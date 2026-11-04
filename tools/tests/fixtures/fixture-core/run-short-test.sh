#!/bin/sh
# Short test of the core fixture (v0.5 build plan, chunk 9b; master spec
# 9.2; capture W2 item 4, W2-d): vet-core's record loaded by gmctl load-data
# from the domain (schema.sql, keys.sql streamed ahead of load.sql, the
# login roles' passwords from their secrets), and its lookup API, clinic-api,
# reading as vet_lookup behind the credential clinic_lookup, and the
# practice software, pms, as vet_app, both composed by gmctl compose from
# the domain's producers. On one host, about three minutes.
#
# On a copy of tools/tests/fixtures/fixture-core (bastion 0.5.0, records:
# postgres 0.5.0, clinic-api: api 0.1.0, pms: scheduler 0.3.0 at intensity
# 0.1, domains: vet-core at records/clinic):
#   gmctl compose --check (nodes/clinic-api/ and nodes/pms/ as compose
#   writes them) -> fit (the laptop playground, 2 CPU / 4G / 8G) -> render
#   -> deploy -> load-data, then:
#   - the stack file: vet_lookup's password and the credential clinic_lookup
#     mounted on clinic-api only, vet_app's on pms only, never on the bastion
#     or records;
#   - pms idle until start-load;
#   - before load-data, a lookup answers honestly (503 or 500, never a hang);
#   - load-data: the core's tables and row counts, every login role (vet_app,
#     vet_lookup, vet_display, vet_reports) with a SCRAM password, CONNECT on
#     clinic by name, no pg_temp.core_* function left in the catalog, no
#     statement of the load in the server's log;
#   - the lookup endpoints for loaded animals, each compared with the record
#     read as postgres: an animal by id; by microchip, UELN and ear tag; its
#     current owner (id, kind, name), a sold animal's the buyer; the current
#     stays (GET /stays?current=true) against the stays not discharged;
#     unknown ids 404, a wrong query 422, no credential 401; no answer
#     carries a contact (e-mail, phone, address) or a death (status,
#     died_at, death_kind);
#   - inject -> start-load (T0): pms running, its two jobs loaded,
#     no error over half a minute (quiet: few calls at intensity 0.1);
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
# Usage: sh tools/tests/fixtures/fixture-core/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=core-short
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-core-short.XXXXXX")
SCN=$tmp/fixture-core
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
dbsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
plog() { docker exec "$(ctr pms)" cat "$SCHEDLOG" 2>/dev/null || true; }
pstatus() { docker exec "$(ctr pms)" cat /run/scheduler/status 2>/dev/null || true; }

# HTTP from clinic-api's own task to its hostname, with the credential it
# mounts (or none): `probe [nocred] <path>...` prints one JSON line a path:
# {"path", "status", "ms", "body"}.
PROBE_PY='
import http.client, json, sys, time
args = sys.argv[1:]
cred = True
if args and args[0] == "nocred":
    cred, args = False, args[1:]
token = open("/opt/gm/secrets/http_clinic_lookup").read().strip()
for path in args:
    t = time.monotonic()
    headers = {"Authorization": "Bearer " + token} if cred else {}
    try:
        c = http.client.HTTPConnection("clinic-api", 8000, timeout=20)
        c.request("GET", path, headers=headers)
        r = c.getresponse()
        status, body = r.status, r.read().decode("utf-8", "replace")
        c.close()
    except OSError as exc:
        status, body = "error", type(exc).__name__ + ": " + str(exc)
    print(json.dumps({"path": path, "status": status, "ms": round((time.monotonic() - t) * 1000),
                      "body": body}))
'
probe() { docker exec -i "$(ctr clinic-api)" python3 -I - "$@" <<EOF
$PROBE_PY
EOF
}
# `status <json line>` and `body <json line>`
status() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["status"])' "$1"; }
body() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])["body"])' "$1"; }

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/ and nodes/pms/ as compose writes them from the domain"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the four nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "clinic-api", "pms"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
same "stack: vet_lookup's password and clinic_lookup on clinic-api" \
    "clinic-api http_clinic_lookup role_vet_lookup_password" "$(printf '%s\n' "$st" | sed -n 3p)"
same "stack: vet_app's password on pms" "pms role_vet_app_password" "$(printf '%s\n' "$st" | sed -n 4p)"
same "stack: none on the bastion" "bastion -" "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: none on records (load-data sets the roles' passwords)" "records -" \
    "$(printf '%s\n' "$st" | sed -n 2p)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the four nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi

r=$(probe /animals/14609)
case $(status "$r") in
    500|503) pass "before load-data: GET /animals/14609 answers $(status "$r") ($(body "$r" | cut -c1-80))" ;;
    *) fail "before load-data: GET /animals/14609: [$r]" ;;
esac
case $(pstatus) in idle\ *) pass "pms idle before the load: $(pstatus)" ;;
    *) fail "pms before the load: [$(pstatus)]" ;; esac

