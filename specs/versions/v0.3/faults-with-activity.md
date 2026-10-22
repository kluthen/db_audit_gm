# v0.3 — faults that need activity, and difficulty

Status: draft v3

The fault families a running load makes possible, the faults the
scheduler and PgBouncer bring, what difficulty means, and v0.3's
scenario. Settled: difficulty (D120, D134), one new normal scenario and
six to eight new catalog faults (D134). Which faults, and the scenario's
make-up, are (proposed) until the owner reviews this draft. Checks under
load: [checks-under-load.md](checks-under-load.md).

## Difficulty (D120, D134)

Each fault is worth 1. An easy game scores 5, a normal one 10, a hard one
20, and so on. A scoring system for the players is post-v1.0: research
on scoring methods is allowed, and one is added before then only if it is
quick to implement (not researched).

- A scenario's difficulty score is its number of fault instances; silent
  tooling expectations (D76) are not faults and do not count (D134).
- The named levels are targets for the GM designing from a brief ("a
  normal game"), not exact counts: `bookshop-new-server` scores 6 and
  `fernway-clinics-monitoring` 8 (D134).
- The scenario records its score and the loader checks it against the
  count of its fault instances (proposed; [format-changes.md](format-changes.md)).

## v0.3's scenario (D134)

One new scenario at normal difficulty: ten fault instances, with
producers, consumers, monitoring and PgBouncer. Proposed make-up:

- **Topology**: the bastion; one `postgres` database; PgBouncer in front
  of it; two scheduler nodes, a producer (orders, ingestion, a nightly
  batch) and a consumer (BI and reporting queries, an export job); the
  v0.2 monitoring bricks (Prometheus, `postgres_exporter`, Grafana).
  Single-host, on armenelos; also deployed once across armenelos and the
  VPS to test multi-host (D128).
- **Faults**: six or seven of the new catalog faults below, plus three
  or four existing ones that gain evidence under load
  (`pg-join-index-missing`, `pg-table-autovacuum-off`, one monitoring
  fault), at least one of them planted during the aging (D127).
- **Write policies**: the database and PgBouncer fixable; the scheduler
  nodes report-only, with the producer's repository and both
  `jobs.yaml` files fixable (D130); the monitoring nodes one fixable,
  one report-only, now that report-only monitoring nodes exist (D108,
  D140).

## Families that need activity

From the v0.3 page (D47) and [bricks-and-faults.md](../../bricks-and-faults.md):

| Family | Needs |
|---|---|
| Contention, lock waits | concurrent writers on the same rows; a batch at peak time |
| Bloat growing | an update or delete stream on a table whose vacuuming is off or starved |
| Long transactions | a consumer holding a transaction open; `idle in transaction` sessions |
| Connection exhaustion | a low `max_connections` and a client that leaks or never pools |
| Data flow | duplicates, dropped records, a producer swallowing errors |
| Faulty requests | ill-formatted, misbehaving, ill-targeted queries (D47) |
| Scheduled jobs | a fixed-time operation at the wrong time, in the wrong zone, overlapping, never running |
| Pooling | PgBouncer sized or configured wrong ([pgbouncer.md](pgbouncer.md)) |

Existing catalog faults gain evidence under load:
`pg-join-index-missing` shows in `pg_stat_statements` and pgBadger,
`pg-table-autovacuum-off` grows bloat, `pg-stat-statements-not-preloaded`
hides a real workload, the monitoring faults hide real symptoms.

## Candidate faults

Where each fault lives decides who can fix it: in the query repository
or `jobs.yaml` (fixable when the scenario gives the file that policy,
D116, D130), in the schedule (report or propose only, since players
never change streams), or in a database or PgBouncer node. The eight
marked **v0.3** are the proposed new catalog faults (D134: six to
eight); the others stay candidates.

| Candidate | Lives in | Evidence | Resolutions | |
|---|---|---|---|---|
| A query with a syntax or type error | repository | scheduler log, PostgreSQL log, error counters | report, propose, fix | **v0.3** |
| A query without its `WHERE` (updates every row) | repository | `pg_stat_statements` rows per call, bloat, lock waits | report, propose, fix | **v0.3** |
| A BI query reading far too much (`SELECT *`, no date bound) | repository | temp files, `work_mem` spills, slow-query log | report, propose, fix | **v0.3** |
| Inserts without idempotency, retried: duplicates | repository | duplicate rows | report, propose, fix | **v0.3** |
| A consumer holding transactions open | schedule (hold) | `pg_stat_activity`, `idle in transaction`, vacuum held back | report, propose | **v0.3** |
| A nightly batch at the daily peak | `jobs.yaml` | lock waits and latency at the peak, the job's time | report, propose, fix | **v0.3** |
| A job in the wrong time zone | `jobs.yaml` | the job's run times in the log against the story's time zone | report, propose, fix | **v0.3** |
| PgBouncer pool too small | PgBouncer seed | `SHOW POOLS` waiting clients, latency | report, propose, fix | **v0.3** |
| An N+1 pattern (one query per row of a list) | repository (builder) | calls per minute, pgBadger | report, propose, fix | |
| A producer swallowing errors: dropped records | repository and schedule | row counts against the scheduler's counters, PostgreSQL log | report, propose | |
| A client that never pools (connect per call) | schedule (connection) | connection rate, log of connections | report, propose | |
| Two jobs overlapping | `jobs.yaml` | the scheduler's skipped runs, lock waits | report, propose, fix | |
| A low `max_connections` with a leaking consumer | database seed and schedule | refused sessions | report, propose, fix (the setting) | |
| A client bypassing PgBouncer | schedule (connection target) | connections to 5432 from that node | report, propose | |
| `pool_mode = transaction` with a client relying on session state | PgBouncer seed and repository | errors on `SET`, advisory locks, prepared statements | report, propose, fix | |

Each needs the new format items ([format-changes.md](format-changes.md)):
a fault whose injection changes the repository, `jobs.yaml` or the
schedule, an aging minimum stating how long its evidence takes, and,
for some, a planting moment during the aging (D127).

Every candidate's sealed check judges its cause where it can (D124): the
query's text, the job's time and zone, the pool's size, the
transaction's hold in the schedule. Duplicates and dropped records are
the behavioural ones, judged over a window.

## Open points

None; the format items are in [format-changes.md](format-changes.md), the
`(proposed)` items in [review-list.md](review-list.md).
