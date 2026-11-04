#!/bin/sh
# Short test of the housing fixture (v0.5 build plan, chunk 14; master spec
# 9.5; vet-housing-domain.md, "Testing"; capture W3 item 3): vet-core's record
# and vet-housing's wards loaded by gmctl load-data from the domains (the
# core's schema, keys.sql and load, then housing's schema, keys.sql and load,
# then the coherence check), the practice software, pms, the ward service,
# ward, and the lookup API, clinic-api, composed by gmctl compose from the
# domains' producers. Two runs, each on one host in under 30 minutes:
#
#   place  T0 placed at 10:00 local (10:00-10:59, the discharges' hours):
#          the load and the board, then a new stay placed within minutes,
#          an ended one released (its unit to clean, its plans ended), the
#          ward's disinfections waiting their 30 minutes;
#   care   T0 placed just before 17:00 local (16:00-16:59): the load and the
#          board, then the round's feedings recorded, a nil-by-mouth animal
#          skipped, the care log's pace.
#
# Time is placed by the shift (whole hours), so the local minute at T0 is
# the UTC minute, about four minutes after the start: place started at
# minute 30 to 50 of an hour puts T0 at about 10:35-10:55, when units the
# history released after 10:00 reach their 30 minutes to clean by the
# ward's first disinfection call; care started at minute 40 to 50 puts T0 at
# about 16:45-16:55, so the 17:00 round, and the first nil-by-mouth orders
# (from the next hour) it meets, fall in the window. Started at another
# minute, the checks needing those moments are reported as not reached
# (....), never failed.
#
# On a copy of tools/tests/fixtures/fixture-housing (bastion 0.5.0, records:
# postgres 0.5.0, clinic-api: api 0.1.0, pms and ward: scheduler 0.3.0 at
# intensity 1.0, domains: vet-core and vet-housing at records/clinic):
#   compose --check -> vet-housing at another database refused (lands_with)
#   -> fit (the laptop playground, 2 CPU / 4G / 8G) -> render (the shift
#   placing T0) -> deploy -> load-data (its time and size), then:
#   - the stack file: housing_app's and vet_app's passwords on pms only,
#     vet_display's and housing_ward's on ward only, none on the bastion or
#     records;
#   - load-data: the coherence check passed (three checks); housing's rows;
#     every login role with a SCRAM password; the wards at T0 (every current
#     stay placed once, none open on an ended stay, no unit holding two,
#     every stay of the year placed); no key function left in the catalog;
#   - the board as vet_display: one row per unit, an occupied unit's with
#     its animal, no owner, contact or natural identifier, no grant beyond
#     the two boards;
#   - inject -> start-load (T0), then the run's window: the board's calls
#     about 64 a minute from ward (one statement, one queryid, ward's pooled
#     sessions), and the run's own checks; pms and ward without an error;
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
# Usage: sh tools/tests/fixtures/fixture-housing/run-short-test.sh place|care
set -eu

MODE=${1:-}
case $MODE in
    place) TARGET_HOUR=10 ;;
    care) TARGET_HOUR=16 ;;
    *) echo "usage: $0 place|care" >&2; exit 2 ;;
esac
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=housing-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SETUP=240            # seconds from now to T0, about: fit, render, deploy, load-data
WINDOW=1200          # seconds of load after T0, at most
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-housing-short.XXXXXX")
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

cp -R "$HERE" "$SCN"
rm -f "$SCN/run-short-test.sh"

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
nlog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
nstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }

