"""`gmctl history`: a fake game's Prometheus past, forged, imported and
joined to the live tail (v0.6 master spec 9.4 step 8, 9.5, 9.9 fixes 1, 5,
6 and 10, 9.12; capture W3 items 1 to 5 in
`specs/versions/v0.6/wave-log.md`).

Rewritten from the research prototypes at `research/fake-aging` 10d1bc6
(`gen_history.py`, `seam_check.py`, `import_history.sh`, `snapshot.py`,
`prom.py`): nothing of the shop is hardcoded; the overlays come from each
selected instance's `history:` (model.instance_history), never from the
research's `overlays.yaml`; the recorded baseline stays research (fix 6).

The composer (pure, unit-tested):

- the span: from the virtual T0 to the restart (`restart.at`); every
  series is forged on its own target's scrape grid, stepping back from its
  first sample in the tail, every sample before the restart;
- the profile baseline, one per series of the tail's first minutes, by
  class: counters joined to the tail (those surviving a clean shutdown:
  RESET_KEEP) or counting up to the restart's reset (every other counter,
  the restarted processes' and the statistics clean-restart resets, capture
  W3 item 3); size gauges a ramp ending at the tail's value, growing with
  the load's shape; activity gauges drawn around the tail's median with
  its spread, scaled by the load; other gauges the tail's level with its
  spread, scaled to the value and clamped at zero (fix 1); start times and
  reset times constant before the restart (fix 1), `up` and `pg_up`
  blipping to 0 at it;
- the load's shape: the calls the fill's metrics record per virtual minute
  (`local/<pg>/fill/<node>.metrics.jsonl`, W1 item 9) against the tail's;
- each series' driver (fix 12, spec D594, D595; `Composer.driver`): a
  database's `pg_stat_database_*` series follow the transactions the fill
  ran there (the record's `fill_transactions`) against the tail's
  equivalent, the fill's transactions per call there times the tail's
  calls (`Composer.transaction_shape`); else a
  series whose `user` names a scheduler connection's role, or, without a
  `user`, whose `datname` names one of their databases, follows the load;
  any other series with either label (the monitoring's own queries, the
  `postgres` database) stays flat at the tail's rate; a series with
  neither (host, WAL, checkpointer) follows the load;
- the scheduler's series from the fill's metrics records, never a second
  simulation, so the `queue` entries reach the past through them (W3 item
  4); they reset at the restart (the program restarted);
- the selected instances' entries (W3 item 4): each from its planting
  (`planted_at`, virtual) to the restart, nothing for an instance planted
  in the tail; `gauge_before` adding its value to the level drawn until the
  planting (spec D585), its value alone on a series the tail lacks;
  `daily_spike` at its scenario time on each day; `suppressed_by` from the
  planting of the first selected instance of a hiding fault (spec D543);
  `remove` last, winning on its series.

The seam check (pure, unit-tested; the live reading is `read_seam`):
findings `{check, series, detail}`, `check` one of `negative`, `reset`,
`jump`, `empty` (W3 item 3; `empty` added here: no forged sample at all).
"""

import bisect
import collections
import datetime
import json
import math
import random
import re
from dataclasses import dataclass, field

from .model import parse_duration

UTC = datetime.timezone.utc

STEP = 15.0                         # seconds: a scrape interval when the tail shows none
RESTART_WINDOW = 7200.0             # a start or reset time this close before the restart is its
PAST_START_BEFORE = 60.0            # the past's start times: this long before the virtual T0
NOISE_CV_MAX = 0.5                  # a gauge's noise, relative to its level, at most
COUNTER_JITTER = 0.05               # a counter's increase per step, relative
SHAPE_SMOOTH = 15                   # minutes: the load's shape, a moving mean
# The load's ratio to the tail's, bounded. The floor is far under any night
# the games draw (the shop's and fixture-fill's lowest, about 0.14 to 0.17),
# so the forged night follows the load down (fix 12); it only keeps a series
# moving through a minute the fill ran nothing in.
SHAPE_RATIO = (0.02, 4.0)
# The fill's transactions per call on a database, read over its last minutes:
# the hour before the restart, whose mix of keys is the tail's.
TX_PER_CALL_SPAN = 60
JUMP_TOLERANCE = 0.01               # a size gauge's step at the join, relative

# Counters a clean shutdown keeps (9.9, "Not done, on purpose"; W3 item 3):
# they carry on across the join. Every other counter is a restarted
# process's own or a statistic clean-restart resets, so it resets there.
RESET_KEEP = ("pg_stat_database_", "pg_stat_user_tables_", "pg_stat_user_indexes_",
              "pg_statio_", "pg_stat_all_", "pg_stat_sys_")
COUNTER_PREFIX = ("pg_stat_database_", "pg_stat_bgwriter_", "pg_stat_checkpointer_",
                  "pg_stat_archiver_", "pg_stat_statements_", "pg_stat_wal_", "pg_stat_io_",
                  "pg_stat_user_tables_", "pg_stat_user_indexes_", "pg_statio_")
NOT_COUNTERS = re.compile(r"(numbackends|stats_reset(_total)?|_timestamp(_seconds)?|_seconds_ago|"
                          r"_n_live_tup|_n_dead_tup|_n_mod_since_analyze|_n_ins_since_vacuum|"
                          r"last_.*)$")
# A gauge read as an instant when its value is one (seconds or milliseconds).
INSTANT_NAME = re.compile(r"(time|timestamp|reset|last_|_seconds$|_at$)")
SIZE_RE = re.compile(r"(_size_bytes|_used_bytes|_free_bytes)$")
ACTIVITY_RE = re.compile(r"(_activity_count|_locks_count|numbackends|_connections)$")
UP_NAMES = ("up", "pg_up")
SCHEDULER_PREFIX = "scheduler_"
SCHEDULER_COUNTERS = ("scheduler_calls_total", "scheduler_errors_total")
# The fill's transactions per database (bricks/scheduler gm_scheduler.fill
# FILL_TRANSACTIONS): {"<host>:<port>/<database>": so far}; the composer's
# input only, never a series
FILL_TRANSACTIONS = "fill_transactions"
DATABASE_PREFIX = "pg_stat_database_"
DRIVEN = ("counter_join", "counter_reset", "size", "activity")     # the classes a driver scales
FINDING_CHECKS = ("negative", "reset", "jump", "empty")


# --- Instants and series ---------------------------------------------------------

def epoch(text):
    """Seconds since the epoch of an instant `YYYY-MM-DDTHH:MM[:SS]Z`."""
    text = str(text)
    if re.match(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}Z$", text):
        text = text[:-1] + ":00Z"
    return datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(
        tzinfo=UTC).timestamp()


def series_key(labels):
    """`name{a="1",b="2"}`, labels sorted: one series' identity."""
    return labels["__name__"] + "{" + ",".join(
        f'{k}="{labels[k]}"' for k in sorted(labels) if k != "__name__") + "}"


def escape(value):
    return str(value).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"')


_SEL = re.compile(r"^\s*([a-zA-Z_:][a-zA-Z0-9_:]*)?\s*(?:\{(.*)\})?\s*$")
_MATCH = re.compile(r'\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*(=~|!~|!=|=)\s*"((?:[^"\\]|\\.)*)"\s*,?')


@dataclass(frozen=True)
class Selector:
    """A PromQL instant-vector selector, as an entry's `series` writes it:
    `name{label="v",label=~"re",label!="v",label!~"re"}`."""
    text: str
    name: str
    matchers: tuple                 # (label, op, value)

    @classmethod
    def parse(cls, text):
        m = _SEL.match(str(text))
        if not m or not (m.group(1) or m.group(2)):
            raise ValueError(f"not a series selector: {text!r}")
        body = m.group(2) or ""
        matchers = tuple(_MATCH.findall(body))
        if _MATCH.sub("", body).strip():
            raise ValueError(f"not a series selector: {text!r}")
        name = m.group(1)
        named = [v for k, op, v in matchers if k == "__name__" and op == "="]
        return cls(str(text), name or (named[0] if named else None), matchers)

    def matches(self, labels):
        if self.name and labels.get("__name__") != self.name:
            return False
        for k, op, v in self.matchers:
            x = labels.get(k, "")
            if (op == "=" and x != v) or (op == "!=" and x == v) \
                    or (op == "=~" and not re.fullmatch(v, x)) \
                    or (op == "!~" and re.fullmatch(v, x)):
                return False
        return True

    def equalities(self):
        out = {k: v for k, op, v in self.matchers if op == "="}
        if self.name:
            out["__name__"] = self.name
        return out


