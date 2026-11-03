# Tarnbeck Outdoor, six months on

Tarnbeck Outdoor sells camping and hiking gear online: tents, sleeping
bags, boots, stoves and the rest, about 30 000 orders a day in the busy
season. The company works in {{customer_timezone}}: every time of day in
this story, in the issues and in the data policy is in that zone. The
busiest hour is lunchtime; nights are quiet, apart from the carriers,
whose delivery events arrive day and night.

Six months ago an audit sorted out the shop's lunchtime slowdowns. Since
then the shop has started selling abroad, outside the customs union too,
and a lot more now runs around its database.

## The system

- **The web shop** (the `producer` machine): checkout, the catalogue, the
  order pages, the warehouse's packing and shipping updates, the
  carriers' delivery feed, the customers' consent to marketing e-mail
  (the newsletter box at checkout, the unsubscribe link in every mail),
  and the close of day at noon, which invoices what was shipped. It
  reaches the database through the connection pooler (`pooler`,
  PgBouncer). A release of the web shop went out yesterday evening. Its
  code and its fixed-time jobs are Tarnbeck's own: you may change them.
- **The shop's database** (`db`, PostgreSQL 18) holds everything:
  customers and their consent history, products, orders and their
  lines, the carriers' events, the campaigns, the mail and customs
  outboxes. The web shop's best-sellers list is a materialized view the
  database server refreshes every hour from its own crontab.
- **The marketing team's jobs** (the `crm` machine), in-house: the
  win-back campaign (an hourly extraction of lapsed customers as leads,
  then e-mails to them every quarter hour through the day, best score
  first) and the shipping notices, every five minutes. The mail provider
  sends whatever lands in the mail outbox.
- **The shipping manager's jobs**, on the same machine: an export
  declaration to the customs gateway for every order packed for a
  country outside the customs union, every five minutes. The gateway
  acknowledges each one on its callback (the `gateway` machine), and a
  job every quarter hour raises an incident for the shipping manager on
  any declaration that went wrong.
- **Lumen Analytics**, a BI agency, keeps the back office's figures for
  Tarnbeck. Lumen moved them to a reporting database of its own
  (`reporting`, PostgreSQL 18) and runs the roll-ups that fill it from
  its own machine (`bi`): an hourly roll-up of the day's sales, and a
  nightly close of yesterday's at 1:30. Lumen also built a churn table
  for a dashboard, refreshed by a job inside the reporting database, and
  a nightly sales-detail roll-up run from the reporting server's own
  crontab. The back office's dashboards (the `consumer` machine) read
  the reporting database. `reporting` and `bi` are Lumen's systems:
  Tarnbeck can ask Lumen for changes there, not make them.
- **Monitoring**: Prometheus, a PostgreSQL exporter and Grafana watch the
  shop's database, and every machine reports its own health.

## Why you are here

Ines Varga, the operations manager, has had a bad week. Customers who
unsubscribed still get the win-back e-mails, some customers get every
shipping notice twice, a customer abroad got a promotion in the middle
of his night, the accountant's revenue never matches the dashboard, and
this morning the dashboards froze. Lumen also mentions that the
reporting database "restarted itself" one night this week, and says it
is fine now.

Ines would like an audit of the shop's data and of everything that
moves it: the problems in the issues fixed where Tarnbeck may fix them,
and clear recommendations, for Tarnbeck or for Lumen, where it may not.
With the story she hands over the company's data policy
(`data-policy.md`): she expects it to hold wherever the company's data
goes.

The shop is live while you work: orders keep coming in, and nobody will
stop or slow the traffic for you.
