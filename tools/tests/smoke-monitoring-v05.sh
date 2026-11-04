#!/bin/sh
# The v0.5 monitoring breadth's fixture short test, on a real single-node
# swarm (build plan v0.5, chunk 10; rerun at wave 2's gate; under 30
# minutes, the deployment included).
#
# On a copy of tools/tests/fixtures/fixture-monitoring-v05 (bastion,
# records with the option monitoring, pgwatch, prometheus, grafana,
# health): fit (the laptop playground, 2 CPU / 4G / 8G) -> render ->
# deploy -> load-data, then checks:
#   - pgwatch and the health node, deployed with records (a fresh postgres
#     node enters DNS only once healthy, about 49 s): each waited, bounded,
#     and its readings failed honestly or worked as the name resolved, then
#     work (spec D356);
#   - Prometheus scrapes pgwatch's sink (target pgwatch:9188 up,
#     pgwatch_instance_up{dbname="records"} 1);
#   - Grafana's pgwatch dashboard provisioned, and its series answered
#     through Grafana's own Prometheus data source;
#   - the health node's status page, through the bastion's web front
#     (route health, the tools password): each check's line on records with
#     its state and time, the disk alarm's and the backup script's lines
#     (UNKNOWN: no cold storage in this fixture, G13 reads it);
#   - pgCluu on records, as player: a collection, a report in the player's
#     home, copied to the bastion with scp (O225);
#   - the footprints at rest (docker stats), the run's time;
#   -> teardown, nothing labelled with the game id left.
#
# Needs: a swarm manager on the local engine, curl and python3 (PyYAML) on
# the host, the images built (bastion, postgres 0.5.0, prometheus 0.2.0,
# grafana 0.3.0, pgwatch 0.1.0, health-check 0.1.0). Host ports 2222 and
# 8080 free (the bastion's).
# Usage: sh tools/tests/smoke-monitoring-v05.sh        (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=smoke-monitoring-v05
NODES="bastion records prometheus pgwatch grafana health"
IMAGES="127.0.0.1:5000/dbagm/postgres:0.5.0 127.0.0.1:5000/dbagm/bastion:0.5.0
127.0.0.1:5000/dbagm/prometheus:0.2.0 127.0.0.1:5000/dbagm/grafana:0.3.0
127.0.0.1:5000/dbagm/pgwatch:0.1.0 127.0.0.1:5000/dbagm/health-check:0.1.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
ACTIONS="connection backends locks txn_wraparound last_autovacuum last_analyze database_size"
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
command -v curl >/dev/null || { echo "curl is needed on the host" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-monitoring-v05.XXXXXX")
SCN=$tmp/fixture-monitoring-v05
LDIR=$SCN/local/$PG
GAME=
deployed=no

cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
        left=$(labelled)
        [ -z "$left" ] && info "teardown: nothing of game $GAME left" || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
    find "$REPO/tools" -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$REPO/tools/tests/fixtures/fixture-monitoring-v05" "$SCN"

on() {  # on <node> <user> [gmctl exec options]: the script on stdin
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
logs_of() { docker service logs --raw "${GAME}_$1" 2>&1; }

# --- local implementation, deployment -------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the six images and the reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"; exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id" >&2; exit 1; }
$GMCTL render "$SCN" --playground "$PG"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
info "gmctl deploy"
deployed=yes
t_deploy=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: stack deployed and healthy ($(($(date +%s) - t_deploy))s)"
else
    fail "deploy"; exit 1
fi
set +e
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"

# --- started with records, before it resolves (spec D356) -------------------------
w=$(logs_of pgwatch | grep '^pgwatch-run: ' | head -n 3 | tr '\n' ' ')
case $w in
    *"waiting up to 30s for sources' hosts to resolve: records"*) pass "pgwatch waited, bounded, for records: $w" ;;
    *"sources' hosts resolve: records"*) pass "pgwatch found records resolving at start: $w" ;;
    *) fail "pgwatch's start: [$w]" ;;
esac
w=$(logs_of health | grep '^health-start: ' | head -n 3 | tr '\n' ' ')
case $w in
    *"waiting up to 30s for instances' hosts to resolve: records"*|*"instances' hosts resolve: records"*)
        pass "the health node waited, bounded, for records, and ran the checks: $w" ;;
    *) fail "the health node's start: [$w]" ;;
