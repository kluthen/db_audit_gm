#!/bin/sh
# Smoke run of gmctl on a real single-node swarm (build plan v0.1, chunks 5
# and 7; the wave gate's smoke run).
#
# On a copy of the fixture scenario (tools/tests/fixtures/fixture-audit):
#   fit -> render -> deploy (credentials, labelled configs and secrets, stack,
#   health checks; the network's name, UTC on every node) -> exec on both
#   nodes -> logs, status
#   -> load-data -> inject twice (same result) -> status --set handed-over
#   -> check (1) -> the fix through exec -> check (0)
#   -> validate green, then red after an out-of-envelope change -> teardown,
# then asserts that nothing carrying the game's labels is left (services,
# containers, networks, volumes, configs, secrets) and that the objects not
# belonging to the game are the same as before.
#
# Needs: a swarm manager on the local engine (docker swarm init), and the
# bricks' images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.3.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.3.0 bricks/bastion
# Host port 2222 must be free (the bastion's published port).
# Usage: sh tools/tests/smoke.sh        (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=smoke
IMAGES="127.0.0.1:5000/dbagm/postgres:0.3.0 127.0.0.1:5000/dbagm/bastion:0.3.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

# Objects on the engine that do not carry the game's labels, one per line.
others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
}

# Everything still carrying one of the game's labels, one per line.
labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of $0)" >&2; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke.XXXXXX")
SCN=$tmp/fixture-audit
LDIR=$SCN/local/$PG
GAME=
deployed=no

cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
        left=$(labelled)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$REPO/tools/tests/fixtures/fixture-audit" "$SCN"

# --- local implementation ---------------------------------------------------
info "gmctl fit"
$GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 20G
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
info "gmctl render"
$GMCTL render "$SCN" --playground "$PG"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- deployment -----------------------------------------------------------
info "gmctl deploy"
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: stack deployed and healthy"
else
    fail "deploy"
    exit 1
fi

# From here on, every check records its own result; keep going on failure.
set +e

same "status: stage deployed" "  stage: deployed" "$($GMCTL status "$SCN" --playground "$PG" | grep '^  stage:')"
same "secrets/ is mode 700" 700 "$(stat -c %a "$LDIR/secrets")"
same "credential files are mode 600" "600 600 600 600 600" \
    "$(stat -c %a "$LDIR/secrets/player_password" "$LDIR/secrets/player_ssh_key" \
        "$LDIR/secrets/player_ssh_key.pub" "$LDIR/secrets/dba_password" \
        "$LDIR/secrets/tools_password" | tr '\n' ' ' | sed 's/ $//')"
# v0.3: postgres adds gm_check_password (W1-x); pgbouncer_lookup_password is
# only_with_role: pooler, and fixture-audit has no pooler node (chunk 7b).
same "configs and secrets carry both labels" "13" \
    "$(for k in config secret; do docker "$k" ls --filter "label=dbagm.game=$GAME" \
        --filter "label=com.docker.stack.namespace=$GAME" -q; done | wc -l | tr -d ' ')"
same "volumes carry dbagm.game" "9" \
    "$(docker volume ls -q --filter "label=dbagm.game=$GAME" | wc -l | tr -d ' ')"
