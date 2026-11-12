# Probe — pg-monitoring-option-absent

Descriptive only. As `player`:

1. On the bastion, `psql -h {node} -d postgres -c '\du'`: no role
   `monitoring`.
2. On the node, `grep -h monitoring /var/log/postgresql/postgresql-*.log |
   tail -n 5`: the exporter's logins refused, `password authentication
   failed for user "monitoring"`, `Role "monitoring" does not exist`.
3. On the exporter's node, `curl -s localhost:9187/metrics | grep
   '^pg_up'` (or the dashboard): `pg_up 0`.

Expected: 1 at any time; 2 and 3 from the exporter's first scrape.
