#!/bin/sh
# Short test of the imaging fixture (v0.5 build plan, chunk 15b; master spec
# 9.6; vet-machinery-domain.md, "Testing in v0.5"; capture W3 item 4, W3-d):
# vet-core's record and vet-machinery's three databases loaded by gmctl
# load-data from the domains (the core's schema, keys.sql and load into
# records/clinic; on machines, pacs, vitals and biomed each created, CONNECT
# revoked from PUBLIC, its schema and load with the core's keys streamed
# ahead; then data/cron.sql, the three partition jobs scheduled in jobs,
# pg_cron's database), the machines and their systems, equipment, the
# practice software, pms, the idle integration engine, interfaces, and the
# lookup API, clinic-api, composed by gmctl compose from the domains'
# producers. On one host, about 15 minutes.
#
# T0 is placed by the shift (whole hours) within 30 minutes of 08:50 local
# on a weekday (the driver's ruling, wave log, chunk 15): the local minute at
# T0 is the UTC minute, about SETUP seconds after the render (the estimate
# drifts by a minute or two), so the local hour is 08 when that minute is 14
# or later, 09 before; with 08, a deployment faster than the estimate holds
# start-load until 08:21 local (a few minutes at most), so that T0 never
# falls before 08:20. The local date then follows; on a Saturday or a
# Sunday there the test refuses to run (exit 2), since the imaging day it
# stands for is a weekday's.
#
# On a copy of tools/tests/fixtures/fixture-imaging (bastion 0.5.0, records
# and machines: postgres 0.5.0, clinic-api: api 0.1.0, pms, equipment and
# interfaces: scheduler 0.3.0, domains: vet-core at records/clinic,
# vet-machinery at machines/{pacs,vitals,biomed}):
#   compose --check -> fit (the laptop playground, 2 CPU / 4G / 8G) -> render
#   (the shift placing T0) -> deploy -> load-data (its time and the three
#   databases' sizes), then:
#   - the stack file: the three application roles' passwords and
#     clinic_lookup on equipment only, clinic_lookup alone on interfaces,
#     mach_maint's and mach_service's mounted nowhere, none on the bastion,
#     records or machines;
#   - load-data: the coherence check passed (seven checks); CONNECT revoked
#     from PUBLIC on pacs, vitals, biomed and jobs, each role's CONNECT where W3-d gives it and nowhere else; every login
#     role with a SCRAM password; cron.job holding the three partition jobs
#     (as mach_maint, in vitals and biomed, at their times); the partitions
#     from yesterday to today plus three of mach_vitals and mach_readings by
#     the customer's day, mach_events to next month, each default empty; no
#     key function left; no statement of the load in machines' log;
#   - three worklist entries planted as postgres in pacs (standing for the
#     imaging-orders purpose, chunk 21): a person's dog, a horse, a farm
#     animal, without their identity;
#   - inject -> start-load (T0, its local time checked), then: the identity
#     job filling each planted entry from clinic-api (the record's animal and
#     current owner, DICOM's form) within two minutes; the census job's first
#     run after T0 answered by clinic-api, mach_census's current stays those
#     of the record at that run; the readings of 11 machines a minute; pms,
#     equipment and interfaces without an error, interfaces without a call;
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
# Usage: sh tools/tests/fixtures/fixture-imaging/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=imaging-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SETUP=330            # seconds from the render to T0, about: deploy, load-data, the plants
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-imaging-short.XXXXXX")
SCN=$tmp/fixture-imaging
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
msql() { docker exec -u postgres "$(ctr machines)" psql -XAtq -d "$1" -c "$2"; }
nlog() { docker exec "$(ctr "$1")" cat "$SCHEDLOG" 2>/dev/null || true; }
nstatus() { docker exec "$(ctr "$1")" cat /run/scheduler/status 2>/dev/null || true; }

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/clinic-api/, nodes/pms/, nodes/equipment/ and nodes/interfaces/ as compose writes them"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation; T0 placed by the shift ------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the seven nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# The shift that puts T0 (about SETUP seconds from now) within 30 minutes of
# 08:50 local, the local weekday it falls on, and the next hand-over moment
# that shift makes the designed 14:00.
set -- $(python3 - "$SETUP" <<'EOF'
import datetime, sys
setup = int(sys.argv[1])
now = datetime.datetime.now(datetime.timezone.utc)
t0 = now + datetime.timedelta(seconds=setup)
target = 8 if t0.minute >= 14 else 9                # 08:21-08:59 (held to 08:21) or 09:00-09:13
shift = (target - t0.hour + 11) % 24 - 11          # -11..12, render's compute_shift
moment = now.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=9)   # past the 8h aging floor
while (moment.hour + shift) % 24 != 14:
    moment += datetime.timedelta(hours=1)
