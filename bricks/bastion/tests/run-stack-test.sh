#!/bin/sh
# Stack test of the bastion brick (build plan v0.1, chunk 3, Done when).
#
# Deploys the bastion and a PostgreSQL node (chunk 2's image) as a
# two-service Swarm stack (stack.test.yml), with the starter pack, the seed
# files and the secrets as external configs and secrets created here, then
# checks, from this host as a player would and from the GM side
# (docker exec):
#   - both containers become healthy;
#   - password login as `player` on the published port, nothing else;
#   - the starter pack is in the home, ~/report.md is writable;
#   - from the bastion, `ssh db` with the key and `psql -h db` as dba;
#   - the validator is green, and red when ~/.pgpass is broken;
#   - after the database node is replaced (new host key), `ssh db` works;
#   - after the bastion is replaced, its host key, the home and the
#     player's edits are kept, and the starter pack is not copied again;
#   - read-only root, capabilities, `/run` volume, secrets unreadable.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), both images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.2.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres
# an OpenSSH client (8.4 or later) on this host, and a free TCP port
# GMTEST_BASTION_PORT (default 22222).
# Usage: sh bricks/bastion/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
STACK=gmtest-bastion
IMAGE=127.0.0.1:5000/dbagm/bastion:0.2.0
PG_IMAGE=127.0.0.1:5000/dbagm/postgres:0.2.0
BASTION=${STACK}_bastion
DB=${STACK}_db
NET=${STACK}_net
PORT=${GMTEST_BASTION_PORT:-22222}
export GMTEST_BASTION_PORT=$PORT
LABEL=dbagm.test=chunk3-bastion
CONFIGS="starter_readme starter_story starter_issues seed_postgresql_conf seed_pg_hba_conf envelopes"
SECRETS="player_password player_ssh_key player_ssh_pubkey dba_password"
VOLUMES="bastion_home bastion_hostkeys bastion_run db_pgdata db_pgconf db_home db_gmstate db_run"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-bastion.XXXXXX")

