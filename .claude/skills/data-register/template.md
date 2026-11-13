# Data register templates

Two parts: the true register, `gm/data-register.yaml` (part 1), and the
handout, `player/data-register.md` (part 2), rendered from the same entries
(with a planted register fault's change applied). Replace every
`<placeholder>`; a generated file keeps none. The loader checks part 1
(`tools/gm/model.py`, "the data register").

## Part 1: `gm/data-register.yaml`

```yaml
# gm/data-register.yaml: the true register of <scenario-id> (sealed). Generated
# by the data-register skill from the files generated_from: lists; never edit by
# hand: change an input and regenerate. It describes the system as designed and
# composed, before any fault is planted.
generated_from:                     # every input, its digest: sha256 of the file's bytes
                                    # (composition.yaml's: below)
  scenario.yaml: sha256:<hex>
  composition.yaml: sha256:<hex>    # with domains:; without its top-level coherence: key and the
                                    # lines indented under it (load-data rewrites it; spec D465):
                                    # model.register_digest("composition.yaml", <path>)
  <data/classification.yaml>: sha256:<hex>   # governance.classification
  <player/data-policy.md>: sha256:<hex>      # governance.policy
  <player/partners.md>: sha256:<hex>         # when the bastion maps partners.md
  gm/answer-key.yaml: sha256:<hex>  # with every register_diff written
  catalog/domains/<vet-core>/data/register.yaml: sha256:<hex>   # each composed domain's fragment
  catalog/purposes/<id>/purpose.yaml: sha256:<hex>              # each purposes: entry
controller: <the centre, as the story names it>
contact: <a data-protection contact>
policy: <player/data-policy.md>     # governance.policy
entries:                            # one per fragment activity holding personal or customer-linked data
  - id: <vet-core-owners>           # the fragment's activity id
    department: <The medical record>   # the domain under its business name
    name: <Owners, their animals and who owns them>
    purpose: <one line>             # the fragment's
    people: [<owners>, <keepers>]   # the fragment's
    data:                           # the classification copy's keys, each in exactly one entry
      personal: [<clinic.owners.name>, <clinic.owners.email>]
      customer-linked: [<clinic.ownerships.owner_id>]   # [] when none
    where:                          # each location, then the copies
      - at: <records/clinic>        # node/database
        tables: [<owners>, <ownerships>]   # as the classification keys them, without the database
      - copy: <cold storage (WAL archive, nightly base backup)>
    shared_with:                    # [] when no recipient
      - recipient: <the owners' portal, records/portal>   # inside: business name, location;
                                    # or a third party by its partners.md name
        fields: [<name>, <email>]   # the column or payload names it receives
        flow: <portal>              # optional: the governance: outbound flow's to: label
        processor: true             # optional: processes on the customer's behalf
        outside_eu: true            # optional: a transfer outside the EU
    kept_for:                       # the fragment's retention
      period: <5 years after the owner's last record entry (rule 9, a game value)>
      then: <anonymised>            # erased | anonymised
internal:                           # the closing table: activities holding internal data only
  - id: <vet-core-operations>
    department: <The medical record>
    name: <Running the centre>
    where:
      - at: <records/clinic>
        tables: [<sites>, <sections>]
    kept_for:
      period: <as long as the centre runs>
      then: <erased>
index:                              # each node/database of a where, its entries and lines
  <records/clinic>: [<vet-core-owners>, <vet-core-operations>]
```

## Part 2: `player/data-register.md`

The handout, from the entries as the planted register faults left them.
Departments in the entries' order; one `###` per entry; the internal table;
the index. Lists are comma-separated, the columns in backticks without
their database (`owners.name`), grouped by table where several share one.

```markdown
# Register of processing: <controller>

What <controller> holds, why, where and for how long: its record of
processing activities. The rules each class of data follows are in the
data policy (`data-policy.md`); security measures are stated there, not
here.

- **Controller**: <controller>
- **Data-protection contact**: <contact>

## <department>

### <id>: <name>

- **Purpose**: <purpose>
- **People concerned**: <people, comma-separated; "none" when []>
- **Data held**: personal: `<table>.<column>`, ...; customer-linked: `<table>.<column>`, ...
- **Where**: `<node/database>` (`<table>`, `<table>`); <copy>; ...
- **Shared with**: <recipient, its location in backticks> (<fields>)<, a processor><, outside the EU>; ... ("no one" when [])
- **Kept for**: <period>, then <erased | anonymised>

## Internal data

| Activity | Department | Where | Kept for |
|---|---|---|---|
| <id>: <name> | <department> | `<node/database>` (`<table>`, ...) | <period>, then <then> |

## Index

| Where | Activities |
|---|---|
| `<node/database>` | <id>, <id> |
```
