---
name: scenario-document
description: Use whenever a db_audit_gm scenario's README.md (the scenario document) has to be generated or regenerated — once scenario.yaml and gm/answer-key.yaml are complete, after any change to either, before deploying a scenario whose README is missing or stale, or when grounding a GM on a restart or a re-spawn elsewhere. Fills the template from the authoritative files; the README is never edited by hand and always opens with the "do not read" warning.
---

# Scenario document

A scenario's `README.md` is its **scenario document**: the readable whole
of the scenario, for the GM and the lead. It is **generated** from the two
authoritative files, `scenario.yaml` and `gm/answer-key.yaml`, with this
skill's [template](template.md). This is its **v0.7 version**, expected
to evolve as games are played; when a game shows the document
is missing something, change the template and this skill together, and
the [format skill](../scenario-format/SKILL.md)'s templates first if the
missing thing is not in the authoritative files yet.

Source of the shape: v0.1's master spec (`specs/versions/v0.1/master-spec.md`,
section 6, and 6.2 for the content) and v0.2's
(`specs/versions/v0.2/master-spec.md`, 6.3: evidence `where` and `source`,
tooling expectations; 7.1 and 7.6: the node-health map and the web front's
routes, rendered as "Map-valued parameters" below) and v0.3's
(`specs/versions/v0.3/master-spec.md`, 6.1 and 6.2: the aging, the
difficulty, a fault instance's planting moment and aging minimum, a
node's write overrides, a behavioural check's window and threshold; see
"The v0.3 items" below) and v0.4's (`specs/versions/v0.4/master-spec.md`,
6.1, 6.2, 7.2, 11.5 and 14: the purposes a scenario uses, its domain, its
governance and policy file, its database-node jobs, a check judging runs
or triggers; see "The v0.4 items" below) and v0.5's
(`specs/versions/v0.5/master-spec.md`, 10.3 and 15, with capture W5
item 5 of `specs/versions/v0.5/wave-log.md`: the "Third parties",
"Composition" and "Data register" sections, a `pg_cron` job a purpose's
`ddl:` schedules, a false alarm; see "The v0.5 items" and "The data
register (v0.5)" below) and v0.6's (`specs/versions/v0.6/master-spec.md`,
6.1, 6.2 and 8, with capture W2 item 6 of
`specs/versions/v0.6/wave-log.md`: a node's description, site and users,
the "Network overview" section and the overview beside each fault; see
"The network overview (v0.6)" below; and 7.6, 9.5 and 9.10, with capture
W3 item 12 and W4 items 7 to 9: an instance's admitted incident, the
"Fake aging" section, the starter-pack line; see "The v0.6 items" below)
and v0.7's (ISS-009, `issues/ISS-009_20261120_scenario_document_template_gaps.md`:
a node's options and standbys, a non-database node's jobs, the weekdays,
fake aging's measured figures, where the composed domains load, the
effective aging minimum, and calls earlier left unwritten; see "The v0.7
items" below). The template's sections follow the keys of the
format skill's
[scenario.yaml](../scenario-format/templates/scenario.yaml) and
[answer-key.yaml](../scenario-format/templates/answer-key.yaml) templates,
so the document is filled field by field.

## What it is for

- **Grounding.** On a session restart, or when the scenario is spawned
  again on another playground or later, the GM reads the document first
  for the whole picture, then the authoritative files for the detail.
  With the repository (for the catalog) and the GM skills, the scenario
  folder is enough to start the exercise again.
- **Review.** The lead reviews the defects, issues and answer key in one
  place.
- **Not for players.** It holds every hidden fault and every answer. It
  opens with a prominent warning that students and players should not
  read it; enforcement goes no further (scenarios live in the repository
  in bulk, which is accepted). The starter pack under `player/` does not
  carry the warning, and nothing of this document goes into it.

## When to generate or regenerate

- When the scenario is first complete: the format skill's step 6, once
  `scenario.yaml` and `gm/answer-key.yaml` pass its completeness checklist.
  An incomplete scenario gets the format skill's list of missing items,
  not a document.
- After **any** change to `scenario.yaml`, `gm/answer-key.yaml` or
  `brief.md`, in the same change.
- After a change to what the "Fake aging" section reads (v0.6): a fault
  definition's `aging.fake` or its `gm.md` "**Fake aging.**" note, for
  every scenario with an instance of it, and a new short-game record
  `tools/fake_aging/calibration/<id>-short-game-*.txt`, for its scenario;
  in the same change.
