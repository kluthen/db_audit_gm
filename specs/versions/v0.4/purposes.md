# v0.4 — the purpose: artefact, format, job runner, time

Status: draft v3

What a purpose is in the catalogue, how it is written down, what runs its
jobs, and how its cadence meets real time. The purposes themselves are in
[purpose-catalogue.md](purpose-catalogue.md); their checks in
[checks.md](checks.md). Settled by D190: a purpose is its jobs, its trace,
its invariants and the faults that break them; consumers exist only
through their trace.

## Grounding: what v0.3 already gives

Read on `v0.3-w4` (2026-10-30):

- **The scheduler runs fixed-time jobs.** `jobs.yaml` names a job, a
  repository key, a schedule connection and a 5-field cron `at`, with an
  optional `timezone` (`gm_scheduler/jobs.py`). A run is one key on one
  connection; a run still going when the next is due is skipped, and
  nothing missed is replayed (`runner.py`).
- **A run leaves a trace already.** The scheduler log records
  `run job=… key=… phase=start` and `phase=end status=ok rows=… ms=…`
  (or `status=error sqlstate=…`), `skip` lines, and `reload status=ok`
  on every reload; `/run/scheduler/loaded` holds the digest of every file
  the program loaded. The wrong-time-zone check already reads these
  (`faults/scheduler-job-wrong-timezone/checks/fixed.sh`).
- **A node may have jobs and no stream**: `schedule.yaml` needs at least
  one connection; `streams` may be empty (`schedule.py`).
- **One connection per key.** A key runs on one database; nothing in the
  scheduler moves rows from one database to another. A builder is Python
  the program loads from the repository, players' edits included (D133),
  but it only returns statements: it never touches a connection.
- **Roles.** The scheduler brick declares `producer` and `consumer`; the
  loader's role list already has `transformer` (`tools/gm/model.py`). A
  scheduler node is recognised by its brick, not its role.
- **Checks reach any database from a scheduler node** as `gm_check`
  through the root-only `check-sql` helper, straight to port 5432
  (D185).
