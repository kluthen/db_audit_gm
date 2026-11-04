#!/bin/sh
# Stack test of the PostgreSQL brick (build plan v0.1 chunk 2, v0.2
# chunk 6, v0.3 chunk 4 and v0.4 chunk 4, Done when).
#
# Deploys the brick as a two-service Swarm stack (stack.test.yml): db, a
# node seeding neither pg_cron nor a crontab, as in 0.3.0, and db2, the
# node with jobs (pg_cron preloaded, a seed crontab, a crontab role). With the
# seed files, the envelope file and the secrets as external configs and
# secrets created here, then checks, from a client container on the
# stack's network and from the GM side (docker exec):
#   - the image serves PostgreSQL 18 and the container becomes healthy;
#   - SSH as `player` works, and `player` may sudo exactly the 3 wrappers;
#   - edits to /etc/postgresql survive gm-restart-db and a new container;
#   - the seed marker (/var/lib/gm-state) is out of player's and postgres's reach;
#   - the validator exits 0 in-envelope and 1 out-of-envelope;
#   - read-only root, capabilities, peer access for postgres;
#   - v0.2: the file log on the log volume (UTC, readable by player, not
#     in the service logs), pgBadger run as player into its home,
#     pg_stat_statements preloaded, the monitoring role (pg_monitor, the
#     secret's password), the secret out of player's reach;
#   - v0.3: the GM's reserve (reserved_connections on the command line),
#     the check role gm_check connecting through check-psql with every
#     ordinary slot taken and reading pg_hba_file_rules, two such sessions
#     fitting and a third refused, the PgBouncer lookup role and
#     gm_pgbouncer.lookup, the roles re-applied at a new container's start;
#     the seeded files' owner and mode restored by gm-reload-db,
#     gm-restart-db and a new container after a player's `sed -i`, never
#     through a symlink; gm-snapshot-db's tar restored into a fresh
#     container of a second stack (gmtest-pgr), with its data, the slot
#     gone, and the slot gone after a failed snapshot;
#   - v0.4 (chunk 4a): on db, the service cron down and gm-crontab refusing
#     to install; on db2, the cron daemon up after postgres and stopped
#     before it, the seed crontab installed once into the spool (volume
#     cronspool) with cron's owner and modes, its entry connecting as the
#     customer role cron_app through the password file /run/gm-cron/pgpass
#     (postgres-only) and appending to its log under
#     /var/log/postgresql/cron/ (read by player), gm-crontab listing,
#     refusing what it must and replacing the crontab, the replacement
#     surviving a new container, an empty crontab leaving the daemon up;
#     pg_cron preloaded, a job scheduled with
#     cron.schedule_in_database(..., username => 'cron_app') running as that
#     role and filling cron.job_run_details. No job is run by hand: each
#     waits for its schedule;
#   - v0.4 (chunk 4b): on both nodes every child of the postmaster at
#     oom_score_adj +300 (PG_OOM_ADJUST_* from the run script), the
#     postmaster, s6, sshd and cron at 0; check-psql --node reaching the
#     other node's instance as gm_check over the game network, both ways,
#     db2 admitting only gm_check from it; the footprint at rest;
#   - v0.5 (chunk 3a): rec, a primary whose seed turns TLS and pgaudit on,
#     serving TLS with the game's certificate (made by gmctl deploy's own
#     generator; verify-full against it, its fingerprint on the wire) and
#     turning plain connections away; pgaudit writing its classes into the
#     file log; no password in that log (initdb's roles before pgaudit is
#     loaded, load-data's password session with pgaudit off, a canary
#     showing what it would log otherwise); db (the option) and rec with the
#     role monitoring, db2 (no option) without it or its secret; an unknown
#     option refused; pdb, a `no-access` node: no player account, group
#     membership, sudo rules, ~/.pgpass or SSH login, sshd and PostgreSQL
#     up, gmctl's exec as postgres working; the image's G5 conditions; the
#     footprint at rest;
#   - v0.5 (chunk 3b): standby, cloned from rec the way load-data does it
#     (inject's own SQL for the replication role and the wait), started
#     while rec is down (the clone waits for it, bounded), then a readable,
#     read-only standby streaming from its slot, seen in rec's
#     pg_stat_replication, its password never in primary_conninfo nor in a
#     log, still streaming in a new container; the hand-over snapshot on
#     both, its temporary slot gone; (chunk 28) clone-standby --restore
#     keeping a setting written into the standby's postgresql.auto.conf,
#     the standby streaming after it, the default mode keeping nothing,
#     an unknown argument a usage error; rec's archive_command posting a
#     switched segment to the vault stand-in with every header, a refusal
#     and a short receipt failing honestly (the segment kept, the reason
#     in the server log), then shipped on the retry; vault-post with no
#     vault and with a bad usage; the nightly base backup moved to the next
#     minute, posted once, whole.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the image built locally:
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Usage: sh bricks/postgres/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-pg
IMAGE=127.0.0.1:5000/dbagm/postgres:0.5.0
SERVICE=${STACK}_db
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk2-postgres
SERVICE2=${STACK}_db2               # the node with jobs (chunk 4)
CONFIGS="seed_postgresql_conf seed_pg_hba_conf envelopes seed_postgresql_jobs_conf seed_pg_hba_jobs_conf seed_crontab seed_postgresql_v05_conf seed_pg_hba_v05_conf seed_pg_hba_partners_conf"
CONFIGS="$CONFIGS seed_postgresql_standby_conf seed_crontab_v05 vault_standin"
SECRETS="player_ssh_pubkey dba_password monitoring_password gm_check_password pgbouncer_lookup_password role_cron_app_password tls_certificate tls_key"
SECRETS="$SECRETS replication_password http_vault_rec"
VOLUMES="pgdata pgconf home gmstate pglog run cronspool pgdata2 pgconf2 home2 gmstate2 pglog2 run2 cronspool2"
VOLUMES="$VOLUMES pgdata3 pgconf3 home3 gmstate3 pglog3 run3 cronspool3 pgdata4 pgconf4 home4 gmstate4 pglog4 run4 cronspool4"
VOLUMES="$VOLUMES pgdata5 pgconf5 home5 gmstate5 pglog5 run5 cronspool5"
REPO=$(cd "$HERE/../../.." && pwd)
SERVICE3=${STACK}_rec               # the v0.5 primary: TLS, pgaudit, the option (chunk 3a)
SERVICE4=${STACK}_pdb               # a no-access node (chunk 3a)
SERVICE5=${STACK}_standby           # rec's standby (chunk 3b)
VSERVICE=${STACK}_vault             # the vault's stand-in (chunk 3b)
RSTACK=gmtest-pgr                 # the snapshot restored (chunk 4b)
RSERVICE=${RSTACK}_db
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
    for st in "$STACK" "$RSTACK"; do
        docker stack rm "$st" >/dev/null 2>&1
    done
    for st in "$STACK" "$RSTACK"; do
        i=0
        while [ "$i" -lt 60 ] && [ -n "$(docker ps -aq -f "label=com.docker.stack.namespace=$st")" ]; do
            sleep 1; i=$((i + 1))
        done
        i=0
        while [ "$i" -lt 30 ] && docker network inspect "${st}_net" >/dev/null 2>&1; do
            sleep 1; i=$((i + 1))
        done
        for v in $VOLUMES; do
            j=0
            while docker volume inspect "${st}_$v" >/dev/null 2>&1 && [ "$j" -lt 20 ]; do
                docker volume rm "${st}_$v" >/dev/null 2>&1 || sleep 1
                j=$((j + 1))
            done
        done
    done
    for c in $CONFIGS; do docker config rm "${STACK}_$c" >/dev/null 2>&1; done
    for s in $SECRETS; do docker secret rm "${STACK}_$s" >/dev/null 2>&1; done
    rm -rf "${tmp:?}"
    left=$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")$(docker ps -aq -f "label=com.docker.stack.namespace=$RSTACK")
    left="$left$(docker volume ls -q -f "name=${STACK}_")$(docker volume ls -q -f "name=${RSTACK}_")$(docker config ls -q -f "name=${STACK}_")$(docker secret ls -q -f "name=${STACK}_")"
    if [ -n "$left" ]; then
        echo "WARNING: teardown left objects behind: $left"
    else
        info "teardown complete: no container, volume, config or secret left"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "image $IMAGE not built" >&2; exit 2; }
for st in "$STACK" "$RSTACK"; do
    if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$st" || true)" ]; then
        echo "stack $st already exists; remove it first" >&2
        exit 2
    fi
done

# --- per-game material, as gmctl deploy would create it ---------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
# A password with the characters .pgpass and SQL must escape.
DBA_PASSWORD="T:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$DBA_PASSWORD" > "$tmp/dba_password"
MON_PASSWORD="M:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$MON_PASSWORD" > "$tmp/monitoring_password"
GMC_PASSWORD="G:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$GMC_PASSWORD" > "$tmp/gm_check_password"
LOOKUP_PASSWORD="L:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"
printf '%s' "$LOOKUP_PASSWORD" > "$tmp/pgbouncer_lookup_password"
APP_PASSWORD="app-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
ROLE_PASSWORD="C:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')'q\\z"   # crontab role cron_app
printf '%s' "$ROLE_PASSWORD" > "$tmp/role_cron_app_password"
# The game's TLS pair, made by gmctl deploy's own generator (v0.5 capture W1
# item 6): every postgres node's name and localhost.
(cd "$REPO" && python3 -c 'import sys; from pathlib import Path; from tools.gm import deploy
deploy.openssl_certificate(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:])' \
    "$tmp/tls.crt" "$tmp/tls.key" db db2 rec standby pdb localhost) || { echo "no TLS pair" >&2; exit 2; }
# The standby's replication role and the vault's credential (chunk 3b): the
# first in secrets/ as gmctl deploy writes it, read by inject's own SQL.
mkdir -p "$tmp/secrets"
REPL_PASSWORD="R:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf '%s' "$REPL_PASSWORD" > "$tmp/secrets/replication_password"
VAULT_CREDENTIAL="V$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf '%s' "$VAULT_CREDENTIAL" > "$tmp/http_vault_rec"
chmod 0644 "$tmp/tls.crt"

docker config create -l "$LABEL" "${STACK}_seed_postgresql_conf" "$HERE/fixtures/postgresql.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_conf" "$HERE/fixtures/pg_hba.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_envelopes" "$HERE/fixtures/envelopes.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_postgresql_jobs_conf" "$HERE/fixtures/postgresql-jobs.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_jobs_conf" "$HERE/fixtures/pg_hba-jobs.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_crontab" "$HERE/fixtures/crontab" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_postgresql_v05_conf" "$HERE/fixtures/postgresql-v05.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_v05_conf" "$HERE/fixtures/pg_hba-v05.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_pg_hba_partners_conf" "$HERE/fixtures/pg_hba-partners.conf" >/dev/null
docker secret create -l "$LABEL" "${STACK}_tls_certificate" "$tmp/tls.crt" >/dev/null
docker secret create -l "$LABEL" "${STACK}_tls_key" "$tmp/tls.key" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_postgresql_standby_conf" "$HERE/fixtures/postgresql-standby.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_seed_crontab_v05" "$HERE/fixtures/crontab-v05" >/dev/null
docker config create -l "$LABEL" "${STACK}_vault_standin" "$HERE/fixtures/vault-standin.pl" >/dev/null
docker secret create -l "$LABEL" "${STACK}_replication_password" "$tmp/secrets/replication_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_http_vault_rec" "$tmp/http_vault_rec" >/dev/null
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_dba_password" "$tmp/dba_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_monitoring_password" "$tmp/monitoring_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_gm_check_password" "$tmp/gm_check_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_pgbouncer_lookup_password" "$tmp/pgbouncer_lookup_password" >/dev/null
docker secret create -l "$LABEL" "${STACK}_role_cron_app_password" "$tmp/role_cron_app_password" >/dev/null

info "deploying stack $STACK"
docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1

# From here on, every check records its own result; keep going on failure.
set +e

