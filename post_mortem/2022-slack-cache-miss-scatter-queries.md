# Slack: cache nodes restart during a Consul upgrade, cache misses become scatter queries on Vitess

- **Source**: [Slack's Incident on 2-22-22](https://slack.engineering/slacks-incident-on-2-22-22/) (Slack Engineering blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260419061213/https://slack.engineering/slacks-incident-on-2-22-22/)
- **Date of incident**: 2022-02-22, from just after 06:00 Pacific; restored gradually during the day
- **Organization**: Slack
- **Kind of write-up**: engineering blog (official incident review)

## Tech stack

- MySQL behind Vitess (sharding layer). Memcached with Mcrouter; Mcrib control plane builds Mcrouter configs from Consul service discovery.

## Topology

- Web app reads from memcached through Mcrouter; on a miss it reads Vitess and writes the result back. The affected keyspace (channel membership) is sharded by user.

## Symptoms

- Many users could not connect; client boots slow or failing with error pages. Sharp rise in load on the channel-membership keyspace.

## Diagnosis

- A percentage-based Consul agent upgrade restarted agents, which removed cache nodes from the catalog. Mcrib replaced each with an empty spare and flushed nodes that came back, so the hit rate fell.
- The boot path fetched group DM membership, cached by channel ID but stored in a table sharded by user: a miss meant a scatter query to every shard. Database read load grew faster than the miss rate; most scatter queries timed out, so the cache could not refill; client retries added load.

## Root cause / main culprits

- Trigger: Consul agent restarts during an upgrade.
- Amplifier: an expensive scatter query hidden behind a cache, run on every miss.
- Mcrib repairing configurations quickly increased cache churn ("Mcrib is objectively a better system for generating memcached configurations", yet it made this incident worse).
- Retries under overload; the system stayed in a cascading-failure state.

## Resolution

- Paused the Consul rollout; throttled client boots (first increase overshot, then smaller steps); changed the query to read only missing data from the channel-sharded table and allowed it to read from replicas; restored boot rates once caches warmed.
- Follow-ups: new Consul rollout process, Mcrib control-loop changes, review of other cache-fronted scatter queries, cache tier resilience work.

## Impact and duration

- Many users unable to connect for much of the day; no quantified figures.

## Notes (collector's own, not from the source)

- Transfers directly to PostgreSQL: a report or dashboard query that is cheap only because a cache sits in front of it. Flush the cache in a lab (restart Redis/memcached) and the database sees the full cost at once.
