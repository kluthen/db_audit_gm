# postgres-exporter node — player notes

What you may know about a postgres-exporter node in a db_audit_gm game.
Initial version (v0.2), expected to evolve.

The node runs `postgres_exporter`, which reads PostgreSQL's statistics
and serves them as metrics for Prometheus.

## Getting there

- **Shell**: from the bastion, `ssh player@<node>` (the key is already in
  your `~/.ssh`).
- **Metrics**: `http://<node>:9187/metrics` from any node of the game, in
  Prometheus' text format; for example, on this node,
  `curl -s http://localhost:9187/metrics | grep '^pg_up '`. `pg_up 1`
  means the exporter reached the database on its last scrape. There is no
  web interface through the bastion's web front; Prometheus scrapes this
  node, and Grafana shows what Prometheus keeps.
- `curl` and `jq` are installed.

## What you can change

- **Settings**: `/etc/postgres-exporter/exporter.conf`. You can edit it
  (your account is in the `expconf` group). One `KEY=value` per line;
  lines starting with `#` are comments:

  | Key | Holds |
  |---|---|
  | `DATA_SOURCE_URI` | the database's address: `<node>:5432/postgres?sslmode=disable` |
  | `DATA_SOURCE_USER` | the role the exporter connects as |
  | `COLLECTORS` | optional: `--collector.<name>` and `--no-collector.<name>` words, space-separated; for example `--collector.stat_statements` for the query statistics (`pg_stat_statements_*` metrics). The names this exporter knows: `/usr/local/lib/gm/exporter-collectors`. |

  Values are taken as written: no quotes, no spaces.
- **Your home**, `/home/player`: notes, scripts, `~/report.md`.

Changes to `/etc/postgres-exporter` stay in place when the exporter
restarts.

The role's password is not in the file and you cannot read it: the
exporter reads it from a file only its own account can open.

## Applying changes

The exporter reads its settings only when it starts. You may run exactly
two commands with `sudo`, with no arguments:

| Command | Does |
|---|---|
| `sudo gm-restart-exporter` | Checks `exporter.conf`, then restarts the exporter with it and prints `pg_up` (1: connected to the database; 0: not connected). It refuses to restart with a file that is not valid, and leaves the running exporter alone. |
| `sudo gm-validate` | Runs the public validator. |

## The validator

`sudo gm-validate` prints `GREEN: ...` and exits 0 when all is well. When
something is wrong it prints one `RED ...` line per broken rule and exits
1. It checks that:

- `exporter.conf` is valid: known keys only, each once, the address and
  the user set, collectors this exporter has;
- the exporter answers on port 9187;
- the exporter runs the file as it is now (otherwise restart it).

The validator does not tell you whether the exporter watches the right
database, or whether it is connected: `pg_up` and your audit do.

## Do not tamper

Changing `exporter.conf` is expected. Do not change SSH, `sudo`, the
`gm-*` commands or the validator (they are read-only anyway).

## Good to know

- No ports of this node are published outside the game's network.
- The exporter's log goes to the container's output, which you do not
  see. If a restart fails, `gm-restart-exporter` says so.
- Every request to `/metrics` runs queries on the database.
- Most of the system is read-only; `/tmp` is available.
- Times are in UTC.
