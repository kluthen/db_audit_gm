> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D193–D195 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; no link here needed repair.

- **D193 (2026-10-29, owner ruling after v0.3's release-gate aged run,
  relayed by the wave driver): An aged run, a full aging to the
  hand-over then a play-through, is a one-off check, not a standing
  item of every release gate;** none is planned before v1.0, and whether
  v1.0's gate has one is decided when that gate is planned. The owner:
  "it takes too much time." v0.3's gate ran one and it passed; D135
  holds for v0.3 only. Later gates rely on the smoke tests, the
  rehearsal and the timer-fired early check. Open: O121. Now in:
  [versions/README.md](versions/README.md#release-gates),
  [versions/v0.4/README.md](versions/v0.4/README.md#release-gate),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **D194 (2026-10-30, spec-writer, on drafting v0.4's purposes): No v0.4
  purpose needs an engine beyond PostgreSQL;** reporting, leads,
  mailing, export declarations and finance all fit PostgreSQL at
  "schemas simple, tables small", so D190's condition is not met. Closes
  O106; a later purpose needing one raises a new question. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md).
- **D195 (2026-10-30, spec-writer, reading the owner's words in D190):
  No mail sink in v0.4: `mail_outbox` is the mail's whole trace,** since
  every check the owner named (duplicates, ill-appropriate sending,
  "were we truly doing this") is judged on it. Closes O110; a purpose
  needing delivery behaviour (bounces) raises a new question. Now in:
  [versions/v0.4/purpose-catalogue.md](versions/v0.4/purpose-catalogue.md) P3.
