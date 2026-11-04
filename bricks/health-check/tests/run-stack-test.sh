#!/bin/sh
# Stack test of the health-check brick (v0.5 build plan, chunk 10b; G9's
# build conditions, v0.5 wave log; specs D356, D362).
#
# Deploys the brick as a Swarm stack (stack.test.yml) with a postgres 0.5.0
# primary `db` and its standby `standby` (option monitoring, TLS on), and a
# stand-in for cold storage's GET /manifests (`cold-storage`). The health
# node starts BEFORE the databases (deployed at 0 replicas, then scaled up;
# the standby cloned as load-data does). From a client container on the
# stack's network and from the GM side (docker exec), it checks:
#   - the bounded wait: the node waits up to 30 s for db and standby to
#     resolve, says so, runs the checks anyway at the bound, and the page
#     shows their honest failure (CRITICAL, the name not resolved); once the
#     names resolve, the checks read them;
#   - every check_postgres action of the set, run against PostgreSQL 18 as
#     monitoring, through PGPASSFILE (G9): connection, backends, locks,
#     txn_wraparound, last_autovacuum, last_analyze, database_size on each
#     instance, hot_standby_delay on the standby; each a check_postgres line
#     with its state and time on the page and in status.txt;
#   - cron runs the crontab's lines (the checks and a script) on its own;
#   - the customer's scripts: the disk alarm's sizes; the backup script
#     asking the stand-in's GET /manifests?type=basebackup&from=<yesterday>,
#     found (OK) and missing (CRITICAL), and a broken answer (UNKNOWN), each
#     on the page;
#   - the page: nginx static only, /health/ and status.txt, GET and HEAD
#     only, no listing, no version; through no proxy;
#   - the password: in the secret and /run/gm-health/pgpass (0600, postgres)
#     only; not readable by player, never on the page or a command line;
#   - SSH as `player`, sudo exactly gm-crontab, gm-run-checks, gm-validate;
#   - the validator: green; red on a health.yaml that is not valid (the page
#     says no check ran) and on a crontab naming a missing script;
#   - report-only: health.yaml and the scripts not writable, gm-crontab
#     refusing a replacement; edits survive a new container; the snapshot;
#   - the entrypoint refuses a missing password; read-only root; the
#     footprint at rest.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager, the images built locally (the postgres image is
# the databases, the stand-in and the test client: it has ssh and perl):
#   docker build -t 127.0.0.1:5000/dbagm/health-check:0.1.0 bricks/health-check
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Usage: sh bricks/health-check/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
STACK=gmtest-health
IMAGE=127.0.0.1:5000/dbagm/health-check:0.1.0
CLIENT_IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.0
SERVICE=${STACK}_health
DB_SERVICE=${STACK}_db
SB_SERVICE=${STACK}_standby
CS_SERVICE=${STACK}_cold-storage
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk10-health-check
CONFIGS="seed_health_yaml seed_crontab seed_script_disk_alarm seed_script_backup_there seed_postgresql_conf seed_pg_hba_conf envelopes manifests_standin"
SECRETS="player_ssh_pubkey dba_password monitoring_password replication_password tls_certificate tls_key"
VOLUMES="hc_conf hc_data hc_cronspool hc_home hc_gmstate hc_run db_pgdata db_pgconf db_home db_gmstate db_pglog db_run db_cronspool sb_pgdata sb_pgconf sb_home sb_gmstate sb_pglog sb_run sb_cronspool"
PG_FIXTURES=$HERE/../../postgres/tests/fixtures
COMPANION=$HERE/../companion
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
CONF=/etc/health/health.yaml
SECRET=/opt/gm/secrets/monitoring_password
PASSFILE=/run/gm-health/pgpass
PAGE=/var/lib/health/www/health/index.html
STATUS=/var/lib/health/www/health/status.txt
MARKER=/var/lib/gm-state/.gm-seeded
ACTIONS="connection backends locks txn_wraparound last_autovacuum last_analyze database_size"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-health.XXXXXX")

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" "${STACK}-secret-missing" >/dev/null 2>&1
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
    find "$REPO/tools" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
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
printf 'mon:%s\\x' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/monitoring_password"
MONPW=$(cat "$tmp/monitoring_password")
mkdir -p "$tmp/secrets"
printf 'rep%s' "$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')" > "$tmp/secrets/replication_password"
(cd "$REPO" && python3 -c 'import sys; from pathlib import Path; from tools.gm import deploy
deploy.openssl_certificate(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:])' \
    "$tmp/tls.crt" "$tmp/tls.key" db standby localhost) || { echo "no TLS pair" >&2; exit 2; }
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
cfg seed_health_yaml "$HERE/fixtures/health.yaml"
cfg seed_crontab "$HERE/fixtures/crontab"
cfg seed_script_disk_alarm "$COMPANION/scripts/disk-alarm"
cfg seed_script_backup_there "$COMPANION/scripts/backup-there"
cfg seed_postgresql_conf "$PG_FIXTURES/postgresql-standby.conf"
cfg seed_pg_hba_conf "$HERE/fixtures/pg_hba.conf"
cfg envelopes "$PG_FIXTURES/envelopes.conf"
cfg manifests_standin "$HERE/fixtures/manifests-standin.pl"
sec() { docker secret create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
sec player_ssh_pubkey "$tmp/id.pub"
sec dba_password "$tmp/dba_password"
sec monitoring_password "$tmp/monitoring_password"
sec replication_password "$tmp/secrets/replication_password"
sec tls_certificate "$tmp/tls.crt"
sec tls_key "$tmp/tls.key"

info "deploying stack $STACK: the health node first, db and standby at 0 replicas (not in DNS)"
DB_REPLICAS=0 docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1
t_deploy=$(date +%s)

set +e

container() { docker ps -q -f "label=com.docker.swarm.service.name=$1" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy <service> [old-container-id]
    i=0
    while [ "$i" -lt 240 ]; do
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
    pass "health node healthy with db and standby not yet in DNS ($C, $(($(date +%s) - t_deploy))s after the deployment)"
else
    fail "health node did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi

docker run -d --name "$CLIENT" --network "$NET" -v "$tmp:/k:ro" \
    --entrypoint /bin/sh "$CLIENT_IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 180 ssh $SSH_OPTS player@health "$@"; }
gm() { docker exec -i "$C" "$@"; }
asp() { docker exec -i -u postgres "$C" "$@"; }   # as cron runs a line
PERL_HTTP='use IO::Socket::INET; my ($m, $h, $p, $u) = @ARGV;
my $s = IO::Socket::INET->new(PeerAddr => $h, PeerPort => $p, Timeout => 5) or exit 9;
print $s "$m $u HTTP/1.0\r\nHost: $h:$p\r\nContent-Length: 0\r\n\r\n"; local $/; print <$s>;'
nhttp() { docker exec -i "$CLIENT" timeout 10 perl -e "$PERL_HTTP" "$@" | tr -d '\r'; }
status_of() { sed -n '1s/^HTTP\/[0-9.]* \([0-9]*\).*/\1/p'; }
page() { nhttp GET health 8080 /health/ | sed '1,/^$/d'; }
statustxt() { nhttp GET health 8080 /health/status.txt | sed '1,/^$/d'; }
denied() {
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
line_of() {  # line_of <instance> <check>: its status.txt line
    statustxt | grep " $1 $2: " | head -n 1
}

# --- the bounded wait, then an honest failure (spec D356) ---------------------
# the node is healthy as soon as the entrypoint's empty page answers: wait
# for the wait's end and the first run
i=0
while [ "$i" -lt 90 ] && ! docker service logs --raw "$SERVICE" 2>&1 | grep -q '^health-start: first run: '; do
    sleep 2; i=$((i + 2))
done
logs=$(docker service logs --raw "$SERVICE" 2>&1)
printf '%s\n' "$logs" | grep -q "health-start: waiting up to 30s for instances' hosts to resolve: db standby" \
    && pass "the node waits, bounded (30 s), for db and standby to resolve, and says so" \
    || fail "no bounded-wait line: $(printf '%s\n' "$logs" | grep health-start | head -n 3)"
w=$(printf '%s\n' "$logs" | sed -n "s/^health-start: still not resolving after \([0-9]*\)s: db standby; the checks run anyway$/\1/p" | head -n 1)
[ -n "$w" ] && [ "$w" -ge 30 ] && [ "$w" -le 40 ] && pass "the wait ends at its bound (${w}s); the checks run anyway" \
    || fail "wait outcome: [$w]"
printf '%s\n' "$logs" | grep -q '^health-start: first run: health-run checks: ' \
    && pass "a first run at start: $(printf '%s\n' "$logs" | sed -n 's/^health-start: first run: //p' | head -n 1)" \
    || fail "no first run at start"
l=$(line_of db connection)
case $l in *" CRITICAL db connection: POSTGRES_CONNECTION CRITICAL"*"could not translate host name"*)
    pass "the page shows the honest failure: $l" ;; *) fail "db connection while unresolved: [$l]" ;; esac
r=$(nhttp GET health 8080 /health/)
[ "$(printf '%s' "$r" | status_of)" = 200 ] && pass "the page answers while the databases do not resolve" || fail "page: $(printf '%s' "$r" | head -n 1)"

info "scaling db and standby to 1"
docker service scale --detach "$DB_SERVICE=1" "$SB_SERVICE=1" >/dev/null 2>&1
DB=$(wait_healthy "$DB_SERVICE") && pass "db healthy ($DB)" || { fail "db did not become healthy"; exit 1; }
SB=$(wait_healthy "$SB_SERVICE") && pass "standby healthy ($SB)" || { fail "standby did not become healthy"; exit 1; }
# the standby cloned as load-data does (chunk 3: replication_sql, clone-standby)
(cd "$REPO" && python3 -c 'import sys; from pathlib import Path; from tools.gm import inject
sys.stdout.write(inject.replication_sql(Path(sys.argv[1]), "standby"))' "$tmp") \
    | docker exec -i -u postgres "$DB" psql -X -q -v ON_ERROR_STOP=1 -d postgres >/dev/null 2>"$tmp/repl.err" \
    && pass "db: the replication role (inject.replication_sql)" || fail "replication role: $(cat "$tmp/repl.err")"
out=$(docker exec "$SB" /usr/local/lib/gm/clone-standby 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "standby cloned and streaming (clone-standby exit 0)" || fail "clone-standby: exit $rc: $(printf '%s' "$out" | tail -n 3)"
SB=$(wait_healthy "$SB_SERVICE") || fail "standby not healthy after the clone"
w=$(docker exec -u postgres "$SB" psql -XAtc 'select pg_is_in_recovery()' 2>&1)
[ "$w" = t ] && pass "standby in recovery" || fail "standby recovery: $w"

# --- every check of the set, against PostgreSQL 18 (G9) -------------------------------
out=$(pssh sudo -n gm-run-checks 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "sudo gm-run-checks: $out" || fail "gm-run-checks: exit $rc: $out"
for inst in db standby; do
    for a in $ACTIONS; do
        case $inst/$a in standby/last_autovacuum|standby/last_analyze) continue ;; esac
        l=$(line_of "$inst" "$a")
        A=$(printf '%s' "$a" | tr a-z A-Z)
        case $l in
            *" OK $inst $a: POSTGRES_$A OK: "*)
                pass "$inst $a: $l" ;;
            *" UNKNOWN $inst $a: POSTGRES_$A UNKNOWN: "*"No matching tables have ever been"*)
                pass "$inst $a, nothing to judge on a fresh cluster: $l" ;;
            *) fail "$inst $a: [$l]" ;;
        esac
    done
