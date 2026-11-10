#!/bin/sh
# Short test of the reports fixture (v0.5 build plan, chunk 20; master spec
# 11.1, 11.3, 12.1, 12.2 purposes 7, 8 and 12, 18.1; spec D435, D436; capture
# W4 items 0 and 5): the periodic reports on vet-core's record, read on its
# standby, writing the back office's database office. On one host, under 30
# minutes from the deployment.
#
# Time is placed, never waited for (master spec 18.1): the hand-over is
# planned so that T0 falls at about 01:10 local, before the first feeder
# (01:30), so yesterday is the feeders' to write (the histories plant a
# feeder's day d only when d + 1 at its hour is before load_epoch). Each
# feeder is then moved to the next minute in the runner's jobs.yaml (UTC,
# the runner reloaded), and the monthly close with them, on a date not its
# own. The local minute is the real one (the shift is whole hours): before
# render the test waits, if need be, until a deployment starting then reaches
# T0 at about :10 (REPORTS_PREP_MINUTES, default 13, the minutes from the
# deployment to T0); that wait is not the run's. AM2 needs a herd treatment
# on the judged day (herd visits fall on Tuesdays and Thursdays): when
# yesterday holds none, the test records one, as the left-out pms would.
#
# On a copy of tools/tests/fixtures/fixture-reports (bastion 0.5.0; records,
# standby, lab, partners-db: postgres 0.5.0; backoffice, partners-backend:
# scheduler 0.3.0; partners-api: api 0.1.0):
#   gmctl compose --check -> fit (2 CPU / 4G / 8G) -> render -> deploy ->
#   load-data, then:
#   - load-data: office's tables, the planted periods (the last planted
#     month's extract and working-time months the sums of their days), the
#     standby streaming;
#   - inject -> start-load (T0, about 01:10 local); yesterday unplanted in
#     every feeder's table, the day before planted; a herd treatment
#     yesterday (recorded if none);
#   - the four feeders and close-medicines-register moved to the next minute
#     (one reload): each feeder writes yesterday once, one runs row, read on
#     the standby (its log's connections, none on records); the close, on a
#     date not its own, writes neither output nor runs row;
#   - the eleven checks (MR1 to MR4, AM1 to AM4, WT1 to WT3) on backoffice,
#     CHECK_SINCE T0: each exit 0;
#   - the four feeders moved again: each writes nothing (its day held), one
#     more runs row with 0 written; the runs checks again, exit 0;
#   - WT3 on a corrupted close (the month's night hours from the hours
#     worked, in the runner's queries.yaml): exit 1; restored: exit 0;
#   - no error in the runner's log;
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
# Usage: sh tools/tests/fixtures/fixture-reports/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=reports-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
JOBS=/srv/scheduler/jobs/jobs.yaml
QUERIES=/srv/scheduler/repository/queries.yaml
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
PREP=${REPORTS_PREP_MINUTES:-13}
P7=$REPO/purposes/vet-medicines-registers/checks
P8=$REPO/purposes/vet-antimicrobial-use/checks
P12=$REPO/purposes/vet-working-time/checks
FEEDERS="feed-medicines-register feed-controlled-drugs feed-antimicrobial-use feed-working-time"

