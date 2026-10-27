# v0.3 — load and capacity

Status: draft v3, consolidated

Consolidated into the [master spec](master-spec.md) and its [access
model](access-model.md) on 2026-10-22; its `(proposed)` items were accepted
as proposed (D146). Kept as v0.3's working record until the milestone is
archived; where it and the master spec differ, the master spec wins.

How much load a v0.3 game runs, what carries it, and how it spreads over
several hosts. Settled: capacity is for the GM and the initiator to
discuss, a game lasts at most four hours, the minimum capacity may rise,
Swarm is the platform, Tailscale links armenelos and the VPS (D122);
always-on hosts (D125); multi-host in v0.3 (D128); load control (D131);
`max_connections` (D138). Figures are (proposed) until measured.

## Calibrating the load

Load is calibrated against the nerfed databases: enough to show
symptoms, never enough to saturate the host
([platform.md](../../platform.md), "Resources and nerfing").

- **Slowness** comes from the cgroup limits (CPU, memory), the memory
  settings (`shared_buffers`, `work_mem`) and the intensity. That is where
  a "the system is slow" scenario is tuned.
- **Connection exhaustion** gives errors, not slowness: past
  `max_connections`, PostgreSQL refuses new sessions with `FATAL: sorry,
  too many clients already`. A scenario wanting that sets a low
  `max_connections` in its seed and a consumer that holds or leaks
  connections.
- The intensity is the scenario's and absolute, like its resource limits
  (D32): a different playground never rescales it (proposed;
  [scheduler.md](scheduler.md)).
- Over two days, rows accumulate: a producer inserting one row a second
  adds about 170,000 rows. Rates are chosen so tables stay small
  ([concept.md](../../concept.md), "Out of scope": large volumes).

### `max_connections` (D138)

The `postgres` brick's default stays 100; a scenario that wants a
bottleneck sets a low value in its seed, within the brick's 10–200
envelope (`bricks/postgres/brick.yaml`). A low default would make every
game exhaust connections whether its story wants it or not. Producers
and consumers connect as ordinary roles, so
`superuser_reserved_connections` (3 by default) still let the `dba` role
and the GM's checks in, and the GM has a reserve of its own (D144;
[checks-under-load.md](checks-under-load.md)).

## Load control (D131)

With no events outside the schedule (D117), nobody pauses, speeds up or
triggers the load during a game: not the GM, not the players, not even
for the final checks. The players' one lever is moving a fixed-time
operation (D116), with no "run now"; it moves a job, never adds traffic.

## Hosts (D125)

v0.3 games run on always-on hosts: the hosts must stay up from
deployment through two days of aging to the end of the game. Classroom
swarms of student laptops wait for a later version (O22).

## Several hosts (D128)

Multi-host is in v0.3, tested with armenelos and the VPS over Tailscale.
The default game stays single-host while its load fits one host.

What the code already has, and what it lacks (read at 824e1d5):

- The scenario format already places every node on a declared host:
  `designed_for.placement`, checked by `tools/gm/model.py`
  (`_check_designed_for`), which also sums each host's placed nodes
  against that host's capacity.
- The renderer pins every service to the manager
  (`PLACEMENT_CONSTRAINT = "node.role == manager"` in
  `tools/gm/localimpl.py`, "single host in v0.1"), and `fit` checks one
  host.
- Images are tagged `127.0.0.1:5000/dbagm/...` but built locally; no
  registry runs. The cross-host `127.0.0.1:5000` pattern (a registry
  service published on the routing mesh, so every host's loopback
  reaches it) is unverified (O10), to verify in this build.

To build:

- per-node placement in the local implementation, rendered as hostname
  or label constraints; stateful nodes pinned with their volumes;
- a registry every host reaches, and the images pushed to it before
  deploy;
- `fit` per host: each host's limits, reservations and disk against its
  placed nodes, each host's images counted once on that host;
- per-host SSH Docker contexts for the exec verb (D27), already in the
  platform's design.

Risks to check on the Tailscale pair (D128):

- the overlay's VXLAN over Tailscale's 1280-byte MTU: the overlay
  network's MTU must leave room for both encapsulations (settled: option
  1230, 1180 inside a node, master spec 10.2, D184);
- Swarm advertising the Tailscale addresses, not the public ones;
- **the routing mesh opens every published port on every host**: the
  bastion's SSH and web front would listen on the VPS's public address.
  The bastion publishes in host mode on its own pinned host, or the VPS
  firewalls the ports (proposed: host mode, which needs no host
  configuration; [platform.md](../../platform.md), "Constraints and
  pitfalls").

## The hosts at hand

- **armenelos**: 11 GB of memory, about 5.4 GB available on 2026-10-22.
  v0.2's `fernway-clinics-monitoring` was sized for 2 CPU / 4G / 8G.
- **the VPS** (`ssh vps`), on the same tailnet: capacity declared at
  setup.

v0.3 adds to a v0.2-sized game: two or three scheduler nodes (about 128M
each), PgBouncer (small, [pgbouncer.md](pgbouncer.md)), and a busier
database. A single-host v0.3 game is expected to fit in about 5G (to
measure). Two days of aging occupy the host the whole time.

## Footprint to measure

As v0.2 did (D82): the v0.3 scenario's footprint measured on a running
game, plus its volumes' growth over the full aged run of the release
gate (D135) and a four-hour game (logs, WAL, TSDB, tables), and the
hand-over snapshot's size, declared in the bricks' footprints and counted
by `fit` ([aging-and-timeline.md](aging-and-timeline.md), "Disk over
the aging").

## Open points

O10 (registry pattern, to verify in the build).
