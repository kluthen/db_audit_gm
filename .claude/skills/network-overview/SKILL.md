---
name: network-overview
description: Use whenever a db_audit_gm scenario's network overview has to be generated or regenerated — the true overview gm/network-overview.yaml, the player handout player/network-overview.md and each overview fault's overview_diff in the answer key — when a scenario listing domains: is composed or regenerated, after any change to its nodes, seed files, bricks, domains, purposes, third parties, story, data register or overview faults, and before deploying, at the game-master-setup skill's Setup step 2, after the data register and before the scenario document. Generated from the authoritative files, never edited by hand, regenerated rather than reconciled.
---

# Network overview

A scenario's **network overview** is game content (v0.6 master spec 8.1 to
8.4; capture W2 items 3 to 6 of
the v0.6 wave log): the
customer's own inventory of its servers, one entry per machine of its
estate, what it is for, what runs on it, who connects to it, what runs at
night, how it is backed up. It is customer documentation, which may be
incomplete or wrong (an overview fault), while its **Your access** column
and its header are the game's rule and always exact. The data register is
data-centric; the overview is the node-centric view of the same facts.
This skill writes it on the [data-register](../data-register/SKILL.md)
model: from the authoritative files, never by hand, and regenerated rather
than reconciled. This is its **v0.6 version**, expected to evolve as games
are played.

The skill writes three things:

| Output | What | Sealed |
|---|---|---|
| `gm/network-overview.yaml` | the **true overview**: `generated_from:` (each input's digest), the header, one entry per customer node, the third-party table ([template](template.md), part 1) | yes, like the rest of `gm/` |
| `player/network-overview.md` | the **handout**: the true overview rendered as is, or with a planted overview fault's change applied; **always present** in a scenario that has an overview ([template](template.md), part 2) | no: the bastion's seventh seed file `network-overview.md` |
| `overview_diff:` in `gm/answer-key.yaml` | for each overview fault instance, one item per node and field changed: `{node, field, true, handed_out}` | yes |

`gmctl` has no generator: the skill writes, the loader checks
(`tools/gm/model.py`, "the network overview"). The loader also gives the
facts its coverage reads, so the skill builds from the same reading:
`model.overview_inputs`, `model.overview_connections`,
`model.overview_tasks`, `model.overview_backups`,
`model.overview_databases` and `model.overview_header_lines`.

## Which scenarios

- Every scenario listing `domains:` has one: `gm/network-overview.yaml`,
  `player/network-overview.md`, the bastion's `seed_files:
  {network-overview.md: player/network-overview.md}`, and a
  `description:` on every customer node. The loader refuses such a
  scenario without them.
- **Exempt**: v0.4's released shop scenario (`domain: shop`, no
  `domains:`) until it is next revised; a **test fixture**, whose id starts
  `fixture-`. A fixture *may* have one, and one that has an overview is
  checked in full.
- Every domain of the catalogue declares its overview fragment,
  `overview: data/overview.yaml` (the format skill's `overview.yaml`
  template), naming every login role its schema files create and every
  job its customer producers' `jobs.yaml` and its `data/cron.sql` run; the
  loader refuses a domain missing one.

## When to generate or regenerate

- When a scenario is composed or regenerated (after `gmctl compose`), and
  after any change to its inputs (below): the loader refuses an overview
  whose digests no longer match ("stale overview: regenerate with the
  network-overview skill").
- At the game-master-setup skill's **Setup step 2**, in this order: the format check,
  the data register (its skill), then this skill, then the scenario
  document, which reads both. The register comes first: the overview
  digests it, and a change to `scenario.yaml` (a register input) is
  followed by the register's regeneration.
- After this skill's template changes, for the scenarios about to be used.

Never edit either file by hand, nor the `overview_diff:` it wrote: change
an input and regenerate.

## Inputs (master spec 8.4)

`model.overview_inputs(data, <scenario-dir>)` lists them, in
`generated_from:`'s order: `scenario.yaml` (nodes, resources, write
policies and overrides, web routes, third parties, standbys, fault
instances); each customer node's seed files the fields read
(`postgresql.conf`, `crontab`, `jobs.yaml`, `schedule.yaml`, `api.yaml`,
`exporter.conf`, `sources.yaml`, `health.yaml`, `prometheus.yml`) and its
data file; each customer node's `brick.yaml` at its pinned version; each
composed domain's `data/overview.yaml` and `data/cron.sql`; each purpose's
`purpose.yaml` and `ddl:` files; `player/partners.md`;
`gm/data-register.yaml` (its index); `gm/answer-key.yaml`;
`player/story.md` (the customer's name).

**The customer's nodes** (`model.overview_customer_nodes`): every node but
the bastion and the third parties' (`third_parties:` entries' `nodes`, and
the partners' shared nodes serving the owners alone). The bastion is the
players' kit: no entry, the header's fixed line only. A third party's node
is never named anywhere in the handout; the partners are named by the
hostname the players call and their `partners.md` name.

## Generating it, in this order

The answer key is both an input and an output: it is written first, then
every input is digested, so a plain byte digest stays current and any
later edit to an input makes the overview stale.

1. **The true entries**, from the inputs, **the system as designed**:
   where a selected fault instance's `seed_changes` touch a file the skill
   reads (`postgresql.conf`, a crontab, a `jobs.yaml`), take the value
   before the change. A seed-file fault's declared `lines:` are in the
   scenario's copy from T0 (O269): leave them out (the clinic's s2
   `archive_command`, s7 `log_statement`, s8 `recovery_min_apply_delay`),
   and never quote a faulted value. A system fault then shows as the
   system disagreeing with a true page, never hidden by the page agreeing
   with it. The loader cannot check this; the scenario document shows the
   overview beside each fault for the GM's review.
2. **The overview faults.** For each fault instance whose definition's
   `seed_changes` name the bastion's `network-overview.md` (family
   `documentation`, ids `docs-overview-*`), apply its change to a copy of
   the true entries and write its instance's `overview_diff:` into
   `gm/answer-key.yaml`: one item per node and field changed, `field` one
   of `description`, `site`, `system`, `applications`, `sizing`,
   `databases`, `fed_and_used_by`, `uses`, `users`, `third_parties`,
   `tasks`, `backups`, or `entry` for a whole entry missing or invented
   (its `true` or `handed_out` then `absent`); `true` and `handed_out` the
   field's lines as the handout writes them (a list stays a list). Never
   `access` nor the header; never an `{absent: true}` item: the page is
   never absent. The answer key is then final.
3. **The digests**: `model.file_digest(path)` of each input
   `model.overview_inputs` lists (`python3 -c 'from tools.gm import model;
   ...'` from the repository root), recorded as `sha256:<hex>` under its
   label; every expected input is listed, and nothing else.
4. **Write both files**: `gm/network-overview.yaml` (template part 1),
   then `player/network-overview.md` (part 2) from the entries as the
   faults left them. Map the bastion's `network-overview.md` to
   `player/network-overview.md`.
5. **Check**: the loader (`python3 -c 'from tools.gm import model;
   model.load_scenario("<dir>")'`, or any `gmctl` verb loading the
   scenario) must pass: digests, coverage, the handout. A coverage miss is
   a **generation error**, fixed here before the hand-over, never a fault.
6. Then the scenario document (scenario-document skill), whose "Network
   overview" section shows the counts and each `overview_diff:`, and the
   overview's lines beside each fault.

## Building the entries (master spec 8.2, 8.3)

One entry per customer node, grouped in 8.1's order, each group in
`scenario.yaml`'s order: **database** (the database servers), then
**application** (the applications and APIs), then **integration** (the
integration and back-office engines), then **monitoring** (exporters
included).

**Role**, the fixed table:

| `nodes[].role` | Group | Role |
|---|---|---|
| `database` | database | database server |
| `producer` | application | application |
| `api` | application | API |
| `transformer`, every purpose it runs (`runner`, `runner_reports`) targeting an `office` database | integration | back-office engine |
| `transformer`, otherwise | integration | integration engine |
| `monitoring` | monitoring | monitoring |

**Your access** (8.3, never a deviation): `fixable` **write**, followed by
the brick's writable paths but `/home/player`, in backticks, in brackets
(the paths narrow it: "write (`/etc/postgresql`)"); `report-only`
**read-only**, a write override adding its paths ("read-only; write:
`/srv/api/db/`"); `no-access` **none**. The loader checks the first word
against the write policy and that a report-only node's overrides are
named.

| Field | What it says | Source |
|---|---|---|
| `description`, `site` | one line each; `site` only when the node has one | `nodes[].description`, `nodes[].site` |
| `system` | "<os> <version>" | the brick's `base:` |
| `applications` | the technology and its version; on a database server, then the preloaded libraries, the options, the report tools, "cron" when it seeds a crontab | `brick.yaml` `technology`, `report_tools`; the node's `options:`, its `shared_preload_libraries` as designed, its crontab |
| `sizing` | "CPU <limit> (<reserved> reserved), memory <limit> (<reserved> reserved), disk <reserved disk>" | `nodes[].resources` |
| `activity` | `[Node health](/grafana/d/node-health/node-health?var-node=<node>&from=now-6h&to=now)` (master spec 8.6: the dashboard's uid and slug, the node, six hours); the header's bastion line links the same with `bastion`, its whole-estate line the dashboard with every node, `/grafana/d/node-health/node-health?from=now-6h&to=now` | the node's name; the `grafana` route |
| `databases` | each database (`model.overview_databases`), what it holds in one line, and the register's entries held there (its `index:`, linked to `data-register.md#<id>-<name slug>`; an internal line to `#internal-data`) | `nodes[].data.databases`; what the data file, the domains and the purposes create; the register's index |
| `fed_and_used_by` | each connection to the node (`model.overview_connections`): node, database, role, what the role does; the standby's replication (`standby_of`); each `pg_cron` job's role, "pg_cron's job <name>, on this server" | the composed `schedule.yaml` and `api.yaml`, the monitoring seeds; the domain's `data/overview.yaml` (`who`, `reads`, `writes`); a purpose's role in the customer's words |
| `uses` | the same connections from the node's side, then each HTTP connection: a customer API by node, a third party by its `partners.md` name; a monitoring node's HTTP flows | the same files; `flows:` for the scrapes and the dashboards |
| `users` | `nodes[].users` as written | `nodes[].users` |
| `third_parties` | each partner the node reaches, linked to `partners.md#<anchor>` | HTTP connections to a third party's hostname; the postgres `vault_target`; the health page's backup checks |
| `tasks` | each task (`model.overview_tasks`): a job by its name, a crontab entry by its description (the comment line above it), a `pg_cron` job by its name; when, in the zone the node runs it (UTC for jobs and crontabs, `{{customer_timezone}}` for `pg_cron`, filled at render); what, from the domain's `data/overview.yaml` or a purpose job's `computes:` | the composed `jobs.yaml`; the crontabs; the domains' `data/cron.sql`; the purposes' `ddl:` |
| `backups` | what protects the node's data (`model.overview_backups`): the standby (on the primary, naming it), the WAL archive (`archive_mode = on`), the nightly base backup (a crontab's `pg_basebackup` line), the health page's checks; the one item `{kind: none, line: none}` when nothing does | `standby_of`; `archive_mode`, `archive_command`, the vault target; the base backup lines; the health page's checks |

**One set of facts with the register** (8.3): a database's register
entries are the register's index, linked; the overview never restates the
register's columns, classes or retention. A register fault leaves the
overview true, and an overview fault leaves the register true.

The loader checks the coverage: every customer node in exactly one entry,
the bastion and the third parties' nodes in none; every partner with a
`player_doc` in the third-party table; every database connection of every
composed config under its target's `fed_and_used_by`; every job, crontab
entry and `pg_cron` job under its node's `tasks`; every standby, every
`archive_mode = on` and every base backup line under some `backups`;
every database of every database server under its `databases`. And the
handout: present and mapped; no third party's node named; the header block
(the lines before `## Summary`) equal to `model.overview_header_lines`;
each entry's **Your access** bullet equal to the true overview's. The
clinic comes to 21 entries and nine third-party rows, about 660 lines of
handout.

## Overview faults

Planted in the handout only (master spec 6.3, 8.3): the fault's
`seed_changes` is the bastion's `network-overview.md`, the scenario's
handout carries the change, and regenerating without the fault clears it.
The loader accepts a handout that differs from the true overview anywhere
but the header and **Your access**; the `overview_diff:` says where. One
fault may give away another's (Cold Storage missing from the register
while the overview's **Backups** still name it): the answer key notes the
interaction, and a GM wanting it harder plants a matching overview fault
as a second instance. Fault selection is the GM's.

## On a restart, and during the game

On a restart the GM reads the true overview with the scenario document.
During the game it never shows or quotes the true overview nor an
`overview_diff:` (no reveals, gm-stance): the players compare the handout
with the system.

## Never edit it by hand

Both files and every `overview_diff:` are generated. A wrong entry is
fixed in its input (`scenario.yaml`, a seed file, a domain's fragment, a
purpose) and the overview regenerated; a stale digest is cleared only by
regenerating.
