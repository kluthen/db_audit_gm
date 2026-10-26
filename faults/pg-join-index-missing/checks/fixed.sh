#!/bin/sh
# Sealed check of pg-join-index-missing (master spec 8.1). Run as root.
# Exit 0 once a valid index whose leading column is $FAULT_COLUMN exists on
# $FAULT_TABLE_NAME (whatever its name, however it was built), 1 while none
# does, 2 on an error.
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

n=$(pg -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" -v col="$FAULT_COLUMN" <<'SQL'
SELECT count(*)
  FROM pg_index i
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
 WHERE i.indrelid = :'tbl'::regclass AND a.attname = :'col' AND i.indisvalid
SQL
) || { echo "cannot query $FAULT_TABLE_NAME in database $FAULT_DATABASE."; exit 2; }
case $n in
    ''|*[!0-9]*) echo "unexpected answer from PostgreSQL: $n"; exit 2 ;;
esac
if [ "$n" -gt 0 ]; then
    echo "$FAULT_TABLE_NAME has a valid index leading with $FAULT_COLUMN again."
    exit 0
fi
echo "$FAULT_TABLE_NAME still has no index on $FAULT_COLUMN: every join or lookup through it reads the whole table."
exit 1
