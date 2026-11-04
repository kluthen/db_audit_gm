# The vet-machinery domain: GM notes

The machines of one centre of Aldermoor Veterinary Hospitals and their
three systems' databases (v0.5 master spec 9.6;
[vet-machinery-domain.md](../../../specs/versions/v0.5/vet-machinery-domain.md)):
the business, the data, who may touch what, the producer, the rules, the
traps, loading. A design-time source: a scenario composes it with
`vet-core` (`domains:`, `at:` a map) and the domain itself never changes
for a scenario. A part of `vet-core`: it computes the core's keys from
the core's functions ([vet-core's GM notes](../../vet-core/docs/gm.md),
"Core keys") and never reads `clinic`.

| File | Loaded or copied to | What |
|---|---|---|
| [`data/pacs/schema.sql`](../data/pacs/schema.sql), [`load.sql`](../data/pacs/load.sql) | `pacs`, by `gmctl load-data`, first | the part's roles (created here once), the imaging archive and its worklist |
| [`data/vitals/schema.sql`](../data/vitals/schema.sql), [`load.sql`](../data/vitals/load.sql) | `vitals`, second | the central station: census, sessions, raw vitals (daily partitions), chart, alarms |
| [`data/biomed/schema.sql`](../data/biomed/schema.sql), [`load.sql`](../data/biomed/load.sql) | `biomed`, third | the registry, maintenance, downtimes, logs (monthly partitions), readings (daily partitions), daily aggregates |
| [`data/cron.sql`](../data/cron.sql) | run by `load-data` on `machines` after the part's load, in its `cron.database_name` | the three partition jobs (D405) |
| [`data/coherence.yaml`](../data/coherence.yaml) | run by `load-data` after the loads | sessions on stays, the census, entries on requests, the window's row counts |
| [`data/classification.yaml`](../data/classification.yaml) | the scenario's classification, each key with its database | the class of every column |
| [`data/register.yaml`](../data/register.yaml) | the scenario's data register (chunks 17, 27) | five processing activities, every table in one |
| [`data/governance.yaml`](../data/governance.yaml), [`policy.md`](policy.md) | the scenario's `governance:` and `player/data-policy.md`, with the core's | the eleven rules, where each class may live |
| [`producers/equipment/`](../producers/equipment/) | the machines' node (`nodes/equipment/`), by `gmctl compose` | `queries.yaml`, `schedule.yaml`, `jobs.yaml`, `scripts/` |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | read by compose | the part's scale and purposes |

## The business

