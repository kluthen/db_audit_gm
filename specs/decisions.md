# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived: D1–D54 (v0.1), verbatim in
[archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md);
where each one now lives is in
[archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
Archived IDs keep their meaning and are cited as they are. Numbering
continues from D55; no ID is reused.

- **D55 (2026-10-21, set by spec-writer at the v0.1 archive, as built;
  acknowledged by the owner the same day):
  `/run` is a named volume, not a tmpfs.** A stack file's tmpfs is
  `noexec` and s6-overlay must execute from `/run`, so chunk 2 took the
  build plan's fallback (a): a named volume the entrypoint empties at each
  start (wave-log capture W1-E). Replaces the tmpfs wording of D30 and D41;
  the read-only root stands. Sections 9.1 and 9.2 also list the volumes as
  built (the players' homes, the bastion's host key) and drop a `sudo` log
  target on the bastion, which has no `sudo`. Now in:
  [versions/v0.1/master-spec.md](versions/v0.1/master-spec.md) sections
  9.1 and 9.2, [planes-and-access.md](planes-and-access.md) "Node
  hardening".
- **D56 (2026-10-21, owner ruling): Every brick ships GM documentation
  with required sections.** `docs/gm.md` must have nine: purpose,
  placement, configuration, connections, access, footprint, supported
  faults, checks, known limits, so the GM knows what to install where and
  how to configure and wire it; the format skill refuses a brick that
  lacks one. Applies from v0.2; the v0.1 bricks are brought up to it.
  Access and known limits were added by spec-writer to the owner's seven,
  under the ruling's leave to refine. Now in: [formats.md](formats.md)
  "`docs/gm.md` must contain", [versions/v0.2/README.md](versions/v0.2/README.md).
- **D57 (2026-10-21, owner ruling; resolves O56): A documentation update
  to a brick bumps its version.** "Well they need to be updated, so it
  updates the brick version." Applied in dd2c7b4: `postgres` and `bastion`
  0.1.0 → 0.1.1 wherever pinned; for `postgres`, 0.1.1 also covers the
  RG-1 rebuild (D54), which had kept 0.1.0. The 0.1.1 images are
  byte-identical to 0.1.0. Now in: [formats.md](formats.md) "Versions and
  pins", "`docs/gm.md` must contain".
- **D58 (2026-10-21, owner ruling): The bump rule is for bricks only.** Any
  change to a brick bumps its version. A fault or a scenario keeps its
  version when it only re-pins a brick or widens `applies_to`, so the
  catalog's six faults, the two fixture faults and both scenarios are
  right to have kept theirs in dd2c7b4. Other changes to a fault or a
  scenario are not ruled (O59). Now in: [formats.md](formats.md) "Versions
  and pins".
- **D59 (2026-10-21, owner ruling): A fault's `applies_to` is the only
  source of which faults a brick hosts.** The code already reads only that
  (`tools/gm/model.py`); `compatible_faults` leaves `brick.yaml`, its
  template, both bricks and the format skill, and the brick's GM
  documentation lists the faults whose `applies_to` names it. 0.1.1 is not
  yet released (`v0.2-draft` is unmerged), so the removal folds into it
  with no further bump. Now in: [formats.md](formats.md) "`brick.yaml`
  must contain", "`docs/gm.md` must contain", "Versions and pins".
- **D60 (2026-10-21, owner ruling; resolves O59 for faults): Faults never
  bump.** A fault keeps its version whatever changes; git history is the
  record. A scenario's fault pin then names the fault, not a state of it.
  Scenarios' own versions beyond D58 stay open as O61. Now in:
  [formats.md](formats.md) "Versions and pins".
- **D61 (2026-10-21, owner ruling): The fold rule is general.** While a
  brick's new version is unreleased (its branch not merged into `main`),
  further changes fold into it with no extra bump; D59 had applied it to
  0.1.1 only. Now in: [formats.md](formats.md) "Versions and pins".
- **D62 (2026-10-21, owner ruling): A brick's "Supported faults" lists
  catalog faults only.** A fault defined in a scenario's own `faults/`
  folder is the scenario's, not the brick's, and is not listed. Both v0.1
  bricks' `docs/gm.md` already say so. Now in: [formats.md](formats.md)
  "`docs/gm.md` must contain", section 7.
- **D63 (2026-10-21, owner rulings): v0.2's reference, gap and limits.**
  `~/audits/bluebox-lab` is the reference setup; a general per-node health
  view (CPU, RAM, disk, services) is the gap v0.2 fills; monitoring bricks
  may carry faults of their own (ill-configured, missing nodes, starved of
  information); free tools only, a free tool or a script replacing a paid
  one. Now in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring
  bricks (v0.2)", "Example families".
- **D64 (2026-10-21, owner ruling): One brick per need, chosen by
  footprint.** Research may list the top three per need; v0.2 ships about
  one, and footprint on a 2 CPU / 4G / 8G laptop is a main criterion. Now
  in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks
  (v0.2)", [platform.md](platform.md) "Resources and nerfing".
- **D65 (2026-10-21, owner ruling): Optional, proportionate tooling;
  under-tooling is no fault kind.** Monitoring bricks are optional in a
  topology. Under-tooling is an issue the customer raises, a silent
  expectation of the GM, or both; tooling about three times the compute
  and disk of what it watches is overkill, also a finding. Rejected: a
  fault kind `absent`. How an expectation is written: O62. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Tooling proportionate to
  the topology".
- **D66 (2026-10-21, owner ruling; resolves O51): Per-node health is a
  daemon script on every node.** Provided at initialisation, it reports the
  node's CPU, RAM, disk and the status of the services the GM names for
  that node, and feeds Prometheus; no cAdvisor, no Docker socket. Other
  open-source health tools (Nagios or others) are for v0.5. Packaging:
  O64. Now in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring
  bricks (v0.2)", [planes-and-access.md](planes-and-access.md) "Rules and
  validators".
- **D67 (2026-10-21, owner ruling; resolves O50): Thin monitoring, no load
  in v0.2.** Dashboards watch a static database; load stays v0.3's. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Out of scope".
- **D68 (2026-10-21, owner ruling; resolves O13): The bastion publishes
  the UIs.** Every monitoring web interface is reached through the
  bastion; no other node publishes a port. The mechanism: O63. Now in:
  [planes-and-access.md](planes-and-access.md) "Bastion only",
  [scenario-lifecycle.md](scenario-lifecycle.md) "Hand-over".
- **D69 (2026-10-21, owner ruling after the tooling research; narrows
  O11): v0.2's tools.** `postgres_exporter`, Prometheus, PostgreSQL logs
  to files with pgBadger as a one-shot job and no log aggregator, Grafana
  with its own alerting; the health script feeds Prometheus. The ruling
  names neither pgwatch nor pgCluu, so neither is a v0.2 brick. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks (v0.2)".
- **D70 (2026-10-21, owner ruling): v0.5 extends the tooling.** Other
  tools and hand-made scripts come in v0.5, beyond v0.2's basic defaults.
  Now in: [versions/v0.5/README.md](versions/v0.5/README.md) "In scope".
- **D71 (2026-10-21, owner ruling): v0.6, the bastion as the players'
  main activity point.** A new version, after v0.5: the bastion publishes
  the dashboards and monitoring tools, hosts a documentation website, and
  provides general-use tooling (`psql`, `pg_dump` and the like). v0.2
  only publishes the monitoring UIs (D68). Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md),
  [versions/README.md](versions/README.md).
