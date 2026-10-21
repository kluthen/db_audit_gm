# prometheus-scrape-target-missing — GM notes

**What.** The scenario's `prometheus.yml` leaves one node's node-health
endpoint (`{NODE}:9110`) out of the `node-health` job. The node runs the
node-health script and answers on its endpoint; Prometheus never asks. A
tool starved of information: everything built on Prometheus is silent
about that node.

**Why it matters.** Monitoring that does not know a node cannot warn
about it. The node is in no node-health panel, and no alert can fire for
it: "Scrape target down" (`gm-target-down`) evaluates `up`, which exists
only for targets Prometheus knows. The dashboards look complete because
nothing on them says a node is missing. That "no alert on a target down"
is the consequence of the missing target, not a second defect: the rule
is still there and works for every other node.

**Why it happens.** A node added (or renamed) after the scrape
configuration was written; a target list copied from another environment;
a target commented out during maintenance and never put back.

**What a good answer says.** Compares the targets page with the topology
and names the node missing from the `node-health` job; shows the endpoint
answers (`curl -s {NODE}:9110/metrics` from the prometheus node; the
bastion has no `curl`), so the gap is in the configuration, not on the
node; notes that no alert covers the node. A proposal adds the target and
reloads; a better one keeps the target list in step with the topology and
checks the targets page after each change.

**Fix path.** On the prometheus node, as `player`: add `'{NODE}:9110'` to
the `node-health` job's `targets` in `/etc/prometheus/prometheus.yml`
(writable by `promconf`), then `sudo gm-reload-prometheus`. The wrapper
checks the file with `promtool` first and refuses a broken one. The node's
samples appear at the next scrape (15 s).

**Sealed check.** On the prometheus node as root, on Prometheus' live
state: an instant query through `promtool query instant` for
`node_health_sample_age_seconds{node="{NODE}"}`. *Fixed* when it has a
sample, *present* when it is empty; exit 2 when Prometheus is not ready. A
file edited but not reloaded reads *present*; so does a target added in
the last few seconds, before its first scrape. Any job counts: the metrics
carry the node's name in their own `node` label.

**Placement (no masking).**
- Never on the database node when `prometheus-node-health-service-missing`
  targets it: that fault's evidence is on the node-health dashboard and in
  Prometheus, which this fault empties for the node.
- Never on the node of `prometheus-node-health-node-missing`: that fault's
  evidence is a target down and its alert firing, which need the target.
  With faults 1, 2 and 3 of the v0.2 set, each sits on a different node.
- The node-health job only: never remove the PostgreSQL exporter's target
  (`<exporter>:9187`), which would hide `pg-stat-statements-not-preloaded`
  and every PostgreSQL panel.

**Feedback points.** Reading the targets page against the topology; the
difference between a target down (Prometheus knows and complains) and a
target absent (silence); `up` and target-down alerts only cover what is
scraped.
