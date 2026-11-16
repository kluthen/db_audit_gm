# db_audit_gm v0.6 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

On 2026-11-16 the owner approved build plan v2 (spec D518: "i aprove the
plan"), with κ = 2; the reference archived outside git (D519: "i don't
want to keep the archive in the git, but it can go there"); and `fa-real`
torn down once its usefulness is spent (D520: "you may stop the real
aging game once its usefullness is spent"), which the plan places after
chunk 1 has merged and its archive verifies (G12).

## Wave 1 — started 2026-11-16

Chunks 1, 2, 3, 4, 8 (κ = 2). Branch `v0.6-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.6-w1`, cut from `main` at 819baab
(G1: `v0.6-spec` merged into `main`, spec D518).

### Gates checked at the start

- G1: done (2026-11-16, spec D518); `v0.6-spec` merged into `main` as
  819baab.
- G3 (network at image build time), hand check 2026-11-16: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release`, GitHub's s6-overlay, Prometheus, `postgres_exporter` and
  pgwatch releases answer 200; Grafana's pinned download
  (`grafana_13.3.1_42849527790_linux_amd64.tar.gz`) answers 200. Cleared
  for wave 1.
- G4 (Docker host in swarm mode), hand check 2026-11-16: armenelos swarm
  active, manager, leader; the VPS `vps-5718ad52` a worker, `Ready`,
  `Drain`. Images are tagged `127.0.0.1:5000/dbagm/...` locally; no
  registry runs (none needed on one host). Cleared for wave 1.
- Host on 2026-11-16: `/home` 88 % used, 16G free. `fa-real`
  (`tarnbeck-outdoor-shop-z8415w`, 8 services) still deployed, to go at
  G12.
