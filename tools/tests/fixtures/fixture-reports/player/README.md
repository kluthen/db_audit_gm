# Welcome

Nodes: `bastion` (you are here), `records` (PostgreSQL 18, the clinic's
medical record in the database `clinic`, the back office's in `office`),
`standby` (PostgreSQL 18, the record's read-only standby, where the reports
read), `lab` (PostgreSQL 18, the laboratory's database `lab`) and
`backoffice` (the back office's report runner). Reach each with
`ssh <node>`; reach the databases with `psql` from there.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
