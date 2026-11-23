# Welcome to Aldermoor Veterinary Hospital North's audit

You are on the **bastion**, your only way into the system. Read
`story.md` for the centre's background, `issues.md` for what you are
asked to look at, `data-policy.md`, the franchise's data policy for the
centre, `partners.md`, the partners the centre works with and its
credentials with them, `data-register.md`, the centre's register of
what it holds, where and for how long, and `network-overview.md`, the
centre's own description of its machines. You have up to 4 hours. The centre
has been running since last night and keeps running while you work.

## The system

The centre's machines, and **Your access** on each (the rule for what you may
change), are in its network overview, `network-overview.md`, also on the web front.

- You log in to the bastion as `player`, with no password: the bastion
  asks for none and takes no SSH key. The key in
  `~/.ssh/id_ed25519` is only for the hops from the bastion to the nodes:
  `ssh <node>` logs you in to a node as `player` with it.
- `psql -h <server>` from the bastion, or `psql` on a database node,
  connects you as the superuser role `dba` (the password is in `~/.pgpass`
  on the bastion and on the database nodes). Add `-d <database>`.
- Where the overview gives you **write** access (a fixable node or path),
  changing the configuration is expected: explain every change in your
  report. Where it gives you **read-only** access (a report-only node),
  report what you find and propose what to change, and to whom (the
  centre, a vendor, a partner). The `bastion` is your kit, report-only:
  nothing to fix there.
- The partners' services answer on `http://<hostname>:8000/`, with the
  centre's credentials from `partners.md` where one is needed. Calling
  them is allowed; nothing else of theirs is yours to touch.

## The web interfaces

The game master gives you the web front's port and the **tools
password**. In your browser:

