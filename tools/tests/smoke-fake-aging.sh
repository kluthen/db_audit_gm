#!/bin/sh
# The short fake games of v0.6 (master spec 9.4, 9.8 to 9.10, 12.1; capture
# W4 items 1 to 5 and W4-x; spec D540, D578, D584 to D586, D590): fake aging
# run end to end on tarnbeck-outdoor-shop or tarnbeck-outdoor-campaign, each
# as it is (its span, its data; never a copy at another span), on one host,
# under 30 minutes with the deployment.
#
#   sh tools/tests/smoke-fake-aging.sh <scenario-dir> [--record]
#
# The scenario is known by its scenario.yaml `id`: tarnbeck-outdoor-shop or
# tarnbeck-outdoor-campaign (any other: exit 2). Playground `fake-smoke`, in
# the scenario folder's local/ (git-ignored), removed after a clean teardown.
#
# Its selection, a tail that fits a floor capped at 15 minutes (12.1): the
# shop f1, f2, f3, f6, f8, f9, f10; the campaign f1 to f4 and f7 to f9 (f4
# and f7 through the cover, spec D523); a selected instance whose fault is no
# longer `supported` drops out (9.8's fallback), named in a FIGURE line. The
# rest through `render --test-leave-out`, the tail through
# `--test-tail-floor 15m` (hidden options).
#
# The start window: H is the next whole hour the setup can reach; the anchor
# H - 15 min. The script starts only when the anchor lies between SETUP_MAX
# (the setup's measured bound, deploy to the fill's end, per scenario) and
# LEAD_MAX (30 minutes less the measured time from the anchor to the
# teardown's end) ahead; otherwise exit 3, nothing deployed, its line naming
# the window. It never waits for a window: the host lock is never held idle.
#
# Steps: fit, render --aging fake --handover H, deploy, load-data, inject,
# (the shop) M1 dumped at the virtual T0 and the index f8 drops measured,
# (the campaign) rpt.close_day()'s settings and source read, fill, the wait to
# the anchor, clean-restart, start-load; then in the tail:
#   - every service of the game (the monitoring's included) started within
#     10 s after restart.at, none before (12.1: the monitoring started with
#     the rest), read as each node's PID 1 start time;
#   - the `player` account unable to list /var/lib/prometheus on the
#     Prometheus node (D540);
#   - (the shop) M1 at the read and its comparison with run R scaled to the
#     game's span (W4 item 2, D586); (the campaign) P0's invariants
#     (rpt.close_day()'s proconfig and prosrc md5 unchanged across the fill,
#     the nightly close once at 01:30 scenario time, every hourly roll-up
#     once at :05 in rpt.etl_runs);
#   - gmctl history by hand at restart.at + 12 min, as the timer would (its
#     run after it a no-op); the record's history {ok, seam ok} and the
#     import's figures; Prometheus' lowest timestamp right after it;
#   - the early check by hand right after it: every selected instance
#     present, its history line `ok, seam ok`;
#   - gmctl history --check-seam: exit 0 is the seam's verdict;
#   - the tells (tools/fake_aging/tells.sh, the shop with --reference and
#     --start, its M1 at the virtual T0);
#   - (the shop) M3 against run R over the hours the past holds (W4 item 3);
#     f8's step: pg_database_size_bytes{datname="shop"} over the forged past,
#     the last sample before f8's planting (08:00) less the first after it,
#     against f8's gauge_before value, within the larger of 1 % of it and
#     the tail's own largest step (W4 item 4, D584, D585);
#   - (the campaign) f1's tup_inserted rate either side of the seam (FIGURE;
#     a step is a finding for v1.0 gating, never a failure: D578);
#   - FIGURE lines, never judged (D590): each scheduler key's service time
#     in the tail (calibrate.py keys' median, the method service-times.yaml
#     was written with) against its service-times.yaml, each database node's
#     WAL rate in the tail (pg_stat_wal since the restart's reset) against
#     its wal-rate.yaml, with their ratios;
#   - the retention check: Prometheus' lowest timestamp at the read within
#     one minute of the virtual T0;
#   - gmctl status and the restart record printed;
#   -> teardown (on any exit, a trap): nothing labelled with the game id left.
# It does not wait for H: every check 12.1 lists reads by the early check.
#
# FIGURE lines: the wall time from the start to the teardown's end (a check:
# FAIL at 30 minutes or more), the setup from the deploy to the fill's end,
# the fill's duration, the clean-restart's, the deploy to restart.at, gmctl
# history's duration and figures.
#
# --record: the output also written to
# tools/fake_aging/calibration/<scenario id>-short-game-<YYYYMMDDTHHMMZ>.txt,
# opening with the command, the commit, the start and the wall time (as
# every calibration file); not for a refused start (exit 2 or 3).
#
# Exit status: 0 nothing failed (a SKIP for the reference archive counts no
# failure); 1 any failure; 2 usage or a precondition; 3 outside the window.
#
# Needs: a swarm manager on the local engine, python3 with PyYAML, a systemd
# user manager, the scenario's images built, host ports 2222 and 8080 free,
# run R's archive for the shop's comparisons (else SKIP). Run it under the
# host lock and the sleep inhibitor (build plan, workflow deltas):
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#     sh tools/tests/smoke-fake-aging.sh scenarios/tarnbeck-outdoor-shop
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
FA=$REPO/tools/fake_aging
PG=fake-smoke
TAIL=15m
LABELS="com.docker.stack.namespace dbagm.game dbagm.snapshot"
KINDS="service network volume config secret"

