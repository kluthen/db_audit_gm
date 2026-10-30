# Open questions

Every unresolved decision, with a stable ID. A question leaves this list
only when it is resolved and logged in [decisions.md](decisions.md); IDs
are never reused. Questions resolved by the close of v0.1 (O1, O3, O4,
O6–O9, O14, O15, O17–O19, O26–O28, O33–O37, O39–O44 and O55) are listed
in [archive/v0.1/open-questions-resolved.md](archive/v0.1/open-questions-resolved.md);
their IDs keep their meaning. Questions resolved by the close of v0.2
(O13, O50, O51 and O56–O77) are listed in
[archive/v0.2/open-questions-resolved.md](archive/v0.2/open-questions-resolved.md).
Questions resolved by the close of v0.3 (O45, O46, O78 and O81–O103) are
listed in
[archive/v0.3/open-questions-resolved.md](archive/v0.3/open-questions-resolved.md).
Numbering continues from O134.

Resolved during v0.4's drafting: O106 (D194), O110 (D195), O107 (D197), O120
(D198), O109 (D199), O121 (D200), O123 (D202), O105 (D203), O129 (D206), O131 (D207).

Priority: **next** = shapes everything else, ask first; **soon** = needed
for the next version (v0.1 until it closed, with none left open);
**later** = can wait for v1.0 or beyond.

## Project and scope

- **O2** (later) — Scripts versus agent judgment beyond v0.1. What the GM
  must be told and what it fills in is settled (D16); v0.1's split is
  settled (D33). Still open for generated scenarios: which further steps
  (fault choice, story, solvability probe) become scripts. Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).
- **O5** (later) — ATD was removed. Is any lighter record of intent wanted
  beyond `specs/` and the bricks' GM-facing documentation, or is that
  enough?
- **O16** (later) — Confirm the vocabulary table. Refs:
  [concept.md](concept.md).

## Platform

- **O10** (later, research) — Mostly answered in
  [platform.md](platform.md). Still unverified: numeric-only uid/gid in
  config mounts, SSH
  Docker contexts into Windows or macOS machines. To test when v0.1 is
  built.
- **O11** (later) — Which technology fills each v1.0 role beyond v0.2's
  monitoring (settled: D69) and v0.3's producers and consumers (the
  scheduler brick sending SQL to PostgreSQL, D115, D118; other targets
  from v0.5). Narrowed for v0.4 by D190 and D202: transformation is
  Python transformer scripts run by the extended scheduler brick (D203),
  over several PostgreSQL instances, `postgres_fdw` one method among
  others; another engine only if a purpose needs one, which none does
  (D194). Still open: which engine versions first, and how
  upgrade scenarios (both binaries, disk space) fit the budget. Refs:
  [versions/v1.0/README.md](versions/v1.0/README.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O12** (later) — Are network-level faults (segmentation, routing-mesh
  exposure) in scope? And the network layout itself (management network,
  zones, dual-homed nodes). v0.2 has one network and no network faults
  (D83). Refs: [platform.md](platform.md).

## Faults and aging

- **O20** (later) — Confirm the reading of D28: no project-wide mandatory
  machine check (no common brick lint, no schema check in the format skill),
  only the checks each brick ships. And confirm the solvability probe as a
  gate for generated scenarios, run after aging and before hand-over. As
  built in v0.1, the scripts already check every scenario, and the bricks
  and faults it uses, against the templates when they load it
  (`tools/gm/model.py`), a project-wide check the reading did not foresee,
  while the format skill says there is no schema-check script. Refs:
  [bricks-and-faults.md](bricks-and-faults.md), [formats.md](formats.md)
  "Enforcement".
- **O21** (later) — Can the starter documentation contain deliberate
  inaccuracies as faults, decided per scenario?
- **O22** (later, beyond v0.3) — Aging technique. v0.3 ages in real time
  only, with no sped-up clock, no forged history and no time compression
  (D114, D132), on always-on hosts (D125). Still open: which version
  copies aged volumes to a class's hosts (D125), and whether a later
  version brings back forged history, a sped-up clock or time
  compression (generated scenarios, restarts). With the eight-hour floor
  (D150), a classroom swarm staying up for a school day may become
  enough for short-aging scenarios, which may change how much the
  volume copy is needed; noted, not reopened (D125 stands).
  Not moot: v0.4's purposes (D190) run daily, weekly or monthly jobs,
  which real time alone barely exercises; v0.4's part is settled by
  D199 (realistic cadences, none weekly or monthly).
  Refs: [scenario-lifecycle.md](scenario-lifecycle.md),
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v0.4/README.md](versions/v0.4/README.md).
- **O23** (later) — Difficulty is a fault count, each fault worth 1 (easy
  5, normal 10, hard 20; D120), read for v0.3 as the number of fault
  instances, the levels being targets (D134). Still open:
  how many faults issues cover, the mix of families, and may an issue be
  a false alarm (a complaint with no fault behind it)? Refs:
  [bricks-and-faults.md](bricks-and-faults.md).
