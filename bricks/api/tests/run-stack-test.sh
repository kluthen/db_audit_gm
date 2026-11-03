#!/bin/sh
# Stack test of the api brick (v0.5 build plan, chunk 5, Done when).
#
# Builds the api image from this worktree, deploys it as a Swarm stack
# (stack.test.yml) with the `postgres` 0.5.0 image as it is (never built
# here), seed files and secrets as external configs and secrets created
# here, then checks, from a client container on the stack's network (SSH
# as player, HTTP as another node would) and from the GM side (docker exec):
#   - started before its database (db at 0 replicas): each api node waits,
#     bounded, for the name db, then starts once db is scaled up and
#     resolves; the endpoint answers once the database is there (503 before);
#   - the lab's node (one hostname): the credential (401 without it, with a
#     wrong one or another endpoint's), the endpoint connecting as its
#     application role (never a superuser), a transaction-local setting
#     never outliving its request, a SECURITY DEFINER call, the request log;
#   - the partners' node (nine hostnames, network aliases): each hostname
#     answering only its own routes, an unknown hostname 404, a partner's
#     endpoint calling the lab's API with its credential (the request log's
#     User-Agent) and writing its own database through SECURITY DEFINER;
#   - player: reads routes/ and db/, may not edit routes/ or api.yaml; edits
#     db/ with sed -i and reloads (the new session setting served); a broken
#     db/ refused by gm-reload-api, named, the server answering as before;
#     the validator red then green; exact sudo wrappers; the secrets' copies
#     unreadable;
#   - report-only: db/ denied, gm-reload-api's refusal; the override of
#     /srv/api/db making it fixable again;
#   - no-access (the partners' node): no player account, no apiconf
#     membership, no sudo rules, SSH refused, the server serving;
#   - the node-health script mounted on the lab's node, reporting `api`;
#   - the entrypoint's refusals; read-only root, capabilities, /run a
#     volume; no pip in the image; the footprint at rest of both nodes.
# Real time throughout (about 8 minutes). Everything it creates is removed
# on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the image
# 127.0.0.1:5000/dbagm/postgres:0.5.0. On the build host, run it under the
# host lock:
#   flock /tmp/dbagm-docker.lock sh bricks/api/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BRICK=$(cd "$HERE/.." && pwd)
FX=$HERE/fixtures
PG_FIXTURES=$BRICK/../postgres/tests/fixtures
NH=$BRICK/../prometheus/companion/node-health
STACK=gmtest-api
IMAGE=127.0.0.1:5000/dbagm/api:0.1.0
DB_IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.0
LAB_SERVICE=${STACK}_lab-api
PAR_SERVICE=${STACK}_partners
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk5-api
PARTNERS="centre-north centre-south abroad head-office messaging cold-storage practices authority"
CONFIGS="lab_api_yaml lab_route_orders lab_db_orders nh_script nh_type nh_run nh_dep_base nh_bundle nh_conf_lab"
CONFIGS="$CONFIGS par_api_yaml par_route_xlab_results par_db_xlab_results seed_postgresql_conf seed_pg_hba_conf db_envelopes"
for p in $PARTNERS; do
    n=$(printf '%s' "$p" | tr - _)_status
    CONFIGS="$CONFIGS par_route_$n par_db_$n"
