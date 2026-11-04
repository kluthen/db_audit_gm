#!/bin/sh
# Short test of the archive fixture (v0.5 build plan, chunk 11b; master spec
# 10.4, 11.2; cold-storage.md 3; capture W1 item 6, W2 item 6, W2-f; spec
# D356): cold storage, the vault, on the partners' shared nodes, fed by
# records' archive_command and nightly base backup through postgres 0.5.0's
# vault-post. On one host, about ten minutes.
#
# On a copy of tools/tests/fixtures/fixture-archive (bastion 0.5.0; records:
# postgres 0.5.0 archiving to cold-storage:8000 with the credential
# cold_storage; partners-api: api 0.1.0 serving partners/coldstore/ under
# cold-storage; partners-backend: scheduler 0.3.0; partners-db: postgres
# 0.5.0 with partners/shared/ and coldstore's data and planted manifests):
#   fit (the laptop playground, 2 CPU / 4G / 8G) -> render -> deploy, then:
#   - the stack file: partners-api's alias cold-storage; http_cold_storage on
#     records and partners-api only;
#   - the caller first: a segment switched on records before the vault's
#     database is loaded fails honestly (the vault answers 503, vault-post's
#     reason in the server log, the segment kept), and ships on the
#     archiver's retry once load-data has run;
#   - load-data -> inject -> start-load (T0): the planted manifests, the 35
#     days before T0's day for records, wal and basebackup;
#   - a switched segment yields a manifest naming records (wal, 16 MB, rows
#     1 of 1, the posting day); the base backup, its crontab line moved to
#     the next minute, yields one too (basebackup, its size, its job's log);
#   - POST /shipments: 401 without the credential; a data type's NDJSON rows
#     counted (rows_received), the same shipment id again replacing its
#     manifest; a malformed header 400; its state read at each request
#     (uploads refuse: 503, the back end's coldstore.normal restoring it);
#   - GET /manifests, public: filtered by type, by date (inclusive, against
#     the manifest's range) and by source; a bad date 422;
#   - GET /, public: an HTML page, one inline SVG per type, declared against
#     received per day over five weeks, a mismatch marked, no script;
#   -> teardown, then nothing labelled with the game id is left and the
#   objects not belonging to the game are unchanged.
# With KEEP=<dir>, the page is kept as <dir>/cold-storage.html.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-archive/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=archive-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SECRET=/opt/gm/secrets/http_cold_storage
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-archive-short.XXXXXX")
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
rm -f "$SCN/run-short-test.sh"

# The node's running container (one replica).
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
cx() { n=$1; shift; docker exec "$(ctr "$n")" "$@"; }
rsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
dbsql() { docker exec -u postgres "$(ctr partners-db)" psql -XAtq -d "$1" -c "$2"; }
archiver() { rsql postgres "select coalesce(last_archived_wal, '-') || ' ' || failed_count || ' ' || coalesce(last_failed_wal, '-') from pg_stat_archiver"; }
switch_wal() { rsql postgres "select pg_logical_emit_message(false, 'short-test', repeat('x', 1000)); select pg_walfile_name(pg_switch_wal())" | tail -n 1; }
wait_archived() {  # wait_archived <segment> <seconds>
    k=0
    while [ "$k" -lt "$2" ]; do
        case $(archiver 2>/dev/null) in "$1 "*) return 0 ;; esac
        sleep 2; k=$((k + 2))
    done
    return 1
}
rlog() { cx records sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null || true; }
manifest() {   # manifest <shipment id>: its fields, | separated
    dbsql partners "select type || '|' || source || '|' || name || '|' || rows_declared || '|' || rows_received || '|' || size || '|' || date_from || '|' || date_to from coldstore.manifests where shipment_id = '$1'"
}

# HTTP from the back end's node through the network and the alias (the
# scheduler image's Python): `web get <path>` and `web post <id> <type>
# <rows declared> <from> <to> <lines sent> <token|none> [<name>]` print
# "<status> <body>".
WEB_PY='
import http.client, sys
def ask(method, path, body=None, headers=None):
    c = http.client.HTTPConnection("cold-storage", 8000, timeout=30)
    c.request(method, path, body=body, headers=dict({"User-Agent": "short-test"}, **(headers or {})))
    r = c.getresponse()
    text = r.read().decode("utf-8", "replace")
    c.close()
    return r.status, text
if sys.argv[1] == "get":
    s, text = ask("GET", sys.argv[2])
    sys.stdout.write(f"{s} {text}")
