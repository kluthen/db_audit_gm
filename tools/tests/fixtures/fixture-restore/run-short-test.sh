#!/bin/sh
# Short test of the restore fixture (v0.5 build plan, chunk 28; master spec
# 7.1, 15 "The restore from the hand-over snapshot", 18.2; capture W2-g of
# specs/versions/v0.5/wave-log.md; spec D397): a restart from the hand-over
# snapshot gives back replication. On one host, about ten minutes.
#
# On a copy of tools/tests/fixtures/fixture-restore (bastion 0.5.0; records:
# postgres 0.5.0 archiving to cold-storage:8000 with the credential
# cold_storage, the fault f1 planting the slot old_reports beside the
# standby's; standby: postgres 0.5.0, records' standby; partners-api: api
# 0.1.0 serving partners/coldstore/ under cold-storage; partners-db: postgres
# 0.5.0 with partners/shared/ and coldstore's data; no scheduler node):
#   fit (the laptop playground, 2 CPU / 4G / 16G, so the snapshot fits) ->
#   render -> deploy -> load-data (the standby cloned, streaming) -> inject
#   (old_reports on records) -> check --handover-check -> snapshot (records
#   copied first, old_reports recorded, the standby's slot not) -> a row
#   written on records -> status --set handed-over -> restart, then:
#   - the standby's log since the restore: in standby mode, never a primary;
#   - records' pg_stat_replication: the standby's slot active, its sender
#     streaming; a read-only query answered on the standby, a write refused;
#   - a row written on records after the restart read on the standby within
#     30 s; the one written between the snapshot and the restart gone;
#   - old_reports on records again: physical, inactive, reserving WAL;
#   - a switched segment's wal manifest naming records in GET /manifests,
#     pg_stat_archiver's failed_count unchanged by it;
#   - measured (docs/gm.md, "Snapshot"): the WAL old_reports held and
#     pg_wal's size, and the cumulative statistics (pg_stat_archiver,
#     pg_stat_user_tables), before the snapshot and after the restart;
#   -> teardown, then nothing labelled with either game id or the snapshot's
#   label is left and the objects not belonging to the game are unchanged.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-restore/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=restore-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/postgres:0.5.0"
LABELS="com.docker.stack.namespace dbagm.game dbagm.snapshot"
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
    done | { grep -v -e " ${FIRST}_" -e " ${GAME}_" -e " dbagm-snapshot_${FIRST}_" || true; } | sort
}

labelled() {   # labelled <game id>...
    for g in "$@"; do
        for l in $LABELS; do
            for k in $KINDS; do
                docker "$k" ls --filter "label=$l=$g" --format "$k {{.Name}}"
            done
            docker ps -a --filter "label=$l=$g" --format 'container {{.Names}}'
        done
    done | sort -u
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
for image in $IMAGES; do
    docker image inspect "$image" >/dev/null 2>&1 \
        || { echo "image $image not built (see the header of $0)" >&2; exit 2; }
done

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-restore-short.XXXXXX")
SCN=$tmp/fixture-restore
LDIR=$SCN/local/$PG
GAME=
FIRST=
deployed=no

cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
        left=$(labelled "$FIRST" "$GAME")
        [ -z "$left" ] || echo "WARNING: objects of game $FIRST/$GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$HERE" "$SCN"
rm -f "$SCN/run-short-test.sh"

game_id() { sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml"; }
# The node's running container (one replica).
ctr() { docker ps -q --filter "label=com.docker.swarm.service.name=${GAME}_$1" | head -n 1; }
cx() { n=$1; shift; docker exec "$(ctr "$n")" "$@"; }
rsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -d "$1" -c "$2"; }
ssql() { docker exec -u postgres "$(ctr standby)" psql -XAtq -d "$1" -c "$2"; }
archiver() { rsql postgres "select coalesce(last_archived_wal, '-') || ' ' || failed_count || ' ' || archived_count from pg_stat_archiver"; }
switch_wal() { rsql postgres "select pg_logical_emit_message(false, 'short-test', repeat('x', 1000)); select pg_walfile_name(pg_switch_wal())" | tail -n 1; }
wait_archived() {  # wait_archived <segment> <seconds>
    k=0
    while [ "$k" -lt "$2" ]; do
        case $(archiver 2>/dev/null) in "$1 "*) return 0 ;; esac
        sleep 2; k=$((k + 2))
    done
    return 1
}
replication() { rsql postgres "select s.slot_name || '|' || s.active || '|' || r.state from pg_replication_slots s join pg_stat_replication r on r.pid = s.active_pid where r.application_name = 'standby'"; }
planted() { rsql postgres "select slot_type || '|' || active || '|' || (restart_lsn is not null) || '|' || coalesce(wal_status, '-') from pg_replication_slots where slot_name = 'old_reports'"; }
held_wal() { rsql postgres "select pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) from pg_replication_slots where slot_name = 'old_reports'"; }
pg_wal_size() { cx records du -sh /var/lib/postgresql/18/data/pg_wal | cut -f1; }
visits_stats() { rsql clinic "select n_tup_ins || ' inserted, ' || n_live_tup || ' live' from pg_stat_user_tables where relname = 'visits'"; }
# The standby's server log since an instant ("YYYY-MM-DD HH:MM:SS", UTC).
sb_log_since() {
    cx standby sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null \
        | awk -v since="$1" '/^[0-9][0-9][0-9][0-9]-/ { keep = ($1 " " $2 >= since) } keep'
}

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

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 16G)"
if out=$($GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 16G); then
    pass "fit: the five nodes and their reservations fit 2 CPU / 4G / 16G"
