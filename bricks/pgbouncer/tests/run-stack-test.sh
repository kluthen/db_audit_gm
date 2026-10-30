#!/bin/sh
# Stack test of the PgBouncer brick (v0.3 build plan, chunk 6, Done when).
#
# Deploys the brick as a Swarm stack (stack.test.yml) beside a postgres
# 0.3.0 node `db` holding the lookup role, with their seed files and
# secrets as external configs and secrets created here, then checks, from a
# client container on the stack's network (standing in for the bastion)
# and from the GM side (docker exec):
#   - both containers become healthy; PgBouncer runs as `pgbouncer`;
#   - SSH as `player` works, and `player` may sudo exactly the 2 wrappers;
#   - the validator exits 0 on the seed, as player and as the GM;
#   - owners and modes; the seed marker out of player's reach; the lookup
#     role's password readable by no one but root and pgbouncer, and the
#     application role's password in no file of the pooler node;
#   - an application role through the pooler, from another node and over
#     the local socket, by auth_query; a wrong password refused;
#   - dba on the console: SHOW POOLS, SHOW STATS, SHOW CLIENTS, and plain
#     psql on the node through the player's ~/.pgpass; RELOAD,
#     SET and PAUSE refused; still refused after player writes
#     admin_users = dba in pgbouncer.ini and reloads;
#   - the GM's admin over the local socket (PgBouncer's own account, by
#     peer): SHOW CONFIG and RELOAD; the same account refused over TCP;
#   - an edit (sed -i: pool size, pool mode) reloaded through the wrapper,
#     in effect, the owner sed -i changed given back;
#   - a file that does not load: validator red, the reload refused, the
#     settings in effect untouched; envelopes: red on a pending and an
#     in-effect value outside, and on a database's own pool size;
#     auth_dbname's database missing from [databases]: red, dba locked out;
#   - edits and the marker kept in a new container (not re-seeded);
#   - the snapshot: every volume but /run copied by tar while the node runs;
#   - report-only (GM_WRITE_POLICY): pgbouncer.ini and its directory not
#     writable by player, gm-reload-pgbouncer refusing in one line with
#     nothing reloaded, gm-validate still run, dba still refused RELOAD; an
#     override of /etc/pgbouncer making the file fixable again;
#   - the entrypoint's refusals; read-only root, capabilities, /run a
#     volume; the footprint at rest.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the images built locally (the
# postgres image is also the test client: it has ssh and psql):
#   docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.0 bricks/pgbouncer
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres
# On the build host, run it under the docker lock:
#   flock /tmp/dbagm-docker.lock sh bricks/pgbouncer/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-pgb
IMAGE=127.0.0.1:5000/dbagm/pgbouncer:0.1.0
DB_IMAGE=127.0.0.1:5000/dbagm/postgres:0.3.0
CLIENT_IMAGE=$DB_IMAGE
SERVICE=${STACK}_pooler
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk6-pgbouncer
CONFIGS="seed_pgbouncer_ini pgb_envelopes seed_postgresql_conf seed_pg_hba_conf db_envelopes"
SECRETS="player_ssh_pubkey pgbouncer_lookup_password dba_password monitoring_password gm_check_password"
VOLUMES="pgb_conf pgb_log pgb_home pgb_gmstate pgb_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run"
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
CONF=/etc/pgbouncer/pgbouncer.ini
LOG=/var/log/pgbouncer/pgbouncer.log
REFUSAL='gm-reload-pgbouncer: this node is report-only: its files cannot be changed, so nothing was reloaded.'
REFUSE_NAMES="policy override lookup dba"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-pgb.XXXXXX")

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

for i in "$IMAGE" "$DB_IMAGE"; do
    docker image inspect "$i" >/dev/null 2>&1 || { echo "image $i not built" >&2; exit 2; }
done
if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi

