#!/bin/sh
# Sealed check of scheduler-insert-retry-duplicates (master spec 8.1, v0.3
# master spec 6.5 and 11; capture W4 item 5; spec D185). Run as root on the
# scheduler node. A behavioural check on the data: it connects as the GM
# check role gm_check, inside the GM's reserve, straight to port 5432 of the
# database node FAULT_DB_NODE (never through a pooler), through the
# root-only helper /usr/local/lib/gm/check-sql (scheduler 0.1.0), read-only.
#
# d is the number of rows of FAULT_TABLE_NAME in FAULT_DATABASE whose
# FAULT_TIME_COLUMN lies in the trailing CHECK_WINDOW_SECONDS (W) and whose
# FAULT_ID_COLUMN occurs more than once among them. Exit 0 when d is at most
# CHECK_THRESHOLD (T); else 1 when the newest such row is younger than W/2;
# else 3, `remaining=<W minus its age>` first (too soon: the duplicates may
# predate a fix). A fix in the producer and a unique constraint on the
# database read alike. Before the load starts the table has no recent rows:
# 0. Exit 2 on an error (the helper's, a parameter missing).
set -u
CHECK_SQL=/usr/local/lib/gm/check-sql
for v in FAULT_DATABASE FAULT_TABLE_NAME FAULT_ID_COLUMN FAULT_TIME_COLUMN FAULT_DB_NODE \
         CHECK_WINDOW_SECONDS CHECK_THRESHOLD; do
    eval "val=\${$v:-}"
    [ -n "$val" ] || { echo "$v must be set."; exit 2; }
done
case $CHECK_WINDOW_SECONDS in *[!0-9]*) echo "CHECK_WINDOW_SECONDS is not a whole number of seconds."; exit 2 ;; esac
[ "$CHECK_WINDOW_SECONDS" -ge 1 ] || { echo "CHECK_WINDOW_SECONDS must be at least 1."; exit 2; }
[ -x "$CHECK_SQL" ] || { echo "$CHECK_SQL is missing: the scheduler brick predates 0.1.0's GM check role access."; exit 2; }

out=$("$CHECK_SQL" -h "$FAULT_DB_NODE" -p 5432 -d "$FAULT_DATABASE" \
    -i tbl="$FAULT_TABLE_NAME" -i idc="$FAULT_ID_COLUMN" -i tc="$FAULT_TIME_COLUMN" \
    -v w="$CHECK_WINDOW_SECONDS" 2>&1 <<'SQL'
WITH w AS (
    SELECT {idc} AS id, {tc} AS t FROM {tbl}
     WHERE {tc} > now() - make_interval(secs => %(w)s::int)
), d AS (
    SELECT t FROM w WHERE id IN (SELECT id FROM w GROUP BY id HAVING count(*) > 1)
)
SELECT count(*), coalesce(floor(extract(epoch FROM now() - max(t)))::bigint, -1) FROM d
SQL
) || { echo "cannot read $FAULT_TABLE_NAME in $FAULT_DATABASE on $FAULT_DB_NODE as gm_check: $(printf '%s' "$out" | tail -n 1)"; exit 2; }

d=${out%%|*}
age=${out#*|}
case "$d|$age" in
    *[!0-9|-]*|'|'*|*'|') echo "unexpected answer from PostgreSQL: $out"; exit 2 ;;
esac
W=$CHECK_WINDOW_SECONDS
if awk -v d="$d" -v t="$CHECK_THRESHOLD" 'BEGIN { exit !(d + 0 <= t + 0) }'; then
    echo "$d duplicate row(s) of $FAULT_TABLE_NAME inserted in the last $W s, at most $CHECK_THRESHOLD."
    exit 0
fi
if [ "$age" -lt $((W / 2)) ]; then
    echo "$d duplicate row(s) of $FAULT_TABLE_NAME inserted in the last $W s (the newest $age s ago), more than $CHECK_THRESHOLD: inserts are still resent."
    exit 1
fi
r=$((W - age)); [ "$r" -ge 1 ] || r=1
echo "remaining=$r $d duplicate row(s) of $FAULT_TABLE_NAME in the last $W s, none in the last $age s: they may predate a fix."
exit 3
