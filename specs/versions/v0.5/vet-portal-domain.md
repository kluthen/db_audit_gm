# v0.5 — `vet-portal`, the owners' portal

Status: draft v3, ruled, its stale passages corrected to the master
spec at approval (R16, D339). **Approved by the owner on 2026-11-03 with
v0.5's [master spec](master-spec.md)** (procedure step 9, D339), which
wins where the two disagree.
Steps 1 to 9 of the [procedure](domain-procedure.md) run in one pass on the
owner's instruction of 2026-11-03 ("start an agent for each part, and
let them come back with problems once they're done"); the same day the
owner accepted the recommendations as a whole (D320, closing
O204–O215), marked "(ruled, D320)" below, with one change: the load
computes the core's and the lab's keys by their documented functions
(D249 kept), and only the copied content (the documents, their
versions, views and notices, the copies of animals and ownerships)
comes from a GM-sanctioned derivation step after the sources' loads
(D322; its details confirmed, D326). No appointment reminders in v0.5, the
vaccination reminders only, with consent (D321). T270 replaces s5 in
the test selection (D325). Step 8 has no owner checkpoint (D309). The
changes this part asked of the shared pages are applied ([Changes
needed in shared pages](#changes-needed-in-shared-pages)). Brought to as
built after chunk 16 (2026-11-04, D423): the keeper's clause, the
functions, status codes, grants, id ranges and figures the build needed,
the GM notes (`domains/vet-portal/docs/gm.md`) holding the detail; the
desk's refusal of a closed account's owner kept with a false-alarm line
(D426) and T274's witness at the rate as built (D427), as the driver
ruled.

`vet-portal` is the owners' portal of the centre a scenario deploys
(D285), the centre's own (D293), a **part**: it requires `vet-core`
(procedure 4), refers to the core's and the lab's keys by id with no
foreign key, and prefixes its tables and roles (`portal_`). By the
confirmed split (D279) it holds the owners' accounts, one per core
owner; their consents; their notifications; and the record of what was
released to whom; each owner sees only their own animals.
[vet-lab-domain.md](vet-lab-domain.md) is the model for this page.

## The draft at a glance (step 9)

Where each item of the part's folder, `domains/vet-portal/`, is stated
on this page (procedure 1, 3 and 4; the format is finalised in the
master spec, O111):

| In the folder | Stated in |
|---|---|
| `domain.yaml`: `id` `vet-portal`, `requires: [vet-core]`, its tables and roles prefixed `portal_`, the purposes that fit | [What the portal holds](#what-the-portal-holds); [Purposes](#purposes-that-fit-step-7) |
| `variants/regional-franchise.yaml`: the part's own axes in a manifest of the core variant's name (D301, vet-lab answer 15) | [The variant](#the-variant-its-scale-and-its-tags) |
| `data/schema.sql`: tables, keys, states, the row-level security policies, the auth functions, roles and grants, in a database `portal` on `records` (ruled, D320) | [The data model](#the-data-model-step-4) |
| `data/load.sql`: the accounts, consents, reminders, sessions and tokens by documented functions, the core's and the lab's keys computed (D249, D322); `data/derive.sql`: the copies, the documents and what hangs off them, derived after the sources' loads by a step the GM sanctions (D322, D326) | [Key ranges](#deterministic-key-ranges-d249-d266), [The history before T0](#the-history-before-t0), [Loading](#loading) |
| `data/classification.yaml`: every column classed | [Classification](#classification) |
| `docs/policy.md` and a `governance:` fragment | [The rules](#the-rules-ruled-d320) |
| `producers/`: the portal's API (`producers/api/portal-api/`), the owners' traffic (`producers/partners/owners/`, ruled, D320; the folder for a traffic source that is no business, `partners/` or a sibling `public/`, chosen at the build, D323, D326), the desk's consent stream on `pms` | [The producer profiles](#the-producer-profiles-step-6) |
| `docs/gm.md`: the business, the data, the roles, the classification, the producer, the rules, the traps, loading | this page's sections of the same names; [Loading](#loading) |

## Settled before this page

Built on, not reopened:

- **The portal is the centre's** (D293): it shows what the centre's own
  record holds, the release rules (D280, rule 11) are the centre's to
  apply, and the owner-scoped access, "the clinic's richest governance
  case", stays in the game ([one-centre.md](one-centre.md) 1).
- **Messaging is the franchise's**, a third party (D293): one mail and
  messaging service for every centre, an outbound target the centre's
  outbox traces, as v0.4's mail provider (D195); its governance on the
  centre's side is what goes out ("no owner's data in a message, a
  trap"). Its stub is one hostname on the partners' one `api` node
  (D308). The reminders and the outbox are the portal's, the core
  having no outbox table (D304, vet-core point 6).
- **What the portal may release** (D280, core rule 11): an owner sees
  their current animals and their own ownership's records; results once
  validated, consultations once signed; never a former owner; no staff
  contact beyond the clinic's. The lab adds: a result leaves the lab, to
  the portal or a practice, only once released by a clinical
  pathologist (D302, lab rule 1); amendments are new rows (lab rule 3).
- **The release to the portal** is a purpose fitting `vet-lab`,
  `vet-core` and `vet-portal`, drafted with this part (D304, D306
  point 1), the release gate of v0.4's stress test ("no trace row
  before its source's `validated_at`",
  [v0.4 purpose catalogue](../v0.4/purpose-catalogue.md#stress-test-the-clinics-strict-reporting)).
- **The electronic referral report** comes later (D278 answer 5, D304).
- **Precedents for consent and governance**: v0.4's data policy (D191:
  classes, locations, readers, outbound flows; checks G1 to G4,
  [v0.4 governance](../v0.4/governance.md)); the shop's consent model,
  `consent_events` with the latest event the truth and a flag beside it
  as a fault vector, P3's consent at sending time (M2) and transactional
  mail exempt ([v0.4 master spec](../v0.4/master-spec.md) 9.3, 10.3).
- **The core** is the system of record for owners and animals (D266);
  its owners carry name, e-mail, phone, address; `ownerships` carry the
  dated history with an optional keeper (D278 answer 4); the lookup API
  answers names, never contacts. `clinic` holds `vet-core` only; a part
  lands where `domains:` `at:` places it (D279).
- **`api` nodes only answer** (D270); players edit their database side
  only, queries, transactional work and session settings (D271); a
  third party's back end ticks its own routes (D303); the partners
  share one `api` node, one scheduler and one database (D293, D308).
- **TLS and pgaudit** always available in `postgres`, turned on by the
  seed (D250, D261); the portal reached from outside was among TLS's
  reasons ([brick-options-review.md](brick-options-review.md)).
- **Budget**: the clinic is CPU-bound at 75 % of armenelos plus the VPS
  ([master spec](master-spec.md) 14; first estimated at 78 % to 96 %), and the VPS has no room for another `postgres` node
  ([clinic-capacity.md](clinic-capacity.md)); one variant (D263), one
  centre (D285); short tests (D314).

## The brief (step 1, ruled, D320)

The owner's words, from the clinic's brief (D196): "customers have a
dedicated portal to access their animals informations." The split
(D279): "owners' accounts, one per core owner; consents; notifications;
what was released to whom"; "each owner sees only their animals".

Proposed brief, for the owner to write or accept (O204):

> The centre's owners' portal: every owner of the centre's record has
> an account, through which they see the animals they own now and what
> the centre has released about them: signed consultations, validated
> lab results, discharge summaries. The portal tells them when
> something new is there, and reminds them of their animals'
> vaccinations if they agreed to it; its messages leave through the
> franchise's messaging service. It keeps every consent an owner gives
> or withdraws, and a record of what was released, to whom it was
> notified and who opened it. It is information only: no booking, no
> payment, no messages to the vets.

## The business sketch (step 2)

### The business

A hospital's client portal of the kind veterinary practice software
vendors sell beside their practice software: a web application on the
internet, its own small database, fed from the practice software, read
by owners from home in the evening. For the centre it is the owners'
window on the record and the clinic's channel to them, and the place
where the GDPR's promises to owners are kept or broken: what each owner
may see, what they agreed to receive, what was sent to them, what they
opened. Being reachable from outside, it is also the centre's most
exposed system holding owners' data.

### Actors

| Actor | Who | With the portal |
|---|---|---|
| Owner | a pet owner, a horse owner or stable, a farmer (a holding's keeper): a core owner | activates their account, logs in, reads their animals' documents, grants and withdraws consents, closes their account |
| Keeper | a stable, a livery yard, a holding keeping someone else's animal: a core owner with a `keeper` ownership | sees an animal they keep only with its owner's consent (ruled, D320) |
| Receptionist | core `staff`, `kind` `reception` | records an owner's consent at the desk, through the practice software (`pms`) |
| Vet, clinical pathologist | core `staff` | sign the consultations, release the results: the gates the portal waits for; never use the portal |
| The franchise's messaging service | a third party (D293) | delivers the portal's e-mails and text messages |
| The centre's integration engine | `interfaces`, the purposes' runner (D306) | copies the owners and animals in, publishes what passed its gate, queues and sends the messages |

### Activities

| Activity | What it records | Held by |
|---|---|---|
| Registering an owner and an animal | identity, contacts, ownership | core |
| Inviting the owner | the account, `invited`, its one-time activation link sent | `vet-portal` (ruled, D320) |
| Activating, logging in, logging out | the password's hash, sessions, failed attempts | `vet-portal` |
| Publishing what passed its gate | a document per signed consultation, released centre result, discharge; its version on an amendment | `vet-portal`, by a purpose (step 7) |
| Notifying the owner | one notice per published document, by the account's channel | `vet-portal` (ruled, D320) |
| Reading | each document opened: who, when | `vet-portal` |
| Granting and withdrawing consents | every event: purpose, granted or withdrawn, when, where | `vet-portal` (ruled, D320) |
| Vaccination reminders | one a year per domestic animal and horse, 14 days ahead, with consent | `vet-portal` (moved from the core, D304) |
| Closing an account | its personal columns erased, its sessions ended; the record untouched | `vet-portal` |
| Changing contacts | name, e-mail, phone | core, at the desk; copied to the portal |

Not in the portal (ruled, D320, D321): booking or appointment reminders
(`vet-scheduling`'s bookings stay inside the centre in v0.5, the owner
confirming no appointment reminders at all, D321); payments
and invoices (billing is out, D278 answer 8); messages to the vets;
imaging studies (`vet-machinery`'s, later, O208); treatment consent
forms (O205).

### The variant, its scale and its tags

The portal takes the clinic's one variant, `regional-franchise` (D263),
and adds no tag. Its own axes go in
`vet-portal/variants/regional-franchise.yaml` (D301 answer 15). The
figures follow `vet-core` at one centre's scale (D295).

**Population**, at load:

| What | How many |
|---|---|
| Accounts | 9 999, one per core owner but the clinic itself (owners 2 to 10 000): about 6 700 active, 3 000 invited and never activated, 300 closed (6 682, 3 018, 299 as built, D423) |
| Owners with the reminders' consent | about 5 100 (5 087) |
| Keepers granted access to a horse | about 230 grants in force (232) |
| Animals, ownerships, herds copied from the core | 17 000, about 18 600, 200 |

**History**: one year, growing as the core grew (D279), each daily
volume ramping from about 60 % of today's rate to today's:

| What | Over the year |
|---|---|
| Documents published | about 39 000 as built (D423): 23 900 consultations, 12 700 centre results (the core's analysis requests) with 470 amended versions, 2 400 discharges; fewer than the 41 600 first counted, the core's agenda (D408) leaving about 4 % of the scheduled consultations without a row |
| Documents opened | about 65 000 |
| Messages | about 38 200: 25 700 document notices, 6 700 reminders, 4 000 invitations, 1 600 password resets, 130 closures |
| Consent events | about 7 300 |
| Sessions kept | the last 30 days', about 4 500 |

**Throughput**, in real-world rates during the game:

| What | Rate |
|---|---|
| Documents published | about 140 a day: 85 consultations, 45 results, 8 discharges, 2 amendments |
| Visits (logins) | about 150 a day, most in the evening, every day of the week |
| Documents opened | about 240 a day |
| Messages | about 120 a day: 75 notices, 25 reminders, 13 invitations, 5 resets |
| Activations | about 9 a day, 70 % of invitations within three days |
| Consent events | about 11 a day |
| Failed logins | about 8 a day; a lock-out every second day |
| Account closures | one every four days |

About **0.21 million rows** at load and **720 a day** live
([reference sizes](#reference-sizes)), close to the core's 0.28 million
and 760 (570 main rows), far under the shop's 1.3 million.

**Against a real portal.** No source was read for this draft: two
thirds of owners activated and one visit a day per 40 active accounts,
most of them after a notice, are game values, for the owner to judge
(O204).

**A few stand for many** (D263): one portal for a hospital's thousands
of clients; one messaging stub for e-mail and SMS.

### Cadences

| Cadence | What | Ages in real time? |
|---|---|---|
| Around the clock, peaking 18:00–22:00 every day | owners' visits; documents published as the gates pass (signing in the morning, results at the pathologist's rounds and at once for urgent ones) | yes |
| Every few minutes | the copies from the core, the publishing, the notices (the purposes, step 7) | yes |
| Daily, 09:00 | the day's vaccination reminders queued, sent from 09:00 to 20:00 | yes |
| Daily, 03:30 | sessions older than 30 days purged | yes |
| Yearly | nothing: a year of history holds nothing past the retention periods | no job |

No monthly or yearly cadence: nothing for O22 to flag.

### Regulations

What a client portal plausibly answers to, at the level a game needs.
Named from the texts as known, not re-read for this draft; the owner
checks they are realistic at step 5 (O214).

| Rule | Source | What the portal must hold |
|---|---|---|
| An owner's data, and an animal's record linked to them, is personal data (core rule 10) | GDPR Art 4(1); *Nowak* | the classification |
| Only the data needed for the purpose | GDPR Art 5(1)(c), Art 25 (by design) | the portal's copies without addresses or natural identifiers; documents without free text |
| A controller demonstrates consent; withdrawing is as easy as giving | GDPR Art 7(1), 7(3) | every consent event kept; a withdrawal link in each reminder |
| E-mail and text messages promoting a service need prior consent, or the existing-customer exception with an opt-out in each message | ePrivacy Directive 2002/58/EC, Art 13 | the reminders on consent (a game value, O214) |
| The owner's access, erasure and objection | GDPR Arts 15, 17, 21; erasure bounded by a legal obligation, Art 17(3)(b) | the portal is the access; closing an account erases the portal's personal columns, never the core's medicine records (core rule 10) |
| A processor acts on the controller's instructions under a contract | GDPR Art 28 | the franchise's messaging service, a processor for the centre |
| Security of processing | GDPR Art 32 | hashed passwords and session tokens, TLS, no secrets in logs |
| Results only once validated, consultations once signed | the clinic's rules (D280 rule 11, D302 rule 1) | the release gate |

## What the portal holds

Within the procedure's section 4: every table prefixed `portal_`, every
core and lab key by id with no foreign key, in a database `portal` on
the core's instance `records`, beside `clinic` and `office` (ruled,
D320):

- **Accounts and sessions**: one account per core owner, its login and
  password's hash, its status, its channel; sessions by a token's hash.
- **Copies of the core**: the animals (name, species, status, death),
  the ownerships with their dates and keepers, the herds and their
  keepers; no address, no natural identifier. The core stays the
  system of record (D266); the portal's copy is two places for one fact,
  a fault vector by design.
- **Documents**: what passed its gate, each with the record's own time,
  the gate's time, its publication and its version.
- **Consents**: every grant and withdrawal, the shop's model.
- **Views**: each document opened, by whom and when: with the notices,
  the record of what was released to whom.
- **The outbox**: every message handed, or to be handed, to the
  franchise's messaging service.

## Where the portal presses on the core and the lab

| The portal needs | From |
|---|---|
| each owner as a stable key, with name, e-mail and phone | `owners` (D278), read by the release purpose's role with a column grant (no address) |
| who owns and keeps each animal now, and since when | `ownerships` with `from_at`, `until_at`, `role` (D278) |
| the animal's name, species, status and death | `animals` |
| a herd's keeper | `herds` |
| a consultation's signature, kind, section, vet, diagnoses, prescriptions with withdrawal ends | `consultations.signed_at`, `diagnoses`, `diagnosis_codes`, `prescriptions`, `prescription_lines`, `medicines`, `staff` (names only) |
| a stay's discharge | `stays.discharged_at`, outcome |
| a centre result's release, its values, flags, intervals, amendments | `lab_order_tests` (released by and at), `lab_results` (`supersedes_id`), `lab_tests`, `lab_analytes`, `lab_reference_intervals`; `lab_orders` of account 1 only, by `animal_id` |
| a vaccination's due day | none: a function of the animal's id ([key ranges](#deterministic-key-ranges-d249-d266)), the core recording no vaccinations as such |

Nothing changes in the core's or the lab's tables. Two purpose roles
are new, one in `clinic` and one in `lab`
([roles](#the-roles-the-purposes-add)); `pms` gains one HTTP stream
([producers](#the-applications-and-their-nodes-d276)).

## The owner's answers (step 2, ruled, D320)

The questions the sketch leaves open, each answered as this draft
proposed (D320).

1. **The brief** (O204): as written above; information only, no
   booking, payments or messages to the vets.
2. **What "consents" covers** (O205). Answer: the owner's
   communication and data-use consents, in the shop's event model:
   `reminders` (vaccination reminders by e-mail or text message) and
   `keeper-access` (a named keeper's access to one animal). Consent to
   treatment (anaesthesia, surgery, euthanasia, a cost estimate) is a
   signed clinical form, the core's when it comes, later: the core's
   procedures would need it before the act, which a separate portal
   database cannot give the practice software.
3. **Keepers** (O206). Answer: a keeper sees an animal only
   while they keep it (the core's current `keeper` ownership) and while
   its current owner's latest `keeper-access` event for that keeper and
   animal is a grant; they then see what the owner sees. A livery yard
   following its horses is common practice in equine work, and the
   clause is the owner scope's richest case. Without it, a keeper sees
   only animals they own.
4. **Accounts** (O207). Answer: one per core owner but the
   clinic itself, created `invited` by the release purpose within
   minutes of the owner's registration, the invitation a one-time link
   valid 14 days; activation sets the password and offers the
   reminders' consent; an expired invitation is renewed by a password
   reset. Contacts are the core's: an owner changes them at the desk
   and the copy follows; the portal changes no contact. An owner may
   close the account: its personal columns erased, its sessions ended,
   the consent events kept as proof, never reopened.
5. **What the portal shows** (O208). Answer: of each animal
   the owner owns now, the documents whose record falls within their
   ownership: signed consultations (date, kind, section, the vet's
   name, the diagnoses' labels, the prescriptions with their doses,
   days and withdrawal ends, which a farmer needs), the centre's
   released results (each test's analytes, values, flags, intervals,
   the lab that performed it, an amendment shown as such), discharge
   summaries (dates, outcome). Never the findings' or the pathologist's
   free text, alerts, natural identifiers, imaging studies (later, with
   `vet-machinery`), or the region's practices' patients (lab answer 4).
   A herd's documents go to its keeper.
6. **Notifications** (O209). Answer: one notice per published
   document, by the account's channel (`email`, `sms` or `none`,
   default `email`), transactional and without consent, as the shop's
   `order-shipped` mail; vaccination reminders 14 days before each
   domestic animal's and horse's yearly due day, with the reminders'
   consent at sending time, sent 08:00 to 20:00; account messages
   (invitation, password reset, closure). The messaging service accepts
   each message at once with an id, idempotent on the message's key; no
   delivery receipts or bounces in v0.5 (a round trip with them would
   raise D195's question again).
7. **Where the database lands** (O210). Answer: a database
   `portal` on `records` (`at: records/portal`), beside `clinic` and
   `office`: no new `postgres` node, separation by database, roles,
   `pg_hba.conf` and its own settings (`ALTER DATABASE`). A node of its
   own, as a portal facing the internet often has, costs 0.5 CPU, 512M
   and 2.25G on armenelos with an exporter, which the tally cannot
   easily afford. It rides the standby and the archive.
8. **The owners' traffic** (O211). Answer: out of the
   players' reach, as the outside world is, on the partners' shared
   `api` node under a hostname `owners` and their back end (D303's
   ticked routes, D308): no new node. The owners are no third party
   (they are people, [third-parties.md](third-parties.md) 1), so
   `owners` is not in `partners.md`; it stands for the owners' browsers.
   A scheduler node of its own, out of reach, would cost 0.1 CPU and
   64M.
9. **Scale and hours** (O204, with the brief): the figures in "The
   variant" and "Cadences": two thirds of owners activated, about 150
   visits a day, evenings and weekends included.

## The data model (step 4)

The `portal` database, on `records`, holds `vet-portal` only, in the
core's manner: tables in `public`, prefixed `portal_` (procedure 4),
integer keys `GENERATED BY DEFAULT AS IDENTITY`, explicit ids at load,
each sequence set after its range; core and lab keys as plain integers
with no foreign key (`owner_id`, `animal_id`, `herd_id`, `keeper_id`);
the purposes' tables in a schema `ops` (D307). `pgcrypto` is created in
`portal` for the passwords' hashes (`crypt`, `gen_salt('bf')`).

### Entities

**Accounts and sessions**

| Table | Key, main columns |
|---|---|
| `portal_settings` | one row: the customer's zone and offset (as the core's `business_settings`), the session's idle limit (30 minutes) and its longest life (12 hours), the lock-out (5 failures, 30 minutes), the invitation's life (14 days), the reminders' lead (14 days) and hours (08:00–20:00) |
| `portal_accounts` | `id`; `owner_id` (the core's, unique), `kind`, `display_name`, `email` (the login and the address), `phone`, `status` (`invited`, `active`, `closed`), invited at, `invite_hash` and its expiry (`invite_expires_at`: the one link slot, an invitation's or a reset's, 14 days either; D423), activated at, `password_hash`, `failed_logins`, `locked_until`, last login at, `notify_by` (`email`, `sms`, `none`), `reminders` (the flag beside the events, the shop's `marketing_opt_in`), closed at, synced at |
| `portal_sessions` | `id`; account, `token_hash` (SHA-256 of the token, unique), created at, last seen at, expires at, ended at, `ended_by` (`logout`, `idle`, `expiry`, `closure`) |

**Copies of the core** (written by `vet-portal-release` only)

| Table | Key, main columns |
|---|---|
| `portal_animals` | `animal_id`; name, species, sex, born on, `herd_id`, status (`alive`, `died`), died at, synced at |
| `portal_ownerships` | (`animal_id`, `owner_id`, `role`, `from_at`); `until_at`, open while current; `role` `owner` or `keeper`; synced at |
| `portal_herds` | `herd_id`; `keeper_owner_id`, synced at (no holding number) |

**Releases**

| Table | Key, main columns |
|---|---|
| `portal_documents` | `id`; `animal_id` or `herd_id`, `kind` (`consultation`, `result`, `discharge`), `source_ref` (`C-<consultation id>`, `T-<lab order test id>`, `S-<stay id>`), `version` (unique with `source_ref`), `record_at` (the consultation's start, the sample's collection, the admission), `gated_at` (signed at, released at, discharged at), published at, `title`, `vet_name` (the signing vet or releasing pathologist), `body` (jsonb: diagnoses, prescriptions, or analytes with values, flags and intervals, the performing lab), `supersedes_id`, superseded at |
| `portal_views` | `id`; account, document, at, `action` (`open`, `download`) |

**Consents and messages**

| Table | Key, main columns |
|---|---|
| `portal_consent_events` | `id`; `owner_id`, `purpose` (`reminders`, `keeper-access`), `animal_id` and `keeper_id` (for `keeper-access`), `granted`, at, `source` (`activation`, `portal`, `message-link`, `desk`) |
| `portal_outbox` | `id`; `message_key` (a UUID, unique, kept on a retry), account, `owner_id`, `template` (`invitation`, `password-reset`, `closure`, `document-notice`, `reminder`), `channel`, `address`, `document_id` (a notice), `animal_id` and `due_on` (a reminder), `payload` (jsonb), queued at, sent at, attempts, last status, `provider_id` (the messaging service's), failed at |

Two uniques by design, whose absence is a trap: one `document-notice`
per (`document_id`, `account_id`), one `reminder` per (`animal_id`,
`due_on`).

### Lifecycle states

| Entity | States |
|---|---|
| Account | `invited` → `active` (activation) → `closed` (the owner's request); `invited` → `closed`; locked while `locked_until` is ahead, a time, not a state; an invitation past its expiry renewed by a reset |
| Session | open → ended (`logout`, `idle` after 30 minutes, `expiry` after 12 hours, `closure`) |
| Document | published → superseded (a newer version of its `source_ref`) |
| Message | queued → sent (accepted with a `provider_id`) or failed (six attempts, an incident) |
| Consent | per owner and purpose (and animal and keeper for `keeper-access`), the latest event: granted or withdrawn |

### Deterministic key ranges (D249, D266)

Each sequence resumes after its range (D276).

| Key | Range | Layout |
|---|---|---|
| `portal_accounts.id` | 2–10 000, the sequence set at 20 000 | the account of owner `o` is `o`: the accounts migrated from the old portal kept their owner's number, and accounts created since take 20 001 on. A query joining an account's id to an owner's id is right for every loaded account and wrong for every new one (a trap, T261) |
| Account status at load | by a hash of the id | as built (D423) 6 682 active, 3 018 invited (193 open links: the last 14 days' invitations and the older invited accounts' renewals), 299 closed; 5 087 with the reminders' consent |
| History | `portal_documents` 1–about 39 000, `portal_views` 1–about 65 000, `portal_outbox` 1–about 38 200, `portal_consent_events` 1–about 7 300, in time order (the outbox by `queued_at`, ties by `message_key`); `portal_sessions` the last 30 days' only, their ids where the year left them, from 39 301 | as built (D423): 38 973 documents, 65 032 views, 38 169 messages, 7 285 consent events, 4 507 sessions at the reference T0, after the core's agenda (D408) left about 4 % of the scheduled consultations without a row |
| Core and lab keys | `owner_id` 2–10 000, `animal_id` 1–17 000, `herd_id` 1–200 as the core documents them; documents' `source_ref` the core's consultations and stays and the lab's of the lab's order tests of account 1 | the keys computed by the sources' documented functions at load (D249); the documents' ids, in order of their gate and reference, and their content from the derivation step (D322) |
| A vaccination's due day | day of the year `1 + (animal_id × 211) mod 365` | for domestic animals and horses; farm animals have herd visits instead |
| Passwords and links (the owners' route) | each active account's password, and each invitation's and reset's token, an HMAC of the account's id and a key computed from the load's `load_epoch`, kept only in `owners`' schema on the partners' database (D406) | so the owners' route logs in and activates without the partners' database storing a password; the load stores bcrypt hashes and SHA-256 hashes of the tokens |

### Who sees what: row-level security (ruled, D320)

The owner scope is enforced in the database, so that it is a DBA's
matter: every table of the portal has row-level security on, forced;
the tables belong to `portal`, a role with no login; `portal_api` holds
neither ownership nor `BYPASSRLS`. Each request of the portal's API
runs in one transaction that first sets who asks,
`set_config('portal.owner_id', <the session's account's owner_id>, true)`
(local to the transaction), and
its queries add no owner filter of their own: the policies do.

| Table | `portal_api`'s policy |
|---|---|
| `portal_animals` | the animal's current `owner` ownership (`until_at` open) is the asker's, or the asker is its current `keeper` and the current owner's latest `keeper-access` event for that keeper and animal is a grant |
| `portal_ownerships`, `portal_herds` | the asker's own rows (a herd: its keeper) |
| `portal_documents` | the animal is visible as above (a herd's: its keeper), and the document's `record_at` is on or after the start of the current owner's ownership: never a record from before the sale |
| `portal_accounts` | the asker's own row, without the hashes (a column grant) |
| `portal_consent_events` | the asker's own events; an insert only as the asker |
| `portal_views` | insert only, as the asker's account |
| `portal_sessions`, `portal_outbox` | no grant: reached only through the functions below |

Before anyone is known (log in, activate, reset, unsubscribe, the
desk), the API calls `SECURITY DEFINER` functions owned by `portal`,
their `search_path` pinned: `portal_login(email, password)` checks the
hash and the lock and returns a token, its hash stored;
`portal_session(token)` returns the account if the session is open and
neither idle nor expired; `portal_logout(token)` ends it (a function,
since the sessions have no grant; D423); `portal_activate(token, password,
reminders)`, `portal_request_reset(email)`, `portal_reset(token,
password)`, `portal_unsubscribe(message_key)`, `portal_close()`,
`portal_desk_consent(owner_id, purpose, granted)`. They are the API's
`db/` side (D271), with its queries: the players may fix them, never
the routes.

The purposes' roles see every row (a policy `USING (true)` for each).

**As built (D423).** The policies are `<table>_scope`, for `portal_api`,
and `portal_sessions_purge` for `portal_housekeeping`; the asker is
`NULLIF(current_setting('portal.owner_id', true), '')::integer`, so an
unset owner sees no row. The keeper's clause and the documents' start
need rows the own-rows policies hide from a keeper, so two `SECURITY
DEFINER` helpers owned by `portal` (`STABLE`, `search_path` pinned,
`EXECUTE` for `portal_api` only) read them:
`portal_keeper_granted(animal, keeper)`, the current owner's latest
`keeper-access` event for that keeper and animal being a grant, and
`portal_owner_since(animal)`, the current owner's `from_at`.
`portal_animals_scope` has an owner branch (`until_at IS NULL`, which
T270 drops) and a keeper branch (the keeping current and
`portal_keeper_granted`); `portal_documents_scope` reads the animal
through `portal_animals` and `record_at >= portal_owner_since(animal)`
(which T271 drops). A `keeper-access` event is inserted only for an
animal the asker owns now; a view only for a document the asker sees.
The one link slot (`invite_hash`, `invite_expires_at`) holds an
invitation's or a reset's link, both 14 days; an `activation` consent
event is written only when the reminders are granted. Row-level
security binds every role but `portal` and superusers: `gm_check`'s
`pg_read_all_data` reads no portal row, so a GM read of `portal`
through `gm_src_*` needs a way in, open for W4's capture (O243).

### Application roles and grants

| Role | Who | Reads | Writes |
|---|---|---|---|
| `portal` | owns everything; no login; `BYPASSRLS`, so its `SECURITY DEFINER` functions reach every row (D423) | | |
| `portal_api` | the portal's API, `portal-api` (D267, D270) | through the policies above: animals, ownerships, herds, documents, its own account (no hashes) and consent events; `portal_settings` | views, consent events (its own), its account's `notify_by` and `reminders`; everything else through the functions |
| `portal_housekeeping` | the sessions' purge on `records`' `pg_cron` (D206, D207); a login role, since `pg_cron` runs a job only as one with `CONNECT` (D423) | `portal_sessions` | deletes sessions ended 30 days ago |

The purposes' roles (`portal_sync`, `portal_dispatch`) come with step 7
([below](#the-roles-the-purposes-add)). The API's connection admits
`portal` only: `pg_hba.conf` names the database for `portal_api`, over
`hostssl`, and the seed revokes `CONNECT` on `clinic` and `office` from
`PUBLIC` (both a trap when missing, T253); `schema.sql` grants `CONNECT`
on `portal` by name, revoked from `PUBLIC` (D423).

### Reference sizes

| What | Rows at load | Live, a day |
|---|---|---|
As built (D423; at the reference T0, `load_epoch` 2026-11-04T08:50Z):

| What | Rows at load | Live, a day |
|---|---|---|
| Settings, accounts | 1, 9 999 | 13 new; about 30 updates (logins, activations) |
| Animals, ownerships, herds (copies) | 17 000, 18 569, 200 | 20 animals, 26 ownerships, a few deaths |
| Documents | 38 973 (23 922 consultations, 12 673 results with 467 later versions, 2 378 discharges) | about 140 |
| Views | 65 032 | about 240 |
| Consent events | 7 285 (232 keeper grants in force) | about 11 |
| Outbox | 38 169 (25 728 notices, 6 675 reminders, 4 000 invitations, 1 633 resets, 133 closures) | about 120 |
| Sessions | 4 507 (15 open) | about 150 |
| **Total** | **199 735 rows, about 0.20 million** | **about 720 rows** |

77 MB with the documents' bodies and indexes, within `records`' 2.25G
volume. (Summing `n_live_tup` gives 237 904: it reads `portal_outbox`
double; `count(*)` is the figure.)

### Plausibility points (step 4, ruled, D320)

Offered to the owner (optional at step 4):

1. **Two thirds activated**, one visit a day per 40 active accounts, the
   evening peak.
2. **Documents per record, not per page**: a consultation, a result per
   test, a discharge; an amendment a new version.
3. **Copies, not calls**: the portal holds its own copy of the
   ownerships, since every page needs "my animals now" and the lookup
   API answers one animal at a time (D266's "a reference table the core
   syncs to it").
4. **Account ids equal to owner ids for the migrated accounts**, new
   ones from 20 001.
5. **bcrypt at cost 6**, a game value for the load's time (about 6 500
   hashes); a real portal would use 10 or more.
6. **Row-level security as the one scope control** (O212).
7. **A vaccination's due day a function of the animal's id**, the core
   recording no vaccinations as such.

## Classification and governance (step 5)

### Classification

v0.4's three classes, read as `vet-core` reads them (D280): keys
`<table>.<column>`, the scenario's copy adding the database (procedure
6, item 2); every column not listed is `internal`.

Readings for the portal:

- **An account is the owner's**: its name, e-mail and phone are direct
  identifiers, and the account's and the owner's ids beside them are
  personal; so is a password's hash, and an invitation's.
- **A session token is an online identifier** (GDPR recital 30): its
  hash is personal.
- **The copies follow the core**: an animal's or a herd's id with no
  identifier beside it is `customer-linked`, as the core's
  `ownerships.animal_id` is; the copies hold no natural identifier.
- **A document's body is the medical record**, `internal` once no owner
  is beside it, as the core's diagnoses are; its animal's id is
  `customer-linked`; the vet's name is a staff member's name, personal.
- **Consent events** carry an owner's id with no identifier beside it:
  `customer-linked` by the core's reading; the shop classed its consent
  events personal (v0.4 9.9), which the column-by-column reading of
  D280 refines.
- **The outbox carries addresses**: the address, the payload (the
  recipient's name, the animal's) and the ids beside them are personal.

| Table | `personal` | `customer-linked` |
|---|---|---|
| `portal_accounts` | `id`, `owner_id`, `display_name`, `email`, `phone`, `password_hash`, `invite_hash` | |
| `portal_sessions` | `token_hash` | `account_id` |
| `portal_animals` | | `animal_id`, `herd_id` |
| `portal_ownerships` | | `animal_id`, `owner_id` |
| `portal_herds` | | `herd_id`, `keeper_owner_id` |
| `portal_documents` | `vet_name` | `animal_id`, `herd_id` |
| `portal_views` | | `account_id` |
| `portal_consent_events` | | `owner_id`, `animal_id`, `keeper_id` |
| `portal_outbox` | `account_id`, `owner_id`, `animal_id`, `address`, `payload` | |

Animal health is no special category (O112). Two traps follow (step 8):
a document's body carrying free text, which may name a former owner;
and the copies carrying more than the portal shows (an address, a
chip).

### The business's own rules

The portal's default policy (procedure 6, item 1), beside the core's
and the lab's, in the domain's `docs/policy.md` and its `governance:`
fragment. Its home is the core's unnamed EU member state (D278); a
figure marked *game value* is a choice, not the law.

**Owner scope.** An account sees the animals its owner owns now, by the
core's current ownership, and of each the documents whose record falls
within that ownership; never another owner's animal, never a record
from before the sale, so never a former owner's identity (core rule
11). A keeper sees what the owner sees, while they keep the animal and
while the owner's consent for them stands (O206). Enforced by the
database's row-level security (O212).

**The release gate.** A result is published once released by a
clinical pathologist (lab rule 1), never on technical validation; a
consultation once signed; a discharge once the stay has ended. An
amended result is published as a new version, the first shown as
superseded (lab rule 3). Each within 15 minutes of its gate (*game
value*).

**Least data.** The portal's copies carry what it shows and no more: no
address, no natural identifier. A document carries no free text (the
findings, a pathologist's comment, an alert) and no staff contact, the
vet's name only (core rule 11). The region's practices' patients never
enter the portal (lab rule 10).

**Accounts.** One per core owner, invited at registration by a one-time
link valid 14 days (*game value*); a password stored as a bcrypt hash
at cost 6 (*game value*), never stored, sent or logged in clear; five
failed logins lock the account for 30 minutes (*game value*); a session
ends after 30 minutes idle or 12 hours (*game values*), its token
stored as a hash. Contacts are the core's (D266).

**Closing an account** (GDPR Art 17). On the owner's request: its
personal columns erased at once, its sessions ended, a closure message
sent; the consent events kept as proof (Art 7(1)); never reopened by
the copy from the core; the core's record untouched, its medicine
records kept five years (core rule 10, Art 17(3)(b)).

**Consents** (the shop's model). Every grant and withdrawal is an
event: owner, purpose, for `keeper-access` the animal and the keeper,
granted or withdrawn, when, where (activation, portal, a message's
link, the desk). The truth is the latest event; the account's
`reminders` flag is a convenience the jobs never read. A withdrawal
takes effect at once, from the next message (Art 7(3)). Reminders only
with consent (*game value*: the opt-in, where the existing-customer
exception would allow an opt-out, O214).

**Messages.** Only through the franchise's messaging service, a
processor (Art 28). A message carries its address, its template, the
animal's name and a link; never a result, a diagnosis, a natural
identifier or another owner's data (the outbound flow `to: messaging`,
D191). An invitation or a reset carries a one-time token, never a
password. Reminders are sent 08:00 to 20:00, never for an animal that
has died, never to anyone but its current owner, never to a closed
account, each with a withdrawal link. Every message has its key, kept
on a retry.

**Audit.** Every document opened is recorded: the account, the
document, the time; with the notices, what was released to whom.
pgaudit on `portal` logs writes, DDL and role changes, its parameters
off (`pgaudit.log_parameter = off`), since passwords pass through SQL.

**Logs.** No password, token or personal data in the server's logs: on
`portal` no statement logging (`log_statement = none`), parameters
never logged (core rule 10). As built (D423) `schema.sql` sets both as
the database's settings (`log_statement`, `pgaudit.log_parameter`), the
ones T250 and T251 change; `pgaudit.log` is the seed's.

**Reach.** The portal's API reaches the `portal` database only, over
TLS; never `clinic` or `office` (`pg_hba.conf`, `CONNECT`).

**Retention** (*game values*). Documents as long as the record they
show (five years, core rule 9); views and messages two years; sessions
30 days; consent events as long as the account and five years after,
the proof of consent; a closed account's personal columns at once. A
year of history holds nothing past them but sessions, purged nightly.

**What the data model took from these rules**: the policies; the
functions owning the authentication; the sessions' token hashes and
lives; the documents' `record_at` against the ownership's start; the
versions and `supersedes_id`; the consent events beside the flag; the
two uniques of the outbox; `invite_hash` and its expiry.

### The rules (ruled, D320)

For the owner to judge realistic:

1. **Owner scope**: the current ownership, its records only; a keeper
   with the owner's consent while keeping; enforced by row-level
   security.
2. **The release gate**: released results, signed consultations, ended
   stays; amendments as new versions; within 15 minutes (game value).
3. **Least data**: no address or identifier in the copies, no free text
   in documents, the vet's name only; no practice's patient.
4. **Accounts**: one per owner, invitation valid 14 days, bcrypt cost 6,
   five failures lock for 30 minutes, sessions 30 minutes idle and 12
   hours at most, tokens hashed (game values).
5. **Closing an account**: personal columns erased at once, sessions
   ended, consent proof kept, never reopened, the record untouched.
6. **Consents**: the shop's events, the latest the truth; withdrawal at
   once; reminders on opt-in (game value, O214).
7. **Messages**: through the franchise's messaging service only;
   address, template, the animal's name and a link; reminders 08:00 to
   20:00, never for a dead animal, a former owner or a closed account;
   one key per message.
8. **Audit**: every document opened recorded; pgaudit writes, DDL and
   roles without parameters.
9. **Logs**: no statement logging and no parameters on `portal`.
10. **Reach**: the API on `portal` only, over TLS.
11. **Retention** (game values): documents five years, views and
    messages two, sessions 30 days, consents five years after the
    account.

## The producer profiles (step 6)

**Producer or purpose.** The portal's own application is its API: what
it writes (sessions, views, consents, its account's columns, the
account messages) is this step's, driven by the owners' traffic. The
flows from the core and the lab into the portal, and from the portal to
the messaging service, are purposes (procedure 4, step 7).

### The applications and their nodes (D276)

| Application | Node | Connection, role | What it does |
|---|---|---|---|
| The portal | `portal-api`, an `api` node in the players' scope (D267, D270) | `portal`: `records:5432/portal`, `portal_api`, over TLS | only answers: the endpoints below; players edit its `db/` side only, the functions and queries (D271) |
| The owners' browsers | the partners' `api` node, hostname `owners`, ticked by the partners' back end, out of reach (ruled, D320) | HTTP to `portal-api`; the back end's database for its own record of visits, and the messaging stub's record of messages received | visits, activations, resets, unsubscribes, keeper grants, closures (rates below) |
| The desk | `pms`, the practice software (D276: one application carries the parts' fragments) | HTTP to `portal-api`, the desk's credential (a secret) | `portal.desk-consent`, a stream: an owner's consent recorded at the desk |

No scheduler node of the portal's own: its background work is the
purposes' (on `interfaces`) and its one housekeeping job is on
`records`' `pg_cron`.

**`portal-api`'s endpoints** (each one transaction, `portal.owner_id`
set locally first for those after login):

| Endpoint | What |
|---|---|
| `POST /login` | `portal_login`: a session token (201, the HttpOnly cookie `portal_session`), 401, or 423 while locked |
| `POST /logout` | `portal_logout`: the session ended, 204, the cookie cleared |
| `GET /me`, `PUT /me/preferences` | the account (no hashes), its channel and its consents; the channel changed (422 a channel not `email`, `sms`, `none`) |
| `POST /me/consents` | a grant or a withdrawal: `reminders`, or `keeper-access` for an animal and a keeper; the event (201), and the flag for `reminders`; 403 a `keeper-access` for an animal not owned now (the policy's check) |
| `GET /animals` | the asker's animals, by the policies |
| `GET /animals/{id}/documents` | that animal's documents, newest first, 50 at most, superseded versions included (`superseded_at`); 404 an animal the asker does not see. No herd listing: a herd's keeper opens a herd's document by its id |
| `GET /documents/{id}` | one document; a `portal_views` row in the same transaction; 404 one the asker does not see |
| `POST /accounts/activate` | `portal_activate`: the password set, `active`, the reminders' consent offered (an `activation` event when granted); 200, 401 a link unknown, used or expired |
| `POST /password-reset`, `POST /password-reset/{token}` | `portal_request_reset` queues a `password-reset` message, 202 whatever the address; `portal_reset` sets the password and renews an expired invitation, 200 or 401 |
| `POST /unsubscribe/{message_key}` | `portal_unsubscribe`: the reminders withdrawn (`message-link`), no login |
| `POST /me/close` | `portal_close` |
| `POST /desk/consents` | the desk's credential: `portal_desk_consent` (`desk`), 201; 422 refused (another purpose, or the owner's account closed: about one desk call in thirty, kept, D426); 401 without the credential |

### Rates at intensity 1.0

The portal's API writes nothing on its own: its volume is the owners'
traffic, on the partners' back end, prefixed `owners.` (D303's ticked
routes, the endpoint on the `owners` hostname reading, calling and
writing):

| Key | What one tick does | Rate | Shape | A day |
|---|---|---|---|---|
| `owners.visit` | picks an active account, 70 % among the recipients of a message in the last 24 hours (from the messaging stub's record), the rest at random; logs in (one in 25 mistypes once first; one in 300 five times, locked); one in 50 first tries a token from a past session, a bookmarked link; lists the animals, opens one or two documents (1.6 on average); one in ten changes its channel or the reminders' consent; logs out half the time; records what each call returned | 9.3/h, poisson | `owners-day` | about 150 |
| `owners.activate` | the oldest planted invitation whose activation delay has passed (`owners.accounts`' `activates_at`, D423), else the oldest made in play, from the messaging stub, whose delay (0 to 3 days, by a hash of the account's id; 30 % never) has passed: activated with its token and the account's password, the reminders' consent granted by 80 % | 4/h (a capacity) | `owners-day` | about 9, following the invitations |
| `owners.reset` | an active account asks a reset, then uses the message's token (from the messaging stub: without it, as in chunk 16's fixture, resets are asked and never used) | 0.31/h, poisson | `owners-day` | about 5 |
| `owners.unsubscribe` | a reminder received, one in twenty by a hash of its key, withdrawn through its link a few hours later | 2/h (a capacity) | `owners-day` | about 1 |
| `owners.keeper` | a horse owner grants a keeper of the horse access (three in four) or withdraws it | 0.08/h, poisson | `owners-day` | about 1.3 |
| `owners.close` | an active account closed | 0.015/h, poisson | `owners-day` | one every four days |

As built (D423), the route keeps its state in `owners`' `data.sql`:
`owners.settings` (`password_key`, the key's one copy) and
`owners.accounts (account_id, email, status, link, activates_at)`, the
load's open accounts as each browser remembers its own login
(`account_id` the account's id and its owner's), updated by its own
activations and closures, since the route cannot read `portal`; every
call recorded in `owners.visits (id, at, account_id, call, status,
animal_ids, document_ids)`. Its constants are one-value `choice`s (D303).
About half the `owners.keeper` ticks find a consent to change (222 of
the 414 active horse owners hold one; T274's witness, D427).

On `pms`, as the desk's credential over HTTP:

| Key | What one call does | Rate | Shape | A day |
|---|---|---|---|---|
| `portal.desk-consent` | an existing owner's reminders' consent granted or withdrawn at the desk (owner 2 to 10 000, by a weighted `choice`, D303) | 0.28/h, poisson | `clinic-day` | about 3 on a weekday |

Fixed-time operation, on `records`' `pg_cron`
(`cron.schedule_in_database('portal', ...)`, as `portal_housekeeping`):

| Job | When | What |
|---|---|---|
| `portal.sessions.purge` | `30 3 * * *` | sessions ended 30 days ago deleted (rule 11) |

### The business hours (shapes)

| Shape | Hours |
|---|---|
| `owners-day` | every day: 0.1 at 23:00–07:00, 0.5 at 07–09, 0.8 at 09–18, 1.6 at 18–22, 0.8 at 22–23 |
| `clinic-day` | the core's ([vet-core](vet-core-domain.md#the-business-hours-shapes)) |

### The history before T0

As the core's: the year ramps from about 60 % of today's volume to
today's (D279), on the shapes above, so the evening peaks and the
notices after the pathologist's rounds show in `portal_views` as they
will in the aging. Derived from `clinic` and `lab` by the sanctioned
step after their loads (D322; [Loading](#loading)): the
copies as the core holds them at T0, the documents of every signed
consultation, released centre test and ended stay of the year, the
amendments as versions. In flight at T0, as a night leaves the portal:

- the night's signed consultations and urgent results published, their
  notices sent (notices go at any hour; reminders wait for 09:00);
- about 190 open links (193 as built: the invitations within their 14
  days and the older invited accounts' renewals), their tokens in the
  messaging stub's record, so the owners activate them over the next
  days;
- a few sessions from the late evening, idle;
- today's reminders not yet queued;
- the planted messages of the last day in the messaging stub, so the
  morning's visits follow them.

As built (D423) the load writes no outbox row: the derivation writes
the year's outbox numbered 1..n by `queued_at`, ties by `message_key`,
the sequence set after (the coherence check `outbox-order` holds it);
`message_key` is `md5('<template>:<account>:<reference>')::uuid`, a
sent row's `provider_id` `md5('messaging:' || message_key)::uuid`; one
message in fifty took two attempts (a 503, then the same key); the last
two minutes' are unsent.

The messaging stub's messages of the last 14 days (the invitations'
tokens among them) are planted after the derivation by
`vet-portal-messages`' history, copying `portal_outbox`'s sent rows;
the derivation writes `portal` only (D404). The owners' route's key is
planted by `owners`' `data.sql` (D406).

### Cold storage (D297)

Nothing of the portal ships: about 720 rows a day against the
threshold of about 50 000 (D296). `portal` rides `records`' WAL
archiving and base backups (D299).

### Growth, for the GM notes (D298)

At intensity 1.0, on `portal`:

| | Rows | Size |
|---|---|---|
| A day | about 720 new rows, about 400 updates (logins, sessions seen, messages sent) | about 0.3 MB with indexes |
| An evening hour, 18:00–22:00 | about 60 | |
| A night hour | about 10, the night's publications | |

The partners' database grows by about 300 rows a day for the portal
(the messages received, the visits recorded).

### Nodes and capacity

| Node | Brick | Scope | CPU | Memory | Disk | Host |
|---|---|---|---|---|---|---|
| `portal-api` | `api` | the players' | 0.1 | 96M | 128M | armenelos |
| `portal` (a database on `records`) | | | on `records` | on `records` | about 0.1G of its 2.25G | |
| the owners' traffic | the partners' `api` node and back end | out of reach | on theirs | on theirs | | VPS |

**One node, 0.1 CPU, 96M**, against the tally's estimate of 2 to 4
nodes and 0.2 to 0.8 CPU ([clinic-capacity.md](clinic-capacity.md)).
`interfaces` takes six more jobs (step 7), light: 96M instead of
64M (D320). If the owner wants the database on a node of its own
(O210): three nodes (`portal-api`, a `postgres` node, its exporter),
about 0.65 CPU and 0.66G, the `postgres` node on armenelos (the VPS has
no room for one). If the owners' traffic gets a node of its own (O211):
one more, 0.1 CPU and 64M, out of reach.

## Purposes that fit (step 7)

No existing purpose fits as built: the core's and the lab's ten move
nothing into the portal. Two new ones (ruled, D320; purposes 15 and 16
of sixteen, D324), each its own
unit under `purposes/`, both on `interfaces` (D306 point 2: the
integration engine's light, frequent flows), in v0.4's format with
D307's extensions.

### `vet-portal-release`: the copies and the release gate

**Kind**: pulled (v0.4's P1 shape, a consumer filling its own store),
with a release gate (v0.4's stress test). **Fits** `vet-core`,
`vet-lab`, `vet-portal`. **Source → target**: `clinic` (as
`vet_portal_sync`) and `lab` (as `lab_release`) → `portal` (as
`portal_sync`).

**Jobs** (on `interfaces`):

| Job | Cadence | What it computes |
|---|---|---|
| `sync-portal-identity` | `*/5 * * * *` | owners registered since the watermark (`registered_at`): an account `invited` each, its invitation queued (`portal_outbox`, `invitation`); animals registered, their ownerships started or ended (`from_at`, `until_at`), deaths (`died_at`) since the watermark: the copies updated; a closed account never touched |
| `publish-records` | `*/5 * * * *` | consultations signed since the watermark (`signed_at`) and stays ended since it (`discharged_at`): a document each, version 1, its body built by the rules (diagnoses' labels, prescriptions, withdrawal ends; no findings) |
| `publish-results` | `*/5 * * * *` | the lab's order tests of account 1 released since the watermark (`released_at`), with their results: a document each; results amended since it (`amended_at`): a new version, the former superseded |

Each run writes its documents, its watermark (`ops.watermarks`) and its
`ops.runs` row in one `portal` transaction, after reading the source in
a repeatable-read snapshot; the watermark is the latest gate time read,
less a margin of two minutes, a document already published skipped by
its `source_ref` and version.

**Trace**: `portal_accounts`, the copies, `portal_documents`,
`ops.watermarks`, `ops.runs`, `ops.incidents` in `portal`; the
runner's log; the sources' gate columns (the GM's checks read both).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| RL1 | No document before its gate: a result's test released in the lab at or before `published_at`, a consultation signed, a stay ended | runs | every publication: about 140 a day; the urgent results technically validated before their release, about 15 a day |
| RL2 | Every gate passed since the judged moment has its document within 15 minutes, once (one version 1 per `source_ref`) | triggers | about 140 a day, in bursts at the rounds and the morning's signing |
| RL3 | Every centre result amended since the judged moment has its new version within 15 minutes, the former superseded | triggers | about 2 a day |
| RL4 | No copy or document carries an address, a natural identifier, free text or a staff contact; no document comes from an account other than 1 | runs | every publication |
| RL5 | Every owner registered since the judged moment has an account `invited` within 10 minutes; every ownership started or ended, every death, is in the copy within 10 minutes; no closed account is reopened | triggers | 13 owners, 20 animals, about 3 transfers and one or two deaths a day; closures one every four days |
| RL6 | Every account sees exactly the animals the core says it owns now, or keeps with a standing consent; and of each only documents from within the current ownership | runs, on the owners' recorded visits | about 150 visits a day; about 9 a day by an owner who has sold an animal in the year |

RL6 is judged on what the owners' route recorded each call returning,
against the core's ownerships at that moment: the portal's owner scope
end to end, wherever a fault sits (the copy, a policy, a function).

**Data moved**: owners' names, e-mails and phones (personal) from
`clinic` into `portal_accounts`; ownerships and animals' ids
(customer-linked); the record's content (internal) and the vets' names
(personal) into documents; the lab's released results of account 1.

**Roles**: `vet_portal_sync` on `clinic`, `lab_release` on `lab`,
`portal_sync` on `portal` ([below](#the-roles-the-purposes-add)).

### `vet-portal-messages`: notices and reminders to the messaging service

**Kind**: pushed (v0.4's P3, customer mailing), to a third party, the
franchise's messaging service (D293), a transactional and a
consent-bound part as P3's. **Fits** `vet-portal`. **Source →
target**: `portal` (as `portal_dispatch`) → the messaging service's
stub.

**Receiver**: the messaging service, its own hostname on the partners'
one `api` node (D308), material in the purpose (`receiver/`, D307 item
4), its records in the partners' database: `POST /messages` (message
key, channel, address, template, payload) answers 202 with its id, the
same key again the same id; it answers 503 to about one call in fifty
as standing behaviour, so retries have a witness (D214's precedent); it
keeps what it received (the owners' route reads it for its tokens and
recent recipients).

**History** (D404): the purpose's `history` plants what the stub
received in the last 14 days, its `target` the partners' database,
`portal` its source: `portal_outbox`'s sent rows, read through
`gm_src_source` after the derivation, the 193 open links' tokens
among them (read as `gm_check`, which row-level security binds: the
read needs a way in, open for W4's capture, O243). The stub's DDL is its receiver material, copied into the
partners' node's data file, with `SELECT` granted to `owners`.

**Jobs** (on `interfaces`, `portal` as `portal_dispatch`):

| Job | Cadence | What it computes |
|---|---|---|
| `queue-notices` | `*/5 * * * *` | documents published since the watermark: one `document-notice` for each account that sees it (the current owner's, a granted keeper's), active, its channel not `none`; payload: the template, the animal's name, a link |
| `queue-reminders` | `0 9 * * *` | domestic animals and horses alive in the copy whose due day is in 14 days, whose current owner's latest `reminders` event is a grant and whose account is not closed: one `reminder` per animal and due day, with its withdrawal link |
| `send-messages` | `* * * * *` | the outbox's unsent rows (reminders only between 08:00 and 20:00), oldest first, each posted with its `message_key`, a five-second timeout; 202: `provider_id` and `sent_at`; otherwise the attempt counted, retried at the next run with the same key; after six attempts `failed_at` and an `ops.incidents` row; consent checked again for a reminder at sending time |

**Trace**: `portal_outbox`, `ops.watermarks`, `ops.incidents`,
`ops.runs` in `portal`; the runner's log with each call; the stub's
received messages (evidence).

**Invariants**:

| Id | Statement | Judged | Witness |
|---|---|---|---|
| MS1 | At most one notice per document and account, one reminder per animal and due day, one message at the service per `message_key` | runs | every message; each 503, one in fifty |
| MS2 | Every reminder sent since the judged moment had its owner's `reminders` consent at `sent_at`, by the latest event; transactional messages exempt | runs | about 25 a day; withdrawals about 4 a day, by link, portal and desk |
| MS3 | Every reminder's `sent_at` falls between 08:00 and 20:00, the customer's time | runs | the 09:00 queue |
| MS4 | Every payload carries its template, the animal's name and a link, and names its recipient only: never a result, a diagnosis, an identifier, another owner; an invitation or reset a token, never a password | runs | every message |
| MS5 | Every document published since the judged moment, for an active account whose channel is not `none`, has its notice accepted by the service within 15 minutes, or an incident by its sixth attempt | triggers | about 75 a day, in bursts at the rounds |
| MS6 | No reminder for an animal dead, or to anyone but its current owner, by the core at `sent_at`; no message to a closed account | runs | the daily reminders; one or two deaths and three sales a day |

**Data moved**: the address, the recipient's and the animal's names,
a link with a one-time token (personal), to the franchise's messaging
service, a processor (Art 28). The `governance:` fragment's outbound
flow: `to: messaging`, fields `address`, `template`, `animal_name`,
`link`.

### The roles the purposes add

| Database | Role | Who | Reads | Writes |
|---|---|---|---|---|
| `clinic` | `vet_portal_sync` | `interfaces`' release jobs | `owners` (id, kind, name, email, phone, registered at: a column grant, no address), `animals` (id, name, species, sex, born on, herd, status, died at: no identifiers), `ownerships`, `herds` (id, keeper), `consultations` (id, animal, herd, kind, section, vet, started at, signed at), `diagnoses`, `diagnosis_codes`, `prescriptions`, `prescription_lines`, `medicines` (id, name), `stays`, `staff` (id, name) | nothing |
| `lab` | `lab_release` | `interfaces`' release jobs | `lab_orders` (id, account, animal, ordered at: a column grant, no identifiers or clinical notes), `lab_order_tests`, `lab_results`, `lab_tests`, `lab_analytes`, `lab_reference_intervals` | nothing |
| `portal` | `portal_sync` | the release jobs | the copies, accounts, documents | accounts (insert; contacts and `synced_at`; never a closed one's), the copies, documents, invitations in `portal_outbox`, `ops.*` |
| `portal` | `portal_dispatch` | the messages' jobs | accounts (status, channel, address), the copies, documents, consent events, the outbox | the outbox (queued notices and reminders, sending columns), `ops.*` |

### Points for the owner (step 7, ruled, D320)

1. **Two purposes**, `vet-portal-release` (pulled, the release gate and
   the copies) and `vet-portal-messages` (pushed, notices and reminders
   to the messaging service), the clinic's fifteenth and sixteenth (D324).
2. **Both on `interfaces`**, six light jobs; the copy from the core a
   purpose, not a producer's job (D266's synced reference table; the
   portal has no scheduler node of its own).
3. **The results read from the lab's release**, never from the core's
   `requests` state, so the core's copy of the lab's fact (T43) cannot
   break the portal's gate.
4. **The owner scope judged end to end** on the owners' recorded visits
   (RL6).
5. **The game values**: 15 minutes for a publication and a notice, 10
   for a copy, six attempts, reminders 14 days ahead from 09:00 to 20:00.

## Traps (step 8)

Where faults can bite the portal, each with its D290 class, in the
manner of [clinic-traps.md](clinic-traps.md) (its "How to read the
tables" applies). No owner checkpoint: a scenario's faults are the GM's
to select (D309); v0.5 builds only the test selection's ten (D316), so
these stay listed for the GM, but for one swap: T270 replaces s5 in the
test selection (D325; [changes](#changes-needed-in-shared-pages), item
12). Of the core's
and the lab's traps, T13, T19 and T26 name the portal as a later
victim, but the portal holds no chip and does not call the lookup API,
so as designed they do not reach it; T43 is blocked by design (step 7,
point 3); T80, the release time unindexed on `lab`, slows
`publish-results` too.

### 1. Configuration and reach

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T250 | Statement logging on `portal` (`ALTER DATABASE portal SET log_statement = 'all'`, or `log_min_duration_statement = 0`) | owners' passwords in clear in the server log, since the functions hash them in SQL; e-mails beside them (rules 4, 9) | the log, at once, every login (about 9 an evening hour) | the database's setting | adapts the held `governance-statement-log-personal` (D191) to a per-database setting | M, V when the log ships off site |
| T251 | pgaudit's parameters on for `portal` (`pgaudit.log_parameter = on`) | passwords and tokens in the audit log (rule 8) | the audit log, at once | the setting | adapts the held one | M |
| T252 | `portal-api`'s connection without TLS (`host` where `hostssl` is meant) | passwords and documents in clear between the internet-facing node and the record's instance (rule 10) | `pg_stat_ssl` for `portal_api`'s backends, at once | `pg_hba.conf` | new (TLS always available, D250) | M |
| T253 | `portal_api` admitted to every database (`host all portal_api`), `CONNECT` on `clinic` and `office` left to `PUBLIC` | the internet-facing role able to open the record's database, reading whatever a `PUBLIC` grant leaves (rule 10) | `pg_hba.conf` and `has_database_privilege`, at once | `pg_hba.conf`, `REVOKE CONNECT` | new | M |
| T254 | The sessions' purge missing, or scheduled in the wrong database (`cron.schedule` runs in `cron.database_name`, `postgres`, instead of `schedule_in_database('portal', ...)`) | sessions kept beyond 30 days (rule 11), the table growing by 150 a day | sessions ended over 30 days ago, at once when planted months back; `cron.job_run_details` failing | `cron.job` | new | M |
| T255 | A `SECURITY DEFINER` function of the portal without a pinned `search_path` | a role able to create in a schema on the path runs its own `crypt` as `portal` | the functions' `proconfig`, at once | the function's definition | new | M |

### 2. The copies and the release (`vet-portal-release`)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T256 | Deaths not copied (the sync takes new animals and ownerships, never `died_at`), since a release a few months back | dead animals listed alive; their vaccination reminders: the grieving owner's call to the clinic (MS6, RL5) | the copy's status against the core, at once from the planted history; a wrongful reminder every two or three days | `interfaces`' script, then the copy | new | D (with the story's complaint), V |
| T257 | Ownership ends not copied (only new ownerships taken) | the former owner still sees the animal sold, its new records and its reminders (rule 1, RL6) | ownerships open in the copy and closed in the core, about 3 a day; at once from history | `interfaces`' script, then the copy | new | V, D when a new owner complains |
| T258 | The identity watermark taken from the run's start, or the latest `registered_at` read, while a registration commits later | an owner never invited, their documents never notified (RL5) | owners without an account, about one a day at the busy hours | `interfaces`' script | adapts `purpose-watermark-misses-updates` | V |
| T259 | The sync's upsert setting every account `invited` | closed accounts reopened and re-invited: messages to people who asked to leave (rule 5, Art 17) | at the first run, about 300 invitations to closed accounts | `interfaces`' script, then the accounts | new | D (owners complain within the hour) |
| T260 | The copy taking the microchip and passport, or the owner's address | identifiers and addresses in the internet-facing database (rule 3; G1) | the columns and a content probe, at once | `interfaces`' script, the table | adapts `governance-personal-copied` | M |
| T261 | An account's id taken for its owner's id (in `portal_session`, or a query joining `portal_ownerships.owner_id` to `portal_accounts.id`) | right for every migrated account, wrong for every one created since T0 (ids from 20 001): new owners see no animals | each activation of a new account, about 9 a day; at once in a test | `portal-api`'s `db/` (D271) | new | V, D when new owners call |
| T262 | The copy without the core's one-current-owner index on `portal_ownerships`, a rerun of the sync after an error inserting a sale's new ownership again | two current owners in the copy, both seeing the animal (rule 1, RL6) | duplicate current ownerships after each failed run | the index, then the copy | new (the core's T15, in the copy) | M |
| T263 | Results published on technical validation (`technically_validated_at` taken for `released_at`) | unvalidated results in the portal, urgent ones at once (lab rule 1, RL1) | documents whose test is `technical`, about 15 urgent ones a day | `interfaces`' script | new | V |
| T264 | Results published from the core's `requests` `resulted` (a "simplified" job), not the lab's release | the portal's gate depending on another purpose's copy: T43 reaches the owners; amendments never reach them | the job's source, at once; with T43, documents before release | `interfaces`' script | new | M |
| T265 | Consultations published once `closed`, not `signed` | unsigned records in the portal, changed after the owner read them (core rule 11) | documents of unsigned consultations, about 85 a day | `interfaces`' script | new | M, V |
| T266 | The publication watermark from the run's start while a signature or a release commits later | signed consultations or released results never published (RL2) | gates passed with no document, a few a day, more at the rounds | `interfaces`' script | adapts `purpose-watermark-misses-updates` | V |
| T267 | Amendments never published (the job takes `released_at` only) | owners holding a superseded value (lab rule 3, RL3) | about 2 a day | `interfaces`' script | new | M |
| T268 | The findings or the pathologist's comment copied into a document's body | free text naming a former owner or a staff phone in the portal (rule 3, RL4) | the bodies, at once | `interfaces`' script | adapts `governance-personal-copied` | M |
| T269 | `publish-results` not filtering account 1 | the region's practices' patients' results stored in the centre's portal, the lab's processor duty broken (lab rule 10, RL4) | documents from other accounts, about 40 a day | `interfaces`' script | new | M, V |

### 3. Who sees what (the policies)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T270 | The animals' policy without the ownership's end (`until_at IS NULL` dropped) | former owners still see the animals they sold and their new records (core rule 11, RL6) | a former owner's `GET /animals`, about 9 visits a day; at once in a test | the policy (DDL on `portal`) | new | M, V over days (s5 of the test selection, D325) |
| T271 | The documents' policy without the ownership's start (`record_at` against `from_at`) | a new owner reads the records from before the sale, the former owner's name with them (rule 1) | an animal sold in the year: its earlier documents returned to the buyer | the policy | new | M |
| T272 | Row-level security bypassed for the API: `portal_api` owning the tables (a migration run as it) without `FORCE`, or granted `BYPASSRLS` for a support script | every owner sees every animal, the queries relying on the policies | every visit, at once: the owners' recorded visits, owners calling | the tables' owner, `FORCE`, the role | new | D |
| T273 | No policy on `portal_documents` (the animals' only), while `GET /documents/{id}` reads by id | any owner opens any document by changing the number in the link | `pg_policies`, at once; the visits never probe, the story's complaint does ("I changed the number") | the policy | new | D with the story, M without |
| T274 | The keeper's clause without the withdrawal, or without the keeping's end | a livery yard still seeing a horse after the owner withdrew, or after it left (rule 1) | about one withdrawal every five or six days (as built, D427); the planted history | `portal_keeper_granted` (the withdrawal) or `portal_animals_scope` (the keeping's end) | new | M |
| T275 | The consent lookup inside the policy unindexed (`portal_consent_events (animal_id, keeper_id, at)`; the shop's `consent_events (customer_id, at)`) | every `GET /animals` scanning the events, the evening peak slowing | `pg_stat_statements` on `records`, at once and at each peak | an index | adapts `pg-join-index-missing` | M |

### 4. Accounts and sessions (`portal-api`'s `db/` side)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T276 | `portal_session` ignoring `expires_at` and the idle limit | an old token, a bookmarked or stolen link, still opens the owner's file (rule 4) | the visits' old tokens accepted, one visit in 50 | `portal-api`'s `db/` | new | M |
| T277 | Session tokens stored in clear | anyone reading `portal_sessions` (the standby, a backup, a support login) acts as the owner (rule 4) | the column's values, at once | `db/`, the sessions ended | new | M |
| T278 | New passwords hashed with `md5()` (or `gen_salt('md5')`) in `portal_activate` and `portal_reset` | weak hashes since a release (rule 4) | hashes without the `$2a$` prefix, about 14 a day | `db/` | new | M |
| T279 | `failed_logins` never reset after a success, or `locked_until` ignored | owners locked out for good after five lifetime mistakes; reception's calls rising (rule 4) | locked accounts growing, about one every two days | `db/` | new | V |
| T280 | The view written outside the read's transaction, or dropped | opened documents unrecorded: what was released to whom lost (rule 8) | documents the owners' route opened with no view row, at once | `db/` | new | M |
| T281 | Closing an account leaving its sessions open | a closed account still reading while a session lasts (rule 5) | rare: one closure every four days | `db/` | new | M |
| T282 | An invitation's token neither expiring nor cleared on use | an old invitation link resets an active account's password (rule 4) | invitations used twice or after 14 days | `db/` | new | M |

### 5. Consents and messages (`vet-portal-messages`)

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T283 | Reminders reading the account's `reminders` flag, which the unsubscribe link (or the desk) no longer updates since a release | reminders to owners who withdrew (MS2, Art 7(3)) | the flag against the latest event, at once from the planted history; a wrongful reminder about once a day | the purpose's query (the latest event), then the flag | adapts `purpose-leads-stale-consent` | V |
| T284 | Consent judged at the 09:00 queueing only, never at sending | a withdrawal between the queue and a delayed send ignored (MS2) | with a messaging outage's backlog | the send's check | adapts `purpose-mail-ignores-consent` | M |
| T285 | Reminders for farm animals, herds or the clinic's own teaching animals (owner 1) | messages to holdings for animals with herd visits; reminders addressed to the clinic itself | about 3 a day | the queue's query | new | M |
| T286 | `queue-reminders`' day taken in UTC, or the job at 09:00 UTC | due days off by one around midnight; reminders before 08:00 at a negative shift (MS3) | the due day against the function, at a non-zero shift | the query, `jobs.yaml` | adapts `purpose-day-boundary-wrong-zone` | M |
| T287 | A new `message_key` on each retry | the same message twice at the owner after each 503 (MS1) | the stub's messages per document, one in fifty calls | `interfaces`' script | adapts `purpose-retry-without-key` | M |
| T288 | The reminders' unique dropped and the queue run twice (moved, restarted) | every reminder of the day doubled (MS1) | a second run, at once | the constraint | new | M |
| T289 | Messages sent one after another with a 60-second timeout while the service is slow | every notice and invitation held behind slow calls, hours late (MS5) | the outbox's age at the stub's slow answers | `interfaces`' script | new | V |
| T290 | The messaging stub down (a timeline outage) and nothing escalating | notices and reset links unsent for hours, no incident; owners calling for their passwords (MS5) | unsent rows past six attempts with no `ops.incidents` row | the escalation step | adapts `purpose-receiver-down-unnoticed` | V |
| T291 | The result's values or the diagnosis in a notice ("Rex's potassium is high") | medical data to a third party beyond the rule (MS4, rule 7) | the stub's payloads, each notice | `interfaces`' script | adapts `governance-personal-copied` | M, V |
| T292 | Messages queued for closed accounts | messages to people who left (MS6) | each closure; every one with T259 | the queue's queries | new | M |
| T293 | A notice addressed by the record's owner rather than the account that sees it | a late result after a sale sent to the former owner (core rule 11) | a result released after a sale, about one a week | `queue-notices`' query | new | M |

### 6. Performance

| # | Trap | Where it bites | Witness | Fixed on | Catalogue | Class |
|---|---|---|---|---|---|---|
| T294 | `GET /animals/{id}/documents` unbounded, or `portal_documents` unindexed on the animal | a horse's or a herd's year read at each visit, the evening peak slowing | `pg_stat_statements`, at once | `db/`, an index | adapts `scheduler-report-unbounded`, `pg-join-index-missing` | M |
| T295 | A portal job on `interfaces` holding its `portal` transaction open across the messaging call | vacuum held back on the whole of `records`, `clinic` included (the oldest snapshot is the instance's); locks on the outbox | `pg_stat_activity` idle in transaction at each slow answer; dead rows rising in `clinic` | `interfaces`' script | adapts `scheduler-transaction-held-open` | V |

### False-alarm material

Complaints with no fault behind them, each answerable from the trace
(D290):

| Complaint | Why it is no fault | What answers it |
|---|---|---|
| "The portal locks owners out" | five failures lock for 30 minutes, by design (rule 4) | `failed_logins` and `locked_until` |
| "I can't see my horse's old records" | bought last month: records from before the sale are not shown (core rule 11) | the ownership's `from_at` |
| "The vet saw a result the portal doesn't show" | an urgent result technically validated, shown inside, released later (lab rule 1) | the test's release state |
| "The livery yard lost access to my horse" | the owner withdrew it, or the horse moved yard | the latest `keeper-access` event, the keeping's end |
| "No reminder for my cows" | farm animals have herd visits, no reminders | the reminders' rule |
| "The reminder came two weeks early" | 14 days ahead, by design | the due day's function and the lead |
| "The desk's consent call fails now and then" (a 422 in `pms`' log) | the owner's account is closed: the desk tried a client who left, about one call in thirty (D426) | the account's `status` |

## Testing in v0.5 (D314): the minimal fixture

**The `portal` fixture**: `records` (`clinic`, `office`, `portal`),
`lab`, `interfaces`, `portal-api`, the partners' `api` node (the
`owners` and `messaging` hostnames), back end and database, with the
bastion: eight nodes, about 1.75 CPU and 1.7G, one host. The test
writes the gates itself as `vet_app` and `lab_app` (a signature, a
release, a death, a sale) instead of running `pms` and `lis`, and
calls `portal-api` itself where an owner's call is needed. T0 a
weekday, 08:50, just before the reminders' queue (moved to the next
minute where a check needs it, D132).

| Check | What proves it | Time |
|---|---|---|
| The copies | an owner and an animal registered, a sale, a death written in `clinic`: the account `invited` and the copies within 10 minutes; the invitation at the messaging stub | about 10 minutes |
| The release gate | a consultation closed and another signed, a test technically validated and another released, an amendment: only the signed, the released and the amendment published, within 15 minutes | about 15 minutes |
| Owner scope | as a planted owner, a former owner, a buyer and a keeper with and without consent: each `GET /animals` and document list as the rules say; a document's id from another owner refused | about 5 minutes |
| Accounts | activation from the stub's token, a login, five failures and the lock, an old token refused, a closure | about 5 minutes |
| Messages | a notice accepted with its key; a 503 retried with the same key; the reminders queued for the due animals with consent, a withdrawal by link excluded | about 10 minutes |

Each under 30 minutes with the deployment. **The owners' recorded
visits (RL6)** run on the same fixture, the owners' traffic raised in
its profile layer (D264) so a visit comes every few minutes.

Only the whole-clinic run shows: the owners' traffic among every other
producer, the notices following the pathologist's real rounds. Only
v1.0's major test shows: the evening peaks and the reminders over days,
the sessions' purge and the lock-outs across a full aging, a fault's
class as the hand-over finds it (D290).

## Loading

Two steps (D322; the mechanism confirmed as written, D326, for O111,
which the master spec carries):

1. **The load.** `gmctl load-data` runs `schema.sql` then `load.sql`
   into `portal` on `records` as `postgres`. It never reads the core or
   the lab (D249): the accounts (owner `o`'s is `o`), consent events,
   reminders and their due days, sessions and tokens by documented
   functions of the ids, the core's owners, animals and herds by its
   documented ranges and functions. Each sequence set after its range;
   `portal_accounts`' at 20 000.
2. **The derivation step, sanctioned by the GM.** The documents copy the
   record field by field (a consultation's diagnoses and prescriptions,
   a test's analytes, values and intervals, a discharge), and the copies
   of animals and ownerships hold the core's state at T0. Recomputing
   those by formulas would duplicate the core's and the lab's loads'
   generation in a third place, two implementations that must agree on
   every value; this is the case D322 names. So `data/derive.sql` runs
   after every source's load, as `postgres`, reading `clinic` and `lab`
   through a temporary foreign server it drops afterwards (D307 item
   5's mechanism for `office`), every session unseen (no statement
   logging, `pg_stat_statements` and pgaudit off, D265): the copies as
   at T0; the documents of every signed consultation, released centre
   test and ended stay of the year, numbered in order of their gate and
   reference, their versions; the views and the notices that hang off
   them. It writes `portal` only, the whole outbox included (D404). The
   step is recorded in the scenario's composition record, beside
   `merge.yaml`, with its order (after `vet-core` and `vet-lab`); the
   post-load coherence check then reads every published document
   against a signed consultation, a released result or an ended stay
   ([procedure](domain-procedure.md) 10). Measured at the build (D423),
the same at shift 0 and +2: the keys and `load.sql` 17 to 18 s (21 792
rows, 6 682 bcrypt hashes at cost 6), `derive.sql` 121 s, 77 MB and
about 0.20 million rows in all; through `load-data` in the portal
fixture, the core, the lab, the portal, the owners' state, the purge and
the derivation 603 to 632 s. The partners' database gets the owners' route's key from
`owners`' `data.sql` (D406) and the messaging stub's messages of the
last 14 days, their tokens among them, from `vet-portal-messages`'
history after the derivation (D404). The sessions' purge is scheduled
by `data/cron.sql` (`cron.schedule_in_database('portal', ...)` as
`portal_housekeeping`, nothing else), which `load-data` runs on
`records` after the part's load, once `portal` and its roles exist
(D405).

## Questions for the owner

**Ruled on 2026-11-03** (D320): the owner, "i agree with the
recommendations as a whole", so each is closed as recommended, except
O213: the load computes the sources' keys by functions, and only the
copied content comes from a GM-sanctioned derivation step (D322). No
appointment reminders in v0.5 (D321). Kept as the record of what was
asked.

- **O204 (step 1) The brief.** Accept the proposed brief above: every
  owner has an account to see their current animals' signed
  consultations, released results and discharges, is told when
  something new is there and reminded of vaccinations if they agree;
  information only, no booking, payments or messages to vets.
  *Recommended: yes.*
- **O205 (step 2) What "consents" means.** The owner's consents to
  communications and data use (vaccination reminders; a keeper's access
  to a horse), kept as events like the shop's. Treatment consent forms
  (anaesthesia, surgery, euthanasia) stay out, the core's later.
  *Recommended: yes.*
- **O206 (step 2) Keepers.** Does a livery yard or stable see a horse
  it keeps? *Recommended: only with the owner's consent for that yard
  and that horse, and only while it keeps it.*
- **O207 (step 2) Accounts.** One account per owner, invited
  automatically at registration with a link valid 14 days; contacts
  changed at the desk only; an owner may close the account, which is
  never reopened. *Recommended: yes.*
- **O208 (step 2) What owners see.** Signed consultations (diagnoses,
  prescriptions and withdrawal ends, the vet's name), released lab
  results, discharge summaries; never the vets' free-text notes, alerts,
  imaging (later) or anything from before they owned the animal.
  *Recommended: yes.*
- **O209 (step 2) Notifications.** One notice per new document, by
  e-mail, text or none as the owner chooses, no consent needed;
  vaccination reminders 14 days ahead, only with consent, 08:00–20:00;
  the messaging service accepts each message at once, no bounces in
  v0.5. *Recommended: yes.*
- **O210 (step 2) Where the portal's database lives.** A database
  `portal` on the core's instance (`records`), no new node; or its own
  node, more realistic for an internet-facing system but 0.5 CPU more
  on a tight budget. *Recommended: on `records`.*
- **O211 (step 2) Where the owners' traffic runs.** On the partners'
  shared nodes, out of the players' reach, as "the owners' browsers",
  no new node; or a small node of its own, also out of reach.
  *Recommended: the partners' nodes.*
- **O212 (step 4) Row-level security.** The database itself enforces
  that each owner sees only their animals (PostgreSQL row-level
  security), the API only saying who asks, so the clinic's main
  privacy control is a DBA's matter. *Recommended: yes.*
- **O213 (step 4) The portal's history from the core and the lab.** The
  portal's load reads the core's and the lab's databases through a
  temporary link (as the office's planted reports do) rather than
  recomputing 41 600 documents by formulas. *Recommended: yes; it
  needs the format to let a part's load read its sources, after their
  loads.*
- **O214 (step 5) The portal's rules.** The eleven rules above, with
  their game values; reminders sent only on opt-in consent, though the
  law's existing-customer exception would allow an opt-out.
  *Recommended: as drafted.*
- **O215 (step 7) The purposes.** Two new purposes on the integration
  engine: the release to the portal (the copies and the release gate)
  and the messages (notices and reminders to the franchise's messaging
  service). *Recommended: yes.*

## Changes needed in shared pages

Applied on 2026-11-03 in the fold-in (D320, D323–D325), with these
differences: the purposes are 15 and 16 of sixteen (D324); item 10's
first point becomes the derivation step of D322, its second format
text in procedure 10 (D323, confirmed by D326); item 12's swap is made (D325);
item 14's questions are closed (D320).

1. **[vet-core-domain.md](vet-core-domain.md)**:
   - "Flows to step 7": the row "Results released to owners | to
     `vet-portal` | later, with the portal" becomes "the release to the
     portal | pulled | `vet-portal-release` on `interfaces` | about 140
     documents a day"; add "the portal's notices and reminders | pushed
     | the franchise's messaging service, `vet-portal-messages`".
   - "The applications and their nodes": `pms` carries `vet-portal`'s
     desk fragment, `portal.desk-consent`, an HTTP stream to
     `portal-api` with the desk's credential (a second connection on
     `pms`).
   - "Cadences": the vaccination reminders' line points to `vet-portal`
     (D304 point 6), the due day a function of the animal's id (this
     page, key ranges).
   - "Purposes that fit": add `vet-portal-release`; "Named for later"
     keeps only the referral's electronic report.
   - "The partners the core meets": the messaging service answers
     `vet-portal-messages`' `POST /messages`.
   - "Application roles and grants": `CONNECT` on `clinic` granted to
     the core's login roles by name and revoked from `PUBLIC`, so the
     portal's role, on the same instance, cannot open the record's
     database (this page's rule 10, T253); the same for `office`, its
     roles being the purposes' (clinic-purposes "The roles the purposes
     add").
2. **[vet-lab-domain.md](vet-lab-domain.md)**: "Purposes that fit" adds
   `vet-portal-release`, dropping "named for later"; "Application roles
   and grants", the purposes' roles: `lab_release` (below).
3. **[clinic-purposes.md](clinic-purposes.md)**:
   - section 1: "the release to the portal" drafted in
     [vet-portal-domain.md](vet-portal-domain.md#purposes-that-fit-step-7);
   - section 2: rows 15 `vet-portal-release` (pulled; core, lab,
     portal; every 5 minutes; `interfaces`; `clinic`, `lab` →
     `portal`) and 16 `vet-portal-messages` (first drafted as 11 and 12,
     numbered by D324; pushed; portal; every
     minute, reminders daily 09:00; `interfaces`; `portal` → the
     messaging service's stub); "No flow ... pushed without an answer"
     becomes the notices and reminders, `vet-portal-messages`;
   - section 3: `interfaces` also holds `clinic` as `vet_portal_sync`,
     `lab` as `lab_release`, `portal` as `portal_sync` and
     `portal_dispatch`, and an HTTP connection to the messaging stub;
   - "The roles the purposes add": the four rows of this page's table;
   - "Candidates against the clinic's budget": T270, T272, T256 among
     them (D, V, M by calibration).
4. **[clinic-traps.md](clinic-traps.md)**: a section "The portal",
   T250 to T295 by reference to this page (or copied); its status line's
   count (85 traps) grows by 46.
5. **[clinic-capacity.md](clinic-capacity.md)**: the `vet-portal` row
   becomes "`portal-api`; the `portal` database on `records`; the
   owners' traffic on the partners' nodes | 1 | 0.1 | 96M"; `interfaces`
   at 96M (from 64M); the partners' `api` node serves a tenth hostname,
   `owners` (not a partner), at 128M still (to be measured); the trim
   "the portal's database on `records`" is taken already.
6. **[one-centre.md](one-centre.md) 4**: beside the nine partners'
   hostnames, `owners`, the owners' browsers, out of reach and not a
   partner: not in `partners.md`.
7. **[third-parties.md](third-parties.md) 1**: a line under "It is not
   ... a person": the owners' traffic runs on the partners' nodes for
   reach's sake, the owners staying actors of the story.
8. **[replication.md](replication.md) 1**: `portal` rides the standby
   and the archive with `clinic` and `office`; the standby holds the
   portal's password and token hashes off site.
9. **[brick-options-review.md](brick-options-review.md)**: the TLS row's
   `vet-portal` reach is `portal-api`'s connection to `records`
   (`hostssl`); `pgcrypto` (in PostgreSQL's contrib, shipped with the
   brick's packages) is created in `portal` by its schema.
10. **The format (O111)**, two points: a part's `load.sql` may read its
    sources through a temporary foreign server after their loads
    (O213), as a periodic purpose's `history.sql` does (D307 item 5);
    `producers/partners/<name>/` may hold a traffic source that is not a
    business (`owners`), or a sibling folder takes it
    (`producers/public/owners/`).
11. **The `api` brick** (D267): the portal's API is its first endpoint
    set reached by an out-of-reach caller standing for the public, and
    its `db/` side holds `SECURITY DEFINER` functions and sets a
    transaction-local setting per request; nothing new in the brick,
    but the build's endpoint conventions should allow both.
12. **[clinic-test-selection.md](clinic-test-selection.md)**, a proposed
    swap: **s5 (T78, `lab-api`'s idempotency lookup unindexed) replaced
    by T270 (the portal's policy without the ownership's end), class
    M**, planted a few hours before T0 so only the day's sales are
    exposed. Reasons: the owner-scoped access is "the clinic's richest
    governance case" (D293) and none of the ten covers it, nor
    row-level security, new in the clinic; s5's own growth is not shown
    in v0.5 anyway, and s1 and s4 keep the orders fixture's `api` side
    (its nodes, not their `db/` sides: that side is the `api` brick's
    own build checks', D328);
    T270's fixture is three nodes (`records`, `portal-api`, the
    bastion), its check about 10 minutes (*present*: a planted former
    owner's `GET /animals` returns the horse they sold; *fixed*: after
    the policy's fix it does not, the buyer still sees it). D290's mix
    is unchanged: one D, two V, seven M.
13. **[README.md](README.md)** (v0.5): the documents table gains this
    page; "Next steps" lists its questions O204–O215.
14. **[open-questions.md](../../open-questions.md)**: O204 to O215 as
    listed in "Questions for the owner" above, each "(v0.5) — ...
    Refs: vet-portal-domain.md".

## Cross-part assumptions

Kept to the boundary; none designs another part.

- **`vet-scheduling`**: no booking and no appointment reminder through
  the portal in v0.5 (O204, D321). Were scheduling to send reminders later, it
  would queue them in `portal_outbox` through a purpose of its own.
- **`vet-machinery`**: imaging studies are not released to the portal
  in v0.5 (O208); a study's report would be a fourth document kind,
  published by the same purpose once machinery has a gate for it.
- **`vet-housing`**: none; the displays read the core's board, never the
  portal.
- **`vet-lab`**: a centre result's gate is `lab_order_tests.released_at`
  of account 1, amendments `lab_results.supersedes_id`; the lab's tables
  unchanged, one read-only role added.
- **`vet-core`**: every owner has an e-mail (the core's load and
  `owners.register`); owners' contacts change only at the desk; the
  sync's watermarks are the core's own columns (`registered_at`,
  `from_at`, `until_at`, `died_at`, `signed_at`, `discharged_at`); no
  core table changes.
