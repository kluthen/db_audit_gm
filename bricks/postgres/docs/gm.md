# PostgreSQL brick — GM notes

GM documentation of the `postgres` brick (`brick.yaml`, master spec 9.1;
required sections: spec D56). Never shipped to players. Brick version
0.2.0, expected to evolve as games are played.

## Purpose

A PostgreSQL 18 database server on Debian 13 (trixie), with an SSH server
for the players, in the image `127.0.0.1:5000/dbagm/postgres:0.2.0`. It
fills the role `database`: the node the players audit, holding the
scenario's data and its planted faults. The GM picks it for every
database node of a scenario; in v0.1 it is the only database brick, and
every catalog fault applies to it (see "Supported faults").

The image:

- Debian 13 (`debian:13-slim`), PostgreSQL 18 server and client from the
  PGDG repository (`trixie-pgdg`, major version pinned by package name),
  `openssh-server`, `sudo`, `nano`, `vim-tiny`, `less`, `procps`.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres`.
- **How many**: one per database node of the scenario. Each is its own
  container with its own volumes; the per-game secrets (`dba_password`,
  `player_ssh_pubkey`) are generated once per game, so every database
  node of a game gets the same values.
- **Next to which node**: any host. The node needs no other node on its
  host; in v0.1 the renderer runs the whole game on one host.
- **Stateful**: yes (`stateful: true`). Its volumes `pgdata`, `pgconf`,
  `home`, `gmstate` and `run` (see "Configuration") must follow the node
  if it is replaced; otherwise the data, the players' changes and the seed
  marker are lost.
- **Networks**: it must share a network with the bastion, which is the
  players' only way in (see "Connections"). v0.1 renders a single network
  for the whole game, so it shares it with every node.

## Configuration

`brick.yaml` declares no parameters (`parameters: {}`): everything
scenario-specific reaches the node through the seed files, the per-game
secrets, the envelope file and the data load.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Seed files `postgresql.conf`, `pg_hba.conf` (`seed.files`) | `/opt/gm/seed/`, root `0444`, copied into `/etc/postgresql/` at first start | the scenario's `seed_files` (`nodes/<node>/...`) |
| Envelope file (protected config `envelopes`) | `/opt/gm/protected/envelopes.conf`, root `0444` | `gmctl render`, from the node's `knobs` envelopes |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |
| Secret `dba_password` (kind `password`, not handed over) | `/opt/gm/secrets/dba_password`, root `0400` | `gmctl deploy`: the same secret as the bastion's |
| Data | streamed in once, after deployment | `gmctl load-data`, from `data/<node>.sql` |

### Knobs and their default envelopes

All in `/etc/postgresql/postgresql.conf`. The default envelopes are sized
for the default footprint; a scenario may tighten them, never widen them.

| Setting | Default | Default envelope |
|---|---|---|
| `shared_buffers` | `128MB` | `32MB` to `256MB` |
| `work_mem` | `4MB` | `1MB` to `64MB` |
| `maintenance_work_mem` | `64MB` | `16MB` to `256MB` |
| `max_connections` | `100` | `10` to `200` |
| `max_wal_size` | `1GB` | `64MB` to `1GB` |
| `autovacuum` | `on` | `on` only |

### Fixed paths (capture W1-B)

| What | Path | Notes |
|---|---|---|
| Seed directory | `/opt/gm/seed/` | configs `postgresql.conf`, `pg_hba.conf`, read-only |
| Configuration | `/etc/postgresql/` | volume `pgconf`; `postgres:pgconf`, dir `2775`, seeded files `0664` |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`; dir root `0755`, marker root `0444`; present means never seed again |
| PGDATA | `/var/lib/postgresql/18/data` | volume `pgdata` |
| Player home | `/home/player` | volume `home` |
| Runtime | `/run` | volume `run`, emptied at each start (see below) |
| Secrets | `/opt/gm/secrets/player_ssh_pubkey`, `/opt/gm/secrets/dba_password` | |
| Envelope file | `/opt/gm/protected/envelopes.conf` | protected config `envelopes`, root, `0444` |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-reload-db`, `gm-restart-db`, `gm-validate` | |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |
| Socket | `/run/postgresql/.s.PGSQL.5432` | |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/postgresql` (`postgres`, `2775`),
   `/run/sshd`, `/run/sshd-keys`, `/run/gm`, `/run/tmp` (`/tmp` and
   `/var/tmp` are symlinks to it).
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if a secret is missing or empty.
4. If `/var/lib/gm-state/.gm-seeded` is absent: copies the seed files into
   `/etc/postgresql/` and writes the marker. A missing seed file fails the
   container. Never overwrites afterwards. The marker is on its own
   root-owned volume, out of reach of `player` and `postgres`: the
   configuration directory is group-writable without the sticky bit, so
   that editors saving by rename (`sed -i`) work, and a marker there could
   be removed.