done
l=$(line_of standby hot_standby_delay)
case $l in *" OK standby hot_standby_delay: POSTGRES_HOT_STANDBY_DELAY OK: "*) pass "standby hot_standby_delay (against db): $l" ;;
    *) fail "standby hot_standby_delay: [$l]" ;; esac
check "no replay delay checked on the primary" sh -c "! docker exec $C grep -q ' db hot_standby_delay' $STATUS"
check "no autovacuum check on the standby" sh -c "! docker exec $C grep -q ' standby last_autovacuum' $STATUS"
n=$(statustxt | grep -c ' \(OK\|WARNING\|CRITICAL\|UNKNOWN\) \(db\|standby\) ')
[ "$n" -eq 13 ] && pass "13 check lines (7 on db, 6 on standby), each with its state and time" || fail "check lines: $n"
p=$(page)
for want in '<h1>Health checks</h1>' '<td>db</td><td>connection</td><td>OK</td>' '<td>standby</td><td>hot_standby_delay</td><td>OK</td>'; do
    printf '%s' "$p" | grep -qF "$want" && pass "the HTML page lists: $want" || fail "the page lacks: $want"
done
printf '%s' "$p" | grep -Eq '<td>[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z</td>' \
    && pass "each line with its time (UTC)" || fail "no time on the page"
