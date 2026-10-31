# Clerk: autoanalyze samples only NULLs and flips a hot query's plan

- **Source**: [2026-02-19 system outage postmortem](https://clerk.com/blog/2026-02-19-system-outage-postmortem) (Clerk blog). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261010193212/https://clerk.com/blog/2026-02-19-system-outage-postmortem)
- **Date of incident**: 2026-02-19, from 16:11 UTC; stable at 18:06 UTC
- **Organization**: Clerk (authentication service)
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL (version, managed service and pooler not stated).

## Topology

- Not stated, apart from a new session-token failover path outside the core Session API.

## Symptoms

- Request handlers queued as queries slowed; more than 95% of traffic got HTTP 429 without being handled; the rest returned slowly. Sign-in and account management unavailable. The automatic Session API failover did not trigger because the database was degraded, not down.

## Diagnosis

- Initially suspected a customer's traffic spike; it turned out to be an aggressive retry pattern, and the failures came from inside Clerk. Root cause (autoanalyze leading to a bad plan) confirmed at 17:25 UTC. No specific tools named.

## Root cause / main culprits

- "A routine auto analyze led to a query plan flip". The ANALYZE sample of a very skewed column contained only NULLs, so the planner took the column as 100% NULL (actual figure about 99.9996%) and chose a plan that then scanned over 17,000 rows per call, consuming nearly all database resources.
- Contributing: unstable statistics on skewed data; no alerting for plan flips; failover not automated and the team not yet trained on enabling it manually; client retries.

## Resolution

- 17:08 to 17:10 UTC: enabled the session-token failover; 17:27 UTC: manual `ANALYZE` restored the previous plan; 18:06 UTC: stable.
- Follow-ups: plan-flip alerting; automatic failover triggers and training; higher statistics target on the table; refactor the query for deterministic planning; audit similar queries; formal incident communication.

## Impact and duration

- About 90 minutes to restoration, about two hours to confirmed stability; most customer requests rejected in that window.

## Notes (collector's own, not from the source)

- Lab-friendly: a column that is almost entirely NULL, a query filtering on `col IS NOT NULL`, and a small statistics target. Running `ANALYZE` repeatedly gives different `null_frac` in `pg_stats`, and sometimes the bad plan.
