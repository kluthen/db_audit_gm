"""Unit tests of the scheduler program's parts that need no database:
forms, generators, seeded draws, arrivals, shapes, timeline, cron, the log
and the summaries. Run in the image by tests/run-unit-tests.sh.

No clock is faked anywhere (v0.3 build plan, "No fake time"): functions
that depend on time take the instant as an argument.
"""

import datetime
import decimal
import os
import random
import tempfile
import unittest

from gm_scheduler import ConfigError
from gm_scheduler import generators as gen
from gm_scheduler import repository as repo
from gm_scheduler.cron import Cron
from gm_scheduler.jobs import parse_jobs
from gm_scheduler.metrics import Stats, percentile
from gm_scheduler.rng import derive
from gm_scheduler.schedule import apply_past_changes, parse_input, parse_schedule, read_schedule
from gm_scheduler.streams import next_arrival, rate_function, shape_multiplier
from gm_scheduler.textlog import completed_runs, format_line, last_reload, parse_line, script_line
from gm_scheduler.timeutil import instant, minute_label, parse_duration, parse_instant, parse_rate

UTC = datetime.timezone.utc


def ts(text):
    return parse_instant(text, "test")


class Ctx:
    def __init__(self, sequences=None, now=0.0):
        self.sequences = sequences or gen.Sequences()
        self._now = now

    def now(self):
        return self._now


def flat_shape(value=1.0):
    return {"utc": {d: [value] * 24 for d in ("mon", "tue", "wed", "thu", "fri", "sat", "sun")}}


def schedule_doc(**over):
    doc = {
        "seed": 4815162342,
        "intensity": 1.0,
        "connections": {"app": {"driver": "sql/postgresql", "target": "db:5432/shop", "role": "shop_app",
                                "pool": {"size": 2}}},
        "streams": [{"key": "orders.insert", "connection": "app", "rate": "40/min", "arrivals": "poisson",
                     "shape": "business-hours", "concurrency": 2}],
        "shapes": {"business-hours": flat_shape()},
        "timeline": [{"at": "2026-10-24T08:00:00Z", "stream": "orders.insert",
                      "set": {"key": "orders.insert-v2"}}],
    }
    doc.update(over)
    return doc


class TestTimeForms(unittest.TestCase):
    def test_durations(self):
        self.assertEqual(parse_duration("30s", "x"), 30)
        self.assertEqual(parse_duration("16h", "x"), 57600)
        self.assertEqual(parse_duration("2d", "x"), 172800)
        self.assertEqual(parse_duration("0m", "x"), 0)
        for bad in ("30", "1.5h", "h", "-1m", 30, None):
            with self.assertRaises(ConfigError):
                parse_duration(bad, "x")

    def test_rates(self):
        self.assertAlmostEqual(parse_rate("40/min", "x"), 40 / 60)
        self.assertAlmostEqual(parse_rate("2/h", "x"), 2 / 3600)
        self.assertAlmostEqual(parse_rate("0.5/s", "x"), 0.5)
        for bad in ("40", "40/m", "/min", "-1/min", 40):
            with self.assertRaises(ConfigError):
                parse_rate(bad, "x")

    def test_instants(self):
        t = ts("2026-10-24T08:00:00Z")
        self.assertEqual(instant(t), "2026-10-24T08:00:00Z")
        self.assertEqual(minute_label(t + 59), "2026-10-24T08:00Z")
        for bad in ("2026-10-24 08:00:00Z", "2026-10-24T08:00:00", "2026-13-01T00:00:00Z"):
            with self.assertRaises(ConfigError):
                parse_instant(bad, "x")


class TestLogLines(unittest.TestCase):
    def test_line_format(self):
        t = ts("2026-10-24T09:15:00Z")
        self.assertEqual(format_line(t, "summary", [("minute", "2026-10-24T09:14Z"), ("keys", 2), ("calls", 41),
                                                    ("errors", 1)]),
                         "2026-10-24T09:15:00Z summary minute=2026-10-24T09:14Z keys=2 calls=41 errors=1")

    def test_a_script_line_is_free_text(self):
        t = ts("2026-10-24T09:15:03Z")
        self.assertEqual(script_line(t, "rollup-hourly", "moved 120 rows\nwatermark=2026-10-24T09:00:00Z"),
                         "2026-10-24T09:15:03Z script job=rollup-hourly moved 120 rows watermark=2026-10-24T09:00:00Z")

    def test_lines_parse_back(self):
        t = ts("2026-10-24T09:15:03Z")
        line = format_line(t, "error", [("key", "k"), ("job", "j"), ("sqlstate", "42501"),
                                        ("message", 'permission denied for "src" \\ x')])
        self.assertEqual(parse_line(line), ("2026-10-24T09:15:03Z", "error",
                                            {"key": "k", "job": "j", "sqlstate": "42501",
                                             "message": 'permission denied for "src" \\ x'}, None))
        self.assertEqual(parse_line(script_line(t, "r", "run job=x phase=end status=ok")),
                         ("2026-10-24T09:15:03Z", "script", {"job": "r"}, "run job=x phase=end status=ok"))
        for bad in ("", "gm-scheduler: cannot write", "2026-10-24T09:15:03Z run job", "2026-10-24 run job=x"):
            self.assertIsNone(parse_line(bad), bad)

    def test_runs_since_a_moment_and_the_last_reload(self):
        log = """\
2026-10-24T09:00:00Z state state=running t0=2026-10-24T08:00:00Z
2026-10-24T09:05:00Z run job=rollup key=rollup.hourly phase=start
2026-10-24T09:05:02Z script job=rollup moved 3 rows
2026-10-24T09:05:02Z run job=rollup key=rollup.hourly phase=end status=ok rows=3 ms=2012.5
2026-10-24T09:20:00Z reload status=ok keys=4 jobs=2
2026-10-24T09:21:00Z reload status=refused message="jobs.yaml: does not parse"
2026-10-24T10:05:00Z run job=rollup key=rollup.hourly phase=start
2026-10-24T10:05:01Z run job=rollup key=rollup.hourly phase=end status=error error=ValueError ms=4.0
2026-10-24T10:06:00Z script job=rollup run job=rollup key=rollup.hourly phase=end status=ok rows=9 ms=1
2026-10-24T11:05:00Z run job=other key=rollup.hourly phase=start
2026-10-24T11:05:00Z run job=rollup key=rollup.hourly phase=start
2026-10-24T11:05:03Z run job=other key=rollup.hourly phase=end status=ok rows=1 ms=1.0
2026-10-24T11:05:04Z run job=rollup key=rollup.hourly phase=end status=ok rows=5 ms=4120.0
gm-scheduler: a line not of the grammar
"""
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "scheduler.log")
            with open(path, "w") as f:
                f.write(log)
            self.assertEqual(completed_runs(path, "rollup", "2026-10-24T08:00:00Z"),
                             [("2026-10-24T09:05:00Z", "2026-10-24T09:05:02Z", "3", "2012.5"),
                              ("2026-10-24T11:05:00Z", "2026-10-24T11:05:04Z", "5", "4120.0")])
            self.assertEqual(completed_runs(path, "rollup", "2026-10-24T09:05:02Z"),
                             [("2026-10-24T11:05:00Z", "2026-10-24T11:05:04Z", "5", "4120.0")])
            self.assertEqual(completed_runs(path, "rollup", "2026-10-24T11:05:04Z"), [])
            self.assertEqual(last_reload(path), "2026-10-24T09:20:00Z")
            with open(path, "w") as f:
                f.write(log.split("2026-10-24T09:20")[0])
            self.assertIsNone(last_reload(path))

    def test_quoted_value_is_last(self):
        t = ts("2026-10-24T09:15:00Z")
        line = format_line(t, "error", [("key", "orders.insert"), ("sqlstate", "42601"),
                                        ("message", 'syntax error at or near "FORM" \\ x')])
        self.assertEqual(line, '2026-10-24T09:15:00Z error key=orders.insert sqlstate=42601 '
                               'message="syntax error at or near \\"FORM\\" \\\\ x"')
        with self.assertRaises(ValueError):
            format_line(t, "error", [("message", "two words"), ("key", "k")])
        self.assertIn('message="a b"', format_line(t, "e", [("message", "a\nb")]))
        self.assertTrue(format_line(t, "e", [("v", None)]).endswith("v=-"))


