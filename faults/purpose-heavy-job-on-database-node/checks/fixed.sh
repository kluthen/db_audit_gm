#!/bin/sh
# Sealed check of purpose-heavy-job-on-database-node (v0.4 master spec 16.3,
# 12.7: an incident check). Run as root on the database node carrying the
# heavy entry (reporting), fed to `sh -s` by gmctl check, with the FAULT_*
# parameters. It reads the backfill request as the GM check role through
# check-psql, and PostgreSQL's server log; it never runs a job.
#
# The planting moment is the backfill request's requested_at (the state
# change's row, the earliest of rpt.sales_detail_backfills). Judged: the
# server log's lines since then (postgresql-*.log, in file order; each line
# opens with the seed's %t, UTC): a backend "terminated by signal 9: Killed",
# then the recovery that follows it, "terminating any other active server
# processes", "all server processes terminated; reinitializing", "database
# system was not properly shut down; automatic recovery in progress" and
# "database system is ready to accept connections".
# Exit 1: the kill and the recovery are there, whatever the crontab holds
# since. The fault is report only: no in-game fix is expected and the check
# never answers 0 or 3.
# Exit 2: no request (not planted), no kill since it (the incident did not
# happen: a failed planting, gm.md), a kill without its recovery yet, or
# the log or the request cannot be read.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
DB=${FAULT_DATABASE:-reporting}
LOGS=/var/log/postgresql
EVENTS=/sys/fs/cgroup/memory.events

cannot() { echo "the out-of-memory incident cannot be confirmed: $*"; exit 2; }
[ -x "$CHECK_PSQL" ] || cannot "no $CHECK_PSQL on this node (postgres 0.4.0 needed)"

# the first request's requested_at|taken_at|done_at (UTC, to the second)
request=$("$CHECK_PSQL" -d "$DB" -Atq -v ON_ERROR_STOP=1 <<'SQL'
SELECT to_char(requested_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS'),
       coalesce(to_char(taken_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS'), ''),
       coalesce(to_char(done_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS'), '')
  FROM rpt.sales_detail_backfills
 ORDER BY requested_at, id
 LIMIT 1
SQL
) || cannot "rpt.sales_detail_backfills cannot be read in $DB (PostgreSQL recovering, or the table gone)"
[ -n "$request" ] || cannot "no backfill request in rpt.sales_detail_backfills in $DB: not planted yet"
planted=$(printf '%s' "$request" | cut -d'|' -f1)
taken=$(printf '%s' "$request" | cut -d'|' -f2)
done_=$(printf '%s' "$request" | cut -d'|' -f3)

set -- "$LOGS"/postgresql-*.log
[ -r "$1" ] || cannot "no server log in $LOGS"

# kill time|failed process|terminating|reinitializing|recovery|ready (UTC);
# the first kill since the planting moment and the first recovery lines
# after it.
found=$(cat "$@" | awk -v since="$planted" '
    function at(line) { return substr(line, 1, 19) }
    /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]/ {
        t = at($0)
        if (t < since) next
        if (kill == "" && /was terminated by signal 9: Killed/) { kill = t; detail = 1; next }
        if (kill == "") next
        if (detail && /DETAIL: +Failed process was running: /) {
            sub(/.*Failed process was running: /, ""); failed = $0; detail = 0; next }
        detail = 0
        if (term == "" && /terminating any other active server processes/) term = t
        else if (term != "" && reinit == "" && /all server processes terminated; reinitializing/) reinit = t
        else if (reinit != "" && recov == "" && /database system was not properly shut down; automatic recovery in progress/) recov = t
        else if (recov != "" && ready == "" && /database system is ready to accept connections/) ready = t
    }
    END { gsub(/\|/, "/", failed); printf "%s|%s|%s|%s|%s|%s\n", kill, failed, term, reinit, recov, ready }')
kill_at=$(printf '%s' "$found" | cut -d'|' -f1)
failed=$(printf '%s' "$found" | cut -d'|' -f2)
ready=$(printf '%s' "$found" | cut -d'|' -f6)
recov=$(printf '%s' "$found" | cut -d'|' -f5)

if [ -z "$kill_at" ]; then
    state="not taken yet"
    [ -n "$taken" ] && state="taken at $taken UTC"
    [ -n "$done_" ] && state="$state, done at $done_ UTC: the backfill completed"
    cannot "no backend killed in the server log since the backfill request of $planted UTC ($state): the incident did not happen yet, or the planting failed (never re-planted within the aging)"
fi
if [ -z "$ready" ]; then
    cannot "a backend was killed at $kill_at UTC, but the recovery that follows is not complete in the log yet (recovery started: ${recov:-no})"
fi
oom=$(awk '$1 == "oom_kill" { print $2 }' "$EVENTS" 2>/dev/null)
what=
[ -n "$failed" ] && what=" while running $failed"
echo "the out-of-memory incident is in the log: a backend killed by signal 9 at $kill_at UTC$what, PostgreSQL recovered by itself and accepted connections at $ready UTC (since the backfill request of $planted UTC; oom_kill ${oom:-unreadable} in memory.events)."
exit 1
