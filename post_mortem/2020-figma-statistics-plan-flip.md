# Figma: a routine statistics update makes PostgreSQL 9 mis-plan an ORM query

- **Source**: [Post-mortem: service disruption on January 21-22, 2020](https://www.figma.com/blog/post-mortem-service-disruption-on-january-21-22-2020/) (Figma blog, 2020-01-29, by John Firebaugh). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260730125504/https://www.figma.com/blog/post-mortem-service-disruption-on-january-21-22-2020/)
- **Date of incident**: 2020-01-21 (about 06:00 to 07:00 PST) and 2020-01-22 (11:42 to 20:15 PST, with emergency maintenance 19:00 to 20:15)
- **Organization**: Figma
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL on Amazon RDS. Version 9.x before the incident (the bug reproduced on 9.6.16, not on 10.0); upgraded to PostgreSQL 11 during the incident. ORM-generated SQL.

## Topology

- Not stated (no description of replicas or how app servers connect).

## Symptoms

- Elevated error rates, alerts; API requests queuing until the service was unavailable for some users.
- Day 1: high database CPU. Day 2: high write IOPS, temp bytes and lock contention, with lower CPU.

## Diagnosis

- `pg_stat_user_tables` showed an automatic ANALYZE finishing as the incident started.
- After the incident: restored snapshots from before and after, compared `EXPLAIN` plans, reproduced on a test database, bisected PostgreSQL versions with official Docker images, read mailing lists, release notes and commits.

## Root cause / main culprits

- Day 1: a long-running expensive query drove CPU up; cancelling it recovered.
- Day 2: "a routine change in database statistics caused PostgreSQL 9 to mis-plan the execution of one of our queries". The planner estimated over 20 million rows where the real answer was 3, leading to full scans and heavy temp-buffer writes. PostgreSQL 10 had added a uniqueness-based join optimisation that avoided this.
- Contributing: a vacuum backlog from day 1's long query triggered aggressive autovacuum (more locking and writes); an over-complex ORM query; ANALYZE sampling likely underestimating distinct values in a clustered column.

## Resolution

- Cancelled expensive and non-essential queries, raised provisioned IOPS, cancelled autovacuum on the largest tables (temporary help), changed `autovacuum_freeze_max_age` and rebooted (about 15:00), then upgraded to PostgreSQL 11 in an evening window (tested in staging for months).
- Follow-ups: transaction timeouts and limits; better monitoring of autovacuum, locks and query performance; audit of queries with excessive joins and subqueries; review of data placement; online upgrades; offline-mode improvements in the product.

## Impact and duration

- Intermittent unavailability over two days; total downtime and user counts not stated.

## Notes (collector's own, not from the source)

- Plan flips are hard to plant deterministically. A lab can force one by skewing data in a column and then running `ANALYZE` with a low `default_statistics_target`, or by deleting statistics on purpose. The player-visible signal is a sudden change in `pg_stat_statements` mean time for one query with no deploy.
