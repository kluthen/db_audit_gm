#!/bin/sh
# Sealed check of fixture-dropped-index: exit 0 once a valid index whose
# leading column is $FAULT_COLUMN exists on $FAULT_TABLE_NAME (whatever its
# name, however it was made), 1 while none does, 2 on an error.
set -u
n=$(runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
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
    echo "$FAULT_TABLE_NAME has an index on $FAULT_COLUMN again."
    exit 0
fi
echo "$FAULT_TABLE_NAME still has no index on $FAULT_COLUMN: each lookup reads the whole table."
exit 1
