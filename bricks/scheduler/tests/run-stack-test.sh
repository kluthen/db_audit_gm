#!/bin/sh
# Stack test of the scheduler brick (v0.3 build plan, chunk 3b, Done when).
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
#   - the entrypoint's refusals (policy, override, schedule, secrets);
#     read-only root, capabilities, /run a volume; the footprint at rest.
# Real time throughout (about 15 minutes); nothing moves a clock.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init). On the build host, run it
# under the host lock:
#   flock /tmp/dbagm-docker.lock sh bricks/scheduler/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BRICK=$(cd "$HERE/.." && pwd)
STACK=gmtest-sched
IMAGE=127.0.0.1:5000/dbagm/scheduler:0.1.0
DB_IMAGE=dbagm-test/scheduler-unit:0.1.0
SERVICE=${STACK}_scheduler
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk3-scheduler
CONFIGS="seed_schedule seed_queries seed_builder_report seed_jobs db_init"
SECRETS="player_ssh_pubkey role_shop_app_password"
VOLUMES="sch_repository sch_jobs sch_schedlog sch_schedstate sch_home sch_gmstate sch_run"
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
REPO=/srv/scheduler/repository
JOBS=/srv/scheduler/jobs/jobs.yaml
LOG=/var/log/scheduler/scheduler.log
SCHEDULE=/opt/gm/seed/schedule.yaml
SECRET=/opt/gm/secrets/role_shop_app_password
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
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_schedule "$tmp/schedule.yaml"
cfg seed_queries "$HERE/fixtures/queries.yaml"
cfg seed_builder_report "$HERE/fixtures/builders/report.py"
cfg seed_jobs "$tmp/jobs.yaml"
cfg db_init "$HERE/fixtures/db.sh"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_role_shop_app_password" "$tmp/role_shop_app_password" >/dev/null

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
