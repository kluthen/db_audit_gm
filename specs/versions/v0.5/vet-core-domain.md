# v0.5 — `vet-core`, the clinic's core domain

Status: draft v11, the draft document of procedure step 9, its stale
passages corrected to the master spec at approval (R16, D339).
**Approved by the owner on 2026-11-03 with v0.5's
[master spec](master-spec.md)** (procedure step 9, D339), which wins
where the two disagree. Amended in wave 2 of the build (2026-11-04):
the key functions, their set, signatures and returns, and
`core_request`'s contract (D374, D375, D378, D379); the identifiers'
species and codes (D379); the code catalogues their parts' (D372,
D373). Steps 2 to 8 are done: the business sketch ruled (D266, D278), its first
answer revised by one centre per scenario (D285); the split confirmed
(D279), the parts one centre's (D293); the data model current at one
centre's scale (D279, D280, D295), `requests` revised by `vet-lab`'s
answers (D301, D302), `exchanges` and the disease's category added with
the purposes (D306); classification and governance ruled (D280); the
producer profiles ruled (D303, D304), amended by the purposes (D306);
the purposes ruled (D306, D307) in [clinic-purposes.md](clinic-purposes.md);
the traps listed (step 8, no owner checkpoint, D309) in
[clinic-traps.md](clinic-traps.md). A sent request is cancelled by the
lab only (D315). On 2026-11-03 the four remaining parts folded in
(D317–D325, draft v10): the staff layout, the stays, species, deaths and
infectious alerts as functions of their ids, the history's
consultations matching scheduling's bookings, `consultations.open`
replaced by scheduling's check-in, the census endpoint, the imaging
team cancelling a sent imaging request, and the parts' roles and grants
(D324); a part's load computes these, never reading `clinic`, the GM
checking the composed load's coherence (D322). The format finalised in
[formats.md](../../formats.md) v28 at consolidation (D338).

`vet-core` is the core of the veterinary clinic franchise (D196), the
first domain defined through the [procedure](domain-procedure.md)
(D235, D260). By the procedure's first cut it holds the keys every part
shares, owners, animals, sites and staff, and the medical record:
consultations, treatments and prescriptions (section 4). The brief is the
owner's, quoted in the [version page](README.md#the-veterinary-clinic-d196).

## The draft at a glance (step 9)

