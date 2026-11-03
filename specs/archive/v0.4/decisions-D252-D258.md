> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D252–D258 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and to the v0.4 drafts archived in the same pass were repaired to their archived paths (`archive/v0.4/`), still written from `specs/`.

- **D252 (2026-10-31, owner ruling on G10, relayed by the wave driver):
  f10's normal run at 640M is accepted as measured, 327 MiB against the
  320 MiB half; no criterion change, no re-run.** Chunk 15b's game: 238
  MiB without page cache, the thirty-day backfill killed. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) G10, chunk 15, release gate.
- **D253 (2026-10-31, owner ruling on O140, "Define it now"):
  `separation: instance` is a rule of G1, every database of a node
  holding one of the class's locations, `postgres` aside, being one of
  them; refused with `locations: any`. Built by chunk 20, wave 3.**
  Option (a), recommended. Closes O140. Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  6.9, 11.4, 11.6; [formats.md](formats.md); [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 20.
- **D254 (2026-10-31, spec-writer, chunk 15b's item 1, reading 16.2): A
  `state` fault may carry `seed_changes`, in the scenario's copies from
  T0, its scripts planting the rest later.** f10 is "seed-file at T0,
  state at `handover-12h`"; the fault template's comment and the
  loader's material check are widened by chunk 20. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 6.3;
  [formats.md](formats.md) "Fault definition"; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 20.
- **D255 (2026-10-31, spec-writer, chunk 15b's item 2, reading 9.6 and
  16.3): f10's roll-up reads the orders through its own foreign table,
  `src.sales_detail_orders` (with `updated_at`, no `customer_id`), so the
  close's `src.orders` keeps only the close's columns.** 9.6 keeps each
  foreign table to its reader's needs. Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 9.6, 16.3.
- **D256 (2026-10-31, spec-writer, chunk 15b's items 3 and 4, reading
  12.7, 14 and 16.3): f10's check dates the planting from the backfill
  request's `requested_at`, exits 2 when it cannot confirm the incident,
  and matches the kill line as PostgreSQL 18 writes it ("client
  backend") or as earlier releases do ("server process").** A check
  judging no runs gets no `CHECK_SINCE` (14). Now in:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 16.3.
- **D257 (2026-10-31, spec-writer, chunk 15b's item 5, reading 16.3): The
  night after a killed backfill reads from the last finished run, one
  day back when the killed run was the entry's first; chunk 9's "~2
  days" holds only after an earlier normal night, and still completes.**
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md)
  16.3 step 5.
- **D258 (2026-10-31, owner ruling relayed by the wave driver, built in
  54bc74a): `load-data`'s last step removes the `pg_cron` launcher's
  start-up failures, and only them, from the closed server-log files of
  every database node holding `pg_cron`, after the collector switches
  files; a launcher not connected within 60 s fails the step.** The
  owner: "the pg cron problem (34 error report) we need to fix this".
  Rejected: a restart after the load (the preload is needed for `CREATE
  EXTENSION`, written lines stay); `cron.database_name = 'postgres'`
  (changes the loader rule, the data file, f9 and G3); documenting the
  lines (refused). Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.2, 14.
