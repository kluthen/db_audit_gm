#!/bin/sh
# Short test of the false alarm fa on the send-outs fixture (v0.5 build plan
# chunk 22; master spec 17.2, 17.3 fa; capture W5 item 1 and W5-h (c) of
# specs/versions/v0.5/wave-log.md; spec D459): the fixture's issue I1, "the
# external lab is slow", covering no fault, explained by its answer key's
# false_alarms: entry. No fault is planted: the fixture is deployed as
# committed. On one host, about 5 minutes after the deployment and the load.
#
#   compose --check -> fit (the loader accepts I1 as a false alarm: covers
#   [], expected report, its false_alarms: entry) -> render (any hour: no job
#   is waited for) -> deploy -> load-data, then:
#   - the starter pack: the bastion's ~/issues.md carries the complaint;
#   - the check, as a player from the bastion (psql -h lab as dba, the
#     answer key's query): the small-animal PCR panel (PCRSA, 96 hours)
#     answered on its fourth day after it was sent, within its turnaround
#     (answered_at before due_by, packed plus 50 minutes plus the
#     turnaround); one of the load's, or, when the load holds none, one
#     placed by the test (an answered panel's answer moved to its fourth
#     day, before its due_by);
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas); it needs no host minute.
# Usage: sh tools/tests/fixtures/fixture-send-outs/run-false-alarm-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=sendouts-fa
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.4.0"
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

labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}

[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of $0)" >&2; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-sendouts-fa.XXXXXX")
SCN=$tmp/fixture-send-outs
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
rm -f "$SCN"/run-*.sh

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2" -c "$3"; }
# As the player on the bastion, psql to lab as dba (~/.pgpass).
player_lab() { docker exec -u player "$(ctr bastion)" psql -h lab -U dba -d lab -XAtq -v ON_ERROR_STOP=1 -c "$1"; }

# The answer key's query (gm/answer-key.yaml, false_alarms I1): the panels
# answered on their fourth day after they were sent, in time or not.
FA_QUERY="SELECT s.id, x.code, x.turnaround_hours, floor(extract(epoch FROM s.answered_at - s.sent_at) / 86400)::integer + 1,
                 s.answered_at <= s.due_by
            FROM lab_send_outs s JOIN lab_order_tests t ON t.id = s.order_test_id JOIN lab_tests x ON x.id = t.test_id
           WHERE x.code = 'PCRSA' AND s.answered_at >= s.sent_at + interval '3 days'
             AND s.answered_at < s.sent_at + interval '4 days'
           ORDER BY s.answered_at DESC LIMIT 10"

# --- the scenario: the loader accepts the false alarm -------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/ as compose writes them"
else
    fail "compose --check"
fi
same "the scenario: I1 covers no fault, expects report, explained by false_alarms; one fault instance (f1), difficulty 1" \
    "I1 [] report I1 f1 1" \
    "$(python3 - "$SCN" <<'EOF'
import sys, yaml
s = yaml.safe_load(open(sys.argv[1] + "/scenario.yaml"))
k = yaml.safe_load(open(sys.argv[1] + "/gm/answer-key.yaml"))
i = s["issues"][0]
print(i["id"], i["covers"], i["expected_resolution"], " ".join(a["issue"] for a in k["false_alarms"]),
      " ".join(f["id"] for f in s["fault_instances"]), s["difficulty"]["score"])
EOF
)"
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the loader accepts I1 as a false alarm; the eight nodes fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy: the eight nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: the core, the lab, the partners, the purposes' DDL, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
checked=$(date +%s)

# --- the starter pack ----------------------------------------------------------
same "the starter pack: the bastion's ~/issues.md carries I1's complaint" "1" \
    "$(docker exec -u player "$(ctr bastion)" grep -c 'The external lab is slow' /home/player/issues.md || true)"

# --- fa's check -----------------------------------------------------------------
rows=$(player_lab "$FA_QUERY")
if [ -z "$rows" ]; then
    info "the load holds no panel answered on its fourth day: one placed, as a send-out answered then"
    dbsql lab lab "UPDATE lab_send_outs SET answered_at = sent_at + interval '3 days 12 hours'
                    WHERE id = (SELECT s.id FROM lab_send_outs s JOIN lab_order_tests t ON t.id = s.order_test_id
                                  JOIN lab_tests x ON x.id = t.test_id
                                 WHERE x.code = 'PCRSA' AND s.answered_at IS NOT NULL
                                   AND s.due_by >= s.sent_at + interval '3 days 12 hours'
                                 ORDER BY s.answered_at DESC LIMIT 1)" >/dev/null
    rows=$(player_lab "$FA_QUERY")
else
    info "the load's panels answered on their fourth day (the latest ten): $(printf '%s\n' "$rows" | wc -l), in time: $(printf '%s\n' "$rows" | grep -c '|t$' || true)"
fi
first=$(printf '%s\n' "$rows" | grep '|t$' | head -n 1)
info "the panel read: send-out $(echo "$first" | cut -d'|' -f1), $(echo "$first" | cut -d'|' -f2), turnaround $(echo "$first" | cut -d'|' -f3) h"
same "fa: the panel answered on its fourth day, within its 96-hour turnaround (answered_at <= due_by), read as dba from the bastion" \
    "PCRSA|96|4|t" "$(echo "$first" | cut -d'|' -f2-5)"
info "the send-outs answered after their due time: $(player_lab "SELECT count(*) FILTER (WHERE answered_at > due_by) || ' of ' || count(*) FROM lab_send_outs WHERE answered_at IS NOT NULL")"
info "fa's reading took $(( $(date +%s) - checked )) s"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
same "teardown: nothing labelled with $GAME left" "" "$left"

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
