# Fake aging's verification tools

The tools that check a fake game against what a real day leaves (v0.6
master spec 9.12 "the comparison and tells scripts", 12.1; capture W4
items 1 to 5 in `specs/versions/v0.6/wave-log.md`). Beside them:
`calibrate.py`, the calibration tool for the short real runs (9.7), and
its records in `calibration/`; `reference/`, run R's archive pointer and
`extract.sh` (12.3, spec D519).

Each tool is **copied from the research's prototype and generalised**
(research/fake-aging `10d1bc6`, `tools/research/fake_aging/`, read with
`git show`; nothing copied as is, 9.12): the prototypes hard-coded the
shop's game, node and database; here the scenario, the playground, the
nodes and the database are arguments. Each names its origin in its header.

| Tool | From | What it does |
|---|---|---|
| `tells.sh` | `m4_tells.sh` | the fixed tells on a fake game's database nodes after its restart, judged |
| `m1_dump.sh` | `m1_dump.sh` | M1: a database's state to CSV, one file a query |
| `m1_compare.py` | `m1_compare.py` | M1 against run R's, R scaled to the game's span (D586), judged |
| `m3_profile.py` | `m3_profile.py` | M3: a game's hourly Prometheus profile (`dump`) and against run R's (`compare`), judged |

The short games that run them all: `tools/tests/smoke-fake-aging.sh`
(below).

## What they share

- The scenario directory first, then `--playground <pg>`. A live game is
  read only through `tools/gmctl exec` (SQL as `postgres`, in a session
  with `default_transaction_read_only` on and unseen as the fill's: no
  statement statistics, no statement log, no pgaudit) or, for
  Prometheus, through `tools/gm/history.py`'s reader (`curl` in the
  Prometheus node); never a published port, never a write.
- Each judged point one line: `PASS  <check>: <detail>`, `FAIL  ...`,
  `SKIP  <check>: <reason>`; a figure `FIGURE  <what>: <value>`, never
  judged. The last line `<tool>: <n> passed, <n> failed, <n> skipped`.
- Exit status: 0 nothing failed; 1 a failure; 2 usage or refused, nothing
  read; 77 the reference absent where the tool needs it (its line `SKIP
  ... the reference archive is absent`).
- Run R is the reference (12.3): its M1 dump, M3 profile and table
  statistics extracted from the archive with `reference/extract.sh` into
  the untracked `reference/extracted/`, never a new real run. Run R ran
  PostgreSQL 18; the comparisons judge only counts and rates the workload
  drives, which the server's major doesn't move (D590), and name R as a
  PostgreSQL 18 reference.

## `tells.sh`

```sh
sh tools/fake_aging/tells.sh <scenario-dir> --playground <pg> --node <db node> [--node <db node> ...] [--reference --start <game T0 dir>]
```

Every primary `postgres` node the game reads (the shop `db`; the campaign
`db` and `reporting`). Refused, exit 2, without a restart record, with one
not `mode: fake`, or without `restart.at`. Per node:

