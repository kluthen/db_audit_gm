# v0.4 — data governance: the first cut

Status: draft v2

The customer's own rules for its data (D191), in the game's world:
classes, where each may live, who may read it, where it may flow, the
policy handed to the players, and the checks of what a check can verify.
Not the game's access model ([planes-and-access.md](../../planes-and-access.md)),
not a governance of this project's data (every scenario's data is
synthetic).

## Scope of the first cut

Classification, allowed locations, readers, and flows (D191). Required
settings, audit trails and retention wait for v0.5's regulated domains
(O118, defaulted), with one exception held for v0.5 by the same default
(below, "A settings rule for free").

## Classes (proposed; O115)

| Class | What | In the shop |
|---|---|---|
| `personal` | a direct identifier, or anything stored with one | names, e-mail and postal addresses, country, time zone, consent events, the outboxes' e-mails and payloads |
| `customer-linked` | a customer id with no direct identifier beside it | `orders.customer_id`, `leads` |
| `internal` | everything else | products, order totals, aggregates |

A `payment` class arrives with finance (P4, held) and the special
categories with the regulated domains.

## Where the rules are stated (O115)

Proposed: **the domain classifies, the scenario rules.**

- The domain's `data/classification.yaml`, copied into the scenario,
  classes every column: `shop.customers.email: personal`. A column with
  no entry is `internal`.
- `scenario.yaml` gains a `governance:` section:

```yaml
governance:
  policy: player/data-policy.md          # the player-facing text (O117)
  classes:
    personal:
      locations: [db/shop]               # node/database
      readers: [shop_app, shop_reports, shop_crm, shop_customs, customs_gw]
      outbound:                          # flows leaving the company
        - to: mail-provider              # mail_outbox
          fields: [email, name, order]
        - to: customs-gateway            # customs_outbox
          fields: [consignee_name, consignee_address, country]
    customer-linked:
      locations: [db/shop]
      readers: [shop_app, shop_reports, shop_crm, shop_customs]
    internal:
      locations: any
```

- The loader checks that every class named is defined, every location
  names a `database` node and a database its data file creates, every
  reader is a role a data file creates, and the policy file exists.

**Governance faults** join the Security family rather than making a
family of their own (proposed; O115): `governance-*` ids, `family:
security`.

## The database-versus-instance boundary (D198)

"Distinct database" reads two ways in PostgreSQL: another database in
the same instance, or an instance of its own. What a rule needs decides
it:

| A rule about | Per database or role? | Needs an instance? |
|---|---|---|
| where a class lives (location) | yes | no |
| who may read it (grants) | yes | no |
| where it may flow | yes (foreign servers, mappings) | no |
| statement-log redaction (`log_statement`, `log_min_duration_statement`) | yes (`ALTER DATABASE … SET`) | no |
| audit logging (pgaudit, a preloaded library) | no | yes |
| TLS, the logging collector, `shared_preload_libraries` | no | yes |
| a separate superuser, separate backups, separate failure | no | yes |

**The clinic as a test (D196).** Its classes, borrowed as a test case
only: medical records need an audit trail and retention (instance:
pgaudit); owners' personal data needs separation of readers (database
is enough); internal messaging needs readers limited to the
participants (row-level security: database); machine logs need volume,
their own retention and often their own engine (instance, or beyond
v1.0). So both readings are real, and a policy has to say which one each
rule means.

Settled (D198):

- **The location unit is `node/database`**, so a rule can name either:
  `db/shop` and `db/reporting` are two databases of one instance;
  `db/shop` and `reporting/reporting` two instances. A class's rule may
  add `separation: instance` when the policy demands it, which the check
  verifies by node.
