---
name: data-register
description: Use whenever a db_audit_gm scenario's data register has to be generated or regenerated — the true register gm/data-register.yaml, the player handout player/data-register.md and each register fault's register_diff in the answer key — when a scenario listing domains: (or one with governance.register) is composed or regenerated, after any change to its domains, classification, governance, composition, purposes, topology, third parties or register faults, and before deploying, at the game-master-setup skill's Setup step 2, between the format check and the scenario document. Generated from the authoritative files, never edited by hand, regenerated rather than reconciled.
---

# Data register

A scenario's **data register** is game content (master spec 13.2, 13.3;
v0.5's data-register-handout.md,
sections 1 to 3; capture W4 item 1 of
the v0.5 wave log): a player
handout listing the business's data in the shape of a record of processing
(GDPR Art 30), with two departures. It covers **all** the business's data,
internal included (activities holding internal data only in a closing
table, one line each), and its "where" goes down to **tables and columns**,
since the players compare it with the databases. This skill writes it on
the [scenario-document](../scenario-document/SKILL.md) model: from the
authoritative files, never by hand, and regenerated rather than reconciled.
This is its **v0.5 version**, expected to evolve as games are played.

The skill writes three things:

| Output | What | Sealed |
|---|---|---|
| `gm/data-register.yaml` | the **true register**: `generated_from:` (each input's digest), the header, one entry per register-fragment activity holding personal or customer-linked data, the internal table, the `node/database` index ([template](template.md), part 1) | yes, like the rest of `gm/` |
| `player/data-register.md` | the **handout**: the true register rendered as is, or with a planted register fault's change applied; absent when that fault is the register's absence (T305) ([template](template.md), part 2) | no: the bastion's optional seed file `data-register.md` |
| `register_diff:` in `gm/answer-key.yaml` | for each register fault instance, the entry, the field, the true value and the value handed out, or `[{absent: true}]` | yes |

`gmctl` has no generator: the skill writes, the loader checks
(`tools/gm/model.py`, "the data register"). The true register describes the
system **as designed and composed, before any fault is planted**: a fault
planted in the system (T49 sending a chip to the external lab) leaves both
registers unchanged. The register is a reference the players read the
system against, as they read the data policy. The policy and the register
stay two files: the GM writes the policy, this skill generates the
register, and **a register fault never touches the policy**.

## Which scenarios

- Every scenario listing `domains:` has one: `governance.register:
  player/data-register.md`, `gm/data-register.yaml`, and the bastion's
  `seed_files: {data-register.md: player/data-register.md}`. The loader
  refuses such a scenario without them.
- **Exempt**: v0.4's released shop scenario (`domain: shop`, no
  `domains:`) until it is next revised; a **test fixture**, whose id starts
  `fixture-` (spec D434). A fixture or a scenario with `governance:` alone
  *may* have one, and one that has a register is checked in full.

## When to generate or regenerate

- When a scenario is composed or regenerated (after `gmctl compose`).
- After any change to its domains (their fragments in the catalogue),
  its classification copy, `governance:` or the policy, the composition
  record, its purposes, its topology or third parties (`scenario.yaml`),
  `partners.md`, or its register faults (the answer key).
- Before deploy, at the game-master-setup skill's **Setup step 2**: the format check
  first, then this skill, then the scenario document, which reads its
  outputs. The loader refuses a register whose digests no longer match
  ("stale register: regenerate with the data-register skill").
- After this skill's template changes, for the scenarios about to be used.

Never edit either file by hand, nor the `register_diff:` it wrote: change
an input and regenerate.

## Inputs (W4 item 1)

From the scenario folder: `scenario.yaml` (topology, `domains:`,
`purposes:`, `third_parties:`, the fault instances, `governance:`),
`composition.yaml`, the files `governance:` names (`classification`, the
classification copy, and `policy`, the data policy), `player/partners.md`
when the bastion maps it, and `gm/answer-key.yaml`. From the catalogue:
each composed domain's register fragment (`domains/<id>/data/register.yaml`,
the file its `domain.yaml` names under `register:`) and each `purposes:`
entry's `purposes/<id>/purpose.yaml` (its `classification:` and
`data_moved:`). The header's controller and data-protection contact come
from the story (`player/story.md`).

## Generating it, in this order

The answer key is both an input and an output: it is written first, then
every input is digested, so a plain byte digest stays current and any
later edit to an input makes the register stale (W4 item 1).

1. **The true entries.** Build every entry and internal line (below)
   from the inputs, without any fault.
2. **The register faults.** For each fault instance whose definition's
   `seed_changes` name the bastion's `data-register.md` (a register
   fault, ids `governance-register-*`), apply its change to a copy of the
   true entries (see "Register faults") and write its instance's
   `register_diff:` into `gm/answer-key.yaml`. The answer key is then
   final.
