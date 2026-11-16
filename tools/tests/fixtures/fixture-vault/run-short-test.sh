#!/bin/sh
# Short test of the vault fixture (v0.5 build plan, chunk 21a; capture W4
# item 6, "Purpose 14" and "The fixtures"; spec D403, D442): purpose 14
# (cold-storage-archive) shipping the machinery's last full day to cold
# storage and dropping it on a full receipt. On one host, about 15 minutes.
#
# T0 is placed by the shift (whole hours) at 21:MM local, MM the UTC minute
# about SETUP seconds after the render (20:MM when that minute is 50 or
# later), so that the shipping job, moved to the minute after T0, runs
# before the machinery's 22:00 partition jobs, on the same local day as the
# load.
#
# On a copy of tools/tests/fixtures/fixture-vault (bastion 0.6.0; records,
# machines and partners-db: postgres 0.5.1; interfaces: scheduler 0.4.0;
# partners-api: api 0.1.1 serving partners/coldstore/ under cold-storage;
# domains: vet-core at records/clinic, vet-machinery at
# machines/{pacs,vitals,biomed}; purpose 14 at machines/vitals,
# machines/biomed, partners-db/partners, interfaces, partners-api):
#   compose --check -> fit (the laptop playground, 2 CPU / 4G / 8G) -> render
#   (the shift placing T0) -> the stack's secrets (mach_archive's password
#   and cold_storage on interfaces) -> deploy -> load-data (its seconds),
#   then:
#   - purpose 14's DDL at step (2b): the ops schema with ops.shipments in
#     vitals and biomed, owned by ops; mach_archive logging in with a SCRAM
#     password, CONNECT on vitals and biomed only;
#   - its history at step (4): the vault's planted manifests, both types,
#     every day from the history's first day (the first session's, the
#     first aggregate's) to the day before yesterday, rows declared =
#     received (the readings' the aggregate's sums), source machines,
#     received at 00:40 local the night after the window;
#   - the partitions yesterday (D-1) to today plus three, D-1's rows;
#   - the set-up (spec D442): window_days set to 0 in mach_vitals_settings
#     and mach_settings, as postgres;
#   -> inject -> start-load (T0, its local time checked) -> ship-partitions
#   moved to the next minute on interfaces (its jobs.yaml, the scheduler
#   reloaded), then after its run:
#   - ops.shipments in vitals and biomed: D-1's row of each type
#     (vitals-<D-1>, machine-readings-<D-1>), all its rows received and
#     dropped; D-1's partitions gone from pg_inherits; D-1's
#     mach_readings_daily summing to the readings' rows sent;
#   - both D-1 manifests in coldstore.manifests, rows received = declared =
#     sent, source machines; cold storage's page (GET /) listing them;
#   - one ops.runs row of the run in each database, no incident; the job
#     ending ok, never in error nor skipped;
#   - the checks CA1 to CA3 (CHECK_SINCE at T0) and CA4 (CHECK_SINCE at
#     D-1's local midnight), as gmctl check runs them, on partners-db as
#     root, their cadence constants set to the moved run, each exit 0;
#   -> teardown, then nothing labelled with the game id is left. The
#   load-data's seconds and the whole run's are printed.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-vault/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=vault-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.4.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
JOBS=/srv/scheduler/jobs/jobs.yaml
CHECKS=$REPO/purposes/cold-storage-archive/checks
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SETUP=300            # seconds from the render to T0, about: deploy, load-data, the set-up
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-vault-short.XXXXXX")
SCN=$tmp/fixture-vault
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
msql() { docker exec -u postgres "$(ctr machines)" psql -XAtq -v ON_ERROR_STOP=1 -d "$1" -c "$2"; }
psql_p() { docker exec -u postgres "$(ctr partners-db)" psql -XAtq -v ON_ERROR_STOP=1 -d partners -c "$1"; }
nlog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
nstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }
# HTTP to cold storage through the network and its alias, from its own api
# node (the api image's Python): prints "<status> <body>".
web_get() { docker exec -i "$(ctr partners-api)" python3 -I - "$1" <<'EOF'
import http.client, sys
c = http.client.HTTPConnection("cold-storage", 8000, timeout=30)
c.request("GET", sys.argv[1], headers={"User-Agent": "short-test"})
r = c.getresponse()
sys.stdout.write(f"{r.status} {r.read().decode('utf-8', 'replace')}")
EOF
}

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/interfaces/ as compose writes it"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation; T0 placed by the shift ------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the six nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# The shift that puts T0 (about SETUP seconds from now) at 21:MM local (20:MM
# from minute 50), and the next hand-over moment that shift makes the
# designed 14:00.
set -- $(python3 - "$SETUP" <<'EOF'
import datetime, sys
setup = int(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc)
t0 = now + datetime.timedelta(seconds=setup)
target = 21 if t0.minute < 50 else 20
shift = (target - t0.hour + 11) % 24 - 11          # -11..12, render's compute_shift
moment = now.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=9)   # past the 8h aging floor
while (moment.hour + shift) % 24 != 14:
    moment += datetime.timedelta(hours=1)
