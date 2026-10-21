#!/bin/sh
# Sealed check of pg-abandoned-replication-slot (master spec 8.1). Run as
# root. Exit 0 once the slot $FAULT_SLOT_NAME no longer exists, 1 while it
# does, 2 on an error.
set -u
n=$(runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d postgres \
    -v slot="$FAULT_SLOT_NAME" <<'SQL'
SELECT count(*) FROM pg_replication_slots WHERE slot_name = :'slot'
SQL
) || { echo "cannot query pg_replication_slots as postgres."; exit 2; }
case $n in
    0)
        echo "replication slot $FAULT_SLOT_NAME has been dropped: no WAL is held back for it any more."
        exit 0 ;;
    1)
        echo "replication slot $FAULT_SLOT_NAME still exists with no standby, holding back WAL."
        exit 1 ;;
esac
echo "unexpected answer from PostgreSQL: $n"
exit 2
