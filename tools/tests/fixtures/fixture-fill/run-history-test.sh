#!/bin/sh
# Short test of a fake game's history import (v0.6 build plan chunk 10b;
# master spec 9.4 steps 8 and 9, 9.5, 9.10; captures W3 items 1 to 7 and
# W3-x; spec D540, D541): Prometheus' forged past written, imported about
# ten minutes into the tail, joined to it, and kept by a restart from the
# hand-over snapshot. On one host, under 30 minutes with the deployment.
#
# On a copy of tools/tests/fixtures/fixture-fill, its aging shortened in the
# copy (aging.minimum 8h, the least a scenario takes, D150; f8 planted at
# handover-2h, its aging minimum 1h: the fill's span is not what this test
# is for), f8 carrying a history
# entry of each kind but none (queue, counter_per_call, gauge_sawtooth,
# gauge_before, daily_spike, remove):
#   gmctl fit -> render --aging fake --handover H --test-tail-floor T (T 13
#   or 14 min; the anchor H - T, 5.5 to 8 min after the start, the fill's
#   time: the run refuses to start outside that window, exit 3, nothing
#   deployed; start it between hh:38 and hh:41) -> deploy -> load-data ->
#   inject -> fill ->
#   clean-restart at the anchor -> start-load; then:
#   - the history timer dbagm-<game id>_history due at restart.at + 12 min;
#   - the TSDB folder's owner and mode (prometheus:prometheus 0750) before
#     the import;
#   - gmctl history by hand at restart.at + 10 min (refused a moment
#     before): exit 0, the record's history {at, result ok, seam ok}
#     written last, state.yaml's history_import.attempts with the figures
#     (FIGURE lines: tail, compose, promtool's peak, the load wait, the
#     series and samples, the blocks, the seam);
#   - the TSDB folder's owner and mode kept, the blocks prometheus's;
#     Prometheus' own series (lowest timestamp, blocks loaded, their bytes)
#     right after the import and a minute later (the retention);
#   - the composed kinds read back from Prometheus over the past: the
#     daily spike's value in its window, the removed series absent after
#     the planting and present before, the size gauge's value before the
#     planting, the sawtooth's rise;
#   - the timer's own run at + 12 min a no-op (one attempt recorded);
#   - the early check by hand: its history line `ok, seam ok`;
#   - at the earliest hand-over: the hand-over check's line, the snapshot,
#     status --set handed-over, gmctl history refused once handed over;
#   - restart from the snapshot: the record unchanged (its history kept),
#     no history timer for the new game, Prometheus' series after it (the
#     imported blocks kept), history --check-seam exit 0;
#   -> teardown, nothing labelled with either game id or the snapshot left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl), a systemd user manager (the timers), and the
# images of run-short-test.sh built. Host ports 2222 and 8080 free. Run it
# under the host lock and the sleep inhibitor (build plan, workflow deltas):
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#     sh tools/tests/fixtures/fixture-fill/run-history-test.sh
# `gmctl history` never takes that lock itself (capture W3 item 1).
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=fill-history
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/pgbouncer:0.1.2 127.0.0.1:5000/dbagm/scheduler:0.4.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/prometheus:0.2.2 127.0.0.1:5000/dbagm/postgres-exporter:0.2.1"
LABELS="com.docker.stack.namespace dbagm.game dbagm.snapshot"
KINDS="service network volume config secret"
SETUP_MIN=330                        # seconds from the start to the anchor, at least (the fill's)
SETUP_MAX=480                        # ... at most (else the run would pass 30 minutes)
TAIL_MIN=13                          # minutes: the import at 10, then the early check
TAIL_MAX=14
TSDB=/var/lib/prometheus
API=http://127.0.0.1:9090/prometheus/api/v1
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
figure() { printf 'FIGURE  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}
verdicts() {
    printf '%s\n' "$1"
    passes=$((passes + $(printf '%s\n' "$1" | grep -c '^PASS' || true)))
    failures=$((failures + $(printf '%s\n' "$1" | grep -c '^FAIL' || true)))
}
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
epoch() { date -u -d "$1" +%s; }

labelled() {   # labelled <game id>...
    for g in "$@"; do
        [ -n "$g" ] || continue
        for l in $LABELS; do
            for k in $KINDS; do
                docker "$k" ls --filter "label=$l=$g" --format "$k {{.Name}}"
            done
            docker ps -a --filter "label=$l=$g" --format 'container {{.Names}}'
        done
    done | sort -u
}

# --- the window: the anchor H - T, H a whole hour --------------------------
now=$(date +%s)
amin=$(( (now + SETUP_MIN + 59) / 60 * 60 ))
h=$(( (amin + TAIL_MIN * 60 + 3599) / 3600 * 3600 ))
tail_m=$(( (h - amin) / 60 ))
[ "$tail_m" -le "$TAIL_MAX" ] || tail_m=$TAIL_MAX
anchor=$(( h - tail_m * 60 ))
if [ $(( anchor - now )) -gt "$SETUP_MAX" ]; then
    echo "the anchor would come $(( (anchor - now) / 60 )) min after the start: start this test between" \
         "hh:$(( 60 - TAIL_MAX - SETUP_MAX / 60 )) and hh:$(( 60 - TAIL_MIN - SETUP_MIN / 60 - 1 )) (nothing done)" >&2
    exit 3
fi
TAIL=${tail_m}m
HANDOVER=$(date -u -d "@$h" +%Y-%m-%dT%H:%MZ)
ANCHOR=$(iso "$anchor")
VT0=$(iso $(( h - 8 * 3600 )))
F8_AT=$(iso $(( h - 2 * 3600 )))

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of run-short-test.sh)" >&2; exit 2; }
done
systemctl --user show --property=Version >/dev/null 2>&1 \
    || { echo "no systemd user manager: the timers need one" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-fill-history.XXXXXX")
SCN=$tmp/fixture-fill
LDIR=$SCN/local/$PG
GAME=
FIRST=
deployed=no

cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG" >/dev/null
        left=$(labelled "$FIRST" "$GAME")
        [ -z "$left" ] || echo "WARNING: objects of game $FIRST/$GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$HERE" "$SCN"
rm -f "$SCN/run-short-test.sh" "$SCN/run-history-test.sh"
# the copy's shorter aging: each line replaced exactly once, else stop
python3 - "$SCN/scenario.yaml" <<'EOF'
import sys
path = sys.argv[1]
text = open(path).read()
for old, new in (("  minimum: 16h ", "  minimum: 8h  "),
                 ("    plant_at: handover-6h ", "    plant_at: handover-2h "),
                 ("    aging_minimum: 4h\n", "    aging_minimum: 1h\n")):
    if text.count(old) != 1:
        sys.exit(f"scenario.yaml: {old.strip()!r} found {text.count(old)} times")
    text = text.replace(old, new)
open(path, "w").write(text)
EOF

game_id() { sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml"; }
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr db)" psql -XAtq -d "$1" -c "$2"; }
yval() { python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = (d or {}).get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" "$2"; }
stval() { yval "$LDIR/state.yaml" "$1"; }
recval() { yval "$LDIR/fake-aging.yaml" "$1"; }
# One PromQL instant query in the Prometheus node: its result's values,
# one line each, `<labels> <value>`, sorted.
promq() {   # promq <expr> [<epoch>]
    docker exec "$(ctr prometheus)" curl -fsS --max-time 60 -G "$API/query" \
        --data-urlencode "query=$1" ${2:+--data-urlencode "time=$2"} \
        | python3 -c 'import json, sys
d = json.load(sys.stdin)["data"]["result"]
print("\n".join(sorted(" ".join(f"{k}={v}" for k, v in sorted(r["metric"].items()) if k != "__name__")
                       + " " + r["value"][1] for r in d)))'
}
tsdb() {   # Prometheus' own view of its TSDB, one line
    printf 'lowest %s, blocks %s, bytes %s' \
        "$(iso "$(promq prometheus_tsdb_lowest_timestamp_seconds | awk '{printf "%d", $NF}')")" \
        "$(promq prometheus_tsdb_blocks_loaded | awk '{print $NF}')" \
        "$(promq prometheus_tsdb_storage_blocks_bytes | awk '{print $NF}')"
}
folder() { docker exec "$(ctr prometheus)" stat -c '%U:%G %a' "$TSDB"; }
wait_until() {   # wait_until <epoch>
    w=$(( $1 - $(date +%s) ))
    [ "$w" -le 0 ] || { info "waiting $w s, to $(iso "$1")"; sleep "$w"; }
}
info "hand-over $HANDOVER, tail $TAIL, virtual T0 $VT0, f8 at $F8_AT, anchor $ANCHOR ($(( anchor - now )) s ahead)"

# --- set-up to the tail ------------------------------------------------------
$GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 16G > "$tmp/fit.out" \
    || { cat "$tmp/fit.out"; fail "fit"; exit 1; }
grep -q 'snapshot: copies.*: fits' "$tmp/fit.out" && pass "fit, the hand-over snapshot fitting" \
    || { grep 'snapshot:' "$tmp/fit.out"; fail "fit: the snapshot does not fit"; exit 1; }
GAME=$(game_id)
FIRST=$GAME
info "game id $GAME"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" --aging fake \
    --test-tail-floor "$TAIL" >/dev/null || { fail "render --aging fake"; exit 1; }
same "the record: mode, virtual T0, anchor, tail, nothing refused" "fake $VT0 $ANCHOR $TAIL []" \
    "$(recval mode) $(recval virtual_t0) $(recval anchor) $(recval tail) $(recval refused)"
[ -z "$(labelled "$GAME")" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
deployed=yes
t=$(date +%s)
$GMCTL deploy "$SCN" --playground "$PG" >/dev/null || { fail "deploy"; exit 1; }
d_s=$(( $(date +%s) - t ))
$GMCTL load-data "$SCN" --playground "$PG" >/dev/null || { fail "load-data"; exit 1; }
$GMCTL inject "$SCN" --playground "$PG" >/dev/null || { fail "inject"; exit 1; }
pass "deploy, load-data, inject ($(( $(date +%s) - t )) s, the deploy $d_s s)"
t=$(date +%s)
$GMCTL fill "$SCN" --playground "$PG" > "$tmp/fill.out" 2> "$tmp/fill.err" \
    || { tail -n 20 "$tmp/fill.err"; fail "fill: $(stval fill.reason)"; exit 1; }
fill_s=$(( $(date +%s) - t ))
same "the fill: ok, f8 planted at its virtual instant" "ok $F8_AT" \
    "$(stval fill.outcome) $(stval plantings.f8.planted_at)"
figure "the fill: $fill_s s ($(( (anchor - $(epoch "$VT0")) / 60 )) virtual minutes)"
figure "the shop's size after the fill: $(dbsql postgres "SELECT pg_database_size('shop')") bytes (f8's gauge_before: 202500000)"
wait_until $(( anchor + 1 ))
t=$(date +%s)
$GMCTL clean-restart "$SCN" --playground "$PG" > "$tmp/restart.out" 2>&1 \
    || { tail -n 20 "$tmp/restart.out"; fail "clean-restart: $(stval clean_restart.reason)"; exit 1; }
figure "clean-restart: $(( $(date +%s) - t )) s"
$GMCTL start-load "$SCN" --playground "$PG" > "$tmp/start.out" 2>&1 \
    || { cat "$tmp/start.out"; fail "start-load"; exit 1; }
AT=$(recval restart.at)
at=$(epoch "$AT")
pass "clean-restart and start-load, restart.at $AT ($(( at - anchor )) s after the anchor)"
info "the earliest hand-over recorded: $(stval earliest_handover.at)"

# --- the timer and the folder before the import --------------------------------
same "the history timer: dbagm-${GAME}_history, due restart.at + 12 min" \
    "dbagm-${GAME}_history $(iso $(( at + 720 )))" \
    "$(stval history_import.timer.unit) $(stval history_import.timer.due)"
systemctl --user list-timers --all --no-legend 2>/dev/null | grep -q "dbagm-${GAME}_history.timer" \
    && pass "the history timer listed by the user manager" || fail "the history timer not listed"
same "the TSDB folder before the import (spec D540)" "prometheus:prometheus 750" "$(folder)"

# --- the import, by hand at restart.at + 10 min ----------------------------------
wait_until $(( at + 590 ))
if $GMCTL history "$SCN" --playground "$PG" > "$tmp/h0.out" 2>&1; then
    fail "history before restart.at + 10 min not refused"
else
    grep -q "first 10 minutes" "$tmp/h0.out" && pass "history refused before restart.at + 10 min" \
        || { cat "$tmp/h0.out"; fail "history's refusal before + 10 min"; }
fi
before_import=$(tsdb)
info "Prometheus before the import: $before_import"
wait_until $(( at + 601 ))
t=$(date +%s)
if $GMCTL history "$SCN" --playground "$PG" > "$tmp/h.out" 2>&1; then
    pass "gmctl history exits 0 ($(( $(date +%s) - t )) s)"
else
    fail "gmctl history (exit $?)"
fi
h_s=$(( $(date +%s) - t ))
sed 's/^/....  history: /' "$tmp/h.out"
same "the record's history: ok, seam ok, written last" "ok ok history" "$(python3 -c 'import sys, yaml
r = yaml.safe_load(open(sys.argv[1]))
h = r.get("history") or {}
print(h.get("result"), h.get("seam"), list(r)[-1])' "$LDIR/fake-aging.yaml")"
python3 - "$LDIR/state.yaml" "$h_s" <<'EOF'
import json, sys, yaml
a = yaml.safe_load(open(sys.argv[1]))["history_import"]["attempts"][-1]
f = a.get("figures") or {}
peak = f.get("promtool_memory_peak_bytes")
print(f"FIGURE  history: {sys.argv[2]} s; tail {f.get('tail_series')} series read in "
      f"{f.get('tail_read_s')} s; composed {f.get('series')} series, {f.get('samples')} samples, "
      f"{f.get('openmetrics_bytes')} bytes in {f.get('compose_s')} s; promtool {f.get('import_s')} s, "
      f"peak {peak if peak is None else round(peak / 2**20, 1)} MiB; loaded after "
      f"{f.get('loaded_after_s')} s; seam {f.get('seam_s')} s")
print(f"FIGURE  history: blocks {json.dumps(f.get('blocks'))}; tsdb {json.dumps(f.get('tsdb'))}")
print(f"FIGURE  history: report {json.dumps(f.get('report'))}")
print(f"....  attempt: outcome {a.get('outcome')}, reason {a.get('reason')}, seam {a.get('seam')}")
EOF
[ ! -d "$LDIR/history" ] && pass "the working files removed after the success" \
    || fail "local/$PG/history/ left after the import"
same "the TSDB folder kept by the import (spec D540)" "prometheus:prometheus 750" "$(folder)"
owners=$(docker exec "$(ctr prometheus)" sh -c "stat -c '%U' $TSDB/*/meta.json | sort -u | tr '\n' ' '")
same "the blocks owned by prometheus" "prometheus " "$owners"
# Prometheus' own series lag the load by a scrape: read them once they show it
k=0
until [ "$(promq prometheus_tsdb_blocks_loaded | awk '{print $NF}')" != 0 ] || [ "$k" -ge 60 ]; do
    sleep 5; k=$((k + 5))
done
after_import=$(tsdb)
info "Prometheus right after the import ($k s for its self-scrape): $after_import"
lowest=$(promq prometheus_tsdb_lowest_timestamp_seconds | awk '{printf "%d", $NF}')
d=$(( lowest - $(epoch "$VT0") ))
if [ "$d" -ge 0 ] && [ "$d" -le 15 ]; then
    pass "the lowest timestamp the virtual T0 ($d s after it)"
else
    fail "the lowest timestamp not the virtual T0 ($after_import)"
fi

# --- the kinds read back from Prometheus ---------------------------------------------
P=$(epoch "$F8_AT")
SPIKE=$(( h - 40 * 60 + 300 ))                    # 13:20 + 5 min, scenario time
kinds=$(
  echo "spike $(promq 'pg_stat_activity_count{datname="shop",state="active"}' "$SPIKE" | awk '{print $NF}' | sort -u | tr '\n' ',')"
  echo "removed_after $(promq 'count(pg_locks_count{datname="shop",mode="sireadlock"})' $(( P + 1800 )) | awk '{print $NF}')"
  echo "removed_before $(promq 'count(pg_locks_count{datname="shop",mode="sireadlock"})' $(( P - 1800 )) | awk '{print $NF}')"
  echo "size_before $(promq 'pg_database_size_bytes{datname="shop"}' $(( P - 1800 )) | awk '{print $NF}')"
  echo "tup_rate_before $(promq 'rate(pg_stat_database_tup_returned{datname="shop"}[10m])' $(( P - 900 )) | awk '{print $NF}')"
  echo "tup_rate_after $(promq 'rate(pg_stat_database_tup_returned{datname="shop"}[10m])' $(( P + 900 )) | awk '{print $NF}')"
  echo "saw $(promq 'max(max_over_time(pg_stat_activity_max_tx_duration{datname="shop",state="active"}[10m]))' $(( P + 1200 )) | awk '{print $NF}')"
  echo "saw_before $(promq 'max(max_over_time(pg_stat_activity_max_tx_duration{datname="shop",state="active"}[10m]))' $(( P - 900 )) | awk '{print $NF}')"
)
printf '%s\n' "$kinds" | sed 's/^/....  read back: /'
verdict=$(python3 - "$kinds" <<'EOF'
import sys
v = {}
for line in sys.argv[1].splitlines():
    k, _, x = line.partition(" ")
    v[k] = x.strip()
def num(k):
    try:
        return float(v[k].rstrip(",").split(",")[0])
    except (ValueError, IndexError):
        return None
def check(name, ok):
    print(("PASS" if ok else "FAIL") + "  " + name)
check("daily_spike: 6 active sessions in its window", "6" in v["spike"].split(","))
check("remove: no sireadlock series after the planting", v["removed_after"] == "")
check("remove: the series before the planting", v["removed_before"] not in ("", "0"))
check("gauge_before: the database's size 202500000 before the planting", num("size_before") == 202500000)
a, b = num("tup_rate_after"), num("tup_rate_before")
check("counter_per_call: tup_returned's rate higher after the planting", a is not None and b is not None and a > b)
s, sb = num("saw"), num("saw_before")
check("gauge_sawtooth: the transactions' maximum risen after the planting",
      s is not None and (sb is None or s > sb))
EOF
)
verdicts "$verdict"

# --- a minute later: retention; the timer's run; the early check ---------------------
wait_until $(( at + 735 ))
later=$(tsdb)
info "Prometheus a minute later: $later"
same "the imported past kept a minute later (retention 1d; its compactions)" \
    "$(printf '%s' "$after_import" | cut -d, -f1)" "$(printf '%s' "$later" | cut -d, -f1)"
figure "TSDB: before the import [$before_import]; after [$after_import]; a minute later [$later]"
same "the timer's run at + 12 min a no-op: one attempt recorded" "1" "$(python3 -c 'import sys, yaml
print(len(yaml.safe_load(open(sys.argv[1]))["history_import"]["attempts"]))' "$LDIR/state.yaml")"
info "the timer's unit: $(systemctl --user show -p Result -p ExecMainStatus "dbagm-${GAME}_history.service" 2>/dev/null | tr '\n' ' ')"
$GMCTL check "$SCN" --playground "$PG" --early-check > "$tmp/early.out" 2>&1 \
    && info "early check passed" || info "early check: exit $? ($(grep -i fail "$tmp/early.out" | head -n 3 | tr '\n' ' '))"
same "the early check's history line" "ok, seam ok" "$(stval early_check.result.history)"

# --- the hand-over ------------------------------------------------------------------
wait_until $(( at + tail_m * 60 + 1 ))          # the earliest hand-over: restart.at + the tail
$GMCTL check "$SCN" --playground "$PG" --handover-check > "$tmp/ho.out" 2>&1 \
    && pass "hand-over check" || { cat "$tmp/ho.out"; fail "hand-over check"; }
same "the hand-over check's history line" "ok, seam ok" "$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["handover_checks"][-1].get("history"))' "$LDIR/state.yaml")"
t=$(date +%s)
$GMCTL snapshot "$SCN" --playground "$PG" > "$tmp/snap.out" 2>&1 \
    || { cat "$tmp/snap.out"; fail "snapshot"; exit 1; }
same "snapshot taken" "taken" "$(stval snapshot.status)"
figure "snapshot: $(( $(date +%s) - t )) s"
$GMCTL status "$SCN" --playground "$PG" --set handed-over >/dev/null && pass "status --set handed-over" \
    || { fail "handed-over"; exit 1; }
$GMCTL status "$SCN" --playground "$PG" > "$tmp/status.out" 2>&1 || true
grep 'history import' "$tmp/status.out" | sed 's/^/....  status: /'
if $GMCTL history "$SCN" --playground "$PG" > "$tmp/h2.out" 2>&1; then
    fail "history after the hand-over not refused"
else
    grep -q "never while the players read Prometheus" "$tmp/h2.out" \
        && pass "history refused once handed over" || { cat "$tmp/h2.out"; fail "history's refusal once handed over"; }
fi
cp "$LDIR/fake-aging.yaml" "$tmp/record.before"

# --- the restart from the snapshot -------------------------------------------------
t=$(date +%s)
$GMCTL restart "$SCN" --playground "$PG" \
    --confirmation "Yes, restart from the hand-over snapshot (history fixture, test harness)" \
    > "$tmp/rs.out" 2>&1 || { tail -n 30 "$tmp/rs.out"; GAME=$(game_id); fail "restart"; exit 1; }
GAME=$(game_id)
figure "restart from the snapshot: $(( $(date +%s) - t )) s"
[ "$GAME" != "$FIRST" ] && pass "restarted from the snapshot, a new game id: $GAME" || fail "the game id did not change"
cmp -s "$tmp/record.before" "$LDIR/fake-aging.yaml" && pass "the restart record unchanged, its history kept" \
    || fail "the restart record changed by the restart"
same "no history timer for the new game" "" "$(stval history_import.timer)"
systemctl --user list-timers --all --no-legend 2>/dev/null | grep -q "dbagm-${GAME}_history" \
    && fail "a history timer for $GAME" || pass "no history unit listed for $GAME"
k=0
until promq up >/dev/null 2>&1; do
    k=$((k + 5)); [ "$k" -lt 180 ] || break; sleep 5
done
sleep 20
restarted=$(tsdb)
info "Prometheus after the restart: $restarted"
same "the imported past kept by the restart (the blocks with Prometheus' volume)" \
    "$(printf '%s' "$after_import" | cut -d, -f1)" "$(printf '%s' "$restarted" | cut -d, -f1)"
figure "TSDB after the restart from the snapshot: [$restarted]"
if $GMCTL history "$SCN" --playground "$PG" --check-seam > "$tmp/cs.out" 2>&1; then
    pass "history --check-seam after the restart: ok"
else
    fail "history --check-seam after the restart (exit $?)"
fi
sed 's/^/....  check-seam: /' "$tmp/cs.out"

# --- teardown -------------------------------------------------------------
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "teardown: nothing labelled with $FIRST or $GAME left" "" "$(labelled "$FIRST" "$GAME")"

total=$(( $(date +%s) - started ))
figure "the history test: $total s with the deployment"
[ "$total" -lt 1800 ] && pass "under 30 minutes ($total s)" || fail "over 30 minutes ($total s)"
info "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
