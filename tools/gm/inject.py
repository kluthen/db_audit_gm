"""`gmctl load-data` and `gmctl inject`: the setup steps after deployment.

Master spec 10.1 (data and state faults reach a node through the injection
path), 12 (setup steps 5, "Failures") and 8.1 (script contracts); the
behaviour is fixed by capture W3-A (`specs/versions/v0.1/wave-log.md`):

- `load-data`, at stage `deployed`: for every node with a `data` entry, in
  `nodes` order, its `data/<node>.sql` is streamed into `psql -X -q -v
  ON_ERROR_STOP=1 -d postgres`, run as OS user `postgres` in the node's
  container (local peer authentication). At `data-loaded` or a later
  deployed stage it changes nothing: idempotency is the stage, not the SQL.
  Then (v0.3 chunk 7b; capture W1, item 7) every application role a
  scheduler's schedule names gets its password from its secret
  `role_<role>_password`, the data having created the role: streamed the
  same way into the database node the connection targets (every
  `database` node when it targets another node, a pooler), as a SCRAM
  verifier, with statement logging off for the session, so the password
  is never in a log, a process list or the server's statistics.
- `inject`, at `data-loaded` (or `injected`, to replay the idempotent
  scripts): for every fault instance in `fault_instances` order, a `state`
  fault's `injection.scripts` are streamed in their listed order into `sh
  -s` on the instance's node, as `injection.run_as` (default root), with
  its `FAULT_*` variables; a `seed-file` fault runs nothing. The first
  non-zero exit stops the run. A `parameter` fault (v0.2 capture W1, item
  8) runs nothing either: render planted it.

Each step is one `state.setup_step`: any failure, or Ctrl-C, tears the game
down and records `failed` with the reason.
"""

import base64
import hashlib
import hmac
import os
from dataclasses import dataclass, field

from . import localimpl, model, state, teardown
from .docker import for_local_dir
from .execnode import exec_node
from .model import GmError

DEPLOY_STAGE = "deployed"
DATA_STAGE = "data-loaded"
INJECT_STAGE = "injected"
DATA_USER = "postgres"
PSQL_ARGV = ("psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-d", "postgres")
DEFAULT_RUN_AS = "root"
STATE_KIND = "state"
DATABASE_ROLE = "database"
SCRAM_ITERATIONS = 4096             # PostgreSQL's scram_iterations default
SCRAM_SALT_BYTES = 16
PARAMETER_KIND = localimpl.PARAMETER_KIND


# --- Fault parameters --------------------------------------------------------

def _env_text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def fault_env(fault, instance):
    """The `FAULT_<NAME>` variables of one fault instance (captures W1-D,
    W3-A): each parameter the fault declares, valued by the instance's
    `parameters` entry, else the fault's `default`; a scalar as text
    (booleans `true`/`false`). A parameter with no value is not set, unless
    it is `required`: then GmError, as for a list or map value or an invalid
    name. Nothing else goes into the environment."""
    iid = instance.get("id")
    given = instance.get("parameters") or {}
    env = {}
    for pname, spec in (fault.data.get("parameters") or {}).items():
        spec = spec if isinstance(spec, dict) else {}
        name = model.fault_env_name(pname)
        if name is None:
            raise GmError(f"fault {fault.id}: parameter {pname!r} has no valid environment name")
        value = given.get(pname)
        if value is None:
            value = spec.get("default")
        if value is None:
            if spec.get("required"):
                raise GmError(f"fault instance {iid} ({fault.id}): parameter {pname} is "
                              "required and has no value")
            continue
        if isinstance(value, (list, dict)):
            raise GmError(f"fault instance {iid} ({fault.id}): parameter {pname} is a list "
                          "or map; only a scalar can be passed to a script")
        env[name] = _env_text(value)
    return env


def fault_instances(scenario):
    """[(instance, fault definition)] in `fault_instances` order."""
    return [(inst, scenario.faults[inst["id"]])
            for inst in scenario.data.get("fault_instances") or []]


def node_of(instance, impl):
    """The instance's node, refused unless the game has it."""
    node = instance.get("node")
    if node not in impl["nodes"]:
        raise GmError(f"fault instance {instance.get('id')}: node {node!r} is not a node of "
                      f"game {impl['game_id']}")
    return node


# --- Output ------------------------------------------------------------------

def output_lines(result):
    """The non-empty lines a run printed, stdout first, then stderr."""
    lines = []
    for stream in (result.stdout, result.stderr):
        if isinstance(stream, (bytes, bytearray)):
            stream = stream.decode("utf-8", "replace")
        lines += [line.rstrip() for line in (stream or "").splitlines() if line.strip()]
    return lines


def _first_line(result):
    lines = output_lines(result)
    return lines[0] if lines else "no output"


