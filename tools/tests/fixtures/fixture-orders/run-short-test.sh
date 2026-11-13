#!/bin/sh
# Short test of the orders fixture (v0.5 build plan, chunk 18a; spec D403,
# D435; master spec 12.2 purposes 1 and 6; capture W4 items 0 and 3):
# vet-core's record and vet-lab's laboratory loaded by gmctl load-data, then
# the purposes' DDL at step (2b): vet-lab-centre-orders' in clinic (the ops
# schema, vet_interfaces, its tables, its watermark) and
# vet-lab-critical-calls' in lab (pg_cron, lab_watch, the watch every ten
# minutes); the practice software, pms, the lab's information system, lis
# (intensity 4), both APIs and the integration engine, interfaces, running
# purpose 1's two script jobs. On one host, under 30 minutes.
#
# On a copy of tools/tests/fixtures/fixture-orders (bastion 0.5.0, records
# and lab: postgres 0.5.0, clinic-api and lab-api: api 0.1.0, pms, lis and
# interfaces: scheduler 0.3.0):
#   gmctl compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over 18:00
#   local, 8 to 9 hours ahead, so T0 falls about 10:00, before the 11:00
#   round; a weekday when the host's day is one) -> deploy -> load-data:
#   - the stack file: lab_centre on interfaces with vet_interfaces' password;
#   - load-data: the ops tables in clinic and lab, the purposes' roles with
#     SCRAM passwords, the watermark, the watch scheduled in lab as lab_watch;
#   -> inject -> start-load (T0), then, time placed, never waited for:
#   - a critical result measured 61 minutes ago whose call was not read back
#     (as lis records a call): the watch's trigger;
#   - an emergency consultation closed now with two urgent analysis requests
#     (as pms closes one): posted within two minutes (LO1); its samples'
#     collection placed 20 minutes back, so lis receives, measures and
#     releases them (the rest released by the test itself, as lis would, if
#     lis has not after five minutes); each release resulted within ten (LO3);
#   - the purposes' checks, unfaulted: LO1 to LO4 on interfaces since T0, CC1
#     and CC2 on lab since T0 less 90 minutes (the placed result); the
#     watch's one incident for the unread result, still one after its next
#     run; no error in interfaces' or lis's log;
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-orders/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=orders-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-orders-short.XXXXXX")
SCN=$tmp/fixture-orders
LDIR=$SCN/local/$PG
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

cp -R "$HERE" "$SCN"
rm -f "$SCN"/run-*.sh

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -d "$2" -c "$3"; }
plog() { docker exec "$(ctr "${1:-lis}")" cat "$SCHEDLOG" 2>/dev/null || true; }
pstatus() { docker exec "$(ctr "${1:-lis}")" cat /run/scheduler/status 2>/dev/null || true; }


# A purpose's check, as the GM runs it: `check <node> <file> <since>`, root
# on the node, CHECK_SINCE given; prints "<exit> <first line>".
check() {
    set +e
    out=$(docker exec -i -u root -e CHECK_SINCE="$3" "$(ctr "$1")" sh -s < "$REPO/purposes/$2" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | head -n 1)"
}
since_epoch() { date -u -d "$(echo "$1" | sed 's/T/ /; s/Z$//')" +%s; }
iso_of() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/ as compose writes them (interfaces: purpose 1's material)"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the eight nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# Hand-over 8 to 9 hours ahead at 18:00 local: now between 09:00 and 10:00
# local, T0 about 10:00 once deployed and loaded.
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("interfaces", "lab", "lab-api"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: lab_centre and vet_interfaces' password on interfaces" \
    "interfaces http_lab_centre role_vet_interfaces_password" "$(line 1)"
same "stack: none on lab (load-data sets the roles' passwords, lab_watch's included)" "lab -" "$(line 2)"
same "stack: lab-api's three credentials and lab_api's password on lab-api" \
    "lab-api http_lab_centre http_lab_practices http_lab_xlab role_lab_api_password" "$(line 3)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the eight nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi

# --- load-data ---------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core, the lab, the purposes' DDL, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: ops in clinic, owned by ops, with the purpose's two tables" \
    "incidents:ops lab_orders_sent:ops request_results:ops runs:ops watermarks:ops" \
    "$(dbsql records clinic "SELECT string_agg(tablename || ':' || tableowner, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'ops'")"
same "load-data: ops in lab, the shared three only" "incidents:ops runs:ops watermarks:ops" \
    "$(dbsql lab lab "SELECT string_agg(tablename || ':' || tableowner, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'ops'")"
same "load-data: lab_watch and vet_interfaces log in with SCRAM passwords" "lab_watch:true vet_interfaces:true" \
    "$( { dbsql lab postgres "SELECT rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%') FROM pg_authid WHERE rolname = 'lab_watch'";
          dbsql records postgres "SELECT rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%') FROM pg_authid WHERE rolname = 'vet_interfaces'"; } | sort | tr '\n' ' ' | sed 's/ $//')"
same "load-data: the watermark set, no run yet" "1 0" \
    "$(dbsql records clinic "SELECT (SELECT count(*) FROM ops.watermarks WHERE purpose = 'vet-lab-centre-orders' AND at IS NOT NULL) || ' ' || (SELECT count(*) FROM ops.runs)")"
same "load-data: the watch scheduled in lab as lab_watch, every ten minutes" \
    "lab-critical-calls */10 * * * * lab lab_watch true" \
    "$(dbsql lab lab "SELECT jobname || ' ' || schedule || ' ' || database || ' ' || username || ' ' || active FROM cron.job")"
info "analysis requests at the load: $(dbsql records clinic "SELECT string_agg(state || ' ' || n, ', ') FROM (SELECT state, count(*) AS n FROM requests WHERE kind = 'analysis' GROUP BY state ORDER BY state) x")"

# --- T0 ------------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
info "local time at T0: $(dbsql lab lab "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'Dy HH24:MI') FROM lab_settings")"
i=0
while [ "$i" -lt 60 ]; do
    case $(pstatus interfaces) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(pstatus interfaces) in running\ *) pass "interfaces running: $(pstatus interfaces)" ;;
    *) fail "interfaces not running: [$(pstatus interfaces)]" ;; esac

