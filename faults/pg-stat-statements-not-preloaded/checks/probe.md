# Probe — pg-stat-statements-not-preloaded

Descriptive only. As `player`:

1. On the bastion: `psql -h {database node} -d postgres -c 'SELECT * FROM
   pg_stat_statements LIMIT 1'` fails with "pg_stat_statements must be
   loaded via shared_preload_libraries"; `psql -h {database node} -c 'SHOW
   shared_preload_libraries'` does not name it.
2. Through the web front (tools password), `/grafana/d/postgresql`: the
   four statement panels show "No data", "Exporter connected to
   PostgreSQL" shows 1.
3. Through the web front, `/prometheus/query`:
   `pg_scrape_collector_success{collector="stat_statements"}` is 0.

Expected: all three from the start of the game, with no load (2 and 3
once Prometheus has scraped the exporter, within 15 seconds).
