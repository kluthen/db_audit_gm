"""The local implementation: `<scenario>/local/<playground>/`.

Master spec 10.3; files, names and labels fixed by capture W2-A
(`specs/versions/v0.1/wave-log.md`):

- `playground.yaml`      the playground as declared (never keys): from v0.3
                         a list of hosts and the mapping of the scenario's
                         designed hosts onto them, or today's one-host form,
                         read as a list of one (capture W3 of v0.3, item 1),
                         and the overlay's range when declared (W3-b, D183);
- `implementation.yaml`  written by `fit`: game id, per-node brick, image,
                         resources (copied, never recomputed), published
                         ports, every derived name, and from v0.3 each
                         node's `host` and the hand-over snapshot's verdict
                         `snapshot_fit` (capture W3 of v0.3, items 2, 5),
                         from v0.5 an `api` node's network `aliases` (v0.5
                         capture W2 item 2);
- `stack.yml`, `envelopes/<node>.conf`, `mounted/<item>/<node>.conf`
                         written by `render` (the last: each receiving
                         node's own config of a mounted item, v0.2 capture
                         W1, item 4);
- `rendered/<node>/<seed file>`
                         written by `render` (v0.3 capture W2, item 1):
                         the seed files it rewrites, a scheduler node's
                         `schedule.yaml` and `jobs.yaml` in UTC and a
                         bastion seed file with `{{customer_timezone}}`
                         filled; from v0.4 (master spec 8.5) any other
                         scheduler seed file and a `postgres` node's
                         `postgresql.conf` holding it, and a `postgres`
                         node's `crontab` in UTC; `implementation.yaml`
                         names them from `fit` on, and `render` adds its
                         `timeline`;
- `state.yaml`           the stage reached, its history, any failure, and
                         the teardown record (spec D50); from v0.3 the
                         aging's records (capture W2, items 3 to 8, 10,
                         11), every read-modify-write under an exclusive
                         lock on `.state.lock` (W2, item 0);
- `secrets/`             written by `deploy` (directory 0700, files 0600):
                         the secrets the bricks declare, by kind (v0.2
                         capture W1, item 7), those with `only_with_role`
                         only when a node has the role, and a password
                         `role_<role>_password` per role a scheduler's
                         schedule names (v0.3 capture W1, items 3, 7) or
                         a node's `crontab_roles` names (v0.4 capture W1
                         item 8), one per role per game; and (master spec
                         9.7) one per login role a node's data file
                         creates without a password of its own, mounted
                         nowhere: load-data sets it. From v0.5 (capture W1
                         items 5 and 6): a certificate `<pair>.crt` and its
                         key `<pair>.key` (the game's TLS pair, `tls`), and
                         the role passwords an `api` node's `api.yaml`
                         names; an option's secret only where it is chosen;
                         (capture W2 item 2, spec D347) a password
                         `http_<credential>` per HTTP credential, mounted on
                         each node sending or checking it.

Every path an implementation records (`file:`) is relative to the scenario
folder.
"""

import contextlib
import copy
import datetime
import fcntl
import ipaddress
import os
import posixpath
import re
import secrets as _random
import tempfile
from pathlib import Path

import yaml

from .model import (CUSTOMER_TIMEZONE, POSTGRES_BRICK, POSTGRESQL_CONF, REPO_ROOT,
                    RESERVED_DB_ROLES, SUBSTITUTION_RE, GmError, has_scheduler_nodes,
                    is_scheduler_node, is_seed_folder_entry, mounted_items, node_creates,
                    parse_mode, parse_size)

PLATFORM = "swarm"
STAGES = ("fitted", "rendered", "deployed", "data-loaded", "injected", "load-started",
          "handed-over", "final-answer", "feedback-given", "torn-down")
FAILED = "failed"
TORN_DOWN = "torn-down"

PLAYGROUND_FILE = "playground.yaml"
IMPLEMENTATION_FILE = "implementation.yaml"
STATE_FILE = "state.yaml"
STATE_LOCK = ".state.lock"          # flock'd around each read-modify-write of state.yaml
STACK_FILE = "stack.yml"
ENVELOPES_DIR = "envelopes"
SECRETS_DIR = "secrets"
MOUNTED_DIR = "mounted"
RENDERED_DIR = "rendered"
TIMELINE = "timeline"               # implementation.yaml's key render writes (v0.3 W2, item 1)
TEST_OVERRIDE = "test_harness_override"     # render's undocumented --test-leave-out (W4 item 8)
OVERLAY = "overlay"                 # implementation.yaml's key deploy writes on several hosts
                                    # ({subnet}, capture W3-a, item 4; D182)