db_container() { docker ps -q -f "label=com.docker.swarm.service.name=${1:-$SERVICE}" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy [old-container-id [service]]: prints the healthy container id
    i=0
    while [ "$i" -lt 180 ]; do
        c=$(db_container "${2:-}")
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
if J=$(wait_healthy "" "$SERVICE2"); then
    pass "the node with jobs, db2, deployed and healthy ($J)"
else
    fail "db2 did not become healthy"
    docker service ps --no-trunc "$SERVICE2" || true
    docker service logs --tail 60 "$SERVICE2" 2>&1 || true
    exit 1
fi
for svc in "$SERVICE3" "$SERVICE4" "$SERVICE5"; do
    if c=$(wait_healthy "" "$svc"); then
        pass "v0.5: $svc deployed and healthy ($c)"
    else
        fail "$svc did not become healthy"
        docker service ps --no-trunc "$svc" || true
        docker service logs --tail 60 "$svc" 2>&1 || true
        exit 1
    fi
done
REC=$(db_container "$SERVICE3")
PDB=$(db_container "$SERVICE4")
SB=$(db_container "$SERVICE5")
i=0
while [ "$i" -lt 60 ] && [ -z "$(db_container "$VSERVICE")" ]; do sleep 2; i=$((i + 2)); done
VAULT=$(db_container "$VSERVICE")
[ -n "$VAULT" ] && pass "the vault's stand-in runs ($VAULT)" || { fail "the vault's stand-in did not start"; exit 1; }
# What a data file and load-data would do on db2 (chunk 7's in a game): the
# crontab role with its secret's password, the tables its jobs write, the
# extension pg_cron and a job scheduled for the role. Done now, so that the
# seeded crontab entry and the pg_cron job run on their own schedules while
# the db checks below go on; read back in the v0.4 section.
printf '%s\n' \
    "create role cron_app login password :'pw';" \
    "create table cron_daemon_runs (job text, who text default current_user, at timestamptz default now());" \
    "grant insert on cron_daemon_runs to cron_app;" \
    "create extension pg_cron;" \
    "create table pg_cron_runs (who text default current_user, at timestamptz default now());" \
    "grant insert on pg_cron_runs to cron_app;" \
    "select cron.schedule_in_database('stack-test', '5 seconds', 'insert into pg_cron_runs default values', 'postgres', username => 'cron_app');" \
    | docker exec -i -u postgres "$J" psql -X -q -At -v ON_ERROR_STOP=1 -v pw="$ROLE_PASSWORD" -d postgres >/dev/null 2>"$tmp/db2-setup.err" \
    && pass "db2: role cron_app, its tables, pg_cron and a job for cron_app created as postgres" \
    || fail "db2 setup: $(cat "$tmp/db2-setup.err")"

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
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-db "", /usr/local/sbin/gm-restart-db "", /usr/local/sbin/gm-validate "", /usr/local/sbin/gm-crontab'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the four wrappers, three with no arguments, gm-crontab with its own checks" \
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
m=$(gm stat -c '%a %U:%G' /etc/postgresql /etc/postgresql/postgresql.conf /var/lib/gm-state /var/lib/gm-state/.gm-seeded /home/player /home/player/.pgpass /run/postgresql | tr '\n' ' ')
[ "$m" = "2775 postgres:pgconf 664 postgres:pgconf 755 root:root 444 root:root 750 player:player 600 player:player 2775 postgres:postgres " ] \
    && pass "ownership and modes set by the entrypoint ($m)" || fail "ownership and modes: $m"
out=$(gm_pg /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as postgres green (exit 0)" || fail "GM validator: exit $rc: $out"

# --- seed marker out of the players' reach (release gate RG-1) ----------------
MARKER=/var/lib/gm-state/.gm-seeded
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
marker0=$(gm cat "$MARKER")
check "no marker in the group-writable /etc/postgresql" gm test ! -e /etc/postgresql/.gm-seeded
denied "player cannot remove the marker" rm -f "$MARKER"
denied "player cannot rename the marker" mv -f "$MARKER" "$MARKER.x"
denied "player cannot move the marker to /etc/postgresql" mv -f "$MARKER" /etc/postgresql/x
denied "player cannot overwrite the marker" "echo x > $MARKER"
denied "player cannot create a file next to the marker" touch /var/lib/gm-state/x
denied "dba's COPY TO PROGRAM (as postgres) cannot remove the marker" \
    "psql -X -v ON_ERROR_STOP=1 -c \"copy (select 1) to program 'rm -f $MARKER'\""
check "postgres cannot remove the marker" sh -c "! docker exec -u postgres $C rm -f $MARKER"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "marker unchanged after the attempts" || fail "marker changed or gone"

# --- v0.2: file log on the log volume (master spec 7.5) ------------------------
LOGDIR=/var/log/postgresql
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/log/postgresql"}}{{.Type}} {{.Name}}{{end}}{{end}}' "$C")
[ "$mnt" = "volume ${STACK}_pglog" ] && pass "$LOGDIR is the volume pglog" || fail "$LOGDIR mount: $mnt"
w=$(pssh "psql -XAtc \"select current_setting('logging_collector') || ' ' || current_setting('log_directory') || ' ' || current_setting('log_timezone') || ' ' || current_setting('log_rotation_size') || ' ' || current_setting('log_rotation_age')\"" 2>&1 || true)
[ "$w" = "on $LOGDIR UTC 10MB 0" ] && pass "logging collector on, log_directory, log_timezone UTC, rotated by size ($w)" \
    || fail "logging settings: $w"
LOGFILE=$(gm sh -c "ls -1 $LOGDIR/postgresql-*.log | head -n 1")
first=$(gm head -n 1 "$LOGFILE" 2>&1)
if printf '%s' "$first" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC \[[0-9]+\]: user=[^,]*,db=[^,]*,app=[^,]*,client=[^ ]* '; then
    pass "log file $LOGFILE written in UTC with the pgBadger prefix ($first)"
else
    fail "log file ${LOGFILE:-none}: first line [$first]"
fi
m=$(gm stat -c '%a %U:%G' "$LOGDIR" "$LOGFILE" | tr '\n' ' ')
[ "$m" = "2750 postgres:pgconf 640 postgres:pgconf " ] && pass "log directory and file modes ($m)" || fail "log modes: $m"
w=$(pssh "grep -c 'connection authorized: user=dba' $LOGFILE" 2>&1 || true)
case $w in ''|0|*[!0-9]*) fail "player reads the log file: $w" ;; *) pass "player reads the log file ($w dba connections logged)" ;; esac
denied "player cannot write the log file" "echo x >> $LOGFILE"
denied "player cannot create a file in the log directory" touch "$LOGDIR/x"
n=$(docker service logs --raw "$SERVICE" 2>&1 | grep -c 'connection authorized')
[ "$n" = 0 ] && pass "the server log has left the service logs (no connection line in them)" \
    || fail "service logs still carry $n connection lines"

# --- v0.2: pgBadger run by player, report in its home --------------------------
pssh "psql -XAtc 'select pg_sleep(0.2) as gm_stack_test_slow'" >/dev/null 2>&1
sleep 1
out=$(pssh "pgbadger -q -o ~/pgbadger.html $LOGDIR/postgresql-*.log" 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "pgbadger runs as player, no sudo (exit 0)" || fail "pgbadger: exit $rc: $out"
m=$(gm stat -c '%U %s' /home/player/pgbadger.html 2>&1)
case $m in "player "[1-9]*) pass "HTML report in player's home ($m bytes)" ;; *) fail "report: $m" ;; esac
check "the report holds the slow query (prefix parsed)" gm grep -q gm_stack_test_slow /home/player/pgbadger.html
check "the report is HTML" gm grep -qi '<html' /home/player/pgbadger.html

# --- v0.2: pg_stat_statements ----------------------------------------------------
w=$(pssh "psql -XAtc 'show shared_preload_libraries'" 2>&1 || true)
[ "$w" = pg_stat_statements ] && pass "pg_stat_statements preloaded by the seed" || fail "shared_preload_libraries: $w"
w=$(pssh "psql -XAtc \"select count(*) > 0 from pg_stat_statements where query like '%gm_stack_test_slow%'\"" 2>&1 || true)
[ "$w" = t ] && pass "pg_stat_statements queryable, holds the slow query" || fail "pg_stat_statements: $w"

# --- v0.2: the monitoring role and its secret ----------------------------------
mon_psql() { docker exec -e PGPASSWORD="$1" "$CLIENT" psql -h db -U monitoring -d postgres -XAtc "$2"; }
w=$(mon_psql "$MON_PASSWORD" "select pg_has_role(current_user, 'pg_monitor', 'member') || ' ' || (select rolsuper from pg_roles where rolname = current_user)" 2>&1 || true)
[ "$w" = "true false" ] && pass "monitoring logs in over TCP with the secret's password, holds pg_monitor, not superuser" \
    || fail "monitoring role: $w"
w=$(mon_psql "$MON_PASSWORD" "select count(*) > 0 from pg_stat_statements" 2>&1 || true)
[ "$w" = t ] && pass "monitoring reads pg_stat_statements" || fail "monitoring on pg_stat_statements: $w"
check "monitoring refused with another password" sh -c "! docker exec -e PGPASSWORD=wrong $CLIENT psql -h db -U monitoring -d postgres -XAtc 'select 1'"
m=$(gm stat -c '%a %u:%g' /opt/gm/secrets/monitoring_password)
[ "$m" = "440 0:102" ] && pass "monitoring_password mounted root:postgres 0440" || fail "secret mode: $m"
check "postgres reads the monitoring_password secret" docker exec -u postgres "$C" test -r /opt/gm/secrets/monitoring_password
check "player cannot read the monitoring_password secret file" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@db cat /opt/gm/secrets/monitoring_password"

# --- v0.3: the GM's reserve and the check role (chunk 4a) ------------------------
gm_psql() { docker exec -i "$C" /usr/local/lib/gm/check-psql "$@"; }
pg_q() { docker exec -u postgres "$C" psql -XAtc "$1"; }
app_psql() { docker exec -e PGPASSWORD="$APP_PASSWORD" "$CLIENT" psql -h db -U app -d postgres -XAtc "$1"; }
w=$(pg_q "select setting || ' ' || source from pg_settings where name = 'reserved_connections'" 2>&1)
[ "$w" = "2 command line" ] && pass "reserved_connections 2, set on the server's command line ($w)" \
    || fail "reserved_connections: $w"
w=$(pg_q "select current_setting('max_connections') || ' ' || current_setting('superuser_reserved_connections')" 2>&1)
[ "$w" = "10 3" ] && pass "max_connections 10 (the envelope's minimum), superuser_reserved_connections 3: five ordinary slots" \
    || fail "connection settings: $w"
m=$(gm stat -c '%a %U:%G' /usr/local/lib/gm/check-psql /opt/gm/secrets/gm_check_password | tr '\n' ' ')
[ "$m" = "700 root:root 400 root:root " ] && pass "check-psql and gm_check_password root only ($m)" \
    || fail "check-psql and secret modes: $m"
denied "player cannot run check-psql" /usr/local/lib/gm/check-psql -d postgres -c "'select 1'"
denied "player cannot read the gm_check_password secret file" cat /opt/gm/secrets/gm_check_password
check "postgres cannot run check-psql" sh -c "! docker exec -u postgres $C /usr/local/lib/gm/check-psql -d postgres -c 'select 1'"
w=$(pg_q "select rolcanlogin || ' ' || rolsuper || ' ' || rolcreatedb || ' ' || rolcreaterole || ' ' || rolreplication || ' ' || rolbypassrls from pg_roles where rolname = 'gm_check'" 2>&1)
[ "$w" = "true false false false false false" ] && pass "gm_check: LOGIN, not superuser, no CREATEDB, CREATEROLE, REPLICATION, BYPASSRLS" \
    || fail "gm_check attributes: $w"
GMC_ROLES="select string_agg(g.rolname, ',' order by g.rolname) from pg_auth_members m join pg_roles g on g.oid = m.roleid join pg_roles r on r.oid = m.member where r.rolname = 'gm_check' and m.inherit_option"
w=$(pg_q "$GMC_ROLES" 2>&1)
[ "$w" = "pg_monitor,pg_read_all_data,pg_use_reserved_connections" ] && pass "gm_check inherits pg_monitor, pg_read_all_data, pg_use_reserved_connections" \
    || fail "gm_check memberships: $w"
w=$(gm_psql -d postgres -Atq -v ON_ERROR_STOP=1 <<'SQL' 2>&1
select current_user || ' ' || has_table_privilege('pg_catalog.pg_hba_file_rules', 'select')
       || ' ' || has_function_privilege('pg_catalog.pg_hba_file_rules()', 'execute');
SQL
)
[ "$w" = "gm_check true true" ] && pass "check-psql connects as gm_check; SELECT on pg_hba_file_rules, EXECUTE on its function" \
    || fail "check-psql as gm_check: $w"
gm_psql -d postgres -Atq -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<'SQL'
select no_such_column;
SQL
rc=$?
[ "$rc" -eq 3 ] && pass "check-psql passes psql's status through (script error under ON_ERROR_STOP: 3)" \
    || fail "check-psql status on a script error: $rc"
w=$(gm sh -c 'ls /run/gm | grep -c "^check-psql" || true')
[ "$w" = 0 ] && pass "check-psql leaves no password file in /run/gm" || fail "password files left: $w"

info "taking every ordinary slot with the role app"
pssh "psql -Xqc \"create role app login password '$APP_PASSWORD'\"" >/dev/null 2>&1 || fail "create role app"
docker exec -d -e PGPASSWORD="$APP_PASSWORD" "$CLIENT" sh -c \
    'for i in 1 2 3 4 5; do psql -h db -U app -d postgres -Xqc "select pg_sleep(120)" >/dev/null 2>&1 & done; wait'
n=0; i=0
while [ "$i" -lt 30 ]; do
    n=$(pg_q "select count(*) from pg_stat_activity where usename = 'app'" 2>/dev/null)
    [ "$n" = 5 ] && break
    sleep 1; i=$((i + 1))
