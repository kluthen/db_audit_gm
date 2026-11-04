# Welcome

Nodes: `bastion` (you are here), `records` (PostgreSQL 18, the clinic's
medical record in the database `clinic`), `clinic-api` (the record's lookup
API), `pms` (the practice software), `machines` (PostgreSQL 18, the
machines' three systems in the databases `pacs`, `vitals` and `biomed`),
`equipment` (the machines and their systems) and `interfaces` (the
integration engine). Reach each with `ssh <node>`; reach `records` and
`machines` with `psql` from there.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
