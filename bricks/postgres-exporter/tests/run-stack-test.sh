#!/bin/sh
# Stack test of the postgres-exporter brick (v0.2 build plan, chunk 9, Done
# when).
#
# Deploys the brick as a Swarm stack (stack.test.yml) next to a postgres
# 0.2.0 node `db` (pg_stat_statements preloaded, `monitoring` let in by a
# pg_hba.conf `host` line with scram-sha-256), with seed files and secrets
# as external configs and secrets created here, then checks, from a client
# container on the stack's network and from the GM side (docker exec):
#   - both containers become healthy; postgres_exporter runs as `exporter`;
#   - pg_up 1, the pg_stat_statements metrics, and every default collector
#     succeeding on PostgreSQL 18 (pg_scrape_collector_success 1);
#   - the password: in the secret only, readable by root and exporter, not
#     by player; not in the exporter's arguments, nor in exporter.conf;
#   - SSH as `player` works, and `player` may sudo exactly the 2 wrappers;
#   - the validator exits 0 on the seed, then 1 on a pending edit and on a
#     file that is not valid; gm-restart-exporter applies an edit, refuses
#     a file that is not valid and leaves the exporter running;
#   - a wrong database address is a finding (pg_up 0), not a red validator;
#     the health check does not depend on the database;
#   - a file that is not valid at start leaves the service down;
#   - edits survive a new container; the seed marker is out of player's
#     reach; read-only root, capabilities, /run a volume;
#   - the entrypoint refuses a missing, empty or multi-line password.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the images built locally (the
# postgres image is the test client: it has ssh and perl):
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.1.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres
# Usage: sh bricks/postgres-exporter/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-pgexp
IMAGE=127.0.0.1:5000/dbagm/postgres-exporter:0.1.0
CLIENT_IMAGE=127.0.0.1:5000/dbagm/postgres:0.2.0
SERVICE=${STACK}_exporter
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk9-postgres-exporter
CONFIGS="seed_exporter_conf seed_postgresql_conf seed_pg_hba_conf envelopes"
SECRETS="player_ssh_pubkey dba_password monitoring_password"
VOLUMES="exp_conf exp_home exp_gmstate exp_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run"
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
CONF=/etc/postgres-exporter/exporter.conf
SECRET=/opt/gm/secrets/monitoring_password

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-pgexp.XXXXXX")

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" "${STACK}-secret-missing" "${STACK}-secret-empty" "${STACK}-secret-lines" >/dev/null 2>&1
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
# the monitoring role's password: one secret, read by both nodes
printf 'mon%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
MONPW=$(cat "$tmp/monitoring_password")
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_exporter_conf "$HERE/fixtures/exporter.conf"
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql.conf"
cfg seed_pg_hba_conf "$HERE/fixtures/pg_hba.conf"
cfg envelopes "$PG_FIXTURES/envelopes.conf"
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

if DB=$(wait_healthy "$DB_SERVICE"); then
    pass "db node (postgres 0.2.0) healthy ($DB)"
else
    fail "db node did not become healthy"
    docker service ps --no-trunc "$DB_SERVICE" || true
    docker service logs --tail 60 "$DB_SERVICE" 2>&1 || true
    exit 1
fi
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
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@exporter "$@"; }
gm() { docker exec -i "$C" "$@"; }
dbsql() { docker exec -i -u postgres "$DB" psql -X -q -At -d postgres -c "$1"; }
# nhttp <method> <host> <port> <path>: the raw HTTP/1.0 response, from the
# client container (another node of the network, as Prometheus would be).
PERL_HTTP='use IO::Socket::INET; my ($m, $h, $p, $u) = @ARGV;
my $s = IO::Socket::INET->new(PeerAddr => $h, PeerPort => $p, Timeout => 20) or exit 9;
print $s "$m $u HTTP/1.0\r\nHost: $h:$p\r\nContent-Length: 0\r\n\r\n"; local $/; print <$s>;'
nhttp() { docker exec -i "$CLIENT" perl -e "$PERL_HTTP" "$@"; }
status_of() { sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p' | tr -d '\r'; }
metrics() { nhttp GET exporter 9187 /metrics | tr -d '\r'; }
pg_up() { metrics | sed -n 's/^pg_up \(.*\)$/\1/p'; }
exporter_pid() { gm ps -u exporter -o pid=,args= | awk '$2 == "/usr/local/bin/postgres_exporter" { print $1; exit }'; }
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}