done
[ "$n" = 5 ] && pass "five sessions of app hold the five ordinary slots" || fail "app sessions: $n"
w=$(app_psql 'select 1' 2>&1)
case $w in
    *'reserved for roles with privileges of the "pg_use_reserved_connections" role'*)
        pass "a sixth app connection is refused: the rest is reserved" ;;
    *) fail "sixth app connection: $w" ;;
esac
w=$(gm_psql -d postgres -Atq -v ON_ERROR_STOP=1 <<'SQL' 2>&1
select count(*) from pg_hba_file_rules
 where type = 'local' and 'gm_check' = any(user_name) and auth_method = 'scram-sha-256' and error is null;
SQL
)
[ "$w" = 1 ] && pass "with every ordinary slot taken, gm_check connects through check-psql and reads pg_hba_file_rules (its line found)" \
    || fail "gm_check with the slots taken: $w"
docker exec -d "$C" /usr/local/lib/gm/check-psql -d postgres -Xqc 'select pg_sleep(60)'
docker exec -d "$C" /usr/local/lib/gm/check-psql -d postgres -Xqc 'select pg_sleep(60)'
n=0; i=0
while [ "$i" -lt 20 ]; do
    n=$(pg_q "select count(*) from pg_stat_activity where usename = 'gm_check'" 2>/dev/null)
    [ "$n" = 2 ] && break
    sleep 1; i=$((i + 1))
done
[ "$n" = 2 ] && pass "two gm_check sessions at once in the reserve, the ordinary slots taken" || fail "gm_check sessions held: $n"
w=$(gm_psql -d postgres -XAtc 'select 1' 2>&1)
case $w in
    *'reserved for roles with the SUPERUSER attribute'*) pass "a third gm_check session is refused: the reserve is two" ;;
    *) fail "third gm_check session: $w" ;;
esac
w=$(pssh "psql -XAtc 'select current_user'" 2>&1 || true)
[ "$w" = dba ] && pass "dba (superuser) still connects, in the superuser slots" || fail "dba with the reserve taken: $w"
pg_q "select count(pg_terminate_backend(pid)) from pg_stat_activity where usename in ('app', 'gm_check')" >/dev/null 2>&1
sleep 2
w=$(gm sh -c 'ls /run/gm | grep -c "^check-psql" || true')
[ "$w" = 0 ] && pass "check-psql removed its password files when its sessions were ended" || fail "password files left: $w"

# --- v0.3: the PgBouncer lookup role (chunk 4a) ----------------------------------
lookup_psql() { docker exec -e PGPASSWORD="$1" "$CLIENT" psql -h db -U pgbouncer_lookup -d postgres -XAtc "$2"; }
w=$(pg_q "select rolcanlogin || ' ' || rolsuper || ' ' || rolinherit || ' ' || (select count(*) from pg_auth_members where member = r.oid) from pg_roles r where rolname = 'pgbouncer_lookup'" 2>&1)
[ "$w" = "true false false 0" ] && pass "pgbouncer_lookup: LOGIN, not superuser, no membership" || fail "pgbouncer_lookup: $w"
w=$(pg_q "select p.prosecdef || ' ' || pg_get_userbyid(p.proowner) || ' ' || array_to_string(p.proconfig, ';') || ' ' || has_function_privilege('monitoring', p.oid, 'execute') || ' ' || has_function_privilege('pgbouncer_lookup', p.oid, 'execute') || ' ' || has_schema_privilege('monitoring', 'gm_pgbouncer', 'usage') from pg_proc p where p.oid = 'gm_pgbouncer.lookup(text)'::regprocedure" 2>&1)
[ "$w" = "true postgres search_path=pg_catalog, pg_temp false true false" ] \
    && pass "gm_pgbouncer.lookup: SECURITY DEFINER, owned by postgres, fixed search_path, EXECUTE for pgbouncer_lookup only" \
    || fail "lookup function: $w"
w=$(lookup_psql "$LOOKUP_PASSWORD" "select usename || ' ' || left(passwd, 14) from gm_pgbouncer.lookup('dba')" 2>&1)
[ "$w" = 'dba SCRAM-SHA-256$' ] && pass "pgbouncer_lookup logs in with its secret; lookup returns the superuser dba's SCRAM verifier" \
    || fail "lookup of dba: $w"
w=$(lookup_psql "$LOOKUP_PASSWORD" "select usename from gm_pgbouncer.lookup('app')" 2>&1)
[ "$w" = app ] && pass "lookup returns an ordinary login role (app)" || fail "lookup of app: $w"
pg_q "alter role app valid until '2000-01-01'" >/dev/null 2>&1
w=$(lookup_psql "$LOOKUP_PASSWORD" "select count(*) from gm_pgbouncer.lookup('app')" 2>&1)
[ "$w" = 0 ] && pass "lookup leaves out a role whose password has expired" || fail "lookup of an expired role: $w"
pg_q "alter role app valid until 'infinity'" >/dev/null 2>&1
w=$(lookup_psql "$LOOKUP_PASSWORD" "select count(*) from gm_pgbouncer.lookup('no_such_role')" 2>&1)
[ "$w" = 0 ] && pass "lookup of an unknown role returns no row" || fail "lookup of an unknown role: $w"
w=$(lookup_psql "$LOOKUP_PASSWORD" "select count(*) from pg_authid" 2>&1)
case $w in *"permission denied"*) pass "pgbouncer_lookup cannot read pg_authid itself" ;; *) fail "pgbouncer_lookup on pg_authid: $w" ;; esac
w=$(mon_psql "$MON_PASSWORD" "select * from gm_pgbouncer.lookup('dba')" 2>&1)
case $w in *"permission denied"*) pass "another role (monitoring) cannot call the lookup" ;; *) fail "monitoring calling lookup: $w" ;; esac
denied "player cannot read the pgbouncer_lookup_password secret file" cat /opt/gm/secrets/pgbouncer_lookup_password
# Read back after the restart path below: ALTER SYSTEM cannot lower the reserve.
pssh "psql -Xqc 'alter system set reserved_connections = 0'" >/dev/null 2>&1 || fail "alter system reserved_connections"

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
CONF=/etc/postgresql/postgresql.conf
HBA=/etc/postgresql/pg_hba.conf
owner() { gm stat -c '%U:%G %a' "$@" | tr '\n' ' '; }
m=$(owner "$CONF")
[ "$m" = "player:pgconf 664 " ] && pass "sed -i by player leaves postgresql.conf owned by player ($m)" || fail "after sed -i: $m"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true
m=$(owner "$CONF")
[ "$m" = "postgres:pgconf 664 " ] && pass "gm-reload-db gives postgresql.conf its seeded owner and mode back ($m)" \
    || fail "owner after gm-reload-db: $m"
# A symlink in place of a seeded file: root's chown and chmod never follow it.
s0=$(gm stat -c '%a %U:%G' /run/gm/sudo.log)
pssh "cp $HBA ~/hba.keep && ln -sf /run/gm/sudo.log $HBA" || fail "player replaces pg_hba.conf with a symlink"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true
s1=$(gm stat -c '%a %U:%G' /run/gm/sudo.log)
[ "$s1" = "$s0" ] && [ "$(gm stat -c %F "$HBA")" = "symbolic link" ] \
    && pass "gm-reload-db does not follow a symlinked seeded file (its target stays $s1)" \
    || fail "symlinked seeded file: target $s0 -> $s1"
pssh "rm -f $HBA && cp ~/hba.keep $HBA && rm -f ~/hba.keep" || fail "player puts pg_hba.conf back"
pssh sudo -n gm-reload-db >/dev/null 2>&1 || true
m=$(owner "$HBA")
[ "$m" = "postgres:pgconf 664 " ] && pass "a seeded file a player recreated gets its seeded owner back ($m)" \
    || fail "pg_hba.conf owner after recreation and reload: $m"
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
w=$(pg_q "select setting || ' ' || source from pg_settings where name = 'reserved_connections'" 2>&1)
[ "$w" = "2 command line" ] && pass "after a restart, ALTER SYSTEM reserved_connections = 0 has not lowered the reserve ($w)" \
    || fail "reserved_connections after ALTER SYSTEM and a restart: $w"
pssh "psql -Xqc 'alter system reset reserved_connections'" >/dev/null 2>&1

# --- gm-restart-db refuses a configuration that does not load ---------------------
pssh "echo 'shared_buffers = banana' >> /etc/postgresql/postgresql.conf"
out=$(pssh sudo -n gm-restart-db 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT restarted' && gm pg_isready -q -h /run/postgresql; then
    pass "gm-restart-db refuses a broken postgresql.conf, server left running"
else
    fail "broken config restart: exit $rc: $out"
fi
pssh "sed -i -e '/^shared_buffers = banana/d' -e 's/^max_connections = .*/max_connections = 5/' /etc/postgresql/postgresql.conf"
out=$(pssh sudo -n gm-restart-db 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'max_connections (5) must be more than superuser_reserved_connections (3) plus' \
   && gm pg_isready -q -h /run/postgresql; then
    pass "gm-restart-db refuses max_connections 5 (no room left beside the reserves), server left running"
else
    fail "max_connections 5 restart: exit $rc: $out"
fi
pssh "sed -i -e 's/^max_connections = .*/max_connections = 50/' /etc/postgresql/postgresql.conf"
m=$(owner "$CONF")
[ "$m" = "player:pgconf 664 " ] || fail "precondition, postgresql.conf owned by player before gm-restart-db: $m"
pssh sudo -n gm-restart-db >/dev/null 2>&1 || fail "restart back to the in-envelope configuration"
m=$(owner "$CONF")
[ "$m" = "postgres:pgconf 664 " ] && pass "gm-restart-db gives postgresql.conf its seeded owner and mode back ($m)" \
    || fail "owner after gm-restart-db: $m"
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
# dba breaks the GM's roles; a new container's start puts them back.
pssh "psql -Xqc \"alter role gm_check nologin password 'x'; revoke pg_monitor from gm_check; alter role pgbouncer_lookup password 'y'\"" >/dev/null 2>&1 \
    || fail "dba alters the GM's roles"
w=$(gm_psql -d postgres -XAtc 'select 1' 2>&1)
case $w in *'password authentication failed for user "gm_check"'*|*"not permitted to log in"*) w=locked-out ;; esac
v=$(pg_q "$GMC_ROLES" 2>&1)
[ "$w" = locked-out ] && [ "$v" = "pg_read_all_data,pg_use_reserved_connections" ] \
    && pass "dba locked gm_check out (NOLOGIN, another password) and took pg_monitor away" || fail "dba's changes to gm_check: [$w] [$v]"
pssh "echo 'audit notes' > ~/report.md" && pass "player's home is writable (~/report.md)" || fail "home not writable"
pssh "sed -i 's/^port = 5432$/port = 5432/' $CONF" || fail "sed -i before the new container"
m=$(owner "$CONF")
[ "$m" = "player:pgconf 664 " ] || fail "precondition, postgresql.conf owned by player before the new container: $m"
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
m=$(owner "$CONF" /etc/postgresql)
[ "$m" = "postgres:pgconf 664 postgres:pgconf 2775 " ] && pass "a new container's start gives the seeded files their owner and mode back ($m)" \
    || fail "owner after a new container: $m"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
w=$(pssh "psql -XAtc 'select i from stack_test'" 2>&1 || true)
[ "$w" = 42 ] && pass "data kept in a new container" || fail "data after new container: $w"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green in the new container" || fail "validator in new container: exit $rc: $out"
check "log file kept in a new container (volume pglog)" gm test -s "$LOGFILE"
w=$(mon_psql "$MON_PASSWORD" "select 1" 2>&1 || true)
[ "$w" = 1 ] && pass "monitoring role kept in a new container" || fail "monitoring after new container: $w"
check "the new container's start updated the GM's roles" sh -c "docker logs $C 2>&1 | grep -q 'GM roles up to date: gm_check pgbouncer_lookup'"
w=$(gm_psql -d postgres -XAtc 'select current_user' 2>&1)
[ "$w" = gm_check ] && pass "gm_check logs in again in the new container (LOGIN and password restored)" || fail "gm_check after new container: $w"
w=$(pg_q "$GMC_ROLES" 2>&1)
[ "$w" = "pg_monitor,pg_read_all_data,pg_use_reserved_connections" ] && pass "gm_check's memberships restored in the new container" \
    || fail "gm_check memberships after new container: $w"
w=$(lookup_psql "$LOOKUP_PASSWORD" "select usename from gm_pgbouncer.lookup('dba')" 2>&1)
[ "$w" = dba ] && pass "pgbouncer_lookup's password restored in the new container" || fail "lookup after new container: $w"

# --- v0.3: the hand-over snapshot of pgdata (chunk 4b) ------------------------------
m=$(gm stat -c '%a %U:%G' /usr/local/sbin/gm-snapshot-db)
[ "$m" = "700 root:root" ] && pass "gm-snapshot-db root only ($m)" || fail "gm-snapshot-db mode: $m"
denied "player cannot run gm-snapshot-db" /usr/local/sbin/gm-snapshot-db
denied "player cannot sudo gm-snapshot-db" sudo -n /usr/local/sbin/gm-snapshot-db
pssh "psql -Xqc 'create table snap_test(i int); insert into snap_test values (7)'" || fail "create snap_test"
docker exec "$C" /usr/local/sbin/gm-snapshot-db > "$tmp/pgdata.tar" 2> "$tmp/snapshot.err"; rc=$?
[ "$rc" -eq 0 ] && pass "gm-snapshot-db exit 0, $(wc -c < "$tmp/pgdata.tar") bytes on standard output" \
    || fail "gm-snapshot-db: exit $rc: $(cat "$tmp/snapshot.err")"
grep -q 'temporary replication slot gm_snapshot reserving WAL from ' "$tmp/snapshot.err" \
    && pass "the snapshot reserved WAL with a temporary slot ($(grep -o 'from .*' "$tmp/snapshot.err"))" \
    || fail "no slot line: $(cat "$tmp/snapshot.err")"
list=$(tar -tf "$tmp/pgdata.tar" 2>&1)
if printf '%s\n' "$list" | grep -qx 'PG_VERSION' && printf '%s\n' "$list" | grep -qx 'backup_label' \
   && printf '%s\n' "$list" | grep -Eq '^pg_wal/[0-9A-F]{24}$' && ! printf '%s\n' "$list" | grep -q '^\.\./\|^/'; then
    pass "the tar is rooted at the data directory and holds backup_label and its WAL ($(printf '%s\n' "$list" | grep -Ec '^pg_wal/[0-9A-F]{24}$') segment(s))"
else
    fail "tar contents: $(printf '%s\n' "$list" | head -n 5)"
fi
w=$(pg_q "select count(*) from pg_replication_slots" 2>&1)
[ "$w" = 0 ] && pass "no replication slot left after the snapshot" || fail "slots after the snapshot: $w"
out=$(docker exec "$C" sh -c '{ /usr/local/sbin/gm-snapshot-db; echo "status=$?" >&2; } | head -c 65536 >/dev/null' 2>&1)
st=$(printf '%s\n' "$out" | grep -o '^status=[0-9]*$')
case $st in
    status=0|'') fail "a snapshot cut short did not fail: $out" ;;
    *) pass "a snapshot whose reader stops early fails ($st: $(printf '%s\n' "$out" | grep 'gm-snapshot-db: pg_basebackup' | head -n 1))" ;;
