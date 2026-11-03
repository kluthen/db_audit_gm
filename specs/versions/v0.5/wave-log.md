# db_audit_gm v0.5 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

On 2026-11-03 the owner asked for wave 1 to start and for wave 2 to follow
it.

## Wave 1 — started 2026-11-03

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.5-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.5-w1`, cut from `main` at 24f7835
(G1: `v0.5-domains` merged into `main`).

### Gates checked at the start

- G3 (network at image build time), hand check 2026-11-03: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release`, GitHub's s6-overlay and pgwatch releases, and PyPI's
  `fastapi` index answer 200. Cleared for wave 1.
- G4 (Docker host in swarm mode), hand check 2026-11-03: armenelos,
  Docker Engine 29.9.2, swarm active, leader; the VPS `vps-5718ad52`
  (29.9.2) a worker, `Ready`, `Drain`; `tailscale status` shows the VPS
  active, direct. Cleared for wave 1.
- Host resources on 2026-11-03: about 3.9G of memory available, 1.2G of
  swap in use, 9.6G free on `/`. Docker checks stay serialized under the
  host lock.
