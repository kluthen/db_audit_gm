"""The aging: `gmctl start-load`, `gmctl inject --at`, the host timers, the
outages, the earliest hand-over, the early and hand-over checks, and the
aging's part of `gmctl status`.

v0.3 master spec 8 (its opening), 8.4, 8.5, 8.7 and 13; the records and
their forms are fixed by capture W2 in `specs/versions/v0.3/wave-log.md`
(items 2 to 5, 7, 8 and 10), the scheduler's marker and status file by
W1 item 7 and W1-y.

- Only a game with scheduler nodes ages (D157, D158). `start-load`, at
  `injected`, writes each scheduler's load-started marker holding T0,
  restarts its s6 service and waits for its status file to read
  `running`; T0 is recorded, and the stage `load-started`, once every
  scheduler runs. A scheduler that does not start is recorded and
  nothing is torn down (8.7). Once T0 is recorded the early check is
  scheduled.
- `inject --at <instant>|now --instance <id>`, at `load-started`: one
  `state` fault instance, its planting scheduled by a host timer or run
  at once; a failure is recorded, never a teardown.
- The host timers are persistent systemd user units on the host where
  `gmctl` runs, one `.timer`/`.service` pair per scheduled action, named
  `dbagm-<game_id>_<action>` (spec D173). A run started by one carries
  `DBAGM_GAME`: it refuses a playground holding another game or a torn
  down one, and first waits, up to LATE_RUN_WAIT, for the game's nodes
  to run (a late run after a host restart).
- Outages (W2 item 6, spec D152, D174): a minute after T0 in which a
  scheduler wrote no per-minute summary, or a node had no running task
  by Swarm's kept task history; read at each check and on `status`, the
  union kept, a node whose history may be pruned listed `incomplete`.
  The earliest hand-over is one function (W2 item 7, spec D175).
- `check --early-check` and `--handover-check` (W2 item 8; master spec
  8.5): every planted fault against the answer key's `at_handover`, the
  schedulers' keys and jobs, the nodes' health, the outages; recorded,
  never a teardown. `status --set handed-over` needs the earliest
  hand-over reached and a passed hand-over check run at or after it
  (W2 item 11; the snapshot's condition is chunk 11a's, spec D172).
- The test-harness override of the aging minimum (G6, spec D156, D161)
  is set by `start-load`'s undocumented `--test-aging-minimum`, which only
  the harness scripts pass; it is recorded in `state.yaml` as
  `test_harness_override` and caps the aging minimum and every
  instance's own minimum wherever the earliest hand-over counts them. It
  shortens the wait, never a clock.
"""

import datetime
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import localimpl, model
from .docker import for_local_dir, running_containers
from .execnode import exec_node
from .model import REPO_ROOT, GmError, has_scheduler_nodes, is_scheduler_node, parse_duration

UTC = datetime.timezone.utc
T0 = "T0"
INJECT_STAGE = "injected"
LOAD_STAGE = "load-started"
HANDED_OVER = "handed-over"
AFTER_HANDOVER = ("handed-over", "final-answer", "feedback-given")
STATE_KIND = "state"

GAME_ENV = "DBAGM_GAME"             # set by a host timer's service (W2 item 5)
OVERRIDE_KEY = "test_harness_override"      # state.yaml (W2 item 10)

# The scheduler node (W1 item 7, W1-y).
MARKER_DIR = "/var/lib/gm-state"
MARKER = f"{MARKER_DIR}/load-started"
SCHEDULER_SERVICE = "/run/service/scheduler"
SCHEDULER_STATUS = "/run/scheduler/status"
SCHEDULER_LOG = "/var/log/scheduler/scheduler.log"
RUNNING_WITHIN = 60                 # seconds for a scheduler's status to read running
START_TIMEOUT = 150                 # seconds for one scheduler's start script in all

# Times (W2 items 4, 5, 8).
LATE_RUN_WAIT = 600                 # seconds a timer's run waits for the game's nodes
NODE_POLL = 10                      # seconds between two looks at the nodes
MISSED_AFTER = datetime.timedelta(minutes=15)   # a planting past due with no attempt
JOB_GRACE = datetime.timedelta(minutes=10)      # a job's run started and logged
EARLY_FLOOR = datetime.timedelta(minutes=5)     # the early check at least T0 + 5 min
EARLY_BEFORE = datetime.timedelta(hours=1)      # ... and at most the earliest - 1 h
LOST_FREE_MINUTES = 30              # lost time that does not move the earliest hand-over

INSTANT_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?Z$")


# --- Times -----------------------------------------------------------------

def now_utc():
    return datetime.datetime.now(UTC).replace(microsecond=0)


def iso(moment):
    """An aware datetime as `YYYY-MM-DDTHH:MM:SSZ` (W2 item 0)."""
    return moment.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def iso_minute(moment):
    """A minute as `YYYY-MM-DDTHH:MMZ`, the scheduler's `minute=` form."""
    return moment.astimezone(UTC).strftime("%Y-%m-%dT%H:%MZ")


def parse_instant(text):
    """`YYYY-MM-DDTHH:MM:SSZ` or `YYYY-MM-DDTHH:MMZ` -> an aware datetime;
    None for None; GmError for anything else."""
    if text is None:
        return None
    if isinstance(text, datetime.datetime):
        return text.astimezone(UTC)
    m = INSTANT_RE.match(str(text))
    if m is None:
        raise GmError(f"{text!r} is not a UTC instant (YYYY-MM-DDTHH:MM:SSZ or "
                      "YYYY-MM-DDTHH:MMZ)")
    try:
        return datetime.datetime.strptime(
            f"{m.group(1)}T{m.group(2)}:{m.group(3)}:{m.group(4) or '00'}",
            "%Y-%m-%dT%H:%M:%S").replace(tzinfo=UTC)
    except ValueError:
        raise GmError(f"{text!r} is not a valid date and time") from None


def duration_text(seconds):
    """`5h12m`, `40m`, `2d3h`, `0m`: whole minutes, for the GM to read."""
    minutes = max(0, int(seconds) // 60)
    days, minutes = divmod(minutes, 1440)
    hours, minutes = divmod(minutes, 60)
    out = (f"{days}d" if days else "") + (f"{hours}h" if hours else "")
    return out + (f"{minutes}m" if minutes or not out else "")


# --- Fixed-time operations (rendered jobs.yaml) ----------------------------

def _cron_values(text, lo, hi):
    out = set()
    for part in str(text).split(","):
        step = 1
        if "/" in part:
            part, step_text = part.split("/", 1)
            step = int(step_text)
        if part == "*":
            first, last = lo, hi
        elif "-" in part:
            first, last = (int(v) for v in part.split("-", 1))
        else:
            first = last = int(part)
            if step != 1:
                last = hi
        out.update(range(first, last + 1, step))
    return out


def zone_of(name):
    """A `jobs.yaml` `timezone:` as a tzinfo: UTC when absent; the fixed
    `Etc/GMT[+-]N` zones render writes read directly (POSIX sign: UTC+N is
    `Etc/GMT-N`); any other tzdata name through zoneinfo."""
    if name in (None, "", "UTC", "Etc/UTC", "Etc/GMT"):
        return UTC
    m = re.match(r"^Etc/GMT([+-])(\d{1,2})$", str(name))
    if m:
        hours = int(m.group(2)) * (-1 if m.group(1) == "+" else 1)
        return datetime.timezone(datetime.timedelta(hours=hours))
    try:
        from zoneinfo import ZoneInfo
        return ZoneInfo(str(name))
    except Exception:
        raise GmError(f"time zone {name!r} is not known on this host") from None


def cron_first_due(at, after, zone=None, days=400):
    """The first instant at or after `after` the 5-field cron `at` names in
    `zone`: None when none falls within `days` days. Day of month and day
    of week are OR'd when both are restricted, as cron does."""
    minute, hour, dom, month, dow = str(at).split()
    minutes = sorted(_cron_values(minute, 0, 59))
    hours = sorted(_cron_values(hour, 0, 23))
    doms, months = _cron_values(dom, 1, 31), _cron_values(month, 1, 12)
    dows = {d % 7 for d in _cron_values(dow, 0, 7)}
    either = not dom.startswith("*") and not dow.startswith("*")
    tz = zone_of(zone)
    day = after.astimezone(tz).date()
    for _ in range(days):
        if day.month in months:
            dom_ok, dow_ok = day.day in doms, day.isoweekday() % 7 in dows
            if (dom_ok or dow_ok) if either else (dom_ok and dow_ok):
                for h in hours:
                    for m in minutes:
                        moment = datetime.datetime(day.year, day.month, day.day, h, m,
                                                   tzinfo=tz)
                        if moment >= after:
                            return moment.astimezone(UTC)
        day += datetime.timedelta(days=1)
    return None


def scheduler_nodes(impl):
    """The game's scheduler nodes, in topology order (W1 item 0)."""
    return [name for name, node in impl["nodes"].items()
            if (node.get("brick") or {}).get("id") == model.SCHEDULER_BRICK]


def rendered_file(ldir, node, fname):
    """A scheduler node's rendered seed file (W2 item 1), read; None when
    absent."""
    path = Path(ldir) / localimpl.RENDERED_DIR / node / fname
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, yaml.YAMLError) as exc:
        raise GmError(f"{path}: cannot be read: {' '.join(str(exc).split())}") from None