local = t0 + datetime.timedelta(hours=shift)
print(moment.strftime("%Y-%m-%dT%H:00Z"), shift, local.strftime("%H:%M"), target)
EOF
)
HANDOVER=$1 SHIFT=$2 LOCAL_T0=$3 TARGET_HOUR=$4
info "render --handover $HANDOVER, shift $SHIFT: T0 expected about $LOCAL_T0 local"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "machines", "interfaces", "partners-api", "partners-db"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: mach_archive's password and cold_storage alone on interfaces (purpose 14)" \
    "interfaces http_cold_storage role_mach_archive_password" "$(line 4)"
same "stack: none on the bastion, records, machines" "bastion - records - machines -" "$(line 1) $(line 2) $(line 3)"
same "stack: cold_storage elsewhere only on cold storage's own node, partners-api" "partners-api" \
    "$(printf '%s\n' "$st" | grep -v '^interfaces ' | grep 'http_cold_storage' | cut -d' ' -f1 | tr '\n' ' ' | sed 's/ $//')"
info "stack: $(line 5); $(line 6)"

# --- deployment and load-data ----------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the six nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
case $(nstatus interfaces) in idle\ *) pass "interfaces idle before the load: $(nstatus interfaces)" ;;
    *) fail "interfaces before the load: [$(nstatus interfaces)]" ;; esac

info "gmctl load-data"
t=$(date +%s)
LOAD_START=$t
if $GMCTL load-data "$SCN" --playground "$PG"; then
    LOAD_SECS=$(( $(date +%s) - t ))
    pass "load-data: the core, the machinery's three databases, purpose 14's DDL and history ($LOAD_SECS s)"
else
    fail "load-data"
    exit 1
fi
info "size: $(msql postgres "SELECT string_agg(datname || ' ' || pg_size_pretty(pg_database_size(datname)), ', ' ORDER BY datname)
  FROM pg_database WHERE datname IN ('pacs', 'vitals', 'biomed', 'jobs')")"

# Purpose 14's DDL, load-data's step (2b), in vitals and biomed.
for db in vitals biomed; do
    same "load-data (2b): purpose 14's ops schema in $db, owned by ops, with ops.shipments" \
        "ops:ops incidents runs shipments watermarks" \
        "$(msql $db "SELECT n.nspname || ':' || pg_get_userbyid(n.nspowner) || ' ' || string_agg(c.relname, ' ' ORDER BY c.relname)
                       FROM pg_namespace n JOIN pg_class c ON c.relnamespace = n.oid AND c.relkind = 'r'
                      WHERE n.nspname = 'ops' GROUP BY n.nspname, n.nspowner")"
done
same "load-data (2b): mach_archive logs in with a SCRAM password, CONNECT (pacs vitals biomed jobs) on vitals and biomed only" \
    "mach_archive:true:true:fttf" \
    "$(msql postgres "SELECT rolname || ':' || rolcanlogin || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%') || ':'
                              || (CASE WHEN has_database_privilege(rolname, 'pacs', 'CONNECT') THEN 't' ELSE 'f' END)
                              || (CASE WHEN has_database_privilege(rolname, 'vitals', 'CONNECT') THEN 't' ELSE 'f' END)
                              || (CASE WHEN has_database_privilege(rolname, 'biomed', 'CONNECT') THEN 't' ELSE 'f' END)
                              || (CASE WHEN has_database_privilege(rolname, 'jobs', 'CONNECT') THEN 't' ELSE 'f' END)
                       FROM pg_authid WHERE rolname = 'mach_archive'")"

