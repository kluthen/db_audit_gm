# v0.5 — research and broadening

Status: draft. No master spec.

## Goal

In the owner's words, three things (D47):

- broaden the scope of known issues to fill in the catalogue;
- pre-plan the most common parts of topology;
- gather common schemas for databases, "so that the GM doesn't have to
  reinvent everything every time". Data could also come from an external
  dataset: Bluebox, a PostgreSQL sample database (a Pagila-derived
  DVD-rental dataset), or truly external, internet-based open-source data
  sources.

## In scope

- Other tools and hand-made scripts beyond v0.2's one default brick per
  need (D70): other monitoring tools (among them the research's other
  top-three picks and the reference setup's pgwatch and pgCluu), other
  open-source health solutions such as Nagios (D66), and hand-made scripts
  as the customer's own tooling.
- More fault definitions in the catalog, across the families already
  listed.
- The scheduler's other targets (D118): other database types, message
  queues, APIs, and tools that trigger transformation layers, as drivers
  of v0.3's scheduler brick
  ([v0.3/scheduler.md](../v0.3/scheduler.md), "Drivers").
- Reusable topology fragments for the most common arrangements.
- A library of common schemas and datasets the GM can draw on, including
  Bluebox and selected external sources.
- Brick options (D107): optional elements a brick offers and a scenario
  chooses, each documented in the brick's GM documentation and added to
  a scenario when appropriate, `postgres` first: for that brick in
  particular, the owner expects "many 'optional' elements".
  First candidates: pgBadger, file logging, `pg_stat_statements` and the
  monitoring role (all present in every game in `postgres` 0.2.0), then
  PostGIS, TimescaleDB and the replication modules. The model (where an
  option's software comes from, how a scenario chooses, what start-up
  does, faults that need an option, documentation) is O79; whether it is
  meant for every brick or only `postgres`, O80.
- The `monitoring` role made conditional on the game having monitoring
  (D113; v0.2's RG-5). In `postgres` 0.2.0 every game has the login role
  `monitoring` (`pg_monitor`), exporter or not. The owner: "monitoring
  isn't mandatory in any game (highly suspect if there isn't any of
  course, but it remains a valid game)". Until then the role stays in
  every postgres game. The role is among the first candidate options
  above (O79).

## Out of scope

- New database engines (beyond v1.0).

## Depends on

- v0.2 to v0.4: the bricks the topology fragments are made of; v0.2's
  monitoring bricks, which v0.5's other tools extend.
- v0.2's `postgres` 0.2.0, whose built-in pgBadger, file logging,
  `pg_stat_statements` and monitoring role are the first candidate
  options, and v0.2's declare/choose/check pattern for mounted material
  and `receives` (D97), which the options model is akin to.

## Questions due in this version

- O79: the brick options model (images, choice, start-up, faults,
  documentation).
- O80: options for every brick, or `postgres` only.
- O53: Bluebox's requirements (PostGIS and other extensions, an 88 MB
  compressed dump, `pg_cron` for ongoing data, data licensing).
- O54: internet-sourced data (availability at setup, licensing,
  reproducibility).
- O23: number and mix of faults, difficulty.
- O25: promoting scenario-only bricks and faults into the catalog.
- O21: whether starter documentation may itself carry faults.
- O24: seeded variation per deployment.
- O47: whether generating scenarios from a brief belongs here or in v1.0.