done
SECRETS="player_ssh_pubkey role_lab_api_password http_interfaces_lab_api role_xlab_password http_xlab_results"
SECRETS="$SECRETS dba_password monitoring_password gm_check_password"
VOLUMES="lab_endpoints lab_apilog lab_home lab_gmstate lab_run par_endpoints par_apilog par_home par_gmstate par_run"
VOLUMES="$VOLUMES db_pgdata db_pgconf db_home db_gmstate db_pglog db_run db_cronspool"
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
LOG=/var/log/api/api.log
DB_PY=/srv/api/db/orders.py
REFUSAL='gm-reload-api: this node is report-only: db/ cannot be changed, so nothing was restarted.'

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-api.XXXXXX")
REFUSE_NAMES="policy override noaccess-override seed secret"

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" >/dev/null 2>&1
    for k in $REFUSE_NAMES; do docker rm -f "${STACK}-refuse-$k" >/dev/null 2>&1; done
    docker stack rm "$STACK" >/dev/null 2>&1
    i=0
    while [ "$i" -lt 60 ] && [ -n "$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")" ]; do
        sleep 1; i=$((i + 1))
    done
    i=0
    while [ "$i" -lt 30 ] && docker network inspect "$NET" >/dev/null 2>&1; do
        sleep 1; i=$((i + 1))
    done
    for v in $VOLUMES; do
        j=0
        while docker volume inspect "${STACK}_$v" >/dev/null 2>&1 && [ "$j" -lt 20 ]; do
            docker volume rm "${STACK}_$v" >/dev/null 2>&1 || sleep 1
            j=$((j + 1))
        done
    done
    for c in $CONFIGS; do docker config rm "${STACK}_$c" >/dev/null 2>&1; done
    for s in $SECRETS; do docker secret rm "${STACK}_$s" >/dev/null 2>&1; done
    rm -rf "${tmp:?}"
    left=$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")
    left="$left$(docker volume ls -q -f "name=${STACK}_")$(docker config ls -q -f "name=${STACK}_")$(docker secret ls -q -f "name=${STACK}_")"
    if [ -n "$left" ]; then
        echo "WARNING: teardown left objects behind: $left"
    else
        info "teardown complete: no container, volume, config or secret left"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi
docker image inspect "$DB_IMAGE" >/dev/null 2>&1 || { echo "image $DB_IMAGE is missing" >&2; exit 2; }

# --- the image, from this worktree ---------------------------------------------
info "building $IMAGE from $BRICK"
docker build -q -t "$IMAGE" "$BRICK" >/dev/null
rc=0; out=$(docker run --rm --entrypoint python3 "$IMAGE" -I -m pip --version 2>&1) || rc=$?
[ "$rc" -ne 0 ] && pass "no pip in the image (python3 -I -m pip: exit $rc)" || fail "pip in the image: $out"
out=$(docker run --rm --entrypoint python3 "$IMAGE" -I -c 'import fastapi, uvicorn, psycopg, starlette, pydantic, yaml
print(fastapi.__version__, uvicorn.__version__, starlette.__version__, pydantic.__version__, psycopg.__version__,
      psycopg.pq.__impl__, psycopg.pq.version(), yaml.__version__)' 2>&1) || true
case $out in
    "0.162.0 0.54.0 1.10.0 2.14.2 3.3.7 python 17"[0-9][0-9][0-9][0-9]" 6.0."*) pass "the image's versions: $out" ;;
    *) fail "the image's versions: $out" ;;
esac