- After a change to what the v0.7 items read: a scheduler's seed
  `jobs.yaml` or its `schedule.yaml`'s shapes and keys, a non-database
  node's seed `crontab`, a fault definition's `aging.minimum` or
  `option_absent`, or a `service-times.yaml` or `wal-rate.yaml` added or
  removed; in the same change.
- Before deploying, when `README.md` is missing or does not match the
  authoritative files (its scenario version, or any value, differs).
- After this template changes, for the scenarios the GM is about to use.

## Never edit it by hand

The document is output. To change what it says, change `scenario.yaml` or
`gm/answer-key.yaml` (or `brief.md`) and regenerate. When the document and
the authoritative files disagree, the files win: regenerate, do not
reconcile by hand. A hand-written note that belongs to the GM goes to
`gm/notes.md`, which the document links to.

## Generating it

1. **Check completeness** with the format skill. Stop on any missing item.
2. **Read the inputs**: `scenario.yaml`, `gm/answer-key.yaml`, and
   `brief.md` (quoted as given). Nothing else is a source: the document
   names the other files of the folder by path, it does not copy them.
   The exceptions: a node's parameter whose value is a map is rendered by
   its `shape`, read from the pinned brick's `brick.yaml` (see
   "Map-valued parameters" below); a database node's jobs are read
   from its seed `crontab`, its seed `postgresql.conf`, its data file,
   the `data/cron.sql` of each domain `domains:` places on it and the
   `ddl:` files of each purpose mapped onto it (see "The v0.4 items" and
   "The v0.5 items" below). A scenario listing `domains:` adds its
   composition record, `composition.yaml`, and `merge.yaml` when present
   (the "Composition" section, "The v0.5 items" below), with the node
   lines `tools/gmctl compose <dir> --check` prints. The "Fake aging"
   section (v0.6) reads each fault instance's definition (`aging.fake`,
   its `gm.md` note), the rows of `tools/gm/cleanrestart.py`'s
   `EXPLAINS` with the seed `postgresql.conf` files and the data and
   domains' schema files their conditions name, and the newest short-game
   record; see "The v0.6 items" below; from v0.7 the same definitions
   give section 5's aging minimum (`aging.minimum`) and a node's option
   not chosen (`option_absent`). The fifth (v0.7): a scheduler node's
   seed `jobs.yaml` and the `shapes:` and keys of its seed
   `schedule.yaml`, and a non-database node's seed `crontab` (see "The
   v0.7 items" below). The measured figures of "Fake aging" are read
   from the folder listing alone.
3. **Copy [template.md](template.md)** to `scenarios/<id>/README.md` and
   fill it top to bottom. Each section names the keys it comes from.
   Repeat a block once per entry where its comment says so, in the order
   of the YAML. Write an empty list or map as the comment says ("None.",
   "No issues given."); never drop a section because it is empty.
4. **Keep the warning first**, as the template has it: nothing above it,
   not even the title.
5. **Clean up**: the generated file keeps no `<placeholder>` and no
   template comment (`<!-- ... -->`).
