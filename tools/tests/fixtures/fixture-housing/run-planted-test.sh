#!/bin/sh
# Short test of a fault planted on the housing fixture (v0.5 build plan
# chunk 25; master spec 6.3, 17.2, 17.3 s9, 18.1; capture W3 item 3, W5
# items 0 and 4, W5-d, of specs/versions/v0.5/wave-log.md): planted on a
# copy of tools/tests/fixtures/fixture-housing from its overlay,
# planted/<fault-id>/ (tools/tests/planted.py: the fault instance appended to
# scenario.yaml, its answer-key entry, its seed changes in the scenario layer
# compose/ward/), then `gmctl compose` on the copy; the fixture's committed
# files stay unfaulted. On one host, under 30 minutes with the deployment.
#
#   compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over 8 to 9
#   hours ahead; T0 at any hour: the displays read around the clock) ->
#   deploy -> load-data -> inject (s9 a seed-file fault: nothing runs) ->
#   start-load (T0), then, time placed, never waited for:
#
#   scheduler-display-refresh-loop (s9, about 15 minutes):
#   - present: the board statement's calls well above 64 a minute in
#     pg_stat_statements (about 124), one queryid, from ward as
#     vet_display; gmctl check reads s9 present;
#   - the unit's parameter logged for vet_display alone (ALTER ROLE ... SET
#     log_min_duration_statement = 0, its pooled sessions terminated so the
#     pool reconnects with it): unit 7 about once a second, at least five
#     times as often as any other unit (the displays' reads pick a unit at
#     random, about once a minute each on average; each call's parameter is
#     logged on its bind and its execute lines); no instance-wide setting;
#     the role's setting reset after;
#   - reported: the chain from the parameter to the unit, its display's
#     serial (display 65, the unit's replaced one) and the animal;
#   - cleared, by the test only (never in play, master spec 6.3): ward
#     redeployed with the unfaulted seed (its rendered schedule.yaml without
#     the loop's stream, a new config, `docker service update`), the program
#     resuming its load (the load marker kept); the calls back to about 64 a
#     minute; gmctl check reads s9 fixed;
#
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-housing/run-planted-test.sh <fault-id>
#   <fault-id>: scheduler-display-refresh-loop
set -eu

FAULT=${1:-}
case $FAULT in
    scheduler-display-refresh-loop) INST=s9 UNIT=7 ;;
    *) echo "usage: sh $0 scheduler-display-refresh-loop" >&2; exit 2 ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=housing-planted
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
BOARD="SELECT * FROM housing_unit_board WHERE unit_id = \$1"
SAMPLE=120           # seconds between two reads of the board's calls
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

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of $0)" >&2; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-housing-planted.XXXXXX")
SCN=$tmp/fixture-housing
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

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
nstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
# The board statement's calls in clinic and the moment, "<calls> <epoch>".
calls() { dbsql postgres "SELECT coalesce(sum(s.calls), 0) || ' ' || extract(epoch FROM clock_timestamp())::numeric(20, 3)
  FROM pg_stat_statements s JOIN pg_database d ON d.oid = s.dbid WHERE d.datname = 'clinic' AND s.query = '$BOARD'"; }
# The calls a minute over SAMPLE seconds.
rate() {
    a=$(calls); sleep "$SAMPLE"; b=$(calls)
    python3 -c 'import sys; a, b = sys.argv[1].split(), sys.argv[2].split()
print(round((int(b[0]) - int(a[0])) * 60 / (float(b[1]) - float(a[1])), 1))' "$a" "$b"
}
# The fault's sealed check, as the GM runs it: prints "<exit> <its line>".
fcheck() {
    set +e
    out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | grep "^$INST " | head -n 1)"
}
wait_running() {   # wait_running <node>: up to 90 s for the program to run
    i=0
    while [ "$i" -lt 90 ]; do
        case "$(nstatus "$1")" in running\ *) return 0 ;; esac
        sleep 3; i=$((i + 3))
    done
    return 1
}

# --- the copy, planted -----------------------------------------------------
cp -R "$HERE" "$SCN"
rm -f "$SCN"/run-*.sh
python3 "$REPO/tools/tests/planted.py" "$SCN" "$HERE/planted/$FAULT"
$GMCTL compose "$SCN" >/dev/null
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "planted $INST ($FAULT) from planted/$FAULT/ on a copy, composed: nodes/ as compose writes them"
else
    fail "compose --check on the planted copy"
