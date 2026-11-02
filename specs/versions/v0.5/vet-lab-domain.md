# v0.5 — `vet-lab`, the clinic's lab

Status: draft v1, at the procedure's step 2, the business sketch. Its
questions are the owner's to answer (O151); the data model (step 4)
waits for his answers. Step 3, the split, is not a part's: the lab's
boundary was set by the clinic's split (D279, D293, D294). Figures and
readings are (proposed) until he confirms them.

`vet-lab` is the biology lab of the centre a scenario deploys (D285),
the second domain through the [procedure](domain-procedure.md) (D235,
D260) and its first **part**: it requires `vet-core` (procedure 4),
refers to the core's keys by id with no foreign key, and prefixes its
tables and roles (`lab_`). The brief is the owner's, quoted in the
[version page](README.md#the-veterinary-clinic-d196) ("biology (lab,
blood analysis machinerie, etc)"; "external lab also come into play
regularily"); `vet-core`'s sketch is the model for this page
([vet-core-domain.md](vet-core-domain.md)).

## Settled before this page

Built on, not reopened:

- **One centre, its own lab, in scope** (D285, D293); the region's other
  veterinary clinics pay to use it.
- **Its outside customers** are the core's referring practices, by id
  (D294; [one-centre.md](one-centre.md) 2): a clinic's back end posts an
  order to the lab's API, an `api` node in the players' scope that only
  answers (D270), and gets an accession id; the sample comes by courier;
  the centre's own job posts the result to the clinic's callback. The
  region's clinics are one third-party stub (D293).
- **Billing them, inside `vet-lab`** (D294): prices, each outside
  order's charge; the monthly statements, a periodic report (D265), land
  in the back-office database, `office` (D300).
- **The external lab**, a third party, for the tests the centre's lab
  cannot run: the round trip where the centre asks (D268, D293).
- **Round trips** are a purpose kind of their own (D286): request,
  correlation key, expected answer, timeout, reactions; their faults are
  lost, duplicate, late and out-of-order callbacks, a wrong correlation
  id, a retry without an idempotency key (D268). A cascade's fix is
  judged end to end: for the lab, each new order gets its result
  released (D286).
- **In the core** (D279): the requests for analyses (and imaging), tied
  to the consultation, the animal and the requesting vet; the alerts.
  The core is the system of record for owners and animals, reached
  through its lookup API (`vet_lookup`), and results carry the animals'
  natural identifiers: microchip, UELN and passport, ear tag (D266),
  a dozen of the core's chips mistyped at load (D278).
- **The analysers** are machines: their readings and run logs are
  `vet-machinery`'s, their results reach `vet-lab` through its
  instrument batch uploads; heavy continuous data follows cold storage
  (D288, D296–D298).
- **pgaudit** is always available and turned on by the seed (D261); the
  lab's audit trail is one of the clinic's governance cases (D191).
- **The rules already ruled for the clinic** (D280): a result reaches the
  owner once a vet has validated it (rule 11); notifiable diseases
  reported by the vet who records the diagnosis (rule 7), from the core's
  coded diagnoses and their notifiable flag; EU law as written:
  Regulation (EU) 2019/6 and 2016/429.
- **Scale** on D263's three axes, fitting `vet-core` at one centre's
  scale (D295); "the data schema stays simple and the tables small"
  ([platform.md](../../platform.md)).

## The business sketch

The sketch covers the lab as its staff, its customers and the centre's
vets meet it: what comes in, what is done with it, what goes out, how
much and how often, under which rules. What belongs to the core or to
another part is named, and left to it.

### The business

The centre's clinical pathology lab: a bench of analysers (haematology,
biochemistry, blood gases and electrolytes, coagulation, urinalysis), a
microscopy and cytology bench, a microbiology bench (cultures and
sensitivities), a few serology and rapid tests, and a milk screening
for residues. It serves two kinds of customer:

- **the centre itself**: its vets order analyses in consultations and
  for hospitalised animals, around the clock for emergencies;
- **the region's veterinary practices**, who send samples by the lab's
  courier and pay per test, as a commercial reference lab's customers
  do.