6. **Check by reading**:
   - the warning is the first thing in the file;
   - every node, flow, fault instance and issue of `scenario.yaml`
     appears, and every answer-key entry, one per fault instance, with
     each evidence entry's `where` and `source`, and every tooling
     expectation;
   - the difficulty score and level, the aging (or the line saying the
     scenario does not age), every instance's planting moment (and aging
     minimum, in a scenario that ages), every node's write overrides and
     every behavioural check's window and threshold appear as the files
     write them;
   - every entry of a map-valued parameter appears, in the order of the
     YAML and as `scenario.yaml` writes it: each `node-map` entry with
     its node and its services (or `default`), each `web-routes` route
     with its `ui:<name>`, its path, its node and its port;
   - from v0.4, when the scenario has them: the domain; every purpose
     with each of its parts as mapped; every governance class with its
     locations, separation, readers and outbound flows, and the policy
     file; every database node's crontab roles and each of its jobs
     (every crontab entry, every `pg_cron` job its data file schedules,
     and from v0.5 every one a domain's `data/cron.sql` or a purpose's
     `ddl:` schedules there); every check's `judges` and threshold;
   - from v0.7: every node's `options:` (and the option a topology
     fault leaves out, with its instance), every `standby_of:` under the
     standby and its primary's **Standbys** line, every job of a
     scheduler's `jobs.yaml` and every entry of a non-database node's
     crontab, the Weekdays row in a scenario that ages, under each node
     the domains `load-data` loads there and in section 7 the domains'
     item, every instance's effective aging minimum, and the measured
     figures, each file present or missing;
   - from v0.5, when the scenario has them: every `domains:` entry with
     its variant and `at:`, and `composition.yaml`'s keys, scale, order,
     derivations and left-out producers, every `merge.yaml` resolution;
     every `third_parties:` entry; every false alarm, its issue and its
     `false_alarms:` entry with each evidence entry; every fault
     instance's `backlog:` with its `what` and `cleanup`, under that
     instance's answer (spec D472);
   - from v0.6: every instance's `admitted:` with its partner, title,
     `from`, `until` and text; the "Fake aging" section last, in every
     document: "None: ..." for a scenario without `aging:`, otherwise one
     row per instance (support, or "not assessed"), the full selection's
     tail and anchor, or "not assessed", the setup time or "not measured",
     and the limits that hold with the instances each touches;
   - every value matches its key (versions pinned, knobs' initial values
     and envelopes, reservations, placement);
   - each file path it names exists in the folder (`local/` excepted: it
     is never named);
   - the document is not named in any node's `seed_files` and nothing
     under `player/` quotes it.

## Map-valued parameters

A node parameter whose value is a map (capture W1 item 2 of
`specs/versions/v0.2/wave-log.md`) is not written inline as YAML. Its
rendering is keyed on the parameter's `shape` in the **pinned brick's
`brick.yaml`**: the scenario's `bricks/<id>/brick.yaml` when the
scenario carries the brick, the catalog's `bricks/<id>/brick.yaml`
otherwise. That file is read for this alone, and is the one catalog file
the skill reads; a scenario-local brick's map is covered the same way.
On the node's **Parameters** line the parameter is named and pointed
below ("node_health: the node-health map, below"); its block follows the
node's bullets, before its resources (see the template).