- **The customer's time zone** reaches only the bastion's seed files
  (`{{customer_timezone}}`, `tools/gm/render.py`, `model.py`); databases
  run in UTC (`timezone = 'UTC'` in tarnbeck's seed).

## The artefact

A purpose is a catalogue unit beside bricks, faults and scenarios (D190).
Its name stays "purpose" (proposed; O104): it says what the data is
*for*, which is the milestone's point, and collides with no existing
term.

### Layout (proposed; O104)

```
purposes/<purpose-id>/
  purpose.yaml       identity, parts, jobs, trace, invariants, data moved
  material/          the jobs' repository entries, transformer scripts and
                     jobs.yaml lines, the target's DDL (foreign servers and
                     procedures included), as the GM copies them into a scenario
  checks/            one script per invariant (checks.md)
  gm.md              what the purpose is for, how it can go wrong, feedback notes
```

### `purpose.yaml` must contain (proposed; O104)

- **Identity**: id, title, the domains it fits (`shop` in v0.4; D192).
- **Parts**: the roles the scenario fills with its own nodes and
  databases, for example `source` (a database), `target` (a database),
  `runner` (a scheduler node, `transformer` by role), `consumer`
  (optional, a scheduler node reading the published results). The
  scenario maps each part to a node; source and target may be databases
  of one instance or of two (D202).
- **Jobs**: for each, its name, its repository key, its part (which
  runner), its source and target, its movement method (a transformer
  script, SQL through foreign tables, a stored procedure; D202), what it
  computes in one sentence, its cadence in scenario time, and the
  customer role of each connection it holds.
- **Trace**: each place the purpose leaves something, with its kind
  (outbox rows, published results, run ledger, definitions; README "Consumers
  are modelled by their trace"), its table or file, and the column that
  ties a row to the run that wrote it.
- **Invariants**: for each, an id, a one-sentence statement against the
  source, the check script judging it, its parameters, and its **witness
  condition**: what must exist in the data for a run to be able to
  violate it (see [checks.md](checks.md), "Witnesses").
- **Data moved**: which classed columns each job reads and where it
  writes them, so governance can be checked against it
  ([governance.md](governance.md)).
- **Customer roles** the purpose needs, with their grants.

### How a scenario uses a purpose (proposed; O104, O111)

The GM copies a purpose's material into the scenario at design time, as
it writes a scheduler's repository today: the jobs go into the runner
node's `queries.yaml`, `scripts/` and `jobs.yaml`, the target's DDL into
the target node's data file. The scenario folder stays self-sufficient (D23).
`scenario.yaml` gains a `purposes:` list naming each purpose used and
mapping its parts to nodes; the loader checks that every job's key and
name exist on the mapped runner and that every part is mapped.

Since the material is copied, a purpose **never bumps**, as faults and
scenarios never do (D58, D60); `purposes:` names it by id, for
provenance and for the faults that attach to it.

### Faults attach to purposes (proposed; O104)

`applies_to` gains `purposes: [<purpose-id>, …]` beside `bricks:`. A
purpose fault also lists the `scheduler` brick versions its runner needs,
since its sealed check runs there. Its parameters name the job and keys
it changes; it is planted as v0.3's scheduler faults are: `seed-file`
changes to the runner's `queries.yaml`, a script or `jobs.yaml`, or to a
database's data file, at render; or a `state` change during the aging.

## Instances and nodes (D202, D204)

A scenario may have **several PostgreSQL instances**, each a `postgres`
node of its own (D202). D198's reporting instance is one case of it.
v0.4's first scenario keeps two, `db` (the shop) and `reporting`
(proposed): the four purposes need no third, and each instance costs
about 256 MB.

**Nodes are sized by role** (D204):

- **Each distinct producer runs on a node of its own**, sized as small
  as it runs: its scenario `resources` set from its measured peak, below
  the `scheduler` brick's default where the measurement allows
  (tarnbeck's producer peaked at 39 MB against 64 MB reserved).
- **A transformer node may be sized larger**, to hold the volume its
  scripts move in one run.
- An **undersized transformer** is a fault for later, not v0.4: v0.5's
  catalogue, and the capacity family of the provider layer after v1.0
  (D205). Until players may resize a node it can only be reported or
  proposed: hard limits are the platform's ([platform.md](../../platform.md),
  "Resources and nerfing").

"Its own machine" is read as a **scenario node** with its own
reservation, placed on a host by `fit` and the designed placement as in
v0.3, never a host per producer (D204, confirmed by the owner): one-host
games and classroom swarms keep working. In the specs a **node** is a
scenario node; a swarm machine is a **host** ([concept.md](../../concept.md)).

## The job runner (D203)

**Extend v0.3's `scheduler` brick, no fork** (D203). In the owner's
words (D202): "independent python script with a scheduler (so we may
probably reuse the scheduling block we have already, just attach the
script in there)". A purpose's jobs are fixed-time operations in a
scheduler node's `jobs.yaml`, run as today; what is new is the
**transformer script**, a Python file attached to the node's
repository, which may hold several connections.

| Need | Change | Brick bump |
|---|---|---|
| Jobs on a node with no stream | none: `streams` may be empty | no |
| A job moving rows between instances | a transformer script: a new repository form and a job naming several connections | yes |
| A node role `transformer` | added to `brick.yaml`'s roles; `tools/gm/model.py` already lists it | yes |
| A SQL job through `postgres_fdw`, or calling a stored procedure | none: one SQL statement on one connection, as today | no |
| A run's start, end, rows, status | none: a script's run logs the same lines | no |
| When the runner's files last changed | none: `reload status=ok` lines and `/run/scheduler/loaded` (which gains the scripts) | no |
| The customer's time zone in a job | `render` substitutes `{{customer_timezone}}` in the scheduler's seed files (O122) | no (tools only) |

So **`scheduler` 0.2.0** ships with v0.4 (D203). v0.3 already lets the
players' edited Python run in the program (builders, D133) and accepts
that a fixable builder can leak the schedule (D148): a fixable script
sits on the same trust line, with live connections as its roles beside.

### The transformer script (proposed; D203)

- **Where it lives**: `scripts/<file>.py` in the repository
  (`/srv/scheduler/repository/scripts/`), seeded once, read by the
  players and fixable where the node's write policy allows, as
  `builders/` are. A new seed entry `scripts/`.
- **The repository entry**: `{script: scripts/<file>:<function>,
  options?}`, a fifth form beside query, pool, sequence and builder.
- **The job**: `jobs.yaml` names `connections: {<name>: <connection>,
  …}` instead of `connection:` for a script key, each a connection of
  the schedule; `source` and `target` by convention. The loader and the
  program check every name exists, as they check `connection:` today.
- **The call**: `<function>(conns, options, log)`. `conns` maps each
  name to an open psycopg connection as the schedule's role for it,
  autocommit off; the script commits what it means to commit and
  returns the rows it wrote. `log(text)` appends a `script job=…` line
  to the scheduler log. The runner opens and closes the connections:
  **a script never holds a password**, and players still never see
  `schedule.yaml` (D116, D130).
- **Its run**: in a worker thread of the program, the next run skipped
  while one is going, as today. An exception ends the run with
  `status=error` (`sqlstate=…` for a database error, `error=<class>`
  otherwise); nothing else stops. A script that exhausts its node's
  memory takes the program down with it, which s6 restarts: the
  undersized transformer's symptom, and why a transformer sits on a
  node of its own (D204).
- **What it may import**: the standard library, psycopg 3 and PyYAML,
  which the image has. Anything more (pandas) is an image change with
  its dependency check.
- **PostgreSQL only**: a script talks psycopg, outside v0.3's driver
  interface. v0.5's other targets (D118) stay drivers.

**What the players reach** stays D116 and D130: they read the
repository, the scripts and `jobs.yaml`, edit them where the scenario
allows, move a job's time, and never see `schedule.yaml`. Moving a job
is how they verify a fix to it (D132), and the starter pack says so.

## Moving data between instances (D202)

PostgreSQL cannot query across databases, even in one instance, without
an extension. The ways v0.4 allows, a scenario picking among them per
flow (D202):

| Method | Runs from | Audit surface it brings |
|---|---|---|
| **A transformer script** (the main way) | a transformer node's job | the script's code; the roles of its connections, which no catalog shows (G3, [governance.md](governance.md)); non-atomic writes across two connections; errors swallowed into a clean-looking run |
| **SQL through foreign tables** (`postgres_fdw`) | a producer's key, a transformer's job or script | the foreign server and who owns it; user mappings holding passwords, a mapping `FOR PUBLIC`; the remote role's reach; imported foreign tables; pushdown in `EXPLAIN VERBOSE` |
| **A stored procedure** doing either SQL movement | called (`CALL`) from the same places | `SECURITY DEFINER` and its owner, `search_path`, `EXECUTE` left to `PUBLIC` |
| **A cron job local to the database node** | `pg_cron` or cron in the `postgres` node | a job invisible from the runners: held, no brick change in v0.4 (O129) |

`postgres_fdw` ships in the PGDG server package the `postgres` brick
installs; the data file creates it as superuser. Where a scenario uses
it, `load-data` sets each user mapping's password from its remote
role's secret, a new step ([checks.md](checks.md)).

**v0.5's transformation triggers** (D118: triggers as scheduler
drivers) are untouched: a later driver can run the same SQL jobs
elsewhere.