failures=0
passes=0
stamp() { date -u +%H:%M:%S; }
pass() { printf '%s PASS  %s\n' "$(stamp)" "$*"; passes=$((passes + 1)); }
fail() { printf '%s FAIL  %s\n' "$(stamp)" "$*"; failures=$((failures + 1)); }
info() { printf '%s ....  %s\n' "$(stamp)" "$*"; }
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-reports-short.XXXXXX")
SCN=$tmp/fixture-reports
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
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2" -c "$3"; }
slog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
sstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
pglog() { docker exec -u 0 "$(ctr "$1")" sh -c 'cat /var/log/postgresql/*.log' 2>/dev/null || true; }
ran() {    # ran <job> <from epoch>: the end lines of its successful runs since
    slog backoffice | python3 -c '
import sys, datetime
job, since = sys.argv[1], float(sys.argv[2])
for line in sys.stdin:
    if f" run job={job} " in line and "phase=end" in line and "status=ok" in line:
        t = datetime.datetime.strptime(line.split()[0].rstrip("Z")[:19], "%Y-%m-%dT%H:%M:%S")
        if t.replace(tzinfo=datetime.timezone.utc).timestamp() >= since:
            print(line.rstrip())' "$1" "$2"
}
check() {   # check <script>: one check as gmctl check runs it (root, sh -s, CHECK_SINCE), on backoffice
    out=$(docker exec -i -u root -e "CHECK_SINCE=$T0" "$(ctr backoffice)" sh -s < "$1" 2>&1) && rc=0 || rc=$?
    line=$(printf '%s\n' "$out" | head -n 1)
    if [ "$rc" -eq "${2:-0}" ]; then pass "$(basename "$1"): exit $rc, $line"
    else fail "$(basename "$1"): exit $rc (expected ${2:-0}), $out"; fi
}
# move <job>...: each job's at to the next whole minute (UTC), the runner
# reloaded and its loaded jobs checked; sets MOVED (epoch of the reload).
move() {
    now=$(date -u +%s)
    [ $((now % 60)) -gt 40 ] && now=$((now + 60))
    at=$((now + 60))
    expr="$(date -u -d "@$at" +%-M) $(date -u -d "@$at" +%-H) * * *"
    docker exec -i -u 0 "$(ctr backoffice)" python3 - "$JOBS" "$expr" "$@" <<'EOF'
import sys, yaml
path, at, names = sys.argv[1], sys.argv[2], sys.argv[3:]
doc = yaml.safe_load(open(path))
for job in doc["jobs"]:
    if job["name"] in names:
        job["at"], job["timezone"] = at, "UTC"
text = open(path).read().split("jobs:")[0]
open(path, "w").write(text + yaml.safe_dump({"jobs": doc["jobs"]}, sort_keys=False))
EOF
    MOVED=$(date -u +%s)
    docker exec -u 0 "$(ctr backoffice)" /command/s6-svc -h /run/service/scheduler
    for job in "$@"; do
        j=0; l=
        while [ "$j" -lt 15 ]; do
            l=$(docker exec "$(ctr backoffice)" sed -n "s/^cron $job //p" /run/scheduler/loaded 2>/dev/null || true)
            [ "$l" = "UTC $expr" ] && break
            sleep 1; j=$((j + 1))
        done
        same "backoffice reloaded with $job at '$expr' UTC" "UTC $expr" "$l"
    done
}
# all_ran <since epoch> <job>...: wait (up to 150 s) for every job's run
all_ran() {
    since=$1; shift
    i=0
    while [ "$i" -lt 150 ]; do
        missing=
        for job in "$@"; do [ -n "$(ran "$job" "$since")" ] || missing="$missing $job"; done
        [ -z "$missing" ] && break
        sleep 5; i=$((i + 5))
    done
    if [ -z "$missing" ]; then pass "ran after the move:$(for job in "$@"; do printf ' %s' "$job"; done)"
    else fail "did not run within 150 s:$missing ($(slog backoffice | grep -E "$(echo "$missing" | sed 's/^ //; s/ /|/g')" | tail -n 3))"; fi
}

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/backoffice/, nodes/partners-api/ and nodes/partners-backend/ as compose writes them"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- time placement ---------------------------------------------------------
# T0 at about :10 real (local 01:10): wait, if need be, so that a deployment
# starting now reaches T0 then.
now=$(date +%s)
min=$(( (now + PREP * 60) / 60 % 60 ))
if [ "$min" -lt 5 ] || [ "$min" -gt 15 ]; then
    start=$(( (now / 3600) * 3600 + ((10 - PREP + 60) % 60) * 60 ))
    [ "$start" -gt "$now" ] || start=$((start + 3600))
    info "waiting $(( start - now )) s so that T0 falls at about :10 (REPORTS_PREP_MINUTES $PREP)"
    sleep $(( start - now ))
fi
started=$(date +%s)
T0EST=$(( started + PREP * 60 ))
HANDOVER=$(python3 - "$T0EST" <<'EOF'
import datetime, sys
t0 = datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc)
shift = (1 - t0.hour + 11) % 24 - 11                  # local 01 at T0, in -11..12
planned_hour = (14 - shift) % 24                       # the designed hand-over, 14:00 local
moment = (t0 + datetime.timedelta(hours=9)).replace(minute=0, second=0, microsecond=0)
while moment.hour != planned_hour:
    moment += datetime.timedelta(hours=1)
