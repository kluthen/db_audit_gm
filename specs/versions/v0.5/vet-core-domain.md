# v0.5 — `vet-core`, the clinic's core domain

Status: draft v1, at the procedure's step 2, the business sketch, its
scale on D263's three axes. Its questions are the owner's to answer
(O144); identity across systems is ruled (D266); the split (step 3) and the data model (step 4) wait for his
answers. Figures and readings are
(proposed) until he confirms them.

`vet-core` is the core of the veterinary clinic franchise (D196), the
first domain defined through the [procedure](domain-procedure.md)
(D235, D260). By the procedure's first cut it holds the keys every part
shares, owners, animals, sites and staff, and the medical record:
consultations, treatments and prescriptions (section 4). The brief is the
owner's, quoted in the [version page](README.md#the-veterinary-clinic-d196).

## The business sketch

The sketch covers the whole clinic as the core sees it: who comes in
contact with the medical record, what they do, how much and how often,
and under which rules. What belongs to a part is named, and left to it.

### The business

A franchise of large veterinary hospitals: three in the country and
several abroad (D196), each drawing animals from its whole region. Each
centre has three clinical sections, horse, farm and domestic, the horse
and farm sections with their own housing, machinery and specialists; a
biology lab; a training centre. The centres refer animals to one another
when a machine or a specialist is at another centre, and work with
external labs. Owners follow their animals through a portal.

### Actors

