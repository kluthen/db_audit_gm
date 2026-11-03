# v0.5 — `vet-lab`, the clinic's lab

Status: draft v6, ready for review: the draft document of procedure
step 9, for the owner to approve with v0.5's master spec; not approved.
Steps 2 to 8 are done: the business sketch ruled, every default
accepted (D301, closing O151); step 3 not a part's, the lab's boundary
set by the clinic's split (D279, D293, D294); the data model and the
default policy ruled (D302, closing O152), `lab_app`'s grants amended
(D304); the producer profiles ruled with `vet-core`'s (D303, D304),
`lab-api`'s results feed and the external lab's `resend` added with the
purposes (D306); the purposes ruled (D306, D307) in
[clinic-purposes.md](clinic-purposes.md); the traps listed (step 8, no
owner checkpoint, D309) in [clinic-traps.md](clinic-traps.md). The
centre's sent requests are cancelled by the lab only, the feed carrying
the cancellation (D315). On 2026-11-03 the four remaining parts folded
in (D317–D325): the analysers are `vet-machinery`'s machines 1–6 by its
mapping (D319), and `vet-portal-release` reads the lab's released
results as `lab_release` (D320). Open: the format's finalisation (O111,
at consolidation).

`vet-lab` is the biology lab of the centre a scenario deploys (D285),
the second domain through the [procedure](domain-procedure.md) (D235,
D260) and its first **part**: it requires `vet-core` (procedure 4),
refers to the core's keys by id with no foreign key, and prefixes its
tables and roles (`lab_`). The brief is the owner's, quoted in the
[version page](README.md#the-veterinary-clinic-d196) ("biology (lab,
blood analysis machinerie, etc)"; "external lab also come into play
regularily"); `vet-core`'s sketch is the model for this page
([vet-core-domain.md](vet-core-domain.md)).

## The draft at a glance (step 9)