cleanup() {
    set +e
    info "teardown"
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

for i in "$IMAGE" "$PG_IMAGE"; do
    docker image inspect "$i" >/dev/null 2>&1 || { echo "image $i not built" >&2; exit 2; }
done
if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi

# --- per-game material, as gmctl deploy would create it ---------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
# Passwords with the characters the shadow line, .pgpass and SQL must survive.
PLAYER_PASSWORD="p@ss:w0rd $(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')\"'\\"
printf '%s' "$PLAYER_PASSWORD" > "$tmp/player_password"
DBA_PASSWORD="T:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$DBA_PASSWORD" > "$tmp/dba_password"
printf 'wrong password\n' > "$tmp/bad_password"
for p in player_password bad_password; do
    printf '#!/bin/sh\ncat %s\n' "$tmp/$p" > "$tmp/askpass_$p"
    chmod 0700 "$tmp/askpass_$p"
done
mkdir "$tmp/starter"
printf '# Starter pack (stack test)\n\nNodes: bastion, db.\n' > "$tmp/starter/README.md"
printf '# Story (stack test)\n' > "$tmp/starter/story.md"
printf '# Issues (stack test)\n\nNone.\n' > "$tmp/starter/issues.md"

docker config create -l "$LABEL" "${STACK}_starter_readme" "$tmp/starter/README.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_story" "$tmp/starter/story.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_issues" "$tmp/starter/issues.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_postgresql_conf" "$PG_FIXTURES/postgresql.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_conf" "$PG_FIXTURES/pg_hba.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_envelopes" "$PG_FIXTURES/envelopes.conf" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_password" "$tmp/player_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_key" "$tmp/id" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null

info "deploying stack $STACK (bastion published on port $PORT)"
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

for s in "$BASTION" "$DB"; do
    if c=$(wait_healthy "$s"); then
        pass "$s deployed and container healthy ($c)"
    else
        fail "$s did not become healthy"
        docker service ps --no-trunc "$s" || true
        docker service logs --tail 60 "$s" 2>&1 || true
        exit 1
    fi
done
B=$(container "$BASTION")
D=$(container "$DB")

# --- players' side: password login on the published port -------------------------
SSH_OPTS="-p $PORT -o UserKnownHostsFile=$tmp/known_hosts -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1"
pb() {  # pb <command>: run <command> on the bastion as player, logged in with the password
    SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force \
        timeout 120 ssh $SSH_OPTS player@127.0.0.1 "$@" </dev/null
}
gm() { docker exec -i "$B" "$@"; }
hostkey() { ssh-keyscan -T 5 -t ed25519 -p "$PORT" 127.0.0.1 2>/dev/null | ssh-keygen -lf - 2>/dev/null | cut -d' ' -f2; }

u=$(pb id -un 2>&1)
[ "$u" = player ] && pass "password login as player on port $PORT" || fail "password login: $u"
check "wrong password refused" sh -c "! SSH_ASKPASS=$tmp/askpass_bad_password SSH_ASKPASS_REQUIRE=force timeout 30 ssh $SSH_OPTS player@127.0.0.1 true </dev/null"
check "root login refused" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force timeout 30 ssh $SSH_OPTS root@127.0.0.1 true </dev/null"
check "public-key login refused" sh -c "! timeout 30 ssh -p $PORT -o UserKnownHostsFile=$tmp/known_hosts -o BatchMode=yes -o LogLevel=ERROR -o PreferredAuthentications=publickey -o IdentitiesOnly=yes -i $tmp/id player@127.0.0.1 true"
eff=$(gm sshd -T -f /etc/ssh/sshd_config 2>/dev/null | grep -E '^(passwordauthentication|pubkeyauthentication|permitrootlogin|allowtcpforwarding|persourcepenalties|allowusers) ' | sort | tr '\n' ';')
[ "$eff" = "allowtcpforwarding no;allowusers player;passwordauthentication yes;permitrootlogin no;persourcepenalties no;pubkeyauthentication no;" ] \
    && pass "sshd effective settings ($eff)" || fail "sshd effective settings: $eff"

# --- home and starter pack ------------------------------------------------------
ok=1
for f in README.md story.md issues.md; do
    [ "$(pb cat "$f" 2>&1)" = "$(cat "$tmp/starter/$f")" ] || ok=0
done
[ "$ok" = 1 ] && pass "starter pack copied into the home (README.md, story.md, issues.md)" || fail "starter pack content"
pb "echo 'audit notes' > ~/report.md" && pass "~/report.md is writable" || fail "~/report.md not writable"
m=$(gm stat -c '%a %U:%G' /home/player /home/player/.ssh /home/player/.ssh/id_ed25519 /home/player/.pgpass /home/player/.gm-starter-copied /run/gm/shadow | tr '\n' ' ')
[ "$m" = "750 player:player 700 player:player 600 player:player 600 player:player 444 root:root 640 root:shadow " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"

# --- inner hop: SSH with the key, psql as dba ----------------------------------------
u=$(pb ssh db id -un 2>&1)
[ "$u" = player ] && pass "from the bastion: ssh db with the key, no host-key prompt" || fail "ssh db: $u"
w=$(pb "psql -h db -XAtc 'select current_user, current_setting(\$\$server_version_num\$\$)'" 2>&1)
case $w in "dba|18"*) pass "from the bastion: psql -h db as dba through ~/.pgpass ($w)" ;; *) fail "psql -h db: $w" ;; esac
check "no known_hosts entry kept for in-game names" sh -c "! docker exec $B test -e /home/player/.ssh/known_hosts"
dbip=$(pb getent hosts db 2>/dev/null | head -n 1 | cut -d" " -f1)
out=$(pb ssh -o BatchMode=yes "$dbip" true 2>&1)
case $out in *"Host key verification failed"*) pass "dotted names ($dbip) keep OpenSSH's host-key checks" ;;
    *) fail "dotted name $dbip: $out" ;; esac

