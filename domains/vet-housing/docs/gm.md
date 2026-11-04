# The vet-housing domain: GM notes

The wards of the centre of Aldermoor Veterinary Hospitals (v0.5 master
spec 9.5; [vet-housing-domain.md](../../../specs/versions/v0.5/vet-housing-domain.md);
capture W3 item 3): the 64 boxes, stalls, pens, kennels and cages, which
of the core's hospital stays is placed in which, each stay's feeding plans
and care log, and the display on each unit with the ward service behind
it (D287). A design-time source, a **part** of `vet-core`: it is taken
only with the core (`requires: [vet-core]`), refers to the core's keys by
id with no foreign key, prefixes its tables and roles `housing_`, and
**lands in the core's database** (`lands_with: vet-core`, D318, D322):
the loader refuses a scenario whose `at:` puts it anywhere but beside the
core, because each board read is one statement joining a unit to the
core's `animal_board`.

| File | Copied to | What |
|---|---|---|
| [`data/schema.sql`](../data/schema.sql) | loaded by `gmctl load-data` into the core's `at:` database (`clinic` on `records`), after the core's load | roles, five tables, the unit board, indexes, grants on its tables and the core's columns |
| [`data/load.sql`](../data/load.sql) | after `schema.sql`, the core's `data/keys.sql` streamed ahead of it | last night's backup: a year of placements, plans and care log, on the core's stays computed by its functions |
| [`data/coherence.yaml`](../data/coherence.yaml) | run by `load-data` after the loads | placements on real stays, every current stay placed once, no unit holding two |
| [`data/classification.yaml`](../data/classification.yaml) | where `governance.classification` names it | the class of every column |
| [`data/register.yaml`](../data/register.yaml) | the scenario's data register (chunks 17, 27) | two processing activities, every table in one |
| [`data/governance.yaml`](../data/governance.yaml), [`policy.md`](policy.md) | merged into the scenario's `governance:` and `player/data-policy.md` beside the core's | the wards' eight rules, and who may read the board's `animal_id` |
| [`producers/pms/`](../producers/pms/) | the practice software's node (`nodes/pms/`), beside the core's fragment | the connection `housing`, six streams |
| [`producers/ward/`](../producers/ward/) | the ward service's node (`nodes/ward/`) | two connections, five streams, three shapes |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | read by compose | the part's axes in the core's one variant |

## The business

The centre's hospital wards, one per section: the horse barn's boxes (two
isolation, two padded intensive-care boxes), the farm barn's stalls for
cattle and pens for sheep and goats (one isolation pen), the domestic
wards' kennels and cages (an isolation kennel, an isolation cage, a room
of intensive-care cages). About 40 animals in hospital at any time (14
horses, 6 farm animals, 20 domestic), about 8 admitted and 8 discharged a
day. A unit holds one animal. A nurse places the animal at admission in
the practice software and moves it when its care changes (out of
intensive care, into isolation); the carers and grooms feed, water,
clean, walk and check it, recording each action on the unit's display; an
emptied unit is disinfected before the next animal. The display shows the
animal placed there, read from its file through the ward service, and
records the carers' actions: the actions, never the displays' accesses
(D298).

## Core keys used

Housing's load never reads the core's tables (D249, D322): it computes
what it needs by the core's documented functions, with the run's
`load_epoch` and `customer_utc_offset`, from vet-core's
[`data/keys.sql`](../../vet-core/data/keys.sql) streamed ahead of it
(vet-core `docs/gm.md`, "Core keys"). It calls four of the eighteen, and
none of the `vc_*` helpers:

