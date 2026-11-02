# v0.5 — `vet-core`, the clinic's core domain

Status: draft v5. Step 2, the business sketch, is ruled (D266, D278),
its first answer revised by one centre per scenario (D285); step 3, the
split, is confirmed (D279); step 4, the data model, is current, with
the history's growth and its lower year totals (D279, D280), its
figures still sized for the three national centres: the rescale for
one centre is (proposed) ([below](#one-centre-the-rescale-proposed-o147),
O147); step 5, classification and governance, is ruled (D280). Step 6,
the producer profiles, is next.

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
biology lab; a training centre. Each centre is independent, with its
own records and its own lab, which the region's other clinics pay to
use (D285). The centres refer animals to one another when a machine or
a specialist is at another centre, and work with external labs. Owners
follow their animals through a portal. A scenario deploys one centre;
the other centres and the franchise's central systems are third
parties (D285; [one-centre.md](one-centre.md)).

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
| Another centre of the franchise | the other national centres and the centres abroad, third parties with records of their own (D274, D285) | sends and receives transfers and requests (round trips, D286) |
| The franchise's central systems | the head office and the group's services | third parties (D285) |
| A clinic of the region | a practice using the centre's lab, paying for it | orders analyses and receives results (`vet-lab`, D285) |
| External lab | outside the franchise | receives orders, returns results (`vet-lab`, D268) |
| The authority | the veterinary services | receives notifiable disease reports and the antimicrobial-use report (purposes) |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Registering an owner and an animal | identity, contact, the animal's species, breed, natural identifiers, food-chain status | core |
| Referral intake | the referring vet, the reason, the documents | core |
| Booking a consultation, a room, a machine | the slot | `vet-scheduling` |
| Consultation | the vet, the findings, the diagnoses | core |
| Ordering an analysis | the request, the sample | the request in core, the analysis in `vet-lab` |
| Imaging and machine examinations | the study and its readings | `vet-machinery` |
| Admission and discharge | the hospital stay | core |
| Placing in a box or stall, feeding, care | the stay's placement, care logs | `vet-housing` |
| Surgery and procedures | the procedure, the team, the anaesthesia | core |
| Prescribing, dispensing, administering | the medicine, the batch, the dose, the withdrawal period | core |
| Emergency at any hour | as a consultation, flagged | core |
| Releasing results and reports to the owner | what was released, when | `vet-portal` |
| Death, euthanasia | the outcome on the record | core |
| Reporting to the authority | notifiable diseases, antimicrobial use | purposes fitting core and lab |
| Billing | invoices, insurers, farms' statements | none in v0.5: a later part |

### The variant, its scale and its tags

v0.5 builds one variant of the clinic (procedure 9, D263): the
franchise as briefed, `regional-franchise`, tagged `managed`,
`regional`, `regulated`, `multi-site` and `24/7` (question 13). Its
scale, on the three axes, was sized for one record shared by the three
national centres (D278); since each centre keeps its own (D285), the
figures below await the rescale for one centre, proposed in
[One centre: the rescale](#one-centre-the-rescale-proposed-o147)
(O147). Within "the data schema stays simple and the tables small"
([platform.md](../../platform.md)); the shop holds about 1.3 million
rows, the core stays under it.

**Population**, at load:

| What | How many |
|---|---|
| Sites | 6: 3 national centres, 3 abroad |
| Staff | about 250 |
| Owners | 30 000, of which about 600 holdings and 2 000 horse owners or stables |
| Referring practices | about 1 200 |
| Animals | 50 000: 43 000 domestic, 4 000 horses, 3 000 farm animals |
| Hospitalised animals | about 120 at any time |

**History**: one year of a clinic that grew through it (D279): each
daily volume ramps from about 60 % of today's rate a year ago up to
today's, so the year holds about 73 000 consultations, 44 000
prescriptions (110 000 lines) and 200 000 administrations, and the
players can see the growth in the data.

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
mistyped chip, a lab result matching no animal. It also holds the
hospital stay and the medicines with their batches (D278).

## Where the parts press on the core

| Part | What it needs the core to hold |
|---|---|
| `vet-lab` | the request that orders an analysis, tied to its consultation, animal and requesting vet, so a result can be traced back and released; the animal's natural identifiers, which an external lab's result carries (D266, D268); the animal's food-producing status for residue tests |
| `vet-portal` | the owner as a stable key, one portal account each; who owns an animal **now**, and since when: a horse is sold, a dog changes family (D278); what of the record an owner may see |
| `vet-housing` | the hospital stay the box refers to, the core's (D278); what a display shows: identity, alerts and allergies, the treatment plan; the administrations, so that care logs and the core never hold one fact twice (a trap, step 8) |
| `vet-scheduling` | staff with their specialties and sites, rooms per site; the consultation a booking turns into, by id |
| `vet-machinery` | the examination a study belongs to (a consultation or a stay), the animal |
| `vet-messaging` | staff as the senders and recipients |
| Regulatory purposes | batches, quantities, withdrawal periods, the antimicrobial flag, coded diagnoses with the notifiable flag, species and food-chain status: all in the core, or the reports cannot be computed |
| Exchange with the other centres (D285, D286) | a site on every record, transfers naming the receiving centre, a third party listed in `sites` |

## The owner's answers (D278)

The questions the brief left open, each with the default the owner
accepted on 2026-11-01.

1. **Sites and the record.** Do the three national centres share one
   medical record? Answer, revised on 2026-11-02 (D285, replacing
   D278's "one shared record for the three national centres"): no,
   each centre is independent with its own record, and a scenario
   deploys one. The other national centres and the centres abroad are
   third parties (D274, D285), listed in `sites` so that transfers name
   them; every site in the customer's zone ([producer
   profiles](producer-profiles.md) 10).
2. **The default company.** Answer: a fictional franchise in an
   unnamed EU member state, "Aldermoor Veterinary Hospitals", its rules
   taken from EU law and its national ones named generically. A scenario
   may rename it.
3. **The farm section.** Which species, and are they individuals or
   herds? Answer: cattle, sheep and goats, each identified by its ear
   tag and belonging to a herd (a holding with its keeper); herd-health
   visits attach to the herd, treatments to an animal or a group of the
   herd's animals; no pigs or poultry.
4. **Ownership.** One owner per animal, or ownership over time? Answer:
   one current owner and a dated ownership history; an optional keeper
   (a stable, a livery yard, a holding) beside the owner; the portal's
   reach follows the history (a rule for step 5).
5. **Referrals.** Do referring practices and vets belong in the core?
   Answer: yes, about 1 200 practices, a consultation carrying its
   referral; the report back to the referring vet is a purpose, later.
6. **The hospital stay.** Core or `vet-housing`? Answer: the stay
   (admission, discharge, reason, outcome) in the core, since the lab,
   the portal, the reports and the administrations all refer to it;
   `vet-housing` keeps the boxes and stalls, the placements and the care
   logs, referring to the stay by id. This revises the procedure's cut.
7. **Medicines.** Where do the medicines, their batches and the
   controlled-drugs register live? Answer: the core holds the medicines
   (with the antimicrobial and controlled flags and withdrawal periods),
   their batches, and every administration and dispensing with batch and
   quantity, which is what the registers need; stock receipts and
   ordering stay out of v0.5; no pharmacy part.
8. **Billing.** In the clinic's v0.5 domains? Answer: no. Consultations
   and procedures carry no price; a billing part (insurers, the farms'
   monthly statements) comes later, with the shop's finance purpose
   (D248).
9. **Staff.** Answer: one staff table: vets with their specialties,
   nurses and technicians, lab staff, carers and grooms, receptionists,
   instructors, each with a home site and possibly working at others;
   the applications log in with roles of their own, never one database
   login per person, as in the shop.
10. **The training centre.** Does "canine and horse dedicated training"
    mean training people (vets, nurses, owners, handlers), or training
    animals? Answer: training people, with the clinic's own teaching
    animals; trainees are not staff and live in `vet-scheduling`; the
    teaching animals are core animals, the clinic their owner.
11. **Scale and hours.** Answer: the figures in "The variant" and
    "Cadences": a population of 30 000 owners and 50 000 animals, a year
    of history, a throughput of about 250 consultations a day across the
    three centres, about 120 animals in hospital, emergencies around the
    clock.
12. **Regulations.** Answer: the set in "Regulations", records kept
    five years, a horse's food-chain status deciding the medicines it
    may receive, antimicrobials flagged for the yearly report, notifiable
    diseases reported at once; the reports themselves are purposes (step
    7), monthly and yearly ones living as history ([producer
    profiles](producer-profiles.md) 4).

13. **The variant's tags.** Answer: `regional-franchise`, maturity
    `managed` (an IT team of its own running its own scripts beside the
    tools, D248), reach `regional` (it draws animals from its region),
    traits `regulated`, `multi-site` and `24/7`; not `seasonal`, though
    the farm section has its calving and lambing seasons, which a
    scenario's story may name.

14. **Natural identifiers (D266).** Which identifiers does the core
    hold, and how clean are they? Answer: a microchip for every dog,
    cat and horse and for some other pets, about 2 % of domestic animals
    with none; a UELN and a passport number for every horse; an ear tag
    for every farm animal; unique when present, with a handful of
    mistyped chips at load (a trap, step 8). A herd's holding number
    for each herd.

## The split (step 3), confirmed (D279)

The procedure's first cut (section 4, D249), revised by the answers of
D278, confirmed by the owner with both additions (D279).

| Domain | What it holds |
|---|---|
| `vet-core` | sites and sections; staff; owners and their dated ownerships and keepers; animals with their natural identifiers, herds; referring practices, their vets and referrals; consultations, diagnoses, procedures; requests for analyses and imaging; hospital stays; medicines and their batches, prescriptions, administrations, dispensings; alerts on an animal |
| `vet-lab` | samples and analyses for the core's requests, instrument batch uploads, results, a vet's validation before release; orders to and results from the external labs, a round trip with a third party (D268, D274) |
| `vet-scheduling` | rooms and machines' slots, bookings of staff, rooms and machines; the training centre's courses, sessions and trainees |
| `vet-housing` | boxes and stalls, the placements of the core's stays, care and feeding logs; the displays, reading the core's board of each animal |
| `vet-machinery` | the machines, studies for the core's imaging requests, readings and logs, each machine's own database |
| `vet-portal` | owners' accounts, one per core owner; consents; notifications; what was released to whom |
| `vet-messaging` | internal mail, messages and machine logs, with their own governance |

Not domains: **regulatory reporting**, purposes fitting `vet-core` and
`vet-lab` (step 7); **billing**, a later part (D278); **pharmacy stock**
(receipts, ordering), out of v0.5 (D278); the **other national
centres**, the **centres abroad**, the **franchise's central systems**
and the **external labs**, third parties (D274, D285). Which parts are
the deployed centre's own, `vet-portal` and `vet-messaging` in doubt,
is proposed in [one-centre.md](one-centre.md) 1 (O147).

**Against D249's first cut:**

- the hospital stay moves from `vet-housing` into the core; housing keeps
  the placements and the care logs, by the stay's id;
- the core gains what the answers put there: referring practices and
  referrals, herds, natural identifiers, medicines and batches with
  every administration and dispensing, dated ownerships;
- two additions, confirmed: **requests** (an analysis or
  an imaging study ordered in a consultation) live in the core, so a
  lab result or a study can be traced back without the core reading a
  part; **alerts** (allergies, a dangerous animal, an infection) live in
  the core, as the record every display and part reads;
- trainees join the training centre in `vet-scheduling`; the teaching
  animals are core animals, the clinic their owner;
- the centres abroad are third parties (D274), and since D285 the other
  national centres too: a scenario deploys one centre, its redundancy a
  standby (D250).

## The data model (step 4)

On the confirmed split. The `clinic` database holds `vet-core` only:
each part lands where the scenario's `domains:` `at:` places it, in this
database or an instance of its own (procedure 5). Written in the shop's manner (`domains/shop/data/schema.sql`):
one database, here `clinic`, the tables unprefixed in `public` since the
core is no part (procedure 4), integer keys `GENERATED BY DEFAULT AS
IDENTITY`, explicit ids at load and each sequence set after its range
(`setval`, as the shop's `orders`). Every value is generated: names from
short lists, e-mail addresses `first.last.<id>@example.net`, identifiers
from their documented ranges.

**Growth through the year** (D279). Every daily volume of the history
(consultations, referrals, requests, stays, prescriptions,
administrations, dispensings, new owners and new animals) ramps
linearly from about 60 % of today's live rate a year ago to today's,
the weekday and hour shapes on top; reference tables and staff do not
grow. Monthly counts show the trend, and the live rates continue it.

### Entities

**Places and people**

| Table | Key, main columns |
|---|---|
| `business_settings` | one row: the customer's zone and offset, as the shop's; the records' retention, 5 years |
| `sites` | `id`; code, name, country, `kind` (`centre` or `abroad`); the sites other than the deployed centre are third parties (D274, D285), listed so transfers name them |
| `sections` | `id`; `site_id`, `kind` (`horse`, `farm`, `domestic`) |
| `staff` | `id`; name, e-mail, `kind` (`vet`, `nurse`, `technician`, `lab`, `carer`, `reception`, `instructor`), specialty, `home_site_id`, started on, left on |
| `staff_sites` | (`staff_id`, `site_id`): where a member also works |
| `owners` | `id`; `kind` (`person`, `stable`, `holding`, `clinic`), name, e-mail, phone, address, country, registered at |
| `herds` | `id`; the keeping owner, the holding number, the site that follows it |
| `animals` | `id`; species, breed, sex, born on, name, `food_chain` (`food-producing`, `excluded`, `not-applicable`) with the date and vet of an exclusion, one-way, `herd_id`; the natural identifiers `microchip`, `ueln`, `passport_number`, `ear_tag`, each unique when present; status, died at, how |
| `ownerships` | (`animal_id`, `owner_id`, `role`, `from_at`); `until_at`, open while current; `role` `owner` or `keeper`; one current owner per animal (a partial unique index) |
| `referring_practices` | `id`; name, address, country, e-mail |
| `referring_vets` | `id`; `practice_id`, name, e-mail |

**The medical record**

| Table | Key, main columns |
|---|---|
| `referrals` | `id`; animal, referring vet, receiving site, received at, reason, report sent at |
| `consultations` | `id`; an animal **or** a herd (a herd visit), site, section, vet, `kind` (`scheduled`, `emergency`, `herd-visit`, `in-hospital`), the referral or stay it belongs to, `booking_id` (`vet-scheduling`'s, by id), started at, ended at, findings, signed at |
| `diagnosis_codes` | `code`; label, species group, `notifiable` |
| `diagnoses` | `id`; consultation, code, confirmed, recorded at |
| `procedures` | `id`; consultation or stay, code, lead staff, anaesthesia, performed at |
| `requests` | `id`; consultation, animal, `kind` (`analysis`, `imaging`), test or study code, requested by, `external` (to an external lab), requested at |
| `stays` | `id`; animal, site, section, admitting vet, reason, admitted at, discharged at, `outcome` (`discharged`, `transferred`, `died`), the site transferred to |
| `alerts` | `id`; animal, `kind` (`allergy`, `dangerous`, `infectious`, `other`), text, from, until |

**Medicines**

| Table | Key, main columns |
|---|---|
| `medicines` | `id`; name, authorisation number, ATCvet code, form, `antimicrobial`, `controlled`, withdrawal days for meat and milk, allowed for a food-chain horse |
| `medicine_batches` | `id`; medicine, batch number, site, expires on, quantity received (at load only: stock receipts are out of v0.5) |
| `prescriptions` | `id`; consultation, an animal or a herd, vet, issued at, valid until (five days for an antimicrobial) |
| `prescription_lines` | `id`; prescription, medicine, dose, unit, frequency, days, `cascade`, meat and milk withdrawal days, withdrawal ends on |
| `administrations` | `id`; animal, stay, prescription line, medicine, batch, quantity, scheduled at, given at, given by |
| `dispensings` | `id`; prescription line, batch, quantity, to the owner, by, dispensed at |

### Lifecycle states

| Entity | States |
|---|---|
| Animal | `alive` → `died` (natural or euthanasia) |
| Ownership | current (`until_at` open) → ended; a sale ends one and opens the next |
| Referral | `received` → `accepted` → `closed` (report sent), or `declined` |
| Consultation | `open` → `closed` → `signed`, signed within a day by the vet (an unsigned record older than a day: a trap) |
| Request | `requested` → `sent` → `resulted`, or `cancelled`; `resulted` is the part's fact copied back by a purpose (a trap: two places for one fact) |
| Stay | `admitted` → `discharged`, `transferred` or `died` |
| Prescription | `issued` → `dispensed`, `expired` (an antimicrobial after five days) or `cancelled` |
| Administration | `scheduled` → `given`, `missed` or `cancelled` |

### Deterministic key ranges (D249, D266)

The load writes these ids; each sequence resumes after its range, so an
id created during the game is above it and never meets a part's load
(D276's ruling on key ranges).

| Key | Range | Layout |
|---|---|---|
| `sites.id` | 1–6 | 1–3 the national centres, 4–6 abroad |
| `sections.id` | 1–9 | site `s` holds `3s−2` (horse), `3s−1` (farm), `3s` (domestic) |
| `staff.id` | 1–250 | home sites in turn |
| `owners.id` | 1–30 000 | 1 the clinic (teaching animals); 2–601 holdings; 602–2 601 horse owners and stables; 2 602–30 000 pet owners |
| `herds.id` | 1–600 | herd `h` kept by owner `h + 1` |
| `animals.id` | 1–50 000 | 1–43 000 domestic; 43 001–47 000 horses; 47 001–50 000 farm animals, in herd `1 + (id − 47 001) mod 600` |
| `referring_practices.id` | 1–1 200 | |
| `referring_vets.id` | 1–2 400 | two per practice |
| `medicines.id` | 1–400 | antimicrobials and controlled drugs flagged |
| History | `consultations` 1–73 000, `prescriptions` 1–44 000, `administrations` 1–200 000, the others as loaded | in time order over the year |

**Natural identifiers.** A microchip is 15 digits, the country or
maker's 3 then 12 (ISO 11784/11785), present on every horse, dog and
cat and some other pets, missing on about 2 % of domestic animals; a
UELN (15 characters) and a passport number on every horse; an ear tag
(country code and 12 digits) on every farm animal; each a function of
the animal's id, so a part's load can write the same value without
reading the core. **A dozen mistyped chips** are planted at load: two
digits swapped against the value the parts' loads hold, so a lab result
or a portal record matches no animal (D278; a trap, step 8).

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret, as for the shop.

| Role | Reads | Writes |
|---|---|---|
| `vet` | owns everything; no login | |
| `vet_app` | every table | the record and the people the software keeps: owners, ownerships, animals, herds, referrals, consultations, diagnoses, procedures, requests, stays, alerts, prescriptions and lines, administrations, dispensings; never the reference tables (sites, sections, staff, codes, medicines, batches) |
| `vet_lookup` | the core's lookup API (D266, D267): `animals` without the death columns, `ownerships`, `owners`' id, kind and name (a column grant: no address, no phone) | nothing |
| `vet_display` | the view `animal_board` only: an animal's identity, its current stay, its alerts, its administrations of the day | nothing |
| `vet_reports` | every table, names and contacts included (the back office answers owners) | nothing |

The purposes' roles (the registers, the yearly antimicrobial report,
notifiable diseases) come with step 7.

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| Places and people (sites, sections, staff, practices, referring vets, owners, herds) | about 34 000 | 40 owners |
| Animals and ownerships | 50 000 and about 60 000 | 60 animals |
| Referrals | about 12 000 | about 40 |
| Consultations, diagnoses, procedures | 73 000, 90 000, 20 000 | 250 consultations |
| Requests | about 50 000 | about 170 |
| Stays, alerts | about 7 500, 5 000 | about 25 admissions |
| Medicines, batches | 400, about 2 000 | none |
| Prescriptions and lines | 44 000 and 110 000 | 150 prescriptions |
| Administrations, dispensings | 200 000 and about 65 000 | about 700 administrations, 220 dispensings |
| **Total** | **about 0.82 million rows** | **about 1 700 rows** |

Under the shop's 1.3 million rows, so within "the data schema stays
simple and the tables small" and, by the shop's measure (about 15
seconds to load, its node reserving 2.25G of disk), within the budget;
both are measured at the build.

### Plausibility points (step 4)

Offered to the owner; point 2 as he revised it (D279), the others as
drafted:

1. **Herds of five.** 3 000 farm animals over 600 herds is five each:
   the core registers only the animals the clinic has treated, not
   whole herds.
2. **Growth, history against live.** The clinic grew through the
   year: each daily volume ramps from about 60 % of today's rate to
   today's (about 420 to 700 administrations a day), the trend visible
   in the data; the GM notes compare history and live volume so
   (D276).
3. **Staff.** About 250 for three centres, 90 of them vets and
   specialists.
4. **The lookup API's reach.** Animals, ownerships and owners' names,
   never addresses or phones: the minimum a lab or the portal needs.
5. **A dozen mistyped chips**, two digits swapped.
6. **One day to sign a record**, an unsigned one older than that a trap.
## One centre: the rescale (proposed, O147)

The figures above were sized for one record shared by the three
national centres. Since each centre keeps its own and a scenario
deploys one (D285), the core holds one centre's record. Recommended:
**a third of each figure**, rounded, every ratio and D279's growth
curve kept. The other reading: keep today's figures as one very large
centre, 250 consultations a day at a single site.

**Population**, at load:

| What | Today (three centres) | One centre (proposed) |
|---|---|---|
| Sites | 6: 3 national centres, 3 abroad | 6: the centre, the 2 other national centres and 3 abroad, the 5 others third parties |
| Sections | 9 | 3: the centre's horse, farm and domestic sections |
| Staff | about 250, 90 vets and specialists | about 85, 30 vets and specialists |
| Owners | 30 000, of which about 600 holdings and 2 000 horse owners or stables | 10 000, of which 200 holdings and 700 horse owners or stables |
| Referring practices, their vets | about 1 200, 2 400 | 400, 800: the centre's region, the lab's customers among them (D285) |
| Animals | 50 000: 43 000 domestic, 4 000 horses, 3 000 farm | 17 000: 14 600 domestic, 1 400 horses, 1 000 farm animals in 200 herds of five |
| Hospitalised animals | about 120 | about 40 |

**History**, one year ramping from 60 % of today's rate (D279): about
25 000 consultations, 15 000 prescriptions (37 000 lines) and 70 000
administrations.

**Throughput**: about 85 consultations a day, 10 of them emergencies;
about 13 new owners and 20 new animals a day; about 240 administrations
a day (40 animals, a dose every four to eight hours); about 50
prescriptions a day.

**Reference sizes**: about 11 500 rows of places and people; 17 000
animals and 20 000 ownerships; 4 000 referrals; 25 000 consultations,
30 000 diagnoses, 7 000 procedures; 17 000 requests; 2 500 stays and
1 700 alerts; 400 medicines and 700 batches; 15 000 prescriptions and
37 000 lines; 70 000 administrations and 22 000 dispensings: **about
0.28 million rows**, about 570 a day live.

**Key ranges**: `sites.id` 1 the centre, 2–3 the other national
centres, 4–6 abroad; `sections.id` 1–3; `staff.id` 1–85; `owners.id`
1–10 000 (1 the clinic, 2–201 holdings, 202–901 horse owners and
stables, 902–10 000 pet owners); `herds.id` 1–200, herd `h` kept by
owner `h + 1`; `animals.id` 1–17 000 (1–14 600 domestic, 14 601–16 000
horses, 16 001–17 000 farm animals in herd `1 + (id − 16 001) mod 200`);
`referring_practices.id` 1–400, `referring_vets.id` 1–800, two per
practice; `medicines.id` 1–400; history `consultations` 1–25 000,
`prescriptions` 1–15 000, `administrations` 1–70 000. A dozen mistyped
chips, as ruled (D278).

**The model, for one centre**: `sites.kind` becomes `own`, `centre` or
`abroad`; `staff_sites` and the staff's home site go, the staff being
the centre's (D278's ninth answer read for one centre); the other
tables are unchanged.

**"A few sites stand for many" (D263), re-read for one centre**: the
centre is deployed whole, a few machines, boxes and rooms standing for
many; the five other sites, rows in `sites` and stubs among the
partners, stand for the franchise's network. The variant keeps its name
and tags, `multi-site` standing for the franchise reached through its
partners.

## Classification and governance (step 5, ruled, D280)

### Classification

v0.4's three classes (governance, D191), as the shop applies them in
`domains/shop/data/classification.yaml`: **personal**, a direct
identifier or a person's id stored beside one; **customer-linked**, a
customer's id with no direct identifier beside it; **internal**,
everything else. Keys are `<table>.<column>`, the scenario's copy adding
the database (procedure 6, item 2). The built file lists every column;
the table below gives the personal and customer-linked ones, every
other column of every table and view being `internal`.

Three readings for the clinic:

- **The customer is the owner.** An animal's id links to its owners
  through `ownerships`, so an animal's id with no identifier beside it
  is `customer-linked`, as the shop's `orders.customer_id` is; so is a
  herd's id, which links to its keeper.
- **A natural identifier is personal.** A microchip, a UELN, a passport
  number, an ear tag or a holding number leads to the owner or keeper
  through the national registries, so it is a direct identifier; the
  animal's own id, stored beside it, is personal too, as the shop's
  `customers.id`.
- Staff and referring vets are people: their names and e-mail
  addresses are personal, and their ids personal where stored beside
  them. Elsewhere a staff id or a referring vet's id is the clinic's
  work record (who examined, who referred), `internal`.

| Table | `personal` | `customer-linked` |
|---|---|---|
| `staff` | `id`, `name`, `email` | |
| `owners` | `id`, `name`, `email`, `phone`, `address`, `country` | |
| `herds` | `holding_number`, `id` | `keeper_owner_id` |
| `animals` | `id`, `microchip`, `ueln`, `passport_number`, `ear_tag` | |
| `ownerships` | | `animal_id`, `owner_id` |
| `referring_vets` | `id`, `name`, `email` | |
| `referrals` | | `animal_id` |
| `consultations` | | `animal_id`, `herd_id` |
| `requests` | | `animal_id` |
| `stays` | | `animal_id` |
| `alerts` | | `animal_id` |
| `prescriptions` | | `animal_id`, `herd_id` |
| `administrations` | | `animal_id` |
| `dispensings` | | `owner_id` |
| `animal_board` (view) | | `animal_id` |

Everything else is `internal`: sites, sections, the reference tables,
the medical content (findings, diagnoses, procedures, doses), the
animals' species, breed, name and food-chain status. Animal health is no
special category (O112): the record is `internal` once it no longer
carries its owner. Two traps follow (step 8): free text (findings, an
alert, a referral's reason) may name the owner, and the board the
displays read must carry no natural identifier.

**Where each class may live** is the scenario's `governance:` (D191,
D198), as for the shop; the domain only classes. The default policy
below says what the clinic expects of it.

### The business's own rules

The clinic's default policy (procedure 6, item 1): built as the domain's
`docs/policy.md` and a `governance:` fragment, which the GM copies and
adapts. Its home is an unnamed EU member state (D278): EU law applies as
written; where a rule is national, the policy takes one member state's
figure and says so. Sources were read on 2026-11-01 in the Official
Journal and on Légifrance and gesetze-im-internet.de (research for this
draft); a figure marked *game value* is a choice, not the law.

**Prescriptions.** A prescription states the animal or group, the
owner's or keeper's name and contact, the date, the vet and their
signature, the product with its form, strength and quantity, the dosage,
for a food-producing species the withdrawal period "even if such period
is zero", warnings, and whether the cascade was used (Regulation (EU)
2019/6, Art 105(5)). One for an antimicrobial is valid five days from
issue (Art 105(10)). Under the cascade, with no withdrawal period for
the species, the minimum is the product's longest period × 1.5, or 28
days for meat and 7 for milk when the product is not authorised for
food-producing animals (Art 115(1)–(2)).

