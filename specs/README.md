# Spec tree — index and status

The living specification of db_audit_gm, and the only expression of its
intent (D1). To resume cold: read this page, then
[open-questions.md](open-questions.md); look up decisions in
[decisions.md](decisions.md) by ID only.

Phase: **v0.1 released** on 2026-10-21 and merged into `main`
(3c852e1); its working record is archived in
[archive/v0.1/](archive/v0.1/README.md) (master spec approved under the
owner's delegation to the lead, D44). **v0.2 released** on 2026-10-22: built from its [build plan](archive/v0.2/build-plan.md) (D99) in four waves, release gate passed, G10 and G11 cleared (D109), release notes in [versions/v0.2/README.md](versions/v0.2/README.md); merged into `main` (eedaa0d); its working record is archived in [archive/v0.2/](archive/v0.2/README.md). **v0.3 released** on 2026-10-30 and merged into `main` (cba7be3); its working record is archived in [archive/v0.3/](archive/v0.3/README.md). Its drafting opened on 2026-10-22 on branch `v0.3-spec`: the owner's rulings D114–D146, every question answered and the [review list](archive/v0.3/review-list.md) accepted; **consolidated** the same day into the [v0.3 master spec](versions/v0.3/master-spec.md) and its [access model](versions/v0.3/access-model.md), then revised after the independent review (REJECT, all seven blocking issues fixed, D151) and the owner's answers (D147–D150); **spec approved** on 2026-10-22 with the re-review's corrections (D152–D155); the eight drafts kept as the working record until the archive; the [build plan](archive/v0.3/build-plan.md) **approved** on 2026-10-22 (D156), with the owner's ruling that only a scenario with scheduler nodes ages (D157, D158) and the VPS rule (D159); wave 1 started on 2026-10-23, with the owner's confirmation of three readings (D160–D162); built in four waves; **release gate passed** on 2026-10-30 on `v0.3-w4` (items 1 to 15, G9 and G10 cleared), release notes in [versions/v0.3/README.md](versions/v0.3/README.md#release-notes). **v0.4 released** on 2026-11-03: built from its [build plan](archive/v0.4/build-plan.md) (D216) in four waves, release gate passed on `v0.4-w4`, G11 cleared and the smoke run's end-of-run checks left a known limit (D313), its two-host runs, rehearsal, stance check-list and long-running tests moved to v1.0 gating (D311, D312), release notes in [versions/v0.4/README.md](versions/v0.4/README.md#release-notes); merged into `main`; its working record is archived in [archive/v0.4/](archive/v0.4/README.md). **v0.5 released** on 2026-11-14: its [master spec](versions/v0.5/master-spec.md) and [access model](versions/v0.5/access-model.md) approved on 2026-11-03 (D339, D340); built from its [build plan](archive/v0.5/build-plan.md) (D342) in five waves and 38 chunks, short tests only (D314); release gate passed on 2026-11-13, the whole clinic deployed once on armenelos plus the VPS (G13), G15 cleared by the owner (D475), G13's findings 1 and 4 known limits (D476, O269, O270), release notes in [versions/v0.5/README.md](versions/v0.5/README.md#release-notes); merged into `main` (`a56e5ac`); its build plan, decisions and resolved questions are archived in [archive/v0.5/](archive/v0.5/README.md). v0.6, v0.7 (opened 2026-11-19, D549) and v1.0 in drafting. v0.4's history: recast on 2026-10-28 as purposes, "bricks of why and bits of hows" (D190), with a first cut of data governance (D191); business domains set for v0.5 the same day, the shop first, in v0.4 (D192). On 2026-10-29, after v0.3's release-gate aged run passed, aged runs made a one-off check, none planned before v1.0 (D193). On 2026-10-30 v0.4 was worked into draft documents: no other engine (D194), no mail sink (D195); the owner's veterinary clinic placed in v0.5 (D196); then the owner ruled: four purposes, one a pushed obligation (D197), the reporting database an instance of its own (D198), realistic cadences under real time (D199), the release gate's purpose cycle (D200); then the owner's technology direction: several PostgreSQL instances, data moved mainly by Python transformer scripts the scheduler runs, `postgres_fdw` one method among others (D202), `scheduler` 0.2.0 (D203), nodes sized by role (D204); and, after v1.0, a fictional cloud provider (D205); then jobs on a database node, `pg_cron` and a cron daemon in `postgres` 0.4.0, systemd timers later (D206); the placement guideline (D207); the first scenario given a crontab fault (D208) and a real out-of-memory incident (D209). On the owner's word that v0.4 was ready, its **master spec was drafted** the same day, [master-spec.md](versions/v0.4/master-spec.md) with its [access model](versions/v0.4/access-model.md): every draft proposal carried as written for review in context (its "Owner review" list, A1–A13), with the consolidation's corrections (B1–B15) and two new questions (O132, O133), which the owner ruled the same day: the agency's database report-only by the story alone, no brick policy (D211); the scenario's ten faults only (D212); f10 calibrated early on armenelos (D213); the gateway's lost acknowledgements (D214). The **master spec and access model were approved** the same day, every owner-review item as written, the list removed, closing O104, O108, O115–O117, O119, O122, O124, O125 and O111's v0.4 part (D215); its [build plan](archive/v0.4/build-plan.md) was drafted and **approved** the same day, κ = 3, with the owner's rulings on the judged moment before the hand-over and on f10's measurement without swap (D216–D218). Conventions:
settled items are stated as fact, tentative ones are tagged `(proposed)`,
and every open point cites an `O` ID. Every `(proposed)` item awaits the
owner's confirmation; the register lists the ones with real alternatives.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [concept.md](concept.md) | Purpose, actors, vocabulary, scope, versions, prior art | draft v17 (v0.7: the game assistant among the actors) |
| [versions/](versions/README.md) | The roadmap: v0.1 to v0.7, v1.0 and beyond, one page per version; v0.1's [master spec](versions/v0.1/master-spec.md), [access model](versions/v0.1/access-model.md) and [wave log](versions/v0.1/wave-log.md) | v0.1 released and archived; v0.2 released 2026-10-22 and archived: [master spec](versions/v0.2/master-spec.md), [access model](versions/v0.2/access-model.md), [wave log](versions/v0.2/wave-log.md), build plan archived; v0.3 released 2026-10-30 and archived (below); v0.4–v0.7 and v1.0 draft |
| [versions/v0.3/](versions/v0.3/README.md) | v0.3's page and release notes, [master spec](versions/v0.3/master-spec.md), [access model](versions/v0.3/access-model.md) and [wave log](versions/v0.3/wave-log.md) | released 2026-10-30, merged into `main` (cba7be3); spec approved 2026-10-22 (D154), amended by D157 and D158; built from the [build plan](archive/v0.3/build-plan.md) v15 (D156); release gate passed, items 1 to 15, G9 and G10 cleared; [release notes](versions/v0.3/README.md#release-notes); the build plan, the eight drafts and the review list archived in [archive/v0.3/](archive/v0.3/README.md); page draft v11 |
| [versions/v0.4/](versions/v0.4/README.md) | v0.4's page and release notes, [master spec](versions/v0.4/master-spec.md), [access model](versions/v0.4/access-model.md) and [wave log](versions/v0.4/wave-log.md); four drafts kept: [purpose catalogue](versions/v0.4/purpose-catalogue.md), [shop domain](versions/v0.4/shop-domain.md), [governance](versions/v0.4/governance.md), [candidate faults](versions/v0.4/candidate-faults.md) | released 2026-11-03, merged into `main` (56b7471); spec approved 2026-10-30 (D215), amended through the build (its status note); built from the [build plan](archive/v0.4/build-plan.md) v16 (D216); release gate passed 2026-11-03, G11 cleared, the smoke run's end-of-run checks a known limit (D313); the two-host runs, the rehearsal, the stance check-list and the long-running tests moved to [v1.0 gating](versions/README.md#v10-gating) (D311, D312); [release notes](versions/v0.4/README.md#release-notes); the build plan and four drafts archived in [archive/v0.4/](archive/v0.4/README.md); page v13 |
| [versions/v0.5/](versions/v0.5/README.md) | v0.5's page and release notes, centred on domain definition and the veterinary clinic (D233); its [master spec](versions/v0.5/master-spec.md), [access model](versions/v0.5/access-model.md) and [wave log](versions/v0.5/wave-log.md); the approved [domain procedure](versions/v0.5/domain-procedure.md) and the six domain documents ([`vet-core`](versions/v0.5/vet-core-domain.md), [`vet-lab`](versions/v0.5/vet-lab-domain.md), [`vet-scheduling`](versions/v0.5/vet-scheduling-domain.md), [`vet-housing`](versions/v0.5/vet-housing-domain.md), [`vet-machinery`](versions/v0.5/vet-machinery-domain.md), [`vet-portal`](versions/v0.5/vet-portal-domain.md)); the drafts kept: [purposes](versions/v0.5/clinic-purposes.md), [traps](versions/v0.5/clinic-traps.md), [test selection](versions/v0.5/clinic-test-selection.md), [capacity](versions/v0.5/clinic-capacity.md), [data register](versions/v0.5/data-register-handout.md), [producer profiles](versions/v0.5/producer-profiles.md), [third parties](versions/v0.5/third-parties.md), [one centre](versions/v0.5/one-centre.md), [cold storage](versions/v0.5/cold-storage.md), [replication](versions/v0.5/replication.md), [brick options review](versions/v0.5/brick-options-review.md) | released 2026-11-14, merged into `main` (`a56e5ac`); spec approved 2026-11-03 (D339, D340), amended through the build (its status note), last by D474; built from the [build plan](archive/v0.5/build-plan.md) v21 (D342) in five waves and 38 chunks, short tests only (D314); release gate passed 2026-11-13, the whole clinic deployed once on armenelos plus the VPS (G13), G15 cleared (D475); known limits named, G13's findings 1 and 4 among them (D476; O269, O270), the long-running checks [v1.0 gating](versions/README.md#v10-gating); [release notes](versions/v0.5/README.md#release-notes); the build plan, decisions and resolved questions archived in [archive/v0.5/](archive/v0.5/README.md); page v2 |
| [versions/v0.6/](versions/v0.6/README.md) | v0.6's page: one game's web front and its home page, the documentation website, general-use tooling; the [network overview](versions/v0.6/network-overview.md) handout; [fake aging](versions/v0.6/fake-aging.md), a second aging mode | drafting opened 2026-11-13: the owner's rulings D480–D486 (O135 closed: no front above several games, no reporting tool; no network map; the network overview a handout that may be wrong, O21 narrowed; O251 placed); network overview draft v2, O260–O268 closed as recommended, every handout a static snapshot of the mission's start (D487, D488); fake aging draft v1 (2026-11-15): two aging modes, fixable caveats fixed and the rest documented, faults curated (D489–D491), the bar a student not stumbling on it (D492), O22 closed (D493); draft v2: players never told about the aging process (D494, O271 closed), the shop and the campaign in v0.6, the clinic later (D495, O272 closed); draft v3 (2026-11-16): a reported tell explained once the game is concluded (D496, refining D494); the GM's feedback in two parts, the customer side and a teaching moment, on the v0.6 page (D497, refining D9); D496's three readings okayed; the eighteen pending points agreed as recommended (D498–D503, O21 and O32 closed; [pointer](versions/v0.6/README.md#pending-owner-rulings-before-consolidation)); `main` merged after v0.5's close, O269 brought in and settled (D476, D510); the review of the drafting (REJECT) closed by D504–D512: the initiator who plays (D504), N9 dropped (D505), the restart record (D506), the monitoring at the restart and the early check (D507), P0's reach (D508), v1.0 gating's v0.6 items (D509), Reports and the short tests (D511); **consolidated** 2026-11-16 into the [master spec](versions/v0.6/master-spec.md) and its [access model](versions/v0.6/access-model.md), a delta on v0.5's (D514), the partners' status pages designed there (D513), the drafts' content moved into gm-stance.md v15, scenario-lifecycle.md v14, formats.md v34, bricks-and-faults.md v11 and planes-and-access.md v19; **approved** 2026-11-16, the review's defaults standing (D517), every brick bumped (D515), D504 confirmed (D516); [build plan](versions/v0.6/build-plan.md) (14 chunks, four waves, κ = 2) **approved** 2026-11-16 (D518), v2 with the reference archived outside git (D519) and `fa-real` torn down after chunk 1 (D520); v3 with capture W1's corrections, the master spec amended for `seed_changes[].lines` and `admitted.from` in hours (D521, D522); v4 after chunk 8: the fill covers a routine pinning its own `search_path`, its catalog tell a documented limit, f4 and f7 back to `supported` (D523, refining D508), chunk 15 inserted in wave 2 (D524), the seed and the T0 plantings on the virtual T0's clock in chunk 9 (D525); v5 to v7 in wave 2: capture W2's corrections (D527–D529), chunk 9's blockers (D530, D532, D533), waves 1 and 2's forms as built (G10.1, G10.2, formats.md v36, D534), `clean-restart` never before the anchor (D535), the statistics reset before the stop (D536), an instance's `admitted:` in the scenario document (D537); v8 after wave 2's gate: chunk 16 in wave 4, every fixture's scenario document regenerated (D538), `pg_cron` and `pgaudit` re-pinned in `postgres` 0.5.1, pgAudit 18.1 left for later (D539); v9 in wave 3, capture W3's corrections: the players' shell on the Prometheus node kept, the TSDB folder hiding the blocks (D540), Prometheus' own series showing the import a documented limit (D541), no refused instance a handout names in a GM-run game (D542), `suppressed_by` from the hiding instance's planting (D543), the setup's measured time in the "Fake aging" section (D544); v10 after chunk 11a: the shop's f9 hides f4 in state and logs only, no `suppressed_by` there, its f5 no `daily_spike` (D548); v11 after chunk 11b: the campaign's f5 alike, so no covered fault uses `suppressed_by`, report-only nodes' keys timed from the fill or with psql, the campaign's evening-window figures read as such by chunk 12 (D578); v12 after wave 3's gate: wave 3's forms as built (G10.3, formats.md v39, D580), the seam's join on size gauges (D581), a fake game's restart with no history on the real clock (D582), one history import at a time, a failed seam never imported again (D583); v13 after G10.3: chunk 12 gives the shop's f8 a measured `gauge_before` (D584), its form O292 (G13); v14: O292 ruled, a `gauge_before` adds its value to the drawn level, f8's the index's size (D585, G13 cleared, formats.md v40); v15: chunk 12 split in three, the shop's M1 comparison scaling run R to the game's span (D586); v16: PostgreSQL 19 everywhere, the master spec amended (D587), zlib1g at the release gate (D588), chunk 17 inserted in wave 4 as 17a to 17c (D589), the figures measured on 18 kept, one size re-measured (D590); O294 (pgBadger's checkpoint lines on 19) and O295 (autoanalyze logging on 19) open |
| [gm-stance.md](gm-stance.md) | How the GM behaves and speaks: setup questions (whether the initiator plays, from v0.6), issues, report-only interaction, no reveals, stop only, restarts, the two aging modes and never speaking of the aging in play, no events outside the schedule, final answer, the feedback in two parts, future ideas; from v0.7 the GM an agent, the game assistant beside it | draft v16 |
| [scenario-lifecycle.md](scenario-lifecycle.md) | The game from setup to teardown: setup inputs, scenario, local implementation, deploy, aging (real time from v0.3; fake aging beside it from v0.6, D489), hand-over (the handouts static, which may be wrong, English), end of the game | draft v14 |
| [formats.md](formats.md) | What a scenario folder, a brick (with its companion material and GM documentation) and a fault definition must contain; versions and pins; the local implementation; the skills and templates; where a job runs (D207); from v0.4, the purpose, the domain, governance and the new fields; a test-only brick change bumps nothing (D229); an outbound flow's `fields` are its outbox's payload keys (D231); `separation: instance` refused with `locations: any` (D253); a `state` fault's `seed_changes` (D254); from v0.5, the domain format, composing domains, the data register and the purpose format's extensions (D338, closing O111); a domain's producer folders per node (D344), the `api` node's `api.yaml` (D345), the `api` role (D349); wave 2's format items as built (D364): loading a composed domain from the catalogue (the database convention and `:"DBNAME"`, `load_epoch`, a core's `keys.sql`, a partner's `data.sql`, `coherence.yaml`, a check reading `partners` on its node, D383), the `partners/` catalogue folder, the owners' traffic in `producers/partners/owners/` (D369); the merge's scenario layer `compose/<node>/` in the layout | draft v40, v0.6's format items at its consolidation (v34), a `seed_changes` item's declared `lines:` from wave 1 (v35, D521), waves 1 and 2's forms as built (v36, D534: the true overview's form, `service-times.yaml` and `wal-rate.yaml`, a fake game's records, the status file, the brick pages), v0.7's consolidation (v37: the agents, the GM's skills, `tools/play`, the game branch), `suppressed_by` from the hiding instance's planting (v38, D543) and wave 3's forms as built (v39, D580–D583: the history import, the record's `history`, `history_import`, the seam's findings, a fake game's restart, `# measured:` comments, a signature's optional parameters, the exporter's reach, the `**Fake aging.**` note, the calibration files) and the owner's ruling on O292 (v40, D585: a `gauge_before` adds its `value` to the drawn level) (the network overview, `admitted:`, `aging.fake`, `history:`, the restart record, `base:`, two loader refusals); amended in v0.5's build (v32: wave 4's format items as built, G18; v33: wave 5's, G19) |
| [bricks-and-faults.md](bricks-and-faults.md) | Catalog, v0.2's monitoring bricks, per-brick checks, proportionate tooling, solvability probe, fault interactions and families, difficulty, future backup-tooling faults | draft v11 |
| [versions/v0.7/](versions/v0.7/README.md) | v0.7's page: the [game assistant](versions/v0.7/game-assistant.md), a player-side helper with the player's access and no background, a coach (D545–D554); the GM and the assistant as [agents](versions/v0.7/agents.md) for Claude Code and OpenCode, the assistant with web access (D559–D561, D563); the repository's [game mode](versions/v0.7/game-mode.md), the GM's memory kept clean (D555–D557) | drafting opened 2026-11-19 (D549); game assistant draft v4, agents draft v3, game mode draft v3; every pending proposal accepted and `main` made the game branch (D564–D571); the drafts' review (REJECT, ten findings) closed (D572); **consolidated** 2026-11-19 into the [master spec](versions/v0.7/master-spec.md) and [access model](versions/v0.7/access-model.md) (D573), formats.md v37, gm-stance.md v16, planes-and-access.md v20, concept.md v17; [build plan](versions/v0.7/build-plan.md) v1 (three waves, wave 1 buildable now); **approved** 2026-11-19 with the build plan (D574), `main`'s history settled (D575); plan v3 in wave 1: chunk 9 inserted in wave 2 for the carried GM docs' links into `specs/` (D576), `SECURITY_TODO.md` dev-only, the master spec amended (D577); O291 open (the clinic's trap witnesses on `main`) |
| [../references/grille-audit-pg.md](../references/grille-audit-pg.md) | The owner's PostgreSQL audit grid, a verbatim copy (French), informative only (D558); moved from `specs/references/` to the clone's root by v0.7's build ([master spec](versions/v0.7/master-spec.md#615-the-audit-grid) 6.15) | reference |
| [planes-and-access.md](planes-and-access.md) | Bastion-only rule (the bastion publishes the web interfaces), planes, the GM session, trust, write policies, the scheduler nodes, the customer's data policy kept apart from the game's access, hardening, validators; from v0.7 the game assistant on the player's side, two trust lines | draft v20 |
| [platform.md](platform.md) | Hosting, resources and nerfing, scenario content delivery, portability, Swarm facts and pitfalls, the shared VPS | draft v19 |
| [open-questions.md](open-questions.md) | Open-questions register | live |
| [decisions.md](decisions.md) | Decisions log: every entry through v0.5 archived, one file per range, mapped in each milestone's README (D1–D54 with v0.1, D55–D106 with v0.2, D108–D112 and D114–D189 with v0.3, D190–D313's v0.4 entries with v0.4, D107, D113 and D192–D476's v0.5 entries with v0.5); take the next number from `doc-ids` | live |
| [archive/](archive/README.md) | Closed milestones' working records, kept verbatim: v0.1's to v0.5's build plans, v0.3's drafts and review list, four of v0.4's drafts, the decisions through D476, resolved questions | archive |

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
  activity point, one game's web front with a home page (D233, D480),
  then v1.0; beyond v1.0,
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
  node, 25 nodes and 4.05 CPU in all (D340, O220 closed). Built in five
  waves and 38 chunks (D342–D473); the release gate passed on
  2026-11-13 and G15 was cleared on 2026-11-14, v0.5 released (D475);
  the partners' database admitting by role and password a verified
  access-model gap (D474); G13's findings 1 and 4 known limits, the
  loader's seed-file check for v0.6 (O269) and the clinic's setup for
  v1.0 gating (O270) (D476).
- v0.7 (2026-11-19, D549): the game assistant, an agent for Claude Code
  and OpenCode allowed no skill, as the GM becomes an agent allowed its
  helpers, the two dialects kept by hand (D559–D561, amending D546), with
  the player's access on trust (two trust
  lines: in the assistant, in the players), no background, never a
  database, writing only the report and its drafts wherever the players
  like, a coach, always available, no channel to the GM, graded
  reminders on what players paste and its own SQL minimised (D545,
  D546, D550–D554; D547 amended); the owner's audit grid an informative
  example (D558); the GM leaks no game data through memory, only game
  mode is pushed, a game played from a fresh clone (D555–D557); web
  access for the assistant, to check versions and the tools' behaviour
  (D563, superseding D562); `main` the game branch, a `dev` branch for
  development, a dedicated skill the only way `main` is updated (D564);
  memory off in game mode (D565); v1.0 gating after v0.7 (D566); every
  pending proposal accepted (D567–D571); consolidated (D572, D573) and
  approved with its build plan on 2026-11-19 (D574), `main`'s history
  never rewritten, one snapshot commit per publish, `dev` off the public
  remote (D575) ([v0.7](versions/v0.7/README.md)).
- Small project: scripts and small apps, no ATD, no UI/UX tree (D2).
- v0.1 build: seven artifacts (three skills, a Python/POSIX-shell script
  set, PostgreSQL 18 on Debian 13 and bastion bricks, one scenario), one
  host, four expected resolutions (report, propose, fix, improve), players
  as `player` with a `dba` superuser role, testable stance check-list
  (D9, D33–D41); full detail in the
  [v0.1 master spec](versions/v0.1/master-spec.md).

## Next steps

1. v0.5 released on 2026-11-14 ([release notes](versions/v0.5/README.md#release-notes));
   next, v0.6's drafting ([v0.6](versions/v0.6/README.md)), with O251
   and O269 placed there; v1.0 gating's list in the
   [roadmap](versions/README.md#v10-gating), O249 and O270 among it.
2. The roadmap's "soon" question, O49 (backup tooling's version), then
   v1.0's from the "later" ones.
3. v0.7 ([page](versions/v0.7/README.md)): approved 2026-11-19 (D574);
   `v0.7-spec` merged into `main` (G2), then wave 1 (chunks 1–3); waves
   2 and 3 after v0.6's release and the switch to `dev`.
