# db_audit_gm v0.3 — Master specification

Status: **approved by the owner on 2026-10-22** (spec D154), as
consolidated the same day and revised after an independent review, the
owner's answers to it and its re-review's corrections; the spec writer's
choices on the points the review left open are accepted with it;
amended the same day, at the build plan's approval (D156), by the
owner's ruling that only a scenario with scheduler nodes ages (D157) and
the format choices that carry it (D158); three readings of them
confirmed by the owner on 2026-10-23, at wave 1's start (D160–D162);
two of wave 1's preflight settlements written in the same day: where
`schedule.yaml` lives (7.1, D163) and the scheduler's writable paths in
the 6.7 example (D170); amended on 2026-10-26 by the owner's ruling on
the GM check role's `CONNECT` privilege (7.3, D176), and the same day
by the ruling taking PgBouncer from the PostgreSQL apt repository (7.2,
D177); two of wave 3's preflight settlements written in the same day:
published ports on the manager only (7.5, 10.2, D180) and the image copy
through the host's SSH Docker context (10.2, 20, D181); amended on
2026-10-27 by the owner's ruling on the overlay's subnet on several
hosts (10.2, D182), and the same day by the ruling leaving the overlay's
range to the GM (10.2, 13, D183).
Build plan:
[build-plan.md](build-plan.md), approved (D156). Companion:
[access-model.md](access-model.md). Baseline: the released
[v0.2 master spec](../v0.2/master-spec.md) and its
[access model](../v0.2/access-model.md). Everything v0.2 specifies stays
in force unless this document changes it; where they disagree, this
document wins for v0.3.

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
- a scenario with producers or consumers **ages in real time**: it
  runs unattended before the players arrive, for as long as the scenario
  declares and at least eight hours, so the faults have a history; a
  scenario with neither, a static database, has no aging (section 8);
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
- Brick bumps: `postgres` 0.3.0 (the GM's check role and connection
  reserve, its snapshot method, configuration ownership restored on
  reload); `prometheus`, `postgres-exporter` and `grafana` 0.2.0
  (report-only write policy honoured, snapshot methods); `bastion` 0.3.0
  (its GM documentation: the bastion pinned to its host on multi-host)
  (sections 7.3 to 7.5).
- Real-time aging and the game timeline: the aging each scenario with
  scheduler nodes declares, none for a scenario without, scenario time and the shift by whole hours, changes at fixed
  moments during aging, the early check, failures during the aging, the
  hand-over snapshot (section 8).
- Load calibration and load control (section 9).
- Always-on hosts and multi-host: per-node placement, images copied to
  each host, `fit` per host (section 10).
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
- Classroom swarms of student laptops: v0.3 games run on always-on hosts.
  A later version copies the aged volumes to the class's hosts at
  hand-over, with the snapshot machinery of section 12 as its first half.
  With an eight-hour floor, a laptop swarm that stays up for a school day
  becomes conceivable; whether that changes the later plan is open.
- Random GM events, and pausing or triggering load during a game: never
  (section 9).
- A PgBouncer metrics exporter.
- A report-only database node: `postgres` stays fixable-only in v0.3
  (section 7.3).
- An image registry: images are copied from host to host (section 10.2).
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
a PostgreSQL check role and a connection reserve of its own, and acts
during the aging through `gmctl` runs it scheduled. The full rules are in
the access model.

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
| Scenario time | The clock a scenario's schedules are written in, the customer's own; the local implementation maps it onto real UTC by a whole number of hours |
| Customer's time zone | The fixed UTC offset scenario time stands at in one game, derived from the shift (section 8.3) |
| T0 | The moment the load starts; the aging counts from it |
| Aging minimum | How long the system must run before hand-over: for a scenario with scheduler nodes, what it declares, at least eight hours; a scenario without has none; per fault, how long its evidence takes under the load |
| Lost time | The minutes of the aging in outage, in all |
| Outage | A minute of the aging when a node of the game was not running, or a scheduler wrote no per-minute summary (its process down or idle); a running scheduler writes one every minute, even with no call |
| Earliest hand-over | The moment the scenario's aging minimum has passed since T0, moved later by the lost time beyond thirty minutes, and every fault instance's own minimum has passed since its planting (section 8.7) |
| Hand-over snapshot | A consistent copy of every volume of the game taken at hand-over, from which a restart starts |
| Brief stop | A brick's service stopped inside its running container through s6 while its volumes are copied, then started again; never a Swarm scale to zero |
| Difficulty score | A scenario's number of fault instances |
| Write override | A scenario setting that makes one of a node's writable paths fixable on an otherwise report-only node |
| GM check role | The PostgreSQL role the GM's sealed checks connect as, inside a connection reserve of its own |
| Aging (changed) | Making faults leave traces. In v0.3: running the system in real time before hand-over, nothing else, in a scenario with scheduler nodes only |

## 5. Repository changes

```
bricks/
  scheduler/            0.1.0, new
  pgbouncer/            0.1.0, new
  postgres/             0.3.0: GM check role and reserve, snapshot method, reload restores ownership
  prometheus/           0.2.0: report-only, snapshot by a brief stop
  postgres-exporter/    0.2.0: report-only
  grafana/              0.2.0: report-only, snapshot by a brief stop
  bastion/              0.3.0: its GM documentation states the multi-host placement; image unchanged
faults/<fault-id>/      eight new faults; every existing fault moves to the
                        new evidence locations and adds the bumped versions
scenarios/<new-id>/     the v0.3 scenario
scenarios/bookshop-new-server/, scenarios/fernway-clinics-monitoring/
                        re-pinned, no aging (no scheduler node)
.claude/skills/scenario-format/   templates and checks for section 6
.claude/skills/game-master/       aging and its feasibility, failures during the
                                  aging, the restart, load control, scenario time
tools/                  the script changes of section 13
```

Every new image builds from `debian:13-slim`, as the existing bricks do;
there is no shared base image.

## 6. Format changes

The cross-version [formats.md](../../formats.md) states the rules for
every version; this section lists what v0.3 changes. The shapes of the
new fields are given in 6.7 and, for a scheduler's files, in 7.1; both
are normative until the format skill's templates carry them.

### 6.1 Scenario (`scenario.yaml`)