bastion=$(docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_bastion")
check "bastion publishes port 2222" sh -c "docker port $bastion 22/tcp | grep -q ':2222\$'"
# v0.2, no web interface in fixture-audit: only SSH is published and the web
# front does not run (spec D103).
same "bastion publishes port 22 only" "22/tcp " \
    "$(docker inspect -f '{{range $p, $b := .NetworkSettings.Ports}}{{if $b}}{{$p}} {{end}}{{end}}' "$bastion")"
same "bastion's web front not running" "false" \
    "$(docker exec "$bastion" /command/s6-svstat -o up /run/service/web-front 2>&1)"
# v0.2: the network carries the scenario's network name; every node runs in UTC.
same "network named after the scenario's network" "${GAME}_backend" \
    "$(docker network ls --filter "label=com.docker.stack.namespace=$GAME" --format '{{.Name}}')"
same "status: network line" "  network: ${GAME}_backend" \
    "$($GMCTL status "$SCN" --playground "$PG" | grep '^  network:')"
same "status: lists the 7 secret files" 7 \
    "$($GMCTL status "$SCN" --playground "$PG" | sed -n '/^  secrets: /,$p' | grep -c '^    ')"
for node in db bastion; do
    out=$(printf 'printf "%%s %%s" "$TZ" "$(date +%%Z)"\n' \
        | $GMCTL exec "$SCN" --playground "$PG" --node "$node" --user root)
    same "node $node runs in UTC" "UTC UTC" "$out"
done

# --- exec -----------------------------------------------------------------
out=$(printf 'id -un\npsql -tAc "select 40 + 2"\n' \
    | $GMCTL exec "$SCN" --playground "$PG" --node db --user postgres)
same "exec db as postgres returns the script's output" "postgres
42" "$out"
out=$(printf 'printf "%%s|%%s" "$(id -un)" "$GREETING"\n' \
    | $GMCTL exec "$SCN" --playground "$PG" --node bastion --user player --env 'GREETING=hello world')
same "exec bastion as player, with an environment variable" "player|hello world" "$out"
printf 'exit 3\n' | $GMCTL exec "$SCN" --playground "$PG" --node db --user root
same "exec returns the script's exit status" 3 "$?"
printf 'true\n' | $GMCTL exec "$SCN" --playground "$PG" --node db --user no-such-user 2>/dev/null
same "exec as an unknown user exits 125" 125 "$?"
check "logs" $GMCTL logs "$SCN" --playground "$PG" --node db --tail 5

# --- validate and check (chunk 7) -------------------------------------------
# The setup steps after deployment, then the evaluation, on the deployed game.

# exec_db <user>: the script on stdin, run on db as <user>; prints its output.
exec_db() { $GMCTL exec "$SCN" --playground "$PG" --node db --user "$1"; }
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
# The indexes of shop's orders table, comma-separated.
indexes() {
    exec_db postgres <<'EOF'
psql -XAtq -d shop -c "SELECT string_agg(indexname, ',' ORDER BY indexname) FROM pg_indexes WHERE tablename = 'orders'"
EOF
}

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
same "status: stage data-loaded" data-loaded "$(stage)"
out=$(exec_db postgres <<'EOF'
psql -XAtq -d shop -c "SELECT (SELECT count(*) FROM customers) || ' ' || (SELECT count(*) FROM orders)"
EOF
)
same "fixture data loaded (customers, orders)" "500 20000" "$out"
same "fixture data has the index the test fault drops" "orders_customer_id_idx,orders_pkey" "$(indexes)"
out=$($GMCTL load-data "$SCN" --playground "$PG")
same "load-data again: exit 0, nothing done" "0 already" \
    "$? $(printf '%s' "$out" | grep -o 'already' | head -n 1)"

info "gmctl inject (twice)"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
same "status: stage injected" injected "$(stage)"
first=$(indexes)
same "the test fault is planted (index dropped)" "orders_pkey" "$first"
check "inject again (replay)" $GMCTL inject "$SCN" --playground "$PG"
same "second inject: same result" "$first" "$(indexes)"
same "second inject: stage stays injected" injected "$(stage)"
check "status --set handed-over" $GMCTL status "$SCN" --playground "$PG" --set handed-over
same "status: stage handed-over" handed-over "$(stage)"

# verdicts <output>: the instance lines of gmctl check, without their reasons.
verdicts() { printf '%s\n' "$1" | sed 's/ — .*//'; }

info "gmctl check (faults present)"
out=$($GMCTL check "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "check: exit 1 while the faults are present" 1 "$rc"
same "check: one line per instance, both present" "f1 fixture-random-page-cost: present
f2 fixture-dropped-index: present" "$(verdicts "$out")"

info "the fix, through exec (an index, random_page_cost lowered)"
exec_db postgres >/dev/null <<'EOF'
set -e
psql -XAtq -v ON_ERROR_STOP=1 -d shop -c "CREATE INDEX orders_by_customer ON orders (customer_id)"
psql -XAtq -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET random_page_cost = 1.1" -c "SELECT pg_reload_conf()"
sleep 1
EOF
same "fix applied through exec" 0 "$?"
out=$($GMCTL check "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "check: exit 0 once fixed" 0 "$rc"
same "check: both fixed" "f1 fixture-random-page-cost: fixed
f2 fixture-dropped-index: fixed" "$(verdicts "$out")"

info "gmctl validate (green)"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "validate: exit 0, every node green" 0 "$rc"
same "validate: verdicts" "Validators of game $GAME: bastion green, db green." \
    "$(printf '%s\n' "$out" | tail -n 1)"

info "an out-of-envelope change, through exec (work_mem above 64MB)"
exec_db postgres >/dev/null <<'EOF'
set -e
psql -XAtq -v ON_ERROR_STOP=1 -c "ALTER SYSTEM SET work_mem = '128MB'" -c "SELECT pg_reload_conf()"
sleep 1
EOF
same "change applied through exec" 0 "$?"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "validate: exit 1 after the change" 1 "$rc"
same "validate: verdicts" "Validators of game $GAME: bastion green, db red." \
    "$(printf '%s\n' "$out" | tail -n 1)"
same "validate: a red line under db names work_mem" yes \
    "$(printf '%s\n' "$out" | sed -n '/^db:$/,$p' | grep -q '^  RED .*work_mem' && echo yes)"
same "evaluation changed no stage" handed-over "$(stage)"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "status: stage torn-down" "  stage: torn-down" "$($GMCTL status "$SCN" --playground "$PG" | grep '^  stage:')"
left=$(labelled)
same "nothing labelled with game $GAME is left" "" "$left"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

if [ "$failures" -eq 0 ]; then
    echo "smoke: all checks passed (game $GAME)"
else
    echo "smoke: $failures check(s) failed (game $GAME)"
    exit 1
fi