The centre's machine park, as its staff meet it. **Imaging**: each section
its machines (CT and a 1.5 T MRI for the domestic section; a large-bore CT,
a standing low-field MRI and a gamma camera for the horses; radiography
rooms and ultrasound, a portable radiography unit and a portable
ultrasound for the farm and the stables). A vet orders a study in a
consultation (the core's request, about one in five); purpose 13 puts it
on the PACS's worklist; a radiographer performs it on the machine its
procedure and the animal's section name; an imaging specialist reports
it; a night's urgent study gets the duty vet's preliminary at once and its
final the next morning. **Monitoring**: four anaesthesia monitors (two
small-animal theatres, the equine theatre, one MRI-compatible) and eight
intensive-care monitors (six domestic, two for horses and foals) feed the
central station; under anaesthesia the chart is every five minutes, in
intensive care every hour. **The lab's analysers**, machines 1–6: their
results are `vet-lab`'s; their telemetry and logs are here.
**Biomedical engineering** (staff 56, with the vendors' engineers) keeps
the registry, the service visits, QA tests, calibrations and downtimes, and
every machine's logs and telemetry.

Three vendors' systems share one PostgreSQL instance, `machines`: one
configuration, one superuser, one WAL stream. That is the consolidation's
realism cost and the source of its traps (T200–T202, T216). Hours:
imaging Monday to Friday 08:00–18:00 and Saturday morning, urgent around
the clock; reporting weekdays 08:30–18:00 and Saturday 09:00–12:00;
theatres weekdays 08:00–18:00, emergencies at night; the monitors and the
machines every hour of every day. Everything is in the customer's time
zone, a fixed offset; the databases and their clocks stay in UTC, each
database keeping its copy of the zone (`mach_pacs_settings`,
`mach_vitals_settings`, `mach_settings`).

## Core keys used

The part calls only the core's `pg_temp.core_*` functions, streamed by
`load-data` ahead of each of its three loads (it ships no `keys.sql` of
its own; its loads define their hash `pg_temp.m_u`, the core's formula
with the part's salts, 500 and up):

| Function | Where | What the part takes |
|---|---|---|
| `core_request(n)`, n 1–17 000 | `pacs` | the imaging requests the core sent (`sent_at` set): request, consultation, animal, requesting vet, code, priority, state, `sent_at`, `resulted_at`, `cancelled_at` |
| `core_animal(n)` | `pacs`, `vitals` | species, breed, sex, born on, name |
| `core_microchip(n)`, `core_ueln(n)`, `core_ear_tag(n)` | `pacs` | the natural identifiers as the parts hold them (never the core's dozen mistyped chips, T13) |
| `core_ownership(n)`, `core_owner(n)` | `pacs` | the owner at the identity's time: Responsible Person and the family name in Patient's Name |
| `core_stay(n)`, n 1–2 500 | `vitals` | stay, animal, section, admitted, discharged |

Staff ids follow the core's layout and its rota's published formulas
(no function call): radiographers 52–55 and imaging specialists 26–28 by a
hash in the imaging day, the weekend's by the week (`52 + wk mod 4`,
`26 + wk mod 3`), the night's on-call by the day it started (`52 + dn mod
4`, `26 + dn mod 3`); the biomedical engineer 56; nurses of the section
29–36 (horse), 37–42 (farm), 43–51 (domestic); anaesthetists 21
(domestic), 4 and 10 (horses and farm); the lab's technicians 71–78 on the
analysers' events. **A request's vet** (`requested_by`, and the
preliminary's author, the duty vet) is the core's consultation vet as
`core_request` returns it: the part copies it and depends on no
particular draw.

## The data

### Keys and their layout

| Key | Range | Layout |
|---|---|---|
| `mach_machines.id` | 1–28 | 1–2 haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6 coagulation (on call at night 1, 3, 5); 7 CT small animal, 8 CT large bore, 9 MRI 1.5 T (helium), 10 standing MRI (permanent magnet), 11 DR domestic, 12 DR horses, 13 portable DR (farm and stables), 14 ultrasound domestic, 15 portable ultrasound (horses and farm), 16 gamma camera (horses); 17–18 small-animal theatres, 19 equine theatre, 20 MRI-compatible; 21–26 intensive care domestic, 27–28 horses and foals. Bookable 7–16; ionising 7, 8, 11, 12, 13, 16; telemetry 1–10 and 16 |
| `mach_procedures.id` | 1–30 | the catalogue (D372, D373): 1–12 small, 13–25 large, 26 and 27 horses only, 28–30 any; each code's machine for a domestic, a horse and a farm animal |
| `mach_worklist.id` | 1–3 400 | the k-th imaging request the core sent, by `sent_at` then request id; accession `I-<request id>` |
| `mach_studies.id` | 1–3 464, then 3 465–3 470 | in acquisition order; 3 465–3 470 the six unmatched studies |
| `mach_series.id`, `mach_reports.id` | 1–8 000, 1–3 450 (sequences resume after the larger of these and the load) | in study order; reports in signing order |
| `mach_sessions.id` | 1–3 800 | in start order |
| `mach_alarms.id`, `mach_events.id`, `mach_maintenance.id`, `mach_downtimes.id` | as loaded | in time order |

### Each table's history

- **The worklist** (`pacs`): every imaging request the core sent has its
  entry, created at `sent_at`, its identity a minute later (the identity
  job's next run): `patient_id` `A-<animal>`, `patient_name`
  "family^name" (a holding's or stable's whole name as family), the
  species, breed, sex, born on, natural identifiers and the owner's name
  as Responsible Person, the owner at that time. A request the core
  resulted: the entry `completed`, its study acquired between the post and
  the final (urgent ones within the first fifth), the final signed 1 to 9
  minutes before the core's `resulted_at` (purpose 13 copies within ten
  minutes), so some finals fall outside reporting hours (the core's
  turnaround draws them); an urgent study's preliminary 10 to 60 minutes
  after it ends, by the requesting vet as duty vet. **One urgent night
  study in two** (sent 21:00–07:00, a hash) was typed on the modality 5
  to 30 minutes before its entry existed, then reconciled within the day
  by a radiographer (no accession as acquired). A request of the last day
  (`sent` in the core): urgent ones acquired 10 to 40 minutes after the
  post with their preliminary when T0 allows, routine ones on an
  imaging-day slot within two working days (`scheduled`, `in-progress` or
  `completed` and awaiting the final). A request the imaging team
  cancelled after sending: the entry `cancelled` 1 to 4 minutes before the
  core's `cancelled_at`, with a reason.
- **Studies, series, reports**: the radiographer on duty performs; an
  ionising study (CT, DX, NM) records a nurse of the animal's section as
  restrainer, a companion present in one in ten, and its exposure (kV and
  mAs, CT's DLP, NM's activity); images and size by modality (no pixel
  data). One final in about eighty-five gets an addendum 1 to 10 days
  later, superseding it, both kept. **The six unmatched studies**
  (3 465–3 470), one every two months at night on a radiography room,
  typed `patient_id`s naming no animal (above 17 000, or two digits
  swapped): domain data, a finding (false-alarm material).
- **Sessions** (`vitals`, D377): intensive care on the stays a hash picks
  (`m_u(stay, 541)` below 0.5 domestic, 0.25 horse; no farm stay), from
  the first census after admission, on the first free monitor of the group
  (21–26, 27–28), until the step-down (24 to 72 hours after admission,
  `m_u(stay, 542)`, `ended_by` `staff`) or the census after the stay ended
  (`census`); a pick with no free monitor gets none. Anaesthesia: about
  ten a weekday from 08:00, ramping from six a year ago, and one a night,
  each 90 minutes plus up to an hour, on a current stay with no open
  session picked by a hash, on 17 or 18 (domestic; 20 for one in eight, an
  MRI under anaesthesia) or 19 (horses and farm). At T0 a few intensive-care
  sessions are open, and an anaesthesia one on a weekday.
- **The raw vitals**: a row every 10 seconds per open session on the UTC
  minute's grid, the window only (yesterday 00:00 local to T0); each
  session's baselines by species, lower under anaesthesia, end-tidal CO2
  under anaesthesia only. **The chart**: every 5 minutes under
  anaesthesia and every hour in intensive care, for the whole year, each
  measure's mean about the same baselines at the interval's middle, its
  min and max a spread about it. **Alarms**: about one every two hours in
  intensive care and one every three under anaesthesia, four in five
  physiological, acknowledged within ten minutes by a nurse of the
  section, none after T0.
- **The census**: the core's stays current at T0 as the last census run
  (the five-minute tick before T0) saw them, and those that left in the
  window, marked left at the census after their discharge.
- **The registry** (`biomed`): the 28 machines in service; the
  analysers' monthly calibration (staff 56), imaging's quarterly vendor
  service (machines 7–10, 16, three to five hours down), each ionising
  machine's yearly QA test by the radiation protection expert (its
  `qa_due_on` twelve months later, none past at T0), the monitors' yearly
  check, two software updates a year on the big machines, fourteen
  repairs after a downtime of 2 to 30 hours.
- **The logs**: 250 events a day at 1.0, ramping from 0.6 a year ago,
  fewer at the weekend, 80 % of a weekday's in the imaging day; info
  80 %, warning 15 %, error 4.7 %, critical 0.3 % (acknowledged by staff
  56 within four hours, rule 7); an operator for imaging (52–55) and the
  analysers (71–78), never a name.
- **The telemetry**: a reading a minute per machine with telemetry over the
  window, its kind's channels (an analyser's temperature and reagent, a
  CT's tube heat, the 1.5 T MRI's helium, cold head and shield, the gamma
  camera's detector); **machine 10 reports a status row with no channel**
  (`{}`, a permanent magnet). `mach_readings_daily` holds each day of the
  year before the window, 1 440 rows a machine, the channels' min, max and
  mean drawn about their baselines (the raw rows are in the vault).

### A history day's rows (capture W3 item 4)

For purpose 14's planted manifests (chunk 21): a shipped day keeps no raw
row, so its count comes from what stays on site. **Readings**: the day's
`mach_readings_daily.rows` summed over the machines, 15 840 a day.
**Vitals**: the 10-second ticks of each session's interval that day, a
query on `mach_sessions` the window's raw rows obey (the coherence check
`vitals-window-rows`), here for local day `:'d'`:

```sql
SELECT sum(greatest(0, ceil(extract(epoch FROM least(coalesce(x.ended_at, now()), b.d1)) / 10)
                     - ceil(extract(epoch FROM greatest(x.started_at, b.d0)) / 10)))::bigint AS rows
  FROM (SELECT (:'d'::date::timestamp - make_interval(hours => utc_offset_hours)) AT TIME ZONE 'UTC' AS d0,
               ((:'d'::date + 1)::timestamp - make_interval(hours => utc_offset_hours)) AT TIME ZONE 'UTC' AS d1
          FROM mach_vitals_settings) AS b
  JOIN mach_sessions AS x ON x.started_at < b.d1 AND coalesce(x.ended_at, 'infinity') > b.d0;
```

### The partitions

`mach_vitals` and `mach_readings` by the customer's local day
(`<table>_<yyyymmdd>`, `[d 00:00, d+1 00:00)` at the offset),
`mach_events` by local month (`mach_events_<yyyymm>`), each beside its
`_default`, empty by design (false-alarm material). The load creates
yesterday's to today plus three's, and the events' months from the
history's start to next month. `mach_create_partitions(days)` (vitals and
biomed; biomed's also creates the events' months the days touch) and
`mach_drop_shipped(day)` are `SECURITY DEFINER`, owned by `mach`, `SET
search_path = public, pg_temp`; `mach` keeps `CREATE` on `public` for
them; `mach_partition_day(d)` (and biomed's `mach_partition_month(d)`) is
their one-partition helper, `EXECUTE` revoked from `PUBLIC`. At T0:
partitions from yesterday to today plus three, none older.

### At the reference T0

Measured at `load_epoch` 2026-11-04 10:00Z (a Wednesday), offset +2,
with the core's keys (`count(*)`):

| Database | Table | Rows | Notes |
|---|---|---|---|
| `pacs` | `mach_procedures` | 30 | the catalogue |
| | `mach_worklist` | 2 980 | about 2 910 completed, 64 cancelled, a few scheduled or in progress (the last day's) |
| | `mach_studies` | 2 915 | about 2 900 reported, a few acquired awaiting the final; about 80 unscheduled and reconciled; the six unmatched |
| | `mach_series`, `mach_reports` | 6 515, 3 765 | about 835 preliminaries, 2 905 finals, 31 addenda |
| `vitals` | `mach_sessions` | 2 746 | about 750 intensive care (two a day), 2 000 anaesthesia; 4 intensive-care and 3 anaesthesia sessions open at T0 |
| | `mach_vitals` | 62 629 | the window: 42 700 for the last full day (4.9 MB), today's to T0 |
| | `mach_vitals_chart`, `mach_alarms` | 82 611, 17 050 | the year |
| | `mach_census` | 50 | 40 current, those that left in the window |
| `biomed` | `mach_machines`, `mach_maintenance`, `mach_downtimes` | 28, 134, 33 | |
| | `mach_events` | 72 756 | 14 monthly partitions; about 225 critical a year |
| | `mach_readings` | 23 760 | the window: 15 840 for the last full day (2.4 MB with its index), today's to T0 |
| | `mach_readings_daily` | 4 015 | 11 machines, every day before the window |
| **Total** | | **282 020** | 75 MB on disk (`pacs` 13, `vitals` 34, `biomed` 28) |

The spec's sizes were estimates: the rule the sessions follow (D377) puts
about two intensive-care sessions a day, not 2.7, so a full day's raw
vitals are about 42 700 rows rather than 52 000, and about 2 980 imaging
requests reach the worklist (the core's 3 033 less the vet's own
cancellations), not 3 400.

**Machine 10's telemetry (O227, settled at the build): 11 machines
report.** The standing MRI's permanent magnet has no helium, cold head or
compressor to report, but the machine still sends its status row a
minute, with no channel (`{}`): measured at 48 bytes a row against 116.5
for the others, its 1 440 rows a day add about 70 kB to a readings day of
2.4 MB, 4 % of its bytes for a machine the biomedical engineers watch
like the others. So `mach_machines.telemetry` is true for 1–10 and 16,
the readings are 15 840 a day (as the spec's throughput), its daily
aggregate holds `{}`, and "the horses' MRI reports no helium" stays
false-alarm material. At ten machines the day would be 14 400 rows.

## The roles (vet-machinery-domain.md, "Application roles and grants")

Created once, in `pacs/schema.sql`; `vitals` and `biomed` only grant.

| Role | Databases (`CONNECT`) | Reads | Writes |
|---|---|---|---|
| `mach` | owns everything in each; no login | | |
| `mach_pacs_app` | `pacs` | every table | the entries' scheduling, identity and state (column grants), studies, series, reports; never the procedures nor a new entry (purpose 13's `mach_orders`) |
| `mach_vitals_app` | `vitals` | every table | census, sessions, vitals, chart, alarms |
| `mach_biomed_app` | `biomed` | every table | events, readings, maintenance, downtimes; `mach_machines`' `status` and `qa_due_on` |
| `mach_maint` | `vitals`, `biomed` | nothing | `EXECUTE` on `mach_create_partitions(days)` only; `LOGIN` because pg_cron runs a job only as a role that can log in (measured on `postgres` 0.5.0), its password a secret no node mounts |
| `mach_service` | `biomed` | machines, events, readings, maintenance | maintenance (rule 9); no producer in v0.5 |

`CONNECT` on each database goes to its own roles only, revoked from
`PUBLIC` by `load-data` and again by each schema (T200). The purposes'
roles (`mach_orders`, `mach_archive`) and the `ops` schema are purposes
13's and 14's.

## The classification

[`data/classification.yaml`](../data/classification.yaml) lists all 198
columns of the 18 tables: 10 `personal` (the worklist's animal id,
patient id and name, microchip, UELN, ear tag and Responsible Person; a
study's as-acquired patient id and name; a vendor engineer's name), 2
`customer-linked` (a session's and the census's animal id), the rest
`internal`, the shipped raw rows included while they carry a session's id
only (rule 10). Free text (a report's findings, an event's message) may
name the owner: a trap (T213), not a class.

## The producer

`equipment`, the machines and their systems as one scheduler node: its connections are
[`producers/equipment/schedule.yaml`](../producers/equipment/schedule.yaml)'s (each database as its
application role, and `clinic-api` by HTTP behind `clinic_lookup`).

## The partition jobs

[`data/cron.sql`](../data/cron.sql), as `mach_maint` on `machines`'
`pg_cron`: `vitals-partitions` (`0 22 * * *`,
`mach_create_partitions(3)` in `vitals`), `readings-partitions` (`5 22 *
* *`, the same in `biomed`), `events-partitions` (`0 22 25 * *`,
`mach_create_partitions(7)` in `biomed`, which reaches next month from the
25th of every month). Their times are `cron.timezone`'s (the customer's
zone where the seed sets it).

## The rules

The default policy's eleven rules ([`policy.md`](policy.md), D319):
release on the final only, addenda as new rows, the owner's family name in
studies by the DICOM standard, logs naming staff ids only and kept twelve
months, the radiation record of each ionising study, a yearly QA test, critical
alerts acknowledged within four hours, five years for images, reports and
the chart, vendors to `biomed` only, nothing identifying to the vault, the
aggregates before a day ships.

## Growth, and what stays on site

At intensity 1.0, on `machines`, measured from the loaded window
(the last full day): about **2 500 rows an hour** on average, 1 780 raw
vitals (more on a weekday morning with four theatres, about 2 400), 660
readings, about 10 events, and a few sessions, chart rows, alarms and
studies; about **0.3 MB an hour** with indexes, **7.3 MB a day**, of which
the two shipped types (raw vitals, 4.9 MB; readings, 2.4 MB) leave the
next night and about 700 rows a day stay. A Sunday is about 90 % of a
weekday (intensive care and the machines run every day). **What stays on
site**: raw vitals and readings, today and the last full day (`window_days`
1), their partitions shipped and dropped by purpose 14 the night after;
everything else for the game (the chart, studies and reports five years,
logs twelve months). When the shipping stalls the disk grows by about 7 MB
a day: 2.25G is about 300 days away, never the problem within an aging;
the witnesses are the vault's graph, the partition count and
`ops.shipments` (T220). The WAL adds about 50 MB a day.

## The traps

The catalogue is the domain document's (T200–T237, with its false-alarm
lines; [vet-machinery-domain.md](../../../specs/versions/v0.5/vet-machinery-domain.md#traps-step-8)),
each with its witness and where it is fixed. By class: on the shared
instance T200 (M), T201 (M), T202 (M, V when exposed), T203 (M), T204
(M); data and identity T205 (D), T206 (V), T207 (D), T208 (M; D without
a default partition), T209 (M), T210 (M), T211 (V), T212 (M);
governance T213 to T216 (M), T217 (V), T218 (V); partitions and cold
storage T219 (V), T220 (V), T221 (M), T222 (D; M for the week kept),
T223 to T226 (M); the imaging round trip T227 (D), T228 (D), T229 (V),
T230 (M), T231 (V), T232 (M), T233 (D); performance T234, T235 (M),
T236 (V), T237 (M). None is in v0.5's ten; T208 stays a trap for the GM
(D325). What the data holds on purpose and a player may take for a
fault: the vitals older than the window gone (shipped by design); the
empty default partitions; the standing MRI reporting no helium; a night's
CT reported preliminary only; six studies matching no animal; finals
signed outside reporting hours in the history (the core's turnaround);
the vault's curve dipping on Sundays. Selecting a game's faults is the
GM's.

## Loading

`gmctl load-data` creates `pacs`, `vitals` and `biomed` on `machines`
(owner `postgres`, `CONNECT` revoked from `PUBLIC`), then runs, in that
order, each database's `schema.sql`, then the core's `keys.sql` and its
`load.sql` in one session, as `postgres`, with `customer_timezone`,
`customer_utc_offset` and `load_epoch` set (each load stops at once when
one is missing, and checks its own ranges and partitions before it ends);
then [`data/cron.sql`](../data/cron.sql) in `machines`' `cron.database_name`
(D405), then the coherence queries. Measured on `postgres` 0.5.0 in a
throwaway container (2 GB, `fsync` off), the core's `keys.sql` streamed
ahead of each load:

| T0 (`load_epoch`), offset | `pacs` | `vitals` | `biomed` | Total | Rows | Size |
|---|---|---|---|---|---|---|
| 2026-11-04 10:00Z, +2 | 40.1 s | 9.1 s | 1.6 s | **50.8 s** | 282 020 | 75.4 MB |
| 2026-03-18 15:37Z, 0 | 39.3 s | 9.3 s | 1.7 s | **50.3 s** | 291 087 | 76.3 MB |

Most of `pacs`' time is `core_request` over the core's 17 000 ids (the
core's own 38 s); every check of `data/coherence.yaml` returned no row
against the core loaded at the same T0 (2026-11-04 08:50Z, +2). Purpose
14's material plants the history days' manifests afterwards (chunk 21).
