# v0.6 — the network overview, a player handout

Status: draft v1. The rulings are settled (D480–D485); everything else
on this page is proposed, and the open points are O260–O268
([questions](#questions-for-the-owner)). It follows the
[data register handout](../v0.5/data-register-handout.md) and its
`data-register` skill wherever it can.

## The rulings (D483–D485)

The owner, on 2026-11-13, relayed by the coordinator:

- **A network overview page (D483).** The network information leaves the
  player README for a page of its own, linked from the game's home page
  (D480). Nodes go by their **Docker name**, never an IP. Each links to
  Grafana's **Node health** dashboard for its activity (CPU, memory,
  disk). The graphs read **the customer's Prometheus**, not a GM-side
  collector, so the customer's monitoring faults show through.
- **Customer documentation, a player handout (D484).** The page may be
  incomplete or wrong, like the data register (D330). This answers O21
  for this page.
- **Per node, ideally (D485):** its name (the Docker name); its system
  (Linux, version and so on); its role; a description; its sizing; the
  players' access, read-only, write or none (none for an external
  third party's node, if documented); the significant applications
  running, with their versions; its known users, people and
  applications, mostly applications through their roles, with room for
  a person working directly on a database although no case has one
  today; the third parties it uses; its background tasks (name, timing,
  description); its backup strategy. In the owner's words, the intent is
  "this database is fed by this application, and this application in
  turn uses the data for its own purposes, roughly". The data register
  is data-centric; this page is the node-centric view of the same
  facts.
- **No map or diagram (D482).** The game is one private network, third
  parties aside. The page is text and tables; a map comes with the
  fictional provider's networks.

## 1. What the page is

A real IT team keeps an inventory of its servers: one page or one row
per machine, what it is for, what runs on it, who connects to it, what
runs at night and how it is backed up. It is written once and updated
when someone remembers. The handout takes that shape, with one entry
per node of the customer's estate (proposed).

**Grouping** (proposed): by what the node is for, in this order:

1. the database servers (`database`);
2. the applications (`producer`, `api`) and the integration and
   back-office engines (`transformer`);
3. the monitoring (`monitoring`, the exporters included);
4. a closing **third parties** table (O262).

Within a group, the order is `scenario.yaml`'s. The clinic comes to 21
entries and nine third-party rows, about 400 lines of Markdown: longer
than the register, so the page opens with a one-line-per-node summary
table (name, role, description, access), each name linking to its
entry.

**The header** (proposed, fixed text, never a deviation): the customer's
name (from the story); one line on the network ("one private network;
the partners' services are reached on it by name; from outside, only the
bastion's SSH port and web port are reachable"); a note on the bastion
(O261); the link to Node health for the whole estate; and one sentence
on trust: "This is the centre's own documentation, kept by its IT. The
**Your access** column is the game's rule and always exact (O260)."

## 2. One entry: its fields and their sources

Every field is generated from the authoritative files, never written by
hand. "Gap" marks a field with no source today, and the proposal that
would give it one (O263).

| Field | What it says | Source today | Gap |
|---|---|---|---|
| **Name** | the Docker name, the name the node answers to on the network (`ssh records`, `psql -h records`) | `scenario.yaml` `nodes[].name` | none |
| **Role** | in-world words: database server, application, API, integration engine, back-office engine, monitoring | `nodes[].role` (the closed list), mapped by a fixed table in the skill; `producer` and `transformer` split by `role` | none |
| **Description** | one line on what the node is for, in the customer's words | none: the README's "What it is" column is written by the GM | a `description:` on each node in `scenario.yaml` (O263) |
| **Site** | where it stands, when it matters ("the off-site room") | none: the README derives it from `designed_for.placement` (the VPS), a physical fact a GM may change with `fit` | an optional `site:` on the node (O263); omitted when absent |
| **System** | the operating system and its version | none in `brick.yaml`: only the Dockerfile's `FROM debian:13-slim` | a `base:` in `brick.yaml` (`{os: Debian GNU/Linux, version: "13"}`), checked against the image's `/etc/os-release` by the brick's tests (O263) |
| **Applications** | what runs on the node, with versions: the brick's technology; on a database server the preloaded extensions, the options, the report tools and the cron daemon | `brick.yaml` `technology` (name, version), `options`, `report_tools`; the node's `options:` and `crontab` seed; `postgresql.conf`'s `shared_preload_libraries` | none. A scheduler or API node shows what is installed (`gm-scheduler 0.3.0` on Python 3.13; FastAPI 0.162.0), which the players see on disk anyway; its in-world identity ("the vendor's practice software") is the description's |
| **Sizing** | CPU and memory limits, what is reserved, the disk allotted | `nodes[].resources` (`limits`, `reservations`) | none |
| **Your access** | write, read-only or none, with any path-level exception ("write: its database side, `/srv/api/db/`") | `nodes[].write_policy`; the scenario's write overrides; the brick's `writable_paths` | none. Never a deviation (O260) |
| **Activity** | the link to Node health for this node | the node's name; the route `grafana` in the bastion's `web_routes` | the dashboard's `node` variable (O264) |
| **Databases** (database servers) | each database, with what it holds in one line and the data register's entries held there | `nodes[].data.databases` (names, table descriptions); the domains' `at:` and their titles; the register's `index:` | none |
| **Fed and used by** (database servers) | each application connecting: its node, the database, the role it connects as, what it does there (reads, writes, for what) | the composed `schedule.yaml` and `api.yaml` connections (`target`, `role`); the purposes' job `connections`; the monitoring configs (`exporter.conf`, pgwatch's `sources.yaml`, `health.yaml`); `standby_of` (the `replicator` role); the `pg_cron` jobs' roles (`data/cron.sql`, purpose material) | what a role does there: today SQL comments (`CREATE ROLE ... -- the information system (lis)`) and each domain's `docs/gm.md` "The roles" table, prose. A `roles:` list in a new domain fragment `data/overview.yaml` (O263) |
| **Uses** (applications) | the databases it connects to (as above, from its side) and the APIs and partners it calls | the same connections, read from the node's side; `credential` names for HTTP | none |
| **Users** (people) | people who work on the node directly: the staff on the practice software; a person on a database, when a case has one | none: `scenario.yaml` `flows:` says "the practice software's record, agenda..." in prose | an optional `users:` on the node (`who`, and for a database `database` and `role`); empty for the clinic's databases (O263) |
| **Third parties** | each partner the node reaches, by its `partners.md` name, with a link to its section | the HTTP connections whose `target` is a `third_parties:` hostname; `postgres`'s `vault_target`; `health`'s checks against a partner (its crontab) | none |
| **Background tasks** | each scheduled task: name, when (with its time zone), what it does | the composed `jobs.yaml` (`name`, `at`, UTC); the `crontab` seed files; `pg_cron` jobs (`data/cron.sql`, purpose material); for a purpose's job, `purpose.yaml`'s `computes:` | a description for a domain producer's job and a `pg_cron` job: a `jobs:` list in `data/overview.yaml` (O263); for a crontab line, the comment line directly above it (a rule for the GM's crontabs, O263) |
| **Backups** | how the node's data is protected: a streaming standby, WAL archiving and to where, base backups and when, what checks them; "none" when nothing does | `standby_of` (on the standby); `postgresql.conf`'s `archive_mode` and `archive_command`; `postgres`'s `vault_target`; the base backup lines of the `crontab`; `health`'s `backup-there` lines | none |

