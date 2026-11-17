#!/bin/sh
# Short test of the status fixture (v0.6 build plan, chunk 6b; master spec
# 7.6, 12.1; capture W2 items 1 and 2): the partners' status pages. On one
# host, about ten minutes.
#
# On a copy of tools/tests/fixtures/fixture-status (bastion 0.6.0; the
# partners' three shared nodes under alpha-lab and beta-lab, both with a
# player document; alpha-lab admits f1 from T0 and f2 from handover-2h,
# beta-lab nothing):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render (the hand-over
#   the whole hour three hours ahead) -> deploy, then:
#   - render's status file: alpha-lab's two incidents, f1 at the render
#     time (T0), f2 two hours before the planned hand-over, in start order;
#     beta-lab with none; 0600 in the 0700 secrets folder; mounted on the
#     bastion alone, root, 0400;
#   - f2's start placed a few minutes ahead (the hand-over is a whole hour:
#     the test places the instant in the file before deploy, never waits
#     hours for it);
#   - on the bastion: alpha-lab's page "Incident ongoing" with f1 only,
#     beta-lab's "Operational"; the home's Sites linking both by name; the
#     partners' page linking each partner's status page under its heading;
#     every page behind the tools password; /status/<unknown>/ 404; the
#     pages root:www-data 0440; the status file unreadable by player; the
#     front's configuration without any route (no proxy_pass, no third
#     party's node or hostname);
#   - once f2's start passes, alpha-lab's page shows it too, newest first;
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-status/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=status-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.4.0 127.0.0.1:5000/dbagm/postgres:0.5.1"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-status-short.XXXXXX")
SCN=$tmp/fixture-status
LDIR=$SCN/local/$PG
STATUS=$LDIR/secrets/partners_status.json
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
# web <path> [curl options]: the status code from the front, inside the
# bastion, with the tools password; the body in /run/tmp/b there.
web() {
    p=$1; shift
    bx curl -s -m 10 -o /run/tmp/b -w '%{http_code}' -u "player:$(cat "$LDIR/secrets/tools_password")" \
        "$@" "http://localhost:8080$p" 2>/dev/null
}
body() { bx cat /run/tmp/b; }
# json <python expression over s (the status file) and t (the timeline)>
json() {
    STATUS=$STATUS IMPL=$LDIR/implementation.yaml python3 -c "
import json, os, yaml
s = json.load(open(os.environ['STATUS']))
t = yaml.safe_load(open(os.environ['IMPL']))['timeline']
print($1)"
}

# --- fit, render ----------------------------------------------------------
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit on the laptop playground"
else
    fail "fit"; exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
before=$(others)
HANDOVER=$(date -u -d '+3 hours' +%Y-%m-%dT%H:00Z)
info "render: planned hand-over $HANDOVER"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
same "status file: the partners with a player document, in order" "alpha-lab,beta-lab" \
    "$(json "','.join(p['id'] for p in s['partners'])")"
same "status file: alpha-lab's anchor in the partners' page" "alpha-laboratories" \
    "$(json "s['partners'][0]['anchor']")"
