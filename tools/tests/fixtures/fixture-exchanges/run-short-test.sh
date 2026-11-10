#!/bin/sh
# Short test of the exchanges fixture (v0.5 build plan, chunk 19; master
# spec 12.2 purposes 4 and 5, 18.1; spec D435, D438, D440; capture W4 items
# 0, 4 and 5): purposes 4 (vet-centre-exchanges) and 5
# (vet-notifiable-diseases) on vet-core's record and vet-lab's laboratory,
# with the other centres' stub (vet-core's, three hostnames) and the
# authority's (purpose 5's) on the partners' three nodes. On one host, under
# 30 minutes from the deployment.
#
# Time is placed, never waited for (master spec 18.1): the hand-over is
# planned so that T0 falls at about 23:45 local, and purpose 5's 02:15 copy
# is moved, before render, to 00:01 local (nodes/interfaces/jobs.yaml of the
# copy), so it copies the notifications made before midnight as
# "yesterday's". The local minute is the real one (the shift is whole hours):
# before render the test waits, if need be, until a deployment starting then
# reaches T0 at about :45 (EXCH_PREP_MINUTES, default 7, the minutes from the
# deployment to T0); that wait is not the run's.
#
# On a copy of tools/tests/fixtures/fixture-exchanges (bastion 0.5.0;
# records, lab, partners-db: postgres 0.5.0; clinic-api, partners-api: api
# 0.1.0; interfaces, partners-backend: scheduler 0.3.0):
#   gmctl compose --check -> the copy moved -> fit (2 CPU / 4G / 8G) ->
#   render -> deploy -> load-data, then:
#   - load-data: office and its tables, the purposes' ops tables in clinic
#     and lab, vet_exchange's password, the centres holding the clinic's
#     exchanges in flight by the same keys, the authority's state;
#   - one 503 placed (setval on authority.calls) -> inject -> start-load
#     (T0, about 23:45 local), then, as the left-out pms and lis would: an
#     outbound exchange requested, an inbound one decided, another reported,
#     a vet's notifiable diagnosis (category A) and a lab notification of a
#     practice's recorded; a centre's own request made (POST /request on
#     aldermoor-central, as the back end's tick);
#   - the outbound exchange posted to its centre, its answer due placed at
#     once (UPDATE centres.exchanges SET due_at = now()), answered at
#     clinic-api; the inbound answer and report at their centre within ten
#     minutes; the centre's request recorded at once; both notifications
#     referenced within their deadline, the 503 retried under the same key;
#   - after local midnight, the moved copy: both notifications in office's
#     copies, once;
#   - the ten checks (EX1 to EX4 on partners-db, EX5 and ND1 to ND5 on
#     interfaces), CHECK_SINCE T0: each exit 0 (fixed);
#   - no error in the runners' logs;
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
# Usage: sh tools/tests/fixtures/fixture-exchanges/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=exchanges-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
PREP=${EXCH_PREP_MINUTES:-7}
P4=$REPO/purposes/vet-centre-exchanges/checks
P5=$REPO/purposes/vet-notifiable-diseases/checks

