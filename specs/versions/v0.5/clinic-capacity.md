# v0.5 — the clinic's nodes and capacity

Status: draft v2, ready for review. Every node the clinic's scenario
deploys, for `vet-core` and `vet-lab` with their purposes, replication,
the office database and the partners grouped on one `api` node (D308),
and since 2026-11-03 the four parts as their ruled pages size them
(D317–D320), with D238's monitoring breadth still an estimate; checked
against the hosts the tests declare and against what `gmctl fit` counts.
Capacity is one of the things the GM adjudicates when it composes
domains, by `fit` on the composed topology
([procedure](domain-procedure.md#10-composing-domains-d322) 10, D322). The clinic is a two-host scenario, armenelos plus
the VPS, deployed whole once in v0.5 as the proof in play; every other
v0.5 test runs a small fixture on one host (D314, closing O158).

## How `fit` counts

From `tools/gm/fit.py` (v0.3 master spec 10.3, v0.4 13.3):

- per host, the sum of the reservations of the nodes placed there, plus
  a headroom of 10 % of the host's capacity, on CPU, memory and disk;
- on disk, also the images of the nodes on that host (each layer once)
  and every node's `disk_growth_per_hour` over the aging plus a
  four-hour game;
- each node's limits against the host's capacity;
- the hand-over snapshot's copies after the game's disk: when they do
  not fit, the game has no snapshot and a restart starts from nothing
  (a warning, not a refusal);
- a node carrying a fault that declares `needs_unshared_host` is refused
  on a shared host (the VPS).

The hosts, as the tests declare them (`tools/tests/smoke-load.sh`):
armenelos `cpu=4, memory=4G, disk=20G`, the manager; the VPS `cpu=2,
memory=4G, disk=10G`, shared (D159). Less the headroom, armenelos holds
3.6 CPU, 3.6G and 18G, the VPS 1.8 CPU, 3.6G and 9G; the pair 5.4 CPU and
7.2G.

## Sizing

Nodes sized by role, as v0.4's scenario was (v0.4 master spec 13.2; the
reservations of `tarnbeck-outdoor-campaign` on `main`): a `postgres`
node at the brick's 0.5 CPU and 512M, a producer or a light transformer
at 0.1 CPU and 64M, a heavy transformer at 192M as v0.4's `bi`, the
monitoring bricks as v0.4 set them. The `api` brick is not built yet
(D267): FastAPI and uvicorn estimated at 0.1 CPU and 96M, 128M for the
partners' node serving nine hostnames. These are starting figures; the
build measures them in short runs, and the aging's figures wait for the
major test (D314).

## `vet-core` and `vet-lab`: 18 nodes

| Node | Brick | Scope | CPU | Memory | Disk | Host |
|---|---|---|---|---|---|---|
| `bastion` | `bastion` | the players' | 0.1 | 96M | 256M | armenelos |
| `records` (`clinic`, `office`) | `postgres` | the players' | 0.5 | 512M | 2.25G | armenelos |
| `standby`, off site (D299) | `postgres` | the players' | 0.5 | 512M | 2.25G | VPS |
| `lab` (D301) | `postgres` | the players' | 0.5 | 512M | 2.25G | armenelos |
| `pms` | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos |
| `lis` | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos |
| `clinic-api` | `api` | the players' | 0.1 | 96M | 128M | armenelos |
| `lab-api` | `api` | the players' | 0.1 | 96M | 128M | armenelos |
| `interfaces` | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos |
| `backoffice` | `scheduler` | the players' | 0.1 | 192M | 128M | VPS |
| `prometheus` | `prometheus` | monitoring | 0.1 | 160M | 512M | armenelos |
| `grafana` | `grafana` | monitoring | 0.1 | 272M | 256M | VPS |
| three exporters (`records`, `standby`, `lab`; v0.4 13.4) | `postgres-exporter` | monitoring | 0.15 | 144M | 192M | two on armenelos, one on the VPS |
| the partners' `api` node (D308) | `api` | out of reach | 0.1 | 128M | 128M | VPS |
| the partners' back end | `scheduler` | out of reach | 0.1 | 64M | 128M | VPS |
| the partners' database | `postgres` | out of reach | 0.25 | 256M | 2G | VPS |
| **Total** | | | **3.0** | **3.2G** | **10.9G** | |

A pooler in front of `records` (the scenario's choice, step 6) adds
0.05 CPU and 32M.

**Placed**: armenelos 11 nodes, 1.8 CPU, 1.7G, 6G of volumes; the VPS 7
nodes, 1.2 CPU, 1.4G, 4.9G. The standby off site and the partners out
of reach land naturally on the second host.

**On one host** (4 CPU, 4G) the 18 nodes would fit, barely: 3.4 CPU and
3.6G with the headroom, 0.4G spare. With the brick defaults instead
(`bastion` 128M, every `postgres` node 512M, the `api` nodes 128M), the
first count's 3.8G (O158), they would not. No v0.5 test deploys them on
one host: each fixture is a handful of these nodes
([test selection](clinic-test-selection.md#the-fixtures) and the
parts' own), the largest, `vet-portal`'s, eight with the bastion, about
1.75 CPU and 1.7G.

## The four parts: 5 nodes

As the ruled pages size them (D317–D320); every new node on armenelos:

| Node or change | Part | Brick | Scope | CPU | Memory | Disk | Host |
|---|---|---|---|---|---|---|---|
| `ward`, the ward service (D287) | `vet-housing` | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos |
| `machines` (`pacs`, `vitals`, `biomed`) | `vet-machinery` | `postgres` | the players' | 0.5 | 512M | 2.25G | armenelos |
| `equipment`, the machines' producer | `vet-machinery` | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos |
| the `machines` exporter | `vet-machinery` | `postgres-exporter` | monitoring | 0.05 | 48M | 64M | armenelos |
| `portal-api` | `vet-portal` | `api` | the players' | 0.1 | 96M | 128M | armenelos |
| `pms` 64M → 96M (the scheduling module's fragments) | `vet-scheduling` | | | 0 | +32M | | armenelos |
| `interfaces` 64M → 96M (six more jobs: the bookings sync, the imaging orders, the shipping, the portal's two) | the parts' purposes | | | 0 | +32M | | armenelos |
| **Total** | | | | **0.85** | **848M** | **2.7G** | |

Beside the nodes, on what exists: `vet-scheduling` and `vet-housing`
land in `clinic` and `vet-portal` in a database `portal`, all on
`records` (about 0.11, 0.16 and 0.21 million rows, within its 2.25G);
the owners' traffic is a tenth hostname, `owners`, on the partners'
`api` node, at 128M still (to be measured). `vet-machinery`'s trims
stand ready: its producer's fragments on `pms`, no exporter, `machines`
at 0.25 CPU, down to 2 nodes and about 0.25 CPU (vet-machinery O196).

## The whole clinic: 23 nodes, 25 to 27 with D238's monitoring

| | Nodes | CPU | Memory | Disk |
|---|---|---|---|---|
| `vet-core` and `vet-lab` | 18 | 3.0 | 3 232M | 10.9G |
| The four parts | 5 | 0.85 | 848M | 2.7G |
| **The clinic as defined** | **23** | **3.85** | **4 080M, about 4.0G** | **13.6G** |
| D238: pgwatch (collector, its sink in Prometheus or a database of its own), pgCluu, a Nagios-style health check, still an estimate | 2 to 4 | 0.15 to 0.4 | 0.2G to 0.5G | |
| **The whole clinic** | **25 to 27** | **4.0 to 4.25** | **about 4.2G to 4.5G** | |

**Placed**: armenelos 16 nodes, 2.65 CPU, about 2.55G, about 8.7G of
volumes; the VPS unchanged, 7 nodes, 1.2 CPU, 1.4G, 4.9G.

Against the pair's 5.4 CPU and 7.2G: memory has room, **CPU is the tight
dimension**, at 74 % to 79 % of what the headroom leaves. Armenelos
holds 2.65 of its 3.6 CPU before the monitoring, 2.8 to 3.05 with it all
there; the VPS has 0.6 CPU left, so some of D238's light nodes may go
there instead.

**Disk** is the VPS's second limit: its 4.9G of volumes, the images
(about 1.5G, each layer once, by the sizes of v0.4's images on
armenelos, Grafana's 866M the largest) and the growth over a
sixteen-hour aging and the game (about 0.4G) leave about 2.2G of its
9G: no other `postgres` node (2.25G) fits there, so `machines` goes to
armenelos, as do the parts' other nodes. On armenelos the 8.7G of
volumes, the parts' images and `machines`' growth (about 10 MB a day,
shipped nightly) leave room within its 18G. The hand-over snapshot's copies (the volumes again) fit
neither host at this size: a game of the whole clinic has no snapshot
on these declarations, which the short proof in play does not need;
whether v1.0's major test does is that test's to settle.

**The shared VPS** (D159) takes no node that may exhaust its memory:
none of the test selection's faults sets `needs_unshared_host`; a game
selecting one (a report killed for memory, as v0.4's f10) places that
node on armenelos.

If the build measures heavier, the trims stand ready, in this order:
D238's extra monitoring to one collector; `vet-machinery`'s trims (2
nodes, about 0.25 CPU); the partners' database on `records`' instance,
out of the players' reach by its access rules (D275). The portal's
database on `records` is taken already (D320). Each would be the
owner's call when it comes.

## Checked at the build

`gmctl fit` on the scenario as built, with the measured reservations
and the real image sizes, on armenelos plus the VPS, before the proof in
play; each fixture's `fit` on one host before its test.
