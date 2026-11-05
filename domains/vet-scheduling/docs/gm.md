# The vet-scheduling domain: GM notes

`vet-scheduling` is the centre's agenda (v0.5 master spec 9.4;
[vet-scheduling-domain.md](../../../specs/versions/v0.5/vet-scheduling-domain.md),
which holds the design; capture W3 item 2 with "W3 item 2, revised" and
W3-b in the v0.5 wave log; spec D408 to D414): the rooms and the ten
bookable machines, the bookings and the allocations they take, the slot
function, the staff rota with its clocked hours and absences, and the
training centre. A **part** of `vet-core`: the core's keys by id with no
foreign key, every table and role prefixed `sched_`, in the core's
database `clinic` by the scenario's `at:`; its schema runs as well in a
database of its own (no `lands_with`).

| File | What |
|---|---|
| [`data/schema.sql`](../data/schema.sql) | roles, `btree_gist`, the tables with the four exclusion constraints, `sched_free_slots`, the trigger `sched_release`, the grants |
| [`data/load.sql`](../data/load.sql) | the reference rows, the rota, the year's bookings and the agenda ahead, the training centre; the build's checks |
| [`data/coherence.yaml`](../data/coherence.yaml) | six checks against the core, run by `load-data` after the loads |
| [`data/classification.yaml`](../data/classification.yaml), [`data/register.yaml`](../data/register.yaml), [`data/governance.yaml`](../data/governance.yaml), [`docs/policy.md`](policy.md) | the classes, the three processing activities, the governance fragment, the ten rules |
| [`producers/pms/`](../producers/pms/) | the practice software's scheduling module on `pms`: connection `sched` (`sched_app`), 17 streams, the shape `reception`, the Friday job |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | the part's axes in the core's one variant |

## The business

A referral hospital's agenda: reception books owners' animals on a
section's vets and consultation spaces, the imaging team its machines for
the core's imaging requests (an urgent one at once, a routine one within
two working days, D376), the theatre planners their surgeries, the
maintenance its weekly blocks, the training office its session days with
the clinic's teaching dogs and horses. No resource is in two places at
once: the database refuses it. The staff work to a weekly rota, published
each Friday at noon for the week after next and planned seven weeks
ahead (D411), every shift clocked. Not booked: emergencies, herd visits,
ward rounds, housing's units.

## Core keys used

The load computes the core's ids by its functions (vet-core
[`docs/gm.md`](../../vet-core/docs/gm.md), "Core keys"), streamed ahead of
it by `load-data`, never by reading `clinic`:

| Function | For |
|---|---|
| `core_shifts(n, day, utc_offset)` | the rota and the history's absences, staff 1–85, from the history's first week to the end of the planned weeks |
| `core_staff(n)` | each shift's section |
| `vc_agenda(s, load_epoch, utc_offset)` | the agenda's placed scheduled consultations of each half-hour slot (c, section, vet), which the core's notes name for this part (W3-g) |
| `core_consultation(n, load_epoch, utc_offset)` | each placed one's row (its animal, its start), so a slot's placed consultation with no patient (three a year at the reference T0) has no booking |
| `core_request(n, load_epoch, utc_offset)` | the imaging requests the core sent: code, animal, priority, state |
| `core_exchange(n, load_epoch, utc_offset)` | the inbound examinations accepted: reason, species, date (D413) |
| `core_animal`, `core_death` | a drawn patient's registration and death (the cancelled, no-show and future bookings, the theatre plans) |
| `core_referring_practice(v)` | a trainee vet's practice |

The staff layout is the core's (`core_staff`): section vets 1–10 horse,
11–17 farm, 18–25 domestic; imaging vets 26–28; nurses (`n mod 3 ≠ 0`)
and technicians 29–51 by section; radiographers 52–55; reception 67–70;
instructors 81–85. **Three texts are copies of the core's and must change
with it**: the slot function's staff layout (`core_staff`'s CASE, D412),
`sched.rota.publish`'s pattern (`core_shifts` without the history's
absences), and the booking stream's patients (the core's pools and its
at-home death draw). The load's shifts are `core_shifts`' rows; the build
compared the job's week with `core_shifts` for the same days: no
difference.

