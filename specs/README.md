# Spec tree — index and status

The living specification of db_audit_gm, and the only expression of its
intent (D1). To resume cold: read this page, then
[open-questions.md](open-questions.md); look up decisions in
[decisions.md](decisions.md) by ID only.

Phase: **v0.1 released** on 2026-10-21 and merged into `main`
(3c852e1); its working record is archived in
[archive/v0.1/](archive/v0.1/README.md) (master spec approved under the
owner's delegation to the lead, D44). **v0.2 released** on 2026-10-22: built from its [build plan](archive/v0.2/build-plan.md) (D99) in four waves, release gate passed, G10 and G11 cleared (D109), release notes in [versions/v0.2/README.md](versions/v0.2/README.md); merged into `main` (eedaa0d); its working record is archived in [archive/v0.2/](archive/v0.2/README.md). **v0.3 released** on 2026-10-30 and merged into `main` (cba7be3); its working record is archived in [archive/v0.3/](archive/v0.3/README.md). Its drafting opened on 2026-10-22 on branch `v0.3-spec`: the owner's rulings D114–D146, every question answered and the [review list](archive/v0.3/review-list.md) accepted; **consolidated** the same day into the [v0.3 master spec](versions/v0.3/master-spec.md) and its [access model](versions/v0.3/access-model.md), then revised after the independent review (REJECT, all seven blocking issues fixed, D151) and the owner's answers (D147–D150); **spec approved** on 2026-10-22 with the re-review's corrections (D152–D155); the eight drafts kept as the working record until the archive; the [build plan](archive/v0.3/build-plan.md) **approved** on 2026-10-22 (D156), with the owner's ruling that only a scenario with scheduler nodes ages (D157, D158) and the VPS rule (D159); wave 1 started on 2026-10-23, with the owner's confirmation of three readings (D160–D162); built in four waves; **release gate passed** on 2026-10-30 on `v0.3-w4` (items 1 to 15, G9 and G10 cleared), release notes in [versions/v0.3/README.md](versions/v0.3/README.md#release-notes). **v0.4 released** on 2026-11-03: built from its [build plan](archive/v0.4/build-plan.md) (D216) in four waves, release gate passed on `v0.4-w4`, G11 cleared and the smoke run's end-of-run checks left a known limit (D313), its two-host runs, rehearsal, stance check-list and long-running tests moved to v1.0 gating (D311, D312), release notes in [versions/v0.4/README.md](versions/v0.4/README.md#release-notes); merged into `main`; its working record is archived in [archive/v0.4/](archive/v0.4/README.md). v0.5 consolidated on 2026-11-03 into its [master spec](versions/v0.5/master-spec.md) and [access model](versions/v0.5/access-model.md), **both approved** the same day with every review point as recommended (D339) and the monitoring breadth designed (D340, O220 closed), its build plan next; v0.6 and v1.0 in drafting. v0.4's history: recast on 2026-10-28 as purposes, "bricks of why and bits of hows" (D190), with a first cut of data governance (D191); business domains set for v0.5 the same day, the shop first, in v0.4 (D192). On 2026-10-29, after v0.3's release-gate aged run passed, aged runs made a one-off check, none planned before v1.0 (D193). On 2026-10-30 v0.4 was worked into draft documents: no other engine (D194), no mail sink (D195); the owner's veterinary clinic placed in v0.5 (D196); then the owner ruled: four purposes, one a pushed obligation (D197), the reporting database an instance of its own (D198), realistic cadences under real time (D199), the release gate's purpose cycle (D200); then the owner's technology direction: several PostgreSQL instances, data moved mainly by Python transformer scripts the scheduler runs, `postgres_fdw` one method among others (D202), `scheduler` 0.2.0 (D203), nodes sized by role (D204); and, after v1.0, a fictional cloud provider (D205); then jobs on a database node, `pg_cron` and a cron daemon in `postgres` 0.4.0, systemd timers later (D206); the placement guideline (D207); the first scenario given a crontab fault (D208) and a real out-of-memory incident (D209). On the owner's word that v0.4 was ready, its **master spec was drafted** the same day, [master-spec.md](versions/v0.4/master-spec.md) with its [access model](versions/v0.4/access-model.md): every draft proposal carried as written for review in context (its "Owner review" list, A1–A13), with the consolidation's corrections (B1–B15) and two new questions (O132, O133), which the owner ruled the same day: the agency's database report-only by the story alone, no brick policy (D211); the scenario's ten faults only (D212); f10 calibrated early on armenelos (D213); the gateway's lost acknowledgements (D214). The **master spec and access model were approved** the same day, every owner-review item as written, the list removed, closing O104, O108, O115–O117, O119, O122, O124, O125 and O111's v0.4 part (D215); its [build plan](archive/v0.4/build-plan.md) was drafted and **approved** the same day, κ = 3, with the owner's rulings on the judged moment before the hand-over and on f10's measurement without swap (D216–D218). Conventions:
settled items are stated as fact, tentative ones are tagged `(proposed)`,
and every open point cites an `O` ID. Every `(proposed)` item awaits the
owner's confirmation; the register lists the ones with real alternatives.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [concept.md](concept.md) | Purpose, actors, vocabulary, scope, versions, prior art | draft v16 |
| [versions/](versions/README.md) | The roadmap: v0.1 to v0.6, v1.0 and beyond, one page per version; v0.1's [master spec](versions/v0.1/master-spec.md), [access model](versions/v0.1/access-model.md) and [wave log](versions/v0.1/wave-log.md) | v0.1 released and archived; v0.2 released 2026-10-22 and archived: [master spec](versions/v0.2/master-spec.md), [access model](versions/v0.2/access-model.md), [wave log](versions/v0.2/wave-log.md), build plan archived; v0.3 released 2026-10-30 and archived (below); v0.4–v0.6 and v1.0 draft |
| [versions/v0.3/](versions/v0.3/README.md) | v0.3's page and release notes, [master spec](versions/v0.3/master-spec.md), [access model](versions/v0.3/access-model.md) and [wave log](versions/v0.3/wave-log.md) | released 2026-10-30, merged into `main` (cba7be3); spec approved 2026-10-22 (D154), amended by D157 and D158; built from the [build plan](archive/v0.3/build-plan.md) v15 (D156); release gate passed, items 1 to 15, G9 and G10 cleared; [release notes](versions/v0.3/README.md#release-notes); the build plan, the eight drafts and the review list archived in [archive/v0.3/](archive/v0.3/README.md); page draft v11 |
| [versions/v0.4/](versions/v0.4/README.md) | v0.4's page and release notes, [master spec](versions/v0.4/master-spec.md), [access model](versions/v0.4/access-model.md) and [wave log](versions/v0.4/wave-log.md); four drafts kept: [purpose catalogue](versions/v0.4/purpose-catalogue.md), [shop domain](versions/v0.4/shop-domain.md), [governance](versions/v0.4/governance.md), [candidate faults](versions/v0.4/candidate-faults.md) | released 2026-11-03, merged into `main` (56b7471); spec approved 2026-10-30 (D215), amended through the build (its status note); built from the [build plan](archive/v0.4/build-plan.md) v16 (D216); release gate passed 2026-11-03, G11 cleared, the smoke run's end-of-run checks a known limit (D313); the two-host runs, the rehearsal, the stance check-list and the long-running tests moved to [v1.0 gating](versions/README.md#v10-gating) (D311, D312); [release notes](versions/v0.4/README.md#release-notes); the build plan and four drafts archived in [archive/v0.4/](archive/v0.4/README.md); page v13 |
| [versions/v0.5/](versions/v0.5/README.md) | v0.5's page, centred on domain definition and the veterinary clinic (D233), with its sorting of the earlier scope; the approved [domain procedure](versions/v0.5/domain-procedure.md), the draft [brick options review](versions/v0.5/brick-options-review.md), the draft [producer profiles](versions/v0.5/producer-profiles.md) frictions, the ruled [third parties](versions/v0.5/third-parties.md) definition, [one centre per scenario](versions/v0.5/one-centre.md), [cold storage](versions/v0.5/cold-storage.md), [replication](versions/v0.5/replication.md), the [`vet-core`](versions/v0.5/vet-core-domain.md), [`vet-lab`](versions/v0.5/vet-lab-domain.md), [`vet-scheduling`](versions/v0.5/vet-scheduling-domain.md), [`vet-housing`](versions/v0.5/vet-housing-domain.md), [`vet-machinery`](versions/v0.5/vet-machinery-domain.md) and [`vet-portal`](versions/v0.5/vet-portal-domain.md) domains, their [purposes](versions/v0.5/clinic-purposes.md), [traps](versions/v0.5/clinic-traps.md), [test selection](versions/v0.5/clinic-test-selection.md) and [capacity](versions/v0.5/clinic-capacity.md), a scenario's [data register](versions/v0.5/data-register-handout.md) | master spec approved (D339); the scope review's recommendations accepted (D248–D251, O137 closed); procedure approved, v4 (D249, D260, O139 closed; scale, variants and tags D263, O114 closed); producer-profile frictions ruled (D264–D271, D276, D277, D287, D288, D298; O113 closed); `vet-core`'s sketch and the clinic's split ruled (D278, D279; O144 closed), its data model current, its governance ruled (D280); one centre per scenario (D285, O127 closed), its parts, the lab's billing and `vet-core`'s rescale (D293–D295, O147 closed); round trips a purpose kind (D286, O128 closed); cold storage ruled (D296, D297, O148 closed); [replication](versions/v0.5/replication.md) ruled (D299), the reports writing to a back-office database (D300, O149 closed); `vet-lab`'s sketch ruled, the lab on a node of its own (D301, O151 closed), its data model and governance ruled (D302, O152 closed); `vet-core`'s and `vet-lab`'s producer profiles ruled (D304, O153 closed), with what they need of the scheduler and the format (D303, O154 closed); their [purposes](versions/v0.5/clinic-purposes.md) (step 7) drafted, for the owner (O155, O156); options review v4, ruled (D250; D261, pgaudit always available, O118 closed; D262, options for `postgres` only, O80 closed; D289, the options model, O79 closed); the clinic's fault budget (D290, O23 narrowed); the format finalised at consolidation (D291); v0.5 clinic-only (D292, O112 closed); post-mortem collection begun (D234, D251; O138); the four remaining parts drafted and ruled (D317–D321, O168–O215 closed), composing domains (procedure 10, D322, D323, confirmed by D326), the fold-in's overlaps and test picks (D324, D325, D327, D328); no data register for the repository, no data preflight (D329); a scenario's data register a generated player handout that may carry a fault, by a GM sub-skill (D330, D331), s6 the register's T307 (D332), its questions answered as recommended: *propose*, the format additions with O111's, a register for every scenario listing `domains:` (D333–D336; O217–O219 closed); **consolidated** 2026-11-03 into the [master spec](versions/v0.5/master-spec.md) and [access model](versions/v0.5/access-model.md), O111 closed by formats.md v28 (D338); **both approved** the same day, R1–R20 as recommended, the six domain documents with them and corrected to the spec (D339), the monitoring breadth a `pgwatch` brick, pgCluu in `postgres` and a `health-check` node (D340, O220 raised at consolidation and closed) |
| [gm-stance.md](gm-stance.md) | How the GM behaves and speaks: setup questions, issues, report-only interaction, no reveals, stop only, restarts, no events outside the schedule, final answer, feedback tone, future ideas | draft v13 |
| [scenario-lifecycle.md](scenario-lifecycle.md) | The game from setup to teardown: setup inputs, scenario, local implementation, deploy, aging (real time from v0.3), hand-over, end of the game | draft v13 |
| [formats.md](formats.md) | What a scenario folder, a brick (with its companion material and GM documentation) and a fault definition must contain; versions and pins; the local implementation; the skills and templates; where a job runs (D207); from v0.4, the purpose, the domain, governance and the new fields; a test-only brick change bumps nothing (D229); an outbound flow's `fields` are its outbox's payload keys (D231); `separation: instance` refused with `locations: any` (D253); a `state` fault's `seed_changes` (D254); from v0.5, the domain format, composing domains, the data register and the purpose format's extensions (D338, closing O111) | draft v28 |
| [bricks-and-faults.md](bricks-and-faults.md) | Catalog, v0.2's monitoring bricks, per-brick checks, proportionate tooling, solvability probe, fault interactions and families, difficulty, future backup-tooling faults | draft v10 |
| [planes-and-access.md](planes-and-access.md) | Bastion-only rule (the bastion publishes the web interfaces), planes, the GM session, trust, write policies, the scheduler nodes, the customer's data policy kept apart from the game's access, hardening, validators | draft v18 |
| [platform.md](platform.md) | Hosting, resources and nerfing, scenario content delivery, portability, Swarm facts and pitfalls, the shared VPS | draft v19 |
| [open-questions.md](open-questions.md) | Open-questions register | live |
| [decisions.md](decisions.md) | Decisions log: D107, D113 and D190 onward live (v0.5's are D233–D238, D248–D251, D260–D262, D263–D280, D285–D309 and D314–D340; D340 last, D337 and D341 never used, D281–D284 issued on v0.4's wave 4 branch; take the next number from `doc-ids`); D1–D54 archived with v0.1, D55–D106 with v0.2, D108–D112 and D114–D189 with v0.3 | live |
| [archive/](archive/README.md) | Closed milestones' working records, kept verbatim: v0.1's, v0.2's and v0.3's build plans, v0.3's drafts and review list, decisions D1–D54, D55–D106, D108–D112 and D114–D189, resolved questions | archive |

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
  v0.4 purposes (side usage and transformations, recast by D190) with a
  first cut of data governance (D191) and the shop as the first business
  domain, v0.5 domain definition with the veterinary clinic as its
  worked example (D192, D233), v0.6 the bastion as the players' main
  activity point, with the setup's entry point (D233), then v1.0; beyond v1.0,
  other databases and tools, customer role-play and hints (D48), a
  fictional cloud provider with capacity management and a console (D205;
  O130). Gaps and
  risks: O48, O49, O52–O54 (O46 resolved by D128, O121 by D200, O47 by
  D248). Brick options are a v0.5
  topic, for `postgres` only unless a clinic part calls for another
  brick; v0.2 stays as built (D107, D262; O79).
- Release gates (D193, 2026-10-29): an aged run, a full aging to the
  hand-over then a play-through, is a one-off check, not a standing
  gate item; v0.3's gate ran one and it passed, none is planned before
  v1.0, and v1.0's gate decides its own. Later gates rely on the smoke
  tests, the rehearsal and the timer-fired early check; v0.4's adds
  every purpose fault's full cycle in a smoke run and names what no gate
  shows as known limits (D200; [versions/](versions/README.md#release-gates)).
  On 2026-11-03 v0.4's two-host runs, rehearsal and stance check-list
  became v1.0 gating, run once before the v1.0 tag, with no full-game
  testing until then (D311), then its long-running tests (D312) and its
  smoke run's unreached end-of-run checks (D313;
  [v1.0 gating](versions/README.md#v10-gating)). v0.4 released on
  2026-11-03.
- v0.2, ruled on 2026-10-21 (D63–D70): the owner's `bluebox-lab` is the
  reference and per-node health the gap; free tools, one brick per need,
  chosen by footprint; monitoring optional and tooling proportionate, with
  under-tooling or overkill a finding but no fault kind; a health daemon
  script on every node, no Docker socket; Prometheus, `postgres_exporter`,
  Grafana with its alerting, PostgreSQL file logs read by pgBadger, no log
  aggregator; no load; the bastion publishes the web interfaces. Other
  tools and hand-made scripts in v0.5 (D70), as far as the clinic's
  setting needs them: pgwatch, pgCluu and Nagios-style health tools
  (D238); the rest sorted by D233.
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
  scenario and six to eight faults (D134); a full aged run at v0.3's
  release gate (D135; v0.3's only, D193); seed, driver, `max_connections` (D136–D138); no PgBouncer
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
  (D169); the scheduler's writable paths as directories (D170); the
  GM check role's own DO NOT TAMPER seed line, the owner's ruling on
  O102 (D171). Waves 2 to 4 ruled D172–D189 (O103 by D175); the release
  gate passed on 2026-10-30 and v0.3 was merged into `main` (cba7be3);
  its working record is archived in [archive/v0.3/](archive/v0.3/README.md).
- v0.5, centred on 2026-10-31 (D233–D238): domain definition, the
  veterinary clinic franchise its worked example; tools unrelated to it
  later ("probably v1.0+"), bastion-related items to v0.6; a
  [procedure](versions/v0.5/domain-procedure.md) for defining a domain,
  other domains deferred until its cost is known (D235; O112); brick
  options kept and reviewed against the clinic (D236); Bluebox and other
  datasets later, version not set (D237); pgwatch, pgCluu and monitoring
  breadth kept (D238); a post-mortem collection in `post_mortem/`, not
  bound to faults yet (D234). The owner then accepted every
  recommendation of the review the same day (D248–D251): the sorting as
  proposed, a clinic scenario in v0.5, scenario generation in v1.0
  (O137 and O47 closed); the clinic's seven-domain cut, the composition
  rules (O126 closed), the four format changes in one chunk, a skill
  after two or three domains; plain partitioned tables before
  TimescaleDB, replication a standby mode of the brick, TLS always
  available, only the `monitoring` role an option; the post-mortem
  handout after the final answer, summarising and linking its source.
  Then (D260–D262): the domain procedure approved as drafted (O139
  closed); pgaudit always available in `postgres`, as TLS is (O118
  closed), which leaves the options model to the `monitoring` role
  (O79); options for `postgres` only unless a clinic part calls for
  another brick (O80 closed). Still open: O79, O138. On 2026-11-01
  "size" became scale on three axes, with variants and tags, one
  variant per domain in v0.5 (D263, O114 closed); the producer-profile
  frictions were drafted (O113) and partly ruled: a `gmctl compose`
  merge script (D264), weekly, monthly and yearly reports with planted
  past periods (D265), the core the system of record with natural
  identifiers (D266), an `api` brick on FastAPI and an HTTP driver
  (D267), the external lab's round trip over APIs (D268, O128
  narrowed); then no report run on demand in v0.5 (D269), an `api` node
  only answering (D270), players editing only its database side
  (D271), and v1.0 to v2 leaning to DBA work with bits of devops
  (D272); a third party's nodes put out of the players' reach (D273),
  what a third party is ruled (D274, D275, O145 closed); O113's remaining
  points ruled (D276, D277); `vet-core`'s business sketch ruled (D278,
  O144 closed), the clinic's split confirmed with the history's growth
  (D279), `vet-core`'s data model current and its classification and
  governance ruled (D280). On 2026-11-02 the owner ruled one centre per
  scenario, the other centres and the franchise's systems third parties
  (D285, O127 closed), round trips a purpose kind with cascades judged
  end to end (D286, O128 closed), the housing displays behind a ward
  service (D287), heavy data kept a day on site and shipped to cold
  storage (D288), the options model (D289, O79 closed), the clinic's
  ten-fault budget with false alarms allowed (D290, O23 narrowed), the
  domain format finalised at consolidation (D291) and v0.5 clinic-only
  (D292, O112 closed); then one centre's parts, the portal the
  centre's and messaging the franchise's, the lab billing its outside
  customers, `vet-core` at a third of its first scale (D293–D295, O147
  closed), cold storage's design, the GM deciding what ships, use first
  (D296, D297, O148 closed), and friction 11's profile (D298, O113
  closed); then replication and the off-site copies (D299), and the
  reports' outputs in a back-office database, `office` (D300, O149
  closed); `vet-lab`'s business sketch ruled, every default accepted,
  the lab on a node of its own (D301, O151 closed), its data model and
  default policy ruled as drafted (D302, O152 closed); `vet-core`'s and
  `vet-lab`'s producer profiles ruled as drafted (D304, O153 closed),
  with what they need of the scheduler and the format (D303, O154
  closed); their ten purposes ruled as drafted (D306, O155 closed), with
  the purpose format's extensions (D307, O156 closed); the partners'
  stubs grouped on one `api` node (D308); fault selection the GM's at
  deploy, step 8 listing traps only (D309). On 2026-11-03: short tests
  only in v0.5, on a minimal environment, the whole clinic deployed once
  on two hosts the one exception, the rest to the major test before the
  v1.0 tag (D314, O158 closed). `vet-core` and `vet-lab` are through
  step 8 (84 traps, a test selection of ten, the node tally) and in step
  9's draft, ready for review; a sent request cancelled by the lab only
  (D315, O164 closed); v0.5 building the test selection's ten faults
  (D316, O165 closed). The same day the four remaining parts
  ([`vet-scheduling`](versions/v0.5/vet-scheduling-domain.md),
  [`vet-housing`](versions/v0.5/vet-housing-domain.md),
  [`vet-machinery`](versions/v0.5/vet-machinery-domain.md),
  [`vet-portal`](versions/v0.5/vet-portal-domain.md)) were drafted in
  parallel through step 9 and folded in, the owner accepting their
  recommendations as a whole (D317–D320, O168–O215 closed); no
  appointment reminders in v0.5 (D321); the initial load adjudicated by
  the GM for the whole system, D249's computed keys the default (D322,
  [procedure](versions/v0.5/domain-procedure.md#10-composing-domains-d322)
  10), the parts' format changes for O111 (D323), both confirmed as
  written (D326, O111 settled in substance, carried by the master
  spec); the overlaps settled (D324), the domestic vets eight so the
  imaging staff fit the 85 (D327), and the test selection's s5 and s9
  swapped for T270 and T150 (D325), no fault of the ten on an `api`
  node's `db/` side, the brick's own build checks covering it (D328).
  Steps 1 to 9 done for all six domains. Then the repository keeps no
  data register and v0.5 runs no data preflight, all data synthetic
  (D329); a scenario's data register is a player handout generated from
  the ground truth, which may carry a fault, T300–T308 (D330), by a GM
  sub-skill, `data-register` (D331,
  [data-register-handout.md](versions/v0.5/data-register-handout.md));
  the test selection's s6 is T307, the vault not declared (D332). The
  owner accepted the register's recommendations: a register fault
  resolved by *propose* (D333, O217 closed), its format additions into
  the master spec with O111's (D334, O218 closed), a register for every
  scenario listing `domains:`, v0.4's shop exempt until revised (D335,
  O219 closed), the page's other details as written (D336).
  Consolidated on the owner's word into the master spec and access
  model, O111 closed (D338), and **approved** the same day ("agreed"):
  the review's R1–R3 and R5–R20 as recommended, the domain documents
  corrected to the spec (D339); the monitoring breadth, R4, a `pgwatch`
  brick on its Prometheus sink, pgCluu in `postgres`, a `health-check`
  node, 25 nodes and 4.05 CPU in all (D340, O220 closed).
- Small project: scripts and small apps, no ATD, no UI/UX tree (D2).
- v0.1 build: seven artifacts (three skills, a Python/POSIX-shell script
  set, PostgreSQL 18 on Debian 13 and bastion bricks, one scenario), one
  host, four expected resolutions (report, propose, fix, improve), players
  as `player` with a `dba` superuser role, testable stance check-list
  (D9, D33–D41); full detail in the
  [v0.1 master spec](versions/v0.1/master-spec.md).

## Next steps

1. v0.5, the domain procedure approved (D260), the clinic only (D292):
   all six domains drafted through step 9 and ruled (D317–D328), the
   composition mechanism and format text confirmed (D326);
   consolidated on 2026-11-03 into the
   [master spec](versions/v0.5/master-spec.md) and its
   [access model](versions/v0.5/access-model.md), O111 closed by
   formats.md v28 (D338), and approved the same day (D339, D340, O220
   closed); next, the build plan, with no data preflight (D329) and the
   monitoring breadth's dependency check a gate
   ([v0.5 next steps](versions/v0.5/README.md#next-steps)).
2. The roadmap's "soon" question, O49 (backup tooling's version), then
   v1.0's from the "later" ones.
