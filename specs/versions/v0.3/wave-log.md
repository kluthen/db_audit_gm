# db_audit_gm v0.3 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

## Wave 1 — started 2026-10-23

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.3-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.3-w1`, cut from `main` at 4459c50.

### Gates checked at the start

- G2 (network at build time), hand check 2026-10-23: Debian's trixie
  `Release`, the PostgreSQL apt repository, GitHub's releases and the pinned
  Grafana 13.2.4 tarball answer 200. Cleared for wave 1.
- G3 (Docker host in swarm mode), hand check 2026-10-23: armenelos, Docker
  Engine 29.9.1, swarm active, one node (leader). Cleared for wave 1.
- Host resources on 2026-10-23: about 3G of memory available (5G the day
  before), 10G free on `/`. Docker checks stay serialized under the host lock.

### Owner confirmations, 2026-10-23 (sent to `spec-writer`)

Asked at the wave's start, as spec-writer requested after the plan's merge:

1. In a static scenario (no scheduler node), the fault definitions' own aging
   minima are not counted (bookshop's `pg-join-index-missing` does not hold
   up the hand-over), as in v0.2. **Confirmed.**
2. The G6 test-harness override of the aging minimum also caps each
   instance's own aging minimum, so the two-hour rehearsal can reach its
   hand-over. **Confirmed.**
3. Static games keep the hand-over check and the snapshot, so Prometheus and
   Grafana stop briefly at hand-over on fernway. **Confirmed** (the
   alternative, skipping both in static games, declined).
