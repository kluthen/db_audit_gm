# v0.5 — the clinic's traps (step 8): the whole clinic

Status: draft v4, ready for review; what v0.5 builds ruled (D316), the
test selection's swaps T270 and T150 (D325), then T307 for T49 (D332).
The index of the whole
clinic's traps: 229 in all, the core's and the lab's 85 here (sections
1 to 9), the four parts' 135 on their own pages (section 10: scheduling
29, housing 22, machinery 38, the portal 46), folded in on 2026-11-03
(D317–D320), and the data register's 9 (section 11, T300–T308, D330),
planted in the players' handout only. Step 8 of the
[procedure](domain-procedure.md#2-the-steps-from-a-brief-to-a-finished-domain)
for the clinic's first two domains together, across their data models
([vet-core](vet-core-domain.md#the-data-model-step-4),
[vet-lab](vet-lab-domain.md#the-data-model-step-4)), their producer
profiles (step 6) and their ten purposes
([clinic-purposes.md](clinic-purposes.md)), with replication, the
office database ([replication.md](replication.md)) and the partners
([one-centre.md](one-centre.md) 4). No owner checkpoint: a scenario's
faults are the GM's to select at deploy, with whoever sets up the game,
within D290's cap and mix (D309). This page lists where a fault can
bite and stops there; the spec's own pick, a fixture for the build's
tests, is the [test selection](clinic-test-selection.md).

A trap is not a fault definition (procedure 1): the domain's GM notes
list the traps, the catalogue or a scenario holds the faults. v0.5
builds the [test selection](clinic-test-selection.md)'s ten as fault
definitions, with its false alarm's material; every other trap stays
here and in the GM notes, for a GM to write as a scenario's own fault
when a game selects it (D316).

## How to read the tables

- **Where it bites**: the node, table, purpose or invariant it breaks.
- **Witness**: what shows it, and when; "at once" means within minutes
  of the fault being planted at the clinic's rates; a rate-bound witness
  says how often it recurs.
- **Fixed on**: the layer the players change (D271: an `api` node's
  `db/` side only; third parties never, D273).
- **Catalogue**: the existing fault it is, an existing one adapted
  (a new fault in the build, its precondition or material changed), or
  new. The two held candidates are `purpose-retry-without-key` (D201)
  and `governance-statement-log-personal` (D191), named but not built.
- **Class** (D290): **D** dramatic, noticed by the customer before the
  audit; **V** on the verge of becoming a problem at the hand-over;
  **M** an optimisation or a minor friction. Two letters: the
  calibration (its rate, its planting time, the aging) decides.

Two rules bind every trap below. **Rare flows** (notifiable diseases,
exchanges, critical calls) are planted only with a story that raises
their rate from T0 in the profile layer (D306, point 6). **A cascade**
(a round trip's fault whose backlog spreads) is judged end to end on the
trace after the fix; a symptom fixed alone earns nothing (D286).

## 1. Bricks and configuration

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T1 | Statement logging on (`log_statement = all`) on `records` | owners' names, phones and addresses in the server log, against core rule 10 ("none in the logs") | the log file, at once, every `pms` write | `postgresql.conf` | held: `governance-statement-log-personal` (D191) | M, V when the log ships off site |
| T2 | pgaudit logging parameters (`pgaudit.log_parameter = on`) on `lab` | chips and clients' surnames in the audit log, against lab rule 11 | the audit log, at once, every accession | `postgresql.conf` | adapts the held one | M |
| T3 | The standby's replication connection without TLS (`host` where `hostssl` is meant, `sslmode=disable`) | the whole record streamed in clear between sites | `pg_stat_ssl` for the walsender, at once | `pg_hba.conf`, `primary_conninfo` | new (TLS always available, D250) | M |
| T4 | `trust` for a remote address on `lab` | anyone on the network as `lab_app` | `pg_hba.conf` read; a login with no password | `pg_hba.conf` | `pg-hba-trust-remote` | M |
| T5 | An application role superuser (`lab_app`, `vet_app`) | every grant of steps 4 and 7 bypassed | `\du`, at once | the roles | `pg-role-superuser` | M |
| T6 | `pg_stat_statements` not preloaded on `lab` | the lab's slow statements unexplainable | the extension's error, at once | `postgresql.conf`, a restart | `pg-stat-statements-not-preloaded` | M |
| T7 | Autovacuum off on `lab_order_tests` or `requests`, the two tables updated at every state | dead rows piling at each state change, the worklist and the feed slowing | `pg_stat_user_tables`, dead tuples rising every bench hour | the table's storage parameter | `pg-table-autovacuum-off` | V |
| T8 | Memory set over the node's envelope on the standby | the standby killed while the reports read it at night | the settings against the limit, at once; the kill only under the reports' load | `postgresql.conf` | `pg-memory-over-envelope` | M |
| T9 | The pooler's pool too small for `pms` at the 17:00–19:00 peak, when the scenario places a pooler | the practice software waiting on connections at the peak | client waits on `SHOW POOLS`, each weekday peak | `pgbouncer.ini` | `pgbouncer-pool-too-small` | M, V at a busy story |
| T10 | `monitoring` not chosen on a node (D289): `options: [monitoring]` left off `lab` | its exporter failing to log in, the lab dark on the dashboards | the exporter's errors, at once | the topology's options (the scenario) | new | M |
| T11 | A scrape target or a node-health entry missing (the lab's exporter, the standby) | an instance unwatched | Prometheus' targets, at once | `prometheus.yml` | `prometheus-scrape-target-missing`, `prometheus-node-health-node-missing`, `prometheus-node-health-service-missing` | M |
| T12 | An alert's `for` too long on replication lag or the archive's failures | the problem known only hours late | the rule's `for`, at once | the alert rule | `grafana-alert-for-too-long` | M |

## 2. Data and identity

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T13 | The dozen mistyped chips (D278), planted by the domain at load | the lab's live orders, copied from the core by `lab.identity`, matching no animal by chip; later the portal | `lab_orders.microchip` against the core's function of the animal's id; every order for those twelve animals | the record, by the vets (a finding the players report or propose; part of the domain, a fault only when a story leans on it) | new, the domain's own | M, or false-alarm material |
| T14 | A sequence left below its loaded range (`setval` missing on one table at load) | the first live insert after T0 failing on a duplicate key: no new consultation, or no new lab order | the producer's errors, at once | the sequence | new (the `scheduler-query-error` family) | D |
| T15 | Two current owners for one animal: the partial unique index on `ownerships` dropped, a transfer that opens before it ends | the lookup API answering either owner; the lab printing the former owner's surname | duplicate current ownerships, at each `ownerships.transfer` (about 3 a day) | the index, then the data | new | M, V over days |
| T16 | Closed consultations unsigned for more than a day (core rule 8), the signing stream's capacity cut by a key | the record legally incomplete; the referrals never closing | closed, unsigned rows older than a day, growing by the day's surplus | the practice software (the players report it) | new (rides the schedule, D276) | V |
| T17 | A cascade line for a food-producing animal without its withdrawal end (rules 1, 6) | milk or meat from a treated animal entering the food chain; the residue screening ordered with no date | lines with `cascade` and no `withdrawal_ends_on`, every such prescription (a few a day) | the practice software, then the data | new | V |
| T18 | `prescriptions.expire` taking each line's days for antimicrobials too | antimicrobial prescriptions valid beyond five days (rule 1) | prescriptions past five days still `issued` after 00:15 | the job's statement (`pms`'s `jobs.yaml`, or `pg_cron` where the GM placed it) | new | M |
| T19 | The lookup API's owner taken without `until_at` (former owners answered) | a lab order or, later, the portal showing a former owner (core rule 11) | `GET /animals/{id}/owner` against `ownerships`, for each animal sold (about 3 a day) | `clinic-api`'s `db/` (D271) | new | M |
| T20 | A reference interval for the wrong species, or two in force after the January review (`valid_until` left open) | results flagged against the wrong limits: criticals missed or false | `lab_results` flags against the interval in force, at every batch for that species | the reference data | new | V |
| T21 | Results released from a batch whose QC run failed (lab rule 4) | results the lab should have held, released to the vets and the practices | released results whose batch's QC run is `fail`, after the next failed morning run (one in fifty) | the information system (reported; its key rides the schedule) | new | V |
| T22 | An amendment written as an update of the released row (lab rule 3) | the first result lost; a practice holding a value the lab no longer has | `lab_results` rows with `amended_at` and no superseded row; about 4 a day | the information system's key, a trigger | new | M |
| T23 | A test mapped to the wrong external code (vet-lab answer 6) | the external lab returning another test's result | `lab_tests.external_code` against the external lab's catalogue in `partners.md`; at the 16:00 send-out | the catalogue | new | M |

## 3. Governance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T24 | Free text naming the owner (findings, an alert, a referral's reason, the lab's clinical notes) copied by a purpose | the notifications' or the exchanges' payload carrying a person's name to a third party | the payloads against the policy, on each post | the runner's script (what it copies) | adapts `governance-personal-copied` | M |
| T25 | `animal_board` carrying a natural identifier (the chip) | the ward displays showing what core rule 10 keeps from them | the view's definition, at once | the view | new | M |
| T26 | `vet_lookup` granted all of `owners` (the column grant replaced) | the lab and later the portal able to read addresses and phones | the grants, at once | the grants | new | M |
| T27 | `office_jobs` holding write grants on `clinic`, or `vet_reports` on `office` (D300, D306) | the separation the office exists for | the grants, at once | the grants | new | M |
| T28 | `vet_interfaces` granted `UPDATE` on all of `requests` | a runner able to rewrite the record | the grants, at once | the grants | new | M |
| T29 | Samples never disposed (`lab.samples.dispose` missing or failing) | samples kept beyond lab rule 12's week or two | stored samples past their keep-until, growing by about 60 a day | `lis`'s `jobs.yaml` or `pg_cron` | new | M |
| T30 | The lab writing into `clinic` (a connection the design refused, D306 point 3) | the lab's processor role reaching the centre's record | the roles and the connections, at once | the grants, the runner | new | M |

The purposes' governance traps (T45, T49, T56, T67) are with their
purposes below.

## 4. Replication and the archive

From [replication.md](replication.md) 4, ruled as candidates (D299,
D301). For these two domains cold storage is the archive's vault: no
table of theirs ships (D297), so cold storage's heavy-data traps
([cold-storage.md](cold-storage.md) 4) are `vet-machinery`'s, with its
tables ([vet-machinery](vet-machinery-domain.md#4-partitions-the-time-series-and-cold-storage),
section 10 below), and the vault's traps here read the `wal` and
`basebackup` manifests.

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T31 | `synchronous_standby_names` naming an absent standby (a wrong `application_name`) | every commit on `records` waiting: the practice software stalled | writes hanging, at once | `postgresql.conf` | new | D |
| T32 | An abandoned slot beside the standby's | `pg_wal` growing without bound | the slot's retained WAL, 16 MB an hour or more | the slot | `pg-abandoned-replication-slot`, its precondition bumped (D299) | V |
| T33 | Replication lag: the standby hours behind (a replay delay, a paused replay) | the night's reports reading stale data | `pg_stat_replication`'s lag, at once and growing | the standby's settings | new | V, M |
| T34 | Query conflicts on the reporting standby (`hot_standby_feedback` off) | a feeder cancelled at night: a day missing from a register | the feeder's error and `pg_stat_database_conflicts`, at the feeder's run | the standby's settings | new | V |
| T35 | `archive_command` failing silently (exiting 0) | segments recycled unsent: gaps in the vault, no point-in-time copy | missing segment names in the `wal` manifests, at the next segment switch | the command | new | V |
| T36 | `pg_wal` filling when the archive fails honestly | the disk heading for full; at one centre's rates, days away | `pg_wal`'s size, 16 MB an hour or more | the command, the vault's address | new | V |
| T37 | Base backups older than the policy (the nightly backup broken) | no recent base for a restore | the last `basebackup` manifest's date; at once, from the planted manifests | the backup job | new | M, V |
| T38 | The lab's node left out of the archive (D301) | the lab's record with no copy anywhere | no manifest naming the lab, at once | the lab's `archive_command` and backup job | new | V |

## 5. Round trips

From [clinic-purposes.md](clinic-purposes.md) 5 to 8. Each is a cascade
(D286) where its backlog spreads.

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T39 | Requests marked `sent` before the call returns, in a transaction committed first | requests `sent` with no lab order: results that never come, vets phoning the lab (LO1) | `requests` `sent` with no `ops.lab_orders_sent` accession, at the first timed-out post | `interfaces`' script | new | D |
| T40 | The priority dropped in the mapping | urgent tests posted routine, waiting for the pathologist's round: the emergency team's blood gases hours late (LO4) | lab orders `routine` for `urgent` requests, at the first urgent order (about 20 a day) | `interfaces`' script | new | D |
| T41 | A retry under a new `client_ref` | two lab orders for one consultation, a tube expected that never comes (LO2) | duplicate request ids on lab order tests, at each slow answer | `interfaces`' script | held: `purpose-retry-without-key` (D201) | V, M with the partner's standing slowness only |
| T42 | The results' watermark taken from the run's start, or the latest `released_at` read, while a release commits later | a few requests stuck `sent` though released, more each busy round (LO3) | released tests whose request is not `resulted`, at each release round | `interfaces`' script | adapts `purpose-watermark-misses-updates` | V |
| T43 | A technically validated test read as final | requests `resulted` before release (lab rule 1, core rule 11) | `resulted` requests whose test is `technical`, at each urgent result | `interfaces`' script | new | M, V |
| T44 | `post-lab-orders` at `*/15`, or on business hours only | the night's emergencies posted in the morning (LO1) | the post's delay against the close, every night | `interfaces`' `jobs.yaml` | new | M, V |
| T45 | A practice's callback joined on the wrong key (account against practice id) | one practice receiving another's clients' results: a breach a practice reported (PR4) | deliveries to an account other than the order's, at once | `interfaces`' script | new | D |
| T46 | Deliveries made one after another with a long timeout | one practice's dead callback (a partner outage) holding every delivery: all practices late (PR1) | `lab_callbacks` stalled behind one account, from the outage | `interfaces`' script | new | D, V |
| T47 | A new `delivery_key` on each attempt | duplicates at the practices after each slow answer (PR2) | keys per order and kind, at the stub's 503s (one in fifty) | `interfaces`' script | adapts `purpose-retry-without-key` | M |
| T48 | Amendments never delivered (the query takes `final` only), or no incident after the sixth attempt | practices holding superseded results, or results never delivered, nobody told (PR1, PR5) | amendments with no delivery, about 4 a day; failed deliveries with no incident | `interfaces`' script | new | M |
| T49 | A natural identifier or the client's surname in a send-out (lab rule 11) | personal data sent to a third party (SO3) | the stub's received payloads, at the 16:00 send-out | `interfaces`' script | adapts `governance-personal-copied` | M, V |
| T50 | A new `send_key` on each retry | the external lab running a test twice (SO2) | send-outs with two external accessions, at a chase | `interfaces`' script | adapts `purpose-retry-without-key` | M |
| T51 | `lab-api`'s answer endpoint matching on the external accession, which a resend changes | answers recorded nowhere: results that never come back (SO4) | the stub's posted answers with no recorded result, at each answer after a resend | `lab-api`'s `db/` | new | V |
| T52 | `send-outs` scheduled in UTC, after the courier left at a positive shift | send-outs a day late, every day (SO1) | sent-out tests packed the next day | `interfaces`' `jobs.yaml` | adapts `purpose-day-boundary-wrong-zone` | M |
| T53 | No chase: a lost callback (the partner's, D268) never asked for again | send-outs stuck past their due date, the vets chasing by phone (SO4) | send-outs past `due_by` with no `resend`, from the first lost callback | the chase job | new | V |
| T54 | `clinic-api`'s exchange endpoint answering 201 from a transaction it never commits | the other centre told "received", the centre holding nothing (EX3, EX5) | the stub's acknowledged requests absent from `exchanges`; rare, a story raising the rate | `clinic-api`'s `db/` | new | V |
| T55 | Exchanges' answers posted to the wrong centre (sites 2–3 against 4–6), or a new key on a resend | a centre abroad getting another's answer; the asker chasing (EX3) | answers per site against the requests; rare | `interfaces`' script | new | M |
| T56 | An exchange carrying the owner's other animals' records (EX4) | more than the franchise's agreement allows | the payloads, each post; rare | `interfaces`' script | adapts `governance-personal-copied` | M |
| T85 | `fetch-lab-results` taking released and unperformed tests only, never the lab's cancellations (D315) | requests the vet had the lab cancel staying `sent`, then escalated as overdue (LO3) | cancelled centre tests whose request is still `sent`, about one a day | `interfaces`' script | new | M |

## 6. Pushed obligations: notifications and critical calls

From [clinic-purposes.md](clinic-purposes.md) 9 and 10; rare flows.

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T57 | Category A treated as another listed disease | a suspected category A disease notified a day late | notifications past an hour for category A codes, with the story's outbreak | `interfaces`' script | new | V |
| T58 | `notify-vet` taking confirmed diagnoses only, or `notify-lab` the centre's account only | suspicions, or the region's practices' positives, never notified | notifiable rows with no notification, with the story's outbreak | `interfaces`' script | new | V |
| T59 | The authority's stub down (a timeline outage) and nothing escalating | notifications unacknowledged for hours, no incident | unacknowledged notifications and no `ops.incidents` row | the escalation job | adapts `purpose-receiver-down-unnoticed` | V |
| T60 | The critical calls' watch scheduled by the superuser (`cron.job.username` `postgres`) | a job running as superuser that no runner lists | `cron.job`, at once | `cron.job` | adapts `security-crontab-superuser` to `pg_cron` | M |
| T61 | The watch filtering `flag = 'critical'` while the flags are `critical-low` and `critical-high` | it never escalates a missed call | no incident for a critical left uncalled, two or three a day | the job's statement | new | V |
| T62 | `cron.log_run` off | no run to judge, the watch unseen | `cron.job_run_details` empty, at once | the setting | new | M |
| T63 | The call stream's key calling the centre's vets only (rides the schedule) | the practices' critical values never phoned; the watch's incidents piling | critical results of practice orders with no call | the information system (reported) | new | V |

## 7. Periodic reports

From [clinic-purposes.md](clinic-purposes.md) 11 to 14. Past periods are
planted; at least one planted periodic-data fault shows a witness within
the aging, through a daily feeder carrying it forward (D265); a fix is
checked on the feeder's next run or by the sealed check reading the code
(D277). The feeders run at night (00:30 to 02:30); under D314 a test
reads them on a fixture whose T0 sits just before, or with the feeder
moved (D132).

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T64 | The medicines feeder joining administrations through prescription lines twice | supplies counted twice in the register (MR1) | the feeder's day against the source, each night | the feeder's query | new | M |
| T65 | Administrations in hospital left out (dispensings only) | the register short of most of its lines (MR1) | about 240 lines missing a day | the feeder's query | new | V |
| T66 | A feeder's day in UTC | supplies around midnight in the wrong day, or missing | the day's lines against the source at a non-zero shift | the feeder's query | adapts `purpose-day-boundary-wrong-zone` | M |
| T67 | The owner's e-mail and phone copied into `office` (MR2) | personal data beyond the register's rule | the register's columns, each night | the feeder's query | adapts `governance-personal-copied` | M |
| T68 | A controlled medicine (ketamine) not flagged, planted in the history and carried forward | its movements absent from the controlled register for the year and every day since | the controlled feeder's day against the anaesthetics given, each night | `medicines.controlled`, then the feeder's next run | new | V |
| T69 | Herd prescriptions dropped by a join on `animals` | the cattle, the one species due, under-reported every day and in last year's report | the antimicrobial feeder's day against herd treatments | the feeder's query (the report rerun recommended, D277) | new | V |
| T70 | Prescriptions counted instead of administrations and dispensings | antimicrobial use over-reported | the feeder's day against the source | the feeder's query | new | M |
| T71 | The species filtered on a label the core does not use (`bovine` against `cattle`) | an empty yearly report | the report's code (the sealed check, AM3) | the report's code | new | M |
| T72 | The stays counted when the feeder runs, not at midnight; the turnaround's median taking cancelled tests | the head office's figures off | the daily rows against the source | the feeder's query | new | M |
| T73 | The runner's role on the standby expired | every report's night run refused, the daily rows missing since | `backoffice`'s log, at the next feeder | the role | adapts `purpose-etl-role-expired` | V, D when the head office has noticed |
| T74 | The feeders reading the primary, not the standby; the antimicrobial feeder at the base backup's hour | the night's heavy reads competing with traffic and the backup | the connections at the feeder's run | the runner's connection, `jobs.yaml` | adapts `scheduler-batch-at-peak` | M |
| T75 | The statements' feeder run at bench hours on the lab's only node (D304) | a report competing with the bench at its busiest | the feeder's run against the bench's latency | `jobs.yaml` | adapts `scheduler-batch-at-peak` | M, V |
| T76 | A charge at today's price instead of the order's day (vet-lab answer 13), carried forward | statements over the price list in force when ordered | charges against `lab_prices` on the order's day, every outside order since 1 January | the information system's charge (reported), then the feeder's next run | new | M |
| T77 | Voids taken only for charges made the same day; the discount applied per line | a voided charge still stated; statements off by rounding | the feeder's day against the charges; the statement's code (ST3) | the feeder's query, the statement's code | new | M |

## 8. Performance and the `api` nodes' `db/` sides

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T78 | `lab-api`'s idempotency lookup on `client_ref` alone, unindexed | every post slower as `lab_orders` grows; the runner's call latency climbing | the runner's latency per call and `pg_stat_statements`, at once and rising | `lab-api`'s `db/` | new | M, V as `lab_orders` grows |
| T79 | The lookup API's `GET /animals?microchip=` unindexed | `lab.identity`'s calls every minute slower; `clinic-api` busy | `pg_stat_statements` on `records`, at once | an index on `records` | adapts `pg-join-index-missing` | M |
| T80 | The results feed's `released_since` with no index on the release time | the five-minute poll scanning every order test | `pg_stat_statements` on `lab`, at once | `lab-api`'s `db/`, an index | adapts `pg-join-index-missing` | M |
| T81 | `animals.file` joining `ownerships` with no index on the animal | the practice software's record screen slow at the 17:00 peak | the read's latency, each weekday peak | an index | `pg-join-index-missing` | M |
| T82 | An `interfaces` job holding its `clinic` transaction open across the HTTP call | locks on `requests` while `lab-api` is slow; vacuum held back | `pg_stat_activity` idle in transaction, at each slow answer | `interfaces`' script | adapts `scheduler-transaction-held-open` | V |
| T83 | `requests.pending` or `lab.worklist` unbounded | a screen reading every row as the year grows | the statement's rows, at once | the read (reported; the producer's) | adapts `scheduler-report-unbounded` | M |
| T84 | A heavy statement on a database node's `pg_cron` at bench hours (the statements' feeder moved there) | the lab's node loaded at its busiest | `cron.job` and the node's CPU | `cron.job`, `jobs.yaml` | `purpose-heavy-job-on-database-node` | M |

## 9. False-alarm material

Complaints with no fault behind them, each answerable from the trace
(D290):

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "The external lab is slow" | a PCR answered on its fourth day, within its turnaround (one to five days) | `lab_send_outs`' `due_by` against `answered_at` |
| "Cultures stay pending for days" | two to three days, sensitivities two or three more (vet-lab answer 7) | the catalogue's turnaround |
| "An urgent result showed unvalidated" | inside the centre, by design (lab rule 1) | the release state and the rule |
| "`pg_wal` holds hundreds of megabytes" | `archive_timeout` at an hour forces 24 segments a day, mostly empty (D299) | the manifests, complete |
| "The standby falls behind every night" | a few minutes at the base backup's hour, caught up after | the lag over the night |
| "The lab charged more in January" | the price list's yearly revision on 1 January | `lab_prices` |
| "Critical values are phoned late at night" | called within the hour by the on-call technician | `lab_critical_calls` against the results |
| "A dozen results match no animal" | when the story names no fault: the mistyped chips are the core's data (T13), a finding to report | the chips against the core's function |

## 10. The four parts' traps

Each part's traps are on its page, in the tables and columns of this
one ("How to read the tables"), with its false-alarm material; the
rare-flow and cascade rules bind them too (D306 point 6, D286). Not
copied here: the part's page is their one home.

| Part | Traps | False alarms | Notes |
|---|---|---|---|
| [`vet-scheduling`](vet-scheduling-domain.md#traps-step-8) | T100–T128 (29) | 5 | T122 dormant: `sched_upcoming` is not built, no appointment reminders in v0.5 (D321) |
| [`vet-housing`](vet-housing-domain.md#traps-step-8) | T150–T171 (22) | 4 | T150, the faulty display (D287's own case), is s9 of the test selection, judged on the report (D325) |
| [`vet-machinery`](vet-machinery-domain.md#traps-step-8) | T200–T237 (38) | 6 | cold storage's heavy-data traps among them (its section 4); T208, no partition created ahead, a trap for the GM, not in the selection (D325) |
| [`vet-portal`](vet-portal-domain.md#traps-step-8) | T250–T295 (46) | 6 | T270, the animals' policy without the ownership's end, is s5 of the test selection (D325) |

**The core's and the lab's traps that bite the parts too**, as the
parts' pages name them:

- **`vet-scheduling`**: T5 (an application role superuser:
  `sched_app`), T7 (autovacuum off: on `sched_allocations` or
  `sched_bookings`), T9 (the pooler's pool at the 17:00 peak, with the
  booking stream's searches), T14 (a sequence below its range: on
  `sched_bookings`), T24 (free text copied: a booking's notes), T31 to
  T37 (the archive and the standby, the part riding the core's
  instance), T73 and T74 (the report runner's role and connection, for
  `vet-working-time`), T82 (an `interfaces` job holding its transaction
  across a call: `book-requests`).
- **`vet-housing`**: T14 (on a housing table: the first placement after
  T0 failing), T25 (a natural identifier on `animal_board`, so on every
  display); and the core's `animal_board` bitten by housing's T155, its
  `stays` by T157 and T161.
- **`vet-machinery`** and **`vet-portal`**: as their pages list them.

T60 and T78, s9 and s5 until D325, are traps for the GM again; no
fault of the ten sits on an `api` node's `db/` side, which the `api`
brick's own build checks cover (D328).

## 11. The data register (T300–T308, D330)

A scenario's data register is a player handout generated from the
ground truth by the GM's `data-register` skill (D331); these traps are
planted in the handout only, nothing in the system changing: a
`seed-file` change on the bastion's `data-register.md`, the answer key
recording each one's diff against the true register. Their resolution
is *propose*, the corrected entry, judged at the final answer (D333).
The whole family, its witnesses and its false-alarm material are on
[data-register-handout.md](data-register-handout.md#4-the-trap-family-the-register-itself-t300t308),
their one home.

| # | Trap | Fixed on | Catalogue | Class |
|---|---|---|---|---|
| T300 | an entry out of date (the portal's copies not declared) | the register, by *propose* | new, `governance-register-*` | M |
| T301 | a column missing (`exchanges.partner_patient`) | the register, by *propose* | new | M |
| T302 | a store missing (`office`) | the register, by *propose* | new | M |
| T303 | a wrong class (natural identifiers `internal`) | the register, by *propose* | new | M, V when a reader leaned on it |
| T304 | a wrong retention (controlled drugs five years) | the register, by *propose* | new | M |
| T305 | the register absent, the policy naming one | the register, by *propose* | new | M |
| T306 | the register vague | the register, by *propose* | new | M |
| T307 | cold storage, the vault, not declared | the register, by *propose* | new: s6 of the test selection (D332) | M |
| T308 | the franchise's messaging service not declared | the register, by *propose* | new | M |

A fault planted in the system (T49, T67) leaves the register as the
ground truth has it: the register is then the reference the system is
read against, as the policy is; it is not a register trap.

## What the build needs of a trap

For a trap the build turns into a fault (in v0.5 the test selection's
ten, D316): its `fault.yaml` with
the class it is planted for, its material for the layer it is fixed on,
its present and fixed checks, and its short fixture (D314,
[test selection](clinic-test-selection.md)). The rest stay here and in
the domains' GM notes ("the traps"), for a GM to write as a scenario's
fault when a game selects one (D309).
