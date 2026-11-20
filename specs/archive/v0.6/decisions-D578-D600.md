> **Archived 2026-11-20.** v0.6 closed (released at its release gate, G11 cleared by the owner on 2026-11-20, `v0.6-rg` merged into `main` as `fceda75`); entries D578 to D600 (D579 never issued) of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and the two drafts archived in the same pass were repaired to their archived paths (`archive/v0.6/`), still written from `specs/`.

- **D578 (2026-11-19, spec-writer, chunk 11b's measured deviations):
  the campaign's f5 carries no `suppressed_by` over f4 and f7,** whose
  trails are rows in `reporting`, `rpt.etl_runs` and logs, which no
  exporter reads (D548's case): no covered fault uses D543's rule, which
  stands, unit-tested only. A report-only node's keys are timed from a
  fill or with psql. Now in: [master spec](versions/v0.6/master-spec.md#95-fault-eligibility)
  6.9, 9.5, 9.7, 9.8; [build plan](archive/v0.6/build-plan.md) chunks 10, 11, 12, G10.3.
- **D580 (2026-11-19, spec-writer, gate G10.3 after wave 3's gate):
  wave 3's forms written as built,** each checked against the code on
  `v0.6-w3`; none contradicts the spec, which they complete (reported,
  not settled: 9.9 fix 5's `gauge_before`, which no covered fault carries).
  Now in: [formats.md](formats.md) v39 "Scenario", "Local implementation",
  "Fault definition"; [master spec](versions/v0.6/master-spec.md) 6.3, 6.7, 6.9, 9.5, 9.7, 9.8, 12.1, 18.
- **D581 (2026-11-19, spec-writer, chunk 10's choice routed to G10.3):
  the seam's join is checked on size gauges only,** within the larger of
  1 % and the tail's own largest step; `negative` holds a series the
  system keeps below zero to its own value; `empty` added. Other gauges
  are drawn from the tail's level, so no join to check. Now in:
  [formats.md](formats.md) v39; [master spec](versions/v0.6/master-spec.md#121-short-tests-only) 9.4 step 8, 12.1.
- **D582 (2026-11-19, spec-writer, capture W3 item 7 as built): a fake
  game's restart with no history rebuilds on the real clock,** refused
  instances still out, the story line and the record kept; the spec said
  only "as in a real game". From the snapshot it stays the same fake game.
  Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode) 9.4;
  [formats.md](formats.md) v39.
- **D583 (2026-11-19, spec-writer, chunk 10's choice routed to G10.3):
  one history import at a time (a run lock), and once one is recorded
  `ok` no run imports again, a failed seam included;** a failed import is
  retried by hand, its blocks removed first. So the timer's run after a
  hand run, or a second hand run, is harmless. Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4 step 8; [formats.md](formats.md) v39.
- **D584 (2026-11-19, the owner, after G10.3: "Fix in wave 4"): the
  shop's f8 (`pg-join-index-missing`) gains a measured `gauge_before` on
  `pg_database_size_bytes`, with its `# measured:` comment,** so master
  spec 9.9 fix 5 holds as written rather than becoming a limit. Chunk 12
  takes it (its shop game plays f8). The value's form raised as O292.
  Now in: [build plan](archive/v0.6/build-plan.md) v13, chunk 12, G13.
- **D585 (2026-11-19, the owner: "go with the recommended option on
  O292"): a `gauge_before` adds its `value` to the level drawn before
  the planting, instead of holding one level;** f8's is the dropped
  index's size, so the shop's size keeps the load's shape (9.9 fix 5 as
  written). Closes O292. Now in: [formats.md](formats.md) v40 "Fault
  definition"; [build plan](archive/v0.6/build-plan.md) v14, chunk 12, G13.
- **D586 (2026-11-19, the owner, on capture W4 item 2: "Scale R to
  span"): the shop's M1 comparison scales run R to the short game's
  span,** M1 dumped at the virtual T0 and at the read, each expected
  value T0 + s × (R − T0), s R's share of inserted rows in the game's
  span; insert-driven measures judged within ±3 %, the rest reported; the
  shop played as it is. Now in: [master spec](versions/v0.6/master-spec.md) 12.1; [build plan](archive/v0.6/build-plan.md) v15, chunk 12b.
- **D587 (2026-11-19, the owner, after G8's note 3: "didn't know pg19
  was out yet. that's great news. Move to pg19 everywhere."): PostgreSQL
  19 in every brick and scenario of v0.6,** the server and every client
  tool and library (libpq included, so `scheduler`, `api` and
  `health-check` leave Debian's 17), folded into the unreleased versions
  (6.8), under D396. It brings pgAudit 19.0, which carries 18.1's changes,
  so D539's deferral ends. Now in: [master spec](versions/v0.6/master-spec.md) 6.8, 7.7, 8; [build plan](archive/v0.6/build-plan.md) v16, chunks 17a to 17c.
- **D588 (2026-11-19, the owner, the same answer): zlib1g's DSA-6613-1
  (G8's note 1, the base layer, not reachable) is handled at the release
  gate:** an `apt-get upgrade` or `zlib1g` named in the Dockerfiles, all
  ten bricks, folded into the unreleased versions. Now in: [build plan](archive/v0.6/build-plan.md) v16, release gate item 2.
  Corrected 2026-11-20 (G9.3): DSA-6613-1's zlib findings are
  CVE-2026-85091 and CVE-2026-27171 only. CVE-2026-76844, counted with
  them since G9.2, is not zlib's: Debian's tracker marks it NOT-FOR-US,
  a webpack-dev-middleware path traversal that OSV's Debian import
  misattributes to zlib.
- **D589 (2026-11-19, spec-writer, placing D587): chunk 17 inserted in
  wave 4 before 12b, split in three:** 17a the images on 19 and every
  path, test and generated file they bind (one commit: the data path
  `/var/lib/postgresql/19/data` and the brick digests tie them); 17b
  `postgres_exporter` 0.21.1 and pgwatch 6.2.0 (G9.2's picks, D396) and
  fake aging's re-measure on 19; 17c the game's text and the faults that
  read audit lines, re-run on 19. G9.2 (preflight done, CLEAR WITH
  NOTES; its post-change half open), G14 (no game on the host relies on
  the 18 image under the reused tags), G15 (O294, O295). Now in: [build plan](archive/v0.6/build-plan.md) v16.
- **D590 (2026-11-19, spec-writer, on D587): fake aging's numbers
  measured on 18 stand, one size re-measured:** the service times,
  signatures, WAL rates and run R stay (9.7: one-off per fault version);
  M1's judged measures and M3's judged traffic are counts the workload
  drives, which the server's major doesn't move, so 12.1's comparisons
  against R still prove the fill reproduces a real day (D586). The heap
  and btree page formats are unchanged in 19, so `fixture-dropped-index`
  is re-measured on 19 (17b) as the check of f8's value from R. Chunk 12b
  reports the tail's latencies and WAL rates against the 18 files, never
  judged. Now in: [build plan](archive/v0.6/build-plan.md) v16, chunks 17b, 12b.
- **D591 (2026-11-19, the owner, on O294: the recommendation, "Known
  limit"): pgBadger 13.3's empty checkpoint section on PostgreSQL 19 is
  a known limit,** named in `postgres`' `docs/gm.md` and v0.6's release
  notes; the next pgBadger release that reads 19's lines is taken under
  D396. No fault's witness reads that section, and no fix exists
  upstream. Closes O294. Now in: [build plan](archive/v0.6/build-plan.md) v17, chunk 17c, G15.
- **D592 (2026-11-19, the owner, on O295: the recommendation, "Add the
  new setting"): every seed setting `log_autovacuum_min_duration = 0`
  sets `log_autoanalyze_min_duration = 0` beside it** (56
  `postgresql.conf` files), what those seeds feed regenerated, so the
  customers' logs keep their autoanalyze lines on 19 as designed.
  Closes O295. Now in: [build plan](archive/v0.6/build-plan.md) v17, chunk 17c, G15.
- **D593 (2026-11-20, the owner, on chunk 12b's shop game: "Report
  only"): `n_live_tup` leaves the shop's M1 judged set and is reported
  as a figure;** it is the estimate VACUUM and ANALYZE overwrite, not a
  count inserts drive (run R's `daily_sales` reads 30 for 15 rows).
  Refines D586. Now in: [master spec](versions/v0.6/master-spec.md) 12.1; [build plan](archive/v0.6/build-plan.md) v18, chunk 12b.
- **D594 (2026-11-20, the owner, on chunk 12b's shop game: "Fix a+b+c
  now"): the forged past's counters follow what drives them,** fixed
  before 12b resumes: the scheduler's roles and databases follow the
  load, the monitoring's own series stay flat; no 0.25 floor on the
  load's ratio; each database's `pg_stat_database_*` shaped by the fill's
  transactions there. `set_clock`'s extra commit stays reported, not a
  tell. Now in: [master spec](versions/v0.6/master-spec.md) 9.9 fix 12; [build plan](archive/v0.6/build-plan.md) v18, chunk 18.
- **D595 (2026-11-20, spec-writer, placing D594): chunk 18 inserted in
  wave 4, chunk 12b resuming after it;** the scheduler 0.4.0 rebuilt
  unreleased, the wave gate rerunning what it touches. D594 read: the
  `user` label decides before `datname` (the monitoring's queries in a
  scheduler database stay flat); a series with neither (host, WAL) keeps
  the load. 9.10 unchanged: its "fine shape" row is not the night's
  level. Now in: [build plan](archive/v0.6/build-plan.md) v18; [master spec](versions/v0.6/master-spec.md) 9.9.
- **D596 (2026-11-20, the wave driver's call, recorded by spec-writer):
  capture W4's items 1 to 5 as chunk 12b built them,** with the tells'
  autovacuum rule against run R counting updates from T0 and one run
  per bulk statement (the shop's `customers`: 3.7 expected, observed 1
  passes), the residual reported. Now in: wave log, capture W4 (revised
  2026-11-20); [build plan](archive/v0.6/build-plan.md) v18, chunk 12b; [master spec](versions/v0.6/master-spec.md) 12.1.
- **D597 (2026-11-20, spec-writer, gate G10.4 after wave 4's gate):
  wave 4's forms written as built,** each checked against the code on
  `v0.6-w4`; none contradicts the spec, which they complete: the short
  fake game's record and the "Fake aging" section's sources; the fill's
  `fill_transactions` and fix 12's level per call; M3's judged set and
  bounds; the exporter 0.21.1's reach. The tails' figures on 19 go to v1.0
  gating; chunk 17c's two content findings to O298, O299. Now in:
  [formats.md](formats.md) v41; [master spec](versions/v0.6/master-spec.md) 9.7, 9.9, 9.10, 12.1, 18;
  [v1.0 gating](versions/README.md#v10-gating); [build plan](archive/v0.6/build-plan.md) v19.
- **D598 (2026-11-20, spec-writer, release gate item 6): Prometheus'
  retention after a compaction, never reached in the build, is read in
  v1.0 gating's full selections,** their real tails the first runs long
  enough. Technical, none the owner's (master spec 18). Now in:
  [v1.0 gating](versions/README.md#v10-gating); [master spec](versions/v0.6/master-spec.md) 18.
- **D599 (2026-11-20, the owner, G11: "Release v0.6"): G11 cleared,
  the release gate passed,** the gate as run, its known limits and what
  stays v1.0 gating accepted; `v0.6-rg` merged into `main` (no push),
  then the milestone archived. Now in: [build plan](archive/v0.6/build-plan.md)
  v21, G11 and "Release gate"; [release notes](versions/v0.6/README.md#release-notes) item 8.
- **D600 (2026-11-20, the owner, G11, on row G9.3): OpenSSL's 10 CVEs
  open at the release,** reviewed at a trixie OpenSSL DSA or 2027-02-01
  at the latest; nginx's 14 NVD matches on deb13u11 (backport false
  positives) `[[ignore]]` until 2027-05-01, written in `.tech` by the
  security advisor. None is on a served path. Now in: [release notes](versions/v0.6/README.md#release-notes), "Security".
