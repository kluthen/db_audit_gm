# v0.2 — monitoring and usual tooling

Status: draft v5. Consolidated into the [master spec](master-spec.md) and its [access model](access-model.md), both approved by the owner on 2026-10-21 (D98). Build plan: [build-plan.md](build-plan.md), approved 2026-10-21 (D99). The owner's rulings on the plan (D100–D106) amend the master spec and are written into this page.

Every item is settled and stated as fact with its decision. Planning
the build raised O72 to O77, all ruled on 2026-10-21 (D100–D105). The owner accepted the draft v2 defaults on 2026-10-21
(D72–D87), changing one: the node-health script is mounted into each
node at deploy rather than carried by a shared base image (D73). After
draft v3 the owner made the script companion material of `prometheus`
(D88, D89) and ruled out a shared base image (D90). The independent
review of draft v4 (OKAY, no blocking issue) brought the owner's rulings
D91–D96 and the details of D97.

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

### Monitoring bricks (D66, D69, D87)

One brick per need ([bricks-and-faults.md](../../bricks-and-faults.md),
"Monitoring bricks (v0.2)"):

| Brick | Need | Shape |
|---|---|---|
| node-health script, companion material of `prometheus` (D88) | Per-node health | A daemon script that reports the node's CPU, RAM, disk and the status of its important services, read from inside the node, no Docker socket (D66). The GM installs it at deploy: the script and its s6 service are mounted into each node as configs, with the node's list of services; images only have to accept a mounted service (D73). On every node whenever the topology has a metrics store; a node left out is a monitoring fault (D73). Scraped by Prometheus. Versioned with `prometheus`, which a change to the script bumps; its GM documentation is `prometheus`'s (D88) |
| `prometheus` | Metrics store | A node of its own (D74). Scrape targets in its seed configuration, so a node left out is a plantable fault. Retention bounded by time and by size, about a day, read from a seed file, so a retention fault is a seed-file fault (D106) |
| `postgres-exporter` | PostgreSQL metrics | `postgres_exporter`, a node of its own (D74), connecting to the database with a monitoring role that holds `pg_monitor`; the role's password is a generated secret (D79) |
| `grafana` | Dashboards and alerting | Grafana with its own alerting, no separate alerting brick (D69). Data sources, dashboards and alert rules provisioned from seed files the player can edit on a fixable node. No notification channel in v0.2: firing alerts are read in Grafana's alerting view. Default time zone UTC (D81). Reference dashboards and alert rules (node health, PostgreSQL) shipped in its `companion/` folder, copied by scenarios into their seed files; the node-health view is its node-health dashboard (D104) |
| `postgres` (changed) | Log analysis | PostgreSQL logs to files on a log volume, rotated by size, with a `log_line_prefix` pgBadger parses; the logging settings live in the seed `postgresql.conf`, so faults can live there (D69). pgBadger installed in the image; the players run it themselves, as `player`, as a one-shot job against the log files, which are readable by their group, no wrapper (D95); its HTML report lands in their home there and is copied out with `scp` and `sftp`. `pg_stat_statements` available, its preloading set in the seed configuration so its absence can be a fault |
| `bastion` (changed) | Reaching the UIs | Publishes every monitoring web interface (D68) through a web front on a second published port (D77), only when the topology has a web interface to publish (D103) |

No log aggregator, no cAdvisor, no Docker socket or host mount (D66,
D69). pgwatch and pgCluu, both in the reference setup, are v0.5
candidates (D70).

**The node-health script** (D73). It reads CPU and memory from the
node's own cgroup v2 files, disk as the use of the node's own volumes
(`du`) against its declared disk reservation, and its services with
`s6-svstat`, and serves them in Prometheus' text format on a fixed port
through a minimal listener, readable from every node, the bastion
included. The view shows the host's free space once, not per node, since
on one host every node sees the same figure (D96). Its default services are the
node's brick's s6 `processes`, which the GM may adjust per node. What an
image must provide to accept it: s6-overlay v3, which both v0.1 bricks
run, and the commands the script uses, which `prometheus`'s GM
documentation names (D89); each receiving brick declares what it
provides, and the loader checks it (D97). Every `debian:13-slim` image
has `perl-base` and its socket module, enough for the listener (checked
on 2026-10-21). The script and its listener run as an unprivileged
account, not root, provided `s6-svstat` can read the services' status
as that account (to verify in the build; see "To verify in the build"
below).