# --- per-game material, as gmctl deploy would create it ---------------------
hexpw() { head -c "$1" /dev/urandom | od -An -tx1 | tr -d ' \n'; }
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
hexpw 24 > "$tmp/dba_password"
printf 'mon%s' "$(hexpw 12)" > "$tmp/monitoring_password"
hexpw 24 > "$tmp/gm_check_password"
hexpw 24 > "$tmp/pgbouncer_lookup_password"
APP_PW=app$(hexpw 16)
DBA_PW=$(cat "$tmp/dba_password")
LOOKUP_PW=$(cat "$tmp/pgbouncer_lookup_password")
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_pgbouncer_ini "$HERE/fixtures/pgbouncer.ini"
cfg pgb_envelopes "$HERE/fixtures/envelopes.conf"
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql.conf"
cfg seed_pg_hba_conf "$PG_FIXTURES/pg_hba.conf"
cfg db_envelopes "$PG_FIXTURES/envelopes.conf"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
for s in pgbouncer_lookup_password dba_password monitoring_password gm_check_password; do
    docker secret create -l "$LABEL" "${STACK}_$s" "$tmp/$s" >/dev/null
done

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

if DB=$(wait_healthy "$DB_SERVICE"); then
    pass "db node (postgres 0.3.0, the lookup role's secret mounted) healthy ($DB)"
else
    fail "db node did not become healthy"
    docker service ps --no-trunc "$DB_SERVICE" || true
    docker service logs --tail 60 "$DB_SERVICE" 2>&1 || true
    exit 1
fi
if C=$(wait_healthy "$SERVICE"); then
    pass "pooler deployed and container healthy ($C)"
else
    fail "pooler did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi

# --- client on the stack network, standing in for the bastion -------------------
docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$CLIENT_IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@pooler "$@"; }
gm() { docker exec -i "$C" "$@"; }
# adm <command>: the GM's console, PgBouncer's own account over the local socket
adm() { docker exec -u pgbouncer "$C" psql -X -w -q -A -t -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "$1"; }
setting() { adm 'SHOW CONFIG' | awk -F'|' -v k="$1" '$1 == k { print $2 }'; }
# cpsql <user> <password> <db> <sql>: psql through the pooler, from the client
cpsql() {
    docker exec -e PGPASSWORD="$2" "$CLIENT" psql -X -w -q -A -t -F '|' -h pooler -p 6432 -U "$1" -d "$3" -c "$4"
}
dba() { cpsql dba "$DBA_PW" pgbouncer "$1"; }
dbq() { docker exec -u postgres "$DB" psql -X -w -q -A -t -h /run/postgresql -p 5432 -d "${2:-postgres}" -c "$1"; }
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
validate() { pssh sudo -n gm-validate 2>&1; }
reload() { pssh sudo -n gm-reload-pgbouncer 2>&1; }
reloads_logged() { gm grep -c 'RELOAD command issued' "$LOG"; }

# --- PgBouncer served ------------------------------------------------------------
u=$(gm ps -o user= -C pgbouncer | sort -u | tr -d ' ')
[ "$u" = pgbouncer ] && pass "PgBouncer runs as pgbouncer" || fail "PgBouncer process user: [$u]"
v=$(adm 'SHOW VERSION')
case $v in "PgBouncer 1.26.1"*) pass "PGDG's PgBouncer ($v)" ;; *) fail "version: $v" ;; esac

# --- SSH and sudo ------------------------------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@pooler true"
allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-pgbouncer "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the two wrappers, no arguments" \
    || fail "sudo -l: got [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler sudo -n /bin/sh -c true"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler sudo -n /usr/local/sbin/gm-validate /etc/passwd"
check "sudo refuses -u pgbouncer" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler sudo -n -u pgbouncer /usr/local/sbin/gm-validate"

# --- validator on the seed -----------------------------------------------------
out=$(validate); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "${out#*sudo:}" ] && pass "gm-validate green on the seed, no sudo warning (exit 0: $out)" \
    || fail "gm-validate on seed: exit $rc: $out"
