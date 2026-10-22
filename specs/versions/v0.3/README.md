# v0.3 — producers and consumers

Status: drafting (page draft v3). No master spec: it is consolidated only
when the owner says the drafts are ready. The owner's rulings of
2026-10-22 are D114–D123, and his answers to the first round of
questions D124–D140; the questions still due are listed below.

## Drafts

| Document | Purpose | Status |
|---|---|---|
| [scheduler.md](scheduler.md) | The scheduler brick, the query repository, the schedule, fixed-time operations, what the players reach, drivers | draft v2 |
| [aging-and-timeline.md](aging-and-timeline.md) | Real-time aging, "meaningful" days, time of day, the timeline from deployment to teardown, the restart | draft v2 |
| [load-and-capacity.md](load-and-capacity.md) | Calibrating load, `max_connections`, load control, always-on hosts, several hosts, the hosts at hand | draft v2 |
| [faults-with-activity.md](faults-with-activity.md) | Difficulty, v0.3's scenario, fault families that need activity, candidate faults | draft v2 |
| [checks-under-load.md](checks-under-load.md) | Sealed checks, validators and smoke tests on a living system | draft v2 |
| [pgbouncer.md](pgbouncer.md) | The PgBouncer brick | draft v2 |
| [carried-items.md](carried-items.md) | Earlier rulings and known issues landing in v0.3 | draft v2 |
| [format-changes.md](format-changes.md) | Every change to the formats, script contracts, local implementation and `gmctl` | draft v1 |

## Goal

In the owner's words (D47):

- Producers, "the first being the most important: they will schedule data
  ingestion, load spikes, etc. and are the main opportunity for
  ill-formatted requests, misbehaving requests, or ill-targeted requests."
- "Consumers have it similar, albeit on their end it is more probably a
  question of breadth of query: taking in too much, transactions taking
  too long, BI queries, etc."

## Settled (2026-10-22)

- **Aging is real time** (D114): the stack runs in the background for at
  least two full, meaningful days before hand-over; no sped-up clock, no
  forged history, no time compression (D132); on always-on hosts only
  (D125) ([aging-and-timeline.md](aging-and-timeline.md)).
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
  [load-and-capacity.md](load-and-capacity.md)).
- **A restart rebuilds the game from scratch** on the players' explicit
  confirmation (D110, D123), from a hand-over snapshot where the disk
  allows, otherwise with no history and the lost evidence named first;
  credentials kept, game id renewed (D126).
- **Every carried item is taken** (D140; [carried-items.md](carried-items.md)).
- **The release gate includes one full aged run** (D135).

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
- Multi-host: per-node placement, a registry, `fit` per host.
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

## Definition of done (proposed)

1. The `scheduler` and `pgbouncer` bricks at 0.1.0, with their GM
   documentation, validators and footprints measured; the bricks that
   change bumped (`postgres`, the monitoring bricks for report-only, the
   bastion if it publishes in host mode).
2. The format changes of [format-changes.md](format-changes.md) in the
   templates, the loader and the format skill; the eleven catalog faults
   moved to the new evidence `where`.
3. Six to eight new catalog faults, each with its injection, aging
   minimum, sealed check (cause first) and solvability description.
4. The new normal scenario, complete by the format skill, its scenario
   document generated.
5. `gmctl`: placement per host, the registry, `fit` per host, the shift,
   `start-load`, scheduled planting, the hand-over snapshot, `restart`,
   the extended `status`.
6. Short smoke tests green on one host and on armenelos plus the VPS.
7. The release gate's full aged run (D135): at least 48 hours of aging,
   then a play-through as `player`; every fault's evidence reachable; the
   sealed checks right under load before and after fixes; one restart
   from the hand-over snapshot; the measured footprint and aged growth
   within the declared figures.
8. The GM skill updated: aging, the early check, no load control, the
   restart's confirmation and statement, the shift and the time zone in
   the starter pack.
9. Both existing scenarios still deploy (re-pinned where their bricks
   bumped), `fernway-clinics-monitoring` with its retention raised.

## Depends on

- v0.1; v0.2 for monitoring that shows the load.

## Questions due in this version

Ranked, most important first:

- O81: the rest of the restart: who may confirm, what the GM states
  first, how it is recorded, its place in the access model.
- O98: how the hand-over snapshot is taken.
- O99: the per-file write policy in the format.
- O100: a connection reserve of the GM's own.
- O101: which evidence locations a fault definition may name.
- Narrowed by the rulings: O11 (D118), O22 (D114, D125, D132), O23
  (D120, D134), O30 (D114), O38 (D120), O48 (D114).

Possible input: Bluebox ships its own load generator (Python,
realistic web-traffic patterns), but Bluebox itself is planned for v0.5
(O53).
