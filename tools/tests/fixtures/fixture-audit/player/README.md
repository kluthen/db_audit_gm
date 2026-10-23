# Welcome

Nodes: `bastion` (you are here) and `db` (PostgreSQL 18). Reach `db` with
`ssh db`, then `psql`.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run the validator on `db` with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
