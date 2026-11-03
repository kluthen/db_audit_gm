# v0.5 — a scenario's data register, a player handout

Status: draft v1, for the owner. The ruling is settled (D329–D331);
everything below it is (proposed) unless marked otherwise. The test
selection's swap is the GM's choice (D332).

## The ruling (D329–D331)

The owner, on 2026-11-03: "this repo doesn't "need" to have a data
register (the only data register the game itself would have will focus
on bricks, faults, domains, etc). Scenarios may/should have data
registries (as handout) to the players(could also be some fault here:
desync from the ground truth, entierely absent, ill documented, etc),
and i'm pretty sure some are computed anyway by the gm to shape the
databases. If the test scenario for this setting is entierely fixed then
we should have a data registry, we should probably give it as a handout
to the player as well. (or at least i would believe it something
sensible to do)." And, the same day: "it should probably be added as a
subskill to the GM ensuring such registries get generated with the
appropriate informations (with fault planted or not)."

Settled by it:

- **No data register for the repository (D329).** No `data-register/`,
  and no data preflight in v0.5's consolidation or build plan: every
  scenario's data is synthetic. The game's own inventory is its
  catalogue: bricks, faults, purposes, domains.
- **A scenario's data register is game content (D330).** A player
  handout listing the business's data: what is held, where, its class,
  why, where it goes and how long it is kept. It is generated from the
  ground truth, which the domains' classification and governance (step
  5) and the scenario's composition (D322, D326) already compute. It
  may carry a fault: out of step with the ground truth, absent, or badly
  documented: a trap family (section 4). This narrows O21 (starter
  documentation carrying faults, v0.6) to the other starter files.
- **The clinic's test scenario gets one** (D330), handed to the players.
- **A GM sub-skill generates it** (D331), with or without a planted
  fault (section 3).

## 1. What one entry holds, and how the register is grouped

A real organisation's record of processing (GDPR Art 30(1)) is usually
a table with one row per **processing activity**, grouped by
department. Each row gives the purpose, the people concerned, the
categories of data, the recipients, any transfer outside the EU, the
retention period and, where possible, the security measures. Most
organisations add the systems where the data is held. The handout
follows that shape, with two departures to suit the game:

- **It covers all the business's data**, internal data included, as an
  inventory does, because the players audit systems and not only
  personal data. Activities holding internal data only go in a closing
  table, one line each.
- **"Where" goes down to tables and columns**, because the players
  compare the register with the databases. That comparison is the whole
  point of the handout, and it is what lets a missing column be a fault.

**Grouping: by department, then by activity.** A department is a
domain under a business name (the core's records, the lab, scheduling,
housing, machinery, the portal). An entry is one activity. A short
index at the end lists each `node/database` and the entries held there,
for players who start from a system. The clinic comes to about twenty
entries plus the internal table, roughly 150 lines: a long handout, but
one the players can read.

**One entry:**

| Field | What it says | Computed from |
|---|---|---|
| **Activity** | a name and a stable id (`core-owners`) | the domain's register fragment |
| **Purpose** | why the data is held, in one line | the fragment, from step 5's rules |
| **People concerned** | owners and keepers, staff, referring vets, a practice's clients | the fragment, from step 5's readings |
| **Data held** | the columns, grouped by class (`personal`, `customer-linked`, `internal`) | the scenario's `classification.yaml` copies |
| **Where** | `node/database`, the tables; the copies (the standby, the vault) | the composition record's `at:`, the topology, replication |
| **Shared with** | each recipient, inside (`office`, the portal) or a third party by its `partners.md` name, with the fields it receives; processors marked; transfers outside the EU marked (the centres abroad) | `governance:`'s outbound flows, the purposes in use, `third_parties:` |
| **Kept for** | the period, then what happens to the data (erased or anonymised) | the fragment, from step 5's retention game values |

Security measures are left out. The data policy states them as rules,
and the register stays short.

The header names the controller (the centre, from the story) and a
contact for data protection, and points to the data policy for the
rules.

An entry, as the handout shows it (illustration only; the generator
writes the real ones):

