# The shop domain: GM notes

Tarnbeck Outdoor's web shop as v0.4 knows it (master spec 6.8, 9): the
business, its data, who may touch what, and the traps it holds. A
design-time source: copy its files into a scenario and adapt them there;
the domain itself never changes for a scenario. Derived from
`tarnbeck-outdoor-shop`, whose own files stay as they are.

| File | Copied to | What |
|---|---|---|
| [`data/schema.sql`](../data/schema.sql) | the database node's `data/<node>.sql`, first | roles, database, tables, view, indexes, grants |
| [`data/load.sql`](../data/load.sql) | the same file, after `schema.sql` | last night's backup: the generated history |
| [`data/classification.yaml`](../data/classification.yaml) | where `governance.classification` names it | the class of every column |
| [`producers/`](../producers/) | the web shop's node (`nodes/<producer>/`) | `queries.yaml`, `schedule.yaml` and `jobs.yaml` fragments, `builders/carrier_feed.py` |

## The business

Tarnbeck Outdoor sells camping and hiking gear online from a team of
twenty: about 30 000 orders a day in the busy season, the peak at noon,
nights quiet but never empty. Most customers live inside the customs
union (Germany first, then Austria, France, the Netherlands, Italy,
Belgium, Denmark); 9 % live outside it (Switzerland, the United Kingdom,
Norway, the United States), and a few orders in a hundred ship to a
country other than their customer's. About 10 % of orders ship to a
destination in `export_countries`, which must be declared to customs.

The company works in the customer's time zone, UTC plus the game's
shift. The database, its logs and its clocks stay in UTC; the zone lives
in `business_settings` (written at load from `load-data`'s
`customer_timezone` and `customer_utc_offset`) and in each customer's
own zone.

## The data

| Table | Rows at load | Notes |
|---|---|---|
| `business_settings` | 1 | the customer's zone and offset; marketing mail from 08:00 to 21:00 in the recipient's local time |
| `customers` | 20 000 | name, e-mail, postal address, country, own zone, `marketing_opt_in`, `last_order_at`, `lifetime_value` |
| `consent_events` | about 17 000 | every grant and withdrawal of `marketing-email`; sources `checkout`, `unsubscribe-link`, `support` |
| `products` | 2 000 | sku `TB-00001` to `TB-02000`, eight categories |
| `orders` | 300 000 over fifteen days | `paid` → `packed` → `shipped` → `invoiced`; `packed_at`, `shipped_at`, `ship_country` |
| `order_lines` | 900 000 | |
| `delivery_events` | 60 000 | the carriers' feed; `event_id` unique |
| `export_countries` | 6 | CH, GB, NO, IS, US, CA |
| `campaigns` | 1 | the active `winback` campaign (segment `winback`, code `winback-<yyyy-mm>`), launched on the load day for 28 days |
| `leads`, `mail_outbox`, `customs_outbox`, `customs_acks`, `incidents`, `etl_runs` | 0 | the purposes' tables, filled by their jobs |
| `popular_products` (materialized view) | 192 | each category's 24 best sellers over seven days; refreshed at load |

- **Customers by last order**: 60 % ordered in the fifteen days; 5 %
  last ordered 16 to 59 days ago; **a third are lapsed**, their last
  order 60 to 365 days ago, from an archived history (older orders were
  archived away; `last_order_at` and `lifetime_value` are what is left);
  2 % never ordered. The web shop picks customers uniformly, so lapsed
  customers order again every day.
- **Recipients' zones** are offsets relative to the customer's (9.3):
  80 % at the customer's offset, 5 % each at −1 h, +1 h, −8 h and +5 h,
  wrapped into UTC−12..UTC+14 as render wraps a job's zone (the local
  hour is kept). The zone is independent of the country: the shift makes
  every zone fictional anyway. It is independent of the last order and
  the consent too: every zone holds the same mix, so each 5 % offset has
  330 lapsed customers, 200 of them with consent by their latest event
  and 130 without, and every campaign batch has a witness.
- **Consent**: 64 % granted at their first checkout, a fifth of those
  withdrew later, some granted again. At load the flag equals the latest
  event for every customer; about 4 000 lapsed customers have consent,
  the win-back segment.

Every value is generated: names from two short lists, e-mail addresses
`first.last.<id>@example.net`, addresses in the customer's country.

## The roles (master spec 9.7, access model 9.1)

