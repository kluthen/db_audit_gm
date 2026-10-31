# RevenueCat: cutover to an upgraded Aurora PostgreSQL cluster before ANALYZE had run

- **Source**: [Postmortem for Aurora Postgres Migration, November 23 2022](https://www.revenuecat.com/blog/engineering/postmortem-aurora-postgres-migration) (RevenueCat engineering blog, 2022-12-05, by Guillermo Pérez). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260623075615/https://www.revenuecat.com/blog/engineering/postmortem-aurora-postgres-migration/). Secondary: [EDB commentary](https://www.enterprisedb.com/blog/lets-workshop-an-unplanned-postgres-outage)
- **Date of incident**: 2022-11-23, about 09:39 to 13:07 UTC
- **Organization**: RevenueCat
- **Kind of write-up**: official post-mortem

## Tech stack

- AWS Aurora PostgreSQL 10.x migrated to a new cluster on 14.x (10.x support was ending on 2023-01-31). Database-level replication from old to new cluster (most likely logical replication; the post cites its sequence limitation). PgBouncer between web tier and database.
- Monitoring: CloudWatch, Prometheus/Grafana, New Relic APM.

## Topology

- Old production cluster (10.x) and new cluster (14.x) built from a snapshot and upgraded, then fed by replication. Web tier behind a load balancer, connecting through PgBouncer pools. Writer/reader layout not stated.

## Symptoms

- Statements far slower than normal, database connections exhausted, PgBouncers contended (unclear at first whether the bottleneck was PgBouncer or the database). Dashboard inaccessible, SDK endpoints degraded. New purchases succeeded in app stores but entitlements failed to unlock.

## Diagnosis

- First blamed a cold cache and warmed it; no effect. Set a statement timeout (09:54) and shed 90% of traffic with 503s (09:58).
- Reviewing many `EXPLAIN` plans showed ANALYZE had never run on the new cluster's largest tables; one query used the wrong index and the planner ignored obvious ones.

## Root cause / main culprits

- "ANALYZE was not run on our largest tables" on the new cluster, so the planner had no statistics. The earlier performance comparison had been done on a test cluster that had run long enough for autovacuum to gather stats.
- Contributing: some indexes that misled the planner; New Relic running `EXPLAIN` on every slow query (extra load); Apple webhooks slowing recovery; rollback judged too complex and decided late; sequences not replicated (duplicate primary keys, fixed with a prepared script); integration dispatcher not stopped during cutover (events sent but not recorded); dry runs did not replay write traffic; timing just before Thanksgiving.

## Resolution

- Dropped misused and unneeded indexes, ran ANALYZE on the largest tables, ramped traffic back, paused Apple webhooks, restarted ETLs and other jobs at 13:33 UTC.
- Follow-ups: index review; replay writes in dry runs; more asynchronous processing; per-endpoint load visibility; freeze periods; clearer SDK behaviour in outages; support and comms in incidents.

## Impact and duration

- About 3.5 hours of degraded dashboard and SDK; new-purchase unlocks delayed or failed for about two hours; some integration events not replayable.

## Notes (collector's own, not from the source)

- A very reproducible lab culprit: restore or `pg_upgrade` a database and skip `ANALYZE` (or `vacuumdb --analyze-in-stages`). Players see `last_analyze`/`last_autoanalyze` NULL in `pg_stat_user_tables` and wildly wrong row estimates. The sequence collision after logical replication is a second, independent fault.
