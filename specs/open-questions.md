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
Questions resolved by the close of v0.4 (O104–O110, O115–O117, O119–O125,
O129, O131–O134, O140, O146 and O161–O163, and O111's v0.4 part) are
listed in
[archive/v0.4/open-questions-resolved.md](archive/v0.4/open-questions-resolved.md).
Questions resolved by the close of v0.5 (O47, O79, O80, O111's v0.5
part, O112–O114, O118, O126–O128, O137, O139, O144, O145, O147–O149,
O151–O156, O158, O164, O165, O168–O190, O192–O215, O217–O220,
O223–O227, O229, O235, O236, O239–O243, O247 and O250) are listed in
[archive/v0.5/open-questions-resolved.md](archive/v0.5/open-questions-resolved.md)
and mapped in [archive/v0.5/README.md](archive/v0.5/README.md#where-it-now-lives).
O166, O167, O191, O216, O221, O222, O228, O230, O233, O244, O245 and
O248 were reserved during v0.5 and never used. Questions resolved by
the close of v0.6 (O21, O22, O32, O135, O251, O260–O269, O271, O272,
O292, O294 and O295) are listed in
[archive/v0.6/open-questions-resolved.md](archive/v0.6/open-questions-resolved.md)
and mapped in [archive/v0.6/README.md](archive/v0.6/README.md#where-it-now-lives).
O273, O293, O296 and O297 were never used (O296 and O297 reserved
during v0.6's build).
Take the next number from `doc-ids`; no ID is reused.

v0.5 retargeted its questions on 2026-10-31 (D233): O53 and O54 to
later, version not set (D237); O21 and O135 to v0.6; O24 and O25 to
v1.0+ (D248).

v0.6 was released on 2026-11-20 (D599). How its questions were raised
and closed is archived with them; O251 and O269 closed once built
(D602). O298 and O299, raised in its wave 4 and ruled at G11 (D601),
stay open until done (below).

On 2026-11-19 the game assistant's draft opened (D545–D547), outside
v0.6, raising O274–O285; the owner's rulings the same day placed it in
v0.7 (D549) and closed O274–O281 and O283–O285 (D549–D554, D558),
widened O282 into the repository's game mode (D555–D557), and raised
O286–O288; the GM and the assistant made agents (D559–D561) raised O289,
closed by D562, then by D563, which reversed it. The owner then closed
O282 and O286–O288 (D564–D570) and the game branch raised O290, closed
at v0.7's approval (D575). Wave 1's chunk 3 raised O291 (D576), open.

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
  (D194). Until v1.0 each brick takes its tool's latest release; from
  v1.0 versions are handled game-wide, older ones included (D396).
  Still open: which engine versions first, and how
  upgrade scenarios (both binaries, disk space) fit the budget, which
  the direction for v1.0 to v2 makes an exercise (D272). Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [versions/README.md](versions/README.md#from-v10-versions-at-a-game-wide-scope-d396),
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
- **O232** (later, version not set; D397) — A snapshot and restore of
  the whole game as a feature of the game itself: the owner, 2026-11-04,
  "ability to take snapshot and restore the full game at a given point
  [...] I'd love for the game to keep track of the game time and stay
  set on it", and, for now, "Full game snapshot/restoration without
  interruption of service as seen through the game will have to wait".
  The known constraint: containers share the host's clock, so the game
  cannot hold a clock of its own; a restore at a later wall-clock time
  shows as a gap in the data unless the restored data's timestamps are
  shifted forward ("age once, restore many"). Open: when, how game time
  is kept and shown, whether timestamps are shifted at restore, and how
  it meets the aging (O22) and the restart already in v1.0 gating.
  Today's restore (the hand-over snapshot, a player-confirmed restart)
  is D397's. Refs: [versions/README.md](versions/README.md#v10-gating);
  [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 15.
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
- **O38** (later) — Is the feedback written to a file (the teacher is out
  of the game by then)? A scoring system is post-v1.0, unless research
  finds one quick to implement (D120). Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O231** (later, version not set; D395) — The starter pack hands the
  players the customer's own credentials with each partner (D365). DBAs
  are not security advisors, but they may find a company's integration
  credentials in a handout odd and report it; the owner, 2026-11-04:
  "we may need to rectify it at some point", the game keeping some
  distance from ground truth. Until then such a report is a plausible,
  reasonable finding, not a misreading. Open: whether to rectify (the
  credentials obtained another way, or kept and named a known
  practice), and how the feedback receives the report meanwhile. Refs:
  [versions/v0.5/access-model.md](versions/v0.5/access-model.md) 3, 6,
  13; [versions/v0.5/master-spec.md](versions/v0.5/master-spec.md) 10.2.

## v0.4: data governance

Raised when the owner added a first cut of data governance to v0.4 on
2026-10-28 (D191); its questions closed by v0.4's close are archived
([archive/v0.4/open-questions-resolved.md](archive/v0.4/open-questions-resolved.md)).
O136, raised by D230, waits for a later version.

- **O136** (later, with the open `SECURITY DEFINER` candidate fault) —
  G3 judges a definer procedure by its owner (D230). Should it also
  weigh who may execute it, so a procedure owned by an allowed reader
  but executable by `PUBLIC` or a disallowed role is a path? No v0.4
  fault turns on it. Refs:
  [versions/v0.4/master-spec.md](versions/v0.4/master-spec.md) 11.6, 22.

## v0.5: carried forward

Raised during v0.5's build and release gate and still open at its close
(2026-11-14); v0.5's resolved questions are archived
([archive/v0.5/open-questions-resolved.md](archive/v0.5/open-questions-resolved.md)).
O249 and O251 were raised at wave 5's gate, O251 placed in v0.6 by the
owner; O269 and O270 were raised by G13 and placed at v0.5's close
(D476). O251 and O269 were built in v0.6 and closed at its archive
(D602).

- **O249** (later, before the clinic is first played, v1.0 gating;
  raised by D467) — The partner stubs' reference counters: the
  authority's `AMU<year>-NNNN` and the head office's `HO<YYYYMM>-NNNN`
  count the stub's own rows (`count(*) + 1`), empty at the load, so the
  first live reference restarts at 0001 after the series the purposes'
  histories plant on the customer's side (chunk 35, D451). No repeat
  (the year or month is in the reference), but a player may read the
  count not continuing as a fault. Proposed: each stub's `data.sql`
  seeds its rows (or an offset) to continue the planted series, from the
  history's own `load_epoch` derivation, a test reading the first live
  reference. Refs: `purposes/vet-antimicrobial-use/` and
  `purposes/vet-head-office-figures/` (`material/receiver/`);
  [build plan](archive/v0.5/build-plan.md) release gate item 12.
- **O270** (later, v1.0 gating's setup; raised by G13's finding 4,
  filed as ISS-002; D476) — The whole clinic's `load-data` takes about
  28 minutes (1671 s and 1652 s at G13), about 17 of them `partners-db`
  at its 0.5 CPU limit building vet-lab's partners' orders; meanwhile
  cold storage answered 503 to lab's `vault-post` 66 times before T0,
  so lab's `pg_stat_archiver` shows failures at the hand-over that no
  fault explains. A v0.5 known limit. To settle before the clinic is
  first played: raise `partners-db`'s CPU during the load, compute the
  orders once, or have cold storage answer during the load; and what
  the GM's notes say until then. Refs:
  `issues/ISS-002_20261114_clinic_load_slow_vault_503.md`;
  [versions/README.md](versions/README.md#v10-gating).


## v0.6: game content found in wave 4

Findings of chunk 17c about game content that predates v0.6, routed at
G10.4 (D597); no content changed. Both ruled by the owner at G11 on
2026-11-20, as recommended (D601); each stays open until done.

- **O298** (later, before the clinic is next played; raised at G10.4
  from chunk 17c; **ruled**, D601, as recommended; open until a build
  touching the clinic loads pgaudit) — The clinic's pgaudit is described but never
  loaded. `vet-lab`'s and `vet-portal`'s `policy.md` (and their domain
  notes) tell the players pgaudit logs `write, ddl, role` with its
  parameters off on `lab` and `portal`, but no played scenario's or
  fixture's seed `shared_preload_libraries` loads pgaudit (only
  `postgres`' stack-test seeds and `fixture-composed` do): the
  aldermoor-centre seeds preload `pg_stat_statements,pg_cron`. So the
  traps T2 and T251 (pgaudit's parameters turned on) can't bite as
  built (neither is in the clinic's selection today), and a player who
  checks the policy against the server finds an unlisted breach no
  answer-key item explains. Default (proposed): load pgaudit in `lab`'s
  and `portal`'s seeds with the policy's settings, the overview, the
  register and the scenario document regenerated, in a build that
  touches the clinic (v0.7 or the clinic's fake aging); the alternative
  is rewording both policies to pgaudit off and dropping T2 and T251.
  Refs: [build plan](archive/v0.6/build-plan.md) chunk 17c; wave log
  "Chunk 17c — merged"; [vet-portal domain](versions/v0.5/vet-portal-domain.md) T251.
  Ruled so: pgaudit loaded in `lab`'s and `portal`'s seeds with the
  policy's settings, in a later build touching the clinic (v0.7 or the
  clinic's fake aging), before it is next played; it now needs that
  build.
- **O299** (v0.7, the audit grid; raised at G10.4 from chunk 17c;
  **ruled**, D601, as recommended; open until the owner's amended grid
  is copied in) — The
  owner's audit grid ([references/grille-audit-pg.md](../references/grille-audit-pg.md),
  a verbatim copy, D558) says every query is read-only and to run them
  in a `SET default_transaction_read_only = on;` session, but its
  sampling block ("Qui émet une requête") starts with `CREATE TEMP TABLE
  echantillons`, which PostgreSQL refuses in a read-only transaction
  (every `CREATE` is; only writes to a temporary table are allowed). A
  player or the game assistant following the grid as written gets an
  error. Default (proposed): the owner amends the grid (the sampling
  run in its own session without the read-only setting, or the note
  naming the exception), the copy refreshed; the alternative is the
  copy left verbatim and the game assistant's notes pointing it out.
  Refs: [v0.7 master spec](versions/v0.7/master-spec.md#615-the-audit-grid) 6.15.
  Ruled so: the owner amends his grid, and the copy is refreshed; it
  now needs the owner's amended grid.

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

## The game assistant

Raised on 2026-11-19 by the game assistant's draft, now
[versions/v0.7/game-assistant.md](versions/v0.7/game-assistant.md)
(D545–D547), and its sibling
[versions/v0.7/game-mode.md](versions/v0.7/game-mode.md), then
[versions/v0.7/agents.md](versions/v0.7/agents.md). The owner ruled the
same day: O274–O281 and O283–O285 closed (D549–D554, D558); the GM and
the assistant made agents for Claude Code and OpenCode (D559–D561),
raising O289, closed by D562, then by D563 (web access allowed). The
closed entries are kept here until
v0.7's archive. The
drafts' proposals are labelled GA1…, MD1… and AG1….

- **O274** (**closed**, D549) — Which version builds it? v0.7, the game
  assistant its subject. Recommended had been v1.0.
- **O275** (**closed**, D550, against the recommendation) — How it
  reaches the bastion. The player's own access, on trust; no door, no
  `gmctl` verb, no key. Recommended had been a forced-command door.
- **O276** (**closed**, D550) — The read set's content. No read set: a
  stance on its purview; `~/.pgpass` and `~/.psql_history` outside it.
- **O277** (**closed**, D551, as recommended) — How much it helps: a
  coach.
- **O278** (**closed**, D552, beyond the recommendation) — Database
  snippets. Reminders graded by criticality, schemas and other medium
  items included; its own SQL minimised by design.
- **O279** (**closed**, D553) — Does a game always allow it? Always
  available; no initiator switch. Recommended had been an initiator
  switch.
- **O280** (**closed**, D554, as recommended) — Does the GM learn that
  it helped? No; no communication between them.
- **O281** (**closed**, D554) — Where its files live. Anywhere the
  players like; `play/<game>/` a default only, the report reaching the GM
  however the players hand it in.
- **O282** (**closed**, D570, as recommended) — The GM helpers'
  descriptions in the assistant's listing. Invocation closed by its
  agent definitions (D559); the listing hidden on Claude Code by its
  session-only `skillOverrides`; the build's empirical check in both
  tools settles it, the helpers' descriptions rewritten neutral if it
  still leaks.
- **O283** (**closed**, D558) — The owner's audit grid as the
  assistant's method? An example it may draw on, not its method.
- **O284** (**closed**, D558) — Cutting the grid to the game's scope:
  not enforced; the draft's table kept as informative notes.
- **O285** (**closed**, D558) — Where it lives: a verbatim copy at
  [references/grille-audit-pg.md](../references/grille-audit-pg.md); a
  game-scoped English rewrite optional and later.
- **O286** (**closed**, D564, against the recommendation) — How game
  mode is produced. `main` is the game branch, a side dev branch the
  development environment, a dedicated skill the only way `main` is
  updated. Recommended had been the tracked files as game mode (MD1).
- **O287** (**closed**, D565, as recommended) — The GM's memory: the
  local implementation; `autoMemoryEnabled: false` committed in game
  mode.
- **O288** (**closed**, D566, as recommended) — v1.0 gating runs after
  v0.7, with the assistant's stance items.
- **O289** (**closed**, D563: web access allowed, against the
  recommendation; D562's denial superseded) — May the
  assistant use the web (Claude Code's
  `WebFetch` and `WebSearch`, OpenCode's `webfetch` and `websearch`)?
  Recommended: no: its PostgreSQL and tool knowledge is the model's, a
  web tool is one more way for what the players paste to leave, and
  looking things up is the players' own work; its `Bash` can still reach
  the web front with `curl`, on trust. Alternative: allowed, for the
  tools' upstream documentation only. Refs:
  [versions/v0.7/agents.md](versions/v0.7/agents.md) 5.
- **O290** (**closed**, D575, as recommended) — `main`'s history and
  `dev`'s remote (D564).
  `main` can't take a plain merge of `dev` (it would carry the dev-only
  paths). Recommended (MD9): each publish one new commit on `main`
  holding the filtered snapshot, history continuous, nothing rewritten,
  past commits keeping the development material already public; `dev`
  not pushed to the public `origin` (D556), a private remote if a backup
  is wanted. The alternative, rewriting `main`'s history to strip that
  material, needs a force-push that breaks every clone. Refs:
  [versions/v0.7/game-mode.md](versions/v0.7/game-mode.md) 3.
- **O291** (soon, v0.7, before the release gate's first publish; raised
  by plan v3, D576) — Is the clinic's trap catalogue GM material `main`
  must carry? The carried domain notes list each trap by number with a
  gloss and defer its witness and where it is fixed to v0.5's
  `clinic-traps.md` and the domain specs, which stay in `specs/`. A GM
  composing a clinic scenario on `main`, or judging a report naming a
  trap, has the gloss only. Default (proposed): the notes suffice, as
  the format's "GM notes" rule intends (the traps, each with its class);
  the alternative is a chunk carrying each trap's witness into its
  domain's `docs/gm.md`. Chunk 9 doesn't wait on it. Refs:
  [versions/v0.7/master-spec.md](versions/v0.7/master-spec.md#82-what-main-carries)
  8.2; [versions/v0.7/build-plan.md](versions/v0.7/build-plan.md) chunk 9.

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
  bastion, a site on the game's home page (D480); the network map it
  makes mandatory (D482); the in-world name. Refs:
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
  aging and a hand-over check. A fake-aged game (D489) reaches its
  hand-over about one real tail after setup, so there a failing probe
  costs a tail, not a day. Refs:
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
