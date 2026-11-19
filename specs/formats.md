# Formats: scenario, brick, fault

Status: draft v38; its v0.5 items ruled with the v0.5 master spec (D339),
amended in v0.5's build (D344, D345, D349, D354) and, after wave 2's gate,
with its format items as built: the composed load's files, the partners'
catalogue folder, the owners' traffic folder (D364, D369, D383), and
wave 1's scenario layer of the merge, `compose/<node>/`; after wave 3's
gate, with wave 3's as built (D401, D405, D421): a part's `keys.sql`, a
domain's `cron.sql`, `left_out:`, a history with no feeder, a purpose's
`ddl:` and the load's step (2b), and the owners alone on the partners'
shared nodes. Draft v32, after wave 4's gate (gate G18), with wave 4's as
built (D431–D438, D440): a purpose's parts beyond v0.4's (`source_<w>`,
`runner_<w>`, a `pg_cron` job on a database part), its material laid
out per part, the `ops` block, the calendar-gated cadences, the
invariant ids, `data_moved` reads, HTTP connections `<part>_<w>` and
endpoint `api.yaml`, one end-to-end invariant per round trip; the load's
step (2c), the GM's read policy; the register's form, its digests and
the `fixture-` exemption; the partners' handed-over credentials and
`partners.md`'s placeholders; a domain's `cron.sql` refused when its
databases are not the scenario's. Draft v33, after wave 5's gate (gate
G19), with wave 5's as built (D459, D465, D468, D469, D472): a `state`
script run on another node, the `topology` injection, a false alarm; the
register's digest of `composition.yaml` without its `coherence:` record;
the scenario document without the coherence result and with a cascade's
backlog; the customer's governance holding no location on a third
party's node and walking none. Draft v34, at v0.6's consolidation: the
network overview (a node's `description:`, `site:`, `users:`; the
bastion's seventh optional seed file; `gm/network-overview.yaml`;
`overview_diff:`; a brick's `base:`; a domain's `data/overview.yaml`;
the GM's crontab comments), a partner's admitted incidents
(`admitted:`), the front's reserved route names, fake aging's fault
fields (`aging.fake`, `history:`) and the game's restart record, and
two loader refusals carried from v0.5 (the partners' page mapping, a
seed-file instance's lines; D486, D510). Draft v35, in v0.6's wave 1
(capture W1): a `seed_changes` item's declared `lines:`, which that
refusal reads (D521). Draft v36, after v0.6's wave 2 gate (gates G10.1
and G10.2), with waves 1 and 2's forms as built (D534): the true
overview's form; fake aging's measured figures beside a node's files
(`service-times.yaml`, `wal-rate.yaml`); a fake game's records (the
timeline's keys, the restart record as written, `state.yaml`'s `hold`,
`fill` and `clean_restart`, a `fill.quiet` item and P0's cover's, the
fill's metrics record, `--test-tail-floor`); the partners' status file
and its `rendered` secret; the `brick-doc` configs. Draft v37, in v0.6's
wave 3 (capture W3): `suppressed_by` drops an entry from the hiding
instance's planting (D543). Draft v38, after v0.6's wave 3 gate (gate
G10.3), with wave 3's forms as built (D580 to D583): the history
import (its timer, its run lock, its working files, `--check-seam`),
the restart record's `history` and `state.yaml`'s `history_import`, the
seam check's findings, a fake game's restart; a history signature's
`# measured:` comments, its optional parameters, the exporter's reach,
the `**Fake aging.**` note; the calibration files, a report-only node's
service times and a one-run key's `sigma: 0`.

What a scenario, a brick, a fault definition and, from v0.4, a purpose
and a domain must contain, and how they are laid out, so that every scenario the GM designs or generates stays
within known boundaries. The rules these formats carry (the solvability
probe, per-brick checks, fault families) are in
[bricks-and-faults.md](bricks-and-faults.md); access and validator rules
in [planes-and-access.md](planes-and-access.md).

This page states what each format must contain. The YAML shapes of the
fields v0.3 adds (`aging:`, `difficulty:`, `plant_at`, `write_overrides`,
`snapshot:`, and a scheduler's `queries.yaml`, `schedule.yaml` and
`jobs.yaml`) are in the
[v0.3 master spec](versions/v0.3/master-spec.md), sections 6.7 and 7.1,
normative until the format skill's templates carry them (D151). Those
v0.4 adds (`purposes:`, `domain:`, `governance:`, `crontab_roles`,
`judges`, `needs_unshared_host`, `seed.optional`, `applies_to.purposes`)
are in the [v0.4 master spec](versions/v0.4/master-spec.md), section 6.9,
normative likewise (D215). v0.5's domain format, the composition of domains and the data
register are stated here ("Domain", "Scenario", "Purpose definition"),
with the partners' shared material ("Partners"); the other v0.5 additions (the `api` brick's and the scheduler's HTTP
keys, `options:`, `third_parties:`, `no-access` made real) are in the
[v0.5 master spec](versions/v0.5/master-spec.md), section 6, normative
likewise once it is approved. v0.6's items are stated here, their YAML
shapes in the [v0.6 master spec](versions/v0.6/master-spec.md) 6.9,
normative likewise once it is approved.

## Enforcement

Skills backed by templates enforce the formats:

- **The format skill** (D5): a template each for the scenario (manifest
  and answer key), the brick and the fault definition, from v0.4 the
  purpose and the domain (D215), and one skill the GM
  uses whenever it designs, generates or edits any of them. It starts from
  the template, fills every required item, and flags any that is missing;
  the GM refuses to deploy an incomplete scenario (D40).
- **The scenario-document skill** (D20): the GM's own skill and template for
  the scenario document (see below). The template's detailed shape is that
  skill's; what a scenario must contain is stated here.

Initial versions of both are in v0.1's scope, and both are expected to
evolve as games are played (D21). This document states what the format
skill must encode. Machine checks are per brick, not project-wide (D28);
whether the format skill itself also runs a schema check is part of the
reading to confirm under O20. As built in v0.1, the scripts check a
scenario, and the bricks and faults it uses, against the templates
whenever they load it, and refuse an incomplete one (D40); the format
skill's own check is by reading. The skills live in `.claude/skills/`,
which both Claude Code and opencode read (D29). A third skill, the GM skill,
runs the game itself ([gm-stance.md](gm-stance.md), D33).

The file names and layouts below are settled (D42). YAML for structured
content, Markdown for prose.

## Scenario

A scenario is a **self-sufficient folder** and the source of truth (D23).
With the full repository and the GM persona and skills, the folder is
enough to start the exercise: after a session restart, on another
playground, or months later. Scenarios are kept in this repository, in
bulk (D13).

The folder does not contain the shared bricks (D24). Bricks and fault
definitions shared across scenarios live in the catalog, and the scenario
references them by id and pinned version ("Versions and pins" below). A
brick or fault made solely for one scenario may live inside that
scenario's folder.

### What a scenario must contain

The owner's requirements (D23), with the earlier rulings that apply:

- **Scenario information**: id, version, title, date, origin (from a brief,
  partly or wholly, or GM-designed), session length (at most 4 hours), and
  the initiator's inputs as given.
- **A clear topology**: every node with its brick and version, its role, the
  parameters it is given, whether it is stateful, its networks and write
  policy, and its knobs' initial values (which may lie outside the
  envelope) with the envelope, tightened from the brick's default if
  needed (D32); from v0.3, its write overrides: paths among the brick's
  writable paths made fixable on a report-only node, a fault's *fix*
  resolution then needing the policy of the file it lives in (D130,
  D143); a scheduler node's seed files (`queries.yaml`, `builders/`,
  `jobs.yaml`, `schedule.yaml`; D115), from v0.4 also `scripts/`, the
  transformer scripts (D203); from v0.4, several `postgres` nodes, each an
  instance of its own with its own seed and data file (D202), every
  scheduler node on `scheduler` 0.2.0, and a `postgres` node's cron
  daemon, on when the node seeds a `crontab`, the node then naming in
  `crontab_roles` the customer roles its crontab connects as, whose
  password secrets deployment mounts into it (D206, D215); from v0.5
  every node seeding a `crontab` names `crontab_roles`, whatever its
  brick (a `health-check` node writes `crontab_roles: []`), and a node
  seeding none names none, each role one its data file or a domain
  placed on it creates; every flow between nodes (what moves, how, cadence;
  monitoring and backup relations included); the data schema each database
  holds, or what produces it.
- **Purposes, domain and governance** (from v0.4, D190–D192, D215):
  `purposes:`, each purpose used by id, its parts mapped to the
  scenario's nodes and databases ("Purpose definition" below), the loader
  checking every part is mapped and every job's key and name exist on
  the mapped runner; `domain:`, the domain the scenario's business comes
  from, for provenance only, none in a static scenario ("Domain" below);
  `governance:`, the policy file and, for each data class, its locations
  (`node/database`, with `separation: instance` when the policy demands
  an instance of its own, refused with `locations: any` (D253)), its readers (customer roles) and its outbound
  flows, each naming its receiver (`to`), the outbox it fills (`outbox`,
  `node/database/table`) and, in `fields`, the top-level keys that
  outbox's `payload` may carry, the keys the purpose's job writes, not
  words for them (D231); the loader checking every class named is
  defined, every location and every outbox's `node/database` names a
  `database` node and a database its data file creates, every reader is
  a role a data file creates, and the policy file exists. From v0.5
  "creates" counts what the `domains:` entries placed on the node
  create (each `at:` database, the roles and databases their schema and
  load files create, and on the partners' node each composed partner's
  `data.sql`), which `load-data` creates; a standby is never a location.
  **From v0.5's build** (D469) the customer's governance judges the
  customer's estate only: no location, and no outbound flow's `outbox`,
  is on a third party's node (each `third_parties:` entry's `nodes`, and
  the shared nodes found by name for the owners alone, "Partners"
  below), the loader refusing one ("`<location>`: `<node>` is a third
  party's node"); what the customer sends a partner is the outbound flow,
  judged at the customer's outbox and declared in the register's
  `shared_with`, its storage on the partner's side the partner's
  business. The governance check set walks the customer's nodes only:
  its `database_nodes` and `transformer_nodes` leave out every node the
  loader counts as a third party's (`model.third_party_nodes`, the one
  set for both), so a partners' database, whose `pg_hba.conf` rejects
  `gm_check` (D383), is never walked. Its walk of a standby and of a
  transformer's HTTP connections is a v0.5 known limit (D471).
