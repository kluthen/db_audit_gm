# v0.3 — load and capacity

Status: draft v1

How much load a v0.3 game runs, what carries it, and when it spreads
over several hosts. Settled: capacity is for the GM and the initiator to
discuss, a game lasts at most four hours, the minimum capacity may rise,
Swarm is the platform, and Tailscale links armenelos and the VPS (D122).
Everything else is (proposed).

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
  (D32): a different playground never rescales it ([scheduler.md](scheduler.md)).
- Over two days, rows accumulate: a producer inserting one row a second
  adds about 170,000 rows. Rates are chosen so tables stay small
  ([concept.md](../../concept.md), "Out of scope": large volumes).

### `max_connections` (driver's proposal; O95)

The owner asked whether lowering the brick's default from 100 to about 20
helps simulate bottlenecks. Proposal: keep the brick default at 100 and
let scenarios set low values; the brick's envelope already allows 10 to
200 (`bricks/postgres/brick.yaml`). A low default would make every game
exhaust connections whether its story wants it or not, and exhaustion
shows as refused sessions rather than slowness. With a low value the
`superuser_reserved_connections` (3 by default) still let the `dba` role
and the GM's checks in, provided producers and consumers connect as
ordinary roles ([checks-under-load.md](checks-under-load.md)).

## Load control

With no events outside the schedule (D117), nobody pauses, speeds up or
triggers the load during a game: not the GM, not the players. The
players' one lever is a fixed-time operation's schedule (D116), which
moves a job, never adds traffic. To confirm: O88.

## One host or several (O46)

D122 makes multi-host available; whether v0.3 builds it is O46. The
driver's proposal:

- **Multi-host moves into v0.3**: placement per node, a registry every
  host reaches, `fit` per host; tested with armenelos and the VPS over
  Tailscale.
- **The default game stays single-host** while its load fits one host.

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
  service published on the routing mesh, so every host's loopback reaches
  it) is unverified (O10).

To build if O46 says v0.3:

- per-node placement rendered from the local implementation (hostname or
  label constraints), stateful nodes pinned with their volumes;
- a registry reachable from every host, and the images pushed to it
  before deploy;
- `fit` per host: each host's limits, reservations and disk against its
  placed nodes, each host's images counted once on that host;
- per-host SSH Docker contexts for the exec verb (D27), already in the
  platform's design.

Risks to check on the Tailscale pair (unverified):

- the overlay's VXLAN over Tailscale's 1280-byte MTU (the overlay MTU
  must leave room for both encapsulations);
- Swarm advertising the Tailscale addresses, not the public ones;
- **the routing mesh opens every published port on every host**: the
  bastion's SSH and web front would listen on the VPS's public address.
  The bastion should publish in host mode on its own pinned host, or the
  VPS firewall the ports ([platform.md](../../platform.md), "Constraints
  and pitfalls");
- both hosts up for the whole aging (D114).

## The hosts at hand

- **armenelos**: 11 GB of memory, about 5.4 GB available on 2026-10-22.
  v0.2's `fernway-clinics-monitoring` was sized for 2 CPU / 4G / 8G.
- **the VPS** (`ssh vps`), on the same tailnet: capacity to declare at
  setup.

v0.3 adds to a v0.2-sized game: two or three scheduler nodes (about 128M
each, proposed), PgBouncer when used (small, [pgbouncer.md](pgbouncer.md)),
and a busier database. A single-host v0.3 game is expected to fit in
about 5G (to measure). Two days of aging occupy the host the whole
time.

## Footprint to measure

As v0.2 did (D82): the v0.3 scenario's footprint measured on a running
game, plus, new, its volumes' growth over a full aging and a four-hour
game (logs, WAL, TSDB, tables), declared in the bricks' footprints and
counted by `fit` ([aging-and-timeline.md](aging-and-timeline.md),
"Disk over the aging").

## Open points

O46 (multi-host in v0.3), O10 (registry pattern), O88 (load control),
O95 (`max_connections`), O83 (playgrounds not up for two days).
