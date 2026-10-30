> **Archived 2026-10-30.** One of v0.3's eight drafts, consolidated into the v0.3 master spec on 2026-10-22 and kept since as the working record, stale by design where the master spec supersedes it; v0.3 was released on 2026-10-30 and merged into `main` as cba7be3. Live summary: [v0.3 master spec](../../versions/v0.3/master-spec.md). Relative links were written from `specs/versions/v0.3/`: `master-spec.md`, `access-model.md`, `README.md` and `wave-log.md` are in `../../versions/v0.3/`, and `../v0.2/` is `../../versions/v0.2/`; links between the files archived here still resolve.

# v0.3 — the scheduler and the query repository

Status: draft v3, consolidated

Consolidated into the [master spec](master-spec.md) and its [access
model](access-model.md) on 2026-10-22; its `(proposed)` items were accepted
as proposed (D146). Kept as v0.3's working record until the milestone is
archived; where it and the master spec differ, the master spec wins.

How producers and consumers work in v0.3: one brick that is mostly a
scheduler, running queries the GM wrote at design time. Settled: the
owner's design (D115–D118) and his answers of 2026-10-22 (D129–D133,
D136, D137); file names, formats and figures are (proposed) until he
reviews this draft. Timeline and aging:
[aging-and-timeline.md](aging-and-timeline.md); load sizing:
[load-and-capacity.md](load-and-capacity.md); faults the scheduler
carries: [faults-with-activity.md](faults-with-activity.md); the format
changes all this needs: [format-changes.md](format-changes.md).

## Terms

One term per concept; these move into [concept.md](../../concept.md)'s
vocabulary at consolidation.

| Term | Meaning |
|---|---|
| **scheduler** | The brick (id `scheduler`, proposed) that runs producer and consumer nodes. A node of it is a *producer* or a *consumer* by its role ([formats.md](../../formats.md), "Roles"), not by its code |
| **query repository** | The node's file of queries, written by the GM at design time: a key maps to a query, a list of queries, or a builder (D115) |
| **query** | One operation sent through a driver. In v0.3 always SQL against PostgreSQL (D118); the word stays when other drivers come |
| **pool** | A key mapped to a list of queries: each call picks one (D133) |
| **builder** | Code in the repository that returns the statements to run, given the intensity and options: `builder(intensity, options)` (D115) |
| **schedule** | The node's scheduling script: which keys run, when, how often, how hard. Hidden from the players except its fixed-time operations (D116, D130) |
| **stream** | A schedule entry generating continuous traffic: a rate, a traffic shape, randomisation |
| **fixed-time operation** | A schedule entry running a key at a fixed time: a batch, a daily or nightly job. The only scheduling players read and may change (D116) |
| **timeline change** | A change to a stream or a fault at a fixed moment of the aging, written at design time (D127) |
| **intensity** | A multiplier on the node's load, the scenario's (D115) |
| **traffic shape** | How a stream's rate varies over the day: peaks, low loads, quiet nights (D115) |
| **driver** | The pluggable part that turns a query into a call on a target: SQL on PostgreSQL first (D137) |

## What the brick is (D115)

The brick is mostly a scheduler: it holds no business logic of its own.
The SQL (later the API calls, messages, transformation triggers) is the
scenario's, written by the GM when it designs the scenario. One scheduler
node runs one schedule against one query repository. A topology may have
several producer and consumer nodes, each with its own pair.

Shape (proposed):

- A full node of its own, like every brick since v0.2 (D74): s6, `sshd`,
  the `player` account, a public validator, the node-health script when
  the topology has a metrics store.
- A small Python program (Python 3.13 on Debian 13, `psycopg` from the
  distribution), asyncio-based: one task per stream and per fixed-time
  operation, each with its own connections. s6 restarts it if it dies;
  a restart resumes the schedule at the current time, never replays
  what it missed.
- Footprint (to measure): limits 0.25 CPU / 128M, reservations 0.1 CPU /
  64M, disk for its log.
- Files, all seed-once configs on the node's volumes (D11):
  - `queries.yaml` and an optional `builders/` directory: the query
    repository;
  - `jobs.yaml`: the fixed-time operations;
  - `schedule.yaml`: the streams, the intensity, the connections and the
    timeline changes, root-owned, mode 0400, not readable by `player`
    (D130).
