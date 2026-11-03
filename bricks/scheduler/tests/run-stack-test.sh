#!/bin/sh
# Stack test of the scheduler brick (v0.3 build plan, chunk 3b, Done when;
# v0.4 build plan, chunk 3b: the transformer node; v0.5 build plan, chunk 4:
# the caller node, the HTTP driver).
#
# Builds the scheduler image and its unit-test stage (the throwaway
# PostgreSQL `db`) from this worktree, deploys them as a Swarm stack
# (stack.test.yml) with seed files and secrets as external configs and
# secrets created here, then checks, from a client container on the
# stack's network (SSH as player, HTTP as another node would) and from
# the GM side (docker exec):
#   - idle at start: no call, status idle, scheduler_running 0;
#   - schedule.yaml unreadable by player and by the service account,
#     visible in listings, on no volume; the role's password in no
#     argument, environment, log or file a player reads;
#   - SSH and the exact sudo wrappers; the validator; owners and modes;
#   - running after the load-started marker (as gmctl start-load does it);
#   - a summary every minute, within ten seconds, a stream at 2 per hour
#     included at calls=0; the metrics endpoint from another node;
#   - a killed program resuming running, its sequence going on; taken
#     down over a timeline change and a job's minute, it comes back with
#     the change applied and the job not replayed;
#   - a job moved by player (sed -i) and reloaded, then run at its new
#     minute; reload refusals for files that do not load or fit;
#   - report-only: edits denied, gm-reload-scheduler's refusal line;
#   - an override of /srv/scheduler/jobs on the report-only node letting
#     player edit jobs.yaml with sed -i and reload it;
#   - the GM check role's secret root-only, and check-sql (root only)
#     reaching the database as gm_check, straight to its port 5432,
#     read-only (spec D185);
#   - a transformer node (v0.4: the same image, `streams: []`, a script
#     key's job naming two connections): idle, then running with no
#     stream; check-runs root only, its answers before any run (no run,
#     no reload, the next run); the job moved by player (sed -i) and
#     reloaded; the run at its new minute, its run and script lines, the
#     row written into `reporting` as bi_etl from `shop` read as shop_etl;
#     check-runs' answers after it (the run since the reload, the last
#     reload, the next run a day later); the validator green;
#   - a caller node (v0.5: the same image, `no-access`, streams on two HTTP
#     connections, one with a credential mounted by hand as http_<name>,
#     spec D347, and a script job on it): no `player` account (SSH
#     refused, no sudo, home root's), sshd up, the GM's exec as scheduler
#     and its validator run working; started before the stub HTTP server,
#     it waits, bounded, for the stub's name (spec D305's lesson), then
#     runs once the stub starts; the stub sees each call's method, path,
#     JSON body (a weighted choice within its share, a builder's body),
#     Host, User-Agent and Authorization; kept-alive connections; the
#     caller counts a 503 and a timeout as errors, logs them with status=,
#     and the token nowhere; the script job's calls (JSON, NDJSON bytes, a
#     503 answer it handles) each an `http` line, counted under
#     `stub.relay/lab`;
#   - the entrypoint's refusals (policy, override, schedule, secrets);
#     read-only root, capabilities, /run a volume; the footprint at rest
#     of the three nodes.
# Real time throughout (about 20 minutes); nothing moves a clock, and no
# job is run by hand: each runs at its time, which player moves.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init). On the build host, run it
# under the host lock:
#   flock /tmp/dbagm-docker.lock sh bricks/scheduler/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BRICK=$(cd "$HERE/.." && pwd)
STACK=gmtest-sched
IMAGE=127.0.0.1:5000/dbagm/scheduler:0.3.0
DB_IMAGE=dbagm-test/scheduler-unit:0.3.0
SERVICE=${STACK}_scheduler
TR_SERVICE=${STACK}_transformer
CL_SERVICE=${STACK}_caller
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
STUB=${STACK}-stub
LABEL=dbagm.test=chunk3-scheduler
CONFIGS="seed_schedule seed_queries seed_builder_report seed_jobs db_init tr_schedule tr_queries tr_script_rollup tr_jobs"
CONFIGS="$CONFIGS cl_schedule cl_queries cl_builder_orders cl_script_relay cl_jobs"
SECRETS="player_ssh_pubkey role_shop_app_password gm_check_password role_shop_etl_password role_bi_etl_password"
SECRETS="$SECRETS http_interfaces_stub"
VOLUMES="sch_repository sch_jobs sch_schedlog sch_schedstate sch_home sch_gmstate sch_run"
VOLUMES="$VOLUMES tr_repository tr_jobs tr_schedlog tr_schedstate tr_home tr_gmstate tr_run"
VOLUMES="$VOLUMES cl_repository cl_jobs cl_schedlog cl_schedstate cl_home cl_gmstate cl_run"
HTTP_SECRET=/opt/gm/secrets/http_interfaces_stub
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
REPO=/srv/scheduler/repository
JOBS=/srv/scheduler/jobs/jobs.yaml
LOG=/var/log/scheduler/scheduler.log
SCHEDULE=/opt/gm/seed/schedule.yaml
SECRET=/opt/gm/secrets/role_shop_app_password
GMC_SECRET=/opt/gm/secrets/gm_check_password
CHECK_SQL=/usr/local/lib/gm/check-sql
CHECK_RUNS=/usr/local/lib/gm/check-runs
REFUSAL='gm-reload-scheduler: this node is report-only: its files cannot be changed, so nothing was reloaded.'

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-sched.XXXXXX")
REFUSE_NAMES="policy override schedule secret"

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" "$STUB" >/dev/null 2>&1
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

# --- the images, from this worktree (capture W1 item 9) ----------------------
info "building $IMAGE and $DB_IMAGE from $BRICK"
docker build -q -t "$IMAGE" "$BRICK" >/dev/null
docker build -q --target unit-test -t "$DB_IMAGE" "$BRICK" >/dev/null

# --- per-game material, as render and gmctl deploy would create it ----------
now() { date -u +%s; }
utc() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minute_of() { date -u -d "@$1" +%Y-%m-%dT%H:%MZ; }
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
printf 'app%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/role_shop_app_password"
APPPW=$(cat "$tmp/role_shop_app_password")
printf 'gmc%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/gm_check_password"
GMCPW=$(cat "$tmp/gm_check_password")
TOKEN="schedule-token-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
# X: the moment of the timeline change and the minute of the job `nightly`,
# about eight minutes after deployment; the test takes the scheduler down
# over it.
X=$(( ($(now) / 60 + 8) * 60 + 20 ))
X_MIN=$(( X / 60 * 60 ))
X_CRON="$(date -u -d "@$X" +%-M) $(date -u -d "@$X" +%-H) * * *"
week=
for d in mon tue wed thu fri sat sun; do
    week="$week      $d: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
"
done
cat > "$tmp/schedule.yaml" <<EOF
# $TOKEN (the test looks for it on the volumes)
seed: 4815162342
intensity: 1.0
connections:
  app:
    driver: sql/postgresql
    target: db:5432/shop
    role: shop_app
    pool: {size: 2}
streams:
  - key: orders.insert
    connection: app
    rate: 2/h
    arrivals: even
  - key: orders.lookup
    connection: app
    rate: 30/min
    arrivals: poisson
    shape: flat
    concurrency: 2
shapes:
  flat:
    utc:
$week
timeline:
  - at: "$(utc "$X")"
    stream: orders.lookup
    set: {key: orders.lookup-v2}
EOF
cat > "$tmp/jobs.yaml" <<EOF
# Stack test fixture of the scheduler brick: the fixed-time operations (UTC).
jobs:
  - name: nightly
    key: reports.daily
    connection: app
    at: "$X_CRON"
  - name: close-day
    key: reports.daily
    connection: app
    at: "0 3 * * *"
