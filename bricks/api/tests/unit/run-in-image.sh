#!/bin/sh
# Runs gm_api's unit tests inside the image's `unit-test` stage
# (tests/run-unit-tests.sh builds and starts it): a throwaway PostgreSQL in
# this container (Debian's, 127.0.0.1:5432, its data under /tmp), an
# application role and a database, then every test_*.py here against the
# library installed in the image (python3 -I: dist-packages only).
set -eu

PGBIN=$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -n 1)
PGDATA=/tmp/pgdata
export GM_TEST_PG_HOST=127.0.0.1 GM_TEST_PG_PORT=5432 GM_TEST_PG_DB=lab GM_TEST_PG_ROLE=lab_api
GM_TEST_PG_PASSWORD=$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')
export GM_TEST_PG_PASSWORD

install -d -o postgres -g postgres -m 0700 "$PGDATA"
runuser -u postgres -- "$PGBIN/initdb" -D "$PGDATA" -A scram-sha-256 --auth-local=peer -U postgres -E UTF8 --locale=C.UTF-8 \
    --no-sync >/dev/null
runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -w -l /tmp/pg.log -o \
    "-c listen_addresses=127.0.0.1 -c port=5432 -c unix_socket_directories=/tmp -c shared_buffers=16MB -c max_connections=30 -c fsync=off" \
    start >/dev/null
trap 'runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -m immediate stop >/dev/null 2>&1 || true' EXIT

runuser -u postgres -- psql -X -q -h /tmp -d postgres -v ON_ERROR_STOP=1 -v app="$GM_TEST_PG_PASSWORD" <<'SQL'
CREATE ROLE lab_api LOGIN PASSWORD :'app';
CREATE DATABASE lab;
\c lab
CREATE TABLE orders (id int PRIMARY KEY, label text NOT NULL);
INSERT INTO orders VALUES (1, 'first'), (2, 'second');
GRANT SELECT, INSERT, UPDATE ON orders TO lab_api;
CREATE TABLE audit (who text, owner text);
CREATE FUNCTION record_owner() RETURNS text LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$ INSERT INTO audit VALUES (session_user, current_setting('portal.owner_id', true)) RETURNING current_user::text $$;
REVOKE ALL ON FUNCTION record_owner() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION record_owner() TO lab_api;
SQL
echo "unit tests: PostgreSQL $("$PGBIN/postgres" --version | awk '{print $3}'), psycopg $(python3 -I -c 'import psycopg; print(psycopg.__version__)'), Python $(python3 -I -c 'import sys; print(sys.version.split()[0])')"

cd /opt/gm-test/unit
exec python3 -I -c 'import sys, unittest
sys.path.insert(0, "/opt/gm-test/unit")
r = unittest.main(module=None, argv=["unittest", "discover", "-s", "/opt/gm-test/unit", "-t", "/opt/gm-test/unit", "-v"], exit=False).result
sys.exit(0 if r.wasSuccessful() and not r.skipped else 1)'
