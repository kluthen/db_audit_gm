# v0.4 — the purpose catalogue

Status: draft v2

The purposes v0.4 ships, each with its jobs, its trace and its
invariants, stated against the shop's data model
([shop-domain.md](shop-domain.md)). Which purposes ship is settled
(D197); the format they follow is in [purposes.md](purposes.md);
their faults in [candidate-faults.md](candidate-faults.md); how an
invariant is judged in [checks.md](checks.md).

## The purposes v0.4 ships (D197)

Four purposes on the shop, of three kinds:

| Purpose | Kind | Owner's words it serves | Source → target | Trace kinds |
|---|---|---|---|---|
| **P1 sales reporting** | pulled: published for readers | "BI settings (capturing daily information production…)", "computation of reports", "dashboards" | `shop` → `reporting`, through `postgres_fdw` | published results, run ledger, a dashboard's definition |
| **P2 win-back leads** | transformed in place | "…transforming it into leads" | `shop` → `shop` (`leads`) | published results, run ledger |
| **P3 customer mailing** | pushed, no obligation | "mailing… How would we check duplicate sending, ill appropriate sending, were we truly doing this?" | `shop` → `shop` (`mail_outbox`) | outbox rows |
| **P5 export declarations** | **pushed obligation** | "a really good not really consummer (it's on the output of the system, but need to be pushed…)" | `shop` → the customs gateway (a stub), acknowledged back | outbox rows, acknowledgements, triggers |

Why these: P1 to P3 chain (reporting is the BI side, leads come from
the shop's own data, mailing consumes the leads) and cover every trace
kind with one second database; P5 is the kind the owner singled out
(2026-10-30), the only one with a deadline and an acknowledgement. They
need consent, time zones, a shipping time and a destination country
added to the data model, and one stub receiver node. **Finance** (P4,
below) needs payments, refunds, invoices and accounting periods: about as
much data-model work again. P4 is held for v0.5 with the domains
(D197).

Four purposes is one more than D190's "two or three"; the owner chose
four (D197).

No purpose here needs an engine beyond PostgreSQL at the project's sizes
("schemas simple, tables small"): O106 closed by D194.

## P1 — sales reporting

The back office's figures move out of the shop's database into a
reporting database the BI agency runs.

**Jobs** (runner `bi`, role `bi_etl` on `reporting`):

| Job | Cadence (scenario time) | What it computes |
|---|---|---|
| `rollup-hourly` | `5 * * * *` | Through foreign tables `src.orders`, `src.order_lines`, `src.products`: the orders changed since the watermark (`updated_at`), their hours and days recomputed in `rpt.sales_hourly` and `rpt.sales_daily` (delete and re-insert the affected hours, one transaction); the watermark moved; one `rpt.etl_runs` row |
| `rollup-close` | `30 1 * * *` | Yesterday, in the customer's time zone, recomputed whole and marked `closed`; one `rpt.etl_runs` row |

**Consumer**: the back office's dashboards (v0.3's `consumer` node) read
`reporting` as `bi_reader` for their KPIs; their queries are
definitions.

**Trace**: `rpt.sales_hourly`, `rpt.sales_daily` (published results);
`rpt.etl_runs` and the scheduler log (run ledger); the dashboards'
queries (definitions).

**Invariants**:

- **R1 reconciled.** For every hour and day a run since the judged
  moment wrote, its orders, units and revenue equal the source's for
  that local hour or day, counting the source's orders as they stood at
  the run's start (`updated_at` before it). Witness: orders arrive every
  hour, night included (tarnbeck's shape keeps 0.1 of the peak at night),
  and the close-of-day invoicing updates past orders daily.
- **R2 counted once.** Each (hour, category) has one row; a day's row
  equals the sum of its hours.
- **R3 local days.** Hours and days are the customer's local hours and
  days (`business_settings.timezone`). Witness: orders placed between
  local midnight and the offset's hour exist every night.
- **R4 fresh.** The latest successful `rollup-hourly` started within
  70 minutes and processed rows; `etl_runs` shows no run since the
  judged moment ending in error or with no row read in business hours.
- **R5 dashboard faithful** (definition, optional). The dashboards'
  revenue query returns what `rpt.sales_daily` holds for the same day.

## P2 — win-back leads

The marketing team extracts, every hour, the customers to win back for
the active campaign.

**Job** (runner `crm`, role `shop_crm` on `shop`): `leads-extract`,
`20 * * * *`: for the active `winback` campaign, customers whose last
order is between 60 and 365 days old, with marketing consent, not yet a
lead of the campaign, into `leads` with a score; one `etl_runs` row.

**Trace**: `leads` (published results), `etl_runs` and the log (run
ledger).

**Invariants**:

- **L1 in segment.** Every lead extracted since the judged moment had,
  at its `extracted_at`, no order in the previous 60 days and one within
  365. Witness: lapsed customers order again every day (the checkout
  picks customers at random), so some leave the segment between two
  runs.
- **L2 consented.** Every lead extracted since had marketing consent at
  its `extracted_at`: the latest `consent_events` row for
  `marketing-email` at or before it is a grant. Witness: the producer's
  unsubscribe stream withdraws consent from lapsed customers every hour.
- **L3 once per campaign.** At most one lead per (campaign, customer).

## P3 — customer mailing

Mail is "handed to the provider" by inserting into `mail_outbox`; there
is no mailer (D190; O110 closed by D195). The outbox is the whole trace.

**Jobs** (runner `crm`, role `shop_crm` on `shop`):

| Job | Cadence (scenario time) | What it sends |
|---|---|---|
| `mail-shipped` | `*/5 * * * *` | Transactional: one `order-shipped` notice per order shipped since the last run (`orders.shipped_at`), to its customer; no marketing consent needed |
| `mail-campaign` | `*/15 8-20 * * *` | Marketing: up to a batch of the active campaign's leads not yet mailed, consented at sending time, whose local time is within the sending hours |

**Invariants**:

- **M1 no duplicate.** At most one `order-shipped` mail per order; at
  most one campaign mail per (campaign, customer).
- **M2 consent.** Every marketing mail sent since the judged moment had
  marketing consent at its `sent_at`. Transactional mail is exempt.
  Witness: unsubscribes arrive every hour among leads.
- **M3 sending hours.** Every marketing mail's `sent_at`, in the
  recipient's local time, falls within the sending hours
  (`business_settings`, 08:00 to 21:00 by default). Witness: recipients
  at −8 h and +5 h from the customer's zone are pending at every batch
  time between 08:00 and 20:45 ([shop-domain.md](shop-domain.md),
  "Recipients' time zones").
- **M4 own data.** Every mail's payload names its recipient only: its
  e-mail and name are the recipient's, and any order in it is one of
  the recipient's orders.
- **M5 truly sent.** Every order shipped since the judged moment, more
  than fifteen minutes ago, has its `order-shipped` mail. This is the
  owner's "were we truly doing this".

## P5 — export declarations: a pushed obligation

### The kind

The owner's words (2026-10-30), on the clinic's notifiable disease
reports: "it a really good not really consummer (it's on the output of
the system, but need to be pushed, quite different from our usual
consumer)". v0.3's consumers pull: they query when they like. A **pushed
obligation** is an event in the data that creates a duty to send
something to an outside receiver by a deadline:

- **a trigger**: a source row matching a rule (a confirmed diagnosis of
  a listed disease; an order leaving the customs union);
- **a deadline**, counted from the trigger;
- **an outside receiver**, which the company does not run;
- **an acknowledgement** from the receiver, or an escalation when none
  comes.

P3's mail is pushed too, but owes nobody anything and gets no answer;
that is the difference.

The kind is a v0.4 purpose kind, with a shop instance below; notifiable
disease reports are the clinic's instance, in v0.5 (D196). It belongs in
v0.4 because v0.4 is about consumers modelled by their trace, and this
is the one consumer the trace models best: everything it owes is
checkable in the outbox, the acknowledgements and the triggers.

### The shop's instance (D197)

**Export declarations**: every order shipped to a country outside the
customs union must be declared to the customs gateway before it leaves,
within two hours of being packed, and the gateway answers with a
movement reference (accepted) or a rejection. Other shop instances
considered: a product-recall notice to buyers and a personal-data breach
notification (both rare triggers, which would have to be timeline
changes, D127), a VAT filing (monthly: out of v0.4, D199). The declaration has a
trigger every few minutes at the shop's volume, a real deadline in
hours, and a content rule that meets governance (consignee name and
address may go, the e-mail may not).

