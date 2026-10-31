# v0.5 — brick options: the review against the clinic

Status: draft v3 (D236, D238), ruled by the owner on 2026-10-31
(D250, D261, D262). A review, not the options model: the model is still
O79; it covers `postgres` only (D262).

The owner, on 2026-10-31: "brick options may come in with the clinic
scenario honestly. We need to review this as well." Then, on monitoring:
"pgwatch and pgcluu may be included in the clinic setting to be honest,
they are monitoring tooling that are required in such complex settings."

This page checks the README's candidate list (D107; the README's "In
scope") against what the clinic's parts plausibly need
([domain-procedure.md](domain-procedure.md), "The clinic, a first cut").
Which parts need what stays to be confirmed as the owner defines the
clinic's bricks and configurations (D233); how each candidate reaches
the clinic is ruled (D250, D261, below).

## What the clinic plausibly needs

| Candidate | Clinic need | Parts | Remarks |
|---|---|---|---|
| **pgaudit** | an audit trail on the medical record and the lab, the regulated rules held for v0.5 (D191) | `vet-core`, `vet-lab` | **not an option** (D261): always available in `postgres`, turned on by the seed, as TLS is; new software in the image (a dependency check when built), a preloaded library set in the seed (so its removal can be a fault), an audit log weighing on the disk budget |
| **TLS** | the owners' portal reached from outside, exchanges between clinics, external labs | `vet-portal`, sites | **not an option** (D250): always available in `postgres`, turned on by the seed; certificates as generated secrets ([v0.4 governance](../v0.4/governance.md)) |
| **Replication** | redundancy, the owner's "heavy need" (D196); several sites (O127) | `vet-core`, sites | **a standby mode of the brick** (D250), not an option: a standby is a node the topology chooses; built into PostgreSQL, no extension; every seed already carries the replication line (D164) |
| **TimescaleDB** | the machinery's readings and logs, a time series | `vet-machinery` | **not in v0.5** (D250): plain partitioned tables first, TimescaleDB staying where D47 places it, beyond v1.0 |
| **`pg_cron`** | the clinic's own jobs: registers closed, reminders | `vet-core`, `vet-scheduling` | ships in `postgres` 0.4.0, enabled by the seed (D206); the model would only formalise it |
| **`pg_stat_statements`, file logging and pgBadger, the `monitoring` role** | monitoring a setting this complex: pgwatch and pgCluu stay in v0.5 (D238) and read what these provide | every database | in every game since `postgres` 0.2.0; **only the `monitoring` role becomes an option** (D250, D113), the other three staying in every game |

## What stops mattering in v0.5

- **PostGIS and `pg_trgm`**: Bluebox's needs (O53), which leave with
  Bluebox (D237). The clinic's region-wide catchment needs no geometry
  `(proposed)`.
- Nothing tied to pgwatch or pgCluu: both stay (D238). Whether either
  needs more of the `postgres` brick than it has today (pgwatch's
  optional helper functions, for one) is checked when they are
  specified.

## The owner's rulings (D250, D261, D262)

- Plain partitioned tables for the machinery, before any TimescaleDB
  (D250).
- Replication as a standby mode of the brick (D250).
- TLS always available, turned on by the seed (D250).
- Of the four elements every game has today, only the `monitoring` role
  becomes an option (D250).
- pgaudit always available, turned on by the seed, as TLS is; its
  settings stay in the seed, so their removal can be a fault (D261).
- Options are for `postgres` only, unless one of the clinic's parts
  calls for another brick (D262): the scheduler's drivers for queues or
  APIs, say, or the monitoring bricks once pgwatch and pgCluu are
  specified. Such a part raises its own question.

## What O79 still answers for the clinic

With those rulings the options model has one user, the `monitoring`
role, on one brick, `postgres`. O79's five points, read for it, not yet
ruled:

1. **Where the software comes from**: the role needs none. `fit` counts
   image sizes (D102); pgaudit, in the base image, adds to them.
2. **How a scenario chooses**: per node.
3. **Start-up**: the role created, or not, with its secret.
4. **Faults that need an option**: an exporter or pgwatch with no role
   to connect as.
5. **Documentation**: one section per option in `postgres`'
   `docs/gm.md`.