local = t0 + datetime.timedelta(hours=shift)
print(moment.strftime("%Y-%m-%dT%H:00Z"), shift, local.strftime("%H:%M"), local.strftime("%a"),
      local.isoweekday(), target)
EOF
)
HANDOVER=$1 SHIFT=$2 LOCAL_T0=$3 LOCAL_DAY=$4 ISODOW=$5 TARGET_HOUR=$6
if [ "$ISODOW" -gt 5 ]; then
    echo "T0 would fall on a $LOCAL_DAY locally (shift $SHIFT, $LOCAL_T0): the fixture's imaging day is a weekday's; run it on another day" >&2
    exit 2
fi
info "render --handover $HANDOVER, shift $SHIFT: T0 expected about $LOCAL_T0 local, a $LOCAL_DAY"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "clinic-api", "pms", "machines", "equipment", "interfaces"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: none on the bastion" "bastion -" "$(line 1)"
same "stack: none on records (load-data sets the roles' passwords)" "records -" "$(line 2)"
same "stack: vet_lookup's password and clinic_lookup on clinic-api" \
    "clinic-api http_clinic_lookup role_vet_lookup_password" "$(line 3)"
same "stack: vet_app's password on pms" "pms role_vet_app_password" "$(line 4)"
same "stack: none on machines" "machines -" "$(line 5)"
same "stack: the three application roles' passwords and clinic_lookup on equipment" \
    "equipment http_clinic_lookup role_mach_biomed_app_password role_mach_pacs_app_password role_mach_vitals_app_password" \
    "$(line 6)"
same "stack: clinic_lookup alone on interfaces (idle)" "interfaces http_clinic_lookup" "$(line 7)"
same "stack: mach_maint's and mach_service's passwords mounted on no node" "0" \
    "$(printf '%s\n' "$st" | grep -c 'mach_maint\|mach_service' || true)"

# --- deployment and load-data ----------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the seven nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
for n in pms equipment interfaces; do
    case $(nstatus $n) in idle\ *) pass "$n idle before the load: $(nstatus $n)" ;;
        *) fail "$n before the load: [$(nstatus $n)]" ;; esac
done

info "gmctl load-data"
t=$(date +%s)
LOAD_START=$t
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core and the machinery's three databases loaded ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
same "load-data: the coherence check passed, its seven checks" \
    "pass: sessions-on-stays:pass census-on-current-stays:pass vitals-window-rows:pass readings-window-rows:pass entries-on-imaging-requests:pass sent-requests-on-the-worklist:pass finals-before-resulted:pass" \
    "$(python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])).get("coherence") or {}