# The range a game on several hosts takes its overlay's /24 from (capture
# W3-b, D183): playground.yaml's `overlay_range`, written by `fit
# --overlay-range`, or one run's `--overlay-range` on deploy or restart;
# absent, the default. From /8 to /24, inside the private ranges.
OVERLAY_RANGE = "overlay_range"
OVERLAY_RANGE_OPTION = "--overlay-range"
DEFAULT_OVERLAY_RANGE = "10.20.0.0/16"
OVERLAY_SUBNET_PREFIX = 24
OVERLAY_RANGE_WIDEST = 8
PRIVATE_RANGES = tuple(ipaddress.ip_network(r)
                       for r in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"))

LABEL_NAMESPACE = "com.docker.stack.namespace"
LABEL_GAME = "dbagm.game"
HOSTNAME_CONSTRAINT = "node.hostname == {host}"  # every node pinned to its host (v0.3 W3, item 2)
ENVELOPES_CONFIG = "envelopes"      # the brick's protected config holding the envelope file
SEED_CONFIG_UID, SEED_CONFIG_GID, SEED_CONFIG_MODE = 0, 0, "0444"   # unless seed.modes says
SEED_KIND = "seed"
# A scheduler node's seed files render rewrites in UTC (v0.3 capture W1,
# item 7); the others are copied unchanged.
SCHEDULE_FILE, JOBS_FILE = "schedule.yaml", "jobs.yaml"
RENDERED_SCHEDULER_FILES = (SCHEDULE_FILE, JOBS_FILE)
# A postgres node's seed crontab, shifted to UTC by render (v0.4 master spec
# 8.5, capture W1 item 0); its postgresql.conf filled when it holds
# {{customer_timezone}} (cron.timezone).
CRONTAB_FILE = "crontab"
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
# v0.5 (capture W1 item 6): a certificate writes secrets/<pair>.crt and
# secrets/<pair>.key, a self-signed certificate naming every `postgres`
# node and localhost, and its private key.
PASSWORD = "password"
KEY_PAIR = "key-pair"
CERTIFICATE = "certificate"
SECRET_KINDS = (PASSWORD, KEY_PAIR, CERTIFICATE)
KEY_HALVES = ("private", "public")
PUBLIC_KEY_SUFFIX = ".pub"
CERTIFICATE_HALVES = ("certificate", "key")
CERTIFICATE_SUFFIXES = {"certificate": ".crt", "key": ".key"}
# A scheduler's connection secrets (v0.3 capture W1, item 7): one password
# per role its schedule.yaml names, derived here, never declared in
# brick.yaml; mounted root-only in each scheduler node naming the role.
# Master spec 9.7: every login role a data file creates has one too, the
# same name, set by load-data and mounted only where a schedule or a
# node's crontab_roles names the role. v0.5 (spec D345; capture W1 item
# 5): an `api` node's `api.yaml` connections name roles as a schedule's
# do; a `driver: http` connection names none, in either file.
ROLE_SECRET_PREFIX, ROLE_SECRET_SUFFIX = "role_", "_password"
ROLE_SECRET_DIR = "/opt/gm/secrets"
ROLE_SECRET_UID, ROLE_SECRET_GID, ROLE_SECRET_MODE = 0, 0, "0400"
API_BRICK = "api"                   # an api node: a node whose brick id is this (W1 item 5)
API_FILE = "api.yaml"               # its seed file naming endpoints and connections
HTTP_DRIVER = "http"                # a connection naming no role (W1 item 3)
# v0.5 HTTP credentials (spec D347; capture W1 items 0, 3 and 6, W2 item 2):
# one password `http_<credential>` per name per game, not handed over,
# mounted like a role secret on each node naming the credential: a
# scheduler node's schedule.yaml HTTP connections, an `api` node's api.yaml
# endpoints (`credentials`) and connections (`credential`), a node's
# `vault_credential` parameter (a `postgres` node's archiving).
HTTP_SECRET_PREFIX = "http_"
VAULT_CREDENTIAL = "vault_credential"

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


# --- Hosts and placement (v0.3 capture W3, items 0 to 2) ------------------

def is_list_form(pg):
    """A declaration listing its hosts (`hosts:`), not today's one-host form."""
    return isinstance(pg, dict) and "hosts" in pg


def playground_hosts(pg):
    """The declared hosts, `[{name, docker_endpoint, manager, capacity}]`.
    Today's one-host form reads as a list of one, the manager, whose name is
    None: the engine's own, which `fit` reads (W3 item 1)."""
    if is_list_form(pg):
        return [dict(h) for h in pg.get("hosts") or []]
    return [{"name": None, "docker_endpoint": pg.get("docker_endpoint"), "manager": True,
             "capacity": dict(pg.get("capacity") or {})}]


def manager_host(pg):
    """The host flagged manager (`fit` refuses a declaration without one)."""
    for host in playground_hosts(pg):
        if host.get("manager") is True:
            return host
    raise GmError("the playground declares no manager host: run gmctl fit --host ...,manager")


def designed_hosts(scenario):
    """The scenario's `designed_for.hosts` names, in order."""
    designed = (scenario.data.get("designed_for") or {})
    return [h.get("name") for h in designed.get("hosts") or [] if isinstance(h, dict)]


def node_hosts(scenario, pg, manager_name):
    """node name -> the host it is placed on (W3 item 2): on one host every
    node on it (named `manager_name` in today's form), else the node's
    designed host (`designed_for.placement`) through the mapping. Assumes
    the declaration checked (`fit.check_declaration`)."""
    hosts = playground_hosts(pg)
    if len(hosts) == 1:
        only = hosts[0].get("name") or manager_name
        return {node["name"]: only for node in scenario.nodes}
    placement = (scenario.data.get("designed_for") or {}).get("placement") or {}
    mapping = pg.get("mapping") or {}
    return {node["name"]: mapping[placement[node["name"]]] for node in scenario.nodes}


def placement_constraint(host):
    """The stack file's constraint pinning a node to its host."""
    return HOSTNAME_CONSTRAINT.format(host=host)


# --- The overlay's range (capture W3-b, D183) ------------------------------

def parse_overlay_range(text, what=OVERLAY_RANGE_OPTION):
    """`text` as the overlay's range, an IPv4Network from /8 to /24 inside
    the private ranges; GmError naming `what` otherwise."""
    hint = f"{what} {text!r}"
    try:
        net = ipaddress.ip_network(str(text).strip(), strict=False)
    except ValueError:
        raise GmError(f"{hint}: not an IPv4 CIDR range such as {DEFAULT_OVERLAY_RANGE}") \
            from None
    if net.version != 4:
        raise GmError(f"{hint}: not IPv4; the game's overlay takes an IPv4 range such as "
                      f"{DEFAULT_OVERLAY_RANGE}")
    if net.prefixlen < OVERLAY_RANGE_WIDEST:
        raise GmError(f"{hint}: wider than /{OVERLAY_RANGE_WIDEST}")
    if net.prefixlen > OVERLAY_SUBNET_PREFIX:
        raise GmError(f"{hint}: narrower than /{OVERLAY_SUBNET_PREFIX}, the size of a game's "
                      "overlay subnet")
    if net.with_prefixlen != str(text).strip():
        raise GmError(f"{hint}: host bits set; the range is {net.with_prefixlen}")
    if not any(net.subnet_of(private) for private in PRIVATE_RANGES):
        raise GmError(f"{hint}: outside the private ranges "
                      f"({', '.join(map(str, PRIVATE_RANGES))})")
    return net


def overlay_range(pg, override=None):
    """`(range, where it comes from)`: `override` (the `--overlay-range` of
    one run), else playground.yaml's `overlay_range`, else the default."""
    if override is not None:
        return parse_overlay_range(override), f"given with {OVERLAY_RANGE_OPTION}"
    declared = (pg or {}).get(OVERLAY_RANGE) if isinstance(pg, dict) else None
    if declared is not None:
        return (parse_overlay_range(declared, f"{PLAYGROUND_FILE}'s {OVERLAY_RANGE}"),
                f"playground {pg.get('name')}'s {OVERLAY_RANGE}")
    return ipaddress.ip_network(DEFAULT_OVERLAY_RANGE), "the default range"


def read_implementation(ldir):
    data = read_yaml(Path(ldir) / IMPLEMENTATION_FILE)
    if data is None:
        raise GmError(f"no local implementation in {ldir}: run gmctl fit first")
    return data


def left_out(impl):
    """The fault instances the test harness left out of this game (render's
    undocumented `--test-leave-out`, which only the harness scripts pass;
    v0.4 master spec 18 items 4 and 6, capture W4 item 8): no state
    planting and no check, their seed changes kept. Never in a game."""
    return list(((impl or {}).get(TEST_OVERRIDE) or {}).get("leave_out") or [])


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


@contextlib.contextmanager
def state_lock(ldir):
    """An exclusive `flock` on `<ldir>/.state.lock` (v0.3 capture W2, item
    0): timer runs and the GM's commands write state.yaml at the same
    moments. Held only around a read and its write, never across a Docker
    call or a script, and never taken twice by one process (flock locks
    by open file, so a nested take would wait for itself)."""
    Path(ldir).mkdir(parents=True, exist_ok=True)
    fd = os.open(Path(ldir) / STATE_LOCK, os.O_RDWR | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def update_state(ldir, change):
    """Read state.yaml, `change(state)` it in place, write it back, under
    the state lock; returns the state written. `change` returning False
    leaves the file unwritten. GmError when there is no state."""
    with state_lock(ldir):
        state = read_state(ldir)
        if state is None:
            raise GmError(f"no game state in {ldir}: run gmctl fit first")
        if change(state) is not False:
            write_state(ldir, state)
        return state


def new_state(ldir, game_id, stage, now=None):
    if stage not in STAGES:
        raise ValueError(stage)
    at = now or now_iso()
    state = {"game_id": game_id, "stage": stage, "history": [{"stage": stage, "at": at}],
             "failure": None}
    with state_lock(ldir):
        write_state(ldir, state)
    return state


def enter_stage(state, stage, at):
    """`state` (a dict) at `stage` from `at`: the history entry, any failure
    and teardown record cleared (the game went on after them)."""
    if stage not in STAGES:
        raise ValueError(stage)
    state["stage"] = stage
    state.setdefault("history", []).append({"stage": stage, "at": at})
    state["failure"] = None
    state.pop("teardown", None)
    return state


def set_stage(ldir, stage, now=None):
    """Record that the game reached `stage`; clears any failure, and any
    teardown record (the game went on after it)."""
    if stage not in STAGES:
        raise ValueError(stage)
    at = now or now_iso()
    return update_state(ldir, lambda state: enter_stage(state, stage, at) and None)


def set_failed(ldir, stage, reason, now=None):
    """Record a failure while working towards `stage` (stage becomes `failed`);
    clears any teardown record (a new failure needs a new teardown)."""
    at = now or now_iso()

    def change(state):
        state["stage"] = FAILED
        state.setdefault("history", []).append({"stage": FAILED, "at": at})
        state["failure"] = {"stage": stage, "reason": reason, "at": at}
        state.pop("teardown", None)
    return update_state(ldir, change)


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
    at = now or now_iso()
    written = []

    def change(state):
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
            written.append(record)
        return record is not None or current not in (FAILED, TORN_DOWN)
    update_state(ldir, change)
    return written[0] if written else None


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
    directory entry the scenario leaves out gives none, nor does a file of
    `seed.optional` (v0.4 capture W1 item 4: not mounted)."""
    seed = scenario.bricks[node["name"]].data.get("seed") or {}
    given = node.get("seed_files") or {}
    optional = set(seed.get("optional") or [])
    out = []
    for fname in seed.get("files") or []:
        if not is_seed_folder_entry(fname):
            if fname in optional and fname not in given:
                continue
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


def standby_of(node):
    """The primary's node name of a standby (`standby_of:`, v0.5 master
    spec 6.2, 7.1), or None for a node that is no standby."""
    primary = node.get("standby_of") if isinstance(node, dict) else None
    return primary if isinstance(primary, str) and primary else None


def standby_slot(name):
    """The physical replication slot of the standby `name` on its primary:
    its node name, `-` read as `_` (v0.5 capture W1 item 6)."""
    return str(name).replace("-", "_")


def rendered_seed_file(playground, node, fname):
    """A seed file render rewrites, relative to the scenario folder."""
    return f"local/{playground}/{RENDERED_DIR}/{node}/{fname}"


def is_postgres_node(scenario, node):
    return scenario.bricks[node["name"]].id == POSTGRES_BRICK


def _holds_customer_timezone(scenario, rel):
    try:
        return CUSTOMER_TIMEZONE in (Path(scenario.dir) / rel).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False


def rendered_seed_names(scenario, node):
    """The seed files of `node` render rewrites, in seed_entries order;
    none in a scenario without scheduler nodes, which shifts nothing (v0.3
    capture W2, item 1; D158). A scheduler node's `schedule.yaml` and
    `jobs.yaml`, and from v0.4 any other of its seed files holding
    `{{customer_timezone}}`; a bastion seed file holding it (where the
    loader looks for it, v0.3 W1 item 1); a `postgres` node's `crontab`,
    and its `postgresql.conf` when it holds it (v0.4 master spec 8.5,
    capture W1 item 0)."""
    if not has_scheduler_nodes(scenario.data):
        return []
    names = []
    for _, seed_name, rel in seed_entries(scenario, node):
        if is_scheduler_node(node):
            rewritten = seed_name in RENDERED_SCHEDULER_FILES \
                or _holds_customer_timezone(scenario, rel)
        elif is_postgres_node(scenario, node):
            rewritten = seed_name == CRONTAB_FILE or (
                seed_name == POSTGRESQL_CONF and _holds_customer_timezone(scenario, rel))
        else:
            rewritten = node.get("role") == BASTION_ROLE \
                and _holds_customer_timezone(scenario, rel)
        if rewritten:
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


def _derived_lengths(scenario, catalog_root=REPO_ROOT):
    """(name part after the game id, limit) for every derived name;
    `catalog_root` the catalogue the scenario's domains are read from."""
    parts = []
    for node in scenario.nodes:
        name = node["name"]
        brick = scenario.bricks[name].data
        parts.append((f"_{name}", SERVICE_NAME_MAX))
        for _, seed_name, _ in seed_entries(scenario, node):
            parts.append((f"_{name}_{config_file_part(seed_name)}", OBJECT_NAME_MAX))
        for pc in brick.get("protected_configs") or []:
            parts.append((f"_{name}_{pc['name']}", OBJECT_NAME_MAX))
        for sec in node_secret_declarations(scenario, node):
            parts.append((f"_{sec['name']}", OBJECT_NAME_MAX))
        for role in data_login_roles(scenario, node, catalog_root):
            parts.append((f"_{role_secret_name(role)}", OBJECT_NAME_MAX))
        # mounted material: any node of the topology may receive it
        for item in mounted_items(brick):
            files = item.get("files") or []
            parts.append((f"_{name}_{item.get('name')}-{len(files)}", OBJECT_NAME_MAX))
            for other in scenario.nodes:
                parts.append((f"_{other['name']}_{item.get('name')}.conf", OBJECT_NAME_MAX))
    return parts


def max_game_id_length(scenario, catalog_root=REPO_ROOT):
    longest = GAME_ID_MAX
    for part, limit in _derived_lengths(scenario, catalog_root):
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
    a key pair's `<pair>` (private half) or `<pair>.pub` (public half), a
    certificate's `<pair>.crt` or `<pair>.key`."""
    if sec.get("kind") == KEY_PAIR:
        return sec["pair"] + (PUBLIC_KEY_SUFFIX if sec.get("half") == "public" else "")
    if sec.get("kind") == CERTIFICATE:
        return sec["pair"] + CERTIFICATE_SUFFIXES[sec.get("half")]
    return sec["name"]


def pair_files(kind, pair):
    """The two files a key pair or a certificate of name `pair` writes."""
    if kind == CERTIFICATE:
        return [pair + CERTIFICATE_SUFFIXES[h] for h in CERTIFICATE_HALVES]
    return [pair, pair + PUBLIC_KEY_SUFFIX]


def _secret_identity(sec):
    """What two declarations of one name must agree on (capture W1, item 7)."""
    if sec.get("kind") == PASSWORD:
        return {"kind": PASSWORD, "handed_over": sec.get("handed_over") is True}
    return {"kind": sec.get("kind"), "pair": sec.get("pair"), "half": sec.get("half")}


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
        halves = KEY_HALVES if kind == KEY_PAIR else CERTIFICATE_HALVES
        pair = sec.get("pair")
        if not isinstance(pair, str) or not OBJECT_NAME_RE.match(pair):
            out.append(f"{where}: kind {kind} needs pair, the pair's name (got {pair!r})")
        if sec.get("half") not in halves:
            out.append(f"{where}: kind {kind} needs half, {' or '.join(halves)} "
                       f"(got {sec.get('half')!r})")
        if "handed_over" in sec:
            out.append(f"{where}: handed_over is for a password, not a {kind}")
    return out


def role_secret_name(role):
    return f"{ROLE_SECRET_PREFIX}{role}{ROLE_SECRET_SUFFIX}"


def is_api_node(node):
    """A node of the `api` brick (v0.5 capture W1 item 5)."""
    return isinstance(node, dict) and isinstance(node.get("brick"), dict) \
        and node["brick"].get("id") == API_BRICK


def _seed_map(scenario, node, fname, key):
    """The `key` map of the node's seed file `fname` (`{}` when the node
    seeds none, or when it cannot be read: the loader reports it)."""
    rel = (node.get("seed_files") or {}).get(fname)
    if rel is None:
        return {}
    try:
        doc = yaml.safe_load((Path(scenario.dir) / rel).read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return {}
    found = (doc or {}).get(key) if isinstance(doc, dict) else None
    return found if isinstance(found, dict) else {}


def _seed_connections(scenario, node, fname):
    """The `connections` map of the node's seed file `fname`."""
    return _seed_map(scenario, node, fname, "connections")


def api_endpoints(scenario, node):
    """An `api` node's api.yaml `endpoints` map (`{}` for another node, or
    when the file cannot be read: the loader reports it)."""
    return _seed_map(scenario, node, API_FILE, "endpoints") if is_api_node(node) else {}


def node_aliases(scenario, node):
    """The network aliases of an `api` node (v0.5 capture W2 item 2): the
    hosts its seed api.yaml's endpoints list other than its own name,
    sorted, unique; [] for another node. With the loader's v0.5 checks
    (W2 item 1) only the partners' node has any: the `third_parties:`
    hostnames, plus `owners`."""
    hosts = set()
    for endpoint in api_endpoints(scenario, node).values():
        listed = endpoint.get("hosts") if isinstance(endpoint, dict) else None
        hosts.update(h for h in (listed if isinstance(listed, list) else [])
                     if isinstance(h, str) and h)
    hosts.discard(node["name"])
    return sorted(hosts)


def schedule_connections(scenario, node):
    """A scheduler node's schedule.yaml `connections` (`{}` for another
    node, or when the file cannot be read: the loader reports it)."""
    return _seed_connections(scenario, node, SCHEDULE_FILE) if is_scheduler_node(node) else {}


def node_connections(scenario, node):
    """The connections a node's seed declares: a scheduler node's
    schedule.yaml, an `api` node's api.yaml (spec D345); `{}` for
    another node."""
    if is_scheduler_node(node):
        return schedule_connections(scenario, node)
    if is_api_node(node):
        return _seed_connections(scenario, node, API_FILE)
    return {}


def sql_connections(scenario, node):
    """node_connections without the `driver: http` ones, which name no
    role and no database (v0.5 capture W1 item 3): `{name: connection}`,
    in their order."""
    return {name: conn for name, conn in node_connections(scenario, node).items()
            if isinstance(conn, dict) and conn.get("driver") != HTTP_DRIVER}


def connection_roles(scenario, node):
    """The roles a scheduler node's schedule or an `api` node's api.yaml
    names, in first-use order; an HTTP connection names none."""
    roles = []
    for conn in sql_connections(scenario, node).values():
        role = conn.get("role")
        if isinstance(role, str) and role not in roles:
            roles.append(role)
    return roles


def http_secret_name(credential):
    return f"{HTTP_SECRET_PREFIX}{credential}"


def _credential(value):
    return value if isinstance(value, str) and value else None


def node_credentials(scenario, node, params=None):
    """The HTTP credentials a node sends or checks (v0.5 capture W2 item 2),
    in first-use order: a scheduler node's schedule.yaml HTTP connections'
    `credential`; an `api` node's api.yaml endpoints' `credentials`, then
    its HTTP connections' `credential`; the node's `vault_credential`
    parameter when its brick declares one (a `postgres` node's archiving,
    W1 item 6), as node_parameters gives it (`params`, computed when not
    given: the parameter faults applied, so a fault planting another
    credential mounts that one), else the brick's default. [] for a node
    naming none: no node holds a credential it neither sends nor checks."""
    names = []
    for endpoint in api_endpoints(scenario, node).values():
        accepted = endpoint.get("credentials") if isinstance(endpoint, dict) else None
        names += [c for c in (accepted if isinstance(accepted, list) else []) if _credential(c)]
    for conn in node_connections(scenario, node).values():
        if isinstance(conn, dict) and conn.get("driver") == HTTP_DRIVER \
                and _credential(conn.get("credential")):
            names.append(conn["credential"])
    spec = (scenario.bricks[node["name"]].data.get("parameters") or {}).get(VAULT_CREDENTIAL)
    if isinstance(spec, dict):
        values = (params if params is not None else node_parameters(scenario))[node["name"]]
        vault = _credential(values.get(VAULT_CREDENTIAL, spec.get("default")))
        if vault:
            names.append(vault)
    return list(dict.fromkeys(names))


def crontab_roles(node):
    """The roles a node's seeded crontab connects as (`crontab_roles`, v0.4
    capture W1 item 1), in their order; [] for a node with none."""
    roles = node.get("crontab_roles")
    return [r for r in roles if isinstance(r, str)] if isinstance(roles, list) else []


def data_login_roles(scenario, node, catalog_root=REPO_ROOT):
    """The login roles created on a node with no password of their own
    (model.data_file_creates: `CREATE ROLE ... LOGIN`, `CREATE USER`; one
    whose statement sets `PASSWORD '...'` keeps it), the game's own roles
    (RESERVED_DB_ROLES, pg_*) left out; [] for a node with none. Read
    through model.node_creates (v0.5 capture W2 items 1 and 2, spec D360):
    the node's data file's, in file order, then those the domains placed
    on it (and, on the partners' node, the composed domains' partner
    data.sql) create, read from `catalog_root`.
    Each has a secret `role_<role>_password`, set by load-data on the node
    (master spec 9.7)."""
    created = node_creates(Path(scenario.dir), scenario.data, node, catalog_root=catalog_root)
    return [r for r in (created.logins if created else [])
            if r not in RESERVED_DB_ROLES and not r.startswith("pg_")]


def topology_roles(scenario):
    return {n.get("role") for n in scenario.nodes}


def node_options(node):
    """The options a node chooses (`options:`, v0.5 master spec 6.8), in
    their order; [] for a node with none."""
    options = node.get("options")
    return [o for o in options if isinstance(o, str)] if isinstance(options, list) else []


def unchosen_option_secrets(brick_data, node):
    """The secrets the brick's options bring that no option the node
    chooses brings (v0.5 capture W1 item 1): declared under `secrets:`,
    mounted only on a node choosing an option that brings them."""
    chosen, brought, kept = set(node_options(node)), set(), set()
    for option in brick_data.get("options") or []:
        if not isinstance(option, dict):
            continue
        names = ((option.get("brings") or {}).get("secrets") or []) \
            if isinstance(option.get("brings"), dict) else []
        (kept if option.get("name") in chosen else brought).update(
            n for n in names if isinstance(n, str))
    return brought - kept


def node_secret_declarations(scenario, node):
    """The secrets a node mounts, as declarations: its brick's whose
    `only_with_role` condition holds (a node of the topology has that role;
    v0.3 capture W1, item 3) and that no option the node leaves off brings
    alone (v0.5 W1 item 1), then one password `role_<role>_password`,
    root-only under /opt/gm/secrets/, per role a scheduler node's schedule
    or an `api` node's api.yaml names (v0.3 W1 item 7, spec D345) or a
    node's `crontab_roles` names (v0.4 W1 item 8): one secret per role per
    game, shared by every node naming it; then (v0.5 capture W2 item 2,
    spec D347) one password `http_<credential>` per HTTP credential the
    node names (node_credentials), mounted as the role secrets are, one
    per credential per game."""
    roles = topology_roles(scenario)
    brick = scenario.bricks[node["name"]].data
    off = unchosen_option_secrets(brick, node)
    out = [sec for sec in brick.get("secrets") or []
           if (sec.get("only_with_role") is None or sec.get("only_with_role") in roles)
           and sec.get("name") not in off]
    names = [role_secret_name(role)
             for role in dict.fromkeys(connection_roles(scenario, node) + crontab_roles(node))]
    names += [http_secret_name(c) for c in node_credentials(scenario, node)]
    for name in names:
        out.append({"name": name, "kind": PASSWORD, "path": posixpath.join(ROLE_SECRET_DIR, name),
                    "uid": ROLE_SECRET_UID, "gid": ROLE_SECRET_GID, "mode": ROLE_SECRET_MODE})
    return out


def game_secrets(scenario, catalog_root=REPO_ROOT):
    """`(secrets, problems)`: the game's secrets, one per name a node
    mounts (node_secret_declarations) in topology order, then one per login
    role created on a node (data_login_roles, master spec 9.7) not among
    them, mounted nowhere; each `{"secret": name, **identity, "file": file
    in secrets/}`, and what refuses the topology (capture W1, item 7): a
    malformed declaration, a name two bricks declare differently, or a
    password whose file is a key pair's."""
    found, problems = {}, []
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        for sec in node_secret_declarations(scenario, node):
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
    for node in scenario.nodes:
        for role in data_login_roles(scenario, node, catalog_root):
            found.setdefault(role_secret_name(role), (
                scenario.bricks[node["name"]].id, {"kind": PASSWORD, "handed_over": False}))
    pairs = {(i["kind"], i["pair"]) for _, i in found.values() if i["kind"] != PASSWORD}
    written = {f: (k, p) for k, p in pairs for f in pair_files(k, p)}
    for name, (bid, identity) in found.items():
        if identity["kind"] == PASSWORD and name in written:
            kind, pair = written[name]
            problems.append(f"password {name} (brick {bid}) would be written to the file of "
                            f"{'key pair' if kind == KEY_PAIR else kind} {pair}: rename one "
                            "of them")
    for kind, pair in pairs:
        others = {k for k, p in pairs if p == pair and k != kind}
        if kind == KEY_PAIR and others:
            problems.append(f"pair {pair} is declared as a key pair and as a certificate: "
                            "rename one of them")
    secrets = [{"secret": name, **identity,
                "file": secret_file({"name": name, **identity})}
               for name, (_, identity) in found.items()]
    return secrets, problems


def _identity_text(identity):
    if identity["kind"] == PASSWORD:
        return "password" + (", handed over" if identity["handed_over"] else "")
    if identity["kind"] == CERTIFICATE:
        return f"certificate {identity['pair']}, {identity['half']} half"
    return f"key pair {identity['pair']}, {identity['half']} half"


def check_supported(scenario, catalog_root=REPO_ROOT):
    """What gmctl cannot render or deploy; [] when all is supported."""
    problems = []
    networks = scenario.data.get("networks") or []
    if len(networks) != 1:
        problems.append(f"the scenario declares {len(networks)} networks; gmctl renders one "
                        "network, <game_id>_<network name> (spec D83, D106)")
    problems += game_secrets(scenario, catalog_root)[1]
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        for pc in brick.data.get("protected_configs") or []:
            if pc.get("name") != ENVELOPES_CONFIG:
                problems.append(f"brick {brick.id} declares protected config "
                                f"{pc.get('name')}; gmctl renders only {ENVELOPES_CONFIG}")
    return problems


def implementation_secrets(scenario, playground, game_id, catalog_root=REPO_ROOT):
    """implementation.yaml's `secrets`: per game secret, its Swarm name
    `<game_id>_<name>`, its declaration and its file (relative to the
    scenario folder). GmError when the topology is refused."""
    secrets, problems = game_secrets(scenario, catalog_root)
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


def build_implementation(scenario, playground, game_id, created_at, hosts, snapshot_fit=None):
    """implementation.yaml's content (capture W2-A; v0.2: the network named
    after the scenario's, the secrets by kind, the mounted material and the
    parameter faults applied before it is derived; v0.3 W3 items 2 and 5:
    `hosts`, node name -> its host, and the snapshot's verdict; v0.5 W2
    item 2: a node's network `aliases`, when it has any, node_aliases)."""
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
        for sec in node_secret_declarations(scenario, node):
            sname = f"{gid}_{sec['name']}"
            node_secrets.append({"name": sname, "path": sec["path"], "uid": sec["uid"],
                                 "gid": sec["gid"], "mode": sec["mode"]})
        nodes[name] = {
            "brick": {"id": brick.id, "version": brick.version},
            "image": b["image"],
            "host": hosts[name],
            "resources": copy.deepcopy(node["resources"]),
            "published_ports": [{"target": p["port"], "published": p["default"],
                                 "mode": "host"} for p in node.get("published_ports") or []],
            "service": f"{gid}_{name}",
            "volumes": [{"name": f"{gid}_{name}_{v['name']}", "path": v["path"]}
                        for v in b.get("volumes") or []],
            "configs": configs,
            "secrets": node_secrets,
        }
        aliases = node_aliases(scenario, node)
        if aliases:
            nodes[name]["aliases"] = aliases
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
    if snapshot_fit is not None:
        impl["snapshot_fit"] = dict(snapshot_fit)
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