**The medicines register.** Every supply of a prescription-only medicine
is recorded: date, product, form and strength, batch, quantity, the
recipient's name and address, the prescribing vet, the authorisation
number; records kept five years, with a yearly audit of stock against
them (Art 103(3), (5)). Germany applies this to vets (TÄHAV 2024, §§ 15,
16); France keeps its veterinary medicines register ten years (Code de
la santé publique, R5141-112). Game value: five years.

**The controlled-drugs register.** Every entry and exit of a narcotic
(ketamine, the opioids), a monthly balance signed by the vet, a yearly
inventory, destructions recorded. National law: France keeps it ten
years from its last entry (CSP R5132-36); Germany three years (BtMVV
§ 13(3)). Game value: ten years, the French rule.

**Antimicrobial use.** Member states collect antimicrobial-use data
from vets among others and report it yearly to the European Medicines
Agency (2019/6 Art 57; Delegated Regulation (EU) 2021/578, Art 13). The
collection is phased in: cattle (with pigs and poultry) from
30 September 2024; sheep, goats and horses from 30 June 2027; dogs and
cats from 30 June 2030 (2021/578, Art 15). The clinic records every
antimicrobial administration and dispensing for every species, and its
yearly report covers the species due at the time: today the cattle.

**Horses and the food chain.** A horse is in the food chain unless Part
II of its passport excludes it, a signed and irreversible declaration
(Implementing Regulation (EU) 2021/963, Art 38). Before an off-label
treatment the vet checks the status, and may have the keeper exclude the
horse first (Art 39(1)–(2)). A substance on the list essential for
equines, given to a food-chain horse, imposes a six-month withdrawal,
recorded in the passport (2019/6 Art 115(5); the list is Implementing
Regulation (EU) 2025/901; 2021/963 Art 39(3)).

