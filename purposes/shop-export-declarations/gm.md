# P5, export declarations: GM notes

The shipping manager's declarations of export orders to the customs
gateway (master spec 10.4). A pushed obligation (8.2): a **trigger** in
the data (an order packed for a country in `export_countries`), a
**deadline** (two hours from `packed_at`), an **outside receiver** the
company does not run (the gateway), and an **acknowledgement** (a
movement reference, or a rejection), or an escalation when none comes. A
design-time source: copy the material into a scenario and adapt the names
there.

## What it is for

Every order shipped outside the customs union must be declared before it
leaves. The shop sends each declaration once, keyed by the order (the
idempotency key), with the gateway's schema and nothing more: consignee
name and address may go, the e-mail and the customer id may not. The
gateway answers within a minute. A declaration left unanswered for 30
minutes, or rejected, becomes an `incidents` row for the shipping
manager. That is all v0.4 does with an answer: it records it and checks
it; nothing waits on it, nothing is resubmitted.

## The material

| File | Copied to | What |
|---|---|---|
| [`material/runner/queries.yaml`](material/runner/queries.yaml) | the runner's `queries.yaml` (`nodes/crm/`) | `declare.exports`, `escalate.customs`, one statement each |
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml) | the runner's `jobs.yaml` | `declare-exports` at `*/5 * * * *`, `escalate-customs` at `*/15 * * * *` |
| [`material/runner/schedule.yaml`](material/runner/schedule.yaml) | the runner's `schedule.yaml` | the connection `shop_customs` (`db:5432/shop` as `shop_customs`), no stream |
| [`material/receiver/queries.yaml`](material/receiver/queries.yaml) | the gateway stub's `queries.yaml` (`nodes/gateway/`) | `customs.acknowledge`, one statement |
| [`material/receiver/schedule.yaml`](material/receiver/schedule.yaml) | the gateway stub's `schedule.yaml` | the connection `customs` (`db:5432/shop` as `customs_gw`), the stream `customs.acknowledge`, 4/min, even |

No source material: `domains/shop` creates the customs tables,
`incidents`, `etl_runs`, `shop_customs` and `customs_gw` with their
grants. The gateway stub is a `scheduler` 0.2.0 node of role `producer`,
report-only (16.1), with no `jobs.yaml` entry; its `intensity` and its
`timeline` (the outage, rejection spells) are the scenario's.

**Names to adapt** when copying: `db`/`shop` (both connections; `DB` in
each check), the runner `crm`, the receiver `gateway`, the job names
(`JOB` in E2, E3).

## The jobs

- **`declare-exports`**, as `shop_customs`: the orders packed in the last
  two hours (an order packed earlier is overdue already; the job never
  backfills the load's history, whose outbox starts empty) whose
  `ship_country` is in `export_countries` and with no `customs_outbox`
  row, one row each: `payload` the gateway's schema (below), `sent_at` the
  run's `now()`, `idempotency_key` `export-<order id>` (unique), and one
  `etl_runs` row.
- **`escalate-customs`**, as `shop_customs`: the declarations of the last
  day with no acknowledgement received within 30 minutes of sending, or
  with a rejection, and no incident yet: one `incidents` row each
  (`source` `customs`, `ref` the declaration's id, `opened_at` the run's
  `now()`, `reason` `no acknowledgement 30 minutes after sending` or
  `rejected by the gateway: <reason>`), and one `etl_runs` row. At a
  quarter-hour cadence, an unanswered declaration's incident comes 30 to
  45 minutes after sending.

**The `etl_runs` columns** each job fills: `job` its name; `started_at`
the run's `now()` (every row's time); `finished_at` `clock_timestamp()`
once the rows to write are read; `rows_read` and `rows_written` both the
rows written (each candidate is written, or the statement fails);
`watermark` the latest `packed_at` declared (`declare-exports`), empty for
`escalate-customs`. The log's `rows=` is the declarations or incidents
written.

## The gateway stub

A stream calls `customs.acknowledge` as `customs_gw` every 15 seconds,
day and night (`4/min`, even arrivals). `customs_gw` reads
`customs_outbox` and writes `customs_acks`, nothing else (access model
9.1): it never reads its own answers, so it works by **time slots**. Each
call answers the declarations whose `sent_at` lies in the 15-second slot
(aligned on the epoch) ending at the last slot boundary at least five
seconds before it; the stream's calls come 15 seconds apart, one a slot.

- **Acknowledgement delay**: 5 to 35 seconds after sending, a few
  milliseconds more under load; `declare-exports` sends at the start of
  its minute, so its declarations are answered within 20 to 35 seconds.
  The five seconds let a declaring transaction commit.