- **D72 (2026-10-21, owner ruling; resolves O65): v0.2's brick version
  numbers.** `v0.2-draft` was merged into `main` (5c16d06), which releases
  `postgres` and `bastion` 0.1.1; a v0.1 brick the v0.2 build changes
  takes 0.2.0, later v0.2 changes folding into it (D61). New bricks start
  at 0.1.0, the drafted default. Now in: [formats.md](formats.md)
  "Versions and pins".
- **D73 (2026-10-21, owner ruling; narrows O64): The GM installs the
  node-health script at deploy.** The script and its s6 service are
  mounted into each node as configs, so an image only has to accept a
  mounted service; no image carries the script. D66 is read as drafted:
  the script runs on every node whenever the topology has a metrics
  store, and a node left out is a monitoring fault. How it measures and
  which services it watches stay as drafted. How the brick is declared:
  O64. Now in: [bricks-and-faults.md](bricks-and-faults.md) "Monitoring
  bricks (v0.2)", [versions/v0.2/README.md](versions/v0.2/README.md).
- **D74 (2026-10-21, owner ruling on the drafted default; narrows O67):
  v0.2's node shape.** Every new brick is a full node; Prometheus, Grafana
  and `postgres_exporter` each have a node of their own; pgBadger and
  `pg_stat_statements` live in `postgres`. The shared base image stays
  open (O67): the reason for it was the node-health service, which D73
  mounts instead. Now in: [versions/v0.2/README.md](versions/v0.2/README.md)
  "Node shape".
