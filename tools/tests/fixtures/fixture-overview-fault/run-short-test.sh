#!/bin/sh
# Short test of the overview-fault fixture (v0.6 build plan, chunk 14; master
# spec 6.3, 8.5, 12.1 "The network overview"; capture W2 items 3 and 4): the
# documentation family's first fault, docs-overview-backup-claimed, planted.
# On one host, a few minutes: the bastion alone.
#
# On a copy of tools/tests/fixtures/fixture-overview-fault (bastion 0.6.0;
# its network overview the clinic's, n5 applied: machines' Backups claim the
# WAL archived to Cold Storage):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render -> deploy ->
#   load-data -> inject (a seed-file fault: nothing to run), then:
#   - the instance planted: the bastion's copy, ~/network-overview.md, gives
#     machines' Backups the answer key's handed_out lines, its true lines
#     (the "(no WAL archive)" note) on none; every other entry's Backups the
#     handout's own; the header and Your access unchanged;
#   - the same on the front's page, /docs/network-overview, machines'
#     section, behind the tools password;
#   - n5's sealed check reads present (1);
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the image built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
# Run it under the host lock (build plan, workflow deltas).
# Usage: sh tools/tests/fixtures/fixture-overview-fault/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
cd "$REPO"                          # the helpers below import tools.gm
GMCTL="python3 $REPO/tools/gmctl"
PG=overview-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-overview-short.XXXXXX")
SCN=$tmp/fixture-overview-fault
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

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
bx() { docker exec "$(ctr bastion)" "$@"; }
# web <path>: the status code from the front, inside the bastion, as the
# player OS user with the tools password; the body in $tmp/body.
web() {
    docker exec -u player "$(ctr bastion)" curl -s -m 10 -w '\n%{http_code}' \
        -u "player:$(cat "$LDIR/secrets/tools_password")" "http://localhost:8080$1" \
        > "$tmp/raw" 2>/dev/null || true
    sed '$d' "$tmp/raw" > "$tmp/body"
    tail -n 1 "$tmp/raw"
}
check() {   # check <instance>: gmctl check's exit code and line, "<code> <line>"
    set +e
    out=$($GMCTL check "$SCN" --playground "$PG" --instance "$1" 2>&1)
    rc=$?
    set -e
    printf '%s %s' "$rc" "$(printf '%s\n' "$out" | grep -m 1 "$1" || printf '%s' "$out" | head -n 1)"
}
# diff_lines <key>: n5's overview_diff item's true or handed_out lines, one per line
diff_lines() {
    python3 -c "
import sys, yaml
from tools.gm import model
item = next(i for i in yaml.safe_load(open('$SCN/gm/answer-key.yaml'))['instances']
            if i['instance'] == 'n5')['overview_diff'][0]
lines = model.register_diff_true(item) if sys.argv[1] == 'true' else item['handed_out']
print('\n'.join(lines))" "$1"
}
# backups <file>: machines' Backups items in a handout, one per line
backups() {
    awk '/^#/ { inside = ($0 == "### machines"); b = 0; next }
         inside && /^- \*\*Backups\*\*:/ { b = 1; next }
         inside && /^- / { b = 0 }
         inside && b && /^  - / { sub(/^  - /, ""); print }' "$1"
}

# --- fit, render, deploy ----------------------------------------------------
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit on the laptop playground"
else
    fail "fit"; exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
before=$(others)
$GMCTL render "$SCN" --playground "$PG" >/dev/null && pass "render" || { fail "render"; exit 1; }
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"; exit 1
fi
$GMCTL load-data "$SCN" --playground "$PG" >/dev/null && pass "load-data" || fail "load-data"
out=$($GMCTL inject "$SCN" --playground "$PG" 2>&1) && pass "inject" || fail "inject: $out"
printf '%s\n' "$out" | grep -q 'n5: seed-file fault, planted by the seed files; nothing to run' \
    && pass "inject: n5 a seed-file fault, nothing to run" || fail "inject's line for n5: $out"
i=0
until [ "$(web /docs/network-overview)" = 200 ] || [ "$i" -ge 60 ]; do sleep 2; i=$((i + 2)); done

# --- the instance planted -----------------------------------------------------
bx cat /home/player/network-overview.md > "$tmp/home.md"
same "the bastion's copy is the fixture's handout, byte for byte" "" \
    "$(cmp "$tmp/home.md" "$SCN/player/network-overview.md" 2>&1)"
same "machines' Backups in ~/network-overview.md: the answer key's handed_out lines" \
    "$(diff_lines handed_out)" "$(backups "$tmp/home.md")"
diff_lines true > "$tmp/true.txt"
diff_lines handed_out > "$tmp/handed.txt"
n=0
while IFS= read -r line; do
    grep -qxF -- "$line" "$tmp/handed.txt" && continue
    info "the true line the claim replaced: $line"
    n=$((n + $(grep -cF -- "$line" "$tmp/home.md" || true)))
done < "$tmp/true.txt"
same "the true lines the claim replaced appear nowhere in the copy" 0 "$n"
python3 - "$tmp/home.md" "$REPO/scenarios/aldermoor-centre/player/network-overview.md" \
    "$tmp/true.txt" "$tmp/handed.txt" <<'EOF' \
    && pass "the copy, machines' Backups put back to the true lines, is the clinic's handout (the time zone filled)" \
    || fail "the copy differs from the clinic's beyond the diff"
import sys
from tools.gm import model
home, clinic, true, handed = (open(p).read() for p in sys.argv[1:5])
clinic = clinic.replace(model.CUSTOMER_TIMEZONE, "UTC+1 (Etc/GMT-1)")
old = "- **Backups**:\n" + "".join(f"  - {l}\n" for l in handed.splitlines())
new = "- **Backups**:\n" + "".join(f"  - {l}\n" for l in true.splitlines())
head, sep, tail = home.partition("### machines\n")
assert tail.count(old) == 1
assert head + sep + tail.replace(old, new, 1) == clinic
EOF

code=$(web /docs/network-overview)
page=$(sed -n '/<h3 id="machines">/,/<h3 id="pms">/p' "$tmp/body")
if [ "$code" = 200 ] && printf '%s' "$page" | grep -q '<li>WAL archived to Cold Storage, segment by segment</li>' \
   && ! printf '%s' "$page" | grep -q 'no WAL archive'; then
    pass "the front's /docs/network-overview: machines' section claims the WAL archive, its note gone"
else
    fail "/docs/network-overview: $code $(printf '%s' "$page" | grep -A4 'Backups' | head -6)"
fi
code=$(docker exec -u player "$(ctr bastion)" curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/docs/network-overview)
same "the page without the tools password: 401" 401 "$code"

w=$(check n5)
case $w in "1 "*) pass "n5: sealed check present (1): ${w#1 }" ;; *) fail "n5: sealed check: [$w]" ;; esac

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
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
