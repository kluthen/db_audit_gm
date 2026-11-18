#!/bin/sh
# Stack test of the bastion brick (build plan v0.1, chunk 3, v0.2,
# chunk 7, v0.4, chunk 19a, and v0.5, chunk 17a, Done when; gate G11.2).
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
#   - v0.5 (master spec 7.3; spec D363, D365, D433): partners.md and
#     data-register.md copied and on the page ("Partners" then "Data
#     register" after the data policy), partners.md's
#     {{credential:demo_customer}} replaced by the mounted secret in the home
#     and on the page, the value accepted by the external lab's endpoint
#     (the stub, holding the same secret; with bash alone and with curl,
#     the players' HTTP client, run as player) and a wrong one refused; cold
#     storage's console route: GET /cold-storage/ and GET
#     /cold-storage/manifests (query kept) reach the stub as / and
#     /manifests with Host cold-storage, POST /cold-storage/shipments, any
#     other path or method under it and another partner's hostname 404;
#   - without a data policy, partners.md and data-register.md: no file, no
#     section, no link;
#   - partners.md naming a credential with no secret: the container refused;
#   - without a required starter file (issues.md): the container refused;
#   - the validator green in every state the bastion starts in;
#   - v0.6 (master spec 7.1 to 7.7, 12.1; capture W2 items 1 and 2): the
#     home at / (Sites: the routes, Reports; Documents: each starter file
#     present; Tools: each brick page), every link on it answering; the
#     documentation site /docs/<id> and /docs/bricks/<brick-id> rendered
#     from the starter pack as handed over (a player's edit of a home copy
#     changes no page), headings with GitHub's ids, links between starter
#     files rewritten to /docs/, every page behind the basic
#     authentication; no page for a brick not delivered; jq and tmux as
#     player, jq reading a Prometheus API answer (the stub's) through curl;
#     a pgBadger report made on db and copied into ~/reports/ in one hop,
#     listed and served with the sandbox header, a path outside the folder
#     and a symbolic link 404; with two routes and three documents, only
#     those on the home, no dead link; the footprint at rest.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), both images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# debian:13-slim (the stub's image), an OpenSSH client (8.4 or later) and
# curl on this host, and free TCP ports GMTEST_BASTION_PORT (default 22222)
# and GMTEST_BASTION_WEB_PORT (default 28080).
# Usage: sh bricks/bastion/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
STARTER=$HERE/fixtures/starter
STACK=gmtest-bastion
IMAGE=127.0.0.1:5000/dbagm/bastion:0.6.0
PG_IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.1
BASTION=${STACK}_bastion
DB=${STACK}_db
NET=${STACK}_net
STUB=${STACK}_stub
STUB_IMAGE=debian:13-slim
PORT=${GMTEST_BASTION_PORT:-22222}
WPORT=${GMTEST_BASTION_WEB_PORT:-28080}
export GMTEST_BASTION_PORT=$PORT GMTEST_BASTION_WEB_PORT=$WPORT
LABEL=dbagm.test=chunk3-bastion
CONFIGS="starter_readme starter_story starter_issues starter_policy starter_partners starter_register starter_overview doc_bastion doc_postgres seed_postgresql_conf seed_pg_hba_conf envelopes stub_upstream"
SECRETS="player_password player_ssh_key player_ssh_pubkey dba_password tools_password monitoring_password http_demo_customer"
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
# `base:` against the image's /etc/os-release (v0.6 capture W1 item 1)
if out=$(sh "$HERE/../../../tools/tests/check-base.sh" "$HERE/.." "$IMAGE"); then pass "$out"; else fail "$out"; fi
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
# The external lab's customer credential handed over (W4 item 1): 16
# characters of the players' alphabet, as gmctl deploy writes one.
DEMO_KEY=$(head -c 1024 /dev/urandom | LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789' | cut -c1-16)
printf '%s' "$DEMO_KEY" > "$tmp/http_demo_customer"
[ "${#DEMO_KEY}" -eq 16 ] || { echo "could not make the credential" >&2; exit 2; }
sed "s/{{credential:demo_customer}}/$DEMO_KEY/" "$STARTER/partners.md" > "$tmp/partners.resolved"
for p in player_password bad_password; do
    printf '#!/bin/sh\ncat %s\n' "$tmp/$p" > "$tmp/askpass_$p"
    chmod 0700 "$tmp/askpass_$p"
done

docker config create -l "$LABEL" "${STACK}_starter_readme" "$STARTER/README.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_story" "$STARTER/story.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_issues" "$STARTER/issues.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_policy" "$STARTER/data-policy.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_partners" "$STARTER/partners.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_register" "$STARTER/data-register.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_starter_overview" "$STARTER/network-overview.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_doc_bastion" "$HERE/../docs/player.md" >/dev/null
docker config create -l "$LABEL" "${STACK}_doc_postgres" "$HERE/../../postgres/docs/player.md" >/dev/null
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
docker secret create -l "$LABEL" "${STACK}_http_demo_customer" "$tmp/http_demo_customer" >/dev/null

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
for f in README.md story.md issues.md data-policy.md data-register.md network-overview.md; do
    [ "$(pb cat "$f" 2>&1)" = "$(cat "$STARTER/$f")" ] || ok=0
done
[ "$ok" = 1 ] && pass "starter pack copied into the home (README.md, story.md, issues.md, data-policy.md, data-register.md, network-overview.md)" \
    || fail "starter pack content"
w=$(pb cat partners.md 2>&1)
if [ "$w" = "$(cat "$tmp/partners.resolved")" ] && ! printf '%s' "$w" | grep -q '{{credential:'; then
    pass "~/partners.md copied with its placeholder replaced by the credential handed over"
else
    fail "~/partners.md: $w"
fi
# The value as the players read it, sent to the external lab's endpoint
# (the stub, holding the same secret) from the bastion, with bash alone.
order() {  # order <key>: the status line northfield-lab:9090 answers GET /orders with
    pb "exec 3<>/dev/tcp/northfield-lab/9090 && printf 'GET /orders HTTP/1.0\r\nHost: northfield-lab\r\nAuthorization: Bearer %s\r\n\r\n' '$1' >&3 && head -n 1 <&3 | tr -d '\r'" 2>&1
}
key=$(pb "sed -n 's/^- key: \`\(.*\)\`$/\1/p' partners.md" 2>&1)
i=0
while [ "$i" -lt 30 ] && ! order "$key" | grep -q '^HTTP/1.1 '; do sleep 2; i=$((i + 2)); done
w=$(order "$key")
[ "$key" = "$DEMO_KEY" ] && [ "$w" = "HTTP/1.1 200 OK" ] \
    && pass "the credential read in ~/partners.md is accepted by the partner's endpoint ($w)" \
    || fail "the credential at the partner: key '$key', $w"
w=$(order "wrong$key")
[ "$w" = "HTTP/1.1 401 Unauthorized" ] && pass "a wrong credential is refused by the partner's endpoint ($w)" \
    || fail "a wrong credential at the partner: $w"
# The players' HTTP client (access model 4; gate G11.2): curl, run as player.
w=$(pb "curl --version | head -n 1" 2>&1) || true
case $w in "curl "*) pass "curl runs as player on the bastion ($w)" ;; *) fail "curl --version as player: $w" ;; esac
w=$(pb "curl -s -m 10 -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer $key' http://northfield-lab:9090/orders" 2>&1) || true
[ "$w" = 200 ] && pass "the credential accepted by the partner's endpoint through curl, as player ($w)" \
    || fail "curl to the partner with the credential: $w"
