#!/bin/sh
# Second script of pg-join-index-missing: refreshes the table's statistics
# so that the plans the players see match the data. Idempotent.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" <<'SQL'
SELECT format('ANALYZE %s', :'tbl'::regclass)
\gexec
SQL
echo "statistics of $FAULT_TABLE_NAME refreshed."
