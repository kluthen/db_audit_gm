#!/bin/sh
# Short test of the send-outs fixture (v0.5 build plan, chunk 18b; spec D403,
# D435; master spec 12.2 purposes 2 and 3; capture W4 items 0 and 3):
# vet-core's record and vet-lab's laboratory loaded by gmctl load-data, the
# lab's two partners' state into partners on partners-db, then the purposes'
# DDL at step (2b): vet-lab-practice-results' and vet-lab-send-outs' in lab
# (the ops schema, lab_dispatch's grants); lab-api, the integration engine,
# interfaces, running purpose 2's deliveries and purpose 3's send-outs and
# chase, and the partners' api and back end serving the practices
# (hostname practices) and the external lab (northfield-lab). On one host,
# under 30 minutes from the deployment.
#
# T0 at about 15:45-15:51 local, a few minutes before the 16:00 send-out.
# render shifts whole hours only, so the local minute is the host's: the
# script waits, before taking the host lock, until the host's clock reads
# minute 40 to 46, and takes the lock then (flock -n; busy: the next hour).
# That wait is before the run: nothing is deployed while it waits.
#
# On a copy of tools/tests/fixtures/fixture-send-outs (bastion 0.5.0, records,
# lab and partners-db: postgres 0.5.0, lab-api and partners-api: api 0.1.0,
# interfaces and partners-backend: scheduler 0.3.0):
#   gmctl compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over at the
#   whole hour 8 to 9 hours ahead, designed 00:00, so the local hour is 15; a
#   weekday when the host's day is one) -> deploy -> load-data:
#   - the stack file: practices_customer, xlab_customer and lab_dispatch's
#     password on interfaces;
#   - load-data: the shared ops tables in lab, lab_dispatch's grants on them
#     and on lab_settings (utc_offset_hours);
#   -> inject -> start-load (T0), then, time placed, never waited for:
#   - a practice order received now with two in-house tests: one released at
#     once (an interim delivery due), the other released and the order
#     completed once the interim is acknowledged (the final due), as lis
#     would; both acknowledged at the practices' stub, the right account;
#   - a practice's test routed out, its sample received at 15:00 local
#     today (as lis receives it): packed and posted by the 16:00 send-outs
#     run, accepted, the stub holding the catalogue's fields;
#   - one send-out in flight made due at the stub (its due time placed in
#     the past): the stub's next tick posts its answer to lab-api, which
#     records it; its test then validated and released by the test, as lis
#     would at its round;
#   - the purposes' checks, unfaulted: PR1, PR2, PR3, PR5 and SO1 on
#     interfaces, PR4, SO2, SO3 and SO4 on partners-db, since T0; no error
#     in interfaces' or partners-backend's log;
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# It takes the host lock itself (/tmp/dbagm-docker.lock, build plan workflow
# deltas); run it under the sleep inhibitor.
# Usage: sh tools/tests/fixtures/fixture-send-outs/run-short-test.sh   (from anywhere)
set -eu

