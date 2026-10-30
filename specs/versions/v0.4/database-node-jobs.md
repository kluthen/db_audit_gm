# v0.4 — jobs on a database node: `pg_cron` and a cron daemon

Status: draft v3

A job can run on a database node itself, beside PostgreSQL, instead of
on a scheduler node. The owner listed it among the places movement may
run from (D202): "local to the node cron job", then (2026-10-30): "we
could have a cron job on the same node as the postgresql, either as pure
cron, systemd timer, or pg_cron." Settled (D206): **`pg_cron` and a
cron daemon, both in v0.4**, carried by `postgres` 0.4.0; **systemd
timers later**, with the virtual-machine nodes of the cloud provider
after v1.0 (D205; [roadmap](../README.md#beyond-v10-a-fictional-cloud-provider-d205)).
The placement guideline is settled too (D207), and the first scenario
uses the cron daemon (D208) and an out-of-memory incident on a database
node (D209). Everything else below is proposed.

How these jobs move data is in [purposes.md](purposes.md#moving-data-between-instances-d202);
their faults in [candidate-faults.md](candidate-faults.md); what
governance and the checks read of them in [governance.md](governance.md)
and [checks.md](checks.md).

## Grounding: the `postgres` brick today

Read on `v0.4-spec` (f7b6f81), `bricks/postgres/` at 0.3.0:

- **s6-overlay** (3.2.3.2) supervises two longruns, `postgres` (its
  down-signal SIGINT, a fast shutdown) and `sshd`; `gm-entrypoint`
  prepares `/run`, the configuration and PGDATA, then execs `/init`.
  `S6_SERVICES_GRACETIME=8000`, `S6_KILL_GRACETIME=1000`.
- **A read-only root.** Writable: the volumes `pgdata`, `pgconf`
  (`/etc/postgresql`, group `pgconf`, the players'), `home`, `gmstate`,
  `pglog` (`/var/log/postgresql`, readable by `pgconf`) and `run`.
  Configuration is seeded once (marker in `gmstate`), so players' edits
  survive a restart.
- **PostgreSQL from PGDG** (`trixie-pgdg`); the preloads are the
  scenario's, in its seed `postgresql.conf` (tarnbeck:
  `shared_preload_libraries = 'pg_stat_statements'`).
- **Authentication** (tarnbeck's `pg_hba.conf`): `local all postgres
  peer`, then `local all all scram-sha-256`.
- **Players** reach the node by SSH as `player` (group `pgconf`), with
  three sudo wrappers (reload, restart, validate), and hold the `dba`
  superuser role.
- **Customer roles' passwords** come from `role_<role>_password`
  secrets, set by `load-data` (`tools/gm/inject.py`).
- **Every seed file a brick declares is required** of every node using
  it (`tools/gm/model.py`), so an optional seed file is a loader change.
- **One definition per brick** lives in the repository, and a scenario's
  pin must match it ([formats.md](../../formats.md), "Versions and
  pins").
- **The container survives PostgreSQL.** s6-overlay is PID 1; `postgres`
  is a longrun with no finish script, so s6 restarts a dead postmaster.
  The health check is healthy once PostgreSQL has accepted connections,
  then needs only `sshd` (`/usr/local/lib/gm/healthcheck`), so Swarm
  does not replace the container while PostgreSQL is down or recovering.
- **No OOM tuning today**: the run script sets no `PG_OOM_ADJUST_*`, and
  the capabilities exclude `SYS_RESOURCE`.

## What `postgres` 0.4.0 adds (D206)

| Part | Change | Used when |
|---|---|---|
| Image | `postgresql-18-cron` from PGDG; Debian's `cron`, installed without recommends (so no mail transfer agent) | always installed; idle unless used |
| `pg_cron` | nothing at start: the scenario's seed and data file turn it on | the seed preloads it and the data file creates it |
| Cron daemon | an s6 longrun `cron`; an optional seed file `crontab`; a volume `cronspool`; a sudo wrapper `gm-crontab`; a password file for the crontab's role | the node seeds `crontab` |
| OOM victim | the `postgres` run script exports `PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj` and `PG_OOM_ADJUST_VALUE=300`: every backend raises its own score, so the kernel picks a backend before the postmaster, s6, `sshd` or `cron` (below, "The out-of-memory incident") | always |
| Documentation | a section each in `docs/player.md` and `docs/gm.md` (D57): what it is, how a scenario enables it, its cost, the faults it allows | always |
| Footprint | the default unchanged: the `pg_cron` launcher is one background worker, `cron` a few MB; measured at the rehearsal | |

## `pg_cron`

- **Settings in the seed `postgresql.conf`**:
  `shared_preload_libraries` gains `pg_cron`; `cron.database_name`
  names the database holding its metadata;
  `cron.use_background_workers = on`, so a job runs as its role with no
  password and no `pg_hba.conf` line (the default opens a libpq
  connection to `localhost`, which needs `trust` or a password file for
  every job's role); `cron.timezone` set by `render` to the customer's
  zone (O122). The default, GMT, is right at a shift of 0 and wrong at
  any other, so no wrong-zone fault relies on it (the rule of D168).
  At most eight concurrent jobs under the default `max_worker_processes`,
  which a scenario raises if it needs more.
- **The data file** (the restored backup) creates the extension in
  `cron.database_name` as superuser and schedules each job with
  `cron.schedule_in_database(…, username => <role>)`. Jobs are rows, so
  the backup carries them, and the hand-over's `pg_basebackup` with
  them.
- **The loader checks** that a data file creating `pg_cron` belongs to a
  node whose seed preloads it, and that `cron.database_name` names a
  database that data file creates (the shape of O79's item 3). A fault
  may still remove the preload, a `seed-file` change.
- **Row-level security.** `cron.job` and `cron.job_run_details` show
  each role its own jobs only, unless it is a superuser or has
  `BYPASSRLS`. The players' `dba` sees every job. `gm_check`
  (`pg_read_all_data`) sees none, so `load-data` adds a read policy for
  `gm_check` on both tables where the extension exists, narrower than
  giving the role `BYPASSRLS`.
- **Its trace**: `cron.job_run_details` (start, end, status, message)
  while `cron.log_run` is on; a log line per statement while
  `cron.log_statement` is on.

## The cron daemon

- **Which daemon**: Debian's `cron`. It is apt-verified from the image's
  own distribution, and it is what an administrator meets on a Debian
  database host (`crontab -l` as `postgres`). Rejected: supercronic,
  container-native and unprivileged, which logs its runs to stdout, but
  is a separate binary to pin and check outside Debian, and `crontab`
  does not apply to it; busybox `crond`, which runs a crontab as the
  user its file is named after, unsafe if its directory ever became
  writable by players.
- **Supervision, the lightest way**: a third s6 longrun beside
  `postgres` and `sshd`, running `cron -f` in the foreground. No new
  supervisor. When the node seeds no `crontab`, the service's run script
  marks it down and exits, so the node runs no daemon.
- **Start order**: after `postgres`, so the first runs find the server.
  A job running while the server restarts (`gm-restart-db`) fails, as it
  would on a host.
- **Signals and shutdown**: s6 stops the services in reverse dependency
  order, `cron` (SIGTERM) before `postgres` (SIGINT, fast shutdown). A
  job running at that moment is not waited for. It gets SIGTERM at stage
  3, then SIGKILL after `S6_KILL_GRACETIME` (1 s), and the fast shutdown
  ends its session. An interrupted job is a failed run, as on a host.
  The hand-over snapshot never stops `cron`.
- **The crontab** is `postgres`'s, in the spool on a new volume
  `cronspool` (a read-only root; snapshot `copy`). It is installed from
  the seed `crontab` once, as configuration is, so a player's
  replacement survives a restart. The daemon runs as root and changes to
  `postgres` for its jobs (`SETUID` and `SETGID` are already granted).
- **Connections**: an entry connects over the local socket. As
  `postgres` by peer it is a superuser, which is a fault. The baseline
  connects as a customer role, whose `role_<role>_password` secret
  `gm-entrypoint` writes into a password file only `postgres` reads,
  named by `PGPASSFILE` in the crontab. The password is never in the
  entry.
- **Output**: the node has no mail transfer agent and no syslog, so
  cron's own lines and a job's output go nowhere unless the entry
  redirects them. The baseline appends to a log under
  `/var/log/postgresql/cron/` (`pglog`, readable by the players' group).
  An entry that does not redirect is the lost-output fault.
- **Time**: cron reads the node's clock, UTC (D129). An entry meant for
  a local hour is written by `render` from the customer's offset (O122).
- **Memory**: a job shares the container's limit with PostgreSQL, so a
  heavy one can exhaust it. The first scenario plants this once, during
  the aging, as an incident in the recent past (D209; below).
- **No new escalation**: whatever a crontab runs as OS user `postgres`,
  the players' `dba` can already run (`COPY … TO PROGRAM`), and the
  daemon reads no crontab from a directory the players can write.

## What players see

| | `pg_cron` | Cron daemon |
|---|---|---|
| That it exists | the preload in `postgresql.conf`; `\dx` | `cron` in `ps`; the brick's `docs/player.md` |
| The jobs | `cron.job` as `dba` | `sudo gm-crontab -l`, on any node |
| The runs | `cron.job_run_details`; `cron.log_statement` lines in the log and pgBadger | the job's own log, if its entry writes one |
| Fixing, on a fixable node | `cron.unschedule`, `cron.alter_job` (schedule, command, database, username, active), the settings | `sudo gm-crontab <file>` installs a replacement, read by cron within the minute |
| On a report-only node | read only | `-l` only |

Neither appears in a runner's `jobs.yaml`. The starter pack names
neither unless the story does: a job nobody lists is a finding.

## How a node enables each (D107, O79)

- **No `options:` key in v0.4.** D107 keeps the options model for v0.5
  (O79). Both packages ship in every `postgres` image, as O79's "light
  options in the base" would place them.
- **`pg_cron` is on** when the seed preloads it and the data file
  creates it, as `pg_stat_statements` is today.
- **The cron daemon is on** when the node seeds `crontab`, the brick's
  first optional seed file (`seed.optional: [crontab]` in `brick.yaml`,
  a loader change).
- v0.5's options model takes both as its first options, its `options:`
  then naming what the seed already shows
  ([v0.5](../v0.5/README.md)).

## Scenario pins (D57, D58, D59, D61)

- The repository holds one `postgres` definition, and a pin must match
  it, so **every scenario with a `postgres` node re-pins 0.4.0**:
  `tarnbeck-outdoor-shop`, `bookshop-new-server` and
  `fernway-clinics-monitoring`, as v0.3 re-pinned bookshop and fernway
  to 0.3.0. Opting in is per node, not per pin. A scenario keeps its
  version (D58).
- **Nothing changes where neither is on**: the packages sit idle and the
  `cron` service stays down. v0.3's smoke tests, run unchanged on 0.4.0,
  show it.
- **Every fault applying to `postgres`** adds 0.4.0 to `applies_to`
  (D59).
- While 0.4.0 is unreleased, further changes to the brick fold into it
  (D61), including any governance change O118 might bring.

## Placement: what belongs on a database node (D207)

The owner (2026-10-30): "instinctually i'm not convinced having heavy
transformation on the same node as a receiving database to be a good
move. for low computation stuff, why not, especially if it's well
scheduled."

Where the computation runs matters more than where the scheduler lives.
A `pg_cron` job calling a set-based procedure and a transformer script
running the same `INSERT … SELECT` load the database the same way. What
separates them:

- **Set-based or procedural.** Pulling rows into Python and pushing
  them back costs the network and the database more than one statement.
- **The source or the receiving instance.** Heavy roll-ups on the
  shop's instance compete with customers. Loading and transforming on a
  reporting instance sized for it is normal practice.
- **Light or heavy.**
- **On our nodes**, a cron daemon shares the PostgreSQL container's
  memory limit (above, "Memory").

The guideline, settled (D207) and stated in the scenario format's
guidance ([formats.md](../../formats.md), "Where a job runs"):

- A database node's cron, `pg_cron` or the daemon, may run **light,
  well-scheduled work**: creating partitions, small cleanups, refreshing
  a small materialized view, calling a set-based procedure off-peak.
- **Heavy or row-by-row transformation** goes to a transformer node
  sized for it (D204).
- **Heavy work on the source instance** is the worst placement.

**P1's nightly close fits.** `rollup-close` is scheduled on `bi`, the
transformer node, but `CALL rpt.close_day()` computes on `reporting`,
the receiving instance: one set-based procedure, at 01:30, off-peak.
The shop's instance serves only the remote scan of one day's orders
through `postgres_fdw`. A `pg_cron` job on `reporting` could run the
same call under this guideline, and the procedure's load would not
change. The hourly script's row-by-row work stays on `bi`
([purpose-catalogue.md](purpose-catalogue.md) P1).

## The out-of-memory incident (D209)

The owner (2026-10-30): "It is to my mind a good fault to identify but
maybe not as is: more like, it happened "once" in the recent past,
(maybe a larger than usual peak in the data to be transformed) and it
need to be investigated and decided to move the transformation outside
(reporting only)." No reshaping of the container is needed (above,
"Grounding"). Settled (D209): the incident happens **for real, once,
during the aging**, never forged (D114, D132); at hand-over it lies in
the recent past and the system has recovered; the players investigate,
and the expected resolution is **report**: the finding, with the
recommendation to move the transformation to a transformer node. The
fault is `purpose-heavy-job-on-database-node`
([candidate-faults.md](candidate-faults.md), "Placement"). The rest is
proposed.

### What happens

1. From T0, a database node's crontab runs a heavy transformation
   nightly, a roll-up over the rows changed since its last run. On a
   normal night it fits.
2. At a planned moment before its run, a one-off **backfill request**
   arrives: a `state` change planted by `gmctl inject --at`, a row asking
   the job to recompute the last thirty days (in the story, the agency
   changed its formula). The job marks the request taken, in a
   transaction of its own, before it starts.
3. The run reads thirty days instead of one. The backend computing it
   grows past the node's memory, and the kernel kills it (SIGKILL).
4. The postmaster sees a child killed, ends every other backend, and
   recovers: "server process (PID …) was terminated by signal 9:
   Killed", "terminating any other active server processes", "all
   server processes terminated; reinitializing", "database system was
   not properly shut down; automatic recovery in progress". It accepts
   connections again within seconds. s6, `sshd` and the cron daemon are
   untouched.
5. The request stays taken, never done, so the next night runs normally.
   It happened once.

A producer timeline change (a flash sale) would be the other way to make
a peak, but no realistic rate brings a node's memory to its limit
without straining the shop's instance and its disk; the backfill
reaches it from the history the restored backup already holds.

### Making it deterministic

- **Which process dies.** The kernel's OOM killer picks the process in
  the container's cgroup with the highest score: its memory, plus
  `oom_score_adj` in thousandths of the cgroup's limit. A process may
  raise its own score without a capability. Lowering one needs
  `CAP_SYS_RESOURCE`, which the brick does not get. So `postgres`
  0.4.0 has every backend raise itself (`PG_OOM_ADJUST_VALUE=300`,
  PostgreSQL's own mechanism, applied in each child after fork). A
  backend then outranks any process at 0 unless that process holds 30 %
  of the limit more than the backend: the postmaster, s6, `sshd`, the
  cron daemon and the job's own `psql` are spared, and among backends
  the largest dies, which is the job's. This changes nothing in a game
  where memory never runs out.
- **What grows.** The job's memory must sit in its backend and grow with
  its input, unbounded by `work_mem`: one aggregate holding every row
  (`jsonb_agg` over the window, building the agency's document before
  inserting it, a common naive roll-up). Sorts, hash joins and hash
  aggregates spill to disk and never exhaust memory, so they cannot
  carry this fault. `psql` is called so that it receives no result set
  (an `INSERT … SELECT`), so it stays small.
- **Sizing.** Docker allows a container swap equal to its memory limit
  unless told otherwise, and Swarm cannot say otherwise; the hosts have
  swap. So the backfill run needs more than twice the node's limit, and
  a normal run less than half of it, after `shared_buffers`. Both are
  measured in the smoke run (the cgroup's `memory.peak` around a normal
  run and around the backfill), and the scenario sets the backfill's
  window from them. With swap the run thrashes for a while before it
  dies, which slows its host during the aging: the reason the incident
  is placed at night, alone.
- **When it did not happen.** The setup is verified, not assumed: after
  the job's planned run, the fault's check (below) must find the kill
  and the recovery; if it does not by the next early check, the planting
  failed (D36) and the GM is told, as for a failed `inject --at`.

### Evidence

All of it survives on the node:

| Where | What | Who |
|---|---|---|
| The PostgreSQL file log (`pglog`), and pgBadger's report | the four lines above, at the incident's time; the job's statement if logged | players, GM |
| `/sys/fs/cgroup/memory.events`, readable inside the container | `oom_kill 1`; `memory.peak` near the limit | players, GM |
| `pg_stat_database.stats_reset` and the other statistics' reset times | the incident's time: a crash discards cumulative statistics (`pg_stat_statements` included) | players |
| The job's log (the baseline's redirect) and its run ledger | `server closed the connection unexpectedly` at that run; a run with no end, the request taken and never done | players |
| The backfill request row, and the data | the thirty-day window against the usual one | players |
| The crontab (`sudo gm-crontab -l`) | the heavy job on the database node | players |

### The check

The fault is judged on the incident, not on a live state. Its sealed
check, on the node, exits 1 ("present") while the kill and the recovery
are in the log since the planting moment and the heavy entry is still
in the crontab; 0 if the entry has left the node (a fix the report-only
node does not allow, kept for a scenario that does). It never answers
3. What the answer key judges is the report: the incident named (when,
which process, killed for memory, the recovery that followed), its cause
(the backfill on the database node at its memory limit), and the
recommendation (move the transformation to a transformer node sized for
it, D207). Feedback says *report* was expected, as v0.3's report-only
faults do.

### Risks to the game, accepted

- **Connections dropped.** Recovery ends every session on that node:
  the transformer's and the consumer's (they reconnect on their next
  run, an error run in their logs), a `pg_cron` job running at that
  moment, any `gm_check` session. Acceptable during the aging, where no
  player is connected; the incident is planted away from the early
  check's time and well before hand-over.
- **Statistics lost.** Everything cumulative on that node restarts at
  the incident. No other fault's evidence on that node may rest on
  statistics gathered before it.
- **A heavier host night.** If the host swaps, every node on it slows
  for the minutes before the kill. Hence the placement rule below.

### Never on a shared host

A host shared with other applications must never carry this thrashing:
the VPS hosts filetstudio.com, which must stay up and never be disturbed
(D159; [platform.md](../../platform.md)). So:

- **The node carrying this fault is never placed on a host shared with
  other applications.**
- **How the placement keeps it off**, on v0.3's model: the scenario
  places every node on a declared host (`designed_for.placement`), the
  local implementation maps those hosts onto the playground's, and
  `gmctl fit` checks the mapping. The playground's host declaration
  marks a host `shared` (the VPS); the fault declares that its node needs
  an unshared host; `fit` refuses a mapping that puts that node on a
  shared host and names the mapping to change, as it refuses a node
  publishing ports on a host other than the manager. The designed
  placement itself puts the node on the first host, the manager
  (proposed).
- **Smoke runs of this fault run on armenelos only**, never on the VPS,
  calibration included.

## Dependency check (for the build plan)

`postgres` 0.4.0 adds packages: `postgresql-18-cron` (PGDG) and Debian's
`cron` with what it pulls in. The build plan carries a security-advisor
dependency check for them: a preflight on the candidate versions before
the chunk that changes the image is planned, a post-change check on the
resolved versions after it lands, and `.tech` brought up to date. Not
run now.
