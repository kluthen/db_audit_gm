#!/bin/sh
# Short test of the fill (v0.6 build plan chunk 8; master spec 9.4 step 5,
# 9.9 fixes 3, 7 and 9; capture W1 items 7, 8 and 9, W1-x): the shop's
# virtual night and morning, 22:00 to 11:00 the customer's time, run in
# minutes by gmctl fill on one host, f8 (a state fault) planted at its
# virtual instant, 08:00. Under 30 minutes with the deployment.
#
# On a copy of tools/tests/fixtures/fixture-fill (bastion 0.6.0, db:
# postgres 0.5.1 with pg_cron's job every minute, pooler: pgbouncer 0.1.2,
# producer and consumer: scheduler 0.4.0, prometheus 0.2.2, exporter:
# postgres-exporter 0.2.1):
#   gmctl fit (one host) -> render --handover H, H placed so the anchor
#   (H - 3h) is the first whole hour at least FILL_BUDGET minutes ahead
#   (never waited for) -> deploy -> load-data -> inject (f8 waits) ->
#   prometheus and exporter scaled to zero, as a fake game's deploy holds
#   them (9.4 step 2; chunk 9) -> the restart record written with 6.9's
#   keys, as render --aging fake will (W1 item 7) -> gmctl fill, timed;
#   then:
#   - state.yaml: fill.outcome ok, f8 planted by the fill at its virtual
#     instant (planted_at virtual, the attempt by fill with virtual_at),
#     the stage still injected; the index gone;
#   - each scheduler node's log: the fill's lines appended after its idle
#     lines, at virtual times from the virtual T0 to the anchor, in order,
#     `state stopping` at the virtual T0, `running t0=<virtual T0>`, no
#     `reload` line, minute summaries; the queue model's latencies (each
#     stream key's p50 near its service time's median);
#   - no fill statement in pg_stat_statements (none of shop_app's or
#     shop_reports'); no pg_cron run in the fill (runs before it);
#   - autovacuum's counts with the lowered naptime: each table's count in
#     the fill, against run R's per dirtied row (the reference archive's
#     table_stats.csv, extracted with extract.sh; skipped when absent);
#   - the exporter's sessions: pg_stat_database's sessions on postgres in
#     the fill, against the scrape rate in virtual time (3 120 in 13 h at
#     15 s);
#   - what the fill leaves: no gm_vclock schema, no role setting, the
#     naptime back, pg_cron's launches left off (fill.quiet), the
#     sequences installed, the metrics records (one line a virtual minute);
#   -> teardown, then nothing labelled with the game id is left.
# The figures (the fill's duration, the autovacuum counts) are printed as
# `FIGURE` lines.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.2 bricks/pgbouncer
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.2 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.1 bricks/postgres-exporter
# Host ports 2222 and 8080 free. Run it under the host lock and the sleep
# inhibitor (build plan, workflow deltas):
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#     sh tools/tests/fixtures/fixture-fill/run-short-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=fill-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/pgbouncer:0.1.2 127.0.0.1:5000/dbagm/scheduler:0.4.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/prometheus:0.2.2 127.0.0.1:5000/dbagm/postgres-exporter:0.2.1"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
FILL_BUDGET=${FILL_BUDGET:-25}       # minutes from now the anchor is at least
EXTRACT=$REPO/tools/fake_aging/reference/extract.sh
R_TABLES=m1-fa-real-20261115T0800/table_stats.csv
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

labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of $0)" >&2; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-fill-short.XXXXXX")
SCN=$tmp/fixture-fill
LDIR=$SCN/local/$PG
GAME=
deployed=no

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

