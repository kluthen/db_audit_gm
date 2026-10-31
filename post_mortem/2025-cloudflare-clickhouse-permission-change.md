# Cloudflare: a database permission change doubles a metadata query's rows and crashes the proxy

- **Source**: [Cloudflare outage on November 18, 2025](https://blog.cloudflare.com/18-november-2025-outage/) (Cloudflare blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261021212626/https://blog.cloudflare.com/18-november-2025-outage)
- **Date of incident**: 2025-11-18, about 11:20 to 17:06 UTC
- **Organization**: Cloudflare
- **Kind of write-up**: official post-mortem

## Tech stack

- ClickHouse cluster (version not stated), many shards; `Distributed` tables in database `default` reading underlying tables in database `r0` on each shard.
- A scheduled generator (every five minutes) builds the Bot Management "feature file" from a query on `system.columns` and pushes it to the edge proxy (FL2, written in Rust; older FL proxy also in use).

## Topology

- Feature file generated centrally from the ClickHouse cluster and propagated across the whole network. The permission change was rolled out node by node, so only part of the cluster had it at first.

## Symptoms

- Spikes of HTTP 5xx across the network that came and went, then stayed. FL2 customers saw 5xx; customers on the older FL proxy saw every request get a bot score of zero.
- Knock-on failures: Turnstile, Workers KV, Dashboard logins, Access authentication, parts of Email Security. Latency up as debugging/observability systems burned CPU on uncaught errors.

## Diagnosis

- First suspected a very large DDoS attack; the independently hosted status page going down at the same time (a coincidence) reinforced that. The post states the outage was "not caused, directly or indirectly, by a cyber attack or malicious activity of any kind."
- The flapping came from the five-minute generator hitting either an updated or a not-yet-updated ClickHouse node. The Bot Management configuration file was identified as the trigger at about 13:37.

## Root cause / main culprits

- At 11:05 UTC an access-control change made users' implicit access to `r0` tables explicit, so their metadata became visible.
- The feature-file query read `system.columns` without filtering on the database name; after the change it returned the columns from both `default` and `r0`, more than doubling the rows.
- The proxy module preallocates for at most 200 features (about 60 in use); the oversized file hit the limit and the Rust code's `unwrap()` on the error panicked.
- Contributing: generated configuration trusted like internal code rather than validated like user input; no global kill switch for that feature.

## Resolution

- Bypasses for Workers KV and Access (13:05); stopped generating and propagating new files (14:24); deployed a known-good file globally and restarted the core proxy (14:30); all services back at 17:06 after working through login backlogs.
- Follow-ups: validate Cloudflare-generated configuration files like user input; more global kill switches; stop core dumps and error reports from exhausting resources; review failure modes of all proxy modules.

## Impact and duration

- About 5 h 46 min. Cloudflare calls it its worst outage since 2019.

## Notes (collector's own, not from the source)

- A clean data-governance-meets-reliability culprit: a grants change that is "safe" for access control silently changes what a catalog/metadata query returns. In PostgreSQL the same shape is a query on `information_schema.columns` without a `table_schema` filter, run by a role that just gained `USAGE` on another schema.