EOF
# the transformer node: no stream, one script key's job at 03:05 UTC, moved later by player
for r in shop_etl bi_etl; do
    printf '%s%s' "$r" "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/role_${r}_password"
done
ETLPW=$(cat "$tmp/role_shop_etl_password")
cat > "$tmp/tr_schedule.yaml" <<EOF
seed: 4815162342
intensity: 1.0
connections:
  shop:
    driver: sql/postgresql
    target: db:5432/shop
    role: shop_etl
    pool: {size: 1}
  reporting:
    driver: sql/postgresql
    target: db:5432/reporting
    role: bi_etl
    pool: {size: 1}
streams: []
EOF
cat > "$tmp/tr_queries.yaml" <<EOF
# Stack test fixture of the scheduler brick: a transformer node's repository.
queries:
  rollup.hourly:
    script: scripts/rollup.py:hourly
    options: {into: reporting}
EOF
cat > "$tmp/tr_jobs.yaml" <<EOF
jobs:
  - name: rollup-hourly
    key: rollup.hourly
    connections:
      source: shop
      target: reporting
    at: "5 3 * * *"
EOF
# the caller node (v0.5): streams on two HTTP connections to the stub, one
# with the credential interfaces_stub, the other public with a 1 s timeout
printf 'http%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/http_interfaces_stub"
HTTPTOKEN=$(cat "$tmp/http_interfaces_stub")
cat > "$tmp/cl_schedule.yaml" <<EOF
seed: 4815162342
intensity: 1.0
connections:
  stub:
    driver: http
    target: stub:8080
    credential: interfaces_stub
    pool: 2
  slowstub:
    driver: http
    target: stub:8080
    pool: 1
    timeout: 1s
streams:
  - {key: stub.consent, connection: stub, rate: 30/min, arrivals: even}
  - {key: stub.order, connection: stub, rate: 6/min, arrivals: even}
  - {key: stub.fail, connection: stub, rate: 6/min, arrivals: even}
  - {key: stub.slow, connection: slowstub, rate: 6/min, arrivals: even}
EOF
cat > "$tmp/cl_jobs.yaml" <<EOF
jobs:
  - name: relay
    key: stub.relay
    connections: {lab: stub}
    at: "* * * * *"
EOF
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_schedule "$tmp/schedule.yaml"
cfg seed_queries "$HERE/fixtures/queries.yaml"
cfg seed_builder_report "$HERE/fixtures/builders/report.py"
cfg seed_jobs "$tmp/jobs.yaml"
cfg db_init "$HERE/fixtures/db.sh"
cfg tr_schedule "$tmp/tr_schedule.yaml"
cfg tr_queries "$tmp/tr_queries.yaml"
cfg tr_script_rollup "$HERE/fixtures/scripts/rollup.py"
cfg tr_jobs "$tmp/tr_jobs.yaml"
cfg cl_schedule "$tmp/cl_schedule.yaml"
cfg cl_queries "$HERE/fixtures/caller-queries.yaml"
cfg cl_builder_orders "$HERE/fixtures/builders/orders.py"
cfg cl_script_relay "$HERE/fixtures/scripts/relay.py"
cfg cl_jobs "$tmp/cl_jobs.yaml"
docker secret create -l "$LABEL" "${STACK}_http_interfaces_stub" "$tmp/http_interfaces_stub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_role_shop_app_password" "$tmp/role_shop_app_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_gm_check_password" "$tmp/gm_check_password" >/dev/null
for r in shop_etl bi_etl; do
    docker secret create -l "$LABEL" "${STACK}_role_${r}_password" "$tmp/role_${r}_password" >/dev/null
done

info "deploying stack $STACK (timeline change and job nightly at $(utc "$X"))"
docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1

# From here on, every check records its own result; keep going on failure.
set +e

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
if DB=$(wait_healthy "$DB_SERVICE"); then
    pass "db (throwaway PostgreSQL) healthy ($DB)"
else
    fail "db did not become healthy"
    docker service logs --tail 40 "$DB_SERVICE" 2>&1
    exit 1
fi
if C=$(wait_healthy "$SERVICE"); then
    pass "scheduler deployed and container healthy ($C)"
else
    fail "scheduler did not become healthy"
    docker service ps --no-trunc "$SERVICE"
    docker service logs --tail 60 "$SERVICE" 2>&1
    exit 1
fi

if TC=$(wait_healthy "$TR_SERVICE"); then
    pass "transformer deployed and container healthy ($TC)"
else
    fail "transformer did not become healthy"
    docker service ps --no-trunc "$TR_SERVICE"
    docker service logs --tail 60 "$TR_SERVICE" 2>&1
    exit 1
fi

if CC=$(wait_healthy "$CL_SERVICE"); then
    pass "caller deployed and container healthy ($CC)"
else
    fail "caller did not become healthy"
    docker service ps --no-trunc "$CL_SERVICE"
    docker service logs --tail 60 "$CL_SERVICE" 2>&1
    exit 1
fi

docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@scheduler "$@"; }
gm() { docker exec -i "$C" "$@"; }
dbsql() { docker exec -i "$DB" runuser -u postgres -- psql -X -q -At -d shop -c "$1"; }
log() { gm cat "$LOG"; }
metrics() { docker exec "$CLIENT" curl -fsS -m 10 http://scheduler:9120/metrics; }
status() { gm cat /run/scheduler/status 2>/dev/null; }
prog_pid() { gm ps -u scheduler -o pid=,args= | awk '$2 == "/usr/bin/python3" { print $1; exit }'; }
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
wait_until() { t=$1; while [ "$(now)" -lt "$t" ]; do sleep 1; done; }
wait_status() {  # wait_status <word> [seconds] [old status]: until the status file begins
    i=0             # with <word> and differs from [old status]
    while [ "$i" -lt "${2:-60}" ]; do
        s=$(status)
        case $s in "$1 "*) [ "$s" != "${3:-}" ] && return 0 ;; esac
        sleep 1; i=$((i + 1))
    done
    return 1
}
mem() { echo "$(( $(gm cat /sys/fs/cgroup/memory.current) / 1048576 ))M of $(( $(gm cat /sys/fs/cgroup/memory.max) / 1048576 ))M, program RSS $(( $(gm ps -o rss= -p "$(prog_pid)" | tr -d ' ') / 1024 ))M"; }

# the transformer node
tgm() { docker exec -i "$TC" "$@"; }
tssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@transformer "$@"; }
tlog() { tgm cat "$LOG"; }
tstatus() { tgm cat /run/scheduler/status 2>/dev/null; }
tprog_pid() { tgm ps -u scheduler -o pid=,args= | awk '$2 == "/usr/bin/python3" { print $1; exit }'; }
tmem() { echo "$(( $(tgm cat /sys/fs/cgroup/memory.current) / 1048576 ))M of $(( $(tgm cat /sys/fs/cgroup/memory.max) / 1048576 ))M, program RSS $(( $(tgm ps -o rss= -p "$(tprog_pid)" | tr -d ' ') / 1024 ))M"; }
rsql() { docker exec -i "$DB" runuser -u postgres -- psql -X -q -At -d reporting -c "$1"; }

# the caller node (v0.5)
cgm() { docker exec -i "$CC" "$@"; }
clog() { cgm cat "$LOG"; }
cstatus() { cgm cat /run/scheduler/status 2>/dev/null; }
cprog_pid() { cgm ps -u scheduler -o pid=,args= | awk '$2 == "/usr/bin/python3" { print $1; exit }'; }
cmem() { echo "$(( $(cgm cat /sys/fs/cgroup/memory.current) / 1048576 ))M of $(( $(cgm cat /sys/fs/cgroup/memory.max) / 1048576 ))M, program RSS $(( $(cgm ps -o rss= -p "$(cprog_pid)" | tr -d ' ') / 1024 ))M"; }
stubreqs() { docker logs "$STUB" 2>&1 | sed -n 's/^REQ //p'; }

