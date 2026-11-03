> **Archived 2026-11-03.** v0.4 closed (released at its release gate on 2026-11-03, merged into `main` on the owner's word); entries D190–D191 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; no link here needed repair.

- **D190 (2026-10-28, owner direction, relayed by the lead session): v0.4
  is "bricks of why and bits of hows", not technology bricks:** a new
  catalogue artefact, the purpose (working name: its jobs, trace,
  invariants and faults); consumers modelled by their trace, no mailer,
  BI or finance software; a generic job runner and a second database,
  PostgreSQL by default, another engine only if a purpose needs one
  (the owner: "We shall see"). Revises D47 for v0.4 only; the rest of
  D47 holds. Open: O104–O110; O11, O22, O25, O52 revised. Now in:
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **D191 (2026-10-28, owner direction, relayed by the lead session): v0.4
  brings a first cut of data governance, coupled to purposes:** data
  classes with rules (location, settings, readers, flows), handed to the
  players as the company's data policy and checked by `gm_check` as
  definition checks; the first cut is classification plus allowed
  locations and flows, richer rules growing with v0.5's regulated
  domains. Extends D190. Open: O115–O120. Now in:
  [versions/v0.4/README.md](versions/v0.4/README.md) "Data governance".
