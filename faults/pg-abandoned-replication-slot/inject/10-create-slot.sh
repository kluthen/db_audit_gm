#!/bin/sh
# Plants pg-abandoned-replication-slot: creates the physical replication
# slot $FAULT_SLOT_NAME, reserving WAL at once, unless it already exists.
# Idempotent: a second run finds the slot and creates nothing. psql's
# result rows are discarded; its errors still reach stderr.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d postgres \
    -v slot="$FAULT_SLOT_NAME" >/dev/null <<'SQL'
SELECT format('SELECT pg_create_physical_replication_slot(%L, true)', :'slot')
 WHERE NOT EXISTS (SELECT 1 FROM pg_replication_slots WHERE slot_name = :'slot')
\gexec
SQL
echo "physical replication slot $FAULT_SLOT_NAME exists, with no standby."
