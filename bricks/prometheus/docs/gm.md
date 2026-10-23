# Prometheus brick — GM notes

GM documentation of the `prometheus` brick (`brick.yaml`, v0.2 master
spec 7 and 7.2; required sections: v0.2 master spec 6.2). Never shipped
to players. Brick version 0.2.0, expected to evolve as games are played.

## Purpose

Prometheus 3.13.5 on Debian 13 (trixie), with an SSH server for the
players, in the image `127.0.0.1:5000/dbagm/prometheus:0.2.0`. It fills
the role `monitoring`: the node that scrapes and keeps the game's
metrics, which the players audit as the customer's monitoring and read
through its UI, and which a Grafana node queries. The GM picks it for
every scenario with monitoring; one per scenario. It ships the
**node-health script** (`companion/node-health/`, master spec 7.1), which
the GM mounts into every node of a game that has a `prometheus` node, so
that each node reports its own CPU, memory, disk and services.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server`, `sudo`, `curl`, `nano`,
  `vim-tiny`, `less`, `procps`.
- Prometheus 3.13.5 (`prometheus` and `promtool`, linux-amd64) from the
  upstream release archive, verified by SHA-256 at build against the
  release's `sha256sums.txt`.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image. The
  node-health script is not in the image either: it is mounted, here as
  on every other node.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`). And, into
  **every node the `node_health` map lists** (every node of the topology,
  this one and the bastion included), the node-health script as
  read-only configs (`brick.yaml` `companion.mounted`, item
  `node-health`), with one per-node config each; see "The node-health
  script" below. No image carries it; a receiving node's brick must
  declare `receives` meeting the item's `requires` (s6-overlay `3`, the
  commands `sh`, `perl`, `du`, `df`, `s6-svstat`), which `postgres` and
  `bastion` 0.3.0, `postgres-exporter` and `grafana` 0.2.0, and this brick
  do.
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus`.
- **How many**: one per scenario. Prometheus and Grafana always keep
  separate nodes.
- **Next to which node**: any host; it reaches its scrape targets by node
  name over the game's network.
- **Stateful**: yes (`stateful: true`). Its volumes `promdata`, `promconf`,
  `home`, `gmstate` and `run` (see "Configuration") must follow the node
  if it is replaced; otherwise the history, the players' changes and the
  seed marker are lost.
- **Networks**: it must share a network with the bastion (the players'
  way in, and the web front that relays its UI) and with every node it
  scrapes. The renderer runs the whole game on one network, so it shares
  it with every node.

## Configuration

`brick.yaml` declares one parameter, `node_health`, and no knobs
(`knobs: []`): the scrape targets and the retention are in the seed file.

### Parameter `node_health`

| | |
|---|---|
| Meaning | which nodes receive the node-health script, and which s6 services each one reports |
| Shape | `node-map`: node name to `default` (that node's brick's `processes`) or a non-empty list of names from them |
| Default | none (`null`); required |
| Valid values | exactly the topology's node names as keys, this node included; the loader refuses a missing map or a missing node |
| Where it lands | never as an environment variable: the renderer writes each entry into that node's own `/opt/gm/node-health/node.conf` |

```yaml
parameters:
  node_health: {bastion: default, db: [postgres, sshd], prometheus: default}