5. If PGDATA is empty: `initdb` (UTF8, `C.UTF-8`, data checksums on by
   default in 18), then creates the role `dba` (`LOGIN SUPERUSER`, password
   from the secret) in single-user mode, and removes initdb's own
   `postgresql.conf` and `pg_hba.conf` from PGDATA, so the live files are
   only in `/etc/postgresql`. `pg_ident.conf` stays in PGDATA.
6. Writes `/home/player/.pgpass` (`*:*:*:dba:<password>`, `0600`).
7. Execs s6-overlay's `/init`, which supervises `postgres` and `sshd`.

Seeded once: the configuration files (first start on a fresh `gmstate`
volume) and the cluster with its `dba` role (first start on a fresh
`pgdata` volume). Rewritten at each start: `/run`, the sshd host key and
`~/.pgpass`.

PostgreSQL runs as
`postgres -D /var/lib/postgresql/18/data -c config_file=/etc/postgresql/postgresql.conf -c hba_file=/etc/postgresql/pg_hba.conf`.
Its stderr goes to the container's output (`gmctl logs`); players do not
see it.

### Why `/run` is a volume

A stack file's tmpfs mount is `noexec`, and the stack loader drops the
`exec` option and `mode`. s6-overlay refuses a `noexec` `/run`:

```
preinit: warning: your container manager pre-mounts run with the incorrect noexec option, which s6-overlay cannot work with
stage0: 83: exec: /run/s6/basedir/bin/init: Permission denied
```

