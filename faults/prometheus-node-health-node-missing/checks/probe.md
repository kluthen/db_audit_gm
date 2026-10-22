# Probe — prometheus-node-health-node-missing

Descriptive only. As `player`:

1. Through the web front (tools password), `/prometheus/targets`:
   `{NODE}:9110` in the `node-health` job is down, "connection refused".
2. Through the web front, `/grafana/alerting/list`: "Scrape target down"
   is firing for `{NODE}:9110`, within about 2 minutes of the start.
3. On `{NODE}` (`ssh {NODE}`): `ls /opt/gm/node-health` fails (no such
   file or directory); on any other node it lists `node.conf`.

Expected: 1 and 3 from the start of the game, 2 within about 2 minutes.