# The days: the customer's today at the load (D0) and yesterday (D-1).
D0=$(date -u -d "@$(( LOAD_START + SHIFT * 3600 ))" +%Y-%m-%d)
DM1=$(date -u -d "$D0 -1 day" +%Y-%m-%d)
DM2=$(date -u -d "$D0 -2 day" +%Y-%m-%d)
YM1=$(date -u -d "$DM1" +%Y%m%d)
info "the customer's days: today $D0, yesterday (D-1) $DM1"
same "settings: the customer's offset in vitals and biomed is the shift, the window 1 day" "$SHIFT:1 $SHIFT:1" \
    "$(msql vitals "SELECT utc_offset_hours || ':' || window_days FROM mach_vitals_settings") $(msql biomed "SELECT utc_offset_hours || ':' || window_days FROM mach_settings")"

# Purpose 14's history, load-data's step (4): the vault's planted manifests.
FIRST_V=$(msql vitals "SELECT min(((started_at AT TIME ZONE 'UTC') + make_interval(hours => $SHIFT))::date) FROM mach_sessions")
FIRST_R=$(msql biomed "SELECT min(day) FROM mach_readings_daily")
manifests() {   # manifests <type>: days, first, last, all declared = received, the sources
    psql_p "SELECT count(*) || ' ' || min(date_from) || ' ' || max(date_from) || ' ' || bool_and(rows_declared = rows_received AND date_from = date_to)
                   || ' ' || count(DISTINCT date_from) || ' ' || string_agg(DISTINCT source, ',')
              FROM coldstore.manifests WHERE type = '$1'"
}
ndays() { echo $(( ( $(date -u -d "$2" +%s) - $(date -u -d "$1" +%s) ) / 86400 + 1 )); }
same "history: vitals' manifests, one a day from the first session's day ($FIRST_V) to D-2 ($DM2), declared = received, source machines" \
    "$(ndays "$FIRST_V" "$DM2") $FIRST_V $DM2 true $(ndays "$FIRST_V" "$DM2") machines" "$(manifests vitals)"
same "history: machine-readings' manifests, one a day from the first aggregate's day ($FIRST_R) to D-2, declared = received, source machines" \
    "$(ndays "$FIRST_R" "$DM2") $FIRST_R $DM2 true $(ndays "$FIRST_R" "$DM2") machines" "$(manifests machine-readings)"
same "history: machine-readings' rows each day the sum of that day's mach_readings_daily" \
    "$(msql biomed "SELECT md5(string_agg(day || ':' || n, ',' ORDER BY day)) FROM (SELECT day, sum(rows) AS n FROM mach_readings_daily WHERE day < '$DM1' GROUP BY day) x")" \
    "$(psql_p "SELECT md5(string_agg(date_from || ':' || rows_declared, ',' ORDER BY date_from)) FROM coldstore.manifests WHERE type = 'machine-readings'")"
same "history: shipment ids <type>-<YYYYMMDD>" "0" \
    "$(psql_p "SELECT count(*) FROM coldstore.manifests WHERE shipment_id <> type || '-' || to_char(date_from, 'YYYYMMDD')")"
same "history: each received at 00:40 local the night after the window (a few seconds in)" "0" \
    "$(psql_p "SELECT count(*) FROM coldstore.manifests
                WHERE received_at - (((date_from + 2)::timestamp + interval '40 minutes' - make_interval(hours => $SHIFT)) AT TIME ZONE 'UTC')
                      NOT BETWEEN interval '0' AND interval '40 seconds'")"
info "history: $(psql_p "SELECT string_agg(type || ' ' || n || ' manifests, ' || r || ' rows', '; ' ORDER BY type)
                         FROM (SELECT type, count(*) n, sum(rows_declared) r FROM coldstore.manifests GROUP BY type) x")"

