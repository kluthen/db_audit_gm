# The vet-core domain: GM notes

The medical record of one centre of Aldermoor Veterinary Hospitals, a
regional franchise of three national centres and three abroad (v0.5
master spec 9.1, 9.2; [vet-core-domain.md](../../../specs/versions/v0.5/vet-core-domain.md)):
the business, its keys, its data, who may touch what, and the traps it
holds. A design-time source: copy its files into a scenario and adapt
them there; the domain itself never changes for a scenario. The core is
the system of record for owners and animals, and the keys every part
shares; its five parts (`vet-lab`, `vet-scheduling`, `vet-housing`,
`vet-machinery`, `vet-portal`) compute those keys from the functions
below and never read its database.

| File | Copied to | What |
|---|---|---|
| [`data/schema.sql`](../data/schema.sql) | loaded by `gmctl load-data` into the scenario's `domains:` `at:` database (`clinic` on `records`) | roles, tables, view, indexes, grants; `CONNECT` by name |
| [`data/keys.sql`](../data/keys.sql) | streamed by `load-data` ahead of the core's load, every part's load, every partner `data.sql` and `derive.sql` | the eighteen key functions, `pg_temp.core_*` ("Core keys", below) |
| [`data/load.sql`](../data/load.sql) | after `schema.sql`, in the same database | last night's backup: a year of history, computed from the key functions |
| [`data/classification.yaml`](../data/classification.yaml) | where `governance.classification` names it | the class of every column |
| [`data/register.yaml`](../data/register.yaml) | the scenario's data register (chunks 17, 27) | seven processing activities, every table in one |
| [`data/governance.yaml`](../data/governance.yaml), [`policy.md`](policy.md) | the scenario's `governance:` and `player/data-policy.md` | the default policy's eleven rules, and where each class may live |
| [`producers/pms/`](../producers/pms/) | the practice software's node (`nodes/pms/`) | `queries.yaml`, `schedule.yaml`, `jobs.yaml` |
| [`producers/api/clinic-api/`](../producers/api/clinic-api/) | the lookup API's node (`nodes/clinic-api/`) | `api.yaml`, `routes/`, `db/` |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | read by compose | the variant's scale, tags and parts |

## The business

The centre (site 1, `ALD-N`) has three sections, horse, farm and
domestic, about 85 staff of whom 30 are vets, and sees about 85
consultations a day: 60 scheduled, 12 on the wards, 10 emergencies and 3
herd visits. It keeps about 40 animals in hospital (14 horses, 6 farm
animals, 20 domestic), admits 8 a day and discharges them late in the
morning. Weekdays run 08:00–20:00 with a morning peak and a late
afternoon one, Saturday mornings are domestic consultations, Sundays are
emergencies and the wards only; herd-health visits fall on Tuesday and
Thursday mornings. Requests go to the lab (analyses) and the imaging
service; prescriptions follow EU Regulation 2019/6, the food chain's
withdrawal periods included. The two other national centres (sites 2, 3)
and the three abroad (4–6) exchange examinations and transfers with it,
about one a day each way.

