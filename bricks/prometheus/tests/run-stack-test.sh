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
#   - the seed marker is out of player's reach; read-only root, capabilities.
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
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk4-prometheus
CONFIGS="seed_prometheus_yml"
SECRETS="player_ssh_pubkey"
VOLUMES="prom_data prom_conf prom_home prom_gmstate prom_run"
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
docker config create -l "$LABEL" "${STACK}_seed_prometheus_yml" "$HERE/fixtures/prometheus.yml" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null

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