def rendered_jobs(ldir, impl):
    """[(node, job)] of every scheduler node's rendered jobs.yaml."""
    out = []
    for node in scheduler_nodes(impl):
        doc = rendered_file(ldir, node, localimpl.JOBS_FILE) or {}
        out += [(node, job) for job in doc.get("jobs") or [] if isinstance(job, dict)]
    return out


def job_first_due(job, t0):
    """A rendered job's first due instant at or after T0, or None."""
    try:
        return cron_first_due(job.get("at"), t0, job.get("timezone"))
    except (ValueError, GmError):
        return None


# --- The override and the earliest hand-over (W2 items 7, 10) --------------

def override_seconds(st):
    """The test-harness override recorded for this game, in seconds; None."""
    record = (st or {}).get(OVERRIDE_KEY) or {}
    value = record.get("aging_minimum")
    return parse_duration(value) if value else None


def override_text(st):
    return ((st or {}).get(OVERRIDE_KEY) or {}).get("aging_minimum")


def _capped(seconds, override):
    return seconds if override is None else min(seconds, override)


def instance_start(iid, entry, planting, t0):
    """(instant an instance's own minimum counts from, planted?): its
    planting, else its timer's due instant, else its planned instant; a
    T0 instance counts from T0 (W2 item 7, D175)."""
    planted = parse_instant((planting or {}).get("planted_at"))
    if (entry or {}).get("plant_at", T0) == T0:
        return t0, True
    if planted is not None:
        return max(planted, t0), True
    due = ((planting or {}).get("timer") or {}).get("due") or (entry or {}).get("planned_at")
    return max(parse_instant(due), t0) if due else t0, False


def earliest_handover(timeline, t0, plantings=None, lost_minutes=0, override=None):
    """The earliest hand-over (W2 item 7, spec D175), the one function:

        max(T0 + M, max over i of (max(P_i, T0) + m_i)) + max(0, lost - 30 min)

    M the scenario's aging minimum, m_i each instance's own, both capped
    at the test-harness override when one is set (D161); P_i its planting,
    an instance not yet planted counted at its timer's due instant, else
    its planned one, and listed. Returns (instant, [instances waiting])."""
    t0 = parse_instant(t0)
    latest = t0 + datetime.timedelta(
        seconds=_capped(parse_duration(timeline["aging_minimum"]), override))
    waiting = []
    for iid, entry in (timeline.get("instances") or {}).items():
        start, planted = instance_start(iid, entry, (plantings or {}).get(iid), t0)
        if not planted:
            waiting.append(iid)
        own = entry.get("aging_minimum")
        if own:
            latest = max(latest, start + datetime.timedelta(
                seconds=_capped(parse_duration(own), override)))
    excess = max(0, int(lost_minutes or 0) - LOST_FREE_MINUTES)
    return latest + datetime.timedelta(minutes=excess), waiting


def game_earliest(impl, st):
    """(instant, waiting) for a game whose T0 is recorded; None otherwise."""
    timeline = impl.get(localimpl.TIMELINE) or {}
    t0 = ((st or {}).get("load") or {}).get("t0")
    if not t0 or not timeline.get("aging_minimum"):
        return None
    lost = ((st or {}).get("outages") or {}).get("lost_minutes") or 0
    return earliest_handover(timeline, t0, st.get("plantings"), lost, override_seconds(st))