- **O24** (later) — Seed variation (names, values) per deployment of a
  scenario? Probably moot after D8; kept until the owner says so.
- **O25** (later) — Scenario-only bricks and faults may live in the
  scenario's folder (D24). Can they be promoted into the catalog, and
  through which review? From v0.4 the question is mostly about purposes
  (D190): a purpose built for one scenario, its jobs, invariants and
  faults, promoted into the catalog, rather than a transformer brick.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).

## Game and feedback

- **O29** (later) — Brief format: free text in the GM session, or a
  structured file (YAML?) with the optional items of D16 (topology sketch,
  story, data schema, required incidents, freedom given to the GM,
  difficulty, length)? Refs: [formats.md](formats.md)
  (`brief.md`).
- **O30** (later) — How long may design, deployment and probes take
  before a class? Aging alone takes at least eight hours, as long as the
  scenario declares (D114, D150), so it starts that long before the class
  at the latest; playgrounds that cannot stay up that long wait for a
  later version (D125).
- **O31** (later) — Are player actions on nodes recorded (shell history,
  audit trail) to help the GM's feedback?
- **O32** (later) — Language of player-facing material (story, starter
  documentation, issues, feedback).
- **O38** (later) — Is the feedback written to a file (the teacher is out
  of the game by then)? A scoring system is post-v1.0, unless research
  finds one quick to implement (D120). Refs:
  [scenario-lifecycle.md](scenario-lifecycle.md).

## v0.4: purposes