## The rooms, hours and machines

| Room | Code | Kind | Section | Hours (local) |
|---|---|---|---|---|
| 1–4 | C-1 to C-4 | consulting, **consultation spaces** | domestic | Monday–Friday 08:00–20:00, Saturday 08:00–13:00 |
| 5 | PR-D | procedure | domestic | Monday–Friday 08:00–18:00 |
| 6, 7 | TH-D1, TH-D2 | theatre | domestic | Monday–Friday 08:00–18:00 |
| 8, 9 | EX-H1, EX-H2 | examination, consultation spaces | horse | Monday–Friday 08:00–17:00 |
| 10 | AR-H | arena, consultation space | horse | Monday–Friday 08:00–17:00 (the equine sessions too) |
| 11 | TH-H | theatre (induction and recovery boxes) | horse | Monday–Friday 08:00–18:00 |
| 12 | EX-F | examination crush, consultation space | farm | Monday–Friday 08:00–16:00 |
| 13 | TH-F | standing-surgery theatre, **and** consultation space | farm | Monday–Friday 08:00–16:00 (D410) |
| 14, 15 | CL-1, CL-2 | classroom (24, 16 seats) | — | Monday–Friday 09:00–16:00 |
| 16 | PH-C | canine practical hall (14) | — | Monday–Friday 09:00–16:00 |

The machines are `vet-machinery`'s ids 7–16 (D324), held by id. **Around
the clock** (00:00–24:00 every day, the imaging on-call): the two CTs (7,
8), the three radiography units (11, 12, 13), the two ultrasounds (14,
15). **The imaging day** (Monday–Friday 08:00–18:00): the 1.5 T MRI (9),
the standing MRI (10), the gamma camera (16). The slot (minutes): 7 30, 8
60, 9 60, 10 90, the others 30, 16 60. The operator: a radiographer
(52–55) for CT, radiography, MRI and scintigraphy, an imaging vet
(26–28) for ultrasound, on any shift covering the study, on call
included. No room: the imaging suite is no bookable room.

## The types and courses

| Types | What |
|---|---|
| 1–5 | domestic consultations: first referral, follow-up, cardiology clinic, dermatology clinic, surgical consultation |
| 6–9 | horse: first referral, follow-up, lameness work-up, reproduction clinic |
| 10–12 | farm: first referral, follow-up, herd health consultation |
| 13–24 | imaging, one per section and machine (D372): domestic 7, 9, 11, 14; horse 8, 10, 12, 15, 16; farm 8, 13, 15; the duration the machine's slot; `study_code` empty (a booking's study is its request's code) |
| 25–27 | surgeries: domestic (a theatre 6 or 7, 120 minutes), horse (11, 180), farm standing surgery (13, 90); the team a surgeon (a section vet in surgery), an anaesthetist (another section vet, anaesthesia first), a nurse of the section |
| 28, 29 | blocks: a machine's (quality assurance, service), a room's (deep clean) |
| 30–45 | a session day of courses 1–16 (09:00–16:00, 420 minutes) |