def early_check_due(ldir, impl, st):
    """When the early check runs (W2 item 8): the later of T0 + M/2 and,
    for every rendered job first due before the earliest hand-over, that
    instant plus 10 minutes; then at most the earliest hand-over minus
    one hour, at least T0 + 5 minutes. M capped at the override."""
    t0 = parse_instant(st["load"]["t0"])
    earliest, _ = game_earliest(impl, st)
    minimum = _capped(parse_duration(impl[localimpl.TIMELINE]["aging_minimum"]),
                      override_seconds(st))
    due = t0 + datetime.timedelta(seconds=minimum // 2)
    for _, job in rendered_jobs(ldir, impl):
        first = job_first_due(job, t0)
        if first is not None and first < earliest:
            due = max(due, first + JOB_GRACE)
    due = min(due, earliest - EARLY_BEFORE)
    return max(due, t0 + EARLY_FLOOR)


# --- Host timers (W2 item 5, spec D173) ------------------------------------

EARLY_ACTION = "early-check"


def plant_action(iid):
    return f"plant-{iid}"


def unit_prefix(game_id):
    """Every unit of a game starts with this; game ids never hold `_`."""
    return f"dbagm-{game_id}_"


def unit_name(game_id, action):
    return f"{unit_prefix(game_id)}{action}"


class SystemdUnreachable(GmError):
    """The user's systemd manager does not answer."""


class Systemd:
    """`systemctl --user` and the user unit directory, on the host where
    gmctl runs (the manager). The unit tests replace it with a fake."""

    def __init__(self, unit_dir=None, stamp_dir=None):
        config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
        self.unit_dir = Path(unit_dir) if unit_dir else config / "systemd" / "user"
        self.stamp_dir = Path(stamp_dir) if stamp_dir else data / "systemd" / "timers"

    def run(self, *args, check=True):
        try:
            proc = subprocess.run(["systemctl", "--user", *map(str, args)], text=True,
                                  capture_output=True, stdin=subprocess.DEVNULL, timeout=60)
        except FileNotFoundError:
            raise SystemdUnreachable("systemctl is not installed on this host") from None
        except subprocess.TimeoutExpired:
            raise SystemdUnreachable(f"systemctl --user {args[0]}: no answer within 60 s") \
                from None
        if check and proc.returncode != 0:
            detail = " ".join((proc.stderr or "").split()) or f"exit status {proc.returncode}"
            raise GmError(f"systemctl --user {' '.join(map(str, args[:2]))}: {detail}")
        return proc

    def reachable(self):
        try:
            return self.run("show", "--property=Version", check=False).returncode == 0
        except SystemdUnreachable:
            return False


def _exec_word(arg):
    """One ExecStart word: `%` and `$` doubled (systemd's specifiers and
    variables), quoted when it holds a space, a quote or a backslash."""
    text = str(arg).replace("%", "%%").replace("$", "$$")
    if re.search(r"[\s\"'\\;]", text) or not text:
        text = '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'
    return text


def timer_text(game_id, action, due):
    return (f"[Unit]\nDescription=db_audit_gm game {game_id}: {action}\n\n"
            f"[Timer]\nOnCalendar={due.astimezone(UTC).strftime('%Y-%m-%d %H:%M:%S')} UTC\n"
            "Persistent=true\nAccuracySec=1s\n\n"
            "[Install]\nWantedBy=timers.target\n")


def service_text(game_id, action, argv):
    return (f"[Unit]\nDescription=db_audit_gm game {game_id}: {action}\n\n"
            f"[Service]\nType=oneshot\nEnvironment={GAME_ENV}={game_id}\n"
            f"ExecStart={' '.join(_exec_word(a) for a in argv)}\n")


def gmctl_argv(verb, scenario_dir, playground, *options):
    """A timer's run: the same gmctl, by the same Python, from any directory."""
    return [sys.executable, str(REPO_ROOT / "tools" / "gmctl"), verb,
            str(Path(scenario_dir).resolve()), "--playground", playground, *options]


def create_timer(systemd, game_id, action, due, argv, now=None):
    """Write (or rewrite) the action's two units, reload, enable and start
    the timer; returns its record `{unit, due, created_at}` (W2 items 4, 5)."""
    unit = unit_name(game_id, action)
    timer_path = systemd.unit_dir / f"{unit}.timer"
    replacing = timer_path.exists()
    localimpl.write_text(systemd.unit_dir / f"{unit}.service", service_text(game_id, action, argv))
    localimpl.write_text(timer_path, timer_text(game_id, action, due))
    systemd.run("daemon-reload")
    systemd.run("enable", "--now", f"{unit}.timer")
    if replacing:
        systemd.run("restart", f"{unit}.timer")
    return {"unit": unit, "due": iso(due), "created_at": iso(now or now_utc())}


def remove_timer(systemd, unit):
    """Stop and disable one action's timer, remove its units and stamp."""
    systemd.run("disable", "--now", f"{unit}.timer", check=False)
    for path in (systemd.unit_dir / f"{unit}.timer", systemd.unit_dir / f"{unit}.service",
                 systemd.stamp_dir / f"stamp-{unit}.timer"):
        if path.exists():
            path.unlink()
    systemd.run("daemon-reload")


def _listed(proc):
    return [line.split()[0] for line in (proc.stdout or "").splitlines() if line.split()]


def game_units(systemd, game_id):
    """Every unit of the game the user manager lists (loaded or as a
    file), and every unit file of it in the unit directory."""
    pattern = f"{unit_prefix(game_id)}*"
    names = {p.name for p in systemd.unit_dir.glob(pattern)} if systemd.unit_dir.is_dir() \
        else set()
    names.update(_listed(systemd.run("list-units", "--all", "--plain", "--no-legend",
                                     pattern, check=False)))
    names.update(_listed(systemd.run("list-unit-files", "--no-legend", pattern,
                                     check=False)))
    return sorted(n for n in names if n.startswith(unit_prefix(game_id)))


def records_timer(st):
    """Whether the game's state records any timer (a planting's or the
    early check's)."""
    st = st or {}
    if (st.get("early_check") or {}).get("timer"):
        return True
    return any((p or {}).get("timer") for p in (st.get("plantings") or {}).values())


def remove_game_timers(systemd, game_id, st):
    """Teardown's part (W2 item 5): stop and disable every timer and
    service of the game, remove their unit files and stamps, reset their
    failed state, reload; then the manager must list none. Returns
    `(units removed, note)`; GmError when one is left, or when the manager
    does not answer and the state records a timer."""
    prefix = unit_prefix(game_id)
    if not systemd.reachable():
        files = sorted(p.name for p in systemd.unit_dir.glob(f"{prefix}*")) \
            if systemd.unit_dir.is_dir() else []
        if records_timer(st) or files:
            raise GmError(f"the user's systemd manager does not answer, and game {game_id} "
                          f"has host timers{': ' + ', '.join(files) if files else ''}: "
                          "nothing removed")
        return [], "the user's systemd manager does not answer; the game records no timer"
    units = game_units(systemd, game_id)
    if not units:
        return [], None
    for unit in units:
        if unit.endswith(".timer"):
            systemd.run("disable", "--now", unit, check=False)
    for unit in units:
        if unit.endswith(".service"):
            systemd.run("stop", unit, check=False)
    for path in list(systemd.unit_dir.glob(f"{prefix}*")) + \
            (list(systemd.stamp_dir.glob(f"stamp-{prefix}*")) if systemd.stamp_dir.is_dir()
             else []):
        path.unlink()
    systemd.run("reset-failed", f"{prefix}*", check=False)
    systemd.run("daemon-reload")
    left = game_units(systemd, game_id)
    if left:
        raise GmError(f"teardown of game {game_id} left host timer units: {', '.join(left)}")
    return units, None


class TimerRefused(GmError):
    """A host timer's run refused: the playground holds another game, or
    the game is torn down (W2 item 5). Nothing is recorded."""


def timer_run(st):
    """True when this run was started by a host timer (`DBAGM_GAME` set);
    TimerRefused when that timer is stale."""
    game = os.environ.get(GAME_ENV)
    if not game:
        return False
    stage = (st or {}).get("stage")
    if (st or {}).get("game_id") != game or stage in (localimpl.TORN_DOWN, localimpl.FAILED) \
            or localimpl.teardown_record(st):
        raise TimerRefused(f"a host timer of game {game}: the playground holds game "
                           f"{(st or {}).get('game_id')} at stage {stage}; nothing done, "
                           "nothing recorded")
    return True


def wait_for_nodes(docker, impl, bound=LATE_RUN_WAIT, sleep=time.sleep, clock=time.monotonic,
                   interval=NODE_POLL):
    """A timer's run first waits, up to `bound` seconds, for every node of
    the game to have a running container (spec D173). Returns the nodes
    still not running ([] when all run)."""
    deadline = clock() + bound
    while True:
        down = []
        for name, node in impl["nodes"].items():
            try:
                if not running_containers(docker, node["service"]):
                    down.append(name)
            except GmError:
                down.append(name)
        if not down or clock() >= deadline:
            return down
        sleep(interval)


# --- Common ------------------------------------------------------------------

def _game(scenario_dir, playground):
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    return ldir, st


def first_line(result):
    from .inject import output_lines
    lines = output_lines(result)
    return lines[0] if lines else f"exit status {result.returncode}, no output"


# --- start-load (W2 items 2, 3) ----------------------------------------------

START_SCRIPT = f"""set -eu
d={MARKER_DIR}
t=$(mktemp "$d/.load-started.XXXXXX")
printf '%s\\n' "$GM_T0" > "$t"
chown root:scheduler "$t"
chmod 0440 "$t"
mv -f "$t" {MARKER}
/command/s6-svc -r {SCHEDULER_SERVICE}
line=
i=0
while [ "$i" -lt {RUNNING_WITHIN} ]; do
    line=$(cat {SCHEDULER_STATUS} 2>/dev/null || true)
    case "$line" in
        "running "*)
            if expr "x${{line#running }}" \\>= "x$GM_T0" >/dev/null; then
                printf '%s\\n' "$line"
                exit 0
            fi ;;
    esac
    sleep 1
    i=$((i + 1))
done
echo "status did not read running within {RUNNING_WITHIN} s (last: ${{line:-none}})"
exit 1
"""


@dataclass
class StartLoadResult:
    game_id: str
    began: str
    nodes: dict = field(default_factory=dict)       # node -> {outcome, running_at | reason}
    t0: str = None
    override: str = None
    early_check: dict = None                        # the timer's record
    early_error: str = None
    plantings: list = field(default_factory=list)   # [(instance, command)]

    @property
    def ok(self):
        return bool(self.t0) and not self.early_error

    def text(self):
        out = [f"Game {self.game_id}: starting the load at {self.began}."]
        for node, rec in self.nodes.items():
            out.append(f"  {node}: running since {rec.get('running_at')}"
                       if rec.get("outcome") == "ok" else f"  {node}: FAILED: {rec.get('reason')}")
        if not self.t0:
            bad = [n for n, r in self.nodes.items() if r.get("outcome") != "ok"]
            out.append(f"T0 not recorded: {len(bad)} scheduler(s) did not start ({', '.join(bad)}); "
                       "nothing torn down. Fix it and run gmctl start-load again, or stop the "
                       "game (gmctl teardown). Stage injected.")
            return "\n".join(out)
        out.append(f"Load started: T0 {self.t0}. Stage {LOAD_STAGE}.")
        if self.early_check:
            out.append(f"Early check scheduled at {self.early_check['due']} "
                       f"(timer {self.early_check['unit']}).")
        if self.early_error:
            out.append(f"The early check could NOT be scheduled: {self.early_error}")
        if self.plantings:
            out.append("Plantings to schedule now (master spec 8.7):")
            out += [f"  {command}" for _, command in self.plantings]
        return "\n".join(out)


def check_override(text, timeline):
    """`--test-aging-minimum`: a duration of at least one minute, shorter
    than the scenario's aging minimum."""
    try:
        seconds = parse_duration(text)
    except ValueError as exc:
        raise GmError(f"--test-aging-minimum: {exc}") from None
    minimum = parse_duration(timeline["aging_minimum"])
    if not 60 <= seconds < minimum:
        raise GmError(f"--test-aging-minimum {text}: give at least 1m and less than the "
                      f"scenario's aging minimum {timeline['aging_minimum']}")
    return text


def start_load(scenario_dir, playground, docker=None, systemd=None, test_aging_minimum=None,
               out=print, now=None):
    """`gmctl start-load`; returns a StartLoadResult. Raises GmError on a
    refusal (nothing done). A scheduler that does not start is recorded,
    nothing is torn down and the stage stays `injected` (8.7)."""
    ldir, st = _game(scenario_dir, playground)
    gid, stage = st.get("game_id"), st.get("stage")
    scenario = model.load_scenario(scenario_dir)
    if not has_scheduler_nodes(scenario.data):
        raise GmError(f"game {gid} has no scheduler node, so it has no aging and no load to "
                      "start (D157)")
    if stage == LOAD_STAGE:
        raise GmError(f"game {gid}: the load already started, T0 "
                      f"{(st.get('load') or {}).get('t0')}; nothing done")
    if stage in AFTER_HANDOVER:
        raise GmError(f"game {gid} is at stage {stage}: start-load is refused once handed "
                      "over; nothing done")
    if stage != INJECT_STAGE:
        raise GmError(f"game {gid} is at stage {stage}; start-load needs stage {INJECT_STAGE} "
                      "(run gmctl inject)")
    impl = localimpl.read_implementation(ldir)
    timeline = impl.get(localimpl.TIMELINE) or {}
    if not timeline.get("aging_minimum"):
        raise GmError(f"game {gid} has no timeline in implementation.yaml: run gmctl render "
                      "with --handover")
    override = check_override(test_aging_minimum, timeline) if test_aging_minimum else None
    docker = docker or for_local_dir(ldir)
    began = now or now_utc()
    result = StartLoadResult(gid, iso(began))

    for node in scheduler_nodes(impl):
        try:
            run = exec_node(ldir, node, "root", stdin=START_SCRIPT, env={"GM_T0": iso(began)},
                            timeout=START_TIMEOUT, docker=docker)
        except GmError as exc:
            result.nodes[node] = {"outcome": "failed",
                                  "reason": f"could not run on the node: {exc}"}
            continue
        if run.ok:
            line = first_line(run)
            result.nodes[node] = {"outcome": "ok",
                                  "running_at": line.split(" ", 1)[1] if " " in line else line}
        else:
            result.nodes[node] = {"outcome": "failed", "reason": first_line(run)}
    started = all(rec["outcome"] == "ok" for rec in result.nodes.values())
    recorded_at = localimpl.now_iso() if now is None else iso(now)

    def record(state):
        load = state.setdefault("load", {"t0": None, "attempts": []})
        load.setdefault("attempts", []).append({"began": iso(began), "nodes": result.nodes})
        if override:
            state[OVERRIDE_KEY] = {"aging_minimum": override, "set_at": recorded_at}
        if started:
            load["t0"] = iso(began)
            localimpl.enter_stage(state, LOAD_STAGE, recorded_at)
            write_earliest(state, impl, began)
    st = localimpl.update_state(ldir, record)
    result.override = override_text(st)
    if not started:
        return result
    result.t0 = iso(began)

    systemd = systemd or Systemd()
    try:
        due = early_check_due(ldir, impl, st)
        timer = create_timer(systemd, gid, EARLY_ACTION, due,
                             gmctl_argv("check", scenario_dir, playground, "--early-check"))
        result.early_check = timer
    except GmError as exc:
        timer, result.early_error = None, str(exc)

    def record_early(state):
        state["early_check"] = {"timer": timer, "result": None}
        if result.early_error:
            state["early_check"]["scheduling_failed"] = result.early_error
    localimpl.update_state(ldir, record_early)

    current = now_utc() if now is None else now
    for iid, planting in (st.get("plantings") or {}).items():
        if planting.get("planted_at") or not planting.get("planned_at"):
            continue
        planned = parse_instant(planting["planned_at"])
        at = iso(planned) if planned > current else "now"
        result.plantings.append((iid, f"tools/gmctl inject {scenario_dir} --playground "
                                      f"{playground} --at {at} --instance {iid}"))
    return result


# --- inject --at (W2 item 4) -------------------------------------------------

@dataclass
class PlantResult:
    game_id: str
    instance: str
    scheduled: dict = None          # the timer's record, when scheduled
    attempt: dict = None            # the attempt's record, when run
    nodes_down: list = field(default_factory=list)
    early_moved: dict = None

    @property
    def ok(self):
        return self.scheduled is not None or (self.attempt or {}).get("outcome") == "ok"

    def text(self):
        if self.scheduled:
            out = [f"Game {self.game_id}: the planting of {self.instance} is scheduled at "
                   f"{self.scheduled['due']} (timer {self.scheduled['unit']})."]
        elif self.ok:
            out = [f"Game {self.game_id}: {self.instance} planted at {self.attempt['at']}."]
        else:
            out = [f"Game {self.game_id}: the planting of {self.instance} FAILED: "
                   f"{self.attempt.get('reason')}",
                   "Recorded in state.yaml; nothing torn down, the stage unchanged. Re-plant "
                   f"with gmctl inject --at now --instance {self.instance}."]
        if self.nodes_down:
            out.insert(0, f"Nodes not running after {LATE_RUN_WAIT} s: "
                          f"{', '.join(self.nodes_down)}; planting anyway.")
        if self.early_moved:
            out.append(f"The early check moves earlier, to {self.early_moved['due']}.")
        return "\n".join(out)


def _instance(scenario, impl, iid):
    from .inject import fault_instances
    pairs = {inst["id"]: (inst, fault) for inst, fault in fault_instances(scenario)}
    if iid not in pairs:
        raise GmError(f"--instance {iid}: not a fault instance of the scenario "
                      f"({', '.join(pairs) or 'none'})")
    inst, fault = pairs[iid]
    kind = (fault.data.get("injection") or {}).get("kind")
    if kind != STATE_KIND:
        raise GmError(f"--instance {iid}: fault {fault.id} is a {kind} fault, planted at "
                      "render (master spec 6.1); only a state fault is planted by inject --at")
    entry = ((impl.get(localimpl.TIMELINE) or {}).get("instances") or {}).get(iid) or {}
    if entry.get("plant_at", inst.get("plant_at") or T0) == T0:
        raise GmError(f"--instance {iid} is planted at T0: the GM re-plants only a fault whose "
                      "planting failed, and a T0 planting never fails without a teardown "
                      "(master spec 8.5)")
    return inst, fault, entry


def _refuse_stage(ldir, st, iid, by_timer, now):
    gid, stage = st.get("game_id"), st.get("stage")
    if stage in AFTER_HANDOVER:
        reason = f"game {gid} is at stage {stage}: inject --at is refused at or after hand-over"
        if by_timer:
            def record(state):
                p = (state.setdefault("plantings", {})).setdefault(iid, {})
                p.setdefault("attempts", []).append(
                    {"at": iso(now), "by": "timer", "outcome": "refused", "reason": reason})
            localimpl.update_state(ldir, record)
        raise GmError(reason + "; nothing done")
    if stage != LOAD_STAGE:
        raise GmError(f"game {gid} is at stage {stage}; inject --at needs stage {LOAD_STAGE} "
                      "(run gmctl start-load; a game with no scheduler node has no aging and "
                      "plants every fault with gmctl inject)")


def inject_at(scenario_dir, playground, at, instance, timeout=None, docker=None, systemd=None,
              out=print, now=None, sleep=time.sleep, clock=time.monotonic):
    """`gmctl inject --at <instant>|now --instance <id>`; returns a
    PlantResult. Raises GmError on a refusal (nothing done; a timer's run
    refused at hand-over records its attempt). A failing planting is
    recorded, tears nothing down and leaves the stage (8.7)."""
    ldir, st = _game(scenario_dir, playground)
    by_timer = timer_run(st)
    current = now or now_utc()
    if at != "now":
        when = parse_instant(at)
    _refuse_stage(ldir, st, instance, by_timer, current)
    scenario = model.load_scenario(scenario_dir)
    impl = localimpl.read_implementation(ldir)
    gid = impl["game_id"]
    inst, fault, entry = _instance(scenario, impl, instance)
    planting = (st.get("plantings") or {}).get(instance) or {}
    systemd = systemd or Systemd()
    result = PlantResult(gid, instance)

    if at != "now":
        if when <= current:
            raise GmError(f"--at {at} is not in the future: plant at once with --at now")
        planned = parse_instant((impl.get(localimpl.TIMELINE) or {}).get("planned_handover"))
        if planned is not None and when >= planned:
            raise GmError(f"--at {at} is at or after the planned hand-over {iso(planned)}: "
                          "a planting never falls at or after hand-over (master spec 8.4); "
                          "--at now is bounded only by the stage")
        if planting.get("planted_at"):
            raise GmError(f"{instance} is already planted ({planting['planted_at']}): "
                          "re-plant with --at now")
        timer = create_timer(systemd, gid, plant_action(instance), when,
                             gmctl_argv("inject", scenario_dir, playground, "--at", "now",
                                        "--instance", instance), now=current)
        result.scheduled = timer

        def record(state):
            p = state.setdefault("plantings", {}).setdefault(instance, {})
            p.setdefault("plant_at", entry.get("plant_at"))
            p.setdefault("planned_at", entry.get("planned_at"))
            p["timer"] = timer
            p.setdefault("attempts", [])
            p.setdefault("planted_at", None)
            write_earliest(state, impl, current)
        st = localimpl.update_state(ldir, record)
        result.early_moved = move_early_check(ldir, scenario_dir, playground, impl, st, systemd,
                                              current)
        return result

    from .inject import _print_run, inject_plan
    docker = docker or for_local_dir(ldir)
    live = planting.get("timer")
    if live and not by_timer:
        remove_timer(systemd, live["unit"])
    if by_timer:
        result.nodes_down = wait_for_nodes(docker, impl, sleep=sleep, clock=clock)
    plan = [p for p in inject_plan(scenario, impl) if p[0] == instance]
    started = now or now_utc()
    attempt = {"at": iso(started), "by": "timer" if by_timer else "gmctl", "outcome": "ok"}
    try:
        for iid, _, node, run_as, env, scripts in plan:
            for script, text in scripts:
                run = exec_node(ldir, node, run_as, stdin=text, env=env, timeout=timeout,
                                docker=docker)
                _print_run(out, f"{iid} {script} ({node}, as {run_as})", run)
                if not run.ok:
                    raise GmError(f"{script}: exit {run.returncode}: {first_line(run)}")
    except GmError as exc:
        attempt.update(outcome="failed", reason=" ".join(str(exc).split()))
    result.attempt = attempt

    def record(state):
        p = state.setdefault("plantings", {}).setdefault(instance, {})
        p.setdefault("plant_at", entry.get("plant_at"))
        p.setdefault("planned_at", entry.get("planned_at"))
        if live and not by_timer:
            p["timer"] = None
        p.setdefault("timer", None)
        p.setdefault("attempts", []).append(attempt)
        if attempt["outcome"] == "ok":
            p["planted_at"] = attempt["at"]
        p.setdefault("planted_at", None)
        write_earliest(state, impl, current)
    st = localimpl.update_state(ldir, record)
    if attempt["outcome"] == "ok":
        result.early_moved = move_early_check(ldir, scenario_dir, playground, impl, st, systemd,
                                              current)
    return result


def move_early_check(ldir, scenario_dir, playground, impl, st, systemd, now):
    """After an `inject --at` brings the earliest hand-over earlier, the
    early check's timer moves earlier so it stays no later than the
    earliest hand-over minus one hour, never before T0 + 5 minutes nor
    in the past; it never moves later (W2 item 8). Returns the new timer
    record, or None when unchanged."""
    early = st.get("early_check") or {}
    timer = early.get("timer")
    if not timer or early.get("result") is not None:
        return None
    earliest, _ = game_earliest(impl, st)
    t0 = parse_instant(st["load"]["t0"])
    due = parse_instant(timer["due"])
    new = max(min(due, earliest - EARLY_BEFORE), t0 + EARLY_FLOOR,
              now + datetime.timedelta(minutes=1))
    if new >= due:
        return None
    moved = create_timer(systemd, st["game_id"], EARLY_ACTION, new,
                         gmctl_argv("check", scenario_dir, playground, "--early-check"), now=now)

    def record(state):
        state.setdefault("early_check", {})["timer"] = moved
    localimpl.update_state(ldir, record)
    return moved


# --- Reading the schedulers and the task history (W2 items 6, 8) -----------

READ_SCRIPT = f"""printf 'status %s\\n' "$(cat {SCHEDULER_STATUS} 2>/dev/null)"
[ -f {SCHEDULER_LOG} ] || exit 0
grep -E '^[^ ]+ (summary|key|run|skip|job) ' {SCHEDULER_LOG}
[ $? -le 1 ]
"""
_FIELD_RE = re.compile(r'([a-z_0-9]+)=("(?:[^"\\]|\\.)*"|\S+)')


@dataclass
class SchedulerReading:
    """What one scheduler node's status file and log say (W1 item 7, W1-y)."""
    node: str
    status: str = ""
    summaries: set = field(default_factory=set)     # minutes with a summary line
    keys: dict = field(default_factory=dict)        # minute -> keys with a key line
    runs: dict = field(default_factory=dict)        # job -> instants of run phase=start / skip
    never: set = field(default_factory=set)         # jobs with a `job ... next=never` line

    @property
    def running(self):
        return self.status.startswith("running ")

    def last_minute(self):
        return max(self.summaries) if self.summaries else None


def parse_scheduler_output(node, text):
    reading = SchedulerReading(node)
    for line in (text or "").splitlines():
        if line.startswith("status "):
            reading.status = line[len("status "):].strip()
            continue
        parts = line.split(" ", 2)
        if len(parts) < 3:
            continue
        stamp, event, rest = parts
        fields = {k: v.strip('"') for k, v in _FIELD_RE.findall(rest)}
        if event == "summary" and "minute" in fields:
            reading.summaries.add(fields["minute"])
        elif event == "key" and "minute" in fields:
            reading.keys.setdefault(fields["minute"], set()).add(fields.get("key"))
        elif (event == "run" and fields.get("phase") == "start") or event == "skip":
            reading.runs.setdefault(fields.get("job"), []).append(stamp)
        elif event == "job" and fields.get("next") == "never":
            reading.never.add(fields.get("job"))
    return reading


def read_scheduler(ldir, node, docker):
    """One scheduler node's reading; GmError when it cannot be read."""
    run = exec_node(ldir, node, "root", stdin=READ_SCRIPT, docker=docker, timeout=120)
    if not run.ok:
        raise GmError(f"{node}: its log could not be read: {first_line(run)}")
    return parse_scheduler_output(node, run.stdout if isinstance(run.stdout, str)
                                  else (run.stdout or b"").decode("utf-8", "replace"))


ZERO_TIME = "0001-01-01T00:00:00Z"


def docker_instant(text):
    """A Docker timestamp (`2026-10-26T20:00:07.123456789Z`) -> aware
    datetime; None for an empty or zero one."""
    if not text or str(text).startswith("0001-01-01"):
        return None
    m = re.match(r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})$", str(text))
    if m is None:
        raise GmError(f"{text!r} is not a Docker timestamp")
    moment = datetime.datetime.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S")
    if m.group(2):
        moment = moment.replace(microsecond=int(m.group(2)[1:7].ljust(6, "0")))
    zone = UTC if m.group(3) == "Z" else datetime.datetime.strptime(m.group(3), "%z").tzinfo
    return moment.replace(tzinfo=zone).astimezone(UTC)


