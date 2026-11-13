#!/bin/sh
# Short test of a fault planted on the reports fixture (v0.5 build plan chunk
# 24; master spec 17.3 s3, s7 and s8, 18.1; capture W5 items 0 and 3 of
# specs/versions/v0.5/wave-log.md; spec D456, D459, D461): one fault a run,
# planted on a copy of tools/tests/fixtures/fixture-reports from its overlay,
# planted/<fault-id>/ (tools/tests/planted.py: the fault instance appended to
# scenario.yaml, its answer-key entry, its seed change: s3's in the scenario
# layer compose/backoffice/, s7's in nodes/records/, s8's in nodes/standby/),
# then `gmctl compose` on the copy; the fixture's committed files stay
# unfaulted. On one host, under 30 minutes with the deployment.
#
#   compose --check -> fit (2 CPU / 4G / 8G) -> render -> deploy -> load-data
#   -> inject -> start-load (T0), then, time placed, never waited for. s3 and
#   s8 read a feeder's yesterday, so (as run-short-test.sh) the hand-over is
#   planned for T0 at about 00:10 local and the test waits, if need be,
#   before render until a deployment starting then reaches T0 at about :10
#   (REPORTS_PREP_MINUTES, default 13); s7 reads no job and does not wait.
#   The fixes and the moved feeders are the players' (backoffice and the
#   database nodes are fixable, D456): as player, sed -i and the sudo
#   wrappers. A feeder writes its day once, so between a present and a fixed
#   reading the test removes, as the GM, unseen, in one transaction, that
#   day's output rows and its runs row (the players' rerun; W5 item 0).
#
#   purpose-herd-use-dropped (s3, about 20 minutes):
#   - inject runs the fault's script on records: the planted daily use from
#     last year's first day, and last year's report, rewritten as the faulty
#     query writes them; the report short of the record's herd use, its
#     reference (AMU<year>-NNNN) and its copy kept, the runs' counts their rows;
#   - a herd treatment yesterday (recorded if none, as the left-out pms would);
#   - present: feed-antimicrobial-use moved (as player): yesterday's day
#     without the herd treatments the record holds; gmctl check s3 present;
#   - the players' fix: the LEFT JOIN back (sed -i, sudo gm-reload-scheduler);
#     the day removed, the feeder moved again;
#   - fixed: the day holds every herd treatment under its herd's species;
#     gmctl check s3 fixed since the fix, AM2 too; the planted report still
#     short (its rerun recommended).
#
#   governance-statement-log-personal (s7, about 10 minutes after the load):
#   - log_statement all in effect on records; a practice software's writes as
#     vet_app (a new owner, its phone changed; vet_app given a password by the
#     test, unseen, pms being left out): the owner's name and phone in
#     records' server log; gmctl check s7 present;
#   - the players' fix: the line removed (sed -i), sudo gm-reload-db;
#   - fixed: the same writes for another owner leave neither name nor phone
#     in the log; gmctl check s7 fixed.
#
#   pg-standby-apply-delay (s8, about 20 minutes):
#   - load-data's standby wait passes with the delay in effect (the clone
#     reaches consistency undelayed); the standby streaming, the delay 1h;
#   - late entries for yesterday's last hour recorded on records after T0
#     (two dispensings at 23:40 and 23:50 local, as pms' night staff enter
#     them): present on records, absent on the standby, its received WAL
#     ahead of its replayed WAL; gmctl check s8 present;
#   - present: feed-medicines-register moved (as player): yesterday's
#     register without them; MR1 present;
#   - the players' fix: the line removed on the standby (sed -i), sudo
#     gm-reload-db: the backlog replayed at once, the entries on the standby;
#     gmctl check s8 fixed; the day removed, the feeder moved again;
#   - fixed: the register's day holds them; MR1 fixed since the fix.
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
# Usage: sh tools/tests/fixtures/fixture-reports/run-planted-test.sh <fault-id>
#   <fault-id>: purpose-herd-use-dropped | governance-statement-log-personal
#               | pg-standby-apply-delay
set -eu

