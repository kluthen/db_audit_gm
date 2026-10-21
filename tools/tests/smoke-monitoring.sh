#!/bin/sh
# Monitoring smoke run of gmctl on a real single-node swarm (build plan v0.2,
# chunk 11; run at every wave gate from wave 3 on, after smoke.sh, never at
# the same time: both publish the bastion's ports).
#
# On a copy of the integration fixture (tools/tests/fixtures/
# fixture-monitoring: bastion, db, prometheus, exporter, grafana):
#   fit (the laptop playground, 2 CPU / 4G / 8G, images read from the engine)
#   -> render -> deploy -> load-data, then checks:
#   - Prometheus' API, through exec: every scrape target up, the exporter
#     connected (pg_up 1), query statistics collected;
#   - every node's node-health endpoint, read from the bastion as player:
#     CPU, memory, disk and every listed service up; the exporter's service
#     stopped with s6-svc shown as down, then started again;
#   - Grafana's API, through exec and its helper: the data source healthy,
#     both reference dashboards, the companion's alert rules, UTC in effect;
#   - the web front from the host: 401 without the tools password;
#     Prometheus and Grafana under their paths with it; the administrator's
#     login through the front; Authorization not reaching Grafana;
#   - only the bastion's two ports published; TZ=UTC on every node; UTC
#     timestamps in PostgreSQL's log files (volume pglog);
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# No credential goes on a command line or in `gmctl exec --env`: the tools
# password is read from local/<pg>/secrets/tools_password and given to
# `curl -K -` on stdin; inside a node, secrets are read there (Grafana's
# helper /usr/local/lib/gm/grafana-api). No wrong Grafana administrator
# password is ever sent (brute-force lockout).
#
# Needs: a swarm manager on the local engine (docker swarm init), curl and
# python3 (with PyYAML, as gmctl) on the host, and the bricks' images built:
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.2.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.2.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.1.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.1.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.1.0 bricks/grafana
# Host ports 2222 and 8080 must be free (the bastion's published ports).
# Usage: sh tools/tests/smoke-monitoring.sh        (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=smoke-monitoring
NODES="bastion db prometheus exporter grafana"
IMAGES="127.0.0.1:5000/dbagm/postgres:0.2.0 127.0.0.1:5000/dbagm/bastion:0.2.0
127.0.0.1:5000/dbagm/prometheus:0.1.0 127.0.0.1:5000/dbagm/postgres-exporter:0.1.0
127.0.0.1:5000/dbagm/grafana:0.1.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

# Objects on the engine that do not carry the game's labels, one per line.
others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
}

