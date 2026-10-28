#!/bin/sh
# The rehearsal (v0.3 master spec 11, "The rehearsal"; build plan v0.3,
# chunk 15b): a short unattended game of the v0.3 scenario on a real swarm,
# exercising what the smoke tests skip, and measuring the game's footprint
# under its peak load. Run before the release gate's aged run, on armenelos
# plus the VPS; never at the same time as another game of this repository
# (the bastion's published ports, and the measurements).
#
# On a copy of the scenario (tarnbeck-outdoor-shop by default):
#   fit -> render --handover (chosen so the traffic shapes' peak hour falls
#   inside the run) -> deploy -> load-data -> inject (the T0 faults) -> a
#   wait, the schedulers idle, until the planned T0 -> start-load with the
#   test-harness override of the aging minimum (G6, spec D156, D161: it caps
#   the aging minimum and every instance's own; it shortens the wait, never
#   a clock), then, unattended:
#   - each fault due during the aging scheduled with inject --at a few
#     minutes ahead, and planted by the host timer;
#   - a scheduler container killed (docker kill), Swarm starting a new one,
#     the scheduler resuming at the current time with the same T0;
#   - an outage of a few minutes: another scheduler's program stopped
#     through s6 and started again (no per-minute summary meanwhile); the
#     kill and the outage kept clear of the early check;
#   - the early check fired by the host timer, passing, the outage recorded;
#   - the peak hour under load, measured: every node's memory and CPU, the
#     hosts' available memory, PgBouncer's pools (every 20 s), the volumes
#     at T0 and at hand-over (a database's pg_wal apart);
#   - at the earliest hand-over: the hand-over check, passing, the outage
#     minutes recorded and the earliest hand-over not moved (up to 30
#     minutes); the snapshot with its brief stops; the hand-over;
#   - a restart from the snapshot, its confirmation recorded: a new game id,
#     the schedulers resuming, every fault present, the validators;
#   -> teardown, then nothing of either game left on any engine (snapshot
#   copies and the game's systemd user units included), the objects not
#   belonging to the game unchanged; then the figures.
#
# No credential goes on a command line or in `gmctl exec --env`. The manager
# is kept from suspending while the script runs (systemd-inhibit, sleep and
# idle), since a suspended host stops the game's clock-driven load.
#
# First run: armenelos plus the VPS, 2026-10-28 (build plan v0.3, chunk 15b;
# the figures in the bricks' docs/gm.md, "Footprint").
#
# Usage: sh tools/tests/rehearsal.sh <playground> [<gmctl fit option>...]
#   as smoke-load.sh: options after the playground go to gmctl fit; without
#   any, the local engine at its own capacity. Two hosts (the wave 3 gate's
#   declaration):
#     REHEARSAL_ENGINES=ssh://dbagm-vps sh tools/tests/rehearsal.sh duo \
#       --host armenelos,manager,cpu=4,memory=4G,disk=20G \
#       --host vps-5718ad52,endpoint=ssh://dbagm-vps,cpu=2,memory=4G,disk=10G \
#       --map host-1=armenelos --map host-2=vps-5718ad52
# Environment:
#   REHEARSAL_SCENARIO  the scenario folder (default scenarios/tarnbeck-outdoor-shop)
#   REHEARSAL_ENGINES   the playground's other Docker endpoints (as docker -H
#                       takes them, space-separated): measured, and listed by
#                       the leftovers check; an ssh:// one is also read for
#                       its host's memory (ssh <host> cat /proc/meminfo)
#   REHEARSAL_OUT       where the measurements go (default: a new directory
#                       under $TMPDIR, kept)
#   REHEARSAL_HANDOVER  the planned hand-over (YYYY-MM-DDTHH:00Z); default:
#                       the one that puts the peak hour's start PEAK_LEAD
#                       minutes after a T0 about 25 minutes from now
#   PEAK_LEAD           minutes from T0 to the peak hour's start (default 40)
#   AFTER_PEAK          minutes from the peak hour's start to the earliest
#                       hand-over (default 45): the override is chosen so
#   OUTAGE_MINUTES      the outage's length (default 4)
#   SAMPLE_SECONDS      the sampling period (default 20)
#   MIN_AVAILABLE_MB    the run stops and tears down when the manager's
#                       available memory stays under it (default 400)
#
# Needs what smoke-load.sh needs (a swarm manager on the local engine, the
# user's systemd manager with lingering, python3 with PyYAML, curl, the
# bricks' images built), and host ports 2222 and 8080 free.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
SOURCE=${REHEARSAL_SCENARIO:-$REPO/scenarios/tarnbeck-outdoor-shop}
LABELS="com.docker.stack.namespace dbagm.game dbagm.snapshot"
KINDS="service network volume config secret"
PEAK_LEAD=${PEAK_LEAD:-40}
AFTER_PEAK=${AFTER_PEAK:-45}
OUTAGE_MINUTES=${OUTAGE_MINUTES:-4}
SAMPLE_SECONDS=${SAMPLE_SECONDS:-20}
MIN_AVAILABLE_MB=${MIN_AVAILABLE_MB:-400}
CHECK_TIMEOUT=${CHECK_TIMEOUT:-300}
ENGINES="local ${REHEARSAL_ENGINES:-}"
MAIN=$$
started=$(date +%s)