usage() {
    echo "usage: sh tools/tests/smoke-fake-aging.sh <scenario-dir> [--record]" >&2
    exit 2
}
SRC= record=no
for arg in "$@"; do
    case $arg in
        --record) record=yes ;;
        -*) usage ;;
        *) [ -z "$SRC" ] || usage; SRC=$arg ;;
    esac
done
[ -n "$SRC" ] && [ -f "$SRC/scenario.yaml" ] || usage
SCN=$(cd "$SRC" && pwd)
SID=$(python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["id"])' "$SCN/scenario.yaml")

# The scenarios it knows: the selection, the database nodes the tells read,
# and the measured bounds of the window (seconds; W4-x records them).
case $SID in
    tarnbeck-outdoor-shop)
        SELECTION="f1 f2 f3 f6 f8 f9 f10"
        DB_NODES="db"
        SETUP_MAX=600               # deploy to the fill's end, at most (measured 508 s, fill 478 s, 2026-11-20)
        POST_MAX=960                # the anchor to the teardown's end, at most (measured 841 s)
        ;;
    tarnbeck-outdoor-campaign)
        SELECTION="f1 f2 f3 f4 f7 f8 f9"
        DB_NODES="db reporting"
        SETUP_MAX=330               # measured 228 and 230 s (fill 191 and 195 s), 2026-11-20
        POST_MAX=960                # measured 864 and 868 s
        ;;
    *)
        echo "smoke-fake-aging.sh: $SID: not a scenario this script plays (tarnbeck-outdoor-shop, tarnbeck-outdoor-campaign)" >&2
        exit 2
        ;;
esac
LEAD_MAX=$(( 1800 - POST_MAX ))

# --- --record: this script again, its output kept ---------------------------
if [ "$record" = yes ]; then
    start=$(date +%s)
    stamp=$(date -u -d "@$start" +%Y%m%dT%H%MZ)
    out=$(mktemp "${TMPDIR:-/tmp}/smoke-fake-aging.XXXXXX")
    rcf=$out.rc
    { rc=0; sh "$0" "$SRC" 2>&1 || rc=$?; echo "$rc" > "$rcf"; } | tee "$out"
    rc=$(cat "$rcf")
    if [ "$rc" -le 1 ]; then
        commit=$(git -C "$REPO" rev-parse --short HEAD)
        [ -z "$(git -C "$REPO" status --porcelain -- tools scenarios)" ] \
            || commit="$commit, with uncommitted changes under tools/ or scenarios/ (this record's own chunk)"
        dest=$FA/calibration/$SID-short-game-$stamp.txt
        {
            echo "command: sh tools/tests/smoke-fake-aging.sh ${SRC} --record (under flock /tmp/dbagm-docker.lock and systemd-inhibit)"
            echo "commit: $commit"
            echo "start: $(date -u -d "@$start" +%Y-%m-%dT%H:%M:%SZ)"
            echo "wall time: $(( $(date +%s) - start )) s, deployment and teardown included; exit $rc"
            echo
            cat "$out"
        } > "$dest"
        echo "recorded: ${dest#"$REPO"/}" >&2
    fi
    rm -f "$out" "$rcf"
    exit "$rc"
fi

started=$(date +%s)
failures=0
passes=0
skips=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
skip() { printf 'SKIP  %s\n' "$*"; skips=$((skips + 1)); }
info() { printf '....  %s\n' "$*"; }
figure() { printf 'FIGURE  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}
verdicts() {   # a tool's output: its PASS, FAIL and SKIP lines counted
    printf '%s\n' "$1"
    passes=$((passes + $(printf '%s\n' "$1" | grep -c '^PASS' || true)))
    failures=$((failures + $(printf '%s\n' "$1" | grep -c '^FAIL' || true)))
    skips=$((skips + $(printf '%s\n' "$1" | grep -c '^SKIP' || true)))
}
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date -u -d "$1" +%s; }

# --- the window: the anchor H - 15 min, H a whole hour ------------------------
now=$(date +%s)
h=$(( (now + SETUP_MAX + 900 + 3599) / 3600 * 3600 ))
anchor=$(( h - 900 ))
if [ $(( anchor - now )) -gt "$LEAD_MAX" ]; then
    from=$(( 45 * 60 - LEAD_MAX )) to=$(( 45 * 60 - SETUP_MAX ))
    printf 'smoke-fake-aging.sh: %s: the anchor would come %d min after the start: start between hh:%02d:%02d and hh:%02d:%02d (nothing done)\n' \
        "$SID" $(( (anchor - now) / 60 )) $(( from / 60 )) $(( from % 60 )) $(( to / 60 )) $(( to % 60 )) >&2
    exit 3
fi
HANDOVER=$(date -u -d "@$h" +%Y-%m-%dT%H:%MZ)

