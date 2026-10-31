# Probe — purpose-watermark-misses-updates

Descriptive only. As `player`:

1. On the runner node, `cat /srv/scheduler/repository/scripts/rollup.py`:
   the changed orders are those whose `placed_at` is past the watermark;
   nothing reads `updated_at`.
2. `grep 'job={JOB} ' /var/log/scheduler/scheduler.log | tail`: each
   run reads the hour's new orders only, the run after the noon close
   included.
3. From the bastion, a past day's `invoiced_revenue` in
   `rpt.sales_daily` (`psql -h reporting -d reporting`) against the
   source's invoiced total for that local day (`psql -h db -d shop`):
   lower in reporting, the gap growing after each noon.

Expected: 1 at any time; 2 and 3 from the first close of day after
planting.
