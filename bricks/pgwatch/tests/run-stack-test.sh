#!/bin/sh
# Stack test of the pgwatch brick (v0.5 build plan, chunk 10a; G9's build
# conditions, v0.5 wave log; spec D356).
#
# Deploys the brick as a Swarm stack (stack.test.yml) next to a postgres
# 0.5.0 node `db` choosing the option `monitoring` (`monitoring` let in by a
# pg_hba.conf `host` line with scram-sha-256), with the seed file and the
# secrets as external configs and secrets created here. pgwatch starts
# BEFORE its source: `db` is deployed at 0 replicas, then scaled up. From a
# client container on the stack's network and from the GM side (docker
# exec), it checks:
#   - the bounded wait: pgwatch waits up to 30 s for `db` to resolve, says
#     so, starts anyway at the bound, serves its sink and reports
#     pgwatch_instance_up 0 for `db` (an honest failure, no hang); once `db`
#     resolves and is healthy, pgwatch reaches it within its sources
#     refresh, and the basic preset's series appear (instance_up 1);
#   - pgwatch runs as `pgwatch`, with --web-disable=all (nothing on 8080),
#     never --create-helpers; nothing created in the watched database;
#   - the password: in the secret and /run/gm-pgwatch/pgpass (0600, pgwatch)
#     only; not in pgwatch's arguments, environment or sources.yaml; not
#     readable by player;
#   - SSH as `player` works, and `player` may sudo exactly the 2 wrappers;
#   - the validator: green on the seed; red on a file pgwatch cannot parse
#     and on a file enabling no source; gm-restart-pgwatch refuses a file
#     that is not valid and leaves pgwatch running, applies a valid edit at
#     once and says which source it reached; pgwatch rereads the file on
#     its own within its refresh;
#   - a file not valid at start leaves the service down; edits survive a
#     new container; the snapshot copies every volume while pgwatch runs;
#   - report-only: the file not writable by player, gm-restart-pgwatch
#     refusing in one line, nothing restarted, gm-validate still run;
#   - the entrypoint refuses a missing or multi-line password and a bad
#     write policy; read-only root, capabilities, /run a volume;
#   - the footprint at rest (docker stats, memory.peak).
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the images built locally (the
# postgres image is the test client: it has ssh and perl):
#   docker build -t 127.0.0.1:5000/dbagm/pgwatch:0.1.0 bricks/pgwatch
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Usage: sh bricks/pgwatch/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-pgwatch
IMAGE=127.0.0.1:5000/dbagm/pgwatch:0.1.0
CLIENT_IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.0
SERVICE=${STACK}_pgwatch
DB_SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk10-pgwatch
CONFIGS="seed_sources_yaml seed_postgresql_conf seed_pg_hba_conf envelopes"
SECRETS="player_ssh_pubkey dba_password monitoring_password"
VOLUMES="pw_conf pw_home pw_gmstate pw_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run db_cronspool"
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
CONF=/etc/pgwatch/sources.yaml
SECRET=/opt/gm/secrets/monitoring_password
PASSFILE=/run/gm-pgwatch/pgpass
MARKER=/var/lib/gm-state/.gm-seeded

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-pgwatch.XXXXXX")

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" "${STACK}-secret-missing" "${STACK}-secret-lines" \
        "${STACK}-refuse-policy" >/dev/null 2>&1
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
# the monitoring role's password: one secret, read by both nodes; a `:` and
# a `\` in it, which the password file must escape
printf 'mon:%s\\x' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
MONPW=$(cat "$tmp/monitoring_password")
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_sources_yaml "$HERE/fixtures/sources.yaml"
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql.conf"
cfg seed_pg_hba_conf "$HERE/fixtures/pg_hba.conf"
cfg envelopes "$PG_FIXTURES/envelopes.conf"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_monitoring_password" "$tmp/monitoring_password" >/dev/null

info "deploying stack $STACK: pgwatch first, db at 0 replicas (not in DNS)"
DB_REPLICAS=0 docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1
t_deploy=$(date +%s)

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
    pass "pgwatch healthy with its source not yet in DNS ($C, $(($(date +%s) - t_deploy))s after the deployment)"
else
    fail "pgwatch did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi

# --- client on the stack network ---------------------------------------------
docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$CLIENT_IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@pgwatch "$@"; }
gm() { docker exec -i "$C" "$@"; }
# nhttp <method> <host> <port> <path>: the raw HTTP/1.0 response, from the
# client container (another node of the network, as Prometheus would be);
# exit 9 when nothing accepts the connection.
PERL_HTTP='use IO::Socket::INET; my ($m, $h, $p, $u) = @ARGV;
my $s = IO::Socket::INET->new(PeerAddr => $h, PeerPort => $p, Timeout => 5) or exit 9;
print $s "$m $u HTTP/1.0\r\nHost: $h:$p\r\n\r\n"; local $/; print <$s>;'
nhttp() { docker exec -i "$CLIENT" timeout 10 perl -e "$PERL_HTTP" "$@"; }
metrics() { nhttp GET pgwatch 9188 /metrics | tr -d '\r' | sed '1,/^$/d'; }
up_of() { metrics | sed -n "s/^pgwatch_instance_up{dbname=\"$1\"} \([0-9.e+-]*\).*$/\1/p"; }
pgwatch_pid() { gm ps -u pgwatch -o pid=,args= | awk '$2 == "/usr/local/bin/pgwatch" { print $1; exit }'; }
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}

