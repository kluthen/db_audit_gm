# v0.5 — `vet-machinery`, the clinic's machines

**Drafting in progress: stopped after step 5; steps 6 to 9, the questions and the shared-page changes follow.**

Status: draft v1. Steps 1 to 9 of the [procedure](domain-procedure.md)
drafted in one pass on 2026-11-03, on the owner's instruction ("start an
agent for each part, and let them come back with problems once they're
done"). Wherever the procedure has an owner checkpoint (step 1's brief,
step 2's answers, step 5's rules, step 7's purposes, step 9's approval),
this page writes a **recommended answer**, marks it "(proposed, O<n>)"
and carries on with it. Nothing on this page is ruled. The questions
are gathered in [Questions for the owner](#questions-for-the-owner).
What this part needs from the shared pages is in [Changes needed in
shared pages](#changes-needed-in-shared-pages), for the spec-writer who
folds the four parts in.

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
| `domain.yaml`: `id` `vet-machinery`, `requires: [vet-core]`, tables and roles prefixed `mach_`, its three databases (O195), the purposes that fit | [What the part holds](#what-the-part-holds); [Purposes](#purposes-step-7) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest named after the core's variant (D301, answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/pacs/`, `data/vitals/`, `data/biomed/`: each holds a `schema.sql` and a `load.sql`, for one database each (O195) | [The data model](#the-data-model-step-4) |
| `data/classification.yaml`: every column classed, keyed `<table>.<column>` (the names are unique across the three databases) | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The business's own rules](#the-businesss-own-rules-proposed-o199) |
| `producers/`: the machines and their systems (`equipment`), the `pg_cron` partition jobs on `machines` | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; [Traps](#traps-step-8); [Loading](#loading) |

## Nodes and capacity, first

The brief turns on "each machine's own database", which could multiply
nodes. This section states the minimum first because the budget is the
hardest constraint. Core and lab already take 18 nodes (3.0 CPU,
3.2G). The whole clinic is estimated at 26–32 nodes, which uses 78–96 %
of the CPU on armenelos plus the VPS. The VPS has no room for another
database node ([clinic-capacity.md](clinic-capacity.md)).

**The plausible minimum: three nodes, all on armenelos (proposed, O194,
O196).**

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

## The brief (step 1, proposed, O192)

Built from the owner's clinic brief (D196): "horse section (housing,
dedicated machinerie, multiple specialists); farm section (same); ...
biology (lab, blood analysis machinerie, etc)"; "machinerie require
dedicated servers and databases"; "machine logs, have also their own
governance and needs". Also from his direction on data growth (D288):
"If we're talking about lab machineries, we will say that we keep a day
on site (but moderate the generation), and the rest get shipped to cold
storage". The proposed brief, for the owner to correct:

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
| Radiographer | core `staff`, `kind` `technician` (O198, staff 64–67) | performs studies, records the exposure and who restrained the animal |
| Imaging specialist | core `staff`, `kind` `vet`, specialty diagnostic imaging (61–63) | reports and signs studies, amends a final report by an addendum |
| Duty vet | any core vet on call | a night's preliminary report on an urgent study |
| Anaesthetist, nurse | core `staff` | start and end a monitor session, acknowledge alarms |
| Biomedical engineer | core `staff`, `kind` `technician` (68) | the registry, maintenance, QA, downtimes, acknowledging machine alerts |
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

**Population**, at load (proposed, O193):

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
| imaging staff and the biomedical engineer in a range | `staff` 61–68 | **yes**: as D302's 71–80 (O198) |
| cancelling a sent imaging request | the imaging team, copied back (as D315 for the lab) | **yes**: the core's `requests` lifecycle names the imaging team beside the lab (O198) |
| the analysers' ids | `vet-lab`'s `machine_id` 1–6 | the mapping, stated here (below) |
| machine ids to book | `vet-scheduling` | an assumption: it books machines 7–16 (`bookable`) |

## Proposed answers to the sketch's questions (step 2, proposed, O193)

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
| Core keys used | imaging `request_id`s among 1–17 000 by the core's function; `animal_id` 1–17 000; `stay_id` 1–2 500 (O197); staff 61–68 (O198) | as the core documents them |

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

### Plausibility points (step 4, proposed, O193, O194)

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

### The business's own rules (proposed, O199)

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
