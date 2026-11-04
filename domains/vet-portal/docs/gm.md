# The vet-portal domain: GM notes

The owners' portal of the centre a scenario deploys, a part of
`vet-core` (v0.5 master spec 9.7;
[vet-portal-domain.md](../../../specs/versions/v0.5/vet-portal-domain.md)):
the business, the keys it uses and its own, its data, who may see what
and how the database enforces it, its producers, and the traps it holds.
A design-time source: copy its files into a scenario and adapt them
there; the domain itself never changes for a scenario. The portal is
taken only with its core; it refers to the core's and the lab's keys by
id with no foreign key. Its load computes the core's keys by the core's
functions, never reading `clinic`; its copies and documents come from
its derivation, which reads `clinic` and `lab` once, after their loads.

| File | Copied to | What |
|---|---|---|
| [`data/schema.sql`](../data/schema.sql) | loaded by `gmctl load-data` into the portal's `domains:` `at:` database (`portal` on `records`, D320) | three roles, ten `portal_` tables under forced row-level security, their policies, the API's `SECURITY DEFINER` functions, grants; `CONNECT` by name; the database's logging settings; `pgcrypto` |
| [`data/keys.sql`](../data/keys.sql) | streamed by `load-data` after the core's keys, ahead of this part's load, the owners' `data.sql` and the derivation | the part's key functions, `pg_temp.portal_*` ("Part keys", below) |
| [`data/load.sql`](../data/load.sql) | after `schema.sql`, in the same database | last night's backup: accounts, consent events, sessions, from the key functions |
| [`data/derive.sql`](../data/derive.sql) | run by `load-data` after the core's and the lab's loads, when `composition.yaml` sanctions it (`derive:`) | the copies, the documents, the views and the whole outbox, copied from `clinic` and `lab` |
| [`data/cron.sql`](../data/cron.sql) | run by `load-data` on `records` after the part's load (D405) | the sessions' purge, `portal.sessions.purge`, as `portal_housekeeping` |
| [`data/coherence.yaml`](../data/coherence.yaml) | run by `load-data` after the loads and the derivation | six checks: the core's keys, the copies at T0, the records' and the results' gates, every gate published, the outbox's order |
| [`data/classification.yaml`](../data/classification.yaml) | where `governance.classification` names it | the class of every column |
| [`data/register.yaml`](../data/register.yaml) | the scenario's data register (chunks 17, 27) | the processing activities, every table in one |
| [`data/governance.yaml`](../data/governance.yaml), [`policy.md`](policy.md) | the scenario's `governance:` and `player/data-policy.md`, beside the core's and the lab's | the eleven rules, where each class may live, the outbound flow to the messaging service |
| [`producers/api/portal-api/`](../producers/api/portal-api/) | the portal's API node (`nodes/portal-api/`), by compose | the six endpoints ("The producers", below) |
| [`producers/pms/`](../producers/pms/) | the practice software's node, by compose | the desk's consent stream, `portal.desk-consent` |
| [`producers/partners/owners/`](../producers/partners/owners/) | `partners-db`'s data and the partners' back end and `api` node | `data.sql` (the role and schema `owners`, the key, the owners' logins, the record of visits); the owners' route: `api.yaml`, `routes/`, `db/` onto `partners-api`, `schedule.yaml`, `queries.yaml` onto `partners-backend` |
| [`variants/regional-franchise.yaml`](../variants/regional-franchise.yaml) | read by compose | the portal's axes in the core's variant |

## The business

A hospital's client portal of the kind practice-software vendors sell:
every owner of the centre's record has an account showing the animals
they own now and what the centre released about them (signed
consultations, the centre's released lab results, discharge summaries);
it notifies them of each new document, reminds them of vaccinations if
they consented, through the franchise's messaging service, and keeps
every consent event and what was released, notified and opened.
Information only: no booking, no appointment reminder, no payment, no
message to a vet, no imaging. Reachable from the internet, it is the
centre's most exposed system holding owners' data, and its owner scope,
enforced by the database's row-level security, is the clinic's richest
governance case (D293).

## Core keys used

The load computes the core's keys by the core's own functions (vet-core
[GM notes](../../vet-core/docs/gm.md#core-keys), D249), streamed ahead
of it:

| Core function | What the portal takes |
|---|---|
| `core_owner(n, load_epoch, utc_offset)`, `n` 2–10 000 | each account's kind, name, e-mail and phone, and the owner's `registered_at` (the invitation five minutes after) |
| `core_ownership(n, ...)`, horses 14 609–16 000 | the current owner and keeper of each kept horse, for the planted `keeper-access` events |

The derivation reads the rest from the loaded record and lab, never
recomputing it (D322): the copies (`animals`, `ownerships`, `herds`),
the signed consultations with their diagnoses and prescriptions, the
ended stays, the staff's names; the lab's released tests of account 1
with their results, analytes and intervals. Owner 1, the clinic, has no
account; the teaching animals (1–12, 14 601–14 608) get no reminder. The
portal calls only the core's eighteen `pg_temp.core_*` functions, never
its `pg_temp.vc_*`.

## Part keys

`data/keys.sql` holds `pg_temp.portal_*` only (W3 item 0), every
function `IMMUTABLE`, taking `load_epoch` and `utc_offset` where it
computes a time, every draw a hash of an id (`portal_u`, salts 7 301 to
7 399), never `random()`. To use them by hand: `\i` the core's
`keys.sql`, then this one, in a `psql` session as `postgres`.

### The ranges

| Key | Range | Layout |
|---|---|---|
| `portal_accounts.id` | 2–10 000, the sequence at 20 000 | account `o` is owner `o` (migrated from the old portal); accounts created in play take 20 001 on, so a join of an account's id to an owner's id is right for every loaded account and wrong for every new one (T261) |
| `portal_consent_events.id` | 1–about 7 300 | in time order |
| `portal_sessions.id` | 39 301–about 43 800 | the last 30 days' only, after the year's earlier sessions (purged) |
| `portal_documents.id` | 1–about 40 000 | the derivation's, by gate time, `source_ref`, version |
| `portal_views.id` | 1–about 66 500 | the derivation's, in time order |
| `portal_outbox.id` | 1–about 39 000 | the derivation's, by `queued_at`, ties by `message_key` (W3 item 5) |
| a vaccination's due day | `portal_due_on(animal, year)` | day of the year `1 + (animal_id × 211) mod 365`, domestic animals and horses |

### The key, the passwords, the links (D406)

`portal_key(load_epoch)` is `encode(sha256(convert_to('vet-portal ' ||
load_epoch, 'UTF8')), 'hex')`, `load_epoch` as `load-data` passes it
(`2026-11-04T08:50Z`). Account `n`'s password is `portal_password(n,
load_epoch)`, the HMAC-SHA256 of `n` under the key, in hex; a planted
one-time link's token is `portal_token(template, n, load_epoch)`, the
HMAC of `'<template>:<n>'` (`invitation`, `password-reset`); a planted
session's token the HMAC of `'session-<rank>:<n>'`, its rank among the
account's planted sessions, oldest first. `portal_hmac` is built from
`sha256()` alone, equal to pgcrypto's `encode(hmac(msg, key, 'sha256'),
'hex')` (checked at the build), so the partners' database needs no
extension. The load stores the bcrypt hash of each active account's
password (cost 6, a deterministic salt, `portal_bcrypt_salt`) and the
SHA-256 of each open link's token; the key's only copy is `owners`'
(`owners.settings`, `password_key`). Tokens made in play (logins,
resets, invitations by purpose 15) are random. **Known limit**: the key
follows from T0, so it guards nothing from a reader of these notes; no
player sees the formula.

### `portal_account(n, load_epoch, utc_offset)`

Account `n` as the load leaves it, returning the core owner's `kind`,
`display_name`, `email`, `phone` and the account's `status`,
`invited_at`, `activated_at`, `closed_at`, `open_template` and
`open_sent_at` (the open one-time link), `notify_by`, `consent_at`,
`failed_logins`:

- invited five minutes after the owner's registration;
- the activation delay `portal_activation_delay(n)`: none for
  `portal_u(n, 2) < 0.3` (three in ten never activate), else
  `portal_u(n, 3) × 3 days`; active once it has passed;
- closed for `portal_u(n, 1) < 0.03` when invited over 14 days before
  T0, at `start + (T0 − start) × (0.1 + 0.85 × u₄)` from its activation
  (or invitation);
- the open link: an invited account invited in the last 14 days holds
  its invitation's; an older invited one, for `u₅ < 0.035`, a
  `password-reset`'s sent in the last 14 days (the renewal), the
  `invite_hash` column holding either (the schema's one link slot);
- `notify_by` `email`, `sms` for `0.80 ≤ u₇ < 0.95` and `none` above,
  people only;
- the reminders' consent granted at activation for `u₈ < 0.86`;
- `failed_logins` 1 to 3 for one active account in 500.

At the reference T0: 6 682 active, 3 018 invited (193 open links), 299
closed.

### `portal_resets(n, load_epoch, utc_offset)`

An account's password resets over the year, `rank` in time order: one
for `u₁₁ < 0.20`, a second for `u₁₁ < 0.03`, between its activation (or
the year's start) and its closure (or T0), each used within the hour;
plus an invited account's renewal (unused). The derivation queues one
`password-reset` message each (about 1 600).

## The data

The load writes the settings, the accounts, the consent events (the
activation's grants; one later change for 15 % of the accounts ever
active, by a reminder's link, the portal or the desk; the stables'
`keeper-access` grants by two current owners in three, one in twelve
withdrawn since) with the `reminders` flag set from the latest event,
and the last 30 days' sessions (9.26 an hour times the owners' day's
weight, by active accounts; half logged out, the others idle, the last
12 hours' open). The derivation writes the rest:

- **the copies** as the core holds them at T0: 17 000 animals, every
  ownership row (about 18 600), 200 herds;
- **the documents**: each signed consultation (`C-<id>`), ended stay
  (`S-<id>`) and released test of account 1 (`T-<id>`) of the year,
  published five to ten minutes after its gate (purpose 15's cadence),
  those published by T0; an amendment after the release a new version
  (the values then in force), the former superseded; bodies without
  free text (diagnoses' labels and codes, the prescriptions with their
  withdrawal ends; the analytes with values, flags and intervals and the
  performing lab; the stay's dates and outcome);
- **the views**: each document opened one to four times by nearly every
  account that saw it (the owner at publication, the record within the
  ownership; a granted keeper; a herd's keeper; active then), never
  after T0, the closure or the ownership's end;
- **the outbox**: invitations (the year's accounts), resets, closures,
  the notices of the documents (one per document and account that saw
  it, its channel not `none`) and the reminders (09:00 local 14 days
  before each due day, the animal alive, its owner's account active,
  the latest `reminders` event a grant); sent within the minute, one in
  fifty after a 503 retried with the same key, the last two minutes'
  unsent; `message_key` `md5('<template>:<account>:<reference>')::uuid`
  (reference `1`, the reset's rank, the document's id, or
  `<animal>:<due on>`), a sent row's `provider_id`
  `md5('messaging:' ‖ message_key)::uuid`.

At the reference T0 (`load_epoch` 2026-11-04T08:50Z, shift 0, a
Wednesday morning before the reminders' queue):

| Table | Rows | The document's |
|---|---|---|
| `portal_accounts` | 9 999 (6 682 active, 3 018 invited, 299 closed; 5 087 with the reminders' consent) | 9 999 (6 500, 3 200, 300; 5 200) |
| `portal_consent_events` | 7 285 (232 keeper grants in force) | 8 000 (250) |
| `portal_sessions` | 4 507 (15 open) | 4 500 |
| `portal_animals`, `portal_ownerships`, `portal_herds` | 17 000, 18 569, 200 | 17 000, 20 000, 200 |
| `portal_documents` | 40 028: 24 585 consultations, 13 065 results (497 later versions), 2 378 discharges | 41 600 (25 000, 13 600, 400, 2 300) |
| `portal_views` | 66 533 | 70 000 |
| `portal_outbox` | 38 889: 26 448 notices, 6 675 reminders, 4 000 invitations, 1 633 resets, 133 closures | 36 000 (23 000, 8 000, 3 800, 1 500) |

## The roles (vet-portal-domain.md, "Application roles and grants")

| Role | Login | What |
|---|---|---|
| `portal` | no | owns every table and function, `BYPASSRLS`, so its `SECURITY DEFINER` functions reach every row; nobody logs in as it |
| `portal_api` | yes | `portal-api`'s role: `SELECT` on the settings, the copies and the documents, on its account's columns but the hashes; `UPDATE (notify_by, reminders)` on accounts; `SELECT, INSERT` on consent events; `INSERT` on views; `EXECUTE` on the functions; no grant on sessions and the outbox; everything through the policies |
| `portal_housekeeping` | yes (pg_cron runs a job only as a login role with `CONNECT`) | `SELECT, DELETE` on the sessions, through `portal_sessions_purge` |

`CONNECT` on `portal` is granted by name and revoked from `PUBLIC`. The
purposes' roles (`portal_sync`, `portal_dispatch`) and their policies
(`USING (true)`) are purposes 15's and 16's (chunk 21), as is the `ops`
schema.

## Who sees what: the row-level security (W3 item 5, W3-e)

Row-level security is enabled and forced on all ten tables. The asker is
`NULLIF(current_setting('portal.owner_id', true), '')::integer`, inline
in each policy: unset, no row. `portal-api` sets it with
`set_config('portal.owner_id', <owner id>, true)` first in each
request's transaction, after `portal_session(token)` returned the
account and its owner; `gm_api` rolls it back with the request.

| Policy | On, for | Rule |
|---|---|---|
| `portal_settings_scope` | settings, `portal_api`, `SELECT` | every row |
| `portal_accounts_scope` | accounts, `portal_api`, all | `owner_id` the asker's |
| `portal_animals_scope` | animals, `portal_api`, `SELECT` | the asker's current `owner` ownership (`until_at IS NULL`, T270 drops it); or the asker's current `keeper` ownership (`until_at IS NULL`) and `portal_keeper_granted(animal, asker)` |
| `portal_ownerships_scope` | ownerships, `portal_api`, `SELECT` | the asker's own rows |
| `portal_herds_scope` | herds, `portal_api`, `SELECT` | the asker the keeper |
| `portal_documents_scope` | documents, `portal_api`, `SELECT` | the animal visible through `portal_animals` (its policy applying) and `record_at >= portal_owner_since(animal)` (T271 drops it); a herd's, visible through `portal_herds` |
| `portal_consent_events_scope` | consent events, `portal_api`, all | the asker's own; an insert as the asker, a `keeper-access` event only for an animal the asker owns now |
| `portal_views_scope` | views, `portal_api`, `INSERT` | the asker's account, a document the asker sees |
| `portal_sessions_purge` | sessions, `portal_housekeeping`, all | `coalesce(ended_at, expires_at)` over 30 days ago |

The outbox has no policy for `portal_api`; neither table has a grant.

**The keeper's clause, settled here (W3-e).** The animals' policy needs
the current owner's latest `keeper-access` event for the keeper and the
animal, and the documents' policy the current owner's ownership start;
both rows are hidden from a keeper by the own-rows policies. Two pinned
`SECURITY DEFINER` helpers owned by `portal` read them:
`portal_keeper_granted(animal, keeper)` (the current owner's latest
event for that keeper and animal is a grant; false when none) and
`portal_owner_since(animal)` (the current owner's `from_at`), both
`STABLE`, `search_path = public, pg_temp`, executable by `portal_api`
only. The consent events' policy stays the asker's own. So T274 bites in
two places: the withdrawal in `portal_keeper_granted`, the keeping's end
(`k.until_at IS NULL`) in `portal_animals_scope`; T275's index is
`portal_consent_events_keeper_idx (animal_id, keeper_id, at)`, which the
helper's lookup uses.

**Reading `portal` as the GM.** `gm_check` holds `pg_read_all_data`,
which does not bypass row-level security: through a foreign schema it
reads no row of a portal table. The coherence check runs in `portal` as
`postgres` (a superuser, never subject to it); a history or check that
reads `portal` through `gm_src_*` (purpose 16's, reading
`portal_outbox`'s sent rows, chunk 21) needs a policy for `gm_check` on
the tables it reads, which that purpose's `ddl:` can create.

## The functions (the API's `db/` side, D271)

Owned by `portal`, `SECURITY DEFINER`, `search_path` pinned (T255):

| Function | Returns | What |
|---|---|---|
| `portal_login(email, password)` | `(result, token)` | an active account by its e-mail (case-blind): `ok` and a new session's token; `wrong` (401) for no such account or a wrong password, the failures counted; `locked` (423) while `locked_until` is ahead, the fifth failure locking for 30 minutes; a success resets the failures (T279) |
| `portal_session(token)` | `(account_id, owner_id)` | while the session is open, seen within 30 minutes and under 12 hours (T276), the account active; an idle or expired session is ended as such and yields nothing |
| `portal_logout(token)` | boolean | the session ended (`logout`); a function, since the sessions have no grant |
| `portal_activate(token, password, reminders)` | the account's id, or null | an invited account's unexpired link, used once (T282): the password (bcrypt, cost 6, T278), `active`, the reminders' consent granted when asked (an `activation` event) |
| `portal_request_reset(email)` | nothing | a new one-time link and a `password-reset` message to the account's own address; nothing for an unknown or closed address, answered the same |
| `portal_reset(token, password)` | boolean | the link used once, unexpired: the password set, the lock cleared, an invited account (its invitation renewed) made active |
| `portal_unsubscribe(message_key)` | boolean | a reminder's key: the reminders withdrawn (`message-link`), the flag cleared |
| `portal_close()` | boolean | the asker's active account: a closure message, its personal columns erased, its sessions ended (`closure`, T281), the consent events kept |
| `portal_desk_consent(owner_id, purpose, granted)` | boolean | the reminders' consent from the desk (`desk`), the flag beside it; false for another purpose or no open account |

## The classification

v0.4's three classes, read as `vet-core` reads them (D280), every column
not listed `internal`: the accounts' identity, contacts and hashes, the
session tokens' hashes, a document's vet's name and the outbox's
address, payload and ids `personal`; the other owners', animals' and
herds' ids `customer-linked`; a document's body `internal` (master spec
9.7). [`data/classification.yaml`](../data/classification.yaml) holds
the list.

## The producers

### `portal-api` (`producers/api/portal-api/`, W3 item 5)

An `api` node in the players' scope, hostname `portal-api`, connection
`portal` (`records:5432/portal` as `portal_api`, pool 4, over TLS: the
seed's `hostssl portal portal_api`, plain refused). Every endpoint is
public at the brick but `desk` (credential `portal_desk`): an owner is
known by the cookie `portal_session`, never `Authorization` (`gm_api`'s
client refuses to set it, so the owners' route sends a cookie as a browser
does). Each request is one transaction: an owner endpoint's `db/` side
calls `portal_session(token)` first (an idle or expired session ended and
committed, then 401), then `set_config('portal.owner_id', <owner>,
true)`; its queries carry no owner filter, the policies do. Times in JSON
are UTC with `Z`.

| Endpoint | Route | Answers |
|---|---|---|
| `session` | `POST /login {email, password}` | 201 `{token}` and `Set-Cookie: portal_session=<token>; HttpOnly; Path=/; SameSite=strict`; 401 wrong e-mail or password; 423 locked |
| | `POST /logout` | 204, the cookie cleared; 401 no open session |
| `me` | `GET /me` | 200 the account (`account_id`, `owner_id`, `kind`, `display_name`, `email`, `phone`, `status`, `notify_by`, `reminders`, `invited_at`, `activated_at`, `last_login_at`) and `consents`, the latest event of each purpose, animal and keeper; 401 |
| | `PUT /me/preferences {notify_by}` | 200 the account; 401; 422 a channel not `email`, `sms`, `none` |
| | `POST /me/consents {purpose, granted, animal_id, keeper_id}` | 201 the event (source `portal`), the `reminders` flag beside a reminders' one; 403 `keeper-access` for an animal not owned now (the policy's `WITH CHECK`); 422 a malformed pair; 401 |
| | `POST /me/close` | 200 `{closed: true}`, the cookie cleared (`portal_close`); 401 |
| `animals` | `GET /animals` | 200 `[{animal_id, name, species, sex, born_on, status}]` by `animal_id`; 401 |
| | `GET /animals/{id}/documents` | 200 `[{document_id, kind, title, version, record_at, published_at, superseded_at}]`, newest first by `record_at`, 50 at most, superseded versions included; 404 an animal the asker does not see; 401 |
| `documents` | `GET /documents/{id}` | 200 the document (`document_id`, `animal_id`, `herd_id`, `kind`, `source_ref`, `version`, `record_at`, `gated_at`, `published_at`, `title`, `vet_name`, `body`, `supersedes_id`, `superseded_at`), its `portal_views` row (`open`) in the same transaction; 404 one the asker does not see, another owner's among them; 401 |
| `accounts` | `POST /accounts/activate {token, password, reminders}` | 200 `{account_id}` (`portal_activate`); 401 a link unknown, used or expired; 422 a password under 8 characters |
| | `POST /password-reset {email}` | 202 whatever the address (`portal_request_reset`) |
| | `POST /password-reset/{token} {password}` | 200 `{reset: true}` (`portal_reset`); 401 |
| | `POST /unsubscribe/{message_key}` | 200 `{unsubscribed: true}` (`portal_unsubscribe`); 404 another key; 422 not a UUID |
| `desk` | `POST /desk/consents {owner_id, purpose, granted}` | 201 `{recorded: true}` (`portal_desk_consent`); 422 refused (another purpose, a closed account); 401 without `portal_desk` (the brick) |

Herds' documents have no listing route: a herd's keeper opens one by its
id (`GET /documents/{id}`).

### The desk (`producers/pms/`)

On the practice software, beside the core's `clinic`: the HTTP
connection `portal` (`portal-api:8000`, credential `portal_desk`, pool 1)
and the stream `portal.desk-consent` (0.28/h, Poisson, the core's
`clinic-day`, about three a weekday): `POST /desk/consents` for an owner
drawn from 2 to 10 000, `reminders`, granted two times in three. A closed
account's owner (about one call in thirty) answers 422, an error counted
in `pms`' log. The shape is the core's, named only.

### The owners' traffic (`producers/partners/owners/`, D369)

The owners' browsers, no third party: prefix and hostname `owners` on the
partners' `api` node, no `partners.md` entry, no contract, no
misbehaviour key (no `owners.state`, no `owners.normal`; master spec
10.2). One endpoint, `owners_tick` (`POST /tick {kind}`, credential
`partners_backend`), ticked by six streams on the back end (connection
`owners-tick`, `owners:8000`), at intensity 1.0 on `owners-day`:

| Key | Rate | What one tick does |
|---|---|---|
| `owners.visit` | 9.3/h, Poisson | an active account (70 % among the last day's recipients in the messaging stub's record when it exists, else at random): one in 50 first tries a past session's token (`session-1`, a bookmarked link, 401), one in 300 mistypes five times (locked, 423), one in 25 once; logs in, lists its animals, opens one animal's documents and one or two of them (1.6 on average); one in ten reads `GET /me` and changes its channel or its reminders' consent; logs out half the time |
| `owners.activate` | 4/h, even (a capacity) | the oldest planted invitation whose activation delay has passed (`owners.accounts`' `activates_at`), else one made in play from the messaging stub (its link's token; 0 to 3 days by a hash of the id, three in ten never): `POST /accounts/activate` with the account's password, the reminders granted by 80 % |
| `owners.reset` | 0.31/h, Poisson | a reset asked earlier used through its message's token (the messaging stub), then an active account asks a new one |
| `owners.unsubscribe` | 2/h, even (a capacity) | a reminder received 3 hours to 14 days ago, one in twenty by a hash of its key, withdrawn by its link (the messaging stub) |
| `owners.keeper` | 0.08/h, Poisson | a horse owner (302–901) grants (three in four) or withdraws a keeper's access named in its consents |
| `owners.close` | 0.015/h, Poisson | an active account closed (`POST /me/close`) |

Connections on `partners-api`: `owners-db` (`partners-db:5432/partners`
as `owners`, pool 2) and `owners-portal` (`portal-api:8000`, no
credential, pool 2). A tick reads what it needs in one short transaction,
makes its calls holding no database session, then writes every call to
`owners.visits (id, at, account_id, call, status, animal_ids,
document_ids)`, `call` the route's pattern (`GET /animals/{id}/documents`),
RL6's evidence (chunk 21). Its state, in `owners`' `data.sql`:
`owners.settings` (`password_key`, the key's one copy) and
`owners.accounts (account_id, email, status, link, activates_at)`, the
load's open accounts as each browser remembers its own login (the route
cannot read `portal`, and an address is a hash of the core's), updated by
its own activations and closures. Without the messaging stub (until chunk
21) the resets are asked and never used, and no unsubscribe is sent.
`PUT /me/preferences` goes through the client's own request path, since
`gm_api`'s client offers only `get()` and `post()`.

## The rules

The eleven of [`policy.md`](policy.md) (master spec 9.7): owner scope by
row-level security; the release gate within 15 minutes; least data;
accounts (14-day links, bcrypt cost 6, five failures lock for 30
minutes, sessions 30 minutes idle and 12 hours at most, tokens hashed);
closing; consents (the latest event the truth, reminders on opt-in);
messages through the messaging service only; audit; no statement
logging on `portal` (`schema.sql` sets `log_statement = none`, no
parameters in the log, `pgaudit.log_parameter = off`, as database
settings: T250 and T251 change them); reach (`portal_api` on `portal`
only, over `hostssl`: the seed's `pg_hba.conf`); retention.

## Growth

About 720 new rows a day at intensity 1.0 (140 documents, 240 views, 120
messages, 150 sessions, 11 consent events, 13 accounts), 0.3 MB with
indexes; about 60 an evening hour, 10 a night hour. The sessions' purge
keeps 30 days. The partners' database grows by about 300 rows a day for
the portal (the visits recorded, the messages received).

## The traps

T250 to T295 ([vet-portal-domain.md](../../../specs/versions/v0.5/vet-portal-domain.md#traps-step-8)),
where each bites in this build:

- **Reach and settings** (T250–T255): the database settings in
  `schema.sql`; `pg_hba.conf` (`hostssl portal portal_api`); `CONNECT`
  revoked on `clinic` and `office`; `cron.sql`'s
  `schedule_in_database('portal', ...)`; every function's pinned path.
- **Who sees what** (T270–T275): the policies above by name; T270 edits
  `portal_animals_scope`, T271 `portal_documents_scope`, T272 the
  tables' owner or `FORCE`, T273 drops `portal_documents_scope`, T274
  `portal_keeper_granted` or the animals' policy, T275 drops
  `portal_consent_events_keeper_idx`.
- **Accounts and sessions** (T276–T282): the functions above.
- **The copies, the release and the messages** (T256–T269, T283–T293,
  T295): purposes 15 and 16 (chunk 21); the uniques they rely on are
  here (`portal_ownerships_current_owner_idx`, T262;
  `portal_outbox_notice_idx`, `portal_outbox_reminder_idx`, T288).
- **Performance** (T294): `portal_documents_animal_idx (animal_id,
  record_at DESC)`.

## Loading

`gmctl load-data` runs `schema.sql` then the core's `keys.sql`, this
part's `keys.sql` and `load.sql` into `portal` on `records` as
`postgres`, in one session; then the owners' `data.sql` into `partners`
on the partners' database node, the two key files ahead; then
`cron.sql` on `records` (D405). After every domain's load (and the
purposes' `ddl:`), the derivation: `derive.sql`, the two key files
ahead, in `portal`, `clinic` and `lab` reachable as `gm_src_vet_core`
and `gm_src_vet_lab`, as the composition record's `derive: [{domain:
vet-portal, after: [vet-core, vet-lab]}]` sanctions it. Then the
coherence check. Every session is unseen (D265). Measured on 2026-11-04
in a throwaway container of `postgres:0.5.0` on armenelos, the keys
streamed and the foreign schemas created by hand as `load-data` does:

| Run (`load_epoch` 08:50 local) | Time | Size | Rows |
|---|---|---|---|
| the keys and `load.sql`, shift 0 (`2026-11-04T08:50Z`) | 18 s | | 21 792 |
| `derive.sql`, shift 0 | 134 to 142 s | 78 MB with the load | 241 900 in all |
| the keys and `load.sql`, offset +2 (`2026-11-04T06:50Z`) | 19 s | | 21 792 |
| `derive.sql`, offset +2 | 130 s | 78 MB with the load | 241 900 in all |

The figures are the same at both shifts (the hashes are of ids, the
times local). The coherence check's six queries returned no row at
both (the slowest, `gates-published` and `records-gated`, about 4 s);
`results-gated` caught a document's gate moved by an hour. The core's
and the lab's loads ahead took 94 to 104 s and 64 to 70 s.