# The partitions and D-1's rows before the run.
parts() {   # parts <db> <table>
    msql "$1" "SELECT string_agg(c.relname, ' ' ORDER BY c.relname) FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
               WHERE i.inhparent = '$2'::regclass"
}
days() {   # days <table>: the expected partitions' names
    for k in -1 0 1 2 3; do printf '%s_%s ' "$1" "$(date -u -d "$D0 $k day" +%Y%m%d)"; done
    printf '%s_default' "$1"
}
same "partitions: mach_vitals from D-1 to today plus three, and its default" "$(days mach_vitals)" "$(parts vitals mach_vitals)"
same "partitions: mach_readings from D-1 to today plus three, and its default" "$(days mach_readings)" "$(parts biomed mach_readings)"
VROWS=$(msql vitals "SELECT count(*) FROM mach_vitals_$YM1")
RROWS=$(msql biomed "SELECT count(*) FROM mach_readings_$YM1")
[ "$VROWS" -gt 0 ] && [ "$RROWS" -gt 0 ] && pass "D-1's partitions hold rows: vitals $VROWS, readings $RROWS" \
    || fail "D-1's partitions: vitals $VROWS, readings $RROWS rows"
same "before the run: no shipment, no run of purpose 14" "0 0 0 0" \
    "$(msql vitals "SELECT (SELECT count(*) FROM ops.shipments) || ' ' || (SELECT count(*) FROM ops.runs)") $(msql biomed "SELECT (SELECT count(*) FROM ops.shipments) || ' ' || (SELECT count(*) FROM ops.runs)")"

# --- the set-up (spec D442): the window to 0, so D-1 ships ------------------------
msql vitals "UPDATE mach_vitals_settings SET window_days = 0" >/dev/null
msql biomed "UPDATE mach_settings SET window_days = 0" >/dev/null
same "set-up: window_days 0 in mach_vitals_settings and mach_settings (as postgres)" "0 0" \
    "$(msql vitals "SELECT window_days FROM mach_vitals_settings") $(msql biomed "SELECT window_days FROM mach_settings")"

# --- T0 ----------------------------------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
CHECK_SINCE=$(date -u -d "@$T0S" +%Y-%m-%dT%H:%M:%SZ)
LOCAL=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%H:%M)
LDATE=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%Y-%m-%d)
info "T0 $T0, $LOCAL local (shift $SHIFT)"
case "$LDATE $LOCAL" in "$D0 2"[01]:*) pass "T0 at $LOCAL local on the load's day ($D0), before the 22:00 partition jobs" ;;
    *) fail "T0 not 20:00-21:59 local on $D0: $LDATE $LOCAL" ;; esac
i=0
while [ "$i" -lt 30 ]; do
    case "$(nstatus interfaces)" in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(nstatus interfaces) in running\ *) pass "interfaces running: $(nstatus interfaces)" ;; *) fail "interfaces not running: [$(nstatus interfaces)]" ;; esac
same "interfaces loaded purpose 14's job" "ship-partitions" \
    "$(docker exec "$(ctr interfaces)" cat /run/scheduler/loaded 2>/dev/null | sed -n 's/^job \([^ ]*\) next=.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"

# --- ship-partitions moved to the next minute ----------------------------------------
move_ship() {   # the job's at to the next whole minute (UTC), interfaces reloaded; prints its cron expression
    now=$(date -u +%s)
    [ $((now % 60)) -gt 40 ] && now=$((now + 60))
    at=$((now + 60))
    M=$(date -u -d "@$at" +%-M); H=$(date -u -d "@$at" +%-H)
    docker exec -i -u 0 "$(ctr interfaces)" python3 - "$JOBS" "$M $H * * *" <<'EOF'
import sys, yaml
path, at = sys.argv[1], sys.argv[2]
doc = yaml.safe_load(open(path))
for job in doc["jobs"]:
    if job["key"] == "archive.ship":
        job["at"], job["timezone"] = at, "UTC"
text = open(path).read().split("jobs:")[0]
open(path, "w").write(text + yaml.safe_dump({"jobs": doc["jobs"]}, sort_keys=False))
EOF
    docker exec -u 0 "$(ctr interfaces)" /command/s6-svc -h /run/service/scheduler
    printf '%s' "$M $H * * *"
}
x=$(move_ship)
info "archive.ship moved to '$x' UTC"
j=0
while [ "$j" -lt 15 ]; do
    l=$(docker exec "$(ctr interfaces)" sed -n 's/^cron ship-partitions //p' /run/scheduler/loaded 2>/dev/null || true)
    [ "$l" = "UTC $x" ] && break
    sleep 1; j=$((j + 1))
