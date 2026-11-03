# Probe — pg-abandoned-replication-slot

Descriptive only in v0.1. As `player`, with `psql` as `dba`:

1. `psql -XAt -c "SELECT slot_name, active FROM pg_replication_slots"`
   prints the slot with `f` (inactive).
2. `psql -XAt -c "SELECT count(*) FROM pg_stat_replication"` prints `0`
   (with a standby, v0.5: `psql -XAt -c "SELECT s.slot_name FROM
   pg_replication_slots s JOIN pg_stat_replication r ON r.pid =
   s.active_pid"` prints only the standby's slot, never the planted one).

Expected: both.