print(f"{c.get('result')}: " + " ".join(f"{k.get('check')}:{k.get('result')}" for k in c.get("checks") or []))
EOF
)"
rows=$(msql pacs "SELECT (SELECT count(*) FROM mach_worklist) || ' ' || (SELECT count(*) FROM mach_studies) || ' '
  || (SELECT count(*) FROM mach_reports)")
info "pacs rows: worklist studies reports: $rows"
info "vitals rows: sessions census chart: $(msql vitals "SELECT (SELECT count(*) FROM mach_sessions) || ' '
  || (SELECT count(*) FROM mach_census) || ' ' || (SELECT count(*) FROM mach_vitals_chart)")"
info "size: $(msql postgres "SELECT string_agg(datname || ' ' || pg_size_pretty(pg_database_size(datname)), ', ' ORDER BY datname)
  FROM pg_database WHERE datname IN ('pacs', 'vitals', 'biomed', 'jobs')"), clinic $(dbsql clinic "SELECT pg_size_pretty(pg_database_size('clinic'))")"
same "load-data: 30 procedures and 28 machines" "30 28" \
    "$(msql pacs "SELECT count(*) FROM mach_procedures") $(msql biomed "SELECT count(*) FROM mach_machines")"

# CONNECT: never PUBLIC's; each role's where capture W3-d gives it.
same "load-data: CONNECT revoked from PUBLIC on pacs, vitals, biomed and jobs" "f f f f" \
    "$(msql postgres "SELECT has_database_privilege('public', 'pacs', 'CONNECT'), has_database_privilege('public', 'vitals', 'CONNECT'),
                             has_database_privilege('public', 'biomed', 'CONNECT'), has_database_privilege('public', 'jobs', 'CONNECT')" | tr '|' ' ')"
same "load-data: each role's CONNECT (pacs vitals biomed) where W3-d gives it" \
    "mach_biomed_app:fft mach_maint:ftt mach_pacs_app:tff mach_service:fft mach_vitals_app:ftf" \
    "$(msql postgres "SELECT string_agg(rolname || ':' || (CASE WHEN has_database_privilege(rolname, 'pacs', 'CONNECT') THEN 't' ELSE 'f' END)
                                   || (CASE WHEN has_database_privilege(rolname, 'vitals', 'CONNECT') THEN 't' ELSE 'f' END)
                                   || (CASE WHEN has_database_privilege(rolname, 'biomed', 'CONNECT') THEN 't' ELSE 'f' END), ' ' ORDER BY rolname)
                       FROM pg_roles WHERE rolname LIKE 'mach\_%'")"
same "load-data: every machinery login role has a SCRAM password" \
    "mach_biomed_app:true mach_maint:true mach_pacs_app:true mach_service:true mach_vitals_app:true" \
    "$(msql postgres "SELECT string_agg(rolname || ':' || (rolpassword LIKE 'SCRAM-SHA-256\$%'), ' ' ORDER BY rolname)
                       FROM pg_authid WHERE rolname LIKE 'mach\_%' AND rolcanlogin")"

# pg_cron: the part's three jobs, scheduled by load-data in jobs.
same "load-data: cron.job holds the three partition jobs" \
    "events-partitions biomed mach_maint 0 22 25 * *|readings-partitions biomed mach_maint 5 22 * * *|vitals-partitions vitals mach_maint 0 22 * * *" \
    "$(msql jobs "SELECT string_agg(jobname || ' ' || database || ' ' || username || ' ' || schedule, '|' ORDER BY jobname)
                  FROM cron.job WHERE active")"

# The partitions: yesterday to today plus three by the customer's day, the
# events' months to next month, each default empty.
LOCAL_DAY0=$(date -u -d "@$(( LOAD_START + SHIFT * 3600 ))" +%Y-%m-%d)
days() {   # days <table>: the expected partitions' names
    for k in -1 0 1 2 3; do printf '%s_%s ' "$1" "$(date -u -d "$LOCAL_DAY0 $k day" +%Y%m%d)"; done
    printf '%s_default' "$1"
}
parts() {   # parts <db> <table>
    msql "$1" "SELECT string_agg(c.relname, ' ' ORDER BY c.relname) FROM pg_inherits i JOIN pg_class c ON c.oid = i.inhrelid
               WHERE i.inhparent = '$2'::regclass"
}
same "partitions: mach_vitals from yesterday to today plus three ($LOCAL_DAY0 local), and its default" \
    "$(days mach_vitals)" "$(parts vitals mach_vitals)"
same "partitions: mach_readings from yesterday to today plus three, and its default" \
    "$(days mach_readings)" "$(parts biomed mach_readings)"
THIS_MONTH=$(date -u -d "$LOCAL_DAY0" +%Y%m)
NEXT_MONTH=$(date -u -d "$(date -u -d "$LOCAL_DAY0" +%Y-%m-01) 1 month" +%Y%m)
ev=$(parts biomed mach_events)
case " $ev " in
    *" mach_events_$THIS_MONTH mach_events_$NEXT_MONTH mach_events_default "*)
        pass "partitions: mach_events to next month ($THIS_MONTH, $NEXT_MONTH, then the default; $(echo "$ev" | wc -w) partitions)" ;;
    *) fail "partitions: mach_events not ending with $THIS_MONTH, $NEXT_MONTH and the default: [$ev]" ;;