class TestSeededDraws(unittest.TestCase):
    def draws(self, seed, host="producer", purpose="stream:0:orders.insert", started=1000):
        r = derive(seed, host, purpose, started)
        return [r.random() for _ in range(20)]

    def test_same_seed_same_draws_twice(self):
        self.assertEqual(self.draws(4815162342), self.draws(4815162342))

    def test_draws_differ_by_seed_host_task_and_start(self):
        base = self.draws(4815162342)
        self.assertNotEqual(base, self.draws(4815162343))
        self.assertNotEqual(base, self.draws(4815162342, host="consumer"))
        self.assertNotEqual(base, self.draws(4815162342, purpose="stream:1:orders.insert"))
        self.assertNotEqual(base, self.draws(4815162342, started=1001))

    def test_a_seeded_plan_gives_the_same_calls_twice(self):
        doc = {"queries": {"catalog.lookup": [
            {"sql": "SELECT %(id)s", "params": {"id": {"int": [1, 20000]}}, "weight": 8},
            {"sql": "SELECT %(p)s", "params": {"p": {"choice": ["%lamp%", "%desk%"]}}, "weight": 2}]}}
        r = repo.parse_queries(doc, {})

        def run():
            rng = derive(7, "producer", "stream:0:catalog.lookup", 0)
            ctx = Ctx()
            return [r.get("catalog.lookup").plan(rng, ctx, 1.0).steps for _ in range(50)]
        self.assertEqual(run(), run())


class TestGenerators(unittest.TestCase):
    def test_int_decimal_choice_const(self):
        rng, ctx = random.Random(1), Ctx()
        ints = [gen.compile_param({"int": [1, 3]}, "p", "k.p").draw(rng, ctx) for _ in range(200)]
        self.assertEqual(set(ints), {1, 2, 3})
        g = gen.compile_param({"decimal": [5, 500, 2]}, "p", "k.p")
        for _ in range(200):
            v = g.draw(rng, ctx)
            self.assertIsInstance(v, decimal.Decimal)
            self.assertEqual(v.as_tuple().exponent, -2)
            self.assertTrue(decimal.Decimal(5) <= v <= decimal.Decimal(500))
        c = gen.compile_param({"choice": ["a", "b"]}, "p", "k.p")
        self.assertEqual({c.draw(rng, ctx) for _ in range(100)}, {"a", "b"})
        self.assertEqual(gen.compile_param(42, "p", "k.p").draw(rng, ctx), 42)

    def test_now_is_the_current_utc_time(self):
        g = gen.compile_param({"now": "utc"}, "p", "k.p")
        v = g.draw(random.Random(1), Ctx(now=ts("2026-10-24T08:00:00Z")))
        self.assertEqual(v, datetime.datetime(2026, 10, 24, 8, 0, tzinfo=UTC))

    def test_invalid_generators(self):
        for bad in ({"int": [3, 1]}, {"int": [1.5, 2]}, {"decimal": [1, 2]}, {"choice": []},
                    {"sequence": [1, 0]}, {"now": "local"}, {"uuid": True}, {"int": [1, 2], "choice": [1]},
                    [1, 2]):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                gen.compile_param(bad, "p", "k.p")

    def test_sequence_never_reuses_a_value_across_a_restart(self):
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "sequences.json")
            g = gen.compile_param({"sequence": [100, 5]}, "p", "orders.insert.order_no")
            first = gen.Sequences(path, block=10)
            a = [g.draw(None, Ctx(first)) for _ in range(3)]
            self.assertEqual(a, [100, 105, 110])
            resumed = gen.Sequences(path, block=10)       # the program restarted
            b = [g.draw(None, Ctx(resumed)) for _ in range(12)]
            self.assertEqual(b[0], 100 + 5 * 10)           # the next block
            self.assertFalse(set(a) & set(b))
            self.assertEqual(len(set(b)), 12)