@dataclass
class TaskHistory:
    periods: list = field(default_factory=list)     # [(start, end or None)] a task ran
    oldest: datetime.datetime = None                # the oldest kept task's creation


def task_history(docker, service):
    """When the service's tasks ran, from Swarm's kept task history (master
    spec 20): each task with a container counts from its container's start
    (its creation when the container is gone) to its end (still running:
    open). GmError when it cannot be read."""
    import json
    ids = docker.lines(["service", "ps", "-q", "--no-trunc", service])
    history = TaskHistory()
    if not ids:
        return history
    for line in docker.lines(["inspect", "--type", "task", "--format", "{{json .}}", *ids]):
        try:
            task = json.loads(line)
        except ValueError:
            raise GmError(f"service {service}: its task history could not be read") from None
        created = docker_instant(task.get("CreatedAt"))
        if created and (history.oldest is None or created < history.oldest):
            history.oldest = created
        status = task.get("Status") or {}
        container = (status.get("ContainerStatus") or {}).get("ContainerID")
        if not container:
            continue                    # never started (pending, rejected)
        state = status.get("State")
        started = ended = None
        proc = docker.run(["inspect", "--type", "container", "--format",
                           "{{.State.StartedAt}} {{.State.FinishedAt}}", container], check=False)
        if proc.returncode == 0 and (proc.stdout or "").split():
            fields = proc.stdout.split()
            started = docker_instant(fields[0])
            ended = docker_instant(fields[1]) if len(fields) > 1 else None
        if state == "running":
            started, ended = started or docker_instant(status.get("Timestamp")), None
        else:
            started = started or created
            ended = ended or docker_instant(status.get("Timestamp"))
        if started:
            history.periods.append((started, ended))
    return history


