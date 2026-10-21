"""The local implementation: `<scenario>/local/<playground>/`.

Master spec 10.3; files, names and labels fixed by capture W2-A
(`specs/versions/v0.1/wave-log.md`):

- `playground.yaml`      the playground as declared (never keys);
- `implementation.yaml`  written by `fit`: game id, per-node brick, image,
                         resources (copied, never recomputed), published
                         ports, and every derived name;
- `stack.yml`, `envelopes/<node>.conf`  written by `render`;
- `state.yaml`           the stage reached, its history, any failure, and
                         the teardown record (spec D50);
- `secrets/`             written by `deploy` (directory 0700, files 0600):
                         the secrets the bricks declare, by kind (v0.2
                         capture W1, item 7).

Every path an implementation records (`file:`) is relative to the scenario
folder.
"""

import copy
import datetime
import os
import posixpath
import re
import secrets as _random
import tempfile
from pathlib import Path

import yaml

from .model import GmError, parse_mode

PLATFORM = "swarm"
STAGES = ("fitted", "rendered", "deployed", "data-loaded", "injected", "handed-over",
          "final-answer", "feedback-given", "torn-down")
FAILED = "failed"
TORN_DOWN = "torn-down"

PLAYGROUND_FILE = "playground.yaml"
IMPLEMENTATION_FILE = "implementation.yaml"
STATE_FILE = "state.yaml"
STACK_FILE = "stack.yml"
ENVELOPES_DIR = "envelopes"
SECRETS_DIR = "secrets"

LABEL_NAMESPACE = "com.docker.stack.namespace"
LABEL_GAME = "dbagm.game"
PLACEMENT_CONSTRAINT = "node.role == manager"   # single host in v0.1
ENVELOPES_CONFIG = "envelopes"      # the brick's protected config holding the envelope file
SEED_CONFIG_UID, SEED_CONFIG_GID, SEED_CONFIG_MODE = 0, 0, "0444"

# Per-game secrets, by kind (v0.2 capture W1, item 7): a password writes
# secrets/<name>; a key pair writes secrets/<pair> and secrets/<pair>.pub,
# each half mounting the matching file. The Swarm secret is <game_id>_<name>.
PASSWORD = "password"
KEY_PAIR = "key-pair"
SECRET_KINDS = (PASSWORD, KEY_PAIR)
KEY_HALVES = ("private", "public")
PUBLIC_KEY_SUFFIX = ".pub"

GAME_ID_MAX = 63                    # master spec 10.3
SERVICE_NAME_MAX = 63               # Swarm service names
OBJECT_NAME_MAX = 64                # Swarm config and secret names
OBJECT_NAME_RE = re.compile(r"^[a-zA-Z0-9]+(?:[a-zA-Z0-9-_.]*[a-zA-Z0-9])?$")
SUFFIX_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"
SUFFIX_LENGTH = 6
PLAYGROUND_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")


# --- Paths and files -----------------------------------------------------

def local_dir(scenario_dir, playground):
    """`<scenario>/local/<playground>/` (not created)."""
    if not isinstance(playground, str) or not PLAYGROUND_RE.match(playground):
        raise GmError(f"playground name {playground!r}: use lowercase letters, digits and "
                      "hyphens (laptop, classroom)")
    return Path(scenario_dir).resolve() / "local" / playground


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0) \
        .isoformat().replace("+00:00", "Z")


def read_yaml(path):
    """The file's content, or None if it does not exist."""
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except FileNotFoundError:
        return None
    except yaml.YAMLError as exc:
        raise GmError(f"{path}: cannot be read: {' '.join(str(exc).split())}") from None