- A log of its own (see "What the players reach").
- Its database roles are the scenario's, created by the data load; their
  passwords are generated secrets (D79), mounted into the scheduler node
  and set in the database at the data load.

## The query repository

A key maps to one of three things (D115). Format (proposed):

```yaml
queries:
  orders.insert:                       # key -> query
    sql: >-
      INSERT INTO orders (customer_id, amount)
      VALUES (%(customer_id)s, %(amount)s)
    params:
      customer_id: {int: [1, 5000]}
      amount: {decimal: [5, 500, 2]}

  catalog.lookup:                      # key -> [queries]: a pool, one picked per call
    - sql: SELECT * FROM products WHERE id = %(id)s
      params: {id: {int: [1, 20000]}}
      weight: 8
    - sql: SELECT * FROM products WHERE name ILIKE %(pattern)s
      params: {pattern: {choice: ['%lamp%', '%desk%']}}
      weight: 2

  invoices.close-day:                  # a sequence, run as one transaction
    transaction: {isolation: read committed}
    steps:
      - sql: UPDATE invoices SET closed = true WHERE day = current_date - 1
      - sql: INSERT INTO ledger SELECT ... FROM invoices WHERE day = current_date - 1

  reports.revenue:                     # key -> builder(intensity, options)
    builder: builders/revenue.py:build
    options: {months: 3}
```

- **A list is a pool** (D133): each call picks one entry, by weight when
  weights are given, evenly otherwise.
- **A sequence** of statements is a `steps:` entry (D133), run in order
  on one connection.
- **Transactions or not** (D115): an entry runs in autocommit unless it
  carries `transaction:`: its isolation level, and optionally a hold, the
  time the client keeps the transaction open before committing, which is
  how "transactions taking too long" and `idle in transaction` sessions
  are made.
- **Parameters** come from small generators: an integer or decimal range,
  a choice from a list, a sequence, the current time. Anything richer is
  a builder's job. All randomness comes from the game's seed (D136).
- **Builders** are Python functions in `builders/`, called with the
  intensity and the entry's options, returning the statements (with
  their parameters) to run and whether they run as one transaction. They
  exist for queries whose shape depends on the load: a batch whose size
  grows with intensity, a BI query whose date range is an option. A
  builder the players may edit is code they may run as the scheduler's
  service account; accepted on the trust line (D133), the account
  holding no more than the node already gives.

## The schedule

Hidden from the players (D116, D130). What a schedule says (D115),
format (proposed):

```yaml
intensity: 1.0                         # the scenario's; never rescaled per playground
connections:
  app:                                 # a named connection: driver, target, role, pooling
    driver: sql/postgresql             # the only driver in v0.3 (D137)
    target: pgbouncer:6432/shop        # or db:5432/shop
    role: shop_app                     # password: a generated secret
    pool: {size: 5}                    # or `per-call: true`: connect and disconnect each call
streams:
  - key: orders.insert
    connection: app
    rate: 40/min                       # at intensity 1.0, before the traffic shape
    arrivals: poisson                  # or `even`
    shape: business-hours
    concurrency: 2
  - key: catalog.lookup                # a pool: one of its queries per call
    connection: app
    rate: 120/min
    shape: business-hours
shapes:
  business-hours:                      # hourly multipliers, in scenario time
    hours: {"00-06": 0.1, "07-08": 0.6, "09-11": 1.0, "12": 1.6, "13-17": 1.0, "18-23": 0.3}
timeline:                              # changes at fixed moments, during aging only (D127)
  - at: handover-20h                   # relative to hand-over, so the shift (D129) carries it
    stream: catalog.lookup
    set: {key: catalog.lookup-v2}      # e.g. "the release of yesterday 14:00"
```

- **Intensity** multiplies every stream's rate and is passed to builders.
  It is the scenario's, absolute, like resource limits and envelopes
  (D32): the local implementation does not rescale it to the playground,
  since rescaling would change the evidence (proposed).
- **Pool selection**: a stream runs a key; when the key is a pool, one of
  its queries per call (D133).
- **Randomisation**: arrivals (Poisson or even), parameter values, pool
  picks, all from the game's seed. The seed is recorded in the local
  implementation; a restart takes a new one, so a replayed game may
  differ (D136, D123).