check "sudo logs to /run/gm/sudo.log" gm grep -q 'COMMAND=/usr/local/sbin/gm-validate' /run/gm/sudo.log
out=$(docker exec -u pgbouncer "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as pgbouncer green (exit 0)" || fail "GM validator: exit $rc: $out"

# --- owners, modes, secrets ---------------------------------------------------------
m=$(gm stat -c '%a %U:%G' /etc/pgbouncer $CONF /var/log/pgbouncer $LOG /var/lib/gm-state /var/lib/gm-state/.gm-seeded \
    /home/player /home/player/.pgpass /run/pgbouncer /run/pgbouncer-auth /run/pgbouncer-auth/userlist.txt | tr '\n' ' ')
[ "$m" = "2775 pgbouncer:pgbconf 664 pgbouncer:pgbconf 2750 pgbouncer:pgbconf 640 pgbouncer:pgbconf 755 root:root 444 root:root 750 player:player 600 player:player 755 pgbouncer:pgbouncer 750 root:pgbouncer 440 root:pgbouncer " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"
check "/run/gm/write-policy says fixable (no policy in the environment)" \
    sh -c "docker exec $C cat /run/gm/write-policy | grep -qx policy=fixable"
a=$(gm cat /run/pgbouncer-auth/userlist.txt)
[ "$a" = "\"pgbouncer_lookup\" \"$LOOKUP_PW\"" ] && pass "auth_file holds one line: the lookup role and its secret's password" \
    || fail "auth_file: [$(printf '%s' "$a" | sed 's/"[0-9a-f]\{48\}"/"<pw>"/')]"
denied "player cannot read auth_file" cat /run/pgbouncer-auth/userlist.txt
denied "player cannot read the lookup secret" cat /opt/gm/secrets/pgbouncer_lookup_password
denied "player cannot read /run/gm/write-policy" cat /run/gm/write-policy
check "player reads PgBouncer's log" pssh "grep -q 'process up: PgBouncer' $LOG"
MARKER=/var/lib/gm-state/.gm-seeded
marker0=$(gm cat "$MARKER")
denied "player cannot remove the marker" rm -f "$MARKER"
denied "player cannot create a file next to the marker" touch /var/lib/gm-state/x
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "marker unchanged after the attempts" || fail "marker changed or gone"

# --- an application role through the pooler ------------------------------------------
dbq "CREATE ROLE app LOGIN PASSWORD '$APP_PW'" >/dev/null && dbq "CREATE DATABASE appdb OWNER app" >/dev/null \
    && dbq "CREATE TABLE t (n int); INSERT INTO t VALUES (42); ALTER TABLE t OWNER TO app" appdb >/dev/null \
    || fail "GM setup of the application role app"
r=$(cpsql app "$APP_PW" appdb "SELECT current_user || '|' || n FROM t" 2>&1)
[ "$r" = "app|42" ] && pass "application role app through the pooler, from another node (auth_query): $r" \
    || fail "app through the pooler: $r"
r=$(dbq "SELECT count(*) FROM pg_stat_activity WHERE usename = 'app' AND datname = 'appdb'")
[ "$r" -ge 1 ] && pass "the server holds the pooled connection of app ($r in pg_stat_activity)" || fail "server connections of app: $r"
r=$(cpsql app wrong-password appdb 'SELECT 1' 2>&1)
case $r in *"SASL authentication failed"*|*"password authentication failed"*) pass "a wrong password refused by PgBouncer ($(printf '%s' "$r" | sed 's/.*FATAL: *//'))" ;; *) fail "wrong password: $r" ;; esac
r=$(pssh "PGPASSWORD='$APP_PW' psql -X -w -q -A -t -U app -d appdb -c 'SELECT current_user'" 2>&1)
[ "$r" = app ] && pass "app over the pooler's local socket, as player on the node" || fail "app over the local socket: $r"
r=$(gm grep -rlF "$APP_PW" /etc /home /var /run /opt /usr/local 2>/dev/null)
[ -z "$r" ] && pass "app's password in no file of the pooler node (the verifier comes from the database)" \
    || fail "app's password found in: $r"

