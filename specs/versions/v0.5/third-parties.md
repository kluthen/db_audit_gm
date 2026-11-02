# v0.5 — third parties: what they are and how they enter a game

Status: draft v4, ruled. A third party's nodes are outside the players'
reach (D273); the owner's nine rulings of 2026-11-01 (D274, D275,
closing O145) are stated below as settled, with his ruling of
2026-11-02 that the clinic's other centres and the franchise's systems
are third parties too (D285), sharing one back end (D293), and the
bastion's route to cold storage's page (D296). The `third_parties:` key's
shape, the loader's checks and the format changes stay (proposed) until
the version's master spec.

The owner, on 2026-11-01, agreeing to keep a third party out of reach:
"agreed, but we need a proper definition of what a third party element
is, covers and how we integrate them into the game, what do we tell the
player and how it is documented."

**Why a v0.5 draft and not a cross-version file.** The definition
touches four standing documents: the vocabulary ([concept.md](../../concept.md)),
who reaches what ([planes-and-access.md](../../planes-and-access.md)),
the scenario's keys ([formats.md](../../formats.md)) and the player
material. Those state what is settled and built. This draft still holds
(proposed) format items and is built in v0.5 with the `api` brick
(D267), so it lives here; once built, each part moves into its standing document:
the term into the vocabulary, the access rule into "Player access to
nodes", the keys into "Scenario".

## 1. What a third party is

A **third party** is a business the customer's company depends on but
does not own or operate: an external lab, a carrier, a customs
authority's gateway, a payment provider, a mail provider, a regulator
receiving reports, and after v1.0 the fictional cloud provider (D205).
The customer has a contract with it and an interface to it, never its
internals.

It is not:

- **The customer's own systems that the players are not asked to fix.**
  A report-only node, a contractor's system inside the customer's
  estate (v0.4's BI agency, Lumen Analytics, whose database is
  report-only by the story, D211), a producer the players may only
  observe: all in the players' scope, read and reported on.
- **A person.** Referring vets, the freelancer of `fernway`'s story, the
  customers themselves are actors of the story, with no system of their
  own in the game.

### What the repository already has

