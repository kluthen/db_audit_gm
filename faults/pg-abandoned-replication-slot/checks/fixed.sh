#!/bin/sh
# Sealed check of pg-abandoned-replication-slot (master spec 8.1). Run as
# root. Exit 0 once the slot $FAULT_SLOT_NAME no longer exists, 1 while it
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

n=$(pg -d postgres \
    -v slot="$FAULT_SLOT_NAME" <<'SQL'
SELECT count(*) FROM pg_replication_slots WHERE slot_name = :'slot'
SQL
) || { echo "cannot query pg_replication_slots as $as."; exit 2; }
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
