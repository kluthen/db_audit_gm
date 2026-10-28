# postgres-exporter brick — GM notes

GM documentation of the `postgres-exporter` brick (`brick.yaml`, v0.2
master spec 7 and 7.3; required sections: v0.2 master spec 6.2). Never
shipped to players. Brick version 0.2.0, expected to evolve as games are
played.

## Purpose

`postgres_exporter` 0.20.1 on Debian 13 (trixie), with an SSH server for
the players, in the image `127.0.0.1:5000/dbagm/postgres-exporter:0.2.0`.
It fills the role `monitoring`: the node that reads PostgreSQL's
statistics with a monitoring role and serves them as Prometheus metrics
(`pg_up`, the default collectors' metrics, and the query statistics of
`pg_stat_statements` when the scenario asks for them), which a
`prometheus` node scrapes and the players audit as part of the customer's
monitoring. The GM picks it for every scenario that monitors a
`postgres` database; one per watched database.

The image:

- Debian 13 (`debian:13-slim`), `openssh-server`, `sudo`, `curl`, `jq`,
  `nano`, `vim-tiny`, `less`, `procps`.
- `postgres_exporter` 0.20.1 (linux-amd64) from the upstream release
  archive, verified by SHA-256 at build against the release's
  `sha256sums.txt`. It supports PostgreSQL 18 (the `pg_stat_statements`
  query for PostgreSQL 17 and later) and `--collector.stat_statements`.
  The build records the collectors it offers in
  `/usr/local/lib/gm/exporter-collectors`.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content, no credential and no host keys in the
  image.
- Size: 165MB (about 86MB over the shared `debian:13-slim` layer).

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter`.
- **How many**: one per watched database; it watches the one database
  its seed file names.
- **Next to which node**: any host; it reaches the database by node name
  over the game's network, and Prometheus reaches it the same way.
- **What it needs**: a `postgres` 0.3.0 node (or later) in the same game:
  that brick creates the role `monitoring` (member of `pg_monitor`) when
  it initialises its cluster, with the password from the same secret,
  `monitoring_password`. A cluster initialised by an older image has no
  such role. The database's seed `pg_hba.conf` must let `monitoring` in
  from this node with `scram-sha-256` (for example `host postgres
  monitoring 0.0.0.0/0 scram-sha-256`), and its seed `postgresql.conf`
  needs `shared_preload_libraries = 'pg_stat_statements'` for the query
  statistics.
- **Stateful**: yes (`stateful: true`). Its volumes `expconf`, `home`,
  `gmstate` and `run` (see "Configuration") must follow the node if it is
  replaced; otherwise the players' changes and the seed marker are lost.
  It keeps no data of its own: every scrape asks the database.
- **Networks**: it must share a network with the bastion (the players'
  way in), the database and the `prometheus` node. The renderer runs the
  whole game on one network.

## Configuration

`brick.yaml` declares no parameter (`parameters: {}`) and no knobs
(`knobs: []`): the database's address, the user and the extra collectors
are in the seed file, where a fault or a fix can live and players can
read them.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Seed file `exporter.conf` (`seed.files`) | `/opt/gm/seed/exporter.conf`, root `0444`, copied into `/etc/postgres-exporter/` at first start | the scenario's `seed_files` (`nodes/<node>/exporter.conf`) |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |
| Secret `monitoring_password` (kind `password`, not handed over) | `/opt/gm/secrets/monitoring_password`, uid 0, gid 990 (`exporter`), `0440` | `gmctl deploy`: 32 characters; the same secret the `postgres` node mounts |

### What the seed file must contain

`exporter.conf`: UTF-8, one `KEY=value` per line. Blank lines and lines
starting with `#` are ignored, and so is whitespace followed by `#` to the
end of a line. It is parsed, never sourced: values are taken as written,
with no quotes and no expansion.

```
DATA_SOURCE_URI=db:5432/postgres?sslmode=disable
DATA_SOURCE_USER=monitoring
COLLECTORS=--collector.stat_statements
```

