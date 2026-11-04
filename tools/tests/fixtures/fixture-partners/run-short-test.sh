#!/bin/sh
# Short test of the partners fixture (v0.5 build plan, chunk 11a; master
# spec 10.2; capture W2 item 6, W2-f; spec D356): the partners' three shared
# nodes with two sample partners, one made slow by its misbehaviour key while
# the other answers in time, and partners-db refusing every role but the
# partners'. On one host, about eight minutes.
#
# On a copy of tools/tests/fixtures/fixture-partners (bastion 0.5.0;
# partners-api: api 0.1.0, partners-backend: scheduler 0.3.0, partners-db:
# postgres 0.5.0, all three no-access, under third_parties: alpha-lab and
# beta-lab):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render -> deploy ->
#   load-data -> inject -> start-load (T0), then:
#   - the stack file: partners-api with the aliases alpha-lab and beta-lab;
#     each partner's role password and the back end's credential
#     partners_backend mounted on the partners' nodes only, never on the
#     bastion;
#   - the new caller first: partners-api started before partners-db
#     resolves, its start-up wait ending within its 30 s bound, its endpoints
#     answering 503 (an honest failure, never a hang) until the partners'
#     database is loaded, then 200;
#   - both partners answer under their hostnames, each reading its own
#     state as its own role; the back end's ticks answered (status=200,
#     agent=partners-backend), a tick without the credential 401;
#   - partners-db's pg_hba.conf on one Swarm network, measured: every role
#     but the partners' refused (dba, postgres, gm_check, a partner's role on
#     another database), from the bastion; the address form samenet admits
#     every task of the network (a partner's role from the bastion, with the
#     password the bastion does not hold, gets in: the password is the
#     guard); a task's address changes when it restarts, still admitted; a
#     host name never matches (Swarm's reverse lookup names the task);
#   - at T0 the back end's timeline changes alpha.normal to alpha.slow:
#     alpha answers 4 s late, beta in time; measured with 30 of alpha's
#     requests in flight against a stream of beta's (beta's slowest under
#     1 s), and, for the record only, past the server's 40 worker threads;
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-partners/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=partners-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SCHEDLOG=/var/log/scheduler/scheduler.log
APILOG=/var/log/api/api.log
HBA=/etc/postgresql/pg_hba.conf
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-partners-short.XXXXXX")
SCN=$tmp/fixture-partners
LDIR=$SCN/local/$PG
GAME=
deployed=no
hba_saved=no

