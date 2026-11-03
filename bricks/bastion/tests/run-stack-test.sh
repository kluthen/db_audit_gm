#!/bin/sh
# Stack test of the bastion brick (build plan v0.1, chunk 3, v0.2,
# chunk 7, and v0.4, chunk 19a, Done when).
#
# Deploys the bastion, a PostgreSQL node and a stub web interface as a
# three-service Swarm stack (stack.test.yml), with the starter pack
# (tests/fixtures/starter, its optional data-policy.md included), the
# seed files, the stub and the secrets as external configs and secrets
# created here, then
# checks, from this host as a player would and from the GM side
# (docker exec):
#   - both containers become healthy;
#   - password login as `player` on the published port, nothing else;
#   - the starter pack's four files are in the home, ~/report.md is writable;
#   - from the bastion, `ssh db` with the key (ServerAliveInterval 60) and
#     `psql -h db` as dba;
#   - the validator is green, and red when ~/.pgpass is broken;
#   - after the database node is replaced (new host key), `ssh db` works;
#   - after the bastion is replaced, its host key, the home and the
#     player's edits are kept, and the starter pack is not copied again;
#   - the web front (port GMTEST_BASTION_WEB_PORT): 401 and a challenge
#     without the tools password on every path (/, /stub, /nothing/ too),
#     with it the page at / (README, story, issues, data policy, in that
#     order, a README table as an HTML table, raw HTML omitted, the links
#     to the routes and nothing else; a player's edit of ~/story.md before
#     the bastion's replacement absent from it), /stub redirected, 404
#     elsewhere, and the stub reached under /stub/,
#     the path unchanged, no Authorization header upstream, the stub's own
#     challenge not passed on, 502 for a route whose upstream is down;
#   - read-only root, capabilities, `/run` volume, secrets unreadable;
#   - with the routes emptied (spec D224): the front up on port 8080, 401
#     without the password, the page alone with no web-interface section
#     or link, the health check green, the data policy still copied;
#   - without a data policy: no ~/data-policy.md, no section, no link;
#   - without a required starter file (issues.md): the container refused;
#   - the validator green in every state the bastion starts in.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), both images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# debian:13-slim (the stub's image), an OpenSSH client (8.4 or later) and
# curl on this host, and free TCP ports GMTEST_BASTION_PORT (default 22222)
# and GMTEST_BASTION_WEB_PORT (default 28080).
# Usage: sh bricks/bastion/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
STARTER=$HERE/fixtures/starter
STACK=gmtest-bastion
IMAGE=127.0.0.1:5000/dbagm/bastion:0.5.0
PG_IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.0
BASTION=${STACK}_bastion
DB=${STACK}_db
NET=${STACK}_net
STUB=${STACK}_stub
STUB_IMAGE=debian:13-slim
PORT=${GMTEST_BASTION_PORT:-22222}
WPORT=${GMTEST_BASTION_WEB_PORT:-28080}
export GMTEST_BASTION_PORT=$PORT GMTEST_BASTION_WEB_PORT=$WPORT
LABEL=dbagm.test=chunk3-bastion
CONFIGS="starter_readme starter_story starter_issues starter_policy seed_postgresql_conf seed_pg_hba_conf envelopes stub_upstream"
SECRETS="player_password player_ssh_key player_ssh_pubkey dba_password tools_password monitoring_password"
VOLUMES="bastion_home bastion_hostkeys bastion_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run db_cronspool"

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
# The database node's monitoring role password (postgres 0.5.0); unused here.
printf 'mon%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
for p in player_password bad_password; do
    printf '#!/bin/sh\ncat %s\n' "$tmp/$p" > "$tmp/askpass_$p"
    chmod 0700 "$tmp/askpass_$p"
done

docker config create -l "$LABEL" "${STACK}_starter_readme" "$STARTER/README.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_story" "$STARTER/story.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_issues" "$STARTER/issues.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_policy" "$STARTER/data-policy.md" >/dev/null
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
for f in README.md story.md issues.md data-policy.md; do
    [ "$(pb cat "$f" 2>&1)" = "$(cat "$STARTER/$f")" ] || ok=0