# --- the bounded wait, then an honest failure (spec D356) ---------------------
logs=$(docker service logs --raw "$SERVICE" 2>&1)
printf '%s\n' "$logs" | grep -q "pgwatch-run: waiting up to 30s for sources' hosts to resolve: db" \
    && pass "pgwatch waits, bounded (30 s), for db to resolve, and says so" \
    || fail "no bounded-wait line: $(printf '%s\n' "$logs" | grep pgwatch-run | head -n 3)"
w=$(printf '%s\n' "$logs" | sed -n "s/^pgwatch-run: still not resolving after \([0-9]*\)s: db; pgwatch starts anyway.*/\1/p" | head -n 1)
[ -n "$w" ] && [ "$w" -ge 30 ] && [ "$w" -le 36 ] \
    && pass "the wait ends at its bound (${w}s) and pgwatch starts anyway" \
    || fail "wait outcome: [$w]: $(printf '%s\n' "$logs" | grep pgwatch-run | tail -n 2)"
t0=$(date +%s); m=$(metrics); rc=$?; t=$(($(date +%s) - t0))
[ "$rc" -eq 0 ] && [ "$t" -le 5 ] && pass "the sink answers while db is not in DNS (${t}s, no hang)" \
    || fail "sink with db unresolved: rc $rc in ${t}s"
i=0; u=
while [ "$i" -lt 30 ] && [ -z "$u" ]; do u=$(up_of db); [ -n "$u" ] || { sleep 2; i=$((i + 2)); }; done
[ "$u" = 0 ] && pass "an honest failure: pgwatch_instance_up{dbname=\"db\"} 0 while db does not resolve" \
    || fail "instance_up with db unresolved: [$u]"
check "the failed fetch is logged (hostname resolving error)" sh -c \
    "docker service logs --raw $SERVICE 2>&1 | grep -q 'hostname resolving error: lookup db'"

info "scaling db to 1"
docker service scale --detach "$DB_SERVICE=1" >/dev/null 2>&1
if DB=$(wait_healthy "$DB_SERVICE"); then
    pass "db node (postgres 0.5.0, option monitoring) healthy ($DB)"
else
    fail "db node did not become healthy"
    docker service logs --tail 60 "$DB_SERVICE" 2>&1 || true
    exit 1