done
same "interfaces reloaded with archive.ship at '$x' UTC" "UTC $x" "$l"
RUN_M=$(echo "$x" | cut -d' ' -f1)
RUN_H=$(( ( $(echo "$x" | cut -d' ' -f2) + SHIFT + 24 ) % 24 ))
info "the moved run: $(printf '%02d:%02d' "$RUN_H" "$RUN_M") local"
i=0
while [ "$i" -lt 240 ] && ! nlog interfaces | grep -q ' run job=ship-partitions .*phase=end'; do sleep 5; i=$((i + 5)); done
run=$(nlog interfaces | grep ' run job=ship-partitions .*phase=end' | head -n 1)
case $run in *status=ok*) pass "ship-partitions ran and ended ok ($(echo "$run" | cut -c1-200))" ;;
    *) fail "ship-partitions: no run ended ok within 240 s: [$run]" ;; esac
nlog interfaces | grep ' script job=ship-partitions ' | cut -c1-200 | sed 's/^/....  /'

# --- after the run --------------------------------------------------------------------
same "vitals: ops.shipments holds D-1's vitals shipment, all its rows received, dropped" \
    "vitals|vitals-$YM1|$VROWS|$VROWS|1|true" \
    "$(msql vitals "SELECT type || '|' || shipment_id || '|' || rows_sent || '|' || rows_received || '|' || attempts || '|' || (dropped_at IS NOT NULL)
                     FROM ops.shipments WHERE day = '$DM1'")"
same "biomed: ops.shipments holds D-1's machine-readings shipment, all its rows received, dropped" \
    "machine-readings|machine-readings-$YM1|$RROWS|$RROWS|1|true" \
    "$(msql biomed "SELECT type || '|' || shipment_id || '|' || rows_sent || '|' || rows_received || '|' || attempts || '|' || (dropped_at IS NOT NULL)
                     FROM ops.shipments WHERE day = '$DM1'")"
same "no other shipment in either database" "1 1" \
    "$(msql vitals "SELECT count(*) FROM ops.shipments") $(msql biomed "SELECT count(*) FROM ops.shipments")"
same "D-1's partitions gone from pg_inherits (and from the catalogue)" "0 0 - -" \
    "$(msql vitals "SELECT count(*) FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid WHERE c.relname = 'mach_vitals_$YM1'") $(msql biomed "SELECT count(*) FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid WHERE c.relname = 'mach_readings_$YM1'") $(msql vitals "SELECT coalesce(to_regclass('mach_vitals_$YM1')::text, '-')") $(msql biomed "SELECT coalesce(to_regclass('mach_readings_$YM1')::text, '-')")"
same "partitions left: mach_vitals and mach_readings today to today plus three, and the defaults" \
    "$(days mach_vitals | sed 's/^[^ ]* //') $(days mach_readings | sed 's/^[^ ]* //')" \
    "$(parts vitals mach_vitals) $(parts biomed mach_readings)"
same "mach_readings_daily for D-1 sums to the readings' rows sent, one row a machine" \
    "$RROWS $(msql biomed "SELECT count(*) FROM mach_machines WHERE id IN (SELECT machine_id FROM mach_readings_daily WHERE day = '$DM1')")" \
    "$(msql biomed "SELECT coalesce(sum(rows), 0) || ' ' || count(*) FROM mach_readings_daily WHERE day = '$DM1'")"
same "coldstore.manifests: both D-1 manifests, rows received = declared = sent, source machines" \
    "machine-readings-$YM1|machine-readings|machines|$RROWS|$RROWS|$DM1 vitals-$YM1|vitals|machines|$VROWS|$VROWS|$DM1" \
    "$(psql_p "SELECT string_agg(shipment_id || '|' || type || '|' || source || '|' || rows_declared || '|' || rows_received || '|' || date_from, ' ' ORDER BY shipment_id)
                FROM coldstore.manifests WHERE date_from = '$DM1'")"
