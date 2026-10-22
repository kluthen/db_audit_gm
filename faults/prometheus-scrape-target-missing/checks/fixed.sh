#!/bin/sh
# Sealed check of prometheus-scrape-target-missing (master spec 8.1; capture
# W4, fault 1). Run as root on the prometheus node. Exit 0 once Prometheus,
# in its live state, holds node-health samples for $FAULT_NODE, 1 while it
# holds none, 2 on an error (Prometheus not ready, a query refused).
#
# Live state, not the file: a target added to prometheus.yml but not
# reloaded still reads present. Any job counts, since the node-health
# metrics carry the node's name in their own `node` label. A target added
# a few seconds ago reads present until its first scrape (15 s interval).
set -u
base=http://127.0.0.1:9090/prometheus

curl -fsS -m 5 -o /dev/null "$base/-/ready" 2>/dev/null \
    || { echo "Prometheus is not ready on this node (GET $base/-/ready failed)."; exit 2; }

expr="node_health_sample_age_seconds{node=\"$FAULT_NODE\"}"
out=$(promtool query instant "$base" "$expr" 2>&1) \
    || { echo "promtool query instant failed for $expr: $(printf '%s' "$out" | head -n 1)"; exit 2; }

if printf '%s\n' "$out" | grep -q '^node_health_sample_age_seconds{'; then
    echo "Prometheus scrapes $FAULT_NODE's node-health endpoint: $expr has a sample."
    exit 0
fi
echo "Prometheus holds no node-health sample for $FAULT_NODE: its :9110 target is not scraped."
exit 1
