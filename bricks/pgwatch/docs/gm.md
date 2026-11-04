# pgwatch brick — GM notes

GM documentation of the `pgwatch` brick (`brick.yaml`, v0.5 master spec
7.4, 7.5 and 14; the build conditions: G9, v0.5 wave log; the seed file
and the port: capture W2 item 5). Never shipped to players. Brick version
0.1.0, expected to evolve as games are played.

## Purpose

pgwatch 6.1.0 on Debian 13 (trixie), with an SSH server for the players,
in the image `127.0.0.1:5000/dbagm/pgwatch:0.1.0`. It fills the role
`monitoring`: one collector for every instance in the players' scope,
standing for the clinic's "monitoring tooling required in such complex
settings" (D340). It reads what `postgres` already provides through the
role `monitoring` (`pg_monitor`), keeps no store, and serves its readings
as Prometheus metrics, which v0.2's `prometheus` scrapes beside the
exporters and `grafana` 0.3.0 shows in its seeded pgwatch dashboard
(`pgwatch.json`).

The image:

- Debian 13 (`debian:13-slim`), `openssh-server`, `sudo`, `curl`, `nano`,
  `vim-tiny`, `less`, `procps`.
- pgwatch 6.1.0 (2026-10-26), its latest release at the build (spec
  D368): the release tarball `pgwatch_Linux_x86_64.tar.gz`, verified by
  SHA-256 at build (G9's digest, which agrees with `checksums.txt`), the
  binary only, in `/usr/local/bin/pgwatch` (static, go1.26.9). Its metric
  definitions and presets are built in; the tarball's sample files,
  `metrics.yaml` and dashboards are not installed. The build asserts the
  banner's `Version: 6.1.0`, and that the `basic` preset has no init SQL
  (`pgwatch metric print-init basic` prints none, `standard` does).
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content, no credential and no host keys in the
  image.
- Size: 167MB (about 88MB over the shared `debian:13-slim` layer, 24MB of
  it the pgwatch binary).

## Placement

- **What gets installed**: a node of its own, `pgwatch` in the clinic,
  from the brick's image. The image must be on the engine that runs the
  game: deployment never pulls it.
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/pgwatch:0.1.0 bricks/pgwatch`.
- **How many**: one per game: it watches every source its seed file lists
  (`records`, the standby, `lab`, `machines` in the clinic; never the
  partners' database).
- **Next to which node**: any host; armenelos in the clinic, beside
  Prometheus (master spec 14).
- **What it needs**: every source a `postgres` 0.5.0 node choosing the
  option `monitoring` (a standby's primary choosing it: the role is the
  primary's, cloned), which creates the role `monitoring` (`pg_monitor`)
  with the password of the game's secret `monitoring_password`; `gmctl`
  refuses a pgwatch node targeting a node without the option, unless a
  fault plants that gap (master spec 7.1; capture W2 item 1). Each
  source's `pg_hba.conf` lets `monitoring` in from this node
  (`scram-sha-256`; `hostssl` where the seed demands TLS: libpq's default
  `sslmode=prefer` uses it). Prometheus' seed `prometheus.yml` gains the
  job `pgwatch`, target `<this node>:9188`; the node-health job lists it
  on 9110 like every node (7.5).
- **Stateful**: yes. Its volumes `pwconf`, `home`, `gmstate` and `run`
  must follow the node if it is replaced. It keeps no data of its own:
  every fetch asks the database, and Prometheus keeps the history.
- **Networks**: it shares the game's one network with the bastion, the
  databases and Prometheus.

## Configuration

`brick.yaml` declares no parameter and no knobs: the sources and their
presets are in the seed file, where a fault or a fix can live and players
can read them.

### What the seed file must contain

`sources.yaml`, pgwatch 6.1.0's YAML sources format: a YAML **list** at
the top (not a map), one entry per watched instance:

```yaml
- name: records                                      # the label dbname of every series
  conn_str: postgresql://monitoring@records:5432/postgres
  kind: postgres
  preset_metrics: basic                              # no helper function needed (G9)
  is_enabled: true                                   # required: pgwatch skips an entry without it
```

- `conn_str` in the URI form, with a host and the user `monitoring`, never
  a password (capture W2 item 5; the brick checks the URI form and one
  host on every enabled entry, and `gmctl` reads each enabled entry's
  host as a monitoring target).
- `is_enabled: true` on every entry to watch: pgwatch's default is
  disabled, so an entry without it is not watched (a quiet fault surface).
- `preset_metrics: basic`: `instance_up`, `db_size` (every 5 min),
  `db_stats`, `wal` (every minute). It needs no helper function and only
  `pg_monitor`. A preset with init SQL (`standard`, `exhaustive`) is not
  refused, but its helper metrics fail: pgwatch is never run with
  `--create-helpers` or `--try-create-listed-exts-if-missing` (G9).
- pgwatch ignores unknown keys silently.

### Fixed paths

| What | Path | Notes |
|---|---|---|
| Sources | `/etc/pgwatch/sources.yaml` | volume `pwconf`; `pgwatch:pwconf` 0664 (0644 report-only), the directory 2775 (2755) |
| Seed | `/opt/gm/seed/sources.yaml` | read once, at the first start |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`, root 0444 |
| Password file | `/run/gm-pgwatch/pgpass` | `*:*:*:monitoring:<password>`, `pgwatch` 0600, rewritten at every service start from the secret; libpq's `PGPASSFILE` |
| Emergency pause file | `/run/gm-pgwatch/emergency-pause` | pgwatch's `--emergency-pause-triggerfile`; the directory is `root:pgwatch` 0750, so neither player nor pgwatch can create it (pgwatch's default, under `/tmp`, is world-writable) |
| Player home | `/home/player` | volume `home` |