# --- dba on the console ------------------------------------------------------------------
r=$(dba 'SHOW POOLS' 2>&1)
printf '%s\n' "$r" | grep -q '^appdb|app|' && pass "dba: SHOW POOLS ($(printf '%s\n' "$r" | grep '^appdb|app|' | cut -d'|' -f1-5))" \
    || fail "dba SHOW POOLS: $r"
check "dba: SHOW STATS" sh -c "docker exec -e PGPASSWORD=$DBA_PW $CLIENT psql -X -w -h pooler -p 6432 -U dba -d pgbouncer -c 'SHOW STATS' | grep -q appdb"
check "dba: SHOW CLIENTS" sh -c "docker exec -e PGPASSWORD=$DBA_PW $CLIENT psql -X -w -h pooler -p 6432 -U dba -d pgbouncer -c 'SHOW CLIENTS' | grep -q dba"
for cmd in RELOAD "SET default_pool_size = 9" PAUSE SHUTDOWN; do
    r=$(dba "$cmd" 2>&1); rc=$?
    case $r in *"admin access needed"*) [ "$rc" -ne 0 ] && pass "dba: $cmd refused ($r)" || fail "dba $cmd: exit $rc" ;;
        *) fail "dba $cmd: exit $rc: $r" ;; esac
done
r=$(pssh "psql -X -w -q -A -t -c 'SHOW LISTS'" 2>&1)
printf '%s' "$r" | grep -q '^databases|' && pass "dba's console from the node itself (plain psql: its environment, ~/.pgpass)" || fail "console on the node: $r"
r=$(gm cat /home/player/.pgpass)
[ "$r" = "*:*:*:dba:$DBA_PW" ] && pass "the player's ~/.pgpass holds one line: dba and its secret's password" \
    || fail "~/.pgpass: [$(printf '%s' "$r" | sed 's/[0-9a-f]\{48\}/<pw>/')]"

# --- the GM's admin over the local socket ------------------------------------------------
[ "$(setting admin_users)" = pgbouncer ] && [ "$(setting stats_users)" = dba ] \
    && pass "GM: SHOW CONFIG as pgbouncer by peer (admin_users pgbouncer, stats_users dba)" \
    || fail "GM SHOW CONFIG: admin_users=$(setting admin_users) stats_users=$(setting stats_users)"
