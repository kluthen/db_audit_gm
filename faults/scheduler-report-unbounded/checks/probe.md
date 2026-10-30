# Probe — scheduler-report-unbounded

Descriptive only. As `player`:

1. On the scheduler node, the `{KEY}` entry of
   `/srv/scheduler/repository/queries.yaml` reads `SELECT *` from a large
   table with no condition on `{DATE_COLUMN}`, sorted or grouped.
2. On the node, `grep 'key minute=.* key={KEY} '
   /var/log/scheduler/scheduler.log | tail`: latencies in seconds.
3. From the bastion, `psql -d postgres` (where the extension is): `SELECT
   calls, rows, mean_exec_time, temp_blks_written FROM
   pg_stat_statements ORDER BY temp_blks_written DESC` lists the report
   first, temporary blocks at every call.

Expected: all three within half an hour of planting, under load.