### Start-up

`gm-entrypoint` (every container start, as root) empties `/run` (a named
volume), writes the sshd host key, checks the secrets (the monitoring
password one non-empty line), checks `GM_WRITE_POLICY` and
`GM_WRITE_OVERRIDES` and writes `/run/gm/write-policy`, seeds
`/etc/pgwatch` once, applies the write policy's owner and modes, then
execs s6-overlay, which supervises `pgwatch` and `sshd`.

The s6 service `pgwatch` runs `pgwatch-sources run` as root:

1. checks `sources.yaml` (pgwatch's own parsing, `pgwatch source
   resolve`, as `pgwatch`; at least one enabled entry; each a
   `postgresql://` URI with one host); a file that is not valid leaves
   the service down (exit 3, a line in the log every few seconds);
2. writes the password file from the secret (`:` and `\` escaped);
3. **waits, bounded**, up to 30 s, for every enabled source's host to
   resolve (`getent ahosts`; the pgbouncer lesson, v0.4 D305; spec D356),
   and logs `pgwatch-run: waiting up to 30s ...` then either `... resolve
   after Ns` or `still not resolving after 30s: <hosts>; pgwatch starts
   anyway`. A health-checked `postgres` node enters Swarm's DNS only once
   healthy (about 49 s fresh): pgwatch then starts at the bound and its
   fetch fails honestly (`pgwatch_instance_up 0`, an error logged) until
   the name resolves;
4. execs pgwatch as `pgwatch` in a clean environment (`PATH`, `HOME`,
   `PGPASSFILE` only: no `PW_*` variable): `--sources=/etc/pgwatch/sources.yaml
   --refresh=60 --sink=prometheus://0.0.0.0:9188 --web-disable=all
   --emergency-pause-triggerfile=/run/gm-pgwatch/emergency-pause`.

pgwatch rereads the sources every 60 s (`--refresh`): a source that did
not resolve at start is reached at the next refresh after it does
(measured 52 s after the database became healthy in the stack test), and
a player's edit applies within a minute. A file made invalid while
pgwatch runs is logged ("using last valid cache") and pgwatch keeps the
sources it had.

## Connections

- **Out**: PostgreSQL 5432 to every enabled source, as `monitoring`,
  libpq's defaults (`sslmode=prefer`: TLS where the server offers it).
  One connection pool per source, at most 4 parallel fetches
  (pgwatch's default).
- **In**: HTTP 9188 `/metrics` from Prometheus (job `pgwatch`), on the
  game network only, never published or routed by the bastion; SSH 22
  from the bastion. Nothing listens on 8080: the web interface and REST
  API are off (G9).
- **Series**: `pgwatch_<metric>_<column>{dbname="<source>"}` with an
  explicit sample timestamp (the fetch time), plus Go runtime series;
  the `basic` preset gives about 39 `pgwatch_` series per source
  (`pgwatch_instance_up`, `pgwatch_db_size_size_b`,
  `pgwatch_db_stats_numbackends`, `pgwatch_db_stats_xact_commit`,
  `pgwatch_wal_xlog_location_b`, ...).

## Access

### Accounts and access

- `pgwatch` (990:990): runs pgwatch; with root, the only account reading
  the monitoring password (the secret, mounted `0:990` 0440, and the
  password file).
- `player`: SSH by key only (`player_ssh_pubkey`), in the group `pwconf`
  (991), which owns the sources file with `pgwatch`; never in `pgwatch`'s
  group. Service credentials are not readable by the players (access
  model 5): the stack test asserts player cannot read the secret or the
  password file.

### Writable and protected paths, write policies

`fixable` (default): `/etc/pgwatch` 2775, `sources.yaml` 0664;
`report-only`: 2755 and 0644, and `gm-restart-pgwatch` refuses with one
line (`gm-restart-pgwatch: this node is report-only: its files cannot be
changed, so nothing was reloaded.`), nothing restarted; `gm-validate` is
never refused. `GM_WRITE_OVERRIDES` may name `/etc/pgwatch` or
`/home/player`. The protected files are `brick.yaml`'s list, root-owned,
on a read-only root.

### Wrappers

- `sudo gm-restart-pgwatch`: restores the file's owner and mode, refuses
  a file that is not valid (the running pgwatch left alone), restarts
  pgwatch through s6 and waits up to 60 s for every source's first fetch,
  printing `<source>: pgwatch_instance_up 1: reached.` or `0: NOT
  reached`.
- `sudo gm-validate`: the validator, as `pgwatch`.

### Capabilities

As the exporter's: `cap_drop: ALL`, then `AUDIT_WRITE`, `CHOWN`,
`DAC_OVERRIDE`, `FOWNER`, `KILL`, `NET_BIND_SERVICE`, `SETGID`, `SETUID`,
`SYS_CHROOT`.

### What the GM uses

`docker exec` (as root, or `-u pgwatch` for the validator), the metrics
endpoint from any node, and Prometheus' `pgwatch` job.

## Footprint

Default footprint in `brick.yaml`: limits CPU `0.245`, memory `122M`;
reservations CPU `0.095`, memory `90M`, disk `64M`: master spec 14's row
for the node (0.1 CPU, 96M, no volume beyond the small ones) less the
node-health script's own cost (0.005 CPU, 6M). The scenario's `resources`
take the full row. Disk growth per hour `1M` (the players' notes: pgwatch
writes nothing).

Measured in the stack test (armenelos, AMD Ryzen 5 PRO 8640HS, Docker
29.9.1, 2026-11-04; one source, the `basic` preset, PostgreSQL 18.6,
without the node-health script), at rest about a minute after a restart:
the container 12M of memory (`docker stats`), `memory.peak` 21M since its
start, pgwatch's RSS 27M, CPU 0.00 over the sample; far under the 128M
limit and the 90M reservation, which keep master spec 14's starting row
until the clinic's measurements (fit at the release gate) replace it.

What makes it grow: the number of sources and the preset (each metric's
interval is a query on the source); Prometheus' own series grow by about
39 per source.

### Snapshot

`pwconf`, `home`, `gmstate`: `copy`, a tar while the node runs (pgwatch
keeps no data). `run` is never copied.

## Supported faults

None in v0.5's catalogue. Its sources are fault surface a later game's GM
may pick (master spec 7.4): a source disabled or missing, a preset that
needs helpers, a wrong host.

## Checks

### Validator

`/opt/gm/validator/validate.sh`, as `pgwatch` (`sudo gm-validate` for
players). Rules: `config` (the file is valid for pgwatch, one enabled
source at least, each a `postgresql://` URI with one host), `server` (the
sink answers on 9188), `web` (nothing answers on 8080). pgwatch rereads
the file, so there is no `pending` rule. Output `GREEN: ...` (0), `RED
<rule>: ...` (1), `ERROR: ...` (2).

### Health check

Healthy once the sink has answered once in the container and while sshd
is up; never asks a database (start period 60 s, the bounded wait
included).

### After deployment

`curl -s http://<node>:9188/metrics | grep pgwatch_instance_up` from any
node: 1 for each source once its name resolves; Prometheus' target
`pgwatch` up; Grafana's pgwatch dashboard showing the series.

### Stack test

`sh bricks/pgwatch/tests/run-stack-test.sh` (needs the images
`pgwatch:0.1.0` and `postgres:0.5.0`): pgwatch started before its source
(the wait, its bound, the honest failure, the source reached once it
resolves), the basic preset's series, `--web-disable=all` and nothing on
8080, nothing created in the database, the password's places, SSH and
sudo, the validator and the wrapper (a broken file, no enabled source, a
second source applied by the refresh and by the wrapper), a file not
valid at start, persistence, the snapshot, the footprint, report-only and
the entrypoint's refusals.

## Known limits

- The sink serves the last fetch with its own timestamp; a source pgwatch
  no longer reaches keeps its last series until pgwatch restarts, with
  `pgwatch_instance_up 0` beside them.
- `pgwatch source resolve` is the brick's parser, and it lists every
  source, enabled or not; the brick reads `is_enabled` itself, line by
  line, in YAML's block form or a one-line flow map (`- {name: ..., ...}`),
  the forms the seed and the docs use. pgwatch accepts unknown keys; no
  enabled entry is the brick's own refusal.
- The daily dependency sweep does not see the Go modules inside the
  binary (G9's note to the owner): they reach `.tech` only through a
  dependency check.
- If CPU is short, pgwatch is the first trim (master spec 7.4, 14).