FAULT=${1:-}
case $FAULT in
    purpose-herd-use-dropped) INST=s3 ;;
    governance-statement-log-personal) INST=s7 ;;
    pg-standby-apply-delay) INST=s8 ;;
    *) echo "usage: sh $0 purpose-herd-use-dropped|governance-statement-log-personal|pg-standby-apply-delay" >&2
       exit 2 ;;
esac

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=reports-planted
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
JOBS=/srv/scheduler/jobs/jobs.yaml
QUERIES=/srv/scheduler/repository/queries.yaml
PGCONF=/etc/postgresql/postgresql.conf
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
PREP=${REPORTS_PREP_MINUTES:-13}
P7=$REPO/purposes/vet-medicines-registers/checks
P8=$REPO/purposes/vet-antimicrobial-use/checks
UNSEEN="SET log_statement = 'none'; SET log_min_duration_statement = -1; SET pg_stat_statements.track = 'none';"

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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-reports-planted.XXXXXX")
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

ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2" -c "$3"; }
# unseen <node> <db> <sql>: as dbsql, statement logging and statistics off
# for the session (the GM's own steps, as load-data's).
unseen() { printf '%s\n%s\n' "$UNSEEN" "$3" | docker exec -i -u postgres "$(ctr "$1")" psql -XAtq -v ON_ERROR_STOP=1 -d "$2"; }
slog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
sstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
pglog() { docker exec -u 0 "$(ctr "$1")" sh -c 'cat /var/log/postgresql/*.log' 2>/dev/null || true; }
asplayer() { docker exec -u player "$(ctr "$1")" sh -c "$2"; }
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
# The fault's sealed check, as the GM runs it: `fcheck [<since>]` prints
# "<exit> <its line>".
fcheck() {
    set +e
    if [ -n "${1:-}" ]; then
        out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" --since "$1" 2>&1)
    else
        out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" 2>&1)
    fi
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | grep "^$INST " | head -n 1)"
}
# A purpose's check on backoffice: `pcheck <file> <since>` prints "<exit> <line>".
pcheck() {
    set +e
    out=$(docker exec -i -u root -e CHECK_SINCE="$2" "$(ctr backoffice)" sh -s < "$1" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | head -n 1)"
}
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
# move <job>: the job's at to the next whole minute (UTC), as the players
# move it: jobs.yaml rewritten as player (the jobs directory is theirs on a
# fixable node), sudo gm-reload-scheduler; the loaded job checked. Sets
# MOVED (epoch of the reload).
move() {
    now=$(date -u +%s)
    [ $((now % 60)) -gt 40 ] && now=$((now + 60))
    at=$((now + 60))
    expr="$(date -u -d "@$at" +%-M) $(date -u -d "@$at" +%-H) * * *"
    docker exec -i -u player "$(ctr backoffice)" python3 - "$JOBS" "$expr" "$1" <<'EOF'
import os, sys, yaml
path, at, name = sys.argv[1:4]
doc = yaml.safe_load(open(path))
for job in doc["jobs"]:
    if job["name"] == name:
        job["at"], job["timezone"] = at, "UTC"
text = open(path).read().split("jobs:")[0]
with open(path + ".new", "w") as fh:
    fh.write(text + yaml.safe_dump({"jobs": doc["jobs"]}, sort_keys=False))
os.replace(path + ".new", path)
EOF
    out=$(asplayer backoffice 'sudo -n /usr/local/sbin/gm-reload-scheduler' 2>&1) \
        || fail "gm-reload-scheduler as player: $out"
    MOVED=$(date -u +%s)
    j=0; l=
    while [ "$j" -lt 15 ]; do
        l=$(docker exec "$(ctr backoffice)" sed -n "s/^cron $1 //p" /run/scheduler/loaded 2>/dev/null || true)
        [ "$l" = "UTC $expr" ] && break
        sleep 1; j=$((j + 1))
    done
    same "as player: $1 moved to '$expr' UTC, reloaded with sudo gm-reload-scheduler" "UTC $expr" "$l"
}
# wait_ran <job> <since epoch>: its run, up to 150 s
wait_ran() {
    i=0
    while [ "$i" -lt 150 ] && [ -z "$(ran "$1" "$2")" ]; do sleep 5; i=$((i + 5)); done
    if [ -n "$(ran "$1" "$2")" ]; then pass "$1 ran after the move"
    else fail "$1 did not run within 150 s ($(slog backoffice | grep "$1" | tail -n 2))"; fi
}
# remove_day <table> <job> <day>: the day's output rows and the job's runs
# row since T0, as the GM, unseen, one transaction (W5 item 0).
remove_day() {
    unseen records office "BEGIN;
      DELETE FROM $1 WHERE day = '$3' AND run_id IN (SELECT id FROM runs WHERE job = '$2' AND started_at >= '$T0');
      DELETE FROM runs WHERE job = '$2' AND started_at >= '$T0';
      COMMIT;" >/dev/null
    same "the day $3 removed from $1 with its run, as the GM (the players' rerun)" "0 0" \
        "$(dbsql records office "SELECT (SELECT count(*) FROM $1 WHERE day = '$3') || ' ' || (SELECT count(*) FROM runs WHERE job = '$2' AND started_at >= '$T0')")"
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
same "the planted copy: f1 and $INST, difficulty $(sed -n 's/^  score: *//p' "$SCN/scenario.yaml")" "f1 $INST" \
    "$(python3 -c "import sys, yaml; print(' '.join(i['id'] for i in yaml.safe_load(open(sys.argv[1]))['fault_instances']))" "$SCN/scenario.yaml")"

# --- time placement ---------------------------------------------------------
# s3 and s8: T0 at about :10 real (local 00:10), as run-short-test.sh.
now=$(date +%s)
if [ "$INST" != s7 ]; then
    min=$(( (now + PREP * 60) / 60 % 60 ))
    if [ "$min" -lt 5 ] || [ "$min" -gt 15 ]; then
        start=$(( (now / 3600) * 3600 + ((10 - PREP + 60) % 60) * 60 ))
        [ "$start" -gt "$now" ] || start=$((start + 3600))
        info "waiting $(( start - now )) s so that T0 falls at about :10 (REPORTS_PREP_MINUTES $PREP)"
        sleep $(( start - now ))
    fi
fi
started=$(date +%s)
T0EST=$(( started + PREP * 60 ))
HANDOVER=$(python3 - "$T0EST" <<'EOF'
import datetime, sys
t0 = datetime.datetime.fromtimestamp(int(sys.argv[1]), datetime.timezone.utc)
shift = (0 - t0.hour + 11) % 24 - 11                  # local 00 at T0, in -11..12
planned_hour = (14 - shift) % 24                       # the designed hand-over, 14:00 local
moment = (t0 + datetime.timedelta(hours=9)).replace(minute=0, second=0, microsecond=0)
while moment.hour != planned_hour:
    moment += datetime.timedelta(hours=1)
print(moment.strftime("%Y-%m-%dT%H:00Z"))
EOF
)

# --- local implementation and deployment -------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the eight nodes fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME; planned hand-over $HANDOVER"
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
case $INST in
    s3) same "render planted s3: backoffice's live queries.yaml is the composed planted one" "yes" \
            "$(docker exec -u root "$(ctr backoffice)" cat "$QUERIES" | cmp -s - "$SCN/nodes/backoffice/queries.yaml" && echo yes || echo no)" ;;
    s7) same "render planted s7: log_statement all in effect on records" "all" "$(dbsql records postgres 'SHOW log_statement')" ;;
    s8) same "render planted s8: recovery_min_apply_delay 1h in the standby's seed" "1" \
            "$(docker exec -u root "$(ctr standby)" grep -c "^recovery_min_apply_delay = '1h'" "$PGCONF")" ;;
