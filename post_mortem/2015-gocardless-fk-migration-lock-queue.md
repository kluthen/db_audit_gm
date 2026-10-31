# GoCardless: re-adding foreign keys on idle tables queues behind a slow SELECT and blocks the API

- **Source**: [Zero-downtime Postgres migrations - the hard parts](https://gocardless.com/blog/zero-downtime-postgres-migrations-the-hard-parts/) (GoCardless blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261007021156/https://gocardless.com/blog/zero-downtime-postgres-migrations-the-hard-parts) (the earliest archived copy is from 2015-10-09)
- **Date of incident**: "late January", year not stated in the post. The earliest archive copy (October 2015) and "a few months ago" suggest January 2015; this year is the collector's inference.
- **Organization**: GoCardless
- **Kind of write-up**: engineering blog (incident analysis)

## Tech stack

- PostgreSQL (version not stated; the post mentions 9.4 only for `VALIDATE CONSTRAINT`'s weaker lock). Ruby on Rails-style schema migrations.

## Topology

- Not stated.

## Symptoms

- About 15 seconds of API request timeouts during a planned deploy; recovered when the migration finished.

## Diagnosis

- Re-running the migration against a backup from earlier that day took a few hundred milliseconds, so the migration itself was not slow.
- The team found a mailing-list thread and a blog post describing the behaviour, then read PostgreSQL's `ALTER TABLE` locking code.

## Root cause / main culprits

- The migration renamed empty, unused tables and dropped and recreated their foreign keys (the team did not know constraints can be renamed in place).
- Adding a foreign key takes an `AccessExclusive` lock on both the referencing and the referenced table, even with `NOT VALID`. The referenced `parent` table was busy, and a long-running `SELECT` held an `AccessShare` lock on it.
- The `ALTER TABLE` waited in the lock queue, and every later query on `parent` queued behind it.

## Resolution

- Recommendations from the post: set `lock_timeout` in migrations ("It's better to abort a deploy than take your application down."); eliminate long-running queries and transactions and run analytics on an asynchronous replica; enable `log_min_duration_statement` and `log_lock_waits`; split schema changes into small pieces; keep PostgreSQL up to date; be careful with open transactions in production consoles.

## Impact and duration

- About 15 seconds of API downtime.

## Notes (collector's own, not from the source)

- Very easy to reproduce in a lab: one session holds `BEGIN; SELECT ... FROM parent;` open, another runs `ALTER TABLE child ADD FOREIGN KEY ... REFERENCES parent`, and all application queries on `parent` hang. `pg_locks` shows the `AccessExclusiveLock` request waiting. A reporting job on the primary is the natural "long SELECT".