- **Scheduler nodes**: brick `scheduler`, role `producer` or
  `consumer`, their seed files under `nodes/<node>/`: `queries.yaml`,
  an optional `builders/` directory, `jobs.yaml`, `schedule.yaml`
  (section 7.1).
- **`aging:`**: the scenario's aging minimum, at least eight hours and
  as long as its evidence needs (section 8.2), and the hand-over time of
  day it was designed for, in scenario time. Required from v0.3 in every
  scenario with a scheduler node. A scenario with none has no aging
  (section 8) and omits `aging:`, which the loader refuses there; it
  then has no `plant_at` other than T0, no instance `aging_minimum` and
  no `{{customer_timezone}}`, since it has no shift.
- **`difficulty:`**: the score, which the loader checks equals the
  number of fault instances, and optionally the level it targets (easy,
  normal, hard).
- **A fault instance's planting moment**: `plant_at: T0` (the default:
  planted right after the data load, before the load starts) or a moment
  before hand-over written relative to it (`handover-6h`). A moment other
  than T0 is allowed only for a fault whose injection kind is `state`:
  `seed-file` and `parameter` faults are planted at render, and the
  loader refuses any other moment for them. For `handover-<N>h` the
  loader checks that N is at most the scenario's aging minimum and at
  least the instance's own aging minimum, and refuses a moment at or
  after hand-over. A later change of a scheduler's behaviour (a release
  that broke a query) is a timeline change of its schedule (7.1), not a
  planted fault.
- **A fault instance's aging minimum**, when it needs more than its
  definition says. The loader checks the scenario's aging minimum covers
  every instance: its planting offset from T0 plus its aging minimum.
- **`write_overrides`** on a node: paths, among those the brick lists as
  writable, made fixable on a node whose write policy is report-only.
  The node's `write_policy` stays its default. A fault instance's *fix*
  resolution needs the policy of the file the fault lives in, and the
  loader checks it. This applies to every brick.
- **The customer's time zone** appears in the story and the starter pack
  through the placeholder `{{customer_timezone}}`, which render fills
  (section 8.3). A scenario never names a fixed zone. A scenario with no
  scheduler node has no shift and no customer's time zone: its times stay
  UTC, as in v0.2.
- **Prometheus' retention**: its time bound covers the aging minimum plus
  four hours (four hours with no aging), unless a planted fault is about
  retention; the loader checks it against `aging:`. A size bound, when the seed sets one, must
  stay above the TSDB's measured growth over the same span, which the
  scenario's design checks against the brick's measured footprint.

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
- Faults living in a scheduler's files are planted by the existing
  `seed-file` injection kind, its `seed_changes` editing `queries.yaml`,
  `jobs.yaml` or `schedule.yaml`, at render.
- `applies_to` lists the new and bumped brick versions one by one.

### 6.4 Brick definition (`brick.yaml`)

- A new role, `pooler`, for PgBouncer. The roles list becomes `bastion`,
  `producer`, `queue`, `database`, `pooler`, `transformer`, `consumer`,
  `monitoring`, `backup`.
- **`snapshot:`**: per volume, how it is copied at hand-over, by one of
  three methods:
  - `pg_basebackup`: the database's data, online (7.3);
  - `copy`: a plain copy while the node runs, for a volume holding only
    seeded, append-only or whole-file-rewritten files;
  - `stop`: a brief stop of the brick's service while the volume is
    copied.

  A volume the brick empties at every start (`/run`) is not copied. A
  brick that declares nothing gets `stop`. The declared methods are in
  7.1 to 7.5.
- **`writable_paths`** are the paths a scenario's `write_overrides` may
  name.
- The footprint's disk includes the volumes' growth over an aging and a
  four-hour game, as measured, stated per hour so `fit` can scale it to
  the scenario's aging.

### 6.5 Script contracts

- **Sealed checks** gain a third outcome: exit 3, "too soon to tell",
  with the remaining window on the first output line. Exit 0 still means
  fixed, 1 present, any other code an error.
- Sealed checks on a database connect as the GM check role, inside the
  GM's reserve (section 7.3); clients of the load connect as ordinary
  roles. The existing catalog faults' database checks, which connect as
  `postgres` over the local socket today, move to the check role.

### 6.6 Versions and pins

The rules are unchanged: any change bumps a brick, faults and scenarios
never bump, a brick version is released when v0.3's release gate
passes. The new and bumped versions are those of section 5.

### 6.7 Shapes of the new fields

```yaml
# scenario.yaml
aging:                          # with scheduler nodes only; omitted otherwise
  minimum: 16h                  # at least 8h
  handover_at: "14:00"          # the hand-over time of day designed for, scenario time
difficulty:
  score: 10                     # the loader checks it equals the fault instances
  level: normal                 # optional: easy, normal, hard
nodes:                          # a list, one item per node, as today
  - name: producer
    brick:
      id: scheduler
      version: 0.1.0
    role: producer
    write_policy: report-only
    write_overrides:            # among the brick's writable_paths
      - /srv/scheduler/repository   # queries.yaml and builders/ (D170)
      - /srv/scheduler/jobs         # jobs.yaml
fault_instances:
  - id: f7
    fault:
      id: pg-join-index-missing
      version: 0.1.0
    node: db
    plant_at: handover-6h       # T0 by default; other moments for state faults only
    aging_minimum: 4h           # optional, above the definition's

# fault.yaml
aging:
  technique: real-time
  minimum: 2h

# brick.yaml
snapshot:
  pgdata: pg_basebackup         # pg_basebackup | copy | stop
  pgconf: copy
  pglog: copy
  home: copy
  gmstate: copy                 # run: emptied at every start, never copied
```

The scheduler's paths above are illustrative; the brick's `writable_paths`
fix them.

## 7. The bricks

Every new brick is a full node of its own, as in v0.2: s6, `sshd`, the
`player` account, a public validator, the node-health script when the
topology has a metrics store, and nothing on the node runs as root but
s6, `sshd`, the entrypoint and the run scripts until they drop to their
service account.

### 7.1 `scheduler` 0.1.0

**What it is.** Mostly a scheduler: it holds no business logic. The SQL
is the scenario's, written by the GM at design time. One node runs one
schedule against one query repository; a topology may have several
producer and consumer nodes. A small Python 3.13 program on Debian 13,
asyncio-based, with `psycopg` from the distribution: one task per stream
and per fixed-time operation, each with its own connections, running as
the scheduler's service account. Write policies `fixable` and
`report-only`.

