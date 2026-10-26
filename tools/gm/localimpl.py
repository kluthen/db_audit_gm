"""The local implementation: `<scenario>/local/<playground>/`.

Master spec 10.3; files, names and labels fixed by capture W2-A
(`specs/versions/v0.1/wave-log.md`):

- `playground.yaml`      the playground as declared (never keys);
- `implementation.yaml`  written by `fit`: game id, per-node brick, image,
                         resources (copied, never recomputed), published
                         ports, and every derived name;
- `stack.yml`, `envelopes/<node>.conf`, `mounted/<item>/<node>.conf`
                         written by `render` (the last: each receiving
                         node's own config of a mounted item, v0.2 capture
                         W1, item 4);
- `rendered/<node>/<seed file>`
                         written by `render` (v0.3 capture W2, item 1):
                         the seed files it rewrites, a scheduler node's
                         `schedule.yaml` and `jobs.yaml` in UTC and a
                         bastion seed file with `{{customer_timezone}}`
                         filled; `implementation.yaml` names them from
                         `fit` on, and `render` adds its `timeline`;
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

from .model import (CUSTOMER_TIMEZONE, SUBSTITUTION_RE, GmError, has_scheduler_nodes,
                    is_scheduler_node, is_seed_folder_entry, mounted_items, parse_mode,
                    parse_size)

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
MOUNTED_DIR = "mounted"
RENDERED_DIR = "rendered"
TIMELINE = "timeline"               # implementation.yaml's key render writes (v0.3 W2, item 1)

LABEL_NAMESPACE = "com.docker.stack.namespace"
LABEL_GAME = "dbagm.game"
PLACEMENT_CONSTRAINT = "node.role == manager"   # single host in v0.1
ENVELOPES_CONFIG = "envelopes"      # the brick's protected config holding the envelope file
SEED_CONFIG_UID, SEED_CONFIG_GID, SEED_CONFIG_MODE = 0, 0, "0444"   # unless seed.modes says
SEED_KIND = "seed"
# A scheduler node's seed files render rewrites in UTC (v0.3 capture W1,
# item 7); the others are copied unchanged.
SCHEDULE_FILE, JOBS_FILE = "schedule.yaml", "jobs.yaml"
RENDERED_SCHEDULER_FILES = (SCHEDULE_FILE, JOBS_FILE)
BASTION_ROLE = "bastion"

# Mounted companion material (v0.2 capture W1, item 4; W1-D): each file of
# an item is one config `<game_id>_<mounting node>_<item>-<k>` (k from 1, in
# `files` order), shared by every receiving node; each receiving node's own
# config is `<game_id>_<node>_<item>.conf`. All root-owned, read-only.
MOUNTED_CONFIG = "mounted"
NODE_CONFIG = "node-config"
MOUNTED_UID, MOUNTED_GID = 0, 0
DEFAULT_ENTRY = "default"           # a node-map entry: the brick's processes

# Parameter faults (capture W1, item 8), applied when the implementation is
# written, before the mounted material is derived (master spec 6.4, 8).
PARAMETER_KIND = "parameter"

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


# --- Seed files ------------------------------------------------------------

def seed_entries(scenario, node):
    """`[(brick seed file, seed name, scenario file)]` of a node, in the
    brick's `seed.files` order: a file entry as itself; a directory entry
    (`builders/`, v0.3 capture W1, item 3) as one entry per regular file of
    the scenario's folder, by name, its seed name `<entry><file>`; a
    directory entry the scenario leaves out gives none."""
    seed = scenario.bricks[node["name"]].data.get("seed") or {}
    given = node.get("seed_files") or {}
    out = []
    for fname in seed.get("files") or []:
        if not is_seed_folder_entry(fname):
            out.append((fname, fname, given[fname]))
            continue
        rel = given.get(fname)
        if rel is None:
            continue
        folder = Path(scenario.dir) / rel
        for entry in sorted(folder.iterdir()) if folder.is_dir() else []:
            if entry.is_file():
                out.append((fname, fname + entry.name,
                            posixpath.join(str(rel).rstrip("/"), entry.name)))
    return out


def rendered_seed_file(playground, node, fname):
    """A seed file render rewrites, relative to the scenario folder."""
    return f"local/{playground}/{RENDERED_DIR}/{node}/{fname}"


def rendered_seed_names(scenario, node):
    """The seed files of `node` render rewrites (v0.3 capture W2, item 1):
    a scheduler node's `schedule.yaml` and `jobs.yaml`; in a scenario with
    scheduler nodes, a bastion seed file holding `{{customer_timezone}}`
    (where the loader looks for it, W1 item 1)."""
    if is_scheduler_node(node):
        return [f for f in RENDERED_SCHEDULER_FILES if f in (node.get("seed_files") or {})]
    if node.get("role") != BASTION_ROLE or not has_scheduler_nodes(scenario.data):
        return []
    names = []
    for _, seed_name, rel in seed_entries(scenario, node):
        try:
            text = (Path(scenario.dir) / rel).read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        if CUSTOMER_TIMEZONE in text:
            names.append(seed_name)
    return names


def seed_configs(scenario, node, playground, game_id):
    """A node's seed configs: one per seed entry (seed_entries), at
    `<seed.dir><seed name>`, root-owned, with its brick's `seed.modes`
    mode, `"0444"` otherwise (a directory entry's mode for each of its
    files); `file` the scenario's, or the rendered one for a file render
    rewrites (v0.3 capture W1, item 3; W2, item 1)."""
    name = node["name"]
    seed = scenario.bricks[name].data.get("seed") or {}
    modes = seed.get("modes") or {}
    rendered = rendered_seed_names(scenario, node)
    configs = []
    for fname, seed_name, rel in seed_entries(scenario, node):
        configs.append({
            "kind": SEED_KIND,
            "name": f"{game_id}_{name}_{config_file_part(seed_name)}",
            "file": rendered_seed_file(playground, name, seed_name)
                    if seed_name in rendered else rel,
            "path": posixpath.join(seed["dir"], seed_name),
            "uid": SEED_CONFIG_UID, "gid": SEED_CONFIG_GID,
            "mode": str(modes.get(fname, SEED_CONFIG_MODE)),
        })
    return configs


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
        for _, seed_name, _ in seed_entries(scenario, node):
            parts.append((f"_{name}_{config_file_part(seed_name)}", OBJECT_NAME_MAX))
        for pc in brick.get("protected_configs") or []:
            parts.append((f"_{name}_{pc['name']}", OBJECT_NAME_MAX))
        for sec in brick.get("secrets") or []:
            parts.append((f"_{sec['name']}", OBJECT_NAME_MAX))
        # mounted material: any node of the topology may receive it
        for item in mounted_items(brick):
            files = item.get("files") or []
            parts.append((f"_{name}_{item.get('name')}-{len(files)}", OBJECT_NAME_MAX))
            for other in scenario.nodes:
                parts.append((f"_{other['name']}_{item.get('name')}.conf", OBJECT_NAME_MAX))
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


# --- Parameter faults and mounted material ---------------------------------

def _fault_values(fault, instance):
    """`{NAME: value}` of a fault instance's parameters, for `{NAME}`: the
    instance's value, else the fault's default; NAME is the parameter's name
    upper-cased, `-` to `_` (capture W1, item 8)."""
    given = instance.get("parameters") or {}
    values = {}
    for pname, spec in (fault.data.get("parameters") or {}).items():
        value = given.get(pname)
        if value is None:
            value = (spec if isinstance(spec, dict) else {}).get("default")
        values[str(pname).upper().replace("-", "_")] = value
    return values


def _substitute(value, values, where):
    """`{NAME}` in a change's `entry`, `item` or `value` replaced by the
    instance's parameter; a value that is only `{NAME}` takes its type."""
    if not isinstance(value, str):
        return value

    def lookup(name):
        if values.get(name) is None:
            raise GmError(f"{where}: {{{name}}} has no value (fault parameter)")
        return values[name]

    whole = SUBSTITUTION_RE.fullmatch(value)
    if whole:
        return lookup(whole.group(1))
    return SUBSTITUTION_RE.sub(lambda m: str(lookup(m.group(1))), value)


