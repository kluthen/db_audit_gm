# v0.3 — producers and consumers

Status: drafting opened 2026-10-22 (page draft v2). No master spec: it is
consolidated only when the owner says the drafts are ready. The owner's
rulings of 2026-10-22 are D114–D123; the questions due are listed below.

## Drafts

| Document | Purpose | Status |
|---|---|---|
| [scheduler.md](scheduler.md) | The scheduler brick, the query repository, the schedule, fixed-time operations, what the players reach, drivers | draft v1 |
| [aging-and-timeline.md](aging-and-timeline.md) | Real-time aging, what "meaningful" means, the timeline from deployment to teardown, the restart | draft v1 |
| [load-and-capacity.md](load-and-capacity.md) | Calibrating load, `max_connections`, load control, one host or several, the hosts at hand | draft v1 |
| [faults-with-activity.md](faults-with-activity.md) | Difficulty, fault families that need activity, candidate faults | draft v1 |
| [checks-under-load.md](checks-under-load.md) | Sealed checks, validators and smoke tests on a living system | draft v1 |
| [pgbouncer.md](pgbouncer.md) | The PgBouncer brick | draft v1 |
| [carried-items.md](carried-items.md) | Earlier rulings and known issues landing in v0.3 | draft v1 |

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
  forged history ([aging-and-timeline.md](aging-and-timeline.md)).
- **Producers and consumers are scheduler nodes** running a query
  repository the GM writes at design time: a key maps to a query, a list
  of queries, or a builder of the intensity and options; schedules set
  intensity, pool selection, fixed-time queries, randomisation, traffic
  shapes, transactions (D115; [scheduler.md](scheduler.md)).
- **Players** read the repository and may edit it where the scenario
  allows; of the scheduling they read and change only the fixed-time
  operations (D116).
- **No events outside the schedule**: no random GM events (D117).
- **SQL against PostgreSQL** in v0.3; other databases, message queues,
  APIs and transformation triggers from v0.5, the scheduler designed for
  extension (D118).
- **A PgBouncer brick**, optional in any scenario (D119;
  [pgbouncer.md](pgbouncer.md)).
- **Difficulty** is a fault count: each fault 1, easy 5, normal 10, hard
  20; a scoring system is post-v1.0 (D120;
  [faults-with-activity.md](faults-with-activity.md)).
- **`ALTER SYSTEM` on report-only database nodes** is accepted on the
  trust line (D121).
- **Capacity** is for the GM and the initiator to discuss; games last at
  most four hours; minimum capacity may rise; Swarm is the platform;
  armenelos and the VPS share a tailnet (D122;
  [load-and-capacity.md](load-and-capacity.md)).
- **A restart rebuilds the game from scratch** and may differ, on the
  players' explicit confirmation (D110, D123).

## In scope

- The scheduler brick for producers and consumers, its query repository,
  schedules and fixed-time operations.
- Real-time aging and the timeline it imposes.
- Load calibrated against the nerfed databases: enough to show symptoms,
  not enough to saturate the host.
- Fault families that need activity: contention, lock waits, bloat
  growing, long transactions, connection exhaustion, data-flow defects,
  faulty requests, scheduled jobs, pooling.
- The PgBouncer brick.
- Checks that hold on a living system.
- Report-only nodes in practice: producers and consumers are observed,
  their repository fixable where the scenario allows.
- Restarting a game (D110, D123): the GM tears down and rebuilds the
  whole stack, only on the players' **explicit confirmation**: "we can't
  have a passing comment just restart the game, as it's highly breaking
  change". A passing mention, or a question about restarting, never
  restarts a game. Mechanics: O81, O84.
- Carried items, proposed: report-only monitoring nodes (D108), O78's
  format change, RG-2, RG-3, Prometheus retention
  ([carried-items.md](carried-items.md); O97).
- Proposed: multi-host over Tailscale (O46).

## Out of scope

- Transformers between databases (v0.4).
- Other database types, message queues, APIs, transformation triggers as
  scheduler targets (v0.5, D118).
- A sped-up clock or a forged history (D114).
- Random GM events (D117).
- A scoring system (post-v1.0, D120).
- Kubernetes (future work; portability stays a requirement, D22, D122).

## Depends on

- v0.1; v0.2 for monitoring that shows the load.

## Questions due in this version

Ranked, most important first:

- O82: how checks judge "present" and "fixed" under load.
- O83: playgrounds that cannot stay up for the two days of aging (a
  classroom of student laptops).
- O84: restart and real-time aging; with O81, the rest of the restart.
- O85: scheduled steps during aging (a fault or a query change at a
  fixed moment before hand-over).
- O46: multi-host in v0.3.
- O86: the traffic shapes and the class's time of day.
- O87: what players see on scheduler nodes beyond the repository and the
  fixed-time operations.
- O88: nobody pauses or triggers the load.
- O89: time compression in v0.3.
- O90: the repository's semantics (lists, builders).
- O91: v0.3's scenario, its faults, and the difficulty reading.
- O92: one full aged run before the release gate.
- O93: the seed. O94: the pluggable driver. O95: `max_connections`.
  O96: PgBouncer's monitoring and console. O97: which carried items.
- Narrowed by the rulings: O11 (D118), O22 (D114), O23 (D120), O30
  (D114), O38 (D120), O48 (D114).

Possible input: Bluebox ships its own load generator (Python,
realistic web-traffic patterns), but Bluebox itself is planned for v0.5
(O53).