| Address | What |
|---|---|
| `http://<bastion address>:<web port>/` | the home page: your documents (this starter pack, the network overview, the data policy, the partners and the data register included) and the links to every web interface (Prometheus, Grafana, the health checks' page) |

The browser asks for a user and password: user `player`, the tools
password. Grafana then asks for its own login: user `admin`, the same
tools password. Without them you get "401 Unauthorized"; "502 Bad
Gateway" means the interface is not up yet (try again in a minute). The
connection is plain HTTP: use the tools password only for this game.

The metrics history starts when the system was set up last night.

## Each node in short

- **`records`, `standby`, `lab`, `machines`**: configuration in
  `/etc/postgresql/postgresql.conf` and `/etc/postgresql/pg_hba.conf`
  (`ALTER SYSTEM` works too, except on the standby, which is read-only).
  The server log is in `/var/log/postgresql/` (read-only for you).
  pgBadger is installed: `pgbadger -o ~/pgbadger.html
  /var/log/postgresql/postgresql-*.log`, run as `player`. Query
  statistics: the view `pg_stat_statements`, in the database `postgres`.
  Replication: `pg_stat_replication` on `records`,
  `pg_stat_wal_receiver` and `pg_last_xact_replay_timestamp()` on the
  standby; the archiver: `pg_stat_archiver`. Each server may run jobs of
  its own: `pg_cron` (`SELECT * FROM cron.job;` in the database
  `cron.database_name` names) and a crontab, listed with `sudo gm-crontab
  -l`, whose jobs log to `/var/log/postgresql/cron/`.
- **`pms`, `lis`, `ward`, `equipment`, `interfaces`, `backoffice`**: each
  application's queries are in `/srv/scheduler/repository/queries.yaml`
  (with `builders/` or `scripts/`, small Python files some of them run),
  its fixed-time jobs in `/srv/scheduler/jobs/jobs.yaml` (times in UTC).
  The traffic itself (who calls what, how often) is the staff's, the
  owners' and the partners': you cannot read or change it. Its log is `/var/log/scheduler/scheduler.log` (one `summary` line and
  one `key` line per query a minute, and a `run job=...` line at each
  job's start and end), its metrics at `curl -s
  http://localhost:9120/metrics`.
- **`clinic-api`, `lab-api`, `portal-api`**: `/srv/api/api.yaml` (which
  hostname serves which endpoint, the credentials, the connections),
  `/srv/api/routes/` (the contract, read-only), `/srv/api/db/` (each
  endpoint's database side: its queries, transactions and session
  settings), the request log `/var/log/api/api.log`.
- **`prometheus`**: `/etc/prometheus/prometheus.yml` (scrape targets,
  retention); `curl -s http://localhost:9090/prometheus/api/v1/targets`.
- **The exporters**: `/etc/postgres-exporter/exporter.conf`; `curl -s
  http://localhost:9187/metrics` shows what each serves.
- **`pgwatch`**: `/etc/pgwatch/sources.yaml`, the databases it watches;
  its readings are in Prometheus (the job `pgwatch`) and Grafana's pgwatch
  dashboard; `curl -s http://localhost:9188/metrics` on the node.
- **`health`**: `/etc/health/health.yaml`, the instances it checks, and
  `/etc/health/scripts/`, the IT's own checks; its crontab with `sudo
  gm-crontab -l`.
- **`grafana`**: provisioning files under `/etc/grafana/provisioning/`
  (data source, dashboards, alert rules). What came from these files
  cannot be changed in Grafana's UI: change the file, then reload.
- **Node health**: every node reports its own health at
  `http://<node>:9110/metrics` (CPU, memory, disk, services), from the
  list in `/opt/gm/node-health/node.conf` on that node. The script and
  its list are read-only: if they are wrong, report it or propose a fix.
- Nothing sends alerts by e-mail or chat: firing alerts are shown in
  Grafana's alerting view.
- The machines' clocks, logs, crontabs and `jobs.yaml` are in UTC; the
  centre's own times are in {{customer_timezone}}.

## Applying changes

On each node you may run a few commands with `sudo`:

| Node | Command | Does |
|---|---|---|
| `records`, `standby`, `lab`, `machines` | `sudo gm-reload-db` | reloads the configuration, then lists what PostgreSQL found wrong in the files, including settings that need a restart |
| `records`, `standby`, `lab`, `machines` | `sudo gm-restart-db` | checks that the configuration loads, then restarts PostgreSQL; it refuses if the files do not load. Your SSH session stays open |
| `records`, `lab`, `machines`, `health` | `sudo gm-crontab -l`, `sudo gm-crontab <file>` | lists the node's crontab, or installs `<file>` (one you can read) as the new crontab; it refuses a file with errors |
| `interfaces`, `backoffice` | `sudo gm-reload-scheduler` | checks the queries and the jobs, then has the application reload them and prints when each job runs next (UTC); it refuses, and reloads nothing, when a file does not load |
| `lab-api`, `portal-api` | `sudo gm-reload-api` | checks every endpoint, then restarts the API with the files as they are; it refuses on the first problem and keeps the running server |
| the exporters | `sudo gm-restart-exporter` | checks `exporter.conf`, then restarts the exporter and prints `pg_up` (1: connected to the database) |
| `pgwatch` | `sudo gm-restart-pgwatch` | checks `sources.yaml`, restarts pgwatch and prints `pgwatch_instance_up` for each source |
| `health` | `sudo gm-run-checks` | runs the checks at once and rewrites the page |
| `grafana` | `sudo gm-reload-grafana` | reloads the data source, dashboards and alert rules from the files; it refuses a dashboard file that is not valid JSON |
| every one | `sudo gm-validate` | runs the node's public validator (below) |

An application's change takes effect only once `sudo
gm-reload-scheduler` (or `sudo gm-reload-api`) has run.

## The jobs you may move

There is no "run now" for a job, on any node: nobody, you or the game
master, runs a job outside its schedule. To see a job work after a fix,
move its time a few minutes ahead, reload, wait for its run, then put it
back (unless its time was what needed fixing). These are the jobs you may
move:

| Node | Job | Where | Then |
|---|---|---|---|
| `interfaces` | `post-lab-orders`, `fetch-lab-results`, `deliver-practice-results`, `send-outs`, `chase-send-outs`, `sync-exchanges`, `chase-exchanges`, `notify-vet`, `notify-lab`, `escalate-notifications`, `check-in`, `book-requests`, `cancel-deceased`, `post-imaging-orders`, `fetch-imaging-reports`, `ship-partitions`, `sync-portal-identity`, `publish-records`, `publish-results`, `queue-notices`, `queue-reminders`, `send-messages` | `/srv/scheduler/jobs/jobs.yaml` | `sudo gm-reload-scheduler` |
| `backoffice` | `copy-notifications`, `feed-medicines-register`, `feed-controlled-drugs`, `close-medicines-register`, `balance-controlled-drugs`, `inventory-controlled-drugs`, `feed-antimicrobial-use`, `report-antimicrobial-use`, `feed-working-time`, `close-working-time`, `feed-daily-figures`, `send-monthly-figures`, `feed-lab-charges`, `close-lab-statements` | `/srv/scheduler/jobs/jobs.yaml` | `sudo gm-reload-scheduler` |
| `records`, `lab`, `machines` | the nightly base backup to Cold Storage (its log `/var/log/postgresql/cron/basebackup.log`) | the crontab: `sudo gm-crontab -l > ~/crontab`, edit, `sudo gm-crontab ~/crontab` | the cron daemon reads it within the minute |
| `records`, `machines` | the `pg_cron` jobs: the portal's sessions' purge on `records`, the day partitions on `machines` | `cron.job` in the database `jobs` (`cron.alter_job`) | at once |

The vendors' applications' jobs (`pms`, `lis`, `ward`, `equipment`) are
theirs: you may read them, not move them. When you change something
outside a job (a role, a table, a setting), note in your report the time
you made the change.

## The validators

Each node has one: `sudo gm-validate` on every node but the bastion,
`gm-validate` (no `sudo`) there. It prints `GREEN: ...` and exits 0, or
one `RED ...` line per broken rule and exits 1. It checks that the node
is still in working order: its configuration files load and are the ones
in effect, its service answers, and on the database servers that the
settings with an *envelope* (an allowed range of values) are within it.

The validators are not audit tools: whether the jobs are right, the data
where it should be, the register true or the monitoring complete is your
audit. Run them to make sure you have not broken the centre. If you
cannot make one green, report that too.

## Rules

- Work only through the bastion and the nodes above, with the accounts
  above, and the partners' published services with the centre's
  credentials.
- Changing the configuration is expected where it is fixable; stay
  inside the envelopes the validators check. Explain every change in your
  report.
- The centre's traffic is not yours to change: nobody, you or the game
  master, stops, slows or replays it, and nobody runs a job by hand.
- The game master answers no questions during the game and speaks for no
  partner: hints, restarts, resets and extra time are refused. You may
  ask to stop.

## DO NOT TAMPER

- **Grafana's users and the administrator's password**: do not change
  `admin`'s password, rename or delete it, or add, change or remove
  users. The game master's own checks log in as `admin` with the tools
  password. Grafana lets you do it, so nothing stops you: the rule is
  yours to keep. Several failed logins in a row lock `admin` for a few
  minutes.
- On the database servers: the lines `local all postgres peer`, `local
  replication postgres peer` and `local all gm_check scram-sha-256` in
  `/etc/postgresql/pg_hba.conf`: they are the game master's access to the
  databases. The role `gm_check`, and its policies named `gm_check_read`
  (on `cron.job`, `cron.job_run_details` and every table with row-level
  security, each commented "the game master's read access: DO NOT
  TAMPER"), are the game master's too. The password file
  `/run/gm-cron/pgpass`.
- On every node: SSH, `sudo`, the `gm-*` commands, the validator, and
  the node-health script and its list (read-only anyway); on the
  applications' and the APIs' nodes, the programs under
  `/usr/local/lib/python3.13/` and `/etc/scheduler/`.
- On the bastion: `~/.ssh/id_ed25519`, `~/.pgpass` and
  `~/.gm-starter-copied`.

Being a database superuser also gives you access to the operating system
of the database servers as `postgres` (for example `COPY ... TO
PROGRAM`). It cannot be prevented, so it is a rule: do not use it to get
around the list above. The roles `monitoring` (the monitoring tools') and
`replicator` (the standby's) exist where they are used; their passwords
are not yours to read. A script or query you edit on `interfaces`,
`backoffice` or an API's database side is code the centre runs: keep to
what the centre's own application would do.

## Your report

Write it in `~/report.md` on the bastion (or keep it on your machine and
paste it to the game master). For each issue, and for anything else you
found, in the databases, the jobs, the monitoring, against the data
policy or against the data register: what is wrong, the evidence (where
you looked, what you saw, at what time), why it matters, and what you
did, with the time you did it, or what you recommend, and to whom (the
centre, a vendor, a partner; for a partner, the message you would send
its support). Say what you would do first. Tell the game master when it
is your **final answer**.
