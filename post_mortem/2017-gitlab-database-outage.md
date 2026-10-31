# GitLab.com database outage: replication break, data directory wiped on the primary, every backup method failing

- **Source**: [Postmortem of database outage of January 31](https://about.gitlab.com/blog/2017/02/10/postmortem-of-database-outage-of-january-31/) (GitLab blog, 2017-02-10). Archive: [web.archive.org snapshot](https://web.archive.org/web/20250215180901/https://about.gitlab.com/blog/2017/02/10/postmortem-of-database-outage-of-january-31/)
- **Date of incident**: 2017-01-31 (restoration finished 2017-02-01 around 18:00 UTC)
- **Organization**: GitLab (GitLab.com)
- **Kind of write-up**: official post-mortem

## Tech stack

- PostgreSQL 9.6 in production. The `pg_dump` backup job ran the 9.2 binaries (Omnibus picked 9.2 on an application server that had no local data directory).
- Streaming replication to a hot standby. WAL archiving was not enabled.
- pgpool-II was being tested in staging for load balancing; no pooler in production is described.
- Hosted on Azure. Backups: daily `pg_dump` uploaded to S3 (failing), LVM snapshots (made to copy data to staging), Azure disk snapshots (enabled on NFS servers, not on database servers).

## Topology

- One primary (`db1.cluster.gitlab.com`) and one hot-standby secondary (`db2.cluster.gitlab.com`) used only for failover. All load went through the single primary.
- Staging on Azure classic disks (slow), which later made the restore slow.
- Region: not stated.

## Symptoms

- About 19:00 UTC: database load rose (attributed to spam). Users could not post comments on issues and merge requests.
- About 23:00 UTC: the secondary lagged, then stopped replicating because the primary had already removed the WAL segments it needed.

## Diagnosis

- Engineers tried to re-seed the secondary with `pg_basebackup`, which printed nothing useful even with `--verbose`; the `max_wal_senders` error only showed after several attempts. `strace` showed it blocked in `poll`.
- After raising `max_wal_senders`, PostgreSQL would not restart ("too many semaphores"), traced to `max_connections` being set to 8000.
- When looking for backups, the S3 bucket was found empty; the version mismatch was traced through `PG_VERSION`; failure e-mails from cron had been rejected because DMARC was not configured for them.

## Root cause / main culprits

- **Trigger**: load spike from spam, plus a background job hard-deleting an employee account that had been flagged for abuse by mistake.
- **Replication**: the standby fell too far behind, the primary recycled WAL it still needed, and there was no WAL archive to fall back on.
- **Human error on the wrong host**: while trying to re-seed the standby, an engineer ran the data-directory wipe on the primary instead; about 300 GB was removed before it was stopped.
- **Configuration**: `max_connections` = 8000 (for almost a year), `max_wal_senders` = 3 (default).
- **Backups**: `pg_dump` 9.2 against a 9.6 server failed silently; alerts lost to DMARC; no database disk snapshots; LVM snapshots not meant for disaster recovery; nobody owned testing backup and restore.
- **Documentation**: `pg_basebackup` waiting silently for the primary was not in the runbooks.

## Resolution

- `max_connections` lowered to 2000, `max_wal_senders` raised to 32.
- Restored from a manual LVM snapshot taken about 6 hours earlier; copying it from slow staging disks took about 18 hours.
- Sequences bumped by 100,000 to avoid reusing lost IDs; webhooks restored separately from a staging copy.
- Follow-ups (15 tracked issues): hourly LVM snapshots, Azure disk snapshots for databases, point-in-time recovery and continuous archiving, automated restore testing, a backup monitoring dashboard, review of abuse handling.

## Impact and duration

- About 18 hours down. Database records created in a window of about 6 hours were lost (the post says 17:20 to 23:30 UTC in one place and to 00:00 UTC in another): an estimated 5,000 projects, 5,000 comments and about 700 user accounts. Git repositories and wikis were unavailable but not lost. Self-managed customers were not affected.

## Notes (collector's own, not from the source)

- Several independent faults line up here: replication lag past WAL retention, a backup tool/server version mismatch, alert mail silently dropped, an over-sized `max_connections`, and an operator acting on the wrong host. Each one is reproducible on a small lab with two PostgreSQL nodes.
- The "wrong host" part depends on the players having shell access and similar-looking hostnames. The backup part only needs a cron job whose output nobody reads.