# --- per-game material, as render and gmctl deploy would create it ------------
rand() { head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
for s in role_lab_api_password http_interfaces_lab_api role_xlab_password http_xlab_results dba_password \
         monitoring_password gm_check_password; do
    printf '%s%s' "$(printf '%s' "$s" | cut -c1-4)" "$(rand)" > "$tmp/$s"
done
LABPW=$(cat "$tmp/role_lab_api_password")
LABKEY=$(cat "$tmp/http_interfaces_lab_api")
XLABPW=$(cat "$tmp/role_xlab_password")
XLABKEY=$(cat "$tmp/http_xlab_results")
cp "$FX/partners/api.yaml" "$tmp/par_api.yaml"
for p in $PARTNERS; do
    n=$(printf '%s' "$p" | tr - _)_status
    printf '  %s:\n    hosts: [%s]\n' "$n" "$p" >> "$tmp/par_api.yaml.endpoints"
    sed "s/@NAME@/$n/g" "$FX/partners/routes/status.py.in" > "$tmp/route_$n.py"
    sed "s/@HOST@/$p/g" "$FX/partners/db/status.py.in" > "$tmp/db_$n.py"
done
# the eight endpoints go under endpoints:, before connections:
awk -v extra="$tmp/par_api.yaml.endpoints" '
    /^connections:/ { while ((getline l < extra) > 0) print l }
    { print }' "$tmp/par_api.yaml" > "$tmp/par_api.yaml.new" && mv "$tmp/par_api.yaml.new" "$tmp/par_api.yaml"
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg lab_api_yaml "$FX/lab-api/api.yaml"
cfg lab_route_orders "$FX/lab-api/routes/orders.py"
cfg lab_db_orders "$FX/lab-api/db/orders.py"
cfg nh_script "$NH/node-health.pl"
cfg nh_type "$NH/s6-rc.d/gm-node-health/type"
cfg nh_run "$NH/s6-rc.d/gm-node-health/run"
cfg nh_dep_base "$NH/s6-rc.d/gm-node-health/dependencies.d/base"
cfg nh_bundle "$NH/user-bundles.d/user/contents.d/gm-node-health"
cfg nh_conf_lab "$FX/node-health/lab-api.conf"
cfg par_api_yaml "$tmp/par_api.yaml"
cfg par_route_xlab_results "$FX/partners/routes/xlab_results.py"
cfg par_db_xlab_results "$FX/partners/db/xlab_results.py"
for p in $PARTNERS; do
    n=$(printf '%s' "$p" | tr - _)_status
    cfg "par_route_$n" "$tmp/route_$n.py"
    cfg "par_db_$n" "$tmp/db_$n.py"
done
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql.conf"
cfg seed_pg_hba_conf "$PG_FIXTURES/pg_hba.conf"
cfg db_envelopes "$PG_FIXTURES/envelopes.conf"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
for s in role_lab_api_password http_interfaces_lab_api role_xlab_password http_xlab_results dba_password \
         monitoring_password gm_check_password; do
    docker secret create -l "$LABEL" "${STACK}_$s" "$tmp/$s" >/dev/null
done

info "deploying stack $STACK, db at 0 replicas"
docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1

# From here on, every check records its own result; keep going on failure.
set +e

now() { date -u +%s; }
container() { docker ps -q -f "label=com.docker.swarm.service.name=$1" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy <service> [old-container-id]: prints the healthy container id
    i=0
    while [ "$i" -lt 180 ]; do
        c=$(container "$1")
        if [ -n "$c" ] && [ "$c" != "${2:-}" ] \
           && [ "$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null)" = healthy ]; then
            echo "$c"
            return 0
        fi
        sleep 2; i=$((i + 2))
    done
    return 1
}
wait_log() {  # wait_log <service> <fixed text> <seconds>: the line, once the service's log holds it
    i=0
    while [ "$i" -lt "$3" ]; do
        l=$(docker service logs --raw "$1" 2>/dev/null | grep -F "$2" | tail -n 1)
        [ -n "$l" ] && { echo "$l"; return 0; }
        sleep 1; i=$((i + 1))
    done
    return 1
}

# --- started before its database --------------------------------------------------
if l=$(wait_log "$LAB_SERVICE" "waiting up to 30s for connection hosts to resolve: db" 90); then
    pass "lab-api, started before db, waits for its name: $l"
else
    fail "lab-api did not wait for db"
    docker service logs --tail 30 "$LAB_SERVICE" 2>&1
fi
l=$(wait_log "$PAR_SERVICE" "waiting up to 30s for connection hosts to resolve:" 30) \
    && pass "partners waits too: $l" || fail "partners did not wait for db"
info "scaling db to 1 while they wait"
docker service scale -d "$DB_SERVICE=1" >/dev/null 2>&1
SCALED=$(date -u +%s)
# The wait's outcome, within its bound: db resolves (the server starts at
# once), or the bound passes first (a fresh postgres task's name resolves
# only once the task is healthy, initdb included: Swarm adds a task to the
# service's DNS when its health check passes) and the server starts anyway;
# either way the endpoint then answers once the database is there (below).
if l=$(wait_log "$LAB_SERVICE" "connection hosts resolve after" 45) \
   || l=$(wait_log "$LAB_SERVICE" "connection hosts still unresolved after 30s, starting anyway: db" 5); then
    pass "lab-api: the wait ends within its bound, the server starts: $l"
else
    fail "lab-api: no outcome of the wait within its bound: $(docker service logs --raw "$LAB_SERVICE" 2>&1 | grep '^api: ' | tr '\n' '|')"
fi
if C=$(wait_healthy "$LAB_SERVICE"); then pass "lab-api healthy ($C)"; else
    fail "lab-api did not become healthy"; docker service logs --tail 60 "$LAB_SERVICE" 2>&1; exit 1; fi
if P=$(wait_healthy "$PAR_SERVICE"); then pass "partners healthy ($P)"; else
    fail "partners did not become healthy"; docker service logs --tail 60 "$PAR_SERVICE" 2>&1; exit 1; fi

docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
# hcall <host> <method> <path> [curl args...]: "<status> <body>" from the client, port 8000
hcall() {
    h=$1; m=$2; p=$3; shift 3
    docker exec "$CLIENT" curl -s -m 15 -X "$m" -H "Host: $h" -w ' %{http_code}' "$@" "http://$h:8000$p" 2>/dev/null \
        | awk '{ s = $NF; $NF = ""; sub(/ $/, ""); print s " " $0 }'
}
code() { printf '%s' "$1" | cut -d' ' -f1; }
body() { printf '%s' "$1" | cut -d' ' -f2-; }
pssh() { docker exec -i "$CLIENT" timeout 60 ssh $SSH_OPTS "player@$1" "$2"; }
gm() { docker exec -i "$C" "$@"; }
pgm() { docker exec -i "$P" "$@"; }
LABAUTH="Authorization: Bearer $LABKEY"
XLABAUTH="Authorization: Bearer $XLABKEY"

# Before the database is ready, the endpoint answers 503 (or 200 if it was
# already); once the roles exist, it answers.
r=$(hcall lab-api GET /orders/1 -H "$LABAUTH")
info "before the database's roles exist: $(code "$r") $(body "$r")"
SCALED=${SCALED:-0}
if DB=$(wait_healthy "$DB_SERVICE"); then pass "db (postgres 0.5.0) healthy ($DB), $(( $(now) - SCALED ))s after it was scaled up"; else
    fail "db did not become healthy"; docker service logs --tail 40 "$DB_SERVICE" 2>&1; exit 1; fi
dbq() { docker exec -i -u postgres "$DB" psql -X -q -At -h /run/postgresql -d "${2:-postgres}" -c "$1"; }
docker exec -i -u postgres "$DB" psql -X -q -h /run/postgresql -d postgres -v ON_ERROR_STOP=1 \
    -v lab_api="$LABPW" -v xlab="$XLABPW" < "$FX/db.sql" >/dev/null \
    && pass "db: roles lab_api and xlab, databases lab and partners" || fail "db.sql failed"
ok=; i=0
while [ "$i" -lt 60 ]; do
    r=$(hcall lab-api GET /orders/1 -H "$LABAUTH")
    [ "$(code "$r")" = 200 ] && { ok=1; break; }
    sleep 1; i=$((i + 1))
done
[ -n "$ok" ] && pass "started before its database, it waits and then answers: GET /orders/1 $(body "$r") (${i}s after the roles)" \
    || fail "lab-api never answered GET /orders/1: $r"

# --- the lab's node: credential, role, settings ----------------------------------------
r=$(hcall lab-api GET /orders/1)
[ "$(code "$r")" = 401 ] && [ "$(body "$r")" = '{"detail":"unauthorized"}' ] \
    && pass "no credential: 401 $(body "$r")" || fail "no credential: $r"
r=$(hcall lab-api GET /orders/1 -H "Authorization: Bearer wrong")
[ "$(code "$r")" = 401 ] && pass "a wrong credential: 401" || fail "wrong credential: $r"
r=$(hcall lab-api GET /orders/1 -H "$XLABAUTH")
[ "$(code "$r")" = 401 ] && pass "another endpoint's credential: 401" || fail "other credential: $r"
r=$(hcall lab-api POST /orders -H "Content-Type: application/json" --data-raw '{not json')
[ "$(code "$r")" = 401 ] && pass "an invalid body without the credential: 401, before anything parses it" || fail "invalid body: $r"
r=$(hcall lab-api POST /orders -H "$LABAUTH" -H "Content-Type: application/json" --data-raw '{"id": 3, "label": "third"}')
[ "$(code "$r")" = 201 ] && [ "$(dbq "SELECT label FROM orders WHERE id = 3" lab)" = third ] \
    && pass "POST /orders: 201, the row written" || fail "POST /orders: $r"
r=$(hcall lab-api GET /orders/99 -H "$LABAUTH")
[ "$(code "$r")" = 404 ] && pass "an unknown order: the route's own 404 $(body "$r")" || fail "unknown order: $r"
r=$(hcall lab-api GET '/whoami?owner=42' -H "$LABAUTH")
b=$(body "$r")
case $b in
    *'"user":"lab_api"'*'"session_user":"lab_api"'*'"owner":"42"'*'"timeout":"5s"'*'"superuser":false'*'"definer":"postgres"'*)
        pass "the endpoint connects as its application role, not a superuser; set_config local, SECURITY DEFINER: $b" ;;
    *) fail "whoami: $r" ;;
