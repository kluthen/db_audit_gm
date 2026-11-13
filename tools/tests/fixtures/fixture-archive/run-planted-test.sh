#!/bin/sh
# Planted test of the archive fixture: s2 and s6 together (v0.5 build plan,
# chunk 23; master spec 13.4, 17.2, 17.3; data-register-handout.md 4, 5;
# capture W5 items 0 and 2; spec D382). On one host, about fifteen minutes
# with the deployment.
#
# On a copy of tools/tests/fixtures/fixture-archive, the overlays
# planted/pg-archive-command-silent/ (s2: records' archive_command
# 'vault-post wal %p %f || true') and planted/governance-register-flow-undeclared/
# (s6: the handout naming cold storage nowhere, the register the
# data-register skill generated for that merge) merged by planted/merge.py,
# s2 then s6; both planted at render, before T0. Then:
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render -> deploy ->
#   load-data (vet-core's included) -> inject -> start-load (T0), then:
#   - s2 present: a segment switched (pg_switch_wal()) is counted archived by
#     pg_stat_archiver with no failure, no wal manifest names it, vault-post's
#     refusal of the name pg_wal/... is in the server log, and the vault's
#     page shows the gap (no wal shipment today, beside yesterday's planted
#     ones); its sealed check reads present (1);
#   - s6 present: the bastion serves data-register.md in /home/player and on
#     its page with cold storage on none of its entries, the true register
#     (the copy's gm/data-register.yaml) names it on every entry, the vault
#     lists records' planted wal and basebackup manifests and its page charts
#     them; its sealed check reads present (1). Cleared is the data-register
#     skill's, run by the chunk owner on a copy without the instance (W5-b):
#     this test reads present only;
#   - s2 fixed: the line corrected and reloaded (gm-reload-db), the next
#     switched segment's manifest present, the sealed check fixed (0); the gap
#     staying a finding (the first segment still unshipped, the vault's count
#     today below the archiver's); s6 still present;
#   -> teardown, nothing labelled with the game id left, the objects not
#   belonging to the game unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-archive/run-planted-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=archive-planted
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-archive-planted.XXXXXX")
SCN=$tmp/fixture-archive
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
rm -f "$SCN/run-short-test.sh" "$SCN/run-planted-test.sh"
python3 "$HERE/planted/merge.py" "$SCN" pg-archive-command-silent governance-register-flow-undeclared \
    && pass "planted: s2 and s6 merged into the copy from planted/" || { fail "merging the overlays"; exit 1; }

# The node's running container (one replica).
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
cx() { n=$1; shift; docker exec "$(ctr "$n")" "$@"; }
rsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
archiver() { rsql postgres "select coalesce(last_archived_wal, '-') || ' ' || failed_count || ' ' || archived_count from pg_stat_archiver"; }
switch_wal() { rsql fill "insert into fill_rows (n, written_at) select g, now() from generate_series(1, 2000) g; select pg_walfile_name(pg_switch_wal())" | tail -n 1; }
wait_archived() {  # wait_archived <segment> <seconds>: the archiver at or past it (names sort in order)
    k=0
    while [ "$k" -lt "$2" ]; do
        last=$(archiver 2>/dev/null | cut -d' ' -f1)
        case $last in -|'') ;; *)
            [ "$(printf '%s\n%s\n' "$1" "$last" | sort | tail -n 1)" = "$last" ] && return 0 ;; esac
        sleep 2; k=$((k + 2))
    done
    return 1
}
rlog() { cx records sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null || true; }
check() {   # check <instance>: gmctl check's line and exit code, "<code> <line>"
    set +e
    out=$($GMCTL check "$SCN" --playground "$PG" --instance "$1" 2>&1)
    rc=$?
    set -e
    printf '%s %s' "$rc" "$(printf '%s\n' "$out" | grep -m 1 "$1" || printf '%s' "$out" | head -n 1)"
}

