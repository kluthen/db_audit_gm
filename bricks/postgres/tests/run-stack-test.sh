#!/bin/sh
# Stack test of the PostgreSQL brick (build plan v0.1, chunk 2, Done when).
#
# Deploys the brick as a one-service Swarm stack (stack.test.yml) with the
# seed files, the envelope file and the secrets as external configs and
# secrets created here, then checks, from a client container on the
# stack's network and from the GM side (docker exec):
#   - the image serves PostgreSQL 18 and the container becomes healthy;
#   - SSH as `player` works, and `player` may sudo exactly the 3 wrappers;
#   - edits to /etc/postgresql survive gm-restart-db and a new container;
#   - the validator exits 0 in-envelope and 1 out-of-envelope;
#   - read-only root, capabilities, peer access for postgres.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the image built locally:
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.1.0 bricks/postgres
# Usage: sh bricks/postgres/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-pg
IMAGE=127.0.0.1:5000/dbagm/postgres:0.1.0
SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk2-postgres
CONFIGS="seed_postgresql_conf seed_pg_hba_conf envelopes"
SECRETS="player_ssh_pubkey dba_password"
VOLUMES="pgdata pgconf home run"
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-pg.XXXXXX")

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

docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "image $IMAGE not built" >&2; exit 2; }
if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi

# --- per-game material, as gmctl deploy would create it ---------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
# A password with the characters .pgpass and SQL must escape.
DBA_PASSWORD="T:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$DBA_PASSWORD" > "$tmp/dba_password"

docker config create -l "$LABEL" "${STACK}_seed_postgresql_conf" "$HERE/fixtures/postgresql.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_conf" "$HERE/fixtures/pg_hba.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_envelopes" "$HERE/fixtures/envelopes.conf" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null

info "deploying stack $STACK"
docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1

# From here on, every check records its own result; keep going on failure.
set +e

db_container() { docker ps -q -f "label=com.docker.swarm.service.name=$SERVICE" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy [old-container-id]: prints the healthy container id
    i=0
    while [ "$i" -lt 180 ]; do
        c=$(db_container)
        if [ -n "$c" ] && [ "$c" != "${1:-}" ] \
           && [ "$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null)" = healthy ]; then
            echo "$c"
            return 0
        fi
        sleep 2; i=$((i + 2))
    done
    return 1
}

if C=$(wait_healthy); then
    pass "service deployed and container healthy ($C)"
else
    fail "container did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi

# --- client on the stack network ---------------------------------------------
docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@db "$@"; }
gm() { docker exec -i "$C" "$@"; }
gm_pg() { docker exec -i -u postgres "$C" "$@"; }

# --- PostgreSQL served -------------------------------------------------------
v=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql -h db -U dba -d postgres -XAtc 'show server_version' 2>&1 || true)
case $v in 18.*) pass "serves PostgreSQL over TCP as dba (server_version $v)" ;; *) fail "TCP psql as dba: $v" ;; esac
check "GM: postgres peer over the local socket" sh -c "[ \"\$(docker exec -u postgres $C psql -XAtc 'select current_user')\" = postgres ]"

# --- SSH and sudo ------------------------------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@db true"
w=$(pssh "psql -XAtc 'select current_user'" 2>&1 || true)
[ "$w" = dba ] && pass "player's psql connects as dba through ~/.pgpass" || fail "player psql: $w"

allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-db "", /usr/local/sbin/gm-restart-db "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the three wrappers, no arguments" \
    || fail "sudo -l: got [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db sudo -n /bin/sh -c true"
check "sudo refuses /usr/bin/id" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db sudo -n /usr/bin/id"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db sudo -n /usr/local/sbin/gm-validate /etc/passwd"
check "sudo refuses -u postgres" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db sudo -n -u postgres /usr/local/sbin/gm-validate"
check "sudo refuses -s" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db sudo -n -s"

# --- validator: in envelope ---------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "${out#*sudo:}" ] && pass "gm-validate green on the seed, no sudo warning (exit 0: $out)" \
    || fail "gm-validate on seed: exit $rc: $out"