[ $# -ge 1 ] || { echo "usage: sh $0 <playground> [<gmctl fit option>...]" >&2; exit 2; }
PG=$1; shift
case $PG in ''|*/*) echo "not a playground name: $PG" >&2; exit 2 ;; esac
[ -f "$SOURCE/scenario.yaml" ] || { echo "no scenario.yaml in $SOURCE" >&2; exit 2; }

failures=0
passes=0
pass() { printf '%s PASS  %s\n' "$(date -u +%H:%M:%S)" "$*"; passes=$((passes + 1)); }
fail() { printf '%s FAIL  %s\n' "$(date -u +%H:%M:%S)" "$*"; failures=$((failures + 1)); }
info() { printf '%s ....  %s\n' "$(date -u +%H:%M:%S)" "$*"; }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

# dk <engine> <docker arguments>: docker on the manager ("local") or another engine.
dk() {
    e=$1; shift
    if [ "$e" = local ]; then docker "$@"; else docker -H "$e" "$@"; fi
}

# Objects on the manager that carry none of the games' names, one per line.
others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v -e " ${GAME}_" -e " ${GAME2:-${GAME}}_" -e "dbagm-snapshot_" || true; } | sort
}

# Everything still carrying one of the games' labels, on every engine.
labelled() {
    for g in $GAME ${GAME2:-}; do
        for l in $LABELS; do
            for k in $KINDS; do
                docker "$k" ls --filter "label=$l=$g" --format "$k {{.Name}}"
            done
            for e in $ENGINES; do
                dk "$e" volume ls --filter "label=$l=$g" --format "volume {{.Name}} ($e)"
                dk "$e" ps -a --filter "label=$l=$g" --format "container {{.Names}} ($e)"
            done
        done
    done | sort -u
}

# The games' systemd user units: loaded, as unit files, or left as files.
units() {
    for g in $GAME ${GAME2:-}; do
        systemctl --user list-units --all --plain --no-legend "dbagm-${g}_*" 2>/dev/null \
            | awk '{ print $1 }'
        systemctl --user list-unit-files --no-legend "dbagm-${g}_*" 2>/dev/null \
            | awk '{ print $1 }'
        for f in "$UNIT_DIR"/"dbagm-${g}_"* "$STAMP_DIR"/"stamp-dbagm-${g}_"*; do
            [ -e "$f" ] && echo "file $f"
        done
    done | sort -u
}
# ran <service>: "<Result> <ExecMainStatus>" once its timer has run it.
ran() {
    [ "$(systemctl --user show -p ExecMainStartTimestampMonotonic --value "$1")" != 0 ] || return 0
    echo "$(systemctl --user show -p Result --value "$1") $(systemctl --user show -p ExecMainStatus --value "$1")"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-rehearsal.XXXXXX")
OUT=${REHEARSAL_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/gmctl-rehearsal-out.XXXXXX")}
mkdir -p "$OUT"
SID=$(basename "$SOURCE")
SCN=$tmp/$SID
LDIR=$SCN/local/$PG
GAME=
GAME2=
deployed=no
SAMPLER=
INHIBIT=

cleanup() {
    set +e
    [ -n "$SAMPLER" ] && kill "$SAMPLER" 2>/dev/null
    [ -n "$INHIBIT" ] && kill "$INHIBIT" 2>/dev/null
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG" --reason "rehearsal stopped"
        left=$(labelled; units)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME ${GAME2:-} left behind: $left"
    fi
    [ -f "$LDIR/state.yaml" ] && cp "$LDIR/state.yaml" "$OUT/state.yaml"
    rm -rf "${tmp:?}"
    info "measurements kept in $OUT"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$SOURCE" "$SCN"
rm -rf "${SCN:?}/local"

# The hosts stay up for the whole run (master spec 10.1): the manager does not
# suspend while it runs (a sleep and idle inhibitor, released at the end).
if command -v systemd-inhibit >/dev/null; then
    systemd-inhibit --what=sleep:idle --who=gmctl-rehearsal --mode=block \
        --why="db_audit_gm rehearsal: the game's hosts stay up" sleep 86400 >/dev/null 2>&1 &
    INHIBIT=$!
    sleep 1
    kill -0 "$INHIBIT" 2>/dev/null || { INHIBIT=; info "WARNING: could not inhibit sleep; keep the manager awake"; }
fi

on() {  # on <node> <user> [gmctl exec options]: the script on stdin, run on <node> as <user>
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
state() {  # state <python expression on st, the state.yaml mapping>: its value
    python3 -c 'import sys, yaml
st = yaml.safe_load(open(sys.argv[1])) or {}
try:
    v = eval(sys.argv[2])
except (KeyError, IndexError, TypeError):
    v = None
print("" if v is None else v)' "$LDIR/state.yaml" "$1"
}
epoch() { date -u -d "$(printf '%s' "$1" | sed 's/T/ /; s/Z$//')" +%s; }
instant() { date -u -d "@$1" +%Y-%m-%dT%H:%MZ; }
hm() { date -u -d "@$1" +%H:%M:%S; }
# until_epoch <seconds since the epoch> <what>: sleep until then, in short steps.
until_epoch() {
    w=$(( $1 - $(date +%s) ))
    [ "$w" -gt 0 ] || return 0
    info "waiting ${w} s, until $(hm "$1") UTC: $2"
    while [ "$(date +%s)" -lt "$1" ]; do
        [ -e "$OUT/ABORT" ] && { echo "ABORT: $(cat "$OUT/ABORT")"; exit 1; }
        sleep 5
    done
}

# fx <what>: read from the scenario copy.
#   schedulers  "<node>" per scheduler node
#   nodes       "<node>" per node
#   aging       "<instance>" per instance planted during the aging
#   present     "<instance> <fault-id>: present" per fault instance
#   peak        the hour of the day (scenario time) with the most calls an hour,
#               every stream's rate times its shape's multiplier, summed
#   designed    the designed hand-over hour (aging.handover_at)
fx() {
    python3 - "$SCN" "$1" <<'EOF'
import re, sys, yaml
scn, what = sys.argv[1], sys.argv[2]
s = yaml.safe_load(open(scn + "/scenario.yaml"))
sched = [n for n in s["nodes"] if n["brick"]["id"] == "scheduler"]
def seed(node, name):
    return yaml.safe_load(open(scn + "/" + node["seed_files"][name])) or {}
def per_hour(rate):
    n, unit = re.match(r"\s*([\d.]+)\s*/\s*(s|min|h)\s*$", str(rate)).groups()
    return float(n) * {"s": 3600, "min": 60, "h": 1}[unit]
def multiplier(shape, hour):
    for k, v in (shape or {}).get("hours", {}).items():
        a, _, b = str(k).partition("-")
        if int(a) <= hour <= int(b or a):
            return float(v)
    return 1.0
if what == "schedulers":
    for n in sched:
        print(n["name"])
elif what == "nodes":
    for n in s["nodes"]:
        print(n["name"])
elif what == "aging":
    for f in s["fault_instances"]:
        if f.get("plant_at", "T0") != "T0":
            print(f["id"])
elif what == "present":
    for f in s["fault_instances"]:
        print("%s %s: present" % (f["id"], f["fault"]["id"]))
elif what == "peak":
    total = [0.0] * 24
    for n in sched:
        doc = seed(n, "schedule.yaml")
        shapes = doc.get("shapes") or {}
        for st in doc.get("streams") or []:
            for h in range(24):
                total[h] += per_hour(st["rate"]) * multiplier(shapes.get(st.get("shape")), h)
    print(total.index(max(total)))
elif what == "designed":
    print(int(str(s["aging"]["handover_at"]).split(":")[0]))
EOF
}

