#!/bin/sh
# Sealed check of pg-monitoring-option-absent (master spec 8.1; v0.5 master
# spec 17.2 s10; capture W5 item 4, W5-d; spec D462). Run as root on the
# database node; connects as the GM check role gm_check through the
# root-only helper check-psql, to database postgres.
#
# Exit 0 once the role monitoring exists, can log in and holds pg_monitor's
# privileges (a member of it, inheriting), as the option's initdb step
# creates it; 1 while it does not; 2 on an error. Whether its password is
# the exporter's is read on the exporter's side (pg_up, its metrics), not
# here: gm_check reads no password.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
[ -x "$CHECK_PSQL" ] || { echo "$CHECK_PSQL is missing: the postgres brick predates 0.3.0's GM check role."; exit 2; }
v=$("$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 2>&1 <<'SQL'
SELECT coalesce((SELECT CASE WHEN NOT r.rolcanlogin THEN 'nologin'
                             WHEN NOT pg_has_role(r.oid, 'pg_monitor', 'USAGE') THEN 'nomonitor'
                             ELSE 'ok' END
                   FROM pg_roles r WHERE r.rolname = 'monitoring'), 'missing')
SQL
) || { echo "cannot query pg_roles as the GM check role: $(printf '%s' "$v" | tail -n 1)"; exit 2; }
case $v in
    ok)
        echo "role monitoring exists, can log in and holds pg_monitor, as the monitoring option creates it."
        exit 0 ;;
    missing)
        echo "role monitoring does not exist on this node: its monitoring cannot log in."
        exit 1 ;;
    nologin)
        echo "role monitoring exists but cannot log in."
        exit 1 ;;
    nomonitor)
        echo "role monitoring exists but does not hold pg_monitor."
        exit 1 ;;
esac
echo "unexpected answer from PostgreSQL: $v"
exit 2
