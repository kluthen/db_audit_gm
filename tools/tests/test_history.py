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
    return {history.series_key(s["labels"]): (s["labels"], s["samples"][0][1])
            for s in t["series"]}


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

    def test_empty(self):
        found = history.seam_findings({}, first_of(tail()), META)
        self.assertEqual([f["check"] for f in found], ["empty"])


if __name__ == "__main__":
    unittest.main()