# --- idle at start --------------------------------------------------------------
u=$(gm ps -o user= -p "$(prog_pid)" | tr -d ' ')
[ "$u" = scheduler ] && pass "the program runs as scheduler" || fail "program user: [$u]"
case $(status) in idle\ *) pass "status: $(status)" ;; *) fail "status at start: [$(status)]" ;; esac
check "log: state=idle" sh -c "docker exec $C cat $LOG | grep -q ' state state=idle$'"
m=$(metrics)
printf '%s\n' "$m" | grep -qx 'scheduler_running 0' && pass "metrics from another node: scheduler_running 0" \
    || fail "metrics at start: $(printf '%s\n' "$m" | grep running)"
printf '%s\n' "$m" | grep -qx 'scheduler_calls_total{key="orders.lookup"} 0' \
    && pass "every key's series exists at 0" || fail "series at start"
sleep 5
n=$(dbsql "SELECT count(*) FROM orders")
[ "$n" = 0 ] && pass "idle: no call reached the database" || fail "idle: $n rows"
REST_IDLE=$(mem)
info "footprint at rest, idle: $REST_IDLE"
case $(tstatus) in idle\ *) pass "transformer status: $(tstatus)" ;; *) fail "transformer status at start: [$(tstatus)]" ;; esac
TR_IDLE=$(tmem)
info "transformer footprint at rest, idle: $TR_IDLE"

# --- the caller: HTTP connections, started before the stub (v0.5) -------------------
case $(cstatus) in idle\ *) pass "caller status: $(cstatus)" ;; *) fail "caller status at start: [$(cstatus)]" ;; esac
CL_IDLE=$(cmem)
info "caller footprint at rest, idle: $CL_IDLE"
st=$(cgm stat -c '%u:%g %a' "$HTTP_SECRET")
[ "$st" = "0:0 400" ] && pass "the HTTP credential's secret is 0:0 0400" || fail "$HTTP_SECRET: $st"
check "the service account cannot read the HTTP credential" sh -c "! docker exec -u scheduler $CC cat $HTTP_SECRET"
check "the stub's name does not resolve yet" sh -c "! docker exec $CC getent hosts stub"
# no-access (v0.5, master spec 10.2): no player account, sshd kept
check "no-access: no player account" sh -c "! docker exec $CC getent passwd player && ! docker exec $CC id player"
g=$(cgm getent group schedconf)
[ "$g" = "schedconf:x:994:" ] && pass "no-access: schedconf has no member ($g)" || fail "no-access: schedconf [$g]"
check "no-access: /run/gm/write-policy says no-access" sh -c "docker exec $CC cat /run/gm/write-policy | grep -qx policy=no-access"
[ "$(cgm /command/s6-svstat -o up /run/service/sshd)" = true ] && pass "no-access: sshd runs" || fail "no-access: sshd not up"
check "no-access: SSH as player refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@caller true"
m=$(cgm stat -c '%U:%G %a' /home/player)
[ "$m" = "root:root 700" ] && pass "no-access: the home volume is root's ($m)" || fail "no-access home: $m"
m=$(cgm stat -c '%a %U:%G' "$REPO" "$REPO/queries.yaml" "$REPO/scripts/relay.py" /srv/scheduler/jobs "$JOBS" | tr '\n' ' ')
[ "$m" = "2755 scheduler:schedconf 644 scheduler:schedconf 644 scheduler:schedconf 2755 scheduler:schedconf 644 scheduler:schedconf " ] \
    && pass "no-access: files as report-only ($m)" || fail "no-access modes: $m"
u=$(docker exec -u scheduler "$CC" id -un 2>&1)
[ "$u" = scheduler ] && pass "no-access: the GM's exec as scheduler resolves the account" || fail "exec -u scheduler: [$u]"
out=$(docker exec -u scheduler "$CC" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "no-access: the GM's validator run as scheduler is green ($out)" || fail "caller validator: exit $rc: $out"
u=$(cgm ps -o user= -p "$(cprog_pid)" | tr -d ' ')
[ "$u" = scheduler ] && pass "no-access: the program runs as scheduler" || fail "caller program user: [$u]"
CT0=$(utc "$(now)")
cgm sh -c "printf '%s\n' '$CT0' > /var/lib/gm-state/.load-started.tmp && chown root:scheduler /var/lib/gm-state/.load-started.tmp \
    && chmod 0440 /var/lib/gm-state/.load-started.tmp && mv /var/lib/gm-state/.load-started.tmp /var/lib/gm-state/load-started \
    && /command/s6-svc -r /run/service/scheduler"
i=0
while [ "$i" -lt 30 ] && ! clog | grep -q ' wait status=waiting bound=30s connections=slowstub,stub$'; do sleep 1; i=$((i + 1)); done
w=$(clog | grep ' wait status=waiting ' | tail -n 1)
[ -n "$w" ] && pass "the caller waits, bounded, for its targets' names: $w" || fail "no wait line: $(clog | tail -n 3 | tr '\n' '|')"
sleep 4
[ -z "$(cstatus)" ] && ! clog | grep -q " state state=running " \
    && pass "not running while it waits (no status, no running line)" || fail "running before the stub: [$(cstatus)]"
docker run -d --name "$STUB" --network "$NET" --network-alias stub -v "$HERE/fixtures/stub.py:/opt/stub.py:ro" \
    --entrypoint python3 "$DB_IMAGE" -I /opt/stub.py >/dev/null
info "stub started at $(utc "$(now)")"
i=0
while [ "$i" -lt 45 ]; do case $(cstatus) in running\ *) break ;; esac; sleep 1; i=$((i + 1)); done
r=$(clog | grep ' wait status=resolved ' | tail -n 1)
ms=$(printf '%s' "$r" | sed -n 's/.* ms=\([0-9]*\) .*/\1/p')
case $(cstatus) in
    running\ *) [ "${ms:-0}" -ge 5000 ] && [ "${ms:-0}" -le 30000 ] \
                    && pass "the names resolved once the stub started, then running ($r; $(cstatus))" \
                    || fail "wait: [$r], status [$(cstatus)]" ;;
    *) fail "the caller is not running after the stub started: [$(cstatus)] $(clog | tail -n 3 | tr '\n' '|')" ;;
esac
check "log: caller state=running t0=$CT0" sh -c "docker exec $CC cat $LOG | grep -q ' state state=running t0=$CT0$'"

# --- the schedule: never readable but by root, on no volume ----------------------
st=$(gm stat -c '%u:%g %a' "$SCHEDULE")
[ "$st" = "0:0 400" ] && pass "$SCHEDULE is 0:0 0400" || fail "$SCHEDULE: $st"
check "player sees schedule.yaml in a listing" pssh "ls -l $SCHEDULE"
denied "player cannot read schedule.yaml" cat "$SCHEDULE"
check "the service account cannot read schedule.yaml" sh -c "! docker exec -u scheduler $C cat $SCHEDULE"
check "the schedule is on no volume" sh -c "! docker exec $C grep -rqF -D skip $TOKEN /srv /var/log/scheduler /var/lib/scheduler /var/lib/gm-state /home/player /run"
pid=$(prog_pid)
check "the password is not in the program's arguments" sh -c "! docker exec $C cat /proc/$pid/cmdline | tr '\\0' '\\n' | grep -qF '$APPPW'"
env_=$(docker exec --privileged "$C" cat "/proc/$pid/environ" | tr '\0' '\n')
if [ -n "$env_" ] && ! printf '%s\n' "$env_" | grep -qF "$APPPW"; then
    pass "the password is not in the program's environment ($(printf '%s\n' "$env_" | cut -d= -f1 | tr '\n' ' '))"
