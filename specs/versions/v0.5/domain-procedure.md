# v0.5 — defining a domain: the procedure

Status: approved v4 (D235, D249, D260, D263); section 10 ruled in
principle, its mechanism proposed (D322, D323). Settled by the owner on
2026-10-31 in two rulings: the clinic's cut (section 4, kept now,
revised once `vet-core` is defined), the composition rules (section 4),
the four format changes (section 6) and a skill later (section 8)
(D249); then the rest as drafted, what a domain holds and leaves out
(section 1), the steps and who takes part (2), done and the checklist
(3), and the effort estimate (7) (D260). On 2026-11-01 a domain's scale,
its variants and their tags (section 9, D263), closing O114; where the
variants are built is (proposed) in section 6. On 2026-11-03 composing
domains (section 10, D322): D249's keys stay the default, the initial
load is the GM's to adjudicate, the mechanism (proposed) with the
parts' format changes (D323), for O111.

The owner, on 2026-10-31: "we need a proper "procedure" to define a
domain, what we put in and not. the clinic will probably spawn multiple
such domain. depending on how long and complex definiting such domains
are, we will include or not other domain definitions right now or leave
them for later."

Built from the one domain that exists, the shop as v0.4 built it:
`domains/shop/` in the repository, [shop-domain.md](../v0.4/shop-domain.md),
[formats.md](../../formats.md) "Domain (from v0.4)", the `scenario-format`
skill's `templates/domain.yaml` and its "Domain" checks, and the loader's
`check_domain_dir` (`tools/gm/model.py`). The domain format's open part
is O111, finalised in the master spec when v0.5 consolidates (D291).

## 1. What a domain holds, and what it leaves out

A domain answers four questions about one kind of business: what it
holds, how its data arrives, what the data is for, and how sensitive it
is. Anything about the machines it runs on, how they are wired, or what
goes wrong belongs elsewhere.

| In a domain | Where it lives (the shop) | Fits as built? |
|---|---|---|
| **The business data model**: tables, keys, lifecycle states, roles and grants | `data/schema.sql` | yes |
| **The history**, "last night's backup", at the population and history its variant sets | `data/load.sql` | yes, for its one variant (section 9) |
| **Producer profiles**: how data arrives (traffic shapes, rates, fixed-time operations) | `producers/` (`queries.yaml`, `schedule.yaml`, `jobs.yaml` fragments) | yes; how a profile meets a scenario's schedule is ruled ([producer profiles](producer-profiles.md)) |
| **Scheduler scripts and input types**: builders and parameter generators | `producers/builders/` | yes; richer input types are ruled ([producer profiles](producer-profiles.md) 5) |
| **Purposes that fit** | listed by id in `domain.yaml`; each purpose is its own unit under `purposes/` | yes: defining a domain includes choosing or drafting its purposes, but a purpose stays its own unit, since it may fit several domains |
| **Data classification**: every column classed | `data/classification.yaml` | yes, with one change (section 6, item 2) |
| **Governance**: the business's own rules for its data | none: today a scenario's `governance:` and its policy text state every rule | **no** (section 6, item 1) |
| **GM notes**: the business, its data, roles, classification, producer, rules, traps, loading | `docs/gm.md` | yes; its sections become required |
| **Variants**: the setups the domain covers, each its parts, its scale and its tags | `variants/<name>.yaml` | **no**: new (section 9; section 6, item 5) |

Left out of a domain:

- **Topology**: which bricks, how many instances, where each database
  lands, the sites of a franchise. That is the scenario's, or a topology
  fragment's; for the clinic, a scenario deploys one centre, the other
  sites third parties (D285).
- **IT maturity**: the monitoring, the backups, the redundancy actually
  deployed. A variant's maturity tag states the intent; the topology
  fragment carrying the same tag holds what is deployed (section 9).
- **Bricks and brick options**: the catalogue's. A domain may say what
  it needs from them (for instance an audit trail needing pgaudit) in
  its GM notes; the option itself is the brick's
  ([brick-options-review.md](brick-options-review.md)).