esac
leak=0
for k in 1 2 3 4; do
    b=$(body "$(hcall lab-api GET "/whoami?owner=x$k" -H "$LABAUTH")")
    case $b in *'"before":null'*|*'"before":""'*) ;; *) leak=1 ;; esac
done
[ "$leak" = 0 ] && pass "the transaction-local setting never outlives its request (four requests, two pooled sessions)" \
    || fail "a transaction-local setting leaked: $b"
s=$(dbq "SELECT count(*), min(application_name) FROM pg_stat_activity WHERE usename = 'lab_api'" lab)
case $s in [12]'|lab-api') pass "pooled sessions as lab_api, application_name lab-api: $s" ;; *) fail "lab_api sessions: $s" ;; esac
lines=$(gm grep ' request ' "$LOG")
printf '%s\n' "$lines" | grep -Eq ' request status=200 ms=[0-9.]+ method=GET host=lab-api endpoint=orders from=[0-9.]+ agent=curl/[^ ]+ path=/orders/1$' \
    && pass "the request log: $(printf '%s\n' "$lines" | grep 'status=200' | head -n 1)" || fail "request log: $(printf '%s\n' "$lines" | head -n 3)"
printf '%s\n' "$lines" | grep -q ' request status=401 .* endpoint=orders ' && pass "the 401s are logged" || fail "no 401 line"

