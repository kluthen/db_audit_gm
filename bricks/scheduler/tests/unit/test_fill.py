"""The fill mode and the queue model (v0.6 build plan, chunk 8a; capture W1
items 7, 8 and 9).

The model's and the input's tests run anywhere; P0's measurement and the
fill's own run need the throwaway PostgreSQL of run-in-image.sh (pgtest).
"""

import datetime
import io
import json
import os
import random
import shutil
import tempfile
import unittest

import yaml

from pgtest import ADMIN, ADMIN_PASSWORD, DB, DST_DB, DST_PASSWORD, DST_ROLE, HOST, PASSWORD, PORT, ROLE, \
    SRC_PASSWORD, SRC_ROLE, admin, needs_pg

UTC = datetime.timezone.utc
VT0 = "2026-03-02T21:00:00Z"            # a Monday evening, virtual
ANCHOR = "2026-03-02T21:30:00Z"
PAUSE = "2026-03-02T21:12:00Z"


def ts(text):
    return datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC).timestamp()


class TestVirtualize(unittest.TestCase):
    def test_the_three_clock_forms_become_one_bound_instant(self):
        from gm_scheduler.fill import virtualize
        sql, p = virtualize("SELECT now(), CURRENT_TIMESTAMP, current_date, x FROM t WHERE a = %(a)s",
                            {"a": 1}, ts(VT0))
        self.assertEqual(sql, "SELECT %(gm_vnow)s::timestamptz, %(gm_vnow)s::timestamptz, "
                              "(%(gm_vnow)s::timestamptz)::date, x FROM t WHERE a = %(a)s")
        self.assertEqual(p["a"], 1)
        self.assertEqual(p["gm_vnow"], datetime.datetime(2026, 3, 2, 21, 0, tzinfo=UTC))

    def test_a_statement_without_the_clock_is_sent_as_written(self):
        from gm_scheduler.fill import virtualize
        self.assertEqual(virtualize("SELECT 'TB-%' LIKE x, nowhere()", None, 0.0), ("SELECT 'TB-%' LIKE x, nowhere()",
                                                                                    None))

    def test_a_statement_gaining_parameters_doubles_its_percent_signs(self):
        from gm_scheduler.fill import virtualize
        sql, p = virtualize("SELECT sku LIKE 'TB-%' AND at < now()", None, 0.0)
        self.assertEqual(sql, "SELECT sku LIKE 'TB-%%' AND at < %(gm_vnow)s::timestamptz")
        self.assertEqual(list(p), ["gm_vnow"])

    def test_positional_parameters_with_the_clock_are_refused(self):
        from gm_scheduler.fill import FillError, virtualize
        self.assertEqual(virtualize("SELECT %s", (1,), 0.0), ("SELECT %s", (1,)))
        with self.assertRaises(FillError):
            virtualize("SELECT now() > %s", (1,), 0.0)


class TestQueueModel(unittest.TestCase):
    def model(self, effects=(), pools=None, st=None):
        from gm_scheduler.queue import Model, parse_service_times
        st = st or {"p": parse_service_times({"a": {"median": 0.01, "sigma": 0.0},
                                              "b": {"median": 0.002, "sigma": 0.0},
                                              "batch": {"median": 1.0, "sigma": 0.0}}, "st")}
        return Model(st, list(effects), pools or {}, random.Random(7))

    def test_a_direct_call_is_its_service_its_hold_and_the_round_trip(self):
        from gm_scheduler.queue import CLIENT_OVERHEAD
        m = self.model()
        self.assertAlmostEqual(m.call("p", "a", 100.0), 0.01 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "a", 100.0, hold=3), 3.01 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "a", 100.0, error=True), CLIENT_OVERHEAD)

    def test_a_pool_queues_its_calls_first_come_first_served(self):
        from gm_scheduler.queue import CLIENT_OVERHEAD
        m = self.model(pools={"pooler/shop/app": 2})
        held = [m.call("p", "a", 100.0, hold=3, pool="pooler/shop/app") for _ in range(2)]
        self.assertAlmostEqual(held[0], 3.01 + CLIENT_OVERHEAD)
        waited = m.call("p", "b", 101.0, pool="pooler/shop/app")
        self.assertAlmostEqual(waited, (103.01 - 101.0) + 0.002 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "b", 200.0, pool="pooler/shop/app"), 0.002 + CLIENT_OVERHEAD)

    def test_a_service_effect_starts_at_its_planting(self):
        from gm_scheduler.queue import CLIENT_OVERHEAD, parse_effect
        e = parse_effect({"instance": "f8", "node": "p", "key": "a", "service": {"median": 0.5, "sigma": 0}},
                         "queue[0]", 150.0)
        m = self.model([e])
        self.assertAlmostEqual(m.call("p", "a", 149.0), 0.01 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "a", 151.0), 0.5 + CLIENT_OVERHEAD)

    def test_a_lock_effect_makes_the_blocked_keys_wait(self):
        from gm_scheduler.queue import CLIENT_OVERHEAD, parse_effect
        e = parse_effect({"instance": "f5", "node": "p", "key": "batch",
                          "lock": {"median": 20, "sigma": 0, "blocks": ["b"]}}, "queue[0]", 0.0)
        m = self.model([e])
        self.assertAlmostEqual(m.call("p", "batch", 100.0), 21.0 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "b", 105.0), 15.0 + 0.002 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "a", 105.0), 0.01 + CLIENT_OVERHEAD)
        self.assertAlmostEqual(m.call("p", "b", 121.0), 0.002 + CLIENT_OVERHEAD)

    def test_the_draws_are_lognormal_around_the_median_and_reproducible(self):
        from gm_scheduler.queue import Model, parse_service_times
        st = {"p": parse_service_times({"a": {"median": 0.01, "sigma": 0.35}}, "st")}
        draws = [Model(st, [], {}, random.Random(3)).call("p", "a", float(i)) for i in range(1)]
        again = [Model(st, [], {}, random.Random(3)).call("p", "a", float(i)) for i in range(1)]
        self.assertEqual(draws, again)
        m = Model(st, [], {}, random.Random(3))
        values = sorted(m.call("p", "a", float(i)) for i in range(2001))
        self.assertAlmostEqual(values[1000], 0.0104, delta=0.0008)

    def test_bad_figures_are_refused(self):
        from gm_scheduler import ConfigError
        from gm_scheduler.queue import parse_effect, parse_service_times
        for bad in ({"a": {"median": 0, "sigma": 0.1}}, {"a": {"median": 0.1}}, {"a": [1, 2]}):
            with self.assertRaises(ConfigError):
                parse_service_times(bad, "st")
        for bad in ({"instance": "f", "node": "p", "key": "a"},
                    {"instance": "f", "node": "p", "key": "a", "service": {"median": 1, "sigma": 0},
                     "lock": {"median": 1, "sigma": 0, "blocks": ["b"]}},
                    {"instance": "f", "node": "p", "key": "a", "lock": {"median": 1, "sigma": 0}}):
            with self.assertRaises(ConfigError):
                parse_effect(bad, "queue[0]", 0.0)