esac
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: the core and its parts, the lab, office, the planted periods, the standby cloned and streaming ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "the standby streaming from records, in recovery" "streaming t" \
    "$(dbsql records postgres "SELECT string_agg(state, ',') FROM pg_stat_replication") $(dbsql standby postgres "SELECT pg_is_in_recovery()" | sed 's/true/t/')"
if [ "$INST" = s8 ]; then
    same "load-data's standby wait passed with the delay in effect on the standby" "1h" \
        "$(dbsql standby postgres 'SHOW recovery_min_apply_delay')"
fi
t=$(date +%s)
set +e
injected=$($GMCTL inject "$SCN" --playground "$PG" 2>&1)
rc=$?
set -e
if [ "$rc" -eq 0 ]; then pass "inject ($(( $(date +%s) - t )) s)"; else fail "inject: $injected"; exit 1; fi
[ "$INST" != s3 ] || info "$(printf '%s\n' "$injected" | grep -m 1 'planted as the faulty query' | sed 's/^ *//')"
T0=$(now_iso)
T0S=$(date +%s)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0, $(( T0S - started )) s after the deployment began)"; else fail "start-load"; exit 1; fi
LOCAL=$(dbsql records clinic "SELECT to_char(now() AT TIME ZONE timezone, 'Dy YYYY-MM-DD HH24:MI') FROM business_settings")
Y=$(dbsql records clinic "SELECT (now() AT TIME ZONE timezone)::date - 1 FROM business_settings")
info "local time at T0: $LOCAL; yesterday $Y"
if [ "$INST" != s7 ]; then
    case $LOCAL in *\ 00:[012]?) pass "T0 before 00:30 local, the first feeder's hour ($LOCAL)" ;; *) fail "T0 not before 00:30 local ($LOCAL)" ;; esac
