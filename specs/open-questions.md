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
O248 were reserved during v0.5 and never used. Take the next number
from `doc-ids`; no ID is reused.

v0.5 retargeted its questions on 2026-10-31 (D233): O53 and O54 to
later, version not set (D237); O21 and O135 to v0.6; O24 and O25 to
v1.0+ (D248).

v0.6's drafting opened on 2026-11-13 (branch `v0.6-spec`): O135
resolved by the owner's rulings of that day (D480, D481), O21 narrowed
(D484), O251 placed (D486); O260–O268 raised by the network overview's
draft and closed the same day as recommended (D487, D488). On
2026-11-15 the owner's direction on fake aging closed O22 (D489–D493);
O271 and O272 raised with its draft and closed the same day by the
owner (D494, D495). On 2026-11-16 the owner agreed to every pending
v0.6 point as recommended, closing O21 (D502) and O32 (D503); the
same day the merge of `main` brought O269 into v0.6 (D476), settled as
proposed (D510), and v0.6 was consolidated into its
[master spec](versions/v0.6/master-spec.md) (D514); O251 and O269 stay
open until built.

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
- **O21** (**closed**, D502: only the data register and the network
  overview may carry a planted inaccuracy; the README, rules, data
  policy and `partners.md` never; the story and issues only as the
  customer's belief; kept here until v0.6's archive) (later, v0.6) —
  Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario? Due with v0.6's
  documentation website; no longer v0.5's (D233). Narrowed by D330: the
  data register may carry one from v0.5 (T300–T308); and by D484: v0.6's
  network overview may too. Still open for the other starter files (the
  README, story, issues, data policy, `partners.md`).
- **O22** (**closed**, D489–D493: fake aging joins real aging as a
  second mode from v0.6, forged history and a compressed fill, never
  fake time; the volume copy no longer planned, its use O232's;
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md); kept here
  until v0.6's archive) — Aging technique. v0.3 ages in real time
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
- **O32** (**closed**, D503: English everywhere, the website and the
  feedback included; a scenario language option later, not in v0.6;
  kept here until v0.6's archive) (later) — Language of player-facing
  material (story, starter documentation, issues, feedback).
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
(D476).

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
- **O251** (soon, v0.6; raised at wave 5's gate, 2026-11-12; **placed**
  in v0.6 by the owner, 2026-11-13 (D486): v0.6's first chunk touching
  `tools/gm/model.py`) — The
  loader does not enforce the format rule that a bastion maps
  `partners.md: player/partners.md` exactly when the scenario's
  `third_parties:` carry a `player_doc` (formats.md "Partners"). It
  catches the omission only through `credentials:` (a listed credential
  the unmapped page cannot name), so five fixtures whose partners list
  none passed without the page until gate fix `026e023` mapped it by
  hand. No v0.5 scenario or fixture breaks the rule now, and the players'
  page is the only loss (no check reads it). Proposed: a loader refusal
  in v0.6's first chunk touching `tools/gm/model.py` ("third parties
  carry a `player_doc`, but the bastion maps no `partners.md`", and the
  converse), with a unit test; no v0.5 chunk. Refs: `tools/gm/model.py`
  (`PARTNERS_SEED_FILE`); `.claude/skills/scenario-format/SKILL.md`
  (third parties); [formats.md](formats.md) "Partners".
- **O269** (soon, v0.6; raised by G13's finding 1, filed as ISS-001;
  D476; **settled** by D510 as proposed, the loader refusal, built
  beside O251's in v0.6's first chunk touching `tools/gm/model.py`;
  open until built) — The loader does not check that a `seed-file` fault instance's
  `seed_changes` lines appear in the scenario's copies of the seed
  files, where formats.md (fault "Injection") puts them. In
  `aldermoor-centre` the lines of s2, s7 and s8 were missing; the format
  check, `compose --check`, chunk 27's runs and wave 5's gate all
  passed, and only the whole-clinic run saw it (fixed in the scenario,
  `0118c90`). A v0.5 known limit: the line in the scenario's copy is
  the GM's to check. To settle in v0.6: a loader refusal (each selected
  instance's lines found in its node's copy, with a unit test) or a
  check item of the `scenario-format` skill. Proposed: the loader
  refusal, since the skill's check is the GM reading by hand. Refs:
  `issues/ISS-001_20261114_loader_misses_unplanted_seed_faults.md`;
  `tools/gm/model.py`; [formats.md](formats.md) "Fault definition".
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


## v0.6: the network overview

O260–O268, raised by the network overview's first draft (D483–D485),
closed on 2026-11-13 as recommended (D487, D488); each question's text
is on
[versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#questions-for-the-owner).
O135, the setup's entry point, closed by D480 (one game's front, no
front above several games) and D481 (no reporting tool). None open;
the closed entries are kept here until v0.6's archive moves them:

- **O260** (v0.6; **closed**, D487, as recommended) — Is the page's "Your access" column the game's
  rule, always exact and never a planted deviation? Recommended: yes,
  marked as such on the page, the README pointing to it.
- **O261** (v0.6; **closed**, D487, as recommended) — The bastion on the page: a node entry, or a
  fixed note? Recommended: a fixed note at the top (the players' kit,
  D65, D87), never a deviation, with its Node health link.
