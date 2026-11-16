# v0.6 — the bastion as the players' main activity point

Status: draft v10. **Consolidated** on 2026-11-16 into the
[master spec](master-spec.md) and its [access model](access-model.md)
(D514), **approved** the same day, the review's defaults standing,
every brick bumped and D504 confirmed (D515–D517); the
[build plan](build-plan.md) v1 written, for the owner's approval
(G1). Every drafting point ruled on 2026-11-16 (D498–D503); the
review's findings closed the same day (D504–D512); the partners' status
pages designed at consolidation (D513). This page and its two drafts
stay as the working record until v0.6's archive; where they and the
master spec differ, the master spec wins. Bastion-related items moved in from
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
- **A documentation website** hosted on the bastion (D501). It
  carries the starter pack (the README, the story, the issues and
  the rules), the customer's handouts (the data policy, `partners.md`,
  the data register, the network overview), each a page of its own
  (O267), and the player documentation of every brick in the topology
  (`docs/player.md`), rendered as pages.
- **The network overview** (D483–D485), a player handout: one entry per
  node of the customer's estate, generated from the authoritative
  files, customer documentation that may be incomplete or wrong, each
  node linked to Grafana's Node health dashboard. Its design is
  [network-overview.md](network-overview.md) (draft v4; O260–O268
  closed as recommended, D487, D488; the page always present, D505).