| Function | For |
|---|---|
| `core_stay(n, load_epoch, utc_offset)`, `n` 1–2 500 | each stay's animal, section, admission, end and outcome: the placements follow the stays the core's load wrote (2 421 at the reference T0, 38 current; at most 17, 9 and 23 at once in the three sections) |
| `core_species(animal_id)` | the unit that fits it |
| `core_stay_alert(n, load_epoch, utc_offset)` | the infectious alert, so the animal goes to isolation (one stay in ten) |
| `core_staff(n)`, `n` 1–85 | the nurses by section (29–51, not the technicians) who place and set plans, the carers by section (57–60 horse, 61–62 farm, 63–66 domestic, D324, D394) who record the care |

Sections 1 horse, 2 farm, 3 domestic are the core's ids. The composition
record lists these keys (`composition.yaml`'s `keys.vet-housing`). While
the game runs, housing's roles read the core's columns in place, by the
column grants its schema gives ("The roles"); nothing is copied.

Housing ships no `data/keys.sql` (capture W3 item 0): no part computes
housing's ids. Its own draws in `load.sql` are `pg_temp.housing_u(x,
salt)`, the same hash formula as the core's, with salts 1401 and up.

## The units

| Ids | Section | Kind | Code |
|---|---|---|---|
| 1–2 | horse | isolation boxes | H-01, H-02 |
| 3–4 | horse | intensive-care boxes | H-03, H-04 |
| 5–22 | horse | boxes (15 out of service) | H-05 … H-22 |
| 23 | farm | isolation pen | F-01 |
| 24–28 | farm | stalls | F-02 … F-06 |
| 29–32 | farm | pens | F-07 … F-10 |
| 33 | domestic | isolation kennel | D-01 |
| 34 | domestic | isolation cage | D-02 |
| 35–40 | domestic | intensive-care cages | D-03 … D-08 |
| 41–54 | domestic | kennels (50 out of service) | D-09 … D-22 |
| 55–64 | domestic | cages | D-23 … D-32 |

**Fit**: a box a horse, a stall cattle, a pen sheep or goats, a kennel a
dog, a cage a cat, a rabbit or a ferret; an isolation or an
intensive-care unit any species of its section. **Choice**, in the load
and in `housing.place` alike: an isolation unit first for an animal with a
current infectious alert; otherwise an ordinary unit (neither isolation
nor intensive care), then an intensive-care one, then, a section full to
its last fitting unit, an isolation one; the lowest id within each. (A
"lowest id" read literally would put every new horse into the isolation
boxes, which the rules keep for infectious animals, false alarm 4.) Units
15 and 50 are out of service since a week before T0 (under repair, at
load only in v0.5).

**Displays**: display `u` on unit `u`, installed 400 days before T0;
displays 65 and 66 replaced those of units 7 and 41 182 days before T0
(7 and 41 have `removed_on`), so unit → display always goes through
`housing_displays` (its open row, `removed_on IS NULL`). Serials
`WD7-` and five digits, `(7 919 id + 1 301) mod 100 000`.

## The data

At the reference T0 (`load_epoch` 2026-11-04 10:00Z, offset +2, 12:00
local), counted with `count(*)`:

| Table | Rows | Notes |
|---|---|---|
| `housing_units` | 64 | 62 in service; at this T0 2 `to-clean` (released in the last hour), 2 `out-of-service`, the rest `clean` |
| `housing_displays` | 66 | 64 in place |
| `housing_placements` | 3 032 | 2 421 admissions (every stay of the year), 244 into isolation, 367 moves (out of intensive care, out of isolation once the alert ended); 43 open at T0 |
| `housing_feeding_plans` | 2 795 | 2 421 diets, 374 nil-by-mouth orders |
| `housing_care_events` | 132 795 | 60 822 checks, 28 368 feedings (85 % all, 12 % part, 3 % none), 40 744 other actions, 2 992 disinfections |
| **Total** | **138 752** | 17 MB on disk with indexes |

The care log follows the stays' ramp (60 % of today's volume a year ago),
so the year's mean is below the 520 a day of 40 animals: about 13 events
an animal a day (six checks, two or three feedings, four other actions).

**The history** (`load.sql`, "Placements: the wards, event by event"): the
year's stays in time order, each placed ten minutes after its admission
(at T0 at the latest) in the unit "The units" gives; one stay in nine of
the horse and domestic stays with no alert goes to intensive care first
and moves out after one or two days; a stay with an alert moves into
isolation when it starts, or, none free, at the first isolation unit
disinfected while the alert lasts, and back to an ordinary unit when the
alert ends, freeing isolation for the next (without it the farm's sixth
head of cattle found no unit at two moments of the year: five stalls and
an isolation pen still held by a recovered sheep). Released at the stay's
end, the unit disinfected 30 to 90 minutes later; the next animal only
after. 454 stays moved, 157 of them twice (into isolation and out). Of
249 infectious stays, 244 reached isolation, 47 after a wait (the
isolation units full: at most four infectious horses, three farm animals
and six domestic animals at once, against two, one and two units), up to
three days on the farm; 5 never did; 2 non-infectious admissions overflowed
into an isolation unit. Diets from the species' short list at its meals
a day (horses 4, cattle, sheep, goats and dogs 2, cats and small animals
3); one stay in six a nil-by-mouth order before a 09:00 anaesthetic the
first morning at least 18 hours after admission, twelve hours long for a
horse or a ruminant, eight for the others. The care log day by day: a
check at 02, 06, 10, 14, 18 and 22 (within 25 minutes), each species'
round after its placement (5 to 45 minutes after the hour; none while
nil by mouth), four other actions in the care day, each emptied unit's
disinfection; times by hashes, the carer by a hash of the placement and
the day (a carer of the unit's section, not matched against the rota,
D394).

**In flight at T0**, as the night leaves the wards or the morning's
discharges begin: every current stay placed once, its diet in force, a
few nil-by-mouth orders running; the night's checks recorded, the next
round due; units released in the last 90 minutes `to-clean`.

## The board

`housing_unit_board`, a view owned by `housing`, one row per unit, is what
a display shows: `unit_id`, `code`, `section_id`, `kind`, `isolation`,
`intensive`, `state`; the open placement (`placement_id`, `placed_at`);
the stay (`stay_id`, `admitted_at`, `reason`); from the core's
`animal_board` the animal (`animal_id`, `name`, `species`, `breed`,
`sex`), its `alerts` and the day's doses (`doses_today`,
`doses_given_today`, `next_dose_at`), and its `age_years` (from
`animals.born_on`); the plan in force (`plan_kind`, `diet`,
`meals_a_day`, `plan_until_at`), a nil-by-mouth order overriding the
diet; the day's feedings at this unit (`feedings_today`, `last_fed_at`,
`last_eaten`), `meals_due` (the species' rounds passed today since it was
placed there, at most its meals a day; 0 while nil by mouth) and
`last_check_at` (during this placement). "Today" is the customer's
(`business_settings`). An empty unit's row carries the unit only. No
owner, contact, natural identifier or note (rule 1). Its join, unit →
open placement → stay → animal, is D287's chain. One unit's row costs
about a millisecond (the indexes on the open placement and on the care
log by unit and time).

## The roles (vet-housing-domain.md, "Application roles and grants")

| Role | Reads | Writes |
|---|---|---|
| `housing` | owns the tables and the board; no login; for the board, the core's `animal_board` and `business_settings`, `stays`' `id`, `animal_id`, `reason` and `animals`' `id`, `born_on` | |
| `housing_app` (pms) | every housing table and the board; `stays`' `id`, `animal_id`, `section_id`, `admitted_at`, `discharged_at`, `outcome`; `animals`' `id`, `species`; `alerts`' `animal_id`, `kind`, `from_at`, `until_at`; `staff`' `id`, `kind` | `housing_placements`, `housing_feeding_plans`; `housing_units`' `state` and `state_since_at` only |
| `housing_ward` (ward) | the units, placements, plans, care log and the board; `staff`' `id`, `kind` | `housing_care_events`, insert only (with `USAGE` on its sequence: a feeding's `eaten` is a hash of its id); `housing_units`' `state` and `state_since_at` only |
| `vet_display` (the core's) | `housing_unit_board` (beside the core's `animal_board`) | nothing |
| `vet_reports` (the core's) | every housing table and the board | nothing |

The login roles carry no password here: `load-data` sets each from its
secret (`housing_app` named by `pms`' schedule, `housing_ward` and
`vet_display` by `ward`'s). `CONNECT` on `clinic` by name. A display
cannot move an animal or touch the record.

## The classification

[`data/classification.yaml`](../data/classification.yaml) lists all 68
columns of the five tables and the board: `housing_unit_board.animal_id`
`customer-linked` (the core's reading of `animal_board.animal_id`), every
other `internal`: a unit, a display, a stay id, a staff id are the
clinic's work record. Housing holds no personal data. The notes of plans
and care events are `internal` and may name an owner (T169); the board
shows none. Every table is in one of
[`data/register.yaml`](../data/register.yaml)'s two activities (the
wards' units and displays; placements, plans and the care log).

## The producers

**`pms`**, the practice software ([`producers/pms/`](../producers/pms/)),
connection `housing` (`records:5432/clinic`, `housing_app`, a pool of
two) beside the core's `clinic`; the shapes are the core's (`flat`,
`clinic-day`), named, never written:

| Key | Kind | Rate at 1.0 | What one call does |
|---|---|---|---|
| `housing.place` | work | 6/h, even, `flat` | the oldest current stay with no open placement, admitted five minutes ago or more, placed as "The units" says, with its diet |
| `housing.release` | work | 6/h, even, `flat` | the longest-ended stay still placed (`outcome` discharged, transferred or died): its placement ended at the stay's end, its unit `to-clean`, its plans ended |
| `housing.move` | volume | 0.08/h, poisson, `flat` | an infectious animal into isolation first, then one a day or more in intensive care out to an ordinary unit, else a box change; one transaction, the old placement ended and the new opened at one instant, the old unit `to-clean` |
| `housing.fast` | volume | 0.28/h, poisson, `clinic-day` | a nil-by-mouth order for a placed stay with none in force, from the next hour, twelve hours (horses, ruminants) or eight |
| `housing.ward-view` | read | 12/h, even, `flat` | a section's rows of the board |
| `housing.stay-log` | read | 10/h, poisson, `clinic-day` | one current stay's placements and its care log there |

**`ward`**, the ward service ([`producers/ward/`](../producers/ward/)), a
`scheduler` node of its own in the players' scope (D287), so its sessions
show `ward` as `application_name`, apart from `pms`. Connections
`ward-board` (`vet_display`, a pool of four) and `ward-care`
(`housing_ward`, a pool of two): some sixty displays in six sessions,
against `max_connections`' 100.

| Key | Kind | Rate at 1.0 | What one call does |
|---|---|---|---|
| `ward.board` | read | 3 840/h, even, `flat`, concurrency 4 | one display's refresh: `SELECT * FROM housing_unit_board WHERE unit_id = %(unit)s`, `unit` `{int: [1, 64]}`; no row written (D298); about 92 000 a day |
| `ward.feed` | work | 60/h, even, `feeding-rounds` | the lowest occupied unit whose board shows a diet and fewer feedings today than meals due: a feeding, `eaten` by a hash of its id |
| `ward.check` | volume | 10/h, poisson, `flat` | a check on an open placement picked by an offset |
| `ward.care` | volume | 10/h, poisson, `care-day` | water 25, mucking out 25, bedding 12, a walk 30 (a dog's or a horse's; water otherwise), grooming 8 (a weighted `choice`) |
| `ward.disinfect` | work | 4/h, even, `care-day` | the unit `to-clean` longest, for 30 minutes or more: a disinfection with no stay, the unit `clean` |

Shapes, scenario time: `feeding-rounds` 1.0 in the hour after each round
(06, 07, 08, 12, 13, 16, 17, 18, 21), 0 otherwise; `care-day` 1.0 06:00–22:00;
`flat` copied unchanged from the core's. **One intensity a node**: at
another intensity the displays refresh faster or slower (D32): at 0.5 the
board is read 32 times a minute, which a GM tuning the ward's intensity
says in the story or leaves alone. The fragments are written for the
nodes `pms`, `ward` and `records` and the database `clinic`; rename them
as the scenario does. Every statement was run as its role on a load
(chunk 14's SQL checks).

## The occupancy measure

Purpose 9's feeder (`vet-head-office-figures`, chunk 20; capture W3 item
3) reads, on the standby as `vet_reports`, per section at each local
midnight `t`: the units in service (`housing_units` with `state <>
'out-of-service'`) and the units occupied (distinct `unit_id` of
`housing_placements` with `from_at <= t AND (until_at IS NULL OR until_at
> t)`). `state` keeps no history (out of service at load only), so its
present value stands for every midnight; counting out-of-service units as
available is T171. For the days `from` to `to`:

```sql
WITH m AS (
  SELECT d::date AS day, d::timestamp AT TIME ZONE b.timezone AS t
    FROM business_settings AS b, generate_series(:'from'::date, :'to'::date, interval '1 day') AS d)
