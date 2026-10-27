#!/bin/sh
# Scenario smoke deployment of gmctl on a real single-node swarm (build plan
# v0.2, "Wave gate": from wave 4, the v0.2 scenario and bookshop-new-server;
# rewritten for load by v0.3 chunk 12, master spec 11, "Smoke tests"; run
# after smoke.sh, smoke-monitoring.sh and smoke-load.sh, never at the same
# time as any of them or as another run of itself: all publish the
# bastion's ports).
#
# On a copy of a scenario as it is in the repository (scenarios/<scenario>,
# or a scenario folder given by its path, without any local implementation):
#   fit (the playground the scenario was designed for: its single
#   designed_for host, by name, with that host's CPU, memory and disk;
#   images read from the engine) -> render -> deploy -> load-data -> inject.
#   A scenario with scheduler nodes (spec D157, D158) is a short game with
#   load: rendered with --handover (a whole hour past now plus its aging
#   minimum), then start-load (T0; the early check's host timer armed), the
#   faults due during the aging planted at once with inject --at now (a test
#   harness, never a game), and a few minutes of schedules (LOAD_MINUTES, 3
#   by default) after which every scheduler key is running: summarised every
#   minute since T0 by its scheduler, with calls, and counted in its
#   metrics. A scenario with none is rendered without --handover and has no
#   start-load, as in v0.2. Then:
#   - check: one line per fault instance, in fault_instances order, every
#     sealed check at 1 (present) and the command exiting 1; polled for up
#     to 120 s, each run within a time limit (CHECK_TIMEOUT, 180 s), a check
#     reading Prometheus' live state lagging up to one scrape interval
#     behind;
#   - validate: the verdicts the answer key gives at hand-over. A node is
#     expected red when an instance's evidence is "the public validator on
#     <node>" showing a RED line, or when validators_left_red names it; each
#     such rule must be among that node's RED lines. Every other node is
#     expected green. Exit 1 when a node is expected red, else 0;
#   - the evaluation changed no stage (injected; load-started with load);
#   -> teardown, then nothing labelled with the game id is left (its
#   systemd user timers and services included) and the objects not
#   belonging to the game are unchanged.
#
# No credential goes on a command line or in `gmctl exec --env`: the script
# reads none; the sealed checks and the validators read theirs inside the
# nodes.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, the user's systemd manager
# (systemctl --user) for a scenario with scheduler nodes, and the
# scenario's bricks' images built locally (fit refuses a missing one and
# names its build command):
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.3.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.2.0 bricks/grafana
#   docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.0 bricks/pgbouncer
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.1.0 bricks/scheduler
# Host ports 2222 and 8080 must be free (the bastion's published ports).
# Usage: sh tools/tests/smoke-scenario.sh <scenario>        (from anywhere)
#   e.g. sh tools/tests/smoke-scenario.sh fernway-clinics-monitoring
#        sh tools/tests/smoke-scenario.sh bookshop-new-server
#        sh tools/tests/smoke-scenario.sh path/to/a/scenario-folder
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
LOAD_MINUTES=${LOAD_MINUTES:-3}
CHECK_TIMEOUT=${CHECK_TIMEOUT:-180}    # seconds one gmctl check run may take
started=$(date +%s)

