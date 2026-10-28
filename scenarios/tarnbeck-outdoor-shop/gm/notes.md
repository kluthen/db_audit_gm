# GM notes — tarnbeck-outdoor-shop

Sealed. Longer explanations for the feedback; the authoritative answer is
`answer-key.yaml`, and each fault's own `gm.md` (under `faults/`) has the
general background and the placement rules. Built as capture W4 item 10
proposes (spec D188), for the owner's review at G7.

## The shape of the game

A shop under its own daily load (master spec 15.2): ten defects on six
nodes, seven of the v0.3 catalog faults that live in the applications'
files and the pooler, three existing ones that gain evidence under load.
The aging is the point: most evidence is history (a batch that ran at
noon, an export that ran at 10:00, an index dropped at 08:00, dead rows
built up overnight), read in logs, statistics and Prometheus after
hand-over.

| Instance | Defect | Node | Planted | Visibility | Issue |
|---|---|---|---|---|---|
| f1 | product-code search compares the integer id with a text code (42883, one call in ten) | producer | T0 | hidden | — |
| f2 | "best days" report sorts the whole `orders` table, no bound on `placed_at` | consumer | T0 | known | I5 (propose) |
| f3 | carriers' feed resends one event in five; no unique `event_id` | producer | T0 | known | I2 (fix) |
| f4 | warehouse dashboard holds a repeatable read transaction 5 minutes | consumer | T0 | hidden | — |
| f5 | close-of-day batch at 12:00, the peak, locking every customer ~20 s | producer | T0 | known | I1 (fix) |
| f6 | accounting export in a zone 8 hours behind: 02:00 runs at 10:00 | consumer | T0 | known | I3 (fix) |
| f7 | PgBouncer pool of 3 for `shop` in transaction mode | pooler | T0 | known | I1 (fix) |
| f8 | `order_lines_order_id_idx` dropped at 08:00 | db | handover-6h | known | I4 (fix) |
| f9 | autovacuum off on `orders`, the hot table | db | T0 | hidden | — |
| f10 | `pooler:9110` missing from Prometheus' node-health job | prometheus | T0 | hidden | — |

The story hints at each hidden item without naming it: the shop's error
page "now and then" (f1); the warehouse screen's dashboard (f4); the
warehouse's packing and shipping updates on the orders (f9); "every
machine reports its own health" (f10). Every validator is green at
hand-over; nothing leaves one red. No silent tooling expectation: the
monitoring exists, and f10 is its gap (a PgBouncer exporter is a bonus
remark under f7 and f10).

**Left out, as W4 item 10 proposes**: `scheduler-update-without-where`
(its write load grows with its table for sixteen hours, and its evidence
families are carried by f9, f5 and f2).

## Write policies