fi
same "the planted copy: f1 and $INST" "f1 $INST" \
    "$(python3 -c "import sys, yaml; print(' '.join(i['id'] for i in yaml.safe_load(open(sys.argv[1]))['fault_instances']))" "$SCN/scenario.yaml")"
same "the planted copy: ward's loop, ward.board's SQL byte for byte, unit $UNIT, on ward-board at 3600/h" \
    "True [$UNIT, $UNIT] ward-board 3600/h" \
    "$(python3 -c "import sys, yaml
q = yaml.safe_load(open(sys.argv[1] + '/queries.yaml'))['queries']; s = yaml.safe_load(open(sys.argv[1] + '/schedule.yaml'))
st = [x for x in s['streams'] if x['key'] == 'ward.board-loop'][0]
print(q['ward.board-loop']['sql'] == q['ward.board']['sql'], q['ward.board-loop']['params']['unit']['int'], st['connection'], st['rate'])" "$SCN/nodes/ward")"

# --- local implementation and deployment -------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the five nodes fit 2 CPU / 4G / 8G"
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
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
same "render planted $INST: ward's seed schedule streams ward.board-loop" "1" \
    "$(docker exec -u root "$(ctr ward)" grep -c 'key: ward.board-loop' /opt/gm/seed/schedule.yaml || true)"
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: the core and housing, the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject ($INST a seed-file fault: nothing runs)" || fail "inject"
dbsql postgres "CREATE EXTENSION IF NOT EXISTS pg_stat_statements" >/dev/null
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
wait_running ward && pass "ward running: $(nstatus ward)" || fail "ward not running: [$(nstatus ward)]"
sleep 30

# --- present ---------------------------------------------------------------------
r=$(rate)
if python3 -c "import sys; sys.exit(not $r >= 100)"; then
    pass "present: the board statement's calls well above 64 a minute ($r a minute over $SAMPLE s)"
else
    fail "present: the board statement's calls $r a minute, not well above 64"
fi
same "present: one queryid, run by vet_display from ward" "1 ward" \
    "$(dbsql postgres "SELECT count(DISTINCT s.queryid) FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
                        WHERE r.rolname = 'vet_display' AND s.query = '$BOARD'") $(dbsql postgres "SELECT string_agg(DISTINCT application_name, ',')
                        FROM pg_stat_activity WHERE usename = 'vet_display' AND datname = 'clinic'")"
r=$(fcheck)
case $r in "1 "*) pass "gmctl check: $INST present (${r#* })" ;; *) fail "gmctl check while the loop runs: $r" ;; esac

# --- the unit's parameter, logged for vet_display alone --------------------------
dbsql postgres "ALTER ROLE vet_display SET log_min_duration_statement = 0" >/dev/null
dbsql postgres "SELECT count(pg_terminate_backend(pid)) FROM pg_stat_activity WHERE usename = 'vet_display'" >/dev/null
same "the setting for vet_display alone: no instance-wide change" "vet_display:log_min_duration_statement=0 100ms" \
    "$(dbsql postgres "SELECT string_agg(r.rolname || ':' || array_to_string(s.setconfig, ','), ' ') FROM pg_db_role_setting s
                        JOIN pg_roles r ON r.oid = s.setrole WHERE s.setconfig::text LIKE '%log_min_duration_statement%'") $(dbsql postgres "SHOW log_min_duration_statement")"
sleep 75
params=$(docker exec -u root "$(ctr records)" sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null \
    | sed -n "s/.*user=vet_display,db=clinic.*Parameters: \$1 = '\([0-9]*\)'.*/\1/p" | sort | uniq -c | sort -rn)
top=$(printf '%s\n' "$params" | awk 'NR == 1 {print $2 " " $1}')
others=$(printf '%s\n' "$params" | awk 'NR > 1 {n++; if ($1 > m) m = $1} END {print n + 0 " " m + 0}')
info "logged parameters (count unit): $(printf '%s\n' "$params" | head -n 5 | tr -s ' ' | tr '\n' ';')"
set -- $top
TOP_UNIT=${1:-} TOP_N=${2:-0}
set -- $others
if [ "$TOP_UNIT" = "$UNIT" ] && [ "$TOP_N" -ge 30 ] && [ "$TOP_N" -ge $(( 5 * ${2:-0} )) ]; then
    pass "the unit's parameter logged for vet_display: unit $UNIT $TOP_N times, $1 other units at most ${2:-0} times each"
