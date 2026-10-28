# Probe — scheduler-job-wrong-timezone

Descriptive only. As `player`:

1. On the scheduler node, `cat /srv/scheduler/jobs/jobs.yaml`: the
   `{JOB}` job carries a `timezone:` that is not the customer's (every
   other job's `at` is in UTC with no zone).
2. On the bastion, `cat ~/story.md`: the customer's zone.
3. `grep 'run job={JOB} ' /var/log/scheduler/scheduler.log`: its runs at a
   UTC time which, in the customer's zone, is `{OFFSET}` hours off the
   job's `at`.

Expected: 1 and 2 at any time; 3 from the first run at the wrong time.