# scn <what>: from the scenario's files
scn() {
    python3 -B - "$SCN" "$REPO" "$@" <<'EOF'
import os, re, sys, yaml
scn, repo, what, args = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
sys.path.insert(0, repo)
from tools.gm.model import format_size, parse_cpu, parse_size
s = yaml.safe_load(open(os.path.join(scn, "scenario.yaml")))
def fault_file(fid):
    for root in (scn, repo):
        p = os.path.join(root, "faults", fid, "fault.yaml")
        if os.path.isfile(p):
            return p
def duration(text):
    m = re.fullmatch(r"(\d+)([smhd])", str(text))
    return int(m.group(1)) * {"s": 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)]
inst = {i["id"]: i for i in s["fault_instances"]}
if what == "capacity":
    hosts = s["designed_for"]["hosts"]
    print("%g" % sum(parse_cpu(h["cpu"]) for h in hosts),
          format_size(sum(parse_size(h["memory"]) for h in hosts)),
          format_size(sum(parse_size(h["disk"]) for h in hosts)))
elif what == "images":
    for n in s["nodes"]:
        print(f"127.0.0.1:5000/dbagm/{n['brick']['id']}:{n['brick']['version']}")
elif what == "aging":
    print(duration(s["aging"]["minimum"]), s["aging"]["handover_at"])
elif what == "selection":      # the wanted instances still supported; "drop <id> <support>" for the others
    keep = []
    for iid in args:
        f = yaml.safe_load(open(fault_file(inst[iid]["fault"]["id"])))
        support = ((f.get("aging") or {}).get("fake") or {}).get("support")
        if support == "supported":
            keep.append(iid)
        else:
            print(f"drop {iid} {support}")
    print("keep " + " ".join(keep))
    print("leave " + ",".join(i for i in inst if i not in keep))
elif what == "gauge":           # f8's gauge_before value
    f = yaml.safe_load(open(fault_file(inst[args[0]]["fault"]["id"])))
    print(*[int(e["value"]) for e in f.get("history") or [] if e["kind"] == "gauge_before"])
elif what == "plant":           # an instance's planting, seconds before the hand-over
    m = re.fullmatch(r"handover-(\d+[smhd])", str(inst[args[0]].get("plant_at") or ""))
    print(duration(m.group(1)) if m else "")
elif what == "files":           # <kind> <node>: the node's service-times or wal-rate file
    p = os.path.join(scn, "nodes", args[1], args[0])
    print(p if os.path.isfile(p) else "")