| Node | Policy | So |
|---|---|---|
| `db`, `pooler` | fixable | f7, f8, f9 fixable |
| `producer` | report-only, overrides `/srv/scheduler/repository` and `/srv/scheduler/jobs` | f1, f3 (code) and f5 (job) fixable; the schedule never |
| `consumer` | report-only, override `/srv/scheduler/jobs` | f6 (job) fixable; f2 and f4 (code, an agency's) report or propose |
| `prometheus` | report-only | f10 report or propose |
| `grafana`, `exporter` | fixable | nothing planted there |
| `bastion` | report-only | — |

## The designed day (scenario time, the customer's zone)

T0 is 22:00 the evening before; hand-over 14:00; aging 16h.

| Time | What happens | Seen by |
|---|---|---|
| 22:00 (T0) | load starts; f1 to f7, f9, f10 planted (at render, f9 right after the data load) | — |
| all night | carriers' feed at 10/min, unshaped: f3's duplicates from the first minutes; the dashboard's held snapshots (f4); shop traffic at 0.1 | f3, f4 |
| 01:30 | `nightly-rollup` (right, the reference beside f6) | f6's comparison |
| 07:00 | business hours start (multiplier 0.6, 0.8 from 08:00): pool waits begin (f7) | f7 (min. 10h) |
| 08:00 (handover-6h) | `order_lines_order_id_idx` dropped by a scheduled inject run (`gmctl inject tarnbeck-outdoor-shop --playground <pg> --at <UTC instant> --instance f8`) | f8 (min. 4h) |
| 10:00 | the accounting export runs, eight hours late (designed 02:00) | f6 (min. 13h) |
| 10:00 | twelve hours of updates on `orders`, never vacuumed | f9 (min. 12h) |
| 12:00 | the peak (multiplier 1.0) and the close-of-day batch: the stall | f5 (min. 15h), f7 |
| 14:00 | hand-over; the game until 18:00 at 0.8 then 0.6 | — |

Instance minima are the loader's coverage check (spec D189): f5's first
run is at T0 + 14h, so 15h; f6's at T0 + 12h, so 13h; f7's business hours
from T0 + 9h, so 9h30 rounded to 10h.

## The load and why it is sized so

The web shop (through the pooler, role `shop_app`, shape
`business-hours`: 0.1 at night, 0.6 at 07:00 and in the evening, 0.8 in
the day, 1.0 at noon):

| Key | Rate at 1.0 | What it does |
|---|---|---|
| `orders.place` | 40/min, up to 8 at once | checkout: one statement (order, lines, stock, customer's `last_order_at`), then a 3 s hold (the payment provider) before COMMIT |
| `catalog.lookup` | 120/min | product page, category list, and f1's product-code search (1 in 10) |
| `orders.detail` | 20/min | an order and its lines: f8's lookup |
| `orders.status` | 30/min | the warehouse moves the newest orders to packed, then shipped: f9's dead rows |
| `deliveries.ingest` | 10/min, all day | f3's feed, 20% resent |
| job `close-day` | 12:00 | f5: invoicing, lifetime values, product sales, 20 s hold |

The back office (straight to `db`, role `shop_reports`, shape
`office-hours`): `reports.recent` 4/min, `reports.best-days` (f2) 20/h,
`reports.dashboard` (f4) 12/h unshaped with two at once (each 5 minutes:
one snapshot always open), jobs `nightly-rollup` 01:30 and
`accounting-export` 02:00 with `timezone_offset: -8` (f6).

- **f7's demand comes from the checkout's 3 s hold**, not from the
  database's work: at noon about 0.67 checkouts a second × 3 s = 2
  server connections busy on average, plus the rest of the shop, on a
  pool of 3 (utilisation about 0.7: frequent queueing, waits of seconds);
  at 0.8 about 1.6 (waits still visible); at night 0.2 (none). The
  database's CPU stays low, which is the complaint's "the database does
  not look busy". `min-pool-size: 6` is the design's figure (W4 item 10:
  chunk 15b measures it). The hold itself is not a fault: a sharp team
  proposes authorising the payment before the transaction, which the
  answer key credits.
- **f5 and f7 interact strongly** (chunk 14's warning): the batch locks
  every customer row for about 20 s at noon, every checkout waits on its
  customer, and the waiting checkouts take all three server connections,
  so the whole shop stops for the batch's duration, once a day. A larger
  pool (f7 fixed) leaves only the checkouts waiting; the batch at night
  (f5 fixed) removes the stall.
- **f3's sizing** (W4 item 5): at 10/min unshaped and 20% resent, a 30m
  window holds about 60 resent events, 120 duplicate rows, against the 20 × (T + 1) = 20
  needed; the early check at night reads present.
- **f2's spill**: 300 000 orders at the backup sort to about 19 MB on
  disk at `work_mem` 4MB (measured on a sandbox, PostgreSQL 17: external
  merge, about 200 ms a run); no index serves the sort (`placed_at::date`
  is not `orders_placed_at_idx`'s order), and the report returns three rows
  a day, about 50.
- **f8's cost**: `order_lines` is 121 MB, 900 000 rows; without the index
  an order's lines take a parallel sequential scan, about 30 ms on
  armenelos alone (sandbox), more under load, against 0.07 ms with it.
  The complaint says "slower", not "seconds".
- **f4** holds back vacuum on every table; `orders` is never vacuumed
  anyway (f9), so its evidence is on `customers` and `products`, which
  every checkout updates and autovacuum visits again and again ("dead but
  not yet removable").
- The checkout's own short transactions (3 s, read committed) show in
  `pg_stat_activity` as `idle in transaction` too: under four seconds,
  `application_name` `producer`. A team that tells them apart from f4's
  five-minute ones has read the view well.

## Feedback points

- **I1 (f5, f7).** Two causes, both needed: the pool (waits all through
  the busy hours, `SHOW POOLS`, the stats lines) and the batch (the noon
  stall, the lock waits in the database log at 12:00, the job's `at` in
  UTC read in the customer's zone). The best teams read the pooler's
  stats lines hour by hour and the producer's per-minute key lines around
  noon, and say why the database looked idle. Raising `max_connections`
  on the database is the classic wrong move.
- **I2 (f3).** The fix has two sides; a unique constraint alone turns
  the resends into errors (23505 in the producer's log): data right,
  client wrong. Cleaning the existing duplicates first is needed for the
  constraint and for the counts.
- **I3 (f6).** Reading `timezone: Etc/GMT+7` the right way round (the
  sign is inverted) is the trap; `sudo gm-reload-scheduler` prints the
  next run in UTC, to compare with 02:00 the customer's time.
- **I4 (f8).** The plan, the foreign key without an index, the 08:00
  step in the order page's latency; "who dropped it" is a good question
  for the customer.
- **I5 (f2).** A proposal only: the back office is the agency's.
- Hidden: f1 from any log (scheduler or database), f4 from
  `pg_stat_activity` or the autovacuum lines, f9 from `\d+` or
  `pg_stat_user_tables`, f10 from the targets page against the topology.

## Sealed checks at a glance

All read 1 at hand-over. f1 reads too soon for up to about 130 s after
any reload of the producer (a fix of f3 or f5 included); f3 is
behavioural (window 30m, threshold 0): present for 15 minutes after a
fix, then too soon, then 0 about 30 minutes after the last duplicate. f2,
f4 and f10 cannot be fixed by the players and stay at 1.

## Smoke runs and the rehearsal (test harness only)

- `smoke-scenario.sh` plants f8 at once:
  `gmctl inject tarnbeck-outdoor-shop --playground <pg> --at now --instance f8`. f4's stream ends its first call five
  minutes after the first arrival (the hold) and f2's stream runs every
  five minutes in the evening, so the smoke run needs `LOAD_MINUTES=12`
  for every stream key to have ended a call; f3 reads present only once
  the feed has run a few minutes.
- The rehearsal (chunk 15b) should put the noon peak and the batch inside
  its two hours, measure f7's waits (to confirm or change
  `min-pool-size`), the batch's stall at noon, and the footprint.
