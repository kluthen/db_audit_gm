#!/bin/sh
# Short test of a fake game's fill and maintenance restart (v0.6 build plan
# chunks 8 and 9; master spec 9.3, 9.4 steps 1 to 7, 9.6, 9.9 fixes 2, 3,
# 4, 7, 8, 9 and 11; captures W1 items 7, 8, 9, W1-x, W2 items 7 to 13,
# W2-x): the shop's virtual night and morning, from the virtual T0 (22:00
# the customer's time) to the anchor, run in minutes by gmctl fill on one
# host, f8 (a state fault) planted at its virtual instant (08:00), then
# gmctl clean-restart and gmctl start-load. Under 30 minutes with the
# deployment.
#
# On a copy of tools/tests/fixtures/fixture-fill (bastion 0.6.0, db:
# postgres 0.5.1 with pg_cron's job every minute, pooler: pgbouncer 0.1.2,
# producer and consumer: scheduler 0.4.0, prometheus 0.2.2, exporter:
# postgres-exporter 0.2.1):
#   gmctl fit (one host) -> render --aging fake --handover H
#   --test-tail-floor <cap>, the anchor (H - cap) placed FILL_BUDGET minutes
#   ahead, about when the fill ends, H a whole hour (never waited for but
#   for the minutes between the fill's end and the anchor) -> deploy (the
#   monitoring at zero, the hold recorded) -> load-data and inject on the
#   virtual T0's clock (f8 waits) -> gmctl fill, timed -> clean-restart at
#   the anchor (refused before it) -> start-load; then:
#   - the restart record: render's keys, nothing refused; after
#     clean-restart `restart` (at, story_line, explains), no `history`;
#   - the deploy: prometheus and exporter at zero, the hold recorded, no
#     pg_cron run from it to the fill;
#   - after load-data and inject: no gm_vclock left (each drop clean), no
#     value after the virtual T0 in any timestamptz, timestamp or date
#     column of any database (inject.after_virtual_t0_sql); after the fill
#     none after the anchor and the fill's rows after the virtual T0;
#   - state.yaml: fill.outcome ok, f8 planted by the fill at its virtual
#     instant (planted_at virtual, the attempt by fill with virtual_at),
#     the stage still injected; the index gone;
#   - each scheduler node's log: the fill's lines appended after its idle
#     lines, at virtual times from the virtual T0 to the anchor, in order,
#     `state stopping` at the virtual T0, `running t0=<virtual T0>`, no
#     `reload` line, minute summaries; the queue model's latencies (each
#     stream key's p50 near its service time's median); kept by the
#     restart; no `reload status=ok` line after start-load;
#   - no fill statement in pg_stat_statements; no pg_cron run in the fill;
#   - autovacuum's counts with the lowered naptime: each table's count in
#     the fill, against run R's per dirtied row (the reference archive's
#     table_stats.csv, extracted with extract.sh; skipped when absent);
#   - the exporter's sessions: pg_stat_database's sessions on postgres in
#     the fill, against the scrape rate in virtual time (four a minute);
#   - what the fill leaves: no gm_vclock schema, no role setting, the
#     naptime back, pg_cron's launches left off (fill.quiet), the
#     sequences installed, the metrics records (one line a virtual minute);
#   - the restart: clean_restart.outcome ok; every container's StartedAt
#     and pg_postmaster_start_time() agreeing with restart.at (the
#     monitoring's included, RESTART_SPREAD seconds); one stats_reset
#     instant across the shared statistics and pg_stat_statements_info;
#     no PostgreSQL, pooler or cron log line before restart.at; pg_wal's
#     size and the padding's time recorded (clean_restart.wal);
#   -> teardown, then nothing labelled with the game id is left.
# The figures (the fill's and the restart's durations, pg_wal, the padding,
# the autovacuum counts) are printed as `FIGURE` lines.
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
FILL_BUDGET=${FILL_BUDGET:-13}       # minutes from now to the anchor: about the fill's end
RESTART_SPREAD=${RESTART_SPREAD:-30} # seconds a start time may follow restart.at
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
verdicts() {   # count a block of PASS/FAIL lines printed by a helper
    printf '%s\n' "$1"
    passes=$((passes + $(printf '%s\n' "$1" | grep -c '^PASS' || true)))
    failures=$((failures + $(printf '%s\n' "$1" | grep -c '^FAIL' || true)))
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
dbfile() { docker exec -i -u postgres "$(ctr db)" psql -XAtq -d "$1" -f -; }
slog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG"; }
yval() { python3 -c 'import sys, yaml
d = yaml.safe_load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = (d or {}).get(k) if isinstance(d, dict) else None
print("" if d is None else d)' "$1" "$2"; }
stval() { yval "$LDIR/state.yaml" "$1"; }
recval() { yval "$LDIR/fake-aging.yaml" "$1"; }
replicas() { docker service ls --filter "name=${GAME}_$1" --format '{{.Replicas}}'; }
databases() { dbsql postgres "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY 1"; }
# Fix 11's check (inject.after_virtual_t0_sql) in every database: its
# `<db>:<schema>.<table>.<column>|<latest>` findings, none when nothing in
# the data is after `$1`.
after() {
    python3 -c 'import sys; sys.path.insert(0, sys.argv[1])
from tools.gm import inject
sys.stdout.write(inject.after_virtual_t0_sql(sys.argv[2]))' "$REPO" "$1" > "$tmp/after.sql"
    for d in $(databases); do
        dbfile "$d" < "$tmp/after.sql" | sed "s/^/$d:/"
    done
}
vclocks() {   # databases still holding a gm_vclock schema
    for d in $(databases); do
        [ "$(dbsql "$d" "SELECT count(*) FROM pg_namespace WHERE nspname = 'gm_vclock'")" = 0 ] || echo "$d"
    done
}

# --- the timeline: the anchor FILL_BUDGET minutes ahead, H the next whole
# hour at least a minute after it, the tail capped to H minus the anchor
now=$(date +%s)
anchor=$(( (now + FILL_BUDGET * 60 + 59) / 60 * 60 ))
h=$(( (anchor + 60 + 3599) / 3600 * 3600 ))
cap=$(( (h - anchor) / 60 ))
if [ "$cap" -eq 60 ]; then TAIL=1h; else TAIL=${cap}m; fi
HANDOVER=$(date -u -d "@$h" +%Y-%m-%dT%H:%MZ)
ANCHOR=$(date -u -d "@$anchor" +%Y-%m-%dT%H:%M:%SZ)
VT0=$(date -u -d "@$(( h - 16 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)
F8_AT=$(date -u -d "@$(( h - 6 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)
VMIN=$(( (anchor - (h - 16 * 3600)) / 60 ))     # the fill's virtual minutes
info "hand-over $HANDOVER, tail $TAIL, virtual T0 $VT0, f8 at $F8_AT, anchor $ANCHOR ($(( (anchor - now) / 60 )) min ahead), $VMIN virtual minutes"

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
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" --aging fake \
    --test-tail-floor "$TAIL" > "$tmp/render.out" || { fail "render --aging fake"; exit 1; }
pass "render --aging fake"
same "the record: mode, virtual T0, anchor, tail, nothing refused" "fake $VT0 $ANCHOR $TAIL []" \
    "$(recval mode) $(recval virtual_t0) $(recval anchor) $(recval tail) $(recval refused)"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

info "gmctl deploy"
deployed=yes
t=$(date +%s)
$GMCTL deploy "$SCN" --playground "$PG" >/dev/null || { fail "deploy"; exit 1; }
deploy_ended=$(date -u +%Y-%m-%dT%H:%M:%SZ)
pass "deploy ($(( $(date +%s) - t )) s)"
same "the monitoring at zero after the deploy (prometheus, exporter)" "0/0 0/0" \
    "$(replicas prometheus) $(replicas exporter)"
hold_at=$(stval hold.at)
held=$(python3 -c 'import sys, yaml
h = yaml.safe_load(open(sys.argv[1])).get("hold") or {}
print("; ".join("%s: %s" % (i.get("node"), i.get("what")) for i in h.get("items") or []))' "$LDIR/state.yaml")
info "the hold at $hold_at: $held"
if [ -n "$hold_at" ] && [ -n "$held" ] && [ ! "$hold_at" \> "$deploy_ended" ]; then
    pass "the hold recorded at the deploy ($hold_at)"
else
    fail "the hold not recorded at the deploy (at [$hold_at], items [$held])"
fi

t=$(date +%s)
$GMCTL load-data "$SCN" --playground "$PG" >/dev/null || { fail "load-data"; exit 1; }
pass "load-data on the virtual T0's clock ($(( $(date +%s) - t )) s)"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null || { fail "inject"; exit 1; }
pass "inject (f8 waits for its virtual instant)"
same "no gm_vclock left by load-data and inject (each drop clean)" "" "$(vclocks)"
same "no value after the virtual T0 $VT0 in any database" "" "$(after "$VT0")"

# --- before the fill ------------------------------------------------------
sleep 65    # pg_cron's job, every minute, would have run by now
TABLES="customers products orders order_lines delivery_events daily_sales"
stats() { dbsql shop "SELECT relname || ' ' || autovacuum_count || ' ' || n_tup_ins || ' ' || n_tup_upd || ' ' || n_tup_del
                      FROM pg_stat_user_tables ORDER BY relname"; }
before=$(stats)
sessions_before=$(dbsql postgres "SELECT sessions FROM pg_stat_database WHERE datname = 'postgres'")
same "no pg_cron run from the deploy to the fill (the hold)" "0" \
    "$(dbsql shop "SELECT count(*) FROM cron.job_run_details")"

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
sed 's/^/....  fill: /' "$tmp/fill.out"
if [ "$filled" = yes ]; then
    grep '^fill: virtual' "$tmp/fill.err" | tail -n 3 | sed 's/^/....  /' || true
else
    sed 's/^/....  fill (stderr): /' "$tmp/fill.err" | tail -n 30
    info "fill.reason: $(stval fill.reason)"
    exit 1
fi
figure "the fill's duration: $fill_s s ($VMIN virtual minutes, two scheduler nodes)"

# --- the records --------------------------------------------------------------
same "fill.outcome ok" "ok" "$(stval fill.outcome)"
same "the stage stays injected" "injected" "$(stval stage)"
same "f8 planted at its virtual instant" "$F8_AT" "$(stval plantings.f8.planted_at)"
same "f8's attempt by the fill at virtual $F8_AT" "fill $F8_AT ok" "$(python3 -c 'import sys, yaml
a = yaml.safe_load(open(sys.argv[1]))["plantings"]["f8"]["attempts"][-1]
print(a["by"], a["virtual_at"], a["outcome"])' "$LDIR/state.yaml")"
same "the index on order_lines.order_id gone" "0" \
    "$(dbsql shop "SELECT count(*) FROM pg_indexes WHERE tablename = 'order_lines' AND indexdef LIKE '%(order_id)%'")"
same "no value after the anchor $ANCHOR in any database after the fill" "" "$(after "$ANCHOR")"
continued=$(after "$VT0")
info "after the virtual T0, the fill's: $(printf '%s' "$continued" | tr '\n' ' ')"
[ -n "$continued" ] && pass "the fill's rows continue from the virtual T0" \
    || fail "no row after the virtual T0 after the fill"

# --- the scheduler logs -------------------------------------------------------
for node in producer consumer; do
    slog "$node" > "$tmp/$node.log"
    verdict=$(python3 - "$tmp/$node.log" "$VT0" "$ANCHOR" "$node" "$SCN/nodes/$node/service-times.yaml" \
              "$SCN/nodes/$node/queries.yaml" "$VMIN" <<'EOF'
import re, statistics, sys, yaml
path, vt0, anchor, node, st, qpath, vmin = sys.argv[1:8]
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
check("a summary each virtual minute", len(summaries) >= int(vmin) - 3, str(len(summaries)))
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
    verdicts "$verdict"
done

# --- statistics and the real-clock actors ------------------------------------
same "no fill statement in pg_stat_statements" "0" \
    "$(dbsql postgres "SELECT count(*) FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
                       WHERE r.rolname IN ('shop_app', 'shop_reports')")"
same "no pg_cron run in the fill" "0" "$(dbsql shop "SELECT count(*) FROM cron.job_run_details")"
sessions=$(( $(dbsql postgres "SELECT sessions FROM pg_stat_database WHERE datname = 'postgres'") - sessions_before ))
want=$(( VMIN * 4 ))
figure "the exporter's sessions in the fill: $sessions ($VMIN virtual minutes at 15 s: $want)"
if [ "$sessions" -ge $(( want * 96 / 100 )) ] && [ "$sessions" -le $(( want * 106 / 100 )) ]; then
    pass "the exporter's sessions present, at the scrape rate in virtual time ($sessions)"
else
    fail "the exporter's sessions: $sessions, not about $want"
fi

# --- autovacuum with the lowered naptime --------------------------------------
after_stats=$(stats)
r_tables=$(sh "$EXTRACT" "$R_TABLES" 2>"$tmp/extract.err") || r_tables=
verdict=$(python3 - "$before" "$after_stats" "$r_tables" <<'EOF'
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
verdicts "$verdict"
[ -s "$tmp/extract.err" ] && sed 's/^/....  /' "$tmp/extract.err" | grep SKIP || true

# --- what the fill leaves ----------------------------------------------------------
same "no gm_vclock schema left by the fill" "" "$(vclocks)"
same "no role setting left" "0" "$(dbsql postgres "SELECT count(*) FROM pg_db_role_setting s JOIN pg_roles r ON r.oid = s.setrole
                                                 WHERE r.rolname IN ('shop_app', 'shop_reports')")"
same "autovacuum_naptime back to the minute" "1min" "$(dbsql postgres "SHOW autovacuum_naptime")"
same "pg_cron's launches left off for clean-restart" "off" "$(dbsql postgres "SHOW cron.launch_active_jobs")"
# pg_cron's launches are the hold's (deploy), not fill.quiet's (W2 item 10)
same "fill.quiet: the sessions' quieting and the naptime restored" \
    "autovacuum_naptime (fix 7):restored statement statistics, statement log and pgaudit for the fill's sessions (fix 3):restored" \
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
    same "$node's metrics record: one line a virtual minute" "$VMIN" "$(echo $n)"
done
same "no fill working folder left" "no" "$(docker exec "$(ctr producer)" sh -c '[ -e /run/gm-fill ] && echo yes || echo no')"
for node in producer consumer; do
    wc -l < "$tmp/$node.log" > "$tmp/$node.lines"
done

# --- the restart --------------------------------------------------------------
if [ "$(date +%s)" -lt $(( anchor - 5 )) ]; then
    if $GMCTL clean-restart "$SCN" --playground "$PG" > "$tmp/early.out" 2>&1; then
        fail "clean-restart before the anchor not refused"
    else
        same "clean-restart before the anchor refused, nothing recorded" "yes " \
            "$(grep -q 'has not come' "$tmp/early.out" && echo yes) $(stval clean_restart)"
    fi
    wait_s=$(( anchor - $(date +%s) + 1 ))
    [ "$wait_s" -le 0 ] || { info "waiting $wait_s s for the anchor $ANCHOR"; sleep "$wait_s"; }
else
    info "the fill ended $(( $(date +%s) - anchor )) s after the anchor: FILL_BUDGET too short to wait"
fi
info "gmctl clean-restart"
t=$(date +%s)
if $GMCTL clean-restart "$SCN" --playground "$PG" > "$tmp/restart.out" 2>&1; then
    pass "gmctl clean-restart exits 0 ($(( $(date +%s) - t )) s)"
else
    fail "gmctl clean-restart"
    sed 's/^/....  clean-restart: /' "$tmp/restart.out" | tail -n 30
    info "clean_restart.reason: $(stval clean_restart.reason)"
    exit 1
fi
figure "clean-restart's duration: $(( $(date +%s) - t )) s"
sed 's/^/....  clean-restart: /' "$tmp/restart.out"
same "clean_restart.outcome ok" "ok" "$(stval clean_restart.outcome)"
AT=$(recval restart.at)
info "restart.at $AT (the planned anchor $ANCHOR)"
python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
for node, w in (yaml.safe_load(open(sys.argv[1]))["clean_restart"].get("wal") or {}).items():
    print(f"FIGURE  {node}: WAL padded by {w['padded_bytes']} bytes in {w['seconds']} s; "
          f"pg_wal {w['pg_wal_bytes']} bytes after the checkpoints")
EOF
same "clean_restart.wal: padded bytes, pg_wal's size and the padding's time recorded" "db padded_bytes pg_wal_bytes seconds" \
    "$(python3 -c 'import sys, yaml
w = yaml.safe_load(open(sys.argv[1]))["clean_restart"]["wal"]
print(" ".join(n + " " + " ".join(sorted(k for k in v if v[k] is not None)) for n, v in sorted(w.items())))' "$LDIR/state.yaml")"
figure "pg_wal now: $(dbsql postgres "SELECT pg_size_pretty(sum(size)) || ' in ' || count(*) || ' segments' FROM pg_ls_waldir()")"
same "the restart record complete but history" \
    "anchor handover_planned mode refused restart tail virtual_t0 | at explains story_line" \
    "$(python3 -c 'import sys, yaml
r = yaml.safe_load(open(sys.argv[1]))
print(" ".join(sorted(k for k in r if r[k] is not None or k == "refused")), "|",
      " ".join(sorted(k for k, v in r["restart"].items() if v)))' "$LDIR/fake-aging.yaml")"
same "the monitoring up again (prometheus, exporter)" "1/1 1/1" "$(replicas prometheus) $(replicas exporter)"

# every container's and the postmaster's start against restart.at
for c in $(docker ps -q --filter "label=com.docker.stack.namespace=$GAME"); do
    docker inspect -f '{{index .Config.Labels "com.docker.swarm.service.name"}} {{.State.StartedAt}}' "$c"
done > "$tmp/starts"
echo "postmaster $(dbsql postgres "SELECT to_char(pg_postmaster_start_time() AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"')")" >> "$tmp/starts"
services=$(docker service ls --filter "label=com.docker.stack.namespace=$GAME" -q | wc -l)
verdict=$(python3 - "$tmp/starts" "$AT" "$RESTART_SPREAD" "$services" <<'EOF'
import datetime, re, sys
path, at, spread, services = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
def inst(s):
    m = re.match(r"(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\.\d+)?Z", s)
    frac = float("0" + (m.group(2) or ".0")[:7])
    return datetime.datetime.fromisoformat(m.group(1) + "+00:00").timestamp() + frac
a = inst(at)
rows = [l.split() for l in open(path) if l.strip()]
late = []
for name, when in rows:
    d = inst(when) - a
    print(f"....  {name}: started {when}, {d:+.1f} s from restart.at")
    if not -1 <= d <= spread:
        late.append(f"{name} {d:+.1f} s")
containers = len(rows) - 1
print(("PASS" if containers == services else "FAIL") +
      f"  a container for each of the {services} services after the restart ({containers})")
print(("PASS" if not late else "FAIL") +
      f"  every container's and the postmaster's start within {spread} s of restart.at {at}, the "
      "monitoring's included" + (f" ({'; '.join(late)})" if late else ""))
spreads = [inst(w) - a for _, w in rows]
print(f"FIGURE  the starts: {min(spreads):+.1f} s to {max(spreads):+.1f} s from restart.at")
EOF
)
verdicts "$verdict"

# one stats_reset instant across the shared and statement statistics: each
# view's value set by its own reset call, all within one second of each other
resets=$(dbsql postgres "SELECT to_char(min(r) AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') || ' '
    || round(extract(epoch FROM max(r) - min(r)) * 1000) || ' ms' FROM (
    SELECT stats_reset r FROM pg_stat_bgwriter UNION ALL SELECT stats_reset FROM pg_stat_checkpointer
    UNION ALL SELECT stats_reset FROM pg_stat_wal UNION ALL SELECT stats_reset FROM pg_stat_archiver
    UNION ALL SELECT stats_reset FROM pg_stat_io UNION ALL SELECT stats_reset FROM pg_stat_statements_info) s")
spread_ms=$(printf '%s' "$resets" | awk '{print $2}')
if [ "$spread_ms" -lt 1000 ]; then
    pass "one stats_reset instant (bgwriter, checkpointer, wal, archiver, io, statements: ${spread_ms} ms apart)"
else
    fail "stats_reset values ${spread_ms} ms apart, not one instant"
fi
figure "stats_reset $resets apart, against restart.at $AT"
same "the hold's items restored by the restart (restored_at), pg_cron's launches on" "yes on" \
    "$(python3 -c 'import sys, yaml
h = yaml.safe_load(open(sys.argv[1]))["hold"]["items"]
print("yes" if h and all(i.get("restored_at") for i in h) else "no")' "$LDIR/state.yaml") $(dbsql postgres "SHOW cron.launch_active_jobs")"

# no PostgreSQL, pooler or cron log line from before the restart
docker exec "$(ctr db)" sh -c 'for f in $(find /var/log/postgresql -type f); do echo "== $f $(stat -c %W "$f")"; cat "$f"; done' > "$tmp/pglogs"
docker exec "$(ctr pooler)" sh -c 'for f in $(find /var/log/pgbouncer -type f); do echo "== $f $(stat -c %W "$f")"; cat "$f"; done' > "$tmp/pblogs"
verdict=$(python3 - "$AT" "$tmp/pglogs" "$tmp/pblogs" <<'EOF'
import datetime, re, sys
at = datetime.datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00")).timestamp()
STAMP = re.compile(r"^(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)(?:\.\d+)? ?(UTC|GMT|[+-]\d\d(?::?\d\d)?)?\b")
def when(m):
    zone = m.group(2) or "UTC"
    off = 0
    if zone[0] in "+-":
        z = zone.replace(":", "")
        off = (int(z[1:3]) * 3600 + int(z[3:5] or 0) * 60) * (1 if z[0] == "+" else -1)
    t = datetime.datetime.fromisoformat(m.group(1) + "+00:00").timestamp()
    return t - off
for kind, path in (("PostgreSQL and cron", sys.argv[2]), ("pooler", sys.argv[3])):
    files, lines, before, born_before = 0, 0, [], []
    for l in open(path, errors="replace"):
        if l.startswith("== "):
            name, born = l[3:].split()
            files += 1
            if kind != "pooler" and born != "0" and int(born) < at - 1:
                born_before.append(name)
            continue
        m = STAMP.match(l)
        if m:
            lines += 1
            if when(m) < at - 1:
                before.append(l.strip()[:100])
    print(f"....  {kind} logs: {files} file(s), {lines} dated line(s) after the restart")
    print(("PASS" if not before and not born_before else "FAIL") +
          f"  no {kind} log line from before the restart" +
          ("" if not before and not born_before else f" ({len(before)} lines, first {before[:1]}; "
                                                      f"files born before: {born_before})"))
EOF
)
verdicts "$verdict"

# --- start-load: the tail ---------------------------------------------------------
info "gmctl start-load"
$GMCTL start-load "$SCN" --playground "$PG" > "$tmp/start.out" 2>&1 || {
    fail "start-load"; sed 's/^/....  start-load: /' "$tmp/start.out"; exit 1; }
pass "start-load"
same "load.t0 the virtual T0, load.anchor restart.at" "$VT0 $AT" "$(stval load.t0) $(stval load.anchor)"
sleep 5
for node in producer consumer; do
    slog "$node" > "$tmp/$node.after"
    kept=$(head -n "$(cat "$tmp/$node.lines")" "$tmp/$node.after" | cmp -s - "$tmp/$node.log" && echo yes || echo no)
    same "$node: the fill's log kept by the restart" "yes" "$kept"
    same "$node: no reload status=ok line" "0" "$(grep -c 'reload status=ok' "$tmp/$node.after" || true)"
done

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
