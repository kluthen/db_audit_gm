#!/bin/sh
# Short test of the bookings fixture (v0.5 build plan, chunk 13; master spec
# 9.4; vet-scheduling-domain.md, "Tests in v0.5"; capture W3 item 2 with "W3
# item 2, revised"): vet-core's record and vet-scheduling's agenda, rota and
# training centre loaded by gmctl load-data from the domains (the core's
# schema, keys.sql and load, then scheduling's schema, with btree_gist and the
# four exclusion constraints, and its load with the core's keys.sql, then the
# coherence check), the practice software, pms, the idle integration engine,
# interfaces, and the lookup API, clinic-api, composed by gmctl compose from
# the domains' producers. One run on one host in under 30 minutes, T0 a
# weekday at 09:00-09:59 local.
#
# Time is placed by the shift (whole hours), so the local minute at T0 is the
# UTC minute, about seven minutes after the start (fit, render, deploy and the
# two loads): started at minute 40 to 45 of an hour, T0 lands about 09:47-09:52
# local, before the 10:00 slots and shifts the window meets. Started at
# another minute T0 stays in the 09:00 hour (when the loads end before 09:00
# local, start-load waits for it); the checks needing the 10:00 arrivals and
# clockings then report them as not reached (....).
#
# On a copy of tools/tests/fixtures/fixture-bookings (bastion 0.5.0, records:
# postgres 0.5.0, clinic-api: api 0.1.0, pms and interfaces: scheduler 0.3.0
# at intensity 1.0, domains: vet-core and vet-scheduling at records/clinic):
#   compose --check -> fit (the laptop playground, 2 CPU / 4G / 8G) -> render
#   (the shift placing T0) -> deploy -> load-data (its time and size), then:
#   - the stack file: sched_app's and vet_app's passwords on pms only, none on
#     the bastion or records;
#   - load-data: the coherence check passed (six checks: the attended
#     bookings, no overlap, the vets on shift, the hours, the imaging and
#     exchange bookings); the part's rows; every login role with a SCRAM
#     password; no key function left; the four exclusion constraints created
#     before the allocations were written;
#   - inject -> start-load (T0); as sched_app: an overlapping allocation
#     refused (23P01); a booking through sched_free_slots, one 40 days ahead
#     on a planned shift; the first cancelled, its allocations released and
#     its slot offered again; then the window: arrivals checked in, shifts
#     clocked; sched.rota.publish moved to the next minute (D132): the week
#     after next published, its absence-covered planned shifts removed, the
#     seventh week planned, the week after next's blocks booked; moved again:
#     rerun without a duplicate; pms and interfaces without an error;
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
# Usage: sh tools/tests/fixtures/fixture-bookings/run-short-test.sh
set -eu

TARGET_HOUR=9
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=bookings-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
JOBS=/srv/scheduler/jobs/jobs.yaml
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SETUP=420            # seconds from now to T0, about: fit, render, deploy, load-data
WINDOW=900           # seconds of load after T0, at most
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-bookings-short.XXXXXX")
SCN=$tmp/fixture-bookings
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
asapp() { docker exec -u postgres "$(ctr records)" psql -XAtq -d clinic -c "SET ROLE sched_app" -c "$1"; }
nlog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
nstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }

# --- composition ---------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/, nodes/pms/ and nodes/interfaces/ as compose writes them from the domains"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

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
local = t0 + datetime.timedelta(hours=shift)
print(moment.strftime("%Y-%m-%dT%H:00Z"), shift, local.strftime("%H:%M"), local.isoweekday())
EOF
)
HANDOVER=$1 SHIFT=$2 LOCAL_T0=$3 DOW=$4
info "render --handover $HANDOVER, shift $SHIFT: T0 expected about $LOCAL_T0 local (ISO weekday $DOW)"
[ "$DOW" -le 5 ] || { echo "T0 would fall on a weekend (local weekday $DOW): run on a weekday" >&2; exit 2; }
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "clinic-api", "pms", "interfaces"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
same "stack: sched_app's and vet_app's passwords on pms" \
    "pms role_sched_app_password role_vet_app_password" "$(printf '%s\n' "$st" | sed -n 4p)"