else
    fail "the program's environment: $(printf '%s\n' "$env_" | cut -d= -f1 | tr '\n' ' ')"
fi
denied "player cannot read the program's environment" cat "/proc/$pid/environ"
denied "player cannot read the role's secret" cat "$SECRET"
check "the service account cannot read the role's secret" sh -c "! docker exec -u scheduler $C cat $SECRET"

# --- the GM check role's secret and check-sql (spec D185) ---------------------------
st=$(gm stat -c '%u:%g %a' "$GMC_SECRET" "$CHECK_SQL" | tr '\n' ' ')
[ "$st" = "0:0 400 0:0 700 " ] && pass "gm_check_password 0:0 0400, check-sql 0:0 0700" || fail "gm_check_password, check-sql: $st"
denied "player cannot read gm_check_password" cat "$GMC_SECRET"
denied "player cannot run check-sql" "$CHECK_SQL" -h db -d shop
check "the service account cannot read gm_check_password" sh -c "! docker exec -u scheduler $C cat $GMC_SECRET"
check "the service account cannot run check-sql" sh -c "! echo 'SELECT 1' | docker exec -i -u scheduler $C $CHECK_SQL -h db -d shop"
check "the program got no gm_check password" sh -c "! docker exec $C grep -rqF -D skip '$GMCPW' /proc/$(prog_pid)/cmdline /srv /var/log/scheduler /var/lib/scheduler /run/scheduler /home/player"
out=$(printf 'SELECT current_user, inet_server_port(), count(*) FROM products\n' | gm "$CHECK_SQL" -h db -d shop 2>&1)
[ "$out" = "gm_check|5432|300" ] && pass "check-sql: as gm_check, straight to db:5432 ($out)" || fail "check-sql: [$out]"
out=$(printf 'SELECT count(*) FROM {t} WHERE {c} <= %%(n)s::int\n' | gm "$CHECK_SQL" -h db -p 5432 -d shop -i t=public.products -i c=id -v n=10 2>&1)
[ "$out" = 10 ] && pass "check-sql: -i identifiers and -v values bound ($out)" || fail "check-sql -i, -v: [$out]"
out=$(printf 'INSERT INTO reports (n) VALUES (1)\n' | gm "$CHECK_SQL" -h db -d shop 2>&1); rc=$?
[ "$rc" = 1 ] && printf '%s' "$out" | grep -q '^check-sql: 25006 ' \
    && pass "check-sql: read-only, a write fails with exit 1 ($out)" || fail "check-sql write: exit $rc: $out"
out=$(printf 'SELECT 1\n' | gm "$CHECK_SQL" -h db -d nosuchdb 2>&1); rc=$?
[ "$rc" = 2 ] && pass "check-sql: a connection refused exits 2 ($out)" || fail "check-sql refused: exit $rc: $out"

# --- SSH, sudo, validator, owners and modes ----------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@scheduler true"
allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-scheduler "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the two wrappers, no arguments" || fail "sudo -l: [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@scheduler sudo -n /bin/sh -c true"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@scheduler sudo -n /usr/local/sbin/gm-validate x"
check "sudo refuses -u scheduler" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@scheduler sudo -n -u scheduler /usr/local/sbin/gm-validate"
check "player reads the log" pssh "grep -q 'state state=idle' $LOG"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^GREEN: .*is idle'; then
    pass "gm-validate green while idle ($out)"
else
    fail "gm-validate idle: exit $rc: $out"
