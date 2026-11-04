# v0.5 — `vet-scheduling`, the clinic's bookings, rota and training centre

Status: draft v3, ruled, its stale passages corrected to the master
spec at approval (R16, D339). **Approved by the owner on 2026-11-03 with
v0.5's [master spec](master-spec.md)** (procedure step 9, D339), which
wins where the two disagree. Amended in wave 2 of the build
(2026-11-04): a routine imaging request booked within two working days
(D376); the rota's pattern and the history's absences are the core's
`core_shifts`, the consultations and exchanges its `core_consultation`
and `core_exchange` (D374); a duty vet a section at the weekend
(D384), the nurses' cycle and the history's absences (D388); the
every-shift rule the nurses', the carers' cover (D394). Amended in
wave 3 (2026-11-04): the history's scheduled consultations placed on
the agenda, half-hour slots within the vets and spaces free (D408); the
consultation spaces, 30-minute consultation types and the farm's hours
(D410); the rota planned to the horizon ahead of its publication
(D411); the slot function's copy of the staff layout and its teaching
animals (D412); an inbound examination's machine (D413); `vet_reports`'
grant (D414).
Steps 1 to 9 drafted in one pass on 2026-11-03 at the owner's instruction
("start an agent for each part, and let them come back with problems
once they're done"), in parallel with `vet-housing`, `vet-machinery` and
`vet-portal`; the same day the owner accepted the recommendations as a
whole (D317, closing O168–O179), marked "(ruled, D317)" below. Folded
in with the other parts (D324): ten bookable machines, `vet-machinery`'s
ids 7–16; the staff layout the core documents; no appointment reminders
in v0.5 (D321). Step 8 has no owner checkpoint (D309). The changes this
part asked of the shared pages are applied ([Changes needed in shared
pages](#changes-needed-in-shared-pages)). The format, with the
composition rules (D322, procedure 10), finalised in
[formats.md](../../formats.md) v28 at consolidation (D338).

`vet-scheduling` is the centre's scheduling: the slots of its rooms and
machines, the bookings that take staff, rooms and machines, the staff
rota, and the training centre's courses, sessions and trainees (D279,
D293). It is a **part**: it requires `vet-core` (procedure 4), refers to
the core's keys by id with no foreign key, and prefixes its tables and
roles `sched_`. The machines are `vet-machinery`'s, booked here by the id
that part owns. The teaching animals are core animals, the clinic their
owner (D278 answer 10, D279). The core and `vet-lab` are the model and
the fixed neighbours ([vet-core](vet-core-domain.md),
[vet-lab](vet-lab-domain.md)).

## The draft at a glance (step 9)

Where each item of the part's folder, `domains/vet-scheduling/`, is
stated on this page (procedure 1, 3 and 4; the format is finalised in
the master spec, O111):

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-scheduling`, `requires: [vet-core]`, tables and roles prefixed `sched_`, the purposes that fit | [What scheduling holds](#what-scheduling-holds); [Purposes that fit](#purposes-that-fit-step-7-ruled-d317) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest of the core variant's name (D301 answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/schema.sql`: tables, the exclusion constraints, the slot function and the release trigger, roles and grants, landing in `clinic` (ruled, D317) | [The data model](#the-data-model-step-4) |
| `data/load.sql`: the year's bookings, rota and sessions, the agenda ahead at T0, computing the core's ids by its functions | [Deterministic key ranges](#deterministic-key-ranges-d249-d266), [The history before T0](#intensity-and-the-history-before-t0-d276-d279), [Loading](#loading) |
| `data/classification.yaml`: every column classed | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The rules](#the-rules-ruled-d317) |
| `producers/`: the practice software's scheduling fragments, on `pms` (D276) | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; [Traps](#traps-step-8); [Loading](#loading) |

## Settled before this page

Built on, not reopened:

- **The split** (D279): `vet-scheduling` holds "rooms and machines'
  slots, bookings of staff, rooms and machines; the training centre's
  courses, sessions and trainees". One centre's (D285, D293).
- **The training centre trains people** (D278 answer 10): vets, nurses,
  owners, handlers, with the clinic's own teaching animals; trainees are
  not staff and live here; the teaching animals are core animals, owned
  by the clinic (core owner 1).
- **The core** holds sites, sections, staff (kind, specialty), animals,
  consultations with a `booking_id` that is this part's, by id (core step
  4), requests for imaging (D279), exchanges with the other centres, an
  accepted one "a booking later with `vet-scheduling`"
  ([clinic-purposes](clinic-purposes.md#8-vet-centre-exchanges-the-other-centres) 8).
- **One application, one producer node** (D276): the practice-management
  software, `pms`, carries `vet-scheduling`'s fragments beside the
  core's. Flows between parts are purposes (procedure 4).
- **The machines are `vet-machinery`'s** (D279): the lab's analysers are
  machines 1–6 (D302); the bookable ones are that part's to number.
- **Reminders and the outbox are `vet-portal`'s** (D304); messaging is
  the franchise's, a third party (D293). No appointment reminders in
  v0.5 (D321).
- **Billing is out of v0.5**, but for the lab's outside customers (D278
  answer 8, D294).
- **Schemas simple, tables small; one variant** (D263); tests short, on
  a minimal fixture (D314); only the test selection's ten faults built
  (D316).

## The brief (step 1, ruled, D317)

The procedure has the owner write the brief. None exists for this part
beyond the clinic's (D196), so this one is built from it and from the
split, for the owner to correct:

> The centre runs a heavy agenda across its three sections and its
> training centre. Reception books owners' animals for consultations
> with a section's vets, in its consulting rooms and examination stalls;
> the imaging team books the scanners for the studies the vets request,
> urgent ones the same day; the surgeons plan the theatres with their
> anaesthetists and nurses. Every booking takes a vet or a team, a room
> and sometimes a machine, and none may be in two places at once. Staff
> work to a weekly rota, around the clock in the wards and for
> emergencies, under working-time rules the clinic must be able to show
> an inspector. The training centre runs courses for vets, nurses,
> students, owners and handlers, canine and equine, in its classrooms,
> its practical hall and the horse section's arena, with the clinic's
> own teaching dogs and horses, which must not be overworked. Other
> centres send animals for an examination one of our machines can do;
> those come into the agenda too.

## The business sketch (step 2)

The sketch covers scheduling as reception, the sections' teams, the
imaging team, the theatre planners and the training office meet it.
What belongs to the core or another part is named, and left to it.

### The business

A referral hospital's agenda is its bottleneck: specialists, scanners
and theatres are scarce, and an animal referred from across the region
comes on a set day. The centre books:

- **consultations**: an animal, a section's vet, a consulting room or an
  examination stall, for a set time; first referrals, follow-ups,
  specialist clinics (cardiology, dermatology, lameness work-ups);
- **imaging studies** on the ten bookable machines (two CTs, MRI, the
  horses' standing MRI, three radiography units, two ultrasounds, the
  gamma camera; `vet-machinery`'s, D324), each for a core imaging
  request (D279), an urgent one the same day;
- **theatre plans**: a planned surgery's theatre, surgeon, anaesthetist
  and nurse (ruled, D317: the plan only; the procedure itself stays
  the core's record);
- **maintenance blocks**: a machine or room out of use (the MRI's weekly
  quality assurance, a theatre's deep clean);
- **training sessions**: a course's days in a room, with an instructor
  and teaching animals.

Not booked (ruled, D317): **emergencies** (they come at any hour and
take whoever is on duty), **herd visits** (the farm vets' fixed weekdays,
D278 answer 3, a rota matter), **ward rounds** (the core's rounds,
around the clock), and **housing**'s boxes and stalls (placements are
`vet-housing`'s, D279).

Beside the bookings, the **rota**: each staff member's shifts, published
weekly for the week after next, around the clock for the wards and the
night's emergencies; absences (leave, training, absent) without reasons;
the hours actually worked, clocked, which the working-time rules need.

### Actors

| Actor | Who | With scheduling |
|---|---|---|
| Receptionist | core `staff`, `kind` `reception` | books, moves and cancels consultations by phone and at the desk; checks animals in |
| Referring vet | a core referring vet, by phone or letter | asks for an appointment for a referred animal; reception books it |
| Vet and specialist | core `staff`, `kind` `vet` | is booked; books follow-ups at the end of a consultation; requests imaging (the core's request) |
| Imaging team | core vets (imaging specialty) and technicians | its machines' agenda; urgent studies slotted the same day |
| Theatre planner | a section's senior nurse | plans surgeries: theatre, surgeon, anaesthetist, nurse |
| Rota manager | the clinic's management (story's) | the rota's pattern; publishes it weekly; records absences |
| Every staff member | core `staff` | works shifts, clocks in and out |
| Training manager and instructors | core `staff`, `kind` `instructor` | plan sessions, teach, record attendance, issue certificates |
| Trainee | a person: a vet, nurse or student from outside, an owner, a handler or groom | enrols, attends, receives a certificate; never staff (D278 answer 10) |
| Teaching animals | 12 dogs and 8 horses, core animals owned by the clinic (ruled, D317) | booked for sessions, within welfare limits |
| Another centre | a third party (D285) | its accepted examination booked on the centre's machine (core `exchanges`) |
| Owners | the core's | no appointment reminder in v0.5 (D321); the portal's reminders are vaccinations' only |
| The labour inspectorate | the authority for working time | may ask for the working-time records (a pulled report) |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Booking a consultation | the animal, the type, the vet, the room, the time, who booked, from where | `vet-scheduling` |
| Booking an imaging study | the core's request, the machine, its operator, the time | `vet-scheduling`, from the core's request (a purpose, O172) |
| Planning a surgery | the theatre, the team, the time | `vet-scheduling` |
| Blocking a machine or room | the resource, the time, the reason (maintenance, cleaning) | `vet-scheduling` |
| Moving or cancelling | the cancellation, its reason; the slot released | `vet-scheduling` |
| Checking in | the arrival | `vet-scheduling`; the consultation it opens is the core's (a purpose, O172) |
| A no-show | the booking not attended | `vet-scheduling` |
| Booking another centre's examination | the exchange, the date accepted, the machine | `vet-scheduling`, from the core's `exchanges` (a purpose) |
| Cancelling a dead animal's bookings | the cancellation, reason `deceased` | `vet-scheduling`, from the core's animal (a purpose) |
| Publishing the rota | shifts of the week after next | `vet-scheduling` |
| Recording an absence | leave, training or absent, never why | `vet-scheduling` |
| Clocking in and out | the hours worked | `vet-scheduling` |
| The working-time record | each staff member's day, rests, breaches, the month | `office` (a periodic purpose, O178) |
| Planning a course's session | the session, its days, room, instructor, teaching animals | `vet-scheduling` |
| Enrolling a trainee | the trainee, the session, waiting list | `vet-scheduling` |
| Recording attendance, issuing a certificate | hours attended, the certificate | `vet-scheduling` |
| Reminding owners of appointments | not in v0.5 (D321) | — |

### The variant, its scale and its tags

The part takes the clinic's one variant, `regional-franchise` (D263),
and adds no tag: `24/7` already says the rota runs around the clock. Its
own axes go in `vet-scheduling/variants/regional-franchise.yaml` (D301
answer 15). The figures fit `vet-core` at one centre's scale (D295):
about 60 scheduled consultations a day out of 85, about 11 imaging
requests a day (one in five of the core's 55 requests).

**Population**, at load (ruled, D317; machines D324):

| What | How many |
|---|---|
| Rooms | 16: domestic 4 consulting rooms, a procedure room, 2 theatres; horse 2 examination stalls, the trot-up and lunging arena, a theatre with its induction and recovery boxes; farm an examination crush, a standing-surgery theatre; the training centre 2 classrooms and a canine practical hall (the equine sessions use the horse section's arena) |
| Bookable machines | 10, `vet-machinery`'s ids 7–16 (D324): 7 CT small animal, 8 CT large bore, 9 MRI 1.5 T, 10 standing MRI, 11 radiography room domestic, 12 radiography room horses, 13 portable radiography (farm and stables), 14 ultrasound domestic, 15 portable ultrasound, 16 gamma camera (horses) |
| Appointment types | about 45: consultations per section (first referral, follow-up, specialist clinics, a lameness work-up), imaging studies (one per study code the core's requests use), surgeries, a block, a session day |
| Staff on the rota | the core's 85 (D295), every kind |
| Courses | 16: 7 canine, 6 equine, 3 mixed; audiences vets (continuing education), nurses, students, owners (first aid), handlers and grooms |
| Teaching animals | 12 dogs and 8 horses, core animals of owner 1 (O175) |

**History**: one year, growing as the core grew (D279), each daily
volume ramping from about 60 % of today's rate to today's:

| What | Over the year |
|---|---|
| Consultation bookings | about 19 700: 16 700 attended (the core's scheduled consultations, on the agenda, D408), 2 100 cancelled, 900 no-shows |
| Imaging bookings | about 3 400, one per core imaging request |
| Theatre plans | about 1 250 |
| Maintenance blocks | about 360 |
| Sessions | about 100 held, 200 session days; 25 planned ahead at T0 |
| Trainees, enrolments | about 750 people, 1 000 enrolments |
| Shifts | about 22 700 (85 staff, about 4.5 a week, the year and six or seven weeks ahead: published to the end of the week after next, planned beyond to the horizon, D411) |
| Absences | about 600 |

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Consultation bookings made | about 71 a day (92 a weekday, 34 on Saturday): 75 % domestic, 18 % horse, 7 % farm |
| Lead time | 30 % within two days, 50 % within two weeks, 20 % up to six weeks (follow-ups and re-checks); about ten days on average |
| Cancellations, no-shows | 10 % of bookings cancelled ahead, 5 % of the rest not attended (game values) |
| Imaging bookings | about 11 a day, a quarter urgent and the same day |
| Theatre plans | about 4 a day, Monday to Friday 6 |
| Arrivals checked in | about 60 consultations a day, 78 a weekday, 30 on Saturday, as the core's scheduled share |
| Shifts | about 55 a day, each clocked in and out |
| Enrolments | about 3 a working day |
| Inbound examinations booked | under one a day (the core's exchanges, D306) |

About **0.11 million rows** at load and about **330 new rows and 200
updates a day** live (step 4's count), against the core's 0.28 million
and 760: the allocations, about two per booking, are the bulk.

**Against a real hospital.** A university small-animal hospital of this
order books a few thousand appointments a month across its services,
an MRI a handful of studies a day, a CT twice that; the centre's 1 500
appointments a month and about one study per machine a day are of
that order, a little smaller (figures as known to this draft, not
re-read on 2026-11-03).

**A few stand for many** (D263): sixteen rooms and ten machines for a
hospital's floor, one rota pattern for every team, sixteen courses for a
training centre's programme.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Reception's hours, Monday to Friday 08:00–19:00, Saturday 08:00–12:00 | bookings made, moved and cancelled | yes |
| The rooms' hours | domestic consulting Monday to Friday 08:00–20:00 and Saturday 08:00–13:00; horse Monday to Friday 08:00–17:00; farm Monday to Friday 08:00–16:00, the core's farm consultations running to 16:00 (D410); theatres 08:00–18:00; the agenda's arrivals follow them | yes |
| Around the clock | shifts starting and ending (day, late, night, on call); urgent imaging on the CT | yes |
| Every minute | the flows with the core: check-ins opening consultations, imaging requests booked, deaths cancelling bookings (a purpose) | yes |
| Daily, 09:30 | the working-time feeder: yesterday's shifts, every night shift finished | yes |
| Weekly, Friday 12:00 | the rota of the week after next published; the machines' weekly blocks planned | only if Friday falls within the aging |
| Session days | about two sessions a week, one to three days each, Monday to Friday | yes, within the aging |
| Monthly | the working-time month (hours, nights, breaches, the four-month average) | **no**: history and the daily feeder ([producer profiles](producer-profiles.md) 4) |
| Quarterly | the training programme planned three months ahead | **no**: in the history and the state at T0 |

### Regulations

What a clinic's scheduling plausibly answers to, at the level a game
needs; the rules and values ruled at step 5 (D317). The EU texts below
were checked against the Official Journal and the Court's judgments on
2026-11-03, at the fold-in. *SIMAP* and *Jaeger* interpret the earlier
Directive 93/104/EC, which 2003/88/EC consolidated.

| Rule | Source | What scheduling must hold |
|---|---|---|
| 11 consecutive hours' rest in every 24; a weekly rest of 24 hours beside it; at most 48 hours a week on average, over a reference period of up to four months; night work 8 hours a day on average | Directive 2003/88/EC, Arts 3, 5, 6, 8, 16(b) | each shift's planned and worked times; the rest between consecutive shifts |
| The employer records each worker's daily working time in an objective, reliable and accessible system | CJEU C-55/18, *CCOO* (2019) | the clocked hours, not only the plan |
| Stand-by on site is working time; stand-by elsewhere counts when its constraints are heavy, else the time called out | CJEU C-303/98 *SIMAP*, C-151/02 *Jaeger*, C-518/15 *Matzak*, C-344/19 (2021) | on-call shifts and their call-outs, clocked |
| A staff member's health is special-category data | GDPR Art 9 | an absence's kind only, never its medical reason |
| Training on animals below the threshold of a needle's insertion falls outside the rules on animals used for education | Directive 2010/63/EU, Art 1(5)(f); education and training a purpose it regulates above the threshold, Art 5(f) | the teaching animals' sessions limited to handling and examination; their use per day |
| Vets keep up their continuing education; a course provider certifies attendance and hours | national, the chambers' rules | courses' hours, attendance, certificates |
| Trainees are personal data, processed to run the course | GDPR Art 6(1)(b) | the trainees' contacts, kept for a set period |
| Working-time records kept for a set period | national: Germany keeps them at least two years (ArbZG § 16(2), checked), and since the Federal Labour Court's ruling of 13 September 2022 (1 ABR 22/21) records all working time under ArbSchG § 3(2) (to confirm); France a year (to confirm) | dates to purge by (game value) |

## What scheduling holds

Within the procedure's section 4: every table prefixed `sched_`, every
core key by id with no foreign key; `vet-machinery`'s machines by id
likewise:

- **Reference**: the settings; the rooms and their hours; the bookable
  machines' calendars (where each stands, its slot length, its hours);
  the appointment types (duration, section, the resources each needs);
  the courses.
- **Bookings and allocations**: each booking (a consultation, an imaging
  study, a theatre plan, a block, a session day) and one allocation per
  resource it takes: a staff member, a room, a machine, a teaching
  animal, each with its time range. No resource is allocated twice at
  once: an exclusion constraint per kind of resource enforces it.
- **The slot function**: `sched_free_slots`, in the database, the next
  free slots for a type, by the hours, the rota, the absences, the
  allocations and the teaching animals' limits. Reception's search, the
  booking stream and the purposes all call it.
- **The rota**: shifts (planned, clocked), absences.
- **The training centre**: sessions, trainees, enrolments with
  attendance and certificates.

Not held: the consultation a booking turns into (the core's, which
carries `booking_id`); the imaging study and its readings
(`vet-machinery`'s); the owners' contacts (the core's, read by the
portal's copies); housing's placements.

## Where scheduling presses on the core

What the part needs of `vet-core`, to apply there (see
[Changes needed in shared pages](#changes-needed-in-shared-pages), item 1):

| Scheduling needs | The core |
|---|---|
| which vets, nurses and instructors exist, their section and specialty | `staff`; each id's kind, section and specialty a function of the id, documented, in the core's layout (ruled, D317, D324) |
| which consultation a booking turned into | `consultations.booking_id` (core step 4), unique when present (a new partial unique index) |
| the scheduled consultations arriving from bookings, not from a volume stream of their own | `consultations.open` removed from the core's profile; the check-in purpose opens them (O172) |
| the history's scheduled consultations matching the history's bookings | each history consultation's kind, section, vet and start a function of its id, documented, and `booking_id` = its own id for a scheduled one (O175) |
| the history's vets on shift when they consulted | the core's load picks each consultation's vet by the rota's documented pattern (O175), a scheduled one's on the agenda's half-hour slots, never two at once (D408) |
| the imaging requests, their study code and priority | `requests` (D279, D301), read by the purpose |
| the animals that died, so none is booked | `animals.status`, `died_at`: live deaths read by the purpose; the history's deaths a function of the id, documented, so the booking stream avoids them (O175) |
| the teaching animals | animals 1–12 (dogs) and 14 601–14 608 (horses), owned by owner 1 since before the history (O175) |
| the inbound examinations accepted with a date | `exchanges` (D306), read by the purpose |

Against the core's page: its "Where the parts press on the core" line
for `vet-scheduling` names "rooms per site" in the core; the core holds
no rooms (its step 4), and the split puts the slots of rooms here
(D279). The rooms are this part's; the line is corrected in item 1 of
the changes.

## The owner's answers (step 2, ruled, D317)

The questions the sketch leaves open, each with the default this draft
is built on; none is ruled.

1. **What is booked** (O170). Consultations, imaging studies, theatre
   plans, maintenance blocks and training sessions; not emergencies,
   herd visits, ward rounds or housing's boxes. A theatre plan is the
   plan only: the procedure stays the core's record, written as today
   by its consultations, unlinked to the plan (the GM notes say so, so
   that a plan with no procedure behind it reads as the generator's
   simplification, never a fault).
2. **One allocation per resource** (O169). A booking takes one or more
   resources, each its own row with its time range: a consultation a
   vet and a room, an imaging study a machine and its operator, a
   theatre plan a theatre, a surgeon, an anaesthetist and a nurse, a
   session day a room, an instructor and its teaching animals. No
   resource is in two places at once: the database refuses an overlap
   (`EXCLUDE USING gist`, `btree_gist`), the slot function avoids one.
3. **The slots** (O169). Slots are computed, never stored: a room's or a
   machine's hours, its slot length, the types' durations; the slot
   function returns the free ones. A stored grid of slots would hold
   about 1.5 million rows a year for no gain.
4. **The rota** (O173). Every staff member's shifts (`day`, `late`,
   `night`, `on-call`), from a weekly pattern, a function of the staff
   id and the week, published every Friday for the week after next;
   absences with a kind only (`leave`, `training`, `absent`), never a
   reason; each shift clocked in and out, the clocked hours the
   working-time record. On call means at home: it counts as working time
   only for the time clocked on a call-out, the clinic's reading of the
   case law (game value).
5. **Cancellations and no-shows** (O169). A cancellation releases the
   booking's resources at once (a trigger); a booking not checked in 30
   minutes after its start is a no-show; 10 % cancelled ahead and 5 % of
   the rest not attended (game values).
6. **The training centre** (O174). Courses for people, canine and
   equine: vets' continuing education, nurses' skills, students'
   placements, owners' first aid, handlers' and grooms' handling; one to
   three days, 8 to 14 seats; a waiting list when full; attendance per
   day; a certificate with its hours for a trainee who attended at least
   80 % of them (game value). No fees in v0.5 (billing is out, D278
   answer 8). Trainees are people, never staff; one may be a core
   referring vet, by id.
7. **The teaching animals** (O174, O175). 12 dogs and 8 horses, core
   animals owned by the clinic; handling and examination only, nothing
   above a needle's insertion, so outside Directive 2010/63/EU; at most
   two sessions a day, four hours in all, and a rest day after two
   working days (game values), the slot function refusing more.
8. **Imaging and the other centres** (O172). A core imaging request is
   booked on its study's machine by a purpose, an urgent one the same
   day; an inbound examination accepted with a date (D306) is booked on
   that date or the first free slot after it.
9. **A dead animal's bookings** (O172). Cancelled, reason `deceased`, by
   the purpose, within minutes of the core recording the death, so
   reception never calls a grieving owner about a follow-up.
10. **Scale and hours** (O169). The figures in "The variant" and
    "Cadences": about 71 bookings a day, 16 rooms, 10 machines, 85 staff
    on the rota, 100 sessions a year; reception Monday to Saturday, the
    rooms' hours per section, the rota around the clock.

## The data model (step 4)

On the answers above. The tables land where the scenario's `domains:`
`at:` places them; this draft recommends **`records/clinic`**, the core's
own database, beside the core's tables (ruled, D317): the practice
software's scheduling module, no node of its own, riding the core's
standby and archive. The schema is written to run as well in a database
of its own: no foreign key and no grant on the core's tables, every
flow with the core a purpose holding two connections (O172).

Written in the core's and the lab's manner: the tables in `public`,
prefixed `sched_` (procedure 4), integer keys `GENERATED BY DEFAULT AS
IDENTITY`, explicit ids at load and each sequence set after its range;
every time `timestamptz`, in UTC, the customer's zone in `sched_settings`
(a separate database keeps its own copy, as the lab's `lab_settings`).
`schema.sql` creates `btree_gist` (PostgreSQL's contrib, in the brick's
`postgresql-18` package), run as `postgres` by `load-data`.

**Growth through the year** (D279), as the core's: every daily volume of
the history (bookings, allocations, enrolments) ramps from about 60 % of
today's rate to today's; reference tables, staff, the rota and the
teaching animals do not grow.

### Entities

**Reference**

| Table | Key, main columns |
|---|---|
| `sched_settings` | one row: the customer's zone and offset, the booking horizon (42 days), the no-show delay (30 minutes), the teaching animals' limits (two sessions, four hours a day, a rest day after two), the attendance a certificate needs (80 %), the minimum rest (11 hours) |
| `sched_rooms` | `id`; code, name, `kind` (`consulting`, `examination`, `arena`, `procedure`, `theatre`, `classroom`, `practical`), `section_id` (the core's; none for the training centre's rooms), seats, active |
| `sched_hours` | (`resource_kind`, `resource_id`, `weekday`); opens, closes, local times in the customer's zone: a room's or a machine's opening hours |
| `sched_machines` | `machine_id` (`vet-machinery`'s, the key); `section_id`, `room_id` (where it stands), `study_kind` (`ct`, `mri`, `mri-standing`, `radiography`, `ultrasound`, `scintigraphy`; `vet-machinery`'s modalities, D324), slot minutes, `operator_kind` (the staff kind it needs), around the clock or not |
| `sched_types` | `id`; code, name, `kind` (`consultation`, `imaging`, `surgery`, `block`, `session`), `section_id`, duration minutes, the room kind it needs, `study_code` (the core's, for an imaging type) and its machine, the staff it takes (`vet`, `vet+nurse`, the theatre team); every consultation type takes 30 minutes, a slot of its room's half-hour grid (slots starting on the hour and the half-hour within the room's hours), in one of its section's **consultation spaces**: domestic the consulting rooms 1–4, horse the examination stalls 8 and 9 and the arena 10, farm the crush 12 and the standing-surgery theatre 13 (D410); the imaging types are one per section and machine, 12 of the 45 (domestic 7, 9, 11, 14; horse 8, 10, 12, 15, 16; farm 8, 13, 15), their `study_code` empty, since 30 codes by section would not fit the range: an imaging booking's study is its request's code ([vet-machinery's catalogue](vet-machinery-domain.md#the-procedure-catalogue-d372-d373), D372) |
| `sched_courses` | `id`; code, title, `audience` (`vet`, `nurse`, `student`, `owner`, `handler`), `species` (`canine`, `equine`, `mixed`), days, hours, seats, teaching animals needed, the room kind |

**Bookings**

| Table | Key, main columns |
|---|---|
| `sched_bookings` | `id`; `type_id`, `kind` (the type's, copied for the streams' and the purposes' filters), `animal_id` (the core's patient; none for a block or a session, none for an inbound examination until the animal is registered), `section_id`, `starts_at`, `ends_at`, `state`, `source` (`phone`, `desk`, `follow-up`, `referral`, `request`, `exchange`, `planned`), `request_id` (the core's, an imaging study), `exchange_id` (the core's, an inbound examination), `session_id`, booked at, booked by (staff), `notes` (free text), arrived at, cancelled at, `cancel_reason` (`owner`, `clinic`, `deceased`, `moved`) |
| `sched_allocations` | `id`; `booking_id`, exactly one of `staff_id` (the core's), `room_id`, `machine_id` (`vet-machinery`'s), `animal_id` (a teaching animal, the core's), `role` (`vet`, `nurse`, `surgeon`, `anaesthetist`, `operator`, `instructor`, `room`, `machine`, `teaching`), `during` (`tstzrange(starts_at, ends_at, '[)')`), `released_at` |

Four exclusion constraints on `sched_allocations`, one per kind of
resource, each `EXCLUDE USING gist (<resource> WITH =, during WITH &&)
WHERE (<resource> IS NOT NULL AND released_at IS NULL)`: a staff member,
a room, a machine or a teaching animal is never allocated twice at
once. Their GiST indexes serve the slot function's overlap tests.

**Logic in the database** (the practice software keeps its booking rules
there, so the players can read and fix them):

| Object | What |
|---|---|
| `sched_free_slots(type_id, after, how_many)` | a `STABLE` SQL function, security invoker: the next free slots for a type from a time within the horizon: the resource's hours (local times read in the customer's zone), a staff member of the type's section on a shift covering the slot (planned or published, D411) and absent on no absence, no live allocation overlapping, for a session day as many teaching animals of the course's species free within their limits as the course needs; returns each slot's start and end and the staff, room and machine it would take, never the teaching animals, which the caller picks (D412). A staff member's kind, section and specialty come from the core's documented layout, copied into the function's text (`core_staff`'s, one formula, as `sched.rota.publish` copies the rota's pattern; D412) |
| `sched_release` | a trigger after `UPDATE OF state` on `sched_bookings`, `WHEN (NEW.state = 'cancelled')`: its allocations' `released_at` set, so the slot frees at once |
| `sched_upcoming` | not built in v0.5 (D321): a view of the next 48 hours' bookings without notes or staff, for appointment reminders when a later version adds them |

**The rota**

| Table | Key, main columns |
|---|---|
| `sched_shifts` | `id`; `staff_id` (the core's), `section_id` (none for imaging, the lab, reception, the training centre), `kind` (`day`, `late`, `night`, `on-call`), starts at, ends at (planned), clocked in at, clocked out at, published at; unique on (`staff_id`, starts at) |
| `sched_absences` | `id`; `staff_id`, `kind` (`leave`, `training`, `absent`), from, until, recorded by, `note` (free text, never a reason: rule 4) |

**The training centre**

| Table | Key, main columns |
|---|---|
| `sched_sessions` | `id`; course, first day, last day, the lead instructor (staff), `state`; each session day is a booking (`kind` `session`) with its allocations |
| `sched_trainees` | `id`; name, e-mail, phone, `kind` (`vet`, `nurse`, `student`, `owner`, `handler`), `practice_id` (the core's referring practice, when from one), `referring_vet_id` (the core's, when one), registered at |
| `sched_enrolments` | `id`; session, trainee, enrolled at, `state`, hours attended, certificate number, issued at; unique on (session, trainee) |

### Lifecycle states

| Entity | States |
|---|---|
| Booking | `booked` → `arrived`, `no-show` or `cancelled`; a block or a session day `booked` → `held` once past, or `cancelled` |
| Allocation | live → released (its booking cancelled); a past allocation stays live, the record of who was where |
| Shift | planned → published → clocked in → clocked out; or removed before publication. Planned shifts run to the horizon's end, so a slot search within 42 days always meets the rota; each Friday's publication sets `published_at` on the week after next (D411) |
| Session | `planned` → `open` (eight weeks ahead) → `full` → `running` → `held`, or `cancelled` |
| Enrolment | `enrolled` or `waitlisted` → `attended` (certified when 80 % reached) or `no-show`; `cancelled` |

"Completed" is no booking state: the consultation's close is the core's
fact (`consultations.closed`), held in one place.

### Deterministic key ranges (D249, D266)

The load writes these ids, each sequence resuming after its range
(D276), and refers to the core's keys by its documented ranges
([vet-core](vet-core-domain.md#deterministic-key-ranges-d249-d266)) and
to `vet-machinery`'s machines by that part's range (D324).

| Key | Range | Layout |
|---|---|---|
| `sched_rooms.id` | 1–16 | 1–7 domestic, 8–11 horse (10 the arena), 12–13 farm, 14–16 the training centre |
| `sched_machines.machine_id` | 7–16 | `vet-machinery`'s bookable machines (D324); 1–6 the lab's analysers and 17–28 the monitors, never booked |
| `sched_types.id` | 1–45 | documented per section and kind |
| `sched_courses.id` | 1–16 | |
| `sched_bookings.id` | 1–50 000 | 1–25 000: a history consultation booking that was attended takes the id of the core consultation it turned into (only scheduled consultations have one: about 16 700 rows, gaps elsewhere; D408); 25 001–28 000 the history's cancelled and no-show consultation bookings; 30 001–47 000: an imaging booking is `30 000 + request id`, for the core's imaging requests (about 3 400 rows); 47 001–48 300 theatre plans; 48 301–48 700 blocks; 48 701–49 000 session days; 49 001–50 000 the agenda ahead at T0 |
| `sched_allocations.id` | 1–60 000 | in the bookings' order |
| `sched_shifts.id` | 1–24 000 | staff by staff, week by week, by the rota's pattern, to the end of the planned weeks (D411) |
| `sched_sessions.id` | 1–125 | 1–100 held, 101–125 planned ahead |
| `sched_trainees.id`, `sched_enrolments.id` | 1–750, 1–1 250 | |
| Core keys used | `animal_id` 1–17 000 by section (the teaching animals 1–12 and 14 601–14 608 excluded from patients); staff 1–85 by the core's layout (D317, D324); `request_id` the core's imaging requests (1–17 000, kind a function of the id, D302); `exchange_id` 1–700 | as the core documents them |

**What the load needs of the core's.** So that the year's bookings meet
the year's consultations without reading `clinic` (procedure 4, as
`vet-lab` asked for its requests, D302), the core documents (item 1 of
the changes, O175): each consultation's kind, section, vet and start as
functions of its id, `booking_id` set to its own id when scheduled; the
vet picked among those the rota's pattern puts on shift; the staff
layout; the teaching animals; the history's deaths as a function of the
animal's id. Their names are the core's key functions
([vet-core](vet-core-domain.md#the-key-functions-d374-d375-d379), D374):
`core_consultation`, `core_staff`, `core_death`, `core_request` (an
imaging study's code from
[vet-machinery's catalogue](vet-machinery-domain.md#the-procedure-catalogue-d372-d373)),
`core_exchange` (the inbound examinations' accepted dates, their
reason and the partner patient's species, D413),
`core_referring_practice` (a trainee's practice beside its referring
vet) and `core_shifts`: **the rota's pattern lives in the core's
`data/keys.sql`**, with the history's absences, because the core's
history needs it and loads without this part. This part's load writes
`sched_shifts` from its rows with no absence and `sched_absences` from
the others; `sched.rota.publish` carries the same pattern (without the
history's absences: live absences are this part's table) in its own
statement, and the GM notes say the two texts are one formula.

**The history on the agenda (D408).** The core's scheduled
consultations are the agenda's: each sits in the half-hour slot of its
drawn time; in each section and slot they take, in id order, the
section's vets on a `day` shift covering the slot with no absence (in an
order the core hashes by the slot) and the section's consultation spaces
(domestic 4, horse 3, farm 2; D410), as long as both are left; one past
that has no row, the agenda having been full. A placed one starts in its
slot's first five minutes and closes by the slot's end. So this part's
load writes each attended booking as the slot (`starts_at` the slot's
start, 30 minutes), the consultation's vet, and the section's
consultation space of the consultation's rank among the slot's placed
ones (the first the lowest-numbered space); no two overlap, and every
vet is on shift. The bookings the core does not hold are placed by this
part's load around the agenda, as `sched_free_slots` would place them:
a no-show or a cancelled consultation booking in a slot the agenda
leaves free (a no-show's allocations stay live), a theatre plan where
its team and theatre are free of the agenda's consultations and of each
other (the farm's standing-surgery theatre is also a consultation
space), an imaging booking or a block on its machine, a session day on
its room, instructor and animals. Emergencies, ward rounds and herd
visits are never booked; the core gives them a vet with no booking over
their time when one is on shift, else the one its rota draw gives,
which the GM notes name (an emergency taken between two consultations
is no double booking: T100's witness is the bookings').

**An inbound examination's booking (D413).** `core_exchange` returns the
reason and the partner patient's species the core's load writes. The
booking takes the machine they name: a CT examination the small-animal
CT (7) for a dog or a cat, the large-bore CT (8) for a horse or a cow;
an MRI examination the standing MRI (10) for a horse, the 1.5 T MRI (9)
otherwise (a calf, for a cow); scintigraphy the gamma camera (16); a
cardiology examination the domestic ultrasound (14) for a dog or a cat,
the portable ultrasound (15) otherwise. A second opinion or an
endoscopy takes no machine: a consultation booking of the species'
section (dog and cat domestic, horse, cow farm), the section's
first-referral type, with a vet and a consultation space. The load and
purpose 11's `book-requests` (which reads the same two values from
`exchanges`) map alike.

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret.

| Role | Who | Reads | Writes |
|---|---|---|---|
| `sched` | owns everything; no login | | |
| `sched_app` | the practice software's scheduling module on `pms` (D276): reception, the theatre planners, the rota, the training office | every `sched_` table and view; executes `sched_free_slots` | bookings, allocations, shifts (published, clocked), absences, sessions' state, trainees, enrolments; never the reference tables (rooms, hours, machines, types, courses, settings) |
| `sched_reports` | the periodic reports (the working-time feeder), on the standby | every `sched_` table | nothing |
| `vet_reports` (the core's) | the back office on the standby, as on every core table (vet-core's grants, master spec 9.2) | every `sched_` table, granted by this schema where the role exists (in a database of its own on an instance without the core, it does not; D414) | nothing |

The purposes' role (`sched_interfaces` for the flows with the core)
comes with step 7.

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| Reference (settings, rooms, hours, machines, types, courses) | about 240 | none |
| Bookings | about 25 700 (with about 800 ahead of T0) | about 88 |
| Allocations | about 54 000 | about 180 |
| Shifts, absences | about 22 700, 600 | about 55 (weekly, 380 on Fridays), under one |
| Sessions, trainees, enrolments | 125, 750, 1 250 | under one, 2, 3 |
| **Total** | **about 0.11 million rows** | **about 330 rows** |

Under the core's 0.28 million in the same database: `clinic` with
scheduling holds about 0.39 million rows, well within "the data schema
stays simple and the tables small" and `records`' reservation (2.25G of
disk); about 30 MB more with indexes, the GiST indexes among them.

### Plausibility points (step 4, ruled, D317)

1. **Allocations outweigh bookings**, two to one: every booking takes a
   vet or a machine and a room, a surgery four resources.
2. **Slots computed, never stored**, by one function in the database.
3. **Exclusion constraints** as the double-booking guard: PostgreSQL's
   own answer, needing `btree_gist`; an overlap the function missed is
   refused, never stored.
4. **Bookings in `clinic`**, the practice software's own database, no
   node of their own (O171).
5. **The history's attended bookings take their consultation's id**, so
   two loads agree without reading each other.
6. **The rota a pattern of the staff id and the week**, published weekly;
   the core's history picks its vets by the same pattern.
7. **Teaching animals are resources**, allocated like a room, their
   limits in the slot function.
8. **Four roles**: the owner, the application, the reports, and the
   purposes' one (step 7).

## Classification and governance (step 5)

### Classification

v0.4's three classes, applied as `vet-core` applies them (D280): keys
`<table>.<column>`, the scenario's copy adding the database (procedure
6, item 2). The table gives the personal and customer-linked columns;
every other column of every table and view is `internal`.

Readings for scheduling:

- **The patient follows the core.** An animal's id with no identifier
  beside it is `customer-linked` (it leads to its owner through
  `ownerships`), as in the core's consultations.
- **A teaching animal leads to the clinic**, owner 1, no person: an
  allocation's `animal_id`, which holds teaching animals only, is
  `internal`.
- **Staff ids are the clinic's work record** (the core's reading,
  D280): `internal` on bookings, allocations, shifts and absences. An
  absence's `note` is about a named staff member and may reveal health:
  `personal`, and rule 4 forbids a reason in it.
- **Trainees are people**: their names and contacts personal, their id
  personal beside them, `customer-linked` on an enrolment; a referring
  vet's id stored beside a trainee's name is personal; a certificate
  number identifies its holder, personal.
- **Free text** (a booking's notes) may name the owner: `internal` by
  class, a trap (step 8), as the core's findings are.

| Table | `personal` | `customer-linked` |
|---|---|---|
| `sched_bookings` | | `animal_id` |
| `sched_absences` | `note` | |
| `sched_trainees` | `id`, `name`, `email`, `phone`, `referring_vet_id` | |
| `sched_enrolments` | `certificate_number` | `trainee_id` |
| `sched_upcoming` (view, not built in v0.5, D321) | | `animal_id` |

Animal health is no special category (O112); a staff member's is (GDPR
Art 9), hence rule 4.

### The business's own rules

The part's default policy (procedure 6, item 1), beside the core's and
the lab's, built into `docs/policy.md` and its `governance:` fragment.
Its home is the core's unnamed EU member state (D278); a figure marked
*game value* is a choice, not the law. Sources as in "Regulations", not
re-read for this draft.

**One place at a time.** No staff member, room, machine or teaching
animal is allocated twice at once; the database refuses it.

**Bookings follow the rota.** A booking takes a staff member on a shift
covering it and on no absence; a booking outside a resource's hours is
refused by the slot function.

**Working time.** Every shift is planned and clocked; at least 11
consecutive hours' rest between two shifts, a weekly rest of 24 hours,
at most 48 hours a week on average over four months, night work 8
hours in 24 on average (Directive 2003/88/EC, Arts 3, 5, 6, 8, 16(b)),
a night shift 12 hours at most (*game value*); on call at home counts for the
time clocked on a call-out (*game value*, the clinic's reading of the
case law). The working-time record is kept two years (*game value*;
Germany's rule).

**Absences.** An absence records its kind only; never a diagnosis, an
illness or a reason (GDPR Art 9), so the screens that show the rota show
no health data.

**Least data in a booking.** A booking names the animal by id; the
owner's contact stays in the core; notes carry no owner's name or
contact (core rule 10). No appointment reminder goes out in v0.5
(D321).

**Cancellations.** A cancelled booking frees its resources at once; a
booking not checked in 30 minutes after its start is a no-show
(*game values*); a dead animal's future bookings are cancelled
(`deceased`) within minutes.

**Teaching animals.** Handling and examination only, nothing above a
needle's insertion (Directive 2010/63/EU, Art 1(5)(f)); at most two
sessions and four hours a day, a rest day after two working days
(*game values*).

**Certificates.** A certificate names the course, the dates, the hours
attended and the lead instructor; issued only for 80 % of the hours
attended (*game value*).

**Trainees (GDPR).** Processed to run the course (Art 6(1)(b)); their
contacts erased three years after their last session, enrolments and
certificates kept five years (*game values*).

**Retention.** Bookings five years, as the clinical record (D280, rule
9); shifts and the working-time record two years; then erased.

**What the data model took from these rules**: the exclusion
constraints; the slot function reading the rota and absences; clocked
times on shifts; absences without a reason column; the release trigger; the teaching animals' limits in the
settings.

### The rules (ruled, D317)

For the owner to judge realistic, as D280 and D302 were:

1. **One place at a time**, enforced by the database.
2. **Bookings follow the rota and the hours.**
3. **Working time**: 11 hours' rest, 24 weekly, 48 average over four
   months, nights 8 average; on call counted when called out; records
   two years (2003/88/EC; *CCOO*; game values).
4. **Absences without a reason** (GDPR Art 9).
5. **Least data in bookings.**
6. **Cancellations** free the slot at once; no-show after 30 minutes; a
   dead animal's bookings cancelled.
7. **Teaching animals**: below the needle threshold; two sessions and
   four hours a day, a rest day after two (game values).
8. **Certificates** for 80 % attendance.
9. **Trainees**: contacts three years, records five (game values).
10. **Retention**: bookings five years, working time two.

## The producer profiles (step 6)

The part's own applications' writes into `clinic`, the rates of every
flow it meets, and the history the load plants to meet them; built on
the core's
([vet-core](vet-core-domain.md#the-producer-profiles-step-6)): volume
and work streams, input types, intensity and the history, readable
fragments with no planted fault (D276).

**Producer or purpose.** What reception, the planners, the rota and the
training office write is this step's, on `pms`. The flows between
scheduling and the core (the check-in opening a consultation, an imaging
request booked, an accepted examination booked, a dead animal's bookings
cancelled) and the working-time record are purposes (procedure 4, step
7; O172, O178).

### The application and its node (D276)

| Application | Node | Connection, role | What it does |
|---|---|---|---|
| The practice software's scheduling module | `pms`, the core's scheduler node | `sched`: `records:5432/clinic` (where the part lands, O171), `sched_app` | bookings made, moved and cancelled; check-ins and no-shows; theatre plans; the rota, its publication and the clocking; sessions, enrolments, attendance and certificates |

No new node: `pms` gains a connection and the part's fragments, merged
by `gmctl compose` (D264) under the keys' `sched.` prefix. One intensity
for the node (D276): the core's and the part's rates are one business's.

### Rates at intensity 1.0

Volume streams, on `sched` as `sched_app`:

| Key | What one call writes | Rate | Arrivals, shape | A day: Mon–Fri / Sat / Sun / average |
|---|---|---|---|---|
| `sched.bookings.make` | a consultation booking: the section by `choice` (domestic 75, horse 18, farm 7), a type of it, a patient of the section's range by a hash (never a teaching animal nor one the core's death function marks dead), a lead time by `choice`, a preferred hour by the section's shape; the first slot `sched_free_slots` gives at or after it; the booking and its allocations in one statement; a source by `choice` (phone, desk, follow-up, referral) | 8.4/h | poisson, `reception` | 92 / 34 / 0 / 71 |
| `sched.bookings.cancel` | a future booking, `booked`, cancelled (owner or clinic), the trigger releasing its slot | 0.85/h | poisson, `reception` | 9 / 3.5 / 0 / 7 |
| `sched.surgery.plan` | a theatre plan two to ten days ahead: theatre, surgeon, anaesthetist, nurse of the section | 0.6/h | poisson, `office` | 6 / 0 / 0 / 4.3 |
| `sched.trainees.enrol` | an enrolment in an `open` session, a new trainee in three of four; `full` at the last seat, then `waitlisted` | 0.38/h | poisson, `office` | 3.8 / 0 / 0 / 2.7 |
| `sched.enrolments.cancel` | an enrolment cancelled, the first waitlisted enrolled | 0.04/h | poisson, `office` | 0.4 / 0 / 0 / 0.3 |
| `sched.absences.record` | an absence (leave in nine of ten), the staff member's future bookings in it moved by reception's next pass (below) | 0.04/h | poisson, `office` | 0.4 / 0 / 0 / 0.3 |

Work streams, on `sched` as `sched_app`:

| Key | What it takes and writes | Capacity | Shape | Follows |
|---|---|---|---|---|
| `sched.bookings.arrive` | the oldest consultation, imaging or theatre booking starting within the next 10 minutes, `booked`: `arrived` at its start (give or take five minutes, by a hash); one in twenty left (by a hash of its id) for the no-show | 40/h | `flat` | about 75 arrivals a day, 60 of them consultations |
| `sched.bookings.no-show` | a booking 30 minutes past its start, still `booked`: `no-show` | 10/h | `flat` | about 3 a day |
| `sched.bookings.move` | a future booking whose staff member has an absence over it: moved to the first free slot (cancelled `moved`, rebooked, the new booking's source `desk`) | 4/h | `office` | under one a day |
| `sched.shifts.clock` | a shift started up to ten minutes ago, not clocked in: clocked in (by a hash, five minutes either side); a shift ended up to an hour ago, not clocked out: clocked out (on time in four of five, up to an hour late otherwise); an on-call shift clocked only on a call-out (one night in four, by a hash) | 30/h | `flat` | about 55 shifts, 110 clockings a day |
| `sched.sessions.attend` | a session day ended with enrolments unmarked: each attended (95 %, by a hash) or not, its hours added | 20/h | `office` | about 10 a session day |
| `sched.sessions.close` | a session whose last day has ended: `held`; certificates issued for 80 % attendance | 2/h | `office` | two a week |
| `sched.sessions.open` | a `planned` session eight weeks ahead of its first day: `open` | 2/h | `office` | two a week |

Reads, on `sched` as `sched_app`: `sched.slots.find` (reception's search
for a type's next free slots, `sched_free_slots` over two weeks; 12/h,
poisson, `reception`, concurrency 2), `sched.agenda.day` (a section's or
a vet's day: bookings and allocations; 30/h, poisson, `clinic-day`),
`sched.theatre.board` (today's theatre plans; 6/h, even, `flat`),
`sched.rota.week` (a team's week; 2/h, poisson, `office`).

Fixed-time operations (`jobs.yaml`, scenario time):

| Job | When | What |
|---|---|---|
| `sched.rota.publish` | `0 12 * * 5` | the seventh week after this one generated by the pattern as planned shifts, so the planned rota stays past the 42-day horizon until next Friday; the week after next's planned shifts an absence covers removed, the others `published` (D411); each machine's weekly block (the MRI's quality assurance on Wednesday morning, the CT's service) booked; idempotent on (`staff_id`, starts at) |

`sched.rota.publish` is set-based work: the GM may move it to the
database node's `pg_cron` (D206, D207).

**The rota's pattern** (documented in the GM notes, the same function in
the load, the job and the core's history, O175): vets a day shift on
four weekdays, the fifth off by `(id + week) mod 5`, domestic vets of
odd id 10:00–20:00, the others 08:00–18:00; one vet a night,
20:00–08:00, by rotation over the 25 section vets (1–25), the night's
vet off that day and the next, the imaging vets (26–28) keeping their
own on-call among the three (D339); two domestic vets on Saturday
08:00–13:00 for the bookings; **a duty vet for each section on Saturday
and on Sunday, 08:00–20:00** (D384), by rotation over the section's
vets, never one of that weekend's night vets (Friday's, Saturday's or
Sunday's), so each section has a vet from 08:00 to 20:00 every day and
the night vet after; a surgeon and an anaesthetist on call
each night; nurses and carers in day, late and night shifts around the
clock (day 07:00–15:30, late 13:30–22:00, night 21:30–07:30), on a
four-week cycle staggered by id, phase `(id + week) mod 4`: day Monday
and Tuesday and night Thursday to Sunday; night Monday to Wednesday and
late at the weekend; late Monday to Friday; day Wednesday to Sunday
(D388). Each section's every shift of every day is held by its nurses
and technicians (D388); the carers follow the same cycle, so the
horse's four (57–60) and the domestic's four (63–66) hold every shift
too, and the farm's two (61, 62) two of the four phases each week, the
farm's other shifts held by its nurses alone (D394); reception
Monday to Saturday; the lab's staff alternating day and late weeks on
the bench's hours, with its on-call nights; the imaging vets and the
radiographers their own on-call; instructors on four weekdays of five,
every session day among them. The pattern leaves 11 hours' rest
everywhere (a night is always followed by a day off), a weekly rest of
24 hours and at most 48 hours a week on average: WT2's "the rota leaves
none" holds for it.

**The history's absences** (D388), in `core_shifts` and so in this
part's load, never in `sched.rota.publish` (live absences are this
part's table): only on weekday day and late shifts, so the nights and
the weekend's cover are never short; each a period of one day to two
weeks; leave about five weeks a year a head (above the four weeks of
Directive 2003/88/EC, Art 7), training and `absent` the rest; about 600
periods a year, leave nine in ten.

### The business hours (shapes)

| Shape | Hours |
|---|---|
| `reception` | Monday to Friday 08:00–19:00: 1.2 at 08–10, 1.0 at 10–12, 0.6 over lunch, 1.0 at 14–17, 0.8 at 17–19; Saturday 08:00–12:00 at 0.8 |
| `clinic-day`, `office`, `flat` | the core's ([vet-core](vet-core-domain.md#the-business-hours-shapes)) |

The arrivals follow the agenda, not a shape: the rooms' hours and the
preferred hours the booking stream draws (domestic busiest late in the
afternoon, horse and farm in the morning, the core's `clinic-day`)
place them. The GM notes compare the agenda's hours with the core's
history.

### Input types (D276, D303)

Every value SQL's: the section mix, the types, lead times and sources by
the weighted `choice` (D303); a patient's id by a hash into the
section's documented range; the slot by `sched_free_slots`; per-row
variation (an arrival's minute, a no-show, a clocking's lateness,
attendance) by a hash of the row's id, never `random()` (D117). No
domain builder: `sched.bookings.make` is one statement (a CTE calling
the function, inserting the booking and its allocations).

### Intensity, and the history before T0 (D276, D279)

- **One intensity with the core** on `pms` (D276, core point 8): the
  bookings made and the arrivals they cause are the core's scheduled
  consultations.
- **Bookings made run ahead of arrivals.** At intensity 1.0 the 71
  bookings a day arrive as about 60 consultations ten days later on
  average; a scenario at another intensity changes the bookings at once
  and the arrivals only as the agenda ahead turns over, about two
  weeks: its story says so, or the players read a fault into the lag.
- **The history ends at intensity 1.0**, ramped as the core's from about
  60 % (D279), on the same shapes.
- **In flight at T0** (last night's backup):
  - the agenda ahead: about 800 bookings over the next six weeks, the
    next days nearly full, thinning further out; the rota published to
    the end of the week after next and planned beyond it to the end of
    the seventh week after the last Friday's (D411); the next three
    months' sessions,
    those within eight weeks `open`, their enrolments;
  - today's first bookings `booked`, none arrived (the night leaves
    none); the night's shifts clocked in, not yet out;
  - yesterday's bookings all `arrived`, `no-show` or `cancelled`; every
    attended consultation booking of the history matching its
    consultation by id (O175);
  - sequences set after each range.
- **Unseen.** The load writes without trace (D265).

### Cold storage (D297)

Nothing ships: about 330 rows a day against the threshold of about
50 000 (D296), and the working-time record reads the year. In `clinic`,
the part rides the core's WAL archive and base backup (D299); in a
database of its own on `records`, the same.

### Growth, for the GM notes (D298)

At intensity 1.0, in `clinic`:

| | Rows | Size |
|---|---|---|
| A day, on average | about 330 new rows (88 bookings, 180 allocations, 55 shifts' worth) and 200 updates (arrivals, cancellations' releases, clockings) | about 0.12 MB with indexes, the GiST ones included, before bloat |
| A reception hour on a weekday | about 30 | |
| A Friday at 12:00 | about 380 shifts at once, the rota's publication | |
| A Sunday | under a fifth of a weekday: the clockings | |

Over an aging the part's disk is never the problem: its constraint
violations, its releases and the agenda's consistency with the core
are.

### Points for the owner (step 6, ruled, D317)

1. **No node of its own**: the scheduling module on `pms`, one
   connection more, `sched_app`.
2. **The agenda drives the arrivals**: the core's scheduled
   consultations open from bookings checked in, not from a stream of
   their own (O172).
3. **Reception's week**: Monday to Friday 08:00–19:00, Saturday
   mornings; about 71 bookings a day ten days ahead on average; 10 %
   cancelled, 5 % no-shows.
4. **The rota published on Fridays at noon**, a pattern of the staff id
   and the week, every shift clocked.
5. **Two sessions a week** at the training centre, enrolments on office
   hours.

## Purposes that fit (step 7, ruled, D317)

None of the ten existing clinic purposes fits as built
([clinic-purposes](clinic-purposes.md) 2). Two new ones, each its own
unit under `purposes/`, in v0.4's format with D307's extensions:

| # | Purpose | Kind | Fits | Cadence (scenario time) | Runs on | Source → target |
|---|---|---|---|---|---|---|
| 11 | `vet-bookings-sync` | transformed in place (the clinic's first) | core, scheduling | every minute | `interfaces` | `clinic`'s `sched_` tables ↔ `clinic`'s record |
| 12 | `vet-working-time` | pulled, periodic | core, scheduling | feeder 09:30 daily; the month on the 1st | `backoffice` | the standby → `office` |

Numbered after the ten (D306), first of the parts' six, 11 to 16 in [clinic-purposes](clinic-purposes.md#16-the-parts-purposes-11-to-16) (D324).

### 11. `vet-bookings-sync`: the agenda and the record

**Kind**: transformed in place: four flows between the part's tables and
the core's, in one database when the part lands in `clinic` (O171), two
when it lands apart; a hospital's scheduling system and its record kept
in step by the integration engine, as human hospitals do with their
scheduling messages. The alternative, the practice software's own jobs
on `pms`, is O172's.

**Jobs** (on `interfaces`, script jobs holding `clinic` as
`vet_interfaces` and `sched` as `sched_interfaces`, D303):

| Job | Cadence | What it computes |
|---|---|---|
| `check-in` | `* * * * *` | the consultation bookings `arrived` since its watermark with no consultation in its ledger: each consultation opened in the core (kind `scheduled`, the section, the allocated vet, started at the arrival, `booking_id`), only if none carries that booking id, the ledger row written in the same `clinic` transaction |
| `book-requests` | `* * * * *` | the core's imaging requests `requested` since its watermark with no live booking: each booked on its study's machine by `sched_free_slots`, an urgent one at the first slot today (the CT around the clock), a routine one within two working days (D376); the inbound examinations `accepted` since the watermark: booked on the accepted date, or the first free slot after it and an `ops.incidents` row for the gap |
| `cancel-deceased` | `* * * * *` | the animals the core recorded `died` since its watermark: their future bookings `cancelled`, reason `deceased`, the trigger releasing the slots |

**Trace**: `sched_bookings` (state, `request_id`, `exchange_id`),
`consultations.booking_id`, `ops.booking_consultations` (booking,
consultation, at), `ops.watermarks`, `ops.incidents`, `ops.runs`; the
runner's log.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| BS1 | Every consultation booking `arrived` since the judged moment has its consultation, carrying its id, within 2 minutes | triggers | about 60 a day, on the rooms' hours |
| BS2 | No booking has two consultations; no consultation's booking is anything but `arrived` | runs | every run; the retried ones |
| BS3 | Every imaging request recorded since the judged moment has one live booking on its study's machine within 2 minutes, an urgent one starting the same day | triggers | about 11 a day, a quarter urgent, around the clock |
| BS4 | Every animal recorded `died` since the judged moment has no future booking left `booked` 2 minutes later | triggers | about one death a day; a future booking for about one in three (follow-ups) |
| BS5 | Every inbound examination accepted since the judged moment is booked, on its date or with an incident | triggers | under one a day: rare (D306 point 6) |

**Data moved**: `sched_bookings.animal_id` (customer-linked) to
`consultations.animal_id` (customer-linked); no name or contact either
way; the booking's notes never copied.

**Roles** (with step 7's others, [clinic-purposes](clinic-purposes.md#the-roles-the-purposes-add)):
`sched_interfaces` on the part's tables (reads bookings, allocations,
types, machines, hours, shifts, absences, settings; executes
`sched_free_slots`; writes bookings and allocations, and bookings'
state); `vet_interfaces` on `clinic` gains `INSERT` on `consultations`
(its open columns only: animal, site, section, vet, kind, `booking_id`,
started at) and `SELECT` on `animals` (`id`, `status`, `died_at`).

**Candidate faults**: T112 to T119 (step 8).

### 12. `vet-working-time`: the working-time record

**Kind**: pulled, periodic (D265, D300): the record a labour inspector
may ask for (Directive 2003/88/EC; *CCOO*), kept in `office`, the back
office's; fed daily, summed monthly.

**Jobs** (on `backoffice`, reading the standby's `clinic` as
`sched_reports` for the shifts and as `vet_reports` for the staff's
names, writing `office` as `office_jobs`):

| Job | Cadence | What it computes |
|---|---|---|
| `feed-working-time` (feeder) | `30 9 * * *` | the shifts that **started** yesterday, the customer's day, every night shift clocked out by now: per staff member, the planned and worked hours, night hours, call-outs; the rest before each shift against the previous one, a breach under 11 hours; into `office.working_time_days` and `office.rest_breaches` |
| `close-working-time` | `0 5 1 * *` | each staff member's past month from the daily rows: hours, nights, breaches, the weekly average over the last four months; into `office.working_time_months` |

At 09:30 because a night shift ends at 07:30 or 08:00: a feeder in the
night with the others would count yesterday's night shifts unfinished
(T124).

**Planted before T0**: the year's daily rows, every full month, the
breaches the history holds (none by the pattern; the absences' moves a
handful).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| WT1 | Each feeder run holds every shift started on its local day, its worked hours equal to the clocked ones | runs | about 55 shifts a day, a dozen at night |
| WT2 | Every rest under 11 hours between two consecutive shifts of one staff member is a breach row | runs | the rota leaves none; a moved booking's overtime or a fault's pattern makes them |
| WT3 | A month's figures equal the sum of its days; the average over the last four months | code | the planted months; the 1st's run if the GM places one |

**Data moved**: `staff.name` (personal, the core's) into
`office.working_time_days`, the inspector's record; absences' kinds
only, never their notes.

**Roles**: `sched_reports` on the standby (step 4), `vet_reports` (the
core's), `office_jobs` (D306).

**Candidate faults**: T121, T123 to T125 (step 8).

### No appointment reminders in v0.5 (D321)

The owner ruled none in v0.5: the portal reminds owners of vaccinations
only, with their consent ([vet-portal](vet-portal-domain.md)). Were a
later version to add them, they would be a pushed purpose queuing
through `portal_outbox`, reading a view of the next 48 hours' bookings
without notes or staff (`sched_upcoming`, not built now).

### `office` at T0, the part's share

| What | Rows planted |
|---|---|
| Working-time days | about 20 000 (85 staff, about 4.5 shifts a week, the year) |
| Rest breaches, months | a handful, about 1 000 |
| **Total** | **about 21 000 rows**, live about 60 a day |

## Traps (step 8)

No owner checkpoint (D309). Read as [clinic-traps.md](clinic-traps.md)
reads them (witness at the clinic's rates; "fixed on" the layer the
players change; catalogue; D290 class). Two rules bind them as they
bind the core's: a rare flow (inbound examinations) is planted only with
a story raising its rate from T0 (D306 point 6); a fault in a flow with
the core is judged on the trace after the fix.

**The core's and the lab's traps that bite here too**: T5 (an
application role superuser: `sched_app`), T7 (autovacuum off: on
`sched_allocations` or `sched_bookings`, updated at every arrival and
cancellation), T9 (the pooler's pool at the 17:00 peak, now with the
booking stream's searches), T14 (a sequence left below its range: on
`sched_bookings`, no booking made after T0), T24 (free text copied: a
booking's notes), T31 to T37 (the archive and the standby, the part
riding the core's instance), T73 and T74 (the report runner's role and
connection, for `vet-working-time`), T82 (an `interfaces` job holding
its transaction across a call: `book-requests` while the slot function
runs).

### 1. Constraints and the slot function

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T100 | Staff double-booked: the slot function checks rooms' and machines' allocations but not staff's, and the staff exclusion constraint is dropped | a vet booked in two rooms at once: owners waiting, a consultation started 40 minutes late; the core's scheduled consultations of one vet overlapping (never so in the history, D408; an emergency or a round over a booking is not this trap's) | overlapping live allocations of a staff member, several a day from the first reception hour | the function, then the constraint: it cannot be added while overlaps exist (no `NOT VALID` for an exclusion constraint), so the future overlaps must be moved first | new | D |
| T101 | The allocations' range built `'[]'` (inclusive) instead of `'[)'` | back-to-back bookings refused as overlapping: every slot after a booking unbookable, the agenda full of gaps | `pms`' errors (`23P01`) on `sched.bookings.make`, at once and many a day; utilisation falling | the generated range, the table's definition | new | M, V as the agenda thins |
| T102 | The release trigger disabled, or its `WHEN` testing another state | cancelled bookings still holding their slots: "the MRI is full for three weeks" while a tenth of its slots are cancellations | live allocations of cancelled bookings, about 7 more a day; the slot search finding nothing near | the trigger, then the allocations | new | V, D when the imaging team complains |
| T103 | The slot function comparing `starts_at` and `ends_at` columns instead of the range (`&&`), or unbounded by the horizon | the GiST indexes unused, every search reading every allocation; reception waiting at the peak | `pg_stat_statements` on `records`: `sched_free_slots`' time per call, at once, growing with the year | the function | adapts `pg-join-index-missing` | M |
| T104 | The hours' local times read in UTC (`opens` cast without the customer's zone) | at a non-zero shift, slots offered before the clinic opens or after it closes: owners at a locked door, the evening peak lost | bookings starting outside their room's hours, every day at a non-zero shift | the function | adapts `scheduler-job-wrong-timezone` | M, V at a large shift |
| T105 | The function ignoring absences | vets booked on their leave: owners turned away, reception phoning to move them | allocations overlapping an absence, a few a week, more around holidays | the function, then the bookings moved | new | V, D when owners complain |
| T106 | The function taking any vet of the section, not one on a shift covering the slot | consultations booked after a vet's shift: overtime, rest breaches the next morning | allocations outside every shift of their staff member, several a day | the function | new | V |
| T107 | The teaching animals' limits ignored for a session | a dog in three sessions a day: a welfare breach an instructor reports | teaching allocations over the limits, at each session planned | the function | new | M, V with the instructor's complaint |
| T108 | `sched.rota.publish` not idempotent (the unique index on `staff_id` and start dropped), run twice after a failure | two shifts for each staff member that week: hours doubled in the working-time record, the slot function's choices skewed | duplicate shifts, at the second run (a Friday) | the index, `jobs.yaml`'s statement | adapts `scheduler-insert-retry-duplicates` | M |
| T109 | The rota's pattern putting a day shift the morning after a night | 11-hour rest breached weekly for every night worker (rule 3) | rest under 11 hours, each week's nights; the feeder's breaches (unless T121 hides them) | `jobs.yaml`'s statement | new | V |
| T110 | Enrolment's seat check without a lock (the count read, then the insert) | a session over its seats on a popular course | enrolments over seats; rare at three a day, with a story's rush | the stream (reported), a constraint trigger | new | M |
| T111 | Certificates issued without the attendance threshold | trainees certified for hours they did not attend: a continuing-education credit unearned | certificates with hours under 80 %, each session closed | the stream (reported) | new | M |

### 2. The flows with the core (`vet-bookings-sync`)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T112 | `vet_interfaces` granted `INSERT` on all of `consultations`, or `UPDATE` | the integration engine able to write the record's findings and signatures | the grants, at once | the grants | new | M |
| T113 | The priority dropped in `book-requests`: urgent imaging booked as routine | an emergency's CT two days later; the emergency team phoning radiology (BS3) | urgent requests whose booking is not today, at the first urgent request (about three a day) | `interfaces`' script | new | D |
| T114 | A retry booking a request again (the live-booking check missing) | two MRI slots for one study, one wasted | two live bookings for one `request_id`, at each slow run | `interfaces`' script | adapts `scheduler-insert-retry-duplicates` | M |
| T115 | The check-in's watermark from the run's start while arrivals commit later | an animal checked in with no consultation to open: the vet writing on paper, the record filled later by hand (BS1) | arrived bookings with no consultation, a few a day at the busy hours | `interfaces`' script | adapts `purpose-watermark-misses-updates` | V, D once vets complain |
| T116 | A consultation opened twice for one booking: the core's unique index on `booking_id` missing and the job's existence check dropped | two consultations to close and sign for one visit (BS2); the core's signing backlog | consultations sharing a `booking_id`, at each retried run | the index, `interfaces`' script | adapts `scheduler-insert-retry-duplicates` | M |
| T117 | The check-in taking bookings by start time, not by `arrived` | consultations opened for no-shows and cancellations: records with no animal behind them | consultations whose booking is `no-show` or `cancelled`, a few a day | `interfaces`' script | new | M, V over days |
| T118 | `cancel-deceased` missing, or its watermark on `died_at` rounded to the day | a dead animal's follow-up kept on the agenda, its slot lost and reception calling the owner | future `booked` bookings of `died` animals, about one every three days | `interfaces`' script, `jobs.yaml` | new | V, D when an owner complains |
| T119 | An inbound examination booked on the next free day, the exchange's date left as accepted, no incident | the other centre's animal arriving on a day the machine is full | bookings of exchanges on another date than accepted, with no incident; rare, a story raising the rate | `interfaces`' script | new | M |

### 3. Governance and the working-time record

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T120 | Absences' notes naming a health reason ("sick: back surgery"), planted at load and continued by the stream | special-category data about staff on every rota screen (rule 4) | `sched_absences.note`, at once | the data, then the application (reported) | new | M |
| T121 | `feed-working-time` comparing rests within a day only | a rest breach across midnight never recorded: the record clean while the rota breaks the rule (with T109, the cover-up) | breaches the shifts show and `office` lacks, each week's nights | the feeder's query | new | V |
| T122 | `sched_upcoming` carrying the notes, or the staff's names: dormant in v0.5, the view not built (D321) | the owner's reminder showing what the reception wrote, or a vet's name (rule 5), once appointment reminders exist | the view's definition, at once | the view | adapts `governance-personal-copied` | M |
| T123 | The feeder taking planned hours, not clocked ones | the record not "objective, reliable": overruns missing, the four-month average understated | worked hours equal to planned ones, every day | the feeder's query | new | M, V before an inspection |
| T124 | The feeder moved to the night with the others (02:15), or its day in UTC | yesterday's night shifts counted unfinished or split at UTC midnight: night hours lost or doubled | night shifts with no worked hours in the day's rows, every night | `jobs.yaml`, the feeder's query | adapts `purpose-day-boundary-wrong-zone` | M |
| T125 | On-call counted whole, as on site | hours overstated: breaches and averages for the surgeons on call that are none | on-call shifts' worked hours equal to their planned twelve, each night | the feeder's query | new | M |

### 4. Performance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T126 | `sched_bookings.request_id` unindexed | `book-requests`' live-booking check scanning every booking each minute | `pg_stat_statements` on `records`, at once | an index | `pg-join-index-missing` | M |
| T127 | `sched.agenda.day` calling `sched_free_slots` per room and slot to draw the free ones | the agenda screen slow at the 17:00 peak | the read's latency, each weekday peak | the read (reported) | adapts `scheduler-report-unbounded` | M |
| T128 | `sched.rota.publish` moved to `pg_cron` at Friday 12:00 as one transaction holding a lock on `sched_shifts` | reception's searches waiting on the rota's insert at a busy hour | lock waits each Friday at noon | `cron.job` | adapts `scheduler-batch-at-peak` | M |

### 5. False-alarm material

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "The MRI is idle every Wednesday morning" | its weekly quality assurance, a block | the block's booking |
| "A vet worked 13 hours on Tuesday" | a day shift and a night's call-out, the 11 hours' rest after kept, the four-month average under 48 | the shifts and the working-time record |
| "Twelve dogs have hundreds of bookings" | the teaching animals, within their limits | the allocations and the settings' limits |
| "Consultations open a minute or two after the owner arrives" | the check-in runs every minute | the ledger against the arrivals |
| "Next week's agenda is half empty" | the lead time: the next days fill last-minute, 30 % booked within two days | the history's lead times |

### Against the test selection (D316)

No trap of this part replaces one of the ten (ruled, D317; the
selection's two swaps, s5 and s9, went to the portal and housing,
D325): they cover
v0.5's new bricks and features (round trips, the archive, periodic
reports, `pg_cron`, the options model, governance), and scheduling adds
no brick or feature, only a domain. Should the owner want the part in
the selection (O179), the strongest are **T100** (staff double-booked:
D, PostgreSQL's exclusion constraints, the fix needing the data cleaned
first) or **T113** (urgent imaging booked routine, D, a flow's mapping
like s1), each on the bookings fixture below.

### Tests in v0.5 (D314)

**The minimal fixture, `bookings`**: `records` (`clinic`, the core and
the part loaded), `pms`, `interfaces` and the bastion; four nodes, about
0.8 CPU and 0.8G; T0 a weekday at 09:50. Under 30 minutes it proves: the
two loads agree (every attended booking's consultation by id, no
overlap, every vet of the history on shift); the exclusion constraints
refuse an overlapping allocation the test inserts (`23P01`); bookings
made through the slot function; arrivals checked in and their
consultations opened with `booking_id` within two minutes (BS1, BS2); an
imaging request from the core's `consultations.close` booked within two
minutes (BS3); a death the test records cancelling its animal's future
bookings (BS4); a cancellation releasing its slot; `sched.rota.publish`
moved to the next minute (D132), the week after next published, rerun
without a duplicate.

**`vet-working-time`** on the reports fixture's nodes (`records`, the
standby, `backoffice`) with T0 at 09:20, or the feeder moved: the day's
rows equal the clocked shifts, night shifts whole (WT1, WT2).

**Only the whole clinic or v1.0 shows**: the weekly rota's cycle and a
month's working-time close at their own times; the agenda turning over
across weeks, cancellations and no-shows at their rates; a session's
days and its certificates; the part's growth; the traps' "on the verge"
classes as an aging finds them.

## Node and capacity estimate

**No node of its own.** The part's tables in `clinic` on `records`
(O171); its producer fragments on `pms` (D276); its purposes on
`interfaces` and `backoffice`, the runners that exist. Estimate against
[clinic-capacity](clinic-capacity.md#the-whole-clinic-23-nodes-25-to-27-with-d238s-monitoring):

| Where | Adds | Reservation |
|---|---|---|
| `records` | about 0.11 million rows, 30 MB, 330 rows a day | none: within 0.5 CPU, 512M, 2.25G |
| `pms` | a connection, about 14 streams and a weekly job | 64M → 96M (the slot function's searches run on `records`, not on the node) |
| `interfaces` | three script jobs a minute | none |
| `backoffice` | one feeder a day, one monthly job | none |
| **Total** | **0 nodes** | **0 CPU, about 32M** |

The tally's "0 to 1 node, 0 to 0.1 CPU, 0 to 64M" becomes 0 nodes, 0
CPU and 32M. If the owner prefers the part in a database of its own
(O171), it lands on `records` beside `clinic` and `office`: no node, the
same reservation.

## Loading

`gmctl load-data` runs `schema.sql` then `load.sql` into `clinic` as
`postgres`, after the core's (procedure 3, "for a part, after its
core's"): `btree_gist` created, explicit ids in the documented ranges,
each sequence set after its range, the shift variables applied, the
core's ids computed by its documented functions without reading the
core's tables (O175), so the two loads are independent; the load's
sessions unseen (D265). About 0.11 million rows; size and time measured
at the build. After the sources' loads, `vet-working-time` plants its
year in `office` ([clinic-purposes](clinic-purposes.md) 4, item 5).

## Open points

- **O111**: the domain format, finalised in v0.5's master spec (D291),
  with the composition rules (D322, [procedure](domain-procedure.md) 10).
- The working-time sources are checked (see "Regulations"); the national
  retention periods stay game values.

## Questions for the owner

**Ruled on 2026-11-03** (D317): the owner, "i agree with the
recommendations as a whole", so each is closed as recommended, with
three changes from the fold-in: O169 and O176's machines are ten,
`vet-machinery`'s 7–16 (D324); O175's layout is the core's, adjusted for
`vet-machinery`'s imaging staff (D324); O178's appointment reminders are
not in v0.5 at all (D321). Kept as the record of what was asked.

- **O168 — The brief (step 1).** The brief above, written from your
  clinic brief and the split, since the procedure has you write it.
  *Recommended*: accept it, or correct what the centre's agenda really
  holds.
- **O169 — Scale and how booking works (steps 2 and 4).** 16 rooms, 7
  bookable machines, about 71 bookings a day ten days ahead, 10 %
  cancelled and 5 % no-shows; each booking takes a vet or machine and a
  room as rows of their own; slots computed by one function in the
  database, never stored; the database refusing any double booking.
  *Recommended*: accept as drafted.
- **O170 — What is booked.** Consultations, imaging studies, theatre
  plans (the plan only, the procedure staying the core's record),
  maintenance blocks and training sessions; not emergencies, herd
  visits, ward rounds or housing's boxes. *Recommended*: accept.
- **O171 — Where the part lands.** In the core's `clinic` database on
  `records`, no node of its own, as the practice software's scheduling
  module; alternatives: a database of its own on `records`, or a node
  of its own (0.5 CPU more, which the tally cannot spare).
  *Recommended*: `clinic`.
- **O172 — How bookings and the record meet.** A purpose on the
  integration engine, `vet-bookings-sync`, opening each checked-in
  consultation in the core, booking imaging requests and accepted
  examinations, cancelling a dead animal's bookings; the core's
  scheduled consultations then come from bookings (its
  `consultations.open` stream removed). Alternative: the practice
  software's own jobs on `pms`, faults there only reported, never fixed
  by the players. *Recommended*: the purpose.
- **O173 — The rota and working time.** Scheduling holds every staff
  member's shifts, published weekly, absences without reasons, and the
  clocked hours; on call at home counts only when called out.
  *Recommended*: accept.
- **O174 — The training centre.** Courses for vets, nurses, students,
  owners and handlers, canine and equine, one to three days; a waiting
  list; certificates for 80 % attendance; no fees in v0.5; teaching
  animals handled and examined only, at most two sessions and four
  hours a day, a rest day after two. *Recommended*: accept.
- **O175 — What the core's load must document for this part.** The
  staff's kind, section and specialty by id (a layout: vets 1–28, nurses
  and technicians 29–56, carers and grooms 57–66, receptionists 67–70,
  the lab 71–80 as ruled, instructors 81–85; superseded by the core's
  layout, D324, D327: section vets 1–25, imaging vets 26–28, nurses and
  technicians 29–51, radiographers and the biomedical engineer 52–56); the history's
  consultations as functions of their id, the scheduled ones carrying
  their own id as booking id, their vets on shift by the rota's pattern;
  the teaching animals 1–12 and 14 601–14 608, owned by the clinic; the
  history's deaths by id. *Recommended*: accept, as you accepted the
  lab's two constraints (D302).
- **O176 — The bookable machines.** Seven of `vet-machinery`'s
  machines, assumed ids 7–13 (CT, MRI, standing MRI, scintigraphy,
  radiography, overground endoscope, cardiac ultrasound); the lab's
  analysers never booked. *Recommended*: accept, the ids to agree with
  `vet-machinery`'s page.
- **O177 — The rules (step 5).** The ten in "The rules": one place at
  a time, the rota and hours, working time (11 hours' rest, 48 hours'
  average), absences without a reason, least data in reminders,
  cancellations, teaching animals' limits, certificates, trainees'
  retention, records' retention. *Recommended*: confirm them realistic,
  the EU sources to be re-read at review.
- **O178 — The purposes (step 7).** Two new ones, `vet-bookings-sync`
  and `vet-working-time`, built in v0.5 (twelve purposes in all);
  appointment reminders left to `vet-portal`. *Recommended*: accept.
- **O179 — The test selection.** No trap of this part replaces one of
  the ten (D316). *Recommended*: keep the ten; if you want scheduling
  represented, T100 (staff double-booked) in place of the
  least-needed one is the swap to make.

## Changes needed in shared pages

Applied on 2026-11-03 in the fold-in (D317, D324), with these
differences: the staff layout of item 1 is the core's adjusted one (vets
1–25 by section, 26–28 imaging; nurses and technicians 29–51, 52–56
imaging and biomedical; the rest as below), its domestic vets 18–25,
eight instead of eleven, the total still 85 and the rota's shifts
unchanged (D327); items 6 and 7 are replaced
by D324 (machines 7–16, `vet-machinery`'s) and D321 (no appointment
reminders); the purposes are 11 and 12 of sixteen.

1. **`vet-core-domain.md`** (O172, O175):
   - "Where the parts press on the core", the `vet-scheduling` row:
     replace "staff with their specialties and sites, rooms per site;
     the consultation a booking turns into, by id" with "staff with
     their kind, section and specialty, functions of the id; the
     consultation a booking turns into, by `booking_id`; the imaging
     requests; the teaching animals in a range; the deaths" (the core
     holds no rooms: they are the part's, D279).
   - Step 4, `consultations`: a partial unique index on `booking_id`
     (`WHERE booking_id IS NOT NULL`).
   - Step 4, "Deterministic key ranges": the staff layout (vets 1–28 by
     section, 1–10 horse, 11–17 farm, 18–28 domestic, specialties by
     id; nurses and technicians 29–56; carers and grooms 57–66;
     receptionists 67–70; the lab 71–80, D302; instructors 81–85)
     [applied as the core's layout, D324, D327: 18–25 domestic, 26–28
     imaging, nurses and technicians 29–51, 52–56 imaging and
     biomedical];
     the teaching animals, animals 1–12 (dogs) and 14 601–14 608
     (horses), owned by owner 1 from before the history; each history
     consultation's kind, section, vet and start a function of its id,
     documented, a scheduled one's `booking_id` its own id, its vet one
     the rota's pattern (this page, step 6) puts on shift; the
     history's deaths (which animals, when) a function of the id. To
     reconcile with `vet-housing`'s needs for carers, should its page
     propose another layout.
   - Step 6: `consultations.open` (7.4/h, scheduled consultations)
     removed from the volume streams; a note that the scheduled
     consultations are opened by `vet-bookings-sync`'s `check-in` from
     the bookings `sched.bookings.arrive` checks in, about 60 a day,
     their hours following the agenda; the "Weekly: the staff rota"
     cadence becomes `vet-scheduling`'s `sched.rota.publish`.
   - "Purposes that fit": `vet-bookings-sync`, `vet-working-time`.
2. **`clinic-purposes.md`**: sections 11 and 12 above added (or moved
   there, this page then linking); the at-a-glance table's two rows; the
   roles: `sched_interfaces` (new) and `vet_interfaces`' new grants
   (`INSERT` on `consultations`' open columns, `SELECT` on `animals`'
   `id`, `status`, `died_at`); `office` at T0 gains about 21 000 rows;
   "Twelve purposes", the first of kind *transformed in place*; section
   1's "No flow of the two domains is transformed in place" amended.
3. **`clinic-capacity.md`**: the `vet-scheduling` row of "The whole
   clinic" becomes "0 nodes, 0 CPU, about 32M (`pms` to 96M)"; the range
   narrows by 0 to 1 node and 0 to 0.1 CPU at the top.
4. **`clinic-traps.md`**: a section for `vet-scheduling`, T100 to T128
   with the false-alarm lines, or a link to this page's; the "also
   bites" notes on T5, T7, T9, T14, T24, T31–T37, T73, T74, T82.
5. **`clinic-test-selection.md`**: no change unless O179 swaps a fault;
   the `bookings` fixture listed for the part's own build checks.
6. **`vet-machinery`'s page** (a boundary, not its design): the
   bookable machines' ids (assumed 7–13) and kinds, its studies taking
   their request id from the core; if a study's producer needs the
   booked slot, it reads `sched_upcoming` or `sched_bookings` by
   `request_id` with a role of its own.
7. **`vet-portal`'s page**: the appointment reminders as one of its
   pushed purposes, reading `sched_upcoming` with a role it brings,
   the owner's contact from the core.
8. **`README.md`** (v0.5): "Next steps" and the documents list gain
   this page.
