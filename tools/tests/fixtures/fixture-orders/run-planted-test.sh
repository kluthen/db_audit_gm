#!/bin/sh
# Short test of a fault planted on the orders fixture (v0.5 build plan chunk
# 22; master spec 17.3 s1 and s4, 18.1; capture W5 items 0 and 1 of
# specs/versions/v0.5/wave-log.md; spec D456): one fault a run, planted on a
# copy of tools/tests/fixtures/fixture-orders from its overlay,
# planted/<fault-id>/ (tools/tests/planted.py: the fault instance appended to
# scenario.yaml, its answer-key entry, its seed change in the scenario layer
# compose/interfaces/, s1's emergencies raised in compose/pms/), then `gmctl
# compose` on the copy; the fixture's committed files stay unfaulted. On one
# host, under 30 minutes with the deployment.
#
#   compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over 18:00 local,
#   8 to 9 hours ahead: T0 about 10:00 local, before the 11:00 round) ->
#   deploy -> load-data -> inject -> start-load (T0), then, time placed, never
#   waited for:
#
#   purpose-urgent-priority-dropped (s1, about 25 minutes):
#   - present: an emergency consultation closed now with two urgent requests
#     (as pms closes one): its order C-<consultation>-urgent reaches the lab
#     routine within ten minutes; gmctl check reads s1 present;
#   - the fix, as the GM applies the players' (the purpose's script into the
#     runner's repository as root, the scheduler reloaded through s6, as
#     gm-reload-scheduler does: the fixture's interfaces is no-access);
#   - fixed: the next urgent consultation's order urgent at the lab; its
#     samples' collection placed 20 minutes back, released by lis, or by the
#     test itself after five minutes as lis would (D456); its requests
#     resulted within ten minutes of the release (LO3); gmctl check reads s1
#     fixed since the fix, LO4 end to end too; the first order still routine
#     at the lab and unreleased, the backlog.
#
#   purpose-retry-without-key (s4, about 15 minutes):
#   - locks held on lab_orders, then lab_samples and lab_order_tests
#     (EXCLUSIVE, from sessions on lab), each until lab-api's insert into it
#     has waited four seconds (lab-api runs each statement under a five-second
#     statement_timeout), an urgent consultation closed meanwhile: the post
#     waits about twelve seconds, the runner times out at ten, lab-api commits
#     the order once the locks are gone;
#   - present: the next run's retry takes a client_ref of its own, the
#     consultation two orders at the lab, the same requests on both (LO2);
#     gmctl check reads s4 present;
#   - the fix as above; the same delay again: the retry answered with the
#     first accession, one order; gmctl check reads s4 fixed since the fix,
#     LO2 too.
#
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-orders/run-planted-test.sh <fault-id>
#   <fault-id>: purpose-urgent-priority-dropped | purpose-retry-without-key
set -eu

FAULT=${1:-}
case $FAULT in
    purpose-urgent-priority-dropped) INST=s1 ;;
    purpose-retry-without-key) INST=s4 ;;
    *) echo "usage: sh $0 purpose-urgent-priority-dropped|purpose-retry-without-key" >&2; exit 2 ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=orders-planted
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.4.0"
FIXED_SCRIPT=$REPO/purposes/vet-lab-centre-orders/material/runner/scripts/lab_orders.py
LIVE_SCRIPT=/srv/scheduler/repository/scripts/lab_orders.py
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-orders-planted.XXXXXX")
SCN=$tmp/fixture-orders
LDIR=$SCN/local/$PG
GAME=
deployed=no
lockpids=

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

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -d "$2" -c "$3"; }
plog() { docker exec "$(ctr "${1:-interfaces}")" cat "$SCHEDLOG" 2>/dev/null || true; }
pstatus() { docker exec "$(ctr "${1:-interfaces}")" cat /run/scheduler/status 2>/dev/null || true; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# The fault's sealed check, as the GM runs it: `fcheck [<since>]` prints
# "<exit> <its line>".
fcheck() {
    set +e
    if [ -n "${1:-}" ]; then
        out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" --since "$1" 2>&1)
    else
        out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" 2>&1)
    fi
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | grep "^$INST " | head -n 1)"
}
# A purpose's check: `check <node> <file> <since>`, root on the node.
check() {
    set +e
    out=$(docker exec -i -u root -e CHECK_SINCE="$3" "$(ctr "$1")" sh -s < "$REPO/purposes/$2" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | head -n 1)"
}