How it is declared (D88, D89; [formats.md](../../formats.md),
"Companion material mounted into other nodes"): the script and its s6
service are companion material of the `prometheus` brick, and
`prometheus`'s `brick.yaml` declares them as material mounted into other
nodes: the files and their target paths, the nodes that receive them,
the per-node parameter, the footprint added to each node and what a
receiving image must provide. The service list is a parameter of the
`prometheus` node in the scenario, a map that lists every node of the
topology, `prometheus`'s own included, each entry a list of services or
`default` (that node's brick's s6 `processes`); a missing map or node is
refused (D97). The script is mounted on every node of the map; a node
left out is D73's fault, planted through that parameter at rendering
(D92). The renderer writes each node's entry and its disk reservation
into that node's config. `prometheus`'s `docs/gm.md` covers the script: Placement
the mounting into the other nodes, Configuration the service list,
Footprint what it adds per node, Supported faults the faults about it.
Each receiving brick declares in `brick.yaml` what it provides to
mounted material, and its `docs/gm.md` says so under Connections (D97). Changes this makes to the build: the brick template's
companion declaration and the receiving bricks' declaration, the format
skill and the scripts (loading: the map and the receiving bricks'
declarations checked; rendering: configs added to other nodes' services
and parameter faults applied) learn mounted material; no new brick
kind.

Consequences to carry into the build:

- With file logging, the PostgreSQL log leaves Docker's service logs, so
  `gmctl logs` shows only the start-up; the GM reads the file log through
  the exec verb.
- The node-health script runs inside each node, so its CPU and memory
  count against that node's own limits, the nerfed database's included.
- The node-health script and its list of services are configs, read-only
  on the node: a wrong service list or a node left out can be reported or
  a fix proposed, but no player can fix it.
- pgBadger runs within the database node's limits too: a large run could
  take memory from PostgreSQL. Measured in the build ("Footprint").
- With no load (D67), pgBadger and the dashboards mostly show what the
  setup (data load, injection) and the players themselves leave behind.

**Node shape** (D74): every new brick is a full node, with `sshd`,
s6-overlay, the `player` account, a validator and the seed-once
entrypoint. Grafana, Prometheus and `postgres_exporter` are each a node
of their own, *fixable* or *report-only* per scenario, with configuration
they reload through `sudo` wrappers. pgBadger and `pg_stat_statements`
live inside the `postgres` brick. Prometheus and Grafana keep separate
nodes, whatever the measured footprint (D91). No shared base image (D90): every
brick builds from `debian:13-slim`, as the v0.1 bricks do, and those are
not rebased.

### Tooling proportionate to the topology (D65)

Under-tooling is no fault kind: it is an issue the customer raises, a
silent expectation of the GM, or both. Tooling about three times the
compute and disk of what it watches is overkill, and also a finding. A
silent expectation is an item of the answer key's list of tooling
expectations, outside the fault instances: what is expected and what is
acceptable, no sealed check, judged in feedback; an issue may cover one
(D76). The bastion and its tools are the players' kit, not the
customer's tooling, and do not count (D87).

### The scenario (D78)

One new, partly tooled scenario with one database, for a small or
mid-size customer: some monitoring present and ill-configured, one need
left uncovered as an under-tooling issue or expectation. It has Grafana,
so the node-health view exists, and the need left uncovered is another
one (D104). An HA customer
is out (it implies a standby), and so is a second, reporting database
(it brings in O45). `bookshop-new-server` stays as the v0.1 regression,
re-pinned to the changed bricks, keeping its version (D75).

### Faults (D80)

Four to six monitoring faults, all visible without load (D67), at least
one of them a tool starved of information, mixed with v0.1 faults. The
under-tooling item is not among them (D65). Candidates the chosen tools
make concrete:

- a node missing from Prometheus' scrape targets, with no alert on a
  target down;
- a node left without the node-health script (D73);
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
- retention shorter than the dashboards' or alerts' window.

Grafana's administrator is always on the per-game tools password (D79),
so a default-password fault is not among them (D93). The two node-health
faults are *report* or *propose* issues, never *fix* ("Consequences"
above); each targets the `prometheus` node, takes the affected node as a
parameter, and is planted through the node-health map (D92). A
deliberate masking pair waits for O23. Each fault definition lists the
brick versions it applies to one by one (D59, D86) and never bumps
(D60).

### Access, credentials and the network

- The players reach every web interface through the bastion (D68): a web
  front, a reverse proxy on the bastion's second published port, in host
  mode, every UI under its own path, behind HTTP basic authentication on
  the tools password, plain HTTP in v0.2 (D77). With no web interface
  in the topology there is no web front: the bastion publishes SSH only
  and no tools password is handed over (D103). Reports leave the
  database node by `scp` to the bastion and `sftp` from it, as files do
  in v0.1; publishing them on the bastion is v0.6's (D71).
- One per-game **tools password** opens the web front and Grafana's
  administrator account, handed over with the bastion password and kept
  in `local/<playground>/secrets/` (D45); secret generation becomes "the
  secrets the bricks declare, generated by kind" (password, key pair),
  which also gives the monitoring role its password (D79).
