# v0.3 — the scheduler and the query repository

Status: draft v1

How producers and consumers work in v0.3: one brick that is mostly a
scheduler, running queries the GM wrote at design time. The owner's
design (D115–D118); everything else here is (proposed). Timeline and
aging: [aging-and-timeline.md](aging-and-timeline.md); load sizing:
[load-and-capacity.md](load-and-capacity.md); faults the scheduler
carries: [faults-with-activity.md](faults-with-activity.md).

## Terms

One term per concept; these move into [concept.md](../../concept.md)'s
vocabulary at consolidation.

| Term | Meaning |
|---|---|
| **scheduler** | The brick (id `scheduler`, proposed) that runs producer and consumer nodes. A node of it is a *producer* or a *consumer* by its role ([formats.md](../../formats.md), "Roles"), not by its code |
| **query repository** | The node's file of queries, written by the GM at design time: a key maps to a query, a list of queries, or a builder (D115) |
| **query** | One operation sent through a driver. In v0.3 always SQL against PostgreSQL (D118); the word stays when other drivers come |
| **builder** | Code in the repository that returns the statements to run, given the intensity and options: `builder(intensity, options)` (D115) |
| **schedule** | The node's scheduling script: which keys run, when, how often, how hard. Hidden from the players except its fixed-time operations (D116) |
| **stream** | A schedule entry generating continuous traffic: a rate, a traffic shape, randomisation |
| **fixed-time operation** | A schedule entry running a key at a fixed time: a batch, a daily or nightly job. The only scheduling players read and may change (D116) |
| **intensity** | A multiplier on the node's load, the scenario's (D115) |
| **traffic shape** | How a stream's rate varies over the day: peaks, low loads, quiet nights (D115) |
| **driver** | The part that turns a query into a call on a target: SQL on PostgreSQL in v0.3 (proposed: pluggable, O94) |

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
  operation, each with its own connections.
- Footprint (proposed, to measure): limits 0.25 CPU / 128M, reservations
  0.1 CPU / 64M, disk for its log.
- Files, all seed-once configs on the node's volumes (D11):
  - `queries.yaml` and an optional `builders/` directory: the query
    repository;
  - `jobs.yaml`: the fixed-time operations;
  - `schedule.yaml`: the streams, the intensity and the connections,
    root-owned and not readable by `player` (D116).
- A log of its own (see "What the players reach").

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

  invoices.close-day:                  # one transaction of several statements
    transaction: {isolation: read committed}
    steps:
      - sql: UPDATE invoices SET closed = true WHERE day = current_date - 1
      - sql: INSERT INTO ledger SELECT ... FROM invoices WHERE day = current_date - 1

  reports.revenue:                     # key -> builder(intensity, options)
    builder: builders/revenue.py:build
    options: {months: 3}
```

- **Parameters** come from small generators: an integer or decimal range,
  a choice from a list, a sequence, the current time. The randomness is
  seeded (O93). Anything richer is a builder's job.
- **A list is a pool** (proposed; O90): each call picks one entry, by
  weight when given. A sequence of statements is a `steps:` entry.
- **Transactions or not** (D115): an entry runs in autocommit unless it
  carries `transaction:` (its isolation level, and optionally a hold: the
  time the client keeps the transaction open before committing, which is
  how "transactions taking too long" and `idle in transaction` sessions
  are made).
- **Builders** are Python functions in `builders/`, called with the
  intensity and the entry's options, returning the statements (with
  their parameters) to run, and whether they run as one transaction.
  They exist for queries whose shape depends on the load: a batch whose
  size grows with intensity, a BI query whose date range is an option.
  A builder the players may edit is code they may run as the scheduler's
  service account; accepted on the trust line, the account holding no
  more than the node already gives (O90).

## The schedule

Hidden from the players (D116). What a schedule can say (D115), format
(proposed):

```yaml
intensity: 1.0                         # the scenario's; never recomputed per playground
seed: from-game                        # O93
connections:
  app:                                 # a named connection: target, role, pooling
    target: pgbouncer:6432/shop        # or db:5432/shop; v0.3 targets are PostgreSQL only
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
  business-hours:                      # hourly multipliers, UTC (D81), by weekday if needed
    hours: {"00-06": 0.1, "07-08": 0.6, "09-11": 1.0, "12": 1.6, "13-17": 1.0, "18-23": 0.3}