# HTTP to cold storage from the back end's node, through the network and the
# alias (the scheduler image's Python): `web <path>` prints "<status> <body>".
WEB_PY='
import http.client, sys
c = http.client.HTTPConnection("cold-storage", 8000, timeout=30)
c.request("GET", sys.argv[1], headers={"User-Agent": "planted-test"})
r = c.getresponse()
sys.stdout.write(f"{r.status} " + r.read().decode("utf-8", "replace"))
'
web() { docker exec -i "$(ctr partners-backend)" python3 -I - "$@" <<EOF
$WEB_PY
EOF
}
jq_py() { code=$1; shift; python3 -c "import json, sys; d = json.loads(sys.stdin.read().split(' ', 1)[1]); $code" "$@"; }
# The page's section for one type: its <h2> up to the next.
page_section() { python3 -c "
import re, sys
p = sys.stdin.read().split(' ', 1)[1]
m = re.search(r'<h2>' + sys.argv[1] + r'</h2>(.*?)(?=<h2>|</body>)', p, re.S)
print(m.group(1) if m else '')" "$1"; }

# --- local implementation, deployment, T0 -------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the planted copy's five nodes fit 2 CPU / 4G / 8G"
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

info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
same "s2 planted at render: records' archive_command in effect" "on|vault-post wal %p %f || true" \
    "$(rsql postgres "select current_setting('archive_mode') || '|' || current_setting('archive_command')")"

info "gmctl load-data (vet-core's included)"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then pass "load-data ($(( $(date +%s) - t )) s)"; else fail "load-data"; exit 1; fi
n=$(rsql clinic "select count(*) from owners")
[ "${n:-0}" -gt 1000 ] && pass "vet-core loaded in records/clinic ($n owners)" || fail "vet-core in records/clinic: [$n] owners"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject" || fail "inject"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
T0=$(date +%s)
TODAY=$(date -u +%Y-%m-%d)
LAST=$(date -u -d "$TODAY - 1 day" +%Y-%m-%d)

# --- s2 present -------------------------------------------------------------------
set -- $(archiver)
fail0=$2
SEG=$(switch_wal)
info "segment switched: $SEG"
if wait_archived "$SEG" 60; then
    set -- $(archiver)
    same "s2: pg_stat_archiver counts $SEG archived ($3 archived), no failure" "$SEG 0" "$1 $2"
else
    fail "s2: $SEG not counted archived: $(archiver)"
fi
same "s2: failed_count unchanged since T0" "$fail0" "$(archiver | cut -d' ' -f2)"
r=$(web "/manifests?type=wal&source=records")
w=$(printf '%s' "$r" | jq_py 'print(sum(m["name"] == sys.argv[1] for m in d), sum(m["date_from"] == sys.argv[2] for m in d), len(d) > 0)' "$SEG" "$TODAY")
same "s2: no wal manifest names $SEG, none from records today (its planted ones before)" "0 0 True" "$w"
n=$(rlog | grep -c "vault-post: name pg_wal/$SEG: " || true)
[ "${n:-0}" -ge 1 ] && pass "s2: vault-post's refusal of the name pg_wal/$SEG in records' server log" \
    || fail "s2: no refusal of pg_wal/$SEG in records' log"
r=$(web /)
wal=$(printf '%s' "$r" | page_section wal)
case $wal in *"<td>$TODAY</td>"*|*"$TODAY: declared"*) fail "s2: the page's wal chart has a column for $TODAY: [$(printf '%s' "$wal" | grep -o "$TODAY: [^<]*" | head -n 1)]" ;;
    *) pass "s2: the vault's page shows the gap: no wal column or table row for $TODAY" ;; esac
yday=$(printf '%s' "$wal" | grep -o "$LAST: declared [0-9,]*, received [0-9,]*, [0-9,]* shipments" | head -n 1)
k=$(printf '%s' "$yday" | sed 's/.*, \([0-9,]*\) shipments/\1/' | tr -d ,)
[ "${k:-0}" -ge 24 ] && pass "s2: beside yesterday's planted wal shipments ($yday)" || fail "s2: yesterday's wal column: [$yday]"
w=$(check s2)
case $w in "1 "*) pass "s2: sealed check present (1): ${w#1 }" ;; *) fail "s2: sealed check: [$w]" ;; esac

