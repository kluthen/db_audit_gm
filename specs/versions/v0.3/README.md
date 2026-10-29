# v0.3 — producers and consumers

Status: **spec approved on 2026-10-22** (D154): the [master spec](master-spec.md)
and its [access model](access-model.md), consolidated the same day,
revised after the independent review (REJECT, seven blocking issues, all
fixed: D151), the owner's answers to it (D147–D149), his eight-hour aging
floor (D150) and the re-review's corrections (OKAY, D155); amended the
same day by the ruling that only a scenario with scheduler nodes ages
(D157, D158) (page draft v9). The owner's rulings of 2026-10-22 are
D114–D123, his answers to two rounds of questions D124–D145, his
acceptance of the review list D146, D152 and D153. No v0.3 question is
open. The [build plan](build-plan.md) is **approved** (D156), with the
VPS rule (D159). Built in four waves from 2026-10-23 to 2026-10-28;
**release gate passed on 2026-10-29** on `v0.3-w4` (see "Status" and
"Release notes" below); merging into `main` on the owner's word.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [master-spec.md](master-spec.md) | The consolidated v0.3 specification | approved 2026-10-22 (D154), amended by D157 and D158 |
| [access-model.md](access-model.md) | Who may do what in a v0.3 game | approved 2026-10-22 (D154), amended by D157 and D158 |
| [build-plan.md](build-plan.md) | The v0.3 build: chunks, waves, gates, release gate | v15, approved 2026-10-22 (D156); built, release gate passed 2026-10-29 |
| [wave-log.md](wave-log.md) | The waves' and the release gate's runs, captures and findings | closed with the release gate |
| [scheduler.md](scheduler.md) | The scheduler brick, the query repository, the schedule, fixed-time operations, what the players reach, drivers | draft v3, consolidated |
| [aging-and-timeline.md](aging-and-timeline.md) | Real-time aging, "meaningful" days, time of day, the timeline from deployment to teardown, the restart | draft v3, consolidated |
| [load-and-capacity.md](load-and-capacity.md) | Calibrating load, `max_connections`, load control, always-on hosts, several hosts, the hosts at hand | draft v3, consolidated |
| [faults-with-activity.md](faults-with-activity.md) | Difficulty, v0.3's scenario, fault families that need activity, candidate faults | draft v3, consolidated |
| [checks-under-load.md](checks-under-load.md) | Sealed checks, validators and smoke tests on a living system | draft v3, consolidated |
| [pgbouncer.md](pgbouncer.md) | The PgBouncer brick | draft v2, consolidated |
| [carried-items.md](carried-items.md) | Earlier rulings and known issues landing in v0.3 | draft v3, consolidated |
| [format-changes.md](format-changes.md) | Every change to the formats, script contracts, local implementation and `gmctl` | draft v2, consolidated |
| [review-list.md](review-list.md) | Every `(proposed)` item, for the owner's review in one pass | closed: first round accepted (D146); second round ruled (D152, D153) |

## Goal

In the owner's words (D47):

- Producers, "the first being the most important: they will schedule data
  ingestion, load spikes, etc. and are the main opportunity for
  ill-formatted requests, misbehaving requests, or ill-targeted requests."
- "Consumers have it similar, albeit on their end it is more probably a
  question of breadth of query: taking in too much, transactions taking
  too long, BI queries, etc."

## Settled (2026-10-22)

- **Aging is real time** (D114): the stack runs in the background before
  hand-over for as long as the scenario declares, at least eight hours, a
  floor the GM judges against the time available per game (D150); no
  sped-up clock, no forged history, no time compression (D132); on
  always-on hosts only (D125) ([aging-and-timeline.md](aging-and-timeline.md),
  superseded on the length by the master spec).
- **Only a scenario with scheduler nodes ages** (D157): a scenario with
  no producer or consumer, a static database investigated as a restored
  backup like `bookshop-new-server` and `fernway-clinics-monitoring`, has
  no aging and is handed over once its faults are planted, as in v0.2.
  It omits `aging:` (refused there), with no `plant_at` other than T0,
  no instance `aging_minimum`, no `{{customer_timezone}}`, its faults'
  minima not counted, and `render --handover` optional (D158; master
  spec 6.1, 8, 13, 15.4).
- **Time of day**: the local implementation shifts the schedule by whole
  hours so the game window gets the designed load; clocks stay real UTC;
  the story names the customer's time zone (D129).