fi
t_db=$(date +%s)
dbsql() { docker exec -i -u postgres "$DB" psql -X -q -At -d postgres -c "$1"; }
objs0=$(dbsql "select (select count(*) from pg_proc) || ' ' || (select count(*) from pg_class) || ' ' || (select count(*) from pg_namespace) || ' ' || (select string_agg(extname, ',' order by extname) from pg_extension)")
i=0; u=
while [ "$i" -lt 150 ]; do u=$(up_of db); [ "$u" = 1 ] && break; sleep 3; i=$((i + 3)); done
took=$(($(date +%s) - t_db))
[ "$u" = 1 ] && pass "once db resolves, pgwatch reaches it: instance_up 1 ${took}s after db was healthy (sources refresh 60 s)" \
    || fail "instance_up after db resolved: [$u] after ${took}s"
i=0; m=
while [ "$i" -lt 90 ]; do
    m=$(metrics)
    printf '%s\n' "$m" | grep -q '^pgwatch_db_stats_numbackends{dbname="db"' \
        && printf '%s\n' "$m" | grep -q '^pgwatch_db_size_size_b{dbname="db"' \
        && printf '%s\n' "$m" | grep -q '^pgwatch_wal_xlog_location_b{dbname="db"' && break
    sleep 3; i=$((i + 3))
done
for s in pgwatch_db_stats_numbackends pgwatch_db_stats_xact_commit pgwatch_db_size_size_b pgwatch_wal_xlog_location_b; do
    printf '%s\n' "$m" | grep -q "^$s{dbname=\"db\"" && pass "the basic preset's series: $s" || fail "series missing: $s"
done
n=$(printf '%s\n' "$m" | grep -c '^pgwatch_')
info "pgwatch series in one scrape: $n"

# --- the process, the web interface, the database left untouched ---------------
u=$(gm ps -o user= -C pgwatch | sort -u | tr -d ' ')
[ "$u" = pgwatch ] && pass "pgwatch runs as pgwatch" || fail "pgwatch process user: [$u]"
pid=$(pgwatch_pid)
args=$(gm cat "/proc/$pid/cmdline" | tr '\0' ' ')
info "pgwatch's arguments: $args"
case $args in *"--web-disable=all"*) pass "--web-disable=all" ;; *) fail "no --web-disable=all: $args" ;; esac
case $args in *"--create-helpers"*|*"--try-create-listed-exts"*) fail "helpers or extensions asked for: $args" ;;
    *) pass "neither --create-helpers nor --try-create-listed-exts-if-missing" ;; esac
nhttp GET pgwatch 8080 / >/dev/null 2>&1; rc=$?
[ "$rc" -eq 9 ] && pass "nothing answers on pgwatch:8080 from another node (web interface and REST API off)" \
    || fail "port 8080 accepted a connection (rc $rc)"
check "nothing listens on 8080 inside the node" sh -c "! docker exec $C curl -s -m 3 -o /dev/null http://127.0.0.1:8080/"
objs1=$(dbsql "select (select count(*) from pg_proc) || ' ' || (select count(*) from pg_class) || ' ' || (select count(*) from pg_namespace) || ' ' || (select string_agg(extname, ',' order by extname) from pg_extension)")
[ "$objs0" = "$objs1" ] && pass "nothing created in the watched database (functions, relations, schemas, extensions: $objs1)" \
    || fail "the database changed: [$objs0] -> [$objs1]"
o=$(dbsql "select count(*) from pg_class c join pg_roles r on r.oid = c.relowner where r.rolname = 'monitoring'")
[ "$o" = 0 ] && pass "monitoring owns no relation" || fail "monitoring owns $o relations"
a=$(dbsql "select count(*) from pg_stat_activity where usename = 'monitoring'")
info "monitoring sessions on db now: $a"

