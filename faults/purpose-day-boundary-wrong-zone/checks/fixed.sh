#!/bin/sh
# Sealed check of purpose-day-boundary-wrong-zone (v0.4 master spec 16.2,
# 12.1 to 12.3; R3 of the sales reporting purpose, on the close). Run as
# root on the target database node (reporting), fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD and the
# FAULT_* parameters. It reads both instances as the GM check role through
# check-psql (the source with --node); it never runs a job.
#
# - The runs: the close's own ledger, rpt.etl_runs rows of job $FAULT_JOB
#   finished after CHECK_SINCE. The close is scheduled on the runner, a
#   node this check cannot read, so its judged moment is CHECK_SINCE as
#   given: a fix to the procedure is made outside the runner, and the GM
#   dates it with gmctl check --since (12.1).
# - Judged: each day row such a run wrote and still owns (rpt.sales_daily
#   run_id), its orders and revenue against the source's local day, the
#   source's business_settings zone, once that day was over SETTLE seconds
#   before the run started.
# Exit 1: more than CHECK_THRESHOLD such days differ, naming the first.
# Exit 0: none, and a compared day had orders in its first and in its last
# local hour (the witness: a boundary moved by any whole hour moves one of
# them). Exit 3, remaining= to the close's next designed time
# ($FAULT_CLOSE_AT, customer time): no run since, or no witness yet.
# Exit 2: it cannot judge.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
SETTLE=60
SINCE=${CHECK_SINCE:-}
THRESHOLD=${CHECK_THRESHOLD:-0}
JOB=${FAULT_JOB:-rollup-close}
DB=${FAULT_DATABASE:-reporting}
SRC_NODE=${FAULT_SOURCE_NODE:-db}
SRC_DB=${FAULT_SOURCE_DATABASE:-shop}
SOURCE=$SRC_NODE/$SRC_DB
CLOSE_AT=${FAULT_CLOSE_AT:-01:30}

cannot() { echo "R3 on the close cannot be judged: $*"; exit 2; }
case $SINCE in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) cannot "CHECK_SINCE is not a UTC instant YYYY-MM-DDTHH:MM:SSZ ($SINCE)" ;;
esac
case $THRESHOLD in ''|*[!0-9]*) cannot "CHECK_THRESHOLD is not a whole number ($THRESHOLD)" ;; esac
case $CLOSE_AT in [0-2][0-9]:[0-5][0-9]) ;; *) cannot "close-at is not HH:MM ($CLOSE_AT)" ;; esac
[ -x "$CHECK_PSQL" ] || cannot "no $CHECK_PSQL on this node (postgres 0.4.0 needed)"

target() { "$CHECK_PSQL" -d "$DB" -Atq -v ON_ERROR_STOP=1 "$@"; }
source_() { "$CHECK_PSQL" --node "$SRC_NODE" -d "$SRC_DB" -Atq -v ON_ERROR_STOP=1 "$@"; }

too_soon() {
    remaining=$(target -v at="$CLOSE_AT" <<'SQL'
SELECT greatest(1, ceil(extract(epoch FROM n.next - now())))::bigint
  FROM rpt.business_settings s,
       LATERAL (SELECT (date_trunc('day', now() AT TIME ZONE s.timezone) + :'at'::time)
                       AT TIME ZONE s.timezone AS today) t,
       LATERAL (SELECT CASE WHEN t.today > now() THEN t.today
                            ELSE t.today + interval '1 day' END AS next) n
SQL
) || cannot "rpt.business_settings cannot be read in $DB"
    echo "remaining=$remaining $*"
    exit 3
}

ran=$(target -v since="$SINCE" -v job="$JOB" <<'SQL'
SELECT count(*) FROM rpt.etl_runs
 WHERE job = :'job' AND finished_at > :'since'::timestamptz
SQL
) || cannot "rpt.etl_runs cannot be read in $DB"
[ "$ran" -gt 0 ] || too_soon "no run of $JOB has ended since $SINCE"
runs="$ran runs"; [ "$ran" -eq 1 ] && runs="1 run"