```

Leaving a node out, or a service out of a node's list, exists only as a
parameter fault (a monitoring fault). The map is set on the
`prometheus` node; it configures the other nodes.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Seed file `prometheus.yml` (`seed.files`) | `/opt/gm/seed/prometheus.yml`, root `0444`, copied into `/etc/prometheus/` at first start | the scenario's `seed_files` (`nodes/<node>/prometheus.yml`) |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |
| Parameter `node_health` | each listed node's `/opt/gm/node-health/node.conf`, root `0444`, with the node-health script | the scenario, on this node; written per node by the renderer |

### What the seed file must contain

`prometheus.yml` is Prometheus' own configuration file, used as is:

- **Scrape targets** (`scrape_configs`), by node name and container port:
  every node the scenario monitors. A target missing from the file is a
  plantable fault (a seed-file fault), so the scenario's file is the
  place to leave one out.
- Prometheus scraping itself, if the scenario wants it: target
  `localhost:9090` with `metrics_path: /prometheus/metrics` (everything is
  served under the sub-path, its own metrics included).
- **Retention**, bounded both by time and by size, about a day (v0.2
  master spec 7.2, D106):

  ```yaml
  storage:
    tsdb:
      retention:
        time: 1d
        size: 256MB
  ```

  It is read from the file at start and at each reload, so a retention
  fault is a seed-file fault, fixable on a fixable node. Size units are
  powers of two (`256MB` is 256 MiB) and count the TSDB's blocks; keep
  the size well under the node's disk reservation (`512M` by default), as
  the write-ahead log comes on top. The validator is red when either bound
  is missing (see "Checks").
- No rule files: the brick seeds only `prometheus.yml`, so a scenario
  that needs recording or alerting rules needs a new seed file, hence a
  new brick version. Players may write rule files in `/etc/prometheus`
  and name them in the file themselves.

Do not set anything that moves the files or the port (`--config.file`,
the storage path, the listen address and the sub-path are command-line
flags, fixed by the brick).

### The node-health script

Mounted into each node the map lists (`companion.mounted`, item
`node-health`); every file root-owned (`0:0`), no write bit:

| File (source under `companion/node-health/`) | Target in the receiving node | Mode |
|---|---|---|
| `node-health.pl` | `/usr/local/lib/gm/node-health/node-health.pl` | `0444` |
| `s6-rc.d/gm-node-health/type` (`longrun`) | `/etc/s6-overlay/s6-rc.d/gm-node-health/type` | `0444` |
| `s6-rc.d/gm-node-health/run` | `/etc/s6-overlay/s6-rc.d/gm-node-health/run` | `0555` |
| `s6-rc.d/gm-node-health/dependencies.d/base` | `/etc/s6-overlay/s6-rc.d/gm-node-health/dependencies.d/base` | `0444` |
| `user-bundles.d/user/contents.d/gm-node-health` | `/etc/s6-overlay/user-bundles.d/user/contents.d/gm-node-health` | `0444` |
| per-node config, written by the renderer | `/opt/gm/node-health/node.conf` | `0444` |

**Per-node config** (`node_config`): UTF-8 text, one `key=value` a line,
never empty; `#` lines and blank lines are ignored, every key required:

```
node=db
services=postgres sshd
disk_reservation=1073741824
volumes=/var/lib/postgresql/18/data /etc/postgresql /home/player /var/lib/gm-state /run
```

`node`: the node's name, used as the `node` label. `services`: the map
entry, `default` expanded to the brick's `processes`, space-separated.
`disk_reservation`: the node's `resources.reservations.disk` in bytes.
`volumes`: the in-container paths of the brick's `volumes`,
space-separated. A missing or malformed file makes the script log
`gm-node-health: fatal: ...` in the node's output and retry every 30 s.

**What it does**: one s6 longrun, `gm-node-health`, in s6-overlay's
`user` bundle, started at boot with the node's own services. Two
processes:

- the **sampler**, as root: every 5 s the status of each listed service
  (`s6-svstat` on `/run/service/<name>`), every 30 s the space used by
  each volume (`du -skx`) and the free space of the host filesystem that
  holds the first volume (`df -Pk`). It writes them to
  `/run/gm-node-health/sample.prom` and keeps no socket. It stays root
  because neither `s6-svstat` nor `du` can read as an unprivileged
  account (see "Settled at build" below);
- the **listener**, forked by the sampler, which drops to `nobody:nogroup`
  (uid and gid 65534, present in every Debian image) before it opens its
  socket. It serves `GET /metrics` on **port 9110** (all addresses) in
  Prometheus' text format: CPU and memory read from the node's own
  cgroup v2 files (`/sys/fs/cgroup`, read at request time), then the
  latest sample. `/` answers a pointer to `/metrics`; anything else 404.

If the listener dies, the sampler exits and s6 restarts both.

