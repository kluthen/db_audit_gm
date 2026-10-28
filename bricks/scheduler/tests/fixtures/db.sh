#!/bin/sh
# Stack test fixture of the scheduler brick: a throwaway PostgreSQL (Debian's,
# from the scheduler Dockerfile's unit-test stage), the database the
# scheduler's schedule targets. Not a brick: the brick under test is the
# scheduler. Creates the role shop_app with the password of the secret the
# scheduler node also mounts, the GM check role gm_check (as the postgres
# brick creates it, reading all data) with the password of the GM's secret,
# the database `shop` and its tables, then runs
# the server in the foreground.
set -eu
PGBIN=$(ls -d /usr/lib/postgresql/*/bin | sort -V | tail -n 1)
PGDATA=/var/lib/postgresql/gmtest
install -d -o postgres -g postgres -m 0700 "$PGDATA"
runuser -u postgres -- "$PGBIN/initdb" -D "$PGDATA" -A scram-sha-256 --auth-local=peer -U postgres \
    -E UTF8 --locale=C.UTF-8 --no-sync >/dev/null
echo "host all all 0.0.0.0/0 scram-sha-256" >> "$PGDATA/pg_hba.conf"
runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -w -o "-c listen_addresses=''" start >/dev/null
runuser -u postgres -- "$PGBIN/psql" -X -q -d postgres -v ON_ERROR_STOP=1 \
    -v pw="$(cat /run/secrets/role_shop_app_password)" \
    -v gmc="$(cat /run/secrets/gm_check_password)" <<'SQL'
CREATE ROLE shop_app LOGIN PASSWORD :'pw';
CREATE ROLE gm_check LOGIN PASSWORD :'gmc' IN ROLE pg_read_all_data;
CREATE DATABASE shop OWNER shop_app;
\c shop
SET ROLE shop_app;
CREATE TABLE orders (order_no bigint PRIMARY KEY, amount numeric, at timestamptz, v2 bool);
CREATE TABLE products (id int PRIMARY KEY, name text);
INSERT INTO products SELECT i, (ARRAY['desk lamp', 'office desk', 'chair'])[1 + i % 3] FROM generate_series(1, 300) i;
CREATE TABLE reports (n bigint, at timestamptz DEFAULT now());
SQL
runuser -u postgres -- "$PGBIN/pg_ctl" -D "$PGDATA" -w stop >/dev/null
echo "db: ready"
exec runuser -u postgres -- "$PGBIN/postgres" -D "$PGDATA" -c listen_addresses='*' -c shared_buffers=16MB \
    -c max_connections=20 -c log_min_messages=warning
