#!/bin/sh
# Sealed check of pg-role-superuser (master spec 8.1). Run as root. Exit 0
# once role $FAULT_ROLE is no longer a superuser, 1 while it is, 2 on an
# error. A dropped role also reads 0 (the fault is gone), with a first line
# saying so: the GM judges whether dropping the application's role was
# acceptable.
set -u
# Connects as the GM check role through check-psql, inside the GM's
# reserve (v0.3 master spec 6.5, 11 rule 5); on a postgres brick before
# 0.3.0, which has no check role, as postgres over the local socket.
CHECK_PSQL=/usr/local/lib/gm/check-psql
if [ -e "$CHECK_PSQL" ]; then as="the GM check role"; else as=postgres; fi
pg() {
    if [ -e "$CHECK_PSQL" ]; then
        "$CHECK_PSQL" -Atq -v ON_ERROR_STOP=1 "$@"
    else
        runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 "$@"
    fi
}

v=$(pg -d postgres \
    -v role="$FAULT_ROLE" <<'SQL'
SELECT coalesce((SELECT rolsuper::text FROM pg_roles WHERE rolname = :'role'), 'missing')
SQL
) || { echo "cannot query pg_roles as $as."; exit 2; }
case $v in
    true)
        echo "role $FAULT_ROLE is still a superuser."
        exit 1 ;;
    false)
        echo "role $FAULT_ROLE is no longer a superuser."
        exit 0 ;;
    missing)
        echo "role $FAULT_ROLE no longer exists, so it is no longer a superuser (the application has lost its login)."
        exit 0 ;;
esac
echo "unexpected answer from PostgreSQL: $v"
exit 2
