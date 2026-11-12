# Probe — purpose-urgent-priority-dropped

Descriptive only. As `player`:

1. On the runner node, `cat /srv/scheduler/repository/scripts/lab_orders.py`:
   `post()` sends the order's `"priority"` through
   `{"stat": "urgent"}.get(priority, "routine")`; the record says
   `urgent`, never `stat`, so every order goes out `routine`.
2. From the bastion, the centre's orders at the lab (`psql -h lab -d lab`,
   `lab_orders` of account 1): the `C-{consultation}-urgent` references
   are `routine`, their tests waiting for the next release round.
3. From the bastion, the record's requests (`psql -h records -d clinic`):
   those orders' requests are `urgent`, `sent` long before they are
   `resulted`, no sooner than the routine ones.

Expected: 1 at any time; 2 and 3 from the first urgent request posted
after planting.