Where each item of the part's folder, `domains/vet-lab/`, is stated on
this page or beside it (procedure 1, 3 and 4; the format is finalised
in the master spec, O111):

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-lab`, `requires: [vet-core]`, its tables and roles prefixed `lab_`, the purposes that fit | [What the lab holds](#what-the-lab-holds); [Purposes that fit](#purposes-that-fit-step-7) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest of the core variant's name (answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/schema.sql`: tables, keys, states, roles and grants, on the `lab` node (answer 1) | [The data model](#the-data-model-step-4) |
| `data/load.sql`: the year's history and the state at T0, computing the core's ids by its functions | [Deterministic key ranges](#deterministic-key-ranges-d249-d266), [The history before T0](#the-history-before-t0-d279), [Loading](#loading) |
| `data/classification.yaml`: every column classed | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The rules](#the-rules-as-the-owner-confirmed-them-d302) |
| `producers/`: the information system and middleware (`lis`), the order API (`producers/api/lab-api/`), the practices' and the external lab's stubs (`producers/partners/<partner>/`, D303) | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; the traps in [clinic-traps.md](clinic-traps.md); [Loading](#loading) |

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
  (D288, D296–D298). `vet-machinery` numbers them (D319): 1–2
  haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6
  coagulation; the telemetry and events are that part's, with no
  row-level match to `lab_batches` (a fault leaning on one brings its
  own material).
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
technician has checked it ([answer 7](#the-owners-answers-d301)).

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
| The authority | the veterinary services | receives notifications of listed diseases ([answer 12](#the-owners-answers-d301)) |
| Owners | through `vet-portal` | see their animal's result once released (D280, rule 11) |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Ordering an analysis, inside the centre | the request, tied to consultation, animal and vet | core (`requests`); the lab's order from it ([answer 2](#the-owners-answers-d301)) |
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
| Sample custody and storage | each handover and storage place, disposal | `vet-lab` ([answer 10](#the-owners-answers-d301)) |
| Add-on tests | a test added later on a stored sample | `vet-lab` |
| Charging a practice | each outside test's charge at its price | `vet-lab` (D294) |
| Monthly statements | each practice's month | a periodic report into `office` (D265, D300) |
| Screening milk for residues | a treated animal's milk after its withdrawal end, negative or positive | `vet-lab` ([answer 11](#the-owners-answers-d301)) |
| Notifying a listed disease | a positive for a notifiable test, the notification, a sample forwarded for confirmation | `vet-lab` ([answer 12](#the-owners-answers-d301)); the vet's own in the core (rule 7) |
| Releasing to the owner | what was released, when | `vet-portal` |

### The variant, its scale and its tags

The lab takes the clinic's one variant, `regional-franchise` (D263,
vet-core question 13), and adds no tag: `regulated` and `24/7` already
say what the lab needs. Where a part's own axes are written is
[answer 15](#the-owners-answers-d301). The figures fit `vet-core`
at one centre's scale (D295): the core's history holds about 17 000
requests and about 55 a day live, analyses and imaging together, of
which the lab takes the analyses, about four in five.

**Population**, at load:

| What | How many |
|---|---|
| Analysers | 6 in house, `vet-machinery`'s machines by id: 2 haematology, 2 biochemistry, 1 blood gas and electrolytes, 1 coagulation; urinalysis on the bench |
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

About **0.36 million rows** at load and **1 300 a day** live (step 4's count; the sketch first gave 0.35 and 1 200), against
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
| Listed diseases are notified: category A immediately, others as soon as practicable; EU law puts the duty on "operators and other relevant natural or legal persons", and national law requires labs to notify | Regulation (EU) 2016/429, Art 18; national law (the practice is France's, whose Code rural, L201-7, names vets and labs alike) | tests tied to a notifiable disease; the notification, its time and channel; the sample forwarded for confirmation ([answer 12](#the-owners-answers-d301)) |
| Category A confirmation samples go to an official lab without delay | Delegated Regulation (EU) 2020/687, Art 3(2) | the forwarded sample, under custody, the official lab's reference |
| Official residue control is analysed by official labs only, designated and accredited | Regulation (EU) 2017/625, Art 37; Delegated Regulation (EU) 2022/1644, Implementing Regulation (EU) 2022/1646 | nothing: out of the lab's reach ([answer 11](#the-owners-answers-d301)) |
| A dairy keeps milk with antibiotic residues off the market, by its own checks | Regulation (EC) 853/2004, Annex III, Section IX | a screening result ([answer 11](#the-owners-answers-d301)) |
| The practices' clients are personal data | GDPR | a practice's order names its client; classed at step 5 |
| Lab records kept for a set period, then purged | no EU rule found; ISO/IEC 17025 8.4.2 and AAVLD 4.10.1.2 leave the period to the lab; IDEXX UK keeps reports a year | dates to purge by (a game value, step 5) |

## What the lab holds

Within the procedure's section 4: every table prefixed `lab_`, every
core key by id with no foreign key, the lab on a `postgres` node of its
own (answer 1):

- **Reference**: the test catalogue (tests and panels, the analytes
  each reports, each test's discipline, sample type, turnaround, in
  house or sent out, the external lab's code for it), reference
  intervals per analyte and species, the price list with its revisions,
  the customer accounts (a core referring practice by id, the callback).
- **Orders and samples**: the order (accession), from the centre (the
  core's requests by id) or a practice (its own patient reference); its
  samples; the tests ordered on them; each sample's custody and storage
  events.
- **Work**: instrument batch uploads (a `vet-machinery` machine by id),
  quality-control runs, results (one per analyte, with its flag and the
  interval it was flagged against), critical-value calls, validations,
  amendments, notifications.
- **Round trips**: send-outs to the external lab, with the correlation
  key and the answer; results posted to the practices' callbacks, with
  their acknowledgements.
- **Billing**: the charges of outside orders; the statements are
  `office`'s (D300).

## Where the lab presses on the core

What the lab needs of `vet-core`, with answer 3's revision applied to
the core's step 4 (D301).

| The lab needs | The core |
|---|---|
| the request, its test code, animal, consultation or stay, requesting vet | `requests` holds them (D279) |
| its urgency, which orders the bench | `requests.priority`, `routine` or `urgent` (D301) |
| who decides a test goes out | the lab, by its catalogue: `requests.external` dropped (D301) |
| the animal's species, sex, age, food-chain status, natural identifiers; the owner's name | `vet_lookup` reads them (D266), never contacts |
| the lab's staff and its clinical pathologists | `staff`, kind `lab`, and vets with their specialty; their ids in a documented range, 71–80 (D302) |
| the practices it bills | `referring_practices`, by id (D294) |
| the disease a test detects, and whether it is notifiable | `diagnosis_codes` with its `notifiable` flag: the catalogue names a code |
| for a residue screening, the treatment's withdrawal end | `prescription_lines` and `administrations` hold it (D280, rule 6); the centre's order carries it, the lookup API does not reach it |
| the request's state once resulted | `requests` `resulted`, the lab's fact copied back by a purpose, a trap (two places for one fact, step 8) |
| a history it can refer to without reading the core | each request's kind, test, priority, consultation, animal and time a function of its id (D302) |

## The owner's answers (D301)

The questions the sketch left open (O151), each with the default the
owner accepted on 2026-11-02, answer 1 in his words: "give a separate
node for the lab (not just a separate database)".

1. **Where the lab's database sits.** Answer: on a **separate
   `postgres` node**, `lab`, its database `lab` (`at: lab/lab`), never a
   database on the core's instance: the lab's own information system,
   its keys coming from the core through the lookup API, so orphans and
   mistyped chips are real (procedure 4, 5). It has no standby (D299);
   its WAL and a nightly base backup go to the vault as the core's do,
   which extends D299 ([replication.md](replication.md) 2), so a lab
   left out of the archive is a fault, not the design.
2. **How the centre's orders reach the lab.** Answer: one order API for
   every customer. The centre's practice software posts each request to
   the lab's API, as the region's practices do, the centre an internal
   account with no charge; the lab answers with the accession id and
   the core's request becomes `sent`; the released result's state is
   copied back into `requests` by a purpose.
3. **Two changes to the core's `requests`.** Answer: a `priority`
   (`routine`, `urgent`), the vet's choice the bench orders its work by;
   `external` dropped, since the lab routes a test in house or out by
   its catalogue. Applied to `vet-core`'s step 4
   ([vet-core-domain.md](vet-core-domain.md#entities)).
4. **The practices' patients.** Answer: an outside order's animal is
   the practice's patient, never a core animal: the order carries the
   practice's own patient reference, the species, sex and age, its
   microchip or ear tag when it has one, and the client's surname, as
   real submission forms do (Laboklin's carries the practice's patient
   number, TiHo Hannover's the holding number); the lab never matches it
   to the centre's animals, even on a shared chip. The core stays the
   system of record for the centre's own animals (D266).
5. **What one row is.** Answer: an order (accession) per submission; a
   sample per container, each with its label; a test per orderable item
   (a panel counts as one test, billed once); a result per analyte, with
   its value, flag and interval. Each sample carries its condition at
   receipt (haemolysed, lipaemic, icteric, clotted, under-filled, too
   old, unlabelled), and a test it makes unfit is "not performed" with
   that reason.
6. **The test catalogue.** Answer: about 150 tests and 30 panels over
   about 70 analytes; each test with its sample type, turnaround and
   whether it runs in house or goes out; about one in five sent out
   (histopathology, most PCR, endocrinology, toxicology), about 8 % of
   the tests ordered; each send-out test mapped to the external lab's
   own code (a test mapped to the wrong code: a trap, step 8).
7. **Validation and release.** Answer: two steps. A technician
   validates technically (quality control passed, the result
   plausible); the clinical pathologist validates clinically and
   releases, at their rounds, urgent results at once. Inside the centre
   a clinician sees a technically validated urgent result at once,
   marked unvalidated; the portal and a practice's callback get a result
   only once released (D280, rule 11). Tests are finalised one by one,
   the order once all are; until then its report is interim, listing
   what is done and what is pending. A released result is never
   changed: an amendment is a new result referencing the one it
   replaces, the first kept with what changed, why and who.
8. **Quality control.** Answer: every analyser once a day at the
   bench's opening and before a night run, two control levels for
   biochemistry and three for haematology; a failed run holds that
   analyser's results since its last good run until a passing rerun;
   each run recorded with its level, the rule broken and the action, not
   each control's analytes; external quality assessment left out. Traps:
   a result released from a run whose control failed; a failed control
   simply rerun until it passes.
9. **Reference intervals.** Answer: per analyte and species, adults
   only, with low and high limits and critical limits where they matter
   (potassium, glucose, haematocrit, platelets); dated, so a result
   keeps the interval it was flagged against; a critical value phoned to
   the requesting vet (or the practice) within the hour, read back, the
   call recorded; the critical limits a game value.
10. **Custody and storage.** Answer: every sample's movements in one
    event log; stored about a week (whole blood, urine) or two (serum)
    for add-on tests, which are ordered against the first report and
    billed to whoever paid for it; a sample with legal weight (forwarded
    for official confirmation, a welfare, legal or insurance case) adds
    a chain of custody, each handover's both parties, time, condition
    and seal number. No equine anti-doping.
11. **Residue tests.** Answer: official residue control is the official
    labs' (Regulation (EU) 2017/625, Art 37). The lab runs one screening
    test, a microbial inhibitor test on a treated cow's or goat's milk at
    the keeper's request once the withdrawal period has ended: a
    qualitative negative or positive with no legal standing, never
    reported to the authority; the request names the treatment's
    withdrawal end, which the core holds (D280, rule 6).
12. **Notifiable diseases.** Answer: national law requires labs to
    notify, beside the "operators and other relevant natural or legal
    persons" of Regulation (EU) 2016/429, Art 18. The lab notifies the
    authority itself, at once, on a positive or suspect result for a test
    tied to a notifiable disease, for every customer, the centre's vets
    and the region's practices alike, and calls the requesting vet as for
    a critical value; the vet records the diagnosis in the core and
    notifies too (rule 7). For a category A disease the lab forwards a
    sample to the official lab under custody and records the official
    lab's reference; the confirmation goes to the authority, so this is
    an outbound flow, not a round trip. The notification is a pushed
    obligation (v0.4's P5), a purpose fitting `vet-lab` (step 7). Source
    note: the lab's duty is modelled on France's Code rural, L201-7,
    which names vets and labs alike.
13. **Billing the practices.** Answer: one price list, revised each 1
    January, a price per test and per panel; a handling fee per order;
    an urgent surcharge of half the price; each outside test charged at
    the price of the day it was ordered, billable once released, voided
    if cancelled or the sample unfit; a send-out re-billed at the lab's
    own price; the month's charges gathered into the practice's
    statement in `office` on the 1st (D300), with a volume discount of 3
    to 15 % by the month's total; no payments (D294), never an owner
    billed. A charge at today's price instead of the order's day is a
    trap (step 8).
14. **Scale and hours.** Answer: the figures in "The variant" and
    "Cadences": about 85 tests a day, 700 results; a year of history,
    about 0.35 million rows (0.36 once step 4 counted every table); the
    bench open 07:00 to 21:00 Monday to Saturday, an on-call technician
    for the centre's urgent tests at night and on Sundays; the courier
    twice a day; the pathologist's three rounds.
15. **A part's scale, in the format.** Answer: a part writes its own
    axes in a manifest of the core variant's name,
    `vet-lab/variants/regional-franchise.yaml`, as the merge's
    provenance (`vet-lab@regional-franchise`, D264) assumes; the loader
    checks that the core's variant names the part. Feeds O111
    ([procedure](domain-procedure.md) 9).

## The data model (step 4)

On the answers of D301. The `lab` database, on the `lab` node, holds
`vet-lab` only, written in the shop's and the core's manner: the tables
in `public`, prefixed `lab_` (procedure 4), integer keys `GENERATED BY
DEFAULT AS IDENTITY`, explicit ids at load and each sequence set after
its range. Core keys are plain integer columns with no foreign key:
`animal_id`, `request_id`, `consultation_id`, `practice_id`, the staff
ids; `vet-machinery`'s machines likewise (`machine_id`). Every value is
generated: patient references and surnames from short lists,
identifiers by the core's functions of the animal's id.

**Growth through the year** (D279), as the core's: every daily volume of
the history (orders, samples, tests, results, batches, send-outs,
callbacks, charges) ramps from about 60 % of today's live rate a year
ago to today's; reference tables, accounts and quality control do not
grow. The price list changes on 1 January, inside the year.

### Entities

**Reference**

| Table | Key, main columns |
|---|---|
| `lab_settings` | one row: the customer's zone and offset, as the core's `business_settings` (a separate node keeps its own copy); the handling fee, the urgent surcharge (50 %), the critical call's limit (60 minutes) |
| `lab_analytes` | `id`; code, name, unit, `kind` (`numeric`, `text`: an organism, a sensitivity, a positive or negative, a report) |
| `lab_tests` | `id`; code, name, `is_panel`, `discipline` (`haematology`, `biochemistry`, `blood-gas`, `coagulation`, `urinalysis`, `cytology`, `microbiology`, `serology`, `residue`, `histopathology`, `molecular`, `endocrinology`, `toxicology`), `sample_type` (`edta-blood`, `serum`, `citrate-plasma`, `heparin-blood`, `urine`, `milk`, `swab`, `tissue`, `faeces`), turnaround hours, `performed` (`in-house`, `sent-out`), `external_code` (the external lab's code, sent-out tests only), `diagnosis_code` (the core's, when the test detects a listed disease) |
| `lab_test_analytes` | (`test_id`, `analyte_id`); position: what each test or panel reports |
| `lab_reference_intervals` | `id`; analyte, `species` (`dog`, `cat`, `horse`, `cattle`, `sheep`, `goat`), low, high, critical low, critical high, valid from, valid until (open while in force) |
| `lab_prices` | `id`; test, price (euros), valid from, valid until |
| `lab_accounts` | `id`; `kind` (`internal`, `practice`), `practice_id` (the core's referring practice; none for the centre), callback URL, opened on, closed on |

**Orders and samples**

| Table | Key, main columns |
|---|---|
| `lab_orders` | `id` (the accession); account, `client_ref` (the customer's own order id, unique per account: the idempotency key), `priority` (`routine`, `urgent`); the centre's: `animal_id`, `consultation_id`, requesting staff; a practice's: `patient_ref`, `client_surname`; both: species, sex, born on (or an age), `microchip`, `ueln`, `ear_tag` as given, clinical notes, `withdrawal_ends_on` (a residue screening's); ordered at, received at, completed at, cancelled at |
| `lab_samples` | `id`; order, `label` (the tube's barcode, unique), sample type, collected at, collected by (staff, the centre's), received at, `condition` (`fit`, `haemolysed`, `lipaemic`, `icteric`, `clotted`, `under-filled`, `too-old`, `unlabelled`), `custody` (a chain of custody applies), keep until, disposed at |
| `lab_order_tests` | `id`; order, sample, test, `request_id` (the core's, the centre's orders), `routing` (`in-house`, `sent-out`), `add_on`, status, not performed because, technically validated by and at, released by and at (a clinical pathologist), comment |
| `lab_sample_events` | `id`; sample, `kind` (`received`, `stored`, `moved`, `sent-out`, `forwarded`, `disposed`), at, by (staff), place; for a chain of custody: `other_party` (by name), condition, seal number |

**Work**

| Table | Key, main columns |
|---|---|
| `lab_qc_runs` | `id`; `machine_id`, level (1 to 3), control lot, run at, by, `outcome` (`pass`, `fail`), rule broken (`1-3s`, `2-2s`, `R-4s`, `4-1s`, `10-x`), `action` (`none`, `rerun`, `recalibrated`, `results-held`) |
| `lab_batches` | `id`; `machine_id`, the QC run in force, started at, uploaded at, results |
| `lab_results` | `id`; order test, analyte, batch (none for bench work and send-outs), numeric value or text value, `flag` (`normal`, `low`, `high`, `critical-low`, `critical-high`; none for text), the interval it was flagged against, measured at; `supersedes_id`, amended by, amended at, why: an amendment is a new row, the row it supersedes kept |
| `lab_critical_calls` | `id`; result, called at, called by, `called_staff_id` (the requesting vet) or `called_person` (a person at the practice, by name), read back |
| `lab_notifications` | `id`; order test, the core's diagnosis code, `category` (`A`, `other`), suspected at, notified at, channel, the authority's reference; for category A the sample forwarded and the official lab's reference |

**Round trips and billing**

| Table | Key, main columns |
|---|---|
| `lab_send_outs` | `id`; order test, `send_key` (a UUID: the correlation key, sent again on a retry), the external lab's accession, packed at, sent at, accepted at, answered at, due by, `status` |
| `lab_callbacks` | `id`; order, `kind` (`interim`, `final`, `amended`), `delivery_key` (the practice's idempotency key), attempt, posted at, HTTP status, acknowledged at |
| `lab_charges` | `id`; account, order, order test (none for the handling fee), `kind` (`test`, `handling`, `urgent`), price, amount, billable on (the release's date), voided at |

### Lifecycle states

| Entity | States |
|---|---|
| Order | `ordered` → `received` → `completed` (every test final), or `cancelled`; its report interim until completed |
| Sample | expected → received, fit or not → stored → `disposed`; or sent out, or forwarded under custody |
| Order test | `ordered` → `in-progress` (or `sent-out`) → `technical` → `released`; or `not-performed` (an unfit sample), `cancelled` |
| Result | current → superseded by an amendment, both kept |
| QC run | `pass` or `fail`; a batch after a failed run is held until a passing one |
| Send-out | `packed` → `sent` → `accepted` → `resulted`; on its timeout resent with the same `send_key` |
| Callback | `pending` → `acknowledged`, or failed and retried with the same `delivery_key` |
| Charge | pending → billable on release → `void` on a cancellation or an unfit sample |

### Deterministic key ranges (D249, D266)

The load writes these ids, each sequence resuming after its range
(D276), and refers to the core's keys by its documented ranges
([vet-core](vet-core-domain.md#deterministic-key-ranges-d249-d266)).

| Key | Range | Layout |
|---|---|---|
| `lab_analytes.id` | 1–70 | |
| `lab_tests.id` | 1–180 | 1–150 tests, 151–180 panels; about 36 sent out |
| `lab_reference_intervals.id` | 1–460 | 1–60 the intervals the January review replaced, 61–460 those in force |
| `lab_prices.id` | 1–360 | test `t`'s price `t` until 1 January, `180 + t` from it |
| `lab_accounts.id` | 1–121 | 1 the centre (`internal`); account `a` from 2 to 121 is referring practice `3 × (a − 1)` (3, 6, … 360) |
| History | `lab_orders` 1–14 000, `lab_samples` 1–18 000, `lab_order_tests` 1–24 000, `lab_results` 1–192 000, the others as loaded | in time order over the year |
| Core keys used | `request_id` among the core's analysis requests (1–17 000); `animal_id` 1–17 000; lab staff 71–80 | as the core documents them (D302) |
| Machines | `machine_id` 1–6, the lab's analysers | `vet-machinery`'s range (D302, D319): 1–2 haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6 coagulation; the on-call analysers at night 1, 3 and 5 |

**Two constraints on the core's load (D302).** So that the lab's
history refers to the core's without reading it (procedure 4), applied
in [vet-core](vet-core-domain.md#deterministic-key-ranges-d249-d266):

- **Requests as functions of their id.** Each core request's kind
  (about one in five imaging), test code, priority, consultation,
  animal and time are computed from its id, as the core's other history
  is generated, and documented in the core's GM notes; the lab's load
  computes the same, grouping a consultation's analysis requests into
  one order (1.8 tests each on average).
- **Lab staff in a range**: staff 71–78 the lab's technicians, 79–80
  its clinical pathologists (vets, specialty clinical pathology).

The lab's orders copy each animal's natural identifiers by the core's
functions, so the core's dozen mistyped chips (D278) meet results whose
chip matches no animal, as designed.

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret.

| Role | Who | Reads | Writes |
|---|---|---|---|
| `lab` | owns everything; no login | | |
| `lab_app` | the lab's information system, its staff's screens (a producer node, D276) | every table | orders, samples, order tests, sample events, results (bench work, amendments), critical calls, notifications, QC runs, charges (D304, amending D302: charged at accession, billable at release, voided on a cancellation or an unfit sample); never the reference tables |
| `lab_api` | the lab's order API, an `api` node (D267, D270) | the catalogue, accounts, orders and their tests and results (status) | orders, samples, order tests (intake); send-outs' answers and their results, from the external lab's callback |
| `lab_instruments` | the analysers' middleware uploading batches | samples, order tests, analytes, test analytes, reference intervals, QC runs | batches, results |
| `lab_dispatch` | the centre's jobs posting results to the practices and send-outs to the external lab | orders, order tests, results, accounts, samples | callbacks, send-outs, sample events (`sent-out`) |
| `lab_reports` | the periodic reports and statements, writing to `office` (D300) | every table | nothing |

The purposes' roles (the results' return to the core, the
notifications, the statements) come with step 7, drafted in
[clinic-purposes.md](clinic-purposes.md#the-roles-the-purposes-add);
the release to the portal adds `lab_release`, read-only on the centre's
released results of account 1 (`lab_order_tests.released_at`,
amendments by `lab_results.supersedes_id`), on `interfaces` (D320); the
lab's tables are unchanged.

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| Reference (settings, analytes, tests and their analytes, intervals, prices, accounts) | about 2 100 | none |
| Orders, samples | 14 000, 18 000 | 50, 65 |
| Tests ordered | 24 000 | 85 |
| Results | about 192 000, a thousand of them amendments | about 700 |
| Sample events | about 54 000 | about 200 |
| Batches, QC runs | 22 000, 7 000 | 75, 20 |
| Send-outs, callbacks | 2 000, about 10 000 | 7, 40 |
| Critical calls, notifications | about 900, about 30 | 2 or 3; a few a month |
| Charges | about 17 000 | about 60 |
| **Total** | **about 0.36 million rows** | **about 1 300 rows** |

Under the shop's 1.3 million rows and close to the core's 0.28 million,
on a node of its own: within "the data schema stays simple and the
tables small" and the brick's reservation (0.5 CPU, 512M, 2.25G of
disk); load time and size measured at the build. Far under cold
storage's threshold (D296): nothing of the lab's ships.

### Plausibility points (step 4, ruled, D302)

Offered to the owner and confirmed as drafted on 2026-11-02 ("agreed",
D302):

1. **The lab outweighs the core**: 0.36 million rows against 0.28, the
   results, one per analyte, more than half of it.
2. **One external lab**, so its code is a column of `lab_tests`, not a
   mapping table; a second external lab would make it one.
3. **Validations on the test row** (technically validated by and at,
   released by and at), not a table of their own; amendments as result
   rows superseding the first.
4. **Notifications a table of the lab's**, the record the pushed
   obligation's purpose reads (step 7).
5. **Two constraints on the core's load**: requests as functions of
   their id, lab staff 71–80 (above), applied in
   [vet-core](vet-core-domain.md#deterministic-key-ranges-d249-d266).
6. **The analysers are `vet-machinery`'s machines 1–6**, numbered by
   that part (D319): 1–2 haematology, 3–4 biochemistry, 5 blood gas,
   6 coagulation.
7. **Accounts on every third practice**, 3 to 360: 120 of the core's 400.
8. **Five application roles**: the information system, the order API,
   the analysers' middleware, the dispatch jobs, the reports.

## Classification and governance (step 5)

### Classification

v0.4's three classes, applied as `vet-core` applies them (D280): keys
`<table>.<column>`, the scenario's copy adding the database (procedure
6, item 2). The table gives the personal and customer-linked columns;
every other column of every table is `internal`.

Readings for the lab:

- **The centre's orders follow the core.** A natural identifier
  (microchip, UELN, ear tag) is a direct identifier, so personal; the
  core animal's id stored beside it is personal too.
- **A practice's patient leads to its client.** The practice's patient
  reference is the practice's key to its client's record, a direct
  identifier as a chip is, so personal; the client's surname is
  personal.
- **A practice is a business**: its id, account and callback are
  `internal`, as the core's referring practices are.
- **Child rows are internal**: a result, a test, a sample refers to its
  order and carries no identifier, so is `internal`, as the core's
  diagnoses are; a core `request_id` or `consultation_id` is the
  clinic's work record, `internal`. Staff ids are `internal`, as in the
  core.
- **People named in the lab's records**: the other party of a custody
  handover and a person called at a practice are personal.

| Table | `personal` | `customer-linked` |
|---|---|---|
| `lab_orders` | `animal_id`, `microchip`, `ueln`, `ear_tag`, `patient_ref`, `client_surname` | |
| `lab_sample_events` | `other_party` | |
| `lab_critical_calls` | `called_person` | |

No column is `customer-linked`: every order holding an animal's id
holds an identifier beside it. Animal health is no special category
(O112). Two traps follow (step 8): free text (clinical notes, a
pathologist's comment, a cytology report) may name the owner or the
client; and a send-out or a callback carrying more than its rule allows.

### The business's own rules

The lab's default policy (procedure 6, item 1): beside the core's,
built into the domain's `docs/policy.md` and its `governance:`
fragment. Its home is the core's unnamed EU member state (D278): EU law
as written, national rules named generically; a figure marked *game
value* is a choice, not the law. Sources as in "Regulations" above.

**Release.** A result leaves the lab, to the portal or a practice, only
once released by a clinical pathologist (D280, rule 11); inside the
centre a technically validated urgent result is shown marked
unvalidated (answer 7).

**Traceability.** Every result names its batch (or the bench), the QC
run in force, the technician who validated it and the vet who released
it, with their times (ISO/IEC 17025, 7.5.1).

**Amendments.** A released result is never updated: an amendment is a
new row referencing the one it replaces, the first kept with what
changed, why and who (7.5.2, 7.8.8).

**Quality control.** Each analyser once a day and before a night run; a
failed run holds the analyser's results since its last good run, and
nothing is released from a failed run (7.7.1, 7.10.1).

**Unfit samples.** A sample's condition is recorded at receipt; a test
it makes unfit is not performed, the customer told why (7.4.3).

**Critical values.** Phoned to the requesting vet or the practice
within 60 minutes of the result, read back, the call recorded (*game
value*: no veterinary standard fixes the limits or the delay).

**Notifiable diseases.** National law requires labs to notify: the lab
notifies the authority of a positive or suspect result for a test tied
to a listed disease, for every customer, within an hour of the
result's technical validation for a category A disease and within a day
for another listed disease (*game values* for 2016/429 Art 18's
"immediately" and "as soon as practicable"); for category A it forwards
a sample to an official lab without delay, under custody (2020/687 Art
3(2)).

**Chain of custody.** A sample with legal weight records each handover:
both parties, the time, its condition and its seal number.

**Residue screening.** An own check for the keeper, never an official
sample, never reported to the authority (answer 11).

**The practices' clients (GDPR).** For an outside order the lab
processes the practice's client data on the practice's behalf, a
processor under Art 28: it uses the data for that order only, never
matches a patient to the centre's animals (answer 4), and returns a
practice only its own orders.

**Least data.** A send-out carries the accession, the sample's label,
the species, sex and age, never the owner, the client or a natural
identifier; the lookup API is read without contacts (D266); no personal
data in the logs: pgaudit on the lab's database logs writes, schema
changes and role changes (`pgaudit.log = 'write, ddl, role'`), its
statements' parameters off (`pgaudit.log_parameter = off`).

**Retention.** No EU rule sets a lab's periods; ISO/IEC 17025 and
AAVLD leave them to the lab. *Game values*: orders, results, validations,
amendments, QC runs and custody records five years, as the clinic's
clinical records (D280, rule 9), then the order's personal columns
erased or anonymised; samples a week or two (answer 10), a custody
sample until its case closes, 60 days at most; charges ten years, as
national accounting law commonly keeps them.

**Billing.** As answer 13: the price of the order's day, billable on
release, voided on a cancellation or an unfit sample, a handling fee per
order, half again for urgent, the volume discount on the statement; the
centre's own account never charged; no owner billed.

**What the data model took from these rules** (above): the two
validations on each test, amendments as superseding rows, the QC run
in force on each batch, each sample's condition and custody flag, the
interval each result was flagged against, the notifications with their
times, the charges' price and billable date.

### The rules, as the owner confirmed them (D302)

The owner confirmed them as drafted on 2026-11-02 ("agreed"), with the
classification above and their game values:

1. **Release** by a clinical pathologist only; urgent results shown
   inside, marked unvalidated.
2. **Traceability** of every result to its batch, QC run, technician
   and vet (ISO/IEC 17025, 7.5.1).
3. **Amendments** as new rows, never updates (7.5.2, 7.8.8).
4. **Quality control** daily and before a night run; a failed run
   holds results (7.7.1, 7.10.1).
5. **Unfit samples** recorded, the test not performed, the customer told
   (7.4.3).
6. **Critical values** phoned within 60 minutes, read back, recorded
   (game value).
7. **Notifiable diseases**: national law requires labs to notify;
   within an hour for category A, a day for the others (game values);
   category A samples forwarded under custody (2016/429 Art 18; 2020/687
   Art 3(2)).
8. **Chain of custody** for samples with legal weight.
9. **Residue screening** an own check, never official, never reported.
10. **The practices' clients**: the lab a processor (GDPR Art 28), each
    practice seeing only its own orders.
11. **Least data**: send-outs without owner, client or identifier;
    pgaudit logging writes, DDL and roles, without parameters.
12. **Retention** (game values): lab records five years, samples a
    week or two, custody samples 60 days at most, charges ten years.
13. **Billing** as answer 13, the centre never charged.

## The producer profiles (step 6)

Drafted on 2026-11-02 with `vet-core`'s
([vet-core-domain.md](vet-core-domain.md#the-producer-profiles-step-6)),
whose page states what both share: a volume stream against a work
stream, the input types, intensity and the history, and readable
fragments with no planted fault (D276). Ruled as drafted on 2026-11-02
(D304, closing O153), with what the profiles need of the scheduler and
the format ([producer profiles](producer-profiles.md#12-what-the-clinics-first-profiles-need-ruled-d303)
12, D303, closing O154).

**Producer or purpose.** What the lab's own applications write into
`lab` is this step's, and so are the rates of every flow it meets,
the partners' among them. The flows out of the lab or into another part
are purposes (procedure 4, step 7): the centre's orders posted to the
lab, the results copied back into the core's `requests`, the results
posted to the practices' callbacks, the send-outs to the external lab,
the notifications to the authority, the monthly statements, and the
release to the portal. `lab_dispatch` and `lab_reports` are their roles;
nothing in this step runs as either.

### The applications and their nodes (D276)

| Application | Node | Connection, role | What it does |
|---|---|---|---|
| The lab's information system, with the analysers' middleware | `lis`, a scheduler node | `lab`: `lab:5432/lab`, `lab_app`; `lab-instruments`: the same target, `lab_instruments`; `clinic-api`: the core's lookup API, HTTP (D267) | accessioning, bench work, validation and release, QC, critical calls, notifications' records, custody; the analysers' batch uploads; the centre's patients' identity from the core |
| The lab's order API (D267, D270) | `lab-api`, an `api` node in the players' scope | `lab_api` | only answers: `POST /orders` (any account, the centre's included; idempotent on the account and its `client_ref`, the same accession answered twice), `GET /orders/{accession}` (an order's state, interim or final), `GET /orders?account=<id>&released_since=<time>` (the released results feed: one account's tests released, not performed or cancelled since a time, which the centre's `fetch-lab-results` polls every five minutes, D306), `POST /send-outs/{send_key}/result` (the external lab's answer); players edit its `db/` side only (D271) |

The middleware shares the information system's node: a lab's
middleware is an application of its own, but one node standing for
both keeps the node count to the clinic's applications, a few standing
for many (D263, D304). The fragments are written for the
node names `lis`, `lab-api`, `lab` and `clinic-api`; the GM renames
them as the scenario does.

### Rates at intensity 1.0

A stream is a volume or a work stream, as for the core
([vet-core](vet-core-domain.md#rates-at-intensity-10)); the lab's
volume arrives mostly from outside its node: the centre's orders
through its purpose, the practices' through their stub (below). The
lab's own streams are therefore nearly all work streams, their rates
capacities.

Work streams, on `lab` as `lab_app` unless stated:

| Key | What it takes and writes | Capacity | Shape | Follows |
|---|---|---|---|---|
| `lab.samples.receive` | the oldest centre order whose samples are expected, collected 15 minutes ago or more: its samples received, their condition (about 97 % fit, the rest haemolysed, lipaemic, clotted, under-filled or unlabelled, by a hash of the sample's id), a `received` event; its tests in progress, or waiting for the send-out; an unfit sample's tests not performed | 15/h | `flat` | the centre's orders: about 25 orders, 30 samples a day |
| `lab.courier.receive` | the oldest practice order posted before the courier's round: as above; each outside test's charge, pending | 40/h, concurrency 2 | `courier-waves` | the practices' orders: about 25 orders, 35 samples a working day |
| `lab.analyser.run`, on `lab-instruments` as `lab_instruments` | one analyser's run: a batch of the pending tests of its discipline, one result per analyte, each flagged against the interval in force for the species; nothing when nothing waits or when the analyser's last QC run failed | 5.7/h | `bench` | about 75 batches and 700 results a day |
| `lab.bench.result` | bench work: a urinalysis, a smear or a rapid test read within hours; a culture read after two to three days, its sensitivities two or three more; a result with no batch | 8/h | `bench` | about 100 a day |
| `lab.validate.technical` | a test whose results are all in, from a batch whose QC run passed: technically validated; stored, a `stored` event | 30/h | `bench` | about 80 a day |
| `lab.release.urgent` | an urgent, technically validated test released at once by a clinical pathologist, on call at night and on Sundays; its order completed once every test is final | 10/h | `flat` | about 15 a day |
| `lab.critical.call` | a critical result with no call: the call to the requesting vet or to the practice, read back, recorded within the hour (rule 6) | 6/h | `flat` | two or three a day |
| `lab.notify` | a positive or suspect result for a test tied to a listed disease, technically validated, with no notification: its row, within the hour for category A (rule 7); its push to the authority is a purpose | 2/h | `flat` | a few a month |
| `lab.qc.rerun` | a failed QC run with no passing run after it: rerun and passing, the analyser's results held meanwhile (rule 4) | 4/h | `flat` | about one a week |

Volume streams, on `lab` as `lab_app`:

| Key | What one call writes | Rate | Shape | A day: Mon–Sat / Sun |
|---|---|---|---|---|
| `lab.amend` | a released result amended: a new row superseding it, what changed, why, who (rule 3) | 0.25/h | `bench`, poisson | 4 / 0.6 |
| `lab.orders.cancel` | an order not yet tested cancelled, its tests cancelled, its charges void; for the centre's orders, the vet's phoned cancellation of a sent request (D315), which the results feed carries back | 0.08/h | `bench`, poisson | 1 / 0.2 |
| `lab.add-on` | a test added on a stored sample within its keep-until, billed to whoever paid for the first | 0.1/h | `bench`, poisson | 1.5 / 0.2 |

Reads, on `lab` as `lab_app`: `lab.worklist` (a bench's pending tests;
30/h, even, `bench`), `lab.order.view` (an order's report, interim or
final, for the staff and the telephone; 25/h, poisson, `bench`,
concurrency 2).

Fixed-time operations (`jobs.yaml`, scenario time):

| Job | When | What |
|---|---|---|
| `lab.qc.morning` | `45 6 * * *` | QC on every analyser before the bench opens: three levels for haematology, two for the others, about 15 runs; one in fifty fails, by a hash of the run's id |
| `lab.qc.night` | `15 21 * * *` | QC on the on-call analysers before the night (machines 1, 3 and 5: one haematology, one biochemistry, the blood gas, D319): about 7 runs |
| `lab.release.round` | `0 11,14,18 * * 1-6` and `0 11 * * 0` | the pathologist's round: every technically validated test not held released (rule 1), orders completed, the outside tests' charges billable on the release's date (rule 13) |
| `lab.samples.dispose` | `0 6 * * *` | samples past their keep-until disposed, a `disposed` event; a custody sample kept until its case closes (rule 12) |
| `lab.identity` | `* * * * *` | the centre's new orders lacking the animal's identity: each animal read from the core's lookup API (`GET /animals/{id}`, `/owner`) and its species, sex, born on, natural identifiers, food-chain status and the owner's surname written on the order; a read, a call and a write: a script job holding the `lab` connection and an HTTP one to `clinic-api` (D303) |

`lab.samples.dispose` is light, set-based work, the database node's
`pg_cron` a placement the GM may choose (D206, D207). `lab.identity`
is a producer's, not a purpose: it is how a part gets the core's
animals (D266), the lab storing what the core's API answers; it is the
lookup API's first traffic in the game (D267), and the way the core's
dozen mistyped chips (D278) reach the lab's live orders while its
history holds the correct ones.

About 1 300 rows a day, as step 4 counted. A weekday holds about 85
tests and 700 results, a Sunday about a quarter: the centre's urgent
tests and its hospitalised animals'.

### The business hours (shapes)

| Shape | Hours |
|---|---|
| `bench` | Monday to Saturday 07:00–21:00 at 1.0; every other hour at 0.1, the on-call technician's urgent haematology, biochemistry and blood gases |
| `courier-waves` | Monday to Saturday, 11:00–12:00 and 17:00–18:00: the courier, back from the practices at about 10:45 and 16:45, the samples accessioned in a wave after each round |
| `flat` | every hour at 1.0 |
| `practice-hours` (the practices' stub) | Monday to Friday 08:00–12:00 and 14:00–19:00 at 1.0, 0.3 over lunch; Saturday 08:00–12:00 |
| `xlab-hours` (the external lab's stub) | Monday to Saturday 08:00–20:00 |

The pathologist's rounds are jobs, at 11:00, 14:00 and 18:00 from
Monday to Saturday and at 11:00 on Sundays (the on-call pathologist);
urgent results are released at once around the clock. The send-outs are
packed at 16:00, Monday to Friday, by their purpose (below).

### The partners the lab meets (D285, D293, D294)

On the back end every partner shares (one scheduler node, one small
database, D293), and the one `api` node serving every partner, each
under its own hostname (D308), out of the players' reach. A partner's
back end ticks its own routes, whose endpoint reads the partner's
state, calls the centre and records the answer, as a real partner's
system would; its fault keys come with the faults (D276), the
fragments holding its normal behaviour (D303).

**The region's practices**, one stub for the 120 accounts (D293):

| Key or endpoint | What | Rate | Shape |
|---|---|---|---|
| `practices.order` (back end stream) | ticks the stub: it builds a practice's order (one of accounts 2–121, its patient reference and client's surname, a species mix of 70 % dogs and cats, 15 % horses, 15 % farm animals, about 1.6 tests, one in twenty urgent, a fresh `client_ref`), posts it to `lab-api`'s `POST /orders`, and keeps the accession | 2.9/h | `practice-hours`, poisson: 28 a weekday, 12 on Saturday, 25 a working day on average (step 2) |
| `POST /results` (its routes) | takes a delivery (interim, final or amended), acknowledges each `delivery_key` once, a repeat acknowledged again without a second record | | answers the dispatch's calls: about 40 a day |

**The external reference lab** (D268):

| Key or endpoint | What | Rate | Shape |
|---|---|---|---|
| `POST /orders` (its routes) | takes a send-out: answers `accepted` with its accession, keeps the `send_key`, the test and the due time (the test's turnaround, one to five days); the same `send_key` again answers the same accession | | about 7 a day, Monday to Friday at 16:00 |
| `POST /orders/{send_key}/resend` (its routes, D306) | a chase: the back end posts that send-out's answer again, at once if resulted, else when due | | the chases of `vet-lab-send-outs`, rare unless a callback was lost |
| `xlab.answer` (back end stream) | ticks the stub: each send-out past its due time gets its result posted to `lab-api`'s `POST /send-outs/{send_key}/result`, the answer kept | 6/h, even | `xlab-hours`: follows the send-outs, about 7 a working day |

The back end's intensity is one for every partner (one schedule a
node): at 1.0, the practices' orders above. The ticks are polling and
their capacities only follow; the volume is the practices' order rate,
which the scenario keeps at the clinic's nodes' intensity
([vet-core](vet-core-domain.md#intensity-and-the-history-before-t0-d276-d279)).
The partners' database grows by about 125 rows a day: orders,
deliveries, send-outs, cold storage's manifests.

### The round trips, for step 7 (D268, D286)

Each a purpose of the round-trip kind; the profile they meet:

| Round trip | Who asks | Request | Correlation key | Expected answer | Timing at 1.0 | Timeout, then | Reactions |
|---|---|---|---|---|---|---|---|
| The centre's orders | the centre | the consultation's analysis requests, one order, posted to `lab-api` | `client_ref`, the requests' ids | the accession id at once; the result once released | about 25 orders a day, each within a minute of its consultation's close | no accession in a minute: resent with the same `client_ref` | the core's requests `sent`, then `resulted` with the result copied back |
| The practices' orders | a practice | an order posted to `lab-api` | the practice's `client_ref` | the accession id at once; the interim and final results at its callback | about 25 a working day; results the same day for most, cultures and send-outs days later | the dispatch's: no acknowledgement in five minutes, retried with the same `delivery_key`, at most six times | each delivery acknowledged; a test billable once released |
| The send-outs | the centre | the day's send-out tests posted to the external lab: the accession, the label, species, sex and age, never an identifier (rule 11) | `send_key`, kept on a retry | `accepted` at once; the result one to five days later | about 7 a day, Monday to Friday 16:00 | not accepted: retried with the same `send_key`; past `due_by` by a working day: chased with `resend`, then an incident (clinic-purposes 7) | the test resulted, then validated and released as the centre's own, naming the lab that performed it |

The end-to-end invariant a cascade's fix is judged by (D286): every new
order gets its result released, and for a practice's every released
result is acknowledged at its callback.

### The periodic reports (D265, D294, D300)

| Report | Cadence | Its daily feeder | Planted before T0 |
|---|---|---|---|
| Each practice's monthly statement (answer 13) | on the 1st at 04:00 | 02:30: yesterday's billable and voided charges per account | every full month's statements of the year, one per account |

A purpose (step 7), writing to `office` on the core's instance (D300).
The lab has no standby (D299, D301): its statement reads the lab's own
node, at night when the bench is closed and the on-call traffic light,
a second connection writing `office` (D304). The yearly
price list and the intervals' review are history only: one revision
each, on 1 January, inside the year (step 4).

### The history before T0 (D279)

As the core's: the year ramps from about 60 % of today's volume to
today's, on the shapes above, so the waves after the courier, the
rounds' releases at 11:00, 14:00 and 18:00 and the quiet Sundays show
in the history as they will in the aging; the price change and the
intervals' review on 1 January. In flight at T0, as a night leaves the
lab:

- the night's urgent orders received and in progress; the practices'
  orders posted after the last courier round, their samples not yet
  received;
- cultures incubating, two to five days old, about fifteen;
- samples stored for add-ons, a week or two: about 600 not yet disposed;
- send-outs sent within their turnaround and not yet answered, about
  twenty; the external lab's stub holds the same send-outs, by the same
  `send_key`, in the partners' database;
- outside tests not yet released, their charges pending.

The partners' database is planted from the same documented functions
of the lab's ids as the lab's own load, so no outstanding send-out is
missing from the stub, which would leave a result never coming back
with no fault behind it (D304).

### Cold storage (D297)

Nothing of the lab ships: about 1 300 rows a day against the threshold
of about 50 000 (D296), and the statements, amendments and add-ons read
the year. The analysers' readings and run logs, which may ship, are
`vet-machinery`'s (D298). The lab's node ships its `wal` and its
nightly `basebackup` to the vault (D301), as the core's instance does:
at least 24 segments a day with `archive_timeout` at an hour.

### Growth, for the GM notes (D298)

At intensity 1.0, on `lab`:

| | Rows | Size |
|---|---|---|
| A day, on average | about 1 300 new rows, about 700 of them results; about 400 updates (tests moving through their states, orders completed) | about 0.3 MB with indexes, before bloat |
| An hour, on average | about 55 | |
| A bench hour on a weekday | about 100, in bursts of a batch's results | |
| A Sunday | about a quarter of a weekday | |

The partners' database: about 125 rows a day. Over an aging the lab's
disk is never the problem: its bursts, its holds and its round trips'
backlogs are.

### Points for the owner, ruled (D304)

Confirmed as drafted on 2026-11-02 ("agreed"), with the core's (D304,
closing O153); point 4 amends D302's grants, applied in "Application
roles and grants" above, and point 5 is applied in
[one-centre.md](one-centre.md#2-the-labs-partners-d293-d294):

1. **One node for the information system and the middleware**, `lis`,
   with two connections and their roles; the order API, `lab-api`, only
   answering.
2. **The hours**: the bench 07:00–21:00 Monday to Saturday, a tenth of
   its traffic on call otherwise; the courier back at about 10:45 and
   16:45, Monday to Saturday, a wave of accessioning after each; the
   pathologist's rounds at 11:00, 14:00 and 18:00, and one at 11:00 on
   Sundays by the on-call pathologist; QC at 06:45 and 21:15; send-outs
   at 16:00 Monday to Friday; the external lab answering Monday to
   Saturday, 08:00–20:00.
3. **The centre's patients' identity from the core's lookup API**, a
   job of the information system every minute (D266's mechanism), not a
   purpose.
4. **`lab_app` writes `lab_charges`**: step 4's grants give no role
   that write; the information system charges at accession, makes a
   charge billable at release and voids it on a cancellation or an
   unfit sample. A correction to D302's grants.
5. **The other national centres order nothing from the lab in v0.5**:
   one-centre's "the other national centres order the same way" against
   the accounts D302 ruled, the centre and the practices; each centre
   has its own lab (D285), so the sentence leaves one-centre.md.
6. **The statements read the lab's node at night**, with no standby to
   read (D299, D301); a statement read at bench hours is a fault
   candidate, a report competing with the bench.
7. **The partners' database planted from the lab's functions**, so the
   external lab's stub knows every send-out the history left open and
   the practices' stub every order not yet received.

## Purposes that fit (step 7)

Ruled with `vet-core`'s (D306, D307), each its own unit under
`purposes/` ([clinic-purposes.md](clinic-purposes.md) 2): fitting the
lab, `vet-lab-centre-orders`, `vet-lab-practice-results`,
`vet-lab-send-outs`, `vet-notifiable-diseases`, `vet-lab-critical-calls`,
`vet-head-office-figures` and `vet-lab-statements`; with `vet-portal`,
purpose 15, `vet-portal-release`, reading the centre's released results
(D320, numbered by D324,
[clinic-purposes.md](clinic-purposes.md#16-the-parts-purposes-11-to-16)).

## Traps (step 8)

Listed with `vet-core`'s in [clinic-traps.md](clinic-traps.md); the
part's GM notes carry them ("the traps"). Those that bite the lab: on
its node and configuration T2, T4 to T7, T10, T11; in its data T13 (the
core's chips reaching its orders), T20 to T23; in its governance T24,
T29, T30; in the archive T38; in its round trips T39 to T53 and T85 (the lab's
side of the centre's orders, the practices' deliveries, the
send-outs); in its obligations T57, T58, T60 to T63; in its statements
T75 to T77; in performance and `lab-api`'s `db/` side T78, T80, T83,
T84. False-alarm material: [clinic-traps.md](clinic-traps.md) 9.
Selecting a game's faults is the GM's (D309); the spec's test selection
is [clinic-test-selection.md](clinic-test-selection.md).

## Loading

`gmctl load-data` runs `schema.sql` then `load.sql` into `lab` on the
`lab` node as `postgres`, as for the core: explicit ids in the documented
ranges, each sequence set after its range, the core's ids computed by
its documented functions without reading `clinic` (D302), so the two
loads are independent; the load's sessions unseen (D265). About 0.36
million rows; size and time measured at the build (procedure 3). The
partners' database is planted from the same functions, so the external
lab's stub knows every send-out the history left open and the
practices' stub every order not yet received (D304). After the sources'
loads, `vet-lab-statements` plants the year's statements in `office`
([clinic-purposes.md](clinic-purposes.md) 4, item 5).

## Open points

- **O111**: the domain format, finalised in v0.5's master spec (D291),
  with the composition rules (D322, D323,
  [procedure](domain-procedure.md) 10).

Settled on 2026-11-03: the four parts folded in (D317–D325); the centre's sent requests are cancelled by the
lab only, the results feed carrying cancelled tests beside released and
unperformed ones (D315); v0.5 builds the test selection's ten faults and
its false alarm (D316).
