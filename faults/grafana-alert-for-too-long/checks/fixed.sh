#!/bin/sh
# Sealed check of grafana-alert-for-too-long (master spec 8.1; capture W4,
# fault 5). Run as root on the grafana node. Exit 0 once alert rule
# $FAULT_RULE exists in Grafana's live state, is not paused and waits at
# most $FAULT_MAX_FOR before firing; 1 while it is missing, paused or
# waits longer; 2 on an error (Grafana does not answer, an unreadable
# answer, $FAULT_MAX_FOR not a duration).
#
# Live state through Grafana's provisioning API (the brick's helper, which
# reads the administrator's password on the node): a file edited but not
# reloaded still reads present; a change made through the API counts.
set -u
api=/usr/local/lib/gm/grafana-api

body=$("$api" GET "/api/v1/provisioning/alert-rules/$FAULT_RULE" 2>/dev/null)
rc=$?
case $rc in
    0) ;;
    1)
        echo "alert rule $FAULT_RULE does not exist in Grafana (the API refused GET /api/v1/provisioning/alert-rules/$FAULT_RULE)."
        exit 1 ;;
    *)
        echo "Grafana does not answer on this node (grafana-api exit $rc)."
        exit 2 ;;
esac

# Durations as Grafana and Prometheus write them: 1m, 2h, 1h30m, 2h0m0s,
# 90s, 500ms, 0s; "0" alone allowed.
r=$(printf '%s' "$body" | jq -r --arg max "$FAULT_MAX_FOR" '
    def secs:
      if . == "0" then 0
      elif test("^([0-9]+(\\.[0-9]+)?(ms|s|m|h|d|w|y))+$") then
        [scan("([0-9]+(?:\\.[0-9]+)?)(ms|s|m|h|d|w|y)")
         | (.[0] | tonumber) * {"ms": 0.001, "s": 1, "m": 60, "h": 3600,
                                "d": 86400, "w": 604800, "y": 31536000}[.[1]]]
        | add
      else error("not a duration: \(.)") end;
    "\(.isPaused // false) \(.for // "0s") \((.for // "0s") | secs) \($max | secs)"
' 2>&1) || { echo "cannot read rule $FAULT_RULE's pending period (or $FAULT_MAX_FOR is not a duration): $(printf '%s' "$r" | head -n 1)"; exit 2; }

set -- $r
paused=$1 for=$2 secs=$3 max=$4
if [ "$paused" = true ]; then
    echo "alert rule $FAULT_RULE is paused: it never fires."
    exit 1
fi
if awk -v a="$secs" -v b="$max" 'BEGIN { exit !(a + 0 <= b + 0) }'; then
    echo "alert rule $FAULT_RULE waits $for before firing, at most $FAULT_MAX_FOR."
    exit 0
fi
echo "alert rule $FAULT_RULE still waits $for before firing, longer than $FAULT_MAX_FOR."
exit 1
