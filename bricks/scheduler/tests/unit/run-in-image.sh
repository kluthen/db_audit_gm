#!/bin/sh
# Runs the scheduler program's unit tests inside the image's `unit-test`
# stage (tests/run-unit-tests.sh builds and starts it): a throwaway
# PostgreSQL in this container (Debian's, port 5432 on 127.0.0.1, its data
# under /tmp), the roles the tests use, then every test_*.py here against
# the program installed in the image (python3 -I: dist-packages only).
set -eu

PGBIN=$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -n 1)
PGDATA=/tmp/pgdata
export GM_TEST_PG_HOST=127.0.0.1 GM_TEST_PG_PORT=5432 GM_TEST_PG_DB=shop GM_TEST_PG_ROLE=shop_app
GM_TEST_PG_PASSWORD=$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
GM_TEST_PG_ADMIN=gm_test_admin
GM_TEST_PG_ADMIN_PASSWORD=$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
export GM_TEST_PG_PASSWORD GM_TEST_PG_ADMIN GM_TEST_PG_ADMIN_PASSWORD

install -d -o postgres -g postgres -m 0700 "$PGDATA"
runuser -u postgres -- "$PGBIN/initdb" -D "$PGDATA" -A scram-sha-256 --auth-local=peer -U postgres -E UTF8 --locale=C.UTF-8 \
    --no-sync >/dev/null
runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -w -l /tmp/pg.log -o \
    "-c listen_addresses=127.0.0.1 -c port=5432 -c unix_socket_directories=/tmp -c shared_buffers=16MB -c max_connections=30 -c fsync=off" \
    start >/dev/null
trap 'runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -m immediate stop >/dev/null 2>&1 || true' EXIT

runuser -u postgres -- "$PGBIN/psql" -X -q -h /tmp -d postgres -v ON_ERROR_STOP=1 \
    -v app="$GM_TEST_PG_PASSWORD" -v adm="$GM_TEST_PG_ADMIN_PASSWORD" <<'SQL'
CREATE ROLE shop_app LOGIN PASSWORD :'app';
CREATE ROLE gm_test_admin LOGIN SUPERUSER PASSWORD :'adm';
CREATE DATABASE shop OWNER gm_test_admin;
\c shop
GRANT CREATE, USAGE ON SCHEMA public TO shop_app;
SQL
echo "unit tests: PostgreSQL $("$PGBIN/postgres" --version | awk '{print $3}'), psycopg $(python3 -I -c 'import psycopg; print(psycopg.__version__)'), Python $(python3 -I -c 'import sys; print(sys.version.split()[0])')"

cd /opt/gm-test/unit
exec python3 -I -c 'import sys, unittest
sys.path.insert(0, "/opt/gm-test/unit")
r = unittest.main(module=None, argv=["unittest", "discover", "-s", "/opt/gm-test/unit", "-t", "/opt/gm-test/unit", "-v"], exit=False).result
sys.exit(0 if r.wasSuccessful() and not r.skipped else 1)'