# --- postgres_exporter served, connected ------------------------------------------
u=$(gm ps -o user= -C postgres_export | sort -u | tr -d ' ')
[ "$u" = exporter ] && pass "postgres_exporter runs as exporter" || fail "postgres_exporter process user: [$u]"
r=$(nhttp GET exporter 9187 /metrics)
[ "$(printf '%s' "$r" | status_of)" = 200 ] && pass "metrics served on exporter:9187/metrics, from another node" \
    || fail "GET /metrics: $(printf '%s' "$r" | head -n 3)"
[ "$(pg_up)" = 1 ] && pass "pg_up 1: connected to db as monitoring (scram-sha-256, secret's password)" \
    || fail "pg_up: [$(pg_up)]"
# query statistics: a few statements, then the collector's metrics
for q in "SELECT count(*) FROM pg_class" "SELECT now()" "SELECT 1"; do dbsql "$q" >/dev/null; done
i=0; m=
while [ "$i" -lt 30 ]; do
    m=$(metrics)
    if printf '%s\n' "$m" | grep -q '^pg_stat_statements_calls_total{' \
       && printf '%s\n' "$m" | grep -q '^pg_stat_statements_seconds_total{'; then break; fi
    sleep 3; i=$((i + 3))
done
for n in pg_stat_statements_calls_total pg_stat_statements_seconds_total pg_stat_statements_rows_total; do
    c=$(printf '%s\n' "$m" | grep -c "^$n{")
    [ "$c" -gt 0 ] && pass "$n present with pg_stat_statements preloaded ($c series)" || fail "$n absent"
done
info "a pg_stat_statements series: $(printf '%s\n' "$m" | grep -m1 '^pg_stat_statements_calls_total{')"
# PostgreSQL 18: every collector that ran succeeded, the default ones included
defaults=$(gm postgres_exporter --help 2>&1 | tr -s ' \n' ' ' \
    | grep -o 'collector\.[a-z_]* Enable the [a-z_]* collector (default: enabled)' | sed 's/^collector\.\([a-z_]*\) .*/\1/' | sort)
succ=$(printf '%s\n' "$m" | sed -n 's/^pg_scrape_collector_success{collector="\([a-z_]*\)"} \(.*\)$/\1 \2/p' | sort)
bad=$(printf '%s\n' "$succ" | awk '$2 != 1')
missing=
for d in $defaults stat_statements; do
    printf '%s\n' "$succ" | grep -q "^$d 1$" || missing="$missing $d"
done
if [ -n "$defaults" ] && [ -z "$bad" ] && [ -z "$missing" ]; then
    pass "pg_scrape_collector_success 1 for every default collector and stat_statements ($(printf '%s\n' "$succ" | awk '{print $1}' | tr '\n' ' '))"
else
    fail "collectors: defaults [$(printf '%s' "$defaults" | tr '\n' ' ')] failing [$bad] missing [$missing]"
fi

# --- the password: secret only, unreadable by player ------------------------------------
m=$(gm stat -c '%u:%g %a' "$SECRET")
[ "$m" = "0:990 440" ] && pass "secret $SECRET root:exporter 0440" || fail "secret owner and mode: $m"
check "exporter reads the secret" docker exec -u exporter "$C" test -r "$SECRET"
denied "player cannot read the secret" cat "$SECRET"
g=$(pssh id -nG 2>&1)
case " $g " in *" exporter "*) fail "player is in group exporter ($g)" ;; *) pass "player is not in group exporter ($g)" ;; esac
pid=$(exporter_pid)
check "the password is not in postgres_exporter's arguments" sh -c "! docker exec $C cat /proc/$pid/cmdline | tr '\\0' '\\n' | grep -qF '$MONPW'"
# The exporter dropped root, so its environ is readable only with
# CAP_SYS_PTRACE, which no account in the node has: the GM looks with a
# privileged exec.
env_=$(docker exec --privileged "$C" cat "/proc/$pid/environ" | tr '\0' '\n')
if printf '%s\n' "$env_" | grep -qx "DATA_SOURCE_PASS_FILE=$SECRET" && ! printf '%s\n' "$env_" | grep -qF "$MONPW" \
   && ! printf '%s\n' "$env_" | grep -q '^DATA_SOURCE_PASS='; then
    pass "postgres_exporter's environment: DATA_SOURCE_PASS_FILE=$SECRET, no password ($(printf '%s\n' "$env_" | cut -d= -f1 | tr '\n' ' '))"