# --- the password ----------------------------------------------------------------
check "the password is not in pgwatch's arguments" sh -c "! docker exec $C cat /proc/$pid/cmdline | tr '\0' '\n' | grep -qF -- '$MONPW'"
envp=$(docker exec -u pgwatch "$C" cat "/proc/$pid/environ" | tr '\0' '\n')   # root lacks CAP_SYS_PTRACE
[ -n "$envp" ] || fail "pgwatch's environment could not be read"
printf '%s\n' "$envp" | grep -qF -- "$MONPW" && fail "the password is in pgwatch's environment" \
    || pass "the password is not in pgwatch's environment ($(printf '%s\n' "$envp" | cut -d= -f1 | tr '\n' ' '))"
printf '%s\n' "$envp" | grep -q '^PW_' && fail "a PW_* variable reaches pgwatch" || pass "no PW_* variable reaches pgwatch"
check "the password is not in sources.yaml" sh -c "! docker exec $C grep -qF -- '$MONPW' $CONF"
m=$(gm stat -c '%a %U:%G' "$PASSFILE")
[ "$m" = "600 pgwatch:pgwatch" ] && pass "$PASSFILE: 600 pgwatch:pgwatch" || fail "$PASSFILE: $m"
esc=$(printf '%s' "$MONPW" | sed 's/[\\:]/\\&/g')
[ "$(gm cat "$PASSFILE")" = "*:*:*:monitoring:$esc" ] && pass "the password file escapes : and \\ as libpq requires" \
    || fail "password file content differs"
denied "player cannot read the secret" cat "$SECRET"
denied "player cannot read the password file" cat "$PASSFILE"
denied "player cannot list /run/gm-pgwatch" ls /run/gm-pgwatch/

# --- SSH and sudo --------------------------------------------------------------------
w=$(pssh whoami 2>&1)
[ "$w" = player ] && pass "SSH as player (key from the secret)" || fail "SSH as player: $w"
l=$(pssh sudo -n -l 2>&1 | sed -n 's/^ *(root) NOPASSWD: //p' | tr ',' '\n' | sed 's/^ *//' | sort | tr '\n' ' ')
[ "$l" = '/usr/local/sbin/gm-restart-pgwatch "" /usr/local/sbin/gm-validate "" ' ] \
    && pass "player may sudo exactly the 2 wrappers, with no arguments" || fail "sudo -l: [$l]"
denied "player cannot sudo anything else" sudo -n /bin/true

# --- the validator and the wrapper ---------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^GREEN: ' && pass "validator green on the seed: $out" \
    || fail "validator on the seed: exit $rc: $out"