# --- the copy, planted -----------------------------------------------------
cp -R "$HERE" "$SCN"
rm -f "$SCN"/run-*.sh
python3 "$REPO/tools/tests/planted.py" "$SCN" "$HERE/planted/$FAULT"
$GMCTL compose "$SCN" >/dev/null
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "planted $INST ($FAULT) from planted/$FAULT/ on a copy, composed: nodes/ as compose writes them"
else
    fail "compose --check on the planted copy"
fi
same "the planted copy: f1 and $INST, difficulty $(sed -n 's/^  score: *//p' "$SCN/scenario.yaml")" "f1 $INST" \
    "$(python3 -c "import sys, yaml; print(' '.join(i['id'] for i in yaml.safe_load(open(sys.argv[1]))['fault_instances']))" "$SCN/scenario.yaml")"

# --- local implementation and deployment -------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the eight nodes fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy: the eight nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
same "render planted $INST: the runner's live script is the composed planted one" "yes" \
    "$(docker exec -u root "$(ctr interfaces)" cat "$LIVE_SCRIPT" | cmp -s - "$SCN/nodes/interfaces/scripts/lab_orders.py" && echo yes || echo no)"
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: the core, the lab, the purposes' DDL, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject ($INST a seed-file fault: nothing runs)" || fail "inject"
T0=$(now_iso)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
info "local time at T0: $(dbsql lab lab "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'Dy HH24:MI') FROM lab_settings")"
i=0
while [ "$i" -lt 60 ]; do
    case $(pstatus interfaces) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(pstatus interfaces) in running\ *) pass "interfaces running" ;;
    *) fail "interfaces not running: [$(pstatus interfaces)]" ;; esac