| Element | Where | A third party? | How it fits |
|---|---|---|---|
| The customs gateway | v0.4's `shop-export-declarations` purpose, its `receiver` part; `fixture-campaign`'s `gateway` node, a `report-only` scheduler node writing `customs_acks` into the shop's database as `customs_gw` | yes, in all but name | the first third party with a node; it plays both the authority and the shop's callback endpoint. Stays as built (D273); from v0.5's scenarios on, a purpose's `receiver` part is a declared third party (D274) |
| The carriers | the shop's `carrier_feed.py` builder on the web shop's producer node, resending a share of events | yes, without a node | their traffic arrives through the customer's own feed client; nothing of the carriers runs on its own |
| The payment provider | the shop's `orders.place`, its 3-second `hold` "the payment provider's authorisation before COMMIT" | yes, without a node | a latency inside the customer's transaction |
| The accounting service | the shop's close of day, its 20-second `hold` "posted to the accounting service before COMMIT" | yes, without a node | as the payment provider |
| The mail provider | `mail_outbox`, "handed to the provider"; the governance's outbound flow `to: mail-provider` | yes, without a node | an outbound target; the outbox is the mail's whole trace (D195) |
| The BI agency | v0.4's `reporting` and `bi` nodes | **no** | a contractor operating systems inside the customer's estate, in the players' scope (D211) |
| Vendors in the post-mortems | `post_mortem/`: managed PostgreSQL (MailPace, Clerk's provider upgrade), RDS and Aurora (Figma, RevenueCat), a veterinary practice SaaS (Shepherd) | the providers and SaaS vendors are | models for later third parties; Clerk's is the pattern: the provider's upgrade, the customer's pool settings the fix |
| The clinic's partners | D196: external labs; the other national centres, the centres abroad and the franchise's central systems (D274, D285); the region's clinics using the centre's lab (D285); the authority receiving notifiable diseases and the antimicrobial-use report; cold storage (D288) | yes | the external lab is the first third party with an API (D268); the others stub `api` nodes only (D285; [one-centre.md](one-centre.md), [cold-storage.md](cold-storage.md)) |

## 2. What a third party covers

**Its role in a scenario**: a source of inbound flows (the carriers'
events), a target of outbound ones (the mail provider, the authority),
or a round-trip partner (the customs gateway, the external lab, D268),
either side asking: the clinic asks the external lab, the region's
clinics ask the centre's lab (D285).

**Faults it may carry**: behaviour seen at its interface, placed as
timeline changes of its schedule (D127) or as its stub's standing
behaviour (D214): an outage, slow answers, errors, a lost, late,
duplicated or out-of-order callback, a wrong correlation id, a payload
changed without notice, a maintenance window.

**Faults it may not carry**: a root cause the players are meant to find
inside it. They cannot reach it, so a fault whose answer lies there is
unsolvable.

**Every fix is on the customer's side.** Retries with a backoff, an
idempotency key, a timeout, a reconciliation, monitoring the partner, a
queue that survives its outage. No fault's fix requires the third party
to change (D274). Telling the partner, with the evidence, is a
finding the answer key may credit, never a fix.

**The trust line.** Its stubs are in the repository like every
scenario's files; reading them there is the trust D13 accepts. In a
classroom swarm, a student owning the host it runs on reaches its
containers, as for any node (planes-and-access, "Trust").

**The GM's checks** run in the GM's plane and may read the third party's
side as evidence (callbacks sent against callbacks received); what they
judge is the customer's side.

## 3. How a third party is built into the game

**Bricks.** Whichever the role needs, and no more: none of the
partner's own setup runs, only its interface (D285, the owner: "just
third party api nodes"). An `api` node for an interface (D267), a
scheduler node as its back end firing its callbacks from its hidden
schedule (D270), a `postgres` node when it keeps state. The external
lab: an `api` node answering the clinic's orders, a scheduler node
posting results back, a database holding the orders. Every partner of
a scenario shares one back end, one scheduler node and one small
database, each partner's tables and role its own (D293;
[one-centre.md](one-centre.md) 4): a partner is otherwise one `api`
node.