# --- Classes ---------------------------------------------------------------------

def metric_type(meta, name):
    """The family's type from Prometheus' metadata (`/api/v1/metadata`):
    a histogram's or summary's `_bucket`, `_sum` and `_count` are counters."""
    for suffix in ("_bucket", "_sum", "_count", "_total", ""):
        base = name[:-len(suffix)] if suffix and name.endswith(suffix) else name
        if base in (meta or {}):
            kind = (meta[base] or [{}])[0].get("type")
            if kind in ("histogram", "summary") and suffix in ("_bucket", "_sum", "_count"):
                return "counter"
            return kind or "unknown"
    return "unknown"


def is_counter(labels, meta):
    name = labels["__name__"]
    kind = metric_type(meta, name)
    if kind == "counter":
        return True
    if kind in ("gauge", "info", "stateset"):
        return False
    if NOT_COUNTERS.search(name):
        return False
    return name.endswith(("_total", "_bucket", "_sum", "_count")) or name.startswith(COUNTER_PREFIX)


def restart_resets(labels):
    """Whether the restart resets this counter (capture W3 item 3): every
    restarted process's own counters, the scheduler's, Prometheus' own,
    `pg_stat_statements_*` and the shared statistics; not those a clean
    shutdown keeps (RESET_KEEP)."""
    return not labels["__name__"].startswith(RESET_KEEP)


def is_size(name):
    return bool(SIZE_RE.search(name))


def is_activity(name):
    return bool(ACTIVITY_RE.search(name))


def _epoch_scale(value, t):
    """1 or 1000 when `value` reads as an instant (seconds or milliseconds)
    within a month of `t`, else None."""
    for scale in (1.0, 1000.0):
        if t - 30 * 86400 < value / scale < t + 86400:
            return scale
    return None


def classify(labels, samples, meta, restart):
    """The baseline class of a tail series: `up`, `scrape`, `ts_now`,
    `ts_start`, `const`, `elapsed`, `counter_join`, `counter_reset`,
    `size`, `activity` or `level`."""
    name = labels["__name__"]
    t0, v0 = samples[0]
    if name in UP_NAMES:
        return "up"
    if name.startswith("scrape_"):
        return "scrape"
    if name.endswith("_uptime_seconds") or name == "node_health_service_state_seconds":
        return "elapsed"
    scale = _epoch_scale(v0, t0) if INSTANT_NAME.search(name) else None
    if scale:
        t1, v1 = samples[-1]
        if t1 > t0 and abs((v1 - v0) / scale - (t1 - t0)) < max(1.0, 0.1 * (t1 - t0)):
            return "ts_now"         # it moves with the clock
        if v0 / scale >= restart - RESTART_WINDOW:
            return "ts_start"
        return "const"
    if is_counter(labels, meta):
        return "counter_reset" if restart_resets(labels) else "counter_join"
    if is_size(name):
        return "size"
    if is_activity(name):
        return "activity"
    if len({v for _, v in samples}) == 1:
        return "const"
    return "level"


def tail_rate(samples):
    """A counter's increase per second over the tail's samples (a reset in
    them counted as Prometheus' rate does)."""
    inc = 0.0
    for (_, a), (_, b) in zip(samples, samples[1:]):
        inc += b - a if b >= a else b
    span = samples[-1][0] - samples[0][0]
    return inc / span if span > 0 else 0.0


# --- The load's shape (fix 6) ------------------------------------------------------

def read_metrics(lines):
    """The fill's metrics records (one JSON object a virtual minute), in
    order of `at`, each with its epoch `t`."""
    out = []
    for line in lines:
        line = line.strip()
        if line:
            rec = json.loads(line)
            rec["t"] = epoch(rec["at"])
            out.append(rec)
    out.sort(key=lambda r: r["t"])
    return out


