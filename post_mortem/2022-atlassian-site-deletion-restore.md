# Atlassian: a maintenance script deletes 883 customer sites; restoring them from multi-tenant backups takes two weeks

- **Source**: [Post-Incident Review on the Atlassian April 2022 outage](https://www.atlassian.com/engineering/post-incident-review-april-2022-outage) (Atlassian Engineering). Archive: [web.archive.org snapshot](https://web.archive.org/web/20240716122133/https://www.atlassian.com/engineering/post-incident-review-april-2022-outage)
- **Date of incident**: 2022-04-05 07:38 UTC (deletion script ran until 08:01 UTC); all sites restored by 2022-04-18
- **Organization**: Atlassian (Jira, Confluence and other cloud products)
- **Kind of write-up**: official post-incident review

## Tech stack

- AWS, multiple regions and availability zones; internal PaaS ("Micros"). Many distributed data stores per site (engines not named), with full plus incremental backups, 30-day retention, point-in-time restore.

## Topology

- Multi-tenant: each shard holds many tenants, and one site's data is spread across many stores rather than one database.

## Symptoms

- Customers' sites disappeared. The first support ticket arrived at 07:46 UTC; internal monitoring did not alert because the deletions used a normal workflow. Deleting a site also deleted its URL and admin contacts, so affected customers struggled to open tickets.

## Diagnosis

- Escalated at 08:17 UTC; at 08:53 UTC the team linked the tickets to the script run.

## Root cause / main culprits

- A script meant to remove a legacy app ("Insight - Asset Management") was given site IDs instead of app IDs. The deletion API accepted either kind of ID without checking, and deleted whole sites immediately.
- Peer review looked at the endpoint and call method, not the IDs; staging tests passed because those IDs did not exist there.
- No runbook or tooling for restoring many sites and their linked products at once; tenants' data sat in shared stores, so each site had to be extracted from backups by hand.

## Resolution

- Bulk site deletion blocked. "Restoration 1" (about 70 steps, new identifiers, about 48 hours per batch) for 112 sites; "Restoration 2" (reusing original identifiers, about 12 hours per site) for 771 sites. More than 450 support engineers ran manual validation. Code freeze from 2022-04-08.
- Follow-ups: soft deletes with retention, staged rollouts and tested rollback for deletions; automated multi-site restore and regular DR exercises at that scale; large-incident playbook; customer contacts backed up outside the product.

## Impact and duration

- 883 sites (775 customers), outages of up to 14 days. RPO of one hour met ("no customer lost more than five minutes of data"); RTO missed. For 57 early-restored customers some databases were restored to an earlier point than intended; that data was later recovered.

## Notes (collector's own, not from the source)

- Two culprits worth a game: a destructive admin call that accepts the wrong kind of identifier, and backups that are fine for whole-database restore but useless for restoring one tenant out of a shared database. A lab could plant the second with a multi-tenant PostgreSQL schema and a `pg_dump`-only backup.
