# v0.4 — jobs on a database node: `pg_cron` and a cron daemon

Status: draft v1

A job can run on a database node itself, beside PostgreSQL, instead of
on a scheduler node. The owner listed it among the places movement may
run from (D202): "local to the node cron job", then (2026-10-30): "we
could have a cron job on the same node as the postgresql, either as pure
cron, systemd timer, or pg_cron." Settled (D206): **`pg_cron` and a
cron daemon, both in v0.4**, carried by `postgres` 0.4.0; **systemd
timers later**, with the virtual-machine nodes of the cloud provider
after v1.0 (D205; [roadmap](../README.md#beyond-v10-a-fictional-cloud-provider-d205)).
Everything below the ruling is proposed.

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

## What `postgres` 0.4.0 adds (D206)

| Part | Change | Used when |
|---|---|---|
| Image | `postgresql-18-cron` from PGDG; Debian's `cron`, installed without recommends (so no mail transfer agent) | always installed; idle unless used |
| `pg_cron` | nothing at start: the scenario's seed and data file turn it on | the seed preloads it and the data file creates it |
| Cron daemon | an s6 longrun `cron`; an optional seed file `crontab`; a volume `cronspool`; a sudo wrapper `gm-crontab`; a password file for the crontab's role | the node seeds `crontab` |
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
  heavy one can get a backend or the postmaster OOM-killed. That is real
  and auditable, but too destructive to plant, since it may wipe the
  evidence: it stays a note, not a fault (below, "Placement").
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

## Placement: what belongs on a database node (O131)

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

Guideline (proposed; O131), for the drafts and the scenario format's
guidance:

- A database node's cron, `pg_cron` or the daemon, is for **light,
  well-scheduled work**: creating partitions, small cleanups, refreshing
  a small materialized view, calling a set-based procedure off-peak.
- **Heavy or procedural transformation** runs on a transformer node
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

## Dependency check (for the build plan)

`postgres` 0.4.0 adds packages: `postgresql-18-cron` (PGDG) and Debian's
`cron` with what it pulls in. The build plan carries a security-advisor
dependency check for them: a preflight on the candidate versions before
the chunk that changes the image is planned, a post-change check on the
resolved versions after it lands, and `.tech` brought up to date. Not
run now.