# day|orders|revenue|run id|run start (UTC)|run start (epoch)
days_t=$(target -v since="$SINCE" -v job="$JOB" <<'SQL'
SELECT d.day_local, d.orders, d.revenue::numeric(14,2), e.id,
       to_char(e.started_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       floor(extract(epoch FROM e.started_at))::bigint
  FROM rpt.sales_daily d JOIN rpt.etl_runs e ON e.id = d.run_id
 WHERE e.job = :'job' AND e.finished_at > :'since'::timestamptz
 ORDER BY e.started_at, d.day_local
SQL
) || cannot "rpt.sales_daily cannot be read in $DB"
[ -n "$days_t" ] || too_soon "$runs of $JOB since $SINCE, but no day they closed is left to judge"

list=$(printf '%s\n' "$days_t" | cut -d'|' -f1 | sort -u | tr '\n' ' ')
# day|orders|revenue|last placing (epoch)|orders in the first local hour|in the last|day's end (epoch)
days_s=$(source_ -v days="$list" <<'SQL'
SELECT d.day, count(o.id), coalesce(sum(o.total), 0)::numeric(14,2),
       coalesce(floor(extract(epoch FROM max(o.placed_at)))::bigint, 0),
       count(o.id) FILTER (WHERE extract(hour FROM o.placed_at AT TIME ZONE s.timezone) = 0),
       count(o.id) FILTER (WHERE extract(hour FROM o.placed_at AT TIME ZONE s.timezone) = 23),
       floor(extract(epoch FROM (d.day + 1)::timestamp AT TIME ZONE s.timezone))::bigint
  FROM business_settings s
 CROSS JOIN unnest(string_to_array(btrim(:'days'), ' ')::date[]) AS d(day)
  LEFT JOIN orders o
    ON o.placed_at >= d.day::timestamp AT TIME ZONE s.timezone
   AND o.placed_at < (d.day + 1)::timestamp AT TIME ZONE s.timezone
 GROUP BY d.day, s.timezone
SQL
) || cannot "the source's orders cannot be read on $SOURCE"

verdict=$( { printf '%s\n' "$days_s" | sed 's/^/S|/'; printf '%s\n' "$days_t" | sed 's/^/T|/'; } \
    | awk -F'|' -v settle="$SETTLE" '
    $1 == "S" { orders[$2] = $3; revenue[$2] = $4; first[$2] = $6; last[$2] = $7; end_[$2] = $8; next }
    $1 == "T" {
        day = $2; started = $7
        if (!(day in end_) || end_[day] > started - settle) { skipped++; next }
        compared++
        if ($3 != orders[day] || $4 != revenue[day]) {
            bad++
            if (bad == 1) first_bad = sprintf("the %s run of %s left day %s at orders %s, revenue %s where the source'"'"'s local day holds orders %s, revenue %s", "close", $6, day, $3, $4, orders[day], revenue[day])
        } else if (first[day] > 0 && last[day] > 0) witness++
    }
    END { printf "%d|%d|%d|%d|%s\n", compared, bad, witness, skipped, first_bad }')
compared=$(printf '%s' "$verdict" | cut -d'|' -f1)
bad=$(printf '%s' "$verdict" | cut -d'|' -f2)
witness=$(printf '%s' "$verdict" | cut -d'|' -f3)
first_bad=$(printf '%s' "$verdict" | cut -d'|' -f5-)

if [ "$bad" -gt "$THRESHOLD" ]; then
    more=
    [ "$bad" -gt 1 ] && more=" ($bad closed days differ)"
    echo "R3 present on the close: $first_bad$more."
    exit 1
fi
if [ "$witness" -eq 0 ]; then
    too_soon "$runs of $JOB since $SINCE closed $compared comparable days, none yet with orders at both its ends"
fi
echo "R3 holds on the close: $runs of $JOB since $SINCE closed the customer's local days ($compared compared, $bad differing, threshold $THRESHOLD)."
exit 0
