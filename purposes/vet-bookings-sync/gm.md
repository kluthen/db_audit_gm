# vet-bookings-sync — GM notes

Purpose 11 of v0.5 (master spec 12.2; v0.5's `vet-scheduling-domain.md`,
"11. `vet-bookings-sync`"; capture W4 items 0 and 6): the hospital's agenda
(`vet-scheduling`) and its medical record (`vet-core`) kept in step by the
centre's integration engine, as a human hospital's scheduling messages
keep its record. **Transformed in place**: the part lands in the core's
database (`clinic`), so every flow runs in one database, with two roles.

## What it is for

The core as built has no stream opening scheduled consultations (D317): a
consultation booking's arrival is the only way one opens. Imaging requests
the vets write at a consultation's close need a slot on their machine;
the other centres' examinations the vets accept need one on their date; a
dead animal's follow-ups must leave the agenda.

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `check-in` | `* * * * *` | script `scripts/bookings_sync.py:check_in`, `clinic` as `vet_interfaces`, `sched` as `sched_interfaces` | the consultation bookings `arrived` since its watermark (less ten minutes) with no consultation carrying their id: each opened in the core (`scheduled`, site 1, the booking's section, its allocated vet, started at the arrival, `booking_id`), its `ops.booking_consultations` row, the run's `ops.runs` row and the watermark in one `clinic` transaction |
| `book-requests` | `* * * * *` | `:book_requests`, the same two connections | the imaging requests recorded since its watermark, not cancelled, with no live booking: each on its study's machine by `sched_free_slots` (urgent: the machine's first free slot from now, D424; routine: the first free slot of the imaging day, Monday to Friday 08:00–18:00, from an hour after now, D376); the inbound examinations accepted since then: booking `28 000 + exchange id` (D422) on the machine the reason and the partner patient's species name (D413), at the first free slot of the imaging day from the accepted date's opening; another day, or no slot, one `ops.incidents` row (`examination-moved`, `examination-unbooked`, ref the exchange id). One agenda transaction, each booking in a savepoint (a slot taken meanwhile, `23P01`, retried once) |
| `cancel-deceased` | `* * * * *` | `:cancel_deceased` | the animals recorded `died` since its watermark: their future bookings still `booked` cancelled (`deceased`), the trigger `sched_release` freeing their resources |

Every run writes one `ops.runs` row in its output's transaction (rows read,
rows written), `check-in`'s on `clinic` (as `vet_interfaces`), the two
others' on the agenda's connection (as `sched_interfaces`), the same
database. Watermarks (`check-in`, `requests`, `examinations`, `deaths`)
start at `load_epoch`: the two loads agree at T0 (the coherence check
`attended-bookings`), every request and examination before it booked by
vet-scheduling's load.

**Choices made at the build** (W4-e): the study codes' machines are a copy
in the script of vet-scheduling's `load.sql` mapping (`s_code`), so the
engine reads no `pacs`; a request's section is its consultation's; an
inbound examination's species is read from `exchanges.partner_patient`
(`partner record <site>/<n>: <species>, <age>`, as the core's load and the
centres' stub write it); a booked consultation's site is the option `site`
(1, the hospital), so `vet_interfaces` needs no grant on `sites`; the
imaging day is read at the agenda's `sched_settings.utc_offset`, as the
load places it; a booking without an animal (an inbound second opinion)
opens no consultation. `sched_interfaces` also reads `sched_courses` and
`sched_rooms`: `sched_free_slots` runs with the caller's rights and joins
them.

## What the material holds

Written for the clinic's names; adapt them when copying.

| File | Goes to | Names to adapt |
|---|---|---|
| `material/runner/queries.yaml`, `jobs.yaml`, `schedule.yaml`, `scripts/bookings_sync.py` | the runner's (`interfaces`) scenario layer `compose/interfaces/`, merged by `gmctl compose` | the targets `records:5432/clinic` (both connections); the option `site` |
| `material/target/ddl.sql` | nowhere: `ddl.target`, read from the catalogue by `load-data` at step (2b) | none (`:"DBNAME"`) |
| `checks/*.sh` | the sealed checks of the faults attached to the purpose | the constants at the top of each (`DB`) |

The DDL creates (guarded) `ops`, its three shared tables and
`ops.booking_consultations`, the roles `vet_interfaces` (shared with
purposes 1, 4, 5 and 13) and `sched_interfaces`, `CONNECT` by name, and
grants: `vet_interfaces` `INSERT` on `consultations`' open columns only
(`animal_id`, `site_id`, `section_id`, `vet_id`, `kind`, `booking_id`,
`started_at`), `SELECT (id, booking_id, section_id)` on `consultations`,
`SELECT (id, status, died_at)` on `animals`, `SELECT` on `requests` and
`exchanges`; `sched_interfaces` `SELECT` on the agenda's tables the slot
function reads, `EXECUTE` on `sched_free_slots`, `INSERT` on bookings and
allocations, `UPDATE` of bookings' state and links and of allocations'
`released_at`; both the `ops` grants of W4 item 0.

The scenario must give `records`' `pg_hba.conf` admitting
`vet_interfaces` and `sched_interfaces` from `interfaces`, and `gm_check`
from the game network (every fixture's `host all all` line does).

## How it goes wrong

The candidate faults are the domain's T112 to T119 (vet-scheduling-domain.md,
"Traps", 2): T112 the engine granted `INSERT` on all of `consultations`
(the grants; no check, the governance read); T113 the priority dropped
(BS3); T114 a retry booking a request twice (BS3, the live-booking test
gone, `sched_bookings_request_idx` dropped by T126 makes it slow); T115
the check-in's watermark taken from the run's start with no overlap
(BS1); T116 the core's unique index on `booking_id` dropped and the job's
existence test removed (BS2); T117 bookings taken by start time, not
arrival (BS2); T118 `cancel-deceased` missing or its watermark rounded to
the day (BS4); T119 an examination moved without an incident (BS5). A
scenario's faults are the GM's to select.

## The checks

Each runs on `interfaces` as root (`gmctl check`), reads `clinic` as
`gm_check` (`check-sql`) and the runs' moment (`check-runs`); exit 0
fixed, 1 present, 2 cannot judge, 3 too soon.

| Check | Invariant | Judged | Witness |
|---|---|---|---|
| `bs1-arrival-consultation.sh` | each arrival's consultation within 2 minutes (the ledger's time) | triggers | an arrival since the judged moment, about 60 a day |
| `bs2-one-consultation.sh` | no booking with two consultations; none on a booking not `arrived` | runs | a consultation opened by `check-in` |
| `bs3-requests-booked.sh` | one live booking on the study's machine within 2 minutes; urgent at the first free slot (rebuilt at the booking's time from the machine's hours, its live allocations then and an operator on shift), routine within two working days | triggers | an imaging request, about 11 a day |
| `bs4-no-booking-after-death.sh` | a dead animal's future bookings cancelled within 2 minutes | triggers | a death with a future booking, about one every three days |
| `bs5-examinations-booked.sh` | each accepted examination booked on its date within 2 minutes, or an incident | triggers | rare: under one a day |

BS1 cannot date a consultation opened outside the job (no ledger row): it
counts it in time. BS3's first free slot ignores a slot freed after the
booking (a cancellation) since it reads allocations live at the booking's
time; a slot the function refuses for a staff reason it does not rebuild
(a vet's section, a session's animals) cannot arise on a machine.