failures=0
passes=0
stamp() { date -u +%H:%M:%S; }
pass() { printf '%s PASS  %s\n' "$(stamp)" "$*"; passes=$((passes + 1)); }
fail() { printf '%s FAIL  %s\n' "$(stamp)" "$*"; failures=$((failures + 1)); }
info() { printf '%s ....  %s\n' "$(stamp)" "$*"; }
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-exchanges-short.XXXXXX")
SCN=$tmp/fixture-exchanges
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
rm -f "$SCN/run-short-test.sh"

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2" -c "$3"; }
slog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
sstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
ran() {    # ran <job> <from epoch>: the end lines of its successful runs since
    slog interfaces | python3 -c '
import sys, datetime
job, since = sys.argv[1], float(sys.argv[2])
for line in sys.stdin:
    if f" run job={job} " in line and "phase=end" in line and "status=ok" in line:
        t = datetime.datetime.strptime(line.split()[0].rstrip("Z")[:19], "%Y-%m-%dT%H:%M:%S")
        if t.replace(tzinfo=datetime.timezone.utc).timestamp() >= since:
            print(line.rstrip())' "$1" "$2"
}
until_true() {   # until_true <timeout s> <description> <command...>: polled every 15 s
    limit=$(( $(date +%s) + $1 )); what=$2; shift 2
    while [ "$(date +%s)" -lt "$limit" ]; do
        if "$@"; then pass "$what"; return 0; fi
        sleep 15
    done
    fail "$what (not within the wait)"
    return 1
}
# One call from partners-backend's own task to a centre's hostname on the
# partners' api node, with the back end's credential (the tick's way).
tick_call() {   # tick_call <hostname> <path>: prints the status and the body
    docker exec -i "$(ctr partners-backend)" python3 -I -c '
import http.client, sys
tok = open("/opt/gm/secrets/http_partners_backend").read().strip()
c = http.client.HTTPConnection("partners-api", 8000, timeout=30)
c.request("POST", sys.argv[2], body="{}", headers={"Host": sys.argv[1], "Authorization": "Bearer " + tok,
                                                  "Content-Type": "application/json"})
r = c.getresponse()
print(r.status, r.read().decode())' "$1" "$2"
}
check() {   # check <node> <script>: one check as gmctl check runs it (root, sh -s, CHECK_SINCE)
    out=$(docker exec -i -u root -e "CHECK_SINCE=$T0" "$(ctr "$1")" sh -s < "$2" 2>&1) && rc=0 || rc=$?
    line=$(printf '%s\n' "$out" | head -n 1)
    if [ "$rc" -eq 0 ]; then pass "$(basename "$2") on $1: exit 0, $line"
    else fail "$(basename "$2") on $1: exit $rc, $out"; fi
}

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/, nodes/interfaces/, nodes/partners-api/ and nodes/partners-backend/ as compose writes them"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi
# The 02:15 copy moved to 00:01 local (scenario time), its line only.
python3 - "$SCN/nodes/interfaces/jobs.yaml" <<'EOF'
import sys, yaml
path = sys.argv[1]
text = open(path).read()
lines = text.splitlines(keepends=True)
cur = None
for i, line in enumerate(lines):
    if line.lstrip().startswith("- name:"):
        cur = line.split(":", 1)[1].strip()
    elif cur == "copy-notifications" and line.lstrip().startswith("at:"):
        lines[i] = line[:len(line) - len(line.lstrip())] + 'at: "1 0 * * *"\n'
        cur = None
open(path, "w").write("".join(lines))
jobs = {j["name"]: j["at"] for j in yaml.safe_load(open(path))["jobs"]}
assert jobs["copy-notifications"] == "1 0 * * *", jobs
EOF
info "copy-notifications moved to 00:01 local in the copy's nodes/interfaces/jobs.yaml"

# --- time placement ---------------------------------------------------------
# T0 at about :45 real (local 23:45): wait, if need be, so that a deployment
# starting now reaches T0 then.
now=$(date +%s)
min=$(( (now + PREP * 60) / 60 % 60 ))
if [ "$min" -lt 42 ] || [ "$min" -gt 48 ]; then
    start=$(( (now / 3600) * 3600 + ((45 - PREP + 60) % 60) * 60 ))
    [ "$start" -gt "$now" ] || start=$((start + 3600))
    info "waiting $(( start - now )) s so that T0 falls at about :45 (EXCH_PREP_MINUTES $PREP)"
    sleep $(( start - now ))
fi
started=$(date +%s)
T0EST=$(( started + PREP * 60 ))
HANDOVER=$(python3 - "$T0EST" <<'EOF'
import datetime, sys
t0 = datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc)
shift = (23 - t0.hour + 11) % 24 - 11                 # local 23 at T0, in -11..12
planned_hour = (14 - shift) % 24                       # the designed hand-over, 14:00 local
moment = (t0 + datetime.timedelta(hours=9)).replace(minute=0, second=0, microsecond=0)
while moment.hour != planned_hour:
    moment += datetime.timedelta(hours=1)
