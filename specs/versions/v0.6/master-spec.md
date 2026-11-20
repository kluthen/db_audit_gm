# db_audit_gm v0.6 — Master specification

Status: **approved by the owner on 2026-11-16** ("agreed for both
question, you may proceed on the build plan"), the points settled while
closing the review standing as written. Consolidated on the owner's
word ("have a reviewer check out spec v0.6 then consolidate") from
v0.6's three draft documents (the
version page, the network overview, fake aging) and the owner's
rulings of 2026-11-13 to 2026-11-16, after an independent review of the
drafting whose findings were all closed before consolidation. Every
point is stated here as fact. Companion: [access-model.md](access-model.md).
Amended in wave 1, from capture W1's preflight corrections: a
`seed_changes` item's declared `lines:` (6.3, 6.9, 6.10; spec D521);
`admitted.from` in hours only (6.9; spec D522). Amended after chunk 8:
the fill's cover for a routine that pins its own `search_path`, its
catalog tell a documented limit (9.4, 9.8, 9.10; spec D523); the seed
and the plantings at T0 dated from the virtual T0 (9.4, fix 11; spec
D525). Amended in wave 2, from capture W2's preflight corrections and
the owner's answers: 8.7's README named as the starter pack's
`player/README.md`; fix 11's DDL rule (9.9; spec D529); the fill's
pause plantings at their virtual instant (9.4, fix 11; spec D527).
Amended during chunk 9: where `gm_vclock` sits on a path, for the
sessions and the cover (9.4, fix 11; spec D530); a covered instant's
lead in the tail (9.6; spec D532). Amended after wave 2's gate (gates
G10.1, G10.2): the forms as built, stated in formats.md v36 (6.7, 6.9;
spec D534); the story line's wording (9.4); `clean-restart` never
before the planned anchor, the tail counting from the restart's
instant (9.4, 6.9; spec D535); the statistics reset in the restart's
procedure, before the stop (9.4, 9.9 fix 2, 9.10; spec D536); a data
file's last virtual write (9.9 fix 8); the scenario document showing an
instance's `admitted:` (7.6; spec D537). Amended in wave 3, from capture
W3's preflight corrections: the players' shell on the Prometheus node,
the TSDB folder keeping the imported blocks from it (9.10, 18; spec
D540); Prometheus' own series showing the import, a documented limit
(9.10; spec D541); no refused instance a handout names in a GM-run game
(9.1, 9.8, 12.2; spec D542); `suppressed_by` from the hiding instance's
planting (6.3, 9.5; spec D543); the setup's measured time in the
scenario document's "Fake aging" section, for the quick game's
duration (9.2, 9.10; spec D544). Amended after chunk 11a, from run R:
the shop's f9 hides f4 in state and logs only, so no `suppressed_by`
pair in the shop, and its f5 carries no `daily_spike` (6.9, 9.8; spec
D548). Amended after chunk 11b: the campaign's f5 hides f4 and f7 in
state and logs only, so no covered fault carries a `suppressed_by`, the
rule unit-tested only; a report-only node's keys timed from a fill or
with psql (6.9, 9.5, 9.7, 9.8; spec D578). Amended after wave 3's gate
(gate G10.3): the forms as built, stated in formats.md v39 (6.3, 6.7,
6.9, 9.5, 9.7; spec D580); the seam check's findings, its join checked
on size gauges (9.4, 12.1; spec D581); a fake game's restart with no
history (9.4; spec D582); one import at a time, a failed seam never
imported again (9.4; spec D583); what wave 3 measured (9.4, 9.8, 12.1,
18). Amended in wave 4, on the owner's ruling after capture W4: the
shop's M1 comparison scales the saved real run to the game's span
(12.1; spec D586). Amended in wave 4, on the owner's ruling after G8:
PostgreSQL 19 everywhere, server, client tools and libpq, folded into
the unreleased versions (6.8, 7.7, 8's N3; spec D587). Amended in wave
4, on the owner's rulings after chunk 12b's shop game: `n_live_tup`
reported, not judged, and one row's leeway for a small count (12.1;
spec D593, D596); the forged past's counters follow what drives them
(9.9 fix 12; spec D594, D595). Amended after wave 4's gate (gate
G10.4): the forms as built, stated in formats.md v41 (9.7, 9.9 fix
12, 9.10, 12.1; spec D597); what wave 4 measured (18).

Baseline: the released [v0.5 master spec](../v0.5/master-spec.md) and
its [access model](../v0.5/access-model.md). Everything v0.5 specifies
stays in force unless this document changes it; where they disagree,
this document wins for v0.6. The cross-version format rules are in
[formats.md](../../formats.md), which this consolidation brings to
draft v34 with v0.6's format items (section 6).

---

## 1. Concept and objective

db_audit_gm generates live database audit exercises: an agent, the game
master (GM), deploys a deliberately flawed data stack on a container
cluster, hands it to students (the players) through a single bastion,
receives their report and gives teacher-style feedback. v0.1 settled the
GM's stance on one static PostgreSQL database, v0.2 added monitoring and
the usual tooling, v0.3 made the stack alive with producers and
consumers aging it in real time, v0.4 added purposes, several instances
and a first cut of data governance, and v0.5 defined business domains
with a veterinary clinic as the worked example.

v0.6 has two subjects.

**The bastion becomes the players' main activity point.** In the
owner's words, it publishes the dashboards and monitoring tools, hosts a
documentation website and provides general-use tooling. Everything
stays within one game: its web front, for its players. Concretely:

- a **home page** on the bastion's web front linking every site of the
  game and every document handed over (section 7.2);
- a **documentation site**: the starter pack, the customer's handouts
  and the player documentation of every brick the players work on, each
  a page of its own (section 7.3);
- the **network overview**, a new player handout: the customer's
  inventory of its servers, one entry per node, generated from the
  authoritative files, customer documentation that may be incomplete or
  wrong, each node linked to its activity in Grafana (section 8);
- **reports** the players produce in the stack (pgBadger, pgCluu)
  readable in the browser through the front (section 7.5);
- a **status page per third party**, showing the incidents that
  partner admits (section 7.6);
- **`jq` and `tmux`** added to the bastion's tooling (section 7.7).

**Fake aging, a second aging mode for quick games.** Real aging (the
stack running in real time for the scenario's declared hours, at least
eight) stays for extended games. Fake aging joins it: the scenario's
past is filled in minutes on a virtual clock before the game, the
customer's servers are restarted "for maintenance", a real tail of at
least an hour runs, and Prometheus receives a forged history for the
filled past. The owner's direction: "a quick game can still be started,
and extended one remains available with true aging"; every fixable
caveat of the technique is fixed and every one that can't be is
documented; a fake-aged game curates its faults so that none relies on
a known limit of the technique. The bar is that a student doing the
audit doesn't stumble on the fake. v0.6 makes the shop and the campaign
fake-ageable; the clinic comes later (section 9).

Two smaller items ride along: the **GM's feedback in two parts**, a
customer-side assessment then a teaching moment (section 10), and
**English** as the language of all player-facing material (section 11).

## 2. Scope

### In scope

- The bastion's web front as the game's home: the home page, the
  documentation site, the reports folder, the partners' status pages
  (section 7); `bastion` 0.6.0.
- Every handout a static snapshot of the mission's start; which
  starter files may carry a planted inaccuracy (section 7.4).
- The network overview: its fields, the format additions that give each
  field a source, the GM's `network-overview` skill, the loader's
  checks, overview faults in a new `documentation` family with at least
  one built and tested, Node health's per-node variable (`grafana`
  0.4.0) (section 8).
- Two loader refusals carried from v0.5: the bastion maps the partners'
  page exactly when the third parties carry a player document; each
  selected seed-file fault instance's declared lines
  (`seed_changes[].lines`) are found in its node's copy of the seed
  file (section 6.10).
- Fake aging: the mode and its choice, the initiator who also plays, the
  timeline and the GM's steps, the fault format's eligibility and
  history signature, the tail, calibration, the ten fixes, the
  documented limits, what the players are told and when, the product's
  shape (`scheduler` 0.4.0's fill mode, `gmctl fill`, `clean-restart`,
  `history`), the restart record; the shop and the campaign made
  fake-ageable (section 9).
- The GM's feedback in two parts (section 10); English for all
  player-facing material (section 11).
- `base:` on every brick, so every brick takes a new version
  (section 6.8).
- Short tests only, each under 30 minutes; the long checks join v1.0
  gating (section 12).

### Out of scope (deferred, still part of the project)

- A front, homepage or proxy above several games, a setup-wide
  homepage, a shared Caddy, per-game passwords behind a shared front:
  dropped, "nor is it expected any time soon". The front is one game's.
- A reporting tool: the players write their report where they like.
  A data-register fault stays resolved by *propose*, the corrected
  entry written in the report, with no corrected file handed back.
- A network map or diagram: the game is one private network, third
  parties aside. A map becomes mandatory with the fictional cloud
  provider after v1.0.
- Any other way in: the bastion stays the only one.
- The bastion's tooling judged as the customer's: it is the players'
  kit, and never counts when judging whether the customer's tooling is
  proportionate.
- Fake aging for the clinic: later (it needs a standby and a base
  backup built after the fill, the vault's gap, two hosts).
- Non-fault notices on a partner's status page (a planned maintenance
  announced, say): later. v0.6's pages show admitted fault incidents
  only.
- A scenario language option: later. v0.6 is English throughout.
- A score and the feedback written to a file: still open (section 18).
- Fake time in any form: no sped-up or fake clock, no NTP games, no
  container clock. Ruled out, not deferred.

## 3. Actors

As in v0.5: the GM; the initiator (a teacher, or a student playing
alone); the players; the customer and its partners, in the fiction
only. One change: **the initiator may also be a player**, and the GM
now asks which (section 9.2). The access model's actors are unchanged;
its v0.6 changes are in [access-model.md](access-model.md).

## 4. Glossary (additions and changes)

| Term | Meaning |
|---|---|
| **Home page** | The bastion's web front at `/`: two lists, **Sites** and **Documents**. Replaces v0.4's starter-pack page |
| **Documentation site** | The front's pages under `/docs/`: each starter-pack file and handout, and each player-facing brick's documentation |
| **Handout** | A document the customer gave the DBA at the mission's start: the data policy, the partners' page, the data register, the network overview. Generated once at setup, never re-rendered in play |
| **Network overview** | The handout listing the customer's nodes, one entry each: what it is, what runs on it, who uses it, its tasks, its backups, the players' access |
| **Your access** | The overview's column stating the players' access to a node (write, read-only, none). The game's rule, always exact, never a planted deviation |
| **Status page** | A partner's page on the front, listing the incidents that partner admits, each from its start |
| **Reports folder** | `~/reports/` on the bastion, served read-only at `/reports/` |
| **Real aging** | The stack running in real time for the scenario's declared aging; used for an extended game |
| **Fake aging** | The scenario's past filled in minutes on a virtual clock, a maintenance restart, a real tail, forged Prometheus history; used for a quick game |
| **Quick game / extended game** | What the initiator is offered, by duration; a quick game is fake-aged, an extended one real-aged |
| **Virtual T0** | The T0 a real game of the scenario would have: the planned hand-over minus the scenario's declared aging |
| **Fill** | The run, in minutes, of the producers, consumers and jobs from the virtual T0 to the anchor, the database's time-of-day functions bound to the virtual instant |
| **Maintenance restart** | The restart of every service of the game after the fill; an in-world event the starter pack's story names |
| **Anchor** | The maintenance restart's instant: the planned hand-over minus the tail |
| **Tail** | The real-time stretch from the anchor to the hand-over, everything running |
| **History import** | `gmctl history`: Prometheus' forged past written and imported, about twelve minutes into the tail |
| **Restart record** | The fake game's record of its timeline and of what the restart explains, in the game's local implementation |
| **Support** (of a fault, for fake aging) | `supported`, `tail-only` or `real-only` |
| **History signature** | A fault definition's `history:`: the Prometheus trail it leaves, drawn into the forged past |
| **Tell** | An observation that betrays fake aging (a statistic reset this morning, autovacuum barely run) |

