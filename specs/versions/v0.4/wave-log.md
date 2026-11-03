# db_audit_gm v0.4 — Wave log

Execution record of [build-plan.md](../../archive/v0.4/build-plan.md). No intent or data
register: captures are recorded here by the wave driver (plan, "Read
first").

The owner gave leave on 2026-10-30 to run all four waves: each gated wave
merges into `main` and the next wave starts from it, without a stop for
the owner between waves unless a gate or a finding needs them.

## Wave 1 — started 2026-10-30

Chunks 1, 2, 3, 4, 5 (κ = 3). Branch `v0.4-w1`, worktree
`/home/bastien/work/db_audit_gm-wt/v0.4-w1`, cut from `main` at 51fd02c.

### Gates checked at the start

- G3 (network at image build time), hand check 2026-10-30: Debian's
  trixie `Release`, the PostgreSQL apt repository's `trixie-pgdg`
  `Release` and GitHub's s6-overlay releases answer 200. Cleared for
  wave 1.
- G4 (Docker host in swarm mode), hand check 2026-10-30: armenelos,
  Docker Engine 29.9.1, swarm active, leader; the VPS `vps-5718ad52`
  (29.9.2) a worker, `Ready`, `Drain`. Cleared for wave 1.
- Host resources on 2026-10-30: about 4G of memory available, 3G of swap
  in use, 10G free on `/`. Docker checks stay serialized under the host
  lock.

### Capture W1 — v0.4 template keys and contracts (chunk 1; read by 2, 3, 4, 5 and later)

Recorded 2026-10-30, before any code; drafted for the wave driver from
chunk 1's capture line, master spec 5, 6, 7.1, 7.2, 8.5, 9, 11, 12, 14
and 19, [formats.md](../../formats.md) v22, access model 5, 8 and 9,
spec D190 to D218, the plan's chunks 1 to 11, and the code on `v0.4-w1`
at 731ac3d (`tools/gm/{model,render,checks,localimpl}.py`, the format
skill's templates, `bricks/{postgres,scheduler,bastion}/`). Same rules
as v0.3's W1: where the spec fixes a point it is cited, not restated;
**(choice)** marks a point the sources left open, settled here with its
reason; each item names the chunk that writes it and the chunks that
read it. Chunk internals stay out: chunk 4 records its outcomes as W1-x,
chunk 3 as W1-y (Preflight corrections, item 4).

v0.3's captures hold where v0.4 changes nothing, and are cited here, not
restated ([../v0.3/wave-log.md](../v0.3/wave-log.md)): W1's preamble and
item 0 (snake_case keys, quoted octal modes, `# optional: <when>` keeping
a key uncommented so its shape is checked when present, `<placeholder>`
keys as free map keys, durations, moments, UTC instants); item 3 (brick
keys: `seed.paths`, `seed.modes`, directory seed entries,
`only_with_role`, `snapshot:`); item 4 (`window`, `threshold`); item 5
(write policies); item 6 (snapshot); item 7 (the scheduler's runtime
interface, its file forms, the `role_<role>_password` secrets); item 8
(`gm_check`, `check-psql`); W1-x and W1-y (the two bricks as built).
Every key v0.4 adds is *optional* in its template, so v0.3's definitions
load unchanged (the templates are the loader's schema,
`model.template_schema`).

**0. Conventions used below** (read by every chunk)

- **Purpose and domain ids**: `[a-z][a-z0-9-]*`, the folder's name
  (`shop-sales-reporting`, `shop`). **(choice)** Neither carries a
  `version`: nothing pins one (6.6, formats.md "Versions and pins"), so a
  version would be read by nothing. **(choice)** Both are looked up in
  the catalog only (`purposes/<id>/`, `domains/<id>/`), never in a
  scenario's folder: their material is copied in at design time, so a
  scenario-only purpose would have nothing to name. Unit tests reach
  test purposes and domains through `load_scenario(…, catalog_root=…)`.
- **Locations** `<node>/<database>` (6.9, 11.4): a node of the topology
  whose `role` is `database`, and a database `[a-z_][a-z0-9_]*` its data
  file creates (next item). Used by a purpose's `source` and `target`
  parts and by governance's `locations`.
- **What a data file creates (choice)**: the loader gets no SQL parser.
  It reads `data/<node>.sql` line by line, skipping lines whose first
  non-blank characters are `--`, and counts as created a database for
  each `CREATE DATABASE <name>`, a role for each `CREATE ROLE <name>` or
  `CREATE USER <name>`, and `pg_cron` for `CREATE EXTENSION [IF NOT
  EXISTS] pg_cron`: keywords in any case, at the start of a line after
  blanks, `<name>` unquoted `[a-z_][a-z0-9_]*`. A statement inside a `DO`
  body or a function is not seen. The three scenarios' data files already
  write their databases and roles so; chunk 5's `schema.sql` and every
  later data file do too. Reason: the references 6.1, 7.2 and 14 ask the
  loader to check ("a database its data file creates", "a role a data
  file creates", a data file creating `pg_cron`) need only these
  statements. Such roles carry no password: `load-data` sets them from
  secrets (9.7).
- **Reading a seed `postgresql.conf` (choice)**, for chunk 2b's `pg_cron`
  check: the last uncommented assignment of `shared_preload_libraries` (a
  quoted comma list, `pg_cron` among its items) and of
  `cron.database_name` (quoted), as PostgreSQL reads them; seeds use no
  `include`.
- **The classification key** `<database>.<table>.<column>` (11.3's
  `shop.customers.email`): three identifiers `[a-z_][a-z0-9_]*`, the table
  in schema `public` **(choice**: every classed table of the shop is in
  `public`; a schema-qualified form waits for a domain that needs one).
  Classes: the closed list `personal`, `customer-linked`, `internal`
  (11.2).
- **Cron times in scenario time (choice; widens v0.3 W1 item 7)**:
  `jobs.yaml`'s `at`, a seeded crontab's entries and a purpose job's
  `cadence` share one subset render can shift. Minute: any numeric form,
  as in v0.3. Hour: `*`, or a comma list of items `n`, `a-b` (a ≤ b,
  never wrapping), `*/s` or `a-b/s` (s ≥ 1), within 0–23. Day of month
  and month: `*`. Day of week: `*`, or a number or list 0–6 only with a
  single-number hour (v0.3's). No `@` form (`@reboot`, `@hourly`) in a
  crontab. Render expands the hour field to the hours it fires at,
  shifts each by −shift modulo 24 and writes them back as a sorted list
  (`*` stays `*`). Reason: P3's `mail-campaign` runs at
  `*/15 8-20 * * *` (10.3), outside v0.3's subset, and chunk 6 already
  shifts "lists, ranges and steps". See Preflight corrections, item 1.
- **`{{customer_timezone}}` outside the starter pack** (8.5, chunk 6): in
  a scheduler node's seed files and a `postgres` node's seed
  `postgresql.conf` (`cron.timezone = '{{customer_timezone}}'`) it
  renders as the bare zone name (`Etc/GMT-2`, `Etc/GMT` at a shift of 0:
  `render.zone_name`), never as the starter pack's text
  `UTC+2 (Etc/GMT-2)`, which the bastion's files keep.
- **`load-data`'s `psql` variables (choice; written by chunk 7, read by
  chunk 5)**: `-v customer_timezone=<zone>`, the bare zone as above, and
  `-v customer_utc_offset=<n>`, the customer's offset from UTC in whole
  hours, east positive, without `+` (`2`, `-5`, `0`): render's shift. A
  data file reads them as `:'customer_timezone'` and
  `:customer_utc_offset` (9.2's `business_settings`). Both are passed to
  every data file; one that ignores them loads as before.

**1. Scenario keys** (`scenario.yaml`; chunk 1b writes the template,
chunk 2a checks `domain:`, `purposes:` and `governance:`, chunk 2b
`crontab_roles`; read by 5, 6, 7, 12, 13, 16). Shapes: master spec 6.9,
normative; rules: 6.1, 11.3, 11.4, 14 ("The loader"); formats.md "What a
scenario must contain".

```yaml
domain: shop                        # optional: a scenario whose business comes from a domain;
                                    # a domain id, for provenance only
purposes:                           # optional: a scenario running purposes; non-empty
  - id: shop-sales-reporting        # a purpose id, once in the list
    parts:                          # exactly the parts its purpose.yaml declares (item 5)
      source: db/shop               # source, target: a location (item 0)
      target: reporting/reporting
      runner: bi                    # runner, consumer, receiver: a node name
      consumer: consumer
governance:                         # optional: a scenario handing the players a data policy
  policy: player/data-policy.md     # a file of the scenario (see Questions for the owner, 1)
  classification: data/classification.yaml   # (choice) the domain's file, copied in (item 6)
  classes:                          # non-empty; class (closed list) -> its rules
    personal:
      locations: [db/shop]          # a non-empty list of locations, or the word any
      separation: instance          # optional: the policy demands an instance of its own (11.4)
      readers: [shop_app, shop_reports, shop_crm, shop_customs, customs_gw]
                                    # required unless locations is any; may be []
      outbound:                     # optional: absent, the class leaves to no one
        - to: mail-provider         # a receiver's label, [a-z][a-z0-9-]*, once per class
          outbox: db/shop/mail_outbox   # (choice) <node>/<database>/<table>: the outbox it fills
          fields: [email, name, order]  # non-empty: what it may carry (G4, chunk 12)
    customer-linked:
      locations: [db/shop]
      readers: [shop_app, shop_reports, shop_crm, shop_customs]
    internal:
      locations: any                # takes neither readers nor outbound
nodes:
  - name: reporting
    crontab_roles: [bi_etl]         # optional: required on a node whose seed_files names
                                    # crontab, refused elsewhere; may be []
```

- `domain:` names `domains/<id>/domain.yaml`, which loads. A static
  scenario omits it.
- `purposes:`: each id names `purposes/<id>/purpose.yaml`; `parts` maps
  exactly the parts that purpose declares; `source` and `target` are
  locations and may be equal (P2 transforms in place); `runner` is a node
  of role `transformer`, `consumer` of role `consumer`, `receiver` of role
  `producer` **(choice**: 10.4 makes the gateway stub a `producer`, and
  chunk 2a's "the right role" needs one per part). For each job of the
  purpose (item 5) the runner node's `jobs.yaml` has one entry with that
  `name` and that `key`, the key being in its `queries.yaml` (v0.3's
  check).
- `governance:`: `policy` and `classification` name files of the
  scenario folder that exist. Every class of `classes` is of the closed
  list; every class `classification.yaml` uses other than `internal` has
  an entry, a missing `internal` reading as `locations: any`
  **(choice**: 6.1's "every class named is defined" read both ways, so G1
  to G4 never meet a class without rules, while 6.9's explicit `internal`
  stays allowed). `locations: any` takes neither `readers` nor
  `outbound`; any other `locations` requires `readers` **(choice**: the
  one reading of 6.9's shape that gives 9.3's "customer-linked: leaves
  nowhere" and "internal: not restricted"). Every location, and the
  `<node>/<database>` of each `outbox`, as item 0. Every reader is a role
  a data file of the scenario creates, which leaves out the game's own
  roles (`dba`, `postgres`, `gm_check`, `monitoring`,
  `pgbouncer_lookup`), never created by a data file (11.6).
- `outbox` **(choice)**: G4 (11.6) judges an outbox's rows against its
  flow's `fields`, and 6.9 names the outbox only in a comment; the flow
  names it so chunk 12 can find it.
- `classification` **(choice)**: 11.3 copies the domain's classification
  into the scenario without saying where; a key beside `policy` lets the
  loader check it exists and the governance checks find it from
  `scenario.yaml`.
- Every `database` node of a scenario with `governance:` keeps v0.3's DO
  NOT TAMPER line `host all gm_check samenet scram-sha-256` in its seed
  `pg_hba.conf` (11.6; `tarnbeck-outdoor-shop`'s `nodes/db/pg_hba.conf`
  has it already, for `check-sql`). The format skill states it (1b);
  `check-psql`'s other-node form (chunk 4) relies on it.
- `crontab_roles`: unique role names, each `[a-z_][a-z0-9_]{0,40}`, not
  reserved (v0.3 W1 item 7's rule for a schedule's roles), created by the
  node's own data file (2b). `[]` is allowed, for a crontab connecting as
  no customer role; f6's planted crontab still names the prepared
  `shop_refresh` (16.2).
- A fault instance whose `seed_changes` name `crontab` targets a node
  seeding one (chunk 2b; choice: a seed-file fault cannot change a file
  the node does not have).
- No loader rule ties a fault's `applies_to.purposes` to the scenario's
  `purposes:` (14 names none); the format skill states it as a
  completeness rule (1b).

**2. Answer-key keys** (`gm/answer-key.yaml`; chunk 1b writes the
template, chunk 2a checks, chunk 8b passes them; read by 10, 11, 14, 15,
16). Spec 6.2, 12; v0.3 W1 item 4.

```yaml
instances:
  - instance: f1
    sealed_check:
      script: faults/<fault-id>/checks/fixed.sh
      at_handover: 1
      judges: runs                  # optional: exactly when the fault's sealed_check.judges is
                                    # set, and equal to it (runs | triggers)
      threshold: 0                  # optional: with window (v0.3) or with judges (v0.4)
```

- With `judges`: `threshold` is required, a non-negative integer, the
  violations tolerated **(choice**: v0.3 pairs `threshold` with `window`
  the same way, and every value the check gets is then written in the
  answer key; 6.2's "0 by default" is the template's value); `window` is
  refused (6.2: "no window"). Without `judges`, v0.3's rule stands.
  Chunk 2a amends `model._check_behavioural`, which today refuses a
  threshold without a window.
- `checks.check_env` already passes `threshold` as `CHECK_THRESHOLD`;
  chunk 8b adds `CHECK_SINCE`, a UTC instant `YYYY-MM-DDTHH:MM:SSZ`, for
  an instance whose entry has `judges`.
- A tooling expectation naming an unmonitored instance (6.2, 13.4) needs
  no new key **(choice)**: its `need` and `expected` name the node in
  words; nothing machine-reads them, the feedback judges them.

**3. Fault keys** (`fault.yaml`; chunk 1a writes the template, chunk 2a
checks; read by 8a, 14, 15). Spec 6.3, 6.5, 13.3.

```yaml
family: data-flow                   # free text as in v0.3; v0.4's purpose faults are data-flow
                                    # or rules, its governance-* and security-* ids security
applies_to:
  bricks:
    - {id: scheduler, versions: ["0.2.0"]}
  purposes: [shop-customer-mailing] # optional: a purpose fault; non-empty, purpose ids
  preconditions: []
needs_unshared_host: true           # optional: top level, a boolean, absent read as false
sealed_check:
  script: checks/fixed.sh
  run_as: root
  judges: runs                      # optional: runs | triggers; absent, the check judges the
                                    # live state, as in v0.3
```

- `judges` and `behavioural: true` never together (choice: a judging
  check takes no window, 6.2).
- A purpose fault lists in `applies_to.bricks` the `scheduler` versions
  its runner needs (6.3); its instance's node is of a brick in that list
  (v0.3's rule, unchanged).
- The aging minimum counted from the job's first run after planting
  (6.3, D189) is v0.3's time-of-day rule, already in the template's
  `aging.minimum` comment: chunk 1a widens its words to "a job's runs",
  no new key.
- `needs_unshared_host` is read by `fit` (chunk 8a) through each
  instance's fault.

**4. Brick keys** (`brick.yaml`; chunk 1a writes the template, chunk 2a
checks, chunks 3 and 4 write their bricks' values; read by 6, 7, 13).
Spec 6.4.

```yaml
seed:
  dir: /opt/gm/seed/
  files: [postgresql.conf, pg_hba.conf, crontab]
  optional: [crontab]               # optional: seed files a node may leave out of its
                                    # seed_files; each a plain entry of files
  paths: {…}
```

- An entry of `optional` is an entry of `files` not ending in `/`; a
  directory entry (`builders/`, `scripts/`) is optional already (v0.3 W1
  item 3) and is not listed **(choice**: one statement of optionality per
  entry; chunk 2a refuses the listing as redundant).
- A node's `seed_files` maps every entry of `files` but the directory
  entries and those in `optional` (chunk 2a, the "no entry for the
  brick's seed file" check).
- Render mounts a seed config only for what `seed_files` maps, as in
  v0.3; an optional file left out is not mounted, and the brick tells by
  its absence under `seed.dir` (item 8).
- The roles list already holds `transformer` (`model.ROLES`, the
  template's comment); chunk 3 adds it to `scheduler`'s `roles`.

**5. The purpose** (`purposes/<id>/`; chunk 1b writes the template
`purpose.yaml` and `layouts.md`, chunk 2a loads and checks it; chunks 10
and 11 write the four; read by 12, 13, 14, 16, 18). Layout and contents:
6.7, formats.md "Purpose definition".

Inside `material/`, **(choice)** one folder per part receiving material,
holding files named as the scenario's own for that part's node, as
fragments:

```
purposes/<id>/
  purpose.yaml
  material/
    runner/          queries.yaml, jobs.yaml and schedule.yaml fragments; scripts/ (optional)
    consumer/        the same (optional)
    receiver/        the same (optional: the gateway stub's repository and schedule, P5)
    source/, target/ data.sql: DDL, roles and grants appended to that node's data file
                     (optional)
  checks/            one script per invariant
  gm.md
```

Reason: the GM copies part by part into `nodes/<node>/` and
`data/<node>.sql`, and chunks 10 and 11 write theirs side by side. A
**fragment** has the scenario file's top-level keys holding only the
entries it adds: `queries:`; `jobs:`; for a schedule `connections:`,
`streams:`, `shapes:`, never `intensity` or `timeline`, which are the
scenario's. Material is written for 16.1's mapping (nodes `db`,
`reporting`, `bi`, `crm`, `consumer`, `gateway`; databases `shop`,
`reporting`), and the GM adapts the names when it copies **(choice**:
copied and adapted as a domain is, 6.8; a placeholder grammar would need
a render step nobody runs).

```yaml
# purpose.yaml
id: shop-sales-reporting            # the folder's name
title: <one line>
domains: [shop]                     # non-empty; domain ids
kind: pulled                        # pulled | transformed-in-place | pushed | pushed-obligation
parts:                              # part -> one line saying what fills it
  source: <the shop's database>
  target: <the agency's reporting database>
  runner: <the agency's transformer>
  consumer: <the back office's dashboards>   # optional: a purpose with a consumer
  receiver: <the customs gateway stub>       # optional: a pushed obligation only
jobs:                               # non-empty
  - name: rollup-hourly             # its name in the runner's jobs.yaml
    key: rollup.hourly              # its key in the runner's queries.yaml
    part: runner                    # the part that runs it: runner, the only one in v0.4
    source: source                  # the database parts it reads and writes
    target: target
    method: script                  # sql | script | foreign-tables | procedure | pg_cron
                                    # | cron-daemon
    computes: <one sentence>
    cadence: "5 * * * *"            # scenario time, item 0's subset
    connections:                    # connection name -> customer role: a script's names (its
      source: shop_etl              #   job's connections:), or the job's one connection's
      target: bi_etl                #   name
trace:                              # non-empty
  - kind: published-results         # outbox-rows | published-results | run-ledger | definitions
    part: target
    table: rpt.sales_hourly         # optional: a table (schema-qualified unless public)...
    run_column: <column>            # optional: with table; ties a row to the run that wrote it
  - kind: run-ledger
    part: runner
    file: /var/log/scheduler/scheduler.log   # optional: ...or a file, absolute, on that part's node
invariants:                         # non-empty
  - id: R1                          # [A-Z][0-9]+, once in the purpose (R1, L2, M3, E4)
    statement: <one sentence against the source>
    check: checks/<file>            # a file of checks/
    parameters: {}                  # fault.yaml's parameter shape; may be {}
    witness: <what must exist in the data for a run to be able to violate it>
data_moved:                         # one entry per job
  - job: rollup-hourly
    reads: []                       # classification keys (item 0), classes other than
                                    # internal, the job reads; may be []
    writes: [target:rpt.sales_hourly, target:rpt.sales_daily]   # <part>:<table>
roles:                              # the customer roles the purpose needs
  - name: shop_etl
    part: source                    # the database part it lives in
    reads: [orders without customer_id, order_lines, products]  # as 9.7 writes them; may be []
    writes: []                      # may be []
```

- **(choice)** The closed values are the spec's words, hyphenated
  (`kind` 8.2, trace kinds 8.3, methods 8.6), with `sql` added for a
  plain statement on one connection (P2, P3 and P5, 10's opening).
  `roles`' `reads` and `writes` and `computes` are free text, not
  parsed.
- Chunk 2a checks: the template; `domains` exist; `parts` among the five,
  `source`, `target` and `runner` present; each job's `part` a declared
  `runner`, its `source` and `target` declared database parts;
  `cadence` in item 0's subset; each trace entry has exactly one of
  `table` and `file`, its `part` declared; each `data_moved.job` a job of
  the purpose; each invariant's `check` exists.

**6. The domain** (`domains/<id>/`; chunk 1b writes the templates
`domain.yaml` and `classification.yaml`, chunk 2a loads, chunk 5 writes
`domains/shop/`; read by 12, 13, 16). Layout: 6.8, formats.md "Domain".

```yaml
# domain.yaml
id: shop
title: <one line>
schema: data/schema.sql             # (choice) each part named by its path, as scenario.yaml's
load: data/load.sql                 # brief: and the answer key's notes: are, so the loader
classification: data/classification.yaml   # checks each exists
producers: producers/               # a folder of fragments (below)
notes: docs/gm.md
purposes: [shop-sales-reporting, shop-winback-leads, shop-customer-mailing,
           shop-export-declarations]       # the purposes that fit; may be []
```

- `purposes` **(choice)**: the loader checks each id's form, not that it
  exists, since chunk 5 writes the domain a wave before chunks 10 and 11
  write the purposes. The other direction is checked: a purpose's
  `domains` exist, and each lists that purpose (chunk 2a; vacuous in
  wave 1).
- `producers/`: `queries.yaml` and `schedule.yaml` fragments (item 5's
  rule) of the business's producer, the web shop's for `shop` (6.8, 9.8);
  chunk 5's "parse as fragments".
- `schema.sql` and `load.sql` follow item 0's data-file convention,
  `load.sql` reading item 0's two `psql` variables; copied into a
  scenario they make its data file, `schema.sql` first.

```yaml
# classification.yaml
columns:                            # (choice) wrapped, as queries.yaml and jobs.yaml wrap theirs
  shop.customers.email: personal    # <database>.<table>.<column> (item 0) -> class
  shop.orders.customer_id: customer-linked
  shop.products.name: internal      # a column with no entry is internal; listing one is allowed
```

- Chunk 5 lists every column of the shop's tables, `internal` ones
  included (9.9, its done-when). A scenario copies the file where
  `governance.classification` names it (item 1).

**7. The transformer script** (writes: chunk 3 the brick and program,
chunk 1b the templates `queries.yaml`, `jobs.yaml` and `layouts.md`,
chunk 2b the loader; read by 6, 10, 11, 12, 13). Spec 7.1, normative;
access model 5 ("Scheduler nodes"), 8, 9.2.

- **The repository entry** (`queries.yaml`), the fifth form beside the
  query, pool, sequence and builder (v0.3 W1 item 7):

  ```yaml
  queries:
    rollup.hourly:
      script: scripts/rollup.py:hourly   # scripts/<file>:<function>: a file of the node's
                                         # scripts/ seed folder, the function defined at its
                                         # top level (checked by ast, as a builder's is)
      options: {batch: 5000}             # optional: a map passed to the function
  ```

  A script key runs only as a job: a stream naming one is refused (7.1),
  and so is a timeline change's `set.key` naming one (2b; choice: it
  would turn a stream into one).
- **The job** (`jobs.yaml`):

  ```yaml
  jobs:
    - name: rollup-hourly
      key: rollup.hourly
      connections:                  # a script key's job only, instead of connection:
        source: shop                # the script's name -> a connection of the node's
        target: reporting           #   schedule.yaml
      at: "5 * * * *"
  ```

  Exactly one of `connection:` (any other key) and `connections:` (a
  script key); `connections` non-empty, its names `[a-z][a-z0-9_]*`
  **(choice**: they are the keys of the script's `conns` map), `source`
  and `target` by convention; each value a connection of the schedule.
  The program's `check` verb and `gm-reload-scheduler` check the same
  (3a). In the template `connection:` becomes `# optional:` with that
  rule.
- **The `scripts/` seed entry** (chunk 3): `scheduler`'s `seed.files`
  gains `scripts/` after `builders/`, `seed.paths`
  `scripts/: /srv/scheduler/repository/scripts`, on the volume
  `repository` and under the writable path `/srv/scheduler/repository`,
  so fixable where the repository is (7.1). In a scenario: `seed_files`
  `scripts/: nodes/<node>/scripts/`, optional, a folder as `builders/` is
  (v0.3 W1 item 3), each file a seed config at
  `/opt/gm/seed/scripts/<file>`.
- **`scheduler` 0.2.0's other lines** (chunk 3): `roles: [producer,
  consumer, transformer]`. No package (19) and no new secret: a script's
  connections use the schedule's `role_<role>_password` secrets (v0.3 W1
  item 7).
- **Jobs and no stream**: `schedule.yaml`'s `streams:` may be `[]` (7.1,
  20); `bi` and `crm` have none. The template says non-empty and the
  loader enforces it: Preflight corrections, item 2.
- Chunk 3 records as built (W1-y): the call and its log lines, the
  scripts' digests in `/run/scheduler/loaded`, the means beside
  `check-sql` (12.1, 12.2).

**8. `postgres` 0.4.0's new `brick.yaml` entries** (writes: chunk 4,
chunk 1a its version lines; chunk 2b checks a scenario against them,
chunk 6 renders, chunk 7 sets the roles' passwords; read by 9, 13, 14,
15, 16). Spec 7.2, normative; access model 5 ("Databases"), 8, 9.4, 12.

| Entry | Value | Note |
|---|---|---|
| `seed.files` | `postgresql.conf`, `pg_hba.conf`, `crontab` | |
| `seed.optional` | `[crontab]` | 6.4 |
| `seed.paths.crontab` | `/var/spool/cron/crontabs/postgres` | **(choice)** Debian's spool, so `cron` and `crontab` need no setting; the seed config `/opt/gm/seed/crontab` is 0:0 `"0444"`, no `seed.modes` entry (no secret in it) |
| `volumes` | `{name: cronspool, path: /var/spool/cron/crontabs}` | **(choice)** the spool directory itself, root:crontab `1730`, the crontab `postgres:crontab` `0600` (Debian's), both set by `gm-entrypoint` at every start |
| `snapshot.cronspool` | `copy` | 7.2 |
| `writable_paths` | unchanged | **(choice)** the spool is not listed: v0.3 W1 item 5's owner and mode rule would rewrite modes `cron` checks. Players change it through `gm-crontab` only, and a `postgres` node is fixable, so a crontab fault's *fix* needs no override |
| `player_access.sudo_wrappers`, `protected_files` | `+ /usr/local/sbin/gm-crontab` | |
| `/etc/sudoers.d/gm-player` | `…, /usr/local/sbin/gm-crontab` appended to `player`'s line | **(choice)** without `""`, unlike the three others: sudo's argument wildcards match spaces too, so the wrapper itself accepts exactly `-l` or one file and refuses anything else |
| `processes` | unchanged: `[postgres, sshd]` | **(choice)** below |
| `secrets` | no new entry; a comment | as `scheduler`'s (spec D167), below |

- **`gm-crontab`** (7.2): `-l` lists `postgres`'s crontab, `<file>`
  installs a replacement. **(choice)** It reads `<file>` with the
  invoking `player`'s rights, never as root: root reading a path the
  player names would let `crontab`'s error lines show a root-only file.
  Its messages, exit codes and behaviour on a node with no daemon are
  chunk 4's, recorded in W1-x.
- **The cron service** (7.2): s6 longrun `cron` (`cron -f`), after
  `postgres`. **(choice)** Its run script tells whether the node seeds a
  crontab by the seed config `/opt/gm/seed/crontab`, which render mounts
  only when `seed_files` names `crontab` (item 4), not by the spool's
  content: a player's empty crontab leaves the daemon running, as on a
  host. The crontab is installed once, under v0.3's seed marker
  `/var/lib/gm-state/.gm-seeded`, as configuration is.
- **`processes` (choice)**: `cron` is not added. A node-health entry
  `default` expands to the brick's `processes` (`localimpl`), and
  `tarnbeck-outdoor-shop` and `fernway-clinics-monitoring` give
  `db: default`: a `cron` down by design on every node without a crontab
  would read down there, against "re-pinned, otherwise unchanged" (6.6,
  16.4). The loader refuses a node-health entry naming a service outside
  `processes`, so in v0.4 node-health cannot watch `cron`: a known limit
  `docs/gm.md` names (chunk 4).
- **The crontab roles' secrets**: for each `crontab_roles` entry, the
  game's secret `role_<role>_password` (v0.3 W1 item 7's name and
  generation), derived and mounted by render (chunk 6) at
  `/opt/gm/secrets/role_<role>_password`, 0:0 `"0400"`, as on a scheduler
  node; one secret per role per game, the one any scheduler node naming
  the role holds. `load-data` (chunk 7) sets the password of every role a
  schedule or a `crontab_roles` names (choice: 9.7, "each login role's
  password is a generated secret, set by `load-data`"; `shop_refresh` is
  in no schedule).
- **The password file (choice)**: `/run/gm-cron/pgpass`, its directory
  `postgres:postgres` `0700`, the file `postgres:postgres` `0600`, written
  by `gm-entrypoint` at every start from each mounted
  `/opt/gm/secrets/role_*_password` (the role named by the file name),
  one line `*:*:*:<role>:<password>` each, `:` and `\` escaped as libpq
  requires; absent when none is mounted. Reason: `/run` is emptied at
  every start and never copied, so no password lands on a volume or in
  the hand-over snapshot. Within `dba`'s reach through programs run as
  `postgres`: access model 12, accepted.
- **The baseline entry (choice; for the format skill and chunks 7, 13,
  16)**: the crontab sets `PGPASSFILE=/run/gm-cron/pgpass` on a line of
  its own above its entries; an entry runs `psql -X -w -h /run/postgresql
  -U <role> -d <database> …` and appends its output to
  `/var/log/postgresql/cron/<job>.log` (`>> … 2>&1`), one file per entry,
  named by its job (`[a-z0-9-]+`).
- **The cron log directory** (7.2): `/var/log/postgresql/cron/` on
  `pglog`, created by `gm-entrypoint` at every start when missing,
  `postgres:pgconf` `2750`, as `pglog`'s own directory, so the players'
  group reads it.
- **`pg_cron`**: no `brick.yaml` entry; the package sits idle until a
  seed preloads it (7.2). Its settings and the loader's check: 7.2 and
  item 0.
- Chunk 4 records as built (W1-x): the cron service, the paths above as
  built, `gm-crontab`'s form, `check-psql`'s other-node form.

**9. Wave 1 coordination** (for the driver and chunks 1 to 5)

- **Ownership in `bricks/{postgres,scheduler}/`**: chunk 1a owns every
  line naming the brick's version (`version:`, `image:`, `scheduler`'s
  `technology.version`, the header comments, `docs/gm.md`'s version
  lines, image tags and Supported faults tables, the stack tests' tags);
  chunk 3 owns every other line of `scheduler`'s, chunk 4 of
  `postgres`'s. Both are cut after chunk 1 merges, so they hold its lines
  from their start. *Added 2026-10-30 after spec D221 to D223:* chunk 1a
  also owns `bastion`'s version lines (0.4.0: `brick.yaml`'s version and
  image, the Dockerfile's build comment, `docs/gm.md`'s version lines and
  tags, the stack tests' tags); chunk 19 owns every other line of
  `bastion`'s, and records as built as W1-z. Chunk 19, like chunk 4,
  merges only after chunk 2a (D223).
- **Order**: chunks 1 and 5 first; 2, 3 and 4 after chunk 1's merge (4
  after G5 too). **Chunk 4 adds `crontab` to `seed.files` only on a
  branch holding chunk 2a**: without 2a's `seed.optional` check, every
  scenario pinning `postgres` 0.4.0 fails with "no entry for the brick's
  seed file crontab" (Preflight corrections, item 3).
- **Chunk 2's fixtures** use scenario-local bricks, as v0.3's did:
  `bricks/postgres/` (id `postgres`, 0.4.0) with item 8's seed entries,
  `bricks/scheduler/` (0.2.0) with item 7's role and `scripts/`, chunks
  3 and 4 not being merged; and a test catalog root for purposes and
  domains (item 0).
- **Chunk 5** writes only under `domains/shop/` and the root README's
  domain table (a shared list). It writes the roles of the `shop`
  database (9.7's rows on `db`); `bi_etl` and `bi_reader` are chunk 10's,
  P1's target material (reading the plan's two scopes, so nothing is
  written twice). Its SQL runs into a `postgres` image built from its own
  worktree (0.3.0 there; it needs nothing of 0.4.0, `MAINTAIN` being
  PostgreSQL 17's). Its domain loads in the unit suite once 2a has
  merged (its done-when).
- **Images**: as v0.3 W1 item 9, a tag is built only from a branch
  holding the version that names it, each host-locked command building
  every image it uses from its own worktree.

**Choices made here, not in the spec** (for the driver's review): no
version on purposes and domains, both from the catalog only; the
data-file and seed `postgresql.conf` readings; the classification key
in `public`; the widened cron subset and render's expansion; the bare
zone outside the starter pack and the two `psql` variables' forms;
`receiver` of role `producer`; classes defined both ways, `internal`
defaulting to `any`, `readers` required unless `any`;
`governance.classification` and `outbound[].outbox`; `threshold`
required with `judges`; no key for an unmonitored instance;
`judges` excluding `behavioural`; `seed.optional` holding plain entries
only; the purpose's `material/<part>/` fragments written for 16.1's
mapping, and `purpose.yaml`'s keys and closed values; `domain.yaml`'s
path keys, its `purposes` unchecked for existence; `classification.yaml`
wrapped in `columns:`; a script's connection names, the timeline's
`set.key` refusal; the spool path and volume, `writable_paths` and
`processes` unchanged, `gm-crontab`'s sudoers line and reading as
`player`, the cron service's test by the seed config, the password
file's path, form and owner, `load-data` setting crontab roles'
passwords, the baseline entry and its log file.

### Preflight corrections for spec-writer

1. **The cron subset** (chunks 2b, 1b; read by 6, 11, 13, 16). P3's
   `mail-campaign` runs at `*/15 8-20 * * *` (master spec 10.3); its hour
   range is outside v0.3's `jobs.yaml` subset (hour `*`, a number or a
   list: v0.3 W1 item 7, `model._cron_problem`), which the loader
   refuses, and no chunk widens it: chunk 2's scope does not name it,
   chunk 1b's template keeps v0.3's comment, while chunk 6 already
   shifts "lists, ranges and steps". A seeded crontab's entries are
   checked by nobody before render. Proposal: chunk 2b's scope gains
   "`jobs.yaml`'s `at`, a seeded crontab's entries and a purpose job's
   `cadence` in W1 item 0's subset", and chunk 1b the template comment;
   W1 item 0 holds the subset meanwhile.
2. **`streams: []`** (chunk 1b; read by 2, 3, 13). `schedule.yaml`'s
   template says `streams: # non-empty`, and the template is the
   loader's schema, so `streams: []` is refused as empty; `bi` and `crm`
   run jobs and no stream (master spec 7.1, "`streams` may already be
   empty"; 16.1). That template is not in chunk 1's Files. Proposal: add
   `.claude/skills/scenario-format/templates/schedule.yaml` to chunk 1b's
   Files, `streams` marked "may be `[]` (a node with fixed-time
   operations only)".
3. **Wave 1's order** (chunks 2a, 4). The plan cuts 2, 3 and 4 together
   after chunk 1; chunk 4's `crontab` entry in `seed.files` breaks the
   unit suite until 2a's `seed.optional` check is in (W1 item 9).
   Proposal: an in-wave edge `2 ──> 4` (2a merged into `v0.4-w1` before
   chunk 4 merges, chunk 4 taking `v0.4-w1` in before its final suite
   run; W1).
4. **Two W1-x** (chunks 3, 4). Both are told to record as built "as
   W1-x". Proposal: chunk 4's is W1-x and chunk 3's W1-y, as in v0.3;
   W1 uses these names meanwhile.

### Questions for the owner

1. **How `player/data-policy.md` reaches the players.** Master spec 11.5
   and 15 hand the players the data policy in the starter pack, and 6.1
   has the loader check the file exists; but the starter pack reaches
   the bastion only as `bastion` 0.3.0's three seed files (`README.md`,
   `story.md`, `issues.md`, copied by its entrypoint from a fixed list),
   and master spec 7.3 keeps the bastion unchanged. No chunk delivers the
   policy, so in chunk 13's fixture and chunk 16's scenario it would stay
   on the GM's side. **Proposal**: `bastion` 0.4.0, `data-policy.md` a
   fourth seed file under `seed.optional` (W1 item 4), copied to
   `/home/player/data-policy.md` like the others; chunk 1a bumps and
   re-pins it in the same commit as the two other bricks (every scenario
   and fixture has a bastion; no catalog fault applies to `bastion`),
   and the entrypoint, `brick.yaml`, `docs/` and stack test
   change in a small chunk of wave 1 or 2, before chunk 13. The
   alternative, no bump: the GM writes the policy as a section of
   `player/README.md` and `governance.policy` names that file, departing
   from formats.md's layout. If the bump is chosen, the ruling is needed
   before chunk 1a merges, so the re-pins happen once. Meanwhile chunks
   1b and 2a treat `governance.policy` as a file of the scenario that
   must exist, which both answers keep.

### G5 — dependency preflight on `postgres` 0.4.0's packages (security-advisor, 2026-10-30)

**Clear, with conditions; nothing for the owner.** Checked in throwaway
`debian:13-slim` containers with the Dockerfile's PGDG line (none left).

- `postgresql-18-cron`: candidate `1.6.8-1.pgdg13+2` (PGDG still serves
  1.6.7). **Install 1.6.8, pinned exactly** (ARG `PG_CRON_PACKAGE=1.6.8-1.pgdg13+2`
  plus a `dpkg-query` build assertion, the pgbouncer precedent D177):
  1.6.8 carries citusdata/pg_cron PR #425 (no CVE), which stops
  `cron.unschedule` matching a job's owner case-insensitively. No advisory
  in NVD (no CPE), OSV, GitHub or the Debian tracker.
- Debian `cron` `3.0pl1-197` (trixie/main, no update): **unpinned**, as
  `openssh-server` and `sudo` are. Pulls in only `cron-daemon-common`;
  `systemd` is already there through `openssh-server`; no MTA without
  recommends. No open advisory (CVE-2024-43688 fixed in 3.0pl1-197; NVD's
  CVE-2019-9706 hit on "3.0" is a false positive, fixed in 3.0pl1-133).
- Both packages go in the **second** `apt-get install` (the PGDG one),
  so the `postgres` 100:102 assertion still holds. New group `crontab`
  (gid 997); `/usr/bin/crontab` setgid `root:crontab`; spool
  `/var/spool/cron/crontabs` `root:crontab` 1730, each crontab
  `postgres:crontab` 0600 (cron skips a crontab with another owner or mode:
  `cronspool` must keep them).
- Build notes passed to chunk 4: Debian's `/etc/crontab` runs
  `/etc/cron.daily/{apt-compat,dpkg}` as root (the leader may remove
  them so cron reads only `postgres`'s spool); `/etc/pam.d/cron` requires
  `pam_loginuid.so`, the usual cause of a PAM session error in
  containers; no `/etc/cron.allow`, so every user may run `crontab`
  (accepted, D211).
- `.tech` unchanged; G6 records pg_cron 1.6.8 and cron 3.0pl1-197 (no
  CPE) and `postgres 0.4.0` after chunk 4 merges.

G5 **done (2026-10-30)**.

### W1 reviewed by the driver, 2026-10-30

The capture's 32 **(choice)** points are accepted as drafted. Its four
preflight corrections go to `spec-writer` before chunk 1's branch is cut
(chunk 5 is cut at once: none touches it); its question goes to the owner
before chunk 1a merges.

### Plan revisions and rulings during the wave's start, 2026-10-30

- `spec-writer` applied W1's four corrections: build plan v3 (8eca1a5;
  spec D219 the cron subset and `streams: []`, D220 the `2 ──> 4`
  merge-order edge and the W1-x/W1-y names).
- **Owner ruling (W1's question 1), spec D221**: `bastion` 0.4.0;
  `data-policy.md` a fourth, optional starter-pack seed file copied to
  `/home/player`, and the web front serving a simple read-only page with
  the README, story, issues and data policy, open to a reporting tool
  later; owner's refinement: each element only if the scenario provides
  it. `spec-writer` added D222 (the page rendered in the image at each
  start by Debian's `cmark-gfm`, tables on, raw HTML off) and D223
  (chunk 19 in wave 1; chunk 2a checks the policy's mapping); master
  spec amended after approval; formats.md draft v23; build plan v4
  (bfbf416) with **chunk 19** in wave 1 (six chunks), cut after chunk 1
  and gates G12 and G13, merging after chunk 2a.
- New gates: **G12** (owner, spec O134: does the page make the web front
  run in every game, against D103) and **G13** (`security-advisor`
  preflight on `cmark-gfm`). Both block chunk 19's branch.
- W1 item 9 amended: `bastion`'s line ownership (chunk 1a / chunk 19).

### G13 — dependency preflight on `cmark-gfm` (security-advisor, 2026-10-30)

**Clear; nothing for the owner.** Debian 13's `cmark-gfm`
`0.29.0.gfm.13-4` (trixie/main, the only version; upstream's latest, July
2023), with `libcmark-gfm0.29.0.gfm.13` and
`libcmark-gfm-extensions0.29.0.gfm.13` (tables there), about 860 KiB, only
`libc6` beyond. All ten known advisories (GHSA, CVE-2020-5238 to
CVE-2023-37463) fixed at or below gfm.12; OSV, NVD, the Debian tracker
show nothing open. **Unpinned**, on the Debian install line beside
`nginx`. Build assertions advised: `command -v cmark-gfm`; a table renders
`<table>` with `-e table`; `<b>x</b>` renders `raw HTML omitted` (safe
mode is the default: never `--unsafe`). Watch item for `.tech` at G6:
upstream silent since 2023 (CPE `cpe:2.3:a:github:cmark-gfm`). G13
**done (2026-10-30)**.

### Owner ruling on G12 (spec O134), 2026-10-30

Owner's words: "i expect a front at every game, we may have a common
caddy to handle multiple front and a homepage dedicated to the whole
setup to dispatch the viewer toward the game rules(readmes, game
informations, data policies, issues), tools and dashboards available.
Keep it simple for now. Expect it to evolve both with v0.5 and v1.0+
(with the fake aws, which will have its own entrypoint there). Keep the
setup as minimal as possible for now, delegate larger stuff for v0.5 and
later. I'll bow to your recomendations."

Driver's recommendation, sent to `spec-writer` to record and plan: the
bastion's web front runs in every game (D103 revised for v0.4); its home
page is the starter-pack page, listing what the scenario provides (README,
story, issues, data policy) and linking to the web routes it publishes
(Grafana and the like) when there are any; nothing else. A common Caddy in
front of several fronts, a setup-wide homepage, a reporting tool and the
fictional provider's own entry point are v0.5 and later.

### Chunk 1 — merged (48dc5c3), 2026-10-30

1a fb61d48, 1b 667ded1, merge 48dc5c3 (after chunk 5's). Unit suite 658
OK (with `test_brick_docs`), scheduler unit tests 60 OK; `postgres`
0.4.0, `bastion` 0.4.0 and `scheduler` 0.2.0 build and pass their stack
tests; prometheus, pgbouncer and postgres-exporter rebuilt and their
stack tests pass on the new tags. READMEs: only the pins changed (the
template's v0.4 blocks are all conditional and absent there). Smoke
scripts' tags updated, not run: wave gate.

**W1 addenda — choices chunk 1 made** (accepted):
1. `fixture-v03-refusals` keeps its local `scheduler` 0.1.0 brick, its
   pin and `fixture-job-timezone` at 0.1.0; its bastion and postgres
   re-pinned.
2. Fixture-local faults took the new versions so their fixtures load:
   `fixture-dropped-index`, `fixture-random-page-cost` (postgres 0.4.0),
   `fixture-job-every-minute` (scheduler 0.2.0).
3. The scheduler program's `VERSION` is "0.2.0" with `technology.version`.
4. The other bricks' stack tests and `docs/gm.md` prose naming the
   postgres or bastion 0.3.0 image take 0.4.0; "0.3.0 (or later)" stays.
5. `.tech` untouched (G6).
6. `governance.classes.<class>.locations` is one scalar placeholder
   `<[db/shop] | any>` in the template (the schema can't say "a list or a
   word"); the class key a free placeholder `<personal>`; chunk 2a checks
   both forms and the closed list.
7. `purpose.yaml`: `parts.source`, `target`, `runner` required,
   `consumer`, `receiver` optional; `jobs[].connections` keys free;
   `data_moved[].writes` non-empty. `classification.columns` non-empty;
   `domain.purposes` may be `[]`.
8. Scenario-document skill: v0.4 items conditional, inside the existing
   sections (a Domain row in 1; "Purposes" and "Data governance" in 3
   after Flows; per database node a "Crontab roles" bullet and a "Jobs on
   the node" table; a `judges` line under the sealed check; the policy
   file and classification in 7). It reads a database node's seed
   `crontab`, seed `postgresql.conf` and the data file's
   `cron.schedule_in_database` calls: a second exception to "only
   `scenario.yaml` and the answer key".
9. `brick-gm.md`: a section per database-node job kind after Known limits
   ("## pg_cron", "## The cron daemon"), mirrored in `docs/player.md`.
10. `fault.yaml`: `needs_unshared_host` top-level after `applies_to`;
    the family comment adds `data-flow`; `layouts.md` states the two
    `psql` variables and W1 item 0's data-file reading.

Risks carried: until chunk 2b merges, a job with neither `connection:`
nor `connections:` loads (2b closes it). **Open point sent to
`spec-writer`**: master spec 6.3 lets a purpose fault's seed-file change
edit "a database node's data file", but `seed_changes.file` must name a
seed file the brick declares, and the data file is not one; needed by
the first such fault (wave 3). Old images `postgres:0.3.0`,
`bastion:0.3.0`, `scheduler:0.1.0`, `dbagm-test/scheduler-unit:0.1.0`
remain locally, removable by name.

### Chunk 5 — merged (f172a0e), 2026-10-30

5a 5ff4cef, 5b 17a45d4, merge f172a0e. Schema and load run into
`postgres` (0.3.0 from its worktree) at shifts 0, +2, −5, −11, +12;
grants diffed against 9.7 (70 expected, 70 actual), `shop_etl` refused
`orders.customer_id`; 99 columns classed (17 personal, 5
customer-linked, 77 internal); producer fragments pass the loader's
`_check_queries`/`_check_schedule`/`_check_jobs` (only `intensity:
missing`, left to the scenario) and all 144 statements run as
`shop_app`. Sizes: 20 000 customers (6 580 lapsed, ~3 990 of them
consenting: the win-back segment), 2 000 products, 300 000 orders,
900 000 lines, 17 000 consent events; 10.0 % of orders export. Left for
the wave gate: the unit suite loading the domain (after 2a), and the
domain against 1b's templates.

**W1 addenda — choices chunk 5 made** (accepted):
1. Tarnbeck's planted producer faults are not in the domain (product
   search on `sku`; `delivery_events.event_id` unique, builder `ON
   CONFLICT DO NOTHING`); the 12:00 close of day stays (16.1, R1).
2. The close of day adds the newly invoiced amount to `lifetime_value`
   (older orders archived away, 9.5).
3. `producers/` also holds a `jobs.yaml` fragment (close-day) and
   `builders/carrier_feed.py`, beside W1 item 6's `queries.yaml` and
   `schedule.yaml`: **chunk 2a accepts them** (told in its brief).
4. Classification: `customers.id` and `mail_outbox.customer_id`
   personal (beside a direct identifier, 11.2); `marketing_opt_in` and
   all of `consent_events` personal; all of `leads` customer-linked;
   `ship_country`, `created_at`, `last_order_at`, `lifetime_value`
   internal (9.9).
5. Grants: `shop_refresh` `MAINTAIN` only (a refresh runs as the view's
   owner); `shop_customs` reads customers' `(id, name, address,
   country)`; purpose roles' writes are `INSERT` only, no sequence
   grants (identity columns); a purpose needing `UPDATE` (on `etl_runs`)
   appends the grant in its own source material.

For later chunks (also in `domains/shop/docs/gm.md`): the campaign is
`segment = 'winback'`, code `winback-<yyyy-mm>`, 28 days from the load
day; `leads`, `mail_outbox`, `customs_*`, `incidents`, `etl_runs` start
empty (chunk 11's `mail-shipped` must not take "since the last run" as
the ~290 000 historically shipped orders); the consent history is
quieter in its last weeks than the producer's rates from T0 (a jump at
T0, told as the campaign launch); export packing rate unmeasured until
the rehearsal.

### G12 written in: build plan v5 (af51b8f), 2026-10-30

`spec-writer`: **D224** (the owner's ruling, O134 closed: the web front in
every v0.4 game, its home page the starter-pack page, linking to the
scenario's web interfaces when there are any; port 8080 always published,
the tools password always handed over; D103 no longer applies), **D225**
(chunk 19 split: 19a the bastion, beside chunks 2 to 4; 19b the loader's
port rule in `_check_web_routes`, the port added to `bookshop-new-server`,
`fixture-audit` and `fixture-v03-refusals` with their READMEs, `smoke.sh`'s
four `fixture-audit` assertions reversed, the two skills; 19b starts only
once chunk 2 has merged and chunk 19's branch has taken `v0.4-w1` in),
**D226** (chunk 1's open point: a seed-file change may name `data`, the
target node's `data.file`, refused on a node without one; carried by
chunk 15a). Forward notes: **O135** (v0.5: a common Caddy, a setup-wide
homepage, a reporting tool on the page), O130 widened (the provider's own
entry point, after v1.0). Render and the hand-over code need nothing.
Master spec, access model, formats.md v24, planes-and-access.md v18
amended. Chunk 18 now rewrites the GM skill's "no front" lines. No new
gate. Chunk 19 is dispatched at the first free slot under κ = 3.

### Chunk 2 — merged (5767878), 2026-10-30

2a adaa457 (merge 6e50d70, before 2b, D220), 2b 8630345 (merge 5767878).
Unit suite 658 → 720 (2a) → 745 (2b), OK in the wave worktree. New
fixture `tools/tests/fixtures/fixture-v04-refusals/` (scenario-local
`postgres` 0.4.0, `scheduler` 0.2.0, `bastion` 0.4.0 — the catalog
bastion has no `data-policy.md` until chunk 19 — and a test catalog root
`catalog/` with purpose `fixture-sales-copy` and domain `fixture-shop`).
`domains/shop/` loads in the suite (chunk 5's left-over item closed). No
Docker used.

**W1 addenda — choices chunk 2 made** (accepted):
1. Loader fix: `_inline_comment` treats a quote as opening a string only
   where a value starts (a placeholder with an apostrophe hid the
   `# optional` comment); only `purpose.yaml` `parts.consumer` changed
   (to optional) across every template's schema.
2. Domain `producers/` accepts `queries.yaml`, `schedule.yaml`,
   `jobs.yaml` and `builders/`, refuses anything else (`scripts/`
   included); fragments' top-level keys checked; the queries fragment
   gets the full repository check.
3. Purposes: `gm.md` required; `material/` unchecked; an invariant's
   `check` a file under `checks/`; `data_moved` one entry per job;
   `run_column` only with `table`; a trace `file` absolute;
   `jobs[].connections` values unchecked.
4. Governance: a reader a role any data file of the scenario creates;
   the game's own roles refused as readers by name; `outbox`
   `<node>/<database>/<table>`, table unqualified; `separation` only
   `instance`.
5. Locations: node part per the node-name rule; database
   `[a-z_][a-z0-9_]*`.
6. Data files: quoted or mixed-case names not counted; only statements
   starting a line (W1 item 0).
7. Faults: `check_fault_dir(…, catalog_root=None)` checks
   `applies_to.purposes` in the catalog; helper `model.fault_judges()`;
   a seed-file fault changing an optional seed file the target node
   doesn't seed is refused (generic).
8. Jobs: a job with an unknown key or unreadable repository must have
   exactly one of `connection:` and `connections:`.
9. Cron subset: hour items `n`, `a-b`, `*/s`, `a-b/s`; `*` only alone;
   `n/s` refused. Crontab: blank, comment and `NAME=value` lines skipped;
   an entry is five time fields and a command.
10. `pg_cron`: created without `cron.database_name` refused; preloaded
    without being created loads (a fault may remove the preload).
11. The query entry-forms error ends "…, a builder (builder) or a script
    (script)".
12. Test helper `RefusalAsserts` gains `catalog_root` and `load()`.

Left for the wave gate: the loader does not check a governance
scenario's `host all gm_check samenet scram-sha-256` line (W1 gives it
to the format skill). **Gate note**: `py_compile` inside a seed folder
(`scripts/`, `builders/`) leaves a `__pycache__` the loader refuses; the
gate compiles with `PYTHONDONTWRITEBYTECODE=1`.

### Chunk 3 — merged (b34d375), 2026-10-30

3a 7536550, 3b 1b5d7ba, merge b34d375 (after chunk 2's bff4dc4). Unit
tests in the image 71 OK; stack test 133 PASS, 0 FAIL (~18 min); tools
suite 745 OK on the merged wave branch; image 171MB. Tarnbeck's smoke
run left for the wave gate.

### Capture W1-y — chunk 3 outcomes (`scheduler` 0.2.0; read by 10, 11, 12, 14)

Recorded 2026-10-30 by chunk 3's owner from the code on
`v0.4-c3-scheduler` (7536550, 1b5d7ba; merged b34d375): what W1 item 7
left to the brick, as built and tested. v0.3's W1-y holds except where
noted.

- **Brick lines.** `roles: [producer, consumer, transformer]`.
  `seed.files` gains `scripts/` after `builders/`; `seed.paths`
  `scripts/: /srv/scheduler/repository/scripts`, on the volume
  `repository`. `protected_files` gains `/usr/local/lib/gm/check-runs`.
  No package, no new secret; `footprint` unchanged. The entrypoint seeds
  `scripts/` once, as `builders/`; a node seeded by 0.1.0 has no
  `scripts/` and needs none. `restore` gives `scripts/` the write
  policy's owner and modes (`2775`/`0664` fixable, `2755`/`0644`
  otherwise).
- **Program checks** (`check`, `check-keys`, start, reload): exactly one
  of `connection:` (any key but a script) and `connections:` (a script
  key); `connections` a non-empty map, names `[a-z][a-z0-9_]*`, values
  connections of the schedule. Messages:
  - `jobs.yaml: job <j>: key <k> is a script: name its connections with connections:, not connection:`
  - `jobs.yaml: job <j>: key <k> is not a script: it takes connection:, not connections:`
  - `jobs.yaml: job <j>: connections.<name>: connection <c> is not one of the schedule's`
  - `queries.yaml: key <k> is named by the schedule but is a script: a script runs only as a job` (a stream or a timeline `set.key` naming a script key)

  Exit codes as v0.3 (`run` 3, the checks 1). `streams: []` runs. The
  cron parser accepted every numeric 5-field form already, W1 item 0's
  hour field included.
- **The call.** `<function>(conns, options, log)` in a daemon worker
  thread, one per run (`gm_scheduler/scripts.py`). `conns`: one psycopg 3
  connection per name, as the schedule's role for it with its
  `role_<role>_password`; `autocommit=False`, `application_name` the
  node's hostname, `prepare_threshold=None`, `connect_timeout` 10 s; one
  connection per name per run whatever the connection's `pool:`.
  `options` a copy of the entry's. The runner closes every connection
  after the call (anything uncommitted rolls back). The return must be an
  `int` ≥ 0 (not a bool), else `error=TypeError`. A program stopping
  mid-run does not wait for the thread.
- **Log lines.** Connections opened first; one failing: `error key=<k>
  job=<j> sqlstate=<S> message="..."`, then `skip job=<j> key=<k>
  at=<due> reason=connection-refused`, no `run` line. Otherwise `run
  job=<j> key=<k> phase=start`, then `run ... phase=end status=ok
  rows=<n> ms=<x>`, or on an exception `error key=<k> job=<j> sqlstate=<S
  or -> message="<primary message>"` (or `message="script: <Class>:
  <text>"`) then `run ... phase=end status=error sqlstate=<S> ms=<x>`
  (with an SQLSTATE) or `status=error error=<Class> ms=<x>`. `skip ...
  reason=still-running` while a run goes. `log(text)` writes `<instant>
  script job=<j> <text>`, control characters turned to spaces; **the
  text is free, never parsed as fields — the one exception to v0.3
  W1-y's grammar**: readers take the event from the second word
  (`gm_scheduler.textlog.parse_line`), so a script's text never passes
  for a `run` line. Writes serialised by a lock.
- **`/run/scheduler/loaded`.** v0.3's lines unchanged; `file <sha256>
  <path>` lines cover every regular file in `scripts/` too (`pending` and
  the faults' checks see a script changed but not reloaded). New: one
  `cron <job> <zone> <at>` line per job, its time as loaded (`cron
  rollup-hourly UTC 5 * * * *`). `gm-reload-scheduler` and `pending`
  still parse only `job`/`file` lines.
- **The checks' means**: `/usr/local/lib/gm/check-runs`, root `0700`,
  run as root on the node (`gmctl exec --user root`):
  - `check-runs runs <job> <since>`: one line per run whose `run ...
    phase=end status=ok` line is strictly after `<since>` (UTC
    `YYYY-MM-DDTHH:MM:SSZ` **only**), oldest first, `<start> <end>
    rows=<n> ms=<x>`; whole seconds, truncated; `<start>` `-` without a
    start line; nothing when none; a run started before `<since>` is
    listed (its start shows it).
  - `check-runs last-reload`: the instant of the last `reload status=ok`,
    or nothing.
  - `check-runs since <since>`: the later of `<since>` and the last
    reload (12.1; added beyond the chunk's three).
  - `check-runs next <job>`: `<instant> remaining=<s>` (rounded up), from
    the loaded `cron` line by `gm_scheduler.cron`, never the live
    `jobs.yaml`; `never` when the time never comes.
  - Exit 0 done; 1 for `next` of a job not loaded; 2 when it cannot run
    (not root, a bad argument or instant, the log or loaded file missing),
    one `check-runs: ...` line on stderr. Reads only the log and the
    loaded file. Trace rows tie to a run by its start and end, or by
    `etl_runs` id.
- **Footprint at rest** (stack test, armenelos, 2026-10-30): scheduler
  node idle 17M of 128M (program RSS 25M), two streams 26M (RSS 35M);
  transformer node (no stream, one script job) idle 17M (RSS 25M), after
  its run 27M (RSS 35M), volumes ~56K; log 4597 bytes (51 lines) in 13
  min. Within master spec 7.1; `brick.yaml` unchanged.
- **Tests.** `run-in-image.sh` creates roles `shop_etl`, `bi_etl` and
  database `reporting`; the stack test adds the transformer node and
  `fixtures/scripts/rollup.py`.

Carried: chunk 8b passes `CHECK_SINCE` as `YYYY-MM-DDTHH:MM:SSZ` or
`check-runs` exits 2; `check-runs` reads the whole log per call (fine at
the measured growth, slower over a long aging).

### Chunk 4 — merged (da6d300), 2026-10-30

4a 449f4ec, 4b 606cee0, `v0.4-w1` taken in b44a0e5 (2a, 2b, 3), merge
da6d300 (D220 order kept). Stack test 211 PASS ("all checks passed",
two containers, ~5 min longer than 0.3.0's: it waits for real cron
minutes); unit suite 745 OK; `cve-watch check` nothing new. Resolved for
G6: `postgresql-18-cron` 1.6.8-1.pgdg13+2 (pinned, asserted), `cron` and
`cron-daemon-common` 3.0pl1-197 (unpinned); `postgresql-18` 18.6-1.pgdg13+2
and `pgbadger` 13.2-1.pgdg13+1 unchanged; image ~262MB.

**Outside its Files line** (accepted; chunk 6 to add a dedicated test):
`tools/gm/localimpl.py` `seed_entries` skipped no optional seed file and
raised `KeyError: 'crontab'` for every postgres node not mapping one (312
unit errors once `crontab` was in `seed.files`); the two-line fix skips an
entry of `seed.optional` the node leaves out, W1 item 4's stated
behaviour. `test_fit`, `test_render`, `test_snapshot`, `test_teardown`
updated for the `cronspool` volume. Chunk 19 told to take it from
`v0.4-w1` rather than repeat it.

### Capture W1-x — chunk 4 outcomes (`postgres` 0.4.0; read by 6, 7, 9, 12, 15)

Recorded 2026-10-30 by chunk 4's owner from the code on
`v0.4-c4-postgres` (449f4ec, 606cee0; merged da6d300). v0.3's W1-x holds
except where noted.

- **Packages.** `postgresql-18-cron=1.6.8-1.pgdg13+2` (ARG
  `PG_CRON_PACKAGE`, `dpkg-query` assertion) and Debian `cron`
  3.0pl1-197 (unpinned), both in the PGDG `apt-get install`; `postgres`
  stays 100:102. New group `crontab` (gid 997); **`pgconf` is now gid
  996** (was 997; nothing refers to it by number). The image removes
  `/etc/crontab` and every entry but `.placeholder` in `/etc/cron.d` and
  `/etc/cron.{hourly,daily,weekly,monthly,yearly}`; it appends `session
  optional pam_umask.so umask=0022 nousergroups` to `/etc/pam.d/cron`
  (Debian's USERGROUPS umask 0002 let the players' group write job logs);
  `pam_loginuid` left as shipped (jobs run with it).
- **The cron service.** s6 longrun `cron`, `dependencies.d/{base,postgres}`,
  in the `user` bundle; SIGTERM. Without `/opt/gm/seed/crontab` the run
  script prints `cron: this node seeds no crontab; the cron daemon does
  not run`, runs `s6-svc -O .`, exits 0 (`s6-svstat -o up,wantedup` reads
  `false false`); otherwise `exec /usr/sbin/cron -f` as root. s6-rc stops
  `cron` before `postgres`; `gm-restart-db` leaves cron running; the
  snapshot never stops it.
- **The crontab.** `/var/spool/cron/crontabs/postgres` on volume
  `cronspool` mounted at `/var/spool/cron/crontabs`. Installed once, in
  the seed-marker block, by `crontab -u postgres /opt/gm/seed/crontab`
  (not copied: Debian's `crontab -l` hides the first three lines when
  they are comments, and `crontab` checks the syntax; a refused seed fails
  the container; Debian's 3-line header is added, hidden by `-l`). Every
  start: the spool `root:crontab 1730`, the crontab (a regular file, not
  a symlink) `postgres:crontab 0600`. Log line: `gm-entrypoint: seeded
  postgres's crontab /var/spool/cron/crontabs/postgres from
  /opt/gm/seed/crontab`.
- **The password file.** `/run/gm-cron/pgpass`, directory
  `postgres:postgres 0700`, file `0600`; one `*:*:*:<role>:<password>`
  per `/opt/gm/secrets/role_<role>_password`, `\` and `:` escaped; role
  `[a-z_][a-z0-9_]*`, secret non-empty single line, else the container
  fails; absent when no such secret is mounted. Log line: `gm-entrypoint:
  crontab password file /run/gm-cron/pgpass written: <roles>`.
- **The cron log directory.** `/var/log/postgresql/cron/`, created at
  every start when missing (anything else there, a symlink included,
  removed first), `postgres:pgconf 2750` setgid; a job's files `0644`,
  group `pgconf`.
- **`gm-crontab`**, `/usr/local/sbin/gm-crontab`, root 0755, protected;
  the sudoers line ends `..., /usr/local/sbin/gm-crontab` (no `""`).
  - `-l`: `crontab -u postgres -l`; exit 0, or 1 with `no crontab for postgres`.
  - `<file>`: on a node without `/opt/gm/seed/crontab`, exit 1,
    `gm-crontab: this node runs no cron daemon (its scenario seeds no
    crontab); nothing installed`. Otherwise `runuser -u player -- cat --
    <file>` into `/run/gm/gm-crontab.XXXXXX` (root 0600, removed on exit;
    a read failure exits 1, `gm-crontab: cannot read <file> as player; the
    crontab is unchanged`), then `crontab -u postgres <work file>` (a
    refusal exits 1, crontab's lines then `gm-crontab: crontab refused
    <file>; the crontab is unchanged`); success exits 0, `gm-crontab:
    <file> installed as postgres's crontab; cron reads it within the
    minute.`
  - No argument, two or more, any other `-option` or a lone `-`: exit 2,
    `usage: sudo gm-crontab -l | sudo gm-crontab <file>`; a caller other
    than root: exit 2.
- **`check-psql`'s other-node form.** `/usr/local/lib/gm/check-psql
  --node <node> [psql options and arguments]`, `--node` first; `<node>`
  `[a-z][a-z0-9-]*`, not ending in `-`, ≤ 63 characters, else exit 2
  `check-psql: --node <x>: not a node name`. Runs `psql -X -w -h <node>
  -p 5432 -U gm_check "$@"` with `PGCONNECT_TIMEOUT=10`, the same
  root-only secret and temporary passfile, the same exit codes (psql's 2
  for an unknown or unreachable node). Needs the other node's `host all
  gm_check samenet scram-sha-256`. The local form unchanged.
- **The victim.** `s6-rc.d/postgres/run` exports
  `PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj`,
  `PG_OOM_ADJUST_VALUE=300`; measured: every postmaster child at 300; the
  postmaster, s6, `sshd`, `cron` at 0.
- **`brick.yaml`** as W1 item 8: `seed.files [postgresql.conf,
  pg_hba.conf, crontab]`, `seed.optional: [crontab]`,
  `seed.paths.crontab: /var/spool/cron/crontabs/postgres`; volume
  `cronspool`, `snapshot.cronspool: copy`; `gm-crontab` in
  `sudo_wrappers` and `protected_files`; `processes`, `writable_paths`
  unchanged; a comment for the crontab roles' secrets.
- **Footprint at rest** (stack test, armenelos, Docker 29.9.1,
  2026-10-30, 512M limit, two runs): `db` 32.2–32.6MiB, ≤0.02 CPU; `db2`
  with pg_cron (a job every 5 s) and cron (an entry a minute)
  28.8–30.9MiB, 0.03 CPU; cron 2.5MB resident; the pg_cron launcher
  16.7–16.9MB resident, mostly shared memory. Default footprint unchanged.
- **Render** (chunk 6's code, applied here): `localimpl.seed_entries`
  skips an optional seed file the node does not map.

Known limit (documented in `docs/gm.md`): with no `cron.allow` (D211),
any OS user may run `crontab`, so `player` could install a crontab of
its own, run as `player`.

### Chunk 19 — merged (c15ff5b), 2026-10-30

19a 4a6f936, 19b cb82f3b, merge c15ff5b (branch fast-forwarded to
da6d300 first, so chunk 4's `seed_entries` fix was taken, not
repeated). Stack test 89 PASS, 0 FAIL; unit suite 746 OK; `bastion`
0.4.0 builds with G13's three assertions. Resolved for G6: `cmark-gfm`,
`libcmark-gfm0.29.0.gfm.13`, `libcmark-gfm-extensions0.29.0.gfm.13` at
0.29.0.gfm.13-4 (trixie/main, unpinned), image 185.1 → 185.6 MB.
Outside its Files lines (accepted): `test_fit`, `test_render`,
`test_deploy`, `test_state` follow `fixture-audit`'s new shape
(`test_state`'s no-port test turned round so `state.py`'s hiding branch
stays covered); the bastion stack file gives `db` the `cronspool`
volume. `fixture-v04-refusals` keeps its now-redundant local bastion.
The four READMEs changed only in "Published ports" (not fully
regenerated: re-checked at the gate). For chunk 18: `game-master/SKILL.md`
lines 98-99 (no front, no tools password) and 1191 ("the second lists
the routes"; `/` is now the page).

### Capture W1-z — chunk 19 outcomes (`bastion` 0.4.0's page and front; read by 13, 16, 18)

Recorded 2026-10-30 by chunk 19's owner from the code on
`v0.4-c19-bastion` (4a6f936, cb82f3b; merged c15ff5b).

- **Paths.** At every start, routes or none, `gm-entrypoint` writes
  `/run/web-front/` (root:www-data 0750): `nginx.conf` (0444), `htpasswd`
  (0440, user `player`), `www/index.html` the page (root:www-data 0440),
  `www/not-found.txt`, `www/routes/<name>/` per route. The page is
  rendered from `/opt/gm/starter/` (as handed over, never the home
  copies) by `cmark-gfm -e table` in safe mode (raw HTML becomes a "raw
  HTML omitted" comment; never `--unsafe`). `README.md`, `story.md`,
  `issues.md` required (a missing one fails the container);
  `data-policy.md` optional, copied once to `/home/player/data-policy.md`
  when mounted.
- **Form.** One HTML5 page, UTF-8, at `/` behind auth_basic like every
  path: a small inline stylesheet; a header saying this is the starter
  pack as handed over (the player's own copies in their home), then a
  `<nav>` linking the sections present; one `<section id="<id>">` per
  element present, in order `readme`, `story`, `issues`, `data-policy`,
  `web-interfaces` (`<h1>Web interfaces</h1>`, one `<a
  href="/<route>/">` per route, sorted). An absent element leaves no
  section and no nav link.
- **The front's home.** With web interfaces: the starter sections, then
  `web-interfaces`; `/<route>/` proxies as before, `/<route>` redirects.
  Without: the same page with no `web-interfaces` section or link; the
  front up on 8080, published `{port: 8080, default: 8080}`, the tools
  password read and handed over. The loader refuses a bastion without
  that port, routes or none.
- **How a later element joins.** One list, `PAGE_ELEMENTS` in
  `gm-entrypoint`, a line per element `<kind> <id> <source> <title>`;
  kind `markdown` present when `/opt/gm/starter/<source>` exists, kind
  `routes` when `GM_WEB_ROUTES` has a route. A reporting tool (O135)
  joins by one line; a new kind adds its branch in `page_element`, which
  prints the section or returns 1 when absent.
- **Footprint at rest** (stack test, armenelos, Docker 29.9.1, idle,
  2026-10-30): container 5.1 MiB with routes, 4.9 MiB without (v0.3
  without routes 2.8 MiB, no nginx); nginx resident 12.6–12.8 MiB with
  routes, 12.1 MiB without; the page a few KiB on `run`; `cmark-gfm` only
  at start-up, ~860 KiB of image. `brick.yaml`'s figures unchanged.

Carried: `smoke.sh` now needs host port 8080 free; a `cmark-gfm` failure
on a starter file stops the bastion (its log says why); an untagged
earlier bastion image (`sha256:efc56233…`) is left, removal by name only.

### G6 — dependency post-change check (security-advisor, 2026-10-30)

**Clear; nothing for the owner.** Versions confirmed by `dpkg-query` in
the three images (Debian 13.7): postgres 0.4.0 `postgresql-18-cron`
1.6.8-1.pgdg13+2, `cron`/`cron-daemon-common` 3.0pl1-197; bastion 0.4.0
`cmark-gfm` and its two libraries 0.29.0.gfm.13-4; scheduler 0.2.0 no
package change. No open advisory on the new packages; `cve-watch check`
finds the same 60 keys before and after (42 at medium or above, all
already open items in `SECURITY_TODO.md`: NVD matches on Debian-patched
OpenSSH, nginx, Python, sudo). `.tech` updated (71ab68a): bricks list,
`[stack]` runtime/data/rendering lines, platform entries for pg_cron
1.6.8 and cron 3.0pl1-197 (no CPE) and cmark-gfm 0.29.0.gfm.13 (watch
note: no release since July 2023; PR #394, 2026-09-28, fixes UB in the
autolink extension, unreachable here since only `-e table` is used).
`cve-watch lint` 0. Side note: `pgbadger` 13.2 (since 0.3.0) is not in
`.tech` (no CPE); to add on the owner's word. G6 **done**.

### Wave 1 gate (coding-executor, armenelos, 2026-10-30) — passed

Every step passes on `v0.4-w1` at 4064719; the VPS untouched (`Drain`),
every docker step under the host lock and the sleep inhibitor.

| Step | Result |
|---|---|
| Unit suite (`PYTHONDONTWRITEBYTECODE=1`) | 746 OK, 121 s |
| Scheduler unit tests | 71 OK, 214 s |
| `sh -n` / `perl -c` / `py_compile` | 127 / 7 / 40 files, 0 fail, no `__pycache__` left |
| Seven builds | all rc=0 |
| Stack tests (pass/fail) | bastion 89/0, postgres 211/0, pgbouncer 105/0 (after fix 1), scheduler 133/0, prometheus 131/0, postgres-exporter 103/0, grafana 119/0 |
| `smoke.sh` | 61/0 after fix 2 (first run 58/3) |
| `smoke-monitoring.sh` | 43/43 |
| `smoke-scenario.sh` | bookshop 19/19, fernway 18/18, tarnbeck 26/26 (834 s) |
| `smoke-load.sh armenelos` | 73/73, 415 s; fit 1.1 CPU / 1.22G reserved of 12 CPU / 5043M, disk plan 9.94G of 42G |
| Hand checks | bookshop README matches a regeneration; `domains/shop/` matches the templates (99 classified columns incl. `popular_products`) |

Web front: the smoke scenarios do not check the page; the bastion's
health check needs 8080 listening, and on tarnbeck the page was checked
by hand (401 without the password, 200 with it; README, story, issues,
`/grafana/` and `/prometheus/` links).

Fixes, both from chunk 4's `cronspool` volume, test-only:
- 906c693 — the db node of the pgbouncer, prometheus and postgres-exporter
  stack tests mounts `db_cronspool` (the entrypoint chowns the spool;
  read-only without it), and teardown removes it.
- 4064719 — `smoke.sh`'s fixture-audit counts: 10 game volumes, 8
  snapshot copies (bastion 2, db 6), as `snapshot.cronspool: copy` says.

No brick bump for fix 1: it touches only `bricks/*/tests/`, following the
v0.2 precedent a1ceac5 (prometheus' stack test changed with no bump).
Flagged to the owner in the wave report; the formats rule ("whatever part
of its folder") does not name tests either way.

Image sizes: bastion:0.4.0 186MB, postgres:0.4.0 262MB, pgbouncer:0.1.0
182MB, scheduler:0.2.0 171MB, prometheus:0.2.0 488MB,
postgres-exporter:0.2.0 165MB, grafana:0.2.0 866MB. Builds came from the
cache. smoke-load calls: producer `orders.insert` 42, `orders.lookup` 238
(metrics); consumer `reports.recent` 36, `reports.top-customers` 9. Disk
10 GB free on `/` before and after.

Wave sync: no intent or data register, so no documentalist or
data-steward pass; the dependency post-change check is G6 (above).
Gate logs: the session scratchpad's `gate-w1/` (not kept).

### Wave 1 closed — merged into `main` as 5f32304, 2026-10-30

Merged `--no-ff` under the owner's leave to run all waves; not pushed.
`doc-ids compare main v0.4-w1`: 0 collisions. The wave worktree and the
branches `v0.4-w1`, `v0.4-c{1-formats,2-loader,3-scheduler,4-postgres,5-shop-domain,19-bastion}`
removed. Left for the owner's word: whether `bricks/*/tests/` changes
need a bump (the gate's fix 1, above); adding `pgbadger` to `.tech` (G6).

## Wave 2 — started 2026-10-30

Chunks 6, 7, 8, 9, 10, 11. `v0.4-w2` cut from `main` at 5f32304, worktree
`/home/bastien/work/db_audit_gm-wt/v0.4-w2`. No intent or data register:
no preflight. No new dependency named by any wave 2 chunk.

### Gates checked at the start

- **G3** (hand check): Debian trixie, PGDG trixie-pgdg and the
  s6-overlay releases answer 200.
- **G4** (hand check): armenelos `Ready Active Leader`; `vps-5718ad52`
  `Ready Drain`.
- G8, G9 done (spec D217, D218). **G7** waits for the gate's two-host run.
- Host: 10 GB free on `/`, 4.9 GiB of memory available, 3.0 GiB of
  swap in use; running: `ollama`, `llmward-homepage`,
  `llmward-dlp-metrics`.

### Capture W2 — render and `load-data` across chunks 6 and 7

The in-wave edge `6 ──> 7` is already fixed, before any wave 2 code, by
W1 and W1-x; nothing is left open, so W2 cites them:
- the cron subset render shifts and how (W1 item 0, "Cron times in
  scenario time"); `pg_cron` schedules stay unshifted (8.5);
- `{{customer_timezone}}` outside the starter pack as the bare zone,
  `render.zone_name` (W1 item 0);
- `load-data`'s `-v customer_timezone=<zone> -v customer_utc_offset=<n>`
  (W1 item 0, chunk 7 writes);
- the crontab roles' secrets `role_<role>_password`, derived and mounted
  by render at `/opt/gm/secrets/role_<role>_password` 0:0 `"0400"`, one
  per role per game, shared with any scheduler node naming the role; the
  passwords set by `load-data` for every role a schedule or a
  `crontab_roles` names (W1 item 8);
- the password file, the baseline crontab entry and the log directory as
  built (W1-x).

Chunk 7 records as built, as **W2-x** (read by 12, 15): the
mapping-roles function's name and signature and the read policy's form.

### Order and dispatch

κ = 3. First: chunks 6 and 8 (unit-only, no shared file) and chunk 9
(the calibration, holding the host lock for its run, the VPS drained).
Chunk 7 is cut once chunk 6 has merged; chunks 10 and 11 take the next
free slots (their scheduler unit-test harness runs under the lock).

Carried into the briefs: chunk 6 adds a dedicated unit test for
`localimpl.seed_entries` skipping an optional seed file a node doesn't
map (chunk 4's fix); chunk 8b passes `CHECK_SINCE` to `check-runs` as
`YYYY-MM-DDTHH:MM:SSZ` (W1-y); D219's widened cron subset (chunks 6, 11).

### Chunk 6 — merged (30e8c59), 2026-10-30

639e08c, merge 30e8c59. Unit suite 763 OK (15 new render tests, red
before, green after). `cron_hours`/`shift_cron` cover D219's subset
(hours expanded, shifted −shift mod 24, written back as a sorted list;
`*` kept; day-of-week carry unchanged); new `render_crontab` keeps every
other character, comments, `VAR=` lines and blanks, adds no header. The
bare zone (`render.zone_name`) goes into a scheduler node's files
(before YAML parsing) and a postgres node's `postgresql.conf`; the
bastion keeps the text form. `role_<role>_password` declared for each
`crontab_roles` entry at `/opt/gm/secrets/`, 0:0 `"0400"`, one shared
secret with a scheduler naming the same role. The loader refuses the
placeholder in a postgres `postgresql.conf` of a scenario without a
scheduler. Every v0.3 scenario and fixture renders byte-identical at
−2, 0, +5; chunk 4's optional-seed skip has its own test.
Not substituted (choice): the placeholder in a crontab or `pg_hba.conf`.
For chunk 7: `inject.password_plan` does not yet set crontab-only
roles' passwords. For chunk 18: `gmctl.md`'s `render` paragraph (about
line 128) still describes v0.3's files. Risk: a game fitted before this
change on v0.4 content gets "fit again".

### Chunk 8 — merged (6d88c58), 2026-10-30

8a bde3c70, 8b 33bfb36, merge 6d88c58 (on 2f7bcf6; `test_render.py`
merged cleanly). Unit suite on the merged wave branch: 776 OK. No docker,
no VPS. `--host …,shared` parsed, written to `playground.yaml` only when
given; a node needing an unshared host is refused on a shared one, with
the `--map` hint, and a playground of shared hosts only is refused.
`CHECK_SINCE` is the planting moment before the hand-over and the first
hand-over after it (also after a restart); `--since` (and a repeatable
`--instance`) raises it per instance, refused in the future, malformed,
with no judging instance, or with `--early-check`/`--handover-check`.
Exit 3 names the next run and the judged moment. v0.3's fit and check
texts unchanged. The VPS is marked `shared` in `rehearsal.sh`'s and
`smoke-load.sh`'s two-host examples (the latter added).
Outside the Files line (accepted): `test_render.py`'s `two_hosts()`
helper. Choices: an unplanted judging instance is refused before
anything runs; gmctl only passes `CHECK_SINCE`, the check raises it to
the runner's last reload (`check-runs since`, W1-y).
For chunk 18: `gmctl.md`'s `fit` (`,shared`) and `check` (`--since`,
`--instance`) lines. For the wave gate (a `coding-executor`, own
commit): `aging.run_check`'s hand-over check failure text still says
"N s of its window remain" for a too-soon judging check (wording only).
Risk: a hand-edited or pre-v0.3 state without `plantings` gets a
refusal, not a guess.

### Chunk 9 — merged (17be068), 2026-10-30

396f4be, merge 17be068. Files: `tools/tests/calibrate-f10.sh`,
`tools/tests/fixtures/calibrate-f10/` (`db` with the shop domain's data;
`reporting` at 512M / 256M, `shared_buffers` 128MB, `pg_cron`, the
foreign server `shop`, `bi_etl`'s mapping to `shop_etl`, the foreign
tables with the close's columns only, `rpt.etl_runs`,
`rpt.sales_detail_backfills`, `rpt.sales_detail`, the draft
`rpt.sales_detail_rollup()`: one `jsonb_agg` element per order, kept in
`reporting`'s backend by a materialised CTE, checked with EXPLAIN
VERBOSE; crontab `0 3 * * *` calling it as `bi_etl`). Each run caused by
a backfill request row and the entry's time moved through `gm-crontab`;
the procedure never called by hand. Measured from the host: the cgroup's
`memory.peak`, `memory.swap.peak`, `memory.events`, 0.1 s samples, and
the backend's peak RSS (`log_statement_stats` set on `bi_etl` at setup,
GM-side). Three runs under the lock and the script's own inhibitor; the
VPS Ready/Drain throughout, never reached; nothing pruned; teardown
clean. `sh -n` OK, PyYAML OK, unit suite 746 OK.

**Figures** (armenelos, Docker 29.9.1, 2026-10-30, limit 512M,
`shared_buffers` 128MB, MiB; "need" = anon + shmem + swap, or baseline
plus the backend's peak RSS when larger; raw peak includes page cache):

| UTC | Setting | Run | Days | Orders / lines | Outcome | Raw peak | Swap peak | Need |
|---|---|---|---|---|---|---|---|---|
| 19:44 | swap | normal | 1 | 35,817 / 109,603 | completed | 299 | 0 | 252 |
| 19:46 | swap | backfill | 2 | 55,790 / 169,524 | completed | 414 | 0 | 355 |
| 19:48 | swap | backfill | 4 | 95,762 / 289,409 | completed | 512 | 45 | 549 |
| 19:50 | swap | backfill | 6 | 135,730 / 409,332 | completed | 512 | 356 | 826 |
| 19:52 | swap | backfill | 8 | 175,707 / 529,275 | completed | 512 | 489 | 946 |
| 19:54 | swap | backfill | 10 | 215,699 / 649,235 | **killed** | 512 | 512 | ≥992 |
| 19:56 | noswap | normal | 1 | 35,652 / 109,107 | completed | 301 | 0 | 250 |
| 19:58 | noswap | backfill | 2 | 55,622 / 169,014 | completed | 416 | 0 | 353 |
| 20:00 | noswap | backfill | 4 | 95,618 / 289,000 | **killed** | 512 | 0 | ≥450 |
| 20:03 | swap | normal | 1 | 35,819 / 109,607 | completed | 300 | 0 | 252 |
| 20:05 | swap | backfill | 30 (whole history, 14.9) | 300,000 / 900,000 | **killed** | 512 | 512 | ≥983 |

Growth ~5.2 KB per order (whole history ≈ 1.55 GiB needed against 1 GiB
of limit plus swap). Page cache of a normal run 87–90 MiB. Every kill:
`oom_kill` +1, the four PostgreSQL lines, connections back within 0–1 s,
the postmaster, s6-svscan, sshd and cron keep their pids, the job's log
ends "connection to server was lost". Completed documents 2–12 MiB.
Host MemAvailable never below 4.18 GiB. Full table and samples:
the session scratchpad's `calib1/`, `calib2/` (not committed).

Notes for chunk 15: the night after a killed backfill reads ~2 days
(~355 MiB need, completes, above half); without foreign-table statistics
every run fetches all of `order_lines` and `products` (only the orders
filter is pushed down); the no-swap container's secrets are bind-mounted
test files (calibration only).

### G10 — applied by the driver, 2026-10-30: to the owner

- **Backfill side: holds.** Every window of 10 days and more is killed
  with swap; the scenario's thirty-day request reads the whole history
  (14.9 days) and is killed. The window can stay as designed.
- **Normal-run side: a shortfall on the spec's own measure.** Master
  spec 16.3 names "the cgroup's `memory.peak` around a normal run": it
  reads 299–301 MiB, over half the limit (256). Only on chunk 9's
  reading (non-reclaimable memory, page cache excluded, `shared_buffers`
  touched included) does it pass, 252 against 256, a 4 MiB margin that a
  night of ~36k+ changed orders, or the night after a killed backfill
  (~355), crosses. G10's rule sends a shortfall to the owner before
  anything is reshaped. It blocks chunk 15's f10 half and chunk 16, not
  wave 2.
- Chunk 9's observation for the lever: a limit of about 464–800 MiB
  satisfies both sides at the whole-history window, ~640M near the
  middle (raw 300 < 320; ~1.55 GiB > 1.25 GiB).

### Capture W2-x — chunk 7 outcomes (read by 12, 15)

Recorded 2026-10-30 by chunk 7's owner from the code on
`v0.4-c7-load-data` (`tools/gm/inject.py`), checked in the `postgres`
0.4.0 image and on the `fixture-instances` deployment (armenelos).

- **The steps, in order** (`inject.load_steps`, also a restart's with no
  snapshot): each data file, as before, with `-v
  customer_timezone=<zone> -v customer_utc_offset=<n>` (render's shift;
  `Etc/GMT` and `0` in a game with no scheduler node); the roles'
  passwords (SCRAM verifiers), now also every role a `database` node's
  `crontab_roles` names, on that node; a survey of every database of every
  `database` node (`datallowconn`, not a template; as `postgres`, one
  JSON line per database: `pg_cron` present, foreign servers, user
  mappings); the user mappings' passwords; the check role's read policy
  and mapping-roles function; `CONNECT` for `gm_check` (unchanged, last).
  Policy and function go only to a node whose check role exists (it
  mounts `gm_check_password`), as the grant.
- **A user mapping's password**: per mapping the survey finds,
  `ALTER USER MAPPING FOR "<local>" | PUBLIC SERVER "<server>" OPTIONS
  (ADD | SET password '<secret>')` (SET when one is already there), the
  secret being `role_<remote>_password`, the mapping's `user` option's
  role. Statement logging and `pg_stat_statements.track` are off for the
  session; the password is redacted from anything printed or recorded.
  A mapping with no `user` option, or whose remote role has no secret in
  the game (no schedule's connection and no `crontab_roles` names it),
  fails the setup before this step runs. So the remote role must be named
  by a schedule or a `crontab_roles` (P1's `shop_etl` is, by `bi`'s
  schedule); its password on the remote instance is set by that role's
  own step.
- **The read policy**: in every database holding the extension `pg_cron`
  (in practice `cron.database_name`), on each of `cron.job` and
  `cron.job_run_details`: `DROP POLICY IF EXISTS gm_check_read ON <t>;
  CREATE POLICY gm_check_read ON <t> AS PERMISSIVE FOR SELECT TO gm_check
  USING (true);`. Row-level security is `pg_cron`'s own (enabled, not
  forced, its policies `cron_job_policy` and
  `cron_job_run_details_policy` `USING (username = CURRENT_USER)` for
  `public`); load-data does not change it. Permissive policies add up, so
  `gm_check` (no `BYPASSRLS`, not a superuser) reads every row of both
  tables, through `pg_read_all_data`'s SELECT, and nothing else gains.
- **The mapping-roles function**: `gm_check.user_mapping_roles()`, no
  argument, `RETURNS TABLE (server_name name, local_role name,
  remote_role text)`, `LANGUAGE sql STABLE SECURITY DEFINER SET
  search_path = pg_catalog, pg_temp`, owned by `postgres`; one row per
  user mapping of its database, ordered by server and local role:
  `local_role` is `public` for a mapping for PUBLIC (as
  `pg_user_mappings` writes it), `remote_role` the `user` option, NULL
  when unset; never the password. In every database holding a foreign
  server (`pg_foreign_server` not empty), in schema `gm_check` (created
  `AUTHORIZATION postgres`, `USAGE` revoked from PUBLIC, granted to
  `gm_check`); `EXECUTE` revoked from PUBLIC, granted to `gm_check` only.
  Chunk 12's G3 calls it in each such database: `SELECT server_name,
  local_role, remote_role FROM gm_check.user_mapping_roles()`; the
  server's own options (`host`, `dbname`) are readable by anyone in
  `pg_foreign_server`.
- **For chunks 12 and 15**: both objects are in the instance's data, so
  the hand-over snapshot keeps them and a restart from it needs nothing.
  The players' `dba` may drop either (access model 8, accepted): with the
  policy gone `gm_check` reads no job at all rather than an error, so a
  check reading `pg_cron`'s tables should confirm `gm_check_read` exists
  (`pg_policies`) before trusting an empty answer. The schema `gm_check`
  holds no table (G1's catalog walk finds nothing in it).
- `fixture-instances` (`tools/tests/fixtures/`): `db` (database `shop`,
  crontab role `shop_etl`, entry `crontab-mark`), `reporting` (database
  `reporting`, `pg_cron` jobs `order-count` as `bi_etl` through the
  mapping and `ping` as `bi_reader`, server `shop_db`, `bi_etl`'s mapping
  to `shop_etl`), a bastion, one seed-file fault `f1`; no scheduler node.

### Chunk 7 — merged (38ef427), 2026-10-30

7d2c72e (cut from 6d88c58), merge 38ef427, W2-x 80f9c9d (above). Unit
suite 795 OK on the chunk branch and on the merged wave branch; 19 new
`test_inject` tests (step order, psql variables at a shift, ADD/SET and
PUBLIC mappings, refusals, password redacted on failure, restart path).
Deployment of `fixture-instances` on armenelos, under the lock and the
inhibitor, the VPS untouched: `gm_check` (no BYPASSRLS, no superuser)
read both `pg_cron` tables and both jobs; `gm_check.user_mapping_roles()`
returned `shop_db|bi_etl|shop_etl`, `umoptions` NULL to `gm_check`; the
mapping connected (`src.orders` as `bi_etl`); the crontab entry ran as
`shop_etl` from `/run/gm-cron/pgpass`; `CONNECT` on a database revoking
it from PUBLIC; README regenerated with the scenario-document skill.
Torn down by `gmctl teardown`. Outside the Files line (accepted): two
lines in `tools/tests/__init__.py`; the fixture's copy of
`fixture-audit`'s seed-file fault as `f1`. For chunk 18: `docs/gm.md`
and `gmctl.md` don't yet describe the new `load-data` steps. Risks: two
to four more `docker exec`s per database node on every load, v0.3 games
and restarts included; a hard-coded mapping password is overwritten;
the `gm_check` schema and its policy are visible to players (access
model 8).

### G10 — the owner's ruling, 2026-10-30

Asked with chunk 9's figures (above). The owner chose to **raise
`reporting`'s memory limit to 640M**, its reservation staying 256M: a
normal run's `memory.peak` (~300 MiB) under half of it (320) on the
spec's own measure, the whole-history backfill (~1.55 GiB) above twice
it (1.25 GiB). Chunk 15's f10 run re-measures at 640M. Sent to
`spec-writer` to record and to revise the plan (G10, chunks 15 and 16).

### G10 recorded: D227, build plan v6 (1e543c9), 2026-10-30

`spec-writer`: D227 in `decisions.md`; master spec 16.1 `reporting`
640M / 256M (section 20's 1.85 GB of reservations unchanged); plan v6:
G10 done, chunk 13's `fixture-campaign` and chunk 16's sizes at 640M,
chunk 15b re-measures on `memory.peak` with swap (normal run under 320
MiB, the thirty-day backfill killed), a shortfall either side back to
the owner (D213); release gate item 11. Not edited: the superseded
`scenario-sketch.md` (still 512M); `tools/tests/calibrate-f10.sh`'s
header and `CALIBRATE_LIMIT` default (512M) — chunk 15b's brief passes
`CALIBRATE_LIMIT=640M` or updates them. For the owner, at wave 2's
report: both 640M margins are estimates until 15b (backfill ~1.55 GiB
extrapolated vs 1.25, ~24%; normal ~300 vs 320, ~6%); the night after a
killed backfill (~355 MiB) is over half but completes; 15b re-measures
with swap only (a no-swap reading is a one-line addition if wanted).

### Chunk 10 — merged (1414e3c), 2026-10-30

10a 2ecf66a, 10b 68b2675, merge 1414e3c. `purposes/shop-sales-reporting/`
(`purpose.yaml`; `material/runner/{queries,jobs,schedule}.yaml`,
`scripts/rollup.py`; `material/consumer/`; `material/target/data.sql`;
`checks/r1-reconciled.sh` … `r5-dashboard-faithful.sh`; `gm.md`;
`tests/`), a `purposes/` row in the root README. `check_purpose_dir`
clean; unit suite 795 OK merged (the catalog test fails at 10a alone, by
the split). Scheduler harness at +5: 73 OK (the brick's 71 plus 2), the
real program run by moving `jobs.yaml` times and reloading; published
hours and days equal the source's local ones. `close_day()` at −7 in
`postgres:0.4.0` as `bi_etl`: 20 000 orders, the day's revenue, 192 hour
rows summing to it; `bi_etl` has no USAGE on the server, `shop_etl`
refused `orders.customer_id`. Checks: R1–R4 read 0 clean with a
witness, 3 with `remaining=` after the last run, 1 on crafted violations
(R1 watermark on `placed_at`; R2/R3 a close cut three hours off; R4
`shop_etl` expired); R5 0/1. Harness ~15 min a run, under the lock.

Choices (accepted; for `spec-writer` at the milestone archive if 9.6
should show it): `rpt.business_settings` in `reporting` from
load-data's variables; `rpt.sales_hourly`/`sales_daily` carry `run_id`
(FK to `rpt.etl_runs`), the run column 6.7 and 12.2 need; `close_day()`
recomputes yesterday's hours too, and the hourly script then leaves a
closed day's orders and revenue alone (so f7's evidence persists, 16.2);
R2 compares revenue only; R4's business hours 08:00–20:00 customer time;
`tests/` inside the purpose (the loader ignores it). Fixed in-chunk: R1
read booleans as `t` where `check-sql` prints `True`.

**For wave 3's briefs:**
- R1–R4 run on the runner `bi` (they need `check-runs` and the log),
  R5 on `consumer`; f5 sits on `db` and f7 on `reporting` (16.1), so
  chunks 14 and 15 can't reuse R4 or R3 as they are.
- R1 and R3 read 3 for the rest of a 14:00 hand-over game: their
  witnesses come the next noon (a re-invoiced past day) or the next
  night (the 01:30 close); before the hand-over, judged from the planting,
  they decide. Under f4, R1 reads 1 at the hand-over check (a fixed script
  never restates missed days: that is the *improve*). In `gm.md`.
- Chunk 13's scenario must give `pg_hba` lines for `shop_etl` from `bi`
  and `reporting`, `bi_etl` from `bi`, `bi_reader` from `consumer`, and
  `gm_check` from the network on both instances.
- Risk: the checks' 60 s settle margin assumes no producer transaction
  commits more than 60 s after its `now()` (longest today: the close's
  20 s hold).

### Chunk 11 — merged (d41032c), 2026-10-30

11a 2fda6c4 (P2, P3), 11b 1ae95e6 (P5, the gateway stub), merge d41032c;
the README's purpose row now lists all four purposes. `check_purpose_dir`
clean for all four, `check_domain_dir(shop)` clean; merged runner and
receiver fragments pass the loader's checks; unit suite 795 OK;
scheduler unit tests 71 OK. Every job's SQL ran as its role on the shop's
data at shifts 0, +2, −5; a 33-minute live run at −5 on the real
`scheduler` 0.2.0 programs: every job `status=ok`, the stub 0 errors,
nothing answered twice. The stub: 108 of 5 000 crafted declarations
unanswered (2.2 %), live 2/66 and 5/98, the hash's picks exactly
(idempotency key mod 50 = 0); acknowledgement delay 21.6 s live, bounded
5–35 s. All 12 checks run as `gmctl check` runs them: 0 clean (E4 on
crafted triggers), 3 with `remaining=` (E4 also live while a declaration
is pending), 1 on each crafted violation; `FAULT_JOB` narrows M1, M4.
Fixed in-chunk: L1's race with a checkout's 3 s transaction (orders
placed under a minute before the run ignored; L2, M2 count consent
lacking at the row's time and a minute before); the stub's slots 30 s →
15 s; M5's boolean (`True`, as R1 in chunk 10).

Choices (accepted, in each `gm.md`): the stub answers by 15-second slots
since `customs_gw` cannot read `customs_acks` (access model 9.1); a
restart on a slot boundary may answer a slot twice or skip one, harmless
to the checks; `mail-shipped`'s window `[minute−6, minute−1)` without
reading `mail_outbox` (f1's surface); `declare-exports` looks back 2 h
only; M5 reports a missing notice even if the job hasn't run since; M1,
M4 take an optional `job`; incidents `source = 'customs'`, `ref` the
declaration's id.

**Sent on:**
- **E4's deadline** (master spec 10.4) to `spec-writer`: read literally
  ("an incidents row within 30 minutes of sending") it can't hold for
  the spec's own job, which escalates what is unanswered 30 minutes
  after sending, every quarter hour; chunk 11 reads the 30 minutes as
  the acknowledgement's deadline, the incident due within 30 min + one
  15-minute cycle + 2 min grace (E4's statement, `gm.md`).
- **The shop domain's consent buckets** (chunk 5's `load.sql`): every
  bucket derives from the customer id and they line up, so no lapsed
  customer at +5 h ever has first consent (0, against 200 at −8 h and
  400 at ±1 h). 9.3's "every campaign batch has a witness" fails from
  16:00 to 20:45 company time, and f3 after 16:00 in a 14:00–18:00
  game. To a `coding-executor` on the wave branch, its own commit.
- For the wave gate: the export packing rate (66 declarations in 33 min
  at 16:00 company time, about one unanswered every 25 minutes).

### E4's deadline: D228 (9e3142e), 2026-10-30

`spec-writer` confirmed chunk 11's reading as the spec's intent (10.4's
job table, 8.2, 12.4, D214): the 30 minutes are the gateway's deadline
to acknowledge; the incident is due by the first `escalate-customs` run
after them (45 minutes after sending); a rejection's incident one cycle
after the rejection, no wait; a late acknowledgement doesn't count;
two minutes' grace on each deadline. Master spec 10.4 and 12.4 reworded,
the "Amended after approval" line, D228. Nothing for the owner to rule
(told at the wave report). For the wave gate's fixes: the comment at
`purposes/shop-export-declarations/checks/e4-acknowledged-or-escalated.sh`
lines 17–18 can be read as "30 minutes after the rejection"; the code
(line 128: rejection + 15 + 2 min) is right.

### Shop domain consent fix — merged (f94528c), 2026-10-30

`coding-executor`: 1a8b522 on `v0.4-w2-fix-consent`, merge f94528c.
Cause: in `domains/shop/data/load.sql` the order, country and consent
buckets all hang on `id % 100` and the zone bucket was `id % 20`, so they
lined up (the +5 h zone's only lapsed class never granted). Now the zone
is `(id / 100) % 20`: every zone holds 330 lapsed customers per 5 %
offset, 200 whose latest consent event is a grant, 130 without; zone
shares unchanged (80 %, 5 % ×4). Totals and content hashes unchanged
(20 000 customers, 300 000 orders, 900 000 lines, 15.00 days, 17 000
consent events); P2's leads 4 000 before and after. P3 at shift −6,
16:07 company time: M3's witnesses 0 before, 200 after; simulated every
quarter hour 16:00–20:45 on day 1: min 0 before, 117 after. Day 2's late
batches have no witness either way: the lead pool runs out (P3's
`gm.md`). `domains/shop/docs/gm.md` states the independence and the
figures. Unit suite 795 OK; loads at −6, 0, +3 under the lock.

### Wave 2 gate (coding-executor, armenelos + the VPS, 2026-10-30) — passed

Every step passes on `v0.4-w2` at f35dd40, 22:13–23:21 UTC, every docker
step under the host lock and the sleep inhibitor, one at a time.

| Step | Result |
|---|---|
| Unit suite (`PYTHONDONTWRITEBYTECODE=1`) | 796 OK, 129 s |
| Scheduler unit tests | 71 OK, 200 s |
| `sh -n` / `perl -c` / `py_compile` | 147 / 7 / 44 files, plus 31 embedded Python bodies in 27 shell files; 0 fail, no `__pycache__` left |
| Seven builds | all rc=0 (cache) |
| Stack tests (pass/fail) | bastion 89/0, postgres 211/0, pgbouncer 105/0, scheduler 133/0, prometheus 131/0, postgres-exporter 103/0, grafana 119/0 (as wave 1; 1505 s) |
| `smoke.sh` | 61/0 |
| `smoke-monitoring.sh` | 43/43 |
| `smoke-scenario.sh` | bookshop 19/19, fernway 18/18, tarnbeck 26/26 (~875 s) |
| `smoke-load.sh armenelos` | 73/73, 427 s; fit 1.1 CPU / 1.22G reserved of 12 CPU / 4.78G, disk plan 9.94G of 42G (13.89G with the snapshot) |
| `smoke-load.sh` two hosts (G7) | 73/73, 554 s; armenelos 0.75 CPU / 704M, disk 5.53G of 20G; VPS (`shared`) 0.35 CPU / 544M, disk 3.37G of 10G; overlay 10.20.0.0/24; ports on armenelos only; 4 images copied to the VPS |
| Hand checks | `fixture-instances` README matches a regeneration (the only scenario or fixture whose files changed); four purposes and `domains/shop/` pass their checks |

Fixes (the two listed for the gate, no gate failure):
- 684c031 — `aging.run_check`: a too-soon judging check at the hand-over
  check says "too soon to tell, the job's next run is in N s (…)"; new
  test `test_a_too_soon_judging_check_at_hand_over_names_the_next_run`
  (red before, green after).
- f35dd40 — E4's header comment states the two deadlines (D228).

**G7** (one lock hold, the drain set by a `trap`): pre-check 23:11:30
(`tailscale status` on both, `vps-5718ad52 Ready Drain`, filetstudio.com
200, no game port on the VPS, 23G free); active 23:11:32 (accepted, no
refusal); run 23:11:32–23:20:46, filetstudio.com 200 on all 19 polls at
30 s; drained 23:20:46 (rc=0); post-check: filetstudio.com 200, `Drain`,
0 dbagm containers or `dbagm.game` volumes on the VPS, the site's four
containers with their earlier uptimes, VPS volume list unchanged, 22G
free (the VPS now also holds `scheduler:0.2.0`, 171MB).

smoke-load calls: one host, producer `orders.insert` 28, `orders.lookup`
180, consumer `reports.recent` 36, `reports.top-customers` 9; two hosts
23 / 180 / 36 / 9, PgBouncer 303 transactions. Image sizes as wave 1.
Disk 10G free on armenelos throughout. The smoke scripts run `gmctl`
without `-B`, leaving `tools/__pycache__` (git-ignored; removed). The
bastion's page was not checked by hand this time (the smoke scenarios
don't check it). Logs: the session scratchpad's `gate-w2/` (not kept).

Wave sync: no intent or data register, so no documentalist or
data-steward pass; no wave 2 chunk changed a dependency, so no
security-advisor check.

### Wave 2 report to the owner, 2026-10-31

All six chunks merged (none moved); the gate passed with two wording
fixes; G10 ruled (D227, 640M); D228 (E4's reading, no ruling needed);
the shop domain's consent fix. Left for the owner from wave 1, still
open: the test-only brick-bump precedent, `pgbadger` in `.tech`.
For wave 2: the 640M margins are estimates until 15b (above); R1 and R3
read 3 for the rest of a 14:00 hand-over game (chunk 10). The owner said
"we'll stop after this wave": wave 3 waits for his word.
Owner, 2026-10-31: a test-only brick change bumps nothing (D229, formats.md); `pgbadger` goes into `.tech`, added by security-advisor on his word.

## Wave 3 — started 2026-10-31

Chunks 12, 13, 14, 15. `v0.4-w3` cut from `main` at 62de2f2, worktree
`/home/bastien/work/db_audit_gm-wt/v0.4-w3`. No intent or data register:
no preflight. No new dependency named by any wave 3 chunk.

### Gates checked at the start

- **G3** (hand check): Debian trixie, PGDG trixie-pgdg and the s6-overlay releases answer 200.
- **G4** (hand check): armenelos `Ready Active Leader`; `vps-5718ad52` `Ready Drain`.
- G10 done (spec D227). G7 is not needed in wave 3 (no two-host run in its chunks; the gate's two-host `smoke-load.sh` repeats it).
- Host: 10 GB free on `/`, 4.7 GiB of memory available, 3.1 GiB of swap in use; running: `ollama`, `llmward-homepage`, `llmward-dlp-metrics`.

### Capture W3-a — the governance check set (chunk 12; read by 15)

Recorded 2026-10-31, before any wave 3 code, from chunk 12's capture
line, [master-spec.md](master-spec.md) 6.5, 11.4 to 11.7, 12, 14, 18
(item 4), [access-model.md](access-model.md) 8 and 9.3, W1 items 0 and
1, W1-x, W1-y, W2-x, and `tools/gm/{checks,execnode,inject,model}.py` on
`v0.4-w3` at 62de2f2. W1's rules hold: the spec cited, not restated;
**(choice)** a point settled here; chunk internals (the SQL) left out.

**1. Home and delivery** (12 writes; 15 reads)

- `tools/gm/governance.sh`: POSIX shell defining functions only (nothing
  runs or is set at its top level, no `exit`), its SQL inside; and
  `tools/gm/governance.py`, building the rules (item 3) and the text
  sent. **(choice)** Shipped as checks already reach a node: `gmctl
  check` streams a check's text into `sh -s` on its instance's node
  (`check_plan`, `exec_node`), and nothing else of the GM's is there at
  check time. No brick change, mount or verb; a brick helper would need
  images rebuilt and the rules from the GM all the same.
- `check_plan`: when a fault's `sealed_check.script` contains
  `check_governance`, the text sent is `governance.sh`, a newline, then
  the script, and the environment gains `CHECK_GOVERNANCE`; in a scenario
  without `governance:` the check is refused before anything runs.
  **(choice)** The call is the declaration: no `fault.yaml` key (no
  template or loader change), every other check sent byte for byte as
  today. The early and hand-over checks pass through it too.

**2. The call** (12 writes; 15 reads): `out=$(check_governance G1 G3); rc=$?`

- One or more of `G1` `G2` `G3` `G4`, each once, run in the order given.
  It `return`s, never exits the caller, and writes standard output only.
- G1, G2, G3's catalog paths and G4 run on a `database` node, G3's
  transformer-job path on a `transformer` node, anything else returns 2;
  the node knows itself by `hostname` (render's `hostname: <node>`).
  **(choice)** A check runs on its instance's node only (12), and access
  model 8 lets it read a runner's `jobs.yaml` and schedule "on their own
  node". f9's check, on `reporting`, gets the catalog paths (foreign
  tables, mappings, definer owners, `pg_cron` jobs, on every instance),
  which hold its breaches; the baseline proof (item 6) runs both.

**3. What it reads**

| Input | From | By |
|---|---|---|
| `governance:`, the classification | the scenario folder, on the GM's host, at each check run | `governance.py` (`model.load_scenario`), into `CHECK_GOVERNANCE` |
| catalogs | every database (`datallowconn`, not a template) of every `database` node | `check-psql` as `gm_check`, local on its own node, `--node <node>` for the others (W1-x) |
| mappings' remote roles; `pg_cron` jobs | each database holding a server; the one holding the extension | `gm_check.user_mapping_roles()`; `cron.job` through `gm_check_read` (W2-x) |
| privileges (G2); outbox rows (G4) | the instance holding the column; each flow's `outbox` (W1 item 1) | `has_column_privilege`; `check-psql` |
| a runner's jobs | its `jobs.yaml` and schedule at the paths `/etc/scheduler/scheduler.yaml` names (`jobs`, `schedule_seed`) | the node's `python3`, as root; G2 on each connection's database through `check-sql` |

**(choice)** `CHECK_GOVERNANCE`: one line of JSON, keys sorted:
`classes` (`governance.classes` as written, every class of the closed
list, a missing `internal` as `{"locations": "any"}`), `columns` (the
classification's entries but `internal`), `database_nodes`,
`transformer_nodes` (topology order), `own_roles`
(`model.RESERVED_DB_ROLES`, 11.6's list). Reason: the environment is how
`gmctl` hands a check its values (`FAULT_*`, `CHECK_SINCE`), root's alone
on the node; the text stays code; PostgreSQL parses it (`jsonb`), not
the shell.

**4. Readings 11.6 leaves open** (12 writes; 15 relies on G1, G3)

- **G1, a foreign table**: the remote key `<the server's
  dbname>.<table_name, else its own name>.<column_name, else the
  column's>`, when `schema_name` is `public` or unset (W1 item 0).
  **(choice)** What PostgreSQL itself uses, readable by `gm_check`.
- **G1, a copy by name**: table and column names alone, any schema or
  database (`rpt.customers.email` is `personal`), the strictest class on
  a clash. **(choice)** A copy is elsewhere by definition, often in `rpt`.
- **G1, the probe**: `personal` only, tables and materialized views (not
  views, not foreign tables) of the databases it may not live in,
  text-typed columns, one e-mail-shaped value enough. **(choice)** A view
  or foreign table shows data held elsewhere, which the name and remote
  rules judge; `gm_check` has no mapping to read one.
- **Every walk** leaves out `pg_catalog`, `information_schema`, toast
  schemas, extension-owned schemas (`cron`) and `gm_check`. **(choice)**
  The game's and extensions' own objects, as the game's roles are.
- **G2**: login roles not in `own_roles` and not `pg_*`, on the instance
  holding each column G1 classes there.
- **G4**: rows whose `sent_at` is after `CHECK_SINCE`, the top-level keys
  of their `payload` against the flow's `fields`. **(choice)** Both
  outboxes' columns (9.6); nested keys are E3's and M4's. A scenario's
  `fields` are therefore the payloads' keys (W3-b item 4), so the
  baseline passes (18 item 4); 6.9's and access model 9.3's `[email,
  name, order]` are the policy's words (for `spec-writer` at the archive).

**5. Return status and output** (12 writes; 15 reads)

- 0 every rule named holds; 1 one is broken; 2 it cannot judge (no or
  bad `CHECK_GOVERNANCE`, an unknown or repeated rule, a rule this node
  cannot run, a node unreachable, G4 without `CHECK_SINCE`, the
  mapping-roles function or `gm_check_read` gone: W2-x); 3 for G4 only,
  nothing broken but an outbox with no row since `CHECK_SINCE`. Combined
  as `gmctl check` does: 2, else 1, else 3, else 0. **(choice)** G1 to G3
  never 3 (11.6); G4's 3 is the set's, not a sealed check's, since a
  database node cannot know the outbox job's next run: a caller judging
  runs answers 3 with its own `remaining=`. No v0.4 fault calls G4.
- The first line is one sentence a caller reuses as its own: the first
  breach (`G1: reporting/reporting <schema>.<table>.<column> holds
  personal data (remote shop.customers.email), allowed only in
  db/shop`), or `G1, G3 hold on <n> database nodes, <m> databases`, or
  `governance: cannot judge: <why>`; then one line per breach, `<rule>
  <node>/<database> <object>: <why>`, at most 20 per rule.
- So f9's check (15a): `rc` 1, the set's first line and exit 1; `rc` 0,
  its own test that job, table, foreign table and server are gone
  (16.2); `rc` 2 or 3, exit 2.

**6. The baseline proof** (12 writes; 13's gate and 17's release-gate item 4 run it)

`tools/tests/check-governance.sh <scenario-dir> <playground> [<since>]`
runs `check_governance G1 G2 G3 G4` on the first `database` node and
`check_governance G3` on every `transformer` node through `gmctl exec
--user root`, `CHECK_SINCE` being `<since>` (default: an hour ago), and
exits with item 5's combination. **(choice)** A harness script like the
smoke scripts, not a `gmctl` verb (14 adds none).

### Capture W3-b — `fixture-campaign` (chunk 13; read by 14, 15, 16)

Recorded 2026-10-31, before any wave 3 code, from chunk 13's capture
line, master spec 7.2, 8.5, 9, 10, 11.5, 13, 16.1 to 16.3, access model
9, W1 items 0, 1 and 5 to 8, W1-x, W1-z, W2-x, chunk 10's "For wave 3's
briefs", and on `v0.4-w3` the purposes, the shop domain,
`tarnbeck-outdoor-shop` and `fixture-instances`. Folder
`tools/tests/fixtures/fixture-campaign/`, seed files at
`nodes/<node>/<file>`, one network `backend`.

**1. Nodes** (16.1: bricks, roles, sizes, `reporting` 640M / 256M; "as
v0.3" is `tarnbeck-outdoor-shop`'s)

| Node | Role | Write policy | Seed files |
|---|---|---|---|
| `bastion` | bastion | report-only | `README.md`, `story.md`, `issues.md`, `data-policy.md` |
| `db` | database | fixable | `postgresql.conf`, `pg_hba.conf`, `crontab`; `crontab_roles: [shop_refresh]` |
| `pooler` | pooler | fixable | `pgbouncer.ini`, to `db:5432/shop` |
| `producer` | producer | report-only; `write_overrides` `/srv/scheduler/repository`, `/srv/scheduler/jobs` | `queries.yaml`, `builders/`, `jobs.yaml`, `schedule.yaml` |
| `consumer` | consumer | report-only; `/srv/scheduler/jobs` | `queries.yaml`, `jobs.yaml` (`jobs: []`), `schedule.yaml` |
| `reporting` | database | fixable | `postgresql.conf`, `pg_hba.conf`, `crontab`; `crontab_roles: [bi_etl]` |
| `bi` | transformer | report-only | `queries.yaml`, `scripts/`, `jobs.yaml`, `schedule.yaml` |
| `crm` | transformer | report-only; both overrides | `queries.yaml`, `jobs.yaml`, `schedule.yaml` |
| `gateway` | producer (W1 item 1) | report-only | `queries.yaml`, `jobs.yaml` (`jobs: []`), `schedule.yaml` |
| `prometheus`, `exporter`, `grafana` | monitoring | as tarnbeck | as tarnbeck: `db` scraped, `reporting` not (13.4) |

**2. Databases and data files**

- `db`: `data/db.sql`, the domain's `schema.sql` then `load.sql`
  unchanged (W1 item 6): database `shop` (owner `shop`), 9.7's roles on
  `db`; P2, P3 and P5 add no DDL.
- `reporting`: `data/reporting.sql`, P1's `material/target/data.sql`
  unchanged, then `CREATE EXTENSION pg_cron;` on a line of its own under
  `\connect reporting` (W1 item 0), no job: database `reporting` (owner
  `reporting`), roles `reporting`, `bi_etl`, `bi_reader`; server
  `shop_db` (`host 'db'`, `dbname 'shop'`), the one mapping `bi_etl` to
  `shop_etl`, `src.orders`, `src.order_lines`, `src.products`,
  `rpt.close_day()`. **(choice)** 16.1 to 16.3 give `reporting` one
  `pg_cron` job, f9's, and one crontab entry, f10's, each planted by its
  fault's `data` or `crontab` seed change (spec D226, W1 item 1).

**3. The database nodes' seed configs**

- `postgresql.conf`: `db` tarnbeck's; `reporting` the same form with
  `shared_preload_libraries = 'pg_stat_statements,pg_cron'`,
  `cron.database_name = 'reporting'`, `cron.use_background_workers =
  on`, `cron.timezone = '{{customer_timezone}}'`, `cron.log_run = on`,
  `cron.log_statement = on` (7.2, 8.5, 12.5). **(choice)**
  `pg_stat_statements` there too: f10's evidence names its reset (16.3).
- `pg_hba.conf`, both: `fixture-instances`' DO NOT TAMPER block (with
  `host all gm_check samenet scram-sha-256`), then `local all all` and
  `host all all 0.0.0.0/0`, `scram-sha-256` (`db` keeps tarnbeck's
  `monitoring` line). **(choice)** One password line, as tarnbeck's
  `db`: it admits chunk 10's list and f9's mapping to `shop_reports` from
  `reporting` with no change on `db`, a fault's seed changes targeting
  its own node only (16.2).
- `db`'s crontab, exactly (W1 item 8's form; f6 rewrites the entry):

  ```
  PGPASSFILE=/run/gm-cron/pgpass
  17 * * * * psql -X -w -h /run/postgresql -U shop_refresh -d shop -c "REFRESH MATERIALIZED VIEW popular_products" >> /var/log/postgresql/cron/popular-products.log 2>&1
  ```

  Job `popular-products`. **(choice)** Minute 17, off the five-minute
  grid and the :05 and :20 jobs.
- `reporting`'s crontab: the `PGPASSFILE=` line, no entry. **(choice)**
  Its daemon runs (W1-x: the seed config's presence starts it), and
  f10's seed change adds its 03:00 entry to a file the node seeds.

**4. Connections, jobs, `purposes:`, `governance:`** (material copied
unchanged, written for these names, W1 item 5; each schedule adds
`intensity: 1.0`, no `timeline:`, f2's and f8's being their faults')

| Node | Connection: target, role | Jobs (name, key, `at`); streams | From |
|---|---|---|---|
| `producer` | `app`: `pooler:6432/shop`, `shop_app` | `close-day`, `orders.close-day`, `0 12 * * *`; streams `orders.place`, `catalog.lookup`, `orders.detail`, `orders.status`, `deliveries.ingest`, `consent.unsubscribe`, `consent.subscribe` | `domains/shop/producers/` |
| `consumer` | `dashboards`: `reporting:5432/reporting`, `bi_reader` | streams `dashboard.today`, `dashboard.revenue`, `dashboard.categories`, `dashboard.freshness` | P1 `consumer/` |
| `bi` | `shop`: `db:5432/shop`, `shop_etl`; `reporting`: `reporting:5432/reporting`, `bi_etl` | `rollup-hourly`, `rollup.hourly` (`scripts/rollup.py:hourly`, `connections: {source: shop, target: reporting}`), `5 * * * *`; `rollup-close`, `rollup.close`, `30 1 * * *` | P1 `runner/` |
| `crm` | `shop_crm`, `shop_customs`: `db:5432/shop`, each as its namesake | `leads-extract`, `leads.extract`, `20 * * * *`; `mail-shipped`, `mail.shipped`, `*/5 * * * *`; `mail-campaign`, `mail.campaign`, `*/15 8-20 * * *` (`shop_crm`); `declare-exports`, `declare.exports`, `*/5 * * * *`; `escalate-customs`, `escalate.customs`, `*/15 * * * *` (`shop_customs`) | P2, P3, P5 `runner/`, merged |
| `gateway` | `customs`: `db:5432/shop`, `customs_gw` | stream `customs.acknowledge` | P5 `receiver/` |

```yaml
domain: shop
purposes:
  - {id: shop-sales-reporting, parts: {source: db/shop, target: reporting/reporting, runner: bi, consumer: consumer}}
  - {id: shop-winback-leads, parts: {source: db/shop, target: db/shop, runner: crm}}
  - {id: shop-customer-mailing, parts: {source: db/shop, target: db/shop, runner: crm}}
  - {id: shop-export-declarations, parts: {source: db/shop, target: db/shop, runner: crm, receiver: gateway}}
governance:
  policy: player/data-policy.md                 # 11.5, in words
  classification: data/classification.yaml      # the domain's, unchanged
  classes:                                      # readers: access model 9.3
    personal:
      locations: [db/shop]
      readers: [shop_app, shop_reports, shop_crm, shop_customs, customs_gw]
      outbound:                                 # fields: the payloads' keys (W3-a item 4)
        - {to: mail-provider, outbox: db/shop/mail_outbox,
           fields: [name, email, order_id, shipped_at, ship_country, total, campaign]}
        - {to: customs-gateway, outbox: db/shop/customs_outbox,
           fields: [order_ref, consignee_name, consignee_address, destination_country,
                    lines, total_value, currency]}
    customer-linked: {locations: [db/shop], readers: [shop_app, shop_reports, shop_crm, shop_customs]}
    internal: {locations: any}
```

**5. Instances, aging, placement, player files**

- **(choice)** One harmless instance, `f0`: `fixture-instances`'
  `fixture-random-page-cost` copied into `faults/`, on `db`, hidden;
  `difficulty: {score: 1, level: easy}`; the answer key `f0` only. The
  template refuses an empty `fault_instances` (`fixture-instances`'
  precedent); the id leaves `f1` to `f10` to 16.1. Chunk 16 drops it.
- `aging: {minimum: 8h, handover_at: "14:00"}`, the floor (`fixture-load`'s).
- `designed_for`: `host-1`, the manager, every node but `bi` and
  `gateway`, on `host-2` (16.1). **(choice)** 16.1 places only these.
- `player/README.md`, `story.md`, `issues.md`: one-paragraph fixture
  texts (the bastion needs all three, W1-z); no issue.

**6. Planting on it** (14, 15). **(choice)** Each plants on scratch
copies outside the repository (as v0.3's chunk 10b did), adding its
instances with 16.1's ids, nodes and plantings, the timeline changes f2
and f8 need and `difficulty.score`, never editing the committed fixture:
14 and 15 run side by side sharing no file, and chunk 16 writes the ten.
Their seed changes target `crm`'s `queries.yaml` and `jobs.yaml` (f1, f2,
f3, f8), `bi`'s `scripts/rollup.py` (f4), `db`'s `crontab` (f6),
`reporting`'s `data` (f7, f9, f10) and `crontab` (f10); f5 is a `state`
change on `db`.

### Questions from the captures

1. **The game's own roles against "a superuser reaching everything"**
   (W3-a; `spec-writer`). 11.6 skips `dba`, `postgres`, `gm_check`,
   `monitoring` and PgBouncer's lookup role "by name", while G3 judges a
   `SECURITY DEFINER` procedure "as its owner" and a `pg_cron` job by its
   `username`, "a superuser reaching everything". (a) Skipped everywhere:
   a job run as `postgres`, or a definer function it owns, is never a G3
   path. (b) Skipped as readers only, the reason 11.6 gives ("who may
   read"): a job's username or a function's owner is judged whoever it
   is, a superuser reaching every classed column of its database. No
   v0.4 verdict turns on it (f9's job runs as `bi_etl`; the baseline has
   no `pg_cron` job and one definer function, in `gm_check`, left out
   either way): chunk 12 keeps the predicate in one place. Not blocking.
2. **`shop_reports` has no secret, so f9 cannot be planted** (W3-b, 15a;
   the driver, then `spec-writer`). f9's mapping for `bi_etl` names
   `shop_reports` (16.2); `load-data` sets a mapping's password only for
   a remote role a schedule or a `crontab_roles` names, and fails the
   setup otherwise (W2-x, `inject.password_plan`); nothing in 16.1 names
   `shop_reports`. (a) 9.7 literally, "each login role's password is a
   generated secret, set by `load-data`": render and `load-data` give
   every login role a data file creates its secret, a `tools/gm` fix
   before 15a against W2-x as built. (b) As built: the back office,
   `shop_reports`' user in access model 9.1, also reads the shop, so
   `consumer` gains a connection `db:5432/shop` as `shop_reports` and a
   light stream (as tarnbeck's `reports.recent`), widening 16.1's
   "reading `reporting`". Recommended: (b), content only and the access
   model's own row (the agency then borrows a login in use). Needed
   before chunk 13 merges.

For `spec-writer`, no ruling needed: chunk 13's "Out: fault instances"
reads as "but one harmless instance" (W3-b item 5), and its done-when's
"the `pg_cron` job and both crontabs run" as `db`'s entry running and
`reporting`'s daemon and `pg_cron` launcher up with nothing scheduled
(W3-b items 2 and 3); f9's job and f10's entry run on chunk 15's copies.

### Captures reviewed by the driver, 2026-10-31

W3-a and W3-b accepted as drafted (fba4712). On their questions:

- **Question 2, `shop_reports`' secret: (a), as master spec 9.7 states
  it** ("each login role's password is a generated secret, set by
  `load-data`"). `load-data` as built (chunk 7, W2-x) sets one only for
  a role a schedule or a `crontab_roles` names: the code is narrower
  than the spec, so it is fixed to the spec on the wave branch by a
  `coding-executor`, in its own commit, before chunk 15's branch is cut.
  (b) is not taken: it would widen 16.1's topology (`consumer` reading
  `db`) to work around a gap in the code. No owner ruling needed.
- **Question 1, the game's own roles in G3**, and the `fields` example
  (formats.md and master spec 6's `[email, name, order]` against the
  payloads' real keys, W3-a item 7): to `spec-writer`, not blocking.
  Chunk 12 keeps the own-roles predicate in one place, so either reading
  is a one-line change.
- **Settled by `spec-writer`, 2026-10-31:** question 1 is (b) (D230,
  master spec 11.6, 11.7): `own_roles` are skipped in G2 only, and each
  G3 path's role (remote role, connection role, definer owner, `pg_cron`
  `username`) is judged whoever it is, a superuser reaching every
  classed column of its database; the walk also leaves out
  `gm_pgbouncer`. `fields` are the payloads' top-level keys (D231, 6.9,
  11.3, 11.6, formats.md v26), as W3-a item 4 built; G4 unchanged.

### Order and dispatch

κ = 3. First: chunks 12 and 13 (no shared file), and the `load-data`
secrets fix (`tools/gm/`, no file of chunk 12's or 13's). Chunk 14 is
cut once chunk 13 has merged; chunk 15 once chunks 12, 13 and the fix
have merged (15a, then 15b, which holds the host lock alone on
armenelos, the VPS drained).

### `load-data` secrets fix — merged (0e13b44, 7e464ce), 2026-10-31

`coding-executor`: ad0cd02 (merge 0e13b44), b1771ae (merge 7e464ce).
Every role a node's data file creates with LOGIN (`CREATE ROLE … LOGIN`,
or `CREATE USER` without NOLOGIN; the game's own roles and `pg_*` left
out) has a game secret `role_<role>_password`, same name and derivation
as before, set by `load-data` on that node as a SCRAM verifier; these
secrets are created but mounted nowhere new (a node still mounts only
what a schedule or its `crontab_roles` needs). A user mapping whose
remote role is such a role gets that secret; one naming no data-file
login role is still refused. A schedule's connection through a
non-database node (a pooler) sets the role only on the database nodes
whose data file creates the target database, or on every database node
when none does (chunk 13's deployment found the old rule failing on
`reporting`: `role "shop_app" does not exist`). Known limit: a role
created inside a `DO` body, or given LOGIN later by `ALTER ROLE`, is not
seen. Unit suite 807 OK. `stack.yml` and every seed file render
byte-identical across the three scenarios and six fixtures; the new
secrets appear only in `implementation.yaml`. f9's `shop_reports`
logs in with its secret (container run under the lock).

Driver's call: bookshop's and fernway's data files give their app role a
fixed password, which their GM notes cite; a role whose CREATE sets its
own PASSWORD keeps it (master spec 16.4, v0.3's scenarios unchanged). A
follow-up commit by the same executor (bb5a505, merge 0dbbabf; 808 OK; bookshop and fernway render as before). For chunk 15a: login roles are
read from the scenario's own data file; a role created only by a seed
change's copy would need reading from the copy (f9 doesn't).
For chunk 18: `gmctl.md` 143–147 and 201–208 state the old, narrower rule.

### Idle-session fix — merged (047328a, ee6cb21), 2026-10-31

Confirmed by a throwaway stack: a session without keepalives idle 840 s
survives, at 960 s some die (08006, the server still `idle`, nothing
logged); libpq's default first probe is the kernel's 7200 s. Fix: the
scheduler's driver sets `keepalives=1`, `keepalives_idle=300`,
`keepalives_interval=30`, `keepalives_count=3` on every session and on
transformer scripts' connections; no retry, nothing stated changes;
`docs/gm.md` says why; a unit test reads the options off the sockets.
Unit suite 828 OK; scheduler unit tests 72 OK; image rebuilt; stack test
133/0; after the fix 8 of 8 sessions survive 960 s. Scheduler stays
0.2.0. Chunks 14 and 15a told to merge `v0.4-w3` in before deploying.

Survey of other long-lived connections through a service address: PgBouncer
→ `db` closes idle server connections at 600 s (safe); Prometheus,
Grafana, the exporter scraped every 15 s (safe while scraped);
`reporting`'s postgres_fdw link to `db` exposed at the network level,
probably reconnected by PostgreSQL 14+ (untested; chunk 15a told to
report a lost fdw link); **the bastion's inner SSH hop and players'
`psql` from the bastion are exposed**: an idle player session over 15
minutes may hang (no `ServerAliveInterval`). Proposed: `ServerAliveInterval
60` in the bastion's `gm-game.conf` (sent to a `coding-executor`);
optionally keepalive options on the data files' `CREATE SERVER`, or one
render-level `sysctls` for every service (render and spec change; for
`spec-writer` at the milestone, not now).

`pg_cron` launcher noise: not built. Every brick-only fix changes
`load-data`'s steps or the data-file contract (master spec 7.2, 14).
Options for the owner at the wave report: `cron.database_name =
'postgres'` with `cron.schedule_in_database(…, 'reporting')` (relaxes a
loader rule; no noise), a restart step in `load-data`, or documenting the
pre-load lines in `postgres`' `gm.md` and `player.md`.

### Wave 3 report to the owner, 2026-10-31

Chunks 12, 13, 14, 15 (15a, 15b) and the inserted 20 merged; none moved.
Gate passed with one README-cell fix. Rulings this wave: the pg_cron
noise fixed by a `load-data` step (D258); v0.5's recommendations accepted
(D248–D251, on `v0.5-scope`); f10's 327 MiB accepted (D252);
`separation: instance` defined (D253). Readings by `spec-writer`: D239–D247,
D254–D257. Owner, while the gate ran: "we will end after this chunk" —
merge wave 3, then stop; **wave 4 (chunks 16, 17, 18) waits for his word**.
`v0.5-scope` and `v0.5-post-mortem` stay unmerged until he says.

Open for wave 4's driver:
- To `spec-writer` at wave 4's start: chunk 20's two readings (the breach
  line's object for a whole database is the word `database`;
  `smoke-governance.sh`'s optional `-- first:` line); after `v0.5-scope`
  merges, `formats.md`'s O126 citation (line ~611).
- Chunk 16's brief: f1 `aging_minimum: 65m`; f2's expected fix names both
  paths; f7's offset equal in instance and data-file copy, non-zero,
  −23..23, aging ≥ the close's offset from T0 + 1h, `judges: runs`,
  `threshold: 0`, fix dated with `--since`; f9's fix unschedules by id,
  the CREATE grant is part of the planting; no `separation:` (D253);
  `reporting` at 640M (D252); cite D227, D239–D247, D252–D258; watch
  `reporting`'s fdw link to `db` idle > 900 s (the nightly close).
- Chunk 17a's brief: f7's cycle passes `--since`; after a move, wait for
  the moved time, not `remaining=`.
- Chunk 18's: f10's check reads 2 after hand-over if a player deletes the
  request row in `reporting`.
- Cosmetic README leftovers: "—" vs "none" in other generated READMEs
  (`fixture-v04-refusals` not regenerated since 93538db); wrapping and
  backticks; empty job-table rows.
- The superseded `scheduler:0.2.0` layers may remain on the VPS (no prune).

### Wave 3 gate (coding-executor, armenelos + the VPS, 2026-10-31) — passed

Every step passes on `v0.4-w3` from 62f3b07 to 5e8eb84, 17:33–19:35 UTC,
every docker step under the host lock and the sleep inhibitor, one at a
time. Host: 9.0G free on `/`, 4.9 GiB available, `ollama` and two
`llmward` services running.

| Step | Result |
|---|---|
| Unit suite | 848 OK (146 s), again at 5e8eb84 |
| Scheduler unit tests | 72 OK (178 s) |
| `sh -n` / `perl -c` / `py_compile` | 163 / 7 / 52 files, plus 40 embedded Python bodies in 35 shell files; 0 fail |
| Seven builds | all rc=0 (cache) |
| Stack tests | bastion 90/0, postgres 211/0, pgbouncer 105/0, scheduler 133/0, prometheus 131/0, postgres-exporter 103/0, grafana 119/0 (1460 s) |
| `smoke.sh` / `smoke-monitoring.sh` | 61/0 / 43/43 |
| `smoke-scenario.sh` | bookshop 19/19, fernway 18/18, tarnbeck 26/26 |
| `smoke-load.sh armenelos` | 73/73, 427 s; fit 1.1 CPU / 1.22G of 12 / 4.76G; disk 9.84G of 41G (13.79G with the snapshot) |
| `smoke-load.sh` two hosts (G7) | 73/73, 483 s; armenelos 0.75 CPU / 704M, disk 5.53G of 20G; VPS (`shared`) 0.35 CPU / 544M, 3.37G of 10G |
| `fixture-campaign` deployment | game `…-id9pp3`, shift −8, T0 18:39:17Z; every job ran (moves by `jobs.yaml` + reload, restored byte-identical); G1–G4 exit 0 at 18:56, 19:20, 19:30; purpose checks 0 or 3 only; 0 errors, 0 `08006` |
| D258 on the deployment | 19 + 19 pre-load lines before `load-data`, 78 lines removed, 0 after in the files and `docker service logs` |
| `smoke-governance.sh armenelos` | 121/0 |
| Hand checks | `fixture-campaign` and `fixture-instances` READMEs match a regeneration (after the fix); the ten new faults and the fixture's own pass `check_fault_dir` |

Fix: 5e8eb84 — `fixture-instances`' README, `internal`'s Outbound cell
"none" as the template writes it.

**G7:** pre-check 18:28:08 (`tailscale status` both ways, `Ready Drain`,
filetstudio.com 200, nothing of ours on the VPS, 22G free); `active`
18:28:44 (no refusal); run to 18:36:47, filetstudio.com 200 on 17 polls;
drained 18:36:47; post-check clean, the site's four containers with their
uptimes. The run copied the current `scheduler:0.2.0` (1ad76b563f81) to
the VPS.

Memory on the deployment (41 one-minute samples): grafana 205M of 384M,
db 256M of 1G, reporting 73M of 640M; `memory.peak` db 868M (page cache
at `load-data`), reporting 140M. Logs: the session scratchpad's
`gate-w3/` (not kept).

Wave sync: no intent or data register, so no documentalist or
data-steward pass; no wave 3 chunk changed a dependency, so no
security-advisor check. `doc-ids compare main v0.4-w3`: 0 collisions.

### Chunk 20 — merged (6b4ad78), 2026-10-31

`coding-executor`: cf9d0a4, merge 6b4ad78. G1 judges `separation: instance`
(`_gov_g1_separation`, after the catalog walk); the loader refuses it with
`locations: any`; `check_fault_dir` checks a `state` fault's
`seed_changes` materials; `fixture-instances`' `personal` carries
`separation: instance`, its policy says so, README regenerated (the
Separation cell only). Unit suite 848 OK; `smoke-governance.sh` 121/0 on
armenelos (new breach: G1=1 G2=0 G3=0 G4=0 from `db`, first line from
`reporting` naming `db/scratch`; 0 after the drop). Readings accepted by
the driver (not a player-facing choice of substance; to `spec-writer` at
the wave sync): the breach line's object for a whole database is the word
`database`; the smoke script's optional `-- first:` line. Every chunk of
wave 3 merged; the gate is next.

### Rulings recorded, chunk 20 inserted (f6cdc92), 2026-10-31

`spec-writer`, plan v9: D252 (f10's 327 MiB accepted as measured; G10's
row cites it), D253 (`separation: instance` a G1 rule: on each node
holding a class's location, every other database but `postgres` is a
breach; the loader refuses it with `locations: any`; O140 closed;
**chunk 20 inserted on wave 3**, a coding-executor, before the gate),
D254 (a `state` fault may carry `seed_changes`), D255 (f10's own foreign
table), D256 (f10's check dates from `requested_at`, exits 2 when it
can't confirm, matches both kill wordings), D257 (the night after a
killed first backfill reads one day), D258 (`load-data`'s pg_cron
cleanup step, 7.2 and 14). D259 reserved, unused. Lint 0 errors, 5
known warnings; `doc-ids compare v0.5-scope v0.4-w3` 0 collisions. No
intent register, so no `documentalist` peek for chunk 20.

For chunk 16's brief: D252, D253 (no `separation:` in 16.1), D254–D257.
For chunk 18's: f10's check reads 2 after hand-over if a player deletes
the request row in `reporting` (GM notes).

### Chunk 15b — merged (b744cca), 2026-10-31

6149311 (f10; WIP 7feaca0 squashed in, `gm.md` gives the figures as
measured with the owner's acceptance), b5f4557 (f2's "Fix path": the
producer path with the flags repaired is a fix dated with
`gmctl check --since`, D244). The merge is **b744cca**: the driver's
`commit -a` for the pg_cron log entry ran while the agent's
`merge --no-ff --no-commit` was staged, so it carries the log message;
its parents (900807d, b5f4557) and content are the merge as tested. Left
as is, not rewritten. Unit suite 846 OK merged; `check_fault_dir` clean
for f10 and f2. Lesson: the driver does not commit in the wave worktree
while a chunk agent may be merging.

**Capture W3-d (f10):** `purpose-heavy-job-on-database-node` 0.1.0, family
data-flow, node `reporting` (postgres 0.4.0), builds on P1's target part
(a precondition, no `applies_to.purposes`). `seed_changes`: `data`
(`inject/sales_detail_rollup.sql.snippet`, after P1's material) and
`crontab` (`0 3 * * *` `CALL rpt.sales_detail_rollup()` as `bi_etl`,
`crontab_roles: [bi_etl]`). State change `inject/10-backfill-request.sh`
(one request of `days` days, idempotent) at `plant_at: handover-12h`.
Parameters `database` (reporting), `days` (30). Aging minimum 30m from the
entry's first run after planting. `needs_unshared_host: true`; no
`judges`; `at_handover: 1`; resolution report only.

### `pg_cron` pre-load noise — fixed, merged (54bc74a, merge 900807d), 2026-10-31

`coding-leader`, per the owner's ruling. A last `load-data` step on every
`database` node whose survey finds `pg_cron`: wait up to 60 s for the
launcher (else `load-data` fails), switch the server log
(`pg_rotate_logfile()`, statement logging off), then in the closed files
remove each `pg_cron launcher … exited with exit code 1` line and the lines
its PID logged before it (by the brick's `[%p]` prefix). No file log: a
skip; no switch: left as is with a `warning:`. Restart-after-load ruled out
(pg_cron refuses to load without the preload; lines already written stay);
`cron.database_name = 'postgres'` ruled out (changes 7.2/14's loader rule,
f9, G3). Unit suite 846 OK merged (15 new tests in `test_inject.py`).
`fixture-campaign` deployed twice on armenelos alone: 58 and 54 lines
removed, then 0 such lines in all of `reporting`'s logs and
`docker service logs`; other pre-load lines byte-identical; launcher
connected; `db` untouched. `smoke-governance.sh`: 115/0. Docs:
`gmctl.md`'s `load-data`, `postgres` `gm.md`; `postgres` stays 0.4.0.
Risks: relies on `[%p]` in `log_line_prefix`; a fixed `log_filename`
leaves the noise with a warning; players see a second log file from
`load-data`. The new step to `spec-writer` to record (master spec 13/14).

### Owner rulings on G10 and O140, 2026-10-31

- **G10 (f10 at 640M): "Accept 327 as is".** The normal run's 327 MiB
  `memory.peak` is accepted as measured, no criterion change and no
  re-run; the figure is recorded. 15b resumes from 7feaca0 (its own
  agent) to word `gm.md` and merge.
- **O140: "Define it now".** `separation: instance` gets its rule in v0.4
  as a one-query extension of G1; to `spec-writer` to record and place in
  the plan.

### Chunk 15b — stopped on G10 (WIP 7feaca0), 2026-10-31

f10 built and run on armenelos alone (VPS Ready Drain, never touched),
game `fixture-campaign-9v8w59`, `reporting` at 640M + swap 640M,
`shared_buffers` 128MB. Every Done-when item holds but one: the backfill
(30 days) was killed after 11 s (`oom_kill` 0 → 1, 1258 MiB anon+shmem+swap
of 1280 allowed), the postmaster recovered in 1 s with its pid unchanged,
`gmctl check --instance f10` read 2 before the run and 1 after, the next
run completed, `fit` refused a shared host. **A normal run's `memory.peak`
read 327 MiB, above the 320 MiB half** (anon 203.5 + file 104.3 at the
peak; 238 MiB without page cache; chunk 9 read 299–301 in an isolated
stack; the game's baseline is higher). Measured once, as the rule says.
Not merged; put to the owner. Notes for `spec-writer` after the ruling: a
`state` fault with `seed_changes` (template comment says seed-file only);
the roll-up's own foreign table `src.sales_detail_orders`; the check
dates the planting from `requested_at`; PG 18 logs "client backend", the
check matches both; the night after a killed backfill reads 1 day.
Unit suite 831 OK; `check_fault_dir` clean.

### v0.5 scope rulings recorded (`v0.5-scope` 596995d), 2026-10-31

`spec-writer`, on `v0.5-scope` (not this wave's branch): D248 (the sorting
stands; the clinic scenario in v0.5, generation in v1.0), D249 (seven
domains; composition tried on `vet-core` + `vet-lab`; the four format
changes in one chunk; a skill after two or three domains), D250 (the
clinic's `postgres`: partitioning before TimescaleDB, replication as a
standby mode, TLS always available and on by seed, only the `monitoring`
role an option), D251 (post-mortems bound later; handout after the final
answer). Closed O137, O47, O126; narrowed O111, O79, O118, O138; O139 open.
O135 settled as v0.6's (pointers in v0.4's README, chunk 19, master spec
2 and 22). After the merge into `main`: `formats.md` line 611 still cites
O126 as v0.5's (left alone, this wave may edit `formats.md`).

### Owner rulings, 2026-10-31

- **The `pg_cron` pre-load noise must be fixed**, a step after `load-data`
  allowed: "the pg cron problem (34 error report) we need to fix this, if
  it require a cleanup step after load data, then do it." Documenting the
  lines is out. Sent to a `coding-leader` (branch `v0.4-fix-pgcron-noise`,
  waiting on 15b's lock); the new step then to `spec-writer` to record.
- v0.5: "accept all recomendations for v0.5" (on `v0.5-scope`, recorded
  there by `spec-writer`). O140 (`separation: instance`) not yet ruled.

### Spec items of chunk 14 — settled (6aa843b), 2026-10-31

`spec-writer`, all readings, no code change, nothing to the owner: D244
(f2 restored through the producer is a fix only with the drifted flags
repaired, dated with `--since`; the producer alone reads present), D245
(f5's planting ends `shop_etl`'s open sessions), D246 (f5's and f7's
`remaining=` count to the designed time and ignore a move; it never
changes a verdict), D247 (a five-minute job's aging minimum is the hour
too). Plan v8. `doc-ids compare v0.5-scope v0.4-w3`: 0 collisions (O141
reserved, unused).

For chunk 16's brief: f1 `aging_minimum: 65m`; f2's expected fix names
both paths; spec sections D227, D239–D247. For chunk 17a's: after moving
`rollup-hourly`, wait for the moved time, not `remaining=`. After 15b
merges (driver, at the gate's fixes): one sentence in
`faults/purpose-leads-stale-consent/gm.md`'s "Fix path" (the producer path
with flags repaired dated with `gmctl check --since <repair UTC>`).

### Chunk 14 — merged (3cc4a32), 2026-10-31

14a cd7daed (f1, f2, f3), 14b 8fceabb (f4, f5, f8), merge 3cc4a32; the
`postgres` Supported-faults conflict with 15a resolved (all rows kept).
`v0.4-w3` merged in before deploying (the first game, on a pre-fix image,
torn down before its load). Unit suite 831 OK merged; `check_fault_dir`
clean for all six. Game `…-j8hkz8` (shift −3, T0 12:21:07Z), moves by
`jobs.yaml` and reload only:

| Fault | Evidence | 1 | 3 after the fix | 0 |
|---|---|---|---|---|
| f1 | duplicates 12:40 (T0 + 19 min) | 12:41 | 12:41 | 12:46 |
| f2 | 13:20 leads run, 10 withdrawn leads | 13:27 | 13:49 | 14:01 |
| f3 | 13:30 campaign, a mail at 02:30 the recipient's time | 13:31 | 13:49 | 14:01 |
| f8 | outage from 13:00; 10 declarations past their deadline | 13:47 | 13:49 | 14:31 |
| f5 | planted 14:00; 14:05 run refused 28P01 (expired password) | 14:01 | 14:05:50 (`--since`) | 14:09 |
| f4 | close at 13:10; day 10-30 at 9.34M against 21.50M | 13:27 | 13:31 | 15:36 (2nd game) |

f4's 0 needs a close after a local midnight: a second, f4-only game at
shift +9 (T0 23:32 local). Both games torn down; nothing left.

**Capture W3-c (f1–f5, f8), for chunk 16:**

| | Fault | Node | Seed change or injection | Parameters (defaults) | Aging minimum | Timeline need |
|---|---|---|---|---|---|---|
| f1 | `purpose-mail-overlapping-window` (M1) | crm | `queries.yaml`: `mail.shipped` window 10 min | `source` (db/shop), `job` (mail-shipped) | 1h from the job's first run after planting | none |
| f2 | `purpose-leads-stale-consent` (L2+M2) | crm | `leads.extract`, `mail.campaign` test `c.marketing_opt_in`; with f3, `mail.campaign` carries both | `source`, `leads-job`, `mail-job` | 1h from the campaign's first run after the release: 11h at T0 22:00 | producer: key `consent.unsubscribe-v2` (records the withdrawal, keeps the flag), timeline `at: T0` |
| f3 | `purpose-mail-outside-hours` (M3) | crm | `mail.campaign` hours `AT TIME ZONE s.timezone` | `source`, `job` (mail-campaign) | 1h from the campaign's first run: 11h | none |
| f4 | `purpose-watermark-misses-updates` (R1) | bi | `scripts/rollup.py` with `placed_at > since` (whole file) | `source`, `target` (reporting/reporting), `job` (rollup-hourly) | 1h from the first close of day after planting: 15h | none (the producer's daily close) |
| f5 | `purpose-etl-role-expired` (R4) | db (postgres 0.4.0) | state `inject/10-expire-role.sh`, `plant_at: handover-5h` | `role` (shop_etl), `target`, `job` (rollup-hourly) | 1h from the hourly run after planting | none |
| f8 | `purpose-receiver-down-unnoticed` (E4, `judges: triggers`) | crm | `escalate.customs` escalates rejections only | `source` | 1h from the outage's start: 11h | gateway: key `customs.unavailable`, timeline `handover-6h` → `handover-4h` |

Every instance `judges: runs`, `threshold: 0`, except f8 (`triggers`).

For `spec-writer` (sent with this entry):
1. f2's "or restore the flag's update in the producer's repository"
   (16.2): restoring the producer alone leaves the flags of everyone who
   withdrew since T0, so L2 and M2 read 1 until the flags are repaired
   (the improve); in `gm.md`.
2. f5's injection also ends `shop_etl`'s open sessions: VALID UNTIL is
   checked at login, and the scheduler now keeps its sessions open.
3. f5's `remaining=` counts from the ledger's last start, not the designed
   time D241 names (off when the job has been moved).
4. f1's aging minimum 1h, not 30m (shipping ramps after the load; first
   duplicates at T0 + 19 min).

Risks: f4 reads 3 for a whole 14:00 hand-over game (chunk 10); f5's
check reads `db`'s English log lines (depends on `log_line_prefix`); f8's
0 after a fix waits on the stub's 1-in-50 (an hour or two); f2's leads
side needs about five withdrawals before the first `:20` run.

### Template edits — merged (93538db, 9e29cf7), 2026-10-31

Both scenario-document template edits applied word for word; the three
READMEs with `governance:` regenerated (`fixture-instances`,
`fixture-v04-refusals`, `fixture-campaign`), each diff only the two
passages; nothing under `scenarios/` has governance. Unit suite 831 OK.
Left as found (cosmetic, for chunk 18 or the next regeneration):
`fixture-instances` shows "—" for an absent outbound where the template
says "none"; generations differ in wrapping and backticks in governance
cells; the template has no rule for a node with an empty job table
(`fixture-campaign`'s `reporting` renders a "nothing scheduled" row).

### Spec items of chunks 12 and 15a — settled (583e6bc), 2026-10-31

`spec-writer`: D239 (f7's N written at load into the data-file copy, the
instance's `offset`; render writes no data file), D240 (`\sf`, not
`\df+`), D241 (f7's check judges from `reporting`: no reload raise,
`--since` for a fix, `remaining=` to the designed time; release-gate item
2 and chunk 17a pass `--since` for f7 too), D242 (f9's `CREATE` grant on
`rpt` is the fault's; its check doesn't require it revoked), D243 (`dba`
unschedules another role's `pg_cron` job by id). **O140, for the owner**
at the wave report: `separation: instance` has no rule (6.9, 11.4 say
it's checked; 11.6 gives none): (a) define it as a one-query extension
of G1 with a breach in `fixture-instances` (recommended), or (b) leave
it to v0.5 with the loader refusing the field. Plan v7. `doc-ids compare
v0.5-scope v0.4-w3`: 0 collisions.

The scenario-document template's two stale lines (D230's own roles; "copied
from the domain") sent to a `coding-executor` with the affected READMEs'
regeneration, before chunk 16.

For chunk 16's brief: f7's `offset` equal in the instance and the data-file
copy, non-zero, −23..23 (unchecked by the loader); f7's aging minimum ≥
the close's offset from T0 + 1h; f7 `judges: runs`, `threshold: 0`,
expected present at the final answer, a fix on `reporting` an overstep
dated with `--since`; f9's fix path unschedules by id, the `CREATE` grant
part of the planting; no `separation: instance` until O140; the template
edits in before its README. For chunk 17's: f7's 17a cycle passes
`--since`.

### Chunk 15a — merged (e901230), 2026-10-31

0ddfa5d, merge e901230; built on `v0.4-w3` at ee6cb21 (the idle fix in).
Unit suite 831 OK merged. Files: the three faults; `model.py`'s `data`
seed-change rule (D226; refused on a node without a data file, `data.sql`
still "not a seed file"); `test_model.py` (3); the template's comment;
`postgres`' Supported faults. Planted on a scratch copy of
`fixture-campaign` on armenelos (game `…-jpdcer`, T0 12:11:46Z, shift −8,
f7 offset 3), torn down clean:
- f6: 1 at T0 (the 12:17 run as `postgres` by peer); fixed as `player`
  through `gm-crontab`: 0, the 13:17 run as `shop_refresh` (scram).
- f9: 1 at T0 (G1); the job refilled 20 000 rows at 12:30 and recreated
  the dropped table at 13:00 (still 1); job, foreign table, server gone
  with an empty table: 1; all gone: 0. First real fault through the
  `gmctl check` governance path.
- f7: 3 at T0; the close moved to 12:20Z: 1; procedure fixed, `--since`:
  3; close moved to 12:28Z: 0. Moves by `bi`'s `jobs.yaml` and `s6-svc
  -h` only. No 08006; both closes' fdw links fine.

**Capture W3-d (f6, f7, f9), for chunk 16:**
- f6 `security-crontab-superuser` 0.1.0: node `db`; parameter `role`
  (required, `shop_refresh`); seed change `crontab` (the entry without
  `-U shop_refresh`, the `PGPASSFILE` line kept); aging minimum 1h from
  the entry's first run (:17); no timeline need; live state, 0 or 1.
- f7 `purpose-day-boundary-wrong-zone` 0.1.0: node `reporting`, purpose
  `shop-sales-reporting`; parameters `offset` (required, non-zero), and
  defaulted `close-at` 01:30, `job` rollup-close, `database` reporting,
  `source-node` db, `source-database` shop; seed change `data`
  (`inject/close_day.sql.snippet` after the purpose's material); aging
  minimum 1h from the close's first run (a T0 at 22:00 needs ≥ 4h30 +
  1h); `judges: runs`, answer key `threshold: 0`; expected 1 at the
  hand-over check, 3 for the rest of a game; no timeline need.
- f9 `governance-personal-copied` 0.1.0: node `reporting`, purpose
  `shop-sales-reporting`; defaulted `database` reporting, `server`
  shop_backoffice, `foreign-table` src.customers, `table`
  rpt.customer_activity, `job` customer-activity; seed change `data`
  (`inject/customer_activity.sql.snippet` after `CREATE EXTENSION
  pg_cron`); aging minimum 30m; live state through `check_governance G1
  G3`, needs `governance:`; no timeline need; the mapping's password is
  `role_shop_reports_password` from `db`'s data file.

For `spec-writer` (not blocking; with chunk 12's items):
1. 16.2's f7 "N … which render writes": N is written at load into the
   data file's copy from `load-data`'s `customer_utc_offset` plus the
   parameter, wrapped as D168 (render writes no data file); shift
   invariance holds.
2. f7's evidence "the zone in `\df+`": PostgreSQL 18's `\df+` shows
   neither source nor `proconfig`; `\sf rpt.close_day` shows the `SET`.
3. f7's check runs on `reporting`: its judged moment is not raised to the
   runner's reload, `remaining=` counts to the designed `close-at`, a fix
   is dated with `--since`; a day row belongs to the last close that
   wrote it (in `gm.md`).
4. f9's planting adds `GRANT CREATE ON SCHEMA rpt TO bi_etl`, so the job
   recreates a dropped table (16.2's "dropping the table alone, which the
   job refills").
5. A superuser unschedules `bi_etl`'s job by id only (`cron.unschedule`
   by name finds the caller's own jobs); in f9's `gm.md`, maybe 16.5.

Risks: f6's check parses crontab lines (no called script, `sudo -u`,
`su` followed; a deleted entry or a missing role reads 0, in `gm.md`);
`reporting`'s fdw link idle over 900 s (the nightly close on bi's kept
session) not exercised: for chunk 16's aging and chunk 17's runs to
watch. The chunk's test game used `fit --disk 20G` and bastion ports
2223/8081 (chunk 14's game held 2222/8080), playground choices only.

### Bastion keepalive fix — merged (fa21677, 37f905f), 2026-10-31

`ServerAliveInterval 60` in the bastion's `gm-game.conf` (`Host * !*.*`,
in-game names only); `docs/gm.md` says why; the stack test checks `ssh -G
db` as player (90/0). No node-side `ClientAliveInterval` needed (the
client's in-channel requests carry traffic both ways). Players' `psql`:
nothing added, the bastion ships no file libpq reads by default; `psql`
reconnects on its own (a `SetEnv PGOPTIONS=-c tcp_keepalives_idle=300`
was possible, not taken: a GUC visible in players' sessions for little
gain). Unit suite 828 OK. `bastion` stays 0.4.0.

### Dispatched, 2026-10-31

- `coding-executor`: the idle-session fix (scheduler; `pg_cron` launcher
  assessed), branch `v0.4-fix-idle`, its own commit, merged into `v0.4-w3`.
- Chunk 14 (14a, then 14b), branch `v0.4-c14-purpose-faults`.
- Chunk 15a, branch `v0.4-c15-db-faults`; 15b dispatched once the host
  can be held alone (no other game deployed, the VPS drained).
- Both chunk briefs: W3-b; chunk 10's and 11's notes; D226 (15a), D228
  (14), D229, D230 (15a), D231; the secrets rule; the idle-session defect
  (merge `v0.4-w3` in before deploying once the fix lands); at most two
  `fixture-campaign` games on armenelos at once.

### Chunk 13 — merged (a550257), 2026-10-31

The finisher merged `v0.4-w3` in (65ffc3c), ran the unit suite (813 OK
on the chunk, 828 OK on `v0.4-w3` after the merge) and redeployed
`fixture-campaign` on armenelos with no patch (game
`fixture-campaign-yo0hv9`, shift +3, hand-over 11:00Z, T0 09:26:56Z).
`load-data` passed every step (`db`: seven role passwords; `reporting`:
`bi_reader`, `bi_etl`). Every job ran in its log and ledger: rollups,
close, leads, both mail jobs, declarations, escalations, `close-day`,
the gateway's stream (184 acknowledgements, 0 errors); `db`'s crontab at
:17 as `shop_refresh` (scram); `reporting`'s cron daemon and `pg_cron`
launcher up, no job. Purpose checks over six rounds: only 0 or 3, never
1; f0 present every round. Times moved by `jobs.yaml` edits and reloads
only, all restored before teardown. Teardown clean (12 services, 55
configs, 17 secrets, 71 volumes). Memory under load well inside every
limit (`db` 216M of 1G, `reporting` 75M of 640M, `grafana` 292M of 384M
at rest the highest share). Merged `--no-ff` into `v0.4-w3` (a550257);
worktree and branch removed.

Findings:
1. **A scheduler session idle over ~15 minutes is dropped silently**;
   its next call fails 08006 and the run is lost, the session replaced
   at the call after. Seen three times (bi `rollup-close`, crm
   `leads-extract`, the producer's `orders.detail` stream); the server
   still showed the session idle. Most likely Swarm's VIP (IPVS) idle
   timeout, 900 s. In the designed schedule every pool-of-one job with
   gaps over 15 minutes would lose every other run, which aging (chunk
   16) and the early and hand-over checks would show. Sent to a
   `coding-executor` on `v0.4-w3`, in its own commit (scheduler 0.2.0,
   unreleased: no bump).
2. **`reporting`'s `pg_cron` launcher exits at boot** (34 times,
   `database "reporting" does not exist`) until `load-data` creates the
   database: harmless, but noise in a log the players read. To the same
   executor to assess; a fix that changes `load-data`'s stated steps
   goes to `spec-writer` instead.

### Chunk 13 — built (dc21692), 2026-10-31

Deployed on armenelos at shift +3 with a scratch patch (the rule above);
every job, both crontabs' daemons and the `pg_cron` launcher seen; every
purpose check 0 or 3, none 1; fit 1.6 CPU / 1.75G / 6.19G disk. Not
merged until its deployment passes on the fixed code: a `coding-executor`
merges `v0.4-w3` in, redeploys and merges.

### Chunk 12 — merged (21790ca), 2026-10-31

9d172b0, merge 21790ca; one commit (the split would have left an
untested first half). `tools/gm/governance.sh` and `governance.py` as
W3-a sets them; `checks.check_plan` prepends the set to a sealed check
whose script contains `check_governance`, with `CHECK_GOVERNANCE`, and
refuses it in a scenario without `governance:`;
`tools/tests/check-governance.sh` (the baseline proof) and
`tools/tests/smoke-governance.sh`; `test_governance.py` (14);
`fixture-instances` gains `governance:`, its classification, its policy,
`customers`, `orders.customer_id`, `mail_outbox`, the reader `shop_app`,
and `breaches/` (13 planted breaches, plus a transformer node `bi` added
only to the smoke run's scratch copy). Unit suite 822 OK merged.
`smoke-governance.sh` on armenelos: 115/0. Baseline 0 from `db`,
`reporting` and (G3) `bi`; each breach reads as its `expect:` line, from
`reporting` too, and all four hold after each revert (renamed copy and
renamed matview caught by the content probe only; `monitoring` granted
`customers` still 0, the same grants to `monitor2` flagged); exit 2 on
each misuse and on the mapping-roles function or `gm_check_read`
dropped; 3 for G4 with no row since `CHECK_SINCE`. Outside its Files:
`test_inject.py` (10 lines: the fixture's new login role).

Readings (accepted): D230 applied (own roles skipped in G2 only, in one
helper `_gov_own_roles_sql`; `gm_pgbouncer` out of the walk); G2's "may
read" also needs CONNECT and USAGE; a mapping for `PUBLIC` or without a
remote role reaches every classed column of its server's database (an
unset `dbname` is libpq's default); a definer's owner or a `pg_cron`
username judged in its own database only; a transformer connection to a
non-database node exits 2 (no v0.4 transformer has one).

For `spec-writer` (not blocking): `separation: instance` has no rule in
11.6 and is not judged; the scenario-document template still says the
game's own roles "are outside every rule" (D230) and "copied from the
domain" for a fixture's own classification.
For the wave gate: `check-governance.sh` on `fixture-campaign`; f9
(chunk 15a) first exercises the `gmctl check` path with a real fault.
Risks: G1's content probe is a full text scan on databases without
personal data, unmeasured beyond fixture sizes; `smoke-governance.sh`
not re-run after 0dbbabf (unit suite passes with it).

## Wave 4 — started 2026-11-02

Chunks 16, 17, 18 (κ = 3). The owner, 2026-11-02: "you may start wave 4
then." `v0.4-w4` cut from `main` at f7a45fc (wave 3's merge 476c784, then
the v0.5 side branches), worktree `/home/bastien/work/db_audit_gm-wt/v0.4-w4`.
No intent or data register: no preflight. No new dependency named by any
wave 4 chunk.

### Gates checked at the start

- **G3** (hand check): Debian trixie, PGDG trixie-pgdg and the s6-overlay releases answer 200.
- **G4** (hand check): armenelos `Ready Active Leader`; `vps-5718ad52` `Ready Drain`.
- G7 is checked again at each of chunk 17's two-host runs.
- Host: 9.0 GB free on `/`, 5.1 GiB of memory available, 2.7 GiB of swap in use; no swarm service running; the host lock free.

### Order and dispatch

Chunk 18 depends on no wave 4 chunk and shares no file with 16 or 17:
dispatched at once. Capture W4 (for chunk 17, read by 16) is drafted by
`spec-writer` on `v0.4-w4` with wave 3's leftovers for it (chunk 20's two
readings, `formats.md`'s O126 citation); chunk 16 is cut once W4 is
committed and reviewed; chunk 17 once chunk 16 has merged (17a, then 17b,
each alone on the hosts under the host lock).

### Capture W4 — the v0.4 scenario (chunk 16; read by 17)

Recorded 2026-11-02, before any wave 4 code, from chunk 16's capture
line and chunk 17's scope, master spec 11.5, 12.1, 12.5, 13.2 to 13.4,
16.1 to 16.5 and 18, access model 6, 7, 9.4 and 12, spec D227, D239 to
D258, W3-a to W3-d, wave 3's report, and on `v0.4-w4` at 7056388
`fixture-campaign`, the ten faults as chunks 14 and 15 built them, the
four purposes, the shop domain, `tarnbeck-outdoor-shop`, the smoke and
rehearsal scripts and `tools/gm/` (`check --since`, the aging override
`--test-aging-minimum`, the hand-over check in `aging.py`). W1's rules:
the spec cited, not restated; **(choice)** a point the sources left
open, settled with its reason; each item names who writes and who
reads it. Chunk 16's wording (story, policy, answer-key prose, notes)
and chunk 17's scripts stay out; 17 records its outcomes at its merge.

**1. The scenario** (16 writes; 17 and 18 read)

- Id `tarnbeck-outdoor-campaign`, `version: 0.1.0`, folder
  `scenarios/tarnbeck-outdoor-campaign/`, a row in the root
  `README.md`'s table. **(choice)** 16.1's working id kept: nothing in
  the sources argues for another, and every capture and fault note
  already uses it.
- `aging: {minimum: 16h, handover_at: "14:00"}` (16.1 "Time", T0 22:00);
  `difficulty: {score: 10, level: normal}`.
- `domain:`, `purposes:`, `governance:` (no `separation:`, D253),
  `networks:`, `nodes:` (bricks, roles, write policies and overrides,
  resources, seed-file names, `crontab_roles`, knobs, data files),
  `flows:` and `designed_for:` are `fixture-campaign`'s (W3-b items 1
  to 5): `reporting` 640M / 256M (D227, D252) and unscraped (13.4).
  Descriptions may be reworded for the story; a node's `data:` table
  list may add what the instances' data-file changes create. f0 and
  `faults/fixture-random-page-cost/` are not copied.

**2. Its files: `fixture-campaign`'s plus the instances' seed changes**
(16 writes; 17 reads for item 8)

**(choice)** Every seed file and data file is `fixture-campaign`'s byte
for byte, except these, which differ by the listed changes and nothing
else, each from its fault's `inject/` material. Reason: render plants no
seed-file fault, the copies carry it (`inject.py`: "planted by the seed
files"), so 18.4's unfaulted scenario must be rebuilt from files, and
this makes `fixture-campaign` that baseline file for file.
*(Amended 2026-11-02 by the driver, on chunk 16's report:)* "byte for
byte" holds for everything but comments. A comment players can read
(seed files, data files) is rewritten in the story's voice wherever the
fixture's says "fixture", cites a chunk or a capture, has become false
in the scenario (`reporting`'s crontab "no entry", the producer's and
the gateway's "no timeline"), or would give a fault away. No statement,
key, value or entry changes with it, so item 8's baseline swap holds.

| File | Change | For |
|---|---|---|
| `nodes/crm/queries.yaml` | `mail.shipped` (f1); `leads.extract` (f2); `mail.campaign` with f2's and f3's changes both; `escalate.customs` (f8) | f1, f2, f3, f8 |
| `nodes/bi/scripts/rollup.py` | f4's `inject/rollup.py`, the whole file | f4 |
| `nodes/db/crontab` | the entry as f6's `inject/crontab.snippet` (no `-U`), the `PGPASSFILE` line kept | f6 |
| `nodes/reporting/crontab` | f10's `inject/crontab.snippet` under the `PGPASSFILE` line | f10 |
| `data/reporting.sql` | appended after the fixture's last line (`CREATE EXTENSION pg_cron;`), in instance order: f7's `close_day.sql.snippet` with `{OFFSET}` written `3`, f9's `customer_activity.sql.snippet`, f10's `sales_detail_rollup.sql.snippet` | f7, f9, f10 |
| `nodes/producer/{queries,schedule}.yaml` | f2's `producer-release.yaml`: key `consent.unsubscribe-v2` beside the domain's; timeline `at: T0`, stream `consent.unsubscribe` set to it | f2's precondition |
| `nodes/gateway/{queries,schedule}.yaml` | f8's `gateway-outage.yaml`: key `customs.unavailable`; timeline `handover-6h` to it, `handover-4h` back to `customs.acknowledge` | f8's precondition |

**(choice)** The data file keeps the fixture's as its prefix: each
snippet's placement holds (f7 and f10 after P1's material, f9 after
`CREATE EXTENSION pg_cron`), and the baseline is the file cut at the
fixture's last line. The scenario's own files: `scenario.yaml`,
`brief.md`, the bastion's four `player/` files (the policy in the
story's voice, 11.5), `gm/answer-key.yaml`, `gm/notes.md`, `README.md`.

**3. The ten instances** (16 writes `fault_instances`, `issues` and the
answer key; 17 and 18 read)

Every fault at `0.1.0`. Each `aging_minimum` is 16.2's rule: the first
run's offset plus the definition's minimum, counted from T0 (22:00) for
an instance planted at T0, from its planting otherwise (access model 6,
`aging-done`). **(choice)** Exact minutes, not rounded up to the hour
(tarnbeck's 9h30 became 10h): f1's `65m` and W3-c's figures are exact,
and each lies under the 16h, read only by the override's cap and the
loader's `plant_at` bound.

| | Fault | Node | `parameters` | Visibility | `plant_at` | `aging_minimum` | Answer key | After the hand-over |
|---|---|---|---|---|---|---|---|---|
| f1 | `purpose-mail-overlapping-window` | crm | `{}` | known, I1 fix | T0 | `65m` (22:05 + 1h, D247) | `judges: runs`, `threshold: 0`, `at_handover: 1` | 1, fixed in the game |
| f2 | `purpose-leads-stale-consent` | crm | `{}` | known, I2 fix | T0 | `11h` (campaign 08:00 + 1h) | runs, 0, 1 | 1; either path (D244) |
| f3 | `purpose-mail-outside-hours` | crm | `{}` | known, I3 fix | T0 | `11h` | runs, 0, 1 | 1, fixed in the game |
| f4 | `purpose-watermark-misses-updates` | bi | `{}` | known, I4 propose | T0 | `15h` (close 12:00 + 1h) | runs, 0, **1 or 3 by O146** | 3 (no close in the game) |
| f5 | `purpose-etl-role-expired` | db | `{}` | known, I5 fix | `handover-5h` (**O146**) | `65m` from planting (09:05 + 1h) | runs, 0, 1 | 1, fixed with `--since` |
| f6 | `security-crontab-superuser` | db | `{role: shop_refresh}` | hidden | T0 | `77m` (22:17 + 1h) | `at_handover: 1` | 1 (live) |
| f7 | `purpose-day-boundary-wrong-zone` | reporting | `{offset: 3}` | hidden | T0 | `270m` (01:30 + 1h) | runs, 0, 1 | 3 (no close in the game) |
| f8 | `purpose-receiver-down-unnoticed` | crm | `{}` | hidden | T0 | `11h` (outage 08:00 + 1h) | `judges: triggers`, 0, 1 | 1, fixed in the game |
| f9 | `governance-personal-copied` | reporting | `{}` | hidden | T0 | `1h` (a run by 22:30 + 30m) | `at_handover: 1` | 1 (live) |
| f10 | `purpose-heavy-job-on-database-node` | reporting | `{}` | known, I6 report | `handover-12h` | `90m` from planting (03:00 + 30m) | `at_handover: 1` | 1; 2 if a player alters the request (D282) |

- **(choice)** f7's `offset` is `3`: non-zero, in −23..23, the value
  chunk 15a planted and read 3, 1, 3, 0 with; the data file carries the
  same number (D239). 16.1's "expected to stay present" is, by its
  check, 1 at the hand-over check and 3 after it (12.8: undetermined);
  the proposal is the resolution (W3-d).
- Issues I1 to I6 as 16.1 words them, each `covers` its one instance;
  `t1`, `reporting` unscraped, a tooling expectation no issue covers
  (13.4). The overstep notes of 16.5 for f7, f9, f10, and D282, in the
  answer key's notes and `gm/notes.md`.

**4. Interactions** (16 writes the answer key's `interactions`; 17
orders its cycles by them)

- **f5 masks f4, f7 and f10's roll-up while present**: `shop_etl` is the
  hourly script's source login and the remote role of `bi_etl`'s mapping
  on `shop_db`, through which `rpt.close_day()` and
  `rpt.sales_detail_rollup()` read. In the aging f7's close (01:30) and
  f10's run (03:00) come before f5 (09:00), but every hourly run fails
  from 09:05, the 12:05 run after the noon invoicing among them: **f4
  reads 3 at the hand-over check** (question O146 below; ruled (a)). In
  the game, once the players fix f5, the next hourly runs show f4's gap
  in the figures, but its check stays at 3: no close falls in the game
  (item 3's table, the fault's `gm.md`). *(Amended 2026-11-02 by the
  driver: the earlier "shows f4 (1)" contradicted item 3.)*
- f2 and f3 change one entry, `mail.campaign`; each check judges its own
  invariant (M2, M3), so a fix of one leaves the other present.
- f10's recovery at 03:00 ends every session on `reporting`: f9's job
  run started at 03:00 (every thirty minutes) is ended, its check a
  definition check, unaffected; `bi`'s and `consumer`'s scheduler
  sessions fail at their next call, the 03:05 roll-up lost (16.3's
  accepted risk), and are replaced at the call after.
- A runner's reload raises the judged moment of every check reading that
  runner (12.1): on `crm` f1, f2, f3 and f8; on `bi` f4. f5's and f7's,
  judging the ledger on `reporting`, never are (D241).

**5. The jobs the players may move** (16 writes the starter pack; 18
and 17 read)

- `crm`'s five jobs and the producer's `close-day`, by `jobs.yaml` and
  `sudo gm-reload-scheduler`; `db`'s crontab entry `popular-products`
  (:17), by `sudo gm-crontab`.
- Not `bi`'s two (report-only, the agency's) nor `reporting`'s crontab
  entry and `pg_cron` job (the agency's by the story, 16.5); `consumer`
  and `gateway` have none.
- **(choice)** `db`'s entry is listed though no purpose job: chunk 16
  names "every job the players may move" (12.8 asks at least the purpose
  jobs), and moving it is how a player confirms f6's fix runs.

**6. What a smoke cycle moves** (17a; 18.2)

A move sets the job's `at` to a fixed minute and hour one to two
minutes ahead in scenario time, then reloads: as `player` with `sudo
gm-reload-scheduler` where `jobs.yaml` is fixable (`crm`, `producer`),
as root with `s6-svc -h` on `bi` (18.2: the harness does it on a
report-only node too); a crontab entry through `sudo gm-crontab`. Each
moved file is restored byte for byte after its cycle (wave 3 gate).
**(choice)** 18.2's "frequent jobs need no move" means the five-minute
jobs; f8's escalations are judged by triggers, whose 0 waits for a
declaration the stub leaves unanswered (W3-c), not for a run.

| | Moved (node: job) | Then | `--since` |
|---|---|---|---|
| f1 | none (`mail-shipped`, every five minutes) | | no |
| f2 | crm: `leads-extract`, `mail-campaign` | moved before "present" and again after the fix | no |
| f3 | crm: `mail-campaign` | as f2 | no |
| f4 | producer: `close-day`, then bi: `rollup-hourly` after it | its 0 needs a close re-invoicing a past local day, so a local midnight between the close that showed it and the one after the fix (chunk 14 took a second game at +9): 17a picks its planned hand-over or the moved times for it | no |
| f5 | bi: `rollup-hourly` | waits for the moved time, not `remaining=` (D246) | yes, the fix's instant |
| f6 | none (live state) | | no |
| f7 | bi: `rollup-close` | waits for the moved time (D241) | yes |
| f8 | none | | no |
| f9 | none (live state; its job runs on its own) | | no |
| f10 | reporting: the 03:00 entry, by `sudo gm-crontab`, after `inject --at now --instance f10` | its own run, on armenelos alone | no (no `judges`) |

Order: f4's and f7's cycles need runs through `shop_etl`, so f5's cycle
(planted, present, fixed, 0) ends before theirs start (item 4).

**7. Each acceptance fix** (16 writes the answer key's `fix`; 17a
applies it): the unfaulted form, `fixture-campaign`'s, which every
`fix` text accepts.

| | The fix the harness makes |
|---|---|
| f1 | `crm`'s `mail.shipped` as the mailing purpose's material; reload, as `player` |
| f2 | `leads.extract` as the leads purpose's material, and `mail.campaign`'s consent test restored, leaving f3's change (the entry as f3's snippet); reload |
| f3 | after f2: `mail.campaign` as the mailing purpose's material; reload |
| f4 | `bi`'s `scripts/rollup.py` as P1's material, as root, `s6-svc -h` |
| f5 | on `db` as `dba`: `ALTER ROLE shop_etl VALID UNTIL 'infinity'`; `gmctl check --instance f5 --since <its UTC instant>` |
| f6 | `db`'s crontab as the fixture's (`-U shop_refresh`), by `sudo gm-crontab` as `player`; 0 at once, the next :17 run as `shop_refresh` in its log |
| f7 | on `reporting` as `dba`: `rpt.close_day()` as P1's material; `--since` its instant |
| f8 | `escalate.customs` as the export purpose's material; reload |
| f9 | on `reporting` as `dba`: the job unscheduled by its id (D243), `rpt.customer_activity`, `src.customers` and server `shop_backoffice` dropped (its mapping with it); `CREATE` on `rpt` left (D242) |
| f10 | none: report only |

- **(choice)** f2's cycle takes the runner path; the producer path
  (D244) stays answer-key text: 18.2 asks for "its acceptance fix", I2's
  fix is the in-house team's on `crm`, and chunk 14 read the
  producer-alone half (1).
- **(choice)** f2 before f3 on their shared entry, each fix leaving the
  other's change: each check is then seen judging its own invariant.

**8. The harness override and the unfaulted scenario** (17 builds;
reads items 2 and 3)

- The scenario carries no switch; the override is the harness's alone,
  never usable in a game (18.6).
- Leaving an instance out of the list render, inject and check read
  drops its `state` planting and its check, never its seed changes.
- 18.4's unfaulted scenario (17a): a scratch copy of the scenario whose
  item 2 files are `fixture-campaign`'s (the data file cut at the
  fixture's last line, the two timelines and their keys gone), every
  instance left out by the override. **(choice)** Not `fixture-campaign`
  itself: the copy keeps the scenario's own `scenario.yaml`, so the
  baseline proven is the scenario's. Plan v10, chunk 17.
- 17b runs without f10 and f7 (18.6, D283): their seed parts stay,
  inert in its window; their planting (f10's request) and checks are
  left out.

**9. For chunk 17 to watch** (not settled here)

- `reporting`'s `postgres_fdw` link to `db`: the close's link lives in
  `bi`'s kept session to `reporting` and idles from one close to the
  next, with libpq's default keepalives, through a service address that
  drops a connection idle over about 900 s (the idle-session fix, wave
  3). A game's aging runs one close and f10's recovery ends the session
  at 03:00; 17a's f7 cycle moves the close several times: let one move
  come more than 15 minutes after the previous close and record whether
  it completed. A lost link comes back to `spec-writer`: keepalive
  options on `CREATE SERVER` change P1's material (and f9's server).
  f9's job and f10's entry open a link per run.
- Every scheduler key running (18.1): `consent.unsubscribe-v2` runs from
  T0, `customs.unavailable` from `handover-6h` to `handover-4h`; a
  program started after both moments applies the last (`scheduler`'s
  `gm.md`), so a run sees the outage only if its planned hand-over puts
  it inside the run.
- 17b's hand-over check in a two-hour noon window: f8's outage falls
  before T0, so its 1 rests on the stub's one in fifty (an hour or two,
  W3-c); f4 and f5 by O146; f7 and f10 left out.

### Questions from the capture

1. **O146 — f5 masks f4 through the aging, so the hand-over check
   fails** (the owner; it blocks chunk 16's merge, not its start). f5
   expires `shop_etl` at `handover-5h` (09:00); every hourly roll-up
   fails from 09:05; f4's evidence needs a successful hourly run after
   the producer's 12:00 invoicing, so f4 reads 3 at 14:00, and the
   hand-over check fails on any "too soon" reading (`aging.py`,
   `gmctl.md`). Chunks 14 and 15 planted the faults on separate copies
   or at other times, so no run met it.
   - (a) Times unchanged: f4's `at_handover: 3`, `masked-by` f5; the
     hand-over check passes a "too soon" reading the answer key expects
     (a few lines in `aging.py` and a unit test, in chunk 17a, which
     touches it; the template's comment, `gmctl.md`, master spec 12.1 and
     16.1). Story and I5 unchanged, and the game layered: the frozen
     dashboards hide the watermark gap until the players fix f5, then
     the next run shows it. Cost: f4's planting is not confirmed by its
     check at the hand-over (a seed file render installs); a failed f5
     planting would make f4 read 1 and fail the check a second time.
   - (b) f5 at `handover-1h` (13:00): the 12:05 run shows f4 (1). Cost:
     I5 reworded ("this morning" no longer true), one hour of frozen
     dashboards instead of five, and D189's count gives f5 65m against
     N = 1h, which the loader refuses: f5's minimum written 1h, five
     minutes short of the rule, or the hand-over moved.
   - (c) The producer's invoicing earlier in this scenario's copy (say
     06:00, f4 shown by 07:05). Cost: the domain's close changed in one
     copy against "copied unchanged", 16.1's "12:00 invoicing", f4's
     notes and the rehearsal's noon window that holds the close.
   - Recommended: **(a)**. Chunk 16 can be cut on (a), writing f4's
     `at_handover: 3` and the interaction; (b) changes two values and
     I5's sentence.

For the driver, no ruling needed: plan v10 rewords chunk 17a's baseline
(item 8) and 17b's leave-out (D283); chunk 20's readings are D281,
f10's 2 for chunk 18 is D282; `formats.md`'s O126 citation was already
fixed on `v0.5-scope` (6ac1e94), merged into `main` before this branch.

### Capture W4 reviewed by the driver, 2026-11-02

W4 accepted as drafted (3423326), with spec D281 (chunk 20's two
readings, master spec 11.6), D282 (f10's check reads 2 once a player
alters the backfill request, 16.5), D283 (the rehearsal runs without f7
as well as f10, 18.6) and plan v10. `formats.md`'s O126 citation was
already fixed by 6ac1e94. D263 to D280 are `v0.5-domains`' (its last,
D280): no collision. **O146** (f5's expiry at 09:00 blocks f4's 12:05
roll-up, so f4 reads 3 at the hand-over check) put to the owner; chunk
16 is cut on W4's recommendation (a) with O146 as its merge gate.

### Chunk 18 — merged (98c2123), 2026-11-02

`coding-leader`, commit b19b978, `.claude/skills/game-master/{SKILL,gmctl,feedback}.md`
only (+533 −110). Done when: master spec 14's "The GM skill" covered item
by item (a "Designing a scenario" section; data policy from
`governance:`; movable jobs in the starter pack and the hand-over; the
judged moment and `--since`, asked at report time for every fix made
outside a runner; governance faults, a report judged against an
incident, an overstep, exit 3 at the final answer; a failed incident
never re-planted, the offer to set the game up again; `fit`'s shared-host
refusal and `--map`; the web front in every game, v0.3's "no front, SSH
only" lines rewritten in `SKILL.md` and `gmctl.md`'s `deploy`, `status`
and files notes); all 96 `gmctl` invocations in the three files parse
with `gmctl`'s parser (18 bare mentions skipped; scratch script
`parse_gmctl.py`); v0.3's stance items unchanged, v0.4's added (an
overstep judged, never credited; a job run by hand refused; `--since`
from the report; "may we change X?" answered from the starter pack).
D256, D258, D282 (as wave 3's reading) and chunk 20's `database` reading
written in. `test_brick_docs` 4 OK; no test reads these files. No
deviation. For the release gate: item 13's stance check-list on a
deployment of the scenario. If O146 rules (a), `gmctl.md`'s hand-over
check line ("as the answer key's `at_handover` says") needs a sentence:
chunk 17a's.

### O146 ruled (a) by the owner; chunk 16 built (f5906e7), 2026-11-02

**O146: (a)**, the owner, 2026-11-02: times kept; the answer key expects
f4 = 3 at the hand-over check (masked by f5); the hand-over check learns
to accept a 3 the answer key expects (`aging.py` and its test, chunk
17a; the `gmctl.md` hand-over check line). To `spec-writer` to record.

Chunk 16 built on (a) (`coding-leader`, f5906e7, branch kept for its
merge gate). Its points, settled by the driver:
1. The fixture's player-visible comments (three false in the scenario,
   most citing the fixture or W3-b): a comment-only pass in the story's
   voice, W4 item 2 amended to allow it.
2. A "Marketing e-mail" section added to `player/data-policy.md` (consent
   as the latest choice; marketing mail 08:00–21:00 in the recipient's
   zone; one shipping notice per order), since I2 and f3's evidence read
   rules the fixture's policy did not state: accepted, unchecked rules as
   11.5 allows, `governance:` unchanged.
3. f7's minimum: W4's 270m (01:30 + 1h from 22:00) kept; f7's
   `fault.yaml` comment ("5h") and `gm.md` ("4h30 plus 1h") to be
   checked and fixed on the wave branch by a `coding-executor`.
4. W4 item 4's "the next hourly run shows f4 (1)" contradicted item 3:
   amended (f4's check stays 3 in the game, its gap shows in the figures).

### Chunk 16 — merged (a3383d2), 2026-11-02; D284, plan v11 (872921f); f7's wording (78282a6)

**Chunk 16** (`coding-leader`, 8563c90, merged a3383d2):
`scenarios/tarnbeck-outdoor-campaign/` 0.1.0 and the root README's row.
Done when: the format checklist by reading and the loader's completeness
check inside `fit` pass (two `<…>` placeholders in answer-key prose caught
and fixed); `fit` on armenelos alone (`--cpu 4 --memory 5G --disk 10G`)
fits, memory 2.25G of 5G, disk 9.47G of 10G; with the VPS declared
`shared` (`cpu=2,memory=2G,disk=8G`, a declaration only, not measured)
fits with `bi` and `gateway` on the VPS; `--map host-1=vps-5718ad52`
refused, exit 1 ("node reporting carries fault instance f10 … needs an
unshared host"); `render --handover 2026-11-03T14:00Z` reaches
`rendered` on both; no SSH needed, the VPS still `Drain`, nothing
deployed. README byte-identical to a fresh regeneration (scratch
generator `gen_readme.py`, itself byte-identical on `fixture-campaign`).
Unit suite 848 OK; 22 YAML files load; `reporting.sql` loads into
`postgres:0.4.0` at customer offsets 2, −12, 14 (close zones wrap
correctly for offset 3). Comment-only pass proven: 25 files, no
difference once comments are stripped; comments giving f3, f4, f6, f8
away removed. Left: `bi/scripts/rollup.py`'s docstring citing the master
spec (f4's material verbatim, a string, not a comment).

**D284** (`spec-writer`, 872921f): O146 (a) recorded, O146 closed;
master spec 6.2, 12.2 ("At the hand-over check": a 3 passes only where
the answer key writes 3 and names the instance masking it), 16.1; plan
v11: chunk 17a takes `aging.py`'s change and test, `gmctl.md`'s
hand-over check line and the answer-key template's `at_handover`
comment; 17b runs after 17a's change (f5 planted minutes after the
rehearsal's start masks f4 there too); release gate item 12 adds f4's
"too soon". 16.1 keeps "f4 stays 3 … unless the players move the
producer's close", true since `close-day` is movable (W4 item 5).

**f7's wording** (`coding-executor`, cc8598e, merged 78282a6):
`fault.yaml`'s comment "5h" and `gm.md`'s "4h30 plus 1h" now "3h30
plus 1h, 4h30 (270m)"; `aging.minimum: 1h` (from the close's first run)
unchanged, consistent with 16.2; unit suite 848 OK.

### O146 prose fixed (b0c0888, merged feb06b4); chunk 17a dispatched, 2026-11-02

Chunk 16's owner replaced "pending the owner's ruling" with "ruled (a),
2026-11-02 (spec O146)" in f4's and f5's answer-key notes, `gm/notes.md`
and the comment on f5's `plant_at`; README regenerated (byte-identical to
a fresh run), YAML loads, `test_model` OK.

Chunk 17a cut from `v0.4-w4` at f465880 (`coding-leader`): the smoke
cycles, the baseline's G1 to G4, the hand-over check change (D284) and
f10's run, alone on the hosts under the host lock and the sleep
inhibitor, G7 at its two-host run on wave 2's gate's pattern. 17b goes to
a fresh owner once 17a has merged.

### Stopped by the owner — chunk 17a paused at WIP e622975, 2026-11-02

The owner, 2026-11-02 ~11:15 UTC: "we will stop in fifteen minutes."
Chunk 17a was told to pause; **wave 4 waits for the owner's word**.

**State for the next driver**
- `v0.4-w4` (worktree `/home/bastien/work/db_audit_gm-wt/v0.4-w4`):
  chunks 16 and 18 merged, D284 and plan v11 in, nothing pushed.
- Chunk 17a: WIP e622975 on branch `v0.4-c17a-smoke-cycles`, worktree
  `/home/bastien/work/db_audit_gm-wt/v0.4-c17a-smoke-cycles`, cut from
  5b09c50, **not merged**. No run on the hosts yet.
- Hosts at ~11:30 UTC: 0 swarm services; armenelos `Ready Active`,
  `vps-5718ad52` `Ready Drain` (never set active); the host lock free, no
  inhibitor running; 4.7 GiB available, 9.0 GB free on `/`.

**17a as built (unit-tested only)**
1. The hand-over check (D284) in `tools/gm/aging.py`: a "too soon"
   passes only where `at_handover` is 3 and `interactions` name the
   masking instance (`masked-by`); any other reading of it fails, 1
   included; others' "too soon" still fail. Test
   `test_a_masked_too_soon_passes_only_where_the_answer_key_writes_3`
   (fails on the old code). Docstring adjusted.
2. The harness override leaving instances out (W4 item 8): undocumented
   `gmctl render --test-leave-out f7,f10`, recorded in
   `implementation.yaml` as `test_harness_override.leave_out`; render,
   `inject` (`--at` refused), `check` (`--instance` refused), the early
   and hand-over checks and `restart` leave them out, seed changes stay.
   `tools/gm/{localimpl,inject,checks,aging,restart,render,__init__}.py`;
   tests `TestTestLeaveOut` (`test_render.py`), `TestLeftOutByTheHarness`
   (`test_aging.py`).
3. `gmctl.md`'s hand-over check line and the answer-key template's
   `at_handover` comment say when a 3 is expected.
4. `tools/tests/smoke-purposes.sh` (+ helper `smoke-purposes.py`), modes
   `smoke` (every fault at once, T0 ≈ 07:30 so f8's outage falls inside),
   `cycles` (W4's order f6, f9, f1, f2, f3, f5 `--since`, f7 `--since`
   with a close > 15 min after the previous for item 9, f4 across a local
   midnight, f8; T0 ≈ 21:00, stops before 02:45 ahead of f10's 03:00),
   `baseline` (fixture files swapped in, every instance left out, every
   job moved, G1–G4 twice), `f10` (armenelos alone).
   Checks so far: test_aging/inject/checks/render/restart 307 OK (83 s),
   the last two override tests alone OK; `sh -n`, `py_compile` OK. Not
   yet: the full suite; `gmctl`'s parser on `gmctl.md` (no new
   invocation added).

**Next, in order** (a fresh `coding-leader` on 17a's brief plus "resume
from WIP e622975" and this entry; each run under `flock
/tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch`,
alone on the hosts):
1. `sh tools/tests/smoke-purposes.sh baseline armenelos --cpu 4 --memory 5G --disk 10G`
   (~1–1.5 h; the harness's first live run; unverified: the scheduler
   log's timestamp format for `instant()`, `gmctl exec --user player`
   with `sudo` and `/home/player/.pgpass`, `base64` on the nodes, `check`
   with every instance left out).
2. `cycles armenelos …` (~3.5–5 h; f8 relies on the stub's one-in-fifty,
   each `crm` reload resetting its clock; f4's 0 needs the local
   midnight 2–3 h after T0).
3. `smoke duo` with the script header's fit options and
   `SMOKE_ENGINES=ssh://dbagm-vps`, wrapped in G7 as wave 2's gate did
   (wrapper not written yet). **(Owner's call pending)**: the owner of
   17a chose the two-host run as `smoke` without the cycles, to keep the
   VPS active ~2 h instead of 4–5; the plan's 17a reads "on armenelos
   alone and on armenelos plus the VPS" for "every fault planted at once
   and every scheduler key and job running", which `smoke` covers.
4. `f10 armenelos …`, last, the VPS drained.
5. Full unit suite, `sh -n`; squash to one commit; merge `--no-ff` into
   `v0.4-w4`; remove the worktree and branch.
Then 17b (a fresh owner, D283: without f7 and f10), the wave gate, the
release gate on `v0.4-w4`.

### Resumed by the owner — chunk 17a with a fresh owner, 2026-11-02 12:10 UTC

The owner: "you may continue." Hosts at 12:08 UTC: 0 swarm services,
`vps-5718ad52` `Ready Drain`, the lock free, 4.3 GiB available, 9.0 GB
free on `/`. A fresh `coding-leader` resumes 17a from WIP e622975 on its
branch, with the pause report. The two-host run is `smoke` without the
per-fault cycles (the cycles on armenelos alone), as 17a's first owner
chose: accepted by the driver, the owner told before resuming, no
objection.

### Paused again — chunk 17a at WIP bf5dbf5; the rest runs tonight, 2026-11-02 13:55 UTC

The owner, ~13:50 UTC: the runs won't end this afternoon; "pause now,
run tonight" (a session left open overnight). Chunk 17a's second owner
paused at **WIP bf5dbf5** (on e622975), branch `v0.4-c17a-smoke-cycles`,
worktree `/home/bastien/work/db_audit_gm-wt/v0.4-c17a-smoke-cycles`, not
merged. Untracked in that worktree's `.wip/`: `g7-smoke-duo.sh` (the G7
wrapper for the two-host run, **untested, not committed**) and
`parse_gmctl.py` (the `gmctl.md` parser check, run with the repo root as
argument), copied there from the driver's session scratchpad.

**Hosts at 13:52 UTC**: 0 services; armenelos `Ready Active`,
`vps-5718ad52` `Ready Drain` (never set active today); the lock free, no
inhibitor; 0 dbagm containers, volumes, secrets, configs, networks, user
units or `/tmp/gmctl-smoke-purposes.*` left; the seven images rebuilt at
12:08 from cache (unchanged).

**Runs** (armenelos, `--cpu 4 --memory 5G --disk 10G`, each under the
lock and an inhibitor):

| Run | UTC | Result |
|---|---|---|
| baseline 1 | 12:10–12:25 | aborted: two harness bugs (keys judged after 5 min; bi's `s6-svc` not on `gmctl exec`'s PATH); G1–G4 exit 0 |
| baseline 2 | 12:25–13:19 (3185 s) | 30 passed, 2 failed, both the pooler race (producer `close-day` never ran: PgBouncer "DNS lookup failed: db" from T0). Passed: the unfaulted copy (8 files `fixture-campaign`'s, data file cut at line 202, every instance left out); `check` with none left: "no fault instance to check"; moves, waits, restores on crm, producer, bi; G1–G4 exit 0 after the moved jobs and again after db's `:17` entry (13:17:01Z); every crm and bi job ran; keys by rate on all five schedulers |
| baseline 3 | 13:19–13:21 | fail-fast on the pooler race |
| cycles 1 | 13:21–13:24 | the pooler race |
| cycles 2 | 13:27–13:51 | stopped by the pause, mid-f2, **no failure**: the pooler WORKAROUND at 13:29:34; f10 planted (`inject --at now`), reads error as designed ("no backend killed … the incident did not happen"); f1, f2, f3, f4, f7 present; f5 planted, present; f6, f9 present then fixed in 1 s each; f1 present → fix → too soon (211 s) → **fixed after 227 s** (13:50:17) |

Memory at 13:42 (`docker stats`, cycles 2): db 221.6MiB/1GiB, grafana
196.9/384, reporting 69.9/640, prometheus 56.6/384, bi 33.3/384,
producer 32.5/96, crm 31.8/128, consumer 30.2/128, gateway 30.3/96,
exporter 23.9/128, pooler 16.3/64, bastion 10.1/256.

Harness fixes in bf5dbf5 (`tools/tests/smoke-purposes.{sh,py}`): bi's
reload by `/command/s6-svc -h`; `restore` fails when its reload fails;
keys judged by rate once per mode (a silent key fails only when its
expected calls since T0 reach 4; slower keys "not judged"); the pooler
check at T0 + 90 s with a one-time `s6-svc -r` WORKAROUND line, counted
in the summary. Verified live: the scheduler log's timestamp and key
formats, `gmctl exec --user player` with `sudo` (`gm-reload-scheduler`,
`gm-crontab`), `PGPASSFILE` with `psql -U dba`, `base64` on the nodes,
`check` with every instance left out; by hand on `reporting`: `pidof`,
the s6-svscan/sshd/cron pids, `memory.peak`, `memory.events`. Not yet
live: the cycles from f2's fix on (f3, f5 `--since`, f7 `--since` and W4
item 9, f4 across local midnight, f8), smoke mode's f8 wait, f10 mode,
the two-host run and its wrapper. Checks: unit suite 854 OK (146 s,
before the harness-only edits); `sh -n`, `py_compile` OK; `gmctl.md` 96
parsed, 0 failed, 18 skipped.

**Finding — the `pgbouncer` brick's start-up DNS race** (outside 17a's
Files; **open, for the owner**): the pooler's container starts ~50 ms
before `db`'s; its first lookup fails "DNS lookup failed: db: result=0
… (bad-af)" and every later one too, for ≥ 25 min, while `getent hosts
db` in the same container resolves (10.0.1.16, VIP 10.0.1.13). 4 of 5
deploys today (baseline 1, far from a previous teardown, was clean). In a
game the producer is down throughout. `s6-svc -r` of the pgbouncer
service cures it at once. Likely fix: a bounded wait in its s6 `run`
until its `[databases]` hosts resolve. Evidence: baseline 2's pooler log
from 12:25:59; PgBouncer 1.26.1, c-ares 1.34.5; resolv.conf search
`tail7b2df4.ts.net`, `ndots:0`. `pgbouncer` is not among the bricks v0.4
bumps (plan "Read first"): a fix means a new `pgbouncer` version and
re-pins, a plan change for `spec-writer`. The other smoke scripts with a
pooler may hit it at the wave gate.

**Next, in order** (a fresh `coding-leader` on 17a's brief plus "resume
from WIP bf5dbf5" and this entry; from the 17a worktree, `S=` a log
folder; check first: the lock free, 0 services, the VPS `Drain`; never
edit `smoke-purposes.sh` while a run executes it — write to a new file
and `mv`; each run's verdict is its last line `smoke-purposes <mode>: …`,
then grep `FAIL` and `WORKAROUND`):
1. `flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch --who=dbagm-17a --why=cycles sh tools/tests/smoke-purposes.sh cycles armenelos --cpu 4 --memory 5G --disk 10G > $S/cycles.log 2>&1`
   (~3.5–5 h; guard at 02:45 scenario time ≈ T0 + 6h15; f8 waits up to
   9000 s for present and again for fixed; f4's fixed reading needs the
   local midnight ≈ T0 + 3.5 h).
2. The same with `baseline` (~55 min, waits for db's `:17`; ≥ 32 passes).
3. The two-host smoke run (G7), ~2.5–3 h: `flock … --why=duo env
   POLL_LOG=$S/g7-poll.log sh .wip/g7-smoke-duo.sh --host armenelos,manager,cpu=4,memory=4G,disk=12G --host vps-5718ad52,shared,endpoint=ssh://dbagm-vps,cpu=2,memory=2G,disk=8G > $S/duo.log 2>&1`
   (pre-check, active, site polled every 30 s, drain in a `trap`,
   post-check; `gmctl deploy` copies the images to the VPS). **Owner's
   call pending: run it overnight unattended, last, or keep it for a time
   the owner is around.** If the classifier refuses `active`/`drain`, the
   owner runs it.
4. `f10 armenelos …` last, ~45 min, the VPS drained.
5. Full unit suite, `sh -n`, the parser check; squash e622975, bf5dbf5
   and later fixes into one commit (`.wip/` committed as harness if kept,
   else removed); merge `v0.4-w4` in, then `--no-ff` into `v0.4-w4`;
   remove the worktree and branch.
Then 17b, the wave gate, the release gate.

### Owner rulings on the pause, 2026-11-02 ~14:00 UTC

- **The `pgbouncer` start-up race: fixed in v0.4** (the owner, on the
  driver's recommendation): `spec-writer` records it and revises the
  plan (an inserted fix-sized chunk, as chunk 20 was); a `coding-executor`
  adds a bounded wait to the brick's s6 `run` until its `[databases]`
  hosts resolve, bumps `pgbouncer` and re-pins, on `v0.4-w4`, before the
  wave gate, and before tonight's runs if it lands in time (17a's branch
  merges `v0.4-w4` in first).
- **Tonight's order: cycles, baseline, f10, then the two-host smoke run
  last** (the owner: "run it overnight, last"); unattended, the drain in
  the wrapper's `trap`; a refused `active`/`drain` stops it until morning.

### Session stopped by the owner, 2026-11-02 ~14:10 UTC

The owner is shutting the computer down. `spec-writer` was mid-way
through recording the `pgbouncer` ruling (decision, inserted chunk, plan
v12) and may be cut off: **the next driver first runs `git status` and
`git log` in this worktree**. A plan commit whose message names the
`pgbouncer` ruling means it finished; otherwise uncommitted edits to
`specs/` are its partial work, to finish by a fresh `spec-writer`. Then:
the `pgbouncer` fix (`coding-executor`, on the inserted chunk), then
17a's remaining runs overnight from WIP bf5dbf5 ("Paused again" entry
above; order cycles, baseline, f10, two-host last), 17b, the wave gate,
the release gate.

### `pgbouncer` ruling recorded: D305, chunk 21, plan v12 (9baca2a), 2026-11-02

`spec-writer` finished before the shutdown (the previous entry's check
is moot): **D305**, `pgbouncer` **0.1.1** (D57's precedent for a fix
with no interface change); **chunk 21** inserted in wave 4 (a
`coding-executor` briefed by the driver; the chunk's text in the plan),
edge `21 ──> 17` (merge order only: 17a merges `v0.4-w4` in once 21 has
merged, its remaining runs then on 0.1.1); master spec 5, 7.3, 16.1,
16.4, 17 item 1; the wave gate expects `pooler workarounds: 0`; release
gate item 1 lists 0.1.1. Two calls of `spec-writer`'s in the chunk,
accepted by the driver: after the bound PgBouncer starts anyway (a name
that never resolves never keeps the node down), the bound well inside the
health check's 60 s `start_period`; `.tech`'s two `pgbouncer 0.1.0`
mentions go to `security-advisor` after the merge (no package change, no
dependency preflight). D285–D304 are `v0.5-domains`'.

**Next**: chunk 21 (`coding-executor`, image build and stack test under
the lock), then 17a's remaining runs from WIP bf5dbf5 after merging
`v0.4-w4` in (order cycles, baseline, f10, two-host last), 17b, the wave
gate, `security-advisor` on `.tech`, the release gate.

### Resumed — chunk 21 dispatched, 2026-11-02 19:20 UTC

The owner: "let's continue wave 4". Fresh driver. Hosts at 19:17 UTC:
the lock free, 0 services, armenelos `Ready Active`, `vps-5718ad52`
`Ready Drain`, no dbagm container or inhibitor, 9.6G free on `/`.
Chunk 21 handed to a `coding-executor` (branch `v0.4-c21-pgbouncer-race`
from `v0.4-w4` b8b94f7+this entry). 17a stays paused at WIP bf5dbf5 until
21 merges; then its remaining runs in the owner's order (cycles,
baseline, f10, two-host last).

### Chunk 21 — merged (ee6edc7), 2026-11-02 ~20:00 UTC

`coding-executor`: commit 63c6111, merged `--no-ff` as ee6edc7, no
conflict; worktree and branch removed; nothing pushed.
- **The fix**, as the chunk wrote it (no equivalent): the s6 `run` reads
  every `host=` of `[databases]` (lists split, quotes removed, sockets and
  entries without `host=` skipped), `timeout 5 getent ahosts` once a
  second up to **30 s**, then starts PgBouncer either way; its lines in
  the container log, prefixed `pgbouncer-run:`.
- **Findings**: (1) in a swarm a name resolves only once its container is
  *healthy*, so the bound covers the database node's time to healthy
  (5 s at deploy, 7–8 s scaled back up, in the stack test); a `db`
  slower than 30 s in a heavy deploy starts PgBouncer early as 0.1.0 did
  — the main risk for 17a's runs, visible as `still not resolving after
  30s` in the pooler's log. (2) The 25-minute stuck lookup did not
  reproduce in the stack fixture (0.1.0 logged one `DNS lookup failed`
  and recovered ~10 s after `db`); the new cases prove the mechanism (no
  lookup until the name resolves), 17a's `pooler workarounds: 0` the fix.
- **Known limits** in `docs/gm.md`: `db` replaced while PgBouncer runs
  (served again 603 s after `db` healthy, the swarm DNS's 600 s answer
  lifetime) and a `db` slower than 30 s; cure `/command/s6-svc -r
  /run/service/pgbouncer` as root.
- Stack test 120 PASS, 0 FAIL, two full runs (new cases: pooler before
  `db`, query 10 s after `db` back, no `DNS lookup failed`; ghost host:
  PgBouncer at the bound, healthy at 36 s, console and `appdb` answering).
  Image `pgbouncer:0.1.1` sha256:137b342a… (local). Unit suite 848 OK;
  every scenario and fixture loads; no 0.1.0 pin left; four READMEs
  regenerated. Footprint 11.2 MiB, 0.04 % CPU at rest.
- Left: `.tech`'s two `pgbouncer 0.1.0` → `security-advisor` (dispatched
  now). Hosts clean after (lock free, 0 services).

**Next**: 17a resumed by a fresh `coding-leader` from WIP bf5dbf5, its
branch merging `v0.4-w4` (ee6edc7+) in first; the runs overnight in the
owner's order (cycles, baseline, f10, two-host last).

### `.tech` for `pgbouncer` 0.1.1 (security-advisor, 0b9e906), 2026-11-02

Post-change check: **clear**. 0.1.0 and 0.1.1 images carry the same 133
packages (PgBouncer 1.26.1-1.pgdg13+1, libcares2 1.34.5-1+deb13u1, libpq5
18.6); no advisory on PgBouncer 1.26.1; c-ares' NVD hit CVE-2025-62408 is
fixed by Debian's backport (DSA-6084-1). `.tech`: `updated`, the brick
line and the PostgreSQL platform's `source` at 0.1.1; lint as before (6
pre-existing no-CPE warnings); `cve-watch check .` 42 ≥ medium, all
pre-existing (nginx, OpenSSH, Python, sudo), none on the pooler.

**For the owner (not blocking)**: Debian's tracker lists c-ares
CVE-2026-33630, -69184, -69186 and 11 GHSA entries open in trixie, no DSA
yet (upstream fixed in ≥ 1.34.7; three high). Neither the sweep nor
`check` sees them (c-ares is no `[[platform]]` in `.tech`). Exposure low
(PgBouncer resolves backend names through Docker's resolver on the
internal overlay only). Proposed: watch; a rebuild of the brick picks up
Debian's fix (apt unpinned, no Dockerfile change). Decision pending: add
c-ares 1.34.5 as a `[[platform]]` (CPE `cpe:2.3:a:c-ares:c-ares`), which
needs an `[[ignore]]` for the false positive CVE-2025-62408 (reason
"fixed by Debian backport 1.34.5-1+deb13u1 (DSA-6084-1)", review
2027-02-01), an owner approval.

### Owner ruling: 17a's runs closed without the two-host run, 2026-11-03 ~07:30 UTC

Overnight (UTC, armenelos, all under the lock): cycles 1 19:58–01:45
failed (f2/f3 never present, f3 present after f2's fix, f7 too soon; then
the 02:45 guard); baseline 01:48–02:19 **32/32**, pooler workarounds 0;
f10 02:19–02:25 **23/23**, workarounds 0, the VPS drained; cycles 2 from
02:26, 54 PASS 0 FAIL by 03:42 (f6, f9, f1, f2, f3, f5, f7, f8 cycled),
then idle waiting for scenario midnight (09:01Z) for f4's last steps.

The owner: "abort and consider it done for this cycle of test, we can't
proceed to the two host run, as the laptop will be regularly
disconnected from the network today". So: cycles 2 aborted at the f4
wait, counted as 17a's cycles run; f4's after-midnight reading not
observed; **17a's two-host run not run**. Relayed to 17a's owner: clean
teardown, finish the checks, one commit, merge into `v0.4-w4`.
`spec-writer` records the ruling and revises chunk 17's text.

### D310, O161, plan v13 (783eca7), 2026-11-03

`spec-writer`: **D310** (17a done: cycles aborted at f4's midnight wait,
54/0; no two-host run; unproven: f4's after-midnight steps, every fault
at once on two hosts; still release gate items 8 and 9, master spec 18
items 1–2, unchanged). **O161** (open): the owner, ~07:45 UTC, "we may do
the 2 host testing later tonight (report it maybe to the end of v0.6
prior tagging v1.0" — the remaining two-host runs (17b's rehearsal, the
wave gate's two-host `smoke-load.sh`, release gate items 8 and 12,
17a's skipped smoke run) tonight, or moved to the end of v0.6; proposal:
tonight if possible, else the owner rules the move and the release gate
names what is unproven. Chunk 17's text revised (Depends on, 17a's
scope, Done when, Verification). Questions raised with O161: whether the
release gate repeats items 8 and 9, and what the wave gate's "chunk 17's
runs" covers now.

Driver's plan, told to the owner: today the wave gate's armenelos-only
parts; tonight, if connected, 17b, the wave gate's two-host run and the
two-host smoke; otherwise the owner rules O161.

### Chunk 17a — merged (edc3457), 2026-11-03 ~07:40 UTC

`coding-leader` (third owner): one commit 398f09b (13 files: `gmctl.md`,
the answer-key template, `tools/gm/{__init__,aging,checks,inject,localimpl,render,restart}.py`,
`tools/tests/smoke-purposes.{sh,py}`, `test_aging.py`, `test_render.py`),
merged `--no-ff` as edc3457; worktree and branch removed; nothing pushed.

| Run (armenelos, 4 CPU, 5G, 10G) | UTC | Result | Workarounds | `pgbouncer-run:` |
|---|---|---|---|---|
| cycles 1 | 11-02 19:58 – 11-03 01:45 | 53 passed, 6 failed (harness timing) | 0 | resolve after 6 s |
| baseline | 01:47–02:18 (1869 s) | 32/32 | 0 | after 5 s |
| f10 | 02:19–02:25 (386 s) | 23/23 | 0 | after 6 s |
| cycles 2 | 02:25–07:26 | 54 passed, 0 failed; aborted (D310) | 0 | after 6 s |

- **Cycles 1's failures**, all the harness's choice of scenario time: T0
  20:58 local put f3's planted campaign after its 08:00–21:00 window (f3
  read fixed) and f7's close on a day not yet over; f2 shows present only
  when a segment customer unsubscribes between extractions; f8's fixed
  reading needs a late declaration that never came before the 02:45
  guard. Fixed in the harness: cycles' T0 18:00 local, crm rounds counted
  per instance, f2 may rest on an earlier present reading of the same
  planting. No product fault.
- **Cycles 2** (T0 02:26:30Z, 17:26 scenario time): f1–f9 present, f10
  error as designed; f6, f9, f1, f2, f3, f5 and f7 (`--since`) cycled to
  fixed; W4 item 9's close ok 1080 s after the previous, 0 `sqlstate=08`;
  f4 and f8 fixed in place, too soon; then the wait for 09:01Z. Not
  observed (D310): f4 after the local midnight, f8's fixed, the final
  keys/jobs/every-instance check. Stopped at 07:26 by TERM; the harness's
  trap tore down.
- **f10**: planted 02:21:11, entry at 02:23:00, present after 123 s;
  backend SIGKILLed 02:23:08, ready 02:23:09; s6-svscan, sshd, cron pids
  kept; reporting `memory.peak` 113025024 → 671092736 B, `oom_kill` 0 → 1.
- **Memory** (cycles 2, MiB of limit): db 221.8/1024, grafana 190.1/384,
  reporting 70.6/640, prometheus 61.7/384, bi 33.3/384, producer 31.7/96,
  crm 30.6/128, consumer 30.2/128, gateway 30.0/96, exporter 20.9/128,
  pooler 16.3/64, bastion 10.1/256 (cycles 1 at 21:09: grafana 270.2,
  prometheus 136.8).
- **Two-host**: not run (D310); the VPS Drain throughout; filetstudio.com
  200 at 19:56Z and 07:33Z. `.wip/g7-smoke-duo.sh` not committed (hard-coded
  worktree path, never drove an active VPS; trap stub-tested, copy in the
  driver's scratchpad `wip-17a/`); 17b writes a fresh wrapper.
- Checks: unit suite 854 OK (132 s) three times, the last on edc3457;
  `sh -n`, `py_compile`, PyYAML OK; `gmctl.md` 96 parsed, 0 failed.
- Risk: cycles mode has no clean end-to-end verdict yet (f4 across the
  midnight, f8's fixed untested live).
- Hosts at 07:33Z: clean, lock free, the VPS Drain, 9.6G free.

**Next**: the wave gate's armenelos-only parts now; 17b and the two-host
parts tonight if connected (O161).

### Owner ruling: stance check and two-host sessions to v1.0 gating, 2026-11-03 ~08:00 UTC

The owner: "ok keep the stance check for v1.0 gating (like the 2 host
session). We won't proceed to full game for testing until then. see if
you can wrap up this wave and this milestone without these". Answers
O161. Sent to `spec-writer` with the driver's reading: to v1.0 gating
the stance check-list (release gate item 13), every two-host session
(17a's skipped smoke run, item 8's two-host half, the wave gate's
two-host `smoke-load.sh`), the rehearsal (17b, item 12), and item 9's
unobserved part (f4 after the local midnight, f8's fixed, a clean cycles
verdict); 17b leaves v0.4; the release gate keeps the rest, its notes
naming what moved. The single-host wave gate goes on.

### D311, O161 closed, O162, plan v14 (d8f5f3c), 2026-11-03

`spec-writer`: **D311** writes the ruling in. The v1.0-gating list lives
in `specs/versions/README.md`, "Release gates" → "v1.0 gating" (pointer
in `specs/versions/v1.0/README.md`): the stance check-list (item 13),
every two-host session (item 8's two-host half, 17a's skipped run, the
wave 4 gate's two-host `smoke-load.sh`), the rehearsal (17b, item 12) and
its figures. 17b leaves v0.4; the bricks' footprints and the scenario's
`resources` stay as they stand (item 1 met by the stack tests' at-rest
figures; the rehearsal-tied figures move with it; 17a's memory table goes
into the notes as one-host readings). G7 now blocks nothing in v0.4 after
wave 3; G11 trimmed (no game played). Release gate: no GM session, no VPS
run; item 8 the single-host smoke run plus `fit` refusing the VPS for
`reporting`; items 12, 13 v1.0 gating. **Master spec 18** amended (a
"Moved to v1.0 gating" paragraph, item 7's clause), on the owner's ruling
as sign-off — **to confirm with the owner**. **O162** (open): item 9's
unobserved part (f4 after the midnight, f8's fixed, a clean cycles
verdict, ~9 h single-host) — `spec-writer` kept it in v0.4 (a smoke run,
not a game); proposal: move it too, named in the known limits. Driver:
chunk 17's Status set; the wave gate line corrected to the running scope
(smoke, baseline, f10 on armenelos; cycles as 17a ran it).

### Owner ruling: long-running tests to v1.0 gating, 2026-11-03 ~10:40 UTC

The owner: "long running tests should be moved to v1.0 gating. remaining
tests should be short." Closes O162 (item 9's unobserved part moves).
The wave gate's `smoke` run (started 09:19Z; f1–f7, f9 present, f10 error
as designed, 25 PASS 0 FAIL by 10:15Z, then f8's wait of up to 9000 s)
is stopped at f8's wait, f8's reading moving too; `f10` and `baseline`
(~31 min) still run. Taken as the owner's confirmation of D311's master
spec 18 amendment. Sent to `spec-writer` (decision, plan v15) and to the
gate's `coding-executor`.

Wave gate so far (armenelos, 2026-11-03, UTC from the logs' local times −1 h):
unit suite and scheduler unit tests run; `sh -n` clean; seven builds
(first try) and stack tests all pass (07:43–08:09); `smoke.sh` pass;
`smoke-monitoring.sh` 43/43 (46 s); `smoke-scenario.sh` bookshop 19/19
(21 s), fernway 18/18 (29 s), tarnbeck-outdoor-shop 26/26 (822 s);
`smoke-load.sh` armenelos 73/73 (423 s). Full figures in the gate's report.

### D312, O162 closed, O163, plan v15 (fd2124f), 2026-11-03

`spec-writer`: **D312** (long-running tests to v1.0 gating: the full
cycles run with f4 across the midnight, f8's fixed and a clean verdict;
f8's wait for its present reading in the all-at-once smoke run — in
`smoke` mode the harness waits only for present, up to 9000 s); D311's
master spec 18 amendment confirmed by it; master spec 18, plan v15
(wave gate line, release gate intro "no long-running test", items 8, 9,
17), the v1.0-gating list. **O163** (open): stopping `smoke` at f8's
wait also skipped its end-of-run checks (`jobs_ran` incl. db's crontab
entry and reporting's `pg_cron` job, `keys_running`, the full `gmctl
check`, the teardown checks) — never yet reached with every fault
planted; `baseline` covers them unfaulted except reporting's `pg_cron`
job. Option (a), checks by hand on the stopped deployment, is moot: the
harness's trap tore it down at 10:40:16Z, before the report. Left: (b) a
harness option skipping f8's wait and a ~1 h `smoke` re-run, or (c) the
gap named in the known limits. Driver's reading of release gate item 14:
the wave 4 gate's run counts, re-run only for code changed after it.

### Wave 4 gate (coding-executor, armenelos, 2026-11-03 07:35–11:19 UTC) — passed, armenelos-only

On tree cd4bbd4 (later tips only the driver's log and `spec-writer`'s
spec commits); no fix, no commit; the VPS untouched (Drain); κ = 1, each
Docker step under the lock and an inhibitor. Logs in the driver's
scratchpad `w4gate/`.

| Step | Result | UTC, duration |
|---|---|---|
| Unit suite | 854 OK | 07:35, 140 s |
| Scheduler unit tests | 72 OK | 07:40, 159 s |
| `sh -n` / `perl -c` / `py_compile` | 165 / 7 / 46 files, 0 fail | < 1 min |
| Seven builds | rc 0 first try, 0 network retries | 07:43 |
| Stack tests | bastion 90, postgres 211, pgbouncer 120, scheduler 133, prometheus 131, postgres-exporter 103, grafana 119; 0 FAIL | 07:43–08:09, 1575 s |
| `smoke.sh` | 61 PASS | 29 s |
| `smoke-monitoring.sh` | 43/43 | 46 s |
| `smoke-scenario.sh` | bookshop 19/19 (21 s), fernway 18/18 (29 s), tarnbeck-outdoor-shop 26/26 (822 s) | |
| `smoke-load.sh armenelos` | 73/73 | 423 s |
| `fixture-campaign` deployment | 84/84, G1–G4 exit 0 twice, every job ran, 17 purpose checks × 3 rounds only 0/3 | 08:33–09:19, 2743 s |
| `smoke` (new scenario, every fault) | 25 PASS 0 FAIL, stopped in f8's wait (D312) | 09:19–10:40 |
| `f10` | 23/23 | 10:43–10:51, 425 s |
| `baseline` | 32/32 | 10:51–11:18, 1664 s |

- `pooler workarounds: 0` in every run (D305); the pooler's start-up
  wait resolved `db` after 5–7 s each time.
- Images (`127.0.0.1:5000/dbagm/`): bastion:0.4.0 8ffc0bf43d36 185.6 MB;
  postgres:0.4.0 2d4f82a98130 262.3 MB; pgbouncer:0.1.1 137b342a9b34
  182.4 MB; scheduler:0.2.0 **c1ef5309474e** 170.6 MB (rebuilt: its
  s6-overlay `ADD` layers re-fetched, re-running the apt layer on current
  Debian packages; no `bricks/scheduler` commit since wave 3; old
  1ad76b563f81 untagged, kept); prometheus:0.2.0 e0bad6332958 488.2 MB;
  postgres-exporter:0.2.0 b8c644f1c94d 164.6 MB; grafana:0.2.0
  b53a718ae5c0 866.2 MB.
- `smoke`, first live run: f1–f7 and f9 present, f10 error as designed,
  every moved job ok and every `jobs.yaml` restored byte for byte; stopped
  at 10:40:03 in `await f8 present 9000`; not reached: f8, `keys_running`,
  `jobs_ran` (O163).
- `f10`: present after 154 s (backend SIGKILLed 10:48:10); recovered;
  s6-svscan/sshd/cron pids kept; reporting `oom_kill` 0 → 1, `memory.peak`
  93675520 → 671092736 B.
- Memory peaks (one-minute samples): `fixture-campaign` db 217M/1G,
  grafana 253M/384M, reporting 80M/640M, crm 50M/128M; `smoke` db 203M,
  grafana 305M, reporting 73M, prometheus 98M; `baseline` db 218M,
  grafana 240M.
- Not checked: wave 3's "0 errors, 0 `08006`" count and the pg_cron
  launcher check on `reporting` in the `fixture-campaign` run.
- No wave sync: no intent register; dependencies changed only by chunk
  21 (`security-advisor` done, 0b9e906).
- Hosts at 11:19Z: clean, lock free, the VPS Drain, 9.6G free.

### Release gate (coding-executor, armenelos, 2026-11-03) — passed, G11 and O163 for the owner

On `v0.4-w4`; no non-spec change since the wave 4 gate's tree (cd4bbd4),
so nothing re-run. Two commits: **5120e36** (`postgres` 0.4.0's
`docs/gm.md`: the `pg_cron` and cron-daemon sections moved to level-2
after Known limits, `player.md` likewise, text unchanged; unit suite 854
OK after; the image unaffected) and **814ae8a** (release notes in
`specs/versions/v0.4/README.md`, "## Release notes").
- Items 1–7, 15: pass (bricks 7 checked 0 missing; 29 faults, 4 purposes,
  1 domain, 4 scenarios complete; shop 92 columns + 7 view columns
  classed; the ten faults complete; the scenario's README checked against
  its sources, 619 values 0 missing; starter-pack page sections `readme
  story issues data-policy web-interfaces` from the bastion image's own
  code; bookshop without a web-interfaces section; every `applies_to`
  current; the nine "Left for the build" rows recorded, five by pointer
  to their captures).
- Item 8's `fit`: the VPS refused for `reporting` (f10 needs an unshared
  host, master spec 13.3) before any engine is contacted; the designed
  mapping fits (armenelos: reporting; VPS: bi, gateway); the VPS never
  contacted. Note: at the declared 12G the hand-over snapshot doesn't fit
  (15.74G), on armenelos' real 41G it does.
- Wave 3's readings: the `pg_cron` launcher on `reporting` ran in the
  gate's `fixture-campaign` run (step5.log:103); every job run `ok`; the
  `08006` count never taken — named in the notes.
- Notes' known limits: master spec 18.7's four, D311/D312's moves, O163
  as option (c) **provisionally** (an HTML comment marks it), the `08006`
  count, D252, D258; known issues: c-ares pending, `pgbouncer` 0.1.1's
  limits, the scheduler image rebuilt at the gate; grafana's 305M peak in
  `smoke` above its 272M reservation (within 384M).
- Items 9–14 as the wave log records; 12, 13 v1.0 gating; **16 (G11)
  the owner's**.
- Hosts: clean, lock free, the VPS Drain (never active).

### Owner: "option c, G11 ok, merge", 2026-11-03

O163 answered (c): the `smoke` run's end-of-run checks stay a known limit,
covered by the v1.0-gating smoke run (`spec-writer` records it and drops
the notes' provisional mark). **G11 cleared.** The owner asks for the
merge: `spec-writer` closes O163 and archives the milestone
(`milestone-archive`) on `v0.4-w4`, then the driver merges `v0.4-w4`
`--no-ff` into `main` (no push) and removes the wave worktree and
branch. `doc-ids compare main v0.4-w4`: 0 collisions.
