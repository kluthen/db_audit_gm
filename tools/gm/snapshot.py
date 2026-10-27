"""`gmctl snapshot`: the hand-over snapshot (v0.3 master spec 6.4, 7.1 to
7.5 "Snapshot", 12, 13; spec D142, D147, D162, D172).

Every volume of the game is copied by its brick's method (`brick.yaml`
`snapshot:`; a brick declaring none: `stop`; the volume at `/run` never),
inside the node through the exec path, as root, one exec per step (capture
W1, item 6, and W1-x):

- `copy`: `tar --create --file=- --numeric-owner --directory=<path> .`
  while the node runs; exit 0, or 1 (a file changed while read), is a copy;
- `pg_basebackup`: `/usr/local/sbin/gm-snapshot-db`, a tar of the data
  directory holding the WAL it needs; exit 0 only;
- `stop`: the brick's services but `sshd` stopped through s6 in list order
  (`s6-svc -wD -T 60000 -d`), the volume copied as `copy` (exit 0 only),
  the services started again in reverse order (`s6-svc -wu -T 60000 -u`),
  always, a failed copy included; the node's other volumes are copied
  before the stop, to keep it short.

Where the copies live (capture W3, item 4): one Docker volume per copied
volume, on that volume's host, holding the tar stream as produced
(`volume.tar`), named `dbagm-snapshot_<game id>_<node>_<volume>` and
labelled `dbagm.snapshot=<game id>`, never `dbagm.game`, so a restart's
removal of the game's objects leaves it; teardown removes it by the game
id recorded with it. The stream reaches the copy through a helper
container on that host (`--rm`, `--pull never`, no network, the label, the
node's own image, which the host holds).

When `fit` said the copies do not fit (`implementation.yaml`'s
`snapshot_fit.fits: false`), nothing is copied and the snapshot is
recorded as not fitting (master spec 12, "Otherwise, no history").

`snapshot` needs `load-started` and the earliest hand-over reached, or
`injected` in a game with no scheduler node (D162); it is refused once the
game is handed over, when it would capture the players' changes (access
model 7). A failed snapshot is recorded (`status: failed`), its copies
removed, nothing torn down. Taking it again replaces the earlier copies.

Recorded in `state.yaml` (capture W2, item 11; chunk 11 owns all but
`status`):

    snapshot:
      status: taken | not-fitting | failed
      at: <instant it began>
      finished_at: <instant>
      game: <id of the game that took it>      # its copies' label value
      volumes: [{node, volume, method, host, copy, bytes}]
      stops: [{node, services, stopped_at, started_at}]
      why: <fit's line>                        # not-fitting
      reason: <first line of the failure>      # failed
"""

import subprocess
import tempfile
from dataclasses import dataclass, field

from . import aging, localimpl, model
from .docker import for_local_dir
from .execnode import exec_node, node_container, node_docker
from .model import GmError

SNAPSHOT_LABEL = "dbagm.snapshot"
COPY_PREFIX = "dbagm-snapshot"
TAR_NAME = "volume.tar"
COPY_MOUNT = "/snapshot"
TAKEN, NOT_FITTING, FAILED = "taken", "not-fitting", "failed"
READY = (TAKEN, NOT_FITTING)            # what `status --set handed-over` accepts (D172)
COPY, PG_BASEBACKUP, STOP = "copy", "pg_basebackup", "stop"
DEFAULT_METHOD = STOP                   # a brick that declares nothing (master spec 6.4)
RUN_PATH = "/run"                       # emptied at every start, never copied (D55)
SSHD = "sshd"                           # never stopped: the exec path and health need it
SNAPSHOT_DB = "/usr/local/sbin/gm-snapshot-db"
S6_TIMEOUT_MS = 60000
STEP_TIMEOUT = 300                      # seconds for one stop or start step


# --- Methods and names -------------------------------------------------------

def copy_name(game_id, node, volume):
    """The snapshot volume holding one volume's copy."""
    return f"{COPY_PREFIX}_{game_id}_{node}_{volume}"


def label(game_id):
    return f"{SNAPSHOT_LABEL}={game_id}"