# --- Outages and the lost time (W2 item 6, spec D152, D174) -----------------

MINUTE = datetime.timedelta(minutes=1)
SUMMARY_DELAY = datetime.timedelta(seconds=15)


def floor_minute(moment):
    return moment.replace(second=0, microsecond=0)


def outage_span(t0, now, end=None):
    """(first, last) minutes judged: from the first whole minute after T0
    to the last minute M with M + 1 min + 15 s at or before `now`, never
    past `end` (the hand-over)."""
    first = floor_minute(t0) + MINUTE
    last = floor_minute(now - MINUTE - SUMMARY_DELAY)
    if end is not None:
        last = min(last, floor_minute(end) - MINUTE)
    return first, last


def covered(periods, start, end):
    """Whether the periods cover [start, end) without a gap."""
    reach = start
    for p_start, p_end in sorted(periods, key=lambda p: p[0]):
        if p_start > reach:
            break
        if p_end is None:
            return True
        reach = max(reach, p_end)
        if reach >= end:
            return True
    return reach >= end


def outage_minutes(first, last, summaries, histories, known_from=None):
    """{minute: [causes]} for every outage minute from `first` to `last`
    (8.7): a scheduler with no summary for it (`summaries`: node -> its
    minutes), or a node with no running task during part of it
    (`histories`: node -> [(start, end)]). A minute before `known_from`
    (node -> the oldest kept task's creation) is not judged by that node's
    history: Swarm pruned what it held, so the lost time is a lower bound
    (D174)."""
    out = {}
    known_from = known_from or {}
    minute = first
    while minute <= last:
        name = iso_minute(minute)
        causes = [f"{node}: no summary" for node, minutes in summaries.items()
                  if name not in minutes]
        causes += [f"{node}: no running task" for node, periods in histories.items()
                   if (known_from.get(node) is None or minute >= known_from[node])
                   and not covered(periods, minute, minute + MINUTE)]
        if causes:
            out[name] = causes
        minute += MINUTE
    return out


