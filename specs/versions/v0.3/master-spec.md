# db_audit_gm v0.3 — Master specification

Status: **consolidated on 2026-10-22, awaiting an independent review and
the owner's approval.** Companion: [access-model.md](access-model.md).
Baseline: the released [v0.2 master spec](../v0.2/master-spec.md) and
its [access model](../v0.2/access-model.md). Everything v0.2 specifies
stays in force unless this document changes it; where they disagree,
this document wins for v0.3.

---

## 1. Concept and objective

db_audit_gm generates live database audit exercises: an agent, the game
master (GM), deploys a deliberately flawed data stack on a container
cluster, hands it to students (the players) through a single bastion,
receives their report and gives teacher-style feedback. v0.1 settled the
GM's stance on one static PostgreSQL database; v0.2 added monitoring and
the usual tooling.

v0.3 adds **producers and consumers**: the stack is alive. In the
owner's words, producers "will schedule data ingestion, load spikes,
etc. and are the main opportunity for ill-formatted requests,
misbehaving requests, or ill-targeted requests"; for consumers "it is
more probably a question of breadth of query: taking in too much,
transactions taking too long, BI queries, etc." Concretely:

- producers and consumers are nodes of one new brick, the **scheduler**,
  which runs queries the GM writes at design time, on a schedule;
- the system **ages in real time**: it runs for at least two full,
  meaningful days before the players arrive, so the faults have a
  history;
- a **PgBouncer** brick, optional in any scenario;
- **checks that hold on a living system**, since the load never stops;
- **multi-host** swarms, tested on two hosts over Tailscale;
- a **game restart**, on the players' explicit confirmation;
- one new scenario of normal difficulty and eight new catalog faults.

## 2. Scope

### In scope

- The `scheduler` brick: query repository, schedule, fixed-time
  operations, a pluggable driver with SQL on PostgreSQL as its only
  driver (section 7.1).
- The `pgbouncer` brick (section 7.2).
- Brick bumps: `postgres` 0.3.0 (the GM's connection reserve, its
  snapshot method, configuration ownership restored on reload);
  `prometheus`, `postgres-exporter` and `grafana` 0.2.0 (report-only
  write policy honoured, snapshot methods); `bastion` 0.3.0 (multi-host
  publishing documented) (sections 7.3 to 7.5).
- Real-time aging and the game timeline: scenario time and the shift by
  whole hours, changes at fixed moments during aging, the early check,
  the hand-over snapshot (section 8).
- Load calibration and load control (section 9).
- Always-on hosts and multi-host: per-node placement, a registry, `fit`
  per host (section 10).
- Checks on a living system and the smoke tests (section 11).
- The game restart (section 12).
- The format changes (section 6) and the script changes (section 13).
- Difficulty as a fault count; the new scenario and faults; the existing
  scenarios kept deployable (section 15).
- Two known issues of v0.2 fixed: configuration files left owned by
  `player` after an in-place edit, and `gmctl status` naming a tools
  password a game without a web front does not have (section 16).

### Out of scope (deferred, still part of the project)

- Transformers between databases: v0.4.
- Other database types, message queues, APIs and tools that trigger
  transformation layers as scheduler targets: v0.5, as new drivers.
- Adjusting v0.3's accepted defaults (formats, brick interfaces, the
  scenario, aging, scheduler behaviour, tooling, figures) after use:
  v0.5, the version that improves and extends the bricks.
- A sped-up clock, a forged history, time compression: none in v0.3.
  Whether any returns in a later version is open.
- Classroom swarms of student laptops: they cannot stay up for two days
  of aging. A later version copies the aged volumes to the class's hosts
  at hand-over, with the snapshot machinery of section 12 as its first
  half.
- Random GM events, and pausing or triggering load during a game: never
  (section 9).
- A PgBouncer metrics exporter.
- A scoring system for the players: after v1.0, unless research finds
  one quick to implement (not researched).
- Kubernetes: future work; portability stays a requirement.
- Brick options and the `monitoring` role made conditional: v0.5, as
  planned.

## 3. Actors

Unchanged from v0.2: the initiator, the players, anyone in the GM
session, the GM, and the unauthenticated network visitor. v0.3 gives
the players two more kinds of node to reach (scheduler and PgBouncer),
the power to confirm a restart, and no power over the load. The GM gains
a PostgreSQL check role and a connection reserve of its own. The full
rules are in the access model.

## 4. Glossary (additions and changes)

