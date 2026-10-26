# PgBouncer node — player notes

What you may know about a PgBouncer node in a db_audit_gm game: the
connection pooler between the clients and the database. Initial version
(v0.3), expected to evolve.

## Getting there

- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **Through the pooler**: clients connect to `<node>` port `6432` with
  their usual role and password, for example from the bastion
  `psql -h <node> -p 6432 -U <role> <database>`. PgBouncer checks the
  password against the database: there is no separate password list.
- **The console**: the database `pgbouncer`, as role `dba` with `dba`'s
  password. From the bastion: `psql -h <node> -p 6432 -U dba pgbouncer`
  (your `~/.pgpass` there has the password). On the node itself, plain
  `psql` opens it (you type `dba`'s password, or copy the bastion's
  `~/.pgpass`). `SHOW POOLS;`, `SHOW STATS;`, `SHOW CLIENTS;`,
  `SHOW SERVERS;`, `SHOW CONFIG;`, `SHOW DATABASES;`, `SHOW HELP;`.
  `dba` reads the console but cannot change it: `RELOAD`, `SET`, `PAUSE`
  and the like answer "admin access needed".

## What you can change

- **Configuration**: `/etc/pgbouncer/pgbouncer.ini`: the databases
  (`[databases]`), per-role settings (`[users]`), and in `[pgbouncer]`
  the pool sizes, the pool mode, the limits and timeouts, the log detail.
  You can edit it (your account is in the `pgbconf` group). On some games
  the file is read-only: an edit gets "permission denied", and
  `gm-reload-pgbouncer` says the node is report-only.
- **Settings the game keeps**: the ports, the local socket, the log file,
  authentication and the console's users are set by the game master in
  `/usr/local/lib/gm/pgbouncer-gm.ini` (read-only), applied after your
  file: writing them in `pgbouncer.ini` has no effect. PgBouncer reads
  `/run/pgbouncer-conf/pgbouncer.ini`, your file with those settings
  added; you can read it. `%include` is not followed on this node: write
  your settings in `pgbouncer.ini` itself.
- **Your home**, `/home/player`: notes, scripts, `~/report.md`.

Changes to `/etc/pgbouncer` stay in place when PgBouncer restarts.

## Applying changes

You may run exactly two commands with `sudo`, with no arguments:

| Command | Does |
|---|---|
| `sudo gm-reload-pgbouncer` | Checks that PgBouncer loads `pgbouncer.ini`, then reloads it and prints the pool settings in effect. It refuses to reload a file that does not load, with PgBouncer's error and the line, so a typo never reaches the running pooler. |
| `sudo gm-validate` | Runs the public validator. |

`sed -i` works on `pgbouncer.ini`; the reload gives the file its usual
owner back.

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `pgbouncer.ini` loads, with no `%include`;
- PgBouncer answers on its console;
- the game's own settings are the ones in effect;
- the database `postgres`, where PgBouncer looks the logins up, is in
  `[databases]` (without it nobody can log in, the console included);
- the pool settings (`default_pool_size`, `max_client_conn`,
  `max_db_connections`, `reserve_pool_size`, `pool_mode`), in effect and
  in the file, and each database's own pool settings, are within the
  bounds set for this game.

The validator does not tell you whether the pools suit the load: that is
part of your audit.

## Do not tamper

Changing PgBouncer's configuration is expected. Do not change SSH, `sudo`,
the `gm-*` commands, the validator or the game's files under
`/usr/local/lib/gm` (they are read-only anyway).

## Good to know

- PgBouncer's log: `/var/log/pgbouncer/pgbouncer.log` (logins and
  logouts, a stats line per database every minute, errors).
- No metrics endpoint for PgBouncer: its console and its log are where
  to look. The node's own health is at `http://<node>:9110/metrics` when
  the game has a Prometheus node.
- No ports of this node are published outside the game's network.
- Most of the system is read-only; `/tmp` is available.
- Times are in UTC.