c=$(docker exec -u postgres "$DB" psql -XAtc "select count(*) from pg_stat_activity a join pg_stat_ssl s using (pid) where a.usename = 'monitoring' and s.ssl" 2>&1)
info "monitoring sessions on db now (TLS): $c"
w=$(docker exec "$DB" sh -c "cat /var/log/postgresql/postgresql-*.log" 2>/dev/null | grep -c 'connection authorized: user=monitoring.*SSL enabled')
[ "$w" -ge 1 ] && pass "the checks connect as monitoring over TLS ($w sessions logged)" || fail "no monitoring TLS session in db's log"

# --- the customer's scripts ---------------------------------------------------------------
YESTERDAY=$(date -u -d yesterday +%Y-%m-%d)
cs() { docker exec -i "$(container "$CS_SERVICE")" "$@"; }
cs sh -c 'echo found > /srv/standin/mode'
out=$(asp health-run script backup-there http://cold-storage:8000 db 2>&1)
case $out in *"BACKUP OK: 1 basebackup manifest(s) since $YESTERDAY"*) pass "backup script, found: $out" ;; *) fail "backup found: $out" ;; esac
q=$(cs tail -n 1 /srv/standin/requests.log)
[ "$q" = "GET /manifests?type=basebackup&from=$YESTERDAY&source=db" ] && pass "it asks the stand-in: $q" || fail "the request: [$q]"
statustxt | grep -q " OK script backup-there: BACKUP OK: " && pass "the page shows the backup found" || fail "page: backup found"
cs sh -c 'echo missing > /srv/standin/mode'
out=$(asp health-run script backup-there http://cold-storage:8000 db 2>&1)
case $out in *"CRITICAL: BACKUP CRITICAL: no basebackup manifest since $YESTERDAY"*) pass "backup script, missing: $out" ;; *) fail "backup missing: $out" ;; esac
statustxt | grep -q " CRITICAL script backup-there: BACKUP CRITICAL: " && pass "the page shows the backup missing" || fail "page: backup missing"
page | grep -qF '<tr class="critical"><td>backup-there http://cold-storage:8000 db</td><td>CRITICAL</td>' \
    && pass "the HTML page: backup-there CRITICAL" || fail "HTML page: backup-there"
