#!/bin/sh
# Sealed check of scheduler-display-refresh-loop (master spec 8.1; v0.3
# master spec 6.5 and 11; v0.5 master spec 17.2 s9; capture W5 items 0 and
# 4, W5-d). Run as root on the ward service's node. A behavioural check: it
# connects as the GM check role gm_check, inside the GM's reserve, straight
# to port 5432 of the record's node FAULT_DB_NODE, through the root-only
# helper /usr/local/lib/gm/check-sql (scheduler 0.1.0), read-only, to
# database postgres, where pg_stat_statements lives.
#
# The board statement (ward.board's, `SELECT * FROM housing_unit_board
# WHERE unit_id = $1` as pg_stat_statements normalises it, one queryid for
# every display) in FAULT_DATABASE: its calls are read twice,
# CHECK_WINDOW_SECONDS (W) apart, the check sleeping in between, since the
# statistics keep no history; r is the calls a minute over those W
# seconds. Exit 0 when r is at most CHECK_THRESHOLD (T: the wards' 64
# displays at one read a minute each, and a margin, in the answer key);
# else 1. Exit 3, `remaining=<W>`, when the statistics were reset between
# the two reads. Exit 2 on an error (the helper's, a parameter missing).
# Report-only (master spec 6.3): the GM runs it at the final answer as
# evidence, never to clear the fault in play.
set -u
CHECK_SQL=/usr/local/lib/gm/check-sql
for v in FAULT_DB_NODE FAULT_DATABASE CHECK_WINDOW_SECONDS CHECK_THRESHOLD; do
    eval "val=\${$v:-}"
    [ -n "$val" ] || { echo "$v must be set."; exit 2; }
done
case $CHECK_WINDOW_SECONDS in *[!0-9]*) echo "CHECK_WINDOW_SECONDS is not a whole number of seconds."; exit 2 ;; esac
[ "$CHECK_WINDOW_SECONDS" -ge 10 ] || { echo "CHECK_WINDOW_SECONDS must be at least 10."; exit 2; }
[ -x "$CHECK_SQL" ] || { echo "$CHECK_SQL is missing: the scheduler brick predates 0.1.0's GM check role access."; exit 2; }

calls() {
    "$CHECK_SQL" -h "$FAULT_DB_NODE" -p 5432 -d postgres -v db="$FAULT_DATABASE" 2>&1 <<'SQL'
SELECT coalesce(sum(s.calls), 0)::bigint, extract(epoch FROM clock_timestamp())::numeric(20, 3)
  FROM pg_stat_statements AS s JOIN pg_database AS d ON d.oid = s.dbid
 WHERE d.datname = %(db)s AND s.query = 'SELECT * FROM housing_unit_board WHERE unit_id = $1'
SQL
}
a=$(calls) || { echo "cannot read pg_stat_statements on $FAULT_DB_NODE as gm_check: $(printf '%s' "$a" | tail -n 1)"; exit 2; }
sleep "$CHECK_WINDOW_SECONDS"
b=$(calls) || { echo "cannot read pg_stat_statements on $FAULT_DB_NODE as gm_check: $(printf '%s' "$b" | tail -n 1)"; exit 2; }
case "$a|$b" in
    *[!0-9.|]*|'|'*|*'|') echo "unexpected answer from PostgreSQL: $a, $b"; exit 2 ;;
esac
awk -v a="$a" -v b="$b" -v t="$CHECK_THRESHOLD" -v w="$CHECK_WINDOW_SECONDS" -v db="$FAULT_DATABASE" 'BEGIN {
    split(a, x, "|"); split(b, y, "|")
    n = y[1] - x[1]; s = y[2] - x[2]
    if (n < 0 || s <= 0) {
        printf "remaining=%d pg_stat_statements was reset during the %d s read: read again.\n", w, w
        exit 3
    }
    r = n * 60 / s
    if (r <= t + 0) {
        printf "the board statement ran %.1f times a minute in %s over %d s, at most %s: no display reads it in a loop.\n", r, db, s, t
        exit 0
    }
    printf "the board statement ran %.1f times a minute in %s over %d s, above %s: a display reads its board in a loop.\n", r, db, s, t
    exit 1
}'