- **`node-map`** (`prometheus`'s `node_health`): one item per entry, in
  YAML order, the node and its services, comma-separated; `default` is
  kept as written and glossed as the brick's s6 processes ("`default`
  (its brick's s6 processes)"). Then one line, in master spec 7.1's and
  the access model's wording: "The node-health script is mounted into
  every node listed, read-only for players; its endpoint is readable
  from every node of the game, the bastion included." The map is shown
  as `scenario.yaml` states it, before any parameter fault: a fault
  leaving a node or a service out is listed in section 5, never applied
  here.
- **`web-routes`** (the bastion's `web_routes`): a table, one row per
  route, in YAML order: the route as `ui:<name>` (the name the answer
  key's evidence uses), its path `/<name>/` on the web front, the
  upstream node and port (the value `"<node>:<port>"` split). Then one
  line (bastion 0.8.0, the owner's ruling of 2026-11-23, replacing
  master spec 7.6's and access model 5 and 7's basic authentication):
  "Published on the bastion's web front port, with no login of the
  front's own (bastion 0.8.0); an upstream with a login keeps it
  (Grafana's `admin`, the tools password)." An empty map (`{}` written in
  `scenario.yaml`): no table, and the line "Web front routes (`<NAME>`):
  none. The topology has no web interface: the web front serves the
  starter-pack page alone, with its Access section" (v0.4, D224). A parameter the scenario leaves out (its brick's default
  applies) is not rendered: the Parameters line says what
  `scenario.yaml` writes.

A shape not listed here is a change to this skill and its template
first; never invent its rendering.

## The v0.3 items

- **Aging**: in a scenario with scheduler nodes, its minimum and the
  hand-over time of day it was designed for, in scenario time. In one
  with none, which does not age (v0.3 master spec 8, D157), the row says
  so; there is then no aging-minimum column and every instance is
  planted at `T0`. The shift and the customer's time zone are a game's,
  computed at render: the document names neither.
- **Difficulty**: the score, with the number of fault instances beside it,
  which it equals, and the level when the file gives one.
- **Planting moment**: `plant_at` as written, `T0` when absent; the
  instance's `aging_minimum` as written, only in a scenario that ages, in
  the table's last column. From v0.7, without `aging_minimum`, the
  definition's `aging.minimum` read from its `fault.yaml` (the scenario's
  `faults/<id>/` first, then the catalog's), written "<minimum> (the
  definition's)": the minimum the loader counts, so the GM sees it
  without opening the definition.
- **Write overrides**: a bullet under the node, after its write policy,
  only for a node that has them.
- **Behavioural check**: its window and threshold under the sealed check,
  as the answer key writes them.
- **Evidence locations**: the answer key's `where` as written (`bastion`,
  `node:<name>`, `ui:<name>`, `report:<tool>`). The readings a fault
  definition cannot carry (a web interface, another node) are the answer
  key's, so the document shows them all.

## The v0.4 items

Each is an "if:" block of the template: a scenario without the key gets
the v0.3 document, unchanged.

- **Domain**: a row of section 1, the domain's id, for provenance.
- **Purposes**: a subsection of section 3 after the flows, one block per
  purpose: its id, its catalog folder, and a row per part with the node
  or the `<node>/<database>` location `scenario.yaml` maps it to. The
  purpose's definition is not read: its jobs are listed under the runner
  (a scheduler's `jobs.yaml`, a database node's crontab and `pg_cron`
  jobs), and the faults attached to it are in section 5.
- **Governance and the policy file**: a subsection of section 3, the
  policy file and the classification named by path, a row per class as
  `governance.classes` writes it, `internal` added as "any (the default)"
  when the file leaves it out; section 7 names the policy among the
  starter pack and the classification among the data. The policy's text
  is not copied.
- **Database-node jobs**: under a database node that seeds `crontab` or
  whose seed `postgresql.conf` preloads `pg_cron`, its crontab roles and
  a table of its jobs: each crontab entry (its job name from its log file
  `/var/log/postgresql/cron/<job>.log`, its schedule in scenario time as
  written, the role it connects as, its database, what it runs) and each
  `pg_cron` job its data file schedules with `cron.schedule_in_database`
  (name, schedule, `username`, database, command), with `pg_cron`'s
  metadata database and `cron.timezone` as the seed writes them. From
  v0.5, a composed domain's jobs too: every entry of `domains:` whose
  `at:` places it on the node (a domain shipping a `data/cron.sql` sits
  on one node, spec D405) adds the `cron.schedule_in_database` calls of
  the catalog's `domains/<id>/data/cron.sql`, after the data file's, in
  `domains:` order; `load-data` schedules them after the domain's load,
  as `postgres` in the node's `cron.database_name`. Their database is as
  the file writes it: the file is read from the catalogue, never copied
  or renamed, and the loader requires the entry's `at:` to place it on
  the node (v0.5 capture W4 item 2). The jobs line names the domain's
  `data/cron.sql` and says "(its data file schedules none)" when the data
  file schedules none. This is the one place those files are read, for
  this alone: a job no runner lists is often a finding, so the GM must
  see them here.
- **A check judging runs or triggers**: under the sealed check, what it
  judges (`runs` or `triggers`) since the judged moment and its threshold,
  as the answer key writes them.

## The v0.5 items

Each is an "if:" block of the template: a scenario without the key gets
the v0.4 document, unchanged.

- **Composition** (`domains:`; master spec 8.4, 8.5, 15; capture W5
  item 5): section 1's "Domains" row, and a subsection of section 3 after
  the flows. It reads `scenario.yaml`'s `domains:`, `composition.yaml`
  and `merge.yaml` (when present), lists the scenario layer's folders
  `compose/<node>/` by path and the nodes `gmctl compose` writes, from
  the node lines of `tools/gmctl compose <dir> --check` (design time, no
  playground, nothing written; it must read `up to date`, else the
  composition is a design step left undone): a row per domain (variant, `at:`,
  `lands_with`, the `keys` it relies on), the load `order`, the
  `derive` steps, the `scale` as checked, the `left_out` producers (a
  fixture's) and each `merge.yaml` resolution (node, file, entry, the
  source taken or "a value written", the reason). Its last line says
  the coherence check runs at every setup and where its result is
  recorded; **the result itself is never rendered**: `coherence:` is
  setup state, rewritten by `load-data`, and the document, like the
  register's digest (spec D465), leaves it out, so a setup never makes
  the document stale. The domains' own files and the merged nodes'
  files are named by path, never copied.
- **Third parties** (`third_parties:`; master spec 10.3): a subsection of
  section 3 after the purposes, a row per entry as `scenario.yaml`
  writes it (id, name, what it stands for, role, nodes, hostname, its
  `player_doc`, the customer's credentials with it by name), then the
  GM-side facts: played by no one, its support contact never answering
  during the game, its nodes `no-access` and named to no player; the
  partners' hidden schedule by path (`partners-backend`'s
  `schedule.yaml`); the fault instances whose node is one of its nodes.
  The partners' page itself (`player/partners.md`) is named, not copied.
- **A `pg_cron` job a purpose's `ddl:` schedules** (spec D456; purpose
  6's `lab-critical-calls`): `load-data` runs each `purposes:` entry's
  `ddl:` files (step (2b)) in the database its part is mapped to, so a
  `cron.schedule_in_database` call in one is a job on that part's node,
  listed in the node's jobs table like a domain's `data/cron.sql` job,
  after them, in `purposes:` order: its name, schedule and `username` as
  the call writes them, its database the part's mapped database when
  the call writes `current_database()`. The jobs line names the purpose
  and the file (`purposes/<id>/<ddl path>`, step (2b)). The file is read
  from the catalogue for this alone.
- **A false alarm** (an issue whose `covers` is `[]`, its
  `false_alarms:` entry in the answer key; spec D459): in section 5 the
  issue's "Covers" line says it covers nothing and points to section 6;
  in section 6 a "False alarms" subsection after the tooling
  expectations, one block per entry: the issue, `why`, the evidence
  table (`where`, `source`, `how`, `shows`, as an instance's) and
  `acceptable`. A false alarm is no fault instance: it has no row in
  "Fault instances" and counts in no difficulty score.

## The v0.7 items

ISS-009's fixes. Each is an "if:" block but for the aging-minimum value,
the T0 line, the placement totals and the starter pack's joining, which
every document with them has.

- **Options and standbys**: under a node, after its write overrides,
  "**Options**" when it has `options:` (each on, every other option its
  brick declares off), or when a topology fault (`option_absent`) is on
  it, which adds the option not chosen and the instance: a missing
  option is that fault's only trace in the topology. After its seed
  files, "**Standby of**" on a standby (no data of its own: cloned after
  the load) and "**Standbys**" on its primary.
- **A non-database node's jobs** (the fifth exception): a jobs table
  under any node seeding `jobs.yaml` (a scheduler) or, not being a
  database node, a `crontab` (the health check): Kind `jobs.yaml` or
  `crontab`; a `jobs.yaml` job's name, `at` as written (with its
  `timezone_offset`), connection and key; a crontab entry's command, its
  OS user. A fault naming a job by name (the shop's `close-day`) finds it
  here. The streams of `schedule.yaml` stay summarised by the flows.
- **Weekdays** (section 1, a scenario that ages): derived from the
  schedulers' `schedule.yaml` shapes, no format key: the shapes writing
  `days:`, each with its day groups, and the day to age on; or "the same
  every day". The GM chooses the aging's start from it
  ([game-master-setup](../game-master-setup/SKILL.md), "Real aging").
- **Measured figures** (under "Fake aging"): each
  `nodes/<node>/service-times.yaml` a scheduler with keys needs and each
  `nodes/<node>/wal-rate.yaml` a primary needs, present or missing with
  the command that refuses, from the folder listing alone; section 7
  names the files present as **Fake aging figures**, GM side and never
  mapped.
- **Where the composed domains load**: under each node `domains:`
  places one on, "The domain(s) loaded here by `load-data`, after the
  data file: ..." with each domain's database, or "Data: no data file;
  the domain(s) loaded here ..." on a node without data; the jobs line
  says "(its data file schedules none)" or "it has no data file" by the
  same test; section 7's restored-backup data ends with the domains'
  item, and reads "none." only with neither a data file nor a domain.
- **Column classification for `domains:`**: the scenario's copy of the
  composed domains' classification files, one per domain, each key
  prefixed with its table's database.
- **Unwritten cases, now rules**: a crontab entry naming no database,
  "all (<what the command covers>)"; `cron.timezone` absent from the
  seed, "cron.timezone not set (pg_cron's default, GMT)"; an empty
  `pg_cron` table, its one "nothing scheduled in the baseline" row; a
  `cron.schedule` job as `postgres` in `cron.database_name`; one bold
  total row per host after the node rows, in `designed_for.hosts` order,
  each sum in the largest unit giving a whole number or one decimal
  place; scenario-only bricks before faults, each in folder-name order;
  the starter pack's items joined with ", ", the last with ", and ";
  T0 "right after the data load, before the workload starts" in a
  scenario that ages; section 1's Domain row naming the domain's
  `docs/gm.md`, "and producer" only when the domain has `producers/`.

## The data register (v0.5)

An "if:" block of the template, after "Data governance", for a scenario
with a data register (`governance.register`; master spec 13.3; capture W4
item 1). The [data-register](../data-register/SKILL.md) skill generates
the register first (Setup step 2: the format check, the register, then
this document), so this document reads its outputs, never the other way
round:

- the handout's path and whether it is handed over (mapped on the
  bastion as `data-register.md`) or declared absent by a register fault;
  the true register's path, `gm/data-register.yaml`;
- its header (controller, contact), its counts (entries, internal lines,
  locations of the index) and its departments, each with its entry ids;
- **one table per register fault instance**, its `register_diff:` as the
  answer key writes it: entry, field, true value, value handed out, or
  "the register left out" for `{absent: true}`.

The register's entries are not copied: the GM reads
`gm/data-register.yaml` itself on a restart. A scenario without
`governance.register` keeps the v0.4 document.

## The network overview (v0.6)

A node's `description:`, `site:` and `users:` (v0.6 master spec 6.1) are
lines of its subsection, each an "if:" block. A scenario with a network
overview (`gm/network-overview.yaml`, master spec 8.4; every scenario
listing `domains:`, a fixture exempt) gets an "if:" block after "Data
register", on its model. The
[network-overview](../network-overview/SKILL.md) skill generates the
overview after the register and before this document (Setup step 2: the
format check, the register, the overview, the document), so this document
reads its outputs, never the other way round:

- the handout's path and its mapping (the bastion's `network-overview.md`),
  the true overview's path, the header's customer;
- its counts: the entries per group (database servers, applications and
  APIs, integration and back-office engines, monitoring) and the
  third-party rows;
- **one table per overview fault instance**, its `overview_diff:` as the
  answer key writes it: node, field, true value, value handed out,
  `absent` for an entry missing or invented.

**Beside each fault** (master spec 8.2; W2 item 6): in section 6, each
answer-key instance on a customer node gains one line, "The overview
beside it", quoting that node's handout lines whose source its definition's
`seed_changes` touch: `postgresql.conf`, the **Applications** and
**Backups** lines; a crontab, `jobs.yaml` or `cron.sql`, the **Background
tasks** lines; `schedule.yaml` or `api.yaml`, the **Fed and used by** and
**Uses** lines; otherwise (a state, parameter or topology fault, or a
seed change of another file), a link to the node's entry. These are the
lines that can hide or help a system fault: the GM reviews that the page
shows the system as designed. An instance on the bastion (a register or
an overview fault) gets no such line.

The entries are not copied: the GM reads `gm/network-overview.yaml` itself
on a restart. A scenario without an overview has no such section and no
such lines.

**A true overview with no entry** (a fixture whose topology is the
bastion alone, v0.6 chunk 14's: the loader refuses an entry for a node
outside the topology): the subsection says the true overview describes no
node of the scenario's topology, gives its third-party rows, and makes no
claim that the handout renders it; the "No overview fault" line drops
"the handout is the true overview rendered as is". Where the handout came
from is no fact of the authoritative files, so the document says nothing
of it.

## The v0.6 items

- **An instance's admitted incident** (`admitted:`, master spec 7.6; spec
  D537; capture W4 item 8): in section 5, after the plantings' line, only
  when an instance has one: "Admitted by a partner on its status page:", a
  table (instance, partner, title, `from`, `until` as written, "—" when
  absent), then each one's text quoted, in the order of
  `fault_instances`. So the GM knows what a status page will say and when
  without reading `scenario.yaml`. An instance left out of a game's
  selection, or refused in a fake game, admits nothing: that is the game's,
  not the document's.