- **One network**, as in v0.1, the scripts refusing a second (D106);
  network faults stay out (D83). Each
  declared network renders as `<game_id>_<network name>` (D85).
- The access model is revised for v0.2 ([access-model.md](access-model.md)):
  the web front and the interfaces behind it, the tools password, the
  monitoring nodes, the monitoring role, the health endpoints, Grafana's
  write-policy gap (D94) and the log files the players read with
  pgBadger (D95).

### Platform and capacity (D83, D84)

- **One host**, with the budget "the v0.2 scenario fits 2 CPU / 4G /
  8G", and `gmctl fit` also counting image sizes against the declared
  disk (D83), read from the playground's engine, each layer once, a
  missing image refused with its build command (D102). Estimate:
  "Footprint" below.
- **A brick's footprint** in `brick.yaml` takes the shape of the
  scenario's `resources`: limits for CPU and memory, reservations for
  CPU, memory and disk, as the default the GM starts from (D84). The
  estimate below is written in that shape.
- **No aging** (D83): with no load (D67), history builds during the
  game, and the dashboards' first 10 to 15 minutes are thin.

### Evidence and times (D81)

v0.1's known issues RG-3 and RG-4 are settled here. Each evidence entry in
an answer key gains a required `where`: `bastion`, `node:<name>`,
`ui:<name>` or `report:<tool>`; v0.1's free-text `where` (the file, view
or output looked at) becomes a required `source` (D101).
`bookshop-new-server`'s key changes so at its re-pin. All times are UTC: the GM states times in UTC, nodes run with
`TZ=UTC`, PostgreSQL logs with `log_timezone = UTC`, Grafana's default
time zone is UTC.

### Bricks' GM documentation and versions

- Every brick ships GM documentation with the nine required sections of
  [formats.md](../../formats.md), "`docs/gm.md` must contain" (D56): the
  new monitoring bricks, `prometheus`'s covering the node-health script
  (D88), and the v0.1 bricks, already brought up to it at 0.1.1 (D57). "Supported faults"
  lists catalog faults only (D62).
- Versions ([formats.md](../../formats.md), "Versions and pins"): any
  change to a brick bumps it (D57, D58); changes to an unreleased version
  fold into it (D61), and a version is released only when the release
  gate of the version that builds it passes, not when a build wave
  merges into `main` (D100); faults and scenarios never bump (D60, D75); a
  fault's `applies_to` is the only statement of which faults a brick
  hosts (D59), listing versions one by one (D86). 0.1.1 is released
  (`main` at 5c16d06), so `postgres` and `bastion` take 0.2.0 for their
  v0.2 changes, and the new bricks start at 0.1.0 (D72). Each catalog
  fault that still applies to a changed brick adds 0.2.0 to its
  `applies_to`. The node-health script has no version of its own: a
  change to it bumps `prometheus`, and faults about it, such as the two
  node-health candidates above, name `prometheus` only in `applies_to`
  (D88, D92).

## Footprint

Estimates, not measurements: nothing in v0.1 or the reference setup sizes
these services. Figures are per node, in the shape of D84, from the
tooling research's order-of-magnitude figures scaled to about five
nodes, a few thousand series and a static database. The figures are a
scenario's per-node `resources`, so each includes the node's `sshd`, s6
and node-health script (about 10M for the first two; about 5M and 0.005
CPU for the script). The bricks' own `brick.yaml` footprints exclude the
script, which `prometheus`'s documentation adds per node (D97).

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

- **Images**, which `fit` counts from v0.2 (D83): about 0.8G more
  (Grafana ~450M, Prometheus ~150M, the exporter ~25M, pgBadger and its
  Perl modules ~30M in `postgres`, and about 40M of `sshd`, s6-overlay
  and tools in each new image over the `debian:13-slim` layer they all
  share), so about 1.25G with v0.1's 0.44G. Volumes plus images: about 4.5G of 8G.
- **Expected at rest** (estimate): Prometheus 80–150M, Grafana
  100–150M, the exporter 15–30M. **Peaks**: a pgBadger run inside the
  database node's 1G limit (tens of MB on v0.2's small logs, up to
  hundreds of MB on a day of real logs, per the research), and a
  dashboard load inside Grafana's 0.5 CPU.
- **Proportion** (D65): the tooling (Prometheus, Grafana, exporter)
  reserves about 0.25 CPU, 370M and 0.8G against the database's 0.5 CPU,
  512M and 2.25G, between a third and three quarters of it: well under
  the overkill yardstick for a one-database customer.
- Levers if measurement disagrees: a shorter retention or a longer
  scrape interval; Prometheus and Grafana stay on separate nodes (D91),
  and VictoriaMetrics in place of Prometheus stays a v0.5 candidate
  (D70).

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
- Backup tooling (O49, a roadmap question that names no version yet).
- Network faults, a second network, multi-host and the registry (D83).
- Aging (D83).

