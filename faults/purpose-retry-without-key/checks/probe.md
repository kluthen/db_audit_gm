# Probe — purpose-retry-without-key

Descriptive only. As `player`:

1. On the runner node, `cat /srv/scheduler/repository/scripts/lab_orders.py`:
   `post()` reads the ledger's timed-out references and posts such a
   group again as `f"{ref}-{started:%H%M}"`, a client_ref the lab has
   never seen.
2. `grep 'lab-api timeout' /var/log/scheduler/scheduler.log`: a post the
   runner gave up on; the next `post-lab-orders` run posted its group
   again.
3. From the bastion, the ledger (`psql -h records -d clinic`,
   `ops.lab_orders_sent`): the timed-out `C-{consultation}-{priority}`
   beside a `C-{consultation}-{priority}-{HHMM}` with the same request
   ids; at the lab (`psql -h lab -d lab`), both orders, the same requests
   on two order tests (LO2).

Expected: 1 at any time; 2 and 3 only after a post answered later than
the runner's ten-second timeout, a few a week in the clinic.
