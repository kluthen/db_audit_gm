#!/bin/sh
# Sealed check of purpose-etl-role-expired (v0.4 master spec 12.1, 12.2,
# 12.5, 16.2): the sales reporting purpose's R4, the dashboards fresh, judged
# from the fault's own node, the source database node, on the hourly job's
# runs since the judged moment: its run ledger (rpt.etl_runs on the target
# instance, which the script writes in the run's transaction) and the source
# role's refused logins in this node's server log. R4 itself reads the
# runner's log, out of reach here (purposes/shop-sales-reporting/checks/
# r4-fresh.sh).
#
# Runs on the database node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the refused logins
# tolerated, 0 by the answer key's default), FAULT_ROLE (the source role),
# FAULT_TARGET (<node>/<database> of the run ledger) and FAULT_JOB (the
# hourly job). It reads pg_roles here and rpt.etl_runs on the target as
# gm_check through check-psql (the other-node form), and this node's server
# log; it never runs a job.
#
# - The judged moment: CHECK_SINCE, the planting before the hand-over, the
#   hand-over after it, or the time of the fix the players' report dates
#   (gmctl check --since): the fix is made outside the runner, so no reload
#   raises it (12.1).
# - Present (1): the role cannot log in now (its password expired, NOLOGIN,
#   or the role gone); or more logins of it refused for an expired password
#   since the judged moment than the threshold (every run of the hourly
#   script and of the close since then, each a refused connection); or no
#   run of the job in the ledger for 70 minutes since the judged moment
#   (the dashboards frozen).
# - Fixed (0): none of these, and a run of the job since the judged moment
#   in the ledger, having read changed orders (the witness).
# - Too soon (3): otherwise, remaining= to the job's next run, read from the
#   ledger's last start (an hourly job).
# Exit 2: it cannot judge.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
LOGS=/var/log/postgresql
FRESH=4200                               # seconds: 70 minutes, R4's latest run's age at most
ROLE=${FAULT_ROLE:-shop_etl}
TARGET=${FAULT_TARGET:-reporting/reporting}
JOB=${FAULT_JOB:-rollup-hourly}
SINCE=${CHECK_SINCE:-}
THRESHOLD=${CHECK_THRESHOLD:-0}

cannot() { echo "R4 cannot be judged: $*"; exit 2; }

case $SINCE in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) cannot "CHECK_SINCE '$SINCE' is not YYYY-MM-DDTHH:MM:SSZ" ;;
esac
case $THRESHOLD in ''|*[!0-9]*) cannot "CHECK_THRESHOLD '$THRESHOLD' is not an integer" ;; esac
node=${TARGET%%/*}
db=${TARGET#*/}
case $TARGET in */*/*|/*|*/) cannot "FAULT_TARGET '$TARGET' is not <node>/<database>" ;; esac
[ "$node" != "$TARGET" ] || cannot "FAULT_TARGET '$TARGET' is not <node>/<database>"
since_log=$(printf '%s' "$SINCE" | sed 's/T/ /; s/Z$//')     # the log's %t, in UTC
now=$(date -u +%s)

# 1. The role, now.
state=$("$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 -v role="$ROLE" <<'SQL'
SELECT coalesce((
  SELECT CASE WHEN rolvaliduntil IS NOT NULL AND rolvaliduntil <= now()
              THEN 'expired ' || to_char(rolvaliduntil AT TIME ZONE 'UTC',
                                         'YYYY-MM-DD"T"HH24:MI:SS"Z"')
              WHEN NOT rolcanlogin THEN 'nologin'
              ELSE 'ok' END
    FROM pg_roles WHERE rolname = :'role'), 'missing')
SQL
) || cannot "cannot read pg_roles as gm_check"
case $state in
    expired*)
        echo "R4 present: role $ROLE's password expired at ${state#expired }: every run of $JOB (and of the close over postgres_fdw) is refused its connection; the dashboards are frozen."
        exit 1 ;;
    nologin)
        echo "R4 present: role $ROLE is NOLOGIN: every run of $JOB is refused its connection."
        exit 1 ;;
    missing)
        echo "R4 present: role $ROLE no longer exists: every run of $JOB is refused its connection."
        exit 1 ;;
    ok) ;;
    *) cannot "unexpected answer from pg_roles: $state" ;;
esac

# 2. Its logins refused for an expired password since the judged moment.
refused=$(find "$LOGS" -maxdepth 1 -name 'postgresql-*.log' -type f 2>/dev/null | sort |
    xargs -r cat 2>/dev/null |
    awk -v since="$since_log" -v detail="DETAIL:  User \"$ROLE\" has an expired password." '
        index($0, detail) && substr($0, 1, 19) >= since { n++; last = substr($0, 1, 19) }
        END { printf "%d %s\n", n, last }')
count=${refused%% *}
latest=${refused#* }
if [ "$count" -gt "$THRESHOLD" ]; then
    echo "R4 present: $count logins of $ROLE refused since $SINCE for an expired password, the latest at ${latest} UTC: runs of $JOB failed."
    exit 1
fi
tolerated=
[ "$count" -eq 0 ] || tolerated="; $count refused logins tolerated (threshold $THRESHOLD)"

# 3. The job's runs in the ledger.
ledger=$("$CHECK_PSQL" --node "$node" -d "$db" -Atq -v ON_ERROR_STOP=1 -v job="$JOB" \
    -v since="$SINCE" <<'SQL'
SELECT count(*) FILTER (WHERE finished_at > :'since'::timestamptz),
       count(*) FILTER (WHERE finished_at > :'since'::timestamptz AND rows_read > 0),
       coalesce(floor(extract(epoch FROM max(started_at)))::bigint, 0),
       coalesce(floor(extract(epoch FROM max(finished_at)))::bigint, 0)
  FROM rpt.etl_runs
 WHERE job = :'job' AND finished_at IS NOT NULL
SQL
) || cannot "cannot read rpt.etl_runs on $node as gm_check"
IFS='|' read -r runs witnessed last_start last_end <<EOF
$ledger
EOF
case "$runs$witnessed$last_start$last_end" in
    ''|*[!0-9]*) cannot "unexpected answer from rpt.etl_runs: $ledger" ;;
esac
if [ "$witnessed" -gt 0 ]; then
    echo "R4 fixed: $runs runs of $JOB in rpt.etl_runs since $SINCE, $witnessed reading changed orders; no login of $ROLE refused since${tolerated}."
    exit 0
fi
since_s=$(date -u -d "$since_log" +%s) || cannot "cannot read CHECK_SINCE '$SINCE'"
from=$since_s
[ "$last_end" -le "$from" ] || from=$last_end
if [ $((now - from)) -gt "$FRESH" ]; then
    echo "R4 present: no run of $JOB has landed in rpt.etl_runs for $(( (now - from) / 60 )) minutes since $SINCE: the dashboards are frozen${tolerated}."
    exit 1
fi
if [ "$last_start" -gt 0 ]; then
    next=$(( last_start + ( (now - last_start) / 3600 + 1 ) * 3600 ))
else
    next=$(( now + 3600 ))
fi
echo "remaining=$(( next - now )) no run of $JOB since $SINCE has read changed orders yet ($runs in rpt.etl_runs); $ROLE logs in${tolerated}."
exit 3
