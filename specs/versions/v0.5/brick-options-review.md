# v0.5 — brick options: the review against the clinic

Status: draft v1 (D236, D238). A review, not the options model: the
model is still O79, and whether it covers every brick is O80.

The owner, on 2026-10-31: "brick options may come in with the clinic
scenario honestly. We need to review this as well." Then, on monitoring:
"pgwatch and pgcluu may be included in the clinic setting to be honest,
they are monitoring tooling that are required in such complex settings."

This page checks the README's candidate list (D107; the README's "In
scope") against what the clinic's parts plausibly need
([domain-procedure.md](domain-procedure.md), "The clinic, a first cut").
Every "needs" below is `(proposed)` until the owner defines the clinic's
bricks and configurations (D233).

## What the clinic plausibly needs

| Candidate | Clinic need | Parts | Remarks |
|---|---|---|---|
| **pgaudit** | an audit trail on the medical record and the lab, the regulated rules held for v0.5 (O118) | `vet-core`, `vet-lab` | new software in the image, a preloaded library set in the seed (so its removal can be a fault), an audit log weighing on the disk budget |
| **TLS** | the owners' portal reached from outside, exchanges between clinics, external labs | `vet-portal`, sites | settings in the seed, certificates as generated secrets ([v0.4 governance](../v0.4/governance.md)); an option, or available in every game? |
| **Replication** | redundancy, the owner's "heavy need" (D196); several sites (O127) | `vet-core`, sites | built into PostgreSQL, no extension; mostly topology (a standby node) plus what the brick must do as a standby; every seed already carries the replication line (D164) |
| **TimescaleDB** | the machinery's readings and logs, a time series | `vet-machinery` | D107 names it an option, D47 places it beyond v1.0: a tension to settle; plain partitioned tables may do at "schemas simple, tables small"; image size and its licence editions to check |
| **`pg_cron`** | the clinic's own jobs: registers closed, reminders | `vet-core`, `vet-scheduling` | ships in `postgres` 0.4.0, enabled by the seed (D206); the model would only formalise it |
| **`pg_stat_statements`, file logging and pgBadger, the `monitoring` role** | monitoring a setting this complex: pgwatch and pgCluu stay in v0.5 (D238) and read what these provide | every database | in every game since `postgres` 0.2.0; making the role conditional (D113) stays a v0.5 item |

## What stops mattering in v0.5

- **PostGIS and `pg_trgm`**: Bluebox's needs (O53), which leave with
  Bluebox (D237). The clinic's region-wide catchment needs no geometry
  `(proposed)`.
- Nothing tied to pgwatch or pgCluu: both stay (D238). Whether either
  needs more of the `postgres` brick than it has today (pgwatch's
  optional helper functions, for one) is checked when they are
  specified.

## What O79 and O80 must answer for the clinic

O79's five points, read for the candidates above:

1. **Where the software comes from**: pgaudit is light, TimescaleDB is
   not; one image with both, or a variant for the heavy one. `fit`
   counts image sizes (D102).
2. **How a scenario chooses**: per node, since the clinic's databases
   differ (an audited record, a machine's time series, a standby).
3. **Start-up**: pgaudit's extension and its settings; a standby's
   start from its primary; TLS's certificates mounted from secrets. The
   settings stay in the seed, so a fault can remove them.
4. **Faults that need an option**: an audit trail missing a class of
   access, TLS off on the portal's path, a standby lagging or broken.
5. **Documentation**: one section per option in `postgres`'
   `docs/gm.md`.

O80, for the clinic: `postgres` is certain. Another brick needs options
only if a clinic part calls for one: the scheduler's drivers for queues
or APIs (the README's "Scheduler's other targets"), or the monitoring
bricks once pgwatch and pgCluu join `(proposed)`.

## Open points for the owner

All carried by O79, O80 and O118 in the register:

- TimescaleDB for the machinery, against D47's "beyond v1.0", or plain
  partitioned tables first (recommended: plain tables first).
- Replication: a brick option, or a standby mode of the brick that
  topology chooses (recommended: a mode, since a standby is a node).
- TLS: an option, or always available and turned on by the seed
  (recommended: always available, like `pg_cron`).
- Whether the four elements every game has today become options in
  v0.5 (recommended: only the `monitoring` role, D113, the rest staying
  in every game).
