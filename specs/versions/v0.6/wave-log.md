# db_audit_gm v0.6 — Wave log

Execution record of [build-plan.md](../../archive/v0.6/build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

On 2026-11-16 the owner approved build plan v2 (spec D518: "i aprove the
plan"), with κ = 2; the reference archived outside git (D519: "i don't
want to keep the archive in the git, but it can go there"); and `fa-real`
torn down once its usefulness is spent (D520: "you may stop the real
aging game once its usefullness is spent"), which the plan places after
chunk 1 has merged and its archive verifies (G12).

## Wave 1 — started 2026-11-16

Chunks 1, 2, 3, 4, 8 (κ = 2). Branch `v0.6-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.6-w1`, cut from `main` at 819baab
(G1: `v0.6-spec` merged into `main`, spec D518).

### Gates checked at the start

- G1: done (2026-11-16, spec D518); `v0.6-spec` merged into `main` as
  819baab.
- G3 (network at image build time), hand check 2026-11-16: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release`, GitHub's s6-overlay, Prometheus, `postgres_exporter` and
  pgwatch releases answer 200; Grafana's pinned download
  (`grafana_13.3.1_42849527790_linux_amd64.tar.gz`) answers 200. Cleared
  for wave 1.
- G4 (Docker host in swarm mode), hand check 2026-11-16: armenelos swarm
  active, manager, leader; the VPS `vps-5718ad52` a worker, `Ready`,
  `Drain`. Images are tagged `127.0.0.1:5000/dbagm/...` locally; no
  registry runs (none needed on one host). Cleared for wave 1.
- Host on 2026-11-16: `/home` 88 % used, 16G free. `fa-real`
  (`tarnbeck-outdoor-shop-z8415w`, 8 services) still deployed, to go at
  G12.

### Capture W1 — versions and `base:`, the reference archived, the loader's accessors and refusals, the domains' fragment, the fill's interface (chunks 1, 2, 3, 4, 8; read by 5 to 14)

Recorded 2026-11-16, before any code; drafted for the wave driver from
the capture lines of chunks 1, 2, 3, 4 and 8 and the Depends and capture
lines of chunks 6, 7 and 9 to 14; master spec 5, 6, 7.6, 9.3 to 9.12,
12.3, 16 and 18; [formats.md](../../formats.md) v34; spec D486, D510,
D519; the code on `v0.6-w1` at ae5218e (`tools/gm/{model,render,localimpl,aging,inject}.py`,
`tools/gm/__init__.py`, the format skill's templates, `bricks/*/brick.yaml`,
`bricks/*/tests/run-stack-test.sh`, the bastion's `gm-entrypoint`,
`bricks/scheduler/program/gm_scheduler/{__init__,__main__,metrics,scripts,textlog}.py`,
`domains/*/`, every scenario's and fixture's `scenario.yaml` and seed
copies); and the research at `10d1bc6` (`fill.py`, `latency.py`,
`overlays.yaml`, the run sheet `run-2026-11-14.md`), its `results/`
listed with `ls` only. v0.5's rules: where the spec fixes a point it is
cited, not restated; **(choice)** marks a point the sources left open,
settled here with its reason; each item names the chunk that writes it
and the chunks that read it. Chunk internals stay out; chunks record
their as-built outcomes as **W1-w** (chunk 1: the archive's size,
SHA-256 and checks, which G12 waits for), **W1-x** (chunk 8: P0's result
and the fill as built), **W1-y** (chunk 3: the accessors as built, the
faults given `lines:`) and **W1-z** (chunk 4: the coverage run); chunk 2
is mechanical and records nothing.

Held, cited not restated: v0.3 W1 items 0 (key conventions, `# optional:
<when>`, durations `<integer><s|m|h|d>`) and 7 (the scheduler's runtime
interface, its log); v0.4 W1 item 4 (`seed.optional`); v0.5 W1 item 1
(tags, pins, `applies_to`, "Supported faults") and its rule that the
templates are the loader's schema (`model.template_schema`, missing keys
reported, unknown keys accepted); the `{NAME}` placeholder of
`parameter_changes` (a fault parameter's name upper-cased, `-` as `_`;
`localimpl._substitute`).

**0. Conventions** (read by every chunk)

- **Every key v0.6 adds is `# optional:` in its template in wave 1**, but
  `base:`, required once chunk 2 has written it everywhere (chunk 3
  merges after chunk 2): `description:`, `site:`, `users:`, `admitted:`,
  `overview_diff:`, `aging.fake`, `history:`, `seed_changes[].lines`
  (item 5) and `domain.yaml`'s `overview` load in either merge order of
  chunks 3 and 4. Chunk 7 turns the overview's requirements on (plan
  "Read first"); `aging.fake` and `history:` stay optional (absent: not
  assessed, 6.3; the mandatory `history:` is checked from `aging.fake`).
- **Accessors** are module functions of `tools/gm/model.py`, beside
  `fault_judges` and `fault_aging_minimum`, taking a fault's `data` or a
  checked `Scenario`. They parse, never check (the loader has), and never
  raise on a checked scenario; their records are frozen dataclasses.

**1. Versions, tags and `base:`** (chunk 2 writes; read by every later
chunk)

- **Versions**: master spec 6.8's table; tags
  `127.0.0.1:5000/dbagm/<brick>:<version>`; pins, `applies_to` and
  "Supported faults": the plan's "Read first". `scheduler`'s
  `technology.version` and the program's `gm_scheduler.VERSION` read
  `"0.4.0"`, version lines both (no log line prints `VERSION`, so chunk
  8's replay corpus is unaffected).
- **`base:`** as 6.4 and 6.9, verbatim, `version` quoted. **(choice)** Its
  shape, checked by chunk 3: a map of exactly `os` and `version`, both
  non-empty strings; an unquoted `13` is refused, since the check
  compares strings. Chunk 7's **System** reads `<os> <version>`.
- **The check (choice)**: one shared helper, `tools/tests/check-base.sh
  <brick-dir> <image>` (new, chunk 2). It reads `base:` from
  `<brick-dir>/brick.yaml` with `python3` and PyYAML, runs `docker run
  --rm --network none --entrypoint cat <image> /etc/os-release`, and
  compares `NAME` with `os` and `VERSION_ID` with `version`; one line
  out, exit 0 on a match, 1 on a difference, 2 when either side can't be
  read. Each stack test calls it once, after its image check, as a
  `pass`/`fail` line; the wave gate runs it alone over the ten bricks
  (per-wave gate contents, wave 1). Why: ten copies of a YAML read and
  an os-release parse would drift, and the gate's item needs it without
  a stack test. `NAME` and `VERSION_ID` because they name the
  distribution and its release without codename or point release
  (`debian:13-slim`: `Debian GNU/Linux`, `13`).

**2. The bastion's seventh seed file** (chunk 2 writes `brick.yaml`;
chunk 7 maps it, chunk 6 serves it, chunk 14 plants a fault in it)

- `bricks/bastion/brick.yaml` at 0.6.0: `network-overview.md` appended to
  `seed.files` (seventh, after `data-register.md`) and to
  `seed.optional`, and `seed.paths: network-overview.md:
  /home/player/network-overview.md`, commented `network-overview.md:
  player/network-overview.md, with a network overview (v0.6)`. Nothing
  else of the bastion in chunk 2: the entrypoint's `STARTER_OPTIONAL`
  and `docs/gm.md`'s starter-pack rows are chunk 6's. Until chunk 6
  merges, a mapped file is mounted but neither copied nor served, which
  no test of waves 1 and 2 reads (the clinic is never deployed whole).
- The mapping rule (6.1: exactly when the scenario has an overview) is
  chunk 7's check.

**3. The reference archive and `extract.sh`** (chunk 1 writes; read by
8, 11, 12)

- The archive's path and name, its `.sha256`, the pointer files and the
  working directory `tools/fake_aging/reference/extracted/` (ignored):
  plan chunk 1. **(choice)** The archive is `tar --zstd` of the folder
  `results` (`-C <...>/fake_aging results`), its members
  `results/<path>`; `MANIFEST.sha256` lists `<path>`, relative to
  `results/`, and so does every member name below.
- **(choice)** `sh tools/fake_aging/reference/extract.sh [--archive
  <path>] <member>...`:
  - `<member>`: a manifest path; a folder ending `/` takes every file
    under it; a quoted shell pattern (`'calibrate-r-*-20261115.txt'`)
    every manifest path it matches. A member matching nothing is an
    error.
  - `--archive` names another archive (a test pointing at a missing
    one); the default is the plan's path.
  - It checks the archive against its `.sha256` once a run, extracts into
    `extracted/` beside the script (each worktree its own) at the
    member's path (`--strip-components=1`), checks each file against
    `MANIFEST.sha256`, and prints each file's absolute path, one a line,
    on standard output; messages go to standard error. A file already
    there and matching the manifest is not extracted again.
  - Exit status: 0 done; 1 a check failed (the archive's checksum, a
    file's manifest line, an unknown member); 2 usage; **77, skip**: the
    archive is absent, with `extract.sh: SKIP: the reference archive
    <path> is absent (kept outside git, spec D519; see
    tools/fake_aging/reference/README.md)` on standard error. 77 is
    automake's skip status; the repository has none, and gmctl uses 2
    and 3. A Python test seeing 77 calls `skipTest` with that
    line, a shell test prints `SKIP` and counts no failure. Only absence
    skips: a checksum mismatch fails.
  - `extracted/` is a cache, deleted at will and taken away with its
    worktree; `r-dump/` (1.4 GB) is never extracted whole when one file
    serves.
- **The members the chunks read** (listed 2026-11-16):
  - chunks 8 (service times) and 11 (the calibration tool):
    `calibrate-r-producer-20261115.txt`,
    `calibrate-r-consumer-20261115.txt`,
    `calibrate-r-producer-f5-20261115.txt`;
  - chunk 11 (the shop's signatures' measured costs): run R's members as
    needed, `m1-fa-real-20261115T0800/` (`statements.csv`,
    `table_stats.csv`, `database_stats.csv`, ...),
    `m3-r-20261115.json`, `prom-r-20261115T0800/volume.tar`,
    `r-dump/r.om`; W3 names those it read;
  - chunk 12 (the M1 and M3 comparisons): `m1-fa-real-20261115T0800/`,
    `m3-r-20261115.json`, and `m4-r-20261115.txt` if its tells script
    compares with R's.

  The F runs' members (`*-f1*` to `*-f6*`, `hist-f*/`, `prom-f*/`,
  `fa-fake-*.log`, `m7-f4-20261115.txt`) are kept for the record; no
  v0.6 chunk reads them.

**4. The loader's accessors** (chunk 3 writes; read by 6, 8, 9, 10, 11,
12)

- **`admitted_incidents(scenario)`** (read by 6b and 9): one `Admitted` per
  fault instance carrying `admitted:`, in `fault_instances` order:
  `instance`, `by` (the third party's id), `partner` (its `name`),
  `anchor` (its `player_doc`'s fragment, after `#`), `title`, `text`,
  `start` and `end` as written (`end` None without `until`), and
  `start_before` and `end_before`, seconds before hand-over (None for
  `T0`, or without `until`). Resolved per instance: the partner looked
  up, the moments parsed; the UTC instants (they need the planned
  hand-over and the game's T0) and the filter to planted instances are
  render's (7.6; chunk 6b). In a fake game `T0` is the virtual T0 (9.3),
  which chunk 9 hands render. **(choice)** Moments are written as a
  planting moment is, `T0` or `handover-<N>h` (`HANDOVER_MOMENT_RE`),
  as 7.6 and formats.md say; 6.9's comment `handover-<N>h|m` is the
  outlier (Preflight corrections, item 2).
- **`fault_fake_aging(fault_data)`** (read by 9, 11, 12): `FakeAging` or None
  (no `aging.fake`: not assessed): `support`, `reason`, `tail_minimum`
  (seconds, or None), `tail_covers` (a tuple of `"HH:MM"` scenario-time
  strings), `plant_in` and `emulate` (a tuple). **(choice)** `support` and
  `reason` required; `plant_in` and `fill` optional, defaulting to `any`
  and `[]`, since a `real-only` fault has neither; a `tail-only` fault
  gives at least one of `tail_minimum`, `tail_covers` and `plant_in:
  tail`, 9.5's three ways of needing the tail, else it is refused.
- **`fault_history(fault_data)`** (read by 10, 11, 12): a tuple of
  `HistoryEntry`, or None (no `history:`): `kind`, `fields` (every key
  but `kind` and `suppressed_by`, as written, placeholders unresolved),
  `suppressed_by` (a tuple of fault ids). **`instance_history(scenario,
  iid)`** (read by 8 and 10): the same entries, every `{NAME}` replaced
  from the instance's parameters, else their defaults, and
  `{INSTANCE_NODE}` by the instance's `node:`; `suppressed_by` kept as
  data, since it depends on the selection. **(choice)** One resolver,
  so chunks 8 (`queue`) and 10 (the rest) read a signature alike.
- **The kinds' fields** (chunk 3 checks the shapes, 11 writes them, 8
  and 10 read them). 6.9 shows two kinds; **(choice)** the others from
  the research's `overlays.yaml`, its `_s` seconds written as durations:

  | kind | required | optional |
  |---|---|---|
  | `counter_per_call` | `series`, `key`, `per_call` (a number) | `node` |
  | `gauge_sawtooth` | `series`, `period` (a duration), `amplitude` (a number) | `phase` (a duration, `0s`) |
  | `gauge_before` | `series`, `value` (the level until the planting) | |
  | `daily_spike` | `series`, `at` (`"HH:MM"`, scenario time), `duration`, `value` (the level during the spike) | |
  | `remove` | `series` | |
  | `queue` | `key`, and exactly one of `service` and `lock` (item 9) | `node` |
  | `none` | | the list's only entry |

  Every entry may carry `suppressed_by: [<fault id>]`. Placeholders go
  in strings only (`series`, `key`, `node`); numbers are numbers (9.7:
  measured). A `{NAME}` names a parameter of the fault, as in
  `parameter_changes`, or is `{INSTANCE_NODE}` **(choice**: a signature on
  the instance's own node, a database node's exporter series, has no
  parameter naming it). `node` is the scheduler node running `key`;
  absent, the one scheduler node whose `queries.yaml` has the key (fill
  and history refuse an ambiguous one). A fault lacking a parameter its
  signature needs (f8's slowed key) gains one in chunk 11; faults never
  bump (formats.md "Versions and pins").
- **`RESERVED_WEB_ROUTES = ("docs", "reports", "status")`** in `model.py`
  beside `_check_web_routes` (read by 6): the refusal's names and the
  front's paths, one list.

**5. The two refusals** (chunk 3 writes; read by every chunk adding a
scenario or fixture; ISS-001 closes with them)

- **O251** (6.10; formats.md "Partners"; spec D486), on each bastion
  node:
  - `scenario.yaml: nodes[<bastion>].seed_files.partners.md: missing:
    third parties carry a player_doc, but the bastion maps no partners.md
    (formats.md "Partners"; spec D486)`
  - `scenario.yaml: nodes[<bastion>].seed_files.partners.md: the bastion
    maps partners.md, but no third party carries a player_doc (formats.md
    "Partners"; spec D486)`
  - `scenario.yaml: nodes[<bastion>].seed_files.partners.md: <path>, not
    player/partners.md (formats.md "Partners"; spec D486)`
- **O269** (6.10; formats.md fault "Injection"; spec D510). **(choice)**
  The lines are declared: a `seed_changes` item gains `lines:`, optional,
  the literal lines the change puts in the scenario's copy, `{NAME}`
  placeholders allowed (Preflight corrections, item 1). For each
  instance of `fault_instances` whose definition's `seed_changes` item
  has `lines:`, each line, its placeholders replaced from the instance's
  parameters (else the defaults), is looked for in the node's copy of
  the item's `file` (its `seed_files` entry; a folder entry, any file of
  the folder; `data`, the node's data file). It is found when a line of
  the copy, both stripped and their runs of blanks made one space,
  equals it or continues it with a comment (`#` or `--` after a blank).
  Line by line, anywhere in the file: a comment put above it (chunk 4's
  crontabs) or a line moved breaks nothing. `lines:` is refused on
  `data-register.md` and `network-overview.md`, generated handouts whose
  changes the answer key's diffs carry. One refusal a missing line:
  - `scenario.yaml: fault_instances[<id>]: <file>: line "<line>" of fault
    <fault id>'s seed_changes is not in <the copy's scenario-relative
    path>: a seed-file change is in the scenario's copy from T0
    (formats.md, fault "Injection"; spec D510)`

  Why declared: the changed lines exist nowhere a program can find them.
  Most `change:` texts are prose, and a `material:` is an example, a
  diff or a whole file: run against every scenario and fixture on
  2026-11-16, matching the materials' lines refused eight correct
  instances (the clinic's s1 and s9, fernway's f1 and f6, the campaign's
  f2 and f3, the shop's f3 and f10). Chunk 3 gives `lines:` to
  `pg-archive-command-silent`, `governance-statement-log-personal` and
  `pg-standby-apply-delay` (the clinic's s2, s7, s8: plan chunk 3, Done
  when), and to any other change whose text is the same in every copy
  (W1-y lists them). A change without `lines:` stays the GM's to read,
  as the format skill's checklist says.

**6. The domains' overview fragment and the crontab comments** (chunk 4
writes; chunk 7 reads and checks)

- File, declaration and shape: `data/overview.yaml`, declared
  `overview: data/overview.yaml` in `domain.yaml` after `register:`
  (formats.md "`domain.yaml` must contain"; 6.5), with 6.9's `roles:
  [{role, who, reads, writes}]` and `jobs: [{job, what}]`.
- **(choice)** Coverage, as chunk 7's check will compute it: `roles`, every
  role created `LOGIN` in the domain's schema files (`schema`, or each
  `data/<database>/schema.sql`), as `data_file_creates` reads them;
  `jobs`, every `name:` in the domain's `producers/<node>/jobs.yaml` for
  a customer node (not `producers/api/` nor `producers/partners/`) and
  every job name `cron.schedule` or `cron.schedule_in_database` gives in
  its `cron.sql`, one entry a distinct name, as written. Each value one
  line in the customer's words, no placeholder.
- In wave 1 `overview` is optional in the template (item 0) and nothing
  checks the file; chunk 4 shows coverage with a script run once, not a
  unit test (`test_model.py` is chunks 2's and 3's in wave 1, the check
  chunk 7's), recorded as W1-z.
- **Crontab comments** (6.6): the description is the one comment line
  directly above its entry, no blank line between; earlier comment lines
  are the file's own notes, not read; an environment line
  (`PGPASSFILE=`) goes above the description, never between it and its
  entry. `render_crontab` keeps comments as written.

**7. The fill: `gmctl fill`** (chunk 8 writes; read by 9, 12, 13)

- **(choice)** `tools/gmctl fill <scenario-dir> --playground <name>`, no
  other option: what it needs is recorded. It reads `virtual_t0` and
  `anchor` from the restart record, `local/<playground>/fake-aging.yaml`
  (6.7, 6.9's keys), and refuses without one or when its `mode` is not
  `fake`; the instances' `planned_at`, the seed and the shift from
  `implementation.yaml`'s `timeline`; the service times (item 9); the
  selection's `queue` entries through `instance_history`. Stage
  `injected` (after 9.4 step 4), left as it is: no new stage.
- **The record before chunk 9**: chunk 8's tests and `fixture-fill`'s run
  script write it themselves with 6.9's keys (`mode`, `virtual_t0`,
  `anchor`, `tail`, `handover_planned`, `refused: []`), so chunk 9's
  `render --aging fake` replaces only the writer. The file's name and
  its reader are `localimpl.py`'s (`RESTART_RECORD_FILE`,
  `read_restart_record(ldir)`, None when absent), written by chunk 8;
  chunk 9 adds the writer (Preflight corrections, item 4).
- **What it records**, in `state.yaml` **(choice**: progress is
  `state.yaml`'s; the restart record keeps 6.7's fields): `fill:
  {started_at, ended_at, outcome: ok|failed, reason, quiet}` (`quiet`:
  item 8), and each state instance it plants under `plantings.<id>` as
  `inject --at` records one, its attempt `by: fill` with `at` the real
  instant and `virtual_at`, and `planted_at` the **virtual** instant
  (9.3: aging minima count in virtual time). A failed fill is recorded
  and never resumed (its rows are half a night: the GM tears the game
  down); a fill on a game whose `fill.outcome` is `ok` is refused.
  `clean-restart` requires `fill.outcome: ok`; `start-load` creates no
  timer for an instance the fill planted (chunk 9).
- **What it plants**: the state instances whose `planned_at` lies in
  [virtual T0, anchor); T0 instances are `inject`'s (step 4), later
  ones the tail's timers (chunk 9).
- **The scheduler logs**: on each scheduler node the fill appends its
  lines, at virtual times and in time order, to
  `/var/log/scheduler/scheduler.log` (the `schedlog` volume), in the
  program's format (`textlog`), their latencies the queue model's, and no
  `reload` line (9.4 step 7). The tail's program appends after them;
  clean-restart keeps them (9.10).
- **One clock** (9.4 step 5): a job on one node sees exactly what the
  other nodes wrote up to its virtual instant. Where the fill process
  runs (one for every node, as the research's, or one a node in lock
  step) and the program's `fill` entry point's input and output are
  chunk 8's, recorded in W1-x.

**8. P0, and what the fill leaves** (chunk 8 writes; read by 9, 11, 12)

- **P0's candidate (choice**; measured first, its result W1-x):
  - in the SQL the fill sends (keys, jobs, builders' statements, and
    scripts through the connections the fill opens): `now()`,
    `current_timestamp` and `current_date` replaced by bound parameters
    holding the virtual instant, as the research's `fill.py`
    (`virtualize`), proven on the shop;
  - in the server-side functions it calls: a schema `gm_vclock`, created
    by the fill, unseen, in each database it writes, holding `now()`,
    `transaction_timestamp()`, `statement_timestamp()` and
    `clock_timestamp()`, which read the session setting `gm.vclock` (the
    last advancing with the real clock from it); every fill session sets
    `search_path` to `gm_vclock, pg_catalog` then the role's own path,
    and `gm.vclock` at each transaction's start. Session settings only,
    never a role's, a database's or the system's, so no real-mode
    session sees them. `clock_timestamp()` is in because the campaign's
    run ledgers write it and its checks read them.
  - Out of its reach, so P0's measurement: `current_date`,
    `current_timestamp` and `localtimestamp` inside a function body
    (SQL keywords, never looked up on the search path), a function with
    its own `SET
    search_path`, a `BEGIN ATOMIC` body, a column's `DEFAULT now()`
    (`scenarios/tarnbeck-outdoor-campaign/data/reporting.sql:396`). If
    the campaign's P0 faults need one of these and chunk 8 finds no
    cover, P0 fails and 9.8's fallback holds (chunks 11, 12).
- **What it leaves**, the contract chunk 9 builds on:
  - in a database: the fill's rows, at their virtual times. Nothing of
    P0: the fill drops `gm_vclock` at its end and on failure, and
    `clean-restart` drops a leftover (`DROP SCHEMA IF EXISTS gm_vclock
    CASCADE`) before its statistics reset, so no failed fill hands one
    over; the catalog rows and OIDs the shim used, listed in W1-x if P0
    is adopted.
  - settings: `autovacuum_naptime` lowered for the fill and restored at
    its end (fix 7). The real-clock actors (`pg_cron`'s launching, the
    database node's cron daemon, archiving) and anything else the fill
    turned off server-wide, the statement statistics' switch included if
    it is server-wide (fix 3; `pg_stat_statements.track` is
    superuser-only and the fill's sessions are the roles', so chunk 8
    picks the means), are **left off**, each listed in `fill.quiet` with
    how to restore it, and turned back on by `clean-restart` in its
    restart, never before, so they start at the anchor (9.4 step 6,
    9.10).
  - for clean-restart (W2): the PostgreSQL, pooler and cron logs of the
    fill's span, the WAL, the data files' modification times (fixes 2, 4,
    8), and what the real-clock actors did between the deploy and the
    fill's start.

**9. The queue model** (chunk 8 writes; read by 10, 11, 12)

- **Service times (choice)**: `service-times.yaml` beside the
  `queries.yaml` defining the keys (6.5, 9.7),
  `scenarios/<id>/nodes/<node>/service-times.yaml`:

  ```yaml
  source: >-            # where the figures were measured: the run, its date, the file
    research/fake-aging 10d1bc6, run R (fa-real, 2026-11-14 to 15),
    calibrate-r-producer-20261115.txt
  keys:                 # every key a stream or job of the node runs
    catalog.lookup: {median: 0.0011, sigma: 0.35}   # seconds of database work a call, lognormal
  ```

  `gmctl fill` reads it from the scenario folder and passes it to the
  program at fill time: never a seed file, never mounted, so nothing of
  fake aging reaches a node a player reads (9.10). The fill refuses a
  key a stream or job runs without an entry, naming the key and the
  file. A domain's keys' file beside its fragment, and its composition,
  wait for the clinic's fake aging (later). The campaign's shop keys copy
  the shop's figures with their source; its own keys are chunk 11b's.
- **A fault's `queue` entry (choice)**: `key` (and `node`), and one effect,
  its numbers measured:
  - `service: {median, sigma}`: the key's work a call from the
    instance's planting (f2, f8);
  - `lock: {median, sigma, blocks: [<key>...]}`: each call of `key`
    holds its locks this long, and a call of a `blocks` key reaching the
    database meanwhile waits until it ends (f5).

  What a rendered file already plants the model reads there, never from
  a `queue` entry: a connection's target and, through a `pgbouncer`
  node, its pool size and mode (`pgbouncer.ini`; f7), a job's time and
  zone (`jobs.yaml`; f6), a key's transaction hold (`queries.yaml`'s
  `transaction.hold`; f4); a call's error is the fill's own execution's
  (f1). So f1, f4, f6 and f7 need no `queue` entry.
- **What `gmctl history` reads for the histograms (choice)**: the fill's
  own record, never a second simulation:
  `local/<playground>/fill/<node>.metrics.jsonl`, one JSON object a
  virtual minute, in order, holding what the node's `/metrics` would
  have served at that minute's end counting from the virtual T0
  (`scheduler_calls_total`, `scheduler_errors_total`, and
  `scheduler_call_duration_seconds`' buckets (`metrics.BUCKETS`), sum
  and count, a key each; `scheduler_job_runs_total`,
  `scheduler_job_skips_total`): the calls and latencies of the log's
  lines, so log and graphs agree by construction (9.12). Its exact keys:
  W1-x. Chunk 10 reads it for the fill's span, Prometheus for the tail.

**10. Wave 1's order and ownership** (plan "Wave 1's order")

- **Order**: chunks 2 and 1 first; 3 in chunk 1's slot, then 4; 8 once 1
  and 2 have merged. 3, 4 and 8 merge after 2, each taking `v0.6-w1` in
  first; **8 also merges after 3** (8b reads `instance_history`;
  Preflight corrections, item 4).
- **Owners**:
  - chunk 1: `tools/fake_aging/reference/`, `.gitignore`;
  - chunk 2: every version line (`bricks/*/brick.yaml`'s `version`,
    `image`, `scheduler`'s `technology.version`, `gm_scheduler.VERSION`),
    `base:`, the bastion's seventh seed file, the Dockerfiles' build
    comments, `docs/gm.md`'s version lines and "Supported faults", the
    stack tests' tags and `check-base.sh` calls, `tools/tests/check-base.sh`,
    every `applies_to`, every scenario's and fixture's pins with their
    `README.md` and data registers regenerated, the smoke scripts, the
    unit tests' version tuples, `domains/{vet-lab,vet-portal}/docs/gm.md`,
    the root `README.md`'s tables;
  - chunk 3: `tools/gm/model.py`, alone in wave 1; its tests in
    `test_model.py`; the format skill and its templates;
    `fixture-v06-refusals/`; the faults' `lines:`; ISS-001;
  - chunk 4: `domains/*/domain.yaml` and `data/overview.yaml`; the
    clinic's `description:`, `site:` and `users:`; every crontab;
  - chunk 8: `bricks/scheduler/` but chunk 2's lines, `tools/gm/fill.py`,
    `localimpl.py`'s record reader, the `fill` registration in
    `tools/gm/__init__.py` and its row in `gmctl.md`,
    `tools/tests/test_fill.py`, `fixture-fill/`, the shop's and the
    campaign's `service-times.yaml`.
- **Files two chunks touch**, the second taking `v0.6-w1` in first:
  `tools/tests/test_model.py` (2's tuples, then 3); the fault definitions
  (2's `applies_to`, then 3's `lines:`); the clinic's `scenario.yaml`,
  `README.md`, `gm/data-register.yaml` and `player/data-register.md`
  (2's pins, then 4, which regenerates the register and the README
  again); `bricks/scheduler/{brick.yaml,docs/gm.md}` (2, then 8). Of the
  shared lists (workflow deltas), wave 1 touches only
  `tools/gm/__init__.py` and `gmctl.md`, chunk 8's alone. No wave 1
  chunk touches `render.py`, `deploy.py`, `aging.py`, `inject.py` or
  `state.py`.

**Choices made here, not in the spec** (for the driver's review): the
templates' v0.6 keys optional in wave 1; frozen-dataclass accessors;
`base:`'s exact shape; the shared `check-base.sh`, its `NAME` and
`VERSION_ID`; the archive's member layout; `extract.sh`'s arguments,
patterns, cache, output and exit 77; the members each chunk reads;
`Admitted`'s fields and its hours-only moments; `FakeAging`'s defaults
and a `tail-only` fault's one requirement; `instance_history` as the one
resolver; the history kinds' fields, durations and numbers;
`{INSTANCE_NODE}`; `RESERVED_WEB_ROUTES`; O251's three texts; O269's
declared `lines:`, its matching and its text; the fragment's coverage;
the crontab description's place; `gmctl fill`'s arguments, its stage,
the record's reader in `localimpl.py`, the fill's `state.yaml` record
and virtual `planted_at`, no resumed fill; P0's `gm_vclock` shim and
`clock_timestamp()`; the fill's leftovers and `fill.quiet` restored by
clean-restart; `service-times.yaml`, its form and its delivery at fill
time; the two `queue` effects and what the model reads from rendered
files; the fill's per-minute metrics record for `gmctl history`; the
`3 ──> 8` merge edge.

### Preflight corrections for spec-writer

1. **O269's lines have no form a program can find** (master-spec.md:90
   and :442; formats.md:763-767; build-plan.md:525). The rule says a
   selected instance's "changed lines are found", but a `seed_changes`
   item has a prose `change:` and an optional `material:` that is an
   example, a diff or a whole file (eight correct instances refused by
   matching the materials, item 5). Proposal: item 5's
   `seed_changes[].lines`, optional and checked where given, in
   formats.md fault "Injection" and master spec 6.3 and 6.10; chunk 3's
   Files gain `faults/{pg-archive-command-silent,governance-statement-log-personal,pg-standby-apply-delay}/fault.yaml`
   and any other fault it gives `lines:`. W1 holds it meanwhile.
2. **`admitted.from` in minutes** (master-spec.md:359's comment `T0 or
   handover-<N>h|m`, against master-spec.md:567 and formats.md:302, "as
   a planting moment is written"). W1 takes hours only (item 4); 6.9's
   comment to read `T0 or handover-<N>h`.
3. **Chunk 2's Files** (build-plan.md:464-482) gain
   `tools/tests/check-base.sh` (new, item 1);
   `bricks/scheduler/program/gm_scheduler/__init__.py` (`VERSION`); and
   the data registers of every scenario whose register digests
   `scenario.yaml` (`model.register_inputs`, tools/gm/model.py:6437),
   regenerated with the `data-register` skill in the re-pins' commit, as
   the workflow deltas already require:
   `scenarios/aldermoor-centre/{gm/data-register.yaml,player/data-register.md}`
   and the same two files of `tools/tests/fixtures/{fixture-archive,fixture-register}/`.
4. **Chunk 8's Files and edges** (build-plan.md:668-679; the graph at
   build-plan.md:121-144; "Wave 1's order"): Files gain
   `tools/gm/localimpl.py` (the restart record's name and reader, item
   7; no other wave 1 chunk touches it); the graph and the order gain the
   merge edge `3 ──> 8` (8b reads `instance_history`, item 4).
5. **Forms W1 settles, for G10 after the wave's gate** (none contradicts
   the spec; formats.md v34 and master spec 6.9 don't carry them yet):
   the history kinds' fields and `{INSTANCE_NODE}` (item 4); a
   `tail-only` fault's one requirement (item 4); `seed_changes[].lines`
   (item 5, correction 1); `service-times.yaml`'s place and form and the
   `queue` effects (item 9); the fill's `state.yaml` record and
   `local/<playground>/fill/` (items 7, 9).

### Questions for the owner

None.

### W1 reviewed by the driver, 2026-11-16

The capture's 18 **(choice)** points are accepted as drafted. Its four
plan corrections (O269's `seed_changes[].lines`, `admitted.from` in hours
only, chunk 2's and chunk 8's Files, the edge `3 ──> 8`) go to
`spec-writer` before chunk 2's branch is cut; item 5 (the forms W1
settles) waits for G10 after the wave's gate. No owner question.
Chunk 1 starts at once: no correction touches it, and W1 item 3 is
committed (f01e24e).

### Plan revision before chunk 2, 2026-11-16

`spec-writer` applied W1's corrections 1 to 4: build plan v3 (41717cd),
spec D521 (O269's lines declared as an optional `seed_changes[].lines`;
a change without `lines:` left to the GM: this narrows D510 as approved,
to be named in the wave report) and D522 (`admitted.from` in hours
only); formats.md v35. The `3 ──> 8` merge edge makes the merge chain
2 → 3 → 8, three long against the model's two; kept, since it orders
merges only (chunk 8 still starts after 1 and 2 on W1's accessor).

### Chunk 1 — merged (3c62185), 2026-11-16

Commit 679beec, merged `--no-ff` as 3c62185. Every Done-when item
passed; no deviation. W1-w (as built):

- Archive `/home/bastien/archive/db_audit_gm/fake-aging-shop-reference/results-20261115.tar.zst`,
  326,495,975 bytes (unpacked 2,031,069,790); SHA-256
  `26faa9e010a449abad9e17472fdea1cfc96dca3614df9cd6cd5c2ed2ed838a55` in
  its `.sha256`; both made read-only (`chmod a-w`).
- `MANIFEST.sha256`: 507 files (plus 5 empty folders `hist-f2/tmp` to
  `hist-f6/tmp` the manifest can't list, named in the README).
- `tar --zstd -df` against the research `results/`: no difference;
  manifest 507/507 OK; `extract.sh` extracted the three calibrations
  and skipped (77) on a missing archive. The research worktree's
  `git status --porcelain --ignored` unchanged, still locked.
- `extract.sh` resolves members against the manifest before looking
  for the archive: a misnamed member fails (1) even where the archive
  is absent.
- The driver re-verified the archive's checksum on 2026-11-16.

Risk noted: one copy, on armenelos `/home`, no off-host backup (spec
12.3 asks for none).

### G12 — `fa-real` torn down, 2026-11-16

`tools/gmctl teardown scenarios/tarnbeck-outdoor-shop --playground fa-real
--reason "v0.6 chunk 1: the reference archived and verified (spec D520)"`,
under the lock, from the main checkout: 8 services, 1 network, 35
configs, 13 secrets, 78 volumes and the game's 4 host timer units
removed; `state.yaml` records the teardown at 2026-11-16T11:31:57Z from
stage `load-started`. Nothing labelled `tarnbeck-outdoor-shop-z8415w`
is left.

### Chunks 2 and 3 started, 2026-11-16

Chunk 2 (Docker: heavy) on `v0.6-c2-versions`, then chunk 3 (Docker:
none) on `v0.6-c3-loader` in chunk 1's slot; chunk 3 merges after
chunk 2. Briefs assembled from plan v3 and W1 items 0, 1, 2, 4, 5, 10.

### Chunk 3 — built (1ef46e3, 97417bc), waiting on chunk 2, 2026-11-16

60 new tests; ISS-001 marked Resolved (97417bc). Before merging it
re-pins its new `fixture-v06-refusals` (and its three local faults'
`applies_to`) to chunk 2's versions. Relayed to chunk 2 while it ran:
seven fixture-local `brick.yaml` lacked `base:`. W1-y comes with the
merge.

### Chunk 4 — built (a87c9fa), waiting on chunk 2, 2026-11-16

Seven `data/overview.yaml` (27 roles, 18 jobs, coverage run once:
nothing missing or extra), the clinic's 21 descriptions, 20 crontab
entries commented. Outside Files: `tools/tests/test_render.py`'s two
positional indices moved by one (a fixture crontab gained a line). The
wording is the customer's voice from the handouts: offered to the owner
for review in the wave report.

### Chunk 2 — merged (15a5e1a), 2026-11-16

Commit e5e4348, merged as 15a5e1a. Versions as master spec 6.8 (bastion
0.6.0, grafana 0.4.0, scheduler 0.4.0, the other seven a patch up);
`base: {os: Debian GNU/Linux, version: "13"}` in every brick and the
seven fixture-local ones; `check-base.sh` matches on all ten images
(adds `--pull never`). Unit suite 1283 OK, 2 skipped. Stack tests all
pass; images identical to v0.5's but the scheduler's (cached builds).

- **Flake:** health-check's stack test failed 2 of 3 runs, `gm-validate`
  running before the cron daemon starts ("RED cron: the cron daemon
  does not run"); pre-existing (image byte-identical to 0.1.0). To be
  filed as an issue; the wave gate may meet it.
- The unit suite writes into a fixture tree briefly: don't load fixtures
  while it runs.
- Left: `.tech` (G5), the format skill's version prose (chunk 3),
  `purposes/shop-sales-reporting/tests/run-tests.sh`'s stale
  `scheduler-unit:0.2.0` (pre-existing).

### Chunk 3 — merged (b475c4d), 2026-11-16

A `coding-executor` finished the merge: `v0.6-w1` taken in (c6cc23c, no
conflict; the faults' `applies_to` and `lines:`, `fixture-v05-refusals`'
pins and `partners.md`, `test_model.py`'s tuples and classes all kept
both sides), `fixture-v06-refusals` re-pinned (be123be), merged as
b475c4d. Suite 1343 OK, 2 skipped; 35 scenario and fixture folders load;
`base:` required, on all 17 tracked `brick.yaml`. W1-y (as built):

- `admitted_incidents(scenario) -> tuple[Admitted]` (`instance`, `by`,
  `partner`, `anchor` — None without `#` in the `player_doc` —, `title`,
  `text`, `start`, `end`, `start_before`, `end_before`, seconds before
  hand-over, None for `T0` or without `until`); `fault_fake_aging ->
  FakeAging(support, reason, tail_minimum, tail_covers, plant_in="any",
  emulate=())`; `fault_history -> tuple[HistoryEntry(kind, fields,
  suppressed_by)]`; `instance_history(scenario, iid)` with `{NAME}` and
  `{INSTANCE_NODE}` resolved recursively (None without `history:`,
  `KeyError` for an unknown instance). Helpers `line_found`,
  `resolve_placeholders`, `instance_values`, `moment_before`;
  `RESERVED_WEB_ROUTES = ("docs", "reports", "status")`;
  `FAULT_PLACEHOLDER_RE` upper-case names only.
- Refusal texts verbatim as W1 item 5 (O251's three, O269's one), plus
  `admitted:`'s seven, the reserved route's and `base:`'s three.
- `lines:` on `pg-archive-command-silent`,
  `governance-statement-log-personal`, `pg-standby-apply-delay` and
  `grafana-alert-for-too-long`; not on `pg-hba-trust-remote` (scenario
  picks the range), prose or block changes, nor the 20-copy fixture
  `fixture-random-page-cost`.
- Chunk choices: T0 is `aging.minimum` before hand-over (at hand-over
  without a scheduler); `history: []` refused (no trail is `kind:
  none`); unknown keys refused in `aging.fake`, `fill`, `admitted`,
  history entries; the documentation family checked both ways;
  `overview_diff`'s `true`/`handed_out` optional in the template only
  (YAML booleans), chunk 7 checks them.
- Noted: a DeprecationWarning at `tools/gm/model.py:5122` (positional
  `maxsplit`, from dde1a148, older than v0.6).

### Chunk 4 — merged (d88169e), 2026-11-16

`v0.6-w1` taken in (8b2ba71); the one conflict, the clinic register's
`scenario.yaml` digest, recomputed with `model.register_digest`, not a
side picked. Merged as d88169e. Suite 1343 OK, 2 skipped;
`check_domain_dir` clean on the seven domains; each fragment passes
chunk 3's `templates/overview.yaml`. W1-z: shop 7 roles 1 job,
vet-core 4/2, vet-housing 2/0, vet-lab 5/7, vet-machinery 5/3+3
pg_cron, vet-portal 2/1 pg_cron, vet-scheduling 2/1; 20 crontab entries
commented. Chunk 2's in-place README pin edits are left for the gate's
"every README matching a fresh regeneration" check.

### Chunk 8 — half 8a built (bb6c3df), 8b resumed by a fresh owner, 2026-11-16

The first owner built 8a (the program's fill mode, P0, the replay guard,
the queue model, the service times) and stopped at the split with a heavy
context (306k tokens; the program and the research read in full). Its
report, kept for the resume in the driver's scratchpad, gives W1-x's 8a
part:

- **P0: partial.** The fill's own SQL binds the virtual instant
  (`%(gm_vnow)s`); the `gm_vclock` shim on each fill session's
  `search_path` covers plpgsql and SQL bodies calling `now()`,
  `clock_timestamp()`, `transaction_timestamp()`. Not reached: the
  `current_timestamp`/`current_date` keywords in a body, a function with
  its own `SET search_path`, `BEGIN ATOMIC`, a column's `DEFAULT now()`.
  The shop is fully covered; the campaign's f1, f2, f3 too; **f4 and f7
  fail** (`rpt.close_day()` is `SET search_path = pg_catalog, pg_temp`),
  so master spec 9.8's fallback (D508) holds for them. A cover (`ALTER
  PROCEDURE rpt.close_day() SET search_path = gm_vclock, ...` for the
  fill's span, restored after) is outside W1 item 8's "session settings
  only": put to the owner, not built.
- The replay guard: a 1,698-line corpus recorded before any program
  change, green on the host and in the image. Scheduler unit tests 109
  OK; stack test 179 PASS.
- The program's interface (`gm_scheduler fill`, `FillConfig`, `PAUSE`/
  `GO`/`DONE`/`FAILED`), the queue model (`queue.Model.call`), the
  metrics record (`<node>.metrics.jsonl`) and `service-times.yaml` (the
  shop's producer and consumer, the campaign's producer; its `consent.*`
  keys and consumer are 11b's): as the report states; W1-x completes with
  8b.
- Choices for review: one fill process for every node; `fill-sql`;
  `visits` and `sequences` inputs; `RESTART_S` = 1 s; failed calls end at
  once.

8b (`gmctl fill`, the record's reader, `test_fill.py`, `fixture-fill/`
and its run, fix 3's means, the visits) dispatched to a fresh
`coding-leader`, resuming from bb6c3df, taking `v0.6-w1` in first.

ISS-006 filed (ccb5a1c): health-check's stack test races cron after the
report-only redeploy. If the wave gate meets it, the test-only fix (a
bounded wait for cron before `gm-validate`) goes in as a gate fix.

### Chunk 8 — merged (f66ba41), 2026-11-16

8b's owner took `v0.6-w1` in (5676098), built 8b (4d78db8), took it in
again (0bc3ab0) and merged as f66ba41, no conflict. Suite 1366 OK, 2
skipped (`test_fill.py` 23 new; `test_aging`'s verb list gained `fill`);
scheduler unit tests 109 OK with the replay guard; `scheduler:0.4.0`
rebuilt to the identical image id. **`fixture-fill`'s short test: 39
passed, 0 failed; the shop's 22:00 to 11:00 filled in 332 s (311 s the
run before), 447 s with the deployment.** W1-x, 8b's part (as built):

- `gmctl fill <scenario-dir> --playground <name>`: needs stage `injected`
  and a restart record (`localimpl.RESTART_RECORD_FILE =
  "fake-aging.yaml"`, `read_restart_record(ldir)`, None when absent) with
  `mode: fake` and an anchor not passed. Refuses before any change: a
  fill already recorded (never resumed), a key without a service time,
  a non-`sql/postgresql` connection, a pgwatch node. Runs the program as
  root in the first scheduler node's container (working folder
  `/run/gm-fill`, limits raised to 2 CPU / 768m and restored); pooled
  connections go straight to the database `pgbouncer.ini` names, pool id
  `<pooler>/<db>/<role>`; queue entries via `instance_history`; the
  exporter's visits from its seed `exporter.conf` and Prometheus' scrape
  interval. A `state` instance planned in [vT0, anchor) is planted at its
  pause by its inject scripts (600 s timeout); a failed planting fails
  the fill.
- `state.yaml`: `fill: {started_at, ended_at, outcome: ok|failed, reason,
  quiet}`; plantings with `{at: real, by: fill, virtual_at, outcome}` and
  `planted_at` virtual; metrics in `local/<pg>/fill/<node>.metrics.jsonl`
  (780 lines for 13 h).
- `fill.quiet`, one item per `postgres` node (`node, what, how,
  left_off, restore, restored_at`). Restored at the fill's end: fix 3 as
  `ALTER ROLE <role> IN DATABASE <db> SET` (load-data's `UNSEEN_SQL`
  values) for each role the fill connects as, earlier values put back;
  fix 7's `autovacuum_naptime = '1s'`. Left off for clean-restart:
  `cron.launch_active_jobs = off`, archiving (`archive_command =
  '/bin/true'`, unit-tested only), the cron daemon.
- Left in the database: the rows at virtual times; `gm_vclock` dropped
  (also on failure); the fill's PostgreSQL and pooler log lines, for
  clean-restart.
- Autovacuum (naptime 1 s; about 150 virtual s per real s): products 45
  against 73.8 expected from R's rate (0.6x), customers 0 against 0.9,
  orders, delivery_events and order_lines 0 (R's orders not comparable,
  f9). The exporter's sessions: 3126 against 3120 expected.

Choices for review (no deviation from the spec or W1): fix 3 per role
and database rather than server-wide; the naptime fixed at 1 s (the
floor; it could follow the fill's speed); the fixture adds the pooler
and an every-minute pg_cron job, drops Grafana, keeps f1's seed error
lines; exporter visits one statement per default collector; a failed
planting fails the fill; the fixture's README generated with the
skill (two skill gaps noted: `cron.schedule` jobs not described, no
`cron.timezone` in the fixture's seed).

Risks passed on: **load-data writes with the real `now()`, so in a fake
game its rows run up to the deploy and overlap the fill's virtual span
(chunk 9)**; a held repeatable-read session can block an inject script at
a pause (600 s bound); cron and archiving paths unit-tested only; f8's
latency step appears only once chunk 11 adds its `queue` entry.

### Owner ruling: the `rpt.close_day()` cover adopted, 2026-11-16

Asked: P0 can't reach the campaign's f4 and f7 (`rpt.close_day()` pins
its own `search_path`); keep master spec 9.8's fallback (D508), or adopt
a cover that sets that procedure's `search_path` to `gm_vclock,
pg_catalog, pg_temp` for the fill's span and restores it exactly after,
leaving only a catalog row-version tell, beyond W1 item 8's "session
settings only"? **The owner chose: "Adopt the cover (Recommended)".**
Sent to `spec-writer` to record and place in the plan.

### Wave 1's chunks all merged, 2026-11-16

Chunks 1, 2, 3, 4 and 8 merged. Next: G5 (dependency post-change check
on wave 1's images), then the wave gate.

### G5 — dependency post-change check: CLEAR, 2026-11-16

`security-advisor`, a833c67: nine bricks are the v0.5 images retagged,
`scheduler` 0.4.0 has the same 142 packages as 0.3.0; chunk 8's fill mode
imports only the standard library, psycopg and PyYAML. Docker Engine
29.9.3 (NVD: 0). cve-watch: 52 at or above medium, all pre-existing and
triaged, none introduced. `.tech` updated.

### Plan v4 (420e730), 2026-11-16

`spec-writer` recorded the owner's cover ruling and its consequences:
- **D523:** at the fill's start, every routine whose `proconfig` pins
  `search_path` is auto-discovered, given `gm_vclock` first, listed, and
  restored exactly at the end or on failure; clean-restart puts back any
  leftover. The catalog row-version tell is a documented limit. Campaign
  f4 and f7 count as supported on one short campaign fill's evidence,
  tail-only otherwise.
- **D524:** chunk 15 (the cover) inserted in wave 2: wave 2 is now
  chunks 6, 7, 9 and 15.
- **D525:** load-data and the T0 plantings run on the virtual T0's clock
  (chunk 9a); what can't be backdated (a column `DEFAULT now()`) is
  reported, not patched.
- D526 reserved by mistake, unused.

Put to the owner, both minor, neither blocking before wave 2: (1)
auto-discovery against a declared list, given the clinic's ~25 pinned
routines (recommended: keep auto-discovery); (2) D525's reach to the T0
plantings (recommended: keep it).

### Wave 1 gate — all green, 2026-11-16

`coding-executor`, verification level wave gate, on armenelos, 15:58 to
17:40 CET, from a833c67, κ = 1, under the lock and the inhibitor.

| Item | Result |
|---|---|
| Unit suite (`tools/tests`) | 1366 OK, 2 skipped, 317 s |
| Scheduler unit tests, replay guard | 109 OK, replay byte for byte and deterministic, 228 s |
| api unit tests | 36 OK |
| `sh -n`/`bash -n`; `py_compile` | 333 shell files; 464 Python files |
| Ten bricks: build, stack test | postgres 316/0, bastion 117/0, pgbouncer 121/0, scheduler 179/0, api 89/0, prometheus 132/0, postgres-exporter 104/0, grafana 131/0, pgwatch 73/0, health-check 97/0 (and 3 reruns on the fix) |
| `check-base.sh` | 10/10 Debian GNU/Linux 13 |
| Smokes | smoke 61, monitoring 43, governance 121, load 73 |
| Scenario smokes | bookshop 19, fernway-clinics 18, tarnbeck shop 26, tarnbeck campaign 33 |
| Loader's new refusals (chunk 3's 11 classes) | 60 OK |
| `check_scenario` | 5/5 scenarios, 31/31 scenario fixtures |
| `check_domain_dir` | 0 problems on the seven domains |
| `fixture-fill/run-short-test.sh` | 39/0, 431 s with the deployment |

Figures (armenelos, 2026-11-16): the fill took 316 s for 13 virtual hours
on two scheduler nodes; the exporter opened 3126 sessions against 3120
expected; autovacuum ran 52 times on `products`, 0 elsewhere. Gate wall
clock about 1 h 42 min.

- **Failures:** none traced to a chunk.
- **ISS-006:** the race showed (first run "waited 2s"); test-only bounded
  wait for `ps -C cron` (up to 90 s) in 78fe203, three green runs after
  it; issue In Progress (b15e35a), the brick's two medium-term options
  left for its next version.
- **G9 (dpkg):** no change; scheduler 0.4.0's apt layer missed the cache
  (image id 73f52fa1eb26 to 2589362d6a90) with an identical package list.
  No G9 row.
- **Left:** the unit suite ran outside the docker lock (nothing else was
  using docker; it passed); a rerun goes under the lock. `/home` has about
  16 GB free; no images removed. Nothing labelled with a game id or
  `dbagm` left running.
- **Wave sync:** no intent register or data register in this repo, so no
  `documentalist` or `data-steward` sync; the dependency check was G5.
- **G10.1** added (wave 1's forms as built), held by `spec-writer`.
- `doc-ids compare main v0.6-w1`: 0 collisions, 0 warnings.
- **Cost figures:** not recorded. `agent-stats wave 1` (`--line` and
  `--md`) printed nothing in 300 s each and was killed, as
  `agent-stats chunk 1 --line` had hung earlier in the wave.
- **Over 300k context:** chunk 8b's `coding-leader` (a0a3adacdf99c0ba2):
  419k tokens, 185 tool calls, about 7 h 22 min, past the rotation point
  the brief sets (about 100 tool calls). It built `gmctl fill`, its
  fixture and fixes 3, 7 and 9, and ran the fixture's fill several times
  under the lock, and it didn't stop at a WIP commit. It stayed alive
  after its report until 2026-11-16 evening. For wave 2: rotate a chunk
  owner at its WIP point instead of letting it carry on, and end it once
  it has reported.

Open after wave 1: G6 (security preflight on `jq`/`tmux`) before chunk 6;
capture W2; G10.1; the owner's two minor questions above; the merge into
`main` on the owner's word. Branches left: `v0.6-w1` (worktree
`~/work/db_audit_gm-wt/v0.6-w1`); the merged chunk branches
`v0.6-c1-reference`, `v0.6-c2-versions`, `v0.6-c3-loader`,
`v0.6-c4-overview-inputs`, `v0.6-c8-fill` (no worktrees), removed with
the wave's merge; `v0.6-spec` (worktree, merged into `main` at 819baab).

## Wave 2 — started 2026-11-17

Chunks 6, 7, 9, 15 (κ = 2). Branch `v0.6-w2`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.6-w2`, cut from `main` at ea13456
(wave 1 merged).

### Gates checked at the start

- G3 (network at image build time), hand check 2026-11-17: Debian's
  trixie `Release`, `trixie-pgdg` `Release`, GitHub's s6-overlay,
  Prometheus, `postgres_exporter` and pgwatch releases, and the
  Dockerfile's Grafana download
  (`dl.grafana.com/grafana/release/13.3.1/grafana_13.3.1_42849527790_linux_amd64.tar.gz`)
  answer 200. Cleared for wave 2.
- G4 (swarm), hand check 2026-11-17: armenelos active, Leader; the VPS
  `vps-5718ad52` `Ready`, `Drain`. No stack deployed. Cleared for wave 2.
- Host: `/home` 89 % used, 15G free.
- G6 (dependency preflight on `bastion` 0.6.0's `jq` and `tmux`),
  `security-advisor`, 2026-11-17: **CLEAR WITH NOTES**. Six packages
  come in with `--no-install-recommends` (apt simulate in a throwaway
  `debian:13-slim`, Debian 13.7): `jq` and `libjq1` 1.7.1-6+deb13u4,
  `libonig5` 6.9.9-1+b1, `tmux` 3.5a-3, `libevent-core-2.1-7t64`
  2.1.13-stable-1~deb13u1, `libjemalloc2` 5.3.0-3; `libutempter0` (a
  Recommends) not installed. The note: DEBIAN-CVE-2025-9403 on jq, open
  in every suite, Debian "unimportant" (testsuite only, `jq
  --run-tests`), not reachable. NVD's 17 matches on jq 1.7.1 are all
  fixed in trixie at or below deb13u4 (backport false positives).
  Nothing for tmux 3.5a (CVE-2026-11623 is 3.6a's), oniguruma, libevent
  or jemalloc. Packages left unpinned. `.tech` unchanged.
  **For G7:** add `jq` and `tmux` `[[platform]]` entries (CPEs
  `cpe:2.3:a:jqlang:jq`, `cpe:2.3:a:tmux_project:tmux`; source strings
  naming the Debian versions above, the images, the use, and the two
  notes); `jq` is already in the grafana and postgres-exporter images
  and `.tech` does not record it, so G7 dpkg-queries them too. **Owner
  decision at G7:** with `jq`'s CPE set, the sweep raises the 17
  backported CVEs, which would need 17 `[[ignore]]` entries approved
  ("fixed by Debian backport in 1.7.1-6+deb13u4 or earlier", review
  2027-02-01 or the next trixie jq upload); the alternative is no CPE
  and the Debian tracker only.

### Capture W2 — the bastion's front and status file, the overview's form, the fake timeline, the seed's clock and the restart, the cover (chunks 6, 7, 9, 15; read by 10 to 14)

Drafted 2026-11-17 for the wave driver, before any code. Sources: the
capture lines of chunks 6, 7, 9 and 15 and the Depends and capture lines
of chunks 10 to 14 (plan v4); their spec packs (master spec 6.7, 6.9,
6.10, 7.1 to 7.7, 8.1 to 8.4, 8.7, 9.3 to 9.6, 9.9, 9.10; access model
4 and 7); [formats.md](../../formats.md) v35; spec D515 to D525; W1 and
its as-built records (W1-w, W1-x, W1-y, W1-z, plan v4); the code on
`v0.6-w2` at ea13456 (`tools/gm/{render,deploy,localimpl,restart,fill,inject,aging,model}.py`,
the bastion's `brick.yaml`, `gm-entrypoint` and s6 services,
`bricks/scheduler/program/gm_scheduler/{fill,__main__}.py`, the
`scenario-document` and `data-register` skills, the clinic's and the
shop's files). W1's rules hold: the spec is cited, not restated;
**(choice)** marks a point the sources left open, settled with its
reason; each item names its writer and its readers; chunk internals stay
out. As-built records: **W2-w** (chunk 6: the front's files, the status
file and the brick pages as built, the footprint), **W2-x** (chunk 9: the
record as written, the clock means' findings per scenario, the shop's
WAL rate and its source member, the fixture's figures), **W2-y** (chunk
15: `fill-sql`'s options as built, `TestP0`'s cases), **W2-z** (chunk 7:
the clinic's counts, the loader's texts as built).

Held, cited not restated: W1 items 0 (accessors), 4 (`admitted_incidents`,
`fault_fake_aging`, `RESERVED_WEB_ROUTES`), 7 to 9 (the fill, its
`state.yaml` record, `fill.quiet`, P0, what the fill leaves) and W1-x;
the host timers' unit names `dbagm-<game_id>_<action>` (spec D173,
`aging.unit_name`); the credentials written into `partners.md` by the
entrypoint (spec D365, D433). Every instant W2 adds is UTC, written
`YYYY-MM-DDTHH:MM:SSZ`; every duration W1's `<integer><s|m|h|d>`.

**1. What render delivers to the bastion** (chunk 6 writes; 9 extends
render; 14 reads)

- **The brick pages (choice)**: a config kind `brick-doc`, one per brick
  of a node the players may reach (every node not in
  `model.third_party_nodes(data, sdir)`, the bastion included),
  topology order, one per brick id: name `<game_id>_bastion_doc-<brick-id>`,
  file the pinned brick's `docs/player.md` relative to the scenario
  folder (as `mounted_configs` does), path
  `/opt/gm/docs/bricks/<brick-id>.md`, `0:0`, `0444`. Built by
  `build_implementation` (fit) and checked by `render._check_fit` ("the
  brick pages changed since gmctl fit: fit again"), as the mounted
  material is; the new names enter `_derived_lengths`. Why at fit: the
  set depends on the topology only, and fit already derives every other
  config.
- **The status file (choice)**: JSON, since the bastion has `jq` (7.7)
  and no YAML parser:

  ```json
  {"generated_at": "2026-11-21T09:00:00Z",
   "partners": [{"id": "northfield-lab", "name": "Northfield Veterinary Laboratories",
                 "anchor": "northfield-veterinary-laboratories",
                 "incidents": [{"instance": "s11", "title": "Delayed results delivery",
                                "text": "...", "start": "2026-11-21T08:00:00Z",
                                "end": "2026-11-21T10:00:00Z"}]}]}
  ```

  Every third party with a `player_doc`, in `third_parties:` order, those
  admitting nothing with `"incidents": []`; `anchor` the `player_doc`'s
  fragment or `null` (W1-y); `end` `null` without `until`; incidents in
  `start` order. Only planted instances: those of `inject.fault_instances
  (scenario, impl)`, so whatever `localimpl.left_out(impl)` returns
  admits nothing (item 7 adds the refused instances there). Instants:
  `handover-<N>h` the planned hand-over minus N hours; `T0`
  `render.t0_instant(timeline)`, which chunk 6 writes as
  `timeline.get("virtual_t0") or timeline["rendered_at"]` (the render
  time, as `moment_instant` takes it; without a timeline, the render
  time), so chunk 9 sets the key and touches nothing of 6's. A real
  game's `T0` incident thus shows from the render, before any player
  arrives.
- **Delivered as (choice)**: a secret of a new kind `rendered`, declared by
  `localimpl.node_secret_declarations` on the bastion when some third
  party carries a `player_doc` (as O251 maps `partners.md`): name
  `partners_status`, Swarm `<game_id>_partners_status`, file
  `local/<playground>/secrets/partners_status.json` (0600 in the 0700
  folder), path `/opt/gm/secrets/partners_status.json`, `0:0`, `0400`.
  Render writes it in `write_rendered`, so a restart's re-render
  (`restart.py`) rewrites it with the rest; `deploy.generate_credentials`
  skips kind `rendered`; `create_objects` creates it as any secret.

**2. The front** (chunk 6 writes; 14 reads; 7's handout served)

- **Paths**, under `/run/web-front/www/` (the existing `WEB_DIR/www`),
  all behind the server's basic authentication:

  | URL | File or source | nginx |
  |---|---|---|
  | `/` | `index.html` (the home) | the existing `location = /` |
  | `/docs/<id>`, `<id>` one of `readme`, `story`, `issues`, `data-policy`, `partners`, `data-register`, `network-overview` | `docs/<id>.html` | `location /docs/ { root ...; default_type text/html; try_files $uri.html =404; }` |
  | `/docs/bricks/<brick-id>` | `docs/bricks/<brick-id>.html`, from `/opt/gm/docs/bricks/<brick-id>.md` | the same location |
  | `/reports/` | `/home/player/reports/` | `location /reports/ { alias /home/player/reports/; autoindex on; disable_symlinks on; add_header Content-Security-Policy "sandbox allow-scripts" always; }` |
  | `/status/<id>/` | `status/<id>/index.html` | `location /status/ { root ...; index index.html; try_files $uri $uri/ =404; }` |

  The docs and the home are rendered by the entrypoint at each start
  (from `/opt/gm/starter`, the resolved `partners.md`, the brick
  configs); the status pages by the service below. **`disable_symlinks
  on` (choice)**: a player's link in `~/reports/` would otherwise serve
  whatever `www-data` can read (7.5: nothing outside the folder).
- **Heading ids (choice)**: cmark-gfm emits none, yet `player_doc`
  fragments (`partners.md#the-regions-practices`) and the overview's
  summary links need them. The page renderer gives every `<h1>` to
  `<h6>` an `id` by GitHub's rule (lower-case; every character but
  letters, digits, spaces, `-` and `_` dropped; spaces to `-`; a repeat
  suffixed `-1`, `-2`), so a link that works in the GM's Markdown preview
  works on the bastion; chunk 7 writes anchors by the same rule
  (item 4). The partners' page gets, under each partner's heading, a link
  to `/status/<id>/`.
- **The status service (choice)**: s6 longrun `status-pages`
  (`s6-rc.d/status-pages/`, in `user-bundles.d/user/contents.d/`), root,
  running `/usr/local/lib/gm/render-status` then sleeping 60 s; each page
  written to a temporary file and moved into place, `root:www-data`
  `0440`. Without `/opt/gm/secrets/partners_status.json` it asks s6 not
  to restart it (`s6-svc -O .`, as `web-front`) and no `/status/` page
  exists. Page renderers live in `/usr/local/lib/gm/` (W2-w names them).
- The home lists one status page per partner by `name`, read from the
  status file by the entrypoint (root); its header names the customer by
  the first `# ` heading of `story.md` **(choice**: 7.2's "from the
  story", the one source chunk 7's overview header uses too).

**3. The true overview, `gm/network-overview.yaml`** (chunk 7 writes; 13
and 14 read)

- **(choice)** Top keys, in order: `generated_from` (each input's
  `sha256:<hex>`, as the register's; the inputs of 8.4 plus
  `player/story.md`, item 2), `header`, `entries`, `third_parties`.
  `header`: `customer`, `network`, `bastion`, `node_health`, `trust`, each
  the fixed text of 8.1 as rendered.
- **An entry**: `node`, `group` (`database`, `application`,
  `integration`, `monitoring`: 8.1's groups), `role` (the skill's fixed
  table), `access` and `activity`, then **the fields under the names
  `overview_diff:` uses** (formats.md, 6.2): `description`, `site`
  (absent when none), `system`, `applications`, `sizing`, `databases`,
  `fed_and_used_by`, `uses`, `users`, `third_parties`, `tasks`, `backups`.
  Scalars are the line as handed out; the fields the loader's coverage
  reads are lists of records, each also rendered as one line:
  `databases` `{database, holds, register: [<entry id>]}`;
  `fed_and_used_by` and `uses` `{node, database, role, what}` (an HTTP
  use `{node|partner, what}`); `users` `{who, database, role}`; `tasks`
  `{task, when, zone, what, source: jobs|crontab|pg_cron|purpose}`;
  `backups` `{kind: standby|wal-archive|base-backup|vault|check, line}`,
  or the one item `{kind: none, line: none}`. Why the diff's names: a
  diff's `field` is then a key of the entry, and its `true` one of that
  field's rendered lines.
- `third_parties`: `{id, name, hostname, anchor}`, one per partner with a
  `player_doc`, access none implied.

**4. The handout, `player/network-overview.md`** (chunk 7 writes; 6 serves
it; 14 plants a change in it)

- **(choice)** Layout: the header (8.1, its lines in `header`'s order);
  `## Summary`, a table `Name | Role | Description | Your access`, each
  name `[<node>](#<node>)`; one `##` section per group in 8.1's order
  (`Database servers`, `Applications and APIs`, `Integration and
  back-office engines`, `Monitoring`); each entry `### <node>` (anchor:
  the node's name, which item 2's rule leaves unchanged); its fields as
  one bullet each, `- **<Field>**: <line>`, a list field's items as
  nested bullets, one line each; `## Third parties` closing, a table
  `Partner | Hostname | Your access`, each partner linking
  `partners.md#<anchor>`. One line per fact, so an overview fault's
  change replaces whole lines of one entry and its diff names them.
- The loader compares the header block and each entry's **Your access**
  bullet with the true overview's, text for text.

**5. The loader's texts** (chunk 7 writes; its unit tests read)

- **(choice)** The register's pattern (`model.py`'s register check): the
  file, the place, what is wrong, the rule, the way out. A miss is a
  generation error (8.4), never a fault, so coverage texts end
  `a generation error: regenerate with the network-overview skill`; a
  stale digest `... changed since the overview was generated (its digest
  differs): stale overview: regenerate with the network-overview skill`.
  The named cases, each with its unit test (plan chunk 7, Done when):
  - `gm/network-overview.yaml: entries: customer node <node> is in no entry (master spec 8.4): ...`
  - `gm/network-overview.yaml: entries[<node>]: <node> is the bastion|a third party's node, never an entry (master spec 8.3): ...`
  - `gm/network-overview.yaml: <node> -> <database> as <role> (<source>) is under no entry's fed_and_used_by (master spec 8.4): ...`
  - `gm/network-overview.yaml: <task> (<source>) is under no entry's tasks (master spec 8.4): ...`
  - `gm/network-overview.yaml: <node>: archive_mode = on (<file>) is under no entry's backups (master spec 8.4): ...`
  - `player/network-overview.md: names <name>, a third party's node (master spec 8.3)`
  - `player/network-overview.md: <node>: Your access reads "<x>", not the true overview's "<y>" (master spec 8.3: never a deviation)`
  - `player/network-overview.md: the header differs from the true overview's (master spec 8.1: never a deviation)`
  - the requirements: `scenario.yaml: a scenario listing domains: has a network overview: gm/network-overview.yaml missing (master spec 6.1, 8.4): generate it with the network-overview skill`;
    `scenario.yaml: nodes[<node>].description: missing: every customer node of a scenario with an overview has one (master spec 6.1)`;
    `domains/<id>/data/overview.yaml: roles|jobs: <name> missing, a login role|job the domain creates (<file>) (master spec 6.5)`.
  W2-z records the full list as built.

**6. The scenario document and the starter pack's README** (chunk 7
writes; 12 and 13 read)

- **"Network overview" section (choice)**, an `if:` block after "Data
  register", on its model: the handout's path and its mapping, the true
  overview's path; the header's customer; the counts (entries per group,
  third-party rows); one table per overview fault instance, its
  `overview_diff:` as the answer key writes it (node, field, true, handed
  out, `absent` for an entry missing or invented). **Beside each fault**
  (8.2): each answer-key instance on a customer node gains one line
  quoting that node's entry lines whose 8.2 source its `seed_changes`
  touch (`postgresql.conf`: Applications, Backups; a crontab, `jobs.yaml`
  or `cron.sql`: Background tasks; a connection's file: Fed and used by,
  Uses), else a link to the entry. Why: those are the lines that can
  hide or help a system fault (8.5).
- **8.7's README is the starter pack's `player/README.md`** (its "The
  system" table and network paragraph, its "The web interfaces"), hand
  written, not the scenario document: chunk 7 edits the clinic's
  (one line pointing to the overview) and shrinks the web-interfaces
  table of the four scenarios that have one to the home page's address
  (Preflight corrections, item 1).

**7. `gmctl render --aging fake`** (chunk 9 writes; 6's status file,
10, 12, 13 read)

- **(choice)** `--aging real|fake`, default `real`; `--handover` required
  as today; a real render removes a leftover restart record.
  `--test-tail-floor <duration>`, undocumented, the harness's alone,
  recorded in `test_harness_override.tail_floor` (as `--test-leave-out`).
  One pure function computes the timeline from a scenario, a planned
  hand-over and a floor (`render.fake_timeline`, W2-x names it):
  virtual T0, anchor, tail (9.6), the refused instances with reasons;
  chunk 12's "Fake aging" section calls it.
- **Refused instances (choice)**: an ineligible instance is refused, not
  the game: render prints each with its reason (its `aging.fake.reason`,
  or `not assessed: no aging.fake`), the record lists it (6.9), and
  `timeline.refused` lists its id, which `localimpl.left_out(impl)` adds
  to the harness's, so every verb (inject, fill, checks, the status
  file, history) leaves it out through the one function. Why: 6.9 and
  12.2 ("f10 refused") show a game running with refused instances. A
  refused fault's seed changes stay in its copies (as the harness's
  leave-outs): the GM replaces it (9.1). Preflight corrections, item 7.
- **`implementation.yaml`'s `timeline`** in a fake game also carries
  `virtual_t0`, `anchor`, `tail` and `refused`; the instances'
  `planned_at` as today (from H); `moment_instant`'s `T0` and
  `t0_instant` read `virtual_t0`.
- **The story line (choice)**: in a scenario with scheduler nodes the
  bastion's `story.md` is always a rendered seed file
  (`localimpl.rendered_seed_names`), copied as is in a real game, so fit's
  configs don't depend on the mode; in a fake game render appends one
  paragraph: `The servers were restarted for maintenance on <YYYY-MM-DD>
  at <HH:MM> UTC; older logs were archived.`, the planned anchor's.
  Why a date and UTC: the anchor's hour need not be "this morning", and
  every time the game shows is UTC (7.6).
- **Monitoring at zero (choice)**: `localimpl.MONITORING_BRICKS =
  ("prometheus", "grafana", "postgres-exporter", "pgwatch")` (9.4 step
  2's list). In a fake game render writes `replicas: 0` for their nodes;
  deploy's health wait skips them; clean-restart rewrites `stack.yml`
  with every replica at 1 before its restart, so a later restart or
  redeploy keeps the monitoring up.

**8. The restart record as written** (chunk 9 writes; 10, 12, 13 read)

- Exactly 6.9's form at `local/<playground>/fake-aging.yaml`; render
  writes `mode`, `virtual_t0`, `anchor` (planned), `tail`,
  `handover_planned`, `refused: [{instance, reason}]`; clean-restart
  adds `restart: {at, story_line, explains: [{observation, where,
  in_world}]}`; chunk 10 adds `history: {at, result, seam}`. **(choice)**
  `explains` is 9.10's table kept where it holds in the game (a row on
  archiving only with an archiving node, the covered routines' row only
  when `fill.quiet` lists a cover). After the restart every verb takes
  `restart.at` as the tail's start, the planned `anchor` before it.
- **Progress stays in `state.yaml` (choice**, W1 item 7's rule): `hold`
  (item 10), `fill` (W1), `clean_restart: {started_at, ended_at,
  outcome, reason, wal: {<node>: {padded_bytes, pg_wal_bytes,
  seconds}}}`. No new stage: the stage stays `injected` until
  `start-load`, which in a fake game requires `clean_restart.outcome:
  ok`.

**9. The seed's and the T0 plantings' clock (D525)** (chunk 9 writes; 12
reads; **depends on owner question 2**)

- **(choice)** In a fake game, load-data and inject's T0 plantings run on
  P0's means at the fixed instant `virtual_t0`:
  - `gm_vclock` created, as postgres and unseen, in every database of
    every `postgres` node, from `gm_scheduler fill-sql` run in the
    game's first scheduler node (as `gmctl fill` gets it); dropped after
    the verb by `fill-sql --drop` (item 13's checked drop);
  - each session through `PGOPTIONS`: `-c gm.vclock=<virtual T0> -c
    search_path=gm_vclock,pg_catalog,"$user",public`;
  - `load_epoch` (`inject.load_epoch`) the virtual T0;
  - in the SQL load-data sends, outside literals, comments and
    dollar-quoted bodies (the splitter `model.sql_statements` uses):
    `current_timestamp`, `current_date`, `localtimestamp`,
    `current_time` and `localtime` replaced by their `gm_vclock.now()`
    form in every statement but DDL, and in DDL (`CREATE`, `ALTER`)
    every unqualified `now()`, `transaction_timestamp()`,
    `statement_timestamp()` and `clock_timestamp()` written
    `pg_catalog.<name>()`.
  Why the DDL rule: a stored expression (a column default, a view, a
  `BEGIN ATOMIC` body) binds the function it names when created, so an
  unqualified `now()` resolved through the shim would bind
  `gm_vclock.now()`, and the shim's drop would take it away
  (`scenarios/tarnbeck-outdoor-campaign/data/reporting.sql:396`,
  `DEFAULT now()`); qualified, the catalog holds what a real load leaves.
  The keywords bind nothing and are left in DDL.
- Inject scripts are shell programs run unchanged (as the fill runs them
  at its pauses): they get the session means through `PGOPTIONS` only;
  no script in `faults/*/inject/` uses a keyword today (they appear only
  in `.sql.snippet` materials, which reach the seed's files).
- What the means can't reach (a column's `DEFAULT now()` left to the
  default, a keyword in a routine's body, a `CREATE TABLE AS` at load) is
  reported by chunk 9's check (no value after the virtual T0 in any
  `timestamptz`, `timestamp` or `date` column), each finding in W2-x,
  never shifted after the fact. The real mode is unchanged.

**10. The hold: the real-clock actors off from the deploy** (chunk 9
writes; 15's fill reads; 9b restores)

- **(choice)** In a fake game `gmctl deploy`, once the nodes are healthy
  and before anything else, turns off on each `postgres` node what the
  fill turns off as "left off" (`cron.launch_active_jobs = off`, the cron
  daemon, archiving: W1-x's means), recorded in `state.yaml` as `hold:
  {at, items: [<fill.quiet item>]}`, `left_off: true`. Why prevent
  rather than clean (W1 item 8 left it to W2): what those actors do
  between the deploy and the fill (an every-minute `pg_cron` job, as
  `fixture-fill` has; a vault upload; a crontab job's effects) writes
  real times into tables and the vault, which clean-restart could only
  forge away, and it breaks item 9's "no time after the virtual T0".
- The fill (chunk 15, fill.py) neither turns off again nor lists in
  `fill.quiet` an actor the hold lists, so its restore stays the hold's
  (the fill's survey would otherwise read the held value as the
  original). clean-restart turns the hold's and the fill's left-off
  items back on in its restart, as W1 item 8 says.

**11. `gmctl clean-restart`** (chunk 9 writes; 10, 12 read)

- Requires `fill.outcome: ok` (W1 item 7) and no `clean_restart.outcome:
  ok` yet. Its order (9.4 step 6, 9.9 fixes 2, 4, 8), the contract
  chunks 10 and 12 test against:
  1. every `fill.quiet` item not `left_off` and without `restored_at`
     restored by its `restore` in `restore.database` (absent: `postgres`)
     or its root `script`, and `restored_at` set; a leftover `gm_vclock`
     dropped in every database (item 13's checked drop); a failure here
     stops it, recorded;
  2. the WAL padded, then `CHECKPOINT` and `pg_switch_wal()` twice;
  3. the statement, shared, checkpointer and WAL statistics reset
     (never the table and index statistics, 9.9);
  4. every service stopped; the PostgreSQL, pooler and cron logs
     removed; each data file's modification time set to its last
     virtual write; the hold's and the fill's left-off items restored
     for the next start; `stack.yml` rewritten (item 7);
  5. every service started at one instant, the monitoring with them;
     the measured instant written as `restart.at`.
- **The WAL rate (choice)**: `scenarios/<id>/nodes/<postgres
  node>/wal-rate.yaml`, beside the node's seed files and never mapped,
  as `service-times.yaml` is:

  ```yaml
  source: >-            # where it was measured: the run, its date, the file
    research/fake-aging 10d1bc6, run R (fa-real, 2026-11-14 to 15), <member>
  bytes_per_hour: 0     # WAL the node writes in an hour at the scenario's load, measured
  ```

  A day's worth is 24 times it. clean-restart refuses a `postgres` node
  without one, naming the file. Chunk 9 writes the shop's (from the
  reference, the member named in W2-x) and `fixture-fill`'s (the shop's,
  with its source); chunk 11 the campaign's.

**12. `start-load`, the timers, the outages** (chunk 9 writes; 10 and 13
read)

- **(choice)** In a fake game `start-load` records T0 as `virtual_t0`,
  writes no `reload status=ok` line, creates plant timers for tail
  plantings only (the fill planted the rest, W1 item 7), and schedules
  the early check, unit `dbagm-<game_id>_early-check` (today's): with a
  tail under two hours at the history's due time plus 5 min
  (`EARLY_FLOOR`), else at the earlier of `restart.at` plus half the
  tail and H minus one hour (9.4 step 9). The history import's unit is
  **`dbagm-<game_id>_history`**, due `restart.at` plus 12 min
  (`aging.HISTORY_AFTER`, chunk 9's constant); chunk 10 creates it in
  `start-load` with its verb, and makes the early check wait, bounded,
  for `history` in the record and read it.
- **Outages (choice)**: in a fake game the outage window starts at
  `restart.at`, never at the recorded T0: before it the nodes didn't
  exist or the monitoring was at zero by design, and counting it would
  push the earliest hand-over by the virtual span.

**13. The cover** (chunk 15 writes; 9, 11, 12 read; **depends on owner
question 1**)

- **What it covers** (9.4, spec D523): in each database `gm_vclock` is
  created in (the fill's sessions' databases), every routine with
  `prokind` `f` or `p` whose `proconfig` has a `search_path=` entry,
  outside `pg_catalog`, `information_schema`, `pg_toast`, the temporary
  schemas and every schema `gm_*` (`gm_vclock`, `gm_check`, `gm_src_*`),
  **and not an extension's member (choice**: `pg_depend` `deptype = 'e'`;
  an extension's routines are not the scenario's, and altering one is a
  change `ALTER EXTENSION` and a dump see). The covered path: 9.4's.
- **Its `fill.quiet` item (choice)**, W1-x's form plus `routine` and
  `restore.database`:

  ```yaml
  - node: reporting
    what: "P0's cover: search_path of procedure rpt.close_day() in sales (spec D523)"
    how: ALTER PROCEDURE rpt.close_day() SET search_path = gm_vclock, pg_catalog, pg_temp
    left_off: false
    routine: {database: sales, kind: procedure, signature: rpt.close_day(),
              original: "pg_catalog, pg_temp"}
    restore: {user: postgres, database: sales,
              sql: ["ALTER PROCEDURE rpt.close_day() SET search_path = pg_catalog, pg_temp;"]}
  ```

  `restore.database` absent means `postgres`, so W1-x's items read as
  before; the fill's end (`undo`) and clean-restart (item 11) both
  connect to it. One item per database and signature, recorded before
  the `ALTER` is sent; restored when `proconfig` equals the original,
  entries and order. A routine gone at restore time counts as restored.
- **After each planting** at a pause, the look again: a routine whose
  `search_path` entry no longer starts with `gm_vclock` (replaced) or
  that has no item (added) is covered, its item's `original` and
  `restore` rewritten to the new setting.
- **The fill's outcome (choice)**: the outcome is the program's: `ok`
  when it ended `DONE` and every planting succeeded, even if an end
  restore or the shim's drop failed; those items stay without
  `restored_at`, the problems in `fill.reason`, and clean-restart
  completes them (item 11, step 1). `FAILED` and `gmctl fill`'s own
  failures stay `failed`, torn down (W1 item 7). This changes W1-x's
  rule (`tools/gm/fill.py:991`, any end problem made the fill `failed`).
  Why: an end restore failing leaves the night's rows whole, tearing a
  complete fill down for a retryable `ALTER` is waste, and 9.4 gives the
  leftover to clean-restart.
- **The shim's drop never cascades onto a customer object (choice)**:
  `fill-sql --drop` (today `DROP SCHEMA IF EXISTS gm_vclock CASCADE`,
  `bricks/scheduler/program/gm_scheduler/fill.py:107`) first fails,
  naming them, if any object outside `gm_vclock` depends on its
  functions (a default, a view, a `BEGIN ATOMIC` body bound to the
  shim), then drops; the fill's end, load-data's and inject's (item 9)
  and clean-restart's drops all use it.
- **What chunk 12's tells check reads**: no `proconfig` entry
  `search_path=gm_vclock...` and no schema `gm_vclock` after
  clean-restart.

**14. Wave 2's order, owners and the interfaces across merges** (plan
"Wave 2's order")

- **Order**: 6 and 7 first; 9 in 7's slot, 15 the next free one. 6 and 7
  merge in either order (no shared file); **15 before 9; 9 last**, after
  6 and 15, taking `v0.6-w2` in first.
- **Owners**:
  - chunk 6: the bastion's brick but chunk 2's lines; `bricks/postgres/docs/player.md`;
    in `tools/gm/`, items 1 and 2's parts of `localimpl.py` (the
    `brick-doc` configs, the `rendered` kind, `partners_status`),
    `render.py` (`t0_instant`, the status file in `write_rendered`, the
    fit check), `deploy.py` (`generate_credentials`), `restart.py`;
    `test_{render,deploy,restart}.py`; `fixture-status/`;
  - chunk 7: `tools/gm/model.py`, alone in wave 2; the
    `network-overview` skill; the `scenario-document` skill; the
    `game-master` skill's `SKILL.md` (setup step 2); every scenario
    document and the four `player/README.md`; the clinic's files; the
    fixtures' catalogue domains;
  - chunk 15: `bricks/scheduler/` (the program, its tests, `docs/gm.md`),
    `tools/gm/fill.py`, `tools/tests/test_fill.py`, the fill's row of
    `gmctl.md`;
  - chunk 9: the rest of `render.py`, `deploy.py`, `localimpl.py` after 6;
    `aging.py`, `state.py`, `inject.py`, `cleanrestart.py`, `__init__.py`;
    their tests; the `gmctl.md` rows; `fixture-fill`'s run script and the
    two `wal-rate.yaml`.
- **What 9 builds on, fixed here so neither waits**: from 6, the status
  file reading `timeline.virtual_t0` and `localimpl.left_out(impl)`, so
  9 only writes `timeline`'s keys (item 7); from 15, the cover item and
  `restore.database`, the hold read by the fill (item 10), the outcome
  rule and the checked drop (item 13). **9 does not change
  `bricks/scheduler/program/`**: its clock means are host-side
  (`inject.py`) and take the shim from `fill-sql` as built by 15. 9 keeps
  `inject.inject_plan`'s signature, which `fill.py` calls at its pauses.
  Shared lists: `gmctl.md` (15, then 9), `tools/gm/__init__.py` (9 alone).
- **What chunks 10 to 14 read from W2**: 10, items 7, 8, 11 and 12 (the
  record, `restart.at`, the history unit and its due time, the outages,
  `fill/<node>.metrics.jsonl` from W1); 11, items 11 (the campaign's
  `wal-rate.yaml`) and 13 (f4's and f7's cover, f7's `TimeZone`
  untouched); 12, items 7 (`fake_timeline`, refused), 8, 9's findings,
  11 and 13's tells; 13, items 6 (setup step 2's order: format,
  register, overview, document), 7, 8 and 12 (the verbs, the story line,
  the record); 14, items 2 (paths, heading ids), 3, 4 and 5 (the form,
  the layout, the loader accepting a handout that differs only where a
  diff says).

**Choices made here, not in the spec** (for the driver's review): the
`brick-doc` configs built at fit; the status file's JSON form, its
`rendered` secret kind, name and path; `t0_instant`; the front's
locations and `disable_symlinks on`; GitHub-slug heading ids; the
`status-pages` service; the customer's name from `story.md`'s heading;
the true overview's keys (the diff's field names, the structured
coverage fields); the handout's layout; the loader's text pattern; the
scenario document's "Network overview" section and its lines beside each
fault; refused instances left out through `left_out`; `--aging`,
`--test-tail-floor`, `fake_timeline`; the story line's wording and the
always-rendered `story.md`; `MONITORING_BRICKS` and the stack rewrite;
`explains` filtered by the game; `hold` and `clean_restart` in
`state.yaml`; D525's means (`PGOPTIONS`, `load_epoch`, keywords outside
DDL, `pg_catalog.` in DDL); the hold at deploy; clean-restart's order;
`wal-rate.yaml`; the fake early check's due time, the history unit and
`HISTORY_AFTER`; outages from `restart.at`; extension members left
uncovered; the cover item's `routine` and `restore.database`; the fill's
outcome rule; the checked drop.

### Preflight corrections for spec-writer

1. **8.7's README is `player/README.md`, not the scenario document**
   (master-spec.md:823-838; the clinic's `player/README.md:11-74` holds
   "The system" table, the network paragraph and "The web interfaces";
   `.claude/skills/scenario-document/SKILL.md:3,8`: `README.md` is the
   scenario document; build-plan.md:900, :931). Chunk 7's Files gain
   `scenarios/{aldermoor-centre,fernway-clinics-monitoring,tarnbeck-outdoor-campaign,tarnbeck-outdoor-shop}/player/README.md`
   (the only four with a web-interfaces section); its Done when to read
   "the clinic's `player/README.md` has no node table". The scenario
   documents are still regenerated (item 6).
2. **Chunk 7's Files gain the clinic's register**,
   `scenarios/aldermoor-centre/{gm/data-register.yaml,player/data-register.md}`:
   mapping the seventh seed file changes `scenario.yaml`, a register
   input (`model.register_inputs`, tools/gm/model.py:6451; the clinic's
   `gm/data-register.yaml:6`), so the register is regenerated before the
   overview (W1 correction 3's case).
3. **Chunk 9's Files** gain `scenarios/tarnbeck-outdoor-shop/nodes/db/wal-rate.yaml`
   and `tools/tests/fixtures/fixture-fill/nodes/db/wal-rate.yaml` (new,
   item 11). **Chunk 15's scope** gains reading `state.yaml`'s `hold`
   (item 10), the outcome rule and the checked drop (item 13); its Files
   are unchanged. Chunk 9's 9a gains "`gmctl deploy` holding the
   real-clock actors off" (item 10; master-spec.md:923, "stay off").
4. **clean-restart's leftover restore was unreachable**: W1 item 7
   (clean-restart requires `fill.outcome: ok`) and `tools/gm/fill.py:991`
   (any end problem makes the fill `failed`) leave no game where 9.4's
   "`clean-restart` restores a cover still listed unrestored"
   (master-spec.md:972) applies. Item 13's outcome rule settles it;
   build-plan.md:995's "(a cover after a failed fill, chunk 15)" to read
   "an item the fill's end could not restore".
5. **`fill.quiet` restores ran in database `postgres` only**
   (`tools/gm/fill.py:940-943`, `psql_argv("postgres")`); a cover's
   `ALTER` must run in its own database: `restore.database` (item 13),
   for G10.1's `fill.quiet` form.
6. **Fix 11's means binds stored expressions** (master spec 9.9 fix 11:
   "`gm_vclock` for the functions they call"): with the shim on the
   session path during load-data's DDL, an unqualified `now()` in a
   default binds `gm_vclock.now()`, and today's `CASCADE` drop
   (`bricks/scheduler/program/gm_scheduler/fill.py:107`) would remove it
   (`scenarios/tarnbeck-outdoor-campaign/data/reporting.sql:396`). Item 9's
   DDL rule and item 13's checked drop settle it; 9.9 fix 11 to name the
   rule. Build-plan.md:977's "the time-of-day keywords in ... the inject
   scripts' SQL bound" holds for load-data's SQL only: inject scripts run
   unchanged (item 9).
7. **"Refused" read two ways**: access-model.md:117 ("A fake game holding
   a `real-only` or unassessed fault: refused by `gmctl render`") against
   6.9's `refused:` in a rendered game's record (master-spec.md:430) and
   12.2's "f10 refused" in a run (master-spec.md:1323). Item 7 takes the
   instance as refused and the game as running without it; access model
   7 to say so.
8. **For G10 after the wave's gate** (none contradicts the spec; formats.md
   v35 and master spec 6.9 don't carry them): the status file's form and
   secret, the `brick-doc` configs; the true overview's keys; the
   restart record as written with `state.yaml`'s `hold` and
   `clean_restart`; `timeline`'s fake keys; `wal-rate.yaml`; the cover
   item; `--test-tail-floor`.

### Questions for the owner (as drafted)

Two, already put after wave 1 (plan v4 entry); W2 is drafted on the
recommended answers and marks what depends on them.

1. **The cover finds its routines itself, or reads a declared list?**
   Recommended: auto-discovery (spec D523's default), given the clinic's
   ~25 pinned routines and chunk 8's omission. Item 13 depends on it.
2. **D525 reaches the T0 plantings, not only load-data?** Recommended:
   keep. Item 9 depends on it. The same question reaches the fill's
   pause plantings, which 9.4 step 5 runs unchanged on the real clock (a
   pause at virtual 02:00 planted at real 10:45 writes 10:45, before the
   anchor). Recommended: give them the same session means at the pause's
   virtual instant (`PGOPTIONS` in `fill.py`'s planting, chunk 15, the
   shim already there), a change to 9.4 step 5 for spec-writer. If not
   adopted, chunk 11 assesses such a fault `tail-only` with a tail
   planting.

### Owner answers, 2026-11-17

All three as recommended:
1. "Auto-discover (Recommended)": the cover finds its routines itself
   (D523 as written). Item 13 stands.
2. "Include plantings (Recommended)": D525 reaches the T0 plantings (as
   written). Item 9 stands.
3. "Virtual instant (Recommended)": the fill's pause plantings run with
   the same session means at the pause's virtual instant (`fill.py`,
   chunk 15); a change to master spec 9.4 step 5, for `spec-writer` to
   record.

### W2 reviewed by the driver, 2026-11-17

The capture's (choice) points are accepted as drafted. Corrections 1 to
8 and answer 3 go to `spec-writer` before chunks 7, 9 and 15 start; no
correction touches chunk 6, so it starts at once (G6 cleared). Chunk 7
starts once the plan revision is committed (its Files gain the
`player/README.md`s and the clinic's data register).

### Chunk 6 started; plan v5 (ae35c7a), 2026-11-17

- Chunk 6 (`bastion` 0.6.0) dispatched to a `coding-leader` at 578a87f,
  branch `v0.6-c6-bastion`.
- `spec-writer` applied W2's corrections 1 to 8 (none declined) and
  answer 3: build plan v5, ae35c7a. **D527**: the fill's pause plantings
  at the pause's virtual instant (master spec 9.4 step 5; chunk 15),
  answers 1 and 2 recorded as confirming D523 and D525. **D528**: an
  ineligible instance refused, not the game (access model 7).
  **D529**: inside DDL, `now()` and its kin written `pg_catalog.` (9.9
  fix 11). D526 listed under "Never issued". G10.2 added (W2's forms,
  after wave 2's gate). `doc-ids lint spec` and `doc-get lint plan`
  clean. Noted for chunk 15: an inject script whose DDL used an
  unqualified `now()` would bind the shim at a pause; the checked drop
  catches it; none does today.

### Chunk 7 — merged (4f96311), 2026-11-17

7a 50ee241 (the skill, the loader's checks and requirements, the
clinic's overview and register digest, the fixture domains' fragments),
7b 90c74b0 (the scenario document's section, the four
`player/README.md`, setup step 2, the clinic's `README.md`). Every Done
when item met: the clinic's overview, 21 entries and 9 third-party rows;
each crafted break refused in its own test (`TestNetworkOverview`,
`TestOverviewDiff`, `TestDomainOverview`); the clinic's README without a
node table; unit suite 1397 OK, 2 skipped; every scenario and fixture
loads. No Docker.

**W2-z (as built):** the true overview's top keys `generated_from`,
`header` (`customer`, `network`, `bastion`, `node_health`, `trust`),
`entries`, `third_parties`; an entry's keys `node`, `group`, `role`,
`access`, `activity`, `description`, `site` (when present), `system`,
`applications`, `sizing`, `databases`, `fed_and_used_by`, `uses`,
`users`, `third_parties` (`{partner, anchor, what}`), `tasks` (a crontab
task keyed by its comment), `backups`; a third-party row `{id, name,
hostname, anchor}`; inputs beyond 8.4: the customer nodes' data files,
their `brick.yaml`, the purposes' `ddl:` files, `player/story.md`.
**Your access** written `write (<paths>)`, `read-only[; write:
<overrides>]`, `none`. The handout: `# Network overview: <customer>` and
four header lines, one bullet per field ("none" when empty), plus a
**Name** bullet. Error texts as W2 item 5, except the connection's,
which names the target node; texts W2 didn't name are added (a node in
two entries, the standby or a base-backup line under no backups, a
database under no databases, a partner in no row, the access against
the write policy, the bastion's mapping, a missing handout or true
overview, a domain's missing `overview:`, the field shapes, the full
`overview_diff` set). The coverage reads the system as designed (a
selected fault's seed lines left out). The clinic's overview was
generated by a throwaway script following the skill (no `gmctl`
generator, as for the register).

Outside its Files: `tools/tests/test_compose.py` and two tests in
`test_model.py` given fx-part's job fragment. **For the gate:** every
`README.md` beyond the clinic checked against a full regeneration (the
owner applied the template's delta and judged only the clinic
affected); the domain template's `overview:` still optional; the
scenario document renders none of chunk 3's v0.6 keys (`admitted:`, fake
aging), which W2 item 6 didn't name (chunk 12's "Fake aging" section;
`admitted:` to check with `spec-writer` at G10.2). Its note that the
clinic pins postgres 0.5.1 is not a gap: 0.5.1 is postgres's v0.6
version (D100). **For chunk 9:** an edit to any overview input of the
clinic (its `scenario.yaml`, a node's seed, a `brick.yaml`, `partners.md`,
`story.md`, the register, the answer key) regenerates the overview in
the same commit.

Figures: 1 agent, 113 tool calls, 22.9M tokens in / 121k out, max
context 321k, $8.45 at API prices. **Over 300k context** (321k), and
past the ~100-call rotation point by 13 calls; it finished and merged
at that point rather than stopping at a WIP commit.

### Chunk 6 — merged (153fc24), 2026-11-17

6a 147782e (the front, the documentation site, the reports, the tools),
6b 0566c62 (the status pages, render's status file, `fixture-status`);
merged after chunk 7 without conflict. Every Done when item met: the
bastion's stack test 136/0; `fixture-status`'s run 27/0 in 381 s with
the deployment; two routes and three documents listed, the four others
404, no dead link (`/other/` 502 by design); pages from the starter pack
as handed over; 401 without the password, `/status/` included; no page
for a third party's brick; `jq` 1.7.1 reading a Prometheus-format API
through `curl` as `player`, `tmux` 3.5a; a pgBadger report listed and
served with the sandbox header, symlinks, `..` and POST 404; the status
pages (f1 only, then f2 once started, "Operational" for the other
partner; the file root 0400, unreadable by `player`; no `proxy_pass` in
the front). Footprint (Docker 29.9.3, 2026-11-17): container 5.5 MiB
with routes, 5.0 without; nginx 13.2 MiB resident with routes, 12.3
without; image 199 MB (from 195 MB, `jq`/`tmux` and their libraries
3.6 MiB); `brick.yaml`'s figures unchanged. Unit suite on its branch
1381 OK, 2 skipped; 494 related tests on the merged tree.

**W2-w (as built):**
- Brick pages: config kind `brick-doc`, name
  `<game_id>_<bastion node>_doc-<brick-id>`, the brick's
  `docs/player.md` at `/opt/gm/docs/bricks/<id>.md` (0:0, 0444), one per
  brick of a node outside `third_party_nodes`, in topology order, built
  at fit (`localimpl.brick_doc_configs`, `documented_bricks`); counted
  in `_derived_lengths` (game ids shorter where brick ids are long);
  render refuses "the brick pages changed since gmctl fit: fit again".
- Status secret: kind `rendered`, name `partners_status` (Swarm
  `<gid>_partners_status`), file `local/<pg>/secrets/partners_status.json`
  (0600 in 0700), at `/opt/gm/secrets/partners_status.json` (root
  0400); declared on the bastion when a third party has a `player_doc`;
  written in `write_rendered`, so a restart rewrites it; skipped by
  `generate_credentials`. `render.t0_instant(timeline, rendered_at=None)`:
  `virtual_t0`, else the timeline's `rendered_at`, else the argument.
- The front: W2 item 2's locations plus `location = /reports` 301;
  `/reports/` with `limit_except GET`, `mime.types`, `error_page 403
  404 =404`; `/status/<id>` 301 to the slash; the entrypoint refuses a
  route named `docs`, `reports` or `status`.
- Renderers: `/usr/local/lib/gm/pages.sh`; `/usr/local/lib/gm/html-ids`
  (perl: GitHub-style ids, `<file>.md#x` links to `/docs/<id>#x`, a
  "Status page" link under each partner); `/usr/local/lib/gm/render-status`
  (jq). s6 longrun `status-pages`: render, sleep 60 s; `s6-svc -O`
  without the file; left out of `brick.yaml`'s `processes`.
- The home 0751; `~/reports/` `player` 0755, recreated if missing, a
  link or a file. The customer's name from `story.md`'s first `# `.
- Choices W2 left open: render refuses a `handover-<N>h` moment in a
  game rendered without `--handover`; tools listed alphabetically;
  `html-ids` on bytes (perl-base has no Unicode tables), so a
  non-ASCII heading may differ from GitHub's id (every anchor today is
  ASCII).

Outside its Files: `test_fit.py`, `test_teardown.py`, `test_inject.py`
(config counts, the game-id bound). `fixture-status`'s `README.md` is a
hand-written stub. **For chunk 9:** `state.secret_files` labels the
`rendered` secret "password" and names it `partners_status` without
`.json` (`gmctl status`'s display only; `state.py` is chunk 9's).
**Risk:** a game deployed before this merge needs its bastion restarted
for the pages. **Next:** G7.

Figures: 1 agent, 139 tool calls, 30.1M tokens in / 132k out, max
context 324k, $10.21 at API prices. **Over 300k context** (324k), and
39 calls past the ~100-call rotation point; it finished and merged
instead of stopping at a WIP commit.

### Chunk 15 — merged (1aacf9e), 2026-11-17

252d319 (it took `v0.6-w2` in first, b550268, after chunk 6's merge; no
conflict). Every Done when item met: `TestP0` (PostgreSQL 17.12) with
f7's shape (`pg_catalog, pg_temp`, `TimeZone=Etc/GMT-2`) and a `public,
pg_temp` function, virtual under the cover and real without
`gm.vclock`, `TimeZone` kept, each `proconfig` restored exactly (also
`"$user", public` and the empty path), a `gm_*` routine and one without
its own path untouched; `TestFillSql` (`fill-sql --cover`/`--drop`
print the program's SQL); `TestCover` (10 tests: listed before its
`ALTER`, restored in its own database at the end, on `FAILED` and on a
`gmctl fill` failure, a replaced routine covered again, no item without
a pinned routine, a failed end restore leaving `ok` with the problem in
`fill.reason`, held actors left out, f8's pause scripts given
`PGOPTIONS` at the pause's instant); `fill-sql --drop` refusing with a
`DEFAULT gm_vclock.now()` column and naming it; the replay guard green.
Scheduler unit runner 112 OK; `scheduler:0.4.0` rebuilt (sha256:9b3c3c6d…);
host tests 217 OK on the merged tree.

**W2-y (as built):**
- Discovery (`COVER_SQL`, `fill-sql --cover`): `SET search_path =
  pg_catalog;` then a `SELECT` of `prokind` `f`/`p` with a
  `search_path=` entry, excluding `pg_catalog`, `information_schema`,
  `pg_toast`, `pg_temp_%`, `pg_toast_temp_%`, every `gm\_%` schema and
  extension members (`pg_depend` `deptype='e'`); one JSON line per
  routine `{kind, signature, setting, covered, cover, restore}`,
  `signature` as `oid::regprocedure::text`; `pg_catalog` added after
  `gm_vclock` only when no element names it; `""` written back as `''`.
- The `fill.quiet` item: `what` "P0's cover: search_path of <kind>
  <signature> in <db> (spec D523)", `how` the `ALTER`, `routine:
  {database, kind, signature, original}`, `restore: {user: postgres,
  database, sql: [one statement]}`; keyed by node, database, signature.
- **`restore.sql` differs in form from W2's example**: a guarded `DO
  $gm_cover$` block that restores only while the cover is in place, so
  a routine gone or redefined without its path counts as restored and a
  rerun is safe (clean-restart included).
- A routine already under a cover no item lists fails the fill
  ("…under a cover no fill.quiet item lists").
- `undo`: covers restored first, then the other items, each in
  `restore.get("database") or "postgres"`, then the checked drop.
- Checked drop (`VCLOCK_DROP`): a `DO $gm_drop$` block listing each
  `pg_depend` row (`n`/`a`) on a `gm_vclock` function from outside the
  schema (`pg_describe_object`), then `DROP SCHEMA IF EXISTS gm_vclock
  CASCADE`. Refusal: "gm_vclock not dropped: <objects; …> depend(s) on
  its functions (bound to the fill's clock: define them again with
  pg_catalog.now() or its kin, then drop it)".
- `fill.reason` on `ok`: `"; "`-joined, `"<node>: <what> not restored
  (<line>)"`, `"<pg>/<db>: gm_vclock not dropped (<line>)"`.
- **The hold read, for chunk 9:** `state.yaml`'s `hold.items[]` matched
  on `(node, what)`, with `what` exactly `fill.PG_CRON_WHAT` ("pg_cron's
  job runs"), `fill.ARCHIVING_WHAT` ("archiving"), `fill.CRON_WHAT`
  ("the cron daemon"); helpers `settings_plan(..., held=)`,
  `fill.held_whats(st, node)`.
- **Session means, for chunk 9:** `fill.session_means(env, at)` and
  `fill.VCLOCK_PATH` (`gm_vclock,pg_catalog,"$user",public`) give W2
  item 9's `PGOPTIONS`, appended to any already set.

Risks: OUT-parameter procedures and extension members not tested.
**For the gate:** `fixture-fill`'s short test (the shop gets no cover
item).

Figures: 1 agent, 63 tool calls, 8.6M tokens in / 78k out, max context
208k, $4.20 at API prices.

### Owner answer for G7, 2026-11-17

"CPE + 17 ignores": `jq` goes into `.tech` with
`cpe:2.3:a:jqlang:jq`, and the 17 backported CVEs get `[[ignore]]`
entries ("fixed by Debian backport in 1.7.1-6+deb13u4 or earlier",
review 2027-02-01 or the next trixie jq upload).

### G7 — dependency post-change check: CLEAR, 2026-11-17

`security-advisor`, 2f242e5 (`.tech` only). dpkg-query 2026-11-17:
`bastion` 0.6.0 (b8ae4d82a6cd, Debian 13.7, 163 packages) has `jq`/`libjq1`
1.7.1-6+deb13u4, `libonig5` 6.9.9-1+b1, `tmux` 3.5a-3,
`libevent-core-2.1-7t64` 2.1.13-stable-1~deb13u1, `libjemalloc2` 5.3.0-3,
no `libutempter0`; against 0.5.0, those six plus PGDG `libpq5` and
`postgresql-client-18` 18.6 → 18.7-1.pgdg13+2 (the tag now names a new
package list; v0.6 unreleased, so folded into 0.6.0). `grafana` 0.4.0
and `postgres-exporter` 0.2.1 already carry jq deb13u4: no rebuild for
jq. `.tech`: `[stack]` `tools` and `bastion_tools` keys; `[[platform]]`
jq (`cpe:2.3:a:jqlang:jq`, 1.7.1) and tmux
(`cpe:2.3:a:tmux_project:tmux`, 3.5a); **17 jq `[[ignore]]` entries**
(the owner's "CPE + 17 ignores"), each re-checked on the Debian tracker
as fixed at or below deb13u4, `approved_by = "bastien"`, until
2027-02-01 or the next trixie jq upload; PostgreSQL 18's entry records
the bastion's client at 18.7. `cve-watch lint` exit 0 (ten old
no-CPE warnings); `cve-watch check` 75 findings before and after (none
from this change), accepted 94 → 111.

Expected later: CVE-2026-39956 and CVE-2026-40164 (jq, fixed in
deb13u2, not yet matched by NVD) will surface in a sweep and need
their own approved ignores.

**PostgreSQL's 2026-11-12 security release** (about 50 CVEs on 18.x,
several CVSS 8.8, fixed in 18.7; NVD not yet analysed, so the sweep
won't raise them): `postgres` 0.5.1's server and `pgbouncer` 0.1.2's
client are at 18.6; `scheduler`, `api` and `health-check` have Debian
libpq 17.11 (trixie-security has 17.12). No Dockerfile pins those
versions, and every one of these bricks is at its unreleased v0.6
version, so the plan's gate rule applies: rebuilt, the change folds
into the unreleased version with a post-change check. The cached apt
layer would keep 18.6, so the driver added **G9.1**: the five built
with `--no-cache` at wave 2's gate, then `security-advisor`.

### Chunk 9a — WIP (2af490b), stopped on a blocker, 2026-11-17

The driver split chunk 9 to force the rotation: a 9a owner (no merge),
then a fresh 9b owner. 9a's owner stopped at ~100 calls with WIP commit
2af490b on `v0.6-c9-restart` (worktree kept). 9a's unit Done when items
pass (`TestFakeTimeline`, `test_the_floor_and_its_cap`,
`test_ineligible_instances_refused_with_their_reason`, `TestRenderFake`,
`TestFakeEarlyCheck`; render, deploy, aging, state, inject, fill,
restart, fit, teardown tests OK). Chunk 6's `state.secret_files` bug
fixed. Left for 9b's fixture run: the hold with no `pg_cron` run before
the fill; no value after the virtual T0 (check written,
`inject.after_virtual_t0_sql(vt0)`).

**Blocked, routed to `spec-writer`:**
1. **The session path's order** (W2 item 9, master spec 9.9 fix 11,
   `fill.VCLOCK_PATH`): `gm_vclock` first makes it the creation schema,
   so an unqualified `CREATE TABLE` in load-data (or in an inject at T0
   or at a pause) fails for a non-owner ("permission denied for schema
   gm_vclock") or lands in `gm_vclock` for `postgres`, to be dropped
   with it. Shown on a scratch PostgreSQL 17 with
   `fixture-fill/data/db.sql`. Proposed: `"$user",public,gm_vclock,pg_catalog`
   (unqualified `now()` still reaches the shim before `pg_catalog`);
   the same scratch load then ran whole, the latest `orders.placed_at`
   exactly the virtual T0, nothing after it, the checked drop clean.
   Not applied: the code still uses `fill.VCLOCK_PATH`.
2. **The shop's tail**: 9.6's rules on 9.8's estimates give 2 h, anchor
   12:00 (f4 `tail_minimum` 2h; f5, f7 `covers 12:00`); 9.8,
   `fake-aging.md` and the Done when say 3 h, 11:00. 9a built 9.6 as
   written (its test asserts 2h/12:00; a 3h `tail_minimum` gives 11:00).
3. **f8 (`pg-join-index-missing`) in `fixture-fill` has no `aging.fake`**,
   so a fake render refuses it and 9b's fixture run can't plant it;
   faults' assessments are chunk 11's (wave 3).

**W2-x so far** (9a's report, kept here for 9b and chunks 10 to 13):
`render.fake_timeline(scenario, planned, floor=None, left_out=())` →
`{virtual_t0, anchor, tail, refused: [{instance, reason}]}`; `--aging
real|fake`, hidden `--test-tail-floor` (1m to 1h, recorded in
`test_harness_override.tail_floor`); a fake render refused without a
scheduler node or with the anchor past; `timeline` gains `virtual_t0`,
`anchor`, `tail`, `refused`; `localimpl.left_out(impl)`; the record
`{mode: fake, virtual_t0, anchor, tail, handover_planned, refused}`
(`localimpl.write_restart_record`/`remove_restart_record`); `story.md`
always a rendered bastion seed file in scheduler scenarios (games fitted
before need `fit` again), the line "The servers were restarted for
maintenance on <date> at <HH:MM> UTC; older logs were archived.";
`MONITORING_BRICKS`, `monitoring_held`, `build_stack(..., held)` at
`replicas: 0`, `write_rendered(..., record=None)` restoring 1 once the
record has `restart`; the hold (`deploy.hold_actors`) on primaries after
the health wait, items in `fill.quiet`'s form with chunk 15's `what`
strings, `left_off: true`, `state.yaml` `hold: {at, items}`; the clock
(`inject.clock_plan`/`set_clock`/`drop_clock`, shim in every connectable
database and `template1`, `virtual_sql` rewriting keywords outside DDL
and qualifying `now()` and its kin in `CREATE`/`ALTER`, the shim dropped
after `composed_steps`); T0 plantings' `planted_at` the virtual T0;
start-load (fake) requiring `clean_restart.outcome: ok` and `restart.at`,
T0 the virtual T0, `load.anchor` = `restart.at`; `aging.HISTORY_ACTION`
"history" (unit `dbagm-<gid>_history`), `HISTORY_AFTER` 12 min,
`SHORT_TAIL` 2h, `fake_early_check_due`; outages from `load.anchor`;
`state.aging_mode_lines` in status. For 9b: clean-restart writes
`restart.at` and `clean_restart.outcome: ok`; the hold's restore is in
`hold.items[].restore`. Risks: `gmctl restart` of a fake game rebuilds
the timeline without the fake keys (chunk 11's area); the cron daemon
back if a container restarts before clean-restart; data files running
`SET search_path` (the clinic's domains, the campaign's
`reporting.sql`, `shop-sales-reporting`) leave the clock, reported as
findings; standbys outside the hold and the shim.

### Plan v6 (c87f332): chunk 9 unblocked, 2026-11-17

`spec-writer` settled the three points itself (none changes how a game
plays against the approved spec; nothing for the owner):
- **D530**: `gm_vclock` placed right before `pg_catalog` on every path
  P0 sets (both at the end, before a final `pg_temp`, when the path
  doesn't name `pg_catalog`). The cover had the same flaw, with data
  loss: the clinic's `vet-machinery` routines (`public, pg_temp`)
  `EXECUTE 'CREATE TABLE … PARTITION OF …'`, which under today's cover
  lands in `gm_vclock` and goes with its CASCADE. The checked drop also
  refuses any object inside `gm_vclock` other than its four functions.
  The cost (a same-named, same-signature function in `public` or
  `"$user"` would win; none in any scenario) is in master spec 9.4.
- **D532**: 9.6 corrected, not 9.8: a `tail_covers` instant counts from
  one floor before it (the research's run sheet chose 3 h so f5's 12:00
  run is not the restart's own minute). The shop: 3 h, anchor 11:00.
- **D533**: `fixture-fill`'s f8 becomes a fixture-local
  `fixture-dropped-index` (copied from `fixture-v06-refusals`, its own
  `aging.fake: supported` and `history:`), so 9b's fake run still plants
  it at its pause; the catalogue's `pg-join-index-missing` stays
  unassessed until chunk 11.
- D531 never issued (cited before reserving; renumbered).

W2 item 14's "9 does not change `bricks/scheduler/program/`" is
superseded: 9b changes it (chunk 15 merged). Chunk 15's section, as
built, still says "`gm_vclock` first on the path"; chunk 9's text
carries the change.

### Chunk 9b — WIP (4fe88e9), rotated at ~97 calls, 2026-11-17

On `v0.6-c9-restart` over 9a's 2af490b: a6b5abc (v0.6-w2 taken in),
8474542 (WIP: D530's program and host changes, D532's lead, D533's
`fixture-dropped-index`, the two `wal-rate.yaml`), 4fe88e9 (WIP:
`gmctl clean-restart`, 11 unit tests, the verb, `gmctl.md`'s row). Met
by unit tests: the shop's 3 h / 11:00 and a capped floor with a covered
instant; `TestP0`'s cover forms by 9.4's rule and an unqualified
`CREATE TABLE` landing in `public`; `fill-sql --drop` refusing a table
inside `gm_vclock`; clean-restart refusing a node without
`wal-rate.yaml`; a synthetic cover item restored. Scheduler unit runner
113 OK, replay guard green; `scheduler:0.4.0` rebuilt (sha256:bfa1d9fb…).
Full tools suite 1454 with one failure (`TestNoLoadControl.test_verbs`,
the new verb), fixed in 4fe88e9, not rerun whole. Left: the fixture run
(every deployment item of the Done when) and the merge.

**W2-x additions, accepted by the driver:**
- `wal-rate.yaml`: `bytes_per_hour: 43881262` for the shop, from the
  reference's `m1-fa-real-20261115T0800/shared_stats.csv`
  (`pg_stat_wal.wal_bytes` 1055344352 over 86580 s); it includes the
  seed load, so it overstates the steady rate (chunk 11 measures the
  campaign's; worth a remeasure then). `fixture-fill`'s is the shop's.
- clean-restart's order: the fill's unrestored items (covers first, in
  `restore.database`) and a leftover `gm_vclock` dropped; WAL padded
  with `pg_logical_emit_message` in 1 MiB to 24 × `bytes_per_hour`,
  `CHECKPOINT; pg_switch_wal()` twice, `{padded_bytes, pg_wal_bytes,
  seconds}` in `clean_restart.wal`; `pg_stat_statements_reset()` and
  `pg_stat_reset_shared(NULL)`; the hold's and the fill's left-off
  `ALTER SYSTEM` restores sent **before** the stop (they need a running
  server; they take effect at the start), the cron daemon's script not
  run (the fresh container brings cron back); PostgreSQL stopped fast,
  every service scaled to 0; helper containers clear `pglog`, empty
  `pgblog`, set data files' mtimes (not `pg_wal`, `postmaster.*`); the
  record's `restart: {at, story_line, explains}`, the stack rewritten
  `held=False`; one `docker service scale -d …=1`, `restart.at` the
  issue instant to the second.
- `explains`: 9.10's rows `{observation, where, in_world}`, the archive
  row only with an archiving item, the cover row only with a cover.
- **Last virtual write** (a choice; the capture gave no means): before
  the fill, the virtual T0 minus the gap to the fill's start; during
  it, the fill's real span mapped linearly onto virtual T0 → anchor;
  after it, the anchor.
- Risks: `restart.at` is the scale's issue instant, not a measured
  start; several hosts untested (`restart.volume_name`); the padding's
  time not yet measured.

Figures so far (chunk 9, three agents: 9a, 9b, and the earlier
blockers' run is spec-writer's, not counted here): 250 tool calls,
34.1M tokens in / 218k out, max context 245k, $14.09 at API prices.
A fresh owner resumes for the fixture run.

### Chunk 9 — merged (3b9b1b7), 2026-11-17

The third owner (fixture run, 74 calls) committed 8cfcc87 and merged.
9a = 2af490b; 9b = 8474542, 4fe88e9, 8cfcc87 (the driver's rotation
points). Full tools suite 1456 OK, 2 skipped; `test_cleanrestart` and
`test_deploy` 92 OK on `v0.6-w2`. Scheduler program unchanged since
8474542 (113 OK, replay guard green then).

**`fixture-fill`'s fake run** (`run-short-test.sh` rewritten: render
`--aging fake --test-tail-floor`, deploy, load-data and inject on the
virtual T0's clock, fill, clean-restart at the anchor after a refused
early call, start-load, teardown), run 4: **65/0, 840 s** with the
deployment (runs 2, 3: 850 s, 878 s, failing on the bugs below). Every
deployment item of the Done when met: nothing refused; monitoring `0/0`
at deploy; the hold recorded (`db: pg_cron's job runs`) and
`cron.job_run_details` 0 before and after the fill; `gm_vclock` gone
from every database after each drop; nothing after the virtual T0
after load-data and inject, nothing after the anchor after the fill;
f8 planted by the fill at virtual 14:00Z, the index gone; no fill
statement in `pg_stat_statements`; every container (7 services, the
monitoring's included) and the postmaster started 0.7 to 1.7 s after
`restart.at`; one `stats_reset` instant; no log line from before the
restart; the hold restored, `cron.launch_active_jobs` on; both
scheduler logs keep the fill's lines byte for byte, no `reload
status=ok`; `load.t0` the virtual T0, `load.anchor` `restart.at`; the
record complete but `history`; nothing left after teardown.

Figures (armenelos, 2026-11-17, run 4): deploy 15 s, load-data 16 s;
fill 449 s for 904 virtual minutes; clean-restart 26 s, its padding
1,085,863,544 bytes in 1.6 s (2.4 s, 2.2 s in runs 2, 3); `pg_wal`
1,073,741,824 bytes after the checkpoints, 63 segments after the start;
`restart.at` 14 s after the planned anchor; `stats_reset` 9 s before
`restart.at`; 244 s waiting for the anchor; the exporter's sessions
3626 against 3616 expected.

**Fixed in the chunk** (found by the run): deploy's hold called
`exec_node` while the stage was still `rendered` (unit tests had
mocked it), now `exec_node(..., impl=)` inside deploy's setup step,
with a test; `stats_reset` split over two seconds, now the resets end
in one session (every database but `postgres`, then `postgres`'s
statement reset and the shared reset together), with a test.

**Added**: clean-restart refused before the planned anchor (the fill's
rows run up to it; the owner's reading of W2 item 8), unit-tested,
`gmctl.md` updated. In a fake game `pg_cron`'s launches are the hold's
item, not `fill.quiet`'s. `explains` = `cleanrestart.EXPLAINS`' 11
rows; `wal-rate.yaml` = `source:` + `bytes_per_hour`.

**Reviewed by the driver:** both choices accepted, for G10.2 to write
down: (1) the refusal before the anchor (a GM plans the anchor at the
fill's end; the wait, 3 to 4 min here, is the fill's own slack); (2)
`stats_reset` before `restart.at` by seconds (the reset before the
stop, as captured; with statistics surviving a clean shutdown, a reset
just before a maintenance restart reads as the maintenance itself).
Spec 9.4's "reset there" is read as part of the restart's procedure,
not after the postmaster's start; `spec-writer` to confirm at G10.2.

**For the gate**: the cron daemon's hold and archiving aren't exercised
by the fixture; data files' mtimes only unit-tested (1325 dated).

Figures (chunk 9, `agent-stats`, 4 agents: 9a, 9b, the fixture run, and
the blockers' `spec-writer`): 324 tool calls, 43.2M tokens in / 275k
out, max context 245k, $19.82 at API prices. No owner over 300k; each
stopped at its rotation point or finished before it.

### Wave 2's chunks all merged, 2026-11-17

6 (153fc24), 7 (4f96311), 15 (1aacf9e), 9 (3b9b1b7). Next: the wave
gate (G9.1 included), then G10.2 by `spec-writer`.

### Wave 2 gate — 2026-11-17, green after four fixes

`coding-executor` at the wave-gate level, armenelos, 20:13–23:05 CET,
from 992c085; every docker step serialised under the lock and the
inhibitor, each item under 30 minutes. Head after the gate: 15749dd.

| Item | Result |
|---|---|
| Unit suite | 1456 OK, 2 skipped, 382 s |
| Scheduler unit tests, replay guard | 113 OK (6 `TestP0`), the real mode's replay byte for byte |
| api unit tests | 36 OK |
| `sh -n`, `py_compile`, `perl -c` | 342 shell, 474 Python, 14 Perl files OK |
| Ten bricks' stack tests | postgres 316, bastion 136, pgbouncer 121, scheduler 179, api 89, prometheus 132, postgres-exporter 104, grafana 131, pgwatch 73, health-check 97; all 0 failed |
| `check-base.sh` | 10/10 Debian 13 |
| Smokes | smoke 61, monitoring 43, governance 121, load 73 |
| Scenario smokes | bookshop 19, fernway-clinics 18, tarnbeck shop 26 (828 s), tarnbeck campaign 33 (303 s) |
| `fixture-status` | 27/0, twice |
| `fixture-fill` | 65/0, 886 s; 65/0, 842 s on the final images |
| Overview tests, `check_scenario`, `check_domain_dir` | 31 OK; 5/5 scenarios, 32/32 fixtures; 0 problems |
| Clinic's data register | regenerated on a copy: identical to the committed files |
| READMEs | aldermoor's v0.6 parts correct; fixture-status's generated |

**Fixes** (each its own commit on `v0.6-w2`): f6e14ab, the domain
template's `overview:` required (chunk 7); 6fff117, fixture-status's
README generated from the template, replacing chunk 6b's stub (no
`admitted:` section: the template has none, G10.2); d77808a, `smoke.sh`
counts 17 labelled configs and secrets, bastion 0.6.0's two brick pages
(chunk 6); 15749dd, smoke-load judges from the first whole minute after
the last scheduler's start, not T0 (from before v0.6; the producer
started 2 s after T0's minute began). ISS-006 didn't show.

**G9.1's builds** (`--no-cache --pull`; dpkg lists diffed):
- postgres: libpq5, postgresql-18, postgresql-client-18 18.6 → 18.7-1.pgdg13+2;
  the pinned `pg_cron` 1.6.8-1.pgdg13+2 and `pgaudit` 18.0-3.pgdg13+1
  still install (PGDG has newer builds needing > 18.7).
- pgbouncer: libpq5, postgresql-client-18 → 18.7; **libcares2
  1.34.5-1+deb13u1 → 1.34.9-1~deb13u1** (the c-ares item open in
  `.tech`); postgresql-common family 293 → 295.pgdg13+1.
- scheduler, api: libpq5 17.11 → 17.12-0+deb13u1; health-check: libpq5
  and postgresql-client-17 → 17.12. Nothing else.
- The other five: same image ids, no change.

**Found: the api and scheduler stack tests undo G9.1.** They rebuild
their image with a cached `docker build` (`run-stack-test.sh` lines 126
and 150), which BuildKit answers with the old apt layer: both went back
to libpq 17.11. The other eight stack tests take a prebuilt image. The
executor rebuilt both `--no-cache --pull` and reran their stack tests
through a shim skipping that line (89/0, 179/0), then reran
fixture-status, smoke-load and fixture-fill on the final images; the
other smoke and scenario rows ran with libpq 17.11 in scheduler and api.
Sent to a `coding-executor`: those two tests take the prebuilt image like
the other eight. Wider point for the owner: any cached build of a brick
keeps its old apt layer, so security updates arrive only with
`--no-cache`.

**Left for the owner**: older fixture READMEs predate the current
template (11 without "Third parties", 12 without "Composition"); v0.5's
gate ruled this not a gate item, and nothing in wave 2 made one stale.

**Figures**: fill 526 s for 916 virtual minutes on 2 scheduler nodes
(495 s for 904 in the final run); exporter sessions 3674 against 3664
expected; autovacuum during the fill 99 runs on `products`, 1 on
`customers`; clean-restart 27 s, WAL padding about 1.08 GB in 2–3 s,
`pg_wal` 1,056,964,608 bytes after the checkpoints; starts +0.9 to +2.3 s
from `restart.at`; `stats_reset` 8 s before it. `/home` 14 GB free.
Removed: the superseded `api:0.1.0` tag. Nothing left running.

### G9.1's post-change check — 2026-11-17, CLEAR with one follow-up

`security-advisor`, 3768038 (`.tech` only). The rebuilt images match
the gate's dpkg diffs. Clean: postgres 18.7 (the 2026-11-12 batch, 52
CVEs on 18), libpq 17.12 in scheduler, api, health-check (DSA-6625-1,
47 on 17), pgbouncer 1.26.1, c-ares 1.34.9-1~deb13u1 (DSA-6626-1):
**the c-ares item in `.tech` closed**, its `[[ignore]]` removed.
`cve-watch check` 75 findings before and after, none new (all already
in `SECURITY_TODO.md`).

Follow-up for the owner: the pinned `pg_cron` 1.6.8-1.pgdg13+2 and
`pgaudit` 18.0-3.pgdg13+1 were built before 18.7 and lack the extension
half of CVE-2026-6460 (18.7's notes: C extensions need rebuilding).
PGDG's +3/+2 are the same sources rebuilt and do install on 18.7 (the
gate's note that they need "above 18.7" was wrong). Not reachable here
(only the superuser and the game's service roles connect). Proposed:
re-pin in `bricks/postgres/Dockerfile` now, postgres 0.5.1 being
unreleased, `--no-cache` rebuild and its stack test. Also: pgAudit 18.1
(upstream 2026-11-17, not yet in PGDG) changes which audit lines are
logged, so it is a game-content decision for later.

### G10.2 and G10.1 done — 2026-11-17

`spec-writer`, b2578a0 (formats.md v36, master spec, plan v7, D534–D537)
and 53168e9 (gates). Every form checked against the code; none
contradicts the spec. G10.1 done alongside (shared paragraphs; the
fill's interface pointed to the scheduler's `docs/gm.md`): accepted by
the driver.

- Chunk 9's two choices confirmed: D535 (clean-restart refused before
  the anchor; the earliest hand-over is `restart.at` plus the tail, no
  upper bound), D536 (`stats_reset` seconds before the postmaster's
  start).
- `admitted:` in the scenario document: no chunk had it; chunk 12
  revised (D537) to render it and regenerate fixture-status's and
  fixture-v06-refusals' READMEs.
- Chunk 11 revised: 11b measures the campaign's `wal-rate.yaml` for
  `db` and `reporting` (W2 item 11 had no chunk; chunk 12's short game
  needs it).
- Found: the overview's Node health link differs from master spec 8.6
  (built `/grafana/d/node-health?var-node=<node>`, default 1h; spec
  `/grafana/d/node-health/node-health?var-node=<name>&from=now-6h&to=now`).
  The driver's call: the code follows the spec; sent to a
  `coding-executor` as a wave 2 fix (chunk 7's), clinic's overview
  regenerated.
- Notes for wave 3: `restart.at` is the instant the start is issued
  (containers 0.7–2.3 s later), for chunk 10's rebase; the shop's
  `bytes_per_hour` includes the seed load (a remeasure can ride on 11b);
  the 6.9 example's `history` key is chunk 10's.

### Gate fixes after the gate — 2026-11-17

- 504fa50 (chunk 7's): the overview's Node health links in master spec
  8.6's form, `/grafana/d/node-health/node-health?var-node=<name>&from=now-6h&to=now`;
  header lines the same without a node (bastion's with `var-node=bastion`).
  Skill, template and aldermoor's overview regenerated (23 lines each,
  85 input digests unchanged); overview tests 31 OK, `check_scenario`
  5/5 and 32/32, `check_domain_dir` 0. The dashboard has no `node`
  variable yet (chunk 5, wave 4): until then each link shows every node
  over 6 h.
- 9860cb1: the api and scheduler stack tests take the prebuilt image
  (exit 2 if missing), as the other eight do; scheduler's test-only
  `unit-test` stage build kept (separate tag). Reruns: api 89/0,
  scheduler 179/0, both image ids and libpq5 17.12-0+deb13u1 unchanged.
  api's `docs/gm.md` stack-test line corrected to postgres 0.5.1 by the
  driver.

### Wave 2 report — 2026-11-17

Chunks merged: 6, 7, 15, 9; none moved. Gate green (above), G7, G9.1's
builds and post-change check, G10.1, G10.2 done. `doc-ids compare main
v0.6-w2`: 0 collisions. Head f83805b.

Over 300k context: chunk 6's and chunk 7's owners (324k, 321k), both
single owners past 100 calls before rotation was enforced in the
briefs; chunk 9 split across owners with a hard stop stayed at 245k.

Waiting on the owner: the merge into `main`; the pg_cron +3 / pgaudit +2
re-pin (security-advisor recommends it now, postgres 0.5.1 unreleased:
`--no-cache` rebuild and its stack test); the older fixture READMEs;
pgAudit 18.1 later (game content). For wave 3 (chunks 10, 11, 13; fresh
session): plan v7 (chunks 11 and 12 revised, D537); notes in "G10.2 and
G10.1 done" above; worktree `v0.6-spec` still exists (owner's call).

#### v0.6 wave 2

- Time: 2026-11-17 09:43 → 2026-11-17 23:27 (13h43)
- Agents: 17 · tool calls: 1,304 · model turns: 1,273
- Tokens in: 196.0M (fresh 3k, cache write 3.7M, cache read 192.3M) · out: 1.1M
- Max context: 324k (coding-leader: Chunk 6 bastion 0.6.0 owner)
- Cost: $79.73 at API list prices (checked 2026-11-12)
- Ends: at its last tagged agent (not merged yet)

#### By role
| role | agents | calls | tokens in | out | cost | share | max ctx |
|---|---:|---:|---:|---:|---:|---:|---:|
| coding-leader | 7 | 658 | 110.5M | 656k | $45.38 | 57% | 324k |
| coding-executor | 3 | 315 | 48.5M | 134k | $14.37 | 18% | 292k |
| spec-writer | 3 | 178 | 21.3M | 129k | $9.22 | 12% | 232k |
| driver (top level) | 1 | 49 | 9.1M | 89k | $6.89 | 9% | 238k |
| security-advisor | 3 | 104 | 6.6M | 62k | $3.87 | 5% | 132k |

#### By chunk
| chunk | agents | calls | tokens in | out | cost | share | max ctx |
|---|---:|---:|---:|---:|---:|---:|---:|
| 6 | 1 | 139 | 30.1M | 132k | $10.21 | 13% | 324k |
| 7 | 1 | 113 | 22.9M | 121k | $8.45 | 11% | 321k |
| 9 | 4 | 324 | 43.2M | 275k | $19.82 | 25% | 245k |
| 15 | 1 | 63 | 8.6M | 78k | $4.20 | 5% | 208k |
| outside chunks |  |  |  |  | $37.05 | 46% |  |

#### By activity (tool calls)
| activity | calls | share | writes | results |
|---|---:|---:|---:|---:|
| dispatch | 14 | 1% |  | 15k |
| doc-get | 28 | 2% |  | 154k |
| plan | 128 | 10% | 19 | 524k |
| spec | 48 | 4% | 2 | 176k |
| other docs | 209 | 16% | 47 | 624k |
| source | 438 | 34% | 64 | 1.3M |
| git | 76 | 6% |  | 110k |
| shell other | 312 | 24% | 28 | 439k |
| skills | 5 | 0% |  | 173 |
| other files | 3 | 0% |  | 43k |
| other tools | 43 | 3% |  | 37k |

#### Largest contexts
| agent | task | calls | max ctx | cost |
|---|---:|---:|---:|---:|
| ! coding-leader | Chunk 6 bastion 0.6.0 owner | 139 | 324k | $10.21 |
| ! coding-leader | Chunk 7 network overview owner | 113 | 321k | $8.45 |
| coding-executor | v0.6 wave 2 gate run | 247 | 292k | $12.48 |
| coding-leader | Draft capture W2 for wave 2 | 73 | 263k | $5.38 |
| coding-leader | Chunk 9a timeline owner | 96 | 245k | $5.98 |
(! = over 300k tokens of context)

### Wave 2 merged; the follow-up — 2026-11-18

Merged into `main` at e955dd3 on the owner's word (not pushed); the
wave worktree and the chunk branches 6, 7, 9, 15 removed. Owner's
answers: merge now; re-pin `pg_cron`/`pgaudit` now; the older fixture
READMEs regenerated later.

On `v0.6-w2-follow` (from e955dd3):
- 8141046, `spec-writer`: plan v8. New chunk 16 in wave 4 (every
  fixture's scenario document regenerated through the skill, after
  chunks 12 and 14; split 16a/16b), D538; the re-pin recorded beside
  G9.1, D539; pgAudit 18.1 a later game-content decision.
- 1a123a6, `coding-executor`: `pg_cron` 1.6.8-1.pgdg13+3, `pgaudit`
  18.0-3.pgdg13+2 in postgres 0.5.1 (same tag), rebuilt `--no-cache
  --pull`: c2ebb6cceaed → 52300dbef515, dpkg diff exactly those two.
  postgres stack test 316/0 (both extensions load and work),
  pgbouncer 121/0, health-check 97/0.
- 9bce357, `security-advisor`: CLEAR; the new `.so` files are built
  against 18.7, so CVE-2026-6460's fix is now in full; `.tech` updated.
  No new finding.

Next: merge `v0.6-w2-follow` into `main` on the owner's word, then
wave 3 (chunks 10, 11, 13) in a fresh session, from plan v8.

## Wave 3 — started 2026-11-19

Chunks 10, 11, 13 (κ = 2). Branch `v0.6-w3`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.6-w3`, cut from `main` at 9aac312
(wave 2 and its follow-up merged; plan v8).

### Gates checked at the start

- G3 (network at image build time), hand check 2026-11-19: Debian's
  trixie `Release`, `trixie-pgdg` `Release`, GitHub's s6-overlay,
  Prometheus, `postgres_exporter` and pgwatch releases, and the
  Dockerfile's Grafana download answer 200. Cleared for wave 3.
- G4 (swarm), hand check 2026-11-19: armenelos `Ready`, `Active`,
  Leader; the VPS `vps-5718ad52` `Ready`, `Drain`. No stack deployed.
  Cleared for wave 3.
- Host: `/home` 66 % used, 55G free. The Docker lock is free.
- No dependency gate is planned for wave 3 (G9 standing: a chunk adding
  a dependency gets a `G9.<n>` row).

### Capture W3 — `gmctl history` and the seam, the faults' assessments, the GM's fake setup (chunks 10, 11, 13; read by 12, 14, 16)

Drafted 2026-11-19 for the wave driver, before any code. Sources: the
capture lines of chunks 10, 11 and 13 and the Depends and capture lines
of chunks 5, 12, 14 and 16 (plan v8); their spec packs (master spec 6.3,
6.7, 6.9, 9.1 to 9.12, 10, 11, 13 items 5 and 6); [formats.md](../../formats.md)
v36 ("A fake game's records", the fault definition's `aging.fake` and
`history:`, "Fake aging's measured figures"); spec D528, D530, D532 to
D539; W1 and W2 with their as-built records (W1-x, W1-y, W2-x, W2-y,
W2-z, the chunk records and G10.2's notes above); the code on `v0.6-w3`
at 1674461 (`tools/gm/{aging,localimpl,state,restart,render,cleanrestart,inject,fill,snapshot}.py`,
`tools/gm/__init__.py`, `bricks/prometheus/{brick.yaml,docs/player.md,rootfs/usr/local/sbin/gm-entrypoint}`,
`.claude/skills/game-master/{SKILL.md,feedback.md,gmctl.md}`, the
`scenario-document` template, the twenty faults, the shop's and the
campaign's `scenario.yaml`, `nodes/`, `player/issues.md` and answer
keys, `fixture-fill/`); and the research at `10d1bc6` (`seam_check.py`,
`import_history.sh`, read with `git show`), its
`results/fa-fake-import-f*.log` read with `grep` only. W1's rules hold:
the spec is cited, not restated; **(choice)** marks a point the sources
left open, settled with its reason; each item names its writer and its
readers; chunk internals stay out. As-built records: **W3-x** (chunk 10:
`gmctl history`'s text and working files as built, the seam's
tolerances and any check added, the import's figures, the retention
measurement, the snapshot's restart), **W3-y** (chunk 11: each fault's
assessment as written, the calibration runs, the campaign's short fill
and P0's outcome as applied, the campaign's figures, the selections'
tails as render computes them), **W3-z** (chunk 13: the skill's sections
as built, the never-told search's scope and result).

Held, cited not restated: W1 items 3 (`extract.sh`, the members chunk 11
reads), 4 (`fault_fake_aging`, `fault_history`, `instance_history`, the
kinds' fields, `{INSTANCE_NODE}`), 7 to 9 (the fill, P0, the queue
model, `<node>.metrics.jsonl`) and W1-x, W1-y; W2 items 6 (setup step
2's order), 7 (`fake_timeline`, refused instances, `left_out`, the story
line, the monitoring at zero), 8 (the record as written), 11
(clean-restart, `wal-rate.yaml`), 12 (start-load, the early check, the
history unit `dbagm-<game_id>_history` due `restart.at` plus
`aging.HISTORY_AFTER`, the outages from the restart) and 13 (the cover),
with W2-x and W2-y; D532's tails; D535 (clean-restart refused before the
anchor); D536 (`stats_reset` seconds before the start). Instants UTC,
`YYYY-MM-DDTHH:MM:SSZ`; durations `<integer><s|m|h|d>`.

**1. `gmctl history`: arguments, refusals, output** (chunk 10 writes; 12
and 13 read)

- **(choice)** `tools/gmctl history <scenario-dir> --playground <name>
  [--check-seam]`, no other option: what it needs is recorded (the
  record, the timeline, `state.yaml`), as `gmctl fill`'s (W1 item 7).
- **Refused, exit 1, nothing done**: no restart record or `mode` not
  `fake`; no `restart.at`, or the stage not `load-started` (start-load
  not run); a game without a `prometheus` node; before `restart.at`
  plus 10 minutes (`aging.HISTORY_READ`, the tail's first 10 minutes it
  reads, 9.4 step 8); at or after `handed-over` **(choice**: an import
  appearing while the players read Prometheus would be a tell of its
  own).
- **Once `history.result: ok` is recorded (choice)** it prints that
  result, exits 0 and changes nothing, so the timer's run after a GM's
  hand run, or a second hand run, is harmless. After `failed` it runs
  again (the GM's retry, by hand), first removing what a failed attempt
  copied in.
- Its timer's run carries `DBAGM_GAME` and follows every timer run's
  rules (`tools/gm/aging.py:20-24`). **It never takes the development
  Docker lock (choice)**: the timer runs outside the harness that holds
  `/tmp/dbagm-docker.lock`, and waiting for it there would deadlock the
  run that started the game.
- **`--check-seam` (choice)**: the seam check alone (item 3), against
  the live Prometheus, on a game whose `history.result` is `ok`; prints
  the verdict and its findings, records nothing; exit 0 `ok`, 1
  `failed` or refused. Why: the fixture's snapshot-restart check (item
  7), chunk 12's script and a GM after a restart read the same verdict
  from the same code, without a second import.
- **Output**, GM-side, spoilers. Its last line: `Game <id>: history
  from the virtual T0 <virtual_t0> to the restart <restart.at> imported
  at <at>; seam ok|failed (<n> findings)`, or `Game <id>: history import
  failed at <at>: <reason> (recorded; nothing torn down)`; each finding
  on its own line, `  seam <check>: <series>: <detail>`. Exit 0 only
  when `result` and `seam` are both `ok`; 1 otherwise **(choice**: a
  failed seam is a tell the GM must see as a failure; a failed timer
  unit shows it too). Tests read the record and `state.yaml`, never the
  text.

**2. The record's `history`, `state.yaml`'s `history_import`** (chunk 10
writes; 12 and 13 read)

- **The record (choice**, 6.9's form plus one key): `history: {at,
  result: ok|failed, seam: ok|failed|unchecked, reason}`; `at` the
  attempt's end, to the second; `seam: unchecked` when the import
  failed before the check; `reason` only when the two are not both
  `ok`, one line, as `fill.reason` (`"; "`-joined). Written last, after
  render's and clean-restart's keys, through
  `localimpl.write_restart_record` (the whole file); a retry replaces it.
- **Progress in `state.yaml` (choice)**, W1 item 7's rule: `history_import:
  {timer, scheduling_failed, attempts: [{began, ended, outcome, reason,
  seam: [<finding>]}]}`. Not `history`: that key is the stage history
  (`localimpl.enter_stage`, `tools/gm/localimpl.py:496`). `timer` is
  `create_timer`'s record, as `early_check.timer`; `scheduling_failed`
  as the early check's. `restart.carry_state` clears it
  (`tools/gm/restart.py:217-222`) and `aging.records_timer` counts it
  (`tools/gm/aging.py:479`), so a teardown with the manager unreachable
  still knows a timer exists.
- `gmctl status`'s line (`tools/gm/state.py:195`) reads `history import:
  <result> at <at>, seam <seam>`, then the reason when there is one.

**3. The seam check's verdicts** (chunk 10 writes; 12 reads)

- A finding is `{check, series, detail}`, `check` one of:
  - `negative`: a value below zero, in the forged past or at the join;
  - `reset`: a counter going down anywhere but at the restart, or at the
    restart on a series the restart does not reset;
  - `jump`: a gauge whose last forged value and first tail value differ
    beyond the tolerance W3-x records.
  The verdict is `ok` with no finding. Chunk 10 may add a check, named
  in W3-x; chunk 12 reads `seam` and the findings and never re-derives
  them.
- **What the restart resets** (from W2 item 11, fixes 1 and 2, D536):
  each restarted process's own counters (every scrape target's process,
  `scheduler_*`, Prometheus' own), `pg_stat_statements_*`, and the shared
  statistics clean-restart resets (`pg_stat_reset_shared(NULL)`: the
  bgwriter's, checkpointer's, WAL's, archiver's, I/O's). What survives a
  clean shutdown carries on across the join: `pg_stat_database_*` and
  the table and index statistics (9.9, "Not done, on purpose"). The
  forged past draws the restart at `restart.at` (fix 1), so the resets
  sit at the join.

**4. What the history composes, and over which span** (chunk 10 writes;
11 writes the signatures against it; 12 reads)

- Inputs: the record (`virtual_t0`, `restart.at`); the game's selection
  (the timeline's instances, `left_out` excluded); each instance's
  entries through `model.instance_history`; the fill's metrics records
  for every `scheduler_*` series (W1 item 9: the `queue` entries reach
  the past through them, never drawn twice); the tail's first 10
  minutes from Prometheus; the producers' profiles for the day's shape
  (fix 6).
- **An instance's span (choice)**: its entries apply from its
  `planted_at` (the virtual T0, or the fill's pause) to the restart; an
  instance planted in the tail adds nothing to the past;
  `gauge_before.value` holds until the planting; `daily_spike.at` is
  scenario time, drawn on each day the span covers. Why: the past is
  what the game would have shown, and a fault shows from its planting.
- **`suppressed_by` (choice)**: an entry is dropped from the planting of
  the first instance of a listed fault onward; a hiding instance planted
  in the tail drops nothing from the past. Why: the campaign's f5 hides
  f4 and f7 (master spec 9.8) but is planted at `handover-5h`, in the
  tail; their trails before it are real in a real game. The shop's f9
  (T0) hides f4 (T0) over the whole span either way. 9.5's "while a
  hiding fault is selected" read so (correction 9).
- `remove` wins over every baseline and overlay on its series (9.5).

**5. The import** (chunk 10 writes; 12 reads)

- **Where promtool runs (choice)**: `promtool tsdb create-blocks-from
  openmetrics` in a helper container of the Prometheus node's own image
  on its host (`--rm`, `--pull never`, no network, labelled
  `dbagm.game=<game id>`, as restart's and clean-restart's helpers),
  never in the running node. Why: promtool's peak was 108 to 170 MB in
  the research (`results/fa-fake-import-f2..f6.log`, `promtool_memory_peak_bytes`)
  inside a node limited to 384M (the shop's `scenario.yaml:260-263`,
  the campaign's alike) beside the running server (66M at rest, the
  rehearsal's peak, `scenario.yaml:264`, before the imported blocks it
  then holds); an out-of-memory kill of the server would be a crash the
  players see (correction 4).
- The blocks moved into `/var/lib/prometheus` whole, owned
  `prometheus:prometheus`, the folder left `0750`
  (`bricks/prometheus/rootfs/usr/local/sbin/gm-entrypoint:84-85`).
  **Prometheus is never restarted (choice)**: the import waits, bounded
  (3 minutes, the research's `import_history.sh`), for Prometheus to
  load the blocks by itself, else `failed`. Why: a second start twelve
  minutes after the restart is a start time the story doesn't cover
  (9.10, "Prometheus starts at the restart").
- Working files GM-side under `local/<playground>/history/` (W3-x names
  them), removed after a successful import; nothing of the import left
  on the node but the blocks.
- **Fixture budget (risk)**: on `fixture-fill` the anchor comes about 13
  minutes after the run's start (`run-short-test.sh:82`), the import at
  `restart.at` plus 12, the snapshot only after the earliest hand-over:
  one run holding the import and the snapshot's restart is near 30
  minutes. Means, in order: the history's run script calls `gmctl
  history` itself at `restart.at` plus 10 minutes (the timer's creation
  and due time unit-tested and read in `state.yaml`); a tail cap of at
  most 10 minutes, so the snapshot follows the import; the script's copy
  of the fixture given a shorter `aging.minimum` (the fill's span is not
  what chunk 10 tests). Never a shorter read window or timer: chunk 12's
  games run them as built. W3-x records the run's figure.

**6. The early check and the hand-over check** (chunk 10 writes; 12 and
13 read)

- **(choice)** start-load creates the history timer before the early
  check's; a fake game with no `prometheus` node gets none. The early
  check of a fake game with one waits, bounded by `aging.LATE_RUN_WAIT`
  (600 s), for `history` in the record, then prints `history import:
  ok, seam ok`, or the result, seam and reason, or `history import: not
  recorded`; anything but `ok, seam ok` fails the early check (exit 1,
  recorded, nothing torn down). Without a Prometheus node the line reads
  `history import: none (no Prometheus node)` and passes. **The
  hand-over check prints the same line and never fails on it.** Why: a
  past missing from Prometheus is a tell the GM must know of before the
  hand-over, but a failed import must not hold the game (9.4 step 8),
  and `status --set handed-over` needs a passed hand-over check.
- The import's due time is never scaled by `--test-tail-floor`: a test
  running the timer uses a tail long enough for it (chunk 12: 15
  minutes, the import at 12, the early check at 17, after the earliest
  hand-over, which is allowed).

**7. A fake game's restart** (chunk 10 writes; 13 reads; correction 1)

- **From the hand-over snapshot**: the same fake game. The timeline
  keeps `virtual_t0`, `anchor`, `tail` and `refused`; the record is
  unchanged, its `history` included; no history timer, no second import;
  Prometheus' volume (method `stop`, `bricks/prometheus/brick.yaml:129`)
  brings the imported blocks back. `--check-seam` after it reads `ok`
  (the Done when's check).
- **With no history (choice)**, by what must hold: the instances out of
  the game stay out (`left_out` unchanged, so no check reads a refused
  instance); the players' story keeps its line; the rebuild runs on the
  real clock, as the real mode's no-history restart (the data, the
  plantings and T0 at the restart, no fill, no import); the record kept
  as the first game's, for the feedback. Which timeline keys carry that
  is chunk 10's (W3-x). Why: the players were told it restarts from
  nothing (`SKILL.md:1203-1211`); a virtual clock there would date
  fresh rows before the restart.

**8. The faults' assessments: forms** (chunk 11 writes; 12 and 13 read)

- `aging.fake` as W1 item 4 and 6.9: `tail_minimum` a duration,
  `tail_covers` `"HH:MM"` scenario time (as `render.covers_seconds`
  reads it); a `supported` fault carries neither (the loader refuses
  them there).
- **`fill.emulate` (choice)**: short kebab-case tokens, as 6.9's
  `held-snapshot`; no program reads them (`model.FILL_KEYS` checks their
  shape only; nothing in `tools/gm/` or the program does), so they are
  for the GM and chunk 12's section.
- **Every number traced by a comment (choice)**: on its line, `# measured:
  <reference member>|tools/fake_aging/calibration/<file>, <what>`. The
  loader refuses unknown keys in a history entry (W1-y), so no
  `source:` key; `model.py` is no wave 3 chunk's file.
- **A parameter a signature needs** (W1 item 4: f8's slowed key) **is added
  `required: false`, `default: null` (choice)**: the scenarios already
  using the fault load unchanged (the bookshop's f3 is
  `pg-join-index-missing`, `scenarios/bookshop-new-server/scenario.yaml:156`,
  and history is read only in a fake game); every instance in a
  scenario played fake sets it in its `scenario.yaml`, its `README.md`
  regenerated in the same commit (its instance table lists the
  parameters; correction 6).
- **The `gm.md` note (choice)**: a paragraph opening `**Fake aging.**`,
  after the note's last paragraph, the run-in labels' convention
  (`faults/scheduler-transaction-held-open/gm.md:3-48`), so chunk 12's
  section and the skill's teaching moment point to it by that label.
- Chunk 11 changes no key the scenario document renders today
  (`aging.minimum`, `technique`, an instance's parameters), but the
  added parameters above: every other `README.md` stays fresh until
  chunk 12.

**9. The supports and tails chunk 12 builds on** (chunk 11 confirms; 12
reads)

- **The shop** (9.8, D532): f4 `tail-only`, `tail_minimum: 2h`; f5 and
  f7 `tail-only`, `tail_covers: ["12:00"]`; the other seven `supported`.
  The full selection: tail 3h, anchor 11:00 (`render.fake_timeline`, H
  14:00).
- **The campaign** (9.8 on the scenario as it is): f1 to f3, f8, f9
  `supported`; f4 and f7 `supported` through the cover if the short fill
  confirms them, else `tail-only` with the tail their jobs' runs need;
  f4 also `tail-only` with `tail_covers: ["12:00"]` if its check needs
  the 12:00 close; f5 `tail-only`, `plant_in: tail` (its instance is
  planted at `handover-5h`); f6 `tail-only`, `tail_minimum: 1h`; f10
  `real-only`, no `history:`. **The full selection, by 9.6 on those**:
  f10 refused, tail 5h (f5's planting moment to H), anchor 09:00.
- **P0's outcome as applied**: W3-y records the campaign's short fill
  (wall time, f4 and f7 planted, `rpt.close_day()`'s runs in
  `rpt.etl_runs` at their virtual instants, its `proconfig` identical
  after) and the support it set for each. A measurement changing any
  support or tail above is recorded in W3-y with its run and routed by
  the driver to `spec-writer` (9.8) before chunk 12 starts.
- **The short selections** (chunk 12): the shop's f1, f2, f3, f6, f8,
  f9, f10 are all `supported`; the campaign's f1 to f4 and f7 to f9 lose
  any of f4, f7 left `tail-only`, f4 by the 12:00 close included (a
  `tail_covers` instant costs the capped floor plus two hours,
  `tools/gm/render.py:556-557`).

**10. The calibration runs and the campaign's figures** (chunk 11
writes; 12 reads)

- `tools/fake_aging/calibrate.py`: scenario, node, key and fault as
  arguments (plan). **Its output (choice)**: one file per run in
  `tools/fake_aging/calibration/`, `<scenario id>-<what>-<YYYYMMDDTHHMMZ>.txt`
  (`<what>` the instance, `fill` or `wal-<node>`), opening with the
  command, the commit, the start and the wall time. Never reference
  data: the shop's numbers are read through `extract.sh` and cited by
  member (W1 item 3).
- Each run under the lock and the inhibitor, one at a time, under 30
  minutes, its game torn down after.
- **The campaign's service times**: a `service-times.yaml` beside each
  scheduler node's `queries.yaml` whose keys the fill runs: `consumer`,
  `bi`, `crm` and `gateway` (only `producer` has one; `gmctl fill`
  refuses a key without one, formats.md "Fake aging's measured
  figures"); keys shared with the shop copy its figures with their
  source (W1 item 9). Correction 5.
- **`wal-rate.yaml`** for the campaign's `db` and `reporting`, formats.md's
  form, `bytes_per_hour` from `pg_stat_wal.wal_bytes` from after the
  data load to the run's end, `source:` naming the calibration file.
  **The shop's file stays chunk 9's (choice)**: 11b measures the shop's
  rate the same way in one of its short runs if one fits, and W3-y
  records it beside the file's 43881262 (which includes the seed load,
  W2-x); the file is unchanged, and chunk 12's M1 comparison decides.
- **A test (choice)**: `tools/tests/test_fake_aging_faults.py` (new):
  the twenty definitions carry `aging.fake`, a `history:` unless
  `real-only`, the `gm.md` note where `tail-only` or `real-only`, and a
  `# measured:` comment on each number line, so wave 3's gate row ("every
  fault of the shop and the campaign ... with `aging.fake` and
  `history:`") is a test (correction 7).

**11. The skill: the dialogue, the fake setup, the never-told rule, the
feedback** (chunk 13 writes; reads W2 items 6 to 8, 12 and W3 items 1,
2, 6, 7, 9, 12)

- **Refused instances in a GM-run game (choice)**: the GM composes the
  selection before render, so render refuses no instance a handout
  names. An instance an issue in `player/issues.md` (or any handout)
  names and fake aging can't make is replaced through "Designing a
  scenario", or the game is played real, or declined (9.1). Render's
  refusal (D528) stays the safety net: a game runs without an instance
  no handout names. In the evaluation and the feedback a refused
  instance is out of the game, neither expected nor credited, never
  named to the players. Why: the campaign's f10 is `real-only` and issue
  6 is its (`scenarios/tarnbeck-outdoor-campaign/player/issues.md:22-24`,
  `gm/answer-key.yaml:746`); handed out without its cause, the issue
  sends the players after nothing (correction 8).
- **No `gmctl history` invocation in the skill (choice)**: the import
  runs by its timer from start-load; the skill names the timer, reads
  the result in `gmctl status` and the record, and points to
  `gmctl.md`'s `history` row for a retry. Why: chunk 13 may merge before
  chunk 10, and its Done when parses every invocation with `gmctl`'s
  parser.
- The setup's steps in 9.4's order, every invocation as `gmctl.md`
  states it (W2 items 7, 11, 12): `render --aging fake --handover H`
  (it prints the tail and the anchor, and refuses an anchor already
  passed), `deploy`, `load-data`, `inject`, `fill`, the wait to the
  anchor, `clean-restart`, `start-load`. H is the time from now to the
  restart (the setup, W2's figures: the fixture's fill 449 to 526 s for
  about 15 virtual hours, about 15 minutes from the deploy to the
  restart) plus the tail.
- **The never-told search (choice)**: the texts the skill gives a player
  or a playing initiator (the setup dialogue, the restart's statement
  and question, the in-world facts, the feedback's customer side) are
  marked so the Done when's search is mechanical and repeatable at the
  release gate; W3-z records the marking, the search and its result.
  Today's restart statement says "the history the aging built"
  (`SKILL.md:1207`): it changes.
- The feedback reads the record (`restart.at`, `story_line`, `explains`,
  `history` with its reason), item 12's section, each fault's
  `aging.fake.reason` and its `**Fake aging.**` note.

**12. The scenario document's "Fake aging" section, as far as chunk 13
cites it** (chunk 12 writes in wave 4; 13 reads now)

- **(choice)** Heading `## Fake aging` (anchor `#fake-aging`), the name
  9.10 and the plan give it, holding 9.10's per-scenario facts: each
  instance's support with its reason, its tail needs and `plant_in`;
  the tail the full selection needs, with its anchor at the designed
  hand-over; the instances refused, with their reasons; the limits that
  touch its evidence; "not assessed" where the faults are. Its layout
  and wording are chunk 12's (W4). Chunk 13 cites it by heading and
  facts only (correction 10).

**13. Wave 3's order, owners and the shared lists** (plan "Wave 3's
order")

- **Order**: 13 and 11 first; 10 in 13's slot; 10's and 11's Docker
  runs queue on the lock. **Merge in any order**: once corrections 1, 5,
  6 and 7 land no file is shared. Checked against the code: of the
  shared lists, only chunk 10 registers a verb (`tools/gm/__init__.py`)
  and writes `gmctl.md`; chunk 13 touches neither (its Out); chunk 11
  adds no verb (9.12: the calibration tool is not `gmctl`) and no
  fixture; the shop's `scenario.yaml` and `README.md` are chunk 11's
  alone.
- **Owners**:
  - chunk 10: `tools/gm/history.py` (new); `aging.py` (start-load's
    timer, the checks' line, `records_timer`, `HISTORY_READ`),
    `localimpl.py`, `state.py`, `restart.py` (item 7), `__init__.py` (the
    verb); `tools/tests/{test_history,test_aging,test_restart}.py`;
    `gmctl.md` (the `history` row and output, start-load's and check's
    rows for the timer and the line); `fixture-fill/` (its fixture
    faults, the history's run script, its `README.md` regenerated);
  - chunk 11: the twenty faults' `fault.yaml` and `gm.md`;
    `tools/fake_aging/{calibrate.py,calibration/}`; the campaign's four
    `service-times.yaml` and two `wal-rate.yaml`; the shop's (and the
    campaign's, should one gain a parameter) `scenario.yaml` and
    `README.md`; `tools/tests/test_fake_aging_faults.py`;
  - chunk 13: `.claude/skills/game-master/{SKILL.md,feedback.md}`.
- **What wave 4 reads from W3**: chunk 12, items 1 to 6 and 8 to 10,
  W3-x and W3-y; 12 also builds item 12's section. Chunks 5, 14 and 16
  read nothing from W3 (16 regenerates `fixture-fill`'s `README.md`
  again, after chunk 10's).

**Choices made here, not in the spec** (for the driver's review):
`gmctl history`'s arguments, refusals, idempotence and retry; no Docker
lock in its run; `--check-seam`; the output's last line and exit
status; the record's `seam` values and `reason`; `state.yaml`'s
`history_import`; the seam's three checks and what the restart resets;
an instance's span in the past and `suppressed_by` from the hiding
instance's planting; promtool in a helper container; no Prometheus
restart, the bounded wait; the early check failing on the import, the
hand-over check not; the restart's two cases; `fill.emulate` tokens;
`# measured:` comments; a signature's parameter optional; the `gm.md`
note's label; the calibration files' names; the shop's WAL rate left
as it is; the faults' test; refused instances in a GM-run game; no
`history` invocation in the skill; the never-told search's marking;
the section's heading.

### Preflight corrections for spec-writer

1. **Chunk 10's Files gain `tools/gm/restart.py` and
   `tools/tests/test_restart.py`**: `restart.new_timeline`
   (`tools/gm/restart.py:199-204`) rebuilds the timeline with
   `render.build_timeline`, which has no fake keys, so after any restart
   of a fake game `localimpl.left_out` (`tools/gm/localimpl.py:419-430`)
   loses `refused` (the checks read refused instances again), `is_fake`
   turns false, and the bastion's `story.md` loses its line
   (`tools/gm/render.py:605-606`). Chunk 9 noted it ("chunk 11's area",
   this log, chunk 9a's record: the v0.3 chunk that wrote `restart.py`);
   no v0.6 chunk owns it, and chunk 10's Done when restarts a fake
   game from its snapshot. Chunk 10's Scope gains item 7.
2. **The players have a shell on the Prometheus node**: master spec
   9.10's row (master-spec.md:1193, "the players have no shell on the
   Prometheus node (to verify)"), build-plan.md:392-394 and :414, and
   chunk 12's "no player shell on the Prometheus node"
   (build-plan.md:1504-1505) against `bricks/prometheus/docs/player.md:8-9`
   (`ssh player@<node>`), which f10's fix needs (it edits
   `prometheus.yml` there). What hides the blocks is the TSDB folder,
   `prometheus:prometheus 0750` (`gm-entrypoint:84-85`). Fix: 9.10's
   curation to read "the players' shell can't read the TSDB folder";
   chunk 12's check "the `player` account cannot list
   `/var/lib/prometheus`"; chunk 10's "the players' access ... read from
   the write policies" (build-plan.md:1274-1275) to read "the TSDB
   folder's owner and mode, which the import keeps" (the write policies
   govern `/etc/prometheus` only, `bricks/prometheus/brick.yaml:55-57`).
3. **A limit 9.10 lacks: Prometheus' own series show the import**
   (master-spec.md:1180-1197): `prometheus_tsdb_lowest_timestamp_seconds`
   drops from `restart.at` to the virtual T0, `prometheus_tsdb_blocks_loaded`
   and `prometheus_tsdb_storage_blocks_bytes` step up, about 12 minutes
   after the restart, in the series the `prometheus` job scrapes (the
   shop's `nodes/prometheus/prometheus.yml:16-19`), readable by any player
   in Prometheus and Grafana. The tail's own samples can't be rewritten
   without the admin API. Fix: a 9.10 row (curation none, not covered
   by the story); its `explains` row in `cleanrestart.EXPLAINS` follows
   the spec's decision (chunk 10's, `cleanrestart.py` then in its
   Files); chunk 12's tells script may report it.
4. **promtool "in the Prometheus node"** (build-plan.md:1268-1269): to
   read "with the Prometheus node's image, in a helper container on its
   host" (item 5's reason).
5. **Chunk 11's Files: the campaign's service times**: "the campaign's
   service times beside its `queries.yaml` if a key is campaign-only"
   (build-plan.md:1358-1360, :1344, :372-373) is narrower than what
   11b's short fill needs: only `nodes/producer/service-times.yaml`
   exists, and `gmctl fill` refuses a key without one. Fix:
   `scenarios/tarnbeck-outdoor-campaign/nodes/{consumer,bi,crm,gateway}/service-times.yaml`
   (new) named.
6. **Chunk 11's Files: the scenarios setting a new parameter**: W1 item
   4 (this log, "a fault lacking a parameter its signature needs (f8's
   slowed key) gains one in chunk 11") makes an instance set it, so
   `scenarios/tarnbeck-outdoor-shop/{scenario.yaml,README.md}` (and the
   campaign's, should one of its faults gain one) join chunk 11's Files,
   the README regenerated in the same commit (workflow deltas, "a chunk
   changing a generated file's input").
7. **Chunk 11's Files: `tools/tests/test_fake_aging_faults.py`** (new;
   item 10): wave 3's gate row (build-plan.md:312) has no test behind it,
   since the format check accepts a fault without `aging.fake` (optional,
   W1 item 0).
8. **Handouts naming an instance fake aging can't make**: 9.1
   (master-spec.md:885-889) and D528 (access-model.md:119-122: the game
   runs without a refused instance) are silent on an issue the starter
   pack carries for it; 9.8's "With f10 out" (master-spec.md:1138) runs
   the campaign with issue 6 (`player/issues.md:22-24`) and no cause.
   Fix: 9.1 to say a GM-run game never leaves refused an instance a
   handout names (item 11); 9.8's campaign note to say issue 6 goes
   with f10 in a fake game's design. If spec-writer finds 9.1's
   "replaces ... or declines" does not cover a variant without that
   issue, it is the owner's.
9. **9.5's `suppressed_by`** ("drops an entry while a hiding fault is
   selected", master-spec.md:1058-1059): to read "from the hiding
   instance's planting", item 4's reason (the campaign's f5 is planted
   in the tail and hides f4 and f7).
10. **Chunk 13 reads a section chunk 12 writes a wave later**
    (build-plan.md:1402 against chunk 12's :1506-1509): chunk 13's
    Depends to name "capture W3 item 12 (the "Fake aging" section's
    heading and facts)". And 9.2's "ready in about an hour and a half"
    (master-spec.md:901-902) needs the setup's time, which no GM-facing
    document carries: 9.10's per-scenario section to add the fill's
    measured duration (chunk 12 measures it, build-plan.md Done when).
11. **For G10.3 after wave 3's gate** (none contradicts the spec;
    formats.md v36 doesn't carry them): the record's `history` with
    `seam` values and `reason`; `state.yaml`'s `history_import`; the
    history unit and `HISTORY_READ`; `--check-seam`; the seam's
    findings; the `# measured:` comments; the calibration files' names;
    the `**Fake aging.**` note.

### Questions for the owner (as drafted)

None. Every point above is settled by the spec, a capture, or a
correction `spec-writer` can make without changing how a game plays;
correction 8 goes to the owner only if `spec-writer` finds 9.1 doesn't
cover a scenario variant without the refused instance's issue.
Recommendation there: the GM designs that variant, or plays the
campaign real.

### W3 reviewed by the driver, 2026-11-19

Drafted by a `coding-leader` (3cba8b7, about 87 tool calls). The
capture's (choice) points are accepted as drafted. No owner question.
Corrections 1 to 11 go to `spec-writer` for plan v9 on `v0.6-w3`.
Chunk 13 starts at once: its only correction (10: its Depends naming
W3 item 12) changes no file it builds, and its brief carries W3 items
7, 8, 11 and 12. Chunk 11 starts once plan v9 is committed
(corrections 5, 6, 7 give it the campaign's `service-times.yaml`, the
shop's `scenario.yaml`/`README.md` and the new test); chunk 10 takes
the next free slot after plan v9 (correction 1 gives it `restart.py`).

### Plan v9 (70fc0d5); chunk 11 started, 2026-11-19

- `spec-writer` applied W3's corrections 1 to 11, none declined: plan
  v9, 70fc0d5. **D540**: the players keep their Prometheus shell; the
  TSDB folder (`prometheus:prometheus 0750`) is what hides the blocks.
  **D541**: Prometheus' own `prometheus_tsdb_*` series step at the
  import, a documented limit (9.10). **D542**: an instance a handout
  names that fake aging can't make is never left to render's refusal
  (a variant without it and its issue, the game real, or decline;
  the campaign's f10 and issue 6 together; v1.0 gating's campaign
  blind read becomes that variant). **D543**: `suppressed_by` counts
  from the hiding instance's planting (formats.md v37 [renumbered v38 at
  the merge with main]). **D544**: the
  "Fake aging" section carries the setup's measured time, behind 9.2's
  "ready in about…". G10.3 added. No owner question.
- Relayed to chunk 13 (running): D544's duration, D542's selection
  rule, 9.10 in its Spec sections.
- Chunk 11 dispatched to a `coding-leader` from 70fc0d5, branch
  `v0.6-c11-faults-assessed`, split 11a/11b, rotation at ~100 calls.

### Chunk 13 — merged (0ec38b3), 2026-11-19

944731e, merge 0ec38b3 (rebased onto plan v9 first). Only
`.claude/skills/game-master/{SKILL.md,feedback.md}`.

Done when: the play question asked once with the time available,
modes offered per 9.1/9.2 (D516: "quick game"/"extended game" by
duration to a possible player; D544's estimate; D542's selection
rule); the never-told search over every marked player text: 0 hits
(28 texts, a probe file with the words gives 3 hits); the fake-mode
steps in 9.4's order, 44/44 `gmctl` invocations parse with
`build_parser()`; the feedback in two parts with the tell rule
("Fake aging in the teaching moment"). No `gmctl history` invocation
(W3 item 11): the skill names the timer and reads `status`.

**W3-z** (as built): player-facing texts wrapped in `<!-- player -->`
… `<!-- /player -->` (26 in SKILL.md, 2 in feedback.md); the search
command and word list (aging/ageing/ages/aged, fill*,
forge/forged/forgery/forging, virtual, fake*) in SKILL.md's top
comment; the rule holds in both modes; a picked-up game treats the
initiator as one who may play; a failed or bad-seam import: retry by
hand, then set up again or hand over as is.

Left: fake mode is offered only once a scenario document has a
`## Fake aging` section (chunk 12, wave 4); gmctl.md's `history` row
(chunk 10). Risk: a solo initiator who also plays can see the GM's
tool output during setup (`status` prints `aging: fake`); v0.5
already accepted that risk for setup output.

**For the wave gate:** the unit suite has one failure,
`test_model.TestV06Templates.test_domain_and_overview_templates`
(`domain.yaml`'s `overview` not optional), already failing on `main`
at 9aac312, so not wave 3's: chunk 3's test predates chunk 7a
(50ee241), which made the domains' overview required. To trace and fix
at the gate.

Figures: 1 agents, 99 tool calls, 15.7M tokens in / 73k out, max
context 229k, $5.62 at API prices.

### Chunk 11a — committed (816c090), owner rotated, 2026-11-19

11a on `v0.6-c11-faults-assessed`, not merged (11b, then one merge);
the worktree kept for 11b, with an ignored reference cache in
`tools/fake_aging/reference/extracted/` (1.4 GB, deletable). No Docker
run. The shop's ten faults carry `aging.fake` and `history:`, every
number `# measured:` against an archive member; f4, f5, f7 `gm.md`
notes; optional parameters (`database` on scheduler-query-error and
scheduler-report-unbounded, `key` on scheduler-insert-retry-duplicates
and pg-join-index-missing, `key`/`blocked-key` on
scheduler-batch-at-peak) set by the shop's instances;
`tools/fake_aging/calibrate.py` copied from `10d1bc6` and generalised;
`test_fake_aging_faults.py` (6 tests, shop only).

**W3-y, the shop's part**: f4 `tail-only` (`tail_minimum: 2h`), f5 and
f7 `tail-only` (`tail_covers: ["12:00"]`), the other seven `supported`;
all `plant_in: any`; the full selection's tail stays 3h, anchor 11:00
(W3 item 9). Signatures from run R: f1 `xact_rollback` 0.100/call; f2
service {0.198, 0.03}, `temp_bytes` 20 450 000 and `temp_files` 1 per
call; f3 `tup_inserted` 0.228/call; f4 sawtooth 300 s × 300; f5 lock
{21.25, 0}; f6, f7, f9 `none`; f8 service {0.024, 0.35},
`tup_returned` 963 700 and `blks_hit` 12 410 per call; f10 two
`remove` selectors. No calibration run for the shop (archive reads).

Deviations: (1) **f9's `suppressed_by` over f4 not written**: the
exporter has no per-table series and R shows f4's sawtooth throughout,
so f9 hides f4 only in state and logs; the chunk's scope line and W3
item 4's "the shop's f9 hides f4 over the whole span" are wrong, sent
to `spec-writer`. (2) f5 has no `daily_spike` (R holds no noon-run
sample; the shop's span holds no noon before the tail). (3) f1, f2, f3,
f5 also gained optional parameters (W3 item 8's pattern). The shop's
`README.md` instance rows were edited by hand: 11b regenerates it with
the `scenario-document` skill.

Figures (owner 1): see the chunk's total line at its merge.

### Plan v10 (1d582a7); chunk 11b started, 2026-11-19

- `spec-writer`: plan v10, 1d582a7, **D548**: the shop has no
  `suppressed_by` pair (its f9 hides f4 only in `orders`' state and the
  autovacuum log lines); the shop's f5 has no `daily_spike`; chunk 11's
  optional-parameter line as 11a built it. Master spec 9.8's f9 and f5
  rows and 6.9's shape example corrected. Chunk 12 does not rely on the
  pair. **W3 item 4's last two sentences now read**: "The shop has no
  `suppressed_by` pair: its f9 hides f4 only in state and logs (the
  exporter has no per-table series; R shows f4's `max_tx_duration`
  sawtooth throughout; spec D548). 9.5's 'while a hiding fault is
  selected' read so (correction 9)."
- Chunk 11b dispatched to a fresh `coding-leader`, resuming from
  816c090 (the shop's `README.md` to be regenerated through the skill).
  Relayed: confirm in its own run that the campaign's f5 hides f4's and
  f7's trail in a Prometheus series before writing that pair (D543),
  else report it as D548's case.

### Chunk 10a — committed (18c85f0), 10b WIP (a2469a1), owner rotated, 2026-11-19

Rotated on the driver's word at ~85 calls, context past 300k. On
`v0.6-c10-history`, not merged; worktree kept. No Docker run.
`test_aging`, `test_restart`, `test_cleanrestart`, `test_history`: 156
OK on a2469a1.

- **10a** (18c85f0): `tools/gm/history.py`'s composer (span from the
  virtual T0 to `restart.at` on each target's scrape grid; one baseline
  per series by class, fixes 1, 5, 6; the load shape from the fill's
  metrics records, bounded 0.25 to 4; the kinds per W3 item 4,
  `suppressed_by` from the hiding instance's planting, D543;
  OpenMetrics out) and the seam check (findings `{check, series,
  detail}`, `check` ∈ `negative`, `reset`, `jump` (size gauges, 1 %
  tolerance), `empty` (added: no sample before the restart)).
- **10b WIP** (a2469a1): `gmctl history <dir> --playground <pg>
  [--check-seam]` per W3 item 1 (refusals; no-op once ok; a failed
  import's blocks removed before a retry; promtool in a `--rm`,
  `--pull never`, network-less helper of the node's image; blocks moved
  in whole, folder untouched, D540; load wait ≤180 s, no Prometheus
  restart); the record's `history: {at, result, seam, reason}` written
  last; `state.yaml`'s `history_import: {timer, attempts[]}` with each
  attempt's figures; the start-load timer `dbagm-<gid>_history` at
  `restart.at` + 12 min; the checks' line (early ≤600 s and fails, the
  hand-over never fails); status's line; `restart.new_timeline` keeping
  the fake keys (W3 item 7); the D541 `EXPLAINS` row, the existing
  Prometheus rows made conditional on a Prometheus node; the verb
  registered; `gmctl.md`'s rows (parse with `build_parser()`).
- W3-x so far: the interface, records and verdicts above; `empty`; the
  1 % jump tolerance; a no-op rerun after "ok but seam failed" exits 1.
- Left for 10b's owner: `fixture-dropped-index`'s `history:` (a kind
  each but `none`, unit-tested only: a deviation to report),
  `run-history-test.sh`, the fixture run (~25 min estimated), the
  retention figures, then commit and merge.
- Finding relayed to chunk 11b: an `instance="{INSTANCE_NODE}"`
  selector on a `pg_*` series matches nothing (the exporter's target is
  the `instance`); every selector to be checked against the real label
  sets.

Figures (owner 1): 1 agent, ~85 tool calls, max context >300k; the
chunk's total line at its merge.

### Chunk 11 — merged (5c28a1d), 2026-11-19

11b 822b208 (second owner, from 816c090), `v0.6-w3` taken in as
1732d47, merge 5c28a1d. Worktree and reference cache removed; no
playground left.

**Host event:** armenelos rebooted at 07:55:46 UTC; every `dbagm`
image was gone from the local engine afterwards. 11b rebuilt the seven
the campaign uses (bastion 0.6.0, postgres 0.5.1, pgbouncer 0.1.2,
scheduler 0.4.0, prometheus 0.2.2, postgres-exporter 0.2.1, grafana
0.4.0) under the lock in 152 s, cached (old apt layers). The wave gate
rebuilds every brick; whether with `--no-cache` is the gate's call.

Done when: the twenty definitions load with `aging.fake`, all but the
campaign's f10 with `history:` (`test_fake_aging_faults.py`, 6 OK, the
campaign in `COVERED`); every number traced (the test); f5, f6, f10
`gm.md` notes; runs recorded with wall times: A short real run 1327 s,
B short fill 1761 s (848 s an idle wait for an hh:02 anchor), B2 short
fill 559 s; the two `wal-rate.yaml` from run A. Lock waits not counted:
~21 min behind chunk 10, ~100 min retrying B's window. Both scenario
`README.md`s regenerated through the `scenario-document` skill (shop:
11a's hand rows equal the template's, plus six "Knobs" intro lines;
campaign: f1's parameter row).

**W3-y, the campaign's part**: f1 to f4 and f7 to f9 `supported` (f1
`counter_per_call` `pg_stat_database_tup_inserted{datname="{DATABASE}"}`
on `mail.shipped`, `per_call` 70.7; the rest `kind: none`), f5
`tail-only` `plant_in: tail`, f6 `tail-only` `tail_minimum: 1h`, f10
`real-only`. Full selection unchanged (W3 item 9): f10 refused, 5h
tail, anchor 09:00. f1 gained an optional `database` (the campaign sets
`shop`). **P0 as applied** (B, B2): `rpt.etl_runs` holds the close at
virtual 23:30Z (01:30 scenario time) and every hourly roll-up at
virtual :05; the 12:00 close at virtual 10:00Z; `rpt.close_day()`'s
`proconfig` and `prosrc` md5 identical before and after, only `xmin`
moved (9.10's limit); B2's check after the restart reads f1, f2, f3,
f4, f7, f8, f9 present: f4 and f7 stay `supported`, f4 needs no 12:00
close in the tail. Service times: consumer, crm, gateway, bi and the
producer's `consent.*` keys written (bi's from `rpt.etl_runs`,
`rollup.close` on one run; `customs.unavailable` from psql timing).
WAL rates over 7.2 min of run A after the data load: db 25 418 671,
reporting 8 326 392 bytes/hour. The shop's WAL rate not measured.

Selector check (chunk 10's finding): all twenty match the real label
sets; no `instance=` selector on a `pg_*` series; nothing to fix.

Deviations: (1) **no `suppressed_by` for the campaign's f5 over f4 and
f7**: f4's and f7's trails are rows in `reporting`, `rpt.etl_runs` and
logs, which no exporter reads; D548's case; touches D543's example and
9.8's "f5 hides f4 and f7", sent to `spec-writer`. (2) bi and gateway
are report-only, so their times were measured from the fill's
`rpt.etl_runs` and psql timing. (3) Calibration file names
`keys-<node>`, `run-a`, `f1`, `f5` beyond W3 item 10. (4) f1's
`per_call` and the WAL rates from an evening window (not a day's
average, unlike the shop's 43 881 262). Found outside the chunk: the
`scenario-document` template's starter-pack line "(v0.5; the true
register … stays GM side)" sits outside any "if:" block; for the gate.
Risk for chunk 12: low-sample figures (`rollup.close` one run, the
evening WAL and f1 figures).

Figures: 3 agents, 214 tool calls, 31.6M tokens in / 200k out, max
context 243k, $17.90 at API prices.

### Plan v11 (7f7f170), 2026-11-19

`spec-writer`: **D578** (D579 reserved, unused): no covered fault uses
`suppressed_by` (the shop's f9 and the campaign's f5 hide in state and
logs only); D543's rule stands, unit-tested only. Master spec 6.9,
9.5, 9.7 (a report-only node's key timed from its runs in a fill or
with psql), 9.8 amended; chunk 10a's and 11b's text; chunk 12 gains how
to read the campaign's few-run, evening-window figures (`pg_wal`
checked against `clean_restart.wal`'s padding, never a day's figure; a
step in f1's series at the seam a finding for v1.0 gating, not a
failure); G10.3 lists wave 3's as-built forms. No change to chunk 10b.

**W3 amended** (driver, from chunks 11a and 11b and plan v10/v11):
- item 4: the rule stands, but no covered fault uses it: the shop's f9
  and the campaign's f5 hide in state and logs only (spec D548, D578);
  unit-tested only.
- item 9: as written; P0's outcome: f4 needs no 12:00 close in the
  tail, f4 and f7 stay `supported`.
- item 10: calibration file names as built `<scenario>-<what>-<stamp>.txt`
  with `keys-<node>`, `run-a`, per fault, `fill`, `wal-<node>`; the
  shop's WAL rate not measured.

### Chunk 10 — merged (552259f), 2026-11-19

10a 18c85f0; 10b 34a151c (the second owner's three WIPs squashed),
`v0.6-w3` taken in as c18f23b, merge 552259f. Worktree removed.

Done when: `test_history` composes every kind and a `suppressed_by`
pair, the seam refuses a negative value, a stray reset, a gauge jump
(28 OK); `test_restart` restarts a fake game both ways, `refused`,
`left_out` and the story line kept. **`fixture-fill`'s history run**
(`run-history-test.sh`, run 5, 2026-11-19 12:39, armenelos): **38/0,
1348 s** with the deployment: the import lands (exit 0, seam ok, 0
findings), the record's `history {at, result: ok, seam: ok}` written
last, the TSDB folder `prometheus:prometheus 750` (D540), every kind
read back over the past; the timer's run at +12 min a no-op; the early
and hand-over checks read `ok, seam ok`; refused once handed over; the
snapshot's restart keeps the record and the imported blocks, no history
timer, `--check-seam` ok; nothing left after teardown.

**W3-x** (as built): W3 item 1's interface plus **one import at a time**
(`local/<pg>/.history.lock` held for the import; the timer's run waits
and finds the result); working files `local/<pg>/history/{tail.json,
history.om,report.json}` removed after a success; the record's
`history {at, result, seam, reason}`; `state.yaml`'s `history_import
{timer, scheduling_failed, attempts[{began, ended, outcome, reason,
seam, figures}]}`, `figures` = `tail_series`, `tail_read_s`, `series`,
`samples`, `openmetrics_bytes`, `compose_s`, `import_s`, `blocks`,
`promtool_memory_peak_bytes`, `loaded_after_s`, `seam_s`, `report`,
`tsdb` (read once the self-scrape shows the blocks, ≤60 s, else
`stale`); timer `dbagm-<gid>_history` at `restart.at` + 12 min. Seam
verdicts `negative` (a series the system holds below zero, a `-1`
setting, held to its own value), `reset`, `jump` (a size gauge's step
up to the larger of 1 % and the tail's own largest step), `empty`.

Run 5's figures: deploy + load + inject 31 s; fill 227 s (466 virtual
min); clean-restart 26 s; tail before the import 10 min; `gmctl history`
68 s (tail read 2081 series 0.4 s; compose 2082 series, 3 879 946
samples, 476.5 MB OpenMetrics, 4.5 s; promtool 7.9 s, peak 587.6 MiB;
blocks loaded 50.9 s; seam 4.0 s; 4 blocks ~1.3 MB each); snapshot
10 s; restart from it 33 s. Retention: the lowest timestamp moved from
the restart (11:46:21Z) to the virtual T0 + 3 s (04:00:03Z), 4 blocks,
5 359 865 bytes, unchanged a minute later and after the restart
(retention 1d / 384MB; a 13 to 15 h past not measured). Verified live:
promtool `-q` (Prometheus 3.16.0), `memory.peak` in the helper.

Runs: (1) refused at fit, `aging.minimum` ≥ 8h (D150); (2) 24/14,
1349 s: the helper's `/tmp` dangling link, the two seam refinements;
(3) 35/3: `prometheus_tsdb_*` read before the self-scrape; (4) the lock
held by 11b, the script refused its window, nothing deployed; (5) 38/0.

Deviations, for G10.3 via `spec-writer`: `none` unit-tested only (a
signature's only entry); `run-history-test.sh` starts only between
hh:38 and hh:41 (exit 3 otherwise: H a whole hour, aging ≥ 8h, the run
under 30 min); the fixture's `README.md` not regenerated (the fault is
not its input); `gauge_before` on `pg_database_size_bytes` (no
per-index series); the run lock.

Findings outside the chunk: (a) **the exporter connects to the
`postgres` database only**: scenario databases have no
`pg_stat_user_tables_*`/`pg_stat_user_indexes_*` series, so a signature
or tell on them matches nothing (11b checked its twenty: none does);
chunk 12 checks its selectors (for its brief). (b) **`fill.queue_plan`
drops a `queue` entry outright when any selected fault suppresses it**,
ignoring the hiding instance's planting (D543); no covered fault uses
`suppressed_by` (D578), so nothing breaks today: fix-sized, for the
owner (issue or inserted chunk). (c) `shellcheck` is not installed on
armenelos. Risks: the GM host's memory (732 MB peak for an 8 h past in
run 2, about double for 16 h); promtool's ~590 MiB peak in an unlimited
helper; the run's 30-minute budget has ~7 min of margin.

Figures: 2 agents, 227 tool calls, 44.4M tokens in / 228k out, max
context 310k (owner 1, marked: rotated at 10a), $24.61 at API prices;
owner 2 ran ~140 calls, past the bound, on timing windows and lock
waits.

### Wave 3's chunks all merged, 2026-11-19

Chunks 13 (0ec38b3), 11 (5c28a1d), 10 (552259f). Next: the wave gate.

### Wave 3 gate — 2026-11-19, green after one fix

`coding-executor` at the wave-gate level, armenelos, 12:10–14:33 UTC,
from 682f6cd; every docker step serialised under the lock and the
inhibitor, κ = 1, each item under 30 minutes; the VPS unused, nothing
pruned. Head after the gate: 3bb81c0 (ISS-007, committed by the driver
during the gate, over the gate's fix f07f0b1).

| Item | Result |
|---|---|
| Unit suite | 1496 OK, 2 skipped, 370 s (after the fix) |
| Scheduler unit tests, replay guard | 113 OK (6 `TestP0`), the real mode's replay byte for byte, 209 s |
| api unit tests | 36 OK, 30 s |
| `sh -n`, `py_compile`, `perl -c` | 343 shell (`run-history-test.sh` new), 478 Python, 14 Perl files OK; `shellcheck` not installed |
| Builds `--no-cache --pull` | ten OK, 163 s |
| `check-base.sh` | 10/10 Debian 13 |
| Ten bricks' stack tests | postgres 316, bastion 136, pgbouncer 121, scheduler 179 (824 s), api 89, prometheus 132, postgres-exporter 104, grafana 131, pgwatch 73, health-check 97; all 0 failed |
| Smokes | smoke 61, monitoring 43, governance 121, load 73 (431 s) |
| Scenario smokes | bookshop 19, fernway-clinics 18, tarnbeck shop 26 (831 s), tarnbeck campaign 33 (316 s) |
| `fixture-fill` history test (chunk 10) | **38/0, 1386 s** |
| `fixture-fill` short test | 65/0, 889 s; p50 checks hold for producer and consumer |
| `fixture-status` | 27/0, 381 s |
| `test_fake_aging_faults` | 6 OK |
| `check_fault_dir`, `check_scenario`, `check_domain_dir` | 39/39 catalogue faults, 37/37 fixture faults; 5/5 scenarios, 32/32 fixtures (fixture-v04-refusals against `catalog/`); 0 problems |
| Calibration files | 12 in `tools/fake_aging/calibration/`; the 9 that faults and the log name all exist |
| READMEs (shop, campaign) | the parts wave 3 could change re-rendered by hand: 20 fault-instance rows, 0 mismatches; the "Knobs" intro lines follow the template |

**Fix** (its own commit on `v0.6-w3`): f07f0b1,
`test_model.TestV06Templates.test_domain_and_overview_templates` expects
the domain template's `overview` required (D487, master spec 6.5);
stale since wave 2's f6e14ab, failing on `main` too.

**One rerun (environment)**: the bastion stack test first stopped on
"image debian:13-slim not built", its stub image, which the 07:55 reboot
removed and `--pull` builds don't restore; pulled, rerun 136/0.

**dpkg**: the seven images 11b rebuilt from cache diffed against their
pre-gate lists: no change. api (141 packages), health-check (151) and
pgwatch (126) had no earlier list; recorded now. G9.1's packages as G9.1
and the follow-up left them (libpq5 17.12 in api, scheduler,
health-check; postgres 18.7-1.pgdg13+2 with `pg_cron` 1.6.8-1.pgdg13+3
and `pgaudit` 18.0-3.pgdg13+2; libcares2 1.34.9-1~deb13u1 in
pgbouncer). **No package change: no G9.2 row, no post-change check.**

**Figures**:
- History test: deploy, load and inject 29 s; fill 229 s for 466
  virtual minutes; clean-restart 28 s; `gmctl history` 81 s (tail's 2081
  series read 0.4 s; composed 2082 series, 3 880 181 samples, 476.6 MB
  of OpenMetrics in 4.8 s; promtool 8.5 s, peak 610.4 MiB; blocks loaded
  51.0 s later; seam check 4.3 s); 5 blocks, 5 566 509 bytes. Lowest
  timestamp 12:46:23Z → 05:00:03Z (virtual T0 + 3 s), unchanged a minute
  later and after the restart; snapshot 9 s, restart from it 31 s, the
  imported blocks kept.
- Short fill: 467 s for 925 virtual minutes on 2 scheduler nodes;
  exporter sessions 3710 against 3700 expected; autovacuum 97 runs on
  `products`, 2 on `customers`; clean-restart 26 s, WAL padding
  1 084 484 928 bytes in 1.5 s, `pg_wal` 1 056 964 608 bytes; starts
  +1.3 to +2.2 s from `restart.at`; `stats_reset` 9 s before it.
- `/home` 55 GB free. Teardown clean; seven untagged pre-rebuild images
  left (nothing pruned).

Not seen in the gate: D578's case, the template's starter-pack line
outside an "if:" block (for chunk 12 or 16), ISS-007.

Next: G10.3 to `spec-writer`.

### G10.3 done — 2026-11-19

`spec-writer`, 06a5d21 (formats.md v38 [renumbered v39 at the merge with
main], master spec, plan v12,
D580–D583) and b0f7840 (gate row). Every form checked against the code
(`history.py`, `aging.py`, `state.py`, `restart.py`, `cleanrestart.py`,
gmctl.md, SKILL.md, `tools/fake_aging/`, the twenty faults, the loader).
None contradicts the spec.

- D580 the umbrella (as D534); D581 the seam check as built (joins
  checked on size gauges only, within the larger of 1 % and the tail's
  largest step; `negative` for a series the system holds below zero;
  `empty`): master spec 12.1 now reads "size gauges joining", read as a
  gap filled (the other gauges are drawn from the tail's level); D582 a
  fake game's restart without history (W3 item 7 as built); D583 one
  import at a time, `ok` final even with a failed seam, a failed import
  retried by hand.
- Chunk 10's Record items and the exporter's reach (`postgres` database
  only) now in 9.5 and formats.md.
- Open, for the owner: master spec 9.9 fix 5 claims a `gauge_before` for
  a dropped index's size, but the shop's f8 (`pg-join-index-missing`)
  has none (only `fixture-dropped-index` has one); the shop's forged past
  likely shows no database-size step at f8's planting (about 20 MB on
  182 MB). Add a measured `gauge_before` to f8, or record a limit.
- Open, for the owner: nothing enforces a fake game's instance setting a
  signature's optional parameter (f1's `database`); unset, the selector
  matches nothing, silently (`test_fake_aging_faults` covers the two
  scenarios). A render refusal would be fix-sized.
- Sent as gate fixes (driver's call, text only, the code following the
  spec): gmctl.md (about line 389) and SKILL.md (about line 1236) advise
  retrying "a failed seam" by hand, which D583 makes a no-op;
  `calibrate.py`'s docstring lists the old names; from wave 2,
  `cleanrestart.EXPLAINS`' real-clock row leaves out Grafana's alert
  state and history and its no-log row says "the night" where 9.10 says
  "the fill".
- Retention measured only in part (section 18): a 13–15 h past and a
  compaction not measured; for chunk 12's games or v1.0 gating.
- For chunk 12's brief: its seam check reads `gmctl history`'s verdict
  (D581) and may use `--check-seam`; its selectors meet the exporter's
  reach; f8's gap could show in the shop's M1 comparison. Chunks 5, 14,
  16 read nothing that changed.

`doc-ids compare main v0.6-w3`: 0 collisions.

### After G10.3: gate fixes, ISS-008, plan v13 — 2026-11-19

- Gate fixes (`coding-executor`, unit suite 1496 OK after them): 6334690,
  gmctl.md and SKILL.md's retry advice follows D583 (a failed import is
  retried by hand; a failed seam with the import `ok` is never rerun);
  cd3d37e, `calibrate.py`'s docstring names as formats.md v38 [renumbered
  v39 at the merge with main];
  8669bd8, `cleanrestart.EXPLAINS`' real-clock row gains Grafana's alert
  state and history, its no-log row "covers the fill" (9.10). The
  real-clock row's "where it shows" still lists no Grafana view (9.10
  says "those views"); left as is.
- Owner rulings on G10.3's two open points: the unset optional signature
  parameter filed as **ISS-008** (Medium, c7e9d80); f8's missing size
  step **fixed in wave 4**.
- Plan v13 (`spec-writer`, f7794bf, spec D584): chunk 12a gains f8's
  measured `gauge_before` on `pg_database_size_bytes` (its Docker, Scope,
  Files, Done when, Verification and Split rule lines revised). New gate
  **G13 "O292 ruled"**, the owner's: `gauge_before` as built holds one
  constant level until the planting, so the shop's database size would
  read flat 22:00–08:00 and the step equals `value` minus the forged
  level; O292 asks whether to keep the kind (a 9.10 limit) or make it add
  its value to the drawn size before the planting (`history.py`,
  formats.md, `fixture-dropped-index`'s value; spec-writer recommends
  it). G13 blocks only chunk 12's f8 item, not the chunk's start.
  `fixture-dropped-index`'s "about 20 MB" is an estimate: chunk 12 must
  not reuse it.

### Wave 3 report — 2026-11-19

Chunks merged: 13 (0ec38b3), 11 (5c28a1d), 10 (552259f); none moved.
Gate green after one fix (f07f0b1), then three text fixes after G10.3;
no package change (no G9.2); G10.3 done (06a5d21, D580–D583). Issues
filed: ISS-007 (Low), ISS-008 (Medium). `doc-ids compare main v0.6-w3`:
0 collisions.

Cost: 15 agents, 1,023 tool calls, 148.9M tokens in / 865k out, max
context 310k, $75.45 at API prices (07:57–about 16:10).

| role | agents | calls | cost | share | max ctx |
|---|---:|---:|---:|---:|---:|
| coding-leader | 6 | 597 | $52.50 | 70% | **310k** |
| spec-writer | 5 | 226 | $10.04 | 13% | 201k |
| coding-executor | 3 | 134 | $7.18 | 10% | 209k |
| driver (top level) | 1 | 66 | $5.73 | 8% | 232k |

| chunk | agents | calls | cost | share | max ctx |
|---|---:|---:|---:|---:|---:|
| 10 | 2 | 227 | $24.61 | 33% | **310k** |
| 11 | 3 | 214 | $17.90 | 24% | 243k |
| 13 | 1 | 99 | $5.62 | 7% | 229k |
| outside chunks | | | $27.32 | 36% | |

Over 300k: chunk 10's first owner (85 calls, 310k), which read
`history.py`'s whole design and the composer's inputs before writing;
rotated at 10a's commit. 10b's owner ran to 142 calls (276k), past the
rotation bound, to finish its 23-minute fixture run.

### Handover for wave 4 (read this first in a fresh session)

- State: wave 3 gated on `v0.6-w3` (worktree
  `~/work/db_audit_gm-wt/v0.6-w3`), merge into `main` on the owner's word;
  then remove the worktree and the chunk branches `v0.6-c10-history`,
  `v0.6-c11-faults-assessed`, `v0.6-c13-gm-skill`.
- Wave 4: chunks 5, 12, 14, 16 (plan v13). Chunks 5 and 14 have no
  wave 4 dependency; 12 and 16 need wave 3's merge.
- G13 cleared (O292 ruled, D585): see the entry below.
- For chunk 12's brief: f8's `gauge_before` (D584, O292's form); its
  seam reads `gmctl history`'s verdict (D581), `--check-seam` available;
  its selectors meet the exporter's reach (the `postgres` database only,
  9.5); the `player` listing of the TSDB folder is its check; retention
  past 13–15 h unmeasured.
- For chunk 12 or 16: the `scenario-document` template's starter-pack
  line sits outside an "if:" block.
- Issues open in the area: ISS-007 (fill ignores the hider's planting,
  D543), ISS-008 (unset signature parameter).
- Environment: armenelos rebooted 07:55 UTC; `debian:13-slim` pulled
  again; seven untagged pre-rebuild images left (no prune); `/home` 55 GB
  free; `shellcheck` not installed; the VPS untouched.

### Main merged in; O292 ruled; wave 3 merged — 2026-11-19

- `spec-writer` merged `main` into `v0.6-w3` (8a8ecf3): main had moved
  28 commits (the v0.7 spec, 03429d9; v0.7 wave 1, ac17153 and e47df6a,
  with `tools/play`, `game-mode/publish.py`, the game-assistant agent,
  D576 and D577). Conflicts only in `specs/formats.md`, `specs/README.md`
  and `specs/decisions.md`. Both sides had taken formats.md **v37**:
  main's (v0.7's consolidation) keeps it; the wave's v37 (D543) became
  **v38** and its v38 (G10.3) **v39**; 22 references renumbered
  (067e6f7), older log entries annotated. decisions.md kept in number
  order (interleaved). Unit suite after the merge: 1546 OK, 2 skipped;
  `doc-ids compare`: 0 collisions; `merge-tree` into main clean.
- **Since the merge, `doc-get` defaults to v0.7's plan**: a v0.6 driver
  passes `doc-get --plan specs/versions/v0.6/build-plan.md …`.
- Owner, on O292: "go with the recommended option". Spec D585 (02beec5,
  plan v14, formats.md v40, G13 cleared): a `gauge_before` adds its
  `value` to the level drawn before the planting; f8's `value` is the
  dropped index's size. Chunk 12a carries it: `history.py`'s sum and a
  `test_history` case, the `scenario-format` skill's and template's
  wording, `fixture-dropped-index`'s value measured in `fixture-fill`'s
  history run (its `run-history-test.sh` check, now asserting
  `size_before == 202500000`, follows the new form), f8's measured
  `gauge_before`.
- Owner: "then merge". Wave 3 merged `--no-ff` into `main`, branch
  head at this entry's commit; the worktree and the chunk branches
  `v0.6-c10-history`, `v0.6-c11-faults-assessed`, `v0.6-c13-gm-skill`
  removed after.

## Wave 4 — started 2026-11-19

Chunks 5, 12, 14, 16 (κ = 2). Branch `v0.6-w4`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.6-w4`, cut from `main` at de48602
(wave 3 merged; plan v14).

### Gates checked at the start

- G3 (network at image build time), hand check 2026-11-19: Debian's
  trixie `Release`, `trixie-pgdg` `Release`, GitHub's s6-overlay,
  Prometheus, `postgres_exporter` and pgwatch releases, and the
  Dockerfile's Grafana download (13.3.1) answer 200. Cleared for wave 4.
- G4 (swarm), hand check 2026-11-19: armenelos `Ready`, `Active`,
  Leader; the VPS `vps-5718ad52` `Ready`, `Drain`. No stack deployed.
  Cleared for wave 4.
- Host: `/home` 66 % used, 55G free. The Docker lock is free.
- G8 (post-change check on `grafana` 0.4.0 and any image a wave 3 or 4
  chunk rebuilt) is due before the gate. G13 cleared (D585).

### Order

Only chunk 12 names a capture (W4: the verification tools' arguments
and verdicts, the short-game script's name). Chunks 5 and 14 name none
beyond W2; 16 none. So: capture W4 drafted by a `coding-leader` beside
chunk 14 (light); chunk 12 starts once W4 is reviewed (and any plan
correction it raises is committed); chunk 5 takes chunk 14's slot; 16
starts once 12 and 14 have merged.

### Capture W4 — the verification tools, the short-game script, the scenario document's "Fake aging" section (chunk 12; read by 16 and the release gate)

**Revised 2026-11-20** (spec D593, D596; plan v18): items 1, 2 and 5 as
chunk 12b built them (its entry, "Chunk 12b — stopped for rulings"),
with the owner's ruling on `n_live_tup` and the driver's on the tells'
autovacuum rule. Each change is marked "(rev. 2026-11-20)".

Drafted 2026-11-19 for the wave driver, before any code. Sources: chunk
12's and chunk 16's lines and the Release gate section (plan v14), gates
G8 and G13; their spec packs (master spec 7.6, 9.4 to 9.12, 12.1, 12.3,
14); [formats.md](../../formats.md) v40 ("Fault definition", `gauge_before`
per D585; "Fake aging's measured figures"); spec D578 and D580 to D585;
W1 to W3 with the records chunk 12 builds on (W3 items 1 to 6, 8 to 10
and 12, W3-x, W3-y as amended by plan v11, G10.3's entry, the wave 3
gate's figures, the handover for wave 4); the code on `v0.6-w4` at
e6d709c (`tools/gm/{history,aging,cleanrestart,render}.py`,
`tools/gmctl`'s parser in `tools/gm/__init__.py`, `tools/fake_aging/`
with `calibrate.py`, `calibration/` and `reference/`,
`tools/tests/fixtures/fixture-fill/{run-short-test.sh,run-history-test.sh}`,
the `scenario-document` skill and template, `fixture-v06-refusals`'
hand-rendered `README.md`, the shop's and the campaign's
`scenario.yaml`, `faults/pg-join-index-missing/fault.yaml`,
`.claude/skills/game-master/SKILL.md` where it cites the section);
ISS-007 and ISS-008; and the research at `10d1bc6` (`m4_tells.sh`,
`m1_dump.sh`, `m1_compare.py`, `m3_profile.py`,
`specs/research/fake-aging/{run-2026-11-14,results-2026-11-15}.md`, read
with `git show`), with four files of run R's M1 dump read through
`extract.sh`. W1's rules hold: the spec is cited, not restated;
**(choice)** marks a point the sources leave open, settled with its
reason; each item names its writer and its readers; chunk internals stay
out. As-built record: **W4-x** (chunk 12: the tools' and the script's
interfaces as built where they differ from items 1 to 5; each script's
start window; each game's figures and verdict counts; the M1 and M3
verdicts with the reported measures; the tells' figures; f8's value and
its source; `fixture-dropped-index`'s value; the campaign's figures as
read; the section as built).

Held, cited not restated: W1 item 3 (`extract.sh`, its exit 77 for an
absent archive) and W1-x; W2 items 7 (the fake timeline, `left_out`), 8
(the record), 11 (clean-restart, the padding, `wal-rate.yaml`) and 12
(start-load, the early check); W3 items 1 to 3 as built (W3-x, D581,
D583: `gmctl history`, its record and the seam's findings), 6 (the
checks' history line), 8 to 10 (the faults' forms, the supports, the
calibration files) and 12 (the section's heading and facts); D578 (no
covered fault uses `suppressed_by`), D584 and D585 (f8's `gauge_before`,
the sum). Instants UTC, `YYYY-MM-DDTHH:MMZ`; scenario times `HH:MM`.

**What every tool and the script share (choice)**, the form of
`calibrate.py` (W3 item 10) and the run scripts
(`run-history-test.sh:72-82`): the scenario directory first, then
`--playground <pg>`; a live game read only through `tools/gmctl exec`
(SQL as `postgres` with `default_transaction_read_only=on`, as the
research's M1 dump) or, for Prometheus, through
`tools/gm/history.py`'s `Prometheus` reader (`history.py:879`, `curl`
in the node, read-only), never a published port; each judged point one
line, `PASS  <check>: <detail>`, `FAIL  <check>: <detail>`, `SKIP
<check>: <reason>`, a figure `FIGURE  <what>: <value>`; the last line
`<tool>: <n> passed, <n> failed, <n> skipped`; exit 0 nothing failed,
1 any failure, 2 usage or refused (nothing read), 77 the reference
absent where a tool needs it (its line `SKIP ... the reference archive
is absent`, `extract.sh`'s message). Why: the script counts `PASS` and
`FAIL` lines as `run-history-test.sh` does, and the release gate reads
one form. Each tool names its origin in its header (`research/fake-aging`
10d1bc6, the file), as `calibrate.py` does.

**1. The tells script** (chunk 12 writes; the script, a GM after a
restart and the release gate read)

- **(choice)** `sh tools/fake_aging/tells.sh <scenario-dir> --playground
  <pg> --node <db node> [--node <db node> ...] [--reference --start
  <game T0 dir>]` (`--start` as built, rev. 2026-11-20, G10.4: the
  game's M1 dump at its virtual T0, item 2's, which the autovacuum
  check counts the updates from; only with `--reference`): every primary
  `postgres` node the game reads (the shop `db`; the campaign `db` and
  `reporting`), named by the caller. Refused, exit 2: no restart record
  or `mode` not `fake`, no `restart.at` (the tells are a fake game's);
  `--reference` for a scenario other than the shop, whose run R is
  (rev. 2026-11-20).
- **Its checks**, one verdict each per node, the fixed tells of 12.1
  and 9.9:
  - `start-time`: `pg_postmaster_start_time()` at or after
    `restart.at`, within 10 s of it (the wave 3 gate measured +1.3 to
    +2.2 s), before `now()`, and the same when read again at the
    script's end (no negative, no moving start);
  - `statements`: no row of `pg_stat_statements` in any database whose
    query names `gm_vclock` or `gm_pad` (the fill's clock and the
    padding's messages, `fill.py`, `cleanrestart.py:148-172`), and
    `pg_stat_statements_info.stats_reset` before `restart.at`;
  - `stats-reset`: one instant: the shared views' `stats_reset`
    (bgwriter, checkpointer, WAL, archiver, I/O) and the statements' all
    within one second of each other, before `restart.at` by at most 120
    s (D536; the bound as built, rev. 2026-11-20; the observed gap a
    `FIGURE`);
  - `pg-wal`: the live `pg_wal` total (`pg_ls_waldir()`) not below 90 %
    of `state.yaml`'s `clean_restart.wal.<node>.pg_wal_bytes`, the
    padding's own figure (`cleanrestart.py:151-172`), never a day's rate
    from `wal-rate.yaml` (plan, the campaign's figures read as
    measured). **(choice)**: only a shrinking `pg_wal` reads as a young
    server; 90 % leaves one recycled segment's worth of a 1 GB folder.
    The ratio is a `FIGURE` too;
  - `autovacuum`: per table, with the reference (the shop, `--reference`
    given; rev. 2026-11-20, D596): the updated rows counted from the
    game's T0 dump (the script's M1 at T0; R's from the same T0, the
    same data), so the load's own updates count in neither; each run of
    a bulk statement updating the whole table in the span (the shop's
    `orders.close-day` on `customers`, `nodes/producer/queries.yaml:73`)
    expected as one run, in the game and in R; the remaining runs
    expected at R's runs per updated row: expected = bulk runs + (R's
    runs − R's bulk runs) × the game's updated rows ÷ R's, ×0.5 to ×2,
    one run either way (the shop's `customers`: (6 − 1) × 16617 / 30334
    + 1 = 3.7, band 0.85 to 8.4). What the rule leaves unexplained (about
    2.7 runs from order updates in R: pruning, 18 against 19, time
    compression) is a `FIGURE`, never judged. Without the reference (the
    campaign): a table whose updated and deleted rows passed its
    autovacuum threshold at least once has at least one run, and none
    more than its dirtied rows (inserted, updated and deleted: inserts
    trigger autovacuum too) over that threshold plus one
    **(choice**: the only range the campaign's own figures give; all
    dirtied rows as built, rev. 2026-11-20);
  - `search-path`: no routine in any database with `gm_vclock` in its
    `proconfig`'s `search_path`, and no `gm_vclock` schema left.
- `FIGURE` only, never a verdict (9.10's row, curation none; W3
  correction 3): Prometheus' `prometheus_tsdb_lowest_timestamp_seconds`,
  `prometheus_tsdb_blocks_loaded` and `prometheus_tsdb_storage_blocks_bytes`
  at the read.
- `--reference`: run R's tells (`m4-r-20261115.txt`) and M1 table
  statistics read through `extract.sh`; with the archive absent, or
  without `--start` (rev. 2026-11-20, G10.4), the autovacuum check
  takes the campaign's rule and says so in a `SKIP` line for R's.

**2. The M1 dump and comparison** (chunk 12 writes; the script reads)

- `sh tools/fake_aging/m1_dump.sh <scenario-dir> --playground <pg>
  --node <db node> --database <db> <out-dir>`: the research's queries,
  its output form (one CSV a query and `meta.txt`, as run R's
  `m1-fa-real-20261115T0800/`), the database an argument; a query whose
  tables the database lacks (the shop's order statuses and ledger)
  writes no file.
- **The span and the selection differ from R's (finding)**: run R aged
  24 hours, from 13:59 to 14:00 customer time
  (`run-2026-11-14.md`, "Run R"); a fake game's virtual T0 is H minus
  `aging.minimum`, the shop's 16 h (`scenario.yaml:33`, T0 22:00), and
  the short selection lacks f4, f5 and f7, which R played. Every count
  accumulated over the span (inserts, updates, scans, transaction ages)
  differs by R's afternoon and evening; the research's ±3 % held only
  because its F runs matched R's span (`run-2026-11-14.md`, "Span").
- **(choice) The comparison scales R to the game's span**:
  `python3 tools/fake_aging/m1_compare.py <reference-dir> <game-dir>
  --start <game's T0 dir> --profile <reference M3 profile> --span
  <HH:MM>-<HH:MM>`. The script dumps M1 twice: once after `inject`,
  before `fill` (the game's T0 state: the same data file and T0
  plantings as R's, so it stands for R's T0), and once at the read.
  For each judged measure the expected value is `T0 + s × (R − T0)`,
  `s` the share of R's inserted rows (`rows inserted/s, shop`, R's M3
  profile, its 24 hourly steps) falling in the game's span from its
  virtual T0 to the read, scenario time. Judged, within ±3 % of the
  expected value (the research's tolerance, `results-2026-11-15.md`
  Q1), or one row either way for a count under 34, where 3 % is less
  than a row (as built, rev. 2026-11-20): the measures inserts drive:
  each table's `n_tup_ins`, the sequences' `last_value`, the
  database's `tup_inserted`. Reported as `FIGURE` with their ratio to
  the expected value, never judged: each table's `n_live_tup` (rev.
  2026-11-20, D593: the estimate VACUUM and ANALYZE overwrite; run R's
  `daily_sales` reads 30 for 15 rows); the rest of Q1's list (updates, HOT
  updates, scans, bloat and dead tuples, transaction ages, order
  statuses, temp files), which f4's held transaction and f5's noon
  close in R move, and Q1's own known differences (`delivery_events`'
  bloat, `products`' transaction age, the `postgres` and `template1`
  activity, the ledger's last day). Why: insert-driven measures are the
  ones a share of R's own insert profile scales exactly; the rest
  depend on instances the game doesn't play.
- Without the archive: `SKIP`, exit 77, nothing judged (W1 item 3).

**3. The M3 profile and comparison** (chunk 12 writes; the script reads)

- `python3 tools/fake_aging/m3_profile.py dump <scenario-dir>
  --playground <pg> --handover <YYYY-MM-DDTHH:00Z> <out.json>` (the
  research's expressions, the database from `--database <db>`, where
  the research had `shop`) and
  `python3 tools/fake_aging/m3_profile.py compare <reference.json>
  <game.json>`. Both hand over at 14:00 scenario time, so step i is the
  same scenario hour (the research's alignment).
- **(choice) Only the hours the game's past holds**: the steps from its
  virtual T0 plus one hour to the last whole hour before the restart
  (the shop: 23:00 to 13:00, 15 steps); a step spanning the restart or
  the import is left out. Judged, per expression: Pearson correlation
  at least 0.95 and the ratio of means 0.95 to 1.05, on the traffic
  expressions (`calls/s`, `errors/s`, `commits/s`, `rows inserted/s`,
  `statements calls/s`): the research's 0.96 to 1.00 and "within 5 %"
  (Q4), rounded to a bound. Reported, not judged: `call p95` (f7's pool
  and f5's noon close in R), the size and resource gauges (database
  size, WAL, backends, CPU: R's afternoon growth; 9.9 fixes them against
  the game's own tail, which the seam judges), `series`.
- Without the archive: `SKIP`, exit 77.

**4. The seam and the import, as chunk 12 reads them** (chunk 10 built;
12 reads; W3 items 1 to 3, D581, D583)

- The script reads the record's `history {result: ok, seam: ok}` and
  `state.yaml`'s `history_import.attempts` (the figures), then runs
  `tools/gmctl history <dir> --playground <pg> --check-seam` once:
  exit 0 is the seam verdict (12.1's "a past present" is the `empty`
  finding). It never re-derives a finding.
- **(choice) A retention check**: Prometheus' lowest timestamp at the
  read within one minute of the virtual T0 (`FIGURE` right after the
  import and at the read). Why: G10.3 left a 13 to 15 h past's retention
  unmeasured, and the shop's and the campaign's are 16 h; a past cut by
  retention is a tell. W4-x records both figures.
- **f8's step** (the Verification line, D584, D585): over the forged
  past, `pg_database_size_bytes{datname="shop"}`'s last sample before
  f8's planting (08:00) less its first after it, against f8's `value`:
  within the larger of 1 % of `value` and the tail's own largest step
  **(choice**: D581's join tolerance; the drawn level moves far less
  than that between two scrapes).

**5. The short-game script: `tools/tests/smoke-fake-aging.sh`** (chunk 12
writes; the release gate item 3 calls it)

- **(choice)** `sh tools/tests/smoke-fake-aging.sh <scenario-dir>
  [--record]`; it knows two scenarios, by `scenario.yaml`'s `id`:
  `tarnbeck-outdoor-shop` and `tarnbeck-outdoor-campaign` (any other:
  exit 2). It plays the scenario as it is (its span, its data), never a
  copy: the setup's time it measures is the one the scenario document
  shows (item 8). Playground `fake-smoke`. Run under the host lock and
  the sleep inhibitor by the caller, as every run script; it takes no
  lock.
- **Its selection**, plan and 12.1: the shop f1, f2, f3, f6, f8, f9,
  f10; the campaign f1 to f4 and f7 to f9 (W3-y: f4 and f7 stay
  `supported`, no fallback). The rest through `render --test-leave-out`,
  the tail through `--test-tail-floor 15m` (both hidden options,
  `tools/gm/__init__.py:280-281`).
- **The start window (choice)**, as `run-history-test.sh:16-17`: H is
  the next whole hour; the anchor is H − 15 min; the script refuses to
  start, exit 3, nothing deployed, unless the setup's measured bounds
  (from the deploy to the fill's end, per scenario, constants in the
  script, W4-x records them) end before the anchor and the run ends
  under 30 minutes. Its refusal line names the window, e.g. `start
  between hh:MM and hh:MM`. No waiting option: the lock is never held
  idle.
- **Steps**, 9.4's and 12.1's order: `fit`, `render --aging fake
  --handover H` with the two hidden options, `deploy`, `load-data`,
  `inject`, M1 at T0 (the shop), `fill`, the wait to the anchor,
  `clean-restart`, `start-load`; then, in the tail: the start-time
  check (every service of the game, the monitoring's included, started
  within 10 s after `restart.at`, none before: 12.1's "the monitoring
  started with the rest"); the `player` account's
  `ls /var/lib/prometheus` refused on the Prometheus node (D540, through
  `gmctl exec --user player`); `gmctl history` by hand at
  `restart.at` + 12 min, as the timer would (W3 item 6: the timer's run
  after it is a no-op); the early check by hand right after it
  (`gmctl check --early-check`), reading every selected instance present
  and its history line `ok, seam ok`; a failure of the early check's
  own verdict whose masking names only instances the game left out
  (`(masked by ...)`, an instance `--test-leave-out` dropped, whose
  masking the answer key expects at the hand-over) a `FIGURE`, every
  other failure judged (rev. 2026-11-20); item 4's reads; the tells (item
  1); for the shop, M1 and M3 (items 2, 3) and f8's step; for the
  campaign, P0's invariants as chunk 11's B2 read them (W3-y:
  `rpt.close_day()`'s `proconfig` and `prosrc` md5 unchanged across the
  fill, the nightly close once at 01:30 scenario time and every hourly
  roll-up once at :05 in `rpt.etl_runs`); `gmctl status` and the
  restart record printed (release gate item 3 reads them there); the
  teardown, nothing labelled with the game's id left (on any exit, a
  trap). It does not wait for H **(choice**: every check 12.1 lists
  reads by the early check, H − 2 min; waiting for H would put the
  teardown past 30 minutes).
- **Figures** (`FIGURE` lines, the Done when's and the release notes'):
  the wall time from the script's start to the teardown's end; the
  setup from the deploy to the fill's end, the fill's duration, the
  clean-restart's, the deploy to `restart.at`; the setup time item 7's
  section shows, the deploy to `restart.at` less the wait for the
  anchor (rev. 2026-11-20); `gmctl history`'s duration and its
  `figures`; each key's median service time in the tail, as
  `calibrate.py keys` reads it, against its `service-times.yaml`, and
  each database node's WAL rate against its `wal-rate.yaml` (plan, spec
  D590; medians as built, rev. 2026-11-20). **The wall time is a
  check**: `FAIL` at 30 minutes or more (12.1).
- **`--record` (choice)**: also writes the output to
  `tools/fake_aging/calibration/<scenario id>-short-game-<YYYYMMDDTHHMMZ>.txt`,
  opening as every calibration file (the command, the commit, the start,
  the wall time; W3 item 10). Chunk 12 commits one per scenario; the
  release gate runs without it. Why: 9.7, every number the scenario
  document shows traced to a file.
- **Exit status**: 0 nothing failed (a `SKIP` for the archive counts no
  failure); 1 any failure; 2 usage; 3 outside the window.
- **Campaign figures read as measured** (plan, D578): a step in f1's
  `pg_stat_database_tup_inserted` at the seam is a `FIGURE` and a W4-x
  finding for v1.0 gating, never a `FAIL`; the tells read `pg_wal`
  against the padding only (item 1).

**6. `gauge_before` adds its value; f8's and the fixture's values**
(chunk 12 writes; the shop's game and `fixture-fill`'s history run read)

- The sum, the wording, the test case and `run-history-test.sh`'s new
  check are the plan's and formats.md v40's (D585); not restated.
- **f8's `value` from run R's reference first (choice)**: `calibrate.py
  gauge` on `r-dump/r.om`, the shop's size either side of R's planting
  (2026-11-15T02:00Z), its `# measured:` comment naming the member; a
  short run of the shop (`--record f8`) only if that read can't isolate
  the step. Why: R is the shop at its scale, already archived; a run
  costs a lock slot and a window (the plan leaves both open).
- f8's new entry selects `{DATABASE}`, a required parameter
  (`fault.yaml:56-59`): ISS-008 (an optional parameter left unset) does
  not reach it. ISS-007 touches no covered fault (D578): neither game
  meets it.

**7. The scenario document's "Fake aging" section** (chunk 12 writes;
chunk 16, the GM skill, the feedback and the release gate read)

- **Heading `## Fake aging`, unnumbered, after section 7 (choice)**: the
  literal heading W3 item 12 fixed and `SKILL.md:689-697` cites; last,
  since it is GM-side material about how a game may be run, not about
  the system. **Always present**, in every scenario document: the GM
  skill treats a document without it as stale (`SKILL.md:690-693`).
- **Its contents**, 9.10's per-scenario facts, from the authoritative
  files only:
  - a scenario without `aging:`: one line, "none: the scenario does
    not age, so it has no fake game", and nothing else;
  - the virtual span: `aging.minimum`, the virtual T0 at the designed
    hand-over (`aging.handover_at`) minus it, scenario time;
  - a table, one row per instance: instance, fault, support
    (`aging.fake.support`, or **"not assessed"** when the definition has
    no `aging.fake`), its tail needs (`tail_minimum`, `tail_covers`),
    `plant_in`, its reason (`aging.fake.reason`) and, when the
    definition's `gm.md` has one, a pointer to its `**Fake aging.**`
    note (W3 item 8);
  - the full selection: the tail and the anchor at the designed
    hand-over, by 9.6 as `render.fake_timeline` computes them (the shop
    3 h, anchor 11:00; the campaign 5 h, 09:00, W3 item 9), and the
    instances refused with their reasons; with any instance not
    assessed, "not assessed: no fake game of this scenario until every
    instance is" instead (9.5);
  - **the limits (choice)**: the rows of `cleanrestart.EXPLAINS`
    (`cleanrestart.py:72-109`, 9.10's table) that hold for the scenario
    by the same conditions (a Prometheus node, an archiving node, a
    cover in an instance's `fill.quiet`), each with the instances whose
    evidence in the answer key reads where it shows, or "none of this
    scenario's evidence". Why: the restart record's `explains` carries
    the same rows, so the document and the record never disagree;
  - **the setup's measured time (choice)**: from the newest
    `<scenario id>-short-game-*.txt` (item 5), the deploy to the
    restart, the wait for the anchor not counted, and the fill's
    duration within it, the file named; "not measured" without one. Why:
    D544 asks for a measured figure, and the newest record is the one
    the code as it stands produced.
- **Its inputs** join the skill's "When to generate or regenerate": the
  faults' `aging.fake` and `gm.md` notes, and the scenario's short-game
  records; a chunk changing one regenerates the documents that read it
  in the same commit (workflow deltas).

**8. An instance's `admitted:` in the scenario document** (chunk 12
writes; chunk 16 reads)

- In section 5, after the plantings' line, only when an instance has
  `admitted:`: "Admitted by a partner on its status page:", the table
  (instance, partner, title, `from`, `until` as written), then each
  one's text quoted, exactly as `fixture-v06-refusals/README.md:196-203`
  shows it (the plan's model). No **(choice)** here.

**9. The starter-pack line** (chunk 12 writes; chunk 16 reads)

- **(choice) Chunk 12 fixes it**: in `template.md:588-598`, "(v0.5; the
  true register, `gm/data-register.yaml`, stays GM side)" moves inside
  the "if: the bastion maps data-register.md" block. Why: chunk 12 owns
  the template in wave 4, and chunk 16's Out forbids changing it; a
  scenario without a register now names one it doesn't have.

**10. What chunk 16 and the release gate read; order and shared files**

- **Chunk 16** reads items 7 to 9 only: every fixture's document gains
  "Fake aging" (always present; "not assessed" for most fixture
  faults, "none: ... does not age" for fixtures without `aging:`), the
  `admitted:` table where an instance has one, the corrected
  starter-pack line. It starts once 12 and 14 have merged.
- **The release gate** reads item 5: the script's name, arguments, exit
  status, window and `FIGURE` lines (item 3 of the gate); items 1 to 4
  through the script's verdicts; item 7's section for "the limits
  documented where 9.10 says" (gate item 6).
- **Shared files**: none with chunks 5 and 14 (chunk 5's
  `node-health.json` seed files are no scenario document input, which
  names seed files by path only; chunk 14's fixtures and the root
  `README.md` are its own). Chunk 12's games deploy `grafana` 0.4.0 as
  the registry holds it; chunk 5's rebuild of it under the lock does not
  change what 12 checks.
- **Risk**: `gmctl history`'s GM-side memory for a 16 h past (W3-x: 732
  MB for 8 h in run 2, about double for 16 h; promtool about 590 MiB in
  an unlimited helper), on armenelos; W4-x records the peaks.

**Choices made here, not in the spec** (for the driver's review): the
shared form of the tools' output and exit status; the tells' arguments,
their 10 s start bound, 90 % `pg_wal` floor and the campaign's
autovacuum range; M1 dumped at T0 and scaled to the game's span by R's
insert share, judged on insert-driven measures within ±3 %, the rest
reported; M3 judged on the traffic expressions over the hours the past
holds (correlation 0.95, means within 5 %); the retention check; f8's
step tolerance; the script's arguments, scenarios, playground, window
and no wait, the check by the early check instead of H, the wall-time
check, `--record` and its file name; f8's value from R first; the
section's place, presence, limits from `EXPLAINS` and setup time from
the newest record; chunk 12 fixing the starter-pack line.

### Preflight corrections for spec-writer

1. **Chunk 12's split rule**: 12a as written holds two Docker runs with
   start windows (`fixture-fill`'s history run, the shop's game), four
   tools, the script, the sum and f8; 12b is light. Chunk 10's second
   owner spent about 140 calls on windows and lock waits (wave 3's
   record). Proposed: **12a** `gauge_before`'s sum, the `scenario-format`
   wording, `fixture-dropped-index`'s value and `fixture-fill`'s history
   run, f8's `gauge_before` (one Docker run); **12b** the four tools,
   `smoke-fake-aging.sh`, the shop's and the campaign's games and their
   records (`--record`), the two scenarios' `README.md` regenerated with
   the records (two Docker runs; after 12a for f8's step and after 12c
   for the section); **12c** the scenario document: the "Fake aging"
   section, `admitted:`, the starter-pack line, every scenario's
   `README.md` and the two fixtures' (no Docker; no file shared with
   12a, so it may run beside it). The scenarios' setup times read "not
   measured" until 12b's records land.
2. **Chunk 12's Done when, "the shop's M1 and M3 comparisons within the
   reference's tolerances"**: the reference states none, and R's span
   (24 h from 14:00, `run-2026-11-14.md`) and selection (ten faults)
   differ from the short game's (16 h from 22:00, seven). To read: "the
   shop's M1 comparison's judged measures within ±3 % of R scaled to the
   game's span, and its M3 comparison's traffic expressions within its
   bounds (capture W4 items 2 and 3)". Its Scope's M1 line gains the
   dump at T0.
3. **Chunk 12's Files**: `tools/fake_aging/calibration/` gains the short
   games' records, `<scenario id>-short-game-<stamp>.txt` (item 5), not
   only f8's file.
4. **Chunk 12's Scope: the starter-pack line** (handover for wave 4,
   "for chunk 12 or 16"): name it in chunk 12 (item 9), since chunk 16's
   Out forbids changing the template.
5. **Chunk 16's Scope**: every fixture's document gains the "Fake aging"
   section (item 7; all 32 with chunk 14's), beside the "Third parties"
   and "Composition" lists; its size grows by one table a fixture.
6. **The Release gate's item 3 and estimate**: the script runs in a
   start window (item 5, exit 3 outside it), so the second game waits
   for its next window: about 1½ hours for the two, not 60 minutes
   (estimate about 4 hours). Item 3's "the restart record and `gmctl
   status` read" are in the script's output.
7. **G10.4 after wave 4's gate** (none contradicts the spec; formats.md
   v40 doesn't carry them): the short-game record's name in "Fake
   aging's measured figures"; 9.10's per-scenario section's sources (the
   limits as `explains` holds them, the setup time from the newest
   record, the wait for the anchor not counted); the M1 and M3
   comparisons' judged sets and bounds if the spec is to name them
   (12.1 says only "against the saved real run").

### Questions for the owner (as drafted)

None. Every point above is settled by the spec, a capture, or a
correction `spec-writer` can make without changing how a game plays.
Correction 2 changes what the shop's M1 comparison proves (R scaled to
the game's span, not R as is); if the driver prefers the comparison to
stay span for span, the alternative is a copy of the shop with R's 24 h
span in the script, which costs about 3 more minutes of fill, the
30-minute margin and the setup time the scenario document shows.

### W4 reviewed by the driver; owner ruling on M1 — 2026-11-19

- Capture W4 drafted by a `coding-leader` (688b5c1, 57 tool calls),
  merged into the wave as e78e3f9. Its (choice) points are accepted as
  drafted. The extracted M1 files sit in the git-ignored
  `tools/fake_aging/reference/extracted/` of the removed capture
  worktree (gone with it).
- **Owner, on the M1 comparison** (W4 item 2, correction 2): "Scale R to
  span": the shop's M1 dumped at the virtual T0, expected T0 +
  s × (R − T0), insert-driven measures judged within ±3 %, the rest
  reported; the shop played as it is. For `spec-writer` to record as a
  decision with plan v15.
- Corrections 1 to 7 go to `spec-writer` for plan v15 (chunk 12 split
  in three: 12a, 12b, 12c).

### Chunk 14 — merged (edb11e8), 2026-11-19

- b659382 on `v0.6-c14-docs-overview-fault`, merged `--no-ff` as
  edb11e8. Done when met: `docs-overview-backup-claimed` (trap N5) passes
  `check_fault_dir`; `fixture-overview-fault` 16 passed / 0 failed in
  16 s (deploy 6 s), the instance planted, `overview_diff` in the answer
  key, `gmctl check --instance n5` reads present; `fixture-clinic-front`
  38 passed / 0 failed in 20 s (deploy 6 s): 7 documents, 76 internal
  links, nine status pages "Operational", a copied report listed with
  its sandbox header. Unit suite 1558 OK, 2 skipped (new
  `test_clinic_front.py`, 12 tests). No image rebuilt.
- Inside the chunk, no deviation: the bastion-only fixtures' true
  overviews have `entries: []` (the loader refuses entries for nodes
  outside the topology); `fixture-clinic-front`'s handouts are the
  clinic's with `{{customer_timezone}}` and credentials filled, kept
  equal by `test_clinic_front.py` (a regenerated clinic handout fails it
  until the copies are refreshed, deliberately); classes set to
  `locations: any`; no `aging:`; one bastion→bastion flow.
- For `spec-writer` (plan v15): the fault has no `aging.fake` (refused
  in a fake game, like the register fault), a one-line assessment if
  overview faults should be playable in fake games; the
  `scenario-document` template has no case for a true overview with
  zero entries (both fixtures' READMEs say "0 entries" beside a handout
  of 21 nodes), cosmetic, for 12c's template work.
- For the wave gate: `tools/tests/fixtures/fixture-clinic-front/run-short-test.sh`
  and `tools/tests/fixtures/fixture-overview-fault/run-short-test.sh`
  (release gate item 4), `bastion:0.6.0` only.
- Figures: 2 agents, 142 tool calls, 22.2M tokens in / 116k out, max
  context 289k, $8.69 at API prices.

### Plan v15 (a935a6d, merged 177a7d3); chunk 12a started — 2026-11-19

- `spec-writer` applied W4's corrections 1 to 7, none declined: plan
  v15. **D586**: the owner's "Scale R to span" (master spec 12.1
  amended). Chunk 12 split: **12a** (D585's sum, f8's measured
  `gauge_before`, `fixture-fill`'s history run; Docker light), **12b**
  (the four tools, `smoke-fake-aging.sh`, both short games, their
  records; Docker heavy; after 12a and 12c), **12c** (the scenario
  document: "Fake aging", `admitted:`, the starter-pack line, the
  zero-entries overview case, every scenario's README; no Docker).
  Chunk 16 now depends on 12c and 14 (not 12b), so it may run beside
  12b. G10.4 added (open). Release gate estimate ~4 h.
- Chunk 14's notes settled by the spec, no owner question: the overview
  and register faults stay not assessed (master spec 9.5, 9.8: no
  covered scenario uses them); the zero-entries case is in 12c.
- Chunk 12a dispatched from 177a7d3 beside chunk 5, branch
  `v0.6-c12a-gauge-before`. 12c takes chunk 5's slot.

### Chunk 5 — merged (da4bd14), 2026-11-19

- 6646829 on `v0.6-c5-grafana-node`, merged `--no-ff` as da4bd14 (on
  177a7d3, no conflict). Done when met: the `node` variable
  (`label_values(node_health_cpu_limit_cores, node)`, multi, "All" =
  `.*`, refreshed on time-range change); all 7 queries filtered
  `{node=~"$node"}`; the stack test opens `?var-node=<name>`, each
  query returns that node only, `no-such-node` returns nothing, "All"
  both nodes; the 8 seeded copies byte-identical to the companion.
  Grafana stack test 139 passed / 0 failed in 183 s (two test-only fixes
  on the way: no `/tmp` in the client image, panel 7's two series per
  node). Image build 15 s, from cache; Grafana 13.3.1 unchanged. Unit
  suite 1558 OK, 2 skipped.
- For G8 (at the gate, with any other image wave 4 rebuilds): the
  image's `dpkg-query` list (129 packages) saved at
  `/tmp/claude-1001/-home-bastien-work-db-audit-gm/e95c81d0-9133-4a5d-85a1-2bc7abccbc57/scratchpad/grafana-0.4.0-dpkg-query.txt`; no dependency changed.
- For the wave gate: a possible flake in the existing check "a data
  source pointing nowhere is a finding" (health still OK once, right
  after a provisioning reload; passed on runs 2 and 3); `bricks/grafana/brick.yaml`'s
  header comment still says the `node` variable "comes with its
  chunk" (stale, a one-line gate fix).
- Figures: 1 agents, 91 tool calls, 10.5M tokens in / 50k out, max context 167k, $3.91 at API prices.

### Chunk 12a — merged (303697f), 2026-11-19

- c1bcaf8 on `v0.6-c12a-gauge-before` (v0.6-w4 taken in first, 360e5be),
  merged `--no-ff` as 303697f. Done when met: `history.py`'s
  `gauge_overlays` adds `value` to the drawn level (a `None` base
  reads `value` alone); `test_gauge_before_adds_its_value` (test_history
  30 OK); the `scenario-format` skill and template word `value` as
  "what is added until the planting" (D585).
- `fixture-dropped-index`'s value **13213696** (order_lines_order_id_idx,
  1613 pages), checked equal to the run's FIGURE; the old
  `size_before == 202500000` check replaced by a step check: 13207587
  for 13213696, within 1 %, PASS.
- f8 (`pg-join-index-missing`) gains its `gauge_before` on
  `pg_database_size_bytes{datname="{DATABASE}"}`, value **14016512**,
  read from run R's `r-dump/r.om` (196531903 at 01:59:55Z, 182515391 at
  02:00:10Z; neighbours move 0 to 32768 bytes): W4 item 6's choice held,
  no shop run, no calibration file.
- `fixture-fill`'s history run, once, in its window (17:38:03), under
  the lock: 39 passed / 0 failed, **1326 s** with the deployment
  (deploy + load-data + inject 31 s; fill 233 s for 466 virtual min;
  clean-restart 26 s; `gmctl history` 69 s; restart.at 14 s after the
  anchor; lowest timestamp 3 s after the virtual T0). Unit suite OK
  (2 skipped), before and after taking the wave in.
- For 12b: f8's step over the shop's own forged past (W4 item 4's
  tolerance). f8's `fault.yaml` is an input of the shop's answer key and
  README: 12c regenerates it after taking the wave in (its brief says so).
- For W4-x: f8 14016512 (R), `fixture-dropped-index` 13213696 (run),
  forged step 13207587.
- Figures: 1 agents, 55 tool calls, 5.5M tokens in / 31k out, max context 134k, $3.35 at API prices.

### G8 — done (19c67f1, merged 3a7ac22), 2026-11-19: CLEAR WITH NOTES

- `security-advisor` checked `grafana` 0.4.0 (dpkg list equal to chunk
  5's, Grafana 13.3.1 still the newest, its SBOM findings unchanged) and
  the ten images wave 3's gate rebuilt `--no-cache --pull` (every
  version `.tech` records still holds; Debian 13.7). Nothing wave 3 or 4
  changed brought a finding. `.tech` updated (`cve-watch lint` 0;
  `cve-watch check` 75 findings, as at G9.1).
- Notes, none reachable here:
  1. **zlib1g** `+deb13u1` (DSA-6613-1) in all ten images: it comes from
     the `debian:13-slim` layer (Hub digest unchanged since 2026-11-04)
     and no Dockerfile upgrades it, so `--no-cache` does not pick it up;
     only an `apt-get upgrade` or naming `zlib1g` would. Gzwrite is not
     used. Batch (release gate or v0.7).
  2. **nginx** deb13u11 (DSA-6642-1, today 14:40 UTC, 9 CVEs) in
     `bastion` 0.6.0 and `health-check` 0.1.1: each CVE read against both
     configs, none reachable (no mail, TLS listener, stream, HTTP/2-3,
     SSI/mirror, regex-capture map).
  3. **PGDG moved on 2026-11-17**: libpq5 19.0 in `trixie-pgdg main`
     (18.x in component `18`), postgresql-18 18.7-1.pgdg13+5 (a
     non-security rebuild), postgresql-common 297. A fresh build would
     give `postgres` libpq5 19.0 and server/client +5; `bastion` libpq5
     19.0, client-18 +5, nginx u11; `pgbouncer` libpq5 19.0 and
     **postgresql-client-19** (the unpinned metapackage), make and guile
     through postgresql-common-dev; `health-check` nginx only.
- The gate's rebuild policy is an owner decision before the gate (see
  below). Whatever the gate builds, each rebuilt image's `dpkg-query`
  diff goes to `security-advisor` for a G9.2 check.
- Context: `security-2026-11-14` (on hold) carries 29 `[[ignore]]`
  entries `v0.6-w4` lacks; some `SECURITY_TODO.md` lines say "accepted"
  ahead of that merge. c-ares was closed at G9.1 (3768038).

### PostgreSQL 19 — the owner's ruling, G9.2's preflight, plan v16 (66169ba, merged 184316a); G14 — 2026-11-19

- Asked how the gate should rebuild after G8 (pin 18 / accept 19
  client-side / cached), the owner: "didn't know pg19 was out yet.
  that's great news. Move to pg19 everywhere." zlib1g: release gate.
- `security-advisor`, G9.2 preflight: CLEAR WITH NOTES (no advisory
  on any candidate). Picks: postgresql-19 / client-19 / libpq5
  19.0-1.pgdg13+1; pg_cron 1.6.8-1.pgdg13+3 (the only build `>> 19~rc2`);
  pgaudit 19.0-1.pgdg13+1; postgresql-common 297; postgres_exporter
  0.21.1 and pgwatch 6.2.0 (clear the accepted Go findings); libpq 19
  for `scheduler`, `api`, `health-check` from PGDG `main` through a key
  stage, asserted at build. Notes: exporter 0.21's flags and labels,
  pgaudit 19's logging (four faults rerun), changed server defaults, 18
  data directories don't start on 19. Full text kept in the driver's
  scratchpad (`g92-preflight.md`), passed to `spec-writer`.
- `spec-writer`, plan v16: **D587** (19 everywhere, D539's pgAudit
  wait ended), **D588** (zlib1g at the release gate), **D589** (chunk 17
  inserted, split 17a/17b/17c; G9.2, G14, G15), **D590** (18's figures
  stand; `fixture-dropped-index`'s size re-measured on 19; 18-vs-19
  ratios reported in 12b, never judged). No brick bump: master spec 6.8
  folds a change into an unreleased version (G14 covers the reused
  tags). **O294** (pgBadger 13.3 drops 19's checkpoint lines), **O295**
  (autoanalyze no longer logged by `log_autovacuum_min_duration` on 19,
  56 seeds) for the owner, G15; O296 never used.
  - 17a (heavy): the images, paths and tests on 19, one commit; beside
    12c, merges after it.
  - 17b (heavy): exporter 0.21.1, pgwatch 6.2.0, the size re-measured.
  - 17c (light): 19 in the game's text, the pgaudit faults rerun, O294
    and O295 as ruled.
  - Then 12b beside 16 (12b after 17b and 17c; 16 after 17c).
- **G14** (driver's hand check, before 17a's first build): `docker stack
  ls` empty, no service but `ollama`; the only local implementation,
  `tarnbeck-outdoor-shop/local/fa-real`, is `torn-down` with no
  snapshot. Cleared.
- Inserted chunk's checks: no intent register (no `documentalist`
  peek), no data register; G9.2's preflight done.

### Plan v17 (a775891, merged 314a16f); chunk 17a rotated — 2026-11-19

- Owner on G15: O294 "Known limit" (**D591**), O295 "Add the new
  setting" (**D592**). G15 done; chunk 17c states both as settled.
- Chunk 17a's first owner stopped at the rotation bound: WIP 5428aeb.
  postgres on 19 (pins asserted), stack test 317 / 0 in 7m38s; bastion,
  pgbouncer, scheduler, api, health-check rebuilt `--no-cache` on 19
  (libpq5 19.0-1.pgdg13+1 in each, no 17 or 18 package); every 18 path
  moved; the clinic's crontabs, overview and digests updated; unit suite
  OK. Findings for G9.2's post-change: postgres, bastion, pgbouncer keep
  Debian's postgresql-common 278 (installed before the PGDG source);
  `.tech` still says 18. `domains/vet-scheduling/data/schema.sql:31`'s
  "postgresql-18" comment left to 17c. A second owner resumed from
  5428aeb (nine stack tests, the two unit runners, the smokes, the
  clinic's README after 12c, the merge).

### Chunk 12c — merged (ee98c68), 2026-11-19

- c53b0d1 (rebased on 314a16f), merged `--no-ff` as ee98c68. Done when
  met: `## Fake aging` last in all five scenario READMEs and
  `fixture-status`'s and `fixture-v06-refusals`' (bookshop, fernway:
  "None"; aldermoor and fixture-status: "not assessed"; shop tail 3h,
  anchor 11:00; campaign tail 5h, anchor 09:00, f10 refused
  `real-only`; tails and anchors from `render.fake_timeline`; limits
  from `cleanrestart.EXPLAINS` under their design-time conditions;
  setup time "not measured" until 12b). `admitted:` shown;
  `fixture-v06-refusals` fully regenerated (four template drifts fixed);
  the starter-pack line inside the register condition; the
  zero-entries overview case in the template (16 applies it). A second
  render changes nothing. Unit suite 1558 OK, 2 skipped.
- Choices recorded in the skill: the evidence-to-limit table (one row
  per `EXPLAINS` row); the section as the template's fourth exception
  to "read only `scenario.yaml` and the answer key"; template labels
  moved to v0.6; admitted texts quoted in instance order with no
  instance label (an owner-visible nicety, not needed for v0.6).
- For 12b: the shop's and campaign's READMEs regenerated in the same
  commit as the short-game records. For 17a: the clinic's README
  regenerated on top of this merge.
- The owner's wait loops (`pgrep -f` matching itself) kept it idle
  after its suite; killed on the driver's status check.
- Figures: 1 agents, 76 tool calls, 10.8M tokens in / 53k out, max context 207k, $5.01 at API prices.

### Chunk 17a — merged (b788df5), 2026-11-19

- aff0b4d (second owner, from WIP 5428aeb), merged `--no-ff` as b788df5
  on top of dc1420b (12c in, no conflict). Done when met: six images
  `--no-cache` on 19 (libpq5 19.0-1.pgdg13+1 everywhere, no 17/18
  PostgreSQL package left); ten stack tests green (postgres 317,
  bastion 136, pgbouncer 121, scheduler 179, api 89, health-check 97,
  postgres-exporter 104, pgwatch 73, prometheus 132, grafana 139 PASS);
  unit suite 1559 OK, 2 skipped; scheduler (113) and api unit runners
  in their images on 19.0; eight smokes green, each under 30 minutes;
  the clinic's README's three "overview beside it" lines now read 19,
  12c's sections untouched.
- Paths beside capture W4: data `/var/lib/postgresql/19/data`,
  binaries `/usr/lib/postgresql/19/bin` (17b, 17c, 12b read them).
- To G9.2's post-change check: postgresql-common 278 (Debian) in
  postgres, bastion and pgbouncer (first `apt install` before the PGDG
  source); health-check has 297.pgdg13+1. dpkg lists in the driver's
  scratchpad `c17a/dpkg/`.
- To 17c: `domains/vet-scheduling/data/schema.sql:31` ("postgresql-18"
  comment, a digest input) and `scenarios/tarnbeck-outdoor-shop/README.md`
  line ~650 ("PostgreSQL 18's wording" of the autovacuum log line, from
  the answer key).
- Figures: 3 agents, 160 tool calls, 17.8M tokens in / 72k out, max context 186k, $7.20 at API prices.

### Chunk 17c — merged (270d883), 2026-11-20

- Commits d9a7b86 (the game's text on 19, D591) and e1c2e3b (D592:
  `log_autoanalyze_min_duration = 0` in all 56 seeds); merged --no-ff,
  no conflicts. Branch deleted.
- Evidence: fixture runs on 19, all green: `fixture-lab` /
  pg-monitoring-option-absent 19/0 (22 s); `fixture-portal-scope` /
  security-policy-ownership-end-dropped 20/0 (374 s); `fixture-reports`
  planted / governance-statement-log-personal 24/0 (685 s);
  `fixture-reports` planted / purpose-herd-use-dropped 32/0 (739 s from
  deployment; 3016 s lock-to-end includes the test's own 2276 s idle wait
  for T0 at :10 local). Postgres stack test 317/0 (484 s). Unit suite 1559
  OK, 2 skipped. Loader passes on all 39 scenarios and fixtures.
- VACUUM (VERBOSE) and autovacuum wording read on 19.0: unchanged from
  15-18; `scheduler-transaction-held-open`'s gm.md and the shop's answer
  key say so; shop README regenerated.
- D591 named in postgres' `docs/gm.md` ("Logging"), quoting 19's
  checkpoint line. For the release notes: pgBadger 13.3's Checkpoints
  section is empty on PostgreSQL 19; the next pgBadger that reads 19's
  lines is taken under D396.
- Generated files: clinic's and `fixture-clinic-front`'s overview digests
  re-recorded (entries unchanged); only the shop's scenario document
  regenerated. 17b merges second, so it regenerates the clinic's overview
  and README on the merged inputs.
- **Open, for spec-writer at G10.4 (predates this chunk, not about 19):**
  no played scenario or fixture loads pgaudit in its seed
  `shared_preload_libraries` (only postgres' stack-test seeds and
  `fixture-composed` do). vet-lab's and vet-portal's `policy.md` and the
  domain notes describe pgaudit as on (`write, ddl, role`; traps T2,
  T251), so those traps can't bite in the clinic as built. The four
  pgaudit-reading faults reach it only through the `SET pgaudit.log =
  'none'` guard, which 19.0 accepts as a placeholder. No content changed.
- Also noted: the grid's sampling block's `CREATE TEMP TABLE` fails in
  the read-only session the grid itself prescribes (predates the chunk).
- For the wave gate: existing scenarios' smokes with the D592 seeds.
- Figures: 1 agents, 166 tool calls, 26.5M tokens in / 76k out, max context 227k, $7.81 at API prices.

### Chunk 16 — merged (d24715c), 2026-11-20

- Commits 5d37c7f (16a: `fixture-alias` to `fixture-load`) and 7860234
  (16b: the rest); merged --no-ff, no conflicts. Branch deleted.
- Evidence: 34 fixture scenario documents from chunk 12c's template (32
  regenerated, 12c's two byte-identical); checked by script for the
  warning, "Fake aging" in every one, "Third parties" and "Composition"
  wherever their keys are, `admitted:` tables, "Data register", no
  placeholders left; a second run reproduces all 34 byte for byte. Unit
  suite 1559 OK, 2 skipped. Only `tools/tests/fixtures/*/README.md`
  changed.
- Method: no generator exists in the repo; the owner applied the
  template with an uncommitted script (scratchpad `gen/scendoc.py`,
  `apply.py`, `run.sh`), validated on the five scenarios and 12c's two
  fixtures. `run.sh` regenerates every fixture document (for 17b if it
  changes `fixture-fill` or `fixture-clinic-front` inputs).
- **Open, for spec-writer at G10.4 (the template, capture W4 items
  7-10; information some fixture documents carried by hand is now
  gone):**
  1. node keys `options:` (9 fixtures) and `standby_of:` have no place
     in the template; aldermoor-centre's document invents "Options" and
     "Standby of" lines; `fixture-monitoring-v05` and `fixture-reports`
     lost them;
  2. "Column classification" handles only `domain:`; a `domains:`
     scenario gets "the scenario's own" (`fixture-register`,
     `-clinic-load`, `-archive` lost richer wording);
  3. nothing says which database each composed domain loads into except
     the Composition table's "At"; "Restored-backup data" reads "none."
     where data comes only from domains;
  4. no wording for an empty pg_cron jobs table (kept the existing
     "— | none | … | nothing scheduled in the baseline" row);
  5. owner's calls on ambiguities: totals at the end of the placement
     table; scenario-only bricks/faults kept in existing order; the
     starter-pack line's ", and the data policy"; `cron.schedule` jobs
     listed as postgres in `cron.database_name`.
  Also seen in `scenarios/*` (out of scope): aldermoor-centre lists s6
  under the vault limit though its evidence reads the data register;
  bookshop-new-server writes one total as "2.25G".
- Figures: 1 agents, 75 tool calls, 12.9M tokens in / 85k out, max context 253k, $5.39 at API prices.

### Chunk 17b — merged (a2dbe23), 2026-11-20

- Commit 741751c; v0.6-w4 taken in twice (17c, then chunk 16 as
  8ef9d21), generated files regenerated on the merged inputs; merged
  --no-ff. Branch deleted.
- Evidence: `postgres-exporter:0.2.1` (0.21.1, sha256 02f316da…) and
  `pgwatch:0.1.1` (6.2.0, sha256 8c61a80e…) built --no-cache with
  version-banner checks. Stack tests on 19: exporter all pass (101 s;
  first run failed on the owner's own `datname` check, fixed), pgwatch
  all pass (250 s; `basic` preset on 190000; 13.5 MiB at rest, peak
  23 MB). SBOMs regenerated (34 and 46 components), `go-sbom check` and
  `test_go_sbom` pass. `fixture-fill` short test 65/0 (889 s, pre-merge
  tree); history run 39/0 (1412 s, merged tree). Unit suite 1559 OK, 2
  skipped; `test_planted` green after chunk 16.
- Index size on 19 (D590): `order_lines_order_id_idx` 13213696 bytes,
  exactly 18's; f8's 14016512 stands; gauge_before read 13207980. No
  fault, calibration or shop README change.
- Generated: the clinic's overview (four exporter entries now 0.21.1,
  pgwatch 6.2.0, `brick.yaml` digests), the same five lines in
  `fixture-clinic-front`'s and `fixture-overview-fault`'s handouts;
  clinic README unchanged; chunk 16's `scendoc.py` reruns change
  nothing.
- dpkg lists for G9.2's post-change check:
  scratchpad `c17b/dpkg/postgres-exporter-0.2.1.txt`,
  `c17b/dpkg/pgwatch-0.1.1.txt`. The exporter 0.20.1 ignores live only
  in `.tech`: post-change check.
- **Beside W4, the exporter on 0.21.1** (12b's tells and the history
  read these): started as `env -i PATH DATA_SOURCE_USER=<user>
  postgres_exporter --datasource.uri=<from exporter.conf>
  --datasource.pass-file=/opt/gm/secrets/monitoring_password
  --web.listen-address=:9187 --web.telemetry-path=/metrics
  --config.file=/usr/local/lib/gm/postgres_exporter.yml <collectors>`;
  `exporter.conf` keys unchanged; no `--auto-discover-databases`, no
  `--wrap-large-counters`, `--web.max-requests` default 40. Same 15
  default collectors; database-scoped ones reach `postgres` only
  (checked: 25 sessions all in `postgres`, no series for a second
  database). Label changes: `stat_replication` gains `pid`;
  `statio_user_indexes` gets `datname` only under discovery (not here);
  new `pg_settings_pending_restart{name}` = 1 while a setting waits for
  a restart (a possible tell when a player or fault only reloads). A
  collector failing mid-scrape drops all its metrics. No counter family
  changed: `history.py` untouched. `fill.py`'s `EXPORTER_SQL` replays
  0.21's session setup, slot columns, `pg_stat_replication.pid`,
  `pg_settings.pending_restart` (`test_fill` asserts it).
- Deviation, for spec-writer at G10.4: the chunk and G9.2 say
  `statio_user_indexes` "gains `datname`"; it does only under discovery.
  Docs and stack test state it; no code path changes.
- Outside Files, to keep docs true: `bricks/pgwatch/docs/player.md`
  (6.1 → 6.2), comments in pgwatch's `pgwatch-sources`, its test
  `sources.yaml`, the exporter's s6 `run`. Left: `bricks/grafana/docs/
  gm.md:135` still says "pgwatch 6.1.0" (wave gate fix);
  `fixture-monitoring-v05`'s comment (frozen v0.5 fixture).
- For the wave gate: `fixture-fill` short test on the merged tree (17c's
  D592 seeds, chunk 16).
- Figures: 1 agents, 128 tool calls, 22.8M tokens in / 68k out, max context 242k, $12.26 at API prices.

### G9.2 post-change check — done (cf059a3, merged ec352a1), 2026-11-20

- `security-advisor`, own branch from 0e11541; one commit (`.tech`),
  merged --no-ff by the driver, branch and worktree removed.
- Verdict CLEAR (with notes). Introduced: none. Fixed: 35 open
  SECURITY_TODO.md Go items (34 from the exporter 0.20.1 build, plus
  GO-2026-6809 shared with pgwatch); the sweep ticks them once v0.6-w4
  reaches main. PostgreSQL/libpq/psql 19.0-1.pgdg13+1, pg_cron
  1.6.8-1.pgdg13+3 (CVE-2026-6460 build), pgaudit 19.0-1.pgdg13+1,
  exporter 0.21.1, pgwatch 6.2.0: no advisory. Exporter keeps
  GO-2026-5932 (x/crypto/openpgp), not linked in the binary
  (pre-existing).
- `postgresql-common` 278: acceptable, no move. postgres and bastion
  had it since v0.4; only pgbouncer changed (295 → 278). PGDG's
  postgresql-19 needs >= 275~; 278 has no open CVE; 279–297 carry no
  security fix; no brick runs pg_createcluster/pg_ctlcluster/
  pg_upgradecluster. Moving to 297 is optional parity only.
- `.tech`: PostgreSQL 18.7 → 19.0 over six bricks (libpq/psql 17.12
  entry merged in), pg_cron/pgaudit sources, check_postgres over psql
  19, exporter 0.21.1, pgwatch 6.2.0, nginx deb13u11 (DSA-6642-1 fixed),
  OpenSSL note. `cve-watch lint` exit 0.
- No ignore removed or added: the preflight's "exporter 0.20.1 ignores"
  were open SECURITY_TODO.md items, not `[[ignore]]` entries (the
  preflight's wording was wrong).
- Pre-existing, not from this change, for the release gate:
  - zlib1g still +b1 everywhere: D588's two CVEs plus CVE-2026-76844
    (7.4), all fixed by +deb13u1; stays under D588. *Corrected
    2026-11-20 (G9.3, D588): CVE-2026-76844 is not zlib's (Debian:
    NOT-FOR-US, a webpack-dev-middleware flaw OSV misattributes).*
  - OpenSSL 3.5.7-1~deb13u3: 10 CVEs open in trixie (published
    2026-11-10 to 11-18, no DSA yet; QUIC, DTLS, AES-GCM-SIV, CMS, PEM,
    DANE, Suite B); NVD hasn't matched them, so the sweep hasn't raised
    them; at first sight none on a path a brick serves. A vuln-triage
    pass when they surface; recheck at the release gate.

### Chunk 12b — stopped for rulings (WIP c14d445), 2026-11-20

- Built on `v0.6-c12b-fake-aging-games` (worktree kept): the four tools
  in `tools/fake_aging/` (from research 10d1bc6, generalised, W4's
  PASS/FAIL/SKIP/FIGURE form, exit 0/1/2/77) and their README;
  `tools/tests/smoke-fake-aging.sh <scenario-dir> [--record]` (playground
  `fake-smoke`, exit 0/1/2/3, refuses outside its window: shop
  hh:31:00–hh:35:00, campaign hh:31:00–hh:39:30); two records; both
  READMEs' setup-time line (campaign 4 min 6 s; shop 8 min 43 s).
- Runs (each under the lock, in its window): campaign 1 61/1 (1558 s; an
  extra check of the owner's on a left-out instance's masking, since
  reported not judged); **shop 55/5 (1546 s)**; **campaign 2 64/0 (1674
  s), the committed record**. Unit suite 1559 OK. No campaign instance
  dropped (f1–f4, f7–f9 all `supported`).
- Shop: f8's step met (14008827 for 14016512, tolerance 161808); every
  `n_tup_ins`, `last_value`, `tup_inserted` within ±3 % of R scaled
  (s = 0.5604). The five failures:
  1. M1 `daily_sales.n_live_tup` 15 vs 23.4 (R's 30 for 15 inserts) and
     `delivery_events.n_live_tup` ×1.040: an ANALYZE estimate, the owner
     proposes dropping it from W4 item 2's judged set;
  2. M3 `commits/s` mean ×1.18 (night 1.07/s vs R 0.60); M1
     `shop.xact_commit` ×1.95 (reported only): suspected `fill.py`
     `run_steps`'s `set_clock` committing once per call (scheduler brick,
     outside 12b's Files);
  3. M3 `statements calls/s` mean ×0.851 (night 1.44 vs 2.3), cause not
     found;
  4. tells: `autovacuum public.customers` 1 run for 57018 updates vs 4.9
     expected (1.45–10.8).
- FIGURE findings (never judged, for v1.0 gating): tail service times
  outside ×0.8–×1.25 for many keys (cold caches after the restart, plus
  19 vs 18 files); tail WAL shop ×1.07, campaign `db` ×2.13–2.57
  (full-page writes after the restart's checkpoint), `reporting` ×0.14;
  campaign f1 at the seam ×1.00–1.03 (no step); retention holds; history
  import memory peak 1.0–1.2 GiB.
- As-built deviations to fold into W4 when it's revised: M1 "or one row
  either way for a count under 34"; the tells' autovacuum upper bound
  counts all dirtied rows; `stats-reset` within 120 s before
  `restart.at`; service times as medians (`calibrate.py keys`) not
  means; `--reference` refused for scenarios other than the shop; setup
  time excludes the wait for the anchor; an early-check failure caused
  by a left-out instance's masking reported, not judged.
- Risk: each game's wall time is 26–28 min; a slower host could cross 30.
- Next: a read-only diagnosis of failures 1–4 (dispatched), then
  rulings (spec-writer, the owner where a judged set changes), then a
  fresh owner resumes from c14d445: shop rerun with `--record`, the
  0133Z record replaced, squash, merge.

### Wave gate, first pass (all but 12b's games) — green, 2026-11-20

- `coding-executor`, 04:04–06:46 CET on armenelos, one item at a time
  under the lock and inhibitor, each under 30 min. Logs:
  scratchpad `gate4/logs/`, `gate4/results.txt`.
- Fixes: 3017cf8 (grafana `brick.yaml`'s stale header comment; the
  clinic's overview digest line for it), 9b45eba (grafana `docs/gm.md`
  names pgwatch 6.2.0).
- Unit suite 1559 OK (382 s); scheduler unit 113 OK; api unit 36 OK;
  `sh -n` 349, `py_compile` 485, `perl -c` 14 files.
- Ten builds `--no-cache --pull` (197 s), Debian 13 on 10/10. Stack
  tests on 19, all 0 failed: postgres 317 (450 s), bastion 136 (95 s),
  pgbouncer 121 (173 s), scheduler 179 (838 s), api 89 (196 s),
  health-check 97 (169 s), postgres-exporter 112 (103 s), pgwatch 74
  (252 s), prometheus 132 (78 s), grafana 139 (201 s; "data source
  pointing nowhere" passed first time, no flake seen).
- Smokes: `smoke.sh` 61/0 (31 s), `smoke-monitoring.sh` 43/0 (48 s),
  `smoke-governance.sh` 121/0 (109 s), `smoke-load.sh` 73/0 (378 s).
  Scenario short smokes: bookshop 19/0 (22 s), fernway 18/0 (30 s), shop
  26/0 (841 s), campaign 33/0 (317 s).
- Fixtures on the merged branch: `fixture-fill` history 39/0 (1396 s;
  index 13213696 = the fault's value, step 13208585, fill 224 s for 466
  virtual min, promtool peak 625 MiB); `fixture-fill` short 65/0 (836 s;
  exporter sessions 3790 vs 3780); `fixture-overview-fault` 16/0;
  `fixture-clinic-front` 38/0 (76 links, none dead); `fixture-lab` 19/0;
  `fixture-portal-scope` 20/0 (352 s); `fixture-reports` s7 24/0 (649 s),
  s3 32/0 (767 s, no idle wait).
- dpkg: all ten lists identical to their last builds (c17a, c17b, G8):
  PostgreSQL 19 alone everywhere; no G9 row needed.
- Left: 12b's two short games after 12b merges, plus reruns of whatever
  the inserted fill/history chunk touches (scheduler build and stack
  test, unit suite, `fixture-fill` short and history).

### Chunk 12b's rulings — 2026-11-20

- Diagnosis (read-only `coding-executor`): scratchpad
  `c12b/diagnosis.md`. 1: `n_live_tup` is a VACUUM/ANALYZE estimate (R's
  `daily_sales` 30 for 15 rows from its load's late counter flush). 2
  and 3: M3's commits ×1.18 and statements ×0.851 come from
  `tools/gm/history.py` scaling every counter by one load ratio clamped
  at 0.25 (history.py:64, :298, :541): a flat night plateau at 25 %
  while calls drop to 17 %, and the scraper's own queries slowing at
  night: a DBA-visible tell. `set_clock`'s extra commit per call
  (fill.py:474-475, :578) explains M1 `xact_commit` ×1.95 but not M3;
  report only. 4: the tells' autovacuum rule counts the load's 20000
  updates and close-day's one bulk statement as per-row updates;
  corrected, 3.7 expected (band 0.85–8.4), observed 1 passes.
- **Owner, 2026-11-20:** (1) "Report only": `n_live_tup` leaves M1's
  judged set and is reported (master spec 12.1 reworded). (2/3) "Fix
  a+b+c now": an inserted chunk before 12b resumes: (a) per-series
  drivers in `history.py` (the scheduler's roles and databases follow the
  load, the rest stay flat), (b) the 0.25 floor removed, (c) the fill
  records its transactions per minute per database as the shape of
  `pg_stat_database_*` (scheduler image rebuilt).
- Driver's call (no ruling needed): 4 is a tells-rule correction inside
  12b's own files (updates from T0, one run per bulk statement), folded
  into W4 with 12b's other as-built deviations; the residual reported.
- Sent to `spec-writer`: the rulings, master spec 12.1, the inserted
  chunk, W4's revision, 12b's dependency.

### Plan v18 (bd194b6): chunk 18 inserted — 2026-11-20

- `spec-writer` recorded D593 (owner: `n_live_tup` reported only; 12.1
  reworded, one row either way under 34), D594 (owner: the forged past's
  counters follow what drives them; `set_clock` report-only), D595
  (chunk 18 placed in wave 4; two readings below), D596 (W4 items 1, 2, 5
  revised as 12b built them, the corrected autovacuum rule; all seven
  as-built deviations accepted). 9.9 gains fix 12; 9.10 unchanged.
  O297 reserved by `doc-ids next`, unused.
- **Chunk 18** ("The forged past's counters follow what drives them"):
  (a) per-series drivers in `history.py`, (b) the floor removed, (c) the
  fill's per-database transactions per virtual minute as the shape of
  `pg_stat_database_*`; scheduler 0.4.0 rebuilt; depends on 8, 10, 12a,
  17b; 12b depends on it. Runs alone (Docker heavy).
- D595's readings, for the owner's nod in the wave report: the `user`
  label decides before `datname` (else the monitoring's queries in a
  scheduler database would keep the night tell); a series with neither
  label (host, WAL, checkpointer) keeps following the load (flattening
  it would be a new tell).
- Driver's call: 12b's resume reruns **both** games with `--record` on
  the post-18 tree (the campaign's 0231Z record predates 18's fill),
  and those runs stand as the gate's two-games item if nothing else
  changes after.

### Chunk 18 — merged (11ad762), 2026-11-20

- Commit 9767de6, merged --no-ff (wave branch unmoved). Branch deleted.
- Built: (a) `Composer.driver` in `tools/gm/history.py`: `user` decides
  first (scheduler role → load, other → flat), then `datname` (scheduler
  database → load, other, e.g. `postgres`, → flat), neither → load;
  scales counters, activity gauges and size ramps; overlays and
  signatures unchanged; roles/databases from each scheduler node's
  rendered `schedule.yaml`, exporter `instance` → `host:port` from
  `exporter.conf`. (b) `SHAPE_RATIO` (0.02, 4.0): today's nights run
  0.14–0.17, so it never binds. (c) `fill.py` records
  `fill_transactions` per virtual minute (`{"host:port/database":
  cumulative}`, a pooler session keyed by its server): one per
  transaction plan, else one per step (failed included); a script's
  commits/rollbacks plus one for a transaction open at close; not
  `set_clock`, session set-up or the exporter. `pg_stat_database_*` takes
  its shape from it over the tail's commits+rollbacks, ahead of (a);
  falls back to (a) without it. Never served or forged as a series.
- Evidence: `test_history` 37 OK (new `TestDrivers`, `TestFillDrivers`);
  scheduler unit 117 OK with the replay guard (224 s); scheduler 0.4.0
  `--no-cache --pull` build, Debian 13, dpkg identical to gate4's (no G9
  row); stack test 179/0 (834 s); `fixture-fill` short 65/0 (851 s; fill
  461 s for 929 virtual min; exporter 3726 vs 3716); history 39/0 (1416
  s, in window; drivers load 900, flat 276, transactions 24; seam ok;
  promtool 551 MiB; index step 13207583 for 13213696). Unit suite 1567
  OK (384 s), then one report-only `history.py` change with
  `test_history` rerun green. These stand as the gate's post-18 reruns.
- For G10.4 (the owner's readings): (c)'s denominator is the tail's
  commits + rollbacks on that database; scripts counted by their
  commits/rollbacks; the key's `host:port/database` form and the
  exporter mapping; the per-database shape smoothed and bounded like
  the load shape (15 min, `SHAPE_RATIO`).
- Risks: a script using psycopg's `conn.transaction()` blocks would go
  uncounted (none today); non-scheduler transactions on a scheduler
  database in the tail scale the forged rate slightly.
- Not measured here: the M3 predictions (statements ×1.0, commits
  ×1.0); 12b's reruns judge them.
- Figures: 1 agents, 90 tool calls, 18.0M tokens in / 71k out, max context 259k, $8.68 at API prices.

### Chunk 12b (resume 2) — stopped on a judged failure (WIP 713fbcf), 2026-11-20

- Branch rebased as 56c3f3b (as-built tools on e04b5b3, research origin
  10d1bc6 named; 0133Z/0231Z records removed) + WIP 713fbcf (records
  0931Z shop (failing), 1031Z campaign; campaign README setup line).
- Resume work: `m1_compare.py` judges `n_tup_ins`, `last_value`,
  `tup_inserted` only (`n_live_tup` FIGURE, D593); `tells.sh`'s
  autovacuum rule per D596 with a new `--start <game T0 M1 dir>`
  argument (goes with `--reference`; W4 item 1's usage line lacks it:
  for W4-x / G10.4); offline check on the old run: 3.74, 0.87–8.5.
- Unit suite 1567 OK on the merged tree.
- **Shop 09:31Z: 52/2, 1660 s.** Fill 476 s; setup 519 s (832 s with
  the anchor wait); history 77 s, promtool 1027.5 MiB; M1 10/0; tells
  10/0 (customers 2 runs vs 3.8, band 0.90–8.6); f8's step 14008635 for
  14016512 passes. M3: calls ×0.985, errors ×1.01, **statements ×0.986
  (chunk 18's prediction met)**, **commits ×0.787 FAIL**, **rows
  inserted ×0.703 FAIL** (passed before 18).
- **Campaign 10:31Z: 64/0, 1683 s.** Fill 197 s; setup 248 s; P0 holds;
  tells 35/0; f1 at the seam ×1.03; WAL `db` ×2.54, `reporting` ×0.14
  (FIGURE).
- Cause (owner's diagnosis): `Composer.transaction_shape`
  (`tools/gm/history.py:503-525`) divides the fill's own counted
  transactions (`fill.py:230-235`: no session set-up, `set_clock` or
  visits) by the tail's **every** commit + rollback on the database: R
  reads 1.34 commits per call at 13:00, the forged past 0.97; rows
  inserted ride the same shape (×0.70–0.74 every hour). Chunk 18's own
  risk line, at −21 % / −30 %.
- Driver's call: a defect in chunk 18's code, not a change to stated
  behaviour (D594): a `coding-executor` fixes it on the wave branch,
  then a fresh 12b owner reruns both games.
- Risk: game wall times 1660–1683 s against 1800 s, about 2 min margin.

### Gate fix: chunk 18's transaction shape — 1e341dc, merged df27325, 2026-11-20

- `coding-executor`, own branch from 237cef9 (branch deleted after).
- Cause: R's commits before f8's planting are 0.9425 per call + a flat
  0.095/s (likely autovacuum, inferred). From f8's planting, +3.995
  commits per `orders.detail` call: without the index, the query runs a
  Parallel Seq Scan with 2 workers, and each worker counts 2 commits at
  start-up (tested on 19: 50 queries gave +200 with workers on, +4 off).
  Session set-up, pooler checks, the reports and real mode ruled out.
- Fix: `Composer.transaction_shape`'s denominator is the tail's
  fill-equivalent transactions: the fill's counted transactions per call
  over its last 60 min (`TX_PER_CALL_SPAN`, `fill_per_call()`, whole fill
  as fallback) × the tail's calls; the report notes it. D594 unchanged
  (shape still the fill's transactions; only the level was wrong).
  `tup_inserted` and the other `pg_stat_database_*` counters stay on the
  transaction shape (R's rows per call rise at night with
  `deliveries.ingest`; predicted ×1.001 vs ×0.987 on calls).
- **Game content touched:** f8's history signature gains a measured
  `counter_per_call` on `pg_stat_database_xact_commit`, key `{KEY}`,
  `per_call 4` (`faults/pg-join-index-missing/fault.yaml`, beside its
  measured `tup_returned`/`blks_hit`, and the fixture's mirror
  `fixture-dropped-index`); without it the fix would spread f8's commits
  over the whole past (predicted ×1.08, FAIL). Faults don't bump
  versions.
- Known limit: the flat ~0.09/s floor scales with the load, so the
  forged night stays 6–12 % under R.
- Checks: `test_history` 40 OK (3 new, two fail on the old code); unit
  suite 1570 OK (378 s); `fixture-fill` history 39/0 (1396 s, in window;
  per-call 1.010; forged rows inserted per call within ±2.2 % of the tail
  every hour; commits +3.9/+5.3 % in f8-active hours from the detail
  mix, +0.5 % without f8's share). No image change.
- Predicted for 12b's shop rerun (inferred): commits ×0.97 (night
  ×0.88–0.94, day ×0.98–1.00), rows inserted ×1.00, statements ×0.986.
  Scratch: `fix18/`.

## 2026-11-20: chunk 12b merged; wave 4's gate passed

- Chunk 12b, third owner, resumed from WIP 713fbcf: the tools squashed as
  758e080 onto v0.6-w4 before the runs (so each record names a surviving
  commit), records and setup-time lines 17fdb0b, merged `--no-ff` as
  a86c3e3. The 0931Z and 1031Z WIP records never reached the wave branch.
- Shop game 12:31Z: 54/0, 1642 s. Fill 473 s; deploy to fill end 503 s
  (bound 600); deploy to `restart.at` 814 s (296 s anchor wait); import
  80 s, promtool peak 1043.9 MiB.
  - M1 10/10: all within 0.2 % of R scaled to span, except `daily_sales`
    16 vs 15.0 (one row) and `delivery_events` ×1.025; `n_live_tup`
    FIGURE only (D593).
  - Tells 10/10; autovacuum `customers` 1 run (D596 rule), `products`
    102 vs 123.3 (band 60.66–247.6).
  - M3 5/5 over 15 steps: commits ×0.996 (predicted ×0.97; night steps
    ×0.91–0.97 vs predicted ×0.88–0.94), rows inserted ×0.982, statements
    ×1.00, calls ×0.992, errors ×0.991; correlations 0.995–1.
  - f8's step 14008930 vs 14016512, tolerance 170000.
- Campaign game 13:32Z: 64/0, 1652 s. Fill 196 s; deploy to fill end
  231 s (bound 330); import 90 s, peak 1220.6 MiB; P0 holds; tells 35/0;
  f1 at the seam ×0.99.
- Setup times in the READMEs: shop 8 min 38 s (fill 7 min 53 s),
  campaign 4 min 9 s (fill 3 min 16 s). Both documents and
  `fixture-fill`'s checked against a fresh generation (`scendoc.py`):
  only the setup line changed.
- Unit suite 1570 OK, 2 skipped (374 s) on the merged tree.
- For v1.0 gating (recalibration on 19, FIGURE only): 16 service-time
  ratios outside ×0.8–×1.25 (shop `orders.detail` ×15 from f8's scan,
  `reports.best-days` ×35, `deliveries.ingest` ×2.27, `orders.place`
  ×1.96, `orders.status` ×1.61, `reports.dashboard` ×0.44; campaign 10 of
  22, among them `dashboard.today` ×68, `dashboard.freshness` ×63,
  `dashboard.revenue` ×17, `declare.exports` ×4.25); WAL rates outside
  the band: campaign `db` ×2.43, `reporting` ×0.14 (shop `db` ×1.18 is
  inside it; corrected by G10.4).
- Risks: both games about 2.5 min under 1800 s; history import peaks at
  1.0–1.2 GiB.
- Figures: 5 agents, 348 tool calls, 51.1M tokens in / 315k out, max
  context 333k, $30.91 at API prices. **Over 300k:** the first owner
  (333k) ran the three games and the tools' build in one context before
  stopping for rulings; the later owners stayed under 170k.
- **Gate:** every item of wave 4's gate row is met: the first pass
  (figures, ten stack tests, smokes, fixtures, dpkg lists), the post-18
  reruns (chunk 18 and fix 1e341dc: scheduler rebuilt, its unit tests,
  stack test, `fixture-fill` short test and history run), the full unit
  suite on the merged tree, and the two short games. Next: G10.4
  (spec-writer), the wave report, the merge into main.

## 2026-11-20: G10.4 done; wave 4 report; merged into main

- G10.4 (spec-writer): 0c2e91a, status 3c5c82b, spec D597, formats.md
  v41, plan v19.
  - The forms: `short-game` records named in "Fake aging's measured
    figures"; the scenario document's `## Fake aging` section and its
    sources (9.10); M3's judged set and bounds in master spec 12.1 (five
    measures, correlation ≥ 0.95, ratio of means 0.95–1.05); the
    `fill_transactions` key in "The fill's metrics record"; 9.9 fix 12
    gains the gate fix's denominator, f8's `counter_per_call` and
    `SHAPE_RATIO`.
  - Capture W4 item 1 names `tells.sh --start`. Chunk 17b's scope line
    corrected for `statio_user_indexes`' `datname`.
  - Chunk 16's template gaps filed as ISS-009 (Medium), not a form.
  - Chunk 17c's content findings are open questions for the owner: O298
    (the clinic's policy says pgaudit is on, but no seed loads it) and
    O299 (the grid's TEMP TABLE in a read-only session), both with
    proposed defaults.
  - The 19 recalibration figures are under v1.0 gating's "v0.6's
    additions" (D597 extends D590): 16 service times, 2 WAL rates.
- Wave 4 merged: chunks 5, 12a, 12b, 12c, 14, 16, 17a, 17b, 17c, 18
  (18 inserted mid-wave, D594/D595). Rulings in the wave: D586–D597.
  Gate fixes: 1e341dc (chunk 18's transaction shape).
- Figures: 31 agents, 2,231 tool calls, 304.6M tokens in / 1.6M out, max
  context 333k (12b's first owner, the only one over 300k; see 12b's
  entry), $145.30 at API prices, before G10.4 (+1 agent, 217k context).
  By chunk: 12b $30.91 (21 %), 17b $12.26, 14 $8.69, 18 $8.68, 17c $7.81,
  17a $7.20, 16 $5.39, 12c $5.01, 5 $3.91, 12a $3.35; outside chunks
  $52.08 (driver $15.11, security-advisor $7.75, spec-writer, research).
- For the owner's nod (report): D595's two readings (`user` before
  `datname`; a series with neither follows the load); f8's
  `counter_per_call` content change; the games' ~2.5 min wall-time
  margin; O298, O299; ISS-009's timing; D597's placing of the 19
  recalibration in v1.0 gating.
- Next: v0.6's release gate on main (no push): zlib1g (D588) and
  CVE-2026-76844; recheck the 10 OpenSSL CVEs in trixie; pgBadger's
  limit (D591) in the release notes. Then the milestone archive, v0.7's
  G3/G4 (`dev` from main at v0.6's release commit) and v0.7 wave 2.

## 2026-11-20: v0.6 release gate started

- Branch `v0.6-rg` (worktree `~/work/db_audit_gm-wt/v0.6-rg`) cut from
  main 1db4044. G3 (PGDG and Debian reachable) and G4 (swarm active,
  armenelos the only active node, the VPS drained and untouched) checked
  by hand; the host lock is free.
- Order: (A) zlib1g (D588) in the ten bricks' install steps, the ten
  builds `--no-cache`, dpkg lists, stack tests, the unit suite and the
  format checks (item 2); (B) security-advisor's post-change check, row
  G9.3, with the OpenSSL recheck; (C) items 1, 4, 5; (D) item 3, the two
  short games; (E) spec-writer's items 6 and 7; (F) G11, the owner.

### Release gate (A) item 2 and (E1) item 6 done, 2026-11-20

- (A) 7476d7b: `zlib1g` named in each of the ten installs plus a
  `ZLIB_FLOOR` assertion (naming it rather than `apt-get upgrade` keeps
  `postgresql-common` at 278 where G9.2 left it). All ten built
  `--no-cache --pull`; the only dpkg difference in each is zlib1g +b1 →
  +deb13u1. Stack tests all green at wave 4's counts (postgres 317/0
  after 3179aff, a test-only fix: `pgrep -o -x cron`, cron's per-job
  child raced the check). Scheduler unit 117 OK, api 36 OK; unit suite
  1570 OK, 2 skipped (397 s); format check 0 missing on the 5 scenarios
  and 38 fixtures. G5, G7, G8, G9.2, G10.1–G10.4 done. Row G9.3 added
  for the post-change check. Logs and dpkg lists: scratchpad `rg/`.
- (E1) item 6 met: 94bb1b5 (v1.0 gating's campaign per D542), 925734d
  (D598: retention after a compaction to v1.0 gating), a8b9edb (plan
  v20: "Recorded in" column); merged e91fb5a. The archive's checksum
  verified. Gap: the bastion's footprint with the status service up was
  never measured; (C) takes it.

### Release gate (B) G9.3 and (C) items 1, 4, 5 done, 2026-11-20

- (B) G9.3 CLEAR WITH NOTES (81b6ffb, `.tech` only; merged). zlib1g
  +deb13u1 read in all ten built images, `dpkg -V` clean; CVE-2026-85091
  and -27171 fixed by DSA-6613-1. CVE-2026-76844 is not zlib's (Debian:
  NOT-FOR-US, a webpack-dev-middleware flaw; OSV misattributes it): D588
  wants a one-line correction. Nothing pending in trixie-security; PGDG
  only `postgresql-common` 297 (kept at 278 by G9.2) and a no-change
  `check-postgres` rebuild. OpenSSL 3.5.7-1~deb13u3: the 10 CVEs still
  have no Debian fix (8 Low upstream, fixed in 3.5.10); none reachable
  on a served path; no rebuild would change anything.
  - **For the owner (G11):** (1) release with the 10 OpenSSL CVEs open,
    review at a trixie openssl DSA or 2027-02-01; (2) 14 nginx NVD
    matches on deb13u11 (backport false positives): accept as
    `[[ignore]]` until 2027-05-01, or let tomorrow's sweep file them.
- (C) all twelve runs 0 failed, no fix needed: `fixture-status` 27/0
  (381 s); `docs-overview-backup-claimed` 16/0; `fixture-clinic-front`
  38/0 as `player`; scenario smokes bookshop 19/0, fernway 18/0, shop
  26/0 (844 s), campaign 33/0 (317 s); `smoke.sh` 61/0,
  `smoke-monitoring.sh` 43/0, `smoke-governance.sh` 121/0,
  `smoke-load.sh` 73/0. The bastion's footprint with `status-pages` up
  (8674f10, in its `docs/gm.md`): 5.2 MiB container (256 MiB limit),
  nginx 11.2 MiB, the status service 1.7 MiB between renders, cgroup
  peak 21.7 MB at start-up. Logs: scratchpad `rg/c/`.
- Next: (D) item 3, the two short fake games.

### Release gate (D) item 3 and (E2) item 7 done, 2026-11-20

- (D) both short fake games PASS on 19, without `--record`, each in its
  window, nothing committed: shop 16:31Z 54/0 in 1675 s (fill 476 s;
  deploy to `restart.at` 520 s without the 328 s anchor wait; import 78
  s, peak 1063.5 MiB; M1 10/10; M3 5/5: calls ×0.983, errors ×1.00,
  commits ×1.00, rows ×0.977, statements ×0.998; tells 10/0, customers 2
  runs; f8's step 14008804); campaign 17:31Z 64/0 in 1705 s (fill 192 s;
  241 s without the 609 s wait; import 90 s, peak 1224.9 MiB; tells
  35/0; P0 held; f1 at the seam ×1.05). The restart record and `gmctl
  status` in each output; all 20 faults carry `aging.fake`, 19
  `history:` (f10 `real-only`); `test_fake_aging_faults` 6 OK. Nothing
  left deployed. **Margin narrowing:** 125 s and 95 s under 30 min (12b:
  about 150 s). Logs: scratchpad `rg/d/`.
- (E2) release notes ff7f19a (`## Release notes` in the v0.6 README; the
  driver filled in item 3's placeholders); D588 corrected (CVE-2026-76844
  is not zlib's; Debian NOT-FOR-US); merged. The ten Dockerfiles' zlib
  comment corrected the same way (comment only, no image change).
- O251 and O269 still read "open until built" though the refusals are
  built: for the milestone archive.
- Items 1 to 7 done. Left: item 8, G11, the owner's judgement, with the
  OpenSSL and nginx calls (G9.3) and wave 4's nods; then the merge into
  main on the owner's word.

### G11: the owner's rulings, 2026-11-20

Asked with AskUserQuestion; all four answered "(Recommended)":
1. **Release v0.6**: merge `v0.6-rg` into main (no push), archive the
   milestone, then v0.7's G3/G4 and wave 2.
2. **OpenSSL**: release with the 10 CVEs open; review at a trixie
   openssl DSA or 2027-02-01 at the latest.
3. **nginx**: the 14 NVD matches on deb13u11 accepted as `[[ignore]]`
   until 2027-05-01 (security-advisor writes them).
4. **Wave 4's items, all as proposed**: D595's two readings; f8's
   `counter_per_call` (per_call 4); O298 (load pgaudit in `lab` and
   `portal` in a later build); O299 (the owner amends the grid, the
   copy is refreshed); ISS-009 fixed in v0.7.

### Release gate passed; v0.6 merged into main, 2026-11-20

- G11 recorded e18b222 (D599 release; D600 OpenSSL open until a trixie
  DSA or 2027-02-01, nginx's 14 matches ignored until 2027-05-01; D601
  wave 4's items; plan v21; release notes draft v12; O298, O299 ruled,
  open until done; ISS-009 targets v0.7). `.tech` fb4cc2c merged
  (findings ≥ medium 31 → 17, accepted 110 → 124). D599's acceptance of
  the gate as run covers the games' margin and D597's recalibration
  placing as known limits.
- `v0.6-rg` merged into main `--no-ff` (no push). Next: the milestone
  archive (spec-writer, on main; keep O251, O269, O298, O299 live), then
  v0.7's G3/G4: `dev` from main at v0.6's release commit, and v0.7 wave 2.