- **D75 (2026-10-21, owner ruling; resolves O61): Scenarios never bump.**
  As with faults (D60), a scenario keeps its version whatever changes, and
  git history is the record; nothing pins a scenario. Now in:
  [formats.md](formats.md) "Versions and pins".
- **D76 (2026-10-21, owner ruling; resolves O62): Silent tooling
  expectations are an answer-key list.** Kept apart from the fault
  instances, with no sealed check, judged in feedback; an issue may cover
  one. Rejected: the GM's notes only; issues only. Now in:
  [formats.md](formats.md) "What a scenario must contain".
- **D77 (2026-10-21, owner ruling; resolves O63): A web front on the
  bastion publishes the UIs.** Rejected: SSH forwarding through the
  bastion, which has each player set up tunnels. Now in:
  [planes-and-access.md](planes-and-access.md) "Bastion only".
- **D78 (2026-10-21, owner ruling; resolves O66): v0.2's scenarios.** One
  new, partly tooled, one-database scenario, and `bookshop-new-server`
  re-pinned as the v0.1 regression. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "The scenario".
- **D79 (2026-10-21, owner ruling; resolves O68): One per-game tools
  password; secrets generated by kind.** Now in:
  [planes-and-access.md](planes-and-access.md) "Credentials and the way
  in".
- **D80 (2026-10-21, owner ruling; resolves O69): v0.2's fault set.** Four
  to six monitoring faults visible without load, mixed with v0.1 faults;
  a masking pair waits for O23. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Faults".
- **D81 (2026-10-21, owner ruling; resolves O70 and v0.1's RG-3 and
  RG-4): Evidence says where it is run; every time is UTC.** Now in:
  [formats.md](formats.md) "What a scenario must contain",
  [gm-stance.md](gm-stance.md) "Sessions and restarts",
  [versions/v0.2/README.md](versions/v0.2/README.md) "Evidence and times".
- **D82 (2026-10-21, owner ruling; resolves O71): v0.2's definition of
  done.** Now in: [versions/v0.2/README.md](versions/v0.2/README.md)
  "Definition of done".
- **D83 (2026-10-21, owner ruling; narrows O12, O22 and O46): v0.2's
  platform limits.** One network and no network faults; no aging; one
  host, with `gmctl fit` counting images against the declared disk. The
  later parts of the three questions stay open. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Platform and
  capacity", [platform.md](platform.md) "Resources and nerfing".
- **D84 (2026-10-21, owner ruling; resolves O57): A brick's footprint has
  the shape of a scenario's `resources`.** Now in:
  [formats.md](formats.md) "`brick.yaml` must contain".
- **D85 (2026-10-21, owner ruling; resolves O58): One rendered network
  per declared network.** Now in: [formats.md](formats.md) "Local
  implementation".
- **D86 (2026-10-21, owner ruling; resolves O60): `applies_to` lists
  versions one by one.** Rejected: ranges, which would let a fault claim
  a brick version nobody tried it on. Now in: [formats.md](formats.md)
  "`fault.yaml` must contain".
