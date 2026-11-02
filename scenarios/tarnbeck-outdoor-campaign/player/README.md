# Welcome to Tarnbeck Outdoor's audit

You are on the **bastion**, your only way into the system. Read
`story.md` for the customer's background, `issues.md` for what you are
asked to look at, and `data-policy.md`, the company's data policy. You
have up to 4 hours. The shop has been running since last night and keeps
running while you work.

## The system

| Node | What it is | Your access | Write policy |
|---|---|---|---|
| `bastion` | this machine: SSH, PostgreSQL 18 client tools, the web front, your notes and report | you are here, as `player` | **report-only**: nothing to fix here |
| `db` | the shop's PostgreSQL 18 server, database `shop` | `ssh db` as `player`; `psql` as the role `dba` | **fixable** |
| `pooler` | PgBouncer, between the web shop and the database | `ssh pooler`; `psql -h pooler -p 6432` | **fixable** |
| `producer` | the web shop's application | `ssh producer` | **report-only**, except its code (`/srv/scheduler/repository`) and its jobs (`/srv/scheduler/jobs`), which are **fixable** |
| `crm` | the marketing team's and the shipping manager's jobs | `ssh crm` | **report-only**, except its code (`/srv/scheduler/repository`) and its jobs (`/srv/scheduler/jobs`), which are **fixable** |
| `gateway` | the customs gateway's callback, which acknowledges the export declarations | `ssh gateway` | **report-only**: the customs authority's |
| `reporting` | Lumen Analytics' PostgreSQL 18 server, database `reporting` | `ssh reporting` as `player`; `psql` as the role `dba` | the database lets you change it, but it is **Lumen's**: report what you find and propose what Lumen should change |
| `bi` | Lumen's roll-ups, which fill the reporting database | `ssh bi` | **report-only**: Lumen's |
| `consumer` | the back office's dashboards, which read the reporting database | `ssh consumer` | **report-only**, except its jobs (`/srv/scheduler/jobs`), which are **fixable** (it has none today) |
| `prometheus` | Prometheus, which collects the metrics | `ssh prometheus`; its web interface | **report-only** |
| `exporter` | the PostgreSQL exporter, which reads `db`'s statistics for Prometheus | `ssh exporter` | **fixable** |
| `grafana` | Grafana: the dashboards and the alert rules | `ssh grafana`; its web interface | **fixable** |

All twelve nodes are on one private network. From outside, only the
bastion's SSH port and its web front port are reachable.

- You log in to the bastion as `player` with the bastion password the
  game master gave you: the bastion takes no SSH key. The key in
  `~/.ssh/id_ed25519` is only for the hops from the bastion to the nodes:
  `ssh <node>` logs you in to a node as `player` with it.
- `psql -h db` or `psql -h reporting` from the bastion, or `psql` on
  either node, connects you as the superuser role `dba` (the password is
  in `~/.pgpass` on the bastion and on both nodes). Add `-d shop` for the
  shop's database, `-d reporting` for Lumen's.
- `psql -h pooler -p 6432 -U dba pgbouncer` from the bastion opens
  PgBouncer's console (`SHOW POOLS;`, `SHOW STATS;`, `SHOW DATABASES;`,
  `SHOW HELP;`); on `pooler`, plain `psql` does (`dba`'s password is in
  `~/.pgpass` there too).
- On a fixable node or path, changing the configuration is expected:
  explain every change in your report. On a report-only one, report what
  you find and propose what to change. On Lumen's `reporting`, you have
  the access but the system is not Tarnbeck's: what should change there
  is Lumen's to do, so it goes in your report as a proposal.

## The web interfaces

The game master gives you the web front's port and the **tools
password**. In your browser:

| Address | What |
|---|---|
| `http://<bastion address>:<web port>/` | this starter pack, the data policy included |
| `http://<bastion address>:<web port>/prometheus/` | Prometheus: targets, queries |
| `http://<bastion address>:<web port>/grafana/` | Grafana: dashboards, alerting |

