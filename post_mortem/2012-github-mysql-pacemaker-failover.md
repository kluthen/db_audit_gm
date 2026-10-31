# GitHub: a schema migration trips automated MySQL failover, then a Pacemaker split-brain

- **Source**: [GitHub availability this week](https://github.blog/2012-09-14-github-availability-this-week/) (GitHub blog, 2012-09-14, by Jesse Newland). Archive: [web.archive.org snapshot](https://web.archive.org/web/20240624110206/https://github.blog/2012-09-14-github-availability-this-week/)
- **Date of incident**: 2012-09-10 and 2012-09-11
- **Organization**: GitHub
- **Kind of write-up**: official post-mortem

## Tech stack

- MySQL (InnoDB; version not stated). Pacemaker and Heartbeat with Percona Replication Manager as the resource agent; two virtual IPs (read/write and read-only). The status site ran on Heroku with a shared development database add-on.

## Topology

- Three-node MySQL cluster (replacing a DRBD-backed pair in August 2012). MySQL runs on all nodes; failover moves the VIP and flips `read_only`. One active (primary) and standby replicas.

## Symptoms

- 2012-09-10: unwanted failovers back and forth and degraded performance.
- 2012-09-11: a developer saw wrong query results from the standby; later the whole site went down. Some dashboard events showed on the wrong users' dashboards; some repositories were misrouted.

## Diagnosis

- A two-pass zero-downtime schema migration loaded the primary more than ever before; health checks failed and the active role moved to a node with a cold InnoDB buffer pool, which also failed its checks, so the role moved back. The engineer put Pacemaker in maintenance mode.
- Maintenance mode had stopped the standby from re-pointing to the new primary, hence the wrong results. Leaving maintenance mode triggered a Pacemaker segfault that partitioned the cluster; two uncoordinated elections ran and an out-of-date node was elected primary.

## Root cause / main culprits

- Automated failover driven by health checks that read migration load as a dead primary.
- Cold buffer pools on failover targets.
- A cluster-manager crash leading to split-brain despite a quorum setting.
- Replication not reconfigured while automation was paused, leaving a replica on the old primary.

## Resolution

- Stopped Pacemaker and Heartbeat on the two remaining nodes, restarted them, started MySQL on node "a" as primary; the out-of-date node had been powered off. Divergent records cleaned up; misdelivered events removed; owners of exposed private repositories contacted.
- Follow-ups: failover of the active role only when a human starts it; investigate warming replica buffer pools; audit of the Pacemaker/Heartbeat stack; hardware testing of the server that segfaulted. Status site moved to a production-grade database with a replica.

## Impact and duration

- 1 hour 46 minutes of downtime over two outages plus about an hour of degraded performance. Sixteen private repositories were reachable by non-collaborators for seven minutes (08:19 to 08:26 PDT on 2012-09-11). Redis records keyed on MySQL IDs no longer matched after the divergence.

## Notes (collector's own, not from the source)

- Two small-lab culprits: a health check that cannot tell "busy" from "dead", and a status page whose many workers exhaust the connections of a tiny database (same shape as `max_connections` exhaustion behind a pooler-less app).
- The privacy side effect (cross-user data shown after divergence) is a useful end-of-game handout point.