same "stack: none on the bastion" "bastion -" "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: none on records (load-data sets the roles' passwords)" "records -" \
    "$(printf '%s\n' "$st" | sed -n 2p)"
info "stack: $(printf '%s\n' "$st" | sed -n 3p); $(printf '%s\n' "$st" | sed -n 5p)"

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
for n in pms interfaces; do
    case $(nstatus $n) in idle\ *) pass "$n idle before the load: $(nstatus $n)" ;;
        *) fail "$n before the load: [$(nstatus $n)]" ;; esac
done

info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core and the agenda loaded, coherence checked ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: the coherence check passed, its six checks" \
    "pass: attended-bookings:pass no-overlap:pass vets-on-shift:pass within-hours:pass imaging-bookings:pass exchange-bookings:pass" \
    "$(python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])).get("coherence") or {}
print(f"{c.get('result')}: " + " ".join(f"{k.get('check')}:{k.get('result')}" for k in c.get("checks") or []))
EOF
)"
info "scheduling rows: $(dbsql clinic "SELECT string_agg(t || ' ' || n, ', ') FROM (
  SELECT 'bookings' t, count(*) n FROM sched_bookings UNION ALL SELECT 'allocations', count(*) FROM sched_allocations
  UNION ALL SELECT 'shifts', count(*) FROM sched_shifts UNION ALL SELECT 'absences', count(*) FROM sched_absences
  UNION ALL SELECT 'sessions', count(*) FROM sched_sessions UNION ALL SELECT 'trainees', count(*) FROM sched_trainees
  UNION ALL SELECT 'enrolments', count(*) FROM sched_enrolments) x")"
info "size: scheduling $(dbsql clinic "SELECT pg_size_pretty(sum(pg_total_relation_size(oid))) FROM pg_class
  WHERE relname LIKE 'sched\_%' AND relkind = 'r'"), clinic $(dbsql clinic "SELECT pg_size_pretty(pg_database_size('clinic'))")"
same "load-data: every attended booking a scheduled consultation of the core, by id" "0 0" \
    "$(dbsql clinic "SELECT (SELECT count(*) FROM consultations c WHERE c.kind = 'scheduled'
                              AND NOT EXISTS (SELECT 1 FROM sched_bookings b WHERE b.id = c.booking_id AND b.state = 'arrived'))
                     || ' ' || (SELECT count(*) FROM sched_bookings b WHERE b.id <= 25000
                              AND NOT EXISTS (SELECT 1 FROM consultations c WHERE c.booking_id = b.id))")"
same "load-data: sched_app and sched_reports have a SCRAM password" "sched_app:true sched_reports:true" \
    "$(dbsql postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%'), ' ' ORDER BY rolname)
                       FROM pg_authid WHERE rolname LIKE 'sched\_%'")"
same "load-data: no key function left in the catalog" "0" \
    "$(dbsql clinic "SELECT count(*) FROM pg_proc WHERE proname LIKE 'core\_%' OR proname LIKE 'vc\_%'
                       OR (proname LIKE 'sched\_%' AND proname NOT IN ('sched_free_slots', 'sched_release_allocations'))")"
same "the four exclusion constraints, created before the allocations were written" \
    "sched_allocations_animal_excl sched_allocations_machine_excl sched_allocations_room_excl sched_allocations_staff_excl:true" \
    "$(dbsql clinic "SELECT string_agg(conname, ' ' ORDER BY conname) || ':' ||
                            (max(xmin::text::bigint) < (SELECT min(xmin::text::bigint) FROM sched_allocations))
                       FROM pg_constraint WHERE conrelid = 'sched_allocations'::regclass AND contype = 'x'")"
info "at T0's load: $(dbsql clinic "SELECT string_agg(kind || ' ' || state || ' ' || n, ', ') FROM (SELECT kind, state, count(*) n
  FROM sched_bookings GROUP BY 1, 2 ORDER BY 1, 2) x")"

# --- T0 ----------------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
# The loads may end before TARGET_HOUR local (SETUP is an estimate): T0 waits
# for it, at most SETUP seconds.
i=0
while [ "$(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%-H)" -lt "$TARGET_HOUR" ] && [ "$i" -lt "$SETUP" ]; do
    sleep 5; i=$((i + 5))
