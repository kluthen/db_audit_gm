# db_audit_gm v0.4 — Wave log

Execution record of [build-plan.md](build-plan.md). No intent or data
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