def write_text(path, text):
    """Atomic write (temporary file, then rename)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def write_yaml(path, data, header=None):
    body = yaml.safe_dump(data, sort_keys=False, default_flow_style=False, width=100)
    write_text(path, (header or "") + body)


def _header(what):
    return f"# {what}\n# Written by gmctl; never edit by hand (capture W2-A).\n"


def read_playground(ldir):
    return read_yaml(Path(ldir) / PLAYGROUND_FILE)


def write_playground(ldir, data):
    write_yaml(Path(ldir) / PLAYGROUND_FILE, data, _header("Playground as declared."))


def read_implementation(ldir):
    data = read_yaml(Path(ldir) / IMPLEMENTATION_FILE)
    if data is None:
        raise GmError(f"no local implementation in {ldir}: run gmctl fit first")
    return data


def write_implementation(ldir, data):
    write_yaml(Path(ldir) / IMPLEMENTATION_FILE, data,
               _header("Local implementation of the scenario on this playground."))


def secrets_dir(ldir):
    return Path(ldir) / SECRETS_DIR


# --- State ---------------------------------------------------------------

def read_state(ldir):
    return read_yaml(Path(ldir) / STATE_FILE)


def write_state(ldir, state):
    write_yaml(Path(ldir) / STATE_FILE, state, _header("Game state."))


def new_state(ldir, game_id, stage, now=None):
    if stage not in STAGES:
        raise ValueError(stage)
    at = now or now_iso()
    state = {"game_id": game_id, "stage": stage, "history": [{"stage": stage, "at": at}],
             "failure": None}
    write_state(ldir, state)
    return state


def set_stage(ldir, stage, now=None):
    """Record that the game reached `stage`; clears any failure, and any
    teardown record (the game went on after it)."""
    if stage not in STAGES:
        raise ValueError(stage)
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game state in {ldir}: run gmctl fit first")
    at = now or now_iso()
    state["stage"] = stage
    state.setdefault("history", []).append({"stage": stage, "at": at})
    state["failure"] = None
    state.pop("teardown", None)
    write_state(ldir, state)
    return state


def set_failed(ldir, stage, reason, now=None):
    """Record a failure while working towards `stage` (stage becomes `failed`);
    clears any teardown record (a new failure needs a new teardown)."""
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game state in {ldir}")
    at = now or now_iso()
    state["stage"] = FAILED
    state.setdefault("history", []).append({"stage": FAILED, "at": at})
    state["failure"] = {"stage": stage, "reason": reason, "at": at}
    state.pop("teardown", None)
    write_state(ldir, state)
    return state


def teardown_record(state):
    """The state's teardown record `{stage, reason, at}`, or None; a state
    without the key has none (spec D50)."""
    return (state or {}).get("teardown") or None


def record_teardown(ldir, reason=None, now=None):
    """Record that `gmctl teardown` left nothing labelled with the game id.

    Stage `torn-down` with its history entry, except for a failed game,
    which stays `failed` with its failure. The teardown record `{stage,
    reason, at}` (`stage`: the last stage reached) is written when the
    state has none and the game is not already at `torn-down`. Returns
    the record written, or None when it was left unchanged."""
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game state in {ldir}")
    at = now or now_iso()
    current = state.get("stage")
    record = None
    if teardown_record(state) is None and current != TORN_DOWN:
        record = {"stage": effective_stage(state), "reason": reason, "at": at}
    if current not in (FAILED, TORN_DOWN):
        state["stage"] = TORN_DOWN
        state.setdefault("history", []).append({"stage": TORN_DOWN, "at": at})
        state["failure"] = None
    if record is not None:
        state["teardown"] = record
    if record is not None or current not in (FAILED, TORN_DOWN):
        write_state(ldir, state)
    return record


def effective_stage(state):
    """The last stage reached: for a failed game, the stage before the failure."""
    if state is None:
        return None
    if state.get("stage") != FAILED:
        return state.get("stage")
    for entry in reversed(state.get("history") or []):
        if entry.get("stage") != FAILED:
            return entry.get("stage")
    return None


def require_stage(ldir, *allowed):
    """The state, if the game's stage is one of `allowed`; else GmError."""
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game in {ldir}: run gmctl fit first")
    if state.get("stage") not in allowed:
        raise GmError(f"game {state.get('game_id')} is at stage {state.get('stage')}; "
                      f"this needs stage {' or '.join(allowed)}")
    return state


# --- Names -----------------------------------------------------------------

def labels(game_id):
    """Labels gmctl deploy sets on every config and secret (capture W2-A)."""
    return {LABEL_NAMESPACE: game_id, LABEL_GAME: game_id}


def config_file_part(file_name):
    return str(file_name).replace("/", "-")


def _derived_lengths(scenario):
    """(name part after the game id, limit) for every derived name."""
    parts = []
    for node in scenario.nodes:
        name = node["name"]
        brick = scenario.bricks[name].data
        parts.append((f"_{name}", SERVICE_NAME_MAX))
        for fname in (brick.get("seed") or {}).get("files") or []:
            parts.append((f"_{name}_{config_file_part(fname)}", OBJECT_NAME_MAX))
        for pc in brick.get("protected_configs") or []:
            parts.append((f"_{name}_{pc['name']}", OBJECT_NAME_MAX))
        for sec in brick.get("secrets") or []:
            parts.append((f"_{sec['name']}", OBJECT_NAME_MAX))
    return parts