fi
out=$(docker exec -u scheduler "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as scheduler green" || fail "GM validator: exit $rc: $out"
modes() { gm stat -c '%a %U:%G' "$REPO" "$REPO/queries.yaml" "$REPO/builders" "$REPO/builders/report.py" \
    /srv/scheduler/jobs "$JOBS" | tr '\n' ' '; }
m=$(modes)
want="2775 scheduler:schedconf 664 scheduler:schedconf 2775 scheduler:schedconf 664 scheduler:schedconf 2775 scheduler:schedconf 664 scheduler:schedconf "
[ "$m" = "$want" ] && pass "fixable: owners and modes ($m)" || fail "fixable modes: $m"
m=$(gm stat -c '%a %U:%G' /var/log/scheduler "$LOG" /var/lib/scheduler /var/lib/gm-state /var/lib/gm-state/.gm-seeded /home/player | tr '\n' ' ')
[ "$m" = "2750 scheduler:schedconf 640 scheduler:schedconf 750 scheduler:scheduler 755 root:root 444 root:root 750 player:player " ] \
    && pass "log, state, markers, home ($m)" || fail "log, state, markers, home: $m"
check "/run/gm/write-policy says fixable" sh -c "docker exec $C cat /run/gm/write-policy | grep -qx policy=fixable"
denied "player cannot read /run/gm/write-policy" cat /run/gm/write-policy
denied "player cannot create a file next to the markers" touch /var/lib/gm-state/load-started

# --- running after the load-started marker (as gmctl start-load does it) --------
T0=$(utc "$(now)")
gm sh -c "printf '%s\n' '$T0' > /var/lib/gm-state/.load-started.tmp && chown root:scheduler /var/lib/gm-state/.load-started.tmp \
    && chmod 0440 /var/lib/gm-state/.load-started.tmp && mv /var/lib/gm-state/.load-started.tmp /var/lib/gm-state/load-started \
    && /command/s6-svc -r /run/service/scheduler"
if wait_status running 60 "$(status)"; then
    pass "running after the marker and an s6 restart ($(status))"
else
    fail "not running after the marker: [$(status)]"
fi
RUN_START=$(now)
check "log: state=running t0=$T0" sh -c "docker exec $C cat $LOG | grep -q ' state state=running t0=$T0$'"
m=$(gm stat -c '%a %U:%G' /var/lib/gm-state/load-started)
[ "$m" = "440 root:scheduler" ] && pass "load-started marker root:scheduler 0440" || fail "marker: $m"

# --- a summary every minute, a stream at 2 per hour included ------------------------
B1=$(( RUN_START / 60 * 60 + 60 ))
B2=$(( B1 + 60 ))
info "waiting for the summaries of $(minute_of $((B1 - 60))) and $(minute_of "$B1") (until $(utc $((B2 + 12))))"
wait_until $((B2 + 12))
L=$(log)
for b in $B1 $B2; do
    mm=$(minute_of $((b - 60)))
    line=$(printf '%s\n' "$L" | grep " summary minute=$mm " | head -n 1)
    if [ -n "$line" ]; then
        at=$(date -u -d "$(printf '%s' "$line" | cut -c1-20 | sed 's/T/ /; s/Z//')" +%s)
        late=$((at - b))
        [ "$late" -ge 0 ] && [ "$late" -le 10 ] && pass "summary for $mm written ${late}s after the minute ($line)" \
            || fail "summary for $mm written ${late}s after the minute"
    else
        fail "no summary for $mm"
    fi
    k=$(printf '%s\n' "$L" | grep " key minute=$mm key=orders.insert ")
    printf '%s' "$k" | grep -q 'calls=0 errors=0 p50_ms=- p95_ms=- p99_ms=-$' \
        && pass "the 2-per-hour stream has its key line at calls=0 in $mm" || fail "2/h key line in $mm: [$k]"
done
k=$(printf '%s\n' "$L" | grep " key minute=$(minute_of "$B1") key=orders.lookup ")
printf '%s' "$k" | grep -Eq 'calls=[1-9][0-9]* errors=0 p50_ms=[0-9.]+ ' \
    && pass "the 30-per-minute stream: $k" || fail "orders.lookup key line: [$k]"
check "the log names no rate and no shape" sh -c "! docker exec $C cat $LOG | grep -Eq 'rate|flat|30/min|2/h'"
m=$(metrics)
printf '%s\n' "$m" | grep -qx 'scheduler_running 1' && pass "metrics: scheduler_running 1" || fail "metrics running"
c=$(printf '%s\n' "$m" | sed -n 's/^scheduler_calls_total{key="orders.lookup"} \([0-9]*\)$/\1/p')
[ "${c:-0}" -gt 0 ] && pass "metrics: scheduler_calls_total{key=\"orders.lookup\"} $c" || fail "calls_total: [$c]"
printf '%s\n' "$m" | grep -q '^scheduler_call_duration_seconds_bucket{key="orders.lookup",le="+Inf"} ' \
    && pass "metrics: latency histogram per key" || fail "histogram"
n=$(dbsql "SELECT count(*) FROM orders WHERE order_no >= 1000000")
[ "$n" -gt 0 ] && pass "the stream's inserts reach the database ($n rows)" || fail "no rows"
REST_RUN=$(mem)
info "footprint running at 30 calls a minute: $REST_RUN"

# --- a killed program resumes running, its sequence goes on ------------------------
pid=$(prog_pid)
st0=$(status)
max0=$(dbsql "SELECT max(order_no) FROM orders")
gm kill -KILL "$pid"
i=0
while [ "$i" -lt 30 ]; do
    sleep 1; i=$((i + 1))
    p2=$(prog_pid)
    [ -n "$p2" ] && [ "$p2" != "$pid" ] && break
done
if [ -n "$p2" ] && [ "$p2" != "$pid" ] && wait_status running 30 "$st0" \
   && [ "$(log | grep -c ' state state=running ')" -eq 2 ]; then
    pass "killed (SIGKILL), the program came back running ($(status))"
else
    fail "after a kill: pid [$p2], status [$(status)]"
fi
sleep 20
n=$(dbsql "SELECT min(order_no) FROM orders WHERE order_no > $max0")
[ "${n:-0}" -ge 1001000 ] && pass "the sequence went on at its next block ($max0 then $n), no value reused" \
    || fail "sequence after the kill: max before $max0, next [$n]"
check "no duplicate key error in the log" sh -c "! docker exec $C cat $LOG | grep -q sqlstate=23505"

# --- down over a timeline change and a job's minute: nothing replayed ----------------
if [ "$(now)" -gt $((X - 30)) ]; then
    fail "too slow: the down window around $(utc "$X") is already gone"
else
    wait_until $((X - 30))
    gm /command/s6-svc -wD -T 20000 -d /run/service/scheduler
    info "scheduler down at $(utc "$(now)") over $(utc "$X") (the change, the job nightly's minute)"
    st0=$(status)
    wait_until $((X_MIN + 75))
    gm /command/s6-svc -wu -T 20000 -u /run/service/scheduler
    if wait_status running 30 "$st0"; then pass "back up after the window ($(status))"; else fail "not running after the window: [$(status)]"; fi
    B=$(( $(now) / 60 * 60 + 60 ))
    wait_until $((B + 12))
    L=$(log)
    mm=$(minute_of $((B - 60)))
    if printf '%s\n' "$L" | grep -q " key minute=$mm key=orders.lookup-v2 calls=[1-9]" \
       && ! printf '%s\n' "$L" | grep -q " key minute=$mm key=orders.lookup "; then
        pass "the timeline change that passed while down is applied: orders.lookup-v2 in $mm"
    else
        fail "timeline after the window: $(printf '%s\n' "$L" | grep " minute=$mm" | tr '\n' '|')"
    fi
    if printf '%s\n' "$L" | grep -q ' job=nightly '; then
        fail "the job nightly ran or was logged after the window: $(printf '%s\n' "$L" | grep ' job=nightly ' | tr '\n' '|')"
    else
        pass "the job nightly, due while down, was not replayed"
    fi
    s=$(printf '%s\n' "$L" | grep -c " summary minute=$(minute_of "$X_MIN") ")
    [ "$s" -eq 0 ] && pass "no summary for $(minute_of "$X_MIN"), a minute down (an outage minute)" || fail "summary while down"
fi

# --- a job moved by player and reloaded --------------------------------------------
J=$(( $(now) / 60 * 60 + 120 ))
cron="$(date -u -d "@$J" +%-M) $(date -u -d "@$J" +%-H) \* \* \*"
pssh "sed -i 's/^    at: \"0 3 \\* \\* \\*\"/    at: \"$cron\"/' $JOBS" && pass "player moves close-day to $(utc "$J") with sed -i" \
    || fail "player cannot edit jobs.yaml"
o=$(gm stat -c '%U' "$JOBS")
info "jobs.yaml after sed -i belongs to $o"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED pending: .*jobs.yaml changed' \
    && pass "validator red on the edit not yet reloaded ($out)" || fail "pending: exit $rc: $out"
out=$(pssh sudo -n gm-reload-scheduler 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "close-day: next run $(utc "$J")"; then
    pass "gm-reload-scheduler (exit 0: $(printf '%s' "$out" | tr '\n' ' '))"
else
    fail "gm-reload-scheduler: exit $rc: $out"
fi
m=$(gm stat -c '%a %U:%G' "$JOBS")
[ "$m" = "664 scheduler:schedconf" ] && pass "the wrapper restored jobs.yaml's owner and mode ($o -> $m)" || fail "after reload: $m"
check "log: reload status=ok" sh -c "docker exec $C cat $LOG | grep -q ' reload status=ok keys=4 jobs=2$'"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green after the reload" || fail "after reload: exit $rc: $out"
wait_until $((J + 15))
L=$(log)
if printf '%s\n' "$L" | grep -q "^$(minute_of "$J" | sed 's/Z$//'):0[0-9]Z run job=close-day key=reports.daily phase=start$" \
   && printf '%s\n' "$L" | grep -q ' run job=close-day key=reports.daily phase=end status=ok rows=1 ms='; then
    pass "the moved job ran at its new minute: $(printf '%s\n' "$L" | grep ' run job=close-day' | tr '\n' '|')"
else
    fail "the moved job did not run at $(utc "$J"): $(printf '%s\n' "$L" | grep ' job=close-day' | tr '\n' '|')"
fi
n=$(dbsql "SELECT count(*) FROM reports")
[ "$n" = 1 ] && pass "its builder's statement reached the database (reports: $n)" || fail "reports: $n"

# --- reload refusals: files that do not load or do not fit the schedule --------------
pssh "cp $REPO/queries.yaml ~/queries.good && sed -i 's/^  orders.lookup-v2:/  orders.renamed:/' $REPO/queries.yaml"
gen0=$(gm sed -n 's/^generation=//p' /run/scheduler/loaded)
out=$(pssh sudo -n gm-reload-scheduler 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT reloaded' \
   && printf '%s' "$out" | grep -q 'key orders.lookup-v2 is named by the schedule but is missing' \
   && ! printf '%s' "$out" | grep -Eq '30/min|poisson|flat|db:5432'; then
    pass "refused: a key the schedule names is missing, naming only the key"
else
    fail "missing key: exit $rc: $out"
fi
pssh "cp ~/queries.good $REPO/queries.yaml && printf 'jobs: [\n' >> $JOBS"
out=$(pssh sudo -n gm-reload-scheduler 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'do not load; the scheduler was NOT reloaded' \
    && pass "refused: jobs.yaml does not parse ($(printf '%s' "$out" | tail -n 1))" || fail "bad yaml: exit $rc: $out"
[ "$(gm sed -n 's/^generation=//p' /run/scheduler/loaded)" = "$gen0" ] && case $(status) in running*) true ;; *) false ;; esac \
    && pass "nothing reloaded, the scheduler keeps running" || fail "after refusals"
pssh "sed -i '\$d' $JOBS"
pssh sudo -n gm-reload-scheduler >/dev/null 2>&1 && pass "fixed and reloaded" || fail "reload after the fix"

# --- report-only ------------------------------------------------------------------------
info "redeploying the node report-only (GM_WRITE_POLICY=report-only)"
docker service update --detach --env-add GM_WRITE_POLICY=report-only "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "report-only container healthy ($C)"; else fail "report-only container"; fi
wait_status running 30 && check "the new container's program says it resumed" \
    sh -c "docker exec $C cat $LOG | tail -n 20 | grep -q ' state state=running t0=$T0$'" \
    && pass "a new container resumes running ($(status))" || fail "new container: [$(status)]"
m=$(modes)
want="2755 scheduler:schedconf 644 scheduler:schedconf 2755 scheduler:schedconf 644 scheduler:schedconf 2755 scheduler:schedconf 644 scheduler:schedconf "
[ "$m" = "$want" ] && pass "report-only: owners and modes ($m)" || fail "report-only modes: $m"
denied "report-only: player cannot sed -i jobs.yaml" "sed -i 's/close-day/x/' $JOBS"
denied "report-only: player cannot append to queries.yaml" "echo '# x' >> $REPO/queries.yaml"
denied "report-only: player cannot create a builder" "touch $REPO/builders/x.py"
gen0=$(gm sed -n 's/^generation=//p' /run/scheduler/loaded)
out=$(pssh sudo -n gm-reload-scheduler 2>&1); rc=$?
[ "$rc" -eq 1 ] && [ "$out" = "$REFUSAL" ] && pass "gm-reload-scheduler refuses: $out" || fail "report-only reload: exit $rc: $out"
[ "$(gm sed -n 's/^generation=//p' /run/scheduler/loaded)" = "$gen0" ] && pass "nothing signalled" || fail "reloaded anyway"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate is never refused (green)" || fail "validate report-only: exit $rc: $out"

# --- an override of /srv/scheduler/jobs on the report-only node ----------------------------
info "redeploying with GM_WRITE_OVERRIDES=/srv/scheduler/jobs"
docker service update --detach --env-add GM_WRITE_OVERRIDES=/srv/scheduler/jobs "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "override container healthy ($C)"; else fail "override container"; fi
m=$(modes)
want="2755 scheduler:schedconf 644 scheduler:schedconf 2755 scheduler:schedconf 644 scheduler:schedconf 2775 scheduler:schedconf 664 scheduler:schedconf "
[ "$m" = "$want" ] && pass "override: jobs fixable, repository not ($m)" || fail "override modes: $m"
check "/run/gm/write-policy names the override" sh -c "docker exec $C cat /run/gm/write-policy | grep -qx overrides=/srv/scheduler/jobs"
J2=$(( $(now) / 60 * 60 + 600 ))
cron2="$(date -u -d "@$J2" +%-M) $(date -u -d "@$J2" +%-H) \* \* \*"
pssh "sed -i 's/^    at: \"$cron\"/    at: \"$cron2\"/' $JOBS" && pass "override: player edits jobs.yaml with sed -i" \
    || fail "override: sed -i on jobs.yaml"
out=$(pssh sudo -n gm-reload-scheduler 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "close-day: next run $(utc "$J2")" \
    && pass "override: gm-reload-scheduler reloads it (close-day next $(utc "$J2"))" || fail "override reload: exit $rc: $out"
m=$(gm stat -c '%a %U:%G' "$JOBS")
[ "$m" = "664 scheduler:schedconf" ] && pass "override: owner and mode restored ($m)" || fail "override after reload: $m"
denied "override: queries.yaml still not writable" "echo '# x' >> $REPO/queries.yaml"

# --- the transformer node: a script job between two databases, no stream ----------------------
st=$(tgm stat -c '%u:%g %a' "$CHECK_RUNS")
[ "$st" = "0:0 700" ] && pass "check-runs is 0:0 0700" || fail "check-runs: $st"
check "player cannot run check-runs" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@transformer $CHECK_RUNS last-reload"
check "the service account cannot run check-runs" sh -c "! docker exec -u scheduler $TC $CHECK_RUNS last-reload"
m=$(tgm stat -c '%a %U:%G' "$REPO/scripts" "$REPO/scripts/rollup.py" | tr '\n' ' ')
[ "$m" = "2775 scheduler:schedconf 664 scheduler:schedconf " ] && pass "scripts/ seeded, fixable ($m)" \
    || fail "scripts/ modes: $m"
check "player reads the transformer's script" tssh "grep -q '^def hourly(conns, options, log):' $REPO/scripts/rollup.py"
check "loaded: the script's digest" sh -c "docker exec $TC cat /run/scheduler/loaded | grep -Eq '^file [0-9a-f]{64} $REPO/scripts/rollup.py\$'"
TT0=$(utc "$(now)")
tgm sh -c "printf '%s\n' '$TT0' > /var/lib/gm-state/.load-started.tmp && chown root:scheduler /var/lib/gm-state/.load-started.tmp \
    && chmod 0440 /var/lib/gm-state/.load-started.tmp && mv /var/lib/gm-state/.load-started.tmp /var/lib/gm-state/load-started \
    && /command/s6-svc -r /run/service/scheduler"
i=0; st0=
while [ "$i" -lt 60 ]; do case $(tstatus) in running\ *) st0=$(tstatus); break ;; esac; sleep 1; i=$((i + 1)); done
if [ -n "$st0" ] && tlog | grep -q " state state=running t0=$TT0$"; then
    pass "the transformer runs with no stream ($st0)"
else
    fail "transformer not running: [$(tstatus)]"
fi
out=$(tgm "$CHECK_RUNS" runs rollup-hourly "$TT0" 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && pass "check-runs runs: none yet" || fail "check-runs runs before any: exit $rc: $out"
out=$(tgm "$CHECK_RUNS" last-reload 2>&1); rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && pass "check-runs last-reload: none yet" || fail "check-runs last-reload: exit $rc: $out"
out=$(tgm "$CHECK_RUNS" since "$TT0" 2>&1)
[ "$out" = "$TT0" ] && pass "check-runs since: the moment itself without a reload ($out)" || fail "check-runs since: [$out]"
out=$(tgm "$CHECK_RUNS" next rollup-hourly 2>&1)
printf '%s' "$out" | grep -Eq '^[0-9-]{10}T03:05:00Z remaining=[0-9]+$' && pass "check-runs next: $out" \
    || fail "check-runs next before the move: [$out]"
out=$(tgm "$CHECK_RUNS" next no-such-job 2>&1); rc=$?
[ "$rc" = 1 ] && pass "check-runs next: an unknown job exits 1 ($out)" || fail "check-runs next unknown: exit $rc: $out"
out=$(tgm "$CHECK_RUNS" runs rollup-hourly yesterday 2>&1); rc=$?
[ "$rc" = 2 ] && pass "check-runs: a moment not an instant exits 2 ($out)" || fail "check-runs bad since: exit $rc: $out"
TJ=$(( $(now) / 60 * 60 + 120 ))
tcron="$(date -u -d "@$TJ" +%-M) $(date -u -d "@$TJ" +%-H) \* \* \*"
tssh "sed -i 's/^    at: \"5 3 \\* \\* \\*\"/    at: \"$tcron\"/' $JOBS" && pass "player moves rollup-hourly to $(utc "$TJ") with sed -i" \
    || fail "player cannot edit the transformer's jobs.yaml"
out=$(tssh sudo -n gm-reload-scheduler 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "rollup-hourly: next run $(utc "$TJ")" \
    && pass "transformer: gm-reload-scheduler ($(printf '%s' "$out" | tr '\n' ' '))" || fail "transformer reload: exit $rc: $out"
R=$(tgm "$CHECK_RUNS" last-reload 2>&1)
lr=$(tlog | sed -n 's/^\([^ ]*\) reload status=ok .*/\1/p' | tail -n 1)
[ -n "$R" ] && [ "$R" = "$lr" ] && pass "check-runs last-reload: $R" || fail "check-runs last-reload: [$R], log [$lr]"
out=$(tgm "$CHECK_RUNS" since "$TT0" 2>&1)
[ "$out" = "$R" ] && pass "check-runs since: raised to the last reload ($TT0 -> $out)" || fail "check-runs since raised: [$out]"
out=$(tgm "$CHECK_RUNS" next rollup-hourly 2>&1)
left=$(( TJ - $(now) ))
rem=${out#* remaining=}
if [ "${out%% *}" = "$(utc "$TJ")" ] && [ "$rem" -ge $((left - 2)) ] && [ "$rem" -le $((left + 2)) ]; then
    pass "check-runs next after the move: $out"
else
    fail "check-runs next after the move: [$out], expected $(utc "$TJ") remaining about $left"
fi
info "waiting for the transformer's run at $(utc "$TJ")"
wait_until $((TJ + 20))
L=$(tlog)
tmin=$(minute_of "$TJ" | sed 's/Z$//')
if printf '%s\n' "$L" | grep -q "^$tmin:0[0-9]Z run job=rollup-hourly key=rollup.hourly phase=start$" \
   && printf '%s\n' "$L" | grep -Eq ' run job=rollup-hourly key=rollup.hourly phase=end status=ok rows=1 ms=[0-9.]+$'; then
    pass "the script job ran at its new minute: $(printf '%s\n' "$L" | grep ' job=rollup-hourly' | tr '\n' '|')"
else
    fail "the script job at $(utc "$TJ"): $(printf '%s\n' "$L" | grep ' job=rollup-hourly' | tr '\n' '|')"
fi
printf '%s\n' "$L" | grep -q " script job=rollup-hourly rolled up [0-9]* orders as shop_etl into reporting$" \
    && pass "its log(text) line: $(printf '%s\n' "$L" | grep ' script job=' | tail -n 1)" || fail "no script line"
out=$(rsql "SELECT count(*), min(src_role), min(dst_role) FROM rollup")
[ "$out" = "1|shop_etl|bi_etl" ] && pass "one row moved from shop (read as shop_etl) into reporting (as bi_etl): $out" \
    || fail "reporting.rollup: [$out]"
runs=$(tgm "$CHECK_RUNS" runs rollup-hourly "$R" 2>&1)
if [ "$(printf '%s\n' "$runs" | wc -l)" = 1 ] && printf '%s' "$runs" | grep -Eq "^$tmin:0[0-9]Z $tmin:[0-9]{2}Z rows=1 ms=[0-9.]+$"; then
    pass "check-runs runs since the reload: $runs"
else
    fail "check-runs runs since the reload: [$runs]"
fi
end=$(printf '%s' "$runs" | cut -d' ' -f2)
out=$(tgm "$CHECK_RUNS" runs rollup-hourly "$end" 2>&1)
[ -z "$out" ] && pass "check-runs runs since its end: none" || fail "check-runs runs since its end: [$out]"
out=$(tgm "$CHECK_RUNS" next rollup-hourly 2>&1)
[ "${out%% *}" = "$(utc $((TJ + 86400)))" ] && pass "check-runs next after the run: $out" || fail "check-runs next after the run: [$out]"
out=$(tssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^GREEN: queries.yaml, builders/, scripts/ and jobs.yaml load' \
    && pass "transformer validator green ($out)" || fail "transformer validator: exit $rc: $out"
check "the transformer's log holds no role password" sh -c "! docker exec $TC grep -qF '$ETLPW' $LOG"
TR_RUN=$(tmem)
info "transformer footprint after a run: $TR_RUN"

# --- the caller's calls on its HTTP connections (v0.5) --------------------------------------
L=$(clog)
R=$(stubreqs)
c=$(printf '%s\n' "$R" | grep -c '"path": "/consents/')
[ "$c" -ge 100 ] && pass "the stream's calls reached the stub ($c POST /consents/<owner>)" || fail "consents at the stub: $c"
bad=$(printf '%s\n' "$R" | grep '"path": "/consents/' | grep -v '"method": "POST"' | grep -c .)
[ "$bad" = 0 ] && pass "each consent call a POST" || fail "$bad consent calls not POST"
bad=$(printf '%s\n' "$R" | grep '"path": "/consents/' | grep -cv "\"auth\": \"Bearer $HTTPTOKEN\"")
[ "$bad" = 0 ] && pass "each call on stub carries Authorization: Bearer <its secret>" || fail "$bad calls without the bearer"
bad=$(printf '%s\n' "$R" | grep -v '"agent": "caller"' | grep -c .)
[ "$bad" = 0 ] && pass "every request's User-Agent is the caller's hostname" || fail "$bad requests with another User-Agent"
bad=$(printf '%s\n' "$R" | grep -v '"host": "stub:8080"' | grep -c .)
[ "$bad" = 0 ] && pass "every request's Host is the target as written (stub:8080)" || fail "$bad requests with another Host"
bad=$(printf '%s\n' "$R" | grep '"path": "/slow' | grep -cv '"auth": null')
[ "$bad" = 0 ] && pass "the public connection sends no Authorization" || fail "$bad slow calls with a credential"
printf '%s\n' "$R" | grep '"path": "/consents/' | head -n 1 | grep -Eq '"json": \{"at": "[0-9-]{10}T[0-9:.]{8,15}Z", "consent": "(grant|withdraw)"\}, .*"path": "/consents/[0-9]+", .*"type": "application/json"' \
    && pass "a consent's JSON body from its parameters, the path's owner not in it: $(printf '%s\n' "$R" | grep '"path": "/consents/' | head -n 1 | cut -c1-160)" \
    || fail "consent body: $(printf '%s\n' "$R" | grep '"path": "/consents/' | head -n 1)"
g=$(printf '%s\n' "$R" | grep -c '"consent": "grant"')
w=$(printf '%s\n' "$R" | grep -c '"consent": "withdraw"')
share=$(( g * 100 / (g + w + (g + w == 0)) ))
[ "$share" -ge 62 ] && [ "$share" -le 88 ] && pass "the weighted choice {grant: 3, withdraw: 1}: $g grant, $w withdraw ($share%)" \
    || fail "weighted choice: $g grant, $w withdraw"
o=$(printf '%s\n' "$R" | grep -c '"json": {"n": 10, "tests": \["cbc", "chem"\], "urgent": \(true\|false\)}, "method": "POST", "path": "/orders"')
[ "$o" -ge 10 ] && pass "a builder's body, POST /orders ($o)" || fail "builder calls: $o"
p=$(printf '%s\n' "$R" | grep '"path": "/consents/' | sed -n 's/.*"peer": "\([^"]*\)".*/\1/p' | sort -u | wc -l)
[ "$p" -ge 1 ] && [ "$p" -le 4 ] && pass "kept alive: $c consent calls on $p connections" || fail "consent connections: $p for $c calls"
m=$(docker exec "$CLIENT" curl -fsS -m 10 http://caller:9120/metrics)
v() { printf '%s\n' "$m" | awk -v n="$1{key=\"$2\"}" '$1 == n { print $2 }'; }   # v <series> <key>
[ "$(v scheduler_errors_total stub.consent)" = 0 ] && [ "$(v scheduler_calls_total stub.consent)" -ge 100 ] \
    && pass "metrics: stub.consent $(v scheduler_calls_total stub.consent) calls, 0 errors" || fail "stub.consent metrics: $(v scheduler_calls_total stub.consent)/$(v scheduler_errors_total stub.consent)"
[ "$(v scheduler_errors_total stub.order)" = 0 ] && [ "$(v scheduler_calls_total stub.order)" -ge 10 ] \
    && pass "metrics: stub.order $(v scheduler_calls_total stub.order) calls idle past the stub's 5 s, 0 errors (reopened)" \
    || fail "stub.order metrics: $(v scheduler_calls_total stub.order)/$(v scheduler_errors_total stub.order)"
f=$(v scheduler_calls_total stub.fail)
[ "${f:-0}" -ge 10 ] && [ "$(v scheduler_errors_total stub.fail)" = "$f" ] && pass "metrics: each 503 an error ($f of $f)" \
    || fail "stub.fail metrics: $f/$(v scheduler_errors_total stub.fail)"
sl=$(v scheduler_calls_total stub.slow)
[ "${sl:-0}" -ge 10 ] && [ "$(v scheduler_errors_total stub.slow)" = "$sl" ] && pass "metrics: each timeout an error ($sl of $sl)" \
    || fail "stub.slow metrics: $sl/$(v scheduler_errors_total stub.slow)"
printf '%s\n' "$L" | grep -q ' error key=stub.fail status=503 message="the lab is closed for maintenance; ' \
    && pass "a 503 logged: $(printf '%s\n' "$L" | grep ' error key=stub.fail ' | tail -n 1 | cut -c1-120)..." || fail "no 503 error line"
printf '%s\n' "$L" | grep -q ' error key=stub.slow status=timeout message="no answer within 1s"$' \
    && pass "a timeout logged: $(printf '%s\n' "$L" | grep ' error key=stub.slow ' | tail -n 1)" || fail "no timeout error line"
k=$(printf '%s\n' "$L" | grep ' key minute=.* key=stub.fail ' | tail -n 1)
printf '%s' "$k" | grep -Eq 'calls=([1-9][0-9]*) errors=\1 ' && pass "the minute's key line counts them: $k" || fail "stub.fail key line: [$k]"
check "the caller's log holds no credential" sh -c "! docker exec $CC grep -qF '$HTTPTOKEN' $LOG && ! docker service logs $CL_SERVICE 2>&1 | grep -qF '$HTTPTOKEN'"
# the script job on the HTTP connection, every minute since the caller runs
runs=$(printf '%s\n' "$L" | grep -c ' run job=relay key=stub.relay phase=end status=ok rows=1 ms=')
[ "$runs" -ge 5 ] && pass "the script job ran on its HTTP connection ($runs runs, $(printf '%s\n' "$L" | grep ' run job=relay ' | tail -n 1 | cut -c22-))" \
    || fail "relay runs: $runs; $(printf '%s\n' "$L" | grep ' job=relay ' | tail -n 3 | tr '\n' '|')"
printf '%s\n' "$L" | grep -Eq ' script job=relay order 201 A[0-9]{6}, shipment 201, refused 503$' \
    && pass "the script got each answer, whatever its status: $(printf '%s\n' "$L" | grep ' script job=relay ' | tail -n 1 | cut -c22-)" \
    || fail "relay script line: $(printf '%s\n' "$L" | grep ' script job=relay ' | tail -n 1)"
for want in 'connection=lab method=POST status=201 ms=[0-9.]+ path=/orders$' \
            'connection=lab method=POST status=201 ms=[0-9.]+ path=/shipments$' \
            'connection=lab method=POST status=503 ms=[0-9.]+ path=/fail$'; do
    printf '%s\n' "$L" | grep -Eq " http job=relay $want" && pass "an http line: $(printf '%s\n' "$L" | grep -E " http job=relay $want" | tail -n 1 | cut -c22-)" \
        || fail "no http line matching [$want]"
done
s=$(printf '%s\n' "$R" | grep '"path": "/shipments"' | tail -n 1)
printf '%s' "$s" | grep -q '"size": 22, "type": "application/x-ndjson"' && pass "a bytes body as given, its Content-Type from headers" \
    || fail "shipment at the stub: [$s]"
rc_=$(v scheduler_calls_total stub.relay/lab); re_=$(v scheduler_errors_total stub.relay/lab)
[ "${rc_:-0}" -ge 15 ] && [ "$rc_" = $(( 3 * ${re_:-0} )) ] \
    && pass "metrics: stub.relay/lab $rc_ calls, $re_ errors (the 503s), apart from the runs" || fail "stub.relay/lab metrics: $rc_/$re_"
[ "$(v scheduler_errors_total stub.relay)" = 0 ] && pass "metrics: the runs themselves, no error ($(v scheduler_calls_total stub.relay))" \
    || fail "stub.relay run metrics: $(v scheduler_calls_total stub.relay)/$(v scheduler_errors_total stub.relay)"
CL_RUN=$(cmem)
info "caller footprint running (48 calls a minute, a script job every minute): $CL_RUN"

# --- the entrypoint's refusals -------------------------------------------------------------
printf 'x: [\n' > "$tmp/bad.yaml"
refuse() {  # refuse <name> <expected text> <docker run args...>
    k=$1; want=$2; shift 2
    out=$(docker run --name "${STACK}-refuse-$k" --rm -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" "$@" "$IMAGE" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want"; then
        pass "the entrypoint refuses: $want (exit $rc)"
    else
        fail "entrypoint $k: exit $rc: $(printf '%s' "$out" | tail -n 3)"
    fi
}
SCHED_MOUNT="-v $tmp/schedule.yaml:/opt/gm/seed/schedule.yaml:ro"
refuse policy "gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of" $SCHED_MOUNT -e GM_WRITE_POLICY=read-only
refuse override "is not one of this brick's writable_paths" $SCHED_MOUNT -e GM_WRITE_POLICY=report-only \
    -e GM_WRITE_OVERRIDES=/srv/scheduler/jobs/jobs.yaml
refuse schedule "gm-entrypoint: fatal: seed file /opt/gm/seed/schedule.yaml is missing"
printf 'a\nb\n' > "$tmp/pw_lines"
refuse secret "gm-entrypoint: fatal: secret role_shop_app_password must be a single line" $SCHED_MOUNT \
    -v "$tmp/pw_lines:$SECRET:ro"

# --- hardening ------------------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
for f in /opt/gm/validator/validate.sh /usr/local/sbin/gm-reload-scheduler /etc/scheduler/scheduler.yaml \
         /usr/local/lib/python3.13/dist-packages/gm_scheduler/runner.py /etc/s6-overlay/s6-rc.d/scheduler/run; do
    check "player cannot write $f" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@scheduler 'echo x >> $f'"
done
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
case $caps in "[ALL]"*) pass "cap_drop ALL ($caps)" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"
check "the password is in no log line" sh -c "! docker exec $C grep -qF '$APPPW' $LOG && ! docker service logs $SERVICE 2>&1 | grep -qF '$APPPW'"
info "footprint at rest: idle $REST_IDLE; running $REST_RUN"
info "transformer footprint: idle $TR_IDLE; running, after a run $TR_RUN"
info "caller footprint: idle $CL_IDLE; running $CL_RUN"
info "transformer disk: $(tgm du -sh /srv/scheduler /var/log/scheduler /var/lib/scheduler /var/lib/gm-state 2>/dev/null | tr '\t\n' ' ')"
info "disk: $(gm du -sh /srv/scheduler /var/log/scheduler /var/lib/scheduler /var/lib/gm-state 2>/dev/null | tr '\t\n' ' ')"
info "log: $(gm sh -c "wc -lc < $LOG") (lines, bytes) after $(( ($(now) - RUN_START) / 60 )) min running"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