def node_plan(scenario, node):
    """`[(volume, path, method)]` of one node, in its brick's `volumes`
    order, the volume at /run left out; the methods its `snapshot:` names,
    `stop` for every volume of a brick that declares none."""
    brick = scenario.bricks[node].data
    declared = brick.get("snapshot")
    plan = []
    for vol in brick.get("volumes") or []:
        if vol.get("path") == RUN_PATH:
            continue
        method = (declared or {}).get(vol["name"]) if declared else DEFAULT_METHOD
        plan.append((vol["name"], vol["path"], method or DEFAULT_METHOD))
    return plan


def stopped_services(scenario, node):
    """The services a `stop` stops: the brick's processes but sshd, in order."""
    return [str(p) for p in scenario.bricks[node].data.get("processes") or [] if str(p) != SSHD]


def copy_script(path):
    return f"exec tar --create --file=- --numeric-owner --directory='{path}' .\n"


DB_SCRIPT = f"exec {SNAPSHOT_DB}\n"


def stop_script(services):
    return "set -e\n" + "".join(
        f"/command/s6-svc -wD -T {S6_TIMEOUT_MS} -d /run/service/{s}\n" for s in services)


def start_script(services):
    """Every service started again, in reverse order; each one tried even
    when one before it fails."""
    lines = "".join(f"/command/s6-svc -wu -T {S6_TIMEOUT_MS} -u /run/service/{s} || rc=1\n"
                    for s in reversed(services))
    return "rc=0\n" + lines + "exit $rc\n"


# --- The stream into its copy -----------------------------------------------

def pipe(source, source_args, script, target, target_args):
    """`docker <source_args>` fed `script` on its standard input, its
    standard output streamed into `docker <target_args>` (another host's
    Docker possibly). Returns `(source status, source stderr, target status,
    target stdout, target stderr)`. The stream never passes through Python."""
    for docker in (source, target):
        ensure = getattr(docker, "ensure", None)
        if ensure is not None:
            ensure()
    with tempfile.TemporaryFile() as errors:
        try:
            src = subprocess.Popen(source.command(source_args), stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=errors)
        except FileNotFoundError:
            raise GmError("the docker command line is not installed on this host") from None
        try:
            src.stdin.write(script.encode("utf-8"))
            src.stdin.close()
            tgt = subprocess.run(target.command(target_args), stdin=src.stdout,
                                 capture_output=True, text=True)
        finally:
            src.stdout.close()
            status = src.wait()
        errors.seek(0)
        return (status, errors.read().decode("utf-8", "replace"), tgt.returncode,
                tgt.stdout or "", tgt.stderr or "")


def _one_line(text):
    lines = [line.strip() for line in (text or "").splitlines() if line.strip()]
    return lines[-1] if lines else ""


def take_copy(ldir, docker, impl, game_id, node, volume, script, accepted):
    """One volume's copy: its snapshot volume created on the node's host,
    the in-node step's tar stream written into it by a helper container.
    Returns the bytes written; GmError on a failure (the copy volume left
    for the caller to remove)."""
    host = node_docker(docker, impl, node)
    container = node_container(docker, impl, node)
    name = copy_name(game_id, node, volume)
    host.run(["volume", "create", "--label", label(game_id), name])
    image = impl["nodes"][node]["image"]
    target = ["run", "--rm", "-i", "--pull", "never", "--network", "none", "--user", "0:0",
              "--label", label(game_id), "-v", f"{name}:{COPY_MOUNT}", "--entrypoint", "sh",
              image, "-c", f"cat > {COPY_MOUNT}/{TAR_NAME} && wc -c < {COPY_MOUNT}/{TAR_NAME}"]
    status, err, t_status, t_out, t_err = pipe(
        host, ["exec", "-i", "-u", "root", container, "sh", "-s"], script, host, target)
    if t_status != 0:
        raise GmError(f"{node} {volume}: the copy could not be stored in {name}: "
                      f"{_one_line(t_err) or f'exit status {t_status}'}")
    if status not in accepted:
        raise GmError(f"{node} {volume}: exit {status}: {_one_line(err) or 'no output'}")
    try:
        return int(t_out.strip().split()[-1])
    except (ValueError, IndexError):
        raise GmError(f"{node} {volume}: the copy's size could not be read ({t_out!r})") \
            from None


