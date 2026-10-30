# Probe — scheduler-update-without-where

Descriptive only. As `player`:

1. On the scheduler node, the `{KEY}` entry of
   `/srv/scheduler/repository/queries.yaml` is an `UPDATE` with no
   `WHERE`.
2. On the node, `grep 'key minute=.* key={KEY} '
   /var/log/scheduler/scheduler.log | tail`: the key's latencies far above
   a one-row update's.
3. From the bastion, `psql -d postgres` (where the extension is): `SELECT calls,
   rows, rows / calls FROM pg_stat_statements WHERE query ILIKE
   'update%'` gives the table's row count per call;
   `pg_stat_user_tables` shows `n_tup_upd` and `n_dead_tup` climbing.

Expected: 1 to 3 within the first minutes; dead rows and lock waits
within the hour.
