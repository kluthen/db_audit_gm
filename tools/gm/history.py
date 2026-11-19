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
- the scheduler's series from the fill's metrics records, never a second
  simulation, so the `queue` entries reach the past through them (W3 item
  4); they reset at the restart (the program restarted);
- the selected instances' entries (W3 item 4): each from its planting
  (`planted_at`, virtual) to the restart, nothing for an instance planted
  in the tail; `gauge_before` until the planting; `daily_spike` at its
  scenario time on each day; `suppressed_by` from the planting of the
  first selected instance of a hiding fault (spec D543); `remove` last,
  winning on its series.

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
SHAPE_RATIO = (0.25, 4.0)           # the load's ratio to the tail's, bounded
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


class LoadShape:
    """Calls a minute, every scheduler node together, from the fill's
    records (a moving mean of SHAPE_SMOOTH minutes), against the tail's.
    `ratio(t)` is the load at `t` over the tail's, bounded by SHAPE_RATIO;
    1 throughout without records or a tail load."""

    def __init__(self, metrics, tail_per_minute):
        per_minute = collections.Counter()
        for records in (metrics or {}).values():
            prev = {}
            for rec in records:
                calls = rec.get("scheduler_calls_total") or {}
                minute = int(rec["t"] // 60)
                for k, v in calls.items():
                    per_minute[minute] += max(0, v - prev.get(k, 0))
                prev = calls
        self.minutes = sorted(per_minute)
        self.values = [per_minute[m] for m in self.minutes]
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


def tail_calls_per_minute(tail_series):
    """The tail's calls a minute, every scheduler node together."""
    total = 0.0
    for s in tail_series:
        if s["labels"]["__name__"] == "scheduler_calls_total" and len(s["samples"]) > 1:
            total += tail_rate(s["samples"]) * 60
    return total


# --- The selection's entries (W3 item 4) ---------------------------------------------

@dataclass
class Overlay:
    """One selected instance's entry, its window in the past resolved:
    `start` to `end` (epoch seconds; `gauge_before` holds before `start`)."""
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
    clamped: list = field(default_factory=list)
    synthesized: list = field(default_factory=list)
    unmatched: list = field(default_factory=list)
    removed_samples: int = 0
    notes: list = field(default_factory=list)

    def as_dict(self):
        return {"series": self.series, "samples": self.samples, "classes": dict(self.classes),
                "clamped": self.clamped, "synthesized": self.synthesized,
                "unmatched": self.unmatched, "removed_samples": self.removed_samples,
                "notes": self.notes}


class Composer:
    """The forged past of one game (W3 item 4).

    `tail`: {"series": [{"labels", "samples": [[t, v], ...]}], "metadata"}
    read from the restart on; `metrics`: {node: records} (read_metrics);
    `scheduler_instances`: {node: the `instance` label its target has};
    `selection`: overlays_for's input; `shift`: hours, scenario time minus
    UTC; `seed`: the game's seed, for the noise."""

    def __init__(self, vt0, restart, tail, metrics=None, scheduler_instances=None,
                 selection=(), shift=0, seed=0):
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
        self.step = self._scrape_interval()
        self.past_start = self.vt0 - PAST_START_BEFORE

    def _scrape_interval(self):
        gaps = sorted(b[0] - a[0] for s in self.tail for a, b in zip(s["samples"], s["samples"][1:])
                      if b[0] > a[0])
        return round(gaps[len(gaps) // 2], 3) if gaps else STEP

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
            vals = self.size(smp, ts)
        elif cls == "activity":
            vals = self.activity(values, ts, r, integral)
        elif cls == "level":
            vals = self.level(values, ts, r, integral)
        else:
            vals = self.counter(lb, smp, ts, cls == "counter_reset", r, integral)
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

    def activity(self, values, ts, r, integral):
        """Around the tail's median, with its real spread, scaled by the
        load's shape (fix 5); never below zero."""
        ordered = sorted(values)
        median = ordered[len(ordered) // 2]
        spread = [v - median for v in values]
        out = []
        for t in ts:
            v = max(0.0, median * self.shape.ratio(t) + r.choice(spread))
            out.append(round(v) if integral else v)
        return out

    def size(self, smp, ts):
        """A ramp ending at the tail's first value: the tail's slope, per
        unit of load, over the load's shape (fix 5), never below zero."""
        (t0, v0), (t1, v1) = smp[0], smp[-1]
        slope = (v1 - v0) / (t1 - t0) if t1 > t0 else 0.0
        out, v = [], v0
        for t in reversed(ts):
            v -= slope * self.step * self.shape.ratio(t)
            out.append(max(0.0, v))
        out.reverse()
        return [round(x) for x in out] if float(v0).is_integer() else out

    def counter(self, lb, smp, ts, resets, r, integral):
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
        inc = [max(0.0, rate * self.step * self.shape.ratio(t) * (1 + r.gauss(0, COUNTER_JITTER)))
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
                vals = [float(o.fields["value"]) if o.active(t) else v for t, v in zip(ts, vals)]
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
    {series key: (labels, first value from the restart on)}. Returns the
    findings, [] when the seam is ok."""
    out = []
    if not past:
        return [finding("empty", "*", "no sample before the restart: the history is not there")]
    for key in sorted(past):
        p = past[key]
        lb = p["labels"]
        if p.get("min") is not None and p["min"] < 0:
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
            rel = abs(first - last) / max(abs(last), 1.0)
            if rel > JUMP_TOLERANCE:
                out.append(finding("jump", key, f"{_value(last)} -> {_value(first)} at the join "
                                                f"({rel:.1%}, tolerance {JUMP_TOLERANCE:.0%})"))
    for key in sorted(tail_first):
        lb, first = tail_first[key]
        if first < 0:
            out.append(finding("negative", key, f"{_value(first)} at the join"))
    return out