# --- helpers on the game -----------------------------------------------------
# An emergency consultation closed now with two urgent in-house requests, as
# pms closes one; prints its id.
place_urgent() {
    dbsql records clinic "WITH c AS (
        INSERT INTO consultations (animal_id, site_id, section_id, vet_id, kind, started_at, ended_at, state)
        SELECT animal_id, site_id, section_id, vet_id, 'emergency', now() - interval '25 minutes', now(), 'closed'
          FROM consultations WHERE kind = 'emergency' AND section_id = 3 AND animal_id IS NOT NULL
         ORDER BY id DESC LIMIT 1 RETURNING id, animal_id, vet_id),
      r AS (INSERT INTO requests (consultation_id, animal_id, kind, code, requested_by, priority, requested_at)
            SELECT c.id, c.animal_id, 'analysis', x.code, c.vet_id, 'urgent', now()
              FROM c CROSS JOIN (VALUES ('GLU'), ('BGAS')) AS x (code))
      SELECT id FROM c"
}
# Waits up to three minutes for consultation $1's two requests to be sent;
# prints "<sent> <seconds from the close>".
wait_sent() {
    w=$(date +%s)
    s=
    while [ $(( $(date +%s) - w )) -lt 180 ]; do
        s=$(dbsql records clinic "SELECT count(*) || ' ' || coalesce(max(extract(epoch FROM r.sent_at - c.ended_at))::integer, -1)
                                  FROM requests r JOIN consultations c ON c.id = r.consultation_id
                                 WHERE r.consultation_id = $1 AND r.state <> 'requested'")
        [ "${s%% *}" = 2 ] && break
        sleep 5
    done
    printf '%s\n' "$s"
}
# The GM's fix: the purpose's script into the runner's repository as root,
# the scheduler reloaded through s6 (gm-reload-scheduler's step 4; it refuses
# on a node with no fixable path). Prints the moment after the reload.
apply_fix() {
    c=$(ctr interfaces)
    gen() { docker exec -u root "$c" sed -n 's/^generation=//p' /run/scheduler/loaded; }
    before=$(gen)
    docker exec -i -u root "$c" sh -c "cat > $LIVE_SCRIPT" < "$FIXED_SCRIPT"
    docker exec -u root "$c" /command/s6-svc -h /run/service/scheduler
    i=0
    while [ "$i" -lt 60 ] && [ "$(gen)" = "$before" ]; do sleep 0.5; i=$((i + 1)); done
    [ "$(gen)" != "$before" ] || { echo "the scheduler did not reload" >&2; return 1; }
    now_iso
}
# The delay. lab-api's order endpoint runs each statement under a five-second
# statement_timeout (its 503 then rolls the order back), so one lock cannot
# hold a post past the runner's ten seconds: three sessions on lab each hold
# an EXCLUSIVE lock (lab-api's insert waits, its reads do not), on lab_orders,
# lab_samples and lab_order_tests, and each lets go once lab_api's insert into
# its table has waited four seconds: the order's three inserts wait about
# twelve seconds in all, past the runner's timeout, and the lab commits the
# order after the runner gave up. Each session ends after 150 s at most.
# In the background; their pids in $lockpids.
lock_session() {   # lock_session <table>
    docker exec -u postgres "$(ctr lab)" psql -XAtq -d lab -v ON_ERROR_STOP=1 -c "DO \$\$
      BEGIN
        LOCK TABLE $1 IN EXCLUSIVE MODE;
        FOR i IN 1..300 LOOP
          PERFORM pg_stat_clear_snapshot();
          EXIT WHEN EXISTS (SELECT 1 FROM pg_stat_activity
                             WHERE usename = 'lab_api' AND wait_event_type = 'Lock'
                               AND query LIKE 'INSERT INTO $1 %'
                               AND clock_timestamp() - query_start > interval '4 seconds');
          PERFORM pg_sleep(0.5);
        END LOOP;
      END \$\$" >/dev/null 2>&1 &
}
hold_locks() {
    lockpids=
    for table in lab_orders lab_samples lab_order_tests; do
        lock_session "$table"
        lockpids="$lockpids $!"
    done
    i=0
    while [ "$i" -lt 20 ]; do
        [ "$(dbsql lab lab "SELECT count(*) FROM pg_locks l JOIN pg_class c ON c.oid = l.relation
                            WHERE c.relname IN ('lab_orders', 'lab_samples', 'lab_order_tests')
                              AND l.mode = 'ExclusiveLock' AND l.granted")" = 3 ] && return 0
        sleep 0.5; i=$((i + 1))
    done
    echo "the locks on lab_orders, lab_samples and lab_order_tests were not taken" >&2
    return 1
}
# The delay: the locks held, an urgent consultation closed under them; prints
# "<consultation> <the timed-out reference>" once the runner's post has timed
# out and the locks are gone.
delayed_post() {
    hold_locks
    cons=$(place_urgent)
    w=$(date +%s)
    for pid in $lockpids; do         # the sessions end once the post has waited past the timeout
        wait "$pid" || true
    done
    secs=$(( $(date +%s) - w ))
    ref=$(dbsql records clinic "SELECT client_ref FROM ops.lab_orders_sent
                                 WHERE last_status = 'timeout' AND posted_at > '$1' ORDER BY posted_at LIMIT 1")
    info "the locks held $secs s more after consultation $cons closed; timed out: [${ref:-none}]" >&2
    printf '%s %s\n' "$cons" "$ref"
}

case $INST in
s1)
# --- s1 present ----------------------------------------------------------------
CONS1=$(place_urgent)
closed=$(date +%s)
info "placed: consultation $CONS1 closed with urgent GLU and BGAS"
s=$(wait_sent "$CONS1")
if [ "${s%% *}" = 2 ] && [ "${s#* }" -le 120 ]; then
    pass "post-lab-orders: the urgent requests sent ${s#* } s after the close"
else
    fail "the urgent requests not sent within two minutes: [$s]"
fi
ACC1=$(dbsql records clinic "SELECT coalesce(accession, 0) FROM ops.lab_orders_sent WHERE client_ref = 'C-$CONS1-urgent'")
same "present ($(( $(date +%s) - closed )) s after the close): order C-$CONS1-urgent (accession $ACC1) routine at the lab, its requests urgent" \
    "routine urgent,urgent" \
    "$(dbsql lab lab "SELECT priority FROM lab_orders WHERE id = 0$ACC1") $(dbsql records clinic "SELECT string_agg(priority, ',') FROM requests WHERE consultation_id = $CONS1")"
r=$(fcheck)
same "gmctl check $INST at the planting: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "1" "${r%% *}"
info "urgent orders posted since T0 by pms' own consultations: $(dbsql records clinic "SELECT count(*) FROM ops.lab_orders_sent WHERE client_ref LIKE '%-urgent' AND client_ref <> 'C-$CONS1-urgent' AND posted_at >= '$T0'")"

# --- the fix -----------------------------------------------------------------
FIXED_AT=$(apply_fix)
pass "fixed as the GM applies it: the purpose's script loaded at $FIXED_AT"

# --- s1 fixed ------------------------------------------------------------------
CONS2=$(place_urgent)
info "placed: consultation $CONS2 closed with urgent GLU and BGAS"
s=$(wait_sent "$CONS2")
if [ "${s%% *}" = 2 ] && [ "${s#* }" -le 120 ]; then
    pass "post-lab-orders after the fix: sent ${s#* } s after the close"
else
    fail "after the fix, the urgent requests not sent within two minutes: [$s]"
fi
ACC2=$(dbsql records clinic "SELECT coalesce(accession, 0) FROM ops.lab_orders_sent WHERE client_ref = 'C-$CONS2-urgent'")
same "fixed: order C-$CONS2-urgent (accession $ACC2) urgent at the lab" "urgent 2" \
    "$(dbsql lab lab "SELECT o.priority || ' ' || count(t.id) FROM lab_orders o JOIN lab_order_tests t ON t.order_id = o.id
                       WHERE o.id = 0$ACC2 AND t.request_id IS NOT NULL GROUP BY o.priority")"
dbsql lab lab "UPDATE lab_samples SET collected_at = now() - interval '20 minutes' WHERE order_id = 0$ACC2" >/dev/null
released=0
i=0
while [ "$i" -lt 300 ]; do
    released=$(dbsql lab lab "SELECT count(*) FROM lab_order_tests WHERE order_id = 0$ACC2 AND status = 'released'")
    [ "$released" = 2 ] && break
    sleep 15; i=$((i + 15))
done
if [ "$released" = 2 ]; then
    pass "lis received, measured and released the urgent order ($i s after its collection was placed)"
else
    info "lis has released $released of the order's two tests after $i s: the rest released by the test, as lis would (D456)"
    dbsql lab lab "UPDATE lab_order_tests SET status = 'released', technical_by = 71, technical_at = coalesce(technical_at, now()),
                    released_by = 79, released_at = now() WHERE order_id = 0$ACC2 AND status NOT IN ('released', 'cancelled')" >/dev/null
fi
REL=$(dbsql lab lab "SELECT extract(epoch FROM max(released_at))::integer FROM lab_order_tests WHERE order_id = 0$ACC2")
res=
while [ $(( $(date +%s) - REL )) -lt 660 ]; do
    res=$(dbsql records clinic "SELECT count(*) || ' ' || coalesce(max(extract(epoch FROM resulted_at))::integer - $REL, -1)
                                 FROM requests WHERE consultation_id = $CONS2 AND state = 'resulted'")
    [ "${res%% *}" = 2 ] && break
    sleep 10
done
if [ "${res%% *}" = 2 ] && [ "${res#* }" -le 600 ]; then
    pass "fixed: both urgent requests resulted ${res#* } s after the release (LO3: 10 minutes)"
else
    fail "the requests not resulted within ten minutes of the release: [$res]"
fi
r=$(fcheck "$FIXED_AT")
same "gmctl check $INST since the fix: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "0" "${r%% *}"
r=$(check interfaces vet-lab-centre-orders/checks/lo4-orders-answered.sh "$FIXED_AT")
same "LO4 end to end since the fix: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
same "the backlog: C-$CONS1-urgent still routine at the lab, unreleased, waiting for the round" "C-$CONS1-urgent" \
    "$( { dbsql records clinic "SELECT client_ref || ' ' || accession FROM ops.lab_orders_sent
                               WHERE client_ref LIKE '%-urgent' AND accession IS NOT NULL AND posted_at < '$FIXED_AT'" |
          while read -r ref acc; do
              [ "$(dbsql lab lab "SELECT count(*) FROM lab_orders o WHERE o.id = $acc AND o.priority = 'routine'
                                    AND EXISTS (SELECT 1 FROM lab_order_tests t WHERE t.order_id = o.id AND t.status <> 'released')")" = 1 ] \
                  && echo "$ref"
          done; } | grep -x "C-$CONS1-urgent" || true)"
