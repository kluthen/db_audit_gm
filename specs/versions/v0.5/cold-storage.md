# v0.5 — cold storage: a third party for heavy data

Status: draft v3, ruled. The direction is the owner's (D288); the
design was ruled as drafted on 2026-11-02, with the bastion's route to
its page (D296) and the GM deciding what ships, use first (D297),
closing O148. Linked from [producer profiles](producer-profiles.md) 11.
The same stub also holds the core's WAL and base backups, as types
`wal` and `basebackup` ([replication.md](replication.md), D299). Its
stub shares the partners' one `api` node, under its own hostname,
`cold-storage` (D308).

The owner, on 2026-11-02, on the data growth over the aging: "If we're
talking about lab machineries, we will say that we keep a day on site
(but moderate the generation), and the rest get shipped to cold storage
(S3 like, and more to the point, out of the game). We may need a "cold
storage interface" in whatever maner, that allows us to "control"
what's been stored but keeping it soft (like, a simple graph of the
number of rows shipped per day)." And: "I believe the cold storage
option can be used whenever we get to generate a hefty amount of data
continuously. so the display/data access should provide minimum
information to be usefull (type of data, number of rows, date)".

## 1. What it is

Cold storage is a **third party** ([third-parties.md](third-parties.md),
D273–D275): an off-site archive service in the manner of an S3 bucket.
What the customer ships there leaves the game: nothing reads it back.
It is **generic**: any domain whose producers continuously generate a
heavy amount of data uses it, the clinic's machinery first. The GM
copies its endpoint files into a scenario like any `api` node's (D267)
and declares it in `third_parties:` with the role `round-trip`, since
each shipment is answered by a receipt (D286).

## 2. The customer's side: keeping a day, shipping the rest

- **On site**, the heavy data lives in plain partitioned tables (D250),
  one partition a day, partitions created ahead. By default the site
  keeps the current day and the last full day; a type the exercise's
  consumers read keeps longer, the GM setting its window (section 6,
  D297).
- **A shipping job** on the customer's side, in the players' scope, runs
  each night after midnight, customer time. For each data type it takes
  the partitions older than the window, sends each as one shipment, and
  on a receipt whose rows received equal the rows sent, detaches and
  drops the partition.
- **A round trip** (D286): the request is the shipment; the correlation
  key the shipment id, the data type and the day; the expected answer a
  receipt with the rows received; a timeout; the reactions: drop the
  partition on a matching receipt, keep it and resend with the same
  shipment id on a mismatch or a timeout. A generic purpose,
  `cold-storage-archive`, of the round-trip kind, fitting any domain
  that ships.
- **Aggregates first.** Whatever a periodic report (D265) needs from the
  shipped rows is aggregated on site before the shipment, in a daily
  summary table kept for the whole game (section 5).
- The job reads the database and then posts, as the external lab's back
  end does (D268): the same need of the HTTP driver (D267).

## 3. The stub's side

A partner on the partners' shared `api` node, `no-access` (D274), on
the one network (D275), under its own hostname, `cold-storage`, its
routes dispatched by that name (D308); three endpoints:

| Endpoint | What it does |
|---|---|
| `POST /shipments` | takes a header (shipment id, data type, rows declared, the date range) and the rows as NDJSON; counts the rows received, discards the payload, writes a manifest and answers with a receipt (shipment id, rows received). The same shipment id again replaces its manifest, as a write to the same key would; a new id for a day already shipped adds a second manifest |
| `GET /manifests` | the manifests as JSON, filtered by data type and dates |
| `GET /` | a page graphing the rows shipped per day per data type, declared against received, drawn on the server (no script) |

**A manifest** holds what the owner asked for and no more: the data
type, the rows declared, the rows received, the date range, the time of
the shipment, and the shipment id. A few rows a day, kept in the
partners' shared database, cold storage's own tables and role (D296,
following from D293's shared back end).

**Before T0** the load plants the manifests of the history's days, so
the graph shows the weeks before the hand-over and not only the aging.

**Who reads it.** The players, through the bastion: it routes them to
the page and the read endpoint, `GET /` and `GET /manifests`, never to
`POST /shipments` (D296; the owner: "yes the bastion must be able to
route the player to this coldstorage. keep it simple for now."), the
one stated exception to a third party's absence from the bastion's
routes ([third-parties.md](third-parties.md) 3). The GM, the same; its
checks read the manifests as evidence of the customer's side
([third-parties.md](third-parties.md) 2).

**Its own faults**, as any third party's: an outage refusing uploads,
slow answers, timeline changes of its schedule (D127). Never a root
cause inside it.

## 4. Faults it enables, on the customer's side (candidates)

| Candidate | What the players find |
|---|---|
| Deleting before the upload is confirmed | a day missing from the graph, or received below declared, while its partition is gone on site: rows lost |
| The shipping job stalled | the graph flat at zero, partitions older than the window piling up on site, the disk heading for its budget |
| Duplicate shipments | a day counted twice: a retry under a new shipment id (`purpose-retry-without-key`, D201) |
| The wrong age window | today's partition shipped while still written, the late rows lost; or a week kept on site |
| `DELETE` instead of detaching and dropping the partition | bloat, autovacuum busy, WAL volume up, the table never shrinking |
| No partition created ahead | rows falling into a default partition the job never ships |
| Aggregates computed after the shipment | a report's day empty or short |
| A shipping window shorter than a consumer needs | a report or transformation missing the rows already shipped: a cascade, its fix judged end to end (D286) |

## 5. A caution: shipped data is gone

Nothing comes back from cold storage within the game. A periodic report
(D265) needing the heavy data reads the on-site daily aggregates; its
past periods' inputs are planted as aggregates, not as raw rows. A fault
whose evidence lies in the shipped rows is unsolvable, and is not
planted.

## 6. When a data type ships (D297)

The owner, on 2026-11-02: "cold storage-ing decision depend on the usage
of the data first and might be decided by the GM: data that are needed
for transformation, reporting, etc that IS used for the exercice may not
be cold storaged, or may be storaged with an appropriate scheduling
(like storage after 2 days if the reporting / transofrmation whatever is
effective daily, something like that)."

- **The GM decides, per data type**: use first, volume second.
- **Data the exercise reads**, a purpose, a transformation or a report,
  either stays on site for the whole game or ships only after its
  consumers' cadence and a margin: a daily consumer, shipped after two
  days.
- **The threshold** (D296), about 50 000 rows a day at intensity 1.0
  for a table fed continuously, only marks a data type as a candidate.
- **Every domain's GM notes** state each producer's growth an hour at
  intensity 1.0, in rows and megabytes; and, for each type that ships,
  its retention on site and the consumers it waits for.
- **The disk**: the GM sizes the node for the retention on site plus
  the aging's slack, never for the whole game's volume.