else
    fail "postgres_exporter's environment: $(printf '%s\n' "$env_" | cut -d= -f1 | tr '\n' ' ')"
fi
denied "player cannot read postgres_exporter's environment" cat "/proc/$pid/environ"
check "the password is not in exporter.conf" sh -c "! docker exec $C grep -qF '$MONPW' $CONF"
check "the password is not in the container's log" sh -c "! docker service logs $SERVICE 2>&1 | grep -qF '$MONPW'"

# --- SSH and sudo ------------------------------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@exporter true"
allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-restart-exporter "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the two wrappers, no arguments" \
    || fail "sudo -l: got [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter sudo -n /bin/sh -c true"
check "sudo refuses cat of the secret" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter sudo -n /bin/cat $SECRET"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter sudo -n /usr/local/sbin/gm-validate /etc/passwd"
check "sudo refuses -u exporter" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter sudo -n -u exporter /usr/local/sbin/gm-validate"
check "sudo refuses -s" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter sudo -n -s"
check "player has curl and jq" pssh 'curl -fsS -m 20 http://localhost:9187/metrics | grep -q "^pg_up " && echo "{}" | jq -e . >/dev/null'

# --- validator on the seed -----------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "${out#*sudo:}" ] && pass "gm-validate green on the seed, no sudo warning (exit 0: $out)" \
    || fail "gm-validate on seed: exit $rc: $out"
