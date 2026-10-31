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
  same way into the database node the connection targets (when it
  targets another node, a pooler: every `database` node whose data file
  creates the target database, every `database` node when none does;
  v0.4, a game with two), as a SCRAM
  verifier, with statement logging off for the session, so the password
  is never in a log, a process list or the server's statistics.
  Then (spec D176) on every `database` node whose brick has the GM check
  role (it mounts `gm_check_password`: the role exists), `gm_check` is
  granted `CONNECT` on every database but the templates, the same way, a
  scenario's data possibly having revoked it from `PUBLIC`.
- v0.4 (master spec 14, 7.2, 8.5, 8.6, 11.6; captures W1 items 0 and 8,
  W2-x of `specs/versions/v0.4/wave-log.md`): each data file gets `-v
  customer_timezone=<zone> -v customer_utc_offset=<n>` (render's shift;
  `Etc/GMT` and 0 in a game with none); the passwords are set for the
  roles a node's `crontab_roles` names too, on that node, and (master
  spec 9.7) for every login role a node's data file creates, on that
  node, each from its secret `role_<role>_password`; then every
  database of every `database` node is surveyed (`pg_cron`, foreign
  servers, user mappings), each user mapping gets as its `password` option
  its remote role's secret, and where the check role exists it gets, in a
  database holding `pg_cron`, the read policy CHECK_POLICY on `cron.job`
  and `cron.job_run_details`, and in a database holding a foreign server
  the mapping-roles function MAPPING_FUNCTION; the `CONNECT` grant last.
