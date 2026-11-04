# The vet-lab domain: GM notes

The clinical pathology laboratory of the centre a scenario deploys, a
part of `vet-core` (v0.5 master spec 9.3;
[vet-lab-domain.md](../../../specs/versions/v0.5/vet-lab-domain.md)):
the business, the keys it uses and its own, its data, who may touch
what, its producers and partners, and the traps it holds. A design-time
source: copy its files into a scenario and adapt them there; the domain
itself never changes for a scenario. The lab is taken only with its
core; it refers to the core's keys by id with no foreign key and
computes them by the core's functions, never reading `clinic`.

| File | Copied to | What |
|---|---|---|
| [`data/schema.sql`](../data/schema.sql) | loaded by `gmctl load-data` into the lab's `domains:` `at:` database (`lab` on `lab`, answer 1) | six roles, nineteen `lab_` tables, indexes, grants; `CONNECT` by name |
| [`data/keys.sql`](../data/keys.sql) | streamed by `load-data` after the core's keys, ahead of this part's load and its partners' `data.sql` | the part's key functions, `pg_temp.lab_*` ("Part keys", below) |
| [`data/load.sql`](../data/load.sql) | after `schema.sql`, in the same database | last night's backup: a year of history, from the key functions |
| [`data/coherence.yaml`](../data/coherence.yaml) | run by `load-data` after the loads | five checks: the core's keys, the requests in step, staff and practices, the two stubs' open state |
| [`data/classification.yaml`](../data/classification.yaml) | where `governance.classification` names it | the class of every column |
| [`data/register.yaml`](../data/register.yaml) | the scenario's data register (chunks 17, 27) | six processing activities, every table in one |
| [`data/governance.yaml`](../data/governance.yaml), [`policy.md`](policy.md) | the scenario's `governance:` and `player/data-policy.md`, beside the core's | the thirteen rules, where each class may live |
| `producers/lis/` | the information system's node (`nodes/lis/`) | `queries.yaml`, `schedule.yaml`, `jobs.yaml` (chunk 12b) |
| `producers/api/lab-api/` | the order API's node (`nodes/lab-api/`) | `api.yaml`, `routes/`, `db/` (chunk 12b) |
| [`producers/partners/xlab/`](../producers/partners/xlab/), [`producers/partners/practices/`](../producers/partners/practices/) | `partners-db`'s data and the partners' back end and `api` node | each stub's `data.sql` (its state, from the key functions); its fragments (chunk 12b) |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | read by compose | the lab's axes in the core's variant |

## The business

The centre's lab: six analysers (`vet-machinery`'s machines 1–2
haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6
coagulation), a microscopy and cytology bench, a microbiology bench,
serology and rapid tests, and a milk inhibitor test. Its customers are
the centre itself (an internal account, never charged) and 120 of the
region's 400 referring practices, who post orders to its API and get
their results at their callback; what it cannot run (histopathology,
most PCR, endocrinology, toxicology) goes to one external reference lab,
Northfield Veterinary Laboratories (`northfield-lab`). A result leaves
the lab once a clinical pathologist (staff 79, 80) has released it, after
a technician's (71–78) technical validation; urgent results are shown
inside the centre at once, marked unvalidated. The bench works 07:00–21:00
Monday to Saturday, an on-call technician runs urgent haematology,
biochemistry and blood gases at night and on Sundays; the courier brings
the practices' samples back at about 10:45 and 16:45; the pathologist's
rounds release at 11:00, 14:00 and 18:00 (11:00 on Sundays); send-outs
leave at 16:00 Monday to Friday.

## Core keys used