**Files**, seed-once on the node's volumes, except `schedule.yaml`,
which is read in place from the game's own seed at every start and is
never on a volume, so it is not in the hand-over snapshot and a restart's
new game brings its new seed (section 12; D163):

| File | Holds | Players |
|---|---|---|
| `queries.yaml`, `builders/` | the query repository | read; edit where the scenario makes them fixable |
| `jobs.yaml` | the fixed-time operations | read; edit where the scenario makes it fixable |
| `schedule.yaml` | streams, intensity, connections, timeline changes | never: root-owned, mode 0400 |
| the scheduler's other configuration | log settings, the endpoint | read |
| the scheduler's log | runs and errors | read |

**How the program gets its schedule.** The scheduler's s6 run script,
running as root, reads `schedule.yaml` and passes it to the program on
standard input, then drops to the service account with `s6-setuidgid`.
The program never opens the file, and the service account cannot read
it. Every start of the service, an s6 restart included, reads it again;
the file never changes during a game.

**Idle or running.** The program starts idle. `gmctl start-load` writes
a load-started marker holding T0 on the node's root-owned state volume,
readable by the service account, then restarts the scheduler's s6
service; a program that finds the marker at start runs its schedule.
If the program dies, or the container or its host restarts, it comes
back running: it resumes at the current time, applies every timeline
change whose moment has passed, and never replays what it missed.

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
  run as the scheduler's service account, inside the process that holds
  the schedule: it holds nothing beyond the node and its application
  roles, but it can print the schedule to the log. Both are accepted on
  the trust line; builders are not isolated.

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
  - at: handover-6h
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
  moment before hand-over. The loader refuses one at or after hand-over,
  or further before it than the scenario's aging minimum. Render turns
  each moment into a UTC time from the planned hand-over (8.3).

**Fixed-time operations** (`jobs.yaml`):

```yaml
jobs:
  - name: close-day
    key: invoices.close-day
    connection: app
    at: "30 1 * * *"                   # cron expression, scenario time
```

- In the scenario a job's time is in scenario time, with no `timezone:`.
  Render writes every such job in UTC with its time shifted, so the
  players read the real UTC times the jobs run at.
- Only the wrong-time-zone fault gives a job a `timezone:`: its seed
  change sets a zone offset from the customer's zone by a whole number of
  hours (its parameter, never 0), and render writes that zone as a fixed
  offset (`Etc/GMT±N`) beside the job's time as designed, unshifted
  (8.3). An offset outside the range `Etc/GMT` names (UTC−12 to
  UTC+14) wraps modulo 24 into it: a daily job runs at the same hour
  either way.
- A player's change takes effect when the scheduler reloads `jobs.yaml`
  through its `sudo` wrapper (`gm-reload-scheduler`).
- There is no "run now". Moving a job's time is how a player verifies a
  fix to it within the game.
- A job that cannot start (its previous run still going, its connection
  refused) is logged and skipped, never queued.

**The log** records every fixed-time run (start, end, rows, error),
every error (key, SQLSTATE, message), and a per-key summary every minute
(calls, errors, latency percentiles), written every minute while the
program runs its schedule, even when no call ran, since the outages of
8.7 are read from it. It names keys, never rates or shapes.

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

**Snapshot**: every volume by `copy` (seeded files, the marker, an
append-only log).

**Footprint** (to confirm by measurement): limits 0.25 CPU / 128M,
reservations 0.1 CPU / 64M, disk for its log.

### 7.2 `pgbouncer` 0.1.0