n0=$(reloads_logged)
r=$(adm RELOAD 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$(reloads_logged)" -gt "$n0" ] && pass "GM: RELOAD on the console ($r)" || fail "GM RELOAD: exit $rc: $r"
r=$(docker exec "$C" psql -X -w -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW VERSION' 2>&1)
[ $? -ne 0 ] && pass "root as pgbouncer over the socket refused (peer: not that account)" || fail "root as pgbouncer: $r"
r=$(docker exec -u pgbouncer "$C" psql -X -w -h 127.0.0.1 -p 6432 -U pgbouncer -d pgbouncer -c 'SHOW VERSION' 2>&1)
[ $? -ne 0 ] && pass "pgbouncer over TCP refused ($(printf '%s' "$r" | tail -n 1 | cut -c1-90))" || fail "pgbouncer over TCP: $r"

# --- an edit, reloaded --------------------------------------------------------------------
pssh "sed -i -e 's/^default_pool_size = 5$/default_pool_size = 8/' -e 's/^pool_mode = session$/pool_mode = transaction/' $CONF" \
    && pass "player edits $CONF with sed -i (default_pool_size 8, pool_mode transaction)" || fail "player cannot edit $CONF"
m=$(gm stat -c '%U:%G' "$CONF")
[ "$m" = player:pgbconf ] && pass "sed -i left $CONF owned by player ($m)" || fail "owner after sed -i: $m"
out=$(reload); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'in effect: pool_mode=transaction default_pool_size=8 '; then
    pass "gm-reload-pgbouncer (exit 0: $(printf '%s' "$out" | tr '\n' ' '))"
else
    fail "gm-reload-pgbouncer: exit $rc: $out"
fi
[ "$(setting default_pool_size)" = 8 ] && [ "$(setting pool_mode)" = transaction ] \
    && pass "the edit in effect (SHOW CONFIG: default_pool_size 8, pool_mode transaction)" \
    || fail "after reload: default_pool_size=$(setting default_pool_size) pool_mode=$(setting pool_mode)"
m=$(gm stat -c '%a %U:%G' "$CONF")
[ "$m" = "664 pgbouncer:pgbconf" ] && pass "the wrapper restored the owner sed -i changed ($m)" || fail "owner after reload: $m"
r=$(cpsql app "$APP_PW" appdb 'SELECT n FROM t' 2>&1)
[ "$r" = 42 ] && pass "app through the pooler in transaction mode" || fail "app in transaction mode: $r"
out=$(validate); rc=$?
[ "$rc" -eq 0 ] && pass "validator green after the reload (exit 0)" || fail "after reload: exit $rc: $out"

# --- the GM's settings win over the players' file --------------------------------------------
pssh "printf 'admin_users = dba\nauth_type = trust\n' >> $CONF"
out=$(reload); rc=$?
[ "$rc" -eq 0 ] || fail "reload with admin_users = dba in the file: exit $rc: $out"
r=$(dba RELOAD 2>&1)
case $r in *"admin access needed"*) pass "admin_users = dba in $CONF, reloaded: dba still refused RELOAD" ;; *) fail "dba RELOAD after the edit: $r" ;; esac
[ "$(setting admin_users)" = pgbouncer ] && [ "$(setting auth_type)" = hba ] \
    && pass "the GM's admin_users and auth_type in effect, not the file's" \
    || fail "after the edit: admin_users=$(setting admin_users) auth_type=$(setting auth_type)"
r=$(docker exec "$CLIENT" psql -X -w -h pooler -p 6432 -U app -d appdb -c 'SELECT 1' 2>&1)
[ $? -ne 0 ] && pass "no password-less login (auth_type trust in the file has no effect)" || fail "trust: $r"
pssh "sed -i -e '/^admin_users = dba$/d' -e '/^auth_type = trust$/d' $CONF" && reload >/dev/null || fail "undo the GM settings edit"
# an %include in the players' file is left out: an included [pgbouncer]
# header would reset the section, the GM's settings with it
pssh "printf '[pgbouncer]\\nadmin_users = dba\\n' > ~/inc.ini && printf '%%include /home/player/inc.ini\\n' >> $CONF"
out=$(reload); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '%include left out' && [ "$(setting admin_users)" = pgbouncer ] \
    && pass "an %include in $CONF left out, the GM's settings kept ($(printf '%s' "$out" | sed -n 2p | sed 's/^ *//'))" \
    || fail "%include: exit $rc: $out / admin_users=$(setting admin_users)"
out=$(validate); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: .*%include left out' && pass "validator red on the %include ($out)" \
    || fail "validator on %include: exit $rc: $out"
pssh "sed -i '/^%include /d' $CONF" && reload >/dev/null || fail "undo the %include"

# --- a file that does not load ------------------------------------------------------------
pssh "cp $CONF ~/pgbouncer.ini.good && sed -i 's/^pool_mode = transaction$/pool_mode = sometimes/' $CONF"
out=$(validate); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: .*invalid value "sometimes" for parameter pool_mode'; then
    pass "validator red on a file that does not load (exit 1: $(printf '%s' "$out" | head -n 1 | cut -c1-140))"
else
    fail "broken file: exit $rc: $out"
fi
n0=$(reloads_logged)
out=$(reload); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'does not load; PgBouncer was NOT reloaded' && [ "$(reloads_logged)" = "$n0" ]; then
    pass "gm-reload-pgbouncer refuses a file that does not load, no RELOAD sent ($(printf '%s' "$out" | sed -n 2p))"
else
    fail "broken file reload: exit $rc: $out"