- **Faults**: the catalogue's or a scenario's. A domain's GM notes list
  its **traps**, the places a fault can bite (the shop's "two places for
  one fact"), never fault definitions.
- **The story**: the company's name, staff and incidents are the
  scenario's. A domain may carry a default company (the shop is Tarnbeck
  Outdoor), which a scenario may rename.
- **Post-mortems** ([README](README.md#the-post-mortem-collection-d234)):
  not bound to a domain.

## 2. The steps, from a brief to a finished domain

| # | Step | Input | Output | Owner |
|---|---|---|---|---|
| 1 | **Brief** | the owner's description of the business (the clinic's, D196) | the brief, quoted in the version page | **writes it** |
| 2 | **Business sketch** | the brief | actors, activities, the variant's scale (population, history, throughput) and tags, cadences, regulations; the questions the brief leaves open | **answers the questions** |
| 3 | **Split** (composites only) | the sketch | a core and its parts (section 4) | **confirms the split** |
| 4 | **Data model** | the sketch; for a domain fed by an external dataset, that dataset's schema, size, licence and availability (O53, O54) | entities, keys, states, roles and grants, the variant's population and history within "schemas simple, tables small" | checks plausibility, optional |
| 5 | **Classification and governance** | the data model; the business's regulations | every column classed; the business's own rules (section 6, item 1) | **confirms the rules are realistic** |
| 6 | **Producer profiles** | the sketch's activities and cadences | traffic shapes and rates, fixed-time operations, input types; cadences real time cannot age flagged (monthly, yearly: O22) | only for a flagged cadence |
| 7 | **Purposes** | the data model, the existing purposes | which existing purposes fit; new ones named, each drafted as a purpose of its own ([formats.md](../../formats.md) "Purpose definition") | **chooses the purposes** |
| 8 | **Traps** | the model, the profiles, the purposes | where faults can bite, as a list, each with its D290 class | none: a scenario's faults are selected by the GM at deploy, with whoever sets up the game (D309, amending D233) |
| 9 | **Draft document** | steps 2 to 8 | `specs/versions/<version>/<domain>-domain.md`, as [shop-domain.md](../v0.4/shop-domain.md) | **approves it**, with the version's master spec |
| 10 | **Build** | the approved draft | `domains/<id>/`, verified (section 3) | none: a build-plan chunk |
| 11 | **Proof in play** | a scenario using the domain | a smoke run with the domain's data, producers and purposes running | none, unless the run shows a design gap |

**Testing in v0.5 (D314).** Step 10's verification and every check of
the build are short tests, under 30 minutes on the least environment
that proves the brick or feature. Step 11's smoke run is v0.5's one
exception, the whole clinic deployed once on two hosts, short and
without aging; the clinic aged and played waits for the major test
before the v1.0 tag ([v0.5](README.md#testing-in-v05-d314)).

A domain fed by an **external dataset** (Bluebox, which the owner sees
as close to a domain, D237) changes step 4 and step 10: the dataset's
schema is the data model's starting point, and its dump replaces
`load.sql`, which brings its size, licence and availability at setup
(O53, O54) into the inputs. Such a domain waits for those questions;
none is planned (D237).

## 3. Definition of done, and the checklist

A domain is **done** when its draft is approved and its folder is built
and passes every item below. It is **proven** once a scenario has run
with it (step 11); v0.4's shop was proven by v0.4's scenario.

Completeness checklist (the build's checks are those v0.4's chunk 5 ran):

- [ ] `domain.yaml`: every key of the template; `id` the folder's name;
      each path names a file that exists; `requires` when it is a part
      (section 4).
- [ ] `schema.sql` follows the data load's contract and runs into the
      `postgres` image; for a part, after its core's.
- [ ] `load.sql` runs after it, with the shift variables at 0 and at a
      non-zero shift; its sizes fit the disk and memory budget and its
      load time is measured.
- [ ] Every role holds exactly the grants the draft lists (diffed).
- [ ] Every column of every table is classed, `internal` included.
- [ ] The business's own rules, when it has any, are written (section 6,
      item 1).
- [ ] The producer fragments parse as `queries.yaml`, `schedule.yaml`
      and `jobs.yaml` fragments, and every statement runs as its role.
- [ ] Every purpose listed exists, or is named in the draft as to be
      drafted.
- [ ] Every variant in `variants/` names parts that exist, sets the
      three scale axes, takes its tags from the vocabulary only, and
      lists purposes that fit; v0.5 builds one variant per domain
      (section 9).
- [ ] `docs/gm.md` has its sections: the business, the data, the roles,
      the classification, the producer, the rules, the traps, loading.
- [ ] The `scenario-format` skill finds nothing missing.

## 4. Composite domains: splitting and composing (D249)

The clinic is one business made of parts that are close to domains of
their own (D196). The rules for splitting it, settled by D249 (closing
O126), to be tried first on `vet-core` and `vet-lab`:

- **A core and parts.** The core holds the keys every part shares (for
  the clinic: owners, animals, sites, staff). A part names its core in
  `domain.yaml` (`requires: [<core>]`) and never redefines the core's
  tables. One level only: a part requires a core, never another part.
- **Flows between parts are purposes.** A lab result reaching the
  owners' portal is a purpose fitting both parts (the release gate of
  v0.4's stress test), not a dependency between them.
- **Keys by id, without foreign keys to the core.** A part refers to a
  core key by its id, with no foreign-key constraint, as separate
  systems do. The same schema then runs in the core's database or in an
  instance of its own (the machinery's dedicated databases). In a
  separate instance the scenario feeds the keys it needs through a
  purpose or a transformer; integrity becomes an invariant, and orphans
  a fault vector.
- **Deterministic keys.** The core's load generates its keys in
  documented ranges, as the shop's `generate_series` loads already do,
  so a part's load can refer to them without reading the core. Kept as
  the default when the clinic's parts were composed (D322); the GM
  adjudicates the initial load's coherence and may sanction a derivation
  step (section 10).
- **Names.** A part's roles and tables carry its prefix (`lab_app`,
  `lab_results`), so parts never clash in one database.
- **Taking a part alone**: only with its core. The core may be taken
  alone.
- **Several sites**: a site is a core entity, so one database can hold
  several sites' data. For the clinic each centre keeps its own record
  and a scenario deploys one; the other sites are rows naming third
  parties, and the exchange with them is round trips, outside the
  domain (D285, D286).

### The clinic, a first cut

Kept now, and revised once `vet-core` is defined (D249); one line per
domain. It is superseded by the split the owner confirmed after
`vet-core`'s sketch (D278, D279), in
[vet-core-domain.md](vet-core-domain.md#the-split-step-3-confirmed-d279);
the first cut stays below as the starting point:

| Domain | What it holds |
|---|---|
| `vet-core` | owners, animals, sites and sections (horse, farm, domestic), staff and specialists, consultations, treatments and prescriptions: the medical record |
| `vet-lab` | samples, analysis orders, instrument batch uploads, results, a vet's validation before release, external labs' orders and results (a round trip, D268, D286) |
| `vet-scheduling` | rooms, machines, specialists and instructors, bookings, the training centre's courses and sessions |
| `vet-housing` | boxes and stalls, stays, care and feeding logs, one display per animal reading its file |
| `vet-machinery` | the machines and their readings and logs, each machine's own database (a time series, see [brick-options-review.md](brick-options-review.md)) |
| `vet-portal` | owners' accounts, their consents, notifications, and what has been released to them; each owner sees only their animals |
| `vet-messaging` | internal mail, messages and machine logs, with their own governance |

Not domains, in this cut: **regulatory reporting** (the medicines and
antimicrobial-use registers, notifiable disease reports) is a set of
purposes fitting `vet-core` and `vet-lab`, the pushed obligation of
v0.4's P5; **inter-clinic exchange** is round trips with third parties
(D285, D286). The training centre sits in `vet-scheduling` unless the owner
wants it on its own.

## 5. How a scenario names its domains

Today `scenario.yaml` carries `domain: <id>`, for provenance only. With
composites, a scenario names a list (D249):

```yaml
domains:
  - id: vet-core
    at: records/clinic        # node/database the schema lands in
  - id: vet-lab
    at: lab/lab               # an instance of its own: keys fed by a purpose
```

The loader checks that each id is a domain and that every domain a part
`requires` is in the list. `domain: <id>` stays accepted as the
one-domain form, so v0.4's scenario keeps its line. A part declaring
`lands_with` must share its core's `at:`, and a part with several
databases gives `at:` as a map (section 10, proposed). The files are still
copied in and adapted at design time; the scenario folder stays
self-sufficient (D23).

## 6. Where the shop fits, and where it would change

The shop fits the procedure as built for its folder layout, the
`domain.yaml` keys, the design-time copy, never bumping, purposes listed
by id, deterministic loads and its GM notes' sections. Four changes,
settled (D249) and built together in one chunk, and a fifth (D263):

1. **The business's own rules.** A regulated business's rules (a
   medicines register kept, lab results released only once validated)
   are the business's, not a scenario's choice. A domain may carry them
   as a default policy (`docs/policy.md` and a `governance:` fragment)
   that the GM copies and adapts. Optional: the shop needs none, and
   could take its rules from v0.4's scenario if wanted.
2. **Classification keys without the database.** The shop keys columns
   `shop.<table>.<column>`; a part lands in whichever database the
   scenario chooses, so a domain would key `<table>.<column>` and the
   copy add the database. The shop's file is rewritten mechanically;
   v0.4's scenario keeps its own copy.
3. **`requires`** in `domain.yaml`, optional: the shop has none.
4. **`domains:`** in `scenario.yaml` (section 5), with `domain:` kept.
5. **Variants and tags** (section 9, D263): a `variants/` folder in a
   domain, the manifest's template, the tag vocabulary, and the shop's
   one variant, its present setup written as a manifest.

Each needs the template, the format skill's checks and
`check_domain_dir` to follow; the fifth joins the other four in that one
chunk (proposed), since it touches the same template, checks and
function. `formats.md` states them once it is built.

## 7. Effort to define one domain

One data point, the shop, and it was cheap: derived from an existing
scenario (`tarnbeck-outdoor-shop`), drafted within one day's spec
session (2026-10-30, [shop-domain.md](../v0.4/shop-domain.md)), built in
one build chunk the same afternoon (two commits), with one correction in
wave 2. It is about 1 100 lines: schema 280, load 280, classification
150, producer fragments 200, GM notes 170.

Rough estimate for a domain designed from a brief, with nothing to
derive it from:

- **owner time**: one or two sessions (the sketch's questions, the
  split, the rules, the purposes);
- **spec work**: one to two sessions for the draft, about twice the
  shop's, since nothing is derived;
- **build**: one chunk per domain of the shop's size, a smaller part
  half of one;
- **for the clinic**: the core about a shop, each of the six parts a
  half to a whole shop; with its purposes and round trips, the clinic
  alone is several shops' worth of work.

The estimate firms up after the first clinic domain is defined. Other
domains come after v0.5 (D292): "i belive v0.5 is already big, so
they'll wait".

## 8. A skill later

The procedure becomes a skill once it has been used on two or three
domains (D249), as `scenario-format` and `scenario-document` are: a
domain-definition skill walking the steps, filling the draft document's
sections and running the checklist. Not created yet.

## 9. Scale, variants and tags (D263)

Settled by the owner on 2026-11-01, closing O114: "size isnt sufficient
to describe whatever it is." One domain name covers several setups of a
business, the owner's examples being the village shop managing its own
storage, the city hypermarket with higher throughput and statistics on
its customers' habits, and the shop with hundreds of warehouses.

- **Scale** replaces "size", on three axes:
  - `population`: how many entities (sites, warehouses, customers,
    products; for the clinic, animals and staff);
  - `history`: how far back the backup goes, so the data's volume;
  - `throughput`: the traffic, in real-world rates, absolute as D32
    makes the intensity ([producer profiles](producer-profiles.md) 3).
- **A variant** is a short manifest in the domain, `variants/<name>.yaml`,
  never a copy of the domain: the parts it takes, its three axes, the
  purposes that fit it, its tags. Its profile, the merge's middle layer
  (D264), is fragment overrides in `variants/<name>/producers/`, holding
  only what they change (D276). Data that genuinely differs between
  setups is a part, under section 4's rules (a `shop-analytics`, a
  `shop-logistics`), so one domain holds every variant's material.
- **A part's own scale** (D301, `vet-lab`'s answer 15): a part writes
  its axes in a manifest of the core variant's name
  (`vet-lab/variants/regional-franchise.yaml`), as the merge's
  provenance (`vet-lab@regional-franchise`, D264) assumes; the loader
  checks that the core's variant names the part.
- **Tags** come from a small fixed vocabulary, in families:
  - maturity: `homebrewed`, `managed`, `industrial`;
  - reach: `local`, `regional`, `national`, `global`;
  - traits: `regulated`, `multi-site`, `24/7`, `seasonal`.

  Topology fragments carry tags too. A variant's tags meet a fragment
  with the same tags: the tag states the intent, the fragment what is
  deployed. The IT maturity itself stays out of the domain (section 1).
- **Large setups show through structure, not volume.** The playground's
  budget and "schemas simple, tables small" hold at every scale. A
  `global` variant differs by robustness and tooling: a few sites or
  warehouses standing for hundreds, several instances and replication,
  more parts and purposes; not many more rows. Its GM notes say what it
  stands for. The owner: "it isn't because we work at world scale that
  we need to spawn hundreds of nodes in our topology, it's more a
  question of robustness and tool used", which fits the fictional cloud
  provider after v1.0 (D205).
- **In v0.5, one variant per domain**: the clinic as briefed, a large
  regional franchise ([vet-core](vet-core-domain.md), question 13), and
  the shop's existing setup. The shop's other variants are other-domain
  work, after v0.5 (D292).

A scenario names the variant beside its core (proposed):

```yaml
domains:
  - id: vet-core
    variant: regional-franchise
    at: records/clinic
  - id: vet-lab
    at: lab/lab
```

The loader then checks that the scenario's parts are the variant's.

## 10. Composing domains (D322)

Ruled on 2026-11-03, when the clinic's four remaining parts came back
with three ways of loading against the core (computed keys, a direct
read of the core's tables, a foreign server). The owner: "although you
are also right, initial load is a major step and will need to be
adjudicated by the gm for coherence across the system." Two things are
settled: **D249's deterministic keys stay the default**, and **the
initial load is a step the GM adjudicates for the whole system**. The
mechanism below is (proposed), for the owner to confirm with the master
spec, and feeds O111, since the domain format is finalised at
consolidation (D291).

### Who decides what

| Decided by | What |
|---|---|
| **The format** (fixed for every domain) | a part names its core (`requires`) and never another part; keys by id without foreign keys; prefixes; a part's load computes the core's keys and never reads the core (D249); the placement constraints a domain may declare; the composition record's fields; the loader's checks |
| **The domain** (declared in its folder) | the core keys it relies on, by the core's documented ranges and functions; any placement constraint (`lands_with`); its databases; its producer fragments and the nodes they target; its scale per variant; the purposes it fits; a derivation step, when it needs one, which only the GM may sanction |
| **The GM** (adjudicated at composition, recorded) | placement (`at:`, within the declared constraints); key feeding when a part sits apart from its core; colliding producer profiles; which cross-part purposes run; the initial load's coherence; capacity |

### What a domain must declare

- **The core keys it relies on.** In its `docs/gm.md`, the ranges and
  functions of the core it uses ("Core keys used"), by the names the
  core's GM notes give them; the core documents every function a part
  needs (the clinic's: requests, consultations, stays as functions of
  their id; the staff layout; species, deaths and infectious alerts by
  id). A part never reads the core at load to find them.
- **Placement constraints.** A part that must share its core's database
  says so in `domain.yaml`, `lands_with: <core>`, and the loader refuses
  a scenario whose `at:` puts it elsewhere. `vet-housing` is the first:
  each display's board read joins housing's units to the core's board
  in one statement.
- **Its databases**, when it has several (below).
- **A derivation step, if it wants one**, with the reason formulas would
  be unreasonably costly; the domain proposes it, the GM sanctions it.

### What the GM adjudicates

1. **Placement.** Each domain's `at:`, within its constraints, against
   the topology.
2. **Key feeding when a part sits apart.** A part in an instance of its
   own reads no core key while running either; the GM chooses the
   purpose or transformer that feeds them (procedure 4), whose orphans
   are then a fault vector.
3. **Colliding producer profiles.** Two parts' fragments on one node
   that conflict stop `gmctl compose`; the GM writes the resolution into
   the scenario's `merge.yaml` (D264).
4. **Which cross-part purposes run.** A purpose fitting several domains
   runs only when all of them are composed; the GM chooses among those
   that may.
5. **The initial load's coherence**, below.
6. **Capacity**, by `gmctl fit` on the composed topology, the parts'
   reservations summed ([clinic-capacity](clinic-capacity.md) for the
   clinic).

### The initial load

When it composes domains, the GM checks and records:

- **the id ranges and functions each part relies on**, against what the
  core documents, in the core's version the scenario copied;
- **combined scale**: the parts' populations and histories against the
  core variant's (a part sized for 40 current stays on a core holding
  60 is incoherent);
- **load order where it matters**: a part's load needs only its core's
  schema in the same database; a derivation step runs after the loads
  it reads;
- **a post-load coherence check**, run once on the loaded system: every
  part's references resolve in its core (no `animal_id`, `stay_id`,
  `request_id` or staff id beyond what the core holds), and the
  histories agree: placements on real stays and every current stay
  placed, monitoring sessions on stays, published documents matching
  signed consultations, released results and ended stays.

