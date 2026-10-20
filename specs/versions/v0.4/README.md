# v0.4 — transformers

Status: draft. No master spec.

## Goal

In the owner's words: "Internal bricks that will transform data from one
database to another (in batch, as it comes, scheduled or on demand) using
various tech: plain scripts (Python or otherwise), dbt-based, etc." (D47)

## In scope

- Transformer bricks moving data from one database to another: in batch,
  as it comes, scheduled, or on demand.
- Several technologies: plain scripts (Python or other), dbt-based.
- The second database of the pipeline, and faults in the transformation
  path (stale input, a job that never runs, wrong scheduling).

## Out of scope

- New database engines (beyond v1.0).

## Depends on

- v0.1; v0.3 for data flowing into the source database; v0.2 for watching
  the jobs.

## Questions due in this version

- O11: transformation technologies and versions.
- O22: scheduled jobs under time compression.
- O52: dbt adds a Python toolchain to a node image.
- O25: promoting transformer bricks built for one scenario into the
  catalog.
