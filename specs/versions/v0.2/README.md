# v0.2 — monitoring and usual tooling

Status: draft v2. No master spec.

Settled items are stated as fact with their decision; tentative ones are
tagged `(proposed)` and cite the open question that holds them. The
`(proposed)` items come from the v0.2 decision set of 2026-10-21 and keep
its recommendation unless an owner ruling changed the ground under it.

## Goal

In the owner's words: "We will first bundle a few bricks with the most
common (free, open-source) monitoring tools: some Grafana dashboard, some
system monitoring tool (docker up and down, load, etc.), eventually log
aggregators." (D47)

As ruled on 2026-10-21: v0.2 covers the basic needs with one free default
tool per need, chosen with footprint as a main criterion, and fills the
gap the owner's reference setup leaves, a general per-node health view
(D63, D64). Monitoring is optional in a topology, and how well a customer
is tooled is itself something to audit (D65). Other tools and hand-made
scripts come in v0.5 (D70); the bastion as the players' main activity
point in v0.6 (D71).

## In scope

### Monitoring bricks (D66, D69)

One brick per need ([bricks-and-faults.md](../../bricks-and-faults.md),
"Monitoring bricks (v0.2)"):

| Brick | Need | Shape |
|---|---|---|
| `node-health` | Per-node health | A daemon script on every node of the topology, configured by the GM at initialisation: the node's CPU, RAM, disk and the status of its important services, read from inside the node, no Docker socket (D66). Scraped by Prometheus. Packaging and delivery: O64 |
| `prometheus` | Metrics store | A node of its own (proposed, O67). Scrape targets in its seed configuration, so a node left out is a plantable fault. Retention bounded by time and by size, about a day (proposed) |
| `postgres-exporter` | PostgreSQL metrics | `postgres_exporter`, a node of its own (proposed, O67), connecting to the database with a monitoring role that holds `pg_monitor` (proposed); the role's password is a generated secret (proposed, O68) |
| `grafana` | Dashboards and alerting | Grafana with its own alerting, no separate alerting brick (D69). Data sources, dashboards and alert rules provisioned from seed files the player can edit on a fixable node (proposed). No notification channel in v0.2: firing alerts are read in Grafana's alerting view (proposed). Default time zone UTC (proposed, O70) |
| `postgres` (changed) | Log analysis | PostgreSQL logs to files on a log volume, rotated by size, with a `log_line_prefix` pgBadger parses; the logging settings live in the seed `postgresql.conf`, so faults can live there (D69; details proposed). pgBadger installed in the image and run as a one-shot job on the database node against the log files, its HTML report left in the player's home there and copied out with `scp` and `sftp` (proposed). `pg_stat_statements` available, its preloading set in the seed configuration so its absence can be a fault (proposed) |
| `bastion` (changed) | Reaching the UIs | Publishes every monitoring web interface (D68); how: O63, default a web front on a second published port (proposed) |

No log aggregator, no cAdvisor, no Docker socket or host mount (D66,
D69). pgwatch and pgCluu, both in the reference setup, are v0.5
candidates (D70).

Consequences to carry into the build:

- With file logging, the PostgreSQL log leaves Docker's service logs, so
  `gmctl logs` shows only the start-up; the GM reads the file log through
  the exec verb (proposed).
- The node-health script runs inside each node, so its CPU and memory
  count against that node's own limits, the nerfed database's included.
- pgBadger runs within the database node's limits too: a large run could
  take memory from PostgreSQL. Measured in the build ("Footprint").
- With no load (D67), pgBadger and the dashboards mostly show what the
  setup (data load, injection) and the players themselves leave behind.

**Node shape** (proposed, O67): every new brick is a full node, with
`sshd`, s6-overlay, the `player` account, a validator and the seed-once
entrypoint, on a new shared base image (Debian 13, s6-overlay, `sshd`)
that also carries the node-health service (O64). Grafana, Prometheus and
`postgres_exporter` are each a node of their own, *fixable* or
*report-only* per scenario, with configuration they reload through `sudo`
wrappers. pgBadger and `pg_stat_statements` live inside the `postgres`
brick. The v0.1 bricks move onto the shared base. If measured footprint
is tight, Prometheus and Grafana share one node.

### Tooling proportionate to the topology (D65)

Under-tooling is no fault kind: it is an issue the customer raises, a
silent expectation of the GM, or both. Tooling about three times the
compute and disk of what it watches is overkill, and also a finding. How
a silent expectation is written in the answer key and judged in feedback:
O62, default an answer-key list of tooling expectations outside the fault
instances, which an issue may cover (proposed). The bastion and its tools
are the players' kit, not the customer's tooling, and do not count
(proposed).

### The scenario (proposed, O66)

One new, partly tooled scenario with one database, for a small or
mid-size customer: some monitoring present and ill-configured, one need
left uncovered as an under-tooling issue or expectation. An HA customer
is out (it implies a standby), and so is a second, reporting database
(it brings in O45). `bookshop-new-server` stays as the v0.1 regression,
re-pinned to the changed bricks (its version: O61).