def max_game_id_length(scenario):
    longest = GAME_ID_MAX
    for part, limit in _derived_lengths(scenario):
        longest = min(longest, limit - len(part))
    return longest


def new_game_id(scenario_id, max_length=GAME_ID_MAX):
    """Scenario id, `-`, 6 random `[a-z0-9]`; the scenario id is shortened
    so that the game id fits `max_length`."""
    room = max_length - SUFFIX_LENGTH - 1
    prefix = str(scenario_id)[:max(room, 0)].rstrip("-")
    if not prefix:
        raise GmError(f"no room for a game id of at most {max_length} characters")
    suffix = "".join(_random.choice(SUFFIX_ALPHABET) for _ in range(SUFFIX_LENGTH))
    return f"{prefix}-{suffix}"


def network_name(scenario):
    """The name of the scenario's one network (it renders as
    `<game_id>_<name>`, master spec 6.3); None when it declares none."""
    networks = scenario.data.get("networks") or []
    return networks[0].get("name") if networks and isinstance(networks[0], dict) else None


def secret_file(sec):
    """The file in `secrets/` a declared secret mounts: a password's name,
    a key pair's `<pair>` (private half) or `<pair>.pub` (public half)."""
    if sec.get("kind") == KEY_PAIR:
        return sec["pair"] + (PUBLIC_KEY_SUFFIX if sec.get("half") == "public" else "")
    return sec["name"]


def _secret_identity(sec):
    """What two declarations of one name must agree on (capture W1, item 7)."""
    if sec.get("kind") == PASSWORD:
        return {"kind": PASSWORD, "handed_over": sec.get("handed_over") is True}
    return {"kind": KEY_PAIR, "pair": sec.get("pair"), "half": sec.get("half")}


def _secret_problems(brick, sec):
    """A declared secret's shape, as far as generating it goes."""
    name = sec.get("name")
    where = f"brick {brick.id}: secret {name}"
    kind = sec.get("kind")
    if kind not in SECRET_KINDS:
        return [f"{where}: kind {kind} is not {' or '.join(SECRET_KINDS)}"]
    out = []
    if kind == PASSWORD:
        if "handed_over" in sec and not isinstance(sec["handed_over"], bool):
            out.append(f"{where}: handed_over is not true or false")
        out += [f"{where}: {key} is for a key pair, not a password"
                for key in ("pair", "half") if key in sec]
    else:
        pair = sec.get("pair")
        if not isinstance(pair, str) or not OBJECT_NAME_RE.match(pair):
            out.append(f"{where}: kind key-pair needs pair, the pair's name (got {pair!r})")
        if sec.get("half") not in KEY_HALVES:
            out.append(f"{where}: kind key-pair needs half, private or public "
                       f"(got {sec.get('half')!r})")
        if "handed_over" in sec:
            out.append(f"{where}: handed_over is for a password, not a key pair")
    return out


def game_secrets(scenario):
    """`(secrets, problems)`: the game's secrets, one per declared name in
    topology order, each `{"secret": name, **identity, "file": file in
    secrets/}`, and what refuses the topology (capture W1, item 7): a
    malformed declaration, a name two bricks declare differently, or a
    password whose file is a key pair's."""
    found, problems = {}, []
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        for sec in brick.data.get("secrets") or []:
            name = sec.get("name")
            shape = _secret_problems(brick, sec)
            if shape:
                problems += shape
                continue
            identity = _secret_identity(sec)
            if name in found:
                first_brick, first = found[name]
                if first != identity:
                    problems.append(
                        f"secret {name} is declared differently by bricks {first_brick} "
                        f"({_identity_text(first)}) and {brick.id} "
                        f"({_identity_text(identity)}): one name is one secret")
                continue
            found[name] = (brick.id, identity)
    pairs = {i["pair"] for _, i in found.values() if i["kind"] == KEY_PAIR}
    pair_files = {f: p for p in pairs for f in (p, p + PUBLIC_KEY_SUFFIX)}
    for name, (bid, identity) in found.items():
        if identity["kind"] == PASSWORD and name in pair_files:
            problems.append(f"password {name} (brick {bid}) would be written to the file of "
                            f"key pair {pair_files[name]}: rename one of them")
    secrets = [{"secret": name, **identity,
                "file": secret_file({"name": name, **identity})}
               for name, (_, identity) in found.items()]
    return secrets, problems


