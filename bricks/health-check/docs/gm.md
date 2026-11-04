# health-check brick — GM notes

GM documentation of the `health-check` brick (`brick.yaml`, v0.5 master
spec 7.4, 7.5 and 14; the build conditions: G9, v0.5 wave log; the seed
files, the scripts' convention, the port and the route: capture W2 item
5). Never shipped to players. Brick version 0.1.0, expected to evolve as
games are played.

## Purpose

The node `health`, standing for the clinic's Nagios-style health tooling:
Debian's `check_postgres` 2.26.0 run every five minutes from cron as
`monitoring` against each instance in scope, the customer's hand-made
scripts on the same crontab, and a status page rewritten by each run and
served by nginx (static files only), routed by the bastion as `health`.
It fills the role `monitoring`; image
`127.0.0.1:5000/dbagm/health-check:0.1.0`.

The image:

- Debian 13 (`debian:13-slim`); `check-postgres=2.26.0-2` pinned, no
  recommends (Debian's `postgresql-client-17` and `libpq5` 17.11, Perl
  5.40); Debian's `cron`, `nginx` (1.26.3, the bastion's, no
  `libnginx-mod-*`: asserted), `curl`, `openssh-server`, `sudo`, `nano`,
  `vim-tiny`, `less`, `procps`. The build asserts the package version,
  `check_postgres --version` 2.26.0, psql 17, the OpenSSL floor
  `3.5.7-1~deb13u3`, no dynamic nginx module, Debian's sites and
  `conf.d` cleared, and that the node's nginx configuration loads and
  holds none of G9's excluded directives (proxy, fastcgi, uwsgi, scgi,
  grpc, dav, charset, rewrite and `return`, `include`, `load_module`,
  HTTP/2 and 3, mail, stream).
- s6-overlay 3.2.3.2 (x86_64), verified by SHA-256 at build.
- `health-run` (Perl, core modules only), the runs and the page.
- Generic: no scenario content, no credential and no host keys.
- Size: 195MB (about 116MB over the shared `debian:13-slim` layer).

## Placement

