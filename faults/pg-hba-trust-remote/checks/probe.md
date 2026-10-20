# Probe — pg-hba-trust-remote

Descriptive only in v0.1. As `player`:

1. On the bastion: `PGPASSFILE=/nonexistent psql -w -h {database node} -U dba -c
   'SELECT 1'` prints `1` (a password-less login succeeds).
2. On the database node (`ssh {database node}`): `cat /etc/postgresql/pg_hba.conf`
   shows a `host ... 0.0.0.0/0 trust` line before the `scram-sha-256`
   ones.

Expected: both, so the fault is visible and its effect testable from the
player's side.
