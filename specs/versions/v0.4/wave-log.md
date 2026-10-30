# db_audit_gm v0.4 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

The owner gave leave on 2026-10-30 to run all four waves: each gated wave
merges into `main` and the next wave starts from it, without a stop for
the owner between waves unless a gate or a finding needs them.

## Wave 1 — started 2026-10-30

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.4-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.4-w1`, cut from `main` at 51fd02c.

### Gates checked at the start

- G3 (network at image build time), hand check 2026-10-30: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release` and GitHub's s6-overlay releases answer 200. Cleared for
  wave 1.
- G4 (Docker host in swarm mode), hand check 2026-10-30: armenelos,
  Docker Engine 29.9.1, swarm active, leader; the VPS `vps-5718ad52`
  (29.9.2) a worker, `Ready`, `Drain`. Cleared for wave 1.
- Host resources on 2026-10-30: about 4G of memory available, 3G of swap
  in use, 10G free on `/`. Docker checks stay serialized under the host
  lock.
