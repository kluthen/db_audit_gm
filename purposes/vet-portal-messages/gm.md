# vet-portal-messages — GM notes

Purpose 16 of v0.5 (master spec 12.2; v0.5's `vet-portal-domain.md`,
"`vet-portal-messages`: notices and reminders to the messaging service";
capture W4 items 0, 6 and 7; spec D404): **pushed** (v0.4's P3, customer
mailing) to a third party, the franchise's messaging service (a processor),
with a transactional part (invitations, resets, closures, document
notices) and a consent-bound one (vaccination reminders).

## What it is for

| Job | When (scenario time) | How | What |
|---|---|---|---|
| `queue-notices` | `*/5 * * * *` | script `scripts/portal_messages.py:queue_notices`, `portal` as `portal_dispatch` | the documents published since the watermark `notices`: one `document-notice` for each account that sees it (its animal's current owner, the record within the ownership; a keeper the owner grants access now; a herd's keeper), active, channel not `none`; key `md5('document-notice:<account>:<document>')`, as the derivation's; payload template, the recipient's name, the animal's name (or `herd <id>`), the document's link; once per document and account |
| `queue-reminders` | `0 9 * * *` | `:queue_reminders` | the dogs, cats, rabbits, ferrets and horses (option `species`) alive in the copy whose yearly due day (day 1 + (id × 211) mod 365, the load's) is today plus `reminder_lead_days` (14), whose current owner's account is not closed and whose latest `reminders` event is a grant: one `reminder` per animal and due day, by sms when the account's channel is sms, else e-mail; payload with the withdrawal link `unsubscribe/<message key>` |
| `send-messages` | `* * * * *` | `:send_messages`, `messaging` (`messaging:8000`, `messaging_customer`, 5 s) too | the unsent rows, oldest first, at most `batch` (100), reminders only within `reminders_from`–`reminders_until` local; a reminder checked again at sending time (account not closed, animal alive, its owner still the account's, consent a grant), any message to a closed account but the closure itself likewise: such a row is **stopped**, `failed_at` with `last_status` the reason (`consent-withdrawn`, `animal-died`, `owner-changed`, `account-closed`), no incident; the others posted with their `message_key`: 202 `provider_id` and `sent_at`; otherwise the attempt counted, its status kept, retried next minute with the same key; at the sixth `failed_at` and one `ops.incidents` row (`failed`, ref the key). The calls hold no transaction; one `portal` transaction writes the results and the run's row |

The messaging service's stub answers 202 with its id
(`md5('messaging:' ‖ message_key)`, the derivation's `provider_id`), the
same key again the same id, never a second message; one call in fifty 503
(its state `fail_one_in`), the retries' witness.

## What the material holds

- `material/source/ddl.sql` (`portal`): the `ops` schema, `portal_dispatch`,
  its grants and policies `<table>_dispatch` (`SELECT` `USING (true)` on
  what it reads, `ALL` on the outbox), the watermark `notices` at
  `load_epoch`. **Beyond the list** (reported, W4-e): the accounts' `id`,
  `owner_id` and `display_name` (the outbox names the account and the
  payload the recipient's name, as the derivation writes them).
- `material/partner/messaging/`: the stub, prefix and hostname `messaging`,
  laid out as `producers/partners/<prefix>/`: `api.yaml` (endpoint
  `messaging_messages`, `messaging_customer`), `routes/` and `db/` into
  `compose/partners-api/`; `queries.yaml` and `schedule.yaml` (the baseline
  `messaging.normal`) into `compose/partners-backend/`; `data.sql`
  (`messaging.state`, `messaging.calls`, `messaging.messages`,
  `messaging.message_calls`) after `partners/shared/partners-db/data.sql`
  in `partners-db`'s data file.
- `material/history.sql`: run in `partners` after the derivation, reading
  `portal` as `gm_src_source` (through `gm_check_read`; it fails the load
  when it reads no outbox row): the last 14 days' sent outbox rows as the
  stub received them (`received_at` = `sent_at`), then `SELECT` on
  `messaging.messages` to `owners` (the owners' route reads the tokens of
  invitations and resets, the reminders' keys and the recent recipients;
  with the stub, resets are used and unsubscribes sent).
- `material/runner/`: `jobs.yaml`, `queries.yaml`, `schedule.yaml`
  (connections `portal-dispatch` and `messaging`), `scripts/portal_messages.py`.

Mapping: `source` `portal`, `target` the partners' database (the history
only), `runner` the integration engine, `partner` the partners' api node.
The scenario lists the messaging service in `third_parties:` with the
partners' three nodes, hostname `messaging`.

## How it goes wrong

The unique notices and reminders dropped or a retry under a new key (MS1),
the consent read from the flag or not at sending time (MS2), the hours in
UTC (MS3), a payload carrying a result, a diagnosis or a password (MS4),
the watermark skipping documents or the incidents never written (MS5), a
reminder to a seller or for a dead animal, a message to a closed account
(MS6).

## The checks

Every check reads `portal` as `gm_check`, through the `gm_check_read`
policies (step (2c)); each first finds them in place on every table it
reads, else exits 2, "cannot judge" (spec D432). MS2 to MS6 run on the
runner node (`interfaces`), the judged moment `CHECK_SINCE` raised to the
runner's last reload; MS1 runs on the partners' database node, reading the
stub's record there and the portal through `check-psql --node`.