| Metric (each labelled `node`) | From |
|---|---|
| `node_health_cpu_seconds_total` (counter) | `cpu.stat` `usage_usec` |
| `node_health_cpu_throttled_seconds_total` (counter) | `cpu.stat` `throttled_usec` |
| `node_health_cpu_limit_cores` | `cpu.max` (absent without a limit) |
| `node_health_memory_used_bytes` | `memory.current`, page cache included |
| `node_health_memory_working_set_bytes` | `memory.current` less `inactive_file` |
| `node_health_memory_limit_bytes` | `memory.max` (absent without a limit) |
| `node_health_memory_oom_kills_total` (counter) | `memory.events` `oom_kill` |
| `node_health_volume_used_bytes{path}` | `du`, one per volume |
| `node_health_disk_used_bytes` | the volumes' sum, to set against the next one |
| `node_health_disk_reservation_bytes` | `disk_reservation` |
| `node_health_host_free_bytes`, `node_health_host_size_bytes` | `df`: the host's filesystem, the same figure on every node of a host, so the health view shows it once |
| `node_health_service_up{service}` | `s6-svstat`: 1 up, 0 down (also 0 for a name s6 does not know) |
| `node_health_service_wanted_up{service}` | 0 after `s6-svc -d`, 1 otherwise |
| `node_health_service_state_seconds{service}` | seconds since it last went up or down |
| `node_health_sample_age_seconds` | age of the latest sample |

**Scraping it**: list every node's `<node>:9110` in the seed
`prometheus.yml` (default `metrics_path` `/metrics`); a node left out of
the targets is a seed-file fault, distinct from a node left out of the
map.

**Settled at build** (master spec 15):

- *Empty configs*: Swarm refuses an empty config, and s6-rc uses empty
  marker files (`dependencies.d/base`, `contents.d/<service>`). The
  mounted markers carry a comment line; s6-rc reads only their names
  (seen with s6-overlay 3.2.3.2).
- *Service folder missing from a read-only image*: Docker creates the
  mount points of configs (`/etc/s6-overlay/s6-rc.d/gm-node-health/`,
  `/usr/local/lib/gm/node-health/`, `/opt/gm/node-health/`) before it
  makes the root read-only, so nothing has to exist in the image (Docker
  29.9.1, swarm mode).
- *cgroup v2 in a Swarm container*: the container has its own cgroup
  namespace; `/sys/fs/cgroup` is the node's own cgroup, read-only and
  readable by `nobody`, and `cpu.max` and `memory.max` carry the
  service's limits.
- *Account*: `s6-svstat` cannot read as `nobody` (`unable to check
  /run/service/<name>: Permission denied`: each `supervise/` is root
  `0700`), and `du` cannot read the volumes of other accounts (PGDATA is
  `postgres` `0700`). So the sampler, which runs only those two and `df`,
  stays root, and the listener, which faces the network, runs as
  `nobody`.
- *Port*: 9110, fixed.

### Fixed paths (capture W1-B)

| What | Path | Notes |
|---|---|---|
| Seed directory | `/opt/gm/seed/` | config `prometheus.yml`, read-only |
| Configuration | `/etc/prometheus/` | volume `promconf`; `prometheus:promconf`, dir `2775`, seeded file `0664` |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`; dir root `0755`, marker root `0444`; present means never seed again |
| TSDB | `/var/lib/prometheus` | volume `promdata`; `prometheus:prometheus`, `0750` |
| Player home | `/home/player` | volume `home` |
| Runtime | `/run` | volume `run`, emptied at each start (see below) |
| Secret | `/opt/gm/secrets/player_ssh_pubkey` | |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-reload-prometheus`, `gm-validate` | |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |
| Node-health script, config, sample | `/usr/local/lib/gm/node-health/node-health.pl`, `/opt/gm/node-health/node.conf`, `/run/gm-node-health/sample.prom` | mounted, on every listed node (see above) |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/sshd`, `/run/sshd-keys`, `/run/gm`,
   `/run/tmp` (`/tmp` and `/var/tmp` are symlinks to it).
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if the secret is missing or empty.
4. If `/var/lib/gm-state/.gm-seeded` is absent: copies `prometheus.yml`
   into `/etc/prometheus/` and writes the marker. A missing seed file
   fails the container. Never overwrites afterwards. The marker is on its
   own root-owned volume, out of reach of `player` and `prometheus`.
5. Sets the ownership of the TSDB and the player's home.
6. Execs s6-overlay's `/init`, which supervises `prometheus` and `sshd`.

Prometheus runs as `prometheus` with
`--config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/var/lib/prometheus --web.listen-address=:9090 --web.external-url=/prometheus/ --web.route-prefix=/prometheus/`,
and neither `--web.enable-admin-api` nor `--web.enable-lifecycle`. Its log
goes to the container's output (`gmctl logs`); players do not see it.
`/run` is a named volume for the reason the `postgres` brick's
[GM notes](../../postgres/docs/gm.md#why-run-is-a-volume) give.

## Connections

The brick provides two interfaces and consumes none through the
topology (`interfaces.consumes: []`): what it scrapes is the seed file's
business, by node name and port. Container ports 9090 and 22; nothing is
published (only the bastion publishes ports), so both are reachable only
from nodes sharing a network with it, by its node name.

- **`ui`, HTTP, port 9090, web path `/prometheus/`.** Prometheus' UI and
  HTTP API. The other side is the bastion's web front: route
  `prometheus` in the bastion's `web_routes` parameter
  (`prometheus: "<node>:9090"`), which the front serves at `/prometheus/`
  and forwards with the path unchanged; Prometheus serves under that
  sub-path itself (`--web.external-url=/prometheus/`,
  `--web.route-prefix=/prometheus/`), so the route name must be
  `prometheus`. Nothing is served outside the sub-path (404), except a
  redirect from `/` to it. Prometheus has no login of its own; the front
  asks for the tools password. Grafana's data source uses
  `http://<node>:9090/prometheus`. From inside the game network any node
  reaches it directly (access model, `through-web-front`).
