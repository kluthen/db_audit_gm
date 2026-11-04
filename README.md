# db_audit_gm — Database Audit Game Master

A generator of **live database audit exercises**. An agent (the *game
master*) assembles a realistic data stack — producers, databases,
transformers, consumers, backup and monitoring tools — on a Docker Swarm,
plants a set of issues in it, ages it so that those issues leave traces, and
hands it over to a student (the *player*) through a single bastion host.

The player's job is the auditor's job: map the system, check what the
monitoring says against what is really happening, find the issues the
customer already knows about, discover the ones nobody has noticed, fix what
they are allowed to fix, and write an audit report.

## Status

**v0.4 released** (2026-11-03). **v0.5** (domain definition, with the
veterinary clinic franchise as the worked example) has an approved master
spec, access model and build plan: 27 chunks in five waves, with wave 1
next. v0.6 and v1.0 are still being drafted.

| Version | Theme | Released | Scenario |
|---|---|---|---|
| [v0.1](specs/versions/v0.1/README.md) | Settle the GM stance: a static PostgreSQL database investigated for specific defects | 2026-10-21 | `bookshop-new-server` |
| [v0.2](specs/versions/v0.2/README.md) | Monitoring and the usual tooling: node health, PostgreSQL metrics, dashboards, alerting, logs | 2026-10-22 | `fernway-clinics-monitoring` |
| [v0.3](specs/versions/v0.3/README.md) | Producers and consumers: a scheduler driving load, ingestion, load spikes, misbehaving requests; aging under real time | 2026-10-30 | `tarnbeck-outdoor-shop` |
| [v0.4](specs/versions/v0.4/README.md) | Purposes: the side uses of the data (reporting, leads, mailing, export declarations), several PostgreSQL instances, jobs on a database node, the shop as the first business domain, a first cut of data governance | 2026-11-03 | `tarnbeck-outdoor-campaign` |
| [v0.5](specs/versions/v0.5/README.md) | Domain definition: a procedure for defining a domain, the clinic's domains, purposes and round trips, `postgres` brick options, a post-mortem collection | spec approved 2026-11-03, build next | — |
| [v0.6](specs/versions/v0.6/README.md) | The bastion as the players' main activity point: web interfaces, a documentation site, general tooling, a reporting tool | draft | — |
| [v1.0](specs/versions/v1.0/README.md) | First release: the full pipeline scenario | draft | — |

The specification starts at [`specs/README.md`](specs/README.md) (index,
status and how to resume). The roadmap, along with what lies beyond v1.0
and the v1.0 gating list, is in
[`specs/versions/README.md`](specs/versions/README.md). Each version page
has its own release notes.

## Layout

| Path | What |
|---|---|
| [`tools/gmctl`](tools/gmctl) | The GM's host-side command line: `fit`, `render`, `deploy`, `load-data`, `inject`, `start-load`, `validate`, `check`, `snapshot`, `restart`, `status`, `exec`, `logs`, `teardown` (code in [`tools/gm/`](tools/gm/)) |
| [`tools/go-sbom`](tools/go-sbom) | Generates (`generate`) and checks (`check`, offline) the CycloneDX SBOMs of the Go binaries the bricks download as release tarballs (Prometheus, promtool, Grafana and its Prometheus data source plugin, postgres_exporter, pgwatch), from the exact archive each Dockerfile pins; the daily cve-watch sweep reads the SBOMs through [`.tech`](.tech)'s `lockfiles`. Kept by the security advisor |
| [`tools/tests/`](tools/tests/) | Unit tests for `gmctl` and the smoke and rehearsal scripts |
| [`bricks/`](bricks/) | Node definitions: `postgres` 0.5.0, `bastion` 0.5.0, `scheduler` 0.3.0, `api` 0.1.0, `pgbouncer` 0.1.1, `prometheus` and `postgres-exporter` 0.2.0, `grafana` 0.3.0, `pgwatch` 0.1.0, `health-check` 0.1.0 |
| `bricks/<brick>/sbom/` | One CycloneDX SBOM per downloaded Go binary (`<binary>.cdx.json`, written by `tools/go-sbom`): [`prometheus`](bricks/prometheus/sbom/), [`postgres-exporter`](bricks/postgres-exporter/sbom/), [`grafana`](bricks/grafana/sbom/), [`pgwatch`](bricks/pgwatch/sbom/); a bump of a pinned release regenerates them (`tools/tests/test_go_sbom.py` fails until it does) |
| [`faults/`](faults/) | The fault catalog (29 faults): PostgreSQL configuration and security, monitoring and alerting, scheduler jobs, purposes and governance |
| [`domains/`](domains/) | Business domains: `shop`, `vet-core` (the clinic's medical record and the keys its parts share), `vet-machinery` (the clinic's machines and their three systems' databases, `pacs`, `vitals`, `biomed`). The one-domain form (`domain:`) copies a domain into the scenario at design time; a composed scenario (`domains:`) takes its producer fragments through `gmctl compose`, and `load-data` reads its data files from the catalogue at every load |
| [`partners/`](partners/README.md) | The partners' three shared nodes (`shared/`: the `api` node, the back end and the small database every third party runs on) and cold storage, the vault (`coldstore/`), design-time sources a scenario copies from |
| [`purposes/`](purposes/) | Purposes (what the customer's data is for): `shop-sales-reporting`, `shop-winback-leads`, `shop-customer-mailing` and `shop-export-declarations`. A scenario copies a purpose's material at design time; a purpose's `history:` (the past periods' outputs planted into its target) is read from the catalogue by `load-data` at every load |
| [`scenarios/`](scenarios/) | Playable scenario folders, one per released version (table above) |
| [`post_mortem/`](post_mortem/README.md) | Summaries of 27 public database incident reports. They are source material for future games and end-of-game handouts, not fault definitions |
| [`specs/`](specs/README.md) | The living specification: concept, platform, formats, decisions, open questions, version pages and the archive |
| [`.claude/skills/`](.claude/skills/) | The `game-master`, `scenario-format` and `scenario-document` skills |

To play, open a Claude Code session at the repository root and run
`/game-master`. The GM sets the game up from a complete scenario folder
through `tools/gmctl`, hands it over, holds its stance during play,
evaluates the final answer against the answer key and the live system,
gives feedback and tears the game down.

## Core ideas

- **Scenarios, not a fixed lab.** Each scenario is generated from a teacher's
  brief (background story, required incidents, whether the agent may add
  more), then frozen into a manifest and a sealed answer key so it can be
  redeployed identically.
- **A growing catalog of bricks.** The repository holds Dockerfiles,
  configurations and documentation for clean and faulty nodes: several
  database engines and versions, backup tools, monitoring, pipelines (e.g.
  dbt + DuckDB). The agent picks bricks from the catalog or builds new ones
  that follow the brick contract.
- **Constrained resources.** Every scenario must fit in the cluster's CPU and
  memory budget. Databases are deliberately nerfed; the player's tuning must
  stay within published bounds, checked by a validator on each node.
- **Bastion only.** The player never touches the swarm. They get SSH access
  to the bastion and, from there, legal access to every node of the
  topology, with write access only where fixing is part of the exercise.
- **Trust, documented.** Some tampering cannot be prevented in practice. What
  can't be enforced is clearly marked (`DO NOT TAMPER`), and the players are
  trusted not to break the game.
- **Sessions of up to 4 hours**, usually one scenario per class, sometimes one
  per student.

