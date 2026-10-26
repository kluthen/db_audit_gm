"""`gmctl teardown`: remove everything carrying the game's label.

Master spec 11 and 12; labels fixed by capture W2-A. Services, networks
and the stack's volumes carry `com.docker.stack.namespace=<game_id>`
(Docker sets it); configs and secrets carry it and `dbagm.game=<game_id>`
(set by `gmctl deploy`); volumes carry `dbagm.game` too (the stack file).
Teardown lists every object by either label and removes those, and only
those: nothing else on the host (other stacks, the local registry,
unrelated volumes), never images, never the swarm.

Before any Docker object (v0.3 capture W2, item 5; spec D173), `gmctl
teardown` stops, disables and removes the game's host timers, the
persistent systemd user units `dbagm-<game_id>_*` (`aging`); a unit left
fails the teardown as a labelled object does.

When nothing labelled is left, `gmctl teardown` records it: stage
`torn-down` and the teardown record `{stage, reason, at}` in `state.yaml`
(`--reason`; spec D50). The teardown a failed setup step runs itself
(`state.setup_step`) records none.

v0.3, several hosts (capture W3, item 4; D179): the game's Swarm-scoped
objects (services, networks, configs, secrets) are listed and removed on
the manager, its containers and volumes on every declared host, each
through its own Docker (`docker.every_host`). A host that does not answer
fails the teardown as a labelled object left, nothing recorded. Images
stay, copied ones included, and so do the hosts' Docker contexts.
"""

import re
import time
from dataclasses import dataclass, field

from . import aging, localimpl
from .docker import for_local_dir, label_filter
from .model import GmError
from .state import record_text

LABEL_KEYS = (localimpl.LABEL_NAMESPACE, localimpl.LABEL_GAME)
# Removal order: services first (their tasks hold the rest), volumes last.
KINDS = ("service", "network", "config", "secret", "volume")
SWARM_KINDS = ("service", "network", "config", "secret")     # on the manager
LOCAL_KINDS = ("volume",)                                     # on every host, as containers
UNREACHABLE = "host"            # leftovers' kind for a host that does not answer
TEARDOWN_TIMEOUT = 120          # seconds to wait for Swarm to stop the tasks
GAME_ID_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")


def check_game_id(game_id):
    """Teardown filters on the game id: never on an empty or odd value."""
    if not isinstance(game_id, str) or not GAME_ID_RE.match(game_id):
        raise GmError(f"game id {game_id!r} is not a valid game id: nothing removed")
    return game_id


def labelled(docker, kind, game_id):
    """Names of the `kind` objects carrying either of the game's labels."""
    names = set()
    for key in LABEL_KEYS:
        names.update(docker.lines([kind, "ls", "--filter", label_filter(key, game_id),
                                   "--format", "{{.Name}}"]))
    return sorted(names)


def labelled_containers(docker, game_id):
    ids = set()
    for key in LABEL_KEYS:
        ids.update(docker.lines(["ps", "-aq", "--no-trunc",
                                 "--filter", label_filter(key, game_id)]))
    return sorted(ids)


def _where(docker, host, name):
    """An object's name, with its host's when the playground has several."""
    return name if host is docker or not docker.hosts else f"{host.name}:{name}"


def leftovers(docker, game_id):
    """{kind: [names]} still carrying the game's labels (containers
    included): Swarm-scoped kinds on the manager, containers and volumes on
    every declared host (`<host>:<name>` on several hosts); a host that does
    not answer is listed under `host`."""
    left = {kind: labelled(docker, kind, game_id) for kind in SWARM_KINDS}
    for kind in LOCAL_KINDS + ("container",):
        left.setdefault(kind, [])
    for host in docker.every_host():
        try:
            for kind in LOCAL_KINDS:
                left[kind] += [_where(docker, host, n) for n in labelled(host, kind, game_id)]
            left["container"] += [_where(docker, host, c)
                                  for c in labelled_containers(host, game_id)]
        except GmError as exc:
            left.setdefault(UNREACHABLE, []).append(
                f"{host.name or host.describe()} (not reachable: {exc})")
    return {kind: names for kind, names in left.items() if names}