LOCK=/tmp/dbagm-docker.lock
if [ -z "${SENDOUTS_LOCKED:-}" ]; then
    while :; do
        m=$(date +%M); m=${m#0}
        if [ "$m" -ge 40 ] && [ "$m" -le 46 ]; then
            rc=0
            SENDOUTS_LOCKED=1 flock -n -E 75 "$LOCK" sh "$0" "$@" || rc=$?
            [ "$rc" -eq 75 ] || exit "$rc"
            echo "....  the host lock is busy: waiting for the next hour's minute 40" >&2
            sleep 900
        fi
        sleep 20
    done
fi

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=sendouts-short
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-sendouts-short.XXXXXX")
SCN=$tmp/fixture-send-outs
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
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2" -c "$3"; }
plog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
pstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
lab() { dbsql lab lab "$1"; }
partners() { dbsql partners-db partners "$1"; }

# A purpose's check, as the GM runs it: `check <node> <file> <since>`, root
# on the node, CHECK_SINCE given; prints "<exit> <first line>".
check() {
    set +e
    out=$(docker exec -i -u root -e CHECK_SINCE="$3" "$(ctr "$1")" sh -s < "$REPO/purposes/$2" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | head -n 1)"
}
# wait_for <seconds> <sql on lab or partners: lab|partners> <query> <expected>: polls every 10 s.
wait_for() {
    w=0
    while [ "$w" -lt "$1" ]; do
        got=$($2 "$3" 2>/dev/null || true)
        [ "$got" = "$4" ] && return 0
        sleep 10; w=$((w + 10))
    done
    return 1
}

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/ as compose writes them (interfaces: purposes 2 and 3's material; the partners' stubs)"
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
# The hand-over at the whole hour 8 to 9 hours ahead, designed for 00:00:
# the local hour is 15 now and at T0, the minute the host's.
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("interfaces", "lab", "partners-api"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: practices_customer, xlab_customer and lab_dispatch's password on interfaces" \
    "interfaces http_practices_customer http_xlab_customer role_lab_dispatch_password" "$(line 1)"
same "stack: none on lab (load-data sets the roles' passwords)" "lab -" "$(line 2)"
info "stack: $(line 3)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
deploy_started=$t
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
    pass "load-data: the core, the lab, the partners' state, the purposes' DDL, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: ops in lab, owned by ops, the shared three only" "incidents:ops runs:ops watermarks:ops" \
    "$(lab "SELECT string_agg(tablename || ':' || tableowner, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'ops'")"
same "load-data: lab_dispatch's grants (ops, the lab's offset only of lab_settings)" "true true true false" \
    "$(lab "SELECT has_schema_privilege('lab_dispatch', 'ops', 'USAGE') || ' ' || has_table_privilege('lab_dispatch', 'ops.incidents', 'INSERT')
               || ' ' || has_column_privilege('lab_dispatch', 'lab_settings', 'utc_offset_hours', 'SELECT')
               || ' ' || has_column_privilege('lab_dispatch', 'lab_settings', 'timezone', 'SELECT')")"
info "at the load: $(lab "SELECT count(*) FILTER (WHERE status IN ('sent', 'accepted')) || ' send-outs in flight, '
                              || count(*) FILTER (WHERE status = 'packed') || ' packed' FROM lab_send_outs"); \
$(lab "SELECT count(*) || ' sent-out tests received and not packed' FROM lab_order_tests t JOIN lab_samples s ON s.id = t.sample_id
       WHERE t.routing = 'sent-out' AND t.status = 'sent-out' AND s.received_at IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM lab_send_outs so WHERE so.order_test_id = t.id)")"

# --- T0 ------------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
LOCAL=$(lab "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'Dy HH24:MI') FROM lab_settings")
info "local time at T0: $LOCAL"
case $LOCAL in *\ 15:4[0-9]|*\ 15:5[0-5]) ;; *) fail "T0 not between 15:40 and 15:55 local: $LOCAL" ;; esac
for n in interfaces partners-backend; do
    i=0
    while [ "$i" -lt 60 ]; do
        case $(pstatus $n) in running\ *) break ;; esac
        sleep 2; i=$((i + 2))
    done
    case $(pstatus $n) in running\ *) pass "$n running: $(pstatus $n)" ;; *) fail "$n not running: [$(pstatus $n)]" ;; esac
done

# Purpose 2, placed: a practice order received now, two in-house tests, the
# first released at once (as lis's urgent release or round would).
PO=$(lab "WITH o AS (
    INSERT INTO lab_orders (account_id, client_ref, priority, patient_ref, client_surname, species, sex, born_on,
                            ordered_at, received_at)
    VALUES (7, 'T18P-' || extract(epoch FROM now())::bigint, 'routine', 'P10001', 'Testa', 'dog', 'female',
            current_date - 2000, now() - interval '30 minutes', now()) RETURNING id),
  s AS (INSERT INTO lab_samples (order_id, label, sample_type, collected_at, received_at, condition)
        SELECT id, 'T18P' || id, 'whole blood', now() - interval '40 minutes', now(), 'fit' FROM o RETURNING id, order_id),
  t AS (INSERT INTO lab_order_tests (order_id, sample_id, test_id, routing, status)
        SELECT s.order_id, s.id, x.id, 'in-house', 'in-progress' FROM s, lab_tests x WHERE x.code IN ('CBC', 'GLU'))
  SELECT id FROM o")
lab "UPDATE lab_order_tests SET status = 'released', technical_by = 71, technical_at = now(), released_by = 79, released_at = now()
      WHERE id = (SELECT min(id) FROM lab_order_tests WHERE order_id = $PO)" >/dev/null
info "placed: practice order $PO (account 7) received with CBC and GLU, its first test released"