The centre sits in an unnamed EU member state whose codes are fictional:
`XA` (ISO 3166-1's user-assigned alpha-2) on ear tags, passports and
holdings, `941` (one of ISO 11784's user-assigned 900–998) on chips and
UELNs, `+999` on phones. Every name, e-mail (`first.last.<id>@example.net`)
and address is generated.

The clinic works in the customer's time zone, UTC plus the game's shift,
a fixed `Etc/GMT` offset. The database, its logs and its clocks stay in
UTC; the zone lives in `business_settings`, written at load from
`load-data`'s `customer_timezone` and `customer_utc_offset`.

## Core keys

The parts' loads, the partners' `data.sql` and every derivation compute
the core's ids, and what hangs off them, by these functions, never by
reading `clinic` (D249, D302, D322; capture W2 items 3 and 4). The text
of each function is [`data/keys.sql`](../data/keys.sql); this section is
its reading, the formula each implements, so that a GM can answer
"which animal is request 4 711's?" with a `SELECT`, and a part's author
knows what the core guarantees. Where the two differ, `keys.sql` is
right and this section is the bug.

**Calling them.** `gmctl load-data` streams `keys.sql` into each load's
session; the functions live in `pg_temp` and vanish with it, so nothing
reaches the catalog the players read. To use them by hand, open a `psql`
session on any database as `postgres`, run `\i keys.sql`, then for
instance:

```sql
SELECT * FROM pg_temp.core_request(4711, '2026-11-04T10:00Z', 2);
```

**Signatures** (D379). An id function takes `(n integer)`; a function
computing a time takes `(n integer, load_epoch timestamptz, utc_offset
integer)`: `load_epoch` is the run's psql variable (the load's "now",
T0, to the minute), `utc_offset` is `customer_utc_offset` in hours. Every
function is `IMMUTABLE`, a pure function of its arguments, and returns
no row for an id outside its range or not yet existing at `load_epoch`.
A part's load passes `:'load_epoch'` and `:customer_utc_offset`, never
`now()`: the parts load minutes apart, and a stay computed at two
moments would disagree with itself.

**The contract is the eighteen `pg_temp.core_*` functions.** The
`pg_temp.vc_*` functions beside them are their shared formulas (a hash,
the calendar, the rota's duties, a vet's or a patient's pick): internal,
free to change while the eighteen return the same rows. A part calls
only the eighteen. `pg_temp.core_*` is reserved to the core (W2 item 0).

### The ranges

The load writes these ids; each sequence resumes after its range, so an
id created during the game is above it and never meets a part's load
(D276). "Sparse" ranges hold fewer ids than their span: the ids are the
function's arguments, and an argument whose function returns no row has
no row in the table.

| Key | Range | Layout |
|---|---|---|
| `sites.id` | 1–6 | 1 the centre (`own`, `ALD-N`), 2–3 the other national centres (`centre`), 4–6 abroad (Liège, Aachen, Luxembourg) |
| `sections.id` | 1–3 | 1 horse, 2 farm, 3 domestic, all site 1's |
| `staff.id` | 1–85 | `core_staff`: 1–10 horse vets, 11–17 farm vets, 18–25 domestic vets; 26–28 imaging vets; 29–51 the sections' nurses and technicians; 52–55 radiographers, 56 the biomedical engineer; 57–66 carers and grooms; 67–70 reception; 71–78 the lab's technicians, 79–80 its clinical pathologists; 81–85 instructors |
| `owners.id` | 1–10 000 | 1 the clinic (the teaching animals' owner); 2–201 holdings (herd `h`'s keeper is owner `h + 1`); 202–301 stables, 302–901 horse owners; 902–10 000 pet owners, 6 001–10 000 registered during the year with their first animal |
| `herds.id` | 1–200 | kept by owner `h + 1`; cattle 1–120 (dairy 1–80), sheep 121–170, goats 171–200 |
| `animals.id` | 1–17 000 | 1–14 600 domestic (1–12 the teaching dogs), 14 601–16 000 horses (14 601–14 608 the teaching horses), 16 001–17 000 farm animals in herd `1 + (id − 16 001) mod 200`; the teaching animals are owned by the clinic and are never patients |
| `referring_practices.id` | 1–400 | |
| `referring_vets.id` | 1–800 | two a practice: `core_referring_practice(v) = (v + 1) / 2` |
| `medicines.id` | 1–400 | 40 products, ten presentations each: `id = 10 × (product − 1) + presentation` |
| `consultations.id` | 1–25 000, sparse | in start order over the year; `core_consultation` |
| `referrals.id` | within 1–25 000, sparse | a referral's id is its first consultation's (`core_consultation`'s `referral_id`) |
| `requests.id` | 1–17 000, sparse | in their consultation's order; `core_request` |
| `stays.id` | 1–2 500, sparse | in admission order; `core_stay` |
| `exchanges.id` | 1–700, sparse | in blocks of seven around the transfers; `core_exchange` |
| `prescriptions.id` | 1–15 000 | in issue order; the load's, no function |
| `administrations.id` | 1–70 000 | in schedule order; the load's, no function |
| the others | as loaded | `diagnoses`, `procedures`, `alerts`, `medicine_batches`, `prescription_lines`, `dispensings`: in their parent's order, no part reads them |

### The calendar (`vc_cal`, `vc_before`)

The history covers **53 local weeks**, Monday to Sunday, the last the
week of `load_epoch`, cut at `load_epoch`: it starts at `S`, local Monday
00:00 52 weeks before T0's week (`vc_start`). Each weekly volume ramps
linearly from 0.6 of today's rate in week 0 to 1.0 in week 52 (D279), so
a stream of weekly base `b` has

    vc_weeks(w, b) = floor(b × (0.6 w + w (w − 1) / 260))

events before week `w`. Event `n` (1, 2, … in time order) falls in the
week `w` where `vc_weeks(w) < n ≤ vc_weeks(w + 1)`, at the quantile
`q = (n − vc_weeks(w) − 0.5) / (that week's count)` of its stream's
**hour-of-week shape** (168 cumulative fractions, linear inside the
hour), and is null at or after `load_epoch`. `vc_before(t)` is the
inverse: how many events fall before local time `t`, with no scan.
Consultations have `b = 589` (84 a day at 1.0), stays `b = 58`.

Every draw is `vc_u(x, salt) = (hashint8extended(x, salt) & 2³¹−1) / 2³¹`,
uniform in [0, 1), never `random()`; each formula below names its
salts (`u_k(x)` for `vc_u(x, k)`).

**The shapes** (`vc_rate`, events an hour at rate 1.0, the producer
profiles' rates, D304), local weekday and hour:

| Stream | Hours |
|---|---|
| scheduled, domestic | 78 a weekday × 75 %, 08:00–19:59, the late afternoon peak (weights 0.5 0.6 0.8 0.8 0.4 0.6 1.0 1.0 1.2 1.4 1.4 0.6 from 08:00); 30 on Saturday 08:00–12:59; none on Sunday |
| scheduled, horse and farm | 78 a weekday × 18 % and × 7 %, the morning (1.0 1.2 1.2 1.0 0.5 0 0.4 0.3 from 08:00) |
| emergency | 10 a day, every day, 0.8 before 08:00, 1.1 to 21:59, 0.9 after: a third at night |
| in-hospital | 12 a day on the rounds, 09:00–11:59, and 16:00–17:59 at half |
| herd visit | 2 an hour Tuesday and Thursday 08:00–12:59 |
| stay (admissions) | around the clock: 0.8 at night, 1.1 by day, 0.9 late |

A consultation's shape is the sum of the first five.

### `core_staff(n)`

Returns `kind`, `section_id`, `specialty` for staff 1–85 (D324, D327):

| Ids | Kind | Section | Specialty |
|---|---|---|---|
| 1–10 | `vet` | 1 | surgery, internal medicine, surgery, anaesthesia, reproduction, internal medicine, surgery, reproduction, internal medicine, anaesthesia |
| 11–17 | `vet` | 2 | herd health, herd health, surgery, reproduction, herd health, internal medicine, reproduction |
| 18–25 | `vet` | 3 | internal medicine, surgery, emergency and critical care, anaesthesia, surgery, internal medicine, emergency and critical care, dermatology |
| 26–28 | `vet` | | diagnostic imaging |
| 29–51 | `technician` when `n mod 3 = 0`, else `nurse` | 29–36 horse, 37–42 farm, 43–51 domestic | |
| 52–55 | `technician` | | radiography |
| 56 | `technician` | | biomedical engineering |
| 57–66 | `carer` | 57–60 horse, 61–62 farm, 63–66 domestic | |
| 67–70 | `reception` | | |
| 71–78 | `lab` | | |
| 79–80 | `vet` | | clinical pathology |
| 81–85 | `instructor` | | teaching |

### The rota's pattern: `core_shifts(n, day, utc_offset)`

Returns staff `n`'s shifts **starting on local day `day`**: `kind`
(`day`, `late`, `night`, `on-call`), `starts_at`, `ends_at` (UTC), and
`absence`, null or `leave`, `training`, `absent` when one of the
history's absences covers it. It is `vet-scheduling`'s rota (step 6,
O175, D339): that part's load writes `sched_shifts` from the rows with
no absence and `sched_absences` from the others; its
`sched.rota.publish` carries the same pattern, without the history's
absences, in its own statement: **the two texts are one formula**, and
a change to one is a change to both.

With `dn = day − 2000-01-03` (a Monday), `wk = dn / 7`, `dow = dn mod 7
+ 1` (1 Monday … 7 Sunday):

- **The night vet**, one a night over the 25 section vets, 20:00–08:00:
  `vc_night_vet(day) = 1 + dn mod 25`.
- **The section vets** 1–25, a `day` shift Monday to Friday, four
  weekdays of five (off when `(n + wk) mod 5 = dow − 1`), never on the
  day of their night or the day after: domestic vets of odd id (19, 21,
  23, 25) 10:00–20:00, the others 08:00–18:00.
- **The weekend** (`vc_weekend_vets`): one duty vet a section, Saturday
  and Sunday 08:00–20:00 (horse the first of `1 + (wk + g) mod 10`, farm
  of `11 + (wk + g) mod 7`, domestic of `18 + (wk + 3 + g) mod 8`, for
  `g = 0, 1, …`; D384), and Saturday's two domestic consulting vets 08:00–13:00
  (the first two of `18 + (2 wk + g) mod 8` other than the domestic duty
  vet), each skipping the vets resting from Friday's, Saturday's or
  Sunday's night.
- **On call**, 20:00–08:00 every night: a surgeon, the first of 1, 3, 7,
  13, 19, 22 in the order `(o + dn) mod 6` (`o` its place in that list)
  that is not the night vet, and an anaesthetist, likewise of 4, 10, 21
  by `(o + dn) mod 3`.
- **Imaging**: vets 26–28 and radiographers 52–55 a `day` 08:00–18:00
  four weekdays of five; their own on-call every night 18:00–08:00
  (vet `26 + dn mod 3`, radiographer `52 + dn mod 4`) and at the weekend
  08:00–18:00 (`26 + wk mod 3`, `52 + wk mod 4`).
- **The biomedical engineer** 56: Monday to Friday 08:00–16:30.
- **Nurses, technicians, carers** (29–51, 57–66): a four-week cycle by
  `(n + wk) mod 4` (D388): 0 `day` Monday and Tuesday, `night` Thursday
  to Sunday; 1 `night` Monday to Wednesday, `late` Saturday and Sunday;
  2 `late` Monday to Friday; 3 `day` Wednesday to Sunday (day
  07:00–15:30, late 13:30–22:00, night 21:30–07:30). One person in each
  phase holds every shift of every day, and each section's nurses and
  technicians (8, 6 and 9, consecutive ids) cover every phase: 47.25
  hours a week on average, 57 at most, every rest at least 11 hours,
  a weekly rest of 24 hours in every week. The carers follow the same
  cycle as far as their number goes (two on the farm cover two phases).
- **Reception** 67–70: Monday to Saturday, five days of six (off when
  `dow = (n + wk) mod 6 + 1`); weekdays 08:00–16:00 when `n + dn` is
  even, else 11:00–19:00; Saturday 08:00–12:30.
- **The lab** 71–78: the bench's hours, Monday to Saturday five days of
  six (as reception), a `day` week 07:00–15:00 when `n + wk` is even,
  else a `late` week 13:00–21:00; on-call every night 21:00–07:00
  (`71 + dn mod 8`) and Sunday 07:00–21:00 (`71 + wk mod 8`).
- **Clinical pathologists and instructors** (79–80, 81–85): 08:30–17:00,
  four weekdays of five.
- **The history's absences** (`vc_absence`, D388), on weekday `day`
  and `late` shifts only, so the nights and the weekend's cover are never
  short; periods of one day to two weeks, by hashes of the person and the
  week `w`: a fortnight's leave starting in week `w` when `u₁₄(100 000 n +
  w) < 1/52`, a week's when `u₁₁ < 0.0385`, one or two days' when `u₁₅ <
  0.067` (the day `u₁₆`, the length `u₁₇`); then a day's `training` (`u₁₂
  < 0.01`) or one to three days `absent` (`u₁₃ < 0.01`). Nurses,
  technicians and carers take their fortnights and weeks from their
  `late` week (phase 2) at four times the rate and their short leave at
  twice. At the reference T0: about 630 periods a year, nine in ten
  leave, about 21 leave shifts a head (25 for the nursing staff), so about
  five weeks; the absences leave a weekday day or late shift of a
  section without its nurse about 150 times a year (the pattern holds it,
  the absence takes it).

**A consultation's vet** (`vc_vet_at(section, t, utc_offset, salt)`) is
the same rules in closed form for the section vets at one local instant:
the vets 1–25 on a `day` or `night` shift at `t` with no absence, the
weekend's duty and Saturday's consulting vets included, on-call
excluded; among them one of the section, the first by
`u₂₁(32 salt + v)`; else any section vet on shift, by `u₂₂`; else the
night vet. `core_consultation` passes its own id as the salt.

### Animals

**`core_species(n)`**: 1–12 `dog`; 13–14 600 by `u₆₁(n)`: `dog` below
0.56, `cat` below 0.95, `rabbit` below 0.98, else `ferret`; 14 601–16 000
`horse`; 16 001–17 000 by the herd `h = 1 + (n − 16 001) mod 200`:
`cattle` for `h ≤ 120`, `sheep` to 170, `goat` above. At load: 8 105
dogs, 5 762 cats, 424 rabbits, 309 ferrets, 1 400 horses, 600 cattle,
250 sheep, 150 goats.

**The identifiers** (D379), each an affine bijection of the id, so
unique, and null where the animal has none:

| Function | Value | Who carries one |
|---|---|---|
| `core_microchip(n)` | `'941' ‖ lpad((7 919 813 n + 104 729) mod 10¹², 12)` | every animal 1–16 000 but two rabbits in three (`u₆₂(n) < 2/3`); no farm animal |
| `core_ueln(n)` | `'941001' ‖ lpad((7 919 n + 1 009) mod 10⁹, 9)` | horses |
| `core_passport(n)` | `'XA' ‖ lpad((104 723 n + 7) mod 10¹⁰, 10)` | horses |
| `core_ear_tag(n)` | `'XA' ‖ lpad((9 973 n + 31) mod 10¹², 12)` | farm animals |
| `core_holding(h)` | `'XA' ‖ lpad(7 883 h + 100 003, 9)` | herds 1–200 |

The functions give the identifier as **the parts hold it**: the dozen
mistyped chips (trap T13) are the core's load's own swap, never the
functions'.

**A section's patients** (`vc_pool`): horses 14 609–16 000, farm
16 001–17 000, domestic 13–14 600 (the teaching animals left out); the
first 928, 667 and 9 725 of each registered before the history, the
rest during the year in id order.

**`core_animal(n, load_epoch, utc_offset)`** returns `species`,
`breed`, `sex`, `born_on`, `name`, `food_chain`,
`food_chain_excluded_on`, `food_chain_excluded_by`, `herd_id`,
`registered_at`:

- `registered_at` (`vc_registered`): the teaching animals 800 days
  before `S`; a patient of the pre-history 30 to 2 530 days before `S`
  (`u₆₃`); one of the year at its place in id order on the ramp
  (`vc_ramp`), Monday to Saturday, 08:00–19:00 (`u₆₄`), about 20 a day
  at 1.0; never later than 10 minutes before T0;
- `breed` from a short list per species by `u₆₅` (cattle, sheep and
  goats by herd: dairy herds Holstein, Montbéliarde, Jersey); `sex`
  female when `u₆₆ < 0.5`, or `< 0.92` for dairy cattle and goats;
  `born_on` before registration (`u₆₇`); `name` from 30 pet names
  (`u₆₈`), a farm animal's a name and its ear tag's last four digits;
- `food_chain`: domestic `not-applicable`; farm `food-producing`; a
  horse `excluded` when a teaching horse or `u₆₉ < 0.6`, else
  `food-producing`; an exclusion dated within 200 days of registration
  (`u₇₀`), before T0, signed by horse vet `1 + n mod 10` when it falls
  in the year (null before: signed elsewhere);
- `herd_id` for farm animals.

### Owners and ownerships

**`core_owner(n, load_epoch, utc_offset)`** returns `kind`, `name`,
`family_name`, `email`, `phone`, `registered_at`, never the address:
owner 1 the clinic ("Aldermoor Veterinary Hospitals",
`records.1@example.net`); 2–201 `holding`, "<Family> Farm"; 202–301
`stable`, "<Place>[ Livery] Stables"; 302–10 000 `person`, "<First>
<Family>" from 24 first names (`u₇₂`) and 30 family names (`u₇₃`),
`family_name` the surname (a stable's, holding's or the clinic's name
whole). E-mail `first.last.<id>@example.net` (or the farm's or stable's
own form); phone `+999 ` and 8 digits, `(7 907 n + 1 234 567) mod 10⁸`.
Registered with their first animal (owners 6 001–10 000: the domestic
animal `9 738 + floor((n − 6 001) × 4 863 / 4 000)`, five minutes before
it), else 2 540 to 3 600 days before `S` (`u₇₁`), before any of their
animals.

**`core_ownership(n, load_epoch, utc_offset)`** returns animal `n`'s
ownerships over the year, every row: `owner_id`, `role` (`owner`,
`keeper`), `from_at`, `until_at` (null while current):

- the first owner, from registration: the teaching animals owner 1; a
  farm animal its herd's holding, `2 + (n − 16 001) mod 200`; a horse
  `202 + 37 n mod 700`; a domestic animal registered during the year
  with a new owner that owner, else `902 + 31 n mod 5 099`;
- a horse of a person (owner ≥ 302) kept at stable `202 + n mod 100`
  when `u₇₇ < 0.5` (a `keeper` row beside the owner's);
- a sale for one horse or domestic animal in about sixteen (`u₇₅ <
  0.06`, registered more than 31 days before T0): at `registered_at +
  30 days + u₇₆ × (the rest of the year less a day)`, never after the
  animal's death; it ends the owner's and the keeper's rows and opens
  the buyer's (`202 + (53 n + 17) mod 700` for a horse, `902 + (47 n +
  3) mod 5 099` otherwise, the next id if that is the seller).

One current owner per animal, always. At the reference T0 (below):
17 962 owner rows, 608 keeper rows, 962 sales.

### Stays, their alerts, and deaths

**`core_stay(n, load_epoch, utc_offset)`**, stays 1–2 500 in admission
order (58 a week, about 8 a day at 1.0), returns `animal_id`,
`section_id`, `admitted_at`, `discharged_at` (null while current),
`outcome` (null while current), `transferred_to_site_id`:

- `admitted_at = vc_cal(n, 58, 'stay')`;
- the section (`vc_stay_place`, D386): in each block of 20 stays (`n /
  20`), seven horse, three farm and ten domestic places, shuffled by
  `u₉₁(32 × block + place)`;
- the animal: with `i` the stay's rank in its section (`block × places +`
  the stays of its section before it in the block), `lo + (7 919 i + 101
  × section) mod pre` over the section's pre-history patients: an affine
  bijection, so **an animal has at most one stay**; `vc_stay_at` is the
  inverse;
- the outcome (`vc_stay_outcome`, D386): in each block of 25 one
  `transferred`, at place `floor(25 u₉₂(n / 25))`, to site `2 + (n / 25)
  mod 5`, a day after admission plus the partner's answer (2–8 hours,
  `u₃₄(n)`) and 2–6 hours (`u₃₃`); in each block of 16 one `died`, at
  place `floor(16 u₉₃(n / 16))` unless transferred, 0.3 to 4.3 days after
  admission (`u₃₁`); else `discharged` 2.5 to 6.5 days after admission
  (`u₃₁`), at least two days, 10:00–13:00 (`u₃₂`).

A stay lasts at most seven days, so a section never holds more current
stays than its units in service (21 horse, 10 farm, 31 domestic, D318):
at the reference T0 at most 17, 9 and 23 at once over the year, 38
current at T0.

**`core_stay_alert(n, load_epoch, utc_offset)`**: one stay in ten
(`u₄₁ < 0.10`) carries an `infectious` alert, `from_at` 1 to 12 hours
after admission (`u₄₂`), `until_at` 1.5 to 4.5 days later (`u₄₃`) or the
stay's end, whichever first, null while current at T0; no row when none,
or when it would start after the stay or T0.

**`core_death(n, load_epoch, utc_offset)`** returns `died_at` and `how`
(`natural`, `euthanasia`) for an animal of the history that died:

- in hospital: the animal's stay, found by inverting `core_stay`'s
  bijection (the inverses of 7 919 modulo 928, 667 and 9 725 are 15,
  102 and 3 904) and `vc_stay_at`, when it ended `died`, at its end; euthanasia three in
  five (`u₃₅(stay)`);
- at home: an animal with no stay, `u₃₆ < 0.026`, at `S + vc_ramp(u₃₇) ×
  (T0 − S)`, at least 30 days after registration and before T0;
  euthanasia one in two (`u₃₉`).

The teaching animals never die.

### `core_consultation(n, load_epoch, utc_offset)`

Consultations 1–25 000 in start order, `b = 589`. Returns `kind`,
`section_id`, `vet_id`, `animal_id`, `herd_id`, `stay_id`, `referral_id`,
`started_at`, `closed_at`, `signed_at`, `booking_id`:

- `started_at = vc_cal(n, 589, 'consult')`; the kind and section drawn
  by `u₁(n) × (the hour's total rate)` among the streams' rates at that
  hour (scheduled domestic, horse, farm; emergency; in-hospital; herd
  visit); an emergency's section by `u₂`: domestic below 0.65, horse
  below 0.90, else farm;
- an `in-hospital` one is on a stay current at its start and admitted at
  least an hour before: the first of eight stays drawn (`u₃(8 n + g)`)
  among those admitted in the seven days before, by `vc_before`, else
  it becomes an `emergency`; its section and animal are the stay's;
- a `herd-visit` is on herd `1 + floor(200 u₅)`, no animal;
- any other's animal is `vc_patient`: the first of six drawn in the
  section's patients (`u₅₁(8 n + g)`) registered an hour before and
  alive at the start (no row when none);
- `vet_id = vc_vet_at(section, start, utc_offset, n)`: a vet on shift by
  the rota, never on an absence;
- `referral_id = n` for one scheduled consultation in about five
  (`u₇ < 0.21`) and one emergency in ten (`u₇ < 0.10`);
- `booking_id = n` when `scheduled` (D317), else null;
- `closed_at` 25 to 45 minutes after the start (`u₆`); `signed_at`
  within the day (`u₈`): closed 08:00–19:59, 0.5 to 3.5 hours later but
  by 21:00; closed at night, the morning after, 08:00–10:00; times at or
  after T0 null.

At the reference T0: 24 633 consultations, 70.7 % scheduled (54.1 %
domestic), 13.9 % in hospital, 12.1 % emergencies, 3.3 % herd visits;
4 034 carrying a referral.

### `core_request(n, load_epoch, utc_offset)` (D375)

Requests 1–17 000 in their consultation's order. Returns `kind`, `code`,
`consultation_id`, `animal_id`, `requested_by`, `requested_at`,
`priority`, `state`, `sent_at`, `resulted_at`, `cancelled_at`,
`withdrawal_ends_on`:

- **Which consultation** (D385, D386). In every block of 40
  consultation ids, 17 places write requests at their close, 27 requests
  a block: eleven places one, three two, two three, one four; the places
  (the 17 lowest `u₉₄(64 × block + place)`) and their counts (permuted by
  `u₉₅`) shuffled in each block. Request `n` is the `j`-th of its place's
  consultation in block `(n − 1) / 27`; no row when that consultation
  has no row or is not closed at T0.
- **Its animal**: the consultation's; for a herd visit the first alive
  and registered of five animals of the herd (`16 001 + (h − 1) + 200 k`,
  rotated by `u₈₂(c)`).
- **Its kind**: a one-request place is an `imaging` study when
  `u₈₁(c)` is below 0.395 domestic, 0.68 horse, 0.41 farm; every other
  request is an `analysis`, a consultation's analyses one lab order. So
  about four consultations in ten make requests, 0.675 each; three in
  ten a lab order of 1.83 tests; one in eight an imaging study, the
  imaging mix about 60 % domestic, 30 % horses, 10 % farm (at the
  reference T0: 42.5 %, 7 432 orders of 1.83, 3 033 studies, 59.5/29.3/11.2).
- **Its code**, from the parts' catalogues (D372):
  [the lab's tests](../../../specs/versions/v0.5/vet-lab-domain.md#the-test-catalogue-d372)
  and [the machinery's procedures](../../../specs/versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373),
  each code weighted for the section, a weighted draw **without
  replacement** within the consultation (the codes ordered by
  `ln(u₈₃(1 000 c + id)) / weight`, descending; the consultation's `k`-th
  imaging request takes the `k`-th imaging code, likewise the analyses),
  so a consultation's codes are distinct; an imaging study takes the
  first imaging code. Valid for the animal: the
  catalogue's species group (an imaging code 1–12 domestic, 13–27 horses
  and farm but 26, 27 horses only, 28–30 any, D373), its species and
  sex (milk culture and the milk inhibitor test on females); `MINH` only
  on a female cow or goat, routine and by day, whose herd had a herd visit
  on a local day at least 11 days before (`vc_herd_visit_on`, searching
  the 16 weeks before: each Tuesday and Thursday hour's consultation ids by
  `vc_before`, a herd visit where `u₁` passes the other streams' share and
  `1 + floor(200 u₅) = h`), the weights renormalised without it otherwise
  (D389). **Urgent** (an
  emergency's or a stay's) requests draw only in-house analyses of 4
  hours or less, and never imaging 26 or 27; an urgent horse's foot
  radiograph and tendon ultrasound weigh 10 and 7 more. **At night**
  (21:00–07:00, and Sundays) only the night-capable analyses
  (haematology, biochemistry, blood gases).
- `requested_by` the consultation's vet; `requested_at` its close;
  `priority` `urgent` for an `emergency` or `in-hospital` consultation,
  else `routine`.
- **Its state at T0** (`u₈₅(n)`): below 0.02 `cancelled` by the vet before
  sending (no `sent_at`, `cancelled_at` 2 to 10 minutes after the
  request, `u₈₈`); else of the last 24 hours `sent`; else below 0.04
  `cancelled` by the part after sending (`sent_at` set, `cancelled_at`
  within the first third of the turnaround); else `resulted`. Sent 1 to
  5 minutes after the request (`u₈₄`); resulted within the code's
  turnaround, `sent + tat × (0.4 + 0.5 u₈₆) + 5 to 20 minutes` (imaging
  urgent 18 hours, routine 72, a day more when that falls on a Sunday,
  D376), never later than 5 minutes before T0. None is `requested` at T0.
- `withdrawal_ends_on`, for the milk inhibitor test (`MINH`) only: the
  milk withdrawal end of the line it checks, ten days after that herd
  visit's day (three days' oxytetracycline and seven days' milk
  withdrawal), so before the request; the core's load writes the line on
  that visit's prescription ("What the load adds", below).

The parts fit their own times inside these: a lab release or an imaging
final report before `resulted_at` by the copying purpose's lag, within
the turnaround from `sent_at`; a part's cancellation before
`cancelled_at`. Only the sent requests reach a part's load. At the
reference T0: 16 617 requests, 13 584 analyses, 3 033 imaging; 22 milk
inhibitor tests.

### `core_exchange(n, load_epoch, utc_offset)` (D306)

Exchanges 1–700, in blocks of seven around the transfers. Returns
`direction`, `kind`, `site_id`, `animal_id`, `stay_id`, `exchange_key`,
`requested_at`, `sent_at`, `state`, `answer`, `accepted_for`,
`answered_at`, `reported_at`:

- block `k = (n − 1) / 7`, place `r = (n − 1) mod 7`; `r = 3` is the
  transfer of block `k`'s transferred stay (`vc_transfer_stay(k) = 25 k +
  floor(25 u₉₂(k))`, `out`, `transfer`), requested a day after the stay's
  admission, its site the stay's (`2 + k mod 5`), its animal the stay's;
  places 1, 5, and in even blocks 6, outbound examinations; the others
  inbound examinations (D390: no inbound transfer);
- **in `requested_at` order** (D390): the six examinations between two
  transfer requests (block `k`'s last three, block `k + 1`'s first three)
  are drawn in that interval's office hours (Monday to Friday
  08:00–18:00, `vc_om` and its inverse), the `s`-th in its sixth of the
  office time (`(s + 0.1 + 0.8 u₁₀₃) / 6`); an interval with no office
  time (a weekend between two transfers) holds none;
- an examination's partner site `2 + floor(5 u₁₀₁)`; an outbound one's
  animal `vc_patient` of a section drawn 60/30/10 (`u₁₀₉`); an inbound
  one has no registered animal (`partner_patient` only, the load's);
- `exchange_key = md5('vet-core-exchange:' ‖ n)::uuid`;
- sent 2 to 10 minutes after the request (outbound); answered 2 to 8
  hours later (a transfer's by the stay's `u₃₄`), declined one
  examination in ten (`u₁₀₂`); an accepted examination for 1 to 10 days
  after the answer, reported 1 to 3 days after that, 10:00–17:00; a
  transfer accepted for the answer's day;
- `state` at T0: `requested`, `sent` or `received` while unanswered,
  then `declined`, `accepted`, or `reported`.

At the reference T0: 664 exchanges loaded.

### `core_referring_practice(v)`

Referring vet `v`'s practice, two vets a practice: `(v + 1) / 2`, for
`v` 1–800 (D378). The core's `referring_vets.practice_id`;
`vet-scheduling`'s `sched_trainees` reads it.

### What the load adds (no function)

The core's own load writes beside the functions, and no part reads:

- **the dozen mistyped chips** (T13): twelve chipped dogs and cats
  registered before the history, the first twelve dogs and cats among ids
  `13 + 607 k`, their stored chip with two adjacent digits of the twelve
  swapped (the first differing pair from the `(4 + k mod 7)`-th); the
  parts' loads hold the function's value, so a
  lab order or a portal record matches no animal;
- **the milk inhibitor test's checked line** (D389): for each `MINH`
  request, on the prescription of the herd visit `vc_herd_visit_on`
  found, oxytetracycline 100 mg (medicine 31) for three days, meat 21 and
  milk 7 days, so the line's milk end is the request's
  `withdrawal_ends_on` (its own `withdrawal_ends_on`, the later meat end,
  24 days after); the load checks every one;
- the referrals, their dates and reasons; diagnoses, procedures,
  prescriptions and lines, administrations, dispensings, batches and the
  other alerts; the staff's names; owners' addresses; inbound
  exchanges' `partner_patient`, reasons and reports.

### The reference T0

The figures in this section are at `load_epoch` 2026-11-04 10:00Z (a
Wednesday), offset +2. Another T0 moves every event with it: the
history is the 53 weeks before it, and an id's row is a function of T0.
A part loaded at another `load_epoch` than the core's computes another
history: `load-data` passes one `load_epoch` to every file of a run.

### The catalogues' shares, as the load measures them

Measured at the reference T0 (the same at shift 0 within a tenth of a
point), against the two catalogues' draws ([vet-lab](../../../specs/versions/v0.5/vet-lab-domain.md#the-test-catalogue-d372),
[vet-machinery](../../../specs/versions/v0.5/vet-machinery-domain.md#the-procedure-catalogue-d372-d373)):

- **Analyses**: 13 584, 10 042 routine and 3 542 urgent. Every routine
  code is within 2.2 points of its weight in the domestic section, 3.0 on
  the farm and 4.7 with the horses: a consultation's codes are distinct,
  so the heaviest codes give way when an order has two or three tests
  (`CBC` 19.8 % against 22 domestic, 22.3 against 27 horse; `CHEMEQ` 15.2
  against 18), and the farm's cattle-only codes (`CALFD`, `HERDB`) and
  `MINH` (22 requests, 2.0 % against 5, D389) are renormalised away from
  sheep and goats. 9.2 % of the routine analyses go out, none of the
  urgent ones; of the 1 019 urgent analyses outside the bench's hours, none
  is a code that is not night-capable.
- **Imaging**: 3 033 studies, 59.5 % domestic, 29.3 % horses, 11.2 % farm.
  Routine: DX 44.7 %, US 31.2, CT 14.9, MR 7.0, NM 2.2; urgent: DX 50.5,
  US 32.4, CT 13.8, MR 3.3, none NM; overall DX 46.4, US 31.6, CT 14.6, MR
  6.0, NM 1.5.
- **Validity**, every check at zero: no urgent 26 or 27; no farm animal
  with a horse-only code, no domestic animal with a large or horse code, no
  large animal with a small one; `FELV` only cats, `VECT`, `DIARC` and
  `ACTHST` only dogs, `TT4` dogs and cats, the cattle codes only cattle,
  `MCULT` only farm females, `MINH` only food-producing cows and goats, the
  equine codes only horses; no urgent analysis sent out or above four
  hours; no code twice in a consultation.

## The data

At the reference T0 (`load_epoch` 2026-11-04 10:00Z, offset +2), counted
with `count(*)`:

| Table | Rows | Notes |
|---|---|---|
| `business_settings` | 1 | the customer's zone and offset, the company, retention five years |
| `sites`, `sections` | 6, 3 | site 1 the centre; sections 1 horse, 2 farm, 3 domestic |
| `staff` | 85 | `core_staff`'s layout; names and e-mails generated |
| `owners` | 10 000 | the clinic, 200 holdings, 100 stables, 9 699 people; address `XA` |
| `herds` | 200 | keeper `h + 1`, holding number `core_holding` |
| `animals` | 17 000 | 8 105 dogs, 5 762 cats, 424 rabbits, 309 ferrets, 1 400 horses, 600 cattle, 250 sheep, 150 goats; the dozen mistyped chips (T13) |
| `ownerships` | 18 569 | 17 962 owner rows, 608 keeper rows, 962 sales; one current owner per animal |
| `referring_practices`, `referring_vets` | 400, 800 | |
| `referrals` | 4 034 | received, accepted, closed by the vet's letter |
| `consultations` | 24 633 | 70.7 % scheduled, 13.9 % in hospital, 12.1 % emergencies, 3.3 % herd visits |
| `diagnoses`, `diagnosis_codes` | 29 486, 50 | a listed disease one in 250, never category A |
| `procedures` | 6 885 | three in ten closed consultations |
| `requests` | 16 617 | 13 584 analyses, 3 033 imaging studies; the last day's `sent` |
| `stays` | 2 421 | 38 current at T0 |
| `alerts` | 1 692 | allergies, dangerous, infectious (one stay in ten), other |
| `exchanges` | 664 | out and in, a few in flight |
| `medicines`, `medicine_batches` | 400, 699 | 40 products of ten presentations |
| `prescriptions` | 14 732 | 13 431 dispensed, 1 084 expired, 182 cancelled, 35 issued |
| `prescription_lines` | 38 597 | withdrawal periods and their end for food-producing animals |
| `administrations` | 61 241 | the ward lines' doses at their frequency; the next round's `scheduled` |
| `dispensings` | 25 020 | an outpatient's lines, to the owner or the herd's keeper |
| **Total** | **274 235** | 49 MB on disk |

`animal_board` (a view) is what a ward display reads: an animal's
identity, its current stay, its current alerts and today's doses, no
natural identifier and no owner (rule 10).

## The roles (vet-core-domain.md, "Application roles and grants")

| Role | Reads | Writes |
|---|---|---|
| `vet` | owns everything; no login | |
| `vet_app` | every table | owners, ownerships, animals, herds, referrals, consultations, diagnoses, procedures, requests, stays, alerts, exchanges, prescriptions and lines, administrations, dispensings; `USAGE` on `owners`' and `animals`' sequences (a new owner's e-mail and a new animal's identifiers are functions of the new id); never the reference tables |
| `vet_lookup` | `animals` without `status`, `died_at`, `death_kind`; `ownerships`; `owners`' `id`, `kind`, `name`; `stays`' `id`, `animal_id`, `section_id`, `admitted_at`, `discharged_at` | nothing |
| `vet_display` | `animal_board` (and `vet-housing`'s `housing_unit_board`, granted by that part) | nothing |
| `vet_reports` | every table, contacts included | nothing |

The login roles carry no password here: `load-data` sets each from its
secret. `CONNECT` on `clinic` is granted to them by name and revoked from
`PUBLIC`; a part landing in `clinic` grants its own roles in its schema.
The purposes' roles (`vet_interfaces`, the runners on `office`) are their
material.

## The classification

[`data/classification.yaml`](../data/classification.yaml) lists all 213
columns of the 25 tables and the view: 20 `personal` (the owners'
identity and contacts and `owners.id`, staff's and referring vets' id,
name and e-mail, an animal's natural identifiers and its id beside them,
the holding number and the herd's id, an inbound exchange's
`partner_patient`), 15 `customer-linked` (an animal's or a herd's id
elsewhere, `herds.keeper_owner_id`, `ownerships`' two ids,
`dispensings.owner_id`, `animal_board.animal_id`), the rest `internal`.
The scenario's `governance:` says where each class may live; the
domain's [`data/governance.yaml`](../data/governance.yaml) and
[`policy.md`](policy.md) are the default to copy. Every table is in one
of [`data/register.yaml`](../data/register.yaml)'s seven activities
(owners and animals, staff, referrals, the record, medicines, exchanges,
operations).

## The producers

**`pms`**, the practice-management software ([`producers/pms/`](../producers/pms/)),
on `clinic` as `vet_app`: 21 streams and two jobs, one key each in
`queries.yaml`, no builder. Volume streams: registrations (a new owner
with a first animal, 86 % domestic, 8 % horses, 6 % farm; an animal for an
existing owner), referrals received, emergencies, herd visits, ward
consultations, admissions (within the units in service, 21/10/31),
discharges (90 % discharged, 4 % transferred with an outbound transfer
exchange `requested`, 6 % died), alerts, ownership transfers, request
cancellations (`requested` only, D315), outbound exchanges. Work streams:
`consultations.close` writes what the history writes (one or two
diagnoses, a procedure in three in ten, a lab order in three in ten of 1.8
tests drawn by the catalogue's weights, valid for the species and sex,
urgent ones in-house and night-capable outside the bench's hours, an
imaging study in one in eight; a prescription on every ward round and 53 %
of the others, its lines, an outpatient's dispensed at once nine times in
ten), then signing, referrals accepted and closed, inbound exchanges
decided, examinations reported. Reads: `animals.file`, `wards.list`,
`requests.pending` (50 at most). Jobs: `administrations.round` at 02:00,
06:00 … 22:00 (a new ward line's first dose at the round after its issue,
every dose due given by a nurse of the section by a hash, one in a
hundred missed, then each line's next dose at its frequency, D393) and
`prescriptions.expire` at 00:15 (an antimicrobial past five days, the
others past their lines' days). A vet, nurse or carer is the section's,
picked by a parameter, not matched against the rota (D391). The scheduled
consultations have no stream: `vet-bookings-sync`'s check-in opens them
(D317). Every statement was run as `vet_app` on a load (chunk 9's SQL
checks).

**`clinic-api`**, the lookup API ([`producers/api/clinic-api/`](../producers/api/clinic-api/)),
an `api` node in the players' scope, only answering, as `vet_lookup`,
behind the credential `clinic_lookup` every caller of the estate sends:

| Endpoint | Answer |
|---|---|
| `GET /animals/{id}` | the animal: `id`, `species`, `breed`, `sex`, `born_on`, `name`, `food_chain`, `herd_id`, `microchip`, `ueln`, `passport_number`, `ear_tag`, `registered_at` (ISO 8601 UTC, `Z`); 404 `{"detail": "not found"}` |
| `GET /animals?microchip=` (or `ueln=`, `ear_tag=`) | a list, `[]` when none; anything but exactly one identifier 422 `{"detail": "exactly one of microchip, ueln or ear_tag"}` |
| `GET /animals/{id}/owner` | the current owner's `id`, `kind`, `name`, never a contact or a former owner; 404 |
| `GET /stays?current=true` | the stays not discharged: `stay_id`, `animal_id`, `section_id`, `admitted_at`, `name`, `species` (D319); without `current=true` 422 |

`statement_timeout` 5 s, a pool of four. Without the credential, 401.
Purpose 4's exchange endpoints come with that purpose (`vet_exchange`).
The fragments are written for the nodes `pms`, `records`, `clinic-api`
and the database `clinic`; rename them as the scenario does.

## The rules

The default policy's eleven rules ([`policy.md`](policy.md), D280):
prescriptions with Art 105(5)'s contents, an antimicrobial one valid five
days, the cascade's minimum withdrawals; the medicines register five
years; the controlled-drugs register ten; antimicrobial use recorded for
every species, the yearly report for the species due (cattle today); a
horse in the food chain unless excluded, the exclusion one-way, six
months' withdrawal for an essential substance; every food-producing
treatment's withdrawal end; notifiable diseases, category A at once;
records signed within a day; retention five years (medicines five,
controlled drugs ten); owners' data personal, least data per reader, none
in the logs; the portal's release rules.

## Growth

At intensity 1.0 the core gains about 760 rows and 450 updates a day,
about 0.25 MB with indexes before bloat, 30 rows an hour on average, 90 in
the busiest (a weekday 17:00–19:00 with a round), a Sunday a third of a
weekday. **Administrations**, measured on the history's last four weeks:
218.6 a day at shift 0 (T0 2026-03-18 15:37Z), 36 a round, against
spec-writer's estimate of about 210 (D393), the rounds uneven (the 14:00 and 02:00 rounds carry the ward
rounds' new lines, the 06:00 round the fewest); the live round continues
the same model (D393). Over an aging of eight to twenty-four hours the
core grows by a few hundred rows: its disk is never the problem, its
updates, dead rows and WAL are; with archiving failing, `pg_wal` keeps at
least 16 MB an hour.

## The traps

[clinic-traps.md](../../../specs/versions/v0.5/clinic-traps.md) lists
each with its witness and where it is fixed; those biting the core: on its
instance T1, T3, T5, T7, T9; in its data and identity T13 (the dozen
mistyped chips, planted by this load), T14 to T19; in its grants and views
T24 to T28 (`animal_board` with no identifier, `vet_lookup`'s column
grants); in replication and the archive T31 to T37; in its round trips T39
to T44, T54 to T56, T85; in its obligations T57 to T59; in its reports T64
to T74; in performance T79, T81 to T83. Four things the data holds on
purpose and a player may take for faults: `requests.state` `resulted` is
a part's fact copied back (two places for one fact); free text (findings,
alerts, a referral's reason) may name the owner; the history's volumes
ramp from 60 % a year ago (a step at T0 at another intensity is the
story's); the rota is a pattern, so a weekday shift may be a nurse short
on an absence (146 times a year). Selecting a game's faults is the GM's.

## Loading

`gmctl load-data` runs `schema.sql`, then `keys.sql` and `load.sql` in one
session into the `at:` database (`clinic`), as `postgres`, with
`customer_timezone`, `customer_utc_offset` and `load_epoch` set; the load
stops at once when one is missing or the zone is not UTC plus the offset,
and checks its own caps (prescriptions ≤ 15 000, administrations ≤ 70 000,
every `MINH` request's line) before it commits. Measured on `postgres`
0.5.0 in a throwaway container (2 GB, `fsync` off): **89 s** at offset +2
(T0 2026-11-04 10:00Z), **89 to 113 s** at offset 0 (T0 2026-03-18 15:37Z;
two runs), **49 MB**,
274 235 and 274 404 rows; most of it `core_consultation` (about 41 s) and
`core_request` (about 38 s), and every part's load calling them pays its
share. The fixture `tools/tests/fixtures/fixture-core/` loads it through
`load-data` on Swarm (its figure in its short test).