# --- composition and the landing ----------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/, nodes/pms/ and nodes/ward/ as compose writes them from the domains"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi
refused=$(cd "$REPO" && python3 - "$SCN" "$tmp/elsewhere" <<'EOF'
import shutil, sys
from tools.gm import model
src, dst = sys.argv[1], sys.argv[2]
shutil.copytree(src, dst)
for name, old, new in (("scenario.yaml", "  - id: vet-housing\n    at: records/clinic\n",
                        "  - id: vet-housing\n    at: records/wards\n"),
                       ("composition.yaml", "{id: vet-housing, at: records/clinic",
                        "{id: vet-housing, at: records/wards")):
    text = open(f"{dst}/{name}").read()
    assert old in text, name
    open(f"{dst}/{name}", "w").write(text.replace(old, new))
try:
    model.load_scenario(dst)
    print("accepted")
except model.GmError as exc:
    print(" | ".join(getattr(exc, "missing", None) or [str(exc)]))
EOF
)
case $refused in
    *"vet-housing lands_with vet-core, whose at: is records/clinic"*)
        pass "lands_with: vet-housing at records/wards refused ($refused)" ;;
    *) fail "lands_with: vet-housing at records/wards not refused: [$refused]" ;;
esac

# --- local implementation; T0 placed by the shift ------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the five nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# The shift that puts T0 (about SETUP seconds from now) in TARGET_HOUR local,
# and the next hand-over moment that shift makes the designed 14:00.
set -- $(python3 - "$TARGET_HOUR" "$SETUP" <<'EOF'
import datetime, sys
target, setup = int(sys.argv[1]), int(sys.argv[2])
now = datetime.datetime.now(datetime.timezone.utc)
t0 = now + datetime.timedelta(seconds=setup)
shift = (target - t0.hour + 11) % 24 - 11          # -11..12, render's compute_shift
moment = now.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=9)   # past the 8h aging floor
while (moment.hour + shift) % 24 != 14:
    moment += datetime.timedelta(hours=1)
print(moment.strftime("%Y-%m-%dT%H:00Z"), shift, (t0 + datetime.timedelta(hours=shift)).strftime("%H:%M"))
EOF
)
HANDOVER=$1 SHIFT=$2 LOCAL_T0=$3
info "mode $MODE: render --handover $HANDOVER, shift $SHIFT: T0 expected about $LOCAL_T0 local"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "clinic-api", "pms", "ward"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
same "stack: vet_lookup's password and clinic_lookup on clinic-api" \
    "clinic-api http_clinic_lookup role_vet_lookup_password" "$(printf '%s\n' "$st" | sed -n 3p)"
same "stack: housing_app's and vet_app's passwords on pms" \
    "pms role_housing_app_password role_vet_app_password" "$(printf '%s\n' "$st" | sed -n 4p)"
same "stack: housing_ward's and vet_display's passwords on ward" \
    "ward role_housing_ward_password role_vet_display_password" "$(printf '%s\n' "$st" | sed -n 5p)"
same "stack: none on the bastion" "bastion -" "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: none on records (load-data sets the roles' passwords)" "records -" \
    "$(printf '%s\n' "$st" | sed -n 2p)"

# --- deployment and load-data ----------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
for n in pms ward; do
    case $(nstatus $n) in idle\ *) pass "$n idle before the load: $(nstatus $n)" ;;
        *) fail "$n before the load: [$(nstatus $n)]" ;; esac
done

info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core and the wards loaded, coherence checked ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: the coherence check passed, its three checks" "pass: placements-on-stays:pass stays-placed:pass units-hold-one:pass" \
    "$(python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])).get("coherence") or {}