def period_minutes(periods):
    """Recorded periods -> {minute: [causes]}."""
    out = {}
    for period in periods or []:
        minute, to = parse_instant(period["from"]), parse_instant(period["to"])
        while minute <= to:
            out[iso_minute(minute)] = list(period.get("causes") or [])
            minute += MINUTE
    return out


def merge_periods(minutes):
    """{minute: [causes]} -> periods, runs of consecutive minutes, oldest
    first, each with its minutes and the union of its causes."""
    periods = []
    for name in sorted(minutes):
        moment = parse_instant(name)
        if periods and parse_instant(periods[-1]["to"]) + MINUTE == moment:
            period = periods[-1]
            period["to"], period["minutes"] = name, period["minutes"] + 1
        else:
            period = {"from": name, "to": name, "minutes": 1, "causes": []}
            periods.append(period)
        period["causes"] += [c for c in minutes[name] if c not in period["causes"]]
    return periods


def handover_instant(st):
    for entry in reversed((st or {}).get("history") or []):
        if entry.get("stage") == HANDED_OVER:
            return parse_instant(entry.get("at"))
    return None


def read_outages(ldir, impl, st, docker, now, readings=None):
    """One reading of the outages (W2 item 6), recorded under `outages`,
    keeping the union with the minutes already recorded. A node that
    cannot be read leaves the record as it was, with `unread`. Returns
    (record, {node: SchedulerReading or GmError})."""
    t0 = parse_instant(st["load"]["t0"])
    previous = st.get("outages") or {}
    readings = dict(readings or {})
    error = None
    for node in scheduler_nodes(impl):
        if node not in readings:
            try:
                readings[node] = read_scheduler(ldir, node, docker)
            except GmError as exc:
                readings[node] = exc
        if isinstance(readings[node], GmError):
            error = error or f"{node}: {readings[node]}"
    histories = {}
    for name, node in impl["nodes"].items():
        try:
            histories[name] = task_history(docker, node["service"])
        except GmError as exc:
            error = error or f"{name}: {exc}"
    if error:
        record = dict(previous, unread={"at": iso(now), "reason": " ".join(error.split())})
        return record, readings
    first, last = outage_span(t0, now, handover_instant(st))
    seen = outage_minutes(first, last, {n: r.summaries for n, r in readings.items()},
                          {n: h.periods for n, h in histories.items()},
                          {n: h.oldest for n, h in histories.items()})
    merged = period_minutes(previous.get("periods"))
    for name, causes in seen.items():
        merged[name] = list(dict.fromkeys(merged.get(name, []) + causes))
    since = parse_instant(previous.get("read_at")) or t0
    incomplete = list(previous.get("incomplete") or [])
    for name, history in histories.items():
        if history.oldest is not None and history.oldest > since and name not in incomplete:
            incomplete.append(name)
    record = {"read_at": iso(now),
              "through": iso_minute(last) if last >= first else previous.get("through"),
              "lost_minutes": len(merged), "periods": merge_periods(merged),
              "incomplete": incomplete}
    return record, readings


def lost_text(outages):
    lost = (outages or {}).get("lost_minutes") or 0
    return f"{'at least ' if (outages or {}).get('incomplete') else ''}{lost} min"


# --- The early check and the hand-over check (W2 item 8) -------------------

EARLY_CHECK, HANDOVER_CHECK = "early-check", "handover-check"
PASSED, FAILED_CHECK, CANNOT, TOO_SOON_ONLY = 0, 1, 2, 3


def at_handover(scenario, iid):
    for entry in (scenario.answer_key or {}).get("instances") or []:
        if isinstance(entry, dict) and entry.get("instance") == iid:
            value = (entry.get("sealed_check") or {}).get("at_handover")
            return 1 if value is None else int(value)
    return 1


def planting_problem(iid, planting, now):
    """`(kind, text)` of an instance planted later whose planting needs the
    GM: its last attempt failed, its planting missed (W2 item 4: its
    timer due more than 15 minutes ago with no attempt since), or its
    planned instant past with no timer and no planting (W2 item 11); None
    otherwise."""
    if not planting or planting.get("plant_at", T0) == T0:
        return None
    attempts = planting.get("attempts") or []
    last = attempts[-1] if attempts else None
    if last and last.get("outcome") == "failed":
        return "failed", (f"{iid}: its planting failed at {last.get('at')}: "
                          f"{last.get('reason')}")
    if planting.get("planted_at"):
        return None
    timer = planting.get("timer")
    due = parse_instant((timer or {}).get("due") or planting.get("planned_at"))
    if due is None:
        return None
    if not timer:
        if now <= due:
            return None
        return "unscheduled", f"{iid}: planned at {iso(due)}, neither scheduled nor planted"
    if now <= due + MISSED_AFTER or (last and parse_instant(last.get("at")) >= due):
        return None
    return "missed", f"{iid}: its planting due {iso(due)} has not run"


def current_keys(ldir, node, minute):
    """The stream keys of a scheduler current in `minute` (W1 item 7): each
    stream's initial key, changed by every timeline `set: {key}` at or
    before the minute's start."""
    doc = rendered_file(ldir, node, localimpl.SCHEDULE_FILE) or {}
    keys = {s.get("key"): s.get("key") for s in doc.get("streams") or [] if isinstance(s, dict)}
    start = parse_instant(minute)
    changes = sorted((c for c in doc.get("timeline") or [] if isinstance(c, dict)),
                     key=lambda c: str(c.get("at")))
    for change in changes:
        try:
            when = parse_instant(change.get("at"))
        except GmError:
            continue
        new = (change.get("set") or {}).get("key")
        if when <= start and new and change.get("stream") in keys:
            keys[change["stream"]] = new
    return sorted(set(keys.values()))