## 5. Repository changes

```
bricks/
  bastion/          0.6.0: the home page, the documentation site, the reports folder,
                    the status pages and their renderer, jq and tmux, the seventh
                    optional seed file network-overview.md
  grafana/          0.4.0: Node health's `node` variable
  scheduler/        0.4.0: the fill mode and the queue model's code
  every other brick its next patch version: `base:` in brick.yaml (and, for
                    postgres, its player documentation on the reports folder)
faults/
  docs-overview-*/  new, family documentation: at least one, with its short test
  <the shop's and the campaign's faults>/
                    fault.yaml gains aging.fake and history:; gm.md a "Fake aging"
                    note when tail-only or real-only
domains/<id>/data/overview.yaml
                    new, each composed domain: its login roles and its jobs described
scenarios/
  aldermoor-centre/ nodes' description:, site:, users:; gm/network-overview.yaml and
                    player/network-overview.md generated; player/README.md's node table gone
  tarnbeck-outdoor-shop/, tarnbeck-outdoor-campaign/
                    repinned; their faults assessed for fake aging
  <every scenario>  repinned to the new brick versions
tools/gm/           the loader's new checks; render --aging fake; fill; clean-restart;
                    history; the restart record; status
tools/fake_aging/   the calibration tool and the verification tools (the tells script,
                    the M1 and M3 comparisons), with the pointer to the shop's
                    reference archive (no reference data in git)
.claude/skills/
  network-overview/ new GM sub-skill
  game-master/      the setup dialogue (whether the initiator plays, the mode), the
                    setup step calling network-overview, the feedback in two parts
  scenario-document/ "Network overview" and "Fake aging" sections
  scenario-format/  the new keys in the templates and the checklist
```

The research prototypes stay on their research branch; nothing is
copied as is (section 9.12).

## 6. Format changes

[formats.md](../../formats.md) v35 carries every rule below.

### 6.1 Scenario (`scenario.yaml` and the folder)

- **A node's `description:`**: one line on what the node is for, in the
  customer's words. Required on every customer node of a scenario that
  has a network overview; optional elsewhere.
- **A node's `site:`**, optional: where it stands, when that matters
  ("the off-site room"). Omitted from the overview when absent.
- **A node's `users:`**, optional: the people who work on the node
  directly, each `who`, and on a database node `database` and `role`.
  Empty for every clinic database today; room for a case with a person
  working directly on a database.
- **The bastion's seventh optional seed file**, `network-overview.md`,
  mapped to `player/network-overview.md` exactly when the scenario has
  an overview.
- **`gm/network-overview.yaml`**, the true overview, generated
  (section 8.4). No overview section inside `scenario.yaml`.
- **A fault instance's `admitted:`**, optional: the incident the
  instance causes as a partner admits it on its status page
  (section 7.6).
- **Reserved route names**: a bastion's `web_routes` may not name a
  route `docs`, `reports` or `status`, the front's own paths.
- **Which scenarios need an overview**: every scenario listing
  `domains:`, as for the data register. A `fixture-` scenario is
  exempt; v0.4's shop and earlier scenarios are exempt until next
  revised. A scenario without an overview keeps its README's node table
  (section 8.7).
- The scenario format is otherwise **unchanged by fake aging**: the
  aging mode is the game's, chosen at setup, never a scenario field.

### 6.2 Answer key (`gm/answer-key.yaml`)

- **`overview_diff:`** on each network-overview fault instance, required
  there and refused elsewhere, the shape of a register fault's diff: a
  non-empty list of `{node, field, true, handed_out}`, one item per node
  and field changed. `field` is one of `description`, `site`, `system`,
  `applications`, `sizing`, `databases`, `fed_and_used_by`, `uses`,
  `users`, `third_parties`, `tasks`, `backups`, or `entry` for a whole
  entry missing or invented (its `true` or `handed_out` then `absent`).
  `access` is never a field, nor is the header, and there is no
  `{absent: true}` item: the page is never absent. The scenario document
  shows each diff in a "Network overview" section.

### 6.3 Fault definition (`fault.yaml`)

The `aging:` block keeps `technique: real-time` (the real mode's) and
`minimum`, and gains `fake:`; the definition gains a `history:`. Shapes
in 6.9; rules in 9.5.

- **`aging.fake`**, absent meaning "not assessed", refused in a fake
  game: `support` (`supported`, `tail-only`, `real-only`), `reason`
  (one sentence), and for `tail-only` `tail_minimum` and `tail_covers`;
  `plant_in` (`any` or `tail`); `fill.emulate`, what the fill must
  imitate.
- **`history:`**, the fault's history signature, mandatory unless the
  support is `real-only`; a fault with no Prometheus trail says so with
  `- kind: none`. Kinds `queue`, `counter_per_call`, `gauge_sawtooth`,
  `gauge_before`, `daily_spike`, `remove`; `suppressed_by:` drops an
  entry from the planting of a hiding fault's instance onward (9.5).
  Every number in it is measured, and traced by a `# measured:` comment
  on its line naming the reference member or calibration file it was
  read from. A parameter only the signature needs is added optional
  (`required: false`, `default: null`), so the scenarios using the
  fault load unchanged, and every instance of a scenario played fake
  sets it.
- **`seed_changes[].lines`**, optional: the literal lines the change
  puts in the scenario's copy of the item's `file`, `{NAME}` parameter
  placeholders allowed, so a program can find them (a `change:` is
  prose, a `material:` an example, a diff or a whole file). Refused on
  `data-register.md` and `network-overview.md`, generated handouts
  whose changes the answer key's diffs carry. The loader checks them
  (6.10); a change without `lines:` stays the GM's to read.
- **`gm.md`** gains a "Fake aging" note when the support is `tail-only`
  or `real-only`: its last paragraph, opening `**Fake aging.**`.
- **Family `documentation`**, ids `docs-overview-*`: a `seed-file` fault
  on the bastion whose `seed_changes` name `network-overview.md`; the
  network-overview skill writes the handout with the change, the system
  is untouched.

### 6.4 Brick definition (`brick.yaml`)

- **`base:`**, required: the image's operating system,
  `{os: Debian GNU/Linux, version: "13"}`, checked by the brick's tests
  against the image's `/etc/os-release`. The overview's **System** field
  reads it.

### 6.5 Domain

- **`data/overview.yaml`**, declared in `domain.yaml`, required of
  every domain: `roles:`, each login role its schema creates (who uses
  it, what it reads, what it writes, one line each), and `jobs:`, each
  producer job and `pg_cron` job, with a one-line description. The
  domain checklist gains the item: every login role and every job
  described.
- Per-key **service times** for the fill's queue model live beside the
  query repository that defines the keys (`queries.yaml`), measured
  (9.7).

### 6.6 Crontabs written by the GM

Each crontab entry has its description on the comment line directly
above it. The overview's **Background tasks** read it.

### 6.7 The local implementation

- **The restart record** of a fake game,
  `local/<playground>/fake-aging.yaml`, written by `gmctl` (render, then
  `clean-restart`, then `history`): the mode, the virtual T0, the
  anchor, the tail, the planned hand-over, the refused instances with
  their reasons, the restart (its measured instant, the story line as
  rendered, the documented limits that hold in this game, each with
  what it shows, where, and its in-world explanation) and the history
  import's result. GM-side, out of the players' reach like the answer
  key. The game's progress through the fake steps (the deploy's hold,
  the fill, the clean-up) is in `state.yaml`, beside the rest of its
  progress.
- **The partners' status file**: render turns each planted instance's
  `admitted:` into UTC instants, as it turns a schedule's timeline
  changes, and writes it as a GM-owned secret mounted on the bastion
  (section 7.6).
- The bastion also receives, as configs, the player documentation of
  each brick it documents (section 7.3).

Their forms as built (the timeline's keys, the record as written with
its `history`, `state.yaml`'s `hold`, `fill`, `clean_restart` and
`history_import`, a `fill.quiet` item and the cover's, the history
import's unit, run lock and working files, the seam check's findings,
a fake game's restart, the status file's JSON and its `rendered`
secret, the `brick-doc` configs) are in [formats.md](../../formats.md)
"Local implementation" (v39).

### 6.8 Versions and pins

Every brick changes in v0.6, since `base:` is a change to `brick.yaml`:

| Brick | v0.5 | v0.6 | Why |
|---|---|---|---|
| `bastion` | 0.5.0 | 0.6.0 | the home page, documentation site, reports, status pages, `jq`, `tmux`, the seventh seed file; the PostgreSQL 19 client tools (spec D587) |
| `grafana` | 0.3.0 | 0.4.0 | Node health's `node` variable |
| `scheduler` | 0.3.0 | 0.4.0 | the fill mode, the queue model; libpq 19 (spec D587) |
| `postgres` | 0.5.0 | 0.5.1 | `base:`; its player documentation on the reports folder; PostgreSQL 19 (spec D587) |
| `api` | 0.1.0 | 0.1.1 | `base:`; libpq 19 (spec D587) |
| `health-check` | 0.1.0 | 0.1.1 | `base:`; the PostgreSQL 19 client and libpq (spec D587) |
| `pgbouncer` | 0.1.1 | 0.1.2 | `base:`; the PostgreSQL 19 client and libpq (spec D587) |
| `pgwatch` | 0.1.0 | 0.1.1 | `base:` |
| `postgres-exporter` | 0.2.0 | 0.2.1 | `base:` |
| `prometheus` | 0.2.1 | 0.2.2 | `base:` |

A brick whose build finds more to change folds it into the same new
version while it is unreleased. Every PostgreSQL in v0.6 is 19, the
server and every client tool and library (spec D587, the latest
release under spec D396): folded so, it re-pins nothing. Every scenario repins; every fault that
still applies adds the new versions to its `applies_to`. Faults,
scenarios, domains and purposes never bump.

### 6.9 Shapes of the new fields