esac
same "partitions: the three defaults empty" "0 0 0" \
    "$(msql vitals "SELECT count(*) FROM mach_vitals_default") $(msql biomed "SELECT count(*) FROM mach_readings_default") $(msql biomed "SELECT count(*) FROM mach_events_default")"

same "load-data: no key function left in the three databases" "0 0 0" \
    "$(for db in pacs vitals biomed; do msql $db "SELECT count(*) FROM pg_proc WHERE proname LIKE 'core\_%' OR proname LIKE 'vc\_%' OR proname = 'm_u'"; done | tr '\n' ' ' | sed 's/ $//')"
seen=$(docker exec "$(ctr machines)" sh -c 'cat /var/log/postgresql/*.log 2>/dev/null | grep "INSERT INTO mach_\|pg_temp\.core_\|pg_temp\.m_u\|schedule_in_database" || true')
same "load-data: the load unseen (no statement of it in machines' log)" "0" \
    "$(printf '%s' "$seen" | grep -c . || true)"
[ -z "$seen" ] || printf '%s\n' "$seen" | cut -c1-300 | head -n 8 | sed 's/^/....  log: /'

# --- the plants: three new worklist entries without their identity ---------------
# Standing for the imaging-orders purpose (chunk 21): a person's dog, a horse
# and a farm animal, each alive, with a consultation of its own; request ids
# 990001-990003, outside the core's.
wit=$(dbsql clinic "SELECT string_agg(x.id || ':' || x.cid || ':' || x.vet_id || ':' || x.proc, ' ' ORDER BY x.ord) FROM (
  (SELECT 1 AS ord, a.id, c.id AS cid, c.vet_id, 1 AS proc FROM animals a
    JOIN ownerships o ON o.animal_id = a.id AND o.role = 'owner' AND o.until_at IS NULL
    JOIN owners w ON w.id = o.owner_id AND w.kind = 'person'
    JOIN LATERAL (SELECT id, vet_id FROM consultations WHERE animal_id = a.id ORDER BY id DESC LIMIT 1) c ON true
   WHERE a.species = 'dog' AND a.status <> 'died' ORDER BY a.id OFFSET 200 LIMIT 1)
  UNION ALL
  (SELECT 2, a.id, c.id, c.vet_id, 13 FROM animals a
    JOIN LATERAL (SELECT id, vet_id FROM consultations WHERE animal_id = a.id ORDER BY id DESC LIMIT 1) c ON true
   WHERE a.species = 'horse' AND a.status <> 'died' ORDER BY a.id OFFSET 40 LIMIT 1)
  UNION ALL
  (SELECT 3, a.id, c.id, c.vet_id, 13 FROM animals a
    JOIN LATERAL (SELECT id, vet_id FROM consultations WHERE animal_id = a.id ORDER BY id DESC LIMIT 1) c ON true
   WHERE a.herd_id IS NOT NULL AND a.status <> 'died' ORDER BY a.id OFFSET 20 LIMIT 1)) x")
info "witnesses (animal:consultation:vet:procedure): $wit"
values=$(printf '%s\n' $wit | awk -F: '{ printf "%s(%d, %d, %d, %d, %d)", (NR > 1 ? ", " : ""), 990000 + NR, $2, $1, $3, $4 }')
same "plants: three worklist entries without their identity" "3" \
    "$(msql pacs "WITH p (request_id, consultation_id, animal_id, requested_by, procedure_id) AS (VALUES $values)
                  INSERT INTO mach_worklist (accession, request_id, consultation_id, animal_id, requested_by, procedure_id,
                                             priority, created_at)
                  SELECT 'I-' || request_id, request_id, consultation_id, animal_id, requested_by, procedure_id, 'routine', now()
                    FROM p RETURNING 1" | grep -cx 1)"
ANIMALS=$(printf '%s\n' $wit | cut -d: -f1 | tr '\n' ',' | sed 's/,$//')