QUERIES = """\
queries:
  orders.place:
    transaction: {isolation: read committed, hold: 3s}
    steps:
      - sql: INSERT INTO f_orders (customer, placed_at, day) VALUES (%(c)s, now(), current_date)
        params:
          c: {int: [1, 50]}
      - sql: UPDATE f_customers SET last_order_at = now() WHERE id = %(c)s
        params:
          c: {int: [1, 50]}
  orders.mark:
    sql: INSERT INTO f_marks (at, fn_at, clock_at) VALUES (current_timestamp, f_server_now(), clock_timestamp())
  catalog.lookup:
    sql: SELECT * FROM f_products WHERE sku LIKE 'TB-%'
  catalog.broken:
    sql: SELECT gm_missing_function()
  reports.dashboard:
    transaction: {isolation: repeatable read, hold: 5m}
    sql: SELECT count(*) FROM f_orders
  orders.close-day:
    transaction: {isolation: read committed, hold: 20s}
    sql: UPDATE f_customers SET lifetime_value = lifetime_value + 1
  orders.touch:
    steps:
      - sql: SELECT count(*) FROM f_orders
      - sql: SELECT count(*) FROM f_customers
"""

SCRIPT = """\
def hourly(conns, options, log):
    src, dst = conns["source"], conns["target"]
    with src.cursor() as cur:
        cur.execute("SELECT now(), count(*) FROM f_orders")
        at, n = cur.fetchone()
    src.commit()
    with dst.cursor() as cur:
        cur.execute("INSERT INTO f_rollups (at, orders, clock_at) VALUES (%(at)s, %(n)s, clock_timestamp())",
                    {"at": at, "n": n})
    dst.commit()
    log(f"rolled up {n} orders at {at:%H:%M}")
    return 1
"""

SHAPE = {"utc": {d: [1.0] * 24 for d in ("mon", "tue", "wed", "thu", "fri", "sat", "sun")}}


def node_input(doc, passwords):
    return ("gm-scheduler-input 1\n" + "".join(f"password {r} {p}\n" for r, p in passwords.items())
            + "schedule\n" + yaml.safe_dump(doc))


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