- **D87 (2026-10-21, owner ruling): The v0.2 page's other drafted
  defaults are accepted.** They are the defaults held by no question: the
  monitoring bricks' details, the log-reading consequence, and the
  bastion's tools not counting as the customer's tooling. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Monitoring
  bricks", "Tooling proportionate to the topology".
- **D88 (2026-10-21, owner ruling; resolves O64): The node-health script
  is companion material of the `prometheus` brick.** It has no version of
  its own: a change to it bumps `prometheus` (D57), and faults about it
  name `prometheus` in `applies_to`. Its GM documentation is
  `prometheus`'s `docs/gm.md`: Placement covers mounting it into the other
  nodes, Configuration the per-node service list. The `mounted` brick kind
  proposed under O64 is not adopted. Now in:
  [formats.md](formats.md) "Brick definition",
  [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks (v0.2)".
- **D89 (2026-10-21, set by spec-writer working out D88): Companion
  material the GM mounts into other nodes.** A brick's companion material
  may include files the renderer mounts as configs into other nodes at
  deploy; `brick.yaml` declares them. For the node-health script, the
  service list is a parameter of the `prometheus` node, and a node left
  out of it is D73's fault. Now in: [formats.md](formats.md) "`brick.yaml`
  must contain", "`docs/gm.md` must contain".
- **D90 (2026-10-21, owner ruling; resolves O67): No shared base image in
  v0.2.** Every brick builds from `debian:13-slim`, and the v0.1 bricks
  are not rebased. Now in: [versions/v0.2/README.md](versions/v0.2/README.md)
  "Node shape".
- **D91 (2026-10-21, owner ruling after the v0.2 review): Prometheus and
  Grafana keep separate nodes.** Sharing one node is dropped as a
  footprint lever, as D64 and D74 imply. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Node shape".
- **D92 (2026-10-21, owner ruling after the v0.2 review): Node-health
  faults target the `prometheus` node.** The affected node is a fault
  parameter and `applies_to` names `prometheus` only; such a fault is
  planted through a parameter, a new injection kind. Now in:
  [formats.md](formats.md) "`fault.yaml` must contain".
- **D93 (2026-10-21, owner ruling after the v0.2 review): The tools
  password always opens Grafana.** The candidate fault "Grafana's
  administrator left on its default password" is dropped, since D79 sets
  that password per game. Now in:
  [versions/v0.2/README.md](versions/v0.2/README.md) "Faults".
- **D94 (2026-10-21, owner ruling after the v0.2 review): Grafana's write
  policy is a known gap.** Players are Grafana administrators through the
  tools password, so on a report-only Grafana node they can still change
  dashboards, data sources and alert rules in the UI. Accepted under light
  enforcement, like the superuser gap on report-only databases; sealed
  checks judge Grafana's effective live state, not only its provisioned
  files. Now in: [planes-and-access.md](planes-and-access.md) "Player
  access to nodes".
- **D95 (2026-10-21, owner ruling after the v0.2 review): Players run
  pgBadger themselves.** The PostgreSQL log files are readable by the
  players' group; no wrapper. Now in:
  [planes-and-access.md](planes-and-access.md) "The database node".
- **D96 (2026-10-21, owner ruling after the v0.2 review): Node-health disk
  is per node.** Each node reports the use of its own volumes (`du`)
  against its declared disk reservation; the host's free space is shown
  once in the view, not per node. Now in:
  [bricks-and-faults.md](bricks-and-faults.md) "Monitoring bricks (v0.2)".
- **D97 (2026-10-21, set by spec-writer after the v0.2 review): Mounted
  material, explicit.** The node-health map lists every node explicitly;
  receiving bricks declare what they provide and the loader checks it
  against `prometheus`'s requirements; bricks' own footprints exclude
  mounted material. Now in: [formats.md](formats.md) "Companion material
  mounted into other nodes".
- **D98 (2026-10-21, owner approval, relayed by the lead session): The
  v0.2 master spec and access model are approved as written** (commit
  9f8ddc3), with the three consolidation choices (the web front's default
  port 8080; Prometheus' admin and lifecycle endpoints disabled, reloads
  through the node's `sudo` wrapper; the DO NOT TAMPER rule on Grafana's
  users and administrator password) and D97. The known gaps stay gaps.
  Now in: [versions/v0.2/master-spec.md](versions/v0.2/master-spec.md),
  [versions/v0.2/access-model.md](versions/v0.2/access-model.md).
- **D99 (2026-10-21, owner ruling, relayed by the coordinator; clears
  G1): The v0.2 build plan is approved** (v1, 65f701a). Now in:
  [versions/v0.2/build-plan.md](versions/v0.2/build-plan.md) header.
- **D100 (2026-10-21, owner ruling; resolves O72, amends D61): A brick
  version is released when its version's release gate passes.** A wave
  merging into `main` releases nothing; v0.2's changes keep folding into
  0.2.0 (and 0.1.0 for new bricks) until the v0.2 release gate. Now in:
  [formats.md](formats.md) "Versions and pins", master spec 6.5.
- **D101 (2026-10-21, owner ruling; resolves O73): Evidence keeps its v0.1
  text under `source`.** v0.1's free-text `where` (the file, view or
  output looked at) moves to a new required key `source`; `where` is the
  location from the fixed set. Now in: [formats.md](formats.md) "What a
  scenario must contain", master spec 6.3.