esac

# --- Prometheus scrapes pgwatch ------------------------------------------------------
query() {  # query <PromQL>: the first sample's value, empty when none
    on prometheus prometheus --env "QUERY=$1" <<'EOF' | python3 -c '
import json, sys
try:
    r = json.load(sys.stdin)["data"]["result"]
except (ValueError, KeyError):
    r = []
print(r[0]["value"][1] if r else "")'
curl -fsS --get --data-urlencode "query=$QUERY" 'http://localhost:9090/prometheus/api/v1/query'
EOF
}
info "waiting for pgwatch to reach records, scraped by Prometheus (up to 180 s)"
i=0; v=; u=
while [ "$i" -lt 180 ]; do
    u=$(query 'up{job="pgwatch",instance="pgwatch:9188"}')
    v=$(query 'pgwatch_instance_up{dbname="records"}')
    [ "$u" = 1 ] && [ "$v" = 1 ] && break
    sleep 5; i=$((i + 5))
done
same "Prometheus scrapes pgwatch's sink (target pgwatch:9188 up)" 1 "$u"
same "pgwatch reaches records: pgwatch_instance_up{dbname=\"records\"} 1 (${i}s after load-data)" 1 "$v"
i=0; n=
while [ "$i" -lt 90 ]; do
    n=$(query 'count({__name__=~"pgwatch_db_stats_.*",dbname="records"})')
    [ -n "$n" ] && [ "$n" -ge 20 ] && break
    sleep 5; i=$((i + 5))
done
[ -n "$n" ] && [ "$n" -ge 20 ] && pass "the basic preset's db_stats series in Prometheus ($n)" || fail "db_stats series: [$n]"
info "pgwatch series in Prometheus: $(query 'count({__name__=~"pgwatch_.*"})')"

# --- Grafana's pgwatch dashboard ------------------------------------------------------
grafana_api() {  # grafana_api <path> <jq filter>
    on grafana root --env "API_PATH=$1" --env "FILTER=$2" <<'EOF'
/usr/local/lib/gm/grafana-api GET "$API_PATH" | jq -r "$FILTER"
EOF
}
same "Grafana: the pgwatch dashboard provisioned" pgwatch \
    "$(grafana_api /api/dashboards/uid/pgwatch .dashboard.uid)"
exprs=$(python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
for p in d["panels"]:
    for t in p.get("targets", []):
        print(t["expr"])' "$SCN/nodes/grafana/pgwatch.json")
# the rate() panels need two of pgwatch's fetches (one a minute) inside
# their window: polled, bounded at 240 s
panels() {
    k=0; empty=
    while IFS= read -r e; do
        [ -n "$e" ] || continue
        k=$((k + 1))
        q=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$e")
        r=$(grafana_api "/api/datasources/proxy/uid/prometheus/api/v1/query?query=$q" '.data.result | length')
        [ -n "$r" ] && [ "$r" -ge 1 ] || empty="$empty [$e]"
    done <<EOF
$exprs
EOF
}
i=0
while :; do
    panels
    [ -z "$empty" ] || [ "$i" -ge 240 ] && break
    sleep 15; i=$((i + 15))
done
[ -z "$empty" ] && pass "the dashboard shows its series: all $k panel queries answer through Grafana's data source (${i}s more)" \
    || fail "panel queries with no series after ${i}s:$empty"

# --- the health node's page, through the bastion ------------------------------------------
on health player <<'EOF' >/dev/null 2>&1
sudo -n gm-run-checks
EOF
on health postgres <<'EOF' >/dev/null 2>&1
health-run script disk-alarm 2048 4096 records
health-run script backup-there http://cold-storage:8000 records
EOF
bastion=$(docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_bastion")
web=$(docker port "$bastion" 8080/tcp | sed -n '1s/.*://p')
FRONT=http://127.0.0.1:$web
tools_password=$(cat "$LDIR/secrets/tools_password")
creds() { printf 'user = "player:%s"\n' "$tools_password"; }
same "web front: no tools password, /health/ refused (401)" 401 "$(curl -s -o /dev/null -w '%{http_code}' "$FRONT/health/")"
page=$(creds | curl -s -K - -w '\n%{http_code}' "$FRONT/health/")
same "web front: the status page under /health/ (200)" 200 "$(printf '%s' "$page" | tail -n 1)"
st=$(creds | curl -s -K - "$FRONT/health/status.txt")
unset tools_password
for a in $ACTIONS; do
    l=$(printf '%s\n' "$st" | grep " records $a: " | head -n 1)
    case $l in
        [0-9][0-9][0-9][0-9]-*Z\ OK\ records\ $a:\ POSTGRES_*|[0-9][0-9][0-9][0-9]-*Z\ UNKNOWN\ records\ $a:\ POSTGRES_*"No matching tables"*)
            pass "the page, through the bastion: $l" ;;
        *) fail "records $a on the page: [$l]" ;;
    esac