**Out of reach (D273).** A third party's nodes have no `player`
account, are not on the bastion's routes and are not listed among the
starter pack's nodes. **One stated exception** (D296): the bastion
routes the players to cold storage's read-only page and read endpoint
(`GET /`, `GET /manifests`), as a provider's console the customer logs
into; never to its upload endpoint or to any other partner
([cold-storage.md](cold-storage.md) 3). The per-node option is the existing `no-access`
write policy made real, with no new key (D274), built with the `api`
brick. The format already offers it (`WRITE_POLICIES` in `tools/gm/model.py`, the
template's `write_policy`), but every brick reads it as `report-only`
today (for instance `bricks/prometheus/docs/gm.md`, "Write policies"):
the `player` account and its `sudo` wrappers are still created. Made
real, `no-access` creates neither.

**One network, the back end closed by its own rules (D275).** v0.5
keeps the one network `gmctl` renders (`tools/gm/localimpl.py`; D83,
D106). Without a `player` account nothing logs in, and a third party's
back end refuses the players by its own access rules: its database's
`pg_hba.conf` admits only the third party's own nodes, and its other
services accept only their own callers. As with a real lab, its API is
reachable from outside, its database is not. Separate networks for
third parties stay with O12.

How the database admits only its own nodes is the build's to verify. On
one Swarm network the tasks' addresses change, and a host name in
`pg_hba.conf` relies on reverse lookups that Swarm does not promise; the
proposed form: lines for the third party's database and roles only, the
roles' passwords secrets mounted on its own nodes only, every other
line for that database a `reject`.

**Its interface stays callable.** A player may call the lab's API from a
node, as the customer's staff could, with the credentials the starter
pack gives (D274).

**Placement.** Like any node: `fit` counts it in the host's budget; with
several hosts the GM may place third parties on the host the players do
not own, a preference, not a check.

**Declaring it** (proposed), in `scenario.yaml`:

```yaml
third_parties:
  - id: northfield-lab
    name: Northfield Veterinary Laboratories   # its in-world name
    stands_for: a regional reference laboratory
    role: round-trip                           # inbound | outbound | round-trip
    nodes: [lab-api, lab-backend, lab-db]      # none for a party without a node
    player_doc: player/partners.md#northfield-veterinary-laboratories
```

**What the loader checks** (proposed): each node listed exists and has
`write_policy: no-access` on a brick that implements it; no third-party
node is in the bastion's `web_routes`, but for a cold storage stub's
read-only paths (D296), or among the starter pack's nodes;
no fault instance's expected `fix` resolution names a third-party node;
a third-party `postgres` node's seed `pg_hba.conf` admits no role but
its own on its database. `fit` needs nothing new.

## 4. What the players are told, and how it is documented

**Player side.** Each third party is described as a real company knows
its partner, in the starter pack, on the bastion's web page beside the
README, story, issues and data policy (D221):

- its name and what it does for the business;
- the contract: what it promises (a result within so many hours, an
  acknowledgement within a minute, its support hours);
- the interface: its endpoints and their formats, the authentication,
  the customer's callback URL, the retries it makes or expects;
- a support contact, in-world, never answering during the game: the GM
  plays no partner, as it plays no customer before v1.0 is past (D48);
  players write in their report the message they would send, and the
  answer key may credit it (D274).

The description is a fifth optional starter-pack file, `partners.md`,
shown on the bastion's page as `data-policy.md` is (D221), a small
`bastion` bump (D274). No status page in v0.5: one comes with v0.6's
bastion work, showing only the incidents the partner admits
([v0.6](../v0.6/README.md)).

Never its internals: no node names to audit, no schedule, no code.

**GM side.** The scenario's `third_parties:` entries, its nodes'
schedules (hidden as every `schedule.yaml` is, D130), the faults it
carries and what it stands in for, in the scenario document's own
section (the `scenario-document` skill).

**Format changes this needs** (proposed):

- `formats.md`, "Scenario": the `third_parties:` key; `no-access` made
  real in "Player access to nodes" and in the bricks' `write_policies`;
  `partners.md`, the fifth optional starter-pack file (D274).
- The `scenario-format` skill: the template's `third_parties:` block,
  the checks above, a partners file when the scenario has third parties
  players are meant to know.
- The `scenario-document` skill: a "Third parties" section in its
  template.
- `bastion`: the partners file on its page, as `data-policy.md` (D221);
  a version bump.
- Each brick that may be a third party's (`api`, `scheduler`,
  `postgres`): `no-access` in its `write_policies`, its entrypoint
  creating no `player` account; a bump each.

## The owner's rulings (D274, D275)

On 2026-11-01, "agreed with your recomendations", answering the lead's
views:

1. `no-access` made real, no new key (D274).
2. One network in v0.5; the back end closed by its own access rules;
   separate networks with O12 (D275, against the draft's recommendation
   of a network of its own).
3. Players may call a third party's public interface with the
   documented credentials (D274).
4. No status page in v0.5; one with v0.6's bastion, showing only what
   the partner admits (D274).
5. `partners.md`, a fifth optional starter-pack file, on the bastion's
   page (D274).
6. An in-world support contact that never answers during the game; the
   message players would send may be credited (D274).
7. v0.4's customs gateway stays as built; from v0.5's scenarios on, a
   purpose's `receiver` part is a declared third party (D274).
8. The franchise's centres abroad are third parties, franchisees with
   systems of their own, reached by exchange (D274).
9. No fault's fix ever requires a third party to change (D274).

On 2026-11-02 (D285): a scenario deploys one centre of the clinic; the
other national centres and the franchise's central systems are third
parties as well, stub `api` nodes only. Then (D293, D296): one back end
shared by every partner; the bastion's route to cold storage's
read-only page, the one exception to D273.
