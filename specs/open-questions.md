# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Resolved IDs are listed at the bottom.

Priority: **next** = shapes everything else, ask first; **soon** = needed
for v0.1; **later** = can wait for v1.0 or beyond. None is open for v0.1.

## Project and scope

- **O2** (later) — Scripts versus agent judgment beyond v0.1. What the GM
  must be told and what it fills in is settled (D16); v0.1's split is
  settled (D33). Still open for generated scenarios: which further steps
  (fault choice, story, solvability probe) become scripts. Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O5** (later) — ATD was removed. Is any lighter record of intent wanted
  beyond `specs/` and the bricks' GM-facing documentation, or is that
  enough?
- **O16** (later) — Confirm the vocabulary table. Refs:
  [concept.md](concept.md).

## Platform

- **O10** (later, research) — Mostly answered in
  [platform.md](platform.md). Still unverified: numeric-only uid/gid in
  config mounts, the cross-host `127.0.0.1:5000` registry pattern, SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role (producer, the two
  databases, transformation, consumer, monitoring), which engine versions
  first, and how upgrade scenarios (both binaries, disk space) fit the
  budget. Refs: [versions/v1.0/README.md](versions/v1.0/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). Refs: [platform.md](platform.md).

## Player access and rules

- **O13** (later) — How does the player reach monitoring web UIs (Grafana,
  pgwatch) while only ever going through the bastion: SSH tunnel / SOCKS, a
  browser on the bastion, or ports exposed on the local network (which the
  routing mesh opens on every host)? Refs:
  [planes-and-access.md](planes-and-access.md).

## Faults and aging

- **O20** (later) — Confirm the reading of D28: no project-wide mandatory
  machine check (no common brick lint, no schema check in the format skill),
  only the checks each brick ships. And confirm the solvability probe as a
  gate for generated scenarios, run after aging and before hand-over. Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O21** (later) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario?
- **O22** (later) — Default aging technique per fault (pre-aging, forged
  history, time compression). Time compression is visible to the auditor
  (`*/5` on a "daily" job), collides with schedule faults, and must stay
  consistent with forged timestamps. Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O23** (later) — How many faults per scenario, how many covered by
  issues, what "difficulty" means concretely, and may an issue be a false
  alarm (a complaint with no fault behind it)? Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O24** (later) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O45** (later) — `ALTER SYSTEM` on a report-only database node cannot
  be prevented for a superuser `dba`. When report-only database nodes
  arrive: a non-superuser role there, or accept it under light enforcement?
  Refs: [versions/v0.1/access-model.md](versions/v0.1/access-model.md),
  "Known gaps".
- **O25** (later) — Scenario-only bricks and faults may live in the
  scenario's folder (D24). Can they be promoted into the catalog, and
  through which review?

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment, aging and probes take
  before a class? Can pre-aging run the day before?
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Does the GM's feedback include a score? Is it written
  to a file (the teacher is out of the game by then)? Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47). The tag after the priority is the version
the question concerns.

- **O46** (soon, v0.2 → v1.0) — Multi-host and the registry were deferred
  from v0.1. Does v1.0 still run on one host, or does the full pipeline
  with monitoring need a multi-host swarm and a registry? The question
  starts mattering in v0.2: Grafana, a metrics store and possibly a log
  aggregator all count against one laptop's capacity. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [platform.md](platform.md).
- **O47** (later, v1.0) — Which version brings scenario generation: the GM
  designing from a partial or empty brief and filling the blanks (D16)?
  v0.5 prepares for it without naming it. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O48** (later, v0.3 → v1.0) — Where do aging (pre-aging, time
  compression; O22) and the solvability probe as a gate (O20) enter the
  roadmap? Load (v0.3) and generated scenarios both need them. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O49** (soon, roadmap) — Backup tools (pgBackRest and the like) and the
  backup-tooling fault families (D17) are in no version, although backups
  were a founding example and the v0.1 goal speaks of "investigating a
  backup". Which version? Refs:
  [bricks-and-faults.md](bricks-and-faults.md), "Future ideas: backup
  tooling".
- **O50** (soon, v0.2) — Monitoring arrives in v0.2, before any load
  (v0.3): dashboards over a static database show almost nothing, and
  monitoring faults ("monitoring that lies") are hard to observe without
  activity. Add a minimal load generator to v0.2, give the monitoring a
  forged history, swap v0.2 and v0.3, or accept thin monitoring in v0.2?
  Refs: [versions/v0.2/README.md](versions/v0.2/README.md).
- **O51** (soon, v0.2) — Container and host monitoring ("docker up and
  down, load") usually needs the Docker socket or host mounts (cAdvisor,
  node exporters), which amounts to root on the host. That collides with
  the rule that the player side never gets a Docker socket, if players can
  reach the collector's node. Collect from the infrastructure plane, put
  the collector behind a no-access write policy, use a read-only socket
  proxy, or limit system monitoring to what needs no socket? Refs:
  [planes-and-access.md](planes-and-access.md),
  [versions/v0.2/README.md](versions/v0.2/README.md).
- **O52** (later, v0.4) — dbt adds a Python toolchain and adapters to a
  node image: image size and build time, one image per adapter (Postgres,
  DuckDB), versions to pin. One transformer brick per technology? Refs:
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O53** (later, v0.5) — Bluebox as a dataset:
  - its schema needs PostGIS, `pg_stat_statements` (a preloaded library)
    and `pg_trgm`, so a PostgreSQL 18 brick with those extensions;
  - its dump is about 88 MB compressed and larger restored, against the
    disk budget and the time to load it at setup;
  - a file that size should not live in the repository, yet a scenario
    folder plus the repository is meant to be self-sufficient (D23);
  - its code is MIT-licensed, but part of its data comes from TMDB and
    other sources whose redistribution terms need checking;
  - its ongoing data generation relies on `pg_cron`.

  Refs: [versions/v0.5/README.md](versions/v0.5/README.md).
- **O54** (later, v0.5) — Internet-sourced datasets: availability at setup
  time, licensing, and reproducibility against the self-sufficient
  scenario folder (D23). Pin by address and checksum and cache locally?
  Refs: [versions/v0.5/README.md](versions/v0.5/README.md).

## Resolved

| ID | Resolved by |
|---|---|
| O1 | D4 |
| O4 | D6 |
| O6 | D7 |
| O7 | D8 |
| O17, O18 | D10 |
| O26, O27 | D9 |
| O8 | D11 |
| O36 | D13 |
| O33 | D14, D15 |
| O41 | D17 |
| O42 | D18 |
| O28 | D19 |
| O39 | D20 |
| O40 | D22 |
| O43 | D23 |
| O44 | D24 |
| O15 | D25 |
| O34 | D26 |
| O35 | D27 |
| O37 | D28 |
| O3 | D29 |
| O9 | D30 |
| O14 | D31 |
| O19 | D32 |
