# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Numbering continues from O102.

Resolved since v0.2 closed: O45 (D121), O46 (D128), O78 (D140), O82
(D124), O83 (D125), O84 (D126), O85 (D127), O86 (D129), O87 (D130), O88
(D131), O89 (D132), O90 (D133), O91 (D134), O92 (D135), O93 (D136), O94
(D137), O95 (D138), O96 (D139), O97 (D140).

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
  config mounts, the cross-host `127.0.0.1:5000` registry pattern (to
  verify in v0.3's build, D128), SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role beyond v0.2's
  monitoring (settled: D69) and v0.3's producers and consumers (the
  scheduler brick sending SQL to PostgreSQL, D115, D118; other targets
  from v0.5): the two databases, transformation; which engine versions
  first; and how upgrade scenarios (both binaries, disk space) fit the
  budget. Refs: [versions/v1.0/README.md](versions/v1.0/README.md).
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
  compression (generated scenarios, restarts).
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md).
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
  through which review?

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment and probes take
  before a class? Aging alone takes at least two full days (D114), so it
  starts two days before the class at the latest; playgrounds that cannot
  stay up that long wait for a later version (D125).
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Is the feedback written to a file (the teacher is out
  of the game by then)? A scoring system is post-v1.0, unless research
  finds one quick to implement (D120). Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O81** (soon, v0.3) — How a game restart works (D110: allowed from
  v0.3, on the players' explicit confirmation only). To settle: what
  counts as explicit (who may confirm, the GM restating that the game's
  state and the players' work are lost, a passing comment never enough);
  what the rebuild keeps (the game id, the per-game credentials, the
  session's clock) and redoes (data load, faults planted again); how it
  is recorded in the local implementation; whether the access model
  lists it with the confirmed operations, beside `stop`, which needs no
  confirmation. Also to confirm: a whole-game restart is distinct from
  the node resets D19 and D48 leave beyond v1.0, which stay there.
  Settled since (D123): every node shut down, the game data destroyed,
  fresh nodes, the game set up again, the replay possibly different; so
  the data load and the faults are redone; the hand-over snapshot
  restored where the disk allows, else no history; the players'
  credentials kept, the game id renewed (D126). Still open: who may
  confirm, what the GM restates first, how the restart is recorded,
  and its place in the access model. Recommended: any player in the GM
  session may confirm, in so many words, after the GM states that the
  game's state and the players' changes are lost and, without a
  snapshot, which evidence is lost; the local implementation records
  each restart (old and new game id, time, snapshot or not); the access
  model lists it as a confirmed operation beside `stop`. Refs:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md)
  "Restart", [gm-stance.md](gm-stance.md).

## v0.3: producers, consumers and aging

Raised while v0.3 is drafted. O82 to O97, raised when the drafting
opened, were all answered on 2026-10-22 (D124–D140). Refs are in
[versions/v0.3/](versions/v0.3/README.md).

- **O98** (soon, v0.3) — How the hand-over snapshot (D126) is taken.
  Options: (a) every node stopped briefly at hand-over and its volumes
  copied: simple, but a second visible gap, just before the game; (b)
  per-brick online copies: `pg_basebackup` for `postgres`, Prometheus'
  TSDB snapshot (its admin API on, reachable from the node's own shell),
  a plain copy for seed-only volumes; one gap only, at the restart.
  Recommended: (b), each brick declaring how its volumes are copied, (a)
  for a brick that declares nothing; `fit` counting the copies' disk, and
  the GM falling back to D126's no-history restart when they do not fit.
  Refs: aging-and-timeline.md "Restart".
- **O99** (soon, v0.3) — The per-file write policy (D130) in the format.
  Recommended: the node's `write_policy` stays its default, and a
  scenario may set `fixable` on paths the brick lists as writable
  (`write_overrides: [queries.yaml, builders/, jobs.yaml]`); a fault's
  `fix` resolution then needs the policy of the file the fault lives in,
  which the loader checks. Applies to every brick, the scheduler first.
  Alternative: a scheduler-only parameter. Refs: format-changes.md.
- **O100** (later, v0.3) — A connection reserve of the GM's own
  (D124): PostgreSQL's `reserved_connections` with a check role holding
  `pg_use_reserved_connections`, pinned on the server's command line by
  the brick so no configuration file overrides it. Without it the GM
  shares `superuser_reserved_connections` with the players' `dba`.
  Recommended: yes, in `postgres`'s v0.3 bump; the players can still
  exhaust it as `dba`, on the trust line. Refs: checks-under-load.md.
- **O101** (later, v0.3) — Under O78's option (b) (D140), which locations
  a `fault.yaml` evidence may name. Recommended: `node` (its target node)
  and `report:<tool>` for a tool the target's brick ships; `bastion`; no
  `ui:<name>`, whose routes only the scenario knows, so the answer key
  adds those. Refs: carried-items.md.

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47). The tag after the priority is the version
the question concerns.

- **O47** (later, v1.0) — Which version brings scenario generation: the GM
  designing from a partial or empty brief and filling the blanks (D16)?
  v0.5 prepares for it without naming it. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O48** (later, v0.3 → v1.0) — Aging enters in v0.3, in real time
  (D114). Where does the solvability probe as a gate (O20) enter the
  roadmap? With two days of aging, a probe failing at hand-over costs the
  class; v0.3's draft proposes an early check during aging. Refs:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md),
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
