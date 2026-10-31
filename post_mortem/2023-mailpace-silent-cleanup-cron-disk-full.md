# MailPace: a silently failing retention cron lets data pile up until PostgreSQL runs out of disk

- **Source**: [Postgres outage post mortem](https://mailpace.com/blog/musings/postgres-outage-post-mortem) (MailPace blog, 2023-08-30; the old URL blog.mailpace.com/blog/postgres-outage-post-mortem redirects here). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260918212844/https://mailpace.com/blog/musings/postgres-outage-post-mortem)
- **Date of incident**: 2023-08-11, 13:36 to 15:50 BST
- **Organization**: MailPace (transactional e-mail)
- **Kind of write-up**: official post-mortem (company blog)

## Tech stack

- Managed PostgreSQL from an unnamed provider (version not stated). Ruby on Rails app; a daily Rake task run by cron enforces a 30-day retention policy.

## Topology

- A single managed database instance with an off-site backup about six hours old. No hot replica (being investigated).

## Symptoms

- The database was about 1.5 times its expected size and close to capacity. Then all transactions failed across services; the database went offline and would not restart, reporting it was out of space. Status pages stayed green because the app URL still returned HTTP 200.

## Diagnosis

- Records older than the retention window were still present: the clean-up job had been ending with `killed` (likely out of memory) every day.
- Given 8 GB instead of 1 GB, the job ran for a few minutes and the database then ran out of space. The post suspects WAL growth, pending the provider's confirmation; vacuum is not mentioned.

## Root cause / main culprits

- "Our Cron Job to remove old data was failing silently": `destroy_all` per domain, cascading across more than ten related tables, made each deletion huge.
- Contributing: "Our Database plan was under specified for growth"; health checks that did not touch the database; two provider support engineers working the same case; a migration that left the database read-only.

## Resolution

- Deleted old data manually, day by day, watching memory and size; moved to a much larger instance.
- Clean-up now uses `in_batches(of: 50)` and runs four times a day; cron monitoring on every job; `/health` endpoint that checks the database and returns 500 on failure; hot replica under investigation.

## Impact and duration

- Just over two hours without sending; read-only from 15:25 (users could log in but not send).

## Notes (collector's own, not from the source)

- Two classic culprits in one: a cron job whose failure nobody sees, and a catch-up delete so large that its WAL fills the disk. A lab can plant both with a retention job killed by a memory limit and a small data volume; `pg_wal` size and `pg_stat_user_tables.n_dead_tup` are the signals.