[ $# -eq 1 ] || { echo "usage: sh $0 <scenario>   (a folder of $REPO/scenarios, or a path)" >&2; exit 2; }
case $1 in
    */*) SRC=$(cd "$1" 2>/dev/null && pwd) || { echo "no folder $1" >&2; exit 2; } ;;
    *) SRC=$REPO/scenarios/$1 ;;
esac
NAME=$(basename "$SRC")
[ -f "$SRC/scenario.yaml" ] && [ -f "$SRC/gm/answer-key.yaml" ] \
    || { echo "no scenario $1 (no scenario.yaml and gm/answer-key.yaml in $SRC)" >&2; exit 2; }

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

# The game's systemd user units (loaded, or as files), one per line; none
# when the user's manager does not answer, as in a game with no timer.
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
STAMP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/systemd/timers
units() {
    {
        systemctl --user list-units --all --plain --no-legend "dbagm-${GAME}_*" 2>/dev/null \
            | awk '{ print $1 }'
        systemctl --user list-unit-files --no-legend "dbagm-${GAME}_*" 2>/dev/null \
            | awk '{ print $1 }'
        for f in "$UNIT_DIR"/"dbagm-${GAME}_"* "$STAMP_DIR"/"stamp-dbagm-${GAME}_"*; do
            [ -e "$f" ] && echo "file $f"
        done
    } | sort -u
}

# scn <what>: read from the scenario copy's scenario.yaml and answer key.
#   playground  "<host> <cpu> <memory> <disk>" of its single designed_for host
#   aging       its aging minimum in seconds, empty with no scheduler node
#   schedulers  "<node>" per scheduler node, in nodes order
#   streams     "<node> <key>" per stream of every scheduler (initial keys)
#   late        "<instance>" per instance planted during the aging (not T0)
#   checks      "<instance> <fault-id>: present" per fault instance, in order
#   verdicts    "<node> green|red, ..." in nodes order, as validate's last line
#   red         "<node> <rule>" per RED line the answer key expects
scn() {
    python3 - "$SCN" "$1" <<'EOF'
import re, sys, yaml
scn, what = sys.argv[1], sys.argv[2]
s = yaml.safe_load(open(scn + "/scenario.yaml"))
key = yaml.safe_load(open(scn + "/gm/answer-key.yaml"))
sched = [n for n in s["nodes"] if n["brick"]["id"] == "scheduler"]
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
        sys.exit("designed for %d hosts: this smoke run needs a single one "
                 "(smoke-load.sh takes a playground of several)" % len(hosts))
    h = hosts[0]
    print(h["name"], h["cpu"], h["memory"], h["disk"])
elif what == "aging":
    if sched:
        m = re.match(r"^(\d+)([smhd])$", str(s["aging"]["minimum"]))
        print(int(m.group(1)) * {"s": 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)])
elif what == "schedulers":
    for n in sched:
        print(n["name"])
elif what == "streams":
    for n in sched:
        for st in yaml.safe_load(open(scn + "/" + n["seed_files"]["schedule.yaml"]))["streams"]:
            print(n["name"], st["key"])
elif what == "late":
    for f in s["fault_instances"]:
        if f.get("plant_at", "T0") != "T0":
            print(f["id"])
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
        left=$(labelled; units)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$SRC" "$SCN"
rm -rf "${SCN:?}/local"

host=$(scn playground) || exit 2
set -- $host
PG=$1 CPU=$2 MEMORY=$3 DISK=$4
LDIR=$SCN/local/$PG
AGING=$(scn aging)
if [ -n "$AGING" ]; then
    systemctl --user show --property=Version >/dev/null 2>&1 \
        || { echo "the user's systemd manager does not answer (systemctl --user)" >&2; exit 2; }
    LIVE=load-started
else
    LIVE=injected
fi
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
on() {     # on <node> <user> [gmctl exec options]: the script on stdin, run there
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}

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
if [ -n "$AGING" ]; then
    # A whole hour past now plus the aging minimum and an hour, so render
    # warns of nothing.
    HANDOVER=$(date -u -d "@$(( ($(date +%s) + AGING) / 3600 * 3600 + 7200 ))" +%Y-%m-%dT%H:00Z)
    info "gmctl render --handover $HANDOVER (scheduler nodes: the scenario ages)"
    set -- --handover "$HANDOVER"
else
    info "gmctl render (no scheduler node: no aging, nothing shifted)"
    set --
fi
if $GMCTL render "$SCN" --playground "$PG" "$@"; then
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

# --- the load (scheduler nodes only) ----------------------------------------
if [ -n "$AGING" ]; then
    info "gmctl start-load"
    $GMCTL start-load "$SCN" --playground "$PG"
    same "start-load: exit 0" 0 "$?"
    same "status: stage load-started" load-started "$(stage)"
    same "the early check's host timer is active" active \
        "$(systemctl --user show -p ActiveState --value "dbagm-${GAME}_early-check.timer")"
    T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
    info "T0 $T0"
    for i in $(scn late); do
        info "gmctl inject --at now --instance $i (a test harness: planted at once)"
        $GMCTL inject "$SCN" --playground "$PG" --at now --instance "$i"
        same "inject --at now: $i planted" 0 "$?"
    done

    first=$(( $(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s) / 60 * 60 + 60 ))
    wait=$(( first + LOAD_MINUTES * 60 + 15 - $(date +%s) ))
    if [ "$wait" -gt 0 ]; then
        info "$LOAD_MINUTES minutes of schedules: waiting ${wait} s"
        sleep "$wait"
    fi
    MINUTES=$(i=0; while [ "$i" -lt "$LOAD_MINUTES" ]; do
        date -u -d "@$(( first + i * 60 ))" +%Y-%m-%dT%H:%MZ; i=$((i + 1)); done)
    for n in $(scn schedulers); do
        keys=$(scn streams | awk -v n="$n" '$1 == n { print $2 }' | tr '\n' ' ')
        lines=$(on "$n" root --env "MINUTES=$(printf '%s' "$MINUTES" | tr '\n' ' ')" <<'EOF'
for m in $MINUTES; do
    grep -E "^[^ ]+ (summary|key) minute=$m( |\$)" /var/log/scheduler/scheduler.log
done
EOF
)
        same "scheduler $n: every minute since T0 summarised, every stream key in each, with calls" \
            ok "$(python3 - "$keys" "$MINUTES" "$lines" <<'EOF'
import re, sys
keys, minutes, text = sys.argv[1].split(), sys.argv[2].split(), sys.argv[3]
summ, calls, seen = set(), {k: 0 for k in keys}, {}
for line in text.splitlines():
    f = dict(re.findall(r"(\w+)=(\S+)", line))
    if " summary " in line:
        summ.add(f["minute"])
    elif " key " in line:
        seen.setdefault(f["minute"], set()).add(f["key"])
        if f["key"] in calls:
            calls[f["key"]] += int(f["calls"])
out = ["minute %s: no summary" % m for m in minutes if m not in summ]
out += ["minute %s: no key line for %s" % (m, k) for m in minutes for k in keys
        if k not in seen.get(m, set())]
out += ["key %s: no call in %d minutes" % (k, len(minutes)) for k in keys if not calls[k]]
print("\n".join(out) or "ok")
EOF
)"
        metrics=$(printf 'curl -fsS http://localhost:9120/metrics\n' | on "$n" root)
        same "scheduler $n: running, and its metrics count calls of every stream key" ok \
            "$(printf '%s\n' "$metrics" | python3 -c '
import re, sys
keys, text = sys.argv[1].split(), sys.stdin.read()
v = {m.group(1): float(m.group(2)) for m in
     re.finditer(r"^scheduler_calls_total\{key=\"([^\"]+)\"\} (\S+)$", text, re.M)}
out = [] if re.search(r"^scheduler_running 1(\.0)?$", text, re.M) else ["not running"]
out += ["%s: no call counted" % k for k in keys if not v.get(k)]
print("\n".join(out) or "ok")' "$keys")"
    done
fi

# --- check: every sealed check at 1 ----------------------------------------
# verdicts <output>: the instance lines of gmctl check, without their reasons.
verdicts() { printf '%s\n' "$1" | sed 's/ — .*//'; }
expected=$(scn checks)
count=$(printf '%s\n' "$expected" | wc -l | tr -d ' ')
info "gmctl check, until every sealed check reads present (up to 120 s, ${CHECK_TIMEOUT} s a run)"
i=0
while :; do
    out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG"); rc=$?
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
same "evaluation changed no stage" "$LIVE" "$(stage)"

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
same "no systemd user timer or service of game $GAME is left" "" "$(units)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-scenario $NAME: all $passes checks passed in ${elapsed}s (game $GAME)"
else
    echo "smoke-scenario $NAME: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME)"
    exit 1
fi
