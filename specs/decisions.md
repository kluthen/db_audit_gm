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
close, unused at its archive). The live entries below are v0.6's, from
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
