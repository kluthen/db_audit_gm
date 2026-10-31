# Neon: a scheduled job's query changes plan, compute VMs stop suspending, IPs run out

- **Source**: [Delayed start compute operations: triggering event](https://neon.com/blog/delayed-start-compute-operations-triggering-event) (Neon blog, 2025-05-30, by Mihai Bojin and Matt Sherman; part of a series on the 2025-05-16 and 2025-05-19 us-east-1 outages). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261009132634/https://neon.com/blog/delayed-start-compute-operations-triggering-event)
- **Date of incident**: 2025-05-16 (AWS us-east-1)
- **Organization**: Neon (serverless PostgreSQL)
- **Kind of write-up**: engineering blog (part of an official post-mortem series)

## Tech stack

- Control plane: a regional Go service backed by a PostgreSQL database (version not stated). It starts and suspends compute VMs running Neon Postgres.

## Topology

- One control plane and database per region; each regional database plans its queries independently. The us-east-1 cluster had a planned capacity of 6,000 concurrent VMs and a tested ceiling of 10,000.

## Symptoms

- `fetchEndpointWithCompute` queries went from a few hundred milliseconds to over 100 seconds. The scheduled "Activity Monitor" job could not suspend idle computes, running VMs rose above 6,000, and the cluster hit IP allocation failures.

## Diagnosis

- Execution plan change on the Activity Monitor query: a suboptimal index choice caused a broad scan of the `computes` table and saturated database CPU.

## Root cause / main culprits

- The planner switched to a worse index for a multi-join query on `computes`, a table of tens of millions of rows of which only a small number are active.
- Contributing: table growth with index bloat and dead tuples; different table shapes across regions (so only some regions flipped); the job needs consistent reads and transactional writes, so it could not be moved to a read replica.

## Resolution

- `ANALYZE computes` restored the normal plan (us-east-1 during the incident, other regions later). The expensive subquery was wrapped in a materialized CTE as an optimisation fence.
- Follow-ups: more aggressive garbage collection to shrink `computes` to millions of rows; move historical data to an OLAP store; study what triggers plan changes.

## Impact and duration

- IP exhaustion in us-east-1; this part of the series gives no duration (it points to the top-level post-mortem).

## Notes (collector's own, not from the source)

- Combines a scheduled job with a plan flip: the job "succeeds" but slower and slower until its side effect (suspending VMs) stops happening. A lab analogue: a pg_cron job that marks rows processed, over a table full of dead history rows.
