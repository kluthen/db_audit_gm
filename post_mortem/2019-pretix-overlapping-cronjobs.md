# pretix: a slow periodic job overlaps itself across the cluster after a network blip

- **Source**: [Brought down by cronjobs - analysis of an outage today](https://behind.pretix.eu/2019/11/24/cronjobs) (pretix blog, behind.pretix.eu). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260520013521/https://behind.pretix.eu/2019/11/24/cronjobs/)
- **Date of incident**: 2019-11-24, about 06:57 to 07:28 CET
- **Organization**: pretix (ticketing SaaS)
- **Kind of write-up**: engineering blog (official incident analysis)

## Tech stack

- Django application; periodic work via `python -m pretix runperiodic` launched by cron on each application server. Separate database servers (engine and version not stated in the post).

## Topology

- Four application servers, each running the periodic command from cron on shifted schedules (six runs per hour in total), all talking over the data-centre network to the database servers.

## Symptoms

- A data-centre network disruption raised latency and errors between app and database servers. Periodic runs took longer, cron started new runs before old ones ended, and servers ran out of memory. Service down from about 06:57; reachable again about 07:04 with three of four app servers still failing.

## Diagnosis

- Alerted around 07:02, problem identified around 07:14. Later, per-task timing of each run showed a normal run took just over 14 minutes, about 11 of them selecting orders for expiry warnings.

## Root cause / main culprits

- A periodic job whose runtime had crept up to roughly its scheduling interval, so any slowdown made runs overlap and multiply load until memory ran out.
- cron does not stop a new run while the previous one is still going.
- Trigger: the network disruption. Underlying condition: task code that got slower as data grew, already noticed but not treated as urgent.

## Resolution

- Rebooted app nodes one by one, disabled the cron job on one server.
- Same day: optimised the slowest task (about 14 minutes down to about 1 minute when no e-mails are due) and moved from cron to systemd timers, because "the main benefit of systemd timers is that they never get started while the previous job is already running".
- Considered: run some tasks daily, a more structured task system or Celery Beat, without creating a single point of failure.

## Impact and duration

- About 7 minutes of full outage and partial degradation until about 07:28 CET. No figures on affected customers.

## Notes (collector's own, not from the source)

- Directly reusable for the project's cron / pg_cron bricks: a job close to its interval plus added latency. In PostgreSQL, overlapping runs also show up as many identical queries in `pg_stat_activity` with the same `application_name`, and possibly as row-lock waits if the job updates the same rows. `flock -n` or pg_cron's own single-run behaviour are the fixes players might propose.
