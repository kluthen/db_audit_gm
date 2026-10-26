#!/bin/sh
# Scenario smoke deployment of gmctl on a real single-node swarm (build plan
# v0.2, "Wave gate": from wave 4, the v0.2 scenario and bookshop-new-server;
# run after smoke.sh and smoke-monitoring.sh, never at the same time as
# either or as another run of itself: all publish the bastion's ports).
#
# On a copy of a scenario as it is in the repository (scenarios/<scenario>,
# without any local implementation):
#   fit (the playground the scenario was designed for: its single
#   designed_for host, by name, with that host's CPU, memory and disk;
#   images read from the engine) -> render -> deploy -> load-data -> inject,
#   then:
#   - check: one line per fault instance, in fault_instances order, every
#     sealed check at 1 (present) and the command exiting 1; polled for up
#     to 120 s, a check reading Prometheus' live state lagging up to one
#     scrape interval behind;
#   - validate: the verdicts the answer key gives at hand-over. A node is
#     expected red when an instance's evidence is "the public validator on
#     <node>" showing a RED line, or when validators_left_red names it; each
#     such rule must be among that node's RED lines. Every other node is
#     expected green. Exit 1 when a node is expected red, else 0;
#   - the evaluation changed no stage (injected);
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# No credential goes on a command line or in `gmctl exec --env`: the script
# reads none; the sealed checks and the validators read theirs inside the
# nodes.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the scenario's bricks' images
# built locally (fit refuses a missing one and names its build command):
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.3.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.2.0 bricks/grafana
# Host ports 2222 and 8080 must be free (the bastion's published ports).
# Usage: sh tools/tests/smoke-scenario.sh <scenario>        (from anywhere)
#   e.g. sh tools/tests/smoke-scenario.sh fernway-clinics-monitoring
#        sh tools/tests/smoke-scenario.sh bookshop-new-server
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
started=$(date +%s)

[ $# -eq 1 ] || { echo "usage: sh $0 <scenario>   (a folder of $REPO/scenarios)" >&2; exit 2; }
NAME=$1
[ -f "$REPO/scenarios/$NAME/scenario.yaml" ] && [ -f "$REPO/scenarios/$NAME/gm/answer-key.yaml" ] \
    || { echo "no scenario $NAME in $REPO/scenarios" >&2; exit 2; }

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

# Objects on the engine that do not carry the game's labels, one per line.
others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
}

# Everything still carrying one of the game's labels, one per line.
labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}

# scn <what>: read from the scenario copy's scenario.yaml and answer key.
#   playground  "<host> <cpu> <memory> <disk>" of its single designed_for host
#   checks      "<instance> <fault-id>: present" per fault instance, in order
#   verdicts    "<node> green|red, ..." in nodes order, as validate's last line
#   red         "<node> <rule>" per RED line the answer key expects
scn() {
    python3 - "$SCN" "$1" <<'EOF'
import re, sys, yaml
scn, what = sys.argv[1], sys.argv[2]
s = yaml.safe_load(open(scn + "/scenario.yaml"))
key = yaml.safe_load(open(scn + "/gm/answer-key.yaml"))
red = []
for inst in key.get("instances") or []:
    for ev in inst.get("evidence") or []:
        m = re.match(r"the public validator on (\S+)$", str(ev.get("source", "")).strip())
        r = re.match(r"RED (\S+?):", str(ev.get("shows", "")).strip())
        if m and r:
            red.append((m.group(1), r.group(1)))
    for left in inst.get("validators_left_red") or []:
        r = re.match(r"(?:RED )?(\S+?):", str(left.get("rule", "")).strip())
        red.append((left["node"], r.group(1) if r else ""))
if what == "playground":
    hosts = s["designed_for"]["hosts"]
    if len(hosts) != 1:
        sys.exit("designed for %d hosts: this smoke run needs a single one" % len(hosts))
    h = hosts[0]
    print(h["name"], h["cpu"], h["memory"], h["disk"])
elif what == "checks":
    for f in s["fault_instances"]:
        print("%s %s: present" % (f["id"], f["fault"]["id"]))
elif what == "verdicts":
    reds = {n for n, _ in red}
    print(", ".join("%s %s" % (n["name"], "red" if n["name"] in reds else "green")
                    for n in s["nodes"]) + ".")
elif what == "red":
    for n, rule in sorted(set(red)):
        print(n, rule)
EOF
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-scenario.XXXXXX")
SCN=$tmp/$NAME
GAME=
deployed=no

cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
        left=$(labelled)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$REPO/scenarios/$NAME" "$SCN"
rm -rf "${SCN:?}/local"

host=$(scn playground) || exit 2
set -- $host
PG=$1 CPU=$2 MEMORY=$3 DISK=$4
LDIR=$SCN/local/$PG
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }

# --- local implementation ---------------------------------------------------
info "scenario $NAME"
info "gmctl fit (the $PG playground: $CPU CPU / $MEMORY / $DISK)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK"; then
    pass "fit: the images and the reservations fit $CPU CPU / $MEMORY / $DISK"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
info "gmctl render"
if $GMCTL render "$SCN" --playground "$PG"; then
    pass "render"
else
    fail "render"
    exit 1
fi
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- deployment -----------------------------------------------------------
info "gmctl deploy"
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: stack deployed and healthy"
else
    fail "deploy"
    exit 1
fi

# From here on, every check records its own result; keep going on failure.
set +e

same "status: stage deployed" deployed "$(stage)"

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
same "status: stage data-loaded" data-loaded "$(stage)"

info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
same "status: stage injected" injected "$(stage)"

# --- check: every sealed check at 1 ----------------------------------------
# verdicts <output>: the instance lines of gmctl check, without their reasons.
verdicts() { printf '%s\n' "$1" | sed 's/ — .*//'; }
expected=$(scn checks)
count=$(printf '%s\n' "$expected" | wc -l | tr -d ' ')
info "gmctl check, until every sealed check reads present (up to 120 s)"
i=0
while :; do
    out=$($GMCTL check "$SCN" --playground "$PG"); rc=$?
    { [ "$rc" = 1 ] && [ "$(verdicts "$out")" = "$expected" ]; } || [ "$i" -ge 24 ] && break
    i=$((i + 1)); sleep 5
done
printf '%s\n' "$out"
info "check: $((i + 1)) run(s), $((i * 5)) s waited"
same "check: exit 1 (faults present)" 1 "$rc"
same "check: every one of the $count sealed checks at 1 (present)" "$expected" "$(verdicts "$out")"

# --- validate: the verdicts the answer key gives at hand-over ---------------
# red_lines <validate output> <node>: the RED lines under the node's heading.
red_lines() {
    printf '%s\n' "$1" | awk -v h="$2:" '/^[^ ]/ { on = ($0 == h); next } on && /^  RED / { print }'
}
want=$(scn verdicts)
reds=$(scn red)
if [ -n "$reds" ]; then want_rc=1; else want_rc=0; fi
info "gmctl validate (expected: $want)"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "validate: exit $want_rc" "$want_rc" "$rc"
same "validate: verdicts" "Validators of game $GAME: $want" "$(printf '%s\n' "$out" | tail -n 1)"
if [ -n "$reds" ]; then
    printf '%s\n' "$reds" | while read -r node rule; do
        if red_lines "$out" "$node" | grep -q "^  RED $rule:"; then
            echo yes
        else
            echo "no: $node $rule"
        fi
    done > "$tmp/red-rules"
    same "validate: the answer key's RED lines ($(printf '%s' "$reds" | tr '\n' ',' | sed 's/,/, /g'))" \
        "$(printf '%s\n' "$reds" | sed 's/.*/yes/')" "$(cat "$tmp/red-rules")"
fi
same "evaluation changed no stage" injected "$(stage)"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "status: stage torn-down" torn-down "$(stage)"
same "nothing labelled with game $GAME is left" "" "$(labelled)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-scenario $NAME: all $passes checks passed in ${elapsed}s (game $GAME)"
else
    echo "smoke-scenario $NAME: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME)"
    exit 1
fi
