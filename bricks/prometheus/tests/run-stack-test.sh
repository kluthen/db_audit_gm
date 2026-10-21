#!/bin/sh
# Stack test of the Prometheus brick (v0.2 build plan, chunk 4, Done when).
#
# Deploys the brick as a Swarm stack (stack.test.yml) with its seed file and
# secret as external configs and secrets created here, then checks, from a
# client container on the stack's network and from the GM side (docker exec):
#   - the container becomes healthy; Prometheus runs as `prometheus`;
#   - SSH as `player` works, and `player` may sudo exactly the 2 wrappers;
#   - the UI and API answer under /prometheus/, from another container;
#   - the admin and lifecycle HTTP endpoints are refused;
#   - edits to /etc/prometheus survive a reload and a new container, and a
#     retention change in prometheus.yml takes effect through the wrapper;
#   - the validator exits 0, then 1 on a broken or pending file;
#   - the seed marker is out of player's reach; read-only root, capabilities;
#   - the node-health script, mounted as configs into the prometheus node and
#     a postgres 0.2.0 node `db`: each node's endpoint readable from the
#     other, with CPU, memory, disk against the reservation, the host's free
#     space and each listed service; a service stopped with s6-svc -d shown
#     as down; Prometheus scraping both; the files read-only for player.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the images built locally (the
# postgres image is the test client: it has ssh and perl):
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.1.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres
# Usage: sh bricks/prometheus/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-prom
IMAGE=127.0.0.1:5000/dbagm/prometheus:0.1.0
CLIENT_IMAGE=127.0.0.1:5000/dbagm/postgres:0.2.0
SERVICE=${STACK}_prometheus
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk4-prometheus
CONFIGS="seed_prometheus_yml seed_postgresql_conf seed_pg_hba_conf envelopes nh_script nh_type nh_run nh_dep_base nh_bundle nh_conf_db nh_conf_prometheus"
SECRETS="player_ssh_pubkey dba_password monitoring_password"
VOLUMES="prom_data prom_conf prom_home prom_gmstate prom_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run"
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
NH=$HERE/../companion/node-health
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
CONF=/etc/prometheus/prometheus.yml

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-prom.XXXXXX")

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" >/dev/null 2>&1
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

for i in "$IMAGE" "$CLIENT_IMAGE"; do
    docker image inspect "$i" >/dev/null 2>&1 || { echo "image $i not built" >&2; exit 2; }
done
if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi

# --- per-game material, as gmctl deploy would create it ---------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$tmp/dba_password"
# The database node's monitoring role password (postgres 0.2.0); unused here.
printf 'mon%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_prometheus_yml "$HERE/fixtures/prometheus.yml"
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql.conf"
cfg seed_pg_hba_conf "$PG_FIXTURES/pg_hba.conf"
cfg envelopes "$PG_FIXTURES/envelopes.conf"
# the node-health script and its s6 service, and each node's own config,
# written by hand in the renderer's format (capture W1, item 4)
cfg nh_script "$NH/node-health.pl"
cfg nh_type "$NH/s6-rc.d/gm-node-health/type"
cfg nh_run "$NH/s6-rc.d/gm-node-health/run"
cfg nh_dep_base "$NH/s6-rc.d/gm-node-health/dependencies.d/base"
cfg nh_bundle "$NH/user-bundles.d/user/contents.d/gm-node-health"
cfg nh_conf_db "$HERE/fixtures/node-health/db.conf"
cfg nh_conf_prometheus "$HERE/fixtures/node-health/prometheus.conf"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_monitoring_password" "$tmp/monitoring_password" >/dev/null

info "deploying stack $STACK"
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

if C=$(wait_healthy "$SERVICE"); then
    pass "service deployed and container healthy ($C)"
else
    fail "container did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi
if DB=$(wait_healthy "$DB_SERVICE"); then
    pass "db node (postgres 0.2.0, receiving node-health) healthy ($DB)"