cleanup() {
    set +e
    if [ "$hba_saved" = yes ]; then
        cx partners-db sh -c "cp $HBA.short-test $HBA && rm -f $HBA.short-test" \
            && dbsql postgres 'select pg_reload_conf()' >/dev/null
    fi
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

# The node's running container (one replica).
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
cx() { n=$1; shift; docker exec "$(ctr "$n")" "$@"; }
cxi() { n=$1; shift; docker exec -i "$(ctr "$n")" "$@"; }
clog() { cx partners-backend cat "$SCHEDLOG" 2>/dev/null || true; }
cstatus() { cx partners-backend cat /run/scheduler/status 2>/dev/null || true; }
alog() { cx partners-api cat "$APILOG" 2>/dev/null || true; }
task_ip() { docker inspect -f "{{(index .NetworkSettings.Networks \"${GAME}_backend\").IPAddress}}" "$(ctr "$1")"; }
secret() { cat "$LDIR/secrets/$1"; }
dbsql() { docker exec -u postgres "$(ctr partners-db)" psql -XAtq -d "$1" -c "$2"; }

# HTTP from the back end's node, through the network and the aliases (the
# scheduler image's Python): `probe <host> <path> [GET|POST] [credential]`
# prints "<status> <ms> <body>"; `measure <slow host> <in flight> <other host>
# <samples>` puts that many of the slow host's requests in flight at once and,
# meanwhile, asks the other host <samples> times in a row.
PROBE_PY='
import http.client, json, sys, threading, time

def ask(host, path="/status", method="GET", token=None, timeout=20):
    t = time.monotonic()
    headers = {"User-Agent": "short-test"}
    if token:
        headers["Authorization"] = "Bearer " + token
    try:
        c = http.client.HTTPConnection(host, 8000, timeout=timeout)
        c.request(method, path, body=b"{}" if method == "POST" else None,
                  headers=dict(headers, **({"Content-Type": "application/json"} if method == "POST" else {})))
        r = c.getresponse()
        body = r.read().decode("utf-8", "replace")
        c.close()
        return r.status, (time.monotonic() - t) * 1000, body
    except OSError as exc:
        return "error", (time.monotonic() - t) * 1000, type(exc).__name__ + ": " + str(exc)

if sys.argv[1] == "probe":
    token = open("/opt/gm/secrets/http_partners_backend").read().strip() if sys.argv[5:] == ["credential"] else None
    s, ms, body = ask(sys.argv[2], sys.argv[3], sys.argv[4], token)
    print(s, round(ms), " ".join(body.split())[:300])
else:
    slow, n, other, k = sys.argv[2], int(sys.argv[3]), sys.argv[4], int(sys.argv[5])
    slow_ms, other_ms, bad = [], [], []
    def one():
        s, ms, body = ask(slow)
        (slow_ms if s == 200 else bad).append(ms if s == 200 else (s, body[:80]))
    threads = [threading.Thread(target=one) for _ in range(n)]
    t0 = time.monotonic()
    for th in threads:
        th.start()
    time.sleep(0.3)                          # every slow request in flight
    for _ in range(k):
        s, ms, body = ask(other)
        (other_ms if s == 200 else bad).append(ms if s == 200 else (s, body[:80]))
        time.sleep(0.1)
    for th in threads:
        th.join()
    wall = (time.monotonic() - t0) * 1000
    other_ms.sort(); slow_ms.sort()
    med = other_ms[len(other_ms) // 2] if other_ms else -1
    print(json.dumps({"in_flight": n, "slow_ok": len(slow_ms), "slow_min": round(min(slow_ms or [-1])),
                      "slow_max": round(max(slow_ms or [-1])), "other_ok": len(other_ms),
                      "other_median": round(med), "other_max": round(max(other_ms or [-1])),
                      "errors": bad[:3], "wall": round(wall)}))
'
probe() { cxi partners-backend python3 -I - probe "$@" <<EOF
$PROBE_PY
EOF
}
measure() { cxi partners-backend python3 -I - measure "$@" <<EOF
$PROBE_PY
EOF
}
field() { python3 -c 'import json, sys; print(json.loads(sys.argv[1])[sys.argv[2]])' "$1" "$2"; }

# psql from the bastion to partners-db: `bpsql <role> <database> <password>`
# prints the first line of the answer or of the refusal.
bpsql() {
    docker exec -e PGPASSWORD="$3" -e PGCONNECT_TIMEOUT=10 "$(ctr bastion)" \
        psql -X -w -At -h partners-db -U "$1" -d "$2" -c 'select current_user' 2>&1 | head -n 1
}
refused() {   # refused <role> <database>
    w=$(bpsql "$1" "$2" not-the-password)
    case $w in
        *"pg_hba.conf rejects connection for host"*"user \"$1\", database \"$2\""*)
            pass "partners-db refuses $1 on $2 from the bastion (pg_hba.conf: $(printf '%s' "$w" | sed 's/.*FATAL: *//'))" ;;
        *) fail "$1 on $2 from the bastion: [$w]" ;;
    esac
}

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the four nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
info "gmctl render --handover $HANDOVER"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- the stack file ---------------------------------------------------------
st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
svc = stack["services"]
print(svc["partners-api"]["networks"])
for node in ("bastion", "partners-api", "partners-backend", "partners-db"):
    names = sorted(s["source"][len(gid) + 1:] for s in svc[node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
same "stack: partners-api with both hostnames as aliases" "{'backend': {'aliases': ['alpha-lab', 'beta-lab']}}" \
    "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: the partners' secrets on partners-api only where it needs them" \
    "partners-api http_partners_backend role_alpha_password role_beta_password" "$(printf '%s\n' "$st" | sed -n 3p)"
same "stack: and on the back end" \
    "partners-backend http_partners_backend role_alpha_password role_beta_password" "$(printf '%s\n' "$st" | sed -n 4p)"
same "stack: none on the bastion" "bastion -" "$(printf '%s\n' "$st" | sed -n 2p)"
same "stack: none on partners-db (load-data sets the roles' passwords)" "partners-db -" \
    "$(printf '%s\n' "$st" | sed -n 5p)"

# --- deployment: the new caller first ----------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the four nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
w=$(docker service logs --raw "${GAME}_partners-api" 2>&1 | grep -E 'api: (waiting|still unresolved|.* resolve)' | tr '\n' '|')
case $w in
    *"waiting up to 30s"*"partners-db"*) pass "partners-api waited, bounded, for partners-db: $w" ;;
    *) fail "no bounded wait in partners-api's log: [$w]" ;;
