> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D197–D200 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and to the v0.4 drafts archived in the same pass were repaired to their archived paths (`archive/v0.4/`), still written from `specs/`.

- **D197 (2026-10-30, owner ruling on spec-writer's recommendation,
  relayed by the coordinator): v0.4 ships four purposes on the shop:**
  P1 sales reporting, P2 win-back leads, P3 customer mailing, and P5
  export declarations, a pushed obligation; finance (P4) is held for
  v0.5. Closes O107. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md).
- **D198 (2026-10-30, owner ruling, relayed by the coordinator): v0.4's
  reporting database is a PostgreSQL instance of its own,** a second
  `postgres` node of about 256 MB; governance rules name their location
  as `node/database` and may require instance separation. Closes O120.
  Now in: [versions/v0.4/governance.md](versions/v0.4/governance.md)
  "The database-versus-instance boundary".
- **D199 (2026-10-30, owner ruling, relayed by the coordinator):
  Purposes run at realistic cadences, sub-daily where a real business
  would;** players verify a daily job by moving its run time (D132); no
  weekly or monthly purpose in v0.4; the restored backup may hold past
  records computed by the data load, but no fault's evidence rests on
  them alone. Closes O109. Now in:
  [archive/v0.4/purposes.md](archive/v0.4/purposes.md) "Time".
- **D200 (2026-10-30, owner ruling, relayed by the coordinator): v0.4's
  release gate runs the checks O121 proposed (known limits named,
  rehearsal hand-over placed on the jobs, growth extrapolated) plus every
  purpose fault through its full cycle in a smoke run,** present, too
  soon after the fix, then fixed, its job moved as a player may. Closes
  O121. Now in: [archive/v0.4/checks.md](archive/v0.4/checks.md).
