# Probe — purpose-day-boundary-wrong-zone

Descriptive only. As `player` on the target node, after a night's close:
`psql -d <database> -c '\sf rpt.close_day'` shows `SET "TimeZone" TO
'Etc/GMT…'`, another zone than `SELECT timezone FROM
rpt.business_settings`, and the day cut in `current_setting('TimeZone')`.
`SELECT day_local, orders, revenue FROM rpt.sales_daily WHERE closed
ORDER BY 1 DESC LIMIT 1` against the source's `SELECT count(*),
sum(total) FROM orders, business_settings s WHERE (placed_at AT TIME
ZONE s.timezone)::date = '<that day>'` (from the bastion, on the source
node) shows different orders and revenue.

Expected: the closed day differs from the shop's local day, and the
procedure's zone is `offset` hours off the customer's.