```markdown
### core-owners: owners and keepers

- **Purpose**: identify the animals' owners and keepers, contact them,
  invoice them; their names and addresses in the medicines register
  (core rules 2, 10)
- **People concerned**: owners and keepers
- **Data held**: personal: `owners.id`, `name`, `email`, `phone`,
  `address`, `country`; `herds.id`, `holding_number`;
  customer-linked: `ownerships.animal_id`, `owner_id`, `herds.keeper_owner_id`
- **Where**: `records/clinic` (`owners`, `ownerships`, `herds`); the
  standby off site; the vault (WAL archive, nightly base backup)
- **Shared with**: the portal (`records/portal`: name, e-mail, phone);
  the back office (`records/office`: name, address, for a dispensing);
  the franchise's messaging service, a processor (address, animal's
  name); cold storage, a processor (the whole instance, archived)
- **Kept for**: five years after the last record, then erased or
  anonymised (core rule 9)
```

## 2. Two handouts: the policy states the rules, the register the inventory

v0.4's data policy (D191) is the company's rules, written as prose for
each class: where a class may live, who may read it, what may leave.
The GM writes it by adapting the domain's `docs/policy.md`. The register
is the inventory, and it is generated. They stay **two files**:

- they are made differently: the policy is written by the GM, the
  register is generated, and a register fault must never touch the
  policy;
- a real organisation keeps them apart too (a policy, and a record of
  processing);
- the policy stays the reference the players read the register
  against: a retention period or a class in the register that breaks
  the policy is a finding.

