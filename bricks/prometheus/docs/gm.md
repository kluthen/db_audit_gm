# Prometheus brick — GM notes

GM documentation of the `prometheus` brick (`brick.yaml`, v0.2 master
spec 7 and 7.2; required sections: v0.2 master spec 6.2). Never shipped
to players. Brick version 0.1.0, expected to evolve as games are played.

## Purpose

Prometheus 3.13.5 on Debian 13 (trixie), with an SSH server for the
players, in the image `127.0.0.1:5000/dbagm/prometheus:0.1.0`. It fills
the role `metrics-store`: the node that scrapes and keeps the game's
metrics, which the players audit as the customer's monitoring and read
through its UI, and which a Grafana node queries. The GM picks it for
every scenario with monitoring; one per scenario.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server`, `sudo`, `curl`, `nano`,
  `vim-tiny`, `less`, `procps`.
- Prometheus 3.13.5 (`prometheus` and `promtool`, linux-amd64) from the
  upstream release archive, verified by SHA-256 at build against the
  release's `sha256sums.txt`.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/prometheus:0.1.0 bricks/prometheus`.
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

`brick.yaml` declares no parameters (`parameters: {}`) and no knobs
(`knobs: []`): the scrape targets and the retention are in the seed file.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Seed file `prometheus.yml` (`seed.files`) | `/opt/gm/seed/prometheus.yml`, root `0444`, copied into `/etc/prometheus/` at first start | the scenario's `seed_files` (`nodes/<node>/prometheus.yml`) |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |

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
  `2775`; the seeded `prometheus.yml` `0664`) and `/home/player`.
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the entrypoint, the two
  wrappers, the health check, the validator, the s6-overlay service
  definitions (`/etc/s6-overlay/s6-rc.d`, `/etc/s6-overlay/user-bundles.d`)
  and the seed marker's directory `/var/lib/gm-state`. The TSDB is not
  readable by the player.
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
`resources`: limits CPU `0.495` and memory `379M`; reservations CPU
`0.095`, memory `155M` and disk `512M`. That is master spec 12's estimate
for a Prometheus node (limits 0.5 / 384M, reservations 0.1 / 160M, 512M of
volumes), which includes the node-health script, less the script's own
cost, since a brick's footprint excludes mounted material. An estimate,
not a measurement: at rest, in its stack test, the node used about 40M of
memory. The scenario sets each node's own `resources`, and `gmctl` uses
those, never the brick's footprint; disk is only counted by the capacity
check.

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

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59). No catalog fault (`faults/`) names `prometheus` `0.1.0` yet, so it
supports none.

Faults it lends itself to with no definition yet (master spec 11.1's
candidates): a node missing from the scrape targets, with no alert on a
target down; retention shorter than the dashboards' or alerts' window
(both seed-file faults on `prometheus.yml`).

Known interactions: a scrape target left out hides that node from every
Grafana panel built on Prometheus; a retention change applies at the next
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

None: the brick ships no `companion/` material.

### After deployment

`gmctl deploy` returns once the node is healthy, which proves Prometheus
started with the seed file. `gmctl validate` shows the validator. The
wiring is confirmed from inside the node: every scrape target up
(`curl -s http://127.0.0.1:9090/prometheus/api/v1/targets`, or
`promtool query instant http://127.0.0.1:9090/prometheus 'up == 0'`
returning nothing, unless a target down is a planted finding), and the UI
answering at `/prometheus/` through the bastion's web front.

### Stack test

`sh bricks/prometheus/tests/run-stack-test.sh` deploys the brick as a
stack (`tests/stack.test.yml`, fixtures in `tests/fixtures/`), checks the
chunk's Done-when and removes everything it created, volumes included.
Needs a swarm manager, this image and the `postgres` 0.2.0 image (the
test client) built.

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
- **Image size**: about 490MB, mostly the two Go binaries (`prometheus`
  131M, `promtool` 109M), well above master spec 12's estimate of 150M for
  Prometheus.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