| Actor | Who | With the medical record |
|---|---|---|
| Owner | a pet owner, a horse owner or stable, a farmer (a holding's keeper) | registers animals, brings them, consents, reads what is released to them (`vet-portal`) |
| Animal | a patient: domestic, horse or farm animal; also the clinic's own teaching animals | the subject of every record |
| Referring vet | a practice outside the franchise sending an animal | sends a referral, receives a report back |
| Vet and specialist | surgery, internal medicine, imaging, anaesthesia, reproduction, per section | examines, diagnoses, prescribes, operates, signs the record |
| Nurse, technician | per section | records administrations, observations, admissions and discharges |
| Carer, groom | housing staff | feeds and cares (`vet-housing`), never prescribes |
| Lab staff | the biology lab | receives orders, runs analyses (`vet-lab`) |
| Receptionist | each centre | registers owners and animals, books (`vet-scheduling`) |
| Instructor | the training centre | teaches with the teaching animals (`vet-scheduling`) |
| Another centre of the franchise | the other sites | sends and receives transfers and requests (topology, round trips: O127, O128) |
| External lab | outside the franchise | receives orders, returns results (`vet-lab`, O128) |
| The authority | the veterinary services | receives notifiable disease reports and the antimicrobial-use report (purposes) |

### Activities

| Activity | What it records | Held by (first cut) |
|---|---|---|
| Registering an owner and an animal | identity, contact, the animal's species, breed, natural identifiers (question 14), food-chain status | core |
| Referral intake | the referring vet, the reason, the documents | core (question 5) |
| Booking a consultation, a room, a machine | the slot | `vet-scheduling` |
| Consultation | the vet, the findings, the diagnoses | core |
| Ordering an analysis | the request, the sample | the request in core, the analysis in `vet-lab` (pressure below) |
| Imaging and machine examinations | the study and its readings | `vet-machinery` |
| Admission and discharge | the hospital stay | core or `vet-housing` (question 6) |
| Placing in a box or stall, feeding, care | the stay's placement, care logs | `vet-housing` |
| Surgery and procedures | the procedure, the team, the anaesthesia | core |
| Prescribing, dispensing, administering | the medicine, the batch, the dose, the withdrawal period | core (question 7) |
| Emergency at any hour | as a consultation, flagged | core |
| Releasing results and reports to the owner | what was released, when | `vet-portal` |
| Death, euthanasia | the outcome on the record | core |
| Reporting to the authority | notifiable diseases, antimicrobial use | purposes fitting core and lab |
| Billing | invoices, insurers, farms' statements | none in the cut (question 8) |

### The variant, its scale and its tags (proposed)

v0.5 builds one variant of the clinic (procedure 9, D263): the
franchise as briefed, `regional-franchise`, tagged `managed`,
`regional`, `regulated`, `multi-site` and `24/7` (question 13). Its
scale, on the three axes, for the record the three national centres
share (question 1), within "the data schema stays simple and the tables
small" ([platform.md](../../platform.md)); the shop holds about 1.3
million rows, the core stays under it.

**Population**, at load:

| What | How many |
|---|---|
| Sites | 6: 3 national centres, 3 abroad |
| Staff | about 250 |
| Owners | 30 000, of which about 600 holdings and 2 000 horse owners or stables |
| Referring practices | about 1 200 |
| Animals | 50 000: 43 000 domestic, 4 000 horses, 3 000 farm animals |
| Hospitalised animals | about 120 at any time |

**History**: one year, so about 90 000 consultations, 60 000
prescriptions (150 000 lines) and 200 000 administrations.

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Consultations | about 250 a day across the centres, 30 of them emergencies |
| New owners, new animals | about 40 and 60 a day |
| New referring practices | a few a week |
| Administrations | about 700 a day: 120 animals, a dose every four to eight hours |
| Prescriptions | about 150 a day |

A franchise with more centres shows it through structure, not rows: a
few sites stand for many (D263).

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Business hours, Monday to Saturday | consultations, registrations, prescriptions; the domestic section's busiest hours late afternoon, horse and farm mornings | yes |
| Around the clock | emergencies (a third at night), administrations in hospital, the rounds at fixed hours | yes |
| Daily | discharges late in the morning, the records closed and signed, the controlled-drugs count, vaccination reminders (each animal once a year, spread over every day) | yes |
| Weekly | herd-health visits on fixed weekdays, the staff rota | only if the day falls within the aging: a weekday shape, not a job |
| Monthly | the medicines register's extract, farms' and stables' statements | **no**: history and daily feeders ([producer profiles](producer-profiles.md) 4) |
| Yearly | the antimicrobial-use report to the authority; the records' retention purge | **no**: history and daily feeders |

### Regulations

What a regulated clinic plausibly answers to, at the level a game needs.
The exact rules and periods are confirmed at step 5, where the owner
checks they are realistic; national rules are named generically.

| Rule | Source | What the core must hold |
|---|---|---|
| A prescription states the animal, the medicine, the dose, the duration and, for a food-producing animal, the withdrawal period; one for an antimicrobial is valid five days | Regulation (EU) 2019/6 on veterinary medicinal products | prescriptions and their lines, the animal's food-producing status |
| Medicines given to food-producing animals are recorded with their batch and withdrawal period, records kept at least five years | Regulation (EU) 2019/6 | administrations and dispensings with batch, quantity, withdrawal end |
| A horse's passport says whether it may enter the food chain; that decides which medicines it may receive | EU equine identification rules | the horse's food-chain status, its identifier |
| Antimicrobial use is collected and reported to the authority yearly | Regulation (EU) 2019/6 | an antimicrobial flag on medicines, every use traceable to species and animal |
| Listed diseases are notified to the authority at once | Regulation (EU) 2016/429, the Animal Health Law | coded diagnoses, a notifiable flag |
| Controlled drugs (anaesthetics, opioids) have a register | national law | the movements of those medicines |
| Owners are personal data; an animal's record linked to its owner is linked to a person | GDPR | the classification: owners `personal`, the record `customer-linked`; animal health is no special category (O112) |
| Medical records are kept for a set period, then purged | national rules and professional practice | dates to purge by |

## What the core holds, and its rules

Within the procedure's section 4: the core holds the keys every part
shares (owners, animals, sites, staff) and the medical record
(consultations, diagnoses, procedures, prescriptions, administrations).
Parts refer to its keys by id, with no foreign key, so a part's schema
runs in the core's database or in an instance of its own; the core's
load generates its keys in documented ranges; a part's names carry its
prefix.

The core is the **system of record** for owners and animals (D266): a
part gets them through a lookup API on the core, an `api` node (D267),
or a reference table the core syncs to it. Across systems an animal is
known by its **natural identifiers**: its microchip (ISO 11784/11785),
a horse's UELN and passport number, a farm animal's ear tag. They are
the animal's own columns in the core, and fault vectors: a duplicate, a
mistyped chip, a lab result matching no animal. Two answers may add to it: the hospital stay (question 6) and
the medicines and their batches (question 7).

## Where the parts press on the core

| Part | What it needs the core to hold |
|---|---|
| `vet-lab` | the request that orders an analysis, tied to its consultation, animal and requesting vet, so a result can be traced back and released; the animal's natural identifiers, which an external lab's result carries (D266, D268); the animal's food-producing status for residue tests |
| `vet-portal` | the owner as a stable key, one portal account each; who owns an animal **now**, and since when: a horse is sold, a dog changes family (question 4); what of the record an owner may see |
| `vet-housing` | the hospital stay the box refers to (question 6); what a display shows: identity, alerts and allergies, the treatment plan; the administrations, so that care logs and the core never hold one fact twice (a trap, step 8) |
| `vet-scheduling` | staff with their specialties and sites, rooms per site; the consultation a booking turns into, by id |
| `vet-machinery` | the examination a study belongs to (a consultation or a stay), the animal |
| `vet-messaging` | staff as the senders and recipients |
| Regulatory purposes | batches, quantities, withdrawal periods, the antimicrobial flag, coded diagnoses with the notifiable flag, species and food-chain status: all in the core, or the reports cannot be computed |
| Exchange between centres (O127, O128) | a site on every record, transfers naming the sending and receiving site |

## Questions for the owner (O144)

Each with a proposed default; "agreed" accepts it.

1. **Sites and the record.** Do the three national centres share one
   medical record, and are the centres abroad separate systems? Default:
   one shared record for the three national centres (a site is a core
   entity, procedure 4); the centres abroad are separate systems,
   reached by exchange (O127, O128), listed in `sites` so that transfers
   name them; every site in the customer's zone ([producer
   profiles](producer-profiles.md) 10).
