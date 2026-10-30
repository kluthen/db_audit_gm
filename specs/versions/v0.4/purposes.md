# v0.4 — the purpose: artefact, format, job runner, time

Status: draft v1

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
  scheduler moves rows from one database to another.
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
  material/          the jobs' repository entries and jobs.yaml lines,
                     the target's DDL, as the GM copies them into a scenario
  checks/            one script per invariant (checks.md)
  gm.md              what the purpose is for, how it can go wrong, feedback notes
```

### `purpose.yaml` must contain (proposed; O104)

- **Identity**: id, title, the domains it fits (`shop` in v0.4; D192).
- **Parts**: the roles the scenario fills with its own nodes and
  databases, for example `source` (a database), `target` (a database),
  `runner` (a scheduler node), `consumer` (optional, a scheduler node
  reading the published results). The scenario maps each part to a node.
- **Jobs**: for each, its name, its repository key, its part (which
  runner), its source and target, what it computes in one sentence, its
  cadence in scenario time, and the customer role it runs as.
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
node's `queries.yaml` and `jobs.yaml`, the target's DDL into the target
node's data file. The scenario folder stays self-sufficient (D23).
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
changes to the runner's `queries.yaml` or `jobs.yaml`, or to the target's
data file, at render; or a `state` change during the aging.

## The job runner (O105)

**Proposed: extend v0.3's `scheduler` brick, no fork.** A purpose's jobs
are fixed-time operations in a scheduler node's `jobs.yaml`, run as
today. What v0.4 needs of it:

| Need | Change | Brick bump |
|---|---|---|
| Jobs on a node with no stream | none: `streams` may be empty | no |
| Cross-database movement | none in the runner: the target pulls from the source through `postgres_fdw` (O123) | no |
| A run's start, end, rows, status | none: the log has them | no |
| When the runner's files last changed | none: `reload status=ok` lines and `/run/scheduler/loaded` | no |
| The customer's time zone in a job's SQL | `render` substitutes `{{customer_timezone}}` in the scheduler's seed files (O122) | no (tools only) |
| A node role `transformer` for a purpose runner | add it to `brick.yaml`'s roles | yes, 0.2.0 |

The last row is optional: a purpose runner can be a `consumer`, which it
is (it reads the source). Proposed: keep `consumer` and bump nothing, so
v0.4 may ship with `scheduler` 0.1.0 unchanged (O105).

**What the players reach** stays D116 and D130: they read the
repository and `jobs.yaml`, edit them where the scenario allows, move a
job's time, and never see `schedule.yaml` (hence never the runner's
connections). Moving a job is how they verify a fix to it (D132), and
the starter pack says so.

**v0.5's transformation triggers** (D118: transformation triggers as
scheduler drivers) are untouched: a purpose job is SQL on PostgreSQL;
a later driver can run the same jobs elsewhere.

### Cross-database movement (O123)

PostgreSQL cannot query across databases, even in one instance, without
an extension. Two ways to move rows from the source to a reporting
database:

- **`postgres_fdw` in the target (proposed).** The reporting database
  holds foreign tables over the source, through a user mapping to a
  source role; a job is one `INSERT … SELECT` from foreign tables, run on
  the reporting database. Plain SQL in `queries.yaml`; no runner code;
  `postgres_fdw` ships in the PGDG server package the `postgres` brick
  installs (`postgresql-${PG_MAJOR}`), created by the data file as
  superuser. What players can audit becomes real evidence: the foreign
  server, the user mapping and its role, the imported foreign tables
  (which classed columns reporting can reach, [governance.md](governance.md)),
  pushdown in `EXPLAIN VERBOSE`. Cost: `load-data` must set the user
  mapping's password from the source role's secret, a new step.
- **A two-connection job in the runner.** The runner reads with one
  connection and writes with another. New code in the scheduler (a
  bump), a new repository form, and nothing for the players to audit in
  the databases themselves.

## Time: cadence under real time (O109)

No sped-up clock, no forged history, no time compression (D114, D132);
nobody triggers a job during a game (D131). Proposed:

1. **Each purpose runs at the cadence a real business would give it,
   chosen where that is sub-daily**: transactional mail every few
   minutes, a campaign batch every quarter hour in its sending hours,
   lead extraction hourly, an hourly incremental reporting load. These
   run many times during a four-hour session, so a fix shows within the
   game.
2. **A daily job stays daily** where the business closes a day (the
   reporting close at 01:30). Its fix is verified as D132 says: the
   players move its time. A smoke test does the same (O121).
3. **Weekly and monthly purposes are out of v0.4** (O22): a monthly
   close or a weekly report cannot run inside a game, and moving it
   proves a single run.
4. **Past trace in the restored backup.** The data file is "last night's
   backup" and already computes fifteen days of orders and a daily
   roll-up (`tarnbeck-outdoor-shop/data/db.sql`). The backup may hold a
   purpose's past trace the same way (KPI rows, past mail), computed by
   the data load consistently with its rules, but **a fault's evidence
   never rests on it alone**: every fault's evidence is produced live
   during the aging, and its aging minimum counts from that (D189). This
   is a reading of D114 and D132 for the owner (O109).

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
