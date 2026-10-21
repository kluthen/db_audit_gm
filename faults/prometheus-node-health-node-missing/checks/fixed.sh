#!/bin/sh
# Sealed check of prometheus-node-health-node-missing (master spec 8.1;
# capture W4, fault 2). Run as root on the prometheus node. Exit 0 once
# $FAULT_NODE's node-health endpoint answers with samples for that node,
# 1 while it does not (no answer, or no sample labelled with the node), 2 on
# an error ($FAULT_NODE does not resolve).
#
# On the endpoint, not on Prometheus: the result does not depend on whether
# Prometheus scrapes the node (prometheus-scrape-target-missing). The fault
# is report or propose only; this check reads present for the whole game.
set -u
url="http://$FAULT_NODE:9110/metrics"

body=$(curl -s -m 5 "$url" 2>/dev/null)
rc=$?
if [ "$rc" -eq 6 ]; then
    echo "$FAULT_NODE does not resolve from the prometheus node."
    exit 2
fi
if [ "$rc" -eq 0 ] && printf '%s\n' "$body" | grep -q "^node_health_[a-z_]*{.*node=\"$FAULT_NODE\""; then
    echo "$FAULT_NODE runs the node-health script: $url answers with its samples."
    exit 0
fi
if [ "$rc" -ne 0 ]; then
    echo "$FAULT_NODE has no node-health endpoint: $url does not answer (curl exit $rc)."
else
    echo "$FAULT_NODE's port 9110 answers, but with no node-health sample for $FAULT_NODE."
fi
exit 1