| Role | Reads | Writes |
|---|---|---|
| `shop` | owns everything; no login | |
| `shop_app` | orders, lines, customers, products, delivery events, `consent_events`, `popular_products` | orders, lines, customers (the opt-in flag, the last order), products' stock, delivery events, `consent_events` |
| `shop_reports` | every table and the view, names and e-mails included | nothing |
| `shop_etl` | `orders` without `customer_id` (a column grant), `order_lines`, `products` | nothing |
| `shop_crm` | `customers`, `consent_events`, `orders`, `campaigns`, `leads`, `mail_outbox`, `business_settings` | `leads`, `mail_outbox`, `etl_runs` (insert) |
| `shop_customs` | `orders`, `order_lines`, `customers` (id, name, address, country), `export_countries`, `customs_outbox`, `customs_acks`, `incidents` | `customs_outbox`, `incidents`, `etl_runs` (insert) |
| `customs_gw` | `customs_outbox` | `customs_acks` (insert) |
| `shop_refresh` | nothing directly | `MAINTAIN` on `popular_products`: it may refresh it, the refresh reading the inputs as the view's owner |

The login roles carry no password here: `load-data` sets each from its
secret once the data has created it. The reporting instance's roles
(`bi_etl`, `bi_reader`) are the sales reporting purpose's material. A
purpose needing more (an `UPDATE` on its ledger, say) appends its grant
in its own source material.

## The classification

[`data/classification.yaml`](../data/classification.yaml) lists all 99
columns: 17 `personal` (names, e-mail and postal addresses, country, own
zone, the opt-in flag, every column of `consent_events`, the outboxes'
e-mails and payloads, and a customer id stored beside a direct
identifier: `customers.id`, `mail_outbox.customer_id`), 5
`customer-linked` (`orders.customer_id`, every column of `leads`), the
rest `internal`. The scenario's `governance:` says where each class may
live and who may read it; the domain only classes.

## The producer

The web shop's fragments: tarnbeck's checkout (40 a minute at the noon
peak, a tenth at night), catalogue pages (now also reading
`popular_products`), order pages, the warehouse's status updates, the
carriers' feed and the 12:00 close of day, plus:

- `orders.place` sets `ship_country`: the customer's country, one in
  twenty elsewhere;
- `orders.status` stamps `packed_at` and `shipped_at`, sized for a few
  export orders packed every five minutes at the peak and one every
  quarter hour at night (9.4; measured at the rehearsal);
- `consent.unsubscribe`, about 20 an hour day and night: a withdrawal
  event and the flag, three in four from a lapsed customer, so the
  consent invariants have witnesses every hour;
- `consent.subscribe`, about 30 an hour: a grant at checkout and the flag.

Tarnbeck's planted faults are not in the domain: the product-code search
compares the sku, and a resent carrier event is stored once (`event_id`
unique, `ON CONFLICT DO NOTHING`). The close of day adds the newly
invoiced to each customer's lifetime value rather than recomputing it
from `orders`, which no longer holds the archived history. The 12:00
close at the noon peak is kept on purpose: it is tarnbeck's, and its
invoicing updates past orders daily (R1's witness).

The fragments sit in `producers/producer/`, for the v0.4 scenario's
node `producer` (D344), and hold only the entries they add: no
`intensity`, no `timeline`, which are the scenario's. They are written for the node
names `pooler` and `db` and the database `shop`; rename them as the
scenario does.

## The rules

- **Consent is the latest event.** A customer may be mailed for
  marketing at a moment when their latest `marketing-email` event at or
  before it is a grant. The baseline jobs read the events, never
  `marketing_opt_in`.
- **Sending hours** are the recipient's local time, from
  `business_settings` and the customer's zone, never the server's.
- **Exports are declared** within two hours of `packed_at`, once per
  order (`idempotency_key` unique), with the gateway's schema and nothing
  more.
- **Back-office reads are allowed**: the company's policy lets
  `shop_reports` read names and e-mail addresses (it answers
  customers); what leaves the shop's database is what the policy rules.

## The traps

- **Two places for one fact.** `marketing_opt_in` and `consent_events`
  agree at load and the web shop writes both, but a job reading the flag
  is a fault vector: any lag or a single missed write makes it lie.
- **Lifetime value and last order come from the archive.** Recomputing
  them from `orders` drops two years of history; a roll-up comparing
  them with `orders` never matches.
- **A recipient's zone is not the customer's company zone.** One
  recipient in five is elsewhere; at −8 h they are outside their hours
  before 16:00 company time, at +5 h from 16:00.
- **Shift invariance.** Every zone in the data is relative to the
  customer's, so nothing vanishes at a shift of 0; a fault that takes a
  wrong zone takes it as an offset from the customer's, never UTC.
- **The consent history is quieter than the producer.** The backup's
  history holds few events in its last weeks; at T0 the producer starts
  at 20 withdrawals and 30 grants an hour, the volume the invariants
  need. Read it as the campaign's launch, not as a fault.
- **`shop_refresh` holds only `MAINTAIN`.** It cannot read the view or
  its inputs; it refreshes (plain or `CONCURRENTLY`, the view has a
  unique index) because the refresh runs as the view's owner.

## Loading

`schema.sql` then `load.sql`, one `psql` session, as `postgres`, with
both variables set: about 15 seconds into an unconstrained `postgres`
image. `load.sql` stops at once when either variable is missing, or when
the zone is not UTC plus the offset.