fi
[ "$(setting pool_mode)" = transaction ] && [ "$(setting logfile)" = "$LOG" ] && [ "$(setting auth_type)" = hba ] \
    && pass "settings in effect untouched (pool_mode transaction, the GM's log and authentication)" \
    || fail "after the refused reload: pool_mode=$(setting pool_mode) logfile=$(setting logfile)"
pssh "cat ~/pgbouncer.ini.good > $CONF"

# --- envelopes ------------------------------------------------------------------------------
pssh "sed -i 's/^default_pool_size = 8$/default_pool_size = 80/' $CONF"
out=$(validate); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qx "RED knobs: default_pool_size: pending 80 ($CONF:[0-9]*); envelope 1..50"; then
    pass "validator red on a pending value outside its envelope ($out)"
else
    fail "pending out of envelope: exit $rc: $out"
fi
reload >/dev/null
out=$(validate); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED knobs: default_pool_size: in effect 80; pending 80 '; then
    pass "validator red on a value in effect outside its envelope"
else
    fail "in effect out of envelope: exit $rc: $out"
fi
pssh "cat ~/pgbouncer.ini.good > $CONF && sed -i 's/^appdb = host=db port=5432 dbname=appdb$/& pool_size=60/' $CONF"
reload >/dev/null
out=$(validate); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qx "RED knobs: database appdb: its pool_size 60 is outside default_pool_size's envelope 1..50"; then
    pass "validator red on a database's own pool_size outside the envelope ($out)"
else
    fail "database pool_size: exit $rc: $out"
fi
pssh "cat ~/pgbouncer.ini.good > $CONF && sed -i '/^postgres = /d' $CONF"
reload >/dev/null
out=$(validate); rc=$?
r=$(dba 'SHOW POOLS' 2>&1)
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED auth: database postgres, where PgBouncer looks the logins up' \
   && ! printf '%s' "$r" | grep -q '^pgbouncer|'; then
    pass "auth_dbname's database removed from [databases]: validator red, dba locked out of the console"
else
    fail "auth database missing: exit $rc: $out / $r"
fi
pssh "cat ~/pgbouncer.ini.good > $CONF" && out=$(reload) || fail "restore the file: $out"
out=$(validate); rc=$?
[ "$rc" -eq 0 ] && pass "validator green again after fixing (exit 0)" || fail "after fix: exit $rc: $out"
r=$(dba 'SHOW POOLS' 2>&1)
printf '%s' "$r" | grep -q '^pgbouncer|' && pass "dba back on the console" || fail "dba after the fix: $r"

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
check "$CONF edits kept in a new container (not re-seeded)" gm grep -q '^default_pool_size = 8$' "$CONF"
[ "$(setting pool_mode)" = transaction ] && pass "the edited pool_mode in effect in the new container" \
    || fail "pool_mode in the new container: $(setting pool_mode)"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
r=$(cpsql app "$APP_PW" appdb 'SELECT n FROM t' 2>&1)
[ "$r" = 42 ] && pass "app through the new container" || fail "app after new container: $r"
check "the log kept across containers (volume pgblog)" sh -c "[ \$(docker exec $C grep -c 'process up: PgBouncer' $LOG) -ge 2 ]"

# --- the snapshot: every volume but /run by copy (W1 item 6) -------------------------------
snap=$(docker exec -i -u root "$C" sh -s 2>&1 <<'SNAPSHOT'
for v in /etc/pgbouncer /var/log/pgbouncer /home/player /var/lib/gm-state; do
    tar --create --file=- --numeric-owner --directory="$v" . > /run/tmp/snap.tar
    echo "$v rc=$? bytes=$(wc -c < /run/tmp/snap.tar) files=$(tar -tf /run/tmp/snap.tar | grep -vc '/$')"
done
rm -f /run/tmp/snap.tar
SNAPSHOT
)
info "snapshot: $(printf '%s' "$snap" | tr '\n' ';')"
bad=$(printf '%s\n' "$snap" | grep -v ' rc=[01] ' || true)
if [ -z "$bad" ] && [ "$(printf '%s\n' "$snap" | grep -c ' files=[1-9]')" -eq 4 ]; then
    pass "snapshot: the four volumes but /run copied by tar while the node runs"
