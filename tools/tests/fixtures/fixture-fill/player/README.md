# Welcome

Nodes: `bastion` (you are here), `db` (PostgreSQL 18), `pooler`
(PgBouncer), `producer` (the web shop's scheduler), `consumer` (the back
office's scheduler), `prometheus` and `exporter` (the PostgreSQL
exporter). Reach each with `ssh <node>`; reach `db` with `psql` from
there, and the pooler with `psql -h pooler -p 6432`.

Prometheus is on the bastion's web front, under `/prometheus/`, with the
tools password.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
