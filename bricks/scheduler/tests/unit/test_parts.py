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
from gm_scheduler.textlog import format_line
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

    def test_never_and_invalid(self):
        self.assertIsNone(Cron("0 0 31 2 *").next_after(ts("2026-10-24T00:00:00Z")))
        for bad in ("* * * *", "60 * * * *", "0 24 * * *", "0 0 0 * *", "0 0 * 13 *", "0 0 * * 8",
                    "0 0 * * mon", "@daily", "5-1 * * * *", 5):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                Cron(bad)
        with self.assertRaises(ConfigError):
            Cron("0 0 * * *", "Mars/Olympus")


class TestJobs(unittest.TestCase):
    def test_parse(self):
        jobs = parse_jobs({"jobs": [{"name": "close-day", "key": "invoices.close-day", "connection": "app",
                                     "at": "30 1 * * *"},
                                    {"name": "tz", "key": "k", "connection": "app", "at": "0 2 * * *",
                                     "timezone": "Etc/GMT-5"}]})
        self.assertEqual([j.name for j in jobs], ["close-day", "tz"])
        self.assertEqual(jobs[1].cron.zone_name, "Etc/GMT-5")
        self.assertEqual(parse_jobs({"jobs": []}), [])

    def test_invalid(self):
        ok = {"name": "a", "key": "k", "connection": "app", "at": "0 1 * * *"}
        for bad in ({"jobs": [dict(ok, at="0 25 * * *")]}, {"jobs": [ok, ok]}, {"jobs": [dict(ok, extra=1)]},
                    {"jobs": [dict(ok, key="Bad Key")]}, {"jobs": [dict(ok, timezone="Nowhere/Here")]},
                    {"jobs": {}}, {"other": []}):
            with self.assertRaises(ConfigError, msg=repr(bad)):
                parse_jobs(bad)


class TestSchedule(unittest.TestCase):
    def test_input_framing(self):
        passwords, text = parse_input("gm-scheduler-input 1\npassword shop_app s3cr3t\nschedule\nseed: 1\n")
        self.assertEqual(passwords, {"shop_app": "s3cr3t"})
        self.assertEqual(text, "seed: 1\n")
        for bad in ("", "seed: 1", "gm-scheduler-input 1\npassword x\nschedule\n", "gm-scheduler-input 1\n"):
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
        s, pw = read_schedule(data)
        self.assertEqual(pw, {"shop_app": "pw"})
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
            conn(role="pgbouncer_lookup"), conn(role="pg_monitor"), conn(role="Shop"),
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


if __name__ == "__main__":
    unittest.main()