- **v0.4's reporting database is an instance of its own**, a second
  `postgres` node `reporting`: the owner's words ("some data NEED to be
  in distinct database, with distinct settings") point at settings, which
  only an instance separates; v1.0's pipeline already draws `db-src` and
  `db-dwh` as two nodes ([formats.md](../../formats.md), "Expressing the
  v1.0 pipeline"); and it is the arrangement v0.5's regulated domains
  will need. Cost: one more `postgres` node, about 256 MB reserved at
  this data size, and either a second exporter or the reporting instance
  left unmonitored (O125).

## Checks (proposed; O116)

Definition checks, judged on the live state, exit 0 or 1, never 3
(as sealed checks are, formats.md "Script contracts"). They run on a
database node as `gm_check` (`pg_read_all_data`), or on a runner node
through `check-sql`.

| Check | Rule | How |
|---|---|---|
| G1 location | a classed column exists only in its allowed locations | the catalog of every database on every `database` node: tables, views, materialized views and foreign tables; by classified name, and for `personal`, a content probe on text columns of disallowed databases (values shaped like an e-mail address, or equal to a source customer's) so a renamed copy is caught |
| G2 readers | only allowed customer roles may read a classed column | `has_column_privilege` for every customer login role, through membership and `PUBLIC` |
| G3 reach | no path lets a disallowed location read a class | every foreign table, and every user mapping's remote role checked with G2 on the source: a mapping whose role may read `personal` makes `reporting` a reader |
| G4 outbound | what leaves carries only the listed fields | the outboxes' payload keys against `outbound.fields`; judged on rows written since the judged moment, as a purpose invariant is ([checks.md](checks.md)) |

**The game's own roles are outside every rule** (proposed; O116): `dba`
(the players' superuser), `postgres`, `gm_check`, `monitoring`,
`pgbouncer_lookup`. Each would break "who may read"; the policy says
"application and staff accounts", and the checks skip them by name.

**Not checked**: encryption at rest, retention, purposes of processing.
The policy may state them; the checks do not judge them (O116).

### "Fixed" for a governance fault (O119)

Proposed, as the README did: a definition (a classed column where it may
not be, a grant, a mapping) is fixed when the live state complies, so
removing what was copied is part of the fix, not only stopping the flow;
content already sent (outbox payloads) is judged as a purpose is, no new
violation since the judged moment. G1 to G3 are the first kind, G4 the
second.

## The policy the players audit (O117)

Proposed: `player/data-policy.md`, the company's data policy in the
story's voice, in the starter pack beside the story: what the company
holds, the classes in plain words, where each may live, who may read it,
what may leave and to whom. The GM writes it from `governance:`; the
scenario document lists it.

- It may state rules no check verifies (encryption at rest, retention),
  marked by nothing: a real policy does not say which of its rules are
  audited. The answer key lists only checked ones.
- It is correct in v0.4. A policy that is itself wrong or ambiguous is
  starter documentation carrying a fault, which waits for O21.

## Brick changes (O118, defaulted)

None in v0.4, by default: the owner was told this holds unless he
objects, and has not ruled (O118 stays open as defaulted). pgaudit (an image change and a dependency
check) and TLS (certificates as generated secrets) come with v0.5's
regulated domains.

### A settings rule for free

One settings rule needs no brick change: statement logging that writes
personal data into the logs (`log_statement = 'all'`, or
`log_min_duration_statement` catching the outbox inserts with their
parameters), set per database with `ALTER DATABASE … SET`, evidence in
the logs and pgBadger's report the players already have. It is outside
the first cut D191 set; held for v0.5 by the same default (O118), listed
as a candidate fault ([candidate-faults.md](candidate-faults.md)).

## The coupling to purposes

The shop's grants already show it: `shop_reports` reads names and
e-mails. The v0.4 policy allows it (the back office answers customers),
so it is not a finding there; it is in `reporting`, where the policy
keeps personal data out. The faults that copy, import or expose a class
are in [candidate-faults.md](candidate-faults.md); a purpose job moving
data is what makes most of them happen, which is why the first cut
sits in v0.4.