else
    fail "snapshot copy: $snap"
fi
[ "$(docker inspect -f '{{.State.Health.Status}}' "$C")" = healthy ] && pass "the node stayed healthy through the copy" \
    || fail "node after the copy"

# --- report-only ---------------------------------------------------------------------------
modes() { gm stat -c '%a %U:%G' /etc/pgbouncer "$CONF" | tr '\n' ' '; }
# an edit made on the fixable node, not reloaded: the new container starts
# with it, and its entrypoint gives the file sed -i left to player back
pssh "sed -i -e 's/^default_pool_size = 8$/default_pool_size = 9/' $CONF" \
    && pass "fixable: player edits $CONF with sed -i (default_pool_size 9, not reloaded)" || fail "fixable: sed -i before report-only"
info "redeploying the node report-only (GM_WRITE_POLICY=report-only)"
docker service update --detach --env-add GM_WRITE_POLICY=report-only "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "report-only container healthy ($C)"; else fail "report-only container"; fi
w=$(gm cat /run/gm/write-policy | tr '\n' ' ')
[ "$w" = "policy=report-only overrides= " ] && pass "/run/gm/write-policy says report-only, no override" || fail "write-policy: [$w]"
m=$(modes)
[ "$m" = "2755 pgbouncer:pgbconf 644 pgbouncer:pgbconf " ] \
    && pass "report-only: owners and modes, the file sed -i left to player given back at start ($m)" \
    || fail "report-only modes: $m"
denied "report-only: player cannot sed -i $CONF" "sed -i 's/^default_pool_size = 9$/default_pool_size = 2/' $CONF"
denied "report-only: player cannot append to $CONF" "echo '; x' >> $CONF"
denied "report-only: player cannot create a file in /etc/pgbouncer" touch /etc/pgbouncer/extra.ini
check "report-only: $CONF unchanged by the attempts" gm grep -q '^default_pool_size = 9$' "$CONF"
n0=$(reloads_logged)
out=$(reload); rc=$?
[ "$rc" -eq 1 ] && [ "$out" = "$REFUSAL" ] && pass "gm-reload-pgbouncer refuses (exit 1): $out" \
    || fail "report-only reload: exit $rc: $out"
[ "$(reloads_logged)" = "$n0" ] && [ "$(setting default_pool_size)" = 9 ] \
    && pass "report-only: nothing reloaded (no RELOAD in the log; 9 from the start in effect)" \
    || fail "report-only: reloaded anyway ($(reloads_logged) vs $n0)"
out=$(validate); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate is never refused (green, exit 0)" || fail "validate report-only: exit $rc: $out"
r=$(dba 'SHOW POOLS' 2>&1)
printf '%s' "$r" | grep -q '^pgbouncer|' && pass "report-only: dba reads the console (SHOW POOLS)" || fail "report-only SHOW POOLS: $r"
r=$(dba RELOAD 2>&1)
case $r in *"admin access needed"*) pass "report-only: dba refused RELOAD on the console" ;; *) fail "report-only dba RELOAD: $r" ;; esac
check "report-only: the home is still writable" pssh "echo notes >> ~/report.md"

# --- an override of /etc/pgbouncer on the report-only node ----------------------------------
info "redeploying with GM_WRITE_OVERRIDES=/etc/pgbouncer"
docker service update --detach --env-add GM_WRITE_OVERRIDES=/etc/pgbouncer "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "override container healthy ($C)"; else fail "override container"; fi
w=$(gm cat /run/gm/write-policy | tr '\n' ' ')
[ "$w" = "policy=report-only overrides=/etc/pgbouncer " ] && pass "/run/gm/write-policy names the override" \
    || fail "write-policy: [$w]"
