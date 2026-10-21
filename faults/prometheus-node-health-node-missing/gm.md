# prometheus-node-health-node-missing — GM notes

**What.** One node, `{NODE}`, gets no node-health script: the scenario's
`node_health` map lists it, and this parameter fault removes its entry at
rendering, so the GM mounts nothing into it. Prometheus still has
`{NODE}:9110` among its targets and finds nothing there.

**Why it matters.** The node's CPU, memory, disk and services are
monitored nowhere: a full disk or a stopped service on `{NODE}` would go
unnoticed. Unlike `prometheus-scrape-target-missing`, the gap is not
silent: the target is down and "Scrape target down" fires for it. The
finding is that the alert is real, not noise to live with.

**Why it happens.** A node added after the monitoring agent was rolled
out; an agent left off a node thought unimportant; an alert that fired so
long that everybody stopped reading it.

**What a good answer says.** The targets page (`{NODE}:9110` down,
connection refused), the firing alert, and the node itself (`ssh {NODE}`:
no `/opt/gm/node-health/`, while every other node has it), hence a node
with no agent rather than a network or Prometheus problem. A proposal
deploys the script on the node as on the others. The players cannot do it
themselves: the script and its configuration are mounted read-only by the
platform (D92), so this is *report* or *propose* only, even on a fixable
node.

**Fix path.** None for the players. Whoever runs the platform adds the
node back to the `node_health` map and redeploys.

**Sealed check.** On the prometheus node as root, `curl -s -m 5
http://{NODE}:9110/metrics`, on the endpoint itself, not on Prometheus,
so it does not depend on `prometheus-scrape-target-missing`. *Present*
while the endpoint gives no answer, or no sample labelled
`node="{NODE}"`; *fixed* when it answers for the node; exit 2 when the
name does not resolve. It reads *present* for the whole game.

**Placement (no masking).**
- Never on the node of `prometheus-scrape-target-missing`: without the
  target, Prometheus does not know the node, the target is not down and
  the alert never fires, so this fault's main evidence disappears.
- Not with `prometheus-node-health-service-missing` on the same node:
  that fault needs the script.
- The scenario keeps `gm-target-down` in Grafana's alert rules
  (`grafana-alert-for-too-long` targets `gm-service-down`, never this
  rule).

**Timing.** The target is down from Prometheus' first scrape; the alert
fires about 2 minutes after the start (`for: 1m`, evaluated every
minute).

**Feedback points.** A target down versus a target absent; an alert that
always fires is still an alert; checking the node rather than the
dashboard.