def _identity_text(identity):
    if identity["kind"] == PASSWORD:
        return "password" + (", handed over" if identity["handed_over"] else "")
    return f"key pair {identity['pair']}, {identity['half']} half"


def check_supported(scenario):
    """What gmctl cannot render or deploy; [] when all is supported."""
    problems = []
    networks = scenario.data.get("networks") or []
    if len(networks) != 1:
        problems.append(f"the scenario declares {len(networks)} networks; gmctl renders one "
                        "network, <game_id>_<network name> (spec D83, D106)")
    problems += game_secrets(scenario)[1]
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        for pc in brick.data.get("protected_configs") or []:
            if pc.get("name") != ENVELOPES_CONFIG:
                problems.append(f"brick {brick.id} declares protected config "
                                f"{pc.get('name')}; gmctl renders only {ENVELOPES_CONFIG}")
    return problems


def implementation_secrets(scenario, playground, game_id):
    """implementation.yaml's `secrets`: per game secret, its Swarm name
    `<game_id>_<name>`, its declaration and its file (relative to the
    scenario folder). GmError when the topology is refused."""
    secrets, problems = game_secrets(scenario)
    if problems:
        raise GmError("; ".join(problems))
    return [{"name": f"{game_id}_{sec['secret']}", **sec,
             "file": f"local/{playground}/{SECRETS_DIR}/{sec['file']}"} for sec in secrets]


def build_implementation(scenario, playground, game_id, created_at):
    """implementation.yaml's content (capture W2-A; v0.2: the network named
    after the scenario's, the secrets by kind)."""
    gid = game_id
    local_rel = f"local/{playground}"
    nodes = {}
    for node in scenario.nodes:
        name = node["name"]
        brick = scenario.bricks[name]
        b = brick.data
        seed = b.get("seed") or {}
        configs = []
        for fname in seed.get("files") or []:
            configs.append({
                "kind": "seed",
                "name": f"{gid}_{name}_{config_file_part(fname)}",
                "file": node["seed_files"][fname],
                "path": posixpath.join(seed["dir"], fname),
                "uid": SEED_CONFIG_UID, "gid": SEED_CONFIG_GID, "mode": SEED_CONFIG_MODE,
            })
        for pc in b.get("protected_configs") or []:
            configs.append({
                "kind": pc["name"],
                "name": f"{gid}_{name}_{pc['name']}",
                "file": f"{local_rel}/{ENVELOPES_DIR}/{name}.conf",
                "path": pc["path"], "uid": pc["uid"], "gid": pc["gid"], "mode": pc["mode"],
            })
        node_secrets = []
        for sec in b.get("secrets") or []:
            sname = f"{gid}_{sec['name']}"
            node_secrets.append({"name": sname, "path": sec["path"], "uid": sec["uid"],
                                 "gid": sec["gid"], "mode": sec["mode"]})
        nodes[name] = {
            "brick": {"id": brick.id, "version": brick.version},
            "image": b["image"],
            "resources": copy.deepcopy(node["resources"]),
            "published_ports": [{"target": p["port"], "published": p["default"],
                                 "mode": "host"} for p in node.get("published_ports") or []],
            "service": f"{gid}_{name}",
            "volumes": [{"name": f"{gid}_{name}_{v['name']}", "path": v["path"]}
                        for v in b.get("volumes") or []],
            "configs": configs,
            "secrets": node_secrets,
        }
    impl = {
        "scenario": {"id": scenario.id, "version": str(scenario.data.get("version")),
                     "path": str(scenario.dir)},
        "game_id": gid,
        "created_at": created_at,
        "playground": playground,
        "stack": gid,
        "network": f"{gid}_{network_name(scenario)}",
        "labels": labels(gid),
        "nodes": nodes,
        "secrets": implementation_secrets(scenario, playground, gid),
    }
    _check_names(impl)
    return impl


def _check_names(impl):
    for node in impl["nodes"].values():
        if len(node["service"]) > SERVICE_NAME_MAX:
            raise GmError(f"service name {node['service']} is longer than {SERVICE_NAME_MAX}")
        for obj in node["configs"] + node["secrets"]:
            if len(obj["name"]) > OBJECT_NAME_MAX or not OBJECT_NAME_RE.match(obj["name"]):
                raise GmError(f"config or secret name {obj['name']} is not a valid Swarm name")
            parse_mode(obj["mode"])
