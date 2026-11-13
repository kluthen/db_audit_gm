# Probe — purpose-herd-use-dropped

Descriptive only. As `player`:

1. On the runner node, `grep -n -A20 'amu.feed.read:'
   /srv/scheduler/repository/queries.yaml`: the dispensings joined to
   `animals` with an inner `JOIN`; a herd prescription has no animal.
2. From the bastion, the daily use in `office` (`psql -h <target node> -d
   office`, `antimicrobial_use`): `herds_treated` 0 on every day, the
   record's herd visits (`psql -h <standby> -d clinic`: dispensings of
   prescriptions with a `herd_id` and no `animal_id`, on Tuesdays and
   Thursdays) not counted.
3. From the bastion, last year's report (`amu_reports`, the latest year):
   acknowledged with its reference, its cattle lines without a herd
   treated.

Expected: 1 and 3 at any time; 2 from the feeder's first run after a day
with a herd treatment.