```yaml
# scenario.yaml, a customer node with an overview
- name: records
  brick: postgres
  version: 0.5.1
  description: The record's database server, the medical record, the wards, the agenda,
    the owners' portal and the back office's registers.
  site: the main building          # optional
  users: []                        # optional: [{who: ..., database: ..., role: ...}]

# scenario.yaml, a fault instance a partner admits
- id: s11                          # an illustration: no such fault exists yet
  fault: <a partner fault>
  admitted:
    by: northfield-lab             # a third_parties id with a player_doc
    title: Delayed results delivery
    text: >-
      Results are being delivered with delays of up to two hours. Our
      engineers are working on it.
    from: handover-6h              # T0 or handover-<N>h, not before the instance's planting
    until: handover-4h             # optional; absent: still ongoing at hand-over

# answer-key.yaml, an overview fault instance
overview_diff:
  - {node: machines, field: backups, true: "a base backup nightly to Cold Storage",
     handed_out: "WAL archived to Cold Storage, base backup nightly"}

# fault.yaml (pg-archive-command-silent), a seed-file change's declared lines
injection:
  seed_changes:
    - file: postgresql.conf
      change: >-
        archive_command = 'vault-post wal %p %f || true': ...
      lines:                       # optional: literal lines in the scenario's copy; {NAME} allowed
        - "archive_command = 'vault-post wal %p %f || true'"

# fault.yaml
aging:
  technique: real-time
  minimum: 30m
  fake:                            # absent: not assessed; refused in a fake game
    support: tail-only             # supported | tail-only | real-only
    reason: >-
      the autovacuum "not yet removable" lines are genuine only in the tail;
      the fill holds the snapshot
    tail_minimum: 2h               # tail-only
    tail_covers: ["12:00"]         # tail-only: scenario-time instants the tail must hold
    plant_in: any                  # any | tail
    fill:
      emulate: [held-snapshot]
history:                           # mandatory unless real-only
  - kind: counter_per_call
    series: 'node_health_cpu_seconds_total{node="{NODE}"}'
    key: '{KEY}'
    per_call: 0.067                # measured: <reference member or calibration file>, <what>
  - kind: remove
    series: 'up{job="{TARGET}"}'
    suppressed_by: [<hiding fault id>]   # no covered fault uses it in v0.6 (9.5)

# brick.yaml
base: {os: Debian GNU/Linux, version: "13"}

# domains/<id>/data/overview.yaml
roles:
  - {role: vet_app, who: the practice software, reads: the record and the agenda,
     writes: consultations, prescriptions, bookings}
jobs:
  - {job: prescriptions-expire, what: the night's expiry of prescriptions}

# local/<playground>/fake-aging.yaml, the restart record
mode: fake
virtual_t0: 2026-11-20T22:00:00Z
anchor: 2026-11-21T11:00:00Z       # planned: the hand-over minus the tail
tail: 3h
handover_planned: 2026-11-21T14:00:00Z
refused: []                        # each {instance, reason}; the shop's full selection refuses none
restart:
  at: 2026-11-21T11:00:14Z         # measured: the one start's instant, never before the anchor
  story_line: The servers were restarted for maintenance on 2026-11-21 at 11:00 UTC;
    older logs were archived.
  explains:
    - {observation: statement and shared statistics reset at 11:00,
       where: "pg_stat_statements_info.stats_reset, pg_stat_bgwriter.stats_reset",
       in_world: the maintenance restart reset them}
history: {at: 2026-11-21T11:12:30Z, result: ok, seam: ok}   # result ok|failed; seam ok|failed|unchecked;
                                   # reason: one line, only when not both ok
```

### 6.10 The loader's new checks

- The network overview's: the digests, the coverage of the true
  overview, the handout present and mapped, no third party's node named,
  **Your access** and the header equal to the true overview's
  (section 8.4); `overview_diff:`'s shape (6.2).
- `description:` present on every customer node of a scenario with an
  overview; `users:` shape.
- `admitted:`: `by` names a `third_parties:` entry with a `player_doc`;
  `from` not before the instance's planting moment and before the
  hand-over; `until`, when present, after `from` and not after the
  hand-over; `title` and `text` non-empty.
- Reserved route names refused.
- `aging.fake` and `history:`: shapes; a `supported` or `tail-only`
  fault with an empty or missing `history:` refused; `tail_minimum` and
  `tail_covers` only on `tail-only`. In a fake game `gmctl render`
  refuses a `real-only` or unassessed instance, naming its reason.
- **The partners' page**: a bastion maps `partners.md:
  player/partners.md` exactly when the scenario's `third_parties:`
  carry a `player_doc`; the loader refuses "third parties carry a
  `player_doc`, but the bastion maps no `partners.md`", and the
  converse. With a unit test. (v0.5 caught the omission only through a
  listed credential.)
- **A seed-file fault's lines**: for each selected instance whose
  definition's `seed_changes` item carries `lines:`, each line, its
  placeholders replaced from the instance's parameters (else their
  defaults), is found in the node's copy of the item's `file` (a folder
  entry: any file of the folder; `data`: the node's data file). A line
  is found when a line of the copy, both stripped and their runs of
  blanks made one, equals it or continues it with a comment (`#` or
  `--` after a blank), anywhere in the file. The loader refuses an
  instance whose line is missing, naming the instance, the line and the
  file. With a unit test. The clinic's `pg-archive-command-silent`,
  `governance-statement-log-personal` and `pg-standby-apply-delay`
  carry `lines:`. (In v0.5 the clinic's s2, s7 and s8 lines were
  missing from the scenario's copies and every check passed until the
  whole-clinic run.)
- `base:` present in every `brick.yaml`.
- A domain's `data/overview.yaml` declared and covering every login role
  and job.

## 7. The bastion, the players' main activity point

### 7.1 `bastion` 0.6.0

The bastion keeps its two published ports (SSH, the web front), its
basic authentication on the per-game tools password (user `player`),
nginx, and the bastion-only rule: the front proxies only to the game's
own web interfaces, plus cold storage's read-only console as in v0.5.
What it serves on its own grows: the home page at `/`, the
documentation site under `/docs/`, the reports folder at `/reports/`,
the status pages under `/status/`. Every page is built by the bastion
itself from what the GM delivered; none is proxied from another node.

As in v0.5, the pages are rendered at each start from the starter pack
as handed over (the GM's copies in the bastion's seed), never from the
players' copies in their home, by `cmark-gfm` with the table extension
and no raw HTML passed through. An absent element leaves nothing: no
section, no dead link.

### 7.2 The home page

Replaces v0.4's starter-pack page. Two lists:

- **Sites**: each route of the bastion's `web_routes` (Grafana,
  Prometheus, the clinic's health page, cold storage's console);
  **Reports** (always); one **status page per partner** with a player
  document, by the partner's name; later the fictional provider's
  console.
- **Documents**: each document the scenario provides, each linking its
  page under `/docs/`: the README, the story, the issues, the data
  policy, the partners, the data register, the network overview; then
  **Tools**, each brick's player documentation (7.3).

A short header names the game's customer (from the story) and says the
documents are what the customer handed over at the mission's start.

### 7.3 The documentation site

- `/docs/<id>`, one page per starter-pack file and handout present:
  `readme`, `story`, `issues`, `data-policy`, `partners`,
  `data-register`, `network-overview`. The partners' page has its
  credential placeholders filled, as the home copy has.
- `/docs/bricks/<brick-id>`, the player documentation (`docs/player.md`,
  at the pinned version) of each brick of a node the players may reach
  (every customer node's brick, and the bastion's own); never a brick
  only a third party's nodes run, which stay out of the starter pack.
  `gmctl render` delivers each as a config to the bastion.
- The brick pages are the game's documentation, always exact, like
  **Your access**. A node missing from a planted-wrong network overview
  still has its brick's page: one more witness, by design, as Node
  health's node list is.
- Copies in `/home/player` stay as they are: the starter pack and the
  handouts as Markdown files, the network overview among them.

### 7.4 Handouts: static snapshots, and which may be wrong

**Every handout is a static snapshot of the mission's start.** In the
owner's words, the documents are "what the customer provided the dba at
mission start, so some fixes may render them inaccurate, but that's
okay". Generated once at setup, never re-rendered in play; a restart
from the hand-over snapshot keeps them as handed over. A handout
describes the system **as designed**, the value before a planted fault
changed it. Only the live tools it links to (Grafana, Prometheus, the
health page) follow the system, on their own. A fix that leaves a
handout out of date is expected: never a fault, never something the GM
checks, and the players are not asked to update it. This holds for the
data register too.

**Which starter files may carry a planted inaccuracy**: only the
handouts that describe the system, the data register and the network
overview. Never the README and the rules (the game's how-to), the data
policy (the norm the players audit against) or the partners' page (the
players have no access to verify it). The story and the issues may be
mistaken only as the customer's belief: a false alarm, as today.

### 7.5 Reports

The stack's reports (pgBadger's HTML, pgCluu's folder) become readable
in the browser instead of leaving through `scp` and then `sftp`:

- `~/reports/`, created by the bastion's entrypoint in the player's
  home, readable by the front's account;
- served read-only at `/reports/` as a directory listing, behind the
  same basic authentication; nothing outside the folder is served;
- a player brings a report there in one hop
  (`scp <node>:pgbadger.html ~/reports/`, `scp -r` for pgCluu's
  folder) and opens it; the copy to their own machine is no longer
  needed;
- the front answers `/reports/` with
  `Content-Security-Policy: sandbox allow-scripts`, so a report's own
  scripts run but never act on the origin Grafana shares;
- the front never reaches into a database node: no new route, no web
  server on any node.

Owner: the `bastion` brick, its web front. The `postgres` brick's
player documentation says where to put a report. These are the stack's
own reports; the players' audit report stays theirs, written where they
like.

### 7.6 The partners' status pages

One page per third party with a player document, at
`/status/<third-party-id>/`, linked from the home page's Sites and from
the partner's section of the partners' page. A live site like Grafana,
not a handout: the static-snapshot rule doesn't apply.

**What it shows**: only the incidents the partner admits. A third party
admits what its own monitoring and its contract make it admit: an
outage, slow answers, a maintenance window it caused. It never admits
what it doesn't know or won't say, and a partner that stays silent on
an incident the customer suffered is a finding the players may make
from the customer's side.

**Where the scenario marks it**: on the fault instance, `admitted:`
(6.9): `by`, the partner; `title` and `text`, the partner's words;
`from`, the incident's start, `T0` or a moment before hand-over as a
planting moment is written, never before the instance's planting;
`until`, optional, its end. Only a planted instance's incident shows: a
fault the GM left out of the selection, or refused in a fake game,
admits nothing. A fault instance on a partner without `admitted:` is
an incident the partner doesn't admit.

