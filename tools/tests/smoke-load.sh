#!/bin/sh
# Load smoke run of gmctl on a real swarm (build plan v0.3, chunk 12; master
# spec 11, "Smoke tests"; run at every wave gate from v0.3 wave 3 on, on one
# host and on armenelos plus the VPS; never at the same time as smoke.sh,
# smoke-monitoring.sh, smoke-scenario.sh or another run of itself: all
# publish the bastion's ports).
#
# On a copy of the load fixture (tools/tests/fixtures/fixture-load: bastion,
# db, pooler, producer, consumer, prometheus, exporter, grafana), a short
# game with load:
#   fit -> render --handover (about ten hours ahead) -> deploy -> load-data
#   (the schedulers' role passwords set) -> inject (the T0 faults; the
#   schedulers idle) -> start-load (T0, the early check's host timer), then:
#   - the host timers: the early check's armed; the planting of the fault
#     due during the aging scheduled with inject --at, re-scheduled (the
#     timer rewritten and re-armed on its new OnCalendar), then planted at
#     once with inject --at now (its timer removed): a test harness, never
#     a game;
#   - a few minutes of schedules (LOAD_MINUTES, 3 by default), then every
#     scheduler key running: in the schedulers' per-minute summaries
#     (every minute since T0 summarised, every stream key in each, calls
#     over the span, no error), in their metrics, and in Prometheus (every
#     scrape target up, the schedulers' counters scraped);
#   - PgBouncer's pools in use (the producer's pool, server connections);
#   - every fault present, polled with a time limit per check (gmctl check
#     exiting 1, each sealed check at 1); the early check run by hand
#     passing; every validator green;
#   - the report-only node refusing, as player through the bastion: an
#     edit of prometheus.yml denied and gm-reload-prometheus refusing, and
#     the producer's repository (outside its write override) denied;
#   - "too soon to tell": f1 fixed as player through the producer's write
#     override (jobs.yaml, then sudo gm-reload-scheduler), f2 fixed by the
#     GM; gmctl check exits 3 with f1 too-soon, then 0 once its window
#     has passed;
#   -> teardown, then nothing labelled with the game id is left (the
#   game's systemd user timers and services included) and the objects not
#   belonging to the game are unchanged.
#
# No credential goes on a command line or in `gmctl exec --env`: the script
# reads none; the sealed checks, the validators and the players' sessions
# read theirs inside the nodes. Every in-node step goes through gmctl exec,
# so it reaches a node on any host of the playground.
#
# Usage: sh tools/tests/smoke-load.sh <playground> [<gmctl fit option>...]
#   (from anywhere). <playground> is the playground's name (local/<name>/ in
#   the copy). Options after it are passed to gmctl fit as given, in place
#   of the default capacity; without any, the playground is the local
#   engine at its own capacity: its CPUs, the memory available now
#   (MemAvailable) and the disk free under Docker's root directory.
#   e.g. sh tools/tests/smoke-load.sh armenelos
#        sh tools/tests/smoke-load.sh armenelos --cpu 4 --memory 5G --disk 10G
# SMOKE_LOAD_ENGINES: other Docker endpoints of the playground
#   (space-separated, as docker -H takes them), whose containers and volumes
#   the leftovers check lists too.
#
# Needs: a swarm manager on the local engine, the user's systemd manager
# (systemctl --user; lingering on, for the game's persistent timers),
# python3 with PyYAML (as gmctl) and curl on the host, and the bricks'
# images built (fit refuses a missing one and names its build command):
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.3.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.0 bricks/pgbouncer
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.1.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.2.0 bricks/grafana
# Host ports 2222 and 8080 must be free (the bastion's published ports).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
FIXTURE=$REPO/tools/tests/fixtures/fixture-load
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
LOAD_MINUTES=${LOAD_MINUTES:-3}
CHECK_TIMEOUT=${CHECK_TIMEOUT:-180}    # seconds one gmctl check run may take
started=$(date +%s)

