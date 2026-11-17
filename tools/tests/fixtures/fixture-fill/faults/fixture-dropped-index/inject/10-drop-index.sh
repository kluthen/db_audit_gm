#!/bin/sh
# Plants fixture-dropped-index: drops every index (the primary key aside)
# whose leading column is $FAULT_COLUMN on table $FAULT_TABLE_NAME of
# database $FAULT_DATABASE. Idempotent: a second run finds none to drop.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" -v col="$FAULT_COLUMN" <<'SQL'
SELECT format('DROP INDEX %I.%I', n.nspname, c.relname)
  FROM pg_index i
  JOIN pg_class c ON c.oid = i.indexrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace
  JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
 WHERE i.indrelid = :'tbl'::regclass AND a.attname = :'col' AND NOT i.indisprimary
\gexec
SQL
echo "no index leads with $FAULT_COLUMN on $FAULT_TABLE_NAME in database $FAULT_DATABASE."
