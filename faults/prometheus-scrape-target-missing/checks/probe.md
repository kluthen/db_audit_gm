# Probe — prometheus-scrape-target-missing

Descriptive only. As `player`:

1. Through the web front (tools password), `/prometheus/targets`: the
   `node-health` job lists one target fewer than the topology has nodes;
   `{NODE}:9110` is not there (absent, not down).
2. On the prometheus node (`ssh prometheus`): `grep -n 9110
   /etc/prometheus/prometheus.yml` shows the targets without
   `{NODE}:9110`; `curl -s {NODE}:9110/metrics | grep '^node_health_cpu'`
   prints samples labelled `node="{NODE}"`: the endpoint answers.
3. Through the web front, `/grafana/d/node-health`: `{NODE}` is in no
   panel's legend.

Expected: all three from the start of the game. The bastion has no
`curl`; the endpoint is read from the prometheus node.
