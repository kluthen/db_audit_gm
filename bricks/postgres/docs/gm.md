# PostgreSQL brick — GM notes

GM documentation of the `postgres` brick (`brick.yaml`, master spec 9.1;
required sections: spec D56). Never shipped to players. Brick version
0.5.0, expected to evolve as games are played.

## Purpose

A PostgreSQL 18 database server on Debian 13 (trixie), with an SSH server
for the players, in the image `127.0.0.1:5000/dbagm/postgres:0.5.0`. It
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
  `vim-tiny`, `less`, `procps`. About 265MB (pgCluu included, 0.5.0).
- From 0.5.0, pgCluu 5.0 from the same repository (G9: `pgcluu=5.0-1.pgdg13+1`,
  build argument `PG_CLUU_PACKAGE`, pinned exactly and checked at build;
  not Debian's 4.0, which does not collect from PostgreSQL 17 and 18), a
  report tool beside pgBadger (master spec 7.4, O225): run on demand by
  the players, never a daemon or a node of its own. Its report CGI
  (`/usr/lib/cgi-bin/pgcluu.cgi`) and Apache configuration
  (`/etc/apache2/conf-available/pgcluu.conf`) are deleted at build and
  asserted gone; no `sysstat`, so the collector runs with `--disable-sar
  --disable-pidstat`. It brings `libjs-jquery` and `libjs-underscore` for
  the report's own pages (G9: CVE-2026-27601 in underscore, a recursion
  in the browser's JavaScript, not reachable here). Cosmetic: every run
  prints `Duplicate specification "no-sysinfo!"`; `--help` exits 1.
- From 0.4.0, for jobs on the node (see "`pg_cron`" and "The cron
  daemon"): `postgresql-18-cron` from the same repository, pinned exactly
  (`1.6.8-1.pgdg13+2`, build argument `PG_CRON_PACKAGE`, checked at build;
  security preflight G5), and Debian's `cron` (`3.0pl1-197` at the 0.4.0
  build, unpinned, without recommends, so no mail transfer agent). Both
  sit idle unless the scenario uses them. They add Debian's group
  `crontab` (gid 997), so `pgconf` is gid 996 from 0.4.0 (997 before).
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- Generic: no scenario content and no host keys in the image.

## Placement

- **What gets installed**: a node of its own, from the brick's image. The
  image must be on the engine that runs the game: deployment never pulls
  it (`gmctl deploy` deploys with `--resolve-image never`).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres`.
- **How many**: one per database node of the scenario. Each is its own
  container with its own volumes; the per-game secrets (`dba_password`,
  `monitoring_password`, `gm_check_password`, `pgbouncer_lookup_password`
  in a scenario with a pooler node, `player_ssh_pubkey`) are generated
  once per game, so every database node of a game gets the same values.
- **Next to which node**: any host. The node needs no other node on its
  host; in v0.2 the renderer still runs the whole game on one host (one
  host remains the only playground shape, master spec 8).
- **Stateful**: yes (`stateful: true`). Its volumes `pgdata`, `pgconf`,
  `home`, `gmstate`, `pglog`, `run` and `cronspool` (see "Configuration")
  must follow the node if it is replaced; otherwise the data, the
  players' changes, the seed marker, the server log and the crontab are
  lost.
- **Networks**: it must share a network with the bastion, which is the
  players' only way in (see "Connections"). Each network a scenario
  declares renders as `<game_id>_<network name>`; v0.2 scenarios declare
  one network, and the scripts refuse a second (master spec 6.3), so it
  shares it with every node.

## Configuration

`brick.yaml` declares two parameters, from 0.5.0, both default null:
`vault_target`, cold storage's `<host>:<port>`, and `vault_credential`,
the name of the credential `vault-post` sends (see "WAL archiving and the
nightly base backup"). Everything else scenario-specific reaches the node
through the seed files, the per-game secrets, the envelope file, the
node's choices (`write_policy`, `options:`, `standby_of:`) and the data
load.

### Values the GM sets per scenario and per game

| What | Where it lands | Set by |
|---|---|---|
| Seed files `postgresql.conf`, `pg_hba.conf` (`seed.files`) | `/opt/gm/seed/`, root `0444`, copied into `/etc/postgresql/` at first start | the scenario's `seed_files` (`nodes/<node>/...`) |
| Seed file `crontab` (`seed.optional`: a node may leave it out) | `/opt/gm/seed/crontab`, root `0444`, installed at first start as `postgres`'s crontab; its presence turns the cron daemon on | the scenario's `seed_files`, when the node runs a cron daemon (see "The cron daemon") |
| Envelope file (protected config `envelopes`) | `/opt/gm/protected/envelopes.conf`, root `0444` | `gmctl render`, from the node's `knobs` envelopes |
| Secret `player_ssh_pubkey` (kind `key-pair`, pair `player_ssh_key`, half `public`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy`: the public half of the bastion's `player_ssh_key` |
| Secret `dba_password` (kind `password`, not handed over) | `/opt/gm/secrets/dba_password`, root `0400` | `gmctl deploy`: the same secret as the bastion's |
| Environment `GM_WRITE_POLICY`, `GM_OPTIONS`, `GM_STANDBY_OF` | the container's environment, read by `gm-entrypoint` at each start (`GM_STANDBY_OF` also by `clone-standby`) | `gmctl render`: the node's `write_policy` (`fixable` or `no-access`, see "`no-access`"), the options it chooses, space-separated, `""` when none, and its `standby_of:`, `""` when it is no standby (v0.5 capture W1 item 0) |
| Environment `GM_VAULT_TARGET`, `GM_VAULT_CREDENTIAL` | written by `gm-entrypoint` into `/run/gm-vault/` for `vault-post` | `gmctl render`, from the parameters `vault_target` and `vault_credential`; absent when null |
| Secret `replication_password` (kind `password`, not handed over) | `/opt/gm/secrets/replication_password`, root `0400`; on every node | `gmctl deploy`; set on a primary by `load-data`'s clone step, read by a standby's entrypoint (see "The standby") |
| Secret `http_<credential>` (the vault's credential) | `/opt/gm/secrets/http_<credential>`, root `0400`, copied for `postgres` into `/run/gm-vault/credential` | mounted by `gmctl render` on a node naming `vault_credential` (wave 2's chunk 7; v0.5 capture W1 items 0, 3) |
| Secret `monitoring_password` (kind `password`, not handed over), brought by the option `monitoring` | `/opt/gm/secrets/monitoring_password`, uid `0`, gid `102` (`postgres`), `0440`: root and `postgres` only; mounted only on a node choosing the option | `gmctl deploy`: the same secret as the `postgres-exporter` node's (see "Option `monitoring`") |
| Secrets `tls_certificate` and `tls_key` (kind `certificate`, pair `tls`, halves `certificate` and `key`) | `/opt/gm/secrets/tls.crt`, root `0444`; `/opt/gm/secrets/tls.key`, uid `0`, gid `102`, `0440`; on every node | `gmctl deploy`: one self-signed pair per game, with the host's `openssl` (see "TLS") |
| Secret `gm_check_password` (kind `password`, not handed over) | `/opt/gm/secrets/gm_check_password`, root `0400`: root only | `gmctl deploy`; declared by this brick only (see "The GM check role and the reserve") |
| Secret `pgbouncer_lookup_password` (kind `password`, not handed over, `only_with_role: pooler`) | `/opt/gm/secrets/pgbouncer_lookup_password`, root `0400`: root only | `gmctl deploy`, only in a scenario with a `pooler` node: the same secret as the `pgbouncer` node's (see "The PgBouncer lookup role") |
| Secrets `role_<role>_password` (kind `password`, not declared in `brick.yaml`), one per role of the node's `crontab_roles` | `/opt/gm/secrets/role_<role>_password`, root `0400`; written into the crontab's password file at each start | `gmctl render`, from `crontab_roles` in `scenario.yaml`: the game's secret of that name, the one any scheduler node naming the role holds (spec D167) |
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
| Seed directory | `/opt/gm/seed/` | configs `postgresql.conf`, `pg_hba.conf` and, optional, `crontab`, read-only |
| Configuration | `/etc/postgresql/` | volume `pgconf`; `postgres:pgconf`, dir `2775`, seeded files `0664` |
| Seed marker | `/var/lib/gm-state/.gm-seeded` | volume `gmstate`; dir root `0755`, marker root `0444`; present means never seed again |
| PGDATA | `/var/lib/postgresql/18/data` | volume `pgdata` |
| Player home | `/home/player` | volume `home`; pgBadger reports land here |
| Server log | `/var/log/postgresql/` | volume `pglog`; `postgres:pgconf`, dir `2750` (setgid), files `0640` |
| Crontab's job logs | `/var/log/postgresql/cron/` | on `pglog`; `postgres:pgconf`, dir `2750` (setgid), a job's files `0644` |
| Cron spool | `/var/spool/cron/crontabs/` | volume `cronspool`; `root:crontab`, dir `1730`; `postgres`'s crontab `postgres:crontab` `0600` (`seed.paths.crontab`) |
| Crontab's password file | `/run/gm-cron/pgpass` | `postgres:postgres`, dir `0700`, file `0600`; absent with no crontab role |
| Standby's password file | `/run/gm-replication/pgpass` | `postgres:postgres`, dir `0700`, file `0600`; on a standby only, named by `passfile=` in `primary_conninfo` |
| Vault's files | `/run/gm-vault/target`, `/run/gm-vault/credential` | `postgres:postgres`, dir `0700`, files `0600`; only with `vault_target` (the credential only with `vault_credential`) |
| Posting command | `/usr/local/bin/vault-post` | root `0755`, on `PATH`, readable as a customer's tool (see "WAL archiving and the nightly base backup") |
| Standby's clone | `/usr/local/lib/gm/clone-standby` | root `0700`, run by `load-data` (see "The standby") |
| Runtime | `/run` | volume `run`, emptied at each start (see below) |
| Secrets | `/opt/gm/secrets/player_ssh_pubkey`, `/opt/gm/secrets/dba_password`, `/opt/gm/secrets/monitoring_password`, `/opt/gm/secrets/gm_check_password`, `/opt/gm/secrets/pgbouncer_lookup_password`, `/opt/gm/secrets/role_<role>_password`, `/opt/gm/secrets/tls.crt`, `/opt/gm/secrets/tls.key` | the monitoring password's only with the option `monitoring`; the lookup role's only with a pooler node; a role's for each of the node's `crontab_roles` |
| Account files | `/run/gm-accounts/{passwd,group,shadow,gshadow,sudoers-gm-player}` | written at each start from `/usr/local/lib/gm/accounts/`; `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow` and `/etc/sudoers.d/gm-player` link to them (see "`no-access`") |
| Envelope file | `/opt/gm/protected/envelopes.conf` | protected config `envelopes`, root, `0444` |
| Validator | `/opt/gm/validator/validate.sh` | |
| Wrappers | `/usr/local/sbin/gm-reload-db`, `gm-restart-db`, `gm-validate`, `gm-crontab` | |
| Entrypoint | `/usr/local/sbin/gm-entrypoint` | |
| Snapshot helper | `/usr/local/sbin/gm-snapshot-db` | root `0700`, not a `sudo` wrapper (see "Snapshot") |
| Health check | `/usr/local/lib/gm/healthcheck` | |
| Check role's `psql` | `/usr/local/lib/gm/check-psql` | root `0700`; the sealed checks connect through it (see "The GM check role and the reserve") |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |
| Socket | `/run/postgresql/.s.PGSQL.5432` | |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run`, writes the account files into `/run/gm-accounts`
   (the image's, or without `player` on a `no-access` node: see
   "`no-access`"), and recreates `/run/postgresql` (`postgres`, `2775`),
   `/run/sshd`, `/run/sshd-keys`, `/run/gm`, `/run/tmp` (`/tmp` and
   `/var/tmp` are symlinks to it).
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container if `GM_OPTIONS` names an option the brick does
   not declare, or if `player_ssh_pubkey` (not needed on a `no-access`
   node), `dba_password` or, with the option `monitoring`,
   `monitoring_password` is missing or empty, or if a password secret is
   not a single line. On a standby (`GM_STANDBY_OF` set): a value that is
   no node name, or `replication_password` missing or empty, fails it
   too; and with a vault, a `GM_VAULT_TARGET` that is no `<host>:<port>`
   or a `GM_VAULT_CREDENTIAL` whose secret `http_<credential>` is missing
   or empty. `gm_check_password` missing only logs a warning
   (another brick's test stack runs without it; a game always mounts
   it), and the check role is then neither created nor updated.
   `pgbouncer_lookup_password` is optional: mounted means a pooler node.
4. If `/var/lib/gm-state/.gm-seeded` is absent: copies the seed files into
   `/etc/postgresql/` and writes the marker. A missing seed file fails the
   container. If the node seeds a `crontab`, installs it the same once
   as `postgres`'s crontab, through Debian's `crontab -u postgres`, which
   checks it (a seed it refuses fails the container) and writes the
   header `crontab -l` leaves out. Never overwrites afterwards. The marker is on its own
   root-owned volume, out of reach of `player` and `postgres`: the
   configuration directory is group-writable without the sticky bit, so
   that editors saving by rename (`sed -i`) work, and a marker there could
   be removed. At every start, seeded or not, gives `postgresql.conf` and
   `pg_hba.conf` their seeded owner and mode back (`postgres:pgconf`,
   `0664`), as the wrappers do (see "Wrappers"); and gives the spool its
   `root:crontab` `1730`, and `postgres`'s crontab, when there is one,
   `postgres:crontab` `0600` (cron skips a crontab of another owner or
   mode; a symlink is left alone).
5. Sets `/var/log/postgresql` to `postgres:pgconf`, `2750` with the
   setgid bit, so every log file PostgreSQL writes there gets the group
   `pgconf` (the players' group); creates `/var/log/postgresql/cron/` when
   missing (anything but a directory there is removed first) and sets it
   the same.
6. If PGDATA is empty: `initdb` (UTF8, `C.UTF-8`, data checksums on by
   default in 18), then, in single-user mode, creates the role `dba`
   (`LOGIN SUPERUSER`, password from its secret), with the option
   `monitoring` the role `monitoring` (`LOGIN`, member of `pg_monitor`,
   password from `monitoring_password`), and the extension
   `pg_stat_statements` in the database `postgres`; then removes initdb's
   own `postgresql.conf` and `pg_hba.conf` from PGDATA, so the live files
   are only in `/etc/postgresql`. `pg_ident.conf` stays in PGDATA. The
   single-user session runs on initdb's configuration, before the seed's
   is ever read, with no preload library and no statement logged, even
   on an error: pgaudit, which a seed preloads, never sees these
   passwords (see "pgaudit"). The start-up log says
   `cluster initialised: roles dba and monitoring (option monitoring on)`
   or `roles dba (option monitoring off)`.
7. Creates or updates the GM's roles, at every start, in single-user
   mode before the server listens: the check role `gm_check` and, when
   `pgbouncer_lookup_password` is mounted, the lookup role
   `pgbouncer_lookup` with its schema and function (see the two sections
   below), except on a standby (`standby.signal` in PGDATA): single-user
   mode cannot run in standby mode, and the primary's roles reach it by
   replication (the log says `standby of <primary> (standby.signal): the
   GM's roles come from the primary`). Single-user mode runs on PostgreSQL's defaults
   (`config_file=/dev/null`), so a player's broken `postgresql.conf`
   does not stop it, with no preload library and no statement logged
   (the passwords). On a fresh cluster a failure fails the container;
   on an existing one it logs a warning and the roles stay as they were,
   rather than lock the players out of the node. Success logs
   `gm-entrypoint: GM roles up to date: gm_check pgbouncer_lookup`
   (`gmctl logs`).
8. Writes `/home/player/.pgpass` (`*:*:*:dba:<password>`, `0600`; not on
   a `no-access` node, whose home volume is left as it is) and,
   when a `role_<role>_password` secret is mounted, the crontab's
   password file (see "The cron daemon"). A secret of that form not
   naming a role (`[a-z_][a-z0-9_]*`), empty or not a single line fails
   the container. On a standby, writes the replication password file
   `/run/gm-replication/pgpass` (`*:*:*:replicator:<password>`); with a
   vault, `/run/gm-vault/target` and, with a credential,
   `/run/gm-vault/credential` (see "WAL archiving and the nightly base
   backup").
9. Execs s6-overlay's `/init`, which supervises `postgres`, `sshd` and
   `cron` (down on a node seeding no crontab).

Seeded once: the configuration files (first start on a fresh `gmstate`
volume) and the cluster with its role `dba`, the role `monitoring` with
the option, and the extension (first start on a fresh `pgdata` volume).
Rewritten at each start: `/run` and the account files, the sshd host
key, `~/.pgpass`, the crontab's password
file, and the GM's roles' attributes, memberships, grants and passwords.

PostgreSQL runs as
`postgres -D /var/lib/postgresql/18/data -c config_file=/etc/postgresql/postgresql.conf -c hba_file=/etc/postgresql/pg_hba.conf -c reserved_connections=2`
(the GM's reserve, see "The GM check role and the reserve"), with
`PG_OOM_ADJUST_FILE` and `PG_OOM_ADJUST_VALUE` in its environment (see
"The out-of-memory victim") and, from 0.5.0, `PATH` set by the run
script (`/usr/local/bin:/usr/bin:/bin:/usr/lib/postgresql/18/bin`), so
`archive_command` finds `vault-post`: s6 gives its services a minimal
environment.
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

### TLS

Always available, turned on by the seed (v0.5 master spec 7.1). Not an
option: a seed turning it off, or a `host` line where the policy demands
`hostssl`, is a fault to plant. The image is built `--with-openssl` and
needs no TLS package of its own (G5): OpenSSL comes with
`postgresql-common`, at or above the floor `libssl3t64
3.5.7-1~deb13u3` the build asserts; `postgres` is in the group
`ssl-cert`. `ssl-cert`'s snakeoil pair, the same in every game built from
the image, is deleted at build, and the build asserts it gone.

- **The pair**: one per game, the secrets `tls_certificate` and `tls_key`
  (kind `certificate`, pair `tls`), generated by `gmctl deploy` with the
  host's `openssl`, as `ssh-keygen` makes the key pairs: a self-signed
  certificate with a P-256 key, its subject `CN` the first `postgres`
  node, its subject alternative names every `postgres` node's name and
  `localhost`, valid 365 days from the deployment; files
  `secrets/tls.crt` and `secrets/tls.key`. Mounted on every `postgres`
  node: `/opt/gm/secrets/tls.crt` root `0444`, `/opt/gm/secrets/tls.key`
  root, group `postgres` (102), `0440`, which PostgreSQL accepts for a
  root-owned key (at most `u=rw,g=r`). Used only where a seed turns TLS
  on (17.5: the existing scenarios keep theirs, TLS unused). Nothing
  verifies a host name in v0.5, though a client may (`verify-full`
  against the certificate works for every node); an expiry inside a
  game is a fault to plant, never an accident.
- **The seed**: in `postgresql.conf`,

  ```
  ssl = on
  ssl_cert_file = '/opt/gm/secrets/tls.crt'
  ssl_key_file = '/opt/gm/secrets/tls.key'
  ```

  and in `pg_hba.conf`, `hostssl` lines for what must arrive encrypted
  (the portal's API reaching `records`), a `host ... reject` after them
  turning a plain connection away. The stack test's `rec`
  (`tests/fixtures/postgresql-v05.conf`, `pg_hba-v05.conf`) is the
  reference: TLS from the whole network, plain connections refused.
- **Seen**: `pg_stat_ssl` (`ssl`, `version`) for a session; `show ssl`;
  `openssl s_client -starttls postgres -connect <node>:5432` prints the
  certificate served. A node whose seed leaves `ssl` off answers a client
  asking for TLS "server does not support SSL".

### pgaudit

Always available, turned on by the seed (v0.5 master spec 7.1). Not an
option: removing the settings can be a fault. The package
`postgresql-18-pgaudit` is pinned exactly (`18.0-3.pgdg13+1`, upstream
18.0, G5), the build asserting its version and
`/usr/lib/postgresql/18/lib/pgaudit.so`.

- **The seed**: `shared_preload_libraries` naming it beside
  `pg_stat_statements` (a restart), and its classes. The stack test's
  `rec` seeds

  ```
  shared_preload_libraries = 'pg_stat_statements,pgaudit'
  pgaudit.log = 'ddl, role, write'
  pgaudit.log_catalog = off
  pgaudit.log_parameter = off
  pgaudit.log_relation = off
  pgaudit.log_statement_once = off
  ```

  Session auditing needs no `CREATE EXTENSION` (the stack test runs
  without one).
- **Where it writes**: the server log, as `LOG:  AUDIT:
  SESSION,<statement>,<substatement>,<class>,<command>,...` lines in the
  file log (`log_line_prefix` before them), which the players' group
  reads and pgBadger counts. Its volume weighs on the disk budget: each
  audited statement is a line, its text included; the domains' GM notes
  count it per class.
- **Passwords never reach the log**: the `role` class logs `CREATE
  ROLE`, `ALTER ROLE` and the user mappings with their text. pgaudit
  18.0 redacts a password there (`... password <REDACTED>`, which the
  stack test shows), but PostgreSQL's own statement logging
  (`log_statement`, `log_min_duration_statement`, an error's statement)
  does not, and G5 asked for neither to see them. So every secret this
  brick or `gmctl` writes into a database goes where neither can see
  it: `dba`'s and `monitoring`'s
  at initdb, before the seed's configuration is ever read (start-up step
  6); `gm_check`'s and `pgbouncer_lookup`'s in single-user mode on
  PostgreSQL's defaults, no preload library (step 7); `load-data`'s
  roles' passwords and user mappings in a session that sets
  `pgaudit.log = 'none'` beside statement logging off, a role's password
  as a SCRAM verifier (`inject.NO_AUDIT_SQL`); the replication role's
  likewise (see "The standby"). The stack test shows none of them in
  `rec`'s log, and a canary `ALTER ROLE ... PASSWORD` run with
  `log_statement = 'ddl'` and without the guard landing there in clear.

### Option `monitoring`

The brick's one option (v0.5 master spec 7.1, "Options"), declared in
`brick.yaml`'s `options:`: it brings the secret `monitoring_password`
(its entry under `secrets:` unchanged) and the role `monitoring`, a
member of `pg_monitor`, created at initdb. A scenario chooses it per node
with `options: [monitoring]`, and it is off unless chosen: the role and
its secret exist only on a node that chooses it, as every node a
monitoring brick targets (`postgres-exporter`, `pgwatch`,
`health-check`) does. Each option has its own section here; the player
documentation and the starter pack mention the role only when the
option is on.

- **Rendered**: `gmctl render` passes the node's options as
  `GM_OPTIONS` (`monitoring`, or `""`), and mounts `monitoring_password`
  only on a node choosing the option (`localimpl.node_secret_declarations`
  leaves out a secret an option the node does not choose brings); the
  `postgres-exporter` node, which declares the same secret, mounts it as
  before. A game whose `postgres` nodes all leave the option off has no
  `monitoring_password` at all, unless an exporter declares it.
- **At start**: `gm-entrypoint` refuses an option the brick does not
  declare, requires `monitoring_password` only with the option, and
  creates the role at initdb only then (start-up step 6; "The monitoring
  role" below).
- **Checked by `gmctl`** (chunk 6): a monitoring node targeting a node
  without the option is refused, unless a fault plants that gap; a fault
  may require the option (a lost `pg_monitor` grant).
- **Changed later**: choosing the option on a node whose `pgdata` already
  exists creates nothing; the role exists only on a cluster initialised
  with it.

### The monitoring role

Who creates the exporter's monitoring role and how its password reaches
the database (master spec 15, settled by the build of this brick):

- **Who and when**: this brick's start-up (`gm-entrypoint`, step 6), once,
  when it initialises a fresh `pgdata` volume on a node choosing the
  option `monitoring`, in single-user mode, before PostgreSQL first
  listens. Not the data load: the role exists before
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
- **Another database node's instance** (from 0.4.0; master spec 6.5 and
  7.2, capture W1-x): a check comparing two instances, run on one
  database node, reaches the other's with the other node's name first:

  ```
  /usr/local/lib/gm/check-psql --node <node> -d <db> -Atq -v ON_ERROR_STOP=1 <<'SQL'
  select ...;
  SQL
  ```

  `<node>` is the other node's name in the scenario, which the game
  network resolves (`[a-z]`, then `[a-z0-9-]`, not ending in `-`, at
  most 63 characters). It runs `psql -X -w -h <node> -p 5432 -U gm_check
  "$@"` over the game network, as `gm_check` with this node's secret
  (one password per game), the connection given up after 10 s
  (`PGCONNECT_TIMEOUT`). The other node's seed `pg_hba.conf` must admit
  `gm_check` from the game network, under its DO NOT TAMPER comment:
  `host all gm_check samenet scram-sha-256`, which every database node of
  a scenario with `governance:` keeps (v0.4 capture W1 item 1). Same
  streams and exit status as above; 2 also for `--node` without a node
  name, and psql's 2 for a node that does not answer. The connection
  lands in the other node's reserve like any `gm_check` session.
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

### The out-of-memory victim

The run script (`s6-rc.d/postgres/run`) exports
`PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj` and
`PG_OOM_ADJUST_VALUE=300` to the postmaster (master spec 7.2). PostgreSQL
writes the value into that file in every process it forks, right after
the fork: each backend and each background process (checkpointer,
autovacuum, the logger, `pg_cron`'s launcher and workers) runs at +300,
while the postmaster, s6, `sshd`, `cron` and the jobs cron starts stay
at 0. The kernel's out-of-memory killer picks the process of the
container's cgroup with the highest score, its memory plus
`oom_score_adj` in thousandths of the cgroup's limit: a backend outranks
any process at 0 unless that process holds 30 % of the limit more, and
among backends the largest dies. A process may raise its own score
without a capability; lowering one needs `CAP_SYS_RESOURCE`, which the
brick does not get, so a player cannot undo it from a backend. The
postmaster then ends the other backends and recovers in place (s6 keeps
the container; the health check needs only `sshd` once PostgreSQL has
accepted connections). Nothing changes in a game where memory never runs
out. The stack test reads +300 in a backend (`pg_read_file` of
`/proc/self/oom_score_adj`) and in every child of the postmaster, and 0
in the postmaster, s6, `sshd` and `cron`.

### The standby

A node in standby mode is a readable, asynchronous replica of a primary
named in the scenario (v0.5 master spec 6.2, 7.1, 11.1): `standby_of:
<primary>` on a `postgres` 0.5.0 node, the primary a `postgres` node that
is no standby itself, the standby with no `data:` entry (its data is the
clone). Its role stays `database`. Several standbys of one primary would
each get their slot; v0.5 builds one (`standby` in the clinic).

- **The replication role** `replicator`, `LOGIN REPLICATION`, not
  superuser, set on the primary by `load-data`'s clone step from the
  secret `replication_password` as a SCRAM verifier, with statement
  logging, pgaudit and `pg_stat_statements` off for the session: never
  created at initdb nor by a data file; it exists where a standby needs
  it. The secret is mounted on every `postgres` node (a spare secret costs
  nothing); only a standby reads it, into `/run/gm-replication/pgpass`,
  rewritten at each start. The password is never in `primary_conninfo`.
- **The slot**: physical, on the primary, named for the standby (its node
  name, `-` read as `_`); seen in the primary's `pg_replication_slots`
  (active) and `pg_stat_replication` (its sender, `application_name` the
  standby's name, `state` `streaming`).
- **The seeds**: the primary's `pg_hba.conf` carries `host replication
  replicator samenet scram-sha-256` (before any line rejecting the
  network); the standby's `postgresql.conf` sets `hot_standby_feedback =
  on` (and `hot_standby`, on by default), so the reports' long queries
  there are not cancelled, at the cost of vacuum held back on the
  primary. The stack test's `tests/fixtures/postgresql-standby.conf` and
  `pg_hba-v05.conf`.
- **The clone**, `load-data`'s last step (after every other, so the
  standby copies the checked load; before the aging), for each standby
  in topology order: on the primary, `replicator` created or updated
  and an inactive slot of the standby's name dropped (a rerun); then, as
  root in the standby, `/usr/local/lib/gm/clone-standby` (no arguments;
  it reads `GM_STANDBY_OF`): waits, bounded (120 s), for the primary to
  answer on 5432, its name resolving included, so a standby started
  before its primary waits for it; stops `postgres` (s6), empties PGDATA;
  `pg_basebackup -X stream -C -S <slot> -R -d "host=<primary> port=5432
  user=replicator passfile=/run/gm-replication/pgpass
  application_name=<standby>"` as `postgres` (`-R` writes
  `standby.signal`, `primary_conninfo` and `primary_slot_name` into
  `postgresql.auto.conf`; the helper refuses a `primary_conninfo` holding
  a password); starts `postgres`, and waits, bounded, until it answers in
  recovery. Exit 0 on success, 1 when a step fails (the node left down: a
  failed setup), 2 for a usage error. `load-data` then waits, bounded by
  its `--timeout` (300 s without one), until the primary's
  `pg_stat_replication` shows the slot's sender `streaming`. Any failure
  is a failed setup. Every other `load-data` step skips a standby: no
  data file, password, grant, survey, mapping or log clean-up runs there;
  a role a schedule names on a connection to the standby gets its
  password on the primary.
- **After**: the standby restarts as a standby (its `standby.signal`
  stays), its password file rewritten, its start skipping the GM's roles
  step: `dba`, `monitoring`, `gm_check` and `replicator` are the
  primary's, replicated, so `check-psql` works there with the game's
  `gm_check_password`. It answers read-only queries (`dba` over TLS
  where its seed turns it on); a write is refused ("cannot execute ... in
  a read-only transaction"). The players may change its own settings
  (`fixable`) and never promote it (access model 5).
- **The hand-over snapshot** works on both: on the primary the temporary
  slot `gm_snapshot` comes and goes beside the standby's, which stays;
  on the standby `gm-snapshot-db` takes its base backup from the standby
  itself (see "Snapshot").
- **The fault `pg-abandoned-replication-slot`** applies beside a standby
  when its slot is an orphan: its `slot-name` is not the standby's (see
  "Supported faults").

### WAL archiving and the nightly base backup

The vault is cold storage itself, types `wal` and `basebackup` (v0.5
master spec 10.4, 11.2): plain PostgreSQL tools, and the brick's small
posting command they call, `vault-post`, on the same trust line as every
seed script. The vault discards the payload; nothing is restored in
v0.5. Which instances archive and send a base backup is the scenario's
(the clinic: `records` and `lab` both, `machines` the base backup only).

- **The seed** (`postgresql.conf`):

  ```
  archive_mode = on
  archive_command = 'vault-post wal %f %p'
  archive_timeout = 1h
  ```

  `archive_timeout` makes a quiet night still ship, once an hour. A
  standby does not archive with `archive_mode = on`.
- **The nightly base backup**: a line of the node's seed `crontab`, in
  the crontab's baseline form, low hours, scenario time (render shifts
  it to UTC), with `PATH` on a line of its own (cron's default finds
  neither command):

  ```
  PATH=/usr/local/bin:/usr/bin:/bin:/usr/lib/postgresql/18/bin
  30 3 * * * pg_basebackup -h /run/postgresql -D - -Ft -X fetch | vault-post basebackup "<node>-$(date -u +\%Y\%m\%dT\%H\%MZ)" >> /var/log/postgresql/cron/basebackup.log 2>&1
  ```

  It connects as `postgres` through the seed's `local replication
  postgres peer` line, and posts the tar whole: `vault-post` spools it to
  `/run/tmp` first, and refuses one without tar's end-of-archive blocks
  (a `pg_basebackup` that failed midway). Its receipt or its refusal goes
  to `cron/basebackup.log`, which the players read.
- **`vault-post <type> <name> [<file>]`**, `/usr/local/bin/vault-post`,
  Perl with core `HTTP::Tiny` and `JSON::PP` (no package added, G5; the
  build asserts `perl -MHTTP::Tiny -e 1`): `<type>` `wal` or
  `basebackup`, `<name>` the segment's file name or the backup's name,
  the payload `<file>` (`%p`, relative to the data directory) or standard
  input. Its vault: `/run/gm-vault/target` and `credential`, which the
  entrypoint writes from `vault_target`, `vault_credential` and the
  secret `http_<credential>`; with no target it exits 1, "no vault
  configured" (an archiving seed on a node with no vault fills `pg_wal`:
  a design error, or a fault to plant).
  - **The request**: `POST http://<target>/shipments`, the payload's
    bytes as the body (`application/octet-stream`, `Content-Length`),
    headers `Shipment-Id` and `Shipment-Name` (the name),
    `Shipment-Type`, `Shipment-Rows` (`1`), `Shipment-From` and
    `Shipment-To` (the posting day, UTC), `Shipment-Source` (the node's
    name), and `Authorization: Bearer <credential>` when there is one;
    `User-Agent: vault-post (<node>)`. Timeout 60 s.
  - **Honest failure**: exit 0 only on a 2xx JSON receipt naming the
    shipment (`shipment_id`) whose `size` equals the bytes sent (the
    receipt: `{shipment_id, type, rows_declared, rows_received, size,
    received_at}`). Anything else (a refusal, a timeout, no connection, a
    short or foreign receipt) exits 1 with one `vault-post: ...` line on
    standard error saying why, in the server log for `archive_command`:
    PostgreSQL keeps the segment (`pg_wal/archive_status/<segment>.ready`),
    counts the failure in `pg_stat_archiver` and retries. Exit 2 for a
    usage error. A success prints one `vault-post: <type> <name>
    shipped, <n> bytes` line.
- **Seen**: `pg_stat_archiver` (`last_archived_wal`, `failed_count`,
  `last_failed_wal`), the server log, `cron/basebackup.log`, and cold
  storage's manifests and page (each manifest names its node).

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
exec` (see "Access"). The one exception is a sealed check comparing two
instances: from this node, `check-psql --node <node>` reaches another
database node's `sql` interface as `gm_check` (see "The GM check role and
the reserve"); the scenario's network and that node's `pg_hba.conf` must
allow it.

**Jobs**: `pg_cron` and the cron daemon reach nothing outside the node:
their jobs connect over the local socket (see "`pg_cron`" and "The cron
daemon").

## Access

### Accounts and access

- `player`: SSH by public key only (`AuthorizedKeysFile` points at the
  secret; no password, no PAM), member of `pgconf`. sshd sets
  `PGUSER=dba` and `PGDATABASE=postgres`. No TCP, agent or X11 forwarding.
  None on a `no-access` node (see "`no-access`").
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
- `sudo`: `player` may run the four wrappers as root
  (`/etc/sudoers.d/gm-player`), the first three with no arguments,
  `gm-crontab` with any (it checks its own: see "Wrappers"):
  `env_reset`, fixed `secure_path`, no syslog, log in `/run/gm/sudo.log`.
- The crontab roles (`crontab_roles`): customer roles a crontab entry
  connects as, through the password file only `postgres` reads; their
  passwords are set by `load-data` (chunk 7) from the same secrets.

- Logs: `player` reads `/var/log/postgresql/*.log` through the group
  `pgconf` (files `0640`, directory `2750`), and runs pgBadger itself, with
  no wrapper and no `sudo` (access model 8), for example `pgbadger -o
  ~/pgbadger.html /var/log/postgresql/postgresql-*.log`. The report lands
  in its home; the players copy it to the bastion with `scp
  <node>:pgbadger.html .` (sshd's `internal-sftp` subsystem serves `scp`
  and `sftp`) and from the bastion to their machine with `sftp`.
- pgCluu, the same way (O225): `player` runs `pgcluu_collectd` itself,
  as `dba` (its `~/.pgpass`), for the window it chooses (`-E`), with a pid
  file of its own (`-f`), then `pgcluu -o <directory>` writes the report into
  a directory of its home, which must exist;
  no wrapper, no `sudo`, no sudoers rule (G9: `pgcluu_collectd` builds
  shell commands from its arguments, so it never runs as root). A
  collection is a few queries every `-i` seconds on the node, inside its
  limits; the fixture short test (`tools/tests/smoke-monitoring-v05.sh`)
  runs one of 30 s and copies the report to the bastion with `scp`.
- `monitoring`: the exporter's role, on a node choosing the option
  (see "The monitoring role"); its password is readable on this node by
  root and `postgres` only, never by `player`.

The node has no web interface.

### `no-access`

The write policy of a third party's node (v0.5 master spec 10.2; the
partners' shared database), made real: the node has **no `player`
account, no `sudo` rules and no `~/.pgpass`**. `sshd` still runs (the
health check and `processes` unchanged), but no account can log in;
PostgreSQL serves the partners' own roles as its seed `pg_hba.conf`
admits them (only theirs, on their database, every other line for the
network a `reject`).

How, on a read-only root: `/etc/passwd`, `/etc/group`, `/etc/shadow`,
`/etc/gshadow` and `/etc/sudoers.d/gm-player` are links into
`/run/gm-accounts`, which `gm-entrypoint` writes first at each start
(step 1) from the image's copies in `/usr/local/lib/gm/accounts`: as
built on any other node; on a `no-access` node without `player`'s line,
without its group and without it among `pgconf`'s members, and with no
sudo rules file (sudo's `@includedir` skips the dangling link). The
image's own `/run/gm-accounts` holds the files as built, because the
Docker daemon resolves `docker exec -u postgres` (`gmctl exec`) from the
image's root filesystem, where the `/run` volume is not mounted; inside
the container the volume hides that copy. So `gmctl exec --user postgres`
works on every node, and `docker exec -u player` on a `no-access` node
would still find a uid from the image's copy: the GM's own doing, not a
player's.

`GM_WRITE_POLICY` is read at start only for this: on a `fixable` node
nothing else changes (see "Writable and protected paths, write
policies").

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
  `pglog`, `postgres:pgconf`), the crontab's job logs in its `cron/`
  included.
- Changed only through `gm-crontab`: `postgres`'s crontab in the spool
  `/var/spool/cron/crontabs` (volume `cronspool`), not in
  `writable_paths`: v0.3's owner-and-mode rule for writable paths would
  rewrite the modes cron checks. A crontab fault's fix needs no
  override: the node is fixable.
- Protected (root-owned, read-only to the player): `/etc/ssh/sshd_config`,
  `/etc/sudoers`, `/etc/sudoers.d/gm-player` (a link to the copy in
  `/run/gm-accounts`), the account files' copies in
  `/usr/local/lib/gm/accounts`, the entrypoint, the four
  wrappers, the snapshot helper and `check-psql` (both root only), the
  health check, the validator, the envelope file, the
  s6-overlay service definitions (`/etc/s6-overlay/s6-rc.d`,
  `/etc/s6-overlay/user-bundles.d`) and the seed marker's directory
  `/var/lib/gm-state`.
- Write policies: `fixable` (v0.3 master spec 7.3; see "Known limits")
  and, from 0.5.0, `no-access` (see "`no-access`"); the node reads
  `GM_WRITE_POLICY` for `no-access` alone and ignores
  `GM_WRITE_OVERRIDES`.

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
- `gm-crontab -l`: `crontab -u postgres -l` (exit 1 and `no crontab for
  postgres` when there is none). `gm-crontab <file>`: reads `<file>` as
  `player` (`runuser -u player -- cat`, so a file `player` cannot read is
  refused and nothing of a root-only file reaches an error line) into a
  root-only work file under `/run/gm`, then `crontab -u postgres`
  checks and installs it (`postgres:crontab` `0600`, with crontab's
  header); exit 0, `gm-crontab: <file> installed as postgres's crontab;
  cron reads it within the minute.`; exit 1 when the file cannot be read
  or crontab refuses it (crontab's own lines, then `gm-crontab: crontab
  refused <file>; the crontab is unchanged`), or on a node seeding no
  crontab, where no daemon runs (`gm-crontab: this node runs no cron
  daemon (its scenario seeds no crontab); nothing installed`); exit 2 for
  any other arguments (none, two, `-e`, `-r`, `-u ...`, a lone `-`: the
  sudoers line allows any, so the wrapper checks them).

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
- **Jobs on the node** (from 0.4.0): a `pg_cron` job's run is a
  background worker and a cron daemon's job a shell, `psql` and the
  backend it connects to, all within the node's limits: a heavy job
  takes memory and CPU from PostgreSQL and can exhaust the memory limit
  (see "The out-of-memory victim"). The default footprint is unchanged
  for them; a scenario with jobs sizes the node for its heaviest run.

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

At rest with jobs, from 0.4.0 (the stack test, armenelos, Docker 29.9.1,
2026-10-30, `docker stats` once at the end of each of two runs, a 512M
limit, the test's small clusters): `db`, seeding neither `pg_cron` nor a
crontab, 32.2 to 32.6MiB and at most 0.02 CPU; `db2`, with `pg_cron`
preloaded (its launcher and a job every 5 seconds) and the cron daemon
(an entry every minute), 28.8 to 30.9MiB and 0.03 CPU. The jobs' own
weight at rest is within the measurement's noise: the cron daemon 2.5MB
resident, the `pg_cron` launcher 16.7 to 16.9MB resident, mostly shared
memory. The rehearsal measures them in a game.

At rest in 0.5.0, a first figure (the stack test, armenelos, 2026-11-03,
`docker stats` once at the end of a run, a 512M limit, the test's small
clusters): `rec`, a primary with TLS and pgaudit on, the option
`monitoring`, WAL archiving to the vault, a base-backup job and a
standby streaming from it, 32.4MiB and no measurable CPU; its standby,
`standby`, in recovery with `hot_standby_feedback` on, 36.2MiB; `pdb`, a
`no-access` node, 30.8MiB; `db` and `db2` as in 0.4.0 (32.4 and
29.3MiB). Each node's CPU at that moment was at most 4.3 % (a check's
psql in flight). On disk after the run: `rec`'s `pgdata` 136M, 113M of
it `pg_wal` (`max_wal_size` 512MB in the test seed, the segments the
test switched and the archiver's retries), its log 92K with pgaudit's
lines; the standby's `pgdata` 152M; a base backup of `rec` posted 41.4MB.
TLS, pgaudit and archiving cost nothing visible at rest; their cost is
under load (pgaudit's lines in `pglog`, a segment posted each time one
fills or each hour, a base backup a night in `/run/tmp` while it posts),
measured by the domains' runs (master spec 14).

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
- `pgconf`, `home`, `gmstate`, `pglog`, `cronspool`: `copy`, a tar of the
  volume while the node runs (`cronspool`: the crontab as the players
  left it; its owner and modes come back at the restored node's start) (`tar --create --file=- --numeric-owner --directory=<volume
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
`postgres` `0.5.0`, and no other; all also name `0.4.0`. The v0.4 database-node faults
(`security-crontab-superuser`, `purpose-day-boundary-wrong-zone`,
`governance-personal-copied`, `purpose-etl-role-expired`,
`purpose-heavy-job-on-database-node`) name `0.5.0` and `0.4.0` only; all others also name `0.3.0` and `0.2.0`, and all of those but
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
| `pg-abandoned-replication-slot` | state, after the data load | parameter `slot-name`; an orphan slot: no standby of the node, or a `slot-name` other than its standby's slot (from 0.5.0, master spec 6.4); a seed `postgresql.conf` that allows a physical slot (`wal_level` `replica` or above, `max_replication_slots` above 0: PostgreSQL's defaults); writes, for the retained WAL to grow |
| `pg-stat-statements-not-preloaded` | seed file | the seed `postgresql.conf` (material `inject/postgresql.conf.snippet`) without `pg_stat_statements` in `shared_preload_libraries`, the logging settings above kept; the extension this version creates at initdb in database `postgres`; `gm-restart-db` for the fix (a reload is not enough); for its dashboard evidence, a `postgres-exporter` node with `--collector.stat_statements` |
| `security-crontab-superuser` | seed file (`crontab`) | the cron daemon (a seeded `crontab`, material `inject/crontab.snippet`: an entry's `-U <role>` removed, so `psql` runs as `postgres` by peer); parameter `role`, in the node's `crontab_roles` and created by its data file with the entry's grant; `log_connections = on` for the evidence; the sealed check reads cron's spool as root and `rolsuper` through `check-psql` |
| `purpose-day-boundary-wrong-zone` | seed file (`data`, spec D226) | the node's data file holding the sales reporting purpose's target part, `rpt.close_day()` replaced after it (material `inject/close_day.sql.snippet`, its zone from `load-data`'s `customer_utc_offset` plus parameter `offset`); the sealed check (`judges: runs`) reads `rpt.etl_runs` here and the source's orders through `check-psql --node` |
| `governance-personal-copied` | seed file (`data`, spec D226) | the node's data file creating `pg_cron` (preloaded by the seed `postgresql.conf`), then the snippet `inject/customer_activity.sql.snippet`: a second foreign server, its user mapping (password from the remote role's secret, set by `load-data`), a foreign table, the copy and a `pg_cron` job; the scenario's `governance:`; the sealed check calls the governance check set (G1, G3) and reads `cron.job` through `gm_check_read` |
| `purpose-etl-role-expired` | state, during the aging | parameter `role`: the purpose's source role, a login role the data file creates, given `VALID UNTIL` the planting moment and its sessions ended; its check reads `pg_roles`, this node's server log (`postgresql-*.log`, the seed's `log_line_prefix` and UTC, English messages) and the run ledger `rpt.etl_runs` on the purpose's target instance with `check-psql --node` (`judges: runs`, R4), so that instance's `pg_hba.conf` admits `gm_check` from the game network |
| `purpose-heavy-job-on-database-node` | seed files (`data`, spec D226; `crontab`), then state during the aging | the node's data file holding the sales reporting purpose's target part, then `inject/sales_detail_rollup.sql.snippet` (the roll-up's foreign table, request and document tables, `rpt.sales_detail_rollup()`); the cron daemon (a seeded `crontab` with the entry of `inject/crontab.snippet`, the loader in `crontab_roles`); the backends' raised OOM score (`PG_OOM_ADJUST_VALUE`, "The out-of-memory victim" above), so the kernel kills the roll-up's backend and the postmaster recovers; parameters `database`, `days` (the backfill request's window, inserted by `inject/10-backfill-request.sh`); a memory limit the window exceeds twice over; `needs_unshared_host`; the sealed check (an incident check, 1 or an error, never 0 or 3) reads the request through `check-psql` and this node's server log (the seed's `%t` prefix in UTC, English messages) |

Every state fault's scripts run as root and query as `postgres` over the
local socket, so they need the GM's `local all postgres peer` line in
`pg_hba.conf`; every sealed check needs it too.

Faults it lends itself to with no definition yet: from 0.4.0, the other
jobs' faults of "`pg_cron`" and "The cron daemon" below; a bloated table, and
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
catalog faults apply to `scheduler` 0.3.0, 0.2.0 and 0.1.0 (`scheduler-query-error`,
`scheduler-update-without-where`, `scheduler-report-unbounded`,
`scheduler-insert-retry-duplicates`, `scheduler-transaction-held-open`,
`scheduler-batch-at-peak`, `scheduler-job-wrong-timezone`) and one to
`pgbouncer` 0.1.1 and 0.1.0 (`pgbouncer-pool-too-small`); none applies to
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
`local` line every `postgres` 0.5.0 seed carries.

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
two-service stack (`tests/stack.test.yml`, test fixtures in
`tests/fixtures/`): `db`, seeding neither `pg_cron` nor a crontab, as a
0.3.0 node, and `db2`, the node with jobs (`postgresql-jobs.conf`
preloading `pg_cron`, `pg_hba-jobs.conf` admitting only `gm_check` from
the network, the seed `crontab`, the crontab role `cron_app`'s secret).
It checks v0.1 chunk 2's and v0.2 chunk 6's Done-when
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
second stack, `gmtest-pgr`, that starts with the data and no slot; v0.4
chunk 4a's: on `db` the service `cron` down and `gm-crontab` refusing to
install, on `db2` the daemon up as root after `postgres` and stopped
before it, the seed crontab installed once in the spool with cron's
owners and modes, its entry running as `cron_app` through the password
file and appending to its log under `/var/log/postgresql/cron/`, which
`player` reads and cannot write, `gm-crontab` listing, refusing bad
arguments, a root-only file and a bad crontab, and replacing the crontab,
the replacement running and surviving a new container, an empty crontab
leaving the daemon up, `pg_cron` preloaded and a job scheduled with
`username => 'cron_app'` running as that role into
`cron.job_run_details`; v0.4 chunk 4b's: +300 in every child of the
postmaster and 0 in the postmaster, s6, `sshd` and `cron`, on both
nodes, and `check-psql --node` both ways, its refusals and its
timeout; v0.5 chunk 3a's: the image's G5 conditions (pgaudit's exact
pin and library, the OpenSSL floor, no snakeoil pair), `rec`, the v0.5
primary (`postgresql-v05.conf`, `pg_hba-v05.conf`), serving TLS with the
game's certificate made by `gmctl deploy`'s own generator (`verify-full`
against it, its fingerprint on the wire) and turning plain connections
away, `db` refusing TLS (its seed leaves it off), pgaudit's classes in
the file log and readable by `player`, no password of `dba`,
`monitoring`, `gm_check` or a role `load-data` sets (its own SQL, from
`tools/gm/inject.py`) in that log and no SCRAM verifier either, the role
`monitoring` on `db` and `rec` (the option) and neither it nor its
secret on `db2`, an unknown option refused, and `pdb`, a `no-access`
node (`pg_hba-partners.conf`): no `player` account, group, membership,
sudo rules, `~/.pgpass` or SSH login, `sshd` and PostgreSQL up, `gmctl
exec` as `postgres` working, `dba` rejected from the network; v0.5
chunk 3b's: `standby`, cloned from `rec` the way `load-data` does it
(`inject.replication_sql`, `clone-standby`, `inject.streaming_sql`),
started while `rec` is down so the clone waits for it, then in recovery
with `hot_standby_feedback` on, streaming from its slot `standby` in
`rec`'s `pg_stat_replication`, answering a read over TLS and refusing a
write, holding the primary's roles, its `primary_conninfo` naming the
password file only, streaming again in a new container whose start skips
the roles step, the hand-over snapshot on both nodes leaving only the
standby's slot, and no replication password in either log; `rec`'s
`archive_command` posting a switched segment to `vault` (a stand-in for
cold storage, `tests/fixtures/vault-standin.pl`, run by the image's own
Perl) whole with every header and the credential, a refusal and a short
receipt failing honestly (the segment kept as `.ready`, `vault-post`'s
reason in the server log, `pg_stat_archiver`'s failures), then shipped
on the retry; `vault-post` with no vault (exit 1) and a bad usage (exit
2); the base-backup job moved to the next minute, posted once, whole,
its receipt in `cron/basebackup.log`), and removes everything it
created, volumes included. No job is run by hand: each waits for its
schedule (the base backup's moved one included); time is placed, never
waited for: a WAL segment is switched by the test. A run takes a few
minutes, well under 30.
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
- **The monitoring role is created once**, with a fresh `pgdata` volume
  on a node choosing the option: a cluster from an older image, or one
  initialised without the option, has no `monitoring` role, and a
  password changed in the secret is not applied to an existing cluster.
- **The reserve is not the GM's alone.** `dba`, a superuser, can take
  the superuser slots and use the reserve too (access model 11); and
  `gm_check` is put back only at a container start, so a `dba` who
  dropped it locks the sealed checks out until then (the GM's checks
  report an error, never "fixed").
- **Write policy**: `fixable` and `no-access` (v0.3 master spec 7.3, v0.5 10.2). A `report-only` node would need
  the configuration files not group-writable, decided at start from a
  value the renderer passes; not built.
- **Stop timing**: s6 gives services 8 s to stop, inside Docker's default
  10 s stop grace period.
- **Node-health cannot watch `cron`** in v0.4: `processes` stays
  `[postgres, sshd]`, since a node-health entry `default` expands to it
  and `cron` is down by design on every node seeding no crontab; the
  loader refuses an entry naming a service outside `processes` (capture
  W1 item 8). A dead cron daemon shows only as jobs that stop running.
- **Cron logs nowhere of its own**: no syslog and no mail, so a job's
  failure is visible only in the log its entry writes, if any.
- **Any OS user may run `crontab`** (no `cron.allow`, spec D211):
  `postgres`, reached by `dba`, changes the crontab `gm-crontab` changes,
  and `player` could install a crontab of its own in the spool, which
  cron would run as `player` on a node with a daemon. Neither gives more
  than those accounts already have; the checks read `postgres`'s
  crontab only.
- **`gm-crontab` on a node without a daemon** refuses a replacement:
  turning the daemon on is the scenario's seed, not the players'.
- **The base backup's own errors go nowhere**: the crontab line's
  `>> ... 2>&1` applies to `vault-post`, the pipeline's last command;
  `pg_basebackup`'s messages are lost (no mail). Its failure still shows:
  `vault-post` refuses a tar without its end-of-archive blocks, or
  nothing on standard input, and says so in `cron/basebackup.log`.
- **`vault-post` spools a base backup** to `/run/tmp` (the `run` volume)
  before posting it, so the node needs room for one backup there, for
  the time of the post.
- **An archiving seed without a vault** fills `pg_wal`: every segment
  waits for an `archive_command` that exits 1 ("no vault configured").
  The scenario gives every archiving node `vault_target`.
- **The standby's clone is `load-data`'s**, and a restart with no
  snapshot clones it again (its load steps). **A restart restoring the
  hand-over snapshot does not bring a standby back as one**: a base
  backup leaves out `standby.signal` (so the restored standby would start
  as a primary of its own) and `pg_replslot/` (so the restored primary
  has no slot for it), and the two copies are taken at different
  moments. Such a game needs the standby cloned again after the restore;
  not built in 0.5.0 (reported for the restart's owner).
- **`docker exec -u player` on a `no-access` node** resolves from the
  image's account files, not the container's (see "`no-access`"): the
  GM's own doing; no player reaches the node.

## `pg_cron`

**What it is**: the PostgreSQL extension `pg_cron` (PGDG package
`postgresql-18-cron` 1.6.8, pinned), which runs SQL on a schedule from
inside the server: a launcher, one background worker, reads the jobs
from its tables and starts a background worker per run. The image ships
the library and the extension's files only; nothing runs until a seed
preloads it (master spec 7.2). It needs no `brick.yaml` entry.

**How a scenario turns it on**: the seed `postgresql.conf` and the data
file, as `pg_stat_statements`:

```
shared_preload_libraries = 'pg_stat_statements,pg_cron'
cron.database_name = 'shop'              # the database holding its tables; one the data file creates
cron.use_background_workers = on         # a job runs as its role: no password, no pg_hba.conf line
cron.timezone = '{{customer_timezone}}'  # render fills in the bare zone (8.5)
cron.log_run = on                        # cron.job_run_details; a check on its runs needs it (12.5)
cron.log_statement = on                  # a log line per run, in the file log and pgBadger
```

The data file creates the extension in `cron.database_name` as
superuser (`CREATE EXTENSION pg_cron`, written at the start of a line,
which the loader reads) and schedules each job with
`cron.schedule_in_database(<name>, <schedule>, <command>, <database>,
username => <role>)`, the job then running as that role. Jobs are rows,
so the restored backup carries them, and the hand-over snapshot with it.
The loader checks that a data file creating `pg_cron` belongs to a node
whose seed preloads it and that `cron.database_name` names a database
that file creates; a fault may still remove the preload. The stack test
shows it on db2 (`tests/fixtures/postgresql-jobs.conf`).

From boot until the data file has created `cron.database_name`, the
preloaded launcher cannot connect: it exits (`FATAL:  database "..." does
not exist`, then the postmaster's `background worker "pg_cron launcher"
(PID n) exited with exit code 1`) and is restarted about once a second.
The brick cannot avoid it (creating the database at start-up would fail
the data file's `CREATE DATABASE`; holding the preload back would fail its
`CREATE EXTENSION`, which loads the library only when preloaded), so
`load-data`, last, waits for the launcher to be connected, has the
collector switch files and removes those lines, and only those, from the
files it closed (`tools/gm/inject.py`): the players' log holds none.

**What players and the GM see**: `\dx`, the preload, `cron.job` (the
jobs) and `cron.job_run_details` (start, end, status, message, while
`cron.log_run` is on). Both tables show a role its own jobs only, unless
it is a superuser or bypasses row-level security: `dba` sees them all;
`gm_check` reads them through a read policy `load-data` adds where the
extension exists (chunk 7). Changing them: `cron.schedule`,
`cron.unschedule`, `cron.alter_job` and the settings, as `dba`.

**Its cost**: the launcher (one background worker, about 17MB resident in
the stack test, most of it the server's shared memory, which the
container counts once), and one background worker per run while it runs, out
of `max_worker_processes` (8 by default, the other background workers
included): at most eight jobs run at once, fewer beside parallel query,
and a scenario needing more raises `max_worker_processes` (a restart).
`cron.job_run_details` gains a row per run and is never purged by
`pg_cron`: a job every few seconds makes it grow. A run's memory and
CPU are a backend's, within the node's limits.

**The faults it allows**: a job running as a superuser or as the wrong
role, at the wrong time (its schedule, `cron.timezone`), too heavy for the
database node, its trace turned off (`cron.log_run`, so a check on its
runs answers 3), its preload removed (no job runs). The catalogue faults
using it are listed in "Supported faults".

## The cron daemon

**What it is**: Debian's `cron` (`3.0pl1-197`), as on a Debian database
host, running the crontab of OS user `postgres` (master spec 7.2). A
third s6 longrun, `cron`, runs `/usr/sbin/cron -f` as root, started after
`postgres` (`dependencies.d/postgres`); cron switches to `postgres` for
each job. The image removes Debian's `/etc/crontab` and the entries of
`/etc/cron.d` and `/etc/cron.{hourly,daily,weekly,monthly,yearly}` (its
`apt-compat` and `dpkg` jobs as root), so the only crontab cron reads is
the spool's; and it sets the jobs' umask to `0022` in `/etc/pam.d/cron`
(Debian's `pam_umask` would give `postgres`'s jobs `0002`, letting the
players' group write the job logs).

**How a scenario turns it on**: by seeding `crontab` (the optional seed
file, `seed.optional`) and naming the node's `crontab_roles` in
`scenario.yaml`. Render mounts `/opt/gm/seed/crontab` only when the
node's `seed_files` names it, and the service's run script decides by that
file: without it, it prints `cron: this node seeds no crontab; the cron
daemon does not run` (`gmctl logs`), marks itself to run once at most
(`s6-svc -O`) and exits, so `s6-svstat /run/service/cron` reads down and
not wanted up, and no daemon runs. With it, the daemon runs even if a
player empties the crontab, as on a host.

**The crontab**: installed once, at the first start (start-up step 4),
as `/var/spool/cron/crontabs/postgres` on the volume `cronspool`
(`snapshot: copy`), `postgres:crontab` `0600` in the spool `root:crontab`
`1730`, both set again at every start. A player's replacement survives a
restart and a new container. Its baseline entry (capture W1 item 8), with
`PGPASSFILE` on a line of its own above the entries:

```
PGPASSFILE=/run/gm-cron/pgpass
0 3 * * * psql -X -w -h /run/postgresql -U <role> -d <database> -c "<statement>" >> /var/log/postgresql/cron/<job>.log 2>&1
```

- **Connections** go over the local socket. An entry naming no role
  connects as `postgres` by peer, a superuser: a fault. The baseline
  connects as a customer role through the password file
  `/run/gm-cron/pgpass`, written at every start (start-up step 8) from
  each mounted `/opt/gm/secrets/role_<role>_password` (the role named by
  the file name), one line `*:*:*:<role>:<password>` each, `:` and `\`
  escaped; its directory `postgres:postgres` `0700`, the file `0600`, so
  only OS user `postgres` reads it; on `/run`, so no password lands on a
  volume or in the hand-over snapshot. No entry holds a password. The
  node's seed `pg_hba.conf` must let the role in over the local socket
  by password (`local all all scram-sha-256` does).
- **Output**: there is no mail transfer agent and no syslog, so cron's
  own lines and a job's output go nowhere unless the entry redirects
  them. The baseline appends to one file per entry, named by its job
  (`[a-z0-9-]+`), in `/var/log/postgresql/cron/` on `pglog`: the
  directory `postgres:pgconf` `2750`, set at every start, a job's file
  `0644` with the group `pgconf`, so the players read the logs and cannot
  write them.
- **Times**: cron reads the node's clock, UTC; render shifts each entry's
  hours from scenario time, as it shifts `jobs.yaml` (8.5).
- **Shutdown**: s6 stops `cron` (SIGTERM) before `postgres` (fast
  shutdown); a job running then is not waited for and is a failed run, as
  on a host. `gm-restart-db` restarts PostgreSQL alone (`s6-svc -r`):
  cron goes on, and a job starting meanwhile fails to connect. The
  hand-over snapshot never stops `cron`.
- **`gm-crontab`**, the players' way in (see "Wrappers"): `sudo
  gm-crontab -l` and `sudo gm-crontab <file>`; cron reads a replacement
  within the minute. Debian's default lets any OS user run `crontab`
  (no `cron.allow`, spec D211): `postgres`, which `dba` reaches through
  `COPY ... TO PROGRAM`, changes the same crontab, on a node the players
  may change anyway (access model 9.4).

**Its cost**: the daemon, 2.5MB resident at rest in the stack test;
each run is a shell and its programs as `postgres`, sharing the
container's memory limit with PostgreSQL, so a heavy one can exhaust it
(see "The out-of-memory victim"; master spec 16.3).

**The faults it allows**: an entry connecting as `postgres` by peer (a
superuser), a password written into an entry, a heavy job on the
database node, an entry at the wrong hour (UTC against the customer's
time), an entry whose output goes nowhere. The catalogue faults using it
are listed in "Supported faults". Node-health cannot watch `cron` in v0.4
(see "Known limits").