done
[ "$i" -eq 0 ] || info "start-load held $i s for $TARGET_HOUR:00 local"
info "gmctl start-load"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
LOCAL=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%H:%M)
LDOW=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%u)
info "T0 $T0, $LOCAL local (shift $SHIFT, weekday $LDOW)"
case "$LDOW $LOCAL" in [1-5]\ 09:*) pass "T0 a weekday in the 09:00 hour local ($LOCAL)" ;;
    *) fail "T0 not a weekday at 09:00-09:59 local: weekday $LDOW, $LOCAL" ;; esac
i=0
while [ "$i" -lt 30 ]; do
    case "$(nstatus pms) $(nstatus interfaces)" in running\ *running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
for n in pms interfaces; do
    case $(nstatus $n) in running\ *) pass "$n running: $(nstatus $n)" ;; *) fail "$n not running: [$(nstatus $n)]" ;; esac
done

# --- the constraints and the slot function, as sched_app -----------------------------
# An allocation of a staff member over one of their live allocations ahead.
r=$(docker exec -u postgres "$(ctr records)" psql -XAtq -d clinic -c "SET ROLE sched_app" -c "\set VERBOSITY verbose" -c "
WITH a AS (SELECT a.staff_id, a.starts_at, a.ends_at FROM sched_allocations AS a JOIN sched_bookings AS b ON b.id = a.booking_id
            WHERE b.state = 'booked' AND a.role = 'vet' AND a.released_at IS NULL AND a.starts_at > now() + interval '1 day'
            ORDER BY a.starts_at, a.id LIMIT 1),
nb AS (INSERT INTO sched_bookings (type_id, kind, section_id, starts_at, ends_at, state, source, booked_at)
       SELECT 2, 'consultation', 3, a.starts_at, a.ends_at, 'booked', 'desk', now() FROM a RETURNING id, starts_at, ends_at)
INSERT INTO sched_allocations (booking_id, staff_id, role, starts_at, ends_at)
SELECT nb.id, a.staff_id, 'vet', nb.starts_at, nb.ends_at FROM nb, a" 2>&1 || true)
case $r in *23P01*sched_allocations_staff_excl*) pass "an overlapping staff allocation refused: 23P01 (sched_allocations_staff_excl)" ;;
    *) fail "the overlapping allocation not refused with 23P01: [$(printf '%s' "$r" | head -n 2)]" ;; esac

# book <type> <after>: the stream's statement, the slot sched_free_slots gives;
# prints the booking's id, start, vet (or first staff) and room or machine.
book() {
    asapp "WITH s AS (SELECT f.* FROM sched_free_slots($1, $2, 1) AS f),
           b AS (INSERT INTO sched_bookings (type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, booked_at,
                                             booked_by)
                 SELECT t.id, t.kind, 9800, t.section_id, s.starts_at, s.ends_at, 'booked', 'phone', now(), 67
                   FROM s, sched_types AS t WHERE t.id = $1
                 RETURNING id, starts_at, ends_at),
           v AS (INSERT INTO sched_allocations (booking_id, staff_id, role, starts_at, ends_at)
                 SELECT b.id, s.staff_ids[1], 'vet', b.starts_at, b.ends_at FROM b, s RETURNING booking_id),
           r AS (INSERT INTO sched_allocations (booking_id, room_id, role, starts_at, ends_at)
                 SELECT b.id, s.room_id, 'room', b.starts_at, b.ends_at FROM b, s RETURNING booking_id)
           SELECT b.id || ' ' || b.starts_at || ' ' || s.staff_ids[1] || ' ' || s.room_id
             FROM b, s, (SELECT count(*) FROM v) AS v, (SELECT count(*) FROM r) AS r" | tr ' ' '_' | sed 's/_/ /;s/_/T/;s/_/ /g'
}
set -- $(book 2 "now() + interval '2 hours'")
B1=${1:-} S1=${2:-} V1=${3:-} R1=${4:-}
if [ -n "$B1" ]; then pass "a follow-up booked through sched_free_slots: booking $B1 at $S1, vet $V1, room $R1"
else fail "no booking through sched_free_slots two hours ahead"; fi
set -- $(book 2 "now() + interval '40 days'")
B2=${1:-} S2=${2:-} V2=${3:-}
if [ -n "$B2" ]; then
    same "a booking 40 days ahead (booking $B2 at $S2, vet $V2) on a planned shift, not yet published" "planned" \
        "$(dbsql clinic "SELECT CASE WHEN h.published_at IS NULL THEN 'planned' ELSE 'published' END
                           FROM sched_bookings AS b JOIN sched_allocations AS a ON a.booking_id = b.id AND a.role = 'vet'
                           JOIN sched_shifts AS h ON h.staff_id = a.staff_id AND h.starts_at <= a.starts_at AND h.ends_at >= a.ends_at
                          WHERE b.id = $B2")"
