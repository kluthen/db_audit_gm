# Clerk: a provider minor upgrade makes pooled connections expire in lockstep every 15 minutes

- **Source**: [Database incident postmortem (2025-09-18)](https://clerk.com/blog/2025-09-18-database-incident-postmortem) (Clerk blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261009213448/https://clerk.com/blog/2025-09-18-database-incident-postmortem)
- **Date of incident**: trigger 2025-09-14 about 05:30 UTC (automatic minor upgrade); impact from 2025-09-15 13:08 UTC to the fix on 2025-09-18 03:19 UTC
- **Organization**: Clerk (authentication service)
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL on a managed service (provider not named in the post; version not stated). Application on Google Cloud Run with a connection pool inside each container (pooler not named), maximum connection lifetime 15 minutes.

## Topology

- Many Cloud Run containers, each with its own pool, all connecting to one database. Frontend API (many connections) and Backend API (far fewer) share the pooling logic.

## Symptoms

- Intermittent request failures and latency spikes; after a first fix, database load spikes roughly every 15 minutes. Some legitimate requests got HTTP 429 during traffic shaping. Sign-up/sign-in failed for 3 to 6 minutes during a manual upgrade on 2025-09-17.

## Diagnosis

- Hard because connection metrics were sampled every 60 seconds (hiding seconds-long recycling bursts), a fraudulent sign-up attack produced its own load surges about every 10 minutes, background jobs on 10-, 15- and 30-minute schedules gave false leads, and a release freeze removed the staggering that deploys normally give connection creation.

## Root cause / main culprits

- The upgrade changed how PostgreSQL grants connections: an older O(n^2) behaviour had acted as an informal rate limiter; after the upgrade, batches of connections were granted almost at once.
- With a fixed 15-minute lifetime, connections across all containers began to expire together, and backpressure kept them synchronised: "synchronized connection recycling across all Cloud Run containers creates unmanageable load".
- The provider refused to roll the upgrade back.

## Resolution

- During the incident: query and index optimisation and a full re-index, more aggressive blocking of abusive traffic, a manual minor upgrade and more capacity.
- Fix: jitter on connection lifetime in the pool. Load dropped below pre-incident levels.
- Follow-ups: evaluate providers with more control over upgrades; isolate sign-up/sign-in infrastructure; keep optimising queries; consider tenant isolation and sharding.

## Impact and duration

- About 62 hours of customer-facing impact.

## Notes (collector's own, not from the source)

- Lab culprit: many clients (or several PgBouncer instances) with the same `server_lifetime` / pool max-lifetime and no jitter, so reconnect storms recur on a fixed period. Coarse scrape intervals in Prometheus hiding the burst is itself a plantable monitoring fault.
