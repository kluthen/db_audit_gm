#!/bin/sh
# Short test of the clinic load fixture (v0.5 wave 3's gate; spec D407; build
# plan "Per-wave gate contents", row 3): the six clinic domains loaded by
# gmctl load-data, uncomposed, load only, through the coherence check. On one
# host, under 30 minutes.
#
# On a copy of tools/tests/fixtures/fixture-clinic-load (bastion 0.5.0;
# records, lab, machines and partners-db: postgres 0.5.0; every producer left
# out, so no compose, no scheduler node and no aging):
#   fit (2 CPU / 4G / 8G) -> render -> deploy -> load-data, then:
#   - load-data: the core, housing and scheduling in records/clinic, the lab
#     in lab/lab and its two stubs' state, the machinery's three databases on
#     machines, the portal in records/portal and the owners' state, the
#     portal's derivation after the core and the lab, each domain's
#     data/cron.sql; every coherence check passing (load-data fails
#     otherwise); each step's time, read off load-data's output;
#   - each node's databases, CONNECT revoked from PUBLIC on each domain's;
#   - cron.job on records (the sessions' purge) and on machines (the three
#     partition jobs);
#   - partners-db: each partner's schema owned by its role, the external
#     lab's open orders the lab's open send-outs, the owners' logins the
#     portal's open accounts;
#   - the figures: each database's size, each domain's rows;
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-clinic-load/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=clinic-load-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-clinic-load-short.XXXXXX")
SCN=$tmp/fixture-clinic-load
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
dbsql() { docker exec -u postgres "$(ctr "$1")" psql -XAtq -d "$2" -c "$3"; }
# rows <node> <database> <regex>: the exact row count of the database's
# ordinary tables (partitions counted, their parents not) whose name matches.
rows() {
    dbsql "$1" "$2" "SELECT coalesce(sum((xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %s', c.oid::regclass), false, true, '')))[1]::text::bigint), 0)
                       FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
                      WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'cron', 'gm_check')
                        AND n.nspname NOT LIKE 'gm\_%' AND c.relname ~ '$3'"
}
size() { dbsql "$1" postgres "SELECT pg_size_pretty(pg_database_size('$2'))"; }

# --- composition: none (every producer left out) -----------------------------
same "no nodes/ folder beside the seeds: no producer to compose" \
    "lab machines partners-db records" "$(ls "$SCN/nodes" | sort | tr '\n' ' ' | sed 's/ $//')"

# --- local implementation ---------------------------------------------------
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
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 2) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi

# --- load-data ---------------------------------------------------------------
# Each line of load-data's output is printed once its step ends: the time
# between a heading and the one before it is that step's.
info "gmctl load-data"
t=$(date +%s)
log=$tmp/load-data.log
{ PYTHONUNBUFFERED=1 $GMCTL load-data "$SCN" --playground "$PG" 2>&1; echo "load-data exit $?"; } | python3 -c '
import sys, time
last = start = time.monotonic()
for line in sys.stdin:
    now = time.monotonic()
    print(f"{now - start:7.1f} {now - last:6.1f}  {line.rstrip()}", flush=True)
    last = now
' > "$log"
status=$(sed -n 's/.*  load-data exit \([0-9]*\)$/\1/p' "$log")
loaded=$(( $(date +%s) - t ))
sed -n 's/^/....  load-data: /p' "$log" | grep -v '^\.\.\.\.  load-data: *[0-9.]* *[0-9.]*      ' | cut -c1-200
if [ "$status" = 0 ]; then
    pass "load-data: the six domains, the partners' state, the derivation and the cron jobs ($loaded s)"
else
    fail "load-data (exit $status)"
    tail -n 20 "$log"
    exit 1
fi
checks=$(grep -c '  coherence [a-z-]* [A-Za-z0-9_.-]*: ' "$log" || true)
passed=$(grep -c '  coherence [a-z-]* [A-Za-z0-9_.-]*: pass' "$log" || true)
info "coherence: $passed of $checks checks passed"
same "load-data: every coherence check passed" "$checks" "$passed"
[ "$checks" -gt 0 ] && pass "load-data: coherence checks ran ($checks)" || fail "load-data: no coherence check ran"
same "load-data: each domain with a coherence file checked" "vet-housing vet-lab vet-machinery vet-portal vet-scheduling" \
    "$(sed -n 's/.*  coherence \([a-z-]*\) [A-Za-z0-9_.-]*: [a-z]*.*/\1/p' "$log" | sort -u | tr '\n' ' ' | sed 's/ $//')"