**Jobs** (runner `crm`, role `shop_customs` on `shop`):

| Job | Cadence | What it does |
|---|---|---|
| `declare-exports` | `*/5 * * * *` | Packed orders whose `ship_country` is in `export_countries` and that have no accepted declaration: one `customs_outbox` row each, keyed by the order (the idempotency key), with the declared content |
| `escalate-customs` | `*/15 * * * *` | Declarations unacknowledged 30 minutes after sending, or rejected: one `incidents` row each |

**The receiver** is a stub, a scheduler node of its own (`gateway`,
report-only, the customs authority's side plus the shop's callback
endpoint): a stream reads new `customs_outbox` rows as `customs_gw` and
writes `customs_acks` (accepted with a reference, or rejected with a
reason), within a minute. It accepts every well-formed declaration, so
two declarations of one order get two references. Its outages and
rejections are timeline changes of its schedule (D127), never events
outside the schedule (D117). No real external service.

**Trace**: the triggers (orders, `export_countries`), `customs_outbox`,
`customs_acks`, `incidents`, the runner's log.

**Invariants**:

- **E1 every trigger declared in time.** Every order packed since the
  judged moment with an export destination has a declaration sent within
  two hours of `packed_at`. Witness: export orders are packed every few
  minutes ([shop-domain.md](shop-domain.md)).
- **E2 declared once.** At most one accepted declaration per order.
- **E3 minimum content.** A declaration carries the fields the gateway's
  schema lists and nothing else: no e-mail, no customer id, no other
  order's lines ([governance.md](governance.md), outbound flows).
- **E4 acknowledged or escalated.** Every declaration sent since the
  judged moment has an acknowledgement, or an `incidents` row within 30
  minutes of sending; every rejection has an `incidents` row.

### Time

A deadline counted from a continuous trigger fits real time well: the
trigger happens every few minutes, so a fix shows within a session
without moving any job, and the check judges each trigger once its
deadline or two dispatch cycles have passed ([checks.md](checks.md),
"Pushed obligations"). It eases real time's limits (D199) for this
kind, under two
conditions:

- **Triggers must be frequent.** A rare trigger (a breach, a recall, a
  notifiable disease in a quiet week) never occurs in a session unless a
  timeline change makes it occur, which D127 allows at fixed moments
  during the aging only, so never after a fix.
- **The deadline must be shortish, or the dispatch frequent.** A missed
  trigger is a violation only once its deadline has passed; a clinic's
  24-hour deadline would leave a miss "too soon to tell" for the whole
  session. Shortening a legal deadline in the story (24 hours to two) is
  a story choice, not a clock change, so D114 and D132 allow it.

## P4 — finance reconciliation (held for v0.5, D197)

Listed so the swap is costed. Jobs: a nightly invoicing and a period
close. Data: `payments`, `refunds`, `invoices`, `ledger_entries`,
`periods`; the producer's checkout writes a payment, a refund stream
reverses some. Invariants: every invoiced order has one invoice equal to
its total and a payment covering it; the ledger balances per period; a
closed period is never modified; a refund lands in the period it
happened in; reporting revenue equals ledger revenue. Its daily and
monthly cadences make it the purpose real time serves worst (D199).

## Stress test: the clinic's strict reporting

The veterinary clinic is a v0.5 domain (D196), not a v0.4 purpose. Its
regulatory reports were used to test whether the purpose model above can
express them; they ask for two invariant shapes the shop's purposes do
not exercise:

- **A deadline.** A notifiable disease must be reported within N hours
  of the confirming lab result: "every source event of a kind has its
  trace row within N hours". That is P5's kind, a pushed obligation
  (E1, E4); M5 has the same shape without an acknowledgement.
- **A release gate.** A lab result may reach the owner's portal only
  once a vet has validated it: "no trace row before its source's
  `validated_at`". Expressible as an invariant over the trace against
  the source, like L2.
- **A register.** The antimicrobial-use register must list every
  prescription of a listed substance, once, with quantities equal to the
  source: completeness (M5) plus reconciliation (R1). Expressible.

No new artefact or check form is needed for them. One thing they show:
regulatory reports are **monthly or yearly** in reality, which real time
cannot age (D199, O22); a v0.5 clinic will press O22 harder than the shop.