- **The starter-pack line** (capture W4 item 9): the true register,
  `gm/data-register.yaml`, is named beside the data register only, when
  the bastion maps `data-register.md`.
- **"Fake aging"** (master spec 9.5, 9.6, 9.10; spec D544; captures W3
  item 12 and W4 item 7): an unnumbered `## Fake aging` after section 7,
  **in every document**: the GM skill treats a document without it as
  stale for a fake game. For a scenario without `aging:` it is one line,
  "None: the scenario does not age, so it has no fake game." Otherwise:
  - the virtual span: `aging.minimum`, the virtual T0 at the designed
    hand-over minus it, scenario time;
  - a row per instance from its definition's `aging.fake`: support, or
    **not assessed** without `aging.fake`; its tail needs
    (`tail_minimum`, `tail_covers`); `plant_in`; its reason as written;
    whether its `gm.md` has a "**Fake aging.**" note (the note itself is
    not copied);
  - the full selection at the designed hand-over, by master spec 9.6 as
    `render.fake_timeline` computes it: the tail, the anchor, the
    instances refused (`real-only`) with their reasons; with any instance
    not assessed, "not assessed: no fake game of this scenario until every
    instance is" instead. Compute it with the function itself (a planned
    hand-over on any day at `aging.handover_at`), never by hand;
  - the setup's measured time (spec D544): from the newest
    `tools/fake_aging/calibration/<id>-short-game-*.txt` (written by
    `tools/tests/smoke-fake-aging.sh --record`), the deploy to
    `restart.at`, the wait for the anchor not counted, and the fill's
    duration within it, the file named; **"not measured"** without one;
  - the limits: the rows of `tools/gm/cleanrestart.py`'s `EXPLAINS` (9.10's
    table, the restart record's `explains`) that hold for the scenario by
    the record's own conditions, read at design time: the archive's row
    when a postgres node's seed `postgresql.conf` sets `archive_mode` on
    with an `archive_command` or `archive_library`; Prometheus' two when a
    node runs the `prometheus` brick; the covered routines' when a function
    or procedure in the scenario's data files or its domains' schema files
    sets its own `search_path` (9.4's cover). So the document and the
    record never disagree.

**Matching an instance's evidence to a limit.** An instance is listed
beside a limit when one of its answer-key evidence entries reads where the
row shows, by its `where`, `source` and `how`:

| Limit (EXPLAINS row) | Evidence that reads where it shows |
|---|---|
| the restart itself | `pg_postmaster_start_time()`, a process list (`ps`), a `stats_reset`, or a log of a restarted service: PostgreSQL's server log (pgBadger's report over it included), the pooler's log, a cron job's log (`/var/log/postgresql/cron/`) |
| no log before the restart | the same logs (the scheduler's own log is not one: it covers the fill) |
| real-clock actors | `cron.job_run_details`, a cron job's log, PgBouncer's console (`SHOW ...`) or its `stats:` lines, `pg_stat_archiver`, Grafana's alert state or history |
| inode change times | `pg_stat_file()`, `stat`, `ls -lc` |
| last-use times | `pg_stat_user_tables`, `pg_stat_user_indexes` |
| the LSN and WAL volume | an LSN (`pg_current_wal_lsn()`, `pg_last_wal_*_lsn()`), a WAL segment's name (`last_archived_wal`, `pg_wal`) |
| time-driven behaviour | what the definition's `aging.fake.fill.emulate` lists (a held snapshot, a lock wait, a pool's queue), or a timeout or an out-of-memory kill read in a log or a view |
| the archive vault and a standby | the archive vault (its manifests or page), a standby's replication state (`pg_stat_replication`, its receive and replay positions), a replication slot |
| Prometheus' imported blocks | the TSDB's files, Prometheus' runtime information |
| Prometheus' own series | the `prometheus_tsdb_*` series |
| the forged past's fine shape | a series read in Prometheus (`ui:prometheus`) or in a Grafana panel on Prometheus (`ui:grafana`) |
| covered routines | `pg_proc`'s `xmin`, `pg_stat_sys_tables` (a routine's definition read with `\sf` is not: it is identical) |

A row no evidence reads gets "none of this scenario's evidence". The rule
judges where the evidence reads, not whether the instance is eligible: a
refused or not assessed instance is listed as any other.

## What it does not describe

- **A playground.** The document describes the host topology and capacity
  the scenario was **designed for** (`designed_for`). The local
  implementation of a deployment (`local/<playground>/`: rendered stack,
  state, ports actually used) is separate, git-ignored, written by the GM
  at deployment, and never appears in the document.
- **Catalog internals.** Bricks and fault definitions are named by id and
  pinned version; their own docs (`docs/gm.md`, `gm.md`) stay where they
  are.