# --- the databases -----------------------------------------------------------
dbs() { dbsql "$1" postgres "SELECT string_agg(datname, ' ' ORDER BY datname) FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'"; }
same "records: clinic, jobs, portal" "clinic jobs portal" "$(dbs records)"
same "lab: lab" "lab" "$(dbs lab)"
same "machines: biomed, jobs, pacs, vitals" "biomed jobs pacs vitals" "$(dbs machines)"
same "partners-db: partners" "partners" "$(dbs partners-db)"
public() { dbsql "$1" postgres "SELECT string_agg(datname || ':' || has_database_privilege('public', datname, 'CONNECT'), ' ' ORDER BY datname) FROM pg_database WHERE datname IN ($2)"; }
same "CONNECT revoked from PUBLIC on each domain's database and on jobs (records)" "clinic:false jobs:false portal:false" \
    "$(public records "'clinic', 'jobs', 'portal'")"
same "CONNECT revoked from PUBLIC (lab)" "lab:false" "$(public lab "'lab'")"
same "CONNECT revoked from PUBLIC (machines)" "biomed:false jobs:false pacs:false vitals:false" \
    "$(public machines "'biomed', 'jobs', 'pacs', 'vitals'")"

# --- the cron jobs -----------------------------------------------------------
same "records: cron.job holds the sessions' purge, in portal, as portal_housekeeping" \
    "portal.sessions.purge portal portal_housekeeping 30 3 * * *" \
    "$(dbsql records jobs "SELECT string_agg(jobname || ' ' || database || ' ' || username || ' ' || schedule, '|' ORDER BY jobid) FROM cron.job WHERE active")"
same "machines: cron.job holds the three partition jobs, as mach_maint" \
    "vitals-partitions vitals mach_maint 0 22 * * *|readings-partitions biomed mach_maint 5 22 * * *|events-partitions biomed mach_maint 0 22 25 * *" \
    "$(dbsql machines jobs "SELECT string_agg(jobname || ' ' || database || ' ' || username || ' ' || schedule, '|' ORDER BY jobid) FROM cron.job WHERE active")"

# --- partners-db -------------------------------------------------------------
same "the roles on partners own their schemas only" "owners:owners practices:practices xlab:xlab" \
    "$(dbsql partners-db partners "SELECT string_agg(nspname || ':' || pg_get_userbyid(nspowner), ' ' ORDER BY nspname)
                                   FROM pg_namespace WHERE nspname IN ('xlab', 'practices', 'owners')")"
same "the external lab's stub holds the lab's open send-outs" \
    "$(dbsql lab lab "SELECT count(*) FROM lab_send_outs WHERE status IN ('sent', 'accepted')")" \
    "$(dbsql partners-db partners "SELECT count(*) FROM xlab.orders WHERE answered_at IS NULL")"
same "the owners' logins are the portal's open accounts" \
    "$(dbsql records portal "SELECT count(*) || ' ' || count(*) FILTER (WHERE status = 'active') FROM portal_accounts WHERE status <> 'closed'")" \
    "$(dbsql partners-db partners "SELECT count(*) || ' ' || count(*) FILTER (WHERE status = 'active') FROM owners.accounts")"
same "the owners' record of visits is empty (no owners' route)" "0" \
    "$(dbsql partners-db partners "SELECT count(*) FROM owners.visits")"

# --- the figures ---------------------------------------------------------------
info "sizes: clinic $(size records clinic), portal $(size records portal), lab $(size lab lab), pacs $(size machines pacs), vitals $(size machines vitals), biomed $(size machines biomed), partners $(size partners-db partners)"
housing=$(rows records clinic '^housing_')
sched=$(rows records clinic '^sched_')
clinic=$(rows records clinic '.')
portal=$(rows records portal '.')
lab=$(rows lab lab '.')
mach=$(( $(rows machines pacs '.') + $(rows machines vitals '.') + $(rows machines biomed '.') ))
partners=$(rows partners-db partners '.')
info "rows: vet-core $((clinic - housing - sched)), vet-housing $housing, vet-scheduling $sched, vet-lab $lab, vet-machinery $mach, vet-portal $portal, partners $partners; total $((clinic + portal + lab + mach + partners))"
[ "$housing" -gt 0 ] && [ "$sched" -gt 0 ] && [ "$portal" -gt 0 ] && [ "$lab" -gt 0 ] && [ "$mach" -gt 0 ] \
    && pass "every part's tables hold rows" || fail "a part's tables are empty"

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
