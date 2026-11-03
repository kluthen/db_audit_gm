> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D305 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and to the v0.4 drafts archived in the same pass were repaired to their archived paths (`archive/v0.4/`), still written from `specs/`.

- **D305 (2026-11-02, owner ruling on chunk 17a's finding, relayed by the
  wave driver): the `pgbouncer` start-up DNS race is fixed in v0.4 as
  `pgbouncer` 0.1.1, by a bounded wait at start until its `[databases]`
  hosts resolve, or an equivalent; every pin re-pinned. Chunk 21, wave 4.**
  The producer was down all game in 4 of 5 deploys; 0.1.1, a patch as D57's, no interface change.
  Now in: [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.3, 16.1, 16.4, 17; [archive/v0.4/build-plan.md](archive/v0.4/build-plan.md) chunk 21.
