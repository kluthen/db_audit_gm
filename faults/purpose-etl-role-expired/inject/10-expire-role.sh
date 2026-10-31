#!/bin/sh
# Plants purpose-etl-role-expired: role $FAULT_ROLE's password is given
# VALID UNTIL the planting moment, and its open sessions are ended, so its
# next connection (the transformer's source connection, the reporting
# instance's postgres_fdw connection through the user mapping) is refused:
# PostgreSQL checks VALID UNTIL at authentication only, and the scheduler
# keeps its sessions open between runs. Idempotent: a second run moves the
# expiry to its own moment, still past, and finds the sessions ended. Fails
# if the role does not exist (the data file creates it).
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d postgres \
    -v role="$FAULT_ROLE" <<'SQL'
SELECT to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS') || '+00' AS expiry \gset
ALTER ROLE :"role" VALID UNTIL :'expiry';
SELECT count(pg_terminate_backend(pid)) AS ended
  FROM pg_stat_activity WHERE usename = :'role' \gset
\echo role :role expired at :expiry; :ended open session(s) ended.
SQL
