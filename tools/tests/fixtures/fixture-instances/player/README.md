# Welcome

Nodes: `bastion` (you are here), `db` and `reporting` (PostgreSQL 18, one
instance each). Reach either with `ssh db` or `ssh reporting`, then `psql`.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer`, `local all gm_check scram-sha-256` and `host all gm_check
samenet scram-sha-256` in `/etc/postgresql/pg_hba.conf`.

Run the validator on a node with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