esac
case $w in
    *"resolve after "*|*"still unresolved"*"starting anyway"*) pass "its wait ended within its bound" ;;
    *) fail "the wait's outcome: [$w]" ;;
esac
r=$(probe alpha-lab /status GET)
case $r in
    503\ *) pass "before the partners' database is loaded, alpha-lab answers 503, an honest failure: $r" ;;
    *) fail "alpha-lab before load-data: [$r]" ;;
esac
ms=$(printf '%s' "$r" | cut -d' ' -f2)
[ "${ms:-99999}" -lt 15000 ] && pass "and at once, never a hang (${ms} ms)" || fail "the 503 took ${ms} ms"

info "gmctl load-data"
if $GMCTL load-data "$SCN" --playground "$PG"; then pass "load-data"; else fail "load-data"; exit 1; fi
w=$(dbsql partners "select string_agg(rolname || ':' || (rolpassword like 'SCRAM-SHA-256\$%')::text, ' ' order by rolname) from pg_authid where rolname in ('alpha', 'beta')")
same "load-data: each partner's role logs in with its SCRAM password" "alpha:true beta:true" "$w"
w=$(dbsql partners "select string_agg(nspname || ':' || pg_get_userbyid(nspowner), ' ' order by nspname) from pg_namespace where nspname in ('alpha', 'beta')")
same "each partner's schema its own role's" "alpha:alpha beta:beta" "$w"
w=$(dbsql partners "select has_schema_privilege('beta', 'alpha', 'USAGE') or has_schema_privilege('alpha', 'beta', 'USAGE')")
same "neither partner reaches the other's schema" f "$w"

for h in alpha-lab beta-lab; do
    r=$(probe "$h" /status GET)
    case $r in
        200\ *"\"hostname\":\"$h\""*"\"delay_ms\":0"*) pass "$h answers under its hostname, its state read: $r" ;;
        *) fail "$h: [$r]" ;;
    esac
done
r=$(probe alpha-lab /tick POST)
case $r in 401\ *) pass "a tick without the credential: 401 ($r)" ;; *) fail "tick without credential: [$r]" ;; esac
r=$(probe owners /status GET)
case $r in error\ *) pass "no other hostname resolves (owners: $r)" ;; *) fail "owners: [$r]" ;; esac

# --- partners-db's pg_hba.conf on one Swarm network --------------------------
DBA=$(secret dba_password)
GMCHECK=$(secret gm_check_password)
ALPHA=$(secret role_alpha_password)
refused dba partners
refused dba postgres
refused postgres partners
refused gm_check partners
refused alpha postgres
w=$(bpsql dba partners "$DBA")
case $w in *"pg_hba.conf rejects"*) pass "dba with its own password, refused all the same" ;; *) fail "dba with its password: [$w]" ;; esac
w=$(bpsql gm_check partners "$GMCHECK")
case $w in *"pg_hba.conf rejects"*) pass "gm_check with its password, refused from the network" ;; *) fail "gm_check: [$w]" ;; esac
w=$(bpsql alpha partners not-the-password)
case $w in *"password authentication failed for user \"alpha\""*) pass "alpha on partners from the bastion without its password: refused ($w)" ;;
    *) fail "alpha without its password: [$w]" ;; esac
w=$(bpsql alpha partners "$ALPHA")
case $w in
    alpha) pass "measured: samenet admits alpha on partners from the bastion WITH its password (any task of the network matches; the password, mounted on the partners' nodes only, is the guard)" ;;
    *) fail "alpha with its password from the bastion: [$w]" ;;
esac
check_absent() { cx bastion sh -c 'ls /opt/gm/secrets' | grep -c '^role_alpha_password$' || true; }
same "the bastion holds no partner's password" 0 "$(check_absent)"
NET=$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "${GAME}_backend")
GW=$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' docker_gwbridge 2>/dev/null || echo '-')
NETS=$(cx partners-db awk 'NR > 1 && $2 != "00000000" && $8 != "FFFFFFFF" { printf "%s %s %s\n", $1, $2, $8 }' /proc/net/route \
    | python3 -c 'import sys, ipaddress
for line in sys.stdin:
    i, d, m = line.split()
    h = lambda x: str(ipaddress.IPv4Address(bytes.fromhex(x)[::-1]))
    print(i + "=" + str(ipaddress.IPv4Network(h(d) + "/" + h(m))), end=" ")')
info "measured: the game network $NET, docker_gwbridge $GW; partners-db's own subnets, what samenet admits: $NETS"
case " $NETS " in *"=$NET "*) pass "samenet covers the game network ($NET)" ;; *) fail "samenet's subnets: $NETS (network $NET)" ;; esac
ip1=$(task_ip partners-api)
# The addresses partners-db sees: each client through the node's name (its
# service's virtual address) and through tasks.partners-db (the task itself).
seen_from_bastion() {
    docker exec -e PGPASSWORD="$ALPHA" "$(ctr bastion)" psql -X -w -At -h "$1" -U alpha -d partners \
        -c 'select host(inet_client_addr())' 2>&1 | head -n 1
}
SEEN_PY='
import sys, psycopg
with psycopg.connect(host=sys.argv[2], dbname="partners", user="alpha", password=sys.argv[1], connect_timeout=10) as c:
    print(c.execute("select host(inet_client_addr())").fetchone()[0])
