"""The local implementation: `<scenario>/local/<playground>/`.

Master spec 10.3; files, names and labels fixed by capture W2-A
(`specs/versions/v0.1/wave-log.md`):

- `playground.yaml`      the playground as declared (never keys);
- `implementation.yaml`  written by `fit`: game id, per-node brick, image,
                         resources (copied, never recomputed), published
                         ports, and every derived name;
- `stack.yml`, `envelopes/<node>.conf`  written by `render`;
- `state.yaml`           the stage reached, its history, any failure;
- `secrets/`             written by `deploy` (directory 0700, files 0600).

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

PLAYGROUND_FILE = "playground.yaml"
IMPLEMENTATION_FILE = "implementation.yaml"
STATE_FILE = "state.yaml"
STACK_FILE = "stack.yml"
ENVELOPES_DIR = "envelopes"
SECRETS_DIR = "secrets"

LABEL_NAMESPACE = "com.docker.stack.namespace"
LABEL_GAME = "dbagm.game"
NETWORK_KEY = "net"                 # becomes <game_id>_net under stack <game_id>
PLACEMENT_CONSTRAINT = "node.role == manager"   # single host in v0.1
ENVELOPES_CONFIG = "envelopes"      # the brick's protected config holding the envelope file
SEED_CONFIG_UID, SEED_CONFIG_GID, SEED_CONFIG_MODE = 0, 0, "0444"

# Per-game secrets gmctl deploy generates: logical name -> file in secrets/.
# player_ssh_pubkey is the public half of player_ssh_key (captures W1-F, W2-A).
SECRET_FILES = {
    "player_password": "player_password",
    "player_ssh_key": "player_ssh_key",
    "player_ssh_pubkey": "player_ssh_key.pub",
    "dba_password": "dba_password",
}

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
    """Record that the game reached `stage`; clears any failure."""
    if stage not in STAGES:
        raise ValueError(stage)
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game state in {ldir}: run gmctl fit first")
    at = now or now_iso()
    state["stage"] = stage
    state.setdefault("history", []).append({"stage": stage, "at": at})
    state["failure"] = None
    write_state(ldir, state)
    return state


def set_failed(ldir, stage, reason, now=None):
    """Record a failure while working towards `stage` (stage becomes `failed`)."""
    state = read_state(ldir)
    if state is None:
        raise GmError(f"no game state in {ldir}")
    at = now or now_iso()
    state["stage"] = FAILED
    state.setdefault("history", []).append({"stage": FAILED, "at": at})
    state["failure"] = {"stage": stage, "reason": reason, "at": at}
    write_state(ldir, state)
    return state


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


def check_supported(scenario):
    """What v0.1's gmctl cannot render or deploy; [] when all is supported."""
    problems = []
    networks = scenario.data.get("networks") or []
    if len(networks) != 1:
        problems.append(f"the scenario declares {len(networks)} networks; v0.1 renders one "
                        "network, <game_id>_net (capture W2-A)")
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        for sec in brick.data.get("secrets") or []:
            if sec.get("name") not in SECRET_FILES:
                problems.append(f"brick {brick.id} declares secret {sec.get('name')}, which "
                                f"gmctl does not generate ({', '.join(SECRET_FILES)})")
        for pc in brick.data.get("protected_configs") or []:
            if pc.get("name") != ENVELOPES_CONFIG:
                problems.append(f"brick {brick.id} declares protected config "
                                f"{pc.get('name')}; gmctl renders only {ENVELOPES_CONFIG}")
    return problems


def build_implementation(scenario, playground, game_id, created_at):
    """implementation.yaml's content (capture W2-A)."""
    gid = game_id
    local_rel = f"local/{playground}"
    nodes = {}
    game_secrets = {}
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
            game_secrets.setdefault(sname, {
                "name": sname, "secret": sec["name"],
                "file": f"{local_rel}/{SECRETS_DIR}/{SECRET_FILES[sec['name']]}"})
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
        "network": f"{gid}_{NETWORK_KEY}",
        "labels": labels(gid),
        "nodes": nodes,
        "secrets": list(game_secrets.values()),
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