cp -R "$HERE" "$SCN"
rm -f "$SCN/run-short-test.sh"

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr db)" psql -XAtq -d "$1" -c "$2"; }
slog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG"; }
stval() { python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = (d or {}).get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$LDIR/state.yaml" "$1"; }

# --- the timeline: the anchor the first whole hour FILL_BUDGET minutes ahead
now=$(date +%s)
anchor=$(( (now + FILL_BUDGET * 60 + 3599) / 3600 * 3600 ))
HANDOVER=$(date -u -d "@$(( anchor + 3 * 3600 ))" +%Y-%m-%dT%H:%MZ)
ANCHOR=$(date -u -d "@$anchor" +%Y-%m-%dT%H:%M:%SZ)
VT0=$(date -u -d "@$(( anchor + 3 * 3600 - 16 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)
F8_AT=$(date -u -d "@$(( anchor + 3 * 3600 - 6 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)
info "hand-over $HANDOVER, virtual T0 $VT0, f8 at $F8_AT, anchor $ANCHOR ($(( (anchor - now) / 60 )) min ahead)"

# --- set-up -----------------------------------------------------------------
info "gmctl fit (one host, armenelos: 2 CPU / 4G / 10G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 10G >/dev/null; then
    pass "fit"
else
    fail "fit"; exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

info "gmctl deploy"
deployed=yes
t=$(date +%s)
$GMCTL deploy "$SCN" --playground "$PG" >/dev/null || { fail "deploy"; exit 1; }
pass "deploy ($(( $(date +%s) - t )) s)"
t=$(date +%s)
$GMCTL load-data "$SCN" --playground "$PG" >/dev/null || { fail "load-data"; exit 1; }
pass "load-data ($(( $(date +%s) - t )) s)"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null || { fail "inject"; exit 1; }
pass "inject (f8 waits for its virtual instant)"

# the exporter's own sessions, for the record (their application_name)
app=$(docker exec "$(ctr db)" sh -c "grep -h 'user=monitoring' /var/log/postgresql/*.log 2>/dev/null \
      | grep -o 'app=[^,]*' | sort | uniq -c | head -n 3" | tr '\n' ' ')
info "the exporter's sessions before the fill, by application name: ${app:-none logged}"

info "prometheus and exporter scaled to zero (a fake game's deploy, 9.4 step 2)"
docker service scale -d "${GAME}_prometheus=0" "${GAME}_exporter=0" >/dev/null
i=0
while [ -n "$(ctr exporter)$(ctr prometheus)" ] && [ "$i" -lt 60 ]; do sleep 2; i=$((i + 2)); done

python3 - "$LDIR/fake-aging.yaml" "$VT0" "$ANCHOR" "$HANDOVER" <<'EOF'
import sys, yaml
path, vt0, anchor, handover = sys.argv[1:5]
rec = {"mode": "fake", "virtual_t0": vt0, "anchor": anchor, "tail": "3h",
       "handover_planned": handover.replace("Z", ":00Z"), "refused": []}
open(path, "w").write("# The restart record, written by the fill's short test as render "
                      "--aging fake will (W1 item 7).\n" + yaml.safe_dump(rec, sort_keys=False))
EOF

# --- before the fill ------------------------------------------------------
sleep 65    # pg_cron's job runs at least once before the fill
TABLES="customers products orders order_lines delivery_events daily_sales"
stats() { dbsql shop "SELECT relname || ' ' || autovacuum_count || ' ' || n_tup_ins || ' ' || n_tup_upd || ' ' || n_tup_del
                      FROM pg_stat_user_tables ORDER BY relname"; }
before=$(stats)
sessions_before=$(dbsql postgres "SELECT sessions FROM pg_stat_database WHERE datname = 'postgres'")
cron_before=$(dbsql shop "SELECT count(*) FROM cron.job_run_details")
fill_started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
info "pg_cron's runs before the fill: $cron_before"
[ "$cron_before" -gt 0 ] && pass "pg_cron's job ran before the fill ($cron_before runs)" \
    || fail "pg_cron's job never ran before the fill: the no-run check proves nothing"

# --- the fill ---------------------------------------------------------------
info "gmctl fill"
t=$(date +%s)
filled=yes
if $GMCTL fill "$SCN" --playground "$PG" > "$tmp/fill.out" 2> "$tmp/fill.err"; then
    pass "gmctl fill exits 0"
else
    fail "gmctl fill (exit $?)"
    filled=no
fi
fill_s=$(( $(date +%s) - t ))
fill_ended=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed 's/^/....  fill: /' "$tmp/fill.out"
if [ "$filled" = yes ]; then
    grep '^fill: virtual' "$tmp/fill.err" | tail -n 3 | sed 's/^/....  /' || true
else
    sed 's/^/....  fill (stderr): /' "$tmp/fill.err" | tail -n 30
    info "fill.reason: $(stval fill.reason)"
    exit 1
fi
figure "the fill's duration: $fill_s s (13 virtual hours, two scheduler nodes)"

# --- the records --------------------------------------------------------------
same "fill.outcome ok" "ok" "$(stval fill.outcome)"
same "the stage stays injected" "injected" "$(stval stage)"
same "f8 planted at its virtual instant" "$F8_AT" "$(stval plantings.f8.planted_at)"
same "f8's attempt by the fill at virtual $F8_AT" "fill $F8_AT ok" "$(python3 -c 'import sys, yaml
a = yaml.safe_load(open(sys.argv[1]))["plantings"]["f8"]["attempts"][-1]
print(a["by"], a["virtual_at"], a["outcome"])' "$LDIR/state.yaml")"
same "the index on order_lines.order_id gone" "0" \
    "$(dbsql shop "SELECT count(*) FROM pg_indexes WHERE tablename = 'order_lines' AND indexdef LIKE '%(order_id)%'")"

# --- the scheduler logs -------------------------------------------------------
for node in producer consumer; do
    slog "$node" > "$tmp/$node.log"
    verdict=$(python3 - "$tmp/$node.log" "$VT0" "$ANCHOR" "$node" "$SCN/nodes/$node/service-times.yaml" \
              "$SCN/nodes/$node/queries.yaml" <<'EOF'
import re, statistics, sys, yaml
path, vt0, anchor, node, st, qpath = sys.argv[1:7]
lines = [l.rstrip("\n") for l in open(path) if l.strip()]
first = next(i for i, l in enumerate(lines) if l.startswith(vt0 + " state state=stopping"))
fill = lines[first:]
ts = [l[:20] for l in fill]
out = []
def check(name, ok, detail=""):
    out.append(("PASS" if ok else "FAIL") + f"  {node}: {name}" + ("" if ok else f" ({detail})"))
check("the fill's lines after the idle ones", first > 0, f"the first fill line is line {first + 1}")
check("at virtual times from the virtual T0 to the anchor, in order",
      ts == sorted(ts) and ts[0] == vt0 and ts[-1] < anchor, f"{ts[0]} .. {ts[-1]}")
check(f"`running t0={vt0}` a second after", f"state state=running t0={vt0}" in fill[1], fill[1][:80])
check("no reload line", not any(" reload " in l for l in fill))
summaries = [l for l in fill if " summary " in l]
check("a summary each virtual minute", len(summaries) >= 13 * 60 - 3, str(len(summaries)))
medians = (yaml.safe_load(open(st)) or {}).get("keys") or {}
units = {"s": 1, "m": 60, "h": 3600}
holds = {}
for k, q in ((yaml.safe_load(open(qpath)) or {}).get("queries") or {}).items():
    h = str(((q.get("transaction") or {}) if isinstance(q, dict) else {}).get("hold") or "0s")
    holds[k] = int(h[:-1]) * units[h[-1]] * 1000
p50 = {}
for l in fill:
    m = re.search(r" key=(\S+) .*p50_ms=([0-9.]+)", l)
    if m and " key " in l:
        p50.setdefault(m.group(1), []).append(float(m.group(2)))
far = []
for k, v in sorted(p50.items()):
    if k in medians and len(v) >= 30:
        got, want = statistics.median(v), medians[k]["median"] * 1000 + holds.get(k, 0)
        out.append(f"....  {node}: {k} p50 median {got:.2f} ms, service time and hold {want:.2f} ms, "
                   f"{len(v)} minutes")
        if not want * 0.5 <= got <= want * 3 + 1:
            far.append(f"{k} {got:.2f} vs {want:.2f}")
check("the latencies the queue model's (each key's p50 near its service time)", p50 and not far,
      "; ".join(far) or "no key line")
print("\n".join(out))
EOF
)
    printf '%s\n' "$verdict"
    passes=$((passes + $(printf '%s\n' "$verdict" | grep -c '^PASS' || true)))
    failures=$((failures + $(printf '%s\n' "$verdict" | grep -c '^FAIL' || true)))
done

# --- statistics and the real-clock actors ------------------------------------
same "no fill statement in pg_stat_statements" "0" \
    "$(dbsql postgres "SELECT count(*) FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
                       WHERE r.rolname IN ('shop_app', 'shop_reports')")"
same "no pg_cron run in the fill" "0" \
    "$(dbsql shop "SELECT count(*) FROM cron.job_run_details
                   WHERE start_time >= '$fill_started' AND start_time <= '$fill_ended'")"
sessions=$(( $(dbsql postgres "SELECT sessions FROM pg_stat_database WHERE datname = 'postgres'") - sessions_before ))
figure "the exporter's sessions in the fill: $sessions (13 h at 15 s: 3120)"
if [ "$sessions" -ge 3000 ] && [ "$sessions" -le 3300 ]; then
    pass "the exporter's sessions present, at the scrape rate in virtual time ($sessions)"
else
    fail "the exporter's sessions: $sessions, not about 3120"
fi

# --- autovacuum with the lowered naptime --------------------------------------
after=$(stats)
r_tables=$(sh "$EXTRACT" "$R_TABLES" 2>"$tmp/extract.err") || r_tables=
verdict=$(python3 - "$before" "$after" "$r_tables" <<'EOF'
import csv, sys
def parse(text):
    out = {}
    for line in text.splitlines():
        name, av, ins, upd, dele = line.split()
        out[name] = tuple(int(x) for x in (av, ins, upd, dele))
    return out
before, after, rpath = parse(sys.argv[1]), parse(sys.argv[2]), sys.argv[3]
R = {}
if rpath:
    for row in csv.DictReader(open(rpath)):
        R[row["relname"]] = row
out = []
for t in sorted(after):
    a, b = after[t], before.get(t, (0, 0, 0, 0))
    av, ins, upd, dele = (x - y for x, y in zip(a, b))
    line = f"FIGURE  autovacuum {t}: {av} in the fill ({ins} inserted, {upd} updated, {dele} deleted)"
    if t in R:
        r_av, r_upd = int(R[t]["autovacuum_count"]), int(R[t]["n_tup_upd"])
        r_ins = int(R[t]["n_tup_ins"])
        if t in ("products", "customers") and r_upd:
            want = upd * r_av / r_upd
            line += f"; run R {r_av} for {r_upd} updated: {want:.1f} expected per updated row"
            ok = 0.5 * want - 1 <= av <= 2 * want + 1
            out.append(line)
            out.append(("PASS" if ok else "FAIL") + f"  autovacuum on {t} in range: {av} against "
                       f"{want:.1f} (run R's per updated row, x0.5 to x2, one run either way)")
            continue
        line += f"; run R {r_av} ({r_ins} inserted, {r_upd} updated in its day)"
    out.append(line)
if not R:
    out.append("SKIP  autovacuum against run R: the reference archive is absent")
print("\n".join(out))
EOF
)
printf '%s\n' "$verdict"
[ -s "$tmp/extract.err" ] && sed 's/^/....  /' "$tmp/extract.err" | grep SKIP || true
passes=$((passes + $(printf '%s\n' "$verdict" | grep -c '^PASS' || true)))
failures=$((failures + $(printf '%s\n' "$verdict" | grep -c '^FAIL' || true)))

# --- what the fill leaves ----------------------------------------------------------
same "no gm_vclock schema left" "0" "$(dbsql shop "SELECT count(*) FROM pg_namespace WHERE nspname = 'gm_vclock'")"
same "no role setting left" "0" "$(dbsql postgres "SELECT count(*) FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
                                                 WHERE r.rolname IN ('shop_app', 'shop_reports')")"
same "autovacuum_naptime back to the minute" "1min" "$(dbsql postgres "SHOW autovacuum_naptime")"
same "pg_cron's launches left off for clean-restart" "off" "$(dbsql postgres "SHOW cron.launch_active_jobs")"
same "fill.quiet: the sessions' quieting and the naptime restored, pg_cron left off" \
    "autovacuum_naptime (fix 7):restored pg_cron's job runs:left off statement statistics, statement log and pgaudit for the fill's sessions (fix 3):restored" \
    "$(python3 -c 'import sys, yaml
q = yaml.safe_load(open(sys.argv[1]))["fill"]["quiet"]
print(" ".join(sorted(i["what"] + ":" + ("left off" if i["left_off"] else ("restored" if i.get("restored_at") else "NOT restored")) for i in q)))' "$LDIR/state.yaml")"
# The shop's keys draw no sequence (no `seq` generator), so the fill reserves
# none and installs none; installing one is test_fill.py's.
own=$(docker exec "$(ctr producer)" stat -c %U /var/lib/scheduler/sequences.json 2>/dev/null || echo absent)
case $own in
    scheduler) pass "the producer's sequences installed for the tail, the scheduler's" ;;
    absent) info "no sequences file on the producer: the shop's keys draw no sequence" ;;
    *) fail "the producer's sequences file owned by $own, not scheduler" ;;
esac
for node in producer consumer; do
    n=$(wc -l < "$LDIR/fill/$node.metrics.jsonl" 2>/dev/null || echo 0)
    same "$node's metrics record: one line a virtual minute" "780" "$(echo $n)"
done
same "no fill working folder left" "no" "$(docker exec "$(ctr producer)" sh -c '[ -e /run/gm-fill ] && echo yes || echo no')"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "teardown: nothing labelled with $GAME left" "" "$(labelled)"

total=$(( $(date +%s) - started ))
figure "the short test: $total s with the deployment"
[ "$total" -lt 1800 ] && pass "under 30 minutes ($total s)" || fail "over 30 minutes ($total s)"
info "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
