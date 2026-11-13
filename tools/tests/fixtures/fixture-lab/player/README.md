# Welcome

Nodes: `bastion` (you are here), `lab` (PostgreSQL 18) and `exporter` (the
PostgreSQL exporter). Reach each with `ssh <node>`; reach `lab` with `psql`
from there.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
