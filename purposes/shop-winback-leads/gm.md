# P2, win-back leads: GM notes

The marketing team's hourly extraction of the customers to win back for
the active campaign (master spec 10.2). Transformed in place: the shop's
own data turned into another table of it, `leads`, which the mailing
purpose ([`shop-customer-mailing`](../shop-customer-mailing/gm.md))
consumes. A design-time source: copy the material into a scenario and
adapt the names there; the purpose itself never changes for a scenario.

## What it is for

The shop lost a third of its customers to time: their last order is 60
to 365 days old. Each hour, the extraction lists those who still agree to
marketing e-mail and are not leads yet, with a score (their lifetime
value per month lapsed), so the campaign mails the best first. The
company's rule, and the players' audit question: **consent is the latest
`marketing-email` event, never the opt-in flag** (9.3).

## The material

| File | Copied to | What |
|---|---|---|
| [`material/runner/queries.yaml`](material/runner/queries.yaml) | the runner's `queries.yaml` (`nodes/crm/`) | `leads.extract`, one statement |
| [`material/runner/jobs.yaml`](material/runner/jobs.yaml) | the runner's `jobs.yaml` | `leads-extract` at `20 * * * *`, scenario time |
| [`material/runner/schedule.yaml`](material/runner/schedule.yaml) | the runner's `schedule.yaml` | the connection `shop_crm` (`db:5432/shop` as `shop_crm`), no stream |

No source material: `domains/shop` already creates `leads`, `etl_runs`,
`shop_crm` and its grants (`SELECT` on `customers`, `consent_events`,
`campaigns`, `leads`; `INSERT` on `leads`, `etl_runs`). The mailing
purpose's fragment holds the same connection: keep one.

**Names to adapt** when copying: the node `db` and database `shop` (the
connection's target; `DB` in each check), the runner `crm` (where the
checks run), the job name `leads-extract` (`JOB` in each check).

## The job

`leads-extract`, as `shop_crm`, one `INSERT … SELECT` with a
data-modifying CTE, so one transaction:

- for each campaign `active` with `segment = 'winback'`, the customers
  whose `last_order_at` is between 60 and 365 days before `now()`, whose
  latest `marketing-email` event at or before `now()` (by `at`, then `id`)
  is a grant, and with no lead of that campaign;
- each inserted into `leads` with `extracted_at = now()` and `score =
  lifetime_value / (1 + months since the last order)`;
- one `etl_runs` row: `job` `leads-extract`, `started_at` the run's
  `now()` (every lead's `extracted_at`), `finished_at` `clock_timestamp()`
  once the candidates are read, `rows_read` and `rows_written` both the
  number of candidates (each is inserted, or the statement fails),
  `watermark` empty. The scheduler's `rows=` is the leads inserted.

At the first run after the load the segment has about 4 000 customers
with consent (chunk 5's figures); later runs add the few who enter it
(lapsing past 60 days, or granting consent again).

## How it goes wrong (the audit surface)

- **The flag instead of the history**: a job testing
  `customers.marketing_opt_in` agrees with the history only as long as the
  web shop writes both; f2 (`purpose-leads-stale-consent`) breaks that.
- **The latest event, wrongly taken**: `ORDER BY at` without the `id`
  tie-break, any grant ever, the first event: each reads consent wrongly
  for some of the nine hundred customers who withdrew after granting.
- **The segment's bounds**: a stale or cached last order, `>` for `>=`, a
  segment in the server's zone instead of a span of days.
- **"Not yet a lead"**: dropped, and the unique constraint makes the run
  fail; dropped with the constraint, and leads are extracted every hour
  again (L3).

## Invariants and checks

Each check runs on the runner (`crm`) as root, through `gmctl check`,
judging the job's runs since `CHECK_SINCE` raised to the runner's last
reload (`check-runs since`), the same before and after the hand-over
(spec D217). Exit 1 names the run and one violating lead; 0 needs every
run since clean and a witness; 3 gives `remaining=` to the job's next run.

| Invariant | Check | Violation | Witness, counted at the latest run |
|---|---|---|---|
| L1 in segment | [`checks/l1-in-segment.sh`](checks/l1-in-segment.sh) | a lead extracted since whose last order at its `extracted_at` was under 60 or over 365 days old, or who never ordered | a customer with no order in `orders` before the judged moment ordering between it and the run, with consent, not a lead (lapsed customers order again every day) |
| L2 consented | [`checks/l2-consented.sh`](checks/l2-consented.sh) | a lead extracted since whose latest consent event at its `extracted_at` was a withdrawal, or none | customers of the segment, not leads, whose latest event at the run is a withdrawal after a grant |
| L3 once per campaign | [`checks/l3-once-per-campaign.sh`](checks/l3-once-per-campaign.sh) | a (campaign, customer) with two leads, one extracted since | leads of an active campaign extracted before the run |

L1's last order at a past moment: the latest of the customer's orders in
`orders` placed a minute or more before it, else `last_order_at` when
that is not later (the archived history). The minute is a commit's grace:
a checkout holds its transaction a few seconds, so an order placed just
before the extraction may not have been there for the job to see, and
the live run showed one such lead at the launch's extraction. A lead
whose customer ordered since and has no order in `orders` before its
extraction is not judged: its last order then is in no table any more.
L2 takes the same grace both ways: a lead is held against it only when
consent was lacking both at its `extracted_at` and a minute before.

The checks take no parameter (`parameters: {}`): a fault on this purpose
breaks the one job.

## Feedback notes

- Players who find the flag and the history disagreeing have found the
  trap, whether or not a fault planted it; the history is the truth, and
  the policy says so.
- A lead extracted while consent was given and withdrawn since is not a
  violation of L2: the mailing's M2 judges consent again at sending time.
- `leads` holds the campaign's whole audience since its launch, not a
  queue: nothing is ever deleted from it.
