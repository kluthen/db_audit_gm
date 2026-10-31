# Mandrill: transaction ID wraparound on one hot shard, 40 hours of impaired sending

- **Source**: [What we learned from the recent Mandrill outage](https://mailchimp.com/what-we-learned-from-the-recent-mandrill-outage/) (Mailchimp, 2019-03-26, by Eric Muntz). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260821124021/https://mailchimp.com/what-we-learned-from-the-recent-mandrill-outage/)
- **Date of incident**: 2019-02-04 05:35 UTC to 2019-02-05 22:09 UTC
- **Organization**: Mailchimp (Mandrill transactional e-mail)
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL (version not stated) used as a sharded key-value store, plus job-queue tables on the same databases.
- Application servers queue failed jobs and write logs to local disk.

## Topology

- Several separate PostgreSQL databases acting as shards (count not stated). The hashing scheme sent more writes to one shard, "shard4", which also held job-queue tables.

## Symptoms

- Sending impaired: "During the outage, we were sending only 80% of queued emails."
- Failed jobs piled up on app-server disks across the fleet; retries of failed writes added load on shard4.

## Diagnosis

- The first exception appeared overnight and was buried among unrelated errors. Investigation opened at 11:58 UTC; wraparound identified at 12:56 UTC.
- Engineers had flagged in November 2018 that XIDs were approaching half the limit at peak.

## Root cause / main culprits

- XID wraparound on shard4: the database went into its safety shutdown. Autovacuum likely fell behind under the heavy write load on that shard, or failed; the team could not confirm which.
- Contributing: hot shard from uneven hashing, alert lost in log noise, retries amplifying load, app servers' disks filling with queued jobs and logs, knowledge concentrated in a few people, little visibility into job health.

## Resolution

- A standalone VACUUM started at 14:16 UTC on 2019-02-04; its estimate went up to 40 days. A dump and restore was also too slow.
- At 19:12 UTC on 2019-02-05 the team truncated the terabyte-scale Search and Url tables; the vacuum finished about an hour later. Backlog sending resumed at 21:36 UTC; wraparound alerting was in place at 22:40 UTC.
- Follow-ups: customer refunds and credits, incident-command changes (3-hour IC rotations, scribe, liaison roles). Few engineering details beyond the new alerting.

## Impact and duration

- About 40.5 hours of reduced sending (queues normal at 01:00 UTC 2019-02-06). Mandrill drops queued mail older than 48 hours by default, which put a deadline on recovery.

## Notes (collector's own, not from the source)

- Same mechanism as the Sentry 2015 entry, but the interesting lab angle is the uneven shard: one shard burning XIDs much faster than its siblings, and an early warning (XID age at half the limit) that was noticed months earlier and not acted on.
