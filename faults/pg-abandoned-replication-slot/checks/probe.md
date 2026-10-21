# Probe — pg-abandoned-replication-slot

Descriptive only in v0.1. As `player`, with `psql` as `dba`:

1. `psql -XAt -c "SELECT slot_name, active FROM pg_replication_slots"`
   prints the slot with `f` (inactive).
2. `psql -XAt -c "SELECT count(*) FROM pg_stat_replication"` prints `0`.

Expected: both.