3. **The digests.** For each input, `sha256sum <file>`, except
   `composition.yaml`, digested without its top-level `coherence:` key and
   the indented lines under it (the record `load-data` rewrites, spec D465;
   a file without the key digests as its bytes):
   `python3 -c 'from tools.gm import model;
   print(model.register_digest("composition.yaml", "<dir>/composition.yaml"))'`
   from the repository root (it gives any input's digest, its label
   first). Record each as
   `sha256:<hex>` under its path: scenario-relative
   (`scenario.yaml`, `data/classification.yaml`, `gm/answer-key.yaml`), or
   `catalog/<path>` for a catalogue file
   (`catalog/domains/vet-core/data/register.yaml`,
   `catalog/purposes/<id>/purpose.yaml`). Every expected input is listed,
   and nothing else.
4. **Write both files**: `gm/data-register.yaml` (template part 1), then
   `player/data-register.md` (part 2) from the entries as the faults left
   them, or no handout file when a fault declares the register absent.
   Map the bastion's `data-register.md` to `governance.register`, or, for
   an absent register, map none.
5. **Check**: the loader's checks (any `gmctl` verb loading the scenario,
   or `python3 -c 'from tools.gm import model;
   model.load_scenario("<dir>")'`) must pass: digests, coverage, the
   handout. A coverage miss is a **generation error**, fixed here before
   the hand-over, never a fault.
6. Then the scenario document (scenario-document skill), whose "Data
   register" section shows each `register_diff:`.

## Building the entries

One record per **activity of a composed domain's register fragment**, in
the composition's `order:` (the core first), then the fragment's order; its
`id`, `name`, `purpose`, `people` and retention as the fragment states
them. An activity is an **entry** when at least one column of its tables
is `personal` or `customer-linked` in the classification copy; otherwise
it is an **internal line** (the closing table: id, department, name,
where, kept for).

- **department**: the domain under its business name, as the story or the
  domain's title names it ("The medical record", "The laboratory",
  "Scheduling", "Housing", "The machines", "The owners' portal"); a
  handout groups its entries by department.