| Term | Meaning |
|---|---|
| Scheduler | The brick that runs producer and consumer nodes. A node of it is a producer or a consumer by its role, not by its code |
| Query repository | A scheduler node's file of queries, written by the GM at design time: a key maps to a query, a pool of queries, a sequence, or a builder |
| Query | One operation sent through a driver; in v0.3 always SQL against PostgreSQL |
| Pool | A key mapped to a list of queries: each call picks one, by weight when given |
| Builder | Python code in the repository returning the statements to run, given the intensity and its options |
| Schedule | A scheduler node's hidden scheduling script: streams, intensity, connections, timeline changes |
| Stream | A schedule entry generating continuous traffic: a key, a rate, a traffic shape, arrivals, concurrency |
| Fixed-time operation | A batch, daily or nightly job running a key at a fixed time; the only scheduling the players read and may change |
| Timeline change | A change to a stream, or a fault planted, at a fixed moment during the aging, written at design time |
| Intensity | A multiplier on a scheduler node's load, the scenario's, never rescaled to the playground |
| Traffic shape | Hourly multipliers over the day, optionally per weekday |
| Driver | The pluggable part of the scheduler that turns a query into a call on a target |
| Scenario time | The clock a scenario's schedules are written in; the local implementation maps it onto real UTC by a whole number of hours |
| Aging minimum | How long the system must run before hand-over: at least 48 hours for a scenario, and per fault how long its evidence takes |
| Hand-over snapshot | A consistent copy of every volume of the game taken at hand-over, from which a restart starts |
| Difficulty score | A scenario's number of fault instances |
| Write override | A scenario setting that makes one of a node's writable paths fixable on an otherwise report-only node |
| GM check role | The PostgreSQL role the GM's sealed checks connect as, inside a connection reserve of its own |
| Aging (changed) | Making faults leave traces. In v0.3: running the system in real time before hand-over, nothing else |

## 5. Repository changes

```
bricks/
  scheduler/            0.1.0, new
  pgbouncer/            0.1.0, new
  postgres/             0.3.0: GM check role and reserve, snapshot method, reload restores ownership
  prometheus/           0.2.0: report-only, snapshot through the TSDB snapshot API
  postgres-exporter/    0.2.0: report-only
  grafana/              0.2.0: report-only, snapshot by a brief stop
  bastion/              0.3.0: multi-host publishing in its GM documentation
faults/<fault-id>/      eight new faults; every existing fault moves to the
                        new evidence locations and adds the bumped versions
scenarios/<new-id>/     the v0.3 scenario
scenarios/bookshop-new-server/, scenarios/fernway-clinics-monitoring/
                        re-pinned; fernway's retention raised
.claude/skills/scenario-format/   templates and checks for section 6
.claude/skills/game-master/       aging, the restart, load control, scenario time
tools/                  the script changes of section 13
```

Every new image builds from `debian:13-slim`, as the existing bricks do;
there is no shared base image.

## 6. Format changes

The cross-version [formats.md](../../formats.md) states the formats in
full; this section lists what v0.3 changes.

### 6.1 Scenario (`scenario.yaml`)

- **Scheduler nodes**: brick `scheduler`, role `producer` or
  `consumer`, their seed files under `nodes/<node>/`: `queries.yaml`,
  an optional `builders/` directory, `jobs.yaml`, `schedule.yaml`
  (section 7.1).
- **`aging:`**: the scenario's aging minimum, at least 48 hours, and the
  hand-over time of day it was designed for, in scenario time.
- **`difficulty:`**: the score, which the loader checks equals the
  number of fault instances, and optionally the level it targets (easy,
  normal, hard).
- **A fault instance's planting moment**: `plant_at: T0` (the default:
  planted right after the data load) or a moment before hand-over
  written relative to it (`handover-20h`). The loader refuses a moment
  at or after hand-over.
- **A fault instance's aging minimum**, when it needs more than its
  definition says.
- **`write_overrides`** on a node: paths, among those the brick lists as
  writable, made fixable on a node whose write policy is report-only.
  The node's `write_policy` stays its default. A fault instance's *fix*
  resolution needs the policy of the file the fault lives in, and the
  loader checks it. This applies to every brick.
- **The story names the customer's time zone** (section 8.3).
- **Prometheus' retention** must cover the aging minimum plus four
  hours, unless a planted fault is about retention; the loader checks
  it against `aging:`.

### 6.2 Answer key (`gm/answer-key.yaml`)

- A behavioural sealed check (one judging behaviour rather than a cause,
  section 11) states its window and its threshold.

### 6.3 Fault definition (`fault.yaml`)

- **`aging:`**: the technique (`real-time`, the only one in v0.3) and the
  minimum duration before the evidence shows. The format required them
  since v0.1; the templates and the loader now carry them.