check "sudo logs to /run/gm/sudo.log" docker exec "$C" grep -q 'COMMAND=/usr/local/sbin/gm-validate' /run/gm/sudo.log
out=$(docker exec -u exporter "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as exporter green (exit 0)" || fail "GM validator: exit $rc: $out"
m=$(gm stat -c '%a %U:%G' /etc/postgres-exporter $CONF /var/lib/gm-state /var/lib/gm-state/.gm-seeded /home/player | tr '\n' ' ')
[ "$m" = "2775 exporter:expconf 664 exporter:expconf 755 root:root 444 root:root 750 player:player " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"

# --- seed marker out of the players' reach ---------------------------------------
MARKER=/var/lib/gm-state/.gm-seeded
marker0=$(gm cat "$MARKER")
check "no marker in the group-writable /etc/postgres-exporter" gm test ! -e /etc/postgres-exporter/.gm-seeded
denied "player cannot remove the marker" rm -f "$MARKER"
denied "player cannot overwrite the marker" "echo x > $MARKER"
denied "player cannot create a file next to the marker" touch /var/lib/gm-state/x
check "exporter cannot remove the marker" sh -c "! docker exec -u exporter $C rm -f $MARKER"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "marker unchanged after the attempts" || fail "marker changed or gone"

# --- an edit: pending, then applied by the wrapper --------------------------------
pssh "sed -i 's/^COLLECTORS=.*/COLLECTORS=--collector.stat_statements --no-collector.wal/' $CONF" \
    && pass "player edits $CONF (no wal collector)" || fail "player cannot edit $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED pending: ' && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ]; then
    pass "validator red on an edit not yet applied (exit 1: $out)"
else
    fail "pending edit: exit $rc: $out"
fi
pid0=$(exporter_pid)
out=$(pssh sudo -n gm-restart-exporter 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'pg_up 1: connected'; then
    pass "gm-restart-exporter (exit 0: $(printf '%s' "$out" | tr '\n' ' '))"
else
    fail "gm-restart-exporter: exit $rc: $out"
fi
[ -n "$(exporter_pid)" ] && [ "$(exporter_pid)" != "$pid0" ] && pass "a new postgres_exporter process runs" || fail "same process after restart"
m=$(metrics)
if printf '%s\n' "$m" | grep -q '^pg_scrape_collector_success{collector="stat_statements"} 1' \
   && ! printf '%s\n' "$m" | grep -q '^pg_scrape_collector_success{collector="wal"}'; then
    pass "the edit is in effect (wal collector off, stat_statements on)"
else
    fail "collectors after the restart: $(printf '%s\n' "$m" | grep '^pg_scrape_collector_success' | tr '\n' ' ')"
fi
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green after the restart (exit 0)" || fail "after restart: exit $rc: $out"

# --- a file that is not valid: validator red, restart refused, exporter left running ------
pssh "cp $CONF ~/exporter.conf.good && printf 'DATA_SOURCE_PASS=x\nCOLLECTORS=--collector.nope\n' >> $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: .*unknown key DATA_SOURCE_PASS.*COLLECTORS is set twice' \
   && printf '%s' "$out" | grep -q '^RED pending: '; then
    pass "validator red on a file that is not valid (exit 1: $(printf '%s' "$out" | head -n 1 | cut -c1-160))"
else
    fail "file not valid: exit $rc: $out"
fi
pid0=$(exporter_pid)
out=$(pssh sudo -n gm-restart-exporter 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT restarted' && [ "$(exporter_pid)" = "$pid0" ] && [ "$(pg_up)" = 1 ]; then
    pass "gm-restart-exporter refuses a file that is not valid, exporter left running (pg_up 1)"
else
    fail "restart with a file not valid: exit $rc: $out"
fi
# whatever file the path leads to, the checks print nothing of it
pssh "rm -f $CONF && ln -s $SECRET $CONF"
out=$(pssh sudo -n gm-restart-exporter 2>&1); rc=$?
out2=$(pssh sudo -n gm-validate 2>&1); rc2=$?
if [ "$rc" -eq 1 ] && [ "$rc2" -eq 1 ] && printf '%s' "$out$out2" | grep -q 'symbolic link' \
   && ! printf '%s' "$out$out2" | grep -qF "$MONPW"; then
    pass "a symbolic link to the secret is refused, nothing of it printed"
else
    fail "symbolic link: exit $rc/$rc2: $out $out2"
fi
pssh "rm -f $CONF && cp ~/exporter.conf.good $CONF"

# --- a wrong database address: a finding, not a red validator ----------------------
pssh "sed -i 's|^DATA_SOURCE_URI=.*|DATA_SOURCE_URI=nowhere:5432/postgres?sslmode=disable|' $CONF"
out=$(pssh sudo -n gm-restart-exporter 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'pg_up 0: NOT connected'; then
    pass "wrong address: gm-restart-exporter reports pg_up 0 (exit 0)"
else
    fail "wrong address restart: exit $rc: $out"
fi
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green with a wrong address: the database is not its business" || fail "wrong address validator: exit $rc: $out"
pssh "cp ~/exporter.conf.good $CONF" && pssh sudo -n gm-restart-exporter >/dev/null 2>&1 || fail "restore the file"
[ "$(pg_up)" = 1 ] && pass "pg_up 1 again after restoring the address" || fail "pg_up after restore: $(pg_up)"

# --- the database down: pg_up 0, the node stays healthy --------------------------
docker exec "$DB" /command/s6-svc -d /run/service/postgres
i=0; seen=
while [ "$i" -lt 30 ]; do
    sleep 2; i=$((i + 2))
    if [ "$(pg_up)" = 0 ]; then seen=$i; break; fi
done
[ -n "$seen" ] && pass "database stopped: pg_up 0 within ${seen}s" || fail "database stopped: pg_up $(pg_up)"
sleep 12
h=$(docker inspect -f '{{.State.Health.Status}}' "$C")
r=$(docker exec "$C" /usr/local/lib/gm/healthcheck); rc=$?
[ "$h" = healthy ] && [ "$rc" -eq 0 ] && pass "the exporter node stays healthy with the database down" || fail "health with db down: $h, check exit $rc: $r"
docker exec "$DB" /command/s6-svc -u /run/service/postgres
i=0; seen=
while [ "$i" -lt 60 ]; do
    sleep 2; i=$((i + 2))
    if [ "$(pg_up)" = 1 ]; then seen=$i; break; fi
done
[ -n "$seen" ] && pass "database back: pg_up 1 within ${seen}s, no restart needed" || fail "database back: pg_up $(pg_up)"

# --- a file that is not valid at start: the service stays down -----------------------
pssh "printf 'BOGUS=1\n' >> $CONF"
gm /command/s6-svc -r /run/service/postgres-exporter
sleep 3
s=$(gm /command/s6-svstat -o up,exitcode /run/service/postgres-exporter)
[ -z "$(exporter_pid)" ] && pass "not valid at start: postgres_exporter not started (s6: $s)" || fail "started with a file not valid ($s)"
check "the log says why" sh -c "docker service logs --since 1m $SERVICE 2>&1 | grep -q 'postgres-exporter: NOT started: line [0-9]*: unknown key BOGUS'"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: ' && printf '%s' "$out" | grep -q '^RED server: '; then
    pass "validator red: config and server (exit 1)"
else
    fail "service down: exit $rc: $out"
fi
h=$(docker inspect -f '{{.State.Health.Status}}' "$C")
[ "$h" = healthy ] && pass "the node stays healthy with the exporter down" || fail "health with the exporter down: $h"
pssh "cp ~/exporter.conf.good $CONF"
out=$(pssh sudo -n gm-restart-exporter 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'pg_up 1'; then
    pass "gm-restart-exporter starts a service that was down (exit 0)"
else
    fail "start from down: exit $rc: $out"
fi
pssh "printf 'COLLECTORS=--collector.stat_statements --no-collector.wal\n' > /tmp/c && sed -i '/^COLLECTORS=/d' $CONF && cat /tmp/c >> $CONF" \
    && pssh sudo -n gm-restart-exporter >/dev/null 2>&1 || fail "re-apply the edit"

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
check "$CONF edits kept in a new container (not re-seeded)" gm grep -q -- '--no-collector.wal' "$CONF"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green in the new container" || fail "validator in new container: exit $rc: $out"
[ "$(pg_up)" = 1 ] && pass "pg_up 1 in the new container" || fail "pg_up in new container: $(pg_up)"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
for f in /opt/gm/validator/validate.sh /usr/local/sbin/gm-restart-exporter /usr/local/lib/gm/exporter-conf \
         /usr/local/lib/gm/postgres_exporter.yml /etc/s6-overlay/s6-rc.d/postgres-exporter/run; do
    check "player cannot write $f" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@exporter 'echo x >> $f'"
done
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"
info "memory in use: $(gm cat /sys/fs/cgroup/memory.current) bytes (limit $(gm cat /sys/fs/cgroup/memory.max)); postgres_exporter RSS $(gm ps -o rss= -p "$(exporter_pid)" | tr -d ' ') kB"

# --- the entrypoint refuses a missing, empty or multi-line password ------------------------
printf '' > "$tmp/pw_empty"
printf 'line1\nline2\n' > "$tmp/pw_lines"
for k in missing empty lines; do
    case $k in
        missing) mount= ;;
        empty) mount="-v $tmp/pw_empty:$SECRET:ro" ;;
        lines) mount="-v $tmp/pw_lines:$SECRET:ro" ;;
    esac
    out=$(docker run --name "${STACK}-secret-$k" --rm -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" $mount "$IMAGE" 2>&1); rc=$?
    case $k in
        missing|empty) want='secret /opt/gm/secrets/monitoring_password is missing or empty' ;;
        lines) want='secret monitoring_password must be a single line' ;;
    esac
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want"; then
        pass "the entrypoint refuses a $k password (exit $rc: $want)"
    else
        fail "$k password: exit $rc: $out"
    fi
done

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