### Faults (proposed, O69)

Four to six monitoring faults, all visible without load (D67), at least
one of them a tool starved of information, mixed with v0.1 faults. The
under-tooling item is not among them (D65). Candidates the chosen tools
make concrete:

- a node missing from Prometheus' scrape targets, with no alert on a
  target down;
- a node-health script whose service list leaves out the node's main
  service, so the node shows healthy while its database is down;
- no slow-query log (`log_min_duration_statement = -1`), a
  `log_line_prefix` pgBadger cannot parse, or non-English `lc_messages`;
- `pg_stat_statements` not preloaded, so the query panels are empty;
- the exporter's role without `pg_monitor`, so panels are partial, not
  empty;
- a Grafana data source pointed at the wrong address;
- an alert threshold in the wrong unit, or a `for:` longer than the
  incident;
- retention shorter than the dashboards' or alerts' window;
- Grafana's administrator left on its default password.

A deliberate masking pair waits for O23. Each fault definition names the
brick versions it applies to (D59) and never bumps (D60).

### Access, credentials and the network

- The players reach every web interface through the bastion (D68),
  default a web front on its second published port, in host mode, every
  UI under its own path (proposed, O63). Reports leave the database node
  by `scp` to the bastion and `sftp` from it, as files do in v0.1;
  publishing them on the bastion is v0.6's (D71).
- One per-game **tools password** opens the web front and Grafana's
  administrator account, handed over with the bastion password and kept
  in `local/<playground>/secrets/` (D45); secret generation becomes "the
  secrets the bricks declare, generated by kind", which also gives the
  monitoring role its password (proposed, O68).
- **One network**, as in v0.1; network faults stay out (proposed, O12).
  Rendered network names: O58, default one rendered network per declared
  one, named `<game_id>_<network name>` (proposed).
- The access model is revised for v0.2 at consolidation: the web
  interfaces and their accounts, the monitoring role, the health
  endpoints.

### Platform and capacity

- **One host**, with the budget "the v0.2 scenario fits 2 CPU / 4G /
  8G", and `gmctl fit` also counting image sizes against the declared
  disk (proposed, O46). Estimate: "Footprint" below.
- **A brick's footprint** in `brick.yaml` takes the shape of the
  scenario's `resources`: limits for CPU and memory, reservations for
  CPU, memory and disk, as the default the GM starts from (proposed,
  O57). The estimate below is written in that shape.
- **No aging** (proposed, O22): with no load (D67), history builds during
  the game, and the dashboards' first 10 to 15 minutes are thin.

### Evidence and times (proposed, O70)

v0.1's known issues RG-3 and RG-4 are settled here. Each evidence entry in
an answer key gains a required `where`: `bastion`, `node:<name>`,
`ui:<name>` or `report:<tool>`; `bookshop-new-server`'s key gains it at
its re-pin. All times are UTC: the GM states times in UTC, nodes run with
`TZ=UTC`, PostgreSQL logs with `log_timezone = UTC`, Grafana's default
time zone is UTC.

### Bricks' GM documentation and versions

- Every brick ships GM documentation with the nine required sections of
  [formats.md](../../formats.md), "`docs/gm.md` must contain" (D56): the
  new monitoring bricks, the node-health script included, and the v0.1
  bricks, already brought up to it at 0.1.1 (D57). "Supported faults"
  lists catalog faults only (D62).
- Versions ([formats.md](../../formats.md), "Versions and pins"): any
  change to a brick bumps it (D57, D58); changes to an unreleased version
  fold into it (D61); faults never bump (D60); a fault's `applies_to` is
  the only statement of which faults a brick hosts (D59), listing
  versions one by one (proposed, O60). Scenarios: O61. Which numbers
  v0.2's brick changes take: O65, default new bricks at 0.1.0 and a
  changed v0.1 brick at 0.2.0 once 0.1.1 is released (proposed).

## Footprint

Estimates, not measurements: nothing in v0.1 or the reference setup sizes
these services. Figures are per node, in the shape of O57's default, from
the tooling research's order-of-magnitude figures scaled to about five
nodes, a few thousand series and a static database. Each node's figures
include its `sshd`, s6 and node-health script (about 10M for the first
two; about 5M and 0.005 CPU for the script).

| Node | Reservation CPU | Reservation memory | Volumes | Limit CPU | Limit memory |
|---|---|---|---|---|---|
| `bastion` (v0.1: 0.1 / 64M / 256M), with web front and health | 0.1 | 96M | 256M | 0.5 | 256M |
| `db` (v0.1: 0.5 / 512M / 2G), with log volume and health | 0.5 | 512M | 2.25G | 1 | 1G |
| `prometheus` | 0.1 | 160M | 512M | 0.5 | 384M |
| `grafana` | 0.1 | 160M | 256M | 0.5 | 384M |
| `postgres-exporter` | 0.05 | 48M | 64M | 0.25 | 128M |
| **Total** | **0.85** | **976M** | **3.3G** | | |