[ $# -ge 1 ] || { echo "usage: sh $0 <playground> [<gmctl fit option>...]" >&2; exit 2; }
PG=$1; shift
case $PG in ''|*/*) echo "not a playground name: $PG" >&2; exit 2 ;; esac

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

# Everything still carrying one of the game's labels, one per line: on the
# manager, and the containers and volumes on the playground's other engines.
labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
        for e in ${SMOKE_LOAD_ENGINES:-}; do
            docker -H "$e" volume ls --filter "label=$l=$GAME" --format "volume {{.Name}} ($e)"
            docker -H "$e" ps -a --filter "label=$l=$GAME" --format "container {{.Names}} ($e)"
        done
    done | sort -u
}

# The game's systemd user units: loaded, as unit files, or left as files
# (units, timer stamps), one per line.
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
# next_elapse <unit>: when the timer fires next, in seconds since the epoch.
next_elapse() {
    date -d "$(systemctl --user show -p NextElapseUSecRealtime --value "$1")" +%s
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
systemctl --user show --property=Version >/dev/null 2>&1 \
    || { echo "the user's systemd manager does not answer (systemctl --user)" >&2; exit 2; }
command -v curl >/dev/null || { echo "curl is needed on the host" >&2; exit 2; }
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
STAMP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/systemd/timers

if [ $# -eq 0 ]; then
    root=$(docker info --format '{{.DockerRootDir}}')
    df -Pk "$root" >/dev/null 2>&1 || root=/
    set -- --cpu "$(nproc)" \
        --memory "$(awk '/^MemAvailable:/ { printf "%dM", $2 / 1024 }' /proc/meminfo)" \
        --disk "$(df -Pk "$root" | awk 'NR == 2 { printf "%dG", $4 / 1048576 }')"
fi
FIT_OPTIONS="$*"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-load.XXXXXX")
SCN=$tmp/fixture-load
LDIR=$SCN/local/$PG
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

cp -R "$FIXTURE" "$SCN"
rm -rf "${SCN:?}/local"

# on <node> <user> [gmctl exec options]: the script on stdin, run on <node>
# as <user>. Only non-secret values go in --env.
on() {
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
# state <python expression on st, the state.yaml mapping>: its value.
state() {
    python3 -c 'import sys, yaml
st = yaml.safe_load(open(sys.argv[1])) or {}
v = eval(sys.argv[2])
print("" if v is None else v)' "$LDIR/state.yaml" "$1"
}
# epoch <UTC instant>: seconds since the epoch.
epoch() { date -u -d "$(printf '%s' "$1" | sed 's/T/ /; s/Z$//')" +%s; }
# instant <seconds since the epoch>: YYYY-MM-DDTHH:MMZ.
instant() { date -u -d "@$1" +%Y-%m-%dT%H:%MZ; }

# fx <what>: read from the fixture copy.
#   schedulers  "<node>" per scheduler node, in nodes order
#   streams     "<node> <key>" per stream of every scheduler (initial keys)
#   jobkeys     "<node> <key>" per job of every scheduler's jobs.yaml
#   present     "<instance> <fault-id>: present" per fault instance, in order
#   aging       "<instance>" per instance planted during the aging (not T0)
fx() {
    python3 - "$SCN" "$1" <<'EOF'
import sys, yaml
scn, what = sys.argv[1], sys.argv[2]
s = yaml.safe_load(open(scn + "/scenario.yaml"))
sched = [n for n in s["nodes"] if n["brick"]["id"] == "scheduler"]
def seed(node, name):
    return yaml.safe_load(open(scn + "/" + node["seed_files"][name])) or {}
if what == "schedulers":
    for n in sched:
        print(n["name"])
elif what == "streams":
    for n in sched:
        for st in seed(n, "schedule.yaml")["streams"]:
            print(n["name"], st["key"])
elif what == "jobkeys":
    for n in sched:
        for j in seed(n, "jobs.yaml").get("jobs") or []:
            print(n["name"], j["key"])
elif what == "present":
    for f in s["fault_instances"]:
        print("%s %s: present" % (f["id"], f["fault"]["id"]))
elif what == "aging":
    for f in s["fault_instances"]:
        if f.get("plant_at", "T0") != "T0":
            print(f["id"])
EOF
}

# --- local implementation ---------------------------------------------------
info "fixture-load on playground $PG"
info "gmctl fit $FIT_OPTIONS"
if $GMCTL fit "$SCN" --playground "$PG" "$@"; then
    pass "fit: the images and the reservations fit ($FIT_OPTIONS)"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# The planned hand-over: a whole hour about ten hours ahead, past T0 plus
# the aging minimum (8h), so render warns of nothing.
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
info "gmctl render --handover $HANDOVER"
if out=$($GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"); then
    printf '%s\n' "$out"
    pass "render --handover"
else
    printf '%s\n' "$out"
    fail "render --handover"
    exit 1
fi
same "render: the planned hand-over recorded" "${HANDOVER%Z}:00Z" \
    "$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["timeline"]["planned_handover"])' "$LDIR/implementation.yaml")"
same "render: no warning (the planned hand-over is past the earliest one)" "" \
    "$(printf '%s\n' "$out" | grep -i 'warning')"
same "render: every scheduler's schedule.yaml and jobs.yaml rendered" "" \
    "$(for n in $(fx schedulers); do for f in schedule.yaml jobs.yaml; do
        [ -f "$LDIR/rendered/$n/$f" ] || echo "$n/$f"; done; done)"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
[ -z "$(units)" ] || { echo "systemd user units of game $GAME already exist" >&2; exit 1; }
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
same "role secrets: one per scheduler role, mounted where named" \
    "consumer role_shop_reports_password
producer role_shop_app_password" \
    "$(for n in $(fx schedulers); do
        printf 'ls /opt/gm/secrets\n' | on "$n" root | sed -n "s/^\(role_.*_password\)\$/$n \1/p"
       done | sort)"

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
same "status: stage data-loaded" data-loaded "$(stage)"
same "load-data: the schedulers' roles log in with SCRAM passwords" "shop_app|t|t
shop_reports|t|t" "$(on db postgres <<'EOF'
psql -XAtq -c "SELECT rolname, rolcanlogin, rolpassword LIKE 'SCRAM-SHA-256\$%' FROM pg_authid WHERE rolname IN ('shop_app', 'shop_reports') ORDER BY 1"
EOF
)"

info "gmctl inject (the faults due at T0)"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
same "status: stage injected" injected "$(stage)"
reloptions() {
    on db postgres <<'EOF'
psql -XAtq -d shop -c "SELECT coalesce(array_to_string(reloptions, ','), '') FROM pg_class WHERE oid = 'orders'::regclass"
EOF
}
same "inject: f2, due during the aging, not planted yet" "" "$(reloptions)"
for n in $(fx schedulers); do
    same "scheduler $n idle before start-load" idle \
        "$(printf 'cut -d " " -f 1 /run/scheduler/status\n' | on "$n" root)"
done

# --- start-load, T0, the host timers ----------------------------------------
info "gmctl start-load"
out=$($GMCTL start-load "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "start-load: exit 0" 0 "$rc"
same "status: stage load-started" load-started "$(stage)"
T0=$(state 'st["load"]["t0"]')
info "T0 $T0"
for n in $(fx schedulers); do
    same "scheduler $n running since T0" running \
        "$(printf 'cut -d " " -f 1 /run/scheduler/status\n' | on "$n" root)"
done
for i in $(fx aging); do
    check "start-load: prints the planting of $i to schedule" \
        sh -c "printf '%s\n' \"\$1\" | grep -q -- '--instance $i\$'" sh "$out"
done
EARLY=dbagm-${GAME}_early-check.timer
same "the early check's timer is a persistent user unit, active" "active enabled" \
    "$(systemctl --user show -p ActiveState --value "$EARLY") $(systemctl --user is-enabled "$EARLY")"
same "the early check's timer fires at its recorded due" \
    "$(epoch "$(state 'st["early_check"]["timer"]["due"]')")" "$(next_elapse "$EARLY")"

for i in $(fx aging); do
    unit=dbagm-${GAME}_plant-$i.timer
    first=$(( ($(date +%s) / 60 + 120) * 60 ))
    later=$(( first + 3600 ))
    info "gmctl inject --at $(instant "$first") --instance $i"
    $GMCTL inject "$SCN" --playground "$PG" --at "$(instant "$first")" --instance "$i"
    same "inject --at: $i's planting scheduled" 0 "$?"
    same "$i's timer armed at $(instant "$first")" "$first" "$(next_elapse "$unit")"
    info "gmctl inject --at $(instant "$later") --instance $i (re-scheduled)"
    $GMCTL inject "$SCN" --playground "$PG" --at "$(instant "$later")" --instance "$i"
    same "inject --at again: exit 0" 0 "$?"
    same "$i's timer re-armed on its new OnCalendar ($(instant "$later"))" "$later" \
        "$(next_elapse "$unit")"
    same "$i's timer unit holds the new OnCalendar" \
        "OnCalendar=$(date -u -d "@$later" '+%Y-%m-%d %H:%M:%S') UTC" \
        "$(sed -n 's/^OnCalendar=/OnCalendar=/p' "$UNIT_DIR/dbagm-${GAME}_plant-$i.timer")"
    info "gmctl inject --at now --instance $i (a test harness: planted at once)"
    $GMCTL inject "$SCN" --playground "$PG" --at now --instance "$i"
    same "inject --at now: $i planted" 0 "$?"
    same "$i's timer and service removed" "" "$(units | grep "_plant-$i\.")"
    check "$i recorded as planted" test -n "$(state "st['plantings']['$i']['planted_at']")"
done
same "f2 planted: autovacuum off on orders" "autovacuum_enabled=off" "$(reloptions)"
same "stage still load-started" load-started "$(stage)"

# --- a few minutes of schedules ---------------------------------------------
# The span judged: from the first whole minute after T0 for LOAD_MINUTES
# minutes, each summary written within seconds after its minute.
first_minute=$(( $(epoch "$T0") / 60 * 60 + 60 ))
span_end=$(( first_minute + LOAD_MINUTES * 60 ))
wait=$(( span_end + 15 - $(date +%s) ))
if [ "$wait" -gt 0 ]; then
    info "$LOAD_MINUTES minutes of schedules: waiting ${wait} s"
    sleep "$wait"
fi
MINUTES=$(i=0; while [ "$i" -lt "$LOAD_MINUTES" ]; do
    date -u -d "@$(( first_minute + i * 60 ))" +%Y-%m-%dT%H:%MZ; i=$((i + 1)); done)

# summaries <node>: the judged minutes' summary and key lines, read as root.
summaries() {
    on "$1" root --env "MINUTES=$(printf '%s' "$MINUTES" | tr '\n' ' ')" <<'EOF'
for m in $MINUTES; do
    grep -E "^[^ ]+ (summary|key) minute=$m( |\$)" /var/log/scheduler/scheduler.log
done
EOF
}
# judge <node> <stream keys> <log lines>: one line per finding, or "ok".
judge() {
    python3 - "$1" "$2" "$MINUTES" "$3" <<'EOF'
import re, sys
node, keys, minutes, text = sys.argv[1], sys.argv[2].split(), sys.argv[3].split(), sys.argv[4]
summ, calls, errors, seen = set(), {k: 0 for k in keys}, 0, {}
for line in text.splitlines():
    f = dict(re.findall(r"(\w+)=(\S+)", line))
    if " summary " in line:
        summ.add(f["minute"])
        errors += int(f.get("errors", 0))
    elif " key " in line:
        seen.setdefault(f["minute"], set()).add(f["key"])
        if f["key"] in calls:
            calls[f["key"]] += int(f["calls"])
out = []
out += ["minute %s: no summary" % m for m in minutes if m not in summ]
out += ["minute %s: no key line for %s" % (m, k) for m in minutes for k in keys
        if k not in seen.get(m, set())]
out += ["key %s: no call in %d minutes" % (k, len(minutes)) for k in keys if not calls[k]]
if errors:
    out.append("%d error(s) in the summaries" % errors)
print("\n".join(out) or "ok")
print("calls: " + ", ".join("%s %d" % kv for kv in calls.items()), file=sys.stderr)
EOF
}
# metric <metrics text> <name> <key>: the sample's value (empty if absent).
metric() {
    printf '%s\n' "$1" | awk -v n="$2" -v k="$3" '
        $1 == n "{key=\"" k "\"}" || ($1 == n && k == "") { print $2 }'
}
for n in $(fx schedulers); do
    keys=$(fx streams | awk -v n="$n" '$1 == n { print $2 }' | tr '\n' ' ')
    same "scheduler $n: every minute since T0 summarised, every stream key in each, calls, no error" \
        ok "$(judge "$n" "$keys" "$(summaries "$n")")"
    m=$(printf 'curl -fsS http://localhost:9120/metrics\n' | on "$n" root)
    same "scheduler $n: metrics say running" 1 "$(metric "$m" scheduler_running "")"
    jobkeys=$(fx jobkeys | awk -v n="$n" '$1 == n { print $2 }' | tr '\n' ' ')
    for k in $keys; do
        v=$(metric "$m" scheduler_calls_total "$k")
        check "scheduler $n: metrics count calls of $k ($v)" \
            python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > 0 else 1)' "${v:-0}"
    done
    for k in $jobkeys; do
        check "scheduler $n: metrics declare job key $k" test -n "$(metric "$m" scheduler_calls_total "$k")"
    done
    same "scheduler $n: no error counted on any key" "" \
        "$(printf '%s\n' "$m" | awk '/^scheduler_errors_total\{/ && $2 + 0 > 0')"
done
# f1's job runs every minute on the producer: its key has a line each minute.
same "producer: the every-minute job ran in each judged minute" "" \
    "$(for t in $MINUTES; do summaries producer | grep -q "key minute=$t key=stats.refresh " \
        || echo "$t"; done)"

# --- Prometheus: every target up, the schedulers' counters scraped ---------
query() {
    on prometheus prometheus --env "QUERY=$1" <<'EOF' | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin)["data"]["result"]
except (ValueError, KeyError):
    r = []
print(r[0]["value"][1] if r else "")'
curl -fsS --get --data-urlencode "query=$QUERY" 'http://localhost:9090/prometheus/api/v1/query'
EOF
}
targets() {
    on prometheus prometheus <<'EOF' | python3 -c '
import json, sys
try:
    ts = json.load(sys.stdin)["data"]["activeTargets"]
except (ValueError, KeyError):
    ts = []
for line in sorted("%s %s %s" % (t["labels"]["job"], t["labels"]["instance"], t["health"])
                   for t in ts):
    print(line)'
curl -fsS 'http://localhost:9090/prometheus/api/v1/targets?state=active'
EOF
}
EXPECTED_TARGETS=$(python3 - "$SCN" <<'EOF'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1] + "/nodes/prometheus/prometheus.yml"))
print("\n".join(sorted("%s %s up" % (j["job_name"], t) for j in c["scrape_configs"]
                       for sc in j["static_configs"] for t in sc["targets"])))
EOF
)
i=0
while :; do
    out=$(targets)
    [ "$out" = "$EXPECTED_TARGETS" ] || [ "$i" -ge 24 ] && break
    i=$((i + 1)); sleep 5
done
same "Prometheus: all $(printf '%s\n' "$EXPECTED_TARGETS" | wc -l | tr -d ' ') scrape targets up" \
    "$EXPECTED_TARGETS" "$out"
# Each stream key's calls, scraped from its scheduler (instance <node>:9120).
same "Prometheus: every stream key's calls scraped from the schedulers" "" \
    "$(fx streams | while read -r n k; do
        v=$(query "scheduler_calls_total{job=\"scheduler\",instance=\"$n:9120\",key=\"$k\"}")
        python3 -c 'import sys; sys.exit(0 if float(sys.argv[1] or 0) > 0 else 1)' "${v:-0}" \
            || echo "$n $k: ${v:-no sample}"
       done)"

# --- PgBouncer's pools ------------------------------------------------------
# pools: SHOW POOLS on the console, as pgbouncer over the local socket.
pools=$(on pooler pgbouncer <<'EOF'
psql -X -A -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS'
EOF
)
printf '%s\n' "$pools" | sed 's/^/      /'
same "PgBouncer: the producer's pool (shop, shop_app) in use: clients and server connections" ok \
    "$(printf '%s\n' "$pools" | python3 -c '
import sys
rows = [l.rstrip("\n").split("|") for l in sys.stdin if "|" in l]
head, rows = rows[0], [dict(zip(rows[0], r)) for r in rows[1:]]
p = [r for r in rows if r.get("database") == "shop" and r.get("user") == "shop_app"]
if not p:
    print("no pool for shop/shop_app")
else:
    r = p[0]
    cl = int(r["cl_active"]) + int(r["cl_waiting"])
    sv = int(r["sv_active"]) + int(r["sv_idle"]) + int(r["sv_used"])
    print("ok" if cl > 0 and sv > 0 else "clients %d, server connections %d" % (cl, sv))')"
xacts=$(on pooler pgbouncer <<'EOF' | python3 -c '
import sys
rows = [l.rstrip("\n").split("|") for l in sys.stdin if "|" in l]
rows = [dict(zip(rows[0], r)) for r in rows[1:]] if rows else []
print("".join(r["total_xact_count"] for r in rows if r.get("database") == "shop"))'
psql -X -A -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW STATS'
EOF
)
check "PgBouncer: transactions pooled for shop (${xacts:-none})" \
    python3 -c 'import sys; sys.exit(0 if int(sys.argv[1] or 0) > 0 else 1)' "${xacts:-0}"

# --- every fault present ----------------------------------------------------
# verdicts <output>: the instance lines of gmctl check, without their reasons.
verdicts() { printf '%s\n' "$1" | sed 's/ — .*//'; }
expected=$(fx present)
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

info "gmctl check --early-check (by hand, as the timer would)"
out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG" --early-check); rc=$?
printf '%s\n' "$out"
same "early check: exit 0 (faults present, schedulers and keys running, nodes healthy)" 0 "$rc"
same "early check: recorded as passed" True "$(state 'st["early_check"]["result"]["passed"]')"
same "early check: no outage minute" 0 "$(state 'st["early_check"]["result"].get("lost_minutes", 0)')"

info "gmctl validate"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "validate: exit 0, every node green" 0 "$rc"

# --- the report-only node refusing, as player through the bastion ---------
info "as player through the bastion: edits on report-only paths"
out=$(on bastion player <<'EOF'
ssh -n prometheus 'printf "\n" >> /etc/prometheus/prometheus.yml' 2>&1; echo "edit=$?"
ssh -n prometheus 'sudo -n /usr/local/sbin/gm-reload-prometheus' 2>&1; echo "reload=$?"
ssh -n producer 'touch /srv/scheduler/repository/notes.txt' 2>&1; echo "repository=$?"
EOF
)
printf '%s\n' "$out" | sed 's/^/      /'
check "prometheus (report-only): editing prometheus.yml is denied" \
    sh -c 'printf "%s\n" "$1" | grep -q "Permission denied" && ! printf "%s\n" "$1" | grep -q "^edit=0$"' sh "$out"
same "prometheus (report-only): gm-reload-prometheus refuses, exit 1" "reload=1" \
    "$(printf '%s\n' "$out" | grep '^reload=')"
check "prometheus (report-only): the refusal says why" \
    sh -c 'printf "%s\n" "$1" | grep -q "report-only"' sh "$out"
check "producer: its repository, outside the write override, is denied" \
    sh -c 'printf "%s\n" "$1" | grep -q "^repository=[1-9]"' sh "$out"

# --- too soon to tell ---------------------------------------------------------
info "the fixes: f1 as player through the producer's write override, f2 by the GM"
out=$(on bastion player <<'EOF'
ssh producer sh -s <<'INNER' 2>&1
python3 -I - <<'PY'
import yaml
p = "/srv/scheduler/jobs/jobs.yaml"
d = yaml.safe_load(open(p))
for j in d["jobs"]:
    if j["name"] == "refresh-stats":
        j["at"] = "5 * * * *"
with open(p, "w") as f:
    f.write(yaml.safe_dump(d, sort_keys=False))
PY
sudo -n /usr/local/sbin/gm-reload-scheduler
INNER
echo "fix=$?"
EOF
)
printf '%s\n' "$out" | sed 's/^/      /'
same "f1 fixed through the override and reloaded (gm-reload-scheduler exit 0)" "fix=0" \
    "$(printf '%s\n' "$out" | grep '^fix=')"
on db postgres >/dev/null <<'EOF'
psql -XAtq -v ON_ERROR_STOP=1 -d shop -c "ALTER TABLE orders RESET (autovacuum_enabled)"
EOF
same "f2 fixed by the GM (autovacuum back on orders)" 0 "$?"
out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "check: exit 3 (too soon to tell)" 3 "$rc"
same "check: f1 too soon, f2 fixed" "f1 fixture-job-every-minute: too-soon
f2 pg-table-autovacuum-off: fixed" "$(verdicts "$out")"
remaining=$(printf '%s\n' "$out" | sed -n 's/^f1 [^ ]*: too-soon — \([0-9]*\) s of the window remain.*/\1/p')
check "check: f1's line gives the window's remaining seconds (${remaining:-none})" \
    test -n "$remaining"
info "gmctl check, until f1's window has passed (up to $(( ${remaining:-120} + 90 )) s)"
deadline=$(( $(date +%s) + ${remaining:-120} + 90 ))
while :; do
    sleep 10
    out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG"); rc=$?
    [ "$rc" != 3 ] || [ "$(date +%s)" -ge "$deadline" ] && break
done
printf '%s\n' "$out"
same "check: exit 0 once the window has passed" 0 "$rc"
same "check: both fixed" "f1 fixture-job-every-minute: fixed
f2 pg-table-autovacuum-off: fixed" "$(verdicts "$out")"
same "evaluation changed no stage" load-started "$(stage)"

# --- the scheduler's error lines (wave 1: not rate-limited) ----------------
for n in $(fx schedulers); do
    info "scheduler $n: $(printf 'grep -c " error " /var/log/scheduler/scheduler.log; wc -c < /var/log/scheduler/scheduler.log\n' \
        | on "$n" root | tr '\n' ' ' | awk '{ printf "%d error line(s), log %d bytes", $1, $2 }')"
done
$GMCTL status "$SCN" --playground "$PG" | sed 's/^/      /'

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
same "no systemd user timer, service or stamp of game $GAME is left" "" "$(units)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-load $PG: all $passes checks passed in ${elapsed}s (game $GAME)"
else
    echo "smoke-load $PG: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME)"
    exit 1
fi
