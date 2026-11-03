> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D310–D313 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and to the v0.4 drafts archived in the same pass were repaired to their archived paths (`archive/v0.4/`), still written from `specs/`.

- **D310 (2026-11-03, owner ruling on chunk 17a's runs, relayed by the
  wave driver): 17a is done with its second cycles run aborted at f4's
  wait for the scenario's midnight (54 PASS, 0 FAIL) and without its
  two-host run.** The laptop is off the network today. 17a leaves unproven
  f4's steps after that midnight (its "fixed") and every fault at once on
  armenelos plus the VPS; master spec 18 items 1 and 2 still ask for both,
  in release gate items 8 and 9, unchanged, as 17b's two-host rehearsal.
  When the two-host runs happen: O161. Now in:
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 17.
- **D311 (2026-11-03, owner ruling on O161, relayed by the wave driver):
  v0.4 closes without its two-host runs, its rehearsal (chunk 17b and its
  figures) and its stance check-list; they become v1.0 gating, run once
  before the v1.0 tag, with the full-game testing none plays until then.**
  Closes O161. The owner: "see if you can wrap up this wave and this
  milestone without these". The footprints and the scenario's `resources`
  stand as built; item 9's unobserved part stays in v0.4's gate (O162).
  Now in: [versions/README.md](versions/README.md#v10-gating);
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 17, gates, release gate.
- **D312 (2026-11-03, owner ruling on O162, relayed by the wave driver):
  "long running tests should be moved to v1.0 gating. remaining tests
  should be short."** Item 9's unobserved part (f4 after the scenario's
  midnight, f8's fixed reading, a clean cycles verdict, ~9 h) and f8's
  wait in the wave 4 gate's all-at-once smoke run (stopped there) move.
  Closes O162. The driver takes it as the owner's confirmation of D311's
  master spec 18 amendment, since it moves more, not less. Now in:
  [versions/README.md](versions/README.md#v10-gating);
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) workflow deltas, chunk 17, release gate.
- **D313 (2026-11-03, owner answer to O163, "option c, G11 ok, merge",
  relayed by the wave driver): the `smoke` run's end-of-run checks with
  every fault planted (every job and key since T0, `reporting`'s
  `pg_cron` job, the full `check`, the teardown), never reached in v0.4,
  stay a known limit, covered by the v1.0-gating smoke run.** Closes
  O163; options (a) and (b) not taken. Now in:
  [versions/v0.4/README.md](versions/v0.4/README.md#known-limits);
  [versions/README.md](versions/README.md#v10-gating);
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 18;
  [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) release gate item 8.