**How both reach the players:** the same way, as D221 set up.
`player/data-register.md` becomes a sixth optional seed file of the
bastion. Like `data-policy.md`, it is copied into `/home/player` and
shown on the starter-pack page, as a "Data register" item placed after
the data policy, and only when the scenario has one. It goes in the same
small `bastion` bump as `partners.md` (D274). The policy says the
register exists ("what we hold, where and for how long: our register of
processing"). It says so even when a fault leaves the register out,
because that sentence is what gives the absence away (T305).

## 3. Generation: the GM's `data-register` skill (D331)

A GM sub-skill, `.claude/skills/data-register/`, built on the
`scenario-document` model: generated from the authoritative files, never
edited by hand, and regenerated rather than reconciled.

- **Inputs**: the composed domains' classification (the scenario's
  copies of `classification.yaml`) and governance (`governance:`, the
  policy's retention values); a new per-domain **register fragment**,
  `data/register.yaml` (each activity's id, name, purpose, people
  concerned, tables and retention, transcribed from step 5); the
  composition record (`composition.yaml`); `scenario.yaml` (the
  topology, `third_parties:`, the purposes in use, the register faults
  among the fault instances); and `gm/answer-key.yaml`.
- **Outputs**:
  - **`gm/data-register.yaml`**, the true register, sealed like the
    rest of `gm/`. It opens with `generated_from:`, the digest of each
    input file.
  - **`player/data-register.md`**, the handout. It is the true register
    rendered as is, or, when a register fault is planted, with that
    fault's change applied. With T305 planted, there is no handout file.
  - **In the answer key**, for each register fault instance, its
    `register_diff:`: the entry, the field, the true value and the
    value handed out (for T305, `absent: true`). The scenario document
    shows the diff in a "Data register" section.
- **Triggers**: when a scenario is composed or regenerated; after any
  change to its domains, classification, governance, composition,
  purposes, topology or register faults; and before deploy, at
  setup step 2.
- **Completeness**: the deploy refuses a scenario whose register is
  missing or stale, as it refuses an incomplete scenario (the
  scenario-format skill, `gmctl fit`). The loader:
  - recomputes the digests;
  - checks that the true register covers its inputs: every `personal`
    and `customer-linked` column in exactly one entry, under its class;
    every `governance:` location and outbound flow present; every
    database with business tables in at least one entry. A miss here
    is a generation error, caught before hand-over and never a fault,
    as with D322's coherence check;
  - checks that the handout exists unless the answer key declares it
    absent as a planted fault, which passes.

  Which scenarios must have a register is O219.
- **How game-master calls it**: at Setup step 2, after the
  scenario-format completeness check and before scenario-document,
  which reads its outputs. The order is format, then register, then
  document. On a restart the GM reads the true register with the
  scenario document; during the game it never shows or quotes the true
  register, under no reveals (gm-stance).
- **Where the true register stops**: it describes the system as
  designed and composed, before any fault is planted. A fault planted in
  the system (T49 sending a chip to the external lab) leaves the true
  register and the handout unchanged. The register is then the
  reference the players read the system against, as the policy is.

`gmctl` gains no generator. The skill writes the files, and the loader
checks them. Writing `SKILL.md` and its template is a build chunk
(section 7). It is not written now because its inputs (the register
fragment, the answer key's `register_diff:`) wait on O218.

## 4. The trap family: the register itself (T300–T308)

Added to [clinic-traps.md](clinic-traps.md) as section 11. Every trap
here is planted in the handout only; nothing in the system changes.
Injection is a `seed-file` change on the bastion
(`seed_changes: data-register.md`): the scenario's copy carries the
change, as a data file's copy does (D226), and the skill writes it.
Fault ids are `governance-register-*`, in the `security` family (D215).
Each witness is the register read against the system, the data policy
or `partners.md`. The players cannot edit the customer's register, so
each trap's resolution is **propose**: the players give the corrected
entry, and the GM judges it at the final answer against the answer
key's `register_diff:`, as D325 judges s9 on the report. The sealed
check reads only that the change is present in the bastion's copy
(O217).

| # | Trap | Witness | Class |
|---|---|---|---|
| T300 | An entry out of date: the portal "shows the record" and holds only accounts and consents, while `portal` holds copies of diagnoses, prescriptions and results (D322's derivation) | `portal`'s tables and their rows against the entry | M |
| T301 | A column missing: `exchanges.partner_patient`, the free-text summary that may name the owner, left out of the exchanges' entry | the column, and its rows naming a person | M |
| T302 | A store missing: `office` absent, though its medicines and controlled-drugs registers hold the recipients' names and addresses | `office`'s tables on the core's instance | M |
| T303 | A wrong class: microchips, UELNs and passport numbers listed as `internal` ("the animal's data") | the policy's reading that a natural identifier is personal; the columns | M, V when a reader leaned on it (T25 or T49 in play) |
| T304 | A wrong retention: the controlled-drugs register "five years" | the policy's ten (core rule 3) | M |
| T305 | The register absent: the policy names a register of processing, the bastion gives none | the policy's sentence; `/home/player` and the page | M |
| T306 | The register vague: "our systems", "as long as necessary", no recipients | the entries themselves against the policy | M |
| T307 | A flow not declared, to a processor: cold storage, the vault holding the WAL archive and nightly base backups of `records`, `lab` and `machines`, named nowhere | `archive_command` and the backup job; the vault's page and its `wal` and `basebackup` manifests; `partners.md` | M |
| T308 | A flow not declared, to a processor: the franchise's messaging service, which receives owners' addresses and animals' names, missing from the portal's accounts | `portal_outbox`'s payloads; `partners.md` | M |

**The class:** D290 counts a register fault as M by default. Nothing
breaks and nothing gets worse. A D needs a story the customer has
noticed: an owner's access request answered from the register and
missing a recipient, or an inspector asking for the record. False-alarm
material:

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "The register keeps clinical records five years; France keeps ten" | five is the policy's game value, stated as one (core rule 9) | the policy |
| "The register names no recipient for the lab's results coming back" | an inbound flow is a source, not a recipient | the external lab's entry in `partners.md` |

v0.5 builds only the one register fault the test selection takes (D316,
D332). The skill must still be able to apply any variant, since a GM
selects among them at deploy (D309).

## 5. The test selection (D332, the GM's under D309)

**A register fault joins the ten, as s6: T307, the vault not declared.
It replaces T49, which goes back to the traps.** The reasons:

- v0.5 builds the register and its skill. A planted deviation, with the
  true and handed-out registers and the answer key's diff, is the one
  part of that machinery no clean register proves.
- T307's witness is on the system: `archive_command`, the backup job and
  the vault's manifests. It is not only one handout read against
  another. It also reuses a fixture that already exists.
- T49 adapts v0.4's `governance-personal-copied`, whose mechanism (the
  outbound `fields` check) v0.4 already proved. Governance stays covered
  by s5 (row-level security), s7 (the logs) and now the record of
  processing. s8 and s10 prove v0.5 mechanisms that are new (the
  standby, the options model).

D290's mix holds: one M for another, so 1 D, 2 V, 7 M and the false
alarm. The false alarm keeps the send-outs fixture.

**Its short test**, on the archive fixture (`records`, the partners'
`api` node and database, the bastion), about 10 minutes:

- *Present*: the bastion serves `data-register.md` (in `/home/player`
  and on the page) with cold storage among no entry's recipients; the
  true register names it on every entry it holds; the vault's page lists
  `records`' `wal` and `basebackup` manifests.
- *Cleared*: the handout regenerated without the fault names cold
  storage, which proves the change is reversible.
- *Resolution*: propose, judged at the final answer.

s2 sits on the same fixture. Planted together, the archive fails
silently while the vault still holds the planted manifests and the
nightly base backups, so T307's witness stands. The answer key notes
the interaction.

## 6. Format impact (O111, O218)

Beyond O111's confirmed text (D326), so for the owner with this page
(O218):

- **A domain:** `data/register.yaml`, the register fragment, declared
  in `domain.yaml`. A new checklist item: every table belongs to one
  activity.
- **A scenario:**
  - `governance.register: player/data-register.md`, mapped to the
    bastion's optional seed file `data-register.md`, as `policy:` maps
    to `data-policy.md`;
  - `gm/data-register.yaml`, the true register;
  - the answer key's `register_diff:` on a register fault instance;
  - the loader's checks in section 3.

  `formats.md`'s layout gains the two files. No `data-register` section
  goes inside `scenario.yaml`: the true register is a generated file, not
  a key.
- **The bastion:** a sixth optional seed file and a "Data register"
  item on the page (D221), in `partners.md`'s bump (D274).
- **The skills:** `data-register` is new; `game-master`'s Setup step 2
  calls it; the `scenario-document` template gains a "Data register"
  section; the `scenario-format` checklist gains the register's items.

## 7. Build-plan chunks (for the build plan)

1. **The register fragments**, in each domain's own build chunk: the
   six `data/register.yaml` files, from step 5, and the checklist item.
   This is small, and goes where each domain's classification is built.
2. **The data register** (one chunk):
   - the `data-register` skill and its template;
   - `game-master`'s Setup step 2, and scenario-document's section;
   - the loader's checks and `formats.md`;
   - the bastion's sixth seed file and page item, with `partners.md`'s
     bump.

   Its check: the clinic scenario's register generated clean and passed
   by the loader's coverage checks; a stale digest refused; a declared
   absence passed. It waits on the domain format chunk (the composition
   record) and the domains' fragments.
3. **s6, `governance-register-flow-undeclared`**, with the test
   selection's other faults: its `fault.yaml`, the skill applying it,
   and its short test on the archive fixture.
4. **The clinic scenario** (the proof in play): its
   `player/data-register.md` with s6 planted, and `gm/data-register.yaml`.

## Questions for the owner

- **O217**: How does a register fault get resolved? Recommended:
  propose. The corrected entry is part of the players' report, and the
  GM judges it against the answer key. Handing back a corrected register
  as a file the GM compares waits for v0.6's reporting tool (O135).
- **O218**: Do you accept the format additions in section 6 (the
  domain's register fragment, the scenario's two files and the answer
  key's diff, the loader's digest and coverage checks), to go into the
  master spec with O111's text? Recommended: yes.
- **O219**: Which scenarios must have a register? Recommended: every
  scenario that lists `domains:` (v0.5's composed scenarios), with the
  deploy refusing one without. The shop's v0.4 scenario, already
  released, stays exempt until it is next revised. A scenario with
  `governance:` and no `domains:` may have a register but is not
  required to.
