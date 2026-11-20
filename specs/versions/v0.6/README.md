# v0.6 — the bastion as the players' main activity point

Status: draft v12. **Release gate passed** on `v0.6-rg` on 2026-11-20,
its [release notes](#release-notes) written (item 7), G11 cleared by
the owner (D599–D601); the merge into `main` next.
**Consolidated** on 2026-11-16 into the
[master spec](master-spec.md) and its [access model](access-model.md)
(D514), **approved** the same day, the review's defaults standing,
every brick bumped and D504 confirmed (D515–D517); the
[build plan](build-plan.md) **approved** the same day (D518), as v2:
no reference data in git (D519), `fa-real` torn down after chunk 1
(D520). Every drafting point ruled on 2026-11-16 (D498–D503); the
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

## Release notes

v0.6, release gate run on 2026-11-20 on `v0.6-rg`, cut from `main` at
`1db4044` once wave 4 had merged: alone on armenelos, every Docker run
under the host lock and a sleep inhibitor, each item under 30 minutes,
the VPS drained and untouched (D314, D511; master spec 14). Items 1, 2,
4, 5 and 6 passed, run or cited as below; item 3, the two short fake
games, run at the gate; item 7, these notes; item 8, G11, cleared by
the owner on 2026-11-20 (D599).
The bricks at their v0.6 versions (master spec 6.8): `bastion` 0.6.0,
`grafana` 0.4.0, `scheduler` 0.4.0, `postgres` 0.5.1, `api` 0.1.1,
`health-check` 0.1.1, `pgbouncer` 0.1.2, `pgwatch` 0.1.1,
`postgres-exporter` 0.2.1 and `prometheus` 0.2.2.

### What v0.6 delivers

- **The bastion, the players' main activity point** (`bastion` 0.6.0):
  the game's home page of sites and documents (D480); the
  documentation site, every starter-pack file and handout a page of
  its own and every topology brick's player documentation (D501);
  `~/reports/` served read-only at `/reports/`, sandboxed (D511); a
  status page per partner with a `player_doc`, showing only the
  incidents the scenario marks as admitted (D513); `jq` and `tmux`
  beside the PostgreSQL 19 client tools.
- **The network overview**, a player handout that may be wrong
  (D483–D485): the `network-overview` skill, the domains' overview
  fragments, the clinic's overview, the `docs-overview-backup-claimed`
  fault and its short test; Node health's `node` variable (`grafana`
  0.4.0).
- **Fake aging** (D489–D495), a second aging mode beside real aging,
  on the shop and the campaign: `gmctl render --aging fake`, the fill
  (`scheduler` 0.4.0's fill mode and queue model, P0 and its cover),
  `clean-restart` with the WAL padding, `start-load`, the forged
  Prometheus past (`gmctl history`), the early check, the restart
  record and `gmctl status`; every fault of both scenarios carrying
  `aging.fake` and a measured `history:`; the scenario document's
  "Fake aging" section; the fix list (master spec 9.9) and the
  documented limits (9.10); the verification tools and
  `smoke-fake-aging.sh`; the shop's real-aging reference kept outside
  git, its checksum verified.
- **The `game-master` skill**: the two modes, the initiator asked once
  whether they play, the technique never named to a possible player,
  the feedback in two parts (D497), a reported tell explained only
  after the final answer (D496).
- **The loader's refusals** of master spec 6.10, O251's and O269's
  among them, each with a unit test (ISS-001 resolved).
- **PostgreSQL 19 everywhere** (D587; below).
- **Tests**: the unit suite (1570 OK, 2 skipped), each brick's stack
  test, the fixtures of master spec 12.1, each under 30 minutes.

### Release gate results

1. **Short tests: PASS.** The bastion's stack test 136/0 and
   `grafana`'s 139/0 (with item 2's builds); `fixture-status` 27/0
   (381 s); `docs-overview-backup-claimed` 16/0; the network overview's
   unit tests in the unit suite.