SELECT m.day, s.section_id,
       (SELECT count(*) FROM housing_units AS u
         WHERE u.section_id = s.section_id AND u.state <> 'out-of-service') AS units_in_service,
       (SELECT count(DISTINCT p.unit_id) FROM housing_placements AS p
          JOIN housing_units AS u ON u.id = p.unit_id
         WHERE u.section_id = s.section_id AND p.from_at <= m.t
           AND (p.until_at IS NULL OR p.until_at > m.t)) AS units_occupied
  FROM m CROSS JOIN (VALUES (1), (2), (3)) AS s (section_id)
 ORDER BY m.day, s.section_id;
```

At the reference T0, the last midnight finds 21, 10 and 31 units in
service and about 40 occupied (HO1's witness).

## D287 applied: finding a faulty display

The players' way from a complaint, or a hot statement, to the display
(T150, test-selection fault s9, class M):

1. **The querier.** On `records`, `pg_stat_activity` and
   `pg_stat_statements` show the board statement run by `vet_display`
   from `ward` (its sessions' `application_name`), never from `pms`.
2. **The redundant query.** 64 displays at one read a minute make about
   3 840 calls an hour; a display refreshing in a loop adds its own, the
   same statement with the same parameter. `ward.board`'s statement is
   fixed byte for byte, so every display's calls, the faulty one's
   included, are one `queryid`: its calls per minute against the units
   show the excess.
3. **The box.** `pg_stat_statements` normalises the parameter and the
   driver binds it server-side (psycopg 3), so `pg_stat_activity` shows
   `$1`; logging the statement with its parameters shows it
   (`log_min_duration_statement = 0` for `vet_display` alone, `ALTER
   ROLE`, the ward's pooled sessions terminated so the pool reconnects
   with it). A setting for the whole instance would log the practice
   software's statements too, owners' names and phones among them: the
   harm of T1 (core rule 10), which a careful player avoids (T170).
4. **The chain.** The unit → its display (`housing_displays`, the row with
   no `removed_on`: units 7 and 41 have had two) → its open placement →
   the stay → the animal: the box's code, the display's serial and the
   animal named in the report.

**The faulty display's key** (s9, chunk 25; capture W3 item 3): a stream
in the scenario's or fixture's `compose/ward/` layer, its key the fault's,
whose `sql` is `ward.board`'s byte for byte with `unit` fixed (`{int: [u,
u]}`), on `ward-board`, at a rate well above one a minute; "cleared"
removes it from that layer. A display's firmware is no layer of the
players': T150 is reported, never fixed, judged at the final answer on
the report alone (the unit, its display's serial and the animal named,
the excess shown, no instance-wide logging left behind). The GM never
switches the display off during play; the feedback says the technician
would replace it.

## The rules

The wards' eight rules ([`policy.md`](policy.md), D318): the board's least
data; biosecurity (infectious animals in isolation, every emptied unit
disinfected, Regulation (EU) 2016/429 Art 10); nil by mouth on the board,
no feeding while in force; checks every four hours and feeding at the
rounds (Directive 98/58/EC's floor); one fact, one place (no dose in the
care log, a placement names a stay); actions, not accesses (no read
logged, D298); least grants; retention five years with the stay.

## Growth

At intensity 1.0, on `clinic`: about 540 new rows a day, 520 of them care
events, and about 30 updates (placements ended, units' state), about
0.1 MB with indexes; about 22 rows an hour on average, about 45 in the
busiest hour (17:00–18:00, the horses', dogs' and, from 18:00, cats'
meals). The displays' reads, about 92 000 a day, leave no row:
`pg_stat_statements`' calls only. Over an aging the disk is never
housing's problem; its reads are, about one a second, every one through
the board. Nothing ships to cold storage (D296, D297).

## The traps

[vet-housing-domain.md](../../../specs/versions/v0.5/vet-housing-domain.md#traps-step-8)
lists T150–T171 with their witnesses (the ward service and the displays
T150–T156, the chain box → stay → animal T157–T161, care and biosecurity
T162–T166, governance T167–T171) and four false alarms; the core's T14 (a
sequence left below its range: here the first placement after T0
failing) and T25 (a natural identifier on `animal_board`, so on every
display) bite housing too. What the data holds on purpose and a player
may take for a fault: the board statement every second from `ward` (the
64 displays); an animal nil by mouth with no feeding since last night;
an empty isolation box while a horse waits (isolation is kept for
infectious animals, but takes one when its section is full); an
infectious animal waiting in an ordinary unit for an isolation unit to be
disinfected (the history's, at most a few at once; T163's baseline, so a
T163 instance is told by its rate and its story, not by one such
placement); a carer recorded on a day off (not matched against the rota,
D394). Selecting a game's faults is the GM's.

## Loading

`gmctl load-data` runs `schema.sql` into `clinic` on `records` as
`postgres`, after the core's schema and load (the same database), then
vet-core's `keys.sql` and `load.sql` in one session, with
`customer_utc_offset` and `load_epoch` set; the load stops at once when
one is missing or the key functions are absent. Every time follows the
core's shifted stays; the shift needs nothing of housing's own. Explicit
ids for the units and displays, the history's ids in time order, each
sequence set after its range. The load's sessions are unseen (D265). It
checks before it ends, and fails when one does not hold: every stay
current at T0 has one open placement, none is open on an ended stay, no
unit holds two, every stay of the year was placed, each placement inside
its stay, each care event inside its stay's placement at its unit, no
feeding inside a nil-by-mouth order, every occupied unit clean; and a
stay finding no fitting unit free fails the build. The GM's post-load
coherence check ([`data/coherence.yaml`](../data/coherence.yaml)) then
reads every placement on a real stay, every current stay placed once and
no unit holding two (D322).

Measured on `postgres` 0.5.0 in a throwaway container (chunk 14): **7.4
s** at offset +2 (T0 2026-11-04 10:00Z), **7.6 s** at offset 0 (T0
2026-03-18 15:37Z), 138 752 and 138 863 rows, **17 MB**, after the core's
92 to 96 s. The fixture `tools/tests/fixtures/fixture-housing/` loads both
through `load-data` on Swarm, the coherence check included, in 102 to 122
s (armenelos, 2026-11-04), and proves the part in two runs of its short
test, `place` (T0 10:00 local) and `care` (T0 just before 17:00), 19 and 22
minutes each with the deployment.