def copy_volumes(scenario, impl, game_id):
    """`[(node, host, copy volume)]` the snapshot of `game_id` would hold."""
    out = []
    for node in scenario.nodes:
        name = node["name"]
        for volume, _, _ in node_plan(scenario, name):
            out.append((name, impl["nodes"][name].get("host"), copy_name(game_id, name, volume)))
    return out


def remove_copies(docker, game_id):
    """Every snapshot volume labelled with `game_id`, on every declared
    host; returns the names removed."""
    removed = []
    for host in docker.every_host():
        for name in host.lines(["volume", "ls", "-q", "--filter",
                                f"label={label(game_id)}"]):
            host.run(["volume", "rm", name])
            removed.append(name if host is docker or not docker.hosts
                           else f"{host.name}:{name}")
    return removed


# --- gmctl snapshot -----------------------------------------------------------

@dataclass
class SnapshotResult:
    game_id: str
    record: dict
    replaced: list = field(default_factory=list)
    lines: list = field(default_factory=list)

    @property
    def ok(self):
        return self.record.get("status") in READY

    def text(self):
        status = self.record.get("status")
        out = list(self.lines)
        if status == NOT_FITTING:
            out.append(f"Game {self.game_id}: the hand-over snapshot does not fit "
                       f"({self.record.get('why') or 'fit said so'}): recorded as not fitting, "
                       "nothing copied. A restart will start from nothing (no history).")
        elif status == TAKEN:
            vols = self.record.get("volumes") or []
            total = sum(v.get("bytes") or 0 for v in vols)
            out.append(f"Game {self.game_id}: hand-over snapshot taken, {len(vols)} volumes, "
                       f"{model.format_size(total)}, labelled {label(self.game_id)}.")
            for stop in self.record.get("stops") or []:
                out.append(f"  {stop['node']}: {', '.join(stop['services'])} stopped "
                           f"{stop['stopped_at']}, started again {stop['started_at']}")
        else:
            out.append(f"Game {self.game_id}: the hand-over snapshot FAILED: "
                       f"{self.record.get('reason')}")
            out.append("Recorded in state.yaml; its copies removed, nothing torn down. Run "
                       "gmctl snapshot again.")
        if self.replaced:
            out.insert(0, f"The earlier snapshot's {len(self.replaced)} copies removed.")
        return "\n".join(out)


def refusal(impl, st, now):
    """Why `snapshot` is refused (master spec 13; access model 7); None
    when it may run."""
    gid, stage = st.get("game_id"), st.get("stage")
    if stage in aging.AFTER_HANDOVER:
        return (f"game {gid} is at stage {stage}: the snapshot is refused once the game is "
                "handed over, when it would capture the players' changes")
    if not aging.aged_game(impl):
        if stage != aging.INJECT_STAGE:
            return (f"game {gid} is at stage {stage}; snapshot needs stage "
                    f"{aging.INJECT_STAGE} (a game with no scheduler node)")
        return None
    if stage != aging.LOAD_STAGE:
        return f"game {gid} is at stage {stage}; snapshot needs stage {aging.LOAD_STAGE}"
    earliest, waiting = aging.game_earliest(impl, st)
    if waiting:
        return (f"the earliest hand-over is not reached: it waits for the planting of "
                f"{', '.join(waiting)} (provisionally {aging.iso(earliest)})")
    if now < earliest:
        return (f"the earliest hand-over is {aging.iso(earliest)}, in "
                f"{aging.duration_text((earliest - now).total_seconds())}: the snapshot is "
                "refused before it")
    return None


