# Probe — scheduler-insert-retry-duplicates

Descriptive only. As `player`:

1. On the scheduler node, `/srv/scheduler/repository/queries.yaml` maps
   the ingestion key to a builder whose code sends its `INSERT` a second
   time for a share of the calls (the `resend` option).
2. From the bastion, `psql -d {DATABASE} -c 'SELECT {ID_COLUMN}, count(*)
   FROM {TABLE_NAME} GROUP BY 1 HAVING count(*) > 1'` lists ids stored
   twice, more each time.
3. `psql -d {DATABASE} -c '\d {TABLE_NAME}'` shows no unique constraint
   or unique index on `{ID_COLUMN}`.

Expected: 2 within minutes of the load's start; all three at any time.
