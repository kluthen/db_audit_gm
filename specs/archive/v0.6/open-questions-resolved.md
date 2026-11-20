> **Archived 2026-11-20.** v0.6 closed (released at its release gate, G11 cleared by the owner on 2026-11-20, `v0.6-rg` merged into `main` as `fceda75`); the open-questions register's paragraph on v0.6's drafting, its closed entries O21, O22 and O32, O251 and O269 (closed at this pass by D602, both refusals built), and its three v0.6 sections ("the network overview", "fake aging", "PostgreSQL 19": O260 to O268, O271, O272, O292, O294, O295), verbatim at this pass; and O135 with its section, verbatim as it last stood (taken from git: `090ea1f`, the commit before `cb044bb` removed it). The `##` headings marked "(from ...)" are this pass's, naming where each block stood in the register. Only resolved IDs are here; every question still open, O298 and O299 among them, stays in the live register. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan and the two drafts archived in the same pass were repaired to their archived paths (`archive/v0.6/`), still written from `specs/`.

## Resolved during v0.6 (from the register's introduction)

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

## Closed entries (from "Faults and aging")

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
  [archive/v0.6/fake-aging.md](archive/v0.6/fake-aging.md); kept here
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

## Closed entry (from "Game and feedback")

- **O32** (**closed**, D503: English everywhere, the website and the
  feedback included; a scenario language option later, not in v0.6;
  kept here until v0.6's archive) (later) — Language of player-facing
  material (story, starter documentation, issues, feedback).

## Closed at v0.6's archive (from "v0.5: carried forward")

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

## v0.6: the network overview

O260–O268, raised by the network overview's first draft (D483–D485),
closed on 2026-11-13 as recommended (D487, D488); each question's text
is on
[archive/v0.6/network-overview.md](archive/v0.6/network-overview.md#questions-for-the-owner).
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
[archive/v0.6/fake-aging.md](archive/v0.6/fake-aging.md#questions-for-the-owner).
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
  gate G13 of the [build plan](archive/v0.6/build-plan.md)) — The form of f8's
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
(gate G15 of the [build plan](archive/v0.6/build-plan.md)), never the
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
