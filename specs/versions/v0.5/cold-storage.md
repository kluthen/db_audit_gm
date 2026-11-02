# v0.5 — cold storage: a third party for heavy data

Status: draft v1. The direction is the owner's (D288); the design below
is (proposed) throughout and awaits his ruling (O148). Linked from
[producer profiles](producer-profiles.md) 11.

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
  one partition a day, partitions created ahead. The site keeps the
  current day and the last full day.
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

An `api` node, `no-access` (D274), on the one network (D275), with three
endpoints:

| Endpoint | What it does |
|---|---|
| `POST /shipments` | takes a header (shipment id, data type, rows declared, the date range) and the rows as NDJSON; counts the rows received, discards the payload, writes a manifest and answers with a receipt (shipment id, rows received). The same shipment id again replaces its manifest, as a write to the same key would; a new id for a day already shipped adds a second manifest |
| `GET /manifests` | the manifests as JSON, filtered by data type and dates |
| `GET /` | a page graphing the rows shipped per day per data type, declared against received, drawn on the server (no script) |

**A manifest** holds what the owner asked for and no more: the data
type, the rows declared, the rows received, the date range, the time of
the shipment, and the shipment id. A few rows a day, kept in a small
store of the stub's own (where it lives is O148, with the third
parties' back end, O147).

**Before T0** the load plants the manifests of the history's days, so
the graph shows the weeks before the hand-over and not only the aging.

**Who reads it.** The players, through the read endpoint, with the
credentials the starter pack gives (D274), and through the page if the
bastion may publish it (O148); the GM, the same, and its checks read the
manifests as evidence of the customer's side ([third-parties.md](third-parties.md)
2).

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

## 5. A caution: shipped data is gone

Nothing comes back from cold storage within the game. A periodic report
(D265) needing the heavy data reads the on-site daily aggregates; its
past periods' inputs are planted as aggregates, not as raw rows. A fault
whose evidence lies in the shipped rows is unsolvable, and is not
planted.

## 6. When a domain ships, and what its GM notes say

- **Every domain's GM notes** state each producer's growth an hour at
  intensity 1.0, in rows and megabytes, and whether it ships.
- **The threshold** (proposed): a table fed continuously that grows by
  more than about 50 000 rows a day at intensity 1.0 keeps one day on
  site and ships the rest; below it, the data stays on site for the
  whole game.
- **The disk**: the GM sizes the node for the window, two days at most,
  plus the aging's slack, never for the whole game's volume.

## What O148 asks the owner

1. The design above: the job, the round trip, the manifest, the three
   endpoints, the planted past manifests.
2. The page: may the bastion publish a third party's read-only page
   (a route to `GET /` only), as a provider's console the customer logs
   into? [third-parties.md](third-parties.md) 3 has the loader refuse
   any third-party node among the bastion's routes; without the route,
   players read the JSON endpoint only. Recommended: the route, the page
   only.
3. The threshold, about 50 000 rows a day.
4. Where the stub keeps its manifests: its own small store, or the
   third parties' shared back end (O147).