else:
    sid, kind, rows, d1, d2, lines, token = sys.argv[2:9]
    headers = {"Content-Type": "application/x-ndjson", "Shipment-Id": sid, "Shipment-Type": kind,
               "Shipment-Rows": rows, "Shipment-From": d1, "Shipment-To": d2,
               "Shipment-Source": "short-test", "Shipment-Name": sys.argv[9] if len(sys.argv) > 9 else sid}
    if token != "none":
        headers["Authorization"] = "Bearer " + token
    body = b"".join(b"{\"n\": %d, \"v\": 1.5}\n" % i for i in range(int(lines)))
    s, text = ask("POST", "/shipments", body, headers)
    print(s, " ".join(text.split()))
'
web() { docker exec -i "$(ctr partners-backend)" python3 -I - "$@" <<EOF
$WEB_PY
EOF
}
jq_py() { code=$1; shift; python3 -c "import json, sys; d = json.loads(sys.stdin.read().split(' ', 1)[1]); $code" "$@"; }

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
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
info "gmctl render --handover $HANDOVER"
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
svc = stack["services"]
print(svc["partners-api"]["networks"])
print(" ".join(sorted(n for n, s in svc.items()
                      if any(x["source"] == f"{gid}_http_cold_storage" for x in s.get("secrets", [])))))
EOF
)
same "stack: partners-api with the alias cold-storage" "{'backend': {'aliases': ['cold-storage']}}" \
    "$(printf '%s\n' "$st" | sed -n 1p)"
same "stack: http_cold_storage on records and partners-api only" "partners-api records" \
    "$(printf '%s\n' "$st" | sed -n 2p)"

# --- deployment: the caller first ----------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
TOKEN=$(cat "$LDIR/secrets/http_cold_storage")
w=$(rsql postgres "select current_setting('archive_mode') || '|' || current_setting('archive_command')")
same "records archives to the vault" "on|vault-post wal %f %p" "$w"
before_fail=$(archiver | cut -d' ' -f2)
SEG1=$(switch_wal)
k=0
while [ "$k" -lt 60 ]; do
    set -- $(archiver 2>/dev/null)
    [ "${2:-0}" -gt "$before_fail" ] && [ "${3:-}" = "$SEG1" ] && break
    sleep 2; k=$((k + 2))
done
w=$(archiver)
case $w in *" $SEG1") pass "before the vault's database is loaded, $SEG1 fails honestly (pg_stat_archiver: $w)" ;;
    *) fail "segment $SEG1 before load-data: [$w]" ;; esac
n=$(rlog | grep "vault-post: wal $SEG1: " | head -n 1)
case $n in *"refused it: 503"*|*"no answer from the vault"*) pass "vault-post's reason in the server log: $(printf '%s' "$n" | sed 's/.*vault-post: //')" ;;
    *) fail "no honest reason in records' log: [$n]" ;; esac

info "gmctl load-data"
if $GMCTL load-data "$SCN" --playground "$PG"; then pass "load-data"; else fail "load-data"; exit 1; fi
w=$(dbsql partners "select rolpassword like 'SCRAM-SHA-256\$%' from pg_authid where rolname = 'coldstore'")
same "load-data: coldstore logs in with its SCRAM password" t "$w"
wait_archived "$SEG1" 180 && pass "the archiver retries and ships $SEG1 once the vault answers ($(archiver))" \
    || fail "$SEG1 not shipped on the retry: $(archiver)"
info "gmctl inject, start-load"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject" || fail "inject"
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0)"; else fail "start-load"; exit 1; fi
TODAY=$(date -u +%Y-%m-%d)
FIRST=$(date -u -d "$TODAY - 35 days" +%Y-%m-%d)
LAST=$(date -u -d "$TODAY - 1 day" +%Y-%m-%d)

# --- the planted history ------------------------------------------------------
w=$(dbsql partners "select type || ' ' || count(*) || ' ' || count(distinct date_from) || ' ' || min(date_from) || ' ' || max(date_from) || ' ' || bool_and(rows_declared = rows_received and source = 'records')::text from coldstore.manifests where date_from < current_date group by type order by type")
info "planted (type, manifests, days, first, last): $(printf '%s' "$w" | tr '\n' ';')"
case $(printf '%s\n' "$w" | sed -n 1p) in "basebackup 35 35 $FIRST $LAST true") pass "planted: a base backup a night, $FIRST to $LAST" ;;
    *) fail "planted base backups: [$w]" ;; esac
