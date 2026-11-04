#!/bin/sh
# Short test of the lab fixture (v0.5 build plan, chunk 12b; spec D403;
# master spec 9.3; capture W3 items 0 and 1, W3-f): vet-core's record and
# vet-lab's laboratory loaded by gmctl load-data from the domains (vet-core's
# and vet-lab's data/keys.sql streamed ahead of the lab's load.sql and of its
# two partners' data.sql, run into partners on partners-db; the coherence
# check after), the lab's order API, lab-api, as lab_api behind lab_centre,
# lab_practices and lab_xlab, and its information system and middleware, lis,
# as lab_app and lab_instruments, its lab.identity job calling clinic-api
# with clinic_lookup. On one host, under 30 minutes.
#
# On a copy of tools/tests/fixtures/fixture-lab-core (bastion 0.5.0, records,
# lab and partners-db: postgres 0.5.0, clinic-api and lab-api: api 0.1.0, lis:
# scheduler 0.3.0 at intensity 4; domains: vet-core at records/clinic, vet-lab
# at lab/lab; left out: vet-core's pms, vet-lab's partners/xlab and
# partners/practices):
#   gmctl compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over 20:00
#   local, so T0 falls between 11:00 and 12:00, the bench open) -> deploy ->
#   load-data, then:
#   - the stack file: each credential and role password on its node only;
#   - load-data: the lab's tables, its login roles' SCRAM passwords, no key
#     function left, the stubs' state (xlab.orders, practices.orders and
#     .deliveries), the coherence check clean (load-data fails otherwise);
#   - lab-api: an order posted (201) and posted again with the same account
#     and client_ref (200, the same accession and tests, nothing written);
#     a practice's order; an unknown code or account 422; no credential and
#     the wrong one 401; GET /orders/{accession}; the feed of the centre's
#     account since a time holding released, not performed and cancelled
#     tests, equal to the lab's own rows read as postgres; its two
#     parameters required; an open send-out's answer recorded once (again:
#     200, nothing written twice), an unknown send_key 404;
#   - inject -> start-load (T0): lis running with its six jobs; within
#     minutes lab.identity writes the posted centre order's animal from
#     clinic-api, lis receives it (its samples' collection placed 20 minutes
#     back) and releases urgent tests; no error in lis's log;
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
# Usage: sh tools/tests/fixtures/fixture-lab-core/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=lab-short
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-lab-short.XXXXXX")
SCN=$tmp/fixture-lab-core
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
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -d "$2" -c "$3"; }
plog() { docker exec "$(ctr lis)" cat "$SCHEDLOG" 2>/dev/null || true; }
pstatus() { docker exec "$(ctr lis)" cat /run/scheduler/status 2>/dev/null || true; }

# HTTP from lab-api's own task to its hostname: `probe` reads JSON requests
# on its standard input, one a line ({"method", "path", "cred", "body"}; cred
# the secret's name or null), and prints one JSON line each: {"path",
# "status", "ms", "body"}.
PROBE_PY='
import http.client, json, sys, time
for line in sys.stdin:
    q = json.loads(line)
    headers = {"Content-Type": "application/json"}
    if q.get("cred"):
        headers["Authorization"] = "Bearer " + open("/opt/gm/secrets/http_" + q["cred"]).read().strip()
    t = time.monotonic()
    try:
        c = http.client.HTTPConnection("lab-api", 8000, timeout=20)
        c.request(q["method"], q["path"], body=json.dumps(q["body"]) if "body" in q else None, headers=headers)
        r = c.getresponse()
        status, body = r.status, r.read().decode("utf-8", "replace")
        c.close()
    except OSError as exc:
        status, body = "error", type(exc).__name__ + ": " + str(exc)
    print(json.dumps({"path": q["path"], "status": status, "ms": round((time.monotonic() - t) * 1000),
                      "body": body}))
'
probe() { docker exec -i "$(ctr lab-api)" python3 -I -c "$PROBE_PY"; }
# `status <json line>` and `body <json line>`
status() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["status"])' "$1"; }
body() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["body"])' "$1"; }