2. **The format, the loader and the bricks: PASS.** zlib1g named in the
   ten installs with a `ZLIB_FLOOR` assertion (`7476d7b`); the ten
   images built `--no-cache --pull`, zlib1g `+b1` to `+deb13u1` the only
   `dpkg` difference in each; every stack test green at wave 4's counts
   (`postgres` 317/0 after `3179aff`, below); the scheduler's unit tests
   117 OK, `api`'s 36 OK; the unit suite 1570 OK, 2 skipped (397 s);
   the format check 0 missing on the 5 scenarios and 38 fixtures; G5,
   G7, G8, G9.2, G9.3 (`81b6ffb`, CLEAR WITH NOTES) and G10.1 to G10.4
   done, `.tech` current.
3. **Two short fake games: PASS.** On 19, without `--record`, each in
   its start window: the shop 54/0 (M1 10/10; M3 5/5, commits ×1.00,
   rows inserted ×0.977, statements ×0.998; tells 10/0; f8's step
   14008804 vs 14016512), the campaign 64/0 (tells 35/0, P0 held). The
   restart record and `gmctl status` read in each run's output; all 20
   faults carry `aging.fake`, 19 their `history:` (f10 is `real-only`).
   Their wall times are under "Measured figures".
4. **The clinic's front: PASS.** `fixture-clinic-front` 38/0, read as
   `player`; the bastion's footprint with `status-pages` up measured
   (`8674f10`, below).
5. **The existing scenarios' short smokes: PASS.** bookshop 19/0,
   fernway 18/0, shop 26/0 (844 s), campaign 33/0 (317 s); `smoke.sh`
   61/0, `smoke-monitoring.sh` 43/0, `smoke-governance.sh` 121/0,
   `smoke-load.sh` 73/0.
6. **The documents: PASS.** The `game-master` skill read against
   master spec 13 item 6; the limits where 9.10 says; the reference's
   archive checksum verified; v1.0 gating listing 12.2's items, the
   campaign's full selection per D542 (`94bb1b5`); every row of the
   plan's "Left for the build" recorded (`a8b9edb`), retention after a
   compaction to v1.0 gating (D598, `925734d`).
7. **Release notes**: these.
8. **G11 cleared** (2026-11-20, D599): the owner releases v0.6 with
   the gate as run, its known limits and what stays v1.0 gating; the
   OpenSSL and nginx calls (D600) and wave 4's items (D601) below.

### Measured figures

On armenelos (AMD Ryzen 5 PRO 8640HS, 11.3 GiB, Debian 13; Docker
29.9.3 to 29.10.0), 2026-11-16 to 2026-11-20. The VPS ran none of
v0.6's tests.

- **P0**, the virtual clock in the fill's SQL and the server-side
  functions it calls (master spec 9.8): measured partial in chunk 8,
  the fill's own SQL and the `gm_vclock` shim reaching the shop whole
  and the campaign's f1 to f3, not a routine pinning its own
  `search_path`; the cover (chunk 15, D523) reaches the campaign's
  `rpt.close_day()`, so f4 and f7 stay `supported`. In the campaign's
  short game: `rpt.close_day()`'s `proconfig` and `prosrc` identical
  before and after the fill, the nightly close once at 01:30 scenario
  time, 16 hourly roll-ups for 16 due, each at :05. Only the catalog
  row-version tell remains, a documented limit (9.10).