check "sudo logs to /run/gm/sudo.log" docker exec "$C" grep -q 'COMMAND=/usr/local/sbin/gm-validate' /run/gm/sudo.log
m=$(gm stat -c '%a %U:%G' /etc/postgresql /etc/postgresql/postgresql.conf /etc/postgresql/.gm-seeded /home/player /home/player/.pgpass /run/postgresql | tr '\n' ' ')
[ "$m" = "2775 postgres:pgconf 664 postgres:pgconf 444 root:root 750 player:player 600 player:player 2775 postgres:postgres " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"
out=$(gm_pg /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as postgres green (exit 0)" || fail "GM validator: exit $rc: $out"

# --- reload path: out-of-envelope sighup knob ------------------------------------
pssh "echo 'work_mem = 128MB   # stack test' >> /etc/postgresql/postgresql.conf" \
    && pass "player edits /etc/postgresql/postgresql.conf" || fail "player cannot edit postgresql.conf"
out=$(pssh sudo -n gm-reload-db 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-reload-db (exit 0)" || fail "gm-reload-db: exit $rc: $out"
w=$(pssh "psql -XAtc 'show work_mem'" 2>&1 || true)
[ "$w" = 128MB ] && pass "reload applied work_mem = 128MB" || fail "work_mem after reload: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED work_mem: in effect 128MB; pending 128MB'; then
    pass "gm-validate red on an out-of-envelope value (exit 1: $out)"
else
    fail "gm-validate out of envelope: exit $rc: $out"
fi

# --- restart path: postmaster knob, pending then in effect ----------------------
pssh "sed -i -e 's/^work_mem = 128MB.*/work_mem = 8MB   # stack test edit/' -e 's/^max_connections = .*/max_connections = 300/' /etc/postgresql/postgresql.conf" \
    || fail "sed -i as player"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED max_connections: pending 300 (/etc/postgresql/postgresql.conf:' \
   && ! printf '%s' "$out" | grep -q 'in effect'; then
    pass "validator flags a pending value before restart ($out)"
else
    fail "pending check: exit $rc: $out"
fi
s6pid=$(gm /command/s6-svstat -o pid /run/service/postgres)
out=$(pssh sudo -n gm-restart-db 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-restart-db (exit 0: $out)" || fail "gm-restart-db: exit $rc: $out"
[ "$(gm /command/s6-svstat -o pid /run/service/postgres)" != "$s6pid" ] && [ "$(db_container)" = "$C" ] \
    && pass "postgres restarted under s6, same container" || fail "restart did not go through s6 in place"
w=$(pssh "psql -XAtc 'show max_connections'" 2>&1 || true)
[ "$w" = 300 ] && pass "edit kept and applied across gm-restart-db (max_connections 300)" || fail "max_connections after restart: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED max_connections: in effect 300; pending 300'; then
    pass "validator red on the in-effect value (exit 1)"
else
    fail "in-effect check: exit $rc: $out"
fi

# --- gm-restart-db refuses a configuration that does not load ---------------------
pssh "echo 'shared_buffers = banana' >> /etc/postgresql/postgresql.conf"
out=$(pssh sudo -n gm-restart-db 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT restarted' && gm pg_isready -q -h /run/postgresql; then
    pass "gm-restart-db refuses a broken postgresql.conf, server left running"
else
    fail "broken config restart: exit $rc: $out"
fi
pssh "sed -i -e '/^shared_buffers = banana/d' -e 's/^max_connections = .*/max_connections = 50/' /etc/postgresql/postgresql.conf"
pssh sudo -n gm-restart-db >/dev/null 2>&1 || fail "restart back to the in-envelope configuration"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green again after fixing (exit 0)" || fail "after fix: exit $rc: $out"

# --- GM line removed: red --------------------------------------------------------
pssh "sed -i 's/^local   all       postgres              peer/# removed by test/' /etc/postgresql/pg_hba.conf"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true
out=$(gm_pg /opt/gm/validator/validate.sh 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "^RED pg_hba: the GM's line"; then
    pass "validator flags the missing GM pg_hba line"
else
    fail "missing GM line: exit $rc: $out"
fi
pssh "sed -i 's/^# removed by test/local   all       postgres              peer/' /etc/postgresql/pg_hba.conf"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true

# --- persistence across a new container ---------------------------------------------
pssh "psql -Xqc 'create table stack_test(i int); insert into stack_test values (42)'" || fail "create table"
pssh "echo 'audit notes' > ~/report.md" && pass "player's home is writable (~/report.md)" || fail "home not writable"
info "forcing a new container (docker service update --force)"
docker service update --force --detach "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$C"); then
    pass "new container healthy ($C2)"
    C=$C2
else
    fail "new container did not become healthy"
fi
w=$(pssh "grep -c '^work_mem = 8MB   # stack test edit' /etc/postgresql/postgresql.conf" 2>&1 || true)
[ "$w" = 1 ] && pass "/etc/postgresql edits kept in a new container (not re-seeded)" || fail "edits after new container: $w"
w=$(pssh "psql -XAtc 'select i from stack_test'" 2>&1 || true)
[ "$w" = 42 ] && pass "data kept in a new container" || fail "data after new container: $w"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green in the new container" || fail "validator in new container: exit $rc: $out"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
check "player cannot write the validator" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db 'echo x >> /opt/gm/validator/validate.sh'"
check "player cannot write the envelope file" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db 'echo x >> /opt/gm/protected/envelopes.conf'"
check "player cannot read the dba_password secret file" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db cat /opt/gm/secrets/dba_password"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume (fallback a)" || fail "/run mount: $mnt"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
