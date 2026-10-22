# Roadmap

The versions from the first milestone to the first release and beyond, as
set out by the owner (D47), with v0.6 added on 2026-10-21 (D71). Each version has its own page; a version's
master spec lands in its folder only when it is approved. Everything after
v0.1 is draft.

| Version | Theme | Status |
|---|---|---|
| [v0.1](v0.1/README.md) | Settle the GM stance on one simple scenario: a static PostgreSQL database investigated for specific defects | released 2026-10-21, merged into `main` (3c852e1); working record archived in [archive/v0.1/](../archive/v0.1/README.md) |
| [v0.2](v0.2/README.md) | Monitoring and usual tooling: per-node health, PostgreSQL metrics, dashboards and alerting, log analysis; one free brick per need, chosen by footprint | released 2026-10-22: release gate passed, G10 and G11 cleared; [release notes](v0.2/README.md#release-notes); working record archived in [archive/v0.2/](../archive/v0.2/README.md) |
| [v0.3](v0.3/README.md) | Producers and consumers: ingestion, load spikes, misbehaving requests, broad queries | spec approved 2026-10-22 (D154): [master spec](v0.3/master-spec.md) and [access model](v0.3/access-model.md); rulings D114–D155; build plan next |
| [v0.4](v0.4/README.md) | Transformers: moving data between databases with scripts, dbt and the like | draft |
| [v0.5](v0.5/README.md) | Research and broadening: more known issues, pre-planned topology parts, common schemas and datasets; other tools and hand-made scripts | draft |
| [v0.6](v0.6/README.md) | The bastion as the players' main activity point: web interfaces, a documentation website, general-use tooling | draft |
| [v1.0](v1.0/README.md) | First release: the full pipeline scenario, reached through v0.2–v0.6 | draft |

**Beyond v1.0**:

- integrating other tools and databases, such as TimescaleDB, columnar
  databases, MySQL and others (D47);
- the GM playing the customer during the game, and the GM giving hints,
  node resets or extra time (D48).

Questions about the roadmap as a whole (gaps between v0.5 and v1.0,
risks across versions) are in [open-questions.md](../open-questions.md),
O47 to O49 and O52 to O54 (O46, multi-host, resolved by D128 for v0.3).