- **The fill** (wave 4's short games, 945 virtual minutes each): the
  shop 473 s, the campaign 196 s; the deploy to the fill's end 503 s
  (the script's bound 600 s) and 231 s (bound 330 s); the setup, the
  deploy to the restart without the wait for the anchor, 8 min 38 s
  and 4 min 9 s, the line in each scenario document (D544). The
  fixtures: `fixture-fill`'s 22:00 to 11:00 in 332 s (chunk 8); after
  chunk 18, 461 s for 929 virtual minutes.
- **The WAL padding** (`clean-restart`): the shop's `db` 1,083,304,216
  bytes in 2.5 s, `pg_wal` 1,056,964,608 bytes after the checkpoints,
  98.4 % of the padding's figure at the read; the campaign's `db`
  635,780,616 bytes in 0.6 s and `reporting` 219,701,120 bytes in
  0.5 s, `pg_wal` at 100.0 % on both; chunk 9's fixture 1,085,863,544
  bytes in 1.6 s (2.4 s and 2.2 s in reruns), `pg_wal` 1 GiB.
  `clean-restart` 27 s and 31 s whole; every service, the monitoring's
  included, started within 10 s after `restart.at`.
- **The forged past** (`gmctl history`): the shop's import 80 s,
  `promtool`'s peak 1043.9 MiB; the campaign's 90 s, peak 1220.6 MiB;
  Prometheus' lowest timestamp 3 s and 0 s from the virtual T0 right
  after the import.
- **The comparisons** (master spec 12.1), wave 4's shop game: M1 10/10,
  every count within 0.2 % of run R scaled to the span but
  `daily_sales` (16 against 15.0, one row) and `delivery_events`
  ×1.025, `n_live_tup` reported only (D593);
  M3 5/5 over 15 steps (commits ×0.996, rows inserted ×0.982, statements ×1.00,
  calls ×0.992, errors ×0.991; correlations 0.995 to 1); the tells
  10/10; f8's step 14,008,930 bytes against 14,016,512. The campaign's
  tells 35/0, f1 at the seam ×0.99.
- **The short games' wall times**, deployment and teardown included,
  against 1800 s: wave 4's, on `v0.6-w4` at `758e080`, the shop 1642 s
  (54/0) and the campaign 1652 s (64/0), each about 2.5 minutes under.
  The release gate's runs on `v0.6-rg` (2026-11-20): the shop 1675 s
  (fill 476 s, deploy to `restart.at` 520 s without the anchor wait,
  import 78 s, peak 1063.5 MiB), the campaign 1705 s (fill 192 s, 241 s,
  import 90 s, peak 1224.9 MiB): 125 s and 95 s under 30 minutes. The
  margin is narrowing (12b had about 150 s): a known limit, see below.
- **`bastion` 0.6.0's footprint** (limits 0.5 CPU, 256M; reservations
  0.25, 128M, 256M disk; growth 1M an hour; `brick.yaml` unchanged), in
  its `docs/gm.md`, "At rest in v0.6":
  - the stack test, `status-pages` down (2026-11-17): the container
    5.5 MiB with routes and 5.0 MiB without, nginx 13.2 MiB and 12.3
    MiB resident, as v0.4 and v0.5; `jq` and `tmux` add 3.6 MiB to the
    image, 199 MB from 195;
  - `status-pages` up (`8674f10`, release gate item 4,
    `fixture-clinic-front` alone, nine partners' pages, 150 s at rest):
    the container 5.2 MiB (CPU 0.00 %), nginx 11.2 MiB resident, the
    status service 1.7 MiB between renders (its `sleep 60`; its
    supervisor 80 KiB), the cgroup's `memory.peak` 21.7 MB (20.7 MiB)
    with start-up; the status pages 76 KiB under
    `/run/web-front/www/status/`.
- **`pgwatch` 0.1.1** on 19 (chunk 17b): 13.5 MiB at rest, peak 23 MB.

### PostgreSQL 19 everywhere

The owner, 2026-11-19 (D587): "Move to pg19 everywhere." Every
PostgreSQL in v0.6 is PGDG's 19.0, the server and every client tool
and library, folded into the unreleased versions (master spec 6.8):
`scheduler`, `api` and `health-check` leave Debian's libpq 17; pgAudit
19.0 ends D539's deferral; `postgres_exporter` 0.21.1 and pgwatch 6.2.0
(G9.2's picks); `postgresql-common` kept at 278 (G9.2); every seed
logging autovacuum logs autoanalyze too (D592). The ten images hold no
other PostgreSQL.

**The figures measured on 18 stand** (D590): fake aging's service
times, history signatures, WAL rates and run R were measured on 18 and
are kept, since M1's and M3's judged measures are counts the workload
drives, which the server's major doesn't move; both short games passed
them on 19 (above). The one size a signature uses was re-measured on
19 (chunk 17b): `order_lines_order_id_idx` 13,213,696 bytes, exactly
18's, so f8's `gauge_before` stands.

**What chunk 12b read of them on 19**, figures only, never judged
(D590, D597): the short games' 15-minute tails, right after the
restart's cold caches and with faults planted, against the files
measured on 18. Outside ×0.8 to ×1.25: 16 service times (among them
the shop's `orders.detail` ×15 with f8's scan and `reports.best-days`
×35, the campaign's `dashboard.today` ×68 and `dashboard.freshness`
×63) and two WAL rates (the campaign's `db` ×2.43, `reporting` ×0.14;
the shop's `db` ×1.18 within). The full list and what follows are in
[v1.0 gating](../README.md#v10-gating), "fake aging's figures on
PostgreSQL 19": read again over the full selections' real tails, and a
key or rate still outside that no planted fault explains re-measured
on 19.

### Known limits

Named by master spec 12.2 and the release gate's items 5 and 7:

- **v1.0 gating** ([roadmap](../README.md#v10-gating), "v0.6's
  additions"), each run once and longer than 30 minutes: fake aging's
  full selections with their real tails (the shop's 3-hour tail with
  f4, f5 and f7; the campaign's variant without f10 and issue 6, f5
  planted in its 5-hour tail), and in them Prometheus' retention after
  a compaction, which the build never reached (D598); the blind reads
  (D492); the stance check-list's v0.6 items (the feedback's two parts,
  no aging word before the game is concluded, a reported tell
  explained); fake aging's figures on 19 (above). v0.5's and earlier
  versions' items stand there.
- **pgBadger's checkpoint section is empty on PostgreSQL 19** (D591,
  O294 as ruled): 19's `checkpoint complete:` line has a new form that
  pgBadger 13.3 doesn't read. No fault's witness reads that section; the
  lines are in the log and the counters in `pg_stat_checkpointer`. The
  next pgBadger release that reads 19's lines is taken under D396
  (`postgres`' `docs/gm.md`).
- **Fake aging's documented limits** (master spec 9.10), visible to a
  DBA who hunts with superuser access, by design (D492): the restart's
  traces, no log before the restart, the real-clock actors starting at
  it, the data files' inode change times, the last-use times of what
  only the fill touched, the LSN if the padding doesn't hold,
  time-driven behaviour emulated in outcome only, Prometheus' imported
  blocks and its own series showing the import about 12 minutes after
  the restart, the forged past's fine shape, a covered routine's new
  catalog row version. Each scenario's are in its document's "Fake
  aging" section.
- **Fake aging covers the shop and the campaign only.** The clinic is
  later (master spec 18); the campaign's f10 is `real-only`, so its
  fake game is the variant without f10 and issue 6 (9.8). The
  `tail-only` faults (the shop's f4, f5, f7; the campaign's f5, f6)
  are left out of the short games and read in v1.0 gating's.
- **The forged night's commits run under run R's** (×0.91 to ×0.97 in
  the shop game's night steps): R's flat floor of about 0.09 commits a
  second is forged as following the load (gate fix `1e341dc`); M3's
  judged mean holds (×0.996).
- **The short games' margin**: 1.5 to 2.5 minutes under 30 (the release
  gate's runs: 125 s and 95 s); a slower host could cross it.
- **The history import's memory**: `promtool` peaks at 1.0 to 1.2 GiB
  on the host during the import.
- **Open questions found in the build, ruled** (D601): O298, the
  clinic's pgaudit described in its policies but loaded by no seed, so
  T2 and T251 can't bite: pgaudit loaded in `lab`'s and `portal`'s
  seeds in a later build touching the clinic, before it is next played;
  O299, the audit grid's sampling block creating a temporary table in a
  read-only session: the owner amends his grid and the copy is
  refreshed (v0.7). Each stays open until done.
- **Open issues**:
  [ISS-006](../../../issues/ISS-006_20261116_health_check_stack_test_cron_race.md),
  `health-check`'s stack test racing the cron daemon (in progress);
  [ISS-007](../../../issues/ISS-007_20261119_fill_queue_plan_ignores_hider_planting.md),
  the fill dropping a hidden fault's queue entry whenever the hiding
  instance is planted (no covered fault uses `suppressed_by`, D548,
  D578);
  [ISS-008](../../../issues/ISS-008_20261119_fake_game_unset_signature_parameter_silent.md),
  an unset `database` parameter losing a signature's series silently
  (the two covered scenarios checked by a test);
  [ISS-009](../../../issues/ISS-009_20261120_scenario_document_template_gaps.md),
  five cases the scenario document's template lacks (fixed in v0.7,
  D601).
- **v0.5's stand**: the governance checks on the whole clinic (D471),
  no hand-over snapshot for the whole clinic, what a restore doesn't
  give back, the partner stubs' reference counters (O249), the
  clinic's setup time and the vault's refusals before T0 (O270,
  [ISS-002](../../../issues/ISS-002_20261114_clinic_load_slow_vault_503.md)).
  v0.5's `seed-file` limit is gone: the loader checks it (O269,
  ISS-001 resolved).

### Known gaps of the access model

All stand as [access-model.md](access-model.md) section 9 states them.
v0.4's and v0.5's stand as [v0.5's access model](../v0.5/access-model.md)
section 13 states them (summarised in
[v0.5's release notes](../v0.5/README.md#known-gaps-of-the-access-model)).
v0.6's:

- the reports folder is in the player's home: a player may remove the
  front's read access to it and break their own Reports page; their
  problem, as the report is;
- fake aging's documented limits (the restart's traces, the logs
  starting at the restart, the inode change times, the last-use times)
  are visible to a player with superuser access who hunts for them: by
  design, the bar being that a student doing the audit doesn't stumble
  on the fake, not that a hunting DBA can't prove it.

### Fixes made at the release gate

- **`7476d7b`**: `zlib1g` named in the ten bricks' installs with a
  `ZLIB_FLOOR` assertion (D588), rather than an `apt-get upgrade`,
  which keeps `postgresql-common` at 278 where G9.2 left it.
- **`3179aff`**, test only: `postgres`' stack test checks cron with
  `pgrep -o -x cron`; cron's per-job child raced the check.
- **`8674f10`**: the bastion's footprint with `status-pages` up, in
  its `docs/gm.md`.
- Documents: v1.0 gating's campaign per D542 (`94bb1b5`), retention
  after a compaction to v1.0 gating (D598, `925734d`), the plan's
  "Recorded in" column (`a8b9edb`); `.tech` after G9.3 (`81b6ffb`);
  D588 corrected (CVE-2026-76844 is not zlib's, below).

### Security, accepted risks and the owner's rulings

- **zlib1g at `1:1.3.dfsg+really1.3.1-1+deb13u1` in every image** (D588,
  row G9.3): DSA-6613-1, fixing CVE-2026-85091 and CVE-2026-27171; read
  in all ten built images, `dpkg -V` clean. CVE-2026-76844, once
  counted with them, is not zlib's: Debian's tracker marks it
  NOT-FOR-US, a webpack-dev-middleware flaw OSV's Debian import
  misattributes (D588, corrected 2026-11-20).
- **OpenSSL, accepted for the release** (G11, D600): Debian's
  3.5.7-1~deb13u3, in every image, carries 10 CVEs with no Debian fix
  (8 rated Low upstream and fixed in 3.5.10, 2 with no OpenSSL advisory
  yet); none is on a path a brick serves (QUIC, DTLS, AES-GCM-SIV, CMS,
  PEM, DANE, Suite B; the one OpenSSL TLS server is PostgreSQL's), and
  no rebuild would change anything. The owner releases v0.6 with them
  open; they are reviewed at the next trixie OpenSSL DSA, or on
  2027-02-01 at the latest (`.tech`, "OpenSSL").
- **nginx, accepted as ignores** (G11, D600): 14 NVD matches on
  Debian's `deb13u11`, backport false positives, accepted as
  `[[ignore]]` entries in `.tech` until 2027-05-01, written by the
  security advisor.
- **Accepted risks standing**: Debian `curl`'s trixie-unfixed issues
  until 2027-02-01 or the next trixie `curl` security upload (D443);
  `.tech`'s ignores until 2027-05-01 (D444, D458). The
  `security-2026-11-14` branch, with 29 ignores `main` lacks, is on
  hold apart from this release.
- **Wave 4's items, ruled by the owner at G11** (D601, all as
  proposed): D595's two readings confirmed (the `user` label decides
  before `datname`; a series with neither follows the load); f8's
  measured `counter_per_call`, 4 a call of its key (gate fix
  `1e341dc`), confirmed; O298, pgaudit loaded in `lab` and `portal` in
  a later build; O299, the owner amends his grid, the copy refreshed;
  ISS-009 fixed in v0.7. The games' margin stays a known limit (above)
  and the 19 recalibration in v1.0 gating (D597).