print(moment.strftime("%Y-%m-%dT%H:00Z"))
EOF
)

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
info "game id $GAME; planned hand-over $HANDOVER (T0 expected at $(date -u -d "@$T0EST" +%H:%M) UTC)"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "clinic-api", "interfaces", "partners-api", "partners-backend"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: no credential on the bastion" "bastion -" "$(line 1)"
same "stack: clinic-api holds clinic_centres, clinic_lookup and its two roles' passwords" \
    "clinic-api http_clinic_centres http_clinic_lookup role_vet_exchange_password role_vet_lookup_password" "$(line 2)"
same "stack: interfaces holds its two partners' credentials and its five roles' passwords" \
    "interfaces http_authority_customer http_centres_customer role_lab_dispatch_password role_lab_reports_password role_office_jobs_password role_vet_interfaces_password role_vet_reports_password" "$(line 3)"
info "stack: $(line 4); $(line 5)"

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
    pass "load-data: the core, the lab, the partners' state, office, the purposes' DDL; the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: office's two tables, owned by office" "regulatory_submissions:office runs:office" \
    "$(dbsql records office "SELECT string_agg(tablename || ':' || tableowner, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'public'")"
same "load-data: the ops tables in clinic (purposes 4 and 5)" "exchange_messages incidents notifications runs watermarks" \
    "$(dbsql records clinic "SELECT string_agg(tablename, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'ops'")"
same "load-data: the ops tables in lab (purpose 5)" "incidents notifications runs watermarks" \
    "$(dbsql lab lab "SELECT string_agg(tablename, ' ' ORDER BY tablename) FROM pg_tables WHERE schemaname = 'ops'")"
same "load-data: the watermarks at load_epoch" "vet-centre-exchanges:answers vet-centre-exchanges:reports vet-notifiable-diseases:vet" \
    "$(dbsql records clinic "SELECT string_agg(purpose || ':' || name, ' ' ORDER BY purpose, name) FROM ops.watermarks")"
same "load-data: vet_exchange, vet_interfaces and office_jobs have SCRAM passwords" "office_jobs:t vet_exchange:t vet_interfaces:t" \
    "$(dbsql records postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%')::text, ' ' ORDER BY rolname)
                               FROM pg_authid WHERE rolname IN ('vet_exchange', 'vet_interfaces', 'office_jobs')" | sed 's/:true/:t/g; s/:false/:f/g')"
inflight=$(dbsql records clinic "SELECT string_agg(exchange_key::text, ',' ORDER BY exchange_key) FROM exchanges
  WHERE state IN ('sent', 'received') OR (state = 'accepted' AND kind = 'examination')")
same "the centres hold the clinic's exchanges in flight, by the same keys" "$inflight" \
    "$(dbsql partners-db partners "SELECT string_agg(exchange_key::text, ',' ORDER BY exchange_key) FROM centres.exchanges")"
info "in flight at T0: $(dbsql records clinic "SELECT string_agg(direction || ' ' || state || ' ' || n, ', ') FROM (SELECT direction, state, count(*) n FROM exchanges
  WHERE state IN ('sent', 'received') OR (state = 'accepted' AND kind = 'examination') GROUP BY 1, 2 ORDER BY 1, 2) x"); lab notifications open: $(dbsql lab lab "SELECT count(*) FROM lab_notifications WHERE notified_at IS NULL")"
same "the authority's state: delay_ms 0, fail_one_in 50" "delay_ms=0 fail_one_in=50" \
    "$(dbsql partners-db partners "SELECT string_agg(name || '=' || value, ' ' ORDER BY name) FROM authority.state")"

# --- T0 ---------------------------------------------------------------------
now=$(date +%s); min=$(( now / 60 % 60 ))
if [ "$min" -lt 42 ]; then
    info "waiting $(( (42 - min) * 60 - now % 60 )) s for :42 (T0 at about 23:45 local)"
    sleep $(( (42 - min) * 60 - now % 60 ))
elif [ "$min" -gt 52 ]; then
    fail "T0 would fall at :$min, too close to local midnight: raise EXCH_PREP_MINUTES (now $PREP)"
    exit 1
fi
# The next call to the authority is a multiple of fail_one_in: 503.
dbsql partners-db partners "SELECT setval('authority.calls', (coalesce(max(call), 0) / 50 + 1) * 50 - 1) FROM authority.notification_calls" >/dev/null
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
T0S=$(date +%s)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0, $(( T0S - started )) s after the deployment began)"; else fail "start-load"; exit 1; fi
LOCAL=$(dbsql records clinic "SELECT to_char(now() AT TIME ZONE timezone, 'Dy HH24:MI') FROM business_settings")
info "local time at T0: $LOCAL"
case $LOCAL in *\ 23:*) pass "T0 at 23:xx local" ;; *) fail "T0 not at 23:xx local ($LOCAL)" ;; esac
i=0
while [ "$i" -lt 30 ]; do
    case $(sstatus interfaces) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(sstatus interfaces) in running\ *) pass "interfaces running: $(sstatus interfaces)" ;; *) fail "interfaces not running: [$(sstatus interfaces)]" ;; esac