| Key | Required | Value |
|---|---|---|
| `DATA_SOURCE_URI` | yes | `<db node>:5432/postgres?sslmode=disable`: host, port, database, options, without user or password. `sslmode=disable` because `postgres` 0.3.0 runs without SSL. |
| `DATA_SOURCE_USER` | yes | `monitoring`, the role `postgres` 0.3.0 creates. |
| `COLLECTORS` | no | space-separated `--collector.<name>` and `--no-collector.<name>` words, `<name>` one of the release's collectors (`/usr/local/lib/gm/exporter-collectors`). `--collector.stat_statements` turns the query statistics on; it is off by default. Absent or empty: the default collectors. |

The file is not valid, and the service does not start, when it has an
unknown key, a key set twice, a required key missing or empty, a value
holding a space, a quote or one of `` \ ` $ ; ``, or a `COLLECTORS` word
outside the two forms or naming no collector; or when it is missing, not
a regular file, or a symbolic link. The validator's `config` rule says
which line. Its messages give line numbers and key names, never values.

Not in the file: the password (the secret, see "Access"), the listening
address `:9187` and the path `/metrics` (fixed in the s6 service), the
exporter's other flags and environment variables (`PG_EXPORTER_*`), and
`--config.file` (a protected file with no auth module, so `/probe` holds
no credential).

A wrong address, a wrong user or a database that refuses the role is not
a broken file: the exporter runs and reports `pg_up 0`. It is a fault the
seed file can plant, and a finding for the players.

### Fixed paths

| What | Path | Notes |
|---|---|---|
| Seed directory | `/opt/gm/seed/` | config `exporter.conf`, read-only |
| Configuration | `/etc/postgres-exporter/` | volume `expconf`; `exporter:expconf`, dir `2775` and seeded file `0664` when fixable, `2755` and `0644` otherwise (see "Access") |
| Write policy | `/run/gm/write-policy` | root `0444` in the root-only `/run/gm`; written at each start from `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES` |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`; dir root `0755`, marker root `0444`; present means never seed again |
| Player home | `/home/player` | volume `home` |
| Runtime | `/run` | volume `run`, emptied at each start (see below) |
| Secrets | `/opt/gm/secrets/player_ssh_pubkey`, `/opt/gm/secrets/monitoring_password` | |
| What the service last read | `/run/postgres-exporter/loaded` | root `0644` in a root:exporter `0750` directory: the modification time of the `exporter.conf` it started with, and when |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-restart-exporter`, `gm-validate` | |
| Write-policy helper | `/usr/local/sbin/gm-write-policy` | run as root by the entrypoint and `gm-restart-exporter`; not a `sudo` wrapper |
| File reader | `/usr/local/lib/gm/exporter-conf` | `check` (validator, wrapper) and `run` (the s6 service) |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/sshd`, `/run/sshd-keys`, `/run/gm`,
   `/run/tmp` (`/tmp` and `/var/tmp` are symlinks to it) and
   `/run/postgres-exporter`.
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if `player_ssh_pubkey` is missing or empty, or if
   `monitoring_password` is missing, empty or more than one line (as the
   `postgres` brick does with the same secret).
4. Reads the write policy from `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES`
   (both unset or empty: `fixable`, no override) and writes
   `/run/gm/write-policy`. An unknown policy, or an override that is not
   one of `writable_paths`, fails the container with one line
   (`gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of
   fixable, report-only, no-access`, `gm-entrypoint: fatal:
   GM_WRITE_OVERRIDES: '<path>' is not one of this brick's writable_paths
   (/etc/postgres-exporter, /home/player)`).
5. If `/var/lib/gm-state/.gm-seeded` is absent: copies `exporter.conf`
   into `/etc/postgres-exporter/` and writes the marker. A missing seed
   file fails the container. Never overwrites afterwards. The marker is on
   its own root-owned volume, out of reach of `player` and `exporter`.
6. Applies the write policy's owner and modes to `exporter.conf` and
   `/etc/postgres-exporter` (see "Access"), seeding or not, contents
   untouched; logs `write policy: policy=... overrides=...`.
7. Sets the ownership of the player's home.
8. Execs s6-overlay's `/init`, which supervises `postgres-exporter` and
   `sshd`.