- `inject`, at `data-loaded` (or `injected`, to replay the idempotent
  scripts): for every fault instance in `fault_instances` order, a `state`
  fault's `injection.scripts` are streamed in their listed order into `sh
  -s` on the instance's node, as `injection.run_as` (default root), with
  its `FAULT_*` variables; a `seed-file` fault runs nothing. The first
  non-zero exit stops the run. A `parameter` fault (v0.2 capture W1, item
  8) runs nothing either: render planted it. In a game with scheduler
  nodes (v0.3 capture W2, items 2 and 4) only the instances due at T0 are
  planted; the others are planted once the load runs, by `inject --at`
  (`aging`). Recording `injected` writes every instance's `plantings`
  entry. At `load-started` it is refused: re-planting one instance is
  `inject --at now --instance <id>`.

Each step is one `state.setup_step`: any failure, or Ctrl-C, tears the game
down and records `failed` with the reason.
"""

import base64
import hashlib
import hmac
import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from . import localimpl, model, render, state, teardown
from .docker import for_local_dir
from .execnode import exec_node
from .model import GmError

DEPLOY_STAGE = "deployed"
DATA_STAGE = "data-loaded"
INJECT_STAGE = "injected"
LOAD_STAGE = "load-started"
T0 = "T0"
DATA_USER = "postgres"
PSQL_ARGV = ("psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-d", "postgres")
DEFAULT_RUN_AS = "root"
STATE_KIND = "state"
DATABASE_ROLE = "database"
SCRAM_ITERATIONS = 4096             # PostgreSQL's scram_iterations default
SCRAM_SALT_BYTES = 16
PARAMETER_KIND = localimpl.PARAMETER_KIND
CHECK_ROLE = "gm_check"             # the GM check role (v0.3 capture W1-x)
CHECK_SECRET = "gm_check_password"  # mounted on a node: its check role exists
# v0.4 (capture W2-x): what load-data gives the check role.
CHECK_POLICY = "gm_check_read"      # its read policy on CRON_TABLES
CRON_TABLES = ("cron.job", "cron.job_run_details")
CHECK_SCHEMA = "gm_check"           # the mapping-roles function's schema
MAPPING_FUNCTION = f"{CHECK_SCHEMA}.user_mapping_roles"
TIMEZONE_VAR, OFFSET_VAR = "customer_timezone", "customer_utc_offset"   # W1 item 0
# The survey's psql: unaligned, tuples only (one JSON value per line).
SURVEY_ARGV = ("psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-d", "postgres")
NO_LOG_SQL = ("SET log_statement = 'none';", "SET log_min_duration_statement = -1;",
              "SET log_min_error_statement = 'panic';")
NO_STATS_SQL = ("SET pg_stat_statements.track = 'none';",)
QUIET_SQL = "SET client_min_messages = warning;"    # no "already exists" notices
REDACTED = "<password>"


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


PSQL_ERROR_PREFIXES = (("ERROR:",), ("FATAL:", "psql:"))


def psql_error_line(result):
    """The line of a failed psql run that says why: the first starting
    with `ERROR:`, else with `FATAL:` or `psql:`, else the first line
    (release-gate finding RG-9: the output's first line may be a result,
    `setval`, printed before the error)."""
    lines = output_lines(result)
    for prefixes in PSQL_ERROR_PREFIXES:
        for line in lines:
            if line.startswith(prefixes):
                return line
    return _first_line(result)


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
    mappings: list = field(default_factory=list)   # [(node, database, [Mapping])]
    policies: list = field(default_factory=list)   # [(node, database)]: CHECK_POLICY
    functions: list = field(default_factory=list)  # [(node, database)]: MAPPING_FUNCTION
    grants: list = field(default_factory=list)     # database nodes: CHECK_ROLE's CONNECT

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
        out += [f"  {node}/{db}: user mapping for {m.local_text} on server {m.server} given "
                f"remote role {m.remote_role}'s password"
                for node, db, mappings in self.mappings for m in mappings]
        out += [f"  {node}/{db}: {CHECK_ROLE} may read every row of {' and '.join(CRON_TABLES)} "
                f"(policy {CHECK_POLICY})" for node, db in self.policies]
        out += [f"  {node}/{db}: {MAPPING_FUNCTION}() created for {CHECK_ROLE}"
                for node, db in self.functions]
        out += [f"  {node}: {CHECK_ROLE} granted CONNECT on every database"
                for node in self.grants]
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


def psql_variables(impl):
    """The data load's two psql variables (v0.4 capture W1 item 0): the
    customer's bare zone and its offset from UTC in whole hours, east
    positive, without `+`: render's shift, 0 in a game with none."""
    shift = int(((impl.get(localimpl.TIMELINE) or {}).get("shift")) or 0)
    return {TIMEZONE_VAR: render.zone_name(shift), OFFSET_VAR: str(shift)}


def data_argv(variables):
    """PSQL_ARGV with each variable as `-v <name>=<value>` before `-d`."""
    extra = [arg for name, value in variables.items() for arg in ("-v", f"{name}={value}")]
    return (*PSQL_ARGV[:-2], *extra, *PSQL_ARGV[-2:])


def password_plan(scenario, impl):
    """[(database node, [(role, secret)])]: every role a scheduler node's
    schedule names, on the node its connection targets when that node is a
    `database` node, else (through a pooler) on the `database` nodes whose
    data file creates the target database, or on every `database` node
    when none does; then (v0.4 capture W1
    item 8) every role a node's `crontab_roles` names, on that node; then
    (master spec 9.7) every login role a node's data file creates, on that
    node; topology order, each role once per node."""
    databases = [n["name"] for n in scenario.nodes if n.get("role") == DATABASE_ROLE]
    created = {n["name"]: model.node_data_file_creates(Path(scenario.dir), n)
               for n in scenario.nodes if n["name"] in databases}
    roles_of = {}

    def add(db, role):
        if db not in impl["nodes"]:
            raise GmError(f"node {db} is not a node of game {impl['game_id']}")
        roles = roles_of.setdefault(db, [])
        if role not in roles:
            roles.append(role)
    for node in scenario.nodes:
        for conn in localimpl.schedule_connections(scenario, node).values():
            role = conn.get("role")
            m = model.TARGET_RE.match(str(conn.get("target")))
            target, database = (m.group(1), m.group(4)) if m else (None, None)
            holders = [db for db in databases
                       if created[db] is not None and database in created[db].databases]
            for db in [target] if target in databases else holders or databases:
                add(db, role)
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE:
            continue
        for role in localimpl.crontab_roles(node):
            add(node["name"], role)
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE:
            continue
        for role in localimpl.data_login_roles(scenario, node):
            add(node["name"], role)
    return [(db, [(r, localimpl.role_secret_name(r)) for r in roles_of[db]])
            for db in databases if db in roles_of]


def read_secret(ldir, secret):
    """A password secret's text, from `secrets/`; GmError when unreadable
    or empty."""
    path = localimpl.secrets_dir(ldir) / secret
    try:
        password = path.read_text(encoding="utf-8").strip()
    except OSError:
        raise GmError(f"secret file {path} cannot be read: deploy writes it") from None
    if not password:
        raise GmError(f"secret file {path} is empty")
    return password


def password_sql(ldir, roles):
    """The SQL setting each role's password from its secret file in
    `secrets/`, statement logging off for the session."""
    lines = list(NO_LOG_SQL)
    for role, secret in roles:
        password = read_secret(ldir, secret)
        lines.append(f'ALTER ROLE "{role}" PASSWORD \'{scram_verifier(password)}\';')
    return "\n".join(lines) + "\n"


def grant_plan(scenario, impl):
    """The `database` nodes whose check role exists (they mount
    CHECK_SECRET), topology order."""
    plan = []
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE or not any(
                sec.get("name") == CHECK_SECRET
                for sec in localimpl.node_secret_declarations(scenario, node)):
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append(node["name"])
    return plan


def grant_sql():
    """The SQL granting CHECK_ROLE `CONNECT` on every database but the
    templates, each name quoted as an identifier."""
    return ("DO $gm$\nDECLARE\n  db name;\nBEGIN\n"
            "  FOR db IN SELECT datname FROM pg_catalog.pg_database\n"
            "            WHERE NOT datistemplate AND datname NOT IN ('template0', 'template1')\n"
            "            ORDER BY datname LOOP\n"
            f"    EXECUTE format('GRANT CONNECT ON DATABASE %I TO %I', db, '{CHECK_ROLE}');\n"
            "  END LOOP;\nEND\n$gm$;\n")


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


def survey_plan(scenario, impl):
    """The `database` nodes surveyed after the data load, topology order."""
    plan = []
    for node in scenario.nodes:
        if node.get("role") != DATABASE_ROLE:
            continue
        if node["name"] not in impl["nodes"]:
            raise GmError(f"node {node['name']} is not a node of game {impl['game_id']}")
        plan.append(node["name"])
    return plan


# --- The survey of a node's databases (v0.4) --------------------------------

def quote_ident(name):
    return '"' + name.replace('"', '""') + '"'


def quote_literal(text):
    """A standard SQL string literal (standard_conforming_strings on)."""
    return "'" + text.replace("'", "''") + "'"


def connect_line(database):
    """psql's `\\connect` to `database`, the other connection parameters
    reused: the name as a conninfo `dbname` value (so a name holding `=`
    is no connection string), that quoted as one psql argument."""
    value = "'" + database.replace("\\", "\\\\").replace("'", "\\'") + "'"
    conninfo = f"dbname={value}"
    return "\\connect -reuse-previous=on '" + conninfo.replace("\\", "\\\\").replace("'", "''") + "'"


DATABASES_SQL = ("SELECT pg_catalog.json_agg(datname ORDER BY datname) "
                 "FROM pg_catalog.pg_database WHERE datallowconn AND NOT datistemplate;\n")

SURVEY_SQL = """SELECT pg_catalog.json_build_object(
  'database', pg_catalog.current_database(),
  'pg_cron', EXISTS (SELECT 1 FROM pg_catalog.pg_extension WHERE extname = 'pg_cron'),
  'servers', (SELECT pg_catalog.count(*) FROM pg_catalog.pg_foreign_server),
  'mappings', COALESCE((SELECT pg_catalog.json_agg(pg_catalog.json_build_object(
      'server', m.srvname, 'public', m.umuser = 0, 'local_role', m.usename,
      'remote_role', (SELECT o.option_value FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
                       WHERE o.option_name = 'user'),
      'password', EXISTS (SELECT 1 FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
                           WHERE o.option_name = 'password'))
      ORDER BY m.srvname, m.usename) FROM pg_catalog.pg_user_mappings AS m), '[]'));
"""


@dataclass
class Mapping:
    """A user mapping as the survey reads it."""
    server: str
    local_role: str                 # the role name, or `public` for PUBLIC
    public: bool
    remote_role: str                # its `user` option; None when unset
    has_password: bool
    secret: str = None              # the remote role's secret, once planned

    @property
    def local_text(self):
        return "PUBLIC" if self.public else self.local_role


@dataclass
class Database:
    """One database of a node, as the survey reads it."""
    name: str
    pg_cron: bool = False
    servers: int = 0
    mappings: list = field(default_factory=list)


def survey_sql(databases):
    """One JSON line per database: whether it holds `pg_cron`, how many
    foreign servers, its user mappings (server, local role, remote role,
    whether a password is set; read as `postgres`, who sees the options)."""
    return "".join(f"{connect_line(db)}\n{SURVEY_SQL}" for db in databases)


def _json_lines(run, what):
    try:
        return [json.loads(line) for line in output_lines_stdout(run)]
    except ValueError:
        raise GmError(f"{what}: unexpected psql output: {_first_line(run)}") from None


def output_lines_stdout(result):
    stream = result.stdout
    if isinstance(stream, (bytes, bytearray)):
        stream = stream.decode("utf-8", "replace")
    return [line for line in (stream or "").splitlines() if line.strip()]


def survey_node(ldir, node, docker, timeout=None, out=print):
    """[Database] of a node: its databases listed, then each surveyed;
    GmError when psql fails or answers otherwise."""
    run = exec_node(ldir, node, DATA_USER, stdin=DATABASES_SQL, timeout=timeout,
                    docker=docker, argv=SURVEY_ARGV)
    out(f"{node} databases (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    if not run.ok:
        raise GmError(f"listing the databases of {node}: psql exit {run.returncode}: "
                      f"{psql_error_line(run)}")
    rows = _json_lines(run, f"listing the databases of {node}")
    names = rows[0] if len(rows) == 1 and isinstance(rows[0], list) else None
    if names is None or not all(isinstance(n, str) for n in names):
        raise GmError(f"listing the databases of {node}: unexpected psql output: "
                      f"{_first_line(run)}")
    if not names:
        return []
    run = exec_node(ldir, node, DATA_USER, stdin=survey_sql(names), timeout=timeout,
                    docker=docker, argv=SURVEY_ARGV)
    out(f"{node} survey of {', '.join(names)} (psql as {DATA_USER}): "
        f"{'ok' if run.ok else f'exit {run.returncode}'}")
    if not run.ok:
        raise GmError(f"surveying the databases of {node}: psql exit {run.returncode}: "
                      f"{psql_error_line(run)}")
    found = []
    for row in _json_lines(run, f"surveying the databases of {node}"):
        try:
            found.append(Database(row["database"], bool(row["pg_cron"]), int(row["servers"]), [
                Mapping(m["server"], m["local_role"], bool(m["public"]), m["remote_role"],
                        bool(m["password"])) for m in row["mappings"]]))
        except (KeyError, TypeError, ValueError):
            raise GmError(f"surveying the databases of {node}: unexpected psql output: "
                          f"{json.dumps(row)[:200]}") from None
    if [d.name for d in found] != names:
        raise GmError(f"surveying the databases of {node}: {len(found)} answer(s) for "
                      f"{len(names)} database(s)")
    return found


def game_secret_names(impl):
    """The game's secrets by name (`role_<role>_password`, ...)."""
    return {sec.get("secret") for sec in impl.get("secrets") or []}


def plan_mappings(node, databases, game_id, secrets):
    """Each mapping's secret, its remote role's (8.6, 9.7: every login role
    a data file creates has one, as a role a schedule or a `crontab_roles`
    names); GmError, before the mappings' step runs, for a mapping naming
    no remote role or one the game (`secrets`, its secret names) has no
    secret for."""
    for db in databases:
        for m in db.mappings:
            where = (f"{node}/{db.name}: the user mapping for {m.local_text} on server "
                     f"{m.server}")
            if not m.remote_role:
                raise GmError(f"{where} names no remote role (option user): load-data sets a "
                              "mapping's password from its remote role's secret")
            secret = localimpl.role_secret_name(m.remote_role)
            if secret not in secrets:
                raise GmError(f"{where} connects as {m.remote_role}, which has no secret "
                              f"{secret} in game {game_id}: no data file of the scenario "
                              f"creates {m.remote_role} as a login role (CREATE ROLE "
                              f"{m.remote_role} LOGIN), and no schedule's connection or "
                              "node's crontab_roles names it")
            m.secret = secret


def mapping_sql(ldir, databases):
    """`(sql, passwords)`: per database holding a mapping, each mapping's
    `password` option set (ADD, or SET when one is there) to its remote
    role's secret, statement logging and statistics off for each session;
    the passwords, to keep them out of anything printed."""
    parts, passwords = [], []
    for db in databases:
        if not db.mappings:
            continue
        parts += [connect_line(db.name), *NO_LOG_SQL, *NO_STATS_SQL]
        for m in db.mappings:
            password = read_secret(ldir, m.secret)
            passwords.append(password)
            who = "PUBLIC" if m.public else quote_ident(m.local_role)
            op = "SET" if m.has_password else "ADD"
            parts.append(f"ALTER USER MAPPING FOR {who} SERVER {quote_ident(m.server)} "
                         f"OPTIONS ({op} password {quote_literal(password)});")
    return ("\n".join(parts) + "\n" if parts else ""), passwords


def policy_sql():
    """CHECK_ROLE's read policy on each of CRON_TABLES: permissive, SELECT
    only, every row. `pg_cron` enables row-level security on both (its own
    policies show a role its own jobs); permissive policies add up, so this
    one lets the check role read every job and run, nothing more, narrower
    than BYPASSRLS. Re-created, so a second load leaves one."""
    lines = []
    for table in CRON_TABLES:
        lines += [f"DROP POLICY IF EXISTS {CHECK_POLICY} ON {table};",
                  f"CREATE POLICY {CHECK_POLICY} ON {table} AS PERMISSIVE FOR SELECT "
                  f"TO {CHECK_ROLE} USING (true);"]
    return "\n".join(lines) + "\n"


def function_sql():
    """The mapping-roles function (master spec 11.6): in schema
    CHECK_SCHEMA, owned by `postgres`, SECURITY DEFINER with a fixed
    search_path, executable by CHECK_ROLE only; one row per user mapping of
    the database: its server, its local role (`public` for PUBLIC, as
    pg_user_mappings writes it) and its remote role (the `user` option, NULL
    when unset), never its password."""
    fn = f"{MAPPING_FUNCTION}()"
    return f"""CREATE SCHEMA IF NOT EXISTS {CHECK_SCHEMA} AUTHORIZATION postgres;
REVOKE ALL ON SCHEMA {CHECK_SCHEMA} FROM PUBLIC;
GRANT USAGE ON SCHEMA {CHECK_SCHEMA} TO {CHECK_ROLE};
CREATE OR REPLACE FUNCTION {fn}
  RETURNS TABLE (server_name name, local_role name, remote_role text)
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = pg_catalog, pg_temp
AS $gm$
  SELECT m.srvname, m.usename,
         (SELECT o.option_value FROM pg_catalog.pg_options_to_table(m.umoptions) AS o
           WHERE o.option_name = 'user')
    FROM pg_catalog.pg_user_mappings AS m
   ORDER BY 1, 2
$gm$;
ALTER FUNCTION {fn} OWNER TO postgres;
REVOKE ALL ON FUNCTION {fn} FROM PUBLIC;
GRANT EXECUTE ON FUNCTION {fn} TO {CHECK_ROLE};
"""


def access_sql(databases):
    """`(sql, policies, functions)`: per database, the read policy where it
    holds `pg_cron`, the mapping-roles function where it holds a foreign
    server; the databases each went to."""
    parts, policies, functions = [], [], []
    for db in databases:
        if not (db.pg_cron or db.servers):
            continue
        parts.append(connect_line(db.name) + "\n" + QUIET_SQL + "\n")
        if db.pg_cron:
            parts.append(policy_sql())
            policies.append(db.name)
        if db.servers:
            parts.append(function_sql())
            functions.append(db.name)
    return "".join(parts), policies, functions


def _redacted(text, passwords):
    for password in passwords:
        text = text.replace(password, REDACTED)
    return text


@dataclass
class LoadPlans:
    """`load-data`'s plans, read and checked before anything runs."""
    data: list                      # data_plan
    passwords: list                 # password_plan
    surveys: list                   # survey_plan
    grants: list                    # grant_plan: the nodes whose check role exists
    variables: dict                 # psql_variables
    game_id: str
    secrets: set                    # game_secret_names


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
    steps = load_plans(scenario, impl)
    docker = docker or for_local_dir(ldir)
    result = LoadResult(impl["game_id"])

    with state.setup_step(ldir, DATA_STAGE, undo=_undo(docker, impl["game_id"])):
        load_steps(ldir, steps, docker, result, timeout=timeout, out=out)
    localimpl.set_stage(ldir, DATA_STAGE)
    return result


def load_plans(scenario, impl):
    """`load-data`'s plans (LoadPlans), read and checked before anything
    runs."""
    return LoadPlans(data_plan(scenario, impl), password_plan(scenario, impl),
                     survey_plan(scenario, impl), grant_plan(scenario, impl),
                     psql_variables(impl), impl["game_id"], game_secret_names(impl))


def load_steps(ldir, plans, docker, result, timeout=None, out=print):
    """`load-data`'s steps, in order, into `result` (a LoadResult): each
    node's data (with the psql variables), the roles' passwords, the survey
    of every database node's databases, the user mappings' passwords, the
    check role's read policy and mapping-roles function, the check role's
    `CONNECT`; GmError at the first that fails. Also a restart's with no
    snapshot (chunk 11, spec D176)."""
    argv = data_argv(plans.variables)
    for node, rel, path in plans.data:
        with open(path, "rb") as fh:
            run = exec_node(ldir, node, DATA_USER, stdin=fh, timeout=timeout,
                            docker=docker, argv=argv)
        _print_run(out, f"{node} {rel} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"data load of {node} ({rel}): psql exit {run.returncode}: "
                          f"{psql_error_line(run)}")
        result.loaded.append((node, rel))
    for node, roles in plans.passwords:
        names = ", ".join(r for r, _ in roles)
        run = exec_node(ldir, node, DATA_USER, stdin=password_sql(ldir, roles),
                        timeout=timeout, docker=docker, argv=PSQL_ARGV)
        _print_run(out, f"{node} passwords of {names} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"setting the passwords of {names} on {node} (the data must "
                          f"create these roles): psql exit {run.returncode}: "
                          f"{psql_error_line(run)}")
        result.passwords.append((node, [r for r, _ in roles]))
    surveyed = []
    for node in plans.surveys:
        databases = survey_node(ldir, node, docker, timeout=timeout, out=out)
        plan_mappings(node, databases, plans.game_id, plans.secrets)
        surveyed.append((node, databases))
    for node, databases in surveyed:
        sql, passwords = mapping_sql(ldir, databases)
        if not sql:
            continue
        run = exec_node(ldir, node, DATA_USER, stdin=sql, timeout=timeout, docker=docker,
                        argv=PSQL_ARGV)
        heading = f"{node} user mapping passwords (psql as {DATA_USER})"
        out(f"{heading}: {'ok' if run.ok else f'exit {run.returncode}'}")
        for line in output_lines(run):
            out(f"    {_redacted(line, passwords)}")
        if not run.ok:
            raise GmError(f"setting the user mappings' passwords on {node}: psql exit "
                          f"{run.returncode}: {_redacted(psql_error_line(run), passwords)}")
        result.mappings += [(node, db.name, db.mappings) for db in databases if db.mappings]
    for node, databases in surveyed:
        if node not in plans.grants:
            continue
        sql, policies, functions = access_sql(databases)
        if not sql:
            continue
        run = exec_node(ldir, node, DATA_USER, stdin=sql, timeout=timeout, docker=docker,
                        argv=PSQL_ARGV)
        _print_run(out, f"{node} {CHECK_ROLE}'s read policy and mapping-roles function "
                        f"(psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"giving {CHECK_ROLE} its read policy and mapping-roles function on "
                          f"{node}: psql exit {run.returncode}: {psql_error_line(run)}")
        result.policies += [(node, db) for db in policies]
        result.functions += [(node, db) for db in functions]
    for node in plans.grants:
        run = exec_node(ldir, node, DATA_USER, stdin=grant_sql(), timeout=timeout,
                        docker=docker, argv=PSQL_ARGV)
        _print_run(out, f"{node} CONNECT for {CHECK_ROLE} (psql as {DATA_USER})", run)
        if not run.ok:
            raise GmError(f"granting {CHECK_ROLE} CONNECT on the databases of {node}: "
                          f"psql exit {run.returncode}: {psql_error_line(run)}")
        result.grants.append(node)


# --- inject --------------------------------------------------------------------

@dataclass
class InjectResult:
    game_id: str
    replay: bool = False
    scripts: list = field(default_factory=list)    # [(instance, script)]
    seeded: list = field(default_factory=list)     # instances planted by their seed files
    rendered: list = field(default_factory=list)   # parameter faults, planted at rendering
    later: list = field(default_factory=list)      # [(instance, plant_at)] planted by inject --at

    def text(self):
        out = [f"Game {self.game_id}: {len(self.scripts)} injection script(s) run"
               + (" again (replay)." if self.replay else ".")]
        for iid in self.seeded:
            out.append(f"  {iid}: seed-file fault, planted by the seed files; nothing to run")
        for iid in self.rendered:
            out.append(f"  {iid}: parameter fault, planted at rendering; nothing to run")
        for iid, plant_at in self.later:
            out.append(f"  {iid}: planted at {plant_at}, once the load runs (gmctl inject --at "
                       f"after gmctl start-load); nothing run now")
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


def plant_at_of(scenario, impl, inst):
    """An instance's planting moment: `T0` in a game with no scheduler node
    (D157, D158); otherwise the timeline's (render's), else the scenario's."""
    if not model.has_scheduler_nodes(scenario.data):
        return T0
    entry = ((impl.get(localimpl.TIMELINE) or {}).get("instances") or {}).get(inst["id"]) or {}
    return entry.get("plant_at") or inst.get("plant_at") or T0


def initial_plantings(scenario, impl, at):
    """`plantings` as `inject` records it with `injected` (W2 item 4): a T0
    instance planted at `at`, by inject; any other waiting for its
    `inject --at`, its planned instant from the timeline."""
    timeline = (impl.get(localimpl.TIMELINE) or {}).get("instances") or {}
    out = {}
    for inst, _ in fault_instances(scenario):
        plant_at = plant_at_of(scenario, impl, inst)
        if plant_at == T0:
            out[inst["id"]] = {"plant_at": T0, "planted_at": at, "by": "inject"}
        else:
            out[inst["id"]] = {"plant_at": plant_at,
                               "planned_at": (timeline.get(inst["id"]) or {}).get("planned_at"),
                               "timer": None, "attempts": [], "planted_at": None}
    return out


def inject(scenario_dir, playground, timeout=None, docker=None, out=print):
    """`gmctl inject`; returns an InjectResult. Raises GmError on a refusal
    (nothing run) or state.SetupFailed on a failure (torn down, recorded)."""
    ldir, st = _game(scenario_dir, playground)
    stage = st.get("stage")
    if stage == LOAD_STAGE:
        raise GmError(f"game {st.get('game_id')} is at stage {stage}: inject replays the "
                      "plantings only before the load starts; plant one instance with gmctl "
                      "inject --at now --instance <id>")
    if stage not in (DATA_STAGE, INJECT_STAGE):
        raise GmError(f"game {st.get('game_id')} is at stage {stage}; inject needs stage "
                      f"{DATA_STAGE} (run gmctl load-data), or {INJECT_STAGE} to replay")
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    plan = inject_plan(scenario, impl)
    insts = {inst["id"]: inst for inst, _ in fault_instances(scenario)}
    docker = docker or for_local_dir(ldir)
    result = InjectResult(impl["game_id"], replay=stage == INJECT_STAGE)

    with state.setup_step(ldir, INJECT_STAGE, undo=_undo(docker, impl["game_id"])):
        for iid, fault, node, run_as, env, scripts in plan:
            plant_at = plant_at_of(scenario, impl, insts[iid])
            if plant_at != T0:
                result.later.append((iid, plant_at))
                continue
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
        at = localimpl.now_iso()

        def record(st):
            localimpl.enter_stage(st, INJECT_STAGE, at)
            st["plantings"] = initial_plantings(scenario, impl, at)
        localimpl.update_state(ldir, record)
    return result
