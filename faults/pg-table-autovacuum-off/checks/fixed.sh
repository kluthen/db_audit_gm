#!/bin/sh
# Sealed check of pg-table-autovacuum-off (master spec 8.1). Run as root.
# Exit 0 once table $FAULT_TABLE_NAME no longer has autovacuum_enabled set
# to false (reset, or set to a true value), 1 while it has, 2 on an error.
# The option's value is read as PostgreSQL reads a boolean (off, false, no,
# 0...), since reloptions keep it as written.
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

v=$(pg -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" <<'SQL'
SELECT coalesce(bool_or(NOT substr(o, length('autovacuum_enabled=') + 1)::boolean), false)
  FROM pg_class c, unnest(c.reloptions) AS o
 WHERE c.oid = :'tbl'::regclass AND o LIKE 'autovacuum\_enabled=%'
SQL
) || { echo "cannot read the options of $FAULT_TABLE_NAME in database $FAULT_DATABASE."; exit 2; }
case $v in
    t)
        echo "autovacuum is still disabled on $FAULT_TABLE_NAME (autovacuum_enabled=off)."
        exit 1 ;;
    f)
        echo "autovacuum is enabled again on $FAULT_TABLE_NAME."
        exit 0 ;;
esac
echo "unexpected answer from PostgreSQL: $v"
exit 2
