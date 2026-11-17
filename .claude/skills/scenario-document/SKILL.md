---
name: scenario-document
description: Use whenever a db_audit_gm scenario's README.md (the scenario document) has to be generated or regenerated — once scenario.yaml and gm/answer-key.yaml are complete, after any change to either, before deploying a scenario whose README is missing or stale, or when grounding a GM on a restart or a re-spawn elsewhere. Fills the template from the authoritative files; the README is never edited by hand and always opens with the "do not read" warning.
---

# Scenario document

A scenario's `README.md` is its **scenario document**: the readable whole
of the scenario, for the GM and the lead. It is **generated** from the two
authoritative files, `scenario.yaml` and `gm/answer-key.yaml`, with this
skill's [template](template.md). This is its **v0.5 version**, expected
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
"The network overview (v0.6)" below). The template's sections follow the keys of the
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
   Two exceptions: a node's parameter whose value is a map is rendered by
   its `shape`, read from the pinned brick's `brick.yaml` (see
   "Map-valued parameters" below); and a database node's jobs are read
   from its seed `crontab`, its seed `postgresql.conf`, its data file,
   the `data/cron.sql` of each domain `domains:` places on it and the
   `ddl:` files of each purpose mapped onto it (see "The v0.4 items" and
   "The v0.5 items" below). A scenario listing `domains:` adds its
   composition record, `composition.yaml`, and `merge.yaml` when present
   (the "Composition" section, "The v0.5 items" below), with the node
   lines `tools/gmctl compose <dir> --check` prints.
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
   - from v0.5, when the scenario has them: every `domains:` entry with
     its variant and `at:`, and `composition.yaml`'s keys, scale, order,
     derivations and left-out producers, every `merge.yaml` resolution;
     every `third_parties:` entry; every false alarm, its issue and its
     `false_alarms:` entry with each evidence entry; every fault
     instance's `backlog:` with its `what` and `cleanup`, under that
     instance's answer (spec D472);
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
  line, in master spec 7.6's and access model 5 and 7's wording:
  "Published on the bastion's web front port, behind HTTP basic
  authentication on the tools password; a request without it is refused
  with HTTP 401." An empty map (`{}` written in `scenario.yaml`): no
  table, and the line "Web front routes (`<NAME>`): none. The topology
  has no web interface: the web front serves the starter-pack page
  alone, and the tools password is handed over all the same" (v0.4,
  D224). A parameter the scenario leaves out (its brick's default
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
  instance's `aging_minimum`, or "the definition's", only in a scenario
  that ages. The document never reads the fault definitions for it.
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
  purpose's definition is not read: its jobs are in the runner's files,
  named in section 7, and the faults attached to it are in section 5.
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

## What it does not describe

- **A playground.** The document describes the host topology and capacity
  the scenario was **designed for** (`designed_for`). The local
  implementation of a deployment (`local/<playground>/`: rendered stack,
  state, ports actually used) is separate, git-ignored, written by the GM
  at deployment, and never appears in the document.
- **Catalog internals.** Bricks and fault definitions are named by id and
  pinned version; their own docs (`docs/gm.md`, `gm.md`) stay where they
  are.