**A failure there is a design error, caught before hand-over, not a
fault.** The GM fixes the composition (a range, a function, a scale) and
reloads; it never hands over an incoherence as something to find. Faults
the GM plants against the same relations (the core's mistyped chips, an
orphan a feed leaves) are planted after the check, from the answer key.

**The derivation step.** Where formulas would be unreasonably costly,
the GM may sanction an ordered post-load step deriving a part's history
from its loaded sources: `data/derive.sql`, run as `postgres` after
every load it reads, through a temporary foreign server it drops
afterwards (D307 item 5's mechanism for `office`), its sessions unseen
(D265). It derives content only, never keys the part's own load could
compute. The clinic's one case is `vet-portal`: its accounts, consents,
reminders and sessions go to formulas, but its documents copy the
record field by field (diagnoses, prescriptions, analytes and their
values), and recomputing them would duplicate the core's and the lab's
generation in a third place; so the portal needs the step after all,
for the copies, the documents and what hangs off them
([vet-portal](vet-portal-domain.md#loading)).

**The composition record.** A file beside `merge.yaml` in the scenario
folder (`composition.yaml`, the name proposed), written by the GM and
kept with the scenario, so the composition is reproducible (D23):

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
coherence: {run_at: <setup time>, result: pass}
```

### The format changes the parts propose (for O111)

Proposed format text (D323), with the others O111 lists; built with the
format's changes and stated in `formats.md` once built:

1. **`lands_with: <core>`** in `domain.yaml`, optional: the part's
   schema must land in its core's database; the loader refuses another
   `at:` (`vet-housing`).
2. **A part with several databases.** A scenario's `domains:` entry
   gives `at:` as a map from the part's database names to
   `node/database` (`{pacs: machines/pacs, vitals: machines/vitals,
   biomed: machines/biomed}`); the folder holds `data/<database>/`
   with its `schema.sql` and `load.sql`; classification keys stay
   `<table>.<column>`, unique across the part, the copy adding each
   table's database; the loader creates the databases and revokes
   `CONNECT` from `PUBLIC` (`vet-machinery`, O195).
3. **`data/derive.sql`**, optional, declared in `domain.yaml`
   (`derive: {after: [<domains>]}`), run only when the composition
   record sanctions it.
4. **A traffic source that is no business**, out of reach, standing for
   the public: `producers/partners/<name>/` takes it as a partner's
   would, with no `partners.md` entry (`vet-portal`'s `owners`), or a
   sibling folder `producers/public/<name>/`; the choice at the build.
5. **The composition record** above, beside `merge.yaml`, checked by
   the loader against `scenario.yaml`'s `domains:`.
6. **A check at the build**: a part's `SECURITY DEFINER` functions carry
   a fixed `search_path` (`vet-machinery` T237, `vet-portal`'s
   pre-login functions).