'
seen_from_api() { cxi partners-api python3 -I -c "$SEEN_PY" "$ALPHA" "$1" 2>&1 | tail -n 1; }
ENDPOINTS=$(docker network inspect -f '{{range $k, $v := .Containers}}{{$v.Name}}={{$v.IPv4Address}} {{end}}' \
    "${GAME}_backend" | sed "s/${GAME}_//g")
B1=$(seen_from_bastion partners-db); B2=$(seen_from_bastion tasks.partners-db)
A1=$(seen_from_api partners-db); A2=$(seen_from_api tasks.partners-db)
info "measured: the network's endpoints on this host: $ENDPOINTS"
info "measured: partners-db sees the bastion ($(task_ip bastion)) as $B1 through partners-db, $B2 through tasks.partners-db; partners-api ($ip1) as $A1 and $A2"
case "$B1 $B2 $A1 $A2" in
    *[!0-9.\ ]*) fail "a client address not read: [$B1 $B2 $A1 $A2]" ;;
    *) pass "every client address read ($B1 $B2 $A1 $A2)" ;;
esac
if [ "$A1" = "$B1" ]; then
    pass "measured: through the node's name the bastion and partners-api arrive from one address ($A1): no address form tells the partners' nodes apart"
else
    info "through the node's name the bastion and partners-api arrive from different addresses ($B1, $A1)"
fi
PTR=$(cx partners-db getent hosts "$ip1" | awk '{print $2}')
PTR1=$(cx partners-db getent hosts "$A1" | awk '{print $2}')
info "measured: the reverse lookups from partners-db: partners-api's task address $ip1 -> ${PTR:-none}; the address it arrives from, $A1 -> ${PTR1:-none}"
case "$PTR $PTR1" in
    partners-api\ *|partners-api.*|*\ partners-api|*\ partners-api.*) fail "a reverse lookup names the node: a host name form could match ($PTR $PTR1)" ;;
    *) pass "a host name never matches: no reverse lookup names the node (${PTR:-none}; ${PTR1:-none})" ;;
esac
# The host name form, tried: the partners' line with partners-api for samenet.
cx partners-db cp "$HBA" "$HBA.short-test" && hba_saved=yes
cx partners-db sed -i 's/^\(host *partners *alpha,beta *\)samenet /\1partners-api /' "$HBA"
dbsql postgres 'select pg_reload_conf()' >/dev/null
sleep 1
w=$(cxi partners-api python3 -I - "$ALPHA" <<'EOF' 2>&1 | tail -n 1
import sys, psycopg
try:
    psycopg.connect(host="partners-db", dbname="partners", user="alpha", password=sys.argv[1], connect_timeout=10).close()
    print("admitted")
except psycopg.OperationalError as exc:
    print(" ".join(str(exc).split())[:240])
EOF
)
case $w in
    *"pg_hba.conf rejects connection"*) pass "measured: the host name form (host partners alpha,beta partners-api) refuses partners-api itself: $(printf '%s' "$w" | sed 's/.*FATAL: *//')" ;;
    *) fail "the host name form from partners-api: [$w]" ;;
esac
cx partners-db sh -c "cp $HBA.short-test $HBA && rm -f $HBA.short-test" && hba_saved=no
dbsql postgres 'select pg_reload_conf()' >/dev/null
w=$(dbsql postgres "select count(*) from pg_hba_file_rules where address = 'samenet' and 'partners' = any(database)")
same "the seed's samenet line restored" 1 "$w"
info "partners-api restarted: a new task, a new address"
docker service update -q --force "${GAME}_partners-api" >/dev/null
i=0
while [ "$i" -lt 90 ]; do
    [ -n "$(ctr partners-api)" ] && [ "$(task_ip partners-api 2>/dev/null)" != "$ip1" ] \
        && probe alpha-lab /status GET | grep -q '^200 ' && break
    sleep 2; i=$((i + 2))
