#!/bin/sh
# Sealed check of pgbouncer-pool-too-small (master spec 8.1, v0.3 master
# spec 6.5; capture W4 items 0 and 9). Run as root on the pooler node. Reads
# the values in effect on PgBouncer's console over the local socket, as
# `pgbouncer`, its only admin (W2-a), so a file edited but not reloaded
# reads present.
#
# Exit 0 once the pool size of FAULT_DATABASE in effect (SHOW DATABASES,
# pool_size) is at least FAULT_MIN_POOL_SIZE and its max_db_connections in
# effect (SHOW DATABASES, max_connections) is 0 or at least
# FAULT_MIN_POOL_SIZE; 1 otherwise; 2 on an error (the console not
# answering, the database not in [databases]). The pool mode is not judged.
set -u
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
PGCONNECT_TIMEOUT=10
export PGCONNECT_TIMEOUT
db=${FAULT_DATABASE:-}
min=${FAULT_MIN_POOL_SIZE:-}
[ -n "$db" ] || { echo "FAULT_DATABASE must be set."; exit 2; }
case $min in ''|*[!0-9]*) echo "FAULT_MIN_POOL_SIZE must be a whole number."; exit 2 ;; esac

out=$(runuser -u pgbouncer -- psql -X -w -q -A -F '|' -P footer=off -h /run/pgbouncer -p 6432 \
      -U pgbouncer -d pgbouncer -c 'SHOW DATABASES' 2>&1) \
    || { echo "PgBouncer's console does not answer: $(printf '%s' "$out" | head -n 1)"; exit 2; }
row=$(printf '%s\n' "$out" | awk -F'|' -v d="$db" '
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    $1 == d { print $(col["pool_size"]) "|" $(col["max_connections"]); exit }')
[ -n "$row" ] || { echo "database $db is not in PgBouncer's [databases] (SHOW DATABASES)."; exit 2; }
size=${row%%|*}
maxc=${row#*|}
case "$size$maxc" in ''|*[!0-9]*) echo "unexpected SHOW DATABASES row for $db: $row"; exit 2 ;; esac
if [ "$size" -lt "$min" ]; then
    echo "the pool of $db is still $size server connections in effect, below $min."
    exit 1
fi
if [ "$maxc" -ne 0 ] && [ "$maxc" -lt "$min" ]; then
    echo "the pool of $db is $size in effect, but max_db_connections caps it at $maxc, below $min."
    exit 1
fi
echo "the pool of $db is $size server connections in effect (max_db_connections ${maxc}), at least $min."
exit 0
