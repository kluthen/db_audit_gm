# purpose-day-boundary-wrong-zone — GM notes

**What.** The sales reporting purpose's nightly close, `rpt.close_day()`
on the target database node (`reporting`), cuts "yesterday" in a zone
`offset` hours off the customer's: the procedure carries `SET TimeZone`
to that zone and takes its day from `current_setting('TimeZone')`
instead of `rpt.business_settings`. Every night it closes a day whose
boundaries are `offset` hours off the shop's local midnight, and writes
its hours with labels in the wrong zone; the hourly roll-up then leaves a
closed day's orders and revenue alone (chunk 10's design), so the wrong
day stays. Breaks R3, and the day against the source's R2 (16.2, f7).

**Writing it into a scenario.**
- The purpose's target part is on the node, with its `rpt.close_day()`,
  `rpt.business_settings` and `rpt.etl_runs` (the purpose's
  `material/target/data.sql` in the node's data file).
- The seed change is `data`, the node's data file (spec D226): append
  `inject/close_day.sql.snippet` after the purpose's material, `{OFFSET}`
  replaced by the instance's `offset` (an integer, never 0; the loader
  checks neither the equality nor the range; left as is, the data load
  fails). The zone is computed at load from `customer_utc_offset` plus
  the offset and wrapped into UTC−12..UTC+14 (8.5), so the fault holds at
  any shift, a shift of 0 included. render does not write it: render's
  shift reaches the data file only through `load-data`'s variables.
- `close-at` is the runner's `rollup-close` time in the customer's zone
  (`01:30` by default); the other parameters' defaults are the first
  v0.4 scenario's names.
- **Aging minimum (spec D189).** 1h from the close's first run after T0:
  T0 22:00, close 01:30, so the instance's `aging_minimum` is at least
  4h30 plus 1h. The evidence then grows by one wrong day a night.
- In a game the close runs on `bi`, a report-only node the players cannot
  move it on, and the expected resolution is *propose* (16.1, 16.5): the
  check is expected to stay present at the final answer.

**Why it matters.** The business day is the customer's: the accountant,
the dashboard and the shop's own reports all count from the shop's
midnight. A day cut elsewhere moves orders from one day to the next
every night, so no daily figure ever matches the shop's, and the gap
looks like noise.

**Why it happens.** The agency wrote the procedure in its own office's
zone, or a session zone set "to be explicit", and tested it on a day
whose edges had no orders.

**What a good answer says.** Compares a closed day with the shop's local
day and finds orders moved across midnight, reads the procedure (`\sf
rpt.close_day`) and its zone against `rpt.business_settings`, and
proposes that the close take the customer's zone from
`business_settings`. Restating the days already closed is a follow-up.

**Fix path** (an overstep in a game, 16.5). As `dba` on the node:
`CREATE OR REPLACE PROCEDURE rpt.close_day()` with its first line back
to `SELECT timezone INTO STRICT tz FROM rpt.business_settings;` (the
`SET TimeZone` is then harmless, or removed with it). The next close
proves it; running `CALL rpt.close_day()` by hand is a run outside the
schedule, which the rules forbid, and is not taken as the resolution.

**Sealed check** (`judges: runs`, on the target node). Reads the close's
own ledger, `rpt.etl_runs`, rows of `job` finished after `CHECK_SINCE`,
and each day row such a run still owns in `rpt.sales_daily` (`run_id`):
its orders and revenue against the source's local day (the source's
`business_settings` zone, read as `gm_check` with `check-psql --node`),
once that day was over 60 s before the run started. *Present* (1) when
more than `CHECK_THRESHOLD` closed days differ; *fixed* (0) when none
does and a compared day had orders in its first and last local hour (the
witness); *too soon* (3) with no run since, or no witness yet,
`remaining=` counting to the next `close-at` in the customer's zone.
- The close is scheduled on the runner, which a check on this node cannot
  read: the judged moment is not raised to the runner's reload, and
  `remaining=` is the designed time, not a moved one. A fix of the
  procedure is outside the runner anyway: judge it with `gmctl check
  scenarios/<id> --playground <name> --instance <id> --since
  2026-11-01T15:20:00Z`, the fix's time from the players' report (12.1).
- After a 14:00 hand-over the next close is the next night: the check
  reads 3 for the rest of a game, and stays 1 at the hand-over check.
- A day row belongs to the last close that wrote it: a later close of
  the same day (the job moved twice in a day, or a run by hand) replaces
  it, and the earlier run's violation is no longer judged. A night's
  close closes a new day, so in a game each run keeps its own row.
- A close run by hand writes an `etl_runs` row like any other and can
  make the check read *fixed*; the runner's log shows whether
  `rollup-close` ran then.
