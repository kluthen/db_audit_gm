# Probe — grafana-alert-for-too-long

Descriptive only. As `player`:

1. Through the web front (tools password), `/grafana/alerting/list`:
   rule `{RULE}` ("Service down on a node" for `gm-service-down`) shows a
   pending period of 2h; every other rule shows 1m.
2. On the grafana node (`ssh grafana`): `grep -n -e 'uid:' -e 'for:'
   /etc/grafana/provisioning/alerting/alert-rules.yaml` shows `for: 2h`
   under `uid: {RULE}`.

Expected: both from the start of the game.
