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