- **Handouts are static snapshots** (D488): what the customer gave the
  DBA at the mission's start, generated once at setup and never
  re-rendered in play; only the live tools they link to follow the
  system. A fix that leaves one out of date is expected, never a fault
  ([network-overview.md](network-overview.md#2-one-entry-its-fields-and-their-sources)).
- **General-use tooling** on the bastion (D501): what it has today,
  the PostgreSQL 18 client tools (`psql`, `pg_dump` and the rest),
  `ssh`, `procps`, `less`, `nano`, `vim-tiny` and `curl`, plus `jq`
  (for Prometheus' API) and `tmux`; nothing heavier; more when a
  player's need shows.
- **Reports published on the bastion** (D501, moved here from v0.2):
  reports generated in the stack, such as pgBadger's HTML, readable
  through the bastion's web front, a "Reports" entry under the home
  page's sites, rather than copied out with `scp` and `sftp`, which is
  how they leave in v0.2. These are the stack's own reports, not the
  players' (D481). **Design** (D511): a folder on the bastion,
  `~/reports/`, created by the bastion's entrypoint, served read-only
  by its web front at `/reports/` as a listing, behind the same basic
  authentication. A player brings a report there with one hop
  (`scp <node>:pgbadger.html ~/reports/`, `scp -r` for pgCluu's
  folder) and opens it in the browser; the `sftp` to their own machine
  is no longer needed. The front never reaches into a database node: no
  new route, no web server on the nodes. A report's own scripts run
  sandboxed (the front answers `/reports/` with a
  `Content-Security-Policy: sandbox allow-scripts` header), so a
  report's page never acts on Grafana's origin. **Owner**: the
  `bastion` brick, its web front; the `postgres` brick's player
  documentation says where to put a report.
- **A status page for each third party** (D274, D501), showing only the
  incidents the partner admits, beside its `partners.md` description
  ([v0.5's third parties](../v0.5/third-parties.md)): one page per
  partner with a `player_doc`, under the home page's sites, showing the
  incidents the scenario marks as admitted by that partner, each from
  its start time. A live site like Grafana, not a handout, so D488
  doesn't apply. Its design is the master spec's
  ([7.6](master-spec.md#76-the-partners-status-pages), D513): a fault
  instance's `admitted:` marks the incident, render writes a root-only
  status file to the bastion, which renders the pages itself; never a
  route from the bastion to a third party's node (D273).
- **O251's loader refusal** (a bastion mapping `partners.md` exactly
  when the third parties carry a `player_doc`), in v0.6's first chunk
  that touches `tools/gm/model.py` (D486); **O269's beside it** (each
  selected `seed-file` instance's `seed_changes` lines found in its
  node's copy of the seed file, with a unit test; D476, D510).
- **Fake aging** (D489–D493), a second aging mode beside real aging:
  a quick game filled in minutes on a virtual clock, a maintenance
  restart, a real tail, forged Prometheus history; its faults curated
  to what it can fake, its fixable caveats fixed, the rest documented.
  Its design is [fake-aging.md](fake-aging.md) (draft v5): the players
  never told about the aging process during the game, a tell their
  report names explained after it (D494, D496); the setup dialogue
  naming no technique when the initiator may play (D504); the shop and
  the campaign covered, the clinic later (D495).
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
   view (D499); it never steps out of the story. It comes first.
2. **The teaching moment**:
   - what the players missed, and how they could have seen it, from
     the evidence the game actually held;
   - what they found correctly;
   - what they identified but couldn't explain, explained;
   - why things looked as they did, whether from a planted fault
     (its `gm.md`, the scenario's notes) or from the aging (a reported
     tell only, [fake-aging.md](fake-aging.md#41-what-the-players-are-told-and-when-d494-d496)).

What it refines (D499, no conflict found):
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
- Open still: O38 (a score; the feedback written to a file). The
  feedback's language is settled: English, as all player-facing
  material (D503, O32 closed).

[gm-stance.md](../../gm-stance.md) "Feedback" took this text at
consolidation (draft v15).

## Short tests (D314, D511)

Each under 30 minutes, on the least environment that proves it, as
v0.5's gates have them; the long ones are in
[v1.0 gating](../README.md#v10-gating):

- **The home page**: a fixture with two web routes and three of the
  seven documents: its **Sites** list the two routes and **Reports**,
  its **Documents** the three present and no link to an absent one; a
  route named `docs` refused by the loader.
- **The documentation site**: each starter-pack file and handout at
  `/docs/<id>`, each topology brick's player documentation at its page,
  rendered from the starter pack as handed over (a player's edit of
  their home copy changes no page); a page behind the basic
  authentication.
- **`jq` and `tmux`**: present on the bastion and runnable as `player`;
  `jq` reading Prometheus' API through `curl`.
- **Reports**: a pgBadger report copied into `~/reports/` listed and
  served at `/reports/`, with the sandbox header; nothing served from
  outside the folder.
- **The status pages**: a fixture with one partner with a `player_doc`
  and two admitted incidents, one started and one not: the page shows
  the started one only, the other once its start passes; a partner with
  none admitted shows no incident; no route to a third party's node.
- **The network overview**, the dashboard's `node` variable, a
  `docs-overview-*` fault, fake aging's short checks: as their drafts
  say ([network-overview.md](network-overview.md#5-deviations-as-faults),
  [fake-aging.md](fake-aging.md#7-verification)).
- **The loader's refusals**: O251's and O269's, each with a unit test.

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
with a home page of links (O267, D487):

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
  closed by D502.
- O32: the language of player-facing material, the website included;
  closed by D503.
- O260–O268, the network overview's: closed as recommended (D487,
  D488).
- O271, O272, fake aging's: closed (D494, players never told; D495,
  the shop and the campaign)
  ([fake-aging.md](fake-aging.md#questions-for-the-owner)).
- O251, the loader's `partners.md` refusal: placed (D486), built in
  v0.6, open until built.
- O269, the loader's check of a `seed-file` instance's lines in the
  scenario's copy: placed in v0.6 at v0.5's close (D476), settled as
  the loader refusal (D510), built beside O251's, open until built.

## Pending owner rulings before consolidation

Settled on 2026-11-16: the owner, "agreed", to all eighteen items as
recommended (D498–D503): fake aging's proposals (D498), the feedback's
form (D499), the network overview's details (D500), this page's scope
items (D501), O21 (D502) and O32 (D503). None pending. The review of
the drafting (REJECT, 2026-11-16) was closed by D504–D512; next,
consolidation. The two questions' answers, which have no other page
yet:

Both now also stand in [scenario-lifecycle.md](../../scenario-lifecycle.md)
"Hand-over" and the master spec (7.4, 11).

- **Starter files and planted inaccuracies** (D502, O21): only the
  handouts describing the system may carry one, the data register and
  the network overview. The README and the rules (the game's how-to),
  the data policy (the norm the players audit against) and
  `partners.md` (no access, so unverifiable) never do. The story and
  the issues may be mistaken only as the customer's belief, a false
  alarm as today.
- **Language** (D503, O32): every player-facing material is in
  English, the documentation website and the feedback included; a
  scenario language option may come later, not in v0.6.
