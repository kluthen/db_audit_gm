# P3, customer mailing: GM notes

The shop's shipping notices and the win-back campaign's mail (master spec
10.3). Pushed: a mail is "handed to the provider" by inserting a row into
`mail_outbox`, owing nobody an answer; there is no mailer, and the outbox
is the whole trace (8.3). The campaign's audience is the win-back leads
purpose's `leads` ([`shop-winback-leads`](../shop-winback-leads/gm.md)).
A design-time source: copy the material into a scenario and adapt the
names there.

## What it is for

Two kinds of mail. **Transactional**: one `order-shipped` notice for each
order the warehouse ships, day and night; no marketing consent needed.
**Marketing**: the campaign's mail to its leads, in batches during the
company's day, each only with marketing consent at sending time (the
latest consent event, never the flag) and only within the recipient's own
sending hours, 08:00 to 21:00 their time (`business_settings`, 9.2).

## The material

| File | Copied to | What |
|---|---|---|
| [`material/runner/queries.yaml`](material/runner/queries.yaml) | the runner's `queries.yaml` (`nodes/crm/`) | `mail.shipped`, `mail.campaign`, one statement each |
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml) | the runner's `jobs.yaml` | `mail-shipped` at `*/5 * * * *`, `mail-campaign` at `*/15 8-20 * * *`, scenario time |
| [`material/runner/schedule.yaml`](material/runner/schedule.yaml) | the runner's `schedule.yaml` | the connection `shop_crm`, as the leads purpose's; no stream |

No source material: `domains/shop` creates `mail_outbox` and `shop_crm`'s
grants (`SELECT` on `customers`, `consent_events`, `orders`, `campaigns`,
`leads`, `mail_outbox`, `business_settings`; `INSERT` on `mail_outbox`).
P3 writes no `etl_runs` row (9.6): its ledger is the scheduler's log.

**Names to adapt** when copying: `db`/`shop` (the connection; `DB` in each
check), the runner `crm`, the job names (`JOB`/`JOBS` in each check).

## The jobs

- **`mail-shipped`**, as `shop_crm`: the orders whose `shipped_at` is in
  the five minutes ending at the last whole minute before the run, `[t −
  6 min, t − 1 min)` with `t` the run's minute: the orders shipped since
  the last run, the window matching the five-minute cadence, a minute
  behind so a warehouse update still committing is never missed. A notice
  goes out one to six minutes after shipping. It keeps no watermark and
  does not look at `mail_outbox`: **the window must match the cadence**.
  Wider and every notice goes twice (f1,
  `purpose-mail-overlapping-window`, M1); narrower, a skipped run, or a
  cadence moved, and notices are lost (M5).
- **`mail-campaign`**, as `shop_crm`: up to 50 leads of the active
  `winback` campaign with no campaign mail yet, best score first, each
  with marketing consent now by the latest event and whose local time now
  (`now() AT TIME ZONE customers.timezone`) is within `[mail_window_start,
  mail_window_end)`. 50 a quarter hour is the provider's contract (200 an
  hour), so the ~4 000 leads of the launch take about a day and a half of
  sending, and every batch of the game has leads waiting, some outside
  their hours (one in ten is eight hours behind or five ahead of the
  company: outside before 16:00, or from 16:00), some having withdrawn.
  The job's own times, 08:00 to 20:45 company time, are the company's day;
  the recipient's hours are the statement's, which is the audit point:
  the company's day is not the recipient's (f3,
  `purpose-mail-outside-hours`, M3).

`sent_at` is the run's `now()`; `rows=` in the log is the mail sent.

## Payload schemas

The provider's two templates; `mail_outbox.email` is the recipient's
address, `template` the template.

| Template | `payload` keys |
|---|---|
| `order-shipped` (with `order_id`) | `name`, `email` (the recipient's), `order_id`, `shipped_at`, `ship_country`, `total` |
| the campaign's code, `winback-<yyyy-mm>` (with `campaign_id`) | `name`, `email` (the recipient's), `campaign` (the code) |

Both payloads are personal (the classification classes
`mail_outbox.payload` and `email` so).

## Invariants and checks

Each check runs on the runner (`crm`) as root, through `gmctl check`,
judging the runs since `CHECK_SINCE` raised to the runner's last reload
(`check-runs since`), the same before and after the hand-over (spec
D217). Exit 1 names the run and one violating mail or order (a violation
since the judged moment counts whether or not the job ran); 0 needs a run
since, clean, with a witness; 3 gives `remaining=` to the job's next run.
A marketing mail is a row with a `campaign_id`.

| Invariant | Check | Violation | Witness, at the latest run |
|---|---|---|---|
| M1 no duplicate | [`checks/m1-no-duplicate.sh`](checks/m1-no-duplicate.sh) | an order with two `order-shipped` mails, or a (campaign, customer) with two campaign mails, one sent since | `mail-shipped`: notices sent in the half hour before it; `mail-campaign`: campaign mail sent before it |
| M2 consent | [`checks/m2-consent.sh`](checks/m2-consent.sh) | a marketing mail since whose recipient's latest event at `sent_at` was a withdrawal, or none | leads not yet mailed whose latest event at the run is a withdrawal |
| M3 sending hours | [`checks/m3-sending-hours.sh`](checks/m3-sending-hours.sh) | a marketing mail since whose `sent_at` in the recipient's zone is outside the hours | leads not yet mailed, with consent, outside their hours at the run |
| M4 own data | [`checks/m4-own-data.sh`](checks/m4-own-data.sh) | a mail since whose `email`, payload `email` or `name` is not the recipient's, whose payload carries another e-mail address, or whose order (column or payload) is not theirs | a run since that sent mail |
| M5 truly sent | [`checks/m5-truly-sent.sh`](checks/m5-truly-sent.sh) | an order shipped since, more than fifteen minutes ago, with no `order-shipped` mail | such an order (orders ship day and night) |

M2, like the leads' L2, holds a mail against consent only when it was
lacking both at `sent_at` and a minute before: a withdrawal still
committing when the job read is the job's to miss, not a violation.

**Parameters.** M1 and M4 cover both jobs; the purpose's parameter `job`
(`FAULT_JOB`: `mail-shipped` or `mail-campaign`) narrows the check to one,
so a fault breaking the notices is not kept waiting for the campaign's
morning (and the reverse). Unset, both jobs need a run with a witness, and
`remaining=` is the later of their next runs. M2 and M3 judge
`mail-campaign`, M5 `mail-shipped`. In the first v0.4 scenario the game
(14:00 to 18:00 company time) lies in the campaign's day.

## Feedback notes

- A shipping notice to a customer who unsubscribed is right: it is
  transactional (I2's complaint is about the campaign).
- "Every shipping notice twice" (I1) is the window, not the provider; a
  fix that adds a `NOT EXISTS` on `mail_outbox` is as good as one that
  narrows the window back, and better against a moved cadence.
- A recipient's hours are in their own zone; a fix in the server's or the
  company's zone still mails some recipients at night (I3).
- M5 is the owner's "were we truly doing this": a window that misses
  orders is as wrong as one that repeats them.