page=$(web_get / 2>&1 || true)
verdict=$(printf '%s' "$page" | python3 -c '
import re, sys
text = sys.stdin.read()
status, _, body = text.partition(" ")
day, vrows, rrows = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
out = []
for kind, rows in (("vitals", vrows), ("machine-readings", rrows)):
    m = re.search(r"<h2>" + re.escape(kind) + r"</h2>(.*?)(?=<h2>|</body>)", body, re.S)
    row = f"<tr><td>{day}</td><td>{rows:,}</td><td>{rows:,}</td><td>1</td></tr>"
    out.append(f"{kind}:{bool(m and row in m.group(1))}")
print(status, " ".join(out))' "$DM1" "$VROWS" "$RROWS" 2>&1)
same "cold storage's page (GET /) lists D-1's shipments, declared = received, one each" \
    "200 vitals:True machine-readings:True" "$verdict"
same "ops.runs: one row of the run in each database (rows read, written)" \
    "ship-partitions:$VROWS:1 ship-partitions:$RROWS:1" \
    "$(msql vitals "SELECT string_agg(job || ':' || rows_read || ':' || rows_written, ' ') FROM ops.runs WHERE purpose = 'cold-storage-archive' AND started_at >= '$T0'::timestamptz") $(msql biomed "SELECT string_agg(job || ':' || rows_read || ':' || rows_written, ' ') FROM ops.runs WHERE purpose = 'cold-storage-archive' AND started_at >= '$T0'::timestamptz")"
same "ops.incidents: none" "0 0" \
    "$(msql vitals "SELECT count(*) FROM ops.incidents") $(msql biomed "SELECT count(*) FROM ops.incidents")"
ok=$(nlog interfaces | grep -c " run job=ship-partitions .*phase=end status=ok" || true)
bad=$(nlog interfaces | grep -E " (run|skip) job=ship-partitions " | grep -c 'status=error\|reason=' || true)
if [ "$ok" -gt 0 ] && [ "$bad" -eq 0 ]; then pass "interfaces: ship-partitions ran $ok time(s), never in error nor skipped"
else fail "interfaces: ship-partitions ran $ok times ok, $bad in error or skipped: $(nlog interfaces | grep " job=ship-partitions " | grep 'status=error\|reason=' | tail -n 1 | cut -c1-200)"; fi
calls=$(nlog interfaces | grep ' http job=ship-partitions ' || true)
same "interfaces: its two posts to cold storage answered 201" "2 0" \
    "$(printf '%s\n' "$calls" | grep -c 'status=201' || true) $(printf '%s\n' "$calls" | grep -vc 'status=201\|^$' || true)"

# The purpose's sealed checks, as gmctl check runs them: on partners-db as
# root, the job's cadence constants set to the moved run.
DM1_MIDNIGHT=$(date -u -d "@$(( $(date -u -d "$DM1 00:00:00" +%s) - SHIFT * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)
info "CA1 to CA3 judged since T0 ($CHECK_SINCE), CA4 since D-1's local midnight ($DM1_MIDNIGHT)"
for c in "$CHECKS"/ca*.sh; do
    b=$(basename "$c" .sh)
    case $b in ca4-*) since=$DM1_MIDNIGHT ;; *) since=$CHECK_SINCE ;; esac
    sed -e "s/^RUN_MINUTE=40 /RUN_MINUTE=$RUN_M /" -e "s/^RUN_FIRST_HOUR=0 /RUN_FIRST_HOUR=$RUN_H /" \
        -e "s/^RUN_LAST_HOUR=5 /RUN_LAST_HOUR=$RUN_H /" "$c" > "$tmp/$b.sh"
    [ "$(grep -c "^RUN_MINUTE=$RUN_M \|^RUN_FIRST_HOUR=$RUN_H \|^RUN_LAST_HOUR=$RUN_H " "$tmp/$b.sh")" = 3 ] \
        || fail "$b: its cadence constants not set to the moved run"
    set +e
    out=$(docker exec -i -u root -e "CHECK_SINCE=$since" "$(ctr partners-db)" sh -s < "$tmp/$b.sh" 2>&1)
    rc=$?
    set -e
    if [ "$rc" = 0 ]; then pass "$b exit 0: $(printf '%s' "$out" | tail -n 1 | cut -c1-240)"
    else fail "$b exit $rc (expected 0): $(printf '%s' "$out" | tail -n 3 | cut -c1-300)"; fi
done

errs=$(nlog interfaces | grep ' error ' || true)
same "interfaces ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 5 | cut -c1-300 | sed "s/^/....  interfaces: /"

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

info "load-data ${LOAD_SECS:-?} s; the whole run $(( $(date +%s) - started )) s"
info "$passes passed, $failures failed"
[ "$failures" -eq 0 ]