def take(scenario_dir, playground, docker=None, now=None, clock=localimpl.now_iso):
    """`gmctl snapshot`; returns a SnapshotResult (its `ok` False when the
    snapshot failed, recorded). Raises GmError on a refusal (nothing
    done, nothing recorded)."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    impl = localimpl.read_implementation(ldir)
    gid = impl["game_id"]
    moment = now or aging.now_utc()
    why = refusal(impl, st, moment)
    if why:
        raise GmError(f"snapshot refused: {why}; nothing done")
    scenario = model.load_scenario(scenario_dir)
    began = aging.iso(moment)
    fit = impl.get("snapshot_fit") or {"fits": True}
    docker = docker or for_local_dir(ldir)
    result = SnapshotResult(gid, {})
    if fit.get("fits") is False:
        record = {"status": NOT_FITTING, "at": began, "why": fit.get("why")}
    else:
        result.replaced = remove_copies(docker, gid)
        record = {"status": TAKEN, "at": began, "game": gid, "volumes": [], "stops": []}
        try:
            for node in scenario.nodes:
                take_node(ldir, docker, impl, scenario, gid, node["name"], record, clock)
            record["finished_at"] = clock()
        except GmError as exc:
            reason = " ".join(str(exc).split())
            try:
                remove_copies(docker, gid)
            except GmError as again:
                reason += f"; removing its copies also failed: {' '.join(str(again).split())}"
            record = {"status": FAILED, "at": began, "reason": reason,
                      "stops": record.get("stops") or []}
    result.record = record

    def write(state):
        state["snapshot"] = record
    localimpl.update_state(ldir, write)
    return result


def take_node(ldir, docker, impl, scenario, gid, node, record, clock):
    """One node's copies, into `record`: every volume not stopped for
    first, then, when the node has `stop` volumes, its services stopped,
    those copied, its services started again (always)."""
    plan = node_plan(scenario, node)
    host = impl["nodes"][node].get("host")

    def one(volume, method, script, accepted):
        size = take_copy(ldir, docker, impl, gid, node, volume, script, accepted)
        record["volumes"].append({"node": node, "volume": volume, "method": method,
                                  "host": host, "copy": copy_name(gid, node, volume),
                                  "bytes": size})

    for volume, path, method in plan:
        if method == COPY:
            one(volume, method, copy_script(path), (0, 1))
        elif method == PG_BASEBACKUP:
            one(volume, method, DB_SCRIPT, (0,))
    stopped = [(v, p) for v, p, m in plan if m == STOP]
    if not stopped:
        return
    services = stopped_services(scenario, node)
    stop = {"node": node, "services": services, "stopped_at": clock(), "started_at": None}
    record["stops"].append(stop)
    failure = None
    run = exec_node(ldir, node, "root", stdin=stop_script(services), timeout=STEP_TIMEOUT,
                    docker=docker)
    if not run.ok:
        failure = f"{node}: stopping {', '.join(services)}: exit {run.returncode}: " \
                  f"{_one_line((run.stderr or '') + (run.stdout or '')) or 'no output'}"
    else:
        try:
            for volume, path in stopped:
                one(volume, STOP, copy_script(path), (0,))
        except GmError as exc:
            failure = str(exc)
    start = exec_node(ldir, node, "root", stdin=start_script(services), timeout=STEP_TIMEOUT,
                      docker=docker)
    stop["started_at"] = clock()
    if not start.ok:
        text = (f"{node}: starting {', '.join(services)} again: exit {start.returncode}: "
                f"{_one_line((start.stderr or '') + (start.stdout or '')) or 'no output'}")
        failure = f"{failure}; {text}" if failure else text
    if failure:
        raise GmError(failure)


def check_copies(docker, record):
    """The copies a taken snapshot records, each present on its host
    (`docker volume inspect`); GmError naming those missing."""
    missing = []
    for vol in record.get("volumes") or []:
        host = docker.on_host(vol.get("host"))
        try:
            proc = host.run(["volume", "inspect", "--format", "{{.Name}}", vol["copy"]],
                            check=False)
        except GmError as exc:
            missing.append(f"{vol['copy']} ({exc})")
            continue
        if proc.returncode != 0:
            missing.append(vol["copy"] + (f" on {vol['host']}" if docker.hosts else ""))
    if missing:
        raise GmError(f"the hand-over snapshot's copies are missing: {', '.join(missing)}")
