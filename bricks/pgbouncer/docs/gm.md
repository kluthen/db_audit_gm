# pgbouncer brick — GM notes

GM documentation of the `pgbouncer` brick (`brick.yaml`). Never shipped
to players.

## Purpose

A PgBouncer connection pooler node (v0.3 master spec 7.2): PgBouncer
1.26.1 from the PostgreSQL apt repository (PGDG, `trixie-pgdg`, package
`1.26.1-1.pgdg13+1`, D177; psql 18 from there too), on `debian:13-slim`,
with s6-overlay 3.2.3.2, `sshd`, the `player` account and a public
validator, like every node. Image `127.0.0.1:5000/dbagm/pgbouncer:0.1.0`.
Role `pooler`.

It is optional in any scenario (D119): the GM picks it when the design
needs a pooler between the clients and the database, for faults about
pool sizes, pool modes, client limits or a client that bypasses the
pooler. There is no metrics exporter for it (D139): players read
PgBouncer through its console (`SHOW POOLS`, `SHOW STATS`, `SHOW
CLIENTS`) and its log, and the node-health script covers the node.

## Placement

- A node of its own, one per pooler the design needs (one is the usual
  case); it mounts no material into other nodes.
- Build: `docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.0
  bricks/pgbouncer` (x86_64; the build fails if the package is not
  PgBouncer 1.26.1, `1.26.1-1.pgdg13+1`).
- Stateful (`stateful: true`): its configuration, its log and the
  players' home are on named volumes, so a new container keeps the
  players' edits. Requirements: it shares a network with every database
  node its `[databases]` names and with the clients that use it (the
  bastion, scheduler nodes); no host requirement of its own.
- The scenario must also have a `postgres` 0.3.0 node, where the lookup
  role and its function live (see "Connections").

## Configuration

`parameters: {}`: everything scenario-specific is in the seed file.

### Seed file

`pgbouncer.ini`, seeded once to `/etc/pgbouncer/pgbouncer.ini` (marker
`/var/lib/gm-state/.gm-seeded`; later starts keep the players' edits). It
is the scenario's part of PgBouncer's configuration:

- `[databases]`: every database clients reach through the pooler,
  `<name> = host=<db node> port=5432 dbname=<db>`, and **`postgres`**,
  the database PgBouncer looks the logins up in (`auth_dbname`): without
  it no role can log in, the console's `dba` included (the validator's
  `auth` rule). A fallback `* = host=<db node> port=5432` also serves.
  Per-database `pool_size`, `reserve_pool_size`, `pool_mode` and
  `max_db_connections` are allowed and bounded by the envelopes below.
- `[users]`, optional: per-role settings (`pool_mode`,
  `max_user_connections`).
- `[pgbouncer]`: the pool sizes, the pool mode, the limits, timeouts and
  log detail (`log_connections`, `log_disconnections`, `stats_period`).