esac
i=0
while [ "$i" -lt 10 ] && [ "$(pg_q "select count(*) from pg_replication_slots" 2>/dev/null)" != 0 ]; do sleep 1; i=$((i + 1)); done
w=$(pg_q "select count(*) from pg_replication_slots" 2>&1)
[ "$w" = 0 ] && pass "the slot is dropped after a failed snapshot too" || fail "slots after a failed snapshot: $w"
w=$(gm sh -c 'ls /run/gm | grep -c "^snapshot-db" || true')
[ "$w" = 0 ] && pass "gm-snapshot-db leaves nothing in /run/gm" || fail "work directories left: $w"
# SIGKILL of the helper mid-backup (its reader stalled, so the backup is in
# flight): the holding session sees its FIFO close and the slot goes.
docker exec -d "$C" sh -c '/usr/local/sbin/gm-snapshot-db 2>/dev/null | { sleep 15; cat >/dev/null; }'
n=0; i=0
while [ "$i" -lt 20 ]; do
    n=$(pg_q "select count(*) from pg_replication_slots where slot_name = 'gm_snapshot' and temporary" 2>/dev/null)
    [ "$n" = 1 ] && break
    sleep 1; i=$((i + 1))
done
[ "$n" = 1 ] && pass "the temporary slot gm_snapshot exists while a backup runs" || fail "slot during a backup: $n"
gm pkill -KILL -f '^/bin/sh /usr/local/sbin/gm-snapshot-db' || fail "kill -9 of gm-snapshot-db"
i=0
while [ "$i" -lt 10 ] && [ "$(pg_q "select count(*) from pg_replication_slots" 2>/dev/null)" != 0 ]; do sleep 1; i=$((i + 1)); done
w=$(pg_q "select count(*) from pg_replication_slots" 2>&1)
[ "$w" = 0 ] && pass "the slot is dropped when gm-snapshot-db is killed with SIGKILL (in ${i}s)" || fail "slots after a SIGKILL: $w"
i=0
while [ "$i" -lt 40 ] && gm pgrep -f pg_basebackup >/dev/null 2>&1; do sleep 1; i=$((i + 1)); done
gm sh -c 'rm -rf /run/gm/snapshot-db.*'    # a SIGKILL leaves its work directory

info "restoring the snapshot into a fresh container (stack $RSTACK)"
for v in pgconf home gmstate pglog cronspool; do
    case $v in
        pgconf) path=/etc/postgresql ;; home) path=/home/player ;;
        gmstate) path=/var/lib/gm-state ;; pglog) path=/var/log/postgresql ;;
        cronspool) path=/var/spool/cron/crontabs ;;
    esac
    docker exec "$C" tar --create --file=- --numeric-owner --directory="$path" . > "$tmp/$v.tar"; rc=$?
    [ "$rc" -le 1 ] || fail "copy of $v: exit $rc"
done
for v in pgdata pgconf home gmstate pglog cronspool; do
    docker volume create --label "$LABEL" "${RSTACK}_$v" >/dev/null
    docker run --rm -i --network none -v "${RSTACK}_$v:/v" --entrypoint tar "$IMAGE" \
        --extract --file=- --numeric-owner --same-permissions --directory=/v < "$tmp/$v.tar" \
        || fail "extract $v into ${RSTACK}_$v"
done
DB2_REPLICAS=0 V05_REPLICAS=0 docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$RSTACK" >/dev/null 2>&1
if R=$(wait_healthy "" "$RSERVICE"); then
    pass "a fresh container on the restored volumes is healthy ($R)"
    rq() { docker exec -u postgres "$R" psql -XAtc "$1"; }
    w=$(rq "select i from snap_test" 2>&1)
    [ "$w" = 7 ] && pass "the restored cluster holds the data written before the snapshot" || fail "restored data: $w"
    w=$(rq "select count(*) from pg_replication_slots" 2>&1)
    [ "$w" = 0 ] && pass "the restored cluster has no replication slot" || fail "restored slots: $w"
    check "the restored cluster finished its recovery (no backup_label left)" docker exec "$R" test ! -e /var/lib/postgresql/18/data/backup_label
    w=$(docker exec -i "$R" /usr/local/lib/gm/check-psql -d postgres -XAtc 'select current_user' 2>&1)
    [ "$w" = gm_check ] && pass "gm_check connects through check-psql in the restored cluster" || fail "gm_check restored: $w"
    w=$(docker exec "$R" grep -c '^work_mem = 8MB   # stack test edit' /etc/postgresql/postgresql.conf 2>&1)
    [ "$w" = 1 ] && pass "the restored configuration is the copied one, not re-seeded" || fail "restored configuration: $w"
else
    fail "a fresh container on the restored volumes did not become healthy"
    docker service logs --tail 40 "$RSERVICE" 2>&1 || true
fi
docker stack rm "$RSTACK" >/dev/null 2>&1

# --- v0.4: the cron daemon on a node seeding no crontab (chunk 4a) --------------------
SPOOL=/var/spool/cron/crontabs
w=$(gm /command/s6-svstat -o up,wantedup /run/service/cron 2>&1)
[ "$w" = "false false" ] && pass "db, seeding no crontab: the service cron is down and not wanted up ($w)" \
    || fail "service cron on db: $w"
check "db: no cron process" sh -c "! docker exec $C pgrep -x cron"
n=$(docker logs "$C" 2>&1 | grep -c 'cron: this node seeds no crontab; the cron daemon does not run')
[ "$n" = 1 ] && pass "db: the service said once why it does not run (not restarted)" || fail "db: cron's line $n times"
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/spool/cron/crontabs"}}{{.Type}} {{.Name}}{{end}}{{end}}' "$C")
[ "$mnt" = "volume ${STACK}_cronspool" ] && pass "$SPOOL is the volume cronspool" || fail "$SPOOL mount: $mnt"
m=$(gm stat -c '%a %U:%G' "$SPOOL" "$LOGDIR/cron" | tr '\n' ' ')
[ "$m" = "1730 root:crontab 2750 postgres:pgconf " ] && pass "db: the spool and the cron log directory as set at start ($m)" \
    || fail "db: spool and cron log modes: $m"
check "db: no crontab installed" gm test ! -e "$SPOOL/postgres"
check "db: no password file (no crontab role)" gm test ! -e /run/gm-cron
w=$(pssh sudo -n gm-crontab -l 2>&1); rc=$?
[ "$rc" -eq 1 ] && [ "$w" = "no crontab for postgres" ] && pass "db: gm-crontab -l lists nothing (exit 1: $w)" \
    || fail "db: gm-crontab -l: exit $rc: $w"
pssh "printf '* * * * * true\\n' > ~/x.cron" || fail "db: player writes ~/x.cron"
w=$(pssh sudo -n gm-crontab x.cron 2>&1); rc=$?
case $rc:$w in
    1:*"runs no cron daemon"*) pass "db: gm-crontab refuses to install a crontab nothing would run (exit 1)" ;;
    *) fail "db: gm-crontab <file>: exit $rc: $w" ;;
esac
check "db: still no crontab" gm test ! -e "$SPOOL/postgres"
w=$(gm_pg psql -XAtc "select count(*) from pg_stat_activity where backend_type = 'pg_cron launcher'" 2>&1)
[ "$w" = 0 ] && pass "db: no pg_cron launcher (the seed does not preload it)" || fail "db: pg_cron launcher: $w"

# --- v0.4: the node with jobs, db2 (chunk 4a) --------------------------------------------
pssh2() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@db2 "$@"; }
j() { docker exec -i "$J" "$@"; }
jsql() { docker exec -u postgres "$J" psql -XAtc "$1"; }
denied2() {  # denied2 <description> <remote command>: pass if player's command fails on db2
    d=$1; shift
    if pssh2 "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
# wait_rows <seconds> <query>: wait for the query (as postgres on db2) to count more than 0
wait_rows() {
    i=0
    while [ "$i" -lt "$1" ]; do
        n=$(jsql "$2" 2>/dev/null)
        case $n in ''|0|*[!0-9]*) ;; *) echo "$n"; return 0 ;; esac
        sleep 3; i=$((i + 3))
    done
    echo "${n:-none}"
    return 1
}
w=$(j /command/s6-svstat -o up,wantedup /run/service/cron 2>&1)
[ "$w" = "true true" ] && pass "db2, seeding a crontab: the service cron is up ($w)" || fail "service cron on db2: $w"
cpid=$(j pgrep -x cron 2>&1)
w=$(j ps -o user=,args= -p "$cpid" 2>&1 | tr -s ' ')
[ "$w" = "root /usr/sbin/cron -f" ] && pass "db2: the daemon runs as root, in the foreground ($w)" || fail "db2: cron process: [$cpid] $w"
w=$(j /command/s6-rc-db -l /run/s6-rc dependencies cron 2>&1 | sort | tr '\n' ' ')
case " $w" in *" postgres "*) pass "db2: the service cron depends on postgres: started after it, stopped before it ($w)" ;;
    *) fail "db2: cron's dependencies: $w" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/spool/cron/crontabs"}}{{.Type}} {{.Name}}{{end}}{{end}}' "$J")
[ "$mnt" = "volume ${STACK}_cronspool2" ] && pass "db2: $SPOOL is its volume cronspool" || fail "db2: $SPOOL mount: $mnt"
m=$(j stat -c '%a %U:%G' "$SPOOL" "$SPOOL/postgres" /run/gm-cron /run/gm-cron/pgpass "$LOGDIR/cron" | tr '\n' ' ')
[ "$m" = "1730 root:crontab 600 postgres:crontab 700 postgres:postgres 600 postgres:postgres 2750 postgres:pgconf " ] \
    && pass "db2: spool, crontab, password file and cron log directory owners and modes ($m)" || fail "db2: modes: $m"
check "db2: the crontab is the seed's, below crontab's header" j sh -c "tail -n +4 $SPOOL/postgres | cmp -s - /opt/gm/seed/crontab"
check "db2: the start-up logged the seeding" sh -c "docker logs $J 2>&1 | grep -q \"seeded postgres's crontab $SPOOL/postgres from /opt/gm/seed/crontab\""
exp="*:*:*:cron_app:$(printf '%s' "$ROLE_PASSWORD" | sed 's/[\\:]/\\&/g')"
[ "$(j cat /run/gm-cron/pgpass)" = "$exp" ] && pass "db2: the password file holds one line for cron_app, : and \\ escaped" \
    || fail "db2: password file content"
check "db2: postgres reads the password file" docker exec -u postgres "$J" test -r /run/gm-cron/pgpass
denied2 "db2: player cannot read the password file" cat /run/gm-cron/pgpass
denied2 "db2: player cannot read the role's secret" cat /opt/gm/secrets/role_cron_app_password
denied2 "db2: player cannot read the crontab in the spool" cat "$SPOOL/postgres"
denied2 "db2: player cannot write the spool" touch "$SPOOL/x"