class TestRepository(unittest.TestCase):
    def write_repo(self, d, queries, builders=None):
        with open(os.path.join(d, "queries.yaml"), "w") as f:
            f.write(queries)
        if builders:
            os.mkdir(os.path.join(d, "builders"))
            for name, text in builders.items():
                with open(os.path.join(d, "builders", name), "w") as f:
                    f.write(text)

    def test_the_four_kinds(self):
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, """
queries:
  orders.insert:
    sql: >-
      INSERT INTO orders (customer_id, amount) VALUES (%(customer_id)s, %(amount)s)
    params:
      customer_id: {int: [1, 5000]}
      amount: {decimal: [5, 500, 2]}
  catalog.lookup:
    - sql: SELECT * FROM products WHERE id = %(id)s
      params: {id: {int: [1, 20000]}}
      weight: 8
    - sql: SELECT * FROM products WHERE name ILIKE %(pattern)s
      params: {pattern: {choice: ['%lamp%', '%desk%']}}
      weight: 2
  invoices.close-day:
    transaction: {isolation: read committed, hold: 2s}
    steps:
      - sql: UPDATE invoices SET closed = true
      - sql: INSERT INTO ledger SELECT 1
  reports.revenue:
    builder: builders/revenue.py:build
    options: {months: 3}
""", {"revenue.py": """
def build(intensity, options, rng=None):
    n = max(1, int(intensity * 10))
    return ([("SELECT %(m)s", {"m": options["months"]})] * n, True)
""", "revenue.py~": "not python"})
            r = repo.load_repository(d)
            self.assertEqual(r.keys(), ["catalog.lookup", "invoices.close-day", "orders.insert", "reports.revenue"])
            self.assertEqual([r.get(k).kind for k in r.keys()], ["pool", "sequence", "query", "builder"])
            rng, ctx = random.Random(3), Ctx()
            p = r.get("orders.insert").plan(rng, ctx, 1.0)
            self.assertIsNone(p.txn)
            self.assertEqual(set(p.steps[0][1]), {"customer_id", "amount"})
            p = r.get("invoices.close-day").plan(rng, ctx, 1.0)
            self.assertEqual(p.txn, repo.Txn("read committed", 2))
            self.assertEqual(len(p.steps), 2)
            p = r.get("reports.revenue").plan(rng, ctx, 2.0)
            self.assertEqual(len(p.steps), 20)
            self.assertEqual(p.steps[0], ("SELECT %(m)s", {"m": 3}))
            self.assertEqual(p.txn, repo.Txn("read committed", 0))

    def test_the_script_form(self):
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, """
queries:
  rollup.hourly:
    script: scripts/rollup.py:hourly
    options: {batch: 5000}
  rollup.bare:
    script: scripts/rollup.py:hourly
  q: {sql: SELECT 1}
""", {})
            os.mkdir(os.path.join(d, "scripts"))
            marker = os.path.join(d, "other-imported")
            for name, text in {"rollup.py": "def hourly(conns, options, log):\n    return 0\n",
                               "other.py": f"open({marker!r}, 'w').close()\n",
                               "rollup.py~": "not python"}.items():
                with open(os.path.join(d, "scripts", name), "w") as f:
                    f.write(text)
            r = repo.load_repository(d)
            self.assertEqual([r.get(k).kind for k in r.keys()], ["query", "script", "script"])
            e = r.get("rollup.hourly")
            self.assertEqual((e.spec, e.options, e.fn.__name__), ("scripts/rollup.py:hourly", {"batch": 5000}, "hourly"))
            self.assertEqual(r.get("rollup.bare").options, {})
            self.assertFalse(os.path.exists(marker), "only the scripts queries.yaml names are imported")
            self.assertEqual(repo.queries_outline(d), ({"rollup.hourly", "rollup.bare", "q"},
                                                       {"rollup.hourly", "rollup.bare"}, set()))
            files = [os.path.relpath(f, d) for f in repo.loaded_files(d, os.path.join(d, "jobs.yaml"))]
            self.assertEqual(files, ["queries.yaml", "scripts/other.py", "scripts/rollup.py", "jobs.yaml"])
        for bad, why in (({"script": "builders/rollup.py:hourly"}, "scripts/<file>:<function>"),
                         ({"script": "scripts/missing.py:hourly"}, "no file scripts/missing.py"),
                         ({"script": "scripts/rollup.py:nope"}, "has no function nope"),
                         ({"script": "scripts/rollup.py:hourly", "options": [1]}, "options: a map"),
                         ({"script": "scripts/rollup.py:hourly", "connection": "app"}, "unknown key")):
            module = type(os)("m")
            module.hourly = lambda conns, options, log: 0
            with self.assertRaisesRegex(ConfigError, why, msg=repr(bad)):
                repo.parse_queries({"queries": {"k": bad}}, {}, {"rollup.py": module})
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, "queries:\n  r:\n    script: scripts/s.py:run\n")
            os.mkdir(os.path.join(d, "scripts"))
            with open(os.path.join(d, "scripts", "s.py"), "w") as f:
                f.write("raise RuntimeError('x')\n")
            with self.assertRaisesRegex(ConfigError, "scripts/s.py: fails at import"):
                repo.load_repository(d)

    def test_pool_picks_by_weight(self):
        r = repo.parse_queries({"queries": {"k": [{"sql": "A", "weight": 8}, {"sql": "B", "weight": 2}]}}, {})
        rng, ctx = random.Random(11), Ctx()
        picks = [r.get("k").plan(rng, ctx, 1.0).steps[0][0] for _ in range(5000)]
        self.assertAlmostEqual(picks.count("A") / 5000, 0.8, delta=0.03)
        even = repo.parse_queries({"queries": {"k": [{"sql": "A"}, {"sql": "B"}]}}, {})
        picks = [even.get("k").plan(rng, ctx, 1.0).steps[0][0] for _ in range(5000)]
        self.assertAlmostEqual(picks.count("A") / 5000, 0.5, delta=0.03)

    def test_builder_return_forms(self):
        p = repo.builder_plan({"statements": [{"sql": "SELECT 1"}], "transaction": {"isolation": "serializable",
                                                                                   "hold": "1s"}})
        self.assertEqual(p.txn, repo.Txn("serializable", 1))
        self.assertIsNone(repo.builder_plan(([("SELECT 1", None)], False)).txn)
        for bad in ("SELECT 1", ([], False), ([("", None)], False), ([("SELECT 1", 5)], False),
                    ([("SELECT 1", None)], {"isolation": "dirty"})):
            with self.assertRaises(repo.BuilderResult, msg=repr(bad)):
                repo.builder_plan(bad)

    def test_invalid_repositories(self):
        cases = [
            {"queries": {}},
            {"other": {}},
            {"queries": {"Bad Key": {"sql": "SELECT 1"}}},
            {"queries": {"k": {"sql": ""}}},
            {"queries": {"k": {"sql": "SELECT 1", "transaction": {"isolation": "dirty read"}}}},
            {"queries": {"k": {"sql": "SELECT 1", "transaction": {"hold": "1s"}}}},
            {"queries": {"k": {"sql": "SELECT 1", "extra": 1}}},
            {"queries": {"k": [{"sql": "A", "weight": 0}]}},
            {"queries": {"k": []}},
            {"queries": {"k": {"steps": []}}},
            {"queries": {"k": {"builder": "builders/missing.py:build"}}},
            {"queries": {"k": {"builder": "other/x.py:build"}}},
            {"queries": {"k": 5}},
        ]
        for doc in cases:
            with self.assertRaises(ConfigError, msg=repr(doc)):
                repo.parse_queries(doc, {})

    def test_builder_failing_at_import_and_missing_function(self):
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, "queries:\n  r:\n    builder: builders/b.py:build\n", {"b.py": "raise RuntimeError('x')\n"})
            with self.assertRaisesRegex(ConfigError, "fails at import"):
                repo.load_repository(d)
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, "queries:\n  r:\n    builder: builders/b.py:build\n", {"b.py": "def other(): pass\n"})
            with self.assertRaisesRegex(ConfigError, "no function build"):
                repo.load_repository(d)
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, "queries:\n  r:\n    builder: builders/b.py:build\n", {"b.py": "def build(:\n"})
            with self.assertRaisesRegex(ConfigError, "line 1"):
                repo.load_repository(d)

    def test_a_symbolic_link_is_refused_and_yaml_errors_name_the_line(self):
        with tempfile.TemporaryDirectory() as d:
            with open(os.path.join(d, "real.yaml"), "w") as f:
                f.write("queries: {k: {sql: SELECT 1}}\n")
            os.symlink(os.path.join(d, "real.yaml"), os.path.join(d, "queries.yaml"))
            with self.assertRaisesRegex(ConfigError, "symbolic link"):
                repo.load_repository(d)
        with tempfile.TemporaryDirectory() as d:
            self.write_repo(d, "queries:\n  k: {sql: SELECT 1\n")
            with self.assertRaisesRegex(ConfigError, r"queries.yaml: does not parse \(line"):
                repo.load_repository(d)

    def test_keys_only_never_imports_a_builder(self):
        with tempfile.TemporaryDirectory() as d:
            marker = os.path.join(d, "imported")
            self.write_repo(d, "queries:\n  r:\n    builder: builders/b.py:build\n  q: {sql: SELECT 1}\n",
                            {"b.py": f"open({marker!r}, 'w').close()\ndef build(i, o): pass\n"})
            self.assertEqual(repo.queries_keys_only(d), {"r", "q"})
            self.assertFalse(os.path.exists(marker))
            repo.load_repository(d)
            self.assertTrue(os.path.exists(marker))