# `status <json line>` and `body <json line>`
status() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["status"])' "$1"; }
body() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["body"])' "$1"; }

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/, nodes/lis/ and nodes/lab-api/ as compose writes them"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the seven nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# Hand-over 8 to 9 hours ahead at 20:00 local: T0 between 11:00 and 12:00 local.
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "lab", "clinic-api", "lis", "lab-api", "partners-db"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: none on the bastion" "bastion -" "$(line 1)"
same "stack: none on records and lab (load-data sets the roles' passwords)" "records - lab -" "$(line 2) $(line 3)"
same "stack: clinic_lookup and vet_lookup's password on clinic-api" \
    "clinic-api http_clinic_lookup role_vet_lookup_password" "$(line 4)"
same "stack: clinic_lookup, lab_app's and lab_instruments' passwords on lis" \
    "lis http_clinic_lookup role_lab_app_password role_lab_instruments_password" "$(line 5)"
same "stack: lab-api's three credentials and lab_api's password on lab-api" \
    "lab-api http_lab_centre http_lab_practices http_lab_xlab role_lab_api_password" "$(line 6)"
same "stack: none on partners-db (its stubs' nodes left out)" "partners-db -" "$(line 7)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the seven nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
case $(pstatus) in idle\ *) pass "lis idle before the load: $(pstatus)" ;;
    *) fail "lis before the load: [$(pstatus)]" ;; esac