case $(printf '%s\n' "$w" | sed -n 2p) in "wal "*" 35 $FIRST $LAST true") pass "planted: the WAL segments of the same 35 days ($(printf '%s\n' "$w" | sed -n 2p | cut -d' ' -f2) manifests)" ;;
    *) fail "planted segments: [$w]" ;; esac

# --- a switched segment ---------------------------------------------------------
w=$(manifest "$SEG1")
same "$SEG1's manifest names records (wal, 16 MB, 1 of 1, today)" "wal|records|$SEG1|1|1|16777216|$TODAY|$TODAY" "$w"
SEG2=$(switch_wal)
wait_archived "$SEG2" 90 && pass "a segment switched at T0 archived: $SEG2" || fail "$SEG2 not archived: $(archiver)"
same "its manifest names records" "wal|records|$SEG2|1|1|16777216|$TODAY|$TODAY" "$(manifest "$SEG2")"

# --- POST /shipments ------------------------------------------------------------
r=$(web post vitals-x vitals 3 "$TODAY" "$TODAY" 3 none)
case $r in 401\ *) pass "an upload without the account key: 401 ($r)" ;; *) fail "upload without credential: [$r]" ;; esac
r=$(web post "vitals-$LAST" vitals 1000 "$LAST" "$LAST" 1000 "$TOKEN")
case $r in 201\ *'"shipment_id":"vitals-'"$LAST"'"'*'"rows_declared":1000,"rows_received":1000'*) pass "a data type's shipment: its NDJSON lines counted, the receipt 201: $r" ;;
    *) fail "a vitals shipment: [$r]" ;; esac
r=$(web post "vitals-$TODAY" vitals 520 "$TODAY" "$TODAY" 480 "$TOKEN")
case $r in 201\ *'"rows_declared":520,"rows_received":480'*) pass "a short shipment: received 480 of 520 declared ($r)" ;;
    *) fail "a short shipment: [$r]" ;; esac
at1=$(dbsql partners "select received_at from coldstore.manifests where shipment_id = 'vitals-$LAST'")
r=$(web post "vitals-$LAST" vitals 1000 "$LAST" "$LAST" 1000 "$TOKEN")
w=$(dbsql partners "select count(*) || ' ' || (received_at > '$at1') from coldstore.manifests where shipment_id = 'vitals-$LAST' group by received_at")
same "the same shipment id again replaces its manifest (one manifest, received again)" "1 true" "$w"
r=$(web post bad vitals 3 "$TODAY" 2026-13-01 3 "$TOKEN")
case $r in 400\ *Shipment-To*) pass "a malformed header: 400 naming it ($r)" ;; *) fail "malformed header: [$r]" ;; esac
dbsql partners "update coldstore.state set value = 'refuse' where name = 'uploads'" >/dev/null
r=$(web post probe-refused vitals 1 "$TODAY" "$TODAY" 1 "$TOKEN")
case $r in 503\ *) pass "its state read at each request: uploads refuse, 503 ($r)" ;; *) fail "uploads refuse: [$r]" ;; esac
k=0
while [ "$k" -lt 100 ] && [ "$(dbsql partners "select value from coldstore.state where name = 'uploads'")" != accept ]; do sleep 3; k=$((k + 3)); done
same "the back end's coldstore.normal restores the baseline (within ${k} s)" accept \
    "$(dbsql partners "select value from coldstore.state where name = 'uploads'")"
same "no manifest for the refused shipment" 0 "$(dbsql partners "select count(*) from coldstore.manifests where shipment_id = 'probe-refused'")"

# --- the base backup, its crontab line moved to the next minute ---------------------
now=$(date -u +%s)
[ $((now % 60)) -gt 30 ] && now=$((now + 60))
at=$((now + 60))
M=$(date -u -d "@$at" +%-M); H=$(date -u -d "@$at" +%-H)
sed "s/^30 3 \* \* \* /$M $H * * * /" "$HERE/nodes/records/crontab" | docker exec -i "$(ctr records)" crontab -u postgres - \
    && pass "records: the base-backup job moved to $H:$(printf %02d "$M") UTC" || fail "moving the base-backup job"