else
    fail "no booking through sched_free_slots 40 days ahead"
fi
if [ -n "$B1" ]; then
    asapp "UPDATE sched_bookings SET state = 'cancelled', cancelled_at = now(), cancel_reason = 'owner' WHERE id = $B1" >/dev/null
    same "the cancellation released its allocations (the trigger sched_release)" "2 2" \
        "$(dbsql clinic "SELECT count(*) || ' ' || count(released_at) FROM sched_allocations WHERE booking_id = $B1")"
    same "its slot offered again by sched_free_slots" "$S1 $V1 $R1" \
        "$(asapp "SELECT replace(starts_at::text, ' ', 'T') || ' ' || staff_ids[1] || ' ' || room_id
                    FROM sched_free_slots(2, now() + interval '2 hours', 1)")"
fi

# --- sched.rota.publish moved to the next minute, twice ----------------------------
# The week after next and the seventh week, local Mondays from T0's week.
W=$(dbsql clinic "SELECT date_trunc('week', now() AT TIME ZONE timezone)::date FROM sched_settings")
counts() {
    dbsql clinic "WITH w AS (SELECT s.timezone AS tz FROM sched_settings AS s),
      k AS (SELECT ('$W'::date + 14)::timestamp AT TIME ZONE tz AS a2, ('$W'::date + 21)::timestamp AT TIME ZONE tz AS b2,
                   ('$W'::date + 49)::timestamp AT TIME ZONE tz AS a7, ('$W'::date + 56)::timestamp AT TIME ZONE tz AS b7 FROM w)
      SELECT (SELECT count(*) FILTER (WHERE published_at IS NULL) || ' ' || count(*) FILTER (WHERE published_at IS NOT NULL)
                FROM sched_shifts, k WHERE starts_at >= k.a2 AND starts_at < k.b2) || ' ' ||
             (SELECT count(*) FROM sched_shifts, k WHERE starts_at >= k.a7 AND starts_at < k.b7) || ' ' ||
             (SELECT count(*) FROM sched_bookings, k WHERE kind = 'block' AND starts_at >= k.a2 AND starts_at < k.b2) || ' ' ||
             (SELECT count(*) - count(DISTINCT (staff_id, starts_at)) FROM sched_shifts)"
}
move_publish() {   # the job's at to the next whole minute (UTC), pms reloaded; prints its cron expression
    now=$(date -u +%s)
    [ $((now % 60)) -gt 40 ] && now=$((now + 60))
    at=$((now + 60))
    M=$(date -u -d "@$at" +%-M); H=$(date -u -d "@$at" +%-H)
    docker exec -i -u 0 "$(ctr pms)" python3 - "$JOBS" "$M $H * * *" <<'EOF'
import sys, yaml
path, at = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(path))
for job in doc["jobs"]:
    if job["key"] == "sched.rota.publish":
        job["at"], job["timezone"] = at, "UTC"