class TestCron(unittest.TestCase):
    def test_daily_in_utc(self):
        c = Cron("30 1 * * *")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T01:29:59Z"))), "2026-10-24T01:30:00Z")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T01:30:00Z"))), "2026-10-25T01:30:00Z")

    def test_steps_ranges_lists(self):
        c = Cron("*/15 8-10,14 * * *")
        t = ts("2026-10-24T10:50:00Z")
        self.assertEqual(instant(c.next_after(t)), "2026-10-24T14:00:00Z")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T08:00:00Z"))), "2026-10-24T08:15:00Z")

    def test_a_fixed_offset_zone(self):
        # Etc/GMT-3 is UTC+3: 01:30 there is 22:30 UTC the day before
        c = Cron("30 1 * * *", "Etc/GMT-3")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T12:00:00Z"))), "2026-10-24T22:30:00Z")
        c = Cron("0 23 * * *", "Etc/GMT+2")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T12:00:00Z"))), "2026-10-25T01:00:00Z")

    def test_day_of_week_and_the_either_day_rule(self):
        # 2026-10-24 is a Saturday
        c = Cron("0 9 * * 1")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T00:00:00Z"))), "2026-10-26T09:00:00Z")
        self.assertEqual(instant(Cron("0 9 * * 7").next_after(ts("2026-10-24T00:00:00Z"))), "2026-10-25T09:00:00Z")
        either = Cron("0 0 1 * 1")    # the 1st, or any Monday
        self.assertEqual(instant(either.next_after(ts("2026-10-24T00:00:00Z"))), "2026-10-26T00:00:00Z")
        self.assertEqual(instant(Cron("0 0 */2 * *").next_after(ts("2026-10-24T00:00:00Z"))), "2026-10-25T00:00:00Z")

    def test_the_widened_hour_subset(self):
        # v0.4 W1 item 0: hour *, or a list of n, a-b, */s, a-b/s (P3's mail campaign)
        c = Cron("*/15 8-20 * * *")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T20:45:00Z"))), "2026-10-25T08:00:00Z")
        self.assertEqual(instant(c.next_after(ts("2026-10-24T07:59:59Z"))), "2026-10-24T08:00:00Z")
        c = Cron("5 1,*/6,9-11/2 * * *")
        self.assertEqual(sorted(c.hours), [0, 1, 6, 9, 11, 12, 18])

    def test_never_and_invalid(self):
        self.assertIsNone(Cron("0 0 31 2 *").next_after(ts("2026-10-24T00:00:00Z")))
        for bad in ("* * * *", "60 * * * *", "0 24 * * *", "0 0 0 * *", "0 0 * 13 *", "0 0 * * 8",
                    "0 0 * * mon", "@daily", "5-1 * * * *", 5):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                Cron(bad)
        with self.assertRaises(ConfigError):
            Cron("0 0 * * *", "Mars/Olympus")


class TestLoaded(unittest.TestCase):
    def test_the_loaded_file_keeps_each_jobs_time(self):
        from gm_scheduler.runner import read_loaded
        with tempfile.TemporaryDirectory() as d:
            path = os.path.join(d, "loaded")
            with open(path, "w") as f:
                f.write("generation=3\nloaded=2026-10-24T09:20:00Z\n"
                        f"file {'a' * 64} /srv/scheduler/repository/scripts/rollup.py\n"
                        "file missing /srv/scheduler/repository/queries.yaml\n"
                        "job rollup next=2026-10-24T10:05:00Z\njob close next=never\n"
                        "cron rollup UTC 5 * * * *\ncron close Etc/GMT-3 30 1 * * *\n")
            out = read_loaded(path)
        self.assertEqual((out["generation"], out["loaded"]), ("3", "2026-10-24T09:20:00Z"))
        self.assertEqual(out["files"], {"/srv/scheduler/repository/scripts/rollup.py": "a" * 64,
                                        "/srv/scheduler/repository/queries.yaml": "missing"})
        self.assertEqual(out["next"], {"rollup": "2026-10-24T10:05:00Z", "close": "never"})
        self.assertEqual(instant(out["cron"]["rollup"].next_after(ts("2026-10-24T10:05:00Z"))), "2026-10-24T11:05:00Z")
        self.assertEqual(instant(out["cron"]["close"].next_after(ts("2026-10-24T12:00:00Z"))), "2026-10-24T22:30:00Z")


class TestJobs(unittest.TestCase):
    def test_parse(self):
        jobs = parse_jobs({"jobs": [{"name": "close-day", "key": "invoices.close-day", "connection": "app",
                                     "at": "30 1 * * *"},
                                    {"name": "tz", "key": "k", "connection": "app", "at": "0 2 * * *",
                                     "timezone": "Etc/GMT-5"}]})
        self.assertEqual([j.name for j in jobs], ["close-day", "tz"])
        self.assertEqual(jobs[1].cron.zone_name, "Etc/GMT-5")
        self.assertEqual(parse_jobs({"jobs": []}), [])

    def test_a_script_jobs_connections(self):
        job = parse_jobs({"jobs": [{"name": "rollup-hourly", "key": "rollup.hourly", "at": "5 * * * *",
                                    "connections": {"source": "shop", "target": "reporting"}}]})[0]
        self.assertEqual((job.connection, job.connections), (None, {"source": "shop", "target": "reporting"}))
        base = {"name": "a", "key": "k", "at": "0 1 * * *"}
        for bad, why in ((dict(base, connection="app", connections={"source": "app"}), "not both"),
                         (dict(base, connections={}), "at least one"),
                         (dict(base, connections=["app"]), "at least one"),
                         (dict(base, connections={"Source": "app"}), "name 'Source'"),
                         (dict(base, connections={"1st": "app"}), "name '1st'"),
                         (dict(base, connections={"source": ""}), "connections.source: a connection name"),
                         (base, "connection: a connection name")):
            with self.assertRaisesRegex(ConfigError, why, msg=repr(bad)):
                parse_jobs({"jobs": [bad]})

    def test_invalid(self):
        ok = {"name": "a", "key": "k", "connection": "app", "at": "0 1 * * *"}
        for bad in ({"jobs": [dict(ok, at="0 25 * * *")]}, {"jobs": [ok, ok]}, {"jobs": [dict(ok, extra=1)]},
                    {"jobs": [dict(ok, key="Bad Key")]}, {"jobs": [dict(ok, timezone="Nowhere/Here")]},
                    {"jobs": {}}, {"other": []}):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                parse_jobs(bad)