Every consultation type is 30 minutes on its room's half-hour grid, in
one of its section's consultation spaces (D410). The courses: 1–7
canine (first aid for owners, dog handling, cardiology update, dermatology,
nursing skills, students' clinical examination, behaviour), 8–13 equine
(lameness, horse handling, first aid, students, nursing, dentistry),
14–16 mixed (radiation safety, zoonoses, antimicrobial use), one to three
days, 8 to 14 seats, 0 to 6 teaching animals (dogs for canine, horses for
equine, none for mixed); the practical hall, the arena or a classroom.

## The data

| Table | Ids | At the reference T0 (+2, 2026-11-04 07:50Z) |
|---|---|---|
| `sched_settings` | 1 | the zone and offset, horizon 42 days, no-show 30 minutes, two sessions and four hours a day for a teaching animal and a rest day after two, 80 % for a certificate, 11 hours' rest |
| `sched_rooms`, `sched_hours`, `sched_machines`, `sched_types`, `sched_courses` | 16, —, 7–16, 45, 16 | 236 rows in all |
| `sched_bookings` | 1–50 000 | 24 922 (below) |
| `sched_allocations` | 1–60 000, in the bookings' order | 51 653 |
| `sched_shifts` | 1–24 000, staff by staff, week by week | 23 826, 21 793 published |
| `sched_absences` | 1– | 794 periods |
| `sched_sessions` | 1–125 | 100 held, 12 open, 4 full, 9 planned |
| `sched_trainees`, `sched_enrolments` | 1–750, 1–1 250 | 742, 1 202 (953 attended, 889 certified) |

| Bookings | Ids | +2 |
|---|---|---|
| the agenda's attended consultations | the consultation's id (1–25 000) | 16 729 (the core's placed scheduled consultations, every one) |
| the history's cancelled and no-show consultation bookings | 25 001–28 000 | 2 114 cancelled, 880 no-shows |
| inbound examinations (D413) | **28 000 + the exchange's id** (a range the domain document leaves unnamed: 28 001–28 700 lie in its gap) | 300 (second opinions and endoscopies as consultations, the others on their machine) |
| imaging | 30 000 + the request's id | 2 918 (a few cancelled with their request, a few ahead) |
| theatre plans | 47 001–48 300 | 767 (horse 434, farm 113, domestic 220; see "Known limits") |
| blocks | 48 301–48 700 | 367 |
| session days | 48 701–49 000 | 164 |
| the agenda ahead at T0: consultations, plans, blocks, session days | 49 001–50 000 | 683 (593 consultations, 40 plans, 11 blocks, 39 session days) |

### The history on the agenda (D408, W3-g)

Each half-hour slot of the year before T0 (08:00–19:30 local, Monday to
Saturday) is read with `vc_agenda`: its placed scheduled consultations,
their section and vet. Each with a row in `core_consultation` is an
**attended booking**: id the consultation's (its `booking_id`), the slot's
start for 30 minutes, its vet, the section's consultation space of its
rank among the slot's placed ones of its section in id order (the rank is
`vc_slot_rank`'s `rk`: domestic rooms 1–4, horse 8, 9, 10, farm 12, 13),
`arrived` at the consultation's start, its animal the consultation's. Its
type a first referral when the consultation carries a referral, else by
a hash (follow-ups 45 %); booked 0 to 42 days ahead by the lead-time mix,
at reception's hours, never before its animal's registration. So the two
loads agree without reading each other: the coherence check
`attended-bookings` finds every scheduled consultation booked, by id,
with its animal, start and vet.

### The bookings around the agenda

Placed by the load in what the agenda leaves free, each at the first free
slot from its drawn time, the resources free of every allocation placed
before it (the agenda first, then the blocks, imaging, the inbound
examinations, the theatre plans, the sessions, the cancelled and no-show
bookings, the agenda ahead):

- **blocks**: each week to the end of the published rota, the MRI's
  quality assurance Wednesday 08:00–10:00, CT 7's service Tuesday and CT
  8's Thursday 07:00–08:00, the theatres' deep clean Friday 16:00–18:00
  (13 14:00–16:00), at the nearest free start that day; booked with the
  rota, held once past. Their note names the resource (`service: machine
  7`), which `sched.rota.publish` reads to stay idempotent;
- **imaging**: each request the core sent, on its code's machine for its
  section ([the procedure catalogue](../../../specs/versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373)),
  an urgent one at the first free slot from ten minutes after its request
  in the machine's hours, a routine one at the first free slot of the
  imaging day from an hour after it; arrived when started before T0,
  cancelled with its request;
- **inbound examinations**: the machine by reason and species (D413; a
  calf's MRI takes the 1.5 T's only type, domestic; any species'
  scintigraphy the gamma camera's, horse), on the accepted date's imaging
  day or the first free slot after; a second opinion or an endoscopy a
  first referral of the species' section with a vet and a space; no
  animal (the partner's patient is not registered);
- **theatre plans**: each weekday's (6 at today's rate, ramped from 60 %),
  the section by a hash (domestic 55, horse 35, farm 10), at the first
  half-hour start that day where a theatre, a surgeon, an anaesthetist and
  a nurse are free, else the next weekday's (five at most); planned two
  to ten days ahead by the section's first nurse; the farm's
  standing-surgery theatre avoids its consultations;
- **sessions**: 1–100 held through the year, 101–125 over the next three
  months; each a course by a hash on its days in a row, 09:00–16:00, its
  room, its lead instructor every day, its teaching animals from 10:00 to
  12:00 each day, the lowest ids free within their limits (so a three-day
  course changes animals on its third day); within six weeks of its target,
  else the next course in order (the arena is the horse section's third
  consultation space, taken on about half the weekdays);
- **cancelled and no-show consultation bookings**: 3 000 through the year
  (ramped), 30 % no-shows (allocations live), the others cancelled
  (owner, clinic, moved; `deceased` when the animal died first, the
  allocations released at the cancellation);
- **the agenda ahead**: for each of the next 42 days and each section, the
  day's demand (domestic 58.5 a weekday, 30 on Saturday; horse 14; farm
  5.5) times the share of lead times longer than the day's distance: the
  next days nearly full, thinning to nothing at six weeks; vets on planned
  or published shifts, never absent; patients alive at T0.

### The rota (D411)

`sched_shifts` holds every `core_shifts` row with no absence from the
history's first week (local Monday 52 weeks before T0's week) to the end
of the seventh week after the week of the last Friday 12:00 before T0.
Each week is published at the Friday 12:00 ten days before its Monday:
`published_at` set on the weeks to the end of the week after next from
that Friday, null (planned) on the later ones. Clocked in five minutes
either side of the start, out on time in four of five and up to an hour
late otherwise; an on-call shift clocked only on a call-out (one in four,
one to three hours from one to eight hours in); nothing at or after T0, so
the night's shifts are clocked in, not out. A `core_shifts` row with an
absence is part of a `sched_absences` period: a staff member's consecutive
absent shifts of one kind with no worked shift between them, from the
first one's local day to the day after the last one's; recorded one to six
weeks ahead (leave, training) or the morning it starts (absent), never
after T0, with no note.

**`sched.rota.publish`** (Friday 12:00, `jobs.yaml`): one statement that
inserts the seventh week after the current one by the pattern as planned
shifts (`ON CONFLICT (staff_id, starts_at) DO NOTHING`), removes the week
after next's planned shifts a live absence covers and publishes the
others (`published_at = now()` where null), and books the week after
next's seven blocks where their resource is free and no block with the
same start and note exists. A rerun changes nothing. At +2 moved to the
build's moment: 440 shifts planned, 392 published (six removed), seven
blocks; rerun, the same counts.

## The slot function

`sched_free_slots(type_id integer, after timestamptz, how_many integer
DEFAULT 1) RETURNS TABLE (starts_at, ends_at, staff_ids integer[],
room_id, machine_id)`, `LANGUAGE sql STABLE`, security invoker, `SET
search_path = public, pg_temp` (W3 item 2). For the type's resources (the
section's consultation spaces, the section's theatres, the course's room
kind, the type's machine), every start of the resource's hours from
`after` (local times in the settings' zone; the grid of the type's
duration from the opening, a surgery's on the half-hour, a session day at
09:00), ending by `now()` plus the horizon (42 days), with no live
allocation of the resource over it (the GiST index of its exclusion
constraint); per start, in time order, the staff the type takes who are on
a shift covering it (planned or published; an operator on call too), on
no absence over it, with no live allocation over it: the lowest id of each
role (a vet of the section; the operator; the surgeon, another vet of the
section as anaesthetist, anaesthesia first, a nurse; an instructor); for a
session day the course's number of teaching animals of its species free
from 10:00 to 12:00 within their limits (two sessions and four hours that
day, never a third day in a row). It returns no animal (the caller takes
the lowest ids free, the animals' exclusion constraint the guard) and no
slot for a block type. About 150 ms a call at T0 on the build's machine.

**The booking horizon** (W3 item 2, settled): the 42 days bind
`sched_free_slots` only, so reception's bookings (phone, desk, follow-up,
referral) and the purposes' imaging bookings. Session days, planned three
months ahead and opened eight weeks ahead, and theatre plans are inserted
by the load and their streams under the same exclusion constraints; a
search within 42 days sees them taken. The rota is planned to the end of
the seventh week ahead (D411), so a search 40 days ahead meets planned
shifts.

## The roles (vet-scheduling-domain.md, "Application roles and grants")

| Role | Reads | Writes |
|---|---|---|
| `sched` | owns the tables and the function; no login | |
| `sched_app` (pms) | every `sched_` table; executes `sched_free_slots` | bookings, allocations, absences, trainees, enrolments (insert, update); shifts (insert, delete, update of `published_at`, `clocked_in_at`, `clocked_out_at`); sessions' `state` |
| `sched_reports` (purpose 12, the standby) | every `sched_` table | nothing |
| `vet_reports` (the core's) | every `sched_` table, granted in a `DO` block where the role exists (D414) | nothing |

`EXECUTE` on `sched_free_slots` is revoked from `PUBLIC`. `sched_interfaces`
and its grants are purpose 11's (chunk 21).

## The classification

`customer-linked`: a booking's `animal_id`, an enrolment's `trainee_id`.
`personal`: an absence's `note`, a trainee's id, name, e-mail, phone and
referring vet, a certificate number. Everything else `internal`: staff ids
(the work record), an allocation's `animal_id` (teaching animals, owner 1),
a booking's `notes` (free text that may name an owner: T24).

## The producers

On `pms` beside the core's (D276), connection `sched` (`records:5432/clinic`,
`sched_app`, pool 3), the core's shapes named and `reception` its own
(weekdays 08:00–19:00, Saturday 08:00–12:00):

| Key | Rate, shape | What |
|---|---|---|
| `sched.bookings.make` | 8.4/h poisson `reception` | a consultation booking at the first slot `sched_free_slots` gives from a drawn day and hour: section 75/18/7, lead 30/50/20; the booking and its two allocations in one statement |
| `sched.bookings.cancel` | 0.85/h `reception` | a future booking cancelled (owner, clinic); the trigger frees the slot |
| `sched.surgery.plan` | 0.6/h `office` | a theatre plan two to ten days ahead by the slot function |
| `sched.trainees.enrol`, `sched.enrolments.cancel` | 0.38/h, 0.04/h `office` | an enrolment (a new trainee in three of four; waitlisted when full), a cancellation (the first waitlisted enrolled) |
| `sched.absences.record` | 0.04/h `office` | an absence, leave nine in ten |
| `sched.bookings.arrive` | 40/h `flat` | the oldest booking starting within ten minutes: arrived; one in twenty left for the no-show |
| `sched.bookings.no-show` | 10/h `flat` | a booking 30 minutes past its start: no-show; a past block: held |
| `sched.bookings.move` | 4/h `office` | a future booking whose vet is absent: moved (cancelled `moved`, rebooked, source desk) |
| `sched.shifts.clock` | 30/h `flat` | a clock-in and a clock-out (on-call on a call-out only) |
| `sched.sessions.attend`, `.close`, `.open` | 20/h, 2/h, 2/h `office` | a session day's attendance, a session's close and certificates, a session opened eight weeks ahead or running |
| `sched.slots.find`, `sched.agenda.day`, `sched.theatre.board`, `sched.rota.week` | 12/h `reception` (concurrency 2), 30/h `clinic-day`, 6/h `flat`, 2/h `office` | the reads |
| `sched.rota.publish` | `0 12 * * 5` (`jobs.yaml`) | above |

**The booking stream's patients.** The live streams cannot call the core's
functions, so a booking or a theatre plan takes one of the section's
animals **registered during the year** (domestic 9 738–14 600, horse
15 537–16 000, farm 16 668–17 000: the core's pools after their
pre-history patients), the first of six drawn that the core's at-home
death draw spares (`(hashint8extended(id, 36) & 2³¹−1) / 2³¹ ≥ 0.026`,
the core's `u₃₆`). Those animals never have a stay, so never die in
hospital: no live booking names an animal the history killed. An animal
that dies during the game is purpose 11's (`cancel-deceased`).

## The rules

[`docs/policy.md`](policy.md): one place at a time; bookings follow the
rota and the hours; working time (2003/88/EC, *CCOO*); absences without a
reason; least data in a booking; cancellations and no-shows; teaching
animals' limits; certificates at 80 %; trainees' retention; retention.

## Growth

About 330 new rows and 200 updates a day at intensity 1.0, 0.12 MB with
the GiST indexes; Friday noon about 440 shifts at once. Nothing ships to
cold storage.

## The traps

The domain document's T100 to T128 ("Traps"), with the core's that bite
here (T5, T7, T9, T14, T24, T31–T37, T73, T74, T82). Where each lands in
this build: T100 the function's staff test and
`sched_allocations_staff_excl` (the witness reads scheduled consultations
and live staff allocations: none overlap at load); T101 the generated
`during` (`'[)'`); T102 the trigger `sched_release` and its `WHEN`; T103
the function's `during &&` tests and its horizon bound; T104 its `AT TIME
ZONE` on `sched_hours`; T105, T106 its absence and shift tests; T107 its
teaching-animal limits; T108 `sched_shifts_staff_start_key` and the job's
`ON CONFLICT`; T110 the enrolment's session lock (`FOR UPDATE OF se`);
T111 the close's 80 % test; T120 the absences' empty notes; T126
`sched_bookings_request_idx`; T128 the job, one statement, movable to
`pg_cron`. No trap is planted by the domain.

## Known limits (as built)

- **Domestic theatre plans are few**: the core's agenda keeps the two
  domestic surgeons (19, 22) consulting most of the day, so about 240 a
  year find a surgeon, an anaesthetist and a nurse free together (horse
  about 450, farm about 115): about 800 plans (807 at +2, 850 at shift 0)
  against the document's 1 250. The live stream finds its slot further out the same way.
- **An urgent MRI or scintigraphy at night** is booked at the next
  imaging day (the two MRIs and the gamma camera are not around the
  clock); every other urgent study is booked the same day.
- **Shift ids**: the pattern gives about 404 shifts a week; from a T0
  between Friday noon and Sunday the planned rota holds 60 weeks and the
  ids reach about 24 230, past D411's 24 000. The sequence resumes after
  the larger of the range and the ids, so no live shift collides.
- **Future absences** of kind `absent` (the core's draw, which knows no
  future) are recorded before T0 like leave; a GM may read them as
  pre-booked sick leave.
- **Imaging bookings and results**: a routine study booked on the next
  imaging day can start after the core's `resulted_at` (the core's
  turnaround is drawn without the agenda); the coherence checks read the
  booking, not its order against the result.

## Loading

`gmctl load-data` runs `schema.sql` then `load.sql` into `clinic` as
`postgres`, after the core's, the core's `keys.sql` streamed ahead of the
load in its session, then the coherence check. The four exclusion
constraints exist before the load, and its last insert of the allocations
is checked by them. The load fails on any of its own checks (an attended
consultation without its booking or vet, a staff allocation off shift or
absent, a room or machine allocation outside its hours, an id outside its
range, a state that does not fit T0, a dead animal booked ahead, a
cancelled booking's allocation live).

| Load | Time (after the core's) | Rows | Size |
|---|---|---|---|
| +2, T0 2026-11-04 07:50Z (09:50 local, Wednesday) | 99 s (core 121 s) | 103 500 | 20 MB |
| 0, T0 2026-03-18 15:37Z (Wednesday) | 92 s (core 115 s) | 103 538 (16 698 attended, the core's own figure) | 20 MB |
