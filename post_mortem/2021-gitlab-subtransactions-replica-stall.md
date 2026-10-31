# GitLab.com: SAVEPOINT subtransactions plus a long transaction stall every read replica

- **Source**: [Why we spent the last month eliminating PostgreSQL subtransactions](https://about.gitlab.com/blog/2021/09/29/why-we-spent-the-last-month-eliminating-postgresql-subtransactions/) (GitLab blog, 2021-09-29). Archive: [web.archive.org snapshot](https://web.archive.org/web/20250604221600/https://about.gitlab.com/blog/2021/09/29/why-we-spent-the-last-month-eliminating-postgresql-subtransactions/)
- **Date of incident**: first incident on June 24 (2021 implied, the body does not state the year), recurring over the following weeks
- **Organization**: GitLab (GitLab.com)
- **Kind of write-up**: engineering blog (incident investigation)

## Tech stack

- PostgreSQL (version not stated; the post notes that PostgreSQL 13 renamed `SubtransControlLock` to `SubtransSLRU`). Ruby on Rails with ActiveRecord.
- Prometheus metrics; Marginalia comments on SQL for request tracing.

## Topology

- One primary and several read replicas. Replicas were affected, the primary was not. Pooler and load-balancing details not stated.

## Symptoms

- Minutes-long stalls with HTTP 500s; high error rate on the CI/CD runner endpoint (`POST /api/v4/jobs/request`) and a fast-growing backlog of unprocessed builds. Unrelated queries also timed out across the cluster.
- Queries waiting on LWLocks, specifically `SubtransControlLock` / `SubtransSLRU`. Stalls sometimes vanished for days and returned for about 15 minutes.

## Diagnosis

- Extended sampling of `pg_stat_activity` wait events and aggregated LWLock monitoring.
- Prometheus counts of subtransactions per model; application instrumentation logging transactions with more than 32 `SAVEPOINT`s, with backtraces.
- Outside help: an analysis of "suboverflow" with `perf` output (Laurenz Albe) and reproduction benchmarks including replicas and long-running transactions (Nikolay Samokhvalov). In tests, replica TPS dropped from about 360,000 to 50,000 and recovered when the long transaction ended.

## Root cause / main culprits

- Rails code opening subtransactions (`SAVEPOINT`, e.g. `requires_new: true` around `find_or_create_by`), combined with a long-running transaction on the primary.
- On replicas, snapshots became "suboverflowed", lookups spilled past the small `pg_subtrans` SLRU cache, causing cache misses, I/O and LWLock contention on every query.

## Resolution

- Removed every `SAVEPOINT` from the application: updates outside subtransactions, `INSERT ... ON CONFLICT`, or accepting non-atomic `find_or_create_by` in a few places.
- Rejected running a patched PostgreSQL with a larger SLRU (maintenance cost, no benefit for self-managed users). Long-running transactions were not eliminated (judged impractical); partitioning and sharding continue.
- Follow-up: alert on any `SAVEPOINT` use. "Since removing all `SAVEPOINT` queries, we have not seen Nessie rear her head again."

## Impact and duration

- Repeated stalls of minutes over several weeks; no quantified user impact given.

## Notes (collector's own, not from the source)

- Reproducible in a lab with one primary, one hot-standby replica, a session holding an open transaction on the primary, and a write load that uses savepoints. The tell-tale signal is `wait_event = 'SubtransSLRU'` (or `SubtransControlLock` before PG 13) on the replica only.
