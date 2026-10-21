# Probe — pg-join-index-missing

Descriptive only in v0.1. As `player`, with `psql` as `dba`:

1. `psql -d {DATABASE} -c '\d {TABLE_NAME}'` lists a foreign key on `{COLUMN}`
   and no index leading with it.
2. `psql -d {DATABASE} -c 'EXPLAIN SELECT * FROM {TABLE_NAME} WHERE {COLUMN} =
   42'` shows `Seq Scan on {TABLE_NAME}`.

Expected: both.