Where each item of the domain's folder, `domains/vet-core/`, is stated
on this page or beside it (procedure 1 and 3; the format is finalised
in the master spec, O111):

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-core`, the core of a composite (no `requires`), its parts `vet-lab`, `vet-scheduling`, `vet-housing`, `vet-machinery`, `vet-portal` (D293), the purposes that fit | [The split](#the-split-step-3-confirmed-d279); [Purposes that fit](#purposes-that-fit-step-7) |
| `variants/regional-franchise.yaml`: the three scale axes and the tags (D263) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/schema.sql`: tables, keys, states, roles and grants | [The data model](#the-data-model-step-4) |
| `data/load.sql`: the year's history and the state at T0 | [Deterministic key ranges](#deterministic-key-ranges-d249-d266), [Intensity and the history](#intensity-and-the-history-before-t0-d276-d279), [Loading](#loading) |
| `data/classification.yaml`: every column classed | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment: the business's own rules | [The rules](#the-rules-as-the-owner-confirmed-them-d280) |
| `producers/`: the practice software's fragments (`pms`), the lookup API's endpoints (`producers/api/clinic-api/`), the other centres' stubs (`producers/partners/centres/`, D303, D306) | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; the traps in [clinic-traps.md](clinic-traps.md); [Loading](#loading) |

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
`regional`, `regulated`, `multi-site` and `24/7` (question 13),
`multi-site` standing for the franchise reached through its partners.
Its scale, on the three axes, is **one centre's** (D285, D295): a third
of the figures first sized for one record shared by the three national
centres (D278), every ratio and the growth curve kept. Within "the data
schema stays simple and the tables small" ([platform.md](../../platform.md));
the shop holds about 1.3 million rows, the core stays well under it.

**Population**, at load:

| What | How many |
|---|---|
| Sites | 6: the centre, the 2 other national centres, 3 abroad; the 5 others third parties (D285) |
| Sections | 3: the centre's horse, farm and domestic sections |
| Staff | about 85, 30 of them vets and specialists |
| Owners | 10 000, of which 200 holdings and 700 horse owners or stables |
| Referring practices | 400, two vets each: the centre's region, the lab's customers among them (D294) |
| Animals | 17 000: 14 600 domestic, 1 400 horses, 1 000 farm animals in 200 herds |
| Hospitalised animals | about 40 at any time |

**History**: one year of a clinic that grew through it (D279): each
daily volume ramps from about 60 % of today's rate a year ago up to
today's, so the year holds about 25 000 consultations, 15 000
prescriptions (37 000 lines) and 70 000 administrations, and the
players can see the growth in the data.

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Consultations | about 85 a day, 10 of them emergencies |
| New owners, new animals | about 13 and 20 a day |
| New referring practices | a few a month |
| Administrations | about 240 a day: 40 animals, a dose every four to eight hours |
| Prescriptions | about 50 a day |

**A few stand for many** (D263), read for one centre: the centre is
deployed whole, a few machines, boxes and rooms standing for many; the
five other sites, rows in `sites` and stubs among the partners, stand
for the franchise's network.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Business hours, Monday to Saturday | consultations, registrations, prescriptions; the domestic section's busiest hours late afternoon, horse and farm mornings | yes |
| Around the clock | emergencies (a third at night), administrations in hospital, the rounds at fixed hours | yes |
| Daily | discharges late in the morning, the records closed and signed, the controlled-drugs count; vaccination reminders, `vet-portal`'s, with the owner's consent (each animal once a year, its due day a function of its id, D304, D320); no appointment reminders in v0.5 (D321) | yes |
| Weekly | herd-health visits on fixed weekdays; the staff rota, published by `vet-scheduling`'s `sched.rota.publish` (Friday 12:00) | only if the day falls within the aging: a weekday shape, not a job |
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
| `vet-lab` | the request that orders an analysis, tied to its consultation, animal and requesting vet, with its priority (D301), so a result can be traced back and released; the animal's natural identifiers, which an external lab's result carries (D266, D268); the animal's food-producing status for residue tests; the referring practices, by id, as the lab's outside customers (D294) |
| `vet-portal` | the owner as a stable key, one portal account each; who owns an animal **now**, and since when: a horse is sold, a dog changes family (D278); what of the record an owner may see: signed consultations, ended stays, the lab's released results; every owner with an e-mail; the sync's watermarks the core's own columns (`registered_at`, `from_at`, `until_at`, `died_at`, `signed_at`, `discharged_at`); the copied content derived after the load by a step the GM sanctions (D320, D322) |
| `vet-housing` | the hospital stay a unit holds, by id, with its section, its admission and its end (D278); the animal's species, so a unit fits it; current `infectious` alerts, so the animal goes to isolation; staff by the layout (nurses, carers); what a display shows, through `animal_board`; the administrations, so the care log never records a dose (vet-housing T165). The part lands in `clinic` (`lands_with: vet-core`, D318, D322): its roles read `stays`, `animals`, `alerts` and `staff` in place while running, by column grants its schema gives; its load computes them by the functions below, never reading them |
| `vet-scheduling` | staff with their kind, section and specialty, functions of the id; the consultation a booking turns into, by `booking_id`; the imaging requests; the teaching animals in a range; the deaths (the core holds no rooms: they are the part's, D279, D317) |
| `vet-machinery` | the imaging request a study belongs to, its study code one of the part's 30 procedure codes; the animal; the stays as functions of their id and the current ones through `GET /stays?current=true` (the census); the imaging staff in the layout (D319, D324) |
| The franchise's messaging service, a third party (D293) | staff as the senders and recipients, through the centre's outbox |
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
   Answer: yes, about 1 200 practices then, 400 at one centre's scale
   (D295), a consultation carrying its referral; the report back to the referring vet is a purpose, later.
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
   (D248). Narrowed by D294: the lab bills its outside customers, in
   `vet-lab`.
9. **Staff.** Answer: one staff table: vets with their specialties,
   nurses and technicians, lab staff, carers and grooms, receptionists,
   instructors, all the centre's since one centre is deployed (D295;
   first drafted with a home site and other sites worked at);
   the applications log in with roles of their own, never one database
   login per person, as in the shop.
10. **The training centre.** Does "canine and horse dedicated training"
    mean training people (vets, nurses, owners, handlers), or training
    animals? Answer: training people, with the clinic's own teaching
    animals; trainees are not staff and live in `vet-scheduling`; the
    teaching animals are core animals, the clinic their owner.
11. **Scale and hours.** Answer: the figures in "The variant" and
    "Cadences", first given for the three centres (30 000 owners, 50 000
    animals, 250 consultations a day) and rescaled to one centre by
    D295: 10 000 owners and 17 000 animals, a year of history, about 85
    consultations a day, about 40 animals in hospital, emergencies
    around the clock.
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
D278, confirmed by the owner with both additions (D279); the parts are
one centre's, `vet-messaging` leaving for the franchise (D293).

| Domain | What it holds |
|---|---|
| `vet-core` | sites and sections; staff; owners and their dated ownerships and keepers; animals with their natural identifiers, herds; referring practices, their vets and referrals; consultations, diagnoses, procedures; requests for analyses and imaging; hospital stays; medicines and their batches, prescriptions, administrations, dispensings; alerts on an animal |
| `vet-lab` | samples and analyses for the core's requests, instrument batch uploads, results, a vet's validation before release; orders to and results from the external labs, a round trip with a third party (D268, D274); the region's clinics' orders, their accounts, prices and monthly statements (D293, D294) |
| `vet-scheduling` | rooms and machines' slots, bookings of staff, rooms and machines; the training centre's courses, sessions and trainees |
| `vet-housing` | boxes and stalls, the placements of the core's stays, care and feeding logs; the displays, reading the core's board of each animal |
| `vet-machinery` | the machines, studies for the core's imaging requests, readings and logs, each machine's own database |
| `vet-portal` | owners' accounts, one per core owner; consents; notifications; what was released to whom |

Not domains: **regulatory reporting**, purposes fitting `vet-core` and
`vet-lab` (step 7); **billing**, a later part (D278), but for the lab's
outside customers, billed in `vet-lab` (D294); **pharmacy stock**
(receipts, ordering), out of v0.5 (D278); the **other national
centres**, the **centres abroad**, the **franchise's central systems**
and the **external labs**, third parties (D274, D285); **messaging**,
the franchise's service, a third party (D293;
[one-centre.md](one-centre.md) 1).

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
| `sites` | `id`; code, name, country, `kind` (`own`, `centre` or `abroad`); the sites other than the deployed centre are third parties (D274, D285), listed so transfers name them |
| `sections` | `id`; `site_id`, `kind` (`horse`, `farm`, `domestic`) |
| `staff` | `id`; name, e-mail, `kind` (`vet`, `nurse`, `technician`, `lab`, `carer`, `reception`, `instructor`), specialty, started on, left on: the centre's staff (D295) |
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
| `consultations` | `id`; an animal **or** a herd (a herd visit), site, section, vet, `kind` (`scheduled`, `emergency`, `herd-visit`, `in-hospital`), the referral or stay it belongs to, `booking_id` (`vet-scheduling`'s, by id; unique when present, a partial unique index `WHERE booking_id IS NOT NULL`, D317), started at, ended at, findings, signed at |
| `diagnosis_codes` | `code`; label, species group, `notifiable` (`none`, `A` or `other`: a category A disease notified within the hour, another listed disease within the day, D306) |
| `diagnoses` | `id`; consultation, code, confirmed, recorded at |
| `procedures` | `id`; consultation or stay, code, lead staff, anaesthesia, performed at |
| `requests` | `id`; consultation, animal, `kind` (`analysis`, `imaging`), test or study code, requested by, `priority` (`routine`, `urgent`), requested at; whether a test goes out is the lab's routing, not the request's (D301) |
| `stays` | `id`; animal, site, section, admitting vet, reason, admitted at, discharged at, `outcome` (`discharged`, `transferred`, `died`), the site transferred to |
| `alerts` | `id`; animal, `kind` (`allergy`, `dangerous`, `infectious`, `other`), text, from, until |
| `exchanges` | `id`; `direction` (`out`, `in`), `kind` (`transfer`, `examination`), the partner site, the animal, or for an inbound request `partner_patient`, the partner's patient summary, until the animal is registered; reason, `exchange_key` (a UUID, the round trip's correlation key), requested at, the answer (an accepted date, or declined) and answered at, report at, state: the record of an exchange with another centre; its messages are the purpose's trace (D306) |

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
| Request | `requested` → `sent` → `resulted`, or `cancelled` (by the vet while `requested`; once `sent`, by the lab or, for imaging, by the imaging team, copied back, D315, D324); `resulted` is the part's fact copied back by a purpose (a trap: two places for one fact) |
| Stay | `admitted` → `discharged`, `transferred` or `died` |
| Exchange | out: `requested` → `sent` → `accepted` or `declined`, an accepted examination → `reported`; in: `received` → `accepted` or `declined`, an accepted examination → `reported` (D306) |
| Prescription | `issued` → `dispensed`, `expired` (an antimicrobial after five days) or `cancelled` |
| Administration | `scheduled` → `given`, `missed` or `cancelled` |