# Purpose 3, placed: a practice's test routed out, its sample received at
# 15:00 local today, waiting for the 16:00 send-out.
SO_TEST=$(lab "WITH r AS (
    SELECT (((date_trunc('day', (now() AT TIME ZONE 'UTC') + utc_offset_hours * interval '1 hour') + interval '15 hours')
             - utc_offset_hours * interval '1 hour') AT TIME ZONE 'UTC') AS at FROM lab_settings),
  o AS (INSERT INTO lab_orders (account_id, client_ref, priority, patient_ref, client_surname, species, sex, born_on,
                                ordered_at, received_at)
        SELECT 9, 'T18S-' || extract(epoch FROM now())::bigint, 'routine', 'P10002', 'Testb', 'horse', 'male',
               date '2016-05-01', r.at - interval '2 hours', r.at FROM r RETURNING id, received_at),
  s AS (INSERT INTO lab_samples (order_id, label, sample_type, collected_at, received_at, condition)
        SELECT id, 'T18S' || id, 'serum', received_at - interval '1 hour', received_at, 'fit' FROM o RETURNING id, order_id),
  t AS (INSERT INTO lab_order_tests (order_id, sample_id, test_id, routing, status)
        SELECT s.order_id, s.id, x.id, 'sent-out', 'sent-out'
          FROM s, (SELECT id FROM lab_tests WHERE external_code IS NOT NULL ORDER BY id LIMIT 1) AS x RETURNING id)
  SELECT id FROM t")
info "placed: sent-out test $SO_TEST of a practice's order, its sample received at 15:00 local"

# Purpose 3's answer leg, placed: one send-out in flight made due at the stub.
ANS=$(partners "UPDATE xlab.orders SET due_at = now() - interval '1 day'
                 WHERE send_key = (SELECT send_key FROM xlab.orders WHERE answered_at IS NULL ORDER BY received_at LIMIT 1)
                 RETURNING send_key")
info "placed: send-out $ANS made due at the external lab's stub (its next tick answers it)"

# The interim, then the final.
if wait_for 180 lab "SELECT count(*) FROM lab_callbacks WHERE order_id = $PO AND kind = 'interim' AND acknowledged_at IS NOT NULL" 1; then
    pass "deliver-practice-results: order $PO's interim acknowledged ($(lab "SELECT extract(epoch FROM min(acknowledged_at) - (SELECT min(released_at) FROM lab_order_tests WHERE order_id = $PO))::integer FROM lab_callbacks WHERE order_id = $PO AND kind = 'interim'") s after the release)"
else
    fail "order $PO's interim not acknowledged within three minutes: [$(lab "SELECT string_agg(kind || ' ' || attempt || ' ' || coalesce(http_status::text, '-'), ', ') FROM lab_callbacks WHERE order_id = $PO")]"
fi
lab "UPDATE lab_order_tests SET status = 'released', technical_by = 72, technical_at = now(), released_by = 79, released_at = now()
      WHERE order_id = $PO AND status <> 'released';
     UPDATE lab_orders SET completed_at = now() WHERE id = $PO" >/dev/null
if wait_for 180 lab "SELECT count(*) FROM lab_callbacks WHERE order_id = $PO AND kind = 'final' AND acknowledged_at IS NOT NULL" 1; then
    pass "deliver-practice-results: order $PO's final acknowledged ($(lab "SELECT extract(epoch FROM min(c.acknowledged_at) - o.completed_at)::integer FROM lab_callbacks c JOIN lab_orders o ON o.id = c.order_id WHERE c.order_id = $PO AND c.kind = 'final' GROUP BY o.completed_at") s after the completion)"
else
    fail "order $PO's final not acknowledged within three minutes"
fi
same "the practices' stub holds both deliveries, for account 7, each once" "interim:7:0 final:7:0" \
    "$(partners "SELECT string_agg(kind || ':' || account_id || ':' || repeats, ' ' ORDER BY first_at) FROM practices.deliveries WHERE accession = $PO")"

# The 16:00 send-out.
DUE16=$(lab "SELECT extract(epoch FROM (((date_trunc('day', (now() AT TIME ZONE 'UTC') + utc_offset_hours * interval '1 hour')
                                          + interval '16 hours') - utc_offset_hours * interval '1 hour') AT TIME ZONE 'UTC'))::integer
             FROM lab_settings")
