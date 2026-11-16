# v0.6 — the bastion as the players' main activity point

Status: draft v6. No master spec. Bastion-related items moved in from
v0.5 on 2026-10-31 (D233); drafting opened on 2026-11-13 with the
owner's rulings of that day (D480–D486); fake aging joined on
2026-11-15 (D489–D495); the GM's feedback in two parts on 2026-11-16
(D496, D497).

## Goal

In the owner's words, the bastion becomes "the main activity point" (D71):
it publishes the dashboards and monitoring tools, hosts a documentation
website, and provides general-use tooling (`psql`, `pg_dump`, ...).

v0.2 already makes the bastion publish the monitoring web interfaces
(D68); v0.6 turns it from an entry point into the place the players work
from. Everything stays within **one game**: its web front, for its
players (D480).

## In scope

- **The game's home page** (D480): the bastion's web front links every
  site of the game (below).
- **A documentation website** hosted on the bastion. What it carries is
  (proposed): the starter pack (the README, the story, the issues and
  the rules), the customer's handouts (the data policy, `partners.md`,
  the data register, the network overview), each a page of its own
  (O267), and the player documentation of every brick in the topology
  (`docs/player.md`), rendered as pages.
- **The network overview** (D483–D485), a player handout: one entry per
  node of the customer's estate, generated from the authoritative
  files, customer documentation that may be incomplete or wrong, each
  node linked to Grafana's Node health dashboard. Its design is
  [network-overview.md](network-overview.md) (draft v2; O260–O268
  closed as recommended, D487, D488).