2. **The default company.** Default: a fictional franchise in an
   unnamed EU member state, "Aldermoor Veterinary Hospitals", its rules
   taken from EU law and its national ones named generically. A scenario
   may rename it.
3. **The farm section.** Which species, and are they individuals or
   herds? Default: cattle, sheep and goats, each identified by its ear
   tag and belonging to a herd (a holding with its keeper); herd-health
   visits attach to the herd, treatments to an animal or a group of the
   herd's animals; no pigs or poultry.
4. **Ownership.** One owner per animal, or ownership over time? Default:
   one current owner and a dated ownership history; an optional keeper
   (a stable, a livery yard, a holding) beside the owner; the portal's
   reach follows the history (a rule for step 5).
5. **Referrals.** Do referring practices and vets belong in the core?
   Default: yes, about 1 200 practices, a consultation carrying its
   referral; the report back to the referring vet is a purpose, later.
6. **The hospital stay.** Core or `vet-housing`? Default: the stay
   (admission, discharge, reason, outcome) in the core, since the lab,
   the portal, the reports and the administrations all refer to it;
   `vet-housing` keeps the boxes and stalls, the placements and the care
   logs, referring to the stay by id. This revises the procedure's cut.
7. **Medicines.** Where do the medicines, their batches and the
   controlled-drugs register live? Default: the core holds the medicines
   (with the antimicrobial and controlled flags and withdrawal periods),
   their batches, and every administration and dispensing with batch and
   quantity, which is what the registers need; stock receipts and
   ordering stay out of v0.5; no pharmacy part.
8. **Billing.** In the clinic's v0.5 domains? Default: no. Consultations
   and procedures carry no price; a billing part (insurers, the farms'
   monthly statements) comes later, with the shop's finance purpose
   (D248).
9. **Staff.** Default: one staff table: vets with their specialties,
   nurses and technicians, lab staff, carers and grooms, receptionists,
   instructors, each with a home site and possibly working at others;
   the applications log in with roles of their own, never one database
   login per person, as in the shop.
10. **The training centre.** Does "canine and horse dedicated training"
    mean training people (vets, nurses, owners, handlers), or training
    animals? Default: training people, with the clinic's own teaching
    animals; trainees are not staff and live in `vet-scheduling`; the
    teaching animals are core animals, the clinic their owner.
11. **Scale and hours.** Default: the figures in "The variant" and
    "Cadences": a population of 30 000 owners and 50 000 animals, a year
    of history, a throughput of about 250 consultations a day across the
    three centres, about 120 animals in hospital, emergencies around the
    clock.
12. **Regulations.** Default: the set in "Regulations", records kept
    five years, a horse's food-chain status deciding the medicines it
    may receive, antimicrobials flagged for the yearly report, notifiable
    diseases reported at once; the reports themselves are purposes (step
    7), monthly and yearly ones living as history ([producer
    profiles](producer-profiles.md) 4).

13. **The variant's tags.** Default: `regional-franchise`, maturity
    `managed` (an IT team of its own running its own scripts beside the
    tools, D248), reach `regional` (it draws animals from its region),
    traits `regulated`, `multi-site` and `24/7`; not `seasonal`, though
    the farm section has its calving and lambing seasons, which a
    scenario's story may name.

14. **Natural identifiers (D266).** Which identifiers does the core
    hold, and how clean are they? Default: a microchip for every dog,
    cat and horse and for some other pets, about 2 % of domestic animals
    with none; a UELN and a passport number for every horse; an ear tag
    for every farm animal; unique when present, with a handful of
    mistyped chips at load (a trap, step 8). A herd's holding number
    for each herd.

## Next

Once these are answered: the split (step 3), revising the procedure's
cut where questions 6 and 7 move a table, then the data model (step 4).
