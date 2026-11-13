# Probe — governance-statement-log-personal

Descriptive only. As `player`:

1. On the database node, `grep -n log_statement /etc/postgresql/postgresql.conf`:
   `log_statement = 'all'`.
2. On the database node, the server log (`/var/log/postgresql/`, readable
   by the players' group): `grep -h -E 'statement: (INSERT|UPDATE).*owners'
   /var/log/postgresql/postgresql-*.log | tail`: the practice software's
   writes as `vet_app`, owners' names, phone numbers and addresses in
   clear.
3. From the bastion, `psql -h <node> -d postgres -c 'SHOW log_statement'
   -c 'SELECT * FROM pg_db_role_setting'`: `all` server-wide.

Expected: 1 and 3 at any time; 2 from the practice software's first write
on `owners` after planting.
