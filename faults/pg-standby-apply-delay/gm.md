# pg-standby-apply-delay — GM notes

**What.** The standby the reports read replays every commit an hour after
it was made: one line in its seed `postgresql.conf`,
`recovery_min_apply_delay = '1h'`
([`inject/postgresql.conf.snippet`](inject/postgresql.conf.snippet)),
"time to stop a mistake before it reaches the reports", planted at render,
in effect from the standby's first start. Streaming looks healthy: the WAL
is received and flushed at once (`pg_stat_replication`'s write and flush
lags in milliseconds), only its replay waits. The reports reading the
standby miss the last hour: the 00:30 feeder (`feed-daily-figures`) the
evening's commits after 23:30, and every feeder the entries the staff make
after midnight for the day before (T33 of the clinic's traps; class V, M).

**Writing it into a scenario.**
- The node is a standby (`standby_of`), `postgres` 0.5.0, read by the
  reports. Add the snippet's line to `nodes/<standby>/postgresql.conf`
  after `hot_standby_feedback`.
- **The setup is unaffected.** `load-data` clones the standby last;
  PostgreSQL applies no delay before the clone is consistent, and
  `load-data`'s standby wait asks for the slot's sender `streaming`, which
  a delayed replay still is (the reports fixture's short test shows both,
  chunk 24).
- No parameter.
- **Aging minimum (spec D189).** `0m` for WAL received and not replayed
  (the first commit on the primary after the clone). A report missing rows
  shows at the first run of a feeder reading within the hour after its
  day's end: in the clinic `feed-daily-figures` at 00:30 (master spec
  17.2, spec D461), so raise the instance's `aging_minimum` to cover the
  first 00:30 after planting. `pg_stat_replication`'s `replay_lag` reads an
  hour only after an hour of the delay: never in a short test.
- Visibility: hidden, or known through the head office's complaint about
  the evening's missing consultations. The standby is fixable in the
  clinic; an issue may expect `fix`, `propose` or `report`.
- **With `purpose-herd-use-dropped`** (the clinic's s3): both bite feeders
  reading the standby; this one never hides a herd treatment (the 02:00
  feeder reads yesterday whole an hour after it ended), so s3's witness
  stands with it.

**Why it matters.** A delayed standby is a recovery tool; pointing the
reports at it makes every report an hour stale, and a day's report written
once (the feeders write their day once) stays short.

**Why it happens.** Someone wanted a safety net against a mistaken
`DELETE` and set it on the only standby, the one the reports read.

**What a good answer says.** Compares the received and replayed
positions, finds the delay, proposes 0 on the reports' standby and a
reload (the backlog replayed at once), the safety net moved to a standby
nobody reports from or to point-in-time recovery from the WAL archive, and
the short days rerun: their rows removed and each feeder moved to write
them again.

**Fix path.** On the standby, remove the line (or `ALTER SYSTEM SET
recovery_min_apply_delay = 0`), `sudo gm-reload-db`: the received WAL is
replayed within seconds. The days already written short stay short until
rerun (the feeder writes its day once): a finding, credited.

**Sealed check.** On the standby, as root, live state, through
`check-psql` as `gm_check`. *Fixed* (0) when `recovery_min_apply_delay` in
effect is 0; *present* (1) otherwise, with what is received and not
replayed and the last replayed commit's time. A file edited without a
reload reads present.