cs sh -c 'echo broken > /srv/standin/mode'
out=$(asp health-run script backup-there http://cold-storage:8000 db 2>&1)
case $out in *"UNKNOWN: BACKUP UNKNOWN: cold storage answered, but not a list"*) pass "backup script, a broken answer: UNKNOWN" ;; *) fail "backup broken: $out" ;; esac
out=$(asp health-run script backup-there http://nowhere:8000 db 2>&1)
case $out in *"UNKNOWN: BACKUP UNKNOWN: cold storage did not answer"*) pass "backup script, no cold storage: UNKNOWN" ;; *) fail "backup unreachable: $out" ;; esac
cs sh -c 'echo found > /srv/standin/mode'
out=$(asp health-run script disk-alarm 2048 4096 db standby 2>&1)
case $out in *"OK: DISK OK: db "*" MB; standby "*" MB"*) pass "disk alarm: $out" ;; *) fail "disk alarm: $out" ;; esac
out=$(asp health-run script disk-alarm 1 4096 db 2>&1)
case $out in *"WARNING: DISK WARNING: db "*"(warning at 1)"*) pass "disk alarm over the IT's threshold: WARNING" ;; *) fail "disk warning: $out" ;; esac
out=$(asp health-run script missing-one 2>&1)
case $out in *"UNKNOWN: /etc/health/scripts/missing-one is not a regular file"*) pass "a script that is not there: UNKNOWN on the page" ;; *) fail "missing script: $out" ;; esac
asp rm -f /var/lib/health/results/script-missing-one.json
asp health-run page >/dev/null 2>&1