info "waiting for the seeded crontab entry's run (every minute)"
n=$(wait_rows 100 "select count(*) from cron_daemon_runs where job = 'seeded' and who = 'cron_app'")
[ $? -eq 0 ] && pass "db2: the seeded entry ran, connecting as the customer role cron_app through PGPASSFILE ($n runs)" \
    || fail "db2: no run of the seeded entry as cron_app ($n)"
CRONLOG=$LOGDIR/cron/stack-test.log
m=$(j stat -c '%a %U:%G' "$CRONLOG" 2>&1)
[ "$m" = "644 postgres:pgconf" ] && pass "db2: the entry appends to its log $CRONLOG, 0644, group pgconf ($m)" || fail "db2: job log: $m"
w=$(pssh2 "grep -c '^INSERT 0 1' $CRONLOG" 2>&1)
case $w in ''|0|*[!0-9]*) fail "db2: player reads the job's log: $w" ;; *) pass "db2: player reads the job's log ($w INSERT lines)" ;; esac
denied2 "db2: player cannot write the job's log" "echo x >> $CRONLOG"
denied2 "db2: player cannot create a file in the cron log directory" touch "$LOGDIR/cron/x"

w=$(jsql 'show shared_preload_libraries' 2>&1)
[ "$w" = "pg_stat_statements,pg_cron" ] && pass "db2: pg_cron preloaded by the seed ($w)" || fail "db2: shared_preload_libraries: $w"
w=$(jsql "select extversion from pg_extension where extname = 'pg_cron'" 2>&1)
[ "$w" = 1.6 ] && pass "db2: the extension pg_cron $w in cron.database_name (postgres)" || fail "db2: pg_cron extension: $w"
w=$(jsql "select count(*) from pg_stat_activity where backend_type = 'pg_cron launcher'" 2>&1)
[ "$w" = 1 ] && pass "db2: one pg_cron launcher" || fail "db2: pg_cron launcher: $w"
n=$(wait_rows 60 "select count(*) from cron.job_run_details d join cron.job j using (jobid) where j.jobname = 'stack-test' and j.username = 'cron_app' and d.username = 'cron_app' and d.status = 'succeeded'")
[ $? -eq 0 ] && pass "db2: the pg_cron job scheduled with username => 'cron_app' fills cron.job_run_details ($n succeeded runs)" \
    || fail "db2: pg_cron job runs: $n"
w=$(jsql "select count(*) || ' ' || count(*) filter (where who <> 'cron_app') from pg_cron_runs" 2>&1)
case $w in "0 "*|*" "[1-9]*|'') fail "db2: pg_cron job's rows: $w" ;; *) pass "db2: the pg_cron job runs as cron_app (rows, none by another role: $w)" ;; esac

# gm-crontab on the node with jobs.
w=$(pssh2 sudo -n gm-crontab -l 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$w" = "$(cat "$HERE/fixtures/crontab")" ] && pass "db2: sudo gm-crontab -l lists the seeded crontab" \
    || fail "db2: gm-crontab -l: exit $rc: $w"
for a in "" "-l extra" "-e" "-r" "-u player -l" "-"; do
    out=$(pssh2 sudo -n gm-crontab $a 2>&1); rc=$?
    case $rc:$out in 2:*"usage: sudo gm-crontab -l | sudo gm-crontab <file>"*) pass "db2: gm-crontab refuses [$a] (exit 2)" ;;
        *) fail "db2: gm-crontab [$a]: exit $rc: $out" ;; esac
done
out=$(pssh2 sudo -n gm-crontab /opt/gm/secrets/dba_password 2>&1); rc=$?
case $rc:$out in
    1:*"cannot read /opt/gm/secrets/dba_password as player"*)
        if printf '%s' "$out" | grep -qF "$DBA_PASSWORD"; then fail "db2: gm-crontab showed a root-only file"
        else pass "db2: gm-crontab reads its file as player: a root-only file is refused, nothing of it shown (exit 1)"; fi ;;
    *) fail "db2: gm-crontab on a root-only file: exit $rc: $out" ;;
esac
pssh2 "printf 'not a crontab line\\n' > ~/bad.cron" || fail "db2: player writes ~/bad.cron"
out=$(pssh2 sudo -n gm-crontab bad.cron 2>&1); rc=$?
case $rc:$out in 1:*"crontab refused bad.cron; the crontab is unchanged"*) pass "db2: gm-crontab refuses a file crontab rejects (exit 1)" ;;
    *) fail "db2: gm-crontab on a bad file: exit $rc: $out" ;; esac
check "db2: the crontab is still the seed's after the refusals" j sh -c "tail -n +4 $SPOOL/postgres | cmp -s - /opt/gm/seed/crontab"
cat > "$tmp/new.cron" <<'CRON'
# replaced by the stack test, through sudo gm-crontab
PGPASSFILE=/run/gm-cron/pgpass
* * * * * psql -X -w -h /run/postgresql -U cron_app -d postgres -c "insert into cron_daemon_runs (job) values ('replaced')" >> /var/log/postgresql/cron/replaced.log 2>&1
CRON
docker exec -i -u player "$J" sh -c 'cat > /home/player/new.cron' < "$tmp/new.cron" || fail "db2: player writes ~/new.cron"
out=$(pssh2 sudo -n gm-crontab new.cron 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "db2: sudo gm-crontab new.cron installs a replacement (exit 0: $out)" || fail "db2: gm-crontab new.cron: exit $rc: $out"
w=$(pssh2 sudo -n gm-crontab -l 2>&1)
[ "$w" = "$(cat "$tmp/new.cron")" ] && pass "db2: gm-crontab -l lists the replacement" || fail "db2: crontab after the replacement: $w"
m=$(j stat -c '%a %U:%G' "$SPOOL/postgres")
[ "$m" = "600 postgres:crontab" ] && pass "db2: the replacement is postgres's, 0600, in the spool ($m)" || fail "db2: replacement's mode: $m"
check "sudo logs gm-crontab to /run/gm/sudo.log" docker exec "$J" grep -q 'COMMAND=/usr/local/sbin/gm-crontab new.cron' /run/gm/sudo.log
w=$(j sh -c 'ls /run/gm | grep -c "^gm-crontab" || true')
[ "$w" = 0 ] && pass "gm-crontab leaves no work file in /run/gm" || fail "gm-crontab work files left: $w"
info "waiting for the replacement's run"
n=$(wait_rows 100 "select count(*) from cron_daemon_runs where job = 'replaced' and who = 'cron_app'")
[ $? -eq 0 ] && pass "db2: cron runs the replacement within the minute or so, as cron_app ($n runs)" || fail "db2: replacement not run ($n)"

# Shutdown order: s6-rc stops cron before postgres, as the container's stop does.
j /command/s6-rc -d change postgres >/dev/null 2>&1 || fail "db2: s6-rc -d change postgres"
c_dn=$(j /command/s6-svstat -o up,updownsince /run/service/cron 2>&1)
p_dn=$(j /command/s6-svstat -o up,updownsince /run/service/postgres 2>&1)
case $c_dn:$p_dn in
    false\ *:false\ *)
        if [ "$(printf '%s\n%s\n' "${c_dn#* }" "${p_dn#* }" | sort | head -n 1)" = "${c_dn#* }" ]; then
            pass "db2: bringing postgres down stops cron first ($c_dn, then postgres $p_dn)"
        else
            fail "db2: postgres went down before cron ($c_dn, $p_dn)"
        fi ;;
    *) fail "db2: down states: cron $c_dn, postgres $p_dn" ;;
esac
j /command/s6-rc -u change user >/dev/null 2>&1 || fail "db2: s6-rc -u change user"
i=0
while [ "$i" -lt 30 ] && ! j pg_isready -q -h /run/postgresql; do sleep 1; i=$((i + 1)); done
w=$(j /command/s6-svstat -o up /run/service/cron)$(j /command/s6-svstat -o up /run/service/postgres)
[ "$w" = truetrue ] && pass "db2: both back up" || fail "db2: after s6-rc -u: $w"

info "forcing a new container for db2"
docker service update --force --detach "$SERVICE2" >/dev/null 2>&1
if J2=$(wait_healthy "$J" "$SERVICE2"); then
    pass "db2: new container healthy ($J2)"
    J=$J2
else
    fail "db2: new container did not become healthy"
fi
tnew=$(jsql "select pg_postmaster_start_time()")
w=$(pssh2 sudo -n gm-crontab -l 2>&1)
[ "$w" = "$(cat "$tmp/new.cron")" ] && pass "db2: the player's replacement survives a new container (not re-seeded)" \
    || fail "db2: crontab after a new container: $w"
m=$(j stat -c '%a %U:%G' "$SPOOL" "$SPOOL/postgres" /run/gm-cron/pgpass | tr '\n' ' ')
[ "$m" = "1730 root:crontab 600 postgres:crontab 600 postgres:postgres " ] \
    && pass "db2: spool, crontab and a rewritten password file in the new container ($m)" || fail "db2: modes after a new container: $m"
w=$(j /command/s6-svstat -o up /run/service/cron 2>&1)
[ "$w" = true ] && pass "db2: cron up in the new container" || fail "db2: cron in the new container: $w"
n=$(wait_rows 100 "select count(*) from cron_daemon_runs where job = 'replaced' and at > '$tnew'")
[ $? -eq 0 ] && pass "db2: the replacement runs in the new container ($n runs since)" || fail "db2: no run in the new container ($n)"
: | docker exec -i -u player "$J" sh -c 'cat > /home/player/empty.cron'
out=$(pssh2 sudo -n gm-crontab empty.cron 2>&1); rc=$?
[ "$rc" -eq 0 ] || fail "db2: gm-crontab empty.cron: exit $rc: $out"
j /command/s6-svc -r /run/service/cron
sleep 3
w=$(j /command/s6-svstat -o up,wantedup /run/service/cron 2>&1)
[ "$w" = "true true" ] && j pgrep -x cron >/dev/null \
    && pass "db2: an empty player crontab leaves the daemon running, across a restart of the service ($w)" \
    || fail "db2: cron with an empty crontab: $w"

# --- v0.4: the out-of-memory victim (chunk 4b) -------------------------------------------
for node in db db2; do
    if [ "$node" = db ]; then n_c=$C; else n_c=$J; fi
    w=$(docker exec -u postgres "$n_c" psql -XAtc "select trim(pg_read_file('/proc/self/oom_score_adj'))" 2>&1)
    [ "$w" = 300 ] && pass "$node: a backend runs at oom_score_adj +300 (read from the backend itself)" || fail "$node: backend's oom_score_adj: $w"
    ppid=$(docker exec "$n_c" head -n 1 /var/lib/postgresql/18/data/postmaster.pid 2>&1)
    # /proc/<pid>/environ is its owner's: read as postgres (root has no CAP_SYS_PTRACE)
    w=$(docker exec -u postgres "$n_c" sh -c "tr '\\0' '\\n' < /proc/$ppid/environ | grep '^PG_OOM_ADJUST_' | sort | tr '\\n' ' '" 2>&1)
    [ "$w" = "PG_OOM_ADJUST_FILE=/proc/self/oom_score_adj PG_OOM_ADJUST_VALUE=300 " ] \
        && pass "$node: the run script gives the postmaster PG_OOM_ADJUST_FILE and PG_OOM_ADJUST_VALUE=300" \
        || fail "$node: the postmaster's environment: $w"
    # A short-lived child can exit between pgrep and the read: a child gone
    # before its read is skipped; none read at all still fails (empty list).
    w=$(docker exec "$n_c" sh -c "for p in \$(pgrep -P $ppid); do cat /proc/\$p/oom_score_adj 2>/dev/null; done | sort -u | tr '\\n' ' '" 2>&1)
    [ "$w" = "300 " ] && pass "$node: every child of the postmaster at +300 (backends and background processes)" \
        || fail "$node: the postmaster's children: $w"
    # Same race (an sshd session or a cron job's fork): a process gone before
    # its read is skipped; the postmaster, s6 and sshd must still be listed.
    w=$(docker exec "$n_c" sh -c "adj() { v=\$(cat /proc/\$2/oom_score_adj 2>/dev/null) && printf '%s=%s ' \$1 \"\$v\"; }
        adj postmaster $ppid
        for p in \$(pgrep -x 's6-svscan|s6-supervise'); do adj s6 \$p; done
        for p in \$(pgrep -x sshd); do adj sshd \$p; done
        for p in \$(pgrep -x cron); do adj cron \$p; done" 2>&1)
    case " $w" in
        *=[!0]*|*=0[0-9]*) fail "$node: a process outside PostgreSQL's children not at 0: $w" ;;
        *" postmaster=0 "*" s6=0 "*" sshd=0 "*) pass "$node: the postmaster, s6, sshd and cron (where it runs) at 0 ($w)" ;;
        *) fail "$node: oom_score_adj outside PostgreSQL's children: $w" ;;
    esac
done
case $(j sh -c 'for p in $(pgrep -x cron); do cat /proc/$p/oom_score_adj 2>/dev/null; done | sort -u') in
    0) pass "db2: the cron daemon at 0" ;; *) fail "db2: cron's oom_score_adj" ;;
