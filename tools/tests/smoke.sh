#!/bin/sh
# Smoke run of gmctl on a real single-node swarm (build plan v0.1, chunks 5
# and 7; the wave gate's smoke run).
#
# On a copy of the fixture scenario (tools/tests/fixtures/fixture-audit):
#   fit -> render -> deploy (credentials, labelled configs and secrets, stack,
#   health checks) -> exec on both nodes -> logs, status
#   -> load-data -> inject twice (same result) -> status --set handed-over
#   -> check (1) -> the fix through exec -> check (0)
#   -> validate green, then red after an out-of-envelope change -> teardown,
# then asserts that nothing carrying the game's labels is left (services,
# containers, networks, volumes, configs, secrets) and that the objects not
# belonging to the game are the same as before.
#
# Needs: a swarm manager on the local engine (docker swarm init), and the
# bricks' images built locally:
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.1.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.1.0 bricks/bastion
# Host port 2222 must be free (the bastion's published port).
# Usage: sh tools/tests/smoke.sh        (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=smoke
IMAGES="127.0.0.1:5000/dbagm/postgres:0.1.0 127.0.0.1:5000/dbagm/bastion:0.1.0"
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
same "credential files are mode 600" "600 600 600 600" \
    "$(stat -c %a "$LDIR/secrets/player_password" "$LDIR/secrets/player_ssh_key" \
        "$LDIR/secrets/player_ssh_key.pub" "$LDIR/secrets/dba_password" | tr '\n' ' ' | sed 's/ $//')"
same "configs and secrets carry both labels" "10" \
    "$(for k in config secret; do docker "$k" ls --filter "label=dbagm.game=$GAME" \
        --filter "label=com.docker.stack.namespace=$GAME" -q; done | wc -l | tr -d ' ')"
same "volumes carry dbagm.game" "7" \
    "$(docker volume ls -q --filter "label=dbagm.game=$GAME" | wc -l | tr -d ' ')"
bastion=$(docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_bastion")
check "bastion publishes port 2222" sh -c "docker port $bastion 22/tcp | grep -q ':2222\$'"

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
check "load-data" $GMCTL load-data "$SCN" --playground "$PG"
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
check "inject" $GMCTL inject "$SCN" --playground "$PG"
same "status: stage injected" injected "$(stage)"
first=$(indexes)
same "the test fault is planted (index dropped)" "orders_pkey" "$first"
check "inject again (replay)" $GMCTL inject "$SCN" --playground "$PG"
same "second inject: same result" "$first" "$(indexes)"
same "second inject: stage stays injected" injected "$(stage)"
check "status --set handed-over" $GMCTL status "$SCN" --playground "$PG" --set handed-over
same "status: stage handed-over" handed-over "$(stage)"

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
