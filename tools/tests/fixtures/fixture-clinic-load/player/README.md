# Welcome

Nodes: `bastion` (you are here), `records` (PostgreSQL 19, the clinic's
medical record, wards and agenda in the database `clinic` and the owners'
portal in the database `portal`, the back office's database `office`), `lab` (PostgreSQL 19, the laboratory's
database `lab`) and `machines` (PostgreSQL 19, the machines' systems in the
databases `pacs`, `vitals` and `biomed`). Reach each with `ssh <node>`;
reach the databases with `psql` from there.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
The data policy is in `data-policy.md`.
Write your report in `~/report.md`.