**How it is built** (never a route to a third party's node):

- `gmctl render` turns each planted instance's `admitted:` into UTC
  instants from the planned hand-over, as it does a schedule's timeline
  changes, and writes the game's status file: each partner with a
  player document (its id, name and the anchor of its section in the
  partners' page) and its admitted incidents. A restart re-renders it
  as it re-renders the timeline.
- The file reaches the bastion as a GM-owned secret, readable by root
  only: it holds incidents still to come, which no player may read
  ahead.
- A small root service on the bastion renders every minute each
  partner's page into the front's own files: the partner's name, its
  current state ("Operational", or "Incident ongoing" while an
  admitted incident has started and not ended), and each admitted
  incident whose start has passed, newest first, with its title, text,
  start and, once passed, its end, in UTC as every time the game shows.
  An incident not yet started is not on the page.

In a fake game, an incident's instants fall where the virtual timeline
puts them, real instants in the past or the tail; the page shows them
as any other.

**For the GM**: the scenario document shows each instance's admitted
incident beside the instance (the partner, the title, the text, `from`
and `until` as written), so the GM knows what a status page will say
and when without reading `scenario.yaml`.

### 7.7 General-use tooling

What the bastion has today (the PostgreSQL 19 client tools, `ssh`,
`procps`, `less`, `nano`, `vim-tiny`, `curl`) plus `jq`, to read
Prometheus' API, and `tmux`. Nothing heavier; more when a player's need
shows.

### 7.8 What stays as in v0.5

The tools password and Grafana's own login (user `admin`), the
starter-pack files copied into the player's home, cold storage's
console route, the partners' credentials filled into the partners'
page, no `sudo` on the bastion.

## 8. The network overview

### 8.1 What the page is

A real IT team keeps an inventory of its servers: one entry per
machine, what it is for, what runs on it, who connects to it, what runs
at night, how it is backed up, written once and updated when someone
remembers. The handout takes that shape: one entry per node of the
customer's estate, customer documentation that may be incomplete or
wrong. Nodes go by their Docker name, never an IP. Each links to
Grafana's Node health dashboard, which reads the customer's Prometheus,
not a GM-side collector, so the customer's monitoring faults show
through. In the owner's words, the intent is "this database is fed by
this application, and this application in turn uses the data for its
own purposes, roughly". The data register is data-centric; the overview
is the node-centric view of the same facts.

**Grouping**, in this order, each group in `scenario.yaml`'s order:
the database servers; the applications and APIs, then the integration
and back-office engines; the monitoring, exporters included; a closing
**third parties** table. The page opens with a one-line-per-node
summary (name, role, description, access), each name linking to its
entry. The clinic comes to 21 entries and nine third-party rows.

**The header**, fixed text, never a deviation: the customer's name;
one line on the network ("one private network; the partners' services
are reached on it by name; from outside, only the bastion's SSH port
and web port are reachable"); the bastion line ("You work from
`bastion`, your access point", with its Node health link); the link to
Node health for the whole estate; and one sentence on trust: "This is
the centre's own documentation, kept by its IT. The **Your access**
column is the game's rule and always exact."

### 8.2 One entry: its fields and their sources

Every field is generated from the authoritative files, never written by
hand.

| Field | What it says | Source |
|---|---|---|
| **Name** | the Docker name (`ssh records`, `psql -h records`) | `nodes[].name` |
| **Role** | database server, application, API, integration engine, back-office engine, monitoring | `nodes[].role`, by a fixed table in the skill; producers and transformers split by role |
| **Description** | one line, the customer's words | `nodes[].description` |
| **Site** | where it stands, when it matters | `nodes[].site`; omitted when absent |
| **System** | operating system and version | the brick's `base:` |
| **Applications** | what runs, with versions: the brick's technology; on a database server the preloaded extensions, the options, the report tools, the cron daemon | `brick.yaml` `technology`, `options`, `report_tools`; the node's `options:` and `crontab`; `shared_preload_libraries` |
| **Sizing** | CPU and memory limits and reservations, disk | `nodes[].resources` |
| **Your access** | write, read-only or none, with any path exception | the write policy, the scenario's write overrides, the brick's writable paths |
| **Activity** | the link to Node health for this node | the node's name; the `grafana` route |
| **Databases** (database servers) | each database, what it holds in one line, and the data register's entries held there, linked | `nodes[].data.databases`; the domains' `at:` and titles; the register's index |
| **Fed and used by** (database servers) | each application connecting: node, database, role, what it does there | the composed `schedule.yaml` and `api.yaml` connections; the purposes' job connections; the monitoring configs; `standby_of`; the `pg_cron` jobs' roles; what a role does, from the domain's `data/overview.yaml` |
| **Uses** (applications) | the databases it connects to, the APIs and partners it calls | the same connections from the node's side; HTTP credentials |
| **Users** (people) | people working on the node directly | `nodes[].users` |
| **Third parties** | each partner the node reaches, linked to its section of the partners' page | HTTP connections to a third party's hostname; `postgres`' vault target; the health page's checks |
| **Background tasks** | each scheduled task: name, when (with its time zone), what | the composed `jobs.yaml` (UTC); the crontabs and their comment lines; `pg_cron` jobs (the customer's zone); the domains' `data/overview.yaml`; a purpose job's `computes:` |
| **Backups** | how the node's data is protected, "none" when nothing does | `standby_of`; `archive_mode` and `archive_command`; the vault target; the base backup lines; the health page's backup checks |

Times are written as the node runs them: jobs and crontabs in UTC,
`pg_cron` in the customer's zone (`{{customer_timezone}}` filled at
render). **The system as designed**: where a fault instance's
`seed_changes` touch a file the skill reads (`postgresql.conf`, a
crontab, a `jobs.yaml`), the skill takes the value before the change,
so a system fault shows as the system disagreeing with a true page and
is never hidden by the page agreeing with it. The loader can't check
this; the scenario document shows the overview beside each fault for
the GM's review.

### 8.3 One set of facts

**The data register** and the overview come from the same facts and are
consistent by construction: a database server's **Databases** lists,
for each database, the register entries its index gives, linked; the
overview never restates the register's columns, classes or retention. A
register fault leaves the overview true, and an overview fault leaves
the register true: each is planted in its own handout, independently.
One may then give away the other's fault (Cold Storage missing from the
register while the overview's **Backups** still name it): that is how
such a gap is found in a real organisation. The answer key notes the
interaction; a GM wanting it harder plants a matching overview fault as
a second instance.

**The access mapping**, never a deviation:

| Write policy | Your access | Meaning |
|---|---|---|
| `fixable` | **write** | change the configuration; explain it in the report |
| `report-only` | **read-only** | log in and look; report and propose |
| `no-access` | **none** | a third party's: only what it publishes |

A write override on a report-only node adds its paths ("read-only;
write: `/srv/api/db/`"); where the brick's writable paths narrow a
fixable node, the entry says so.

**The bastion** is the players' kit, not the customer's system: no node
entry, the header's fixed line only, its tooling never judged as the
customer's. **The third parties**: a closing table, one row per partner
with a player document, by the hostname the players call, access none,
linking the partners' page. The partners' shared nodes are game
plumbing standing for several partners and are never named.

### 8.4 Generation: the `network-overview` skill

A GM sub-skill, `.claude/skills/network-overview/`, on the
`data-register` skill's model: generated from the authoritative files,
never edited by hand, regenerated rather than reconciled.

- **Inputs**: `scenario.yaml` (nodes, resources, write policies and
  overrides, web routes, third parties, standbys, fault instances);
  each node's seed files the fields read; each brick's `brick.yaml` at
  its pinned version; each composed domain's `data/overview.yaml` and
  `data/cron.sql`; each purpose's `purpose.yaml`; `player/partners.md`;
  `gm/data-register.yaml` (its index); `gm/answer-key.yaml`.
- **Outputs**: `gm/network-overview.yaml`, the true overview, sealed
  like the rest of `gm/`, opening with `generated_from:`, each input's
  digest; `player/network-overview.md`, the true overview rendered as
  is or with a planted overview fault's change applied, always present
  in a scenario that has an overview; each overview fault instance's
  `overview_diff:` in the answer key.
- **When**: at setup step 2, after the data register and before the
  scenario document, which reads both (format, register, overview,
  document); after any change to its inputs.
- **The loader**: recomputes the digests and refuses a stale overview;
  checks the true overview's coverage (every customer node in exactly
  one entry, the bastion and the third parties' nodes in none; every
  partner with a player document in the third-party table; every
  database connection of every composed config under some **Fed and
  used by**; every job, crontab line and `pg_cron` job under some
  **Background tasks**; every database of every database node under
  **Databases**; every standby, `archive_mode = on` and base backup line
  under some **Backups**), a miss being a generation error, never a
  fault; and the handout: present and mapped, no third party's node
  name in it, **Your access** and the header equal to the true
  overview's.

### 8.5 Overview faults

**Injection**: a `seed-file` fault on the bastion naming
`network-overview.md` (6.3). **Resolution**: *propose*: the players
give the corrected entry in their report, and the GM judges it at the
final answer against the diff; the sealed check reads only that the
change is present in the bastion's copy. **Class**: a minor friction by
default, as a register fault; N5 may be on the verge or dramatic when
the story leans on the claimed backup (an issue asking whether `machines` can be brought back to
yesterday noon). A system fault the page's truth makes easier to see
(a silent archive command next to a page saying "WAL archived") is no
overview fault; the answer key notes the help.

**The traps**, a generic catalogue; each witness is the page read
against the system:

| # | Trap | Witness |
|---|---|---|
| N1 | A node missing: a server nobody documented | `ssh`, Prometheus' targets, Node health's node list, the brick's documentation page |
| N2 | A node invented: a server decommissioned but still listed | the name does not resolve; no data in Node health |
| N3 | A stale version: "PostgreSQL 16" on a PostgreSQL 19 server | `SELECT version()`, the tool's own page |
| N4 | A wrong sizing: "4 GB memory" on a node limited to 1 GB | Node health's memory limit; the node's cgroup |
| N5 | A claimed backup that does not exist | `archive_mode`, `pg_stat_archiver`, `pg_stat_replication`; the vault's manifests |
| N6 | A background task wrong or missing | the crontab, `cron.job`, `jobs.yaml` |
| N7 | A user missing, or a role listed that nothing uses | `pg_stat_activity`, `pg_hba.conf`, the configs on the application nodes |
| N8 | A third party missing from a node's entry | `archive_command`, the base backup line; the partners' page |
| N10 | The page vague: "our servers", no versions, "backed up nightly" everywhere; **Your access** and the header stay exact | the entries themselves |

There is no N9: the page's absence was considered and dropped, since it
would take away **Your access**, the game's rule, and leave the README
pointing to a missing page.

A GM selects among these at deploy; fault selection is the GM's. v0.6
builds the family and at least one fault of it with its short test.

### 8.6 Node health's `node` variable (`grafana` 0.4.0)

The dashboard (uid `node-health`) gains a `node` variable
(`label_values(node_health_cpu_limit_cores, node)`, multi-value, "All"
by default), every panel's query filtered by `{node=~"$node"}`. Each
entry links
`/grafana/d/node-health/node-health?var-node=<name>&from=now-6h&to=now`;
the header links the dashboard with every node. It reads the customer's
Prometheus through Grafana's data source, so a target missing from
`prometheus.yml`, a node left out of the node-health map or a broken
dashboard shows as an empty or wrong graph: a witness, by design.

### 8.7 The README

The README here is the starter pack's `player/README.md`, written by
hand, not the scenario document (the scenario's own `README.md`,
generated by the `scenario-document` skill).

**With an overview**, the README keeps how to get in (the bastion's
login, the hops, `psql` and `~/.pgpass`), the rules about fixable and
report-only work, "Each node in short" (where each kind of node keeps
its files and logs), "Applying changes", "The jobs you may move", the
validators, the rules, DO NOT TAMPER and the report. It loses the node
table and the network paragraph to one line pointing to the overview,
whose **Your access** column is the rule. Its web-interfaces table
shrinks to the home page's address.

**Without an overview** (v0.4's shop and earlier scenarios until next
revised, a fixture), the README keeps its node table and network
paragraph as they are, the access rules there; only its web-interfaces
table shrinks to the home page's address, since every game has the
home page.

## 9. Fake aging

### 9.1 Two modes, and choosing one

Real aging stays as it is for extended games: the stack runs in real
time for the scenario's declared aging, at least eight hours. Fake
aging joins it for quick games. The mode is chosen **per game, by the
GM, at setup**; it is not a scenario field.

- The initiator states the time available, as today, and may ask for a
  quick or an extended game. The initiator never picks faults or a
  mode's mechanics: fault selection is the GM's.
- **Default**: real aging when the time available covers the scenario's
  declared aging; fake aging when it doesn't, or when the initiator
  asks for a quick game. The GM's judgment of whether a game's aging is
  affordable stands; fake aging is one more option before declining.
- **Fake aging needs an eligible selection**: the GM selects, or
  replaces, the scenario's fault instances so that every one is
  eligible (9.5), then sets the tail (9.6). If no acceptable selection
  fits, the GM declines the scenario or proposes another, as today.
- **A handout never names a refused instance**: an instance an issue
  of the starter pack (or any handout) names and fake aging can't make
  is never left to `gmctl render`'s refusal, which would hand the
  players an issue with no cause. The GM plays a variant designed
  without that instance and its issue (proposing another scenario, as
  above), plays the game real, or declines. Render's refusal stays the
  safety net, for an instance no handout names.
- A scenario with no scheduler node has no aging, and so no mode.

### 9.2 The initiator who also plays

The players are never told about the aging process during the game
(9.11), and a student playing alone is both the initiator and a player.
So:

- the GM asks **once**, with the time available, whether the initiator
  will play the game;
- when the initiator may play, the setup dialogue speaks of a **quick
  game** or an **extended game** by its duration only ("ready in about
  an hour and a half", "ready in about 16 hours") and never names the
  technique: no aging, fill, forged, virtual clock or fake; a quick
  game's duration is the setup's measured time in the scenario
  document's "Fake aging" section plus the selection's tail (9.10);
- an initiator who will not play (a teacher, the owner) may be told the
  mode and its limits.

### 9.3 A fake game's timeline

Every instant is computed from the planned hand-over H, as for a real
game.

| Instant | Fake game | Real game |
|---|---|---|
| virtual T0 | H minus the scenario's declared aging (the shop: 22:00 the evening before) | T0, real |
| fill | virtual T0 to the anchor, run in minutes, before the tail | none |
| clean-up | ends with the maintenance restart | none |
| anchor | H minus the tail: the maintenance restart's instant, every service of the game started there, the monitoring included | none |
| tail | anchor to H, real time, everything running | the whole aging |
| history import | about 12 minutes into the tail | none |
| early check | halfway through the tail, no later than one hour before H, never before the history import | halfway through the aging, by H minus one hour |
| H | hand-over | hand-over |

The virtual span is the scenario's declared aging, so the virtual T0 is
the T0 a real game of the scenario would have; the instances' aging
minima count in virtual time from it. The Prometheus retention rule
(the aging minimum plus four hours) covers the forged span, the tail and
the game unchanged.

### 9.4 The GM's steps in fake mode

Steps 1 to 4 are today's setup.

1. `gmctl render --aging fake`: the timeline above, written into the
   restart record (6.7). The starter pack's story line on the restart is
   rendered with the planned anchor's date and time, appended to the
   story: "The servers were restarted for maintenance on 2026-11-21 at
   11:00 UTC; older logs were archived." (a date and UTC, since the
   anchor need not fall in the morning and every time the game shows is
   UTC).
2. `gmctl deploy`, the monitoring (Prometheus, Grafana, the exporters,
   pgwatch) kept scaled to zero until the restart.
3. `gmctl load-data`, on the virtual T0's clock (fix 11), and unseen as
   today: no statement log, no pgaudit, no `pg_stat_statements`.
4. `gmctl inject`: the faults planted at the virtual T0, on its clock
   (fix 11).
5. **`gmctl fill`**: the scheduler program's fill mode on every
   scheduler node, one virtual clock, from the virtual T0 to the anchor.
   It runs the producers' streams, the consumers' keys and the jobs as
   fast as the database allows, the database's time-of-day functions
   bound to the virtual instant in the SQL the fill runs and in the
   server-side functions it calls, those that pin their own
   `search_path` through the cover below. It writes the scheduler logs at
   virtual times, their latencies from the shared queue model. It
   pauses at each `state` fault's virtual planting, runs that fault's
   inject unchanged on the pause's virtual instant (fix 11's session
   means, `gm.vclock` at that instant), records the instant, and goes
   on. Statistics stay
   off as in step 3. The real-clock actors stay off: `pg_cron`, the
   database node's cron daemon, archiving. No `pg_cron` job runs in the
   fill; its runs are the tail's.
6. **`gmctl clean-restart`**, never before the planned anchor (refused
   until it comes: the fill's rows run up to it, so a restart before it
   would leave the last of them dated after the restart, in the future);
   the GM waits out whatever is left between the fill's end and the
   anchor (minutes: the fill's slack). In order: what the fill
   left unrestored put back; the WAL padded and checkpointed; the
   statement and shared statistics reset, as the maintenance's own
   step before the stop, so `stats_reset` falls seconds before the
   postmaster's start; the stop; the fill's PostgreSQL, pooler and cron
   logs removed; the data files' modification times set to their
   virtual times; then **every service of the game restarted at the
   same instant, the monitoring scaled up from zero in that same
   restart**, so no start time stands apart; standbys and base backups,
   where a scenario has them, built after it. Its instant, at or just
   after the anchor, is recorded in the restart record (`restart.at`),
   and every later step counts the tail from it.
7. `gmctl start-load` right after the restart, T0 recorded as the
   virtual T0, writing no `reload status=ok` line (the purpose checks
   date their judged moment from that line).
8. **`gmctl history`**, run by a host timer about 12 minutes into the
   tail: read the tail's first 10 minutes from Prometheus, compose the
   baseline and the selected faults' history signatures, rebase them on
   the tail, write the past as OpenMetrics, create blocks with
   `promtool tsdb create-blocks-from openmetrics`, copy them in, check
   the seam. promtool runs in a helper container of the Prometheus
   node's image on its host, never in the running node; Prometheus
   loads the blocks by itself and is never restarted for them. A failed
   import is recorded, never a teardown, as a failed early check is.
   It is refused before the tail's first 10 minutes have passed and
   once the game is handed over. One import runs at a time; once one is
   recorded `ok` a later run changes nothing, so a failed seam is never
   imported again (the GM sets the game up again or hands it over as it
   is), while a failed import may be retried by hand. The seam check's
   findings (`negative`, `reset`, `jump`, `empty`) and the record's
   `history` are in formats.md; `gmctl history --check-seam` reads the
   seam again, recording nothing.
9. **The early check**, by a host timer as today: halfway through the
   tail and no later than one hour before the earliest hand-over, but
   never before the history import is recorded; in a tail under two
   hours, and in the tests' short tails, right after the import. It
   checks what the real mode's does (every fault planted so far reads
   present, the fill's plantings included; every scheduler key running;
   no node unhealthy; the outages) and reads the import's result. Then
   the hand-over check, the hand-over snapshot and the hand-over, as
   today. The earliest hand-over is the restart's instant plus the
   tail.

**Planting times**: a `state` fault planted between the virtual T0 and
the anchor is planted by the fill; one planted in the tail by a host
timer, as today; a fault with `plant_in: tail` must be planted in the
tail.

**Routines that pin their own `search_path`** (the cover). A function or
procedure with its own `SET search_path` never sees the fill's session
path, so the fill covers it for its span. At its start, in each database
it writes, it finds every function and procedure outside the system
schemas and the bricks' own `gm_*` schemas whose own settings
(`proconfig`) set `search_path`, and alters that setting to put
`gm_vclock` right before `pg_catalog`: just ahead of it where the path
names it; where it doesn't (PostgreSQL searched it implicitly, first),
`gm_vclock, pg_catalog` at the path's end, ahead of a final `pg_temp`.
So the path's first schema, where the routine creates what it names
unqualified, stays first (a path that starts with `pg_catalog` creates
nothing unqualified, and `gm_vclock` heads it); the routine's other
settings stay as they are. The fill's own sessions, and fix 11's,
place `gm_vclock` on their path by the same rule. The price: a function
in a schema listed before `pg_catalog`, named and typed as a built-in,
would win over the built-in in those sessions; no scenario has one. The
shim's drop refuses, naming them, objects inside `gm_vclock` other than
its own functions, as it refuses objects outside that depend on them.
Each cover
is listed in `fill.quiet` with the routine, its database and its
original setting, and restored to exactly that at the fill's end, on a
failure too. After each planting at a pause the fill looks again: a
routine an inject replaced or added takes its new setting as its
original and is covered. `clean-restart` restores a cover still listed
unrestored before its statistics reset, as it drops a leftover
`gm_vclock`. A session without the fill's setting that calls a covered
routine reads the real clock. The routine's catalog row ends identical,
with a new row version (9.10).

**As in a real game**: the hand-over, the issues, the GM's stance
during the game, the final answer, the checks, restarts and the
hand-over snapshot. A fake game's restart from its snapshot is the
same fake game: the record unchanged, no second import, the imported
history restored with the rest of Prometheus' volume (measured in wave
3's history run, the seam `ok` after it). Its restart with no history
rebuilds the game on the real clock, as the real mode's (no fill, no
import), the refused instances still out and the story keeping its
line; the record stays the first game's, for the feedback.

### 9.5 Fault eligibility

- **`supported`**: the fill makes the fault's state, its history
  signature draws its Prometheus trail, and its evidence holds whatever
  the tail.
- **`tail-only`**: its evidence must be genuine and needs the tail: a
  minimum length (`tail_minimum`), instants the tail must cover
  (`tail_covers`), or a planting in the tail (`plant_in: tail`).
- **`real-only`**: it needs something fake aging can't make; `gmctl`
  refuses it in a fake game, naming its reason.
- **Not assessed** (no `aging.fake`): refused in a fake game. A fault
  no covered scenario uses stays not assessed.

**The history signature**: the overlay classes of the research, written
per fault definition with the fault's parameter placeholders, not per
instance. Overlays are mandatory: an empty or missing `history:` on a
`supported` or `tail-only` fault is refused. `queue` entries are never
drawn per fault: the fault declares its effect on the one shared queue
model, which writes both the scheduler's log lines and the call
duration histograms. `remove` wins over every baseline and overlay on
its series. `suppressed_by` drops an entry from the planting of the
first selected instance of a hiding fault onward, so a hiding instance
planted in the tail drops nothing from the forged past. No covered fault uses it in v0.6, so it is
unit-tested only: the shop's f9 and the campaign's f5 hide another's trail
in state and logs only, which no exporter reads, so their history
signatures carry no `suppressed_by` (9.8). A signature draws only series
the game's exporters serve: the `postgres-exporter` connects to the
`postgres` database alone, so there are no per-table or per-index
series of a scenario database, and a `pg_*` series' `instance` is the
exporter's, never the database node's; a dropped index's size shows in
its database's size (`pg_database_size_bytes`). Faults that hide or wipe another's
trail are wanted, and the fake reproduces them, never repairs them;
the forged past is always before any fix.

### 9.6 The tail's length

The tail is the longest of:

- a floor of **one hour**, so the statement statistics and the logs hold
  an hour of genuine traffic and the import is done well before the
  hand-over;
- each selected fault's `tail_minimum`;
- for each `tail_covers` instant, the time from one floor before it to
  H, so the instant has the floor's hour of genuine traffic before it,
  clear of the restart and the history import;
- for each instance planted in the tail, the time from its planting
  moment to H; that moment lies inside the tail, at least the instance's
  aging minimum before H, so the tail is never shorter than that
  minimum.

Tests may cap the floor, as v0.3's rehearsal capped the aging minimum;
a covered instant's lead is capped with it.

### 9.7 Every number is measured

Four guesses in the research were 4× to 55× off. Every number in a
history signature, and each key's service time in the queue model,
comes from one real run of the fault: **short**, under 30 minutes, the
fault planted at once and its job moved into the window as a player
would move it. Per-call costs and service times don't need a day; the
day's shape comes from the producer profiles. Calibration is one-off
per fault version. The shop's numbers already come from the research's
real run. The per-key service times describe the scenario's or the
domain's keys, so they live beside the `queries.yaml` that defines
them; the scheduler brick ships the model's code. A key on a
report-only node, whose job no short real run can move into its window,
is timed from its own runs in a fill or by running its statement with
psql, its `source:` saying so (the campaign's `bi` and `gateway`); a
key measured on a single run carries no spread (`sigma: 0`). Each
measurement is kept as one file in the repository's calibration folder,
named by the scenario, what it measured and its instant, opening with
the command, the commit, the start and the wall time; a `source:` or a
`# measured:` comment names it (formats.md). A short fake game's whole
output is kept the same way (12.1's script, `short-game`), and the
scenario document's setup time is read from the newest one (9.10).

### 9.8 The scenarios covered, and the starting estimates

"P0" below is the virtual clock in the SQL the fill runs, the
server-side functions it calls included, through the cover for one that
pins its own `search_path` (9.4). Measured: it reaches the campaign's
f1 to f3 directly, and f4 and f7 (`rpt.close_day()` pins its own path)
through the cover, which their calibration confirms; a fault P0 doesn't
reach drops to `tail-only`. The estimates are measured during the
build.

**The shop** (`tarnbeck-outdoor-shop`, measured):

| Instance | Fault | Estimate | Why |
|---|---|---|---|
| f1 | scheduler-query-error | supported | errors overlay on the key |
| f2 | scheduler-report-unbounded | supported | temp bytes and files per call |
| f3 | scheduler-insert-retry-duplicates | supported | state; rows at virtual times |
| f4 | scheduler-transaction-held-open | tail-only, 2 h | autovacuum's "not yet removable" lines are genuine only in the tail; the fill holds the snapshot |
| f5 | scheduler-batch-at-peak | tail-only, covers 12:00 | the noon lock waits are genuine only in the tail; no `daily_spike` (run R holds no sample of the noon run, and the span holds no noon before the tail) |
| f6 | scheduler-job-wrong-timezone | supported | the 10:00 run, in the fill or the tail |
| f7 | pgbouncer-pool-too-small | tail-only, covers 12:00 | the fill bypasses the pooler; its statistics start at the restart |
| f8 | pg-join-index-missing | supported | planted by the fill at virtual 08:00 |
| f9 | pg-table-autovacuum-off | supported | state; hides f4's trail in `orders`' state and the autovacuum log lines only: the exporter has no per-table series and run R shows f4's `max_tx_duration` sawtooth throughout, so no `suppressed_by` |
| f10 | prometheus-scrape-target-missing | supported | `remove` |

The full selection's tail: three hours (anchor 11:00, the noon peak
inside).

**The campaign** (`tarnbeck-outdoor-campaign`):

| Instance | Fault | Estimate | Why |
|---|---|---|---|
| f1 | purpose-mail-overlapping-window | supported (P0) | a job every five minutes, virtual |
| f2 | purpose-leads-stale-consent | supported (P0) | the release at virtual T0, jobs virtual |
| f3 | purpose-mail-outside-hours | supported (P0) | the campaign job, virtual |
| f4 | purpose-watermark-misses-updates | supported (P0, the cover) | the roll-up and the 12:00 close, virtual; its check reads present after the restart with no 12:00 close in the tail (chunk 11's short fill) |
| f5 | purpose-etl-role-expired | tail-only, planted in the tail | its refusals in the PostgreSQL log must follow its planting; hides f4's and f7's trails in state and logs only (`reporting`'s rows, `rpt.etl_runs`, the logs), which no exporter reads, so no `suppressed_by` |
| f6 | security-crontab-superuser | tail-only, 1 h | the cron daemon is off in the fill |
| f7 | purpose-day-boundary-wrong-zone | supported (P0, the cover) | the 01:30 close, virtual |
| f8 | purpose-receiver-down-unnoticed | supported | the gateway's outage at virtual 08:00–10:00 |
| f9 | governance-personal-copied | supported | its definitions are state; the `pg_cron` copy's run history holds the tail only |
| f10 | purpose-heavy-job-on-database-node | **real-only** | a real out-of-memory kill and crash recovery at 03:00, read from the PostgreSQL log; a redesign moving it into the tail is possible later |

f5 hides f4, f7 and f10, in state and logs. f10 is issue 6's cause (the starter pack's
"The reporting database"), so a fake game of the campaign is a variant
designed without f10 and issue 6 (9.1); in it, with f5 planted in the
tail, the GM checks f5's order against f4's and f7's runs when it
composes the selection.

**If P0 fails for a fault** (f4 or f7, should the cover not hold): it
drops to `tail-only`, with the tail its job's runs need, and leaves
v0.6's short campaign check for the full selection's run in v1.0
gating. f8 and f9 need no P0; f1's job runs every five minutes and fits
a 15-minute tail in any case.

**The clinic** is later: it needs a standby and a base backup built
after the fill, the vault's gap for the fill's span, two hosts; its s8
(the standby's apply delay) is `real-only` unless the fill emulates the
delayed read, its s2 (a silent archive command) and s7 (a statement log
holding personal data) `tail-only`.

### 9.9 The fix list

Every fixable caveat is fixed.

| # | Fix | How |
|---|---|---|
| 1 | Generator bugs | noise clamped at zero and scaled to the value (no negative scrape duration); start times constant, stepping only at a restart; the forged past draws the restart itself at the anchor: a `pg_up` and `up` blip, start times stepping, the restarted processes' counters resetting at that instant |
| 2 | A coherent restart | one event: every service of the game restarted at the anchor (fresh process namespaces, so start times and process IDs agree with it), the statement and shared statistics reset as part of that maintenance and not at the deploy (the reset is its step before the stop: statistics survive a clean shutdown, so `stats_reset` seconds before the postmaster's start reads as the maintenance resetting them, then restarting), no `reload status=ok` line; the PostgreSQL, pooler and cron logs start there; the forged log volume grows through the day and drops at the restart; the story line names the restart |
| 3 | Statistics off during the load and the fill | the fill's sessions run as `load-data`'s: `pg_stat_statements` not tracking, no statement log, no pgaudit; `track_counts` stays on, since autovacuum and the faults read the table statistics |
| 4 | WAL, checkpoints, the LSN | at the clean-up, the WAL padded with `pg_logical_emit_message` to a day's worth at the scenario's measured WAL rate, then `CHECKPOINT` and `pg_switch_wal()` twice, so the fill's segments are recycled; the checkpointer and WAL statistics reset with the shared ones |
| 5 | Calibrated overlays | the measured costs; a `gauge_before` for a dropped index's size; no overlay below the night's floor; activity gauges drawn around the tail's median with the real spread; database size growing with the load's shape |
| 6 | One baseline | the profile baseline is the product's only one; the recorded baseline stays a research tool |
| 7 | Autovacuum through the fill | `autovacuum_naptime` lowered for the fill, so autovacuum visits a table as often per dirtied row as in a real day; no manual `VACUUM`, which would count apart and be a tell |
| 8 | Data files' modification times | each data file set to its last virtual write before the restart (file times, not the clock): a file last written during the fill at its instant on the fill's clock (the fill's real span mapped linearly onto the virtual T0 to the anchor), one written before the fill as far before the virtual T0 as it was before the fill's start, one written after it (the clean-up's checkpoints) at the anchor; `pg_wal` and `postmaster.*` left as they are |
| 9 | Monitoring's footprint in the database | the fill opens the exporter's and pgwatch's sessions at the scrape rate in virtual time |
| 10 | Fault parameters, not constants | the queue model and the overlays read the instance's parameters and the keys' measured service times |
| 11 | The seed and the plantings at T0 dated from the virtual T0 | `load-data`, and `inject`'s plantings at T0, run on the virtual T0's clock with P0's means: every session given `gm.vclock` at the virtual T0 and the path `"$user", public, gm_vclock, pg_catalog` (the default path, `gm_vclock` placed by 9.4's rule), so the time-of-day functions it calls read that instant and what it creates unqualified lands where a real load puts it; in the SQL `load-data` sends, the time-of-day keywords bound to it outside DDL, and in DDL every unqualified `now()` and its kin written `pg_catalog.`, so a stored default or view binds the real function, as a real load leaves it, and the shim's drop reaches no customer object; inject's scripts run unchanged, with the session means only. So the seeded history ends at the virtual T0 and the fill continues it: no seeded or T0-planted time after the virtual T0. The fill's plantings at its pauses take the same session means at the pause's virtual instant (9.4 step 5). The real mode is unchanged |
| 12 | The forged past's counters follow what drives them | a series of the scheduler's roles (its `user` label) or, without a `user` label, of its databases (`datname`) follows the fill's load, with no floor at night; one of another role or database (the monitoring's own queries, the `postgres` database) stays flat at the tail's rate; a series with neither label follows the load; each database's `pg_stat_database_*` series follow the transactions the fill ran on it each virtual minute, the fill's clock setting excluded, at the tail's rate per call: their level is the fill's transactions per call there over its last hour times the tail's calls, so what the fill doesn't run (a session's set-up, autovacuum) keeps the tail's share, and a fault's own commits come from its signature (the shop's f8: 4 a call of its key, its scan's parallel workers starting). Every shape is a 15-minute moving mean, bounded at 2 % to 4 times the tail's, a floor far under any night the games draw |

**Not done, on purpose**: resetting the table and index statistics at
the clean-up. It would hide the last-use times, but it zeroes the dead
row counts and the counters autovacuum triggers on, which several
faults' evidence and the hiding pairs read. The last-use times stay a
documented limit.

### 9.10 Documented limits

What fake aging can't hide without fake time. A student doing the audit
isn't expected to find these; a DBA hunting with superuser access can.

| Limit | Where it shows | Covered by the story? | Curation |
|---|---|---|---|
| The restart itself: the postmaster's start, every container's start, process IDs counted from it, the statistics' reset time (seconds before the postmaster's start), the logs' first lines | `pg_postmaster_start_time()`, `ps`, `stats_reset`, the log folder | yes | none |
| No log before the restart: PostgreSQL, the pooler, pgaudit, the cron jobs (the scheduler's own log does cover the fill) | the log folders | yes, "older logs archived" | a fault whose evidence is a pre-restart log line is `real-only`, or `tail-only` planted in the tail |
| Real-clock actors start at the restart: `pg_cron`'s run history, the crontab's runs, the pooler's statistics, archiving, Grafana's alert state and history | those views | partly | a fault read through these is `tail-only` with enough tail, or `real-only` |
| The data files' inode change times are the fill's real minutes | `pg_stat_file()`, `stat`, `ls -lc` | partly | none |
| Last-use times of what only the fill touched fall in the minutes before the restart | `pg_stat_user_tables`, `pg_stat_user_indexes` | no | none |
| The LSN and WAL volume, if the padding doesn't hold | `pg_current_wal_lsn()`, segment names | partly | none |
| Time-driven behaviour in the fill is emulated in outcome only (a held snapshot, a timeout, a lock wait, an out-of-memory kill) | the fill's span in logs and views | no | `tail-only` or `real-only` |
| The archive vault and a standby date from the restart | the vault, `pg_stat_replication`, a slot's age | partly | the clinic, later |
| Prometheus' imported blocks carry their creation time, and Prometheus starts at the restart | the TSDB's files; Prometheus' runtime info | the start, yes | none; the players' shell on the Prometheus node can't read the TSDB folder (`prometheus:prometheus`, `0750`), which the import keeps |
| Prometheus' own series show the import, about 12 minutes after the restart: its lowest timestamp drops from the restart to the virtual T0, its loaded blocks and their bytes step up (a game with a Prometheus node) | `prometheus_tsdb_lowest_timestamp_seconds`, `prometheus_tsdb_blocks_loaded`, `prometheus_tsdb_storage_blocks_bytes`, in Prometheus and Grafana | no | none: the tail's own samples can't be rewritten without the admin API |
| The forged past's fine shape: series appearing over the day, rarely called statements | Prometheus | no | none |
| Each routine the fill covered (one pinning its own `search_path`, 9.4) has a new catalog row version from the fill's minutes, its definition and settings identical | `pg_proc`'s `xmin` against the other routines'; two updates on `pg_proc` in `pg_stat_sys_tables` | partly: a change in the maintenance before the restart, not named | none; only routines pinning their own path are covered |

The host's uptime and Docker's task history are out of the players'
reach: they have the bastion only.

**Where it is documented**, all GM-facing: once, in the GM's guide to
aging ([scenario-lifecycle.md](../../scenario-lifecycle.md) "Aging",
[gm-stance.md](../../gm-stance.md) "Aging feasibility"); per fault, in
`aging.fake.reason` and a "Fake aging" note in `gm.md`; per scenario, a
generated "Fake aging" section of the scenario document (each
instance's support, the tail the full selection needs, the instances
refused, the limits that touch its evidence, and the setup's measured
time from the deploy to the restart, the fill's duration within it);
per game, the restart
record. The section's limits are the rows the restart record's
`explains` would hold for the scenario, read at design time, so the two
never disagree; its setup time comes from the scenario's newest short
fake game record (12.1), the wait for the anchor not counted, since it
depends on when the setup starts, not on the scenario (formats.md, "The
scenario document"). Nothing reaches the bastion, the starter pack or a handout.

### 9.11 What the players are told, and when

**During the game: never.** The game is concluded when the players have
given their final answer and the GM has processed it. Until then, only
the in-world facts are spoken of (the customer's system was restarted
for maintenance this morning, its older logs are archived; that restart
really happened), and the GM never uses the words aging, fill, forged,
virtual clock or fake in anything a player reads (a restart's
confirmation and, when the initiator may play, the setup dialogue
included), nor confirms or denies a suspicion of forged history.

**After the final answer, in the feedback** (its two parts, section 10):

- **The customer side** stays in-world in every case. A reported tell
  matches no fault there: neither credited nor counted as a mistake. A
  sound reading of the restart's consequences is acknowledged from the
  restart record.
- **The teaching moment** may explain a **reported tell**: that the
  game was fake-aged, how, and why the thing looked as it did. A tell
  is reported when the report names an observation from the limits
  table or the research's tells, whatever cause the player gave it
  ("the statistics were reset this morning", "autovacuum barely ran on
  products", "the graphs before 11:00 look generated: negative scrape
  durations"). A suspicion naming no observation ("this history looks
  generated") is answered as any unsupported claim: noted as not backed
  by the report's evidence; it reports no tell.
- **No tell reported, no mention of aging.** The teaching part stays
  truthful without it: it explains each missed or unexplained finding
  from the evidence this game actually held, never from evidence a real
  aging would have left and this game didn't. If explaining a finding
  the report did make would be false without the aging, that finding
  rests on a tell, and the previous rule applies.
- **The same in a real game**: a report claiming a forged history gets
  the same customer side, and the teaching part explains why the thing
  really looked as it did.

The explanation is drawn from the scenario document's "Fake aging"
section, the fault's reason and `gm.md` note, and the restart record,
so it names this game's instants.

### 9.12 Where it belongs in the product

| Research piece | In the product |
|---|---|
| the fill driver | the scheduler program's **fill mode**, reusing the repository, builders, generators, the log's format and the minute summaries |
| the queue model | its code in the scheduler program, used by the fill's log lines and by `gmctl history`'s histograms; the keys' service times beside `queries.yaml`; the faults' effects in their `queue` entries |
| the fill runner | `gmctl fill`, with the pauses at plantings |
| the clean-up and the tail's start | `gmctl clean-restart`, `gmctl start-load` with a virtual T0 |
| the history generator, its snapshot and import scripts, the seam check | `gmctl history`: a GM tool, not a brick; it composes the overlays from the GM's selection, reads the live tail, writes into the game's Prometheus and checks the seam |
| the overlay file | each fault's `history:` |
| the calibration script | a calibration tool for the short real runs, in the repository's tooling, not `gmctl` |
| the comparison and tells scripts | the verification's tools |
| the recorded baseline, the research's deploy and run scripts | stay research |
| the research's results | the shop's reference, kept (section 12.3) |

Nothing is copied as is: the prototypes hardcode the shop's instances,
keys and parameters. They show what works.

### 9.13 Earlier rulings it touches

- **Real time and no forged history** stand for the real mode; the fake
  mode adds a forged Prometheus history and a compressed fill, no
  sped-up clock.
- **No time compression in play** stands: the fill compresses the past
  before the game; a fake game is played in real time like any other,
  and players still verify a job's fix by moving its time.
- **Classroom swarms waiting for aged volumes copied to them**: no
  longer planned. A quick game ages on the class's own hosts in about
  ten minutes plus the tail; an extended game keeps the always-on
  hosts. Moving a real-aged game to other hosts is the open "age once,
  restore many" question (section 18).
- **The eight-hour floor** holds for the virtual span; the GM's judgment
  gains the fake mode before declining.
- **Aged runs one-off, short tests only**: section 12 follows them.

## 10. The GM's feedback in two parts

The owner: "Explaining why things look like they did (due to aging or
due to planted faults) is one of the goal of the GM upon detailing its
appreciation of the report produced. One part will be the customer side
of thing, the other part is a teaching moment."

After the final answer, the GM's appreciation of the report has two
parts, in this order:

1. **The customer side**: the in-world assessment, in the GM's voice
   from the customer's point of view, never stepping out of the story.
   Each issue against its expected resolution and the answer key's
   acceptance criteria; the faults found against those present; the
   GM's tooling expectations; an overstep named.
2. **The teaching moment**: what the players missed, and how they could
   have seen it, from the evidence the game actually held; what they
   found correctly; what they identified but couldn't explain,
   explained; why things looked as they did, from a planted fault (its
   `gm.md`, the scenario's notes) or from the aging (a reported tell
   only, 9.11).

The tone stays a teacher's and positive: what was missed is said as how
it could have been seen. No reveal comes before the final answer: both
parts come after it, and the teaching moment is where the reveals live.
Answering in character as the customer during the game stays a future
idea; the customer side is an assessment after the game, not a
conversation during it. Whether there is also a score, and whether the
feedback is written to a file, stays open. Stated in
[gm-stance.md](../../gm-stance.md) "Feedback".

## 11. Language

Every player-facing material is in English: the starter pack, the
handouts, the documentation site, the status pages, the issues and the
feedback. A scenario language option may come later, not in v0.6.

## 12. Testing in v0.6

### 12.1 Short tests only

Each test under 30 minutes, on the least environment that proves its
brick or feature; a test longer than that runs once, in v1.0 gating.
No aged run.

- **The home page**: a fixture with two web routes and three of the
  seven documents: **Sites** lists the two routes and Reports,
  **Documents** the three present and no link to an absent one; a route
  named `docs`, `reports` or `status` refused by the loader.
- **The documentation site**: each starter-pack file and handout at its
  page, each documented brick's page, rendered from the starter pack as
  handed over (a player's edit of their home copy changes no page);
  every page behind the basic authentication; no page for a brick only
  a third party runs.
- **`jq` and `tmux`**: present and runnable as `player`; `jq` reading
  Prometheus' API through `curl`.
- **Reports**: a pgBadger report copied into `~/reports/` listed and
  served at `/reports/` with the sandbox header; nothing served from
  outside the folder.
- **The status pages**: a fixture with one partner with a player
  document and two admitted incidents, one started and one not: the
  page shows the started one only, then the other once its start
  passes (a start a few minutes ahead); a partner with none admitted
  shows "Operational"; the status file unreadable by `player`; no route
  to a third party's node in the front's configuration.
- **The network overview**: the skill on the clinic, the loader's
  coverage, digest, access and header checks each refusing a crafted
  break; a `docs-overview-*` fault planted, its diff in the answer key,
  its sealed check reading present; Node health's `node` variable
  filtering one node.
- **The loader's refusals**: the partners' page mapping, a seed-file
  instance's missing lines, `admitted:`, `aging.fake` and `history:`,
  `base:`, a domain's overview fragment; each with a unit test.
- **Fake aging, on the shop and on the campaign**, each under 30
  minutes: a selection whose tail fits a floor capped at 15 minutes
  (the shop: f1, f2, f3, f6, f8, f9, f10; the campaign: f1–f4 and f7–f9,
  or its fallback if P0 fails); fill, clean-restart, a 15-minute tail,
  the history import at about 12 minutes and the early check right
  after it; the checks reading every selected fault present; the seam
  check (no negative value, no counter reset outside the restart, size
  gauges joining, a past present); the tells script on the fixed tells (no negative or
  moving start time, no fill statement in `pg_stat_statements`, one
  `stats_reset` instant, `pg_wal`'s size, autovacuum counts in range);
  for the shop, the M1 and M3 comparisons against the saved real run as
  the reference, not a new real run. The saved run aged a different
  span with a different selection, so M1 scales it to the game's span:
  the game's M1 dumped at its virtual T0 (the same data and T0
  plantings the saved run started from) and at the read, each measure
  expected at T0 + `s` × (R − T0), T0 the game's value at its virtual T0,
  R the saved run's, `s` the share of the saved run's inserted rows that
  fell in the game's span (from its M3 profile); the measures inserts
  drive (each table's `n_tup_ins`, the sequences' `last_value`, the
  database's `tup_inserted`) judged within ±3 % of that, or one row
  either way for a count under 34, the rest reported, never judged,
  `n_live_tup` among them (an estimate VACUUM and ANALYZE overwrite,
  not a count inserts drive); the shop played as it is, never
  a copy at the saved run's span. M3 compares the hourly profiles over
  the hours the game's past holds (from its virtual T0 plus one hour to
  the last whole hour before the restart, the shop's 15), both handing
  over at the same scenario hour: the traffic (the scheduler's calls and
  errors a second, the database's commits and rows inserted a second,
  the statements' calls a second) judged, each at least 0.95 correlated
  with the saved run and its mean within 0.95 to 1.05 of the saved
  run's; the call p95, the size and resource gauges and the series
  count and the transactions' age reported, never judged (the saved
  run's span and selection move them).
  The script's record of each game is kept (9.7). For the campaign, the checks
  reading present, P0's jobs' outputs against their invariants, the
  seam and the tells. A start-time check confirms the monitoring
  started with the rest.
- **The history import, on `fixture-fill`** (wave 3), under 30
  minutes: the import at `restart.at` plus about 10 minutes, the seam,
  every kind read back over the past, the timer's run a no-op after it,
  the checks' line, the refusal once handed over, the snapshot's
  restart keeping the imported blocks. Its script starts only between
  hh:38 and hh:41, so the hand-over falls on a whole hour with an aging
  of at least eight hours inside the 30 minutes. The kind `none` (a
  signature's only entry, drawing nothing) is unit-tested only.

### 12.2 Unproven until v1.0 gating

Run once before the v1.0 tag, each longer than 30 minutes
([v1.0 gating](../README.md#v10-gating)):

- fake aging's full selections with their real tails, on the shop (its
  three-hour tail, f4, f5 and f7 included) and the campaign (f5 planted
  in the tail, its variant without f10 and issue 6, 9.8, and f2, f3,
  f4, f7 as `tail-only` if P0 failed);
- **the blind reads**, on a fake game of each full selection kept up for
  the read: a fresh agent with player access only, told nothing about
  aging, audits the scenario and is then asked whether anything about
  the system's history looked wrong; it passes if the reader doesn't
  come to suspect the history. The reader is a test agent, not a
  player, so the never-told rule doesn't apply to it;
- **the stance check-list's v0.6 items**: the feedback in its two parts,
  the customer side first and in-world; no aging word in anything a
  player reads before the game is concluded, a restart's confirmation
  and the setup dialogue with a playing initiator included; a reported
  tell explained in the teaching moment from the restart record and
  the documented limits; with no tell reported, no mention of aging.

### 12.3 The reference

The research's real run of the shop (about 2 GB, untracked, on the
research worktree) is the only real-aging reference. It must survive
that worktree, and none of it goes into git, small files included: the
whole folder is kept as one archive outside git, on armenelos; git
keeps only the pointer beside the verification tools (the archive's
path, size and checksum, how to extract it, a per-file manifest). A
tool or test reading the reference (the calibrations, the M1 dumps, the
M3 profile) extracts what it needs into an untracked working directory,
and skips, saying why, when the archive is absent.

## 13. Definition of done

v0.6 is done when:

1. `bastion` 0.6.0 serves the home page, the documentation site, the
   reports folder and the partners' status pages as sections 7.2 to 7.6
   state, with `jq` and `tmux`, and its short tests pass.
2. The format items of section 6 are in formats.md and the
   `scenario-format` skill's templates and checklist; the loader
   enforces section 6.10, each refusal with a unit test.
3. The `network-overview` skill generates the clinic's overview; the
   clinic's nodes carry their descriptions, the six domains their
   overview fragments, every brick its `base:`; the clinic's
   `player/README.md` has lost its node table; the scenario document shows the overview and
   each overview fault's diff.
4. At least one `docs-overview-*` fault is built, with its short test;
   Node health has its `node` variable (`grafana` 0.4.0).
5. Fake aging runs end to end on the shop and the campaign: `gmctl
   render --aging fake`, `fill` (`scheduler` 0.4.0), `clean-restart`,
   `start-load`, `history`, the early check, the restart record and
   `gmctl status`; every fault of both scenarios carries `aging.fake`
   and `history:` with measured numbers; the scenario document's "Fake
   aging" section; the ten fixes in; the limits documented where 9.10
   says; the short checks of 12.1 pass.
6. The `game-master` skill asks whether the initiator plays, offers the
   modes as 9.1 and 9.2 say, never names the technique to a possible
   player, gives the feedback in two parts, and explains a reported
   tell only after the final answer.
7. Every scenario repinned to the new brick versions and every fault
   still applying carries them; every existing scenario's checks still
   pass on the short fixtures.
8. The shop's reference preserved as 12.3 says.
9. v1.0 gating lists 12.2's items.

## 14. The release gate

1. Every short test of 12.1, each under 30 minutes, on the least
   environment.
2. The loader's unit tests, the format check of every scenario in the
   repository, and every brick's tests at its new version.
3. One fake game of the shop and one of the campaign, short-tail, as
   12.1 says, on one host.
4. The clinic's starter pack (its network overview, data register,
   partners' page and status file included) served by a bastion-only
   fixture and read through the front as `player`: the home page, every
   document, every partner's status page, a report in `~/reports/`. No
   whole-clinic deployment: its load alone takes about 28 minutes, and
   the whole clinic stays v1.0 gating's.
5. Known limits named in the release notes, each long check pointing to
   v1.0 gating.

## 15. For the build plan

A sketch for the build plan, which comes after the owner approves this
spec:

1. **The format and the loader**: the new keys, the overview's checks,
   `overview_diff:`, `admitted:`, reserved routes, `aging.fake` and
   `history:`, `base:`, the domains' overview fragment; the partners'
   page refusal and the seed-file lines refusal, in this first chunk
   touching `tools/gm/model.py`.
2. **`bastion` 0.6.0**: the home page, the documentation site and
   render's delivery of the brick pages, the reports folder, the status
   service and render's status file, `jq`, `tmux`, the seventh seed
   file.
3. **The network overview**: the skill and its template, the
   `scenario-document` and `scenario-format` changes, `game-master`'s
   setup step; `grafana` 0.4.0's variable.
4. **The domains and the clinic**: the six overview fragments, `base:`
   on every brick (the bumps and repins), the clinic's descriptions and
   overview, its README; one `docs-overview-*` fault with its test.
5. **The fill**: `scheduler` 0.4.0's fill mode and queue model;
   `gmctl fill`, P0 measured first.
6. **The restart and the timeline**: `render --aging fake`,
   `clean-restart` (fixes 2, 4, 7, 8), `start-load` with a virtual T0,
   the restart record, the early check's timing, `status`.
7. **The history**: `gmctl history`, the fault format's history
   signatures for the shop's and the campaign's faults, calibration's
   tool and the measured numbers, fixes 1, 5, 6, 9, 10.
8. **Verification and documentation**: the tells script and the
   comparisons as test tools, the shop's reference preserved, the
   short checks; the GM's guide, the faults' notes, the scenario
   document's "Fake aging" section; `game-master`'s dialogue and
   feedback.

## 16. Grounding: what exists and what is at risk

- **The bastion's front** today: `bricks/bastion/rootfs/usr/local/sbin/gm-entrypoint`
  writes nginx's configuration, the password file and one page under
  `/run/web-front` at each start; the page is a list of elements
  rendered with `cmark-gfm` from the starter pack's own copies, an
  absent element leaving nothing. v0.6 grows this list into a home page
  and pages of their own, and adds a long-running service (the status
  pages) beside sshd and nginx under s6. *At risk*: the front's
  configuration grows paths the route checks must keep apart from the
  web routes (the reserved names).
- **The routes' check**: `tools/gm/model.py`'s `_check_web_routes`
  refuses every third-party target but cold storage's console; the
  status pages add no route. The partners' seed file mapping is checked
  around `PARTNERS_SEED_FILE`; the new refusal goes there.
- **The data register skill** (`.claude/skills/data-register/`) is the
  network overview skill's model: digests, generated files, a diff in
  the answer key.
- **Unseen loading**: `tools/gm/inject.py`'s `UNSEEN_SQL` already loads
  without statement log, pgaudit or statement statistics; the fill
  reuses it.
- **The scheduler program** (`bricks/scheduler/program/gm_scheduler/`)
  holds the repository, builders and generators the fill mode reuses.
  *At risk*: the real mode's scheduling must stay byte-for-byte as it
  is; the fill mode is a separate entry point.
- **The research prototypes** (`tools/research/fake_aging/` on the
  research branch) hardcode the shop; they guide, they are not copied.
- **Every brick bumps** for `base:`, so every scenario repins: a wide,
  mechanical change that must not hide a behavioural one.
- **The Node health dashboard** (uid `node-health`) is in the `grafana`
  brick's files; adding a variable changes every panel's query.

## 17. Architectural decisions and their reasoning

- **One game's front, nothing above it.** A front above several games
  had been read into an earlier ruling; the owner meant one game's
  sites. Keeping the front per game keeps teardown, passwords and
  isolation as they are.
- **No reporting tool.** The players write their report where they
  like; the game judges it, not where it was typed.
- **The network overview generated, never written.** Generating it from
  the authoritative files keeps it consistent with the system and the
  register and lets the loader check its coverage; hand-written pages
  drift. The format additions give every field a source rather than
  having the skill read SQL comments, Dockerfiles and prose, which is
  fragile and can't be checked.
- **Your access exact, everything else possibly wrong.** A wrong access
  would mislead the players about the game's rules, not about the
  customer; the rest is customer documentation, which in real life is
  wrong in exactly the ways the traps model.
- **Handouts are static.** They are what the customer gave at the start;
  re-rendering them would turn a player's fix into a change of the
  evidence. The live tools follow the system on their own.
- **The page never absent**. The access rule
  lives on it and the README points to it.
- **Reports in a folder on the bastion**: no web
  server on the database nodes, no new route, one hop for the player;
  the sandbox header keeps a report's scripts away from Grafana's
  origin.
- **Status pages built by the bastion from GM data**: a third party's
  nodes stay out of the players' reach, so the page can't come from
  them; the status file stays root-only because it holds incidents
  still to come; the incident is marked on the fault instance because
  the incident is the fault, so an unselected fault admits nothing.
- **Fake aging is a fill plus forged history, never fake time.** Fake
  time would make every tool's clock lie and collide with the schedule
  faults; the fill compresses only the past, the game is real time.
- **Faults curated, not the fake stretched.** A fault declares what it
  needs; the GM refuses what the fake can't make, rather than the fake
  pretending.
- **One restart instant for every service**,
  the monitoring included: a monitoring that started later would be a
  tell of its own.
- **The restart record in the local implementation**: the restart is
  the game's event, not the scenario's, so the scenario format stays
  unchanged.
- **The early check after the history import**:
  the import is part of what must be right before the hand-over.
- **Table statistics kept**: resetting them would hide last-use times
  but break the evidence of several faults.
- **The initiator asked once whether they play**: the never-told rule
  binds anything a player reads, and a student playing alone is both; a teacher or the owner may still be
  told the mode.
- **Calibration by short real runs**: per-call costs don't need a day,
  and the research's guesses were far off.

## 18. Deferred items, open questions and points left to the build

**Open, not v0.6's to settle**:

- Whether the feedback carries a score, and whether it is written to a
  file (the teacher is out of the game by then).
- Where the solvability probe enters as a gate. In a fake game a probe
  failing at hand-over costs a tail, not a day.
- A snapshot of the whole game, with its game time, restored many times
  ("age once, restore many"); it inherits the volume copy's use.
- A scenario language option.
- Non-fault notices on a partner's status page.
- Fake aging for the clinic, and the campaign's out-of-memory fault
  redesigned into the tail.

**To measure during the build** (technical, none the owner's):

- P0: binding `now()`, `current_date` and `current_timestamp` to the
  virtual instant inside the server-side functions the fill's SQL calls,
  not only in the scheduler's own SQL. Measured partial in the build: a
  routine pinning its own `search_path` is out of the fill's session
  path, so the cover (9.4) reaches it, f4's and f7's calibration
  confirming it; a fault P0 doesn't reach drops to `tail-only` and
  leaves the campaign's short check (9.8).
- The WAL padding: its time and the WAL left after the checkpoints:
  measured in wave 4's short games, 0.5 to 2.5 s a node, `pg_wal` at
  98 to 100 % of the padding's figure at the read.
- A short autovacuum naptime: the autovacuum counts in range without
  slowing the fill: measured in wave 4, the tells' autovacuum counts in
  range on both scenarios (the shop's `customers` against the saved
  run, D596), the fills 7 min 53 s (shop) and 3 min 16 s (campaign).
- A restart of every service keeps everything the fill wrote (the
  scheduler logs on their volume) and gives fresh process namespaces;
  the monitoring scaled up in the same restart: measured in wave 4,
  every service of both games, the monitoring's included, started
  within 10 s after `restart.at`.
- `daily_spike` and `gauge_before`: measured in wave 3, `fixture-fill`'s
  history run reading every kind back over the past (`gauge_before` on
  `pg_database_size_bytes`).
- A fake game's restart from its hand-over snapshot keeps the imported
  blocks: measured in wave 3, the seam `ok` after it.
- Prometheus' retention against imported blocks older than the head,
  after a compaction: measured partial in wave 3, the lowest timestamp
  at the virtual T0 a minute after the import and after the snapshot's
  restart (a past of under eight hours); in wave 4, the shop's and the
  campaign's 16-hour pasts kept to within 3 s of the virtual T0 at the
  read, about 15 minutes after the import; a compaction not measured,
  left to v1.0 gating's full selections.
- The players' shell on the Prometheus node can't read the TSDB folder,
  whose owner and mode the import keeps (the shell itself stays: f10's
  fix edits `prometheus.yml` there): the folder measured
  `prometheus:prometheus 0750` after the import in wave 3; the `player`
  account's listing refused in both of wave 4's short games.
- Whether the campaign's f4 check needs the 12:00 close in the tail:
  measured in wave 3, it doesn't (9.8).
- The bricks' exact versions if a build finds more to change (folded
  into the unreleased version).

**Points settled while closing the review**, standing as written
since the owner's approval of 2026-11-16, 9.2 confirmed: the initiator
asked once whether they play, and the technique never named to a
possible player
(9.2); the network overview's absence dropped as a trap (8.5); the
restart record's place and fields (6.7, 9.4); the monitoring started in
the restart and the early check's timing (9.3, 9.4); the campaign's
fallback selection if P0 fails (9.8); the reports folder (7.5); a
scenario without an overview keeping its README node table (8.7).
