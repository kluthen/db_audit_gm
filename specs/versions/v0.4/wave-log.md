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
