#!/bin/sh
# Second script of fixture-dropped-index: refreshes the table's statistics
# so that the planner's estimates match the data. Idempotent.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
    -v tbl="$FAULT_TABLE_NAME" <<'SQL'
ANALYZE :"tbl";
SQL
echo "statistics of $FAULT_TABLE_NAME refreshed."
