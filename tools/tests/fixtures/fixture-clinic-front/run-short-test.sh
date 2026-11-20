#!/bin/sh
# Short test of the clinic-front fixture (v0.6 build plan, chunk 14; master
# spec 7.1 to 7.7, 12.1 and release gate item 4; capture W2 items 1 and 2):
# the clinic's starter pack read through the bastion's front as player. On
# one host, a few minutes: the bastion alone, no whole-clinic deployment.
#
# On a copy of tools/tests/fixtures/fixture-clinic-front (bastion 0.6.0; the
# clinic's seven handouts as handed over; its nine partners with a player
# document, on no node, admitting nothing):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render (the status file:
#   the nine partners in order, each with no incident) -> deploy, then, as
#   the player OS user with the tools password, through the front:
#   - the home: Documents linking the seven documents, Sites the nine status
#     pages by name and Reports, Tools the bastion's page;
#   - each document's page, /docs/<id>, 200, titled by its handout's first
#     heading, no placeholder left; every in-page link between the documents
#     (/docs/<id>#<anchor>, the overview's to the register and the partners'
#     page) landing on a heading id of its target page;
#   - the partners' page linking each partner's status page under its
#     heading; the bastion's brick page, /docs/bricks/bastion;
#   - each partner's status page, /status/<id>/, "Operational", no incident;
#   - a report copied into ~/reports/ as player, listed at /reports/ and
#     served with the sandbox header;
#   - every page above 401 without the password;
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the image built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
# Run it under the host lock (build plan, workflow deltas).
# Usage: sh tools/tests/fixtures/fixture-clinic-front/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
cd "$REPO"                          # the helpers below import tools.gm
GMCTL="python3 $REPO/tools/gmctl"
PG=clinic-front-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
DOCS="readme:README.md data-policy:data-policy.md issues:issues.md story:story.md"
DOCS="$DOCS partners:partners.md data-register:data-register.md network-overview:network-overview.md"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-clinic-front-short.XXXXXX")
SCN=$tmp/fixture-clinic-front
LDIR=$SCN/local/$PG
STATUS=$LDIR/secrets/partners_status.json
PAGES=$tmp/pages
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
mkdir -p "$PAGES"

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
bx() { docker exec "$(ctr bastion)" "$@"; }
px() { docker exec -u player "$(ctr bastion)" "$@"; }
# web <path> [file] [curl options]: the status code from the front, inside
# the bastion, as the player OS user with the tools password; the body in
# $tmp/body (and in <file> when given), the headers in $tmp/headers.
web() {
    p=$1; shift
    f=
    [ $# -eq 0 ] || { f=$1; shift; }
    px curl -s -m 10 -D /dev/stderr -w '\n%{http_code}' \
        -u "player:$(cat "$LDIR/secrets/tools_password")" "$@" "http://localhost:8080$p" \
        > "$tmp/raw" 2> "$tmp/headers" || true
    sed '$d' "$tmp/raw" > "$tmp/body"
    [ -z "$f" ] || cp "$tmp/body" "$f"
    tail -n 1 "$tmp/raw"
}
nopass() { px curl -s -m 10 -o /dev/null -w '%{http_code}' "http://localhost:8080$1"; }
# json <python expression over s (the status file)>
json() {
    STATUS=$STATUS python3 -c "
import json, os
s = json.load(open(os.environ['STATUS']))
print($1)"
}
partners() { json "'\n'.join(f\"{p['id']}|{p['name']}\" for p in s['partners'])"; }

# --- fit, render ----------------------------------------------------------
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit on the laptop playground"
else
    fail "fit"; exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
before=$(others)
$GMCTL render "$SCN" --playground "$PG" >/dev/null && pass "render" || { fail "render"; exit 1; }
expected=$(python3 -c "
import yaml
print(','.join(t['id'] for t in yaml.safe_load(open('$SCN/scenario.yaml'))['third_parties']))")
same "status file: the nine partners with a player document, in order" "$expected" \
    "$(json "','.join(p['id'] for p in s['partners'])")"
same "status file: no partner admits an incident (the empty status file)" "set()" \
    "$(json "set(len(p['incidents']) for p in s['partners']) - {0}")"
same "status file: each partner's anchor its player document's fragment" "True" \
    "$(SCN=$SCN json "[p['anchor'] for p in s['partners']] == [t['player_doc'].split('#')[1] for t in __import__('yaml').safe_load(open(os.environ['SCN'] + '/scenario.yaml'))['third_parties']]")"

# --- deploy -----------------------------------------------------------------
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"; exit 1
fi
last=$(partners | tail -n 1 | cut -d'|' -f1)
i=0
while [ "$i" -lt 90 ] && ! bx test -f "/run/web-front/www/status/$last/index.html" 2>/dev/null; do
    sleep 2; i=$((i + 2))
done
same "status-pages up on the bastion" "true" "$(bx /command/s6-svstat -o up /run/service/status-pages)"

# --- the home -----------------------------------------------------------------
code=$(web / "$PAGES/home.html")
same "the home: 200 as player" 200 "$code"
for d in $DOCS; do
    id=${d%%:*}
    grep -q "<li><a href=\"/docs/$id\">" "$PAGES/home.html" || fail "the home: no link to /docs/$id"
done
n=$(grep -c '<li><a href="/docs/[a-z-]*">' "$PAGES/home.html" || true)
same "the home's Documents: the seven documents" 7 "$n"
missing=$(partners | while IFS='|' read -r id name; do
    grep -qF "<li><a href=\"/status/$id/\">" "$PAGES/home.html" || printf '%s ' "$id"
done)
same "the home's Sites: one status page per partner" "" "$missing"
grep -q '<a href="/reports/">' "$PAGES/home.html" && pass "the home's Sites: Reports" || fail "the home: no Reports link"
grep -q '<a href="/docs/bricks/bastion">' "$PAGES/home.html" \
    && pass "the home's Tools: the bastion's page" || fail "the home: no /docs/bricks/bastion link"

# --- the documents --------------------------------------------------------------
for d in $DOCS; do
    id=${d%%:*}
    file=${d#*:}
    code=$(web "/docs/$id" "$PAGES/$id.html")
    title=$(sed -n '1s/^# //p' "$SCN/player/$file")
    if [ "$code" = 200 ] && python3 -c "
import html, re, sys
page = html.unescape(re.sub(r'<[^>]+>', '', open(sys.argv[1]).read()))
sys.exit(sys.argv[2] not in page)" "$PAGES/$id.html" "$title"; then
        pass "/docs/$id: 200, its first heading ($title)"
    else
        fail "/docs/$id: $code, heading [$title] not found"
    fi
    same "/docs/$id without the password: 401" 401 "$(nopass "/docs/$id")"
done
n=$(cat "$PAGES"/*.html | grep -c '{{' || true)
same "no placeholder left on any document page" 0 "$n"
python3 - "$PAGES" <<'PY' && pass "every link between the documents lands on a heading id of its page" \
    || fail "a link between the documents lands nowhere"
import re, sys
from pathlib import Path
pages = Path(sys.argv[1])
ids = {p.stem: set(re.findall(r'<h[1-6] id="([^"]+)"', p.read_text())) for p in pages.glob("*.html")}
links, dead = 0, []
for page in pages.glob("*.html"):
    for target, anchor in re.findall(r'href="/docs/([a-z-]+)#([^"]+)"', page.read_text()):
        links += 1
        if anchor not in ids.get(target, set()):
            dead.append(f"{page.stem} -> {target}#{anchor}")
print(f"{links} links between the documents; dead: {dead}")
assert links > 0 and not dead
PY
missing=$(partners | while IFS='|' read -r id name; do
    grep -qF "<a href=\"/status/$id/\">Status page</a>" "$PAGES/partners.html" || printf '%s ' "$id"
done)
same "the partners' page: a Status page link under each partner" "" "$missing"
code=$(web /docs/bricks/bastion)
grep -q '<h1' "$tmp/body" && same "/docs/bricks/bastion: 200" 200 "$code" || fail "/docs/bricks/bastion: $code"
n=$(bx sh -c 'ls /run/web-front/www/docs/bricks/' | wc -l)
same "one brick page: the bastion, the only brick" 1 "$n"

# --- the status pages -------------------------------------------------------------
bad=$(partners | while IFS='|' read -r id name; do
    code=$(web "/status/$id/")
    if [ "$code" = 200 ] && grep -q '<strong>Operational</strong>' "$tmp/body" \
       && grep -q 'No incident reported' "$tmp/body"; then
        :
    else
        printf '%s(%s) ' "$id" "$code"
    fi
    [ "$(nopass "/status/$id/")" = 401 ] || printf '%s(no 401) ' "$id"
done)
same "each partner's status page: 200, Operational, no incident; 401 without the password" "" "$bad"

# --- a report ------------------------------------------------------------------------
printf '<!DOCTYPE html><html><head><title>pgBadger records</title></head><body><h1>pgBadger report</h1></body></html>\n' \
    | docker exec -i -u player "$(ctr bastion)" sh -c 'cat > ~/reports/pgbadger-records.html'
code=$(web /reports/)
grep -q 'href="pgbadger-records.html"' "$tmp/body" && same "/reports/ lists the copied report" 200 "$code" \
    || fail "/reports/: $code $(cat "$tmp/body")"
code=$(web /reports/pgbadger-records.html)
if [ "$code" = 200 ] && grep -q 'pgBadger report' "$tmp/body" \
   && grep -qi '^content-security-policy: sandbox allow-scripts' "$tmp/headers"; then
    pass "the report served with the sandbox header"
else
    fail "the report: $code $(cat "$tmp/headers")"
fi
same "/reports/ without the password: 401" 401 "$(nopass /reports/)"

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
