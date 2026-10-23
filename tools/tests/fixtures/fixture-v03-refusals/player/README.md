# Welcome

Nodes: `bastion` (you are here), `db` (PostgreSQL 18) and `producer` (the
shop's order service). Reach them with `ssh db` or `ssh producer`. Times
are the customer's, {{customer_timezone}}.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run the validator on a node with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
