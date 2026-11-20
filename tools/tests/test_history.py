"""Unit tests of `gmctl history` (tools/gm/history.py; v0.6 build plan
chunk 10, capture W3 items 1 to 5): the composer, each kind of a history
signature and a `suppressed_by` pair, the restart's resets and the seam
check's verdicts. The live reading and the import are tested with stand-ins
below; the whole on the fixture (tools/tests/fixtures/fixture-fill/
run-history-test.sh)."""

import io
import json
import math
import unittest

from tools.gm import history
from tools.gm.model import HistoryEntry
from tools.tests import FIXTURES, SUFFICIENT, ScenarioCopyTest

R = 1_763_550_000.0                  # the restart: 2025-11-19T11:00:00Z
VT0 = R - 4 * 3600
PLANT = R - 2 * 3600
STEP = 15.0
PG = {"job": "postgres", "instance": "exporter:9187"}
META = {
    "pg_stat_user_tables_seq_scan": [{"type": "counter"}],
    "pg_stat_database_xact_commit": [{"type": "counter"}],
    "prometheus_http_requests_total": [{"type": "counter"}],
    "pg_stat_user_tables_n_dead_tup": [{"type": "gauge"}],
    "pg_stat_user_tables_n_live_tup": [{"type": "gauge"}],
    "pg_database_size_bytes": [{"type": "gauge"}],
    "pg_stat_user_indexes_size_bytes": [{"type": "gauge"}],
    "pg_stat_activity_count": [{"type": "gauge"}],
    "process_start_time_seconds": [{"type": "gauge"}],
    "scheduler_calls_total": [{"type": "counter"}],
    "scheduler_call_duration_seconds": [{"type": "histogram"}],
    "up": [{"type": "gauge"}],
    "pg_stat_database_xact_rollback": [{"type": "counter"}],
    "pg_stat_statements_calls_total": [{"type": "counter"}],
    "pg_stat_wal_records_total": [{"type": "counter"}],
}


def tail_series(labels, values, phase=5.0):
    return {"labels": dict(labels), "samples": [[R + phase + STEP * i, v]
                                                for i, v in enumerate(values)]}


def tail():
    n = 40
    series = [
        tail_series({"__name__": "pg_stat_user_tables_seq_scan", **PG, "relname": "orders"},
                    [50_000 + 2 * i for i in range(n)]),
        tail_series({"__name__": "pg_stat_database_xact_commit", **PG, "datname": "shop"},
                    [900_000 + 30 * i for i in range(n)]),
        tail_series({"__name__": "pg_stat_user_tables_n_dead_tup", **PG, "relname": "orders"},
                    [100 + (i % 5) for i in range(n)]),
        tail_series({"__name__": "pg_stat_user_tables_n_live_tup", **PG, "relname": "old"},
                    [7000] * n),
        tail_series({"__name__": "pg_database_size_bytes", **PG, "datname": "shop"},
                    [80_000_000 + 8192 * i for i in range(n)]),
        tail_series({"__name__": "pg_stat_user_indexes_size_bytes", **PG, "indexrelname": "kept"},
                    [16384] * n),
        tail_series({"__name__": "pg_stat_activity_count", **PG, "datname": "shop",
                     "state": "active"}, [2 + (i % 3) for i in range(n)]),
        tail_series({"__name__": "up", **PG}, [1] * n),
        tail_series({"__name__": "process_start_time_seconds", "job": "prometheus",
                     "instance": "localhost:9090"}, [R + 1] * n, phase=8.0),
        tail_series({"__name__": "prometheus_http_requests_total", "job": "prometheus",
                     "instance": "localhost:9090", "code": "200"},
                    [3 + i for i in range(n)], phase=8.0),
        tail_series({"__name__": "up", "job": "scheduler", "instance": "producer:9120"},
                    [1] * n, phase=11.0),
        tail_series({"__name__": "scheduler_calls_total", "job": "scheduler",
                     "instance": "producer:9120", "key": "orders.detail"},
                    [2.5 * i for i in range(n)], phase=11.0),
        tail_series({"__name__": "scheduler_call_duration_seconds_bucket", "job": "scheduler",
                     "instance": "producer:9120", "key": "orders.detail", "le": "0.01"},
                    [2 * i for i in range(n)], phase=11.0),
    ]
    return {"series": series, "metadata": META}


