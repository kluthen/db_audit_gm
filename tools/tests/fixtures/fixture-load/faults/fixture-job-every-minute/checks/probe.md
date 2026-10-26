# Probe

As `player` on the scheduler node (`ssh producer` from the bastion):
`grep 'run job=<job> ' /var/log/scheduler/scheduler.log | tail` shows a run
every minute, and `/srv/scheduler/jobs/jobs.yaml` gives the job `at: "* * *
* *"`. Expect both while the fault is present.
