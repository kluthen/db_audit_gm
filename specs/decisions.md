# Decisions

Append-only. Look an entry up by its ID; don't read the log whole. Each
entry links to the document that now states the ruling.

Archived, verbatim, with where each one now lives in its milestone's
README:

- D1–D54 (v0.1):
  [archive/v0.1/decisions-D1-D54.md](archive/v0.1/decisions-D1-D54.md),
  mapped in [archive/v0.1/README.md](archive/v0.1/README.md#where-it-now-lives).
- D55–D106 (v0.2):
  [archive/v0.2/decisions-D55-D106.md](archive/v0.2/decisions-D55-D106.md),
  mapped in [archive/v0.2/README.md](archive/v0.2/README.md#where-it-now-lives).
- D108–D112 and D114–D189 (v0.3):
  [archive/v0.3/decisions-D108-D112.md](archive/v0.3/decisions-D108-D112.md)
  and [archive/v0.3/decisions-D114-D189.md](archive/v0.3/decisions-D114-D189.md),
  mapped in [archive/v0.3/README.md](archive/v0.3/README.md#where-it-now-lives).
- D190–D191, D193–D195, D197–D200, D202–D231, D239–D247, D252–D258,
  D281–D284, D305 and D310–D313 (v0.4), one file per range in
  [archive/v0.4/](archive/v0.4/README.md#archived-files), mapped in
  [archive/v0.4/README.md](archive/v0.4/README.md#where-it-now-lives).
- D107, D113, D192, D196, D201, D233–D238, D248–D251, D260–D280,
  D285–D304, D306–D309 and D314–D476 (v0.5), one file per range in
  [archive/v0.5/](archive/v0.5/README.md#archived-files), mapped in
  [archive/v0.5/README.md](archive/v0.5/README.md#where-it-now-lives).

Archived IDs keep their meaning and are cited as they are. Never issued:
D232 and D259 (v0.4); D337, D341, D359, D371, D392, D429, D430 and D470
(reserved during v0.5 and never used); D477–D479 (set aside for v0.5's
close, unused at its archive); D526 (reserved during v0.6's wave 2,
never used). The live entries below are v0.6's, from
D480 on. Take the next number from `doc-ids`; no ID is reused.

- **D480 (2026-11-13, owner ruling, relayed by the coordinator): The
  entry point is the bastion's web front of one game, for the players:
  a simple home page linking every site of the game; nginx kept; no
  front above several games.** Grafana, Prometheus, health and the
  handouts now, later the fictional provider's console and others. "Nor
  is it expected any time soon": the common Caddy, the setup's homepage,
  its placement, per-game passwords behind it and its teardown are
  dropped; D224's "common caddy to handle multiple front" meant one
  game's sites, and had been over-read. Closes O135. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#the-games-home-page-d480).
- **D481 (2026-11-13, owner ruling, same relay): No reporting tool.**
  "They could just write their report outside the bastion. it's their
  problem." D333's corrected register file loses its target: a register
  fault stays resolved by *propose*, the corrected entry in the report.
  The v0.5 master spec (2, 24) and its data register page (3, 4)
  still name the tool; this entry supersedes them. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#the-rulings-of-2026-11-13),
  [versions/README.md](versions/README.md).
- **D482 (2026-11-13, owner ruling, same relay): No network map or
  diagram for now.** The game is one private network, third parties
  aside. A dedicated map becomes mandatory with the fictional provider
  (several networks, security groups). Now in:
  [versions/README.md](versions/README.md#beyond-v10-a-fictional-cloud-provider-d205).
- **D483 (2026-11-13, owner ruling, same relay): A network overview
  page, extracted from the player README and linked from the home
  page.** Nodes go by their Docker name, never an IP; each links to
  Grafana's Node health dashboard, which reads the customer's
  Prometheus, so the customer's monitoring faults show through. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md).
- **D484 (2026-11-13, owner ruling, same relay): The network overview
  is customer documentation, a player handout that may be incomplete or
  wrong, like the data register (D330).** Answers O21 for this page;
  O21 narrowed to the other starter files. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#the-rulings-d483d485).
- **D485 (2026-11-13, owner ruling, same relay): What a node's entry
  holds, ideally:** its Docker name, system, role, description, sizing,
  the players' access (read-only, write, none), its main applications
  with versions, its known users (applications mostly, people possible),
  third parties, background tasks and backup strategy. The node-centric
  view of the data register's facts. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#the-rulings-d483d485).
- **D486 (2026-11-13, the owner, agreeing with the coordinator): O251's
  loader refusal is built in v0.6's first chunk that touches
  `tools/gm/model.py`.** O251 stays open until built. Now in:
  [open-questions.md](open-questions.md) O251.
- **D487 (2026-11-13, owner ruling, "ok with proposed", relayed by the
  coordinator): O260–O267 closed as recommended.** "Your access" is the
  game's rule, never a deviation; the bastion a fixed note; third
  parties a closing table by hostname; the format additions; a `node`
  variable on Node health; the overview and the register planted
  independently; *propose*, M, `docs-overview-*`; the home page's two
  lists, the node table leaving the README. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#questions-for-the-owner).
- **D488 (2026-11-13, same ruling, with the owner's clarification):
  O268 closed as recommended: a handout describes the design, the value
  before a planted fault changed it; every handout is a static snapshot
  of the mission's start.** Generated once at setup, never re-rendered
  in play; only the live tools it links to follow the system; a fix
  leaving it out of date is expected, never a fault or a GM check. Holds
  for the data register too. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md#2-one-entry-its-fields-and-their-sources).
- **D489 (2026-11-15, owner direction after the fake aging test,
  relayed by the coordinator): Two aging modes: real aging stays for
  extended games, fake aging joins it for quick games.** "a quick game
  can still be started, and extended one remains available with true
  aging." The GM chooses the mode per game. Drafted for v0.6. Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#1-the-two-modes).
- **D490 (2026-11-15, same direction): Every fixable caveat of fake
  aging is fixed; every one that can't be is documented.** "your few
  caveat about fake aging that can be fixed must be, those that can't
  must be documented." Now in:
  [fix list](versions/v0.6/fake-aging.md#3-the-fix-list-d490),
  [limits](versions/v0.6/fake-aging.md#4-documented-limits).
- **D491 (2026-11-15, same direction): A fake-aged game curates its
  faults so that none relies on a known limit of fake aging.** Each
  fault declares its support for fake aging; `gmctl` refuses a
  `real-only` or unassessed one in a fake game. Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#2-fault-eligibility).
- **D492 (2026-11-15, spec-writer, reading D489–D491): The bar is "a
  student doing the audit doesn't stumble on the fake", not "a hunting
  DBA can't prove it".** The latter needs fake time, ruled out, and the
  direction accepts documented limits that remain; D490 already sets
  the fixes, so the bar sets only what the verification checks. The
  owner may reopen it. Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#6-the-bar-d492).
- **D493 (2026-11-15, follows D489): O22 closed.** Fake aging is forged
  Prometheus history and a compressed fill before the game, never a
  sped-up or fake clock; D114 and D132 stand for the real mode and for
  play. D125's volume copy is no longer planned, its use O232's. Now
  in: [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#8-impact-on-earlier-rulings-and-documents).
- **D494 (2026-11-15, owner ruling, relayed by the coordinator): The
  players are never told about the aging process**: not during the
  game, not in the feedback, not after the final answer. "players are
  never meant to be told about aging process." Against the
  recommendation (feedback after the final answer). A report naming a
  tell is answered in-world only. Closes O271. Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#41-the-players-are-never-told-d494).
  *Refined by D496 (2026-11-16).*
- **D495 (2026-11-15, same ruling, "agreed for O272"): v0.6 makes the
  shop and the campaign fake-ageable, the campaign's f10 `real-only`;
  the clinic later.** Closes O272. Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#24-starting-estimate-to-be-measured).
- **D496 (2026-11-16, owner ruling, relayed by the coordinator; refines
  D494): Never during the game; once it is concluded, a tell the report
  names may be explained, the fake aging included.** "The game is
  already concluded, thus it's okay." The customer side stays in-world;
  the teaching part explains the reported tell. With no tell reported
  the feedback doesn't mention aging (spec-writer's reading of "if the
  tell has been reported"). Now in:
  [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md#41-what-the-players-are-told-and-when-d494-d496).
  *Owner ok, 2026-11-16, relayed by the coordinator, on its three
  readings: concluded once the final answer is processed (no aging
  words before, D126's confirmation included); a tell reported is a
  named observation, whatever its cause; none reported, no mention.*
- **D497 (2026-11-16, same ruling; refines D9): The GM's appreciation
  of a report has two parts: the customer side, an in-world
  assessment, then a teaching moment** (what was missed and how it
  could have been seen, what was found, what was identified but not
  explained, why things looked as they did, from faults or aging).
  D9's content becomes the first part; D13 and D18 untouched. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#the-gms-feedback-d497).
- **D498 (2026-11-16, owner ruling "agreed", relayed by the
  coordinator, on the v0.6 page's pending items 1–7): fake aging's
  proposals accepted as written:** the mode and the GM's steps, the
  fault format, the tail, the calibration, the fix list with its
  additions and its departure (table statistics kept), the limits'
  documentation, the product's shape, the verification; with 4.1's
  reading of an unsupported suspicion (no tell, no explanation). Now
  in: [versions/v0.6/fake-aging.md](versions/v0.6/fake-aging.md).
- **D499 (2026-11-16, same ruling, item 8): the feedback's customer
  side comes first, in the GM's voice from the customer's point of
  view;** D9's content becomes it, D13 and D18 untouched. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#the-gms-feedback-d497).
- **D500 (2026-11-16, same ruling, items 9–12): the network overview's
  remaining details accepted as written:** the page's shape and
  header, the register linked by construction, the `network-overview`
  skill and which scenarios need it, the traps N1–N10. Now in:
  [versions/v0.6/network-overview.md](versions/v0.6/network-overview.md).
- **D501 (2026-11-16, same ruling, items 13–16): the v0.6 page's scope
  items:** the website's content; `jq` and `tmux` added to the
  bastion, nothing heavier; the stack's reports as a "Reports" site;
  a live status page per partner with a `player_doc`, its design the
  master spec's. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#in-scope).
- **D502 (2026-11-16, same ruling, item 17): only the handouts
  describing the system (the data register, the network overview) may
  carry a planted inaccuracy;** never the README, the rules, the data
  policy or `partners.md`; the story and issues only as the customer's
  belief. Closes O21. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#pending-owner-rulings-before-consolidation).
- **D503 (2026-11-16, same ruling, item 18): player-facing material is
  in English,** the website and the feedback included; a scenario
  language option later. Closes O32. Now in:
  [versions/v0.6/README.md](versions/v0.6/README.md#pending-owner-rulings-before-consolidation).
- **D504 (2026-11-16, spec-writer default on the review's finding,
  reconciling D150 with D494/D496; owner may reopen): the GM asks once,
  with the time available, whether the initiator will play;** if they
  may, it offers a quick or an extended game by duration only, never
  naming the technique; an initiator who won't play may be told the mode.
  Now in: [gm-stance.md](gm-stance.md) "At setup"; [fake aging](versions/v0.6/fake-aging.md#11-choosing-the-mode) 1.1.
- **D505 (2026-11-16, spec-writer default on the review's finding): N9,
  the network overview's absence, dropped;** the page is always present
  where required, no `{absent: true}`. Its absence would remove the
  access rule (O260) and leave the README pointing nowhere (O267). Now
  in: [network-overview.md](versions/v0.6/network-overview.md#5-deviations-as-faults) 4, 5.
- **D506 (2026-11-16, spec-writer default on the review's finding): a
  fake game's restart item is a per-game restart record,
  `local/<playground>/fake-aging.yaml`,** GM-side, written by `gmctl`;
  the scenario format stays unchanged. Now in:
  [fake aging](versions/v0.6/fake-aging.md#21-the-fields) 2.1.
- **D507 (2026-11-16, spec-writer default on the review's findings):
  the monitoring starts in the maintenance restart, whose instant is
  the anchor; the early check runs halfway through the tail, by H − 1 h,
  never before the history import.** A later start would stand apart as
  a tell. Now in: [fake aging](versions/v0.6/fake-aging.md#13-the-gms-steps-in-fake-mode) 1.2, 1.3.
- **D508 (2026-11-16, spec-writer, on the review's findings): P0 binds
  the virtual instant in the fill's SQL and the functions it calls;
  `pg_cron` stays off in the fill. If P0 fails, the campaign's short
  check keeps f1, f8, f9.** Now in:
  [fake aging](versions/v0.6/fake-aging.md#24-starting-estimate-to-be-measured) 2.4, 9.
- **D509 (2026-11-16, spec-writer default on the review's findings):
  the blind reads and the GM-behaviour checks (the two-part feedback,
  no aging word before the game is concluded, a reported tell
  explained, no mention without one) join v1.0 gating;** the gate keeps
  short checks. Now in: [versions/README.md](versions/README.md#v10-gating).
- **D510 (2026-11-16, spec-writer, settling O269 as main's text
  directs): a loader refusal, each selected `seed-file` instance's
  `seed_changes` lines found in its node's copy, with a unit test,**
  built beside O251's. The skill's check is the GM reading by hand.
  Now in: [versions/v0.6/README.md](versions/v0.6/README.md#in-scope).
- **D511 (2026-11-16, spec-writer, on the review's findings): Reports
  are a `~/reports/` folder on the bastion served at `/reports/`,
  sandboxed, owned by `bastion`; the short tests of the bastion's
  items listed; a scenario without an overview keeps its README node
  table.** Now in: [v0.6](versions/v0.6/README.md#short-tests-d314-d511);
  [network-overview.md](versions/v0.6/network-overview.md#6-on-the-bastions-front) 6.
- **D512 (2026-11-16, spec-writer, on the review's findings): the
  drafts' text corrections:** the tail's wording for a fault planted in
  the tail, the stale draft pointers, O32 shown closed on the v0.6
  page, the v1.0 gating additions no longer `(proposed)` (D498). Now
  in: [fake aging](versions/v0.6/fake-aging.md#22-the-tails-length) 2.2;
  [versions/v0.6/README.md](versions/v0.6/README.md).
- **D513 (2026-11-16, spec-writer, at consolidation, as D501 left it):
  the partners' status pages: a fault instance's `admitted:` marks the
  incident; render writes a root-only status file to the bastion, which
  renders the pages itself each minute; no route to a partner's node
  (D273).** Now in: [master spec](versions/v0.6/master-spec.md#76-the-partners-status-pages)
  7.6; [formats.md](formats.md) "Scenario", "Partners".
- **D514 (2026-11-16, the owner's "have a reviewer check out spec v0.6
  then consolidate"): v0.6 consolidated into its master spec and access
  model, for the owner's review;** the access model a delta on v0.5's,
  which stays in force for the rest. Drafts kept as the working record.
  Now in: [versions/v0.6/master-spec.md](versions/v0.6/master-spec.md),
  [versions/v0.6/access-model.md](versions/v0.6/access-model.md).
- **D515 (2026-11-16, owner ruling "agreed for both question, you may
  proceed on the build plan", relayed by the coordinator): every brick
  takes a new version in v0.6, since `base:` changes every `brick.yaml`
  (O263):** `bastion` 0.6.0, `grafana` 0.4.0, `scheduler` 0.4.0, a patch
  bump for the others, every scenario repinned. Now in:
  [master spec](versions/v0.6/master-spec.md#68-versions-and-pins) 6.8.
- **D516 (2026-11-16, same ruling): D504 confirmed:** an initiator who
  may play hears only "quick game" or "extended game", by duration, and
  never the technique. Now in:
  [master spec](versions/v0.6/master-spec.md#92-the-initiator-who-also-plays) 9.2.
- **D517 (2026-11-16, same ruling): v0.6's master spec and access model
  approved, the points marked "(default, for review)" standing as
  written** (the owner raised no objection and asked for the build
  plan); the marks removed. Now in:
  [master spec](versions/v0.6/master-spec.md) (status, 18),
  [access model](versions/v0.6/access-model.md).
- **D518 (2026-11-16, owner approval "i aprove the plan", relayed by
  the coordinator): v0.6's build plan approved, κ = 2;** G1 cleared,
  `v0.6-spec` merged into `main` by the coordinator. Now in:
  [build plan](versions/v0.6/build-plan.md) (header, "Gates").
- **D519 (2026-11-16, same answer, "i don't want to keep the archive in
  the git, but it can go there"): no reference data in git;** the whole
  `results/` folder archived outside git at the proposed path, git
  keeping only its pointer (README, per-file manifest); tests needing it
  skip when it is absent. Now in:
  [master spec](versions/v0.6/master-spec.md#123-the-reference) 5, 12.3;
  [build plan](versions/v0.6/build-plan.md) chunks 1, 8, 11, 12.
- **D520 (2026-11-16, same answer, "you may stop the real aging game
  once its usefullness is spent"): `fa-real` torn down by the wave
  driver once chunk 1 has merged and the archive verifies,** no later
  chunk needing the live game (8, 11, 12 read the saved data). Now in:
  [build plan](versions/v0.6/build-plan.md) G12.
- **D521 (2026-11-16, spec-writer, capture W1's preflight correction 1,
  accepted by the wave driver): O269's lines are declared, an optional
  `seed_changes[].lines` the loader looks for; a change without it stays
  the GM's to read.** Prose `change:` and example `material:` gave no
  form a program finds. Now in: [master spec](versions/v0.6/master-spec.md#610-the-loaders-new-checks)
  6.3, 6.9, 6.10; [formats.md](formats.md) v35 "Injection"; [build plan](versions/v0.6/build-plan.md) chunk 3.
- **D522 (2026-11-16, spec-writer, capture W1's preflight correction 2):
  `admitted.from` is `T0` or `handover-<N>h`, hours only, as a planting
  moment;** 6.9's `h|m` comment was the outlier. Now in:
  [master spec](versions/v0.6/master-spec.md#69-shapes-of-the-new-fields) 6.9.
- **D523 (2026-11-16, owner ruling "Adopt the cover (Recommended)",
  relayed by the wave driver after chunk 8): a routine pinning its own
  `search_path` is covered for the fill's span and restored exactly,
  on failure too; its catalog row-version tell a documented limit;** the
  campaign's f4 and f7 back to `supported`, their calibration confirming.
  Refines D508 and capture W1 item 8 ("session settings only"). The fill
  finds such routines itself (spec-writer's default for the form): a
  declared list is the omission chunk 8 hit. Now in:
  [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4, 9.8, 9.10, 18.
- **D524 (2026-11-16, spec-writer, placing D523): chunk 15 inserted in
  wave 2 to build the cover,** before the wave's start, so W2's capture
  covers it; a chunk of its own rather than inside 9 (already the
  wave's largest) or 11 (wave 3, which needs it done). Now in:
  [build plan](versions/v0.6/build-plan.md) chunk 15, "Waves".
- **D525 (2026-11-16, spec-writer, on chunk 8's risk): in a fake game
  `load-data` and the plantings at T0 run on the virtual T0's clock**
  (fix 11), so the seed ends at the virtual T0 instead of overlapping
  the fill's span; 9.3 already made the virtual T0 a real game's T0,
  9.4 said nothing of the seed's clock. Now in:
  [master spec](versions/v0.6/master-spec.md#99-the-fix-list) 9.4, 9.9;
  [build plan](versions/v0.6/build-plan.md) chunk 9.
- **D527 (2026-11-17, owner answer "Virtual instant (Recommended)",
  relayed by the wave driver after capture W2): the fill's pause
  plantings run with D525's session means at the pause's virtual
  instant** (`gm.vclock` and `gm_vclock` first on the path, through
  `PGOPTIONS`), not on the real clock, so a planting at virtual 02:00
  writes 02:00. The same answers confirmed D523 ("Auto-discover") and
  D525 ("Include plantings") as written. Now in:
  [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4 step 5, 9.9 fix 11; [build plan](versions/v0.6/build-plan.md) chunk 15.
- **D528 (2026-11-17, spec-writer, capture W2's preflight correction 7,
  accepted by the wave driver): in a fake game an ineligible instance is
  refused, not the game,** which renders and runs without it, the
  refusal in the restart record; 6.9's `refused:` and 12.2's "f10
  refused" already read so. Now in:
  [access model](versions/v0.6/access-model.md#7-denial-behaviour) 7.
- **D529 (2026-11-17, spec-writer, capture W2's preflight correction 6):
  in DDL run under fix 11's means, `now()` and its kin are written
  `pg_catalog.`;** a stored default or view would otherwise bind the
  shim's function, and the shim's drop would take it. Now in:
  [master spec](versions/v0.6/master-spec.md#99-the-fix-list) 9.9 fix 11.
- **D530 (2026-11-17, spec-writer, chunk 9a's blocker 1): `gm_vclock`
  goes right before `pg_catalog` on every path P0 sets** (the seed's,
  the plantings', the fill's sessions, the cover), at the path's end
  when it doesn't name `pg_catalog`. First on the path it was the
  creation schema: an unqualified `CREATE` failed or landed in the shim,
  dropped with it (9a's scratch load; the clinic's partition routines
  under the cover). The checked drop also refuses objects inside the shim.
  Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4, 9.9 fix 11; [build plan](versions/v0.6/build-plan.md) chunk 9.
- **D532 (2026-11-17, spec-writer, chunk 9a's blocker 2): a
  `tail_covers` instant counts from one floor (an hour) before it,** so
  the shop's full selection keeps 9.8's three hours, anchor 11:00. 9.6
  as written gave two hours with the noon instant at the restart's own
  minute, which the research's run sheet (10d1bc6) rejected for that
  reason; the approved figure is the intent, the rule is corrected. Now in:
  [master spec](versions/v0.6/master-spec.md#96-the-tails-length) 9.6.
- **D533 (2026-11-17, spec-writer, chunk 9a's blocker 3): `fixture-fill`'s
  f8 becomes a scenario-local fixture fault,** `fixture-dropped-index`
  (as in `fixture-v06-refusals`), its `aging.fake` and `history:` the
  fixture's own, so 9b's fake run still plants it at its pause; the
  catalogue's `pg-join-index-missing` stays unassessed for chunk 11.
  Rejected: leaving f8 out (chunk 8's pause check lost), a provisional
  assessment on the catalogue fault (chunk 11's), a harness override.
  Now in: [build plan](versions/v0.6/build-plan.md) chunk 9.
- **D534 (2026-11-17, spec-writer, gates G10.1 and G10.2 after wave 2's
  gate): waves 1 and 2's forms written as built,** each checked against
  the code on `v0.6-w2`; none contradicts the spec, which they complete.
  Now in: [formats.md](formats.md) v36 "Scenario", "Layout", "Local
  implementation"; [master spec](versions/v0.6/master-spec.md#67-the-local-implementation)
  6.7, 6.9, 9.4 step 1, 9.9 fix 8.
- **D535 (2026-11-17, spec-writer, confirming chunk 9's choice the wave
  driver accepted): `gmctl clean-restart` is refused before the planned
  anchor,** since the fill's rows run up to it; the restart's measured
  instant then starts the tail and the earliest hand-over counts from
  it. Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4 steps 6 and 9, 6.9.
- **D536 (2026-11-17, spec-writer, confirming chunk 9's choice the wave
  driver accepted): the statistics reset is the maintenance's step before
  the stop,** so `stats_reset` falls seconds before the postmaster's
  start; statistics survive a clean shutdown, so it reads as the
  maintenance resetting them, and no session is needed after the start.
  9.9 fix 2's "there" meant the restart, not the deploy. Now in:
  [master spec](versions/v0.6/master-spec.md#99-the-fix-list) 9.4 step 6,
  9.9 fix 2, 9.10.
- **D537 (2026-11-17, spec-writer, chunk 7's note routed to G10.2): the
  scenario document shows each instance's `admitted:`** beside its
  planting moment; no section had it, so a GM learnt what a status page
  will say only from `scenario.yaml`. Placed in chunk 12, which already
  revises the skill and regenerates the documents. Now in:
  [master spec](versions/v0.6/master-spec.md#76-the-partners-status-pages)
  7.6; [build plan](versions/v0.6/build-plan.md) chunk 12.
- **D538 (2026-11-18, owner ruling after wave 2's gate): every fixture's
  scenario document is regenerated in v0.6** from the current template,
  through the `scenario-document` skill, never by hand; the gate found
  the older ones predating it ("Third parties" missing in 11, "Composition"
  in 12, wording). A chunk of its own after chunk 12, whose template
  change it waits on and whose size it would break. Now in:
  [build plan](versions/v0.6/build-plan.md) chunk 16.
- **D539 (2026-11-18, owner approval of G9.1's proposal): `postgres`
  0.5.1 re-pins `pg_cron` to 1.6.8-1.pgdg13+3 and `pgaudit` to
  18.0-3.pgdg13+2**, PGDG's rebuilds against 18.7 (CVE-2026-6460's
  extension half). pgAudit 18.1 (upstream 2026-11-17) changes which audit
  lines are logged: a later game-content decision, not in v0.6 unless the
  owner says so. Now in: [build plan](versions/v0.6/build-plan.md) G9.1.
- **D540 (2026-11-19, spec-writer, capture W3's preflight correction 2):
  the players keep their shell on the Prometheus node; the TSDB folder
  (`prometheus:prometheus`, `0750`) keeps the imported blocks from it,**
  and the import keeps that owner and mode. f10's fix edits
  `prometheus.yml` there, so "no shell (to verify)" was wrong. Now in:
  [master spec](versions/v0.6/master-spec.md#910-documented-limits)
  9.10, 18; [build plan](versions/v0.6/build-plan.md) chunks 10, 12.
- **D541 (2026-11-19, spec-writer, capture W3's preflight correction 3):
  Prometheus' own series showing the import are a documented limit,**
  not covered by the story, no curation (the tail's samples can't be
  rewritten without the admin API); the restart record's `explains`
  carries it. Now in: [master spec](versions/v0.6/master-spec.md#910-documented-limits)
  9.10; [build plan](versions/v0.6/build-plan.md) chunk 10.
- **D542 (2026-11-19, spec-writer, capture W3's preflight correction 8):
  a GM-run game never leaves refused an instance a handout names;** the
  GM plays a variant without it and its issue, plays real, or declines,
  render's refusal (D528) the safety net. 9.1's "replaces ... or
  proposes another" covers the variant: no owner question. Now in:
  [master spec](versions/v0.6/master-spec.md#91-two-modes-and-choosing-one)
  9.1, 9.8, 12.2; [access model](versions/v0.6/access-model.md#7-denial-behaviour) 7.
- **D543 (2026-11-19, spec-writer, capture W3's preflight correction 9):
  `suppressed_by` drops an entry from the hiding instance's planting
  onward,** not over the whole span: the campaign's f5, planted in the
  tail, hides f4's and f7's trails only from then. Now in:
  [master spec](versions/v0.6/master-spec.md#95-fault-eligibility) 6.3,
  9.5; [formats.md](formats.md) v38.
- **D544 (2026-11-19, spec-writer, capture W3's preflight correction 10):
  the scenario document's "Fake aging" section carries the setup's
  measured time, deploy to restart,** and a quick game's stated duration
  is that time plus the selection's tail; no GM-facing document carried
  it. Now in: [master spec](versions/v0.6/master-spec.md#92-the-initiator-who-also-plays)
  9.2, 9.10; [build plan](versions/v0.6/build-plan.md) chunks 12, 13.
- **D545 (2026-11-19, owner request, relayed by the coordinator): a game
  assistant, a player-side helper distinct from the GM**, with no access
  to the game's background: player handouts and basic bastion activity
  only, never a database, no file beyond the report and its drafts
  (tracking only when asked), DBA and basic dev knowledge, SQL written
  unverified for the players to run, a reminder of the breach when a
  player hands it database snippets. Not in v0.6 (O274). Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D546 (2026-11-19, owner ruling, same relay): the assistant is a skill
  in this repository, `/game-assistant`, on trust,** invoked at the
  repository root as `/game-master` is; its off-limits material is so by
  stance, as D13's light enforcement. Rejected: an exported player
  workspace with deny rules; Claude Code installed on the bastion. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 1, 3.
  *Amended by D559 (an agent, not a skill) (2026-11-19).*
- **D547 (2026-11-19, owner ruling, same relay): the bastion link is a
  fixed, read-only set of reads, never a shell; the assistant's files are
  local,** the players copying the report to `~/report.md`, where the GM
  fetches it. A shell as `player` reaches every database (`~/.pgpass`).
  Rejected: writing into the bastion's home; paste only. The mechanism is
  O275, the set O276. Now in: [game-assistant.md](versions/v0.7/game-assistant.md) 4, 6.
  *Amended by D550 (the player's access, no fixed read set) and D554 (the
  report's location free) (2026-11-19).*
- **D548 (2026-11-19, spec-writer, chunk 11a's measured deviation): the
  shop's f9 carries no `suppressed_by` over f4,** since it hides f4 only
  in state and logs: the exporter has no per-table series and run R
  shows f4's `max_tx_duration` sawtooth throughout. The shop's f5 has no
  `daily_spike` (R holds no noon-run sample). Now in: [master spec](versions/v0.6/master-spec.md#98-the-scenarios-covered-and-the-starting-estimates)
  6.9, 9.8; [build plan](versions/v0.6/build-plan.md) chunk 11.
- **D549 (2026-11-19, owner ruling, relayed by the coordinator): v0.7,
  the game assistant its subject** ("it'll be v0.7"), after v0.6 and
  before v1.0; the repository's game mode (D555–D557) joins it. Closes
  O274. Now in: [versions/README.md](versions/README.md),
  [versions/v0.7/README.md](versions/v0.7/README.md).
- **D550 (2026-11-19, owner ruling, same relay): the assistant has the
  player's access, on trust,** amending D547: the bastion as `player`,
  the web front, the handouts; no door, no `gmctl` verb, no key. Two
  trust lines: in the assistant (no database, no write beyond its report
  and drafts, reads only what serves its purview) and in the players
  (they don't use it to reach what they can't). Closes O275, O276. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 1, 3.
- **D551 (2026-11-19, owner ruling, same relay): the assistant is a
  coach** ("it's indeed a coach"), as recommended. Closes O277. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 10.
- **D552 (2026-11-19, owner ruling, same relay): reminders graded by
  criticality, and its own SQL minimised by design.** A schema widens the
  attack surface, "still bad"; high items draw the full reminder, medium
  ones a lighter one naming the risk, after the owner's notes
  (`/home/bastien/audits/bluebox-lab/docs/ADAPTATION.md` 7.5, restated,
  not copied). Closes O278. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 5, 7.
- **D553 (2026-11-19, owner ruling, same relay): the assistant is always
  available** ("it's just not called upon when not needed"); no
  initiator switch, nothing in the hand-over. Closes O279. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D554 (2026-11-19, owner ruling, same relay): no communication
  between the assistant and the GM, and the report's location free,**
  amending D547: the GM isn't told; how the report reaches the GM is the
  players' affair; `play/<game>/` a default only. Closes O280, O281. Now
  in: [game-assistant.md](versions/v0.7/game-assistant.md) 6, 9.
- **D555 (2026-11-19, owner ruling, same relay): the GM leaks no game
  data through memory;** any GM memory is its own, kept to its section
  of the repository. Mechanism O287. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 4.
- **D556 (2026-11-19, owner ruling, same relay): dev mode and game mode;
  only game mode is pushed,** with a `CLAUDE.md` and a `README.md`
  curated for playing. `origin/main` (7a62c54) was pushed in dev mode;
  the mechanism is O286. Now in: [game-mode.md](versions/v0.7/game-mode.md)
  1, 3.
- **D557 (2026-11-19, owner ruling, same relay): a game is played from a
  fresh clone elsewhere,** never from the development checkout, whose
  automatic memory holds development notes. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 2.
- **D558 (2026-11-19, owner ruling, same relay): the owner's audit grid
  is informative,** "not scoped for our purpose but hints as to how to
  handle an audit"; a verbatim copy stored in the tree; the assistant may
  draw on it, never bound to it; a game-scoped English rewrite optional
  and later. Closes O283, O284, O285. Now in:
  [references/grille-audit-pg.md](../references/grille-audit-pg.md),
  [game-assistant.md](versions/v0.7/game-assistant.md) 11.
- **D559 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant is an agent, not a skill,** amending D546: one definition for
  Claude Code and one for OpenCode, allowed no skill (no `Skill` in its
  tools, `skill: deny`), started by name, still on trust. Asked "can't we
  limit the skill this agent is allowed to use ?", the owner took
  dev_team's agent pattern. Now in: [agents.md](versions/v0.7/agents.md)
  1, 5; [game-assistant.md](versions/v0.7/game-assistant.md) 1.
- **D560 (2026-11-19, owner ruling, same relay): the GM is an agent too**
  ("the GM should also be an agent as well"), allowed its four helper
  skills; today's `game-master` skill becomes its core file plus
  workflow skills and references, split at build in a v0.7 chunk after
  v0.6's merge. D6 and D33 hold: a GM session is one started as the GM
  agent. Now in: [agents.md](versions/v0.7/agents.md) 1, 4, 6, 7.
- **D561 (2026-11-19, owner ruling, same relay): Claude Code and OpenCode
  both supported** ("Ensure both claude code and opencode are
  supported"): each agent defined in both dialects, kept in step by hand
  with no automated sync, as dev_team does. Now in:
  [agents.md](versions/v0.7/agents.md) 1–3.
- **D562 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant has no web access** ("no web access"), as recommended: no
  `WebFetch` or `WebSearch` in its Claude Code tools, `webfetch: deny`
  and `websearch: deny` in OpenCode. Closes O289. Now in:
  [agents.md](versions/v0.7/agents.md) 5.
  *Superseded by D563 (2026-11-19).*
- **D563 (2026-11-19, owner ruling, relayed by the coordinator): the game
  assistant has web access,** superseding D562: `WebFetch` and
  `WebSearch` in its Claude Code tools, `webfetch` and `websearch`
  allowed in OpenCode. "we may have to handle weird version and such,
  and i would prefer the assistant to provide TRUE indications or the
  ability to check should the player report something different from
  expectations." The leak D562 guarded against is held by stance
  (GA24, GA25, proposed). O289 stays closed, by this entry. Now in:
  [agents.md](versions/v0.7/agents.md) 5;
  [game-assistant.md](versions/v0.7/game-assistant.md) 2.
- **D564 (2026-11-19, owner ruling, relayed by the coordinator): `main`
  is the game branch,** what players and GMs clone; a side dev branch
  holds the development environment; a dedicated dev-side skill is the
  only way `main` is updated. "actually the main branch should be the
  "game" branch, and a side dev branch should hold dev enviroment."
  Supersedes MD1, the tracked files as game mode. Closes O286. Its
  proposals MD5–MD9 and O290 follow. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 1, 3.
- **D565 (2026-11-19, owner ruling, same relay): automatic memory off in
  game mode,** as recommended (MD2): game mode's committed
  `.claude/settings.json` sets `autoMemoryEnabled: false`, and the GM's
  memory is the game's local implementation; OpenCode's side verified
  at build. Closes O287. Now in:
  [game-mode.md](versions/v0.7/game-mode.md) 4.
- **D566 (2026-11-19, owner ruling, same relay): v1.0 gating runs after
  v0.7,** as recommended, and the game assistant's stance items join its
  stance check-list. Closes O288. Now in:
  [versions/README.md](versions/README.md#v10-gating).
- **D567 (2026-11-19, owner ruling, same relay: every pending proposal
  accepted as drafted): the assistant's actor, knowledge and purview,**
  GA1–GA8 and GA23: an actor at consolidation; scripts read, never
  written; the game's own scripts known from the player documentation;
  the allow-list and the off-limits list; no `gmctl` or `docker`; the
  partners' credentials never repeated; handouts as the customer's
  claims; its purview on the bastion; reads through the player's shared
  SSH connection. Now in: [game-assistant.md](versions/v0.7/game-assistant.md)
  1–3.
- **D568 (2026-11-19, same ruling): its SQL, reminders and bounds,** GA9,
  GA10, GA13 and GA22: queries labelled unverified, read-only first,
  changes flagged with the node's write policy; the graded reminder every
  time, a paragraph the first, the paste still used; "propose, don't do"
  beyond each issue's resolution and write policy. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 4, 5, 7.
- **D569 (2026-11-19, same ruling): its stance with the game and the GM,
  and on the web,** GA14, GA15, GA17–GA19 and GA24–GA27: no talk of the
  game's mechanics or the aging; its opening and the bastion's player
  page telling it from the GM; never the GM's session; files in English,
  the conversation in the player's language; nothing of the game in a
  query or URL, never this project's material, sources cited, the
  in-world stance on the web. Now in:
  [game-assistant.md](versions/v0.7/game-assistant.md) 2, 8, 9, 12.
- **D570 (2026-11-19, same ruling): the skills' listing,** MD3 and MD4:
  the assistant's session-only `skillOverrides` hide the GM's skills;
  the build's empirical check in both tools settles the listing, and the
  helpers' descriptions are rewritten neutral if it still leaks. Closes
  O282. Now in: [game-mode.md](versions/v0.7/game-mode.md) 5.
- **D571 (2026-11-19, same ruling): the agents' definitions,** AG1–AG6:
  each agent started by name, no default agent; the assistant's and the
  GM's tools and permissions in both dialects; the GM's core file and
  workflow skills; the empirical check; the GM's session settings,
  generated at each launch by a launcher. Now in:
  [agents.md](versions/v0.7/agents.md) 4–7.
- **D572 (2026-11-19, spec-writer, closing the independent review of
  v0.7's drafts, REJECT, ten findings): the review's closures,** each
  following from an owner ruling. The assistant runs on the player's
  side, never on a machine holding the GM's local implementation unless
  it is the player's own (from D550: the player's access, not the GM's
  machine's). It reads neither the web front nor the home `partners.md`
  and is handed no password; the shell history reaches it filtered of
  credentials. Its definition names no aging word or game mechanic and
  `publish-main` scans it (the drafts' GA14/GA15 wording contradicted
  the spoiler check). Every GM skill, workflow skills included, hidden
  from it and named in its settings; the handouts treated as the
  customer's claims without the GM's rule on which may be wrong; game
  mode's settings from `game-mode/settings.json`; the grid at
  `references/`; each OpenCode check given its consequence; bricks'
  `tests/` kept on `main` (two images copy them at build). Now in:
  [master spec](versions/v0.7/master-spec.md) 6.3–6.5, 6.9, 6.10, 7.4,
  7.7, 8.2, 8.3; [access model](versions/v0.7/access-model.md) 5, 9.
- **D573 (2026-11-19, owner's word, relayed by the coordinator): v0.7
  consolidated** into its master spec and access model, a delta on
  v0.6's, the game branch's shape (MD5–MD8) and where the assistant runs
  carried for review in context and confirmed by approval; formats.md
  v37, gm-stance.md v16, planes-and-access.md v20 and concept.md v17
  brought up to date; the drafts kept as the working record, the master
  spec winning where they differ. Now in:
  [versions/v0.7/master-spec.md](versions/v0.7/master-spec.md).
- **D574 (2026-11-19, owner approval, relayed by the coordinator): v0.7's
  master spec, access model and build plan v1 approved** ("approved. you
  may merge. ok"), with the points carried for review in context: the
  game branch's shape, where the assistant runs (master spec 6.3, solo
  play included, reread and kept as written) and `tools/play` refusing
  `dev` without `--dev`; `v0.7-spec` may merge into `main` after
  `doc-ids compare`. Clears G1; G2 clears at the merge. Now in:
  [master spec](versions/v0.7/master-spec.md),
  [build plan](versions/v0.7/build-plan.md).
- **D575 (2026-11-19, owner ruling, same relay): `main`'s history and
  `dev`'s remote, as recommended:** one snapshot commit on `main` per
  publish, its history never rewritten; `dev` kept off the public remote,
  a private remote optional. Closes O290; clears G5. Now in:
  [master spec](versions/v0.7/master-spec.md) 16.
- **D576 (2026-11-19, spec-writer, plan v3, from chunk 3's starting
  state): chunk 9 inserted in wave 2, rewriting the 41 Markdown links the
  carried GM docs make into `specs/` and `tools/tests/` as plain
  provenance text.** No chunk owned them; 8.2 already makes such mentions
  provenance, so 8.3's check stands. Raises O291. Now in:
  [build plan](versions/v0.7/build-plan.md) chunk 9.
- **D577 (2026-11-19, spec-writer, plan v3): `SECURITY_TODO.md` is
  dev-only,** built in chunk 7. The game-mode draft listed it; the
  consolidation dropped it. Now in:
  [master spec](versions/v0.7/master-spec.md#82-what-main-carries) 8.2;
  [build plan](versions/v0.7/build-plan.md) chunk 7.
- **D578 (2026-11-19, spec-writer, chunk 11b's measured deviations):
  the campaign's f5 carries no `suppressed_by` over f4 and f7,** whose
  trails are rows in `reporting`, `rpt.etl_runs` and logs, which no
  exporter reads (D548's case): no covered fault uses D543's rule, which
  stands, unit-tested only. A report-only node's keys are timed from a
  fill or with psql. Now in: [master spec](versions/v0.6/master-spec.md#95-fault-eligibility)
  6.9, 9.5, 9.7, 9.8; [build plan](versions/v0.6/build-plan.md) chunks 10, 11, 12, G10.3.
- **D580 (2026-11-19, spec-writer, gate G10.3 after wave 3's gate):
  wave 3's forms written as built,** each checked against the code on
  `v0.6-w3`; none contradicts the spec, which they complete (reported,
  not settled: 9.9 fix 5's `gauge_before`, which no covered fault carries).
  Now in: [formats.md](formats.md) v39 "Scenario", "Local implementation",
  "Fault definition"; [master spec](versions/v0.6/master-spec.md) 6.3, 6.7, 6.9, 9.5, 9.7, 9.8, 12.1, 18.
- **D581 (2026-11-19, spec-writer, chunk 10's choice routed to G10.3):
  the seam's join is checked on size gauges only,** within the larger of
  1 % and the tail's own largest step; `negative` holds a series the
  system keeps below zero to its own value; `empty` added. Other gauges
  are drawn from the tail's level, so no join to check. Now in:
  [formats.md](formats.md) v39; [master spec](versions/v0.6/master-spec.md#121-short-tests-only) 9.4 step 8, 12.1.
- **D582 (2026-11-19, spec-writer, capture W3 item 7 as built): a fake
  game's restart with no history rebuilds on the real clock,** refused
  instances still out, the story line and the record kept; the spec said
  only "as in a real game". From the snapshot it stays the same fake game.
  Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode) 9.4;
  [formats.md](formats.md) v39.
- **D583 (2026-11-19, spec-writer, chunk 10's choice routed to G10.3):
  one history import at a time (a run lock), and once one is recorded
  `ok` no run imports again, a failed seam included;** a failed import is
  retried by hand, its blocks removed first. So the timer's run after a
  hand run, or a second hand run, is harmless. Now in: [master spec](versions/v0.6/master-spec.md#94-the-gms-steps-in-fake-mode)
  9.4 step 8; [formats.md](formats.md) v39.
- **D584 (2026-11-19, the owner, after G10.3: "Fix in wave 4"): the
  shop's f8 (`pg-join-index-missing`) gains a measured `gauge_before` on
  `pg_database_size_bytes`, with its `# measured:` comment,** so master
  spec 9.9 fix 5 holds as written rather than becoming a limit. Chunk 12
  takes it (its shop game plays f8). The value's form raised as O292.
  Now in: [build plan](versions/v0.6/build-plan.md) v13, chunk 12, G13.
- **D585 (2026-11-19, the owner: "go with the recommended option on
  O292"): a `gauge_before` adds its `value` to the level drawn before
  the planting, instead of holding one level;** f8's is the dropped
  index's size, so the shop's size keeps the load's shape (9.9 fix 5 as
  written). Closes O292. Now in: [formats.md](formats.md) v40 "Fault
  definition"; [build plan](versions/v0.6/build-plan.md) v14, chunk 12, G13.
- **D586 (2026-11-19, the owner, on capture W4 item 2: "Scale R to
  span"): the shop's M1 comparison scales run R to the short game's
  span,** M1 dumped at the virtual T0 and at the read, each expected
  value T0 + s × (R − T0), s R's share of inserted rows in the game's
  span; insert-driven measures judged within ±3 %, the rest reported; the
  shop played as it is. Now in: [master spec](versions/v0.6/master-spec.md) 12.1; [build plan](versions/v0.6/build-plan.md) v15, chunk 12b.
- **D587 (2026-11-19, the owner, after G8's note 3: "didn't know pg19
  was out yet. that's great news. Move to pg19 everywhere."): PostgreSQL
  19 in every brick and scenario of v0.6,** the server and every client
  tool and library (libpq included, so `scheduler`, `api` and
  `health-check` leave Debian's 17), folded into the unreleased versions
  (6.8), under D396. It brings pgAudit 19.0, which carries 18.1's changes,
  so D539's deferral ends. Now in: [master spec](versions/v0.6/master-spec.md) 6.8, 7.7, 8; [build plan](versions/v0.6/build-plan.md) v16, chunks 17a to 17c.
- **D588 (2026-11-19, the owner, the same answer): zlib1g's DSA-6613-1
  (G8's note 1, the base layer, not reachable) is handled at the release
  gate:** an `apt-get upgrade` or `zlib1g` named in the Dockerfiles, all
  ten bricks, folded into the unreleased versions. Now in: [build plan](versions/v0.6/build-plan.md) v16, release gate item 2.
- **D589 (2026-11-19, spec-writer, placing D587): chunk 17 inserted in
  wave 4 before 12b, split in three:** 17a the images on 19 and every
  path, test and generated file they bind (one commit: the data path
  `/var/lib/postgresql/19/data` and the brick digests tie them); 17b
  `postgres_exporter` 0.21.1 and pgwatch 6.2.0 (G9.2's picks, D396) and
  fake aging's re-measure on 19; 17c the game's text and the faults that
  read audit lines, re-run on 19. G9.2 (preflight done, CLEAR WITH
  NOTES; its post-change half open), G14 (no game on the host relies on
  the 18 image under the reused tags), G15 (O294, O295). Now in: [build plan](versions/v0.6/build-plan.md) v16.
- **D590 (2026-11-19, spec-writer, on D587): fake aging's numbers
  measured on 18 stand, one size re-measured:** the service times,
  signatures, WAL rates and run R stay (9.7: one-off per fault version);
  M1's judged measures and M3's judged traffic are counts the workload
  drives, which the server's major doesn't move, so 12.1's comparisons
  against R still prove the fill reproduces a real day (D586). The heap
  and btree page formats are unchanged in 19, so `fixture-dropped-index`
  is re-measured on 19 (17b) as the check of f8's value from R. Chunk 12b
  reports the tail's latencies and WAL rates against the 18 files, never
  judged. Now in: [build plan](versions/v0.6/build-plan.md) v16, chunks 17b, 12b.
- **D591 (2026-11-19, the owner, on O294: the recommendation, "Known
  limit"): pgBadger 13.3's empty checkpoint section on PostgreSQL 19 is
  a known limit,** named in `postgres`' `docs/gm.md` and v0.6's release
  notes; the next pgBadger release that reads 19's lines is taken under
  D396. No fault's witness reads that section, and no fix exists
  upstream. Closes O294. Now in: [build plan](versions/v0.6/build-plan.md) v17, chunk 17c, G15.
- **D592 (2026-11-19, the owner, on O295: the recommendation, "Add the
  new setting"): every seed setting `log_autovacuum_min_duration = 0`
  sets `log_autoanalyze_min_duration = 0` beside it** (56
  `postgresql.conf` files), what those seeds feed regenerated, so the
  customers' logs keep their autoanalyze lines on 19 as designed.
  Closes O295. Now in: [build plan](versions/v0.6/build-plan.md) v17, chunk 17c, G15.
- **D593 (2026-11-20, the owner, on chunk 12b's shop game: "Report
  only"): `n_live_tup` leaves the shop's M1 judged set and is reported
  as a figure;** it is the estimate VACUUM and ANALYZE overwrite, not a
  count inserts drive (run R's `daily_sales` reads 30 for 15 rows).
  Refines D586. Now in: [master spec](versions/v0.6/master-spec.md) 12.1; [build plan](versions/v0.6/build-plan.md) v18, chunk 12b.
- **D594 (2026-11-20, the owner, on chunk 12b's shop game: "Fix a+b+c
  now"): the forged past's counters follow what drives them,** fixed
  before 12b resumes: the scheduler's roles and databases follow the
  load, the monitoring's own series stay flat; no 0.25 floor on the
  load's ratio; each database's `pg_stat_database_*` shaped by the fill's
  transactions there. `set_clock`'s extra commit stays reported, not a
  tell. Now in: [master spec](versions/v0.6/master-spec.md) 9.9 fix 12; [build plan](versions/v0.6/build-plan.md) v18, chunk 18.
- **D595 (2026-11-20, spec-writer, placing D594): chunk 18 inserted in
  wave 4, chunk 12b resuming after it;** the scheduler 0.4.0 rebuilt
  unreleased, the wave gate rerunning what it touches. D594 read: the
  `user` label decides before `datname` (the monitoring's queries in a
  scheduler database stay flat); a series with neither (host, WAL) keeps
  the load. 9.10 unchanged: its "fine shape" row is not the night's
  level. Now in: [build plan](versions/v0.6/build-plan.md) v18; [master spec](versions/v0.6/master-spec.md) 9.9.
- **D596 (2026-11-20, the wave driver's call, recorded by spec-writer):
  capture W4's items 1 to 5 as chunk 12b built them,** with the tells'
  autovacuum rule against run R counting updates from T0 and one run
  per bulk statement (the shop's `customers`: 3.7 expected, observed 1
  passes), the residual reported. Now in: wave log, capture W4 (revised
  2026-11-20); [build plan](versions/v0.6/build-plan.md) v18, chunk 12b; [master spec](versions/v0.6/master-spec.md) 12.1.
- **D597 (2026-11-20, spec-writer, gate G10.4 after wave 4's gate):
  wave 4's forms written as built,** each checked against the code on
  `v0.6-w4`; none contradicts the spec, which they complete: the short
  fake game's record and the "Fake aging" section's sources; the fill's
  `fill_transactions` and fix 12's level per call; M3's judged set and
  bounds; the exporter 0.21.1's reach. The tails' figures on 19 go to v1.0
  gating; chunk 17c's two content findings to O298, O299. Now in:
  [formats.md](formats.md) v41; [master spec](versions/v0.6/master-spec.md) 9.7, 9.9, 9.10, 12.1, 18;
  [v1.0 gating](versions/README.md#v10-gating); [build plan](versions/v0.6/build-plan.md) v19.
