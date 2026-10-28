# Probe — scheduler-batch-at-peak

Descriptive only. As `player`:

1. On the scheduler node, `cat /srv/scheduler/jobs/jobs.yaml`: the
   `{JOB}` job's `at` (UTC), read in the customer's time zone
   (`~/story.md` on the bastion), falls in the business day.
2. `grep -E 'run job={JOB} |key minute=' /var/log/scheduler/scheduler.log`:
   the job's runs at that time, and the other keys' `p95_ms` rising in
   the same minutes.
3. From the bastion during a run, `pg_stat_activity`: the batch active,
   other sessions waiting on a lock.

Expected: 1 at any time; 2 and 3 from the job's first run at its planted
time.
