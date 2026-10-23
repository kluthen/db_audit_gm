# Spec tree — index and status

The living specification of db_audit_gm, and the only expression of its
intent (D1). To resume cold: read this page, then
[open-questions.md](open-questions.md); look up decisions in
[decisions.md](decisions.md) by ID only.

Phase: **v0.1 released** on 2026-10-21 and merged into `main`
(3c852e1); its working record is archived in
[archive/v0.1/](archive/v0.1/README.md) (master spec approved under the
owner's delegation to the lead, D44). **v0.2 released** on 2026-10-22: built from its [build plan](archive/v0.2/build-plan.md) (D99) in four waves, release gate passed, G10 and G11 cleared (D109), release notes in [versions/v0.2/README.md](versions/v0.2/README.md); merging into `main` on the owner's word; its working record is archived in [archive/v0.2/](archive/v0.2/README.md). **v0.3's drafting opened** on 2026-10-22 on branch `v0.3-spec`: the owner's rulings D114–D146, every question answered and the [review list](versions/v0.3/review-list.md) accepted; **consolidated** the same day into the [v0.3 master spec](versions/v0.3/master-spec.md) and its [access model](versions/v0.3/access-model.md), then revised after the independent review (REJECT, all seven blocking issues fixed, D151) and the owner's answers (D147–D150); **spec approved** on 2026-10-22 with the re-review's corrections (D152–D155); the eight drafts kept as the working record, stale by design where the master spec supersedes them; the [build plan](versions/v0.3/build-plan.md) **approved** on 2026-10-22 (D156), with the owner's ruling that only a scenario with scheduler nodes ages (D157, D158) and the VPS rule (D159); wave 1 started on 2026-10-23, with the owner's confirmation of three readings (D160–D162). v0.4 to v0.6 and v1.0 in drafting. Conventions:
settled items are stated as fact, tentative ones are tagged `(proposed)`,
and every open point cites an `O` ID. Every `(proposed)` item awaits the
owner's confirmation; the register lists the ones with real alternatives.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [concept.md](concept.md) | Purpose, actors, vocabulary, scope, versions, prior art | draft v12 |
| [versions/](versions/README.md) | The roadmap: v0.1 to v0.6, v1.0 and beyond, one page per version; v0.1's [master spec](versions/v0.1/master-spec.md), [access model](versions/v0.1/access-model.md) and [wave log](versions/v0.1/wave-log.md) | v0.1 released and archived; v0.2 released 2026-10-22 and archived: [master spec](versions/v0.2/master-spec.md), [access model](versions/v0.2/access-model.md), [wave log](versions/v0.2/wave-log.md), build plan archived; v0.3 drafting (below); v0.4–v0.6 and v1.0 draft |
| [versions/v0.3/](versions/v0.3/README.md) | v0.3's drafts: [scheduler](versions/v0.3/scheduler.md), [aging and timeline](versions/v0.3/aging-and-timeline.md), [load and capacity](versions/v0.3/load-and-capacity.md), [faults with activity](versions/v0.3/faults-with-activity.md), [checks under load](versions/v0.3/checks-under-load.md), [PgBouncer](versions/v0.3/pgbouncer.md), [carried items](versions/v0.3/carried-items.md), [format changes](versions/v0.3/format-changes.md); [master spec](versions/v0.3/master-spec.md), [access model](versions/v0.3/access-model.md) | spec approved 2026-10-22 (D154), amended by D157 and D158; [build plan](versions/v0.3/build-plan.md) v4, approved 2026-10-22 (D156), confirmations D160–D162 and wave 1's preflight corrections D163–D170 written in, wave 1 under way; page draft v8 |
| [gm-stance.md](gm-stance.md) | How the GM behaves and speaks: setup questions, issues, report-only interaction, no reveals, stop only, restarts, no events outside the schedule, final answer, feedback tone, future ideas | draft v12 |
| [scenario-lifecycle.md](scenario-lifecycle.md) | The game from setup to teardown: setup inputs, scenario, local implementation, deploy, aging (real time from v0.3), hand-over, end of the game | draft v13 |
| [formats.md](formats.md) | What a scenario folder, a brick (with its companion material and GM documentation) and a fault definition must contain; versions and pins; the local implementation; the skills and templates | draft v20 |
| [bricks-and-faults.md](bricks-and-faults.md) | Catalog, v0.2's monitoring bricks, per-brick checks, proportionate tooling, solvability probe, fault interactions and families, difficulty, future backup-tooling faults | draft v9 |
| [planes-and-access.md](planes-and-access.md) | Bastion-only rule (the bastion publishes the web interfaces), planes, the GM session, trust, write policies, the scheduler nodes, hardening, validators | draft v15 |
| [platform.md](platform.md) | Hosting, resources and nerfing, scenario content delivery, portability, Swarm facts and pitfalls, the shared VPS | draft v17 |
| [open-questions.md](open-questions.md) | Open-questions register | live |
| [decisions.md](decisions.md) | Decisions log, D107 onward (D170 last); D1–D54 archived with v0.1, D55–D106 with v0.2 | live |
| [archive/](archive/README.md) | Closed milestones' working records, kept verbatim: v0.1's and v0.2's build plans, decisions D1–D54 and D55–D106, resolved questions | archive |

History: the tree was seeded on 2026-10-20 from the owner's pre-spec notes,
which are no longer a reference (D1).

Tree shape (D3): actors are a section of [concept.md](concept.md)
("Actors") rather than a personas document, since there is no interface
to design; who reaches what is a game mechanic, stated in
[planes-and-access.md](planes-and-access.md), which feeds each version's
access model.

## Status snapshot — what is settled

- Purpose: live audit-and-fix practice on a complex data stack; an
  exercise, not a CTF; players are expected to follow the rules.
- The GM is an agent in a Claude Code or opencode session. The teacher only
  gives inputs at the start; anyone may ask the GM to stop the game; a
  student may play alone with the GM designing the exercise (D6).
- GM stance: no reveals before the final answer; no action on request but
  stopping; issues carry an expected resolution (report, fix, improve); an
  explicit final answer; positive teacher-style feedback (D9, D13;
  [gm-stance.md](gm-stance.md)).
- One game, one report; who sits behind it is not the project's concern
  (D8).
- v0.1 settles the GM stance on one simple scenario: a static PostgreSQL
  database investigated for defects in itself and its configuration; no
  load producer, no monitoring; the report is the players' only interaction
  with the GM; no hints, resets or extra time (D4, D14, D15, D17–D19).
  v1.0: producer -> database -> transformation -> database -> consumer,
  with monitoring and the bastion (D4).
- Swarm is the starting platform; Kubernetes portability is a requirement;
  multi-host swarms use Linux hosts only. The GM uses an existing swarm or
  sets one up (or guides the user), and reaches hosts over SSH (D12, D22,
  D26, D27).
- The only required setup input is the playground: the swarm, its hosts and
  the capacity available (CPU, RAM, disk). Topology, story, data schema and
  the like are optional and may be sketched or left out; the GM fills the
  blanks and sizes the setup to fit (D7, D16).
- Scenario content: generic brick images, scenario files as Swarm configs
  seeded once into pinned volumes, state faults planted by the GM (D11).
- Scenario format, brick and fault definitions are specified in
  [formats.md](formats.md) and will be enforced by one skill plus templates
  (D5). A scenario is a self-sufficient folder, the source of truth: with
  the full repository and the GM's skills it is enough to start the
  exercise, and it records the host
  topology it was designed for. Its readable scenario document follows the
  GM's own template and carries a prominent "do not read" warning, nothing
  heavier (D13, D20, D23). To deploy, the GM generates a local
  implementation fitting the scenario to the real playground, or says the
  capacity is insufficient (D23). Initial versions of the skills and
  templates are in v0.1 and expected to evolve (D21). From v0.2 every
  brick's GM documentation has required sections, placement and wiring
  among them, and the format skill refuses a brick without them (D56).
- Versions: any change to a brick bumps its version, documentation
  included (`postgres` and `bastion` are at 0.1.1, released; their v0.2
  changes take 0.2.0, new bricks start at 0.1.0); faults and scenarios
  never bump; a fault's `applies_to` alone says which faults a brick
  hosts, listing versions one by one, catalog faults only in its GM
  documentation; changes to an unreleased brick version fold into it
  (D57–D62, D72, D75, D86).
- Players reach everything through the bastion only; read access to every
  node, write access on some; limited `sudo` wrappers, so no
  `no-new-privileges` where they are needed (D25).
- Shared bricks and faults live in the catalog, referenced by id and pinned
  version; scenario-only ones may live in the scenario folder (D24).
  Machine checks are per brick, shipped as companion material (D28).
- Validators may be red from the start; they are not monitoring tools; an
  unfixable red validator is a defect to report (D10).
- Every scenario fits the playground's CPU, memory and disk; databases are
  nerfed;
  schemas simple, tables small; sessions up to 4 hours.
- Roadmap (D47, D71): v0.2 monitoring, v0.3 producers and consumers,
  v0.4 transformers, v0.5 research and broadening, v0.6 the bastion as
  the players' main activity point, then v1.0; beyond v1.0,
  other databases and tools, customer role-play and hints (D48). Gaps and
  risks: O47–O49, O52–O54 (O46 resolved by D128). Brick options, `postgres` first, are a v0.5
  topic; v0.2 stays as built (D107; O79, O80).
- v0.2, ruled on 2026-10-21 (D63–D70): the owner's `bluebox-lab` is the
  reference and per-node health the gap; free tools, one brick per need,
  chosen by footprint; monitoring optional and tooling proportionate, with
  under-tooling or overkill a finding but no fault kind; a health daemon
  script on every node, no Docker socket; Prometheus, `postgres_exporter`,
  Grafana with its alerting, PostgreSQL file logs read by pgBadger, no log
  aggregator; no load; the bastion publishes the web interfaces. Other
  tools and hand-made scripts in v0.5 (D70).
- v0.2, ruled on the draft v2 (D72–D87): the node-health script and its
  s6 service mounted into each node as configs at deploy, on every node
  when there is a metrics store; every new brick a full node of its own;
  a web front on the bastion, with one per-game tools password; one new
  partly tooled scenario and `bookshop-new-server` re-pinned; four to six
  monitoring faults; tooling expectations as an answer-key list; evidence
  says where, all times UTC; one host and one network, no aging; a
  measured footprint in the definition of done. The node-health script
  is companion material of `prometheus`, versioned with it, which the GM
  mounts into the other nodes (D88, D89); no shared base image (D90).
  After the independent review (OKAY): Prometheus and Grafana on
  separate nodes, node-health faults on the `prometheus` node planted
  through a parameter, no default-password fault, Grafana's write policy
  a known gap, players running pgBadger, per-node disk, the node-health
  map explicit (D91–D97). The master spec and access model are approved
  (D98), and so is the [build plan](archive/v0.2/build-plan.md) (D99).
  The owner's rulings on the plan amend the spec: a brick version is
  released by its version's release gate, not by a wave's merge (D100);
  v0.1's evidence text moves to `source` (D101); `fit` reads image sizes
  from the engine (D102); no web front or tools password without a web
  interface (D103); `grafana` ships reference dashboards, the node-health
  view among them (D104); the `laptop` playground is declared on the
  build host (D105); one network enforced, unused bricks measured on the
  integration fixture, Prometheus' retention in a seed file (D106).
  After wave 3: the monitoring bricks are fixable only in v0.2, a known
  limit; report-only monitoring nodes proposed for v0.3 (D108).
- v0.2 release close (2026-10-22): the tooling and the feedback judged
  good (D109); a game restart, the whole stack rebuilt, allowed from
  v0.3 on the players' explicit confirmation only, v0.2 keeping no
  restarts (D110; O81); `bookshop-new-server`'s seed brought to
  `postgres` 0.2.0's logging requirement (D111); RG-2 and RG-3 accepted
  as known issues (D112); the `monitoring` role in every postgres game
  until v0.5 makes it conditional (D113).
- v0.3, ruled on 2026-10-22 as its drafting opened: aging in real time,
  no sped-up clock or forged history (D114; its two days amended to an
  eight-hour floor by D150, below); producers and consumers as scheduler nodes running a
  GM-written query repository, players reading it and editing it where
  the scenario allows, reading and moving only the fixed-time operations
  (D115, D116); no events outside the schedule (D117); SQL against
  PostgreSQL, other targets from v0.5 (D118); an optional PgBouncer brick
  (D119); difficulty a fault count, 5/10/20, scoring post-v1.0 (D120);
  `ALTER SYSTEM` on report-only databases on the trust line (D121, closes
  O45); capacity discussed with the initiator, Swarm the platform,
  Tailscale between armenelos and the VPS (D122); a restart rebuilds the
  game from scratch (D123). The owner's answers to O82–O97 (D124–D140):
  checks judge the cause first, a window otherwise, never pause the load
  (D124); always-on hosts (D125); a hand-over snapshot for restarts
  (D126); timeline changes during aging only (D127); multi-host in v0.3
  (D128); the schedule shifted by whole hours (D129); scheduler log
  visible, write policy per file (D130); nobody touches the load (D131);
  no time compression (D132); repository semantics (D133); one new normal
  scenario and six to eight faults (D134); a full aged run at the release
  gate (D135); seed, driver, `max_connections` (D136–D138); no PgBouncer
  metrics brick (D139); every carried item (D140). And on O81, O98–O101:
  any player confirms a restart once the GM has stated what is lost
  (D141); the snapshot taken online per brick (D142); `write_overrides`
  (D143); a GM connection reserve (D144); a fault's evidence locations
  (D145). The review list's 46 items accepted as proposed, v0.5 to adjust
  them after use (D146); the master spec and access model consolidated.
  After the independent review: Prometheus snapshotted by a brief stop,
  its admin API off (D147); a fixable builder's schedule leak on the
  trust line (D148); images copied between hosts, no registry (D149);
  the aging minimum an eight-hour floor, each scenario declaring its own
  and the GM judging feasibility per game, amending D114's two days
  (D150); the review applied, the open choices proposed (D151). Lost
  time up to thirty minutes does not move the earliest hand-over (D152);
  the second round of the review list accepted (D153); the master spec
  and access model approved with the re-review's corrections (D154,
  D155). The build plan approved with its nine recommendations (D156);
  only a scenario with scheduler nodes ages, a static one omitting
  `aging:`, amending D150 (D157, D158); the VPS shared, filetstudio.com
  never disturbed (D159). At wave 1's start: a static scenario's faults'
  own aging minima not counted (D160); the harness override capping each
  instance's minimum (D161); static games keep the hand-over check and
  the snapshot, brief stops included (D162). Wave 1's preflight on
  capture W1: `schedule.yaml` read in place (D163); the replication line
  in every `postgres` seed (D164); chunk 9 passes windows (D165); chunk
  1 first, 2, 4, 5 after its merge (D166); chunk 1 writes W1's brick
  values (D167); `timezone_offset` (D168); `check-psql` in chunk 4
  (D169); the scheduler's writable paths as directories (D170).
- Small project: scripts and small apps, no ATD, no UI/UX tree (D2).
- v0.1 build: seven artifacts (three skills, a Python/POSIX-shell script
  set, PostgreSQL 18 on Debian 13 and bastion bricks, one scenario), one
  host, four expected resolutions (report, propose, fix, improve), players
  as `player` with a `dba` superuser role, testable stance check-list
  (D9, D33–D41); full detail in the
  [v0.1 master spec](versions/v0.1/master-spec.md).

## Next steps

1. v0.3: wave 1 of the [build plan](versions/v0.3/build-plan.md), under
   way since 2026-10-23; the owner's answer to O102 (the GM check
   role's own DO NOT TAMPER line), best before chunk 1b; the plan's
   remaining owner gates (G7, G8's date, G9 and G10) as their waves
   reach them.
2. The other "soon" question, O49 (backup tooling's version), then
   v1.0's from the "later" ones.