@needs_pg
class TestP0(unittest.TestCase):
    """P0's measurement (W1 item 8): which of the database's clock forms the
    fill binds to the virtual instant, and that no real-mode session sees
    it. The expected values are the result, recorded in W1-x."""

    @classmethod
    def setUpClass(cls):
        from gm_scheduler.fill import VCLOCK_DROP, VCLOCK_SQL
        admin(VCLOCK_DROP)
        admin(VCLOCK_SQL)
        admin("DROP TABLE IF EXISTS p0_defaults")
        admin("CREATE TABLE p0_defaults (id int, at timestamptz DEFAULT now())")
        admin("GRANT ALL ON p0_defaults TO PUBLIC")
        bodies = {
            "p0_plpgsql_now": "LANGUAGE plpgsql AS $$BEGIN RETURN now(); END$$",
            "p0_plpgsql_clock": "LANGUAGE plpgsql AS $$BEGIN RETURN clock_timestamp(); END$$",
            "p0_plpgsql_txn": "LANGUAGE plpgsql AS $$BEGIN RETURN transaction_timestamp(); END$$",
            "p0_sql_now": "LANGUAGE sql AS $$SELECT now()$$",
            "p0_plpgsql_keyword": "LANGUAGE plpgsql AS $$BEGIN RETURN current_timestamp; END$$",
            "p0_plpgsql_own_path": "LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp "
                                   "AS $$BEGIN RETURN now(); END$$",
            "p0_sql_atomic": "LANGUAGE sql BEGIN ATOMIC SELECT now(); END",
        }
        for name, body in bodies.items():
            admin(f"CREATE OR REPLACE FUNCTION public.{name}() RETURNS timestamptz {body}")
        admin("CREATE OR REPLACE FUNCTION public.p0_plpgsql_date() RETURNS date LANGUAGE plpgsql "
              "AS $$BEGIN RETURN current_date; END$$")
        admin("CREATE OR REPLACE FUNCTION public.p0_default_row() RETURNS timestamptz LANGUAGE plpgsql "
              "AS $$DECLARE r timestamptz; BEGIN INSERT INTO p0_defaults (id) VALUES (1) RETURNING at INTO r; "
              "RETURN r; END$$")

    @classmethod
    def tearDownClass(cls):
        from gm_scheduler.fill import VCLOCK_DROP
        admin(VCLOCK_DROP)

    def test_what_the_virtual_clock_reaches(self):
        from gm_scheduler.fill import connect, set_clock, virtualize
        vt = ts("2025-06-01T08:00:00Z")
        conn = connect(HOST, PORT, DB, ROLE, PASSWORD, "p0")
        self.addCleanup(conn.close)
        set_clock(conn, vt)
        virtual = datetime.datetime.fromtimestamp(vt, UTC)

        def value(sql):
            s, p = virtualize(sql, None, vt)
            return conn.execute(s, p).fetchone()[0]

        def is_virtual(v):
            if isinstance(v, datetime.datetime):
                return abs((v - virtual).total_seconds()) < 5
            return v == virtual.date()

        reached = {sql: is_virtual(value(sql)) for sql in (
            "SELECT now()", "SELECT current_timestamp", "SELECT current_date",      # the fill's own SQL
            "SELECT clock_timestamp()", "SELECT transaction_timestamp()", "SELECT statement_timestamp()",
            "SELECT p0_plpgsql_now()", "SELECT p0_plpgsql_clock()", "SELECT p0_plpgsql_txn()",
            "SELECT p0_sql_now()",
            "SELECT p0_plpgsql_keyword()", "SELECT p0_plpgsql_date()", "SELECT p0_plpgsql_own_path()",
            "SELECT p0_sql_atomic()", "SELECT p0_default_row()")}
        self.assertEqual(reached, {
            "SELECT now()": True, "SELECT current_timestamp": True, "SELECT current_date": True,
            "SELECT clock_timestamp()": True, "SELECT transaction_timestamp()": True,
            "SELECT statement_timestamp()": True,
            "SELECT p0_plpgsql_now()": True, "SELECT p0_plpgsql_clock()": True, "SELECT p0_plpgsql_txn()": True,
            "SELECT p0_sql_now()": True,
            # out of its reach (W1 item 8): SQL keywords in a body, a function's own
            # search_path, a BEGIN ATOMIC body, a column's DEFAULT now()
            "SELECT p0_plpgsql_keyword()": False, "SELECT p0_plpgsql_date()": False,
            "SELECT p0_plpgsql_own_path()": False, "SELECT p0_sql_atomic()": False,
            "SELECT p0_default_row()": False,
        })

    def test_a_real_mode_session_never_sees_it(self):
        import psycopg
        from gm_scheduler.fill import connect, set_clock
        fill = connect(HOST, PORT, DB, ROLE, PASSWORD, "p0")
        set_clock(fill, ts("2025-06-01T08:00:00Z"))
        fill.close()
        with psycopg.connect(host=HOST, port=PORT, dbname=DB, user=ROLE, password=PASSWORD,
                             autocommit=True) as real:
            path, setting, now = real.execute("SELECT current_setting('search_path'), "
                                              "current_setting('gm.vclock', true), "
                                              "abs(extract(epoch FROM now() - statement_timestamp()))").fetchone()
            self.assertNotIn("gm_vclock", path)
            self.assertIn(setting, (None, ""))
            self.assertLess(now, 5)
            self.assertLess(abs((real.execute("SELECT p0_plpgsql_now()").fetchone()[0]
                                 - datetime.datetime.now(UTC)).total_seconds()), 60)

    def test_the_session_path_places_the_shim_by_the_rule(self):
        # master spec 9.4's rule (spec D530): right before pg_catalog, else at the
        # end ahead of a final pg_temp; the first schema stays the creation schema
        from gm_scheduler.fill import connect, vclock_path
        self.assertEqual(vclock_path('"$user", public'), '"$user", public, gm_vclock, pg_catalog')
        self.assertEqual(vclock_path("pg_catalog, pg_temp"), "gm_vclock, pg_catalog, pg_temp")
        self.assertEqual(vclock_path("public, pg_temp"), "public, gm_vclock, pg_catalog, pg_temp")
        self.assertEqual(vclock_path("rpt, pg_catalog, public"), "rpt, gm_vclock, pg_catalog, public")
        self.assertEqual(vclock_path('""'), '"", gm_vclock, pg_catalog')
        self.assertEqual(vclock_path("public, gm_vclock, pg_catalog"), "public, gm_vclock, pg_catalog")
        conn = connect(HOST, PORT, DB, ADMIN, ADMIN_PASSWORD, "p0")
        self.addCleanup(conn.close)
        self.addCleanup(admin, "DROP TABLE IF EXISTS public.p0_landing")
        self.assertEqual(conn.execute("SELECT current_setting('search_path')").fetchone()[0],
                         '"$user", public, gm_vclock, pg_catalog')
        conn.execute("CREATE TABLE p0_landing (id int)")      # a session's unqualified CREATE TABLE
        self.assertEqual(admin("SELECT relnamespace::regnamespace::text FROM pg_class "
                               "WHERE relname = 'p0_landing'"), [("public",)])

    def test_a_database_without_the_schema_fails_the_fill(self):
        from gm_scheduler.fill import FillError, connect
        with self.assertRaisesRegex(FillError, "has no schema gm_vclock"):
            connect(HOST, PORT, "postgres", ADMIN, ADMIN_PASSWORD, "p0")

    # --- the cover (master spec 9.4, spec D523; capture W2 item 13) ------------------

    def cover_rows(self):
        """COVER_SQL as gmctl fill sends it (psql runs both statements): its
        rows, by signature."""
        import psycopg
        from gm_scheduler.fill import COVER_SQL
        with psycopg.connect(host=HOST, port=PORT, dbname=DB, user=ADMIN, password=ADMIN_PASSWORD,
                             autocommit=True) as conn:
            cur = conn.cursor()
            cur.execute(COVER_SQL)
            while cur.description is None and cur.nextset():
                pass
            return {r["signature"]: r for (r,) in cur.fetchall()}

    def proconfig(self, signature):
        rows = admin("SELECT proconfig FROM pg_proc WHERE oid = to_regprocedure(%s)", (signature,))
        return rows[0][0] if rows else "gone"

    def test_the_cover_reaches_routines_pinning_their_own_path(self):
        import psycopg
        from gm_scheduler.fill import connect, set_clock
        admin("DROP SCHEMA IF EXISTS p0_rpt, gm_p0 CASCADE")
        admin("CREATE SCHEMA p0_rpt")
        admin("CREATE SCHEMA gm_p0")
        admin(f"GRANT USAGE ON SCHEMA p0_rpt TO {ROLE}")
        admin("CREATE TABLE p0_rpt.closes (by text, at timestamptz, zone text)")
        admin(f"GRANT ALL ON p0_rpt.closes TO {ROLE}")
        self.addCleanup(admin, "DROP SCHEMA IF EXISTS p0_rpt, gm_p0 CASCADE")
        # rpt.close_day()'s shape under the campaign's f7: its own path, then a TimeZone
        admin("CREATE PROCEDURE p0_rpt.close_day(who text) LANGUAGE plpgsql "
              "SET search_path = pg_catalog, pg_temp SET TimeZone = 'Etc/GMT-2' AS "
              "$$BEGIN INSERT INTO p0_rpt.closes VALUES (who, now(), current_setting('TimeZone')); END$$")
        admin("CREATE FUNCTION p0_rpt.p0_pinned_public() RETURNS timestamptz LANGUAGE plpgsql "
              "SET search_path = public, pg_temp AS $$BEGIN RETURN now(); END$$")
        # written back exactly: a quoted name and the empty path
        admin("CREATE FUNCTION p0_rpt.p0_user_path(integer) RETURNS timestamptz LANGUAGE sql "
              "SET search_path = \"$user\", public AS $$SELECT now()$$")
        admin("CREATE FUNCTION p0_rpt.p0_empty_path() RETURNS timestamptz LANGUAGE sql "
              "SET search_path = '' AS $$SELECT now()$$")
        # left alone: a gm_* schema's routine, one without its own path
        admin("CREATE FUNCTION gm_p0.pinned() RETURNS timestamptz LANGUAGE sql "
              "SET search_path = pg_catalog AS $$SELECT now()$$")
        admin("CREATE FUNCTION p0_rpt.unpinned() RETURNS timestamptz LANGUAGE sql "
              "SET TimeZone = 'UTC' AS $$SELECT now()$$")
        mine = ("p0_rpt.close_day(text)", "p0_rpt.p0_pinned_public()", "p0_rpt.p0_user_path(integer)",
                "p0_rpt.p0_empty_path()")
        before = {s: self.proconfig(s) for s in (*mine, "gm_p0.pinned()", "p0_rpt.unpinned()")}
        self.assertEqual(before["p0_rpt.close_day(text)"], ["search_path=pg_catalog, pg_temp", "TimeZone=Etc/GMT-2"])
        self.assertEqual(before["p0_rpt.p0_empty_path()"], ['search_path=""'])

        # the signatures qualified: the query runs with pg_catalog alone on its path
        found = rows = self.cover_rows()
        for s in mine:
            self.assertIn(s, found)
            self.assertFalse(found[s]["covered"])
        self.assertNotIn("gm_p0.pinned()", rows)
        self.assertNotIn("p0_rpt.unpinned()", rows)
        close = found["p0_rpt.close_day(text)"]
        self.assertEqual((close["kind"], close["setting"]), ("procedure", "pg_catalog, pg_temp"))
        # the cover's forms by 9.4's rule (spec D530)
        self.assertEqual(close["cover"],
                         "ALTER PROCEDURE p0_rpt.close_day(text) SET search_path = gm_vclock, pg_catalog, pg_temp;")
        self.assertEqual(found["p0_rpt.p0_pinned_public()"]["cover"],
                         "ALTER FUNCTION p0_rpt.p0_pinned_public() SET search_path = public, gm_vclock, "
                         "pg_catalog, pg_temp;")
        self.assertEqual(found["p0_rpt.p0_user_path(integer)"]["cover"],
                         "ALTER FUNCTION p0_rpt.p0_user_path(integer) SET search_path = \"$user\", public, "
                         "gm_vclock, pg_catalog;")
        self.assertEqual(found["p0_rpt.p0_empty_path()"]["cover"],
                         "ALTER FUNCTION p0_rpt.p0_empty_path() SET search_path = '', gm_vclock, pg_catalog;")

        covered = [found[s] for s in mine]
        self.addCleanup(lambda: [admin(r["restore"]) for r in covered])
        for r in covered:
            admin(r["cover"])
        self.assertEqual(self.proconfig("p0_rpt.close_day(text)"),
                         ["search_path=gm_vclock, pg_catalog, pg_temp", "TimeZone=Etc/GMT-2"])
        self.assertEqual(self.proconfig("p0_rpt.p0_pinned_public()"),
                         ["search_path=public, gm_vclock, pg_catalog, pg_temp"])
        self.assertEqual(self.proconfig("p0_rpt.p0_empty_path()"), ['search_path="", gm_vclock, pg_catalog'])
        self.assertTrue(all(r["covered"] for s, r in self.cover_rows().items() if s.startswith("p0_rpt.")))

        # a fill session reads the virtual clock through them
        vt = ts("2025-06-01T08:00:00Z")
        virtual = datetime.datetime.fromtimestamp(vt, UTC)
        conn = connect(HOST, PORT, DB, ROLE, PASSWORD, "p0")
        self.addCleanup(conn.close)
        set_clock(conn, vt)
        conn.execute("CALL p0_rpt.close_day('fill')")
        self.assertEqual(conn.execute("SELECT p0_rpt.p0_pinned_public()").fetchone()[0], virtual)
        self.assertEqual(conn.execute("SELECT p0_rpt.p0_user_path(1)").fetchone()[0], virtual)
        self.assertEqual(conn.execute("SELECT p0_rpt.p0_empty_path()").fetchone()[0], virtual)
        # a session without gm.vclock reads the real clock through the same routines
        with psycopg.connect(host=HOST, port=PORT, dbname=DB, user=ROLE, password=PASSWORD,
                             autocommit=True) as real:
            real.execute("CALL p0_rpt.close_day('real')")
            real_now = real.execute("SELECT p0_rpt.p0_pinned_public()").fetchone()[0]
            self.assertLess(abs((real_now - datetime.datetime.now(UTC)).total_seconds()), 60)
        closes = dict((by, (at, zone)) for by, at, zone in admin("SELECT by, at, zone FROM p0_rpt.closes"))
        self.assertEqual(closes["fill"], (virtual, "Etc/GMT-2"))       # its TimeZone untouched
        self.assertLess(abs((closes["real"][0] - datetime.datetime.now(UTC)).total_seconds()), 60)

        # restored exactly: entries and order; again, nothing changes; a routine gone counts as restored
        for r in covered:
            admin(r["restore"])
            admin(r["restore"])
        after = {s: self.proconfig(s) for s in before}
        self.assertEqual(after, before)
        admin("DROP FUNCTION p0_rpt.p0_empty_path()")
        admin(found["p0_rpt.p0_empty_path()"]["restore"])
        self.assertEqual(self.proconfig("p0_rpt.p0_empty_path()"), "gone")

    def test_the_checked_drop(self):
        from gm_scheduler.fill import VCLOCK_DROP, VCLOCK_SQL
        import psycopg
        admin("DROP TABLE IF EXISTS p0_bound")
        admin("CREATE TABLE p0_bound (id int, at timestamptz DEFAULT gm_vclock.now())")
        self.addCleanup(admin, "DROP TABLE IF EXISTS p0_bound")
        with self.assertRaises(psycopg.Error) as caught:
            admin(VCLOCK_DROP)
        self.assertIn("gm_vclock not dropped: default value for column at of table p0_bound depend(s) on its "
                      "functions", str(caught.exception))
        self.assertTrue(admin("SELECT to_regnamespace('gm_vclock') IS NOT NULL")[0][0])
        self.assertEqual(admin("SELECT count(*) FROM p0_bound"), [(0,)])
        admin("DROP TABLE p0_bound")
        # an object inside gm_vclock other than its four functions (spec D530)
        admin("CREATE TABLE gm_vclock.p0_inside (id int)")
        self.addCleanup(admin, "DROP TABLE IF EXISTS gm_vclock.p0_inside")
        with self.assertRaises(psycopg.Error) as caught:
            admin(VCLOCK_DROP)
        self.assertIn("gm_vclock not dropped: table gm_vclock.p0_inside inside it", str(caught.exception))
        self.assertEqual(admin("SELECT count(*) FROM gm_vclock.p0_inside"), [(0,)])
        admin("DROP TABLE gm_vclock.p0_inside")
        admin(VCLOCK_DROP)
        self.assertFalse(admin("SELECT to_regnamespace('gm_vclock') IS NOT NULL")[0][0])
        admin(VCLOCK_DROP)                  # without the schema: nothing to do
        admin(VCLOCK_SQL)                   # back for the class's other tests


