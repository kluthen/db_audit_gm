# Probe — scheduler-transaction-held-open

Descriptive only. As `player`:

1. From the bastion, `psql -c "SELECT application_name, state, now() -
   xact_start, backend_xmin FROM pg_stat_activity WHERE state LIKE 'idle
   in transaction%'"` shows a session of the scheduler node idle in
   transaction for minutes, at any moment.
2. On the scheduler node, the `{KEY}` entry of
   `/srv/scheduler/repository/queries.yaml` carries `transaction:
   {isolation: repeatable read, hold: ...}`, and the key's `p50_ms` in
   the log's `key` lines is near the hold.
3. From the bastion, `pg_stat_user_tables` shows `n_dead_tup` rising on
   the updated tables while `last_autovacuum` moves on.

Expected: 1 and 2 at once; 3 within two hours under load.