- **Traffic shapes**: hourly multipliers over the day, optionally per
  weekday, so the aged days look like days: a lunchtime peak, quiet
  nights (D115; "meaningful" days:
  [aging-and-timeline.md](aging-and-timeline.md)).
- **Scenario time**: shapes, fixed-time operations and the timeline are
  written in the scenario's time; the local implementation shifts all of
  them by whole hours so the game window gets the designed load, every
  clock staying real UTC (D129; [aging-and-timeline.md](aging-and-timeline.md),
  "Time of day").
- **Connections**: a driver, a target (the database directly, or through
  PgBouncer, [pgbouncer.md](pgbouncer.md)), a role, and the pooling.
  Pooling matters as much as the SQL: a consumer that connects per call,
  or never returns its connections, is a fault in its own right
  ([faults-with-activity.md](faults-with-activity.md)).
- **Timeline changes** (D127): a stream's key, rate or connection may
  change at a fixed moment of the aging, before hand-over, never after.
  The loader refuses a timeline entry at or after hand-over (proposed).

## Fixed-time operations

Batch, daily or nightly jobs: a key run at a fixed time. The only part
of the scheduling players read, and the only part they may change (D116).
Format (proposed), in `jobs.yaml`, cron-like and readable as such:

```yaml
jobs:
  - name: close-day
    key: invoices.close-day
    connection: app
    at: "30 1 * * *"                   # cron expression, as the players see it (shifted, D129)
    timezone: UTC                      # D81's default; a wrong zone is a plantable fault
```

- Players change a job's time or zone where the scenario allows (the
  file's write policy, D130); they never change streams.
- Their edit takes effect on the scheduler's next reload of `jobs.yaml`,
  through a `sudo` wrapper, as on the other nodes (proposed).
- There is no "run now" (D131). Moving a job's time is how a player
  verifies a fix to it within the game; v0.3 has no time compression
  (D132).
- A job that cannot start (overlapping its previous run, its connection
  refused) is logged and skipped, never queued (proposed): a backlog would
  be an event nobody scheduled.
- `jobs.yaml` is rendered with the shift already applied (D129), so the
  times the players read are the real UTC times the jobs run at.

## No events outside the schedule (D117, D131)

The scheduler is the only source of activity: no random GM events, no
GM intervention in the load. From the start of the aging to the end of
the game, every producer and consumer follows its schedule and nothing
else. During a game nobody, GM or player, pauses, speeds up or triggers
the load, not even for the final checks (D131).

## What the players reach (D116, D130)

- **Read**: the query repository (`queries.yaml`, `builders/`),
  `jobs.yaml`, the scheduler's log, and its configuration other than
  `schedule.yaml` (D130).
- **Edit**, where the scenario allows it: the repository (fixing a faulty
  query) and the fixed-time operations' schedules. Write policy is per
  file (D130): the repository may be fixable while the rest of the node
  is report-only, through the scenario's `write_overrides` (D143).
- **Never**: `schedule.yaml` (the streams, the intensity, the
  connections, the timeline), root-only (D130).
- **The log** (proposed contents): every fixed-time run (start, end, rows,
  error), every error (key, SQLSTATE, message), and a per-key summary
  every minute (calls, errors, latency percentiles). It names keys, never
  rates or shapes, though a patient reader can infer the traffic from it,
  as from the database's own logs.

## Drivers (D118, D137)

v0.3 sends SQL to PostgreSQL. From v0.5 the scheduler reaches other
database types, message queues, APIs and the tools that trigger
transformation layers. The driver is pluggable (D137), so v0.5 adds a
driver, not a format:

- a connection names its driver (`sql/postgresql` in v0.3);
- a driver offers connect, run one statement with its parameters, begin,
  commit, roll back, close, and reports a latency and an error code
  (proposed interface);
- the repository format does not change when a driver is added; only the
  entry's body (SQL here, a message or a request later) does.

## Its own monitoring (proposed)

The scheduler exposes its per-key counters (calls, errors, latency
histogram) on a metrics endpoint the topology's Prometheus may scrape, as
an application would. Leaving it unscraped is then a monitoring fault
like any other target left out. The same counters are a stable source
for the sealed checks under load (D124), read through the exec verb
whether Prometheus scrapes them or not.

## Open points

None; the `(proposed)` items are in [review-list.md](review-list.md).