- **Timeline changes** at fixed moments, during aging only (D127).
- **Producers and consumers are scheduler nodes** running a query
  repository the GM writes at design time (D115); a list is a pool,
  `steps:` a sequence, player-editable builders on the trust line (D133);
  randomness seeded per game (D136); a pluggable driver, SQL on
  PostgreSQL first, other targets from v0.5 (D118, D137)
  ([scheduler.md](scheduler.md)).
- **Players** read the repository and may edit it where the scenario
  allows; of the scheduling they read and change only the fixed-time
  operations (D116); they also see the scheduler's log and configuration
  except `schedule.yaml`; write policy is per file (D130).
- **No events outside the schedule** (D117); nobody pauses, speeds up or
  triggers the load during a game, no "run now" (D131).
- **Checks under load** judge the cause first, a window otherwise, may
  answer "too soon to tell", never pause the load and keep a connection
  (D124; [checks-under-load.md](checks-under-load.md)).
- **A PgBouncer brick**, optional, no metrics brick, the players' console
  role in `stats_users` only (D119, D139; [pgbouncer.md](pgbouncer.md)).
- **Difficulty** is a fault count (D120); a score is the number of fault
  instances, the levels targets (D134). v0.3 ships one new normal
  scenario (ten faults, with producers, consumers, monitoring and
  PgBouncer) and six to eight new catalog faults (D134).
- **`max_connections`** keeps its default of 100; scenarios set low
  values (D138).
- **`ALTER SYSTEM` on report-only database nodes** is accepted on the
  trust line (D121).
- **Capacity** is for the GM and the initiator to discuss; Swarm is the
  platform (D122); **multi-host is in v0.3**, tested on armenelos and the
  VPS over Tailscale, the default game single-host (D128;
  [load-and-capacity.md](load-and-capacity.md)); images are copied
  between hosts over SSH, no registry (D149).
- **A restart rebuilds the game from scratch** on the players' explicit
  confirmation (D110, D123), from a hand-over snapshot where the disk
  allows, otherwise with no history and the lost evidence named first;
  credentials kept, game id renewed (D126). Any player in the GM session
  confirms, in so many words, once the GM has stated what is lost; each
  restart is recorded; the access model lists it beside `stop` (D141).
  The snapshot is taken online, per brick, a brief stop for a brick with
  no method, Prometheus included (D147); a restart falls back to no
  history when the copies do not fit (D142).
- **A fixable builder can leak the schedule**, accepted on the trust line
  (D148).
- **Write policy per file** through the scenario's `write_overrides`, for
  every brick (D143).