# container <game> <node>: "<engine> <container>" of the node's running container.
container() {
    for e in $ENGINES; do
        c=$(dk "$e" ps --filter "label=com.docker.swarm.service.name=$1_$2" \
            --filter status=running --format '{{.Names}}' | head -n 1)
        [ -n "$c" ] && { echo "$e $c"; return 0; }
    done
    return 1
}
sched_status() { printf 'cat /run/scheduler/status 2>/dev/null\n' | on "$1" root; }
sched_marker() { printf 'cat /var/lib/gm-state/load-started 2>/dev/null\n' | on "$1" root; }
# wait_running <node> <seconds> [<since>]: until the scheduler's s6 service is
# up and its status reads `running <instant>`, the instant at or after <since>
# (seconds since the epoch): a stopped program leaves its last status behind.
wait_running() {
    d=$(( $(date +%s) + $2 ))
    while [ "$(date +%s)" -lt "$d" ]; do
        line=$(printf '[ "$(/command/s6-svstat -o up /run/service/scheduler)" = true ] && cat /run/scheduler/status\n' \
            | on "$1" root 2>/dev/null)
        case $line in
            "running "*) [ "$(epoch "${line#running }")" -ge "${3:-0}" ] && return 0 ;;
        esac
        sleep 5
    done
    return 1
}

# --- the measurements -------------------------------------------------------
# meminfo <engine>: "<MemTotal kB> <MemAvailable kB> <SwapTotal kB> <SwapFree kB>".
meminfo() {
    case $1 in
        local) cat /proc/meminfo ;;
        ssh://*) h=${1#ssh://}; ssh -o BatchMode=yes "$h" cat /proc/meminfo ;;
        *) return 0 ;;
    esac | awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
                /^SwapTotal:/ { st = $2 } /^SwapFree:/ { sf = $2 }
                END { print t, a, st, sf }'
}
sampler() {
    low=0
    while :; do
        ts=$(date +%s)
        for e in $ENGINES; do
            names=$(dk "$e" ps --filter "label=com.docker.stack.namespace=$GAME" --format '{{.Names}}')
            if [ -n "$names" ]; then
                # shellcheck disable=SC2086
                dk "$e" stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}' $names \
                    | sed "s#^#$ts|$e|#" >> "$OUT/stats.txt"
            fi
            m=$(meminfo "$e")
            [ -n "$m" ] && echo "$ts|$e|$m" >> "$OUT/hosts.txt"
            if [ "$e" = local ] && [ -n "$m" ]; then
                set -- $m
                if [ "$2" -lt $((MIN_AVAILABLE_MB * 1024)) ]; then low=$((low + 1)); else low=0; fi
                if [ "$low" -ge 2 ]; then
                    echo "the manager's available memory under ${MIN_AVAILABLE_MB} MB twice ($2 kB)" \
                        > "$OUT/ABORT"
                    kill -TERM "$MAIN"
                    exit 0
                fi
            fi
        done
        on pooler pgbouncer 2>/dev/null <<'EOF' | sed "s#^#$ts|#" >> "$OUT/pools.txt"
