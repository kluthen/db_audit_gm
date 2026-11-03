---
name: scenario-format
description: Use whenever a db_audit_gm scenario, brick, fault, purpose or domain definition is designed, generated, edited or checked for completeness — writing scenario.yaml, gm/answer-key.yaml, brick.yaml, fault.yaml, purpose.yaml or domain.yaml, laying out their folders, or deciding whether a scenario is complete enough to deploy. Start from the templates, fill every required item, flag every missing one; the GM refuses to deploy an incomplete scenario.
---

# Scenario format

Every scenario, brick, fault and, from v0.4, purpose and domain is written
to one shape. This skill holds that shape: sixteen templates and the folder
layouts. This is its **v0.5
version**, expected to evolve as games are played; when a game shows the
format is missing something, change the template and this skill together.

Source of the shape: v0.1's master spec (`specs/versions/v0.1/master-spec.md`,
sections 6, 7, 8 and 8.1), v0.2's format changes
(`specs/versions/v0.2/master-spec.md`, section 6) and v0.3's
(`specs/versions/v0.3/master-spec.md`, section 6, with 7.1 for a
scheduler's files) and v0.4's (`specs/versions/v0.4/master-spec.md`,
section 6, with 7.1 and 7.2 for the transformer script and a database
node's crontab) and v0.5's (`specs/versions/v0.5/master-spec.md`,
section 6, its shapes in 6.8, with 7.1 and 7.2 for options, the standby,
the `api` brick and the HTTP driver, 8.4 and 8.5 for composed domains, 10
for third parties and 13.3 for the data register), with `specs/formats.md`
(draft v28). The top-level keys of
`brick.yaml` are fixed (capture W1-A in `specs/versions/v0.1/wave-log.md`);
v0.2's keys are capture W1 in `specs/versions/v0.2/wave-log.md`, v0.3's
capture W1 in `specs/versions/v0.3/wave-log.md`, v0.4's capture W1 in
`specs/versions/v0.4/wave-log.md`, v0.5's capture W1 in
`specs/versions/v0.5/wave-log.md` (items 0 to 7).

## Templates

| Template | Becomes | Shape of |
|---|---|---|
| [templates/scenario.yaml](templates/scenario.yaml) | `scenarios/<id>/scenario.yaml` | the scenario manifest (authoritative) |
| [templates/answer-key.yaml](templates/answer-key.yaml) | `scenarios/<id>/gm/answer-key.yaml` | the answer key (authoritative, sealed) |
| [templates/brick.yaml](templates/brick.yaml) | `bricks/<id>/brick.yaml` | a brick definition |
| [templates/fault.yaml](templates/fault.yaml) | `faults/<id>/fault.yaml` | a fault definition |
| [templates/queries.yaml](templates/queries.yaml) | `scenarios/<id>/nodes/<node>/queries.yaml` | a scheduler node's query repository |
| [templates/schedule.yaml](templates/schedule.yaml) | `scenarios/<id>/nodes/<node>/schedule.yaml` | a scheduler node's schedule (scenario time) |
| [templates/jobs.yaml](templates/jobs.yaml) | `scenarios/<id>/nodes/<node>/jobs.yaml` | a scheduler node's fixed-time operations (scenario time) |
| [templates/purpose.yaml](templates/purpose.yaml) | `purposes/<id>/purpose.yaml` | a purpose definition (from v0.4) |
| [templates/domain.yaml](templates/domain.yaml) | `domains/<id>/domain.yaml` | a domain definition (from v0.4) |
| [templates/classification.yaml](templates/classification.yaml) | `domains/<id>/data/classification.yaml`, copied to `scenarios/<id>/data/classification.yaml` | a domain's column classification (from v0.4) |
| [templates/register.yaml](templates/register.yaml) | `domains/<id>/data/register.yaml` | a domain's register fragment, one entry per processing activity (from v0.5) |
| [templates/variant.yaml](templates/variant.yaml) | `domains/<id>/variants/<variant>.yaml` | a variant's manifest (from v0.5) |
| [templates/composition.yaml](templates/composition.yaml) | `scenarios/<id>/composition.yaml` | the composition record (from v0.5) |
| [templates/merge.yaml](templates/merge.yaml) | `scenarios/<id>/merge.yaml` | the merge's resolutions (from v0.5) |
| [templates/api.yaml](templates/api.yaml) | `scenarios/<id>/nodes/<node>/api.yaml`, and a domain's fragment `domains/<id>/producers/api/<node>/api.yaml` | an `api` node's endpoints and connections (from v0.5) |
| [templates/brick-gm.md](templates/brick-gm.md) | `bricks/<id>/docs/gm.md` | a brick's GM documentation (D56): the nine required sections |
| [templates/layouts.md](templates/layouts.md) | — | the scenario, brick, fault, purpose and domain folders, and the script contracts |

Markers used in every template:

- every key is **required** unless marked otherwise;
- `# optional in v0.1`: no use yet; left commented out, may be omitted;
- `# optional: <when>`: present only when `<when>` holds (a node holding
  data, a brick with companion material, a seed-file fault);
- an empty list or map is a valid value only where the comment says
  "may be `[]`" or "may be `{}`"; an absent required key is a missing item;
- `<placeholder>`: a value to write. A filled file keeps none.

## Writing one

1. **Start from the template.** Copy it to its place (see the layouts) and
   keep its key order and comments' meaning; drop the template comments
   you no longer need.
2. **Fill every required item.** When designing or generating, the GM
   fills the blanks the initiator left; record what came from the
   initiator in `brief.md` as given.
3. **Fill the folder**, not only the YAML: every file the layout requires
   (starter pack, the data policy with `governance:`, `gm/notes.md`, node
   seed files, data files, the classification with `governance:`,
   `inject/`, `checks/`, `material/`, docs; from v0.5 `composition.yaml`
   with `domains:`, `player/partners.md` with `third_parties:`, and the
   data register's two files, generated).
4. **Check completeness** against the checklists below, by reading. The
   scripts check too: whenever a `gmctl` command loads a scenario, it
   checks the scenario, and every brick and fault it uses, against these
   templates (`model.check_scenario`, `check_brick_dir`,
   `check_fault_dir`), and refuses an incomplete one with the list of its
   missing items (D40). Whether this skill must also run a check of its
   own is open (O20). Beyond that, machine checks are per brick (a
   brick's `companion/`), run by the GM before deploying a scenario that
   uses it.
5. **Flag every missing item** (next section). Do not guess a value to make
   an item disappear.
6. Generate `README.md` with the scenario-document skill once
   `scenario.yaml` and `gm/answer-key.yaml` are complete.

## Flag and refuse

A scenario is complete or it is not deployed.

- **Flag.** For every missing or unfilled item, name it: the file, the key
  path (`nodes[db].knobs[shared_buffers].envelope`) or the missing file
  (`player/story.md`), and what is missing. List them all, not just the
  first. A leftover `<placeholder>`, an absent required key, a missing
  required file and a failed consistency rule are all missing items.
- **Refuse.** The GM refuses to deploy an incomplete scenario: it does not
  generate a local implementation, render, or run `gmctl deploy`. It tells
  the initiator which items are missing, and either fills them (a scenario
  it designs) or asks for them. It deploys only once the list is empty.
- The same holds for a brick or fault the scenario references: an
  incomplete one makes the scenario incomplete.

## Completeness checklists

### Scenario (v0.1 master spec 6.2, v0.2 master spec 6.3, v0.3 master spec 6.1, 6.2, v0.4 master spec 6.1, 6.2, v0.5 master spec 6.2, 6.3)

- **Scenario information**: `id`, `version`, `title`, `date`, `origin`,
  `session_length_minutes` (at most 240), `brief` and `brief.md`.
- **Difficulty** (`difficulty`): its `score`, and optionally the `level`
  it targets (`easy`, `normal`, `hard`; master spec 15.1).
- **Aging** (`aging`), in a scenario with scheduler nodes only: its
  `minimum` and its `handover_at`.
- **Topology**: `networks` (one in v0.2); for every node: `name`, `brick`
  (id, pinned version), `role`, `stateful`, `networks`, `write_policy`
  (and `write_overrides` where a report-only node needs fixable paths),
  `parameters`, `resources` (limits and reservations, disk included, and
  what mounted companion material adds to the node), `published_ports`,
  `seed_files`, `knobs` (initial value and envelope for every knob the
  brick declares), and `data` (file and schema) for a node holding data;
  `crontab_roles` for a `postgres` node seeding `crontab` (from v0.4);
  `flows` (every flow between nodes). With a `prometheus` node, its
  `node_health` map. From v0.4 several `postgres` nodes, each an instance
  of its own with its own seed files and data file.
- **Purposes, domain and governance** (from v0.4, each only when the
  scenario has it): `purposes` (each `id` and its `parts`), `domain`, and
  `governance` (`policy`, `classification`, `classes` with each class's
  `locations`, and `readers` and `outbound` where they apply), with
  `player/data-policy.md` and `data/classification.yaml`.
- **Composed domains, third parties and the data register** (from v0.5,
  each only when the scenario has it): `domains` (each `id`, `at`, and
  the core's `variant`) with `composition.yaml` and, when two profiles
  collided, `merge.yaml`; `third_parties` (each `id`, `name`,
  `stands_for`, `role`, `nodes`, `hostname`, `player_doc`) with
  `player/partners.md`; `governance.register` with
  `player/data-register.md` and `gm/data-register.yaml`; on a node,
  `options` and `standby_of`.
- **Background**: `background`, and `player/story.md`.
- **Incidents, flaws and defects**: `fault_instances` (fault id and pinned
  version, `node`, `parameters`, `visibility`, and with scheduler nodes
  `plant_at` and `aging_minimum` where they differ from the defaults);
  `issues` (zero or more, each with `id`, `complaint`,
  `expected_resolution`, `covers`: fault instances and tooling
  expectations).
- **Answer key** (`gm/answer-key.yaml`), for every fault instance: `what`,
  `why`, `evidence` as `player` (each entry with `where`, `source`, `how`,
  `shows`), `acceptable` (diagnosis, and proposal, fix or improvement as
  they apply), `sealed_check` (with its `window` and `threshold` for a
  behavioural check, its `judges` and `threshold` for a check judging
  runs or triggers), `interactions`, `validators_left_red`, from v0.5
  `register_diff` on a register fault instance and `backlog` on a
  round-trip fault instance that leaves one;
  `tooling_expectations` (may be `[]`: each with `id`, `need`,
  `expected`, `acceptable`, optional `notes`); and `gm/notes.md`.
- **Host topology it was designed for**: `designed_for` (platform, hosts
  with CPU, memory, disk, placement of every node).
- **Starter pack** (`player/README.md`, `story.md`, `issues.md`, and
  from v0.4 `data-policy.md` with `governance:`, from v0.5 `partners.md`
  with `third_parties:` and `data-register.md` with
  `governance.register`), **node files**
  (`nodes/<node>/`), **restored-backup data** (`data/<node>.sql`).
- **Scenario document** (`README.md`), generated, opening with the "do not
  read" warning.

Consistency rules (a failure is a missing item). Those v0.3 adds (master
spec 6.1, 6.2, 7.3, 8; capture W1 items 0 to 4 and 8) are checked by the
loader too:

- **Scheduler nodes**: a node whose brick id is `scheduler` (capture W1
  item 0), role `producer` or `consumer`. Its seed files are under
  `nodes/<node>/`: `queries.yaml`, an optional `builders/` folder of
  files, `jobs.yaml` and `schedule.yaml`, in scenario time, written from
  the scheduler's templates (master spec 7.1); their rules are under
  "The scheduler's files" below.
- **Aging** (D157, D158): `aging:` is present exactly when the scenario
  has a scheduler node. `minimum` is a duration (`<integer><s|m|h|d>`)
  of at least `8h` and as long as the evidence needs (master spec 8.2);
  `handover_at` is a quoted `"HH:00"`, 24-hour, in scenario time. A
  scenario with no scheduler node does not age: it omits `aging:`, has no
  `plant_at` other than `T0`, no instance `aging_minimum` and no
  `{{customer_timezone}}`, and its fault definitions' aging minima are not
  counted (D160); its times stay UTC, as in v0.2.
- **Difficulty**: `score` equals the number of fault instances (each
  fault is worth 1; tooling expectations do not count); `level`, when
  given, is `easy`, `normal` or `hard`.
- **Planting moment** (`plant_at`): `T0` (the default: right after the
  data load, before the load starts) or `handover-<N>h`, N a whole number
  of hours, at least 1, so never at or after hand-over. A moment other
  than `T0` only for a fault whose `injection.kind` is `state`
  (`seed-file` and `parameter` faults are planted at render), and N is at
  most `aging.minimum` and at least the instance's own aging minimum.
- **Instance aging minimum**: the instance's own minimum is its
  `aging_minimum` when set, at least its definition's `aging.minimum`,
  else the definition's. `aging.minimum` covers every instance: its
  planting offset (`aging.minimum` − N, or 0 at `T0`) plus its own
  minimum.
- **Write overrides** (`write_overrides`): on a `report-only` node only,
  non-empty, each entry one of its brick's `writable_paths` exactly as
  written there; the node's `write_policy` stays as written. A path is
  fixable on a node when the policy is `fixable`, or it equals an
  override, or it lies under an overridden directory.
- **A *fix* resolution's per-file policy**: an issue expecting `fix` of a
  `seed-file` fault needs every file its `seed_changes` edit to land (by
  the brick's `seed.paths`) on a fixable path of the target node; a
  `state` or `parameter` fault needs the node's policy to be `fixable`.
- **The customer's time zone**: the story and the starter pack (the
  bastion's seed files) write it as `{{customer_timezone}}`, which render
  fills from the shift (master spec 8.3), and never name a fixed zone;
  only a scenario with scheduler nodes has one.
- **Prometheus' retention**: the time bound of a `prometheus` node's seed
  (`storage.tsdb.retention.time`) covers `aging.minimum` plus four hours
  (four hours with no aging), unless a planted fault is about retention
  (`family: retention`); a size bound, when set, stays above the TSDB's
  measured growth over the same span, against the brick's footprint.
- **A `postgres` seed's `pg_hba.conf`** keeps, under its DO NOT TAMPER
  comment, right after `local all postgres peer`, the lines `local
  replication postgres peer` (the hand-over snapshot's `pg_basebackup`,
  master spec 7.3, D164) and `local all gm_check scram-sha-256` (the GM
  check role's access, so tightening the general `local` line keeps the
  sealed checks working, D171). An answer key citing the seed's line
  numbers counts them.
- **Behavioural checks**: an answer-key instance has `window` (a
  duration) and `threshold` (a number) exactly when its fault's
  `sealed_check.behavioural` is true.

The rules from v0.2:

- every referenced brick and fault exists at the pinned version (the
  scenario's own `bricks/`, `faults/` first, then the catalog);
- a node's `role` is one of its brick's roles, its `write_policy` is one
  its brick supports (or `no-access`; from v0.5 only on a brick listing
  it, master spec 6.5), and every required brick parameter is set;
- `seed_files` covers exactly the brick's `seed.files`, and every file
  exists; a directory entry (`builders/`, `scripts/`) and, from v0.4, an
  entry of the brick's `seed.optional` (`postgres`' `crontab`) may be
  left out;
- each knob's envelope equals or tightens the brick's default envelope;
  the `initial` value matches the seed file (it may lie outside the
  envelope: the validator is then red from the start, and the answer key
  lists it under `validators_left_red` if the players cannot fix it);
- each fault instance's `node` runs a brick in the fault's `applies_to`;
  every required fault parameter is set;
- an instance is `known` exactly when an issue `covers` it; every `covers`
  id is a fault instance or a tooling expectation; an issue covering only
  expectations expects `report` or `propose`; expectation ids are unique
  across fault instance ids and expectation ids;
- an issue's `expected_resolution` is one the covered faults list, under a
  write policy the target node has (for *fix*, the per-file policy above);
- `gm/answer-key.yaml` has exactly one entry per fault instance;
- every answer-key evidence `where` is `bastion` (a shell on the bastion,
  `psql` from there included), `node:<name>` (a node of the topology
  other than the bastion), `ui:<name>` (`<name>` a route of the bastion's
  `web_routes`) or `report:<tool>` (a generated report, `<tool>`
  lowercase, such as `report:pgbadger`); `source` names the file, view or
  output looked at (v0.1's free-text `where`, D101). The readings a fault
  definition cannot carry (through a web interface, or on a node other
  than its target, D167) live here; every reading dropped from a fault
  stays in the answer key of each scenario planting it;
- **the node-health map** (D97): whenever the topology has a `prometheus`
  node, its `node_health` parameter is set and lists every node of the
  topology by name, `prometheus`'s own included; each entry is `default`
  (that node's brick's `processes`) or a non-empty list of names from
  them. A missing map, or a node missing from it, is a missing item; a
  node left out exists only as a parameter fault planted through the map;
- **mounted material**: every node a mounting brick's map lists runs a
  brick that declares `receives` meeting the item's `requires` (the
  s6-overlay version begins with the required prefix; every required
  command is listed), checked against the mounting brick's pinned version;
- **web routes**: each route of the bastion's `web_routes` names a node
  whose brick provides a web interface on that port with `web_path:
  /<route>/`; every web interface of the topology has exactly one route;
  the bastion publishes `{port: 8080, default: 8080}` in every game,
  routes or none (v0.4 master spec 7.3, D224: the web front runs in every
  game; an empty map leaves it serving the starter-pack page alone);
- `player/issues.md` states the same issues as `issues`; nothing under
  `player/` names a hidden fault or an answer;
- `designed_for.placement` places every node, and the summed reservations
  fit the hosts.

The rules from v0.4 (v0.4 master spec 6.1, 6.2, 7.1, 7.2, 8.5, 8.7, 11,
13.4; capture W1 items 0 to 2, 7 and 8 of
`specs/versions/v0.4/wave-log.md`). The loader checks those master spec 14
gives it (the purposes' mapping, the domain, governance's references,
`crontab_roles`, `pg_cron`'s preload and database, a script key and a
job's `connections:`); the others are checked by reading:

- **Purposes** (`purposes:`): each `id` names `purposes/<id>/purpose.yaml`
  in the catalog (never the scenario's folder), once in the list; `parts`
  maps exactly the parts that purpose declares: `source` and `target`
  each a location `<node>/<database>` (a node of role `database` and a
  database its data file creates; the two may be equal), `runner` a node
  of role `transformer`, `consumer` of role `consumer`, `receiver` of role
  `producer`. For each job of the purpose, the runner's `jobs.yaml` has an
  entry with that `name` and `key`, the key in its `queries.yaml`. The
  purpose's `material/` is copied in at design time, adapted to the
  scenario's names: each part's fragments into that node's
  `queries.yaml`, `scripts/`, `jobs.yaml` and `schedule.yaml`, a database
  part's `data.sql` into that node's data file. A fault instance whose
  fault lists `applies_to.purposes` needs each of those purposes in
  `purposes:` (by reading: the loader does not tie them).
- **Domain** (`domain:`): names `domains/<id>/domain.yaml` in the
  catalog; provenance only. The domain's files are copied in and adapted:
  `schema.sql` then `load.sql` make the data file of the node holding the
  business, its producer fragments the producer's files, its
  classification the scenario's `data/classification.yaml`. A static
  scenario has none.
- **Governance** (`governance:`): `policy` and `classification` name
  files of the scenario that exist, the classification being the
  domain's, copied in. Every class of `classes` is `personal`,
  `customer-linked` or `internal`; every class the classification uses
  other than `internal` has an entry, and a missing `internal` reads as
  `locations: any`. `locations` is a non-empty list of locations (as for
  purposes) or the word `any`; `any` takes neither `readers` nor
  `outbound`, any other value requires `readers` (may be `[]`). Every
  reader is a role a data file of the scenario creates, never one of the
  game's own (`dba`, `postgres`, `gm_check`, `monitoring`,
  `pgbouncer_lookup`), which every rule leaves out. Each `outbound` entry
  has a receiver label `to` (`[a-z][a-z0-9-]*`, once per class), the
  `outbox` it fills (`<node>/<database>/<table>`) and a non-empty
  `fields`. `separation: instance` when the policy demands an instance of
  its own, refused with `locations: any`: G1 then finds, on each node
  holding one of the class's locations, every database but `postgres` not
  among them (spec D253).
- **The data policy** (`player/data-policy.md`, with `governance:`): the
  GM writes it from `governance:`, in the story's voice (the company
  speaking to its staff): what the company holds, the classes in plain
  words, where each may live, who may read it, what may leave and to
  whom. It is **correct**: it states `governance:` faithfully, never a
  wrong or ambiguous rule (a policy carrying a fault is not allowed in
  v0.4). It may state rules no check verifies (encryption at rest,
  retention, purposes of processing), **unmarked**: it never says which
  of its rules are audited, and the answer key lists only the checked
  ones. It speaks of application and staff accounts: the game's own roles
  are outside it. It names no hidden fault. The bastion maps it:
  `data-policy.md: player/data-policy.md` in its `seed_files` (an
  optional seed file of `bastion` 0.4.0), exactly when the scenario has
  `governance:`.
- **The GM check role on every instance**: in a scenario with
  `governance:`, every `database` node's seed `pg_hba.conf` admits
  `gm_check` from the game network under its DO NOT TAMPER comment,
  `host all gm_check samenet scram-sha-256`, beside the three `local`
  lines above (the governance checks reach every instance over the
  network, as does a check comparing two instances).
- **Several `postgres` nodes**: each an instance of its own, with its own
  seed files, its own data file `data/<node>.sql` and `data` entry, and
  its own `knobs`.
- **The optional crontab** (`postgres` 0.4.0): a `postgres` node seeding
  `crontab` maps `crontab: nodes/<node>/crontab` and has
  `crontab_roles` (may be `[]`), which a node without a crontab may not
  have. The roles are unique, `[a-z_][a-z0-9_]{0,40}`, never reserved
  (as a schedule's roles), and created by the node's own data file;
  deployment mounts each one's `role_<role>_password`. The crontab is
  written in scenario time, its time fields in the subset render can
  shift, as [templates/layouts.md](templates/layouts.md) states with its
  baseline entry: `PGPASSFILE`, `psql -U <role>`, output appended to
  `/var/log/postgresql/cron/<job>.log`; no entry connects as `postgres` by
  peer (a superuser) unless that is a planted fault, and none holds a
  password. A fault editing `crontab` targets a node seeding it.
- **`pg_cron`**: on exactly when the node's seed `postgresql.conf`
  preloads it and its data file creates it. The seed's last uncommented
  `shared_preload_libraries` lists `pg_cron`, `cron.database_name` names
  a database that node's data file creates, `cron.use_background_workers
  = on` (a job runs as its role with no password and no `pg_hba.conf`
  line) and `cron.timezone = '{{customer_timezone}}'`; the data file
  creates the extension in that database as superuser (`CREATE EXTENSION
  [IF NOT EXISTS] pg_cron` at the start of a line) and schedules each job
  with `cron.schedule_in_database(..., username => <role>)`, in scenario
  time. A data file creating `pg_cron` on a node whose seed does not
  preload it is refused (a fault may still remove the preload). At most
  eight jobs run at once under the default `max_worker_processes`, which
  the seed raises if the scenario needs more.
- **The customer's time zone in seed files**: from v0.4
  `{{customer_timezone}}` may also appear in a scheduler node's seed
  files and in a `postgres` node's seed `postgresql.conf`
  (`cron.timezone`), where render writes the bare zone (`Etc/GMT-2`),
  the starter pack keeping its text form; still only in a scenario with
  scheduler nodes. A data file reads the zone and its offset from the
  data load's two `psql` variables. Databases stay in UTC: never `ALTER
  DATABASE ... SET timezone`.
- **Where a job runs** (the placement guideline, v0.4 master spec 8.7,
  D207): a database node's cron, `pg_cron` or the daemon, runs only light,
  well-scheduled work (creating partitions, small cleanups, refreshing a
  small materialized view, calling a set-based procedure off-peak); heavy
  or row-by-row transformation goes to a transformer node sized for it;
  heavy work on the source instance is the worst placement. Where the
  computation runs matters more than where the scheduler lives. A
  scenario departs from this only to plant a fault, which its answer key
  names.
- **A second instance's monitoring** (v0.4 master spec 13.4): a second
  `postgres` instance is monitored by a `postgres-exporter` node of its
  own (about 42 MB reserved, its target scraped by the `prometheus`
  node), or left unscraped by design, which the answer key states as a
  tooling expectation naming the instance (judged in feedback, not a
  fault instance). Every `postgres` node keeps the `monitoring` role; from
  v0.5 the role exists only on a node choosing `options: [monitoring]`,
  which every node an exporter targets does.
- **Jobs the players may move**: the starter pack (`player/README.md`)
  names every job the players may edit (each `jobs.yaml` job on a node
  where `jobs.yaml` is fixable, by policy or override: its node and its
  name) and says that moving a job's time is how they verify a fix to
  it. It names no database-node job (`pg_cron`, crontab) unless the story
  does: a job nobody lists is a finding.
- **Checks judging runs or triggers**: an answer-key instance has
  `judges` exactly when its fault's `sealed_check.judges` is set, equal
  to it, with a `threshold` (a non-negative integer, the violations
  tolerated, 0 by default) and no `window`.

The rules from v0.5 (v0.5 master spec 6.2, 6.3, 6.8, 7.1, 8.4, 8.5, 10,
13.3; capture W1 items 0, 2, 6 and 7 of `specs/versions/v0.5/wave-log.md`;
`specs/formats.md` "Scenario" and "Composing domains"):

- **`domain:` or `domains:`, never both.** `domain: <id>` stays the
  one-domain form (v0.4's shop). `domains:` lists the domains the
  scenario is composed of, each `id` a domain of the catalog, once; every
  core a part `requires` is listed; `variant` is required on the core's
  entry and refused on a part's, and the core's variant names every part
  listed; `at` is a `node/database` (a `database` node and a database the
  scenario's data creates), or for a part declaring `databases` a map
  from each of them to a `node/database`; a `lands_with` part shares its
  core's `at`.
- **The composition record**: `composition.yaml` is required with
  `domains:` and refused without ([templates/composition.yaml](templates/composition.yaml));
  its `domains` equal `scenario.yaml`'s (id, variant, `at`). `merge.yaml`
  ([templates/merge.yaml](templates/merge.yaml)) holds the resolutions of
  the conflicts `gmctl compose` stopped on; a resolution meeting no
  conflict is refused as stale. A scheduler or `api` node's files are
  then `gmctl compose`'s output, from the domains' fragments, the
  variant's profile and the scenario's `compose/<node>/` (the purposes'
  material, each scheduler node's `intensity` and `timeline`), never
  edited by hand.
- **Third parties** (`third_parties:`): one entry per partner, with its
  `id`, in-world `name`, `stands_for`, `role` (`inbound`, `outbound`,
  `round-trip`), its shared `nodes` (may be `[]` for a party without a
  node), its `hostname` (`[a-z][a-z0-9-]*`, unique, never a node's name:
  its alias on the partners' `api` node) and its `player_doc`, an entry
  of `player/partners.md`. The bastion maps `partners.md:
  player/partners.md` (an optional seed file of `bastion` 0.5.0) exactly
  when the scenario has third parties with a `player_doc`. A third
  party's nodes have `write_policy: no-access` (no `player` account, no
  `sudo` wrappers, no route on the bastion, not in the starter pack's
  nodes).
- **Options** (`options:` on a node): a non-empty list of unique option
  names the node's brick declares (`[monitoring]` on `postgres` 0.5.0),
  off unless listed; `[]` is refused. Every node an exporter or another
  monitoring brick targets chooses `monitoring`.
- **A standby** (`standby_of: <node>`): a `postgres` node whose primary is
  a `postgres` node that is no standby itself; the standby has no `data:`
  entry (cloned from its primary after the load) and its seed sets
  `hot_standby_feedback = on`; the primary's seed `pg_hba.conf` carries
  `host replication replicator samenet scram-sha-256` under its DO NOT
  TAMPER comment. The standby keeps the role `database`.
- **The data register** (`governance.register: player/data-register.md`):
  required of every scenario listing `domains:` (v0.4's released shop
  scenario is exempt until it is next revised), allowed with `governance:`
  alone. Its two files, `player/data-register.md` (the handout, mapped to
  the bastion's optional seed file `data-register.md`) and
  `gm/data-register.yaml` (the true register), are generated by the GM's
  `data-register` skill, never edited by hand, and regenerated rather
  than reconciled; the loader refuses a stale register (its
  `generated_from:` digests) and checks the handout exists unless the
  answer key declares its absence as a planted fault.
- **Answer key, from v0.5** (master spec 6.3): a register fault instance
  carries `register_diff:` (each item its `entry`, `field`, `true` value
  and `handed_out` value, or the one item `absent: true` for a register
  left out), its resolution *propose*, the corrected entry judged at the
  final answer; a round-trip fault instance lists its `backlog:`, the
  requests it left stuck before the fix, a consequence the GM may credit
  the players for cleaning up, never a fault and never counted toward
  the fault cap; a fault on a component that is no layer of the players'
  (a ward display's firmware) states *report* as its resolution, judged
  at the final answer, never cleared during play; a sealed check may read
  a third party's side as evidence and judges the customer's side only,
  and no expected *fix* names a third party's node.

### The scheduler's files (v0.3 master spec 7.1, v0.4 master spec 7.1)

A scheduler node's `queries.yaml`, `builders/`, from v0.4 `scripts/`,
`schedule.yaml` and `jobs.yaml`, under `nodes/<node>/`, in scenario time.
Start from
[templates/queries.yaml](templates/queries.yaml),
[templates/schedule.yaml](templates/schedule.yaml) and
[templates/jobs.yaml](templates/jobs.yaml); the forms 7.1 leaves open are
capture W1's (item 7) and spec D168, those v0.4 adds capture W1's of
`specs/versions/v0.4/wave-log.md` (items 0 and 7) and spec D219, those
v0.5 adds (`scheduler` 0.3.0: the HTTP driver, the call, the weighted
`choice`) capture W1's of `specs/versions/v0.5/wave-log.md` (items 3 and
4). The loader checks, and a failure is a missing item:

- **Every key named exists**: each stream's `key`, each job's `key` and
  each timeline change's `set.key` is a key of the node's `queries.yaml`.
  A script key is named by a job only, never by a stream or a timeline
  change's `set.key` (a script runs only as a job).
- **The repository**: a key is `[a-z0-9][a-z0-9._-]*` and maps to one
  form: a query (`sql`, optional `params`, optional `transaction`), a pool
  (a non-empty list of queries, each with an optional positive `weight`),
  a sequence (`steps`, a non-empty list of `{sql, params}`, optional
  `transaction`), a builder (`builder: builders/<file>:<function>`,
  optional `options` map) or, from v0.4 (`scheduler` 0.2.0), a script
  (`script: scripts/<file>:<function>`, optional `options` map) or, from v0.5 (`scheduler` 0.3.0), a call
  (`call: "<METHOD> <path>"`, the method `GET`, `POST`, `PUT`, `PATCH` or
  `DELETE`, the path absolute, its `%(name)s` filled from `params`;
  optional `params`, those not in the path the JSON body's fields, the
  query string's for `GET` and `DELETE`; optional `builder` returning the
  JSON body, with `options`, `params` then holding only the path's names).
  A call key runs only on an `http` connection, a query, pool, sequence or
  builder key only on a SQL one; no pool, sequence or transaction of
  calls. Parameters come from generators, one key each:
  `{int: [lo, hi]}`, `{decimal: [lo, hi, places]}`, `{choice: [..]}`,
  from v0.5 the weighted `{choice: {v1: 3, v2: 1}}` (weights positive
  integers, relative; values scalars),
  `{sequence: [start, step]}`, `{now: utc}`. A `transaction` has an
  `isolation` (`read committed`, `repeatable read`, `serializable`) and an
  optional `hold` (a duration).
- **Builders**: the file is in the node's `builders/` seed folder (files
  only, named `[A-Za-z0-9_][A-Za-z0-9_.-]*`) and defines the function at
  its top level; the loader parses it, never runs it.
- **Transformer scripts** (v0.4 master spec 7.1): the file is in the
  node's `scripts/` seed folder, under the same naming, and defines the
  function at its top level; it is called as `<function>(conns, options,
  log)`, `conns` mapping each of its job's connection names to an open
  psycopg connection (autocommit off), commits what it means to commit
  and returns the number of rows it wrote; it imports only the standard
  library, psycopg 3 and PyYAML, and holds no password. A purpose's
  runner is a node of role `transformer`, sized for what its scripts move
  in one run.
- **Connections**: the driver is a known one (`sql/postgresql`, from
  v0.5 `http`). A `sql/postgresql` connection's target is
  `<node>:<port>/<database>` on a node of the topology; its role
  is an application role (`[a-z_][a-z0-9_]{0,40}`, never `postgres`,
  `dba`, `monitoring`, `gm_check`, `pgbouncer_lookup`, `replicator` or
  `pg_*`); its pool is `{size: N}` or `{per-call: true}`. An `http`
  connection (v0.5) has a target `<host>:<port>` (a node, or a third
  party's hostname), an optional `credential` (`[a-z][a-z0-9_]*`, the
  game's secret `http_<credential>`; absent for a public endpoint), a
  `pool`, a positive integer (kept-alive connections), an optional
  `timeout` (`<n>s`, 1 to 60, default `10s`), and no `role` and no
  database. No password or credential value is ever written: render
  generates one secret per role and per credential. A script job's
  `connections:` may name an `http` connection, which its script gets as
  an HTTP client (`get`, `post`).
- **Streams**: a `rate` `<number>/s|min|h`, `arrivals` `poisson` or
  `even`, an optional `shape` of the schedule, an optional `concurrency`;
  a stream is known by its initial key, unique on the node. From v0.4
  `streams` may be `[]`: a node with fixed-time operations only (a
  transformer).
- **Shapes cover the 24 hours**: `hours` maps quoted `"HH"` or `"HH-HH"`
  (never wrapping) to a multiplier at least 0, covering 00 to 23 exactly
  once; a weekly shape's `days` (`mon` to `sun`, alone or as ranges, never
  wrapping) cover the week exactly once, each with its `hours`.
- **Timeline changes**: `at` is `T0` or `handover-<N>h`, before hand-over
  and no further before it than `aging.minimum`; `stream` names a stream
  by its initial key; `set` changes its `key`, `rate` or `connection`.
- **Jobs**: a unique `name`, a `key`, exactly one of `connection` (a
  connection of the node's schedule; every key but a script's) and, from
  v0.4, `connections` (a script key's job: a non-empty map from the
  script's connection names, `[a-z][a-z0-9_]*`, `source` and `target` by
  convention, to connections of the schedule), and `at`, a quoted 5-field
  cron in the subset render can shift (minute any numeric form; hour `*`,
  or from v0.4 a comma list of `n`, `a-b` (never wrapping), `*/s` or
  `a-b/s` within 0-23; day of month and month `*`; day of week `*` or a
  number or list 0-6, only with a single-number hour). A purpose job's
  `cadence` and a seeded crontab's entries use the same subset. Never
  `timezone:`. A `timezone_offset: <N>`, a
  non-zero whole number of hours from the customer's zone, only on a node
  where a fault instance's seed change edits `jobs.yaml` (the
  wrong-time-zone fault, D168).
- No other key in `schedule.yaml`: the game's seed is render's.

### Brick (master spec 7)

Every key of [templates/brick.yaml](templates/brick.yaml) except the
commented-out ones; and the folder: `Dockerfile`, `validator/`,
`docs/player.md`, `docs/gm.md`, and `companion/` when `companion` is set.
The image name is registry-qualified; the brick names no Swarm-only
feature. In particular (v0.2 master spec 6.1, v0.3 master spec 6.4,
v0.4 master spec 6.4):

- **Roles**: each one of the closed list `bastion`, `producer`, `queue`,
  `database`, `pooler` (PgBouncer), `transformer`, `consumer`,
  `monitoring`, `backup`, `api`. A scenario node's `role` is one of its brick's.
  `transformer` is, from v0.4, a `scheduler` 0.2.0 node running a
  purpose's jobs (v0.4 master spec 7.1); `api`, from v0.5, the `api`
  brick's role (spec D349).
- **Options** (`options:`, optional, from v0.5 master spec 6.5, 6.8): each
  option's `name`, what it `brings` (`secrets`, declared under `secrets:`
  where their path, owner and mode stay, mounted only on a node choosing
  it; `roles`, created at initdb only there) and its `docs`, a section
  `docs/gm.md#option-<name>`, the level-3 heading "Option `<name>`" under
  Configuration. `postgres` 0.5.0 declares one, `monitoring`.
- **`no-access`** (v0.5 master spec 6.5, 10.2): listed in
  `write_policies` by every brick that may serve a third party (`api`,
  `scheduler`, `postgres`); its entrypoint then creates no `player`
  account and no `sudo` wrappers.
- **The `api` brick's seed files** (v0.5, capture W1 item 5): `api.yaml`
  ([templates/api.yaml](templates/api.yaml)) and the directory entries
  `routes/` and `db/`, mapped by `seed.paths`; `writable_paths`
  `/srv/api/db` and `/home/player`, the routes and `api.yaml` protected.
- **Footprint**: the shape of a scenario node's `resources`, `limits`
  (`cpu`, `memory`) and `reservations` (`cpu`, `memory`, `disk`, at rest),
  the default the GM starts from when it sizes a scenario, plus
  `disk_growth_per_hour`: the volumes' growth per hour of aging and of
  game, as measured (a provisional estimate says so in a comment until it
  is measured), `0` when nothing grows, so `fit` scales the disk to the
  scenario's aging. It excludes any material other bricks mount into this
  one.
- **Writable paths** (`writable_paths`): the paths `player` may change on
  a fixable node, and the only paths a report-only node's
  `write_overrides` may name, each written exactly as there. A path is
  fixable on a node when the node's policy is `fixable`, or it equals an
  override, or it lies under an overridden directory. `/home/player`
  stays writable under every policy.
- **Seed paths** (`seed.paths`): every `seed.files` entry mapped to its
  live in-container path, so a *fix* resolution of a seed-file fault can
  be checked against the policy of the file it changes. An entry ending
  in `/` (`builders/`, `scripts/`) is a directory: optional in a
  scenario's `seed_files`, mapped to a folder of files there, and to a
  directory in `seed.paths`. `seed.modes` gives a seed file a config mode
  other than `"0444"` (the scheduler's `schedule.yaml`, `"0400"`).
- **Optional seed files** (`seed.optional`, from v0.4, capture W1 item
  4): the seed files a node may leave out of its `seed_files`, each a
  plain entry of `seed.files`, never one ending in `/` (a directory entry
  is optional already, and listing it is refused as redundant). A node's
  `seed_files` maps every entry of `seed.files` but the directory entries
  and those in `seed.optional`; render mounts only what it maps, and the
  brick tells an optional file left out by its absence under `seed.dir`.
  `postgres` 0.4.0's `crontab` is the first, the bastion's
  `data-policy.md` the second (v0.4 master spec 6.4).
- **Report tools** (`report_tools`, optional): the report generators
  players run on the node (`pgbadger` on `postgres`); a fault's evidence
  may name `report:<tool>` only for one of the target brick's.
- **Snapshot** (`snapshot:`, optional): per volume, how the hand-over
  snapshot copies it: `pg_basebackup` (the database's data, online; at
  most one per brick, which then ships `gm-snapshot-db`), `copy` (a plain
  copy while the node runs, for seeded, append-only or whole-file-rewritten
  files) or `stop` (a brief s6 stop of the brick's services, never a
  Swarm scale to zero). When present it names every volume but the one at
  `/run`, once; absent, every volume but `/run` is copied by `stop`. `/run`
  is never copied.
- **No fault list**: `brick.yaml` names no fault; which faults a brick
  hosts is stated only by each fault's `applies_to` (D59).
- **Interfaces**: `provides` and `consumes`, each entry with `name`,
  `protocol` and `port`. A provided interface with `web_path` is a web
  interface the bastion's web front publishes, at `/<route>/`, its fixed
  path.
- **Parameters**: a scalar unless `shape` says `node-map` (node name to
  `default` or a list of the node's brick's `processes`) or `web-routes`
  (route name to `"node:port"`).
- **Secrets**: each with its `kind`, `password` (with `handed_over: true`
  for one players type) or `key-pair` (with its `pair` and the `half`,
  `private` or `public`, mounted), and optionally `only_with_role`
  (generated and mounted only when a node of the topology has that role).
  A name two bricks declare is one secret and both declare it alike
  (`kind`, `handed_over`, `pair`, `half`).
- **Mounted companion material** (`companion.mounted`), for each item: its
  `files` (each `source` under `companion/`, an absolute `target` in the
  receiving node, a `mode` with no write bit: root-owned, read-only); the
  `parameter` listing the receiving nodes (a `node-map` parameter of this
  brick, set on its own node in the scenario); the `node_config` the
  renderer writes per node; the `footprint` it adds to each receiving
  node; what a receiving image must provide (`requires`: an s6-overlay
  version prefix and the commands used, by name).
- **Receiving bricks** (`receives`): an image that accepts mounted
  material declares the s6-overlay version its Dockerfile installs and
  the commands available, from the vocabulary in the template; its
  `docs/gm.md` says so under Connections. A topology is refused when a
  receiving node's brick does not meet the `requires` of the mounting
  brick's pinned version.

`docs/gm.md` (D56; `specs/formats.md`, "`docs/gm.md` must contain";
template [templates/brick-gm.md](templates/brick-gm.md)) has one level-2
heading per required section, with these exact names, in this order:
`## Purpose`, `## Placement`, `## Configuration`, `## Connections`,
`## Access`, `## Footprint`, `## Supported faults`, `## Checks`,
`## Known limits`. A brick may add its own sections, as subsections of a
required one or after `## Known limits`. A brick running scheduled jobs on
its own node (from v0.4, `postgres` 0.4.0: `pg_cron` and the cron daemon,
v0.4 master spec 7.2) gives each job kind a section of its own after
`## Known limits`, and `docs/player.md` one of the same name: what it is,
how a scenario turns it on, its cost, what players see and change, the
faults it allows. Refuse the brick, and so every scenario that uses it,
when:

- one of the nine headings is missing, renamed or out of order;
- one of them is empty (a section that does not apply says so in a
  sentence, with the reason);
- it disagrees with `brick.yaml`: a parameter, knob, interface or
  footprint figure that does not match the declaration, or one that
  `brick.yaml` lacks (footprint: limits and reservations, D84, and the
  growth per hour); the write policies (and, under report-only, what
  `write_overrides` may make fixable) belong under Access, and the
  snapshot methods, with the brief stop where the brick has one, in a
  level-3 `### Snapshot` under Footprint (capture W1 item 5);
- it disagrees with the faults' `applies_to` (D59, D62): a fault listed as
  supported whose `applies_to` does not name this brick and version, or a
  **catalog** fault whose `applies_to` does that is not listed (a fault
  in a scenario's own `faults/` is the scenario's and is not listed);
- it states placement or connections in a platform's own syntax rather
  than as requirements (one per node, on the same host as a given node,
  sharing a network with it).

### Fault (master spec 8)

Every key of [templates/fault.yaml](templates/fault.yaml), with
`seed_changes` for a seed-file fault, `scripts` for a state fault and
`parameter_changes` for a parameter fault, and an `acceptance` entry for
each kind in `resolutions`; and the folder: `inject/` (when it has
material), `checks/fixed.sh`, `checks/probe.md`, `gm.md`. Scripts follow
the contracts in [templates/layouts.md](templates/layouts.md). In
particular (v0.2 master spec 6.4, v0.3 master spec 6.3 and 6.5, v0.4
master spec 6.3 and 6.5):

- **Family** (`family`): free text. From v0.4 a purpose fault is
  `data-flow` (duplicates, dropped records) or `rules` (a wrong zone, a
  wrong segment), and a governance or credential fault is `security`,
  its id `governance-<what>` or `security-<what>`.
- **Options** (from v0.5 master spec 6.4): `requires_option: <name>` when
  the fault needs its target node to choose that option (a lost
  `pg_monitor` grant on the `monitoring` role), `option_absent: <name>`
  when it plants the option's absence (a monitoring node scraping a node
  without it).
- **A register fault** (v0.5 master spec 6.4): a `seed-file` change on the
  bastion, `seed_changes` naming `data-register.md`, its id
  `governance-register-*`, family `security`; the `data-register` skill
  writes the changed handout, and each instance's answer-key entry
  carries `register_diff:`.
- **A partner's misbehaviour** (`partner_behaviour:`, v0.5 master spec
  6.4, 10.1): an outage, slow answers, errors, a lost, late, duplicated or
  out-of-order callback, seen at the partner's interface, never a root
  cause inside it: the `partner` (a `third_parties` id), the `key`
  switching that partner's state on the shared nodes, how it is `placed`
  (`timeline`, a change at the planting moment, or `standing`, from T0)
  and its own `material` for the shared nodes, never the domain's. Every
  fix is on the customer's side.

- **Aging** (`aging:`): the technique, `real-time` (the only one in
  v0.3), and the minimum duration before the evidence shows under the
  load (`0m` when it shows at once), a duration `<integer><s|m|h|d>`. It
  is counted only in a scenario with scheduler nodes (master spec 8,
  D160). A fault whose evidence shows only at a time of day or at a job's
  runs (from v0.4 a purpose's job, a database node's `pg_cron` job or
  crontab entry too) counts its minimum from that job's first run after
  planting (spec D189); the scenario raises the instance's
  `aging_minimum` to cover it, and the fault's `gm.md` says so.
- **Evidence locations**: each entry's `where` is `node` (a shell on the
  fault's target node), `bastion` (a shell on the bastion, `psql` from
  there included) or `report:<tool>` (`<tool>` one of the target brick's
  `report_tools`), and its `source` names the file, view or output looked
  at (v0.2's free text). A fault never names `ui:<name>` nor
  `node:<name>`: a reading through a web interface, or on a node other
  than the target, is the scenario's, and its answer key carries it.
- **Sealed checks** exit 0 (fixed), 1 (present), 3 (too soon to tell, the
  remaining window on the first output line) or any other code (error).
  A check judging behaviour over a window sets
  `sealed_check.behavioural: true`; the answer key then gives each
  instance's `window` and `threshold`. A check that queries PostgreSQL
  connects as the GM check role `gm_check`, inside the GM's reserve,
  through `postgres`' root-only `check-psql` helper (master spec 6.5,
  capture W1 item 8); never as `dba` or an application role. From v0.4 a
  check comparing two instances reaches each as `gm_check`: from a
  scheduler node through `check-sql`, from a database node through
  `check-psql` with the other node's name.
- **Checks judging runs or triggers** (`sealed_check.judges`, from
  v0.4): `runs` or `triggers` for a check judging a purpose's runs or its
  triggers since the judged moment; absent, the check judges the live
  state, as in v0.3. Never together with `behavioural: true`. The check
  gets `CHECK_SINCE` (the judged moment, a UTC instant) and
  `CHECK_THRESHOLD`; each instance's answer-key entry then states the
  same `judges` and a `threshold`, and no `window`.
- **Purpose faults** (`applies_to.purposes`, from v0.4): a non-empty list
  of purpose ids the fault attaches to, beside `bricks:`. The fault also
  lists in `applies_to.bricks` the `scheduler` versions its runner needs,
  its sealed check running there, and its instance's node runs a brick of
  that list. A scenario planting it names each of those purposes in its
  `purposes:` (the loader does not check it). It is planted as any fault
  is: a `seed-file` change (a runner's `queries.yaml`, `scripts/` or
  `jobs.yaml`; a database node's data file, `postgresql.conf` or
  `crontab`), a `state` change during the aging, or a timeline change of
  a schedule for an outside party's behaviour, which the definition
  states and the scenario writes.
- **Host needs** (`needs_unshared_host`, from v0.4): `true` when the
  fault's node must never be placed on a shared host (the out-of-memory
  incident); a boolean, absent read as `false`. `gmctl fit` refuses a
  mapping that places such an instance's node on a host declared
  `shared`.
- **Faults in a scheduler's files** are `seed-file` faults whose
  `seed_changes` edit `queries.yaml`, `builders/`, `jobs.yaml` or
  `schedule.yaml`, from v0.4 `scripts/` too, at render. A fault editing a
  brick's optional seed file (`crontab`) targets a node seeding it.

- **`applies_to`** lists each brick's versions one by one, as exact
  strings (`["0.1.0", "0.1.1", "0.2.0"]`), never a range: a fault never
  claims a brick version nobody tried it on.
- **Parameter faults** (`injection.kind: parameter`, `stage: seed`): a
  change to a parameter of the target node, applied by the renderer when
  it writes the local implementation. Each `parameter_changes` entry names
  a parameter of the target node's brick and an `op`: `set` (with
  `value`), `remove-entry` (with `entry`, the map key) or
  `remove-from-entry` (with `entry` and `item`; a `default` entry is first
  expanded to the brick's `processes`). `{NAME}` in `entry`, `item` or
  `value` is replaced by the instance's fault parameter `NAME`.
- **Faults about mounted material** (a `parameter_changes` entry naming a
  `companion.mounted` item's `parameter`) target the node of the brick
  that ships the material, name only that brick in `applies_to`, and have
  a required parameter `node` naming the affected node. For the
  node-health script: the `prometheus` node, through its `node_health`
  map (a node left out, or a service left out of a node's entry).

### Purpose (v0.4 master spec 6.7, 8; v0.5 master spec 6.6, 12.1)

Every key of [templates/purpose.yaml](templates/purpose.yaml), and the
folder: `material/` (one folder per part receiving material, each file a
fragment named as the scenario's own), `checks/` (one script per
invariant), `gm.md`. Capture W1 item 5 of
`specs/versions/v0.4/wave-log.md` settles the keys and closed values;
v0.5's additions are `specs/formats.md` "Purpose definition". In
particular:

- **Identity**: `id` (the folder's name, `[a-z][a-z0-9-]*`), `title`,
  `domains` (non-empty, each an existing domain whose `purposes` lists
  this one), `kind` (`pulled`, `transformed-in-place`, `pushed`,
  `pushed-obligation`). No `version`.
- **Parts**: among `source`, `target`, `runner`, `consumer`, `receiver`,
  with `source`, `target` and `runner` always present, each with one line
  saying what fills it.
- **Jobs**: each with its `name` and `key` (as the runner's `jobs.yaml`
  and `queries.yaml` will hold them), `part` (a declared runner), `source`
  and `target` (declared database parts), `method` (`sql`, `script`,
  `foreign-tables`, `procedure`, `pg_cron`, `cron-daemon`), what it
  `computes` in one sentence, its `cadence` in scenario time (the jobs'
  cron subset), and the customer role of each of its `connections`.
- **Trace**: each entry with its `kind` (`outbox-rows`,
  `published-results`, `run-ledger`, `definitions`), its declared `part`,
  and exactly one of `table` (with `run_column`, the column tying a row to
  its run) and `file` (an absolute path on that part's node).
- **Invariants**: each with its `id` (`[A-Z][0-9]+`, once), a one-sentence
  `statement` against the source, its `check` (a file of `checks/`), its
  `parameters` (fault.yaml's shape, may be `{}`) and its `witness` (what
  must exist in the data for a run to be able to violate it).
- **Data moved**: one entry per job of the purpose: the classified
  columns of a class other than `internal` it `reads`
  (`<database>.<table>.<column>`, may be `[]`) and where it `writes`
  (`<part>:<table>`).
- **Roles**: each customer role the purpose needs, the database `part`
  it lives in, and its grants (`reads`, `writes`, free text, each may be
  `[]`).
- **Material** is written for the first v0.4 scenario's names (nodes
  `db`, `reporting`, `bi`, `crm`, `consumer`, `gateway`; databases
  `shop`, `reporting`): a fragment holds only the entries it adds under
  the scenario file's top-level keys (`queries:`; `jobs:`; a schedule's
  `connections:`, `streams:`, `shapes:`, never `intensity` or
  `timeline`). Heavy or row-by-row work runs on the runner, never on a
  database node (the placement guideline above).

From v0.5 (formats.md "Purpose definition", D286, D303, D307):

- **The round trip**: `kind: round-trip` and a `round_trips:` block,
  required there and refused elsewhere, one entry per exchange (an
  exchange both ways carries two): who `asks` (`customer` or `partner`),
  the `request` (its `job`, its `counterpart`, what it `sends`), the
  `correlation` key, the expected `answers` (each `form`, `when`,
  `carries`), the `timeout` (`after`, `then`: resend with the same key,
  escalate) and the `reactions`, named.
- **Two more parts**: `api`, a customer's `api` node the purpose calls or
  brings endpoints to; `partner`, a declared third party's node. A pushed
  obligation's `receiver` is a declared third party.
- **HTTP connections** in a job's `connections:`, named for the part they
  reach (the scheduler's `http` driver).
- **Endpoint material**: `material/api/<node>/routes/` and `db/`, the
  endpoints a purpose brings to a customer's `api` node, as a domain's
  `producers/api/<node>/`; a receiver with no stream of its own keeps its
  stub in the purpose, a partner with streams of its own stays in its
  domain's `producers/partners/<partner>/`.
- **Periodic purposes**: a periodic job names its daily `feeder`, the
  witness within the aging; `history: material/history.sql` plants the
  past periods' outputs into the target before T0 (for a target
  belonging to no domain, `load-data` runs it after the sources' loads,
  as the superuser, through a temporary foreign server, every session
  unseen). No periodic report runs on demand.
- **How an invariant is judged** (`judged:`): `runs`, `triggers`,
  `end-to-end` (on the trace after the fix; the backlog is the answer
  key's), `code` or `definition`; a round trip names exactly one
  `end-to-end` invariant.
- **Its own `classification:`**: a purpose whose target belongs to no
  domain, or which adds tables to a domain's database, classes their
  columns under `columns:`, keyed as a scenario's copy keys them
  (`<database>.<table>.<column>`).
- **The `ops` schema**: a purpose's own tables in a domain's database
  (ledgers, incidents, watermarks) live in schema `ops`, never in
  `public`; a target belonging to no domain keeps them in `public`. Every
  run writes one `ops.runs` row (or the target's `runs`) in the same
  transaction as its output.

### Domain (v0.4 master spec 6.8, 11.3; v0.5 master spec 6.1, 8.2 to 8.6)

Every key of [templates/domain.yaml](templates/domain.yaml), each path
naming a file of the domain folder that exists (`producers` a folder),
and `docs/gm.md`; the folder as [templates/layouts.md](templates/layouts.md)
lays it out. The procedure's checklist
(`specs/versions/v0.5/domain-procedure.md`, section 3) and formats.md "A
domain is done" are the definition of done; `model.check_domain_dir`
checks what a script can decide. Capture W1 item 7 of `specs/versions/v0.5/wave-log.md` settles the
keys. In particular:

- `id` (the folder's name), `title`; no `version`. `purposes`: the ids of
  the purposes that fit (may be `[]`; each id's form is checked, not that
  the purpose exists yet).
- **Core and part.** A core has no `requires` and may be taken alone. A
  part has `requires: [<core>]`, one item, a domain beside it that is no
  part itself (one level only); `lands_with`, `databases` and `derive`
  are a part's keys only. `lands_with` names its core. With `databases`
  (each `[a-z_][a-z0-9_]*`, once) `schema` and `load` are absent and
  `data/<database>/schema.sql` and `load.sql` exist for each; without,
  `schema` and `load` are required. `derive: {after: [...]}` names other
  domains of the catalogue and needs `data/derive.sql`, run only when
  the scenario's composition record sanctions it.
- `schema.sql` and `load.sql` follow the data load's contract
  ([templates/layouts.md](templates/layouts.md)): each `CREATE DATABASE`
  and `CREATE ROLE` at the start of a line, unquoted; `load.sql` may read
  the two `psql` variables `:'customer_timezone'` and
  `:customer_utc_offset`. Every `SECURITY DEFINER` function carries a
  fixed `search_path` (D323; checked at the domain's build).
- **Classification** ([templates/classification.yaml](templates/classification.yaml)):
  every column of every table under `columns:`, each `personal`,
  `customer-linked` or `internal`, `internal` ones listed too, keyed
  `<table>.<column>` (`<schema>.<table>.<column>` outside `public`,
  which is never written) **without the database**: a key whose first
  name is a database the schema files create or `databases` lists is
  refused. The scenario's copy adds each table's database
  (`<database>.<table>.<column>`, four names outside `public`). A part
  with several databases keeps its keys unique across the part.
- **The register fragment** ([templates/register.yaml](templates/register.yaml)),
  `register`, required of every domain: one entry per processing
  activity (its id, unique, the domain's prefix first; name; purpose;
  people, may be `[]`; tables; retention, a period and `erased` or
  `anonymised`, game values stated as such), and **every table of the
  schema files in exactly one activity** (D334), a partition (`CREATE
  TABLE ... PARTITION OF`) with its parent; a table listed that the
  schema does not create is refused.
- **The business's own rules**, when it has any: `policy`
  (`docs/policy.md`) and `governance` (`data/governance.yaml`, a
  `governance:` fragment), both or neither.
- **Producer material** (D344): `producers/` holds folders only, never a
  fragment at its root. `producers/<node>/`: the `queries.yaml`,
  `schedule.yaml` and `jobs.yaml` fragments for the scheduler node of
  that name, `builders/`, `scripts/`; `producers/api/<node>/`: an `api`
  node's `api.yaml` fragment ([templates/api.yaml](templates/api.yaml);
  `endpoints.<name>` with `hosts` and optional `credentials`,
  `connections.<name>`), `routes/`, `db/`;
  `producers/partners/<partner>/` (or `producers/public/<name>/` for a
  traffic source that is no business): the partner's back-end fragments
  and its `api.yaml`, `routes/`, `db/`. `api`, `partners` and `public`
  are reserved, never a node's name. A fragment holds only the entries it
  adds, parses as the scenario file would, never carries `intensity`, a
  `timeline` or a planted fault; its rates are the variant's throughput
  at intensity 1.0; a part prefixes its keys, connections and shapes.
- **Variants** ([templates/variant.yaml](templates/variant.yaml)): at
  least one `variants/<variant>.yaml`. A core's names its `parts` (may be
  `[]`; each a domain requiring this core, with a manifest of the same
  name), sets the three `scale` axes (`population`, `history`,
  `throughput`, each a non-empty map of name to number or text), lists
  `purposes` among `domain.yaml`'s, and takes its `tags` from the
  vocabulary only (maturity `homebrewed`, `managed`, `industrial`, at most
  one; reach `local`, `regional`, `national`, `global`, at most one;
  traits `regulated`, `multi-site`, `24/7`, `seasonal`). A part's
  manifest takes its core variant's name, holds `scale` and `purposes`
  only, and its core's variant names it (D301).
  `variants/<variant>/producers/`, optional, is the variant's profile,
  overrides only, laid out as `producers/`.
- **GM notes** (`docs/gm.md`): the business, the data, the roles, the
  classification, the producer, the rules, the traps (each with its
  class), loading; a part's "Core keys used"; each producer's growth an
  hour at intensity 1.0 and each shipped type's retention on site.

## Versions and pins (v0.2 master spec 6.5, v0.3 master spec 6.6, v0.4 master spec 6.6)

- **Bricks.** Any change to a brick bumps its version, whatever part of
  its folder changes (image, `brick.yaml`, validator, documentation,
  companion material), even with a byte-identical image; only a change
  confined to the brick's tests (`tests/`) bumps nothing. A change made
  while the new version is unreleased folds into it. A brick version is
  released only when the release gate of the version that builds it
  passes; a build wave merging into `main` releases nothing (D100). New
  bricks start at 0.1.0.
- **One version per brick in the catalog.** The scripts refuse a pin that
  does not match the brick's `version`, so bumping a brick re-pins every
  scenario and fixture that uses it in the same change, adds the new
  version to the `applies_to` of every fault that still applies, and
  brings its `docs/gm.md` (image tag, Supported faults) to the new
  version.
- **Faults and scenarios never bump.** They keep their version whatever
  changes; git history is the record. A pin to a fault names the fault,
  not a state of it; nothing pins a scenario.
- **Purposes and domains** (from v0.4) carry no version and never bump:
  their material is copied into a scenario at design time, and nothing
  pins them.
- **Companion material** has no version of its own: it is versioned with
  the brick that ships it (the node-health script with `prometheus`).