# --- T0 ----------------------------------------------------------------------------
# T0 at 08:21 local at the earliest (above): a fast deployment holds here.
if [ "$TARGET_HOUR" = 8 ]; then
    i=0
    while [ "$i" -lt 600 ]; do
        lm=$(( $(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%-H) * 60 + $(date -u -d "@$(( $(date +%s) + SHIFT * 3600 ))" +%-M) ))
        [ "$lm" -ge $(( 8 * 60 + 21 )) ] && break
        sleep 10; i=$((i + 10))
    done
    [ "$i" -eq 0 ] || info "start-load held $i s, until 08:21 local"
fi
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
LOCAL=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%H:%M)
LDOW=$(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%u)
LMIN=$(( $(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%-H) * 60 + $(date -u -d "@$(( T0S + SHIFT * 3600 ))" +%-M) ))
info "T0 $T0, $LOCAL local (shift $SHIFT), day $LDOW of the week"
if [ "$LDOW" -le 5 ] && [ "$LMIN" -ge $(( 8 * 60 + 20 )) ] && [ "$LMIN" -le $(( 9 * 60 + 20 )) ]; then
    pass "T0 placed within 30 minutes of 08:50 local on a weekday ($LOCAL)"
else
    fail "T0 not within 30 minutes of 08:50 local on a weekday: $LOCAL, day $LDOW"
fi
i=0
while [ "$i" -lt 30 ]; do
    case "$(nstatus pms) $(nstatus equipment) $(nstatus interfaces)" in running\ *running\ *running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
for n in pms equipment interfaces; do
    case $(nstatus $n) in running\ *) pass "$n running: $(nstatus $n)" ;; *) fail "$n not running: [$(nstatus $n)]" ;; esac
done
same "equipment loaded its three jobs" "mach-census mach-identity vitals-chart" \
    "$(docker exec "$(ctr equipment)" cat /run/scheduler/loaded 2>/dev/null | sed -n 's/^job \([^ ]*\) next=.*/\1/p' | sort | tr '\n' ' ' | sed 's/ $//')"

# --- the identity job: each planted entry filled from clinic-api ------------------
i=0
while [ "$i" -lt 150 ]; do
    [ "$(msql pacs "SELECT count(*) FROM mach_worklist WHERE request_id > 990000 AND identity_at IS NOT NULL")" = 3 ] && break
    sleep 5; i=$((i + 5))
done
got=$(msql pacs "SELECT json_agg(json_build_object('animal_id', animal_id, 'patient_id', patient_id, 'patient_name', patient_name,
    'species', species, 'breed', breed, 'sex', sex, 'born_on', born_on, 'microchip', microchip, 'ueln', ueln,
    'ear_tag', ear_tag, 'responsible_person', responsible_person, 'identity_at', identity_at) ORDER BY request_id)
  FROM mach_worklist WHERE request_id > 990000")
want=$(dbsql clinic "SELECT json_agg(json_build_object('animal_id', a.id, 'name', a.name, 'species', a.species, 'breed', a.breed,
    'sex', a.sex, 'born_on', a.born_on, 'microchip', a.microchip, 'ueln', a.ueln, 'ear_tag', a.ear_tag,
    'owner', w.name, 'kind', w.kind))
  FROM animals a JOIN ownerships o ON o.animal_id = a.id AND o.role = 'owner' AND o.until_at IS NULL
  JOIN owners w ON w.id = o.owner_id WHERE a.id IN ($ANIMALS)")