# --- the partners' node: nine hostnames ------------------------------------------------
r=$(hcall xlab POST /results/1 -H "$XLABAUTH")
b=$(body "$r")
case "$(code "$r") $b" in
    '200 {"order":{"id":1,"label":"first"},"lab_api_status":200,"recorded_by":"postgres"}')
        pass "xlab: reads lab-api with its credential, records through SECURITY DEFINER: $b" ;;
    *) fail "xlab POST /results/1: $r" ;;
esac
[ "$(dbq "SELECT order_id, label, by_role FROM results" partners)" = "1|first|xlab" ] \
    && pass "the partner's row, written as xlab" || fail "partners.results: $(dbq 'SELECT * FROM results' partners)"
gm grep -Eq ' request status=200 .* endpoint=orders from=[0-9.]+ agent=partners path=/orders/1$' "$LOG" \
    && pass "lab-api's log names the caller partners (User-Agent)" || fail "no partners line in lab-api's log"
r=$(hcall xlab POST /results/1); [ "$(code "$r")" = 401 ] && pass "xlab without its credential: 401" || fail "xlab no credential: $r"
r=$(hcall xlab POST /results/1 -H "$LABAUTH"); [ "$(code "$r")" = 401 ] && pass "xlab with lab-api's credential: 401" || fail "xlab lab credential: $r"
r=$(hcall xlab GET /status); [ "$(code "$r")" = 404 ] && pass "xlab answers only its own routes: GET /status 404" || fail "xlab /status: $r"
r=$(hcall centre-north POST /results/1 -H "$XLABAUTH"); [ "$(code "$r")" = 404 ] \
    && pass "centre-north answers only its own routes: POST /results/1 404" || fail "centre-north /results: $r"
n=0
for p in $PARTNERS; do
    r=$(hcall "$p" GET /status)
    [ "$r" = "200 {\"partner\":\"$p\",\"ok\":true}" ] && n=$((n + 1)) || fail "$p GET /status: $r"