**Times** are written as the node runs them: `jobs.yaml` and crontabs
in UTC, `pg_cron` in `cron.timezone` (the customer's zone,
`{{customer_timezone}}` filled at render as the README's is). The README
already says the machines' clocks are in UTC.

**The system as designed** (O268). Several sources are seed files a
system fault may change in the scenario's copy: `postgresql.conf` (s2's
silent `archive_command`), a `crontab`, a composed `jobs.yaml` (a job at
the wrong hour). The true overview describes the system **as designed,
before any fault is planted**, as the true register does. Where a fault
instance's `seed_changes` touch a file the skill reads, it takes the
value before the change; the fault's `change:` text says what changed.
A system fault then shows as the system disagreeing with a true page,
which is the players' work; it never makes the page agree with the
fault.

## 3. One set of facts, three views

**The data register.** Both handouts come from the same facts: the
register says which data sits in which `node/database` and who receives
it; the overview says which nodes exist, who connects to them and how
they are protected. They are kept consistent by construction (proposed):

- a database server's **Databases** lists, for each database, the
  register entries its `index:` gives, linked
  (`data-register.md#<entry>`);
- the overview never restates the register's columns, classes or
  retention;
- a register fault leaves the overview true, and an overview fault
  leaves the register true. Each is planted in its own handout (O265).

