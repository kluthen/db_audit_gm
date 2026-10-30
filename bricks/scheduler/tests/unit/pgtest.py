"""The throwaway PostgreSQL the database tests use (started by
run-in-image.sh): GM_TEST_PG_* name it; without them the tests skip, so
test_parts.py also runs on a host without psycopg."""

import os
import unittest

HOST = os.environ.get("GM_TEST_PG_HOST")
PORT = int(os.environ.get("GM_TEST_PG_PORT", "5432"))
DB = os.environ.get("GM_TEST_PG_DB", "shop")
ROLE = os.environ.get("GM_TEST_PG_ROLE", "shop_app")
PASSWORD = os.environ.get("GM_TEST_PG_PASSWORD", "")
ADMIN = os.environ.get("GM_TEST_PG_ADMIN", "gm_test_admin")
ADMIN_PASSWORD = os.environ.get("GM_TEST_PG_ADMIN_PASSWORD", "")
# a transformer script's two connections (run-in-image.sh)
SRC_ROLE = os.environ.get("GM_TEST_PG_SRC_ROLE", "shop_etl")
SRC_PASSWORD = os.environ.get("GM_TEST_PG_SRC_PASSWORD", "")
DST_DB = os.environ.get("GM_TEST_PG_DST_DB", "reporting")
DST_ROLE = os.environ.get("GM_TEST_PG_DST_ROLE", "bi_etl")
DST_PASSWORD = os.environ.get("GM_TEST_PG_DST_PASSWORD", "")

needs_pg = unittest.skipUnless(HOST, "no throwaway PostgreSQL (GM_TEST_PG_HOST): run tests/run-unit-tests.sh")


def connection(name="app", role=ROLE, port=PORT, size=2, per_call=False):
    from gm_scheduler.schedule import Connection
    return Connection(name, "sql/postgresql", HOST, port, DB, role, None if per_call else size, per_call)


def admin(sql, params=None, db=DB):
    """Runs one statement as the test's superuser in `db`; returns the rows."""
    import psycopg
    with psycopg.connect(host=HOST, port=PORT, dbname=db, user=ADMIN, password=ADMIN_PASSWORD,
                         autocommit=True) as conn:
        cur = conn.execute(sql, params)
        return cur.fetchall() if cur.description else []