# --- load-data ---------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core loaded ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
counts=$(dbsql clinic "SELECT (SELECT count(*) FROM animals) || ' ' || (SELECT count(*) FROM owners) || ' '
  || (SELECT count(*) FROM consultations) || ' ' || (SELECT count(*) FROM requests) || ' '
  || (SELECT count(*) FROM stays) || ' ' || (SELECT count(*) FROM administrations)")
info "rows: animals owners consultations requests stays administrations: $counts"
same "load-data: 17 000 animals and 10 000 owners" "17000 10000" "$(echo "$counts" | cut -d' ' -f1-2)"
info "size: $(dbsql clinic "SELECT pg_size_pretty(pg_database_size('clinic'))")"
same "load-data: every login role has a SCRAM password" \
    "vet_app:true vet_display:true vet_lookup:true vet_reports:true" \
    "$(dbsql postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%'), ' ' ORDER BY rolname)
                       FROM pg_authid WHERE rolname LIKE 'vet\_%'")"
same "load-data: CONNECT on clinic by name, not PUBLIC" "f t" \
    "$(dbsql postgres "SELECT has_database_privilege('public', 'clinic', 'CONNECT'),
                              has_database_privilege('vet_lookup', 'clinic', 'CONNECT')" | tr '|' ' ')"
same "load-data: no key function left in the catalog" "0" \
    "$(dbsql clinic "SELECT count(*) FROM pg_proc WHERE proname LIKE 'core\_%' OR proname LIKE 'vc\_%'")"
seen=$(docker exec "$(ctr records)" sh -c 'cat /var/log/postgresql/*.log 2>/dev/null | grep "core_consultation\|INSERT INTO consultations\|pg_temp\.vc_" || true')
same "load-data: the load unseen (no statement of it in the server's log)" "0" \
    "$(printf '%s' "$seen" | grep -c . || true)"
[ -z "$seen" ] || docker exec "$(ctr records)" sh -c 'cat /var/log/postgresql/*.log' \
    | awk '/^[0-9][0-9][0-9][0-9]-/ { h = $0; shown = 0 } /core_consultation|INSERT INTO consultations|pg_temp\.vc_/ && !shown { print h; shown = 1 }' \
    | cut -c1-300 | head -n 8 | sed 's/^/....  log: /'
same "vet_lookup sees no contact and no death" "f f f f f" \
    "$(dbsql clinic "SELECT has_column_privilege('vet_lookup', 'owners', 'email', 'SELECT'),
                            has_column_privilege('vet_lookup', 'owners', 'phone', 'SELECT'),
                            has_column_privilege('vet_lookup', 'owners', 'address', 'SELECT'),
                            has_column_privilege('vet_lookup', 'animals', 'died_at', 'SELECT'),
                            has_column_privilege('vet_lookup', 'animals', 'status', 'SELECT')" | tr '|' ' ')"

# --- the lookup endpoints ------------------------------------------------------
# Witnesses, read as postgres: a chipped dog, a horse, a farm animal, a sold
# animal (its current owner the buyer), an animal that died.
pick() { dbsql clinic "$1"; }
DOG=$(pick "SELECT id || ' ' || microchip FROM animals WHERE species = 'dog' AND id > 12 AND microchip IS NOT NULL ORDER BY id LIMIT 1 OFFSET 100")
HORSE=$(pick "SELECT id || ' ' || ueln FROM animals WHERE species = 'horse' AND id > 14608 ORDER BY id LIMIT 1 OFFSET 50")
FARM=$(pick "SELECT id || ' ' || ear_tag FROM animals WHERE herd_id IS NOT NULL ORDER BY id LIMIT 1 OFFSET 30")
SOLD=$(pick "SELECT o.animal_id || ' ' || o.owner_id FROM ownerships o WHERE o.role = 'owner' AND o.until_at IS NULL
              AND EXISTS (SELECT 1 FROM ownerships p WHERE p.animal_id = o.animal_id AND p.role = 'owner' AND p.until_at IS NOT NULL)
              ORDER BY o.animal_id LIMIT 1")
DEAD=$(pick "SELECT id FROM animals WHERE status = 'died' ORDER BY id LIMIT 1")
info "witnesses: dog [$DOG], horse [$HORSE], farm [$FARM], sold [$SOLD], died [$DEAD]"
set -- $DOG; dog=$1; chip=$2
set -- $HORSE; horse=$1; ueln=$2
set -- $FARM; farm=$1; tag=$2
set -- $SOLD; sold=$1; buyer=$2

out=$tmp/answers.jsonl
probe "/animals/$dog" "/animals?microchip=$chip" "/animals?ueln=$ueln" "/animals?ear_tag=$tag" \
      "/animals/$horse" "/animals/$farm" "/animals/$sold/owner" "/animals/$dog/owner" "/animals/$DEAD" \
      "/stays?current=true" "/animals?microchip=941000000000000" \
      "/animals/99999999" "/animals/99999999/owner" "/animals" "/animals?microchip=$chip&ueln=$ueln" \
      "/stays" > "$out"
probe nocred "/animals/$dog" >> "$out"
expected=$(dbsql clinic "SELECT json_build_object(
    'dog', (SELECT row_to_json(x) FROM (SELECT id, species, breed, sex, to_char(born_on, 'YYYY-MM-DD') AS born_on, name,
              food_chain, herd_id, microchip, ueln, passport_number, ear_tag,
              to_char(registered_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS registered_at
              FROM animals WHERE id = $dog) AS x),
    'buyer', (SELECT row_to_json(x) FROM (SELECT id, kind, name FROM owners WHERE id = $buyer) AS x),
    'stays', (SELECT json_agg(id ORDER BY id) FROM stays WHERE discharged_at IS NULL))")
verdict=$(python3 - "$out" "$expected" "$dog" "$horse" "$farm" <<'EOF'
import json, sys
ans = [json.loads(l) for l in open(sys.argv[1])]
exp, dog, horse, farm = json.loads(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
a = {x["path"] + (" nocred" if i == len(ans) - 1 else ""): x for i, x in enumerate(ans)}
def j(p):
    return json.loads(a[p]["body"])
st = lambda p: a[p]["status"]
keys = lambda p: sorted(j(p))
out = []
def check(name, ok, detail=""):
    out.append(("PASS" if ok else "FAIL") + "  " + name + ("" if ok else f" ({detail})"))
paths = list(a)
check(f"GET /animals/{dog}: 200, the record's row", st(paths[0]) == 200 and j(paths[0]) == exp["dog"],
      a[paths[0]]["body"][:200])
for p, want in ((paths[1], dog), (paths[2], horse), (paths[3], farm)):
    check(f"GET {p}: 200, the one animal {want}", st(p) == 200 and [x["id"] for x in j(p)] == [want], a[p]["body"][:200])
check(f"GET {paths[4]} and {paths[5]}: 200", st(paths[4]) == 200 and st(paths[5]) == 200)
check(f"GET {paths[6]}: the sold animal's current owner, the buyer", st(paths[6]) == 200 and j(paths[6]) == exp["buyer"],
      a[paths[6]]["body"][:200])
check(f"GET {paths[7]}: 200, keys id, kind, name", st(paths[7]) == 200 and keys(paths[7]) == ["id", "kind", "name"],
      a[paths[7]]["body"][:200])
check(f"GET {paths[8]} (an animal that died): 200, no death column", st(paths[8]) == 200
      and not set(j(paths[8])) & {"status", "died_at", "death_kind"}, a[paths[8]]["body"][:200])
s = j(paths[9]) if st(paths[9]) == 200 else None
check(f"GET /stays?current=true: the {len(exp['stays'] or [])} stays not discharged",
      s is not None and [x["stay_id"] for x in s] == (exp["stays"] or [])
      and all(sorted(x) == ["admitted_at", "animal_id", "name", "section_id", "species", "stay_id"] for x in s),
      a[paths[9]]["body"][:200])
check(f"GET {paths[10]} (no such chip): 200 []", st(paths[10]) == 200 and j(paths[10]) == [], a[paths[10]]["body"][:200])
for p in paths[11:13]:
    check(f"GET {p}: 404", st(p) == 404, a[p]["body"][:200])
for p in paths[13:16]:
    check(f"GET {p}: 422", st(p) == 422, a[p]["body"][:200])
check("no credential: 401", st(paths[16]) == 401, a[paths[16]]["body"][:200])
bodies = " ".join(x["body"] for x in ans)
leaks = [w for w in ("@example.net", "+999", "email", "phone", "address", "died_at", "death_kind", "\"status\"")
         if w in bodies]
check("no answer carries a contact or a death", not leaks, ", ".join(leaks))
slow = max(x["ms"] for x in ans)
out.append(f"....  slowest answer {slow} ms")
print("\n".join(out))
EOF
)
printf '%s\n' "$verdict"
passes=$((passes + $(printf '%s\n' "$verdict" | grep -c '^PASS' || true)))
failures=$((failures + $(printf '%s\n' "$verdict" | grep -c '^FAIL' || true)))

# --- T0: the practice software ------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
i=0
while [ "$i" -lt 30 ]; do
    case $(pstatus) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(pstatus) in running\ *) pass "pms running: $(pstatus)" ;; *) fail "pms not running: [$(pstatus)]" ;; esac
sleep 30
w=$(plog | grep -E ' (wait|state) ' | tail -n 3 | tr '\n' '|')
info "pms's log: $w"
same "pms loaded vet-core's two jobs" "administrations-round prescriptions-expire" \
    "$(docker exec "$(ctr pms)" cat /run/scheduler/loaded 2>/dev/null | sed -n 's/^job \([^ ]*\) next=.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"
info "pms: $(plog | grep -c ' run \| ok \| call ' || true) log lines of work, vet_app sessions on clinic: $(dbsql postgres "SELECT count(*) FROM pg_stat_activity WHERE usename = 'vet_app' AND datname = 'clinic'")"
errs=$(plog | grep ' error ' || true)
same "pms ran half a minute without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 5 | cut -c1-300 | sed 's/^/....  pms: /'

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