def parameter_faults(scenario):
    """implementation.yaml's `parameter_faults`: every instance of a
    `parameter` fault, in `fault_instances` order, as `{instance, fault,
    node, changes}`; each change `{parameter, op}` with its `entry`, `item`
    or `value`, `{NAME}` replaced (capture W1, item 8)."""
    out = []
    for inst in scenario.data.get("fault_instances") or []:
        fault = scenario.faults[inst["id"]]
        injection = fault.data.get("injection") or {}
        if injection.get("kind") != PARAMETER_KIND:
            continue
        values = _fault_values(fault, inst)
        where = f"fault instance {inst['id']} ({fault.id})"
        changes = []
        for change in injection.get("parameter_changes") or []:
            entry = {"parameter": change.get("parameter"), "op": change.get("op")}
            for key in ("entry", "item", "value"):
                if key in change:
                    entry[key] = _substitute(change[key], values, where)
            changes.append(entry)
        out.append({"instance": inst["id"], "fault": fault.id, "node": inst.get("node"),
                    "changes": changes})
    return out


def entry_services(scenario, node_name, entry):
    """A node-map entry as a list: `default` is the node's brick's
    `processes`."""
    if entry == DEFAULT_ENTRY:
        return [str(p) for p in scenario.bricks[node_name].data.get("processes") or []]
    return [str(s) for s in entry or []]