done
ip2=$(task_ip partners-api)
r=$(probe alpha-lab /status GET)
if [ "$ip2" != "$ip1" ]; then
    case $r in 200\ *) pass "measured: partners-api's address changed ($ip1 -> $ip2), samenet still admits it ($r)" ;;
        *) fail "after the restart ($ip1 -> $ip2): [$r]" ;; esac
else
    case $r in 200\ *) info "partners-api kept its address $ip1 across the restart (admitted: $r)" ;;
        *) fail "after the restart: [$r]" ;; esac
fi

# --- T0: the misbehaviour key ------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
case $(cstatus) in idle\ *) pass "the back end is idle before the load: $(cstatus)" ;;
    *) fail "the back end before the load: [$(cstatus)]" ;; esac
info "gmctl start-load"
t0=$(date +%s)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
i=0
r=
while [ "$i" -lt 120 ]; do
    r=$(probe alpha-lab /status GET)
    case $r in 200\ *'"delay_ms":4000'*) break ;; esac
    sleep 3; i=$(( $(date +%s) - t0 ))
done
case $r in
    200\ *'"delay_ms":4000'*) pass "alpha-lab slow from T0, its key alpha.slow switched in by the timeline ($(( $(date +%s) - t0 )) s after T0): $r" ;;
    *) fail "alpha-lab not slow $(( $(date +%s) - t0 )) s after T0: [$r]" ;;
esac
ms=$(printf '%s' "$r" | cut -d' ' -f2)
[ "${ms:-0}" -ge 4000 ] && pass "alpha's answer takes its 4 s ($ms ms)" || fail "alpha's answer: $ms ms"
r=$(probe beta-lab /status GET)
case $r in 200\ *'"delay_ms":0'*) pass "beta-lab in time: $r" ;; *) fail "beta-lab: [$r]" ;; esac
w=$(clog | grep -E ' (stream|state) ' | grep -E 'alpha\.slow|state=running' | head -n 3 | tr '\n' '|')
info "the back end's log: $w"
i=0
while [ "$i" -lt 30 ] && [ "$(alog | grep ' request status=200 ' | grep ' endpoint=alpha_tick ' | grep -c ' agent=partners-backend ' || true)" -lt 2 ]; do
    sleep 2; i=$((i + 2))
done
for p in alpha beta; do
    n=$(alog | grep ' request status=200 ' | grep " host=$p-lab " | grep " endpoint=${p}_tick " | grep -c ' agent=partners-backend ' || true)
    [ "$n" -ge 1 ] && pass "the back end ticks $p under its hostname with partners_backend ($n answered)" \
        || fail "no tick of $p answered: $(alog | grep tick | tail -n 2 | tr '\n' '|')"
done
w=$(dbsql partners "select (select value from alpha.state where name = 'delay_ms') || ' ' || (select value from beta.state where name = 'delay_ms') || ' ' || (select count(*) from alpha.state where name = 'last_tick')")
same "the state on partners-db: alpha 4000, beta 0, alpha's last tick recorded" "4000 0 1" "$w"
errs=$(clog | grep -c ' error key=' || true)
same "the back end's streams ran without an error" 0 "$errs"

# --- one partner's slow answers never hold another's (measured) ---------------
m=$(measure alpha-lab 30 beta-lab 20)
info "measured, 30 of alpha's requests in flight: $m"
[ "$(field "$m" slow_ok)" = 30 ] && [ "$(field "$m" slow_min)" -ge 4000 ] \
    && pass "every one of alpha's 30 answered slow ($(field "$m" slow_min) to $(field "$m" slow_max) ms)" \
    || fail "alpha's: $m"
[ "$(field "$m" other_ok)" = 20 ] && [ "$(field "$m" other_max)" -lt 1000 ] \
    && pass "beta answered in time meanwhile: 20 of 20, median $(field "$m" other_median) ms, slowest $(field "$m" other_max) ms" \
    || fail "beta's while alpha is slow: $m"
m=$(measure alpha-lab 45 beta-lab 20)
info "for the record, 45 of alpha's requests in flight (past the server's 40 worker threads): $m"
r=$(probe beta-lab /status GET)
case $r in 200\ *) pass "beta answers again once alpha's requests are done: $r" ;; *) fail "beta after: [$r]" ;; esac

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
[ -z "$left" ] && pass "nothing labelled with $GAME is left" || fail "left behind: $left"
same "the objects not belonging to the game are unchanged" "$before" "$(others)"

info "elapsed $(( $(date +%s) - started )) s"
printf '\n%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
