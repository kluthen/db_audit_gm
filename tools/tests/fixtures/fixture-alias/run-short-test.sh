#!/bin/sh
# Short test of the alias fixture (v0.5 build plan, chunk 7; spec D356,
# D362; capture W2 item 2): a call by a third party's alias answered, the
# caller started before the api node, waiting, bounded, then calling once
# the alias resolves. On one host, under ten minutes.
#
# On a copy of tools/tests/fixtures/fixture-alias (caller: scheduler 0.3.0,
# partners: api 0.1.0, no-access, under third_parties: with hostname xlab):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render -> deploy, then:
#   - the stack file: partners with the network alias xlab, every other
#     service in the list form; http_xlab_status mounted 0:0 0400 on both
#     nodes, one secret of the game;
#   - from the caller, xlab resolves; the endpoint answers 401 without the
#     credential (from inside the api node);
#   - the api node scaled to 0, the alias no longer resolves; the caller's
#     load started (the load-started marker, as gmctl start-load writes
#     it): it logs `wait status=waiting bound=30s connections=xlab` and
#     does not run; the api node scaled back to 1: the wait ends within its
#     bound (resolved, or unresolved at 30 s: an alias enters Swarm's DNS
#     only once its task is healthy, D356), the caller runs, and once the
#     alias resolves its calls are answered, the api node's log showing
#     `status=200 ... host=xlab endpoint=xlab_status ... agent=caller`;
#     every call before that an honest error, never a hang;
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-alias/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=alias-short
IMAGES="127.0.0.1:5000/dbagm/scheduler:0.3.0 127.0.0.1:5000/dbagm/api:0.1.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SECRET=/opt/gm/secrets/http_xlab_status
SCHEDLOG=/var/log/scheduler/scheduler.log
APILOG=/var/log/api/api.log
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
}

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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-alias-short.XXXXXX")
SCN=$tmp/fixture-alias
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

cp -R "$HERE" "$SCN"
rm -f "$SCN/run-short-test.sh"

# The node's running container (one replica).
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
cx() { n=$1; shift; docker exec "$(ctr "$n")" "$@"; }
clog() { cx caller cat "$SCHEDLOG" 2>/dev/null || true; }
cstatus() { cx caller cat /run/scheduler/status 2>/dev/null || true; }
resolves() { docker exec "$(ctr caller)" getent hosts xlab >/dev/null 2>&1; }
utc() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: both images and the reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
info "gmctl render --handover $HANDOVER"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- the stack file ---------------------------------------------------------
st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
svc = stack["services"]
print("partners", svc["partners"]["networks"])
print("caller", svc["caller"]["networks"])
for node in ("caller", "partners"):
    m = [s for s in svc[node]["secrets"] if s["source"] == f"{gid}_http_xlab_status"]
    print(node, [(s["target"], s["uid"], s["gid"], oct(s["mode"])) for s in m])
print("secrets", sorted(s for s in stack["secrets"] if "http_" in s))
EOF
)
same "stack: partners has the alias xlab" "partners {'backend': {'aliases': ['xlab']}}" \
    "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: the caller keeps the list form" "caller ['backend']" "$(printf '%s\n' "$st" | sed -n 2p)"
same "stack: http_xlab_status mounted on the caller" \
    "caller [('$SECRET', '0', '0', '0o400')]" "$(printf '%s\n' "$st" | sed -n 3p)"
same "stack: http_xlab_status mounted on partners" \
    "partners [('$SECRET', '0', '0', '0o400')]" "$(printf '%s\n' "$st" | sed -n 4p)"
same "stack: one HTTP credential secret in the game" "secrets ['${GAME}_http_xlab_status']" \
    "$(printf '%s\n' "$st" | sed -n 5p)"

# --- deployment -----------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: both nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
k=$(wc -c < "$LDIR/secrets/http_xlab_status" | tr -d ' ')
same "the credential's secret file: 32 characters" 32 "$k"
for n in caller partners; do
    m=$(cx "$n" stat -c '%u:%g %a' "$SECRET")
    same "$n: $SECRET is 0:0 0400" "0:0 400" "$m"
done
if resolves; then pass "the caller resolves xlab, the partners' alias"; else fail "xlab does not resolve"; fi
code=$(cx partners curl -s -o /dev/null -w '%{http_code}' -H 'Host: xlab' http://127.0.0.1:8000/status || true)
same "xlab's status without the credential: 401" 401 "$code"

# --- the caller started before the api node ----------------------------------
info "the api node scaled to 0"
docker service scale -d "${GAME}_partners=0" >/dev/null
i=0
while [ "$i" -lt 60 ] && { [ -n "$(ctr partners)" ] || resolves; }; do sleep 1; i=$((i + 1)); done
if resolves; then fail "xlab still resolves with the api node at 0"; else pass "xlab no longer resolves"; fi
case $(cstatus) in idle\ *) pass "the caller is idle before the load: $(cstatus)" ;;
    *) fail "the caller's status before the load: [$(cstatus)]" ;; esac