- **The GM's checks have a connection reserve of their own**
  (`reserved_connections`, pinned on the server's command line, D144).
- **A fault definition's evidence** names `node`, `bastion` or
  `report:<tool>`, never `ui:<name>` (D145).
- **Every carried item is taken** (D140; [carried-items.md](carried-items.md)).
- **The release gate includes one full aged run** (D135).
- **The build plan is approved** (D156) with its nine recommendations:
  a test-harness-only override of the aging minimum (G6), the aged
  run's hosts decided from chunk 15b's measurement (G5), the driver
  joining the VPS (G4), κ = 3 under the plan's conditions, the owner
  typing the restart confirmation (G9), the aged run deployed in an
  evening and handed over the next early afternoon (G8), the rehearsal
  re-run on the merged code.
- **The VPS is shared** (D159): the driver may work on it but never
  disturbs its existing applications; filetstudio.com stays up, a change
  needing it down waits for a downtime scheduled with the owner, its
  Caddy may change while filetstudio.com stays up, and the VPS's own
  documentation is read first ([platform.md](../../platform.md)).

## In scope

- The scheduler brick for producers and consumers, its query repository,
  schedules and fixed-time operations.
- Real-time aging and the timeline it imposes; the shift by whole hours;
  timeline changes during aging.
- Load calibrated against the nerfed databases: enough to show symptoms,
  not enough to saturate the host.
- Fault families that need activity, six to eight new catalog faults, one
  new normal scenario.
- The PgBouncer brick.
- Checks that hold on a living system.
- Multi-host: per-node placement, images copied to each host, `fit` per
  host.
- Restarting a game (D110, D123, D126), only on the players' **explicit
  confirmation**: "we can't have a passing comment just restart the
  game, as it's highly breaking change". A passing mention, or a question
  about restarting, never restarts a game.
- The carried items: report-only monitoring nodes (D108), O78's format
  change, RG-2, RG-3, Prometheus retention, the format's aging items.

## Out of scope

- Transformers between databases (v0.4).
- Other database types, message queues, APIs, transformation triggers as
  scheduler targets (v0.5, D118).
- A sped-up clock, a forged history, time compression (D114, D132).
- Classroom swarms of student laptops, which cannot stay up for the
  aging (D125).
- Random GM events, pausing or triggering load (D117, D131).
- A PgBouncer metrics brick (D139).
- A scoring system (post-v1.0, D120).
- Kubernetes (future work; portability stays a requirement, D22, D122).

## Definition of done (accepted, D146; revised by D150, D151 and D157: master spec section 17 wins)

1. The `scheduler` and `pgbouncer` bricks at 0.1.0, with their GM
   documentation, validators and footprints measured; the bricks that
   change bumped (`postgres` with the GM's connection reserve and its
   snapshot method, the monitoring bricks for report-only, the bastion if
   it publishes in host mode).
2. The format changes of [format-changes.md](format-changes.md) in the
   templates, the loader and the format skill; the eleven catalog faults
   moved to the new evidence `where`.
3. Six to eight new catalog faults, each with its injection, aging
   minimum, sealed check (cause first) and solvability description.
4. The new normal scenario, complete by the format skill, its scenario
   document generated.
5. `gmctl`: placement per host, images copied, `fit` per host, the shift,
   `start-load`, scheduled planting, the hand-over snapshot, `restart`,
   the extended `status`.
6. Short smoke tests green on one host and on armenelos plus the VPS.
7. The release gate's full aged run (D135, D150): the scenario aged for
   its declared minimum, after a short rehearsal, then a play-through as
   `player`; every fault's evidence reachable; the
   sealed checks right under load before and after fixes; one restart
   from the hand-over snapshot; the measured footprint and aged growth
   within the declared figures.
8. The GM skill updated: aging, the early check, no load control, the
   restart's confirmation and statement, the shift and the time zone in
   the starter pack.
9. Both existing scenarios still deploy (re-pinned where their bricks
   bumped), with no aging, having no scheduler node (D157).

## Depends on

- v0.1; v0.2 for monitoring that shows the load.

## Questions due in this version

None open: O82–O101 are answered (D124–D145). The owner's review of the
`(proposed)` items, [review-list.md](review-list.md), is closed (D146,
D152, D153). Narrowed by the
rulings and left for later versions: O11 (D118), O22 (D114, D125, D132),
O23 (D120, D134), O30 (D114), O38 (D120), O48 (D114).

Possible input: Bluebox ships its own load generator (Python,
realistic web-traffic patterns), but Bluebox itself is planned for v0.5
(O53).

## Status

Built in four waves from the [build plan](build-plan.md): waves 1 to 3
merged into `main` (5faff6c, 22ff556, be857ff); the wave 4 gate (passed
2026-10-28) and the release gate ran on `v0.3-w4`, before its merge.
Their runs are in [wave-log.md](wave-log.md), "Wave 4 gate passed —
2026-10-28" and "Release gate — started 2026-10-28". G9 confirmed and
G10 passed by the owner on 2026-10-29. Merging `v0.3-w4` into `main`
waits for the owner's word.

## Release notes

v0.3, release gate passed on 2026-10-29: every item passed, G9 confirmed
and G10 passed by the owner, RG-2, RG-3, RG-5, RG-8 and RG-9 fixed at the
gate. Released with it (D100): `postgres` 0.3.0, `bastion` 0.3.0,
`prometheus`, `postgres-exporter` and `grafana` 0.2.0, and the new
`scheduler` 0.1.0 and `pgbouncer` 0.1.0.

### What v0.3 delivers

- **`bricks/scheduler` 0.1.0**, the producers and consumers: a Python
  program running a query repository the GM writes (pools, sequences,
  builders), fixed-time jobs in `jobs.yaml`, a hidden `schedule.yaml` of
  traffic shapes seeded per game, a per-minute summary in its log and a
  metrics endpoint Prometheus scrapes; report-only or fixable, with
  write overrides per file.
- **`bricks/pgbouncer` 0.1.0**: PgBouncer 1.26.1 from `trixie-pgdg`
  (D177), `auth_query` through a lookup role, the players' `dba` in
  `stats_users` only, the console reached with plain `psql` on the node.
- **`postgres` 0.3.0**: the GM's connection reserve (two connections)
  and the check role `gm_check` the sealed checks connect as; the data
  volume snapshotted by `pg_basebackup`; reload wrappers restoring a
  seeded file's owner and mode.
- **`prometheus`, `postgres-exporter`, `grafana` 0.2.0**: report-only
  honoured on their files; Prometheus and Grafana snapshotted by a brief
  stop. **`bastion` 0.3.0**: pinned to the manager on several hosts, its
  ports open on that host only.
- **Real-time aging** for a scenario with scheduler nodes: `start-load`
  and T0, the shift by whole hours and the customer's time zone,
  `state` faults planted during the aging by host timers (`inject
  --at`), the early check and the hand-over check, the lost time and
  outages in `status`, an early hand-over refused. A scenario without
  scheduler nodes keeps v0.2's timeline (D157).
- **The hand-over snapshot and `restart`**, on the players' confirmation
  in so many words, rebuilding the game under a new id from the snapshot
  (or from nothing when it does not fit), credentials kept.
- **Several hosts** over Tailscale: per-node placement, `fit` per host,
  images copied over SSH with no registry, the overlay's MTU 1230 (D184)
  and its range the GM's (D183).
- **The formats**: `aging:`, `difficulty:`, `plant_at`, `write_overrides`,
  behavioural checks with a window, evidence by location (`node`,
  `bastion`, `report:<tool>`), the brick's `snapshot:` map and disk growth
  per hour; the eleven existing faults moved to the new evidence form and
  the GM check role.
- **Eight new catalog faults** in `faults/`: `scheduler-query-error`,
  `scheduler-update-without-where`, `scheduler-report-unbounded`,
  `scheduler-insert-retry-duplicates`, `scheduler-transaction-held-open`,
  `scheduler-batch-at-peak`, `scheduler-job-wrong-timezone`,
  `pgbouncer-pool-too-small`.
- **The scenario `tarnbeck-outdoor-shop`**: an outdoor gear web shop,
  one database behind PgBouncer, a producer and a consumer, Prometheus,
  the exporter and Grafana; ten fault instances (seven new faults and
  three existing ones, four hidden, f8 planted during the aging), issues
  I1 to I4 (fix) and I5 (propose), sixteen hours of aging, 240 minutes of
  play, designed for two hosts and playable on one. Approved under G7.
- **`bookshop-new-server` and `fernway-clinics-monitoring`** re-pinned,
  with no aging.
- **The skills**: `game-master` (aging, the early check, no load control,
  the restart's confirmation and statement, the shift and the time zone
  in the starter pack), `scenario-format`, `scenario-document`.
- **Tests**: unit tests (658), the scheduler's own (60), seven stack
  tests, the fixtures `fixture-load` and `fixture-v03-refusals`,
  `smoke-load.sh` and the unattended `rehearsal.sh`.

### Release gate results

Run on `v0.3-w4` on 2026-10-28 and 2026-10-29 on armenelos, at κ = 1.
GM sessions were fresh agents reading the `game-master` skill; the driver
played the initiator; a verifier played as `player` through the bastion
and the web front only. Every item passed.

1. **Bricks: PASS.** Every brick's `docs/gm.md` against its `brick.yaml`,
   validators and measured footprints.
2. **Formats: PASS.** Templates, loader and format skill; the eleven
   faults in the new evidence form, on `gm_check`.
3. **New faults: PASS.** All eight complete.
4. **Scenario: PASS.** `tarnbeck-outdoor-shop` complete, README current,
   G7 cleared.
5. **`gmctl`: PASS**, through items 6 to 8.
6. **Smoke tests and rehearsal: PASS**, at the wave 4 gate on this code:
   `smoke-load.sh` 73/73 on one host (on a re-run, see "Known issues")
   and on two; `smoke-scenario.sh` on
   tarnbeck 26/26 (one-host by design); `rehearsal.sh` on armenelos plus
   the VPS 53/53, the two-host deployment of tarnbeck.
7. **The aged run: PASS** (below).
8. **Play-through and restart: PASS.** All ten faults' evidence reachable
   where the answer key says; seven fixed, f2, f4 and f10 report or
   propose by design; sealed checks right before and after the fixes;
   one restart from the snapshot (G9); the final answer and feedback.
9. **Stance: PASS.** Pausing the load and triggering close-day refused; a
   passing mention of a restart and a question about it restarting
   nothing; an early hand-over refused, with when.
10. **Existing scenarios: PASS.** Each through its smoke deployment
    (bookshop 19 checks, fernway 18), with no aging.
11. **Forced failures: PASS.** A setup failure before T0 torn down and
    recorded (RG-9 found); a producer stopped for 4 minutes during the
    aging, recorded as lost time, the game left running.
12. **Quality command: PASS** at the wave 4 gate (d7cdbd5): unit 653,
    scheduler 60, seven builds, the seven stack tests, `smoke.sh` 60,
    `smoke-monitoring.sh` 43, the three scenario smokes. After the gate
    fixes: unit 658, scheduler 60, the bastion's and PgBouncer's stack
    tests, tarnbeck's smoke 26/26.
13. **Left for the build: PASS.** Every finding in its chunk's Record
    line and its brick's `docs/gm.md` (below).
14. **G10: passed** by the owner on 2026-10-29: "you may teardown. i'll
    let you fix what need to be fixed … you've done well."
15. **Release notes**: these.

### The aged run

`tarnbeck-outdoor-shop` on armenelos alone (G5: the rehearsal's peak of
577M plus about 1G fitted its available memory), playground `laptop`
declared 4 CPU / 4G / 18G, `fit` 7.75G of disk and 11.85G with the
snapshot, kept awake throughout (G8). Game
`tarnbeck-outdoor-shop-zcbdq5`.

- **Timeline (UTC)**: T0 2026-10-28T20:44:25Z; f8 planted by its host
  timer at 08:00:00Z; the early check fired by its timer at 11:44:25Z and
  passed; earliest hand-over 12:44:25Z; close-day 12:00:00–12:00:23Z
  (checkout p95 22.6 s that minute, the noon stall the story needs); the
  hand-over check passed at 12:47:13Z; handed over at 13:56:58Z, 17h12m
  after T0. **Lost time 0**, no outage: at 11:52Z each scheduler had
  909 per-minute summaries with no gap, and the nightly roll-up and the
  export had run.
- **Memory at the customer's noon** (`docker stats` each minute): game
  peak **632MiB**; grafana 203M, db 192M (CPU 0.32), prometheus 128M (its
  aged TSDB; 65M in the rehearsal), producer 43M, consumer 30M, exporter
  25M, pooler 12M, bastion 6M, each within its reservation; armenelos'
  lowest available memory 3763MiB. No node restarted or OOM-killed.
- **Disk**: the game's 34 volumes **246.59M** at the hand-over snapshot,
  against `fit`'s 11.85G; the snapshot 34 copies, about 11 s, Prometheus
  and Grafana stopped about 1 s each.
- **The players** found all ten faults, every answer acceptable; the
  feedback named three improvements.
- **One restart** from the snapshot, confirmed by the owner in so many
  words (G9): 31 s, new game id, both schedulers resumed from their
  marker, the faults back, the passwords still valid, the maintenance
  window 13:56–14:29 told.

Decided by the owner on 2026-10-29: aged runs are one-off, not a
standing gate item; none before v1.0, maybe not even then.

### Measured figures

On armenelos (AMD Ryzen 5 PRO 8640HS, 11.3 GiB, Debian 13, Docker
29.9.1) and the VPS `vps-5718ad52` (4 vCPU, 7.6 GiB), 2026-10-28.

- **The rehearsal on two hosts** (chunk 15b; re-run at the wave 4 gate):
  game peak 577M (273M armenelos, 308M the VPS); 583M on the re-run.
  Per node at most: db 206M, Grafana 182M, Prometheus 66M, producer 39M,
  consumer 37M, exporter 36M, pooler 20M, bastion 11M; CPU 0.03 to 0.20.
  Snapshot 215M in 52 s; restart across both hosts 92 s (87 s on the
  re-run).
- **Growth per hour**, carried into each `brick.yaml` as
  `disk_growth_per_hour`: postgres data 4.6M and log 0.7M (declared 8M),
  Prometheus' TSDB 3.1M (4M), PgBouncer's log 0.1M (1M), the schedulers'
  logs 0.12M and 0.03M (1M), Grafana 5K (1M). Fernway's 256MB TSDB bound
  holds (under 16M over four hours), tarnbeck's 384MB too (about 80M over
  twenty hours).