- **Handouts are static snapshots** (D488): what the customer gave the
  DBA at the mission's start, generated once at setup and never
  re-rendered in play; only the live tools they link to follow the
  system. A fix that leaves one out of date is expected, never a fault
  ([network-overview.md](network-overview.md#2-one-entry-its-fields-and-their-sources)).
- **General-use tooling** on the bastion: the PostgreSQL client tools
  (`psql`, `pg_dump` and the rest; the v0.1 bastion already carries the
  PostgreSQL 18 client tools) and other everyday tools, to be chosen.
- **Reports published on the bastion** (proposed, moved here from v0.2):
  reports generated in the stack, such as pgBadger's HTML, readable
  through the bastion's web front rather than copied out with `scp` and
  `sftp`, which is how they leave in v0.2. These are the stack's own
  reports, not the players' (D481).
- **A status page for each third party**, showing only the incidents
  the partner admits, beside its `partners.md` description (D274;
  [v0.5's third parties](../v0.5/third-parties.md)).
- **O251's loader refusal** (a bastion mapping `partners.md` exactly
  when the third parties carry a `player_doc`), in v0.6's first chunk
  that touches `tools/gm/model.py` (D486).
- **Fake aging** (D489–D493), a second aging mode beside real aging:
  a quick game filled in minutes on a virtual clock, a maintenance
  restart, a real tail, forged Prometheus history; its faults curated
  to what it can fake, its fixable caveats fixed, the rest documented.
  Its design is [fake-aging.md](fake-aging.md) (draft v3): the players
  never told about the aging process during the game, a tell their
  report names explained after it (D494, D496); the shop and the
  campaign covered, the clinic later (D495).
- **The GM's feedback in two parts** (D497): the customer side, then a
  teaching moment (below).

## The GM's feedback (D497)

The owner, 2026-11-16: "Explaining why things look like they did (due
to aging or due to planted faults) is one of the goal of the GM upon
detailing its appreciation of the report produced. One part will be
the customer side of thing, the other part is a teaching moment. What
did the player miss, and explain how they could have seen it, what
they found correctly, what they identified but couldn't explain should
be explained, etc ..."

After the final answer, the GM's appreciation of the report has two
parts:

1. **The customer side**: the in-world assessment. What the customer
   gets from the report: each issue against its expected resolution
   and the answer key's acceptance criteria, the faults found against
   those present, the GM's tooling expectations (D65, D76), an
   overstep named. In the GM's voice, from the customer's point of
   view (proposed); it never steps out of the story.
2. **The teaching moment**:
   - what the players missed, and how they could have seen it, from
     the evidence the game actually held;
   - what they found correctly;
   - what they identified but couldn't explain, explained;
   - why things looked as they did, whether from a planted fault
     (its `gm.md`, the scenario's notes) or from the aging (a reported
     tell only, [fake-aging.md](fake-aging.md#41-what-the-players-are-told-and-when-d494-d496)).

What it refines (proposed reading, no conflict found):
- **D9 and [gm-stance.md](../../gm-stance.md) "Feedback"**: the
  feedback's content was the issues found against the faults present,
  the tooling expectations, and each answer's acceptability, in a
  teacher's tone that stays positive. That content is now part 1; part
  2 is new. The tone stays: what was missed is said as how it could
  have been seen.
- **D13** (no reveals before the final answer) is untouched: both parts
  come after it, and part 2 is where the reveals live.
- **D18** (the GM answering in character as the customer during the
  game, a future idea) is untouched: part 1 is an assessment after the
  game, not a conversation during it.
- Open still: O38 (a score; the feedback written to a file), O32 (its
  language).

gm-stance.md "Feedback" takes this text at consolidation.

## The game's home page (D480)

The owner, on 2026-11-13: the entry point is the bastion's web front of
**one game**, and its audience is the players. A simple home page links
to every site in the game: Grafana, Prometheus, health, the handouts,
and later the fictional provider's console and others. **nginx is
kept**; no Caddy. There is **no front above several games**, "nor is it
expected any time soon".

From v0.4 the front's home is the starter-pack page: the starter pack's
files rendered one after the other, then the web interfaces' links
(D221, D224; the bastion's `gm-entrypoint`, step 7). v0.6 replaces it
with a home page of links (proposed, O267):

- **Sites**: each web route of the bastion's `web_routes` (Grafana,
  Prometheus, health in the clinic); later the fictional provider's
  console (after v1.0) and the partners' status pages (D274).
- **Documents**: each handout the scenario provides, each a page of its
  own (`/docs/<id>`): the README, the story, the issues, the data
  policy, the partners, the data register, the network overview. An
  absent one leaves no link (D221's rule). A web route named `docs` is
  refused.

The tools password and the basic authentication stay as they are (user
`player`), and so does the bastion-only rule: the front proxies only to
the game's own web interfaces.

## The setup's entry point (D224)

Moved here from v0.5 (D233, D248) as O135: a common Caddy in front of
several games, a homepage for the whole setup, a reporting tool on the
starter-pack page. Superseded on 2026-11-13: one game's front and its
home page (D480, above), no reporting tool (D481). O135 is closed; this
heading stays for the links to it.

## The rulings of 2026-11-13

- **D480**: one game's front, a home page linking every site, nginx
  kept, no front above several games. D224's "common caddy to handle
  multiple front" meant the sites of one game and had been over-read.
  Dropped with it: the common Caddy, the setup-wide homepage, the
  Caddy's placement, per-game passwords behind a shared front, the
  shared front's teardown. Closes O135.
- **D481**: no reporting tool. "They could just write their report
  outside the bastion. it's their problem." A register fault stays
  resolved by *propose* (D333), with no corrected file handed back.
- **D482**: no network map or diagram for now; one private network,
  third parties aside. A map becomes mandatory with the fictional
  provider ([roadmap](../README.md#beyond-v10-a-fictional-cloud-provider-d205)).
- **D483–D485**: the network overview, a player handout that may be
  wrong, its fields per node ([network-overview.md](network-overview.md)).
- **D486**: O251 placed in v0.6's first chunk touching
  `tools/gm/model.py`.
- **D487, D488**: the network overview's questions O260–O268 accepted
  as recommended; every handout a static snapshot of the mission's
  start.

## Out of scope

- Any other way in: the bastion stays the only one (bastion-only rule,
  [planes-and-access.md](../../planes-and-access.md)).
- A front, homepage or proxy above several games (D480).
- A reporting tool: the players write their report where they like
  (D481).
- A network map or diagram (D482).
- The bastion's tooling as the customer's: it is the players' kit, and
  does not count when judging whether the customer's tooling is
  proportionate (D65, D87).

## Depends on

- v0.2: the bastion publishing the UIs (D68) through its web front (D77),
  which the home page and the documentation website build on.
- v0.4: the web front in every game (D224), its page built from a list
  of elements (D221), which the home page replaces.
- v0.5: the data register handout and its skill (D330, D331), the model
  for the network overview; the third parties (D274); the node-health
  dashboard and the clinic's monitoring breadth (D340).

## Questions due in this version

- O21: whether the other starter files may carry faults (narrowed by
  D330 and D484: the data register and the network overview may);
  item 17 below.
- O32: the language of player-facing material, the website included;
  item 18 below.
- O260–O268, the network overview's: closed as recommended (D487,
  D488).
- O271, O272, fake aging's: closed (D494, players never told; D495,
  the shop and the campaign)
  ([fake-aging.md](fake-aging.md#questions-for-the-owner)).

## Pending owner rulings before consolidation

Everything still tagged (proposed) or unsettled in v0.6's drafting, as
of 2026-11-16, each with its recommendation. Answer "ok with proposed",
or name exceptions by number. Not listed: the estimates to be measured
(fake aging 2.4) and the technical unknowns (fake aging 9), which the
build settles, not the owner.

**Fake aging** ([fake-aging.md](fake-aging.md))

1. **The mode and the GM's steps.** The GM picks the mode per game:
   real when the time available covers the scenario's aging, fake
   otherwise or when a quick game is asked for; the virtual span is the
   scenario's declared aging; commands `render --aging fake`, `fill`,
   `clean-restart`, `history`; a failed history import recorded, never
   a teardown. Recommended: as proposed. Lives in: 1.1–1.3.
2. **The fault format.** `aging.fake` (support, reason, tail minimum,
   instants the tail covers, planting in the tail, what the fill
   emulates) under the existing `aging:` block; a mandatory `history:`
   with two new kinds (`gauge_before`, `daily_spike`); a fault not
   assessed is refused in a fake game; the answer key's maintenance
   restart item; the campaign's f10 stays real-only, its redesign not
   in v0.6. Recommended: as proposed, into formats.md at consolidation.
   Lives in: 2.1, 2.4.
3. **The tail.** At least 1 h, longer as the selected faults need;
   capped to 15 minutes in tests only. Recommended: as proposed. Lives
   in: 2.2.
4. **Calibration.** One short real run (under 30 minutes) per fault
   version, the fault planted at once and its job moved into the
   window; each key's service time beside the `queries.yaml` that
   defines it, the model's code in the scheduler brick (the results had
   put the constants in the brick). Recommended: as proposed. Lives in:
   2.3.
5. **The fix list's additions and one departure.** Added: autovacuum
   through the fill (a short naptime), the data files' modification
   times, the monitoring's sessions emulated, fault parameters instead
   of constants. Departure: the table and index statistics are kept at
   the restart (the results proposed a reset, which would wipe f4's and
   f9's evidence). Recommended: as proposed. Lives in: 3.
6. **The limits' documentation and the product's shape.** The limits
   in the GM's guide to aging, each fault's `reason` and `gm.md` note,
   a generated "Fake aging" section in the scenario document, the
   game's record; the research's pieces mapped to the scheduler's fill
   mode, `gmctl` steps and test tools, the recorded baseline left in
   research. Recommended: as proposed. Lives in: 4, 5.
7. **Verification.** v0.6's gate: one short check (under 30 minutes,
   a short-tail selection) on the shop and one on the campaign; one
   blind read of each, once; the full selections with their long tails
   in v1.0 gating; R's reference kept, its small files committed and
   its Prometheus copy archived outside git with its path and
   checksum. Recommended: as proposed. Lives in: 7;
   [roadmap](../README.md#v10-gating).

**The GM's feedback** ([above](#the-gms-feedback-d497))

8. **Its form.** The customer side first, in the GM's voice from the
   customer's point of view, then the teaching moment; D9's content
   becomes the customer side, D13 and D18 untouched; gm-stance.md takes
   the text at consolidation. Recommended: as proposed. Lives in: "The
   GM's feedback (D497)".

**The network overview** ([network-overview.md](network-overview.md))

9. **The page's shape.** One entry per node, grouped (database
   servers, applications and engines, monitoring, then the third
   parties' table), a one-line-per-node summary on top, the fixed
   header text. The tags left on O264's and O267's text are stale (both
   accepted, D487) and go at consolidation. Recommended: as proposed.
   Lives in: 1, 6.
10. **Consistent with the data register by construction.** A database
    server's entry links its register entries and never restates the
    register's columns. Recommended: as proposed. Lives in: 3.
11. **Its generation.** A GM skill, `network-overview`, on the
    `data-register` model (the true overview sealed in `gm/`, the
    handout, `overview_diff:`), run at Setup step 2 between the register
    and the scenario document, checked by the loader; required of every
    scenario listing `domains:`, fixtures exempt, v0.4's shop and
    earlier exempt until next revised; `description:` required on the
    customer's nodes then. Recommended: as proposed. Lives in: 4, 8.
12. **The traps.** The generic catalogue N1–N10, class M by default
    (N5 may rise to V or D); v0.6 builds the family and at least one
    trap with its short test. Recommended: as proposed. Lives in: 5, 9.

**This page**

13. **The documentation website.** It carries the starter pack, the
    customer's handouts each a page, and every topology brick's
    `docs/player.md`. Recommended: as proposed. Lives in: "In scope".
14. **General-use tooling.** The bastion has the PostgreSQL 18 client
    tools, `ssh`, `procps`, `less`, `nano`, `vim-tiny` and `curl`.
    Recommended: add `jq` (for Prometheus' API) and `tmux`, nothing
    heavier; more on a player's need. Lives in: "In scope".
15. **Reports published on the bastion.** The stack's own reports
    (pgBadger's HTML and the like) readable through the web front, a
    "Reports" entry under the home page's sites. Recommended: yes.
    Lives in: "In scope".
16. **A status page for each third party** (D274), not yet designed.
    Recommended: one page per partner with a `player_doc`, under the
    home page's sites, showing the incidents the scenario marks as
    admitted by that partner, each from its start time: a live site
    like Grafana, not a handout, so D488 doesn't apply; designed in the
    master spec. Lives in: "In scope".

**Open questions due in v0.6**

17. **O21**, the other starter files carrying faults. Recommended: only
    the handouts describing the system may carry a planted inaccuracy
    (the data register, the network overview); the README and the rules
    (the game's how-to), the data policy (the norm audited against)
    and `partners.md` (no access, so unverifiable) never do; the story
    and the issues may be mistaken only as the customer's belief (a
    false alarm, as today). Closes O21. Lives in:
    [open-questions.md](../../open-questions.md) O21.
18. **O32**, the language of player-facing material. Recommended:
    English everywhere, the website and the feedback included; a
    scenario language option later, not in v0.6. Closes O32. Lives in:
    [open-questions.md](../../open-questions.md) O32.