# The watch's trigger, placed: a critical result measured 61 minutes ago, its
# call made and not read back (lis records the calls; lab.critical.call only
# calls a result with no call yet).
CRIT=$(dbsql lab lab "WITH t AS (SELECT t.id, a.analyte_id FROM lab_order_tests t
                         JOIN lab_test_analytes a ON a.test_id = t.test_id JOIN lab_analytes x ON x.id = a.analyte_id
                        WHERE t.status = 'released' AND x.kind = 'numeric' ORDER BY t.released_at DESC LIMIT 1),
  r AS (INSERT INTO lab_results (order_test_id, analyte_id, numeric_value, flag, measured_at)
        SELECT id, analyte_id, 99.9, 'critical-high', now() - interval '61 minutes' FROM t RETURNING id),
  c AS (INSERT INTO lab_critical_calls (result_id, called_at, called_by, called_person, read_back)
        SELECT id, now() - interval '50 minutes', 71, 'Dr Moreau', false FROM r)
  SELECT id FROM r")
CC_SINCE=$(iso_of $(( $(since_epoch "$T0") - 5400 )))
info "placed: critical result $CRIT, measured 61 minutes ago, its call not read back (CC judged since $CC_SINCE)"

# The urgent order, placed: an emergency consultation closed now with two
# urgent in-house requests, as pms closes one.
CONS=$(dbsql records clinic "WITH c AS (
    INSERT INTO consultations (animal_id, site_id, section_id, vet_id, kind, started_at, ended_at, state)
    SELECT animal_id, site_id, section_id, vet_id, 'emergency', now() - interval '25 minutes', now(), 'closed'
      FROM consultations WHERE kind = 'emergency' AND section_id = 3 AND animal_id IS NOT NULL
     ORDER BY id DESC LIMIT 1 RETURNING id, animal_id, vet_id),
  r AS (INSERT INTO requests (consultation_id, animal_id, kind, code, requested_by, priority, requested_at)
        SELECT c.id, c.animal_id, 'analysis', x.code, c.vet_id, 'urgent', now()
          FROM c CROSS JOIN (VALUES ('GLU'), ('BGAS')) AS x (code))
  SELECT id FROM c")
