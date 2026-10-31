# Joyent Manta: anti-wraparound autovacuum plus a DROP TRIGGER freezes one metadata shard

- **Source**: Postmortem for July 27 outage of the Manta service (Joyent blog, 2015-08-03). The original URL <https://www.joyent.com/blog/manta-postmortem-7-27-2015> now returns **404** (flagged); the text was read from the archive: [web.archive.org snapshot](https://web.archive.org/web/20220528044329/https://www.joyent.com/blog/manta-postmortem-7-27-2015)
- **Date of incident**: 2015-07-27, about 10:30 to 20:45 UTC
- **Organization**: Joyent (Manta object storage)
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL (version not stated) as Manta's metadata tier,, on ZFS. Manatee manages automatic failover.
- Autovacuum with the default freeze thresholds; cost-based vacuum delay active.

## Topology

- Metadata tier sharded across several PostgreSQL databases. Each shard is a three-node cluster with synchronous replication, managed by Manatee.
- Every Manta request (objects, directories, jobs) touches the metadata tier. Only one shard was affected.

## Symptoms

- High latency and HTTP 500s on about 22% of all requests (peak near 27%, mostly 19 to 23%), for PUT, GET and DELETE alike.
- On the affected shard, simple queries worked but every query on the main metadata table was "waiting"; the only running one was an autovacuum "to prevent wraparound".

## Diagnosis

- Restarting PostgreSQL helped for 5 to 10 minutes, until a new anti-wraparound autovacuum started and the pile-up came back. Lock state and running queries were saved before the restart.
- `prstat -Lm` and DTrace showed the autovacuum mostly off-CPU reading files (ZFS does not prefetch files not yet read) and then sleeping in the cost-based vacuum delay.
- Afterwards, a program summarising the saved lock dependencies showed the real chain: autovacuum held a shared lock; a `DROP TRIGGER` waited for an exclusive table lock; every later query queued behind the `DROP TRIGGER`. The oldest active query during the outage was that `DROP TRIGGER`.

## Root cause / main culprits

- A three-way lock interaction: data-path queries wanting shared locks, a long-running anti-wraparound autovacuum holding a shared lock (it does not back off under lock contention, unlike a normal autovacuum), and a component that idempotently drops and recreates a trigger on reconnect, which asks for an exclusive table lock.
- Contributing: the table and its indexes did not fit in memory, so the vacuum was I/O-bound; cost delay slowed it further. The team had not met anti-wraparound vacuums before and believed they were out of its control.
- The post also lists earlier, smaller incidents from too little autovacuuming: bloat, fragmentation, and "vastly distorted query planner statistics" causing table scans.

## Resolution

- During the incident: manual file prefetch and a live patch of the running process to skip the vacuum sleep; when the vacuum finished, another one started on the same table. Final fix around 20:40 UTC: raised the threshold that triggers the anti-wraparound autovacuum.
- Follow-ups: stop dropping and recreating the trigger; run a manual `VACUUM FREEZE` on all shards; monitor the statistics behind the wraparound trigger and that normal autovacuums complete; validate tunables under load in pre-production. Why the first completed vacuum did not clear the condition was still unexplained.

## Impact and duration

- About 10 hours 15 minutes of partial errors (22% of requests on average).

## Notes (collector's own, not from the source)

- Good lab material because the visible symptom (autovacuum is the only running query) points at the wrong culprit. The real cause is the lock queue: `pg_locks` / `pg_blocking_pids()` show the waiting `DROP TRIGGER` at the head. Any long-held lock plus a DDL waiting on it reproduces the pile-up without needing actual wraparound.