psql -X -A -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW POOLS'
EOF
        w=$(( ts + SAMPLE_SECONDS - $(date +%s) ))
        [ "$w" -gt 0 ] && sleep "$w"
    done
}
# volumes <label>: every node's volumes, their size in kB, into volumes-<label>.txt.
volumes() {
    ts=$(date +%s)
    for n in $(fx nodes); do
        ec=$(container "$GAME" "$n") || { echo "$ts|$n|-|-|none" >> "$OUT/volumes-$1.txt"; continue; }
        set -- "$1" $ec
        mounts=$(dk "$2" inspect "$3" \
            --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}={{.Destination}} {{end}}{{end}}')
        on "$n" root --env "MOUNTS=$mounts" <<'EOF' | sed "s#^#$ts|$n|#" >> "$OUT/volumes-$1.txt"
for m in $MOUNTS; do
    printf '%s|%s|%s\n' "${m%%=*}" "${m#*=}" "$(du -sk "${m#*=}" 2>/dev/null | cut -f 1)"
    [ -d "${m#*=}/pg_wal" ] && printf '%s/pg_wal|%s/pg_wal|%s\n' "${m%%=*}" "${m#*=}" \
        "$(du -sk "${m#*=}/pg_wal" 2>/dev/null | cut -f 1)"
done
EOF
    done
}

# --- fit, the planned hand-over, render -------------------------------------
info "$SID on playground $PG; measurements into $OUT"
info "gmctl fit $FIT_OPTIONS"
if $GMCTL fit "$SCN" --playground "$PG" "$@" > "$OUT/fit.txt" 2>&1; then
    sed 's/^/      /' "$OUT/fit.txt"
    pass "fit: the images and the reservations fit ($FIT_OPTIONS)"
else
    sed 's/^/      /' "$OUT/fit.txt"
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"

PEAK=$(fx peak)
DESIGNED=$(fx designed)
AFTER_HOURS=$(( (DESIGNED - PEAK + 24) % 24 ))    # the planned hand-over, after the peak's start
if [ -n "${REHEARSAL_HANDOVER:-}" ]; then
    HANDOVER=$REHEARSAL_HANDOVER
    U=$(( $(epoch "$HANDOVER") - AFTER_HOURS * 3600 ))
else
    # the peak hour's start: the first whole UTC hour at least PEAK_LEAD minutes
    # after a T0 about 25 minutes from now (fit, render, deploy, the data load)
    U=$(( ( ($(date +%s) + (25 + PEAK_LEAD) * 60 + 3599) / 3600 ) * 3600 ))
    HANDOVER=$(date -u -d "@$(( U + AFTER_HOURS * 3600 ))" +%Y-%m-%dT%H:00Z)
fi
T0_PLAN=$(( U - PEAK_LEAD * 60 ))
info "peak hour ${PEAK}:00 scenario time, designed hand-over ${DESIGNED}:00: planned hand-over $HANDOVER;"
info "the peak hour starts at $(hm "$U") UTC; T0 planned at $(hm "$T0_PLAN") UTC"
echo "$U" > "$OUT/peak-start"
info "gmctl render --handover $HANDOVER"
if out=$($GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"); then
    printf '%s\n' "$out" | sed 's/^/      /'
    pass "render --handover (a warning that the planned hand-over is before the scenario's earliest is expected: the override shortens the aging)"
else
    printf '%s\n' "$out"
    fail "render --handover"
    exit 1
fi
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
docker stack ps "$GAME" --filter desired-state=running --format '{{.Name}} {{.Node}} {{.CurrentState}}' \
    | sed 's/^/      /'

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
info "gmctl inject (the faults due at T0)"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
same "status: stage injected" injected "$(stage)"
for n in $(fx schedulers); do
    same "scheduler $n idle before start-load" idle "$(sched_status "$n" | cut -d ' ' -f 1)"
done

# --- start-load, T0, the override ---------------------------------------------
until_epoch "$T0_PLAN" "T0, $PEAK_LEAD minutes before the peak hour (the schedulers idle)"
now=$(date +%s)
PLANT=$(( (now / 60 + 4) * 60 ))                      # the aging's plantings: in 3 to 4 minutes
EARLIEST_PLAN=$(( U + AFTER_PEAK * 60 ))
OVERRIDE=$(( (EARLIEST_PLAN - PLANT) / 60 ))
[ "$OVERRIDE" -ge 30 ] || OVERRIDE=30
info "gmctl start-load --test-aging-minimum ${OVERRIDE}m (the earliest hand-over at about $(hm "$EARLIEST_PLAN") UTC)"
out=$($GMCTL start-load "$SCN" --playground "$PG" --test-aging-minimum "${OVERRIDE}m"); rc=$?
printf '%s\n' "$out" | sed 's/^/      /'
same "start-load: exit 0" 0 "$rc"
same "status: stage load-started" load-started "$(stage)"
same "the override recorded" "${OVERRIDE}m" "$(state 'st["test_harness_override"]["aging_minimum"]')"
check "status heads the override" sh -c "$GMCTL status '$SCN' --playground '$PG' | head -n 1 | grep -q 'TEST HARNESS OVERRIDE'"
T0=$(state 'st["load"]["t0"]')
info "T0 $T0"
echo "$(epoch "$T0")" > "$OUT/t0"
for n in $(fx schedulers); do
    same "scheduler $n running since T0" running "$(sched_status "$n" | cut -d ' ' -f 1)"
done
EARLY=dbagm-${GAME}_early-check.timer
same "the early check's timer is a persistent user unit, active" "active enabled" \
    "$(systemctl --user show -p ActiveState --value "$EARLY") $(systemctl --user is-enabled "$EARLY")"
sampler &
SAMPLER=$!
volumes start

# --- the aging's plantings, by the host timer ---------------------------------
for i in $(fx aging); do
    info "gmctl inject --at $(instant "$PLANT") --instance $i"
    $GMCTL inject "$SCN" --playground "$PG" --at "$(instant "$PLANT")" --instance "$i"
    same "inject --at: $i's planting scheduled" 0 "$?"
    same "$i's timer armed at $(instant "$PLANT")" "$PLANT" "$(next_elapse "dbagm-${GAME}_plant-$i.timer")"
done
EARLY_DUE=$(epoch "$(state 'st["early_check"]["timer"]["due"]')")
same "the early check's timer fires at its recorded due ($(hm "$EARLY_DUE"))" "$EARLY_DUE" \
    "$(next_elapse "$EARLY")"
until_epoch $((PLANT + 30)) "the plantings' timers"
for i in $(fx aging); do
    d=$(( $(date +%s) + 300 ))
    while [ -z "$(state "st['plantings']['$i']['planted_at']")" ] && [ "$(date +%s)" -lt "$d" ]; do
        sleep 10
    done
    same "$i planted by its host timer" "timer ok" \
        "$(state "st['plantings']['$i']['attempts'][-1]['by'] + ' ' + st['plantings']['$i']['attempts'][-1]['outcome']")"
    same "$i's service run by its timer, successfully" "success 0" "$(ran "dbagm-${GAME}_plant-$i.service")"
done
EARLIEST=$(epoch "$(state 'st["earliest_handover"]["at"]')")
EARLY_DUE=$(epoch "$(state 'st["early_check"]["timer"]["due"]')")
info "early check due $(hm "$EARLY_DUE") UTC"
info "earliest hand-over $(hm "$EARLIEST") UTC (waiting for: $(state 'st["earliest_handover"]["waiting_for"]'))"

# The kill and the outage keep clear of the early check: before it when it
# leaves room, after it otherwise (a T0 later than planned, the host having
# been suspended for instance, brings the early check to T0 + 5 minutes).
if [ $(( EARLY_DUE - $(date +%s) )) -lt $(( (OUTAGE_MINUTES + 8) * 60 )) ]; then
    until_epoch $((EARLY_DUE + 120)) "the early check first (the kill and the outage after it)"
fi

# --- a scheduler container killed, resuming ---------------------------------
KILLED=$(fx schedulers | head -n 1)
OUTAGE_NODE=$(fx schedulers | tail -n 1)
set -- $(container "$GAME" "$KILLED")
KILLED_C=$2
info "docker kill $2 ($KILLED, on $1)"
dk "$1" kill "$2" >/dev/null
same "the $KILLED container killed" 0 "$?"
KILL_AT=$(date +%s)
sleep 15
wait_running "$KILLED" 180 "$KILL_AT"
same "$KILLED: a new container, the scheduler running again" 0 "$?"
set -- $(container "$GAME" "$KILLED")
check "$KILLED: the new container is not the killed one ($2)" test -n "$2" -a "$2" != "$KILLED_C"
info "$KILLED resumed after $(( $(date +%s) - KILL_AT )) s: $(sched_status "$KILLED")"
same "$KILLED: its load-started marker still holds T0" "$T0" "$(sched_marker "$KILLED" | head -n 1 | tr -d ' ')"

# --- an outage of a few minutes ----------------------------------------------
info "outage: $OUTAGE_NODE's program stopped for $OUTAGE_MINUTES minutes (s6-svc -d)"
printf '/command/s6-svc -wD -T 60000 -d /run/service/scheduler\n' | on "$OUTAGE_NODE" root
same "$OUTAGE_NODE: its program stopped" 0 "$?"
OUTAGE_AT=$(date +%s)
until_epoch $((OUTAGE_AT + OUTAGE_MINUTES * 60)) "the outage"
UP_AT=$(date +%s)
printf '/command/s6-svc -u /run/service/scheduler\n' | on "$OUTAGE_NODE" root
wait_running "$OUTAGE_NODE" 120 "$UP_AT"
same "$OUTAGE_NODE: started again, running" 0 "$?"
OUTAGE_END=$(date +%s)
info "outage from $(hm "$OUTAGE_AT") to $(hm "$OUTAGE_END") UTC"

# --- the early check, by the host timer -------------------------------------
until_epoch $((EARLY_DUE + 30)) "the early check's timer"
d=$(( $(date +%s) + 600 ))
while [ -z "$(state 'st["early_check"]["result"]["at"]')" ] && [ "$(date +%s)" -lt "$d" ]; do
    sleep 10
done
check "early check: run by its host timer, recorded" test -n "$(state 'st["early_check"]["result"]["at"]')"
same "early check: passed" True "$(state 'st["early_check"]["result"]["passed"]')"
info "early check at $(state 'st["early_check"]["result"]["at"]'): failures $(state 'st["early_check"]["result"]["failures"]'), lost minutes $(state 'st["early_check"]["result"]["lost_minutes"]')"
same "the early check's service run by its timer, successfully" "success 0" "$(ran "dbagm-${GAME}_early-check.service")"

# --- the peak, to the earliest hand-over --------------------------------------
EARLIEST=$(epoch "$(state 'st["earliest_handover"]["at"]')")
until_epoch $((EARLIEST + 30)) "the earliest hand-over (the peak under load, sampled)"
volumes end
on pooler pgbouncer > "$OUT/pgbouncer-stats.txt" <<'EOF'
grep ' stats: ' /var/log/pgbouncer/pgbouncer.log
EOF
on pooler pgbouncer > "$OUT/pgbouncer-show.txt" <<'EOF'
for c in 'SHOW POOLS' 'SHOW STATS' 'SHOW DATABASES' 'SHOW CONFIG'; do
    echo "== $c"; psql -X -A -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "$c"
done
EOF
for n in $(fx schedulers); do
    on "$n" root --env "SINCE=$T0" > "$OUT/log-$n.txt" <<'EOF'
grep -E '^[^ ]+ (summary|key|run|skip|state|reload|fatal) ' /var/log/scheduler/scheduler.log
EOF
done
on prometheus prometheus > "$OUT/series.txt" <<'EOF'
for q in 'count by (job) ({__name__=~".+"})' 'prometheus_tsdb_head_series' 'sum(prometheus_tsdb_storage_blocks_bytes)' 'prometheus_tsdb_wal_storage_size_bytes'; do
    echo "== $q"
    curl -fsS --get --data-urlencode "query=$q" 'http://localhost:9090/prometheus/api/v1/query'
    echo
done
du -sk /prometheus /var/lib/prometheus 2>/dev/null
EOF
kill "$SAMPLER" 2>/dev/null; SAMPLER=

# --- the hand-over check, the snapshot, the hand-over -------------------------
info "gmctl check --handover-check"
out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG" --handover-check); rc=$?
printf '%s\n' "$out" | sed 's/^/      /'
same "hand-over check: exit 0 (passed)" 0 "$rc"
LOST=$(state 'st["outages"]["lost_minutes"]')
info "outages: $(state 'st["outages"]')"
check "the outage recorded: at least $((OUTAGE_MINUTES - 1)) minutes lost (${LOST:-none})" \
    test "${LOST:-0}" -ge $((OUTAGE_MINUTES - 1))
check "lost time within 30 minutes: the earliest hand-over not moved" test "${LOST:-0}" -le 30
same "the earliest hand-over unchanged by the outages" "$(instant "$EARLIEST")" \
    "$(instant "$(epoch "$(state 'st["earliest_handover"]["at"]')")")"

info "gmctl snapshot"
SNAP_AT=$(date +%s)
$GMCTL snapshot "$SCN" --playground "$PG"
same "snapshot: exit 0" 0 "$?"
info "snapshot took $(( $(date +%s) - SNAP_AT )) s"
same "snapshot: taken" taken "$(state 'st["snapshot"]["status"]')"
info "snapshot stops: $(state 'st["snapshot"]["stops"]')"
check "snapshot: its brief stops recorded (Prometheus and Grafana)" \
    test -n "$(state '[s["node"] for s in st["snapshot"]["stops"] if s["node"] in ("prometheus", "grafana")]' | grep -v '^\[\]$')"
same "snapshot: every node's services running again" "" \
    "$(docker stack ps "$GAME" --filter desired-state=running --format '{{.CurrentState}}' | grep -v '^Running')"
cp "$LDIR/state.yaml" "$OUT/state-snapshot.yaml"

info "gmctl status --set handed-over"
$GMCTL status "$SCN" --playground "$PG" --set handed-over
same "hand-over: exit 0" 0 "$?"
same "status: stage handed-over" handed-over "$(stage)"

# --- a restart from the snapshot --------------------------------------------
info "gmctl restart --confirmation (from the hand-over snapshot)"
RESTART_AT=$(date +%s)
$GMCTL restart "$SCN" --playground "$PG" \
    --confirmation "Yes, restart the game from the hand-over snapshot (rehearsal, test harness)"
same "restart: exit 0" 0 "$?"
info "restart took $(( $(date +%s) - RESTART_AT )) s"
GAME2=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
check "restart: a new game id ($GAME2)" test -n "$GAME2" -a "$GAME2" != "$GAME"
same "restart: recorded completed, from the snapshot, with the confirmation" "completed True True" \
    "$(state 'st["restarts"][-1].get("status")') $(state 'st["restarts"][-1].get("from_snapshot")') $(state 'bool(st["restarts"][-1].get("confirmation"))')"
same "status: stage handed-over" handed-over "$(stage)"
OLD_GAME=$GAME; GAME=$GAME2
for n in $(fx schedulers); do
    wait_running "$n" 180 "$RESTART_AT"
    same "scheduler $n resumed after the restart" 0 "$?"
    same "scheduler $n: the load-started marker holds T0" "$T0" "$(sched_marker "$n" | head -n 1 | tr -d ' ')"
done
expected=$(fx present)
info "gmctl check, until every sealed check reads present (up to 6 minutes)"
d=$(( $(date +%s) + 360 ))
while :; do
    out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG"); rc=$?
    { [ "$rc" = 1 ] && [ "$(printf '%s\n' "$out" | sed 's/ — .*//')" = "$expected" ]; } \
        || [ "$(date +%s)" -ge "$d" ] && break
    sleep 15
done
printf '%s\n' "$out" | sed 's/^/      /'
same "after the restart: every fault present (check exit 1)" "$expected" "$(printf '%s\n' "$out" | sed 's/ — .*//')"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out" | sed 's/^/      /'
same "after the restart: validate exit 0" 0 "$rc"
$GMCTL status "$SCN" --playground "$PG" | sed 's/^/      /'
cp "$LDIR/state.yaml" "$OUT/state-restart.yaml"
GAME=$OLD_GAME

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "nothing labelled with $GAME or $GAME2 is left, on any engine" "" "$(labelled)"
same "no systemd user timer, service or stamp of either game is left" "" "$(units)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

# --- the figures --------------------------------------------------------------
python3 - "$OUT" "$EARLIEST" <<'EOF' | tee "$OUT/figures.txt"
import json, math, os, re, sys, yaml
out, earliest = sys.argv[1], int(sys.argv[2])
t0 = int(open(os.path.join(out, "t0")).read())
peak = int(open(os.path.join(out, "peak-start")).read())
def lines(name):
    p = os.path.join(out, name)
    return [l.rstrip("\n") for l in open(p)] if os.path.exists(p) else []
UNITS = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3, "kB": 1e3, "MB": 1e6, "GB": 1e9}
def size(text):
    m = re.match(r"([\d.]+)\s*([A-Za-z]+)", text.strip())
    return float(m.group(1)) * UNITS[m.group(2)] if m else 0.0
def node_of(name):
    return name.split("_", 1)[1].split(".", 1)[0] if "_" in name else name
MiB = 1024 ** 2
# per node: memory and CPU, over T0..hand-over and over the peak hour
nodes, per_host = {}, {}
for l in lines("stats.txt"):
    ts, eng, name, cpu, mem = l.split("|")
    ts = int(ts)
    if not t0 <= ts <= earliest:
        continue
    n = node_of(name)
    m = size(mem.split("/")[0])
    c = float(cpu.rstrip("%") or 0)
    rec = nodes.setdefault(n, {"host": eng, "mem": [], "cpu": [], "pmem": [], "pcpu": []})
    rec["mem"].append(m); rec["cpu"].append(c)
    if peak <= ts < peak + 3600:
        rec["pmem"].append(m); rec["pcpu"].append(c)
    per_host.setdefault(ts, {}).setdefault(eng, 0.0)
    per_host[ts][eng] += m
def pct(xs, q):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(math.ceil(q * len(xs))) - 1)] if xs else 0
print("== memory and CPU per node, T0 to hand-over (peak hour: from %s UTC)"
      % __import__("time").strftime("%H:%M", __import__("time").gmtime(peak)))