**Food-producing animals.** Every administration and dispensing records
its withdrawal end; the keeper's own records are kept at least five
years (2019/6 Art 108(5)).

**Notifiable diseases.** A suspected or confirmed category A disease is
notified to the authority immediately; another listed disease as soon as
practicable (Regulation (EU) 2016/429, Art 18). Who must notify is
national law; the clinic's rule: the vet who records the diagnosis.

**Records signed within a day.** The clinic's own rule, no law behind
it: a consultation is signed by its vet within a day of closing.

**Retention.** No EU rule sets a period for clinical records; national
rules or the profession's do. A German chamber's example: five years
(Berufsordnung der Tierärztekammer Nordrhein, § 2(6), 2026); in France
no fixed period was found. Game values: clinical records five years from
the last entry, medicines five, controlled drugs ten; past them a record
is erased or anonymised.

**Owners' data (GDPR).** An owner's name and contacts are personal data;
an animal's record linked to an identifiable owner is that owner's
personal data, information relating to a person "by reason of its
content, purpose or effect" (Art 4(1); CJEU C-434/16, *Nowak*, para 35).
Animal health is not a special category (Art 9 covers a natural
person's health only). The policy: the least data per reader (the lookup
API without contacts, the displays without identifiers); no personal
data in the logs; an owner with no record left within retention erased
or anonymised; an erasure request limited by the medicine records the
law keeps five years.