def _print_run(out, heading, result):
    out(f"{heading}: {'ok' if result.ok else f'exit {result.returncode}'}")
    for line in output_lines(result):
        out(f"    {line}")


def _game(scenario_dir, playground):
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    return ldir, st


def _undo(docker, game_id):
    return lambda: teardown.remove_game_objects(docker, game_id).text()


# --- load-data -----------------------------------------------------------------

@dataclass
class LoadResult:
    game_id: str
    already: str = None             # the stage, when the data was already loaded
    loaded: list = field(default_factory=list)     # [(node, file)]
    passwords: list = field(default_factory=list)  # [(database node, [role])]

    def text(self):
        if self.already:
            return (f"Game {self.game_id} is at stage {self.already}: the data is already "
                    "loaded; nothing done.")
        out = [f"Game {self.game_id}: data loaded."]
        out += [f"  {node}: {rel}" for node, rel in self.loaded]
        if not self.loaded:
            out.append("  no node holds data")
        out += [f"  {node}: password set from its secret for role(s) {', '.join(roles)}"
                for node, roles in self.passwords]
        out.append(f"Stage {DATA_STAGE}.")
        return "\n".join(out)


def scram_verifier(password, salt=None, iterations=SCRAM_ITERATIONS):
    """PostgreSQL's stored form of a SCRAM-SHA-256 password (RFC 5802,
    7677): `SCRAM-SHA-256$<iterations>:<salt>$<StoredKey>:<ServerKey>`,
    base64. The server stores it as given and authenticates the password
    against it."""
    salt = os.urandom(SCRAM_SALT_BYTES) if salt is None else salt
    salted = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    stored = hashlib.sha256(hmac.new(salted, b"Client Key", hashlib.sha256).digest()).digest()
    server = hmac.new(salted, b"Server Key", hashlib.sha256).digest()

    def b64(raw):
        return base64.b64encode(raw).decode("ascii")
    return f"SCRAM-SHA-256${iterations}:{b64(salt)}${b64(stored)}:{b64(server)}"


def password_plan(scenario, impl):
    """[(database node, [(role, secret)])]: every role a scheduler node's
    schedule names, on the node its connection targets when that node is a
    `database` node, else on every `database` node; topology order, each
    role once per node."""
    databases = [n["name"] for n in scenario.nodes if n.get("role") == DATABASE_ROLE]
    roles_of = {}
    for node in scenario.nodes:
        for conn in localimpl.schedule_connections(scenario, node).values():
            role = conn.get("role")
            m = model.TARGET_RE.match(str(conn.get("target")))
            target = m.group(1) if m else None
            for db in [target] if target in databases else databases:
                if db not in impl["nodes"]:
                    raise GmError(f"node {db} is not a node of game {impl['game_id']}")
                roles = roles_of.setdefault(db, [])
                if role not in roles:
                    roles.append(role)
    return [(db, [(r, localimpl.role_secret_name(r)) for r in roles_of[db]])
            for db in databases if db in roles_of]


def password_sql(ldir, roles):
    """The SQL setting each role's password from its secret file in
    `secrets/`, statement logging off for the session."""
    lines = ["SET log_statement = 'none';", "SET log_min_duration_statement = -1;",
             "SET log_min_error_statement = 'panic';"]
    for role, secret in roles:
        path = localimpl.secrets_dir(ldir) / secret
        try:
            password = path.read_text(encoding="utf-8").strip()
        except OSError:
            raise GmError(f"secret file {path} cannot be read: deploy writes it") from None
        if not password:
            raise GmError(f"secret file {path} is empty")
        lines.append(f'ALTER ROLE "{role}" PASSWORD \'{scram_verifier(password)}\';')
    return "\n".join(lines) + "\n"


def data_plan(scenario, impl):
    """[(node, relative file, path)] of every node with a `data` entry, in
    `nodes` order."""
    plan = []
    for node in scenario.nodes:
        spec = node.get("data")
        if not isinstance(spec, dict) or not spec.get("file"):
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append((node["name"], spec["file"], scenario.dir / spec["file"]))
    return plan