esac

# --- v0.4: check-psql reaching another database node (chunk 4b) ---------------------------
OTHER="select current_user || ' ' || (inet_client_addr() is not null) || ' ' || coalesce(current_setting('cron.database_name', true), '-')"
w=$(gm_psql --node db2 -d postgres -XAtc "$OTHER" 2>&1)
[ "$w" = "gm_check true postgres" ] && pass "check-psql --node db2 from db: gm_check over the game network, on db2's instance ($w)" \
    || fail "check-psql --node db2: $w"
w=$(docker exec -i "$J" /usr/local/lib/gm/check-psql --node db -d postgres -XAtc "$OTHER" 2>&1)
[ "$w" = "gm_check true -" ] && pass "check-psql --node db from db2: gm_check on db's instance ($w)" || fail "check-psql --node db: $w"
w=$(gm_psql --node db2 -d postgres -Atq -v ON_ERROR_STOP=1 <<'SQL' 2>&1
select count(*) from pg_hba_file_rules where type = 'host' and 'gm_check' = any(user_name) and address = 'samenet';
SQL
)
[ "$w" = 1 ] && pass "check-psql --node db2 reads db2's pg_hba_file_rules (its samenet line for gm_check)" || fail "db2's gm_check line: $w"
w=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql -h db2 -U dba -d postgres -XAtc 'select 1' 2>&1)
case $w in *"no pg_hba.conf entry"*) pass "db2 admits only gm_check from the network: dba refused there" ;; *) fail "dba over TCP on db2: $w" ;; esac
gm_psql --node db2 -d postgres -Atq -v ON_ERROR_STOP=1 >/dev/null 2>&1 <<'SQL'
select no_such_column;
SQL
rc=$?
[ "$rc" -eq 3 ] && pass "check-psql --node passes psql's status through (3)" || fail "check-psql --node status on a script error: $rc"
for a in "--node" "--node Db2" "--node db2;x" "--node -h"; do
    out=$(gm_psql $a -d postgres -XAtc 'select 1' 2>&1); rc=$?
    case $rc:$out in 2:check-psql:*) pass "check-psql refuses [$a] (exit 2: $out)" ;; *) fail "check-psql [$a]: exit $rc: $out" ;; esac
done
t0=$(date +%s)
out=$(gm_psql --node no-such-node -d postgres -XAtc 'select 1' 2>&1); rc=$?
t1=$(date +%s)
[ "$rc" -eq 2 ] && [ $((t1 - t0)) -le 15 ] && pass "check-psql --node on an unknown node: exit 2 within $((t1 - t0)) s" \
    || fail "check-psql --node no-such-node: exit $rc after $((t1 - t0)) s: $out"
w=$(gm sh -c 'ls /run/gm | grep -c "^check-psql" || true')
[ "$w" = 0 ] && pass "check-psql --node leaves no password file in /run/gm" || fail "password files left: $w"

# --- v0.5: the image's G5 conditions (chunk 3a) -------------------------------------------
w=$(gm sh -c 'dpkg-query -W -f "\${Version}" postgresql-18-pgaudit; echo " $(test -f /usr/lib/postgresql/18/lib/pgaudit.so && echo so)"' 2>&1)
[ "$w" = "18.0-3.pgdg13+1 so" ] && pass "pgaudit pinned exactly, its library in place ($w)" || fail "pgaudit package: $w"
w=$(gm sh -c 'dpkg --compare-versions "$(dpkg-query -W -f "\${Version}" libssl3t64)" ge 3.5.7-1~deb13u3 && dpkg-query -W -f "\${Version}" libssl3t64' 2>&1)
[ -n "$w" ] && pass "libssl3t64 at or above the floor 3.5.7-1~deb13u3 ($w)" || fail "libssl3t64 floor"
check "ssl-cert's snakeoil key and certificate deleted" gm sh -c 'test ! -e /etc/ssl/private/ssl-cert-snakeoil.key && test ! -e /etc/ssl/certs/ssl-cert-snakeoil.pem'

# --- v0.5: TLS turned on by rec's seed (chunk 3a) --------------------------------------------
rec() { docker exec -i "$REC" "$@"; }
rec_pg() { docker exec -i -u postgres "$REC" psql -X -q -At -v ON_ERROR_STOP=1 -d postgres "$@"; }
rec_tls() {  # rec_tls <password> <user> <sql>: over TLS, the game's certificate verified
    docker exec -e PGPASSWORD="$1" "$CLIENT" psql "host=rec user=$2 dbname=postgres sslmode=verify-full sslrootcert=/k/tls.crt" -XAtc "$3"
}
w=$(rec_tls "$DBA_PASSWORD" dba "select ssl || ' ' || version from pg_stat_ssl where pid = pg_backend_pid()" 2>&1)
case $w in "true TLSv1."*) pass "rec serves TLS, verify-full against the game's certificate for host rec ($w)" ;; *) fail "TLS to rec: $w" ;; esac
served=$(docker exec "$CLIENT" sh -c 'openssl s_client -starttls postgres -connect rec:5432 </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256' 2>&1)
made=$(openssl x509 -in "$tmp/tls.crt" -noout -fingerprint -sha256 2>&1)
[ -n "$made" ] && [ "$served" = "$made" ] && pass "the certificate rec serves is the game's secret ($made)" || fail "served [$served], made [$made]"
w=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql "host=rec user=dba dbname=postgres sslmode=disable" -XAtc 'select 1' 2>&1)
case $w in *"rejects connection"*|*"no encryption"*) pass "rec turns a plain connection away (hostssl only)" ;; *) fail "plain connection to rec: $w" ;; esac
w=$(rec stat -c '%a %u:%g' /opt/gm/secrets/tls.key /opt/gm/secrets/tls.crt | tr '\n' ' ')
[ "$w" = "440 0:102 444 0:0 " ] && pass "the key root:postgres 0440, the certificate root 0444" || fail "TLS secret modes: $w"
w=$(gm_pg psql -XAtc 'show ssl' 2>&1)
[ "$w" = off ] && pass "db: TLS available, off where the seed does not turn it on" || fail "db's ssl: $w"
w=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql "host=db user=dba dbname=postgres sslmode=require" -XAtc 'select 1' 2>&1)
case $w in *"does not support SSL"*) pass "db refuses sslmode=require (server does not support SSL)" ;; *) fail "TLS to db: $w" ;; esac

# --- v0.5: pgaudit turned on by rec's seed (chunk 3a) ----------------------------------------
w=$(rec_pg -c 'show shared_preload_libraries' 2>&1)
[ "$w" = "pg_stat_statements,pgaudit" ] && pass "rec preloads pgaudit ($w)" || fail "rec's preload: $w"
w=$(rec_pg -c 'show pgaudit.log' 2>&1)
[ "$w" = "ddl, role, write" ] && pass "pgaudit's classes from the seed ($w)" || fail "pgaudit.log: $w"
rec_tls "$DBA_PASSWORD" dba "create table audit_probe (i int); insert into audit_probe values (1); create role audit_probe_role nologin; select 1" >/dev/null 2>&1 \
    || fail "audited statements as dba"
rec_log() { rec sh -c 'cat /var/log/postgresql/*.log'; }
sleep 1
for class in "DDL,CREATE TABLE" "WRITE,INSERT" "ROLE,CREATE ROLE"; do
    n=$(rec_log | grep -c "AUDIT: SESSION,[0-9]*,[0-9]*,$class,")
    [ "$n" -ge 1 ] && pass "pgaudit writes its class $class into the file log ($n line(s))" || fail "no AUDIT line for $class"
done
w=$(docker exec "$CLIENT" ssh $SSH_OPTS player@rec "grep -h 'AUDIT: SESSION' /var/log/postgresql/*.log | grep -c 'DDL,CREATE TABLE'" 2>&1)
[ "$w" -ge 1 ] 2>/dev/null && pass "player reads pgaudit's lines in the file log" || fail "player reading the audit lines: $w"

# --- v0.5: no password in the log pgaudit writes (G5) ----------------------------------------
# load-data's own session (inject.password_sql: statement logging and pgaudit
# off, a SCRAM verifier) setting a role's password from its secret.
mkdir -p "$tmp/secrets"
AUDIT_APP_PASSWORD="A:$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')"
printf '%s' "$AUDIT_APP_PASSWORD" > "$tmp/secrets/role_audit_app_password"
rec_pg -c 'create role audit_app login' >/dev/null 2>&1 || fail "create audit_app"
(cd "$REPO" && python3 -c 'import sys; from pathlib import Path; from tools.gm import inject
sys.stdout.write(inject.password_sql(Path(sys.argv[1]), [("audit_app", "role_audit_app_password")]))' "$tmp") \
    | docker exec -i -u postgres "$REC" psql -X -q -v ON_ERROR_STOP=1 -d postgres >/dev/null 2>"$tmp/audit-app.err" \
    && pass "load-data's password session runs on rec" || fail "load-data's password session: $(cat "$tmp/audit-app.err")"
w=$(rec_tls "$AUDIT_APP_PASSWORD" audit_app "select current_user" 2>&1)
[ "$w" = audit_app ] && pass "audit_app logs in with its secret's password" || fail "audit_app: $w"
# pgaudit 18.0 redacts a password in its own lines (<REDACTED>); PostgreSQL's
# statement logging does not, which is what the guard turns off: a canary
# shows both.
CANARY="canary-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
rec_pg -c "alter role audit_probe_role password '$CANARY'" >/dev/null 2>&1
sleep 1
n=$(rec_log | grep -c "$CANARY")
w=$(rec_log | grep -c 'AUDIT: SESSION,[0-9]*,[0-9]*,ROLE,ALTER ROLE,,,alter role audit_probe_role password <REDACTED>')
[ "$n" = 0 ] && [ "$w" -ge 1 ] && pass "pgaudit's role class logs a password's statement redacted (<REDACTED>)" \
    || fail "pgaudit and a password: canary in $n line(s), redacted lines $w"
CANARY2="canary-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
rec_pg -c "set log_statement = 'ddl'" -c "alter role audit_probe_role password '$CANARY2'" >/dev/null 2>&1
sleep 1
n=$(rec_log | grep -c "$CANARY2")
[ "$n" -ge 1 ] && pass "control: PostgreSQL's statement logging, which the guard turns off, logs a password in clear ($n line(s))" \
    || fail "control: the statement-logging canary is not in the log ($n)"
for v in DBA_PASSWORD MON_PASSWORD GMC_PASSWORD AUDIT_APP_PASSWORD; do
    eval "pw=\$$v"
    n=$(docker exec -e PW="$pw" "$REC" sh -c 'grep -rlF -e "$PW" /var/log/postgresql | wc -l' 2>&1)
    [ "$n" = 0 ] && pass "rec's log holds no $v" || fail "rec's log holds $v ($n file(s))"
done
n=$(rec_log | grep -c 'SCRAM-SHA-256\$')
[ "$n" = 0 ] && pass "rec's log holds no SCRAM verifier (load-data's session unaudited)" || fail "verifiers in the log: $n"

# --- v0.5: the option monitoring (chunk 3a) ------------------------------------------------
w=$(rec_tls "$MON_PASSWORD" monitoring "select pg_has_role(current_user, 'pg_monitor', 'member')" 2>&1)
[ "$w" = t ] && pass "rec (option on): monitoring logs in over TLS with its secret, holds pg_monitor" || fail "rec's monitoring: $w"
w=$(docker exec -u postgres "$J" psql -XAtc "select count(*) from pg_roles where rolname = 'monitoring'" 2>&1)
[ "$w" = 0 ] && pass "db2 (no option): no role monitoring" || fail "db2's monitoring role: $w"
check "db2 (no option): no monitoring_password mounted" docker exec "$J" test ! -e /opt/gm/secrets/monitoring_password
w=$(docker service logs "$SERVICE2" 2>&1 | grep -c 'roles dba (option monitoring off)')
[ "$w" -ge 1 ] && pass "db2's start-up log: roles dba (option monitoring off)" || fail "db2's initdb line: $w"
w=$(docker run --rm --read-only --tmpfs /run --network none -e GM_OPTIONS="monitoring pgcluu" "$IMAGE" 2>&1); rc=$?
case $rc:$w in 1:*"GM_OPTIONS names pgcluu, not an option of this brick"*) pass "an unknown option fails the container (exit 1)" ;; *) fail "unknown option: exit $rc: $w" ;; esac

