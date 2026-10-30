# scheduler-batch-at-peak — GM notes

**What.** A batch meant for the night (the `job` parameter of a scheduler
node's `jobs.yaml`) is timed inside the daily peak of the node's
schedule (the `shape` parameter). Planted at render: the scenario writes
the job's `at` in scenario time; render writes it in UTC.

**Writing it into a scenario.**
- The job's key is a transaction updating rows the daytime streams update
  (lock waits at the peak), and long enough to be felt.
- `quiet-below` (default 0.5) lies below every business hour's
  multiplier of the shape and at or above the night's.
- **Aging minimum (spec D189).** The evidence shows at the job's runs, so
  the definition's 1h counts from the job's first run at its planted
  time. Place that run inside the aging and raise the instance's
  `aging_minimum` to its offset from the designed T0 plus 1h (the loader
  cannot check the offset). Example: T0 22:00, the batch at 12:00:
  `aging_minimum: 15h`.
- The answer key adds the PostgreSQL log's lock waits at the job's time
  (`node:<db>`, with `log_lock_waits`) and the latency in Grafana.

**Why it matters.** The batch competes with the day's traffic for CPU,
I/O and row locks exactly when users are there: freezes and timeouts
around its time, every day.

**Why it happens.** A cron written in UTC on a server, read as local
time; a job moved "temporarily" during an incident; a new batch scheduled
without looking at the traffic.

**What a good answer says.** Reads the job's time in the customer's
zone, ties the daily slowdown and lock waits to its runs, and moves it to
a quiet night hour (checking it ends before the morning).

**Fix path.** Through the write override `/srv/scheduler/jobs`: edit the
job's `at` (in UTC, or with a `timezone:`), then `sudo
gm-reload-scheduler`, which prints the job's next run in UTC.

**Sealed check.** Files only: the shape from the rendered
`/opt/gm/seed/schedule.yaml` (per UTC weekday, so no shift), the loaded
job's `at` and `timezone` read by the program's own cron. *Present*
while `jobs.yaml` is not reloaded, while the job is gone (the batch must
still run), or while a run in the next 35 days falls in a UTC hour whose
multiplier on that weekday is above `quiet-below`; *fixed* once every run
is in a quiet hour.