T0=$(utc "$(date +%s)")
cx caller sh -c "printf '%s\n' '$T0' > /var/lib/gm-state/.load-started.tmp \
    && chown root:scheduler /var/lib/gm-state/.load-started.tmp \
    && chmod 0440 /var/lib/gm-state/.load-started.tmp \
    && mv /var/lib/gm-state/.load-started.tmp /var/lib/gm-state/load-started \
    && /command/s6-svc -r /run/service/scheduler"
info "the caller's load started at $T0"
i=0
while [ "$i" -lt 30 ] && ! clog | grep -q ' wait status=waiting bound=30s connections=xlab$'; do
    sleep 1; i=$((i + 1))
done
w=$(clog | grep ' wait status=waiting ' | tail -n 1)
[ -n "$w" ] && pass "the caller waits, bounded, for xlab: $w" \
    || fail "no wait line: $(clog | tail -n 3 | tr '\n' '|')"
sleep 3
if [ -z "$(cstatus)" ] && ! clog | grep -q " state state=running t0=$T0"; then
    pass "not running while it waits (no status, no running line)"
else
    fail "running before the api node: [$(cstatus)]"
fi
up=$(date +%s)
docker service scale -d "${GAME}_partners=1" >/dev/null
info "the api node scaled to 1 at $(utc "$up")"
i=0
while [ "$i" -lt 60 ]; do case $(cstatus) in running\ *) break ;; esac; sleep 1; i=$((i + 1)); done
r=$(clog | grep -E ' wait status=(resolved|unresolved) ' | tail -n 1)
ms=$(printf '%s' "$r" | sed -n 's/.* ms=\([0-9]*\) .*/\1/p')
case $(cstatus) in
    running\ *) [ "${ms:-99999}" -le 31000 ] \
                    && pass "the wait ended within its bound, then running ($r; $(cstatus))" \
                    || fail "wait: [$r], status [$(cstatus)]" ;;
    *) fail "the caller is not running after the api node started: [$(cstatus)] $(clog | tail -n 3 | tr '\n' '|')" ;;
esac
i=0
while [ "$i" -lt 90 ] && ! resolves; do sleep 1; i=$((i + 1)); done
resolves && info "xlab resolves again $(( $(date +%s) - up )) s after the scale-up" \
    || fail "xlab does not resolve 90 s after the scale-up"
answered() { cx partners cat "$APILOG" 2>/dev/null \
    | grep ' request status=200 ' | grep ' host=xlab ' | grep ' endpoint=xlab_status ' \
    | grep -c ' agent=caller ' || true; }
i=0
while [ "$i" -lt 30 ] && [ "$(answered)" -lt 3 ]; do sleep 1; i=$((i + 1)); done
n=$(answered)
[ "$n" -ge 3 ] && pass "calls by the alias answered: $n lines status=200 host=xlab endpoint=xlab_status agent=caller" \
    || fail "calls answered: $n; $(cx partners tail -n 3 "$APILOG" 2>&1 | tr '\n' '|')"
bad=$(cx partners cat "$APILOG" 2>/dev/null | grep ' request ' | grep ' agent=caller ' \
    | grep -v ' status=200 ' | head -n 3 || true)
[ -z "$bad" ] && pass "no call of the caller refused by the api node (the credential matches)" \
    || fail "calls refused: $bad"
errors=$(clog | grep -c ' error key=xlab.status ' || true)
info "the caller's errors before the alias resolved: $errors ($(clog | grep ' error key=xlab.status ' \
    | sed -n 's/.* \(status=[a-z0-9]*\).*/\1/p' | sort | uniq -c | tr -s ' ' | tr '\n' ',' ))"
hang=$(clog | grep ' error key=xlab.status ' | grep -v -E ' status=(refused|timeout|[0-9]{3}) ' | head -n 1 || true)
[ -z "$hang" ] && pass "every call before the alias resolved failed honestly (refused, timeout or a status)" \
    || fail "an error of another form: $hang"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
[ -z "$left" ] && pass "nothing labelled with $GAME is left" || fail "left behind: $left"
same "the objects not belonging to the game are unchanged" "$before" "$(others)"

info "elapsed $(( $(date +%s) - started )) s"
printf '\n%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
