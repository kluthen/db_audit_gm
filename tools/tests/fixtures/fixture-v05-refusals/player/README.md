# Welcome

Nodes: `bastion` (you are here), `db` (PostgreSQL 18), `standby` (its
read-only replica), `exporter` (the PostgreSQL exporter), `producer` (the
order service's scheduler) and `lab-api` (the order API). Reach each with
`ssh <node>`; reach `db` with `psql` from there.

The external laboratory answers under its own hostname, `northfield-lab`;
the off-site vault under `cold-storage`.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer`, `local all gm_check scram-sha-256` and `host replication
replicator samenet scram-sha-256` in `/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