m=$(modes)
[ "$m" = "2775 pgbouncer:pgbconf 664 pgbouncer:pgbconf " ] \
    && pass "override: /etc/pgbouncer fixable on the report-only node ($m)" || fail "override modes: $m"
pssh "sed -i -e 's/^default_pool_size = 9$/default_pool_size = 6/' $CONF" && pass "override: player edits $CONF with sed -i (6)" \
    || fail "override: sed -i on $CONF"
out=$(reload); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q ' default_pool_size=6 ' \
    && pass "override: gm-reload-pgbouncer reloads it ($(printf '%s' "$out" | tail -n 1))" \
    || fail "override reload: exit $rc: $out"
m=$(gm stat -c '%a %U:%G' "$CONF")
[ "$m" = "664 pgbouncer:pgbconf" ] && pass "override: owner and mode restored by the wrapper ($m)" \
    || fail "override after reload: $m"

# --- the entrypoint's refusals ---------------------------------------------------------------
refuse() {  # refuse <name> <expected text> <docker run args...>
    k=$1; want=$2; shift 2
    out=$(docker run --name "${STACK}-refuse-$k" --rm \
        -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" \
        -v "$HERE/fixtures/pgbouncer.ini:/opt/gm/seed/pgbouncer.ini:ro" "$@" "$IMAGE" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want"; then
        pass "the entrypoint refuses: $want (exit $rc)"
    else
        fail "entrypoint $k: exit $rc: $(printf '%s' "$out" | tail -n 3)"
    fi
}
DP="-v $tmp/dba_password:/opt/gm/secrets/dba_password:ro"
LK="-v $tmp/pgbouncer_lookup_password:/opt/gm/secrets/pgbouncer_lookup_password:ro $DP"
# shellcheck disable=SC2086
refuse policy "gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of fixable, report-only, no-access" \
    $LK -e GM_WRITE_POLICY=read-only
# shellcheck disable=SC2086
refuse override "gm-entrypoint: fatal: GM_WRITE_OVERRIDES: '/etc/pgbouncer/pgbouncer.ini' is not one of this brick's writable_paths (/etc/pgbouncer, /home/player)" \
    $LK -e GM_WRITE_POLICY=report-only -e GM_WRITE_OVERRIDES=/etc/pgbouncer/pgbouncer.ini
# shellcheck disable=SC2086
refuse lookup "gm-entrypoint: fatal: secret /opt/gm/secrets/pgbouncer_lookup_password is missing or empty" \
    $DP
refuse dba "gm-entrypoint: fatal: secret /opt/gm/secrets/dba_password is missing or empty" \
    -v "$tmp/pgbouncer_lookup_password:/opt/gm/secrets/pgbouncer_lookup_password:ro"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
check "player cannot write the validator" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler 'echo x >> /opt/gm/validator/validate.sh'"
check "player cannot write a wrapper" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler 'echo x >> /usr/local/sbin/gm-reload-pgbouncer'"
check "player cannot write the GM's settings" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler 'echo x >> /usr/local/lib/gm/pgbouncer-gm.ini'"
check "player cannot write the configuration PgBouncer reads" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler 'echo x >> /run/pgbouncer-conf/pgbouncer.ini'"
check "player cannot write PgBouncer's log" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pooler 'echo x >> $LOG'"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"

# --- footprint at rest ----------------------------------------------------------------
sleep 10
info "footprint at rest (pooler): $(docker stats --no-stream --format '{{.MemUsage}} CPU {{.CPUPerc}}' "$C"); memory.current $(gm cat /sys/fs/cgroup/memory.current) bytes (limit $(gm cat /sys/fs/cgroup/memory.max))"
info "volumes (pooler): $(gm du -sk /etc/pgbouncer /var/log/pgbouncer /home/player /var/lib/gm-state /run 2>/dev/null | tr '\t\n' ' ;')"
info "image size: $(docker image inspect -f '{{.Size}}' "$IMAGE") bytes"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