# The general-use tools (master spec 7.7; gate G6): jq and tmux, as player;
# jq reading Prometheus' API (the stub answers its form) through curl.
w=$(pb "jq --version" 2>&1)
case $w in jq-1.*) pass "jq runs as player ($w)" ;; *) fail "jq --version as player: $w" ;; esac
w=$(pb "curl -s -m 10 'http://stub:9090/api/v1/query?query=up' | jq -r '.data.result[0].value[1]'" 2>&1)
[ "$w" = 1 ] && pass "jq reads a Prometheus API answer through curl, as player ($w)" \
    || fail "curl | jq on the API: $w"
w=$(pb "tmux -V && tmux new-session -d -s gmtest 'sleep 60' && tmux has-session -t gmtest && tmux kill-server && echo ok" 2>&1)
case $w in "tmux "*ok) pass "tmux runs a session as player ($(printf '%s' "$w" | head -n 1))" ;;
    *) fail "tmux as player: $w" ;; esac
pb "echo 'audit notes' > ~/report.md" && pass "~/report.md is writable" || fail "~/report.md not writable"
m=$(gm stat -c '%a %U:%G' /home/player /home/player/.ssh /home/player/.ssh/id_ed25519 /home/player/.pgpass /home/player/.gm-starter-copied /run/gm/shadow /home/player/reports | tr '\n' ' ')
[ "$m" = "751 player:player 700 player:player 600 player:player 600 player:player 444 root:root 640 root:shadow 755 player:player " ] \
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
[ "$w" = "sites documents " ] && pass "the home: Sites, then Documents ($w)" || fail "the home's sections: $w"
grep -q '<h1>Story (stack test)</h1>' "$tmp/b" \
    && grep -q "what Story (stack test) handed over at the mission's start" "$tmp/b" \
    && pass "the home's header names the customer from the story's heading" \
    || fail "the home's header: $(sed -n '/<header>/,/<\/header>/p' "$tmp/b")"
