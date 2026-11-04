# fixture-job-every-minute

A fixture fault of `fixture-load` (`tools/tests`, v0.3 chunk 12), not a
catalog fault. The job named by the `job` parameter is scheduled every
minute in the scheduler node's `jobs.yaml` instead of once an hour. Its
query is cheap: the fault shows in the scheduler's log (a `run` line a
minute) and counters, and harms nothing.

The sealed check is behavioural (`behavioural: true`): it judges the cause
in `jobs.yaml` and whether the program loaded the fixed file, then the job's
runs over the answer key's window, and reads "too soon to tell" (exit 3)
until that window has passed since the reload. `tools/tests/smoke-load.sh`
fixes it through the producer's write override to see that exit 3, then
the fixed reading.