@dataclass
class TeardownReport:
    game_id: str
    removed: dict = field(default_factory=dict)
    recorded: dict = None       # the teardown record written, if any
    reason_dropped: bool = False    # a reason was given, the record left unchanged
    previous: dict = None       # the record already there, if any
    timers: list = field(default_factory=list)  # the game's systemd units removed
    timer_note: str = None      # why no timer was looked for

    def count(self):
        return sum(len(v) for v in self.removed.values())

    def text(self):
        if not self.count():
            out = [f"Teardown of game {self.game_id}: nothing carrying its label was left."]
        else:
            parts = [f"{len(self.removed[k])} {k}s" for k in KINDS if self.removed.get(k)]
            out = [f"Teardown of game {self.game_id}: removed {', '.join(parts)}; "
                   "nothing carrying its label is left."]
        if self.timers:
            out.append(f"Host timers removed: {', '.join(self.timers)}; none of the game's "
                       "systemd units is left.")
        elif self.timer_note:
            out.append(f"Host timers: {self.timer_note}.")
        if self.recorded:
            out.append(f"Recorded in state.yaml: torn down "
                       f"{record_text(self.recorded).rstrip('.')}.")
        elif self.reason_dropped:
            already = (f" (torn down {record_text(self.previous)})" if self.previous else "")
            out.append(f"The teardown was already recorded{already}: left unchanged, "
                       "the reason given is not recorded.")
        return "\n".join(out)


def clean_reason(reason):
    """`--reason`, whitespace collapsed to one line; None when not given.
    An empty reason is refused."""
    if reason is None:
        return None
    text = " ".join(str(reason).split())
    if not text:
        raise GmError("--reason is empty: give the reason in words, or leave the option "
                      "out; nothing removed")
    return text


def remove_game_objects(docker, game_id, timeout=TEARDOWN_TIMEOUT, sleep=time.sleep,
                        clock=time.monotonic):
    """Remove every service, network, config, secret and volume carrying the
    game's labels; wait for Swarm to stop the tasks. Returns a
    TeardownReport, or raises GmError listing what could not be removed."""
    check_game_id(game_id)
    report = TeardownReport(game_id, {kind: [] for kind in KINDS})
    for name in labelled(docker, "service", game_id):
        docker.run(["service", "rm", name])
        report.removed["service"].append(name)
    deadline = clock() + timeout
    errors = {}

    def remove(host, kind, name):
        proc = host.run([kind, "rm", name], check=False)
        shown = _where(docker, host, name)
        if proc.returncode == 0:
            report.removed[kind].append(shown)
            errors.pop((kind, shown), None)
        else:
            errors[(kind, shown)] = " ".join((proc.stderr or "").split())

    while True:
        for kind in SWARM_KINDS[1:]:
            for name in labelled(docker, kind, game_id):
                remove(docker, kind, name)
        for host in docker.every_host():
            try:
                if labelled_containers(host, game_id):
                    continue    # a task's volumes stay in use until its container is gone
                for name in labelled(host, "volume", game_id):
                    remove(host, "volume", name)
            except GmError:
                continue        # listed by leftovers under `host`
        left = leftovers(docker, game_id)
        if not left:
            return report
        unreachable = set(left) == {UNREACHABLE}
        if unreachable or clock() >= deadline:
            what = "; ".join(f"{kind}s: {', '.join(names)}" for kind, names in left.items())
            last = "; ".join(f"{k} {n}: {e}" for (k, n), e in errors.items() if e)
            when = "" if unreachable else f" after {timeout} s"
            raise GmError(f"teardown of game {game_id} left objects{when}: {what}"
                          + (f" (last errors: {last})" if last else ""))
        sleep(1)


def teardown(scenario_dir, playground, reason=None, docker=None, timeout=TEARDOWN_TIMEOUT,
             sleep=time.sleep, clock=time.monotonic, systemd=None):
    """`gmctl teardown [--reason TEXT]`. First the game's host timers
    (aging.remove_game_timers), then every labelled object. Once nothing
    labelled is left,
    records stage `torn-down` (a failed game stays `failed` with its
    failure) and, when the state has none, the teardown record with the
    reason (`localimpl.record_teardown`). Leftovers: GmError, nothing
    recorded."""
    reason = clean_reason(reason)
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: nothing to tear down")
    impl = localimpl.read_implementation(ldir)
    game_id = impl["game_id"]
    if st.get("game_id") != game_id:
        raise GmError(f"state.yaml (game {st.get('game_id')}) and implementation.yaml "
                      f"(game {game_id}) disagree: nothing removed")
    check_game_id(game_id)
    docker = docker or for_local_dir(ldir)
    timers, note = aging.remove_game_timers(systemd or aging.Systemd(), game_id, st)
    report = remove_game_objects(docker, game_id, timeout=timeout, sleep=sleep, clock=clock)
    report.timers, report.timer_note = timers, note
    report.previous = localimpl.teardown_record(st)
    report.recorded = localimpl.record_teardown(ldir, reason)
    report.reason_dropped = reason is not None and report.recorded is None
    return report