done
printf '%s' "$page" | grep -q '<td>records</td><td>connection</td><td>OK</td><td>20[0-9-]*T[0-9:]*Z</td>' \
    && pass "the HTML page: records connection OK with its time" || fail "the HTML page lacks records connection OK"
l=$(printf '%s\n' "$st" | grep ' script disk-alarm: ')
case $l in *" OK script disk-alarm: DISK OK: records "*" MB"*) pass "the disk alarm's line: $l" ;; *) fail "disk alarm: [$l]" ;; esac
l=$(printf '%s\n' "$st" | grep ' script backup-there: ')
case $l in *" UNKNOWN script backup-there: BACKUP UNKNOWN: cold storage did not answer"*) pass "the backup script's line, no cold storage here (G13 reads it): $l" ;;
    *) fail "backup script: [$l]" ;; esac
out=$(on health postgres <<'EOF'
/opt/gm/validator/validate.sh
EOF
); same "the health node's validator green" 0 "$?"
out=$(on pgwatch pgwatch <<'EOF'
/opt/gm/validator/validate.sh
EOF
); same "pgwatch's validator green ($out)" 0 "$?"

# --- pgCluu on records, its report in the player's home, read with scp (O225) ---------------
out=$(on records player <<'EOF' 2>&1
set -e
rm -rf ~/pgcluu-stats ~/pgcluu-report
mkdir -p ~/pgcluu-stats ~/pgcluu-report
pgcluu_collectd -h localhost -U dba -d postgres --disable-sar --disable-pidstat -i 5 -E 30 -f ~/pgcluu-stats/collectd.pid ~/pgcluu-stats > ~/pgcluu-collectd.log 2>&1
pgcluu --disable-sar -o ~/pgcluu-report ~/pgcluu-stats > ~/pgcluu.log 2>&1
ls ~/pgcluu-report | wc -l
test -s ~/pgcluu-report/index.html && echo report
EOF
)
case $out in *report) pass "pgCluu: a collection and a report in records' player home ($(printf '%s' "$out" | head -n 1) files)" ;;
    *) fail "pgCluu on records: $out" ;; esac
out=$(on bastion player <<'EOF' 2>&1
rm -rf ~/pgcluu-report
cd ~ && scp -q -r records:pgcluu-report . && test -s ~/pgcluu-report/index.html && echo copied
EOF
)
case $out in *copied) pass "pgCluu's report copied to the bastion with scp, as pgBadger's" ;; *) fail "scp of the report: $out" ;; esac
out=$(on records root <<'EOF'
ps -u player -o args= | grep -c '[p]gcluu_collectd'; test ! -e /usr/lib/cgi-bin/pgcluu.cgi && echo nocgi
EOF
)
same "no pgcluu_collectd left running; no CGI on the node" "0
nocgi" "$out"

# --- footprints at rest ----------------------------------------------------------------
sleep 30
for n in $NODES; do
    c=$(docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$n")
    info "footprint at rest: $n $(docker stats --no-stream --format '{{.CPUPerc}} {{.MemUsage}}' "$c")"
done

echo
info "run time: $(($(date +%s) - started))s, the deployment included"
if [ "$failures" -eq 0 ]; then
    echo "smoke-monitoring-v05: all $passes checks passed"
    exit 0
fi
echo "smoke-monitoring-v05: $failures check(s) failed, $passes passed"
exit 1
