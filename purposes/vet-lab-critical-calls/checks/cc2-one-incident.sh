#!/bin/sh
# CC2 one incident per uncalled result (vet-lab-critical-calls, v0.5 master
# spec 12.2 purpose 6; clinic-purposes.md section 10). Judged by runs: the
# watch's runs since the judged moment, from cron.job_run_details.
#
# Runs on the lab's database node (lab) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads lab through check-psql as gm_check (capture W4 items
# 0 and 3); it never runs the watch.
#
# - Exit 1: a result with two incidents or more (kind uncalled), one of them
#   opened since CHECK_SINCE; or the watch exists and has no successful run
#   recorded for two cadences while CHECK_SINCE is older than that (nothing
#   showing it alive: cron.log_run off, the job inactive or failing).
#   Exit 0: none, with an incident opened since CHECK_SINCE and a successful
#   watch run after it (the witness). Exit 3 otherwise, remaining= until the
#   next watch run. Exit 2: it cannot judge.
#
# The node has no Python: the verdict is computed in SQL, one line.
#
# Written for the clinic's names (DB, JOB below); the GM adapts them as it
# copies the purpose.
set -u
DB=lab                               # the target part's database, on this node
JOB=lab-critical-calls               # the watch's pg_cron job (cron.job.jobname)
PURPOSE=vet-lab-critical-calls
case ${CHECK_SINCE:-} in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "CC2 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
out=$(/usr/local/lib/gm/check-psql -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" \
      -v job="$JOB" -v purpose="$PURPOSE" 2>&1 <<'SQL'
WITH inc AS (
  SELECT ref, opened_at FROM ops.incidents WHERE purpose = :'purpose' AND kind = 'uncalled'),
dup AS (
  SELECT ref, count(*) AS n FROM inc
   WHERE ref IN (SELECT ref FROM inc WHERE opened_at > :'since'::timestamptz)
   GROUP BY ref HAVING count(*) > 1),
runs AS (
  SELECT d.start_time AS s FROM cron.job_run_details d JOIN cron.job j ON j.jobid = d.jobid
   WHERE j.jobname = :'job' AND d.status = 'succeeded' AND d.start_time > :'since'::timestamptz),
first AS (SELECT min(opened_at) AS o, count(*) AS n FROM inc WHERE opened_at > :'since'::timestamptz)
SELECT (SELECT count(*) FROM dup),
       coalesce((SELECT ref || ' ' || n FROM dup ORDER BY ref LIMIT 1), '-'),
       (SELECT n FROM first),
       (SELECT count(*) FROM runs),
       (SELECT count(*) FROM runs, first WHERE runs.s > first.o + interval '1 second'),
       coalesce(to_char((SELECT max(s) FROM runs) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '-'),
       floor(extract(epoch FROM now() - greatest(coalesce((SELECT max(s) FROM runs), :'since'::timestamptz),
                                                :'since'::timestamptz)))::integer,
       600 - mod(floor(extract(epoch FROM now()))::integer, 600) + 30
SQL
) || { echo "CC2 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
IFS='|' read -r dups first opened runs after last idle wait <<EOF2
$out
EOF2
if [ "$dups" -gt 0 ]; then
    echo "CC2 present: critical result ${first% *} has ${first#* } incidents ($dups results escalated more than once)"
    exit 1
fi
if [ "$idle" -gt 1260 ]; then
    echo "CC2 present: no successful run of the watch ($JOB) recorded since ${last#-}$( [ "$last" = - ] && echo "$CHECK_SINCE")"
    exit 1
fi
if [ "$opened" -gt 0 ] && [ "$after" -gt 0 ]; then
    echo "CC2 fixed: $opened incidents opened since $CHECK_SINCE, one per result, through $runs watch runs"
    exit 0
fi
echo "remaining=$wait $opened incidents and $runs watch runs since $CHECK_SINCE"
exit 3
