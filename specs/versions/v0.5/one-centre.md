# v0.5 — one centre per scenario

Status: draft v2, ruled. One centre per scenario is the owner's ruling
(D285, closing O127); what it changes for the clinic's parts, its lab,
its exchanges and its partners' nodes was ruled on 2026-11-02 as
recommended (D293–D295, closing O147). `vet-core` at one centre's scale
is in [vet-core-domain.md](vet-core-domain.md#the-variant-its-scale-and-its-tags).

The owner, on 2026-11-02: "the scenario should be centered only on one
such center (not all 3, nor those beyond)... otherwise i do agree with
the separation, with a caveat: each center has its own lab (other
veterinary clinic in the region pay for its usage)". And: "Visibility
of other centers and franchise stuff will be limited (presented,
documented, and used, but other clinics and franchise system can't be
accessible, we will probably consider them third party for the sake of
the exercise). We don't need the full setup started for other clinic and
franchise, just third party api nodes." Then, on the consequences:
"agreed with all your recommendations; billing: do bill external lab."

## The ruling (D285)

- **Each national centre is independent**, with its own records; the
  exchange pipelines between centres are privileged flows. This
  replaces D278's first answer, one shared record for the three
  national centres.
- **A scenario deploys one centre.** The other two national centres,
  the centres abroad and the franchise's central systems are **third
  parties** (D273–D275): no `player` account, no route on the bastion,
  stub `api` nodes only, none of their own setup started, described in
  `partners.md`, their public APIs callable by the players.
- **Each centre has its own lab**, `vet-lab`, in scope. It also serves
  the region's other veterinary clinics, who pay for its use: the lab
  has outside customers, their orders coming in and their bills going
  out.
- **Redundancy stays inside the centre**: replication, a standby mode
  of the brick (D250): a standby of the core's instance off site, and
  its WAL and base backups in cold storage ([replication.md](replication.md),
  D299).

**Privileged flows** are trusted flows inside the franchise, carrying
more of the record than any outside partner gets (an animal's history,
its owner's contact) under the franchise's agreement, the data policy
stating what may go (D293).

## 1. The parts: the centre's own and the franchise's (D293)

| Part | Whose | In v0.5 |
|---|---|---|
| `vet-core` | the centre's | yes: its own record (D285) |
| `vet-scheduling` | the centre's | yes: its rooms, machines, staff, its training centre |
| `vet-housing` | the centre's | yes: its boxes and stalls, their displays |
| `vet-machinery` | the centre's | yes: its machines and their databases, the lab's analysers among them ([producer profiles](producer-profiles.md) 11) |
| `vet-lab` | the centre's | yes (D285) |
| `vet-portal` | the centre's | yes |
| `vet-messaging` | the franchise's | no: a third party |

**`vet-portal` is the centre's.** It shows what the centre's own record
holds, and the release rules (D280, rule 11) are the centre's to apply;
the owner-scoped access, the clinic's richest governance case, stays in
the game.

**`vet-messaging` is the franchise's**: one mail and messaging service
for all its centres, a third party, an outbound target the centre's
outbox traces, as v0.4's mail provider (D195). Its governance on the
centre's side is what goes out (no owner's data in a message, a trap).
The machine logs it held are `vet-machinery`'s (D279). It is no longer
one of v0.5's domains.

The clinic is the core and five parts: lab, scheduling, housing,
machinery and the portal.

**The franchise's central systems**, third parties: the group's
messaging service; its head office receiving each centre's monthly
activity figures, a pushed flow.

## 2. The lab's partners (D293, D294)

- **The external lab** (D268): the round trip where the centre asks,
  for the tests its own lab cannot run.
- **The region's clinics, the lab's customers**: the round trip where
  the partner asks. A clinic's back end posts an order to the centre's
  lab API (an `api` node in the players' scope, only answering, D270)
  and gets an accession id; the sample arrives with the story's courier;
  the centre's own job posts the result to the clinic's callback, so the
  half that can go wrong is the centre's. The other national centres
  order the same way.
- **The customers are the core's referring practices**, by id
  (procedure 4); `vet-lab` keeps their accounts and price list.
- **Billing them** (D294), inside `vet-lab`: test prices, each outside
  order's charge, a monthly statement per customer clinic, a periodic
  report (D265) with its past statements planted. No invoices to animal
  owners, no payments, no insurers: those stay with the later billing
  part. This narrows D278's eighth answer (no billing in the clinic's
  v0.5 domains) to the lab's outside customers.

## 3. Exchanges with the other centres (D293)

Round trips (D286) with third parties, replacing the two instances and
the transformer job planned before (D268's SQL stubs):

- **Out**: a transfer or examination request (the animal, the reason,
  the record's summary) posted to the other centre's API; the answer
  later, accepted with a date or declined; the report back after the
  examination.
- **In**: the other centres' requests arriving at the centre's exchange
  API, which only answers (D270); the centre's job posts its answer and,
  later, its report.
- The core's `sites` lists the other centres, so transfers and stays
  name them.

## 4. The partners' nodes (D293)

"Just third party api nodes": no partner's own setup runs. Each partner
is an `api` node. What they must do on their own (the external lab's
callbacks, D270; the clinics' and centres' orders) or remember
(correlation ids, cold storage's manifests, D296) lives in **one back
end shared by every partner of a scenario**: one scheduler node driving
their calls from its hidden schedule, and one small database holding
their state, each partner's tables and role its own, closed to the
players by its access rules (D275). For some seven partners (the
external lab, two centres, the centres abroad as one, the head office,
the messaging service, cold storage, the region's clinics as one) that
is about nine nodes instead of twenty.