# Everything still carrying one of the game's labels, one per line.
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
command -v curl >/dev/null || { echo "curl is needed on the host" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-monitoring.XXXXXX")
SCN=$tmp/fixture-monitoring
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

cp -R "$REPO/tools/tests/fixtures/fixture-monitoring" "$SCN"

# on <node> <user> [gmctl exec options]: the script on stdin, run on <node>
# as <user>. Only non-secret values go in --env.
on() {
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the five images and the reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
info "gmctl render"
$GMCTL render "$SCN" --playground "$PG"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- deployment -----------------------------------------------------------
info "gmctl deploy"
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: stack deployed and healthy"
else
    fail "deploy"
    exit 1
fi

# From here on, every check records its own result; keep going on failure.
set +e

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
out=$(on db postgres <<'EOF'
psql -XAtq -d shop -c "SELECT (SELECT count(*) FROM customers) || ' ' || (SELECT count(*) FROM orders)"
EOF
)
same "fixture data loaded (customers, orders)" "500 20000" "$out"

# --- Prometheus, through exec -------------------------------------------------
# The prometheus image has curl but no jq: its API's JSON is read on the host.
# targets: "<job> <instance> <health>" per active target, sorted.
targets() {
    on prometheus prometheus <<'EOF' | python3 -c '
import json, sys
try:
    ts = json.load(sys.stdin)["data"]["activeTargets"]
except (ValueError, KeyError):
    ts = []
for line in sorted("%s %s %s" % (t["labels"]["job"], t["labels"]["instance"], t["health"])
                   for t in ts):
    print(line)'
curl -fsS 'http://localhost:9090/prometheus/api/v1/targets?state=active'
EOF
}
# query <PromQL>: the first sample's value, empty when none.
query() {
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
EXPECTED_TARGETS="node-health bastion:9110 up
node-health db:9110 up
node-health exporter:9110 up
node-health grafana:9110 up
node-health prometheus:9110 up
postgres exporter:9187 up
prometheus localhost:9090 up"

info "waiting for every scrape target to be up (up to 120 s)"
i=0
while :; do
    out=$(targets)
    [ "$out" = "$EXPECTED_TARGETS" ] || [ "$i" -ge 24 ] && break
    i=$((i + 1)); sleep 5
done
same "Prometheus: all 7 scrape targets up" "$EXPECTED_TARGETS" "$out"
same "Prometheus: the exporter is connected (pg_up 1)" 1 "$(query 'pg_up')"
i=0
while :; do
    out=$(query 'count(pg_stat_statements_calls_total) > 0')
    [ -n "$out" ] || [ "$i" -ge 12 ] && break
    i=$((i + 1)); sleep 5
done
check "Prometheus: query statistics collected (pg_stat_statements_calls_total)" test -n "$out"

# --- node health, from the bastion -----------------------------------------
# health: every node's endpoint, read from the bastion as player (no curl
# there: Perl's socket module, which every debian:13-slim image has).
health() {
    on bastion player <<'EOF'
for n in bastion db prometheus exporter grafana; do
    perl -MIO::Socket::INET -e '
        my $s = IO::Socket::INET->new(PeerAddr => "$ARGV[0]:9110", Timeout => 5)
            or die "$ARGV[0]:9110: $!\n";
        print $s "GET /metrics HTTP/1.0\r\nHost: $ARGV[0]\r\n\r\n";
        local $/; my $r = <$s>; $r =~ s/^.*?\r\n\r\n//s; print $r;' "$n"
done
EOF
}
# service_up <metrics> <node> <service>: the sample's value.
service_up() {
    printf '%s\n' "$1" \
        | sed -n "s/^node_health_service_up{node=\"$2\",service=\"$3\"} //p"
}
services_of() {
    case $1 in
        bastion) echo "sshd web-front" ;;
        db) echo "postgres sshd" ;;
        prometheus) echo "prometheus sshd" ;;
        exporter) echo "postgres-exporter sshd" ;;
        grafana) echo "grafana sshd" ;;
    esac
}

metrics=$(health)
for n in $NODES; do
    got=
    for m in cpu_seconds_total memory_used_bytes disk_used_bytes; do
        printf '%s\n' "$metrics" | grep -q "^node_health_${m}{node=\"$n\"} [0-9]" && got="$got $m"
    done
    same "node health $n: CPU, memory and disk reported" \
        " cpu_seconds_total memory_used_bytes disk_used_bytes" "$got"
    want=; got=
    for s in $(services_of "$n"); do
        want="$want $s=1"; got="$got $s=$(service_up "$metrics" "$n" "$s")"
    done
    same "node health $n: every listed service up" "$want" "$got"
done

info "stopping the exporter's service (s6-svc -d) on exporter"
printf '/command/s6-svc -d /run/service/postgres-exporter\n' | on exporter root
i=0
while :; do
    v=$(service_up "$(health)" exporter postgres-exporter)
    [ "$v" = 0 ] || [ "$i" -ge 10 ] && break
    i=$((i + 1)); sleep 2
done
same "node health: the stopped postgres-exporter service shows as down" 0 "$v"
info "starting it again (s6-svc -u)"
printf '/command/s6-svc -u /run/service/postgres-exporter\n' | on exporter root
i=0
while :; do
    v=$(service_up "$(health)" exporter postgres-exporter)
    [ "$v" = 1 ] || [ "$i" -ge 15 ] && break
    i=$((i + 1)); sleep 2
done
same "node health: postgres-exporter up again" 1 "$v"

# --- Grafana, through exec and its helper -----------------------------------
grafana_api() {  # grafana_api <path> <jq filter>
    on grafana root --env "API_PATH=$1" --env "FILTER=$2" <<'EOF'
/usr/local/lib/gm/grafana-api GET "$API_PATH" | jq -r "$FILTER"
EOF
}
same "Grafana: the Prometheus data source is healthy" OK \
    "$(grafana_api /api/datasources/uid/prometheus/health .status)"