class TestSchedule(unittest.TestCase):
    def test_input_framing(self):
        passwords, credentials, text = parse_input("gm-scheduler-input 1\npassword shop_app s3cr3t\n"
                                                   "credential interfaces_lab_api t0k3n\nschedule\nseed: 1\n")
        self.assertEqual(passwords, {"shop_app": "s3cr3t"})
        self.assertEqual(credentials, {"interfaces_lab_api": "t0k3n"})
        self.assertEqual(text, "seed: 1\n")
        for bad in ("", "seed: 1", "gm-scheduler-input 1\npassword x\nschedule\n", "gm-scheduler-input 1\n",
                    "gm-scheduler-input 1\ncredential Lab x\nschedule\n",
                    "gm-scheduler-input 1\ncredential lab\nschedule\n"):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                parse_input(bad)

    def test_valid_schedule(self):
        s = parse_schedule(schedule_doc(), {"shop_app": "pw"})
        self.assertEqual(s.seed, 4815162342)
        self.assertEqual(s.connections["app"].pool_size, 2)
        self.assertEqual(s.keys(), {"orders.insert", "orders.insert-v2"})
        st = s.streams[0]
        self.assertAlmostEqual(st.rate, 40 / 60)
        self.assertEqual((st.arrivals, st.shape, st.concurrency), ("poisson", "business-hours", 2))
        per_call = schedule_doc()
        per_call["connections"]["app"]["pool"] = {"per-call": True}
        self.assertTrue(parse_schedule(per_call).connections["app"].per_call)

    def test_read_from_standard_input(self):
        import yaml
        data = "gm-scheduler-input 1\npassword shop_app pw\nschedule\n" + yaml.safe_dump(schedule_doc())
        s, pw, cred = read_schedule(data)
        self.assertEqual((pw, cred), ({"shop_app": "pw"}, {}))
        with self.assertRaisesRegex(ConfigError, "no password"):
            read_schedule("gm-scheduler-input 1\nschedule\n" + yaml.safe_dump(schedule_doc()))

    def test_invalid_schedules(self):
        def conn(**c):
            base = {"driver": "sql/postgresql", "target": "db:5432/shop", "role": "shop_app", "pool": {"size": 2}}
            base.update(c)
            return {"connections": {"app": base}}
        stream = schedule_doc()["streams"][0]
        cases = [
            {"seed": -1}, {"seed": 2 ** 63}, {"seed": "1"}, {"intensity": -1}, {"extra": 1},
            conn(role="postgres"), conn(role="dba"), conn(role="monitoring"), conn(role="gm_check"),
            conn(role="pgbouncer_lookup"), conn(role="replicator"), conn(role="pg_monitor"), conn(role="Shop"),
            conn(driver="sql/mysql"), conn(target="db/shop"), conn(pool={"size": 0}), conn(pool={"per-call": False}),
            {"streams": [dict(stream, rate="fast")]}, {"streams": [dict(stream, arrivals="burst")]},
            {"streams": [dict(stream, shape="none")]}, {"streams": [dict(stream, connection="other")]},
            {"streams": [dict(stream, concurrency=0)]}, {"streams": [stream, stream]},
            {"shapes": {"business-hours": {"utc": {"mon": [1] * 24}}}},
            {"shapes": {"business-hours": {"hours": {"00-23": 1}}}},
            {"timeline": [{"at": "handover-6h", "stream": "orders.insert", "set": {"key": "x"}}]},
            {"timeline": [{"at": "2026-10-24T08:00:00Z", "stream": "orders.insert-v2", "set": {"key": "x"}}]},
            {"timeline": [{"at": "2026-10-24T08:00:00Z", "stream": "orders.insert", "set": {"shape": "x"}}]},
        ]
        for over in cases:
            with self.assertRaises(ConfigError, msg=repr(over)):
                parse_schedule(schedule_doc(**over))

    def test_no_stream(self):
        # a node with fixed-time operations only (D219)
        s = parse_schedule(schedule_doc(streams=[], timeline=[]))
        self.assertEqual((s.streams, s.keys()), ([], set()))

    def test_references_a_script_key_needs(self):
        from gm_scheduler.runner import check_references
        doc = schedule_doc(timeline=[{"at": "2026-10-24T08:00:00Z", "stream": "orders.insert",
                                      "set": {"key": "rollup.hourly"}}])
        doc["connections"]["shop"] = dict(doc["connections"]["app"], role="shop_etl")
        s = parse_schedule(doc)
        module = type(os)("m")
        module.hourly = lambda conns, options, log: 0
        r = repo.parse_queries({"queries": {"orders.insert": {"sql": "SELECT 1"},
                                            "rollup.hourly": {"script": "scripts/rollup.py:hourly"}}},
                               {}, {"rollup.py": module})
        jobs = parse_jobs({"jobs": [
            {"name": "ok", "key": "rollup.hourly", "connections": {"source": "shop", "target": "app"}, "at": "5 * * * *"},
            {"name": "one", "key": "rollup.hourly", "connection": "shop", "at": "5 * * * *"},
            {"name": "many", "key": "orders.insert", "connections": {"source": "shop"}, "at": "5 * * * *"},
            {"name": "far", "key": "rollup.hourly", "connections": {"source": "shop", "target": "elsewhere"},
             "at": "5 * * * *"}]})
        self.assertEqual(check_references(s, r, jobs), [
            "queries.yaml: key rollup.hourly is named by the schedule but is a script: a script runs only as a job",
            "jobs.yaml: job one: key rollup.hourly is a script: name its connections with connections:, "
            "not connection:",
            "jobs.yaml: job many: key orders.insert is not a script: it takes connection:, not connections:",
            "jobs.yaml: job far: connections.target: connection elsewhere is not one of the schedule's"])
        # a stream starting on a script key
        doc = schedule_doc(streams=[dict(schedule_doc()["streams"][0], key="rollup.hourly")], timeline=[])
        self.assertEqual(check_references(parse_schedule(doc), r, []), [
            "queries.yaml: key rollup.hourly is named by the schedule but is a script: a script runs only as a job"])

    def test_messages_never_hold_a_schedule_value(self):
        doc = schedule_doc()
        doc["streams"][0]["rate"] = "secret-rate-7/min"
        with self.assertRaises(ConfigError) as cm:
            parse_schedule(doc)
        self.assertNotIn("secret", str(cm.exception))

    def test_resuming_applies_every_past_change_and_replays_nothing(self):
        doc = schedule_doc(timeline=[
            {"at": "2026-10-24T08:00:00Z", "stream": "orders.insert", "set": {"key": "orders.insert-v2"}},
            {"at": "2026-10-24T09:00:00Z", "stream": "orders.insert", "set": {"rate": "10/min"}},
            {"at": "2026-10-24T12:00:00Z", "stream": "orders.insert", "set": {"connection": "app"}},
        ])
        s = parse_schedule(doc)
        st = s.streams[0]
        pending = apply_past_changes(st, ts("2026-10-24T10:00:00Z"))
        self.assertEqual(st.key, "orders.insert-v2")
        self.assertAlmostEqual(st.rate, 10 / 60)
        self.assertEqual([instant(c.at) for c in pending], ["2026-10-24T12:00:00Z"])


