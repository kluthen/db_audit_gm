# purpose-heavy-job-on-database-node — GM notes

**What.** The agency runs a heavy transformation from the reporting
database node's own crontab: `rpt.sales_detail_rollup()`, called nightly
at 03:00 with `psql` as the loader (`bi_etl`), builds every order changed
since its last run into one document with a single `jsonb_agg` and
inserts it. On a normal night it fits. During the aging a one-off
**backfill request** arrives (in the story, the agency changed its
formula): a row asking for the last `days` days. The next run takes it,
commits that it took it, and reads the whole window into its backend: the
aggregate's memory is unbounded by `work_mem`, the backend grows past the
node's limit, through the swap Swarm gives it, and the kernel kills it.
The postmaster ends every other session and recovers by itself within
seconds; s6, `sshd` and the cron daemon keep running. The request stays
taken and never done, so the next night runs normally. At hand-over the
incident lies in the recent past and the system is fine (master spec
16.3, D209): the players investigate and *report*.

**Writing it into a scenario.**
- The node is a `postgres` 0.4.0 database node holding the sales
  reporting purpose's target part (`reporting` in the first v0.4
  scenario), on a host that is not shared: the fault declares
  `needs_unshared_host`, `gmctl fit` refuses a mapping that places the
  node on a `shared` host, and the designed placement puts it on the
  first host, the manager (13.3).
- Two seed changes, in the scenario's copies from T0: `data` (spec D226),
  append [`inject/sales_detail_rollup.sql.snippet`](inject/sales_detail_rollup.sql.snippet)
  after the purpose's material (its own foreign table
  `src.sales_detail_orders` with `updated_at`, since the close's
  `src.orders` declares only the close's columns; the request table; the
  document table; the procedure); and `crontab`, the entry of
  [`inject/crontab.snippet`](inject/crontab.snippet) under the
  `PGPASSFILE` line, at 03:00 scenario time (render shifts it to UTC).
  The node names `bi_etl` in `crontab_roles`. Both are written for the
  first v0.4 scenario's names; adapt them as you copy, `database` equal to
  what they create.
- The state change, [`inject/10-backfill-request.sh`](inject/10-backfill-request.sh),
  is the instance's `plant_at`: `handover-12h` in the first v0.4 scenario
  (02:00 at a 14:00 hand-over, an hour before the entry's run), planted by
  `gmctl inject --at` as `start-load` lists it. Its `requested_at` is the
  planting moment the check reads.
- **The window (G10, spec D213, D227).** `days` (30) must need more than
  twice the node's memory limit in the roll-up's backend, and a normal
  night less than half of it, measured as the cgroup's `memory.peak`
  (with swap, as Swarm runs it). The first scenario's thirty days read
  its whole restored history (about 15 days, 300 000 orders). Measured
  on `fixture-campaign` (armenelos, 2026-10-31, 640M, `shared_buffers`
  128MB): the backfill was killed after 11 s with 1258 MiB of the 1280
  MiB the cgroup allows in use (640 of memory, 640 of swap); a normal
  night (one day, 35 390 orders) peaked at 327 MiB, 238 MiB without the
  page cache. The owner accepted the 327 MiB as measured (2026-10-31).
  A scenario with another history, limit or `shared_buffers` measures
  again before it is played; a shortfall goes to the owner before
  anything is reshaped (D213).
- **Aging minimum (spec D189).** 30m from the entry's first run after
  planting: the scenario raises the instance's `aging_minimum` to that
  run's offset from T0 plus 30m (03:00 from a 22:00 T0: 5h30m). Keep the
  run away from the early check and from the nightly close (01:30): the
  recovery ends every session on the node.
- Visibility: known (I6 in the first v0.4 scenario). Resolution: report
  only, whatever the write policy; the answer key judges the report.

**Why it matters.** A database server sized for its own work carries a
transformation that grows with its input; one large request is enough to
crash it, ending every session (the dashboards', the hourly loader's) and
wiping its statistics. "It restarted itself and is fine now" hides that
the next large backfill will do it again.

**Why it happens.** Compute pushed into the database "because the data is
there", a naive aggregate that builds the whole document in memory, and a
backfill path nobody sized.

**What a good answer says.** Dates the incident from the log (the kill of
the client backend running `CALL rpt.sales_detail_rollup()` by signal 9, the
four recovery lines, connections back seconds later), ties it to memory
(`oom_kill` in `memory.events`, `memory.peak` at the limit; the reset
statistics), finds the cause (the crontab entry, the job's log ending
with the connection lost, the run without end in `rpt.etl_runs`, the
thirty-day request taken and never done, the procedure's single
`jsonb_agg`), and recommends moving the computation off the database
node to a transformer node sized for it, reading the window in batches,
with backfills bounded. Moving the entry to another hour, deleting it,
or calling the same `CALL` from another node does not move the
computation (16.5): the feedback says so.

**Overstepping.** The node is fixable, so a player can edit the crontab,
the procedure or the request. The incident check is unaffected (it reads
the log since the planting moment); the report is judged as if nothing
had changed, and the feedback names an unrequested change (16.5). A
player re-running the job by hand, or moving its entry to the next
minute, runs it outside its schedule: the same overstep as on any node.

**When it did not happen (16.3).** The hand-over check must find the
kill and the recovery. If the run completed (the request is taken *and*
done), never ran (the request is not taken), or the check cannot read
the request, the check errors with what it found, and the hand-over
check fails, as for a failed planting. **Never re-plant it within the
aging**: the job runs nightly, so a second request would be taken only
the next night, past the hand-over. Offer the initiator to set the game
up again (a new deployment), and look at why first: the window against
the node's limit (a changed history or limit), the entry's time in the
crontab, the cron daemon (`cron` down), the loader's password file.

**Sealed check.** On the node, as root, an incident check (12.7). It
reads the earliest request's `requested_at` through `check-psql`, then the
server log (`postgresql-*.log`, the seed's `%t` prefix in UTC, English
messages) since then. *Present* (1) once a backend killed by signal 9
and the recovery after it ("terminating any other active server
processes", "all server processes terminated; reinitializing", the
automatic recovery, "ready to accept connections") are there, whatever
the crontab holds since; its line names the kill's time, the process and
`oom_kill` from `memory.events`. It never answers 0 or 3: it proves the
incident happened, nothing more. *Error* (2) with the reason otherwise:
not planted, no kill since the request (not yet, or a failed planting),
a kill without its recovery yet, or the request unreadable (PostgreSQL
recovering at that very moment: run it again).

**Risks, accepted (16.3).** Recovery ends every session on the node (the
transformer's, the consumer's, a `pg_cron` job running then, any GM check
session): they reconnect at their next run, an error in their logs. Every
cumulative statistic on the node restarts at the incident, so no other
fault's evidence there may rest on statistics. While the backend swaps,
the host slows for the seconds to minutes before the kill: hence 03:00,
alone, and never a shared host.
