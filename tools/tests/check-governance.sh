#!/bin/sh
# The governance check set's baseline proof (v0.4 master spec 11.6, 18
# item 4; capture W3-a item 6): on a deployed game, the scenario's
# governance holds. Runs `check_governance G1 G2 G3 G4` on the first
# `database` node and `check_governance G3` on every `transformer` node,
# each through `gmctl exec --user root` with CHECK_GOVERNANCE (the
# scenario's, from tools/gm/governance.py) and CHECK_SINCE, the text sent
# as `gmctl check` sends a sealed check calling the set
# (tools/gm/governance.sh, a newline, then the call).
#
# Usage: sh tools/tests/check-governance.sh <scenario-dir> <playground> [<since>]
#   <since>: CHECK_SINCE for G4, YYYY-MM-DDTHH:MM:SSZ (default: an hour ago).
#   e.g. sh tools/tests/check-governance.sh tools/tests/fixtures/fixture-campaign armenelos
#
# Prints each node's run under a `<node>:` heading and exits as `gmctl
# check` combines: 2 when a run could not judge or could not start, else 1
# when a rule is broken, else 3 when G4 had an outbox with no row since
# <since>, else 0. Docker steps: run it under the host lock
# (flock /tmp/dbagm-docker.lock sh tools/tests/check-governance.sh ...).
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 -B $REPO/tools/gmctl"

[ $# -ge 2 ] && [ $# -le 3 ] || {
    echo "usage: sh $0 <scenario-dir> <playground> [<since>]" >&2
    exit 2
}
SCN=$(cd "$1" && pwd) || exit 2
PG=$2
SINCE=${3:-$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)}
case $SINCE in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "since $SINCE: expected YYYY-MM-DDTHH:MM:SSZ" >&2; exit 2 ;;
esac

gov=$(cd "$REPO" && python3 -B -m tools.gm.governance env "$SCN") || exit 2
nodes=$(python3 -B - "$SCN/scenario.yaml" <<'EOF'
import sys, yaml
s = yaml.safe_load(open(sys.argv[1]))
db = [n["name"] for n in s["nodes"] if n.get("role") == "database"]
if db:
    print(db[0], "G1 G2 G3 G4")
for n in s["nodes"]:
    if n.get("role") == "transformer":
        print(n["name"], "G3")
EOF
) || exit 2
[ -n "$nodes" ] || { echo "$SCN: no database node" >&2; exit 2; }

worst=0
rank() { case $1 in 2) echo 3 ;; 1) echo 2 ;; 3) echo 1 ;; *) echo 0 ;; esac; }
for line in $(printf '%s\n' "$nodes" | tr ' ' ':'); do
    node=${line%%:*}
    rules=$(printf '%s' "${line#*:}" | tr ':' ' ')
    echo "$node:"
    out=$(printf 'out=$(check_governance %s); rc=$?\nprintf "%%s\\n" "$out"\nexit $rc\n' "$rules" \
        | (cd "$REPO" && python3 -B -m tools.gm.governance text -) \
        | $GMCTL exec "$SCN" --playground "$PG" --node "$node" --user root \
            --env "CHECK_GOVERNANCE=$gov" --env "CHECK_SINCE=$SINCE" 2>&1)
    rc=$?
    printf '%s\n' "$out" | sed 's/^/  /'
    echo "  (exit $rc)"
    case $rc in 0|1|2|3) ;; *) rc=2 ;; esac
    [ "$(rank "$rc")" -gt "$(rank "$worst")" ] && worst=$rc
done
exit "$worst"