class TestArrivals(unittest.TestCase):
    def test_even_arrivals_at_two_per_hour(self):
        rate = lambda t: 2 / 3600
        t0 = ts("2026-10-24T09:00:00Z")
        at, need = next_arrival(t0, 1.0, rate, t0 + 7200)
        self.assertEqual((instant(at), need), ("2026-10-24T09:30:00Z", 0.0))

    def test_a_limit_returns_what_is_left(self):
        rate = lambda t: 1.0
        at, need = next_arrival(100.0, 10.0, rate, 104.0, boundary_after=lambda t: t + 1000)
        self.assertEqual((at, need), (104.0, 6.0))

    def test_shape_hours_and_weekdays(self):
        # 2026-10-24 is a Saturday (weekday 5)
        shape = {d: [0.0] * 24 for d in range(7)}
        shape[5][10] = 2.0
        self.assertEqual(shape_multiplier(shape, ts("2026-10-24T10:59:59Z")), 2.0)
        self.assertEqual(shape_multiplier(shape, ts("2026-10-24T11:00:00Z")), 0.0)
        self.assertEqual(shape_multiplier(shape, ts("2026-10-25T10:00:00Z")), 0.0)
        self.assertEqual(shape_multiplier(None, 0), 1.0)
        s = parse_schedule(schedule_doc(intensity=0.5, streams=[{"key": "k", "connection": "app", "rate": "60/min",
                                                                 "arrivals": "even", "shape": "sat10"}],
                                        shapes={"sat10": {"utc": {d: ([0] * 10 + [2] + [0] * 13 if d == "sat"
                                                                      else [0] * 24)
                                                                  for d in ("mon", "tue", "wed", "thu", "fri",
                                                                            "sat", "sun")}}},
                                        timeline=[]))
        rate_at = rate_function(s.streams[0], s.intensity, s.shapes)
        # the rate is 0 until Saturday 10:00, then 60/min x 0.5 x 2 = 1/s
        at, need = next_arrival(ts("2026-10-24T06:30:00Z"), 1.0, rate_at, ts("2026-10-25T00:00:00Z"))
        self.assertEqual(instant(at), "2026-10-24T10:00:01Z")
        self.assertAlmostEqual(rate_at(ts("2026-10-24T10:30:00Z")), 1.0)

    def test_poisson_arrivals_are_seeded_and_at_the_rate(self):
        def gaps():
            rng = derive(1, "h", "stream:0:k", 0)
            t, out = 0.0, []
            for _ in range(4000):
                at, _ = next_arrival(t, rng.expovariate(1.0), lambda x: 0.5, t + 1e9,
                                     boundary_after=lambda x: x + 3600)
                out.append(at - t)
                t = at
            return out
        a = gaps()
        self.assertEqual(a, gaps())
        self.assertAlmostEqual(sum(a) / len(a), 2.0, delta=0.15)


class TestSummaries(unittest.TestCase):
    def test_summary_and_key_lines(self):
        s = Stats()
        m = ts("2026-10-24T09:14:00Z")
        s.touch({"orders.insert", "orders.idle"}, m)
        for i in range(40):
            s.record("orders.insert", 0.001 + i * 0.0002, i == 0, m + 1 + i)
        s.record("orders.report", 0.081, False, m + 50)
        lines = s.summary(m)
        t = ts("2026-10-24T09:15:00Z")
        text = [format_line(t, e, f) for e, f in lines]
        self.assertEqual(text[0], "2026-10-24T09:15:00Z summary minute=2026-10-24T09:14Z keys=3 calls=41 errors=1")
        self.assertEqual(text[1], "2026-10-24T09:15:00Z key minute=2026-10-24T09:14Z key=orders.idle calls=0 "
                                  "errors=0 p50_ms=- p95_ms=- p99_ms=-")
        self.assertTrue(text[2].startswith("2026-10-24T09:15:00Z key minute=2026-10-24T09:14Z key=orders.insert "
                                           "calls=40 errors=1 p50_ms=4.8 p95_ms="))
        self.assertEqual(text[3], "2026-10-24T09:15:00Z key minute=2026-10-24T09:14Z key=orders.report calls=1 "
                                  "errors=0 p50_ms=81.0 p95_ms=81.0 p99_ms=81.0")
        # the minute is forgotten; an empty minute still has its summary
        self.assertEqual(s.summary(m + 60), [("summary", [("minute", "2026-10-24T09:15Z"), ("keys", 0),
                                                         ("calls", 0), ("errors", 0)])])

    def test_percentiles(self):
        v = sorted(range(1, 101))
        self.assertEqual((percentile(v, 50), percentile(v, 95), percentile(v, 99)), (50, 95, 99))
        self.assertEqual(percentile([7], 99), 7)
        self.assertIsNone(percentile([], 50))

    def test_metrics_text(self):
        s = Stats()
        s.declare("k")
        s.record("k", 0.003, False, 0)
        s.record("k", 2.0, True, 0)
        s.job_run("j.key", "close-day")
        s.job_skip("j.key", "close-day", "still-running")
        text = s.prometheus()
        for line in ('scheduler_calls_total{key="k"} 2', 'scheduler_errors_total{key="k"} 1',
                     'scheduler_call_duration_seconds_bucket{key="k",le="0.005"} 1',
                     'scheduler_call_duration_seconds_bucket{key="k",le="2.5"} 2',
                     'scheduler_call_duration_seconds_bucket{key="k",le="+Inf"} 2',
                     'scheduler_call_duration_seconds_count{key="k"} 2',
                     'scheduler_job_runs_total{key="j.key",job="close-day"} 1',
                     'scheduler_job_skips_total{key="j.key",job="close-day",reason="still-running"} 1',
                     'scheduler_calls_total{key="j.key"} 0', "scheduler_running 0"):
            self.assertIn(line + "\n", text)
        self.assertIn("# TYPE scheduler_call_duration_seconds histogram", text)