def judge_scheduler(ldir, impl, node, reading, t0, now):
    """(entry, failures) for one scheduler node (W2 item 8 (b))."""
    if isinstance(reading, GmError):
        return {"node": node, "running": None, "error": str(reading)}, \
            [f"{node}: could not be read: {reading}"]
    failures = []
    entry = {"node": node, "running": reading.running, "keys": {}, "jobs": {}}
    if not reading.running:
        failures.append(f"{node}: the scheduler is not running (status: "
                        f"{reading.status or 'none'})")
    minute = reading.last_minute()
    if minute is None:
        failures.append(f"{node}: no per-minute summary yet")
    else:
        entry["minute"] = minute
        lines = reading.keys.get(minute, set())
        for key in current_keys(ldir, node, minute):
            entry["keys"][key] = key in lines
            if key not in lines:
                failures.append(f"{node}: key {key} has no line in minute {minute}")
    for job_node, job in rendered_jobs(ldir, impl):
        if job_node != node:
            continue
        name = job.get("name")
        first = job_first_due(job, t0)
        if name in reading.never:
            verdict = "never"
            failures.append(f"{node}: job {name} will never run again (next=never)")
        elif first is None or first + JOB_GRACE > now:
            verdict = "not-due"
        elif any(parse_instant(t) >= first for t in reading.runs.get(name, [])
                 if INSTANT_RE.match(t)):
            verdict = "ran"
        else:
            verdict = "missed"
            failures.append(f"{node}: job {name}, due {iso(first)}, has not run")
        entry["jobs"][name] = verdict
    return entry, failures


@dataclass
class CheckRun:
    kind: str
    game_id: str
    record: dict
    lines: list = field(default_factory=list)
    exit_code: int = PASSED
    nodes_down: list = field(default_factory=list)

    def text(self):
        what = "Early check" if self.kind == EARLY_CHECK else "Hand-over check"
        out = list(self.lines)
        if self.nodes_down:
            out.insert(0, f"Nodes not running after {LATE_RUN_WAIT} s: "
                          f"{', '.join(self.nodes_down)}; checking anyway.")
        if self.record.get("passed"):
            out.append(f"{what} of game {self.game_id}: passed.")
        else:
            failures = self.record.get("failures") or []
            out.append(f"{what} of game {self.game_id}: FAILED, {len(failures)} failure(s):")
            out += [f"  {f}" for f in failures]
            if self.exit_code == TOO_SOON_ONLY:
                longest = max(f.get("remaining") or 0 for f in self.record.get("faults") or [])
                out.append(f"Only too-soon readings: wait {longest} s, then run it again.")
        out.append("Recorded in state.yaml.")
        return "\n".join(out)


def run_check(scenario_dir, playground, kind, docker=None, out=print, now=None,
              sleep=time.sleep, clock=time.monotonic):
    """`gmctl check --early-check` or `--handover-check`; returns a
    CheckRun (its `exit_code` is the command's: 0 passed, 1 failed, 3 a
    hand-over check failed only on too-soon readings). Raises GmError on
    a refusal (nothing run, nothing recorded)."""
    from . import checks
    from .deploy import service_health
    ldir, st = _game(scenario_dir, playground)
    by_timer = timer_run(st)
    gid, stage = st.get("game_id"), st.get("stage")
    scenario = model.load_scenario(scenario_dir)
    aged = has_scheduler_nodes(scenario.data)
    if kind == EARLY_CHECK and not aged:
        raise GmError(f"game {gid} has no scheduler node, so it has no aging and no early "
                      "check (D157)")
    allowed = LOAD_STAGE if aged else INJECT_STAGE
    if stage != allowed:
        raise GmError(f"game {gid} is at stage {stage}; check --{kind} needs stage {allowed}")
    impl = localimpl.read_implementation(ldir)
    docker = docker or for_local_dir(ldir)
    run = CheckRun(kind, gid, {})
    if by_timer:
        run.nodes_down = wait_for_nodes(docker, impl, sleep=sleep, clock=clock)
    current = now or now_utc()
    record = {"at": iso(current), "passed": False}
    if override_text(st):
        record["override"] = override_text(st)
    failures = []

    plantings = st.get("plantings") or {}
    instances = [inst["id"] for inst in scenario.data.get("fault_instances") or []]
    if aged:
        planted = [i for i in instances if (plantings.get(i) or {}).get("planted_at")
                   or (plantings.get(i) or {}).get("plant_at", T0) == T0]
    else:
        planted = instances
    record["faults"] = []
    try:
        result = checks.check(scenario_dir, playground, docker=docker, instances=planted)
    except GmError as exc:
        result = None
        failures.append(f"the sealed checks could not run: {exc}")
    for line in (result.lines if result else []):
        expected = at_handover(scenario, line.instance)
        entry = {"instance": line.instance, "fault": line.fault_id, "verdict": line.verdict,
                 "exit": line.returncode, "line": line.reason}
        if line.verdict == "too-soon":
            entry["remaining"] = line.remaining
            if kind == HANDOVER_CHECK:
                failures.append(f"{line.instance} {line.fault_id}: too soon to tell, "
                                f"{line.remaining} s of its window remain")
        elif line.verdict == "error":
            failures.append(f"{line.instance} {line.fault_id}: the check errored: {line.reason}")
        elif line.returncode != expected:
            failures.append(f"{line.instance} {line.fault_id}: reads {line.verdict} (exit "
                            f"{line.returncode}), expected exit {expected} at hand-over")
        entry["passed"] = line.verdict != "error" and line.verdict != "too-soon" \
            and line.returncode == expected
        record["faults"].append(entry)
        run.lines.append(line.text())

    if aged:
        not_planted = []
        for iid in instances:
            if iid in planted:
                continue
            problem = planting_problem(iid, plantings.get(iid), current)
            if problem:
                failures.append(problem[1])
            elif kind == HANDOVER_CHECK:
                failures.append(f"{iid}: not planted")
            else:
                not_planted.append(iid)
        if kind == EARLY_CHECK:
            record["not_planted"] = not_planted
        t0 = parse_instant(st["load"]["t0"])
        outages, readings = read_outages(ldir, impl, st, docker, current)
        record["schedulers"] = []
        for node in scheduler_nodes(impl):
            entry, bad = judge_scheduler(ldir, impl, node, readings.get(node), t0, current)
            record["schedulers"].append(entry)
            failures += bad
            run.lines.append(f"{node}: scheduler "
                             + ("running" if entry.get("running") else "NOT running")
                             + (f", keys {', '.join(k + (' ok' if v else ' MISSING') for k, v in entry.get('keys', {}).items())}"
                                if entry.get("keys") else "")
                             + (f"; jobs {', '.join(f'{j} {v}' for j, v in entry.get('jobs', {}).items())}"
                                if entry.get("jobs") else ""))
        if outages.get("unread"):
            run.lines.append(f"outages NOT read: {outages['unread']['reason']}")
        record["lost_minutes"] = outages.get("lost_minutes") or 0
        run.lines.append(f"outages so far: {lost_text(outages)} lost")
    record["nodes"] = {}
    for name, node in impl["nodes"].items():
        try:
            health, detail = service_health(docker, node["service"])
        except GmError as exc:
            health, detail = "unknown", str(exc)
        record["nodes"][name] = health
        if health != "healthy":
            failures.append(f"node {name}: {health}" + (f" ({detail})" if detail else ""))
    run.lines.append("nodes: " + ", ".join(f"{n} {h}" for n, h in record["nodes"].items()))
    record["failures"] = failures
    record["passed"] = not failures
    too_soon = [f for f in record["faults"] if f["verdict"] == "too-soon"]
    if record["passed"]:
        run.exit_code = PASSED
    elif kind == HANDOVER_CHECK and too_soon and len(too_soon) == len(failures):
        run.exit_code = TOO_SOON_ONLY
    else:
        run.exit_code = FAILED_CHECK
    run.record = record

    def write(state):
        if aged:
            state["outages"] = outages
        if kind == EARLY_CHECK:
            state.setdefault("early_check", {"timer": None})["result"] = record
        else:
            state.setdefault("handover_checks", []).append(record)
        if aged:
            write_earliest(state, impl, current)
    localimpl.update_state(ldir, write)
    return run


# --- The earliest hand-over's record and the hand-over (W2 items 7, 11) ----