Minimal seed (the stack test's, `tests/fixtures/pgbouncer.ini`):

```ini
[databases]
postgres = host=db port=5432 dbname=postgres
appdb = host=db port=5432 dbname=appdb

[pgbouncer]
pool_mode = session
default_pool_size = 5
max_client_conn = 50
max_db_connections = 0
reserve_pool_size = 0
```

### The GM's settings

These are not the seed's: `/usr/local/lib/gm/pgbouncer-gm.ini`
(root-owned, read-only) sets them, and they win over the same settings
written in `pgbouncer.ini`:

| Setting | Value | Why |
|---|---|---|
| `listen_addr`, `listen_port` | `*`, `6432` | the interface `brick.yaml` declares |
| `unix_socket_dir` | `/run/pgbouncer` | the console over the local socket |
| `pidfile`, `logfile` | none, `/var/log/pgbouncer/pgbouncer.log` | the log players read |
| `auth_type`, `auth_hba_file` | `hba`, `/usr/local/lib/gm/pgbouncer_hba.conf` | who logs in, and how |
| `auth_file` | `/run/pgbouncer-auth/userlist.txt` | the lookup role's password only |
| `auth_user`, `auth_dbname` | `pgbouncer_lookup`, `postgres` | capture W1 item 8 |
| `auth_query` | `SELECT usename, passwd FROM gm_pgbouncer.lookup($1)` | capture W1 item 8 |
| `admin_users` | `pgbouncer` | only PgBouncer's own account administers |
| `stats_users` | `dba` | the players' console role reads |

How they win: PgBouncer does not read `pgbouncer.ini` itself. At every
container start and every reload, `/usr/local/lib/gm/pgbouncer-conf` (as
`pgbouncer`) writes `/run/pgbouncer-conf/pgbouncer.ini`: the seed line
for line, with `%include /usr/local/lib/gm/pgbouncer-gm.ini` added at the
end of every `[pgbouncer]` section (PgBouncer resets a section's
settings at each of its headers, and the last value in a section wins).
An `%include` line in `pgbouncer.ini` is left out (commented out there,
the line count kept), since an included `[pgbouncer]` header would undo
the GM's settings; the validator is red on it. A seed that sets one of
these settings is not refused, but its value never takes effect: don't
write them in a seed.

`pgbouncer_hba.conf` (root-owned, read-only): `pgbouncer` by `peer` over
the local socket to the console only, `pgbouncer` refused anywhere else
and over TCP, every other role by `scram-sha-256` (local and TCP).

### Knobs

Default envelopes (`brick.yaml` `knobs`), all in `pgbouncer.ini`'s
`[pgbouncer]` section; a scenario may tighten them, never widen them:

| Setting | Default | Envelope |
|---|---|---|
| `default_pool_size` | `20` | `1` to `50` |
| `max_client_conn` | `100` | `10` to `500` |
| `max_db_connections` | `0` (no limit of PgBouncer's own) | `0` to `200` |
| `reserve_pool_size` | `0` | `0` to `20` |
| `pool_mode` | `session` | `session`, `transaction` |

`gmctl render` writes the node's envelope file
(`/opt/gm/protected/envelopes.conf`, `protected_configs`). The
validator checks the values in effect and the values pending in the
file; it also holds each database's own `pool_size`, `reserve_pool_size`,
`pool_mode` and `max_db_connections` (`SHOW DATABASES`) to the envelope
of `default_pool_size`, `reserve_pool_size`, `pool_mode` and
`max_db_connections`. `[users]` settings are not checked.

### Secrets

| Secret | Kind | Path | Owner, mode | Use |
|---|---|---|---|---|
| `player_ssh_pubkey` | key-pair (public half of `player_ssh_key`) | `/opt/gm/secrets/player_ssh_pubkey` | 0:0 `0444` | SSH as `player` |
| `pgbouncer_lookup_password` | password, not handed over, `only_with_role: pooler` | `/opt/gm/secrets/pgbouncer_lookup_password` | 0:0 `0400` | the lookup role's password |

`pgbouncer_lookup_password` is the secret the `postgres` node declares at
its own path (capture W1 item 8): one secret, both nodes. The entrypoint
writes it into `auth_file` (`"pgbouncer_lookup" "<password>"`,
root:pgbouncer `0440`, under `/run`, on no other volume); it must be one
line with no quote, space or tab. No application role's password is held
on this node: their SCRAM verifiers come from the database, through the
lookup function.

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` (a named volume) and creates the runtime directories:
   `/run/gm` (root `0700`), `/run/tmp` (`1777`, the target of `/tmp` and
   `/var/tmp`), `/run/pgbouncer` (the socket, `pgbouncer` `0755`),
   `/run/pgbouncer-auth` (root:pgbouncer `0750`), `/run/pgbouncer-conf`
   (`pgbouncer` `0755`).
2. Generates the sshd host key under `/run/sshd-keys`.
3. Checks the secrets (fatal when one is missing or empty) and writes
   `auth_file`.
4. Checks `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES` (fatal on an unknown
   policy, or an override that is not one of `writable_paths`), writes
   `/run/gm/write-policy`.
5. Seeds `pgbouncer.ini` once.
6. Gives the seeded file and its directory the write policy's owner and
   mode (see "Access").
7. Writes `/run/pgbouncer-conf/pgbouncer.ini`. When `pgbouncer.ini`
   cannot be used (a player's link in its place), it logs a warning and
   PgBouncer starts with the GM's settings and no database: the node
   stays up, the validator says why, and a fixed file is reloaded.
8. Sets the log's owner and mode (`pgbouncer:pgbconf`, `2750`;
   `pgbouncer.log` `0640`) and the home's, then execs `/init`.

## Connections

- **Provides** `sql` (PostgreSQL protocol, port 6432): the databases of
  `[databases]`, pooled, and the console (database `pgbouncer`). Clients
  name the node and port 6432, as a scheduler connection's target
  (`<pooler>:6432/<db>`) or `psql -h <pooler> -p 6432` on the bastion.
- **Provides** `ssh` (port 22): `player` from the bastion, by key.
- **Consumes** `sql` on the database node(s) (port 5432). What must
  exist first, on the `postgres` 0.3.0 node:
  - the lookup role `pgbouncer_lookup` and `gm_pgbouncer.lookup()` in
    database `postgres`: the database node creates both at every start
    when it has the lookup secret, which render mounts in a scenario with
    a pooler node (capture W1-x);
  - its seed `pg_hba.conf` admits, from the pooler node, by
    `scram-sha-256`: `pgbouncer_lookup` to database `postgres`, and every
    role that logs in through the pooler to its database. PgBouncer logs
    in to the server with the client's own SCRAM keys, so these lines must
    be `scram-sha-256`, never `md5` or `password`, and the roles' stored
    passwords SCRAM verifiers (PostgreSQL 18's default);
  - the application roles and databases themselves (the scenario's data).
- **Who connects through it**: the bastion's players (`dba` and any
  role), the scheduler nodes whose connections target it. Each pool also
  holds the lookup role's connection to `postgres` while logins are
  looked up; it counts toward the server's `max_connections`.
- **Monitoring**: no metrics endpoint. Its image accepts mounted material
  (`receives`: s6-overlay `3.2.3.2`; `sh cat du df awk sed grep sleep
  perl s6-svstat s6-setuidgid`): the node-health script, with services
  `pgbouncer` and `sshd`.

## Access

### Accounts and the console

- `player`: SSH by public key only, member of `pgbconf`. Its SSH
  environment opens `psql` on the console as `dba` over the local socket
  (`PGHOST=/run/pgbouncer PGPORT=6432 PGUSER=dba PGDATABASE=pgbouncer`);
  `dba`'s password is the database's, in `~/.pgpass` on the bastion,
  where `psql -h <pooler> -p 6432 -U dba pgbouncer` needs nothing more.
  Players hold no extra password.
- `pgbouncer`: runs PgBouncer, owns its configuration and log; no login.
  The console's only admin, by `peer` over the local socket.
- `sudo`: `player` may run the two wrappers as root, with no arguments
  (`env_reset`, fixed `secure_path`, log in `/run/gm/sudo.log`).

| Console | Who | Can |
|---|---|---|
| `stats_users` | `dba` | every `SHOW` (`POOLS`, `STATS`, `CLIENTS`, `SERVERS`, `CONFIG`, `DATABASES`, `LISTS`) |
| `admin_users` | `pgbouncer`, local socket only | also `RELOAD`, `SET`, `PAUSE`, `RESUME`, `KILL`, `KILL_CLIENT`, `SHUTDOWN` |

`dba`'s `RELOAD`, `SET`, `PAUSE` or `SHUTDOWN` is refused by PgBouncer
("admin access needed", access model 7). `admin_users = dba` written in
`pgbouncer.ini` changes nothing (see "The GM's settings").

### Writable and protected paths, write policies

- Writable by the player: `/etc/pgbouncer` when it is fixable (below),
  `/home/player` under every policy, `/tmp` and `/var/tmp` (`/run/tmp`).
  Readable: the log (`/var/log/pgbouncer`, through `pgbconf`), the GM's
  settings, `pgbouncer_hba.conf` and `/run/pgbouncer-conf/pgbouncer.ini`
  (what PgBouncer reads).
- Protected (root-owned, read-only to the player): the files in
  `brick.yaml`'s `protected_files`. `auth_file` and the lookup secret
  are not readable by the player.
- **Write policies**: `fixable` and `report-only` (`GM_WRITE_POLICY`,
  `GM_WRITE_OVERRIDES`; `no-access` is read as `report-only` for the
  files). The only useful override is `/etc/pgbouncer` (`/home/player` is
  writable anyway):

  | | `/etc/pgbouncer` | `pgbouncer.ini` | `gm-reload-pgbouncer` |
  |---|---|---|---|
  | `fixable`, or `report-only` with the override | `2775` | `0664` | reloads |
  | `report-only` | `2755` | `0644` | refuses |

  Owner `pgbouncer:pgbconf` throughout, set at every start and by the
  wrapper before every reload. A report-only pooler has no gap like a
  report-only database's superuser: `dba` only reads the console, and
  PgBouncer reloads only through the wrapper or the GM.
- **Owner restored**: `sed -i` leaves `pgbouncer.ini` owned by `player`;
  the entrypoint and the wrapper give it back, contents untouched, never
  through a link or on a file with other hard links (named `left alone:
  ...`). Files players add in a fixable `/etc/pgbouncer` stay as they
  made them, and PgBouncer never reads them (`%include` is left out).

### Wrappers

- `gm-reload-pgbouncer`: (1) restores the owner and mode; (2) when
  `pgbouncer.ini` is not fixable, prints `gm-reload-pgbouncer: this node
  is report-only: its files cannot be changed, so nothing was reloaded.`
  and exits 1; (3) tries the files on a throwaway PgBouncer
  (`/usr/local/lib/gm/pgbouncer-check`: no TCP listener, a private
  socket) and refuses, exit 1, "NOT reloaded", with PgBouncer's errors
  and `pgbouncer.ini`'s own line numbers, when they do not load: a
  `RELOAD` of such a file would reset every setting to its default, the
  GM's included; (4) writes `/run/pgbouncer-conf/pgbouncer.ini` and sends
  `RELOAD` on the console, prints PgBouncer's warnings about it, and the
  pool settings in effect (`in effect: pool_mode=... default_pool_size=...
  max_client_conn=... max_db_connections=... reserve_pool_size=...`).
  If PgBouncer is down, s6 restarts it; the wrapper waits up to 15 s.
- `gm-validate`: the validator as `pgbouncer`; never refused.

### Capabilities

`cap_drop: ALL`, then `brick.yaml`'s list, the other bricks' for the same
reasons (entrypoint `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETGID`,
`SETUID`; sshd `SYS_CHROOT`; sudo `AUDIT_WRITE`; s6 `KILL` for the
`pgbouncer`-owned server; `NET_BIND_SERVICE` for port 22 elsewhere than
Docker). `no-new-privileges` stays off (`sudo`).

### What the GM uses

The console as admin, through the exec verb as `pgbouncer`:

```sh
gmctl exec scenarios/<id> --playground <name> --node <pooler> --user pgbouncer <<'SQL'
psql -X -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS' -c 'SHOW CONFIG'
SQL
```

`gmctl validate scenarios/<id> --playground <name>` runs the validator
as `pgbouncer`; `gmctl logs scenarios/<id> --playground <name> --node
<pooler>` shows s6 and sshd, and PgBouncer's lines from before its log
file opens (a file that did not load at start); its own log is
`/var/log/pgbouncer/pgbouncer.log`.

## Footprint

Default footprint in `brick.yaml` (master spec 7.2's figures): limits
CPU `0.25` and memory `64M`; reservations CPU `0.05`, memory `32M` and
disk `256M`. At rest in the stack test, under the 64M limit: 11.1 MiB
(`docker stats`; `memory.current` 12.6 MB), CPU 0.01 %. PgBouncer's memory
grows with clients and pools (a few kilobytes each, `pkt_buf` buffers),
far below the limit within the envelopes. Disk growth per hour
(`disk_growth_per_hour`): `4M`, a provisional estimate, to be replaced by
v0.3 chunk 15b's measurement: the log only (a stats line per database a
minute, a line per login and logout with `log_connections` and
`log_disconnections`, more under a per-call client). Levers: those two
settings, `stats_period`, a pooled client (`pool: {size: N}`) rather
than one connection per call.

### Snapshot

Every volume but `/run` by `copy`, while the node runs (`snapshot:`):
`pgbconf` (the seeded file), `pgblog` (the log, append-only: `tar` exit
1, a file changed while read, still counts as a copy), `home`,
`gmstate`. No service stops. Restored by extracting each copy into its
empty volume; the next start rewrites `/run` (the socket,
`auth_file`, `/run/pgbouncer-conf`) and does not re-seed.

## Supported faults

Which faults the brick hosts is stated only by each fault's `applies_to`
(D59). This list is every catalog fault (`faults/`) whose `applies_to`
names `pgbouncer` `0.1.0`, and no other.

| Fault | Kind | What it needs from the brick |
|---|---|---|
| `pgbouncer-pool-too-small` | seed file (`pgbouncer.ini`) | the database's pool (`default_pool_size`, or the `[databases]` entry's `pool_size`) below the peak's need, `pool_mode = transaction` in effect (a precondition: in session mode the schedulers' sessions pin the pool from the first minute), `stats_period` set; the knob `default_pool_size` with the seed's value as `initial` and an envelope reaching the fault's `min-pool-size`; its sealed check reads `SHOW DATABASES` on the console over the local socket as `pgbouncer`, so only the values in effect count |

Its evidence is the console (`SHOW POOLS`, `SHOW DATABASES`, as `dba`),
`pgbouncer.ini` and the log's `stats:` lines; the clients' latency is the
scenario's, in its answer key. Its aging minimum counts business hours
under load (spec D189): the scenario raises the instance's.

Faults it lends itself to with no definition yet (v0.3
`faults-with-activity.md`): a client bypassing the pooler, `pool_mode =
transaction` with a client relying on session state, `max_client_conn`
below the clients' total. Each would be a `seed-file` fault on
`pgbouncer.ini`, fixable on a fixable node. A fault on the GM's settings
cannot be planted through the seed (they win over it).

## Checks

- **Validator** (`/opt/gm/validator/validate.sh`, as `pgbouncer`;
  players `sudo gm-validate`; GM `gmctl validate`): `config` (the files
  load, no `%include`), `server` (the console answers), `gm` (the GM's
  settings in effect), `auth` (`auth_dbname`'s database in
  `[databases]`), `knobs` (envelopes in effect, pending, and per
  database). Exit 0 green, 1 red (one `RED <rule>: ...` line each), 2
  error. Green on a seed within its envelopes.
- **Health check**: healthy once PgBouncer has answered on its local
  socket in this container, and while sshd is up. After that first time
  it no longer connects, so PgBouncer's log carries no probe lines, and
  PgBouncer being down is the validator's business.
- **After deployment**: `gmctl validate` green; `dba` runs `SHOW POOLS`
  from the bastion; an application role connects through the pooler.
- **Stack test**: `flock /tmp/dbagm-docker.lock sh
  bricks/pgbouncer/tests/run-stack-test.sh` (a `postgres` 0.3.0 node
  beside it): an application role through the pooler, `dba` on the
  console and refused `RELOAD`, the GM's admin over the local socket, an
  edit reloaded, the refusals, report-only and an override, the snapshot
  copy, the footprint at rest.

## Known limits

- No metrics exporter (D139): pool saturation shows in the console and
  the log only.
- **The lookup holds no reserve**: `pgbouncer_lookup` is not a member of
  `pg_use_reserved_connections` (capture W1-x), so when the server's
  ordinary slots are full (a connection-exhaustion fault), PgBouncer's
  lookup connection is refused like any client, and a login through the
  pooler that needs a lookup fails, `dba`'s console included; sessions
  already open carry on. The
  GM's sealed checks are not affected (they run on the database node as
  `gm_check`). Size a scenario's `max_connections` and pools with that in
  mind.
- `%include` in `pgbouncer.ini` is not followed; `[users]` settings are
  not held to an envelope.
- No TLS between clients, PgBouncer and the server.
- A setting PgBouncer cannot change while running (the GM's listeners
  aside, which do not move) takes effect at the next container start;
  the wrapper prints PgBouncer's warning about it.