Raised when the owner recast v0.4 as "bricks of why and bits of hows"
on 2026-10-28 (D190). O11, O22, O25 and O52 are revised by it. Worked
into drafts on 2026-10-30 ([versions/v0.4/](versions/v0.4/README.md#documents)):
O106 closed (D194), O110 closed (D195), O122 to O125 raised; the
owner's rulings closed O107 (D197) and O109 (D199) the same day, and his
technology direction O123 (D202) and O105 (D203), raising O129, which
his ruling on jobs on a database node closed (D206), raising O131,
which he confirmed as written (D207). A
"Proposed" answer below is in a draft, tagged `(proposed)`, and awaits
the owner. On 2026-10-30 the owner declared v0.4 ready and every
proposal was carried as written into the
[master spec](versions/v0.4/master-spec.md#owner-review), which he
reviews in context: each question below names its tag in the spec's
"Owner review" list and closes when he approves the spec, or as he
rules on it there. O132 and O133 were raised by the consolidation.

- **O104** (soon, v0.4) — The purpose format. **In the master spec as proposed, owner review A1, A9, A11.** Proposed in
  [purposes.md](versions/v0.4/purposes.md): the name stays "purpose";
  `purposes/<id>/` with `purpose.yaml` (identity, parts, jobs, trace,
  invariants with witness conditions, data moved, roles), `material/`,
  `checks/`, `gm.md`; copied into a scenario at design time and named in
  `scenario.yaml`'s `purposes:`, so it never bumps; faults attach by
  `applies_to.purposes`; a check judging runs is `sealed_check.judges:
  runs` (or `triggers`); a job names its movement method, and a
  transformer script's contract is proposed with it
  (`scripts/<file>:<function>`, a job's `connections:`, the runner
  holding the passwords; D203). Then the `scenario-format` skill and the
  scenario document. How a check learns when a fix happened is now O124.
- **O108** (soon, v0.4) — The shared business data model **In the master spec as proposed, owner review A2, B2, B8.**, the shop
  domain (D192). Proposed in
  [shop-domain.md](versions/v0.4/shop-domain.md): from tarnbeck's,
  adding `business_settings` (the customer's zone, sending hours),
  customers' address, country and zone, `consent_events` beside the
  opt-in flag, `packed_at`, `shipped_at`, `ship_country`,
  `export_countries`, an archived history behind `last_order_at`, the
  purposes' tables, six roles, and consent streams in the producer.
  Tarnbeck stays untouched; the v0.4 scenario is new. Format: O111.
- **O122** (soon, v0.4) — The customer's time zone **In the master spec as proposed, owner review A8.** in the data and the
  jobs. It is UTC plus the game's shift (D129), known only at render,
  and UTC itself at a shift of 0, while purposes reason in local days and
  recipients' hours. Proposed in
  [purposes.md](versions/v0.4/purposes.md): `render` substitutes
  `{{customer_timezone}}` in scheduler seed files; `load-data` passes the
  zone and offset to `psql` as variables, written into
  `business_settings`; databases stay in UTC; recipients' zones are
  stored relative to the customer's, and a wrong-zone fault is an offset
  from the customer's, never "UTC", so no fault vanishes at a shift of 0.
  Alternative: `ALTER DATABASE … SET timezone` to the customer's zone,
  which changes every session's `current_date` and the logs' reading.
- **O124** (soon, v0.4) — The moment a purpose check judges from. **In the master spec as proposed, owner review A9.**
  Proposed in [checks.md](versions/v0.4/checks.md): `CHECK_SINCE`, the
  hand-over by default, raised to the runner's last successful reload,
  raised by the GM with `gmctl check --since` from the players' report;
  the check judges the job's runs since (none: 3 with the time to the
  next run; one violating: 1; all clean with a witness: 0), or, for a
  pushed obligation, the triggers since. Rejected: a dry run of the job
  (D131).
- **O125** (soon, v0.4) — Monitoring a second database instance **In the master spec as proposed, owner review A10.**, and
  any further one a scenario has (D202): a `postgres-exporter` node per
  instance (about 42 MB reserved each), the exporter brick made
  multi-target (a bump), or the instance left unscraped by design, which
  is then a fault the players may find. Proposed: unscraped in the first
  scenario, an exporter node per instance in the scenario format's
  guidance; no exporter change in v0.4.
- **O132** (soon, v0.4) — A report-only database node. The first
  scenario makes `reporting`, the agency's instance, report-only, but
  `postgres` is fixable only (v0.3 deferred report-only for it).
  Proposed in the [master spec](versions/v0.4/master-spec.md#72-postgres-040)
  (owner review B1): `postgres` 0.4.0 gains the report-only write policy,
  enforced on its configuration, its reload and restart wrappers and its
  crontab, the database's contents on the trust line against the
  superuser `dba` (the `ALTER SYSTEM` gap v0.3 accepted, now arising).
  Alternative: `reporting` fixable, its faults' resolutions *report* or
  *propose* by the story alone.
- **O133** (soon, v0.4) — Which catalogue faults v0.4 builds. The
  drafts list about thirty-five candidates; the scenario uses ten.
  Proposed in the [master spec](versions/v0.4/master-spec.md#162-the-new-catalogue-faults)
  (owner review B14): build the scenario's ten, each through the release
  gate's full cycle; record the others for later versions (master spec
  22). Alternative: build a few more cheap ones now (v0.3 built eight
  for a scenario using six or seven), each adding a smoke cycle.

## v0.4: data governance

Raised when the owner added a first cut of data governance to v0.4 on
2026-10-28 (D191): data classes, their rules, a policy handed to the
players, `gm_check` definition checks. The customer's governance, in the
game's world, not the game's access model. Drafted on 2026-10-30 in
[governance.md](versions/v0.4/governance.md), tested against the
clinic's classes (D196); O120 closed by D198 (an instance of its own).

- **O115** (soon, v0.4) — The governance format. **In the master spec as proposed, owner review A4.** Proposed: classes
  `personal`, `customer-linked`, `internal`; the domain's
  `classification.yaml` classes every column, the scenario's
  `governance:` states locations (`node/database`), readers and outbound
  flows with their allowed fields, and the policy file; the loader checks
  names and references; governance faults join the Security family.
- **O116** (soon, v0.4) — Which rules are checked. **In the master spec as proposed, owner review A5, B3, B4, B5.** Proposed: G1
  locations (catalog by classified name, plus a content probe for
  personal data in disallowed databases), G2 readers
  (`has_column_privilege` through membership and `PUBLIC`), G3 reach
  across instances (foreign tables, user mappings' remote roles,
  `SECURITY DEFINER` owners, and transformer jobs' source roles, D202),
  G4 outbound fields
  (judged as a purpose); not checked: encryption at rest, retention;
  the game's own roles (`dba`, `postgres`, `gm_check`, `monitoring`,
  `pgbouncer_lookup`) outside every rule.
- **O117** (soon, v0.4) — How the policy is presented. **In the master spec as proposed, owner review A6.** Proposed:
  `player/data-policy.md` in the story's voice, written by the GM from
  `governance:`; it may state unchecked rules, unmarked, as a real
  policy does; it is correct in v0.4, a wrong policy waiting for O21.
- **O118** (later, v0.4 → v0.5; **defaulted**) — Brick changes for
  governance. Default, told to the owner on 2026-10-30 and holding
  unless he objects, not a ruling: none in v0.4 (pgaudit and TLS with
  v0.5's regulated domains), and the one settings rule that needs no
  brick change, statement logging writing personal data into the logs,
  also held for v0.5 as a candidate fault. Stays open until v0.5 rules
  on the brick changes. Refs: [governance.md](versions/v0.4/governance.md).
- **O119** (soon, v0.4) — What "fixed" means for a governance fault. **In the master spec as proposed, owner review A7.**
  Proposed: a definition (a copied column, a grant, a mapping) is fixed
  when the live state complies, removal included; content already sent
  is judged as a purpose, no new violation since the judged moment
  (O124).

## v0.5: domains

Raised when the owner set business domains for v0.5 on 2026-10-28
(D192). v0.4 ships the first, the shop (O108). The veterinary clinic
added on 2026-10-30 (D196).

- **O111** (soon, v0.4 → v0.5) — The domain format. **In the master spec as proposed, owner review A3.** Proposed for v0.4 in
  [shop-domain.md](versions/v0.4/shop-domain.md): `domains/shop/` with
  `domain.yaml`, `data/` (schema, load, classification), `producers/`,
  `docs/gm.md`; a design-time source copied into a scenario and named in
  `scenario.yaml` for provenance, so it never bumps; static scenarios
  need none. Left to v0.5: profiles against the schedule (O113), size
  (O114), composition (O126).
- **O112** (later, v0.5) — Which domains come first after the shop? The
  owner names a warehouse, a factory and a lab, and, on 2026-10-30, a
  veterinary clinic franchise (D196), a composite holding a lab. A
  factory's high-frequency time series presses on "schemas simple,
  tables small" and the memory budget, and invites TimescaleDB, placed
  beyond v1.0 by D47 yet listed as a `postgres` option candidate (O79). A
  lab's audit trail needs governance beyond v0.4's cut (O118). The
  clinic's machinery may want engines beyond v1.0 (D47) and its
  regulatory reports run monthly or yearly (O22). v0.2's
  `fernway-clinics-monitoring` is a veterinary clinic: its owners are
  personal data, animal health is no special category. Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains).
- **O113** (later, v0.5) — Producer profiles against v0.3's query
  repository and schedule: a template the GM instantiates into a
  scenario's `queries.yaml` and `schedule.yaml` at design time (the
  folder stays self-sufficient, D23), a library of builders, traffic
  shapes and parameter generators the scenario references, or a layer
  the scheduler reads? Richer input types (names, addresses, SKUs,
  sensor readings) than v0.3's generators? A catalogue profile is
  readable in the repository while `schedule.yaml` is hidden (D130):
  accepted on the trust line (D13)? Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains),
  [versions/v0.3/master-spec.md](versions/v0.3/master-spec.md) 7.1.
- **O114** (later, v0.5) — What a scenario's size scales: data volume,
  number of entities, intensity, or several? Intensity is absolute and
  never rescaled to the playground (D32); size has to fit the
  playground's budget and "schemas simple, tables small". Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#domains).

- **O126** (later, v0.5) — May a domain be composed of smaller
  domains? The clinic (D196) is a lab, bookings, housing, machinery, a
  portal and messaging, each close to a domain of its own; a warehouse
  or a shop could reuse some. If yes: how parts share a data model's
  keys (an animal, an owner), and whether a scenario may take a part
  alone. Linked to O111. Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-veterinary-clinic-d196).
- **O127** (later, v0.5 → beyond v1.0) — Where several sites and the
  exchange between them sit: the clinic is a franchise whose centres
  share machinery and records, with redundancy (D196). Several sites
  need more than one domain's worth of topology: several database
  instances per business, replication or exchange between them, and
  hosts enough. A v0.5 topology fragment (two sites on one playground),
  or beyond v1.0 with the multi-site playgrounds it needs? Linked to
  O12 (network layout). Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md#the-veterinary-clinic-d196).

- **O128** (later, v0.5) — How a round trip is modelled (D201): an
  acknowledgement as an inbound flow the setup waits on and reacts to.
  To settle: whether it is a purpose kind of its own or a pushed
  obligation with reactions; how correlation is stated (the key an
  acknowledgement answers); the stub receiver's repertoire (late, out
  of order, duplicated, unmatched acknowledgements, as timeline changes,
  D127); how a check judges a cascade, whose faults show downstream; and
  what of the clinic's lab results and inter-clinic exchanges it covers.
  Refs: [versions/v0.5/README.md](versions/v0.5/README.md#round-trips-acknowledgements-as-inputs-d201).

## Beyond v1.0: the cloud provider

Raised when the owner set a fictional cloud provider after v1.0
(D205). Settled there: a fictional name, the console's layout our own,
no AWS-style IAM.

- **O130** (later, after v1.0) — The provider layer's design: the type
  ladder and how a type maps onto limits, reservations and `fit`; the
  service kinds and what each denies (a managed database with no shell
  on its host, proposed, against the players' `dba` today); which
  capacity actions players get and what a resize does mid-game (a
  service update restarts the node); the console's relation to v0.6's
  bastion; the in-world name. Refs:
  [versions/README.md](versions/README.md#beyond-v10-a-fictional-cloud-provider-d205).

## Roadmap: gaps and cross-version risks

Raised with the roadmap (D47); O121, raised by the owner's ruling on
release gates (D193), was resolved for v0.4 by D200. The tag after the priority is the version
the question concerns.

- **O47** (later, v1.0) — Which version brings scenario generation: the GM
  designing from a partial or empty brief and filling the blanks (D16)?
  v0.5 prepares for it without naming it; its domains (D192) make a
  brief naming a domain and a size most of a scenario's business side.
  Refs: [versions/v1.0/README.md](versions/v1.0/README.md).
- **O48** (later, v0.3 → v1.0) — Aging enters in v0.3, in real time
  (D114). Where does the solvability probe as a gate (O20) enter the
  roadmap? With an aging of eight hours or more (D150), a probe failing at
  hand-over costs the class; v0.3's master spec has an early check during
  aging and a hand-over check. Refs:
  [archive/v0.3/aging-and-timeline.md](archive/v0.3/aging-and-timeline.md),
  [versions/v1.0/README.md](versions/v1.0/README.md).
- **O49** (soon, roadmap) — Backup tools (pgBackRest and the like) and the
  backup-tooling fault families (D17) are in no version, although backups
  were a founding example and the v0.1 goal speaks of "investigating a
  backup". Which version? Refs:
  [bricks-and-faults.md](bricks-and-faults.md), "Future ideas: backup
  tooling".
- **O52** (later, after v0.4) — dbt adds a Python toolchain and adapters
  to a node image: image size and build time, one image per adapter
  (Postgres, DuckDB), versions to pin. One transformer brick per
  technology? v0.4 plans no dbt: its jobs run on one generic job runner
  (D190, D203). Stands for whichever later version or purpose wants dbt.
  Refs: [versions/v0.4/README.md](versions/v0.4/README.md).
- **O53** (later, v0.5) — Bluebox as a dataset:
  - its schema needs PostGIS, `pg_stat_statements` (a preloaded library)
    and `pg_trgm`, so a PostgreSQL 18 brick with those extensions;
  - its dump is about 88 MB compressed and larger restored, against the
    disk budget and the time to load it at setup;
  - a file that size should not live in the repository, yet a scenario
    folder plus the repository is meant to be self-sufficient (D23);
  - its code is MIT-licensed, but part of its data comes from TMDB and
    other sources whose redistribution terms need checking;
  - its ongoing data generation relies on `pg_cron`.

  Refs: [versions/v0.5/README.md](versions/v0.5/README.md).
- **O54** (later, v0.5) — Internet-sourced datasets: availability at setup
  time, licensing, and reproducibility against the self-sufficient
  scenario folder (D23). Pin by address and checksum and cache locally?
  Refs: [versions/v0.5/README.md](versions/v0.5/README.md).
- **O79** (later, v0.5) — The brick options model (D107), `postgres`
  first. In `postgres` 0.2.0, pgBadger, file logs on the `pglog` volume,
  `pg_stat_statements`, the `monitoring` role and its
  `monitoring_password` secret are in every game, while the logging and
  preload settings are the scenario's, in its seed `postgresql.conf`.
  First candidate options: those four, then PostGIS, TimescaleDB and the
  replication modules; `pg_cron` and the cron daemon, which `postgres`
  0.4.0 ships enabled by the seed, with no `options:` key (D206). To
  settle:
  1. Where an option's software comes from, given a read-only root and no
     network at start: one image carrying every option (simple, but
     PostGIS alone adds a few hundred MB every game pays), image variants
     per option set (e.g. `postgres:0.x.0-postgis`), or a mix (light
     options in the base, heavy ones as variants). `fit` counts image
     sizes (D102), so the choice shows in capacity.
  2. How a scenario chooses: e.g. `options: [pgbadger,
     pg_stat_statements, postgis]` on the node, with `brick.yaml`
     declaring the options it offers, each with its requirements
     (preload library, volume), its footprint, and the secrets and
     volumes that exist only with it (`pglog` and `monitoring_password`
     would become per-option).
  3. What start-up does for an option (create the extension, the role,
     the directory), while its settings in `postgresql.conf` (preloads,
     logging) stay in the seed so a fault can still remove them; the
     loader checks the seed agrees with the chosen options.
  4. Faults that need an option, as `applies_to` ties a fault to a brick
     and version.
  5. Documentation: one section per option in the brick's `docs/gm.md`
     (what it adds, its cost, how to enable it, the faults it allows).

  Akin to v0.2's declare/choose/check pattern for mounted material and
  `receives` (D97). Refs: [versions/v0.5/README.md](versions/v0.5/README.md),
  [formats.md](formats.md) "Brick definition",
  [versions/v0.2/master-spec.md](versions/v0.2/master-spec.md) 7.5.
- **O80** (later, v0.5) — Is the options model (O79) meant for every
  brick, or only `postgres`? The owner's direction (D107) names
  `postgres` "in particular". Refs:
  [versions/v0.5/README.md](versions/v0.5/README.md).
