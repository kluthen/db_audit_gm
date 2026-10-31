# Cloudflare: a half-failed switch splits etcd, automatic database promotion forces full replica rebuilds

- **Source**: [A Byzantine failure in the real world](https://blog.cloudflare.com/a-byzantine-failure-in-the-real-world/) (Cloudflare blog, 2020-11-27). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260521232901/https://blog.cloudflare.com/a-byzantine-failure-in-the-real-world/)
- **Date of incident**: 2020-11-02, 14:43 to about 21:20 UTC
- **Organization**: Cloudflare (control plane: API and dashboard)
- **Kind of write-up**: official post-mortem (engineering blog)

## Tech stack

- "Relational databases" (the post does not name the engine or version) managed by a cluster-management system that uses a three-node etcd cluster for discovery and coordination.
- Redis for user sessions, with database writes at login.

## Topology

- Control plane redundant across two regions; databases writable in one region at a time.
- Each database cluster: primary, synchronous replica, one or more asynchronous replicas; plus a secondary cluster in another data center for disaster recovery.
- Racks with paired switches. One database cluster ("Cluster B") serves authentication for API and dashboard traffic, and one of its replicas absorbed a large share of reads.

## Symptoms

- API success rate dropping periodically to as low as 75%; dashboard up to 80 times slower. The edge network was not affected.

## Diagnosis

- A switch stopped answering pings but kept LACP and BGP up while vPC failed and some data-plane packets were dropped; attached servers saw only partial loss. It recovered by itself after six minutes.
- etcd node 1 could reach node 2 but not node 3 (the leader). Node 1 kept calling elections, elections tied, and etcd stayed read-only while the switch was degraded.
- Two database clusters lost contact with a healthy primary; automation promoted a synchronous replica in each, without data loss.

## Root cause / main culprits

- A partial, inconsistent network failure that Raft does not model ("This caused cluster members to have conflicting views of reality").
- A defect in the cluster manager: after any promotion, all replicas had to be rebuilt, which takes time proportional to database size.
- Read load concentrated on one replica of the authentication cluster; with no replica left, the new primary was overloaded.
- Auto-promotion tuned for speed; for at least one database the post concludes "the cure may be worse than the disease".

## Resolution

- Shed load (fewer certificate pushes, e-mail, background jobs); manually steered API reads to replicas in the secondary region; moved authentication back to the primary region; rebuilt replicas (first one back at 21:20 UTC).
- Follow-ups: fix the rebuild-after-promotion defect; cross-region user sessions; automate steering reads to secondary-region replicas; revisit auto-remediation and promotion timing.

## Impact and duration

- 6 hours 33 minutes of degraded API and dashboard.

## Notes (collector's own, not from the source)

- Two lab-sized culprits: an HA manager that fails over on a transient partition, and a read path that depends on one replica with no headroom on the primary. The second is easy to plant (route all reporting reads to one replica, then take it away).