HOME_ALL="/cold-storage/ /other/ /stub/ /reports/ /docs/readme /docs/story /docs/issues /docs/data-policy /docs/partners /docs/data-register /docs/network-overview /docs/bricks/bastion /docs/bricks/postgres "
w=$(links "$tmp/b")
[ "$w" = "$HOME_ALL" ] \
    && pass "the home's links: the routes, Reports, the seven documents, then Tools, nothing else ($w)" \
    || fail "the home's links: $w"
section "$tmp/b" documents | grep -q '<h3>Tools</h3>' && section "$tmp/b" documents \
    | grep -q '<a href="/docs/bricks/postgres">PostgreSQL node — player notes</a>' \
    && pass "Tools: each brick page by its heading" || fail "Tools: $(section "$tmp/b" documents)"
dead=
for p in $(links "$tmp/b"); do
    case $p in /docs/*|/reports/) ;; *) continue ;; esac
    code=$(web -u "player:$TOOLS_PASSWORD" "$URL$p")
    [ "$code" = 200 ] || dead="$dead $p:$code"
    code=$(web "$URL$p")
    [ "$code" = 401 ] || dead="$dead $p:$code-without-password"
done
[ -z "$dead" ] && pass "every page the home links answers 200, and 401 without the tools password" \
    || fail "dead or open links:$dead"
page() {  # page <path>: GET with the tools password; body in $tmp/b
    web -u "player:$TOOLS_PASSWORD" "$URL$1"
}
code=$(page /docs/partners)
if [ "$code" = 200 ] && grep -q "<code>$DEMO_KEY</code>" "$tmp/b" && ! grep -q 'credential:' "$tmp/b" \
   && grep -q '<h2 id="northfield-veterinary-laboratories">' "$tmp/b"; then
    pass "/docs/partners: the credential handed over, no placeholder, its headings' ids"
else
    fail "/docs/partners: $code $(grep -e '<h' -e 'key' "$tmp/b")"
fi
grep -qi '^Content-Type: text/html; charset=utf-8' "$tmp/h" && grep -q '<a href="/">Home</a>' "$tmp/b" \
    && pass "a page under /docs/: HTML in UTF-8, a link home" || fail "/docs/partners headers: $(cat "$tmp/h")"
code=$(page /docs/network-overview)
if [ "$code" = 200 ] && grep -q '<a href="/docs/partners#northfield-veterinary-laboratories">' "$tmp/b" \
   && grep -q '<a href="#db">db</a>' "$tmp/b" && grep -q '<h3 id="db">db</h3>' "$tmp/b"; then
    pass "/docs/network-overview: its links to partners.md point to /docs/partners#<anchor>, its own anchors resolve"
else
    fail "/docs/network-overview: $code $(grep -e 'href' -e '<h' "$tmp/b")"
fi
code=$(page /docs/readme)
grep -q '<td>db</td>' "$tmp/b" && grep -q '<table>' "$tmp/b" \
    && pass "/docs/readme: the README's table rendered as an HTML table" || fail "README table: $code"
grep -q 'raw HTML omitted' "$tmp/b" && ! grep -qi '<script' "$tmp/b" \
    && pass "raw HTML not passed through (the README's <script> omitted)" || fail "raw HTML in /docs/readme"
page /docs/data-policy >/dev/null; grep -q '<h1 id="data-policy-stack-test">Data policy (stack test)</h1>' "$tmp/b" \
    && pass "/docs/data-policy rendered" || fail "/docs/data-policy: $(grep '<h1' "$tmp/b")"
page /docs/data-register >/dev/null; grep -q '>Data register (stack test)</h1>' "$tmp/b" \
    && pass "/docs/data-register rendered" || fail "/docs/data-register: $(grep '<h1' "$tmp/b")"
code=$(page /docs/story)
if pb grep -qx "'player edit of the story'" story.md && [ "$code" = 200 ] \
   && ! grep -q 'player edit of the story' "$tmp/b" && grep -q 'A fictional customer' "$tmp/b" \
   && page /docs/readme >/dev/null && ! grep -q 'my notes' "$tmp/b"; then
    pass "the pages show the starter pack as handed over: the player's ~/story.md and ~/README.md edits absent after a restart"
else
    fail "the pages and the player's edits: $code $(cat "$tmp/b")"
fi
code=$(page /docs/bricks/postgres)
[ "$code" = 200 ] && grep -q '>PostgreSQL node — player notes</h1>' "$tmp/b" \
    && pass "/docs/bricks/postgres: the brick's player documentation" || fail "/docs/bricks/postgres: $code"
bad=
for p in /docs/bricks/api /docs/bricks/scheduler /docs/nothing /docs/ /docs/readme.html /docs/bricks/; do
    code=$(page "$p")
    [ "$code" = 404 ] || bad="$bad $p:$code"
done
[ -z "$bad" ] && pass "no page for a brick not delivered, nor any other path under /docs/ (404)" \
    || fail "under /docs/, not 404:$bad"

# --- reports (master spec 7.5) ---------------------------------------------------
# A pgBadger report made on db and brought in one hop, then opened; the
# format and prefix given, the fresh log too short for pgBadger to guess them.
w=$(pb "ssh db \"pgbadger -q -f stderr --prefix '%t [%p]: user=%u,db=%d,app=%a,client=%h ' -o pgbadger.html /var/log/postgresql/postgresql-*.log\" && scp -q db:pgbadger.html ~/reports/ && ls ~/reports" 2>&1)
[ "$w" = pgbadger.html ] && pass "a pgBadger report made on db and copied into ~/reports/ in one hop" \
    || fail "pgBadger into ~/reports/: $w"
code=$(page /reports/)
[ "$code" = 200 ] && grep -q '<a href="pgbadger.html">pgbadger.html</a>' "$tmp/b" \
    && grep -qi '^Content-Security-Policy: sandbox allow-scripts' "$tmp/h" \
    && pass "/reports/: the listing, with the sandbox header" || fail "/reports/: $code $(cat "$tmp/h")"
code=$(page /reports/pgbadger.html)
if [ "$code" = 200 ] && grep -qi '^Content-Type: text/html' "$tmp/h" \
   && grep -qi '^Content-Security-Policy: sandbox allow-scripts' "$tmp/h" && grep -qi 'pgbadger' "$tmp/b"; then
    pass "/reports/pgbadger.html served as HTML with Content-Security-Policy: sandbox allow-scripts"
else
    fail "/reports/pgbadger.html: $code $(tr -d '\r' < "$tmp/h")"
fi
code=$(web "$URL/reports/pgbadger.html")
[ "$code" = 401 ] && pass "/reports/ without the tools password: 401" || fail "/reports/ without the password: $code"
code=$(page /reports)
[ "$code" = 301 ] && pass "/reports redirects to /reports/" || fail "/reports: $code"
pb "ln -s /etc/passwd ~/reports/passwd && ln -s / ~/reports/root && ln -s ~ ~/reports/home" >/dev/null 2>&1
bad=
for p in /reports/passwd /reports/root/etc/passwd /reports/home/report.md /reports/../report.md \
         /reports/%2e%2e/report.md /reports/nothing.html; do
    code=$(web -u "player:$TOOLS_PASSWORD" --path-as-is "$URL$p")
    [ "$code" = 404 ] || bad="$bad $p:$code"
done
code=$(web -u "player:$TOOLS_PASSWORD" -X POST -d x "$URL/reports/pgbadger.html")
[ "$code" = 404 ] || bad="$bad POST:$code"
[ -z "$bad" ] && pass "nothing outside ~/reports/ served: a link, a path out of it, a missing file, a POST, all 404" \
    || fail "outside ~/reports/:$bad"
pb "rm -f ~/reports/passwd ~/reports/root ~/reports/home" >/dev/null 2>&1
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/nothing/")
[ "$code" = 404 ] && grep -qx 'No web interface at this path; see /' "$tmp/b" \
    && pass "a path outside the routes: 404" || fail "/nothing/: $code $(head -n 2 "$tmp/b")"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/nothing")
[ "$code" = 404 ] && pass "a path outside the routes, no trailing slash: 404" || fail "/nothing: $code"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/other/")
[ "$code" = 502 ] && pass "a route whose upstream is down: 502" || fail "/other/: $code"
# Cold storage's console (master spec 7.3, spec D363; W4 item 1): GET / and
# GET /manifests only, under the partner's hostname.
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/cold-storage/")
if [ "$code" = 200 ] && grep -qx 'GET / HTTP/1.1' "$tmp/b" && grep -qix 'host: cold-storage' "$tmp/b" \
   && ! grep -qi '^authorization:' "$tmp/b"; then
    pass "console: GET /cold-storage/ reaches cold storage as GET / with Host cold-storage, no Authorization"
else
    fail "console GET /cold-storage/: $code $(head -n 3 "$tmp/b")"
fi
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/cold-storage/manifests?type=wal&from=2026-11-01")
if [ "$code" = 200 ] && grep -qx 'GET /manifests?type=wal&from=2026-11-01 HTTP/1.1' "$tmp/b" \
   && grep -qix 'host: cold-storage' "$tmp/b"; then
    pass "console: GET /cold-storage/manifests reaches /manifests, its query string kept"
else
    fail "console GET /cold-storage/manifests: $code $(head -n 2 "$tmp/b")"
fi
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/cold-storage")
[ "$code" = 301 ] && pass "console: /cold-storage redirects to /cold-storage/" || fail "/cold-storage: $code"
for req in "POST /cold-storage/shipments" "GET /cold-storage/shipments" "POST /cold-storage/manifests" \
           "PUT /cold-storage/" "DELETE /cold-storage/manifests" "GET /cold-storage/manifests/x" \
           "GET /northfield-lab/" "GET /northfield-lab/orders" "GET /partners-api/"; do
    code=$(web -u "player:$TOOLS_PASSWORD" -X "${req%% *}" -d '{}' "$URL${req#* }")
    if [ "$code" = 404 ] && grep -qx 'No web interface at this path; see /' "$tmp/b"; then
        pass "console: $req refused (404, never forwarded)"
    else
        fail "console: $req: $code $(head -n 2 "$tmp/b")"
    fi
done
code=$(web "$URL/cold-storage/manifests")
[ "$code" = 401 ] && pass "console: without the tools password, 401" || fail "console without the password: $code"
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/")
[ "$code" = 200 ] && pass "the other routes still answer" || fail "/stub/ after /other/: $code"
# No status file in this stack (no partner's status page): the s6 service
# status-pages stays down, /status/ answers 404 (master spec 7.6).
st=$(gm /command/s6-svstat -o up,wantedup /run/service/status-pages 2>&1)
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/status/northfield-lab/")
[ "$st" = "false false" ] && [ "$code" = 404 ] \
    && pass "without the status file: status-pages down ($st), /status/northfield-lab/ 404" \
    || fail "without the status file: status-pages $st, /status/: $code"
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
for s in player_password player_ssh_key dba_password tools_password http_demo_customer; do
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
w=$(links "$tmp/b")
[ "$code" = 200 ] && [ "$w" = "/reports/ /docs/readme /docs/story /docs/issues /docs/data-policy /docs/partners /docs/data-register /docs/network-overview /docs/bricks/bastion /docs/bricks/postgres " ] \
    && pass "without routes, the home: Reports alone under Sites, the documents and the tools ($w)" \
    || fail "without routes, the home: $code, links $w"
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

# --- no data policy, partners or register: no file, no section, no link ---------
# As a scenario without governance: or partners (spec D221; v0.5 master
# spec 7.3): data-policy.md, partners.md and data-register.md not mapped, so
# not mounted, and no credential handed over. The GM side removes the home's
# copies and the marker first, so this start would copy them if they were
# there.
# Master spec 12.1: two web routes and three of the seven documents.
info "removing the data policy, partners.md, data-register.md and network-overview.md; two routes"
gm rm -f /home/player/data-policy.md /home/player/partners.md /home/player/data-register.md \
    /home/player/network-overview.md /home/player/.gm-starter-copied
docker service update --detach --config-rm "${STACK}_starter_policy" \
    --config-rm "${STACK}_starter_partners" --config-rm "${STACK}_starter_register" \
    --config-rm "${STACK}_starter_overview" --secret-rm "${STACK}_http_demo_customer" \
    --env-add "GM_WEB_ROUTES=other=stub:9091 stub=stub:9090" "$BASTION" >/dev/null 2>&1
if B4=$(wait_healthy "$BASTION" "$B"); then
    pass "bastion without a data policy, partners or register healthy ($B4)"
    B=$B4
else
    fail "bastion without a data policy, partners or register did not become healthy"
fi
for f in data-policy.md partners.md data-register.md network-overview.md; do
    check "no $f in the starter pack" sh -c "! docker exec $B test -e /opt/gm/starter/$f"
    check "no ~/$f in the home" sh -c "! docker exec $B test -e /home/player/$f"
done
check "the starter marker written again" docker exec "$B" test -f /home/player/.gm-starter-copied
i=0
while [ "$i" -lt 60 ] && [ "$(web -u "player:$TOOLS_PASSWORD" "$URL/stub/")" != 200 ]; do
    sleep 2; i=$((i + 2))
done
code=$(web -u "player:$TOOLS_PASSWORD" "$URL/")
w=$(links "$tmp/b")
[ "$code" = 200 ] && [ "$w" = "/other/ /stub/ /reports/ /docs/readme /docs/story /docs/issues /docs/bricks/bastion /docs/bricks/postgres " ] \
    && ! grep -qi -e 'data policy' -e 'partners' -e 'data register' -e 'network overview' "$tmp/b" \
    && pass "two routes and three documents: Sites the two routes and Reports, Documents the three, then Tools ($w)" \
    || fail "two routes and three documents, the home: $code, links $w"
dead=
for p in $w; do
    [ "$p" = /other/ ] && continue                 # its upstream is down by design: 502
    code=$(web -u "player:$TOOLS_PASSWORD" "$URL$p")
    [ "$code" = 200 ] || dead="$dead $p:$code"
done
[ -z "$dead" ] && pass "no dead link on that home (each answers 200; /other/ is the down route)" \
    || fail "dead links:$dead"
bad=
for p in /docs/data-policy /docs/partners /docs/data-register /docs/network-overview; do
    code=$(web -u "player:$TOOLS_PASSWORD" "$URL$p")
    [ "$code" = 404 ] || bad="$bad $p:$code"
done
[ -z "$bad" ] && pass "no page for an absent document (404)" || fail "absent documents' pages:$bad"
out=$(pb gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate green without a data policy" || fail "validator without a data policy: exit $rc: $out"

# --- partners.md naming a credential with no secret: the container is refused -----
info "partners.md back, its credential's secret not mounted"
docker service update --detach --config-add \
    "source=${STACK}_starter_partners,target=/opt/gm/starter/partners.md,uid=0,gid=0,mode=0444" \
    "$BASTION" >/dev/null 2>&1
i=0; found=0
while [ "$i" -lt 90 ]; do
    if docker service logs "$BASTION" 2>&1 \
        | grep -q 'gm-entrypoint: fatal: partners.md: {{credential:demo_customer}}: no secret /opt/gm/secrets/http_demo_customer'; then
        found=1; break
    fi
    sleep 3; i=$((i + 3))
done
[ "$found" = 1 ] && pass "a placeholder whose credential has no secret refused (demo_customer)" \
    || fail "no refusal of partners.md's credential without its secret in the logs"

# --- a required starter file missing: the container is refused --------------------
info "removing issues.md from the starter pack"
docker service update --detach --config-rm "${STACK}_starter_partners" \
    --config-rm "${STACK}_starter_issues" "$BASTION" >/dev/null 2>&1
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