What it cannot run (histopathology, most PCR, endocrinology, rare
serology) it sends to an **external reference lab**, a third party,
and reports the answer as its own, naming the lab that performed it.

A result is released once a vet, the lab's clinical pathologist, has
validated it; the centre's clinicians see an urgent result as soon as a
technician has checked it ([question 7](#questions-for-the-owner-o151)).

### Actors

| Actor | Who | With the lab |
|---|---|---|
| Requesting vet | the centre's vets and specialists (core `staff`) | order analyses in a consultation or a stay, read results, are called for a critical value |
| Nurse, technician of a section | core `staff` | collect and label samples, send them to the lab |
| Lab technician | core `staff`, `kind` `lab` | accession samples, reject unfit ones, run analysers and benches, run quality control, validate results technically, pack send-outs |
| Clinical pathologist | a vet of the centre, specialty clinical pathology | validates and releases results, writes comments and cytology reports, amends a released result |
| Lab manager | a technician | the test catalogue, the reference intervals, prices and the customers' accounts |
| A practice of the region | a third party (D285), a core referring practice by id (D294) | orders through the lab's API, receives results at its callback, receives a monthly statement |
| The courier | the story's | brings the region's samples, takes send-outs to the external lab; no system |
| External reference lab | a third party (D268) | receives the lab's send-outs, calls back with results |
| The authority | the veterinary services | receives notifications of listed diseases ([question 12](#questions-for-the-owner-o151)) |
| Owners | through `vet-portal` | see their animal's result once released (D280, rule 11) |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Ordering an analysis, inside the centre | the request, tied to consultation, animal and vet | core (`requests`); the lab's order from it ([question 2](#questions-for-the-owner-o151)) |
| Ordering, from a practice of the region | the order, the practice's own patient reference, the tests, the callback | `vet-lab`, through its order API |
| Collecting a sample | the container, the sample type, collected at, by | `vet-lab` (the sample), the collecting staff by id |
| Accessioning | the accession id, each sample's label, received at, fit or rejected and why | `vet-lab` |
| Routing | each test in house or sent out, by the catalogue | `vet-lab` |
| Running analysers | the instrument batch uploads carrying results; the readings and run logs themselves | `vet-lab` (batches, results); `vet-machinery` (readings, logs) |
| Bench work | cultures and their sensitivities, smears, cytology, rapid tests | `vet-lab` |
| Quality control | each control run, its level, pass or fail; results held on a failure | `vet-lab` |
| Flagging | each result against the species' reference interval: low, high, critical | `vet-lab` |
| Critical values | the call to the requesting vet: who, when, read back | `vet-lab` |
| Technical and clinical validation | who validated, when; the pathologist's comment | `vet-lab` |
| Release | to the centre's record, to the portal, to a practice's callback | `vet-lab`; the copies are purposes (step 7) |
| Amending a released result | the corrected result superseding the first, both kept, the reason | `vet-lab` |
| Sending out | the send-out, its correlation id, the external lab's answer | `vet-lab` (a round trip, D268) |
| Sample custody and storage | each handover and storage place, disposal | `vet-lab` ([question 10](#questions-for-the-owner-o151)) |
| Add-on tests | a test added later on a stored sample | `vet-lab` |
| Charging a practice | each outside test's charge at its price | `vet-lab` (D294) |
| Monthly statements | each practice's month | a periodic report into `office` (D265, D300) |
| Screening milk for residues | a treated animal's milk after its withdrawal end, negative or positive | `vet-lab` ([question 11](#questions-for-the-owner-o151)) |
| Notifying a listed disease | a positive for a notifiable test, the notification, a sample forwarded for confirmation | `vet-lab` ([question 12](#questions-for-the-owner-o151)); the vet's own in the core (rule 7) |
| Releasing to the owner | what was released, when | `vet-portal` |

### The variant, its scale and its tags (proposed)

The lab takes the clinic's one variant, `regional-franchise` (D263,
vet-core question 13), and adds no tag: `regulated` and `24/7` already
say what the lab needs. Where a part's own axes are written is
[question 15](#questions-for-the-owner-o151). The figures fit `vet-core`
at one centre's scale (D295): the core's history holds about 17 000
requests and about 55 a day live, analyses and imaging together, of
which the lab takes the analyses, about four in five.

**Population**, at load:

| What | How many |
|---|---|
| Analysers | 6 in house, `vet-machinery`'s machines by id: 2 haematology, 2 biochemistry, 1 blood gas and electrolytes, 1 coagulation |
| Test catalogue | about 150 orderable tests and 30 panels, over about 70 measured analytes, in six disciplines (haematology, biochemistry, urinalysis, cytology, microbiology, serology); about one in five sent out |
| Reference intervals | per analyte and species: dog, cat, horse, cattle, sheep, goat; adults only; about 400 rows |
| Lab staff | 8 technicians and 2 clinical pathologists, among the core's 85 |
| Customer accounts | 120 of the core's 400 referring practices |
| Prices | one list, every orderable test and panel, revised each 1 January |

**History**: one year, growing as the core grew (D279), each daily
volume ramping from about 60 % of today's rate to today's:

| What | Over the year |
|---|---|
| Orders (accessions) | about 14 000: 7 700 from the centre, 6 300 from the practices |
| Samples | about 18 000 |
| Tests ordered | about 24 000: 13 900 from the centre (the core's analysis requests), 10 000 from the practices |
| Results, one per analyte | about 190 000 |
| Instrument batch uploads | about 22 000 |
| Quality-control runs | about 7 000: every analyser once a day, two or three levels, and before a night run |
| Send-outs | about 2 000 |
| Outside charges | about 10 000 |
| Custody and storage events | about 54 000, three a sample |

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Tests from the centre | about 45 a day, around the clock, a third of the night's urgent |
| Orders from the practices | about 25 a day, Monday to Saturday, 1.6 tests each |
| Results | about 700 a day, one per analyte |
| Batch uploads | about 75 a day: each active analyser about once an hour on the bench's hours, one per urgent run at night |
| Quality-control runs | about 20 a day |
| Send-outs | about 7 a day, Monday to Friday |
| Critical values called | two or three a day |

About **0.35 million rows** at load and **1 200 a day** live, against
the core's 0.28 million and 570 ([vet-core](vet-core-domain.md#reference-sizes)):
the results, one per analyte, are the bulk. Far below cold storage's
threshold of about 50 000 rows a day (D296): nothing of the lab's ships;
the analysers' readings, which may, are `vet-machinery`'s (D298).

**Against a real lab.** The University of Missouri's veterinary
diagnostic lab recorded 27 357 clinical pathology accessions in 2025,
98 % from its own teaching hospital, about two tests each: some 75 a
day. The centre's lab, about 50 orders a day live and 1.7 tests each, is
of that order, a little smaller.

**A few stand for many** (D263): six analysers for a hospital lab's
bench, one external lab for its reference labs, 120 accounts and one
stub for the region's practices.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Around the clock | the centre's urgent tests; the on-call technician at night and on Sundays, urgent haematology, biochemistry and blood gases only | yes |
| The bench's hours, 07:00 to 21:00, Monday to Saturday | routine tests, the practices' samples, microbiology reading its plates | yes |
| Daily at the bench's opening, and before a night run | quality control on every analyser | yes |
| Twice a day, Monday to Saturday | the courier's rounds of the practices, samples accessioned in a wave after each | yes |
| The pathologist's rounds, about 11:00, 14:00 and 18:00 | clinical validation and release in batches; urgent ones at once | yes |
| Daily, Monday to Friday, 16:00 | send-outs packed for the external lab's courier | yes |
| Days | cultures, two to three days, their sensitivities two or three more; send-outs' answers, one to five days | yes, within the aging |
| Monthly | each practice's statement | **no**: history and daily feeders ([producer profiles](producer-profiles.md) 4) |
| Yearly | the price list's revision; the reference intervals' review | **no**: in the history |

Sample storage follows a reference lab's: whole blood and urine about
a week, serum two weeks, so an add-on test is possible within it.

### Regulations

What a regulated lab plausibly answers to, at the level a game needs;
the exact rules and periods are confirmed at step 5. Sources were read
on 2026-11-02 (research for this draft): ISO/IEC 17025:2017, the AAVLD
accreditation requirements (AC-1, 2018), Laboklin's 2024/25 compendium
(a German reference lab accredited to 17025), IDEXX UK's testing terms,
submission forms of TiHo Hannover and a French departmental lab, and the
EU texts named.

| Rule | Source | What the lab must hold |
|---|---|---|
| A result is released only once a vet has validated it | the clinic's rule (D280, rule 11); a report names who authorised it (AAVLD 5.10.2) | who validated, when; nothing released before |
| Every activity and every check of a result is recorded with who and when; an amended result keeps the original, what changed, why and who | ISO/IEC 17025, 7.5.1, 7.5.2, 7.8.8 | the batch and QC run behind a result, both validations, amendments as new rows referencing what they replace |
| A failed quality control halts the work and withholds its reports; earlier results are assessed | ISO/IEC 17025, 7.7.1, 7.10.1 | each control run and its outcome; the results it held |
| A sample's unfitness at receipt is recorded, the customer consulted | ISO/IEC 17025, 7.4.3 | each sample's condition, a test not performed and why |
| Listed diseases are notified: category A immediately, others as soon as practicable; EU law names "operators and other relevant natural or legal persons", national law names the labs (France: Code rural L201-7, "les vétérinaires et les laboratoires") | Regulation (EU) 2016/429, Art 18; national law | tests tied to a notifiable disease; the notification, its time and channel; the sample forwarded for confirmation ([question 12](#questions-for-the-owner-o151)) |
| Category A confirmation samples go to an official lab without delay | Delegated Regulation (EU) 2020/687, Art 3(2) | the forwarded sample, under custody, the official lab's reference |
| Official residue control is analysed by official labs only, designated and accredited | Regulation (EU) 2017/625, Art 37; Delegated Regulation (EU) 2022/1644, Implementing Regulation (EU) 2022/1646 | nothing: out of the lab's reach ([question 11](#questions-for-the-owner-o151)) |
| A dairy keeps milk with antibiotic residues off the market, by its own checks | Regulation (EC) 853/2004, Annex III, Section IX | a screening result, if the lab runs it (question 11) |
| The practices' clients are personal data | GDPR | a practice's order names its client; classed at step 5 |
| Lab records kept for a set period, then purged | no EU rule found; ISO/IEC 17025 8.4.2 and AAVLD 4.10.1.2 leave the period to the lab; IDEXX UK keeps reports a year | dates to purge by (a game value, step 5) |

## What the lab holds (proposed)

An outline, not yet the data model (step 4); every table prefixed
`lab_`, every core key by id with no foreign key (procedure 4):

- **Reference**: the test catalogue (tests, panels and their members,
  analytes, each test's discipline, sample type, turnaround, in house or
  sent out, the external lab's code for it), reference intervals per
  analyte and species, the price list with its revisions, the customer
  accounts (a core referring practice by id, the callback, a discount).
- **Orders and samples**: the order (accession), from the centre (a core
  request by id) or a practice (its own patient reference); its samples;
  the tests ordered on them; each sample's custody and storage events.
- **Work**: instrument batch uploads (a `vet-machinery` machine by id),
  quality-control runs, results (one per analyte, with its flag and the
  interval it was flagged against), critical-value calls, validations,
  amendments.
- **Round trips**: send-outs to the external lab, with the correlation
  id and the answer; results posted to the practices' callbacks, with
  their acknowledgements.
- **Billing**: the charges of outside tests; the statements are
  `office`'s (D300).

## Where the lab presses on the core

What the lab needs of `vet-core` against its current data model (step
4, D295). Two changes are proposed, in [question
3](#questions-for-the-owner-o151).

| The lab needs | The core today |
|---|---|
| the request, its test code, animal, consultation or stay, requesting vet | `requests` holds them (D279) |
| its urgency, which orders the bench | **nothing**: a `priority` on `requests` (proposed, question 3) |
| who decides a test goes out | `requests.external`, set by the vet: a second place for the lab's routing (proposed dropped, question 3) |
| the animal's species, sex, age, food-chain status, natural identifiers; the owner's name | `vet_lookup` reads them (D266), never contacts |
| the lab's staff and its clinical pathologists | `staff`, kind `lab`, and vets with their specialty |
| the practices it bills | `referring_practices`, by id (D294) |
| the disease a test detects, and whether it is notifiable | `diagnosis_codes` with its `notifiable` flag: the catalogue names a code |
| for a residue screening, the treatment's withdrawal end | `prescription_lines` and `administrations` hold it (D280, rule 6); the centre's order carries it, the lookup API does not reach it |
| the request's state once resulted | `requests` `resulted`, the lab's fact copied back by a purpose, a trap (two places for one fact, step 8) |

## Questions for the owner (O151)

Each with a proposed default; "agreed" accepts it.

1. **Where the lab's database sits.** Default: an instance of its own,
   `lab/lab`, as the lab's own information system would have, so its
   keys come from the core through the lookup API and orphans and
   mistyped chips are real (procedure 4, 5). By D299 it has no standby;
   proposed: its WAL and a nightly base backup go to the vault as the
   core's do (an extension of D299), so that a lab left out of the
   archive is a fault, not the design. The other reading: in the core's
   instance, riding the standby, the identity faults gone.
2. **How the centre's orders reach the lab.** Default: one order API for
   every customer. The centre's practice software posts each request to
   the lab's API, as the region's practices do, the centre an internal
   account with no charge; the lab answers with the accession id and
   the core's request becomes `sent`; the released result's state is
   copied back into `requests` by a purpose. The other reading: a
   purpose copying the core's new requests into the lab, no API on that
   side.
3. **Two changes to the core's `requests`.** Default: add a `priority`
   (`routine`, `urgent`), the vet's choice the bench orders its work by;
   drop `external`, since the lab routes a test in house or out by its
   catalogue, and a vet's flag beside it is the same fact twice. Both
   revise `vet-core`'s step 4.
4. **The practices' patients.** Default: an outside order's animal is
   the practice's patient, never a core animal: the order carries the
   practice's own patient reference, the species, sex and age, its
   microchip or ear tag when it has one, and the client's surname, as
   real submission forms do (Laboklin's carries the practice's patient
   number, TiHo Hannover's the holding number); the lab never matches it to the centre's
   animals, even on a shared chip. The core stays the system of record
   for the centre's own animals (D266).
5. **What one row is.** Default: an order (accession) per submission; a
   sample per container, each with its label; a test per orderable item
   (a panel counts as one test, billed once); a result per analyte, with
   its unit, value, flag and interval. Results per analyte are most of
   the lab's rows, and what reference intervals and critical values need.
   Each sample carries its condition at receipt (haemolysed, lipaemic,
   icteric, clotted, under-filled, too old, unlabelled), and a test it
   makes unfit is "not performed" with that reason, as real labs report.
6. **The test catalogue.** Default: about 150 tests and 30 panels over
   about 70 analytes, six disciplines; each test with its sample type,
   turnaround and whether it runs in house or goes out; about one in five
   sent out (histopathology, most PCR, endocrinology, toxicology), about
   8 % of the tests ordered; each send-out test mapped to the external
   lab's own code, as practice software maps its tests and species to a
   lab's before it may order (a test mapped to the wrong code: a trap,
   step 8).
7. **Validation and release.** Default: two steps. A technician
   validates technically (quality control passed, the result plausible);
   the clinical pathologist validates clinically and releases, at their
   rounds, urgent results at once. Inside the centre a clinician sees a
   technically validated urgent result at once, marked unvalidated; the
   portal and a practice's callback get a result only once released
   (D280, rule 11). Tests are finalised one by one, the order once all
   are; until then its report is interim, listing what is done and what
   is pending (as AAVLD 5.10.8 asks), so a practice receives a culture's
   result days after its haematology. A released result is never
   changed: an amendment is a new result referencing the one it
   replaces, the first kept with what changed, why and who (ISO/IEC
   17025, 7.5.2, 7.8.8). No rule found requires a pathologist's
   signature on routine results; the vet's validation is the clinic's
   rule.
8. **Quality control.** Default: every analyser once a day at the
   bench's opening and before a night run, two control levels for
   biochemistry and three for haematology, as a 2017 survey of
   veterinary labs found most do; a run failing its rules holds that
   analyser's results since its last good run until a passing rerun
   (ISO/IEC 17025, 7.10.1); the lab records each run, its level, the
   rule broken and the action, not each control's analytes; external
   quality assessment left out. Traps (step 8): a result released from a
   run whose control failed; a failed control simply rerun until it
   passes, the survey's commonest bad habit.
9. **Reference intervals.** Default: per analyte and species, adults
   only, each with a low and high limit and critical limits where they
   matter (potassium, glucose, haematocrit, platelets); a dated set per
   analyser, as labs publish theirs ("as of December 2023"), so a result
   keeps the interval it was flagged against; a critical value phoned to
   the requesting vet (or the practice) within the hour, read back, the
   call recorded with who took it. No veterinary standard fixes critical
   limits; the lab's own list is a game value.
10. **Custody and storage.** Default: every sample's movements in one
    event log (received, stored, moved, sent out, disposed); stored for
    add-on tests about a week (whole blood, urine) or two (serum), then
    disposed; an add-on test ordered against the first report within
    that time, billed to whoever paid for it. A sample with legal weight
    (a sample forwarded for official confirmation, a welfare, legal or
    insurance case) adds a chain of custody: each handover's "relinquished
    by" and "received by", time, condition and seal number, as a
    forensic submission form records. Equine anti-doping stays out: only
    the FEI's approved labs may analyse its samples.
11. **Residue tests.** Official residue control is not the lab's: its
    samples are analysed by official labs, designated and accredited
    (Regulation (EU) 2017/625, Art 37). Default: the lab runs one
    screening test, a microbial inhibitor test (Delvotest's kind) on a
    treated cow's or goat's milk at the keeper's request once the
    withdrawal period has ended, before the milk goes back into the tank;
    a qualitative negative or positive with no legal standing, never
    reported to the authority; on a positive the keeper holds the milk
    back. The request names the treatment's withdrawal end, which the
    core holds (D280, rule 6).
12. **Notifiable diseases.** EU law puts the duty on "operators and
    other relevant natural or legal persons" (2016/429, Art 18); national
    law names the labs (France: Code rural L201-7). Default: the lab
    notifies the authority itself, at once, on a positive or suspect
    result for a test tied to a notifiable disease, for every customer,
    the centre's vets and the region's practices alike, and calls the
    requesting vet as for a critical value; the vet records the diagnosis
    in the core and notifies too (rule 7), the authority receiving two
    notifications for one case, as it would. For a category A disease the
    lab forwards a sample to the official lab under custody (question
    10) and records the official lab's reference; the confirmation goes
    to the authority, not back to the lab, so this is an outbound flow,
    not a round trip. The notification is a pushed obligation (v0.4's
    P5), a purpose fitting `vet-lab` (step 7).
13. **Billing the practices.** Default, after Laboklin's and IDEXX's
    terms: one price list, revised each 1 January, a price per test and
    per panel; a handling fee per order; an urgent surcharge of half the
    price; each outside test charged at the price of the day it was
    ordered, billable once released, voided if cancelled or the sample
    unfit; a send-out re-billed at the lab's own price; the month's
    charges gathered into the practice's statement in `office` on the
    1st (D300), with a volume discount by the month's total (Laboklin's
    3 to 15 %); no payments (D294), and never an owner billed, though
    real labs may at a vet's request. A charge at today's price instead
    of the order's day is a trap (step 8).
14. **Scale and hours.** Default: the figures in "The variant" and
    "Cadences": about 85 tests a day, 700 results; a year of history,
    about 0.35 million rows; the bench open 07:00 to 21:00 Monday to
    Saturday, an on-call technician for the centre's urgent tests at
    night and on Sundays; the courier twice a day; the pathologist's
    three rounds.
15. **A part's scale, in the format.** Default: a part writes its own
    axes in a manifest of the core variant's name,
    `vet-lab/variants/regional-franchise.yaml`, which the merge's
    provenance (`vet-lab@regional-franchise`, D264) already assumes; the
    loader checks the core's variant names it. Feeds O111.

## Next

Once these are answered: the data model (step 4), with the core's
changes from question 3 written into
[vet-core-domain.md](vet-core-domain.md); then classification and
governance (step 5), where the lab's audit trail, its retention and the
practices' clients' data are ruled.