verdict=$(python3 - "$got" "$want" <<'EOF'
import json, sys
got, want = json.loads(sys.argv[1]) or [], {w["animal_id"]: w for w in json.loads(sys.argv[2]) or []}
out = []
for g in got:
    w = want.get(g["animal_id"])
    if g["identity_at"] is None or w is None:
        out.append(f"FAIL  identity: animal {g['animal_id']}'s entry not filled ({g})")
        continue
    family = w["owner"].split()[-1] if w["kind"] == "person" else w["owner"]
    expect = {"patient_id": f"A-{w['animal_id']}", "patient_name": f"{family}^{w['name']}",
              "responsible_person": w["owner"],
              **{k: w[k] for k in ("species", "breed", "sex", "born_on", "microchip", "ueln", "ear_tag")}}
    diff = {k: (g[k], v) for k, v in expect.items() if g[k] != v}
    out.append(("PASS" if not diff else "FAIL") + f"  identity: animal {w['animal_id']} ({w['species']}, a {w['kind']}'s) "
               + (f"filled from clinic-api as the record holds it: {g['patient_name']}, {g['responsible_person']}"
                  if not diff else f"differs from the record: {diff}"))
if len(got) != 3:
    out.append(f"FAIL  identity: {len(got)} planted entries, not 3")
print("\n".join(out))
EOF
)
printf '%s\n' "$verdict"
passes=$((passes + $(printf '%s\n' "$verdict" | grep -c '^PASS' || true)))
failures=$((failures + $(printf '%s\n' "$verdict" | grep -c '^FAIL' || true)))
calls=$(nlog equipment | grep ' http job=mach-identity ' || true)
same "identity: its lookups answered by clinic-api (200), an animal and its owner for each entry" "6 0" \
    "$(printf '%s\n' "$calls" | grep -c 'status=200' || true) $(printf '%s\n' "$calls" | grep -vc 'status=200\|^$' || true)"

# --- the census: its first run after T0, answered by clinic-api -----------------
i=0
while [ "$i" -lt 330 ]; do
    nlog equipment | grep -q ' run job=mach-census .*phase=end' && break
    sleep 10; i=$((i + 10))
done
run=$(nlog equipment | grep ' run job=mach-census .*phase=end' | head -n 1)
case $run in *status=ok*) pass "census: its first run after T0 ended ok ($(echo "$run" | cut -d' ' -f1,6-))" ;;
    *) fail "census: no run ended ok within 330 s of T0: [$run]" ;; esac
cline=$(nlog equipment | grep ' http job=mach-census ' | head -n 1)
case $cline in *status=200*'path="/stays?current=true"'*) pass "census: GET /stays?current=true answered 200 by clinic-api" ;;
    *) fail "census: the lookup [$cline]" ;; esac
info "census: $(nlog equipment | grep ' script job=mach-census ' | head -n 1 | cut -d' ' -f4-)"
S=$(msql vitals "SELECT max(seen_at) FROM mach_census")
same "census: mach_census's current stays are the record's at its run ($S)" \
    "$(dbsql clinic "SELECT string_agg(id::text, ' ' ORDER BY id) FROM stays
                     WHERE admitted_at <= '$S'::timestamptz AND (discharged_at IS NULL OR discharged_at > '$S'::timestamptz)")" \
    "$(msql vitals "SELECT string_agg(stay_id::text, ' ' ORDER BY stay_id) FROM mach_census WHERE left_at IS NULL")"
same "census: every current stay seen at that run" "0" \
    "$(msql vitals "SELECT count(*) FROM mach_census WHERE left_at IS NULL AND seen_at <> '$S'::timestamptz")"
info "sessions open: $(msql vitals "SELECT coalesce(string_agg(kind || ' ' || n, ', '), 'none') FROM (SELECT kind, count(*) n FROM mach_sessions WHERE ended_at IS NULL GROUP BY kind ORDER BY kind) x")"

# --- the run's other work -----------------------------------------------------------
same "readings: 11 machines reporting since T0 (machine 10 among them, O227)" "11 true" \
    "$(msql biomed "SELECT count(DISTINCT machine_id) || ' ' || bool_or(machine_id = 10) FROM mach_readings WHERE read_at >= '$T0'::timestamptz")"
info "since T0: $(msql vitals "SELECT count(*) FROM mach_vitals WHERE at >= '$T0'::timestamptz") vitals rows, $(msql biomed "SELECT count(*) FROM mach_readings WHERE read_at >= '$T0'::timestamptz") readings, $(msql biomed "SELECT count(*) FROM mach_events WHERE at >= '$T0'::timestamptz") events"
for n in pms equipment interfaces; do
    errs=$(nlog $n | grep ' error ' || true)
    same "$n ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
    [ -z "$errs" ] || printf '%s\n' "$errs" | head -n 5 | cut -c1-300 | sed "s/^/....  $n: /"
done
same "interfaces idle: no call, no run" "0" "$(nlog interfaces | grep -c ' http \| run \| call ' || true)"

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
