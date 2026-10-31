# post_mortem: real-world database incidents

Public incident reports (post-mortems, retex, incident write-ups) about database and data-platform failures, each summarised in a fixed format.

**What this folder is.** Source material for future games and for end-of-game handouts: true failures whose main culprits a later version may replicate, so that a GM can close a game by telling the players "this really happened, here is how". **The entries are not bound to the game's faults.** Nothing here is a fault definition, and no entry is mapped to a brick, fault or scenario. That mapping is later work.

- **Date collected**: 2026-10-31
- **Entries**: 27
- **Rules followed**: every entry links the primary write-up (collections such as danluu/post-mortems were used only to find reports). Summaries are in our own words; short quotes are in quotation marks. Every factual claim comes from the cited source; a field the source does not give says "not stated". Each entry ends with a **Notes** section marked as the collector's own: lab-replication remarks, not facts from the source.

## Index

| File | Date | Organization | Engines | Main culprit | Source |
|---|---|---|---|---|---|
| [2012-github-mysql-pacemaker-failover.md](2012-github-mysql-pacemaker-failover.md) | 2012-09-10/11 | GitHub | MySQL, Pacemaker | migration load trips auto-failover; cluster split-brain | [github.blog](https://github.blog/2012-09-14-github-availability-this-week/) |
| [2015-gocardless-fk-migration-lock-queue.md](2015-gocardless-fk-migration-lock-queue.md) | 2015-01 (inferred) | GoCardless | PostgreSQL | FK migration's exclusive lock queued behind a slow SELECT | [gocardless.com](https://gocardless.com/blog/zero-downtime-postgres-migrations-the-hard-parts/) |
| [2015-joyent-manta-autovacuum-lock-queue.md](2015-joyent-manta-autovacuum-lock-queue.md) | 2015-07-27 | Joyent | PostgreSQL (Manatee) | anti-wraparound autovacuum + DROP TRIGGER lock queue | [archive only](https://web.archive.org/web/20220528044329/https://www.joyent.com/blog/manta-postmortem-7-27-2015) (original 404) |
| [2015-sentry-xid-wraparound.md](2015-sentry-xid-wraparound.md) | 2015-07-20 | Sentry | PostgreSQL | XID wraparound, autovacuum under-tuned | [blog.sentry.io](https://blog.sentry.io/transaction-id-wraparound-in-postgres/) |
| [2017-gitlab-database-outage.md](2017-gitlab-database-outage.md) | 2017-01-31 | GitLab | PostgreSQL 9.6 | replication lost, primary wiped by mistake, all backups broken | [about.gitlab.com](https://about.gitlab.com/blog/2017/02/10/postmortem-of-database-outage-of-january-31/) |
| [2017-gocardless-pacemaker-failover.md](2017-gocardless-pacemaker-failover.md) | 2017-10-10 | GoCardless | PostgreSQL, Pacemaker | HA constraints block promotion of the sync replica | [gocardless.com](https://gocardless.com/blog/incident-review-api-and-dashboard-outage-on-10th-october/) |
| [2018-basecamp-int-id-exhaustion.md](2018-basecamp-int-id-exhaustion.md) | 2018-11-09 | Basecamp | not stated (Rails) | 32-bit integer ID exhausted on the events table | [signalvnoise.com](https://signalvnoise.com/svn3/postmortem-on-the-read-only-outage-of-basecamp-on-november-9th-2018/) |
| [2018-github-mysql-cross-region-failover.md](2018-github-mysql-cross-region-failover.md) | 2018-10-21 | GitHub | MySQL, Orchestrator | 43 s partition, cross-region promotion, diverged writes | [github.blog](https://github.blog/2018-10-30-oct21-post-incident-analysis/) |
| [2018-singhealth-patient-database-exfiltration.md](2018-singhealth-patient-database-exfiltration.md) | 2018-06-27 to 07-04 | SingHealth / IHiS | SCM clinical database (engine not stated) | open path from Citrix hosts to DB, no query monitoring | [COI report PDF](https://go.gov.sg/singhealthcoi) |
| [2019-facebook-plaintext-passwords-internal-storage.md](2019-facebook-plaintext-passwords-internal-storage.md) | found 2019-01 | Facebook / Instagram | not stated | passwords unmasked in internal storage and logs | [about.fb.com](https://about.fb.com/news/2019/03/keeping-passwords-secure/) |
| [2019-mailchimp-mandrill-xid-wraparound.md](2019-mailchimp-mandrill-xid-wraparound.md) | 2019-02-04 | Mailchimp (Mandrill) | PostgreSQL (sharded) | XID wraparound on one hot shard | [mailchimp.com](https://mailchimp.com/what-we-learned-from-the-recent-mandrill-outage/) |
| [2019-pretix-overlapping-cronjobs.md](2019-pretix-overlapping-cronjobs.md) | 2019-11-24 | pretix | not stated (Django, cron) | periodic job overlapping itself after a slowdown | [behind.pretix.eu](https://behind.pretix.eu/2019/11/24/cronjobs) |
| [2019-stripe-shard-election-failure.md](2019-stripe-shard-election-failure.md) | 2019-07-10 | Stripe | not named (sharded, elections) | stalled-but-healthy nodes + upgrade election bug | [stripe.com](https://stripe.com/rcas/2019-07-10) |
| [2020-cloudflare-etcd-partial-switch-failover.md](2020-cloudflare-etcd-partial-switch-failover.md) | 2020-11-02 | Cloudflare | relational DBs (not named), etcd | partial switch failure, auto-promotion, replica rebuilds | [blog.cloudflare.com](https://blog.cloudflare.com/a-byzantine-failure-in-the-real-world/) |
| [2020-figma-statistics-plan-flip.md](2020-figma-statistics-plan-flip.md) | 2020-01-21/22 | Figma | PostgreSQL 9.x on RDS | statistics update flips an ORM query's plan | [figma.com](https://www.figma.com/blog/post-mortem-service-disruption-on-january-21-22-2020/) |
| [2020-phe-lab-results-load-truncation.md](2020-phe-lab-results-load-truncation.md) | 2020-09-25 to 10-02 | Public Health England | not stated (XLS per press) | lab-result load silently truncated at a size limit | [gov.uk](https://www.gov.uk/government/news/phe-statement-on-delayed-reporting-of-covid-19-cases) |
| [2021-gitlab-subtransactions-replica-stall.md](2021-gitlab-subtransactions-replica-stall.md) | 2021-06-24 onward | GitLab | PostgreSQL | SAVEPOINTs + long transaction stall replicas (SubtransSLRU) | [about.gitlab.com](https://about.gitlab.com/blog/2021/09/29/why-we-spent-the-last-month-eliminating-postgresql-subtransactions/) |
| [2022-atlassian-site-deletion-restore.md](2022-atlassian-site-deletion-restore.md) | 2022-04-05 | Atlassian | not named (multi-tenant stores, AWS) | deletion script fed wrong IDs; per-tenant restore impossible at scale | [atlassian.com](https://www.atlassian.com/engineering/post-incident-review-april-2022-outage) |
| [2022-revenuecat-aurora-upgrade-missing-analyze.md](2022-revenuecat-aurora-upgrade-missing-analyze.md) | 2022-11-23 | RevenueCat | Aurora PostgreSQL 10 to 14, PgBouncer | cutover before ANALYZE; sequences not replicated | [revenuecat.com](https://www.revenuecat.com/blog/engineering/postmortem-aurora-postgres-migration) |
| [2022-slack-cache-miss-scatter-queries.md](2022-slack-cache-miss-scatter-queries.md) | 2022-02-22 | Slack | MySQL/Vitess, memcached | cache flush exposes expensive scatter query | [slack.engineering](https://slack.engineering/slacks-incident-on-2-22-22/) |
| [2023-mailpace-silent-cleanup-cron-disk-full.md](2023-mailpace-silent-cleanup-cron-disk-full.md) | 2023-08-11 | MailPace | managed PostgreSQL | silently failing retention cron, then disk full | [mailpace.com](https://mailpace.com/blog/musings/postgres-outage-post-mortem) |
| [2023-microsoft-azure-devops-snapshot-job-deletes-server.md](2023-microsoft-azure-devops-snapshot-job-deletes-server.md) | 2023-05-24 | Microsoft (Azure DevOps) | Azure SQL Database | clean-up job deletes the SQL server, not the snapshot | [status.dev.azure.com](https://status.dev.azure.com/_event/392143683) |
| [2025-clerk-synchronized-connection-recycling.md](2025-clerk-synchronized-connection-recycling.md) | 2025-09-14 to 18 | Clerk | managed PostgreSQL | provider minor upgrade + fixed pool lifetime = reconnect storms | [clerk.com](https://clerk.com/blog/2025-09-18-database-incident-postmortem) |
| [2025-cloudflare-clickhouse-permission-change.md](2025-cloudflare-clickhouse-permission-change.md) | 2025-11-18 | Cloudflare | ClickHouse | grants change doubles a metadata query's output | [blog.cloudflare.com](https://blog.cloudflare.com/18-november-2025-outage/) |
| [2025-neon-scheduled-job-plan-change.md](2025-neon-scheduled-job-plan-change.md) | 2025-05-16 | Neon | PostgreSQL (control plane) | scheduled job's query flips plan on a bloated table | [neon.com](https://neon.com/blog/delayed-start-compute-operations-triggering-event) |
| [2025-shepherd-vet-request-surge-outage.md](2025-shepherd-vet-request-surge-outage.md) | 2025-09-17 | Shepherd Veterinary Solutions | not stated | spike of heavy queries on the shared main database | [status.shepherd.vet](https://status.shepherd.vet/incidents/lh2fw90b2h43) |
| [2026-clerk-autoanalyze-plan-flip.md](2026-clerk-autoanalyze-plan-flip.md) | 2026-02-19 | Clerk | PostgreSQL | autoanalyze null_frac misestimate flips a plan | [clerk.com](https://clerk.com/blog/2026-02-19-system-outage-postmortem) |

## Coverage by category

- **PostgreSQL** (13): GitLab 2017 and 2021, Sentry, Mandrill, Joyent, GoCardless (two), Figma, Clerk (two), Neon, RevenueCat, MailPace; plus Basecamp (engine not stated, Rails integer IDs) as a direct carry-over.
- **Other relational and data platforms, culprit carries over** (8): GitHub 2012 and 2018 (MySQL), Stripe (engine not named), Cloudflare 2020 (engine not named) and 2025 (ClickHouse), Slack (Vitess/MySQL), Atlassian, Azure DevOps (Azure SQL).
- **Pipelines, ETL, scheduling, governance** (several overlap with the above): pretix and MailPace (cron), Neon and Azure DevOps (scheduled jobs), PHE (lab-results load), Cloudflare 2025 (grants change), SingHealth (database access and monitoring), Facebook (secrets in internal storage/logs).
- **Healthcare, laboratory, veterinary** (3, thin): SingHealth (hospital clinical database, detailed public inquiry), PHE (laboratory results reporting, official statement plus press), Shepherd (veterinary practice-management software, short status-page postmortem).

## Link verification (2026-10-31)

Every primary link above was fetched on 2026-10-31 and returned HTTP 200, with these exceptions and caveats:

- **Joyent Manta (flagged)**: the original <https://www.joyent.com/blog/manta-postmortem-7-27-2015> returns **404**; the entry was written from the web.archive.org snapshot, which is linked instead.
- **Azure DevOps**: the status page renders with JavaScript; the post-mortem text is in the page source (it was read from there). The only archive snapshots predate the post-mortem text.
- **Shepherd**: no web.archive.org snapshot exists.
- **SingHealth**: `go.gov.sg/singhealthcoi` redirects to a 454-page PDF on file.go.gov.sg; read from the PDF.
- **Secondary links**: the BBC article in the PHE entry and the EDB commentary in the RevenueCat entry returned 200 with curl (the BBC page could not be read with the web-fetch tool but its text was checked by curl).
- Archive links are the "closest snapshot" returned by the Wayback Machine availability API on the same day.
- Not used, because the primary could not be fetched or no primary write-up exists: Microsoft MSRC's 2019 customer-support database exposure post (moved, 404 at the new address), Twitter's 2018 "passwords in an internal log" post (403), Salesforce's 2019 Pardot permissions incident (status-page wording and press only), Toyota's 2023 cloud misconfiguration notice (press only).

## Entry template

File name: `post_mortem/<yyyy>-<org-slug>-<short-slug>.md`, where `yyyy` is the year of the incident (not of the write-up).

```markdown
# <Title: what happened, in one line>

- **Source**: [<title of the write-up>](<primary URL>) (<publisher, publication date>). Archive: [web.archive.org snapshot](<snapshot URL>) or "no snapshot found". Secondary: <optional links>
- **Date of incident**: <yyyy-mm-dd, with times if given>
- **Organization**: <who>
- **Kind of write-up**: <official post-mortem | engineering blog | conference talk | news | official statement>

## Tech stack
<engines and versions where stated, poolers, replication, orchestration, cloud/managed service>

## Topology
<primaries/replicas, regions, how apps connect; "not stated" rather than a guess>

## Symptoms
<what users and operators saw first>

## Diagnosis
<how they found the cause: tools, signals>

## Root cause / main culprits
<technical causes and contributing factors>

## Resolution
<immediate fix, then follow-up actions>

## Impact and duration
<if stated>

## Notes (collector's own, not from the source)
<what matters for replicating it in a small lab>
```

## How to add an entry

1. Find a report (collections such as danluu/post-mortems, status pages, engineering blogs), then follow it to the **primary** write-up. Do not cite a collection or an aggregator as the source.
2. Fetch the primary link and check it resolves. Look up a web.archive.org snapshot (`https://archive.org/wayback/available?url=<url>`) and link it if one exists; say so if none does. If the original is dead but archived, link the archive and flag it here.
3. Copy the template, fill every section from the source only. Write "not stated" for anything the source does not give. Paraphrase; keep quotes short and in quotation marks.
4. Put your own remarks (lab replication, signals a player would read) only under **Notes**, marked as the collector's.
5. Add a row to the index table above, keep it sorted by file name, update the entry count and the category list, and record any link problem under "Link verification".
6. Do not map the entry to a game fault or write a fault definition here; that belongs to the fault catalogue in a later version.
