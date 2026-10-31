# Stripe: a database shard cannot elect a primary after an upgrade, then a rollback starves CPU

- **Source**: [Significantly elevated error rates on 2019-07-10](https://stripe.com/rcas/2019-07-10) (Stripe RCA, 2019-07-12, by David Singleton, CTO). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260515104051/https://stripe.com/rcas/2019-07-10)
- **Date of incident**: 2019-07-10, 16:35 to 17:02 UTC and 21:14 to 22:47 UTC
- **Organization**: Stripe
- **Kind of write-up**: official post-mortem (root cause analysis)

## Tech stack

- The database product and version are not named. The cluster had been upgraded to a newer minor version about three months earlier; election-based primary failover.

## Topology

- Data split by kind into clusters and by volume into shards; each shard has several redundant nodes, and a failed primary is replaced by election. Many applications, including the API, depended on the affected shard.

## Symptoms

- Writes to one shard timed out; the shard had no primary. The API ran short of compute and "a substantial majority of API requests" failed in both windows.

## Diagnosis

- Window 1: several nodes had stalled four days earlier; they stopped reporting replication lag but still passed active health checks. With multiple stalled nodes, a fault in the upgraded version's failover logic prevented any election.
- Window 2: the team assumed a repeat and reused the first playbook. The actual cause was the rolled-back election protocol interacting badly with a recently added configuration setting, causing CPU starvation.

## Root cause / main culprits

- Two previously unseen failure modes: a latent election bug in the new minor version that only fires when several nodes are stalled, then a rollback that conflicted with a recent configuration change.
- Contributing: health checks that missed stalled nodes; one heavily shared shard; client retries; no safe tooling for configuration changes during an incident.

## Resolution

- Window 1: restarted the cluster's nodes, forcing a successful election (17:00 UTC).
- Window 2: rolled the election protocol back across the cluster, fixed the configuration, restarted nodes (22:34 UTC), ramped traffic back (22:47 UTC).
- Follow-ups: alert on nodes that stop reporting replication lag and on shard states that could trigger the fault; work with the database maintainers on a fix; more circuit breaking and retry limits; safer incident-time configuration tooling.

## Impact and duration

- About 27 minutes plus about 93 minutes of severe API degradation.

## Notes (collector's own, not from the source)

- The engine is not named, so the transferable culprit is generic: a replica that is "healthy" to the liveness check but no longer replicating. In PostgreSQL terms, a standby whose `pg_stat_replication` lag stops updating while it still answers `SELECT 1`.