| Check | Passes when |
|---|---|
| `start-time` | `pg_postmaster_start_time()` 0 to 10 s after `restart.at`, before `now()`, the same when read again at the end |
| `statements` | no `pg_stat_statements` row names `gm_vclock` or `gm_pad`; `pg_stat_statements_info.stats_reset` before `restart.at` (SKIP: no database holds the extension) |
| `stats-reset` | the shared views' `stats_reset` (bgwriter, checkpointer, WAL, archiver, I/O) and the statements' within 1 s of each other, at most 120 s before `restart.at` (D536) |
| `pg-wal` | `pg_wal`'s live total at least 90 % of `state.yaml`'s `clean_restart.wal.<node>.pg_wal_bytes`, the padding's own figure (never a day's rate) |
| `autovacuum` | per table: with `--reference` (the shop only) and `--start` (the game's M1 dump at its virtual T0), the rows updated since that T0 in the game and in run R (which started from the same T0 data); each run of a bulk statement updating the whole table in the span (the shop's `orders.close-day` on `customers`, its job's runs counted from the rendered `jobs.yaml`) one run, its rows taken out; the rest at R's runs per updated row: expected = bulk runs + (R's runs − R's bulk runs) × the game's updated rows ÷ R's, ×0.5 to ×2, one run either way (D596; the shop's `customers` 3.7, 0.85 to 8.4; what the rule leaves unexplained a `FIGURE`); otherwise at least one run when its updated and deleted rows passed its autovacuum threshold, and at most its dirtied (inserted, updated, deleted) rows over that threshold, plus one; a table whose reloptions turn autovacuum off is reported only |
| `search-path` | no routine in any database with `gm_vclock` in its `search_path` setting, no `gm_vclock` schema |

`FIGURE` only (9.10, curation none): Prometheus' lowest timestamp, blocks
loaded and their bytes at the read.

## `m1_dump.sh`

```sh
sh tools/fake_aging/m1_dump.sh <scenario-dir> --playground <pg> --node <db node> --database <db> <out-dir>
```

The research's queries and output form (one CSV a query, `all.txt`, and
`meta.txt` naming the scenario, playground, node, database and read time),
as run R's `m1-fa-real-20261115T0800/`; a query naming tables the database
lacks (the shop's orders, deliveries, order statuses, ledger) writes no
file. Exit 0, 1 (the node unreadable or a query failed), 2.

## `m1_compare.py`

```sh
python3 tools/fake_aging/m1_compare.py <reference-dir> <game-dir> --start <game T0 dir> \
    --profile <reference M3 profile> --span <HH:MM>-<HH:MM>
```

A fake game ages its own span with its own selection (the shop's 16 h from
22:00, seven instances), run R aged 24 h from 14:00 with ten. Each measure
is expected at **T0 + s × (R − T0)**: T0 the game's value dumped after
`inject`, before `fill` (the same data and T0 plantings R started from), R
run R's, s the share of R's inserted rows (its M3 profile's hourly `rows
inserted/s`) inside `--span`, scenario time, from the virtual T0 to the
read (D586). Judged within 3 % (the research's tolerance), or one row
either way for a count under 34 where 3 % is less than a row: the
measures inserts drive, each table's `n_tup_ins`, the sequences'
`last_value`, the database's `tup_inserted`. Reported with their ratio,
never judged: each table's `n_live_tup` (D593: an estimate VACUUM and
ANALYZE overwrite, not a count inserts drive), updates, HOT updates,
scans, dead rows,
autovacuum and autoanalyze counts, the bloat estimate, transaction ages,
order statuses, delivery events, the other databases' commits. Exit 77
when the reference directory or profile is absent.

## `m3_profile.py`

```sh
python3 tools/fake_aging/m3_profile.py dump <scenario-dir> --playground <pg> \
    --handover <YYYY-MM-DDTHH:00Z> [--database <db>] <out.json>
python3 tools/fake_aging/m3_profile.py compare <reference.json> <game.json>
```

`dump` reads the research's twelve expressions at 1-hour steps over the 24
hours up to the hand-over, the database `--database` (default `shop`), and
records the game's virtual T0 and restart. Both hand over at 14:00 scenario
time, so step i is the same scenario hour in both. `compare` judges, over
the steps whose hour the game's past holds (the virtual T0 plus one hour to
the last whole hour before the restart: the shop's 23:00 to 13:00, 15
steps), the traffic expressions (`calls/s`, `errors/s`, `commits/s`, `rows
inserted/s`, `statements calls/s`): Pearson correlation at least 0.95 and
the ratio of means 0.95 to 1.05. Reported only: the call p95, the size and
resource gauges, `series`, the transactions' age. Exit 77 when the
reference profile is absent.

## The short games: `tools/tests/smoke-fake-aging.sh`

```sh
flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
  sh tools/tests/smoke-fake-aging.sh <scenario-dir> [--record]
```

`tarnbeck-outdoor-shop` or `tarnbeck-outdoor-campaign`, as it is, playground
`fake-smoke`; any other scenario: exit 2. Its header lists the steps and
checks. Its selection: the shop f1, f2, f3, f6, f8, f9, f10; the campaign
f1 to f4 and f7 to f9 (a selected instance no longer `supported` drops
out, 9.8's fallback); a 15-minute tail, the anchor H − 15 min, H a whole
hour.

**The start window**: it starts only when the anchor lies between the
setup's bound and 30 minutes less the time from the anchor to the
teardown's end; otherwise exit 3, nothing deployed, its line naming the
window (the shop hh:31:00 to hh:35:00, the campaign hh:31:00 to hh:39:30).
It never waits for a window.

**Exit status**: 0 nothing failed (a SKIP for the archive counts no
failure); 1 a failure; 2 usage or a precondition; 3 outside the window.
The wall time is a check: FAIL at 30 minutes or more.

**`--record`** also writes the output to
`calibration/<scenario id>-short-game-<YYYYMMDDTHHMMZ>.txt`, opening with
the command, the commit, the start and the wall time. The scenario
document's "Fake aging" section shows the setup time from the newest
record (the `scenario-document` skill): regenerate the scenario's
`README.md` in the same commit as a new record.