# --- what pms and lis would do, and a centre's request ------------------------
OUT=$(dbsql records clinic "INSERT INTO exchanges (direction, kind, partner_site_id, animal_id, reason, exchange_key, requested_at, state)
  SELECT 'out', 'examination', 3, a.id, 'MRI not available here', gen_random_uuid(), now(), 'requested'
    FROM animals a WHERE a.status = 'alive' AND EXISTS (SELECT 1 FROM ownerships w WHERE w.animal_id = a.id AND w.role = 'owner' AND w.until_at IS NULL)
     AND EXISTS (SELECT 1 FROM consultations c WHERE c.animal_id = a.id AND c.state <> 'open')
   ORDER BY a.id DESC LIMIT 1 RETURNING id || ' ' || exchange_key")
OUT_ID=${OUT%% *}; OUT_KEY=${OUT#* }
info "outbound exchange $OUT_ID ($OUT_KEY) requested to aldermoor-south"
REP=$(dbsql records clinic "UPDATE exchanges SET state = 'reported', reported_at = now(), report = 'No significant abnormality detected; follow-up at the home centre.'
  WHERE id = (SELECT id FROM exchanges WHERE direction = 'in' AND state = 'accepted' AND kind = 'examination' ORDER BY accepted_for, id LIMIT 1)
  RETURNING id || ' ' || exchange_key")
REP_KEY=${REP#* }
info "inbound exchange ${REP%% *} reported, as the vets would"
DIAG=$(dbsql records clinic "INSERT INTO diagnoses (consultation_id, code, confirmed, recorded_at)
  SELECT (SELECT max(id) FROM consultations WHERE animal_id IS NOT NULL), (SELECT min(code) FROM diagnosis_codes WHERE notifiable = 'A'), false, now()
  RETURNING id || ' ' || code")
DIAG_ID=${DIAG%% *}
LABN=$(dbsql lab lab "INSERT INTO lab_notifications (order_test_id, diagnosis_code, category, suspected_at)
  SELECT t.id, c.diagnosis_code, CASE WHEN c.diagnosis_code IN ('D-FM01', 'D-AH01', 'D-SP01', 'D-LS01') THEN 'A' ELSE 'other' END, now()
    FROM lab_order_tests t JOIN lab_tests c ON c.id = t.test_id JOIN lab_orders o ON o.id = t.order_id
   WHERE c.diagnosis_code IS NOT NULL AND o.account_id > 1 AND NOT EXISTS (SELECT 1 FROM lab_notifications x WHERE x.order_test_id = t.id)
   ORDER BY t.id DESC LIMIT 1 RETURNING id || ' ' || category")
LABN_ID=${LABN%% *}
info "a suspected category A diagnosis $DIAG (vet-$DIAG_ID) and a practice's lab notification $LABN (lab-$LABN_ID) recorded"
REQ=$(tick_call aldermoor-central /request)
NEW_KEY=$(printf '%s' "$REQ" | python3 -c 'import json, sys; s = sys.stdin.read(); print(json.loads(s.split(" ", 1)[1]).get("exchange_key", ""))' 2>/dev/null || true)
case $REQ in 200\ *'"requested": 1'*|200\ *'"requested":1'*) pass "aldermoor-central's own request posted: $NEW_KEY" ;; *) fail "aldermoor-central's request: $REQ" ;; esac
same "the centre's request recorded in exchanges at once (direction in, received)" "in received" \
    "$(dbsql records clinic "SELECT direction || ' ' || state FROM exchanges WHERE exchange_key = '$NEW_KEY'")"
# The vets accept the centre's fresh request (the inbound answer's leg).
ANS=
case $NEW_KEY in
    ????????-????-????-????-????????????)
        ANS=$(dbsql records clinic "UPDATE exchanges SET state = 'accepted', accepted_for = current_date + 3, answered_at = now()
          WHERE exchange_key = '$NEW_KEY' AND direction = 'in' AND state = 'received'
          RETURNING id || ' ' || exchange_key") ;;
esac
ANS_KEY=${ANS#* }
if [ -n "$ANS" ]; then
    info "inbound exchange ${ANS%% *} ($ANS_KEY, aldermoor-central's request) answered (accepted), as the vets would"
else
    fail "no inbound exchange to answer: aldermoor-central's request [$NEW_KEY] not recorded as received"
fi

# --- the round trips and the notifications --------------------------------------
received() { [ -n "$(dbsql partners-db partners "SELECT 1 FROM centres.exchanges WHERE exchange_key = '$OUT_KEY' AND hostname = 'aldermoor-south' AND received_at IS NOT NULL")" ]; }
until_true 420 "the outbound exchange posted by sync-exchanges and received by aldermoor-south" received || true
dbsql partners-db partners "UPDATE centres.exchanges SET due_at = now() WHERE exchange_key = '$OUT_KEY'" >/dev/null
info "its answer due placed at once"
answered() { [ -n "$(dbsql records clinic "SELECT 1 FROM exchanges WHERE id = $OUT_ID AND state IN ('accepted', 'declined') AND answered_at IS NOT NULL")" ]; }
until_true 420 "the outbound exchange answered at clinic-api by its centre's tick" answered || true
info "outbound: $(dbsql records clinic "SELECT state || ' ' || coalesce(accepted_for::text, '-') || ', sent ' || to_char(sent_at, 'HH24:MI:SS') || ', answered ' || to_char(answered_at, 'HH24:MI:SS') FROM exchanges WHERE id = $OUT_ID")"
at_centre() { [ -n "$(dbsql partners-db partners "SELECT 1 FROM centres.exchanges WHERE exchange_key = '$ANS_KEY' AND answered_at IS NOT NULL")" ] \
    && [ -n "$(dbsql partners-db partners "SELECT 1 FROM centres.exchanges WHERE exchange_key = '$REP_KEY' AND reported_at IS NOT NULL")" ]; }
if [ -n "$ANS" ] && [ -n "$REP" ]; then
    until_true 600 "the inbound answer and report posted to their centres" at_centre || true
    # Within ten minutes of the vets' decision (master spec 12.2 purpose 4, EX2).
    decided=$(dbsql records clinic "SELECT extract(epoch FROM answered_at)::bigint FROM exchanges WHERE exchange_key = '$ANS_KEY'")
    reached=$(dbsql partners-db partners "SELECT coalesce(extract(epoch FROM answered_at)::bigint, 0) FROM centres.exchanges WHERE exchange_key = '$ANS_KEY'")
    if [ "${reached:-0}" -gt 0 ] && [ $(( reached - decided )) -le 600 ]; then
        pass "the inbound answer reached its centre $(( reached - decided )) s after the vets' decision (within ten minutes)"
    else
        fail "the inbound answer did not reach its centre within ten minutes (decided $decided, reached ${reached:-none})"
    fi
else
    fail "the inbound legs: answer [$ANS], report [$REP]: nothing to wait for"
fi
notified() { [ "$(dbsql records clinic "SELECT count(*) FROM ops.notifications WHERE notification_key = 'vet-$DIAG_ID' AND reference IS NOT NULL")" = 1 ] \
    && [ "$(dbsql lab lab "SELECT count(*) FROM lab_notifications WHERE id = $LABN_ID AND authority_ref IS NOT NULL")" = 1 ]; }
until_true 600 "the vet's diagnosis and the lab notification referenced by the authority" notified || true
same "both notified within their deadlines" "t t" \
    "$(dbsql records clinic "SELECT referenced_at <= deadline FROM ops.notifications WHERE notification_key = 'vet-$DIAG_ID'") $(dbsql lab lab "SELECT referenced_at <= deadline FROM ops.notifications WHERE notification_key = 'lab-$LABN_ID'")"
retried=$(dbsql partners-db partners "SELECT string_agg(c.notification_key || ' ' || c.call || ':503 then ' || (SELECT min(d.call) FROM authority.notification_calls d
    WHERE d.notification_key = c.notification_key AND d.status = 201 AND d.call > c.call) || ':201', ', ')
  FROM authority.notification_calls c WHERE c.status = 503")
info "the 503s: ${retried:-none}"
case $retried in *':201'*) pass "the placed 503 retried under the same key, then accepted" ;; *) fail "no 503 retried: [$retried]" ;; esac
info "authority: $(dbsql partners-db partners "SELECT count(*) || ' accepted, ' || sum(accepted - 1) || ' repeats' FROM authority.notifications")"

# --- after midnight: the copy ---------------------------------------------------
copied() { [ -n "$(ran copy-notifications "$T0S")" ]; }
left=$(( 3600 - $(date +%s) % 3600 + 240 ))
info "local midnight in $(( 3600 - $(date +%s) % 3600 )) s; the copy at 00:01"
until_true "$left" "copy-notifications ran at 00:01 local" copied || true
same "both notifications in office's copies, once" "lab-$LABN_ID:1 vet-$DIAG_ID:1" \
    "$(dbsql records office "SELECT string_agg(ref || ':' || n, ' ' ORDER BY ref) FROM (SELECT ref, count(*) n FROM regulatory_submissions
       WHERE ref IN ('vet-$DIAG_ID', 'lab-$LABN_ID') GROUP BY ref) x")"
info "office: $(dbsql records office "SELECT count(*) || ' copies, ' || (SELECT count(*) FROM runs) || ' runs' FROM regulatory_submissions")"

# --- the ten checks -------------------------------------------------------------
for c in ex1-received-in-time ex2-inbound-end-to-end ex3-one-key ex4-agreement; do
    check partners-db "$P4/$c.sh"
done
check interfaces "$P4/ex5-answered-or-escalated.sh"
for c in nd1-notified-in-time nd2-accepted-once nd3-content nd4-referenced-or-escalated nd5-copied-once; do
    check interfaces "$P5/$c.sh"
done

errs=$( { slog interfaces; slog partners-backend; } | grep ' error ' || true)
same "interfaces and partners-backend ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  /'
info "runs on interfaces since T0: $(slog interfaces | grep ' run job=' | grep phase=end | sed 's/.* run job=\([^ ]*\) .*status=\([^ ]*\).*/\1:\2/' | sort | uniq -c | tr -s ' ' | tr '\n' ',')"

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

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s from the deployment's start"
[ "$failures" -eq 0 ]
