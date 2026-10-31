# Sentry: PostgreSQL stops accepting writes to prevent transaction ID wraparound

- **Source**: [Transaction ID Wraparound in Postgres](https://blog.sentry.io/transaction-id-wraparound-in-postgres/) (Sentry blog, 2015-07-23). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261001101958/https://blog.sentry.io/transaction-id-wraparound-in-postgres/)
- **Date of incident**: 2015-07-20
- **Organization**: Sentry
- **Kind of write-up**: engineering blog (official incident explanation)

## Tech stack

- PostgreSQL (version not stated; the post links to the 9.3 docs). Autovacuum on defaults for worker count (3), with `autovacuum_freeze_max_age` set high and a vacuum cost delay in place.
- Redis buffers and a queue in front of the database for incoming events.

## Topology

- One primary with replicas. Replicas served a read-only view during the outage. Sentry failed the primary over to newly provisioned hardware while vacuum ran.

## Symptoms

- The database stopped accepting writes; Sentry was down "for most of the US working day". The event backlog in the queue and Redis buffers grew.

## Diagnosis

- PostgreSQL's wraparound protection had triggered while autovacuum was still working through very large tables. Internal statistics showed vacuum had finished on every relation except one. The logs did not explain why autovacuum had not kept up.

## Root cause / main culprits

- Autovacuum did not freeze old rows fast enough for a write-heavy workload on very large tables.
- Contributing settings named in the post: `autovacuum_freeze_max_age` too high, only three autovacuum workers, too much cost delay.
- The risk was known; the team had gone back and forth on autovacuum tuning. PostgreSQL halts because "the database must halt to prevent XID re-use".

## Resolution

- Waited for autovacuum (about three hours), then truncated the one remaining large table (events-to-rollups mapping), accepting the loss of that non-critical data. Writes came back about five minutes later.
- Follow-ups: split relations across several databases; new hardware (256 GB RAM, 24 cores, separate RAID arrays for OS, WAL and data); retuned autovacuum (`autovacuum_freeze_max_age` 500000000, `autovacuum_max_workers` 6, `autovacuum_naptime` 15s, `autovacuum_vacuum_cost_delay` 0, `vacuum_freeze_min_age` 10000000, `maintenance_work_mem` raised, with a later correction that it is capped at 1 GB for these paths).

## Impact and duration

- Most of a US working day without writes. A single-user vacuum on a test machine was still running about 24 hours later.

## Notes (collector's own, not from the source)

- Reaching real wraparound needs about 2 billion transactions, which a small lab will not reach in a game. A lab version would have to lower `autovacuum_freeze_max_age` or burn XIDs on purpose. `pg_database.datfrozenxid` and `age()` are the signals a player would read.
