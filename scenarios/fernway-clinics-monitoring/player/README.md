# Welcome to Fernway's monitoring and database audit

You are on the **bastion**, your only way into the system. Read
`story.md` for the customer's background and `issues.md` for what you are
asked to look at. You have up to 4 hours.

## The system

| Node | What it is | Your access | Write policy |
|---|---|---|---|
| `bastion` | this machine: SSH, PostgreSQL 18 client tools, the web front, your notes and report | you are here, as `player` | **report-only**: nothing to fix here |
| `db` | the clinics' PostgreSQL 18 server, database `clinic` | `ssh db` as `player`; `psql` as the role `dba` | **fixable** |
| `prometheus` | Prometheus, which collects the metrics | `ssh prometheus`; its web interface | **fixable** |
| `exporter` | the PostgreSQL exporter, which reads PostgreSQL's statistics for Prometheus | `ssh exporter` | **fixable** |
| `grafana` | Grafana: the dashboards and the alert rules | `ssh grafana`; its web interface | **fixable** |

All five nodes are on one private network. From outside, only the
bastion's SSH port and its web front port are reachable.

- `ssh <node>` logs you in to a node as `player` (the key is in
  `~/.ssh/id_ed25519`).
- `psql -h db` from the bastion, or `psql` on `db`, connects you as the
  superuser role `dba` (the password is in `~/.pgpass` on both
  machines). Add `-d clinic` for the clinics' database.
- On a fixable node, changing the configuration is expected: explain
  every change in your report.

## The web interfaces

The game master gives you the web front's port and the **tools
password**. In your browser:

| Address | What |
|---|---|
| `http://<bastion address>:<web port>/prometheus/` | Prometheus: targets, queries |
| `http://<bastion address>:<web port>/grafana/` | Grafana: dashboards, alerting |

The browser asks for a user and password: user `player`, the tools
password. Grafana then asks for its own login: user `admin`, the same
tools password. Without them you get "401 Unauthorized"; "502 Bad
Gateway" means the interface is not up yet (try again in a minute). The
connection is plain HTTP: use the tools password only for this game.

The metrics history starts when the game was set up: the dashboards have
little to show for the first 10 to 15 minutes.

## Each node in short

- **`db`**: configuration in `/etc/postgresql/postgresql.conf` and
  `/etc/postgresql/pg_hba.conf` (you may edit them; `ALTER SYSTEM` works
  too). The server log is in `/var/log/postgresql/` (read-only for you).
  pgBadger is installed: `pgbadger -o ~/pgbadger.html
  /var/log/postgresql/postgresql-*.log`, run as `player`.
- **`prometheus`**: `/etc/prometheus/prometheus.yml` (scrape targets,
  retention); `curl` works on the node, for example `curl -s
  http://localhost:9090/prometheus/api/v1/targets`.
- **`exporter`**: `/etc/postgres-exporter/exporter.conf`; `curl -s
  http://localhost:9187/metrics` shows what it serves.
- **`grafana`**: provisioning files under `/etc/grafana/provisioning/`
  (data source, dashboards, alert rules). What came from these files
  cannot be changed in Grafana's UI: change the file, then reload.
- **Node health**: every node reports its own health at
  `http://<node>:9110/metrics` (CPU, memory, disk, services), from the
  list in `/opt/gm/node-health/node.conf` on that node. The script and
  its list are read-only: if they are wrong, report it or propose a fix.
- Nothing sends alerts by e-mail or chat: firing alerts are shown in
  Grafana's alerting view.
- The bastion has no `curl`; the other nodes do. Times are in UTC
  everywhere.

## Applying changes

On each fixable node you may run a few commands with `sudo`, with no
arguments:

| Node | Command | Does |
|---|---|---|
| `db` | `sudo gm-reload-db` | reloads the configuration, then lists what PostgreSQL found wrong in the files, including settings that need a restart |
| `db` | `sudo gm-restart-db` | checks that the configuration loads, then restarts PostgreSQL; it refuses if the files do not load. Your SSH session stays open |
| `prometheus` | `sudo gm-reload-prometheus` | checks `prometheus.yml` with `promtool`, then reloads it; it refuses a file that does not load |
| `exporter` | `sudo gm-restart-exporter` | checks `exporter.conf`, then restarts the exporter and prints `pg_up` (1: connected to the database) |
| `grafana` | `sudo gm-reload-grafana` | reloads the data source, dashboards and alert rules from the files; it refuses a dashboard file that is not valid JSON |
| every one | `sudo gm-validate` | runs the node's public validator (below) |

Prometheus' own HTTP reload and administration endpoints are disabled:
use `sudo gm-reload-prometheus`.

## The validators

Each node has one: `sudo gm-validate` on the fixable nodes, `gm-validate`
(no `sudo`) on the bastion. It prints `GREEN: ...` and exits 0, or one
`RED ...` line per broken rule and exits 1. It checks that the node is
still in working order: its configuration files load and are the ones in
effect, its service answers, and on `db` that the game master's line is
in `pg_hba.conf` and the settings with an *envelope* (an allowed range of
values) are within it.

The validators are not monitoring tools: they do not tell you whether
the monitoring watches the right things, which is your audit. Run them to
make sure you have not broken the game. If you cannot make one green,
report that too.

## Rules

- Work only through the bastion and the nodes above, with the accounts
  above.
- Changing the configuration is expected on the fixable nodes; stay
  inside the envelopes `db`'s validator checks. Explain every change in
  your report.
- The game master answers no questions during the game: hints, restarts,
  resets and extra time are refused. You may ask to stop.

## DO NOT TAMPER

- **Grafana's users and the administrator's password**: do not change
  `admin`'s password, rename or delete it, or add, change or remove
  users. The game master's own checks log in as `admin` with the tools
  password. Grafana lets you do it, so nothing stops you: the rule is
  yours to keep. Several failed logins in a row lock `admin` for a few
  minutes.
- On `db`: the lines `local all postgres peer`, `local replication
  postgres peer` and `local all gm_check scram-sha-256` in
  `/etc/postgresql/pg_hba.conf`: they are the game master's access to
  the node.
- On every node: SSH, `sudo`, the `gm-*` commands, the validator, and
  the node-health script and its list (read-only anyway).
- On the bastion: `~/.ssh/id_ed25519`, `~/.pgpass` and
  `~/.gm-starter-copied`.

Being a database superuser also gives you access to the operating system
of `db` as `postgres` (for example `COPY ... TO PROGRAM`). It cannot be
prevented, so it is a rule: do not use it to get around the list above.
A role named `monitoring` exists for the exporter; its password is not
yours to read.

## Your report

Write it in `~/report.md` on the bastion (or keep it on your machine and
paste it to the game master). For each issue, and for anything else you
found, in the database or in the monitoring: what is wrong, the evidence
(where you looked, what you saw), why it matters, and what you did or
recommend. Say what you would do first. Tell the game master when it is
your **final answer**.