- **f7, the pool too small**: at the peak with a pool of 3, clients wait
  in 39% of samples, up to 16, `maxwait` 8.8 s; a pool of 6 queues about
  1%, the fault's `min-pool-size`.
- **At rest**: scheduler 17M to 26M, PgBouncer 11.1MiB, postgres 59M.
- **Images**: postgres 262MB, bastion 185MB, prometheus 488MB,
  postgres-exporter 165MB, grafana 866MB, scheduler 172MB, pgbouncer
  182MB.

### Left for the build (master spec 20), as found

- **Footprints and aged growth**: above; each brick's `docs/gm.md`,
  "Footprint".
- **MTU and Swarm over Tailscale**: option 1230 gives 1180 inside a node
  (D184); Swarm bound to `tailscale0` (`--advertise-addr`,
  `--listen-addr`, `--data-path-addr`).
- **The image copy**: `docker save <image> | docker --context
  dbagm-<host> load` through the host's SSH Docker context, an image
  held under the same id skipped (D181).
- **`auth_query`**: `SELECT usename, passwd FROM gm_pgbouncer.lookup($1)`
  as `pgbouncer_lookup`, `auth_dbname` `postgres`, the console included.
- **The GM's reserve**: `reserved_connections = 2` on the command line,
  `superuser_reserved_connections` kept at 3.