text = open(path).read().split("jobs:")[0]
open(path, "w").write(text + yaml.safe_dump({"jobs": doc["jobs"]}, sort_keys=False))
EOF
    docker exec -u 0 "$(ctr pms)" /command/s6-svc -h /run/service/scheduler
    printf '%s' "$M $H * * *"
}
moved() {   # moved <cron expression>: pms reloaded with it (its /run/scheduler/loaded), within 15 s
    j=0
    while [ "$j" -lt 15 ]; do
        l=$(docker exec "$(ctr pms)" sed -n 's/^cron rota-publish //p' /run/scheduler/loaded 2>/dev/null || true)
        [ "$l" = "UTC $1" ] && { pass "pms reloaded with sched.rota.publish at '$1' UTC"; return 0; }
        sleep 1; j=$((j + 1))
    done
    fail "pms not reloaded with sched.rota.publish at '$1' UTC (loaded: [$l]; $(nlog pms | grep ' reload ' | tail -n 1))"
}
runs() { nlog pms | grep -c ' run job=rota-publish .*phase=end status=ok' || true; }
before=$(counts)
set -- $before
info "before: week after next $1 planned, $2 published; seventh week $3 shifts; week after next's blocks $4"
if [ "$1" -gt 0 ] && [ "$2" -eq 0 ] && [ "$3" -eq 0 ]; then pass "before the job: the week after next planned only, the seventh week empty"
else fail "before the job: [$before]"; fi
n0=$(runs)
x=$(move_publish)
info "sched.rota.publish moved to '$x' UTC"
moved "$x"
i=0; while [ "$i" -lt 150 ] && [ "$(runs)" -le "$n0" ]; do sleep 5; i=$((i + 5)); done
after=$(counts)
set -- $after
if [ "$(runs)" -gt "$n0" ]; then pass "sched.rota.publish ran ($(nlog pms | grep ' run job=rota-publish .*phase=end' | tail -n 1 | cut -c1-160))"
else fail "sched.rota.publish did not run within 150 s: $(nlog pms | grep 'rota-publish' | tail -n 3)"; fi
same "the week after next published, none left planned" "0" "$1"
if [ "$2" -gt 0 ] && [ "$3" -gt 0 ] && [ "$4" -gt 0 ]; then
    pass "published: $2 shifts of the week after next ($(( $(echo "$before" | cut -d' ' -f1) - $2 )) planned ones removed for an absence), the seventh week planned ($3 shifts), $4 blocks booked"
else
    fail "after the job: [$after]"
fi
n1=$(runs)
x=$(move_publish)
info "sched.rota.publish moved again to '$x' UTC"
moved "$x"
i=0; while [ "$i" -lt 150 ] && [ "$(runs)" -le "$n1" ]; do sleep 5; i=$((i + 5)); done
[ "$(runs)" -gt "$n1" ] && pass "sched.rota.publish ran again" || fail "sched.rota.publish did not rerun within 150 s"
same "the rerun: no duplicate shift, no duplicate block, nothing changed" "$after" "$(counts)"

# --- the run's window ------------------------------------------------------------------
DONE_AT=$(( T0S + WINDOW ))
while [ "$(date +%s)" -lt "$DONE_AT" ]; do
    sleep 30
    # the 10:00 slots met and clocked: enough
    [ "$(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%H%M)" -ge 1012 ] && break
done
since="'$T0'::timestamptz"
a=$(dbsql clinic "SELECT count(*) FROM sched_bookings WHERE arrived_at >= $since")
c=$(dbsql clinic "SELECT count(*) FROM sched_shifts WHERE clocked_in_at >= $since")
m=$(dbsql clinic "SELECT count(*) FROM sched_bookings WHERE booked_at >= $since AND source IN ('phone', 'desk', 'follow-up', 'referral')")
NOWL=$(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%H:%M)
if [ "$a" -gt 0 ]; then pass "arrivals checked in since T0: $a"
elif [ "$NOWL" \< "10:05" ]; then info "arrivals: none yet ($NOWL local)"; else fail "no arrival checked in since T0 ($NOWL local)"; fi
if [ "$c" -gt 0 ]; then pass "shifts clocked in since T0: $c"
elif [ "$NOWL" \< "10:05" ]; then info "clock-ins: none yet ($NOWL local)"; else fail "no shift clocked in since T0 ($NOWL local)"; fi
info "reception's bookings since T0: $m (the test's two included)"
same "no live allocation overlaps another at the end of the window" "0" \
    "$(dbsql clinic "SELECT count(*) FROM sched_allocations a JOIN sched_allocations b ON b.staff_id = a.staff_id AND b.id > a.id
                      AND b.during && a.during AND b.released_at IS NULL WHERE a.released_at IS NULL")"
for n in pms interfaces; do
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