# --- v0.5: a no-access node, pdb (chunk 3a) -------------------------------------------------
p_() { docker exec "$PDB" "$@"; }
check "pdb: no player account (getent passwd)" sh -c "! docker exec $PDB getent passwd player"
check "pdb: no player group" sh -c "! docker exec $PDB getent group player"
w=$(p_ getent group pgconf 2>&1)
case $w in pgconf:x:*:) pass "pdb: pgconf has no member ($w)" ;; *) fail "pdb's pgconf: $w" ;; esac
check "pdb: no sudo rules for player (/etc/sudoers.d/gm-player absent)" sh -c "! docker exec $PDB test -e /etc/sudoers.d/gm-player"
w=$(p_ sudo -l -U player 2>&1)
case $w in *"unknown user"*) pass "pdb: sudo knows no player ($w)" ;; *) fail "pdb's sudo: $w" ;; esac
w=$(docker exec "$CLIENT" ssh $SSH_OPTS player@pdb true 2>&1); rc=$?
[ "$rc" -ne 0 ] && pass "pdb: SSH as player refused with the player's key (exit $rc)" || fail "pdb: SSH as player worked"
check "pdb: no ~/.pgpass written" sh -c "! docker exec $PDB test -e /home/player/.pgpass"
w=$(p_ sh -c '/command/s6-svstat -o up /run/service/sshd; /command/s6-svstat -o up /run/service/postgres' | tr '\n' ' ')
[ "$w" = "true true " ] && pass "pdb: sshd and PostgreSQL up" || fail "pdb's services: $w"
w=$(docker exec -u postgres "$PDB" psql -XAtc 'select current_user' 2>&1)
[ "$w" = postgres ] && pass "pdb: gmctl's exec as postgres works (the daemon resolves the name)" || fail "pdb: exec as postgres: $w"
w=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql -h pdb -U dba -d postgres -XAtc 'select 1' 2>&1)
case $w in *"rejects connection"*) pass "pdb: dba from the network rejected by its own pg_hba.conf" ;; *) fail "dba over TCP on pdb: $w" ;; esac
w=$(docker service logs "$SERVICE4" 2>&1 | grep -c 'write policy no-access: no player account')
[ "$w" -ge 1 ] && pass "pdb's start-up log names its write policy" || fail "pdb's log line: $w"
check "db (fixable) keeps its player account" docker exec "$C" getent passwd player

# --- v0.5: the standby, cloned as load-data does (chunk 3b) ------------------------------
sb() { docker exec -i "$SB" "$@"; }
sb_pg() { docker exec -i -u postgres "$SB" psql -X -q -At -v ON_ERROR_STOP=1 -d postgres "$@"; }
py_sql() {  # py_sql <expression>: SQL from tools/gm/inject.py, as load-data writes it
    (cd "$REPO" && python3 -c 'import sys; from pathlib import Path; from tools.gm import inject
tmp = Path(sys.argv[1]); sys.stdout.write(eval(sys.argv[2]))' "$tmp" "$1")
}
w=$(sb_pg -c 'select pg_is_in_recovery()' 2>&1)
[ "$w" = f ] && pass "standby before its clone: a cluster of its own, not in recovery" || fail "standby before the clone: $w"
check "every postgres node's replication secret: rec and pdb mount it" sh -c "docker exec $REC test -s /opt/gm/secrets/replication_password && docker exec $PDB test -s /opt/gm/secrets/replication_password"
m=$(sb stat -c '%a %U:%G' /run/gm-replication/pgpass 2>&1)
[ "$m" = "600 postgres:postgres" ] && pass "standby: the replication password file /run/gm-replication/pgpass, postgres 0600" || fail "standby's pgpass: $m"
rec_pg -c 'create table repl_probe (i int); insert into repl_probe values (1)' >/dev/null 2>&1 || fail "repl_probe on rec"
py_sql 'inject.replication_sql(tmp, "standby")' | docker exec -i -u postgres "$REC" psql -X -q -v ON_ERROR_STOP=1 -d postgres >/dev/null 2>"$tmp/repl.err" \
    && pass "rec: the replication role set by load-data's SQL (inject.replication_sql)" || fail "replication role: $(cat "$tmp/repl.err")"
w=$(rec_pg -c "select rolreplication || ' ' || rolcanlogin || ' ' || rolsuper from pg_roles where rolname = 'replicator'" 2>&1)
[ "$w" = "true true false" ] && pass "replicator: LOGIN REPLICATION, not superuser" || fail "replicator: $w"
# The start-up race (spec D305): the clone starts while its primary is down
# and waits for it, bounded; rec comes back a few seconds later.
docker service scale -d "$SERVICE3=0" >/dev/null 2>&1
i=0
while [ "$i" -lt 60 ] && [ -n "$(db_container "$SERVICE3")" ]; do sleep 1; i=$((i + 1)); done
[ -z "$(db_container "$SERVICE3")" ] && pass "rec scaled to 0 before the clone starts" || fail "rec still running"
( docker exec "$SB" /usr/local/lib/gm/clone-standby > "$tmp/clone.out" 2> "$tmp/clone.err"; echo $? > "$tmp/clone.rc" ) &
clone_pid=$!
sleep 8
docker service scale -d "$SERVICE3=1" >/dev/null 2>&1
REC=$(wait_healthy "" "$SERVICE3") || fail "rec did not come back"
i=0
while [ "$i" -lt 300 ] && [ ! -s "$tmp/clone.rc" ]; do sleep 2; i=$((i + 2)); done
wait "$clone_pid" 2>/dev/null
rc=$(cat "$tmp/clone.rc" 2>/dev/null)
[ "$rc" = 0 ] && pass "clone-standby exit 0 ($(tr '\n' ';' < "$tmp/clone.out"))" || fail "clone-standby: exit $rc: $(cat "$tmp/clone.err")"
w=$(sed -n 's/.*primary rec answers (after \([0-9]*\)s).*/\1/p' "$tmp/clone.out")
[ -n "$w" ] && [ "$w" -ge 4 ] && pass "the clone waited for its primary, bounded (${w}s)" || fail "the clone's wait: [$w]"
w=$(py_sql 'inject.streaming_sql("standby", 60)' | docker exec -i -u postgres "$REC" psql -X -q -A -t -v ON_ERROR_STOP=1 -d postgres 2>&1 | tail -n 1)
case $w in *'"state" : "streaming"'*) pass "rec: load-data's wait sees the slot standby's sender streaming ($w)" ;; *) fail "streaming wait: $w" ;; esac
w=$(rec_pg -c "select r.application_name || ' ' || r.state || ' ' || s.slot_name || ' ' || s.active from pg_stat_replication r join pg_replication_slots s on s.active_pid = r.pid" 2>&1)
[ "$w" = "standby streaming standby true" ] && pass "rec's pg_stat_replication: standby streaming from its slot standby ($w)" || fail "pg_stat_replication: $w"
w=$(sb_pg -c "select pg_is_in_recovery() || ' ' || current_setting('hot_standby') || ' ' || current_setting('hot_standby_feedback')" 2>&1)
[ "$w" = "true on on" ] && pass "standby in recovery, hot_standby and hot_standby_feedback on" || fail "standby settings: $w"
rec_pg -c 'insert into repl_probe values (2)' >/dev/null 2>&1
i=0
while [ "$i" -lt 30 ] && [ "$(sb_pg -c 'select count(*) from repl_probe' 2>/dev/null)" != 2 ]; do sleep 1; i=$((i + 1)); done
w=$(docker exec -e PGPASSWORD="$DBA_PASSWORD" "$CLIENT" psql "host=standby user=dba dbname=postgres sslmode=verify-full sslrootcert=/k/tls.crt" -XAtc 'select count(*) from repl_probe' 2>&1)
[ "$w" = 2 ] && pass "standby answers a read-only query as dba over TLS, a row written after the clone included" || fail "read on the standby: $w"
w=$(sb_pg -c 'insert into repl_probe values (3)' 2>&1)
case $w in *"read-only transaction"*) pass "standby refuses a write (read-only)" ;; *) fail "write on the standby: $w" ;; esac
w=$(sb grep -E '^primary_(conninfo|slot_name)' /var/lib/postgresql/18/data/postgresql.auto.conf 2>&1)
case $w in
    *password=*) fail "primary_conninfo holds a password" ;;
    *"passfile=''/run/gm-replication/pgpass''"*"primary_slot_name = 'standby'"*) pass "primary_conninfo names the password file, no password; primary_slot_name standby" ;;
    *) fail "the standby's postgresql.auto.conf: $w" ;;
esac
w=$(sb sh -c 'test -e /var/lib/postgresql/18/data/standby.signal && echo yes' 2>&1)
[ "$w" = yes ] && pass "standby.signal written by the clone" || fail "no standby.signal"
w=$(sb_pg -c "select count(*) from pg_roles where rolname in ('dba', 'monitoring', 'gm_check', 'replicator')" 2>&1)
[ "$w" = 4 ] && pass "standby holds the primary's roles (dba, monitoring, gm_check, replicator)" || fail "the standby's roles: $w"
w=$(docker exec -i "$SB" /usr/local/lib/gm/check-psql -d postgres -XAtc 'select current_user' 2>&1)
[ "$w" = gm_check ] && pass "standby: gm_check through check-psql (the primary's role and password)" || fail "check-psql on the standby: $w"
m=$(sb stat -c '%a %U:%G' /usr/local/lib/gm/clone-standby)
[ "$m" = "700 root:root" ] && pass "clone-standby root only ($m)" || fail "clone-standby mode: $m"
info "the standby replaced by a new container"
docker service update --force -d "$SERVICE5" >/dev/null 2>&1
SB2=$(wait_healthy "$SB" "$SERVICE5") && SB=$SB2 && pass "standby healthy in a new container ($SB)" || fail "standby not back"
i=0
while [ "$i" -lt 60 ] && [ "$(rec_pg -c "select state from pg_stat_replication where application_name = 'standby'" 2>/dev/null)" != streaming ]; do sleep 1; i=$((i + 1)); done
w=$(rec_pg -c "select state from pg_stat_replication where application_name = 'standby'" 2>&1)
[ "$w" = streaming ] && pass "the new standby container streams again (its password file rewritten at start)" || fail "after the replacement: $w"
w=$(docker service logs "$SERVICE5" 2>&1 | grep -c "standby of rec (standby.signal): the GM's roles come from the primary")
[ "$w" -ge 1 ] && pass "the standby's start skips the single-user roles step" || fail "standby start-up line: $w"
# The hand-over snapshot with a standby: its temporary slot goes, the
# standby's stays (both nodes snapshot their pgdata).
docker exec "$REC" /usr/local/sbin/gm-snapshot-db > "$tmp/rec-pgdata.tar" 2> "$tmp/rec-snapshot.err"; rc=$?
[ "$rc" -eq 0 ] && pass "rec: gm-snapshot-db with a standby attached, exit 0" || fail "rec's snapshot: exit $rc: $(cat "$tmp/rec-snapshot.err")"
w=$(rec_pg -c "select string_agg(slot_name, ',' order by slot_name) from pg_replication_slots" 2>&1)
[ "$w" = standby ] && pass "rec: after the snapshot, only the standby's slot (gm_snapshot removed)" || fail "rec's slots after the snapshot: $w"
docker exec "$SB" /usr/local/sbin/gm-snapshot-db > "$tmp/sb-pgdata.tar" 2> "$tmp/sb-snapshot.err"; rc=$?
[ "$rc" -eq 0 ] && pass "standby: gm-snapshot-db exit 0 ($(wc -c < "$tmp/sb-pgdata.tar") bytes)" || fail "the standby's snapshot: exit $rc: $(cat "$tmp/sb-snapshot.err")"
w=$(sb_pg -c "select count(*) from pg_replication_slots" 2>&1)
[ "$w" = 0 ] && pass "standby: no slot left after its snapshot" || fail "the standby's slots: $w"
for node in REC SB; do
    eval "cid=\$$node"
    n=$(docker exec -e PW="$REPL_PASSWORD" "$cid" sh -c 'grep -rlF -e "$PW" /var/log/postgresql | wc -l' 2>&1)
    [ "$n" = 0 ] && pass "$node's log holds no replication password" || fail "$node's log holds the replication password ($n file(s))"
done

# --- v0.5: clone-standby's restore mode (chunk 28; capture W2-g item 3) ------------------
# As a restart from the hand-over snapshot finds it: the standby's restored
# data directory holding its own settings, no slot of its name on its
# primary. Each clone below runs with its postgres stopped and the slot gone.
AUTO=/var/lib/postgresql/18/data/postgresql.auto.conf
reclone() {  # reclone [--restore]: rc in $tmp/reclone.rc, output in $tmp/reclone.{out,err}
    docker exec "$SB" sh -c '/command/s6-svc -d /run/service/postgres && /command/s6-svwait -d -t 120000 /run/service/postgres' >/dev/null 2>&1
    k=0
    while [ "$k" -lt 30 ] && [ "$(rec_pg -c "select count(*) from pg_replication_slots where slot_name = 'standby' and active" 2>/dev/null)" != 0 ]; do sleep 1; k=$((k + 1)); done
    rec_pg -c "select pg_drop_replication_slot('standby')" >/dev/null 2>&1
    docker exec "$SB" /usr/local/lib/gm/clone-standby "$@" > "$tmp/reclone.out" 2> "$tmp/reclone.err"
    echo $? > "$tmp/reclone.rc"
}
sb_streams() {  # sb_streams <row value>: rec's sender streaming and the row read on the standby
    k=0
    while [ "$k" -lt 60 ] && [ "$(rec_pg -c "select state from pg_stat_replication where application_name = 'standby'" 2>/dev/null)" != streaming ]; do sleep 1; k=$((k + 1)); done
    rec_pg -c "insert into repl_probe values ($1)" >/dev/null 2>&1
    k=0
    while [ "$k" -lt 30 ] && [ "$(sb_pg -c "select count(*) from repl_probe where i = $1" 2>/dev/null)" != 1 ]; do sleep 1; k=$((k + 1)); done
    printf '%s %s' "$(rec_pg -c "select r.state || '/' || s.slot_name || '/' || s.active from pg_stat_replication r join pg_replication_slots s on s.active_pid = r.pid where r.application_name = 'standby'" 2>&1)" \
        "$(sb_pg -c "select count(*) from repl_probe where i = $1" 2>&1)"
}
w=$(docker exec "$SB" /usr/local/lib/gm/clone-standby --bogus 2>&1; echo "rc=$?")
case $w in *"usage: clone-standby [--restore]"*"rc=2") pass "clone-standby: an unknown argument a usage error (exit 2)" ;; *) fail "clone-standby --bogus: $w" ;; esac
docker exec -u postgres "$SB" sh -c "printf '%s\n' \"statement_timeout = '7min'\" >> $AUTO" \
    && pass "a setting written into the standby's postgresql.auto.conf (statement_timeout = '7min')" || fail "writing into the standby's postgresql.auto.conf"
