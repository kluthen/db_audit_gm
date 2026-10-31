# Welcome

Nodes: `bastion` (you are here), `db` (the shop's PostgreSQL 18 server,
database `shop`), `pooler` (PgBouncer), `producer` (the web shop),
`consumer` (the back office's dashboards), `reporting` (Lumen Analytics'
PostgreSQL 18 server, database `reporting`), `bi` (Lumen's roll-ups),
`crm` (the marketing team's and the shipping manager's jobs), `gateway`
(the customs gateway's callback), `prometheus`, `exporter` (the
PostgreSQL exporter) and `grafana`. Reach each with `ssh <node>`; reach
`db` and `reporting` with `psql -h <node>` from here, as `dba`.

Prometheus and Grafana are on the bastion's web front, under
`/prometheus/` and `/grafana/`, with the tools password. The company's
data policy is in `data-policy.md`. The company works in
{{customer_timezone}}; the machines in UTC.

Jobs you may move (in `/srv/scheduler/jobs/jobs.yaml`, then `sudo
gm-reload-scheduler`): `close-day` on `producer`; `leads-extract`,
`mail-shipped`, `mail-campaign`, `declare-exports` and
`escalate-customs` on `crm`. There is no "run now": to see a job work
after a fix, move its time a few minutes ahead, reload, then put it
back.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer`, `local all gm_check scram-sha-256` and `host all
gm_check samenet scram-sha-256` in `/etc/postgresql/pg_hba.conf` on `db`
and `reporting`; Grafana's administrator account.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
