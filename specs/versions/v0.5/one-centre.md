# v0.5 — one centre per scenario

Status: draft v1. The ruling is the owner's (D285, closing O127); what
it changes for the clinic's parts, its lab, its exchanges and its
partners' nodes is (proposed) and awaits his ruling (O147). `vet-core`'s
rescale for one centre is in
[vet-core-domain.md](vet-core-domain.md#one-centre-the-rescale-proposed-o147).

The owner, on 2026-11-02: "the scenario should be centered only on one
such center (not all 3, nor those beyond)... otherwise i do agree with
the separation, with a caveat: each center has its own lab (other
veterinary clinic in the region pay for its usage)". And: "Visibility
of other centers and franchise stuff will be limited (presented,
documented, and used, but other clinics and franchise system can't be
accessible, we will probably consider them third party for the sake of
the exercise). We don't need the full setup started for other clinic and
franchise, just third party api nodes."

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
  of the brick (D250).

"Privileged flows" is read here as trusted flows inside the franchise,
carrying more of the record than any outside partner gets (an animal's
history, its owner's contact) under the franchise's agreement, the data
policy stating what may go (proposed reading).

## 1. The parts: the centre's own and the franchise's (proposed)

| Part | Whose | In v0.5 | Why |
|---|---|---|---|
| `vet-core` | the centre's | yes | each centre's own record (D285) |
| `vet-scheduling` | the centre's | yes | its rooms, machines, staff, its training centre |
| `vet-housing` | the centre's | yes | its boxes and stalls, their displays |
| `vet-machinery` | the centre's | yes | its machines and their databases, the lab's analysers among them ([producer profiles](producer-profiles.md) 11) |
| `vet-lab` | the centre's | yes | ruled (D285) |
| `vet-portal` | **recommended: the centre's** | yes | below |
| `vet-messaging` | **recommended: the franchise's** | no: a third party | below |

**`vet-portal`, recommended the centre's.** The portal shows what the
centre's own record holds, and since D285 each centre's record is its
own; the release rules (D280, rule 11) are the centre's to apply. It
keeps in the game the owner-scoped access, the clinic's richest
governance case (the release gate of v0.4's stress test). The other
reading: one franchise portal for every centre, a third party the
centre pushes its releases to; the faults left are in the push (an
unvalidated result sent, a former owner's data in the payload), the
owner-scoped access leaving the game with it. It saves a part.

**`vet-messaging`, recommended the franchise's.** A franchise plausibly
runs one mail and messaging service for all its centres: a third party,
an outbound target the centre's outbox traces, as v0.4's mail provider
(D195). Its governance on the centre's side is what goes out (no
owner's data in a message, a trap). The machine logs it held are
already `vet-machinery`'s (D279). `vet-messaging` then leaves v0.5's
domains. The other reading: the centre's own messaging server, a part
with its own retention and rules, one more part to define for little the
others do not already bring.

With both recommendations the clinic is the core and five parts: lab,
scheduling, housing, machinery and the portal.

**The franchise's central systems**, third parties: the group's
messaging service (as recommended); its head office receiving each
centre's monthly activity figures, a pushed flow; the portal, if the
owner makes it the franchise's.

## 2. The lab's partners (proposed)

- **The external lab stays** (D268), recommended: the round trip where
  the centre asks, for the tests its own lab cannot run, and the
  catalogue's first.
- **The region's clinics, the lab's customers**: the round trip where
  the partner asks. A clinic's back end posts an order to the centre's
  lab API (an `api` node in the players' scope, only answering, D270)
  and gets an accession id; the sample arrives with the story's courier;
  the centre's own job posts the result to the clinic's callback, so the
  half that can go wrong is the centre's. The other national centres
  order the same way.
- **The customers are the core's referring practices**, by id
  (procedure 4); `vet-lab` keeps their accounts and price list.
- **Billing them** conflicts with D278's eighth answer, no billing in
  the clinic's v0.5 domains. Proposed: a narrow exception inside
  `vet-lab`: test prices, each outside order's charge, a monthly
  statement per customer clinic, a periodic report (D265) with its past
  statements planted. No invoices to animal owners, no payments, no
  insurers: those stay with the later billing part. The other reading:
  outside orders unbilled in v0.5, the story saying they pay.

## 3. Exchanges with the other centres (proposed)

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

## 4. What the partners' nodes need (proposed)

"Just third party api nodes": no partner's own setup runs. A partner
that only answers is one `api` node. Some must also act (the external
lab's callbacks, D270; the clinics' and centres' orders) or remember
(correlation ids, cold storage's manifests). Proposed: **one back end
shared by every partner of a scenario**, one scheduler node driving
their calls from its hidden schedule and one small database holding
their state, each partner's tables and role its own, closed to the
players by its access rules (D275). Against
[third-parties.md](third-parties.md) 3's node trio per partner, which
for some seven partners (the external lab, two centres, the centres
abroad as one, the head office, the messaging service, cold storage,
the region's clinics as one) would be about twenty nodes.

## What O147 asks the owner

1. `vet-portal` the centre's (recommended) or the franchise's?
2. `vet-messaging` the franchise's, a third party, and out of v0.5's
   domains (recommended), or the centre's?
3. The external lab kept as the round trip where the centre asks
   (recommended)?
4. The lab's outside customers billed by a monthly statement inside
   `vet-lab`, an exception to D278's "no billing", or left unbilled?
5. `vet-core` rescaled to one centre, about a third
   ([vet-core-domain.md](vet-core-domain.md#one-centre-the-rescale-proposed-o147)),
   or kept as one very large centre?
6. One back end shared by all the partners (section 4)?