print("%-11s %-22s %9s %9s %9s %8s %8s" % ("node", "host", "mem max", "mem p50",
      "peak p50", "cpu max", "cpu p95"))
for n, r in sorted(nodes.items()):
    print("%-11s %-22s %8.0fM %8.0fM %8.0fM %7.1f%% %7.1f%%" % (
        n, r["host"], max(r["mem"]) / MiB, pct(r["mem"], .5) / MiB,
        pct(r["pmem"], .5) / MiB, max(r["cpu"]), pct(r["pcpu"] or r["cpu"], .95)))
hosts = sorted({e for v in per_host.values() for e in v})
print("== the game's memory, summed per sample (G5)")
for e in hosts:
    print("%-22s max %6.0fM" % (e, max(v.get(e, 0) for v in per_host.values()) / MiB))
print("%-22s max %6.0fM" % ("total", max(sum(v.values()) for v in per_host.values()) / MiB))
print("== the hosts' available memory (min over the run)")
for e in hosts:
    rows = [l.split("|") for l in lines("hosts.txt") if l.split("|")[1] == e]
    if rows:
        vals = [r[2].split() for r in rows]
        print("%-22s total %6.0fM, available min %6.0fM max %6.0fM, swap used max %6.0fM" % (
            e, int(vals[0][0]) / 1024, min(int(v[1]) for v in vals) / 1024,
            max(int(v[1]) for v in vals) / 1024,
            max(int(v[2]) - int(v[3]) for v in vals) / 1024))