The lab computes the core's keys by the core's own functions
(vet-core [GM notes](../../vet-core/docs/gm.md#core-keys), D302), streamed
ahead of its load:

| Core function | What the lab takes |
|---|---|
| `core_request(n, load_epoch, utc_offset)`, `n` 1–17 000 | the analysis requests that reached the lab (`sent_at` set): their code, consultation, animal, requesting vet, priority, state, `sent_at`, `resulted_at`, `cancelled_at`, a milk inhibitor test's `withdrawal_ends_on` |
| `core_animal(n, ...)`, `core_microchip(n)`, `core_ueln(n)`, `core_ear_tag(n)` | a centre order's species, sex, date of birth and natural identifiers, as the core computes them (so the core's dozen mistyped chips, T13, match no lab order) |
| `core_ownership(n, ...)`, `core_owner(n, ...)` | the owner's family name on a centre order, as the lookup API would answer it |

Staff: the lab's technicians 71–78 (`kind` `lab`), its clinical
pathologists 79–80, the nurses who collect 29–51, the requesting vets
the core's; referring practice `3 × (a − 1)` for account `a`. The lab
calls only the core's eighteen `pg_temp.core_*` functions, never its
`pg_temp.vc_*`.

## Part keys

The partners' `data.sql` and every derivation or history reading the
lab compute its ids by these functions, never by reading `lab` (W3 items
0 and 1). The text is [`data/keys.sql`](../data/keys.sql); where the two
differ, `keys.sql` is right. `load-data` streams it after the core's
`keys.sql` (chunk 29's (a)); by hand, open a `psql` session as `postgres`,
`\i` the core's `keys.sql` then this one:

```sql
SELECT * FROM pg_temp.lab_order(4711, '2026-11-04T10:00Z', 2);
```

**One pass.** The centre's orders are the core's analysis requests that
reached the lab, one order a consultation, so every order's id depends
on the core's whole history. `pg_temp.lab_order_tests(load_epoch,
utc_offset)` computes the year in one pass (17 000 `core_request` calls,
about 60 s) and returns one row per order test with its order's,
sample's and send-out's columns; a file calls it once (`load.sql`
materialises it, each stub's `data.sql` filters it). `lab_order(n, ...)`
and `lab_send_out(n, ...)` are lookups over it, the contract W3 named,
about 60 s a call: for a GM's question, not for a loop.

### The ranges

| Key | Range | Layout |
|---|---|---|
| `lab_analytes.id` | 1–70 | 1–14 haematology, 15–47 biochemistry, 48–53 blood gases, 54–57 coagulation, 58–61 urine, 62–66 hormones, lead, IgG; 67–70 text (organism, sensitivity, qualitative result, report) |
| `lab_tests.id` | 1–180 | the test catalogue (D372): 1–114 in house, 115–150 sent out (36), 151–180 the panels; `pg_temp.lab_catalogue()` |
| `lab_reference_intervals.id` | 1–460 | 1–60 the January review's replaced rows (analytes 15–24, six species), 61–456 those in force (66 numeric analytes × 6 species); 457–460 unused |
| `lab_prices.id` | 1–360 | test `t`'s price `t` until 1 January, `180 + t` from it |
| `lab_accounts.id` | 1–121 | 1 the centre (`internal`); `a` from 2 practice `3 × (a − 1)` |
| `lab_orders.id` | 1–14 000 | in `ordered_at` order over the year, the centre's and the practices' mixed; 13 684 at the reference T0 |
| `lab_order_tests.id` | 1–24 000 | in their order's order, then their position |
| `lab_samples.id` | as loaded, about 20 800 | one per order and sample type (a container, answer 5), in their order's order; label `ALD` + the id on eight digits |
| `lab_send_outs.id` | as loaded, about 1 940 | in `packed_at` order; `send_key = md5('vet-lab-send-out:' ‖ id)::uuid` |
| `lab_results.id` | 1–192 000 | in `measured_at` order, the amendments after the year's results |
| the others | as loaded | events, QC runs, batches, calls, notifications, callbacks, charges: in time order, no other file reads them |

### `lab_order_tests(load_epoch, utc_offset)`

Returns, per order test: the order (`order_id`, `account_id`,
`client_ref`, `priority`, the centre's `animal_id`, `consultation_id`,
`requested_by`, a practice's `patient_ref`, `client_surname`, `species`,
`sex`, `born_on`, `microchip`, `ueln`, `ear_tag`, `withdrawal_ends_on`,
`ordered_at`, `received_at`, `completed_at`, `order_cancelled_at`,
`order_state`), the test (`order_test_id`, `test_position`, `test_id`,
`code`, `request_id`, `routing`, `status`, `not_performed_reason`,
`measured_at`, `technical_at`, `technical_by`, `released_at`,
`released_by`, `cancelled_at`, `final_at`), its sample (`sample_id`,
`sample_type`, `label`, `collected_at`, `collected_by`, `condition`) and
its send-out (`send_out_id`, `send_key`, `xlab_accession`, `packed_at`,
`sent_at`, `accepted_at`, `answered_at`, `due_by`, `send_status`). Every
draw is `lab_u(x, salt) = (hashint8extended(x, 7100 + salt) & 2³¹−1) /
2³¹`. Times at or after `load_epoch` are null, the states those at T0.

- **The centre's orders.** Every `core_request` with `kind` `analysis`
  and `sent_at` set (the vet's cancellations before sending never reach
  the lab), grouped by consultation: one order, `client_ref`
  `C-<consultation>-<priority>`, ordered at the first request's
  `sent_at`, one test per request in request order. Received 15 to 35
  minutes later (`u₁₉`, at most three tenths of the way to the first
  release). Each test's final state is the core's: a `resulted` request
  is a released test (or not performed on an unfit sample), a
  `cancelled` one a test cancelled by the lab (D315), each **0.5 to 4.5
  minutes before** the core's `resulted_at` or `cancelled_at` (`u₁₈`,
  purpose 1's five-minute polling); measured, validated and, for a
  sent-out test, packed, sent and answered at fixed fractions of the
  span from receipt to release. **The core states every request of the
  last 24 hours `sent`**, so the lab holds the centre's tests of those
  hours unreleased at T0 (in progress, sent out, or technical, awaiting
  the next round), and the centre's older send-outs all answered.
- **The practices' orders.** 2.9 an hour on `practice-hours` (Monday to
  Friday 08:00–12:00 and 14:00–19:00 at 1.0, 0.3 over lunch; Saturday
  08:00–12:00), ramping from 0.6 to 1.0 over the 53 weeks, laid hour by
  hour (each hour's count the floor of the running sum); order `m`'s
  account `2 + ⌊120 u₂⌋`, `client_ref` `<local YYMMDD>-<m>`, urgent when
  `u₃ < 0.05`, species 42 % dogs, 28 % cats, 15 % horses, 9 % cattle, 3 %
  sheep, 3 % goats (`u₄`), a patient reference, a client's surname, a
  chip (dogs, cats and horses, four in five), a UELN, an ear tag; one,
  two or three tests (55/30/15 %, `u₁₃`) drawn by the catalogue's
  practice weights without replacement (`ln u₁₅ / w`), a sent-out test's
  weight half again, valid for the species and sex, urgent orders in
  house of four hours or less. One in a hundred is cancelled 1 to 9
  hours after posting, never received. Received with the courier's wave
  (posted by 09:30, the 10:45 wave; by 15:30, the 16:45 one; else the
  next working day's) plus 15 to 75 minutes; measured after `tat × (0.3
  to 0.8)` hours, moved to the bench's next opening unless
  night-capable; validated 10 to 60 minutes later; released at the next
  round (urgent: 5 to 20 minutes later). Sent out: packed at the next
  16:00 Monday to Friday, sent 20 to 50 minutes later, accepted 1 to 5
  minutes after, answered `tat × (0.6 to 1.0)` hours later within the
  external lab's hours, validated 30 to 150 minutes after.
- **Samples.** One per order and sample type; fit 97 % (`u₁₆` of the
  sample), else haemolysed, lipaemic, clotted, under-filled, unlabelled
  or icteric, its tests not performed. A centre's sample is unfit only
  when every request on it resulted in the core.

### `lab_order(n, ...)`, `lab_send_out(n, ...)`

`lab_order` returns order `n`'s columns above, its `state` (`ordered`,
`received`, `completed`, `cancelled`) and its tests' codes;
`lab_send_out` send-out `n`'s order test, order, `send_key`, the external
lab's accession (`NL` + `400000 + n`), the label, the external code, its
times, `due_by` (packed + 50 minutes + the test's turnaround) and
`status` (`packed`, `sent`, `accepted`, `resulted`).

### `lab_catalogue()`, `lab_delivery(accession, kind, revision, event_at)`

`lab_catalogue()` is the test catalogue, 180 rows: code, name, panel,
discipline, sample type, turnaround, performed, external code
(`NL-<code>`, sent-out tests), the core's diagnosis code for a listed
disease's test, night-capable, the species it may be ordered for, its
analytes and the practices' weights. `lab_delivery` is a practice
delivery's `delivery_key` (`md5('vet-lab-delivery:' ‖ accession ‖ ':' ‖
kind ‖ ':' ‖ revision)::uuid`, one per order, kind and revision, kept
across attempts) and its times: posted 1 to 3 minutes after its event,
one in fifty failing first (a 503) and retried 5 minutes later.

### The reference T0

The figures here are at `load_epoch` 2026-11-04 10:00Z (a Wednesday),
offset +2, as the core's. A part loaded at another `load_epoch` than the
core's computes another history: `load-data` passes one to every file of
a run.

## The data

At the reference T0, counted with `count(*)`:

| Table | Rows | Notes |
|---|---|---|
| `lab_settings` | 1 | the zone and offset; handling fee 6.50, urgent surcharge 50 %, critical call 60 minutes |
| `lab_analytes`, `lab_tests`, `lab_test_analytes` | 70, 180, 348 | the catalogue |
| `lab_reference_intervals`, `lab_prices`, `lab_accounts` | 456, 360, 121 | |
| `lab_orders` | 13 684 | 7 374 the centre's, 6 310 the practices'; at T0 58 received and 8 awaiting the courier |
| `lab_order_tests` | 23 406 | 13 341 the centre's; 8.7 % sent out; 22 202 released, 738 not performed, 365 cancelled; at T0 32 technical, 37 in progress, 21 sent out |
| `lab_samples` | 20 807 | 11 777 the centre's: its orders' CBC and profile take two containers |
| `lab_results` | 160 890 | 813 amendments; 800 critical |
| `lab_batches`, `lab_qc_runs` | 9 776, 7 861 | |
| `lab_sample_events` | 62 968 | |
| `lab_send_outs` | 1 937 | 8 open at T0, all the practices' |
| `lab_callbacks` | 9 509 | |
| `lab_critical_calls`, `lab_notifications` | 794, 33 | no category A positive in the history |
| `lab_charges` | 16 876 | |
| **Total** | **330 077** | |

## The roles (vet-lab-domain.md, "Application roles and grants")

| Role | Who | Reads | Writes |
|---|---|---|---|
| `lab` | owns everything; no login | | |
| `lab_app` | the information system (`lis`) | every table | orders, samples, tests, events, results, calls, notifications, QC runs, charges; never the reference tables |
| `lab_api` | the order API (`lab-api`) | the catalogue, accounts, orders, samples, tests, results, send-outs | the intake; the external lab's answers (a send-out's `status`, `answered_at`; its results) |
| `lab_instruments` | the analysers' middleware (`lis`, connection `lab-instruments`) | samples, tests, analytes, test analytes, intervals, QC runs; `lab_orders (id, species, priority)`, `lab_tests (id, code, discipline)` | batches, results |
| `lab_dispatch` | purposes 2 and 3's jobs | orders, tests, results, accounts, samples, the catalogue, callbacks, send-outs, notifications | callbacks, send-outs, sent-out events, the notifications' sent columns |
| `lab_reports` | the periodic reports | every table | nothing |

The purposes' roles (`lab_release`, `lab_watch`) are theirs (W3 item 0).
`lab-api` takes the account from the request and trusts it: the 120
practices share one credential (`lab_practices`), and rule 10 ("each
practice seeing only its own orders") holds by the stub asking for its
own, a known limit (W3 item 0).

## The classification

`personal`: a centre order's `animal_id`, `microchip`, `ueln`, `ear_tag`;
a practice's `patient_ref`, the `client_surname`; a custody handover's
`other_party`; a person called at a practice. Everything else is
`internal`, child rows included; no column is `customer-linked`. Free
text (clinical notes, a test's comment, a report) is `internal` and may
name the owner or the client (T24).

## The producers

The information system and middleware (`lis`), the order API
(`lab-api`) and the two stubs' fragments are chunk 12b's; this section
follows them.

## The rules

The thirteen of [policy.md](policy.md): release by a pathologist;
traceability; amendments as rows; quality control; unfit samples;
critical values within 60 minutes; notifiable diseases within the hour
(category A) or the day; chain of custody; residue screening an own
check; the practices' clients (the lab a processor); least data
(send-outs without identifiers, pgaudit `write, ddl, role` without
parameters); retention; billing.

## Growth

At intensity 1.0, on `lab`: about 1 300 new rows a day (700 results) and
400 updates, **about 55 rows an hour** on average, about 100 in a bench
hour on a weekday in bursts of a batch's results, a Sunday a quarter of
a weekday; about 0.3 MB a day with indexes, before bloat. The partners'
database: about 125 rows a day. Over an aging the lab's disk is never the
problem: its bursts, its holds and its round trips' backlogs are.

## The traps

Listed with the core's in
[clinic-traps.md](../../../specs/versions/v0.5/clinic-traps.md); those
biting the lab, by number:

- **Its node and configuration**: T2 (pgaudit parameters on), T4
  (`trust` from afar), T5 (`lab_app` superuser), T6
  (`pg_stat_statements` not preloaded), T7 (autovacuum off on
  `lab_order_tests`), T10 (no `monitoring` on `lab`), T11 (a scrape
  target missing).
- **Its data**: T13 (the core's mistyped chips reaching live orders
  through `lab.identity`), T20 (an interval for the wrong species, or two
  in force after the January review), T21 (results released from a batch
  whose QC failed), T22 (an amendment as an update), T23 (a wrong
  external code).
- **Its governance**: T24 (free text naming the owner), T29 (samples
  never disposed), T30 (the lab writing into `clinic`); the archive: T38
  (the lab's node left out).
- **Its round trips**: T39 to T53 and T85 (the centre's orders, the
  practices' deliveries, the send-outs: a request marked sent before the
  call returns, the priority dropped, a retry under a new `client_ref`,
  the results' watermark, a technical result read as final, a new
  `delivery_key` or `send_key` on each attempt, a send-out carrying an
  identifier, the answer endpoint matching on the external accession, no
  chase, the feed's cancellations ignored).
- **Its obligations**: T57, T58, T60 to T63 (category A treated as
  another; the critical calls' watch as `postgres`, filtering `critical`
  while the flags are `critical-low` and `critical-high`).
- **Its statements**: T75 to T77 (the feeder at bench hours, a charge at
  today's price, voids and discounts).
- **Performance and `lab-api`'s `db/` side**: T78 (the idempotency lookup
  on `client_ref` alone; the unique index is on the account and the
  reference), T80 (the feed with no index on `released_at`; the schema
  ships one), T83 (`lab.worklist` unbounded), T84.

## Loading

`gmctl load-data` runs `schema.sql` then the core's `keys.sql`, this
part's `keys.sql` and `load.sql` into `lab` on the `lab` node as
`postgres`, in one session; then each stub's `data.sql` (`xlab`,
`practices`, in name order) into `partners` on the partners' database
node, the two key files ahead of each; then the coherence check. The
load's sessions are unseen (D265). Measured on 2026-11-04 in a throwaway
container of `postgres:0.5.0` on armenelos (its data on a tmpfs), both
key files streamed by hand as `load-data` streams them:

| Run (`load_epoch` 2026-11-04T10:00Z) | Time | Size | Rows |
|---|---|---|---|
| the keys and `load.sql`, offset +2 | 71 s | 54 MB | 330 077 |
| the keys and `load.sql`, shift 0 | 64 to 70 s | 54 MB | 329 916 |
| each stub's `data.sql` (`xlab`, `practices`), offset +2 | 61 s, 59 s | | 8 send-outs; 39 orders, 12 deliveries |

Most of the time is the one pass's 17 000 `core_request` calls (about
45 s), paid by the load and by each stub. The coherence check's five
queries returned no row at shift 0 (the three reading the core against
its own load at shift 0, 116 s) and at +2 (the two reading `partners`).
