# v0.5 — `vet-machinery`, the clinic's machines

Status: draft v2, ruled, for approval with v0.5's master spec. Steps 1
to 9 of the [procedure](domain-procedure.md) drafted in one pass on
2026-11-03, on the owner's instruction ("start an agent for each part,
and let them come back with problems once they're done"); the same day
the owner accepted the recommendations as a whole (D319, closing
O192–O203), marked "(ruled, D319)" below, with two changes: T208 stays a
trap for the GM, s9 going to housing's T150 (D325); and the imaging
staff move to the core's layout, 26–28 and 52–56 (D324). The
several-database part (O195) is format text for O111, confirmed as
written (D323, D326, [procedure](domain-procedure.md) 10). The changes this part asked of the
shared pages are applied ([Changes needed in shared
pages](#changes-needed-in-shared-pages)).

`vet-machinery` holds the machines of the centre a scenario deploys
(D285). It is the clinic's third part: it requires `vet-core`
(procedure 4), refers to the core's keys by id with no foreign key, and
prefixes its tables and roles with `mach_`. From the confirmed split
(D279) it holds the machines, the studies for the core's imaging
requests (the request itself stays in the core), the readings and logs,
and each machine's own database. Three rulings bind it before anything
else:

- machine data is a time series: plain partitioned tables come first,
  TimescaleDB stays beyond v1.0, and the engine is PostgreSQL only
  (D47, D250; [brick-options-review.md](brick-options-review.md));
- the readings follow friction 11's design, with a day kept on site and
  the rest shipped to cold storage (D288, D296–D298;
  [cold-storage.md](cold-storage.md));
- the lab's six analysers are machines 1–6, by id (D302), and
  `vet-scheduling` books machines by an id this part owns.

## The draft at a glance (step 9)

Where each item of the part's folder, `domains/vet-machinery/`, is
stated on this page (procedure 1, 3 and 4). The format is finalised in
the master spec (O111). A part with three databases needs one format
change ([O195](#questions-for-the-owner)).

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-machinery`, `requires: [vet-core]`, tables and roles prefixed `mach_`, its three databases (D319; format text for O111, D323, D326), the purposes that fit | [What the part holds](#what-the-part-holds); [Purposes](#purposes-step-7-ruled-d319) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest named after the core's variant (D301, answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/pacs/`, `data/vitals/`, `data/biomed/`: each holds a `schema.sql` and a `load.sql`, for one database each (O195) | [The data model](#the-data-model-step-4) |
| `data/classification.yaml`: every column classed, keyed `<table>.<column>` (the names are unique across the three databases) | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The business's own rules](#the-businesss-own-rules-ruled-d319) |
| `producers/`: the machines and their systems (`equipment`), the `pg_cron` partition jobs on `machines` | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; [Traps](#traps-step-8); [Loading](#loading) |

## Nodes and capacity, first

The brief turns on "each machine's own database", which could multiply
nodes. This section states the minimum first because the budget is the
hardest constraint. Core and lab already take 18 nodes (3.0 CPU,
3.2G). The whole clinic is estimated at 26–32 nodes, which uses 78–96 %
of the CPU on armenelos plus the VPS. The VPS has no room for another
database node ([clinic-capacity.md](clinic-capacity.md)).

**The plausible minimum: three nodes, all on armenelos (ruled, D319).**

| Node | Brick | Scope | CPU | Memory | Disk | What it is |
|---|---|---|---|---|---|---|
| `machines` | `postgres` | the players' | 0.5 | 512M | 2.25G | the machinery's database server. One instance holds three databases, one per machine system: `pacs` (the imaging archive and its worklist), `vitals` (the monitors' central station), `biomed` (the biomedical engineering system: the registry, the machines' logs and readings) |
| `equipment` | `scheduler` | the players' | 0.1 | 64M | 128M | the machines and their systems as one producer: the modalities, the PACS and its worklist, the monitors and their central station, the machines' service side |
| `machines` exporter | `postgres-exporter` | monitoring | 0.05 | 48M | 64M | as v0.4's one exporter per `postgres` node (v0.4 13.4), with `options: [monitoring]` on `machines` (D289) |
| **Total** | | | **0.65** | **624M** | **2.44G** | |

This sits at the low end of the tally's estimate for this part (3–4
nodes, 0.7–0.8 CPU, 0.6–0.7G). Armenelos goes from 1.8 to 2.45 of its
3.6 CPU. The two flows this part adds, the imaging orders and the
nightly shipping, run on `interfaces`, which already exists, and take a
few seconds a night and a few calls a minute. The vault is cold
storage's hostname on the partners' shared `api` node (D308), so this
part adds no partner node.

**Trims, if the parts come out heavier**, in this order, each the
owner's call:

1. `machines` at 0.25 CPU and 384M, as the partners' database is
   sized, saves 0.25 CPU. Its load is about one insert a second and
   small reads. This is measured at the build.
2. The producer's fragments move onto `pms` (no `equipment` node). This
   saves 0.1 CPU and 64M. The cost is that the practice software and
   the machines share one schedule, so a fault on `pms`'s schedule
   stops the machines too.
3. The exporter is dropped, with D238's pgwatch covering `machines`.
   This saves 0.05 CPU and 48M, but the dashboards lose the machinery
   until pgwatch is specified.

At all three trims the part is two nodes, about 0.25 CPU and 384M.

**What the minimum costs in realism** (said plainly, for O194):

- **One instance for three vendors' systems.** A real hospital's PACS,
  monitoring central station and biomedical engineering system come
  from different vendors. Each ships its own server and often its own
  engine (SQL Server, an embedded database), and D47 keeps the game on
  PostgreSQL. Here they share one instance: one `postgresql.conf`, one
  superuser, one WAL stream, one failure domain. Hospitals do
  consolidate vendor databases on a shared cluster at `managed`
  maturity, so the shape is plausible. The costs of consolidating
  become traps (T200–T202, T216): a vendor's setting applied to every
  database, `CONNECT` left to `PUBLIC`, and a vendor's service account
  reaching every database.
- **Three databases stand for 28 machines.** Each modality's own
  console database is not modelled; the PACS stands for them. The
  analysers' own databases are the lab's middleware (`lis` writing to
  `lab`), not this part's.
- **One producer for every machine.** A stalled `equipment` stops every
  machine at once, where a real fleet fails piece by piece.
- **No standby and no WAL archive.** Recovery goes back to last night's
  base backup (O200).
- **A day on site**, where real central stations keep three to ten days
  (Philips PIIC iX seven days; Mindray BeneVision CMS 240 hours, read
  2026-11-03). The owner's direction (D288) was chosen over the
  vendors' figures.
- **No pixel data.** A study records its series, image counts and size.
  The images themselves live on the PACS's storage, outside the game.

**Rejected**: one database per machine (28 schemas copied, no game
value beyond the count); one node per machine system (+1.0 CPU, which
the hosts do not have); the databases on `records` (against "dedicated
servers", and the monitors' inserts would ride the core's standby,
which replication.md 1 refuses).

## The brief (step 1, ruled, D319)

Built from the owner's clinic brief (D196): "horse section (housing,
dedicated machinerie, multiple specialists); farm section (same); ...
biology (lab, blood analysis machinerie, etc)"; "machinerie require
dedicated servers and databases"; "machine logs, have also their own
governance and needs". Also from his direction on data growth (D288):
"If we're talking about lab machineries, we will say that we keep a day
on site (but moderate the generation), and the rest get shipped to cold
storage". The brief, accepted as proposed (D319):

> The centre's machines: the imaging of the horse, farm and domestic
> sections (CT, MRI, radiography, ultrasound, the horses'
> scintigraphy), the monitors of its theatres and intensive care, and
> the lab's analysers. Each machine system keeps its own database on
> the machinery's server: the imaging archive with its worklist, the
> monitors' central station, and the biomedical engineers' registry
> with every machine's logs and readings. A vet orders an imaging
> study in a consultation. The study is scheduled on a machine and
> performed, an imaging specialist reports it, and the report goes
> back to the record. Monitors and machines produce readings
> continuously, at a moderate grain. A day is kept on site and the
> rest is shipped to cold storage, after what the clinic needs has
> been kept on site. Machine logs have their own governance: they name
> no owner, they are kept a set time, and a vendor's access reaches
> its own machines' service data only.

## Settled before this page

Built on, not reopened:

- **One centre**, its machines the centre's own (D285, D293;
  [one-centre.md](one-centre.md) 1). The other centres' machines appear
  only through the core's exchanges (an examination asked of another
  centre, D306).
- **The request lives in the core** (D279): `requests` with `kind`
  `imaging`, a study code, a priority, the consultation, the animal and
  the requesting vet. Each request is a function of its id (D302), and
  about one in five is imaging.
- **A sent request is cancelled by the part that holds it** (D315, for
  the lab). This page proposes the same for imaging (O198).
- **Parts get the core's animals through its lookup API** (D266, D267),
  `clinic-api`, as `vet-lab`'s `lab.identity` does. The core's dozen
  mistyped chips reach a part's live data this way (D278).
- **Machine readings at a moderate grain** (D298): a row every ten
  seconds per machine while it runs, or a row a minute holding a batch.
  One day is kept on site in daily partitions, and older days are
  shipped. The tally's figure is about 3 600 rows an hour for ten
  machines.
- **Cold storage** (D296, D297): the shipping job is a round trip of
  the customer's. Aggregates are computed before shipping, and the GM
  decides per data type what ships, use first and volume second. The
  bastion routes players to the vault's read-only page.
- **No standby for the machinery's databases** (D299;
  [replication.md](replication.md) 1): their heavy data ships to cold
  storage, and a standby would double it.
- **pgaudit and TLS** are always available and turned on by the seed
  (D250, D261). The `monitoring` role is an option (D289).
- **Script jobs** hold an HTTP connection beside their PostgreSQL ones
  (D303). `api` nodes only answer (D270). Nothing runs more often than
  every minute.
- **One variant**, `regional-franchise` (D263). "The data schema stays
  simple and the tables small" ([platform.md](../../platform.md)).

## The business sketch (step 2)

### The business

The centre's machine park, as its staff meet it:

- **Imaging.** Each section has its own machines: CT and MRI for the
  domestic section; a large-bore CT, a standing MRI and a gamma camera
  (bone scintigraphy) for the horses; digital radiography rooms and
  ultrasound for each section; a portable radiography unit and a
  portable ultrasound for the farm and the stables. A vet orders a
  study in a consultation (the core's request). It arrives on the
  machine's **worklist**, as DICOM's modality worklist carries an order
  to a modality. A radiographer performs it, the images go to the
  **PACS**, and an imaging specialist reports it. A night's urgent
  study gets a preliminary report from the duty vet and its final
  report the next morning.
- **Monitoring.** Each theatre has an anaesthesia monitor, one of them
  MRI-compatible for imaging under anaesthesia. Intensive care has
  bedside monitors: six domestic, two for horses and foals. All of them
  feed a **central station** that holds each monitored animal's vital
  signs. Under anaesthesia the vitals are charted every five minutes,
  and in intensive care every hour. That chart is the clinical record.
- **The lab's analysers.** The haematology, biochemistry, blood gas and
  coagulation analysers. Their results reach `vet-lab` through its
  instrument batch uploads (D302). Their own telemetry and logs are
  machinery's.
- **Biomedical engineering.** A small team, with the vendors' service
  engineers, keeps the registry of every machine: its service visits,
  its quality-assurance tests, its downtimes, and every machine's
  collected logs and status telemetry (an MRI's helium level and cold
  head, an analyser's temperatures and reagents).

### Actors

| Actor | Who | With the machines |
|---|---|---|
| Requesting vet | core `staff` | orders imaging in a consultation (the core's request); reads the images and reports |
| Radiographer | core `staff`, `kind` `technician` (staff 52–55, D324) | performs studies, records the exposure and who restrained the animal |
| Imaging specialist | core `staff`, `kind` `vet`, specialty diagnostic imaging (26–28, D324) | reports and signs studies, amends a final report by an addendum |
| Duty vet | any core vet on call | a night's preliminary report on an urgent study |
| Anaesthetist, nurse | core `staff` | start and end a monitor session, acknowledge alarms |
| Biomedical engineer | core `staff`, `kind` `technician` (56, D324) | the registry, maintenance, QA, downtimes, acknowledging machine alerts |
| A vendor's service engineer | a third party with a remote service account (no node in v0.5) | reads its machines' logs and readings, records its service visits |
| Lab technician | core `staff`, `kind` `lab` | runs the analysers (`vet-lab`); their logs are here |
| `vet-scheduling` | a part | books imaging machines by `machine_id` (an assumption at the boundary) |
| Cold storage | a third party (D296) | receives the shipped readings, answers with a receipt |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Ordering a study | the request | core (`requests`) |
| The order reaching the machine | a worklist entry, its accession, the animal's identity from the lookup API | `vet-machinery` (`pacs`); the flow is a purpose (step 7) |
| Scheduling a machine | the entry's machine and time | `vet-machinery`; a booking by id is `vet-scheduling`'s |
| Performing the study | the study, its series, images, size, the operator, the exposure, who restrained the animal | `vet-machinery` (`pacs`) |
| An unscheduled study | a night emergency typed on the modality, reconciled later to its entry | `vet-machinery` |
| Reporting | the preliminary, the final, an addendum | `vet-machinery`; `resulted` is copied back to the core by a purpose |
| Monitoring an animal | the session, the 10-second vitals, the chart, the alarms | `vet-machinery` (`vitals`) |
| Knowing who is in hospital | the central station's census of the core's current stays | `vet-machinery`, from the lookup API |
| Machine telemetry and logs | readings each minute, events | `vet-machinery` (`biomed`) |
| Maintenance and QA | service visits, QA tests, calibrations, downtimes | `vet-machinery` (`biomed`) |
| Shipping heavy data | partitions to the vault, their receipts | a purpose (`cold-storage-archive`) |
| Releasing a report to the owner | what was released, when | `vet-portal` |

### The variant, its scale and its tags

The part takes the clinic's one variant, `regional-franchise` (D263),
and adds no tag. Its own axes go in `variants/regional-franchise.yaml`
(D301, answer 15). The figures fit `vet-core` at one centre's scale
(D295): of the core's ~17 000 requests a year and ~55 a day, about one
in five is imaging, so about 3 400 a year and 11 a day.

**Population**, at load (ruled, D319):

| What | How many |
|---|---|
| Machines | 28: analysers 1–6 (the lab's, D302), imaging 7–16, anaesthesia monitors 17–20, intensive-care monitors 21–28 |
| Imaging procedures | 30 study codes over five modalities, by species group |
| Monitored at once | about 5 animals in intensive care around the clock, up to 4 under anaesthesia on weekdays |
| Imaging staff | 3 imaging specialists, 4 radiographers, 1 biomedical engineer, among the core's 85 (O198) |

**History**: one year, growing as the core grew (D279), each daily
volume ramping from about 60 % of today's rate to today's. The heavy
raw data is not history. Only the on-site window is loaded, today so
far and the last full day. The days before it exist as the vault's
manifests and the kept aggregates (cold storage 2, 3, 5).

| What | Over the year |
|---|---|
| Worklist entries, studies | about 3 400 and 3 470 (about 70 of them unscheduled, reconciled) |
| Series, reports | about 8 000 and 3 450 (about 35 addenda) |
| Monitor sessions | about 3 800: 2.7 a day in intensive care, 10 under anaesthesia |
| Chart rows | about 90 000 |
| Alarms | about 21 000 |
| Machine events (the logs) | about 73 000 |
| Daily aggregates of the readings | about 4 000 |
| Maintenance, QA, downtimes | about 190 |

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Imaging studies | about 11 a day: 13 on a weekday, 6 on Saturday, 3 on Sunday; urgent around the clock |
| Raw vitals | about 52 000 rows a day: about 145 monitor-hours at a row every 10 s |
| Machine readings | about 15 800 rows a day: 11 machines with telemetry, a row a minute holding a batch of channels |
| Chart rows, alarms, events | about 310, 72 and 250 a day |

That is about 68 500 rows a day, nearly all of them the two shipped
types, or about 2 850 an hour, which matches D298's ~3 600 for ten
machines. About 700 rows a day stay on site for the game.

**A few stand for many** (D263): 28 machines for a referral hospital's
park, three databases for its vendors' systems, one vault for its
archives.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Every 10 seconds | a raw vitals row per open monitor session | yes |
| Every minute | a reading per machine with telemetry; each modality's worklist query; the identity job | yes |
| Every 5 minutes | the census of current stays; the anaesthesia chart (hourly for intensive care) | yes |
| Imaging hours, Monday to Friday 08:00–18:00, Saturday morning | routine studies; urgent ones around the clock | yes |
| Reporting hours, 08:30–18:00 on weekdays, Saturday morning | final reports; a night's urgent studies get a preliminary at once | yes |
| Theatre hours, weekdays 08:00–18:00 | anaesthesia sessions; emergencies at night | yes |
| Nightly, 00:40 | the shipping to the vault (purpose); partitions created ahead at 22:00 | yes |
| Monthly | the logs' next month's partition, on the 25th | **no**: created at load |
| Yearly | each ionising machine's QA test; the logs' one-year retention | **no**: in the history |

### Regulations

What a regulated clinic's machines plausibly answer to, at the level a
game needs. Sources read on 2026-11-03 (research for this draft): the
Euratom Basic Safety Standards Directive, Germany's Radiation
Protection Act and Ordinance, DICOM PS3.3, PS3.5 and PS3.6 (edition
2026d), Philips' and Mindray's central-station data sheets, Philips'
MRI remote-monitoring sheets, and the Tierärztekammer Nordrhein's
professional code.

| Rule | Source | What the part must hold |
|---|---|---|
| X-ray and CT in a veterinary practice are a regulated practice. Staff who hold or restrain an animal are occupationally exposed, with dose limits, zoning and individual monitoring | Directive 2013/59/Euratom, Art 2(2)(b), recital 31, Arts 9, 35–41 | each ionising study's operator, exposure and the staff who restrained the animal |
| Workers' dose records are kept until age 75 and at least 30 years after the work ends | 2013/59/Euratom Art 43(3); StrlSchG § 167(2) | nothing: the approved dosimetry service keeps them, outside the game |
| An animal's companion is present during exposure only when necessary, and never a pregnant person | StrlSchV § 144 (Germany, the example) | whether a companion was present |
| X-ray equipment is checked by an expert at least every five years. EU equipment QA (Art 60) covers human medical use only | StrlSchV § 88(4); 2013/59/Euratom Art 60, Art 4(48) | each ionising machine's QA tests and their due date |
| Giving radioactive substances to animals needs a licence | 2013/59/Euratom Art 28(a) | nothing: the gamma camera's licence is the story's |
| A study names the animal and its responsible person: Patient's Name is "owner's family name^animal's name", and Responsible Person is required for a non-human patient | DICOM PS3.5 § 6.2; PS3.3 C.7.1.1 (0010,2297), (0010,2299) | the identity on the worklist and the study: personal data |
| Findings and technical records are kept five years | Berufsordnung der Tierärztekammer Nordrhein § 2(6) (2026), "dies gilt auch für technische Dokumentationen" | images, reports and the anaesthesia chart for five years, like the core's records (D280, rule 9) |
| Owners' data stays out of logs and goes to a third party only as its rule allows | GDPR; the core's rule 10 (D280) | logs that name no owner; shipments that carry no identity |

## What the part holds

Within procedure 4: every table prefixed `mach_`, every core key by id
with no foreign key, on a `postgres` node of its own holding three
databases (O194, O195):

- **`pacs`**, the imaging archive and its worklist: the procedure
  catalogue, worklist entries, studies, series and reports.
- **`vitals`**, the monitors' central station: the census of current
  stays, monitor sessions, the 10-second vitals (partitioned daily,
  shipped), the chart and the alarms.
- **`biomed`**, the biomedical engineering system: the machine registry
  (the ids `vet-lab` and `vet-scheduling` use), maintenance and QA,
  downtimes, the machines' events (partitioned monthly, kept a year),
  their readings (partitioned daily, shipped) and the readings' daily
  aggregates.

## Where the part presses on the core and its neighbours

| The part needs | From | Change? |
|---|---|---|
| the imaging request, its study code, priority, consultation, animal, requesting vet | the core's `requests`, through `vet-imaging-orders` | none |
| study codes the PACS knows | the core's function for an imaging request's code drawing from this part's 30 codes by the animal's species | **yes**: a constraint on the core's load, as D302's |
| the animal's identity and the owner's name for the worklist | `clinic-api`'s `GET /animals/{id}` and `/owner` (D266) | none |
| who is in hospital now, for the monitors | `clinic-api`, a new `GET /stays?current=true` | **yes**: an endpoint and `vet_lookup`'s grant on `stays`' columns (O197) |
| the history's sessions on real stays | the core's stays as functions of their id (animal, section, admitted, discharged), as requests are (D302) | **yes**: a constraint on the core's load (O197) |
| imaging staff and the biomedical engineer in a range | `staff` 26–28 and 52–56, the core's layout (D324) | **yes**: as D302's 71–80 (D319) |
| cancelling a sent imaging request | the imaging team, copied back (as D315 for the lab) | **yes**: the core's `requests` lifecycle names the imaging team beside the lab (D319, D324) |
| the analysers' ids | `vet-lab`'s `machine_id` 1–6 | the mapping, stated here (below) |
| machine ids to book | `vet-scheduling` | an assumption: it books machines 7–16 (`bookable`) |

## Answers to the sketch's questions (step 2, ruled, D319)

The questions the brief leaves open, each with the default this page
carries on with:

1. **Which machines.** The 28 above: imaging, monitors and the lab's
   analysers. Not modelled: anaesthesia machines and ventilators,
   infusion pumps, endoscopes, the equine treadmill, and the fridges'
   and freezers' temperature probes. They are named here as a later
   part's or a scenario's story.
2. **Are the patient monitors machinery?** Yes. They are the hospital's
   real heavy time series and the one most like the owner's "hefty
   amount of data continuously". Their rows are about an animal,
   which gives the part its governance case: customer-linked data and
   what may leave for the vault. Without them the readings are
   machine telemetry only, about 16 000 rows a day, under cold
   storage's threshold.
3. **One study per request.** Each imaging request is one worklist
   entry and one study, as a modality worklist item is. A second view
   on another day is a new request.
4. **Who cancels.** While `requested`, the vet, in the core. Once
   `sent` (on the worklist), only the imaging team, and the
   cancellation comes back by the purpose (as D315).
5. **The report.** It is what the request is for. An urgent study gets
   the duty vet's preliminary at once, visible inside the centre and
   marked preliminary. The imaging specialist's final report is signed
   in reporting hours. The request is `resulted` only on the final.
6. **Unscheduled studies.** About one urgent study in fifty, at night,
   is acquired before its entry exists, with the animal typed on the
   modality. A reconciliation links it to its entry within the day.
   The load also plants six studies that match no animal, extra
   acquisitions typed for animals the record does not hold. That is the
   PACS's version of the core's mistyped chips: domain data, a finding
   to report.
7. **Monitor sessions.** Started on a current stay of the core: in
   intensive care for about one stay in three, by a hash of the stay's
   id; under anaesthesia for about ten stays a weekday, in theatre
   hours. A session ends when its stay is no longer current
   (intensive care) or after about 90 minutes (anaesthesia).
8. **What a "reading" is.** For a monitor, a row every 10 seconds of
   heart rate, respiratory rate, SpO2, end-tidal CO2, blood pressures
   and temperature. For a machine, a row a minute holding its
   channels: an MRI's helium level and cold head, a CT's tube heat, an
   analyser's temperatures and reagent levels. Ultrasound and
   radiography send no telemetry.
9. **Logs.** Each machine's events (info, warning, error, critical)
   collected into `biomed`. An operator is named by staff id. Kept a
   year on site, partitioned monthly.
10. **Scale and hours.** The figures and cadences above.

## The data model (step 4)

Three databases on the `machines` node: `pacs`, `vitals` and `biomed`
(O194, O195). They follow the shop's and the core's manner: tables in
`public`, prefixed `mach_` (procedure 4), integer keys `GENERATED BY
DEFAULT AS IDENTITY`, explicit ids at load, each sequence set after its
range. Core keys are plain integer columns with no foreign key:
`request_id`, `consultation_id`, `animal_id`, `stay_id`, staff ids.
`machine_id` is this part's own. It is a foreign key inside `biomed`
only. In `pacs` and `vitals` it is a plain column, since the databases
are separate. Every value is generated, and identities come by the
core's functions of the animal's id.

**Partitioned tables** (D250): `mach_vitals` and `mach_readings` by day
on their time column, `mach_events` by month. Each has a default
partition that stays empty by design. Partitions are created ahead by
`pg_cron` on `machines`: three days ahead for the daily ones, the next
month on the 25th. The indexes are declared on the parent, so every new
partition gets them. A shipped partition is detached and dropped,
never deleted from (cold storage 2).

### Entities

**`biomed`: the registry, maintenance, logs and telemetry**

| Table | Key, main columns |
|---|---|
| `mach_settings` | one row: the customer's zone and offset (a separate node keeps its own copy, as `lab_settings`); the on-site window (1 full day), the logs' retention (12 months) |
| `mach_machines` | `id`; code (`CT-SA-1`), name, `kind` (`analyser`, `ct`, `mri`, `dr`, `us`, `gamma`, `monitor-anaesthesia`, `monitor-icu`), DICOM `modality` (`CT`, `MR`, `DX`, `US`, `NM`; none for analysers and monitors), `ae_title` (the modality's DICOM name), `section_id` (the core's), `discipline` (analysers), `species_group` (`small`, `large`, `any`), vendor, model, serial, installed on, `bookable`, `ionising`, `telemetry`, `status` (`in-service`, `down`, `retired`), `qa_due_on` (ionising machines) |
| `mach_maintenance` | `id`; machine, `kind` (`service`, `repair`, `qa-test`, `calibration`, `software-update`), performed at, vendor, `engineer` (the vendor engineer's name) or staff id, outcome (`pass`, `fail`, `done`), next due on, notes |
| `mach_downtimes` | `id`; machine, from, until (open while down), reason |
| `mach_events` | partitioned by month on `at`: `id`; machine, at, `level` (`info`, `warning`, `error`, `critical`), code, message, `operator_id` (staff), acknowledged at, acknowledged by (critical events) |
| `mach_readings` | partitioned by day on `read_at`, shipped: (`machine_id`, `read_at`); `status`, `channels` (`jsonb`: the kind's channels and values) |
| `mach_readings_daily` | (`machine_id`, `day`); rows, `channels` (`jsonb`: min, max and mean per channel): the aggregate kept for the whole game, computed before the day ships |

**`pacs`: the imaging archive and its worklist**

| Table | Key, main columns |
|---|---|
| `mach_procedures` | `id`; `code` (unique: the core's study code), name, modality, `species_group`, body part, minutes, `under_ga`, turnaround hours (routine) |
| `mach_worklist` | `id`; `accession` (unique, `I-<request id>`: the idempotency key), `request_id`, `consultation_id`, `animal_id`, `requested_by`, procedure, `priority` (`routine`, `urgent`), `machine_id`, scheduled at, `booking_id` (`vet-scheduling`'s, by id, empty in v0.5); the identity the lookup API answered: `patient_id` (`A-<animal id>`), `patient_name` (`Surname^Name`, PS3.5 6.2), species, breed, sex, born on, `microchip`, `ueln`, `ear_tag`, `responsible_person` (the owner's name, role `OWNER`), identity at; `state`, cancelled because, created at |
| `mach_studies` | `id`; `study_uid` (unique), `worklist_id` (none while unscheduled), accession as acquired, `machine_id`, `patient_id` and `patient_name` as acquired (from the worklist, or typed), performed by (staff), restrained by (staff, ionising studies), `companion_present`, started at, ended at, images, size in MB, `exposure` (kV and mAs; CT's DLP; none for MR and US), `state`, reconciled at, by |
| `mach_series` | `id`; study, number, modality, body part, description, images |
| `mach_reports` | `id`; study, `kind` (`preliminary`, `final`), author (staff), findings, conclusion, `status` (`draft`, `signed`), signed at; `supersedes_id`, why: an addendum is a new row superseding the final, which is kept |

**`vitals`: the central station**

| Table | Key, main columns |
|---|---|
| `mach_census` | `stay_id`; `animal_id`, animal's name, species, `section_id`, admitted at, seen at, left at: the core's current stays as the lookup API last answered |
| `mach_sessions` | `id`; `machine_id` (a monitor), `kind` (`anaesthesia`, `icu`), `stay_id`, `animal_id`, animal's name, species, weight, started at, started by, ended at, `ended_by` (`census`, `staff`) |
| `mach_vitals` | partitioned by day on `at`, shipped: (`session_id`, `at`); heart rate, respiratory rate, SpO2, end-tidal CO2, systolic, diastolic, mean pressure, temperature |
| `mach_vitals_chart` | (`session_id`, `at`); the same measures (mean, min and max over the interval): every 5 minutes under anaesthesia, hourly in intensive care; the clinical record, kept five years |
| `mach_alarms` | `id`; session, at, `priority` (`high`, `medium`, `low`), `kind` (`physiological`, `technical`), parameter, value, acknowledged at, by |

### Lifecycle states

| Entity | States |
|---|---|
| Worklist entry | `new` (no identity yet) → `scheduled` → `in-progress` → `completed`; or `cancelled` (by the imaging team once sent, O198) |
| Study | `acquired` → `reported` (final signed); an unscheduled one `acquired` → `reconciled` → `reported`, or `unmatched` |
| Report | a preliminary `signed` (urgent only) → the final `signed` → superseded by an addendum, both kept |
| Monitor session | open → ended (by the census when the stay ends, or by staff) |
| Alarm | raised → acknowledged |
| Machine | `in-service` ⇄ `down` (a downtime) → `retired` |
| A daily partition | created ahead → written → after the window, shipped → receipt matched → detached and dropped |

### Deterministic key ranges (D249, D266)

| Key | Range | Layout |
|---|---|---|
| `mach_machines.id` | 1–28 | 1–2 haematology, 3–4 biochemistry, 5 blood gas and electrolytes, 6 coagulation (the on-call analysers at night are 1, 3 and 5, as `vet-lab`'s `lab.qc.night` runs three); 7 CT small animal, 8 CT large bore, 9 MRI 1.5 T (domestic, helium), 10 standing MRI (horses, a permanent low-field magnet: no helium), 11 DR room domestic, 12 DR room horses, 13 portable DR (farm and stables), 14 ultrasound domestic, 15 portable ultrasound (horses and farm), 16 gamma camera (horses); 17–18 anaesthesia monitors of the small-animal theatres, 19 of the equine theatre, 20 the MRI-compatible one; 21–26 intensive-care monitors domestic, 27–28 horses and foals. Bookable: 7–16. Telemetry: 1–9 and 16 (10 machines) and 10 (status only) |
| `mach_procedures.id` | 1–30 | 1–12 small animal, 13–27 large animal, 28–30 any; DX about 45 % of studies, US 30, CT 15, MR 7, NM 3 |
| History, `pacs` | `mach_worklist` 1–3 400 (the k-th imaging request of the core's, in time order), `mach_studies` 1–3 470, `mach_series` 1–8 000, `mach_reports` 1–3 450 | each a function of the request's id and time, documented in the GM notes |
| History, `vitals` | `mach_sessions` 1–3 800 | intensive-care sessions on the stays a hash of the stay id picks (one in three); anaesthesia sessions on stays by a hash of the day and stay |
| Core keys used | imaging `request_id`s among 1–17 000 by the core's function; `animal_id` 1–17 000; `stay_id` 1–2 500 (O197); staff 26–28 and 52–56 (D324) | as the core documents them |

The six unmatched studies are ids 3 465–3 470. Each has a typed
`patient_id` that names no animal (`A-` and an id above 17 000, or two
digits swapped), with no worklist entry and no request.

### Application roles and grants

The login roles carry no password here; `load-data` sets each from its
secret.

| Role | Database | Who | Reads | Writes |
|---|---|---|---|---|
| `mach` | each | owns everything; no login | | |
| `mach_pacs_app` | `pacs` | the PACS, its worklist and the modalities (`equipment`) | every table | worklist entries' scheduling, identity and state; studies, series, reports; never the procedures |
| `mach_vitals_app` | `vitals` | the central station and the monitors | every table | census, sessions, vitals, chart, alarms |
| `mach_biomed_app` | `biomed` | the biomedical engineering system and the machines' service side | every table | events, readings, maintenance, downtimes; `mach_machines`' `status` and `qa_due_on` (a column grant) |
| `mach_maint` | `vitals`, `biomed` | the partition jobs on `machines`' `pg_cron` | nothing | `EXECUTE` on `mach_create_partitions(days)` only |
| `mach_service` | `biomed` | the vendors' remote service; no producer in v0.5 | machines, events, readings, maintenance | maintenance; never `pacs` or `vitals` (rule 9) |

`CONNECT` on each database goes to its own roles only, revoked from
`PUBLIC` (the default PostgreSQL leaves, T200). The two partition
functions, `mach_create_partitions` and `mach_drop_shipped(day)`, are
`SECURITY DEFINER`, owned by `mach`, with a fixed `search_path`. They
let the jobs create and drop partitions without owning the tables (a
detach needs the owner). The purposes' roles come with step 7.

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
| `biomed`: machines, maintenance, downtimes | about 220 | under 1 |
| `biomed`: events (a year, monthly partitions) | about 73 000 | about 250 |
| `biomed`: readings (the window) and daily aggregates | up to 32 000 and about 4 000 | about 15 800 (shipped) and 11 |
| `pacs`: procedures, worklist, studies, series, reports | 30, 3 400, 3 470, 8 000, 3 450 | about 11, 11, 26, 12 |
| `vitals`: census, sessions | about 40, 3 800 | 40 kept current, 13 |
| `vitals`: vitals (the window) | up to 104 000 | about 52 000 (shipped) |
| `vitals`: chart, alarms | about 90 000, 21 000 | about 310, 72 |
| **Total** | **about 0.34 million rows**, the window at its widest | **about 68 500**, all but about 700 shipped |

Close to the lab's 0.36 million and the core's 0.28. The raw window is
about a third of it and varies with T0. On disk: the window is about
20 MB, the kept rows about 40 MB with indexes. Within the brick's
2.25G with a wide margin. Load time and size are measured at the build.

### Plausibility points (step 4, ruled, D319)

1. **Three databases on one instance**, consolidated vendor systems,
   with the realism costs stated in [Nodes and
   capacity](#nodes-and-capacity-first).
2. **The monitors carry the volume**: about 52 000 of the 68 500 rows
   a day. Without them the part is under cold storage's threshold.
3. **No pixel data and no row per image**: series counts and sizes.
   A real PACS keeps a row per image, about half a million a year here.
4. **The raw data is no history**: the window only, the vault's
   manifests and the kept aggregates standing for the year.
5. **Six unmatched studies** at load, the PACS's mistyped chips.
6. **A standing MRI with no helium**: a permanent magnet. The
   difference from the 1.5 T is false-alarm material.

## Classification and governance (step 5)

### Classification

v0.4's three classes, applied as the core and the lab apply them (D280,
D302). Keys are `<table>.<column>` (unique across the three databases),
and the scenario's copy adds each table's database (procedure 6, item
2; O195).

Readings for the part:

- **A study names its owner.** DICOM's Patient's Name holds the owner's
  family name by the standard (PS3.5 6.2), and Responsible Person is
  the owner. Both are direct identifiers, so personal. The animal's id
  beside them, and the `A-<id>` patient id, are personal too, as in the
  lab's orders. A natural identifier is personal (D280).
- **A session follows the core's stay.** Its `animal_id`, with no
  identifier beside it, is `customer-linked`. An animal's name and
  species are `internal`, as in the core.
- **Child rows are internal.** A raw vitals row, a chart row, an alarm,
  a series and a report refer to their parent by id and carry no
  identifier. So the shipped vitals are `internal` as long as they
  carry the session's id only (rule 10).
- **Machines are no one.** Readings, events and maintenance are
  `internal`. An operator's staff id is the clinic's work record. A
  vendor engineer's name is personal.

| Table | `personal` | `customer-linked` |
|---|---|---|
| `mach_worklist` | `animal_id`, `patient_id`, `patient_name`, `microchip`, `ueln`, `ear_tag`, `responsible_person` | |
| `mach_studies` | `patient_id`, `patient_name` | |
| `mach_census` | | `animal_id` |
| `mach_sessions` | | `animal_id` |
| `mach_maintenance` | `engineer` | |

Everything else is `internal`. Two traps follow (step 8): free text
(a report's findings, an event's message) may name the owner, and a
shipment joined with its session's animal carries more than its rule
allows.

### The business's own rules (ruled, D319)

The part's default policy (procedure 6, item 1), beside the core's and
the lab's, built into `docs/policy.md` and the `governance:` fragment.
Its home is the core's unnamed EU member state (D278), with Germany the
example for national rules. A figure marked *game value* is a choice,
not the law.

1. **Release.** An imaging report leaves the PACS, to the record and to
   the portal, only once the imaging specialist's final is signed. A
   preliminary is visible inside the centre, marked as such (the lab's
   rule 1; the core's rule 11).
2. **Addenda.** A signed final report is never updated. An addendum is
   a new row superseding it, the first kept with why and who (the lab's
   rule 3, applied to reports).
3. **Identity in studies.** A study carries the owner's family name and
   the animal's name (DICOM PS3.5 6.2; PS3.3 Responsible Person), taken
   from the lookup API: a name only, never a contact (D266).
4. **Machine logs** name an operator by staff id only, never an animal's
   or an owner's name. They are kept twelve months on site, then
   dropped (*game value*; Philips keeps 90 days of alarm audit). No
   personal data in the server's logs: pgaudit on `machines` logs
   writes, DDL and roles, without parameters, as on `lab`.
5. **Radiation protection.** Each ionising study records its
   radiographer, the staff who restrained the animal, and whether a
   companion was present (2013/59/Euratom Arts 9, 35–41; StrlSchV
   § 144). Workers' dose records are the dosimetry service's, kept
   until age 75 and 30 years at least (Art 43(3)), outside the game.
6. **Equipment checks.** Each ionising machine passes a QA test every
   twelve months (*game value*), recorded in `mach_maintenance` with
   its next due date, and an expert check at least every five years
   (StrlSchV § 88(4)). A machine past its QA date is not used.
7. **Critical machine alerts** (an MRI's helium or compressor, a
   quench) are acknowledged by the biomedical engineer within four
   hours (*game value*, from Philips' e-Alert response times).
8. **Retention.** Images, reports and the chart: five years, as the
   clinic's records (D280, rule 9; Tierärztekammer Nordrhein § 2(6),
   technical records included). Raw vitals and readings: the on-site
   window, then the vault, whose own retention is outside the game.
   Logs: twelve months. Maintenance and QA: the machine's life and
   five years (*game value*).
9. **Vendors' access.** A vendor's service account reaches `biomed`
   only, through its own role, never as a superuser, its password a
   secret the clinic sets. It never reaches `pacs` or `vitals`.
10. **Least data to the vault.** A shipment carries the table's
    `internal` columns only: a vitals row by its session id, never the
    animal. Cold storage processes it on the clinic's behalf (GDPR Art
    28, as the lab is for the practices).
11. **Aggregates first.** No day ships before what the clinic keeps
    from it exists on site: the chart for the vitals, the daily
    aggregate for the readings (cold storage 2, D297).

**What the data model took from these rules**: the report's kinds and
the superseding row; the identity columns with the standard's form; the
operator, restrainer and companion on a study; the QA due date and the
maintenance kinds; the critical events' acknowledgement; the chart kept
apart from the raw data; the two `SECURITY DEFINER` functions.

## The producer profiles (step 6)

Built on the ruled frictions (D264–D271, D276, D277, D288, D296–D298,
D303) and following the core's and the lab's manner: volume streams,
and work streams whose rate is a capacity; SQL's input types with
`choice` (D303); per-row variation by a hash of the row's id, never
`random()` (D117); readable fragments with no planted fault (D276).
This step holds what the machines and their systems write into their
three databases. The flows to and from the core, and the shipping, are
purposes (step 7).

### The applications and their nodes (D276)

| Application | Node | Connections, roles | What it does |
|---|---|---|---|
| The machines and their systems | `equipment`, a scheduler node (O196) | `pacs`: `machines:5432/pacs`, `mach_pacs_app`; `vitals`: `machines:5432/vitals`, `mach_vitals_app`; `biomed`: `machines:5432/biomed`, `mach_biomed_app`; `clinic-api`: HTTP (D267, D303) | the PACS and its worklist, the modalities, the central station and its monitors, the machines' telemetry and logs, biomedical engineering's screens; the identity and census jobs reading the core's lookup API |
| The partition jobs | `machines`' `pg_cron` (D206, D207) | `vitals` and `biomed`, as `mach_maint` | partitions created ahead |

One node standing for every machine keeps the node count down (D263,
D304), the cost stated in [Nodes and capacity](#nodes-and-capacity-first).
The fragments are written for the node names `equipment`, `machines`
and `clinic-api`; the GM renames them as the scenario does.

### Rates at intensity 1.0

Volume streams:

| Key | Connection | What one call writes | Rate | Shape | A day |
|---|---|---|---|---|---|
| `vitals.sample` | `vitals` | one raw row for every open session, set-based, each value its session's baseline varied by a hash of the session and the time | 360/h | even, `flat` | about 52 000 rows |
| `vitals.alarm` | `vitals` | an alarm on an open session: physiological (four in five) or technical, high, medium or low | 3/h | poisson, `flat` | about 72 |
| `vitals.anaesthesia.start` | `vitals` | a session on a free anaesthesia monitor (17–20, the equine theatre's for horses, 20 for a study under anaesthesia), for a census stay with no open session, picked by a hash | 1/h | poisson, `theatre` | 10 a weekday, 1 a night |
| `biomed.readings` | `biomed` | one row for every machine with telemetry, set-based, its channels by its kind | 60/h | even, `flat` | about 15 800 rows |
| `biomed.events` | `biomed` | a machine's event: info (80 %), warning, error, a critical one in a few hundred; an operator's staff id for imaging and analysers | 10.4/h | poisson, `imaging-day` | about 250 |
| `biomed.maintenance` | `biomed` | a service visit, a calibration or a QA test on a machine due, by its vendor or the biomedical engineer | 0.06/h | poisson, `office` | under 1 |
| `pacs.study.unscheduled` | `pacs` | an urgent study acquired on a modality before its entry exists, the animal typed | 0.01/h | poisson, `flat` | about 1 a week |
| `pacs.worklist.cancel` | `pacs` | an entry still scheduled cancelled by the imaging team (a sent request's cancellation, O198), its reason | 0.01/h | poisson, `imaging-day` | about 1 a week |
| `pacs.report.addendum` | `pacs` | an addendum superseding a final report | 0.02/h | poisson, `reporting` | about 1 every three days |

Work streams:

| Key | Connection | What it takes and writes | Capacity | Shape | Follows |
|---|---|---|---|---|---|
| `pacs.worklist.schedule` | `pacs` | the oldest `new` entry with its identity: scheduled on an in-service machine of its modality and species group; urgent at once, routine within two working days (a slot by a hash) | 10/h | `flat` | about 11 a day |
| `pacs.study.acquire` | `pacs` | the oldest scheduled entry due on an in-service machine: its study (the worklist's identity, the procedure's minutes, series and images by modality, size, a radiographer 52–55, the exposure and the restrainer for an ionising one, a companion present in about one in ten); the entry `completed` | 6/h | `imaging-day` | about 11 a day |
| `pacs.study.reconcile` | `pacs` | the oldest unscheduled study: matched to the scheduled entry of the same typed `patient_id` and procedure within the day, `reconciled`, the entry `completed`; no match after a day, `unmatched` | 2/h | `office` | about 1 a week |
| `pacs.report.preliminary` | `pacs` | an urgent study with no report: the duty vet's preliminary, signed at once | 4/h | `flat` | about 3 a day |
| `pacs.report.final` | `pacs` | the oldest acquired study with no final: the imaging specialist's report (26–28), signed; the study `reported` | 4/h | `reporting` | about 11 a day |
| `vitals.alarm.ack` | `vitals` | the oldest unacknowledged alarm raised a minute ago or more: acknowledged by a nurse | 20/h | `flat` | 72 a day |
| `vitals.anaesthesia.end` | `vitals` | the oldest anaesthesia session started 90 minutes ago or more (a hash adds up to an hour): ended by staff | 6/h | `flat` | 11 a day |
| `biomed.events.ack` | `biomed` | the oldest unacknowledged critical event: acknowledged by the biomedical engineer within four hours (rule 7) | 1/h | `office` | rare |

Reads: `pacs.mwl.query` (a modality's worklist for today, the C-FIND
each modality runs; 120/h, even, `flat`), `pacs.viewer.open` (a study's
series and reports, a vet reading them; 40/h, poisson, `clinic-day`),
`vitals.station` (the central station's screen, every open session's
last minute; 60/h, even, `flat`), `biomed.dashboard` (each machine's
latest reading and open events; 12/h, even, `office`).

Fixed-time operations:

| Job | Where, when | What |
|---|---|---|
| `mach.identity` | `equipment`, `* * * * *` | the `new` entries lacking identity: each animal read from `clinic-api` (`GET /animals/{id}`, `/owner`) and its patient id, name, species, breed, sex, born on, natural identifiers and the owner's name written; a script job holding the `pacs` connection and an HTTP one (D303), as the lab's `lab.identity` |
| `mach.census` | `equipment`, `*/5 * * * *` | `GET /stays?current=true` on `clinic-api` (O197): `mach_census` upserted, rows no longer current marked left; an intensive-care session opened on a free monitor of the species group for each new stay a hash picks (one in three), and the session of a stay that left ended (`ended_by` `census`) |
| `vitals.chart` | `equipment`, `*/5 * * * *` | the chart's rows: every open anaesthesia session's last five minutes, and at minute 0 every intensive-care session's last hour, set-based from the raw rows |
| `vitals-partitions` | `machines`' `pg_cron`, `0 22 * * *`, as `mach_maint` | `mach_create_partitions(3)` in `vitals` |
| `readings-partitions` | `machines`' `pg_cron`, `5 22 * * *`, as `mach_maint` | the same in `biomed` |
| `events-partitions` | `machines`' `pg_cron`, `0 22 25 * *`, as `mach_maint` | next month's `mach_events` partition |

`mach.identity` and `mach.census` add to `clinic-api` about 11 identity
pairs a day and 288 census calls, against the lab's
identity job.

### The business hours (shapes)

| Shape | Hours |
|---|---|
| `imaging-day` | Monday to Friday 08:00–18:00 at 1.0, Saturday 08:00–12:00 at 0.6; every other hour at 0.1, the on-call radiographer's urgent studies |
| `reporting` | Monday to Friday 08:30–18:00, Saturday 09:00–12:00: the imaging specialists |
| `theatre` | Monday to Friday 08:00–18:00 at 1.0; every other hour at 0.1, emergency surgery |
| `flat`, `office`, `clinic-day` | the core's ([vet-core](vet-core-domain.md#the-business-hours-shapes)) |

### The partners the part meets

Cold storage only, on the partners' shared `api` node under its own
hostname (D296, D308), through `cold-storage-archive` (step 7). It
holds two new data types, `vitals` and `machine-readings`, beside the
core's and the lab's `wal` and `basebackup`. The vendors are third
parties with an account (`mach_service`) and no node in v0.5. A
vendor's remote-service partner, and a teleradiology service reporting
the night's studies, are named for later.

### The history before T0 (D279)

As the core's: the year ramps from about 60 % of today's volume to
today's, on the shapes above. Every imaging request of the core's
history has its entry, its study and its final report, except the last
day's: those are `sent` in the core, and here scheduled, acquired or
reported preliminary, matching. The six unmatched studies are spread
over the year. Each history session lies on a stay the core's function
gives (O197), its chart and alarms loaded, its raw rows only within the
window. The intensive-care sessions open at T0 are those of the stays
current at T0, about five. The events cover the year in monthly
partitions, and the readings' and vitals' window holds the last full
day and today up to T0. Partitions exist three days ahead, and next
month's for the events.

Cold storage's manifests for every history day before the window, two
types a day, are planted in the partners' database by
`cold-storage-archive`'s material (cold storage 3). Each manifest
declares and receives the day's count by the documented function of
the day, so the vault's graph shows the year's ramp and its Sundays.

### Cold storage (D297)

| Type | Rows a day | On site | Waits for | Ships |
|---|---|---|---|---|
| `vitals` (`mach_vitals`) | about 52 000 | today and the last full day | the chart (every five minutes, so complete long before) | nightly, 00:40 |
| `machine-readings` (`mach_readings`) | about 15 800 | today and the last full day | the daily aggregate, computed by the purpose before shipping | nightly, 00:40 |
| Everything else | about 700 | the whole game | | never |

`vitals` is above the threshold of about 50 000 rows a day (D296).
`machine-readings` is below it and ships by the owner's direction for
the lab's machines (D288). Both are the GM's call per scenario (D297,
O201). The `machines` node ships a nightly `basebackup` to the vault
and no `wal` (O200).

### Growth, for the GM notes (D298)

At intensity 1.0, on `machines`:

| | Rows | Size |
|---|---|---|
| A day, on average | about 68 500 new rows, 67 800 of them shipped the next night; about 100 updates | about 10 MB with indexes |
| An hour, on average | about 2 850 | about 0.4 MB |
| The busiest hour, a weekday morning with four theatres | about 4 100 | about 0.6 MB |
| A Sunday | about 90 % of a weekday: intensive care and the machines run every day | |

The window holds about 20 MB. **When the shipping stalls**, the disk
grows by about 10 MB a day, so 2.25G is about 200 days away: the disk
is never this part's problem within an aging. The witnesses of a
stalled shipping are the vault's graph, the partition count and the
`ops.shipments` trace (T220). The WAL adds about 50 MB a day.

### Points for the owner (step 6, ruled, D319)

1. **One producer node**, `equipment`, with three connections and an
   HTTP one; the partition jobs on `machines`' `pg_cron`.
2. **The census from the lookup API**, every five minutes, a new
   endpoint on `clinic-api` (O197), the central station's ADT mirror,
   and the core's stays as functions of their id for the history.
3. **The hours**: imaging on weekdays and Saturday mornings, urgent
   around the clock; reporting on weekdays; theatres on weekdays,
   emergencies at night; the monitors and machines every hour.
4. **The rates**: about 11 studies, 13 sessions and 68 500 rows a day,
   the monitors at a row every 10 seconds, the machines at one a
   minute.

## Purposes (step 7, ruled, D319)

No existing purpose fits as built. Two are added (D319): one new, one the
generic purpose cold storage named and nobody had drafted yet. They are
in v0.4's format compressed, with D307's extensions, for
[clinic-purposes.md](clinic-purposes.md#16-the-parts-purposes-11-to-16)
to list (purposes 13 and 14 there, D324). Named for later: **the release to the portal** of final imaging
reports, with `vet-portal` (D304), and a monthly machine-use figure for
the head office, if the owner wants one.

### `vet-imaging-orders`: the imaging requests and their reports

**Kind**: round trip inside the centre, like `vet-lab-centre-orders`
(clinic-purposes 5). There is no API node: the integration engine
writes the order into the PACS's worklist, as an HL7 order to a RIS
would, and reads the reports back.

| | |
|---|---|
| Who asks | the customer (the core) |
| Request | `post-imaging-orders`: each imaging request `requested` whose consultation has closed, one worklist entry: the accession, the request, consultation, animal, requesting vet, study code (the procedure), priority |
| Correlation key | `accession`, `I-<request id>`, unique on `mach_worklist`: a retry finds the entry and writes no second |
| Expected answers | the entry at once; later, the study's final report signed, or the entry cancelled by the imaging team |
| Timeout, then | the entry not written: retried at the next run with the same accession; a request `sent` without a final past its turnaround (urgent 18 hours, the next working morning; routine two working days and one for the report): an `ops.incidents` row, once |
| Reactions | the request `sent` after the entry commits; `resulted` on the final; `cancelled` with the reason on a cancelled entry (O198) |

**Jobs** (on `interfaces`):

| Job | Cadence | What it computes |
|---|---|---|
| `post-imaging-orders` | `* * * * *` | the requests to post; each entry inserted in `pacs` (`ON CONFLICT (accession) DO NOTHING`), then the requests `sent` in `clinic`, the `pacs` commit first |
| `fetch-imaging-reports` | `*/5 * * * *` | from `pacs`, the final reports signed and the entries cancelled since the watermark: each request `resulted` or `cancelled`, the copy in `ops.imaging_results`, the watermark advanced; overdue ones escalated |

**Trace**: `requests` (state), `mach_worklist` and `mach_reports`,
`ops.imaging_results` (request, accession, final signed at, copied at),
`ops.watermarks`, `ops.incidents`, `ops.runs`; the runner's log.

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| IO1 | Every imaging request of a consultation closed since the judged moment is `sent` with its entry within 5 minutes of the close, 2 for an urgent one, or `cancelled` | triggers | about 11 a day, urgent ones at night |
| IO2 | No request has two worklist entries | runs | every retried post |
| IO3 | Every final signed since the judged moment has its request `resulted` within 10 minutes, and no request is `resulted` on a preliminary | runs | about 11 a day, in reporting hours; preliminaries at night |
| IO4 | End to end: every imaging request posted since the judged moment has its final within its turnaround, or is cancelled | end-to-end | the urgent ones by the next morning |

**Data moved**: request, consultation and animal ids and the study code;
no identity leaves the core with the order (the PACS reads it from the
lookup API, D266).

**Roles**: `vet_interfaces` on `clinic` as ruled (it reads `requests`
and `consultations`, writes `requests`' state); `mach_orders` on `pacs`,
new: reads `mach_worklist` (accession, request, state), `mach_reports`
(study, kind, status, signed at, supersedes), `mach_studies` (worklist,
state); inserts into `mach_worklist`; writes `ops.*`.

**Candidate faults**: T227 to T233 (step 8).

### `cold-storage-archive`: the readings to the vault

**Kind**: round trip, generic (cold storage 2, D296), fitting any
domain that ships; `vet-machinery` its first user, with two types.

| | |
|---|---|
| Who asks | the customer |
| Request | `ship-partitions`: for each type, each daily partition older than the window, after its aggregate: a header (shipment id, type, rows declared, the day) and the rows as NDJSON, `internal` columns only (rule 10), posted to the vault's `POST /shipments` |
| Correlation key | the shipment id, `<type>-<day>`, sent again on a resend (cold storage 3: the same id replaces its manifest) |
| Expected answers | a receipt with the rows received |
| Timeout, then | no receipt within 60 seconds, or rows received short of the rows declared: the partition kept, resent at the next run with the same id; still unshipped at 06:00, an `ops.incidents` row |
| Reactions | on a matching receipt, `mach_drop_shipped(day)` detaches and drops the partition; the shipment recorded |

**Jobs** (on `interfaces`):

| Job | Cadence | What it computes |
|---|---|---|
| `ship-partitions` | `40 0-5 * * *` | the first run ships, the later ones resend what is unreceived, a no-op when nothing is left; for `machine-readings`, `mach_readings_daily` for the day first |

**Trace**: `ops.shipments` (type, day, shipment id, rows sent, rows
received, attempts, posted at, receipt at, dropped at) in `vitals` and
`biomed`; `ops.runs`, `ops.incidents`; the vault's manifests and page,
which the players read through the bastion (D296).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| CA1 | No partition is dropped without a receipt whose rows received equal its rows | runs | each night |
| CA2 | One manifest per type and day | runs | each night, every resend |
| CA3 | A readings day's aggregate exists before its partition is dropped | runs | each night |
| CA4 | End to end: every day written since the judged moment appears in the vault with rows received equal to the rows declared, by 06:00 the night after the window, and no partition older than the window stays on site | end-to-end | the first night after the fix |

**Data moved**: `mach_vitals` rows (session id, time, measures) and
`mach_readings` rows, all `internal`, to a third party.

**Roles**: `mach_archive`, new, on `vitals` and `biomed`: reads
`mach_vitals` and `mach_readings`, writes `mach_readings_daily` and
`ops.*`, `EXECUTE` on `mach_drop_shipped`; no table ownership. The
vault's credential is a secret.

**Material**: `history.sql` plants the history days' manifests in the
partners' database (cold storage 3), by the documented daily counts.

**Candidate faults**: T219 to T226, T236, T237 (step 8).

### What `interfaces` gains

Connections: `pacs` as `mach_orders`; `vitals` and `biomed` as
`mach_archive`; HTTP to `cold-storage`. Four jobs, one a minute, one
every five minutes, one six times a night: light, and latency-bound
only for the urgent orders (D306, point 2).

## Traps (step 8)

No owner checkpoint (D309): a scenario's faults are the GM's to select.
Columns as [clinic-traps.md](clinic-traps.md) reads them; D290's
classes D, V, M. The rules on rare flows and cascades bind here too
(D306 point 6, D286). The rare flows here are unscheduled studies, cancellations,
addenda, critical machine events and downtimes: a fault on them is
planted only with a story that raises their rate from T0. The cold
storage traps of [cold-storage.md](cold-storage.md) 4 appear here
with machinery's tables.

### 1. The consolidated instance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T200 | `CONNECT` left to `PUBLIC` on the three databases (PostgreSQL's default) | every machine role, and the vendors' account, logging into every database: the consolidation's separation is gone | `\l`'s privileges; a login of `mach_biomed_app` into `pacs`, at once | the databases' grants | new | M |
| T201 | A vendor's recommended setting applied to the shared instance (`synchronous_commit = off` or `fsync = off` "for the monitors' inserts") | every database's durability, the PACS's index among them | the settings, at once | `postgresql.conf` | new | M |
| T202 | The vendors' service role a superuser with the vendor's default password | the whole instance open to an outside party, `pacs` and `vitals` included | `\du` and a login with the documented default, at once | the role | adapts `pg-role-superuser` | M, V when the story exposes it |
| T203 | `monitoring` not chosen on `machines` (D289) | its exporter failing to log in, the machinery dark on the dashboards | the exporter's errors, at once | the topology's options | the fault built for T10 | M |
| T204 | Statement logging or pgaudit parameters on `machines` | owners' names from the identity job's writes in the server log (rule 4) | the log, at once, each new entry | `postgresql.conf` | adapts the held `governance-statement-log-personal` | M |

### 2. Data and identity

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T205 | A sequence left below its loaded range on `mach_worklist` or `mach_studies` | the first live entry or study failing on a duplicate key: no imaging after T0 | the runner's or the producer's errors, at once | the sequence | new (as T14) | D |
| T206 | The census adding stays and never marking those that left | intensive-care sessions open on discharged animals; their monitors never free, the next patients unmonitored | open sessions whose stay is no longer current, at each discharge (about 3 a day from intensive care) | the census job's script (reported: the producer's), then the data | new (two places for one fact) | V |
| T207 | Unscheduled studies reconciled by animal name and species rather than patient id | images filed to another animal of the same name; its report on the wrong request | reconciled studies whose patient id differs from their entry's | the producer (reported), then the data | new | D when it lands; a rare flow, with a story |
| T208 | No partition created ahead: the `vitals-partitions` job unscheduled or failing | rows from midnight in `mach_vitals_default`, never shipped, the chart's reads slower; without a default partition, the inserts failing and a night's vitals lost | rows in the default partition at 00:00; `cron.job_run_details` | `cron.job`, then the partitions and the rows moved | new | M; D without a default partition |
| T209 | A machine id crossing parts wrongly: a retired or down analyser still in `lab_batches`, a booking of a down machine | the lab's results from a machine out of service; the radiographer's slot on a machine that cannot run | `lab_batches.machine_id` and bookings against `mach_machines.status` | the registry, the other part's data | new | M |
| T210 | The core's mistyped chips reaching the worklist (T13) | other patient ids matching no animal's chip | the worklist against the core's function | the record (a finding) | the domain's own | M, or false-alarm material |
| T211 | The reconciliation's capacity cut by a key | unscheduled studies piling unreconciled, their requests `sent` for ever (IO4) | studies `acquired` with no entry older than a day | the producer (reported; its key rides the schedule) | new | V, a rare flow |
| T212 | An addendum written as an update of the final (rule 2) | the first report lost; the portal's copy different from the PACS's | finals with an amendment and no superseded row | the producer's key, a trigger | new (as T22) | M, a rare flow |

### 3. Governance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T213 | The patient's name in the machine logs: a modality's study-start event carrying Patient's Name in `mach_events.message` | the owner's surname in the logs, kept a year and read by the vendors (rules 4, 9) | `mach_events` messages, at each study (about 11 a day) | the producer's event format (reported), then the logs purged | new | M |
| T214 | The vitals shipment joined with its session's animal (id, name) | customer-linked data sent to a third party (rule 10) | the shipping query and the runner's log; never the payload, which the vault discards | `ship-partitions`' query | new | M |
| T215 | `mach_orders` or `mach_archive` over-granted (every table, or the owner's membership for the detach) | the integration engine able to rewrite the archive; the archive role able to alter any table | the grants, at once | the grants | new | M |
| T216 | The vendors' account granted on `pacs` and `vitals` | the vendors reading owners' names and the animals' vitals (rule 9) | the grants and `CONNECT`, at once | the grants | new | M |
| T217 | An ionising machine past its QA date still acquiring (rule 6) | studies on a machine out of compliance | studies on a machine whose `qa_due_on` has passed, every day | the registry and maintenance (the biomedical engineer); the players report | new | V |
| T218 | Critical machine events unacknowledged past four hours (rule 7) | an MRI's helium alert waiting a night | critical events unacknowledged after four hours | the acknowledgement's key (reported) | new | V, a rare flow |

### 4. Partitions, the time series and cold storage

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T219 | A partition dropped on any answer, the receipt's count unchecked, or on a timeout | with the vault's outage key on, a day missing from the graph or short of declared while its partition is gone: rows lost (CA1) | the graph and the manifests against `ops.shipments`, each night | `ship-partitions`' script | new (cold storage 4) | V |
| T220 | The shipping stalled: `ship-partitions` at `40 0 1 * *`, or disabled | the graph flat, partitions older than the window piling up; the disk, at 10 MB a day, never reached within an aging | the graph and the partition count, the first night | `jobs.yaml` | new (cold storage 4) | V, M at a short aging |
| T221 | A resend under a new shipment id | a day counted twice on the graph (CA2) | two manifests for one type and day, at the first resend | the script | the held `purpose-retry-without-key` (D201) | M |
| T222 | The window wrong: the day's boundary in UTC, or `<=` for `<` | today's partition shipped while still written, the late rows failing or in the default partition; or a week kept | the shipments' days against the window, each night | the script | new (cold storage 4) | D, M for the week kept |
| T223 | `DELETE` from the partition instead of detach and drop | bloat, autovacuum busy, the WAL the day's volume again, empty partitions left | dead tuples and WAL at 00:40; partitions with no rows | the script | new (cold storage 4) | M |
| T224 | The readings' aggregate computed after the drop | the day's aggregate empty (CA3) | `mach_readings_daily` with no rows for shipped days | the script's order | new (cold storage 4) | M |
| T225 | The indexes created on each partition by hand, not on the parent | the new day's partition without (`session_id`, `at`): the chart job and the station's screen scanning more of the day each hour from midnight | `pg_stat_statements` on `vitals`, rising from 00:00 | an index on the parent | new | M |
| T226 | The chart's query defeating pruning (a cast or a zone function on `at`) | every five minutes, both partitions and the default read | the plan, at once | `vitals.chart`'s statement (reported; the producer's) | adapts `pg-join-index-missing` | M |

### 5. The imaging round trip

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T227 | Requests marked `sent` before the `pacs` entry commits (`clinic` first) | requests `sent` with no entry: the study never scheduled, the vet phoning | `sent` requests with no accession in `pacs`, at each failed insert | `post-imaging-orders`' script | new (as the lab's) | D |
| T228 | The priority dropped in the mapping | a night's urgent CT waiting for the routine schedule | entries `routine` whose request is `urgent` | the script | new (as T40) | D |
| T229 | A preliminary read as final | requests `resulted` on the duty vet's preliminary; the portal later releasing an unsigned report (rule 1) | `resulted` requests whose study has no final, each night (about 3) | `fetch-imaging-reports`' query | new | V, D once the portal reads |
| T230 | The unique index on the accession dropped, then a retry | two entries for one request: one completed, the other on the modality's list for ever (IO2) | duplicate accessions, at the first retry | the index, then the data | adapts `purpose-retry-without-key` | M |
| T231 | The reports' watermark taken from the run's start | finals signed during a run missed: requests stuck `sent` though reported | finals without `ops.imaging_results` | the script | adapts `purpose-watermark-misses-updates` | V |
| T232 | Cancellations never read back | cancelled entries' requests `sent` for ever | `cancelled` entries against `sent` requests | the script | new | M, a rare flow |
| T233 | `post-imaging-orders` on business hours only | the night's emergency studies on no worklist until 08:00, typed by hand: unscheduled studies multiplying | entries created at 08:00 for requests closed at night | `jobs.yaml` | new | D |

### 6. Performance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T234 | The modality worklist query unindexed (machine, state, scheduled at) | 120 scans an hour of the whole worklist | `pg_stat_statements` on `pacs`, at once | an index | adapts `pg-join-index-missing` | M |
| T235 | The viewer's study list unbounded | a screen reading the year's studies | the statement's rows, at once | the read (reported) | adapts `scheduler-report-unbounded` | M |
| T236 | The detach without `CONCURRENTLY` inside the shipping's transaction, held across the post | the parent locked for the post's duration: the monitors' inserts waiting at 00:40 | lock waits on `mach_vitals` and `vitals.sample`'s latency, each night | the script | adapts `scheduler-transaction-held-open` | V |
| T237 | `mach_drop_shipped` or `mach_create_partitions` without a fixed `search_path` | a `SECURITY DEFINER` function a lesser role can hijack | the function's definition, at once | the function | new | M |

### False-alarm material

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "The vitals older than two days are gone" | shipped by design (D288); the chart keeps the record | the window and the vault's manifests |
| "There is an empty default partition" | a safety net, empty by design | the partition jobs |
| "The horses' MRI reports no helium" | a permanent low-field magnet | `mach_machines` |
| "The night's CT reports are only preliminary" | the duty vet's, the final next morning (rule 1) | `mach_reports` |
| "Six studies match no animal" | planted domain data, a finding to report | the studies' typed ids |
| "The vault's curve dips on Sundays" | fewer theatres on Sundays | the manifests |

## Testing in v0.5 (D314)

**A minimal fixture proving the part**, two of them, each under 30
minutes, T0 placed before the job a check needs, never waited for:

| Fixture | Nodes (with the bastion) | T0 | What it proves |
|---|---|---|---|
| imaging | `records` (`clinic`), `clinic-api`, `pms`, `machines`, `equipment`, `interfaces`: 7 nodes, about 1.5 CPU and 1.4G | a weekday, 08:50 | the three schemas and loads; the identity and census jobs on `clinic-api`; the round trip: a closed consultation's imaging request `sent`, scheduled, acquired, its final at the reporting hour and `resulted` (IO1–IO4 for urgent ones, the fixture raising emergencies in its profile layer, D264) |
| vault | `machines`, `equipment`, `interfaces`, the partners' `api` node (cold storage's hostname) and database: 6 nodes, about 1.1 CPU and 1.1G | 21:55, the shipping job moved to the next minute (D132) | partitions created ahead; `ship-partitions` shipping the day before the window, its receipt, the drop, the aggregate, the manifest on the vault's page (CA1–CA4); the census left off in the profile layer, the planted sessions sampled |

**Only the whole clinic, once, can show**: every machine's stream
beside the core's and the lab's on one CPU budget; the cross-part ids
under real load (the lab's batches, the bookings against the registry);
the first night's shipping with the vitals of a full day.

**Only v1.0's major test can show**: many nights of shipping and the
graph's weeks; a stalled shipping's partitions piling over days; the
unscheduled studies' and the census's drift over an aging; rare flows
through their cycles.

**Against the ten (D316)**: the ten build no fault on partitions or on
the shipping, which are this part's new features. This page proposed
T208 (no partition created ahead) in place of s9 (O203); s9 went to
housing's T150 instead (D325, the spec's choice under D309), so **T208
stays a trap for the GM**, and partitions and the shipping are proven by
the vault fixture's build checks only. Its short test stays written for
the day a selection takes it: fixture vault, T0 23:50: *present*, rows
in `mach_vitals_default` from 00:00; *fixed*, the job scheduled, the
partition created, the default's rows moved, the next night's shipment
complete when the job is moved. About 20 minutes.

## Loading

`gmctl load-data` runs each database's `schema.sql` and `load.sql`
into `pacs`, `vitals` and `biomed` on `machines`, as `postgres`, after
creating the databases and revoking `CONNECT` from `PUBLIC` (O195):
explicit ids in the documented ranges, each sequence set after its
range, the core's ids computed by its functions without reading
`clinic` (D302, O197); partitions for the window and three days ahead
and the events' months; the sessions unseen (D265). About 0.34 million
rows; size and time measured at the build. After the sources' loads,
`cold-storage-archive`'s material plants the history days' manifests in
the partners' database.

## Questions for the owner

**Ruled on 2026-11-03** (D319): the owner, "i agree with the
recommendations as a whole", so each is closed as recommended, except
O203 (T208 stays a trap, D325) and O198's staff ids (the core's layout,
26–28 and 52–56, D324); O195 goes to O111 as format text (D323),
confirmed as written (D326). Kept as the record of what was asked.

- **O192, the brief (step 1).** Is the proposed brief right: imaging,
  monitors and the lab's analysers, three machine systems' databases,
  reports back to the record, readings a day on site, logs with their
  own governance? *Recommended*: yes, as written.
- **O193, which machines and how many (step 2, step 4).** 28 machines
  (6 analysers, 10 imaging, 12 monitors), the patient monitors in scope
  as the heavy time series, about 11 studies and 13 monitor sessions a
  day, no pixel data. *Recommended*: yes. Without the monitors the part
  stays under cold storage's threshold and loses its customer-linked
  time series.
- **O194, one database server for the three systems.** One `postgres`
  node, `machines`, holding `pacs`, `vitals` and `biomed`, rather than a
  server per vendor. *Recommended*: yes. It is the plausible minimum
  (+0.5 CPU), hospitals do consolidate vendor databases, and the
  consolidation's costs become traps.
- **O195, a part with several databases in the format.** A scenario's
  `domains:` entry gives `at:` as a map (`{pacs: machines/pacs, vitals:
  machines/vitals, biomed: machines/biomed}`), the folder has
  `data/<database>/`. *Recommended*: yes, feeding O111. The fallback is
  one database with three schemas, which needs no format change but
  loses the database-level separation (T200, T216).
- **O196, the producer node and the exporter.** `equipment` of its own
  and an exporter: 3 nodes, 0.65 CPU, 624M. *Recommended*: yes; the trims
  (the fragments on `pms`, no exporter, `machines` at 0.25 CPU) stand
  ready, down to 2 nodes and about 0.25 CPU.
- **O197, the census from the core.** A new `GET /stays?current=true`
  on `clinic-api` (stay, animal, section, admitted, the animal's name
  and species) and the core's stays as functions of their id, so the
  monitors know who is in hospital and the history's sessions lie on
  real stays. *Recommended*: yes; `vet-housing` may need the same.
- **O198, the imaging staff and cancellations.** Core staff 61–63
  imaging specialists, 64–67 radiographers, 68 a biomedical engineer;
  a sent imaging request cancelled by the imaging team only, copied
  back, as D315 for the lab. *Recommended*: yes.
- **O199, the rules (step 5).** Final reports only released, addenda
  as new rows, the owner's name in studies by the DICOM standard, logs
  without names kept twelve months, radiation protection (the
  restrainer and the companion recorded), a yearly QA test, critical
  machine alerts acknowledged within four hours, five years for images
  and charts, vendors to `biomed` only, nothing identifying to the
  vault. *Recommended*: confirm them as realistic, with their game
  values.
- **O200, backing up `machines`.** A nightly base backup to the vault,
  no WAL archive and no standby: recovery to last night. *Recommended*:
  yes. The alternative, WAL as for the core and the lab, adds about 24
  segments a day for data that ships nightly anyway.
- **O201, what ships.** `vitals` and `machine-readings`, the last full
  day kept, shipped nightly by `cold-storage-archive` on `interfaces`.
  *Recommended*: yes, both, readings by your direction for the lab's
  machines (D288) though below the threshold.
- **O202, the purposes (step 7).** `vet-imaging-orders` (a round trip
  inside the centre, no API node) and `cold-storage-archive` (generic,
  first drafted here); the reports' release to the portal with
  `vet-portal`. *Recommended*: yes, both built in v0.5.
- **O203, the test selection.** Replace s9 (the watch scheduled by the
  superuser) with T208 (no partition created ahead), so the ten cover
  partitions and the shipping. *Recommended*: yes; if not, T208 stays
  a trap for the GM, and partitions are proven by the vault fixture
  only.

## Changes needed in shared pages

Applied on 2026-11-03 in the fold-in (D319, D323–D325), with these
differences: item 1(c)'s staff are 26–28 (imaging vets), 52–55
(radiographers) and 56 (the biomedical engineer), the core's layout
(D324); item 7 is not applied, T208 staying a trap (D325); items 9 and
12 are format text in procedure 10 (D323, confirmed by D326); `cold-storage-archive`
and `vet-imaging-orders` are purposes 14 and 13 of sixteen.

1. **[vet-core-domain.md](vet-core-domain.md), key ranges and load
   (O193, O197, O198)**: (a) an imaging request's study code is one of
   `vet-machinery`'s 30 procedure codes, drawn by the documented
   function of the request's id among the codes valid for the animal's
   species group (1–12 domestic, 13–27 horses and farm, 28–30 any),
   with the modality shares of this page; (b) `stays` 1–2 500 as
   functions of their id (animal, section, admitted at, discharged at,
   outcome), documented in the GM notes, as D302 did for requests; (c)
   `staff` 61–63 vets with specialty diagnostic imaging, 64–67
   technicians (radiographers), 68 a technician (biomedical
   engineering), beside D302's 71–80. Check this against the ranges
   the other three parts ask for.
2. **vet-core, the lookup API (O197)**: `clinic-api` gains `GET
   /stays?current=true` (stay id, animal id, section, admitted at, the
   animal's name and species); `vet_lookup` gains a column grant on
   `stays` (id, animal_id, section_id, admitted_at, discharged_at). Its
   callers gain `vet-machinery`'s `mach.identity` (about 11 pairs a day)
   and `mach.census` (288 calls a day).
3. **vet-core, lifecycle (O198)**: the `Request` row reads "once
   `sent`, by the lab or, for imaging, by the imaging team, copied
   back"; the "Where the parts press" row for `vet-machinery` adds the
   study codes, the stays as functions and the census.
4. **[vet-lab-domain.md](vet-lab-domain.md), machines 1–6**: the
   mapping is 1–2 haematology, 3–4 biochemistry, 5 blood gas, 6
   coagulation; `lab.qc.night`'s on-call analysers are 1, 3 and 5. The
   lab's analysers' telemetry and events are `vet-machinery`'s, with no
   row-level match to `lab_batches` (a fault leaning on one brings its
   own material).
5. **[clinic-purposes.md](clinic-purposes.md)**: add 11
   `vet-imaging-orders` and 12 `cold-storage-archive` from this page;
   section 1's sentence on `cold-storage-archive` becomes "fits
   `vet-machinery`, its first user"; section 3's `interfaces` row gains
   `pacs` as `mach_orders`, `vitals` and `biomed` as `mach_archive`,
   HTTP to `cold-storage`; the roles table gains `mach_orders` and
   `mach_archive`; the `ops` schema exists in `pacs`, `vitals` and
   `biomed` too.
6. **[clinic-traps.md](clinic-traps.md)**: a section or a pointer for
   T200–T237 and the false-alarm lines; section 4's "wait for
   `vet-machinery`'s step 8" now points here.
7. **[clinic-test-selection.md](clinic-test-selection.md) (O203)**: s9
   replaced by T208, its fixture `vault` (`machines`, `equipment`,
   `interfaces`, the partners' `api` node and database), T0 23:50, its
   short test as above; s9 returns to the traps.
8. **[clinic-capacity.md](clinic-capacity.md)**: the `vet-machinery` row
   becomes 3 nodes (`machines`, `equipment`, an exporter), 0.65 CPU,
   624M, 2.44G of disk, all on armenelos, with its three trims; the
   VPS untouched.
9. **[formats.md](../../formats.md), the procedure's section 5, O111
   (O195)**: a part may have several databases: `domains:` `at:` as a
   map from the part's database names to `node/database`; the folder's
   `data/<database>/schema.sql` and `load.sql`; classification keys
   stay `<table>.<column>`, unique across the part, the copy adding
   each table's database; the loader creates the databases and revokes
   `CONNECT` from `PUBLIC`.
10. **[replication.md](replication.md) 2 (O200)**: `machines` ships a
    nightly `basebackup` to the vault, no `wal`.
11. **[cold-storage.md](cold-storage.md)**: its first two data types
    named, `vitals` and `machine-readings`; the history's manifests
    planted by `cold-storage-archive`'s `history.sql`; a note in 4 that
    at moderate rates a stalled shipping shows on the graph and in the
    partition count long before the disk.
12. **The scenario-format checks**: a part's `SECURITY DEFINER`
    functions with a fixed `search_path` (T237), checked at the build.

## Cross-part assumptions

Kept minimal, each at the boundary:

- **`vet-scheduling`** books imaging machines 7–16 by `machine_id`
  (`mach_machines.bookable`), and theatres as rooms with their monitors
  in them. The PACS reads no booking in v0.5: `mach_worklist.booking_id`
  stays empty unless scheduling defines a flow filling it.
- **`vet-housing`** reads nothing of this part; intensive-care vitals
  are not on the displays in v0.5. It may share the census endpoint
  (O197).
- **`vet-portal`** releases final imaging reports only (rule 1),
  through the release purpose it drafts.
- **`vet-lab`** uploads its batches with `machine_id` 1–6 by this
  page's mapping.

## Open points

- **O111**: the domain format, finalised in v0.5's master spec (D291),
  with O195's several databases and the composition rules feeding it
  (D322, D323, [procedure](domain-procedure.md) 10).