done
[ "$n" = 8 ] && pass "the eight other hostnames each answer their own public GET /status"
r=$(docker exec "$CLIENT" curl -s -m 5 -o /dev/null -w '%{http_code}' -H 'Host: nowhere' http://partners:8000/status)
[ "$r" = 404 ] && pass "an unknown hostname: 404" || fail "unknown hostname: $r"
r=$(docker exec "$CLIENT" curl -s -m 5 -o /dev/null -w '%{http_code}' http://partners:8000/status)
[ "$r" = 404 ] && pass "the node's own name, which no endpoint lists: 404" || fail "partners by its name: $r"
r=$(hcall lab-api GET /docs -H "$LABAUTH"); [ "$(code "$r")" = 404 ] && pass "no documentation route: /docs 404" || fail "/docs: $r"

# --- player on the lab's node --------------------------------------------------------------
check "player reads routes/orders.py and db/orders.py" pssh lab-api "cat /srv/api/routes/orders.py $DB_PY >/dev/null"
check "player reads the request log" pssh lab-api "tail -n 1 $LOG >/dev/null"
for t in "echo x >> /srv/api/routes/orders.py" "sed -i s/orders/x/ /srv/api/routes/orders.py" \
         "rm -f /srv/api/routes/orders.py" "touch /srv/api/routes/new.py" "echo x >> /srv/api/api.yaml" \
         "cat /run/gm-api/secrets/role_lab_api_password" "cat /opt/gm/secrets/http_interfaces_lab_api"; do
    if pssh lab-api "$t" >/dev/null 2>&1; then fail "player may: $t"; else pass "player may not: $t"; fi
done
check "the route file untouched" sh -c "docker exec $C cmp -s /srv/api/routes/orders.py /opt/gm/seed/routes/orders.py"
out=$(pssh lab-api "ps -eo args; env" 2>&1)
printf '%s' "$out" | grep -qF -e "$LABPW" -e "$LABKEY" && fail "a secret in a process argument or player's environment" \
    || pass "no secret in any process argument or player's environment"
check "the secrets' copies: api only (0400)" sh -c "[ \"\$(docker exec $C stat -c '%U:%G %a' /run/gm-api/secrets/role_lab_api_password /run/gm-api/secrets/http_interfaces_lab_api | sort -u)\" = 'api:api 400' ]"
out=$(pssh lab-api "sudo -n -l" 2>&1)
printf '%s' "$out" | grep -q 'gm-reload-api ""' && printf '%s' "$out" | grep -q 'gm-validate ""' \
    && [ "$(printf '%s\n' "$out" | grep -c '/usr/local/sbin/')" = 1 ] && pass "sudo: exactly gm-reload-api and gm-validate, no arguments" \
    || fail "sudo -l: $out"
if pssh lab-api "sudo -n gm-reload-api now" >/dev/null 2>&1; then fail "sudo gm-reload-api with an argument"; else pass "sudo gm-reload-api refuses an argument"; fi
out=$(pssh lab-api "sudo -n gm-validate" 2>&1); rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^GREEN: api.yaml and its endpoint pairs load (1 endpoint pair(s): orders on lab-api)' \
    && pass "validator green: $out" || fail "validator: exit $rc: $out"
# the edit: a session setting
pssh lab-api "sed -i 's/\"statement_timeout\": \"5s\"/\"statement_timeout\": \"7s\"/' $DB_PY" \
    && pass "player edits db/orders.py with sed -i (statement_timeout 7s)" || fail "player cannot edit db/orders.py"
out=$(pssh lab-api "sudo -n gm-validate" 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q '^RED pending: ' && pass "validator red before the reload: $out" || fail "validator pending: exit $rc: $out"
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -q '^gm-reload-api: restarted the server with api.yaml, routes/ and db/ as they are' \
    && pass "gm-reload-api: $out" || fail "reload: exit $rc: $out"
C=$(container "$LAB_SERVICE")
b=$(body "$(hcall lab-api GET '/whoami?owner=1' -H "$LABAUTH")")
case $b in *'"timeout":"7s"'*) pass "the edited session setting is served: $b" ;; *) fail "after reload: $b" ;; esac
check "db/orders.py back to api:apiconf 0664 after sed -i" sh -c "[ \"\$(docker exec $C stat -c '%U:%G %a' $DB_PY)\" = 'api:apiconf 664' ]"
# broken edits, refused and named; the server keeps answering
pssh lab-api "printf '\ndef broken(:\n' >> $DB_PY"
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'server was NOT restarted' && printf '%s' "$out" | grep -q 'db/orders.py: line [0-9]*: SyntaxError' \
    && pass "a syntax error refused, named: $(printf '%s' "$out" | tr '\n' ' ')" || fail "broken reload: exit $rc: $out"
r=$(hcall lab-api GET /orders/2 -H "$LABAUTH"); [ "$(code "$r")" = 200 ] && pass "the server still answers with the files it loaded" || fail "after a refused reload: $r"
out=$(pssh lab-api "sudo -n gm-validate" 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q '^RED config: ' && pass "validator red: $(printf '%s' "$out" | head -n 1)" || fail "validator config: exit $rc: $out"
pssh lab-api "sed -i '/^def broken(:\$/d' $DB_PY && sed -i 's/^def find(/def find_one(/' $DB_PY"
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'uses find of db/orders.py, which db/orders.py does not define' \
    && pass "a db/ side dropping a function the route calls refused: $(printf '%s' "$out" | tail -n 1)" || fail "dropped function: exit $rc: $out"
pssh lab-api "sed -i 's/^def find_one(/def find(/' $DB_PY && sed -i 's/^import gm_api\$/import gm_api\nimport fastapi/' $DB_PY"
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q 'imports fastapi; a db file imports psycopg, the standard library and gm_api only' \
    && pass "a db/ file importing FastAPI refused" || fail "db importing fastapi: exit $rc: $out"
pssh lab-api "sed -i '/^import fastapi\$/d' $DB_PY"
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 0 ] && pass "fixed, reloaded" || fail "reload after the fix: exit $rc: $out"
C=$(container "$LAB_SERVICE")
out=$(pssh lab-api "sudo -n gm-validate" 2>&1); rc=$?
[ "$rc" = 0 ] && pass "validator green again" || fail "validator after the fix: exit $rc: $out"

# --- the node-health script ---------------------------------------------------------------
ok=; i=0
while [ "$i" -lt 30 ]; do
    docker exec "$CLIENT" curl -fsS -m 5 http://lab-api:9110/metrics 2>/dev/null \
        | grep -q '^node_health_service_up{node="lab-api",service="api"} 1' && { ok=1; break; }
    sleep 2; i=$((i + 2))
done
[ -n "$ok" ] && pass "node-health on lab-api reports the api service up" || fail "node-health: $(docker exec "$CLIENT" curl -sS -m 5 http://lab-api:9110/metrics 2>&1 | grep service_up)"

# --- footprint at rest (no request for 30 s) -------------------------------------------
sleep 30
mem() { echo "$(( $(docker exec "$1" cat /sys/fs/cgroup/memory.current) / 1048576 ))M of $(( $(docker exec "$1" cat /sys/fs/cgroup/memory.max) / 1048576 ))M, server RSS $(( $(docker exec "$1" ps -u api -o rss= | awk '{s += $1} END {print s}') / 1024 ))M"; }
cpu() { docker stats --no-stream --format '{{.CPUPerc}}' "$1"; }
REST_LAB="$(mem "$C"), CPU $(cpu "$C")"
REST_PAR="$(mem "$P"), CPU $(cpu "$P")"
info "footprint at rest: lab-api (one hostname) $REST_LAB; partners (nine hostnames) $REST_PAR"

# --- report-only, then the override ----------------------------------------------------
docker service update --detach --env-add GM_WRITE_POLICY=report-only "$LAB_SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$LAB_SERVICE" "$C"); then C=$C2; pass "lab-api report-only ($C)"; else fail "report-only container"; fi
if pssh lab-api "sed -i 's/7s/9s/' $DB_PY" >/dev/null 2>&1; then fail "report-only: player edited db/orders.py"; else pass "report-only: db/orders.py denied"; fi
out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1); rc=$?
[ "$rc" = 1 ] && [ "$out" = "$REFUSAL" ] && pass "report-only: $out" || fail "report-only reload: exit $rc: $out"
check "report-only: db/ 2755, files 0644" sh -c "[ \"\$(docker exec $C stat -c '%a' /srv/api/db $DB_PY | tr '\n' ' ')\" = '2755 644 ' ]"
docker service update --detach --env-add GM_WRITE_OVERRIDES=/srv/api/db "$LAB_SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$LAB_SERVICE" "$C"); then C=$C2; pass "lab-api report-only with the override of /srv/api/db ($C)"; else fail "override container"; fi
pssh lab-api "sed -i 's/\"statement_timeout\": \"7s\"/\"statement_timeout\": \"9s\"/' $DB_PY" \
    && out=$(pssh lab-api "sudo -n gm-reload-api" 2>&1) \
    && [ "$(body "$(hcall lab-api GET /whoami -H "$LABAUTH")" | grep -c '"timeout":"9s"')" = 1 ] \
    && pass "the override: db/ fixable again, edited and reloaded" || fail "override: $out"

