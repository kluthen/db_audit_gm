#!/bin/sh
# Sealed check of prometheus-node-health-service-missing (master spec 8.1;
# capture W4, fault 3). Run as root on the prometheus node. Exit 0 once
# $FAULT_NODE's node-health endpoint reports $FAULT_SERVICE (a
# node_health_service_up series for it, up or down), 1 while the endpoint
# answers without it, 2 on an error (the endpoint does not answer).
#
# On the endpoint, not on Prometheus. The fault is report or propose only;
# this check reads present for the whole game.
set -u
url="http://$FAULT_NODE:9110/metrics"

body=$(curl -fsS -m 5 "$url" 2>&1) \
    || { echo "$FAULT_NODE's node-health endpoint does not answer ($url): $(printf '%s' "$body" | head -n 1)"; exit 2; }

if printf '%s\n' "$body" | grep '^node_health_service_up{' \
        | grep -qF "service=\"$FAULT_SERVICE\""; then
    echo "$FAULT_NODE's node-health script reports $FAULT_SERVICE (node_health_service_up has its series)."
    exit 0
fi
listed=$(printf '%s\n' "$body" | sed -n 's/^node_health_service_up{.*service="\([^"]*\)".*/\1/p' \
    | tr '\n' ' ' | sed 's/ $//')
echo "$FAULT_NODE's node-health script does not report $FAULT_SERVICE; it reports only: ${listed:-no service}."
exit 1
