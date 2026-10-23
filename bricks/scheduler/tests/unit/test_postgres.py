"""The `sql/postgresql` driver, the pools and transactions, against the
throwaway PostgreSQL (run-in-image.sh)."""

import asyncio
import time
import unittest

from pgtest import DB, PASSWORD, admin, connection, needs_pg


@needs_pg
class TestDriver(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        admin("DROP TABLE IF EXISTS drv")
        admin("CREATE TABLE drv (id int PRIMARY KEY, name text)")
        admin("GRANT ALL ON drv TO shop_app")

    def run_async(self, coro):
        return asyncio.run(coro)

    def test_connect_run_and_close(self):
        from gm_scheduler.drivers import get_driver

        async def go():
            s = await get_driver("sql/postgresql").connect(connection(), PASSWORD, "unit-test")
            r1 = await s.execute("INSERT INTO drv VALUES (%(id)s, %(name)s), (%(id)s + 1, 'x')",
                                 {"id": 1, "name": "lamp"})
            r2 = await s.execute("SELECT * FROM drv WHERE name LIKE '%amp%'", None)
            r3 = await s.execute("SELECT current_setting('application_name')", {})
            await s.close()
            return r1, r2, r3
        r1, r2, r3 = self.run_async(go())
        self.assertEqual((r1.rows, r2.rows, r3.rows), (2, 1, 1))
        self.assertGreater(r1.latency, 0)

    def test_errors_carry_the_sqlstate_and_the_session_survives(self):
        from gm_scheduler.drivers import DriverError, get_driver

        async def go():
            s = await get_driver("sql/postgresql").connect(connection(), PASSWORD, "unit-test")
            codes = []
            for sql in ("SELEC 1", "SELECT 1/0", "SELECT * FROM no_such_table"):
                try:
                    await s.execute(sql, None)
                except DriverError as exc:
                    codes.append((exc.code, exc.connect, exc.lost, bool(exc.message)))
            ok = await s.execute("SELECT 1", None)
            await s.close()
            return codes, ok.rows
        codes, rows = self.run_async(go())
        self.assertEqual(codes, [("42601", False, False, True), ("22012", False, False, True),
                                 ("42P01", False, False, True)])
        self.assertEqual(rows, 1)

    def test_connection_failures(self):
        from gm_scheduler.drivers import DriverError, get_driver

        async def go(conn, password):
            try:
                await get_driver("sql/postgresql").connect(conn, password, "unit-test")
            except DriverError as exc:
                return exc
        refused = self.run_async(go(connection(port=1), PASSWORD))
        self.assertTrue(refused.connect)
        self.assertTrue(refused.code.startswith("08"), refused.code)
        wrong = self.run_async(go(connection(), "wrong-password"))
        self.assertTrue(wrong.connect)
        self.assertEqual(wrong.code, "28P01")
        # connections exhausted ("too many clients" shows as 53300, as the server says)
        admin("DROP ROLE IF EXISTS limited_app")
        admin("CREATE ROLE limited_app LOGIN CONNECTION LIMIT 1 PASSWORD 'limited-pw'")
        import psycopg
        from pgtest import DB, HOST, PORT
        with psycopg.connect(host=HOST, port=PORT, dbname=DB, user="limited_app", password="limited-pw"):
            full = self.run_async(go(connection(role="limited_app"), "limited-pw"))
        self.assertEqual((full.code, full.connect), ("53300", True), full.message)
        self.assertIn("too many connections", full.message)

    def test_transactions_isolation_commit_rollback(self):
        from gm_scheduler.drivers import DriverError, get_driver

        async def go():
            s = await get_driver("sql/postgresql").connect(connection(), PASSWORD, "unit-test")
            await s.begin("serializable")
            level = await s.execute("SHOW transaction_isolation", None)
            await s.execute("INSERT INTO drv VALUES (100, 'kept')", None)
            await s.commit()
            await s.begin("repeatable read")
            await s.execute("INSERT INTO drv VALUES (101, 'undone')", None)
            await s.rollback()
            await s.begin("read committed")
            try:
                await s.execute("INSERT INTO drv VALUES (100, 'duplicate')", None)
            except DriverError as exc:
                dup = exc.code
            await s.rollback()
            await s.close()
            return level, dup
        level, dup = self.run_async(go())
        self.assertEqual(dup, "23505")
        self.assertEqual(admin("SELECT name FROM drv WHERE id IN (100, 101) ORDER BY id"), [("kept",)])

    def test_a_held_transaction_is_idle_in_transaction(self):
        from gm_scheduler.pools import Pool
        from gm_scheduler.repository import Plan, Txn
        from gm_scheduler.runner import run_plan

        async def go():
            pool = Pool(connection(), PASSWORD, "unit-hold")
            plan = Plan([("SELECT 1", None)], Txn("read committed", 2))

            async def call():
                async with pool.session() as s:
                    return await run_plan(s, plan)
            start = time.monotonic()
            task = asyncio.ensure_future(call())
            await asyncio.sleep(1.0)
            states = await asyncio.to_thread(admin, "SELECT state FROM pg_stat_activity "
                                                    "WHERE application_name = 'unit-hold'")
            await task
            await pool.close_all()
            return states, time.monotonic() - start
        states, elapsed = self.run_async(go())
        self.assertEqual(states, [("idle in transaction",)])
        self.assertGreaterEqual(elapsed, 2.0)


@needs_pg
class TestPools(unittest.TestCase):
    def sessions(self, name):
        return admin("SELECT count(*) FROM pg_stat_activity WHERE application_name = %s", (name,))[0][0]

    def test_a_pool_of_one_serves_concurrent_calls_on_one_session(self):
        from gm_scheduler.pools import Pool

        async def go():
            pool = Pool(connection(size=1), PASSWORD, "unit-pool1")
            seen = []

            async def call():
                async with pool.session() as s:
                    await s.execute("SELECT pg_sleep(0.3)", None)
                    seen.append(await asyncio.to_thread(self.sessions, "unit-pool1"))
            start = time.monotonic()
            await asyncio.gather(*(call() for _ in range(3)))
            elapsed = time.monotonic() - start
            kept = await asyncio.to_thread(self.sessions, "unit-pool1")
            await pool.close_all()
            return seen, elapsed, kept
        seen, elapsed, kept = asyncio.run(go())
        self.assertEqual(seen, [1, 1, 1])
        self.assertGreaterEqual(elapsed, 0.9)       # one at a time
        self.assertEqual(kept, 1)                   # kept open after the calls

    def test_per_call_opens_and_closes(self):
        from gm_scheduler.pools import Pool

        async def go():
            pool = Pool(connection(per_call=True), PASSWORD, "unit-percall")
            pids = []
            for _ in range(3):
                async with pool.session() as s:
                    await s.execute("SELECT 1", None)
                    pids.append(s.conn.info.backend_pid)
            await asyncio.sleep(0.3)
            return pids, await asyncio.to_thread(self.sessions, "unit-percall")
        pids, left = asyncio.run(go())
        self.assertEqual(len(set(pids)), 3)
        self.assertEqual(left, 0)

    def test_a_broken_session_is_replaced(self):
        from gm_scheduler.drivers import DriverError
        from gm_scheduler.pools import Pool

        async def go():
            pool = Pool(connection(size=1), PASSWORD, "unit-broken")
            async with pool.session() as s:
                await s.execute("SELECT 1", None)
                first = s.conn.info.backend_pid
            await asyncio.to_thread(admin, "SELECT pg_terminate_backend(%s)", (first,))
            await asyncio.sleep(0.3)
            lost = None
            try:
                async with pool.session() as s:
                    await s.execute("SELECT 1", None)
            except DriverError as exc:
                lost = exc
            async with pool.session() as s:
                await s.execute("SELECT 1", None)
                second = s.conn.info.backend_pid
            await pool.close_all()
            return first, second, lost
        first, second, lost = asyncio.run(go())
        self.assertNotEqual(first, second)
        self.assertIsNotNone(lost)
        self.assertTrue(lost.lost)


if __name__ == "__main__":
    unittest.main()
