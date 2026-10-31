# Probe — purpose-mail-overlapping-window

Descriptive only. As `player`:

1. On the runner node, `cat /srv/scheduler/jobs/jobs.yaml`: the `{JOB}`
   job runs `mail.shipped` every five minutes.
2. `cat /srv/scheduler/repository/queries.yaml`: `mail.shipped` takes the
   orders shipped in the last ten minutes, with no look at `mail_outbox`.
3. `grep 'run job={JOB} .*phase=end' /var/log/scheduler/scheduler.log |
   tail`: each run's `rows=` about twice what five minutes of shipping
   gives.
4. From the bastion, `psql -h db -d shop`: `SELECT order_id, count(*)
   FROM mail_outbox WHERE template = 'order-shipped' GROUP BY order_id
   HAVING count(*) > 1`: orders with two notices, five minutes apart.

Expected: 1 and 2 at any time; 3 and 4 from the job's second run after
planting.