reclone --restore
rc=$(cat "$tmp/reclone.rc")
[ "$rc" = 0 ] && pass "clone-standby --restore exit 0 ($(tr '\n' ';' < "$tmp/reclone.out"))" || fail "clone-standby --restore: exit $rc: $(cat "$tmp/reclone.err")"
w=$(grep -c "saved\|put back" "$tmp/reclone.out")
[ "$w" = 2 ] && pass "the restore mode saved the standby's postgresql.auto.conf and put it back" || fail "restore mode's lines: $(cat "$tmp/reclone.out")"
w=$(sb_pg -c 'show statement_timeout' 2>&1)
[ "$w" = 7min ] && pass "the setting kept across the clone (statement_timeout $w)" || fail "statement_timeout after --restore: $w"
m=$(sb stat -c '%a %U:%G' "$AUTO" 2>&1)
[ "$m" = "600 postgres:postgres" ] && pass "postgresql.auto.conf put back postgres 0600" || fail "postgresql.auto.conf: $m"
w=$(sb grep -E '^primary_(conninfo|slot_name)' "$AUTO" 2>&1)
case $w in
    *password=*) fail "primary_conninfo holds a password after --restore" ;;
    *"passfile=''/run/gm-replication/pgpass''"*"primary_slot_name = 'standby'"*) pass "after --restore, primary_conninfo names the password file, primary_slot_name standby" ;;
    *) fail "the standby's postgresql.auto.conf after --restore: $w" ;;
esac
w=$(sb_streams 4)
[ "$w" = "streaming/standby/true 1" ] && pass "after --restore: rec's sender streaming from the slot standby, a row written on rec read on the standby ($w)" || fail "after --restore: $w"
w=$(sb_pg -c 'select pg_is_in_recovery()' 2>&1)
[ "$w" = t ] && pass "after --restore: the standby in recovery" || fail "after --restore, in recovery: $w"
info "clone-standby's default mode, unchanged"
reclone
rc=$(cat "$tmp/reclone.rc")
[ "$rc" = 0 ] && pass "clone-standby (no argument) exit 0" || fail "clone-standby: exit $rc: $(cat "$tmp/reclone.err")"
w=$(sb_pg -c 'show statement_timeout' 2>&1)
w2=$(sb grep -c statement_timeout "$AUTO" 2>&1)
[ "$w" = 0 ] && [ "$w2" = 0 ] && pass "the default mode keeps nothing of the standby's own postgresql.auto.conf (statement_timeout $w)" || fail "default mode: statement_timeout $w, $w2 line(s)"
case $(cat "$tmp/reclone.out") in *"saved"*|*"put back"*) fail "the default mode saved or put back a file" ;; *) pass "the default mode saves nothing" ;; esac
w=$(sb_streams 5)
[ "$w" = "streaming/standby/true 1" ] && pass "after the default clone: streaming, a row read on the standby ($w)" || fail "after the default clone: $w"

# --- v0.5: WAL archiving to the vault (chunk 3b) ------------------------------------------
vault() { docker exec -i "$VAULT" "$@"; }
shipment() {  # shipment <id> <status>: the stand-in's record of that answer, as key=value
    vault cat /srv/vault/shipments.ndjson 2>/dev/null | python3 -c 'import json, sys
for line in sys.stdin:
    r = json.loads(line)
    if r.get("id") == sys.argv[1] and str(r.get("status")) == sys.argv[2]:
        print(" ".join(f"{k}={r[k]}" for k in sorted(r)))' "$1" "$2"
}
archiver() { rec_pg -c "select coalesce(last_archived_wal, '-') || ' ' || failed_count || ' ' || coalesce(last_failed_wal, '-') from pg_stat_archiver"; }
w=$(rec_pg -c "select current_setting('archive_mode') || '|' || current_setting('archive_command') || '|' || current_setting('archive_timeout')" 2>&1)
[ "$w" = "on|vault-post wal %f %p|1h" ] && pass "rec's archiving from the seed ($w)" || fail "archiving settings: $w"
w=$(rec sh -c 'stat -c "%a %U" /run/gm-vault/target /run/gm-vault/credential; cat /run/gm-vault/target' | tr '\n' ' ')
[ "$w" = "600 postgres 600 postgres vault:8080 " ] && pass "rec: vault-post's target and credential under /run/gm-vault, postgres 0600" || fail "/run/gm-vault: $w"
check "player cannot read the vault's credential" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@rec cat /run/gm-vault/credential"
switch_wal() { rec_pg -c "insert into repl_probe select g from generate_series(1, 1000) g; select pg_walfile_name(pg_switch_wal())" 2>/dev/null | tail -n 1; }
wait_archived() {  # wait_archived <segment> <seconds>
    k=0
    while [ "$k" -lt "$2" ]; do
        case $(archiver 2>/dev/null) in "$1 "*) return 0 ;; esac
        sleep 2; k=$((k + 2))
    done
    return 1
}
SEG=$(switch_wal)
wait_archived "$SEG" 90 && pass "a switched segment archived ($SEG; pg_stat_archiver: $(archiver))" || fail "segment $SEG not archived: $(archiver)"
w=$(shipment "$SEG" 201)
today=$(date -u +%Y-%m-%d)
case " $w " in
    *" credential_ok=True from=$today id=$SEG method=POST name=$SEG path=/shipments received=16777216 rows=1 source=rec status=201 to=$today type=wal "*)
        pass "the vault received it whole: POST /shipments, its headers, the credential ($w)" ;;
    *) fail "the vault's record of $SEG: [$w]" ;;
esac
vault sh -c 'echo refuse > /srv/vault/mode'
before=$(archiver | cut -d' ' -f2)
SEG2=$(switch_wal)
k=0
while [ "$k" -lt 60 ]; do
    set -- $(archiver 2>/dev/null)
    [ "${2:-0}" -gt "$before" ] && [ "${3:-}" = "$SEG2" ] && break
    sleep 2; k=$((k + 2))
done
w=$(archiver)
case $w in "$SEG "*" $SEG2") pass "a refusal fails honestly: $SEG2 not archived, failed_count up ($w)" ;; *) fail "after a refusal: $w" ;; esac
check "the refused segment is kept (archive_status/$SEG2.ready)" docker exec "$REC" test -e "/var/lib/postgresql/18/data/pg_wal/archive_status/$SEG2.ready"
n=$(rec_log | grep -c "vault-post: wal $SEG2: the vault at vault:8080 refused it: 503")
[ "$n" -ge 1 ] && pass "vault-post's reason in the server log ($n line(s): refused it: 503)" || fail "no refusal line in the log"
vault sh -c 'echo short > /srv/vault/mode'
k=0
while [ "$k" -lt 120 ] && [ "$(rec_log | grep -c "vault-post: wal $SEG2: the vault received 16777215 of 16777216 bytes")" = 0 ]; do sleep 2; k=$((k + 2)); done
n=$(rec_log | grep -c "vault-post: wal $SEG2: the vault received 16777215 of 16777216 bytes")
[ "$n" -ge 1 ] && pass "a receipt short of the bytes sent fails too (the reason in the log)" || fail "no short-receipt line"
case $(archiver) in "$SEG "*) pass "still not archived after the short receipt" ;; *) fail "archived on a short receipt: $(archiver)" ;; esac
vault sh -c 'echo accept > /srv/vault/mode'
wait_archived "$SEG2" 150 && pass "the archiver retries and ships $SEG2 once the vault accepts ($(archiver))" || fail "$SEG2 not shipped on the retry: $(archiver)"
w=$(docker exec -u postgres "$J" sh -c 'vault-post wal x /etc/hostname; echo "rc=$?"' 2>&1 | tr '\n' ' ')
case $w in *"no vault configured"*"rc=1 ") pass "vault-post with no vault: exit 1, no vault configured" ;; *) fail "vault-post on db2: $w" ;; esac
w=$(docker exec -u postgres "$REC" sh -c 'vault-post nightly x; echo "rc=$?"' 2>&1 | tr '\n' ' ')
case $w in *"rc=2 ") pass "vault-post refuses a bad usage (exit 2)" ;; *) fail "vault-post usage: $w" ;; esac
m=$(rec stat -c '%a %U:%G' /usr/local/bin/vault-post)
[ "$m" = "755 root:root" ] && pass "vault-post root-owned 0755, on PATH ($m)" || fail "vault-post mode: $m"

# --- v0.5: the nightly base backup, moved to the next minute (chunk 3b) ----------------------
now=$(date -u +%s)
[ $((now % 60)) -gt 30 ] && now=$((now + 60))
at=$((now + 60))
M=$(date -u -d "@$at" +%-M); H=$(date -u -d "@$at" +%-H)
sed "s/^30 3 \* \* \* /$M $H * * * /" "$HERE/fixtures/crontab-v05" | docker exec -i "$REC" crontab -u postgres - \
    && pass "rec: the base-backup job moved to $H:$(printf %02d "$M") UTC" || fail "moving the base-backup job"
NAME="rec-$(date -u -d "@$at" +%Y%m%dT%H%MZ)"
k=0
while [ "$k" -lt 240 ] && [ -z "$(shipment "$NAME" 201)" ]; do sleep 3; k=$((k + 3)); done
w=$(shipment "$NAME" 201)
case " $w " in
    *" credential_ok=True "*" name=$NAME "*" rows=1 source=rec status=201 "*" type=basebackup "*) pass "the base backup posted as type basebackup ($w)" ;;
    *) fail "no base backup shipment $NAME: [$w]" ;;
esac
size=$(printf '%s\n' "$w" | sed -n 's/.* received=\([0-9]*\) .*/\1/p')
[ "${size:-0}" -gt 1000000 ] && pass "posted whole: $size bytes" || fail "base backup size: $size"
w=$(rec grep -c "vault-post: basebackup $NAME shipped" /var/log/postgresql/cron/basebackup.log 2>&1)
[ "$w" = 1 ] && pass "the job's log (cron/basebackup.log) records the receipt" || fail "basebackup.log: $w"
while [ "$(date -u +%s)" -lt $((at + 75)) ]; do sleep 5; done
n=$(vault cat /srv/vault/shipments.ndjson | grep -c '"type":"basebackup"')
[ "$n" = 1 ] && pass "posted once: one base backup in the vault after its minute" || fail "base backups in the vault: $n"

# --- v0.4: footprint at rest of the jobs (chunk 4b) ----------------------------------------
cpid=$(j pgrep -x cron)
lpid=$(jsql "select pid from pg_stat_activity where backend_type = 'pg_cron launcher'")
info "db2 at rest: cron RSS $(j ps -o rss= -p "$cpid" | tr -d ' ')K, pg_cron launcher RSS $(j ps -o rss= -p "$lpid" | tr -d ' ')K"

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
info "footprint at rest: db $(docker stats --no-stream --format '{{.MemUsage}}, CPU {{.CPUPerc}}' "$C"); db2 (cron, pg_cron) $(docker stats --no-stream --format '{{.MemUsage}}, CPU {{.CPUPerc}}' "$J")"
info "footprint at rest (v0.5): rec (TLS, pgaudit, the option) $(docker stats --no-stream --format '{{.MemUsage}}, CPU {{.CPUPerc}}' "$REC"); pdb (no-access) $(docker stats --no-stream --format '{{.MemUsage}}, CPU {{.CPUPerc}}' "$PDB"); standby $(docker stats --no-stream --format '{{.MemUsage}}, CPU {{.CPUPerc}}' "$SB"); rec's pgdata $(rec du -sh /var/lib/postgresql/18/data | cut -f1) (pg_wal $(rec du -sh /var/lib/postgresql/18/data/pg_wal | cut -f1)), its log $(rec du -sh /var/log/postgresql | cut -f1); standby's pgdata $(sb du -sh /var/lib/postgresql/18/data | cut -f1)"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