fi
i=0
while [ "$i" -lt 30 ]; do
    case $(sstatus backoffice) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(sstatus backoffice) in running\ *) pass "backoffice running" ;; *) fail "backoffice not running: [$(sstatus backoffice)]" ;; esac

case $INST in
s3)
# --- s3: the planted past -----------------------------------------------------
YEAR=$(dbsql records office "SELECT max(year) FROM amu_reports")
HERD_SQL="FROM dispensings d JOIN prescription_lines l ON l.id = d.prescription_line_id
      JOIN prescriptions p ON p.id = l.prescription_id JOIN medicines m ON m.id = l.medicine_id CROSS JOIN business_settings s
      WHERE p.herd_id IS NOT NULL AND p.animal_id IS NULL AND m.antimicrobial"
herd_year=$(dbsql records clinic "SELECT count(*) $HERD_SQL
      AND d.dispensed_at >= '$YEAR'::timestamp AT TIME ZONE s.timezone
      AND d.dispensed_at < ('$YEAR'::date + interval '1 year')::timestamp AT TIME ZONE s.timezone")
same "planted: last year's report ($YEAR) without a herd treated, the record holding $herd_year herd dispensings that year" "0 t" \
    "$(dbsql records office "SELECT coalesce(sum((l->>'herds_treated')::integer), 0) || ' ' || ($herd_year > 0)::text
       FROM amu_reports r, jsonb_array_elements(r.payload->'lines') l WHERE r.year = '$YEAR'" | sed 's/true$/t/')"
same "planted: its reference in the authority's form (AMU<year>-NNNN, D451), acknowledged, its copy as the report" "t" \
    "$(dbsql records office "SELECT bool_and(r.reference ~ ('^AMU' || to_char(r.sent_at, 'YYYY') || '-[0-9]{4}\$') AND r.acknowledged_at IS NOT NULL
                                    AND s.reference = r.reference AND s.payload = r.payload) AND count(*) > 0
       FROM amu_reports r LEFT JOIN regulatory_submissions s ON s.kind = 'amu-report' AND s.ref = r.payload->>'report_key'
      WHERE r.year = '$YEAR'")"
same "planted: the daily use from $YEAR without a herd treated, each feeder run's counts its rows" "0 0 t" \
    "$(dbsql records office "SELECT (SELECT coalesce(sum(herds_treated), 0) FROM antimicrobial_use WHERE day >= '$YEAR') || ' '
       || (SELECT count(*) FROM runs r WHERE r.job = 'feed-antimicrobial-use'
             AND r.rows_written <> (SELECT count(*) FROM antimicrobial_use u WHERE u.run_id = r.id)) || ' '
       || ((SELECT count(*) FROM antimicrobial_use WHERE day >= '$YEAR') > 0)::text" | sed 's/true$/t/')"
REPORT=$(dbsql records office "SELECT md5(payload::text) FROM amu_reports WHERE year = '$YEAR' ORDER BY species LIMIT 1")

# --- a herd treatment yesterday (the witness) ----------------------------------
herd() { dbsql "$1" clinic "SELECT count(*) $HERD_SQL
      AND d.dispensed_at >= '$Y'::timestamp AT TIME ZONE s.timezone AND d.dispensed_at < ('$Y'::date + 1)::timestamp AT TIME ZONE s.timezone"; }
n=$(herd records)
if [ "$n" -gt 0 ]; then
    pass "yesterday holds $n herd antimicrobial dispensing(s) (a herd-visit day)"
else
    dbsql records clinic "INSERT INTO dispensings (id, prescription_line_id, batch_id, quantity, owner_id, dispensed_by, dispensed_at)
      SELECT (SELECT max(id) + 1 FROM dispensings), d.prescription_line_id, d.batch_id, d.quantity, d.owner_id, d.dispensed_by,
             ('$Y'::date + time '11:00')::timestamp AT TIME ZONE s.timezone
        $HERD_SQL ORDER BY d.dispensed_at DESC LIMIT 1" >/dev/null
    same "a herd antimicrobial dispensing recorded yesterday at 11:00 local, as pms would" "1" "$(herd records)"
fi
i=0; while [ "$i" -lt 30 ] && [ "$(herd standby)" != "$(herd records)" ]; do sleep 1; i=$((i + 1)); done
same "the standby holds it" "$(herd records)" "$(herd standby)"
HERDS=$(herd records)
day_herds() { dbsql records office "SELECT coalesce(sum(herds_treated), 0) || ' ' || coalesce(sum(dispensings), 0) FROM antimicrobial_use WHERE day = '$Y'"; }

# --- s3 present ------------------------------------------------------------------
move feed-antimicrobial-use
wait_ran feed-antimicrobial-use "$MOVED"
set -- $(day_herds)
H1=$1 D1=$2
same "present: yesterday written without a herd treated ($D1 dispensings), the record holding $HERDS herd dispensings" "0" "$H1"
r=$(fcheck)
same "gmctl check s3 after the feeder's run: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "1" "${r%% *}"

# --- the players' fix ----------------------------------------------------------------
asplayer backoffice "sed -i 's/^          JOIN animals an ON an.id = p.animal_id\$/          LEFT JOIN animals an ON an.id = p.animal_id/' $QUERIES"
same "as player: the LEFT JOIN back in the feeder's query" "1" \
    "$(docker exec "$(ctr backoffice)" grep -c '^          LEFT JOIN animals an ON an.id = p.animal_id$' "$QUERIES")"
out=$(asplayer backoffice 'sudo -n /usr/local/sbin/gm-reload-scheduler' 2>&1) && pass "as player: sudo gm-reload-scheduler" \
    || fail "gm-reload-scheduler as player: $out"
FIXED_AT=$(now_iso)
remove_day antimicrobial_use feed-antimicrobial-use "$Y"

# --- s3 fixed --------------------------------------------------------------------
move feed-antimicrobial-use
wait_ran feed-antimicrobial-use "$MOVED"
set -- $(day_herds)
if [ "$1" -gt 0 ] && [ "$2" -ge $((D1 + HERDS)) ]; then
    pass "fixed: yesterday written again with its herd treatments ($1 herds, $2 dispensings for $D1 before)"
else
    fail "fixed: yesterday's herds and dispensings [$*], expected herds and at least $((D1 + HERDS)) dispensings"
fi
r=$(fcheck "$FIXED_AT")
same "gmctl check s3 since the fix: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "0" "${r%% *}"
r=$(pcheck "$P8/am2-species-traced.sh" "$FIXED_AT")
same "AM2 since the fix: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
same "the planted report still short, unchanged: its rerun the players' to recommend" "$REPORT 0" \
    "$(dbsql records office "SELECT md5(payload::text) FROM amu_reports WHERE year = '$YEAR' ORDER BY species LIMIT 1") $(dbsql records office "SELECT coalesce(sum((l->>'herds_treated')::integer), 0) FROM amu_reports r, jsonb_array_elements(r.payload->'lines') l WHERE r.year = '$YEAR'")"
;;

s7)
# --- s7: the practice software's writes ---------------------------------------------
PW=$(od -An -N12 -tx1 /dev/urandom | tr -d ' \n')
unseen records postgres "ALTER ROLE vet_app PASSWORD '$PW';" >/dev/null
# write <name> <phone> <new phone>: a new owner as pms registers one, then
# its phone changed, as vet_app over the local socket
write() {
    printf '%s\n' "SELECT set_config('application_name', 'pms', false);
      INSERT INTO owners (kind, name, email, phone, address, country, registered_at)
      VALUES ('person', '$1', lower(replace('$1', ' ', '.')) || '@example.org', '$2', '4 Lindenweg, 50667 Koeln', 'DE', now())
      RETURNING id \\gset
      UPDATE owners SET phone = '$3' WHERE id = :id;" |
        docker exec -i -e PGPASSWORD="$PW" "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -h /run/postgresql -U vet_app -d clinic >/dev/null
}
inlog() { pglog records | grep -c -e "$1" -e "$2" || true; }
write 'Ottilie Brennerkamp' '+49 170 5550101' '+49 170 5550102' && pass "as vet_app: an owner registered, its phone changed" \
    || fail "the writes as vet_app"
sleep 2
n=$(inlog 'Ottilie Brennerkamp' '5550102')
if [ "$n" -gt 0 ]; then pass "present: the owner's name and phone in records' server log ($n lines)"
else fail "present: neither the owner's name nor phone in records' log"; fi
info "$(pglog records | grep -m 1 'Brennerkamp' | cut -c1-200)"
r=$(fcheck)
same "gmctl check s7 at the planting: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "1" "${r%% *}"

# --- the players' fix ----------------------------------------------------------------
asplayer records "sed -i \"/^log_statement = 'all'/d\" $PGCONF"
same "as player: the line removed from records' postgresql.conf" "0" \
    "$(docker exec -u root "$(ctr records)" grep -c '^log_statement' "$PGCONF" || true)"
r=$(fcheck)
same "gmctl check s7 before the reload: still present (the setting in effect): $(echo "$r" | cut -d' ' -f2- | cut -c1-160)" "1" "${r%% *}"
out=$(asplayer records 'sudo -n /usr/local/sbin/gm-reload-db' 2>&1) && pass "as player: sudo gm-reload-db" \
    || fail "gm-reload-db as player: $out"
same "log_statement none in effect" "none" "$(dbsql records postgres 'SHOW log_statement')"

# --- s7 fixed --------------------------------------------------------------------
write 'Hennike Asmussen' '+49 170 5550103' '+49 170 5550104' && pass "as vet_app after the fix: another owner registered, its phone changed" \
    || fail "the writes as vet_app after the fix"
sleep 2
same "fixed: neither the new owner's name nor phone in records' server log" "0" "$(inlog 'Hennike Asmussen' '555010[34]')"
r=$(fcheck)
same "gmctl check s7 after the reload: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "0" "${r%% *}"
;;

s8)
# --- s8: late entries for yesterday's last hour -------------------------------------
late() {   # the late entries' ids on <node>
    dbsql "$1" clinic "SELECT coalesce(string_agg(id::text, ',' ORDER BY id), '') FROM dispensings WHERE id IN ($LATE)"
}
LATE=$(dbsql records clinic "WITH s AS (SELECT timezone AS tz FROM business_settings),
      src AS (SELECT d.* FROM dispensings d JOIN prescription_lines l ON l.id = d.prescription_line_id
               JOIN medicines m ON m.id = l.medicine_id, s
              WHERE NOT m.controlled AND d.dispensed_at >= '$Y'::timestamp AT TIME ZONE s.tz
                AND d.dispensed_at < ('$Y'::date + 1)::timestamp AT TIME ZONE s.tz
              ORDER BY d.dispensed_at DESC LIMIT 2),
      ins AS (INSERT INTO dispensings (id, prescription_line_id, batch_id, quantity, owner_id, dispensed_by, dispensed_at)
              SELECT (SELECT max(id) FROM dispensings) + row_number() OVER (ORDER BY src.id), prescription_line_id, batch_id,
                     quantity, owner_id, dispensed_by,
                     ('$Y'::date + time '23:30' + row_number() OVER (ORDER BY src.id) * interval '10 minutes')::timestamp AT TIME ZONE s.tz
                FROM src, s RETURNING id)
      SELECT string_agg(id::text, ',' ORDER BY id) FROM ins")
info "recorded after T0 on records: dispensings $LATE, dated yesterday 23:40 and 23:50 local"
sleep 5
same "present: the late entries on records" "$LATE" "$(late records)"
same "present: absent on the standby" "" "$(late standby)"
same "present: the standby's received WAL ahead of its replayed WAL, the delay 1h in effect" "t 1h" \
    "$(dbsql standby postgres "SELECT (pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) > 0)::text || ' ' || current_setting('recovery_min_apply_delay')" | sed 's/^true/t/')"