def http_conn(**over):
    base = {"driver": "http", "target": "lab-api:8000", "credential": "interfaces_lab_api", "pool": 2}
    base.update(over)
    return base


class TestHttpConnections(unittest.TestCase):
    """v0.5: the `http` driver's connection form (capture W1 item 3)."""

    def test_valid_http_connection(self):
        doc = schedule_doc(timeline=[])
        doc["connections"]["lab-api"] = http_conn()
        doc["connections"]["owners"] = {"driver": "http", "target": "portal-api:8000", "pool": 1, "timeout": "3s"}
        s = parse_schedule(doc, {"shop_app": "pw"}, {"interfaces_lab_api": "t"})
        c = s.connections["lab-api"]
        self.assertEqual((c.driver, c.host, c.port, c.target, c.credential, c.pool_size, c.timeout, c.role),
                         ("http", "lab-api", 8000, "lab-api:8000", "interfaces_lab_api", 2, 10, None))
        self.assertTrue(c.http)
        public = s.connections["owners"]
        self.assertEqual((public.credential, public.timeout, public.pool_size), (None, 3, 1))
        self.assertFalse(s.connections["app"].http)

    def test_a_credential_not_passed_refuses_the_schedule(self):
        doc = schedule_doc(timeline=[])
        doc["connections"]["lab-api"] = http_conn()
        with self.assertRaisesRegex(ConfigError, r"connections\.lab-api: no credential was passed"):
            parse_schedule(doc, {"shop_app": "pw"}, {})
        # a public endpoint needs none; the root-side check passes no secrets at all
        del doc["connections"]["lab-api"]["credential"]
        parse_schedule(doc, {"shop_app": "pw"}, {})
        parse_schedule(doc)

    def test_invalid_http_connections(self):
        for over in ({"target": "lab-api:8000/db"}, {"target": "lab-api"}, {"target": "lab-api:0"},
                     {"credential": "Lab"}, {"credential": "1lab"}, {"pool": 0}, {"pool": {"size": 2}},
                     {"pool": True}, {"timeout": "0s"}, {"timeout": "61s"}, {"timeout": "1m"}, {"timeout": 10},
                     {"role": "lab_api"}, {"tls": True}):
            doc = schedule_doc(timeline=[])
            doc["connections"]["lab-api"] = http_conn(**over)
            with self.assertRaises(ConfigError, msg=repr(over)):
                parse_schedule(doc)
        # an SQL connection takes no credential or timeout
        for over in ({"credential": "x"}, {"timeout": "5s"}):
            doc = schedule_doc(timeline=[])
            doc["connections"]["app"].update(over)
            with self.assertRaises(ConfigError, msg=repr(over)):
                parse_schedule(doc)

    def test_replicator_is_never_a_schedule_role(self):
        doc = schedule_doc(timeline=[])
        doc["connections"]["app"]["role"] = "replicator"
        with self.assertRaisesRegex(ConfigError, "replicator"):
            parse_schedule(doc)


class TestWeightedChoice(unittest.TestCase):
    """v0.5: `{choice: {value: weight, ...}}` beside the uniform list."""

    def test_a_seeded_weighted_draw_is_within_tolerance(self):
        g = gen.compile_param({"choice": {"dog": 45, "cat": 25, "horse": 15, "cattle": 10, "other": 5}},
                              "species", "k.species")

        def run():
            rng = derive(4815162342, "pms", "stream:0:k", 0)
            return [g.draw(rng, Ctx()) for _ in range(20000)]
        draws = run()
        self.assertEqual(draws, run())                         # seeded: the same draws twice
        for value, weight in (("dog", 45), ("cat", 25), ("horse", 15), ("cattle", 10), ("other", 5)):
            share = draws.count(value) / len(draws)
            self.assertAlmostEqual(share, weight / 100, delta=0.015, msg=value)

    def test_weights_are_relative(self):
        g = gen.compile_param({"choice": {"grant": 3, "withdraw": 1}}, "consent", "k.consent")
        rng = random.Random(7)
        draws = [g.draw(rng, Ctx()) for _ in range(8000)]
        self.assertAlmostEqual(draws.count("grant") / len(draws), 0.75, delta=0.02)
        self.assertEqual(set(draws), {"grant", "withdraw"})
        one = gen.compile_param({"choice": {7: 1}}, "p", "k.p")
        self.assertEqual(one.draw(rng, Ctx()), 7)

    def test_invalid_weighted_choices(self):
        for bad in ({"choice": {}}, {"choice": {"a": 0}}, {"choice": {"a": -1}}, {"choice": {"a": 1.5}},
                    {"choice": {"a": True}}, {"choice": {"a": "1"}}, {"choice": {"a": 1, "b": None}}):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                gen.compile_param(bad, "p", "k.p")


