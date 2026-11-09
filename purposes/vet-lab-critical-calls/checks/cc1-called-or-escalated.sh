#!/bin/sh
# CC1 every critical result read back within the hour, or escalated
# (vet-lab-critical-calls, v0.5 master spec 12.2 purpose 6; clinic-purposes.md
# section 10): every critical result measured since the judged moment has a
# read-back call within 60 minutes, or an incident by the next watch run. A
# deadline invariant: it judges triggers.
#
# Runs on the lab's database node (lab), the target part's, as root, fed to
# `sh -s`, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the purpose has no runner
# (its watch is a pg_cron job in lab), so it reads lab through check-psql as
# gm_check, the watch's runs from cron.job_run_details (capture W4 items 0
# and 3); it never runs the watch.
#
# - A trigger: a result flagged critical-low or critical-high measured since
#   CHECK_SINCE. Its deadline: measured_at plus 60 minutes. Handled: a call
#   read back by then, or an ops.incidents row (kind uncalled, ref the result)
#   opened by the end of the first watch run after the deadline.
# - Exit 1: a trigger past its deadline neither called in time nor escalated
#   by that run, or no watch run within two cadences after its deadline.
#   Exit 0: every trigger past its deadline handled, at least one (the
#   witness). Exit 3 otherwise, remaining= until the next deadline or watch
#   run. Exit 2: it cannot judge.
#
# The node has no Python: the verdict is computed in SQL, one line a
# critical result (verdict|result|measured|watch run|seconds to wait).
#
# Written for the clinic's names (DB, JOB below); the GM adapts them as it
# copies the purpose.
set -u
DB=lab                               # the target part's database, on this node
JOB=lab-critical-calls               # the watch's pg_cron job (cron.job.jobname)
PURPOSE=vet-lab-critical-calls
case ${CHECK_SINCE:-} in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "CC1 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
out=$(/usr/local/lib/gm/check-psql -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" \
      -v job="$JOB" -v purpose="$PURPOSE" 2>&1 <<'SQL'
WITH runs AS (
  SELECT d.start_time AS s, coalesce(d.end_time, d.start_time) AS e
    FROM cron.job_run_details d JOIN cron.job j ON j.jobid = d.jobid
   WHERE j.jobname = :'job' AND d.status = 'succeeded' AND d.start_time > :'since'::timestamptz),
t AS (
  SELECT r.id, r.measured_at AS m, r.measured_at + interval '60 minutes' AS due,
         (SELECT min(c.called_at) FROM lab_critical_calls c WHERE c.result_id = r.id AND c.read_back) AS called,
         (SELECT min(i.opened_at) FROM ops.incidents i
           WHERE i.purpose = :'purpose' AND i.kind = 'uncalled' AND i.ref = r.id::text) AS inc
    FROM lab_results r
   WHERE r.flag IN ('critical-low', 'critical-high') AND r.measured_at > :'since'::timestamptz),
v AS (
  SELECT t.*, x.s AS run_s, x.e AS run_e
    FROM t LEFT JOIN LATERAL (SELECT s, e FROM runs WHERE s >= t.due ORDER BY s LIMIT 1) x ON true)
SELECT CASE WHEN called IS NOT NULL AND called <= due THEN 'handled'
            WHEN run_s IS NULL AND now() > due + interval '20 minutes' THEN 'late'
            WHEN run_s IS NULL THEN 'pending'
            WHEN inc IS NOT NULL AND inc <= run_e + interval '5 seconds' THEN 'handled'
            ELSE 'late' END,
       id, to_char(m AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       coalesce(to_char(run_s AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '-'),
       greatest(1, ceil(extract(epoch FROM due + interval '10 minutes' - now())))::integer
  FROM v ORDER BY 1, m, id
SQL
) || { echo "CC1 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
late=$(printf '%s\n' "$out" | grep -c '^late|' || true)
handled=$(printf '%s\n' "$out" | grep -c '^handled|' || true)
pending=$(printf '%s\n' "$out" | grep -c '^pending|' || true)
if [ "$late" -gt 0 ]; then
    first=$(printf '%s\n' "$out" | grep '^late|' | head -n 1)
    id=$(echo "$first" | cut -d'|' -f2); m=$(echo "$first" | cut -d'|' -f3); run=$(echo "$first" | cut -d'|' -f4)
    if [ "$run" = - ]; then why="no watch run since its hour ran out"
    else why="not read back, and no incident by the watch run of $run"; fi
    echo "CC1 present: critical result $id, measured at $m: $why ($late late since $CHECK_SINCE)"
    exit 1
fi
if [ "$handled" -gt 0 ]; then
    echo "CC1 fixed: $handled critical results measured since $CHECK_SINCE read back within the hour or escalated by the next watch run ($pending pending)"
    exit 0
fi
if [ "$pending" -gt 0 ]; then
    wait=$(printf '%s\n' "$out" | grep '^pending|' | cut -d'|' -f5 | sort -n | head -n 1)
    echo "remaining=$wait $pending critical results measured since $CHECK_SINCE, none past its hour and the next watch run"
    exit 3
fi
echo "remaining=3600 no critical result measured since $CHECK_SINCE"
exit 3