# --- load-data ---------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core, the lab and the stubs' state loaded, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
counts=$(dbsql lab lab "SELECT (SELECT count(*) FROM lab_orders) || ' ' || (SELECT count(*) FROM lab_order_tests) || ' '
  || (SELECT count(*) FROM lab_results) || ' ' || (SELECT count(*) FROM lab_send_outs WHERE status IN ('sent', 'accepted'))")
info "lab rows: orders order_tests results open-send-outs: $counts"
info "lab size: $(dbsql lab lab "SELECT pg_size_pretty(pg_database_size('lab'))")"
same "load-data: 180 tests, 121 accounts" "180 121" \
    "$(dbsql lab lab "SELECT (SELECT count(*) FROM lab_tests) || ' ' || (SELECT count(*) FROM lab_accounts)")"
same "load-data: every lab login role has a SCRAM password" \
    "lab_api:true lab_app:true lab_dispatch:true lab_instruments:true lab_reports:true" \
    "$(dbsql lab postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%'), ' ' ORDER BY rolname)
                           FROM pg_authid WHERE rolname LIKE 'lab\_%'")"
same "load-data: no key function left in the catalog" "0" \
    "$(dbsql lab lab "SELECT count(*) FROM pg_proc WHERE proname LIKE 'lab\_%' OR proname LIKE 'core\_%'")"
stubs=$(dbsql partners-db partners "SELECT (SELECT count(*) FROM xlab.orders WHERE answered_at IS NULL) || ' '
  || (SELECT count(*) FROM practices.orders) || ' ' || (SELECT count(*) FROM practices.deliveries)")
info "stubs: xlab open send-outs, practices' orders, deliveries: $stubs"
same "the external lab's stub holds the lab's open send-outs" "$(echo "$counts" | cut -d' ' -f4)" \
    "$(echo "$stubs" | cut -d' ' -f1)"
same "the practices' stub holds the lab's open practice orders" \
    "$(dbsql lab lab "SELECT count(*) FROM lab_orders WHERE account_id > 1 AND completed_at IS NULL AND cancelled_at IS NULL")" \
    "$(echo "$stubs" | cut -d' ' -f2)"
same "the stubs' roles on partners only own their schemas" "practices:practices xlab:xlab" \
    "$(dbsql partners-db partners "SELECT string_agg(nspname || ':' || pg_get_userbyid(nspowner), ' ' ORDER BY nspname)
                                   FROM pg_namespace WHERE nspname IN ('xlab', 'practices')")"
coh=$(sed -n '/^coherence:/,$p' "$SCN/composition.yaml" | head -n 12 | tr '\n' ' ')
info "composition.yaml's coherence record: $(printf '%s' "$coh" | cut -c1-300)"

# --- lab-api ---------------------------------------------------------------------
ANIMAL=$(dbsql records clinic "SELECT id FROM animals WHERE species = 'dog' AND status = 'alive' AND id > 12 ORDER BY id LIMIT 1 OFFSET 200")
SINCE=$(dbsql lab lab "SELECT to_char(min(c) AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM (
          SELECT t.cancelled_at AS c FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
           WHERE o.account_id = 1 AND t.status = 'cancelled' ORDER BY t.cancelled_at DESC LIMIT 2) x")
SEND=$(dbsql lab lab "SELECT send_key FROM lab_send_outs WHERE status = 'accepted' ORDER BY id LIMIT 1")
info "witnesses: animal $ANIMAL, feed since $SINCE, open send-out $SEND"
REF="C-TEST$(date +%s)-urgent"
CENTRE="{\"account\": 1, \"client_ref\": \"$REF\", \"priority\": \"urgent\", \"animal_id\": $ANIMAL, \"requested_by\": 20,
 \"tests\": [{\"code\": \"CBC\", \"request_id\": null}, {\"code\": \"GLU\"}]}"
out=$tmp/answers.jsonl
probe > "$out" <<EOF
{"method": "POST", "path": "/orders", "cred": "lab_centre", "body": $(echo $CENTRE)}
{"method": "POST", "path": "/orders", "cred": "lab_centre", "body": $(echo $CENTRE)}
{"method": "POST", "path": "/orders", "cred": "lab_practices", "body": {"account": 7, "client_ref": "$(date +%y%m%d)-T$(date +%s)", "priority": "routine", "patient_ref": "P00042", "client_surname": "Quinn", "species": "cat", "sex": "female", "born_on": "2019-05-01", "tests": [{"code": "HISTO"}, {"code": "CBC"}, {"code": "TT4"}]}}
{"method": "POST", "path": "/orders", "cred": "lab_centre", "body": {"account": 1, "client_ref": "C-BAD", "priority": "routine", "tests": [{"code": "NOPE"}]}}
{"method": "POST", "path": "/orders", "cred": "lab_centre", "body": {"account": 999, "client_ref": "C-BAD", "priority": "routine", "tests": [{"code": "CBC"}]}}
{"method": "POST", "path": "/orders", "cred": null, "body": {"account": 1, "client_ref": "C-NOCRED", "priority": "routine", "tests": [{"code": "CBC"}]}}
{"method": "POST", "path": "/orders", "cred": "lab_xlab", "body": {"account": 1, "client_ref": "C-WRONG", "priority": "routine", "tests": [{"code": "CBC"}]}}
{"method": "GET", "path": "/orders?account=1&released_since=$SINCE", "cred": "lab_centre"}
{"method": "GET", "path": "/orders?account=1", "cred": "lab_centre"}
{"method": "GET", "path": "/orders/99999999", "cred": "lab_centre"}
{"method": "POST", "path": "/send-outs/$SEND/result", "cred": "lab_xlab", "body": {"accession": "NL0400001", "resulted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "results": [{"analyte": "REPORT", "text_value": "No significant abnormality detected."}]}}
{"method": "POST", "path": "/send-outs/$SEND/result", "cred": "lab_xlab", "body": {"accession": "NL0400001", "resulted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)", "results": [{"analyte": "REPORT", "text_value": "No significant abnormality detected."}]}}
{"method": "POST", "path": "/send-outs/00000000-0000-0000-0000-000000000000/result", "cred": "lab_xlab", "body": {"resulted_at": "2026-11-04T10:00:00Z", "results": [{"analyte": "REPORT", "text_value": "x"}]}}
{"method": "POST", "path": "/send-outs/$SEND/result", "cred": "lab_centre", "body": {"resulted_at": "2026-11-04T10:00:00Z", "results": [{"analyte": "REPORT", "text_value": "x"}]}}
EOF
ACC=$(python3 -c 'import json, sys; print(json.loads(json.loads(open(sys.argv[1]).readline())["body"])["accession"])' "$out" 2>/dev/null || echo 0)
printf '%s\n' "{\"method\": \"GET\", \"path\": \"/orders/$ACC\", \"cred\": \"lab_practices\"}" | probe >> "$out"
expected=$(dbsql lab lab "SELECT coalesce(json_agg(json_build_array(t.id, t.status) ORDER BY f.at, t.id), '[]') FROM (
    SELECT id, released_at AS at FROM lab_order_tests WHERE status = 'released' AND released_at >= '$SINCE'
    UNION ALL SELECT id, not_performed_at FROM lab_order_tests WHERE status = 'not-performed' AND not_performed_at >= '$SINCE'
    UNION ALL SELECT id, cancelled_at FROM lab_order_tests WHERE status = 'cancelled' AND cancelled_at >= '$SINCE') f
  JOIN lab_order_tests t ON t.id = f.id JOIN lab_orders o ON o.id = t.order_id WHERE o.account_id = 1")
written=$(dbsql lab lab "SELECT count(*) FROM lab_orders WHERE client_ref = '$REF'") 
resulted=$(dbsql lab lab "SELECT s.status || ' ' || (SELECT count(*) FROM lab_results r WHERE r.order_test_id = s.order_test_id)
                          FROM lab_send_outs s WHERE s.send_key = '$SEND'")
verdict=$(python3 - "$out" "$expected" "$written" "$resulted" <<'EOF'
import json, sys
a = [json.loads(l) for l in open(sys.argv[1])]
exp, written, resulted = json.loads(sys.argv[2]), sys.argv[3], sys.argv[4]
st = [x["status"] for x in a]
j = lambda i: json.loads(a[i]["body"])
out = []
def check(name, ok, detail=""):
    out.append(("PASS" if ok else "FAIL") + "  " + name + ("" if ok else f" ({detail})"))
first = j(0) if st[0] == 201 else {}
check("POST /orders (the centre): 201, an accession and its two tests",
      st[0] == 201 and [t["code"] for t in first.get("tests", [])] == ["CBC", "GLU"], a[0]["body"][:200])
check("POST /orders again, the same account and client_ref: 200, the same body",
      st[1] == 200 and j(1) == first, a[1]["body"][:200])
check("the order written once", written == "1", written)
check("POST /orders (a practice, lab_practices): 201", st[2] == 201, a[2]["body"][:200])
check("an unknown code 422, an unknown account 422", st[3] == 422 and st[4] == 422, f"{st[3]} {st[4]}")
check("no credential 401, lab_xlab on orders 401", st[5] == 401 and st[6] == 401, f"{st[5]} {st[6]}")
feed = j(7) if st[7] == 200 else []
got = [[x["order_test_id"], x["status"]] for x in feed]
statuses = sorted({x["status"] for x in feed})
check(f"the feed since the time: {len(feed)} tests, the lab's own rows, in order", got == exp,
      f"{len(got)} against {len(exp)}")
check("the feed holds released, not performed and cancelled tests",
      statuses == ["cancelled", "not-performed", "released"], statuses)
rel = [x for x in feed if x["status"] == "released"]
check("a released test carries its results (analyte, value, unit, flag, low, high); the others none",
      bool(rel) and all(x["results"] for x in rel[:20])
      and sorted(rel[0]["results"][0]) == ["analyte", "flag", "high", "low", "numeric_value", "text_value", "unit"]
      and all(not x["results"] for x in feed if x["status"] != "released"), a[7]["body"][:200])
check("the feed without released_since: 422", st[8] == 422, a[8]["body"][:200])
check("GET /orders/99999999: 404", st[9] == 404, a[9]["body"][:200])
check("an open send-out's answer: 200 resulted", st[10] == 200 and j(10) == {"send_key": j(10).get("send_key"), "status": "resulted"},
      a[10]["body"][:200])
check("the same answer again: 200, nothing written twice", st[11] == 200 and resulted == "resulted 1", resulted)
check("an unknown send_key 404, lab_centre on send-outs 401", st[12] == 404 and st[13] == 401, f"{st[12]} {st[13]}")
o = j(14) if st[14] == 200 else {}
check("GET /orders/{accession}: ordered, its tests ordered", o.get("state") == "ordered"
      and [t["status"] for t in o.get("tests", [])] == ["ordered", "ordered"], a[14]["body"][:200])
out.append(f"....  slowest answer {max(x['ms'] for x in a)} ms; the feed {a[7]['ms']} ms")
print("\n".join(out))
EOF
)
printf '%s\n' "$verdict"
passes=$((passes + $(printf '%s\n' "$verdict" | grep -c '^PASS' || true)))
failures=$((failures + $(printf '%s\n' "$verdict" | grep -c '^FAIL' || true)))

# --- T0: the information system ----------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
i=0
while [ "$i" -lt 30 ]; do
    case $(pstatus) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(pstatus) in running\ *) pass "lis running: $(pstatus)" ;; *) fail "lis not running: [$(pstatus)]" ;; esac
info "local time at T0: $(dbsql lab lab "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'Dy HH24:MI') FROM lab_settings")"
jobs=$(docker exec "$(ctr lis)" cat /run/scheduler/loaded 2>/dev/null | sed -n 's/^job \([^ ]*\) next=.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')
same "lis loaded its six jobs" "6" "$(echo "$jobs" | wc -w | tr -d ' ')"
info "lis's jobs: $jobs"
# Time placed, never waited for: the centre order's samples collected 20 minutes ago.
dbsql lab lab "UPDATE lab_samples SET collected_at = now() - interval '20 minutes' WHERE order_id = $ACC" >/dev/null
identity=; received=; released=0
i=0
while [ "$i" -lt 540 ]; do
    identity=$(dbsql lab lab "SELECT coalesce(species, '') || ' ' || coalesce(client_surname, '') FROM lab_orders WHERE id = $ACC")
    received=$(dbsql lab lab "SELECT received_at IS NOT NULL FROM lab_orders WHERE id = $ACC")
    released=$(dbsql lab lab "SELECT count(*) FROM lab_order_tests WHERE released_at >= '$T0'")
    [ "$identity" != " " ] && [ "$received" = t ] && [ "$released" -gt 0 ] && break
    sleep 15; i=$((i + 15))
done
info "after $i s: identity [$identity], received [$received], tests released since T0 [$released]"
want=$(dbsql records clinic "SELECT species FROM animals WHERE id = $ANIMAL")
same "lab.identity: the order's species from clinic-api" "$want" "$(echo "$identity" | cut -d' ' -f1)"
same "lis received the centre's order" "t" "$received"
[ "$released" -gt 0 ] && pass "lis released $released tests since T0" || fail "no test released since T0"
info "since T0: $(dbsql lab lab "SELECT (SELECT count(*) FROM lab_samples WHERE received_at >= '$T0') || ' samples received, '
  || (SELECT count(*) FROM lab_results WHERE measured_at >= '$T0') || ' results, '
  || (SELECT count(*) FROM lab_order_tests WHERE technical_at >= '$T0') || ' validated, '
  || (SELECT count(*) FROM lab_batches WHERE started_at >= '$T0') || ' batches'")"
info "lis's log: $(plog | grep -c ' run \| key ' || true) lines of work; lab_app and lab_instruments sessions: $(dbsql lab postgres "SELECT count(*) FROM pg_stat_activity WHERE usename IN ('lab_app', 'lab_instruments')")"
info "lis's lab.identity calls on clinic-api: $(plog | grep -c 'http job=lab.identity' || true)"
errs=$(plog | grep ' error ' || true)
same "lis ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  lis: /'

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