- **A view** (a classified relation no fragment lists, since fragments
  list tables): it joins the activity of the table its `personal` or
  `customer-linked` columns come from (the core's `animal_board` the
  record, housing's `housing_unit_board` the care), under that entry's
  `where` tables and `data`.
- **data** (`data:`): the classification copy's keys
  (`<database>.<table>.<column>`, `<database>.<schema>.<table>.<column>`
  outside `public`) of the activity's tables whose class is `personal`,
  under `personal`, and `customer-linked`, under `customer-linked`, each
  **in exactly one entry**, under **its** class. Internal columns are not
  listed: the table is in `where`.
- **where** (`where:`): one item `{at: <node>/<database>, tables: [...]}`
  per location holding the activity's tables (the domain's `at:`, or for
  a part with several databases the location of each table's database);
  then the copies, each `{copy: <text>}`: a standby of that node
  (`standby_of`), "the standby `<node>`, a streaming replica"; an
  archiving node (`vault_target` on cold storage's hostname), "cold
  storage (WAL archive, nightly base backup)". Copies go on entries
  only: an internal line's `where` holds its locations. A third party's
  node (each `third_parties:` entry's `nodes`, and the partners' shared
  nodes serving the owners alone) is never in a `where` or the index:
  the loader refuses its name in the handout (master spec 10.2, spec
  D469), and the customer's governance holds no location there.
- **shared_with** (`shared_with:`), each recipient `{recipient, fields}`
  with `flow`, `processor`, `outside_eu` when they hold:
  - a `governance:` outbound flow of a class the entry holds whose
    `outbox` table is among the entry's tables: `recipient` the third
    party by its `partners.md` name (or the receiver's in-world name),
    `fields` the flow's `fields` (payload keys), **`flow` its `to:`
    label**: every outbound flow appears on at least one entry;
  - an inside recipient: another database a composed domain copies the
    entry's columns into (the portal's copies of the core, the
    composition's `derive:`), a purpose's target its `data_moved` writes
    them to (`office`), `recipient` its business name and location
    ("the owners' portal, records/portal"), `fields` the column names it
    receives;
  - a third party reached by a purpose or a domain's producer with the
    entry's data (the external lab, the centres abroad, the messaging
    service), by its `partners.md` name, with the fields;
  - cold storage when the entry's node archives to it: `recipient` its
    `partners.md` name, `fields: [the whole instance, archived]`,
    `processor: true` (the handout: "Cold Storage (the whole instance,
    archived), a processor");
  - `processor: true` for a party processing on the customer's behalf
    (cold storage, the franchise's messaging service); `outside_eu: true`
    for a transfer outside the EU (the story says where a partner is).
  An inbound flow is a source, never a recipient (the external lab's
  results coming back).
- **kept_for**: the fragment's `retention` (`period`, `then`: erased or
  anonymised), as written, even where the period already reads "then":
  game values stay game values.
- **A purpose's tables** (W4 item 1): a purpose table holding a
  `personal` or `customer-linked` column (its `classification:`) joins,
  under `where`, the entry of the activity whose tables its `data_moved`
  reads those columns from, its columns under that entry's `data`; one
  holding only `internal` columns goes in the internal table, one line per
  purpose (`id`: the purpose id). A purpose's table on the partners'
  database (its `target` there, as purposes 14 and 16's) stays out of
  its line, which lists the customer's side; what the customer sends
  there is a recipient in `shared_with`, on an entry.
- **The index** (`index:`): each `node/database` of any `where`, with the
  ids of the entries held there, then of the internal lines, each in file
  order; never a third party's node.
- **The header**: `controller` (the centre, as the story names it),
  `contact` (a data-protection contact the story gives, or the centre's
  data-protection officer by role), `policy` (`governance.policy`).

The loader checks the coverage: every `personal` and `customer-linked`
column of the classification copy and of the purposes' `classification:`
in exactly one entry under its class; every activity of every composed
fragment once, as an entry or an internal line; every `governance:`
location in some `where`; every outbound flow's label as some `flow`;
every `node/database` holding a classified table in some `where`; the
index matching the `where`s. The clinic comes to about twenty entries and
the internal table, about 150 lines of handout.

## Register faults

Planted in the handout only (master spec 13.4; handout section 4): the
fault's `seed_changes` is the bastion's `data-register.md`, the scenario's
handout carries the change, and regenerating without the fault clears it.
The fault definition's parameters say the change; the skill applies it to
the entries and computes `register_diff:` against the true register, **one
item per entry and field changed**: `{entry: <id>, field: <field>, true:
<value>, handed_out: <value>}`, `field` one of `purpose`, `people`,
`data`, `where`, `shared_with`, `kept_for`, the values as the handout
writes that field (a list stays a list; a field the change leaves empty as
the handout words it, `shared_with` "no one", since the loader refuses an
empty value). The resolution is *propose*, judged at the final answer
against the diff; the sealed check reads only that the change is present
in the bastion's copy.

| Trap | Change to the handout | `register_diff` |
|---|---|---|
| T300 an entry out of date | the entry's `purpose` and `data` as an older system had them (the portal "shows the record", holding accounts and consents only) | that entry's `purpose` and `data` |
| T301 a column missing | the column (`exchanges.partner_patient`) dropped from the entry's `data` | that entry's `data` |
| T302 a store missing | every `where` item at the location (`records/office`) dropped, and the index's line | each entry's `where` |
| T303 a wrong class | the columns (microchips, UELNs, passport numbers) moved under `internal`, out of `personal` | that entry's `data` |
| T304 a wrong retention | the entry's `kept_for` (controlled drugs "five years") | that entry's `kept_for` |
| T305 the register absent | no handout file; the bastion maps no `data-register.md`; the policy still says the register exists | `[{absent: true}]` |
| T306 the register vague | each `purpose` "our activities", `where` "our systems", `kept_for` "as long as necessary", `shared_with` none | each entry's four fields |
| T307 a flow not declared (cold storage) | the recipient dropped from every entry's `shared_with`, and its `{copy: cold storage (WAL archive, nightly base backup)}` item from every entry's `where`, so the vault is named nowhere (`governance-register-flow-undeclared`, its parameter `recipient`, default cold storage's `partners.md` name) | each entry's `shared_with` that named it, and each entry's `where` that held the copy |
| T308 a flow not declared (the messaging service) | as T307, `recipient` the messaging service (no copy to drop) | each entry's `shared_with` that named it |

A register fault counts as a minor friction (M) by default. The test
selection's s6 is T307 (chunk 23); a GM may plant any of them (fault
selection is the GM's).

## On a restart, and during the game

On a restart the GM reads the true register with the scenario document.
During the game it never shows or quotes the true register, nor the
`register_diff:` (no reveals, gm-stance): the players compare the handout
with the system, the policy and `partners.md`.

## Never edit it by hand

Both files and every `register_diff:` are generated. A wrong entry is
fixed in its input (the domain's fragment, the classification copy,
`governance:`, `scenario.yaml`) and the register regenerated; a stale
digest is cleared only by regenerating.