Against the `laptop` playground (2 CPU / 4G / 8G), with `fit`'s 10 %
headroom (1.8 CPU / 3.6G / 7.2G usable): about 47 % of the usable CPU,
26 % of the memory and 46 % of the disk are reserved, leaving about 0.95
CPU, 2.6G and 3.9G. v0.2 adds about 0.25 CPU, 400M and 1.1G to v0.1's
reservations. CPU stays the tightest dimension.

- **Images**, which `fit` does not count today (O46): about 0.8G more
  (the shared base ~150M once, Grafana ~450M, Prometheus ~150M, the
  exporter ~25M, pgBadger and its Perl modules ~30M in `postgres`), so
  about 1.25G with v0.1's 0.44G. Volumes plus images: about 4.5G of 8G.
- **Expected at rest** (estimate): Prometheus 80–150M, Grafana
  100–150M, the exporter 15–30M. **Peaks**: a pgBadger run inside the
  database node's 1G limit (tens of MB on v0.2's small logs, up to
  hundreds of MB on a day of real logs, per the research), and a
  dashboard load inside Grafana's 0.5 CPU.
- **Proportion** (D65): the tooling (Prometheus, Grafana, exporter)
  reserves about 0.25 CPU, 370M and 0.8G against the database's 0.5 CPU,
  512M and 2.25G, between a third and three quarters of it: well under
  the overkill yardstick for a one-database customer.
- Levers if measurement disagrees: Prometheus and Grafana in one node
  (O67), a shorter retention, VictoriaMetrics in place of Prometheus (a
  v0.5 candidate, D70).

How done measures it: "Definition of done" below.

## Out of scope

- Producers, consumers and any load: monitoring is thin in v0.2 (D67);
  load is v0.3's. Transformers (v0.4). Monitoring faults that only show
  under load.
- A log aggregator, a separate alerting brick, cAdvisor, any Docker
  socket or host mount (D66, D69).
- Other tools, other health solutions (Nagios or others) and hand-made
  scripts as customer tooling (v0.5, D70).
- The bastion as the players' main activity point: the documentation
  website, general-use tooling, reports published on the bastion (v0.6,
  D71).
- Backup tooling (O49).
- Network faults, a second network, multi-host and the registry
  (proposed, O12, O46).

## Definition of done (proposed, O71)

v0.1's checks (D38), extended:

- The v0.2 scenario exists as a complete scenario folder; every brick it
  uses, the node-health script included, passes the format skill's
  `docs/gm.md` check (D56).
- A full game runs on the `laptop` playground (2 CPU / 4G / 8G) from
  setup through hand-over, with `gmctl fit` passing.
- **Footprint, measured**: `docker stats` samples every node at rest
  after hand-over, during a Grafana dashboard load and during a pgBadger
  run; `docker system df -v` gives the images' sizes and each volume's
  use. The figures are recorded next to the estimate above. Passing
  means: no node OOM-killed or restarted during the game; each node's
  memory at rest within its reservation, or the reservation raised in
  `brick.yaml` and `docs/gm.md` and `fit` re-run, still passing on
  `laptop`; images plus volumes in use within the declared 8G; and the
  bricks' footprints carrying the measured figures in place of the
  estimates.
- A play-through as `player`, through the bastion only, confirms each
  fault's evidence where the answer key says (O70): UI evidence through
  the interfaces the bastion publishes, checked through their HTTP APIs;
  report evidence by generating the report.
- The node-health view shows every node's CPU, RAM, disk and services,
  and a service the GM stops shows as down.
- Each *fix* issue on a monitoring tool is fixed, its sealed check going
  from 1 to 0.
- The tooling expectation (O62) is judged in feedback.
- `bookshop-new-server`, re-pinned, still passes its v0.1 checks.
- The stance check-list is re-run and passes.
- The owner judges the tooling's usefulness and the feedback's tone.

## Depends on

- v0.1: the formats, the GM stance, the scripts, the `postgres` and
  `bastion` bricks.

## Questions due in this version

Settled on 2026-10-21: the tools and the reference (D63–D66, D69, D70;
O11 narrowed), no load (D67, O50), the bastion publishing the UIs (D68,
O13), per-node health without the Docker socket (D66, O51), faults never
bump (D60, O59).

Open, each with a proposed default above:

- O62: how a silent tooling expectation is written and judged.
- O63: how the bastion publishes the UIs.
- O64: the node-health brick's packaging and delivery.
- O65: version numbers for v0.2's brick changes.
- O66: the v0.2 scenario.
- O67: node shape and the shared base image.
- O68: the tools password and secrets generated by kind.
- O69: the v0.2 fault set.
- O70: where evidence is run (RG-3), and UTC everywhere (RG-4).
- O71: the definition of done.
- O12 (v0.2 part): one network, network faults out.
- O22 (v0.2 part): no aging.
- O46 (v0.2 part): one host, `fit` counting images.
- O57: a brick's footprint as limits and reservations.
- O58: rendered network names.
- O60: version lists, not ranges, in `applies_to`.
- O61: when a scenario's version changes.
