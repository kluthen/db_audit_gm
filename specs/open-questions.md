# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Numbering continues from O111.

Resolved since v0.2 closed: O45 (D121), O46 (D128), O78 (D140), O82
(D124), O83 (D125), O84 (D126), O85 (D127), O86 (D129), O87 (D130), O88
(D131), O89 (D132), O90 (D133), O91 (D134), O92 (D135), O93 (D136), O94
(D137), O95 (D138), O96 (D139), O97 (D140), O81 (D141), O98 (D142), O99
(D143), O100 (D144), O101 (D145), O102 (D171), O103 (D175).

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
  config mounts, SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role beyond v0.2's
  monitoring (settled: D69) and v0.3's producers and consumers (the
  scheduler brick sending SQL to PostgreSQL, D115, D118; other targets
  from v0.5). Narrowed for v0.4 by D190: transformation is a generic
  job runner started from the scheduler brick (O105), the second
  database PostgreSQL by default, another engine only if a purpose
  needs one (O106). Still open: which engine versions first, and how
  upgrade scenarios (both binaries, disk space) fit the budget. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
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
- **O22** (later, beyond v0.3) — Aging technique. v0.3 ages in real time
  only, with no sped-up clock, no forged history and no time compression
  (D114, D132), on always-on hosts (D125). Still open: which version
  copies aged volumes to a class's hosts (D125), and whether a later
  version brings back forged history, a sped-up clock or time
  compression (generated scenarios, restarts). With the eight-hour floor
  (D150), a classroom swarm staying up for a school day may become
  enough for short-aging scenarios, which may change how much the
  volume copy is needed; noted, not reopened (D125 stands).
  Not moot: v0.4's purposes (D190) run daily, weekly or monthly jobs,
  which real time alone barely exercises; that part is O109.
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O23** (later) — Difficulty is a fault count, each fault worth 1 (easy
  5, normal 10, hard 20; D120), read for v0.3 as the number of fault
  instances, the levels being targets (D134). Still open:
  how many faults issues cover, the mix of families, and may an issue be
  a false alarm (a complaint with no fault behind it)? Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O24** (later) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O25** (later) — Scenario-only bricks and faults may live in the
  scenario's folder (D24). Can they be promoted into the catalog, and
  through which review? From v0.4 the question is mostly about purposes
  (D190): a purpose built for one scenario, its jobs, invariants and
  faults, promoted into the catalog, rather than a transformer brick.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment and probes take
  before a class? Aging alone takes at least eight hours, as long as the
  scenario declares (D114, D150), so it starts that long before the class
  at the latest; playgrounds that cannot stay up that long wait for a
  later version (D125).
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Is the feedback written to a file (the teacher is out
  of the game by then)? A scoring system is post-v1.0, unless research
  finds one quick to implement (D120). Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
## v0.3: producers, consumers and aging

Raised while v0.3 is drafted. O82 to O97, raised when the drafting
opened, and O98 to O101, raised by their answers, were all answered on
2026-10-22 (D124–D145). The drafts' `(proposed)` items
await the owner's review in
[versions/v0.3/review-list.md](versions/v0.3/review-list.md). O102,
raised at wave 1's preflight, was answered the same day (D171), and
O103, raised at wave 2's preflight, on 2026-10-26 (D175). None is open.

## v0.4: purposes

Raised when the owner recast v0.4 as "bricks of why and bits of hows"
on 2026-10-28 (D190). O11, O22, O25 and O52 are revised by it.

- **O104** (soon, v0.4) — The purpose format: its definition, template
  and completeness rules in [formats.md](formats.md), then the
  `scenario-format` skill and the scenario document. Includes the final
  name ("purpose" is a working name); how a job states its source,
  target, computation and timing; how a fault attaches to a purpose as
  well as to a brick (`applies_to` names a brick and its versions
  today); whether a purpose has a version, as a brick does, or never
  bumps, as faults and scenarios; and how a check learns when a fix
  happened, so it answers "too soon to tell" until the job has run since
  (v0.3's behavioural checks judge a trailing window and are never
  told). Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O105** (soon, v0.4) — The job runner: extend v0.3's `scheduler`
  brick (`queries.yaml`, `schedule.yaml`, `jobs.yaml`) or fork it into a
  brick of its own? Either way, what the players read and change of a
  job (v0.3: the fixed-time operations, D116), and how it meets v0.5's
  plan for transformation triggers as scheduler drivers (D118). Refs:
  [versions/v0.4/README.md](versions/v0.4/README.md),
  [versions/v0.3/scheduler.md](versions/v0.3/scheduler.md).
