# Probe — purpose-receiver-down-unnoticed

Descriptive only. As `player`:

1. On the runner node, `cat /srv/scheduler/repository/queries.yaml`:
   `escalate.customs` joins the rejections only; a declaration with no
   answer is never selected.
2. From the bastion, `psql -h db -d shop`, the evidence's query:
   declarations by hour against acknowledgements and incidents, two
   hours of the morning with none answered and none escalated, and a few
   unanswered every hour since.
3. On the runner, `grep 'run job=escalate-customs .*phase=end'
   /var/log/scheduler/scheduler.log`: `rows=0` through the outage.
4. On the receiver node, `cat /srv/scheduler/repository/queries.yaml`
   and the scheduler's log: the stream switched to
   `customs.unavailable`, then back.

Expected: 1 at any time; 2 and 3 from 47 minutes after the outage's
start; 4 from the outage.
