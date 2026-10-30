# scheduler-job-wrong-timezone — GM notes

**What.** A job of a scheduler node's `jobs.yaml` (the `job` parameter)
runs in the wrong time zone: `offset` hours off its designed time of day
in the customer's zone. Planted at render (spec D168): the scenario
writes `timezone_offset: <offset>` on the job beside its `at` as
designed; render keeps the `at` and writes `timezone: Etc/GMT∓M`, M the
game's shift plus the offset, wrapped into UTC−12..UTC+14 (8.3). Every
other job of the file is in UTC with no zone.

**Writing it into a scenario.**
- `offset` is an integer, never 0, equal to the job's `timezone_offset`
  (the loader checks neither; keep them equal). The loader accepts a
  `timezone_offset` only on a node where a fault instance's seed change
  edits `jobs.yaml`.
- Give the job a reason to run at its time (an export the customer
  reads in the morning, a roll-up after the close of day) and put the
  customer's zone in the story (`{{customer_timezone}}`, filled by
  render), so the player can tell.
- **Aging minimum (spec D189).** The definition's 1h counts from the
  first run at the wrong time: raise the instance's `aging_minimum` to
  that run's offset from the designed T0 plus 1h. Example: T0 22:00, the
  export designed at 02:00 with `offset: -8` runs at 10:00 the
  customer's time, 12h after T0: `aging_minimum: 13h`.

**Why it matters.** A job that runs at the wrong moment of the business
day takes an export before the data is complete, or a batch into the
peak; the times in the logs look right to whoever reads them in UTC.

**Why it happens.** A server's zone changed, a container's `TZ` unset, a
cron copied from another region's server.

**What a good answer says.** Reads the job's `timezone` beside the
customer's zone, works out when it really runs, and gives it the
customer's zone (or its `at` in UTC).

**Fix path.** Through the write override `/srv/scheduler/jobs`: edit the
job (its `timezone`, or its `at` in UTC with the zone removed), then
`sudo gm-reload-scheduler`, which prints the job's next run in UTC.

**Sealed check.** Files only. From the seed copy
`/opt/gm/seed/jobs.yaml` it takes the designed `at` and the planted zone
M, and the customer's offset as M minus `offset` brought into −11..+12
(the shift's range); no shift is an input. *Present* while `jobs.yaml`
is not reloaded, while the job is gone, or while the loaded job's runs
over the next 8 days (the program's own cron) are not the designed `at`
read in the customer's zone; *fixed* once they are the same instants,
whatever the form.