F2_PLANNED=$(python3 -c "
import datetime
h = datetime.datetime.strptime('$HANDOVER', '%Y-%m-%dT%H:%MZ')
print((h - datetime.timedelta(hours=2)).strftime('%Y-%m-%dT%H:%M:%SZ'))")
same "status file: f1 (T0) at the render time, f2 at the planned hand-over less 2 h ($F2_PLANNED), in start order" \
    "True" "$(json "[(i['instance'], i['start'], i['end']) for i in s['partners'][0]['incidents']] == [('f1', t['rendered_at'], None), ('f2', '$F2_PLANNED', None)]")"
same "status file: beta-lab admits nothing" "[]" "$(json "s['partners'][1]['incidents']")"
same "status file 0600 in the 0700 secrets folder" "600 700" \
    "$(stat -c %a "$STATUS") $(stat -c %a "$(dirname "$STATUS")")"
m=$(python3 -c "
import yaml, sys
s = yaml.safe_load(open('$LDIR/stack.yml'))['services']
out = [(n, m['target'], m['uid'], m['gid'], oct(m['mode'])) for n, svc in s.items()
       for m in svc.get('secrets', []) if m['source'] == '${GAME}_partners_status']
print(out)")
same "the status file mounted on the bastion alone, root, 0400" \
    "[('bastion', '/opt/gm/secrets/partners_status.json', '0', '0', '0o400')]" "$m"

# --- f2's start placed a few minutes ahead ----------------------------------
F2_AT=$(date -u -d '+6 minutes' +%Y-%m-%dT%H:%M:%SZ)
STATUS=$STATUS F2_AT=$F2_AT python3 -c "
import json, os
p = os.environ['STATUS']
s = json.load(open(p))
for i in s['partners'][0]['incidents']:
    if i['instance'] == 'f2':
        i['start'] = os.environ['F2_AT']
json.dump(s, open(p, 'w'), indent=1)"
info "f2's start placed at $F2_AT"

# --- deploy -----------------------------------------------------------------
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy"
else
    fail "deploy"; exit 1
fi
i=0
while [ "$i" -lt 90 ] && ! bx test -f /run/web-front/www/status/beta-lab/index.html; do
    sleep 2; i=$((i + 2))
done
same "status-pages up on the bastion" "true" "$(bx /command/s6-svstat -o up /run/service/status-pages)"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
[ "$now" \< "$F2_AT" ] || fail "deploy ended after f2's placed start ($now >= $F2_AT): the check below is moot"
code=$(web /status/alpha-lab/)
b=$(body)
if [ "$code" = 200 ] && printf '%s' "$b" | grep -q '<strong>Incident ongoing</strong>' \
   && printf '%s' "$b" | grep -q '<h3>Slow status answers</h3>' \
   && ! printf '%s' "$b" | grep -q 'Planned maintenance'; then
    pass "alpha-lab: Incident ongoing, the started incident (f1) only, f2 not yet started absent"
else
    fail "alpha-lab's page: $code $b"
fi
printf '%s' "$b" | grep -q "<p>Started $(json "t['rendered_at'][:16].replace('T', ' ')") UTC.</p>" \
    && pass "f1's start in UTC, the render time" || fail "f1's start: $b"
code=$(web /status/beta-lab/)
b=$(body)
if [ "$code" = 200 ] && printf '%s' "$b" | grep -q '<strong>Operational</strong>' \
   && printf '%s' "$b" | grep -q 'No incident reported' && printf '%s' "$b" | grep -q '<h1>Beta Laboratories</h1>'; then
    pass "beta-lab: Operational, no incident"
else
    fail "beta-lab's page: $code $b"
fi
same "/status/beta-lab redirects to /status/beta-lab/" 301 "$(web /status/beta-lab)"
code=$(web /)
b=$(body)
printf '%s' "$b" | grep -q '<li><a href="/status/alpha-lab/">Alpha Laboratories</a></li>' \
    && printf '%s' "$b" | grep -q '<li><a href="/status/beta-lab/">Beta Laboratories</a></li>' \
    && printf '%s' "$b" | sed -n '/<section id="sites">/,/<\/section>/p' | grep -q '/status/beta-lab/' \
    && pass "the home's Sites: one status page per partner, by its name" || fail "the home: $code $b"
code=$(web /docs/partners)
b=$(body)
printf '%s' "$b" | grep -A1 '<h2 id="alpha-laboratories">' | grep -q '<a href="/status/alpha-lab/">Status page</a>' \
    && printf '%s' "$b" | grep -A1 '<h2 id="beta-laboratories">' | grep -q '<a href="/status/beta-lab/">Status page</a>' \
    && pass "the partners' page links each partner's status page under its heading" \
    || fail "/docs/partners: $code $b"
code=$(bx curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/status/alpha-lab/)
same "a status page without the tools password: 401" 401 "$code"
same "a status page for an unknown partner: 404" 404 "$(web /status/gamma-lab/)"
same "a status page's files: root:www-data, 0750 and 0440" "750 root:www-data 440 root:www-data" \
    "$(bx stat -c '%a %U:%G' /run/web-front/www/status/alpha-lab /run/web-front/www/status/alpha-lab/index.html | tr '\n' ' ' | sed 's/ $//')"
same "the status file: root, 0400" "400 root:root" \
    "$(bx stat -c '%a %U:%G' /opt/gm/secrets/partners_status.json)"
if docker exec -u player "$(ctr bastion)" cat /opt/gm/secrets/partners_status.json >/dev/null 2>&1; then
    fail "player reads the status file"
else
    pass "the status file is unreadable by player"
fi
conf=$(bx cat /run/web-front/nginx.conf)
n=$(printf '%s\n' "$conf" | grep -c 'proxy_pass' || true)
t=$(printf '%s\n' "$conf" | grep -c -e partners-api -e partners-backend -e partners-db -e alpha-lab -e beta-lab || true)
same "the front's configuration: no proxy_pass, no third party's node or hostname" "0 0" "$n $t"

# --- f2's start passes ---------------------------------------------------------
info "waiting for f2's start ($F2_AT) and the next page"
deadline=$(( $(date -u -d "$F2_AT" +%s) + 90 ))
shown=no
while [ "$(date -u +%s)" -lt "$deadline" ]; do
    web /status/alpha-lab/ >/dev/null
    if body | grep -q '<h3>Planned maintenance of our database</h3>'; then shown=yes; break; fi
    sleep 5
done
b=$(body)
if [ "$shown" = yes ]; then
    pass "f2 shown once its start passed ($(date -u +%H:%M:%S), start $F2_AT)"
else
    fail "f2 not shown by $(date -u -d "@$deadline" +%H:%M:%S): $b"
fi
order=$(printf '%s' "$b" | sed -n 's/^<h3>\(.*\)<\/h3>$/\1/p' | tr '\n' '|')
same "alpha-lab's incidents newest first" "Planned maintenance of our database|Slow status answers|" "$order"
printf '%s' "$b" | grep -q '<strong>Incident ongoing</strong>' \
    && pass "alpha-lab still Incident ongoing" || fail "alpha-lab's state: $b"

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