The browser asks for a user and password: user `player`, the tools
password. Grafana then asks for its own login: user `admin`, the same
tools password. Without them you get "401 Unauthorized"; "502 Bad
Gateway" means the interface is not up yet (try again in a minute). The
connection is plain HTTP: use the tools password only for this game.

The metrics history starts when the system was set up last night.

## Each node in short

- **`db`** and **`reporting`**: configuration in
  `/etc/postgresql/postgresql.conf` and `/etc/postgresql/pg_hba.conf`
  (`ALTER SYSTEM` works too). The server log is in `/var/log/postgresql/`
  (read-only for you). pgBadger is installed: `pgbadger -o ~/pgbadger.html
  /var/log/postgresql/postgresql-*.log`, run as `player`. Query
  statistics: the view `pg_stat_statements`, in the database `postgres`.
  Each server may run jobs of its own: `pg_cron` (`SELECT * FROM
  cron.job;` in the database `cron.database_name` names) and a crontab,
  listed with `sudo gm-crontab -l`, whose jobs log to
  `/var/log/postgresql/cron/`.
- **`pooler`**: `/etc/pgbouncer/pgbouncer.ini`; the log is
  `/var/log/pgbouncer/pgbouncer.log`.
- **`producer`**, **`crm`**, **`bi`**, **`consumer`** and **`gateway`**:
  each application's queries are in `/srv/scheduler/repository/queries.yaml`
  (with `builders/` or `scripts/`, small Python files some of them run),
  its fixed-time jobs in `/srv/scheduler/jobs/jobs.yaml` (times in UTC),
  its log in `/var/log/scheduler/scheduler.log` (one `summary` line and
  one `key` line per query a minute, and a `run job=...` line at each
  job's start and end), its metrics at `curl -s
  http://localhost:9120/metrics`. The traffic itself (who calls what, how
  often) is the customers' and the staff's: you cannot read or change
  it.
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
- The bastion has no `curl`; the other nodes do. The machines' clocks,
  logs, crontabs and `jobs.yaml` are in UTC; Tarnbeck's own times are in
  {{customer_timezone}}.

## Applying changes

On each node you may run a few commands with `sudo`:

| Node | Command | Does |
|---|---|---|
| `db`, `reporting` | `sudo gm-reload-db` | reloads the configuration, then lists what PostgreSQL found wrong in the files, including settings that need a restart |
| `db`, `reporting` | `sudo gm-restart-db` | checks that the configuration loads, then restarts PostgreSQL; it refuses if the files do not load. Your SSH session stays open |
| `db`, `reporting` | `sudo gm-crontab -l`, `sudo gm-crontab <file>` | lists the server's crontab, or installs `<file>` (one you can read) as the new crontab; it refuses a file with errors |
| `pooler` | `sudo gm-reload-pgbouncer` | checks that PgBouncer loads `pgbouncer.ini`, then reloads it and prints the pool settings in effect |
| `producer`, `crm`, `consumer` | `sudo gm-reload-scheduler` | checks the queries and the jobs, then has the application reload them and prints when each job runs next (UTC); it refuses, and reloads nothing, when a file does not load |
| `exporter` | `sudo gm-restart-exporter` | checks `exporter.conf`, then restarts the exporter and prints `pg_up` (1: connected to the database) |
| `grafana` | `sudo gm-reload-grafana` | reloads the data source, dashboards and alert rules from the files; it refuses a dashboard file that is not valid JSON |
| every one | `sudo gm-validate` | runs the node's public validator (below) |