else
    printf '%s\n' "$out"
    fail "fit"
    exit 1
fi
case $out in *"snapshot: copies"*": fits"*) pass "fit: the hand-over snapshot fits" ;;
    *) fail "fit: the snapshot does not fit: $(printf '%s\n' "$out" | grep 'snapshot:')"; exit 1 ;; esac
GAME=$(game_id)
FIRST=$GAME
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null
[ -z "$(labelled "$GAME")" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- the game up to the hand-over -----------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy: the five nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
info "gmctl load-data (the standby cloned last)"
t=$(date +%s)
if out=$($GMCTL load-data "$SCN" --playground "$PG"); then
    pass "load-data ($(( $(date +%s) - t )) s)"
else
    printf '%s\n' "$out"
    fail "load-data"
    exit 1
fi
same "load-data: the standby streaming from its slot on records" "standby|true|streaming" "$(replication)"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject" || fail "inject"
same "f1 planted: old_reports on records, physical, inactive, reserving WAL" "physical|false|true|reserved" "$(planted)"
out=$($GMCTL check "$SCN" --playground "$PG" --handover-check) && pass "check --handover-check" \
    || { printf '%s\n' "$out"; fail "check --handover-check"; }
SEG0=$(switch_wal)
wait_archived "$SEG0" 90 && pass "before the snapshot, $SEG0 archived to the vault" || fail "$SEG0 not archived: $(archiver)"
rsql clinic "insert into visits (animal_id, seen_at) select 1 + g % 400, now() from generate_series(1, 20000) g" >/dev/null
SEG1=$(switch_wal)
wait_archived "$SEG1" 90 || fail "$SEG1 not archived: $(archiver)"
m_held=$(held_wal); m_wal=$(pg_wal_size); m_arch=$(archiver); m_stats=$(visits_stats)
info "measured before the snapshot: old_reports holds $m_held of WAL, pg_wal $m_wal; pg_stat_archiver (last, failed, archived) $m_arch; visits $m_stats"

info "gmctl snapshot"
t=$(date +%s)
if out=$($GMCTL snapshot "$SCN" --playground "$PG"); then
    pass "snapshot ($(( $(date +%s) - t )) s): $(printf '%s\n' "$out" | grep 'snapshot taken' | sed 's/.*snapshot taken, //')"
else
    printf '%s\n' "$out"
    fail "snapshot"
    exit 1
fi
w=$(python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
snap = yaml.safe_load(open(sys.argv[1]))["snapshot"]
print(list(dict.fromkeys(v["node"] for v in snap["volumes"])))
print(snap.get("slots"))
EOF
)
same "the snapshot copied records (vault_target) first, then the rest in nodes order" \
    "['records', 'bastion', 'standby', 'partners-api', 'partners-db']" "$(printf '%s\n' "$w" | sed -n 1p)"
same "the snapshot recorded old_reports, not the standby's slot nor its own temporary one" \
    "[{'node': 'records', 'name': 'old_reports'}]" "$(printf '%s\n' "$w" | sed -n 2p)"
rsql clinic "insert into visits (animal_id, seen_at) values (9001, now())" >/dev/null
same "a row written on records between the snapshot and the restart (animal 9001)" 1 \
    "$(rsql clinic "select count(*) from visits where animal_id = 9001")"
$GMCTL status "$SCN" --playground "$PG" --set handed-over >/dev/null && pass "status --set handed-over" || fail "handed-over"

# --- the restart from the snapshot -----------------------------------------------
since=$(date -u '+%Y-%m-%d %H:%M:%S')
info "gmctl restart --confirmation (from the hand-over snapshot), at $since UTC"
t=$(date +%s)
if out=$($GMCTL restart "$SCN" --playground "$PG" \
        --confirmation "Yes, restart from the hand-over snapshot (restore fixture, test harness)"); then
    r_secs=$(( $(date +%s) - t ))
    pass "restart from the snapshot (${r_secs} s)"
else
    printf '%s\n' "$out"
    fail "restart"
    GAME=$(game_id)
    exit 1
fi
printf '%s\n' "$out" | grep -E 'standby|slot|restored' | sed 's/^/        /'
GAME=$(game_id)
[ "$GAME" != "$FIRST" ] && pass "a new game id: $GAME" || fail "the game id did not change"
for line in "standby: standby.signal written into its restored data volume before the stack started" \
            "records: replication slot old_reports re-created (physical, reserving WAL, inactive)" \
            "standby: cloned again from records (clone-standby --restore), a standby streaming from slot standby"; do
    case $out in *"$line"*) pass "restart's text: $line" ;; *) fail "restart's text lacks: $line" ;; esac
