# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Resolved since: O56 (D57), O59 (D60), O51
(D66), O50 (D67), O13 (D68), O65 (D72), O61 (D75), O62 (D76), O63
(D77), O66 (D78), O68 (D79), O69 (D80), O70 (D81), O71 (D82), O57 (D84),
O58 (D85), O60 (D86), O64 (D88), O67 (D90), O72 (D100), O73 (D101),
O74 (D102), O75 (D103), O76 (D104), O77 (D105). Numbering continues
from O79.

Priority: **next** = shapes everything else, ask first; **soon** = needed
for the next version (v0.1 until it closed, with none left open);
**later** = can wait for v1.0 or beyond.

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
- **O11** (later) — Which technology fills each v1.0 role beyond v0.2's
  monitoring (settled: D69): producer, the two databases, transformation,
  consumer; which engine versions first; and how upgrade scenarios (both
  binaries, disk space) fit the budget. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). v0.2 has one network and no network faults
  (D83). Refs: [platform.md](platform.md).

## Faults and aging

- **O20** (later) — Confirm the reading of D28: no project-wide mandatory
  machine check (no common brick lint, no schema check in the format skill),
  only the checks each brick ships. And confirm the solvability probe as a
  gate for generated scenarios, run after aging and before hand-over. As
  built in v0.1, the scripts already check every scenario, and the bricks
  and faults it uses, against the templates when they load it
  (`tools/gm/model.py`), a project-wide check the reading did not foresee,
  while the format skill says there is no schema-check script. Refs:
  [bricks-and-faults.md](bricks-and-faults.md), [formats.md](formats.md)
  "Enforcement".
- **O21** (later) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario?
- **O22** (later) — Default aging technique per fault (pre-aging, forged
  history, time compression). Time compression is visible to the auditor
  (`*/5` on a "daily" job), collides with schedule faults, and must stay
  consistent with forged timestamps. v0.2 has no aging (D83). Refs:
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
- **O78** (soon, v0.3) — `where` means two things in v0.2. D101 makes the
  answer key's evidence `where` a location from a fixed set and moves
  v0.1's free text to `source`; `fault.yaml`'s `evidence[]` keeps v0.1's
  free-text `where` (the wave driver's resolution of capture W1). Options:
  (a) leave it; (b) move `fault.yaml`'s text to `source` and give its
  `where` the location set, with `node` meaning the fault's target node
  (a fault knows no topology), in a later chunk or version. Recommended:
  (b) in v0.3's first format change: a GM copying a fault's
  evidence into an answer key copies a free-text `where` the loader then
  refuses; the loader catches it, so it blocks nothing in v0.2, and a
  v0.2 chunk for it would reopen chunks 1 and 2 mid-wave. Still to settle
  under (b): which of `ui:<name>` and `report:<tool>` a fault may name,
  since it cannot know the routes. Refs: [formats.md](formats.md),
  [versions/v0.2/wave-log.md](versions/v0.2/wave-log.md) capture W1 item
  9, `.claude/skills/scenario-format/templates/fault.yaml`.

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

- **O46** (later, v0.3 → v1.0) — Multi-host and the registry were
  deferred from v0.1. Does v1.0 still run on one host, or does the full
  pipeline with monitoring need a multi-host swarm and a registry? v0.2
  runs on one host, with `gmctl fit` counting images against the
  declared disk (D83). Refs:
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
