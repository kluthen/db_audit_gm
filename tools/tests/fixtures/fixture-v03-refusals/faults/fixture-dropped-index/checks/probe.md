# Probe

As `player` on `db`: `psql -d shop -c '\d orders'` lists no index on
`customer_id`, and `EXPLAIN SELECT * FROM orders WHERE customer_id = 42`
shows a sequential scan.