class FakeCursor:
    description, rowcount = None, 1

    def fetchall(self):
        return []


class FakeSession:
    """A session's statements, one of them failing."""

    def __init__(self, failing=None):
        self.sent, self.failing = [], failing
        self.closed = self.broken = False

    def execute(self, sql, params=None):
        import psycopg
        self.sent.append(sql)
        if self.failing and self.failing in sql:
            raise psycopg.errors.UndefinedFunction("function gm_missing_function() does not exist")
        return FakeCursor()


class TestTransactionCount(unittest.TestCase):
    """FILL_TRANSACTIONS' count of a plan (master spec 9.9 fix 12, spec
    D594): one per transaction plan, else one per step; the clock's setting
    not counted."""

    def run_plan(self, steps, txn=None, failing=None):
        from gm_scheduler.fill import run_steps
        from gm_scheduler.repository import Plan, Txn
        sess = FakeSession(failing)
        plan = Plan([(sql, None) for sql in steps], Txn(txn, 0) if txn else None)
        _, err, xacts = run_steps(sess, plan, ts(VT0))
        return sess, err, xacts

    def test_one_per_transaction_plan(self):
        sess, err, xacts = self.run_plan(["INSERT INTO a VALUES (1)", "UPDATE b SET c = 1"], txn="read committed")
        self.assertIsNone(err)
        self.assertEqual(xacts, 1)
        self.assertEqual(sess.sent[0], "SELECT pg_catalog.set_config(%s, %s, false)")   # the clock: sent, not counted
        self.assertEqual(len(sess.sent), 4)

    def test_one_per_step_otherwise(self):
        sess, err, xacts = self.run_plan(["SELECT 1", "SELECT 2", "SELECT 3"])
        self.assertIsNone(err)
        self.assertEqual(xacts, 3)
        self.assertEqual(len(sess.sent), 4)

    def test_a_failed_step_counts_the_steps_sent(self):
        _, err, xacts = self.run_plan(["SELECT 1", "SELECT gm_missing_function()", "SELECT 3"],
                                      failing="gm_missing_function")
        self.assertEqual(err[0], "42883")
        self.assertEqual(xacts, 2)                  # the failed one rolled back by the server
        _, err, xacts = self.run_plan(["SELECT gm_missing_function()", "SELECT 3"], txn="read committed",
                                      failing="gm_missing_function")
        self.assertEqual(xacts, 1)

    def test_a_scripts_transactions_as_it_ends_them(self):
        from gm_scheduler.fill import VConnection
        conn = psycopg_stub()
        vc = VConnection(conn, ts(VT0))
        vc.commit()                                 # nothing open: nothing counted
        conn.status = "INTRANS"
        vc.commit()
        conn.status = "INERROR"
        vc.rollback()
        conn.status = "INTRANS"
        vc.close()                                  # left open: the server rolls it back
        self.assertEqual(vc.gm_transactions, 3)
        self.assertEqual(conn.calls, ["commit", "commit", "rollback", "close"])


