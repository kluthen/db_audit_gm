> **Archived 2026-11-20.** v0.6 closed (released at its release gate, G11 cleared by the owner on 2026-11-20, `v0.6-rg` merged into `main` as `fceda75`); entry D548 of the decisions log, verbatim (D545 to D547 and D549 to D577 are v0.7's and stay live). Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and the two drafts archived in the same pass were repaired to their archived paths (`archive/v0.6/`), still written from `specs/`.

- **D548 (2026-11-19, spec-writer, chunk 11a's measured deviation): the
  shop's f9 carries no `suppressed_by` over f4,** since it hides f4 only
  in state and logs: the exporter has no per-table series and run R
  shows f4's `max_tx_duration` sawtooth throughout. The shop's f5 has no
  `daily_spike` (R holds no noon-run sample). Now in: [master spec](versions/v0.6/master-spec.md#98-the-scenarios-covered-and-the-starting-estimates)
  6.9, 9.8; [build plan](archive/v0.6/build-plan.md) chunk 11.