# volumes
def vols(label):
    res, ts = {}, None
    for l in lines("volumes-%s.txt" % label):
        p = l.split("|")
        if len(p) == 5 and p[4].isdigit():
            ts = int(p[0]); res[(p[1], p[2])] = int(p[4])
    return ts, res
ta, a = vols("start"); tb, b = vols("end")
print("== volumes: growth per hour, T0 + %d min to the hand-over (%.2f h)" % (
    ((ta or t0) - t0) // 60, ((tb or 0) - (ta or 0)) / 3600))
per_node = {}
for k in sorted(b):
    if k in a and tb and ta:
        g = (b[k] - a[k]) / ((tb - ta) / 3600)
        # pg_wal is inside its data volume, bounded by max_wal_size: counted apart
        per_node[k[0]] = per_node.get(k[0], 0) + (-g if k[1].endswith("/pg_wal") else g)
        print("%-11s %-55s %8d kB -> %8d kB  %+9.0f kB/h" % (k[0], k[1], a[k], b[k], g))
print("per node, pg_wal left out:", ", ".join("%s %.1fM/h" % (n, g / 1024) for n, g in sorted(per_node.items())))
print("total: %.1fM/h" % (sum(per_node.values()) / 1024))
# snapshot
st = yaml.safe_load(open(os.path.join(out, "state-snapshot.yaml"))) if os.path.exists(
    os.path.join(out, "state-snapshot.yaml")) else {}
snap = (st or {}).get("snapshot") or {}
tot = sum(int(v.get("bytes") or 0) for v in snap.get("volumes") or [])
print("== snapshot: %s, %.0fM in %d copies" % (snap.get("status"), tot / MiB, len(snap.get("volumes") or [])))
bynode = {}
for v in snap.get("volumes") or []:
    bynode[v["node"]] = bynode.get(v["node"], 0) + int(v.get("bytes") or 0)
print("per node:", ", ".join("%s %.1fM" % (n, s / MiB) for n, s in sorted(bynode.items())))
for s in snap.get("stops") or []:
    print("stop: %s %s from %s to %s" % (s.get("node"), s.get("services"), s.get("stopped_at"), s.get("started_at")))
# PgBouncer's pools
print("== PgBouncer: the pool of shop (SHOW POOLS every sample)")
head, rows = None, []
for l in lines("pools.txt"):
    ts, _, rest = l.partition("|")
    f = rest.split("|")
    if "database" in f:
        head = f; continue
    if head and len(f) == len(head):
        r = dict(zip(head, f)); r["ts"] = int(ts)
        if r.get("database") == "shop":
            rows.append(r)
def window(lo, hi):
    return [r for r in rows if lo <= r["ts"] < hi]
for label, lo, hi in (("before the peak", t0, peak), ("peak hour", peak, min(peak + 3600, earliest + 60))):
    w = window(lo, hi)
    if not w:
        continue
    waits = [int(r["maxwait"]) + int(r.get("maxwait_us", 0)) / 1e6 for r in w]
    waiting = [int(r["cl_waiting"]) for r in w]
    demand = [int(r["sv_active"]) + int(r["cl_waiting"]) for r in w]
    print("%-16s %3d samples: cl_waiting>0 in %3.0f%%, cl_waiting max %d, maxwait max %.1f s p50 %.2f s,"
          " sv_active+cl_waiting p50 %d p90 %d p95 %d max %d" % (
          label, len(w), 100.0 * sum(1 for x in waiting if x) / len(w), max(waiting), max(waits),
          pct(waits, .5), pct(demand, .5), pct(demand, .9), pct(demand, .95), max(demand)))
# the stats lines: offered load (xacts/s x mean transaction time) per minute
print("== PgBouncer's stats lines: offered load A = xacts/s x xact time (Erlangs)")
load = []
for l in lines("pgbouncer-stats.txt"):
    m = re.match(r"(\S+ \S+)", l)
    x = re.search(r"([\d.]+) xacts/s", l); xt = re.search(r"xact ([\d.]+) us", l); wt = re.search(r"wait ([\d.]+) us", l)
    if not (x and xt):
        continue
    when = re.search(r"(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)", l)
    ts = int(__import__("calendar").timegm(__import__("time").strptime(when.group(1), "%Y-%m-%d %H:%M:%S"))) if when else 0
    load.append((ts, float(x.group(1)), float(xt.group(1)) / 1e6, float(wt.group(1)) / 1e6 if wt else 0, l))
def erlang_c(n, a):
    if a >= n:
        return 1.0
    s = sum(a ** k / math.factorial(k) for k in range(n))
    top = a ** n / math.factorial(n) * n / (n - a)
    return top / (s + top)
for label, lo, hi in (("before the peak", t0, peak), ("peak hour", peak, peak + 3600)):
    w = [r for r in load if lo <= r[0] < hi]
    if not w:
        continue
    a = [r[1] * r[2] for r in w]
    print("%-16s %3d minutes: xacts/s p50 %.2f, xact p50 %.0f ms, wait p50 %.0f ms max %.0f ms, A p50 %.2f p90 %.2f max %.2f" % (
        label, len(w), pct([r[1] for r in w], .5), 1000 * pct([r[2] for r in w], .5),
        1000 * pct([r[3] for r in w], .5), 1000 * max(r[3] for r in w), pct(a, .5), pct(a, .9), max(a)))
    for q in (.5, .9):
        A = pct(a, q)
        print("   Erlang C at A=%.2f: " % A + ", ".join("pool %d P(wait) %.0f%%" % (n, 100 * erlang_c(n, A)) for n in range(3, 9)))
# the noon stall
print("== the producer's fixed-time runs and orders.place around the peak's start")
for l in lines("log-producer.txt"):
    if " run " in l or " skip " in l:
        print(l)
for l in lines("log-producer.txt"):
    m = re.search(r"key minute=(\S+) key=orders\.place ", l)
    if m:
        ts = int(__import__("calendar").timegm(__import__("time").strptime(m.group(1), "%Y-%m-%dT%H:%MZ")))
        if peak - 180 <= ts <= peak + 300:
            print(l)
print("== Prometheus (series per job; TSDB)")
for l in lines("series.txt"):
    print(l[:600])
EOF

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "rehearsal $PG: all $passes checks passed in ${elapsed}s (games $GAME, $GAME2); figures in $OUT/figures.txt"
else
    echo "rehearsal $PG: $failures check(s) failed, $passes passed, in ${elapsed}s (games $GAME, $GAME2); figures in $OUT/figures.txt"
    exit 1
fi
