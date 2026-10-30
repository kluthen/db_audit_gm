# Tarnbeck Outdoor

Tarnbeck Outdoor sells camping and hiking gear online: tents, sleeping
bags, boots, stoves and the rest, about 30 000 orders a day in the busy
season, from a team of twenty. The company works in
{{customer_timezone}}: every time of day in this story and in the issues
is in that zone. The busiest hour of the day is lunchtime, from noon to
one; nights are quiet, apart from the carriers, whose delivery events
arrive day and night.

## The system

- **The web shop** (the `producer` machine) is the shop's application:
  checkout (the order, its lines, the stock and the customer's last
  order, then the payment provider's authorisation, which takes a few
  seconds, before the order is committed), the catalogue pages, the order
  pages, the warehouse's packing and shipping updates, the carriers'
  delivery feed, and the close of day: once a day it invoices what was
  shipped and refreshes each customer's lifetime value and each product's
  sales. It reaches the database through the connection pooler (`pooler`,
  PgBouncer). Its code and its fixed-time jobs are Tarnbeck's own: you may
  change them.
- **The back office** (the `consumer` machine) is the staff's
  application: the home page's latest orders, the warehouse screen's
  dashboard, the "best days" sales report, the nightly roll-up of
  yesterday's sales at 1:30, and the accounting export for the
  accountant at 2:00. It goes straight to the database. Its code is
  maintained by an agency; Tarnbeck may change only its fixed-time jobs.
- **The database** (`db`, PostgreSQL 18) holds everything: customers,
  products, orders and their lines, the carriers' delivery events, the
  daily sales. It was moved to a new server three weeks ago.
- **Monitoring**: Prometheus, a PostgreSQL exporter and Grafana, set up
  last year by the developer who built the shop. Every machine reports
  its own health; the dashboards show the database and the machines.
  Nobody has looked at the monitoring's configuration since the move.

## Why you are here

The developer who built the shop left in the summer; since then the shop
has been run by Ines Varga, the operations manager, with help from Jonas,
who looks after the servers part-time. Over the last weeks: lunchtime
slowdowns that customers complain about on social media, deliveries
counted twice, an accounting export that comes too late, and this
morning, order pages that suddenly got slower. Customers also land on
the shop's error page now and then; nobody has had time to look into it.
Ines would like an audit of the database and of what runs around it, the
problems in the issues fixed where Tarnbeck may fix them, and clear
recommendations where it may not.

The shop is live while you work: orders keep coming in, and nobody will
stop or slow the traffic for you.