else
    fail "the logged parameters do not single out unit $UNIT: top [$top], others [$others]"
fi
dbsql postgres "ALTER ROLE vet_display RESET log_min_duration_statement" >/dev/null
same "the role's setting reset: no logging left behind" "" \
    "$(dbsql postgres "SELECT string_agg(array_to_string(setconfig, ','), ' ') FROM pg_db_role_setting WHERE setconfig::text LIKE '%log_min_duration_statement%'")"

# --- reported: the chain ----------------------------------------------------------
chain=$(dbsql clinic "SELECT d.id || '|' || d.serial || '|' || coalesce(p.stay_id::text, '') || '|' || coalesce(a.id::text, '') || '|' || coalesce(a.name, '')
  FROM housing_displays d
  LEFT JOIN housing_placements p ON p.unit_id = d.unit_id AND p.until_at IS NULL
  LEFT JOIN stays s ON s.id = p.stay_id LEFT JOIN animals a ON a.id = s.animal_id
 WHERE d.unit_id = $UNIT AND d.removed_on IS NULL")
info "the chain: unit $UNIT -> display|serial|stay|animal|name: $chain"
case $chain in
    65\|?*\|?*\|?*\|?*) pass "reported: unit $UNIT -> display 65 (its open row; display $UNIT removed), serial ${chain#*|}" ;;
    *) fail "reported: the chain from unit $UNIT does not reach a display and an animal: [$chain]" ;;
esac

# --- cleared, by the test only ------------------------------------------------------
# ward redeployed with the unfaulted seed: the rendered schedule.yaml without
# the loop's stream (its seed and shapes as rendered), a new config labelled
# with the game, swapped in by `docker service update` (the task restarts;
# the load marker on its volume keeps it running).
OLDCFG=${GAME}_ward_schedule.yaml
NEWCFG=${GAME}_ward_schedule.yaml-cleared
python3 - "$LDIR/rendered/ward/schedule.yaml" "$tmp/schedule-cleared.yaml" <<'EOF'
import sys, yaml
s = yaml.safe_load(open(sys.argv[1]))
s["streams"] = [x for x in s["streams"] if x["key"] != "ward.board-loop"]
open(sys.argv[2], "w").write(yaml.safe_dump(s, sort_keys=False))
EOF
docker config create --label "com.docker.stack.namespace=$GAME" --label "dbagm.game=$GAME" \
    "$NEWCFG" "$tmp/schedule-cleared.yaml" >/dev/null
CLEARED_AT=$(date +%s)
docker service update -q --config-rm "$OLDCFG" \
    --config-add "source=$NEWCFG,target=/opt/gm/seed/schedule.yaml,uid=0,gid=0,mode=0400" "${GAME}_ward" >/dev/null \
    && pass "cleared: ward redeployed with its seed schedule without the loop's stream" \
    || fail "cleared: docker service update refused"
wait_running ward && pass "ward running again ($(( $(date +%s) - CLEARED_AT )) s): $(nstatus ward)" || fail "ward not running after the redeploy: [$(nstatus ward)]"
same "cleared: ward's seed schedule streams no loop" "0" \
    "$(docker exec -u root "$(ctr ward)" grep -c 'key: ward.board-loop' /opt/gm/seed/schedule.yaml || true)"
sleep 30
r=$(rate)
if python3 -c "import sys; sys.exit(not 54 <= $r <= 74)"; then
    pass "cleared: the board statement's calls back to about 64 a minute ($r a minute over $SAMPLE s)"
else
    fail "cleared: the board statement's calls $r a minute, not about 64"
fi
r=$(fcheck)
case $r in "0 "*) pass "gmctl check: $INST fixed (${r#* })" ;; *) fail "gmctl check after the clearing: $r" ;; esac

# --- teardown ------------------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    left=$(labelled)
    same "teardown: nothing labelled with game $GAME left" "" "$left"
else
    fail "teardown"
fi

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
