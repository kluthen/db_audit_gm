# v0.5 — producer profiles against v0.3's scheduler (O113)

Status: draft v3. Ruled by the owner on 2026-11-01: merging (1, D264),
periodic reports (4, D265, revised by D269), identity across systems (7,
D266), API nodes, what they do and what players reach on them, and
round trips (8, D267, D268, D270, D271). Frictions 2, 3, 5, 6 and 10 carry
recommendations, (proposed) until he rules on them
([open rulings](#open-rulings)); 9 and 11 wait for their parts.

The owner, on 2026-11-01: "Let's begin working on the clinic domains and
the frictions points between producer profiles and v0.3."

A domain's **producer profile** is how its data arrives: the repository
fragments (`queries.yaml`, `builders/`), the schedule fragment
(`schedule.yaml`: connections, streams, shapes) and the fixed-time
operations (`jobs.yaml`) under `producers/`
([procedure](domain-procedure.md) 1). This document lists the places
where profiles, as the shop built them and as the clinic will need them,
meet v0.3's scheduler badly. Each friction has the evidence that it is
real, the options and a recommendation.

Read for it: the shop as built (`domains/shop/`, its `producers/` and
`docs/gm.md`), the v0.4 fixture that consumed it
(`tools/tests/fixtures/fixture-campaign/`, the shape chunk 16's scenario
copies; the scenario itself is built in v0.4's wave 4), the scheduler
0.2.0's program (`bricks/scheduler/program/gm_scheduler/`), the loader
(`tools/gm/model.py`, `tools/gm/render.py`, `tools/gm/aging.py`),
[v0.3's master spec](../v0.3/master-spec.md) 7.1 and 8, and the archived
[scheduler](../../archive/v0.3/scheduler.md) and
[load and capacity](../../archive/v0.3/load-and-capacity.md) drafts.

## Summary

| # | Friction | State |
|---|---|---|
| 1 | Fragments are merged into a node's files by hand; collisions are lost silently | ruled: `gmctl compose` (D264) |
| 2 | The hidden `schedule.yaml` (D130) against a profile readable in the catalogue (D13) | open ruling 1 |
| 3 | Absolute intensity (D32) against rates the domain states | open ruling 2 |
| 4 | Weekly, monthly and yearly cadences real time cannot age (O22) | ruled: periodic reports, their past periods planted, no run on demand in v0.5 (D265, D269) |
| 5 | Richer input types than v0.3's generators | open ruling 3 |
| 6 | Composites: a core and parts onto one producer node or several | open ruling 4 |
| 7 | Keys shared between the core and its parts | ruled: the core the system of record, natural identifiers (D266) |
| 8 | Inbound flows: round trips (O128) and the scheduler's other targets (D118) | ruled: an `api` brick that only answers, its database side the players' (D267, D270, D271), an HTTP driver, the lab a consumer-producer (D268) |
| 9 | Many small consumers that all look alike (the housing displays) | carried to `vet-housing` |
| 10 | Several sites in different time zones | open ruling 5 |
| 11 | Data growth over the aging (the machinery's readings) | carried to `vet-machinery` |

## 1. Merging fragments (ruled, D264)

**What.** A domain's fragments are not used in place: the GM copies them
into a scheduler node's seed files at design time and adapts them (D23,
D215). Where several sources feed one node, they are merged.

**Evidence.**

- `fixture-campaign`'s `crm` node merges three purposes' runner
  fragments by hand; its `schedule.yaml` header records it: "the two
  fragments' shop_crm connection kept once; the scenario's intensity
  added". The shop's fragments are "written for the node names `pooler`
  and `db` and the database `shop`; rename them as the scenario does"
  (`docs/gm.md`, "The producer").
- PyYAML keeps the last of two equal keys: two fragments both defining a
  query key, a connection `app` or a shape `business-hours` give one,
  the other gone without a word (checked with `yaml.safe_load`). The
  scheduler refuses only two streams with the same key.
- `_check_fragments` (`tools/gm/model.py`) checks a fragment's top-level
  keys and its queries; nothing checks a merge.

**The ruling** (the owner: "bundle in a merging script that would assist
merging yaml files, and annotate when conflic arise"):

- **`gmctl compose`**, a design-time merge script, built in the same
  chunk as the format changes (procedure 6). It writes ordinary files
  into the scenario folder, which stays self-sufficient (D23).
- **Layers**, lowest first: the domain's default profile, the variant's
  profile (D263), the scenario. A higher layer wins silently; the merge
  report records every override.
- **Identical entries** merge silently.
- **A real conflict between two profiles** (two parts on one node) stops
  the merge and names both sides. The GM writes the resolution into the
  scenario's `merge.yaml`, so the merge is reproducible.
- **Prefixes**: a part prefixes its query keys, connection names and
  shape names (`lab.batch.upload`, connection `lab`, shape `lab-runs`),
  as its roles and tables (procedure 4). The conflicts left are the
  settings a node genuinely shares, its pool or its intensity.
- **Provenance**: every output entry carries a comment naming its source
  (`# from vet-lab@regional-franchise`).
- **The loader refuses duplicate keys** in the merge's inputs.

Rejected: a library the scenario references, resolved at render, and a
layer the scheduler reads; both undo D23's self-sufficient folder and,
since domains never bump (D215), would let a catalogue change alter
released scenarios.

## 2. A readable profile and the hidden schedule

**What.** `schedule.yaml` is root-only on the node, never on a volume,
never in the hand-over snapshot (D130, master spec 7.1). A domain's
schedule fragment, its rates and shapes, sits in the repository for
anyone to read.

**Evidence.**

- The scenario folders already hold their own `nodes/<node>/schedule.yaml`
  in the repository, as readable as a domain's fragment. D13 makes the
  repository a textbook: reading it is trust, not enforcement. D130 hides
  the schedule on the node, in the game, not in the catalogue.
- What a fragment can hold is narrow: `_check_fragments` refuses
  `intensity` and `timeline` in a schedule fragment ("intensity and
  timeline are the scenario's"). v0.4's faults that ride the schedule do
  so through the scenario's timeline (f2's release, f8's gateway outage,
  build plan chunk 16), never through a fragment.
- The shop keeps planted faults out of its fragments ("Tarnbeck's planted
  faults are not in the domain", `docs/gm.md`).

**Options.** a. Accept on the trust line. b. Keep profiles out of the
readable catalogue: impossible while scenarios themselves are readable.

**Recommendation.** a: a profile reveals a business's base traffic, which
the players could infer from the logs anyway (archived scheduler draft,
"What the players reach"). The rule worth writing down: a fragment never
carries a timeline, an intensity or a planted fault; the shop's practice
made general.

## 3. Absolute intensity and the domain's rates

**What.** The intensity multiplies every stream of a schedule and is
absolute, never rescaled to the playground (scheduler draft, "The
schedule", after D32). A domain states rates "at intensity 1.0, before
the shape".

**Evidence.**

- One intensity per schedule (`schedule.py`: one `intensity` key), so one
  per node: a core and a part merged onto one node share it.
- The rates are tied to the load: the shop's history holds 300 000 orders
  over fifteen days, 20 000 a day, while its `orders.place` at 40 a
  minute through `business-hours` gives about 30 000 a day; `docs/gm.md`
  explains the gap as the busy season. A clinic part whose live rate and
  history disagree with no such sentence reads as a fault.
- D32 forbids the local implementation rescaling, not the GM choosing an
  intensity at design time.

- Scale is settled (D263, [procedure](domain-procedure.md) 9): a
  variant sets a `throughput` axis, in real-world rates, absolute as
  D32 makes the intensity, beside `population` and `history`.

**Options.** a. A domain's rates are its variant's throughput at
intensity 1.0; the scenario sets each node's intensity at design time;
the GM notes state the daily volume the rates give against the
history's. b. Rates recomputed at render from the variant's axes:
against D32's rule that nothing is recomputed per playground, and
needless while each domain has one variant in v0.5.

**Recommendation.** a. Parts needing a different throughput from the
core's go on their own node (6) or have their rates adapted at copy.

## 4. Periodic reports and real time (ruled, D265, D269)

**What.** The clinic has weekly, monthly and yearly duties: herd visits
and rotas, the medicines register's extract and statements, the
antimicrobial-use report to the authority ([vet-core](vet-core-domain.md),
"Cadences"). A game ages in real time, eight hours at the least (master
spec 8.1, 8.2); no fake time, no time compression (D114, D132; O22).

**Evidence.**

- Shapes are 24 hourly multipliers, optionally per weekday (`days:`); the
  render (`_scenario_week`, `render_shape`) knows a week and nothing
  longer.
- A monthly cron is valid (`cron.py`) and the loader finds its first run
  up to 400 days ahead (`cron_first_due`), but the early check counts
  only the jobs first due before the earliest hand-over
  (`early_check_due`).
- `load-data` already loads without trace: no statement logging and
  `pg_stat_statements.track = 'none'` for its sessions (`NO_LOG_SQL`,
  `NO_STATS_SQL`, `tools/gm/inject.py`).

**The ruling** (the owner: "Weekly, monthly, yearly reporting are part
of the game"):

- **They are part of the game**: heavy data crunching on a node the
  game's standards keep weak, and an investigation for the players.
- **Past periods are planted.** The load writes past periods' input data
  and past runs' outputs before T0; none of it appears in the logs or in
  pgwatch.
- **Faults in that data** are the GM's choice. If the GM plants any, at
  least one shows a witness within the aging: through a daily feeder
  carrying it forward, a check, or a scheduled run. The others may rest
  on the planted data alone. The rule is checkable.
- **One run within the aging** is the GM's option: one weekly, monthly or
  yearly run may be scheduled inside the aging window. No run is
  expected during the players' session.
- **No run on demand in v0.5** (D269). "Run March's report now" comes
  later, probably v1.0 or after, possibly v0.6: a run on an instance
  spawned for the occasion, so the live setup is barely disturbed
  ([roadmap](../README.md#v10-to-v2-dba-work-with-bits-of-devops-d272)).
  D117 and D131 stand: nobody triggers the load, the scheduler has no
  "run now". The players investigate with their own queries on the
  planted inputs and outputs.
- **How a fix is checked** (proposed). A fault in a periodic report is
  judged on what the aging and the session produce, never on a
  periodic run during the session:
  - a fix to the report's inputs or its feeder is checked on the daily
    feeder's next run, which the players may move to verify it (D132),
    the same witness the at-least-one rule required;
  - a fix to the report's own code (its query, its transaction) is
    checked by the sealed check reading the code as fixed, and, where
    the GM placed a periodic run in the aging, against that run's
    output as the evidence the fix answers;
  - the planted past outputs stay as they are: correcting them would be
    a rerun of past periods, which waits for the on-demand runs; the
    players recommend it in their report.
- **Heavy, but never killed.** A report's weight is calibrated per node,
  as f10's was (D213), so that a normal run is never killed for memory
  on a shared host or a class laptop; a run that does run out of memory
  is a planted fault only, as D209's incident is.

**With D199.** D199 stands for v0.4's purposes: no weekly or monthly
purpose, and no fault's evidence on the load's past records alone. For
domains, from v0.5, D265 replaces it: periodic reports are in, and the
"not on history alone" rule becomes "at least one witness within the
aging", the other planted faults free to rest on the past periods.

**For the build.** pgaudit is always on in `postgres` (D261): the load's
sessions must also set it off, or its audit log would show the planting.

## 5. Richer input types

**What.** The clinic's producers need values v0.3's generators do not
make: a species mix, names of new owners and animals, identifiers
(15-digit microchips, horse and cattle identifiers), sensor readings
with noise and alarms, instrument batches of many results.

**Evidence.**

- The generators are `int`, `decimal`, a uniform `choice`, `sequence` and
  `now` (`generators.py`). No weighted choice, no distribution, no text.
- The shop works around it in SQL: `elsewhere: {int: [1, 100]}` and a
  `CASE` in the statement give its 95/5 split of destinations; names come
  from the load's lists, never from the producer.
- Builders are Python, called with the intensity, the options and the
  task's seeded `rng` (`repository.py`; `carrier_feed.py` uses it), and
  return statements: anything computable without reading the database.
  They cannot read a result.
- A change to the generators is a change to the brick: a `scheduler`
  bump. A domain's builders are its own files, copied with it.

**Options.** a. SQL-side generation, as the shop. b. Domain builders in
`producers/builders/`, for values with structure (identifiers with check
digits, readings drifting around a baseline). c. New generators: a
weighted choice first, then distributions.

**Recommendation.** a and b. c only if the clinic's fragments need the
same `int`-and-`CASE` trick over and over; a weighted `choice` would then
be the one generator to add. Work that depends on the database's state
(an instrument run over the pending samples) is SQL (`INSERT ... SELECT`),
not a builder, since builders cannot read.

## 6. Composites: one producer node or several

**What.** A core and its parts each bring fragments. They can land on one
scheduler node or several; a part in an instance of its own needs its own
connection.

**Evidence.**

- One node runs one schedule against one repository, with one intensity,
  one seed, one log (master spec 7.1). A stream holds exactly one
  connection (`schedule.py`): a single call never touches two instances.
- Only a script reaches several connections in one run (`scripts.py`),
  and a script is a job's, never a stream's, fired by cron at most once a
  minute, PostgreSQL only.
- A node costs 128M at its limit; `fixture-campaign`'s twelve nodes fit
  1.6 CPU and 1.75G (build plan chunk 13's record). Seven clinic domains
  on seven producer nodes, with their purposes' runners, cost several
  hundred megabytes before any database.
- The procedure's rule already places flows between parts in purposes
  (section 4), which run on transformer nodes.

**Options.** a. A producer node stands for **one application** of the
business: the practice-management software that writes the core,
bookings and housing is one node; the lab's information system another;
the portal another. A domain's GM notes say which application each
fragment belongs to. b. One node per domain. c. One node for the whole
clinic.

**Recommendation.** a. It is what the players would find in a real
clinic, it keeps the node count to the applications, and it puts every
cross-instance flow where the procedure puts it, in a purpose's
transformer job.

## 7. Identity across systems (ruled, D266)

**What.** A part refers to core keys by id, with no foreign key, and the
core's load generates its keys in documented ranges (procedure 4). The
producers, and the parts in instances of their own, need those keys.

**Evidence.**

- The shop's fragments hard-code its load's sizes: `customer_id: {int:
  [1, 20000]}`; `product_id: {int: [1, 1996]}`, so that `product_id +
  extra` (up to 4) stays within 2 000 products; the carriers' builder
  takes `orders: 300000` as an option. The load sets the sequences after
  its explicit ids (`setval(... 'orders' ..., 300000)`).
- Where the shop needs ids that grow, it reads them (`max(id) - back`). A
  part in an instance of its own cannot read the core's.
- The shop's producer never creates customers. The clinic's core creates
  owners and animals every day.

**Practice** (research of 2026-11-01, relayed by the coordinator):
systems avoid a central id generator and each generates collision-free
ids (UUIDv7, RFC 9562, or Snowflake-style). Healthcare joins identities
across systems with an Enterprise Master Patient Index (IHE PIX/PDQ: a
golden record and a cross-reference of each system's ids). Veterinary
software does the same through master data management, the microchip
number (ISO 11784/11785) the strong but error-prone key; links to
reference labs are proprietary, each practice mapping its own test codes
to the lab's.

**The ruling:**

- **`vet-core` is the system of record** for owners and animals. A part
  gets them through a lookup API on the core (an `api` node, D267) or a
  reference table the core syncs to it.
- **Natural identifiers carry identity across systems**: the microchip,
  a horse's UELN and passport, cattle's ear tags. They are fault vectors
  too: duplicates, a mistyped chip, orphan results.
- **An identity service** in the EMPI's manner may become a later part
  (`vet-identity`); not now.
- **Loaded key ranges** stay documented in the core's GM notes, for the
  references a part's load makes at load time.

## 8. Inbound flows: round trips and API nodes (ruled, D267, D268)

**What.** The clinic receives: external labs' results, other clinics'
requests and answers, machine uploads and logs, messages. Round trips
(D201; O128) make an acknowledgement an input the setup waits on. D118
promised message queues and APIs from v0.5, and D248 kept those the
clinic's flows need.

**Evidence.**

- v0.4's outside party is a scheduler node with the SQL driver:
  `fixture-campaign`'s `gateway` runs the customs stub as `customs_gw`,
  writing `customs_acks` straight into the shop's database every 15
  seconds, losing one acknowledgement in fifty (D214); its outages are
  timeline changes of its key.
- The scheduler has one driver, `sql/postgresql` (`schedule.py`), whose
  interface runs statements (`drivers/__init__.py`); no repository entry
  passes one call's result to the next, and scripts are jobs only,
  PostgreSQL only. No API brick exists.

**The ruling on API nodes (D267).** An `api` brick on FastAPI, Python as
the GM's other code is. The GM drops endpoint files into a folder and
the brick serves them. The scheduler gets an HTTP driver, the caller.
This is the "APIs" of D118 and D248. Its first uses: the core's lookup
API (7), the external labs, the machinery. FastAPI and uvicorn are new
dependencies: a dependency check by security-advisor gates the build
(a gate of the build plan). Message queues wait until a flow needs one.

**API nodes only answer (D270).** The API layer is not a scheduler: an
`api` node in the players' scope never acts on its own. Producers and
consumers on scheduler nodes call it whenever appropriate.

The one exception is a **third party outside the players' scope**: the
external lab, which stands for a business that is not the customer's.
The players cannot reach or edit it, and its side of a round trip
initiates: it calls the clinic back with results. Its callbacks are
still driven by its hidden schedule, so every event stays scheduled and
reproducible (D117), its outages and duplicates timeline changes
(D127).

Where the callback fires from is a build detail, provided the players
cannot reach it. Recommended: a scheduler node that is the lab's own
back end, beside the lab's `api` node. The lab's `api` node answers the
clinic's orders and stores them in the lab's database; the lab's
scheduler node reads the orders falling due and POSTs their results to
the clinic's API, through the HTTP driver (D267). The `api` brick then
needs no timer of its own, and the lab's faults (a lost, duplicated,
late or out-of-order callback, D268) are stream keys switched by the
timeline, as v0.4's customs gateway's outage is. Out of reach means no
`player` account, no route on the bastion, no place in the starter pack,
a per-node option settled with the `api` brick (D273); what a third
party is and how it enters a game is [third-parties.md](third-parties.md)
(O145). v0.4's customs gateway, which players may read, stays as built.

**What the players reach on an `api` node (D271).** They read every
endpoint file. Where the scenario makes the node fixable, they edit its
database side only: the queries, how the transactional work is
organised, session-level database settings. They never change an
endpoint itself, its route or its request and response contract. The
endpoints connect with application roles, never superusers; a change
takes effect through a reload wrapper, as on a scheduler node.

The brick's layout follows from it (proposed, for the `api` brick's
notes): each endpoint is two files of the same name in two directories,
`routes/<name>.py` (the route, its request and response models, calls
into its database module; protected) and `db/<name>.py` (its SQL, its
transactions, its session settings, the functions the route calls;
writable where the scenario makes the node fixable). Write policy is
per directory (D170), so `db/` is the one writable path, and a route
importing only from `db/` keeps the contract out of the players' reach.

**The ruling on round trips (D268).** The external lab is a
consumer-producer: it consumes the clinic's orders and produces results
later. The clinic POSTs an order and gets "accepted" with a correlation
id; the lab's stub, an API node itself, calls back hours later with the
result. Its faults: a lost callback, a duplicate, a late or out-of-order
result, a wrong correlation id, a retry without an idempotency key
(`purpose-retry-without-key`, held for round trips since D201). SQL stubs
stay where no API is needed (the exchange between two clinics, two
instances with a transformer job between them, needs nothing new).

## 9. Many small consumers that all look alike

**What.** Housing has one display per animal reading its file (D196):
some hundred consumers.

**Evidence.** Every session a scheduler node opens carries the node's
hostname as `application_name` (`pools.py`, `scripts.py`): in
`pg_stat_activity` one display cannot be told from another. A hundred
direct connections would also meet `max_connections`' default of 100
(D138).

**Options.** a. The displays talk to a display service holding a pool,
as real ones do: one stream, its concurrency the service's. b.
Connections per call, for the churn. c. A per-session `application_name`
pattern: a scheduler change.

**Recommendation.** a, unless a `vet-housing` fault needs to tell one
display from another; decided at `vet-housing`'s profile step (step 6).

## 10. Several sites in different time zones

**What.** The franchise has three centres in the country and several
abroad (D196).

**Evidence.** The customer's zone is one fixed offset, UTC plus the
shift; shapes and jobs are in scenario time, rendered with that one shift
(master spec 8.3). A job's `timezone:` is reserved for the
wrong-time-zone fault (7.1). The shop handles other zones only as
recipients' offsets in its data.

**Options.** a. Every site in the customer's zone in v0.5 (the centres
abroad in neighbouring countries of the same zone). b. Per-site offsets,
each site's schedule rendered with an extra fixed offset: a render
change, and `timezone:` no longer a fault's marker.

**Recommendation.** a, with O127's topology side.

## 11. Data growth over the aging

**What.** The machinery's readings are a time series ([brick options
review](brick-options-review.md): plain partitioned tables, D250).

**Evidence.** One row a second is about 170 000 rows over two days
([load and capacity](../../archive/v0.3/load-and-capacity.md),
"Calibrating the load"); twenty machines at one reading a second are
1.7 million rows a day, against "the data schema stays simple and the
tables small" ([platform.md](../../platform.md)) and the database's disk
reservation.

**Options.** a. Readings at a coarser grain (every ten seconds to a
minute), or one row a minute holding a batch. b. Sub-second readings with
a larger disk. Either way the profile states its growth an hour at
intensity 1.0, so the GM sizes the disk.

**Recommendation.** a, and every domain's GM notes state the growth an
hour of its producers; decided at `vet-machinery`'s profile step.

## Open rulings

Each with its recommendation; "agreed" accepts it.

1. **Readable profiles (2).** Accept them on the trust line (D13); a
   fragment never carries a timeline, an intensity or a planted fault.
2. **Rates (3).** A domain's rates are its variant's throughput at
   intensity 1.0 (D263); the scenario sets each node's intensity at
   design time; the GM notes compare the rates' daily volume with the
   history's.
3. **Input types (5).** SQL-side generation and domain builders; no new
   generator in v0.5 unless the clinic's fragments keep needing a
   weighted choice.
4. **Producer nodes (6).** A producer node is one application of the
   business; cross-instance flows are purposes' transformer jobs, or
   calls to an `api` node (D267).
5. **Time zones (10).** Every site in the customer's zone in v0.5.

Frictions 9 and 11 are decided at `vet-housing`'s and `vet-machinery`'s
profile steps.

## Questions the rulings raise

Two were settled on 2026-11-01: an API node only answers (D270), and
players reach its database side only (D271); a run on demand left v0.5
(D269). One is left, with a recommendation:

1. **The variant's profile (D264, D263).** The merge's middle layer is
   the variant's profile, which D263's manifest does not hold yet.
   Recommendation: a variant may carry fragment overrides beside its
   manifest, `variants/<name>/producers/`, holding only what they
   change.