## Definition of done (D82)

v0.1's checks (D38), extended:

- The v0.2 scenario exists as a complete scenario folder; every brick it
  uses passes the format skill's `docs/gm.md` check (D56), `prometheus`'s
  covering the node-health script (D88).
- A full game runs on the `laptop` playground (2 CPU / 4G / 8G) from
  setup through hand-over, with `gmctl fit` passing. The playground is
  declared at that capacity on the build host, figures recorded with
  machine and date (D105).
- **Footprint, measured**: `docker stats` samples every node at rest
  after hand-over, during a Grafana dashboard load and during a pgBadger
  run; `docker system df -v` gives the images' sizes and each volume's
  use. The figures are recorded next to the estimate above. Passing
  means: no node OOM-killed or restarted during the game; each node's
  memory at rest within its reservation, or the reservation raised in
  `brick.yaml` and `docs/gm.md` and `fit` re-run, still passing on
  `laptop`; images plus volumes in use within the declared 8G; and the
  bricks' footprints carrying the measured figures in place of the
  estimates. A brick the scenario does not use is measured on a game of
  the build's integration fixture (D106).
- A play-through as `player`, through the bastion only, confirms each
  fault's evidence where the answer key says (D81): UI evidence through
  the interfaces the bastion publishes, checked through their HTTP APIs;
  report evidence by generating the report.
- The node-health view (D104) shows every node's CPU, RAM, disk (its volumes'
  use against its reservation) and services, with the host's free space
  once, and a service the GM stops shows as down.
- A request to the web front without the tools password is refused
  (HTTP 401); the game publishes only the bastion's two ports (SSH and
  the web front); nodes and PostgreSQL logs carry UTC times (D77, D81).
- Each *fix* issue on a monitoring tool is fixed, its sealed check going
  from 1 to 0.
- The tooling expectation (D76) is judged in feedback.
- `bookshop-new-server`, re-pinned, still passes its v0.1 checks.
- The stance check-list is re-run and passes.
- The owner judges the tooling's usefulness and the feedback's tone.

## To verify in the build, and details left to it

The spec takes no position on these; the build settles or verifies each
and records it:

- Swarm refuses an empty config, and an s6 service folder uses empty
  files (`dependencies.d/base`, `contents.d/<service>`): the mounted
  versions need non-empty content.
- Configs mounted into an s6 service folder the read-only image lacks.
- The node's cgroup v2 files readable inside a Swarm container.
- Which unprivileged account the node-health script and its listener run
  as, and whether `s6-svstat` reads the services' status as that account;
  root only if it cannot.
- The web front's reverse proxy; Grafana's and Prometheus' sub-path
  settings; the web front not passing its `Authorization` header on to
  Grafana.
- Who creates the exporter's monitoring role (the data load or a
  start-up step) and how its password reaches the database.
- What the `prometheus`, `grafana` and `postgres-exporter` validators
  check.

## Depends on

- v0.1: the formats, the GM stance, the scripts, the `postgres` and
  `bastion` bricks.

## Questions due in this version

Settled on 2026-10-21: the tools and the reference (D63–D66, D69, D70;
O11 narrowed), no load (D67, O50), the bastion publishing the UIs (D68,
O13), per-node health without the Docker socket (D66, O51), faults never
bump (D60, O59). After draft v2: version numbers (D72, O65), the
node-health delivery (D73), the node shape (D74), scenarios never bumping
(D75, O61), tooling expectations (D76, O62), the web front (D77, O63),
the scenario (D78, O66), the tools password and secrets (D79, O68), the
fault set (D80, O69), evidence and UTC (D81, O70), the definition of done
(D82, O71), the platform limits (D83; v0.2 parts of O12, O22, O46), the
footprint shape (D84, O57), network names (D85, O58), version lists
(D86, O60), the other defaults (D87). After draft v3: the node-health
script as `prometheus`'s companion material (D88, D89, O64), no shared
base image (D90, O67). After the review: separate Prometheus and Grafana
nodes (D91), node-health fault targets (D92), no default-password fault
(D93), Grafana's write-policy gap (D94), players running pgBadger (D95),
per-node disk (D96), mounted material made explicit (D97).

Raised while planning the build and ruled the same day: brick versions
across wave merges (D100, O72), v0.1's evidence text under `source`
(D101, O73), image sizes in `fit` (D102, O74), the web front without
interfaces (D103, O75), Grafana's reference dashboards (D104, O76), the
`laptop` playground (D105, O77); the plan's three readings (D106). O49 (backup tooling's version) is a roadmap
question v0.2 does not wait on.
