# db_audit_gm v0.6 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
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