- **D102 (2026-10-21, owner ruling; resolves O74): `fit` reads image sizes
  from the engine.** Each image layer counted once; a missing image is
  refused with its build command; `fit` now needs the engine reachable.
  Now in: master spec 8, [platform.md](platform.md) "Resources and
  nerfing".
- **D103 (2026-10-21, owner ruling; resolves O75): The web front runs only
  with something to publish.** With no web interface in the topology the
  bastion publishes no second port and no tools password is handed over.
  Now in: master spec 7.6,
  [versions/v0.2/access-model.md](versions/v0.2/access-model.md) 3 and 12,
  [planes-and-access.md](planes-and-access.md) "Credentials and the way in".
- **D104 (2026-10-21, owner ruling; resolves O76): `grafana` ships
  reference dashboards and alert rules** in its `companion/` folder,
  copied by scenarios into their seed files, not mounted; the node-health
  view is its node-health dashboard; the v0.2 scenario has Grafana and
  leaves another need uncovered. Now in: master spec 7.4, 11.1, 14.
- **D105 (2026-10-21, owner ruling; resolves O77): The `laptop` playground
  is declared on the build host** at 2 CPU / 4G / 8G, figures recorded with
  machine and date; CPU contention is not tested. Now in: master spec 14.
- **D106 (2026-10-21, owner ruling on the plan's readings): Three build
  readings.** The scripts keep refusing a second network (D83); a brick
  the v0.2 scenario does not use is measured on the integration fixture's
  game; Prometheus' retention is read from a seed file, so a retention
  fault is a seed-file fault, fixable on a fixable node. Now in: master
  spec 6.3, 7.2, 14.
- **D107 (2026-10-21, owner direction, relayed by the wave driver): Brick
  options are a v0.5 topic; v0.2 stays as built.** The `postgres` brick
  will offer optional elements (PostGIS, TimescaleDB, pgBadger,
  replication modules...), each documented and added to a scenario when
  appropriate; v0.5 improves and extends the bricks. Design open: O79,
  O80. Now in: [versions/v0.5/README.md](versions/v0.5/README.md).
- **D108 (2026-10-21, owner ruling after the v0.2 wave 3 gate): The
  monitoring bricks are fixable only in v0.2**, a known limit: nothing
  passes a node's write policy to its container, so the report-only
  Grafana gap cannot arise. Report-only monitoring nodes are later work
  (proposed: v0.3). Now in: master spec 7, 7.4, 10, 16;
  [versions/v0.2/access-model.md](versions/v0.2/access-model.md) 6, 7,
  11, 12; [versions/v0.3/README.md](versions/v0.3/README.md).