NAME="records-$(date -u -d "@$at" +%Y%m%dT%H%MZ)"
k=0
while [ "$k" -lt 240 ] && [ -z "$(manifest "$NAME")" ]; do sleep 3; k=$((k + 3)); done
w=$(manifest "$NAME")
case $w in "basebackup|records|$NAME|1|1|"*"|$TODAY|$TODAY") pass "the base backup's manifest names records: $w" ;;
    *) fail "no base backup manifest $NAME: [$w] $(cx records cat /var/log/postgresql/cron/basebackup.log 2>&1 | tail -n 2)" ;; esac
size=$(printf '%s' "$w" | cut -d'|' -f6)
[ "${size:-0}" -gt 1000000 ] && pass "streamed whole to the stub: $size bytes counted" || fail "base backup size: $size"
w=$(cx records grep -c "vault-post: basebackup $NAME shipped, $size bytes" /var/log/postgresql/cron/basebackup.log 2>&1)
same "the job's log records the receipt" 1 "$w"
m=$(docker stats --no-stream --format '{{.MemUsage}}' "$(ctr partners-api)")
info "partners-api's memory after the base backup: $m"

# --- GET /manifests ---------------------------------------------------------------
r=$(web get "/manifests?type=wal&from=$TODAY&to=$TODAY")
w=$(printf '%s' "$r" | jq_py 'print(sorted({m["type"] for m in d}), all(m["date_from"] <= sys.argv[1] <= m["date_to"] for m in d), sorted(m["shipment_id"] for m in d if m["shipment_id"] in sys.argv[2:]))' "$TODAY" "$SEG1" "$SEG2" 2>&1)
same "GET /manifests?type=wal&from=&to= today: wal only, today's, both segments" "['wal'] True ['$SEG1', '$SEG2']" "$w"
r=$(web get "/manifests?type=basebackup&from=$FIRST&to=$LAST")
w=$(printf '%s' "$r" | jq_py 'print(len(d), min(m["date_from"] for m in d), max(m["date_to"] for m in d), {m["source"] for m in d})')
same "the planted base backups by date: 35, $FIRST to $LAST, records" "35 $FIRST $LAST {'records'}" "$w"
r=$(web get "/manifests?from=$LAST&to=$LAST")
w=$(printf '%s' "$r" | jq_py 'ts = [m["received_at"] for m in d]; print(sorted({m["type"] for m in d}), ts == sorted(ts), all(m["date_from"] <= sys.argv[1] <= m["date_to"] for m in d))' "$LAST")
same "one day, every type, in the order received" "['basebackup', 'vitals', 'wal'] True True" "$w"
r=$(web get "/manifests?source=short-test")
w=$(printf '%s' "$r" | jq_py 'print(sorted(m["shipment_id"] for m in d))')
same "by source" "['vitals-$LAST', 'vitals-$TODAY']" "$w"
r=$(web get "/manifests?from=yesterday")
case $r in 422\ *) pass "a bad date: 422" ;; *) fail "bad date: [$(printf '%s' "$r" | cut -c1-120)]" ;; esac

# --- GET / --------------------------------------------------------------------------
r=$(web get /)
page=${r#* }
case $r in 200\ *) pass "GET /: 200, public" ;; *) fail "GET /: [$(printf '%s' "$r" | cut -c1-120)]" ;; esac
[ -n "${KEEP:-}" ] && printf '%s' "$page" > "$KEEP/cold-storage.html"
w=$(printf '%s' "$page" | python3 -c '
import re, sys
p = sys.stdin.read()
print(re.findall(r"<h2>([^<]*)</h2>", p), p.count("<svg"), "<script" in p.lower(),
      len(re.findall(r"class=\"dec\"", p)) > 0, len(re.findall(r"class=\"rec\"", p)) > 0,
      len(re.findall(r"class=\"mis\"", p)))')
same "the page: one chart per type, declared and received columns, one mismatch marked, no script" \
    "['wal', 'basebackup', 'vitals'] 3 False True True 1" "$w"
case $page in *"$TODAY: declared 520, received 480, 1 shipment"*) pass "the short day's column says so in its tooltip" ;;
    *) fail "no tooltip for $TODAY's vitals" ;; esac
case $page in *"Received differs from declared: $TODAY (declared 520, received 480)"*) pass "and the mismatch is named under its chart" ;;
    *) fail "the mismatch line" ;; esac
PFIRST=$(date -u -d "$TODAY - 34 days" +%Y-%m-%d)
n=$(printf '%s' "$page" | grep -o "$PFIRST: declared" | wc -l | tr -d ' ')
same "the planted history on the page: its first day, $PFIRST, charted for wal and basebackup" 4 "$n"

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
