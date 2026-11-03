> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D239–D247 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and to the v0.4 drafts archived in the same pass were repaired to their archived paths (`archive/v0.4/`), still written from `specs/`.

- **D239 (2026-10-31, spec-writer, chunk 15a's item 1, reading 8.5 and
  16.2 as approved): f7's N is written by the scenario into its copy of
  `reporting`'s data file, the same number as the instance's `offset`,
  and `load-data` adds it to `customer_utc_offset`, wrapped as D168.**
  `render` writes no data file (8.5); the zone stays N hours off the
  customer's at any shift. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunks 15, 16.
- **D240 (2026-10-31, spec-writer, chunk 15a's item 2): f7's evidence is
  `\sf rpt.close_day`, not `\df+`.** PostgreSQL 18's `\df+` shows neither
  a procedure's source nor its `SET` clauses. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.2.
- **D241 (2026-10-31, spec-writer, chunk 15a's item 3, reading 12 as
  approved): a check on a database node judging a runner's job by a
  ledger there (f7) cannot read the runner: its judged moment is not
  raised to a reload, a fix is dated with `--since`, `remaining=` counts
  to the designed time, and a run is judged on the rows it still owns.**
  12 keeps a check on its instance's node; 18.2's f7 cycle passes
  `--since`, as f5's. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  12.1, 12.5, 18, 19; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md)
  chunk 17, release gate.
- **D242 (2026-10-31, spec-writer, chunk 15a's item 4, reading 16.2 as
  approved): f9's planting grants `bi_etl` `CREATE` on `rpt`, so its job
  recreates a dropped table.** 16.2's "dropping the table alone, which the
  job refills" needs it; the grant is the fault's, not the baseline's
  (access model 9.1), and its check does not require it revoked. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.2;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 15.
- **D243 (2026-10-31, spec-writer, chunk 15a's item 5): `dba` unschedules
  another role's `pg_cron` job by its id; by name `cron.unschedule` finds
  the caller's own jobs only.** pg_cron's behaviour, which f9's fix meets.
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2, 16.5; [versions/v0.4/access-model.md](versions/v0.4/access-model.md) 9.4.
- **D244 (2026-10-31, spec-writer, chunk 14's item 1, reading 16.2 as
  approved): f2's producer path is a fix only with the flags of those who
  withdrew since the release repaired too, dated with the GM's `--since`;
  the producer restored alone stops new drift and the check reads
  present. After the jobs' fix, repairing the flags stays the *improve*.**
  L2 and M2 judge consent by the latest event, so the jobs keep taking
  everyone still flagged. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.1, 16.2; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunks 14, 16.
- **D245 (2026-10-31, spec-writer, chunk 14's item 2, reading 16.2 as
  approved): f5's planting also ends `shop_etl`'s open sessions.**
  PostgreSQL checks `VALID UNTIL` at authentication only and a runner
  keeps its sessions, so without it "every run since fails" would wait
  for a reconnection; `db`'s log shows the sessions ended at the
  planting moment. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 14.
- **D246 (2026-10-31, spec-writer, chunk 14's item 3, reading 12.5 and
  D241): f5's check counts `remaining=` to the hourly job's designed
  minute read from the ledger's last start, carried forward by whole
  hours; no parameter, no code change.** A designed-time parameter would
  be as blind to a move as the ledger, and `remaining=` never changes a
  verdict; a harness that moves the job waits for the moved time. Now
  in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 12.5;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 17.
- **D247 (2026-10-31, spec-writer, chunk 14's item 4, reading 16.2): A
  five-minute job's fault needs an hour from its first run after
  planting, as quarter-hour and hourly ones do: f1's minimum is 1h.**
  Shipping ramps up after the load; f1's first duplicates came at
  T0 + 19 minutes on armenelos. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.2; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunks 14, 16.