**The access mapping** (D485), from the write policy (planes-and-access
"write policies"):

| Write policy | Your access | Meaning |
|---|---|---|
| `fixable` | **write** | change the configuration; explain it in the report |
| `report-only` | **read-only** | log in and look; report and propose |
| `no-access` | **none** | a third party's: only what it publishes (O262) |

A write override on a report-only node adds its paths ("read-only;
write: `/srv/api/db/`"). Where the brick's writable paths narrow a
fixable node, the entry says so (the README's "fixable: its database
side" for `lab-api`).

**The bastion** (O261). It is the players' kit, not the customer's
system (D65, D87): its tooling is not judged as the customer's. It is
not a node entry. The header carries one fixed line: "You work from
`bastion`, your access point; [its activity](...)". The line is never a
deviation. Its Node health stays on the dashboard, as today.

## 4. Generation: the GM's `network-overview` skill (proposed)

A GM sub-skill, `.claude/skills/network-overview/`, on the
`data-register` model: generated from the authoritative files, never
edited by hand, regenerated rather than reconciled.

- **Inputs**: `scenario.yaml` (nodes, resources, write policies and
  overrides, `web_routes`, `third_parties:`, `standby_of`, the fault
  instances); each node's seed files the table above reads; each brick's
  `brick.yaml` at its pinned version; each composed domain's
  `data/overview.yaml` and `data/cron.sql`; each purpose's
  `purpose.yaml`; `player/partners.md`; `gm/data-register.yaml` (the
  index, for the links); `gm/answer-key.yaml`.
- **Outputs**:
  - **`gm/network-overview.yaml`**, the true overview, sealed like the
    rest of `gm/`, opening with `generated_from:`, each input's digest;
  - **`player/network-overview.md`**, the handout: the true overview
    rendered as is, or with a planted overview fault's change applied;
    absent when that fault is the page's absence;
  - **in the answer key**, each overview fault instance's
    `overview_diff:` (section 5).
- **When**: at Setup step 2, after the data register and before the
  scenario document, which reads both (format, register, overview,
  document); after any change to its inputs.
- **Completeness** (the loader): the digests; the coverage of the true
  overview: every node of the customer's estate in exactly one entry
  (the bastion and the third parties' nodes in none); every partner with
  a `player_doc` in the third-party table; every database connection of
  every composed config under some **Fed and used by**; every job,
  crontab line and `pg_cron` job under some **Background tasks**; every
  database of every database node under **Databases**; every
  `standby_of`, `archive_mode = on` and base backup line under some
  **Backups**. A miss is a generation error, never a fault. And the
  handout: present unless the answer key declares it absent; never a
  third party's node name in it (as D469 refuses one in the register);
  **Your access** and the header equal to the true overview's (O260,
  O261).
- **Which scenarios**: every scenario listing `domains:`, as for the
  register (D335) (proposed); a fixture, whose id starts `fixture-`, is
  exempt; v0.4's shop and earlier scenarios are exempt until next
  revised.

## 5. Deviations as faults

**Injection**: a `seed-file` fault on the bastion,
`seed_changes: network-overview.md`; the skill writes the handout with
the change, the system is untouched. Ids `docs-overview-*`, family
`documentation` (bricks-and-faults.md's example family, waiting on O21
until now) (O266).

**The answer key**: `overview_diff:` on each overview fault instance,
required there and refused elsewhere, the shape of `register_diff:`:
`{node, field, true, handed_out}`, one item per node and field changed;
`field` one of `description`, `site`, `system`, `applications`,
`sizing`, `databases`, `fed_and_used_by`, `uses`, `users`,
`third_parties`, `tasks`, `backups`, or `entry` for a whole entry
missing or invented (its `true` or `handed_out` then `absent`); the one
item `{absent: true}` for the page's absence. `access` is never a
field. The scenario document shows each diff in a "Network overview"
section.

**Resolution**: *propose* (O266): the players give the corrected entry
in their report, and the GM judges it at the final answer against the
diff. The sealed check reads only that the change is present in the
bastion's copy. The report is the players' business, written where they
like (D481).

**The traps**, a generic catalogue (proposed; numbered when a
scenario's catalogue takes them). Each witness is the page read against
the system:

| # | Trap | Witness |
|---|---|---|
| N1 | A node missing: a server nobody documented (`pgwatch`, or a whole database server) | `ssh`, Prometheus's targets, Node health's node list |
| N2 | A node invented: a server decommissioned but still listed ("`reporting`, the old report server") | the name does not resolve; no data in Node health |
| N3 | A stale version: "PostgreSQL 16" on a PostgreSQL 18 server, an older Grafana | `SELECT version()`, the tool's own page |
| N4 | A wrong sizing: "4 GB memory" on a node limited to 1 GB | Node health's memory limit; the node's cgroup |
| N5 | A claimed backup that does not exist: `machines` "WAL archived to Cold Storage" (it sends its nightly base backup only), or `lab` "streamed to a standby" | `archive_mode`, `pg_stat_archiver`, `pg_stat_replication`; the vault's manifests |
| N6 | A background task wrong or missing: the base backup "at 02:00" (the crontab says 03:30), the portal's session purge not listed | the crontab (`sudo gm-crontab -l`), `cron.job`, `jobs.yaml` |
| N7 | A user missing: the back office's reads of the record on the standby (`vet_reports`) not listed; or a role listed that nothing uses | `pg_stat_activity`, `pg_hba.conf`, the configs on the application nodes |
| N8 | A third party missing: Cold Storage absent from `records`' third parties | `archive_command`, the base backup line; `partners.md` |
| N9 | The page absent: the README names it, the home page has no such document | the README; the home page |
| N10 | The page vague: "our servers", no versions, "backed up nightly" everywhere | the entries themselves |

**The class**: M by default, as a register fault (D290). N5 can rise to
V or D when the story leans on the claimed backup (an issue asking
whether `machines` can be brought back to yesterday noon). A system
fault that the page's truth makes easier to see (s2's silent archive,
next to a page saying "WAL archived") is no overview fault; the answer
key notes the help.

A GM selects among these at deploy (fault selection is the GM's);
v0.6 builds the family and at least one of them with its short test.

## 6. On the bastion's front

- **Its own page**: the handout rendered as a page of the documentation
  site, beside the other handouts (O267), and copied into
  `/home/player` as the seventh optional seed file of the bastion,
  `network-overview.md`, as `data-register.md` is.
- **The home page's link**: under "Documents", "Network overview", only
  when the scenario has one (D221's rule: no dead link).
- **The Grafana link** (O264): today the dashboard (uid `node-health`)
  has no template variable and shows every node at once. Proposed: a
  `node` variable (`label_values(node_health_cpu_limit_cores, node)`,
  multi-value, "All" by default), every panel's query filtered by
  `{node=~"$node"}`, and each entry linking
  `/grafana/d/node-health/node-health?var-node=<name>&from=now-6h&to=now`;
  the header links the dashboard with every node. It reads the
  customer's Prometheus through Grafana's data source, so a target
  missing from `prometheus.yml`, a node left out of the node-health map
  or a broken dashboard shows as an empty or wrong graph: a witness, by
  design. A `grafana` companion change, so a bump of `grafana`.
  Grafana's own login still applies (user `admin`, the tools password).
- **What stays in the README** (O267): how to get in (the bastion's
  login, the hops, `psql` and `~/.pgpass`), the rules about fixable and
  report-only work, "Each node in short" (where each kind of node keeps
  its files and logs: the game's how-to, which must be true), "Applying
  changes", "The jobs you may move", the validators, the rules, DO NOT
  TAMPER and the report. **What leaves it**: the node table (each node
  and its access) and the network paragraph, replaced by one line
  pointing to the network overview, whose **Your access** column is the
  rule (O260). Its "web interfaces" table shrinks to the home page's
  address.

## 7. Worked against the clinic (aldermoor-centre)

Three entries and the start of the third-party table, as the generator
would write them from today's files, with the proposed fields
(description, site, role and task descriptions) filled as the GM and the
domains would give them. Illustration only.

```markdown
### `records`

The record's database server: the medical record, the wards, the agenda,
the owners' portal and the back office's registers.

| | |
|---|---|
| **Role** | database server |
| **System** | Debian GNU/Linux 13 |
| **Applications** | PostgreSQL 18 (`pg_stat_statements`, `pg_cron`; the `monitoring` role), pgBadger, cron |
| **Sizing** | 1 CPU, 1 GB memory (0.5 CPU, 512 MB reserved); 2.25 GB disk |
| **Your access** | write |
| **Activity** | [Node health](/grafana/d/node-health/node-health?var-node=records&from=now-6h&to=now) |

**Databases**: `clinic`, the medical record, housing and the agenda
(register: [core-owners](data-register.md#core-owners), ...); `portal`,
the owners' portal; `office`, the back office's registers; `jobs`,
`pg_cron`'s jobs.

**Fed and used by**:

| Application | Node | Database | As | What it does there |
|---|---|---|---|---|
| the practice software | `pms` | `clinic` | `vet_app`, `housing_app`, `sched_app` | the record, the housing screens, the agenda |
| the ward service | `ward` | `clinic` | `vet_display`, `housing_ward` | the wards' displays; stays and boxes |
| the integration engine | `interfaces` | `clinic`, `portal` | `vet_interfaces`, `sched_interfaces`, `vet_portal_sync`, `portal_sync`, `portal_dispatch` | orders, exchanges, bookings; the portal's copies and messages |
| the back office | `backoffice` | `office` | `office_jobs` | the registers and figures it writes |
| the lookup API | `clinic-api` | `clinic` | `vet_lookup`, `vet_exchange` | the other centres' lookups and exchanges |
| the owners' portal | `portal-api` | `portal` | `portal_api` | the owners' accounts and pages |
| the session purge (`pg_cron`) | `records` | `portal` | `portal_housekeeping` | ends old sessions |
| the standby | `standby` | (replication) | `replicator` | streams the record |
| the monitoring | `exporter-records`, `pgwatch`, `health` | `postgres` | `monitoring` | statistics and checks |

**Third parties**: [Cold Storage](partners.md#cold-storage) (the WAL
archive and the nightly base backup).

**Background tasks**:

| Task | When | What |
|---|---|---|
| nightly base backup | 03:30 UTC, daily (crontab) | a base backup of the instance, posted to Cold Storage |
| `portal.sessions.purge` | 03:30 {{customer_timezone}}, daily (`pg_cron`, in `portal`) | deletes the portal's sessions ended or expired 30 days ago |

**Backups**: streamed to `standby` (the off-site room); WAL archived to
Cold Storage, at least hourly; a base backup nightly at 03:30 UTC to
Cold Storage, checked at 06:30 UTC by `health`.
```

```markdown
### `interfaces`

The centre's integration engine: its jobs move orders, results,
exchanges, notifications, the portal's publications and messages between
the centre's systems and its partners.

| | |
|---|---|
| **Role** | integration engine |
| **System** | Debian GNU/Linux 13 |
| **Applications** | gm-scheduler 0.3.0 (Python 3.13, psycopg 3) |
| **Sizing** | 0.25 CPU, 192 MB memory (0.1 CPU, 96 MB reserved); 128 MB disk |
| **Your access** | write |
| **Activity** | [Node health](/grafana/d/node-health/node-health?var-node=interfaces&from=now-6h&to=now) |

**Uses**: `records/clinic` as `vet_interfaces`, `sched_interfaces`,
`vet_portal_sync`; `records/portal` as `portal_sync`, `portal_dispatch`;
`lab/lab` as `lab_dispatch`, `lab_release`; `machines/pacs` as
`mach_orders`; `machines/vitals` and `machines/biomed` as `mach_archive`;
the lab's order API `lab-api` (credential `lab_centre`).

**Third parties**: [Northfield Veterinary Laboratories](partners.md#northfield-veterinary-laboratories),
[the region's practices](partners.md#the-regions-practices),
[Aldermoor Central](partners.md#aldermoor-central),
[Aldermoor South](partners.md#aldermoor-south),
[Aldermoor abroad](partners.md#aldermoor-abroad),
[the veterinary authority](partners.md#the-veterinary-authority),
[Cold Storage](partners.md#cold-storage),
[the franchise's messaging service](partners.md#the-franchises-messaging-service).

**Background tasks** (22; three shown):

| Task | When | What |
|---|---|---|
| `send-outs` | 16:00 UTC, Monday to Friday | the day's send-outs packed and posted to the external lab |
| `ship-partitions` | at 40 past each hour, 00:40 to 05:40 UTC | the machines' day partitions older than the window shipped to Cold Storage |
| `send-messages` | every minute | the portal's queued messages sent through the messaging service |

**Backups**: none on this node.
```

```markdown
### `pms`

The practice software, the vendor's: the record, the agenda, the
housing screens and the portal desk, used by the centre's vets, nurses
and reception.

| | |
|---|---|
| **Role** | application |
| **System** | Debian GNU/Linux 13 |
| **Applications** | gm-scheduler 0.3.0 (Python 3.13, psycopg 3) |
| **Sizing** | 0.25 CPU, 192 MB memory (0.1 CPU, 96 MB reserved); 128 MB disk |
| **Your access** | read-only |
| **Activity** | [Node health](/grafana/d/node-health/node-health?var-node=pms&from=now-6h&to=now) |

**Users**: the centre's vets, nurses and reception.

**Uses**: `records/clinic` as `vet_app`, `housing_app`, `sched_app`; the
owners' portal `portal-api` (credential `portal_desk`).

**Background tasks**:

| Task | When | What |
|---|---|---|
| `administrations-round` | 02:00, 06:00, 10:00, 14:00, 18:00, 22:00 UTC | the ward round: each active line's doses at its frequency |
| `prescriptions-expire` | 00:15 UTC, daily | the night's expiry of prescriptions |
| `rota-publish` | 12:00 UTC, Fridays | the week after next's rota published, its machine and theatre blocks booked |

**Backups**: none on this node.
```

```markdown
## Third parties

| Third party | Reached at | Used by | Your access |
|---|---|---|---|
| [Cold Storage](partners.md#cold-storage) | `cold-storage:8000` | `records`, `lab`, `machines` (backups); `interfaces` (shipped days); `health` (backup checks) | none: its published service only |
| [Northfield Veterinary Laboratories](partners.md#northfield-veterinary-laboratories) | `northfield-lab:8000` | `interfaces` | none: its published service only |
| ... | | | |
```

Notes on the illustration: `backoffice` reads the record on `standby`
(`vet_reports`, `sched_reports`), so those roles sit under the
standby's entry, not `records`'; `pms`'s task descriptions are the kind
`data/overview.yaml` would carry; the descriptions and the users line
are the kind `scenario.yaml`'s new keys would carry (O263).

## 8. Format impact (for the master spec)

- **`scenario.yaml`**: on each node, `description:` (required on the
  customer's nodes when the scenario has an overview), optional `site:`
  and `users:`; the answer key's `overview_diff:`; the bastion's seventh
  optional seed file `network-overview.md`, mapped to
  `player/network-overview.md`; `gm/network-overview.yaml`. No overview
  section inside `scenario.yaml`: the true overview is a generated file.
- **`brick.yaml`**: `base:` (`os`, `version`).
- **A domain**: `data/overview.yaml`, declared in `domain.yaml`:
  `roles:` (each login role of its schema: who, reads, writes, one line
  each) and `jobs:` (each producer job and `pg_cron` job: a one-line
  description); a checklist item, every login role and job described.
- **Crontabs written by the GM**: each entry has its description on the
  comment line directly above it.
- **The loader**: section 4's checks; `overview_diff:`'s shape; O251's
  refusal goes into the same chunk (D486).
- **The skills**: `network-overview` is new; `game-master`'s Setup step
  2 calls it; `scenario-document` gains a "Network overview" section;
  `scenario-format`'s checklist gains the new keys.

## 9. Build-plan chunks (a sketch, for the build plan)

1. **The format and the loader**: the new keys, the overview's checks,
   `overview_diff:`, and O251's refusal (D486).
2. **The skill and the front**: the `network-overview` skill and its
   template; the bastion's seventh seed file and the home page (O267);
   the dashboard's `node` variable (O264).
3. **The domains' fragments**: the six `data/overview.yaml` files, from
   each domain's `docs/gm.md` "The roles" and its producers' job
   comments; `brick.yaml`'s `base:` on every brick.
4. **A trap and the clinic**: one `docs-overview-*` fault with its short
   test, and the clinic's overview generated.

## Questions for the owner

- **O260**: Is **Your access** the game's rule, always exact and never a
  planted deviation? The page is otherwise customer documentation that
  may be wrong; a wrong access would mislead the players about the rules
  of the game, not about the customer. **Recommended**: yes. The column
  is marked as the game's rule, the loader refuses a handout whose access
  differs from the truth, and the README points to it instead of keeping
  its own table.
- **O261**: The bastion: a node entry, or a fixed note? **Recommended**:
  a fixed line in the header ("you work from `bastion`, your access
  point", with its Node health link), never a deviation. It is the
  players' kit (D65, D87), so documenting it as the customer's would
  invite judging it as the customer's.
- **O262**: The third parties: how do they appear? **Recommended**: a
  closing table, one row per partner with a `player_doc` ("if
  documented"), by the hostname the players call, access none, linking
  `partners.md`. The partners' shared nodes (`partners-api`,
  `partners-backend`, `partners-db`) are game plumbing standing for nine
  partners and are never named, as D469 keeps them out of the register.
- **O263**: Do you accept the format additions of section 8 for the
  fields with no source today: a node's `description`, `site` and
  `users`; a brick's `base`; a domain's `data/overview.yaml` (roles and
  job descriptions); the crontab comment rule? **Recommended**: yes,
  into v0.6's master spec. The alternative, the skill reading SQL
  comments, Dockerfiles and prose, is fragile and cannot be checked.
- **O264**: Add a `node` variable to the Node health dashboard, so each
  entry links its own node? **Recommended**: yes (a `grafana` bump). One
  link to the whole dashboard is the fallback: it works today, but a
  22-node graph hides the one the player came for.
- **O265**: The overview and the data register are planted
  independently. One may then give away the other's fault: with T307
  planted (Cold Storage missing from the register), the overview's
  **Backups** still name Cold Storage. **Recommended**: keep them
  independent. In a real organisation the infrastructure page names the
  backup vendor while the record of processing forgets it, and that is
  how such a gap is found. The answer key notes the interaction, and a
  GM wanting it harder plants a matching overview fault as a second
  instance.
- **O266**: How is an overview fault resolved and classed?
  **Recommended**: as the register's: *propose*, judged against
  `overview_diff:`; M by default (N5 higher when the story leans on the
  backup); family `documentation`, ids `docs-overview-*`.
- **O267**: The home page and the README. **Recommended**: the home page
  has two lists, **Sites** (each web route: Grafana, Prometheus, health;
  later the console and the partners' status page) and **Documents**
  (each handout present, each now a page of its own under `/docs/<id>`,
  a route named `docs` refused). The README keeps how to work and the
  rules, and loses the node table and the network paragraph to the
  overview.
- **O268**: The true overview reads seed files that a system fault may
  have changed in the scenario's copy. **Recommended**: the skill states
  the design, taking the value before the fault's change (its `change:`
  says what changed), so a system fault is never hidden by the page
  agreeing with it. The loader cannot check this; the scenario document
  shows the overview beside each fault for the GM's review. The
  alternative, keeping a clean copy of every seed file, doubles the
  scenario folder for one reader.
