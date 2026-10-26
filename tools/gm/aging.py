"""The aging: `gmctl start-load`, `gmctl inject --at`, the host timers.

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


def scheduler_nodes(scenario):
    return [n["name"] for n in scenario.nodes if is_scheduler_node(n)]


def rendered_file(scenario, playground, node, fname):
    """A scheduler node's rendered seed file, read (None when absent)."""
    path = Path(scenario.dir) / localimpl.rendered_seed_file(playground, node, fname)
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None
    except (OSError, yaml.YAMLError) as exc:
        raise GmError(f"{path}: cannot be read: {' '.join(str(exc).split())}") from None


def rendered_jobs(scenario, playground):
    """[(node, job)] of every scheduler node's rendered jobs.yaml."""
    out = []
    for node in scheduler_nodes(scenario):
        doc = rendered_file(scenario, playground, node, localimpl.JOBS_FILE) or {}
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


def early_check_due(scenario, playground, impl, st, now=None):
    """When the early check runs (W2 item 8): the later of T0 + M/2 and,
    for every rendered job first due before the earliest hand-over, that
    instant plus 10 minutes; then at most the earliest hand-over minus
    one hour, at least T0 + 5 minutes. M capped at the override."""
    t0 = parse_instant(st["load"]["t0"])
    earliest, _ = game_earliest(impl, st)
    minimum = _capped(parse_duration(impl[localimpl.TIMELINE]["aging_minimum"]),
                      override_seconds(st))
    due = t0 + datetime.timedelta(seconds=minimum // 2)
    for _, job in rendered_jobs(scenario, playground):
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

    for node in scheduler_nodes(scenario):
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
    st = localimpl.update_state(ldir, record)
    result.override = override_text(st)
    if not started:
        return result
    result.t0 = iso(began)

    systemd = systemd or Systemd()
    try:
        due = early_check_due(scenario, playground, impl, st)
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
        st = localimpl.update_state(ldir, record)
        result.early_moved = move_early_check(scenario, playground, impl, st, systemd, current)
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
    localimpl.update_state(ldir, record)
    return result


def move_early_check(scenario, playground, impl, st, systemd, now):
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
                         gmctl_argv("check", scenario.dir, playground, "--early-check"), now=now)

    def record(state):
        state.setdefault("early_check", {})["timer"] = moved
    localimpl.update_state(ldir_of(scenario, playground), record)
    return moved


def ldir_of(scenario, playground):
    return localimpl.local_dir(scenario.dir, playground)