# --- cron runs the crontab on its own -------------------------------------------------------
pssh "sudo -n gm-crontab -l > ~/crontab.good" || fail "gm-crontab -l"
check "gm-crontab -l lists the seed's lines" sh -c "docker exec $CLIENT ssh $SSH_OPTS player@health cat crontab.good | grep -q '^\*/5 \* \* \* \* health-run checks$'"
pssh "sed -e 's#^\*/5 \* \* \* \* health-run checks#* * * * * health-run checks#' -e 's#^30 6 \* \* \* health-run script backup-there#* * * * * health-run script backup-there#' ~/crontab.good > ~/crontab.every-minute"
out=$(pssh sudo -n gm-crontab crontab.every-minute 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-crontab installs a crontab read as player: $out" || fail "gm-crontab install: exit $rc: $out"
m0=$(gm stat -c %Y /var/lib/health/results/checks.json); b0=$(gm stat -c %Y /var/lib/health/results/script-backup-there.json)
i=0
while [ "$i" -lt 130 ]; do
    m1=$(gm stat -c %Y /var/lib/health/results/checks.json); b1=$(gm stat -c %Y /var/lib/health/results/script-backup-there.json)
    [ "$m1" != "$m0" ] && [ "$b1" != "$b0" ] && break
    sleep 5; i=$((i + 5))
done
[ "$m1" != "$m0" ] && [ "$b1" != "$b0" ] && pass "cron runs the checks and a script line on its own (${i}s)" || fail "cron did not run them (${i}s)"
out=$(pssh sudo -n gm-crontab crontab.good 2>&1) && pass "the seed's crontab put back" || fail "restore crontab: $out"

# --- the page, nginx static only -------------------------------------------------------
r=$(nhttp GET health 8080 /health/)
[ "$(printf '%s' "$r" | status_of)" = 200 ] && printf '%s' "$r" | grep -qi '^content-type: text/html' \
    && pass "GET /health/: 200 text/html" || fail "GET /health/: $(printf '%s' "$r" | head -n 3)"
printf '%s' "$r" | grep -i '^server:' | grep -q '[0-9]' && fail "the Server header shows a version" || pass "no version in the Server header"
r=$(nhttp HEAD health 8080 /health/status.txt); [ "$(printf '%s' "$r" | status_of)" = 200 ] && pass "HEAD /health/status.txt: 200" || fail "HEAD: $(printf '%s' "$r" | head -n 1)"
r=$(nhttp POST health 8080 /health/); [ "$(printf '%s' "$r" | status_of)" = 403 ] && pass "POST /health/: 403 (GET and HEAD only)" || fail "POST: $(printf '%s' "$r" | head -n 1)"
r=$(nhttp GET health 8080 /health); [ "$(printf '%s' "$r" | status_of)" = 301 ] && pass "GET /health: 301 to /health/" || fail "GET /health: $(printf '%s' "$r" | head -n 1)"
r=$(nhttp GET health 8080 /); [ "$(printf '%s' "$r" | status_of)" = 403 ] && pass "GET /: 403 (no page there, no listing)" || fail "GET /: $(printf '%s' "$r" | head -n 1)"
r=$(nhttp GET health 8080 /etc/passwd); [ "$(printf '%s' "$r" | status_of)" = 404 ] && pass "GET of any other path: 404" || fail "GET /etc/passwd: $(printf '%s' "$r" | head -n 1)"
gm rm -f "$PAGE.keep"; asp mv "$PAGE" "$PAGE.keep"
r=$(nhttp GET health 8080 /health/); [ "$(printf '%s' "$r" | status_of)" = 403 ] && pass "no directory listing (autoindex off: 403 without index.html)" || fail "listing: $(printf '%s' "$r" | head -n 1)"
asp mv "$PAGE.keep" "$PAGE"
w=$(gm sh -c "ps -C nginx -o user= | sort -u | tr '\n' ' '")
[ "$w" = "www-data " ] && pass "nginx runs as www-data only" || fail "nginx users: [$w]"
# Docker's embedded DNS listens on 127.0.0.11 (0B00007F) in every container
w=$(gm sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null | awk "\$4 == \"0A\" && \$2 !~ /^0B00007F:/ { print \$2 }" | sed "s/.*://" | sort -u | tr "\n" " "')
[ "$w" = "0016 1F90 " ] && pass "listening: 22 and 8080 only (Docker's DNS aside)" || fail "listening ports (hex): [$w]"

# --- the password ----------------------------------------------------------------
m=$(gm stat -c '%a %U:%G' "$PASSFILE")
[ "$m" = "600 postgres:postgres" ] && pass "$PASSFILE: 600 postgres:postgres" || fail "$PASSFILE: $m"
esc=$(printf '%s' "$MONPW" | sed 's/[\\:]/\\&/g')
[ "$(gm cat "$PASSFILE")" = "*:*:*:monitoring:$esc" ] && pass "the password file escapes : and \\" || fail "password file content"
denied "player cannot read the secret" cat "$SECRET"
denied "player cannot read the password file" cat "$PASSFILE"
check "the password is on no page or result" sh -c "! docker exec $C grep -rqF -- '$MONPW' /var/lib/health /etc/health"

# --- SSH and sudo --------------------------------------------------------------------
[ "$(pssh whoami 2>&1)" = player ] && pass "SSH as player (key from the secret)" || fail "SSH as player"
l=$(pssh sudo -n -l 2>&1 | sed -n 's/^ *(root) NOPASSWD: //p' | tr ',' '\n' | sed 's/^ *//' | sort | tr '\n' ' ')
[ "$l" = '/usr/local/sbin/gm-crontab /usr/local/sbin/gm-run-checks "" /usr/local/sbin/gm-validate "" ' ] \
    && pass "player may sudo exactly gm-crontab, gm-run-checks and gm-validate" || fail "sudo -l: [$l]"
denied "player cannot sudo anything else" sudo -n /bin/true
denied "player cannot read postgres's crontab in the spool" cat /var/spool/cron/crontabs/postgres

# --- the validator ---------------------------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^GREEN: ' && pass "validator green: $out" || fail "validator: exit $rc: $out"
pssh "cp $CONF ~/health.yaml.good && printf '  - name: Bad\n    host: x\n    colour: red\n' >> $CONF"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q "^RED config: $CONF is not valid" && printf '%s' "$out" | grep -q 'unknown key colour' \
    && pass "validator red on a health.yaml that is not valid (line numbers, keys)" || fail "validator on bad yaml: exit $rc: $out"
pssh sudo -n gm-run-checks >/dev/null 2>&1
statustxt | grep -q 'UNKNOWN - health.yaml: health.yaml is not valid, no check run' \
    && pass "the page says no check ran, and why" || fail "page with a bad health.yaml: $(statustxt | head -n 3)"
pssh "cat ~/health.yaml.good > $CONF" && pssh sudo -n gm-run-checks >/dev/null 2>&1
pssh "sed 's/disk-alarm 2048/disk-alarms 2048/' ~/crontab.good > ~/crontab.bad && sudo -n gm-crontab crontab.bad" >/dev/null 2>&1
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED scripts: the crontab runs disk-alarms' \
    && pass "validator red on a crontab naming a script that is not there" || fail "validator on missing script: exit $rc: $out"
pssh sudo -n gm-crontab crontab.good >/dev/null 2>&1

# --- persistence across a new container ---------------------------------------------------
marker0=$(gm cat "$MARKER")
pssh "sed -i 's/^  - name: db$/  - name: db                        # edited by player/' $CONF && echo 'audit notes' > ~/report.md" \
    || fail "edit before a new container"
info "forcing a new container (docker service update --force)"
docker service update --force --detach "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then pass "new container healthy ($C2)"; C=$C2; else fail "new container"; fi
check "health.yaml edits kept (not re-seeded)" gm grep -q 'edited by player' "$CONF"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept (volume gmstate)" || fail "marker after new container"
check "the crontab kept (volume cronspool)" sh -c "docker exec $C crontab -u postgres -l | grep -q 'disk-alarm 2048'"
check "the scripts kept, 0775 postgres:healthconf" sh -c "[ \"\$(docker exec $C stat -c '%a %U:%G' /etc/health/scripts/disk-alarm)\" = '775 postgres:healthconf' ]"
i=0
while [ "$i" -lt 60 ] && ! docker service logs --since 3m --raw "$SERVICE" 2>&1 | grep -q '^health-start: first run: '; do sleep 2; i=$((i + 2)); done
check "no wait when the hosts resolve" sh -c "docker service logs --since 3m --raw $SERVICE 2>&1 | grep -q \"health-start: instances' hosts resolve: db standby\""
l=$(line_of db connection)
case $l in *" OK db connection: POSTGRES_CONNECTION OK"*) pass "the first run in the new container reads db at once: $l" ;; *) fail "first run, new container: [$l]" ;; esac

