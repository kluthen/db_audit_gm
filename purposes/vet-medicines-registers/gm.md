# Purpose 7, the medicines registers: GM notes

The register of supplies and the controlled-drugs register (v0.5 master
spec 11.3, 12.1, 12.2 purpose 7; v0.5's `clinic-purposes.md`
section 11; Regulation (EU) 2019/6 Art 103(3); spec D265, D278, D280,
D300, D436): **pulled, periodic**. Published in the back office's
database `office` for the inspector and the vets to query: fed daily from
the record's standby, closed monthly. A design-time source: copy the
material into a scenario and adapt the names there.

## What it is for

The law asks the centre to record every supply of a prescription-only
medicine (core rule 2: the date, the product, its batch and quantity, the
recipient's name and address, the prescribing vet, the authorisation
number) and to keep a controlled-drugs register with periodic balances
(core rule 3). Two feeders copy yesterday's supplies and controlled
movements into `office` at night; on the 1st the month's extract per
product and each controlled batch's balance follow, on 1 January the
yearly inventory. The reports read the **standby** (master spec 11.1), never
the primary; `office` rides the primary.

## The material

Written for the clinic's mapping: `source` `records/clinic` (its jobs read
the standby, `standby`), `target` `records/office`, `runner` `backoffice`.

| File | Copied to | What |
|---|---|---|
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml), [`queries.yaml`](material/runner/queries.yaml), [`schedule.yaml`](material/runner/schedule.yaml), [`scripts/medicines_registers.py`](material/runner/scripts/medicines_registers.py) | the report runner's files (scenario layer `compose/backoffice/`) | the five jobs below; connections `clinic-reports` (`standby:5432/clinic` as `vet_reports`) and `office` (`records:5432/office` as `office_jobs`), pool 1 each |
| [`material/target/office.sql`](material/target/office.sql) | the head of the purposes' share of `records`' data file, once | `office`, `office_jobs`, `office_reader`, the database `office`, its `runs` and `regulatory_submissions`; byte-identical in purposes 5, 7, 8, 9, 10 and 12 (W4 item 5) |
| [`material/target/data.sql`](material/target/data.sql) | after `office.sql` in `records`' data file | `medicines_register`, `controlled_movements`, `register_extracts`, `controlled_balances`, `controlled_inventories`; `office_jobs` `SELECT, INSERT`, `office_reader` `SELECT` |
| [`material/history.sql`](material/history.sql) | nothing: `history:`, read from the catalogue by `load-data` | the planted past (below) |

No `ddl:`: the purpose adds nothing to `clinic`; `vet_reports` reads every
core table by vet-core's own grant.

**Names to adapt** when copying: the standby and the primary in the two
connections; `CLINIC` and `OFFICE` in the checks (the checks read the
primary).

## The jobs

| Job | Key | Cadence | What |
|---|---|---|---|
| `feed-medicines-register` (feeder) | `meds.register` | `30 1 * * *` | yesterday (local) read by `meds.register.read`: each dispensing (its owner the recipient, name and address) and each dose given (the centre), one line each |
| `feed-controlled-drugs` (feeder) | `meds.controlled` | `45 1 * * *` | yesterday's movements of controlled medicines (`meds.controlled.read`) |
| `close-medicines-register` | `meds.close` | `0 3 * * *`, acting on the 1st | the past month's extract per product: lines, quantity, an md5 checksum of its lines (`meds.close.compute`, on `office`) |
| `balance-controlled-drugs` | `meds.balance` | `15 3 * * *`, acting on the 1st | each controlled batch: opening (the previous closing, else the quantity received), movements, closing; signed by the centre's senior vet (the lowest-id vet still employed) |
| `inventory-controlled-drugs` | `meds.inventory` | `30 3 * * *`, acting on 1 January | December's closing per batch |

Each periodic job runs daily and does nothing, **writing neither output
nor `runs` row**, unless the customer's local date (`business_settings`)
is its own (spec D436). Each feeder writes its day once: a day `office`
already holds is skipped (its `runs` row says 0 written). Every run writes
one `runs` row in the transaction of its output. The scripts read the SQL
keys from the runner's `queries.yaml` at each run: **the queries are the
jobs' code**, the place a fault edits.

**The planted past** (`history.sql`, W4 item 5): from the history's first
supply (53 weeks), each feeder's day `d` when `d + 1` at its hour is before
`load_epoch`, each month's extract and balances when the next 1st's run
is, last January's inventory; each run its `runs` row. A T0 just before
01:30 finds yesterday unplanted, the feeder's to write. About 84 000
register lines, 12 000 movements, 4 600 extracts, 1 260 balances, 105
counted batches, 750 runs.

**Seen on the load** (for the GM): the core's batches received far less
than the year moves, so most planted balances close **negative**; MR4
judges the identity, not the stock.

## The invariants and where they run

| Id | Judged | Reads |
|---|---|---|
| MR1 | runs | `feed-medicines-register`'s runs; `dispensings`, `administrations`, `medicine_batches`; `medicines_register` |
| MR2 | runs | the same runs; `owners` (the dispensings'); `medicines_register`'s columns and lines |
| MR3 | runs | `feed-controlled-drugs`' runs; the controlled supplies; `controlled_movements` |
| MR4 | code | `balance-controlled-drugs`' code as loaded (`jobs.yaml`, `queries.yaml`), run read only on `office` for the last planted month; any run since the judged moment |

All on the report runner (`backoffice`), as root, `check-runs` and
`check-sql` as `gm_check` on the primary's `clinic` and `office`, each
guarding its reads (spec D432, exit 2). A day is the run's yesterday,
local. MR4 never judges the planted figures: a fix to the code leaves
them, and the players recommend the rerun (master spec 12.1).

## The faults this purpose carries

From v0.5's `clinic-purposes.md`
section 11 (the selection is the scenario's): administrations joined
through prescription lines twice (MR1; `meds.register.read`); doses given
left out (MR1); the day in UTC (MR1; the script's bounds or the query);
the owner's e-mail and phone copied (MR2); ketamine not flagged
controlled (MR3; `medicines.controlled`); the feeders reading the
primary (the `clinic-reports` connection).

## Trace

`office`'s five tables and `runs`; the runner's log (counts and dates
only, never a name).

## Fixture

`tools/tests/fixtures/fixture-reports/` (chunk 20): the bastion, `records`
(`clinic`, `office`), `standby`, `backoffice`, `lab` and the partners'
three nodes; each feeder moved to the next minute, a monthly job run on a
date not its own.
