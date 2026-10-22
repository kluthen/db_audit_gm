#!/bin/sh
# Stack test of the bastion brick (build plan v0.1, chunk 3, and v0.2,
# chunk 7, Done when).
#
# Deploys the bastion, a PostgreSQL node and a stub web interface as a
# three-service Swarm stack (stack.test.yml), with the starter pack, the
# seed files, the stub and the secrets as external configs and secrets
# created here, then
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
#   - the web front (port GMTEST_BASTION_WEB_PORT): 401 and a challenge
#     without the tools password on every path (/, /stub, /nothing/ too),
#     with it the route list at /, /stub redirected, 404 elsewhere, and
#     the stub reached under /stub/,
#     the path unchanged, no Authorization header upstream, the stub's own
#     challenge not passed on, 502 for a route whose upstream is down;
#   - read-only root, capabilities, `/run` volume, secrets unreadable;
#   - with the routes emptied, port 8080 unpublished and no tools_password
#     secret: the front does not run, the bastion is healthy, SSH answers.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), both images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.2.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres
# debian:13-slim (the stub's image), an OpenSSH client (8.4 or later) and
# curl on this host, and free TCP ports GMTEST_BASTION_PORT (default 22222)
# and GMTEST_BASTION_WEB_PORT (default 28080).
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
STUB=${STACK}_stub
STUB_IMAGE=debian:13-slim
PORT=${GMTEST_BASTION_PORT:-22222}
WPORT=${GMTEST_BASTION_WEB_PORT:-28080}
export GMTEST_BASTION_PORT=$PORT GMTEST_BASTION_WEB_PORT=$WPORT
LABEL=dbagm.test=chunk3-bastion
CONFIGS="starter_readme starter_story starter_issues seed_postgresql_conf seed_pg_hba_conf envelopes stub_upstream"
SECRETS="player_password player_ssh_key player_ssh_pubkey dba_password tools_password monitoring_password"
VOLUMES="bastion_home bastion_hostkeys bastion_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run"

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

for i in "$IMAGE" "$PG_IMAGE" "$STUB_IMAGE"; do
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
# The tools password, with a colon: basic authentication splits at the first.
TOOLS_PASSWORD="t00ls:$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf '%s' "$TOOLS_PASSWORD" > "$tmp/tools_password"
# The database node's monitoring role password (postgres 0.2.0); unused here.
printf 'mon%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
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
docker config create -l "$LABEL" "${STACK}_stub_upstream" "$HERE/fixtures/stub-upstream.pl" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_password" "$tmp/player_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_key" "$tmp/id" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_tools_password" "$tmp/tools_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_monitoring_password" "$tmp/monitoring_password" >/dev/null

info "deploying stack $STACK (bastion published on ports $PORT and $WPORT)"
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

# --- web front ---------------------------------------------------------------------
# The stub has no health check: wait until the front reaches it.
URL=http://127.0.0.1:$WPORT
web() {  # web <curl options...>: status code; headers in $tmp/h, body in $tmp/b
    curl -s -m 10 -D "$tmp/h" -o "$tmp/b" -w '%{http_code}' "$@" 2>/dev/null
}
i=0
while [ "$i" -lt 60 ] && [ "$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/")" != 200 ]; do
    sleep 2; i=$((i + 2))
done
code=$(web "$URL/stub/")
if [ "$code" = 401 ] && grep -qi '^WWW-Authenticate: Basic realm="db_audit_gm web front"' "$tmp/h"; then
    pass "web front without the tools password: 401 and a basic-authentication challenge"
else
    fail "web front without the password: $code $(tr -d '\r' < "$tmp/h" | grep -i '^www-auth')"
fi
# The front's own answers too: the route list, a path outside the routes,
# a route without its trailing slash.
for p in / /nothing/ /stub; do
    code=$(web "$URL$p")
    if [ "$code" = 401 ] && grep -qi '^WWW-Authenticate: Basic realm="db_audit_gm web front"' "$tmp/h"; then
        pass "web front without the tools password, $p: 401 and the challenge"
    else
        fail "web front without the password, $p: $code $(tr -d '\r' < "$tmp/h" | grep -i -e '^www-auth' -e '^location')"
    fi
done
code=$(web -u "player:wrong password" "$URL/stub/")
[ "$code" = 401 ] && pass "web front with a wrong password: 401" || fail "wrong tools password: $code"
code=$(web -u "admin:$TOOLS_PASSWORD" "$URL/stub/")
[ "$code" = 401 ] && pass "web front with another user name: 401" || fail "user admin: $code"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/graph?g0.expr=up")
if [ "$code" = 200 ] && grep -qx 'GET /stub/graph?g0.expr=up HTTP/1.1' "$tmp/b"; then
    pass "with the tools password: the stub reached under /stub/, path and query unchanged"
else
    fail "with the tools password: $code $(head -n 2 "$tmp/b")"
fi
check "no Authorization header reaches the upstream" sh -c "! grep -qi '^authorization:' $tmp/b"
check "the upstream sees the front's Host (127.0.0.1:$WPORT)" grep -qix "host: 127.0.0.1:$WPORT" "$tmp/b"
check "the upstream sees X-Forwarded-Proto http" grep -qix 'x-forwarded-proto: http' "$tmp/b"
check "the upstream's own challenge is not passed on" sh -c "! grep -qi '^www-authenticate:' $tmp/h"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/stub")
[ "$code" = 301 ] && grep -qi '^Location: /stub/' "$tmp/h" \
    && pass "/stub redirects to /stub/" || fail "/stub: $code $(grep -i '^location' "$tmp/h")"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/")
