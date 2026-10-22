# v0.3 — faults that need activity, and difficulty

Status: draft v1

The fault families a running load makes possible, the faults the
scheduler and PgBouncer bring, and what difficulty means (D120).
Candidate faults are (proposed); none is chosen yet. Checks under load:
[checks-under-load.md](checks-under-load.md).

## Difficulty (D120)

Each fault is worth 1. An easy game scores 5, a normal one 10, a hard one
20, and so on. A scoring system for the players is post-v1.0: research
on scoring methods is allowed, and one is added before then only if it is
quick to implement.

Proposed reading, to confirm (O91):

- a scenario's difficulty score is its number of fault instances;
  silent tooling expectations (D76) are not faults and do not count;
- the named levels are targets for the GM designing from a brief ("a
  normal game"), not exact counts a scenario must hit: the existing
  scenarios score 6 (`bookshop-new-server`) and 8
  (`fernway-clinics-monitoring`);
- the scenario records its score; the loader counts it.

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

## Candidate faults (proposed)

Where each fault lives decides who can fix it: in the query repository
or `jobs.yaml` (fixable when the scenario allows, D116), in the schedule
(report or propose only, since players never change streams), or in a
database or PgBouncer node.

| Candidate | Lives in | Evidence | Resolutions |
|---|---|---|---|
| A query with a syntax or type error | repository | scheduler log, PostgreSQL log, error counters | report, propose, fix |
| A query without its `WHERE` (updates every row) | repository | `pg_stat_statements` rows per call, bloat, lock waits | report, propose, fix |
| An N+1 pattern (one query per row of a list) | repository (builder) | calls per minute, pgBadger | report, propose, fix |
| A BI query reading far too much (`SELECT *`, no date bound) | repository | temp files, `work_mem` spills, slow-query log | report, propose, fix |
| Inserts without idempotency, retried: duplicates | repository | duplicate rows | report, propose, fix |
| A producer swallowing errors: dropped records | repository and schedule | row counts against the scheduler's counters, PostgreSQL log | report, propose |
| A consumer holding transactions open | schedule (hold) | `pg_stat_activity`, `idle in transaction`, vacuum held back | report, propose |
| A client that never pools (connect per call) | schedule (connection) | connection rate, log of connections | report, propose |
| A nightly batch at the daily peak | `jobs.yaml` | lock waits and latency at the peak, the job's time | report, propose, fix |
| A job in the wrong time zone | `jobs.yaml` | the job's run times in the log | report, propose, fix |
| Two jobs overlapping | `jobs.yaml` | the scheduler's skipped runs, lock waits | report, propose, fix |
| A low `max_connections` with a leaking consumer | database seed and schedule | refused sessions | report, propose, fix (the setting) |
| PgBouncer pool too small | PgBouncer seed | `SHOW POOLS` waiting clients, latency | report, propose, fix |
| A client bypassing PgBouncer | schedule (connection target) | connections to 5432 from that node | report, propose |

Each needs the new format items: a fault whose injection is a change to
the repository, to `jobs.yaml` or to the schedule (a seed change, as in
D92's parameter kind), and an aging minimum stating how long its
evidence takes. Which faults v0.3 ships, and how many: O91.

## Open points

O91 (scenarios, fault count, difficulty reading), O82 (judging them under
load), O85 (faults that start during aging).