def metrics():
    """The producer's fill records: 10 calls a minute of orders.detail
    from the virtual T0, 8 of them under 10 ms."""
    out = []
    m = VT0 - VT0 % 60
    calls = 0
    while m < R:
        m += 60
        calls += 10
        out.append(json.dumps({
            "at": history.iso(m),
            "scheduler_calls_total": {"orders.detail": calls},
            "scheduler_errors_total": {"orders.detail": 0},
            "scheduler_call_duration_seconds": {"orders.detail": {
                "buckets": {"0.001": 0, "0.01": calls * 8 // 10}, "sum": calls * 0.004,
                "count": calls}},
            "scheduler_job_runs_total": [], "scheduler_job_skips_total": []}))
    return {"producer": history.read_metrics(out)}


def entry(kind, suppressed_by=(), **fields):
    return HistoryEntry(kind=kind, fields=fields, suppressed_by=tuple(suppressed_by))


SPIKE_AT = "12:00"                    # scenario time; the shift +2 puts it at 10:00 UTC
SHIFT = 2

SIGNATURE = (
    entry("counter_per_call", key="orders.detail", per_call=1,
          series='pg_stat_user_tables_seq_scan{relname="orders"}'),
    entry("gauge_sawtooth", series='pg_stat_user_tables_n_dead_tup{relname="orders"}',
          period="30m", amplitude=500),
    entry("gauge_before", series='pg_stat_user_indexes_size_bytes{indexrelname="gone"}',
          value=8192),
    entry("daily_spike", series='pg_stat_activity_count{datname="shop",state="active"}',
          at=SPIKE_AT, duration="10m", value=50),
    entry("remove", series='pg_stat_user_tables_n_live_tup{relname="old"}'),
    entry("queue", key="orders.detail", service={"median": 0.05, "sigma": 0.3}),
)


def compose(selection, **kw):
    c = history.Composer(VT0, R, tail(), metrics=metrics(),
                         scheduler_instances={"producer": "producer:9120"},
                         selection=selection, shift=SHIFT, seed=7, **kw)
    out = {history.series_key(lb): (lb, points) for lb, points in c.compose()}
    return c, out


def key(name, **labels):
    return history.series_key({"__name__": name, **labels})


class TestSelector(unittest.TestCase):

    def test_parse_and_match(self):
        s = history.Selector.parse('pg_x{a="1",b=~"o.*",c!="2",d!~"z"}')
        self.assertEqual(s.name, "pg_x")
        self.assertTrue(s.matches({"__name__": "pg_x", "a": "1", "b": "orders", "c": "3"}))
        self.assertFalse(s.matches({"__name__": "pg_x", "a": "1", "b": "x"}))
        self.assertFalse(s.matches({"__name__": "pg_x", "a": "1", "b": "o", "d": "z"}))
        self.assertEqual(s.equalities(), {"__name__": "pg_x", "a": "1"})
        self.assertEqual(history.Selector.parse('{__name__="up"}').name, "up")
        for bad in ("", "{a=1}", "pg_x{a=\"1\" junk}"):
            with self.assertRaises(ValueError):
                history.Selector.parse(bad)


class TestKinds(unittest.TestCase):
    """Each kind of a signature composed (the Done when's first item)."""

    @classmethod
    def setUpClass(cls):
        cls.c, cls.out = compose([("f8", "fixture-dropped-index", PLANT, SIGNATURE)])

    def points(self, k):
        self.assertIn(k, self.out)
        return self.out[k][1]

    def test_span_and_values(self):
        for lb, points in self.out.values():
            for t, v in points:
                self.assertTrue(VT0 <= t < R, (lb, t))
                self.assertGreaterEqual(v, 0, lb)
            ts = [t for t, _ in points]
            self.assertEqual(ts, sorted(ts))
        self.assertEqual(self.c.step, STEP)

    def test_counter_per_call(self):
        pts = self.points(key("pg_stat_user_tables_seq_scan", **PG, relname="orders"))
        hour = 3600

        def increase(lo, hi):
            vals = [v for t, v in pts if lo <= t < hi]
            return vals[-1] - vals[0]
        before = increase(PLANT - hour, PLANT)
        after = increase(PLANT, PLANT + hour)
        # 10 calls a minute, one sequential scan each, from the planting
        self.assertAlmostEqual(after - before, 600, delta=60)
        # joined: the last forged value at or under the tail's first, monotonic
        self.assertLessEqual(pts[-1][1], 50_000)
        self.assertTrue(all(b[1] >= a[1] for a, b in zip(pts, pts[1:])))

    def test_gauge_sawtooth(self):
        pts = self.points(key("pg_stat_user_tables_n_dead_tup", **PG, relname="orders"))
        before = [v for t, v in pts if t < PLANT]
        after = [v for t, v in pts if t >= PLANT]
        self.assertLess(max(before), 200)
        self.assertGreater(max(after), max(before) + 400)
        self.assertGreaterEqual(min(after), 0)

    def test_gauge_before(self):
        k = key("pg_stat_user_indexes_size_bytes", **PG, indexrelname="gone")
        pts = self.points(k)
        self.assertIn(k, self.c.report.synthesized)
        self.assertTrue(all(v == 8192 and t < PLANT for t, v in pts))
        self.assertGreater(len(pts), 100)
        # the sibling it borrowed its labels from keeps its own level
        kept = self.points(key("pg_stat_user_indexes_size_bytes", **PG, indexrelname="kept"))
        self.assertTrue(all(v == 16384 for _, v in kept))

    def test_gauge_before_adds_its_value(self):
        """On a series the tail has, the value is added to the level drawn
        up to the planting, which keeps its shape and steps down by the
        value at the planting (spec D585)."""
        size = key("pg_database_size_bytes", **PG, datname="shop")
        _, base = compose([])
        c, out = compose([("f8", "fixture-dropped-index", PLANT, (
            entry("gauge_before", series='pg_database_size_bytes{datname="shop"}',
                  value=20_000_000),))])
        self.assertNotIn(size, c.report.synthesized)
        drawn, plain = dict(out[size][1]), dict(base[size][1])
        self.assertEqual(set(drawn), set(plain))
        before = [t for t in plain if t < PLANT]
        after = [t for t in plain if t >= PLANT]
        self.assertTrue(len(before) > 100 and len(after) > 100)
        self.assertTrue(all(drawn[t] == plain[t] + 20_000_000 for t in before))
        self.assertTrue(all(drawn[t] == plain[t] for t in after))
        # the step at the planting is the value, less the drawn level's own move
        last, first = before[-1], after[0]
        self.assertAlmostEqual(drawn[last] - drawn[first], 20_000_000, delta=8192 * 4)

    def test_daily_spike(self):
        pts = self.points(key("pg_stat_activity_count", **PG, datname="shop", state="active"))
        lo = math.floor(R / 86400) * 86400 + 10 * 3600      # 10:00 UTC, after the planting
        self.assertTrue(PLANT <= lo < R)
        inside = [v for t, v in pts if lo <= t < lo + 600]
        outside = [v for t, v in pts if not lo <= t < lo + 600]
        self.assertEqual(len(inside), 40)
        self.assertTrue(all(v == 50 for v in inside))
        self.assertTrue(all(v < 50 for v in outside))

    def test_remove(self):
        pts = self.points(key("pg_stat_user_tables_n_live_tup", **PG, relname="old"))
        self.assertTrue(pts and all(t < PLANT for t, _ in pts))
        self.assertGreater(self.c.report.removed_samples, 0)

    def test_queue_through_the_fill_records(self):
        calls = self.points(key("scheduler_calls_total", job="scheduler",
                                instance="producer:9120", key="orders.detail"))
        t, v = calls[-1]
        rec = [r for r in metrics()["producer"] if r["t"] <= t][-1]
        self.assertEqual(v, rec["scheduler_calls_total"]["orders.detail"])
        # the bucket keeps the tail's le text; +Inf and the sum drawn too
        self.points(key("scheduler_call_duration_seconds_bucket", job="scheduler",
                        instance="producer:9120", key="orders.detail", le="0.01"))
        self.points(key("scheduler_call_duration_seconds_bucket", job="scheduler",
                        instance="producer:9120", key="orders.detail", le="+Inf"))
        start = self.points(key("scheduler_start_time_seconds", job="scheduler",
                                instance="producer:9120"))
        self.assertTrue(all(v == VT0 for _, v in start))
        # no overlay drawn for the queue entry
        self.assertEqual({o.kind for o in self.c.overlays},
                         {"counter_per_call", "gauge_sawtooth", "gauge_before", "daily_spike",
                          "remove"})

    def test_none(self):
        c, out = compose([("f1", "quiet", PLANT, (entry("none"),))])
        self.assertEqual(c.overlays, [])
        _, base = compose([])
        self.assertEqual(set(out), set(base))

    def test_restart_drawn(self):
        up = self.points(key("up", **PG))
        self.assertEqual(up[-1][1], 0)
        self.assertTrue(all(v == 1 for _, v in up[:-1]))
        start = self.points(key("process_start_time_seconds", job="prometheus",
                                instance="localhost:9090"))
        self.assertTrue(all(v == VT0 - history.PAST_START_BEFORE for _, v in start))
        # Prometheus' own counter resets at the restart; the database's joins
        own = self.points(key("prometheus_http_requests_total", job="prometheus",
                              instance="localhost:9090", code="200"))
        self.assertGreater(own[-1][1], 3)
        commits = self.points(key("pg_stat_database_xact_commit", **PG, datname="shop"))
        self.assertLessEqual(commits[-1][1], 900_000)
        self.assertGreater(commits[-1][1], 900_000 - 60)

    def test_size_grows_with_the_load(self):
        pts = self.points(key("pg_database_size_bytes", **PG, datname="shop"))
        self.assertTrue(all(b[1] >= a[1] for a, b in zip(pts, pts[1:])))
        self.assertLess(pts[0][1], pts[-1][1])
        self.assertLessEqual(pts[-1][1], 80_000_000)

    def test_tail_planting_adds_nothing(self):
        c, out = compose([("f8", "fixture-dropped-index", R + 600, SIGNATURE)])
        self.assertEqual(c.overlays, [])
        base, base_out = compose([])
        self.assertEqual(set(out), set(base_out))

    def test_openmetrics(self):
        buf = io.StringIO()
        c = history.Composer(VT0, R, tail(), metrics=metrics(),
                             scheduler_instances={"producer": "producer:9120"},
                             selection=[("f8", "x", PLANT, SIGNATURE)], shift=SHIFT, seed=7)
        report = c.write(buf)
        lines = buf.getvalue().splitlines()
        self.assertEqual(lines[-1], "# EOF")
        self.assertEqual(report.samples, len(lines) - 1)
        for line in lines[:-1]:
            head, value, at = line.rsplit(" ", 2)
            float(value)
            self.assertTrue(VT0 <= float(at) < R)
            self.assertRegex(head, r'^[a-zA-Z_:][a-zA-Z0-9_:]*\{.*\}$')


# --- Each series' driver (master spec 9.9 fix 12, spec D594, D595) ----------------------------

NIGHT = (VT0 + 3600, VT0 + 2 * 3600)  # the fill's load drops to a tenth, its transactions to a half
DRIVERS = history.Drivers(frozenset({"shop_app"}), frozenset({"shop"}), {"exporter:9187": "db:5432"})
SHOP_DB = "db:5432/shop"


def night_metrics(transactions=True, day=120):
    """The producer's fill records: 10 calls a minute (the tail's), 1 at
    night; `day` transactions a minute on the shop's database (120: the
    tail's commits), half of them at night (each night call ran more of
    them)."""
    out, m, calls, xacts = [], VT0 - VT0 % 60, 0, 0
    while m < R:
        night = NIGHT[0] <= m < NIGHT[1]
        m += 60
        calls += 1 if night else 10
        xacts += day // 2 if night else day
        rec = {"at": history.iso(m), "scheduler_calls_total": {"orders.detail": calls},
               "scheduler_errors_total": {"orders.detail": 0}, "scheduler_call_duration_seconds": {},
               "scheduler_job_runs_total": [], "scheduler_job_skips_total": []}
        if transactions:
            rec[history.FILL_TRANSACTIONS] = {SHOP_DB: xacts, "db:5432/other": xacts}
        out.append(json.dumps(rec))
    return {"producer": history.read_metrics(out)}


def driven_tail():
    t = tail()
    n = 40
    t["series"] += [
        tail_series({"__name__": "pg_stat_database_xact_rollback", **PG, "datname": "shop"}, [12] * n),
        tail_series({"__name__": "pg_stat_database_xact_commit", **PG, "datname": "postgres"},
                    [400_000 + 7 * i for i in range(n)]),
        # the monitoring's own statements in the shop's database: `user` decides first
        tail_series({"__name__": "pg_stat_statements_calls_total", **PG, "user": "monitoring",
                     "datname": "shop", "queryid": "1"}, [100 + 5 * i for i in range(n)]),
        tail_series({"__name__": "pg_stat_statements_calls_total", **PG, "user": "shop_app",
                     "datname": "shop", "queryid": "2"}, [100 + 5 * i for i in range(n)]),
        tail_series({"__name__": "pg_stat_wal_records_total", **PG}, [100 + 5 * i for i in range(n)]),
    ]
    return t


def increase(points, lo, span=2400):
    """A counter's increase over `span` seconds from `lo`."""
    vals = [v for t, v in points if lo <= t < lo + span]
    return vals[-1] - vals[0]


def night_over_day(points):
    """A counter's increase over 40 minutes of the night, over the same at
    day (margins for the shape's moving mean)."""
    return increase(points, NIGHT[0] + 600) / increase(points, NIGHT[1] + 600)


class TestDrivers(unittest.TestCase):

    def compose(self, metrics, drivers=DRIVERS, selection=()):
        c = history.Composer(VT0, R, driven_tail(), metrics=metrics,
                             scheduler_instances={"producer": "producer:9120"},
                             selection=list(selection), shift=SHIFT, seed=7, drivers=drivers)
        return c, {history.series_key(lb): points for lb, points in c.compose()}

    def test_the_monitorings_series_flat_the_schedulers_following_the_load(self):
        c, out = self.compose(night_metrics())
        mon = out[key("pg_stat_statements_calls_total", **PG, user="monitoring", datname="shop",
                      queryid="1")]
        app = out[key("pg_stat_statements_calls_total", **PG, user="shop_app", datname="shop",
                      queryid="2")]
        self.assertAlmostEqual(night_over_day(mon), 1.0, delta=0.05)       # flat across the drop
        self.assertAlmostEqual(night_over_day(app), 0.1, delta=0.02)       # following it
        # another database's counters (the postgres database) flat too
        other = out[key("pg_stat_database_xact_commit", **PG, datname="postgres")]
        self.assertAlmostEqual(night_over_day(other), 1.0, delta=0.05)
        self.assertGreater(c.report.drivers["flat"], 0)

    def test_a_series_with_neither_label_follows_the_load(self):
        _, out = self.compose(night_metrics())
        wal = out[key("pg_stat_wal_records_total", **PG)]
        self.assertAlmostEqual(night_over_day(wal), 0.1, delta=0.02)
        seq = out[key("pg_stat_user_tables_seq_scan", **PG, relname="orders")]
        self.assertAlmostEqual(night_over_day(seq), 0.1, delta=0.02)

    def test_a_ratio_below_the_old_floor_is_kept(self):
        """(b): the night's tenth is no longer lifted to a quarter; the
        floor left only bounds a minute without any call."""
        self.assertLess(history.SHAPE_RATIO[0], 0.25)
        shape = history.LoadShape(night_metrics(), 10.0)
        self.assertAlmostEqual(shape.ratio(sum(NIGHT) / 2), 0.1)
        self.assertAlmostEqual(shape.ratio(VT0 + 3 * 3600), 1.0)
        self.assertEqual(history.Shape({}, 10.0).ratio(R), 1.0)            # no record: no shape
        self.assertEqual(history.Shape({int(VT0 // 60): 0}, 10.0).ratio(VT0), history.SHAPE_RATIO[0])

    def test_a_databases_commits_follow_its_recorded_transactions(self):
        c, out = self.compose(night_metrics())
        commits = out[key("pg_stat_database_xact_commit", **PG, datname="shop")]
        # 60 transactions a minute at night, 120 by day: the tail's 120 commits a minute
        self.assertAlmostEqual(night_over_day(commits), 0.5, delta=0.03)
        self.assertEqual(c.report.drivers["transactions"], 2)              # commits and rollbacks
        # joined to the tail, never past it
        self.assertLessEqual(commits[-1][1], 900_000)
        self.assertGreater(commits[-1][1], 900_000 - 300)

    def test_commits_the_fill_never_counts_keep_the_tails_rate_per_call(self):
        """The fill counts 9 transactions a call by day, the tail commits
        12 a call (a session's set-up, a parallel worker's start-up, never
        counted by the fill): by day the forged commits keep the tail's 12
        a call (120 a minute), not the fill's 9; at night they follow the
        fill's transactions, half the day's."""
        c, out = self.compose(night_metrics(day=90))
        commits = out[key("pg_stat_database_xact_commit", **PG, datname="shop")]
        day = increase(commits, NIGHT[1] + 600) / 40          # a minute; 10 calls a minute
        self.assertAlmostEqual(day / 10, 12.0, delta=0.4)
        self.assertAlmostEqual(night_over_day(commits), 0.5, delta=0.03)
        self.assertIn(f"{SHOP_DB}: the fill's 9.000 transactions a call", " ".join(c.report.notes))

    def test_the_fills_transactions_per_call_over_its_last_hour(self):
        """Read where the fill's mix of keys is the tail's: its last hour
        (the night ran 45 a call, the day 9); the whole fill when the last
        hour holds no call."""
        metrics = night_metrics(day=90)
        self.assertAlmostEqual(history.fill_per_call(metrics, SHOP_DB), 9.0)
        # the fill ending with the night: its last hour is the night's
        to_night = {"producer": [r for r in metrics["producer"] if r["t"] <= NIGHT[1]]}
        self.assertAlmostEqual(history.fill_per_call(to_night, SHOP_DB), 45.0)
        # no call in the last hour: the whole fill
        recs = metrics["producer"]
        frozen = [r for r in recs if r["t"] <= R - 3600][-1]["scheduler_calls_total"]
        for r in recs:
            if r["t"] > R - 3600:
                r["scheduler_calls_total"] = dict(frozen)
        whole = recs[-1][history.FILL_TRANSACTIONS][SHOP_DB] / frozen["orders.detail"]
        self.assertAlmostEqual(history.fill_per_call(metrics, SHOP_DB), whole)
        self.assertGreater(whole, 10.0)
        self.assertIsNone(history.fill_per_call({}, SHOP_DB))

    def test_a_signatures_commits_per_call_from_its_planting(self):
        """A counter_per_call on the commits (pg-join-index-missing: each
        scan's parallel workers commit at their start-up): its share of the
        tail's rate is taken out before the shape scales the rest, then
        added from its planting; the tail's 12 a call by day after it, 8
        before (4 a call of orders.detail, the tail's only key)."""
        sig = (entry("counter_per_call", key="orders.detail", per_call=4,
                     series='pg_stat_database_xact_commit{datname="shop"}'),)
        _, out = self.compose(night_metrics(day=80), selection=[("f8", "dropped", PLANT, sig)])
        commits = out[key("pg_stat_database_xact_commit", **PG, datname="shop")]
        before = increase(commits, VT0 + 600) / 40
        after = increase(commits, PLANT + 1200) / 40
        self.assertAlmostEqual(before / 10, 8.0, delta=0.3)
        self.assertAlmostEqual(after / 10, 12.0, delta=0.4)

    def test_without_the_record_the_database_keeps_its_driver(self):
        """A fill from an earlier image: no `fill_transactions`; the shop's
        counters follow the load ((a)'s driver)."""
        c, out = self.compose(night_metrics(transactions=False))
        commits = out[key("pg_stat_database_xact_commit", **PG, datname="shop")]
        self.assertAlmostEqual(night_over_day(commits), 0.1, delta=0.02)
        self.assertEqual(c.report.drivers["transactions"], 0)
        # nor without the exporter's data source
        _, out = self.compose(night_metrics(), drivers=history.Drivers(DRIVERS.roles,
                                                                       DRIVERS.databases, {}))
        commits = out[key("pg_stat_database_xact_commit", **PG, datname="shop")]
        self.assertAlmostEqual(night_over_day(commits), 0.1, delta=0.02)

    def test_the_record_is_never_a_series(self):
        _, out = self.compose(night_metrics())
        self.assertFalse([k for k in out if "transactions" in k or "db:5432" in k])

    def test_without_drivers_every_series_follows_the_load(self):
        _, out = self.compose(night_metrics(), drivers=None)
        mon = out[key("pg_stat_statements_calls_total", **PG, user="monitoring", datname="shop",
                      queryid="1")]
        self.assertAlmostEqual(night_over_day(mon), 0.1, delta=0.02)


class TestFillDrivers(ScenarioCopyTest):
    """The drivers' sources on fixture-fill, fitted and rendered: the
    scheduler nodes' rendered schedules and the exporter's data source."""

    def test_roles_databases_and_the_exporters_target(self):
        import shutil as _shutil
        from tools.gm import fit, model, render
        scenario = self.tmp / "fixture-fill"
        _shutil.copytree(FIXTURES / "fixture-fill", scenario)
        fit.fit(scenario, "laptop", **SUFFICIENT)
        handover = _dt.datetime.now(_dt.timezone.utc).replace(minute=0, second=0, microsecond=0) \
            + _dt.timedelta(hours=5)
        render.render(scenario, "laptop", handover=handover.strftime("%Y-%m-%dT%H:%MZ"))
        from tools.gm import localimpl
        impl = localimpl.read_implementation(localimpl.local_dir(scenario, "laptop"))
        drivers = history.fill_drivers(model.load_scenario(scenario), impl, "laptop")
        self.assertEqual(drivers, history.Drivers(frozenset({"shop_app", "shop_reports"}),
                                                  frozenset({"shop"}), {"exporter:9187": "db:5432"}))


class TestSuppressedBy(unittest.TestCase):

    def test_hidden_from_the_hiding_planting(self):
        hidden = entry("remove", suppressed_by=["hider"],
                       series='pg_stat_user_tables_n_live_tup{relname="old"}')
        hide_at = PLANT + 1800
        c, out = compose([("f4", "hidden", PLANT, (hidden,)),
                          ("f9", "hider", hide_at, (entry("none"),))])
        self.assertEqual(c.overlays[0].end, hide_at)
        pts = out[key("pg_stat_user_tables_n_live_tup", **PG, relname="old")][1]
        self.assertFalse([t for t, _ in pts if PLANT <= t < hide_at])
        self.assertTrue([t for t, _ in pts if t >= hide_at])

    def test_a_hider_planted_in_the_tail_hides_nothing(self):
        hidden = entry("remove", suppressed_by=["hider"],
                       series='pg_stat_user_tables_n_live_tup{relname="old"}')
        c, out = compose([("f4", "hidden", PLANT, (hidden,)),
                          ("f5", "hider", R + 3600, (entry("none"),))])
        self.assertEqual(c.overlays[0].end, R)
        pts = out[key("pg_stat_user_tables_n_live_tup", **PG, relname="old")][1]
        self.assertFalse([t for t, _ in pts if t >= PLANT])


def past_of(out):
    """What read_seam reads from Prometheus, from the composer's output."""
    past = {}
    for k, (lb, points) in out.items():
        vals = [v for _, v in points]
        resets = sum(1 for a, b in zip(vals, vals[1:]) if b < a)
        past[k] = {"labels": lb, "min": min(vals), "last": vals[-1], "resets": resets}
    return past


def first_of(t):
    """What read_seam reads of the tail: the first value, the largest step."""
    out = {}
    for s in t["series"]:
        vals = [v for _, v in s["samples"]]
        step = max((abs(b - a) for a, b in zip(vals, vals[1:])), default=0.0)
        out[history.series_key(s["labels"])] = (s["labels"], vals[0], step)
    return out


class TestSeam(unittest.TestCase):

    def test_composed_history_passes(self):
        _, out = compose([("f8", "fixture-dropped-index", PLANT, SIGNATURE)])
        self.assertEqual(history.seam_findings(past_of(out), first_of(tail()), META), [])

    def test_negative(self):
        _, out = compose([])
        past = past_of(out)
        k = key("pg_stat_user_tables_n_dead_tup", **PG, relname="orders")
        past[k]["min"] = -3
        found = history.seam_findings(past, first_of(tail()), META)
        self.assertEqual([(f["check"], f["series"]) for f in found], [("negative", k)])
        first = first_of(tail())
        first[k] = (first[k][0], -1.0)
        found = history.seam_findings(past_of(out), first, META)
        self.assertEqual([f["check"] for f in found], ["negative"])
        self.assertIn("at the join", found[0]["detail"])

    def test_stray_reset(self):
        _, out = compose([])
        past = past_of(out)
        k = key("pg_stat_database_xact_commit", **PG, datname="shop")
        past[k]["last"] = 2_000_000          # the database's counter going down at the join
        found = history.seam_findings(past, first_of(tail()), META)
        self.assertEqual([(f["check"], f["series"]) for f in found], [("reset", k)])
        past = past_of(out)
        past[k]["resets"] = 1                # a reset inside the forged past
        found = history.seam_findings(past, first_of(tail()), META)
        self.assertEqual([f["check"] for f in found], ["reset"])
        # the restart's own reset is no finding
        own = key("prometheus_http_requests_total", job="prometheus", instance="localhost:9090",
                  code="200")
        past = past_of(out)
        self.assertGreater(past[own]["last"], first_of(tail())[own][1])
        self.assertEqual(history.seam_findings(past, first_of(tail()), META), [])

    def test_gauge_jump(self):
        _, out = compose([])
        past = past_of(out)
        k = key("pg_database_size_bytes", **PG, datname="shop")
        past[k]["last"] = 70_000_000
        found = history.seam_findings(past, first_of(tail()), META)
        self.assertEqual([(f["check"], f["series"]) for f in found], [("jump", k)])

    def test_what_the_system_holds_below_zero_and_whole_block_steps(self):
        """A setting's -1 ("no limit") is no negative finding, a size one
        included, and a volume growing by whole blocks joins within the
        tail's own step (the fixture's run, 2026-11-19)."""
        t = tail()
        n = 40
        t["series"] += [
            tail_series({"__name__": "pg_roles_connection_limit", **PG, "rolname": "shop"},
                        [-1] * n),
            tail_series({"__name__": "pg_settings_max_slot_wal_keep_size_bytes", **PG},
                        [-1] * n),
            tail_series({"__name__": "node_health_volume_used_bytes", "job": "node-health",
                         "instance": "db:9110", "volume": "pgdata"},
                        [4096 * (1 + i // 8) for i in range(n)], phase=3.0)]
        c = history.Composer(VT0, R, t, metrics=metrics(),
                             scheduler_instances={"producer": "producer:9120"},
                             selection=[], shift=SHIFT, seed=7)
        out = {history.series_key(lb): (lb, points) for lb, points in c.compose()}
        size = out[key("pg_settings_max_slot_wal_keep_size_bytes", **PG)][1]
        self.assertEqual({v for _, v in size}, {-1})
        self.assertEqual(history.seam_findings(past_of(out), first_of(t), META), [])
        # a forged value below the setting's own -1 is still a finding
        past = past_of(out)
        k = key("pg_roles_connection_limit", **PG, rolname="shop")
        past[k]["min"] = -2
        found = history.seam_findings(past, first_of(t), META)
        self.assertEqual([(f["check"], f["series"]) for f in found], [("negative", k)])

    def test_empty(self):
        found = history.seam_findings({}, first_of(tail()), META)
        self.assertEqual([f["check"] for f in found], ["empty"])


if __name__ == "__main__":
    unittest.main()


# --- gmctl history: the verb, with a stand-in Prometheus and helper ------------------------

import datetime as _dt
import re as _re
import shutil
import subprocess
import tempfile
from pathlib import Path
from unittest import mock

from tools.gm import aging, localimpl
from tools.gm.model import GmError

GID = "g1"
IMPL = {"game_id": GID, "nodes": {
    "prometheus": {"service": f"{GID}_prometheus", "image": "127.0.0.1:5000/dbagm/prometheus:x",
                   "brick": {"id": "prometheus"}},
    "producer": {"service": f"{GID}_producer", "image": "s", "brick": {"id": "scheduler"}}},
    "timeline": {"virtual_t0": history.iso(VT0), "anchor": history.iso(R), "tail": "1h",
                 "refused": [], "shift": SHIFT, "seed": 7}}


class MiniPrometheus:
    """The game's Prometheus, in memory: the tail, plus whatever the helper
    container imported (parsed from the OpenMetrics it was fed)."""

    def __init__(self):
        self.series = {history.series_key(s["labels"]): (s["labels"], [tuple(x) for x in s["samples"]])
                       for s in tail()["series"]}
        self.loaded = True
        self.queries = []

    def load(self, text):
        for line in text.splitlines():
            if line.startswith("#"):
                continue
            head, v, t = line.rsplit(" ", 2)
            name, body = head[:-1].split("{", 1)
            lb = dict(_re.findall(r'([a-zA-Z_]\w*)="((?:[^"\\]|\\.)*)"', body), __name__=name)
            k = history.series_key(lb)
            self.series.setdefault(k, (lb, []))[1].append((float(t), float(v)))
        for k, (lb, pts) in self.series.items():
            pts.sort()

    def get(self, path, **params):
        return META

    def query(self, expr, at):
        self.queries.append(expr)
        if expr.startswith("count("):
            past = any(t < R for _, pts in self.series.values() for t, _ in pts)
            return [{"value": [at, "1"]}] if past and self.loaded else []
        if expr.startswith("prometheus_tsdb"):
            return [{"value": [at, "1"]}]
        m = _re.match(r"^(\w+)\(label_replace\(.*\)\[(\d+)s:\d+s\]\)$", expr)
        if m:
            fn, w = m.group(1), int(m.group(2))
            out = []
            for lb, pts in self.series.values():
                vals = [v for t, v in pts if at - w < t <= at]
                if not vals:
                    continue
                v = {"last_over_time": vals[-1], "min_over_time": min(vals),
                     "resets": sum(1 for a, b in zip(vals, vals[1:]) if b < a)}[fn]
                metric = {k: x for k, x in lb.items() if k != "__name__"}
                metric[history.NAME_LABEL] = lb["__name__"]
                out.append({"metric": metric, "value": [at, str(v)]})
            return out
        m = _re.match(r"^\{__name__=~\"\.\+\"\}\[(\d+)s\]$", expr)
        assert m, expr
        w = int(m.group(1))
        return [{"metric": lb, "values": [[t, str(v)] for t, v in pts if at - w < t <= at]}
                for lb, pts in self.series.values() if any(at - w < t <= at for t, _ in pts)]


class HelperDocker:
    """The helper containers: the import fed its OpenMetrics on stdin."""

    def __init__(self, prom, fail=False):
        self.prom, self.fail, self.runs = prom, fail, []

    def on_host(self, host):
        return self

    def run(self, args, input=None, stdin=None, check=True, **kw):
        self.runs.append(args)
        if "-c" in args:
            if self.fail:
                return subprocess.CompletedProcess(args, 1, "", "promtool: out of order sample")
            self.prom.load(stdin.read().decode())
            return subprocess.CompletedProcess(
                args, 0, "peak 120000000\nblock 01JD0000000000000000000000 4096\n", "")
        return subprocess.CompletedProcess(args, 0, "removed 01JD0000000000000000000000\n", "")


class TestVerb(unittest.TestCase):

    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.scenario = self.root / "scenario"
        self.ldir = localimpl.local_dir(self.scenario, "laptop")
        localimpl.new_state(self.ldir, GID, "load-started")
        localimpl.write_implementation(self.ldir, IMPL)
        localimpl.write_restart_record(self.ldir, {
            "mode": "fake", "virtual_t0": history.iso(VT0), "anchor": history.iso(R),
            "tail": "1h", "handover_planned": history.iso(R + 3600), "refused": [],
            "restart": {"at": history.iso(R), "story_line": "x", "explains": []}})
        fdir = self.ldir / "fill"
        fdir.mkdir(parents=True)
        (fdir / "producer.metrics.jsonl").write_text(
            "\n".join(json.dumps({k: v for k, v in r.items() if k != "t"})
                      for r in metrics()["producer"]) + "\n")
        self.prom = MiniPrometheus()
        patches = [mock.patch.object(history, "Prometheus", lambda *a: self.prom),
                   mock.patch.object(history, "selection",
                                     lambda *a: [("f8", "fixture-dropped-index", PLANT,
                                                  SIGNATURE)]),
                   mock.patch("tools.gm.model.load_scenario", lambda d: None),
                   mock.patch.object(history, "fill_drivers", lambda *a: DRIVERS),
                   mock.patch.dict("os.environ", {}, clear=False)]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        import os
        os.environ.pop(aging.GAME_ENV, None)

    def run_history(self, docker, **kw):
        now = _dt.datetime.fromtimestamp(R + 720, _dt.timezone.utc)
        ticks = [0.0]

        def sleep(s):
            ticks[0] += s
        return history.run(self.scenario, "laptop", docker=docker, now=now, sleep=sleep,
                           clock=lambda: ticks[0], **kw)

    def test_import_recorded_and_seam_ok(self):
        result = self.run_history(HelperDocker(self.prom))
        self.assertEqual(result.exit_code, 0, result.text())
        rec = localimpl.read_restart_record(self.ldir)
        self.assertEqual(list(rec)[-1], "history")              # written last
        self.assertEqual(rec["history"]["result"], "ok")
        self.assertEqual(rec["history"]["seam"], "ok")
        self.assertNotIn("reason", rec["history"])
        attempt = localimpl.read_state(self.ldir)["history_import"]["attempts"][-1]
        self.assertEqual(attempt["outcome"], "ok")
        self.assertEqual(attempt["seam"], [])
        self.assertEqual(attempt["figures"]["blocks"], {"01JD0000000000000000000000": 4096})
        self.assertEqual(attempt["figures"]["tsdb"]["prometheus_tsdb_blocks_loaded"], 1.0)
        self.assertNotIn("stale", attempt["figures"]["tsdb"])
        self.assertFalse((self.ldir / history.HISTORY_DIR).exists())    # removed after success
        self.assertRegex(result.text().splitlines()[-1],
                         r"^Game g1: history from the virtual T0 \S+ to the restart \S+ "
                         r"imported at \S+; seam ok \(0 findings\)$")
        # once ok: printed again, nothing done, nothing run
        docker = HelperDocker(self.prom)
        again = self.run_history(docker)
        self.assertTrue(again.noop)
        self.assertEqual(again.exit_code, 0)
        self.assertEqual(docker.runs, [])
        self.assertEqual(len(localimpl.read_state(self.ldir)["history_import"]["attempts"]), 1)
        # --check-seam: the verdict alone, nothing recorded
        before = (self.ldir / localimpl.RESTART_RECORD_FILE).read_bytes()
        checked = self.run_history(HelperDocker(self.prom), check_seam=True)
        self.assertEqual((checked.exit_code, checked.findings), (0, []))
        self.assertEqual((self.ldir / localimpl.RESTART_RECORD_FILE).read_bytes(), before)

    def test_a_second_run_waits_for_the_first_then_finds_its_result(self):
        import threading
        lock = history.run_lock(self.ldir)
        lock.__enter__()                       # a run importing (the GM's by hand)
        done, docker = {}, HelperDocker(self.prom)
        second = threading.Thread(target=lambda: done.update(r=self.run_history(docker)))
        second.start()                         # the timer's, meanwhile
        second.join(1.0)
        self.assertTrue(second.is_alive())     # waiting, nothing run
        self.assertEqual(docker.runs, [])
        self.assertIsNone(localimpl.read_state(self.ldir).get("history_import"))
        rec = localimpl.read_restart_record(self.ldir)   # the first finishes: ok recorded
        rec["history"] = {"at": history.iso(R + 780), "result": "ok", "seam": "ok"}
        localimpl.write_restart_record(self.ldir, rec)
        lock.__exit__(None, None, None)
        second.join(10)
        self.assertFalse(second.is_alive())
        self.assertTrue(done["r"].noop)
        self.assertEqual((done["r"].exit_code, docker.runs), (0, []))

    def test_tsdb_figures_wait_for_the_self_scrape(self):
        answers = iter(["0", "0", "0", "0", "0", "0", "1.7e9", "4", "5373353"])

        class Lagging:
            def query(self, expr, at):
                return [{"value": [at, next(answers)]}]
        ticks = [0.0]
        out = history.tsdb_figures(Lagging(), lambda: 0.0, lambda s: ticks.__setitem__(
            0, ticks[0] + s), lambda: ticks[0])
        self.assertEqual(out["prometheus_tsdb_blocks_loaded"], 4.0)
        self.assertEqual(ticks[0], 2 * history.LOAD_POLL)
        never = history.tsdb_figures(type("P", (), {"query": lambda s, e, a: [
            {"value": [a, "0"]}]})(), lambda: 0.0, lambda s: ticks.__setitem__(
            0, ticks[0] + s), lambda: ticks[0])
        self.assertTrue(never["stale"])

    def test_failed_import_recorded_then_retried(self):
        result = self.run_history(HelperDocker(self.prom, fail=True))
        self.assertEqual(result.exit_code, 1)
        rec = localimpl.read_restart_record(self.ldir)["history"]
        self.assertEqual((rec["result"], rec["seam"]), ("failed", "unchecked"))
        self.assertIn("out of order sample", rec["reason"])
        self.assertIn("(recorded; nothing torn down)", result.text())
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "load-started")
        self.assertTrue((self.ldir / history.HISTORY_DIR / history.OM_FILE).is_file())
        with self.assertRaisesRegex(GmError, "--check-seam reads one"):
            self.run_history(HelperDocker(self.prom), check_seam=True)
        docker = HelperDocker(self.prom)
        retry = self.run_history(docker)
        self.assertEqual(retry.exit_code, 0, retry.text())
        self.assertIn("-s", docker.runs[0])                       # the removal first
        self.assertIn(f"GM_RESTART_MS={int(R * 1000)}", docker.runs[0])
        attempts = localimpl.read_state(self.ldir)["history_import"]["attempts"]
        self.assertEqual([a["outcome"] for a in attempts], ["failed", "ok"])

    def test_not_loaded_in_time_fails(self):
        self.prom.loaded = False
        result = self.run_history(HelperDocker(self.prom))
        rec = localimpl.read_restart_record(self.ldir)["history"]
        self.assertEqual((rec["result"], rec["seam"]), ("failed", "unchecked"))
        self.assertIn("never restarted", rec["reason"])
        self.assertEqual(result.exit_code, 1)

    def test_a_bad_seam_fails_the_command(self):
        lb = {"__name__": "pg_stat_user_tables_n_dead_tup", **PG, "relname": "orders"}
        self.prom.series[history.series_key(lb)][1].append((R - 30, -5.0))
        result = self.run_history(HelperDocker(self.prom))
        rec = localimpl.read_restart_record(self.ldir)["history"]
        self.assertEqual((rec["result"], rec["seam"]), ("ok", "failed"))
        self.assertIn("seam negative", rec["reason"])
        self.assertEqual(result.exit_code, 1)
        self.assertIn("  seam negative: ", result.text())

    def test_refusals(self):
        st = {"game_id": GID, "stage": "load-started"}
        record = localimpl.read_restart_record(self.ldir)
        at = _dt.datetime.fromtimestamp(R + 720, _dt.timezone.utc)
        self.assertIsNone(history.refusal(st, IMPL, record, at))
        self.assertIn("not a fake game", history.refusal(st, IMPL, None, at))
        self.assertIn("not a fake game", history.refusal(st, IMPL, {"mode": "real"}, at))
        no_prom = dict(IMPL, nodes={"producer": IMPL["nodes"]["producer"]})
        self.assertIn("no prometheus node", history.refusal(st, no_prom, record, at))
        self.assertIn("follows the restart and start-load",
                      history.refusal(dict(st, stage="injected"), IMPL, record, at))
        self.assertIn("follows the restart",
                      history.refusal(st, IMPL, dict(record, restart=None), at))
        early = _dt.datetime.fromtimestamp(R + 599, _dt.timezone.utc)
        self.assertIn("first 10 minutes", history.refusal(st, IMPL, record, early))
        self.assertIn("never while the players read Prometheus",
                      history.refusal(dict(st, stage="handed-over"), IMPL, record, at))
        # nothing written by a refusal
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, "first 10 minutes.*nothing done"):
            history.run(self.scenario, "laptop", docker=HelperDocker(self.prom),
                        now=early)
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)