### Deterministic key ranges (D249, D266)

The load writes these ids; each sequence resumes after its range, so an
id created during the game is above it and never meets a part's load
(D276's ruling on key ranges). Two constraints came from `vet-lab`'s
load (D302): the lab's staff in a range, and each request a function
of its id; the other parts' loads added the staff layout, the history's
consultations, stays, species, deaths and infectious alerts as
functions of their ids (D317–D319, D322, D324). Each function is
documented in the GM notes, under the names the parts' "Core keys used"
cite ([procedure](domain-procedure.md) 10).

| Key | Range | Layout |
|---|---|---|
| `sites.id` | 1–6 | 1 the centre (`own`), 2–3 the other national centres, 4–6 abroad |
| `sections.id` | 1–3 | 1 horse, 2 farm, 3 domestic, all the centre's |
| `staff.id` | 1–85 | one layout (D324, D327): 1–25 the sections' vets (1–10 horse, 11–17 farm, 18–25 domestic, eight instead of eleven so the imaging staff fit, specialties by id); 26–28 vets, specialty diagnostic imaging (`vet-machinery`'s reporters); 29–51 the sections' nurses and technicians (kind and section by id); 52–55 radiographers and 56 the biomedical engineer (`kind` `technician`); 57–66 carers and grooms (`kind` `carer`); 67–70 receptionists; 71–78 the lab's technicians (`kind` `lab`), 79–80 its clinical pathologists (`kind` `vet`, specialty clinical pathology, D302); 81–85 instructors. Kind, section and specialty a function of the id; the night vet rotates over 1–25, the imaging vets 26–28 keeping their own on-call ([vet-scheduling](vet-scheduling-domain.md)'s rota, D339) |
| `owners.id` | 1–10 000 | 1 the clinic (the teaching animals, below); 2–201 holdings; 202–901 horse owners and stables; 902–10 000 pet owners |
| `herds.id` | 1–200 | herd `h` kept by owner `h + 1` |
| `animals.id` | 1–17 000 | 1–14 600 domestic; 14 601–16 000 horses; 16 001–17 000 farm animals, in herd `1 + (id − 16 001) mod 200`; each animal's species a function of its id; the teaching animals 1–12 (dogs) and 14 601–14 608 (horses), owned by owner 1 from before the history, never patients (D317); the history's deaths (which animals, when) a function of the id (D317) |
| `referring_practices.id` | 1–400 | |
| `referring_vets.id` | 1–800 | two per practice |
| `medicines.id` | 1–400 | antimicrobials and controlled drugs flagged |
| History | `consultations` 1–25 000, `prescriptions` 1–15 000, `administrations` 1–70 000, `exchanges` 1–700, the others as loaded | in time order over the year; each consultation's kind, section, vet and start a function of its id, a scheduled one's `booking_id` its own id and its vet one the rota's pattern puts on shift ([vet-scheduling](vet-scheduling-domain.md), step 6; D317) |
| `stays.id` | 1–2 500 | each stay's animal, section, admitted at, discharged at and outcome a function of its id, and the infectious alert current on it (from, until) a function of the stay's id (D319, D322); at any time about 14 horses, 6 farm animals and 20 domestic animals of the 40 current, never more current stays in a section than its units in service (21 horse, 10 farm, 31 domestic, species fitting; D318) |
| `requests.id` | 1–17 000 | each request's kind (about one in five imaging), test code, priority, consultation, animal and time computed from its id, documented in the GM notes, so `vet-lab`'s load computes the same and groups a consultation's analysis requests into one order, without reading the core (D302); an imaging request's study code one of `vet-machinery`'s 30 procedure codes, drawn by the documented function of its id among those valid for the animal's species group (1–12 domestic, 13–27 horses and farm but 26 and 27 horses only, 28–30 any), at that page's modality shares (D319, D373); the codes and their draw are [the lab's test catalogue](vet-lab-domain.md#the-test-catalogue-d372) and [the machinery's procedure catalogue](vet-machinery-domain.md#the-procedure-catalogue-d372-d373) (D372) |

**Natural identifiers.** A microchip is 15 digits, the country or
maker's 3 then 12 (ISO 11784/11785), present on every horse, dog and
cat and some other pets, missing on about 2 % of domestic animals:
every dog, cat, horse and ferret carries one, and two rabbits in three
none, rabbits being about 3 % of the domestic animals (D379); a
UELN (15 characters) and a passport number on every horse; an ear tag
(country code and 12 digits) on every farm animal; each a function of
the animal's id, so a part's load can write the same value without
reading the core. **A dozen mistyped chips** are planted at load: two
digits swapped against the value the parts' loads hold, so a lab result
or a portal record matches no animal (D278; a trap, step 8). The
unnamed member state's codes are fictional, so no identifier points at
a real registry (D379): `XA`, ISO 3166-1's user-assigned alpha-2, on
the ear tags and passports; one user-assigned numeric code of 900–998
(never 999, ISO 11784's test code) as a chip's first three digits and
a UELN's country part, the GM notes naming it.

### The key functions (D374, D375, D379)

The core's `data/keys.sql` defines them as `pg_temp.core_<name>`, which
`load-data` streams ahead of the core's load, every part's load, every
partner `data.sql` and `derive.sql` (capture W2, item 3); `docs/gm.md`'s
"Core keys" documents each with its SQL. **This is the set**, and what
each returns is the contract the parts' loads rely on. The formulas are
the build's (master spec 24), within the ranges and figures of this
page; no part re-derives what a function returns.

**Signatures** (D379). An id function takes `(n integer)`. A function
computing a time takes `(n integer, load_epoch timestamptz, utc_offset
integer)`: `load_epoch` is the run's psql variable, the load's "now";
`utc_offset` is `customer_utc_offset` in hours, the customer's zone
being a fixed `Etc/GMT` offset, so the shapes' local hours need no
zone name. Every function is `IMMUTABLE`, a pure function of its
arguments, and returns no row for an id outside its range.

| Function | Returns | Read by |
|---|---|---|
| `core_staff(n)` | `kind`, `section_id`, `specialty`: the layout above | every part |
| `core_shifts(n, day date, utc_offset)` | staff `n`'s shifts starting on that local day by the rota's pattern ([vet-scheduling](vet-scheduling-domain.md), step 6): rows of `kind` (`day`, `late`, `night`, `on-call`), `starts_at`, `ends_at`, `absence` (null, or `leave`, `training`, `absent` when one of the history's absences covers the shift; about 600 absences a year, leave nine in ten) | `vet-scheduling` (its shifts and absences); the core's own pick of a consultation's vet, among shifts with no absence |
| `core_species(n)` | the animal's species | housing, machinery, lab |
| `core_animal(n, load_epoch, utc_offset)` | `species` (`core_species`'), `breed`, `sex`, `born_on`, `name`, `food_chain`, an exclusion's date and vet, `herd_id`, `registered_at` | lab (an order's species, sex, age), machinery (the worklist's identity), portal |
| `core_microchip(n)`, `core_ueln(n)`, `core_passport(n)`, `core_ear_tag(n)` | the identifier as the parts hold it, null where the animal has none; the dozen mistyped chips are the core's load's own swap, never the function's | lab, machinery, portal |
| `core_holding(h)` | herd `h`'s holding number | the core's load; no part in v0.5 |
| `core_owner(n, load_epoch, utc_offset)` | `kind`, `name`, `family_name` (a person's surname; a stable's, holding's or the clinic's name whole), `email`, `phone`, `registered_at`; never the address | portal (an account's name, e-mail and phone; the owners' route), machinery (a study's patient name and responsible person) |
| `core_ownership(n, load_epoch, utc_offset)` | animal `n`'s ownerships over the year, every row: `owner_id`, `role` (`owner`, `keeper`), `from_at`, `until_at` (null while current); one current owner, a sale ending one row and opening the next | portal (keepers, consent events), machinery (the owner at a study's time) |
| `core_death(n, load_epoch, utc_offset)` | `died_at` and how, for an animal of the history that died; no row otherwise | scheduling, portal |
| `core_consultation(n, load_epoch, utc_offset)` | `kind`, `section_id`, `vet_id`, `animal_id` or `herd_id`, `stay_id` (in hospital), `referral_id`, `started_at`, `closed_at`, `signed_at`, `booking_id` (its own id when `scheduled`, else null) | scheduling, lab and machinery (through their requests), portal |
| `core_stay(n, load_epoch, utc_offset)` | `animal_id`, `section_id`, `admitted_at`, `discharged_at` (null while current), `outcome`, the site transferred to | housing, machinery, portal |
| `core_stay_alert(n, load_epoch, utc_offset)` | stay `n`'s `infectious` alert: `from_at`, `until_at`; no row when none | housing |
| `core_request(n, load_epoch, utc_offset)` | below (D375) | lab, machinery, scheduling |
| `core_exchange(n, load_epoch, utc_offset)` | `direction`, `kind`, `site_id` (the partner centre), `animal_id` (null for an inbound one whose animal is not registered), `stay_id` (a transfer's, its stay `transferred`), `exchange_key` (a UUID, a function of the id), `requested_at`, `state`, the answer (an accepted date, or declined) and `answered_at`, `reported_at` | scheduling (the inbound examinations' dates), the centres' stubs (their `data.sql`, chunk 19) |
| `core_referring_practice(v)` | referring vet `v`'s practice, two vets a practice (by default `(v + 1) / 2`) | scheduling (`sched_trainees`), the core's own `referring_vets` (D378) |

A prescription line's withdrawal end has no function of its own: the one
part reading it, the lab's residue screening, gets it from the request
(`withdrawal_ends_on`, below).

**`core_request`** (D375) returns, for each request of the history:

- `kind`: about one in five `imaging`, its share by section setting
  the imaging mix, about 60 % domestic, 30 % horses, 10 % farm;
- `code`: drawn by the catalogues' draw, [the lab's
  tests](vet-lab-domain.md#the-test-catalogue-d372) or [the
  machinery's procedures](vet-machinery-domain.md#the-procedure-catalogue-d372-d373),
  valid for the animal;
- `consultation_id`, `animal_id` (the consultation's, or for a herd
  visit an animal of the herd), `requested_by`
  (the consultation's vet), `requested_at` (at its close, which writes
  the request);
- `priority`: the consultation's, `urgent` for an emergency's or a
  stay's (`in-hospital`), `routine` otherwise, as `consultations.close`
  writes it;
- `state` at T0 and its times: `resulted` (with `sent_at`,
  `resulted_at`) or `cancelled` (`cancelled_at`; with `sent_at` when the
  part cancelled it after sending, without when the vet did before),
  but a request of the last 24 hours before `load_epoch` `sent`, or
  `cancelled` by the vet. None is `requested` at T0: a request is
  written at its consultation's close and sent within minutes;
- `withdrawal_ends_on`: for the milk inhibitor test only, the milk
  withdrawal end of the prescription line it checks, which the core's
  load holds; null otherwise.

The parts fit their own times inside these: a lab release, or an
imaging final report, falls before `resulted_at` by the copying
purpose's lag, within the code's turnaround from `sent_at` (the lab's
catalogue; imaging urgent 18 hours, routine three working days, D376);
a part's cancellation before `cancelled_at`. Only the sent requests
reach a part's load.

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret, as for the shop.

| Role | Reads | Writes |
|---|---|---|
| `vet` | owns everything; no login | |
| `vet_app` | every table | the record and the people the software keeps: owners, ownerships, animals, herds, referrals, consultations, diagnoses, procedures, requests, stays, alerts, exchanges (recorded, decided, reported), prescriptions and lines, administrations, dispensings; never the reference tables (sites, sections, staff, codes, medicines, batches) |
| `vet_lookup` | the core's lookup API (D266, D267): `animals` without the death columns, `ownerships`, `owners`' id, kind and name (a column grant: no address, no phone); `stays`' `id`, `animal_id`, `section_id`, `admitted_at`, `discharged_at` for the census (D319) | nothing |
| `vet_display` | the view `animal_board`: an animal's identity, its current stay, its alerts, its administrations of the day; where `vet-housing` lands in `clinic`, its view `housing_unit_board` too, granted by that part's schema (D287, D318) | nothing |
| `vet_reports` | every table, names and contacts included (the back office answers owners), those of a part landing in `clinic` too (`vet-scheduling`'s and `vet-housing`'s, granted by their schemas) | nothing |

The purposes' roles (the registers, the yearly antimicrobial report,
notifiable diseases) come with step 7, drafted in
[clinic-purposes.md](clinic-purposes.md#the-roles-the-purposes-add); the periodic reports read on the
standby and write to the back-office database, `office`, never to
`clinic` ([replication.md](replication.md) 1, 3; D299, D300). The
parts' purposes add `vet_interfaces` grants on the core: `INSERT` on
`consultations`' open columns (`vet-bookings-sync`'s check-in) and
`SELECT` on `animals`' `id`, `status` and `died_at` (D317).

**`CONNECT` by name.** `CONNECT` on `clinic` is granted to the core's
login roles and the parts' landing there by name and revoked from
`PUBLIC`, so the portal's role on the same instance cannot open the
record's database (vet-portal rule 10, T253); the same for `office`,
its roles the purposes' (D320).

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| Places and people (sites, sections, staff, practices, referring vets, owners, herds) | about 11 500 | 13 owners |
| Animals and ownerships | 17 000 and about 20 000 | 20 animals |
| Referrals | about 4 000 | about 13 |
| Consultations, diagnoses, procedures | 25 000, 30 000, 7 000 | 85 consultations |
| Requests | about 17 000 | about 55 |
| Stays, alerts | about 2 500, 1 700 | about 8 admissions |
| Exchanges | about 700 | about 2, either way |
| Medicines, batches | 400, about 700 | none |
| Prescriptions and lines | 15 000 and 37 000 | 50 prescriptions |
| Administrations, dispensings | 70 000 and about 22 000 | about 240 administrations, 75 dispensings |
| **Total** | **about 0.28 million rows** | **about 570 rows** |

Under the shop's 1.3 million rows, so within "the data schema stays
simple and the tables small" and, by the shop's measure (about 15
seconds to load, its node reserving 2.25G of disk), within the budget;
both are measured at the build.

### Plausibility points (step 4)

Offered to the owner; point 2 as he revised it (D279), the others as
drafted, the figures one centre's (D295):

1. **Herds of five.** 1 000 farm animals over 200 herds is five each:
   the core registers only the animals the clinic has treated, not
   whole herds.
2. **Growth, history against live.** The clinic grew through the
   year: each daily volume ramps from about 60 % of today's rate to
   today's (about 145 to 240 administrations a day), the trend visible
   in the data; the GM notes compare history and live volume so
   (D276).
3. **Staff.** About 85 for one centre, 30 of them vets and
   specialists.
4. **The lookup API's reach.** Animals, ownerships and owners' names,
   never addresses or phones: the minimum a lab or the portal needs.
5. **A dozen mistyped chips**, two digits swapped.
6. **One day to sign a record**, an unsigned one older than that a trap.
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
| `exchanges` | `partner_patient` (an inbound request's summary, which may name the owner; classed by the readings above when D306 added the table) | `animal_id` |
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

## The producer profiles (step 6)

Drafted on 2026-11-02 with `vet-lab`'s, since their flows interlock
([vet-lab-domain.md](vet-lab-domain.md#the-producer-profiles-step-6)):
the core's consultations create requests, the lab takes them through its
order API, analysers upload, results come back, and the partners' round
trips run around both. Ruled as drafted on 2026-11-02 (D304, closing
O153), with what the profiles need of the scheduler and the format
([producer profiles](producer-profiles.md#12-what-the-clinics-first-profiles-need-ruled-d303)
12, D303, closing O154).
Built on the ruled frictions (D264–D271, D276, D277, D287, D288,
D296–D300) and not reopening them.

**Producer or purpose.** By the procedure, a flow between parts or out
to a partner is a purpose (procedure 4, step 7), and so is every
periodic report (D300). This step holds what the core's own
applications write into `clinic`, the rates and timings of every flow
the core takes part in, and the history the load plants to meet them.
The flows themselves (posting the requests to the lab, the results
coming back, the exchanges with the other centres, the reports) are
named here with their rates and left to step 7.

### The applications and their nodes (D276)

| Application | Node | Connection, role | What it does |
|---|---|---|---|
| The practice-management software | `pms`, a scheduler node | `clinic`: `records:5432/clinic` (or the scenario's pooler), `vet_app` | everything the clinic's staff record: registrations, referrals, consultations and their diagnoses, procedures, requests and prescriptions, stays, the rounds' administrations; it also carries, one application (D276): `vet-scheduling`'s fragments (connection `sched`, `sched_app`), `vet-housing`'s (connection `housing`, `housing_app`) and `vet-portal`'s desk fragment, `portal.desk-consent`, an HTTP stream to `portal-api` with the desk's credential (D317, D318, D320) |
| The core's lookup API (D266, D267) | `clinic-api`, an `api` node in the players' scope | `vet_lookup` | only answers (D270): `GET /animals/{id}`, `GET /animals?microchip=` (or `ueln`, `ear_tag`), `GET /animals/{id}/owner` (the current owner's id, kind and name, never a contact); no stream of its own; its callers are the parts' producers, `vet-lab`'s first ([vet-lab](vet-lab-domain.md#the-applications-and-their-nodes-d276)), then `vet-machinery`'s `mach.identity` (about 11 pairs a day) and `mach.census` (288 calls a day) on `GET /stays?current=true` (stay id, animal id, section, admitted at, the animal's name and species; D319); and the exchange endpoints `vet-centre-exchanges` brings, `POST /exchanges`, `POST /exchanges/{key}/answer` and `/report`, as `vet_exchange` (D306), called by the other centres' stubs |

Not the core's producers: the housing displays reading `animal_board`
as `vet_display` are `vet-housing`'s ward service, `ward` (D287, D318); the reports
reading as `vet_reports` are purposes (below). The fragments are
written for the node names `pms`, `records` and `clinic-api` and the
database `clinic`; the GM renames them as the scenario does, as the
shop's (`docs/gm.md`, "The producer").

**Readable, never planted (D276).** The fragments sit in the
repository for anyone to read, as the shop's do; the rendered
`schedule.yaml` stays root-only on the node (D130). A fragment holds no
timeline, no intensity and no planted fault; a fault riding the
schedule brings its own keys and timeline change in its material.

### Rates at intensity 1.0

The rates are `regional-franchise`'s throughput (D263, D276): real-world
rates, at intensity 1.0, before the shape. A **volume** stream's rate
makes the daily volume; a **work** stream takes the oldest item waiting
(a consultation to close, a referral to accept) and finds nothing when
nothing waits, so its rate is a capacity, set at least twice the
busiest hour's arrivals, and its volume follows the volume streams. A
work stream short of capacity builds a backlog: a fault vector, never
the design.

Volume streams, on `clinic` as `vet_app`:

| Key | What one call writes | Rate | Arrivals, shape | A day: Mon–Fri / Sat / Sun / average |
|---|---|---|---|---|
| `owners.register` | a new owner, their first animal (the species mix of the load: 86 % domestic, 8 % horses, 6 % farm animals of an existing herd) and its ownership | 1.6/h | poisson, `clinic-day` | 17 / 6 / 0 / 13 |
| `animals.register` | an animal for an existing owner, its ownership | 0.86/h | poisson, `clinic-day` | 9 / 3 / 0 / 7 |
| `referrals.receive` | a referral from a referring vet, for an animal registered or found | 1.82/h | poisson, `office` | 18 / 0 / 0 / 13 |
| `consultations.emergency` | an emergency consultation, flagged, a third of them at night | 0.42/h | poisson, `around-the-clock` | 10 every day |
| `consultations.herd-visit` | a herd visit, a consultation on a herd | 2.1/h | even, `herd-days` | 10 on Tuesdays and Thursdays / 0 / 0 / 3 |
| `consultations.ward` | an in-hospital consultation on a current stay | 3/h | poisson, `ward-rounds` | 12 every day |
| `stays.admit` | an admission from a consultation of the last hours | 0.34/h | poisson, `around-the-clock` | 8 every day |
| `stays.discharge` | the oldest stay past two days ended: discharged (90 %), transferred to another centre (4 %, each recording an outbound `transfer` exchange, D306), died (6 %) | 2.67/h | even, `discharges` | 8 every day |
| `alerts.record` | an alert on an animal (allergy, dangerous, infectious) | 0.6/h | poisson, `clinic-day` | 6 / 2 / 0 / 5 |
| `ownerships.transfer` | a sale or a new keeper: one ownership ended, the next opened | 0.37/h | poisson, `clinic-day` | 4 / 1.5 / 0 / 3 |
| `requests.cancel` | a request still `requested` cancelled; once `sent`, only the lab cancels it (the imaging team an imaging request), the vet phoning, and the cancellation comes back through the results feed or the imaging reports' fetch (D315, D324) | 0.12/h | poisson, `clinic-day` | 1 / 0.5 / 0 / 1 |
| `exchanges.request` | an outbound exchange recorded: an examination or a transfer asked of another centre (two centres, or the centres abroad), `requested`, its `exchange_key` (D306) | 0.1/h | poisson, `office` | 1 / 0 / 0 / 0.7 |

The scheduled consultations have no stream of their own (D317): they
are opened by `vet-bookings-sync`'s `check-in` (purpose 11) from the
bookings `vet-scheduling`'s `sched.bookings.arrive` checks in, about 60
a day (78 a weekday, 30 on Saturday), their hours following the agenda
(horse and farm in the morning, domestic in the late afternoon).
Consultations come to about 100 a weekday (110 on herd days), 52 on a
Saturday and 22 on a Sunday: 85 a day over the week, as the variant
states.

Work streams, on `clinic` as `vet_app`:

| Key | What it takes and writes | Capacity | Shape | Follows |
|---|---|---|---|---|
| `consultations.close` | the oldest open consultation started 25 minutes ago or more: closed with its findings, one or two diagnoses (1.2 on average), a procedure in about three in ten, requests in about two in three (0.65 on average, one in five imaging; `urgent` for emergencies and stays), a prescription in six in ten (2.5 lines), dispensed to the owner at once for an outpatient (75 dispensings a day), its administrations planned by the next round for a stay | 40/h | `flat` | the opens: 85 a day |
| `consultations.sign` | the oldest closed, unsigned consultation closed an hour ago or more, signed by its vet | 20/h | `signing` | 85 a day; nothing waits a day (the trap stays a fault's) |
| `referrals.accept` | the oldest received referral: accepted, one in twenty declined | 6/h | `office` | 13 a day |
| `referrals.close` | an accepted referral whose consultations are signed and whose stay has ended: closed, its report marked sent (the vet's letter; the report as an electronic flow is a purpose, D278 answer 5) | 4/h | `office` | about 13 a day |
| `exchanges.decide` | the oldest inbound exchange `received`: accepted with a date, one in ten declined, within a working day (D306) | 2/h | `office` | about one a day |
| `exchanges.report` | an accepted examination, either way, one to three days after its date: its report written, `reported` (D306) | 2/h | `office` | under one a day |

Reads, on `clinic` as `vet_app`: `animals.file` (an animal's record:
identity, alerts, ownership, the last consultations, the current stay;
60/h, poisson, `clinic-day`, concurrency 4, about 640 a weekday),
`wards.list` (a section's current stays and the next round's doses;
12/h, even, `flat`), `requests.pending` (a vet's open requests and
their state; 15/h, poisson, `clinic-day`).

Fixed-time operations (`jobs.yaml`, scenario time):

| Job | When | What |
|---|---|---|
| `administrations.round` | `0 2,6,10,14,18,22 * * *` | the round: every scheduled administration due is given (one in a hundred missed, by a hash of its id), then the next round's are planned for each current stay with an active line: about 40 a round, 240 a day |
| `prescriptions.expire` | `15 0 * * *` | antimicrobial prescriptions past five days expired (D280, rule 1), the others past their days |

`prescriptions.expire` is light, set-based work: the GM may move it to
the database node's `pg_cron` (D206, D207).

### The business hours (shapes)

Scenario time, the customer's zone, every site in it (D276):

| Shape | Hours |
|---|---|
| `clinic-day` | Monday to Friday 08:00–20:00: 0.8 at 08–10, 1.0 at 10–12, 0.4 and 0.6 over lunch, 1.0 at 14–17, 1.2 at 17–19, 0.6 at 19–20; Saturday 08:00–13:00 at 0.8; Sunday closed |
| `office` | Monday to Friday 08:00–18:00, flat |
| `herd-days` | Tuesday and Thursday 08:00–13:00: the herd-health visits on fixed weekdays, a weekday shape and not a job (Cadences) |
| `ward-rounds` | every day 09:00–12:00 at 1.0, 16:00–18:00 at 0.5 |
| `around-the-clock` | every day: 0.8 at night (00–08), 1.1 by day (08–22), 0.9 in the late evening; about a third of the volume between 22:00 and 08:00 |
| `discharges` | every day 10:00–13:00: discharges late in the morning |
| `signing` | every day 08:00–21:00: a night's emergencies are signed the next morning, within the day the rule gives (D280, rule 8) |
| `flat` | every hour at 1.0 |

### Input types (D276)

Every value is SQL's, as the shop's: the species mix, a consultation's
outcome, a stay's outcome, an urgent share, through an `int` parameter
and a `CASE`; names from short lists in array literals; the natural
identifiers of a new animal as functions of its new id, the same
functions the load uses (step 4), so a microchip is never drawn at
random; per-row variation inside a set-based statement (a round's
missed doses) by a hash of the row's id, never `random()`, so a run is
reproducible from the game's seed (D117). No domain builder. The
int-and-`CASE` trick recurs about a dozen times across the core and the
lab, which is D276's trigger for a weighted `choice` generator (D303).

### Intensity, and the history before T0 (D276, D279)

- **Absolute.** The scenario sets each node's intensity at design time;
  nothing rescales it (D32). The core's, the lab's and the partners'
  rates are one business's: a scenario sets the same intensity on
  `pms`, `vet-lab`'s `lis` and the partners' back end, or the lab's
  share of the centre's requests drifts from the history's.
- **The history ends at intensity 1.0.** The load ramps each daily
  volume from about 60 % of today's rate a year ago up to today's
  (D279), on the same hour and weekday shapes as the streams above, so
  the curve runs on into the aging without a step. A scenario at
  another intensity shows a step at T0; its story names it (a new
  contract, a busy week), or the players read it as a fault, as the
  shop's busy season says of its own gap (D276).
- **In flight at T0.** The load is last night's backup: it leaves the
  clinic as a night leaves it. About 40 current stays (about 14 horses,
6 farm animals and 20 domestic animals, which `vet-housing`'s units are
sized on, D318), each with its
  active lines and the next round's administrations planned; the
  evening's emergencies open or closed and unsigned, none older than a
  day; a few exchanges in flight either way, answered or reported over
  the next days, the partners' database planted from the same functions
  (D306); received referrals of the day not yet accepted; every request of
  the history `resulted` or `cancelled` but the last day's, `sent`;
  sequences set after each range (step 4).
- **Unseen.** The load writes without trace: no statement logging,
  `pg_stat_statements` off, pgaudit off for its sessions (D265, [producer
  profiles](producer-profiles.md) 4).

### The periodic reports (D265, D269, D277, D299, D300)

Purposes (step 7): each reads the core on the standby (D299) and writes
the back-office database, `office` (D300), never `clinic`; past periods
planted before T0, no run on demand (D269), at most one run in the
aging, the GM's choice (D265), a fix checked on the daily feeder's next
run or by the sealed check reading the code (D277). The profile they
meet:

| Report | Cadence | Its daily feeder (the witness within the aging) | Planted before T0 |
|---|---|---|---|
| The medicines register (D280, rule 2) | its extract monthly, on the 1st at 03:00 | 01:30: yesterday's supplies of prescription-only medicines, with batch, quantity and recipient | the register's lines for the year, every full month's extract |
| The controlled-drugs register (rule 3) | a signed balance monthly, on the 1st; the inventory on 1 January | 01:45: yesterday's movements of controlled medicines | the year's movements and balances, last January's inventory |
| Antimicrobial use (rule 4) | the yearly report in January, a pushed obligation to the authority | 02:00: yesterday's use by species and medicine | last year's report, the cattle's |
| The head office's activity figures (one-centre 1) | monthly, on the 1st, pushed to the franchise's head office, a third party | 00:30: the day's consultations, admissions, the midnight census, housing units occupied and in service, the lab's tests and median turnaround | every full month's figures and the copies sent |

Not reports in v0.5: the farms' and stables' statements are billing,
out of v0.5 (D278 answer 8); the records' yearly retention purge finds
nothing to purge in a year of history (D280, rule 9: five years), so no
job runs it, its rule standing in the policy. Who plants each report's
past outputs into `office`, which no domain owns, is its purpose's
material (step 7).

### Flows to step 7, with their rates

| Flow | Kind | With | Rate at 1.0 |
|---|---|---|---|
| The analysis requests posted to the lab's order API (`vet-lab` answer 2) | round trip inside the centre: the accession id at once, the result later | `vet-lab`'s `lab-api` | about 45 tests in 25 orders a day, each within a minute of its consultation's close |
| The released results copied back into `requests` (`resulted`) | the round trip's answer | from `vet-lab` | as released, about 45 a day |
| Exchanges with the other centres, out: a transfer or an examination request, its answer, the report back (one-centre 3) | round trip, the centre asking | the other centres' stubs | about one a day (the transfers of `stays.discharge`, 0.3 a day, among them); an answer within a working day, the report one to three days after the examination |
| Exchanges with the other centres, in | round trip, the partner asking, at the centre's exchange endpoints | `clinic-api`, as `vet_exchange` (D306) | about one a day, business hours |
| Notifiable diseases (D280, rule 7) | pushed obligation | the authority | a few a month |
| The activity figures, the antimicrobial-use report | pushed, monthly and yearly | the head office, the authority | above |
| The release to the portal: signed consultations, ended stays, the lab's released results (D320) | pulled | `vet-portal-release` (purpose 15) on `interfaces` | about 140 documents a day |
| The portal's notices and vaccination reminders (D320, D321) | pushed | the franchise's messaging service, `vet-portal-messages` (purpose 16) | a notice per document, reminders daily |
| The agenda and the record: check-ins opening consultations, imaging requests and accepted examinations booked, a dead animal's bookings cancelled (D317) | transformed in place | `vet-bookings-sync` (purpose 11), in `clinic` | about 60 check-ins, 11 imaging bookings a day |
| The working-time record (D317) | pulled, periodic | `vet-working-time` (purpose 12), the standby → `office` | daily feeder, monthly |
| The imaging requests and their reports (D319) | round trip inside the centre | `vet-imaging-orders` (purpose 13), `clinic` ↔ `vet-machinery`'s `pacs` | about 11 a day |

An exchange's request, answer and report are the core's record, in
`exchanges` (D306, amending this step's first draft); the messages
either way are the purpose's trace (`ops.exchange_messages`), as a
purpose carries its target's DDL ([formats.md](../../formats.md)
"Purpose definition"). The purposes are
drafted in [clinic-purposes.md](clinic-purposes.md) (step 7).

### The partners the core meets (D285, D293)

On the one back end every partner shares, a scheduler node and a small
database (D293), and the one `api` node serving every partner, each
under its own hostname (D308), out of the players' reach (D273–D275):

- **The other national centres and the centres abroad** (three
  partners, two centres and the centres abroad as one, each its own
  hostname on the shared node): they answer the centre's requests
  within a working day, report one to three days after an
  examination, and post their own requests, about one a day, on the
  `office` hours; the back end's streams tick each partner's routes,
  which read its state, call the centre and record the answer (D303).
  Their fragments: `producers/partners/centres/` (D306).
- **The franchise's head office**: answers the monthly figures; no
  stream.
- **The franchise's messaging service**: answers `vet-portal-messages`'
  `POST /messages` (D320); the core hands it nothing, the reminders and
  the outbox being `vet-portal`'s (D304).
- **The authority**: a partner stub of its own on the back end (D304),
  the receiver of the notifiable diseases and the antimicrobial-use
  report ([clinic-purposes.md](clinic-purposes.md)).

Their fragments carry their normal behaviour only; an outage, a late or
duplicated answer comes with its fault (D276).

### Cold storage (D297)

Nothing of the core ships. About 760 rows a day is far under the
threshold of about 50 000 (D296), and the registers and the
antimicrobial report read the whole year. The core's instance ships
only its `wal` and `basebackup` (D299): with `archive_timeout` at an
hour, at least 24 segments of 16 MB a day, 384 MB a day nominal and
mostly empty, the vault discarding the payload; and one base backup a
night. Cold storage's planted manifests cover the history's days (cold
storage 3).

### Growth, for the GM notes (D298)

At intensity 1.0, on `clinic`:

| | Rows | Size |
|---|---|---|
| A day, on average | about 760 new rows (step 4's 570 main rows, with the diagnoses, lines, procedures and ownerships) and about 450 updates (closing, signing, giving) | about 0.25 MB with indexes, before bloat |
| An hour, on average | about 30 | |
| The busiest hour, a weekday 17:00–19:00 with a round | about 90 | |
| A Sunday | about a third of a weekday | |

Over an aging of eight to twenty-four hours the core grows by a few
hundred rows: the disk is never the core's problem; its updates, its
dead rows and its WAL are. When archiving fails, `pg_wal` keeps every
segment: at least 16 MB an hour, about 2 GB in five days, so a full
disk is not reached inside an aging, but the growth shows (replication
4).

### Points for the owner, ruled (D304)

Confirmed as drafted on 2026-11-02 ("agreed"), with the lab's (D304,
closing O153):

1. **Two nodes for the core**: the practice-management software
   (`pms`), which later carries scheduling and housing, and the lookup
   API (`clinic-api`), only answering; the displays and the reports are
   not the core's producers.
2. **The week**: weekdays 08:00–20:00 with a morning and a late
   afternoon peak, Saturday mornings, Sundays emergencies and wards
   only; herd visits on Tuesday and Thursday mornings; a round every
   four hours; discharges late in the morning.
3. **The 85 consultations**: 60 scheduled, 12 in hospital, 10
   emergencies, 3 herd visits on average; a request in two in three, a
   prescription in six in ten, as the history's ratios.
4. **A referral is closed by the vet's letter** once its consultations
   are signed and its stay ended; the electronic report stays a later
   purpose (D278 answer 5).
5. **No farms' statements and no retention purge** in the profile:
   billing is out of v0.5, and a year of history holds nothing past five
   years.
6. **The vaccination reminders** (Cadences, daily) leave the core's
   profile: an owner's reminder is a `vet-portal` notification, settled
   with that part; the centre's outbox to the franchise's messaging
   service is settled there too, the core having no outbox table.
7. **The exchanges with the other centres**: about one a day each way,
   round trips at step 7 with their trace tables (amended by D306: the
   request, its answer and report in the core's `exchanges`); the authority a
   partner stub of its own on the shared back end.
8. **One intensity for the clinic's nodes**, the history ending at 1.0's
   rates, another intensity a step at T0 the story must explain.

## Purposes that fit (step 7)

Ruled with `vet-lab`'s (D306, D307), each its own unit under
`purposes/` ([clinic-purposes.md](clinic-purposes.md) 2): fitting the
core, `vet-lab-centre-orders`, `vet-centre-exchanges`,
`vet-notifiable-diseases`, `vet-medicines-registers`,
`vet-antimicrobial-use` and `vet-head-office-figures`; with the parts
(D317–D320, numbered by D324,
[clinic-purposes.md](clinic-purposes.md#16-the-parts-purposes-11-to-16)):
11 `vet-bookings-sync`, 12 `vet-working-time`, 13 `vet-imaging-orders`
and 15 `vet-portal-release`. Named for later: the referral's electronic
report (D278 answer 5).

## Traps (step 8)

Listed with `vet-lab`'s in [clinic-traps.md](clinic-traps.md), each with
its witness, where it is fixed, catalogue or new, and its D290 class;
the domain's GM notes carry them ("the traps"). Those that bite the core:
on its instance and configuration T1, T3, T5, T7, T9; in its data and
identity T13 to T19; in its grants and views T24 to T28; in replication
and the archive T31 to T37; in its round trips T39 to T44, T54 to
T56 and T85; in its obligations T57 to T59; in its periodic reports T64 to T74;
in performance T79, T81 to T83. The parts' traps that also bite it:
`animal_board` T155, `stays` T157 and T161 (vet-housing); the
scheduling traps' "also bites" notes on T5, T7, T9, T14, T24, T31–T37,
T73, T74 and T82 (vet-scheduling). False-alarm material:
[clinic-traps.md](clinic-traps.md) 9. Selecting a game's faults is the
GM's (D309); the spec's test selection is
[clinic-test-selection.md](clinic-test-selection.md).

## Loading

`gmctl load-data` runs `schema.sql` then `load.sql` into `clinic` as
`postgres`, as for the shop: explicit ids in the documented ranges, each
sequence set after its range, the shift variables applied; the load's
sessions unseen (no statement logging, `pg_stat_statements` and pgaudit
off, D265). About 0.28 million rows, a few seconds by the shop's
measure (1.3 million in about 15 seconds); size and time measured at the
build (procedure 3). After the sources' loads, the purposes plant
`office`'s past periods ([clinic-purposes.md](clinic-purposes.md) 4,
item 5); the standby follows the primary ([replication.md](replication.md)
1). `vet-lab`'s, `vet-scheduling`'s, `vet-housing`'s, `vet-machinery`'s
and `vet-portal`'s loads and the partners' database compute the core's
ids by the documented functions, never reading `clinic` (D302, D322);
`vet-portal`'s copied content alone comes from a derivation step the GM
sanctions, after this load (D322, D326). The GM's post-load
coherence check then reads every part's references against the core
([procedure](domain-procedure.md) 10).

## Open points

- **O111**: the domain format, finalised in v0.5's master spec (D291),
  with the composition rules (D322, D323, procedure 10).

Settled on 2026-11-03: the four parts folded in (D317–D325); a sent request is cancelled by the lab only, the
cancellation copied back (D315); v0.5 builds the test selection's ten
faults and its false alarm, the other traps staying in the GM notes
(D316).
