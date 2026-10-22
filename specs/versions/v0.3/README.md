# v0.3 — producers and consumers

Status: **spec approved on 2026-10-22** (D154): the [master spec](master-spec.md)
and its [access model](access-model.md), consolidated the same day,
revised after the independent review (REJECT, seven blocking issues, all
fixed: D151), the owner's answers to it (D147–D149), his eight-hour aging
floor (D150) and the re-review's corrections (OKAY, D155); amended the
same day by the ruling that only a scenario with scheduler nodes ages
(D157, D158) (page draft v8). The owner's rulings of 2026-10-22 are
D114–D123, his answers to two rounds of questions D124–D145, his
acceptance of the review list D146, D152 and D153. No v0.3 question is
open. The [build plan](build-plan.md) is **approved** (D156), with the
VPS rule (D159); wave 1 starts on 2026-10-23 in a fresh driver session.

## Documents

| Document | Purpose | Status |
|---|---|---|
| [master-spec.md](master-spec.md) | The consolidated v0.3 specification | approved 2026-10-22 (D154), amended by D157 and D158 |
| [access-model.md](access-model.md) | Who may do what in a v0.3 game | approved 2026-10-22 (D154), amended by D157 and D158 |
| [build-plan.md](build-plan.md) | The v0.3 build: chunks, waves, gates, release gate | v2, approved 2026-10-22 (D156); wave 1 ready |
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
