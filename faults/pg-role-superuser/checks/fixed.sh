#!/bin/sh
# Sealed check of pg-role-superuser (master spec 8.1). Run as root. Exit 0
# once role $FAULT_ROLE is no longer a superuser, 1 while it is, 2 on an
# error. A dropped role also reads 0 (the fault is gone), with a first line
# saying so: the GM judges whether dropping the application's role was
# acceptable.
set -u
v=$(runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d postgres \
    -v role="$FAULT_ROLE" <<'SQL'
SELECT coalesce((SELECT rolsuper::text FROM pg_roles WHERE rolname = :'role'), 'missing')
SQL
) || { echo "cannot query pg_roles as postgres."; exit 2; }
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