closed=$(date +%s)
info "placed: consultation $CONS closed with urgent GLU and BGAS"
sent=
while [ $(( $(date +%s) - closed )) -lt 180 ]; do
    sent=$(dbsql records clinic "SELECT count(*) || ' ' || coalesce(max(extract(epoch FROM r.sent_at - c.ended_at))::integer, -1)
                                  FROM requests r JOIN consultations c ON c.id = r.consultation_id
                                 WHERE r.consultation_id = $CONS AND r.state <> 'requested'")
    [ "${sent%% *}" = 2 ] && break
    sleep 5
done
secs=${sent#* }
if [ "${sent%% *}" = 2 ] && [ "$secs" -le 120 ]; then
    pass "post-lab-orders: the urgent requests sent $secs s after the close (LO1: 2 minutes)"
else
    fail "the urgent requests not sent within two minutes: [$sent]"
fi
ACC=$(dbsql records clinic "SELECT coalesce(accession, 0) FROM ops.lab_orders_sent WHERE client_ref = 'C-$CONS-urgent'")
same "the lab holds order C-$CONS-urgent (accession $ACC), its two tests carrying the requests" "2" \
    "$(dbsql lab lab "SELECT count(*) FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
                       WHERE o.id = 0$ACC AND o.client_ref = 'C-$CONS-urgent' AND o.priority = 'urgent'
                         AND t.request_id IS NOT NULL")"
# Time placed: the order's samples collected 20 minutes ago.
dbsql lab lab "UPDATE lab_samples SET collected_at = now() - interval '20 minutes' WHERE order_id = 0$ACC" >/dev/null
released=0
i=0
while [ "$i" -lt 300 ]; do
    released=$(dbsql lab lab "SELECT count(*) FROM lab_order_tests WHERE order_id = 0$ACC AND status = 'released'")
    [ "$released" = 2 ] && break
    sleep 15; i=$((i + 15))
done
if [ "$released" = 2 ]; then
    pass "lis received, measured and released the urgent order ($i s after its collection was placed)"
else
    info "lis has released $released of the order's two tests after $i s: the rest released by the test, as lis would"
    dbsql lab lab "UPDATE lab_order_tests SET status = 'released', technical_by = 71, technical_at = coalesce(technical_at, now()),
                    released_by = 79, released_at = now() WHERE order_id = 0$ACC AND status NOT IN ('released', 'cancelled')" >/dev/null
fi
REL=$(dbsql lab lab "SELECT extract(epoch FROM max(released_at))::integer FROM lab_order_tests WHERE order_id = 0$ACC")
res=
while [ $(( $(date +%s) - REL )) -lt 660 ]; do
    res=$(dbsql records clinic "SELECT count(*) || ' ' || coalesce(max(extract(epoch FROM resulted_at))::integer - $REL, -1)
                                 FROM requests WHERE consultation_id = $CONS AND state = 'resulted'")
    [ "${res%% *}" = 2 ] && break
    sleep 10
done
lag=${res#* }
if [ "${res%% *}" = 2 ] && [ "$lag" -le 600 ]; then
    pass "fetch-lab-results: both requests resulted $lag s after the release (LO3: 10 minutes)"
else
    fail "the requests not resulted within ten minutes of the release: [$res]"
fi
same "ops.request_results: the two copies, released" "2" \
    "$(dbsql records clinic "SELECT count(*) FROM ops.request_results r JOIN requests q ON q.id = r.request_id
                             WHERE q.consultation_id = $CONS AND r.status = 'released'")"
info "ops.runs: $(dbsql records clinic "SELECT string_agg(job || ' ' || n || ' runs, ' || w || ' rows', '; ') FROM (SELECT job, count(*) n, sum(rows_written) w FROM ops.runs GROUP BY job ORDER BY job) x"); centre orders posted since T0: $(dbsql lab lab "SELECT count(*) FROM lab_orders WHERE account_id = 1 AND ordered_at >= '$T0'")"

# --- the purposes' checks, unfaulted ------------------------------------------
# LO3 judges a release once ten minutes old.
while [ $(( $(date +%s) - REL )) -lt 615 ]; do sleep 10; done
for c in lo1-sent-in-time lo2-one-order-test lo3-resulted-on-release lo4-orders-answered; do
    r=$(check interfaces "vet-lab-centre-orders/checks/$c.sh" "$T0")
    same "$c: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
done
# CC2 needs the incident and a watch run after it.
i=0
while [ "$i" -lt 900 ]; do
    r=$(check lab "vet-lab-critical-calls/checks/cc2-one-incident.sh" "$CC_SINCE")
    [ "${r%% *}" != 3 ] && break
    sleep 30; i=$((i + 30))
done
for c in cc1-called-or-escalated cc2-one-incident; do
    r=$(check lab "vet-lab-critical-calls/checks/$c.sh" "$CC_SINCE")
    same "$c: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
done
same "the watch wrote one incident for the unread result, through $(dbsql lab lab "SELECT count(*) FROM cron.job_run_details WHERE status = 'succeeded'") runs" \
    "1" "$(dbsql lab lab "SELECT count(*) FROM ops.incidents WHERE purpose = 'vet-lab-critical-calls' AND kind = 'uncalled' AND ref = '$CRIT'")"
for n in interfaces lis; do
    errs=$(plog $n | grep ' error ' || true)
    same "$n ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
    [ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed "s/^/....  $n: /"
done
info "interfaces' calls: $(plog interfaces | grep -c 'http job=' || true), the slowest $(plog interfaces | sed -n 's/.*http job=.* ms=\([0-9]*\).*/\1/p' | sort -n | tail -n 1) ms"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
same "teardown: nothing labelled with $GAME left" "" "$left"

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
