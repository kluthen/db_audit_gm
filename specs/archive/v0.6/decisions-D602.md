> **Archived 2026-11-20.** v0.6 closed (released at its release gate, G11 cleared by the owner on 2026-11-20, `v0.6-rg` merged into `main` as `fceda75`); entry D602 of the decisions log, written at this pass to close O251 and O269, verbatim (D601 stays live until O298, O299 and ISS-009 are done). Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and the two drafts archived in the same pass were repaired to their archived paths (`archive/v0.6/`), still written from `specs/`.

- **D602 (2026-11-20, spec-writer, at v0.6's archive, on the lead's
  request; as D486 and D510 left them): O251 and O269 closed: both
  loader refusals are built,** `_check_partners_page` and
  `_check_declared_lines` in `tools/gm/model.py`, each with its unit
  tests (`tools/tests/test_model.py`, `fixture-v06-refusals`), green in
  the release gate's unit suite; ISS-001 resolved. Now in:
  [master spec](versions/v0.6/master-spec.md#610-the-loaders-new-checks)
  6.10; [release notes](versions/v0.6/README.md#what-v06-delivers).
