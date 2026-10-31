# GoCardless: primary's RAID array dies, Pacemaker refuses to promote the synchronous replica

- **Source**: [Incident review: API and Dashboard outage on 10 October 2017](https://gocardless.com/blog/incident-review-api-and-dashboard-outage-on-10th-october/) (GoCardless blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261007021208/https://gocardless.com/blog/incident-review-api-and-dashboard-outage-on-10th-october)
- **Date of incident**: 2017-10-10, 15:09 to 16:59 (UK time)
- **Organization**: GoCardless
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL (version not stated) with synchronous and asynchronous streaming replication.
- Pacemaker cluster manager on each node, managing Postgres and virtual IPs. PgBouncer appears in the follow-up migration; whether it was in the path during the incident is not stated.

## Topology

- Three nodes: primary, synchronous replica, asynchronous replica; every acknowledged write on at least two nodes.
- Clients reach the primary through a Pacemaker-managed virtual IP. A second "Backup VIP" points backup traffic at a replica.

## Symptoms

- All API and Dashboard requests failed. The primary's disk array had failed and the cluster did not fail over.

## Diagnosis

- The RAID controller lost three disks at once; the kernel remounted the filesystem read-only.
- Pacemaker repeatedly tried to promote a new primary but could not settle where it should run. At about the same time, a Postgres subprocess crashed on the synchronous replica. An invalid WAL file was seen but later ruled out.
- After the incident the team reproduced the failure in Docker containers and isolated the trigger to the Backup VIP's colocation rule.

## Root cause / main culprits

- Hardware failure of the primary, combined with Pacemaker configuration that blocked promotion:
  - non-zero `default-resource-stickiness`;
  - the Backup VIP had a negative-infinity colocation rule against the primary and was running on the synchronous replica, the node that had to become primary.
- Needed two simultaneous failures to show up (primary down and a subprocess crash on the sync replica).

## Resolution

- 15:17 broken primary powered off; an hour of failed attempts to make Pacemaker promote; 16:18 cluster put in maintenance mode, synchronous replica promoted by hand, applications pointed at its IP; 16:59 services confirmed up.
- Follow-ups: data integrity checks (no corruption found); rebuilt third node; reversed the colocation rule ("specifying the colocation rule for the Backup VIP the opposite way round worked just fine"); migrated to a new cluster using PgBouncer and a second VIP without downtime; plan to move from VIPs to application-side proxies, more fault injection, game days without automation.

## Impact and duration

- About 1 hour 50 minutes of total API and Dashboard unavailability; no data loss reported. The post sums it up as turning "an outage that would normally last 1 or 2 minutes to one that lasted almost 2 hours".

## Notes (collector's own, not from the source)

- A small lab can reproduce this without Pacemaker: any HA manager whose constraints silently forbid the only valid promotion target. The player-visible clue is a failover tool that keeps retrying while a healthy, in-sync replica sits idle.
