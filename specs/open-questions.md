# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Questions resolved by the close of v0.3 (O45, O46, O78 and O81–O103) are
listed in
[archive/v0.3/open-questions-resolved.md](archive/v0.3/open-questions-resolved.md).
Numbering continues from O152.

Resolved during v0.4's drafting: O106 (D194), O110 (D195), O107 (D197), O120
(D198), O109 (D199), O121 (D200), O123 (D202), O105 (D203), O129 (D206), O131 (D207),
O132 (D211), O133 (D212). Resolved by the approval of v0.4's master
spec (D215): O104, O108, O115, O116, O117, O119, O122, O124, O125, and
O111's v0.4 part. Resolved during v0.4's build: O134 (D224), O140 (D253).

On 2026-10-31 v0.5 was centred on domain definition and the clinic
(D233), and its questions retargeted: O53 and O54 to later, version not
set (D237); O21 and O135 to v0.6; O24 and O25 to v1.0+ (D248). Resolved
during v0.5's drafting: O137 and O47 (D248), O126 (D249), O139 (D260),
O118 (D261), O80 (D262), O114 (D263), O145 (D274, D275), O144 (D278),
O127 (D285), O128 (D286), O79 (D289), O112 (D292), O147 (D293–D295),
O148 (D296, D297), O113 (D298), O149 (D300).

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
  from v0.5). Narrowed for v0.4 by D190 and D202: transformation is
  Python transformer scripts run by the extended scheduler brick (D203),
  over several PostgreSQL instances, `postgres_fdw` one method among
  others; another engine only if a purpose needs one, which none does
  (D194). Still open: which engine versions first, and how
  upgrade scenarios (both binaries, disk space) fit the budget, which
  the direction for v1.0 to v2 makes an exercise (D272). Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). v0.2 has one network and no network faults
  (D83). Separate networks for third parties wait here: v0.5 keeps one
  network, a third party's back end closed by its own access rules
  (D275). Refs: [platform.md](platform.md),
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md).

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
- **O21** (later, v0.6) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario? Due with v0.6's
  documentation website; no longer v0.5's (D233).
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
  which real time alone barely exercises; v0.4's part is settled by
  D199 (realistic cadences, none weekly or monthly); the clinic's
  weekly, monthly and yearly reports are in the game, past periods
  planted (D265, D269, D277; [producer-profiles.md](versions/v0.5/producer-profiles.md) 4).
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O23** (later) — Difficulty is a fault count, each fault worth 1 (easy
  5, normal 10, hard 20; D120), read for v0.3 as the number of fault
  instances, the levels being targets (D134). Ruled for the clinic's
  scenario (D290): ten faults at most, one dramatic and noticed by the
  customer, two on the verge of becoming problematic, the rest
  optimisations and minor frictions; an issue may be a false alarm.
  Still open beyond the clinic: whether that severity mix becomes the
  general rule, how many faults issues cover, and the mix of families.
  Refs: [bricks-and-faults.md](bricks-and-faults.md),
  [versions/v0.5/README.md](versions/v0.5/README.md#in-scope).
- **O24** (later, v1.0+; D248) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O25** (later, v1.0+; D248) — Scenario-only bricks and faults may live in the
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

## v0.4: purposes

Raised when the owner recast v0.4 as "bricks of why and bits of hows"
on 2026-10-28 (D190). O11, O22, O25 and O52 are revised by it. Worked
into drafts on 2026-10-30 ([versions/v0.4/](versions/v0.4/README.md#documents)):
O106 closed (D194), O110 closed (D195), O122 to O125 raised; the
owner's rulings closed O107 (D197) and O109 (D199) the same day, and his
technology direction O123 (D202) and O105 (D203), raising O129, which
his ruling on jobs on a database node closed (D206), raising O131,
which he confirmed as written (D207). O132 and O133, raised by the
consolidation, were ruled the same day (D211, D212), and the approval
of the [master spec](versions/v0.4/master-spec.md) closed O104, O108,
O122, O124 and O125 as written there (D215). None is open.

## v0.4: data governance

Raised when the owner added a first cut of data governance to v0.4 on
2026-10-28 (D191): data classes, their rules, a policy handed to the
players, `gm_check` definition checks. The customer's governance, in the
game's world, not the game's access model. Drafted on 2026-10-30 in
[governance.md](versions/v0.4/governance.md), tested against the
clinic's classes (D196); O120 closed by D198 (an instance of its own);
O115, O116, O117 and O119 closed by the master spec's approval, as
written there (D215). O118, held for v0.5, closed by D250 and D261
(TLS and pgaudit always available in `postgres`); O134, raised by D221,
closed by D224; O136, raised by D230, waits for a later version. O140,
raised by chunk 12, closed by D253.

- **O136** (later, with the open `SECURITY DEFINER` candidate fault) —
  G3 judges a definer procedure by its owner (D230). Should it also
  weigh who may execute it, so a procedure owned by an allowed reader
  but executable by `PUBLIC` or a disallowed role is a path? No v0.4
  fault turns on it. Refs:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 11.6, 22.

## v0.5: domains

Raised when the owner set business domains for v0.5 on 2026-10-28
(D192). v0.4 ships the first, the shop (O108). The veterinary clinic
added on 2026-10-30 (D196).

- **O111** (later, v0.5) — The domain format, beyond v0.4's part. v0.4's
  part was settled by the master spec's approval (D215): `domains/shop/`
  with `domain.yaml`, `data/` (schema, load, classification),
  `producers/`, `docs/gm.md`, a design-time source named for provenance
  that never bumps, static scenarios needing none
  ([master spec](versions/v0.4/master-spec.md) 6.8). Still open: what
  the format gains when v0.5 adds the clinic's domains, beyond the four
  changes D249 settled (the business's own rules in a domain,
  classification keys without the database, `requires`, a scenario's
  `domains:` list;
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md)
  5, 6): profiles against the schedule (O113), the variant manifest and its
  tags (D263; procedure 9), and what the
  clinic's domains reveal. Finalised in the master spec when v0.5
  consolidates (D291), which closes it.
- **O151** (next, v0.5) — `vet-lab`'s business sketch: fifteen
  questions, each with a proposed default, from where the lab's
  database sits and how the centre's orders reach it to residue tests,
  notifiable diseases, billing the practices and a part's scale in the
  format. The data model (step 4) waits for the answers. Refs:
  [versions/v0.5/vet-lab-domain.md](versions/v0.5/vet-lab-domain.md#questions-for-the-owner-o151).

## v0.6: the setup's entry point

Raised by the owner's ruling on the web front (D224): every game has a
web front from v0.4, and he expects more around it, "Expect it to
evolve both with v0.5 and v1.0+". Moved from v0.5 to v0.6 (D233,
D248).

- **O135** (later, v0.6) — A common entry point for the whole setup: one
  Caddy in front of several games' web fronts, and a homepage for the
  setup dispatching the viewer to each game's rules (READMEs, game
  information, data policies, issues), tools and dashboards; and a
  reporting tool joining a game's starter-pack page (D221). To settle:
  where the Caddy runs (the build host, a VPS whose own Caddy is shared
  with other sites, platform.md) and who may reach the homepage; how it
  keeps the bastion-only rule (it may proxy only to each game's
  published web front, never to a node); what a game publishes to it
  and when it leaves at teardown; the tools password per game behind a
  shared front; how it relates to v0.6's landing page and documentation
  website on the bastion; what the reporting tool is (the players
  writing their report, or reports generated in the stack, v0.6).
  Refs: [versions/v0.6/README.md](versions/v0.6/README.md#the-setups-entry-point-d224),
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 7.3, 22.

## v0.5: scope, the domain procedure, post-mortems

Raised on 2026-10-31, when the owner centred v0.5 on domain definition
and the clinic (D233), asked for a procedure for defining a domain
(D235) and began a post-mortem collection (D234). O139, approving the
rest of the procedure, closed by D260.

- **O138** (later, version not set) — Binding post-mortems to the game
  (D234). Settled (D251): the binding comes in a later version; the
  handout is given after the final answer, keeping no reveals before it
  ([gm-stance.md](gm-stance.md)), and it summarises its source and links
  to it rather than copying it. Still open: which version; how a fault
  or a scenario cites an entry (a field of `fault.yaml`, the answer
  key); the handout's form; how close a replication must stay to the
  real failure when the stack differs. Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-post-mortem-collection-d234).

## Beyond v1.0: the cloud provider

Raised when the owner set a fictional cloud provider after v1.0
(D205). Settled there: a fictional name, the console's layout our own,
no AWS-style IAM.

- **O130** (later, after v1.0) — The provider layer's design: the type
  ladder and how a type maps onto limits, reservations and `fit`; the
  service kinds and what each denies (a managed database with no shell
  on its host, proposed, against the players' `dba` today); which
  capacity actions players get and what a resize does mid-game (a
  service update restarts the node); the console's relation to v0.6's
  bastion; its own entry point beside the setup's homepage (O135,
  D224); the in-world name. Refs:
  [versions/README.md](versions/README.md#beyond-v10-a-fictional-cloud-provider-d205).

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47); O121, raised by the owner's ruling on
release gates (D193), was resolved for v0.4 by D200; O47 by D248
(scenario generation in v1.0). The tag after the priority is the version
the question concerns.

- **O48** (later, v0.3 → v1.0) — Aging enters in v0.3, in real time
  (D114). Where does the solvability probe as a gate (O20) enter the
  roadmap? With an aging of eight hours or more (D150), a probe failing at
  hand-over costs the class; v0.3's master spec has an early check during
  aging and a hand-over check. Refs:
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O49** (soon, roadmap) — Backup tools (pgBackRest and the like) and the
  backup-tooling fault families (D17) are in no version, although backups
  were a founding example and the v0.1 goal speaks of "investigating a
  backup". Which version? WAL archiving and base backups with plain
  PostgreSQL tools are in v0.5 (D299); left here: pgBackRest and the
  like, restores, point-in-time recovery and restore drills, for
  v1.0+'s DBA work (D272). Refs:
  [bricks-and-faults.md](bricks-and-faults.md), "Future ideas: backup
  tooling".
- **O52** (later, after v0.4) — dbt adds a Python toolchain and adapters
  to a node image: image size and build time, one image per adapter
  (Postgres, DuckDB), versions to pin. One transformer brick per
  technology? v0.4 plans no dbt: its jobs run on one generic job runner
  (D190, D203). Stands for whichever later version or purpose wants dbt.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O53** (later, version not set; D237) — Bluebox as a dataset. The
  owner sees it as "quite akin to a domain": a later domain candidate,
  brought in through the domain procedure, its dataset filling that
  domain's data model
  ([versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md) 2):
  - its schema needs PostGIS, `pg_stat_statements` (a preloaded library)
    and `pg_trgm`, so a PostgreSQL 18 brick with those extensions;
  - its dump is about 88 MB compressed and larger restored, against the
    disk budget and the time to load it at setup;
  - a file that size should not live in the repository, yet a scenario
    folder plus the repository is meant to be self-sufficient (D23);
  - its code is MIT-licensed, but part of its data comes from TMDB and
    other sources whose redistribution terms need checking;
  - its ongoing data generation relies on `pg_cron`.

  Refs: [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
- **O54** (later, version not set; D237) — Internet-sourced datasets:
  availability at setup time, licensing, and reproducibility against the
  self-sufficient scenario folder (D23). Pin by address and checksum and
  cache locally? Refs:
  [versions/README.md](versions/README.md#deferred-from-v05-d233-d237).
