# Probe — pg-table-autovacuum-off

Descriptive only in v0.1. As `player`, with `psql` as `dba`:

1. `psql -d {DATABASE} -c '\d+ {TABLE_NAME}'` ends with `Options:
   autovacuum_enabled=off`.
2. `psql -XAt -d {DATABASE} -c "SELECT relname, reloptions FROM pg_class
   WHERE relkind = 'r' AND reloptions IS NOT NULL"` lists the table.

Expected: both, while `SHOW autovacuum` prints `on` and the validator is
green on that rule.