# --- s6 present -------------------------------------------------------------------
h=$(cx bastion cat /home/player/data-register.md)
e=$(printf '%s\n' "$h" | grep -c '^### ' || true)
c=$(printf '%s\n' "$h" | grep -ci 'cold storage' || true)
same "s6: the bastion serves ~/data-register.md, its 6 entries naming cold storage nowhere" "6 0" "$e $c"
p=$(cx bastion sh -c 'curl -s -u "player:$(cat /opt/gm/secrets/tools_password)" http://127.0.0.1:8080/')
w=$(printf '%s' "$p" | python3 -c '
import re, sys
p = sys.stdin.read()
m = re.search(r"<section id=\"data-register\">(.*?)</section>", p, re.S)
print("missing" if not m else (m.group(1).count("<h3"), "cold storage" in m.group(1).lower()))')
same "s6: and on its page: the Data register section, 6 entries, no cold storage" "(6, False)" "$w"
w=$(python3 - "$SCN/gm/data-register.yaml" <<'EOF'
import sys, yaml
r = yaml.safe_load(open(sys.argv[1]))
print(len(r["entries"]), sum(any(s["recipient"] == "Cold Storage" for s in e["shared_with"])
                             and {"copy": "cold storage (WAL archive, nightly base backup)"} in e["where"]
                             for e in r["entries"]))
EOF
)
same "s6: the true register names cold storage on every entry it holds (recipient and copy)" "6 6" "$w"
r=$(web "/manifests?source=records&to=$LAST")
w=$(printf '%s' "$r" | jq_py 'print(sorted({m["type"] for m in d}), len({m["date_from"] for m in d}))')
same "s6: the vault lists records' planted wal and basebackup manifests, 35 days" "['basebackup', 'wal'] 35" "$w"
r=$(web /)
w=$(printf '%s' "$r" | python3 -c 'import re, sys; print(re.findall(r"<h2>([^<]*)</h2>", sys.stdin.read()))')
same "s6: the vault's page charts records' wal and base backups" "['wal', 'basebackup']" "$w"
w=$(check s6)
case $w in "1 "*) pass "s6: sealed check present (1): ${w#1 }" ;; *) fail "s6: sealed check: [$w]" ;; esac

# --- s2 fixed -----------------------------------------------------------------------
cx records sed -i "s/^archive_command = .*/archive_command = 'vault-post wal %f %p'/" /etc/postgresql/postgresql.conf
cx records /usr/local/sbin/gm-reload-db >/dev/null 2>&1 || true
same "s2 fixed: the line corrected and reloaded" "vault-post wal %f %p" "$(rsql postgres "select current_setting('archive_command')")"
SEG2=$(switch_wal)
info "segment switched after the fix: $SEG2"
k=0
while [ "$k" -lt 60 ]; do
    r=$(web "/manifests?type=wal&source=records&from=$TODAY")
    [ "$(printf '%s' "$r" | jq_py 'print(any(m["name"] == sys.argv[1] for m in d))' "$SEG2")" = True ] && break
    sleep 2; k=$((k + 2))
done
w=$(printf '%s' "$r" | jq_py 'print(sorted(m["name"] for m in d if m["name"] in sys.argv[1:]))' "$SEG" "$SEG2")
same "s2 fixed: $SEG2's manifest present, $SEG's still missing (the gap stays)" "['$SEG2']" "$w"
w=$(check s2)
case $w in "0 "*) pass "s2: sealed check fixed (0): ${w#0 }" ;; *) fail "s2: sealed check after the fix: [$w]" ;; esac
today=$(printf '%s' "$r" | jq_py 'print(sum(m["date_from"] == sys.argv[1] for m in d))' "$TODAY")
archived=$(archiver | cut -d' ' -f3)
[ "${today:-0}" -ge 1 ] && [ "${today:-0}" -lt "${archived:-0}" ] \
    && pass "s2: the gap stays a finding: the vault holds $today of records' segments today, the archiver counts $archived archived" \
    || fail "s2: the vault's count today [$today] against the archiver's [$archived]"
wal=$(web / | page_section wal)
case $wal in *"<tr><td>$TODAY</td><td>$today</td><td>$today</td><td>$today</td></tr>"*)
        pass "s2: the vault's page now shows $today wal shipment(s) today, the gap before the fix unfilled" ;;
    *) fail "s2: the page's wal row for $TODAY after the fix: [$(printf '%s' "$wal" | grep -o "<tr><td>$TODAY</td>[^/]*" | head -n 1)]" ;; esac
w=$(check s6)
case $w in "1 "*) pass "s6: still present after s2's fix (1)" ;; *) fail "s6 after s2's fix: [$w]" ;; esac
info "readings from T0: $(( $(date +%s) - T0 )) s"

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