# --- the snapshot ----------------------------------------------------------------------
snap=$(docker exec -i -u root "$C" sh -s 2>&1 <<'SNAPSHOT'
for v in /etc/health /var/lib/health /var/spool/cron/crontabs /home/player /var/lib/gm-state; do
    tar --create --file=- --numeric-owner --directory="$v" . > /run/tmp/copy.tar
    echo "$v rc=$? bytes=$(wc -c < /run/tmp/copy.tar)"
done
rm -f /run/tmp/copy.tar
SNAPSHOT
)
[ "$(printf '%s\n' "$snap" | grep -c ' rc=0 bytes=[1-9]')" -eq 5 ] && pass "snapshot: the five volumes copied by tar while the node runs" || fail "snapshot: $snap"

# --- the footprint at rest ------------------------------------------------------------------
sleep 20
st=$(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' "$C")
asp health-run checks >/dev/null 2>&1
info "footprint at rest: docker stats $st; memory.peak (a check run included) $(gm cat /sys/fs/cgroup/memory.peak) bytes; image $(docker image inspect -f '{{.Size}}' "$IMAGE") bytes"

# --- report-only ---------------------------------------------------------------------------
info "redeploying the node report-only (GM_WRITE_POLICY=report-only)"
docker service update --detach --env-add GM_WRITE_POLICY=report-only "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then C=$C2; pass "report-only container healthy ($C)"; else fail "report-only container"; fi
m=$(gm stat -c '%a %U:%G' /etc/health "$CONF" /etc/health/scripts /etc/health/scripts/backup-there | tr '\n' ' ')
[ "$m" = "2755 postgres:healthconf 644 postgres:healthconf 2755 postgres:healthconf 755 postgres:healthconf " ] \
    && pass "report-only: owners and modes ($m)" || fail "report-only modes: $m"
denied "report-only: player cannot edit health.yaml" "echo '# x' >> $CONF"
denied "report-only: player cannot edit a script" "echo '# x' >> /etc/health/scripts/disk-alarm"
denied "report-only: player cannot add a script" touch /etc/health/scripts/new
out=$(pssh sudo -n gm-crontab crontab.good 2>&1); rc=$?
[ "$rc" -eq 1 ] && [ "$out" = "gm-crontab: this node is report-only: its crontab cannot be replaced; nothing installed." ] \
    && pass "report-only: gm-crontab refuses a replacement (exit 1)" || fail "report-only gm-crontab: exit $rc: $out"
check "report-only: gm-crontab -l still lists" pssh sudo -n gm-crontab -l
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "report-only: gm-validate green" || fail "validate report-only: exit $rc: $out"

# --- hardening, refusals --------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
for f in /usr/local/bin/health-run /usr/local/lib/gm/nginx.conf /opt/gm/validator/validate.sh /usr/local/sbin/gm-crontab; do
    denied "player cannot write $f" "echo x >> $f"
done
denied "player cannot write the page" "echo x >> $PAGE"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}}' "$C")
[ "$caps" = "[ALL]" ] && pass "cap_drop ALL" || fail "cap_drop: $caps"
out=$(docker run --name "${STACK}-secret-missing" --rm -v "$tmp/id.pub:/opt/gm/secrets/player_ssh_pubkey:ro" "$IMAGE" 2>&1); rc=$?
[ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qF 'secret /opt/gm/secrets/monitoring_password is missing or empty' \
    && pass "the entrypoint refuses a missing password" || fail "missing password: exit $rc: $out"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