out=$(docker exec -u pgwatch "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "the GM's validator run (as pgwatch) green" || fail "GM validator: exit $rc: $out"
pssh "cp $CONF ~/sources.yaml.good"
pid0=$(pgwatch_pid)
pssh "printf -- '- name: [broken\n' >> $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "^RED config: $CONF is not valid" \
    && pass "validator red on a file pgwatch cannot parse: $(printf '%s' "$out" | cut -c1-160)" \
    || fail "validator on broken YAML: exit $rc: $out"
out=$(pssh sudo -n gm-restart-pgwatch 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "pgwatch was NOT restarted" \
    && pass "gm-restart-pgwatch refuses a file that is not valid (exit 1)" || fail "restart on broken YAML: exit $rc: $out"
[ "$(pgwatch_pid)" = "$pid0" ] && pass "the running pgwatch is left alone (pid $pid0)" || fail "pgwatch restarted anyway"
pssh "sed 's/is_enabled: true/is_enabled: false/' ~/sources.yaml.good > $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'no enabled source' \
    && pass "validator red on a file enabling no source" || fail "validator on no enabled source: exit $rc: $out"
# a second source, on a host that never resolves: applied by pgwatch's own
# refresh, without the wrapper
pssh "cat ~/sources.yaml.good > $CONF && printf -- '- name: ghost\n  conn_str: postgresql://monitoring@ghost:5432/postgres\n  kind: postgres\n  preset_metrics: basic\n  is_enabled: true\n' >> $CONF"
i=0; g=
while [ "$i" -lt 100 ]; do g=$(up_of ghost); [ -n "$g" ] && break; sleep 4; i=$((i + 4)); done
[ "$g" = 0 ] && [ "$(pgwatch_pid)" = "$pid0" ] \
    && pass "pgwatch rereads the file on its own (ghost watched, instance_up 0, ${i}s, same process)" \
    || fail "refresh without the wrapper: ghost [$g] after ${i}s"
out=$(pssh sudo -n gm-restart-pgwatch 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'db: pgwatch_instance_up 1: reached' \
    && printf '%s' "$out" | grep -q 'ghost: pgwatch_instance_up 0: NOT reached' \
    && pass "gm-restart-pgwatch applies at once and names what it reached: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)" \
    || fail "restart with ghost: exit $rc: $out"
[ "$(pgwatch_pid)" != "$pid0" ] && pass "a new pgwatch process after the wrapper" || fail "same process after the wrapper"
pssh "cat ~/sources.yaml.good > $CONF" && pssh sudo -n gm-restart-pgwatch >/dev/null 2>&1 \
    || fail "restore the seed's sources"

# --- a file not valid at start ------------------------------------------------------------
pssh "printf -- '- name: [broken\n' > $CONF"
gm /command/s6-svc -r /run/service/pgwatch
sleep 3
[ -z "$(pgwatch_pid)" ] && pass "not valid at start: pgwatch not started" || fail "started with a file not valid"
check "the log says why" sh -c "docker service logs --since 1m --raw $SERVICE 2>&1 | grep -q 'pgwatch: NOT started: $CONF is not valid for pgwatch'"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED config: ' && printf '%s' "$out" | grep -q '^RED server: ' \
    && pass "validator red: config and server (exit 1)" || fail "service down: exit $rc: $out"
[ "$(docker inspect -f '{{.State.Health.Status}}' "$C")" = healthy ] && pass "the node stays healthy with pgwatch down" \
    || fail "health with pgwatch down"
pssh "cat ~/sources.yaml.good > $CONF"
out=$(pssh sudo -n gm-restart-pgwatch 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'db: pgwatch_instance_up 1' \
    && pass "gm-restart-pgwatch starts a service that was down (exit 0)" || fail "start from down: exit $rc: $out"

# --- persistence across a new container ---------------------------------------------------
marker0=$(gm cat "$MARKER")
pssh "sed -i 's/^- name: db .*/- name: db                          # edited by player/' $CONF && echo 'audit notes' > ~/report.md" \
    || fail "edit before a new container"
info "forcing a new container (docker service update --force)"
docker service update --force --detach "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then pass "new container healthy ($C2)"; C=$C2; else fail "new container did not become healthy"; fi
check "$CONF edits kept in a new container (not re-seeded)" gm grep -q 'edited by player' "$CONF"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
[ "$(pssh cat report.md 2>&1)" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container"
i=0; u=; while [ "$i" -lt 60 ]; do u=$(up_of db); [ "$u" = 1 ] && break; sleep 3; i=$((i + 3)); done
[ "$u" = 1 ] && pass "instance_up 1 in the new container (db resolves at once: no wait)" || fail "instance_up in new container: [$u]"
check "no wait when the host resolves" sh -c "docker service logs --since 3m --raw $SERVICE 2>&1 | grep -q \"pgwatch-run: sources' hosts resolve: db\""

# --- the snapshot: every volume by copy, the node running -----------------------------------
snap=$(docker exec -i -u root "$C" sh -s 2>&1 <<'SNAPSHOT'
for v in /etc/pgwatch /home/player /var/lib/gm-state; do
    tar --create --file=- --numeric-owner --directory="$v" . > /run/tmp/copy.tar
    echo "$v rc=$? bytes=$(wc -c < /run/tmp/copy.tar)"
done
rm -f /run/tmp/copy.tar
SNAPSHOT
)
[ "$(printf '%s\n' "$snap" | grep -c ' rc=0 bytes=[1-9]')" -eq 3 ] && [ -n "$(pgwatch_pid)" ] \
    && pass "snapshot: pwconf, home, gmstate copied by tar while pgwatch runs" || fail "snapshot copy: $snap"

# --- the footprint at rest ------------------------------------------------------------------
sleep 20
st=$(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' "$C")
info "footprint at rest: docker stats $st; memory.peak $(gm cat /sys/fs/cgroup/memory.peak) bytes; pgwatch RSS $(gm ps -o rss= -p "$(pgwatch_pid)" | tr -d ' ') kB; image $(docker image inspect -f '{{.Size}}' "$IMAGE") bytes"

# --- report-only ---------------------------------------------------------------------------
REFUSAL='gm-restart-pgwatch: this node is report-only: its files cannot be changed, so nothing was reloaded.'
info "redeploying the node report-only (GM_WRITE_POLICY=report-only)"
docker service update --detach --env-add GM_WRITE_POLICY=report-only "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "report-only container healthy ($C)"; else fail "report-only container"; fi
m=$(gm stat -c '%a %U:%G' /etc/pgwatch "$CONF" | tr '\n' ' ')
[ "$m" = "2755 pgwatch:pwconf 644 pgwatch:pwconf " ] && pass "report-only: owners and modes ($m)" || fail "report-only modes: $m"
denied "report-only: player cannot edit $CONF" "echo '# x' >> $CONF"
denied "report-only: player cannot create a file in /etc/pgwatch" touch /etc/pgwatch/x.yaml
pid0=$(pgwatch_pid)
out=$(pssh sudo -n gm-restart-pgwatch 2>&1); rc=$?
[ "$rc" -eq 1 ] && [ "$out" = "$REFUSAL" ] && pass "gm-restart-pgwatch refuses (exit 1): $out" || fail "report-only restart: exit $rc: $out"
sleep 2
[ -n "$pid0" ] && [ "$(pgwatch_pid)" = "$pid0" ] && pass "report-only: nothing restarted (pid $pid0)" || fail "report-only: restarted anyway"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-validate is never refused (green, exit 0)" || fail "validate report-only: exit $rc: $out"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/bin" sh -c "! docker exec $C touch /usr/local/bin/x"
for f in /opt/gm/validator/validate.sh /usr/local/sbin/gm-restart-pgwatch /usr/local/lib/gm/pgwatch-sources \
         /usr/local/bin/pgwatch /etc/s6-overlay/s6-rc.d/pgwatch/run; do
    denied "player cannot write $f" "echo x >> $f"
done
check "player cannot create the emergency pause file" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@pgwatch 'touch /run/gm-pgwatch/emergency-pause'"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"

# --- the entrypoint's refusals ------------------------------------------------------------
printf 'line1\nline2\n' > "$tmp/pw_lines"
for k in missing lines; do
    case $k in
        missing) mount= ; want='secret /opt/gm/secrets/monitoring_password is missing or empty' ;;
        lines) mount="-v $tmp/pw_lines:$SECRET:ro" ; want='secret monitoring_password must be a single line' ;;
    esac
    out=$(docker run --name "${STACK}-secret-$k" --rm -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" $mount "$IMAGE" 2>&1); rc=$?
    if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want"; then
        pass "the entrypoint refuses a $k password (exit $rc)"
    else
        fail "$k password: exit $rc: $out"
    fi
done
want="gm-entrypoint: fatal: GM_WRITE_POLICY='read-only' is not one of fixable, report-only, no-access"
out=$(docker run --name "${STACK}-refuse-policy" --rm -e GM_WRITE_POLICY=read-only \
    -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" -v "$tmp/monitoring_password:$SECRET:ro" \
    -v "$HERE/fixtures/sources.yaml:/opt/gm/seed/sources.yaml:ro" "$IMAGE" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF "$want" && pass "the entrypoint refuses an unknown write policy" \
    || fail "policy refusal: exit $rc: $(printf '%s' "$out" | tail -n 2)"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