same "Grafana: both reference dashboards provisioned" "node-health
postgresql" "$(grafana_api '/api/search?type=dash-db' '.[].uid' | sort)"
rules=$(python3 -c 'import sys, yaml
print(sum(len(g["rules"]) for g in yaml.safe_load(open(sys.argv[1]))["groups"]))' \
    "$SCN/nodes/grafana/alert-rules.yaml")
same "Grafana: the companion's $rules alert rules provisioned" "$rules" \
    "$(grafana_api /api/v1/provisioning/alert-rules length)"
same "Grafana: default time zone in effect is UTC" UTC \
    "$(grafana_api /api/frontend/settings .dateFormats.defaultTimezone)"

# --- the web front, from the host ------------------------------------------
bastion=$(docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_bastion")
web=$(docker port "$bastion" 8080/tcp | sed -n '1s/.*://p')
same "web front published on host port 8080" 8080 "$web"
FRONT=http://127.0.0.1:$web
tools_password=$(cat "$LDIR/secrets/tools_password")
creds() { printf 'user = "player:%s"\n' "$tools_password"; }
code() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

same "web front: no tools password, /prometheus/ refused (401)" 401 \
    "$(code "$FRONT/prometheus/-/ready")"
same "web front: no tools password, /grafana/ refused (401)" 401 \
    "$(code "$FRONT/grafana/api/health")"
same "web front: Prometheus under /prometheus/ (200)" 200 \
    "$(creds | code -K - "$FRONT/prometheus/-/ready")"
same "web front: Grafana under /grafana/ (200)" 200 \
    "$(creds | code -K - "$FRONT/grafana/api/health")"
same "web front: Grafana administrator login through the front (200)" 200 \
    "$({ creds
         printf 'header = "Content-Type: application/json"\n'
         printf 'header = "Origin: %s"\n' "$FRONT"
         printf 'data = "{\\"user\\":\\"admin\\",\\"password\\":\\"%s\\"}"\n' "$tools_password"
       } | code -K - -X POST "$FRONT/grafana/login")"
# Authorization stops at the front: through it, /api/user answers as an
# in-node request without credentials, not as one sending player's.
front=$(creds | curl -s -K - -w ' %{http_code}' "$FRONT/grafana/api/user")
inside=$(on grafana root <<'EOF'
curl -s -w ' %{http_code}' http://127.0.0.1:3000/grafana/api/user
EOF
)
as_player=$(on grafana root <<'EOF'
printf 'user = "player:%s"\n' "$(cat /opt/gm/secrets/tools_password)" \
    | curl -s -K - -w ' %{http_code}' http://127.0.0.1:3000/grafana/api/user
EOF
)
same "web front: Authorization not passed on (Grafana answers as without credentials)" \
    "$inside" "$front"
check "web front: ... and differs from player's credentials sent straight to Grafana" \
    test "$front" != "$as_player"
info "Grafana /api/user through the front: $front"
unset tools_password

# --- ports, time zones, PostgreSQL's log ------------------------------------
ports=$(for c in $(docker ps -q --filter "label=com.docker.stack.namespace=$GAME"); do
    docker inspect -f '{{index .Config.Labels "com.docker.swarm.service.name"}}:{{range $p, $b := .NetworkSettings.Ports}}{{if $b}} {{$p}}{{end}}{{end}}' "$c"
done | sed "s/^${GAME}_//" | grep -v ':$' | sort)
same "only the bastion publishes ports: SSH and the web front" "bastion: 22/tcp 8080/tcp" "$ports"
check "bastion's SSH on host port 2222" sh -c "docker port $bastion 22/tcp | grep -q ':2222\$'"
for n in $NODES; do
    out=$(printf 'printf "%%s %%s" "$TZ" "$(date +%%Z)"\n' | on "$n" root)
    same "node $n runs in UTC (TZ=UTC)" "UTC UTC" "$out"
done
# The zone of every timestamped line of the log files (log_line_prefix %t).
zones=$(on db root <<'EOF'
cat /var/log/postgresql/postgresql-*.log \
    | sed -n 's/^[0-9]\{4\}-[0-9][0-9]-[0-9][0-9] [0-9:]\{8\} \([^ ]*\) \[[0-9]*\]: .*/\1/p' \
    | sort | uniq -c
EOF
)
info "PostgreSQL log timestamps by zone: $(printf '%s' "$zones" | tr -s ' \n' ' ')"
same "PostgreSQL's log files carry UTC timestamps only" UTC \
    "$(printf '%s\n' "$zones" | awk 'NF == 2 && $1 > 0 { print $2 }' | tr '\n' ' ' | sed 's/ $//')"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "status: stage torn-down" "  stage: torn-down" \
    "$($GMCTL status "$SCN" --playground "$PG" | grep '^  stage:')"
same "nothing labelled with game $GAME is left" "" "$(labelled)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-monitoring: all $passes checks passed in ${elapsed}s (game $GAME)"
else
    echo "smoke-monitoring: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME)"
    exit 1
fi