# --- validator ------------------------------------------------------------------
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green (exit 0: $out)" || fail "gm-validate: exit $rc: $out"
out=$(docker exec -u player "$B" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as player green (exit 0)" || fail "GM validator: exit $rc: $out"
out=$(docker exec "$B" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 2 ] && pass "validator run as root is an ERROR (exit 2)" || fail "validator as root: exit $rc: $out"
pb chmod 0644 .pgpass
out=$(pb gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED pgpass: '; then
    pass "gm-validate red on a loose ~/.pgpass (exit 1: $out)"
else
    fail "loose .pgpass: exit $rc: $out"
fi
pb chmod 0600 .pgpass
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green again after fixing" || fail "after fix: exit $rc: $out"

# --- database node replaced: new host key, ssh db still works ------------------------
fp_db=$(pb "ssh-keyscan -T 5 -t ed25519 db 2>/dev/null | ssh-keygen -lf - | cut -d' ' -f2" 2>/dev/null)
info "replacing the database node (docker service update --force)"
docker service update --force --detach "$DB" >/dev/null 2>&1
if D2=$(wait_healthy "$DB" "$D"); then
    pass "new database container healthy ($D2)"
else
    fail "new database container did not become healthy"
fi
fp_db2=$(pb "ssh-keyscan -T 5 -t ed25519 db 2>/dev/null | ssh-keygen -lf - | cut -d' ' -f2" 2>/dev/null)
[ -n "$fp_db" ] && [ -n "$fp_db2" ] && [ "$fp_db" != "$fp_db2" ] \
    && pass "the database node's host key changed ($fp_db -> $fp_db2)" || fail "db host key: '$fp_db' -> '$fp_db2'"
u=$(pb ssh db id -un 2>&1)
[ "$u" = player ] && pass "ssh db still works after the node replacement" || fail "ssh db after replacement: $u"

# --- bastion replaced: host key, home and edits kept ------------------------------
fp=$(hostkey)
pb "echo 'my notes' >> README.md" || fail "player edits README.md"
info "replacing the bastion (docker service update --force)"
docker service update --force --detach "$BASTION" >/dev/null 2>&1
if B2=$(wait_healthy "$BASTION" "$B"); then
    pass "new bastion container healthy ($B2)"
    B=$B2
else
    fail "new bastion container did not become healthy"
fi
fp2=$(hostkey)
[ -n "$fp" ] && [ "$fp" = "$fp2" ] && pass "bastion host key kept across a new container ($fp)" || fail "bastion host key: '$fp' -> '$fp2'"
u=$(pb id -un 2>&1)
[ "$u" = player ] && pass "password login on the new bastion (known_hosts unchanged)" || fail "login after replacement: $u"
w=$(pb cat report.md 2>&1)
[ "$w" = "audit notes" ] && pass "~/report.md kept in a new container" || fail "report.md after replacement: $w"
w=$(pb tail -n 1 README.md 2>&1)
[ "$w" = "my notes" ] && pass "player's starter-pack edits kept (not copied again)" || fail "README.md after replacement: $w"
u=$(pb ssh db id -un 2>&1)
[ "$u" = player ] && pass "inner hop works from the new bastion" || fail "ssh db from new bastion: $u"
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green in the new container" || fail "validator in new container: exit $rc: $out"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $B)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $B touch /usr/local/sbin/x"
check "player cannot write sshd_config" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 'echo x >> /etc/ssh/sshd_config' </dev/null"
for s in player_password player_ssh_key dba_password; do
    check "player cannot read the $s secret file" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 cat /opt/gm/secrets/$s </dev/null"
done
check "player cannot read /etc/shadow" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 cat /etc/shadow </dev/null"
check "no sudo on the bastion" sh -c "! docker exec $B sh -c 'command -v sudo'"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$B")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$B")
[ "$mnt" = volume ] && pass "/run is a named volume (capture W1-E)" || fail "/run mount: $mnt"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$BASTION" 2>&1 || true
exit 1