EOF
}
set -- $(scn aging)
AGING_S=$1 HANDOVER_AT=$2
VT0=$(iso $(( h - AGING_S )))
ANCHOR=$(iso "$anchor")
HO_MIN=$(( ${HANDOVER_AT%%:*} * 60 + ${HANDOVER_AT##*:} ))
scen_time() {   # scen_time <epoch>: its scenario time, HH:MM
    m=$(( ((HO_MIN + ($1 - h) / 60) % 1440 + 1440) % 1440 ))
    printf '%02d:%02d' $(( m / 60 )) $(( m % 60 ))
}

# --- preconditions -------------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $(scn images | sort -u); do
    docker image inspect "$image" >/dev/null 2>&1 || { echo "image $image not built" >&2; exit 2; }
done
systemctl --user show --property=Version >/dev/null 2>&1 \
    || { echo "no systemd user manager: the timers need one" >&2; exit 2; }
LDIR=$SCN/local/$PG
if [ -f "$LDIR/state.yaml" ]; then
    left=$(python3 -c 'import sys, yaml; print((yaml.safe_load(open(sys.argv[1])) or {}).get("stage", ""))' "$LDIR/state.yaml")
    [ "$left" = torn-down ] || [ "$left" = fitted ] || [ "$left" = rendered ] \
        || { echo "playground $PG holds a game at stage $left: gmctl teardown $SRC --playground $PG first" >&2; exit 2; }
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/smoke-fake-aging.XXXXXX")
GAME=
deployed=no
labelled() {
    [ -n "$GAME" ] || return 0
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}
cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG" >/dev/null
        left=$(labelled)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

game_id() { sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml"; }
yval() { python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = (d or {}).get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" "$2"; }
stval() { yval "$LDIR/state.yaml" "$1"; }
recval() { yval "$LDIR/fake-aging.yaml" "$1"; }
on() {   # on <node> <user> [--env K=V]: the script on stdin, run there
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
RO="-c default_transaction_read_only=on -c statement_timeout=60s -c log_statement=none -c log_min_duration_statement=-1 -c log_min_error_statement=panic -c pg_stat_statements.track=none -c pgaudit.log=none -c client_min_messages=warning"
sql() {   # sql <node> <database> <query>: read-only and unseen, as postgres
    printf '%s\n' "PGOPTIONS='$RO' psql -X -At -F '|' -v ON_ERROR_STOP=1 -d '$2' <<'GMSQL'
$3
GMSQL" | on "$1" postgres
}
PROM_API=http://127.0.0.1:9090/prometheus/api/v1
promq() {   # promq <expr> [<epoch>]: an instant query's values, `<labels> <value>` a line
    printf '%s\n' "curl -fsS --max-time 60 -G '$PROM_API/query' --data-urlencode 'query=$1' ${2:+--data-urlencode 'time=$2'}" \
        | on prometheus prometheus | python3 -c 'import json, sys
d = json.load(sys.stdin)["data"]["result"]
print("\n".join(sorted(" ".join(f"{k}={v}" for k, v in sorted(r["metric"].items()) if k != "__name__")
                       + " " + r["value"][1] for r in d)))'
}
promr() {   # promr <selector>[<range>] <epoch>: its single series' samples, `<epoch> <value>`
    printf '%s\n' "curl -fsS --max-time 60 -G '$PROM_API/query' --data-urlencode 'query=$1' --data-urlencode 'time=$2'" \
        | on prometheus prometheus | python3 -c 'import json, sys
d = json.load(sys.stdin)["data"]["result"]
print("\n".join(f"{t} {v}" for r in d[:1] for t, v in r["values"]))'
}
lowest() { promq prometheus_tsdb_lowest_timestamp_seconds | awk '{printf "%d", $NF}'; }
wait_until() {   # wait_until <epoch>
    w=$(( $1 - $(date +%s) ))
    [ "$w" -le 0 ] || { info "waiting $w s, to $(iso "$1")"; sleep "$w"; }
}

# --- the selection ---------------------------------------------------------------
sel=$(scn selection $SELECTION)
KEEP=$(printf '%s\n' "$sel" | sed -n 's/^keep //p')
LEAVE=$(printf '%s\n' "$sel" | sed -n 's/^leave //p')
printf '%s\n' "$sel" | sed -n 's/^drop \([^ ]*\) \(.*\)/\1 \2/p' | while read -r i s; do
    figure "$i dropped from the selection: its fault's support is $s (master spec 9.8's fallback)"
done
info "$SID: hand-over $HANDOVER, virtual T0 $VT0, anchor $ANCHOR ($(( anchor - now )) s ahead), tail $TAIL"
info "selection: $KEEP; left out: $LEAVE"
set -- $(scn capacity)
CPU=$1 MEMORY=$2 DISK=$3

# --- set-up to the tail -------------------------------------------------------------
$GMCTL fit "$SCN" --playground "$PG" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK" > "$tmp/fit.out" 2>&1 \
    || { cat "$tmp/fit.out"; fail "fit"; exit 1; }
pass "fit: $CPU CPU / $MEMORY / $DISK on this host"
GAME=$(game_id)
info "game id $GAME"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" --aging fake \
    --test-tail-floor "$TAIL" --test-leave-out "$LEAVE" > "$tmp/render.out" 2>&1 \
    || { cat "$tmp/render.out"; fail "render --aging fake"; exit 1; }
same "the record: mode, virtual T0, anchor, tail" "fake $VT0 $ANCHOR $TAIL" \
    "$(recval mode) $(recval virtual_t0) $(recval anchor) $(recval tail)"
info "the record's refused: $(recval refused)"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
deployed=yes
t_deploy=$(date +%s)
$GMCTL deploy "$SCN" --playground "$PG" > "$tmp/deploy.out" 2>&1 || { tail -n 20 "$tmp/deploy.out"; fail "deploy"; exit 1; }
d_s=$(( $(date +%s) - t_deploy ))
$GMCTL load-data "$SCN" --playground "$PG" > "$tmp/load.out" 2>&1 || { tail -n 20 "$tmp/load.out"; fail "load-data"; exit 1; }
$GMCTL inject "$SCN" --playground "$PG" > "$tmp/inject.out" 2>&1 || { tail -n 20 "$tmp/inject.out"; fail "inject"; exit 1; }
pass "deploy, load-data, inject ($(( $(date +%s) - t_deploy )) s, the deploy $d_s s)"

case $SID in
tarnbeck-outdoor-shop)
    if sh "$FA/m1_dump.sh" "$SCN" --playground "$PG" --node db --database shop "$tmp/m1-t0" > "$tmp/m1-t0.out" 2>&1; then
        pass "M1 dumped at the virtual T0 ($(tail -n 1 "$tmp/m1-t0.out"))"
    else
        cat "$tmp/m1-t0.out"; fail "M1 at the virtual T0"
    fi
    IDX=$(sql db shop "SELECT sum(pg_relation_size(i.indexrelid)) FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
        WHERE i.indrelid = 'order_lines'::regclass AND a.attname = 'order_id' AND i.indnatts = 1") || IDX=-
    figure "the index f8 drops, before the fill: $IDX bytes (pg_relation_size; f8's gauge_before $(scn gauge f8), from run R)"
    ;;
tarnbeck-outdoor-campaign)
    PROC="SELECT p.proconfig::text || '|' || md5(p.prosrc) FROM pg_proc p WHERE p.oid = 'rpt.close_day()'::regprocedure"
    proc_before=$(sql reporting reporting "$PROC") || proc_before=unread
    info "rpt.close_day() before the fill: $proc_before"
    ;;
esac

t=$(date +%s)
$GMCTL fill "$SCN" --playground "$PG" > "$tmp/fill.out" 2> "$tmp/fill.err" \
    || { tail -n 20 "$tmp/fill.err"; fail "fill: $(stval fill.reason)"; exit 1; }
fill_end=$(date +%s)
fill_s=$(( fill_end - t ))
same "the fill: ok" "ok" "$(stval fill.outcome)"
figure "the fill: $fill_s s ($(( (anchor - $(epoch "$VT0")) / 60 )) virtual minutes)"
figure "the setup, the deploy to the fill's end: $(( fill_end - t_deploy )) s (the script's bound $SETUP_MAX s)"
[ "$fill_end" -lt "$anchor" ] && pass "the fill ended before the anchor ($(( anchor - fill_end )) s)" \
    || fail "the fill ended $(( fill_end - anchor )) s after the anchor"
if [ "$SID" = tarnbeck-outdoor-shop ]; then
    F8_AT=$(iso $(( h - $(scn plant f8) )))
    same "f8 planted by the fill at its virtual instant" "$F8_AT" "$(stval plantings.f8.planted_at)"
    figure "the shop's size after the fill: $(sql db postgres "SELECT pg_database_size('shop')") bytes"
else
    proc_after=$(sql reporting reporting "$PROC") || proc_after=unread
    info "rpt.close_day() after the fill: $proc_after"
fi
wait_until $(( anchor + 1 ))
t=$(date +%s)
$GMCTL clean-restart "$SCN" --playground "$PG" > "$tmp/restart.out" 2>&1 \
    || { tail -n 20 "$tmp/restart.out"; fail "clean-restart: $(stval clean_restart.reason)"; exit 1; }
cr_s=$(( $(date +%s) - t ))
sed 's/^/....  clean-restart: /' "$tmp/restart.out"
$GMCTL start-load "$SCN" --playground "$PG" > "$tmp/start.out" 2>&1 \
    || { cat "$tmp/start.out"; fail "start-load"; exit 1; }
AT=$(recval restart.at)
at=$(epoch "$AT")
pass "clean-restart and start-load, restart.at $AT ($(( at - anchor )) s after the anchor)"
figure "clean-restart: $cr_s s"
figure "the setup's time, the deploy to restart.at: $(( at - t_deploy )) s; the wait for the anchor $(( anchor - fill_end )) s within it, so $(( at - t_deploy - (anchor - fill_end) )) s without it; the fill $fill_s s"

# --- the tail: the starts, the player's reach ----------------------------------------
sleep 20
starts=$(python3 - "$LDIR/implementation.yaml" <<'EOF'
import sys, yaml
print(" ".join(yaml.safe_load(open(sys.argv[1]))["nodes"]))
EOF
)
bad= n_ok=0 latest=0
for n in $starts; do
    s=$(printf '%s\n' 'set -eu
st=$(sed "s/^.*) //" /proc/1/stat | cut -d " " -f 20)
bt=$(sed -n "s/^btime //p" /proc/stat)
hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
echo "$st $bt $hz"' | on "$n" root 2>/dev/null | awk '{printf "%.2f", $2 + $1 / $3}') || s=
    if [ -z "$s" ]; then
        bad="$bad $n:unread"
        continue
    fi
    d=$(awk -v s="$s" -v a="$at" 'BEGIN { printf "%.1f", s - a }')
    if awk -v d="$d" 'BEGIN { exit !(d >= -1 && d <= 10) }'; then
        n_ok=$((n_ok + 1))
    else
        bad="$bad $n:${d}s"
    fi
    info "start: $n $d s from restart.at"
done
[ -z "$bad" ] && pass "every service started with the rest, within 10 s after restart.at ($n_ok nodes, the monitoring's included)" \
    || fail "services not started with the rest:$bad"
if printf 'ls /var/lib/prometheus\n' | on prometheus player > "$tmp/ls.out" 2>&1; then
    fail "the player account lists /var/lib/prometheus on the Prometheus node (D540)"
else
    grep -qi 'permission denied' "$tmp/ls.out" \
        && pass "the player account cannot list /var/lib/prometheus on the Prometheus node (D540)" \
        || fail "the player's ls on the Prometheus node: not a permission refusal ($(tr '\n' ' ' < "$tmp/ls.out" | cut -c1-200))"
fi

# --- the tail: before the import -----------------------------------------------------
case $SID in
tarnbeck-outdoor-shop)
    REF=$(sh "$FA/reference/extract.sh" m1-fa-real-20261115T0800/ m3-r-20261115.json 2> "$tmp/extract.err") && ref_rc=0 || ref_rc=$?
    if [ "$ref_rc" -eq 0 ]; then
        R_M1=$(printf '%s\n' "$REF" | sed -n 's|/table_stats.csv$||p')
        R_M3=$(printf '%s\n' "$REF" | grep 'm3-r-20261115.json$')
    else
        R_M1=$tmp/absent R_M3=$tmp/absent.json
        [ "$ref_rc" -eq 77 ] || fail "extract.sh: exit $ref_rc ($(tr '\n' ' ' < "$tmp/extract.err" | cut -c1-200))"
    fi
    if sh "$FA/m1_dump.sh" "$SCN" --playground "$PG" --node db --database shop "$tmp/m1-read" > "$tmp/m1-read.out" 2>&1; then
        read_at=$(date +%s)
        SPAN="$(scen_time "$(epoch "$VT0")")-$(scen_time "$read_at")"
        info "M1 at the read ($(tail -n 1 "$tmp/m1-read.out")); the game's span $SPAN scenario time"
        rc=0
        out=$(python3 "$FA/m1_compare.py" "$R_M1" "$tmp/m1-read" --start "$tmp/m1-t0" --profile "$R_M3" --span "$SPAN" 2>&1) || rc=$?
        verdicts "$out"
        [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || [ "$rc" -eq 77 ] || fail "m1_compare.py: exit $rc"
    else
        cat "$tmp/m1-read.out"; fail "M1 at the read"
    fi
    ;;
tarnbeck-outdoor-campaign)
    same "P0: rpt.close_day()'s proconfig and prosrc md5 unchanged across the fill" "$proc_before" "$proc_after"
    runs=$(sql reporting reporting "SELECT job || '|' || extract(epoch FROM started_at)::bigint FROM rpt.etl_runs
                                    WHERE started_at >= '$VT0' ORDER BY started_at") || runs=
    verdict=$(python3 - "$runs" "$(epoch "$VT0")" "$h" "$HO_MIN" "$(date +%s)" <<'EOF'
import sys
runs, vt0, h, ho, now = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
def scen(t):
    m = (ho + (t - h) // 60) % 1440
    return m // 60, m % 60
got = {}
for line in runs.splitlines():
    job, _, t = line.partition("|")
    got.setdefault(job, []).append(int(t))
close = got.get("rollup-close", [])
want_close = [t for t in range(vt0, now, 60) if scen(t) == (1, 30)]
ok = len(close) == 1 and len(want_close) == 1 and 0 <= close[0] - want_close[0] < 60
print(("PASS" if ok else "FAIL") + f"  P0: the nightly close once at 01:30 scenario time in rpt.etl_runs "
      f"({len(close)} run(s): {', '.join('%02d:%02d' % scen(t) for t in close) or 'none'})")
hourly = got.get("rollup-hourly", [])
due = [t for t in range(vt0, now - 60, 60) if scen(t)[1] == 5]
hours = {}
for t in hourly:
    hours.setdefault((t - vt0) // 3600, []).append(t)
missing = [d for d in due if not any(0 <= t - d < 60 for t in hourly)]
twice = [k for k, v in hours.items() if len(v) > 1]
off = [t for t in hourly if scen(t)[1] != 5]
ok = not missing and not twice and not off and len(hourly) == len(due)
print(("PASS" if ok else "FAIL") + f"  P0: every hourly roll-up once at :05 in rpt.etl_runs ({len(hourly)} "
      f"run(s) for {len(due)} due; missing {len(missing)}, twice {len(twice)}, off :05 {len(off)})")
EOF
)
    verdicts "$verdict"
    ;;
esac

# --- the import, by hand at restart.at + 12 min; the early check -----------------------
# A few seconds before the timer's due time, so the hand run imports and the
# timer's run, waiting on the game's run lock, finds it done (W3 item 6).
wait_until $(( at + 715 ))
before_import=$(lowest)
t=$(date +%s)
if $GMCTL history "$SCN" --playground "$PG" > "$tmp/h.out" 2>&1; then
    pass "gmctl history exits 0 ($(( $(date +%s) - t )) s)"
else
    fail "gmctl history (exit $?)"
fi
h_s=$(( $(date +%s) - t ))
sed 's/^/....  history: /' "$tmp/h.out"
grep -q 'Already recorded' "$tmp/h.out" && fail "gmctl history by hand found the import done (the timer ran first)" \
    || pass "gmctl history by hand imported, before the timer's run"
same "the record's history: ok, seam ok" "ok ok" "$(recval history.result) $(recval history.seam)"
python3 - "$LDIR/state.yaml" "$h_s" <<'EOF'
import json, sys, yaml
a = yaml.safe_load(open(sys.argv[1]))["history_import"]["attempts"]
f = a[-1].get("figures") or {}
peak = f.get("promtool_memory_peak_bytes")
print(f"FIGURE  history: {sys.argv[2]} s, {len(a)} attempt(s); tail {f.get('tail_series')} series read in "
      f"{f.get('tail_read_s')} s; composed {f.get('series')} series, {f.get('samples')} samples, "
      f"{f.get('openmetrics_bytes')} bytes in {f.get('compose_s')} s; promtool {f.get('import_s')} s, "
      f"peak {peak if peak is None else round(peak / 2**20, 1)} MiB; loaded after "
      f"{f.get('loaded_after_s')} s; seam {f.get('seam_s')} s")
print(f"FIGURE  history: blocks {json.dumps(f.get('blocks'))}; tsdb {json.dumps(f.get('tsdb'))}")
print(f"FIGURE  history: report {json.dumps(f.get('report'))}")
EOF
k=0
until [ "$(lowest)" -lt "$at" ] 2>/dev/null || [ "$k" -ge 60 ]; do
    sleep 5; k=$((k + 5))
done
after_import=$(lowest)
figure "Prometheus' lowest timestamp: before the import $(iso "$before_import"), right after it $(iso "$after_import") ($(( after_import - $(epoch "$VT0") )) s from the virtual T0, $k s for its self-scrape)"
$GMCTL check "$SCN" --playground "$PG" --early-check > "$tmp/early.out" 2>&1 && early_rc=0 || early_rc=$?
sed 's/^/....  early check: /' "$tmp/early.out"
same "the early check's history line" "ok, seam ok" "$(stval early_check.result.history)"
verdict=$(python3 - "$LDIR/state.yaml" "$KEEP" "$LEAVE" <<'EOF'
import re, sys, yaml
st = yaml.safe_load(open(sys.argv[1]))
r = (st.get("early_check") or {}).get("result") or {}
want, left = sys.argv[2].split(), set(sys.argv[3].split(","))
got = {f["instance"]: f for f in r.get("faults") or []}
for i in want:
    f = got.get(i)
    ok = f is not None and f.get("verdict") == "present"
    print(("PASS" if ok else "FAIL") + f"  the early check reads {i} present"
          + ("" if ok else f" (got {f.get('verdict') if f else 'no line'}: {(f or {}).get('line')})"))
# The early check's own verdict expects the answer key's hand-over readings,
# masking included; a masking by an instance this game leaves out (the
# test's --test-leave-out) does not hold here, so it is reported, not judged.
other = []
for x in r.get("failures") or []:
    m = re.search(r"\(masked by ([^)]*)\)$", x)
    if m and set(s.strip() for s in m.group(1).split(",")) <= left:
        print(f"FIGURE  the early check's failure from a masking by an instance left out of this game: {x}")
    else:
        other.append(x)
print(("PASS" if not other else "FAIL") + "  the early check: no failure but a left-out instance's masking"
      + (f" ({'; '.join(other)})" if other else ""))
n = len((st.get("history_import") or {}).get("attempts") or [])
print(("PASS" if n == 1 else "FAIL") + f"  the timer's run after the hand run a no-op: {n} attempt(s) recorded")
EOF
)
verdicts "$verdict"
info "the early check's exit: $early_rc; the timer's unit: $(systemctl --user show -p Result -p ExecMainStatus "dbagm-${GAME}_history.service" 2>/dev/null | tr '\n' ' ')"

# --- the seam, the tells ----------------------------------------------------------------
if $GMCTL history "$SCN" --playground "$PG" --check-seam > "$tmp/cs.out" 2>&1; then
    pass "history --check-seam: exit 0, the seam joined, a past present"
else
    fail "history --check-seam (exit $?)"
fi
sed 's/^/....  check-seam: /' "$tmp/cs.out"
nodes=
for n in $DB_NODES; do nodes="$nodes --node $n"; done
rc=0
ref=
if [ "$SID" = tarnbeck-outdoor-shop ]; then
    ref=--reference
    [ -f "$tmp/m1-t0/table_stats.csv" ] && ref="$ref --start $tmp/m1-t0"
fi
out=$(sh "$FA/tells.sh" "$SCN" --playground "$PG" $nodes $ref 2>&1) || rc=$?
verdicts "$out"
[ "$rc" -le 1 ] || fail "tells.sh: exit $rc"

# --- the shop: M3 and f8's step; the campaign: f1 at the seam ------------------------------
case $SID in
tarnbeck-outdoor-shop)
    if python3 "$FA/m3_profile.py" dump "$SCN" --playground "$PG" --handover "$HANDOVER" --database shop "$tmp/m3.json" > "$tmp/m3.out" 2>&1; then
        rc=0
        out=$(python3 "$FA/m3_profile.py" compare "$R_M3" "$tmp/m3.json" 2>&1) || rc=$?
        verdicts "$out"
        [ "$rc" -eq 0 ] || [ "$rc" -eq 1 ] || [ "$rc" -eq 77 ] || fail "m3_profile.py compare: exit $rc"
    else
        cat "$tmp/m3.out"; fail "M3 dump"
    fi
    P=$(epoch "$F8_AT")
    around=$(promr 'pg_database_size_bytes{datname="shop"}[2m]' $(( P + 60 )) | tr '\n' ',')
    tailr=$(promr "pg_database_size_bytes{datname=\"shop\"}[$(( $(date +%s) - at ))s]" "$(date +%s)" | tr '\n' ',')
    verdict=$(python3 - "$around" "$tailr" "$P" "$(scn gauge f8)" <<'EOF'
import sys
def pts(text):
    return [tuple(map(float, p.split())) for p in text.split(",") if p.strip()]
around, tail, planted, value = pts(sys.argv[1]), pts(sys.argv[2]), float(sys.argv[3]), float(sys.argv[4])
before = [x for t, x in around if t < planted]
after = [x for t, x in around if t >= planted]
step = before[-1] - after[0] if before and after else None
tail_step = max((abs(b[1] - a[1]) for a, b in zip(tail, tail[1:])), default=0.0)
tol = max(0.01 * value, tail_step)
print(f"FIGURE  f8's step over the forged past at its planting: {step} bytes for its value {value:.0f} "
      f"(the tail's largest step {tail_step:.0f} over {len(tail)} samples)")
ok = step is not None and abs(step - value) <= tol
print(("PASS" if ok else "FAIL") + f"  f8: the shop's size steps down by f8's value at its planting "
      f"({step} for {value:.0f}, within {tol:.0f})")
EOF
)
    verdicts "$verdict"
    ;;
tarnbeck-outdoor-campaign)
    now_t=$(date +%s)
    before=$(promq "rate(pg_stat_database_tup_inserted{datname=\"shop\"}[30m])" $(( at - 1 )) | awk '{print $NF}')
    after=$(promq "rate(pg_stat_database_tup_inserted{datname=\"shop\"}[$(( now_t - at - 30 ))s])" "$now_t" | awk '{print $NF}')
    figure "f1 at the seam: pg_stat_database_tup_inserted{datname=\"shop\"} $before rows/s over the past's last 30 min, $after rows/s over the tail; ratio $(awk -v a="$after" -v b="$before" 'BEGIN { if (b > 0) printf "%.2f", a / b; else print "-" }') (a step is a finding for v1.0 gating's day-long measurement, D578)"
    ;;
esac

# --- FIGURE lines: the tail against the 18 files (D590) -------------------------------
for n in $(python3 - "$LDIR/implementation.yaml" <<'EOF'
import sys, yaml
print(" ".join(k for k, v in yaml.safe_load(open(sys.argv[1]))["nodes"].items()
               if (v.get("brick") or {}).get("id") == "scheduler"))
EOF
); do
    f=$(scn files service-times.yaml "$n")
    [ -n "$f" ] || continue
    python3 "$FA/calibrate.py" "$SCN" keys --node "$n" --playground "$PG" --since "$AT" > "$tmp/keys-$n" 2>&1 || true
    python3 - "$tmp/keys-$n" "$f" "$n" <<'EOF'
import re, sys, yaml
got = {}
for line in open(sys.argv[1]):
    m = re.match(r"\s+(\S+): \{median: ([0-9.e+-]+), sigma: ([0-9.e+-]+)\}", line)
    if m:
        got[m.group(1)] = float(m.group(2))
keys = (yaml.safe_load(open(sys.argv[2])) or {}).get("keys") or {}
for k, v in sorted(keys.items()):
    want = float(v["median"])
    g = got.get(k)
    ratio = g / want if g is not None and want else None
    flag = "" if ratio is None or 0.8 <= ratio <= 1.25 else "; outside x0.8 to x1.25: a finding for a recalibration on 19"
    print(f"FIGURE  service time {sys.argv[3]} {k}: {'-' if g is None else f'{g:.4g}'} s in the tail "
          f"(calibrate.py keys' median), {want:.4g} s in service-times.yaml (PostgreSQL 18), ratio "
          f"{'-' if ratio is None else f'{ratio:.2f}'}{flag}")
EOF
done
for n in $DB_NODES; do
    f=$(scn files wal-rate.yaml "$n")
    w=$(sql "$n" postgres "SELECT wal_bytes || '|' || extract(epoch FROM now() - stats_reset) FROM pg_stat_wal") || w=
    python3 - "$w" "$f" "$n" <<'EOF'
import sys, yaml
w, f, n = sys.argv[1:4]
try:
    b, s = (float(x) for x in w.split("|"))
    rate = b / s * 3600
except ValueError:
    print(f"FIGURE  WAL rate {n}: not read ({w!r})"); sys.exit()
want = (yaml.safe_load(open(f)) or {}).get("bytes_per_hour") if f else None
ratio = rate / want if want else None
flag = "" if ratio is None or 0.8 <= ratio <= 1.25 else "; outside x0.8 to x1.25: a finding for a recalibration on 19"
print(f"FIGURE  WAL rate {n}: {rate:.0f} bytes/hour in the tail ({b:.0f} bytes in {s:.0f} s since the "
      f"restart's reset), {want if want else '-'} in wal-rate.yaml (PostgreSQL 18), ratio "
      f"{'-' if ratio is None else f'{ratio:.2f}'}{flag}")
EOF
done

# --- the retention; status and the record ------------------------------------------------
read_low=$(lowest)
d=$(( read_low - $(epoch "$VT0") ))
figure "Prometheus' lowest timestamp at the read: $(iso "$read_low") ($d s from the virtual T0)"
[ "$d" -ge -60 ] && [ "$d" -le 60 ] && pass "retention: the past kept to the virtual T0 at the read ($d s)" \
    || fail "retention: the lowest timestamp $d s from the virtual T0 at the read"
$GMCTL status "$SCN" --playground "$PG" 2>&1 | sed 's/^/....  status: /'
sed 's/^/....  record: /' "$LDIR/fake-aging.yaml"

# --- teardown --------------------------------------------------------------------------------
if $GMCTL teardown "$SCN" --playground "$PG" > "$tmp/td.out" 2>&1; then
    deployed=no
    pass "teardown"
else
    cat "$tmp/td.out"; fail "teardown"
fi
same "teardown: nothing labelled with $GAME left" "" "$(labelled)"
[ "$deployed" = yes ] || rm -rf "${LDIR:?}"

total=$(( $(date +%s) - started ))
figure "the wall time: $total s, the start to the teardown's end"
[ "$total" -lt 1800 ] && pass "under 30 minutes ($total s)" || fail "30 minutes or more ($total s)"
info "smoke-fake-aging.sh: $passes passed, $failures failed, $skips skipped"
[ "$failures" -eq 0 ]