done
w=$(python3 - "$LDIR/state.yaml" <<'EOF'
import sys, yaml
r = yaml.safe_load(open(sys.argv[1]))["restarts"][-1]
print(r["status"], r.get("slots"), r.get("standbys"))
EOF
)
same "the restart's record names the slot re-created and the standby cloned" \
    "completed [{'node': 'records', 'name': 'old_reports'}] [{'node': 'standby', 'primary': 'records', 'slot': 'standby'}]" "$w"

# --- replication given back ------------------------------------------------------
log=$(sb_log_since "$since")
n_standby=$(printf '%s\n' "$log" | grep -c "entering standby mode" || true)
n_ro=$(printf '%s\n' "$log" | grep -c "ready to accept read-only connections" || true)
n_rw=$(printf '%s\n' "$log" | grep -c -e "ready to accept connections" -e "selected new timeline ID" -e "archive recovery complete" || true)
[ "$n_standby" -ge 2 ] && [ "$n_ro" -ge 1 ] && [ "$n_rw" = 0 ] \
    && pass "the standby's log since the restore: standby mode at each start ($n_standby), read-only ($n_ro), never a primary" \
    || fail "the standby's log since the restore: standby mode $n_standby, read-only $n_ro, as a primary $n_rw"
same "records: the standby's slot active, its sender streaming" "standby|true|streaming" "$(replication)"
same "standby: in recovery" t "$(ssql postgres 'select pg_is_in_recovery()')"
w=$(ssql clinic "select count(*) > 0 from visits" 2>&1)
same "standby: a read-only query answered" t "$w"
w=$(ssql clinic "insert into visits (animal_id, seen_at) values (1, now())" 2>&1 || true)
case $w in *"read-only transaction"*) pass "standby: a write refused (read-only)" ;; *) fail "a write on the standby: $w" ;; esac
same "records: the row written between the snapshot and the restart is gone" 0 \
    "$(rsql clinic "select count(*) from visits where animal_id = 9001")"
same "standby: nor is it there" 0 "$(ssql clinic "select count(*) from visits where animal_id = 9001")"
rsql clinic "insert into visits (animal_id, seen_at) values (9002, now())" >/dev/null
k=0
while [ "$k" -lt 30 ] && [ "$(ssql clinic "select count(*) from visits where animal_id = 9002" 2>/dev/null)" != 1 ]; do sleep 1; k=$((k + 1)); done
[ "$k" -lt 30 ] && pass "a row written on records after the restart read on the standby within ${k} s" \
    || fail "the row written after the restart not on the standby after 30 s"
same "old_reports on records again: physical, inactive, reserving WAL" "physical|false|true|reserved" "$(planted)"

# --- archiving and the vault in step ------------------------------------------------
a_arch=$(archiver); a_held=$(held_wal); a_wal=$(pg_wal_size); a_stats=$(visits_stats)
info "measured after the restart: old_reports holds $a_held of WAL, pg_wal $a_wal; pg_stat_archiver (last, failed, archived) $a_arch; visits $a_stats"
f_before=$(printf '%s' "$a_arch" | cut -d' ' -f2)
SEG2=$(switch_wal)
wait_archived "$SEG2" 120 && pass "after the restart, a switched segment archived: $SEG2" || fail "$SEG2 not archived: $(archiver)"
f_after=$(archiver | cut -d' ' -f2)
same "pg_stat_archiver's failed_count unchanged by it" "$f_before" "$f_after"
r=$(web_get "/manifests?type=wal&source=records")
w=$(printf '%s' "$r" | python3 -c 'import json, sys; t = sys.stdin.read(); s, b = t.split(" ", 1); d = json.loads(b); print(s, [m["source"] + ":" + m["type"] for m in d if m["shipment_id"] == sys.argv[1]])' "$SEG2" 2>&1)
same "GET /manifests: $SEG2's wal manifest names records" "200 ['records:wal']" "$w"
w=$(printf '%s' "$r" | python3 -c 'import json, sys; d = json.loads(sys.stdin.read().split(" ", 1)[1]); print(sorted({m["shipment_id"] for m in d} & set(sys.argv[1:])))' "$SEG0" "$SEG1" 2>&1)
same "the vault's restored manifests name the segments archived before the snapshot" "['$SEG0', '$SEG1']" "$w"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled "$FIRST" "$GAME")
[ -z "$left" ] && pass "nothing labelled with $FIRST or $GAME is left, the snapshot's copies included" || fail "left behind: $left"
same "the objects not belonging to the game are unchanged" "$before" "$(others)"

info "elapsed $(( $(date +%s) - started )) s (the restart ${r_secs:-?} s)"
printf '\n%d passed, %d failed\n' "$passes" "$failures"
[ "$failures" -eq 0 ]
