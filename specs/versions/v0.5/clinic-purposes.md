# v0.5 — the clinic's purposes (step 7): `vet-core` and `vet-lab`

Status: draft v2, ruled. The owner accepted all eight points as drafted
on 2026-11-02 ("agreed", D306, closing O155) and the format's
extensions in section 4 (D307, closing O156, feeding O111); step 7 is
ruled for both domains. The partners' stubs share one `api` node, each
under its own hostname (D308). The candidate faults below are traps for
step 8; a scenario's faults are the GM's to select (D309).

Step 7 of the [procedure](domain-procedure.md#2-the-steps-from-a-brief-to-a-finished-domain)
for the clinic's first two domains together, since their flows
interlock: the core's consultations order analyses, the lab returns
results, both answer to the authority, and the reports read both. Step 6
named what it left here, with the rates these purposes meet
([vet-core](vet-core-domain.md#flows-to-step-7-with-their-rates),
[vet-lab](vet-lab-domain.md#the-round-trips-for-step-7-d268-d286); D304).

Built on, not reopened: a purpose's format and kinds (v0.4 master spec
6.7, 8; [formats.md](../../formats.md) "Purpose definition"); cadence
under real time (v0.4 master spec 8.4) as D265 replaces it for domains:
periodic reports with their past periods planted, at least one planted
periodic-data fault visible within the aging through a daily feeder, no
run on demand (D269), a fix checked on the feeder's next run or by the
sealed check reading the code (D277); round trips a kind of their own, a
cascade judged end to end (D286); the reports reading the standby and
writing `office` (D299, D300); `api` nodes that only answer, their
database side the players' (D270, D271); third parties out of reach,
every fix on the customer's side (D273–D275); script jobs with an HTTP
connection and partners ticking their own routes, each under its own
hostname on the partners' one `api` node (D303, D308); the
clinic's ten faults at most (D290), of which this page lists candidates
only.

## 1. Existing purposes that fit

None as built. v0.4's four fit the shop only (`domains: [shop]`), but
their shapes recur here: P1's reporting into a database of its own is
the office's reports; P5's pushed obligation is the notifications; P3's
mailing is the reminders, `vet-portal`'s (D304). The generic
`cold-storage-archive` ([cold storage](cold-storage.md) 2) fits neither
domain: nothing of the core's or the lab's ships (D297), and the WAL and
base backups the vault receives are the `postgres` brick's
([replication](replication.md) 2), not a purpose.

Named, not drafted here:

- **the release to the portal**, fitting `vet-lab`, `vet-core` and
  `vet-portal`: drafted with `vet-portal` (D304), the release gate of
  v0.4's stress test;
- **the referral's report back to the referring vet**, as an electronic
  flow: later (D278 answer 5); in v0.5 the vet's letter closes a
  referral (D304).

## 2. The purposes, at a glance

| # | Purpose | Kind | Fits | Cadence (scenario time) | Runs on | Source → target |
|---|---|---|---|---|---|---|
| 1 | `vet-lab-centre-orders` | round trip | core, lab | every minute; results every 5 minutes | `interfaces` | `clinic` → `lab-api`; `lab-api` → `clinic` |
| 2 | `vet-lab-practice-results` | round trip (the partner asks) | lab | every minute | `interfaces` | `lab` → the practices' stub |
| 3 | `vet-lab-send-outs` | round trip | lab | 16:00 Monday to Friday; chased every 15 minutes | `interfaces` | `lab` → the external lab's stub → `lab-api` |
| 4 | `vet-centre-exchanges` | round trip, both ways | core | every 5 minutes; chased daily | `interfaces`, and `clinic-api`'s exchange endpoints | `clinic` ↔ the other centres' stubs |
| 5 | `vet-notifiable-diseases` | pushed obligation | core, lab | every 5 minutes; escalation every 15; copy nightly | `interfaces`; the copy on `backoffice` | `clinic`, `lab` → the authority's stub; copy → `office` |
| 6 | `vet-lab-critical-calls` | pushed obligation | lab | every 10 minutes | `lab`'s `pg_cron` | `lab` → `lab` |
| 7 | `vet-medicines-registers` | pulled, periodic | core | feeders 01:30 and 01:45; monthly on the 1st; inventory 1 January | `backoffice` | the standby → `office` |
| 8 | `vet-antimicrobial-use` | pushed obligation, periodic | core | feeder 02:00; yearly, 15 January | `backoffice` | the standby → `office` → the authority's stub |
| 9 | `vet-head-office-figures` | pushed obligation, periodic | core, lab | feeder 00:30; monthly on the 1st | `backoffice` | the standby and `lab` → `office` → the head office's stub |
| 10 | `vet-lab-statements` | pulled, periodic | lab | feeder 02:30; monthly on the 1st | `backoffice` | `lab` → `office` |

No flow of the two domains is **transformed in place** or **pushed**
without an answer in v0.5: the reminders and the outbox, the pushed
ones, are `vet-portal`'s (D304). Kinds are v0.4's four and the round
trip (D286); "periodic" is D265's report, a pulled or pushed purpose
with a daily feeder and planted past periods.

The two medicines registers (the register of supplies and the
controlled-drugs register) are one purpose, 7: one source, one runner,
the same feeders' shape. Ten purposes in all (D306, point 1).

## 3. Where they run

| Runner | What | Holds |
|---|---|---|
| `interfaces` | the centre's integration engine: a scheduler node, role `transformer` (v0.4 master spec 7.1), running every flow between the centre's systems and out to its partners, light and frequent | `clinic` as `vet_interfaces`; `lab` as `lab_dispatch`; HTTP connections (D303) to `lab-api` (the centre's internal account), the practices' stub, the external lab's stub, the three centres' stubs and the authority's stub |
| `backoffice` | the back office's report runner: a scheduler node, role `transformer`, running the periodic reports and their feeders, heavy at night | the standby's `clinic` as `vet_reports`; `lab` as `lab_reports`; `office` as `office_jobs`; HTTP connections to the authority's and the head office's stubs |
| `lab`'s `pg_cron` | light, set-based work on the database node (D206, D207; v0.4 master spec 8.7) | the critical calls' watch, as `lab_watch` |
| The partners' back end | the shared scheduler node and database (D293): the partners' own streams and state, out of reach (D273) | as step 6 ruled; the authority and the head office answer only, no stream |

Two runners rather than one: the integration engine's flows are
latency-bound (an urgent order within a minute), the reports heavy at
night; a report placed on the integration engine, delaying the orders,
becomes a fault candidate rather than the design (D306, point 2). Light
work elsewhere stays where step 6 put it (`prescriptions.expire`,
`lab.samples.dispose`: `pg_cron` a placement the GM may choose).

Every job of `interfaces` holding an HTTP connection is a script job
(D303): it reads, calls and writes, each call's status and latency in
the runner's log. None runs more often than every minute.

## 4. The format, and what the round trip extends (ruled, D307)

Each purpose below is stated in v0.4's format (identity, parts, jobs,
trace, invariants, data moved, roles; [formats.md](../../formats.md)
"Purpose definition"), compressed into prose and tables; it becomes
`purposes/<id>/purpose.yaml`, `material/`, `checks/` and `gm.md` at the
build. What extends, accepted (D307), feeding O111:

1. **The round-trip kind** (D286): `kind: round-trip` and a
   `round_trips:` block, one entry per exchange the purpose carries
   (the exchanges carry two, one each way): who asks (the customer or
   the partner), the request (its job, its counterpart, what it sends),
   the correlation key, the expected answers (each form, when it comes,
   what it carries), the timeout and what follows it (resend with the
   same key, escalate), and the reactions (the processes an answer
   starts, the purpose's jobs or a domain's streams, named).
2. **Two parts**: `api`, a customer's `api` node the purpose calls or
   brings endpoints to (`lab-api`, `clinic-api`); `partner`, a declared
   third party's node, as the `receiver` of a pushed obligation is one
   from v0.5 (D274).
3. **HTTP connections** in a job's `connections:` (D303), named for the
   part they reach.
4. **Endpoint material**: `material/api/<node>/routes/` and `db/` for
   the endpoints a purpose brings to a customer's `api` node, the layout
   a domain's `producers/api/` uses (D303). A receiver with no stream of
   its own (the authority, the head office) keeps its stub in the
   purpose, as P5's `receiver/` does; a partner with streams of its own
   (the practices, the external lab, the centres) stays in its domain's
   `producers/partners/` (D303).
5. **Periodic purposes** (D265, D277): a periodic job names its daily
   feeder, the witness within the aging; `material/history.sql` plants
   the past periods' outputs into the target before T0. `office` belongs
   to no domain (D300), so the purpose plants it: `load-data` runs the
   file in the target database after the sources' loads, as the
   superuser, reading the sources through a temporary foreign server it
   drops afterwards, every session unseen (no statement logging,
   `pg_stat_statements` and pgaudit off, D265).
6. **How an invariant is judged**: `judged:` one of `runs` (v0.4
   master spec 12.2), `triggers` (12.4), `end-to-end` (D286: on the
   trace after the fix, the backlog a consequence in the answer key,
   never in the purpose), `code` (D277: the sealed check reading the
   code) or `definition` (12.6). A round trip names exactly one
   `end-to-end` invariant.
7. **The classes of the tables it brings**: a purpose whose target
   belongs to no domain (`office`), or which adds tables to a domain's
   database (the `ops` schema below), classes their columns in its own
   `classification:` entry, as a domain does (D191), so governance's G1
   reads them.

**The `ops` schema.** The purposes' own tables in a domain's database
(their ledgers, incidents, watermarks) live in a schema `ops`, in
`clinic` and in `lab`: never in `public`, where the domains' tables and
a part's prefixed ones live (procedure 4), so no purpose's table ever
clashes with a part landing in the same database. `office`'s tables are
the purposes' own, in `public`.

**Every run** writes one `ops.runs` (or `office`'s `runs`) row in the
same transaction as its output (v0.4's `etl_runs`), beside the runner's
log; the checks tie trace rows to runs by it (v0.4 master spec 12.2).

## 5. `vet-lab-centre-orders`: the centre's orders and their results

**Kind**: round trip, inside the centre (vet-lab answer 2, D301): the
centre's practice software posts each consultation's analysis requests
to the lab's order API, as the region's practices do, and the released
results' state comes back into the core's `requests`.

**Round trip**:

| | |
|---|---|
| Who asks | the customer (the core) |
| Request | `post-lab-orders`: a consultation's analysis requests, one order per consultation and priority, posted to `lab-api`'s `POST /orders` as account 1 (the centre's, never charged): the requests' ids, test codes, priority, the animal's id, the consultation, the requesting vet; for a residue screening the treatment's withdrawal end, read from `prescription_lines` |
| Correlation key | `client_ref`, `C-<consultation id>-<priority>`, unique per account: the idempotency key `lab-api` answers twice with one accession; the requests' ids, carried on each order test |
| Expected answers | the accession at once (201); each test's release later, read from a released-results feed |
| Timeout, then | no 2xx within ten seconds: retried at the next run with the same `client_ref`; a request `sent` and unreleased past its test's turnaround plus two hours: an `ops.incidents` row, once |
| Reactions | requests `sent`, the accession kept in `ops.lab_orders_sent`; requests `resulted` once their test is released; a test not performed (an unfit sample): its request `cancelled` with the reason, the vet's to reorder |

**Jobs** (on `interfaces`):

| Job | Cadence | What it computes |
|---|---|---|
| `post-lab-orders` | `* * * * *` | the analysis requests still `requested` whose consultation has closed: grouped, posted, each answer's accession recorded and the requests `sent` in one `clinic` transaction after the call returns |
| `fetch-lab-results` | `*/5 * * * *` | `GET /orders?account=1&released_since=<watermark>` on `lab-api`: the centre's tests released (or not performed) since the watermark; each request `resulted` (or `cancelled`), the copy in `ops.request_results`, the watermark advanced; overdue requests escalated |

`lab-api` gains the feed endpoint (section 15). A watermark rather than
one call per open order: one call a run, and the watermark's own way of
going wrong (v0.4's `purpose-watermark-misses-updates`) as a candidate
(D306, point 3).

**Trace**: `requests` (state), `ops.lab_orders_sent` (client_ref,
request ids, accession, attempts, last HTTP status, posted at, answered
at), `ops.request_results` (request, released at in the lab, copied
at), `ops.watermarks`, `ops.incidents`, `ops.runs`; the runner's log
with each call's line; on the lab's side, `lab_orders` of account 1 and
their tests' `request_id` (the GM's checks may read both).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| LO1 | Every analysis request of a consultation closed since the judged moment is `sent` with an accession within 5 minutes of the close, 2 for an urgent one, or `cancelled` | triggers | about 25 orders a day, around the clock; urgent ones at night |
| LO2 | No consultation's requests reach the lab as two orders: each request id appears on one lab order test only | runs | every run that retried a timed-out post; the lab's API slow at a courier wave |
| LO3 | Every centre test released since the judged moment has its request `resulted` within 10 minutes, and no request is `resulted` while its test is not released | runs | about 45 releases a day, in bursts at the rounds and at once for urgent ones |
| LO4 | End to end: every centre order posted since the judged moment has each test released or not performed within its turnaround plus the wait for the next release round, an urgent one within its turnaround | end-to-end | the routine tests' turnarounds (hours) end within a session; urgent ones within the hour |

**Data moved**: `requests.animal_id` (customer-linked in `clinic`)
reaches `lab_orders.animal_id`, which the lab's identity job makes
personal there; no name, contact or identifier leaves the core with the
order (the lab reads them through the lookup API, D266).

**Roles**: `vet_interfaces` on `clinic` (section 14); the centre's
account credential on `lab-api`, a secret.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| Requests marked `sent` before the call returns, in a transaction committed first | requests `sent` with no lab order behind them: results that never come, vets phoning the lab | the runner's script |
| The priority dropped in the mapping | urgent tests posted routine, waiting for the round: the emergency team's blood gases hours late | the runner's script |
| A retry under a new `client_ref` (`purpose-retry-without-key`, held since D201) | two lab orders for one consultation, two tubes expected, one never arrives: the duplicate unfit or not performed | the runner's script |
| The results' watermark taken from the run's start, or from the latest `released_at` read, while a release commits later | a few requests stuck `sent` though released: two places disagreeing (v0.4's `purpose-watermark-misses-updates`, adapted) | the runner's script |
| A technically validated test read as final | requests `resulted` before release: the release gate broken where the portal will read (D280 rule 11) | the runner's script |
| `post-lab-orders` at `*/15` or on business hours only | the night's emergencies posted in the morning | `jobs.yaml` |
| `lab-api`'s idempotency lookup on `client_ref` alone, unindexed (the unique index is on the account and the reference) | every post slower as `lab_orders` grows; the runner's call latency climbing | `lab-api`'s `db/` (D271) |
| `vet_interfaces` granted `UPDATE` on all of `requests` | a grant beyond the state columns (minor) | the grants |

## 6. `vet-lab-practice-results`: the results back to the practices

**Kind**: round trip where the partner asks (D293, D294): a practice's
back end posts its order to `lab-api` and gets the accession (the API's,
vet-lab step 6); the centre's half, the one that can go wrong, is
delivering the results to the practice's callback.

**Round trip**:

| | |
|---|---|
| Who asks | the partner (the region's practices, one stub for 120 accounts) |
| Request | the practice's order at `POST /orders`; the purpose's part: `deliver-practice-results` posting each delivery (interim, final, amended) to the account's callback, `POST /results` on the practices' stub |
| Correlation key | the practice's `client_ref` for the order; `delivery_key`, one per order, kind and revision, kept across attempts |
| Expected answers | an acknowledgement (2xx) of each `delivery_key`, a repeat acknowledged without a second record |
| Timeout, then | no acknowledgement within 30 seconds: retried 5 minutes after the last attempt with the same key, at most six attempts, then an `ops.incidents` row in `lab` (vet-lab step 6) |
| Reactions | `lab_callbacks` acknowledged; the order's report final once every test is; the charges billable on release are the information system's (D304) |

**Jobs** (on `interfaces`, `lab` as `lab_dispatch`): `deliver-practice-results`,
`* * * * *`: the practice orders with a test released, an amendment, or
an interim report due (a first test released while others are pending)
and no acknowledged delivery of it; one `lab_callbacks` row per attempt;
the deliveries made in parallel, at most four at a time, so one
practice's dead callback never holds the others.

**Trace**: `lab_callbacks` (order, kind, delivery key, attempt, posted
at, HTTP status, acknowledged at), `ops.incidents`, `ops.runs`, the
runner's log; the practices' stub's received deliveries (evidence).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| PR1 | Every practice test released since the judged moment is in a final delivery acknowledged within 15 minutes, or after six failed attempts in an incident | triggers | about 40 a working day, in bursts at the rounds |
| PR2 | A delivery keeps its `delivery_key` across attempts; one key per order, kind and revision | runs | the stub answers 503 to about one call in fifty, as standing behaviour (D214's precedent), so retries happen every day |
| PR3 | No delivery carries a result not released (lab rule 1) | runs | interim reports while tests are technical |
| PR4 | Each delivery goes to its own order's account's callback, never another practice's (lab rule 10) | runs | every delivery |
| PR5 | End to end: every practice order received since the judged moment has its released results acknowledged at its callback within the tests' turnaround, the wait for the next round and 15 minutes | end-to-end | about 25 orders a working day, most resulted the same day |

**Data moved**: `lab_orders.patient_ref`, `client_surname` and the
results (personal, the practice's own client data, the lab its processor
under GDPR Art 28) back to that practice only.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| The callback joined on the wrong key (`lab_accounts.id` against the order's `practice_id`, account `a` being practice `3(a − 1)`) | one practice receiving another's clients' results: a data breach a practice reported | the runner's script |
| Deliveries made one after the other with a long timeout | one practice's dead callback (a timeline outage) holds every delivery: all practices late, the phone ringing | the runner's script |
| A new `delivery_key` on each attempt | duplicates at the practices after every slow answer | the runner's script |
| Amendments never delivered (the query takes `final` only) | practices holding a superseded result | the runner's script |
| No incident after the sixth attempt, the delivery dropped silently | released results a practice never got, nobody told | the runner's script |
| A technically validated test sent as final | the release gate broken towards the practices | the runner's script |

## 7. `vet-lab-send-outs`: the external reference lab

**Kind**: round trip where the centre asks (D268), the consumer-producer
the owner ruled: the lab posts the day's send-outs, the external lab
accepts at once and calls back with the result one to five days later.

**Round trip**:

| | |
|---|---|
| Who asks | the customer (the lab) |
| Request | `send-outs`: the tests routed `sent-out` whose samples are received and not yet sent, one `lab_send_outs` row each, posted to the external lab's `POST /orders`: the accession, the sample's label, species, sex and age, the external code; never the owner, the client or an identifier (lab rule 11) |
| Correlation key | `send_key`, a UUID per send-out, sent again on every retry |
| Expected answers | `accepted` with the external accession at once; the result one to five days later at `lab-api`'s `POST /send-outs/{send_key}/result` |
| Timeout, then | not accepted: retried by `chase-send-outs` with the same key; past `due_by` by a working day with no answer: `POST /orders/{send_key}/resend` on the stub, which calls back again; after a second chase, an `ops.incidents` row |
| Reactions | the test resulted, then technically validated and released by the pathologist as the centre's own, naming the lab that performed it (the information system's streams, vet-lab step 6); then delivered by purposes 1 or 2 |

**Jobs** (on `interfaces`, `lab` as `lab_dispatch`):

| Job | Cadence | What it computes |
|---|---|---|
| `send-outs` | `0 16 * * 1-5` | packs and posts the day's send-outs: rows, a `sent-out` sample event each, the external accession on acceptance |
| `chase-send-outs` | `*/15 8-19 * * 1-6` | the unaccepted ones retried; the overdue ones chased, then escalated |

**Trace**: `lab_send_outs` (send key, external accession, packed, sent,
accepted, answered at, due by, status), the `sent-out` sample events,
`ops.incidents`, `ops.runs`, the runner's log; the stub's received
orders and posted answers (evidence).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| SO1 | Every sent-out test whose sample was received by 15:30 on a working day is accepted by the external lab that day, or in an incident | triggers | about 7 a working day; a 16:00 run in the aging, or the job moved to verify (D132) |
| SO2 | One `send_key` per send-out, kept on every retry: no test has two external accessions | runs | the chases; the stub's slow answers |
| SO3 | A send-out carries the catalogue's fields only: no owner, client, natural identifier or clinical note | runs | every `send-outs` run |
| SO4 | End to end, on the answer's leg: every answer the external lab posted since the judged moment is recorded against its send-out, and its test released by the end of the next release round | end-to-end | about twenty send-outs in flight at T0 (vet-lab step 6), answered through the aging |

The request's leg (posted at 16:00, answered days later) is longer than
a session; SO1 and SO4 judge its two ends, and a fault between them
leaves its backlog in the answer key (D286).

**Data moved**: none classed: the send-out carries the accession, the
label and the animal's species, sex and age.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| A natural identifier or the client's surname in the payload | personal data sent to a third party, against the lab's own rule 11 (a governance fault, adapting v0.4's `governance-personal-copied`) | the runner's script |
| A new `send_key` on each retry | the external lab running a test twice; its invoices (the story's) showing it | the runner's script |
| `lab-api`'s answer endpoint matching on the external accession, which a resend changes | answers recorded nowhere: results that never come back, though the external lab sent them | `lab-api`'s `db/` (D271) |
| The answer written straight as released | a result reaching the record unvalidated (lab rule 1) | `lab-api`'s `db/` |
| `send-outs` in UTC, after the courier has left at a positive shift | send-outs a day late, every day (adapting `purpose-day-boundary-wrong-zone`) | `jobs.yaml` |
| No chase: a lost callback (the partner's fault, D268) never asked for again | send-outs stuck past their due date, the vets chasing by phone | the runner (the chase job missing or never escalating) |
| A test mapped to the wrong external code (a trap, vet-lab answer 6) | the external lab returning another test's result | the catalogue, `lab_tests.external_code` |

## 8. `vet-centre-exchanges`: the other centres

**Kind**: round trip, two of them (one-centre 3, D293): the centre asks
another centre (a transfer, an examination its own machines or
specialists cannot do) and the other centres ask it. Privileged flows
inside the franchise (D293): an exchange may carry the animal's history
and its owner's contact, the data policy stating what may go.

**Round trips**:

| | Out: the centre asks | In: a centre asks |
|---|---|---|
| Request | an exchange the practice software records (section 15), posted by `sync-exchanges` to the centre's stub, `POST /exchanges` | the partner's `POST /exchanges` at `clinic-api`, written as `received` |
| Correlation key | `exchange_key`, a UUID, kept on a resend | the partner's `exchange_key` |
| Expected answers | `received` at once; accepted with a date, or declined, within a working day at `clinic-api`'s `POST /exchanges/{key}/answer`; for an examination, its report one to three days after it, at `POST /exchanges/{key}/report` | the centre's answer, then its report, posted by `sync-exchanges`, acknowledged by the stub |
| Timeout, then | no answer a working day after sending: resent with the same key by `chase-exchanges`; after a second working day, an `ops.incidents` row | the stub's own, out of the customer's side |
| Reactions | the exchange `accepted` (the transfer goes ahead, a booking later with `vet-scheduling`) or `declined` (the requesting vet's to redirect); the report filed with the exchange | the practice software's vets decide and report (section 15) |

**Jobs** (on `interfaces`, `clinic` as `vet_interfaces`):

| Job | Cadence | What it computes |
|---|---|---|
| `sync-exchanges` | `*/5 * * * *` | posts the outbound requests not yet sent, the inbound answers and reports not yet posted, each recorded with its HTTP status |
| `chase-exchanges` | `0 9 * * 1-5` | the outbound requests unanswered a working day: resent; two working days: escalated |

**Endpoints** the purpose brings to `clinic-api` (section 15): `POST
/exchanges`, `POST /exchanges/{key}/answer`, `POST
/exchanges/{key}/report`, as `vet_exchange`; they only answer (D270).

**Trace**: `exchanges` (section 15), `ops.exchange_messages` (each post,
either way: key, kind, direction, HTTP status, at), `ops.incidents`,
`ops.runs`, the runner's and `clinic-api`'s logs; the stubs' records
(evidence).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| EX1 | Every outbound exchange recorded since the judged moment is received by its centre within 10 minutes | triggers | about one a day, the transfers among them: rare (D306, point 6) |
| EX2 | Every inbound request decided since the judged moment has its answer posted within 10 minutes, every report written its report posted within 10 minutes | triggers | about one a day, business hours |
| EX3 | One `exchange_key` per exchange, kept on a resend; each answer recorded on its own exchange | runs | the chases; the in-flight exchanges at T0 |
| EX4 | An exchange carries what the franchise's agreement allows: this animal's record and its owner's contact, never another animal's or another owner's | runs | every post |
| EX5 | End to end: every outbound exchange sent since the judged moment is answered within a working day, or chased and then escalated | end-to-end | the exchanges in flight at T0, planted, and the day's |

**Data moved**: the animal's identifiers, its record's summary, the
owner's name and contact (personal), to another centre of the
franchise, under its agreement.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| `clinic-api`'s exchange endpoint answering 201 from a transaction it never commits | the partner told "received", the centre holding nothing: requests lost silently | `clinic-api`'s `db/` (D271) |
| Answers posted to the wrong centre (the site mapped off by one, `sites` 2–3 against 4–6) | a centre abroad getting another centre's answer; the asking centre chasing | the runner's script |
| An exchange carrying the owner's other animals' records | more than the agreement allows (a governance fault) | the runner's script |
| A new key on the resend | the partner holding the same request twice | the runner's script |

## 9. `vet-notifiable-diseases`: the authority

**Kind**: pushed obligation (v0.4's P5), the owner's own example of the
kind: a trigger in the data, a deadline, the authority as the outside
receiver, its acknowledgement or an escalation. Two triggers, one
purpose, since one receiver and one rule serve both: the lab notifies
on a positive or suspect result for a test tied to a listed disease, for
every customer (lab rule 7); the vet who records the diagnosis notifies
too (core rule 7).

**Trigger and deadline**: a `lab_notifications` row (the information
system's `lab.notify` writes it), or a `diagnoses` row whose code is
notifiable (suspected or confirmed). Within an hour for a category A
disease, a day for another listed disease: the lab's game values (D302),
applied to the vet's too (D306, point 7). The category needs
`diagnosis_codes` to say it (section 15).

**Receiver**: the authority's stub, its own hostname on the partners'
one `api` node (D308) and their back end (D304), material in the purpose (`receiver/`): `POST
/notifications` answers 201 with a reference, the same
`notification_key` again the same reference; it answers 503 to about one
call in fifty as standing behaviour, so retries and escalations have a
witness (D214's precedent).

**Jobs**:

| Job | Runs on | Cadence | What it computes |
|---|---|---|---|
| `notify-lab` | `interfaces`, `lab` as `lab_dispatch` | `*/5 * * * *` | the lab's notifications not yet notified: posted, keyed `lab-<id>`; `notified_at`, the channel and the authority's reference written back |
| `notify-vet` | `interfaces`, `clinic` as `vet_interfaces` | `*/5 * * * *` | the notifiable diagnoses with no notification: posted, keyed `vet-<diagnosis id>`, one `ops.notifications` row each |
| `escalate-notifications` | `interfaces`, both | `*/15 * * * *` | those with no reference by their deadline, or rejected: an `ops.incidents` row, once |
| `copy-notifications` | `backoffice` | `15 2 * * *` | yesterday's notifications, both sources, copied into `office.regulatory_submissions` (D300's copies) |

**Trace**: the triggers; `lab_notifications`, `ops.notifications`,
`ops.incidents`, `ops.runs` in `clinic` and `lab`;
`office.regulatory_submissions`; the runners' logs; the stub's records.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| ND1 | Every trigger since the judged moment is notified within its deadline | triggers | rare: a few a month (D306, point 6) |
| ND2 | One notification accepted per trigger | runs | the stub's 503s, retried |
| ND3 | A notification carries the disease, the species, the holding or the keeper's name and address, the notifying vet or lab and the date; never the clinical notes | runs | every post |
| ND4 | Every notification sent since the judged moment has its reference, or an incident by the next escalation run | triggers | the stub's 503s |
| ND5 | Every notification of yesterday is in `office`'s copies, once | runs | the nightly copy, when a day had one |

**Data moved**: the animal's identifiers, the holding number, the
keeper's name and address (personal), to the authority, by law
(2016/429 Art 18); the same in `office`'s copy.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| Category A treated as another listed disease | a suspected category A disease notified a day late | the runner's script |
| `notify-vet` taking confirmed diagnoses only | suspicions never notified, though Art 18 requires them | the runner's script |
| `notify-lab` taking the centre's account only | the region's practices' positives never notified, the lab's duty covering every customer | the runner's script |
| The authority's stub down (a timeline outage) and nothing escalating (v0.4's `purpose-receiver-down-unnoticed`, adapted) | notifications unacknowledged for hours, no incident | the escalation job |
| The findings' free text in the payload | clinical notes, owner's names in them, sent to the authority | the runner's script |

## 10. `vet-lab-critical-calls`: critical values phoned within the hour

**Kind**: pushed obligation: a critical result (the trigger) owes a call
to the requesting vet or the practice within 60 minutes (the deadline,
lab rule 6), its read-back the acknowledgement, an escalation to the
on-call pathologist when none comes. The call itself is a person's,
recorded by the information system's `lab.critical.call` stream (step
6); the purpose is the obligation's watch. The receiver is a person
inside the centre for its own vets, outside for a practice: P5's
"outside receiver" widens to the person owed the push.

**Job**: `watch-critical-calls`, a `pg_cron` job on `lab`, `*/10 * * *
*`, as `lab_watch`: one set-based statement writing an `ops.incidents`
row for each critical result measured more than 60 minutes ago with no
read-back call and no incident yet. Light, well scheduled, on the
database node: the placement the guideline allows (v0.4 master spec
8.7); `cron.log_run` on, so its runs are judged from
`cron.job_run_details` (v0.4 master spec 12.5).

**Trace**: `lab_results` (the flags), `lab_critical_calls`,
`ops.incidents`, `cron.job_run_details`.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| CC1 | Every critical result measured since the judged moment has a read-back call within 60 minutes, or an incident by the next watch run | triggers | two or three a day; more where the scenario's critical limits are wider (a game value) |
| CC2 | One incident per uncalled result | runs | every watch run after a miss |

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| The watch scheduled by the superuser, `cron.job.username` `postgres` | a job running as superuser that no runner lists (adapting `security-crontab-superuser` to `pg_cron`) | `cron.job` |
| The watch filtering `flag = 'critical'` while the flags are `critical-low` and `critical-high` | it never escalates; misses found only by reading the calls | the job's statement |
| `cron.log_run` off | no run to judge, nothing showing the watch alive | the setting |
| The call stream's key calling the centre's vets only (a fault riding the schedule) | the practices' critical values never phoned; the watch's incidents piling up | the information system's fragment |

## 11. `vet-medicines-registers`: the register of supplies and the controlled-drugs register

**Kind**: pulled, periodic (D265): the registers are published in
`office` for the inspector and the vets to query, monthly extracts and
balances on the 1st, fed daily. Core rules 2 and 3 (D280).

**Jobs** (on `backoffice`, reading the standby as `vet_reports`,
writing `office` as `office_jobs`):

| Job | Cadence | What it computes |
|---|---|---|
| `feed-medicines-register` (feeder) | `30 1 * * *` | yesterday's supplies of prescription-only medicines, the customer's day: each dispensing and each administration given, with the product, form, batch, quantity, recipient (the owner's name and address for a dispensing; the centre for an administration in hospital), prescribing vet, authorisation number (Art 103(3)) |
| `feed-controlled-drugs` (feeder) | `45 1 * * *` | yesterday's movements of controlled medicines, out of the batches the load received (stock receipts are out of v0.5, D278) |
| `close-medicines-register` | `0 3 1 * *` | the past month's extract: its lines' count and totals per product, a checksum |
| `balance-controlled-drugs` | `15 3 1 * *` | each controlled medicine's and batch's monthly balance: the opening, the month's movements, the closing; signed by the vet in the story |
| `inventory-controlled-drugs` | `30 3 1 1 *` | the yearly inventory, on 1 January |

**Planted before T0** (`history.sql`): the year's register lines and
movements, every full month's extract and balance, last January's
inventory. Periodic runs in the aging: none, unless the GM places one
(D265).

**Trace**: `office.medicines_register`, `office.controlled_movements`,
`office.register_extracts`, `office.controlled_balances`,
`office.controlled_inventories`, `office.runs`, the runner's log.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| MR1 | Each feeder run since the judged moment holds every supply of its day once, its batch and quantity equal to the source's | runs | about 75 dispensings and 240 administrations a day |
| MR2 | A register line carries the fields of Art 103(3) and no more: no e-mail, no phone | runs | every feeder run with a dispensing |
| MR3 | Each controlled-drugs feeder run holds every movement of its day once | runs | the anaesthetics of the day's procedures (about three consultations in ten) |
| MR4 | A month's balance equals the previous closing less the month's movements, per batch | code | the planted months; the 1st's run if the GM places one |

**Data moved**: `owners.name` and `address` (personal) into
`office.medicines_register`, as the law requires; nothing else of the
owner.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| The feeder joining administrations through prescription lines twice | supplies counted twice in the register | the feeder's query |
| Administrations in hospital left out (dispensings only) | the register short of most of its lines | the feeder's query |
| The feeder's day in UTC (adapting `purpose-day-boundary-wrong-zone`) | supplies around midnight in the wrong day, or missing | the feeder's query |
| The owner's e-mail and phone copied into `office` (adapting `governance-personal-copied`) | personal data beyond the register's rule | the feeder's query |
| A controlled medicine not flagged (ketamine), planted in the history and carried forward | its movements absent from the controlled register for the year and every day since | the reference data (`medicines.controlled`) and the feeder's next run |
| The feeders reading the primary, not the standby (D300's candidate) | their reads competing with the night's traffic and base backup | the runner's connection |

## 12. `vet-antimicrobial-use`: the yearly report to the authority

**Kind**: pushed obligation, periodic: the yearly antimicrobial-use
report for the species due (core rule 4: the cattle today; sheep, goats
and horses from mid-2027; dogs and cats from mid-2030), posted to the
authority, which answers with a reference; fed daily for every species.

**Jobs** (on `backoffice`):

| Job | Cadence | What it computes |
|---|---|---|
| `feed-antimicrobial-use` (feeder) | `0 2 * * *` | yesterday's antimicrobial use per species and medicine (ATCvet): administrations and dispensings, quantities of active substance, animals treated, herd treatments counted through their herd |
| `report-antimicrobial-use` | `0 4 15 1 *` | last year's report for the species due on the day it runs, summed from the feeder's rows, posted to the authority's `POST /amu-reports`; its reference and a copy in `office.regulatory_submissions`; deadline 31 January (a game value) |

**Planted before T0**: the year's daily rows, last year's report (the
cattle's) and its reference.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| AM1 | Each feeder run since the judged moment holds its day's antimicrobial use per species and medicine, equal to the source's | runs | the day's antimicrobial prescriptions, every day |
| AM2 | Every use traces to a species: a herd treatment counts its herd's species, nothing falls out for lack of an animal | runs | herd visits on Tuesdays and Thursdays prescribe to herds |
| AM3 | The yearly report covers the species due at its date, and equals the sum of its year's daily rows | code | last year's planted report; January's run if the GM places one |
| AM4 | The report is acknowledged by its deadline, or escalated | triggers | January only: planted |

**Data moved**: none classed: counts and quantities per species and
medicine.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| Herd prescriptions dropped by a join on `animals` (a herd treatment carries a herd, no animal) | the cattle, the one species due, under-reported every day and in last year's planted report | the feeder's query (the report rerun recommended, D277) |
| Prescriptions counted instead of administrations and dispensings | the use over-reported | the feeder's query |
| The species filtered on a label the core does not use (`bovine` against `cattle`) | an empty report | the report's code (judged by AM3) |
| The feeder reading at the hour of the base backup | the night's two heavy reads together (adapting `scheduler-batch-at-peak`) | `jobs.yaml` |

## 13. `vet-head-office-figures`: the franchise's monthly figures

**Kind**: pushed obligation, periodic: each centre owes the head office
its month's activity figures by the 5th (one-centre 1), answered with a
reference; fed daily into `office`, where the figures are the back
office's own business report, the daily census and the lab's turnaround
among them.

**Jobs** (on `backoffice`):

| Job | Cadence | What it computes |
|---|---|---|
| `feed-daily-figures` (feeder) | `30 0 * * *` | yesterday's figures, the customer's day: consultations per section and kind, admissions, discharges, the stays at midnight, new owners and animals, from the standby; the lab's tests per discipline and priority, outside orders and their median turnaround, from `lab` |
| `send-monthly-figures` | `0 5 1-5 * *` | the past month's figures, summed from the daily rows, posted to the head office's `POST /figures` on the 1st, retried each morning to the 5th; a month still unanswered on the 5th escalated |

**Planted before T0**: the year's daily rows, every full month's
figures and the head office's references.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| HO1 | Each feeder run holds its local day's counts, equal to the sources' | runs | every day: about 85 consultations, 8 admissions |
| HO2 | One row per day, section and measure | runs | every feeder run |
| HO3 | A month's figures equal the sum of its days, sent by the 5th and acknowledged, or escalated | code | the planted months; the 1st's run if the GM places one |

**Data moved**: none classed: counts and durations.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| The stays counted when the feeder runs, not at midnight | the census off by the night's admissions and discharges | the feeder's query |
| The turnaround's median taking cancelled and unperformed tests | a turnaround figure better than the lab's | the feeder's query |
| `office_jobs` holding write grants on `clinic` (D300's candidate) | a grant the separation forbids | the grants |
| The runner's role on the standby expired (adapting v0.4's `purpose-etl-role-expired`) | every report's night run refused, the daily rows missing since | the role |

## 14. `vet-lab-statements`: the practices' monthly statements

**Kind**: pulled, periodic (D294, D300): each practice's monthly
statement, published in `office`, its charges at the price of the
order's day, the volume discount by the month's total (lab rule 13).

**Jobs** (on `backoffice`, reading `lab` as `lab_reports` at night, the
lab having no standby, D304):

| Job | Cadence | What it computes |
|---|---|---|
| `feed-lab-charges` (feeder) | `30 2 * * *` | yesterday's billable and voided charges of practice accounts, each with its order, test, kind, amount, the order's patient reference and client surname, into `office.lab_charge_lines` |
| `close-lab-statements` | `0 4 1 * *` | each account's statement for the past month: billable less voided, the discount bracket (3 to 15 %, a game value), the total, into `office.lab_statements` |

**Planted before T0**: the year's charge lines, every full month's
statements, one per account with charges.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| ST1 | Each feeder run holds every charge made billable or voided on its day, once, its amount equal to the lab's | runs | about 60 charges a working day; voids on cancellations and unfit samples |
| ST2 | The centre's internal account is never charged nor stated (lab rule 13) | runs | the centre's orders, every day |
| ST3 | A statement equals its month's billable charges less voids, with its bracket's discount | code | the planted months; the 1st's run if the GM places one |

**Data moved**: `lab_orders.patient_ref` and `client_surname`
(personal) into `office.lab_charge_lines`: the practice's statement
lists its own clients' orders.

**Candidate faults**:

| Candidate | What the players find | Fixed on |
|---|---|---|
| The feeder run at bench hours, on the lab's only node (D304's candidate) | a report competing with the bench at its busiest | `jobs.yaml` |
| Voids taken only for charges made on the same day | a charge voided after it became billable still stated | the feeder's query |
| A charge at today's price instead of the order's day (a trap, vet-lab answer 13), carried forward | statements over the price list in force when ordered | the information system's charge, then the feeder's next run |
| The discount applied per line | statements off by rounding, each month | the statement's code (ST3) |

## 15. What step 7 asks of the domains

Each item is a change to a ruled step, accepted with the purposes
(D306), and applied on 2026-11-03 to
[vet-core](vet-core-domain.md) steps 4 and 6 and
[vet-lab](vet-lab-domain.md) step 6:

**`vet-core`**

- **Exchanges as the core's record** (point 5): a table `exchanges`
  (`id`; `direction` `out` or `in`; `kind` `transfer` or `examination`;
  the partner site; the animal, or for an inbound request the partner's
  patient summary until the animal is registered; reason; `exchange_key`;
  requested at; answer, accepted date or declined, answered at; report
  at; state), written by the practice software: a volume stream
  `exchanges.request` (about 0.7 a day on `office` hours), the
  transfers of `stays.discharge` (0.3 a day) each recording one, and
  two work streams, `exchanges.decide` (an inbound request accepted
  with a date, one in ten declined, within a working day) and
  `exchanges.report` (an accepted examination's report one to three
  days after it). This amends step 6's "trace tables come with the
  purpose": the request is the record's, the messages the purpose's.
  The history plants about 700 exchanges and those in flight at T0.
- **The disease's category**: `diagnosis_codes.notifiable` becomes
  `none`, `A` or `other`, so the vet's deadline can be computed (point
  7).
- **The other centres' stubs**: `producers/partners/centres/`, the
  three stubs' fragments (D303): `POST /exchanges`, `POST
  /exchanges/{key}/answer` and `/report`, and the back end's streams
  answering within a working day, reporting one to three days after,
  and asking about once a day.

**`vet-lab`**

- `lab-api` gains `GET /orders?account=<id>&released_since=<time>`, the
  released tests of one account's orders since a time, for the centre's
  account (point 3).
- The external lab's stub gains `POST /orders/{send_key}/resend`, its
  back end posting the answer again.

**Roles**, below.

## The roles the purposes add

| Database | Role | Who | Reads | Writes |
|---|---|---|---|---|
| `clinic` | `vet_interfaces` | `interfaces`' jobs | `requests`, `consultations` (state, closed at), `prescription_lines` and `administrations` (withdrawal ends), `diagnoses` and `diagnosis_codes`, `stays`, `exchanges`, `animals` (id, species) | `requests`' state, `exchanges`' sent and posted columns, `ops.*` |
| `clinic` | `vet_exchange` | `clinic-api`'s exchange endpoints | `exchanges` | inbound `exchanges`, the answers and reports received on outbound ones |
| `clinic` (on the standby) | `vet_reports` | `backoffice`'s reads | every table (step 4) | nothing |
| `lab` | `lab_dispatch` | `interfaces`' lab jobs (step 4) | as step 4 | as step 4, and `lab_notifications`' `notified_at`, channel and reference; `ops.*` |
| `lab` | `lab_watch` | the critical calls' `pg_cron` job | `lab_results`, `lab_critical_calls`, `lab_order_tests` | `ops.incidents`, `ops.runs` |
| `lab` | `lab_reports` | `backoffice`'s reads (step 4) | every table | nothing |
| `office` | `office` | owns everything; no login | | |
| `office` | `office_jobs` | `backoffice`'s writes | `office` | every `office` table; nothing elsewhere |
| `office` | `office_reader` | the back office's staff and dashboards | `office` | nothing |

**The office role** (point 4), the name [replication](replication.md#3-where-the-reports-write-a-back-office-database-d300)
3 left to step 7: `office_jobs` writes `office` and reads nothing of the
record; the reports read as `vet_reports` and `lab_reports`, never given
a write grant. A report job holds two connections, as v0.4's
`rollup-hourly` does.

## `office` at T0

| What | Rows planted |
|---|---|
| The medicines register and the controlled movements | about 90 000 and 9 000 |
| Extracts, balances, the inventory | about 600 |
| Antimicrobial use per day | about 15 000 |
| Daily figures, monthly figures | about 5 500, 12 |
| Lab charge lines, statements | about 17 000, about 1 400 |
| Regulatory copies, run rows | about 50, about 3 000 |
| **Total** | **about 0.14 million rows** |

Live, about 500 rows a night. On the primary's instance beside `clinic`
(D300), it rides the standby and the archive.

## Candidates against the clinic's budget (D290)

Far more candidates than the ten faults the scenario may hold; the
choice is the scenario's. Read against D290's mix, without choosing:

- **Dramatic, already noticed by the customer**: orders marked `sent`
  before the lab answered (results never coming); the urgent priority
  dropped (the emergency team waiting); a practice receiving another's
  results; one dead callback holding every delivery.
- **On the verge**: the results' watermark missing late releases (a
  few requests stuck, more each busy hour); a retry without a key
  (duplicates growing with the partner's slowness); herd treatments
  missing from the antimicrobial use (a compliance gap a year deep); the
  lab's feeder at bench hours.
- **Optimisations and minor frictions**: the feeders in UTC; a report
  reading the primary; `office_jobs` or `vet_interfaces` over-granted;
  the watch running as superuser; `lab-api`'s idempotency lookup
  unindexed.
- **A false alarm**: "the external lab is slow": a PCR answered on its
  fourth day, within its turnaround.

## Points for the owner, ruled (D306)

Accepted as drafted on 2026-11-02 ("agreed"), with vet-lab's two asks
(the results feed on `lab-api`, `resend` on the external lab's stub).

1. **Ten purposes, all built in v0.5**: the four round trips, the
   notifications, the critical calls' watch, the two registers as one
   purpose, the antimicrobial-use report, the head office's figures,
   the lab's statements. About two and a half times v0.4's four
   purposes. The release to the portal waits for `vet-portal`; the
   referral's electronic report stays later.
2. **Two runners**: `interfaces`, the centre's integration engine, and
   `backoffice`, the report runner; the critical calls' watch on the
   lab's `pg_cron`.
3. **The results come back by a feed**: `fetch-lab-results` polls
   `lab-api`'s released results every five minutes with a watermark; the
   lab never writes into `clinic`.
4. **The office role**: `office_jobs` writes `office` only; the reports
   read as `vet_reports` and `lab_reports`, with no write grant.
5. **Exchanges in the core's record**: a table `exchanges` and three
   streams of the practice software, the exchange endpoints on
   `clinic-api` as `vet_exchange`; amends `vet-core`'s steps 4 and 6.
6. **Rare flows**: notifiable diseases (a few a month), exchanges (one a
   day) and critical calls (two or three a day) leave a fault on them
   short of witnesses; such a fault is planted only with a story that
   raises the rate from T0 for the whole game (an outbreak in the
   region's herds, a machine down at another centre), set in the
   scenario's profile layer (D264), never a timeline change after the
   hand-over.
7. **Notifications**: one purpose for the lab's and the vet's; the
   category on `diagnosis_codes`; the lab's game values (an hour for
   category A, a day for the others) for the vet's too.
8. **The game values**: an order posted within 5 minutes of the close
   (2 if urgent); a practice delivery acknowledged within 15 minutes,
   six attempts; send-outs at 16:00 for samples received by 15:30; an
   exchange answered within a working day, chased then escalated; the
   antimicrobial-use report sent 15 January, due 31 January; the head
   office's figures by the 5th; the statements' discount brackets.

The format's extensions (section 4) are ruled (D307), feeding O111.