An application's change takes effect only once `sudo
gm-reload-scheduler` has run.

## The jobs you may move

There is no "run now" for a job, on any node: nobody, you or the game
master, runs a job outside its schedule. To see a job work after a fix,
move its time a few minutes ahead, reload, wait for its run, then put it
back (unless its time was what needed fixing). These are the jobs you may
move:

| Node | Job | Where | Then |
|---|---|---|---|
| `producer` | `close-day` | `/srv/scheduler/jobs/jobs.yaml` | `sudo gm-reload-scheduler` |
| `crm` | `leads-extract`, `mail-shipped`, `mail-campaign`, `declare-exports`, `escalate-customs` | `/srv/scheduler/jobs/jobs.yaml` | `sudo gm-reload-scheduler` |
| `db` | the hourly refresh of the best-sellers list (`popular-products`, its log `/var/log/postgresql/cron/popular-products.log`) | the crontab: `sudo gm-crontab -l > ~/crontab`, edit, `sudo gm-crontab ~/crontab` | the cron daemon reads it within the minute |

`bi`'s jobs, and the jobs in and on the reporting database, are Lumen's:
you may read them, not move them. When you change something outside a
job (a role, a table, a setting), note in your report the time you made
the change.

## The validators

Each node has one: `sudo gm-validate` on every node but the bastion,
`gm-validate` (no `sudo`) there. It prints `GREEN: ...` and exits 0, or
one `RED ...` line per broken rule and exits 1. It checks that the node
is still in working order: its configuration files load and are the ones
in effect, its service answers, and on `db`, `reporting` and `pooler`
that the settings with an *envelope* (an allowed range of values) are
within it.

The validators are not audit tools: whether the jobs are right, the data
where it should be or the monitoring complete is your audit. Run them to
make sure you have not broken the shop. If you cannot make one green,
report that too.

## Rules

- Work only through the bastion and the nodes above, with the accounts
  above.
- Changing the configuration is expected where it is fixable; stay
  inside the envelopes the validators check. Explain every change in your
  report.
- The shop's traffic is not yours to change: nobody, you or the game
  master, stops, slows or replays it, and nobody runs a job by hand.
- The game master answers no questions during the game: hints, restarts,
  resets and extra time are refused. You may ask to stop.

## DO NOT TAMPER

- **Grafana's users and the administrator's password**: do not change
  `admin`'s password, rename or delete it, or add, change or remove
  users. The game master's own checks log in as `admin` with the tools
  password. Grafana lets you do it, so nothing stops you: the rule is
  yours to keep. Several failed logins in a row lock `admin` for a few
  minutes.
- On `db` and `reporting`: the lines `local all postgres peer`, `local
  replication postgres peer`, `local all gm_check scram-sha-256` and
  `host all gm_check samenet scram-sha-256` in
  `/etc/postgresql/pg_hba.conf`: they are the game master's access to the
  databases. The role `gm_check` is the game master's too. The password
  file `/run/gm-cron/pgpass`.
- On every node: SSH, `sudo`, the `gm-*` commands, the validator, and
  the node-health script and its list (read-only anyway); on `producer`,
  `crm`, `bi`, `consumer` and `gateway`, the program under
  `/usr/local/lib/python3.13/` and `/etc/scheduler/`.
- On the bastion: `~/.ssh/id_ed25519`, `~/.pgpass` and
  `~/.gm-starter-copied`.

Being a database superuser also gives you access to the operating system
of `db` and `reporting` as `postgres` (for example `COPY ... TO
PROGRAM`). It cannot be prevented, so it is a rule: do not use it to get
around the list above. The roles `monitoring` (the exporter's) and
`pgbouncer_lookup` (the pooler's) exist; their passwords are not yours
to read. A builder or script you edit on `producer` or `crm` is code the
application runs: keep to what Tarnbeck's own application would do.

## Your report

Write it in `~/report.md` on the bastion (or keep it on your machine and
paste it to the game master). For each issue, and for anything else you
found, in the databases, the jobs, the monitoring or against the data
policy: what is wrong, the evidence (where you looked, what you saw, at
what time), why it matters, and what you did, with the time you did it,
or what you recommend, and to whom (Tarnbeck or Lumen). Say what you
would do first. Tell the game master when it is your **final answer**.
