# v0.5 — brick options: the review against the clinic

Status: draft v5 (D236, D238), ruled by the owner on 2026-10-31
(D250, D261, D262); the options model ruled on 2026-11-02 (D289,
closing O79), for `postgres` only (D262); the four parts checked
against it on 2026-11-03, none calling for an option.

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
| **TLS** | the owners' portal reached from outside, exchanges between clinics, external labs | `vet-portal` (its reach, D320: `portal-api`'s connection to `records`, a `hostssl` line; the owners reach the API, not the database), sites | **not an option** (D250): always available in `postgres`, turned on by the seed; certificates as generated secrets ([v0.4 governance](../v0.4/governance.md)) |
| **Replication** | redundancy, the owner's "heavy need" (D196), inside the one centre a scenario deploys (D285) | `vet-core`, sites | **a standby mode of the brick** (D250), not an option: a standby is a node the topology chooses; built into PostgreSQL, no extension; every seed already carries the replication line (D164) |
| **TimescaleDB** | the machinery's readings and logs, a time series | `vet-machinery` | **not in v0.5** (D250): plain partitioned tables first, TimescaleDB staying where D47 places it, beyond v1.0 |
| **`pg_cron`** | the clinic's own jobs: registers closed, reminders | `vet-core`, `vet-scheduling` | ships in `postgres` 0.4.0, enabled by the seed (D206); the model would only formalise it |
| **`pg_stat_statements`, file logging and pgBadger, the `monitoring` role** | monitoring a setting this complex: pgwatch and pgCluu stay in v0.5 (D238) and read what these provide | every database | in every game since `postgres` 0.2.0; **only the `monitoring` role becomes an option** (D250, D113), the other three staying in every game |

## What stops mattering in v0.5

- **PostGIS and `pg_trgm`**: Bluebox's needs (O53), which leave with
  Bluebox (D237). The clinic's region-wide catchment needs no geometry
  (ruled, D339).
- Nothing tied to pgwatch or pgCluu: both stay (D238). Neither needs
  more of the `postgres` brick than it has: pgwatch runs a metric set
  without helper functions as `monitoring`, pgCluu ships beside pgBadger
  (D340).

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
- **Applied with the parts on 2026-11-03** (D317–D320): no part calls
  for an option or another brick. `vet-portal` creates `pgcrypto`
  (PostgreSQL's contrib, shipped with the brick's packages) in its
  database `portal` by its own schema, an extension, not an option;
  `vet-machinery`'s partitions are plain partitioned tables, as D250
  set.

## The options model (D289)

Ruled by the owner on 2026-11-02, closing O79, as proposed: "ok for
now, if it needs upgrading we'll handle it then". It has one user, the
`monitoring` role, on one brick, `postgres`.

1. **Declared by the brick.** `brick.yaml` gains `options:`; `postgres`
   offers one, `monitoring`, which brings the `monitoring_password`
   secret and the role created at initdb.
2. **Chosen per node.** A scenario opts in with `options: [monitoring]`
   on the node; an option is off unless chosen. The role and its secret
   exist only when it is on.
3. **Checked by `gmctl`.** A monitoring node (the exporter, pgwatch,
   pgCluu) targeting a `postgres` node without the option is refused,
   unless a fault plants that gap.
4. **Faults may require an option**: a lost `pg_monitor` grant, an
   expired password, a connection limit of 1.
5. **No software, so one image.** Image variants wait for the first
   option that brings software, after v0.5.
6. **Documentation**: one section per option in `postgres`'
   `docs/gm.md`; the player documentation and the starter pack mention
   the role only when the option is on.
7. **v0.4's scenarios** that use the exporter get `options: [monitoring]`
   in the build.

pgwatch and the health check read what they need with `pg_monitor`;
pgCluu is run by the players, as pgBadger is (D340).