print(moment.strftime("%Y-%m-%dT%H:00Z"))
EOF
)

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the eight nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME; planned hand-over $HANDOVER (T0 expected at $(date -u -d "@$T0EST" +%H:%M) UTC)"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "backoffice"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: no credential on the bastion" "bastion -" "$(line 1)"
same "stack: backoffice holds the authority's credential and its three roles' passwords" \
    "backoffice http_authority_customer role_office_jobs_password role_sched_reports_password role_vet_reports_password" "$(line 2)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the eight nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi

# --- load-data ---------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core and its parts, the lab, the partners' state, office, the planted periods, the standby cloned ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: office's twelve tables, owned by office" \
    "amu_reports antimicrobial_use controlled_balances controlled_inventories controlled_movements medicines_register register_extracts regulatory_submissions rest_breaches runs working_time_days working_time_months office" \
    "$(dbsql records office "SELECT string_agg(tablename, ' ' ORDER BY tablename) || ' ' || string_agg(DISTINCT tableowner, ',') FROM pg_tables WHERE schemaname = 'public'")"
info "planted: $(dbsql records office "SELECT (SELECT count(*) FROM medicines_register) || ' register lines, ' || (SELECT count(*) FROM controlled_movements) || ' controlled movements, '
  || (SELECT count(DISTINCT month) FROM register_extracts) || ' extracts (months), ' || (SELECT count(*) FROM controlled_balances) || ' balances, '
  || (SELECT count(*) FROM controlled_inventories) || ' inventory rows, ' || (SELECT count(*) FROM antimicrobial_use) || ' antimicrobial-use rows, '
  || (SELECT count(*) FROM amu_reports) || ' amu reports, ' || (SELECT count(*) FROM working_time_days) || ' working-time days, '
  || (SELECT count(*) FROM working_time_months) || ' months, ' || (SELECT count(*) FROM rest_breaches) || ' breaches, '
  || (SELECT count(*) FROM runs) || ' runs'")"
same "planted: the last year's antimicrobial-use report, acknowledged with its reference" "t" \
    "$(dbsql records office "SELECT bool_and(reference IS NOT NULL AND acknowledged_at IS NOT NULL) AND count(*) > 0 FROM amu_reports WHERE year = date_trunc('year', current_date - interval '1 year')::date")"
M=$(dbsql records office "SELECT max(month) FROM register_extracts")
same "a planted month ($M): each product's extract the sum of its days (lines, quantity), none missing" "0 t" \
    "$(dbsql records office "SELECT count(*) FILTER (WHERE r.l IS DISTINCT FROM e.lines OR r.q IS DISTINCT FROM e.quantity) || ' ' || (count(*) > 0)::text
       FROM (SELECT medicine_id, count(*) AS l, sum(quantity) AS q FROM medicines_register
              WHERE day >= '$M' AND day < ('$M'::date + interval '1 month')::date GROUP BY medicine_id) r
       FULL JOIN (SELECT medicine_id, lines, quantity FROM register_extracts WHERE month = '$M') e USING (medicine_id)" | sed 's/true$/t/')"
W=$(dbsql records office "SELECT max(month) FROM working_time_months")
same "a planted month ($W): each staff member's working time the sum of their days (hours, night hours, call-outs)" "0 t" \
    "$(dbsql records office "SELECT count(*) FILTER (WHERE d.w IS DISTINCT FROM m.worked_hours OR d.n IS DISTINCT FROM m.night_hours OR d.c IS DISTINCT FROM m.call_outs)
       || ' ' || (count(*) > 0)::text
       FROM (SELECT staff_id, sum(worked_hours) AS w, sum(night_hours) AS n, sum(call_outs) AS c FROM working_time_days
              WHERE day >= '$W' AND day < ('$W'::date + interval '1 month')::date GROUP BY staff_id) d
       FULL JOIN (SELECT staff_id, worked_hours, night_hours, call_outs FROM working_time_months WHERE month = '$W') m USING (staff_id)" | sed 's/true$/t/')"
same "the standby streaming from records, in recovery" "streaming t" \
    "$(dbsql records postgres "SELECT string_agg(state, ',') FROM pg_stat_replication") $(dbsql standby postgres "SELECT pg_is_in_recovery()" | sed 's/true/t/')"

