# v0.4 — the shop domain: data model and domain format

Status: draft v1

The shop as the first domain (D192): what v0.4 must settle of a domain's
format (O111), and the changes to the business data model that the
purposes' invariants need (O108). It starts from v0.3's
`tarnbeck-outdoor-shop`, read on `v0.3-w4`.

## What tarnbeck already has

`data/db.sql` (149 lines, run by `gmctl load-data` as `postgres`):

- roles `shop` (owner, no login), `shop_app` (the web shop, through
  PgBouncer), `shop_reports` (the back office, direct);
- `customers` (20 000: name, e-mail, `created_at`, `last_order_at`,
  `lifetime_value`), `products` (2 000), `orders` (300 000 over fifteen
  days, status paid → packed → shipped → invoiced, `updated_at`),
  `order_lines` (900 000), `delivery_events` (60 000), `daily_sales`;
- grants: `shop_reports` reads every table, customers' names and e-mail
  addresses included.

The producer (`nodes/producer/queries.yaml`) places orders (40 a minute
at the noon peak, a tenth at night), moves them to packed and shipped,
ingests carrier events, and invoices shipped orders at the 12:00
close-of-day. Every clock and the database's `timezone` are UTC.

None of it says who may be mailed, where a customer lives, when an order
was shipped, or where it goes: the truth the purposes' invariants need.

## The domain format: what v0.4 settles (O111)

Proposed, the least that keeps v0.5 from restructuring the shop:

```
domains/shop/
  domain.yaml           identity, the parts below, the purposes that fit
  data/
    schema.sql          the business tables, roles and grants
    load.sql            the generated history ("last night's backup")
    classification.yaml every classed column (governance.md)
  producers/            producer profiles: repository fragments and
                        schedule fragments for the web shop's traffic
  docs/gm.md            the business, its rules, its traps
```

- **A design-time source.** The GM copies a domain's files into the
  scenario folder, adapting them, as it writes a repository today; the
  scenario stays self-sufficient (D23). `scenario.yaml` names the domain
  (`domain: shop`) for provenance. Like a purpose, a domain therefore
  never bumps (purposes.md, O104). How a profile meets `schedule.yaml`
  and its size scaling stay v0.5's (O113, O114).
- **Static scenarios** need no domain: `bookshop-new-server` and
  `fernway-clinics-monitoring` stay as they are.
- **Tarnbeck stays untouched.** The domain is derived from its data
  file; the released v0.3 scenario keeps its own (scenarios never bump,
  D58, but nothing obliges a change). v0.4's scenario is new
  ([scenario-sketch.md](scenario-sketch.md)).
- Whether a domain may be **composed of smaller domains**, as the clinic
  suggests (D196), is O126; v0.4's shop is one piece.

## Changes to the business data model (O108)

Proposed. Each change names the invariant that needs it.

### Business settings (O122)

```sql
CREATE TABLE business_settings (
    timezone          text NOT NULL,   -- the customer's zone, Etc/GMT∓N, from load-data
    utc_offset_hours  integer NOT NULL,
    mail_window_start time NOT NULL DEFAULT '08:00',
    mail_window_end   time NOT NULL DEFAULT '21:00'
);
```

One row, written by the data file from the `psql` variables `load-data`
passes (purposes.md, "The customer's time zone in the data"). The
purposes read it; so do the checks. R3, M3, E1.

### Customers: country, time zone, consent

- `customers.address`, `customers.country` (ISO 3166 alpha-2) and
  `customers.timezone` (`Etc/GMT∓N`). M3, E1, E3 (a declaration names
  the consignee and their address).
- `consent_events (id, customer_id, purpose, granted, at, source)`:
  the record of every grant and withdrawal (`purpose` is
  `marketing-email` in v0.4; `source` is `checkout`, `unsubscribe-link`
  or `support`). The truth L2 and M2 judge against.
- `customers.marketing_opt_in`: the current state, kept by the web shop
  beside the history. Two places for one fact is realistic, and a fault
  vector (L1-type faults read the flag when the history disagrees).

**Recipients' time zones.** Stored as fixed offsets relative to the
customer's (shift invariance, O122): by default 80 % at the customer's
offset, 5 % at −1 h, 5 % at +1 h, 5 % at −8 h (North America), 5 % at
+5 h (Asia). With sending hours 08:00 to 21:00 and the campaign job
running 08:00 to 20:45 customer time, recipients at −8 h are outside
their hours before 16:00 and those at +5 h from 16:00: every campaign
batch has a witness for M3 (purpose-catalogue.md).

