# v0.5 — the clinic's nodes and capacity

Status: draft v1, ready for review. Every node the clinic's scenario
deploys so far, for `vet-core` and `vet-lab` with their purposes,
replication, the office database and the partners grouped on one `api`
node (D308), with an estimate for the four parts still to define
(scheduling, housing, machinery, the portal) and D238's monitoring
breadth; checked against the hosts the tests declare and against what
`gmctl fit` counts. The clinic is a two-host scenario, armenelos plus
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
([test selection](clinic-test-selection.md#the-fixtures)), the largest
eight with the bastion, about 1.6 CPU and 1.5G.

## The whole clinic: about 26 to 32 nodes

The four parts and D238's monitoring are estimates until their steps 4
and 6:

| Addition | Nodes | CPU | Memory |
|---|---|---|---|
| `vet-scheduling`: in `pms` (D276), its tables in `clinic` or a database on `records` | 0 to 1 | 0 to 0.1 | 0 to 64M |
| `vet-housing`: the ward service holding the displays' pool (D287), its tables on `records` | 1 | 0.1 | 64M |
| `vet-machinery`: a database for the machines' time series, their producer, the shipping job to cold storage (D288, D297), an exporter | 3 to 4 | 0.7 to 0.8 | 0.6G to 0.7G |
| `vet-portal`: its `api` node, the owners' producer, its own database or one on `records`, an exporter if its own | 2 to 4 | 0.2 to 0.8 | 0.2G to 0.8G |
| D238: pgwatch (collector, its sink in Prometheus or a database of its own), pgCluu, a Nagios-style health check | 2 to 4 | 0.15 to 0.4 | 0.2G to 0.5G |
| **The four parts and the monitoring** | **8 to 14** | **1.2 to 2.2** | **1.1G to 2.1G** |
| **The whole clinic** | **26 to 32** | **4.2 to 5.2** | **4.3G to 5.3G** |

Against the pair's 5.4 CPU and 7.2G: memory has room, **CPU is the tight
dimension**, at 78 % to 96 % of what the headroom leaves. The VPS is the
tighter host: 1.8 CPU, of which the core's and the lab's nodes already
take 1.2; the parts' nodes go to armenelos first, which then holds 3.0
to 3.6 of its 3.6 CPU, the VPS taking the light remainder (at the upper
estimate, armenelos 3.4 and the VPS its full 1.8).

**Disk** is the VPS's second limit: its 4.9G of volumes, the images
(about 1.5G, each layer once, by the sizes of v0.4's images on
armenelos, Grafana's 866M the largest) and the growth over a
sixteen-hour aging and the game (about 0.4G) leave about 2.2G of its
9G: no other `postgres` node (2.25G) fits there, so the machinery's and the portal's databases go to
armenelos. The hand-over snapshot's copies (the volumes again) fit
neither host at this size: a game of the whole clinic has no snapshot
on these declarations, which the short proof in play does not need;
whether v1.0's major test does is that test's to settle.

**The shared VPS** (D159) takes no node that may exhaust its memory:
none of the test selection's faults sets `needs_unshared_host`; a game
selecting one (a report killed for memory, as v0.4's f10) places that
node on armenelos.

If the parts come out heavier, the trims stand ready, in this order:
D238's extra monitoring to one collector; the portal's database on
`records`; the partners' database on `records`' instance, out of the
players' reach by its access rules (D275). Each would be the owner's
call when it comes.

## Checked at the build

`gmctl fit` on the scenario as built, with the measured reservations
and the real image sizes, on armenelos plus the VPS, before the proof in
play; each fixture's `fit` on one host before its test.