(seen with s6-overlay 3.2.3.2 on Docker 29.8.2, task exit 126). The only
run-time fix it offers is `CAP_SYS_ADMIN`. So `/run` is the named volume
`run` (fallback (a) of the build plan's chunk 2), and the entrypoint
empties it before `/init`, so nothing survives from one container to the
next. The root filesystem stays read-only.

### What the seed files must contain

The scenario's seed files replace PostgreSQL's defaults entirely:

- `postgresql.conf`: `listen_addresses = '*'` (otherwise the bastion
  cannot connect), `port = 5432` (the health check, the wrappers and the
  validator use 5432), and whatever initdb would have set that the scenario
  cares about (`dynamic_shared_memory_type`, `timezone`, `lc_messages`...).
  Do not set `config_file`, `hba_file` or `data_directory`.
- `pg_hba.conf`: the line `local all postgres peer`, before any other line
  matching `postgres` on the local socket, with a comment marking it
  DO NOT TAMPER; plus the players' access for `dba`, for example
  `local all all scram-sha-256` and `host all all 0.0.0.0/0 scram-sha-256`
  (the password is SCRAM-hashed).
- Every knob should be inside its envelope unless an out-of-envelope value
  is a planted finding. A knob the seed does not set takes PostgreSQL's
  default, which the validator checks too.

## Connections

The brick provides two interfaces and consumes none (`interfaces.consumes:
[]`): it reaches no other node. Container ports 5432 and 22; nothing is
published (in v0.1 only the bastion publishes a port), so both are
reachable only from nodes sharing a network with it, by its node name.

- **`sql`, PostgreSQL protocol, port 5432.** The other side is the
  bastion, where the players run `psql -h <node>`. They log in as the role
  `dba`, whose password is the per-game secret `dba_password`: `gmctl
  deploy` generates it and gives the same secret to both nodes (no brick
  parameter supplies it); the bastion's `~/.pgpass` carries it. Before the
  wiring works: the seed `postgresql.conf` listens on `*` and port 5432,
  and the seed `pg_hba.conf` has a `host` line letting `dba` in with
  `scram-sha-256` from the game's network (see "What the seed files must
  contain").
- **`ssh`, SSH protocol, port 22.** The other side is the bastion's inner
  hop (`ssh <node>`), as `player`, by public key only: the node's
  `player_ssh_pubkey` is the public half of the bastion's `player_ssh_key`,
  a key pair `gmctl deploy` generates per game. The node's host key is
  created anew at each container start; how the bastion copes with that
  is in the bastion brick's
  [GM notes](../../bastion/docs/gm.md#inner-hop-and-host-keys).

**Monitoring**: `brick.yaml` declares no monitoring exposure, and the brick
has no metrics endpoint or exporter. The server log and the sshd log go to
the container's output only (`gmctl logs`).

**Mounted material**: the image accepts another brick's mounted companion
material (`brick.yaml` `receives`): it runs s6-overlay `3.2.3.2`, and the
commands `sh`, `cat`, `du`, `df`, `awk`, `sed`, `grep`, `sleep`, `perl`,
`s6-svstat` and `s6-setuidgid` are on an s6 service's PATH. A brick whose
mounted material requires no more than that (such as `prometheus`'s
node-health script) can be mounted into this node; the cost of that
material is stated by the brick that ships it, not here.

The GM's own operations (data load, injection, sealed checks, validator)
do not use these interfaces: they run inside the container through `gmctl
exec` (see "Access").

## Access

### Accounts and access

- `player`: SSH by public key only (`AuthorizedKeysFile` points at the
  secret; no password, no PAM), member of `pgconf`. sshd sets
  `PGUSER=dba` and `PGDATABASE=postgres`. No TCP, agent or X11 forwarding.
- `dba`: superuser role, password from the secret `dba_password` (the same
  Swarm secret as the bastion's). Superuser also means OS access as
  `postgres`; protected files are root-owned and read-only, so it cannot
  alter them.
- `postgres`: the GM's account, over the local socket with peer
  authentication (`gmctl exec` as `postgres`, or `runuser -u postgres`).
  Sealed checks query as `postgres`.
- `sudo`: `player` may run the three wrappers as root, with no arguments
  (`/etc/sudoers.d/gm-player`): `env_reset`, fixed `secure_path`, no
  syslog, log in `/run/gm/sudo.log`.

The node has no web interface.

### Writable and protected paths, write policies

- Writable by the player: `/etc/postgresql` (`postgres:pgconf`, `2775`;
  seeded files `0664`) and `/home/player` (`~/.pgpass`, rewritten at each
  start; `~/report.md`).
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the entrypoint, the three
  wrappers, the health check, the validator, the envelope file, the
  s6-overlay service definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`) and the seed marker's directory
  `/var/lib/gm-state`.
- Write policies: `fixable` only, in v0.1 (see "Known limits").

### Wrappers

- `gm-reload-db`: `pg_ctl reload` as `postgres`, then lists
  `pg_file_settings` and `pg_hba_file_rules` errors (including "needs a
  restart"). Exit 1 only if PostgreSQL is not running.
- `gm-restart-db`: checks `postgres -C data_directory` with the live files
  and `pg_hba_file_rules`; refuses (exit 1) if either fails. Otherwise
  `s6-svc -r` (down signal `SIGINT`, fast shutdown) and waits up to 60 s
  for a new postmaster to accept connections. The container and SSH
  sessions survive. Failures that only show at start (shared memory too
  large for the memory limit, for example) are reported as "did not come
  back"; the reason is in `gmctl logs`.
- `gm-validate`: runs the validator as `postgres`, exit code passed
  through.

### Capabilities

`cap_drop: ALL`, then the list in `brick.yaml`, checked by dropping each
one in turn (Docker 29.8.2): without `CHOWN`, `DAC_OVERRIDE`, `FOWNER`,
`SETGID` or `SETUID` the entrypoint fails; without `SYS_CHROOT` SSH
logins fail (privilege separation); without `KILL` `gm-restart-db`
cannot restart PostgreSQL; without `AUDIT_WRITE` every `sudo` prints
"unable to send audit message". `NET_BIND_SERVICE` is not needed under
Docker, which sets `net.ipv4.ip_unprivileged_port_start=0`, but sshd
binds port 22, so it stays for other platforms. `no-new-privileges` is
off: `sudo` is setuid.

### What the GM uses

`gmctl exec --node <node> --user postgres` (or `--user root`, then
`runuser -u postgres`) for SQL over the local socket with peer
authentication; `gmctl load-data`, `gmctl inject`, `gmctl check` and
`gmctl validate` go the same way. `gmctl logs --node <node>` shows the
server log.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `1` and memory `1G`; reservations CPU `0.5`,
memory `512M` and disk `1G` (v0.1's single figures became the
reservations, the limits twice the CPU and memory). No allowed range. It
excludes any material other bricks mount into the node: what that adds
per node is stated by the brick that ships it, and the GM adds it to the
node's `resources` in the scenario. The scenario sets each node's own
`resources` (limits for CPU and memory, reservations for CPU, memory and
disk), and `gmctl` uses those, never the brick's footprint. The renderer
applies the CPU and memory limits and reservations; disk is only counted
by the capacity check (`gmctl fit`: reservations plus 10 % headroom
against the playground); the volumes themselves have no size limit.

What makes it grow:

- **Memory**: `shared_buffers`, plus `work_mem` for every sort or hash of
  every connection (up to `max_connections`), plus
  `maintenance_work_mem` for maintenance work. The default envelopes are
  sized for the default 512M reservation; shared memory too large for the memory
  limit keeps the server from starting.
- **Disk**: the restored data (`data/<node>.sql`) and its indexes in
  `pgdata`; WAL, up to `max_wal_size` (at most `1GB` in the default
  envelope), and without bound when a replication slot holds it (fault
  `pg-abandoned-replication-slot`); a few megabytes for the configuration
  and the player's home.
- **CPU**: the data load, and the players' own queries.

Size the disk reservation from the data file (with its indexes) plus
`max_wal_size`, and the memory limit from the knobs' initial values. The
levers that shrink it: smaller knob values within their envelopes (a lower
`shared_buffers`, `max_connections` or `max_wal_size`), a scenario
envelope tightened to match, and a smaller data file.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59): a fault instance is accepted on a node when the fault's
`applies_to` names the node's brick and version (`tools/gm/model.py`).
This list is every catalog fault (`faults/`) whose `applies_to` names
`postgres` `0.2.0`, and no other; all six also name `0.1.0` and `0.1.1`. A scenario's
own `faults/` folder may define more for itself (the test fixture
`tools/tests/fixtures/fixture-audit` defines two); those are the
scenario's, not the brick's, and are not listed here.

| Fault | Kind | What it needs from the brick |
|---|---|---|
| `pg-hba-trust-remote` | seed file | the seed `pg_hba.conf` (material `inject/pg_hba.conf.snippet`): a `host ... trust` line for a remote range before the `scram-sha-256` `host` lines, the GM's `local all postgres peer` line still first; the bastion, from where the players try a password-less connection |
| `pg-memory-over-envelope` | seed file | the seed `postgresql.conf` setting a memory knob above the scenario envelope's `max` (parameters `setting`, `max`), and the knob's `initial` recording the same value; the validator is red from the start |
| `pg-role-superuser` | state, after the data load | parameter `role`: a login role the data file creates |
| `pg-join-index-missing` | state, after the data load | parameters `database`, `table-name`, `column`: a table the data file creates, with a foreign key and an index leading with that column; the scripts drop the index and run `ANALYZE` |
| `pg-table-autovacuum-off` | state, after the data load | parameters `database`, `table-name`: a table the data file creates; the server-wide `autovacuum` stays `on`, so the validator stays green |
| `pg-abandoned-replication-slot` | state, after the data load | parameter `slot-name`; no standby in the topology; a seed `postgresql.conf` that allows a physical slot (`wal_level` `replica` or above, `max_replication_slots` above 0: PostgreSQL's defaults); writes, for the retained WAL to grow |

Every state fault's scripts run as root and query as `postgres` over the
local socket, so they need the GM's `local all postgres peer` line in
`pg_hba.conf`; every sealed check needs it too.

Faults it lends itself to with no definition yet: a bloated table (a
candidate of master spec 15), and other configuration, schema, role or
state defects visible without activity.

Known interactions:

- The bastion's `~/.pgpass` supplies the `dba` password on every
  connection, so a `trust` line (`pg-hba-trust-remote`) goes unnoticed in
  ordinary use; its evidence connects with `PGPASSFILE=/nonexistent`.
- The `autovacuum` knob's envelope allows `on` only: turning autovacuum
  off server-wide turns the validator red, while the table-level
  `pg-table-autovacuum-off` leaves it green.
- No monitoring brick exists in v0.1, so nothing masks or reveals a fault
  from outside the node.

Faults it cannot host: anything needing a standby or a replication peer
(the brick has the single role `database` and consumes nothing), and
anything visible only under load (the brick has no load generator).

## Checks

### Validator

`/opt/gm/validator/validate.sh [envelope-file]`, run as `postgres`. The
official run is `gmctl validate` (the GM's exec as `postgres`). It may be
red from the start, when a knob's initial value is a planted finding
outside its envelope.

Envelope file format (capture W1-B), one rule a line, `#` comments:

```
shared_buffers  range 64MB 256MB    # bounds as PostgreSQL accepts them, - for unbounded
autovacuum      enum on             # allowed values, comma-separated, no spaces
wal_level       enum replica,logical
```

Values are compared in the setting's base unit: memory through
`pg_size_bytes`, time through `interval`, bare numbers as the base unit
(`shared_buffers = 16384` is 16384 blocks of 8kB); booleans as `on`/`off`;
enums case-insensitively. Both the value in effect (`pg_settings`) and the
pending value (the last `pg_file_settings` entry for the setting, which a
reload or restart would apply, `postgresql.auto.conf` included) are
checked. A setting no file sets has no pending value.

Output: `GREEN: ...` and exit 0; one `RED <rule>: ...` line per broken
rule and exit 1, for example

```
RED work_mem: in effect 128MB; pending 128MB (/etc/postgresql/postgresql.conf:18); envelope 1MB..64MB
RED max_connections: pending 300 (/etc/postgresql/postgresql.conf:4); envelope 10..200
RED pg_hba: the GM's line 'local all postgres peer' is missing from /etc/postgresql/pg_hba.conf (DO NOT TAMPER)
RED server: postgres cannot connect over the local socket (...)
```

`ERROR: ...` and exit 2 for a missing or malformed envelope file, an
unknown setting, a bound that is not a valid value, or an unexpected query
failure. If `postgres` cannot connect (GM line removed, server down), the
knob rules are reported red as not checked.

### Health check

Healthy while `sshd` is up, once PostgreSQL has accepted connections at
least once in this container (marker `/run/gm/postgres-was-ready`). After
that, PostgreSQL being down does not make the container unhealthy: a
player's broken configuration is the game's business, and Swarm replacing
the container would cut the players' SSH sessions. `gmctl deploy` waiting
for health therefore waits for the first PostgreSQL start.

### Companion checks

None: the brick ships no `companion/` material.

### After deployment

`gmctl deploy` returns once the node is healthy, which proves PostgreSQL
started with the seed files. `gmctl validate` shows the node's validator.
The wiring to the bastion is confirmed from the bastion, as `player`:
`ssh <node>` and `psql -h <node>` as `dba` (see the bastion brick's
[GM notes](../../bastion/docs/gm.md#after-deployment)).

### Stack test

`sh bricks/postgres/tests/run-stack-test.sh` deploys the brick as a
one-service stack (`tests/stack.test.yml`, test fixtures in
`tests/fixtures/`), checks the chunk's Done-when, and removes everything
it created, volumes included. Needs a swarm manager and the image built.

## Known limits

- **Host key per container.** The sshd host key is generated at each
  container start. If the container is replaced, players see a changed
  host key on the inner hop.
- **`.pgpass` is rewritten** at each container start from the secret.
- **Server log** only in the container output; players see it only if a
  scenario turns `logging_collector` on.
- **Write policy**: only `fixable` in v0.1. A `report-only` node would need
  the configuration files not group-writable, decided at start from a
  value the renderer passes; not built.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
