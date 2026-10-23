# scheduler brick — GM notes

GM documentation of the `scheduler` brick (`brick.yaml`, v0.3 master
spec 7 and 7.1; runtime interface: capture W1 item 7 and W1-y in
`specs/versions/v0.3/wave-log.md`). Never shipped to players. Brick
version 0.1.0, expected to evolve as games are played.

## Purpose

The producers and consumers of a game: a small Python 3.13 program on
Debian 13 (`program/gm_scheduler`, asyncio, Debian's `psycopg` 3 and
PyYAML), with an SSH server for the players, in the image
`127.0.0.1:5000/dbagm/scheduler:0.1.0`. It runs one rendered schedule
against one query repository and the fixed-time operations of
`jobs.yaml`, as the customer's applications would. It holds no business
logic: the SQL is the scenario's, written by the GM at design time. It
fills the roles `producer` and `consumer`; a topology may have several
scheduler nodes, each with its own schedule. The GM picks it for every
scenario with load (any scenario that ages, spec D157).

The image:

- Debian 13 (`debian:13-slim`), `python3` 3.13, `python3-psycopg`,
  `python3-yaml`, `tzdata`, `openssh-server`, `sudo`, `curl`, `less`,
  `nano`, `vim-tiny`, `procps`.
- s6-overlay 3.2.3.2 (x86_64), archives verified by SHA-256 at build.
- The program in `/usr/local/lib/python3.13/dist-packages/gm_scheduler`,
  run as `python3 -I -m gm_scheduler` (isolated mode: no environment
  variable, user site or current directory reaches its import path).
- Generic: no scenario content, no credential and no host keys in the
  image.
- Size: 172MB.

## Placement

- **What gets installed**: a node of its own, from the brick's image,
  which must be on the engine that runs the game (deployment never pulls
  it).
- **Build**: `docker build -t 127.0.0.1:5000/dbagm/scheduler:0.1.0 bricks/scheduler`.
- **How many**: one per application the story needs (a shop front, a
  reporting job, a batch consumer); each node has its own schedule,
  repository and jobs, and the same game seed (the program mixes in its
  hostname, so two nodes never draw alike).
- **Next to which node**: any host; it reaches its targets (a `postgres`
  node, or a `pgbouncer` node) by node name over the game's network.
- **What it needs**: the roles its schedule names, created in the
  database by the data load with the passwords of the secrets render
  generates for them (below); the tables its queries use.
- **Stateful**: yes. Its volumes (`repository`, `jobs`, `schedlog`,
  `schedstate`, `home`, `gmstate`, `run`) must follow the node if it is
  replaced; otherwise the players' changes, the log, the markers and the
  sequence positions are lost.
- **Networks**: it shares the game's network with the bastion (the
  players' way in), its targets and Prometheus.

## Configuration

`brick.yaml` declares no parameter and no knobs: everything is in the
seed files, where a fault or a fix can live.

### Seed files

| Seed file | Live path | Players |
|---|---|---|
| `schedule.yaml` | `/opt/gm/seed/schedule.yaml`, read in place (0:0 `0400`, `seed.modes`), never copied onto a volume (spec D163) | never: unreadable for `player` and for the service account |
| `queries.yaml` | `/srv/scheduler/repository/queries.yaml`, seeded once | read; edit where fixable |
| `builders/` (optional, a folder of files) | `/srv/scheduler/repository/builders/<file>`, seeded once | read; edit where fixable |
| `jobs.yaml` | `/srv/scheduler/jobs/jobs.yaml`, seeded once | read; edit where fixable |