- **What gets installed**: a node of its own, `health` in the clinic.
  The image must be on the engine that runs the game.
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/health-check:0.1.0 bricks/health-check`.
- **How many**: one per game.
- **Next to which node**: any host; the VPS in the clinic, off site as the
  standby is (master spec 14).
- **What it needs**: every instance of `health.yaml` a `postgres` 0.5.0
  node choosing the option `monitoring` (a standby's primary choosing it);
  `gmctl` refuses a health node targeting a node without it, unless a
  fault plants the gap (master spec 7.1; capture W2 item 1). Each
  instance's `pg_hba.conf` lets `monitoring` in from this node to the
  database `health.yaml` names (`scram-sha-256`; `hostssl` where TLS is
  demanded: libpq's default `sslmode=prefer` uses it). The bastion's
  `web_routes` gains `health: "health:8080"`; Prometheus' node-health job
  lists the node on 9110. The backup script reaches cold storage's
  `GET /manifests` on `cold-storage:8000` (public, no credential).
- **Stateful**: yes. Volumes `healthconf`, `healthdata`, `cronspool`,
  `home`, `gmstate`, `run`.
- **Networks**: the game's one network.

## Configuration

No parameter, no knob: the instances, the crontab and the scripts are
seed files.

### What the seed files must contain

- **`health.yaml`** (required): `instances:`, a list of `{name, host,
  port, dbname}`, and `primary: <name>` on a standby (capture W2 item 5
  gives the four keys; `primary` is this brick's addition, needed for the
  standby's replay delay, which `check_postgres` measures against the
  primary). Parsed by `health-run`, never evaluated: block or flow form,
  plain or quoted scalars, comments; any other key or shape is refused
  with its line number. Every check connects to `dbname` (`postgres`
  in the clinic); `check_postgres` lists every database it can see from
  there.
- **`crontab`** (required): OS user `postgres`'s, installed once into
  cron's spool through Debian's `crontab`. It needs its own `PATH=` line
  and `MAILTO=""` (no mail transport). The companion's:

  ```
  PATH=/usr/local/bin:/usr/bin:/bin
  MAILTO=""
  */5 * * * * health-run checks
  */5 * * * * health-run script disk-alarm 2048 4096 records
  30 6 * * * health-run script backup-there http://cold-storage:8000 records
  ```

- **`scripts/`** (optional, a directory entry): the customer's scripts,
  installed once into `/etc/health/scripts/` 0775. Each is a Nagios
  plugin run by `health-run script <name> [args...]`: its first output
  line and its exit status (0 OK, 1 WARNING, 2 CRITICAL, 3 UNKNOWN,
  anything else UNKNOWN), bounded at 120 s, in an environment of `PATH`,
  `PGUSER=monitoring`, `PGPASSFILE`, `PGCONNECT_TIMEOUT=10`,
  `HEALTH_YAML`, `TZ=UTC`. The companion's two (`companion/scripts/`):
  - `disk-alarm <warning MB> <critical MB> <host>...`: the IT's alarm on
    the sum of `pg_database_size` per host;
  - `backup-there <URL> [<source>]`: asks
    `GET <URL>/manifests?type=basebackup&from=<yesterday>[&source=<node>]`
    and counts the manifests with `rows_received` of one or more: OK
    (found), CRITICAL (none), UNKNOWN (no answer, or not a JSON list).
    Its first read against cold storage itself is G13's; the stack test
    answers it with a stand-in (spec D362).

### The checks

`health-run checks`, for each instance, in this order, `check_postgres
--host --port --dbname --dbuser=monitoring --timeout=15 --output=nagios`
(each run bounded at 30 s):

| Action | Where | Thresholds |
|---|---|---|
| `connection` | every instance | — |
| `backends` | every instance | 80 % / 90 % of `max_connections` |
| `locks` | every instance | 100 / 150 |
| `txn_wraparound` | every instance | 1.3e9 / 1.4e9 |
| `last_autovacuum` | primaries | 1 day / 7 days |
| `last_analyze` | primaries | 1 day / 7 days |
| `database_size` | every instance | 5GB / 10GB |
| `hot_standby_delay` | standbys, against `primary` | 16MB / 128MB of replay |

Every action runs within `pg_monitor` and was run against PostgreSQL
18.6 in the stack test, as G9 requires; Debian's psql 17.11 talks to it
(PGDG's `postgresql-client-18` is the fallback if an action ever fails on
18). On a fresh cluster `last_autovacuum` (and `last_analyze` on a
standby, hence skipped there) report UNKNOWN, "No matching tables have
ever been vacuumed": the page says so.

### Fixed paths

| What | Path | Notes |
|---|---|---|
| Instances | `/etc/health/health.yaml` | volume `healthconf`; `postgres:healthconf` 0664 (0644) |
| Scripts | `/etc/health/scripts/` | 2775 (2755), each script 0775 (0755) |
| Crontab | `/var/spool/cron/crontabs/postgres` | volume `cronspool`, `postgres:crontab` 0600 |
| Results | `/var/lib/health/results/` | volume `healthdata`; `checks.json`, `script-<name>.json` |
| Page | `/var/lib/health/www/health/index.html`, `status.txt` | rewritten by each run; served under `/health/` |
| Password file | `/run/gm-health/pgpass` | `*:*:*:monitoring:<password>`, `postgres` 0600, written at every start |
| nginx | `/usr/local/lib/gm/nginx.conf` | runtime files under `/run/nginx` |

### Start-up

`gm-entrypoint` empties `/run`, writes the host key and the password file
(`:` and `\` escaped), writes the write policy, seeds once (`health.yaml`,
`scripts/`, the crontab through `crontab -u postgres`), applies owners
and modes, writes an empty page when there is none, then execs
s6-overlay: `cron`, `web` (nginx as `www-data`) and `sshd`.

The `cron` service first **waits, bounded**, up to 30 s for every
instance's host to resolve (spec D356), logging `health-start: waiting up
to 30s ...` and its outcome, then runs the checks once (`health-start:
first run: ...`) so the page has a reading from the start, then execs
cron. A host not resolved yet gives an honest CRITICAL line ("could not
translate host name") until a later run reads it.

## Connections

- **Out**: PostgreSQL 5432 to each instance, as `monitoring`, a few
  short sessions every five minutes; HTTP 8000 to cold storage
  (`GET /manifests`), from the backup script.
- **In**: HTTP 8080 from the bastion's web front only (`web_routes`
  `health`), GET and HEAD; SSH 22.

## Access

- `postgres` (990:990): runs the crontab (G9: Debian cron as `postgres`,
  one spool crontab) and is the only account, with root, reading the
  monitoring password. `www-data` runs nginx and reads the page.
- `player`: SSH by key only, in `healthconf` (991), never in `postgres`'s
  group. Fixable: `health.yaml` and the scripts writable; `sudo
  gm-crontab <file>` replaces the crontab. Report-only: 2755/0644/0755,
  `gm-crontab` refuses a replacement in one line, `-l` still lists.
  `GM_WRITE_OVERRIDES` may name `/etc/health` (the crontab follows it) or
  `/home/player`.
- **Wrappers**: `gm-crontab` (any argument, checked: `-l` or one file
  read as player), `gm-run-checks` (the checks now, as `postgres`),
  `gm-validate`.
- **The page** has no login beyond the web front's tools password
  (access model 13), and no `edit-content`: each run rewrites it.
- Capabilities as the exporter's, `cap_drop: ALL` first.

## Footprint

Default footprint in `brick.yaml`: limits CPU `0.245`, memory `122M`;
reservations CPU `0.095`, memory `58M`, disk `64M`: master spec 14's row
(0.1 CPU, 64M) less the node-health script's 0.005 CPU and 6M. A check
run starts one `check_postgres` (Perl and psql) at a time, about 15
processes in a few seconds every five minutes. Disk growth per hour `1M`:
the results and the page are rewritten, never appended. Measured in the
stack test (armenelos, Docker 29.9.1, 2026-11-04; two instances, without
the node-health script): 5M of memory at rest (`docker stats`), CPU 0.00
over the sample, `memory.peak` 33M with a check run (13 checks, the
scripts); far under the 128M limit and the 58M reservation, which keep
master spec 14's starting row until the clinic's measurements.

### Snapshot

Every volume but `run` by `copy`, the node running.

## Supported faults

None in v0.5's catalogue. The instances, the crontab and the scripts are
fault surface a later game's GM may pick (master spec 7.4): an instance
missing, a script's threshold, a backup check against the wrong date or
source, a crontab line commented out.

## Checks

### Validator

`/opt/gm/validator/validate.sh`, as `postgres`. Rules: `config`
(`health.yaml` valid), `scripts` (every `health-run script <name>` of the
crontab an executable regular file), `cron` (the daemon runs), `web` (the
page answers on 8080), `fresh` (the checks ran less than 15 minutes ago).
`GREEN: ...` (0), `RED <rule>: ...` (1), `ERROR: ...` (2).

### Health check

Healthy once the page has answered once in the container and while sshd
is up; never asks a database.

### After deployment

The page through the bastion, `/health/`: each instance's checks OK (or
UNKNOWN on a fresh cluster), each script's line; `sudo gm-validate` green.

### Stack test

`sh bricks/health-check/tests/run-stack-test.sh` (needs
`health-check:0.1.0` and `postgres:0.5.0`): a primary and its cloned
standby started after the health node (the wait, its bound, the honest
failure, then every action of the set against PostgreSQL 18, TLS), cron
running lines on its own, the two scripts (the stand-in's `GET
/manifests` found, missing and broken), nginx static only, the password's
places, SSH and sudo, the validator, persistence, the snapshot, the
footprint, report-only and the entrypoint's refusal.

## Known limits

- **The trust line** (access model 8): on a fixable node a player's
  script runs as `postgres`, which reads the monitoring password; such a
  script could print it. Accepted, as a fixable builder on a scheduler
  node may print its credentials.
- `check_postgres` upstream is dormant since 2023 (G9: a watch).
- The checks' thresholds are fixed in `health-run`; a game wanting
  others changes the brick.
- `health.yaml`'s parser accepts only the documented shape.
