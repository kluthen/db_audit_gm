# Probe — prometheus-node-health-service-missing

Descriptive only. As `player`:

1. On `{NODE}` (`ssh {NODE}`): `cat /opt/gm/node-health/node.conf` shows
   a `services=` line without `{SERVICE}`; the same file on another node
   lists that node's main service.
2. Through the web front (tools password), `/grafana/d/node-health`, the
   "Services: up or down, per node" panel: `{NODE}` shows its other
   services only.
3. Through the web front, `/prometheus/query`:
   `node_health_service_up{node="{NODE}"}` returns no series with
   `service="{SERVICE}"`.

Expected: all three from the start of the game (2 and 3 once Prometheus
has scraped the node, within 15 seconds).