;;

s4)
# --- s4 present ----------------------------------------------------------------
P0=$(now_iso)
set -- $(delayed_post "$P0")
CONS1=$1 REF1=${2:-}
[ -n "$REF1" ] && pass "the delay: post $REF1 timed out (the runner's ten seconds), lab-api's insert committed after the lock" \
    || fail "no post timed out under the lock"
CID1=$(echo "$REF1" | cut -d- -f2)
n=
i=0
while [ "$i" -lt 150 ]; do
    n=$(dbsql lab lab "SELECT count(*) || ' ' || string_agg(client_ref, ',' ORDER BY id) FROM lab_orders WHERE account_id = 1 AND consultation_id = 0$CID1")
    [ "${n%% *}" -ge 2 ] && break
    sleep 5; i=$((i + 5))
done
same "present: consultation $CID1 two orders at the lab, two client_refs ($(echo "$n" | cut -d' ' -f2))" "2" "${n%% *}"
same "present: the same requests on both orders (LO2)" "2" \
    "$(dbsql lab lab "SELECT count(DISTINCT t.request_id) FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
                       WHERE o.account_id = 1 AND o.consultation_id = 0$CID1 AND t.request_id IN (
                         SELECT request_id FROM lab_order_tests t2 JOIN lab_orders o2 ON o2.id = t2.order_id
                          WHERE o2.consultation_id = 0$CID1 GROUP BY request_id HAVING count(*) > 1)")"