info "standby: $(dbsql standby postgres "SELECT 'received ' || pg_last_wal_receive_lsn() || ', replayed ' || pg_last_wal_replay_lsn() || ', last replayed commit ' || coalesce(pg_last_xact_replay_timestamp()::text, '-')")"
r=$(fcheck)
same "gmctl check s8: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "1" "${r%% *}"
reg() { dbsql records office "SELECT count(*) FROM medicines_register WHERE day = '$Y' AND supply = 'dispensing' AND supply_id IN ($LATE)"; }

move feed-medicines-register
wait_ran feed-medicines-register "$MOVED"
REG1=$(dbsql records office "SELECT count(*) FROM medicines_register WHERE day = '$Y'")
same "present: the register's day written ($REG1 lines) without the late entries" "0" "$(reg)"
r=$(pcheck "$P7/mr1-supplies-once.sh" "$T0")
same "MR1 since T0: present: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "1" "${r%% *}"

# --- the players' fix ----------------------------------------------------------------
asplayer standby "sed -i '/^recovery_min_apply_delay/d' $PGCONF"
out=$(asplayer standby 'sudo -n /usr/local/sbin/gm-reload-db' 2>&1) && pass "as player: the delay removed from the standby, sudo gm-reload-db" \
    || fail "gm-reload-db as player on the standby: $out"