The s6 service `postgres-exporter` runs `exporter-conf run` as root: it
reads `exporter.conf`; if the file is not valid it logs
`postgres-exporter: NOT started: <problem>` and exits 3, and its `finish`
script keeps the service down 4 s before s6 tries again (one log line
every 5 s, not every second). Otherwise it records the file's
modification time in `/run/postgres-exporter/loaded`, logs the address,
user and collectors it starts with (never the password), and execs, as
`exporter`, with a clean environment:

```
DATA_SOURCE_URI=<from the file> DATA_SOURCE_USER=<from the file> \
DATA_SOURCE_PASS_FILE=/opt/gm/secrets/monitoring_password \
postgres_exporter --web.listen-address=:9187 --web.telemetry-path=/metrics \
  --config.file=/usr/local/lib/gm/postgres_exporter.yml <COLLECTORS>
```

`postgres_exporter` reads the password from the file at start, trimmed
of surrounding whitespace. Its log goes to the container's output
(`gmctl logs`); players do not see it. `/run` is a named volume for the
reason the `postgres` brick's
[GM notes](../../postgres/docs/gm.md#why-run-is-a-volume) give.

## Connections

Container ports 9187 and 22; nothing is published (only the bastion
publishes ports), so both are reachable only from nodes sharing a network
with it, by its node name.

- **`metrics`, HTTP, port 9187.** `GET /metrics`, Prometheus' text
  format; no `web_path`: never routed through the web front. The other
  side is the `prometheus` node, through its seed file's scrape targets
  (`- {job_name: postgres, static_configs: [{targets: ['<node>:9187']}]}`).
  Every scrape runs the collectors' queries against the database. `GET /`
  is a landing page that asks nothing of the database (the health check
  and the validator use it). No login: anything on the game's network
  reads the metrics (access model, monitoring interfaces).
- **`ssh`, SSH protocol, port 22.** The other side is the bastion's inner
  hop (`ssh <node>`), as `player`, by public key only: the node's
  `player_ssh_pubkey` is the public half of the bastion's
  `player_ssh_key`, a key pair `gmctl deploy` generates per game. The
  node's host key is created anew at each container start; how the
  bastion copes with that is in the bastion brick's
  [GM notes](../../bastion/docs/gm.md#inner-hop-and-host-keys).
- **Consumes `sql`, PostgreSQL, port 5432.** The database named in
  `exporter.conf` (`interfaces.consumes`), over TCP, database `postgres`,
  role `monitoring`, `scram-sha-256` through the database's `pg_hba.conf`
  `host` line. Nothing has to exist first: a database that does not
  answer shows as `pg_up 0`, a finding, not a deployment failure; the
  exporter reconnects on the next scrape once it answers.

**Metrics other bricks and scenarios rely on** (names confirmed in the
stack test against `postgres` 0.2.0, PostgreSQL 18.6):

| Metric | Meaning |
|---|---|
| `pg_up` | 1 when the last scrape reached the database, 0 when it did not |
| `pg_stat_statements_calls_total`, `pg_stat_statements_seconds_total`, `pg_stat_statements_rows_total` | per statement (`queryid`, `datname`, `user` labels), the top 100 by time; only with `--collector.stat_statements` and the database's preload |
| `pg_scrape_collector_success{collector=…}` | 1 per collector that succeeded on the last scrape; all default collectors succeed on PostgreSQL 18 |

The default collectors in 0.20.1: `database`, `locks`, `replication`,
`replication_slots`, `roles`, `settings`, `stat_activity`,
`stat_archiver`, `stat_bgwriter`, `stat_database`,
`stat_progress_vacuum`, `stat_replication`, `stat_user_tables`,
`statio_user_tables`, `wal`. The exporter also serves its own process and
Go metrics.

**Mounted material**: the image accepts another brick's mounted companion
material (`brick.yaml` `receives`): it runs s6-overlay `3.2.3.2`, and the
commands `sh`, `cat`, `du`, `df`, `awk`, `sed`, `grep`, `sleep`, `perl`,
`s6-svstat` and `s6-setuidgid` are on an s6 service's PATH (the
Dockerfile checks each with `command -v`). The `prometheus` brick's
node-health script is mounted this way; its `default` entry for this node
reports the services `postgres-exporter` and `sshd`.

The GM's own operations (validator, sealed checks, injection) do not use
these interfaces: they run inside the container through `gmctl exec`.

## Access

### Accounts and access

- `player`: SSH by public key only (`AuthorizedKeysFile` points at the
  secret; no password, no PAM), member of `expconf` (gid 991). No TCP,
  agent or X11 forwarding. `curl` and `jq` are installed.
- `exporter` (uid 990, gid 990): runs the server; no login, no home. The
  Dockerfile fails the build if the ids differ, as `brick.yaml` mounts
  the secret with gid 990.
- `sudo`: `player` may run the two wrappers as root, with no arguments
  (`/etc/sudoers.d/gm-player`): `env_reset`, fixed `secure_path`, no
  syslog, log in `/run/gm/sudo.log`.

**The monitoring password** (access model: monitoring role credentials
`read` allowed to the exporter's account only):

- The secret is root:exporter `0440`; `player` is not in the `exporter`
  group: reading it is an ordinary "permission denied".
- It reaches the server only as `DATA_SOURCE_PASS_FILE`, set by the s6
  service: never in `exporter.conf`, an argument, an environment
  variable holding the value, or the log. The server's environment is
  unreadable to `player` (and to root without `CAP_SYS_PTRACE`: the
  process dropped root).
- `exporter-conf`, the wrapper and the validator refuse an
  `exporter.conf` that is a symbolic link, and print line numbers and key
  names, never values, so a file pointed at the secret leaks nothing.
- `dba` on the database node can still read the database node's copy
  (`COPY … TO PROGRAM`), a risk the access model accepts.

### Writable and protected paths, write policies

- Writable by the player: `/etc/postgres-exporter` when it is fixable
  (below: `exporter:expconf`, `2775`; the seeded `exporter.conf`
  `0664`), `/home/player` under every policy, and the scratch space
  `/tmp` and `/var/tmp`, both links to `/run/tmp` (root, `1777`, emptied
  at each start, see "Start-up").
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the entrypoint, the two
  wrappers and their helper `gm-write-policy`, the health check, `exporter-conf`, the collector list,
  `postgres_exporter.yml`, the validator, the s6-overlay service
  definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`) and the seed marker's directory
  `/var/lib/gm-state`.
- **Write policies** (`write_policies`): `fixable` and `report-only`
  (v0.3 master spec 7.4), as on the `prometheus` brick. The renderer
  passes the node's policy as `GM_WRITE_POLICY` and its `write_overrides`
  as `GM_WRITE_OVERRIDES` (sorted, space-separated); `no-access` is read
  as `report-only` for the files. A path is *fixable* when the policy is
  `fixable`, or it is an override or lies under one. The only useful
  override here is `/etc/postgres-exporter` (`/home/player` is writable
  anyway):

  | | `/etc/postgres-exporter` | `exporter.conf` | `gm-restart-exporter` |
  |---|---|---|---|
  | `fixable`, or `report-only` with the override | `2775` | `0664` | restarts |
  | `report-only` | `2755` | `0644` | refuses |

  Owner `exporter:expconf` throughout. On a report-only node `player` (in
  `expconf`) can read the file but not change, replace or add anything
  there: an edit gets an ordinary "permission denied". The policy is set
  at each container start (entrypoint) and enforced again by the wrapper
  before every restart; it changes only with a new deployment.
- **Owner restored**: `sed -i` replaces the file with one owned by
  `player`. The entrypoint at every start, and `gm-restart-exporter`
  before it restarts, give `exporter.conf` and its directory their owner
  and mode back, contents untouched. Nothing is changed through a
  symbolic link or on a file with other hard links: such an entry is
  left alone and named (`left alone: ...`). Files players add in a
  fixable `/etc/postgres-exporter` stay as they made them; the exporter
  reads only `exporter.conf`.

### Wrappers

- `gm-restart-exporter`: first restores the owner and mode (above);
  then, when `exporter.conf` is not fixable (report-only, no override),
  prints one line and exits 1, restarting nothing:
  `gm-restart-exporter: this node is report-only: its files cannot be
  changed, so nothing was reloaded.` (exit 2 if the policy cannot be read
  or the owner not restored). `postgres_exporter` reads its settings only
  at start. The wrapper then checks `exporter.conf` as the s6 service does
  (`exporter-conf check`, as root) and refuses (exit 1, "NOT restarted",
  one line per problem) if it is not valid, leaving the running exporter
  alone. Otherwise it restarts the service through s6 (`s6-svc -r -u`:
  restarts it, or starts it if it was down), waits up to 30 s for a new
  `postgres_exporter` process to serve `/metrics`, and prints `pg_up`:
  `pg_up 1: connected to the database.` or `pg_up 0: NOT connected …`
  (exit 0 either way: the restart worked). Exit 1 if nothing answers
  within 30 s.
- `gm-validate`: runs the validator as `exporter`
  (`runuser -u exporter`), exit code passed through. Never refused,
  whatever the policy.

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, the `prometheus` brick's
list for the same reasons: the entrypoint needs `CHOWN`, `DAC_OVERRIDE`,
`FOWNER`, `SETGID` and `SETUID`; SSH logins need `SYS_CHROOT` (privilege
separation); `sudo` needs `AUDIT_WRITE` to stay quiet; s6 needs `KILL` to
restart the `exporter`-owned server; `NET_BIND_SERVICE` is for sshd's
port 22 on platforms other than Docker. `no-new-privileges` is off:
`sudo` is setuid. Not re-checked by dropping each one in turn for this
brick (it was for `postgres`).

### What the GM uses

`gmctl exec --node <node> --user exporter` (or `--user root`) for
`curl -s http://127.0.0.1:9187/metrics`; `gmctl validate` runs the
validator as `exporter`; `gmctl logs --node <node>` shows the exporter's
log, including why it did not start. Never put the password in `--env` or
on a command line: it is in the secret file, which `exporter` and root
read inside the node.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `0.245` and memory `122M`; reservations CPU
`0.045`, memory `42M` and disk `64M`. These are master spec 12's
figures for an exporter node (limits 0.25 / 128M, reservations 0.05 /
48M, 64M of volumes), which include the node-health script, less the
script's own cost (0.005 CPU, 6M; see the `prometheus` brick's
[GM notes](../../prometheus/docs/gm.md#what-the-node-health-script-adds-to-each-node)),
since a brick's footprint excludes mounted material. The scenario's
`resources` take the full row. Measured in the stack test (Docker
29.9.1, PostgreSQL 18.6, `--collector.stat_statements`, scraped by hand):
the container about 10–13M of memory, `postgres_exporter` about 17–19M of
RSS. The scenario sets each node's own `resources`, and `gmctl` uses
those, never the brick's footprint; disk is only counted by the capacity
check. Disk growth per hour (`disk_growth_per_hour`): `1M`, for the
players' notes; the v0.3 rehearsal, with no player, measured none
(below).

Measured in the v0.2 game (`fernway-clinics-monitoring` on the `laptop`
playground, declared at 2 CPU / 4G / 8G on armenelos: AMD Ryzen 5 PRO
8640HS, 11.3 GiB, Docker 29.9.1; 2026-10-21; `docker stats`, the highest
of its samples; without the node-health script, which that scenario's
fault f2 leaves off this node; scraped every 15 s, `pg_stat_statements`
not loaded on the database by fault f4), under a 128M limit: at rest 11
to 15 minutes after the deployment 24M; during dashboard loads 20M; during
a pgBadger run on `db` 20M; at rest again after them 22M; 31M at most
over the whole game.
CPU: up to 0.07 at rest over a docker stats sample, as each scrape runs
the collectors (above the 0.045 reservation, which only reserves, well
within the 0.245 limit). Never OOM-killed nor restarted, never at its
limit (`memory.peak`, page cache included, 38M). Its volumes: about 20K.
With the script mounted, add its 6M: still within the reservation.

Measured in the v0.3 rehearsal (`tools/tests/rehearsal.sh`:
`tarnbeck-outdoor-shop` on armenelos, AMD Ryzen 5 PRO 8640HS, 11.3 GiB,
Debian 13, Docker 29.9.1, plus the VPS `vps-5718ad52`, 4 vCPU Intel
Haswell, 7.6 GiB, Docker 29.9.2; 2026-10-28; 46 minutes of load from T0
12:59Z to the hand-over check, the customer's noon peak from 13:00Z;
`docker stats` every 20 s, the node-health script included), under
`tarnbeck-outdoor-shop`'s 128M limit, `pg_stat_statements` loaded, a
database of six tables under load, scraped every 15 s: 36M at most (28M
typical), 0.14 CPU at most (0.105 at the 95th percentile, above the 0.05
reservation, within the limit); 1 006 series a scrape; its volumes did not
grow.

What makes it grow:

- **Memory and CPU**: the scrape interval and the number of series per
  scrape: the databases and tables the collectors walk, and with
  `stat_statements` up to 100 statements (`--collector.stat_statements.limit`
  is not settable from the file).
- **Database load**: every scrape runs the collectors' queries on the
  database, inside its own limits.
- **Disk**: almost none: `exporter.conf`, the player's home, `/run`.

The levers that shrink it: a longer scrape interval, fewer collectors
(`--no-collector.<name>` in `COLLECTORS`).

### Snapshot

How each volume is copied at hand-over (`snapshot:` in `brick.yaml`):

- `expconf`, `home`, `gmstate`: `copy`, a tar of the volume while the
  node runs. The exporter keeps no data of its own (its metrics are read
  live from the database), so nothing is stopped: the node is never down
  for the snapshot. The stack test copies the three volumes this way.
- `run` (`/run`) is never copied.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59). No catalog fault (`faults/`) names `postgres-exporter` `0.2.0`,
so it supports none.

It shows one catalog fault of another brick: `pg-stat-statements-not-preloaded`
(on the `postgres` node, which its `applies_to` names). With
`--collector.stat_statements` in `exporter.conf`, the collector fails
(`pg_scrape_collector_success{collector="stat_statements"}` 0) and the
statement panels stay empty while `pg_up` is 1; a scenario planting that
fault keeps the collector on, and keeps the exporter's target in
Prometheus' configuration.

Faults it lends itself to with no definition yet: the exporter pointed at
the wrong database or host (`DATA_SOURCE_URI` in `exporter.conf`: a
seed-file fault, `pg_up 0`); query statistics off on this node (no
`--collector.stat_statements`; the database without the preload is
`pg-stat-statements-not-preloaded`, above); the database's `pg_hba.conf` not letting
`monitoring` in from this node (a seed-file fault on the database node).
Each is fixable on a fixable node by editing `exporter.conf` and running
`sudo gm-restart-exporter`, or on the database node.

Known interactions: `pg_up 0` empties every PostgreSQL panel and fires an
exporter-disconnected alert where one exists; the node-health script
still shows the exporter's service up, since the process runs. A file
that is not valid leaves the service down: node-health shows
`postgres-exporter` down and Prometheus' target down.

Faults it cannot host: anything needing the password in a file players
read (the brick never puts it there); a default or weak monitoring
password (the secret is always generated).

## Checks

### Validator

`/opt/gm/validator/validate.sh`, run as `exporter`. The official run is
`gmctl validate` (the GM's exec as `exporter`). Rules:

| Rule | Red when |
|---|---|
| `config` | `exporter.conf` is not valid (see "What the seed file must contain"); the service does not start with it |
| `server` | `postgres_exporter` does not answer on port 9187 (rule `pending` is then not checked) |
| `pending` | the file's modification time differs from the one the running service started with (`/run/postgres-exporter/loaded`): run `sudo gm-restart-exporter` |

Output: `GREEN: ...` and exit 0; one `RED <rule>: ...` line per broken
rule and exit 1, for example

```
RED config: /etc/postgres-exporter/exporter.conf is not valid, postgres_exporter does not start with it: line 12: unknown key DATA_SOURCE_PASS (known: DATA_SOURCE_URI, DATA_SOURCE_USER, COLLECTORS); line 13: COLLECTORS is set twice (first on line 11)
RED pending: /etc/postgres-exporter/exporter.conf changed at 2026-10-21T16:52:11Z, after postgres_exporter started (2026-10-21T16:51:58Z); run sudo gm-restart-exporter
```

`ERROR: ...` and exit 2 when port 9187 answers but no `postgres_exporter`
runs as `exporter`, or the service's record of what it loaded is missing.
The validator never asks the database anything and never judges
`pg_up`: a wrong address or a refused role is a finding, not a broken
game.

### Health check

Healthy while `sshd` is up, once `postgres_exporter` has answered its
landing page at least once in this container (marker
`/run/gm/postgres-exporter-was-ready`). The landing page asks nothing of
the database, so the database being down never makes this node
unhealthy; after the first answer, the exporter being down does not
either, so Swarm does not replace the container and cut the players' SSH
sessions.

### After deployment

`gmctl deploy` returns once the node is healthy, which proves the
exporter started with the seed file. `gmctl validate` shows the
validator. The wiring is confirmed from inside the node:
`curl -s http://127.0.0.1:9187/metrics | grep -E '^pg_up |^pg_stat_statements_calls_total'`
shows `pg_up 1` and, with the collector and the preload, statement
series (unless a planted fault says otherwise); in Prometheus,
`up{job="<the exporter's job>"}` is 1 and `pg_up` is 1.

### Stack test

`sh bricks/postgres-exporter/tests/run-stack-test.sh` deploys the brick as
the stack `gmtest-pgexp` (`tests/stack.test.yml`, fixtures in
`tests/fixtures/`, no published port) next to a `postgres` 0.3.0 node
`db` (its seed `postgresql.conf` from the postgres brick's fixtures, with
the preload; a `pg_hba.conf` `host` line for `monitoring`), both reading
the same `monitoring_password`, checks the chunk's Done-when and removes
everything it created, volumes included. It covers `pg_up`, the
`pg_stat_statements` metrics, every default collector succeeding, the
secret out of `player`'s reach and out of the server's arguments, the
wrappers, the validator green and red, a wrong address, the database
down, a file not valid at start, a new container, the hardening, and the
entrypoint refusing a missing, empty or multi-line password. Then the
snapshot's copies, the node redeployed `report-only` (`docker service
update --env-add GM_WRITE_POLICY=report-only`: modes, denied edits, the
wrapper's refusal, nothing restarted), then with the override
`/etc/postgres-exporter` (the edit through the wrapper, the owner
restored), and the entrypoint's two write-policy refusals. Needs a swarm
manager, this image and the `postgres` 0.3.0 image (the `db` node and the
test client) built.

## Known limits

- **Write policy**: only the files are guarded. On a report-only node
  `/metrics` still answers every reader of the game's network, as on a
  fixable one.
- **Host key per container.** The sshd host key is generated at each
  container start. If the container is replaced, players see a changed
  host key on the inner hop.
- **Settings at start only**: `postgres_exporter` has no reload; every
  change restarts it (a gap of about a second in its metrics).
- **Collector options**: `COLLECTORS` takes only `--collector.<name>` and
  `--no-collector.<name>`; the collectors' own options
  (`--collector.stat_statements.limit` and the like) keep their defaults.
- **`pending` granularity**: the rule compares modification times, so a
  file rewritten with its old content still shows as pending until the
  next restart.
- **No TLS, no login on `/metrics`** (the access model's monitoring
  interfaces are open inside the game's network). Upstream also serves
  `/debug/pprof` (profiles: stacks and counts, not memory contents; a CPU
  profile costs the node CPU while it runs), linked from the landing
  page, and `/probe`, which has no auth module here, so it holds no
  credential.
- **Image size**: 165MB, against master spec 12's estimate of about 25M
  for the exporter over the shared layers (about 40M of system layer per
  new image): the system packages (`openssh-server`, `sudo`, `curl`,
  `jq`) weigh more than the binary.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