[ "$code" = 200 ] && grep -qx '/other/' "$tmp/b" && grep -qx '/stub/' "$tmp/b" \
    && grep -qi '^Content-Type: text/plain' "$tmp/h" \
    && pass "/ lists the routes as plain text (/other/, /stub/)" || fail "/: $code $(cat "$tmp/b")"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/nothing/")
[ "$code" = 404 ] && grep -qx 'No web interface at this path; see /' "$tmp/b" \
    && pass "a path outside the routes: 404" || fail "/nothing/: $code $(head -n 2 "$tmp/b")"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/nothing")
[ "$code" = 404 ] && pass "a path outside the routes, no trailing slash: 404" || fail "/nothing: $code"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/other/")
[ "$code" = 502 ] && pass "a route whose upstream is down: 502" || fail "/other/: $code"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/")
[ "$code" = 200 ] && pass "the other routes still answer" || fail "/stub/ after /other/: $code"
users=$(gm ps -o user= -C nginx | sort -u | tr '\n' ' ')
[ "$users" = "www-data " ] && pass "nginx runs as www-data" || fail "nginx users: $users"
m=$(gm stat -c '%a %U:%G' /run/web-front /run/web-front/htpasswd /run/web-front/nginx.conf | tr '\n' ' ')
[ "$m" = "750 root:www-data 440 root:www-data 444 root:root " ] \
    && pass "front's files ($m)" || fail "front's files: $m"
check "player cannot read the front's password file" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 cat /run/web-front/htpasswd </dev/null"
rss=$(gm ps -o rss= -C nginx | awk '{ s += $1 } END { print s }')
info "nginx resident memory: ${rss} KiB (master and worker)"
info "bastion container memory with the front: $(docker stats --no-stream --format '{{.MemUsage}}' "$B")"
gm /command/s6-svc -d /run/service/web-front
sleep 2
out=$(gm /usr/local/lib/gm/healthcheck 2>&1); rc=$?
[ "$rc" -ne 0 ] && [ "$out" = "web-front is not up" ] \
    && pass "health check fails while the front is down ($out)" || fail "health check, front down: exit $rc: $out"
gm /command/s6-svc -u /run/service/web-front
sleep 2
out=$(gm /usr/local/lib/gm/healthcheck 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "health check passes once the front is back" || fail "health check, front back: exit $rc: $out"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $B)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $B touch /usr/local/sbin/x"
check "player cannot write sshd_config" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 'echo x >> /etc/ssh/sshd_config' </dev/null"
for s in player_password player_ssh_key dba_password tools_password; do
    check "player cannot read the $s secret file" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 cat /opt/gm/secrets/$s </dev/null"
done
check "player cannot read /etc/shadow" sh -c "! SSH_ASKPASS=$tmp/askpass_player_password SSH_ASKPASS_REQUIRE=force ssh $SSH_OPTS player@127.0.0.1 cat /etc/shadow </dev/null"
check "no sudo on the bastion" sh -c "! docker exec $B sh -c 'command -v sudo'"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$B")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$B")
[ "$mnt" = volume ] && pass "/run is a named volume (capture W1-E)" || fail "/run mount: $mnt"

# --- no route: the front does not run (spec D103) ----------------------------------
# As a game without a web interface: GM_WEB_ROUTES empty, port 8080 not
# published, and no tools_password secret, which the bastion then needs not.
info "emptying the routes (no published web port, no tools_password)"
docker service update --detach --env-add GM_WEB_ROUTES= \
    --publish-rm "published=$WPORT,target=8080,mode=host" \
    --secret-rm "${STACK}_tools_password" "$BASTION" >/dev/null 2>&1
if B3=$(wait_healthy "$BASTION" "$B"); then
    pass "bastion without routes healthy ($B3)"
    B=$B3
else
    fail "bastion without routes did not become healthy"
fi
st=$(gm /command/s6-svstat -o up,wantedup /run/service/web-front 2>&1)
[ "$st" = "false false" ] && pass "web-front down and not wanted up (s6-svstat: $st)" || fail "web-front status: $st"
n=$(gm awk '$2 ~ /:1F90$/ && $4 == "0A"' /proc/net/tcp /proc/net/tcp6 2>/dev/null | wc -l)
[ "$n" -eq 0 ] && pass "nothing listens on port 8080 in the container" || fail "$n listener(s) on port 8080"
check "no nginx process" sh -c "! docker exec $B ps -C nginx -o pid="
check "no /run/web-front" sh -c "! docker exec $B test -e /run/web-front"
p=$(docker service inspect -f '{{range .Spec.EndpointSpec.Ports}}{{.TargetPort}}/{{.PublishMode}} {{end}}' "$BASTION")
q=$(docker inspect -f '{{range $p, $b := .NetworkSettings.Ports}}{{if $b}}{{$p}} {{end}}{{end}}' "$B")
[ "$p" = "22/host " ] && [ "$q" = "22/tcp " ] && pass "only port 22 published (service: $p; container: $q)" \
    || fail "published ports: service $p; container $q"
check "the web port refuses connections" sh -c "! curl -s -m 5 -o /dev/null http://127.0.0.1:$WPORT/"
u=$(pb id -un 2>&1)
[ "$u" = player ] && pass "SSH answers: password login as player" || fail "login without routes: $u"
info "bastion container memory without the front: $(docker stats --no-stream --format '{{.MemUsage}}' "$B")"
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green without routes" || fail "validator without routes: exit $rc: $out"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$BASTION" 2>&1 || true
exit 1