def load_data(scenario_dir, playground, timeout=None, docker=None, out=print):
    """`gmctl load-data`; returns a LoadResult. Raises GmError on a refusal
    (nothing done) or state.SetupFailed on a failure (torn down, recorded)."""
    ldir, st = _game(scenario_dir, playground)
    stage = st.get("stage")
    if stage in state.DEPLOYED_STAGES and stage != DEPLOY_STAGE:
        return LoadResult(st.get("game_id"), already=stage)
    if stage != DEPLOY_STAGE:
        raise GmError(f"game {st.get('game_id')} is at stage {stage}; load-data needs stage "
                      f"{DEPLOY_STAGE} (run gmctl deploy)")
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    plan = data_plan(scenario, impl)
    passwords = password_plan(scenario, impl)
    docker = docker or for_local_dir(ldir)
    result = LoadResult(impl["game_id"])

    with state.setup_step(ldir, DATA_STAGE, undo=_undo(docker, impl["game_id"])):
        for node, rel, path in plan:
            with open(path, "rb") as fh:
                run = exec_node(ldir, node, DATA_USER, stdin=fh, timeout=timeout,
                                docker=docker, argv=PSQL_ARGV)
            _print_run(out, f"{node} {rel} (psql as {DATA_USER})", run)
            if not run.ok:
                raise GmError(f"data load of {node} ({rel}): psql exit {run.returncode}: "
                              f"{_first_line(run)}")
            result.loaded.append((node, rel))
        for node, roles in passwords:
            names = ", ".join(r for r, _ in roles)
            run = exec_node(ldir, node, DATA_USER, stdin=password_sql(ldir, roles),
                            timeout=timeout, docker=docker, argv=PSQL_ARGV)
            _print_run(out, f"{node} passwords of {names} (psql as {DATA_USER})", run)
            if not run.ok:
                raise GmError(f"setting the passwords of {names} on {node} (the data must "
                              f"create these roles): psql exit {run.returncode}: "
                              f"{_first_line(run)}")
            result.passwords.append((node, [r for r, _ in roles]))
    localimpl.set_stage(ldir, DATA_STAGE)
    return result


# --- inject --------------------------------------------------------------------

@dataclass
class InjectResult:
    game_id: str
    replay: bool = False
    scripts: list = field(default_factory=list)    # [(instance, script)]
    seeded: list = field(default_factory=list)     # instances planted by their seed files
    rendered: list = field(default_factory=list)   # parameter faults, planted at rendering

    def text(self):
        out = [f"Game {self.game_id}: {len(self.scripts)} injection script(s) run"
               + (" again (replay)." if self.replay else ".")]
        for iid in self.seeded:
            out.append(f"  {iid}: seed-file fault, planted by the seed files; nothing to run")
        for iid in self.rendered:
            out.append(f"  {iid}: parameter fault, planted at rendering; nothing to run")
        out.append(f"Stage {INJECT_STAGE}" + (" (unchanged)." if self.replay else "."))
        return "\n".join(out)


def inject_plan(scenario, impl):
    """[(instance, fault, node, run_as, env, [(script, text), ...])], every
    instance in order, scripts read; refuses (GmError) before anything runs."""
    plan = []
    for inst, fault in fault_instances(scenario):
        injection = fault.data.get("injection") or {}
        node = node_of(inst, impl)
        env = fault_env(fault, inst)
        scripts = []
        if injection.get("kind") == STATE_KIND:
            for script in injection.get("scripts") or []:
                try:
                    text = (fault.dir / str(script)).read_text(encoding="utf-8")
                except OSError as exc:
                    raise GmError(f"fault {fault.id}: {script}: cannot be read: "
                                  f"{exc.strerror}") from None
                scripts.append((str(script), text))
        plan.append((inst["id"], fault, node, injection.get("run_as") or DEFAULT_RUN_AS,
                     env, scripts))
    return plan


def inject(scenario_dir, playground, timeout=None, docker=None, out=print):
    """`gmctl inject`; returns an InjectResult. Raises GmError on a refusal
    (nothing run) or state.SetupFailed on a failure (torn down, recorded)."""
    ldir, st = _game(scenario_dir, playground)
    stage = st.get("stage")
    if stage not in (DATA_STAGE, INJECT_STAGE):
        raise GmError(f"game {st.get('game_id')} is at stage {stage}; inject needs stage "
                      f"{DATA_STAGE} (run gmctl load-data), or {INJECT_STAGE} to replay")
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    plan = inject_plan(scenario, impl)
    docker = docker or for_local_dir(ldir)
    result = InjectResult(impl["game_id"], replay=stage == INJECT_STAGE)

    with state.setup_step(ldir, INJECT_STAGE, undo=_undo(docker, impl["game_id"])):
        for iid, fault, node, run_as, env, scripts in plan:
            if not scripts:
                kind = (fault.data.get("injection") or {}).get("kind")
                (result.rendered if kind == PARAMETER_KIND else result.seeded).append(iid)
                continue
            for script, text in scripts:
                run = exec_node(ldir, node, run_as, stdin=text, env=env, timeout=timeout,
                                docker=docker)
                _print_run(out, f"{iid} {script} ({node}, as {run_as})", run)
                if not run.ok:
                    raise GmError(f"injection of {iid} ({fault.id}) stopped at {script}: exit "
                                  f"{run.returncode}: {_first_line(run)}")
                result.scripts.append((iid, script))
    if stage != INJECT_STAGE:
        localimpl.set_stage(ldir, INJECT_STAGE)
    return result
