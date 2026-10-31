# GitHub: 43-second network partition, cross-region MySQL promotion, 24 hours of degraded service

- **Source**: [October 21 post-incident analysis](https://github.blog/2018-10-30-oct21-post-incident-analysis/) (GitHub blog, 2018-10-30). Archive: [web.archive.org snapshot](https://web.archive.org/web/20240526124618/https://github.blog/2018-10-30-oct21-post-incident-analysis/)
- **Date of incident**: 2018-10-21 22:52 UTC to 2018-10-22 23:03 UTC
- **Organization**: GitHub
- **Kind of write-up**: official post-mortem

## Tech stack

- MySQL clusters (version not stated) with asynchronous replication. Orchestrator manages topology and automated failover, using Raft for consensus.
- Backups stored off-site (public cloud); webhooks and GitHub Pages builds as asynchronous job queues.

## Topology

- MySQL primaries in the US East Coast data center; replicas in a US West Coast data center and in East Coast public-cloud capacity. Applications write to each cluster's primary and send most reads to replicas.

## Symptoms

- After a 43-second loss of connectivity between the East Coast network hub and the primary East Coast data center, Orchestrator had promoted West Coast primaries. The application tier started writing to them as soon as connectivity returned.
- Monitoring raised many faults; topology queries showed only West Coast servers. Users saw stale and inconsistent data; webhooks and Pages builds were delayed.

## Diagnosis

- Engineers found that the East Coast primaries held a few seconds of writes not replicated to the West Coast, while the West Coast primaries had since taken new writes: the two sites had diverged, so a simple fail-back would lose data.

## Root cause / main culprits

- Routine replacement of failing 100G optical equipment cut the link for 43 seconds.
- Orchestrator, with quorum among West Coast and cloud nodes, promoted primaries across regions. The application tier was not built for cross-country write latency.
- Divergent writes on both sides; no previous partition of this size had exercised this path.

## Resolution

- Chose to fail forward to protect data: paused webhooks and Pages builds, rebuilt East Coast replicas from backups (transfer, decompress, checksum, load took hours), restored East Coast primaries around 11:12 UTC, failed back to the original topology at 16:24 UTC.
- Backlog of more than five million hook events and about 80,000 Pages builds; about 200,000 webhook payloads expired past an internal TTL before the TTL was raised.
- Binary logs of the divergent writes captured for reconciliation, some needing user outreach.
- Follow-ups: forbid cross-region primary promotion in Orchestrator; richer per-service status reporting; active/active/active data-center design; fault injection and chaos engineering.

## Impact and duration

- 24 hours 11 minutes of degraded service. No user data lost, per the post; a few seconds of writes needed reconciliation.

## Notes (collector's own, not from the source)

- The lab-sized version is a primary and a replica with an automatic failover tool and a short network cut: the interesting fault is the split history, not the outage. With PostgreSQL this is the classic "old primary has WAL the new one never saw" case (`pg_rewind` territory).