- **Composed domains and the data register** (from v0.5, D322, D326,
  D330, D334, D335): `domains:`, the domains the scenario's business is
  composed of, each with its `at:` ("Domain" below, "Composing
  domains"), `domain: <id>` staying accepted as the one-domain form; the
  composition record `composition.yaml`, when two profiles collided
  `merge.yaml`, and the merge's scenario layer `compose/<node>/` ("The
  merge" below), beside `scenario.yaml`; and the scenario's
  **data register**, a player handout of the business's record of
  processing. Every scenario listing `domains:` must have a register,
  and the deploy refuses one without it; v0.4's released shop scenario
  is exempt until it is next revised; a scenario with `governance:`
  alone may have one but need not. `governance.register:
  player/data-register.md` names the handout, mapped to the bastion's
  optional seed file `data-register.md` as `policy:` maps to
  `data-policy.md`; the true register is `gm/data-register.yaml`. Both
  are generated by the GM's `data-register` skill from the domains'
  register fragments and classification, `governance:`, the
  composition record, the topology, the purposes in use, the third
  parties and the answer key, never edited by hand, and regenerated
  rather than reconciled. The true register opens with
  `generated_from:`, the digest of each input file, and describes the
  system as designed and composed, before any fault is planted; the
  handout is the true register rendered as is, or with a planted
  register fault's change applied, and absent when that fault is the
  register's absence. The loader recomputes the digests and refuses a
  stale register; checks that the true register covers its inputs
  (every `personal` and `customer-linked` column in exactly one entry,
  under its class; every `governance:` location and outbound flow
  present; every database with business tables in at least one entry),
  a miss being a generation error caught before the hand-over, never a
  fault; and checks that the handout exists unless the answer key
  declares it absent as a planted fault. No `data-register` section goes
  inside `scenario.yaml`: the true register is a generated file, not a
  key. **As built** (v0.5's chunk 17, D433, D434): the requirement binds
  played scenarios; a scenario whose id starts `fixture-` is exempt, and
  one that has a register is checked in full. The skill reads
  `scenario.yaml`, `composition.yaml`, the files `governance:` names,
  `player/partners.md` when mapped, `gm/answer-key.yaml`, and from the
  catalogue each composed domain's `data/register.yaml` and each purpose's
  `purpose.yaml`; it builds the true entries, writes each register fault
  instance's `register_diff:` into the answer key, then digests every
  input and writes both files. `gm/data-register.yaml` opens with
  `generated_from:`, a map from each input's path (scenario-relative, or
  `catalog/<path>` for a catalogue file) to `sha256:<hex>` of its bytes,
  but for `composition.yaml` (v0.5's chunk 37, D465): it is digested
  without its top-level `coherence:` key and the indented lines under
  it, the span `load-data` rewrites, so a setup never makes the register
  stale; a `composition.yaml` without the key digests as its bytes, and
  every other input as its bytes (the loader's `register_digest`, the
  span found by `coherence_span`, the one finder `load-data`'s rewrite
  uses too);
  then `controller`, `contact`, `policy`; `entries`, one per register
  fragment activity, its `id` the fragment's, with `department`, `name`,
  `purpose`, `people`, `data` (`personal`, `customer-linked`), `where`
  (`{at, tables}` or `{copy}`; the customer's own nodes only, never a
  third party's node, which neither a `where` nor the index names, D469:
  a purpose's table on the partners' database stays out, what the
  customer sends there a recipient in `shared_with`), `shared_with`
  (`{recipient, fields, flow?, processor?, outside_eu?}`) and `kept_for`
  (`{period, then}`),
  the field names `register_diff:` uses; `internal`, one line per
  internal activity or purpose holding internal columns only; and
  `index`, each `node/database` to its entries. A purpose's table
  holding a classed column joins the entry of the activity whose tables
  its `data_moved` reads it from; a view joins the activity its classed
  column comes from. The loader recomputes every digest and requires
  every expected input listed, refusing otherwise with "stale register:
  regenerate with the data-register skill", naming the file. A register
  fault whose `seed_changes` name `data-register.md` is accepted with
  the handout unmapped when `governance.register` exists, the answer key
  then declaring `{absent: true}` (T305). `gmctl` has no generator: the
  register is the skill's.
- **The network overview** (from v0.6, D483–D488, D500, D505): every
  scenario listing `domains:` has one, under the register's exemptions
  (a `fixture-` scenario; v0.4's shop and earlier ones until next
  revised); the deploy refuses one without it. Each customer node then
  carries `description:`, one line in the customer's words, and may
  carry `site:` (where it stands) and `users:` (people working on it
  directly: `who`, and on a database node `database` and `role`). The
  true overview is `gm/network-overview.yaml`, opening with
  `generated_from:` (each input's digest); the handout
  `player/network-overview.md`, mapped to the bastion's seventh optional
  seed file `network-overview.md`, always present when the scenario has
  an overview (never declared absent). Both are generated by the GM's
  `network-overview` skill, after the data register and before the
  scenario document, never edited by hand, regenerated rather than
  reconciled, describing the system as designed (a field read from a
  seed file a fault's `seed_changes` touch takes the value before the
  change). The loader recomputes the digests and refuses a stale
  overview; checks its coverage (every customer node in exactly one
  entry, the bastion and the third parties' nodes in none; every
  partner with a `player_doc` in its third-party table; every database
  connection of every composed config, every job, crontab line and
  `pg_cron` job, every database of every database node, every standby,
  `archive_mode = on` and base backup line, each under its field), a
  miss being a generation error; and that the handout names no third
  party's node and that its **Your access** column and header equal the
  true overview's. A scenario without an overview keeps its README's
  node table (D511). The fields and their sources are the
  [v0.6 master spec](versions/v0.6/master-spec.md)'s 8.2. **The true
  overview's form** (as built, D534): top keys `generated_from` (each
  input's path to `sha256:<hex>`: 8.4's inputs plus the customer nodes'
  data files, their `brick.yaml`, the purposes' `ddl:` files and
  `player/story.md`), `header` (`customer`, `network`, `bastion`,
  `node_health`, `trust`, each 8.1's fixed line as rendered), `entries`,
  `third_parties`. An entry: `node`, `group` (`database`, `application`,
  `integration`, `monitoring`), `role`, `access`, `activity`, then the
  fields under the names `overview_diff:` uses: `description`, `site`
  (only when the node has one), `system`, `applications`, `sizing`
  (scalars, the line as handed out) and the lists `databases`
  (`{database, holds, register: [<entry id>]}`), `fed_and_used_by` and
  `uses` (`{node, database, role, what}`; an HTTP use `{node|partner,
  what}`), `users` (`{who, database, role}`), `third_parties`
  (`{partner, anchor, what}`), `tasks` (`{task, when, zone, what,
  source: jobs|crontab|pg_cron|purpose}`, a crontab task named by its
  comment line), `backups` (`{kind: standby|wal-archive|base-backup|vault|check,
  line}`, or the one item `{kind: none, line: none}`), each item also
  rendered as one line of the handout. `access` reads `write
  (<paths>)`, `read-only` (`; write: <paths>` with an override) or
  `none`. A third-party row: `{id, name, hostname, anchor}`. A diff's
  `field` is an entry's key and its `true` one of that field's rendered
  lines. The handout opens `# Network overview: <customer>` and the
  header's lines, then a summary table, one `##` section per group and
  one `### <node>` per entry (its anchor the node's name), one bullet a
  field ("none" when empty), a list field's items nested one a line,
  and closes with the third parties' table. **Crontabs
  written by the GM**: each entry has its description on the comment
  line directly above it.
- **The bastion's web front** (from v0.6, D480, D501, D511): a
  `web_routes` entry may not be named `docs`, `reports` or `status`, the
  front's own paths; the loader refuses one.
- **Background information**: the customer's story and context.
- **Incidents, flaws and defects**: every fault instance (fault definition
  and version, target nodes, parameters, known or hidden; from v0.3 its
  planting moment, `T0` by default or, for a `state` fault only, a moment
  before hand-over written relative to it, within the scenario's aging
  minimum and never at or after hand-over (D127, D151), and its aging
  minimum when it needs more than its definition's),
  and the issues given to the players, zero or more, each with its expected
  resolution (*report*, *propose*, *fix*, *improve*) and the faults it
  covers (D9);
  the aging plan: none in v0.1 or v0.2; from v0.3, in a scenario with
  scheduler nodes, a required `aging:` block with the aging minimum, at
  least eight hours and as long as the scenario's evidence needs, and the
  hand-over time of day the scenario was designed for, in scenario time
  (D114, D129, D150). A scenario with no scheduler node has no aging
  (D157) and omits `aging:`, which the loader refuses there, as it
  refuses a planting moment other than T0, an instance's aging minimum
  and the customer's time zone placeholder, none of which means anything
  without an aging or a shift; its fault definitions' aging minima,
  times under the load, are not counted, and `render --handover` is
  optional for it (D158); and its
  difficulty score, the number of fault instances, checked by the
  loader, with optionally the level it targets (D120, D134). An issue may also cover a
  tooling expectation, which is not a fault (D65, D76). From v0.5 an
  issue may be a **false alarm** (v0.5's chunk 36, D459): `covers: []`,
  its expected resolution *report*, and an entry in the answer key's
  `false_alarms:` (below); the loader refuses an issue covering nothing
  with another resolution or with no entry there. A false alarm is no
  fault instance: it counts in no difficulty score and no fault cap.
  From v0.6 a fault instance may carry **`admitted:`**, the incident it
  causes as a partner admits it on its status page: `by` (a
  `third_parties:` id with a `player_doc`), `title`, `text`, `from`
  (`T0` or a moment before hand-over written as a planting moment is,
  never before the instance's planting) and, optional, `until` (after
  `from`, not after the hand-over); render turns them into UTC instants
  for the bastion's status file, and only a planted instance's incident
  shows.
- **The answer key**, for every fault instance: what is wrong and why, the
  evidence as the player user and where it is run (a required `where`
  from v0.2: `bastion`, `node:<name>`, `ui:<name>`, `report:<tool>`;
  D81), with the file, view or output looked at under a required
  `source`, which held v0.1's free-text `where` (D101), what counts as an
  acceptable diagnosis, fix, improvement or recommendation, the sealed
  check, interactions with other faults, any validator the player cannot make green (D10), and, once
  solvability probes exist, their results. From v0.3 a behavioural
  sealed check (one judging behaviour over time, not a cause) states its
  window and threshold (D124). From v0.4 a sealed check judging a
  purpose's runs or triggers states `judges: runs` or `judges: triggers`
  and a `threshold` (violations tolerated, 0 by default), and no window
  (D215). The GM's silent tooling
  expectations (D65) are a list of their own, outside the fault
  instances: each says what is expected and what is acceptable (any of
  the research's top three tools for a need, say), has no sealed check,
  and is judged in feedback (D76); from v0.4 one may name an unmonitored
  instance (D215). From v0.5 a register fault instance (a fault planted in
  the data register handout only: its definition's `seed_changes` hold
  the bastion's `data-register.md`) carries `register_diff:`, required
  there and refused on any other instance: a non-empty list, each item
  exactly the entry, the field, the true value and the value handed out
  (`entry`, `field`, `true`, `handed_out`), or the one item
  `{absent: true}` for the register's absence; its resolution is *propose*, the
  corrected entry judged at the final answer against the diff (D333),
  and the scenario document shows the diff in a "Data register"
  section. From v0.6 a network-overview fault instance (its definition's
  `seed_changes` hold the bastion's `network-overview.md`) carries
  `overview_diff:`, required there and refused elsewhere: a non-empty
  list of `{node, field, true, handed_out}`, `field` one of
  `description`, `site`, `system`, `applications`, `sizing`,
  `databases`, `fed_and_used_by`, `uses`, `users`, `third_parties`,
  `tasks`, `backups`, or `entry` for a whole entry missing or invented
  (its `true` or `handed_out` then `absent`); never `access` or the
  header, and no `{absent: true}` item (D505); resolved by *propose*,
  judged against the diff, the scenario document showing it in a
  "Network overview" section. From v0.5 a round-trip fault instance that leaves requests
  stuck before the fix lists them as its `backlog:` (`what`, the
  requests stuck; `cleanup`, what counts as cleaned up), a consequence
  the GM may credit, never a fault and never counted toward the fault
  cap or the score; the scenario document shows it with the instance's
  answer (D472). And the answer key's optional `false_alarms:` (v0.5's
  chunk 36, D459), non-empty when present, holds one entry per false
  alarm: `issue` (an issue of `scenario.yaml` with `covers: []`), `why`
  (why no fault is behind it), `evidence[]` (as a fault instance's, its
  `where` checked) and `acceptable` (one string, as a tooling
  expectation's); the loader refuses an entry naming no issue, an issue
  that covers anything, or one issue twice. The scenario document shows
  each in a "False alarms" subsection of its answer key; it is judged at
  the final answer, on the report alone, with no sealed check.
- **The host topology it was designed for**: the platform (Swarm,
  Kubernetes…), the hosts, their capacity (CPU, RAM, disk), and the
  resource limits, reservations and placement the scenario was sized with.
  This is the reference the local implementation adapts from.
- **The starter pack** shipped to the bastion: topology documentation,
  node names, rules and DO NOT TAMPER list, the story, the issues. From
  v0.3 the story and the starter pack name the customer's time zone
  through a placeholder render fills from the shift, never a fixed zone
  (D129, D151), a scenario with no scheduler node having neither shift
  nor placeholder, its times UTC (D158); and a scenario's Prometheus
  retention covers its aging minimum (none without an aging) plus four
  hours by time unless a planted fault is about
  retention, which the loader checks, a size bound staying above the
  measured growth (D140, D151). From v0.4, a scenario with `governance:`
  hands the players the company's data policy, `player/data-policy.md`
  (D191, D215), mapped to the bastion's optional seed file
  `data-policy.md`; `bastion` 0.4.0 copies it into the player's home
  with the rest and shows the starter pack on a page, each file only
  when the scenario has it (D221). From v0.4 the web front runs in every
  game, the bastion publishing its port and the tools password handed
  over whether or not the topology has a web interface; the page is its
  home, linking to the web interfaces when there are any (D224,
  replacing D103). From v0.5 a scenario whose `third_parties:` carry a
  `player_doc` hands the players the partners' page,
  `player/partners.md`, mapped to the bastion's optional seed file
  `partners.md` exactly then ("Partners" below); v0.5's loader did not
  enforce the mapping unless an entry listed `credentials:`; from v0.6
  it refuses either omission (O251, D486).
- **The files each node needs**, delivered as Swarm configs (D11).
- **Fake aging's measured figures** (from v0.6, D534): beside a node's
  seed files, never a seed file, never mapped, so nothing of fake aging
  reaches a node a player reads; each opens with `source:`, the run, its
  date and the file the figures were measured from. A scheduler node
  whose keys a fake game's fill runs has `nodes/<node>/service-times.yaml`
  beside the `queries.yaml` defining them, `keys:` mapping each key a
  stream or job of the node runs to `{median, sigma}` (seconds of
  database work a call, lognormal); `gmctl fill` refuses a key without
  one, naming the key and the file. A key on a report-only node, whose
  jobs no short real run can move into its window, is timed from its own
  runs in a fill (the campaign's `bi` from `rpt.etl_runs`' ledger times)
  or by running its statement with psql (the campaign's
  `customs.unavailable`), its `source:` saying which; a key measured on
  one run carries `sigma: 0`, no spread measured, and its `source:` says
  so (D578). Each primary `postgres` node (not a
  standby) of a scenario played fake has `nodes/<node>/wal-rate.yaml`,
  `bytes_per_hour:` the WAL the node writes in an hour at the scenario's
  load, a positive whole number, measured; `gmctl clean-restart` pads
  the WAL to 24 times it and refuses, before doing anything, a node
  without the file or with a malformed one (duplicate keys refused, as
  the loader's), naming it. The loader reads neither: a scenario only
  ever played real needs neither.

  A figure measured in a short real run is recorded by the calibration
  tool (`tools/fake_aging/calibrate.py`, `--record <what>`) or the run's
  script in one file per measurement,
  `tools/fake_aging/calibration/<scenario id>-<what>-<YYYYMMDDTHHMMZ>.txt`,
  opening with `command:`, `commit:`, `start:` and `wall time:` lines.
  `<what>` as built in wave 3: `keys-<node>` (a node's service times),
  `run-<letter>` (the run itself: its steps and windows, `run-a`), the
  instance (`f1`, `f5`: a fault's figures), `fill` (a short fill), and
  `wal-<node>` (a WAL rate). A `source:` here, and a `# measured:`
  comment in a fault's history ("Fault definition"), names that file;
  the shop's figures name a member of the reference instead (master
  spec 12.3), never a copy of it.

  ```yaml
  # nodes/db/wal-rate.yaml
  source: >-
    research/fake-aging 10d1bc6, run R (fa-real, 2026-11-14 to 15), reference
    member m1-fa-real-20261115T0800/shared_stats.csv: pg_stat_wal.wal_bytes ...
  bytes_per_hour: 43881262
  ```
- **The scenario document**, generated with the GM's scenario-document
  skill (D20), opening with a prominent warning that students and players
  should not read it. Enforcement goes no further (D13). The starter pack
  does not carry the warning; repeating it at the top of the other GM-side
  files is (proposed). From v0.5 it renders every answer-key item a
  fault instance carries, a cascade's `backlog:` included (D472), and
  the false alarms; it never shows the coherence result, setup state
  ("Composing domains" below, D468).

A scenario is complete whatever the initiator sketched or left out at
setup: the GM fills the blanks (D16). Recording which items came from the
initiator and which the GM filled in is (proposed).

### Layout (D42)

The readable document and the machine files live together in the folder.
`scenario.yaml` and `gm/answer-key.yaml` are authoritative; the scenario
document (`README.md`) is generated from them by the scenario-document
skill (D40).

```
<scenario-id>/
  README.md           the scenario document (template: the GM's scenario-document skill)
  scenario.yaml       the machine-readable manifest: information, topology, defects, issues, host topology
  brief.md            the initiator's inputs as given (possibly partial or empty)
  player/             the starter pack, shipped to the bastion
    README.md         topology, node names, rules and DO NOT TAMPER list
    story.md          the customer's background
    issues.md         the issues given, each with its expected resolution (may be empty)
    data-policy.md    from v0.4, with `governance:`: the company's data policy
    data-register.md  from v0.5, with `domains:`: the data register handout (generated)
    partners.md       from v0.5, with `third_parties:` carrying a `player_doc`: the partners' page
    network-overview.md  from v0.6, with an overview: the network overview handout (generated)
  gm/                 sealed: never shipped to any node
    answer-key.yaml
    notes.md          explanations the GM draws on for feedback
    data-register.yaml  from v0.5: the true register (generated)
    network-overview.yaml  from v0.6, with an overview: the true overview (generated)
  composition.yaml    from v0.5, with `domains:`: the composition record, written by the GM
  merge.yaml          from v0.5, when two profiles collided: the merge's resolutions
  compose/<node>/     from v0.5, with `domains:`: the merge's scenario layer, one folder per
                      scheduler or `api` node, written by the GM, never shipped
  nodes/<node>/       files per node, delivered as Swarm configs (D11); with `domains:`, a
                      scheduler or `api` node's merged files, written by `gmctl compose`;
                      from v0.6 also `service-times.yaml` and `wal-rate.yaml`, never mapped
  data/<node>.sql     restored-backup data, streamed into the node through the injection path (D39)
  bricks/, faults/    bricks and faults made solely for this scenario, if any (D24)
  local/<playground>/ local implementations, one per playground, git-ignored (D40)
```

## Local implementation

At deployment the GM generates a **local implementation** of the scenario
for the real playground (D23). It maps the playground's true resources onto
what the scenario expects:

- resource limits and reservations per node, placement and pinning, and the
  number of hosts used (one in v0.1 and v0.2, D35; from v0.3 nodes are
  placed on the playground's declared hosts and rendered as hostname
  constraints, the bastion pinned to its own host, and the images copied
  to each host over SSH, with no registry, D128, D149);
- from v0.3, the planned hand-over and the shift in whole hours mapping
  scenario time onto UTC, T0, the aging minimum, the outages and the
  lost time (D152), the earliest hand-over and the hand-over, the game's seed, the
  scheduled setup actions and their results, the early and hand-over
  checks' results, the hand-over snapshot's location, and each restart
  (old and new game ids, time, from the snapshot or not, the player's
  confirmation) (D126, D129, D136, D141, D151);
- the game id, which names every volume, config, secret and network of the
  game, so a redeploy never reuses a player-edited volume (D36); each
  network the scenario declares renders as one network named
  `<game_id>_<network name>` (D85; v0.1 rendered one `<game_id>_net`);
- the rendered platform files: the Swarm stack file today, Kubernetes
  manifests later. They are always rendered, never written by hand (D22).

In v0.1 the scenario's resource limits and envelopes are absolute: the
local implementation only checks that they fit the playground and never
recomputes them, since recomputing could turn a planted out-of-bounds
value into an in-bounds one (D32).

The GM adapts the scenario to the playground as long as capacity is
sufficient. If it is not, the GM says so and does not deploy (D23). The
scenario itself is not changed by a new playground; only a new local
implementation is generated.

Where it lives (D42): in `local/<playground>/` inside the scenario folder.
It is kept out of version control (D40), because it describes one particular
set of machines. It never holds host access keys; it does keep the game's
own credentials in `secrets/` (mode 0600), so a restarted GM can hand them
over again (D45). Besides the mapping and the rendered files, it records the
playground as declared at setup (platform, hosts, capacity) and the current
game's id and progress (stage reached, including where a failed setup
stopped, D36), so a restarted GM can find where it was.

### A fake game's records (from v0.6)

From v0.6 (D506; forms as built in waves 1 to 3, D534, D580) a fake-aged game
keeps its timeline in `implementation.yaml`, its **restart record** in
`local/<playground>/fake-aging.yaml`, and its progress in `state.yaml`.
All are GM-side, out of the players' reach like the answer key;
`gmctl status` shows the mode and the record.

**The render.** `gmctl render --aging real|fake` (`real` by default). A
fake render is refused in a scenario without scheduler nodes (no aging,
D157) and when its anchor has already passed. It adds to
`implementation.yaml`'s `timeline` `virtual_t0`, `anchor` (planned: the
hand-over minus the tail), `tail` (a duration in one unit, `3h`) and
`refused` (the refused instances' ids); the timeline's `instances` then
hold neither a refused instance nor one the test harness leaves out, and
every later verb (inject, the fill, the checks, the status file) leaves
both out through one function (`localimpl.left_out`); their seed changes
stay in the copies. The stack file renders the monitoring nodes (bricks
`prometheus`, `grafana`, `postgres-exporter`, `pgwatch`) at `replicas:
0` until the record has `restart`. In a scenario with scheduler nodes the
bastion's `story.md` is always a rendered seed file, so fit's configs
don't depend on the mode, and a fake render appends the restart's story
line as its last paragraph. A real render removes a leftover record.
`--test-tail-floor <duration>`, undocumented and the test harness's
alone (as `--test-leave-out`), caps the tail's floor between `1m` and
`1h`, in a fake game only, recorded as `test_harness_override.tail_floor`.

**The restart record as written**, render's keys first, then
`clean-restart`'s `restart`, then the history import's `history`:

```yaml
mode: fake
virtual_t0: 2026-11-20T22:00:00Z
anchor: 2026-11-21T11:00:00Z        # planned
tail: 3h
handover_planned: 2026-11-21T14:00:00Z
refused:                            # [] when none
  - {instance: f10, reason: "not assessed: no aging.fake"}
restart:
  at: 2026-11-21T11:00:14Z          # the one start's issue instant, to the second; never before the anchor
  story_line: The servers were restarted for maintenance on 2026-11-21 at 11:00 UTC; older logs were archived.
  explains:
    - {observation: "the restart itself: the postmaster's start, every container's start, ...",
       where: "pg_postmaster_start_time(), ps, stats_reset, the log folder",
       in_world: the maintenance restart of the story line}
history: {at: 2026-11-21T11:12:30Z, result: ok, seam: ok}
# or: {at: ..., result: ok, seam: failed, reason: "seam jump: <series>: ...; and 2 more"}
# or: {at: ..., result: failed, seam: unchecked, reason: "Prometheus did not load the blocks within 180 s ..."}
```

A refused instance's `reason` is its fault's `aging.fake.reason`
(`real-only`), or `not assessed: no aging.fake`. `story_line` is the
planned anchor's date and time in UTC, as appended to `story.md`.
`explains` holds the rows of the v0.6 master spec's 9.10 table that hold
in this game: the archive's row only when the hold or the fill turned
archiving off, the covered routines' row only when `fill.quiet` lists a
cover, Prometheus' two rows (its imported blocks, its own series showing
the import, D541) only in a game with a `prometheus` node; `in_world`
reads `none: not covered by the story` where the story covers nothing.
`history` is the history import's, written last, by `gmctl history`
alone, through the whole file: `at` the attempt's end, to the second;
`result` `ok` once the blocks are in and Prometheus has loaded them,
`failed` otherwise; `seam` `ok` (no finding), `failed`, or `unchecked`
when the import failed before the check; `reason` only when the two
are not both `ok`, one line: the error, or the first three findings as
`seam <check>: <series>: <detail>`, `"; "`-joined, then `; and <n>
more`. A retry replaces it.

**Progress in `state.yaml`.** The stage stays `injected` from the inject
to `start-load`; no new stage.

- `hold: {at, items}`: written by `gmctl deploy` in a fake game, once the
  nodes are healthy and before anything else, on each primary `postgres`
  node: `pg_cron`'s launches off (`cron.launch_active_jobs = off`) when
  `pg_cron` is loaded, archiving off (`archive_command = '/bin/true'`, and
  `archive_library = ''` when set) when it is on, the cron daemon stopped
  when it runs; each item recorded before it is applied, `left_off:
  true`; `items: []` when none runs. The fill neither turns off again nor
  lists an actor the hold lists for that node.
- `fill: {started_at, ended_at, outcome, reason, quiet}`: `gmctl fill`'s.
  `outcome: ok` when the program ended `DONE` and every planting
  succeeded, even when an end restore or the shim's drop failed: those
  items stay without `restored_at`, for `clean-restart`, and `reason`
  lists the problems, `"; "`-joined, each `<node>: <what> not restored
  (<error line>)` or `<node>/<database>: gm_vclock not dropped (<error
  line>)`. `failed` otherwise: never resumed, the game torn down. A state
  instance the fill plants at a pause is recorded under `plantings.<id>`,
  its attempt `{at, by: fill, virtual_at, outcome}` (`at` real), its
  `planted_at` the virtual instant.
- `clean_restart: {started_at, ended_at, outcome: ok|failed, reason,
  wal: {<node>: {padded_bytes, pg_wal_bytes, seconds}}}`: `gmctl
  clean-restart`'s, which requires `fill.outcome: ok`, is refused once
  its own `outcome` is `ok`, and is refused before the planned anchor.
- `load.t0` the virtual T0 and `load.anchor` the record's `restart.at`,
  written by `start-load`, which in a fake game requires
  `clean_restart.outcome: ok` and `restart.at`. The earliest hand-over
  (never before it plus the tail), the early check and the outages count
  from `load.anchor`.
- `history_import: {timer, scheduling_failed, attempts}`: the history
  import's progress (not `history`, which is the stage history).
  `start-load` writes it in a game with a `prometheus` node, before the
  early check's timer: `timer` is the history unit's record (`{unit,
  due, created_at}`, as `early_check.timer`), `scheduling_failed` only
  when it could not be created, `attempts: []`. Each `gmctl history`
  import appends `{began, ended, outcome: ok|failed, reason, seam:
  [<finding>], figures}`; `figures` holds what the attempt measured:
  `tail_series`, `tail_read_s`, `series`, `samples`,
  `openmetrics_bytes`, `compose_s`, `report` (the composer's counts),
  `import_s`, `blocks` (`{<block id>: bytes}`),
  `promtool_memory_peak_bytes`, `loaded_after_s`, `seam_s`, `tsdb`
  (Prometheus' three `prometheus_tsdb_*` series once its self-scrape
  shows the blocks, within 60 s, else as read with `stale: true`), and
  on a retry `removed_before_retry` (the failed attempt's block ids),
  each only as far as the attempt got. A restart clears `timer` and
  keeps the attempts; a teardown and a restart count `timer` among the
  game's timers, so they know one exists with the manager unreachable. A
  fake game's check records (`early_check.result`, each
  `handover_checks` item) gain `history`, the check's line after
  `history import: ` (`ok, seam ok`; `<result>, seam <seam>: <reason>`;
  `not recorded`; `none (no Prometheus node)`).

**The history import** (D580, D583). `start-load` creates the unit
`dbagm-<game_id>_history`, due `restart.at` plus 12 minutes (never
moved by `--test-tail-floor`), running `gmctl history <dir> --playground
<pg>`; a game without a `prometheus` node has none. `gmctl history` is
refused, nothing done or recorded, in a game that is not fake or has no
`prometheus` node, at another stage than `load-started`, at or after
`handed-over`, and before `restart.at` plus 10 minutes, the tail's
first minutes it reads. One import at a time: an import holds
`local/<playground>/.history.lock` (an exclusive `flock`), so the
timer's run and the GM's never import at once; the second, once the
lock is free, reads the refusals and the record again. Once `history.result` is `ok` a run prints the
recorded result and changes nothing, exit 0 with the seam `ok` and 1
with it `failed`: a failed seam is never imported again. After
`failed` it imports again, first removing from the TSDB volume every
block wholly before the restart and any half-moved one. A timer's run
first waits up to 600 s for the game's nodes and imports anyway. The
working files are `local/<playground>/history/{tail.json, history.om,
report.json}`, removed after an `ok` import and kept after a failed
one. promtool runs in a helper container of the Prometheus node's
image on its host (`--rm`, `--pull never`, no network, labelled with
the game), each block moved into the TSDB volume whole under a name
Prometheus skips until its rename, owned `prometheus:prometheus`, the
folder left `0750` (D540); Prometheus loads them by itself within 180
s, else `failed`, and is never restarted. `--check-seam` runs the seam
check alone against the live Prometheus, at any stage once
`history.result` is `ok`, and records nothing (exit 0 no finding, 1
otherwise). The output's last line: `Game <id>: history from the
virtual T0 <instant> to the restart <instant> imported at <instant>;
seam ok|failed (<n> findings)`, or `Game <id>: history import failed
at <instant>: <reason> (recorded; nothing torn down)`, or with
`--check-seam` `Game <id>: seam ok|failed (<n> findings); nothing
recorded`; each finding on a line before it, `  seam <check>: <series>:
<detail>`. Exit 0 only when `result` and `seam` are both `ok`.
`gmctl status` reads `history import: <result> at <at>, seam <seam>`
and the reason on the next line, or before the import `history import:
due <instant> (timer <unit>)` or `history import: FAILED to schedule:
<why>`.

**The seam check's findings** (D581), `{check, series, detail}`, the
series as its label set; the verdict is `ok` with none:

- `negative`: a value in the forged past below zero, or below the
  series' own value where the system itself holds it below zero (a
  setting's `-1`); or a value below zero at the join coming from a past
  that was not;
- `reset`: a counter going down in the forged past, or going down at
  the restart on a series the restart keeps (`pg_stat_database_*`, the
  table and index statistics);
- `jump`: a size gauge (`*_size_bytes`, `*_used_bytes`,
  `*_free_bytes`) whose first value from the restart on differs from
  its last forged value by more than the larger of 1 % and the tail's
  own largest step between two samples in its first 5 minutes; other
  gauges are drawn around the tail's level with its spread and are not
  checked at the join;
- `empty` (`series` `*`): no sample at all before the restart.

**A fake game's restart** (D582), with `gmctl restart`: from the
hand-over snapshot it is the same fake game, the timeline's
`virtual_t0`, `anchor`, `tail` and `refused` kept, the record unchanged,
its `history` included, no history unit and no second import, the
imported blocks back with Prometheus' volume; with no history the
timeline keeps `anchor`, `tail` and `refused` but not `virtual_t0`, so
the rebuild runs on the real clock as the real mode's no-history
restart (no fill, no import, no history line in the checks) while the
refused instances stay out and the story keeps its line, and the record
stays the first game's, for the feedback.

**A `fill.quiet` or `hold` item** says what was turned off, how, and how
to restore it:

```yaml
- node: db
  what: pg_cron's job runs          # the real-clock actors: "pg_cron's job runs", "archiving", "the cron daemon"
  how: ALTER SYSTEM SET cron.launch_active_jobs = off
  left_off: true                    # true: restored by clean-restart for the next start; false: by the fill's end
  restore: {user: postgres, sql: ["ALTER SYSTEM RESET cron.launch_active_jobs;"]}   # or {user: root, script: ...}
  restored_at: 2026-11-21T11:00:16Z # once restored
```

A `restore.sql` runs as `postgres` in `restore.database`, in database
`postgres` when absent. The fill's own items besides the actors: the
statement statistics, statement log and pgaudit quieted per role and
database it connects as (fix 3), `autovacuum_naptime` lowered (fix 7),
both `left_off: false`. **P0's cover** adds one item per node, database
and routine signature, recorded before its `ALTER` is sent, with
`routine` and `restore.database`:

```yaml
- node: reporting
  what: "P0's cover: search_path of procedure rpt.close_day() in sales (spec D523)"
  how: ALTER PROCEDURE rpt.close_day() SET search_path = gm_vclock, pg_catalog, pg_temp
  left_off: false
  routine: {database: sales, kind: procedure, signature: rpt.close_day(), original: "pg_catalog, pg_temp"}
  restore: {user: postgres, database: sales, sql: ["DO $gm_cover$ BEGIN IF EXISTS (...) THEN ALTER PROCEDURE rpt.close_day() SET search_path = pg_catalog, pg_temp; END IF; END $gm_cover$;"]}
```

`original` is the setting as `proconfig` holds it; `restore.sql` is
guarded, acting only while the routine is under that cover, so a routine
gone or redefined since counts as restored and a rerun is safe. After
each planting a routine replaced or added is covered again, its item's
`original` and `restore` rewritten. A routine already under a cover no
item lists fails the fill. The fill's end and `clean-restart` restore
the covers first.

**The fill's metrics record**, `local/<playground>/fill/<node>.metrics.jsonl`,
one JSON object a virtual minute, in order: what the node's `/metrics`
would have served at that minute's end counting from the virtual T0,
`at`, `scheduler_calls_total` and `scheduler_errors_total` (`{<key>:
n}`), `scheduler_call_duration_seconds` (`{<key>: {buckets: {<le>: n},
sum, count}}`), `scheduler_job_runs_total` (`[{key, job, value}]`),
`scheduler_job_skips_total` (`[{key, job, reason, value}]`); read by
`gmctl history`. The program's fill interface (`gm_scheduler fill`: one
JSON line in, its `FillConfig`, then `PAUSE <instant>` and `GO` at each
pause, `DONE <json>` or `FAILED <reason>`) and `gm_scheduler fill-sql`
(the shim's SQL; `--drop`, the checked drop; `--cover`, the routines
pinning their own `search_path`) are the `scheduler` brick's, stated in
its `docs/gm.md` ("The fill mode (0.4.0)").

### The partners' status file and the brick pages (from v0.6)

**The status file** (D534): render writes it from each planted
instance's `admitted:`, JSON, since the bastion reads it with `jq`:

```json
{"generated_at": "2026-11-21T09:00:00Z",
 "partners": [{"id": "northfield-lab", "name": "Northfield Veterinary Laboratories",
               "anchor": "northfield-veterinary-laboratories",
               "incidents": [{"instance": "s11", "title": "Delayed results delivery",
                              "text": "...", "start": "2026-11-21T08:00:00Z",
                              "end": "2026-11-21T10:00:00Z"}]}]}
```

`generated_at` is the render time; every third party with a
`player_doc`, in `third_parties:` order, one admitting nothing with
`"incidents": []`; `anchor` the `player_doc`'s fragment, or `null`;
incidents in `start` order, `end` `null` without `until`. Only the
instances the game plants admit anything (a left-out or refused one
doesn't). Instants: `handover-<N>h` the planned hand-over minus N hours
(render refuses one in a game rendered without `--handover`); `T0` the
virtual T0 in a fake game, else the render time, so a real game's `T0`
incident shows from the render. It is delivered as a secret of kind
**`rendered`**, which render writes and no brick declares and deploy
never generates: `partners_status`, Swarm `<game_id>_partners_status`,
file `secrets/partners_status.json` (0600 in the 0700 folder), on the
bastion at `/opt/gm/secrets/partners_status.json`, `0:0`, `0400`;
declared exactly when some third party has a `player_doc`; rewritten by
every render, a restart's included.

**The brick pages**: one config of kind **`brick-doc`** per brick of a
node the players may reach (every node but a third party's, the bastion
included), in topology order, once per brick id: name
`<game_id>_<bastion node>_doc-<brick-id>`, file the pinned brick's
`docs/player.md`, on the bastion at `/opt/gm/docs/bricks/<brick-id>.md`,
`0:0`, `0444`. Built at fit, which refuses a brick whose page is missing
or empty; render refuses "the brick pages changed since gmctl fit: fit
again". The names count in the game id's length bound.

## Brick definition

```
bricks/<brick-id>/
  brick.yaml
  Dockerfile         and its build context
  validator/         the public validator
  docs/player.md     what the player may read about this kind of node
  docs/gm.md         the GM documentation (required sections below), never shipped
  companion/         optional: the brick's own checks, scripts and tools (D28),
                     and material the GM mounts into other nodes (D89)
```

### `brick.yaml` must contain

Fields marked *optional in v0.1* have no use yet and may be left out
(D35).

- **Identity**: id, version ("Versions and pins" below), role(s),
  technology and engine version(s), image name(s); from v0.6 `base:`,
  the image's operating system (`{os: Debian GNU/Linux, version:
  "13"}`), checked by the brick's tests against the image's
  `/etc/os-release` (D487, the network overview's **System**).
- **Footprint** (D84): the shape of a scenario's `resources`, limits for
  CPU and memory and reservations for CPU, memory and disk, as the
  default the GM starts from when it sizes a scenario; `gmctl fit` and
  the renderer read the scenario's own `resources`. The v0.1 bricks' one
  figure per dimension takes this shape at their 0.2.0 (D72). The allowed
  range is *optional in v0.1*.
- **Interfaces**: what the brick *provides* (e.g. a PostgreSQL SQL endpoint
  on a port) and what it *consumes* (e.g. an upstream SQL endpoint, a
  queue). Flows in a scenario connect a consumer interface to a matching
  provider; this is what lets a pipeline be checked. *Optional in v0.1.*
- **Parameters** the scenario sets (upstream node, schema, load rate…).
- **Knobs**: setting, file, default, and default envelope; a scenario may
  tighten the envelope (D32).
- **Write policy options** it supports (*fixable*, *report-only*).
  `postgres` supports *fixable* only, from v0.4 too: a database node
  another party owns in the story is report-only by the story and the
  answer key alone (D211).
- **Writable paths** (what the player may change; from v0.3 also the
  paths a scenario's write overrides may name, D143) and **protected
  files**.
- **Snapshot** (from v0.3, D142, D147): per volume, how it is copied at
  hand-over: `pg_basebackup` for a database's data, `copy` (a plain copy
  while the node runs) for a volume holding only seeded, append-only or
  whole-file-rewritten files, or `stop`, a brief stop of the brick's
  service inside its running container (s6, never a Swarm scale to zero)
  while the volume is copied. Prometheus and Grafana use `stop`. A volume
  the brick empties at every start is not copied; a brick that declares
  nothing gets `stop`. The footprint's disk includes the volumes' growth
  over an aging and a four-hour game, as measured, per hour.
- **Player access**: the SSH account, its group, its `sudo` wrappers.
- **Capabilities** it adds back after dropping all (D41).
- **Monitoring exposure**: metrics endpoints, logs, what monitoring bricks
  can collect. *Optional in v0.1.*
- **Health check**: a command run inside the container.
- **Secrets** it needs, and the fixed paths where it reads them and its
  seed files. Every seed file a brick declares is required of every node
  using it, except those it lists under `seed.optional` (from v0.4;
  `postgres`' `crontab` the first, D206, D215; the bastion's
  `data-policy.md` the second, D221).
- **Processes** run under s6-overlay (D30).
- **Companion material**, if any (see below).

**Companion material** (D28, D42). A brick may ship extra information,
scripts or tools that help its integration and use: its own lint or
checks, helpers for the GM (seeding, state injection, inspection), notes on
combining it with other bricks. Machine checks are per brick: whether a
brick has any depends on the brick. Such material lives in the brick's
`companion/` folder, and `brick.yaml` says what it provides and when the GM
should use it.

**Companion material mounted into other nodes** (D88, D89, D97). Some
companion material does not stay with the brick's own node: the GM
mounts it into other nodes of the topology at deploy, as configs, as
`prometheus` does with the node-health script. For each such item,
`brick.yaml`'s companion declaration states:

- the files, and for each its target path and mode in the receiving
  node (root-owned and read-only there, so a protected file);
- which nodes receive it: those the brick's parameter for it lists;
- the parameter that configures it per node, set on the brick's own
  node in the scenario;
- what it adds to each receiving node's footprint;
- what a receiving image must provide (for the node-health script:
  s6-overlay v3 and the commands the script uses, by name).

For the node-health script the parameter is a map from node name to that
node's entry, and it is explicit (D97): whenever the topology has a
`prometheus` node, the map is required and lists every node of the
topology, `prometheus`'s own included; an entry is either a list of
services or `default`, which stands for that node's brick's s6
`processes`. The format skill and the loader refuse a missing map or a
node missing from it. In the scenario the map is always complete: a node
left out exists only as a fault planted through the parameter (D92).
The renderer writes each node's entry, with the node's declared disk
reservation (D96), into that node's own config.

A receiving brick declares in `brick.yaml` what it provides to mounted
material (its s6-overlay version, the commands available), and its
`docs/gm.md` says so under Connections (D97). The loader checks each
receiving node's declaration against the requirements of the mounting
brick's pinned version and refuses a topology where one is not met.

Footprints do not double count (D97): a brick's own `brick.yaml`
footprint excludes material other bricks mount into it; the mounting
brick's `docs/gm.md` states what that material adds per node, and the
GM adds it to each receiving node's `resources` in the scenario.

The renderer adds the configs to every receiving node's service, so the
material changes no image and no other brick's folder, and bumps only the
brick that ships it (D57). A fault about it targets the mounting brick's
node, names only that brick in `applies_to`, and takes the affected node
as a parameter (D92).

**Platform-neutral bricks** (D22, D42). A brick definition names no
Swarm-only feature, so the same brick runs under Kubernetes:

- seeds and secrets are read from fixed paths inside the container,
  declared in the brick, never from Swarm's default mount locations;
- the health check is a command run inside the container;
- interfaces are container ports; publishing ports on hosts is the
  renderer's business, and no brick relies on the routing mesh;
- a brick says whether it is stateful; how it gets pinned (placement
  constraints, a StatefulSet) is the renderer's business;
- peers are reached by node name only, never `tasks.<service>`;
- hardening needs (read-only root, capabilities, `sudo` wrappers) are
  declared in the brick and mapped by the renderer to each platform's
  settings.

### `docs/gm.md` must contain (D56)

The GM documentation tells the GM how to use the brick in a scenario: what
to install where, how to configure it and wire it to the other bricks, what
it costs, which faults it can host and how to check it. `brick.yaml`
declares; `docs/gm.md` explains. It holds spoilers and is never shipped to
the player side.

The rule applies from v0.2. Every brick added from v0.2 on meets it, and
the two v0.1 bricks (`postgres`, `bastion`) are brought up to it within
v0.2; that change bumps their version, to 0.1.1 (D57). The format skill
refuses a brick whose `docs/gm.md` lacks one of the required
sections, so the GM refuses to deploy a scenario that uses it (D40).

Rules for the whole file:

- One level-2 heading per required section, with the exact names below,
  in this order. A brick may add its own sections, as subsections of a
  required one or after the last.
- No required section is empty. One that does not apply says so in a
  sentence, with the reason (a brick that consumes nothing says so under
  Connections).
- It agrees with `brick.yaml`: every parameter, knob, interface or
  footprint figure it mentions matches the declaration, and it introduces
  none that `brick.yaml` lacks.
- It agrees with the catalog faults' `applies_to` (D59, D62): every fault
  it lists as supported names this brick and version in its `applies_to`,
  and every catalog fault that does is listed.
- A disagreement with either is a defect of the brick.
- Placement and connections are stated as requirements (one per node,
  on the same host as a given node, sharing a network with it), never in a
  platform's own syntax ("Platform-neutral bricks" above).

The required sections:

1. **Purpose**: what the brick is (technology, engine or tool version,
   image), the role or roles it fills in a scenario, and when the GM
   picks it.
2. **Placement**: what gets installed (a node of its own from the brick's
   image, and any companion material the GM mounts into other nodes at
   deploy, such as `prometheus`'s node-health script, D88, D89), how to
   build it, how many per scenario (one per scenario, one per node, one per
   node of a given brick), next to which node (same host as a given node,
   or any host), whether it is stateful, and which networks it joins.
3. **Configuration**: every parameter the scenario sets and every value
   the GM sets per scenario or per node at initialisation (the per-node
   values of mounted companion material included, D89), each with its
   meaning, default, valid values and where it lands (seed file, secret,
   fixed path); the knobs and their default envelopes; the secrets and seed
   files and what they must contain; and what start-up does (what is seeded
   once, what is rewritten at each start).
4. **Connections**: for each interface it provides or consumes, the bricks
   on the other side, the port and protocol, what the GM wires and where (a
   scrape target, an exporter's connection, a datasource, a dashboard), the
   account or role the other side must provide and which parameter supplies
   it, and what must exist before the wiring works; what it exposes to
   monitoring bricks (metrics endpoints, logs); and whether its image
   accepts another brick's mounted companion material, such as the
   node-health script (D89).
5. **Access**: how the player reaches it (account, group, `sudo` wrappers,
   any web interface and the path to it through the bastion), its writable
   and protected paths, the write policies it supports, the capabilities it
   adds back and why each is needed, and what the GM itself uses to operate
   it.
6. **Footprint**: the default CPU, memory and disk, limits and
   reservations, as `brick.yaml` declares them (D84);
   what makes it grow (nodes watched, scrape targets, retention, log
   volume, data size) and how the GM sizes it for the capacity check;
   what its mounted companion material adds to each node it lands on
   (D89); and the levers that shrink it.
7. **Supported faults**: the catalog fault definitions (`faults/`) whose
   `applies_to` names this brick and version (D59), and what each needs
   from it (a parameter, a peer, aging). Catalog faults only: a fault
   defined in a scenario's own `faults/` folder belongs to that scenario
   and is not listed (D62). Then the faults it lends itself to that have no
   definition yet; its known interactions (a monitoring brick that can
   mask a fault elsewhere, a fault elsewhere it would reveal); and, where
   not obvious, the faults it cannot host and why.
8. **Checks**: its validator (what it checks; it may be red from the
   start), its health check, its companion checks and when the GM runs
   them, how the GM confirms after deployment that it works and is wired
   (every scrape target up, the exporter connected), and its stack test if
   it has one.
9. **Known limits**: what it does not do, or does surprisingly, in this
   version; "none known" when so.

## Fault definition

Faults live beside the bricks rather than inside one, because a fault can
span several bricks (a collector pointed at the standby touches the
monitoring brick and the database brick).

```
faults/<fault-id>/
  fault.yaml
  inject/            material that plants the fault, when it has any
  checks/            solvability probe and sealed fix check
  gm.md              explanation the GM uses for feedback
```

### `fault.yaml` must contain

- **Identity**: id, version, title, family, severity. From v0.4, purpose
  faults are `data-flow` (duplicates, dropped records) or `rules` (a
  wrong zone, a wrong segment); governance and credential faults join
  `security`, with `governance-*` and `security-*` ids (D215).
- **Applies to**: brick ids and, for each, the brick versions the fault
  applies to, plus topology preconditions (e.g. needs a standby, needs a
  scheduled job). This is the only statement of which faults a brick
  hosts (D59). Versions are listed one by one, never as ranges (D86), so
  each brick bump adds its version to every fault that still applies.
  From v0.4, `applies_to.purposes` names the purposes a fault attaches to,
  beside `bricks:`, and a purpose fault also lists the `scheduler`
  versions its runner needs, since its sealed check runs there (D215).
- **Parameters** the scenario sets (which table, which job…).
- **Injection**: how it is planted, and at which stage. Kinds: a change
  to a node's seed configuration; a change to a parameter of the target
  node, applied when the local implementation is rendered (D92: for
  example leaving the affected node out of the node-health map, or a
  service out of its entry); a state change run in the node by the GM;
  an aging step. State changes are idempotent POSIX shell scripts
  streamed over stdin, so they run the same through `docker exec` or
  `kubectl exec` (D22). Their interface is in "Script contracts" below.
  In the format these kinds are `seed-file` (with `seed_changes`),
  `parameter` and `state`; from v0.3 only a `state` fault may be planted
  later than T0, the other two being planted at render (D151). From
  v0.4 a purpose fault is planted as these are: a `seed-file` change (a
  runner's `queries.yaml`, a script, `jobs.yaml`, a database node's data
  file, `postgresql.conf` or `crontab`), a `state` change during the
  aging, or a timeline change of a schedule for an outside party's
  behaviour, which the definition states and the scenario writes (D215).
  A data file is not a seed file of its brick: a `seed_changes` entry
  names it `data`, the target node's `data.file`, refused on a node
  without one; the scenario's copy carries the change, in place from the
  data load, before T0 (D226). A `state` fault may also carry
  `seed_changes`, in the scenario's copies from T0 as a `seed-file`
  fault's, its scripts planting the rest later (D254). From v0.6 a
  `seed_changes` item may carry **`lines:`**, optional: the literal
  lines the change puts in the scenario's copy of its `file`, `{NAME}`
  parameter placeholders allowed (as in `parameter_changes`), refused
  on `data-register.md` and `network-overview.md`, whose changes the
  answer key's diffs carry (D521). The loader checks them (O269, D510,
  D521): for each selected instance whose definition's item carries
  `lines:`, each line, its placeholders replaced from the instance's
  parameters (else their defaults), is found in the node's copy of the
  item's `file` (a folder entry: any file of the folder; `data`: the
  node's data file), a line of the copy matching when, both stripped
  and their runs of blanks made one, it equals the line or continues it
  with a comment (`#` or `--` after a blank), anywhere in the file; an
  instance whose line is missing is refused, naming the instance, the
  line and the file (v0.5's clinic lacked s2's, s7's and s8's and every
  check passed until the whole-clinic run). A change without `lines:`
  stays the GM's to read: a `change:` is prose, a `material:` an
  example, a diff or a whole file.
  From v0.5's build (chunk 36, D459), two more forms:
  - **A script run on another node**: an item of a `state` fault's
    `injection.scripts[]` is a bare path, run on the instance's node, or
    `{script: <path>, on: <parameter>}`, no other key; `<parameter>` is
    a parameter of the fault declared `required: true`, and its value in
    the scenario's instance (else its default) names a node of the
    topology whose brick, at its pinned version, the fault's
    `applies_to` names. `gmctl inject`, `inject --at` and `restart`'s
    replant stream that script to that node under the same contract as
    the instance's own scripts (the same `run_as` and `FAULT_*`
    variables), in the fault's script order; a node the game lacks is
    refused before anything runs.
  - **`injection.kind: topology`**: the fault is planted at render by
    the scenario's topology itself, valid only on a fault declaring
    `option_absent` (the instance's node must not choose that option);
    its `stage` is `seed` or absent; it has no `seed_changes`, `scripts`
    or `parameter_changes`, keeps `run_as`, and may declare
    `parameters:` for its sealed check. `gmctl inject` runs nothing for
    it (it reports "topology fault, planted at rendering by the
    topology; nothing to run"), and `inject --at` refuses it.
- **Evidence paths** as the player user. From v0.3 each evidence's
  free text is its `source`, and its `where` is `node` (the fault's
  target node), `bastion`, or `report:<tool>` for a tool the target's
  brick ships; never `ui:<name>`, whose routes only the scenario knows
  and which the answer key adds (D140, D145). And the **aging** technique
  (`real-time`, the only one from v0.3, D114) and
  minimum duration that make them visible. From v0.4, a fault whose
  evidence shows at a job's runs counts its aging minimum from that job's
  first run after planting, as v0.3's time-of-day faults do (D189, D215).
  From v0.6 (D489–D491, D498) the block gains **`aging.fake`**, the
  fault's support for fake aging; absent, the fault is not assessed and
  refused in a fake game: `support` (`supported`: the fill makes its
  state and its history draws its trail; `tail-only`: its evidence must
  be genuine and needs the tail; `real-only`: refused in a fake game),
  `reason` (one sentence), for `tail-only` `tail_minimum` and
  `tail_covers` (scenario-time instants the tail must hold), `plant_in`
  (`any` or `tail`) and `fill.emulate` (what the fill imitates). And the
  definition gains **`history:`**, its history signature, mandatory
  unless `real-only` (`- kind: none` for a fault with no Prometheus
  trail): entries of kind `queue` (the fault's effect on the shared
  queue model), `counter_per_call`, `gauge_sawtooth`, `gauge_before`,
  `daily_spike` or `remove` (which wins over every baseline and overlay
  on its series), with the fault's parameter placeholders, every number
  measured by a short real run, and `suppressed_by: [<fault id>]` to drop
  an entry from the planting of the first selected instance of a hiding
  fault onward (one planted in the tail drops nothing from the forged
  past). The loader refuses an empty
  or missing `history:` on a `supported` or `tail-only` fault, and
  `tail_minimum` or `tail_covers` elsewhere; `gmctl render --aging fake`
  refuses a `real-only` or unassessed instance, naming its reason. A
  `tail-only` or `real-only` fault's `gm.md` has a "Fake aging" note.
  Shapes: [v0.6 master spec](versions/v0.6/master-spec.md) 6.9. As built
  in v0.6's wave 3 (D580):
  - `fill.emulate` holds short kebab-case tokens (`held-snapshot`,
    `lock-wait`, `pool-queue`; `[]` when the fill imitates nothing),
    for the GM: no program reads them, the loader checks only that
    each is a non-empty string.
  - Every number of a history entry carries, on its own line, a comment
    `# measured: <source>, <what>`, `<source>` a member of the shop's
    reference (`r-dump/r.om`) or a calibration file
    (`tools/fake_aging/calibration/<file>`, "Scenario" above); the
    loader refuses unknown keys in an entry, so the trace is a comment,
    never a key. `tools/tests/test_fake_aging_faults.py` checks it on
    the covered scenarios' faults, the source existing.
  - A parameter only a history signature needs (a `{DATABASE}` or
    `{KEY}` the injection doesn't use) is added `required: false`,
    `default: null`, its description saying it is read only in a fake
    game, so the scenarios using the fault load unchanged; every
    instance of a scenario played fake sets it, its `README.md`
    regenerated with it. No loader or render check enforces it (an
    unset one leaves `None` in the selector, which matches nothing);
    `test_fake_aging_faults.py` checks the covered scenarios' instances
    resolve every placeholder.
  - A history entry's selector names series the game's exporters
    serve: the `postgres-exporter` connects to the `postgres` database
    only, so a scenario database has no `pg_stat_user_tables_*` or
    `pg_stat_user_indexes_*` series, and a `pg_*` series' `instance`
    label is the exporter's target, never the database node: an
    `instance=` or per-table selector on a `pg_*` series matches
    nothing. A dropped index's size is drawn with a `gauge_before` on
    `pg_database_size_bytes{datname=...}`, the database's size with the
    index. `- kind: none` is a signature's only entry.
  - The `gm.md` note is a paragraph opening `**Fake aging.**`, the
    note's last, after its run-in labelled paragraphs; the skills point
    to it by that label.
- **Solvability probe**: what it runs as the player user and what it
  expects. Descriptive only in v0.1; a manual play-through checks it
  (D38).
- **Possible resolutions**: which of *report*, *propose*, *fix*, *improve*
  make sense, and which write policy each needs.
- **Acceptance criteria**: what counts as a correct diagnosis and as an
  acceptable fix or improvement.
- **Sealed fix check**. From v0.4 it states `sealed_check.judges`:
  `runs`, `triggers`, or absent for a check judging the live state
  (D215).
- **Host needs** (from v0.4): `needs_unshared_host: true` when the
  fault's node must never be placed on a shared host; `gmctl fit`
  refuses a mapping that does (D209, D215).
- **Interactions**: masks, masked by, conflicts with.
- **Complaint template**: how a customer would describe it, for when the
  fault is known.

*Known* or *hidden* is not part of the definition: it is chosen per
instance, in the scenario.

## Purpose definition (from v0.4)

A purpose is a catalogue unit beside bricks, faults and scenarios: what
some of the customer's data is *for* (D190, D215). Its jobs are run by a
scheduler node or a database node; faults attach to it as to bricks.

```
purposes/<purpose-id>/
  purpose.yaml   identity, parts, jobs, trace, invariants, data moved, roles
  material/      the jobs' repository entries, transformer scripts and
                 jobs.yaml lines, the target's DDL (foreign servers and
                 procedures included), as the GM copies them into a scenario;
                 from v0.5 the DDL files `ddl:` names, which load-data reads
  checks/        one script per invariant
  gm.md          what the purpose is for, how it goes wrong, feedback notes
```

From v0.5's build (wave 4) `material/` holds one folder per part,
named for it, and two files at its root:

| Path | What | How it reaches a game |
|---|---|---|
| `runner/` (`jobs.yaml`, `queries.yaml`, `schedule.yaml`, `scripts/`) | the runner's jobs, as v0.4 | copied into the runner's seed files |
| `runner_<w>/` | a second runner's | likewise, into that runner's |
| `<part>/ddl.sql` | a database part's DDL, named by `ddl:` (`ddl: {target: material/target/ddl.sql}`) | read from the catalogue by `load-data` at step (2b) |
| `target/office.sql`, `target/data.sql` | the DDL of a database no domain holds (`office`): `office.sql` the same text in every purpose using it, `data.sql` the purpose's own tables and grants | copied into the node's data file, `office.sql` first and once |
| `history.sql` | the planted past, named by `history:` | read from the catalogue at step (4) |
| `api/<node>/` (`api.yaml`, `routes/`, `db/`) | endpoints the purpose brings to a customer's `api` node, a domain's `producers/api/<node>/` layout | copied into the scenario layer `compose/<node>/`, merged by `gmctl compose` |
| `receiver/<prefix>/`, `partner/<prefix>/` | a stub with no stream of its own, laid out as `producers/partners/<prefix>/` | its fragments into `compose/partners-api/` and `compose/partners-backend/`, its `data.sql` after the shared one in `partners-db`'s data file |

Two purposes may ship one receiver prefix (the clinic's authority, for
purposes 5 and 8): each its own table, endpoint and route, the shared
role, schema and state created guarded, in the same text in both.

`purpose.yaml` must contain:

- **Identity**: id, title, the domains it fits, its kind (pulled,
  transformed in place, pushed, pushed obligation; from v0.5 round
  trip).
- **Parts**: the roles the scenario fills with its own nodes and
  databases: `source` and `target` (databases, of one instance or two),
  `runner` (a scheduler node, role `transformer`), optionally `consumer`
  (a scheduler node reading published results) and `receiver` (a stub
  node, for a pushed obligation).
- **Jobs**: for each, its name, its repository key, its runner, its
  source and target, its movement method, what it computes in one
  sentence, its cadence in scenario time, and the customer role of each
  connection it holds.
- **Trace**: each place it leaves something, with its kind (outbox rows,
  published results, run ledger, definitions), its table or file, and
  the column that ties a row to the run that wrote it.
- **Invariants**: for each, an id, a one-sentence statement against the
  source, the check script judging it, its parameters, and its witness
  condition (what must exist in the data for a run to be able to violate
  it).
- **Data moved**: which classed columns each job reads and where it
  writes them, so governance can be checked against it.
- **Customer roles** the purpose needs, with their grants.

From v0.5 (D286, D303, D307):

- **The round-trip kind**: `kind: round-trip`, beside v0.4's four, and a
  `round_trips:` block, one entry per exchange the purpose carries (an
  exchange both ways carries two): who asks (the customer or the
  partner); the request (its job, its counterpart, what it sends); the
  correlation key (what an answer carries to name its request); the
  expected answers (each form: accepted, rejected, a result; when it
  comes; what it carries); the timeout and what follows it (resend with
  the same key, escalate); and the reactions (the processes an answer
  starts, the purpose's jobs or a domain's streams, named).
- **Two more parts**: `api`, a customer's `api` node the purpose calls or
  brings endpoints to; `partner`, a declared third party's node. A
  pushed obligation's `receiver` is a declared third party from v0.5.
- **More parts of a kind** (from v0.5's build, D431): a purpose may
  declare more database parts `source_<w>` and more runners
  `runner_<w>` (`<w>` `[a-z][a-z0-9]*`), each checked as its base part (a
  `source_<w>` a location, never a standby; a `runner_<w>` a scheduler
  node of role `transformer`, its jobs in its own `jobs.yaml`) and usable
  wherever the base is (`jobs[].source` and `target`, `jobs[].part`,
  `roles[].part`, `trace[].part`, `data_moved.writes`, `ddl:` keys). A
  runner none of whose jobs the purpose runs needs no `jobs.yaml`; a job
  with no `part` is `runner`'s. A report job reading a standby keeps its
  part on the primary (a standby is no location), its scheduler
  connection targeting the standby.
- **A `pg_cron` job on a database part** (from v0.5's build, D431): a job
  of `method: pg_cron` names as its `part` the database part it runs in,
  is in no runner's `jobs.yaml` and is scheduled by that part's own
  `ddl:` file (`cron.schedule_in_database(…, current_database(), <role>)`,
  the node's seed preloading pg_cron with `cron.database_name` that
  database); its `key` is the pg_cron job name. The loader refuses a
  `pg_cron` job naming a runner, any other job naming a database part,
  a `pg_cron` job whose part has no `ddl:`, and a runner declared beside
  `pg_cron` jobs only (`parts.runner` is then left out).
- **HTTP connections** in a job's `connections:`, named for the part
  they reach (the scheduler's HTTP driver), each mapped to the HTTP
  credential it calls with, or `public` for a public endpoint, where its
  scheduler connection has no `credential` (D354). A part reached under
  several hostnames (the clinic's three centres) takes one connection per
  hostname, `<part>_<w>` (`partner_central`, matching
  `^(api|partner|receiver)(_[a-z][a-z0-9]*)?$`), each checked exactly as
  its part (D438).
- **Endpoint material**: `material/api/<node>/routes/` and `db/` for the
  endpoints a purpose brings to a customer's `api` node, the layout of a
  domain's `producers/api/`, with its `api.yaml` (from v0.5's build,
  D438: optional, keys within the brick's, its endpoints and the stems
  of `routes/` matching exactly; anything else in the folder refused as
  "not endpoint material"). A receiver with no stream of its own (an
  authority, a head office) keeps its stub in the purpose, as v0.4's
  `receiver/` does; a partner with streams of its own stays in its
  domain's `producers/partners/`.
- **Periodic purposes** (weekly, monthly, yearly reports): a periodic
  job names its daily feeder, the witness within the aging;
  `material/history.sql` plants the past periods' outputs into the
  target before T0. A target belonging to no domain (the clinic's
  `office`) is planted by the purpose: `history:` in `purpose.yaml`
  names the file, and `load-data` runs it, in a scenario with
  `domains:`, in the `target` location the scenario maps, after the domains' loads and the derivations, the
  `purposes:` entries in list order, as the superuser, reading the
  entry's other mapped locations through foreign schemas
  (`gm_src_source`; "Loading a composed domain" below) it drops
  afterwards, every session unseen (no statement logging,
  `pg_stat_statements` and pgaudit off). A purpose whose periodic
  jobs name a feeder needs a `history:`; one with no feeder may carry
  a history too (purposes 14 and 16: a past no periodic job extends),
  a file under `material/`. A history
  may target the partners' database (D366, D404): it then runs on the
  partners' node, in `partners`, reading its other parts over TCP; one
  reading the partners' database from another node is refused (D383).
  No periodic report runs on demand in v0.5. A history reads every
  mapped database part but `target`, each as `gm_src_<part>`
  (`gm_src_source_lab`), and plants exactly what the periodic jobs would
  have written before `load_epoch` (a feeder's day `d` when `d + 1` at its
  hour is past, a close when its date at its hour is), each period with
  its run row and, where the partner answered, a reference in the form
  the partner's stub gives live (D451).
- **Calendar-gated cadences** (from v0.5's build, D436): the scheduler's
  cron subset takes no day of month or month, and a day of week only
  with a single-number hour, a range written as a list (`0 16 * * 1,2,3,4,5`).
  So a monthly or yearly job runs daily at its hour (`0 3 * * *`) and
  acts only when the customer's local date, read from its source, is its
  day (the 1st; the 1st to the 5th; 15 January), writing neither output
  nor run row otherwise; a windowed job (08:00–19:00, Monday to
  Saturday) runs `*/15 * * * *` and returns at once outside its window.
  `computes:` and `gm.md` state the calendar.
- **The DDL a purpose adds to a domain's database**, `ddl:` (from
  v0.5's build), beside `history:`: a non-empty map from a database part
  the purpose declares (`source`, `target`) to a file under `material/`
  (`ddl: {target: material/target-ddl.sql}`), one key per database the
  purpose adds tables to (its `ops` schema, below). Read from the
  catalogue at every load, as the history is, never copied into the
  scenario. Only for a part the scenario maps to a database a
  `domains:` entry's `at:` holds: the loader and `load-data` refuse a
  `ddl:` part mapped to a database no domain holds (`office`,
  `partners`), whose DDL stays in the node's data file, one place each,
  never both. `load-data` runs each file at step (2b) of the composed
  load ("Loading a composed domain" below), as `postgres` connected to
  the mapped database, unseen, with every `psql` variable and no key
  functions; like a domain's schema it never creates a database nor
  `\connect`s (refused, naming the line), names its database
  `:"DBNAME"` and creates its roles at top level. Roles are
  cluster-wide: a role two purposes' DDL create on one node is created
  guarded (`DO … IF NOT EXISTS`), the purpose material's concern, which
  the loader does not police. The loader counts the roles and objects a
  `ddl:` file creates on its node, a guarded `CREATE ROLE` counted when
  it starts its own line inside the `DO` block, so render gives its
  login roles their secrets and the placement and `crontab_roles`
  checks see them.
- **How an invariant is judged**: `judged:`, one of `runs`, `triggers`,
  `end-to-end` (on the trace after the fix, wherever the player fixed
  it; a symptom fixed alone earns nothing; the backlog the fault left is
  a consequence the answer key lists, never the purpose), `code` (the
  sealed check reading the job's code) or `definition`. A purpose names
  one `end-to-end` invariant per `round_trips:` entry, so one carrying
  an exchange both ways names two (D440). An invariant's id is one or
  two capitals and a number (`R1`, `LO1`, `MS6`: `^[A-Z]{1,2}[0-9]+$`,
  D438). As built, a `code` check runs the job's loaded SQL on the last
  planted period and compares its output with the check's own rule; the
  planted figures are not judged (D454).
- **Data moved** keys (from v0.5's build, D438): `data_moved[].reads`
  in the scenario's classification-key form, three or four parts
  (`clinic.owners.name`, `clinic.ops.notifications.payload`).
- **The classes of the tables it brings**: a purpose whose target
  belongs to no domain, or which adds tables to a domain's database,
  classes their columns in its own `classification:` entry, as a domain
  does, so governance reads them.
- **The `ops` schema**: a purpose's own tables in a domain's database
  (its ledgers, incidents, watermarks) live in a schema `ops`, never in
  `public`, where the domains' tables live; a target belonging to no
  domain keeps them in `public`. Every run writes one `ops.runs` row (or
  the target's `runs`) in the same transaction as its output. In a
  scenario with `domains:`, the loader checks that every `trace` table
  on a database part mapped to a `domains:` entry's `at:` is in schema
  `ops`; the domain tables a purpose writes appear in its `data_moved`
  and `gm.md`, never in its `trace:`.
- **The `ops` block** (from v0.5's build, W4): every `ddl:` file writing
  a domain database carries one text, between the lines `-- ops: begin`
  and `-- ops: end`, byte-identical across the purposes (a unit test
  compares them): the role `ops` (`NOLOGIN`) created guarded, the schema
  `ops` it owns, `PUBLIC` revoked, and as `ops` the tables
  `ops.runs (id, purpose, job, started_at, finished_at, rows_read,
  rows_written)`, `ops.incidents (id, purpose, job, kind, ref, opened_at,
  reason, run_id)` and `ops.watermarks (purpose, name, at, last_id,
  run_id)`, each `CREATE … IF NOT EXISTS`, so any subset of purposes
  loads alike. `ref` names an id, never a name; no unique constraint on
  incidents ("one incident each" is the jobs' care and the checks'
  judgement). Each purpose's DDL inserts its own watermarks at
  `:'load_epoch'` (`ON CONFLICT DO NOTHING`), grants each of its roles
  `USAGE` on `ops`, `SELECT, INSERT` on `ops.runs` and `ops.incidents`,
  `SELECT, INSERT, UPDATE` on `ops.watermarks`, and creates its own `ops`
  tables owned by `ops`, each with `run_id bigint NOT NULL REFERENCES
  ops.runs (id)`. A run writes its domain rows, then its `ops.runs` row
  with final counts, then the rows naming it; a job writing two
  databases writes a run row in each, with the same `job` and
  `started_at`. The purposes' login roles are created guarded at top
  level of their own line in the `DO` block, `CONNECT` granted by name;
  a purpose's DDL never creates nor alters a role a domain creates, only
  grants to it. `office`'s `office.sql` (the same text in every purpose
  using `office`) creates the database, `office`, `office_jobs` and
  `office_reader` and `runs` (the same columns, in `public`).
- **The checks** (from v0.5's build): as v0.4, on the runner node, the
  runs from `check-runs` and the databases through `check-sql` as
  `gm_check` (which prints a boolean as `True` or `False`); a check
  needing a partner's side runs on the partners' database node
  (`check-psql`, the customer's databases through `check-psql --node`),
  in shell with its verdict in SQL, since a `postgres` node has no
  Python. A check reading a table with row-level security first finds
  `gm_check_read` on it and no `RESTRICTIVE` policy for `public` or
  `gm_check`, else exits 2 (D432).

The GM copies a purpose's material into the scenario at design time, as
it writes a scheduler's repository: the jobs into the runner's
`queries.yaml`, `scripts/` and `jobs.yaml`, the target's DDL into the
target node's data file. Its `history` and `ddl:` files are the
exception: from v0.5 `load-data` reads them from the catalogue
(`purposes/<id>/`, the paths `history:` and `ddl:` name) at every load,
never from the scenario folder. The
scenario folder stays self-sufficient with the full repository (D23),
and `purposes:` names the purpose for provenance and for the faults
attached to it.

## Domain (from v0.4; composed domains from v0.5)

A domain is a reusable catalogue unit of a business: its data model, its
producer material, its classification, its governance, its GM notes; the
shop is the first (D192, D215), the veterinary clinic's six the next
(D292). What a domain holds and leaves out, and how one is defined, is
the [domain procedure](versions/v0.5/domain-procedure.md) (D260). This
section is the format: v0.4's part, and from v0.5 what composing
domains adds (O111, closed by v0.5's master spec: D249, D263, D264,
D276, D301, D303, D322, D323, D326, D334). The v0.5 additions are built
in v0.5's domain-format chunk, the `scenario-format` skill's templates
and checks and the loader's `check_domain_dir` with them; until then the
skill carries v0.4's shape.

```
domains/<domain-id>/
  domain.yaml               identity, the parts below, the purposes that fit
  data/
    schema.sql              the business tables, roles and grants
    load.sql                the generated history ("last night's backup")
    <database>/schema.sql   from v0.5, a part with several databases: one folder per
    <database>/load.sql       database, in place of the two files above
    derive.sql              from v0.5, optional: a derivation step the GM may sanction
    keys.sql                from v0.5, optional: a core's key functions (pg_temp.core_*),
                              or a part's own (pg_temp.<its prefix>_*)
    cron.sql                from v0.5, optional: the domain's pg_cron jobs
    coherence.yaml          from v0.5, optional: the post-load coherence queries
    classification.yaml     every classed column
    register.yaml           from v0.5: the register fragment, one entry per activity
    governance.yaml         from v0.5, optional: the business's own rules (ruled, D339)
  producers/                the business's producer fragments
    <node>/                 from v0.5 (D344): the fragments for the scheduler node of that
                              name (queries.yaml, schedule.yaml, jobs.yaml, builders/)
    api/<node>/             from v0.5: an `api` node the domain owns: its api.yaml
                              fragment (D345), routes/ (the endpoints), db/ (their
                              database side)
    partners/<prefix>/      from v0.5: a partner's back-end fragments, its api.yaml,
                              routes/ and db/, and optionally data.sql, its tables and
                              state in the partners' database
  variants/
    <variant>.yaml          from v0.5: a variant's manifest (a part: its own axes)
    <variant>/producers/    from v0.5, optional: the variant's profile, overrides only,
                              laid out as producers/
  docs/gm.md                the business, its rules, its traps
  docs/policy.md            from v0.5, optional: the business's default data policy
```

A domain carries no version and never bumps ("Versions and pins"
below); a static scenario needs none. In the one-domain form
(`domain: <id>`, v0.4's shop) it is a design-time source: the GM copies
its files into the scenario, adapting them, its data into the database
node's data file. A composed domain (`domains:`, from v0.5) is copied
in part only: `gmctl compose` writes its producer fragments into the
scenario folder, and the GM copies its classification (each key given
its database), its default policy and its `governance:` fragment; its
data files (`schema.sql`, `load.sql`, `keys.sql`, `derive.sql`,
`cron.sql`, each partner's `data.sql`, `coherence.yaml`) are never copied: `load-data`
reads them from the catalogue the scenario is loaded against
(`domains/<id>/`) at every load, as the scripts read a fault definition
("Loading a composed domain" below). The scenario folder stays
self-sufficient with the full repository (D23).

### `domain.yaml` must contain

- **Identity**: `id`, the folder's name; `title`; no `version`.
- **Its files**: `schema`, `load`, `classification`, `producers`,
  `notes`, each a path that exists (`producers` a folder); from v0.5
  `register` (`data/register.yaml`), required of every domain, and,
  optional, `policy` (`docs/policy.md`) with its `governance` fragment;
  from v0.6 `overview` (`data/overview.yaml`), required of every domain
  (D487): `roles:`, each login role its schema creates (`role`, `who`,
  `reads`, `writes`), and `jobs:`, each producer job and `pg_cron` job
  (`job`, `what`), every one described (a checklist item, checked by
  the loader). The keys' measured service times for fake aging's queue
  model sit beside the `queries.yaml` that defines them (D498).
- **`purposes`**: the ids of the purposes that fit (may be `[]`; each id's
  form is checked, not that the purpose exists yet).
- From v0.5, for a composite's part:
  - **`requires: [<core>]`**: the core it is taken with. One level only:
    a part requires a core, never another part. A core has none, and
    may be taken alone; a part never without its core.
  - **`lands_with: <core>`**, optional: the part's schema must land in
    its core's database; the loader refuses a scenario whose `at:` puts
    it elsewhere (`vet-housing`, whose displays' board read joins its
    units to the core's board in one statement).
  - **`databases: [<name>, ...]`**, optional (ruled, D339): a part
    with several databases names them; its folder then holds
    `data/<database>/schema.sql` and `load.sql` for each, in place of
    `schema` and `load` (`vet-machinery`'s `pacs`, `vitals`, `biomed`).
  - **`derive: {after: [<domain>, ...]}`**, optional: the part ships
    `data/derive.sql`, run only when the scenario's composition record
    sanctions it, after the loads it names.

### The data, the classification and the rules

- `schema.sql` and `load.sql` follow the data load's contract ("Script
  contracts" below); a part's run after its core's, in the same
  database or another. `load.sql` may read the two `psql` variables
  `:'customer_timezone'` and `:customer_utc_offset`, and from v0.5
  `:'load_epoch'`. A composed domain's files follow "Loading a composed
  domain" below: they never create their database.
- **Composition rules** (D249, D322), fixed for every domain:
  - a part never redefines its core's tables;
  - a part refers to a core key by its id, **without a foreign key** to
    the core, as separate systems do, so its schema runs in the core's
    database or in an instance of its own; integrity across them is an
    invariant, and an orphan a fault vector;
  - **deterministic keys**: the core's load generates its keys in
    documented ranges and functions, and a part's load **computes** the
    core keys it uses from them; it never reads the core at load;
  - **prefixes**: a part's tables, roles, query keys, connection names
    and shape names carry its prefix (`lab_results`, `lab_app`,
    `lab.batch.upload`, connection `lab`, shape `lab-runs`), so parts
    never clash in one database or one node; a partner's prefix is its
    folder's name ("Producer material" below);
  - a site is a core entity, so one database may hold several sites'
    rows; the exchange with another site is a round trip, outside the
    domain.
- **`classification.yaml`** classes every column, under `columns:`, each
  `personal`, `customer-linked` or `internal`; a column with no entry is
  `internal`, and a domain lists every column of its tables, `internal`
  ones included. From v0.5 a domain keys its columns `<table>.<column>`
  (the table in schema `public`, or `<schema>.<table>.<column>` for
  another), without the database: the scenario's copy adds each table's
  database, `<database>.<table>.<column>`, as the shop's v0.4 scenario
  already keys its own copy. A part with several databases keeps its
  keys unique across the part, the copy adding each table's database.
  The shop's file is rewritten mechanically.
- **The business's own rules** (from v0.5, optional): a regulated
  business's rules (a medicines register kept, results released only
  once validated) are the business's, not a scenario's choice. A domain
  may carry them as a default policy, `docs/policy.md`, and a
  `governance:` fragment, which the GM copies into the scenario's
  `player/data-policy.md` and `governance:`, adapting them. Each rule's
  game values (retention periods, deadlines) are stated as such.
- **The register fragment** (from v0.5, D334), `data/register.yaml`:
  one entry per **processing activity** of the domain, with its stable
  id (`core-owners`), name, purpose, the people concerned, its tables,
  and its retention (the period, then erased or anonymised), transcribed
  from the domain's classification and rules. Every table of the domain
  belongs to exactly one activity. The GM's `data-register` skill reads
  the fragments to generate a scenario's register ("Scenario" above).

### Loading a composed domain (from v0.5)

`load-data` loads every `domains:` entry from the catalogue ("Domain"
above), as `postgres`:

- **The database convention**: `load-data` creates each `at:` database
  absent from its node (owner `postgres`, `CONNECT` revoked from
  `PUBLIC`) and runs the domain's `schema.sql`, then its `load.sql`,
  connected to it (`psql -d <database>`; a several-database part's in
  `databases` order). So a domain's schema and load **never create a
  database nor `\connect`** to one (`load-data` refuses either before
  anything runs, naming the line), create their roles at top level, and
  name their database as psql's `:"DBNAME"` (`GRANT CONNECT ON DATABASE
  :"DBNAME" TO vet_app`): a part lands in its core's database or its
  own, so the name is the scenario's. The shop's v0.4 schema (`CREATE
  DATABASE shop`) stays as built for `domain: shop`, which no composed
  scenario uses. A contrib extension a schema creates (`btree_gist`,
  `pgcrypto`) is a plain `CREATE EXTENSION`.
- **One reference moment**: every file `load-data` runs, a node's data
  file included, gets beside `customer_timezone` and
  `customer_utc_offset` the variable `load_epoch`, the run's start in UTC
  to the minute (`2026-11-04T10:00Z`). A load's "now" is
  `:'load_epoch'::timestamptz`, never `now()`, so parts loaded minutes
  apart agree.
- **The core's key functions**, `data/keys.sql`, optional, a core's (a
  fixed path, no `domain.yaml` key): function definitions in `pg_temp`
  only, the keys its parts rely on as `pg_temp.core_<name>(…)` and, as
  built, its helpers under a prefix of the core's own (vet-core's
  `pg_temp.vc_*`), which a part calls only where the core's notes name
  one for it (vet-scheduling's `vc_agenda`). `load-data` streams the file
  ahead of the core's `load.sql`, each of its parts' `load.sql`, each
  partner `data.sql` and each `derive.sql` of the core and its parts, in
  the same session. Called schema-qualified, the functions vanish with
  the session, so nothing reaches the catalog the players read. The
  core's GM notes list each function a part relies on ("Core keys",
  below); the loader does not read a core's file.
- **A part's key functions** (from v0.5's build), its own
  `data/keys.sql`, optional, the same fixed path: `CREATE [OR REPLACE]
  FUNCTION pg_temp.<prefix>_<name>(` definitions only, under one prefix,
  the part's own (vet-lab's `lab_`, vet-portal's `portal_`); a part's
  function may call the core's. `load-data` streams it after the core's
  file, in the same session, ahead of the part's `load.sql`, its partner
  `data.sql` files and its `derive.sql`. `check_domain_dir` refuses, in
  a part's file, a `CREATE` at the start of a line that is no such
  definition, more than one prefix, the prefix `core`, or a prefix the
  core's `keys.sql` uses (vet-core's `core`, `vc`). Neither file is ever
  streamed ahead of a `schema.sql`, a `cron.sql`, another domain's file,
  a purpose's DDL or a history.
- **A partner's state**, `producers/partners/<prefix>/data.sql`,
  optional, beside the partner's fragments: run into the partners'
  database `partners`, on the one `postgres` node the `third_parties:`
  entries list, after its domain's own load, the domain's partner
  folders in name order, the core's keys and the part's ahead. It
  creates the role `<prefix>` (`LOGIN`, no password: render's secret,
  set by `load-data`), the schema `<prefix>` it owns, the partner's tables and
  its planted state; like a schema, it never creates a database nor
  `\connect`s, naming its database `:"DBNAME"` (`load-data` refuses
  either, naming the line). A scenario composing a domain with one needs
  that `postgres` node (refused otherwise, naming the folder), unless
  `composition.yaml`'s `left_out:` names the partner's folder ("Composing
  domains" below): with no partners' database a left-out partner's
  `data.sql` is skipped; with one it runs as any other, and its roles
  count among the node's. Only `producers/partners/` holds one: `producers/public/` never holds a
  `data.sql`, which `load-data` never runs (D369; the loader refuses one
  from v0.5's chunk 17, the bastion and the data register).
- **A domain's `pg_cron` jobs** (from v0.5's build, D405),
  `data/cron.sql`, optional (a fixed path, no `domain.yaml` key):
  `SELECT cron.schedule_in_database(…)` calls only, at least one, each
  job naming its database and its role as written (no variable names
  them: the file runs in `cron.database_name`, not in the job's
  database), so a scenario's `at:` must name the domain's databases as
  the file does (`vitals`, `biomed`, `portal`). From v0.5's chunk 17
  (D433) the loader checks it before anything runs: each statement's
  database (the fourth positional argument, or the one named
  `database`) must be a single-quoted literal (`check_domain_dir` refuses
  anything else, naming the line), and a scenario whose entry's `at:`
  does not place that database on the domain's node is refused, naming
  the file, the line, the job and the database. pg_cron refuses a job for a
  missing database, a missing role, a role without `LOGIN` or one
  without `CONNECT` on the database, and a node's data file runs before
  a domain's databases and roles exist; so the file runs last of its
  domain's load, after its partner files, as `postgres` on the domain's
  node, connected to the node's `cron.database_name` (read from its seed
  `postgresql.conf`, `postgres` when unset), unseen, with no key
  functions; and the domain's schema creates each job's role with
  `LOGIN` and grants it `CONNECT` on the job's database, which
  `load-data` revokes from `PUBLIC`. The jobs survive step (6)'s
  `pg_cron` clean-up, which never touches `cron.job`. Refused, by the
  loader and `load-data`: a domain shipping one whose `at:` spans
  several nodes, a node whose seed does not preload pg_cron, a node
  whose data file does not create the extension (the loader only), and
  any statement but those calls (with `check_domain_dir`).
- **Unseen**: every session of the composed load runs unseen (statement
  and temporary-file logging, pgaudit and `pg_stat_statements` off), as
  a derivation's and a history's do; a node's data file is not.
- **The order**: (1) the nodes' data files, as in v0.4, creating the
  databases no domain holds (`office`, `partners`); (2) the domains, in
  `composition.yaml`'s `order`: each database's `schema.sql`, then its
  `load.sql`, then the domain's partners' `data.sql`, then its
  `cron.sql`; (2b) each `purposes:` entry's `ddl:` files ("Purpose
  definition" above), the entries in list order, each entry's parts in
  the order its `purpose.yaml`'s `parts:` lists them, since a derivation
  or a history may write into the purpose's `ops` tables; (2c) the GM's
  read policy (below); (3) the sanctioned derivations, in `derive` order; (4) each `purposes:`
  entry's history, in list order; (5) the coherence check ("Composing domains" below);
  (6) v0.4's passwords, survey, mappings, grants and `pg_cron` clean-up;
  (7) each standby's clone, last. Every step skips standbys.
- **The GM's read policy** (from v0.5's build, D432): at step (2c), in
  every database a `domains:` entry's `at:` holds, as `postgres`,
  unseen, on every table (`relkind` `r` or `p`) outside `pg_catalog`,
  `information_schema` and `gm_src_*` with row-level security,
  `load-data` replaces `gm_check_read`, `AS PERMISSIVE FOR SELECT TO
  gm_check USING (true)`, commented "the game master's read access: DO
  NOT TAMPER", and prints, per database, `<node>/<db>: gm_check may read
  every row of <n> table(s) with row security (policy gm_check_read)`.
  So the derivations, histories and checks reading as `gm_check` see
  every row; the players see the policies in `pg_policies`, listed in
  `postgres`' player notes. A database of a node's data file is the data
  file's to cover.
- **Reading another database**: a derivation, a history and a coherence
  query read their sources through foreign schemas `load-data` creates
  for the session (`postgres_fdw`, as the GM check role) and drops
  after: `gm_src_<name>` for a source's `public`, `gm_src_<name>_<s>` for
  each other schema `<s>`. `<name>` is a domain id with `-` read as `_`
  (`vet_core`), `<id>_<database>` for a several-database part, `partners`
  for the partners' database, or a purpose part's name (`source`,
  `source_lab`). The
  partners' database is read only from its own node: a derivation or
  history reading it from another node is refused (D383).
- **Reserved names**: `pg_temp.core_*` functions are the core's, as is
  any other prefix its `keys.sql` uses;
  `gm_src_*` schemas and servers are `load-data`'s; `partners` names the
  partners' database, never a domain id (the loader refuses one).

### Producer material

- `producers/` holds `queries.yaml`, `schedule.yaml` and `jobs.yaml`
  fragments of the business's applications, which parse as fragments,
  every statement running as its role, and the builders they use. From
  v0.5 (D344) they sit in **`producers/<node>/`**, one folder per
  scheduler node they target (`producers/<node>/builders/`), so a domain
  feeding two nodes (`vet-housing`: `pms` and `ward`) says which
  fragment goes where; `api`, `partners` and `public` are reserved
  names. The shop's sit in `producers/producer/`, its v0.4 scenario's
  node. A fragment is readable: it carries no timeline, no intensity
  and no planted fault, which are the scenario's (D276). Its rates are the variant's throughput at intensity 1.0, in
  real-world rates; its values come from SQL and the domain's builders.
  One producer node per application (D276); every site of a variant is
  in the customer's zone in v0.5 (D276).
- From v0.5 (D303): **`producers/api/<node>/`** holds the endpoints of an
  `api` node the domain owns, its `api.yaml` fragment (D345), `routes/`
  and `db/` (the `api` brick's layout); **`producers/partners/<prefix>/`**
  a partner's back-end fragments at its root, merged onto the back end
  every partner of a scenario shares, and its `api.yaml`, `routes/` and
  `db/`, merged onto the partners' `api` node, and optionally its
  `data.sql` ("Loading a composed domain" above), which the merge
  skips. **The folder's name is the partner's prefix**,
  `[a-z][a-z0-9]{0,15}` (checked), with neither `_` nor `-`: its role
  and its schema in the partners' database (its tables
  `<prefix>.<table>`), its keys `<prefix>.<…>`, its endpoints
  `<prefix>_<…>` and its connections `<prefix>-<…>` (`xlab`, serving the
  hostname `northfield-lab`; `practices`). One folder may serve several
  hostnames. A partner's misbehaviour (an outage, a lost or duplicated
  callback) comes with its fault's material, never the domain's: the
  domain's partner brings its state table `<prefix>.state` (in its
  `data.sql`) and its baseline stream `<prefix>.normal`, a fault its key
  `<prefix>.<behaviour>` ([partners/README.md](../partners/README.md),
  "A partner on the shared nodes").
- **A traffic source that is no business** (from v0.5, D323), standing
  for the public (the portal's owners' browsers): out of the players'
  reach as a partner is, it takes `producers/partners/<name>/` with no
  `partners.md` entry, no contract and no misbehaviour keys (no
  `<name>.state`, no `<name>.normal`). The owners' traffic is
  `producers/partners/owners/` (D369): role and schema `owners`, keeping
  its record of visits in the partners' database, whose tables its
  `data.sql` creates; `owners` is also its hostname, reserved (never a node's
  name, a `third_parties:` id or hostname). `public` stays a reserved
  folder name; no v0.5 folder uses `producers/public/`, and it never
  holds a `data.sql` (D369).
- **The merge** (D264): a node's fragments are merged at design time by
  **`gmctl compose`**, which writes ordinary files into the scenario
  folder. Layers, lowest first: the domain's default profile, the
  variant's profile (`variants/<variant>/producers/`, overrides only),
  the scenario's own layer, `compose/<node>/` in the scenario folder,
  kept apart from `nodes/<node>/` so a rerun reproduces the output: one
  folder per scheduler or `api` node `scenario.yaml` lists, holding the
  material the GM adds (the purposes', cold storage's) in that node's
  files (`queries.yaml`, `schedule.yaml`, `jobs.yaml`, `builders/`,
  `scripts/`; `api.yaml`, `routes/`, `db/`) and each scheduler node's
  `intensity` and `timeline`, which a fragment never carries. A higher
  layer wins silently and the merge report records every override;
  identical entries merge silently; a conflict between two profiles
  (two parts on one node) stops the merge and names both sides, the GM
  writing its resolution into the scenario's `merge.yaml`, so the merge
  is reproducible. Every output entry carries
  a provenance comment (`# from vet-lab@regional-franchise`). The loader
  refuses duplicate keys in the merge's inputs. A producer folder
  `composition.yaml`'s `left_out:` names ("Composing domains" below) is
  merged from in neither the domain's layer nor the variant's, and
  needs no node of its name.

### Variants, scale and tags (D263)

- **Scale**, on three axes: `population` (how many entities: sites,
  customers, animals, staff), `history` (how far back the backup goes,
  so the data's volume) and `throughput` (the traffic, in real-world
  rates at intensity 1.0). Large setups show through structure, not
  volume: "schemas simple, tables small" holds at every scale.
- **A variant**, `variants/<variant>.yaml`, is a short manifest, never a
  copy of the domain: the parts it takes, its three axes, the purposes
  that fit it, its tags. Data that genuinely differs between setups is a
  part, not a variant.
- **A part's own scale** (D301): a part writes its axes in a manifest of
  the core variant's name (`vet-lab/variants/regional-franchise.yaml`);
  the loader checks that the core's variant names the part.
- **Tags**, from a fixed vocabulary only: maturity `homebrewed`,
  `managed`, `industrial`; reach `local`, `regional`, `national`,
  `global`; traits `regulated`, `multi-site`, `24/7`, `seasonal`. A
  topology fragment carrying the same tags holds what is deployed; the
  IT maturity itself stays out of the domain.
- v0.5 builds one variant per domain: the shop's present setup, and the
  clinic's `regional-franchise`.

### `docs/gm.md` must contain

The sections: the business, the data, the roles, the classification,
the producer, the rules, the traps, loading. From v0.5:

- **"Core keys used"**, for a part: the core's ranges and functions it
  relies on, by the names the core's notes give them; a core documents
  every range and function a part needs (the clinic's: requests,
  consultations and stays as functions of their id; the staff layout;
  species, deaths and infectious alerts by id) in a **"Core keys"**
  section: its ranges, then each function of its `data/keys.sql` a part
  relies on, as `pg_temp.core_<name>(…)` (or a helper it names for one
  part, `pg_temp.vc_agenda`), with its arguments, what it returns and its
  formula. A part with its own `data/keys.sql` describes its functions
  in its notes likewise.
- **Each producer's growth an hour** at intensity 1.0, in rows and
  megabytes, and, for each data type shipped to cold storage, its
  retention on site and the consumers it waits for (D297, D298).
- **The traps**: the places a fault can bite, each with its class
  (dramatic, on the verge, optimisation or minor friction; D290), never
  fault definitions; a scenario's faults are the GM's to select at
  deploy (D309).

### Composing domains (from v0.5, D322, D326)

A scenario names its domains in `scenario.yaml` ("Scenario" above):

```yaml
domains:
  - id: vet-core
    variant: regional-franchise          # beside the core (D339)
    at: records/clinic                   # node/database the schema lands in
  - id: vet-lab
    at: lab/lab                          # an instance of its own: keys fed by a purpose
  - id: vet-machinery
    at: {pacs: machines/pacs, vitals: machines/vitals, biomed: machines/biomed}
```

`domain: <id>` stays accepted as the one-domain form (v0.4's scenario).
`at:` is a `node/database`, or for a part with several databases a map
from each of its databases to a `node/database`. The loader checks that
each id is a domain, that every core a part `requires` is listed, that
a `lands_with` part shares its core's `at:`, that the scenario's parts
are its core variant's, and that no `at:` names a standby; `load-data`
creates each `at:` database absent from its node and revokes `CONNECT`
from `PUBLIC` on it ("Loading a composed domain" above).

**Who decides what.** The format fixes the rules above, the placement
constraints a domain may declare, the composition record's fields and
the loader's checks. The domain declares the core keys it relies on,
its placement constraints, its databases, its producer fragments and
the nodes they target, its scale per variant, the purposes it fits, and
a derivation step when it needs one. The GM adjudicates, at composition,
and records: placement within the constraints; the key feeding when a
part sits apart from its core (the purpose or transformer that feeds
them, whose orphans are then a fault vector); colliding producer
profiles (`merge.yaml`); which cross-part purposes run (a purpose
fitting several domains runs only when all are composed); the initial
load's coherence; capacity, by `gmctl fit` on the composed topology.

**The initial load.** When it composes domains, the GM checks and
records: the id ranges and functions each part relies on, against what
the core documents in the catalogue the scenario is loaded against; the combined
scale, the parts' populations and histories against the core variant's;
the load order where it matters (a part's load needs only its core's
schema in the same database; a derivation step runs after the loads it
reads); and **a post-load coherence check**, run once on the loaded
system, before any fault is planted: every part's references resolve in
its core (no animal, stay, request or staff id beyond what the core
holds), and the histories agree (for the clinic: placements on real
stays and every current stay placed, monitoring sessions on stays,
published documents matching signed consultations, released results
and ended stays). **A failure there is a design error, caught before
the hand-over, never a fault**: the GM fixes the composition (a range,
a function, a scale) and reloads. Faults planted against the same
relations are planted after the check, from the answer key.

**The coherence queries**, a domain's optional `data/coherence.yaml`,
are that check; `load-data` refuses a malformed file before any query
runs (`check_domain_dir` does not read it in v0.5):

```yaml
checks:                           # non-empty; no other top-level key
  - id: stays-placed              # [a-z][a-z0-9-]*, once in the domain
    what: every current stay placed in a unit   # one line, the report's
    database: pacs                # a several-database part's only, required there unless
                                  #   the check reads partners; refused on one that does
    reads: [vet-core]             # optional: composed domains (this one included) or partners
    sql: |                        # one SELECT or WITH query: the offending rows, none when coherent
      SELECT s.id AS stay_id FROM gm_src_vet_core.stays s ...
```

A part carries its references to its core and the histories it shares;
the core carries none. `sql` is one query, no `;` but a trailing one
and no psql meta-command, its `reads` reached through `gm_src_<name>`
("Loading a composed domain" above); a name in `reads` that is no
catalogue domain is refused. Each check runs once, after the
histories, as `postgres` in the domain's database (its `database:` for
a several-database part), in a read-only transaction, unseen; a check
whose `reads` names `partners` runs in the partners' database on the
partners' node instead, so every table it reads goes through
`gm_src_*`, its own domain's too (named in `reads`) (D383). A check
reading a catalogue domain the scenario does not compose, or
`partners` in a game with no partners' database, is skipped and
reported so. Any row fails the setup, naming the domain, the check,
its `what`, the row count and the first ten rows. The result is
recorded twice: `coherence: {run_at, result}` rewritten by `load-data`
in `composition.yaml` (that key only, every other line kept byte for
byte), and each check's outcome in the game's `state.yaml`; a failing
check is recorded `result: fail` before the setup fails. Both records
are setup state, read by nothing at design time: the data register's
digest of `composition.yaml` leaves the `coherence:` key and the lines
indented under it out ("Scenario" above, D465), and the scenario
document never shows the result (D468); its Composition section says
only that the check runs at every setup and where its result is
recorded, so a setup never makes the register or the document stale.

**The derivation step.** Where formulas would be unreasonably costly,
the GM may sanction an ordered post-load step deriving a part's history
from its loaded sources: `data/derive.sql`, run as `postgres` in its
part's database after every load it reads (its `derive.after`), the
core's keys streamed ahead, reading them through foreign schemas it
drops afterwards ("Loading a composed domain" above), its sessions
unseen (no statement logging, `pg_stat_statements` and pgaudit off). A
several-database part takes none. It derives content only, never
keys the part's own load could compute. The clinic's one case is
`vet-portal`, whose documents copy the record field by field.

**The composition record**, `composition.yaml`, beside `merge.yaml` in
the scenario folder, written by the GM and kept with the scenario, so
the composition is reproducible (D23); the loader checks it against
`scenario.yaml`'s `domains:`:

```yaml
domains:            # as scenario.yaml lists them, with the constraints checked
  - {id: vet-core, variant: regional-franchise, at: records/clinic}
  - {id: vet-housing, at: records/clinic, lands_with: vet-core}
  - {id: vet-portal, at: records/portal}
keys:               # what each part relies on, against the core's notes
  vet-housing: [stays-by-id, species-by-animal, infectious-alerts-by-stay, staff-layout]
scale: {checked: true, note: "housing's 64 units against 40 current stays"}
order: [vet-core, vet-lab, vet-scheduling, vet-housing, vet-machinery, vet-portal]
derive:             # sanctioned steps, in order
  - {domain: vet-portal, after: [vet-core, vet-lab], reason: "documents copy the record"}
left_out:           # optional: producer folders not composed, each once
  - {domain: vet-lab, producer: partners/xlab, reason: "no reference lab in this game"}
coherence: {run_at: <setup time>, result: pass}   # written by load-data
```

**`left_out:`** (from v0.5's build), optional: when present, a
non-empty list of `{domain, producer, reason}`, every key a non-empty
string, no other key; `domain` a `domains:` entry, `producer` an existing
folder under that domain's `producers/`, named as `<node>`,
`api/<node>`, `partners/<prefix>` or `public/<name>`, each pair once.
`gmctl compose` merges nothing from a left-out folder, in either the
domain's or the variant's layer, and needs no node for it; so a
left-out owners' route does not call for the partners' shared nodes
("Partners" below). A left-out
partner's `data.sql` is the exception: it still runs where the game has
a partners' database, and is skipped, with the partner-database
refusal, where it has none ("Loading a composed domain" above). A
fixture loading the domains without their producers leaves out every
producer folder (`fixture-clinic-load`, D407).

### A domain is done

When its draft is approved and its folder passes every item (the
procedure's checklist, section 3):

- `domain.yaml` has every key, `id` its folder's name, each path a file
  that exists, `requires` when it is a part;
- `schema.sql` runs into the `postgres` image, a part's after its
  core's; `load.sql` after it, with the shift variables at 0 and at a
  non-zero shift, its sizes within the budget and its load time
  measured; from v0.5 both as `load-data` runs them, connected to their
  database, neither creating one ("Loading a composed domain");
- every role holds exactly the grants the draft lists (diffed);
- every column of every table is classed, `internal` included;
- the business's own rules, when it has any, are written;
- every table belongs to one activity of the register fragment (D334);
- the producer fragments parse, and every statement runs as its role;
- every purpose listed exists, or is named in the draft as to be
  drafted;
- every variant names parts that exist, sets the three axes, takes its
  tags from the vocabulary only, and lists purposes that fit;
- **every `SECURITY DEFINER` function carries a fixed `search_path`**
  (from v0.5, D323: `vet-machinery`'s, `vet-portal`'s pre-login
  functions): in the schema and load files, `data/derive.sql`,
  `data/keys.sql` and each partner `data.sql`, a `SET search_path`
  never naming `"$user"` (`FROM CURRENT` is no fixed path);
- `docs/gm.md` has its sections;
- the `scenario-format` skill finds nothing missing.

## Partners (from v0.5)

The partners' shared material is a catalogue folder of its own, beside
`domains/` and `purposes/`: the three shared nodes every third party
with nodes runs on (`partners-api`, `partners-backend`, `partners-db`,
all `no-access`), and cold storage, the vault, which belongs to no
domain (it serves the `postgres` brick's archiving in any scenario, and
the clinic's purpose 14). It is a design-time source, copied into a
scenario as a purpose's material is; it carries no version and never
bumps. The GM's notes on it are its
[README](../partners/README.md).

```
partners/
  README.md                 GM notes: a partner on the shared nodes, the pg_hba.conf form, cold storage
  shared/
    nodes.yaml              the three nodes' declarations, as a scenario's nodes: holds them
    partners-db/            pg_hba.conf, postgresql.conf, data.sql (creates partners, ends connected to it)
    partners-backend/       the back end's base: schedule.yaml (intensity, no stream), queries.yaml, jobs.yaml
  coldstore/                cold storage, laid out as a domain's partner folder (prefix coldstore):
                              api.yaml, routes/, db/, schedule.yaml, queries.yaml, data.sql,
                              and planted.sql, the vault's history before T0
```

The GM copies `nodes.yaml`'s entries into `scenario.yaml`'s `nodes:`
(each seed path and `partners-db`'s `data:` filled), listing the three
under each `third_parties:` entry with nodes; `shared/partners-db/` as
that node's seed files and the start of its data file;
`shared/partners-backend/` as the back end's seed files. With a vault,
cold storage's endpoints go onto `partners-api` and its fragments onto
`partners-backend` (in a composed scenario through `gmctl compose`'s
scenario layer, `compose/<node>/`), and its `data.sql` then
`planted.sql` (the archiving nodes filled in) after the shared
`data.sql` in `partners-db`'s data file: cold storage belongs to no
domain, so `load-data` never runs these from the catalogue. A domain's
own partners join the same nodes through `gmctl compose` and
`load-data` ("Producer material" and "Loading a composed domain"
above). `partners-db`'s `pg_hba.conf` holds the GM's DO NOT TAMPER
`local` lines, then `host partners <roles> samenet scram-sha-256`, its
roles every partner's (each composed partner's prefix, `coldstore` with
a vault, `owners` for the owners' traffic), then `host all all all
reject`; it carries no `gm_check` host line (D383).

**The customer's credentials with a partner** (from v0.5's build, D365,
D433). A `third_parties:` entry may list `credentials: [<name>, ...]`,
the HTTP credentials `partners.md` documents for that partner, the
customer's own (the clinic's `xlab_customer`, `practices_customer`,
`centres_customer`, `authority_customer`, `headoffice_customer`,
`messaging_customer`). Render gives each its secret `http_<name>`,
handed over (16 characters, the players' alphabet), and mounts it on
the bastion too, the one node holding a credential it neither sends nor
checks. `partners.md` names each as `{{credential:<name>}}`; the
bastion's entrypoint replaces each placeholder by the mounted value when
it copies the file into `/home/player` and onto the page, and refuses to
start on a name with no secret. The loader refuses a placeholder naming
a credential no entry lists, a listed one `partners.md` does not name,
one no endpoint answering under that entry's hostname accepts,
`partners_backend`, and any node's `vault_credential`; `gmctl status`
lists them as "password, handed over". A scenario, a fixture included,
whose third parties carry a `player_doc` maps `partners.md:
player/partners.md` on its bastion, and one whose third parties carry
none maps no `partners.md` (the `scenario-format` skill's rule). v0.5's
loader enforced the mapping only through `credentials:` (a listed
credential `partners.md` does not name); a bastion leaving the page
unmapped beside a `player_doc` and no credential passed it (wave 5's
gate fix `026e023` mapped it on five fixtures by hand). From v0.6 the
loader refuses "third parties carry a `player_doc`, but the bastion
maps no `partners.md`", and the converse, with a unit test (O251,
D486). **Status pages** (from v0.6, D501): each partner with a
`player_doc` has a status page on the bastion's front, rendered by the
bastion from the GM's status file, showing the incidents fault instances
mark `admitted:` ("Scenario" above), each from its start; never a route
to a partner's node (D273).

**Cold storage's console route** (from v0.5's build, master spec 7.3):
the bastion's `web_routes` may hold `cold-storage: "cold-storage:8000"`,
the one route to a third party, accepted only when its target is a
hostname an `api` node's `coldstore_manifests` endpoint answers under,
port 8000; the front forwards `GET /cold-storage/` and `GET
/cold-storage/manifests` (its query kept) with that `Host`, the
`Authorization` header stripped, and answers 404 to every other path or
method. Every other route to a third party's node or hostname is refused.

**The owners alone** (from v0.5's build, D421). The shared scheduler
and `api` nodes are the ones the `third_parties:` entries list. When no
entry lists a scheduler or an `api` node and a composed domain's
`producers/partners/owners/` (either layer, not left out) is the only
partner material for them, the shared nodes are found by name instead:
`partners-backend` (a `scheduler` node) and `partners-api` (an `api`
node), both `write_policy: no-access`, `nodes.yaml`'s names. `gmctl
compose` puts the owners' route onto them; the loader requires both
(refused when one is missing, of another brick or not `no-access`),
counts them among the third parties' nodes for every out-of-reach
check, and takes `partners-api` as the partners' `api` node serving
exactly `owners` (refused when no endpoint answers under `owners` or
one answers under another hostname). The partners' database still
comes from an entry listing `partners-db`: a scenario with the owners'
route and no third party at all is refused for the owners' `data.sql`
(a known limit; no v0.5 scenario is one). With an entry listing a
scheduler or `api` node, every rule above holds unchanged.

**The customer's governance stops at the partners' nodes** (from
v0.5's build, chunk 38, D469). The nodes the loader counts as a third
party's are each `third_parties:` entry's `nodes` plus, for the owners
alone, `partners-backend` and `partners-api` (`model.third_party_nodes`,
one set). On them the customer's `governance:` holds nothing: a class's
location or an outbound flow's `outbox` there is refused ("`<location>`:
`<node>` is a third party's node: the customer's governance holds no
location there; what it sends the partner is an outbound flow"); the
governance check set never walks them (its `database_nodes` and
`transformer_nodes` leave them out, and `check-governance.sh` takes its
nodes from that value, never from the topology's roles); the data
register names none in a `where` or its index. What the customer sends
a partner is judged at the customer's outbox (G4) and declared as a
recipient in the register's `shared_with`; a purpose's table on the
partners' database (its `target` there) stays out of the register's
`where`. A foreign server or a transformer connection reaching a node
not walked still reads "cannot judge".

## Versions and pins (D57–D62, D72, D75, D86, D100, D229)

A scenario pins every brick and fault it uses by id and version: each
node's brick, each fault instance's fault definition. The scripts refuse a
pin that does not match the definition's `version`.

- **Bricks.** Any change to a brick bumps its version, whatever part of
  its folder the change touches: the image and its build context,
  `brick.yaml`, the validator, the documentation (`docs/player.md`,
  `docs/gm.md`) or the companion material. That includes a change that
  leaves the image byte-identical (D57, D58). The one exception is a
  change confined to the brick's tests (`tests/`), which bumps nothing
  (D229). A change made while a
  brick's new version is still unreleased folds into that version with no
  further bump (D61). A brick version is released when the release gate
  of the version that builds it passes; a build wave merging into `main`
  releases nothing (D100). New bricks
  start at 0.1.0 (from v0.3, `scheduler` and `pgbouncer`; `postgres` and
  `bastion` then take 0.3.0, the monitoring bricks 0.2.0); v0.2's changes
  to a v0.1 brick take 0.2.0, since 0.1.1
  was released with `main` at 5c16d06 (D72). v0.4 bumps `postgres` to
  0.4.0 and `scheduler` to 0.2.0: every scenario with a `postgres` node
  pins 0.4.0, every scenario with a scheduler node 0.2.0, and every fault
  applying to either adds the new version to `applies_to` (D206, D215).
- **Faults never bump** (D60). A fault keeps its version whatever changes
  in its folder (injection, sealed check, acceptance criteria,
  `applies_to`); git history is the record. A fault pin therefore names
  the fault, not a state of it.
- **Scenarios never bump** (D58, D75). A scenario keeps its version
  whatever changes (pins, answer key, issues, story, topology); git
  history is the record, and nothing pins a scenario.
- **Purposes and domains never bump** (from v0.4, D215): their material
  is copied into a scenario at design time, so nothing pins a state of
  them. From v0.5 a scenario's composition record names the
  domains and variant it was composed from, for provenance only; a
  composed domain's data files and a purpose's history and DDL are read from
  the catalogue at every load, as a fault definition is, so a change to
  them reaches every scenario loading them, and git history is the
  record. The `partners/` folder never bumps either.
- **Which faults a brick hosts** is stated only by each fault's
  `applies_to` (D59); `brick.yaml` lists no faults. A new brick version
  hosts no fault until the faults that still apply to it add that version
  to their `applies_to`.

## Script contracts (D43)

Fixed at consolidation so the scripts, the faults and the GM skill agree.

- **Injection scripts** (`inject/*.sh`): POSIX shell, read from stdin by
  `sh -s` inside the target container, run as root unless the fault says
  otherwise, with fault parameters passed as environment variables.
  Idempotent: running one twice leaves the same state. Exit 0 on success;
  anything else is a failed setup (D36).
- **Sealed checks** (`checks/fixed.sh`): same delivery. Exit 0 means the
  fault is no longer present in the effective live state, 1 means it is
  still present, from v0.3 3 means "too soon to tell", with the remaining
  window on the first output line (D124); any other code is an error. The
  first line of output says why, in one sentence the GM can use in
  feedback. From v0.3 a sealed check on a database connects as the GM
  check role, inside the GM's connection reserve (D144). From v0.4 a
  sealed check judging runs or triggers receives `CHECK_SINCE`, the
  judged moment as a UTC timestamp, the exit codes unchanged; a check
  comparing two instances reaches each as the GM check role, from a
  scheduler node through `check-sql`, from a database node through
  `check-psql` with the other node's name (D215).
- **The data load** (`data/<node>.sql`): SQL, streamed into `psql` run as
  `postgres` inside the node's container; once per game, a second load
  changes nothing; any error is a failed setup (D52). From v0.5 every
  file `load-data` runs gets the `psql` variable `load_epoch` beside the
  zone and its offset, and a composed domain's files run after the data
  files, read from the catalogue ("Loading a composed domain").
- **Public validator**: exit 0 green, 1 red with one line per broken rule,
  any other code an error. On the database node the player runs it through
  `sudo gm-validate`; the GM's official run goes through the exec verb.

## Roles

A node's role names its place in the topology (proposed list): `bastion`,
`producer`, `queue`, `database`, `pooler` (from v0.3, PgBouncer),
`transformer` (from v0.4, a `scheduler` 0.2.0 node running purpose jobs,
D203), `consumer`, `monitoring`, `backup`, `api` (from v0.5, an `api`
node, D349). A brick may serve several
roles.

### Where a job runs (D207)

Guidance for designing a scenario, from v0.4. A scheduled job may run on
a scheduler node or, with `postgres` 0.4.0, on a database node, through
`pg_cron` or the cron daemon (D206):

- **Light, well-scheduled work may run on a database node**: creating
  partitions, small cleanups, refreshing a small materialized view,
  calling a set-based procedure off-peak.
- **Heavy or row-by-row work goes to a transformer node** sized for it
  (D204).
- **Heavy work on the source instance is the worst placement**: it
  competes with the customers.

Where the computation runs matters more than where the scheduler lives:
a database-node job calling a set-based procedure and a transformer's
job running the same statement load the database alike. A scenario
departs from this guidance only to plant a fault, which its answer key
names.

## Expressing the v1.0 pipeline

Illustration only; v0.2's monitoring tools are D69, the other roles' O11.

| Node | Role | Consumes | Provides |
|---|---|---|---|
| `bastion` | bastion | SSH to every node | the player's entry point |
| `producer` | producer | SQL on `db-src` | — |
| `db-src` | database | — | SQL |
| `transform` | transformer | SQL on `db-src`, SQL on `db-dwh` | — |
| `db-dwh` | database | — | SQL |
| `consumer` | consumer | SQL on `db-dwh` | — |
| `prometheus`, `pg-exporter`, `grafana` | monitoring | metrics from `db-src`, `db-dwh`, and every node's health script | dashboards, alerts |

Flows: `producer` -> `db-src` (rows, continuously), `db-src` ->
`transform` -> `db-dwh` (batch, nightly), `db-dwh` ->
`consumer` (reads), the monitoring nodes *monitor* both databases and
every node. v0.1 uses the same
format with `bastion` and one database node.
