# Probe — scheduler-query-error

Descriptive only. As `player`, on the scheduler node (`ssh <node>` from
the bastion):

1. `grep 'error key={KEY} ' /var/log/scheduler/scheduler.log | tail`
   prints error lines with a SQLSTATE of class 42 or 22 and PostgreSQL's
   message, a few each minute.
2. `grep 'key minute=.* key={KEY} ' /var/log/scheduler/scheduler.log |
   tail` shows `errors=` above 0 in every minute.
3. `curl -s localhost:9120/metrics | grep 'scheduler_errors_total{key="{KEY}"}'`
   climbs between two reads.
4. The `{KEY}` entry of `/srv/scheduler/repository/queries.yaml` shows the
   error in its SQL.

Expected: all four within ten minutes of planting, under load.