r=$(fcheck)
same "gmctl check $INST at the planting: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "1" "${r%% *}"

# --- the fix -----------------------------------------------------------------
FIXED_AT=$(apply_fix)
pass "fixed as the GM applies it: the purpose's script loaded at $FIXED_AT"
r=$(fcheck "$FIXED_AT")
same "gmctl check $INST since the fix, before any retry: too soon: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "3" "${r%% *}"

# --- s4 fixed ------------------------------------------------------------------
set -- $(delayed_post "$FIXED_AT")
CONS2=$1 REF2=${2:-}
[ -n "$REF2" ] && pass "the same delay after the fix: post $REF2 timed out" || fail "no post timed out under the lock after the fix"
CID2=$(echo "$REF2" | cut -d- -f2)
l=
i=0
while [ "$i" -lt 150 ]; do
    l=$(dbsql records clinic "SELECT attempts || ' ' || coalesce(accession, 0) FROM ops.lab_orders_sent WHERE client_ref = '$REF2'")
    [ "${l%% *}" -ge 2 ] && [ "${l#* }" != 0 ] && break
    sleep 5; i=$((i + 5))
done
same "fixed: $REF2 retried under its own key, answered (attempts 2)" "2" "${l%% *}"
same "fixed: one order at the lab for consultation $CID2, the retry answered with the first accession" "1 ${l#* }" \
    "$(dbsql lab lab "SELECT count(*) || ' ' || min(id) FROM lab_orders WHERE account_id = 1 AND consultation_id = 0$CID2")"
r=$(fcheck "$FIXED_AT")
same "gmctl check $INST since the fix: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "0" "${r%% *}"
r=$(check interfaces vet-lab-centre-orders/checks/lo2-one-order-test.sh "$FIXED_AT")
same "LO2 since the fix: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
info "consultations placed: $CONS1, $CONS2"
;;
esac

info "interfaces' timeouts: $(plog interfaces | grep -c 'lab-api timeout' || true)"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
same "teardown: nothing labelled with $GAME left" "" "$left"

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
