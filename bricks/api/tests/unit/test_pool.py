"""gm_api.connection: the pooled sessions, as the application role, against
the throwaway PostgreSQL."""

import threading
import time
import unittest

import psycopg

import gm_api
from gm_api import Unavailable, app, pool

from apitest import PG, standard_node


class TestConnection(unittest.TestCase):

    def setUp(self):
        self.node = standard_node()
        app.build()

    def tearDown(self):
        self.node.close()

    def test_as_the_role_autocommit_off(self):
        with gm_api.connection("lab") as conn:
            self.assertEqual(conn.execute("SELECT current_user").fetchone()[0], PG["role"])
            self.assertFalse(conn.autocommit)
            self.assertEqual(conn.info.parameter_status("application_name"),
                             __import__("socket").gethostname())

    def test_uncommitted_work_is_rolled_back_on_leaving(self):
        with gm_api.connection("lab") as conn:
            conn.execute("INSERT INTO orders VALUES (900, 'never')")
        with gm_api.connection("lab") as conn:
            self.assertIsNone(conn.execute("SELECT 1 FROM orders WHERE id = 900").fetchone())
        with self.assertRaises(psycopg.errors.UniqueViolation):
            with gm_api.connection("lab") as conn:
                conn.execute("INSERT INTO orders VALUES (1, 'clash')")
        with gm_api.connection("lab") as conn:                    # the failed session came back clean
            self.assertEqual(conn.execute("SELECT count(*) FROM orders WHERE id = 1").fetchone()[0], 1)

    def test_session_settings_applied_and_reset(self):
        with gm_api.connection("lab", session={"work_mem": "8MB", "application_name": "x"}) as conn:
            self.assertEqual(conn.execute("SHOW work_mem").fetchone()[0], "8MB")
        with gm_api.connection("lab", session={"work_mem": "8MB", "application_name": "x"}) as conn:
            self.assertEqual(conn.execute("SHOW work_mem").fetchone()[0], "8MB")
        with gm_api.connection("lab") as conn:
            self.assertEqual(conn.execute("SHOW work_mem").fetchone()[0], "4MB")      # reset
            self.assertNotEqual(conn.execute("SHOW application_name").fetchone()[0], "x")

    def test_the_pool_size_holds_and_waits_are_bounded(self):
        old = pool.WAIT
        pool.WAIT = 0.5
        try:
            pids = set()
            with gm_api.connection("lab") as a, gm_api.connection("lab") as b:
                pids = {a.info.backend_pid, b.info.backend_pid}
                t0 = time.monotonic()
                with self.assertRaises(Unavailable):
                    with gm_api.connection("lab"):
                        pass
                self.assertLess(time.monotonic() - t0, 2)
            with gm_api.connection("lab") as c:
                self.assertIn(c.info.backend_pid, pids)               # kept and reused
        finally:
            pool.WAIT = old

    def test_a_broken_session_is_replaced(self):
        with gm_api.connection("lab") as conn:
            pid = conn.info.backend_pid                       # now idle in the pool
        with psycopg.connect(host=PG["host"], port=PG["port"], dbname=PG["db"], user=PG["role"],
                             password=PG["password"], autocommit=True) as killer:
            killer.execute("SELECT pg_terminate_backend(%s)", (pid,))
        time.sleep(0.2)
        with self.assertRaises(psycopg.OperationalError):     # found broken on first use: 503
            with gm_api.connection("lab") as conn:
                conn.execute("SELECT 1")
        with gm_api.connection("lab") as conn:                # then replaced
            self.assertEqual(conn.execute("SELECT 1").fetchone()[0], 1)
            self.assertNotEqual(conn.info.backend_pid, pid)

    def test_threads_share_the_pool(self):
        results = []

        def work():
            with gm_api.connection("lab") as conn:
                results.append(conn.execute("SELECT pg_sleep(0.1), 1").fetchone()[1])
        threads = [threading.Thread(target=work) for _ in range(6)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(results, [1] * 6)
        self.assertLessEqual(len(pool._pools["lab"]._idle), 2)

    def test_an_unknown_connection(self):
        with self.assertRaises(gm_api.ConfigError):
            gm_api.connection("nowhere")


if __name__ == "__main__":
    unittest.main()
