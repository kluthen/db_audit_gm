# v0.5 — research and broadening

Status: draft. No master spec. Business domains added on 2026-10-28
(D192).

## Goal

In the owner's words, three things (D47):

- broaden the scope of known issues to fill in the catalogue;
- pre-plan the most common parts of topology;
- gather common schemas for databases, "so that the GM doesn't have to
  reinvent everything every time". Data could also come from an external
  dataset: Bluebox, a PostgreSQL sample database (a Pagila-derived
  DVD-rental dataset), or truly external, internet-based open-source data
  sources.

On 2026-10-28 the owner added business domains (D192), in the vein of
v0.4's purposes: "we may see this for producers as well, this will
mostly assist in having common scheduler scripts, input types etc. A
shopping website will have specific data profile, whereas a warehouse
management system will have another, a factory yet another than a bio
lab." On placing them here: "v0.5 already is on expansion of
capabilities so that's okay." Domains are how the third goal, common
schemas, is delivered (below).

## Domains

A **domain** (D192; working name) is a reusable catalogue unit made of:

- **a business data model**: the schema and the data load of a kind of
  business;
- **producer profiles**: how data arrives. A shop is bursty, with daily
  peaks and promotions; a warehouse has scan events around shifts; a
  factory has continuous, high-frequency time series; a lab has
  instrument batch uploads and a strict audit trail;
- **common scheduler scripts and input types**: the queries, builders,
  traffic shapes and parameter generators the domain's producers and
  consumers share;
- **the purposes that fit the domain** ([v0.4](../v0.4/README.md)).

A scenario then becomes a domain, a size, the bricks, the purposes in
use, and the faults. What a domain holds and how a scenario names it is
O111; what "size" scales, O114.

How domains meet the rest of this version (proposed):

- **Common schemas**: a domain's business data model is the common
  schema D47 asks for, so the GM does not reinvent the data each time.
- **Datasets**: Bluebox and internet sources fill a domain's data model,
  or stand as a domain's model of their own (Bluebox is a rental shop);
  their requirements stay O53 and O54.
- **Topology fragments** are the technical arrangement (which bricks,
  how they connect); a domain is the business side. A scenario combines
  one domain with fragments.
- **Producer profiles and v0.3's scheduler**: a profile's relation to
  the query repository (`queries.yaml`, `builders/`) and the hidden
  schedule (`schedule.yaml`) is O113. A factory's stream or a lab's
  instrument uploads may want the scheduler's other targets (D118),
  message queues and APIs, below.
- **Governance**: each domain classifies its data (v0.4's first cut,
  D191). The regulated domains, a lab's records or health data, bring
  the richer rules: required settings, audit trails, retention, and the
  brick changes they need (O118).
- **Scenario generation** (O47): a brief naming a domain and a size is
  most of a scenario's business side.

v0.4 ships the first domain, the shop, structured so that more can be
added (O108). v0.5 adds the others; which come first is O112.

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
- Adjusting v0.3's defaults after use (D146): the formats, brick
  interfaces, scenario, aging, scheduler behaviour, tooling and figures
  the owner accepted as proposed in v0.3's review list
  ([v0.3/review-list.md](../v0.3/review-list.md)), revisited once games
  have run on them.
- Reusable topology fragments for the most common arrangements.
- Domains beyond v0.4's shop (D192; O112), each with its business data
  model, producer profiles, common scheduler scripts and input types,
  and fitting purposes: the library of common schemas, and the datasets
  the GM can draw on, including Bluebox and selected external sources.
- Governance rules beyond v0.4's first cut, with the regulated domains
  (D191).
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
- v0.4: the shop domain and the shape it gives domains, purposes, and
  data governance's first cut (D190 to D192).
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
- O111: the domain format (its v0.4 part settled with the shop).
- O112: which domains come first.
- O113: producer profiles against v0.3's query repository and schedule.
- O114: what a scenario's size scales.
