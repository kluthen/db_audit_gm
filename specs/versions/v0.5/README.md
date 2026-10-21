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
- Reusable topology fragments for the most common arrangements.
- A library of common schemas and datasets the GM can draw on, including
  Bluebox and selected external sources.

## Out of scope

- New database engines (beyond v1.0).

## Depends on

- v0.2 to v0.4: the bricks the topology fragments are made of; v0.2's
  monitoring bricks, which v0.5's other tools extend.

## Questions due in this version

- O53: Bluebox's requirements (PostGIS and other extensions, an 88 MB
  compressed dump, `pg_cron` for ongoing data, data licensing).
- O54: internet-sourced data (availability at setup, licensing,
  reproducibility).
- O23: number and mix of faults, difficulty.
- O25: promoting scenario-only bricks and faults into the catalog.
- O21: whether starter documentation may itself carry faults.
- O24: seeded variation per deployment.
- O47: whether generating scenarios from a brief belongs here or in v1.0.