- **Evidence**: the free text moves to `source`, and `where` takes a
  location: `node` (the fault's target node), `bastion`, or
  `report:<tool>` for a tool the target's brick ships. A fault never
  names a `ui:<name>` location, whose routes only the scenario knows;
  the answer key adds those. The eleven existing catalog faults move to
  this form.
- Faults living in a scheduler's files are planted by the existing seed
  change injection kind, on `queries.yaml`, `jobs.yaml` or
  `schedule.yaml`.
- `applies_to` lists the new and bumped brick versions one by one.

### 6.4 Brick definition (`brick.yaml`)

- A new role, `pooler`, for PgBouncer. The roles list becomes `bastion`,
  `producer`, `queue`, `database`, `pooler`, `transformer`, `consumer`,
  `monitoring`, `backup`.
- **`snapshot:`**: per volume, how the brick's volumes are copied online
  at hand-over: a command run in the node (`pg_basebackup` for the
  database's data, Prometheus' TSDB snapshot API), or a plain copy for a
  volume holding only seeded or append-only files. A brick that declares
  nothing is stopped briefly while its volumes are copied.
- **`writable_paths`** are the paths a scenario's `write_overrides` may
  name.
- The footprint's disk includes the volumes' growth over the aging and a
  four-hour game, as measured.

### 6.5 Script contracts

- **Sealed checks** gain a third outcome: exit 3, "too soon to tell",
  with the remaining window on the first output line. Exit 0 still means
  fixed, 1 present, any other code an error.
- Sealed checks on a database connect as the GM check role, inside the
  GM's reserve (section 7.3); clients of the load connect as ordinary
  roles.

### 6.6 Versions and pins

The rules are unchanged: any change bumps a brick, faults and scenarios
never bump, a brick version is released when v0.3's release gate
passes. The new and bumped versions are those of section 5.

## 7. The bricks

Every new brick is a full node of its own, as in v0.2: s6, `sshd`, the
`player` account, a public validator, the node-health script when the
topology has a metrics store, and nothing on the node runs as root but
s6, `sshd` and the entrypoint.

### 7.1 `scheduler` 0.1.0

**What it is.** Mostly a scheduler: it holds no business logic. The SQL
is the scenario's, written by the GM at design time. One node runs one
schedule against one query repository; a topology may have several
producer and consumer nodes. A small Python 3.13 program on Debian 13,
asyncio-based, with `psycopg` from the distribution: one task per stream
and per fixed-time operation, each with its own connections. If it dies,
s6 restarts it; it resumes at the current time and never replays what it
missed. It starts idle and runs its schedule only once the GM starts the
load (section 8.4).

**Files**, all seed-once on the node's volumes:

| File | Holds | Players |
|---|---|---|
| `queries.yaml`, `builders/` | the query repository | read; edit where the scenario makes them fixable |
| `jobs.yaml` | the fixed-time operations | read; edit where the scenario makes it fixable |
| `schedule.yaml` | streams, intensity, connections, timeline changes | never: root-owned, mode 0400 |
| the scheduler's other configuration | log settings, the endpoint | read |
| the scheduler's log | runs and errors | read |

**The query repository.** A key maps to one of four things:

```yaml
queries:
  orders.insert:                       # a query
    sql: >-
      INSERT INTO orders (customer_id, amount)
      VALUES (%(customer_id)s, %(amount)s)
    params:
      customer_id: {int: [1, 5000]}
      amount: {decimal: [5, 500, 2]}
  catalog.lookup:                      # a pool: one entry per call, by weight when given
    - sql: SELECT * FROM products WHERE id = %(id)s
      params: {id: {int: [1, 20000]}}
      weight: 8
    - sql: SELECT * FROM products WHERE name ILIKE %(pattern)s
      params: {pattern: {choice: ['%lamp%', '%desk%']}}
      weight: 2
  invoices.close-day:                  # a sequence, here one transaction
    transaction: {isolation: read committed}
    steps:
      - sql: UPDATE invoices SET closed = true WHERE day = current_date - 1
      - sql: INSERT INTO ledger SELECT ... FROM invoices WHERE day = current_date - 1
  reports.revenue:                     # a builder
    builder: builders/revenue.py:build
    options: {months: 3}
```

- Parameters come from generators: an integer or decimal range, a choice
  from a list, a sequence, the current time.
- An entry runs in autocommit unless it carries `transaction:`: its
  isolation level and optionally a hold, the time the client keeps the
  transaction open before committing (how long transactions and `idle in
  transaction` sessions are made).
- A builder is a Python function called with the intensity and the
  entry's options; it returns the statements and their parameters, and
  whether they run as one transaction. Builders serve queries whose shape
  depends on the load: a batch growing with intensity, a report whose
  date range is an option. A builder the players may edit is code they
  run as the scheduler's service account, which holds nothing beyond the
  node; that is accepted on the trust line.

**The schedule** (`schedule.yaml`):

```yaml
intensity: 1.0
connections:
  app:
    driver: sql/postgresql
    target: pgbouncer:6432/shop        # or db:5432/shop
    role: shop_app                     # password: a generated secret
    pool: {size: 5}                    # or per-call: true
streams:
  - key: orders.insert
    connection: app
    rate: 40/min                       # at intensity 1.0, before the shape
    arrivals: poisson                  # or even
    shape: business-hours
    concurrency: 2
shapes:
  business-hours:                      # hourly multipliers, scenario time
    hours: {"00-06": 0.1, "07-08": 0.6, "09-11": 1.0, "12": 1.6, "13-17": 1.0, "18-23": 0.3}
timeline:
  - at: handover-20h
    stream: orders.insert
    set: {key: orders.insert-v2}
```

- The intensity multiplies every stream's rate and is passed to the
  builders. It is the scenario's: the local implementation never
  rescales it, since rescaling would change the evidence, as it never
  recomputes resource limits or envelopes.
- All randomness (arrivals, parameter values, pool picks) comes from the
  game's seed, which the local implementation records. A restart takes a
  new seed, so a replayed game may differ.
- A connection names its driver, a target (the database directly, or
  PgBouncer), a role and its pooling. Pooling is part of the behaviour: a
  client that connects per call, or never returns its connections, can be
  a fault.
- A timeline change sets a stream's key, rate or connection at a fixed
  moment before hand-over. The loader refuses one at or after hand-over.

**Fixed-time operations** (`jobs.yaml`):

```yaml
jobs:
  - name: close-day
    key: invoices.close-day
    connection: app
    at: "30 1 * * *"                   # cron expression
    timezone: UTC                      # the default; a wrong zone is a plantable fault
```

- The file is rendered with the scenario-time shift already applied, so
  the players read the real UTC times the jobs run at.
- A player's change takes effect when the scheduler reloads `jobs.yaml`
  through its `sudo` wrapper (`gm-reload-scheduler`).
- There is no "run now". Moving a job's time is how a player verifies a
  fix to it within the game.
- A job that cannot start (its previous run still going, its connection
  refused) is logged and skipped, never queued.

**The log** records every fixed-time run (start, end, rows, error),
every error (key, SQLSTATE, message), and a per-key summary every minute
(calls, errors, latency percentiles). It names keys, never rates or
shapes.

**Metrics.** Per-key counters (calls, errors, a latency histogram) on an
HTTP endpoint the topology's Prometheus may scrape, as an application
would; a scheduler left unscraped is then an ordinary monitoring fault.
The sealed checks read the same counters through the exec verb, scraped
or not.

**Drivers.** A driver offers connect, run one statement with its
parameters, begin, commit, roll back and close, and reports a latency
and an error code. v0.3 ships `sql/postgresql`. A new target later adds
a driver; the repository format keeps its shape and only the entry's
body changes.

**Database roles.** The scheduler's roles are the scenario's, created by
the data load, never superusers. Their passwords are generated secrets,
mounted into the scheduler node and set in the database at the data
load.

**Footprint** (to confirm by measurement): limits 0.25 CPU / 128M,
reservations 0.1 CPU / 64M, disk for its log.

### 7.2 `pgbouncer` 0.1.0

- Role `pooler`; PgBouncer from Debian 13's package; optional in any
  scenario.
- Seed-once `pgbouncer.ini`, owned so that a fixable node's players edit
  it; reload through `gm-reload-pgbouncer`.
- Authentication through `auth_query` against the database, with a
  lookup role whose password is a generated secret; no plain-text list
  holds the application roles' passwords.
- Knobs with envelopes: `default_pool_size`, `max_client_conn`,
  `max_db_connections`, `reserve_pool_size`; `pool_mode` allowed
  `session` or `transaction`.
- The admin console: the players' console role is in `stats_users` only
  (`SHOW POOLS`, `SHOW STATS`, `SHOW CLIENTS`); `admin_users`, which can
  change settings and reload from the console, is the GM's alone.
- No metrics exporter: the players read PgBouncer through its console
  and its log; the node-health script covers the node.
- Snapshot: a plain copy (its volumes hold seeded files and logs).
- Footprint (to confirm): limits 0.25 CPU / 64M, reservations 0.05 CPU /
  32M.

### 7.3 `postgres` 0.3.0

- **The GM's connection reserve.** `reserved_connections` is set on the
  server's command line by the brick's run script, where neither a
  configuration file nor `ALTER SYSTEM` overrides it, and a GM check
  role holding `pg_use_reserved_connections` is created at start-up, its
  password a generated secret readable by root only. Sealed checks
  connect as that role. With a low `max_connections` and a client
  exhausting it, the GM still gets in.
- **The default `max_connections` stays 100**, its envelope 10 to 200;
  a scenario wanting a connection bottleneck sets a low value in its
  seed.
- **Snapshot**: the data volume by `pg_basebackup` over the local socket,
  so the scenario's seed `pg_hba.conf` and settings must allow a local
  replication connection for `postgres` (the loader checks it); the log
  and home volumes by a plain copy.
- **Reload restores ownership**: `gm-reload-db` and `gm-restart-db`
  restore a seeded configuration file's owner and mode before reloading,
  so an in-place edit (`sed -i`) no longer leaves it owned by `player`.

### 7.4 `prometheus`, `postgres-exporter`, `grafana` 0.2.0

- **Report-only honoured.** The renderer passes each node's write policy
  (and its write overrides) to the container. On a report-only node the
  seeded files are read-only for `player` and the reload wrappers
  refuse. Grafana's interface still lets its administrators edit
  dashboards, data sources and alert rules: a known gap, accepted.
- Reload wrappers restore ownership, as in 7.3.
- **Snapshots**: Prometheus' TSDB through its snapshot API, which needs
  its admin API on; the bastion's web front refuses the admin paths, and
  from inside the game network they are forbidden by rule (a known gap).
  Grafana by a brief stop (its database is SQLite). The exporter by a
  plain copy.
- Prometheus' retention is a seed-file value; every v0.3 scenario sets it
  to at least the aging minimum plus four hours.

### 7.5 `bastion` 0.3.0

- On a multi-host playground the renderer publishes the bastion's ports
  in host mode on the bastion's own pinned host, never through the
  routing mesh, which would open them on every host, including a VPS's
  public address. The bastion's GM documentation states this placement
  rule; its image is unchanged.

## 8. Aging and the game timeline

### 8.1 Real time

The stack runs in the background, producers and consumers following
their schedules, for at least two full, meaningful days before
hand-over. Every timestamp, log line, metric and counter the players see
was produced by the system itself at the time it says. There is no
sped-up clock, no forged history and no time compression.

Why: the aging research (measured on the owner's host) compared real
time, a sped-up clock (libfaketime), container pause and resume, VM
snapshots, CRIU, time namespaces and whole-system simulation. Only real
time is consistent everywhere without tricks. A sped-up clock multiplies
every query duration PostgreSQL records by the speed-up (faithful only to
about 4x at a quarter-CPU limit), makes timeouts fire late, cannot touch
the Go binaries (Prometheus, Grafana, the exporter), so Prometheus'
history would have to be forged without alert history, and leaves file
and process times that betray it. The owner preferred a sped-up clock
but accepted those caveats as real, and does not trust forging. The cost,
two days of host time per game, is accepted.

### 8.2 Meaningful days

- Every traffic shape has gone through two full daily cycles, and every
  daily fixed-time operation has run at least twice.
- Every fault instance has reached its aging minimum.
- The scenario's aging minimum is at least 48 hours.

A shape may differ by weekday; the GM picks the deployment time so the
aged days are the ones the story needs.

### 8.3 Scenario time and the shift

A scenario's traffic shapes, fixed-time operations and timeline changes
are written in scenario time, with the hand-over time of day it was
designed for. The local implementation shifts them all by a whole number
of hours so the real hand-over falls where the design put it and the
game window gets the designed load. Every clock stays real UTC: nodes,
logs and tools are untouched, only the schedule is rendered shifted. The
story names the customer's time zone, so a nightly batch the players see
at 14:00 UTC is nightly where the customer is. The shift is recorded in
the local implementation.

### 8.4 The timeline

| Moment | What happens |
|---|---|
| Design | The scenario is written in scenario time: schedules, timeline changes, aging minimum, intended hand-over time of day |
| T0, deployment | On always-on hosts: `fit`, `render` (shift applied), `deploy`, data load, the faults due at T0 planted. Scheduler nodes start idle |
| T0, load start | `gmctl start-load` starts every schedule; T0 is recorded |
| During aging | The stack runs unattended; the GM session may end; the hosts stay up. Timeline changes happen at their moments; faults due during aging are planted by `gmctl inject --at`, scheduled on the manager. The early check runs (8.5) |
| Hand-over | No earlier than the aging minimum after T0: the GM refuses an earlier hand-over, as it refuses a playground too small. The hand-over snapshot is taken (section 12), then the starter pack and the issues are handed over |
| The game | At most four hours. The load runs on; nobody touches it |
| Final answer | Sealed checks and the official validator run, the load still running |
| Teardown | As in v0.2, the hand-over snapshot included |

The local implementation records T0, the shift, the aging minimum, the
earliest hand-over, the hand-over, the seed, the snapshot and each
restart, so a fresh GM session finds where the game is.

Faults are planted at T0 by default, so their history covers the whole
aging. A fault meant to start later (an index dropped "yesterday"), or a
change of behaviour (a release that broke a query at 14:00), is a
timeline entry at a fixed moment during the aging, never at or after
hand-over.

### 8.5 The early check

Halfway through the aging, or after the first run of each fixed-time
operation if later, a scheduled `gmctl` run checks that every fault
planted so far reads present, that every scheduler key is running, and
that no node is unhealthy, and records the result. The GM reads it at
hand-over at the latest; a failure found early leaves time to set the
game up again.

### 8.6 Disk and retention

Fifty-two hours of load grow the tables, the WAL, the PostgreSQL logs,
Prometheus' TSDB and the schedulers' logs. The growth is measured on the
v0.3 scenario, declared in the footprints and counted by `fit`, with the
hand-over snapshot's copies. Prometheus keeps at least the aging minimum
plus four hours.

## 9. Load

- Load is calibrated against the nerfed databases: enough to show
  symptoms, never enough to saturate the host. Slowness comes from the
  CPU and memory limits, the memory settings and the intensity.
  Connection exhaustion shows as refused sessions ("too many clients"),
  not slowness.
- Rates are chosen so tables stay small over the aging (one insert a
  second is about 170,000 rows in two days).
- **No events outside the schedule.** The schedulers are the only source
  of activity: the GM plants no random events and never intervenes in the
  load. During a game nobody, GM or player, pauses, speeds up or
  triggers the load, not even for the final checks. The players' only
  lever is moving a fixed-time operation, which moves a job and adds no
  traffic. No tool offers anything else.

## 10. Hosts

### 10.1 Always-on hosts

The playground's hosts must stay up from deployment through the aging to
the end of the game. v0.3 games run on always-on hosts; a classroom of
student laptops is out of scope (section 2). What a game may use is for
the GM and the initiator to discuss; a game lasts at most four hours.
The available hosts: armenelos (11 GB of memory, about 5.4 GB available
when this was written) and a VPS, linked by Tailscale.

### 10.2 Several hosts

- **Placement per node.** The scenario format already places every node
  on a declared host and sums each host's placed nodes against its
  capacity. The local implementation now places nodes on the real
  playground's hosts and the renderer writes them as hostname or label
  constraints, replacing the single "manager" constraint; stateful nodes
  are pinned with their volumes.
- **A registry every host reaches**: a registry service published on the
  routing mesh, so each host's loopback address `127.0.0.1:5000` reaches
  it and the image names stay as they are; the GM pushes the images
  before deploy.
- **`fit` per host**: each host's limits, reservations and disk against
  the nodes placed on it, each host's images counted once on that host.
- **Per-host SSH Docker contexts** for the exec verb.
- **The default game stays single-host** while its load fits one host.

Risks the build checks on armenelos plus the VPS: the overlay's VXLAN
inside Tailscale's 1280-byte MTU (the overlay network's MTU set to leave
room for both); Swarm advertising the Tailscale addresses; the routing
mesh (handled by host-mode publishing, section 7.5); both hosts up for
the whole aging.

## 11. Checks on a living system

The load never stops, so readings drift and jitter between two runs. The
rules:

1. **Judge the cause, not the symptom**, wherever the cause is
   checkable: the index exists, the setting is in effect, the query has
   its `WHERE`, the job runs outside the peak, the client pools. These
   checks are as stable under load as in v0.2.
2. **A behavioural check judges a window**, when only behaviour shows the
   fault (duplicates still arriving, records still dropped): over a
   trailing window stated in the answer key, against a threshold with a
   margin, from stable sources: the scheduler's per-key counters, or
   cumulative PostgreSQL counters read twice, never a single sample.
3. **"Too soon to tell" is an answer**: exit 3 when the window since the
   fix is shorter than the check needs. The GM waits the window, or
   reports the fault as undetermined in its feedback.
4. **The GM's checks never pause the load.**
5. **The GM's checks always get a connection**: clients connect as
   ordinary roles, and the GM check role has its reserve (section 7.3).
6. **Validators judge state.** Envelopes are unaffected. Under an
   exhaustion fault a validator's service rule may read unhealthy; the
   answer key then declares that validator red.

**Smoke tests** stay short: a few minutes of schedules, every fault
present (polled, with per-check timeouts), every scheduler key running.
In a smoke run, faults due during the aging are planted at once; this is
a test harness, never a game. They run on one host and on armenelos plus
the VPS.

**The release gate** includes one full aged run of the v0.3 scenario:
at least 48 hours of aging, then a play-through as `player` (section
17).

## 12. Restart

A restart rebuilds the game from scratch: every node shut down, the
game's data destroyed, fresh nodes started under a new game id, the game
set up again. The players' credentials are kept, so they log in as
before. The replay may differ (a new seed).

- **Confirmation.** Any player in the GM session may ask. The GM first
  states that the game's state and the players' changes will be lost
  and, when there is no snapshot, which evidence goes with them; it
  restarts only when a player confirms in so many words. A passing
  mention, or a question about restarting, never restarts a game. A stop
  still needs no confirmation.
- **From the hand-over snapshot, where the disk allows.** At hand-over
  the GM copies every volume of the game, each brick by its declared
  method (online where it has one, a brief stop where it has none). A
  restart starts the fresh nodes on fresh copies of it. The history then
  has a gap from hand-over to the restart, which the story tells as a
  maintenance window.
- **Otherwise, no history.** When the copies do not fit the disk, the
  game has no snapshot, and a restart starts from nothing: only the
  history since the restart. The GM names the evidence lost (the faults
  whose aging minimum the new game will not reach) before the players
  confirm, and judges the final answer accordingly.
- **Record.** The local implementation records each restart: the old and
  new game ids, the time, from the snapshot or not.
- A whole-game restart is not a node reset; node resets, hints and extra
  time stay beyond v1.0.

## 13. The local implementation and the scripts

**Local implementation** additions: per-node placement on the
playground's hosts; the registry; the shift; T0, the aging minimum, the
earliest hand-over, the hand-over; the seed; the scheduled setup actions
and their results; the hand-over snapshot's location; each restart.

**`gmctl`**:

| Verb | Change |
|---|---|
| `fit` | per host; counts aged growth and the snapshot's copies; says when the snapshot does not fit |
| `render` | per-node placement, the shift, host-mode publishing on multi-host, write policies and overrides passed to the containers |
| `start-load` | new: starts every scheduler's schedule at T0; refused once the game is handed over |
| `inject --at` | new option: plants a fault at its moment during the aging, scheduled on the manager; refused at or after hand-over |
| `snapshot` | new: takes the hand-over snapshot by each brick's method |
| `restart` | new: the rebuild of section 12, from the snapshot or from nothing; refused unless the GM has recorded the players' confirmation |
| `check` | reads exit 3 as "too soon to tell"; connects as the GM check role |
| `status` | the aging's progress, the shift, the snapshot, restarts; no tools-password line in a game without a web front |

No verb pauses, speeds up or triggers the load.

**The GM skill**: the aging and the timeline, the early check, the
refusal of an early hand-over, load control, the restart's confirmation
and statement, scenario time and the customer's time zone in the
starter pack.

## 14. Player access and rules

The full rules are in the [access model](access-model.md). In short:

- On a scheduler node the players read the repository, `jobs.yaml`, the
  log and the configuration other than `schedule.yaml`, which is
  root-only; they edit the repository and `jobs.yaml` where the scenario
  makes them fixable.
- Write policy may be set per file through write overrides.
- On PgBouncer they read the console as a `stats_users` role.
- `ALTER SYSTEM` on a report-only database node is not prevented for the
  superuser `dba`: accepted on the trust line.
- They may confirm a restart; they cannot touch the load.

## 15. Scenarios and faults

### 15.1 Difficulty

Each fault is worth 1. An easy game scores 5, a normal one 10, a hard
one 20. A scenario's score is its number of fault instances; the GM's
silent tooling expectations are not faults and do not count. The named
levels are targets for the GM designing from a brief, not exact counts:
`bookshop-new-server` scores 6 and `fernway-clinics-monitoring` 8.

### 15.2 The new scenario

One new scenario of normal difficulty:

- **Topology**: the bastion; one `postgres` database; PgBouncer in front
  of it; a producer (orders, ingestion, a nightly batch) and a consumer
  (reporting queries, an export job); Prometheus, the exporter and
  Grafana. Single-host on armenelos; also deployed once across armenelos
  and the VPS.
- **Ten faults**: six or seven of the new catalog faults below, plus
  three or four existing ones that gain evidence under load (the missing
  join index, autovacuum off on a hot table, one monitoring fault); at
  least one planted during the aging.
- **Write policies**: the database and PgBouncer fixable; the scheduler
  nodes report-only, with the producer's repository and both `jobs.yaml`
  files fixable by override; one monitoring node fixable, one
  report-only.
- **Aging minimum** 48 hours or more; Prometheus' retention at least that
  plus four hours.

### 15.3 New catalog faults

| Fault | Lives in | Evidence | Resolutions |
|---|---|---|---|
| A query with a syntax or type error | repository | scheduler log, PostgreSQL log, error counters | report, propose, fix |
| A query missing its `WHERE` (updates every row) | repository | `pg_stat_statements` rows per call, bloat, lock waits | report, propose, fix |
| A reporting query reading far too much (`SELECT *`, no date bound) | repository | temporary files, `work_mem` spills, slow-query log | report, propose, fix |
| Inserts retried without idempotency: duplicates | repository | duplicate rows | report, propose, fix |
| A consumer holding transactions open | schedule (hold) | `pg_stat_activity`, `idle in transaction`, vacuum held back | report, propose |
| A nightly batch at the daily peak | `jobs.yaml` | lock waits and latency at the peak, the job's time | report, propose, fix |
| A job in the wrong time zone | `jobs.yaml` | run times in the log against the story's time zone | report, propose, fix |
| A PgBouncer pool too small for the peak | PgBouncer seed | `SHOW POOLS` waiting clients, latency | report, propose, fix |

Each has its injection, its aging minimum, its sealed check judging the
cause (the query's text, the job's time and zone, the pool's size, the
schedule's hold), and its solvability description; the duplicates fault
is judged over a window. A fault living in the schedule is report or
propose only, since players never change streams.

### 15.4 Existing scenarios

`bookshop-new-server` and `fernway-clinics-monitoring` are re-pinned to
the bumped bricks and still deploy; fernway's retention (one day today)
is raised to cover an aging. Neither gains producers.

## 16. Carried fixes

- Configuration files edited in place (`sed -i`) are restored to their
  owner and mode by the reload wrappers.
- `gmctl status` shows no tools-password line in a game without a web
  front.
- Every catalog fault's evidence moves to the location form of 6.3.

## 17. Definition of done

1. The `scheduler` and `pgbouncer` bricks at 0.1.0, with GM documentation,
   validators and measured footprints; `postgres` 0.3.0, the three
   monitoring bricks 0.2.0 and `bastion` 0.3.0 as in section 7.
2. The format changes of section 6 in the templates, the loader and the
   format skill; the eleven existing catalog faults in the new evidence
   form.
3. The eight new catalog faults, each with injection, aging minimum,
   cause-first sealed check and solvability description.
4. The new scenario, complete by the format skill, its scenario document
   generated.
5. `gmctl` as in section 13.
6. Short smoke tests green on one host and on armenelos plus the VPS.
7. The release gate's full aged run: at least 48 hours of aging, then a
   play-through as `player`; every fault's evidence reachable; the sealed
   checks right under load before and after fixes; one restart from the
   hand-over snapshot; the measured footprint and aged growth within the
   declared figures.
8. The GM skill updated as in section 13.
9. Both existing scenarios deploy re-pinned, fernway with its retention
   raised.

## 18. Grounding: what exists and what is at risk

Read in the code at the v0.2 close:

- **The scenario format already places nodes per host**:
  `designed_for.placement` is checked by the loader (`tools/gm/model.py`),
  which sums each host's placed nodes against its capacity. Multi-host
  extends this rather than inventing it.
- **The renderer pins every service to the manager**
  (`PLACEMENT_CONSTRAINT` in `tools/gm/localimpl.py`), and `fit`
  (`tools/gm/fit.py`) checks one host: both change.
- **Images are tagged `127.0.0.1:5000/...` but built locally**; no
  registry runs yet, and the cross-host loopback-registry pattern has
  never been tried.
- **Nothing passes a node's write policy to its container** today; the
  loader only checks resolutions against node write policies
  (`tools/gm/model.py`). Per-file policies and report-only monitoring
  nodes both start here.
- **The fault template carries no aging field** and keeps free-text
  evidence `where`, although the format has required aging since v0.1.
- **The scenario smoke test** (`tools/tests/smoke-scenario.sh`) expects
  every sealed check present within 120 seconds of injection on a still
  system; it is rewritten for load.
- At risk of disruption: the sealed-check contract (a third exit code
  every caller must read); the loader's resolution check (now per file);
  the renderer's placement and publishing (every existing scenario
  re-rendered); the `postgres` start-up (the reserve and the check role).

## 19. Architectural decisions and their reasoning

- **Real-time aging**, rejecting a sped-up clock, forging and VM
  snapshots: only real time is consistent for every component, Go
  binaries and file times included (section 8.1).
- **One scheduler brick with GM-written queries**, rather than one brick
  per kind of client: the behaviour is the scenario's, so the brick stays
  generic and the faults live in data the GM writes and the players can
  read.
- **The schedule hidden, the fixed-time operations visible and
  movable**: a real customer's traffic is not a file anyone reads, while
  its batch schedule is; moving a job is also how a player verifies a
  fix without time compression.
- **No events outside the schedule, and no load control during a game**:
  the evidence must come from the system, never from GM improvisation,
  and a paused load would remove the symptoms a check reads.
- **A pluggable driver**: other targets arrive in v0.5 without a format
  change.
- **Intensity never rescaled**: rescaling would change the evidence, as
  recomputing envelopes could turn a planted out-of-bounds value into an
  in-bounds one.
- **Scenario time shifted by whole hours, clocks untouched**: a class at
  any hour sees the designed load while every timestamp stays real.
- **Checks judge the cause first**: a cause is stable under load, a
  symptom is not; windows and "too soon to tell" cover the rest.
- **A connection reserve pinned on the command line**: the GM must reach
  the database under an exhaustion fault, and no player-editable file can
  remove it.
- **The hand-over snapshot taken online per brick**: one gap only, at
  the restart; a brief stop only for bricks with no online method.
- **Always-on hosts**: two days of aging rule out hosts that are not
  there; copying aged volumes elsewhere is the later path.
- **Host-mode publishing for the bastion on multi-host**: the routing
  mesh would expose the players' entry on every host.
- **Write policy per file**: a scheduler's repository can be fixable
  while its node stays report-only, the realistic split.

## 20. Deferred items and points left to the build

Deferred (section 2 lists the scope): v0.5 adjusts every default above
after use; a later version brings classroom swarms by copying aged
volumes; whether a sped-up clock, forged history or time compression
ever returns is open; scoring after v1.0; Kubernetes later.

Left to the build, to settle without changing behaviour:

- the footprints of every new or bumped brick, and the aged growth, by
  measurement;
- the cross-host registry pattern and the overlay MTU over Tailscale,
  tried on armenelos and the VPS;
- `auth_query`'s exact set-up in PgBouncer;
- the size of the GM's connection reserve (two connections expected);
- how `gmctl` schedules setup actions on the manager (a timer of the
  host's, recorded in the local implementation);
- the loader's check that a seed allows `pg_basebackup` locally.

Known limits, accepted (also in the access model): the players' `dba`, a
superuser, can still use up the GM's reserve and run `ALTER SYSTEM` on a
report-only database; Grafana's interface ignores report-only;
Prometheus' admin API, on for snapshots, is reachable from inside the
game network; a player editing a fixable builder runs code as the
scheduler's account; the traffic can be inferred from the schedulers'
logs and the database's own.
