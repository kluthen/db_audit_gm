# Story

Tarnbeck Outdoor sells camping and hiking gear online, across Europe and
beyond. Its web shop writes into one PostgreSQL database through
PgBouncer. Lumen Analytics, a BI agency, keeps the back office's figures
on a reporting database of its own, which its roll-ups fill hourly and
nightly; the marketing team mails win-back campaigns and shipping
notices, and the shipping manager declares exports to the customs
gateway. The company works in {{customer_timezone}}. Prometheus and
Grafana watch the shop's database. The company's data policy is in
`data-policy.md`.