def _apply_change(scenario, brick, values, change, where):
    pname, op = change.get("parameter"), change.get("op")
    where = f"{where}: {op} {pname}"
    spec = (brick.data.get("parameters") or {}).get(pname)
    if not isinstance(spec, dict):
        raise GmError(f"{where}: {pname} is not a parameter of brick {brick.id}")
    if op == "set":
        values[pname] = change.get("value")
        return
    current = values.get(pname, spec.get("default"))
    if not isinstance(current, dict):
        raise GmError(f"{where}: {pname} is not a map")
    current = copy.deepcopy(current)
    entry = change.get("entry")
    if entry not in current:
        raise GmError(f"{where}: {pname} has no entry {entry}")
    if op == "remove-entry":
        del current[entry]
    elif op == "remove-from-entry":
        items = entry_services(scenario, entry, current[entry])
        item = change.get("item")
        if item not in items:
            raise GmError(f"{where}: entry {entry} of {pname} has no item {item}")
        current[entry] = [i for i in items if i != item]
    else:
        raise GmError(f"{where}: op {op} is not set, remove-entry or remove-from-entry")
    values[pname] = current


def node_parameters(scenario):
    """`{node: parameters}` in topology order: each node's `parameters` as
    scenario.yaml writes them (copied; the scenario is left unchanged), with
    every parameter fault's changes applied, in order, to its target node
    (master spec 6.4, 8). A change that would plant nothing, an entry or an
    item that is not there, is refused (GmError)."""
    params = {n["name"]: copy.deepcopy(n.get("parameters") or {}) for n in scenario.nodes}
    for pf in parameter_faults(scenario):
        where = f"fault instance {pf['instance']} ({pf['fault']})"
        if pf["node"] not in params:
            raise GmError(f"{where}: node {pf['node']!r} is not a node of the topology")
        brick = scenario.bricks[pf["node"]]
        for change in pf["changes"]:
            _apply_change(scenario, brick, params[pf["node"]], change, where)
    return params


def mounted_material(scenario, params):
    """`[(mounting node, brick, item, {receiving node: entry})]`: every
    `companion.mounted` item of the topology, its receiving nodes those its
    node-map parameter lists in `params` (node_parameters), in topology
    order (capture W1, item 4)."""
    names = [n["name"] for n in scenario.nodes]
    out = []
    for name in names:
        brick = scenario.bricks[name]
        for item in mounted_items(brick.data):
            pname = item.get("parameter")
            spec = (brick.data.get("parameters") or {}).get(pname) or {}
            value = params[name].get(pname, spec.get("default"))
            value = value if isinstance(value, dict) else {}
            out.append((name, brick, item, {r: value[r] for r in names if r in value}))
    return out


def node_config_file(playground, item, node):
    """A receiving node's own config of a mounted item, relative to the
    scenario folder (written by render)."""
    return f"local/{playground}/{MOUNTED_DIR}/{item}/{node}.conf"


def _scenario_relative(scenario, path):
    return Path(os.path.relpath(Path(path).resolve(), Path(scenario.dir).resolve())).as_posix()