- **Setup actions on the manager**: persistent systemd user timers,
  named in `status` (D173); held through the aged run.
- **Outages**: read from the per-minute summaries and the task history,
  a pruned history flagged (D174).
- **The loader's `pg_basebackup` check**: its `pg_hba.conf` reading
  ignores `+group`, `@file` and `include`.
- **`gm_check` on `pg_hba_file_rules`**: `SELECT` on the view and
  `EXECUTE` on the function behind it.
- **`pg_basebackup` on a read-only root**: `-X fetch` with a temporary
  slot held, no snapshot volume.

### Known gaps of the access model

All stand as [access-model.md](access-model.md) section 11 states them:

- when the players own the host, the bastion-only rule and the answer
  key's secrecy rest on trust;
- a player in the GM session can see the setup dialogue;
- credentials are shared by all players and cannot be rotated during a
  game, a restart included;
- `ALTER SYSTEM` by `dba` on a report-only database node, not reachable
  in v0.3;
- the GM's connection reserve can be used up by `dba`;
- Grafana's write policy cannot be enforced on a report-only node, and
  Grafana administration is forbidden by rule, not prevented;
- Prometheus has no login of its own, reachable from every node;
- a fixable builder is code run as the scheduler's account, and can
  print the schedule;
- the traffic can be inferred from the logs and statistics;
- the web front uses plain HTTP.