## Time: cadence under real time (D199)

No sped-up clock, no forged history, no time compression (D114, D132);
nobody triggers a job during a game (D131). Settled (D199):

1. **Each purpose runs at the cadence a real business would give it,
   chosen where that is sub-daily**: transactional mail every few
   minutes, a campaign batch every quarter hour in its sending hours,
   lead extraction hourly, an hourly incremental reporting load. These
   run many times during a four-hour session, so a fix shows within the
   game.
2. **A daily job stays daily** where the business closes a day (the
   reporting close at 01:30). Its fix is verified as D132 says: the
   players move its time. A smoke test does the same (D200).
3. **Weekly and monthly purposes are out of v0.4** (O22): a monthly
   close or a weekly report cannot run inside a game, and moving it
   proves a single run.
4. **Past trace in the restored backup.** The data file is "last night's
   backup" and already computes fifteen days of orders and a daily
   roll-up (`tarnbeck-outdoor-shop/data/db.sql`). The backup may hold a
   purpose's past trace the same way (KPI rows, past mail), computed by
   the data load consistently with its rules, but **a fault's evidence
   never rests on it alone**: every fault's evidence is produced live
   during the aging, and its aging minimum counts from that (D189).

### The customer's time zone in the data (O122)

Purposes reason in local time: a business day, a recipient's sending
hours. The customer's time zone is UTC plus the game's shift (D129), so
it is known only at render, and with a shift of 0 it is UTC itself. Two
consequences:

- **The zone must reach the data and the jobs.** Proposed: `render`
  substitutes `{{customer_timezone}}` (as `Etc/GMT∓N`) in the scheduler's
  seed files, as it does in the starter pack; `load-data` passes the
  zone and its offset to `psql` as variables (`-v customer_timezone=…
  -v customer_utc_offset=…`), which the data file writes into a
  `business_settings` row. Databases stay in UTC; logs and clocks are
  untouched (D129).
- **Shift invariance.** A fault must not vanish with a shift of 0.
  Recipients' zones are stored as fixed offsets **relative to the
  customer's** (computed at load: the customer's offset plus a designed
  delta), and a day-boundary fault takes its wrong zone as an offset from
  the customer's, as the wrong-time-zone fault does (D168). Neither ever
  reads "UTC" as the wrong zone.