### Orders: shipping time, destination

- `orders.packed_at`, `orders.shipped_at`: set by the warehouse's status
  update. M5, E1.
- `orders.ship_country`: the customer's country by default, sometimes
  another. E1.
- `export_countries (country)`: the destinations outside the customs
  union, the rule P5's trigger reads. About 10 % of orders ship to one,
  so a few export orders are packed every five minutes at the peak, one
  every quarter hour at night.

### Longer history for the segment

Orders cover fifteen days; a win-back segment needs customers who last
ordered 60 to 365 days ago. The data file sets `last_order_at` from an
older, archived history (the orders table holding fifteen days, older
ones archived away) for customers with no recent order: about a third
lapsed. L1.

### New tables of the purposes

| Table | Database | Purpose | Notes |
|---|---|---|---|
| `campaigns (id, code, segment, starts_on, ends_on, active)` | `shop` | P2, P3 | one active `winback` campaign |
| `leads (campaign_id, customer_id, score, extracted_at)` | `shop` | P2 | unique (campaign, customer) by design |
| `mail_outbox (id, customer_id, email, template, campaign_id, order_id, payload jsonb, sent_at)` | `shop` | P3 | "handed to the provider" |
| `customs_outbox (id, order_id, payload jsonb, sent_at, idempotency_key)` | `shop` | P5 | unique `idempotency_key` by design |
| `customs_acks (outbox_id, status, reference, reason, received_at)` | `shop` | P5 | written by the gateway stub |
| `incidents (id, source, ref, opened_at, reason)` | `shop` | P5 | escalations |
| `etl_runs (id, job, started_at, finished_at, rows_read, rows_written, watermark)` | each target | P1, P2, P5 | the run ledger the jobs write themselves |
| `rpt.sales_hourly (hour_local, category, orders, units, revenue)` | `reporting` | P1 | aggregates only, no customer id |
| `rpt.sales_daily (day_local, orders, revenue, invoiced_revenue, closed)` | `reporting` | P1 | |
| `src.*` foreign tables over `orders`, `order_lines`, `products` | `reporting` | P1 | `postgres_fdw` (O123) |

`daily_sales` leaves the shop's database: the reporting database holds
the figures now.

### Roles

| Role | Database | Reads | Writes |
|---|---|---|---|
| `shop_app` | `shop` | as v0.3, plus `consent_events` | as v0.3, plus `consent_events`, `customers.marketing_opt_in`, the new order columns |
| `shop_reports` | `shop` | as v0.3 (names and e-mails included) | none (the roll-up moved) |
| `shop_etl` | `shop` | `orders`, `order_lines`, `products` | none: the user mapping's remote role |
| `shop_crm` | `shop` | `customers`, `consent_events`, `orders`, `campaigns`, `leads`, `mail_outbox` | `leads`, `mail_outbox`, `etl_runs` |
| `shop_customs` | `shop` | `orders`, `order_lines`, `customers` (name, country), `export_countries`, `customs_*` | `customs_outbox`, `incidents`, `etl_runs` |
| `customs_gw` | `shop` | `customs_outbox` | `customs_acks` |
| `bi_etl` | `reporting` | `src.*` | `rpt.*` |
| `bi_reader` | `reporting` | `rpt.*` | none |

Each login role gets its password from its secret at `load-data`, as
v0.3 does for the roles a schedule names; the user mapping's password is
the new step (O123).

### Producer changes

New keys in the web shop's repository and streams in its schedule:

- `consent.unsubscribe` (an unsubscribe link: a withdrawal event and the
  flag), about 20 an hour, weighted to lapsed customers so L2 and M2 have
  witnesses every hour;
- `consent.subscribe` (a grant at checkout), about 30 an hour;
- `orders.status` sets `packed_at` and `shipped_at`; `orders.place` sets
  `ship_country`.

Load on the database grows by the purposes' jobs, small beside the
checkout; to measure at the rehearsal as v0.3 did.

## Classification

Every column of the model carries a data class in
`data/classification.yaml` ([governance.md](governance.md)):
`personal` for names, e-mail and postal addresses, the outboxes'
payloads and e-mails, consent events, a customer's country and time
zone;
`customer-linked` for a customer id without a direct identifier
(`orders.customer_id`, `leads`); everything else `internal`.