def psycopg_stub():
    from psycopg.pq import TransactionStatus

    class Info:
        def __init__(self, owner):
            self.owner = owner

        @property
        def transaction_status(self):
            return getattr(TransactionStatus, self.owner.status)

    class Conn:
        closed = False

        def __init__(self):
            self.status, self.calls = "IDLE", []
            self.info = Info(self)

        def commit(self):
            self.calls.append("commit")
            self.status = "IDLE"

        def rollback(self):
            self.calls.append("rollback")
            self.status = "IDLE"

        def close(self):
            self.calls.append("close")
    return Conn()


class TestFillSql(unittest.TestCase):
    def test_fill_sql_prints_the_programs_sql(self):
        import contextlib
        from gm_scheduler.__main__ import main
        from gm_scheduler.fill import COVER_SQL, VCLOCK_DROP, VCLOCK_SQL
        for argv, sql in ((["fill-sql"], VCLOCK_SQL), (["fill-sql", "--drop"], VCLOCK_DROP),
                          (["fill-sql", "--cover"], COVER_SQL)):
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                self.assertEqual(main(argv), 0)
            self.assertEqual(out.getvalue(), sql)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            main(["fill-sql", "--drop", "--cover"])


@needs_pg
class TestFillRun(unittest.TestCase):
    """The fill on two nodes against the throwaway PostgreSQL."""

    def setUp(self):
        from gm_scheduler.fill import VCLOCK_DROP, VCLOCK_SQL
        for db in (DB, DST_DB):
            admin(VCLOCK_DROP, db=db)
            admin(VCLOCK_SQL, db=db)
        admin("DROP TABLE IF EXISTS f_orders, f_customers, f_products, f_marks")
        admin("CREATE TABLE f_orders (id serial, customer int, placed_at timestamptz, day date)")
        admin("CREATE TABLE f_customers (id int PRIMARY KEY, last_order_at timestamptz, lifetime_value int "
              "DEFAULT 0)")
        admin("INSERT INTO f_customers (id) SELECT generate_series(1, 50)")
        admin("CREATE TABLE f_products (sku text)")
        admin("INSERT INTO f_products VALUES ('TB-00001'), ('XX-1')")
        admin("CREATE TABLE f_marks (at timestamptz, fn_at timestamptz, clock_at timestamptz)")
        admin("CREATE OR REPLACE FUNCTION f_server_now() RETURNS timestamptz LANGUAGE plpgsql "
              "AS $$BEGIN RETURN now(); END$$")
        admin(f"GRANT ALL ON f_orders, f_customers, f_products, f_marks TO {ROLE}, {SRC_ROLE}")
        admin(f"GRANT USAGE ON SEQUENCE f_orders_id_seq TO {ROLE}")
        admin("DROP TABLE IF EXISTS f_rollups", db=DST_DB)
        admin("CREATE TABLE f_rollups (at timestamptz, orders int, clock_at timestamptz)", db=DST_DB)
        admin(f"GRANT ALL ON f_rollups TO {DST_ROLE}", db=DST_DB)
        admin(f"GRANT USAGE, CREATE ON SCHEMA public TO {DST_ROLE}", db=DST_DB)
        self.root = tempfile.mkdtemp(prefix="gm-fill-test-")
        self.addCleanup(shutil.rmtree, self.root, True)

    def tearDown(self):
        from gm_scheduler.fill import VCLOCK_DROP
        for db in (DB, DST_DB):
            admin(VCLOCK_DROP, db=db)

    def config(self):
        r = self.root
        write(f"{r}/producer/repository/queries.yaml", QUERIES)
        write(f"{r}/producer/jobs/jobs.yaml",
              "jobs:\n  - name: close-day\n    key: orders.close-day\n    connection: app\n    at: \"*/10 * * * *\"\n"
              "  - name: mark\n    key: orders.mark\n    connection: app\n    at: \"5 21 * * *\"\n"
              "  - name: touch\n    key: orders.touch\n    connection: app\n    at: \"15 21 * * *\"\n")
        write(f"{r}/consumer/repository/queries.yaml",
              QUERIES + "  rollup.hourly:\n    script: scripts/rollup.py:hourly\n")
        write(f"{r}/consumer/repository/scripts/rollup.py", SCRIPT)
        write(f"{r}/consumer/jobs/jobs.yaml",
              "jobs:\n  - name: rollup\n    key: rollup.hourly\n    connections: {source: shop, target: reporting}\n"
              "    at: \"20 21 * * *\"\n")
        target = f"{HOST}:{PORT}"
        producer = {"seed": 99, "intensity": 1.0,
                    "connections": {"app": {"driver": "sql/postgresql", "target": f"pooler:6432/{DB}", "role": ROLE,
                                            "pool": {"size": 4}}},
                    "streams": [{"key": "orders.place", "connection": "app", "rate": "6/min", "arrivals": "poisson",
                                 "concurrency": 4},
                                {"key": "catalog.lookup", "connection": "app", "rate": "20/min",
                                 "arrivals": "poisson", "shape": "flat", "concurrency": 2},
                                {"key": "catalog.broken", "connection": "app", "rate": "1/min", "arrivals": "even"}],
                    "shapes": {"flat": SHAPE},
                    "timeline": [{"at": "2026-03-02T21:20:00Z", "stream": "catalog.broken",
                                  "set": {"key": "catalog.lookup"}}]}
        consumer = {"seed": 99, "intensity": 1.0,
                    "connections": {
                        "reports": {"driver": "sql/postgresql", "target": f"{target}/{DB}", "role": ROLE,
                                    "pool": {"size": 2}},
                        "shop": {"driver": "sql/postgresql", "target": f"{target}/{DB}", "role": SRC_ROLE,
                                 "pool": {"size": 1}},
                        "reporting": {"driver": "sql/postgresql", "target": f"{target}/{DST_DB}", "role": DST_ROLE,
                                      "pool": {"size": 1}}},
                    "streams": [{"key": "reports.dashboard", "connection": "reports", "rate": "6/h",
                                 "arrivals": "even"}],
                    "timeline": []}
        st = {k: {"median": 0.002, "sigma": 0.2} for k in ("orders.place", "catalog.lookup", "catalog.broken",
                                                           "orders.close-day", "orders.mark", "orders.touch")}
        return {
            "vt0": VT0, "anchor": ANCHOR, "seed": 7, "pauses": [PAUSE],
            "nodes": {
                "producer": {"hostname": "producer", "input": node_input(producer, {ROLE: PASSWORD}),
                             "repository": f"{r}/producer/repository", "jobs": f"{r}/producer/jobs/jobs.yaml",
                             "log": f"{r}/out/producer.log", "metrics": f"{r}/out/producer.metrics.jsonl",
                             "sequences": f"{r}/out/producer.sequences.json",
                             "connections": {"app": {"target": target, "pool": {"id": "pooler/shop/app", "size": 3}}}},
                "consumer": {"hostname": "consumer",
                             "input": node_input(consumer, {ROLE: PASSWORD, SRC_ROLE: SRC_PASSWORD,
                                                            DST_ROLE: DST_PASSWORD}),
                             "repository": f"{r}/consumer/repository", "jobs": f"{r}/consumer/jobs/jobs.yaml",
                             "log": f"{r}/out/consumer.log", "metrics": f"{r}/out/consumer.metrics.jsonl"}},
            "service_times": {"producer": st,
                              "consumer": {"reports.dashboard": {"median": 0.05, "sigma": 0.3},
                                           "rollup.hourly": {"median": 0.06, "sigma": 0.2}}},
            "queue": [{"instance": "f8", "node": "producer", "key": "catalog.lookup", "planted_at": PAUSE,
                       "service": {"median": 0.4, "sigma": 0.0}}],
            "visits": [{"name": "exporter", "target": f"{HOST}:{PORT}/{DB}", "role": ROLE, "password": PASSWORD,
                        "every": 15, "sql": ["SELECT count(*) FROM pg_stat_database"]}],
        }

    def run_fill(self, doc, answer="GO\n"):
        from gm_scheduler import fill
        out = io.StringIO()
        rc = fill.main(io.StringIO(json.dumps(doc) + "\n" + answer), out)
        return rc, out.getvalue().splitlines()

    def test_a_fill_runs_both_nodes_on_one_virtual_clock(self):
        from gm_scheduler.textlog import parse_line
        rc, out = self.run_fill(self.config())
        self.assertEqual(rc, 0, out)
        self.assertEqual(out[0], f"PAUSE {PAUSE}")
        done = json.loads(out[-1][len("DONE "):])
        self.assertEqual(done["pauses"], [PAUSE])
        self.assertGreater(done["visits"]["sessions"], 100)
        # the rows sit at their virtual instants, the server-side function's included
        lo, hi = admin("SELECT min(placed_at), max(placed_at), count(*), "
                       "count(*) FILTER (WHERE day = DATE '2026-03-02') FROM f_orders")[0][:2]
        self.assertGreaterEqual(lo, datetime.datetime(2026, 3, 2, 21, 0, tzinfo=UTC))
        self.assertLess(hi, datetime.datetime(2026, 3, 2, 21, 30, tzinfo=UTC))
        mark = admin("SELECT at, fn_at, clock_at FROM f_marks")
        self.assertEqual(len(mark), 1)
        for v in mark[0]:
            self.assertLess(abs((v - datetime.datetime(2026, 3, 2, 21, 5, tzinfo=UTC)).total_seconds()), 5)
        rollup = admin("SELECT at, orders, clock_at FROM f_rollups", db=DST_DB)
        self.assertEqual(rollup[0][0], datetime.datetime(2026, 3, 2, 21, 20, tzinfo=UTC))
        self.assertLess(abs((rollup[0][2] - rollup[0][0]).total_seconds()), 5)
        # the logs: virtual times, in order, the restart first, no reload
        with open(f"{self.root}/out/producer.log") as f:
            lines = f.read().splitlines()
        events = [parse_line(x) for x in lines]
        self.assertTrue(all(e is not None for e in events))
        self.assertEqual([e[0] for e in events], sorted(e[0] for e in events))
        self.assertEqual(lines[0], f"{VT0} state state=stopping")
        self.assertEqual(lines[1], f"2026-03-02T21:00:01Z state state=running t0={VT0}")
        self.assertFalse(any(e[1] == "reload" for e in events))
        self.assertTrue(all(VT0 <= e[0] < ANCHOR for e in events))
        errors = [e for e in events if e[1] == "error"]
        self.assertTrue(errors and all(e[2]["key"] == "catalog.broken" for e in errors))
        self.assertTrue(all(e[0] < "2026-03-02T21:20:01Z" for e in errors))
        runs = [e for e in events if e[1] == "run" and e[2]["job"] == "close-day" and e[2]["phase"] == "end"]
        self.assertEqual(len(runs), 2)                         # 21:00 is before the start; 21:10, 21:20
        self.assertTrue(all(20000 < float(e[2]["ms"]) < 20100 for e in runs))
        summaries = [e for e in events if e[1] == "summary"]
        self.assertEqual(summaries[0][2]["minute"], "2026-03-02T21:00Z")
        self.assertEqual(summaries[-1][2]["minute"], "2026-03-02T21:28Z")
        keys = [e for e in events if e[1] == "key" and e[2]["key"] == "catalog.lookup" and e[2]["calls"] != "0"]
        before = [float(e[2]["p50_ms"]) for e in keys if e[2]["minute"] < "2026-03-02T21:11Z"]
        after = [float(e[2]["p50_ms"]) for e in keys if e[2]["minute"] > "2026-03-02T21:13Z"]
        self.assertTrue(before and max(before) < 100, before)    # the queue model's, f8's from its planting
        self.assertTrue(after and min(after) > 300, after)
        with open(f"{self.root}/out/consumer.log") as f:
            consumer = f.read()
        self.assertIn("script job=rollup rolled up", consumer)
        self.assertIn("run job=rollup key=rollup.hourly phase=end status=ok rows=1", consumer)
        # the metrics record: one object a minute, cumulative, the log's calls
        with open(f"{self.root}/out/producer.metrics.jsonl") as f:
            record = [json.loads(x) for x in f]
        self.assertEqual(len(record), 30)
        self.assertEqual(record[0]["at"], "2026-03-02T21:01:00Z")
        self.assertEqual(sorted(record[0]), sorted(("at", "scheduler_calls_total", "scheduler_errors_total",
                                                    "scheduler_call_duration_seconds", "scheduler_job_runs_total",
                                                    "scheduler_job_skips_total", "fill_transactions")))
        calls = [r["scheduler_calls_total"]["catalog.lookup"] for r in record]
        self.assertEqual(calls, sorted(calls))
        logged = sum(int(e[2]["calls"]) for e in events if e[1] == "key" and e[2]["key"] == "catalog.lookup")
        self.assertEqual(record[28]["scheduler_calls_total"]["catalog.lookup"], logged)
        hist = record[-1]["scheduler_call_duration_seconds"]["catalog.lookup"]
        self.assertEqual(hist["buckets"]["60.0"], hist["count"])
        self.assertEqual(record[-1]["scheduler_job_runs_total"],
                         [{"job": "close-day", "key": "orders.close-day", "value": 2},
                          {"job": "mark", "key": "orders.mark", "value": 1},
                          {"job": "touch", "key": "orders.touch", "value": 1}])
        # the transactions per database (master spec 9.9 fix 12): cumulative,
        # each call's plan one (a transaction plan, or a single step), the
        # two-step touch two; the clock's setting, the set-up and the
        # exporter's visits not counted
        shop, reporting = f"{HOST}:{PORT}/{DB}", f"{HOST}:{PORT}/{DST_DB}"
        xacts = [r["fill_transactions"].get(shop, 0) for r in record]
        self.assertEqual(xacts, sorted(xacts))
        self.assertEqual(sorted(record[-1]["fill_transactions"]), [shop])
        self.assertEqual(record[-1]["fill_transactions"][shop],
                         sum(record[-1]["scheduler_calls_total"].values()) + 1)
        with open(f"{self.root}/out/consumer.metrics.jsonl") as f:
            consumer = [json.loads(x) for x in f][-1]
        # the dashboard's held snapshots one each; the script's two, one per database
        self.assertEqual(consumer["fill_transactions"],
                         {shop: consumer["scheduler_calls_total"]["reports.dashboard"] + 1, reporting: 1})

    def test_a_key_without_a_service_time_is_refused(self):
        doc = self.config()
        del doc["service_times"]["producer"]["catalog.lookup"]
        rc, out = self.run_fill(doc)
        self.assertEqual(rc, 1)
        self.assertEqual(out, ["FAILED node producer: no service time for catalog.lookup"])

    def test_a_fill_stopped_at_its_pause_fails(self):
        rc, out = self.run_fill(self.config(), answer="")
        self.assertEqual(rc, 1)
        self.assertEqual(out[-1], f"FAILED stopped at the pause at {PAUSE}: end of input")


if __name__ == "__main__":
    unittest.main()
