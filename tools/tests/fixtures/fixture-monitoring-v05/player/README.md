# Welcome

Nodes: `bastion` (you are here), `records` (PostgreSQL 18), `prometheus`,
`pgwatch` (a PostgreSQL metrics collector), `grafana` and `health` (the
health checks and their status page). Reach each with `ssh <node>`; reach
`records` with `psql` from there.

Prometheus, Grafana and the health page are on the bastion's web front,
under `/prometheus/`, `/grafana/` and `/health/`, with the tools password.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`; Grafana's administrator account.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