while [ "$(date +%s)" -lt $((DUE16 + 60)) ]; do sleep 10; done
if wait_for 180 lab "SELECT status FROM lab_send_outs WHERE order_test_id = $SO_TEST" accepted; then
    pass "send-outs: test $SO_TEST packed at 16:00 and accepted ($(lab "SELECT external_accession || ', due ' || to_char(due_by AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI') || ' UTC, posted ' || extract(epoch FROM sent_at - packed_at)::integer || ' s after packing' FROM lab_send_outs WHERE order_test_id = $SO_TEST"))"
else
    fail "test $SO_TEST's send-out not accepted after 16:00: [$(lab "SELECT coalesce(string_agg(status, ','), 'none') FROM lab_send_outs WHERE order_test_id = $SO_TEST")]"
fi
KEY=$(lab "SELECT send_key FROM lab_send_outs WHERE order_test_id = $SO_TEST")
same "the stub took it once, with the catalogue's fields (label, code, species, sex, age)" \
    "1 T18S horse male" "$(partners "SELECT count(*) || ' ' || min(left(label, 4)) || ' ' || min(species) || ' ' || min(sex) FROM xlab.orders WHERE send_key = '$KEY'")"
same "a sent-out event for its sample" "1" \
    "$(lab "SELECT count(*) FROM lab_sample_events e JOIN lab_order_tests t ON t.sample_id = e.sample_id WHERE t.id = $SO_TEST AND e.kind = 'sent-out'")"
info "send-outs run: $(lab "SELECT string_agg(rows_read || ' read, ' || rows_written || ' written', '; ') FROM ops.runs WHERE job = 'send-outs'"); \
packed today: $(lab "SELECT count(*) FROM lab_send_outs WHERE packed_at > now() - interval '1 hour'")"

# The answer leg: recorded by lab-api, then released as lis would.
if wait_for 900 lab "SELECT status FROM lab_send_outs WHERE send_key = '$ANS'" resulted; then
    pass "the external lab's answer to $ANS recorded by lab-api ($(lab "SELECT count(*) FROM lab_results r JOIN lab_send_outs so ON so.order_test_id = r.order_test_id WHERE so.send_key = '$ANS'") results)"
else
    fail "the answer to $ANS not recorded: [$(lab "SELECT status FROM lab_send_outs WHERE send_key = '$ANS'")]"
fi
lab "UPDATE lab_order_tests SET status = 'released', technical_by = 73, technical_at = now(), released_by = 80, released_at = now()
      WHERE id = (SELECT order_test_id FROM lab_send_outs WHERE send_key = '$ANS') AND status NOT IN ('released', 'cancelled')" >/dev/null
info "released its test, as lis would at its round; chase runs: $(lab "SELECT count(*) || ' (' || coalesce(sum(rows_written), 0) || ' rows)' FROM ops.runs WHERE job = 'chase-send-outs'"); incidents: $(lab "SELECT coalesce(string_agg(kind || ' ' || n, ', '), 'none') FROM (SELECT kind, count(*) n FROM ops.incidents GROUP BY kind ORDER BY kind) x")"

# --- the purposes' checks, unfaulted ------------------------------------------
# PR1 judges a delivery made due once 15 minutes old.
REL=$(lab "SELECT extract(epoch FROM min(released_at))::integer FROM lab_order_tests WHERE order_id = $PO")
while [ "$(date +%s)" -lt $((REL + 915)) ]; do sleep 10; done
for c in pr1-delivered-in-time pr2-one-key pr3-released-only pr5-orders-delivered; do
    r=$(check interfaces "vet-lab-practice-results/checks/$c.sh" "$T0")
    same "$c: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
done
r=$(check partners-db "vet-lab-practice-results/checks/pr4-own-account.sh" "$T0")
same "pr4-own-account: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
r=$(check interfaces "vet-lab-send-outs/checks/so1-accepted-that-day.sh" "$T0")
same "so1-accepted-that-day: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
for c in so2-one-key so3-catalogue-fields so4-answers-released; do
    r=$(check partners-db "vet-lab-send-outs/checks/$c.sh" "$T0")
    same "$c: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
done
info "ops.runs: $(lab "SELECT string_agg(job || ' ' || n || ' runs, ' || w || ' rows', '; ') FROM (SELECT job, count(*) n, sum(rows_written) w FROM ops.runs GROUP BY job ORDER BY job) x"); \
deliveries since T0: $(lab "SELECT count(*) || ' attempts, ' || count(*) FILTER (WHERE acknowledged_at IS NOT NULL) || ' acknowledged' FROM lab_callbacks WHERE posted_at >= '$T0'")"
for n in interfaces partners-backend; do
    errs=$(plog $n | grep ' error ' || true)
    same "$n ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
    [ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed "s/^/....  $n: /"
done
info "interfaces' calls: $(plog interfaces | grep -c 'http job=' || true), the slowest $(plog interfaces | sed -n 's/.*http job=.* ms=\([0-9]*\).*/\1/p' | sort -n | tail -n 1) ms"
info "from the deployment to here: $(( $(date +%s) - deploy_started )) s"

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
