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
  from the hiding instance's planting (formats.md v37). **D544**: the
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