### Fixes made at the release gate

- **RG-1 (not a defect)**: the player's SSH key is refused on the
  bastion, which is password-only by design; the key is for the hops.
  Tarnbeck's starter pack now says so (cfeebb9).
- **RG-2 (fixed, 3cde51c)**: plain `psql` on `pooler` failed; PgBouncer
  now writes the player's `~/.pgpass` at each start, so f7's answer key
  works as written.
- **RG-3 (fixed, e4dca09)**: f4 delays f3's unique constraint and each
  `CREATE INDEX CONCURRENTLY` (about five minutes, inserts queuing);
  the answer key says so, f3 and f4 marked `conflicts-with`.
- **RG-5 (fixed, e4dca09)**: PostgreSQL 18's autovacuum log says
  "removable cutoff", now the answer key's wording for f4.
- **RG-8 (fixed, e4dca09)**: f3's check counts the duplicates still in
  the table, so deleting them alone is not a fix.
- **RG-9 (fixed, d2e3999)**: a failed `psql` step recorded psql's first
  output line as the reason; it now records psql's `ERROR:` line.

### Known issues

Found by the release gate, kept as known gaps; none blocked it.

- **RG-4**: f5's Prometheus evidence is weak: the latency histogram's
  buckets (2.5, 5, 10, 30 s) hide the noon stall among other bumps. The
  logs show it plainly.
- **RG-6**: Grafana's statement panels are labelled by `queryid` only,
  not by the query's text (f2's evidence there).
- **RG-7**: the database log's `client=` shows the same address,
  10.0.1.18, for most connections.
- **`smoke-load.sh`, intermittent**: its first one-host run at the wave
  4 gate failed 3 of 73 checks (18 producer errors in the first judged
  minute, an every-minute job not run), not traced, the scheduler's log
  lost at teardown; the re-run and the two-host run passed 73/73.
- Also seen: the producer's first minute after a restart carries a few
  more errors while it reconnects.