# --- T0 ---------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
T0S=$(date +%s)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0, $(( T0S - started )) s after the deployment began)"; else fail "start-load"; exit 1; fi
LOCAL=$(dbsql records clinic "SELECT to_char(now() AT TIME ZONE timezone, 'Dy YYYY-MM-DD HH24:MI') FROM business_settings")
Y=$(dbsql records clinic "SELECT (now() AT TIME ZONE timezone)::date - 1 FROM business_settings")
info "local time at T0: $LOCAL; yesterday $Y"
case $LOCAL in *\ 00:*|*\ 01:[012]?) pass "T0 before 01:30 local, the first feeder's hour ($LOCAL)" ;; *) fail "T0 not before 01:30 local ($LOCAL)" ;; esac
i=0
while [ "$i" -lt 30 ]; do
    case $(sstatus backoffice) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(sstatus backoffice) in running\ *) pass "backoffice running: $(sstatus backoffice)" ;; *) fail "backoffice not running: [$(sstatus backoffice)]" ;; esac
held() {   # held <day>: each feeder table's row count for the day
    dbsql records office "SELECT (SELECT count(*) FROM medicines_register WHERE day = '$1') || ' ' || (SELECT count(*) FROM controlled_movements WHERE day = '$1')
      || ' ' || (SELECT count(*) FROM antimicrobial_use WHERE day = '$1') || ' ' || (SELECT count(*) FROM working_time_days WHERE day = '$1')"
}
same "yesterday unplanted in the four feeders' tables (theirs to write)" "0 0 0 0" "$(held "$Y")"
set -- $(held "$(date -d "$Y - 1 day" +%F)")
if [ "$1" -gt 0 ] && [ "$3" -gt 0 ] && [ "$4" -gt 0 ]; then pass "the day before planted: $* (register, controlled, antimicrobial, working time)"
else fail "the day before not planted: [$*]"; fi

# --- a herd treatment yesterday (AM2's witness) -----------------------------------
herd() {   # herd <node>: yesterday's antimicrobial dispensings to a herd
    dbsql "$1" clinic "SELECT count(*) FROM dispensings d JOIN prescription_lines l ON l.id = d.prescription_line_id
      JOIN prescriptions p ON p.id = l.prescription_id JOIN medicines m ON m.id = l.medicine_id CROSS JOIN business_settings s
      WHERE p.herd_id IS NOT NULL AND m.antimicrobial
        AND d.dispensed_at >= '$Y'::timestamp AT TIME ZONE s.timezone AND d.dispensed_at < ('$Y'::date + 1)::timestamp AT TIME ZONE s.timezone"
}
n=$(herd records)
if [ "$n" -gt 0 ]; then
    pass "yesterday holds $n herd antimicrobial dispensing(s) (a herd-visit day)"
else
    dbsql records clinic "INSERT INTO dispensings (id, prescription_line_id, batch_id, quantity, owner_id, dispensed_by, dispensed_at)
      SELECT (SELECT max(id) + 1 FROM dispensings), d.prescription_line_id, d.batch_id, d.quantity, d.owner_id, d.dispensed_by,
             ('$Y'::date + time '11:00')::timestamp AT TIME ZONE s.timezone
        FROM dispensings d JOIN prescription_lines l ON l.id = d.prescription_line_id
        JOIN prescriptions p ON p.id = l.prescription_id JOIN medicines m ON m.id = l.medicine_id CROSS JOIN business_settings s
       WHERE p.herd_id IS NOT NULL AND m.antimicrobial ORDER BY d.dispensed_at DESC LIMIT 1" >/dev/null
    same "a herd antimicrobial dispensing recorded yesterday at 11:00 local, as pms would" "1" "$(herd records)"
fi
i=0; while [ "$i" -lt 30 ] && [ "$(herd standby)" != "$(herd records)" ]; do sleep 1; i=$((i + 1)); done
same "the standby holds it" "$(herd records)" "$(herd standby)"

