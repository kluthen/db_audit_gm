# cold-storage-archive — GM notes

Purpose 14 of v0.5 (master spec 12.2; v0.5's `vet-machinery-domain.md`,
"`cold-storage-archive`"; v0.5's `cold-storage.md`
2, 3 and 6; capture W4 items 0 and 6): the generic round trip of cold
storage, first drafted for `vet-machinery`. Heavy time series live on site
in day partitions; each night the integration engine ships every day older
than the kept window to the vault, one shipment per type and day, and drops
a partition only on a receipt counting every row it sent. What ships leaves
the game: nothing reads it back (cold storage 5).

## What it is for

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `ship-partitions` | `40 0-5 * * *` | script `scripts/cold_storage.py:ship`, `vitals` and `biomed` as `mach_archive`, `partner` (the schedule's `cold-storage`) with the credential `cold_storage` | for `vitals` (`mach_vitals` in `vitals`) and `machine-readings` (`mach_readings` in `biomed`): each day partition (`<parent>_YYYYMMDD`, from `pg_inherits`) older than the customer's today less `window_days`, both read from the database's settings (`mach_vitals_settings`, `mach_settings`, D418); for the readings the day's `mach_readings_daily` first, committed; the rows as NDJSON posted to `POST /shipments` (`Shipment-Id` `<type>-<YYYYMMDD>`, the same on a resend; `Shipment-Source` the option `source`, the node whose partitions ship, D381; `Shipment-Rows`, `-From`, `-To` the day); on a 2xx receipt whose `rows_received` equals the rows sent, `mach_drop_shipped(day)`; per database one transaction: the run's `ops.runs` row, each day's `ops.shipments` row (upserted on type and day, `attempts` counted), the drops, and from the local hour `last_hour` (5: the 05:40 run) one `ops.incidents` row (`unshipped`, ref the shipment id) per day still on site, once |

The first run of the night ships, the later ones resend what was not
received, a no-op (its run rows only) when nothing is left. A shipment with
no receipt within the connection's 60 s, refused, or short is kept and sent
again with the same id: the vault replaces that source's manifest.

The **history** (`material/history.sql`, run by `load-data` in the
partners' database after the loads) plants the manifests of every day
before the kept window at `load_epoch`: `vitals` from the first session's
day, its rows the 10-second ticks within the sessions; `machine-readings`
the days of `mach_readings_daily`, its rows their sum; declared and
received equal, received at 00:40 the night after the window, the source
read from the foreign server's `host` (no node name written). No periodic
job extends it (no feeder).

**Choices made at the build** (W4-e): the job key `archive.ship`, the
schedule's HTTP connection `cold-storage` (target `cold-storage:8000`, the
partners' api node's alias), the script's names `vitals`, `biomed`,
`partner`; the rows read through the parent between the day's bounds
(pruning picks the partition), so `mach_archive` needs no grant on a
partition the pg_cron job creates; the day's bounds at the settings' fixed
offset, as the partitions are cut; the aggregate per machine, each numeric
channel's min, max and mean to two places, as the load's; a run row in each
database at every run, so the checks see the runs; the manifests' `size`
in the history estimated at 170 bytes a vitals row, 130 a readings row.

## What the material holds

Written for the clinic's names; adapt them when copying.

| File | Goes to | Names to adapt |
|---|---|---|
| `material/runner/queries.yaml`, `jobs.yaml`, `schedule.yaml`, `scripts/cold_storage.py` | the runner's (`interfaces`) scenario layer `compose/interfaces/`, merged by `gmctl compose` | the targets `machines:5432/vitals`, `machines:5432/biomed`, `cold-storage:8000`; the option `source` (the node holding the partitions) |
| `material/source/ddl.sql`, `material/source_biomed/ddl.sql` | nowhere: `ddl.source`, `ddl.source_biomed`, read from the catalogue by `load-data` at step (2b) | none (`:"DBNAME"`) |
| `material/history.sql` | nowhere: `history:`, read from the catalogue by `load-data` | none |
| `checks/*.sh` | the sealed checks of the faults attached to the purpose | the constants at the top of each (`PARTNERS`, `NODE`, `VITALS`, `BIOMED`, `SOURCE`; the job's cadence `RUN_MINUTE`, `RUN_FIRST_HOUR`, `RUN_LAST_HOUR`) |

Each DDL creates (guarded) `ops`, its three shared tables and
`ops.shipments` (`type`, `day`, `shipment_id`, `rows_sent`,
`rows_received`, `attempts`, `posted_at`, `receipt_at`, `dropped_at`,
`run_id`; key type and day), the role `mach_archive` (`LOGIN`, owning no
table), `CONNECT` by name, the `ops` grants and `SELECT, INSERT, UPDATE` on
`ops.shipments`; `SELECT` on the parent and the settings, `EXECUTE` on
`mach_drop_shipped`; in `biomed` also `SELECT, INSERT, UPDATE` on
`mach_readings_daily`.

The scenario must declare cold storage (`third_parties:`, role
`round-trip`, the partners' `api` node and database, hostname
`cold-storage`), copy `partners/coldstore/` as `partners/README.md` says
(its `data.sql` into `partners-db`'s data file before the history runs),
give `machines`' `pg_hba.conf` a line admitting `mach_archive` from
`interfaces` and `gm_check` from the network, and set the secret
`cold_storage` on `interfaces`' connection only.

## How it goes wrong

The candidate faults are the domain's T219 to T226, T236 and T237
(vet-machinery-domain.md, "Traps", 4): T219 a partition dropped on any
answer or on a timeout (CA1, with the vault's outage key on); T220 the
shipping stalled (CA4); T221 a resend under a new shipment id (CA2); T222
the window wrong (CA4); T223 `DELETE` instead of detach and drop; T224 the
aggregate after the drop (CA3); T225 and T226 the partitions' indexes and
pruning (performance, no check of this purpose); T236 the detach held
across the post in one transaction (the monitors' inserts waiting at
00:40: a performance read, no check); T237 a partition function without a
fixed `search_path` (the definition, read at once). A scenario's faults are the GM's to select.

## The checks

They need the partner's side, so each runs on `partners-db` as root
(`gmctl check`), in POSIX sh (the `postgres` image has no `python3`):
`partners` through `check-psql`, `vitals` and `biomed` through
`check-psql --node machines`, as `gm_check`; the judged moment is
`CHECK_SINCE` as given, the runs read from `ops.runs` (W4 item 0). Exit 0
fixed, 1 present, 2 cannot judge, 3 too soon (`remaining=` until the job's
next run, `RUN_MINUTE` past the hours `RUN_FIRST_HOUR` to `RUN_LAST_HOUR`
local, 40, 0 and 5 as shipped: when the job is moved, the GM sets the three
constants to its new cadence).

| Check | Invariant | Judged | Witness |
|---|---|---|---|
| `ca1-dropped-on-receipt.sh` | every partition dropped since the judged moment has its manifest from the source, rows declared and received equal to the rows sent | runs | a dropped day, two each night |
| `ca2-one-manifest.sh` | one manifest per type and day from the source | runs | a manifest received since the judged moment |
| `ca3-aggregate-first.sh` | each readings day dropped has its `mach_readings_daily`, summing to the rows shipped | runs | a readings day dropped, one each night |
| `ca4-end-to-end.sh` | each type-day written since the judged moment in the vault, all rows received, by 06:00 the night after the window; no partition left past its night | end-to-end | a day whose shipping night has passed |

CA4 takes `window_days` live from the settings: a GM lowering it (the vault
fixture sets 0 to ship yesterday at 21:56) moves every day's night with
it.
