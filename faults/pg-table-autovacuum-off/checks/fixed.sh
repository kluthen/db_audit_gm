#!/bin/sh
# Sealed check of pg-table-autovacuum-off (master spec 8.1). Run as root.
# Exit 0 once table $FAULT_TABLE_NAME no longer has autovacuum_enabled set
# to false (reset, or set to a true value), 1 while it has, 2 on an error.
# The option's value is read as PostgreSQL reads a boolean (off, false, no,
# 0...), since reloptions keep it as written.
set -u
v=$(runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
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