The program reads only the rendered forms (render, chunk 7, writes them
from the scenario's): `queries.yaml` and `builders/` as designed,
`jobs.yaml` in UTC, `schedule.yaml` with the game's seed, the shapes per
UTC weekday and the timeline as UTC instants. The forms are W1 item 7's:

- **`queries.yaml`**: `queries:` maps a key (`[a-z0-9][a-z0-9._-]*`) to a
  query (`sql`, `params`, `transaction`), a pool (a list of queries, each
  with an optional `weight`, default 1; one per call), a sequence
  (`steps:` run in order on one connection, `transaction`) or a builder
  (`builder: builders/<file>:<function>`, `options`). Generators:
  `{int: [lo, hi]}`, `{decimal: [lo, hi, places]}`, `{choice: [...]}`,
  `{sequence: [start, step]}` (never reused, a restart included),
  `{now: utc}`; any other value is a constant. Parameters are psycopg's
  `%(name)s`; a statement with no parameter is sent as written. A name
  YAML reads as a boolean (`no`, `yes`, `on`, `off`) must be quoted.
  `transaction: {isolation: read committed | repeatable read |
  serializable, hold: <duration>}`: the hold is how long the client
  keeps the transaction open after its statements, before `COMMIT`.
- **Builders**: Python files; the function is called as
  `<function>(intensity, options)`, with `rng=` (the task's seeded
  generator) when its signature names `rng`, and returns
  `(statements, transaction)` or `{"statements": [...], "transaction":
  ...}`; a statement is `(sql, params)` or `{"sql", "params"}`;
  `transaction` is false, true (read committed) or `{isolation, hold}`.
  Only the files `queries.yaml` names are imported.
- **`jobs.yaml`**: `jobs: [{name, key, connection, at, timezone}]`, `at`
  any numeric 5-field cron, `timezone` optional, any zone `tzdata` names
  (render writes `Etc/GMT±N` for the wrong-time-zone fault), UTC when
  absent.
- **`schedule.yaml`**: `seed`, `intensity`, `connections` (`{driver:
  sql/postgresql, target: <node>:<port>/<database>, role, pool: {size: N}
  | {per-call: true}}`), `streams` (`{key, connection, rate, arrivals:
  poisson | even, shape, concurrency}`), `shapes` (`<name>: {utc: {mon:
  [24 multipliers], ..., sun: [...]}}`), `timeline` (`{at: <UTC instant>,
  stream: <initial key>, set: {key, rate, connection}}`).

### Secrets

| Secret | Path | Set by |
|---|---|---|
| `player_ssh_pubkey` (key-pair, public half of `player_ssh_key`) | `/opt/gm/secrets/player_ssh_pubkey`, root `0444` | `gmctl deploy` |
| `role_<role>_password`, one per role the schedule names (password, not handed over) | `/opt/gm/secrets/role_<role>_password`, 0:0 `0400` | render derives them from the schedules (spec D167): not in `brick.yaml`; `load-data` sets them in the database |

A role is `[a-z_][a-z0-9_]{0,40}`, never `postgres`, `dba`, `monitoring`,
`gm_check`, `pgbouncer_lookup` or `pg_*`.

### Fixed paths

| What | Path | Owner and mode |
|---|---|---|
| Repository | `/srv/scheduler/repository/` (volume `repository`), `builders/` in it | `scheduler:schedconf`, dirs `2775` fixable / `2755`, files `0664` / `0644` |
| Jobs | `/srv/scheduler/jobs/` (volume `jobs`) | as above |
| Log | `/var/log/scheduler/scheduler.log` (volume `schedlog`) | `scheduler:schedconf` `0640` in a `2750` directory: players read it |
| Program state | `/var/lib/scheduler/sequences.json` (volume `schedstate`) | `scheduler` only |
| Seed and load markers | `/var/lib/gm-state/.gm-seeded`, `/var/lib/gm-state/load-started` (volume `gmstate`) | root `0755` dir; seed marker root `0444`; load marker root:scheduler `0440` |
| Status | `/run/scheduler/status`, `/run/scheduler/loaded` | `scheduler`, in a `scheduler` `0750` directory: root and the validator read them |
| Write policy | `/run/gm/write-policy` | root `0444` in the root-only `/run/gm` |
| Program configuration | `/etc/scheduler/scheduler.yaml` | root `0644`, protected: log, status, marker, paths, the endpoint |
| Wrappers | `/usr/local/sbin/gm-reload-scheduler`, `gm-validate` | root `0755` |
| `sudo` log | `/run/gm/sudo.log` | root, lost when the container is replaced |

### Start-up (`gm-entrypoint`, every container start)

1. Empties `/run` and recreates `/run/sshd`, `/run/sshd-keys`, `/run/gm`,
   `/run/tmp` (`/tmp`, `/var/tmp` link to it) and `/run/scheduler`.
2. Generates an ed25519 sshd host key in `/run/sshd-keys`.
3. Fails the container when `player_ssh_pubkey` is missing or empty, a
   mounted `role_*_password` is empty or more than one line, or
   `/opt/gm/seed/schedule.yaml` is missing.
4. Checks `GM_WRITE_POLICY` and `GM_WRITE_OVERRIDES` (unset: `fixable`,
   no override) and writes `/run/gm/write-policy`; refuses an unknown
   policy or an override that is not one of `writable_paths`
   (`gm-entrypoint: fatal: ...`, the container exits).
5. Seeds once (marker `/var/lib/gm-state/.gm-seeded`): `queries.yaml` and
   `builders/` into the repository, `jobs.yaml` into the jobs directory.
   Never `schedule.yaml`.
6. Applies the write policy's owner and modes to every seeded file and
   directory, seeding or not (contents untouched, never through a link).
7. Sets the log, state, marker and home owners and modes; execs `/init`.

The s6 service `scheduler` runs as root only long enough to read
`schedule.yaml` and the role passwords and pass them on standard input
(`gm-scheduler-input 1`, one `password <role> <password>` line per
mounted secret, `schedule`, then the file), through a here-document
(`/bin/sh` is `dash`, which feeds it through a pipe, never a file), then
`s6-setuidgid scheduler`. The program never opens the schedule. Every
start of the service reads it again; the file never changes in a game.
The program exits 2 when its input is not valid (the reason on the
container's output, never in the players' log) and 3 when a file of the
repository or `jobs.yaml` is not valid; the `finish` script then keeps
the service down 4 s before s6 tries again.

### Idle, running, resuming

The run script removes the previous program's status before each start.
The program starts idle (`/run/scheduler/status`: `idle <instant>`, log
`state state=idle`, no call) until `/var/lib/gm-state/load-started`
exists. `gmctl start-load` (chunk 8) writes it atomically (T0, one line,
root:scheduler `0440`), runs `s6-svc -r /run/service/scheduler` and
polls the status until it reads `running <instant>`. A program that finds
the marker at start runs: from the current time, every timeline change
whose moment has passed applied, each job at its next time; nothing it
missed is replayed. After a kill, a container restart or a host restart
it comes back running the same way.

## Connections

Container ports 9120 and 22; nothing is published.

- **`metrics`, HTTP, port 9120.** `GET /metrics`, Prometheus' text
  format; no `web_path`, never routed through the web front, no login.
  The topology's Prometheus may scrape it as it would an application
  (`targets: ['<node>:9120']`); a scheduler left unscraped is an ordinary
  monitoring fault. The sealed checks read the same counters inside the
  node (`curl -s localhost:9120/metrics`, scraped or not). Series, each
  labelled `key` (and `job`, `reason` for the jobs'):
  `scheduler_calls_total`, `scheduler_errors_total`,
  `scheduler_call_duration_seconds` (histogram, buckets 1 ms to 60 s),
  `scheduler_job_runs_total`, `scheduler_job_skips_total`; and
  `scheduler_running` (1 or 0), `scheduler_start_time_seconds`. Every key
  the schedule or `jobs.yaml` names has its series from the start, at 0.
- **`ssh`, port 22.** The bastion's inner hop, as `player`, by key only.
- **Consumes `sql`, PostgreSQL, port 5432 or 6432.** The targets its
  connections name, a `postgres` node or a `pgbouncer` node, over TCP,
  as the connection's role with its password, `application_name` the
  node's hostname. Sessions in autocommit; transactions are explicit
  `BEGIN ISOLATION LEVEL ...`; no server-side prepared statements, so any
  PgBouncer pool mode works. `pool: {size: N}` keeps up to N sessions per
  task (each stream and each job has its own), opened when first needed;
  `per-call` opens and closes one per call. Nothing has to exist first:
  a target that refuses shows as errors in the log and the counters.
- **Mounted material**: the image accepts the `prometheus` brick's
  node-health script (`receives`: s6-overlay 3.2.3.2 and the commands
  `sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid`). Its
  node-health map entry is `default`, the brick's `processes`:
  `scheduler` and `sshd`.

## Access

- **Players**: SSH from the bastion as `player`, group `schedconf`; `sudo`
  for exactly `gm-reload-scheduler` and `gm-validate`, no arguments. They
  read the repository, `jobs.yaml`, the log and `/etc/scheduler/`; they
  see `/opt/gm/seed/schedule.yaml` in listings and cannot read it.
- **Write policies**: `fixable` and `report-only` (`no-access` is treated
  as `report-only` for files). Render sets `GM_WRITE_POLICY` and
  `GM_WRITE_OVERRIDES`; the entrypoint writes `/run/gm/write-policy`.
  `writable_paths` are the two directories `/srv/scheduler/repository`
  and `/srv/scheduler/jobs` (spec D170) and `/home/player`; an override
  names one of the two directories, which makes it and everything in it
  fixable (`2775`, files `0664`), so `sed -i` works there. On a
  report-only node without override the directories are `2755` and the
  files `0644`: an edit is an ordinary "permission denied".
- **`gm-reload-scheduler`**: restores every seeded file's owner and mode
  first (a file `sed -i` left owned by `player` gets `scheduler` back;
  contents untouched, links and hard-linked files left alone); then, when
  neither directory is fixable, prints `gm-reload-scheduler: this node is
  report-only: its files cannot be changed, so nothing was reloaded.` and
  exits 1, nothing signalled. Otherwise it checks the files as
  `scheduler` (they load, builders import, jobs' keys exist), then as root
  that every key the schedule names is still in `queries.yaml` and every
  job's connection is the schedule's (naming only the key), refuses with
  "NOT reloaded" and exit 1 when either fails, and sends SIGHUP through
  s6. The program reloads the repository and `jobs.yaml`, keeping its
  schedule, connections and counters; the wrapper waits for it and prints
  each job's next run in UTC. Files players add in a fixable directory:
  the program ignores them, except a builder `queries.yaml` names;
  `gm-reload-scheduler` gives them the seeded files' owner and mode.
- **A fixable builder is code** players run as `scheduler`, inside the
  process holding the schedule and the role passwords; accepted on the
  trust line (access model 8), builders are not isolated.
- **Protected files** (root, read-only): `brick.yaml`'s
  `protected_files`. Read-only root filesystem.
- **Capabilities** added back after `cap_drop: ALL`: `AUDIT_WRITE`,
  `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `KILL`, `NET_BIND_SERVICE`, `SETGID`,
  `SETUID`, `SYS_CHROOT`, each for the reason in `brick.yaml`;
  `DAC_OVERRIDE` also lets root's `tar` read every volume for the
  snapshot.
- **The GM** uses `gmctl exec` as root: the marker, the status, the
  counters, the log.

## Footprint

`brick.yaml`'s `footprint`: limits 0.25 CPU and 128M, reservations 0.1
CPU, 64M and 64M of disk, master spec 7.1's figures. Measured in the stack
test (armenelos, 2026-10-23, two runs): at rest and idle, 17M to 26M of
memory in the node's cgroup, page cache included (the program's RSS 24M
to 25M, shared library pages included); running two streams at 30 calls
a minute and 2 an hour, 27M to 41M (RSS 35M); the volumes at rest hold
about 56K. What grows is the log: a `summary` line and one `key` line per key every minute (about
120 bytes each), plus every fixed-time run and every error (measured: 4K
in 12 minutes at two keys, about 20K an hour); a stream failing at 40
calls a minute adds 40 `error` lines a minute.
`disk_growth_per_hour: 2M` is provisional, for a few keys and a few
errors a minute; chunk 15b's measurement replaces it. The CPU follows the
rates: tens of calls a second fit in 0.25 CPU. The levers: lower rates
or intensity, fewer keys, fewer failing calls.

### Snapshot

Every volume but `run` by `copy` (`snapshot:`): seeded files, the
markers, an append-only log and a state file rewritten whole; nothing is
stopped. `schedule.yaml` is not on a volume, so it is not in the
snapshot: a restart's re-render brings the new game's seed.

## Supported faults

No catalog fault names `scheduler` 0.1.0 yet. The faults of master spec
15.3 that live in its files (a query with an error, a missing `WHERE`, a
report reading far too much, retried inserts, transactions held open, a
batch at the daily peak, a job in the wrong time zone) arrive with chunk
14, which adds them to this section.

## Checks

- **Validator** (`sudo gm-validate`, or `/opt/gm/validator/validate.sh`
  as `scheduler`): `RED config` when `queries.yaml`, a builder it names
  or `jobs.yaml` does not load; `RED server` when the program does not
  answer on 9120; `RED pending` when the files changed since the program
  loaded them (run `sudo gm-reload-scheduler`). Green otherwise, saying
  whether it is idle or running. It cannot read the schedule, so a key
  the schedule names and the repository lacks shows only in
  `gm-reload-scheduler`'s refusal and in the program's `fatal` line.
- **Health check**: healthy once the program has answered on 9120 in this
  container and while `sshd` is up; it never asks a database.
- **The log** (`/var/log/scheduler/scheduler.log`), every line `<UTC
  instant> <event> name=value...`, a quoted value last:
  - `state state=idle`, `state state=running t0=<instant>`, `state
    state=stopping`;
  - within ten seconds after each UTC minute boundary while running, `summary
    minute=<YYYY-MM-DDTHH:MMZ> keys=N calls=N errors=N`, then one `key
    minute=... key=<k> calls=N errors=N p50_ms=x p95_ms=x p99_ms=x` per
    stream key current in the minute and per key a call of which ended in
    it (latencies `-` when `calls=0`); a minute with no `summary` is an
    outage minute;
  - `run job=<name> key=<k> phase=start`, then `phase=end status=ok
    rows=N ms=x` or `status=error sqlstate=S ms=x`;
  - `skip job=<name> key=<k> at=<instant> reason=still-running |
    connection-refused`;
  - `error key=<k> [job=<name>] sqlstate=<S or -> message="..."`;
  - `reload status=ok keys=N jobs=N`, `reload status=refused
    message="..."`, `fatal message="..."`.
  It names keys, jobs and connections, never rates or shapes.
- **After deployment**: the node healthy, `status` reads `idle`, the
  validator green; after `start-load`, `running` and a `summary` line a
  minute.
- **Tests**: `sh bricks/scheduler/tests/run-unit-tests.sh` (the program,
  in the image, against a throwaway PostgreSQL) and
  `sh bricks/scheduler/tests/run-stack-test.sh` (the brick, with a
  `postgres` node, as a Swarm stack); both under the host lock.

## Known limits

- One process for every task: a builder that blocks blocks the node's
  load.
- A call that finds every slot of its stream busy waits for one; the
  arrivals it delays are not caught up (no backlog), as a client with a
  fixed number of workers would.
- `jobs.yaml`'s cron has no names (`mon`, `jan`) and no `@` macros.
- The validator cannot see the schedule (above).
- Error lines are not rate-limited: a target down for long fills the log
  at the streams' rates.