**What the portal may release, and when.** An owner sees the animals
they own now, and their records from their own ownership only, never a
former owner's identity; a result once a vet has validated it, and a
consultation once it is signed; no staff contact beyond the clinic's.

**What the data model took from these rules** (above): the date and
vet of a horse's exclusion from the food chain, one-way; the cascade
flag and the meat and milk withdrawal days on `prescription_lines`; the
authorisation number on `medicines`. The registers'
monthly balances and yearly reports are purposes (step 7), their past
periods planted (D265).

### The rules, as the owner confirmed them (D280)

The owner judged them realistic on 2026-11-01 ("they're great"), with
the classification above.

1. **Prescriptions** carry the contents of Regulation (EU) 2019/6 Art
   105(5); an antimicrobial one is valid five days (Art 105(10)); the
   cascade's minimum withdrawals apply (Art 115).
2. **The medicines register** records every supply with its batch, kept
   five years (Art 103(3), (5)); five years in the game, though France
   keeps ten (CSP R5141-112).
3. **The controlled-drugs register**: every movement, a monthly signed
   balance, a yearly inventory, kept ten years (France, CSP R5132-36;
   Germany three, BtMVV § 13).
4. **Antimicrobial use**: recorded for every species; the yearly report
   covers the species due, cattle today, sheep, goats and horses from
   mid-2027, dogs and cats from mid-2030 (2021/578 Arts 13, 15).
5. **Horses**: in the food chain unless excluded, the exclusion
   irreversible; an essential substance imposes six months' withdrawal
   (2021/963 Arts 38, 39; 2019/6 Art 115(5); 2025/901).
6. **Food-producing animals**: every treatment records its withdrawal
   end (2019/6 Art 108).
7. **Notifiable diseases**: category A immediately, other listed
   diseases as soon as practicable, by the vet who records the
   diagnosis (2016/429 Art 18).
8. **Records signed within a day**: the clinic's own rule.
9. **Retention**: clinical records five years (no EU rule; Tierärztekammer
   Nordrhein § 2(6)), medicines five, controlled drugs ten; then erased
   or anonymised.
10. **Owners' data**: personal, an animal's record the owner's personal
    data, not a special category (GDPR Arts 4(1), 9; *Nowak*); least
    data per reader, none in the logs, erasure bounded by the legal
    retention.
11. **The portal**: an owner sees their current animals and their own
    ownership's records; results once validated, consultations once
    signed; never a former owner.