class TestCalls(unittest.TestCase):
    """v0.5: the call, the repository's sixth form (capture W1 item 3)."""

    def parse(self, queries, modules=None):
        return repo.parse_queries({"queries": queries}, modules or {})

    def test_method_path_and_body_from_parameters(self):
        import json
        r = self.parse({"portal.desk-consent": {
            "call": "POST /owners/%(owner)s/consents",
            "params": {"owner": {"int": [2, 10000]}, "consent": {"choice": {"grant": 3, "withdraw": 1}},
                       "amount": {"decimal": [5, 500, 2]}, "at": {"now": "utc"}, "channel": "desk"}}})
        entry = r.get("portal.desk-consent")
        self.assertEqual(entry.kind, "call")
        p = entry.plan(random.Random(3), Ctx(now=ts("2026-11-03T08:15:00Z")), 1.0)
        self.assertEqual(p.method, "POST")
        self.assertRegex(p.target, r"^/owners/[0-9]+/consents$")
        self.assertTrue(2 <= int(p.target.split("/")[2]) <= 10000)
        self.assertEqual(p.content_type, "application/json")
        body = json.loads(p.body)
        self.assertEqual(set(body), {"consent", "amount", "at", "channel"})   # the path's owner is not in it
        self.assertIn(body["consent"], ("grant", "withdraw"))
        self.assertIsInstance(body["amount"], float)                         # a number, never a string
        self.assertRegex(p.body.decode(), r'"amount":[0-9]+\.[0-9]{2}[,}]')    # with its two digits
        self.assertEqual(body["at"], "2026-11-03T08:15:00Z")
        self.assertEqual(body["channel"], "desk")
        # the same seed, the same call
        self.assertEqual(len({entry.plan(random.Random(9), Ctx(), 1.0).body for _ in range(3)}), 1)

    def test_a_get_puts_its_parameters_in_the_query_string_and_quotes_the_path(self):
        r = self.parse({"lab.result": {"call": "GET /results/%(sample)s",
                                       "params": {"sample": {"choice": ["A 1/2"]}, "full": True,
                                                  "species": {"choice": ["dog"]}}},
                        "lab.forget": {"call": "DELETE /orders/%(id)s", "params": {"id": 7}},
                        "lab.ping": {"call": "POST /ping"}})
        p = r.get("lab.result").plan(random.Random(1), Ctx(), 1.0)
        self.assertEqual((p.method, p.target, p.body, p.content_type),
                         ("GET", "/results/A%201%2F2?full=true&species=dog", None, None))
        p = r.get("lab.forget").plan(random.Random(1), Ctx(), 1.0)
        self.assertEqual((p.method, p.target, p.body), ("DELETE", "/orders/7", None))
        p = r.get("lab.ping").plan(random.Random(1), Ctx(), 1.0)
        self.assertEqual((p.target, p.body), ("/ping", b"{}"))        # no parameter: an empty JSON object

    def test_a_builder_returns_the_body(self):
        module = type(os)("orders")

        def order(intensity, options, rng=None):
            return {"urgent": rng.random() < options["urgent_share"], "tests": ["cbc", "chem"],
                    "n": int(10 * intensity), "price": decimal.Decimal("12.50")}
        module.order = order
        module.query = lambda intensity, options: {"since": "2026-11-01"}
        module.bad = lambda intensity, options: {"at": object()}
        r = self.parse({"lab.order.post": {"call": "POST /labs/%(lab)s/orders", "builder": "builders/orders.py:order",
                                           "params": {"lab": "north"}, "options": {"urgent_share": 0.08}},
                        "lab.order.list": {"call": "GET /orders", "builder": "builders/orders.py:query"},
                        "lab.order.bad": {"call": "PUT /orders", "builder": "builders/orders.py:bad"}},
                       {"orders.py": module})
        p = r.get("lab.order.post").plan(random.Random(5), Ctx(), 2.0)
        self.assertEqual((p.method, p.target, p.content_type), ("POST", "/labs/north/orders", "application/json"))
        self.assertRegex(p.body.decode(), r'^\{"urgent":(true|false),"tests":\["cbc","chem"\],"n":20,"price":12\.50\}$')
        p = r.get("lab.order.list").plan(random.Random(5), Ctx(), 1.0)
        self.assertEqual((p.target, p.body), ("/orders?since=2026-11-01", None))
        with self.assertRaisesRegex(repo.BuilderResult, "not JSON"):
            r.get("lab.order.bad").plan(random.Random(5), Ctx(), 1.0)

    def test_invalid_calls(self):
        module = type(os)("orders")
        module.order = lambda intensity, options: {}
        for bad in ({"call": "post /orders"}, {"call": "FETCH /orders"}, {"call": "POST orders"},
                    {"call": "POST /a b"}, {"call": "POST"}, {"call": "POST /orders/%(id)s"},
                    {"call": "POST /orders/%(id)d", "params": {"id": 1}}, {"call": "POST /orders#x"},
                    {"call": "POST /orders", "options": {"a": 1}}, {"call": "POST /orders", "sql": "SELECT 1"},
                    {"call": "POST /orders", "transaction": {"isolation": "read committed"}},
                    {"call": "POST /orders/%(id)s", "builder": "builders/orders.py:order",
                     "params": {"id": 1, "extra": 2}},
                    {"call": "POST /orders", "builder": "builders/orders.py:missing"}, {"call": 7}):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                self.parse({"k": bad}, {"orders.py": module})
        # a percent escape stays as written
        r = self.parse({"k": {"call": "GET /a%20b"}})
        self.assertEqual(r.get("k").plan(random.Random(1), Ctx(), 1.0).target, "/a%20b")

    def test_json_on_the_wire(self):
        from gm_scheduler.drivers.http import encode_json, scalar_text
        when = datetime.datetime(2026, 11, 3, 8, 15, 0, 123456, tzinfo=UTC)
        self.assertEqual(encode_json({"a": decimal.Decimal("0.10"), "b": [decimal.Decimal("-3.000")], "t": when,
                                      "u": "é"}),
                         '{"a":0.10,"b":[-3.000],"t":"2026-11-03T08:15:00.123456Z","u":"é"}'.encode())
        with self.assertRaises(ValueError):
            encode_json({"a": decimal.Decimal("NaN")})
        with self.assertRaises(TypeError):
            encode_json({"a": object()})
        self.assertEqual([scalar_text(v) for v in (True, None, decimal.Decimal("1.50"), 3)],
                         ["true", "", "1.50", "3"])


class TestDriverChecks(unittest.TestCase):
    """v0.5: a call only on an HTTP connection, every other key only on a SQL
    one; a job with connection: never on an HTTP connection."""

    def test_driver_problems(self):
        from gm_scheduler.runner import check_references
        doc = schedule_doc(timeline=[
            {"at": "2026-10-24T08:00:00Z", "stream": "orders.insert", "set": {"key": "portal.consent"}}])
        doc["connections"]["portal"] = http_conn(target="portal-api:8000")
        doc["streams"].append({"key": "portal.consent", "connection": "portal", "rate": "1/min", "arrivals": "even"})
        doc["streams"].append({"key": "orders.lookup", "connection": "portal", "rate": "1/min", "arrivals": "even"})
        s = parse_schedule(doc)
        r = repo.parse_queries({"queries": {"orders.insert": {"sql": "SELECT 1"}, "orders.lookup": {"sql": "SELECT 2"},
                                            "portal.consent": {"call": "POST /consents"}}}, {})
        jobs = parse_jobs({"jobs": [
            {"name": "ping", "key": "portal.consent", "connection": "portal", "at": "5 * * * *"},
            {"name": "sql", "key": "orders.insert", "connection": "portal", "at": "5 * * * *"},
            {"name": "fine", "key": "orders.insert", "connection": "app", "at": "5 * * * *"}]})
        self.assertEqual(check_references(s, r, jobs), [
            "queries.yaml: key portal.consent is a call, but the schedule runs it on connection app, which is not an "
            "HTTP connection",
            "queries.yaml: key orders.lookup is not a call, but the schedule runs it on connection portal, an HTTP "
            "connection",
            "jobs.yaml: job ping: key portal.consent is a call: a call runs only in a stream",
            "jobs.yaml: job sql: connection portal is an HTTP connection: a job with connection: runs SQL; an HTTP "
            "connection is a stream's or a script's"])


if __name__ == "__main__":
    unittest.main()
