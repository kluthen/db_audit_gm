# PostgreSQL brick — GM notes

GM documentation of the `postgres` brick (`brick.yaml`, master spec 9.1;
required sections: spec D56). Never shipped to players. Brick version
0.3.0, expected to evolve as games are played.

## Purpose

A PostgreSQL 18 database server on Debian 13 (trixie), with an SSH server
for the players, in the image `127.0.0.1:5000/dbagm/postgres:0.3.0`. It
fills the role `database`: the node the players audit, holding the
scenario's data and its planted faults. The GM picks it for every
database node of a scenario; in v0.2 it is still the only database
brick. The catalog faults are no longer all its own: those that do not
name it in `applies_to` apply to the monitoring bricks `prometheus` and
`grafana` (see "Supported faults" for the ones it hosts).

The image:

- Debian 13 (`debian:13-slim`), PostgreSQL 18 server and client from the
  PGDG repository (`trixie-pgdg`, major version pinned by package name;
  `pg_stat_statements` ships with the server), pgBadger from the same
  repository (13.2 at the 0.2.0 build), `openssh-server`, `sudo`, `nano`,
  `vim-tiny`, `less`, `procps`. About 262MB.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres`.
- **How many**: one per database node of the scenario. Each is its own
  container with its own volumes; the per-game secrets (`dba_password`,
  `monitoring_password`, `gm_check_password`, `pgbouncer_lookup_password`
  in a scenario with a pooler node, `player_ssh_pubkey`) are generated
  once per game, so every database node of a game gets the same values.
- **Next to which node**: any host. The node needs no other node on its
  host; in v0.2 the renderer still runs the whole game on one host (one
  host remains the only playground shape, master spec 8).
- **Stateful**: yes (`stateful: true`). Its volumes `pgdata`, `pgconf`,
  `home`, `gmstate`, `pglog` and `run` (see "Configuration") must follow
  the node if it is replaced; otherwise the data, the players' changes,
  the seed marker and the server log are lost.
- **Networks**: it must share a network with the bastion, which is the
  players' only way in (see "Connections"). Each network a scenario
  declares renders as `<game_id>_<network name>`; v0.2 scenarios declare
  one network, and the scripts refuse a second (master spec 6.3), so it
  shares it with every node.

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
| Secret `monitoring_password` (kind `password`, not handed over) | `/opt/gm/secrets/monitoring_password`, uid `0`, gid `102` (`postgres`), `0440`: root and `postgres` only | `gmctl deploy`: the same secret as the `postgres-exporter` node's (see "The monitoring role") |
| Secret `gm_check_password` (kind `password`, not handed over) | `/opt/gm/secrets/gm_check_password`, root `0400`: root only | `gmctl deploy`; declared by this brick only (see "The GM check role and the reserve") |
| Secret `pgbouncer_lookup_password` (kind `password`, not handed over, `only_with_role: pooler`) | `/opt/gm/secrets/pgbouncer_lookup_password`, root `0400`: root only | `gmctl deploy`, only in a scenario with a `pooler` node: the same secret as the `pgbouncer` node's (see "The PgBouncer lookup role") |
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
| Player home | `/home/player` | volume `home`; pgBadger reports land here |
| Server log | `/var/log/postgresql/` | volume `pglog`; `postgres:pgconf`, dir `2750` (setgid), files `0640` |
| Runtime | `/run` | volume `run`, emptied at each start (see below) |
| Secrets | `/opt/gm/secrets/player_ssh_pubkey`, `/opt/gm/secrets/dba_password`, `/opt/gm/secrets/monitoring_password`, `/opt/gm/secrets/gm_check_password`, `/opt/gm/secrets/pgbouncer_lookup_password` | the last one only with a pooler node |
| Envelope file | `/opt/gm/protected/envelopes.conf` | protected config `envelopes`, root, `0444` |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-reload-db`, `gm-restart-db`, `gm-validate` | |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Snapshot helper | `/usr/local/sbin/gm-snapshot-db` | root `0700`, not a `sudo` wrapper (see "Snapshot") |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| Check role's `psql` | `/usr/local/lib/gm/check-psql` | root `0700`; the sealed checks connect through it (see "The GM check role and the reserve") |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |
| Socket | `/run/postgresql/.s.PGSQL.5432` | |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/postgresql` (`postgres`, `2775`),
   `/run/sshd`, `/run/sshd-keys`, `/run/gm`, `/run/tmp` (`/tmp` and
   `/var/tmp` are symlinks to it).
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if `player_ssh_pubkey`, `dba_password` or
   `monitoring_password` is missing or empty, or if a password secret is
   not a single line. `gm_check_password` missing only logs a warning
   (another brick's test stack runs without it; a game always mounts
   it), and the check role is then neither created nor updated.
   `pgbouncer_lookup_password` is optional: mounted means a pooler node.
4. If `/var/lib/gm-state/.gm-seeded` is absent: copies the seed files into
   `/etc/postgresql/` and writes the marker. A missing seed file fails the
   container. Never overwrites afterwards. The marker is on its own
   root-owned volume, out of reach of `player` and `postgres`: the
   configuration directory is group-writable without the sticky bit, so
   that editors saving by rename (`sed -i`) work, and a marker there could
   be removed. At every start, seeded or not, gives `postgresql.conf` and
   `pg_hba.conf` their seeded owner and mode back (`postgres:pgconf`,
   `0664`), as the wrappers do (see "Wrappers").
5. Sets `/var/log/postgresql` to `postgres:pgconf`, `2750` with the
   setgid bit, so every log file PostgreSQL writes there gets the group
   `pgconf` (the players' group).
6. If PGDATA is empty: `initdb` (UTF8, `C.UTF-8`, data checksums on by
   default in 18), then, in single-user mode, creates the role `dba`
   (`LOGIN SUPERUSER`, password from its secret), the role `monitoring`
   (`LOGIN`, member of `pg_monitor`, password from `monitoring_password`)
   and the extension `pg_stat_statements` in the database `postgres`;
   then removes initdb's own `postgresql.conf` and `pg_hba.conf` from
   PGDATA, so the live files are only in `/etc/postgresql`.
   `pg_ident.conf` stays in PGDATA.
7. Creates or updates the GM's roles, at every start, in single-user
   mode before the server listens: the check role `gm_check` and, when
   `pgbouncer_lookup_password` is mounted, the lookup role
   `pgbouncer_lookup` with its schema and function (see the two sections
   below). Single-user mode runs on PostgreSQL's defaults
   (`config_file=/dev/null`), so a player's broken `postgresql.conf`
   does not stop it, with no preload library and no statement logged
   (the passwords). On a fresh cluster a failure fails the container;
   on an existing one it logs a warning and the roles stay as they were,
   rather than lock the players out of the node. Success logs
   `gm-entrypoint: GM roles up to date: gm_check pgbouncer_lookup`
   (`gmctl logs`).
8. Writes `/home/player/.pgpass` (`*:*:*:dba:<password>`, `0600`).
9. Execs s6-overlay's `/init`, which supervises `postgres` and `sshd`.

Seeded once: the configuration files (first start on a fresh `gmstate`
volume) and the cluster with its roles `dba` and `monitoring` and the
extension (first start on a fresh `pgdata` volume). Rewritten at each
start: `/run`, the sshd host key, `~/.pgpass`, and the GM's roles'
attributes, memberships, grants and passwords.

PostgreSQL runs as
`postgres -D /var/lib/postgresql/18/data -c config_file=/etc/postgresql/postgresql.conf -c hba_file=/etc/postgresql/pg_hba.conf -c reserved_connections=2`
(the GM's reserve, see "The GM check role and the reserve").
With the seed's `logging_collector = on`, it writes its log to files in
`/var/log/postgresql` (see "What the seed files must contain"); only the
lines before the collector starts reach the container's output (`gmctl
logs`). Without it, the log goes to the container's output as in v0.1.

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
  Do not set `config_file`, `hba_file` or `data_directory`. Plus the
  logging and preload settings below.
- `pg_hba.conf`: the line `local all postgres peer`, before any other line
  matching `postgres` on the local socket, and the check role's line
  `local all gm_check scram-sha-256`, before any other line matching
  `gm_check` (v0.3 spec D171), both under a comment marking them DO NOT
  TAMPER, so a player tightening the general `local` line keeps the
  sealed checks working; and `local replication postgres peer` beside
  them (v0.3 spec D164), the hand-over snapshot's connection (see
  "Snapshot"); plus the players' access for `dba`, for example
  `local all all scram-sha-256` and `host all all 0.0.0.0/0 scram-sha-256`
  (the password is SCRAM-hashed).
- `wal_level` `replica` or `logical` (the default is `replica`), and
  `max_wal_senders` and `max_replication_slots` left at 1 or more (their
  defaults are 10): the snapshot needs a replication connection and a
  slot.
- `max_connections` above 5: the server does not start unless it is
  more than `superuser_reserved_connections` (3) plus the GM's
  `reserved_connections` (2). The envelope's minimum, 10, leaves five
  ordinary slots.
- Every knob should be inside its envelope unless an out-of-envelope value
  is a planted finding. A knob the seed does not set takes PostgreSQL's
  default, which the validator checks too.

### Logging and `pg_stat_statements` in the seed `postgresql.conf`

The logging settings live in the seed, not in the image, so a scenario can
plant a logging fault there (master spec 7.5). The stack test's seed
(`tests/fixtures/postgresql.conf`) carries the reference values:

```
logging_collector = on
log_destination = 'stderr'
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_file_mode = 0640
log_rotation_age = 0
log_rotation_size = 10MB
log_truncate_on_rotation = off
log_line_prefix = '%t [%p]: user=%u,db=%d,app=%a,client=%h '
log_timezone = 'UTC'
log_min_duration_statement = 100ms
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 0
lc_messages = 'C.UTF-8'
shared_preload_libraries = 'pg_stat_statements'
```

- `log_directory` must be `/var/log/postgresql`, the volume `pglog`: a
  relative path lands in PGDATA, which players cannot read.
- `log_file_mode = 0640` with the directory's setgid bit makes the files
  readable by `pgconf`, so the players read them and run pgBadger without
  `sudo`; they cannot write them.
- Rotation is by size only (`log_rotation_size`, a new file per 10MB;
  `log_rotation_age = 0`). The file name carries the time the file was
  opened, so no file is ever overwritten.
- `log_line_prefix` is the stderr prefix pgBadger's documentation
  recommends: pgBadger reads it with no `--prefix` option. Timestamps
  (`%t`) are in `log_timezone`, UTC like the node (`TZ=UTC`).
- `log_min_duration_statement` sets which queries pgBadger can report
  (`-1` logs none, `0` logs all); `lc_messages` must be English (`C`,
  `C.UTF-8` or `en_*`) for pgBadger to classify the messages.
- `shared_preload_libraries = 'pg_stat_statements'` loads the library
  (restart only). The extension already exists in the database `postgres`
  (start-up step 6), so the view `pg_stat_statements` answers as soon as
  the library is preloaded, and fails with "pg_stat_statements must be
  loaded via shared_preload_libraries" when it is not. A data file
  creating it in another database should use `CREATE EXTENSION IF NOT
  EXISTS`.

These are not knobs: the validator does not check them, so leaving one
out or getting one wrong is a finding for the players, not a red
validator.

### The monitoring role

Who creates the exporter's monitoring role and how its password reaches
the database (master spec 15, settled by the build of this brick):

- **Who and when**: this brick's start-up (`gm-entrypoint`, step 6), once,
  when it initialises a fresh `pgdata` volume, in single-user mode, before
  PostgreSQL first listens. Not the data load: the role exists before
  `gmctl load-data` runs, whatever the scenario's data file holds.
- **The role**: `monitoring`, `LOGIN`, not superuser, member of
  `pg_monitor` (`GRANT pg_monitor TO monitoring`); it reads every
  statistics view, `pg_stat_statements` included.
- **The password**: the per-game secret `monitoring_password` (kind
  `password`, 32 characters, not handed over), generated by `gmctl
  deploy` from the declarations of this brick and of `postgres-exporter`
  (the same name in both, so one secret per game), mounted at
  `/opt/gm/secrets/monitoring_password` (root and `postgres` only). The
  entrypoint reads it as root and sets it as the role's SCRAM password.
  It is never written to the player's files.
- **Connection**: over TCP to port 5432, database `postgres`, user
  `monitoring`, `scram-sha-256` through the seed `pg_hba.conf`'s `host`
  line for the game's network (the stack test's seed: `host all all
  0.0.0.0/0 scram-sha-256`). A scenario restricting `pg_hba.conf` must
  keep a line letting `monitoring` in from the exporter's node.
- **Not re-applied**: a later start leaves the role as it is. The players
  (as superuser `dba`) can alter or drop it, which only breaks their own
  monitoring (access model 8); a fault taking `pg_monitor` away is a state
  change after the data load.

### The GM check role and the reserve

The sealed checks' connection (v0.3 master spec 6.5, 7.3 and 11, rule 5;
capture W1 item 8), so that a check always gets in, even when the load or
a planted exhaustion fault holds every ordinary slot:

- **The reserve**: `reserved_connections = 2`, on the server's command
  line in the run script (`s6-rc.d/postgres/run`), which overrides
  `postgresql.conf` and `ALTER SYSTEM` alike (`pg_settings.source` reads
  `command line`). `superuser_reserved_connections` keeps its default 3.
  With `max_connections = N`, ordinary roles get `N - 5` slots, the
  members of `pg_use_reserved_connections` two more, superusers (`dba`,
  `postgres`) the last three. Two: the GM runs its checks one at a time,
  and a timer-fired early check may overlap one the GM runs by hand. The
  stack test shows it with `max_connections = 10`: five sessions of an
  ordinary role take the five ordinary slots and a sixth is refused
  ("reserved for roles with privileges of the pg_use_reserved_connections
  role"), two `gm_check` sessions get in, a third is refused (the
  superuser slots), and `dba` still connects.
- **The role** `gm_check`: `LOGIN`, not superuser, no `CREATEDB`,
  `CREATEROLE`, `REPLICATION` or `BYPASSRLS`; member, with `INHERIT`, of
  `pg_use_reserved_connections`, `pg_monitor` (settings, statistics,
  activity) and `pg_read_all_data` (the data checks); `SELECT` on
  `pg_catalog.pg_hba_file_rules` and `EXECUTE` on the function
  `pg_catalog.pg_hba_file_rules()` behind it (the view alone is not
  enough). A check needing more says so in its fault and is a build
  finding.
- **When**: created at the first start and brought back at every
  container start (start-up step 7): its attributes, memberships, grants
  and password are re-applied, so a cluster restored from the hand-over
  snapshot carries it and a `dba` who altered or dropped it is undone at
  the next new container. `gm-restart-db` does not re-apply it.
- **Its password**: the per-game secret `gm_check_password` (kind
  `password`, 32 characters, not handed over), declared by this brick
  only, mounted root `0400`. Never in a player's file, nor in the
  server's log.
- **How a check connects**: as root inside the node (`gmctl exec --node
  <node> --user root`), through `/usr/local/lib/gm/check-psql`, root
  `0700`, protected:

  ```
  /usr/local/lib/gm/check-psql -d <db> -Atq -v ON_ERROR_STOP=1 <<'SQL'
  select ...;
  SQL
  ```

  It runs `psql -X -w -h /run/postgresql -p 5432 -U gm_check "$@"`,
  standard input and output passed through, with the password in a
  `0600` `PGPASSFILE` under the root-only `/run/gm`, removed on every
  exit, and the caller's `PG*` connection variables cleared. Exit status:
  psql's (0 done, 1 a psql error, 2 the connection failed or was lost,
  3 a script error under `ON_ERROR_STOP`), and 2 with one `check-psql:
  ...` line on standard error when the helper cannot run (not root, the
  secret missing). It connects over the local socket through the seed's
  `local all gm_check scram-sha-256` line.
- **Players see it**: with `log_connections = on` the server log, and so
  pgBadger, records the `gm_check` sessions, as `pg_stat_activity` shows
  them while they run.

### The PgBouncer lookup role

PgBouncer's `auth_query` on the database side (v0.3 master spec 7.2;
capture W1 item 8), present only in a scenario with a `pooler` node:

- **The role** `pgbouncer_lookup`: `LOGIN`, not superuser, `NOINHERIT`,
  no membership; its only right is `EXECUTE` on the lookup function and
  `USAGE` on its schema.
- **The function**, in the database `postgres`:
  `gm_pgbouncer.lookup(p_usename text) RETURNS TABLE (usename name,
  passwd text)`, `LANGUAGE sql STABLE SECURITY DEFINER`, owned by
  `postgres`, `SET search_path = pg_catalog, pg_temp`. It returns
  `rolname` and `rolpassword` from `pg_authid` for the login role named,
  when its password has not expired (`rolvaliduntil` null or in the
  future), superusers included (`dba`, the players' console role). The
  schema `gm_pgbouncer` and the function have every right revoked from
  `PUBLIC`.
- **PgBouncer's side** (the `pgbouncer` brick): `auth_user =
  pgbouncer_lookup`, `auth_dbname = postgres`, `auth_query = SELECT
  usename, passwd FROM gm_pgbouncer.lookup($1)`. It connects over TCP,
  so the seed `pg_hba.conf` must let `pgbouncer_lookup` in from the
  pooler's node by password.
- **When**: created and brought back at every container start (start-up
  step 7) when `/opt/gm/secrets/pgbouncer_lookup_password` is mounted,
  which `gmctl render` does only for a scenario with a node of role
  `pooler` (`only_with_role: pooler`). Its password is that per-game
  secret (kind `password`, not handed over), root `0400` here, the same
  secret as the `pgbouncer` node's.

## Connections

The brick provides two interfaces and consumes none (`interfaces.consumes:
[]`): it reaches no other node. Container ports 5432 and 22; nothing is
published (no node other than the bastion publishes a port, master spec
7), so both are reachable only from nodes sharing a network with it, by
its node name.

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

**Pooler**: in a scenario with a `pgbouncer` node, PgBouncer reaches the
`sql` interface over TCP for its clients, and for `auth_query` as
`pgbouncer_lookup` (see "The PgBouncer lookup role"); the seed
`pg_hba.conf` must let both in from the pooler's node.

**Monitoring**: the node has no metrics endpoint of its own. What it
exposes to monitoring is the `sql` interface itself: the `postgres-exporter`
brick connects to it as the role `monitoring` (`pg_monitor`), with the
per-game secret `monitoring_password` (see "The monitoring role"); the
exporter's node must share a network with this node, and the seed
`pg_hba.conf` must let `monitoring` in from it. `pg_stat_statements` is
there for the exporter's query panels once the seed preloads it. The server
log is in `/var/log/postgresql` (pgBadger); the sshd log and the server's
start-up lines go to the container's output (`gmctl logs`).

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
  authentication (`gmctl exec` as `postgres`, or `runuser -u postgres`):
  data load, injection, validator.
- `gm_check`: the GM check role, for the sealed checks, inside the GM's
  reserve, through the root-only `check-psql` (see "The GM check role and
  the reserve"); its password is readable by root only.
- `pgbouncer_lookup`: PgBouncer's lookup role, with a pooler node only
  (see "The PgBouncer lookup role").
- `sudo`: `player` may run the three wrappers as root, with no arguments
  (`/etc/sudoers.d/gm-player`): `env_reset`, fixed `secure_path`, no
  syslog, log in `/run/gm/sudo.log`.

- Logs: `player` reads `/var/log/postgresql/*.log` through the group
  `pgconf` (files `0640`, directory `2750`), and runs pgBadger itself, with
  no wrapper and no `sudo` (access model 8), for example `pgbadger -o
  ~/pgbadger.html /var/log/postgresql/postgresql-*.log`. The report lands
  in its home; the players copy it to the bastion with `scp
  <node>:pgbadger.html .` (sshd's `internal-sftp` subsystem serves `scp`
  and `sftp`) and from the bastion to their machine with `sftp`.
- `monitoring`: the exporter's role (see "The monitoring role"); its
  password is readable on this node by root and `postgres` only, never by
  `player`.

The node has no web interface.

### Writable and protected paths, write policies

- Writable by the player: `/etc/postgresql` (`postgres:pgconf`, `2775`;
  seeded files `0664`; an in-place edit by renaming, such as `sed -i`,
  leaves a seeded file owned by `player` until the next reload, restart
  or container start puts `postgres:pgconf` `0664` back; files players
  add there are left as they made them), `/home/player` (`~/.pgpass`, rewritten at each
  start; `~/report.md`; pgBadger reports), and the scratch space `/tmp`
  and `/var/tmp`, both links to `/run/tmp` (root, `1777`, emptied at each
  start, see "Start-up").
- Readable, not writable, by the player: `/var/log/postgresql` (volume
  `pglog`, `postgres:pgconf`).
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player`, the entrypoint, the three
  wrappers, the snapshot helper and `check-psql` (both root only), the
  health check, the validator, the envelope file, the
  s6-overlay service definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`) and the seed marker's directory
  `/var/lib/gm-state`.
- Write policies: `fixable` only (v0.3 master spec 7.3; see "Known
  limits"); the node ignores `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES`.

### Wrappers

- Both `gm-reload-db` and `gm-restart-db` first give the seeded files
  (`postgresql.conf`, `pg_hba.conf`) their owner and mode back,
  `postgres:pgconf` `0664`, content untouched (v0.3 master spec 7.3 and
  16, release gate RG-2): a file a player's `sed -i` left owned by
  `player` is owned by `postgres` again. The file is opened without
  following a symlink and changed through the open file, so a symlink a
  player put in its place is never followed by root, and anything but a
  regular file is left alone. Other files in `/etc/postgresql` are not
  touched. The node is fixable only, so neither ever refuses as
  report-only.
- `gm-reload-db`: `pg_ctl reload` as `postgres`, then lists
  `pg_file_settings` and `pg_hba_file_rules` errors (including "needs a
  restart"). Exit 1 only if PostgreSQL is not running.
- `gm-restart-db`: checks `postgres -C data_directory` with the live files
  and `pg_hba_file_rules`, and that `max_connections` is more than
  `superuser_reserved_connections` plus the reserve's 2; refuses (exit 1)
  if any fails. Otherwise
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
`gmctl validate` go the same way. Sealed checks connect as `gm_check`
through `check-psql`, as root (`gmctl exec --node <node> --user root`).
`gmctl logs --node <node>` shows sshd and
the server's start-up only; the GM reads the server log through the exec
operation, for example `gmctl exec --node <node> --user postgres` running
`tail -n 50 /var/log/postgresql/postgresql-*.log`.

## Footprint

Default footprint in `brick.yaml`, in the shape of a scenario node's
`resources`: limits CPU `1` and memory `1G`; reservations CPU `0.5`,
memory `512M` and disk `2.25G` (v0.1's CPU and memory figures became the
reservations, the limits twice them; the disk is master spec 12's
database node with its log volume: data and WAL 1G, log volume 1G, home
and pgBadger reports 256M). No allowed range. It
excludes any material other bricks mount into the node: what that adds
per node is stated by the brick that ships it, and the GM adds it to the
node's `resources` in the scenario. The scenario sets each node's own
`resources` (limits for CPU and memory, reservations for CPU, memory and
disk), and `gmctl` uses those, never the brick's footprint. The renderer
applies the CPU and memory limits and reservations; disk is only counted
by the capacity check (`gmctl fit`: reservations plus 10 % headroom
against the playground); the volumes themselves have no size limit.
Disk growth per hour (`disk_growth_per_hour`): `8M`, the data a load
writes and the server log, measured (below); the WAL is not counted
there, since it stays within `max_wal_size`, part of the reservation.

What makes it grow:

- **Memory**: `shared_buffers`, plus `work_mem` for every sort or hash of
  every connection (up to `max_connections`), plus
  `maintenance_work_mem` for maintenance work. The default envelopes are
  sized for the default 512M reservation; shared memory too large for the memory
  limit keeps the server from starting.
- **Disk**: the restored data (`data/<node>.sql`) and its indexes in
  `pgdata`; WAL, up to `max_wal_size` (at most `1GB` in the default
  envelope), and without bound when a replication slot holds it (fault
  `pg-abandoned-replication-slot`); the server log in `pglog`, never
  pruned (one file per 10MB), growing with connections and with the
  statements over `log_min_duration_statement`; a few megabytes for the
  configuration, and about 1MB per pgBadger report in the player's home
  (810KB for the stack test's small log).
- **Memory**: a pgBadger run, within the node's own limits: a large run
  takes memory from PostgreSQL (master spec 7.5; measured below).
- **CPU**: the data load, the players' own queries and their pgBadger
  runs.

Size the disk reservation from the data file (with its indexes) plus
`max_wal_size` plus the expected log (1G covers a static database with
the reference settings), and the memory limit from the knobs' initial
values plus headroom for a pgBadger run. The levers that shrink it:
smaller knob values within their envelopes (a lower `shared_buffers`,
`max_connections` or `max_wal_size`), a scenario envelope tightened to
match, a smaller data file, and fewer logged lines (a higher
`log_min_duration_statement`, `log_connections` off).

Measured in the v0.2 game (`fernway-clinics-monitoring` on the `laptop`
playground, declared at 2 CPU / 4G / 8G on armenelos: AMD Ryzen 5 PRO
8640HS, 11.3 GiB, Docker 29.9.1; 2026-10-21; `docker stats`, the highest
of its samples, the node-health script included; the `clinic`
database, about 47 000 rows; the knobs at their initial values,
`shared_buffers` 128MB), under a 1G limit: at rest 11 to 15 minutes
after the deployment 59M and 0.05 CPU; during dashboard loads 52M; during a pgBadger run (`pgbadger -o
~/pgbadger.html /var/log/postgresql/postgresql-*.log` as `player`, a
190K log after 23 minutes of game, five runs, an 858K report each) 81M
and 0.18 CPU; at rest again after them 54M. The data load: 0.35 CPU over a
docker stats sample. Never OOM-killed nor restarted, never at its limit
(`memory.peak`, page cache included, 134M, most likely at the data load). Its
volumes after 35 minutes: `pgdata` 74M, `pglog` 0.2M, `home` 0.9M (the
report). A static database is far within the reservation; the levers above
matter when the data file or the log grows.

Measured in the v0.3 rehearsal (`tools/tests/rehearsal.sh`:
`tarnbeck-outdoor-shop` on armenelos, AMD Ryzen 5 PRO 8640HS, 11.3 GiB,
Debian 13, Docker 29.9.1, plus the VPS `vps-5718ad52`, 4 vCPU Intel
Haswell, 7.6 GiB, Docker 29.9.2; 2026-10-28; 46 minutes of load from T0
12:59Z to the hand-over check, the customer's noon peak from 13:00Z;
`docker stats` every 20 s, the node-health script included), with
`tarnbeck-outdoor-shop`'s `shop` database (176MB loaded, about 220 calls a
minute at the peak through PgBouncer and a few a minute from the back
office, autovacuum off on `orders` by fault f9) under a 1G limit and
`shared_buffers` 128MB: 206M at most (202M typical), 0.20 CPU at most
(0.12 at the 95th percentile). The `pglog` volume grew 0.7M an hour. The
`pgdata` volume shrank (515M to 488M) as the WAL the data load wrote was
recycled, which hides the data's own growth, so a second run measured it
on armenelos alone (same day, 30 minutes from the customer's 11:54, the
close-day batch's 20 000-row update at 12:00 included): the databases grew
2.3M (4.6M an hour), `orders` gaining 10 000 dead rows; the WAL stayed at
20 segments of 16MB. `8M` an hour covers both with a margin. The hand-over
snapshot of `pgdata` (`pg_basebackup`) was 206M.

### Snapshot

How each volume is copied at hand-over (`snapshot:` in `brick.yaml`; v0.3
master spec 6.4 and 7.3, capture W1 item 6):

- `pgdata`: `pg_basebackup`, an online base backup through the root-only
  helper `/usr/local/sbin/gm-snapshot-db` (no arguments, run as root
  through the exec verb: `gmctl exec --node <node> --user root`, a script
  running `/usr/local/sbin/gm-snapshot-db`); the server keeps running and
  the load goes on.
  - **Standard output**: a tar stream of the data directory, rooted at
    it (`PG_VERSION`, `backup_label`, `base/`, ...), holding the WAL the
    backup needs under `pg_wal/`. Restored as a `copy` is, by extracting
    it into an empty data volume (`tar --extract --numeric-owner
    --same-permissions`); the server completes the recovery at its next
    start, and the entrypoint's role sync runs first. Diagnostics, one
    `gm-snapshot-db: ...` line each, on standard error.
  - **Exit status**: 0 on success; pg_basebackup's own status when the
    backup fails (a broken connection, a reader that stops early); 1
    when the helper fails before or after it (no slot, the slot still
    there after the backup); 2 for arguments or a caller other than root.
  - **How**: `pg_basebackup -h /run/postgresql -U postgres -w -D - -F tar
    -X fetch --checkpoint=fast --no-manifest` as `postgres`, through the
    seed's `local replication postgres peer` line. `-X fetch` copies the
    WAL at the end of the backup, so a **temporary physical replication
    slot**, `gm_snapshot`, reserves the WAL from just before the backup
    starts: created with `pg_create_physical_replication_slot('gm_snapshot',
    true, true)` by a `psql` session of its own, which holds it and reads
    its commands from a FIFO in a work directory under `/run/gm`. Being
    temporary, the slot goes with that session, which ends when the
    helper closes the FIFO or exits in any way, a failure or a `SIGKILL`
    included (no child of the helper holds the FIFO open); on success the
    helper checks it is gone before exiting 0. A `SIGKILL` leaves only
    the helper's work directory in `/run/gm`, emptied at the next
    container start.
    `--checkpoint=fast` starts the backup at once instead of waiting for
    a spread checkpoint.
  - **What players may notice afterwards**: the server log records the
    checkpoint and the replication connection. Nothing stays: no slot,
    no file in `/run/gm`.
- `pgconf`, `home`, `gmstate`, `pglog`: `copy`, a tar of the volume while
  the node runs (`tar --create --file=- --numeric-owner --directory=<volume
  path> .`; exit 1, a file such as the log changing while read, is a copy).
- `run` (`/run`) is never copied.

Size of a snapshot: the data directory and the WAL segments written
during the backup, 16MB each, plus the other volumes' copies. The stack
test's small cluster gives a 41MB tar (one WAL segment), 2026-10-23.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59): a fault instance is accepted on a node when the fault's
`applies_to` names the node's brick and version (`tools/gm/model.py`).
This list is every catalog fault (`faults/`) whose `applies_to` names
`postgres` `0.3.0`, and no other; all also name `0.2.0`, and all but
`pg-stat-statements-not-preloaded` also name `0.1.0` and `0.1.1`. A scenario's
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
| `pg-stat-statements-not-preloaded` | seed file | the seed `postgresql.conf` (material `inject/postgresql.conf.snippet`) without `pg_stat_statements` in `shared_preload_libraries`, the logging settings above kept; the extension this version creates at initdb in database `postgres`; `gm-restart-db` for the fix (a reload is not enough); for its dashboard evidence, a `postgres-exporter` node with `--collector.stat_statements` |

Every state fault's scripts run as root and query as `postgres` over the
local socket, so they need the GM's `local all postgres peer` line in
`pg_hba.conf`; every sealed check needs it too.

Faults it lends itself to with no definition yet: a bloated table, and
other configuration, schema, role or state defects visible without
activity; and, from v0.2, monitoring faults of master spec 11.1 not chosen for
the v0.2 set: no slow-query log (`log_min_duration_statement = -1`), a
`log_line_prefix` pgBadger cannot parse or a non-English `lc_messages`
(seed `postgresql.conf`), and the role `monitoring` without `pg_monitor`
(state, after the data load; it overlaps
`pg-stat-statements-not-preloaded`).

Known interactions:

- The bastion's `~/.pgpass` supplies the `dba` password on every
  connection, so a `trust` line (`pg-hba-trust-remote`) goes unnoticed in
  ordinary use; its evidence connects with `PGPASSFILE=/nonexistent`.
- The `autovacuum` knob's envelope allows `on` only: turning autovacuum
  off server-wide turns the validator red, while the table-level
  `pg-table-autovacuum-off` leaves it green.
- A `postgres-exporter` node reveals from outside what the node's
  statistics show (`pg_stat_statements` included); a fault on the
  `monitoring` role or on preloading (`pg-stat-statements-not-preloaded`)
  hides it, so a fault found through `pg_stat_statements` or the
  PostgreSQL dashboard (`pg-join-index-missing`'s evidence is `EXPLAIN`
  and the index catalogue) never goes with it.
- A scenario with a `postgres-exporter` node lets `monitoring` in by
  `samenet` (or an address range) in `pg_hba.conf`; the fix of
  `pg-hba-trust-remote` must keep that line, or the exporter disconnects. pgBadger shows only what
  the logging settings let through.

Faults it cannot host: anything needing a standby or a replication peer
(the brick has the single role `database` and consumes nothing), and
anything visible only under load (the brick has no load generator): those
live in the nodes that make the load, below.

**Faults of other bricks read on this one** (v0.3 capture W4). Seven
catalog faults apply to `scheduler` 0.1.0 (`scheduler-query-error`,
`scheduler-update-without-where`, `scheduler-report-unbounded`,
`scheduler-insert-retry-duplicates`, `scheduler-transaction-held-open`,
`scheduler-batch-at-peak`, `scheduler-job-wrong-timezone`) and one to
`pgbouncer` 0.1.0 (`pgbouncer-pool-too-small`); none applies to
`postgres`, so none is listed above, but much of their evidence is read
here. A scenario using them gives this node a seed `postgresql.conf` with
the logging block above (`log_min_duration_statement`, `log_lock_waits =
on`, `log_temp_files = 0`, `log_autovacuum_min_duration = 0`) and
`pg_stat_statements` in `shared_preload_libraries` (players read it from
the bastion: rows per call, temporary blocks, mean time); the PostgreSQL
log and pgBadger readings are the scenario's, in its answer key.
`scheduler-insert-retry-duplicates`' sealed check connects to this node's
port 5432 as `gm_check` from the scheduler node (spec D185): the
scenario's `pg_hba.conf` admits it from the game network under its DO NOT
TAMPER comment (`host all gm_check samenet scram-sha-256`), beside the
`local` line every `postgres` 0.3.0 seed carries.

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
`tests/fixtures/`), checks v0.1 chunk 2's and v0.2 chunk 6's Done-when
(the file log in UTC on `pglog` readable by `player`, a pgBadger run as
`player` into its home, `pg_stat_statements`, the role `monitoring` with
`pg_monitor` and the secret's password, the secret out of `player`'s
reach; v0.3 chunk 4a's: the reserve on the command line and out of
`ALTER SYSTEM`'s reach, `gm_check` and `check-psql` with every ordinary
slot taken reading `pg_hba_file_rules`, two check sessions fitting and a
third refused, `gm-restart-db` refusing a `max_connections` that leaves
no room, the lookup role and its function, the roles brought back in a
new container; v0.3 chunk 4b's: a player's `sed -i` leaving
`postgresql.conf` owned by `player` and `gm-reload-db`, `gm-restart-db`
and a new container's start giving it its owner back, a symlink in
place of `pg_hba.conf` never followed, `gm-snapshot-db`'s tar with its
WAL, no slot left after it nor after a snapshot cut short, the tar
restored with the other volumes' copies into a fresh container of a
second stack, `gmtest-pgr`, that starts with the data and no slot), and
removes everything it created, volumes included.
Its seed has `max_connections = 10`, the envelope's minimum. Needs a
swarm manager and the image built.

The monitoring role, by hand, from the GM side: `gmctl exec --node <node>
--user postgres` running `psql -XAtc "select pg_has_role('monitoring',
'pg_monitor', 'member')"` (`t`); that the exporter actually connects is
the `postgres-exporter` brick's check.

## Known limits

- **Host key per container.** The sshd host key is generated at each
  container start. If the container is replaced, players see a changed
  host key on the inner hop.
- **`.pgpass` is rewritten** at each container start from the secret.
- **`gmctl logs` shows only the start-up.** With file logging, the server
  log leaves Docker's service logs: `gmctl logs` shows the lines before
  the logging collector starts and sshd's log; the GM reads the file log
  through the exec operation (see "What the GM uses").
- **The log is never pruned.** PostgreSQL rotates by size but keeps every
  file; the volume grows until the game ends. The disk reservation counts
  1G for it.
- **pgBadger shares the node's limits.** A large run competes with
  PostgreSQL for the node's memory and CPU.
- **The monitoring role is created once**, with a fresh `pgdata` volume:
  a cluster from an older image has no `monitoring` role, and a password
  changed in the secret is not applied to an existing cluster.
- **The reserve is not the GM's alone.** `dba`, a superuser, can take
  the superuser slots and use the reserve too (access model 11); and
  `gm_check` is put back only at a container start, so a `dba` who
  dropped it locks the sealed checks out until then (the GM's checks
  report an error, never "fixed").
- **Write policy**: only `fixable` (v0.3 master spec 7.3). A `report-only` node would need
  the configuration files not group-writable, decided at start from a
  value the renderer passes; not built.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