w=$(date +%s); i=0
while [ "$i" -lt 30 ] && [ "$(late standby)" != "$LATE" ]; do sleep 1; i=$((i + 1)); done
same "fixed: the backlog replayed at once ($(( $(date +%s) - w )) s): the late entries on the standby" "$LATE" "$(late standby)"
same "fixed: the delay 0 in effect, nothing received left unreplayed" "0 t" \
    "$(dbsql standby postgres "SELECT current_setting('recovery_min_apply_delay') || ' ' || (pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn()) <= 0)::text" | sed 's/true$/t/')"
r=$(fcheck)
same "gmctl check s8 after the reload: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-220)" "0" "${r%% *}"
remove_day medicines_register feed-medicines-register "$Y"
FIXED_AT=$(now_iso)

# --- s8 fixed: the day rerun ---------------------------------------------------------
move feed-medicines-register
wait_ran feed-medicines-register "$MOVED"
REG2=$(dbsql records office "SELECT count(*) FROM medicines_register WHERE day = '$Y'")
same "fixed: the register's day written again ($REG2 lines, $REG1 before) with the late entries" "2 $((REG1 + 2))" "$(reg) $REG2"
r=$(pcheck "$P7/mr1-supplies-once.sh" "$FIXED_AT")
same "MR1 since the fix: fixed: $(echo "$r" | cut -d' ' -f2- | cut -c1-200)" "0" "${r%% *}"
;;
esac

errs=$(slog backoffice | grep ' error ' || true)
same "backoffice ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  /'

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

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s from the deployment's start"
[ "$failures" -eq 0 ]
