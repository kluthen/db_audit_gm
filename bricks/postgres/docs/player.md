# PostgreSQL node — player notes

What you may know about a PostgreSQL 18 database node in a db_audit_gm
game. Version 0.2: server log in files, pgBadger, `pg_stat_statements`.

## Getting there

From the bastion, `ssh player@<node>` (the key is already in your
`~/.ssh`). On the node, `psql` connects you as the superuser role `dba`;
the password is in `~/.pgpass`. From the bastion, `psql -h <node>` works
too.

## What you can change

- **Configuration**: `/etc/postgresql/postgresql.conf` and
  `/etc/postgresql/pg_hba.conf`. They live outside the data directory.
  You can edit them (your account is in the `pgconf` group) and create
  files next to them. `ALTER SYSTEM` works as well.
- **Your home**, `/home/player`: notes, scripts, `~/report.md`.
- **The database** itself, through `psql` as `dba`.
- **The node's crontab**, if the node runs a cron daemon, through `sudo
  gm-crontab` (see "Scheduled jobs").

Changes to `/etc/postgresql` stay in place when PostgreSQL restarts.

## The server log and pgBadger

PostgreSQL writes its log to files in `/var/log/postgresql/`, if the
configuration says so (`logging_collector`, `log_directory`). You can read
them (your account is in the `pgconf` group) but not change them.

pgBadger is installed. Run it yourself, as `player`, no `sudo` needed;
write the report in your home:

```
pgbadger -o ~/pgbadger.html /var/log/postgresql/postgresql-*.log
```

What it can report depends on what PostgreSQL logs and how
(`log_line_prefix`, `log_min_duration_statement`, `lc_messages`, ...): that
is part of what you audit. A run on a large log uses this node's memory
and CPU, shared with PostgreSQL; `pgbadger --help` lists the options to
restrict it (`--begin`, `--end`, one file at a time).

To read the report on your own machine, copy it out in two hops. From the
bastion:

```
scp <node>:pgbadger.html .
```

then, from your machine, `sftp` to the bastion and `get pgbadger.html`.

## Query statistics

If the configuration preloads it (`shared_preload_libraries`), the view
`pg_stat_statements` in the database `postgres` lists the statements run
on the server and what they cost.

## Scheduled jobs

A database node may run jobs of its own, in two ways. Whether this one
does is part of what you find out.

**`pg_cron`**, an extension that runs SQL on a schedule inside
PostgreSQL. It is on when the configuration preloads it
(`shared_preload_libraries` lists `pg_cron`) and the extension exists
(`\dx` in the database `cron.database_name` names). As `dba`:

- the jobs: `select * from cron.job;` (each job's schedule, command,
  database and the role it runs as, `username`);
- their runs: `select * from cron.job_run_details order by start_time
  desc limit 20;`, while `cron.log_run` is on; with `cron.log_statement`
  on, each run also leaves a line in the server log, and so in pgBadger;
- changes: `cron.schedule`, `cron.unschedule`, `cron.alter_job`, and the
  `cron.*` settings.

Schedules are read in `cron.timezone`. A job runs as its role, with no
password.

**A cron daemon**, Debian's `cron`, running the crontab of the operating
system user `postgres`. When the node runs one, `ps -e` shows `cron`.

| Command | Does |
|---|---|
| `sudo gm-crontab -l` | Lists the crontab. |
| `sudo gm-crontab <file>` | Installs `<file>` (one you can read) as the new crontab, replacing the old one. `crontab` checks it first and refuses a file with errors, leaving the crontab as it was. The daemon reads the new one within the minute; it stays in place when the node restarts. |

The node's clock is UTC: a crontab's times are UTC times. An entry runs
as `postgres`; one connecting to PostgreSQL as `postgres` connects as a
superuser. An entry connecting as another role finds that role's password
in the file named by `PGPASSFILE` at the top of the crontab
(`/run/gm-cron/pgpass`), which only `postgres` can read. There is no mail
and no system log: a job's output goes where its entry sends it, by
convention a file in `/var/log/postgresql/cron/`, which you can read.
On a node without a cron daemon, `sudo gm-crontab <file>` refuses: nothing
would run it.

A job on the database node shares the node's memory and CPU with
PostgreSQL.

## Applying changes

You may run exactly four commands with `sudo`; the first three take no
arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-db` | Reloads the configuration, then lists what PostgreSQL found wrong in the files, including settings that need a restart. |
| `sudo gm-restart-db` | Checks that the configuration loads, then restarts PostgreSQL. It refuses to restart if the files do not load, so a typo does not take the server down. Your SSH session stays open. |
| `sudo gm-validate` | Runs the public validator. |
| `sudo gm-crontab -l`, `sudo gm-crontab <file>` | Lists or replaces the node's crontab (see "Scheduled jobs"). |

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- the server accepts connections;
- `pg_hba.conf` still holds the line `local all postgres peer`;
- the settings that have an *envelope* (an allowed range or set of values)
  are within it, both the value in effect and the value written in the
  files, waiting for a reload or a restart.

Some settings may start outside their envelope; that is a finding. The
validator is not a monitoring tool: run it to make sure you have not
broken the game. If you cannot make it green, report that too.

## Do not tamper

Changing the database configuration is expected. Do not change:

- the line `local all postgres peer` in `pg_hba.conf`: it is the game
  master's access to the node;
- SSH, `sudo`, the `gm-*` commands and the validator (they are read-only
  anyway);
- the password file `/run/gm-cron/pgpass`.

Being a database superuser also gives you access to the operating system
as `postgres` (for example `COPY ... TO PROGRAM`). Do not use it to get
around these rules.

## Good to know

- No ports of this node are published outside the game's network.
- If PostgreSQL does not come back after a restart, `gm-restart-db` says
  so; look at your last changes.
- A role named `monitoring` exists: the game's monitoring tools connect
  with it. Its password is not yours to read.
- Most of the system is read-only; `/tmp` is available.
