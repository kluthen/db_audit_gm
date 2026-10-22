# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Numbering continues from O98.

Resolved since v0.2 closed: O45 (D121).

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
  only, with no sped-up clock and no forged history (D114). Still open:
  whether a later version brings back forged history or a sped-up clock
  (generated scenarios, restarts, playgrounds that cannot stay up two
  days; O83, O84), and time compression during the game (O89 for v0.3).
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md).
- **O23** (later) — Difficulty is a fault count, each fault worth 1 (easy
  5, normal 10, hard 20; D120); its reading for v0.3 is O91. Still open:
  how many faults issues cover, the mix of families, and may an issue be
  a false alarm (a complaint with no fault behind it)? Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O24** (later) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
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
- **O30** (later) — How long may design, deployment and probes take
  before a class? Aging alone takes at least two full days (D114), so it
  starts two days before the class at the latest; playgrounds that cannot
  stay up that long are O83.
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
  the data load and the faults are redone. Recommended for the rest: the
  players' credentials kept, the game id renewed (D36). What a restart
  does to the aged history: O84. Refs:
  [versions/v0.3/aging-and-timeline.md](versions/v0.3/aging-and-timeline.md)
  "Restart", [gm-stance.md](gm-stance.md).

## v0.3: producers, consumers and aging

Raised when v0.3's drafting opened (2026-10-22). Refs are in
[versions/v0.3/](versions/v0.3/README.md).

- **O82** (next, v0.3) — How sealed checks, validators and the smoke
  tests judge "present" and "fixed" while the load runs (drift, jitter,
  lagging counters, checks refused under connection exhaustion).
  Proposed: judge the cause, not the symptom, where it is checkable;
  behavioural checks over a stated trailing window from stable counters;
  a new exit code for "too soon to tell"; the GM's checks never pause the
  load and always get a connection. Refs: checks-under-load.md.
- **O83** (next, v0.3) — Real-time aging needs the hosts up for two days
  before the game. A classroom swarm of the students' laptops is not
  there, and a stateful node's volumes live on one host. Options: (a)
  v0.3 games run on always-on hosts only, classroom swarms wait; (b) age
  on always-on hosts, then move the volumes to the class's hosts at
  hand-over (a stop and a copy, the restart snapshot's machinery); (c)
  the class's hosts join two days early. Refs: aging-and-timeline.md,
  [platform.md](platform.md) "Hosting".
- **O84** (next, v0.3) — What a restart (D123) does with the aged
  history: (a) the restarted game has only the history since the
  restart, the GM naming the evidence lost before confirmation; (b) it
  re-ages, a postponement; (c) a hand-over snapshot of every volume,
  restored on restart, with a gap the story calls maintenance (disk
  cost; a short stop or per-brick online copies at hand-over). Refs:
  aging-and-timeline.md "Restart".
- **O85** (next, v0.3) — May a scenario's timeline change something at a
  fixed moment during aging (plant a fault, switch a key to a faulty
  query, raise a rate), written at design time, or is everything set at
  the start of aging? Never during the game (D117). Refs: scheduler.md
  "The schedule", aging-and-timeline.md "Faults during aging".
- **O86** (soon, v0.3) — Traffic shapes and fixed-time operations follow
  the UTC wall clock (D81), so a scenario designed for a morning class
  shows night-time load to an evening one. Options: (a) the wall clock
  as written, the GM designing for the class's hour; (b) the local
  implementation shifts the whole schedule by whole hours so the game
  window gets the designed load, every clock staying real UTC and the
  story naming the customer's time zone. Refs: scheduler.md.
- **O87** (soon, v0.3) — What players see on a scheduler node beyond the
  repository and `jobs.yaml` (D116): its log (runs, errors, per-key
  summaries), its configuration other than the schedule, its metrics;
  and whether write policy becomes per file (repository fixable, node
  report-only). For the access model. Refs: scheduler.md "What the
  players reach".
- **O88** (soon, v0.3) — Confirm: during the game nobody, GM or player,
  pauses, speeds up or triggers the load, not even for the final checks;
  the players' only lever is moving a fixed-time operation, with no
  "run now". Refs: load-and-capacity.md "Load control".
- **O89** (soon, v0.3) — Time compression (a "daily" job every few
  minutes during the game) in v0.3? Proposed: none; the aging gives every
  daily job two runs, and players verify a fix to a job by moving its
  time (D116). Refs: scheduler.md "Fixed-time operations".
- **O90** (soon, v0.3) — The repository's semantics: is `key -> [queries]`
  a pool (one picked per call; proposed) or a sequence; and a builder the
  players may edit is code run by the scheduler's account (accepted on
  the trust line, proposed)? Refs: scheduler.md "The query repository".
- **O91** (soon, v0.3) — v0.3's scenario and faults: one new scenario
  (proposed: normal difficulty, ten faults, producers, consumers,
  monitoring, PgBouncer); which candidate faults join the catalog; the
  difficulty reading (score = fault instances, tooling expectations not
  counted, levels as targets: `bookshop-new-server` scores 6, `fernway`
  8). Refs: faults-with-activity.md.
- **O92** (soon, v0.3) — Does the release gate need one full aged run
  (two days of host time) of the v0.3 scenario, played as `player`?
  Proposed: yes, once; smoke tests run short. Refs: checks-under-load.md.
- **O93** (soon, v0.3) — Randomness seeded, the seed recorded per game in
  the local implementation; a restart takes a new one (the replay may
  differ, D123). Proposed. Refs: scheduler.md.
- **O94** (soon, v0.3) — A pluggable driver in the scheduler, SQL on
  PostgreSQL first, so v0.5's targets (D118) add a driver, not a format.
  Proposed. Refs: scheduler.md "Drivers".
- **O95** (soon, v0.3) — `max_connections`: keep the `postgres` brick's
  default at 100, scenarios setting low values within the 10–200
  envelope (the driver's proposal), or lower the default? Refs:
  load-and-capacity.md.
- **O96** (soon, v0.3) — PgBouncer: metrics through a
  `pgbouncer_exporter` brick or none in v0.3; the players' console role
  (`stats_users` only, proposed); write policy per scenario. Refs:
  pgbouncer.md.
- **O97** (soon, v0.3) — Which carried items v0.3 takes: report-only
  monitoring nodes (D108), O78's option (b), RG-2, RG-3, Prometheus
  retention covering the aged history, the format's aging items.
  Proposed: all. Refs: carried-items.md.

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47). The tag after the priority is the version
the question concerns.

- **O46** (soon, v0.3) — Multi-host and the registry were deferred from
  v0.1; v0.2 runs on one host (D83). Multi-host is available (D122:
  Swarm, Tailscale on armenelos and the VPS). The driver's proposal:
  multi-host moves into v0.3, with per-node placement, a registry every
  host reaches, `fit` per host, tested on armenelos and the VPS; the
  default game stays single-host while its load fits. Risks: VXLAN over
  Tailscale's MTU, the routing mesh publishing the bastion on the VPS's
  public address. Refs:
  [versions/v0.3/load-and-capacity.md](versions/v0.3/load-and-capacity.md),
  [platform.md](platform.md).
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