def mounted_configs(scenario, params, playground, game_id):
    """`{node: [config]}` for every node of the topology: the mounted items'
    files (one config each, shared by the receiving nodes, its `file` the
    brick's source relative to the scenario folder) and the node's own
    config, for every item whose map lists the node; root-owned at the
    declared targets and modes (capture W1, item 4; W1-D). GmError when a
    file is missing or empty (Swarm refuses an empty config)."""
    configs = {n["name"]: [] for n in scenario.nodes}
    for mnode, brick, item, entries in mounted_material(scenario, params):
        iname = item.get("name")
        files = []
        for k, entry in enumerate(item.get("files") or [], 1):
            source = brick.dir / entry["source"]
            if not source.is_file():
                raise GmError(f"brick {brick.id}: {entry['source']} does not exist "
                              f"(companion.mounted {iname})")
            if source.stat().st_size == 0:
                raise GmError(f"brick {brick.id}: {entry['source']} is empty (companion.mounted "
                              f"{iname}): Swarm refuses an empty config")
            files.append({"kind": MOUNTED_CONFIG, "item": iname,
                          "name": f"{game_id}_{mnode}_{iname}-{k}",
                          "file": _scenario_relative(scenario, source),
                          "path": entry["target"], "uid": MOUNTED_UID, "gid": MOUNTED_GID,
                          "mode": entry["mode"]})
        node_config = item.get("node_config") or {}
        for rnode in entries:
            configs[rnode] += copy.deepcopy(files)
            configs[rnode].append({
                "kind": NODE_CONFIG, "item": iname, "name": f"{game_id}_{rnode}_{iname}.conf",
                "file": node_config_file(playground, iname, rnode),
                "path": node_config["target"], "uid": MOUNTED_UID, "gid": MOUNTED_GID,
                "mode": node_config["mode"]})
    return configs


def node_config_text(scenario, impl, node_name, entry):
    """A receiving node's own config (capture W1, item 4; W1-D): `node`,
    `services` (the entry, `default` expanded to the brick's processes),
    `disk_reservation` (the node's reserved disk, in bytes) and `volumes`
    (the in-container paths of its volumes); never empty."""
    inode = impl["nodes"][node_name]
    disk = parse_size(inode["resources"]["reservations"]["disk"])
    return (f"node={node_name}\n"
            f"services={' '.join(entry_services(scenario, node_name, entry))}\n"
            f"disk_reservation={disk}\n"
            f"volumes={' '.join(v['path'] for v in inode['volumes'])}\n")


def build_implementation(scenario, playground, game_id, created_at):
    """implementation.yaml's content (capture W2-A; v0.2: the network named
    after the scenario's, the secrets by kind, the mounted material and the
    parameter faults applied before it is derived)."""
    gid = game_id
    local_rel = f"local/{playground}"
    mounted = mounted_configs(scenario, node_parameters(scenario), playground, gid)
    nodes = {}
    for node in scenario.nodes:
        name = node["name"]
        brick = scenario.bricks[name]
        b = brick.data
        configs = seed_configs(scenario, node, playground, gid)
        for pc in b.get("protected_configs") or []:
            configs.append({
                "kind": pc["name"],
                "name": f"{gid}_{name}_{pc['name']}",
                "file": f"{local_rel}/{ENVELOPES_DIR}/{name}.conf",
                "path": pc["path"], "uid": pc["uid"], "gid": pc["gid"], "mode": pc["mode"],
            })
        configs += mounted[name]
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
        "parameter_faults": parameter_faults(scenario),
    }
    _check_names(impl)
    return impl


def _check_names(impl):
    seen = {}
    for node in impl["nodes"].values():
        if len(node["service"]) > SERVICE_NAME_MAX:
            raise GmError(f"service name {node['service']} is longer than {SERVICE_NAME_MAX}")
        for obj in node["configs"] + node["secrets"]:
            if len(obj["name"]) > OBJECT_NAME_MAX or not OBJECT_NAME_RE.match(obj["name"]):
                raise GmError(f"config or secret name {obj['name']} is not a valid Swarm name")
            parse_mode(obj["mode"])
        for obj in node["configs"]:
            # one name, one config: a mounted file is shared, never two files
            if seen.setdefault(obj["name"], obj) != obj:
                raise GmError(f"config name {obj['name']} is derived for two different files")