# --- no-access: the partners' node ----------------------------------------------------
if pgm getent passwd player >/dev/null 2>&1; then fail "no-access: a player account"; else pass "no-access: no player account (getent passwd player)"; fi
g=$(pgm getent group apiconf)
case $g in *player*) fail "no-access: player in apiconf: $g" ;; apiconf:*) pass "no-access: apiconf without player ($g)" ;; *) fail "apiconf: $g" ;; esac
if pgm getent group player >/dev/null 2>&1; then fail "no-access: a player group"; else pass "no-access: no player group"; fi
check "no-access: no sudo rules for player" sh -c "! docker exec $P test -e /etc/sudoers.d/gm-player"
if docker exec "$CLIENT" timeout 30 ssh $SSH_OPTS player@partners true >/dev/null 2>&1; then fail "no-access: SSH as player"; else pass "no-access: SSH as player refused"; fi
check "no-access: sshd still runs" sh -c "[ \"\$(docker exec $P /command/s6-svstat -o up /run/service/sshd)\" = true ]"
check "no-access: docker exec -u api works (the GM's plane)" docker exec -u api "$P" true
check "a fixable node keeps its player account" docker exec "$C" getent passwd player

# --- the entrypoint's refusals --------------------------------------------------------------
refuse() {  # refuse <name> <expected text> <docker run args...>
    k=$1; want=$2; shift 2
    out=$(docker run --name "${STACK}-refuse-$k" --rm -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" "$@" "$IMAGE" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want"; then
        pass "the entrypoint refuses: $want (exit $rc)"
    else
        fail "entrypoint $k: exit $rc: $(printf '%s' "$out" | tail -n 3)"
    fi
}
SEED="-v $FX/lab-api/api.yaml:/opt/gm/seed/api.yaml:ro"
refuse policy "gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of" $SEED -e GM_WRITE_POLICY=read-only
refuse override "is not one of this brick's writable_paths" $SEED -e GM_WRITE_POLICY=report-only \
    -e GM_WRITE_OVERRIDES=/srv/api/routes
refuse noaccess-override "a no-access node has no player, so nothing to override" $SEED -e GM_WRITE_POLICY=no-access \
    -e GM_WRITE_OVERRIDES=/srv/api/db
refuse seed "gm-entrypoint: fatal: seed file /opt/gm/seed/api.yaml is missing"
printf 'a\nb\n' > "$tmp/pw_lines"
refuse secret "gm-entrypoint: fatal: secret role_lab_api_password must be a single line" $SEED \
    -v "$tmp/pw_lines:/opt/gm/secrets/role_lab_api_password:ro"

# --- hardening ------------------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
for f in /opt/gm/validator/validate.sh /usr/local/sbin/gm-reload-api /usr/local/lib/python3.13/dist-packages/gm_api/app.py \
         /etc/s6-overlay/s6-rc.d/api/run; do
    check "player cannot write $f" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@lab-api 'echo x >> $f'"
done
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
case $caps in "[ALL]"*) pass "cap_drop ALL ($caps)" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"
check "no secret in a log line" sh -c "! docker exec $C grep -qF -e '$LABPW' -e '$LABKEY' $LOG && ! docker exec $P grep -qF -e '$XLABPW' -e '$XLABKEY' -e '$LABKEY' $LOG && ! docker service logs $LAB_SERVICE 2>&1 | grep -qF '$LABPW'"
info "footprint at rest: lab-api (one hostname) $REST_LAB; partners (nine hostnames) $REST_PAR"
info "disk: lab-api $(gm du -sh /srv/api /var/log/api 2>/dev/null | tr '\t\n' ' '); partners $(pgm du -sh /srv/api /var/log/api 2>/dev/null | tr '\t\n' ' ')"
info "request log: lab-api $(gm sh -c "wc -lc < $LOG") (lines, bytes); partners $(pgm sh -c "wc -lc < $LOG")"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$LAB_SERVICE" 2>&1 || true
exit 1