done
[ "$ok" = 1 ] && pass "starter pack copied into the home (README.md, story.md, issues.md, data-policy.md)" \
    || fail "starter pack content"
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
w=$(pb ssh -G db 2>&1 | grep -i '^serveraliveinterval ' || true)
[ "$w" = "serveraliveinterval 60" ] && pass "inner hop keeps an idle flow alive ($w)" || fail "ssh -G db: '$w'"
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
pb "echo 'player edit of the story' >> story.md" || fail "player edits story.md"
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
sections() {  # sections <page>: its section ids, in order, space-separated
    grep -o '<section id="[a-z-]*">' "$1" | sed 's/^<section id="\(.*\)">$/\1/' | tr '\n' ' '
}
links() {  # links <page>: every href in it, in order, space-separated
    grep -o 'href="[^"]*"' "$1" | sed 's/^href="\(.*\)"$/\1/' | tr '\n' ' '
}
section() {  # section <page> <id>: that section's HTML
    sed -n "/<section id=\"$2\">/,/<\/section>/p" "$1"
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
# The front's own answers too: the page, a path outside the routes,
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
[ "$code" = 200 ] && grep -qi '^Content-Type: text/html; charset=utf-8' "$tmp/h" \
    && pass "/ with the tools password: the page, HTML in UTF-8" \
    || fail "/: $code $(tr -d '\r' < "$tmp/h" | grep -i '^content-type')"
w=$(sections "$tmp/b")
[ "$w" = "readme story issues data-policy web-interfaces " ] \
    && pass "the page: README, story, issues, data policy, then the web interfaces ($w)" \
    || fail "the page's sections: $w"
w=$(links "$tmp/b")
[ "$w" = "#readme #story #issues #data-policy #web-interfaces /other/ /stub/ " ] \
    && pass "the page's links: its sections and the routes, nothing else ($w)" \
    || fail "the page's links: $w"
section "$tmp/b" readme | grep -q '<td>db</td>' && section "$tmp/b" readme | grep -q '<table>' \
    && pass "the README's table rendered as an HTML table" || fail "README table: $(section "$tmp/b" readme)"
grep -q 'raw HTML omitted' "$tmp/b" && ! grep -qi '<script' "$tmp/b" \
    && pass "raw HTML not passed through (the README's <script> omitted)" || fail "raw HTML in the page"
section "$tmp/b" data-policy | grep -q '<h1>Data policy (stack test)</h1>' \
    && pass "the data policy rendered in its section" || fail "data policy section: $(section "$tmp/b" data-policy)"
if pb grep -qx "'player edit of the story'" story.md && ! grep -q 'player edit of the story' "$tmp/b" \
   && ! grep -q 'my notes' "$tmp/b" && section "$tmp/b" story | grep -q 'A fictional customer'; then
    pass "the page shows the starter pack as handed over: the player's ~/story.md edit absent after a restart"
else
    fail "the page and the player's edits: $(section "$tmp/b" story)"
fi
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
m=$(gm stat -c '%a %U:%G' /run/web-front /run/web-front/htpasswd /run/web-front/nginx.conf /run/web-front/www/index.html | tr '\n' ' ')
[ "$m" = "750 root:www-data 440 root:www-data 444 root:root 440 root:www-data " ] \
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

# --- no route: the front serves the page alone (spec D224) -----------------------
# As a game without a web interface: GM_WEB_ROUTES empty, port 8080 still
# published and tools_password still mounted, as every game now has them.
# The GM side first removes ~/data-policy.md and the starter marker, so
# this start copies the data policy again, without a route.
info "emptying the routes (port 8080 and tools_password kept)"
gm rm -f /home/player/data-policy.md /home/player/.gm-starter-copied
docker service update --detach --env-add GM_WEB_ROUTES= "$BASTION" >/dev/null 2>&1
if B3=$(wait_healthy "$BASTION" "$B"); then
    pass "bastion without routes healthy ($B3)"
    B=$B3
else
    fail "bastion without routes did not become healthy"
fi
st=$(gm /command/s6-svstat -o up,wantedup /run/service/web-front 2>&1)
[ "$st" = "true true" ] && pass "web-front up without routes (s6-svstat: $st)" || fail "web-front status: $st"
n=$(gm awk '$2 ~ /:1F90$/ && $4 == "0A"' /proc/net/tcp /proc/net/tcp6 2>/dev/null | wc -l)
[ "$n" -ge 1 ] && pass "the front listens on port 8080 in the container" || fail "no listener on port 8080"
p=$(docker service inspect -f '{{range .Spec.EndpointSpec.Ports}}{{.TargetPort}}/{{.PublishMode}} {{end}}' "$BASTION")
q=$(docker inspect -f '{{range $p, $b := .NetworkSettings.Ports}}{{if $b}}{{$p}} {{end}}{{end}}' "$B")
[ "$p" = "22/host 8080/host " ] && [ "$q" = "22/tcp 8080/tcp " ] \
    && pass "ports 22 and 8080 published (service: $p; container: $q)" \
    || fail "published ports: service $p; container $q"
i=0
while [ "$i" -lt 30 ] && [ "$(web "$URL/")" != 401 ]; do
    sleep 1; i=$((i + 1))
done
code=$(web "$URL/")
if [ "$code" = 401 ] && grep -qi '^WWW-Authenticate: Basic realm="db_audit_gm web front"' "$tmp/h"; then
    pass "without routes, / without the tools password: 401 and the challenge"
else
    fail "without routes, / without the password: $code"
fi
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/")
w=$(sections "$tmp/b")
[ "$code" = 200 ] && [ "$w" = "readme story issues data-policy " ] \
    && pass "without routes, the page alone: README, story, issues, data policy ($w)" \
    || fail "without routes, the page: $code, sections $w"
w=$(links "$tmp/b")
[ "$w" = "#readme #story #issues #data-policy " ] && ! grep -q 'Web interfaces' "$tmp/b" \
    && pass "without routes, no web-interface section or link ($w)" || fail "without routes, links: $w"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/")
[ "$code" = 404 ] && pass "without routes, a former route's path: 404" || fail "/stub/ without routes: $code"
out=$(gm /usr/local/lib/gm/healthcheck 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "health check green without routes" || fail "health check without routes: exit $rc: $out"
[ "$(pb cat data-policy.md 2>&1)" = "$(cat "$STARTER/data-policy.md")" ] \
    && pass "the data policy copied again into the home, without routes" || fail "data-policy.md without routes"
w=$(pb tail -n 1 README.md 2>&1)
[ "$w" = "my notes" ] && pass "the copy left the player's own files as they were" || fail "README.md after the copy: $w"
u=$(pb id -un 2>&1)
[ "$u" = player ] && pass "SSH answers: password login as player" || fail "login without routes: $u"
rss=$(gm ps -o rss= -C nginx | awk '{ s += $1 } END { print s }')
info "at rest without routes: nginx resident memory ${rss} KiB (master and worker)"
info "at rest without routes: bastion container memory $(docker stats --no-stream --format '{{.MemUsage}}' "$B")"
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green without routes" || fail "validator without routes: exit $rc: $out"

# --- no data policy: no file, no section, no link (spec D221) ---------------------
# As a scenario without governance: data-policy.md not mapped, so not
# mounted. The GM side removes the home's copy and the marker first, so
# this start would copy it if it were there.
info "removing the data policy from the starter pack"
gm rm -f /home/player/data-policy.md /home/player/.gm-starter-copied
docker service update --detach --config-rm "${STACK}_starter_policy" "$BASTION" >/dev/null 2>&1
if B4=$(wait_healthy "$BASTION" "$B"); then
    pass "bastion without a data policy healthy ($B4)"
    B=$B4
else
    fail "bastion without a data policy did not become healthy"
fi
check "no data policy in the starter pack" sh -c "! docker exec $B test -e /opt/gm/starter/data-policy.md"
check "no ~/data-policy.md in the home" sh -c "! docker exec $B test -e /home/player/data-policy.md"
check "the starter marker written again" docker exec "$B" test -f /home/player/.gm-starter-copied
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/")
w=$(sections "$tmp/b")
[ "$code" = 200 ] && [ "$w" = "readme story issues " ] \
    && pass "without a data policy, the page: README, story, issues ($w)" \
    || fail "without a data policy, the page: $code, sections $w"
w=$(links "$tmp/b")
[ "$w" = "#readme #story #issues " ] && ! grep -qi 'data policy' "$tmp/b" \
    && pass "without a data policy, no such section or link ($w)" || fail "without a data policy, links: $w"
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green without a data policy" || fail "validator without a data policy: exit $rc: $out"

# --- a required starter file missing: the container is refused --------------------
info "removing issues.md from the starter pack"
docker service update --detach --config-rm "${STACK}_starter_issues" "$BASTION" >/dev/null 2>&1
i=0; found=0
while [ "$i" -lt 90 ]; do
    if docker service logs "$BASTION" 2>&1 \
        | grep -q 'gm-entrypoint: fatal: starter pack file /opt/gm/starter/issues.md is missing'; then
        found=1; break
    fi
    sleep 3; i=$((i + 3))
done
[ "$found" = 1 ] && pass "a missing required starter file refused (issues.md)" \
    || fail "no refusal of a missing issues.md in the logs"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$BASTION" 2>&1 || true
exit 1