- Role `pooler`; PgBouncer from the PostgreSQL apt repository
  (`trixie-pgdg`), pinned at `1.26.1-1.pgdg13+1` (amended by D177:
  Debian 13's 1.24.1 had open CVEs with no fix); optional in any
  scenario; write policies `fixable` and `report-only`.
- Seed-once `pgbouncer.ini`, owned so that a fixable node's players edit
  it; reload through `gm-reload-pgbouncer`.
- Authentication through `auth_query` against the database, with a
  lookup role whose password is a generated secret; no plain-text list
  holds the application roles' passwords.
- Knobs with envelopes: `default_pool_size`, `max_client_conn`,
  `max_db_connections`, `reserve_pool_size`; `pool_mode` allowed
  `session` or `transaction`.
- The admin console. The players' console role is `dba`, authenticated
  through `auth_query` (with `auth_dbname` naming the database the
  lookup runs in, so the console accepts it), and listed in `stats_users`
  only (`SHOW POOLS`, `SHOW STATS`, `SHOW CLIENTS`); the players hold no
  extra password, and the lookup function returns superusers too.
  `admin_users`, which can change settings and reload from the console,
  names only the GM's account: PgBouncer's own service account over the
  local socket, which the exec verb reaches.
- No metrics exporter: the players read PgBouncer through its console
  and its log; the node-health script covers the node.
- Snapshot: every volume by `copy` (seeded files and logs).
- Footprint (to confirm): limits 0.25 CPU / 64M, reservations 0.05 CPU /
  32M.

### 7.3 `postgres` 0.3.0

- **Write policy** stays `fixable` only. No v0.3 scenario needs a
  report-only database, and offering one untested would ship a policy no
  game exercises.
- **The GM's connection reserve.** `reserved_connections` is set on the
  server's command line by the brick's run script, where neither a
  configuration file nor `ALTER SYSTEM` overrides it, and a GM check
  role is created at start-up, its password a generated secret readable
  by root only. Sealed checks connect as that role. With a low
  `max_connections` and a client exhausting it, the GM still gets in.
- **The GM check role's privileges**: a login role, not a superuser,
  member of `pg_use_reserved_connections`, `pg_monitor` (settings,
  statistics, activity) and `pg_read_all_data` (the duplicates and other
  data checks), with `SELECT` on the `pg_hba_file_rules` view and
  `EXECUTE` on the `pg_hba_file_rules()` function behind it granted (the
  view alone is not enough), and `CONNECT` on every database the data
  creates, granted by `gmctl load-data` as `postgres` after the data load,
  since a scenario's data may revoke it from `PUBLIC` (amended by D176).
  A check needing more says so in its fault
  and is a build finding.
- **The default `max_connections` stays 100**, its envelope 10 to 200;
  a scenario wanting a connection bottleneck sets a low value in its
  seed.
- **Snapshot**: the data volume by `pg_basebackup` over the local socket,
  so the scenario's seed `pg_hba.conf` and settings must allow a local
  replication connection for `postgres` (the loader checks it); every
  other volume by `copy`, except `/run`.
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
- **Snapshots**: Prometheus by a brief stop, its TSDB copied during a
  stop of a few seconds; its admin and lifecycle APIs stay off, as in
  v0.2. Grafana by a brief stop (its database is SQLite). The exporter by
  `copy`. The scrape gap the stop leaves at hand-over is told in the
  story as a maintenance window.
- Prometheus' retention is a seed-file value; every v0.3 scenario bounds
  it by time to at least the aging minimum plus four hours (6.1).

### 7.5 `bastion` 0.3.0

- The renderer already publishes every port in host mode, never through
  the routing mesh. On a multi-host playground the bastion is pinned to
  its declared host, so its ports open on that host only; the routing
  mesh would have opened them on every host, a VPS's public address
  included. Its host must be the manager (10.2). The bastion's GM
  documentation states this placement rule; its image is unchanged.
- Snapshot: every volume by `copy`, except `/run`. A restart from the
  snapshot gives the players back the bastion as it was handed over.

## 8. Aging and the game timeline

**Only a scenario with scheduler nodes ages** (D157): aging is what lets
the producers' and consumers' load leave its traces. A scenario with no
producer or consumer, a static database investigated as a restored
backup, as `bookshop-new-server` and `fernway-clinics-monitoring` are,
has no aging and keeps v0.2's timeline, with v0.3's checks before the
hand-over: deployment, the data load, the faults planted, the hand-over
check (8.5, its scheduler and outage items empty) and the hand-over
snapshot (section 12), Prometheus and Grafana stopped briefly for it
where the scenario has them (D162), then the hand-over. It has no
`start-load` and no T0 (its faults are planted right after the data load), no early check,
no outages and no earliest hand-over; the GM makes
no feasibility judgement on aging for it; its monitoring history builds
during the game, as in v0.2. A fault definition's aging minimum is the
time its evidence takes under the load, so it is not counted in a
static scenario (D160), whose faults the GM chooses for evidence the
restored state shows at once. A setup failure tears such a game down, as in v0.2.
The rest of this section, and every mention of the aging elsewhere,
concerns scenarios with scheduler nodes.

### 8.1 Real time

The stack runs in the background, producers and consumers following
their schedules, before hand-over, for as long as the scenario declares
and at least eight hours. Every timestamp, log line, metric and counter
the players see was produced by the system itself at the time it says.
There is no sped-up clock, no forged history and no time compression.

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
the scenario's aging in host time before each game, is accepted.

### 8.2 What the aging must cover

- **The scenario declares its aging minimum**, at least eight hours.
  Eight hours is a floor, not the norm: the minimum covers whatever the
  scenario's evidence needs, such as each fault instance's own minimum
  after its planting moment, the runs of a fixed-time operation the
  evidence relies on (a daily job's two runs need more than a day), the
  hours of the day a fault shows in, or bloat building up over several
  days. The loader checks the minimum against the fault instances (6.1).
- **The GM judges feasibility**, per scenario and per game: whether the
  aging the initiator can afford, between deployment and the class, is
  enough for this scenario. It never hands over before the earliest
  hand-over. When the time available is too short, it says so and
  declines the scenario, or proposes another that fits. Designing a
  scenario from a brief, it declares the aging that scenario needs.
- A shape may differ by weekday; the GM picks the deployment time so the
  aged hours are the ones the story needs.

### 8.3 Scenario time and the shift

A scenario's traffic shapes, fixed-time operations and timeline changes
are written in scenario time, with the hand-over time of day it was
designed for. `gmctl render` takes the planned hand-over, a UTC date and
hour, and computes the shift: the designed hand-over hour minus the
planned one, a whole number of hours brought between −11 and +12. Render
shifts every schedule by it, so the real hand-over falls where the design
put it and the game window gets the designed load. Every clock stays real
UTC: nodes, logs and tools are untouched, only the schedule is rendered
shifted. The shift is recorded in the local implementation.

- **The customer's time zone** is the fixed offset UTC plus the shift,
  with no daylight saving time, written `Etc/GMT-5` for UTC+5 (that
  naming inverts the sign). Render substitutes it, with its plain
  reading ("UTC+5"), for `{{customer_timezone}}` in the story and the
  starter pack, so a nightly batch the players see at 20:30 UTC is
  nightly where the customer is.
- **Jobs.** A job with no `timezone:` is in scenario time and rendered
  in UTC, shifted. A job given a `timezone:` by the wrong-time-zone fault
  keeps its designed time in a zone offset from the customer's by the
  fault's parameter, so it is wrong by that offset whatever the shift
  (7.1); an offset beyond UTC−12 or UTC+14 wraps modulo 24, which
  leaves a daily job's hour unchanged.
- **Timeline moments** (`handover-<N>h`) are rendered as UTC times from
  the planned hand-over. A moment that falls before T0, because the load
  started late, takes effect at T0.
- **When the real hand-over moves.** A later hand-over keeps the
  rendered schedule: what was planted or changed N hours before the
  planned hand-over is older, never younger, but the game window then
  sees another part of the designed day unless the move is by whole
  days, which the GM tells the initiator. A hand-over before the earliest
  hand-over is refused (8.4). Re-planning the hand-over hour means a new
  game: stop, then start.

### 8.4 The timeline

| Moment | What happens |
|---|---|
| Design | The scenario is written in scenario time: schedules, timeline changes, aging minimum, intended hand-over time of day |
| Deployment | On always-on hosts, after the GM's feasibility judgement (8.2): `fit`, `render` (the planned hand-over given, the shift applied), `deploy`, data load, the faults due at T0 planted. Scheduler nodes start idle. A failure here tears the game down, as in v0.2 |
| T0, load start | `gmctl start-load` starts every schedule; T0 is recorded once every scheduler has started |
| During aging | The stack runs unattended; the GM session may end; the hosts stay up. Timeline changes happen at their moments; `state` faults due during aging are planted by `gmctl inject --at` runs scheduled on the manager. The early check runs (8.5). A failure is recorded and tears nothing down (8.7) |
| Hand-over | No earlier than the earliest hand-over: the GM refuses an earlier one, as it refuses a playground too small. The hand-over check runs (8.5), the hand-over snapshot is taken (section 12), then the starter pack and the issues are handed over |
| The game | At most four hours. The load runs on; nobody touches it |
| Final answer | Sealed checks and the official validator run, the load still running |
| Teardown | As in v0.2, the hand-over snapshot included |

The local implementation records T0, the shift, the planned hand-over,
the aging minimum, the outages and the lost time, the earliest
hand-over, the hand-over, the seed, the scheduled setup actions and their
results, the snapshot and each restart, so a fresh GM session finds
where the game is.

Faults are planted at T0 by default, so their history covers the whole
aging. A fault meant to start later (an index dropped this morning) is a
`state` fault planted at a fixed moment during the aging; a change of
behaviour (a release that broke a query at 10:00) is a timeline change;
neither ever falls at or after hand-over.

### 8.5 The early check and the hand-over check

- **The early check** runs halfway through the aging minimum, or, if
  later, once every fixed-time operation due before the earliest
  hand-over has run once, and in any case no later than one hour before
  the earliest hand-over. A scheduled `gmctl` run checks that every
  fault planted so far reads present, that every scheduler key is
  running, that no node is unhealthy, and the outages so far, and
  records the result.
- **Who is told.** Nobody is notified: the result is in the local
  implementation and heads `gmctl status`. A GM session resuming a game
  during the aging runs `status` first and tells the initiator of any
  failure or outage before anything else; the GM advises the initiator
  to resume a session after the early check when it can.
- **The hand-over check**: at hand-over the GM runs the same checks
  again, every planted fault included, before the snapshot. It does not
  hand over a game whose check fails: it re-plants a fault whose
  scheduled planting failed (`inject --at now --instance <id>`, 8.7),
  when the fault's aging minimum can still be reached in the time the
  initiator has, and otherwise tells the
  initiator and offers to set the game up again (8.7).

### 8.6 Disk and retention

The aging plus a four-hour game grow the tables, the WAL, the PostgreSQL
logs, Prometheus' TSDB and the schedulers' logs. The growth is measured
on the v0.3 scenario, declared per hour in the footprints and counted by
`fit` over the scenario's aging, with the hand-over snapshot's copies.
Prometheus keeps at least the aging minimum plus four hours (6.1).

### 8.7 Failures during the aging

- **Scheduled actions never tear down.** A scheduled `inject --at`, the
  early check, or any other setup action during the aging that fails
  records its failure and reason in the local implementation and leaves
  the game running. The game's stage is not set to failed. Setup
  failures before T0 (render, deploy, data load, the T0 faults) tear the
  game down as in v0.2, since nothing has aged yet. A `start-load` that
  fails on one scheduler tears nothing down either: the GM sees which,
  fixes it or stops the game.
- **One instance at a time.** `gmctl inject --at <moment> --instance
  <id>` acts on one `state` fault instance only, never replaying the
  others: with a UTC time it schedules that instance's planting on the
  manager; with `now` it plants it at once. The scheduled run is itself
  `inject --at now --instance <id>`. Both need the stage `load-started`.
- **A failed planting** is re-planted by the GM with `gmctl inject --at
  now --instance <id>` before hand-over; the earliest hand-over is
  recomputed from the actual planting time.
- **Restarts resume.** The load-started marker (7.1) persists on the
  schedulers' volumes, so after a container, Swarm task or host restart
  every scheduler comes back running at the current time. Missed
  fixed-time runs are not replayed.
- **Outages.** A minute of the aging is in outage when any node of the
  game was not running, or any scheduler wrote no per-minute summary,
  its process down or idle (a host down, a Tailscale partition, a
  crashed node). A running scheduler writes its summary every minute,
  even when no call ran, so a low-rate stream never reads as an outage.
  `gmctl` reads the outages from the schedulers' summaries and the
  nodes' task history, at the early check, at the hand-over check and on
  `status`, and records the lost time: the outage minutes in all.
- **The threshold: thirty minutes.** Lost time up to thirty minutes in
  all is recorded and does not move the earliest hand-over: a real system
  has blips. Lost time beyond thirty minutes moves the earliest hand-over
  later by the excess, and the GM judges at hand-over whether the
  evidence the issues rely on survived (a fault whose evidence fell in
  the gap, a fixed-time run missed): either it hands over, the story
  telling the gap as an incident, or it sets the game up again.
- **Setting the game up again before hand-over** is a stop then a start,
  asked or agreed by the initiator: a new game, its aging starting from
  zero. `restart` is a players' operation after hand-over and is never
  used for it.

## 9. Load

- Load is calibrated against the nerfed databases: enough to show
  symptoms, never enough to saturate the host. Slowness comes from the
  CPU and memory limits, the memory settings and the intensity.
  Connection exhaustion shows as refused sessions ("too many clients"),
  not slowness.
- Rates are chosen so tables stay small over the aging (one insert a
  second is about 29,000 rows in eight hours, 86,000 in a day).
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
The available hosts: armenelos (11 GB of memory, about 5 GB available
and about 5 GB of swap in use when the review measured it) and a VPS,
linked by Tailscale. A playground is declared at the memory its hosts
have available, not their total.

### 10.2 Several hosts

- **The playground declaration** lists its hosts: for each, its swarm
  node name, its Docker endpoint (SSH over Tailscale for a remote host),
  whether it is the manager, and its capacity (CPU, memory available,
  disk). It also maps each host the scenario's `designed_for` names onto
  one of them. A one-host declaration keeps today's form, read as a list
  of one. It may also name the private range its games' overlays take
  their subnets from, which the GM chooses for the execution environment
  (the risks below).
- **Placement per node.** The scenario format already places every node
  on a declared host and sums each host's placed nodes against its
  capacity. The local implementation now places nodes on the real
  playground's hosts through that mapping, and the renderer writes them
  as hostname constraints, replacing the single "manager" constraint;
  stateful nodes are pinned with their volumes, the bastion to its host
  (7.5). A node that publishes ports is placed on the manager only:
  `gmctl fit` refuses a mapping that puts one on another host, naming
  the mapping to change, since a host-mode port opens on every address
  of its host, and a worker such as the VPS has a public one.
- **Images are copied, no registry.** The GM builds the images on the
  manager and copies to each other host the images of the nodes placed
  there, with `docker save | docker --context dbagm-<host> load`
  through the host's SSH Docker context over Tailscale, skipping an
  image the host already holds under the same id. Deployment never
  pulls (`--resolve-image never`, as today), image names stay as they
  are, and nothing listens on any host for images. The cost, about
  1.7 GB per new host, is paid once per build. Single-host games copy
  nothing.
- **`fit` per host**: each host's limits, reservations and disk against
  the nodes placed on it, each host's images counted once on that host.
- **Per-host SSH Docker contexts** for the exec verb and the image copy.
- **The default game stays single-host** while its load fits one host.

Risks the build checks on armenelos plus the VPS:

- the overlay's VXLAN inside Tailscale's 1280-byte MTU: the MTU of the
  game's overlay network, and of the swarm's ingress network too, set to
  leave room for both;
- Swarm bound to the Tailscale addresses: `--advertise-addr` and
  `--data-path-addr` on the Tailscale interface, so the swarm's ports
  (2377, 7946, 4789) carry nothing over a public address;
- the overlay's addresses: Swarm's default pool hands out subnets the
  VPS's local networks already hold, so a game spanning several hosts
  takes its overlay's /24 from a private range the GM chooses,
  `10.20.0.0/16` proposed by default, free on the swarm and on every
  placed host, kept across a restart unless the GM changes the range;
  `deploy` refuses rather than overlap, naming what is taken and how to
  choose another range (D182, D183);
- both hosts up for the whole aging; a reboot or a partition is an
  outage (8.7).

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

**The rehearsal**: before the release gate's aged run, a
short unattended run of about two hours on armenelos plus the VPS,
exercising what the smoke tests skip: `start-load`, a scheduled
`inject --at` and the early check fired by the host's timer, a scheduler
container killed and resuming, an outage of a few minutes recorded, the
hand-over check, the snapshot with its brief stops, and a restart from
it. The memory footprint of the whole game is measured during it, before
the gate. Its planned hand-over (`render --handover`) is chosen so the
traffic shapes' peak hours fall inside the two hours, since the memory
measured means something only under peak load. The aging's length adds
nothing to these, so the rehearsal stays short. It reaches its hand-over
within the two hours through a test-harness-only override of the aging
minimum, which caps the scenario's aging minimum and each fault
instance's own (D161); it shortens the wait, never a clock, and a game
never uses it.

**The release gate** includes one full aged run of the v0.3 scenario at
its declared aging minimum, then a play-through as `player` (section
17).

## 12. Restart

A restart rebuilds the game from scratch: every node shut down, the
game's data destroyed, fresh nodes started under a new game id, the game
set up again. Every generated secret of the game is kept, the players'
credentials and the service ones alike (application roles, PgBouncer's
lookup role, the GM check role, Grafana's administrator), so the players
log in as before and the restored databases and Grafana match them: the
new game id gets new Swarm secret objects carrying the same values. The
replay may differ (a new seed). The rebuilt game enters the stage
`handed-over`, its four hours still counting from the first hand-over.

- **Confirmation.** Any player in the GM session may ask. The GM first
  states that the game's state and the players' changes will be lost
  and, when there is no snapshot, which evidence goes with them; it
  restarts only when a player confirms in so many words. A passing
  mention, or a question about restarting, never restarts a game. A stop
  still needs no confirmation. The GM records the confirmation with
  `gmctl restart --confirmation "<the player's words>"`, which refuses
  to run without it.
- **From the hand-over snapshot, where the disk allows.** At hand-over
  the GM copies every volume of the game, each brick by its declared
  method (section 6.4). A restart starts the fresh nodes on fresh copies
  of it; the schedulers find their load-started marker and resume, every
  timeline change already past. The history then has a gap from
  hand-over to the restart, which the story tells as a maintenance
  window. A restart copies the snapshot and leaves it as it was, so a
  second restart starts from it again; it is removed only at teardown.
- **Otherwise, no history.** When the copies do not fit the disk, the
  game has no snapshot, and a restart starts from nothing: the data
  loaded, every fault planted at once (those due at T0 and those due
  during the aging), the load, when the game has scheduler nodes, started
  at once with every timeline change already applied. Only the history since the restart exists. The GM
  names the evidence lost (the faults whose aging minimum the new game
  will not reach) before the players confirm, and judges the final answer
  accordingly.
- **The restart's own setup** runs inside `gmctl restart`: the refusals
  of `start-load` and `inject --at` after hand-over do not apply to it.
- **No extra time.** A restart does not extend the game's four hours,
  which still count from the hand-over; extra time stays beyond v1.0.
- **Record.** The local implementation records each restart: the old and
  new game ids, the time, from the snapshot or not, and the player's
  confirmation.
- A whole-game restart is not a node reset; node resets, hints and extra
  time stay beyond v1.0.

## 13. The local implementation and the scripts

**Local implementation** additions: the playground's hosts and the
mapping onto them; per-node placement; the images copied to each host;
the planned hand-over and the shift; T0, the aging minimum, the running
time and the outages, the earliest hand-over, the hand-over; the seed;
the scheduled setup actions and their results; the early check's and
the hand-over check's results; the hand-over snapshot's location; each
restart with its confirmation.

**Stages**: `fitted`, `rendered`, `deployed`,
`data-loaded`, `injected`, `load-started`, `handed-over`,
`final-answer`, `feedback-given`, `torn-down`. The aging is the span from
`load-started` to `handed-over`; whether it is done is computed from the
earliest hand-over, never recorded as a stage. `start-load` requires
`injected`; `inject --at` and `snapshot` require `load-started`;
`status --set handed-over` requires the earliest hand-over reached, the
hand-over check passed, and the snapshot taken or recorded as not
fitting. A restart's rebuilt game enters `handed-over` directly, under its
new game id (section 12). A game with no scheduler node has no aging
(section 8) and never reaches `load-started`: `start-load` refuses it
with a one-line reason, `snapshot` requires `injected`, and `status --set
handed-over` requires only the hand-over check passed and the snapshot
taken or recorded as not fitting.

**`gmctl`**:

| Verb | Change |
|---|---|
| `fit` | the playground's hosts; per host; counts aged growth over the scenario's aging and the snapshot's copies; says when the snapshot does not fit |
| `render` | takes the planned hand-over (`--handover <UTC date and hour>`), optional for a scenario with no scheduler node, where it shifts nothing; per-node placement as hostname constraints, the shift, the customer's time zone filled in, write policies and overrides passed to the containers |
| `deploy` | copies the images to each host that lacks them before deploying |
| `start-load` | new: writes each scheduler's load-started marker and starts its schedule; records T0; refused once the game is handed over |
| `inject --at` | new option, with `--instance <id>`: one `state` fault instance, its planting scheduled on the manager at a UTC time, or planted at once with `now` (the scheduled run, and a re-planting); refused at or after hand-over; a failure is recorded, never a teardown (8.7) |
| `snapshot` | new: takes the hand-over snapshot by each brick's method; refused before the earliest hand-over and once the game is handed over |
| `restart` | new: the rebuild of section 12, from the snapshot or from nothing, the rebuilt game at `handed-over`, the snapshot kept for a later restart; refused without `--confirmation` |
| `check` | reads exit 3 as "too soon to tell"; connects as the GM check role; runs the early check and the hand-over check |
| `status` | heads with any failure or outage; the aging's progress, the lost time, the earliest hand-over, the shift, the snapshot, restarts; no tools-password line in a game without a web front |

No verb pauses, speeds up or triggers the load.

**The GM skill**: the aging and the timeline; the feasibility judgement
of 8.2, declining a scenario or proposing another when the time is too
short; the early check and the hand-over check; failures and outages
during the aging and when to set the game up again; the refusal of an
early hand-over; load control; the restart's confirmation and statement;
scenario time, the planned hand-over and the customer's time zone in the
starter pack; the maintenance window told at hand-over; choosing another
range for a game's overlay when the proposed one is taken (10.2).

## 14. Player access and rules

The full rules are in the [access model](access-model.md). In short:

- On a scheduler node the players read the repository, `jobs.yaml`, the
  log and the configuration other than `schedule.yaml`, which is
  root-only; they edit the repository and `jobs.yaml` where the scenario
  makes them fixable.
- Write policy may be set per file through write overrides.
- On PgBouncer they read the console as `dba`, a `stats_users` role there.
- `ALTER SYSTEM` on a report-only database node would not be prevented
  for the superuser `dba`, accepted on the trust line; the case does not
  arise in v0.3, where `postgres` is fixable only.
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
  least one `state` fault planted during the aging.
- **Write policies**: the database and PgBouncer fixable; the scheduler
  nodes report-only, with the producer's repository and both `jobs.yaml`
  files fixable by override; one monitoring node fixable, one
  report-only.
- **Aging minimum: 16 hours**, the hand-over designed for the customer's
  early afternoon, so the aging covers the night (the nightly batch, the
  export) and the morning ramp, and the time-of-day faults run within
  it: deployed the evening before, played after lunch. Prometheus'
  retention at least 20 hours.

### 15.3 New catalog faults

| Fault | Lives in | Evidence | Resolutions |
|---|---|---|---|
| A query with a syntax or type error | repository | scheduler log, PostgreSQL log, error counters | report, propose, fix |
| A query missing its `WHERE` (updates every row) | repository | `pg_stat_statements` rows per call, bloat, lock waits | report, propose, fix |
| A reporting query reading far too much (`SELECT *`, no date bound) | repository | temporary files, `work_mem` spills, slow-query log | report, propose, fix |
| Inserts retried without idempotency: duplicates | repository | duplicate rows | report, propose, fix |
| A consumer holding transactions open | schedule (hold) | `pg_stat_activity`, `idle in transaction`, vacuum held back | report, propose |
| A nightly batch at the daily peak | `jobs.yaml` | lock waits and latency at the peak, the job's time | report, propose, fix |
| A job in the wrong time zone | `jobs.yaml` | run times in the log against the customer's time zone in the story; the job's zone offset from it | report, propose, fix |
| A PgBouncer pool too small for the peak | PgBouncer seed | `SHOW POOLS` waiting clients, latency | report, propose, fix |

Each has its injection, its aging minimum, its sealed check judging the
cause (the query's text, the job's time and zone, the pool's size, the
schedule's hold), and its solvability description; the duplicates fault
is judged over a window. All eight are `seed-file` faults, planted at
render. A fault living in the schedule is report or propose only, since
players never change streams.

### 15.4 Existing scenarios

`bookshop-new-server` and `fernway-clinics-monitoring` are re-pinned to
the bumped bricks and still deploy. Neither gains producers, so neither
ages (section 8, D157): no `aging:`, their faults visible at once and
their definitions' own aging minima not counted (D160), the game handed
over once they are planted, as in v0.2. Both keep the hand-over check
and the hand-over snapshot (D162): at `fernway-clinics-monitoring`'s
hand-over, Prometheus and Grafana stop briefly while their volumes are
copied, the scrape gap told as maintenance (7.4).
`fernway-clinics-monitoring`'s retention of one day covers the four-hour
game, so it stays; its 256 MB size bound is checked against the measured
TSDB growth.

## 16. Carried fixes

- Configuration files edited in place (`sed -i`) are restored to their
  owner and mode by the reload wrappers.
- `gmctl status` shows no tools-password line in a game without a web
  front.
- Every catalog fault's evidence moves to the location form of 6.3.
- The existing catalog faults' database sealed checks move from
  `postgres` over the local socket to the GM check role (6.5).

## 17. Definition of done

1. The `scheduler` and `pgbouncer` bricks at 0.1.0, with GM documentation,
   validators and measured footprints; `postgres` 0.3.0, the three
   monitoring bricks 0.2.0 and `bastion` 0.3.0 as in section 7.
2. The format changes of section 6 in the templates, the loader and the
   format skill; the eleven existing catalog faults in the new evidence
   form, their database checks on the GM check role.
3. The eight new catalog faults, each with injection, aging minimum,
   cause-first sealed check and solvability description.
4. The new scenario, complete by the format skill, its scenario document
   generated.
5. `gmctl` as in section 13, the failures during the aging of 8.7
   included.
6. Short smoke tests green on one host and on armenelos plus the VPS;
   the rehearsal of section 11 passed, the game's memory measured.
7. The release gate's full aged run: the v0.3 scenario aged for its
   declared minimum, then a play-through as `player`; every fault's
   evidence reachable; the sealed checks right under load before and
   after fixes; one restart from the hand-over snapshot; the measured
   footprint and aged growth within the declared figures.
8. The GM skill updated as in section 13.
9. Both existing scenarios deploy re-pinned, with no aging, having no
   scheduler node (D157).

## 18. Grounding: what exists and what is at risk

Read in the code at the v0.2 close, and checked by the independent
review:

- **The scenario format already places nodes per host**:
  `designed_for.placement` is checked by the loader (`tools/gm/model.py`),
  which sums each host's placed nodes against its capacity. Multi-host
  extends this rather than inventing it.
- **The renderer pins every service to the manager**
  (`PLACEMENT_CONSTRAINT` in `tools/gm/localimpl.py`), and `fit`
  (`tools/gm/fit.py`) checks one host against a one-host playground
  declaration: both change.
- **Every port is already published in host mode** (`tools/gm/localimpl.py`,
  `tools/gm/render.py`), since v0.1. The multi-host change is pinning
  the bastion to its host, not the publishing mode.
- **Images are tagged `127.0.0.1:5000/...` but built locally**, and
  deployment already never pulls (`--resolve-image never` in
  `tools/gm/deploy.py`): copying images to each host fits as it is.
- **The bastion's web front forwards every path under a route
  unchanged** (its nginx configuration, generated in the bastion's
  entrypoint): nothing there could refuse Prometheus' admin paths, which
  is why Prometheus is snapshotted by a brief stop with its admin API
  off.
- **Any setup failure tears the whole game down today**
  (`tools/gm/state.py`'s setup step, used by `tools/gm/inject.py`): the
  scheduled actions of the aging need the record-only handling of 8.7.
- **The stages** (`STAGES` in `tools/gm/localimpl.py`) end the setup at
  `injected`; v0.3 adds `load-started`.
- **The existing database sealed checks run `psql` as `postgres`** over
  the local socket; they move to the GM check role.
- **`postgres` allows the fixable write policy only**
  (`bricks/postgres/brick.yaml`), and the monitoring bricks likewise.
- **Nothing passes a node's write policy to its container** today; the
  loader only checks resolutions against node write policies
  (`tools/gm/model.py`). Per-file policies and report-only monitoring
  nodes both start here.
- **The fault template carries no aging field** and keeps free-text
  evidence `where`, although the format has required aging since v0.1.
- **The scenario smoke test** (`tools/tests/smoke-scenario.sh`) expects
  every sealed check present within 120 seconds of injection on a still
  system; it is rewritten for load.
- **Memory on armenelos is tight**: about 5 GB available with about 5 GB
  of swap in use, against a game expected at about 5 GB. The game's
  footprint is measured in the rehearsal, before the gate, and the
  playground declared at the memory available, not 11 GB.
- At risk of disruption: the sealed-check contract (a third exit code
  every caller must read); the loader's resolution check (now per file);
  the renderer's placement (every existing scenario re-rendered); the
  `postgres` start-up (the reserve and the check role); the setup
  failure path (record-only during the aging).

## 19. Architectural decisions and their reasoning

- **Real-time aging**, rejecting a sped-up clock, forging and VM
  snapshots: only real time is consistent for every component, Go
  binaries and file times included (section 8.1).
- **An eight-hour floor, each scenario declaring its own aging**: short
  agings keep games affordable; the GM judges whether a scenario's
  evidence can grow in the time a class allows. A scenario with no
  scheduler node has nothing to age and no aging (D157).
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
  any hour sees the designed load while every timestamp stays real; the
  customer's time zone follows the shift, so the story stays true.
- **Checks judge the cause first**: a cause is stable under load, a
  symptom is not; windows and "too soon to tell" cover the rest.
- **A connection reserve pinned on the command line**: the GM must reach
  the database under an exhaustion fault, and no player-editable file can
  remove it.
- **The hand-over snapshot per brick, online where the brick has a
  method**: the database by `pg_basebackup`, plain copies for seeded and
  append-only volumes, a brief stop for Prometheus and Grafana.
  Prometheus' snapshot API would need its admin API on, reachable from
  the whole game network; a stop of a few seconds removes that exposure
  and leaves the bastion image unchanged.
- **Failures during the aging never tear down**: an unattended aging lost
  at hour fifteen costs the whole aging again; a recorded failure costs
  one judgement at hand-over.
- **Images copied host to host, no registry**: a registry on the routing
  mesh would listen, unauthenticated, on every host's addresses; copying
  over SSH opens nothing.
- **Always-on hosts**: the aging rules out hosts that are not there;
  copying aged volumes elsewhere is the later path.
- **The bastion pinned to its host on multi-host**: its host-mode ports
  then open on one host only.
- **Write policy per file**: a scheduler's repository can be fixable
  while its node stays report-only, the realistic split.

## 20. Deferred items and points left to the build

Deferred (section 2 lists the scope): v0.5 adjusts every default above
after use; a later version brings classroom swarms by copying aged
volumes; whether a sped-up clock, forged history or time compression
ever returns is open; scoring after v1.0; Kubernetes later.

Left to the build, to settle without changing behaviour:

- the footprints of every new or bumped brick, and the aged growth per
  hour, by measurement;
- the overlay and ingress MTU over Tailscale, and Swarm bound to the
  Tailscale addresses, tried on armenelos and the VPS;
- the image copy (`docker save | docker --context dbagm-<host> load`,
  through the host's SSH Docker context), tried on the same pair;
- `auth_query`'s exact set-up in PgBouncer, `auth_dbname` for the console
  included;
- the size of the GM's connection reserve (two connections expected);
- how `gmctl` schedules setup actions on the manager (a timer of the
  host's, recorded in the local implementation);
- how `gmctl` reads outages from the schedulers' summaries and the
  nodes' task history;
- the loader's check that a seed allows `pg_basebackup` locally;
- the GM check role's grants on `pg_hba_file_rules`: `SELECT` on the
  view and `EXECUTE` on the function (7.3);
- `pg_basebackup`'s form on a read-only root: in tar format to standard
  output it needs `-X fetch`, and the WAL written during the copy must
  stay until it ends, by a temporary physical replication slot reserving
  WAL from its creation and dropped afterwards, failure included, rather
  than a pinned `wal_keep_size`; or a copy into a snapshot volume.

Known limits, accepted (also in the access model): the players' `dba`, a
superuser, can still use up the GM's reserve; Grafana's interface
ignores report-only; a player editing a fixable builder runs code as the
scheduler's account, and can make it print the schedule; the traffic can
be inferred from the schedulers' logs and the database's own; the scrape
gap at hand-over, told as maintenance.