- **`ssh`, SSH protocol, port 22.** The other side is the bastion's inner
  hop (`ssh <node>`), as `player`, by public key only: the node's
  `player_ssh_pubkey` is the public half of the bastion's `player_ssh_key`,
  a key pair `gmctl deploy` generates per game. The node's host key is
  created anew at each container start; how the bastion copes with that
  is in the bastion brick's
  [GM notes](../../bastion/docs/gm.md#inner-hop-and-host-keys).

**Node-health endpoints**: every node of the game, this one included,
serves its node-health metrics on port 9110 (HTTP, `/metrics`), readable
from every node, the bastion included (access model, node-health
endpoint `read`). Prometheus scrapes them from the seed file's targets.
Nothing else needs wiring: the script and its config come with the
deployment.

**Scrape targets**: whatever the seed file lists. Nothing has to exist
first: a target that does not answer shows as down (`up == 0`), which is
a finding, not a deployment failure.

**Monitoring**: Prometheus exposes its own metrics at
`/prometheus/metrics`; the seed file decides whether it scrapes them.

**Mounted material**: the image accepts another brick's mounted companion
material (`brick.yaml` `receives`): it runs s6-overlay `3.2.3.2`, and the
commands `sh`, `cat`, `du`, `df`, `awk`, `sed`, `grep`, `sleep`, `perl`,
`s6-svstat` and `s6-setuidgid` are on an s6 service's PATH.

The GM's own operations (validator, sealed checks, injection) do not use
these interfaces: they run inside the container through `gmctl exec`.

## Access

### Accounts and access

- `player`: SSH by public key only (`AuthorizedKeysFile` points at the
  secret; no password, no PAM), member of `promconf`. No TCP, agent or
  X11 forwarding.
- `prometheus`: runs the server and owns the TSDB; no login.
- `sudo`: `player` may run the two wrappers as root, with no arguments
  (`/etc/sudoers.d/gm-player`): `env_reset`, fixed `secure_path`, no
  syslog, log in `/run/gm/sudo.log`.

**Web interface**: Prometheus' UI through the bastion's web front at
`/prometheus/`, with the tools password (see "Connections"). The admin
and lifecycle HTTP endpoints are disabled: `POST /prometheus/-/reload`
and `PUT /prometheus/-/quit` answer 403 ("Lifecycle API is not
enabled."), `/prometheus/api/v1/admin/...` answers 500 ("admin APIs
disabled"). Reloads go through the `sudo` wrapper, under the write
policy.

### Writable and protected paths, write policies

- Writable by the player: `/etc/prometheus` (`prometheus:promconf`,
  `2775`; the seeded `prometheus.yml` `0664`), `/home/player`, and the
  scratch space `/tmp` and `/var/tmp`, both links to `/run/tmp` (root,
  `1777`, emptied at each start, see "Start-up").
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the entrypoint, the two
  wrappers, the health check, the validator, the s6-overlay service
  definitions (`/etc/s6-overlay/s6-rc.d`, `/etc/s6-overlay/user-bundles.d`)
  and the seed marker's directory `/var/lib/gm-state`. The TSDB is not
  readable by the player.
- The node-health script's files and its per-node config, on every
  node that receives them: root-owned, read-only (no write bit, and
  read-only mounts). Players can read the service list
  (`/opt/gm/node-health/node.conf`) and the endpoint, and can report a
  wrong list or propose a fix, but not make it: an edit gets an ordinary
  "permission denied".
- Write policies: `fixable` only (see "Known limits").

### Wrappers

- `gm-reload-prometheus`: runs `promtool check config` on
  `/etc/prometheus/prometheus.yml` as `prometheus` and refuses (exit 1,
  "NOT reloaded") if it fails. Otherwise sends SIGHUP through s6
  (`s6-svc -h`), waits for Prometheus to record a new successful load
  (`prometheus_config_last_reload_success_timestamp_seconds`), and prints
  the retention in effect. Exit 1 if Prometheus refuses the file
  (it keeps the previous configuration). If Prometheus is not running (a
  file that did not load when the container started), s6 keeps restarting
  it, and the wrapper waits up to 30 s for it to come back with the
  checked file.
- `gm-validate`: runs the validator as `prometheus`, exit code passed
  through.

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, the `postgres` brick's
list for the same reasons: the entrypoint needs `CHOWN`, `DAC_OVERRIDE`,
`FOWNER`, `SETGID` and `SETUID`; SSH logins need `SYS_CHROOT` (privilege
separation); `sudo` needs `AUDIT_WRITE` to stay quiet; s6 needs `KILL` to
send the reload's SIGHUP to the `prometheus`-owned server;
`NET_BIND_SERVICE` is for sshd's port 22 on platforms other than Docker.
`no-new-privileges` is off: `sudo` is setuid. Not re-checked by dropping
each one in turn for this brick (it was for `postgres`).

### What the GM uses

`gmctl exec --node <node> --user prometheus` (or `--user root`) for
`promtool` and `curl http://127.0.0.1:9090/prometheus/api/v1/...`; `gmctl
validate` runs the validator as `prometheus`; `gmctl logs --node <node>`
shows Prometheus' log.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `0.495` and memory `378M`; reservations CPU
`0.095`, memory `154M` and disk `512M`. These are master spec 12's
figures for a Prometheus node (limits 0.5 / 384M, reservations 0.1 /
160M, 512M of volumes), which include the node-health script, less the script's own
cost (below), since a brick's footprint excludes mounted material. The
scenario sets each node's own `resources`, and `gmctl` uses those, never
the brick's footprint; disk is only counted by the capacity check.
Disk growth per hour (`disk_growth_per_hour`): `4M`, a provisional
estimate, to be replaced by v0.3 chunk 15b's measurement.

Measured in the v0.2 game (`fernway-clinics-monitoring` on the `laptop`
playground, declared at 2 CPU / 4G / 8G on armenelos: AMD Ryzen 5 PRO
8640HS, 11.3 GiB, Docker 29.9.1; 2026-10-21; `docker stats`, the highest
of its samples; the node-health script included; six scrape targets
every 15 s, fault f1 leaving grafana's out; about 35 minutes of
samples), under a 384M limit: at rest 11 to 15 minutes after the
deployment 56M and 0.03 CPU; during dashboard
loads (Grafana's panel queries) 66M and 0.07 CPU; during a pgBadger run on
`db` 60M; at rest again after them 64M. Never OOM-killed nor restarted,
never at its limit (`memory.peak`, page cache included, 85M). The TSDB
volume held 0.9M after 35 minutes. The figures stay well within the
reservation (master spec 12 estimated 80M to 150M at rest); in its stack
test the node used about 40M without the node-health script and 52M with
it.

What makes it grow:

- **Memory**: the number of active series (targets times the series each
  exposes) and the scrape interval; queries over long ranges.
- **Disk**: the TSDB, bounded by the retention's time and size, plus the
  write-ahead log (about two hours of samples) on top of the size bound.
- **CPU**: scraping, compaction every two hours, and the players' queries.

Size the disk reservation from the retention size plus the write-ahead
log, and the memory from the series count. The levers that shrink it: a
shorter retention, a smaller size bound, a longer scrape interval, fewer
targets.

### What the node-health script adds to each node

`companion.mounted[node-health].footprint`, added by the GM to the
`resources` of **every node the map lists**, this one included: limits
CPU `0.005` and memory `6M`; reservations CPU `0.005`, memory `6M`, disk
`0`. The scenario's per-node `resources` include it; the bricks' own
footprints do not. It counts against each node's own limits, the nerfed
database's included.

Measured in the stack test (Docker 29.9.1): the sampler about 8.6M of
RSS, of which 1M private and 3.5M proportional (most of it Perl's code,
shared with the listener it forked); the listener about 7.6M of RSS,
mostly the same shared pages (its own memory maps are not readable once
it has dropped root). CPU: 20 ms over the first 36 s, start-up included,
well under 0.005 CPU. What makes it grow: more services (one `s6-svstat`
every 5 s each), and volumes with many files (`du` every 30 s). Disk: a
few hundred bytes in `/run`.

### Snapshot

How each volume is copied at hand-over (`snapshot:` in `brick.yaml`):

- `promdata`: `stop`. The brick's services other than `sshd` (here
  `prometheus`) are stopped through s6, never by a Swarm scale to zero,
  while the volume is copied, then started again: Prometheus is briefly
  down at hand-over (the health checks stay green; the players are told
  it is maintenance).
- `promconf`, `home`, `gmstate`: `copy`, a tar of the volume while the
  node runs.
- `run` (`/run`) is never copied.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59). This list is every catalog fault (`faults/`) whose `applies_to`
names `prometheus` `0.2.0`, and no other.

| Fault | Kind | What it needs from the brick |
|---|---|---|
| `prometheus-scrape-target-missing` | seed file | the seed `prometheus.yml` (material `inject/prometheus.yml.snippet`): the `node-health` job lists every node's `<node>:9110` but the parameter `node`'s, every other job (the exporter's `:9187`) kept; the left-out node still in the `node_health` map, so it serves its endpoint; `promtool` and `curl` for the sealed check |
| `prometheus-node-health-node-missing` | parameter | `node_health`, `remove-entry` on the parameter `node`'s entry: nothing mounted into that node; the seed `prometheus.yml` still lists its `:9110` target, so the target is down and "Scrape target down" fires; `curl` for the sealed check |
| `prometheus-node-health-service-missing` | parameter | `node_health`, `remove-from-entry` of the parameter `service` (the node's main service) from the parameter `node`'s entry, never its only item; `curl` for the sealed check |

The two node-health faults are *report* or *propose* only, never *fix*:
the script and its configuration are read-only on every node (D92). Each
names only this brick in `applies_to` and has a required parameter `node`,
the affected node. `prometheus-scrape-target-missing` is fixable on this
fixable node (edit the file, `sudo gm-reload-prometheus`). Every sealed
check runs as root on this node.

Faults it lends itself to with no definition yet (master spec 11.1's
candidates): retention shorter than the dashboards' or alerts' window (a
seed-file fault on `prometheus.yml`; not chosen for v0.2: Prometheus
holds the dashboards' hour in memory, so it shows in no session).

Known interactions: a scrape target left out hides that node from every
Grafana panel built on Prometheus, the node-health ones included, and no
target-down alert can fire for it, while the node still serves its
endpoint (readable with `curl <node>:9110/metrics` from this node; the
bastion has no `curl`). So `prometheus-scrape-target-missing` never goes
on the node of either node-health fault, and never removes the exporter's
target (which would hide `pg-stat-statements-not-preloaded`); placement
rules in each fault's `gm.md`. A retention change applies at the next
reload, and data already dropped does not come back.

Faults it cannot host: anything needing the admin or lifecycle HTTP API
(disabled), and alerting faults that need an Alertmanager (none in the
brick).

## Checks

### Validator

`/opt/gm/validator/validate.sh [config-file]`, run as `prometheus`. The
official run is `gmctl validate` (the GM's exec as `prometheus`). Rules:

| Rule | Red when |
|---|---|
| `config` | `promtool check config` refuses the file |
| `server` | Prometheus is not ready on port 9090 under `/prometheus/` (the next three rules are then not checked) |
| `reload` | the last load of the file failed (`reloadConfigSuccess` false): Prometheus runs an older configuration |
| `pending` | the file changed after Prometheus last loaded it (its mtime is later than `lastConfigTime`) |
| `retention` | the retention in effect is not bounded both by time and by size |

Output: `GREEN: ...` and exit 0; one `RED <rule>: ...` line per broken
rule and exit 1, for example

```
RED pending: /etc/prometheus/prometheus.yml changed at 2026-10-21T14:24:51Z, after Prometheus last loaded it (2026-10-21T14:24:40Z); run sudo gm-reload-prometheus
RED retention: in effect '12h'; it must be bounded both by time and by size (storage.tsdb.retention.time and .size in /etc/prometheus/prometheus.yml)
```

`ERROR: ...` and exit 2 when Prometheus is ready but its runtime
information is unreadable or unexpected. The validator never judges the
scrape targets: a missing target is a finding, not a broken game.

### Health check

Healthy while `sshd` is up, once Prometheus has been ready at least once
in this container (marker `/run/gm/prometheus-was-ready`). After that,
Prometheus being down does not make the container unhealthy, so Swarm
does not replace it and cut the players' SSH sessions.

### Companion checks

The node-health script has no validator of its own. After deployment,
on each node: the s6 service is up (`s6-svstat
/run/service/gm-node-health` as root), and `curl -s <node>:9110/metrics`
from this node lists the node's CPU, memory, disk and each service in its
list; in Prometheus, `up{job="<the node-health job>"}` is 1 for every
node's target, unless a planted fault says otherwise.

### After deployment

`gmctl deploy` returns once the node is healthy, which proves Prometheus
started with the seed file. `gmctl validate` shows the validator. The
wiring is confirmed from inside the node: every scrape target up, the
node-health endpoints included
(`curl -s http://127.0.0.1:9090/prometheus/api/v1/targets`, or
`promtool query instant http://127.0.0.1:9090/prometheus 'up == 0'`
returning nothing, unless a target down is a planted finding), and the UI
answering at `/prometheus/` through the bastion's web front.

### Stack test

`sh bricks/prometheus/tests/run-stack-test.sh` deploys the brick as a
stack (`tests/stack.test.yml`, fixtures in `tests/fixtures/`), checks the
chunk's Done-when and removes everything it created, volumes included.
It also runs a `postgres` 0.3.0 node `db`, mounts the node-health script
as configs into both nodes (per-node configs written by hand in
`tests/fixtures/node-health/`, in the renderer's format), and checks each
endpoint from the other node, a service stopped with `s6-svc -d`, the
scrape, and the files read-only for `player`. Needs a swarm manager, this
image and the `postgres` 0.3.0 image (the `db` node and the test client)
built.

## Known limits

- **Write policy**: only `fixable`. A `report-only` node would need the
  configuration directory not group-writable, decided at start from a
  value the renderer passes; not built.
- **Host key per container.** The sshd host key is generated at each
  container start. If the container is replaced, players see a changed
  host key on the inner hop.
- **No Alertmanager**: alerting rules, if a scenario adds any, show as
  firing in the UI only.
- **Retention size** bounds the TSDB's blocks, not the write-ahead log:
  the volume holds somewhat more than the size bound.
- **Node-health sampler as root**: on every node, a root process runs
  `s6-svstat`, `du` and `df` every few seconds; only the listener is
  unprivileged. The script reads only, writes only under
  `/run/gm-node-health`, and is read-only to players.
- **Node-health listener** serves one request at a time, each with a 5 s
  limit to send its headers; a slow client delays the others by up to
  that.
- **Node-health disk figures** are up to 30 s old, service status up to
  5 s (`node_health_sample_age_seconds`).
- **Image size**: about 490MB, mostly the two Go binaries (`prometheus`
  131M, `promtool` 109M), well above master spec 12's estimate of 150M for
  Prometheus.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
