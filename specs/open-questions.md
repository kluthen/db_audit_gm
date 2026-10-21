# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Resolved since: O56 (D57), O59 (D60), O51
(D66), O50 (D67), O13 (D68). Numbering continues from O65.

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
  zones, dual-homed nodes). Refs: [platform.md](platform.md).
- **O57** (soon, v0.2) — A brick's footprint. `brick.yaml` gives one
  figure per dimension (CPU, memory, disk), while
  [formats.md](formats.md) and D56's Footprint section speak of limits and
  reservations; nothing in the scripts reads it, since `gmctl fit` and the
  renderer use the scenario's own `resources`. A Footprint section giving
  both therefore introduces figures `brick.yaml` lacks, against D56's
  agreement rule. Options: (a) `brick.yaml` takes the shape of the
  scenario's `resources` (limits for CPU and memory, reservations for CPU,
  memory and disk) as the default the GM starts from; (b) one figure per
  dimension, with its meaning stated (the reservation, say); (c) no
  footprint in `brick.yaml`, the sizing guidance only in `docs/gm.md`.
  Default (proposed): (a), which matters for v0.2's monitoring bricks in
  the capacity check. Refs: [formats.md](formats.md), "`brick.yaml` must
  contain", "`docs/gm.md` must contain".

- **O58** (soon, v0.2) — Rendered network names. A scenario names its
  networks (`backend` in `bookshop-new-server`) and each node lists those
  it joins, but v0.1 renders exactly one network, `<game_id>_net`,
  whatever the scenario calls it, and refuses a scenario that declares
  more (capture W2-A, `tools/gm/localimpl.py`). Harmless with one network;
  a monitoring network (O12) needs a rule. Default (proposed): one
  rendered network per declared one, named `<game_id>_<network name>`.
  Refs: [formats.md](formats.md), "Local implementation".
- **O64** (soon, v0.2) — The node-health brick: packaging and delivery
  (D66). The format allows a brick that is material installed into other
  bricks' nodes ([formats.md](formats.md), "Placement"), but the template
  and the scripts know only full nodes (an image, an SSH account, s6
  processes). To settle: (1) a brick kind with no node of its own, its
  GM documentation still required (D56); (2) how the script reaches each
  node: delivered at deploy as a protected config with the node's list of
  services, started by a generic s6 service every image carries (a change
  to every brick image: a shared base), or baked into each image;
  (3) how it measures and exposes: the node's own cgroup v2 files for CPU
  and memory (readable inside a Swarm container: to verify), `df` on its
  volumes, `s6-svstat` for services, written in Prometheus text format
  and served on a fixed port by a minimal listener; (4) the default
  services per node: the brick's s6 `processes`, the GM adjusting;
  (5) whether a topology with monitoring has it on every node, or may
  leave one out. Default (proposed): (1) yes; (2) a config, started by a
  generic s6 service in the shared base; (3) and (4) as stated; (5) on
  every node whenever the topology has a metrics store, a node left out
  being a fault. Refs: [bricks-and-faults.md](bricks-and-faults.md),
  "Monitoring bricks (v0.2)".

## Player access and rules

- **O63** (soon, v0.2) — How the bastion publishes the UIs (D68).
  Options: (a) a web front on the bastion, a reverse proxy (~10–20M) on a
  second published port in host mode, every UI behind it under its own
  path, with HTTP basic authentication on the per-game tools password
  since Prometheus has no login of its own, plain HTTP in v0.2;
  (b) SSH local forwarding through the bastion, `PermitOpen` limited to
  the UI endpoints and rendered per game: no new port and no footprint,
  but each player sets up tunnels. Reports leave by `scp` and `sftp` either
  way. Default (proposed): (a): the ruling's "publishes" and the plans for
  the bastion as a web-serving activity point both point there, and it
  spares players with little programming experience the tunnels. Refs:
  [planes-and-access.md](planes-and-access.md), "Bastion only".

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
- **O61** (soon, v0.2) — Scenario versions beyond D58. A scenario keeps
  its version when it only re-pins a brick (D58), and faults never bump
  (D60). Does any other change bump a scenario (its answer key, issues,
  story, topology)? Nothing pins a scenario, so its version only informs.
  v0.2 meets the case at once: `bookshop-new-server`'s answer key changes
  if RG-3 is settled (O70). Default (proposed): as for faults, never bump;
  git history is the record. Refs: [formats.md](formats.md), "Versions and
  pins".
- **O62** (soon, v0.2) — How a silent tooling expectation is written
  and judged. Under-tooling and overkill are no fault kind (D65), yet
  feedback compares what the players found with the fault instances
  present, and an issue covers faults (D9): an expectation outside the
  faults gives feedback a second kind of item, and an issue about
  under-tooling covers no fault. Options: (a) an answer-key list of
  tooling expectations, outside the fault instances, each saying what is
  expected and what is acceptable (any of the research's top three for a
  need, say), with no sealed check, judged in feedback, and an issue may
  cover one; (b) the GM's notes only (`gm/notes.md`), judged freely;
  (c) issues only, no silent expectation. Default (proposed): (a). Refs:
  [formats.md](formats.md), "What a scenario must contain";
  [bricks-and-faults.md](bricks-and-faults.md), "Tooling proportionate to
  the topology".
- **O60** (later) — `applies_to` lists brick versions one by one (the v0.1
  template and faults), where [formats.md](formats.md) used to say
  "version ranges". Since every brick change bumps the brick (D58) and a
  fault applies only to the versions it lists (D59), each bump means
  editing every fault that still applies (eight in dd2c7b4). Ranges would
  spare that, but let a fault claim a brick version nobody tried it on.
  Default (proposed): keep lists. Refs: [formats.md](formats.md), "Versions
  and pins".

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
