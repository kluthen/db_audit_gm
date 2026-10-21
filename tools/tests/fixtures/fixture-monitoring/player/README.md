# Welcome

Nodes: `bastion` (you are here), `db` (PostgreSQL 18), `prometheus`,
`exporter` (the PostgreSQL exporter) and `grafana`. Reach each with
`ssh <node>`; reach `db` with `psql` from there.

Prometheus and Grafana are on the bastion's web front, under `/prometheus/`
and `/grafana/`, with the tools password.

DO NOT TAMPER: `local all postgres peer` in `/etc/postgresql/pg_hba.conf`;
Grafana's administrator account.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