- **Accepted** when well-formed: the schema's seven fields present and not
  empty, `lines` a non-empty list; `reference` an MRN, the year, `DE` (the
  exporter's country) and 14 characters of a hash of the declaration.
  Fields beyond the schema do not make it reject: the gateway is lenient,
  E3 is not. Two declarations of one order get two references.
- **Rejected** otherwise, `reason` `missing or empty: <fields>`.
- **Never answered: about one declaration in fifty**, those whose
  idempotency key hashes to 0 modulo 50
  (`mod(hashtextextended(idempotency_key, 214), 50) = 0`), as standing
  behaviour of its schedule before and after the hand-over (spec D214), so
  `escalate-customs` has work every hour or so and E4 has witnesses. The
  choice is deterministic: a declaration's fate depends on its key alone,
  so a GM can tell which ones the stub left (`SELECT … WHERE
  mod(hashtextextended(idempotency_key, 214), 50) = 0`).
- **Its limits**, to know before reading its trace: a call that fails (the
  database unreachable) leaves its slot unanswered for good, read as the
  gateway's outage; a program start whose phase falls within a few
  milliseconds of a slot boundary can answer a slot twice or skip one
  (the calls' jitter against 15 seconds: rare). Neither breaks a check: a second
  answer is still one accepted declaration (E2 counts declarations), a
  skipped slot is escalated (E4).
- **Outages and rejection spells** are timeline changes of the stream in
  the scenario's schedule (its `key` set to one that answers nothing, or
  rejects everything, then back), never anything outside the schedule
  (f8, `purpose-receiver-down-unnoticed`, writes its own).

## Payload schemas

The declaration (`customs_outbox.payload`), the gateway's schema,
exactly:

| Key | Value |
|---|---|
| `order_ref` | `TB-<order id>` |
| `consignee_name`, `consignee_address` | the customer's name and postal address |
| `destination_country` | the order's `ship_country` |
| `lines` | the order's lines, each exactly `sku`, `description` (the product as sold), `quantity`, `value` (the line total) |
| `total_value`, `currency` | the sum of the lines, `EUR` |

The acknowledgement (`customs_acks`): `outbox_id`, `status` (`accepted`
or `rejected`), `reference` (accepted) or `reason` (rejected),
`received_at`.

## Invariants and checks

Each check runs on the runner (`crm`) as root, through `gmctl check`, from
`CHECK_SINCE` raised to the runner's last reload (`check-runs since`), the
same before and after the hand-over (spec D217). E1 and E4 judge
**triggers** (12.4): exit 1 for a trigger past its deadline unhandled, 0
when every trigger older than two dispatch cycles was handled in time (at
least one), else 3 with `remaining=` until the oldest pending trigger
reaches two cycles or its deadline. E2 and E3 judge `declare-exports`'
runs (12.2).

| Invariant | Check | Violation | Witness |
|---|---|---|---|
| E1 declared in time | [`checks/e1-declared-in-time.sh`](checks/e1-declared-in-time.sh) | an export order packed since with no declaration two hours after `packed_at`, or declared later | an export order packed since, ten minutes old (exports are packed every few minutes) |
| E2 declared once | [`checks/e2-declared-once.sh`](checks/e2-declared-once.sh) | an order with two accepted declarations, one sent since | a run since, answered (two minutes old), starting when its horizon held declarations |
| E3 minimum content | [`checks/e3-minimum-content.sh`](checks/e3-minimum-content.sh) | a declaration since with a key beyond or missing from the schema, a line beyond its keys or not of its order, more lines than its order, or an e-mail address anywhere | a run since that sent declarations |
| E4 acknowledged or escalated | [`checks/e4-acknowledged-or-escalated.sh`](checks/e4-acknowledged-or-escalated.sh) | a declaration since unacknowledged within 30 minutes, or rejected, with no incident by its deadline | such a declaration escalated in time: the stub's one in fifty |

**E4's deadline.** The master spec's E4 reads "an acknowledgement, or an
incidents row within 30 minutes of sending", and its escalation job
escalates what is "unacknowledged 30 minutes after sending" every quarter
hour. Read together, the 30 minutes are the acknowledgement's: an
unanswered declaration's incident is due by the escalation run after
them, so the check's deadline is 30 minutes after sending (or after the
rejection, with no wait) plus one escalation cycle (15 minutes) and two
minutes' grace. Its witness is a declaration that needed escalating, so
it reads 0 only once the stub has left one unanswered and its incident
came (about every 25 minutes at the peak, sparser at night).

The checks take no parameter (`parameters: {}`).

## Feedback notes

- A declaration that is both late (E1) and escalated in time (E4) is two
  findings, not one: the trigger was missed, the answer was handled.
- During the gateway's outage every declaration goes unanswered: a
  working escalation turns each into an incident within 45 minutes. Two
  hours of outage with no incident is f8's "down unnoticed".
- The idempotency key is the shop's promise not to declare twice; the
  gateway does not dedupe (two declarations, two references), so E2 is the
  shop's to keep.
- E3's line about e-mail addresses matches any address-like text in the
  payload, a consignee address included.
