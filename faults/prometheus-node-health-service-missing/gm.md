# prometheus-node-health-service-missing — GM notes

**What.** The node-health script on `{NODE}` watches every service of the
node but its main one, `{SERVICE}`: this parameter fault removes it from
the node's entry in the `node_health` map at rendering (a `default` entry
is first expanded to the brick's processes; on a postgres node `[postgres,
sshd]` becomes `[sshd]`). The node's `node.conf` lists the others only.

**Why it matters.** The node shows healthy while its database is down:
"Service down on a node" (`gm-service-down`) evaluates
`node_health_service_up`, and there is no series for `{SERVICE}` to go to
0. The one service that matters most on the node is the one no one
watches. At rest the evidence is the service *missing*, not *down*: a
player who only looks for red finds nothing.

**Why it happens.** A monitoring agent's service list written for a
generic server and never adapted; a service renamed during a migration;
"we watch sshd so we know the box is up".

**What a good answer says.** Compares the node's service list
(`/opt/gm/node-health/node.conf`, or the "Services: up or down, per node"
panel, or `node_health_service_up{node="{NODE}"}` in Prometheus) with the
services the node actually runs, names `{SERVICE}` as missing, and
explains that its outage would not be seen. A proposal adds it to the list.
The players cannot change it: the configuration is mounted read-only by
the platform (D92), so this is *report* or *propose* only, even on a
fixable node. A good answer may also point at an application-level check
(for postgres, the exporter's `pg_up` and "Exporter disconnected from
PostgreSQL").

**Fix path.** None for the players. Whoever runs the platform puts the
service back into the node's `node_health` entry and redeploys.

**Sealed check.** On the prometheus node as root, `curl
http://{NODE}:9110/metrics`, on the endpoint, not Prometheus: *present*
while the endpoint answers without a `node_health_service_up` series for
`service="{SERVICE}"`, *fixed* when the series is there (up or down);
exit 2 when the endpoint does not answer. It reads *present* for the
whole game.

**Placement (no masking).**
- `prometheus-scrape-target-missing` never on `{NODE}`: the node would
  vanish from Prometheus and the dashboard, hiding this fault's
  dashboard and Prometheus evidence (`node.conf` would remain).
- `prometheus-node-health-node-missing` never on `{NODE}`: there would be
  no script at all.
- With `grafana-alert-for-too-long` on `gm-service-down`: both weaken "an
  alert when the database's service stops" without hiding each other's
  evidence (this one is in the node's service list, that one in the rule's
  pending period). One issue may cover both; each is still a finding.

**Feedback points.** Monitoring is only as good as what it is told to
watch; reading a green dashboard for what it does not show; checking the
service list against the node's purpose.
