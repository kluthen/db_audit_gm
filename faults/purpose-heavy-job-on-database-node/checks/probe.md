# Probe — purpose-heavy-job-on-database-node

Descriptive only. As `player` on the database node, after the incident:
`grep -h -A1 -E 'terminated by signal 9|terminating any other|reinitializing|automatic recovery|ready to accept' /var/log/postgresql/postgresql-*.log`
shows, at the entry's minute, a backend killed by signal 9 while running
`CALL rpt.sales_detail_rollup()`, the other processes ended, the
automatic recovery, and connections accepted again seconds later;
`cat /sys/fs/cgroup/memory.events` reads `oom_kill 1`;
`tail /var/log/postgresql/cron/sales-detail-rollup.log` ends with the
connection to the server lost; `psql -d <database>` shows the run with no
`finished_at` in `rpt.etl_runs` (job `sales-detail-rollup`) and the
backfill request in `rpt.sales_detail_backfills`, `taken_at` set and
`done_at` empty, its `days` far beyond a night; `sudo gm-crontab -l` the
entry calling the procedure as the loader; `\sf rpt.sales_detail_rollup`
the single `jsonb_agg` over the whole window.

Expected: one out-of-memory kill of the roll-up's backend, recovered from
by PostgreSQL alone, caused by the backfill request; nothing to fix on
the node, a report to write.