print(f"{c.get('result')}: " + " ".join(f"{k.get('check')}:{k.get('result')}" for k in c.get("checks") or []))
EOF
)"
rows=$(dbsql clinic "SELECT (SELECT count(*) FROM housing_units) || ' ' || (SELECT count(*) FROM housing_displays) || ' '
  || (SELECT count(*) FROM housing_placements) || ' ' || (SELECT count(*) FROM housing_feeding_plans) || ' '
  || (SELECT count(*) FROM housing_care_events)")
info "housing rows: units displays placements plans care events: $rows"
info "size: housing $(dbsql clinic "SELECT pg_size_pretty(sum(pg_total_relation_size(oid))) FROM pg_class
  WHERE relname LIKE 'housing\_%' AND relkind = 'r'"), clinic $(dbsql clinic "SELECT pg_size_pretty(pg_database_size('clinic'))")"
same "load-data: 64 units and 66 displays" "64 66" "$(echo "$rows" | cut -d' ' -f1-2)"
same "load-data: every login role has a SCRAM password" \
    "housing_app:true housing_ward:true vet_app:true vet_display:true vet_lookup:true vet_reports:true" \
    "$(dbsql postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%'), ' ' ORDER BY rolname)
                       FROM pg_authid WHERE rolname LIKE 'vet\_%' OR rolname LIKE 'housing\_%'")"
same "load-data: no key function left in the catalog" "0" \
    "$(dbsql clinic "SELECT count(*) FROM pg_proc WHERE proname LIKE 'core\_%' OR proname LIKE 'vc\_%' OR proname LIKE 'housing\_%'")"
same "the wards at T0: every current stay placed once, none open on an ended stay, no unit holding two, every stay placed" \
    "0 0 0 0" "$(dbsql clinic "SELECT
  (SELECT count(*) FROM stays s WHERE s.discharged_at IS NULL
      AND (SELECT count(*) FROM housing_placements p WHERE p.stay_id = s.id AND p.until_at IS NULL) <> 1) || ' ' ||
  (SELECT count(*) FROM housing_placements p JOIN stays s ON s.id = p.stay_id
    WHERE p.until_at IS NULL AND s.discharged_at IS NOT NULL) || ' ' ||
  (SELECT count(*) FROM (SELECT unit_id FROM housing_placements WHERE until_at IS NULL
                          GROUP BY unit_id HAVING count(*) > 1) x) || ' ' ||
  (SELECT count(*) FROM stays s WHERE NOT EXISTS (SELECT 1 FROM housing_placements p WHERE p.stay_id = s.id))")"
info "at T0: $(dbsql clinic "SELECT count(*) FROM housing_placements WHERE until_at IS NULL") units occupied, units $(dbsql clinic "SELECT string_agg(state || ' ' || n, ', ') FROM (SELECT state, count(*) n FROM housing_units GROUP BY state ORDER BY state) x")"

# --- the board, as the displays read it --------------------------------------------
board() {   # board <sql>: as vet_display, through its own grants
    docker exec -u postgres "$(ctr records)" psql -XAtq -d clinic -c "SET ROLE vet_display" -c "$1"
}
same "board: one row per unit, 64 units" "64 64" \
    "$(board "SELECT count(*) || ' ' || count(DISTINCT unit_id) FROM housing_unit_board")"
same "board: every occupied unit's row carries its animal (name, species, age, plan)" "0" \
    "$(board "SELECT count(*) FROM housing_unit_board WHERE stay_id IS NOT NULL
               AND (name IS NULL OR species IS NULL OR age_years IS NULL OR plan_kind IS NULL)")"
same "board: an empty unit's row carries the unit only" "0" \
    "$(board "SELECT count(*) FROM housing_unit_board WHERE stay_id IS NULL AND (name IS NOT NULL OR feedings_today IS NOT NULL)")"
same "board: no owner, contact or natural identifier among its columns" "" \
    "$(dbsql clinic "SELECT string_agg(column_name, ' ') FROM information_schema.columns
      WHERE table_name = 'housing_unit_board' AND column_name ~ '(owner|phone|email|address|microchip|ueln|passport|ear_tag|note)'")"
same "board: no owner's contact or a chip in any value" "0" \
    "$(board "SELECT count(*) FROM housing_unit_board AS b WHERE row_to_json(b)::text ~ '(@example\\.net|\\+999|941[0-9]{12})'")"
same "vet_display reads the two boards and nothing else of clinic" "t t f f f" \
    "$(dbsql clinic "SELECT has_table_privilege('vet_display', 'housing_unit_board', 'SELECT'),
                            has_table_privilege('vet_display', 'animal_board', 'SELECT'),
                            has_table_privilege('vet_display', 'owners', 'SELECT'),
                            has_table_privilege('vet_display', 'housing_placements', 'SELECT'),
                            has_table_privilege('housing_ward', 'housing_placements', 'INSERT')" | tr '|' ' ')"

# --- T0 ----------------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
dbsql postgres "CREATE EXTENSION IF NOT EXISTS pg_stat_statements" >/dev/null
info "gmctl start-load"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
dbsql postgres "SELECT pg_stat_statements_reset()" >/dev/null
T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
RESET=$(date +%s)
# The units the ward's first disinfection call (about 15 minutes after T0)
# finds to clean for 30 minutes or more.
DUE=$(dbsql clinic "SELECT count(*) FROM housing_units WHERE state = 'to-clean'
                     AND state_since_at <= '$T0'::timestamptz - interval '15 minutes'")
LOCAL=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%H:%M)
info "T0 $T0, $LOCAL local (shift $SHIFT)"
case $MODE in
    place) case $LOCAL in 10:*) pass "T0 placed at 10:00 local ($LOCAL)" ;; *) fail "T0 not in 10:00-10:59 local: $LOCAL" ;; esac ;;
    care) case $LOCAL in 16:*) pass "T0 placed just before 17:00 local ($LOCAL)" ;; *) fail "T0 not in 16:00-16:59 local: $LOCAL" ;; esac ;;