def write_earliest(state, impl, now):
    """`earliest_handover` recomputed from the records and written into
    `state` (a dict); None for a game with no T0."""
    computed = game_earliest(impl, state)
    if computed is None:
        return None
    earliest, waiting = computed
    record = {"at": iso(earliest), "waiting_for": waiting, "computed_at": iso(now)}
    if override_text(state):
        record["override"] = override_text(state)
    state["earliest_handover"] = record
    return record


def aged_game(impl):
    """A game that ages: its timeline holds the aging minimum (render, W2
    item 1); a game with no scheduler node has none (D157)."""
    return bool((impl.get(localimpl.TIMELINE) or {}).get("aging_minimum"))


def handover_refusal(impl, st, now):
    """Why `status --set handed-over` is refused (W2 item 11; until chunk
    11a the snapshot condition is not enforced, spec D172); None when it
    may go on."""
    checks_run = st.get("handover_checks") or []
    last = checks_run[-1] if checks_run else None
    if aged_game(impl):
        earliest, waiting = game_earliest(impl, st)
        if waiting:
            return (f"the earliest hand-over is not reached: it waits for the planting of "
                    f"{', '.join(waiting)} (provisionally {iso(earliest)})")
        if now < earliest:
            return (f"the earliest hand-over is {iso(earliest)}, in "
                    f"{duration_text((earliest - now).total_seconds())}: not reached")
    if last is None:
        return ("no hand-over check has run: run gmctl check <dir> --playground <pg> "
                "--handover-check")
    if not last.get("passed"):
        return (f"the last hand-over check, at {last.get('at')}, failed: "
                + "; ".join(last.get("failures") or []))
    if aged_game(impl) and parse_instant(last.get("at")) < earliest:
        return (f"the last hand-over check ran at {last.get('at')}, before the earliest "
                f"hand-over {iso(earliest)}: run it again")
    return None


# --- status (W2 item 11) ----------------------------------------------------

def status_head(impl, st, now):
    """The lines heading `gmctl status`: the override, then every
    unresolved failure and the outages."""
    out = []
    if override_text(st):
        out.append(f"TEST HARNESS OVERRIDE: this game's aging minimum is shortened to "
                   f"{override_text(st)} (a test run of the tools, never a game for players)")
    load = st.get("load") or {}
    attempts = load.get("attempts") or []
    if attempts and not load.get("t0"):
        bad = [f"{n}: {r.get('reason')}" for n, r in (attempts[-1].get("nodes") or {}).items()
               if r.get("outcome") != "ok"]
        if bad:
            out.append(f"FAILED start-load at {attempts[-1].get('began')}, T0 not recorded: "
                       + "; ".join(bad))
    for iid, planting in (st.get("plantings") or {}).items():
        problem = planting_problem(iid, planting, now)
        if problem:
            out.append(f"{problem[0].upper()} planting: {problem[1]} (plant it: gmctl inject "
                       f"<dir> --playground <pg> --at now --instance {iid})")
    early = st.get("early_check") or {}
    handover = st.get("handover_checks") or []
    if early.get("scheduling_failed"):
        out.append(f"FAILED to schedule the early check: {early['scheduling_failed']}")
    result = early.get("result")
    if result and not result.get("passed") and not any(c.get("passed") for c in handover):
        out.append(f"FAILED early check at {result.get('at')}: "
                   + "; ".join(result.get("failures") or []))
    if handover and not handover[-1].get("passed"):
        out.append(f"FAILED hand-over check at {handover[-1].get('at')}: "
                   + "; ".join(handover[-1].get("failures") or []))
    outages = st.get("outages") or {}
    if outages.get("lost_minutes"):
        excess = max(0, outages["lost_minutes"] - LOST_FREE_MINUTES)
        out.append(f"OUTAGES: {lost_text(outages)} lost in {len(outages.get('periods') or [])} "
                   "period(s)" + (f", the earliest hand-over {excess} min later" if excess else
                                  " (up to 30 min does not move the earliest hand-over)")
                   + (f"; task history may be incomplete for {', '.join(outages['incomplete'])}"
                      if outages.get("incomplete") else ""))
        out += [f"  {p['from']} to {p['to']} ({p['minutes']} min): {', '.join(p['causes'])}"
                for p in outages.get("periods") or []]
    if outages.get("unread"):
        out.append(f"OUTAGES NOT READ at {outages['unread']['at']}: "
                   f"{outages['unread']['reason']}")
    return out


def status_aging(impl, st, now):
    """The aging's lines of `gmctl status` (a game that ages), and the
    hand-over checks', the snapshot's and the restarts' (every game)."""
    out = []
    timeline = impl.get(localimpl.TIMELINE) or {}
    if aged_game(impl):
        load = st.get("load") or {}
        minimum = override_text(st) or timeline["aging_minimum"]
        if load.get("t0"):
            t0 = parse_instant(load["t0"])
            end = handover_instant(st) or now
            lost = (st.get("outages") or {}).get("lost_minutes") or 0
            ran = max(0, (end - t0).total_seconds() - 60 * lost)
            out.append(f"  aging: T0 {load['t0']}; ran {duration_text(ran)} (elapsed less the "
                       f"lost time) of the {minimum} minimum")
            out.append(f"  lost time: {lost_text(st.get('outages'))}")
            earliest, waiting = game_earliest(impl, st)
            state_text = (f"provisional, waiting for the planting of {', '.join(waiting)}"
                          if waiting else "reached" if now >= earliest else
                          f"in {duration_text((earliest - now).total_seconds())}")
            out.append(f"  earliest hand-over: {iso(earliest)} ({state_text})")
        else:
            out.append(f"  aging: not started (gmctl start-load); minimum {minimum}")
        tz = timeline.get("customer_timezone") or {}
        out.append(f"  planned hand-over: {timeline.get('planned_handover')}; shift "
                   f"{int(timeline.get('shift') or 0):+d}; customer's time zone "
                   f"{tz.get('reading')} ({tz.get('zone')})")
        plantings = st.get("plantings") or {}
        if plantings:
            out.append("  plantings:")
        for iid, p in plantings.items():
            last = (p.get("attempts") or [None])[-1]
            if p.get("plant_at", T0) == T0:
                text = f"planted {p.get('planted_at')} (T0)"
            elif p.get("planted_at"):
                text = f"planted {p['planted_at']} ({p.get('plant_at')})"
            elif p.get("timer"):
                text = f"due {p['timer']['due']} ({p.get('plant_at')}), timer {p['timer']['unit']}"
            else:
                text = f"planned {p.get('planned_at')} ({p.get('plant_at')}), not scheduled"
            if last and last.get("outcome") != "ok":
                text += f"; last attempt {last.get('outcome')} at {last.get('at')}"
            out.append(f"    {iid}: {text}")
        early = st.get("early_check") or {}
        if early.get("result"):
            res = early["result"]
            out.append(f"  early check: {'passed' if res.get('passed') else 'FAILED'} at "
                       f"{res.get('at')}")
        elif early.get("timer"):
            out.append(f"  early check: due {early['timer']['due']}, timer "
                       f"{early['timer']['unit']}")
    checks_run = st.get("handover_checks") or []
    if checks_run:
        last = checks_run[-1]
        out.append(f"  hand-over check: {'passed' if last.get('passed') else 'FAILED'} at "
                   f"{last.get('at')} ({len(checks_run)} run(s))")
    snapshot = st.get("snapshot")
    if snapshot:
        out.append(f"  snapshot: {snapshot.get('status')} at {snapshot.get('at')}")
    restarts = st.get("restarts") or []
    if restarts:
        out.append(f"  restarts: {len(restarts)}")
    return out


def status_reading(ldir, impl, st, docker, now):
    """On `status` at `load-started`: an outage reading (8.7) and the
    earliest hand-over recomputed, both written back; returns the state."""
    if st.get("stage") != LOAD_STAGE or not (st.get("load") or {}).get("t0") \
            or not aged_game(impl):
        return st
    try:
        docker = docker or for_local_dir(ldir)
        outages, _ = read_outages(ldir, impl, st, docker, now)
    except GmError as exc:
        outages = dict(st.get("outages") or {},
                       unread={"at": iso(now), "reason": " ".join(str(exc).split())})

    def write(state):
        state["outages"] = outages
        write_earliest(state, impl, now)
    return localimpl.update_state(ldir, write)