- **O106** (soon, v0.4) — Does any v0.4 purpose need an engine beyond
  PostgreSQL (columnar or other)? The owner: "we may have to introduce
  other database at this step despite what i've said. We shall see."
  If one does, it brings an engine D47 placed beyond v1.0 into v0.4.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O107** (next, v0.4) — Which purposes are in v0.4? Proposed: two or
  three, for example a BI rollup into a reporting database, lead
  extraction, and a mailing job to an outbox; reports, dashboards and
  finance could follow, or one of them could replace one of these.
  Shapes O106, O108 and O109. Refs:
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O108** (soon, v0.4) — The shared business data model (orders,
  customers, payments, refunds, consent, time zones): what it holds,
  where it lives (catalogue or per scenario), how the data load and the
  producers write it, and how it relates to v0.5's library of common
  schemas, which it partly brings forward. Probably v0.4's main
  technical work. Refs: [versions/v0.4/README.md](versions/v0.4/README.md),
  [versions/v0.5/README.md](versions/v0.5/README.md).
- **O109** (soon, v0.4) — Daily, weekly or monthly purposes under real
  time, with no sped-up clock (D114, D132): v0.3's scenario ages sixteen
  hours, so a daily job runs once or twice per game, and nobody triggers
  a job during a game (D131), so a fix may stay "too soon to tell" to
  the session's end. Run the jobs more often than their story says, or
  ship pre-aged derived history (past results already in the trace)?
  The second may count as the forged history D114 and D132 rule out.
  Linked to O22. Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O110** (later, v0.4) — Is a real mail sink ever needed, or is the
  outbox always enough? Current view: the outbox is enough. Refs:
  [versions/v0.4/README.md](versions/v0.4/README.md).

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47). The tag after the priority is the version
the question concerns.

- **O47** (later, v1.0) — Which version brings scenario generation: the GM
  designing from a partial or empty brief and filling the blanks (D16)?
  v0.5 prepares for it without naming it. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O48** (later, v0.3 → v1.0) — Aging enters in v0.3, in real time
  (D114). Where does the solvability probe as a gate (O20) enter the
  roadmap? With an aging of eight hours or more (D150), a probe failing at
  hand-over costs the class; v0.3's master spec has an early check during
  aging and a hand-over check. Refs:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O49** (soon, roadmap) — Backup tools (pgBackRest and the like) and the
  backup-tooling fault families (D17) are in no version, although backups
  were a founding example and the v0.1 goal speaks of "investigating a
  backup". Which version? Refs:
  [bricks-and-faults.md](bricks-and-faults.md), "Future ideas: backup
  tooling".
- **O52** (later, after v0.4) — dbt adds a Python toolchain and adapters
  to a node image: image size and build time, one image per adapter
  (Postgres, DuckDB), versions to pin. One transformer brick per
  technology? v0.4 plans no dbt: its jobs run on one generic job runner
  (D190, O105). Stands for whichever later version or purpose wants dbt.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
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
- **O79** (later, v0.5) — The brick options model (D107), `postgres`
  first. In `postgres` 0.2.0, pgBadger, file logs on the `pglog` volume,
  `pg_stat_statements`, the `monitoring` role and its
  `monitoring_password` secret are in every game, while the logging and
  preload settings are the scenario's, in its seed `postgresql.conf`.
  First candidate options: those four, then PostGIS, TimescaleDB and the
  replication modules. To settle:
  1. Where an option's software comes from, given a read-only root and no
     network at start: one image carrying every option (simple, but
     PostGIS alone adds a few hundred MB every game pays), image variants
     per option set (e.g. `postgres:0.x.0-postgis`), or a mix (light
     options in the base, heavy ones as variants). `fit` counts image
     sizes (D102), so the choice shows in capacity.
  2. How a scenario chooses: e.g. `options: [pgbadger,
     pg_stat_statements, postgis]` on the node, with `brick.yaml`
     declaring the options it offers, each with its requirements
     (preload library, volume), its footprint, and the secrets and
     volumes that exist only with it (`pglog` and `monitoring_password`
     would become per-option).
  3. What start-up does for an option (create the extension, the role,
     the directory), while its settings in `postgresql.conf` (preloads,
     logging) stay in the seed so a fault can still remove them; the
     loader checks the seed agrees with the chosen options.
  4. Faults that need an option, as `applies_to` ties a fault to a brick
     and version.
  5. Documentation: one section per option in the brick's `docs/gm.md`
     (what it adds, its cost, how to enable it, the faults it allows).

  Akin to v0.2's declare/choose/check pattern for mounted material and
  `receives` (D97). Refs: [versions/v0.5/README.md](versions/v0.5/README.md),
  [formats.md](formats.md) "Brick definition",
  [versions/v0.2/master-spec.md](versions/v0.2/master-spec.md) 7.5.
- **O80** (later, v0.5) — Is the options model (O79) meant for every
  brick, or only `postgres`? The owner's direction (D107) names
  `postgres` "in particular". Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md).