esac
i=0
while [ "$i" -lt 30 ]; do
    case "$(nstatus pms) $(nstatus ward)" in running\ *running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
for n in pms ward; do
    case $(nstatus $n) in running\ *) pass "$n running: $(nstatus $n)" ;; *) fail "$n not running: [$(nstatus $n)]" ;; esac
done

# --- the run's window --------------------------------------------------------------
# Every instant below is read against T0 in the database (UTC).
q() { dbsql clinic "$1"; }
since="'$T0'::timestamptz"
PLACED= RELEASED= DONE_AT=$(( T0S + WINDOW ))
while [ "$(date +%s)" -lt "$DONE_AT" ]; do
    sleep 30
    if [ "$MODE" = place ]; then
        [ -n "$PLACED" ] || PLACED=$(q "SELECT s.id || ' ' || p.unit_id || ' ' || round(extract(epoch FROM p.from_at - s.admitted_at) / 60, 1)
            FROM stays s JOIN housing_placements p ON p.stay_id = s.id AND p.reason = 'admission'
           WHERE s.admitted_at >= $since ORDER BY s.id LIMIT 1")
        [ -n "$RELEASED" ] || RELEASED=$(q "SELECT s.id || ' ' || p.unit_id || ' ' || s.outcome
            FROM stays s JOIN housing_placements p ON p.stay_id = s.id AND p.until_at = s.discharged_at
           WHERE s.discharged_at >= $since ORDER BY s.id LIMIT 1")
        # placed and released, and the ward's first disinfection call (4/h,
        # even: about 15 minutes after T0) passed: enough
        [ -n "$PLACED" ] && [ -n "$RELEASED" ] && [ $(( $(date +%s) - RESET )) -ge 1000 ] && break
    elif [ "$(date +%s)" -ge $(( T0S + 900 )) ]; then
        lt=$(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%H%M)
        # the 17:00 round met, or never to be met in the window
        { [ "$lt" -ge 1712 ] || [ "$(date -u -d "@$(( DONE_AT + SHIFT * 3600 ))" +%H%M)" -lt 1705 ]; } && break
    fi
done
ELAPSED=$(( $(date +%s) - RESET ))
info "window: $ELAPSED s of load after T0"

calls=$(dbsql postgres "SELECT coalesce(sum(s.calls), 0) || ' ' || count(DISTINCT s.queryid)
  FROM pg_stat_statements s JOIN pg_roles r ON r.oid = s.userid
 WHERE r.rolname = 'vet_display' AND s.query = 'SELECT * FROM housing_unit_board WHERE unit_id = \$1'")
set -- $calls
perminute=$(python3 -c "print(round($1 * 60 / $ELAPSED, 1))")
same "board: one statement (one queryid) for every display's read" "1" "$2"
if python3 -c "import sys; sys.exit(not 54 <= $perminute <= 74)"; then
    pass "board: about 64 calls a minute ($1 in $ELAPSED s: $perminute a minute)"
else
    fail "board: calls a minute $perminute ($1 in $ELAPSED s), not about 64"
fi
same "board: read from ward, as vet_display, through its pool (4 sessions at most)" "ward ok" \
    "$(dbsql postgres "SELECT string_agg(DISTINCT application_name, ',') || ' ' || CASE WHEN count(*) BETWEEN 1 AND 4 THEN 'ok' ELSE count(*)::text END
                        FROM pg_stat_activity WHERE usename = 'vet_display' AND datname = 'clinic'")"

if [ "$MODE" = place ]; then
    if [ -n "$PLACED" ]; then
        set -- $PLACED
        if python3 -c "import sys; sys.exit(not $3 <= 15)"; then
            pass "placement: stay $1, admitted after T0, placed in unit $2 within $3 minutes"
        else
            fail "placement: stay $1 placed after $3 minutes"
        fi
    else
        fail "placement: no stay admitted after T0 was placed"
    fi
    if [ -n "$RELEASED" ]; then
        set -- $RELEASED
        same "release: stay $1 ($3) released at its end, unit $2 to clean (or disinfected since), its plans ended" "ok ok" \
            "$(q "SELECT CASE WHEN u.state = 'to-clean' OR EXISTS (SELECT 1 FROM housing_care_events e WHERE e.unit_id = u.id
                     AND e.kind = 'disinfection' AND e.done_at >= s.discharged_at) THEN 'ok' ELSE u.state END || ' ' ||
                  CASE WHEN NOT EXISTS (SELECT 1 FROM housing_feeding_plans f WHERE f.stay_id = s.id
                     AND (f.until_at IS NULL OR f.until_at > greatest(f.from_at, s.discharged_at))) THEN 'ok'
                       ELSE 'open plan' END
                FROM stays s JOIN housing_units u ON u.id = $2 WHERE s.id = $1")"
    else
        fail "release: no stay discharged after T0 was released"
    fi
    same "release: no placement open on a stay ended 15 minutes ago or more" "0" \
        "$(q "SELECT count(*) FROM housing_placements p JOIN stays s ON s.id = p.stay_id
               WHERE p.until_at IS NULL AND s.discharged_at <= now() - interval '15 minutes'")"
    # A disinfection only after 30 minutes to clean; none left waiting past
    # its 30 minutes and the ward's 15.
    same "disinfection: none before its unit's 30 minutes to clean" "0" \
        "$(q "SELECT count(*) FROM housing_care_events e
               WHERE e.kind = 'disinfection' AND e.done_at >= $since
                 AND e.done_at < (SELECT max(p.until_at) FROM housing_placements p
                                   WHERE p.unit_id = e.unit_id AND p.until_at <= e.done_at) + interval '30 minutes'")"
    d=$(q "SELECT count(*) || ' ' || coalesce(string_agg(DISTINCT unit_id::text, ','), '-') FROM housing_care_events
            WHERE kind = 'disinfection' AND done_at >= $since")
    set -- $d
    if [ -n "$DUE" ] && [ "$DUE" -gt 0 ] && [ "$ELAPSED" -ge 1000 ]; then
        if [ "$1" -gt 0 ]; then
            same "disinfection: $DUE unit(s) due at the ward's first call, $1 disinfected since T0 (units $2), each clean again or holding its next animal" "0" \
                "$(q "SELECT count(*) FROM housing_units u WHERE u.id IN ($2) AND u.state <> 'clean'
                        AND NOT EXISTS (SELECT 1 FROM housing_care_events e WHERE e.unit_id = u.id AND e.kind = 'disinfection'
                                         AND e.done_at > u.state_since_at)")"
        else
            fail "disinfection: $DUE unit(s) due at the ward's first call, none disinfected"
        fi
    else
        info "disinfection: none due in the window ($DUE unit(s) to clean 30 minutes by the ward's first call; T0 $LOCAL local, $1 disinfected)"
    fi
    info "since T0: $(q "SELECT count(*) FROM stays WHERE admitted_at >= $since") admitted, $(q "SELECT count(*) FROM stays WHERE discharged_at >= $since") ended, $(q "SELECT count(*) FROM housing_placements WHERE from_at >= $since") placements opened, $(q "SELECT count(*) FROM housing_placements WHERE until_at >= $since") ended"
else
    f=$(q "SELECT count(*) || ' ' || count(DISTINCT stay_id) FROM housing_care_events WHERE kind = 'feeding' AND done_at >= $since")
    set -- $f
    if [ "$1" -gt 0 ]; then pass "care: the round's feedings recorded since T0 ($1 feedings, $2 animals)"
    else fail "care: no feeding recorded since T0"; fi
    same "care: no feeding inside a nil-by-mouth order" "0" \
        "$(q "SELECT count(*) FROM housing_care_events e JOIN housing_feeding_plans f ON f.stay_id = e.stay_id
               AND f.kind = 'nil-by-mouth' AND e.done_at >= f.from_at AND e.done_at < coalesce(f.until_at, 'infinity')
              WHERE e.kind = 'feeding' AND e.done_at >= $since")"
    same "care: no feeding beyond the meals due (two at a round at most)" "0" \
        "$(q "SELECT count(*) FROM (SELECT stay_id, date_trunc('hour', done_at) FROM housing_care_events
               WHERE kind = 'feeding' AND done_at >= $since GROUP BY 1, 2 HAVING count(*) > 2) x")"
    # A nil-by-mouth animal at a round in the window: its species' round
    # passed while its order was in force, and no feeding since T0.
    skipped=$(q "WITH b AS (SELECT timezone FROM business_settings),
      r AS (SELECT p.stay_id, a.species, ((now() AT TIME ZONE b.timezone)::date + make_interval(hours => h)) AT TIME ZONE b.timezone AS at
              FROM b, housing_placements p JOIN stays s ON s.id = p.stay_id JOIN animals a ON a.id = s.animal_id,
                   unnest(CASE a.species WHEN 'horse' THEN ARRAY[6, 12, 17, 21] WHEN 'cattle' THEN ARRAY[7, 16]
                          WHEN 'sheep' THEN ARRAY[7, 16] WHEN 'goat' THEN ARRAY[7, 16] WHEN 'dog' THEN ARRAY[8, 17]
                          ELSE ARRAY[8, 13, 18] END) AS h
             WHERE p.until_at IS NULL)
      SELECT count(DISTINCT r.stay_id) || ' ' || count(DISTINCT r.stay_id) FILTER (WHERE EXISTS (
               SELECT 1 FROM housing_care_events e WHERE e.stay_id = r.stay_id AND e.kind = 'feeding' AND e.done_at >= r.at))
        FROM r JOIN housing_feeding_plans f ON f.stay_id = r.stay_id AND f.kind = 'nil-by-mouth'
                 AND r.at >= f.from_at AND r.at < coalesce(f.until_at, 'infinity')
       WHERE r.at >= $since AND r.at <= now() - interval '5 minutes'")
    set -- $skipped
    if [ "$1" -gt 0 ]; then
        same "care: $1 nil-by-mouth animal(s) at a round in the window skipped" "0" "$2"
    else
        info "care: no nil-by-mouth order met a round in the window (T0 $LOCAL local)"
    fi
    ev=$(q "SELECT count(*) FROM housing_care_events WHERE done_at >= $since")
    perhour=$(python3 -c "print(round($ev * 3600 / $ELAPSED))")
    if python3 -c "import sys; sys.exit(not 10 <= $perhour <= 90)"; then
        pass "care: the care log's pace, $ev events in $ELAPSED s ($perhour an hour: about 20 on average, 45 in the evening rounds)"
    else
        fail "care: $ev events in $ELAPSED s ($perhour an hour)"
    fi
    info "care since T0, by kind: $(q "SELECT string_agg(kind || ' ' || n, ', ') FROM (SELECT kind, count(*) n FROM housing_care_events
                                      WHERE done_at >= $since GROUP BY kind ORDER BY kind) x")"
fi
for n in pms ward; do
    errs=$(nlog $n | grep ' error ' || true)
    same "$n ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
    [ -z "$errs" ] || printf '%s\n' "$errs" | head -n 5 | cut -c1-300 | sed "s/^/....  $n: /"
done

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
same "teardown: nothing labelled with $GAME left" "" "$left"

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