# --- the feeders and the monthly close moved to the next minute ----------------------
EXTRACTS=$(dbsql records office "SELECT count(*) FROM register_extracts")
move $FEEDERS close-medicines-register
A=$MOVED
info "moved at $(date -u -d "@$A" +%H:%M:%S) UTC"
all_ran "$A" $FEEDERS close-medicines-register
runs_of() {   # runs_of <job>: its office runs rows since T0, as count:rows_written,...
    dbsql records office "SELECT count(*) || ':' || coalesce(string_agg(rows_written::text, ',' ORDER BY id), '') FROM runs WHERE job = '$1' AND started_at >= '$T0'"
}
set -- $(held "$Y")
info "yesterday written: $1 register lines, $2 controlled movements, $3 antimicrobial rows, $4 working-time days"
same "feed-medicines-register: one run, yesterday written, its lines as its run row says" "1:$1" "$(runs_of feed-medicines-register)"
same "feed-controlled-drugs: one run, its movements as its run row says" "1:$2" "$(runs_of feed-controlled-drugs)"
same "feed-antimicrobial-use: one run, its rows as its run row says" "1:$3" "$(runs_of feed-antimicrobial-use)"
same "feed-working-time: one run, its days as its run row says" "1:$4" "$(runs_of feed-working-time)"
if [ "$1" -gt 0 ] && [ "$3" -gt 0 ] && [ "$4" -gt 0 ]; then pass "the feeders wrote yesterday"; else fail "a feeder wrote nothing for yesterday: [$*]"; fi
same "the herd treatment counted under its herd's species" "t" \
    "$(dbsql records office "SELECT coalesce(sum(herds_treated) > 0, false) FROM antimicrobial_use WHERE day = '$Y'" | sed 's/true/t/; s/false/f/')"
same "close-medicines-register on a date not its own: no runs row" "0:" "$(runs_of close-medicines-register)"
same "close-medicines-register on a date not its own: no extract written" "$EXTRACTS" "$(dbsql records office "SELECT count(*) FROM register_extracts")"
case $(slog backoffice | grep 'script job=close-medicines-register' | tail -n 1) in
    *"not this job's date"*) pass "close-medicines-register said so: $(slog backoffice | grep 'script job=close-medicines-register' | tail -n 1 | cut -d' ' -f3-)" ;;
    *) fail "close-medicines-register's log: [$(slog backoffice | grep 'close-medicines-register' | tail -n 2)]" ;;
esac
s=$(pglog standby | grep -c 'connection authorized: user=\(vet\|sched\)_reports database=clinic' || true)
r=$(pglog records | grep -c 'connection authorized: user=\(vet\|sched\)_reports' || true)
if [ "$s" -gt 0 ] && [ "$r" -eq 0 ]; then pass "read on the standby: $s connections as vet_reports or sched_reports there, none on records"
else fail "the reads: $s connections on the standby, $r on records"; fi

# --- the eleven checks --------------------------------------------------------------
for c in "$P7"/mr*.sh "$P8"/am*.sh "$P12"/wt*.sh; do check "$c"; done

# --- the feeders moved again: their day held -------------------------------------------
before=$(held "$Y")
move $FEEDERS
B=$MOVED
all_ran "$B" $FEEDERS
same "the rerun: yesterday unchanged in the four tables" "$before" "$(held "$Y")"
set -- $before
same "the rerun: one more runs row each, 0 written" "2:$1,0 2:$2,0 2:$3,0 2:$4,0" \
    "$(for j in $FEEDERS; do printf '%s ' "$(runs_of "$j")"; done | sed 's/ $//')"
for c in "$P7"/mr1-*.sh "$P7"/mr2-*.sh "$P7"/mr3-*.sh "$P8"/am1-*.sh "$P8"/am2-*.sh "$P12"/wt1-*.sh "$P12"/wt2-*.sh; do check "$c"; done

# --- WT3 on a corrupted close ------------------------------------------------------------
edit_close() {   # edit_close <from> <to>: one replacement in worktime.close.compute's SQL
    docker exec -i -u 0 "$(ctr backoffice)" python3 - "$QUERIES" "$1" "$2" <<'EOF'
import sys
path, old, new = sys.argv[1:4]
text = open(path).read()
assert text.count(old) == 1, (old, text.count(old))
open(path, "w").write(text.replace(old, new))
EOF
}
edit_close "sum(night_hours) AS night" "sum(worked_hours) AS night"
check "$P12/wt3-month-code.sh" 1
edit_close "sum(worked_hours) AS night" "sum(night_hours) AS night"
check "$P12/wt3-month-code.sh" 0

errs=$(slog backoffice | grep ' error ' || true)
same "backoffice ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  /'
info "runs on backoffice since T0: $(slog backoffice | grep ' run job=' | grep phase=end | sed 's/.* run job=\([^ ]*\) .*status=\([^ ]*\).*/\1:\2/' | sort | uniq -c | tr -s ' ' | tr '\n' ',')"

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

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s from the deployment's start"
[ "$failures" -eq 0 ]
