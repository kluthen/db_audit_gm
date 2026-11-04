# v0.5 — `vet-housing`, the clinic's boxes, stalls and displays

Status: draft v3, ruled, its stale passages corrected to the master
spec at approval (R16, D339). **Approved by the owner on 2026-11-03 with
v0.5's [master spec](master-spec.md)** (procedure step 9, D339), which
wins where the two disagree. Amended in wave 2 of the build
(2026-11-04): the carers by section, a care event's carer not matched
against the rota (D394). Amended in wave 3 (2026-11-04) to the build's
measures (D417): the owner role's and the ward's grants as built, an
animal moved out of isolation when its alert ends (and the waits for
isolation that follow), about 0.14 million rows and 17 MB, the short
test's limits.
Steps 1 to 9 drafted in one pass on 2026-11-03 at the owner's instruction
("start an agent for each part, and let them come back with problems
once they're done"); the same day the owner accepted the recommendations
as a whole (D318, closing O180–O190), marked "(ruled, D318)" below, with
one change: housing's tables stay in `clinic`, declared by `lands_with:
vet-core`, but its load computes the core's stays by the core's
documented functions instead of reading them (D249 kept, D322). The
faulty display (T150) is in the test selection, judged on the report
(D325). Step 3 is not a part's: the boundary is the confirmed split's
(D279). The traps (step 8) need no owner (D309). The changes this part
asked of the shared pages are applied ([Changes needed in shared
pages](#changes-needed-in-shared-pages)). The format, with the
composition rules (D322, procedure 10), finalised in
[formats.md](../../formats.md) v28 at consolidation (D338).

`vet-housing` holds the centre's boxes, stalls, pens, kennels and cages,
which animal of the core's hospital stays is placed in which, the care
and feeding each animal gets there, and the display on each unit: the
ward service the displays talk to (D287). It is a **part**: it requires
`vet-core` (procedure 4), refers to the core's keys by id with no
foreign key, and prefixes its tables and roles `housing_`. The clinic's
brief is the owner's, quoted in the [version
page](README.md#the-veterinary-clinic-d196); `vet-lab` is the model for
this page's shape ([vet-lab-domain.md](vet-lab-domain.md)).

## The draft at a glance (step 9)

Where each item of the part's folder, `domains/vet-housing/`, is stated
on this page (procedure 1, 3 and 4; the format is finalised in the
master spec, O111):

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-housing`, `requires: [vet-core]`, tables and roles prefixed `housing_`, landing in the core's database only, `lands_with: vet-core` (ruled, D318, D322), the purposes that fit | [What housing holds](#what-housing-holds); [Purposes that fit](#purposes-that-fit-step-7) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest of the core variant's name (D301, answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/schema.sql`: tables, the unit board view, keys, states, roles and grants, in `clinic` | [The data model](#the-data-model-step-4) |
| `data/load.sql`: the year's placements and care log, the state at T0, on the core's stays computed by its documented functions (D322) | [Deterministic key ranges](#deterministic-key-ranges), [The history before T0](#the-history-before-t0), [Loading](#loading) |
| `data/classification.yaml`: every column classed | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The rules](#the-rules-ruled-d318) |
| `producers/`: the practice software's housing fragments (on `pms`, D276), the ward service's (`ward`, D287) | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; [Traps](#traps-step-8); [Loading](#loading) |

## Settled before this page

Built on, not reopened:

- **The split** (D279): `vet-housing` holds "boxes and stalls, the
  placements of the core's stays, care and feeding logs; the displays,
  reading the core's board of each animal". The hospital stay itself
  (admission, discharge, reason, outcome) is the core's (D278 answer 6),
  since the lab, the portal, the reports and the administrations refer to
  it; housing refers to it by id.
- **The displays** (D287, friction 9): they talk to a **ward service
  holding a pool**, as real ones do, with no scheduler change. A faulty
  display is found through the ward service's **redundant query**, whose
  parameters name the box, and the relation **box → stay → animal**,
  which `vet-housing`'s placements and the core's stays hold; the housing
  data must keep it. The owner: "identifying the querier (the ward
  service) and the redundant query might be sufficient to determine which
  display is faulty. (there must be somewhere something that relate a
  housebox to a specific animal)".
- **Small action events** (D288, D298, friction 11): the displays record
  action events only, feeding, care, cleaning, checks; no per-access log
  is kept, a display's reads leaving nothing but the database's own
  statistics; about forty animals at a dozen events each, some 500 rows
  a day, kept on site for the whole game. The owner: "Do we really need
  to keep every day's access, etc. ... it's most probably indicators that
  actions have been taken ... so it should stay smallish."
- **In the core** (D279): stays, alerts (an infectious animal among
  them), staff (carers and grooms, nurses), the administrations of every
  medicine; and the view `animal_board`, read by the role `vet_display`:
  an animal's identity, its current stay, its alerts, its administrations
  of the day, never a natural identifier (core rule 10; trap T25). The
  core's page names the displays as `vet-housing`'s ward service, not a
  core producer ([vet-core](vet-core-domain.md#the-applications-and-their-nodes-d276)).
- **One application, one producer node** (D276): the practice-management
  software, `pms`, carries `vet-scheduling`'s and `vet-housing`'s
  fragments beside the core's. The ward service is an application of its
  own, so a node of its own: D287's chain starts by telling it from the
  practice software in `pg_stat_activity`, where every session carries
  its node's hostname as `application_name`.
- **One centre** (D285); every site in the customer's zone (D276); one
  variant, `regional-franchise` (D263); "the data schema stays simple and
  the tables small" ([platform.md](../../platform.md)).
- **Tests** (D314): short, under 30 minutes on the least environment;
  the whole clinic deployed once as the proof in play. **Faults**: the
  GM's to select (D309); v0.5 builds the test selection's ten (D316).

## The brief (step 1, ruled, D318)

The owner writes the brief (procedure 2). Proposed, built from the
clinic's brief (D196) and the split (D279), for him to correct:

> The centre's horse and farm sections each have their own housing, and
> the domestic section its kennels and cages: every hospitalised animal
> is placed in a box, a stall, a pen, a kennel or a cage, and moves
> between them (out of intensive care, into isolation). Each unit has its
> own dedicated display, showing the animal placed there with access to
> its file: who it is, its alerts, why it is in, what it eats or whether
> it is nil by mouth, the day's doses and the care already given. The
> carers and grooms record on the display what they do: feeding, water,
> mucking out, walks, checks, the disinfection of an emptied unit. The
> displays reach the database through the ward service. The data stays
> small: the actions taken, never the displays' every access.

The brief's own words: "horse section (housing, dedicated machinerie,
multiple specialists); farm section (same)"; "housing have their own
dedicated display for each animal, access to their file".

## The business sketch

The sketch covers housing as the carers, the nurses and the displays
meet it: where each hospitalised animal is, what is done for it there,
how much and how often, under which rules. What belongs to the core or
another part is named, and left to it.

### The business

The centre's hospital wards, one per section:

- **the horse section's barn**: boxes, two of them isolation boxes, two
  intensive-care boxes (padded, for foaling or a recovering colic);
- **the farm section's barn**: stalls for cattle, pens for sheep and
  goats, one isolation pen;
- **the domestic section's wards**: kennels for dogs, cages for cats and
  small animals, an isolation kennel and an isolation cage, an
  intensive-care room of cages.

A unit holds one animal at a time (a calf with its dam stays out of
v0.5). A nurse places the animal at admission, in the practice
software, and moves it when its care changes; the carers and grooms
feed, water, clean, walk and check it, recording each action on the
unit's display; an emptied unit is cleaned and disinfected before the
next animal, an isolation unit always. The display shows the animal
placed there, read from its file through the ward service.

### Actors

| Actor | Who | With housing |
|---|---|---|
| Nurse | core `staff`, `kind` `nurse` | places an animal at admission, moves it, sets its diet, records a vet's nil-by-mouth order (in the practice software) |
| Vet | core `staff` | orders nil by mouth before an anaesthetic, an animal to isolation; reads the board |
| Carer, groom | core `staff`, `kind` `carer` (D278 answer 9) | feeds, waters, mucks out, walks, checks, disinfects; records each on the display; never prescribes, never gives a dose |
| The display | one per unit, a small read-mostly screen | shows the unit's board; sends the carers' actions to the ward service |
| The ward service | the displays' back end, an application of its own (D287) | holds a pool of connections to `clinic`: reads each unit's board, writes the care events |
| The practice software | `pms` (D276) | the nurses' screens: placements, moves, diets, the ward's overview |
| Owner | through `vet-portal` | none in v0.5: what the portal shows of a stay is that part's (Boundaries) |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Admission | the stay | core (`stays`) |
| Placing the animal | the unit, the stay, from when, by whom, why | `vet-housing` (`housing_placements`) |
| Moving it | the open placement ended, the next opened, at one instant | `vet-housing` |
| Its diet, a nil-by-mouth order | the plan in force, from and until | `vet-housing` (`housing_feeding_plans`) |
| Feeding | when, how much was eaten (all, part, none), by whom | `vet-housing` (`housing_care_events`) |
| Water, mucking out, bedding, a walk, grooming, a check | the action, when, by whom | `vet-housing` |
| Giving a medicine | the administration | core (`administrations`), never the care log |
| Discharge, transfer, death | the stay's end | core |
| Releasing the unit | the placement ended, the unit to clean | `vet-housing` |
| Disinfecting an emptied unit | the action, the unit clean again | `vet-housing` |
| Showing the board | nothing: a display's reads leave no row (D298) | the ward service, reading `housing_unit_board` |

### The variant, its scale and its tags

Housing takes the clinic's one variant, `regional-franchise` (D263,
vet-core question 13), and adds no tag: `24/7` and `regulated` already
say what it needs. Its axes go in a manifest of the core variant's
name, `vet-housing/variants/regional-franchise.yaml` (D301, answer 15).
The figures fit the core at one centre's scale (D295): about 40 animals
in hospital at any time, about 8 admissions and 8 discharges a day,
about 2 500 stays in the year.

**Population**, at load:

| What | How many |
|---|---|
| Units | 64: the horse section 22 boxes (2 isolation, 2 intensive care), the farm section 10 (5 stalls, 4 pens, 1 isolation pen), the domestic section 32 (14 kennels, 10 cages, 6 intensive-care cages, an isolation kennel and an isolation cage); 2 out of service (a box and a kennel under repair) |
| Displays | 64, one per unit; 66 rows, two replaced during the year |
| Animals placed at T0 | about 40, about 14 horses, 6 farm animals, 20 domestic animals (an assumption the core is asked to state, [Changes](#changes-needed-in-shared-pages)) |

About 62 % of the units in service occupied on average, so a section's
busiest day finds a free unit.

**History**: one year, as the core's (D279), following its stays: about
3 030 placements (454 stays moved, 157 of them twice, into isolation and
out), 2 800 plans, and the care log, about 133 000 events (ruled, D318;
the build's figures, D417).

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Placements | about 8 a day at admission, 2 moves |
| Releases and disinfections | about 8 a day each |
| Feeding plans | about 8 diets and 3 nil-by-mouth orders a day |
| Care events | about 520 a day: 110 feedings, 240 checks, 160 other actions, 8 disinfections; about 22 an hour |
| Display reads | each display once a minute: about 64 a minute, one a second, leaving no row |

About **0.14 million rows** at load (138 752 at the reference T0, D417;
step 4 counted 0.16) and **540 a day** live, beside the core's 0.28 million and 760 (570 main rows) in the
same database.

**A few stand for many** (D263): 64 units and their displays for a
large referral hospital's wards.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Around the clock | admissions and placements (a third at night, as the core's), checks every four hours, emergencies to intensive care | yes |
| The feeding rounds, every day | horses at 06:00, 12:00, 17:00 and 21:00; cattle, sheep and goats at 07:00 and 16:00; dogs at 08:00 and 17:00; cats and small animals at 08:00, 13:00 and 18:00 (game values) | yes |
| The care day, 06:00 to 22:00 | mucking out, bedding, water, walks, grooming | yes |
| Late morning, daily | discharges (the core's), so releases and disinfections | yes |
| The evening before an anaesthetic | nil-by-mouth orders | yes |
| Weekly, monthly, yearly | none of housing's own; the head office's monthly figures may read it ([Purposes](#purposes-that-fit-step-7)) | no cadence to flag (O22) |

### Regulations

What a hospital's housing plausibly answers to, at the level a game
needs; confirmed at step 5. The EU citations were checked against the
Official Journal's texts on 2026-11-03, at the fold-in; every figure is
a game value.

| Rule | Source | What housing must hold |
|---|---|---|
| Animals are fed, watered and inspected; farmed animals whose welfare depends on human attention at least once a day | Council Directive 98/58/EC, Annex points 2 (inspection at least once a day) and 14–16 (feed, water), for the farm section; national animal-welfare law for the others | the care log: feedings and checks per animal, with times |
| An operator takes biosecurity measures against the spread of disease | Regulation (EU) 2016/429, Art 10(1)(b) and 10(4)(v) (isolation of sick animals); the vets' own duties in Art 12 | isolation units, an infectious animal placed in one, disinfection recorded |
| A medicine given is recorded with its batch and withdrawal period | Regulation (EU) 2019/6, Art 108 (the keeper's records, the withdrawal period, five years), Art 103(3) (the batch, in the dispenser's records) (core rules 2, 6) | nothing: the core's administrations; the care log never records a dose |
| Nil by mouth before a general anaesthetic | professional practice, no law | the order, from and until, on the board; no feeding while in force |
| Owners' data is personal; least data per reader, the displays without identifiers | GDPR; core rule 10 | a board with no owner, no contact, no natural identifier |
| Records kept for a set period | core rule 9 (five years, a game value) | the care log kept as the stay's record |

## What housing holds

Within the procedure's section 4: every table prefixed `housing_`,
every core key by id with no foreign key, the tables in `clinic` beside
the core's (ruled, D318):

- **Reference**: the units, each in a section, its kind, isolation or
  intensive care, its hygiene state; the displays, each on a unit.
- **Placements**: which stay is in which unit, from when until when, the
  relation D287 requires.
- **Plans**: each stay's diet and its nil-by-mouth orders, dated.
- **The care log**: each action taken at a unit, for its occupant, or
  for the emptied unit.
- **The unit board**: a view, one row per unit, joining the unit, its
  open placement, the core's board for the stay's animal, the plan in
  force and the day's care: what a display shows.

## Where housing presses on the core

| Housing needs | The core |
|---|---|
| the stay a unit holds, its section, its admission and its end | `stays` (D278 answer 6): `id`, `animal_id`, `section_id`, `admitted_at`, `discharged_at`, `outcome` |
| the animal's species, so the unit fits it | `animals.species` |
| a current infectious alert, so the animal goes to isolation | `alerts` with `kind` `infectious`, from and until |
| who places, feeds and checks | `staff` by id and `kind` (`nurse`, `carer`) |
| what a display shows of the animal | `animal_board` (D279): identity, the current stay, alerts, the day's administrations, never a natural identifier |
| that a dose is recorded once | the core's `administrations` only; the care log holds no dose (a trap, T165) |
| the customer's zone, for "today" on the board | `business_settings` (the same database, no copy of its own) |

**Read in place while running; computed at load.** Housing lands in
`clinic` (ruled, D318), so its roles read these columns directly while
the game runs, by column grants its own schema gives; nothing is copied,
no purpose moves them. Its load never reads them: it computes the
year's stays, their animals' species and their infectious alerts from
the core's documented functions (D249, D322), as `vet-lab`'s load
computes the requests (D302). The placement of a new
stay is the practice software's own work, as `lab.identity` is the
lab's (D266, D304): one application writing both, not a flow between
parts.

## Boundaries with the other parts

Kept minimal; nothing of theirs is designed here.

- **`vet-scheduling`**: books rooms, machines and staff; it never books
  a unit. An animal is placed when admitted, with no reservation ahead
  (ruled, D318). Housing's streams share `pms` with scheduling's
  (D276), each prefixing its keys.
- **`vet-machinery`**: no housing unit is a machine; the displays
  produce no readings (D298) and nothing of housing ships to cold
  storage.
- **`vet-portal`**: shows owners nothing of housing in v0.5 by this
  draft. If the portal shows a hospitalised animal's day ("ate all its
  breakfast"), that is a release to the portal drafted with `vet-portal`,
  reading the care log through a grant of its own; named for later
  ([Purposes](#purposes-that-fit-step-7)).

## The sketch's answers (step 2, ruled, D318)

The questions the brief leaves open, each answered as this draft
proposed (D318), answer 4's load changed by D322.

1. **Which sections have housing** (O181). Answer: all three.
   The brief names housing for the horse and farm sections; the
   domestic section's kennels and cages are housing too, since most of
   the core's stays are domestic animals and the display is "one per
   animal". Taking horse and farm only would leave about half the stays
   with no placement and no display.
2. **One display per unit** (O182). Answer: a display on each
   of the 64 units, showing the animal placed there; "one per animal"
   read as each hospitalised animal having its unit's display. An empty
   unit's display shows the unit's state (clean, to clean, out of
   service). Each display refreshes once a minute through the ward
   service: about one board read a second, each carrying the unit's id.
3. **What a display shows and records** (O183). Answer: it
   shows the unit, the animal's name, species, sex and age, its alerts,
   the stay's reason and day, its diet or a nil-by-mouth order in force,
   the day's doses from the core's board (given or due), and the day's
   feedings and last check. It records care events only: feeding (all,
   part or none eaten), water, mucking out, bedding, a walk, grooming, a
   check, the disinfection of an emptied unit; never a dose, which the
   nurses record in the practice software's round (core). No owner, no
   contact, no natural identifier (core rule 10).
4. **Where the tables live** (O184). Answer: in `clinic`, on
   `records`, beside the core (`at: records/clinic`), never in an
   instance of their own. The ward service's board read is one
   statement, a stream holding one connection (friction 6); it joins the
   unit to the core's board, so both must be in one database. In an
   instance of its own, housing would need a synced copy of the stays
   and the board, a purpose not built in v0.5. `domain.yaml` declares the
   constraint, `lands_with: vet-core`, and the loader refuses another
   `at:` (D322; format text in procedure 10, confirmed by D326, for
   O111). The load
   does not read the core's stays in place, as this draft first
   proposed: it computes them by the core's documented functions, as
   `vet-lab`'s does (D302), D249 staying the default (D322).
5. **How much history** (O185). Answer: a year, as the core's:
   every stay's placements, plans and care log, about 0.16 million rows
   (0.14 million as built, D417),
   the care log the stay's record kept five years (core rule 9). The
   alternative, the current stays only, saves about 0.15 million rows
   but leaves `housing.stay-log` and the head office's occupancy with no
   past.
6. **Reservations** (O186). Answer: none in v0.5. An elective
   admission's unit is not booked ahead; `vet-scheduling` books no unit,
   and housing's placement happens at admission.
7. **The variant**: `regional-franchise`, no tag added, the part's axes
   in its manifest (D301 answer 15); not a question.

## The data model (step 4)

On the answers above. The tables land in `clinic`, in `public`,
prefixed `housing_` (procedure 4), owned by the role `housing`, written
in the core's manner: integer keys `GENERATED BY DEFAULT AS IDENTITY`,
explicit ids at load and each sequence set after its range. Core keys
are plain integer columns with no foreign key: `section_id`, `stay_id`,
the staff ids. Integrity between a placement and its stay is an
invariant, and an orphan a fault vector (procedure 4).

### Entities

| Table | Key, main columns |
|---|---|
| `housing_units` | `id`; `section_id` (the core's), `code` (`H-01`, `F-03`, `D-12`), `kind` (`box`, `stall`, `pen`, `kennel`, `cage`), `isolation`, `intensive`, `state` (`clean`, `to-clean`, `out-of-service`), `state_since_at` |
| `housing_displays` | `id`; `unit_id`, serial, installed on, removed on (open while in place) |
| `housing_placements` | `id`; `unit_id`, `stay_id` (the core's), `from_at`, `until_at` (open while placed), `reason` (`admission`, `move`, `isolation`), placed by (staff); a partial unique index on `unit_id` and one on `stay_id` where `until_at` is open: one animal per unit, one unit per stay |
| `housing_feeding_plans` | `id`; `stay_id`, `kind` (`diet`, `nil-by-mouth`), diet (from a short list per species), meals a day, `from_at`, `until_at`, set by (staff), note |
| `housing_care_events` | `id`; `unit_id`, `stay_id` (the unit's occupant at the time; none for an emptied unit), `kind` (`feeding`, `water`, `mucking-out`, `bedding`, `walk`, `grooming`, `check`, `disinfection`), `eaten` (`all`, `part`, `none`; feeding only), at, by (staff), note; written once, never updated |

**The view `housing_unit_board`**, owned by `housing`, one row per unit:
the unit (`unit_id`, code, section, kind, isolation, intensive, state);
its open placement (id, from); the stay (`stay_id`, admitted at) and,
through the core's `stays`, its animal; from `animal_board`, the
animal's identity, its alerts, the stay's reason and the day's doses;
the plan in force, a nil-by-mouth order overriding the diet; the day's
feedings (count, the last and how much was eaten), the meals due so far
today and the last check, "today" in the customer's zone
(`business_settings`); the animal's age in years from `animals.born_on`
(D417). An empty unit's
row carries the unit only. The chain D287 requires is the view's own
join: unit → open placement → stay → animal.

Units fit species: a box a horse; a stall cattle; a pen sheep or goats;
a kennel a dog; a cage a cat or a small animal; an isolation or an
intensive-care unit any species of its section.

### Lifecycle states

| Entity | States |
|---|---|
| Unit | `clean` → occupied (an open placement, not a state: the placement holds it) → `to-clean` when released → `clean` after its disinfection; `out-of-service` and back (at load only in v0.5) |
| Display | installed → removed (replaced) |
| Placement | open (`until_at` empty) → ended, at the stay's end or a move |
| Feeding plan | in force → ended (`until_at`); a nil-by-mouth order in force overrides the diet |
| Care event | written once |

The unit's hygiene is a state; whether it is occupied is not, so the
placements stay the one place that says it (one fact, one place).

### Deterministic key ranges

| Key | Range | Layout |
|---|---|---|
| `housing_units.id` | 1–64 | 1–22 the horse section (1–2 isolation, 3–4 intensive care, 5–22 boxes; 15 out of service); 23–32 the farm section (23 isolation pen, 24–28 stalls, 29–32 pens); 33–64 the domestic section (33 isolation kennel, 34 isolation cage, 35–40 intensive-care cages, 41–54 kennels, 55–64 cages; 50 out of service) |
| `housing_displays.id` | 1–66 | display `u` on unit `u`; 65 and 66 replaced those of units 7 and 41 during the year, displays 7 and 41 removed |
| History | `housing_placements`, `housing_feeding_plans`, `housing_care_events` as loaded, in time order | each sequence set after its last id |
| Core keys used | `stay_id` 1–2 500, each stay's animal, section, admission, end and outcome; the animal's species; the infectious alerts current on a stay; `section_id` 1–3; staff by the core's layout (nurses among 29–51, carers and grooms 57–66, by section 57–60 horse, 61–62 farm, 63–66 domestic, D324, D394) | computed by the core's documented functions, never read (D249, D322) |

No part refers to housing's ids, so nothing beyond the units needs a
documented layout.

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret. Housing's schema runs after the core's into `clinic`, as
`postgres`, and gives the grants on the core's tables below; the core's
own grants are unchanged but for the two rows in [Changes needed in
shared pages](#changes-needed-in-shared-pages).

| Role | Who | Reads | Writes |
|---|---|---|---|
| `housing` | owns housing's tables and the view; no login | for the view: `animal_board`, `business_settings`, `stays` (`id`, `animal_id`, `reason`) and `animals` (`id`, `born_on`) (D417) | |
| `housing_app` | the practice software's housing screens, on `pms` (D276) | every housing table and the view; of the core's: `stays` (`id`, `animal_id`, `section_id`, `admitted_at`, `discharged_at`, `outcome`), `animals` (`id`, `species`), `alerts` (`animal_id`, `kind`, `from_at`, `until_at`), `staff` (`id`, `kind`) | `housing_placements`, `housing_feeding_plans`; `housing_units` (`state`, `state_since_at`) only; never the units' or displays' other columns |
| `housing_ward` | the ward service's writes (D287) | `housing_units`, `housing_placements`, `housing_feeding_plans`, `housing_care_events`, the view; `staff` (`id`, `kind`) | `housing_care_events` (insert only, with `USAGE` on its sequence: a feeding's `eaten` is a hash of its id, D417); `housing_units` (`state`, `state_since_at`) only |
| `vet_display` (the core's) | the ward service's board reads, the displays' | the core's `animal_board` (D279) and `housing_unit_board` | nothing |
| `vet_reports` (the core's) | `backoffice`'s reads on the standby (D299, D306) | every housing table, as every core table | nothing |

**Two roles for the ward service.** Its reads are the displays', on a
read-only role, the core's `vet_display`, which the core created for
them; its writes are the carers' actions, on `housing_ward`, which can
add a care event and mark a unit clean and nothing else. A display
therefore cannot move an animal or touch the record.

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| Units, displays | 64, 66 | none |
| Placements | about 3 030 (2 421 admissions, 244 into isolation, 367 moves) | about 10 (8 admissions, 2 moves) |
| Feeding plans | about 2 800 (2 421 diets, 374 nil-by-mouth orders) | about 11 |
| Care events | about 133 000 (60 800 checks, 28 400 feedings, 40 700 other actions, 3 000 disinfections) | about 520 |
| **Total** | **about 0.14 million rows** (138 752 at the reference T0, 2026-11-04 10:00Z, offset +2; 138 863 at offset 0) | **about 540 rows** |

The build's counts (D417): the care log follows the stays' ramp, so
the year's mean is below the 520 a day of today's 40 animals. Beside
the core's 0.28 million in `clinic`, about 0.42 million on `records`'
`clinic` with `office`'s 0.16 million beside it: under the shop's 1.3
million and within the `postgres` brick's 2.25G of disk; 17 MB with
indexes, measured. Far under cold
storage's threshold of about 50 000 rows a day (D296): nothing ships.

### Plausibility points (step 4, optional, ruled, D318)

Offered to the owner; the draft carries on with them:

1. **Sixty-four units for forty animals**, about 62 % occupied on
   average, so the busiest day still finds a unit of the right kind.
2. **Placements one per unit and one per stay**, each move ending one
   and opening the next at one instant; about one stay in five moved.
3. **The unit's hygiene a state, its occupancy not**: the placements say
   who is there.
4. **A dozen care events per animal a day**, about 520 in all, D298's
   figure: six checks, about three feedings, the other actions.
5. **The care log holds no dose**: a medicine given is the core's
   administration (one fact, one place).
6. **The care event names its stay** beside its unit, as a real nursing
   record names its patient: the one fact housing holds twice, the unit's
   occupant at the time, an invariant against the placements (T160).
7. **Housing in `clinic`**, declared by `lands_with: vet-core` (answer
   4, D322), its load computing the core's stays by functions like every
   other part's.
8. **Two displays replaced in the year**, so the chain from a unit to its
   display goes through `housing_displays`, not an equal id.

## Classification and governance (step 5)

### Classification

v0.4's three classes, applied as the core applies them (D280): keys
`<table>.<column>`, the scenario's copy adding the database (procedure
6, item 2).

Readings for housing:

- **No housing table carries an identifier**: a unit, a display, a stay
  id, a staff id are the clinic's work record, `internal`, as the core's
  `administrations.stay_id` and the lab's `request_id` are.
- **The unit board carries the animal's id with no identifier beside
  it**, so `customer-linked`, as the core's `animal_board.animal_id`.
- **Free text** (a plan's or a care event's note) is `internal`, with
  the trap the core's readings name: it may name the owner (T169).

| Table or view | `personal` | `customer-linked` |
|---|---|---|
| `housing_unit_board` (view) | | `animal_id` |

Every other column of every housing table is `internal`. Housing holds
no personal data, which the rules below keep so.

### The business's own rules

Housing's default policy (procedure 6, item 1), beside the core's and
the lab's, built into the part's `docs/policy.md` and its `governance:`
fragment. Its home is the core's unnamed EU member state (D278). The
sources were checked at the fold-in (Regulations); every figure is a
*game value*.

**The board's least data.** A display shows the animal's name, species,
sex and age, its alerts, the stay's reason, its plan and the day's doses
and care; never the owner, a contact or a natural identifier (core rule
10). Its notes are working notes, never an owner's name.

**Biosecurity.** An animal with a current `infectious` alert is housed
in an isolation unit, moved there when the alert comes during its stay,
as soon as one is free (the policy as built, D417);
an isolation unit's occupant never shares the ward's ordinary units;
every emptied unit is mucked out and disinfected before the next animal,
an isolation unit always (Regulation (EU) 2016/429, Art 10, the
operator's biosecurity; the clinic's rule).

**Nil by mouth.** A vet's nil-by-mouth order is on the board from its
start; no feeding is recorded while it is in force (*game value*: from
eight hours before an anaesthetic for a dog or a cat, twelve for a horse
or a ruminant; the clinic's rule).

**Checks and feeding.** Every hospitalised animal is checked at least
every four hours, around the clock, and fed by its plan at its species'
rounds (*game values*; Directive 98/58/EC's daily inspection the legal
floor for farmed animals).

**One fact, one place.** A medicine given is recorded in the core's
administrations, never in the care log; a placement names a stay, never
an animal.

**Actions, not accesses** (D298). The displays record the actions
taken; no read of a display is logged in a table, by a heartbeat or in
the audit log.

**Least grants.** The displays read one view and write nothing; the
ward service adds care events and marks units clean and nothing else.

**Retention.** The care log, the plans and the placements are the
stay's record, kept as the clinical records are: five years from the
stay's end (core rule 9), then erased with it.

### The rules (ruled, D318)

For the owner to judge realistic, with the classification above:

1. **The board's least data**: no owner, contact or natural identifier
   on a display.
2. **Biosecurity**: infectious animals in isolation; every emptied unit
   disinfected before the next, isolation always (2016/429 Art 10).
3. **Nil by mouth** on the board, no feeding while in force (eight
   hours, twelve for horses and ruminants: game values).
4. **Checks** every four hours, **feeding** by plan at the rounds (game
   values; 98/58/EC's floor).
5. **One fact, one place**: no dose in the care log; a placement names a
   stay.
6. **Actions, not accesses**: no read logged (D298).
7. **Least grants**: the displays read one view, the ward service writes
   care events and the units' `state` only.
8. **Retention**: five years with the stay (core rule 9).

## The producer profiles (step 6)

Applying friction 9 (D287) and friction 11 (D298), the two the
[producer profiles](producer-profiles.md#applied-at-the-parts-profile-steps)
left to `vet-housing`, on the core's model: a volume stream against a
work stream, values from SQL and `choice` (D276, D303), readable
fragments holding no timeline, intensity or planted fault (D276).

**Producer or purpose.** Every flow here is inside one database and one
of two applications: the practice software writing the placements from
the core's stays, the ward service reading the board and writing the
care log. No flow crosses parts or leaves the centre, so step 6 holds
them all; step 7 adds none of housing's own.

### The applications and their nodes (D276, D287)

| Application | Node | Connection, role | What it does |
|---|---|---|---|
| The practice software's housing screens | `pms`, the core's node (D276) | `housing`: `records:5432/clinic` (or the scenario's pooler), `housing_app` | places each new stay, moves animals, releases units, sets diets and nil-by-mouth orders; the nurses' ward overview |
| The ward service (D287) | `ward`, a scheduler node of its own in the players' scope | `ward-board`: `records:5432/clinic`, `vet_display`, `pool: {size: 4}`; `ward-care`: the same target, `housing_ward`, `pool: {size: 2}` | the displays' back end: each display's board read, through its pool; the carers' actions recorded from the displays |

**Why the ward service is its own node.** D287's chain starts with "the
querier": every session of a node carries its hostname as
`application_name` (`pools.py`), so the displays' reads show as `ward`
in `pg_stat_activity` and `pg_stat_statements`' users, never mixed with
the practice software's `pms`. Its pool keeps the displays' some sixty
consumers at four sessions on `records`, against `max_connections`' 100
(D138). The fragments are written for the node names `pms`, `ward` and
`records` and the database `clinic`; the GM renames them as the scenario
does.

### Rates at intensity 1.0

On `pms`, connection `housing`, as `housing_app`:

| Key | Kind | What one call takes and writes | Rate or capacity | Shape | A day |
|---|---|---|---|---|---|
| `housing.place` | work | the oldest current stay (no end) with no open placement, admitted five minutes ago or more: placed in the free unit of its section fitting its species with the lowest id, `clean` and in service, an isolation unit when its animal has a current `infectious` alert; `reason` `admission`, by a nurse; its diet plan (the species' diet and meals a day) | 6/h | `flat` | follows `stays.admit`: about 8 |
| `housing.release` | work | an open placement whose stay has ended, discharged, transferred or died: ended at the stay's end, its unit `to-clean`, its plans ended | 6/h | `flat` | follows `stays.discharge`: about 8 |
| `housing.move` | volume | a current stay moved to a free unit of its section: out of intensive care after a day or more, into isolation when an infectious alert has come, or a box change; in one transaction, the open placement ended and the next opened at the same instant, the old unit `to-clean` | 0.08/h | `flat`, poisson | about 2 |
| `housing.fast` | volume | a nil-by-mouth order for a current stay, from the next hour for eight hours (dogs, cats) or twelve (horses, ruminants), set by a nurse for the vet | 0.28/h | `clinic-day`, poisson | about 3 a weekday |

Reads on `pms`, as `housing_app`: `housing.ward-view` (a section's units,
occupants, plans and the day's care for the nurses' station; 12/h, even,
`flat`), `housing.stay-log` (one stay's placements and care log; 10/h,
poisson, `clinic-day`).

On `ward`:

| Key | Kind | Connection | What one call takes and writes | Rate or capacity | Shape | A day |
|---|---|---|---|---|---|---|
| `ward.board` | read | `ward-board` (`vet_display`) | one display's refresh: `SELECT ... FROM housing_unit_board WHERE unit_id = %(unit)s`, `unit` `{int: [1, 64]}` | 3 840/h (64 a minute), concurrency 4 | `flat`, even | about 92 000 reads, no row |
| `ward.feed` | work | `ward-care` (`housing_ward`) | an occupied unit whose occupant has had fewer feedings today than its plan's meals due by now, its board showing no nil-by-mouth order (read off `housing_unit_board`, as a carer reads the display): a `feeding` event, `eaten` by a hash of the event's id (about 85 % all, 12 % part, 3 % none), by a carer | 60/h | `feeding-rounds` | about 110 |
| `ward.check` | volume | `ward-care` | a check on an occupied unit, picked by an `int` offset among the open placements | 10/h | `flat`, poisson | about 240 |
| `ward.care` | volume | `ward-care` | another action on an occupied unit: `{choice: {water: 25, mucking-out: 25, bedding: 12, walk: 30, grooming: 8}}`, a walk for a dog or a horse only, else water (a `CASE` on the occupant's species) | 10/h | `care-day`, poisson | about 160 |
| `ward.disinfect` | work | `ward-care` | a unit `to-clean` for 30 minutes or more: a `disinfection` event with no stay, the unit `clean` | 4/h | `care-day` | follows the releases: about 8 |

The displays' refresh is a technical rate, not the business's volume,
but one schedule holds one intensity a node: at another intensity the
displays refresh faster or slower, which the GM notes say (D32).

### The business hours (shapes)

Scenario time, the customer's zone (D276):

| Shape | Hours |
|---|---|
| `flat`, `clinic-day` | as the core's ([vet-core](vet-core-domain.md#the-business-hours-shapes)) |
| `feeding-rounds` | every day, 1.0 in the hour after each round: 06, 07, 08, 12, 13, 16, 17, 18 and 21 o'clock; 0 otherwise |
| `care-day` | every day 06:00–22:00 at 1.0; 0 at night, when only checks are done |

### Input types (D276, D303)

Every value is SQL's, as the core's: diets from a short list per
species in an array literal; the meals a day and the walk by a `CASE` on
the species; the kind of action by the weighted `choice` (D303); a unit
picked by an `int` offset over the open placements ordered by id;
per-row variation (what was eaten, which carer) by a hash of the row's
id, never `random()`, so a run is reproducible from the game's seed
(D117). No domain builder.

### The history before T0

The load follows the core's year of stays (D279), computed by the
core's documented functions (D322), so housing's history grows as the
core's does without a curve of its own:

- each stay, in admission order, placed ten minutes after its admission
  in the free unit its rules give (fit, isolation for an animal whose
  infectious alert was current then, the lowest id); one in nine of the
  horse and domestic stays with no alert to intensive care first, moved
  out after one or two days; a stay with an alert moved into isolation
  when it starts, or, none free, at the first isolation unit
  disinfected while the alert lasts, and **back to an ordinary unit when
  the alert ends**, freeing isolation for the next (without it the
  farm's sixth head of cattle found no unit twice in the year: five
  stalls, and the isolation pen held by a recovered sheep) (D417);
  released at its end, the unit disinfected 30 to 90 minutes later. As
  built: 454 stays moved, 157 of them twice; of 249 infectious stays,
  244 reached isolation, 47 after a wait (at most four infectious
  horses, three farm animals and six domestic animals at once against
  two, one and two isolation units), up to three days on the farm, and
  5 never did; 2 non-infectious admissions overflowed into isolation;
- each stay's diet at its placement; about one stay in six a
  nil-by-mouth order, by a hash of its id, on the evening before a
  morning;
- each placement's care log, day by day, by the rates above: the
  species' meals at its rounds (none while nil by mouth), a check every
  four hours, the care day's other actions, times and carers by hashes
  of the placement's id and the day (a carer of the unit's section, not
  matched against the rota, D394);
- the two out-of-service units out since a week before T0; the two
  replaced displays swapped mid-year.

**In flight at T0**, as a night leaves the wards: about 40 stays placed,
one open placement each and no unit holding two; their plans in force,
a few nil-by-mouth orders running into the morning; the night's checks
recorded, the next feeding round due; units released in the last 90 minutes
`to-clean`, the rest `clean`. Every core stay current at T0 has its
placement, and no placement is open on an ended stay: a mismatch would be
a fault with no story (D304's principle for the partners' database). The
GM's post-load coherence check reads exactly this on the composed
scenario (D322; [procedure](domain-procedure.md) 10): a mismatch there is
a design error caught before hand-over, never a fault.

**Unseen.** The load writes without trace: no statement logging,
`pg_stat_statements` off, pgaudit off for its sessions (D265).

### Cold storage (D297)

Nothing of housing ships: about 540 rows a day against the threshold of
about 50 000 (D296), and the care log is the stay's record, read by the
nurses' screens. Housing's tables ride the core's `wal` and
`basebackup` to the vault and its standby (D299), at no cost of their
own.

### Growth, for the GM notes (D298)

At intensity 1.0, on `clinic`:

| | Rows | Size |
|---|---|---|
| A day, on average | about 540 new rows, 520 of them care events; about 30 updates (placements ended, units' state) | about 0.1 MB with indexes |
| An hour, on average | about 22 | |
| The busiest hour, 17:00–18:00 with the horses', dogs' and cats' meals | about 45 | |
| The displays' reads | about 92 000 a day, no row: `pg_stat_statements`' calls only | |

Over an aging the disk is never housing's problem; its reads are: about
one a second, every one through the board view.

### D287 applied: finding a faulty display

What the GM notes carry for D287's case, the players' way from a
complaint (or a hot statement) to the display:

1. **The querier.** On `records`, `pg_stat_activity` and
   `pg_stat_statements` show the board statement run by `vet_display`
   from `ward`, the ward service, never from `pms`.
2. **The redundant query.** Sixty-four displays at one read a minute
   make about 3 840 calls an hour; a display refreshing in a loop adds
   its own on top, the same statement with the same parameter. The
   statement's calls per minute, against the units, show the excess.
3. **The box.** The parameter names the unit. `pg_stat_statements`
   normalises it away, and the driver binds it server-side (psycopg 3,
   `drivers/postgresql.py`), so `pg_stat_activity` shows `$1`; logging
   the statement with its parameters shows it (`log_min_duration_statement
   = 0` for `vet_display` alone, the ward's pooled sessions terminated
   so the pool reconnects with the setting). A setting for the whole
   instance would log the practice software's statements too, the
   owners' names and phones among them: the harm of T1 (core rule 10),
   which a careful player avoids.
4. **The chain.** The unit → its display (`housing_displays`, open
   while in place) → its open placement → the stay → the animal: the
   box, the display's serial and the animal named in the report.

A display's firmware is no layer of the players': such a fault is
reported, never fixed by the player (bricks-and-faults, "can be reported
or a fix proposed").

### Points for the owner (step 6)

Step 6 has an owner checkpoint only for a flagged cadence (procedure 2),
and housing has none; these are stated for the approval (O190):

1. **One new node**, the ward service `ward`, with two connections, the
   displays' reads as `vet_display` through a pool of four and the
   carers' writes as `housing_ward`; the practice software carries
   housing's placements on `pms`.
2. **The displays refresh once a minute**, about one read a second,
   leaving no row (D298).
3. **About 520 care events a day**, D298's figure.
4. **The feeding rounds**: horses four a day, ruminants two, dogs two,
   cats three, at fixed hours (game values).

## Purposes that fit (step 7)

**Proposed (O189): no purpose of housing's own in v0.5**, and housing
added to one existing purpose's fit:

- **`vet-head-office-figures`** ([clinic-purposes.md](clinic-purposes.md)
  13) fits housing too: its daily feeder, which already counts the stays
  at midnight, adds the units occupied and the units in service per
  section, read from housing's tables on the standby; the month's
  occupancy goes to the head office with the other figures. One more
  measure, no new job; a candidate trap with it (out-of-service units
  counted as available, T171, [Traps](#traps-step-8)).

Why no purpose of its own: every flow of housing stays inside `clinic`
and two applications (step 6); none crosses parts or leaves the centre,
and nothing of it ships. The clinic's ten purposes already reach D290's
budget's needs.

Named for later: **the stay's day on the portal**, a hospitalised
animal's care shown to its owner, a release to the portal drafted with
`vet-portal` if that part wants it.

## Traps (step 8)

No owner checkpoint: a scenario's faults are the GM's to select at
deploy, with whoever sets up the game, within D290's cap and mix (D309).
Read as [clinic-traps.md](clinic-traps.md) reads ("How to read the
tables": where it bites, witness, fixed on, catalogue, D290 class); the
rare-flow and cascade rules there bind these too. The core's traps that
also bite housing are T14 (a sequence left below its loaded range, here
on a housing table: the first placement after T0 failing) and T25 (a
natural identifier on `animal_board`, so on every display).

### 1. The ward service and the displays (D287)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T150 | A faulty display: one unit's board read in a loop, about once a second (its refresh stuck), through the ward service | `records`' CPU and the ward's pool; at a high enough rate the other displays' refresh lagging | the board statement's calls well above 64 a minute, at once; the unit by its parameter, logged for `vet_display`; then unit → display → placement → stay → animal | reported, never fixed by the player (the display's firmware); judged on the report naming the unit, its display and the animal | new (D287's own case) | M; V when it saturates the pool and the displays go stale at a feeding round |
| T151 | The board read held in a snapshot: `ward.board`'s entry `transaction: {isolation: repeatable read, hold: 20s}` | at one read a second and four sessions, an old snapshot always open: vacuum held back on `clinic`'s busiest tables (`administrations`, `requests`, `consultations`) | `pg_stat_activity`'s `ward` sessions idle in transaction, their `backend_xmin` old, at once; dead rows rising on the hot tables over hours | the ward's `queries.yaml` where the scenario makes it fixable, else reported | adapts `scheduler-transaction-held-open` | V |
| T152 | The ward service connecting per call (`pool: {per-call: true}`) | about one backend started and authenticated a second on `records`; with `log_connections`, a line each | `pg_stat_database.sessions` rising by about 3 800 an hour, at once | a pooler in front of `records` where the topology offers one, else reported (the schedule is the GM's, D130) | new | M |
| T153 | A heartbeat on each refresh: the board key also updating a `last_seen_at` on `housing_displays` | about 3 800 updates an hour on a 64-row table: dead rows, WAL to the standby and the vault, against rule 6 | the table's `n_tup_upd` rising about once a second, at once | the ward's `queries.yaml`, the column dropped | new | M |
| T154 | A per-access log: each refresh inserting a row into a reads table | about 92 000 rows a day, past cold storage's threshold (D296): the disk and the archive growing, against D298 and rule 6; the wrong fix ships it instead of stopping it | the table's rows, about 3 800 an hour, at once | the ward's `queries.yaml`, then the table emptied | new | V |
| T155 | `animal_board`'s day of doses with no index on `administrations` by animal and time | every one of the 3 840 reads an hour scanning the year's administrations | `pg_stat_statements`: the board statement first by total time on `records`, at once, worse as administrations grow | an index on `records` | adapts `pg-join-index-missing` | M, V as the year grows |
| T156 | The day's care read with no index on `housing_care_events` by unit and time | every read scanning the year's 150 000 events | as T155 | an index on `records` | adapts `pg-join-index-missing` | M |

### 2. Placements: the chain box → stay → animal

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T157 | `housing.release` taking `outcome = 'discharged'` only: the stays that ended by death or transfer never released | a display still showing a horse put down yesterday or a dog transferred; the unit never `to-clean`, so new admissions placed elsewhere, a section full of empty boxes | open placements on ended stays, about 0.8 a day (died 6 %, transferred 4 % of 8 discharges) | `pms`' `queries.yaml` (the release statement), then the data | new | V; D with a story of carers complaining |
| T158 | A move opening the next placement before ending the open one, in two transactions, the unique index on the open placement's `stay_id` dropped | the old unit's display still showing the animal; care events at either unit; the unit never released | stays with two open placements, at each move (about 2 a day) | the index, the move's transaction, then the data | new | M, V over days |
| T159 | The unique index on the open placement's `unit_id` dropped, `housing.place` choosing a unit by its state alone | a unit holding two animals: its display alternating between them, the board returning two rows | units with two open placements, at the first admission into a unit released and cleaned while its placement stayed open (with T157), or at any race | the index, the placement's statement, then the data | new | M |
| T160 | The ward's care statement taking the stay of the unit's latest placement, ended or not | the actions at an emptied unit, its mucking-out and disinfection, recorded on the stay that left; the next occupant's first events on the former one | care events whose stay had ended before the event, at every release | the ward's `queries.yaml`, then the data | new | M |
| T161 | `housing.place` writing the animal's id into `stay_id` (two integer columns, no foreign key) | the chain broken: a unit's placement naming another animal's stay or none, its display showing a stranger or nothing | placements whose stay is not current or names another animal, at each admission (about 8 a day) | `pms`' `queries.yaml`, then the data | new (procedure 4's orphans) | M, V over days |

### 3. Care, feeding and biosecurity

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T162 | The unit board showing the latest plan by its start, the diet written after a nil-by-mouth order hiding it | the carers, following the display (`ward.feed` reading it), feeding an animal due for an anaesthetic: rule 3 | feeding events inside a nil-by-mouth order, at each order followed by a diet change (about 3 orders a day) | the view on `records` | new | V; D with a story of an anaesthetist's complaint (a horse fed before its colic surgery) |
| T163 | `housing.place` ignoring a current infectious alert, or `housing.move` never moving an animal whose alert came during its stay | an infectious animal in an ordinary unit: rule 2 | an infectious animal outside isolation while an isolation unit of its section has stood clean and free for more than a day (D419; the history's waits, every isolation unit held, are no witness); rare, a story raising the rate (strangles in the horse barn, D306 point 6) | `pms`' `queries.yaml`, then the moves (reported) | new | V |
| T164 | `housing.release` marking an isolation unit `clean` at once, skipping its disinfection | the next animal placed where an infectious one was: rule 2 | placements into an isolation unit with no `disinfection` event since its last occupant, at each release of one | `pms`' `queries.yaml` | new | M |
| T165 | A care kind `medication` offered on the displays and used | a dose recorded at the box and not in the core's administrations, or in both: two places for one fact (rule 5); the medicines register short | care events of that kind, beside the core's administrations at the same animal and hour | reported (the ward's application); the ward's `queries.yaml` where fixable | new | M; V when the register's feeder misses the doses |
| T166 | The night checks short: `ward.check`'s capacity cut at night by a key (rides the schedule) | animals unchecked for more than four hours at night: rule 4 | occupied units with no check for over four hours, every night | reported (the ward's staffing, D276) | new | M |

### 4. Governance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T167 | The unit board joining `owners` for the owner's name and phone ("to call in an emergency") | a person's contact on a screen in the barn: rule 1, core rule 10 | the view's definition, at once | the view | new (beside T25) | M |
| T168 | `vet_display` granted more than its two views (`stays`, `owners`), or `housing_ward` writing placements or a core table | a display able to read the record or move an animal: rule 7 | the grants, at once | the grants | new | M |
| T169 | Notes naming the owner ("owner visited, Mrs ..."), shown by the board | a person's name on the display: rule 1 | notes matching owners' names, a few a week | the view leaving the notes out, then the data (reported) | adapts `governance-personal-copied` | M |
| T170 | pgaudit on `records` logging reads (`pgaudit.log` with `read`), or the role setting of T150's step 3 left on | about 3 800 audit or log lines an hour from the displays, the log's disk growing: rule 6 | the log's growth, at once | `postgresql.conf`, the role setting | new | M |
| T171 | The head office's occupancy counting out-of-service units as available, when O189 adds the measure | the month's occupancy low by two units | the feeder's day against `housing_units`, each night | the feeder's query | new | M |

### 5. False-alarm material

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "Something hits `records` with the same query every second" | the 64 displays, each once a minute (D287) | the board statement's calls against the units, the parameters spread over all of them |
| "Box H-07's display shows no feeding since last night" | the horse is nil by mouth for this morning's surgery (rule 3) | the plan in force |
| "Box H-12's display shows it empty, yet the horse's name is on the door" | the horse moved to intensive care an hour ago | the placements |
| "Two isolation boxes stand empty while a horse waits for a box" | isolation units are kept for infectious animals (rule 2) | the units and the alerts |
| "An infectious animal is in an ordinary unit" (the history's, at most a few at once) | the section's isolation units were all held; it moves in at the first one disinfected (D417; never T163's witness, which needs a free isolation unit for a day, D419) | the placements, the alerts and the isolation units' occupants |

### Against the test selection

The ten (D316) held nothing of D287's own case, the one fault the owner
described himself. T150 replaces s9 (D325, the spec's choice under
D309), class M for class M:
[clinic-test-selection](clinic-test-selection.md).

**How T150 is judged.** A display's firmware is no layer of the
players', so T150 is reported, never fixed (bricks-and-faults; D209's
precedent). In a game it is judged at the final answer, on the report
alone: the unit, its display's serial and the animal named, the excess
calls shown, and no instance-wide statement logging left behind (T170,
core rule 10). The GM does not switch the display off when the report
names it: the GM's only action during play is stopping the game, and it
never touches the load (gm-stance, "Stop only", "No events outside the
schedule"), so the faulty display loops until teardown, and the
feedback says the clinic's technician would replace it. Clearing its
key is the build's short test, which proves the key reversible, never a
game's step.

## Testing (D314)

**The least environment that proves the part**, a `housing` fixture:
`records` (`clinic`, the core and housing loaded), `pms`, `ward`, with
the bastion: four nodes, about 0.8 CPU and 0.75G reserved, one host.

| Check | How | Time |
|---|---|---|
| The load | every core stay current at T0 has one open placement, none open on an ended stay, no unit holding two, no stay of the year left unplaced; sizes and load time measured | a few minutes |
| The board | `ward.board` reading one row per unit, an occupied unit's carrying its animal, no owner and no identifier; its calls about 64 a minute in `pg_stat_statements`, from `ward` | 10 minutes |
| Placement and release | the fixture raises `stays.admit` and `stays.discharge` on `pms` (its profile layer, D264), T0 placed at 10:00 for the discharges: a new stay placed within minutes, an ended one released and its unit disinfected within the hour | 25 minutes |
| The care log | T0 just before 17:00: the round's feedings recorded, a nil-by-mouth animal skipped, about 20 events an hour | 20 minutes |
| T150 (s9, D325) | *present*: the excess calls and the unit's parameter, logged for `vet_display` alone; *reported*: the chain read from the unit's parameter to the display's serial and the animal, the answer key's criteria; *cleared*: the test itself switching the display's key off in the profile layer (D264), the calls back to 64 a minute, proving the key reversible (a test step, never the GM's in a game) | 15 minutes |

**As built** (chunk 14, D417): the shift moves whole hours, so "T0 at
10:00" is placed within 10:00–10:59 local and "just before 17:00"
within 16:00–16:59 (runs at 10:04 and 16:48); the place run 39 of 39
checks in 19.4 minutes, the care run 40 of 40 in 22.3. "Its unit
disinfected within the hour" is not shown for a unit released live:
`ward.disinfect` takes a unit `to-clean` for 30 minutes or more, and
the run stops after the ward's first call, about 15 minutes after T0, so
it shows the disinfection of units the history released before T0, the
live one left to the whole clinic's run (a test limit, not a design
change). The fixture renders its hand-over
at least nine hours out, past the eight-hour aging floor, at the
designed 14:00 scenario time; the test runs its checks long before it.

**Only the whole clinic shows**, in the proof in play: the ward service
beside every other producer on `records`, its reads among the core's and
the purposes', the standby replaying housing's rows; if O189 is
accepted, the occupancy measure's first feeder only with T0 placed
before 00:30.

**Unproven in v0.5**, the major test's before the v1.0 tag: the care log
and the board's cost over an aging of days; T151's dead rows over hours;
T150 found across a hand-over; the night checks of T166 over a night.

## Nodes and capacity

| Node | Brick | Scope | CPU | Memory | Disk | Host |
|---|---|---|---|---|---|---|
| `ward`, the ward service (D287) | `scheduler` | the players' | 0.1 | 64M | 128M | armenelos (light enough for the VPS if CPU there allows) |

One node, the [tally](clinic-capacity.md)'s estimate unchanged. On
`records`: about 0.14 million rows and 17 MB more in `clinic` (D417), within
its 2.25G; about one board read a second and 540 rows a day, a few
hundredths of its 0.5 CPU; four pooled sessions and two for the writes.
No database node, no exporter.

## Loading

`gmctl load-data` runs housing's `schema.sql` then `load.sql` into
`clinic` on `records` as `postgres`, after the core's schema (the same
database), its load computing the core's stays, species, infectious
alerts and staff by the core's documented functions, never reading the
core's tables (D249, D322): explicit ids for the units and displays,
the history's ids in time order, each sequence set after its range; the
shift variables need nothing of housing's own, every time following the
core's shifted stays. The loader refuses an `at:` other than the core's
database (`lands_with: vet-core`, D322). The load's sessions unseen (D265). About 0.14 million rows and 17 MB,
in about 7.5 s after the core's 92 to 96 s (7.4 s at offset +2, 7.6 s
at 0, `postgres` 0.5.0 in a throwaway container); through `load-data`
on Swarm, the core and the coherence check included, 102 to 122 s
(D417). The build checks that no
stay of the year finds its section without a fitting unit, and fails if
one does; the GM's post-load coherence check then reads every placement
on a real stay and every current stay placed (D322).

## Questions for the owner

**Ruled on 2026-11-03** (D318): the owner, "i agree with the
recommendations as a whole", so each is closed as recommended, except
O184's load: the tables stay in `clinic`, declared `lands_with:
vet-core`, and the load computes the core's stays by functions (D322).
Kept as the record of what was asked.

- **O180 (step 1)**: the brief above, proposed, for him to write or
  correct.
- **O181**: housing in all three sections, the domestic section's
  kennels and cages included. Recommended: yes.
- **O182**: a display on each of the 64 units, refreshing once a minute
  through the ward service. Recommended: yes.
- **O183**: the display shows the animal, its alerts, plan, the day's
  doses and care, never the owner; it records care only, never a dose.
  Recommended: yes.
- **O184**: housing's tables in `clinic` beside the core, never an
  instance of their own, its load reading the core's stays in place.
  Recommended: yes, the ward service's one statement needs it.
- **O185**: a year of placements and care log, about 0.16 million rows.
  Recommended: yes.
- **O186**: no reservation of units; scheduling never books a box.
  Recommended: yes, in v0.5.
- **O187 (step 4, optional)**: the eight plausibility points.
- **O188 (step 5)**: the eight rules, with their game values.
  Recommended: as drafted.
- **O189 (step 7)**: no purpose of housing's own; occupancy added to the
  head office's monthly figures. Recommended: yes.
- **O190 (step 9)**: this page approved with v0.5's master spec.

## Changes needed in shared pages

Applied on 2026-11-03 in the fold-in (D318, D324, D325), with these
differences: the core's "Where the parts press" row says the part's
load computes the stays by functions and its roles read in place while
running (D322); the core documents the stays, species and infectious
alerts as functions of their ids; the staff are the core's layout
(D324); item 7 is replaced by the composition section, procedure 10
(D322); T150's check is judged on the report (D325).

1. **[vet-core-domain.md](vet-core-domain.md)**:
   - "Application roles and grants", the `vet_display` row: Reads
     becomes "the view `animal_board`; where `vet-housing` lands in
     `clinic`, its view `housing_unit_board` too, granted by that part's
     schema (D287)".
   - The same table, the `vet_reports` row: Reads becomes "every table,
     those of a part landing in `clinic` included (`vet-housing`'s,
     granted by its schema)".
   - "Where the parts press on the core", the `vet-housing` row becomes:
     "the hospital stay a unit holds, by id, with its section, its
     admission and its end (D278); the animal's species, so a unit fits
     it; current `infectious` alerts, so the animal goes to isolation;
     staff by kind (nurses, carers); what a display shows, through
     `animal_board`; the administrations, so the care log never records
     a dose (vet-housing T165). Read in place: the part lands in
     `clinic` (vet-housing O184), its roles' column grants on `stays`,
     `animals`, `alerts` and `staff` given by its schema."
   - "The applications and their nodes", the `pms` row: "it also carries
     `vet-housing`'s fragments on a connection `housing`, as
     `housing_app`".
   - The stays' section mix, stated in step 6 and the GM notes: at any
     time about 14 horses, 6 farm animals and 20 domestic animals of the
     40 (housing's units are sized on it), so that the core's
     history never holds more current stays in a section than its units
     in service: 21 horse units, 10 farm units, 31 domestic units, species
     fitting.
   - "Traps (step 8)": the core's `animal_board` also bitten by T155,
     its `stays` by T157 and T161 (vet-housing).
2. **[clinic-capacity.md](clinic-capacity.md)**, "The whole clinic",
   the `vet-housing` row: "the ward service, `ward`, a scheduler node
   (D287), 0.1 CPU, 64M, 128M of disk, armenelos; its tables in `clinic`
   on `records`, about 0.16 million rows and 50 MB, about one board read
   a second" (1 node, the estimate confirmed).
3. **[clinic-purposes.md](clinic-purposes.md)**, if O189 is accepted:
   section 13, `vet-head-office-figures` fits housing too; its feeder
   adds the units occupied and in service per section at midnight, read
   from `housing_units` and `housing_placements` on the standby; HO1's
   witness gains about 40 occupied units a day; its candidate faults
   gain "out-of-service units counted as available" (T171). Section 2's
   table: "Fits" for 9 becomes core, lab, housing. "The roles the
   purposes add": `vet_reports` on the standby reads housing's tables.
4. **[clinic-traps.md](clinic-traps.md)**: a section for `vet-housing`
   pointing at this page's T150–T171 and its four false alarms (or the
   tables copied), the status line naming the part.
5. **[clinic-test-selection.md](clinic-test-selection.md)**: T150 in
   place of s9 (T60, the critical calls' watch as superuser), class M,
   so the mix stays one D, two V, seven M. Reason: D287 is the owner's
   own description of how a faulty display is found, the many-small-
   consumers case nothing else in the ten touches; s9 adapts an existing
   catalogue fault (`security-crontab-superuser`) to `pg_cron`, which
   v0.4 already used on a database node, so it proves least that is
   new. The `housing` fixture joins the table (`records`, `pms`, `ward`;
   T0 any; T150); the `lab` fixture keeps s10 alone; the proof in play
   reads T150 at once. If the owner prefers to keep s9, T150 stays a
   trap for the GM, and the ward service is still proven by the build's
   board check (Testing).
6. **[producer-profiles.md](producer-profiles.md)**, "Applied at the
   parts' profile steps": friction 9 applied in
   [vet-housing-domain.md](vet-housing-domain.md) (the ward service
   `ward`, its pool of four, `ward.board`); friction 11's housing figure
   confirmed, about 520 care events a day.
7. **[domain-procedure.md](domain-procedure.md)** section 4, if O184 is
   accepted: "A part may require its core's database (`vet-housing`,
   whose ward service joins its units to the core's board in one
   statement); its load then reads the core's tables in place rather
   than computing the keys." **[formats.md](../../formats.md)** and
   O111: `domain.yaml` gains a key saying so (for instance
   `lands_with: vet-core`), the loader refusing a scenario whose `at:`
   places the part elsewhere.
8. **[README.md](README.md)**, "Next steps": `vet-housing` through step
   8, its questions O180–O190.

## Open points

- **O180–O190**: the owner's checkpoints above.
- **O111**: the domain format, finalised in v0.5's master spec (D291);
  item 7 of the changes feeds it, with the composition rules (D322,
  [procedure](domain-procedure.md) 10).
- The EU sources in "Regulations" were checked on 2026-11-03.