- **O262** (v0.6; **closed**, D487, as recommended) — Third parties on the page. Recommended: a
  closing table, one row per partner with a `player_doc`, by its
  hostname, access none; the partners' shared nodes never named (D469).
- **O263** (v0.6; **closed**, D487, as recommended) — The format additions for the fields with no
  source today (a node's `description`, `site`, `users`; a brick's
  `base`; a domain's `data/overview.yaml`; the crontab comment rule).
  Recommended: accept, into v0.6's master spec.
- **O264** (v0.6; **closed**, D487, as recommended) — A `node` variable on the Node health
  dashboard, each entry linking its own node. Recommended: yes.
- **O265** (v0.6; **closed**, D487, as recommended) — The overview and the data register planted
  independently, so one may give away a fault of the other.
  Recommended: independent; the answer key notes the interaction.
- **O266** (v0.6; **closed**, D487, as recommended) — Resolving and classing an overview fault.
  Recommended: *propose*, M by default, family `documentation`, ids
  `docs-overview-*`, as the register's.
- **O267** (v0.6; **closed**, D487, as recommended) — The home page's shape and what leaves the
  README. Recommended: two lists (sites, documents), one page per
  handout; the node table and the network paragraph leave the README.
- **O268** (v0.6; **closed**, D488, as recommended, with the owner's clarification) — The true overview read from seed files a
  system fault may have changed. Recommended: the skill states the
  design, the value before the fault's change.

## v0.6: fake aging

Raised by the fake aging draft (D489–D493) and closed by the owner on
2026-11-15; the closed entries are kept here until v0.6's archive moves
them. Text on
[versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#questions-for-the-owner).
O292 raised by the build (D584), closed by D585.

- **O271** (v0.6; **closed**, D494, against the recommendation) — Are
  the players ever told their game was fake-aged? Never: not during
  the game, not in the feedback, not after the final answer.
  Recommended had been: the feedback says so after the final answer.
  Refined by D496 (2026-11-16): never during the game; once it is
  concluded, a tell the report names may be explained.
- **O272** (v0.6; **closed**, D495, as recommended) — Which scenarios
  does v0.6 make fake-ageable? The shop and the campaign (its f10
  `real-only`); the clinic later.
- **O292** (v0.6; **closed**, D585, as recommended; raised by D584,
  gate G13 of the [build plan](versions/v0.6/build-plan.md)) — The form of f8's
  `gauge_before`. As built (`tools/gm/history.py`, formats.md v39) it
  holds one absolute `value` flat over the forged past until the
  planting: the shop's database size would read flat from 22:00 to
  08:00 (fix 5 also says "growing with the load's shape"), the step at
  08:00 is `value` less the forged size there, so it reads as the
  index's size only if `value` is set from the shop's own level, and
  that shop number sits in a catalogue fault `bookshop-new-server` uses
  too. Keep the kind (the flat night a 9.10 limit), or make the entry
  add its value, the index's size, to the drawn size before the
  planting (`history.py`, formats.md, `fixture-dropped-index`'s value).
  Recommended: the latter. Ruled so: a `gauge_before` adds its value.

## v0.6: PostgreSQL 19

Raised by D587's placement (D589); each gates one item of chunk 17c
(gate G15 of the [build plan](versions/v0.6/build-plan.md)), never the
images. O296 was reserved during that drafting and never used. Both
closed by the owner on 2026-11-19 (D591, D592); the closed entries are
kept here until v0.6's archive moves them.

- **O294** (v0.6; **closed**, D591, as recommended; before chunk 17c's
  documentation item; raised by D589) — pgBadger 13.3, the latest release and PGDG's, no longer reads
  PostgreSQL 19's `checkpoint complete:` lines (19 writes the
  checkpoint's flags before `wrote`; its regex wants `complete: wrote`),
  so a player's report on 19 has an empty checkpoint section: buffers
  written, WAL files added and recycled, write and sync times. No fault's
  witness reads it (f10's pgBadger witness is the kill and the restart),
  and no fix exists upstream. Default (proposed): accept it as a known
  limit, named in `postgres`' `docs/gm.md` and the release notes, the
  next pgBadger taken under D396 when it fixes it; the alternatives are
  a local patch of the packaged script (a fork to keep) or keeping
  `postgres` on 18 (against D587). Refs: build plan chunk 17c. Ruled
  so: a known limit.
- **O295** (v0.6; **closed**, D592, as recommended; before chunk 17c's
  seed item; raised by D589) — On
  PostgreSQL 19, `log_autovacuum_min_duration` covers vacuum only and
  the new `log_autoanalyze_min_duration` (default 10 minutes) gates the
  autoanalyze lines, so every seed setting `log_autovacuum_min_duration
  = 0` (56 `postgresql.conf` files: 13 in the scenarios and bricks, 43
  in the test fixtures) stops logging autoanalyze. Nothing
  in the game reads those lines (no witness, no check); pgBadger's
  autovacuum section and a player reading the log see fewer. Default
  (proposed): add `log_autoanalyze_min_duration = 0` beside it in every
  such seed, keeping what the customers' logs show as designed, with
  the overviews and documents those seeds feed regenerated; the
  alternative is leaving the seeds as written, the lines gone. Refs:
  build plan chunk 17c. Ruled so: the new setting added.

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
  Refs: [build plan](versions/v0.6/build-plan.md) chunk 17c; wave log
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