```

- **Intensity** multiplies every stream's rate and is passed to builders.
  It is the scenario's, absolute, like resource limits and envelopes
  (D32): the local implementation does not rescale it to the playground,
  since rescaling would change the evidence (proposed).
- **Pool selection**: a stream runs a key; when the key is a pool, one of
  its queries per call (above).
- **Randomisation**: arrivals (Poisson or even), parameter values, pool
  picks; all from the game's seed (O93).
- **Traffic shapes**: hourly multipliers over the day, optionally per
  weekday, so the aged days look like days: a lunchtime peak, quiet
  nights (D115; "meaningful" days: [aging-and-timeline.md](aging-and-timeline.md)).
  Whether a shape is wall-clock UTC or shifted to the class's hour: O86.
- **Connections**: a target (the database directly, or through PgBouncer,
  [pgbouncer.md](pgbouncer.md)), a role, and the pooling. Pooling
  matters as much as the SQL: a consumer that connects per call, or never
  returns its connections, is a fault in its own right
  ([faults-with-activity.md](faults-with-activity.md)).
- **Scheduled steps** (O85): whether the schedule may change a stream at
  a fixed moment of the aging (switch a key to a faulty query "since
  yesterday 14:00", or raise a rate), or whether everything holds from
  the start of the aging.

## Fixed-time operations

Batch, daily or nightly jobs: a key run at a fixed time. The only part
of the scheduling players read, and the only part they may change (D116).
Format (proposed), in `jobs.yaml`, cron-like and readable as such:

```yaml
jobs:
  - name: close-day
    key: invoices.close-day
    connection: app
    at: "30 1 * * *"                   # cron expression
    timezone: UTC                      # D81's default; a wrong zone is a plantable fault
```

- Players change a job's time or zone where the scenario allows (the
  node's write policy for `jobs.yaml`); they never change streams.
- Their edit takes effect on the scheduler's next reload of `jobs.yaml`,
  through a `sudo` wrapper, as on the other nodes (proposed).
- Moving a job is also how a player verifies a fix to it within the game,
  instead of time compression (O89).
- A job that cannot start (overlapping its previous run, its connection
  refused) is logged and skipped, never queued (proposed): a backlog would
  be an event nobody scheduled.

## No events outside the schedule (D117)

The scheduler is the only source of activity: no random GM events, no
GM intervention in the load. From the start of the aging to the end of
the game, every producer and consumer follows its schedule and nothing
else. Who may pause or trigger load (proposed: nobody, during the game):
O88.

## What the players reach (D116)

- **Read**: the query repository (`queries.yaml`, `builders/`) and
  `jobs.yaml`.
- **Edit**, where the scenario allows it: the repository (fixing a faulty
  query) and the fixed-time operations' schedules.
- **Never**: the streams, the intensity, the connections, the seed
  (`schedule.yaml`, root-owned, mode 0400).
- Beyond that (proposed; O87): the scheduler's log, which records every
  fixed-time run (start, end, rows, error) and every error (key, SQLSTATE,
  message), with a periodic per-key summary (calls, errors, latency); its
  configuration other than `schedule.yaml`; the node-health view.
- A write policy per file rather than per node may be needed, since the
  repository may be fixable while the rest of the node is report-only
  (O87).

## Drivers (D118)

v0.3 sends SQL to PostgreSQL. From v0.5 the scheduler is to reach other
database types, message queues, APIs and the tools that trigger
transformation layers, so the design keeps the target out of the query
format (proposed; O94):

- a connection names its driver (`sql/postgresql` implied in v0.3);
- a driver offers connect, run one statement with its parameters, begin,
  commit, roll back, close, and reports a latency and an error code;
- the repository format does not change when a driver is added; only the
  entry's body (SQL here, a message or a request later) does.

## Its own monitoring (proposed)

The scheduler exposes per-key counters (calls, errors, latency
histogram) on a metrics endpoint the topology's Prometheus may scrape,
as an application would. Leaving it unscraped is then a monitoring
fault like any other target left out. The same counters give the sealed
checks a stable source under load (O82).

## Open points

O82 (checks under load), O85 (scheduled steps), O86 (time of day), O87
(visibility), O88 (load control), O89 (time compression), O90
(repository semantics), O93 (seed), O94 (driver).