def per_minute(metrics, key, entry=None):
    """The increase a minute of the records' cumulative map `key` (only its
    `entry` when given), every scheduler node together."""
    out = collections.Counter()
    for records in (metrics or {}).values():
        prev = {}
        for rec in records:
            counts = rec.get(key) or {}
            minute = int(rec["t"] // 60)
            for k, v in counts.items():
                if entry is None or k == entry:
                    out[minute] += max(0, v - prev.get(k, 0))
            prev = counts
    return out


class Shape:
    """A count a minute from the fill's records (a moving mean of
    SHAPE_SMOOTH minutes), against the tail's. `ratio(t)` is the count at
    `t` over the tail's, bounded by SHAPE_RATIO; 1 throughout without
    records or a tail count."""

    def __init__(self, counts, tail_per_minute):
        self.minutes = sorted(counts)
        self.values = [counts[m] for m in self.minutes]
        self.tail = tail_per_minute or 0.0
        self.cache = {}

    def at(self, t):
        if not self.minutes:
            return None
        minute = int(t // 60)
        if minute in self.cache:
            return self.cache[minute]
        lo = bisect.bisect_left(self.minutes, minute - SHAPE_SMOOTH // 2)
        hi = bisect.bisect_right(self.minutes, minute + SHAPE_SMOOTH // 2)
        value = sum(self.values[lo:hi]) / SHAPE_SMOOTH if hi > lo else 0.0
        self.cache[minute] = value
        return value

    def ratio(self, t):
        load = self.at(t)
        if load is None or self.tail <= 0:
            return 1.0
        return min(max(load / self.tail, SHAPE_RATIO[0]), SHAPE_RATIO[1])


class LoadShape(Shape):
    """Calls a minute, every scheduler node together, against the tail's."""

    def __init__(self, metrics, tail_per_minute):
        super().__init__(per_minute(metrics, "scheduler_calls_total"), tail_per_minute)


class Flat:
    """A series the fill's load does not drive: the tail's rate throughout."""

    def ratio(self, t):
        return 1.0


FLAT = Flat()


@dataclass(frozen=True)
class Drivers:
    """What decides a series' driver (fix 12; `fill_drivers`): the
    scheduler connections' `roles` and `databases`, and `targets`, each
    exporter's `instance` label to the `<host>:<port>` it reads."""
    roles: frozenset = frozenset()
    databases: frozenset = frozenset()
    targets: dict = field(default_factory=dict)


def tail_calls_per_minute(tail_series, instances=None):
    """The tail's calls a minute, every scheduler node together (only the
    targets in `instances` when given)."""
    total = 0.0
    for s in tail_series:
        if s["labels"]["__name__"] == "scheduler_calls_total" and len(s["samples"]) > 1 \
                and (instances is None or s["labels"].get("instance") in instances):
            total += tail_rate(s["samples"]) * 60
    return total


def fill_per_call(metrics, entry, span=TX_PER_CALL_SPAN):
    """The fill's transactions on the database `entry` per call, over its
    last `span` minutes (the whole fill when they hold no call); None
    without a call."""
    xacts = per_minute(metrics, FILL_TRANSACTIONS, entry)
    calls = per_minute(metrics, "scheduler_calls_total")
    if not calls:
        return None
    last = max(list(xacts) + list(calls))
    window = [m for m in calls if m > last - span]
    if not sum(calls[m] for m in window):
        window = list(calls)
    n = sum(calls[m] for m in window)
    return sum(xacts.get(m, 0) for m in window) / n if n else None


# --- The selection's entries (W3 item 4) ---------------------------------------------

@dataclass
class Overlay:
    """One selected instance's entry, its window in the past resolved:
    `start` to `end` (epoch seconds; `gauge_before` adds its value before
    `start`)."""
    instance: str
    kind: str
    fields: dict
    planted: float                  # the instance's planting (virtual), epoch
    end: float                      # the restart, or the hiding instance's planting
    selector: Selector = None

    def active(self, t):
        if self.kind == "gauge_before":
            return t < min(self.planted, self.end)
        return self.planted <= t < self.end


def overlays_for(selection, restart):
    """`selection`: [(instance id, fault id, planted_at epoch or None,
    entries)] of the selected instances. Returns (overlays, notes): the
    entries drawn in the past, `queue` and `none` left out (the fill's
    records carry the queue's; none draws nothing)."""
    plantings = collections.defaultdict(list)
    for iid, fault_id, planted, _ in selection:
        if planted is not None:
            plantings[fault_id].append(planted)
    out, notes = [], []
    for iid, fault_id, planted, entries in selection:
        if planted is None or planted >= restart:
            if entries:
                notes.append(f"{iid}: planted in the tail, nothing in the past")
            continue
        for entry in entries or ():
            if entry.kind in ("queue", "none"):
                continue
            hiders = [p for f in entry.suppressed_by for p in plantings.get(f, ())]
            end = min([restart] + [p for p in hiders if p < restart])
            if end < restart:
                notes.append(f"{iid}: {entry.kind} on {entry.fields.get('series')} suppressed "
                             f"from {iso(end)}")
            out.append(Overlay(iid, entry.kind, dict(entry.fields), planted, end,
                               Selector.parse(entry.fields["series"])))
    return out, notes


def iso(t):
    return datetime.datetime.fromtimestamp(t, UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def daily_windows(at, duration, shift, start, end):
    """The instants a `daily_spike` covers within [start, end): `at`
    (`"HH:MM"`, scenario time, UTC plus `shift` hours) for `duration`
    seconds, on each day."""
    hh, mm = (int(x) for x in str(at).split(":"))
    utc_minutes = (hh * 60 + mm - int(shift) * 60) % 1440
    day = math.floor(start / 86400) * 86400 - 86400
    out = []
    while day < end:
        lo = day + utc_minutes * 60
        if lo + duration > start and lo < end:
            out.append((lo, lo + duration))
        day += 86400
    return out


# --- The composer ------------------------------------------------------------------

@dataclass
class Report:
    series: int = 0
    samples: int = 0
    classes: collections.Counter = field(default_factory=collections.Counter)
    drivers: collections.Counter = field(default_factory=collections.Counter)
    clamped: list = field(default_factory=list)
    synthesized: list = field(default_factory=list)
    unmatched: list = field(default_factory=list)
    removed_samples: int = 0
    notes: list = field(default_factory=list)

    def as_dict(self):
        return {"series": self.series, "samples": self.samples, "classes": dict(self.classes),
                "drivers": dict(self.drivers),
                "clamped": self.clamped, "synthesized": self.synthesized,
                "unmatched": self.unmatched, "removed_samples": self.removed_samples,
                "notes": self.notes}


class Composer:
    """The forged past of one game (W3 item 4).

    `tail`: {"series": [{"labels", "samples": [[t, v], ...]}], "metadata"}
    read from the restart on; `metrics`: {node: records} (read_metrics);
    `scheduler_instances`: {node: the `instance` label its target has};
    `selection`: overlays_for's input; `shift`: hours, scenario time minus
    UTC; `seed`: the game's seed, for the noise; `drivers`: a Drivers (fix
    12), None for every series following the load."""

    def __init__(self, vt0, restart, tail, metrics=None, scheduler_instances=None,
                 selection=(), shift=0, seed=0, drivers=None):
        self.vt0, self.restart = float(vt0), float(restart)
        self.meta = tail.get("metadata") or {}
        self.tail = [s for s in tail.get("series") or [] if s.get("samples")]
        for s in self.tail:
            s["samples"] = sorted((float(t), float(v)) for t, v in s["samples"])
        self.metrics = metrics or {}
        self.sched = scheduler_instances or {}
        self.shift, self.seed = shift, seed
        self.report = Report()
        self.overlays, notes = overlays_for(selection, self.restart)
        self.report.notes += notes
        self.shape = LoadShape(self.metrics, tail_calls_per_minute(self.tail))
        self.drivers = drivers
        self.db_shapes = {}
        self.step = self._scrape_interval()
        self.past_start = self.vt0 - PAST_START_BEFORE

    def _scrape_interval(self):
        gaps = sorted(b[0] - a[0] for s in self.tail for a, b in zip(s["samples"], s["samples"][1:])
                      if b[0] > a[0])
        return round(gaps[len(gaps) // 2], 3) if gaps else STEP

    def driver(self, lb):
        """The series' shape (fix 12, spec D594, D595): a database's
        transactions first, then the `user` label, then `datname`; a series
        with neither follows the load."""
        if self.drivers is None:
            return self.shape
        if lb["__name__"].startswith(DATABASE_PREFIX):
            shape = self.transaction_shape(lb.get("instance"), lb.get("datname"))
            if shape is not None:
                return shape
        if lb.get("user"):
            return self.shape if lb["user"] in self.drivers.roles else FLAT
        if lb.get("datname"):
            return self.shape if lb["datname"] in self.drivers.databases else FLAT
        return self.shape

    def transaction_shape(self, instance, datname):
        """The transactions the fill ran on the database a series reads, a
        minute, against the tail's equivalent: the fill's transactions per
        call there (its last TX_PER_CALL_SPAN minutes, `fill_per_call`)
        times the tail's calls from the same scheduler nodes. Both sides
        count the fill's transactions, never the tail's commits, which hold
        more (a session's set-up, a parallel worker's start-up, autovacuum's
        visits): the forged series keep the tail's rate per call, their
        shape the fill's transactions. None without a record of them (a
        fill from an earlier image) or a call in the fill or the tail."""
        key = (instance, datname)
        if key not in self.db_shapes:
            self.db_shapes[key] = None
            target = self.drivers.targets.get(instance)
            entry = f"{target}/{datname}"
            nodes = {n: recs for n, recs in self.metrics.items()
                     if any(entry in (rec.get(FILL_TRANSACTIONS) or {}) for rec in recs)}
            if target and datname and nodes:
                per_call = fill_per_call(nodes, entry)
                insts = {self.sched[n] for n in nodes if n in self.sched} or None
                calls = tail_calls_per_minute(self.tail, insts)
                if per_call and calls > 0:
                    self.db_shapes[key] = Shape(per_minute(nodes, FILL_TRANSACTIONS, entry),
                                                per_call * calls)
                    self.report.notes.append(
                        f"{entry}: the fill's {per_call:.3f} transactions a call (its last "
                        f"{TX_PER_CALL_SPAN} min) times the tail's {calls:.1f} calls a minute")
        return self.db_shapes[key]

    def rng(self, labels):
        """The noise of a series, the same for a histogram's buckets."""
        lb = {k: v for k, v in labels.items() if k not in ("le", "quantile")}
        return random.Random(f"{self.seed}/{series_key(lb)}")

    def grid(self, t_first):
        """The forged samples' instants: the target's scrape grid stepping
        back from its first sample in the tail, in [vT0, restart)."""
        k = math.ceil((t_first - self.restart) / self.step + 1e-9)
        last = t_first - self.step * max(k, 1)
        n = int((last - self.vt0) // self.step)
        return [last - self.step * i for i in range(n, -1, -1)]

    # baselines --------------------------------------------------------------------
    def baseline(self, s):
        lb, smp = s["labels"], s["samples"]
        if lb.get("__name__", "").startswith(SCHEDULER_PREFIX) and self.sched:
            return None                 # the fill's records own them
        ts = self.grid(smp[0][0])
        if not ts:
            return None
        cls = classify(lb, smp, self.meta, self.restart)
        self.report.classes[cls] += 1
        shape = self.driver(lb)
        if cls in DRIVEN:
            self.report.drivers["flat" if shape is FLAT else "load" if shape is self.shape
                                else "transactions"] += 1
        r = self.rng(lb)
        values = [v for _, v in smp]
        integral = all(float(v).is_integer() for v in values)
        t_first, v_first = smp[0]
        if cls == "up":
            vals = [1.0 if v_first else 0.0] * len(ts)
            vals[-1] = 0.0              # the restart's blip (fix 1)
        elif cls == "scrape":
            vals = self.level(values, ts, r, integral)
            if lb["__name__"] == "scrape_series_added":
                vals = [0] * len(ts)
        elif cls == "ts_now":
            scale = _epoch_scale(v_first, t_first)
            lag = v_first - t_first * scale
            vals = [t * scale + lag for t in ts]
        elif cls == "ts_start":
            scale = _epoch_scale(v_first, t_first)
            vals = [self.past_start * scale] * len(ts)
        elif cls == "elapsed":
            start = t_first - v_first
            if start >= self.restart - RESTART_WINDOW:
                start = self.past_start
            vals = [max(0.0, t - start) for t in ts]
        elif cls == "const":
            vals = [v_first] * len(ts)
        elif cls == "size":
            vals = self.size(smp, ts, shape)
        elif cls == "activity":
            vals = self.activity(values, ts, r, integral, shape)
        elif cls == "level":
            vals = self.level(values, ts, r, integral)
        else:
            vals = self.counter(lb, smp, ts, cls == "counter_reset", r, integral, shape)
        return lb, ts, vals

    def level(self, values, ts, r, integral, scale=False):
        """The tail's level with its spread, the noise relative to the
        level and clamped at zero (fix 1); scaled by the load's shape when
        `scale`."""
        mean = sum(values) / len(values)
        sd = (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5
        cv = min(sd / abs(mean), NOISE_CV_MAX) if mean else 0.0
        floor = 0.0 if min(values) >= 0 else min(values)
        out = []
        for t in ts:
            base = mean * (self.shape.ratio(t) if scale else 1.0)
            v = max(floor, base * (1 + r.gauss(0, cv))) if cv else base
            out.append(round(v) if integral else v)
        return out

    def activity(self, values, ts, r, integral, shape):
        """Around the tail's median, with its real spread, scaled by its
        driver (fix 5, fix 12); never below zero."""
        ordered = sorted(values)
        median = ordered[len(ordered) // 2]
        spread = [v - median for v in values]
        out = []
        for t in ts:
            v = max(0.0, median * shape.ratio(t) + r.choice(spread))
            out.append(round(v) if integral else v)
        return out

    def size(self, smp, ts, shape):
        """A ramp ending at the tail's first value: the tail's slope, per
        unit of load, over its driver (fix 5, fix 12), never below zero (a
        setting the tail holds below zero, -1 for "no limit", stays at it)."""
        (t0, v0), (t1, v1) = smp[0], smp[-1]
        slope = (v1 - v0) / (t1 - t0) if t1 > t0 else 0.0
        floor = min(0.0, v0)
        out, v = [], v0
        for t in reversed(ts):
            v -= slope * self.step * shape.ratio(t)
            out.append(max(floor, v))
        out.reverse()
        return [round(x) for x in out] if float(v0).is_integer() else out

    def counter(self, lb, smp, ts, resets, r, integral, shape):
        rate = tail_rate(smp)
        extra = [0.0] * len(ts)
        for o in self.overlays:
            if o.kind == "counter_per_call" and o.selector.matches(lb):
                node, key = self.key_node(o), o.fields["key"]
                per_call = float(o.fields["per_call"])
                rate -= per_call * self.tail_key_rate(node, key)
                calls = self.calls_per_step(node, key, ts)
                for i, t in enumerate(ts):
                    if o.active(t):
                        extra[i] += per_call * calls[i]
        rate = max(rate, 0.0)
        inc = [max(0.0, rate * self.step * shape.ratio(t) * (1 + r.gauss(0, COUNTER_JITTER)))
               + extra[i] for i, t in enumerate(ts)]
        v_first = smp[0][1]
        if resets:
            # counting from its start-up up to the restart, which resets it
            v, out = v_first, []
            for x in inc:
                v += x
                out.append(v)
        else:
            total = sum(inc)
            if total > v_first > 0 or (total and v_first <= 0):
                k = max(0.0, v_first) / total
                self.report.clamped.append([series_key(lb), round(k, 4)])
                inc = [x * k for x in inc]
            v, out = v_first, []
            for x in reversed(inc):     # inc[i]: the increase from ts[i] to the next sample
                v -= x
                out.append(max(0.0, v))
            out.reverse()
        if integral:
            out = [math.floor(x + 1e-9) for x in out]
            for i in range(1, len(out)):
                out[i] = max(out[i], out[i - 1])
        return out

    # the scheduler's records ----------------------------------------------------------
    def key_node(self, overlay):
        node = overlay.fields.get("node")
        if node:
            return node
        found = [n for n, recs in self.metrics.items()
                 if any(overlay.fields["key"] in (rec.get("scheduler_calls_total") or {})
                        for rec in recs[-1:])]
        return found[0] if len(found) == 1 else None

    def cumulative(self, node, key):
        """[(t, calls so far)] of `key` on `node`, from the fill's records."""
        return [(rec["t"], (rec.get("scheduler_calls_total") or {}).get(key, 0))
                for rec in self.metrics.get(node) or []]

    def calls_per_step(self, node, key, ts):
        points = self.cumulative(node, key)
        if not points:
            return [0.0] * len(ts)
        times = [p[0] for p in points]

        def at(t):              # linear within the minute
            i = bisect.bisect_right(times, t)
            if i == 0:
                return 0.0
            if i == len(points):
                return float(points[-1][1])
            (ta, a), (tb, b) = points[i - 1], points[i]
            return a + (b - a) * (t - ta) / (tb - ta)
        return [max(0.0, at(t) - at(t - self.step)) for t in ts]

    def tail_key_rate(self, node, key):
        inst = self.sched.get(node)
        for s in self.tail:
            lb = s["labels"]
            if lb["__name__"] == "scheduler_calls_total" and lb.get("key") == key \
                    and (inst is None or lb.get("instance") == inst):
                return tail_rate(s["samples"])
        return 0.0

    def scheduler_series(self):
        """Every scheduler node's series from the fill's records, labelled
        as the tail labels them, on the target's grid; they reset at the
        restart (the program restarted)."""
        le_text = {}
        firsts = {}
        for s in self.tail:
            lb = s["labels"]
            if lb["__name__"] == "scheduler_call_duration_seconds_bucket" and lb.get("le"):
                le_text[_le_value(lb["le"])] = lb["le"]
            if lb["__name__"].startswith(SCHEDULER_PREFIX) or lb["__name__"] == "up":
                firsts.setdefault(lb.get("instance"), s["samples"][0][0])
        job = next((s["labels"].get("job") for s in self.tail
                    if s["labels"].get("instance") in self.sched.values()), "scheduler")
        for node, records in sorted(self.metrics.items()):
            inst = self.sched.get(node)
            if inst is None or not records:
                continue
            base = {"job": job, "instance": inst}
            ts = self.grid(firsts.get(inst, self.restart + self.step))
            times = [rec["t"] for rec in records]
            rows = collections.defaultdict(list)
            for t in ts:
                i = bisect.bisect_right(times, t)
                rec = records[i - 1] if i else {}
                for name in SCHEDULER_COUNTERS:
                    for k, v in (rec.get(name) or {}).items():
                        rows[(name, (("key", k),))].append((t, v))
                for k, h in (rec.get("scheduler_call_duration_seconds") or {}).items():
                    for le, n in (h.get("buckets") or {}).items():
                        text = le_text.get(_le_value(le), _le_format(le))
                        rows[("scheduler_call_duration_seconds_bucket",
                              (("key", k), ("le", text)))].append((t, n))
                    rows[("scheduler_call_duration_seconds_bucket",
                          (("key", k), ("le", "+Inf")))].append((t, h.get("count", 0)))
                    rows[("scheduler_call_duration_seconds_sum", (("key", k),))].append(
                        (t, h.get("sum", 0.0)))
                    rows[("scheduler_call_duration_seconds_count", (("key", k),))].append(
                        (t, h.get("count", 0)))
                for run in rec.get("scheduler_job_runs_total") or []:
                    rows[("scheduler_job_runs_total",
                          (("exported_job", run["job"]), ("key", run["key"])))].append(
                        (t, run["value"]))
                for skip in rec.get("scheduler_job_skips_total") or []:
                    rows[("scheduler_job_skips_total",
                          (("exported_job", skip["job"]), ("key", skip["key"]),
                           ("reason", skip["reason"])))].append((t, skip["value"]))
                rows[("scheduler_running", ())].append((t, 1))
                rows[("scheduler_start_time_seconds", ())].append((t, self.vt0))
            for (name, extra), points in rows.items():
                lb = dict(base, **dict(extra), __name__=name)
                yield lb, [p[0] for p in points], [p[1] for p in points]

    # overlays on gauges, remove, synthesized series -------------------------------------
    def gauge_overlays(self, lb, ts, vals):
        for o in self.overlays:
            if not o.selector.matches(lb):
                continue
            if o.kind == "gauge_sawtooth":
                period = parse_duration(o.fields["period"])
                phase = parse_duration(o.fields.get("phase") or "0s")
                amp = float(o.fields["amplitude"])
                # riding on the baseline, never below the night's floor (fix 5)
                vals = [(v or 0.0) + ((t - phase) % period) / period * amp if o.active(t)
                        else v for t, v in zip(ts, vals)]
            elif o.kind == "gauge_before":
                # added to the level drawn up to the planting (spec D585); a
                # series the tail lacks (a dropped object's) reads it alone
                add = float(o.fields["value"])
                vals = [(0.0 if v is None else v) + add if o.active(t) else v
                        for t, v in zip(ts, vals)]
            elif o.kind == "daily_spike":
                wins = daily_windows(o.fields["at"], parse_duration(o.fields["duration"]),
                                     self.shift, self.vt0, self.restart)
                vals = [float(o.fields["value"]) if o.active(t)
                        and any(lo <= t < hi for lo, hi in wins) else v
                        for t, v in zip(ts, vals)]
        return vals

    def removed(self, lb, t):
        return any(o.kind == "remove" and o.active(t) and o.selector.matches(lb)
                   for o in self.overlays)

    def synthesized(self, present):
        """The gauge overlays' series the tail lacks (a dropped object's,
        a spike's): labels from the selector's equalities and a tail series
        of the same name; drawn only where the overlay is."""
        by_name = collections.defaultdict(list)
        for s in self.tail:
            by_name[s["labels"]["__name__"]].append(s)
        done = set()
        for o in self.overlays:
            if o.kind not in ("gauge_before", "gauge_sawtooth", "daily_spike"):
                continue
            if any(o.selector.matches(s["labels"]) for s in self.tail):
                continue
            eq = o.selector.equalities()
            sibling = by_name.get(eq.get("__name__"))
            if not sibling:
                self.report.unmatched.append(f"{o.instance}: {o.kind} {o.selector.text}: no "
                                             "series of that name in the tail")
                continue
            lb = dict(sibling[0]["labels"], **eq)
            key = series_key(lb)
            if key in present or key in done or not o.selector.matches(lb):
                continue
            done.add(key)
            self.report.synthesized.append(key)
            ts = self.grid(sibling[0]["samples"][0][0])
            yield lb, ts, [None] * len(ts)

    # output ---------------------------------------------------------------------------
    def compose(self):
        """Every forged series: (labels, [(t, v)]) with t in [vT0, restart)."""
        produced = []
        for s in self.tail:
            r = self.baseline(s)
            if r:
                produced.append(r)
        produced += list(self.scheduler_series())
        present = {series_key(lb) for lb, _, _ in produced}
        produced += list(self.synthesized(present))
        for lb, ts, vals in produced:
            if not lb["__name__"].startswith(SCHEDULER_PREFIX):
                vals = self.gauge_overlays(lb, ts, vals) if not is_counter(lb, self.meta) \
                    else vals
            points = []
            for t, v in zip(ts, vals):
                if v is None or not self.vt0 <= t < self.restart:
                    continue
                if self.removed(lb, t):
                    self.report.removed_samples += 1
                    continue
                points.append((t, v))
            if points:
                yield lb, points

    def write(self, out):
        """The past as OpenMetrics, each series' samples together and in
        order, `# EOF` last; the report filled."""
        for lb, points in self.compose():
            head = lb["__name__"] + "{" + ",".join(
                f'{k}="{escape(lb[k])}"' for k in sorted(lb) if k != "__name__") + "} "
            out.write("".join(f"{head}{_value(v)} {t:.3f}\n" for t, v in points))
            self.report.series += 1
            self.report.samples += len(points)
        out.write("# EOF\n")
        return self.report


def _value(v):
    if isinstance(v, float):
        return repr(int(v)) if v.is_integer() and abs(v) < 1e15 else repr(v)
    return str(v)


def _le_value(text):
    return math.inf if str(text) == "+Inf" else float(text)


def _le_format(text):
    return "+Inf" if str(text) == "+Inf" else repr(float(text))


# --- The seam check (W3 item 3) --------------------------------------------------------

def finding(check, series, detail):
    return {"check": check, "series": series, "detail": detail}


def seam_findings(past, tail_first, meta):
    """The seam's verdict from what Prometheus holds: `past`: {series key:
    {"labels", "min", "last", "resets"}} over the forged span; `tail_first`:
    {series key: (labels, first value from the restart on[, the largest
    step between two of its samples there])}. Returns the findings, []
    when the seam is ok. A series below zero in the tail itself (a
    setting's -1) is held to that value; a size gauge's join may step as
    far as the tail's own largest step."""
    out = []
    if not past:
        return [finding("empty", "*", "no sample before the restart: the history is not there")]
    for key in sorted(past):
        p = past[key]
        lb = p["labels"]
        # a series the system itself holds below zero (a setting's -1, "no
        # limit") is held to its own value, never to zero
        own = tail_first[key][1] if key in tail_first else 0.0
        if p.get("min") is not None and p["min"] < min(0.0, own):
            out.append(finding("negative", key, f"{_value(p['min'])} in the forged past"))
        counter = is_counter(lb, meta)
        if counter and (p.get("resets") or 0) > 0:
            out.append(finding("reset", key, f"{int(p['resets'])} reset(s) in the forged past"))
        if key not in tail_first:
            continue
        first = tail_first[key][1]
        last = p.get("last")
        if counter and last is not None and first < last and not restart_resets(lb):
            out.append(finding("reset", key, f"{_value(last)} -> {_value(first)} at the restart, "
                                             "which keeps this counter"))
        if not counter and is_size(lb["__name__"]) and last is not None:
            # beyond the tolerance and beyond the tail's own largest step (a
            # volume growing by whole blocks, a WAL filling after its start)
            step = tail_first[key][2] if len(tail_first[key]) > 2 else 0.0
            rel = abs(first - last) / max(abs(last), 1.0)
            if rel > JUMP_TOLERANCE and abs(first - last) > step:
                out.append(finding("jump", key, f"{_value(last)} -> {_value(first)} at the join "
                                                f"({rel:.1%}, tolerance {JUMP_TOLERANCE:.0%}, the "
                                                f"tail's own step {_value(step)})"))
    for key in sorted(tail_first):
        lb, first = tail_first[key][:2]
        last = (past.get(key) or {}).get("last")
        # below zero at the join, coming from a forged past that was not
        if first < 0 and (last is None or last >= 0):
            out.append(finding("negative", key, f"{_value(first)} at the join"))
    return out


# --- gmctl history (capture W3 items 1, 2, 5) ---------------------------------------------

HISTORY_DIR = "history"             # local/<playground>/history/: the working files
TAIL_FILE, OM_FILE, REPORT_FILE = "tail.json", "history.om", "report.json"
RUN_LOCK = ".history.lock"          # local/<playground>/: one import at a time
PROM_DATA_VOLUME = "promdata"       # the brick's TSDB volume (bricks/prometheus/brick.yaml)
PROM_API = "http://127.0.0.1:9090/prometheus/api/v1"   # its web_path, /prometheus/
TSDB_MOUNT = "/gm-tsdb"
# in the helper container's own layer, removed with it (--rm); never /tmp,
# the image's link to /run/tmp, which s6 creates at boot and the helper,
# started without s6, lacks
HELPER_WORK = "/gm-history"
QUERY_TIMEOUT = 120                 # seconds for one query
LOAD_WAIT = 180                     # seconds for Prometheus to load the blocks by itself
LOAD_POLL = 10
SEAM_CHUNK = 7200                   # seconds of the past one seam query reads
SEAM_TAIL = 300                     # seconds of the tail the seam reads its first values in
REASON_FINDINGS = 3                 # findings named in the record's one-line reason
ULID_RE = re.compile(r"^[0-9A-HJKMNP-TV-Z]{26}$")

# The helper container (capture W3 item 5): promtool with the node's image, on
# its host, never in the running node; the OpenMetrics on stdin; each block
# moved in whole, owned prometheus:prometheus, under a name Prometheus skips
# until its rename; the folder itself, prometheus:prometheus 0750, untouched
# (spec D540).
IMPORT_SCRIPT = f"""set -eu
mkdir -p {HELPER_WORK}
cat > {HELPER_WORK}/{OM_FILE}
TMPDIR={HELPER_WORK} promtool tsdb create-blocks-from openmetrics -q {HELPER_WORK}/{OM_FILE} \\
    {HELPER_WORK}/blocks >&2
echo "peak $(cat /sys/fs/cgroup/memory.peak 2>/dev/null || echo unknown)"
for b in {HELPER_WORK}/blocks/*; do
    id=${{b##*/}}
    case "$id" in ??????????????????????????) [ -d "$b" ] || continue ;; *) continue ;; esac
    rm -rf "{TSDB_MOUNT}/${{id:?}}.tmp-for-creation"
    cp -a "$b" "{TSDB_MOUNT}/$id.tmp-for-creation"
    chown -R prometheus:prometheus "{TSDB_MOUNT}/$id.tmp-for-creation"
    mv "{TSDB_MOUNT}/$id.tmp-for-creation" "{TSDB_MOUNT}/$id"
    echo "block $id $(du -sb "{TSDB_MOUNT}/$id" | cut -f1)"
done
"""

# A failed attempt's blocks removed before a retry: every block wholly before
# the restart (Prometheus' own begin at it), and any half-moved one.
REMOVE_SCRIPT = f"""set -eu
for b in {TSDB_MOUNT}/*; do
    id=${{b##*/}}
    [ -n "$id" ] || continue
    case "$id" in
        *.tmp-for-creation) rm -rf "{TSDB_MOUNT}/${{id:?}}"; echo "removed $id"; continue ;;
    esac
    [ -f "{TSDB_MOUNT}/$id/meta.json" ] || continue
    max=$(tr -d ' \\n' < "{TSDB_MOUNT}/$id/meta.json" | sed -n 's/.*"maxTime":\\([0-9]*\\).*/\\1/p')
    if [ -n "$max" ] && [ "$max" -le "$GM_RESTART_MS" ]; then
        rm -rf "{TSDB_MOUNT}/${{id:?}}"
        echo "removed $id"
    fi
done
"""


class Prometheus:
    """The game's Prometheus HTTP API, read-only, through `curl` in its node
    (as `prom.py` did): GET on /api/v1 only."""

    def __init__(self, ldir, node, docker):
        self.ldir, self.node, self.docker = ldir, node, docker

    def get(self, path, **params):
        import shlex
        from .execnode import exec_node
        from .model import GmError
        script = f"curl -fsS --max-time {QUERY_TIMEOUT} -G {shlex.quote(f'{PROM_API}/{path}')}"
        for k, v in params.items():
            script += f" --data-urlencode {shlex.quote(f'{k}={v}')}"
        run = exec_node(self.ldir, self.node, "prometheus", stdin=script + "\n",
                        timeout=QUERY_TIMEOUT + 30, docker=self.docker)
        if not run.ok:
            detail = " ".join((run.stderr or run.stdout or "").split())[:200]
            raise GmError(f"Prometheus {path}: exit {run.returncode}: {detail}")
        try:
            data = json.loads(run.stdout)
        except ValueError:
            raise GmError(f"Prometheus {path}: not JSON") from None
        if data.get("status") != "success":
            raise GmError(f"Prometheus {path}: {data.get('error') or data.get('status')}")
        return data["data"]

    def query(self, expr, at):
        return self.get("query", query=expr, time=f"{at:.3f}")["result"]


ALL = '{__name__=~".+"}'
NAME_LABEL = "gm_name"
# The functions over time drop __name__ (and refuse two series left with one
# label set): the name rides in NAME_LABEL through a subquery.
NAMED = f'label_replace({ALL}, "{NAME_LABEL}", "$1", "__name__", "(.+)")'


def read_tail(prom, restart):
    """The tail's first HISTORY_READ minutes, every series, from the restart
    on, and the metadata (what the research's `snapshot.py` wrote)."""
    from .aging import HISTORY_READ
    window = int(HISTORY_READ.total_seconds())
    series = []
    for r in prom.query(f"{ALL}[{window}s]", restart + window):
        samples = [[float(t), float(v)] for t, v in r.get("values") or [] if float(t) >= restart]
        if samples:
            series.append({"labels": r["metric"], "samples": samples})
    return {"restart": restart, "series": series, "metadata": prom.get("metadata")}


def read_seam(prom, vt0, restart):
    """What the seam check reads (W3 item 3): over the forged span, in
    SEAM_CHUNK slices (a query's samples bounded, so Prometheus' memory too),
    each series' minimum, last value and resets; the tail's first value of
    each from the restart on. Returns (past, tail_first)."""
    past = {}
    end = restart - 0.001
    edges, t = [], vt0
    while t < end:
        edges.append((t, min(t + SEAM_CHUNK, end)))
        t += SEAM_CHUNK
    step = f"{int(STEP)}s"
    for lo, hi in edges:
        window = f"{int(math.ceil(hi - lo + STEP * 2))}s"     # overlapping: no reset unseen
        for kind in ("last", "min", "resets"):
            fn = {"last": "last_over_time", "min": "min_over_time", "resets": "resets"}[kind]
            for r in prom.query(f"{fn}({NAMED}[{window}:{step}])", hi):
                lb = dict(r["metric"])
                name = lb.pop(NAME_LABEL, None)
                if not name:
                    continue
                lb["__name__"] = name
                p = past.setdefault(series_key(lb), {"labels": lb, "min": None, "last": None,
                                                     "resets": 0})
                v = float(r["value"][1])
                if kind == "last":
                    p["last"] = v
                elif kind == "min":
                    p["min"] = v if p["min"] is None else min(p["min"], v)
                else:
                    p["resets"] += v
    tail_first = {}
    for r in prom.query(f"{ALL}[{SEAM_TAIL}s]", restart + SEAM_TAIL):
        samples = [(float(t), float(v)) for t, v in r.get("values") or [] if float(t) >= restart]
        if samples:
            step = max((abs(b[1] - a[1]) for a, b in zip(samples, samples[1:])), default=0.0)
            tail_first[series_key(r["metric"])] = (r["metric"], samples[0][1], step)
    return {k: p for k, p in past.items() if p["last"] is not None}, tail_first


@dataclass
class HistoryResult:
    game_id: str
    record: dict = None             # the restart record's `history`
    findings: list = field(default_factory=list)
    virtual_t0: str = None
    restart: str = None
    noop: bool = False
    checked_only: bool = False
    figures: dict = field(default_factory=dict)
    lines: list = field(default_factory=list)

    @property
    def exit_code(self):
        if self.checked_only:
            return 0 if not self.findings else 1
        rec = self.record or {}
        return 0 if rec.get("result") == "ok" and rec.get("seam") == "ok" else 1

    def text(self):
        out = list(self.lines)
        out += [f"  seam {f['check']}: {f['series']}: {f['detail']}" for f in self.findings]
        if self.checked_only:
            out.append(f"Game {self.game_id}: seam {'ok' if not self.findings else 'failed'} "
                       f"({len(self.findings)} findings); nothing recorded")
            return "\n".join(out)
        rec = self.record or {}
        if self.noop:
            out.append("Already recorded; nothing done.")
        if rec.get("result") == "ok":
            count = len(self.findings) if not self.noop else ("0" if rec.get("seam") == "ok"
                                                               else "recorded")
            out.append(f"Game {self.game_id}: history from the virtual T0 {self.virtual_t0} to "
                       f"the restart {self.restart} imported at {rec.get('at')}; seam "
                       f"{rec.get('seam')} ({count} findings)")
        else:
            out.append(f"Game {self.game_id}: history import failed at {rec.get('at')}: "
                       f"{rec.get('reason')} (recorded; nothing torn down)")
        return "\n".join(out)


def refusal(st, impl, record, now, check_seam=False):
    """Why `gmctl history` is refused (W3 item 1), None when it may run."""
    from . import aging
    gid = st.get("game_id")
    if not record or record.get("mode") != "fake":
        return f"game {gid} is not a fake game (no restart record of mode fake)"
    if not aging.prometheus_node(impl):
        return f"game {gid} has no prometheus node: there is no history to import"
    if check_seam:
        if (record.get("history") or {}).get("result") != "ok":
            return f"game {gid}: no history import recorded ok; --check-seam reads one"
        return None
    if st.get("stage") in aging.AFTER_HANDOVER:
        return (f"game {gid} is at stage {st.get('stage')}: the history is imported before the "
                "hand-over, never while the players read Prometheus")
    restart = aging.parse_instant((record.get("restart") or {}).get("at"))
    if restart is None or st.get("stage") != aging.LOAD_STAGE:
        return (f"game {gid} is at stage {st.get('stage')}: the history follows the restart and "
                "start-load (gmctl clean-restart, then gmctl start-load)")
    if now < restart + aging.HISTORY_READ:
        return (f"game {gid}: the history reads the tail's first "
                f"{int(aging.HISTORY_READ.total_seconds() // 60)} minutes: not before "
                f"{aging.iso(restart + aging.HISTORY_READ)}")
    return None


def selection(scenario, impl, st):
    """The game's selection (W3 item 4): (instance, fault id, planted_at
    epoch or None, entries) of each instance the game plays."""
    from . import inject, model
    out = []
    plantings = st.get("plantings") or {}
    for inst, fault in inject.fault_instances(scenario, impl):
        planted = (plantings.get(inst["id"]) or {}).get("planted_at")
        out.append((inst["id"], fault.id, epoch(planted) if planted else None,
                    model.instance_history(scenario, inst["id"]) or ()))
    return out


def fill_drivers(scenario, impl, playground):
    """The Drivers of a game (fix 12): the scheduler nodes' connections as
    the game holds them (each node's schedule.yaml, the rendered copy where
    render rewrites it: the roles they connect as, the databases they
    name), and each postgres-exporter node's data source (its exporter.conf:
    the `instance` Prometheus scrapes it as, `<node>:9187`, to the
    `<host>:<port>` it reads)."""
    from . import fill, model
    from .model import GmError
    roles, databases, targets = set(), set(), {}
    for n in fill._nodes(scenario, impl, model.SCHEDULER_BRICK):
        schedule = fill._yaml(fill._seed_text(scenario, playground, n, fill.SCHEDULE_FILE),
                              f"{n['name']}'s schedule")
        for c in (schedule.get("connections") or {}).values():
            try:
                _, _, database = fill.parse_target((c or {}).get("target"), n["name"])
            except GmError:
                continue                # an HTTP connection: no role, no database
            databases.add(database)
            if c.get("role"):
                roles.add(str(c["role"]))
    for n in fill._nodes(scenario, impl, fill.EXPORTER_BRICK):
        conf = fill.parse_env_file(fill._seed_text(scenario, playground, n, fill.EXPORTER_CONF))
        try:
            host, port, _ = fill.parse_target((conf.get("DATA_SOURCE_URI") or "").split("?", 1)[0],
                                              n["name"])
        except GmError:
            continue
        targets[f"{n['name']}:{fill.EXPORTER_PORT}"] = f"{host}:{port}"
    return Drivers(frozenset(roles), frozenset(databases), targets)


def scheduler_targets(tail, nodes):
    """{scheduler node: its target's `instance` label} from the tail."""
    out = {}
    for s in tail["series"]:
        inst = s["labels"].get("instance") or ""
        host = inst.rsplit(":", 1)[0]
        if s["labels"]["__name__"].startswith(SCHEDULER_PREFIX) and host in nodes:
            out.setdefault(host, inst)
    return out


def helper_args(impl, node, *rest):
    """A helper container of the Prometheus node's image on its host, the
    TSDB volume mounted (W3 item 5; as restart's and clean-restart's)."""
    from . import localimpl
    from .restart import volume_name
    return ["run", "--rm", "-i", "--pull", "never", "--network", "none", "--user", "0:0",
            "--label", f"{localimpl.LABEL_GAME}={impl['game_id']}", *rest,
            "-v", f"{volume_name(impl, node, PROM_DATA_VOLUME)}:{TSDB_MOUNT}",
            "--entrypoint", "sh", impl["nodes"][node]["image"]]


def import_blocks(docker, impl, node, om_path):
    """Blocks created and moved in. Returns ({block id: bytes}, promtool's
    memory peak in bytes or None)."""
    from .model import GmError
    host = docker.on_host(impl["nodes"][node].get("host"))
    with open(om_path, "rb") as stdin:
        r = host.run(helper_args(impl, node) + ["-c", IMPORT_SCRIPT], stdin=stdin, check=False)
    if r.returncode != 0:
        detail = " ".join((r.stderr or "").split())[-300:] or f"exit status {r.returncode}"
        raise GmError(f"the import's helper container: {detail}")
    blocks, peak = {}, None
    for line in (r.stdout or "").splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[0] == "block" and ULID_RE.match(parts[1]):
            blocks[parts[1]] = int(parts[2])
        elif len(parts) == 2 and parts[0] == "peak":
            peak = int(parts[1]) if parts[1].isdigit() else None
    if not blocks:
        raise GmError("promtool created no block")
    return blocks, peak


def remove_blocks(docker, impl, node, restart):
    """A failed attempt's blocks removed before a retry (W3 item 1)."""
    from .model import GmError
    host = docker.on_host(impl["nodes"][node].get("host"))
    r = host.run(helper_args(impl, node, "-e", f"GM_RESTART_MS={int(restart * 1000)}")
                 + ["-s"], input=REMOVE_SCRIPT, check=False)
    if r.returncode != 0:
        detail = " ".join((r.stderr or "").split())[-300:] or f"exit status {r.returncode}"
        raise GmError(f"removing the failed attempt's blocks: {detail}")
    return [line.split()[1] for line in (r.stdout or "").splitlines()
            if line.startswith("removed ")]


def wait_loaded(prom, vt0, restart, sleep, clock, bound=LOAD_WAIT, interval=LOAD_POLL):
    """Prometheus loads the blocks by itself (its reload, about a minute):
    never restarted (W3 item 5). Seconds waited, None when not loaded."""
    from .model import GmError
    probe = (vt0 + restart) / 2
    start = clock()
    while True:
        try:
            r = prom.query(f"count({ALL})", probe)
            if r and float(r[0]["value"][1]) > 0:
                return round(clock() - start, 1)
        except GmError:
            pass
        if clock() - start >= bound:
            return None
        sleep(interval)


TSDB_SCRAPE_WAIT = 60               # seconds for Prometheus' self-scrape to show the blocks


def tsdb_figures(prom, now, sleep, clock, bound=TSDB_SCRAPE_WAIT, interval=LOAD_POLL):
    """Prometheus' own view of its TSDB (spec D541's series), for W3-x:
    read once its self-scrape shows a loaded block (its series lag the
    load by a scrape), else as they are after `bound` seconds, with
    `stale: true`. `now()` gives the instant to read at."""
    start = clock()
    while True:
        out = {}
        for name in ("prometheus_tsdb_lowest_timestamp_seconds",
                     "prometheus_tsdb_blocks_loaded", "prometheus_tsdb_storage_blocks_bytes"):
            r = prom.query(name, now())
            if r:
                out[name] = float(r[0]["value"][1])
        if out.get("prometheus_tsdb_blocks_loaded", 0) > 0:
            return out
        if clock() - start >= bound:
            return dict(out, stale=True)
        sleep(interval)


def reason_of(findings):
    head = "; ".join(f"seam {f['check']}: {f['series']}: {f['detail']}"
                     for f in findings[:REASON_FINDINGS])
    more = len(findings) - REASON_FINDINGS
    return head + (f"; and {more} more" if more > 0 else "")


def run_lock(ldir):
    """An exclusive `flock` on `<ldir>/.history.lock`, held for a whole
    import: the GM's hand run and the timer's never import at once; the
    second waits for the first, then finds its result (a no-op after
    `ok`). Never the state lock (held only around a write)."""
    import contextlib
    import fcntl
    import os
    from pathlib import Path

    @contextlib.contextmanager
    def held():
        Path(ldir).mkdir(parents=True, exist_ok=True)
        fd = os.open(Path(ldir) / RUN_LOCK, os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield
        finally:
            os.close(fd)
    return held()


def run(scenario_dir, playground, check_seam=False, docker=None, now=None, sleep=None,
        clock=None):
    """`gmctl history`; returns a HistoryResult (its `exit_code` is the
    command's). Raises GmError on a refusal (nothing done, nothing
    recorded). Never takes the development Docker lock (W3 item 1); an
    import holds the game's run lock (run_lock), the refusals read again
    once it is taken."""
    from . import aging, localimpl
    from .model import GmError
    ldir, st = aging._game(scenario_dir, playground)
    aging.timer_run(st)
    why = refusal(st, localimpl.read_implementation(ldir), localimpl.read_restart_record(ldir),
                  now or aging.now_utc(), check_seam)
    if why:
        raise GmError(why + "; nothing done")
    if check_seam:
        return _run(scenario_dir, playground, True, docker, now, sleep, clock)
    with run_lock(ldir):
        return _run(scenario_dir, playground, False, docker, now, sleep, clock)


def _run(scenario_dir, playground, check_seam, docker, now, sleep, clock):
    import shutil
    import time
    from pathlib import Path
    from . import aging, localimpl, model
    from .docker import for_local_dir
    from .fill import FILL_DIR, METRICS_SUFFIX
    from .model import GmError
    sleep = sleep or time.sleep
    clock = clock or time.monotonic
    ldir, st = aging._game(scenario_dir, playground)
    by_timer = aging.timer_run(st)
    impl = localimpl.read_implementation(ldir)
    record = localimpl.read_restart_record(ldir)
    why = refusal(st, impl, record, now or aging.now_utc(), check_seam)
    if why:
        raise GmError(why + "; nothing done")
    node = aging.prometheus_node(impl)
    vt0, restart = epoch(record["virtual_t0"]), epoch(record["restart"]["at"])
    result = HistoryResult(st.get("game_id"), virtual_t0=record["virtual_t0"],
                           restart=record["restart"]["at"])
    docker = docker or for_local_dir(ldir)
    prom = Prometheus(ldir, node, docker)
    if check_seam:
        result.checked_only = True
        past, first = read_seam(prom, vt0, restart)
        result.findings = seam_findings(past, first, prom.get("metadata"))
        result.record = record.get("history")
        return result
    done = record.get("history") or {}
    if done.get("result") == "ok":
        result.record, result.noop = done, True
        return result
    if by_timer:
        down = aging.wait_for_nodes(docker, impl, sleep=sleep, clock=clock)
        if down:
            result.lines.append(f"Nodes not running after {aging.LATE_RUN_WAIT} s: "
                                f"{', '.join(down)}; importing anyway.")
    attempt = {"began": aging.iso(aging.now_utc()), "ended": None, "outcome": None,
               "reason": None, "seam": []}
    figures, work = {}, Path(ldir) / HISTORY_DIR
    seam_state, reason, outcome = "unchecked", None, "failed"
    try:
        if done.get("result") == "failed":
            figures["removed_before_retry"] = remove_blocks(docker, impl, node, restart)
        work.mkdir(parents=True, exist_ok=True)
        t = time.monotonic()
        tail = read_tail(prom, restart)
        figures["tail_series"] = len(tail["series"])
        figures["tail_read_s"] = round(time.monotonic() - t, 1)
        if not tail["series"]:
            raise GmError("the tail holds no sample from the restart on")
        localimpl.write_text(work / TAIL_FILE, json.dumps(tail))
        metrics = {}
        for sched in aging.scheduler_nodes(impl):
            path = Path(ldir) / FILL_DIR / f"{sched}{METRICS_SUFFIX}"
            if path.is_file():
                metrics[sched] = read_metrics(path.read_text().splitlines())
        scenario = model.load_scenario(scenario_dir)
        timeline = impl.get(localimpl.TIMELINE) or {}
        drivers = fill_drivers(scenario, impl, playground)
        figures["drivers"] = {"roles": sorted(drivers.roles), "databases": sorted(drivers.databases),
                              "exporters": drivers.targets}
        t = time.monotonic()
        composer = Composer(vt0, restart, tail, metrics=metrics,
                            scheduler_instances=scheduler_targets(tail, set(metrics)),
                            selection=selection(scenario, impl, st),
                            shift=timeline.get("shift") or 0, seed=timeline.get("seed") or 0,
                            drivers=drivers)
        with open(work / OM_FILE, "w", buffering=1 << 20) as f:
            report = composer.write(f)
        figures["compose_s"] = round(time.monotonic() - t, 1)
        figures["series"], figures["samples"] = report.series, report.samples
        figures["openmetrics_bytes"] = (work / OM_FILE).stat().st_size
        figures["report"] = {k: v for k, v in report.as_dict().items() if k != "clamped"}
        figures["report"]["clamped"] = len(report.clamped)
        localimpl.write_text(work / REPORT_FILE, json.dumps(report.as_dict(), indent=1))
        t = time.monotonic()
        blocks, peak = import_blocks(docker, impl, node, work / OM_FILE)
        figures["import_s"] = round(time.monotonic() - t, 1)
        figures["blocks"] = blocks
        figures["promtool_memory_peak_bytes"] = peak
        waited = wait_loaded(prom, vt0, restart, sleep, clock)
        if waited is None:
            raise GmError(f"Prometheus did not load the blocks within {LOAD_WAIT} s (it is never "
                          "restarted for them)")
        figures["loaded_after_s"] = waited
        outcome = "ok"
        t = time.monotonic()
        past, first = read_seam(prom, vt0, restart)
        result.findings = seam_findings(past, first, tail["metadata"])
        figures["seam_s"] = round(time.monotonic() - t, 1)
        seam_state = "ok" if not result.findings else "failed"
        if result.findings:
            reason = reason_of(result.findings)
        try:
            figures["tsdb"] = tsdb_figures(prom, lambda: aging.now_utc().timestamp(), sleep,
                                           clock)
        except GmError as exc:
            figures["tsdb"] = {"unread": str(exc)}
    except GmError as exc:
        reason = str(exc)
    rec = {"at": aging.iso(aging.now_utc()), "result": outcome, "seam": seam_state}
    if reason:
        rec["reason"] = " ".join(reason.split())
    attempt.update(ended=rec["at"], outcome=outcome, reason=rec.get("reason"),
                   seam=result.findings, figures=figures)

    def change(state):
        hist = state.get(aging.HISTORY_IMPORT) or {"timer": None, "attempts": []}
        hist.setdefault("attempts", []).append(attempt)
        state[aging.HISTORY_IMPORT] = hist
    localimpl.update_state(ldir, change)
    record = localimpl.read_restart_record(ldir) or record
    record["history"] = rec
    localimpl.write_restart_record(ldir, record)
    if outcome == "ok":
        shutil.rmtree(work, ignore_errors=True)
    result.record, result.figures = rec, figures
    return result