else
    fail "db node did not become healthy"
    docker service ps --no-trunc "$DB_SERVICE" || true
    docker service logs --tail 60 "$DB_SERVICE" 2>&1 || true
    exit 1
fi

# --- client on the stack network ---------------------------------------------
docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$CLIENT_IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@prometheus "$@"; }
gm() { docker exec -i "$C" "$@"; }
# nhttp <method> <host> <port> <path>: the raw HTTP/1.0 response, from the
# client container (another node of the network, as the web front would be).
PERL_HTTP='use IO::Socket::INET; my ($m, $h, $p, $u) = @ARGV;
my $s = IO::Socket::INET->new(PeerAddr => $h, PeerPort => $p, Timeout => 5) or exit 9;
print $s "$m $u HTTP/1.0\r\nHost: $h:$p\r\nContent-Length: 0\r\n\r\n"; local $/; print <$s>;'
nhttp() { docker exec -i "$CLIENT" perl -e "$PERL_HTTP" "$@"; }
status_of() { sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' | tr -d '\r'; }
retention() { gm curl -fsS -m 5 http://127.0.0.1:9090/prometheus/api/v1/status/runtimeinfo | sed -n 's/.*"storageRetention":"\([^"]*\)".*/\1/p'; }

# --- Prometheus served ---------------------------------------------------------
u=$(gm ps -o user= -C prometheus | sort -u | tr -d ' ')
[ "$u" = prometheus ] && pass "Prometheus runs as prometheus" || fail "Prometheus process user: [$u]"
[ "$(retention)" = "1d or 256MiB" ] && pass "seed retention in effect (1d or 256MiB)" || fail "seed retention: $(retention)"

# --- SSH and sudo ------------------------------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@prometheus true"
allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-prometheus "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the two wrappers, no arguments" \
    || fail "sudo -l: got [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus sudo -n /bin/sh -c true"
check "sudo refuses /usr/bin/id" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus sudo -n /usr/bin/id"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus sudo -n /usr/local/sbin/gm-validate /etc/passwd"
check "sudo refuses -u prometheus" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus sudo -n -u prometheus /usr/local/sbin/gm-validate"
check "sudo refuses -s" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus sudo -n -s"

# --- validator on the seed -----------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "${out#*sudo:}" ] && pass "gm-validate green on the seed, no sudo warning (exit 0: $out)" \
    || fail "gm-validate on seed: exit $rc: $out"
check "sudo logs to /run/gm/sudo.log" docker exec "$C" grep -q 'COMMAND=/usr/local/sbin/gm-validate' /run/gm/sudo.log
out=$(docker exec -u prometheus "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as prometheus green (exit 0)" || fail "GM validator: exit $rc: $out"
m=$(gm stat -c '%a %U:%G' /etc/prometheus $CONF /var/lib/gm-state /var/lib/gm-state/.gm-seeded /home/player /var/lib/prometheus | tr '\n' ' ')
[ "$m" = "2775 prometheus:promconf 664 prometheus:promconf 755 root:root 444 root:root 750 player:player 750 prometheus:prometheus " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"

# --- seed marker out of the players' reach ---------------------------------------
MARKER=/var/lib/gm-state/.gm-seeded
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
marker0=$(gm cat "$MARKER")
check "no marker in the group-writable /etc/prometheus" gm test ! -e /etc/prometheus/.gm-seeded
denied "player cannot remove the marker" rm -f "$MARKER"
denied "player cannot rename the marker" mv -f "$MARKER" "$MARKER.x"
denied "player cannot overwrite the marker" "echo x > $MARKER"
denied "player cannot create a file next to the marker" touch /var/lib/gm-state/x
check "prometheus cannot remove the marker" sh -c "! docker exec -u prometheus $C rm -f $MARKER"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "marker unchanged after the attempts" || fail "marker changed or gone"

# --- UI and API under the sub-path, from another node ---------------------------
r=$(nhttp GET prometheus 9090 /prometheus/)
if [ "$(printf '%s' "$r" | status_of)" = 302 ] && printf '%s' "$r" | grep -qi '^Location: /prometheus/query'; then
    pass "GET /prometheus/ redirects to /prometheus/query"
else
    fail "GET /prometheus/: $(printf '%s' "$r" | head -n 3)"
fi
r=$(nhttp GET prometheus 9090 /prometheus/query)
if [ "$(printf '%s' "$r" | status_of)" = 200 ] && printf '%s' "$r" | grep -q '<title>Prometheus'; then
    pass "the UI answers under /prometheus/ (GET /prometheus/query: 200, the UI's page)"
else
    fail "GET /prometheus/query: $(printf '%s' "$r" | head -n 3)"
fi
r=$(nhttp GET prometheus 9090 /prometheus/api/v1/status/buildinfo)
if [ "$(printf '%s' "$r" | status_of)" = 200 ] && printf '%s' "$r" | grep -q '"version":"3.13.5"'; then
    pass "the API answers under /prometheus/ (buildinfo: version 3.13.5)"
else
    fail "GET buildinfo: $(printf '%s' "$r" | head -n 3)"
fi
r=$(nhttp GET prometheus 9090 /api/v1/status/buildinfo)
[ "$(printf '%s' "$r" | status_of)" = 404 ] && pass "nothing is served outside the sub-path (GET /api/v1/status/buildinfo: 404)" \
    || fail "GET /api/v1/status/buildinfo outside the sub-path: $(printf '%s' "$r" | head -n 1)"

# --- admin and lifecycle endpoints refused ------------------------------------------
for e in "POST /prometheus/-/reload 403" "PUT /prometheus/-/quit 403" \
         "POST /prometheus/api/v1/admin/tsdb/snapshot 500" \
         "POST /prometheus/api/v1/admin/tsdb/delete_series?match[]=up 500" \
         "POST /prometheus/api/v1/admin/tsdb/clean_tombstones 500"; do
    set -- $e
    r=$(nhttp "$1" prometheus 9090 "$2")
    s=$(printf '%s' "$r" | status_of)
    if [ "$s" = "$3" ] && printf '%s' "$r" | grep -q 'Lifecycle API is not enabled\|admin APIs disabled'; then
        pass "$1 $2 refused ($s: $(printf '%s' "$r" | tail -n 1 | cut -c1-80))"
    else
        fail "$1 $2: $(printf '%s' "$r" | head -n 1) $(printf '%s' "$r" | tail -n 1)"
    fi
done
check "Prometheus still ready after the refused quit" gm curl -fsS -o /dev/null -m 5 http://127.0.0.1:9090/prometheus/-/ready

# --- edits, pending, reload, retention ---------------------------------------------------
pssh "sed -i -e 's/^      time: 1d$/      time: 12h/' $CONF && cat >> $CONF" <<'EOF' \
    && pass "player edits $CONF (retention 12h, a new job)" || fail "player cannot edit $CONF"
  - job_name: stack-test-edit
    metrics_path: /prometheus/metrics
    static_configs:
      - targets: ['127.0.0.1:9090']
EOF
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED pending: '; then
    pass "validator red on an edit not yet reloaded (exit 1: $out)"
else
    fail "pending edit: exit $rc: $out"
fi
out=$(pssh sudo -n gm-reload-prometheus 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'retention in effect: 12h or 256MiB'; then
    pass "gm-reload-prometheus (exit 0: $(printf '%s' "$out" | tr '\n' ' '))"
else
    fail "gm-reload-prometheus: exit $rc: $out"
fi
[ "$(retention)" = "12h or 256MiB" ] && pass "retention change in prometheus.yml in effect through the wrapper (12h or 256MiB)" \
    || fail "retention after reload: $(retention)"
check "the new job is in the configuration Prometheus runs" sh -c \
    "docker exec $C curl -fsS -m 5 http://127.0.0.1:9090/prometheus/api/v1/status/config | grep -q 'job_name: stack-test-edit'"
check "the edits are kept in $CONF after the reload" gm grep -q '^      time: 12h$' "$CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green after the reload (exit 0)" || fail "after reload: exit $rc: $out"

# --- a broken file: validator red, reload refused, server left running ---------------------
pssh "cp $CONF ~/prometheus.yml.good && echo 'scrape_configs: [' >> $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: ' && printf '%s' "$out" | grep -q '^RED pending: '; then
    pass "validator red on a file that does not load (exit 1)"
else
    fail "broken file: exit $rc: $out"
fi
out=$(pssh sudo -n gm-reload-prometheus 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT reloaded' \
   && gm curl -fsS -o /dev/null -m 5 http://127.0.0.1:9090/prometheus/-/ready; then
    pass "gm-reload-prometheus refuses a broken file, server left running"
else
    fail "broken file reload: exit $rc: $out"
fi
# a retention without its size bound loads, but the validator is red
pssh "sed -e '/^      size: /d' ~/prometheus.yml.good > $CONF"
pssh sudo -n gm-reload-prometheus >/dev/null 2>&1 || fail "reload of the file without a size bound"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "^RED retention: in effect '12h'"; then
    pass "validator red on a retention bounded by time only (exit 1)"
else
    fail "retention without size: exit $rc: $out"
fi
pssh "cat ~/prometheus.yml.good > $CONF" && pssh sudo -n gm-reload-prometheus >/dev/null 2>&1 || fail "restore the file"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green again after fixing (exit 0)" || fail "after fix: exit $rc: $out"

# --- persistence across a new container ---------------------------------------------------
pssh "echo 'audit notes' > ~/report.md" && pass "player's home is writable (~/report.md)" || fail "home not writable"
info "forcing a new container (docker service update --force)"
docker service update --force --detach "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then
    pass "new container healthy ($C2)"
    C=$C2
else
    fail "new container did not become healthy"
fi
check "$CONF edits kept in a new container (not re-seeded)" gm grep -q 'job_name: stack-test-edit' "$CONF"
[ "$(retention)" = "12h or 256MiB" ] && pass "the edited retention is in effect in the new container" \
    || fail "retention in the new container: $(retention)"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green in the new container" || fail "validator in new container: exit $rc: $out"

# --- node-health script (mounted material) ---------------------------------------------
NHFILES="/usr/local/lib/gm/node-health/node-health.pl /etc/s6-overlay/s6-rc.d/gm-node-health/run /etc/s6-overlay/s6-rc.d/gm-node-health/type /etc/s6-overlay/s6-rc.d/gm-node-health/dependencies.d/base /etc/s6-overlay/user-bundles.d/user/contents.d/gm-node-health /opt/gm/node-health/node.conf"
dbx() { docker exec -i "$DB" "$@"; }
nodex() {  # nodex <prometheus|db> <command...>: run in that node's container (GM side)
    n=$1; shift
    if [ "$n" = db ]; then docker exec -i "$DB" "$@"; else docker exec -i "$C" "$@"; fi
}
for n in prometheus db; do
    s=$(nodex $n /command/s6-svstat -o up /run/service/gm-node-health 2>&1)
    [ "$s" = true ] && pass "$n: s6 runs the mounted gm-node-health service" || fail "$n: gm-node-health: $s"
    who=$(nodex $n ps -o user=,args= -C perl | sed 's/  */ /g' | sort | tr '\n' ';')
    [ "$who" = "nobody perl /usr/local/lib/gm/node-health/node-health.pl;root perl /usr/local/lib/gm/node-health/node-health.pl;" ] \
        && pass "$n: listener runs as nobody, sampler as root ($who)" || fail "$n: node-health processes: $who"
    m=$(nodex $n stat -c '%U:%G %a' $NHFILES | sort -u | tr '\n' ' ')
    [ "$m" = "root:root 444 root:root 555 " ] && pass "$n: mounted files root-owned, no write bit ($m)" || fail "$n: modes: $m"
done
# from the prometheus node, as player: the db node's endpoint
mdb=$(pssh curl -fsS -m 5 http://db:9110/metrics 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "prometheus node (player, curl): db:9110/metrics readable" || fail "db endpoint from prometheus: $mdb"
# from the db node, as player (perl, no curl there): the prometheus node's endpoint
mprom=$(docker exec -u player "$DB" perl -e "$PERL_HTTP" GET prometheus 9110 /metrics 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(printf '%s' "$mprom" | status_of)" = 200 ]; then
    pass "db node (player, perl): prometheus:9110/metrics readable"
else
    fail "prometheus endpoint from db: $(printf '%s' "$mprom" | head -n 2)"
fi
has() {  # has <node> <text> <regex> <what>
    if printf '%s\n' "$2" | grep -Eq "$3"; then pass "$1 endpoint shows $4"; else fail "$1 endpoint lacks $4 ($3)"; fi
}
for n in db prometheus; do
    if [ "$n" = db ]; then t=$mdb; res=1073741824; svcs="postgres sshd"; mem=536870912
    else t=$mprom; res=536870912; svcs="prometheus sshd"; mem=402653184; fi
    has $n "$t" "^node_health_cpu_seconds_total\{node=\"$n\"\} [0-9.e+-]+$" "CPU time"
    has $n "$t" "^node_health_cpu_limit_cores\{node=\"$n\"\} 0\.5$" "the CPU limit (0.5)"
    has $n "$t" "^node_health_memory_used_bytes\{node=\"$n\"\} [1-9][0-9]+$" "memory used"
    has $n "$t" "^node_health_memory_working_set_bytes\{node=\"$n\"\} [0-9]+$" "the memory working set"
    has $n "$t" "^node_health_memory_limit_bytes\{node=\"$n\"\} $mem$" "the memory limit ($mem)"
    has $n "$t" "^node_health_disk_used_bytes\{node=\"$n\"\} [1-9][0-9]+$" "disk used by its volumes"
    has $n "$t" "^node_health_disk_reservation_bytes\{node=\"$n\"\} $res$" "the disk reservation ($res)"
    has $n "$t" "^node_health_volume_used_bytes\{node=\"$n\",path=\"/run\"\} [0-9]+$" "per-volume use"
    has $n "$t" "^node_health_host_free_bytes\{node=\"$n\"\} [1-9][0-9]+$" "the host's free space"
    for s in $svcs; do
        has $n "$t" "^node_health_service_up\{node=\"$n\",service=\"$s\"\} 1$" "service $s up"
    done
done
info "db endpoint, disk lines: $(printf '%s\n' "$mdb" | grep -E '^node_health_(disk|volume|host)' | tr '\n' ' ')"
r=$(nhttp GET db 9110 /nothing-here)
[ "$(printf '%s' "$r" | status_of)" = 404 ] && pass "node-health answers 404 off /metrics" || fail "GET /nothing-here: $(printf '%s' "$r" | head -n 1)"
# a service stopped with s6-svc -d shows as down, then up again
dbx /command/s6-svc -d /run/service/postgres
i=0; down=
while [ "$i" -lt 20 ]; do
    sleep 1; i=$((i + 1))
    m=$(nhttp GET db 9110 /metrics)
    if printf '%s\n' "$m" | grep -q '^node_health_service_up{node="db",service="postgres"} 0' \
       && printf '%s\n' "$m" | grep -q '^node_health_service_wanted_up{node="db",service="postgres"} 0'; then
        down=$i; break
    fi
done
[ -n "$down" ] && pass "postgres stopped with s6-svc -d shown as down (up 0, wanted_up 0) within ${down}s" \
    || fail "postgres stopped with s6-svc -d not shown as down"
dbx /command/s6-svc -u /run/service/postgres
i=0; up=
while [ "$i" -lt 30 ]; do
    sleep 1; i=$((i + 1))
    if nhttp GET db 9110 /metrics | grep -q '^node_health_service_up{node="db",service="postgres"} 1'; then up=$i; break; fi
done
[ -n "$up" ] && pass "postgres back up shown as up within ${up}s" || fail "postgres not shown up again"
# Prometheus scrapes both endpoints
i=0; ok=
while [ "$i" -lt 60 ]; do
    q=$(gm curl -fsS -m 5 -G --data-urlencode 'query=up{job="node-health"} == 1' http://127.0.0.1:9090/prometheus/api/v1/query)
    if printf '%s' "$q" | grep -q '"instance":"db:9110"' && printf '%s' "$q" | grep -q '"instance":"prometheus:9110"'; then ok=1; break; fi
    sleep 3; i=$((i + 3))
done
[ -n "$ok" ] && pass "Prometheus scrapes both node-health endpoints (up == 1 for db:9110 and prometheus:9110)" \
    || fail "Prometheus scrape of node-health: $q"
q=$(gm curl -fsS -m 5 -G --data-urlencode 'query=node_health_disk_used_bytes / node_health_disk_reservation_bytes' http://127.0.0.1:9090/prometheus/api/v1/query)
printf '%s' "$q" | grep -q '"node":"db"' && pass "disk against the reservation queryable in Prometheus ($(printf '%s' "$q" | grep -o '"node":"[a-z]*"[^]]*\]' | tr '\n' ' '))" \
    || fail "disk ratio query: $q"
# read-only for player, on both nodes
for f in /usr/local/lib/gm/node-health/node-health.pl /opt/gm/node-health/node.conf /etc/s6-overlay/s6-rc.d/gm-node-health/run; do
    check "player cannot write $f on db" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db 'echo x >> $f'"
    check "player cannot write $f on prometheus" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus 'echo x >> $f'"
done
check "player cannot remove the service list on db" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db 'rm -f /opt/gm/node-health/node.conf'"
check "player can read the service list on db" docker exec "$CLIENT" ssh $SSH_OPTS player@db "grep -qx 'services=postgres sshd' /opt/gm/node-health/node.conf"
# cost of the script, for brick.yaml's companion footprint. The listener's
# smaps are unreadable (a process that dropped root is not dumpable, and
# root here lacks CAP_SYS_PTRACE): its RSS only.
for n in prometheus db; do
    for p in $(nodex $n ps -o pid= -C perl); do
        u=$(nodex $n ps -o user= -p "$p" | tr -d ' ')
        if [ "$n" = db ]; then x=$DB; else x=$C; fi
        if [ "$u" = root ]; then
            mem=$(docker exec "$x" sh -c "grep -E '^(Rss|Pss|Private_Clean|Private_Dirty):' /proc/$p/smaps_rollup" | tr -s ' ' | tr '\n' ' ')
        else
            mem="Rss: $(nodex $n ps -o rss= -p "$p" | tr -d ' ') kB"
        fi
        cpu=$(docker exec "$x" sh -c "awk '{print \$14 + \$15}' /proc/$p/stat")
        info "$n: node-health pid $p ($u): $mem; CPU ${cpu} ticks in $(nodex $n ps -o etimes= -p "$p" | tr -d ' ') s"
    done
done

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
check "player cannot write the validator" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus 'echo x >> /opt/gm/validator/validate.sh'"
check "player cannot write a wrapper" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus 'echo x >> /usr/local/sbin/gm-reload-prometheus'"
check "player cannot write the TSDB" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@prometheus 'touch /var/lib/prometheus/x'"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"
info "memory in use: $(gm cat /sys/fs/cgroup/memory.current) bytes (limit $(gm cat /sys/fs/cgroup/memory.max))"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
