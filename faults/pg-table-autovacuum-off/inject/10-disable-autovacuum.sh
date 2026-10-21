#!/bin/sh
# Plants pg-table-autovacuum-off: sets autovacuum_enabled = off on table
# $FAULT_TABLE_NAME of database $FAULT_DATABASE. Idempotent: setting it
# again changes nothing.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" <<'SQL'
SELECT format('ALTER TABLE %s SET (autovacuum_enabled = off)', :'tbl'::regclass)
\gexec
SQL
echo "autovacuum is off on $FAULT_TABLE_NAME in database $FAULT_DATABASE."
