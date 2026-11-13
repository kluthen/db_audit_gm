#!/bin/sh
# Short test of the lab fixture (v0.5 build plan chunk 25; master spec 17.2,
# 17.3 s10; capture W5 items 0 and 4, W5-h, of
# specs/versions/v0.5/wave-log.md; spec D462): pg-monitoring-option-absent,
# a topology fault, planted by the fixture's topology itself (lab without
# options: [monitoring]), its instance s10 committed. On one host, under 30
# minutes with the deployment; no scheduler node, so no aging and no shift.
#
#   fit (2 CPU / 4G / 8G) -> render -> the stack file: monitoring_password
#   declared by postgres-exporter alone, mounted on exporter and not on lab
#   -> deploy (the game's monitoring_password generated, W5 item 4) ->
#   load-data -> inject (s10 listed as a topology fault, nothing run), then:
#   - present: no role monitoring on lab; the exporter's logins refused in
#     lab's server log; the exporter's metrics pg_up 0; gmctl check reads
#     s10 present;
#   - the GM applying the accepted proposal (spec D462): the game's
#     monitoring_password read on exporter as root, the role created on lab
#     as postgres, unseen, as the option's initdb step does (CREATE ROLE
#     monitoring LOGIN PASSWORD ...; GRANT pg_monitor TO monitoring);
#   - fixed: the role a member of pg_monitor, the exporter's metrics present
#     (pg_up 1, pg_stat_statements' among them); gmctl check reads s10
#     fixed; the password in no log line on lab;
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-lab/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=lab-short
INST=s10
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-lab-short.XXXXXX")
SCN=$tmp/fixture-lab
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
dbsql() { docker exec -u postgres "$(ctr lab)" psql -XAtq -d "$1" -c "$2"; }
pg_up() { docker exec "$(ctr exporter)" curl -fsS -m 10 http://127.0.0.1:9187/metrics 2>/dev/null | sed -n 's/^pg_up \(.*\)$/\1/p'; }
# The fault's sealed check, as the GM runs it: prints "<exit> <its line>".
fcheck() {
    set +e
    out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | grep "^$INST " | head -n 1)"
}

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the three nodes fit 2 CPU / 4G / 8G, lab without the option (the loader accepts the exporter's target for s10)"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
$GMCTL render "$SCN" --playground "$PG" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("lab", "exporter"):
    svc = stack["services"][node]
    names = sorted(s["source"][len(gid) + 1:] for s in svc.get("secrets", [])
                   if s["source"][len(gid) + 1:] == "monitoring_password")
    env = svc.get("environment") or {}
    opts = env.get("GM_OPTIONS") if isinstance(env, dict) else \
        next((e.split("=", 1)[1] for e in env if e.startswith("GM_OPTIONS=")), None)
    print(node, " ".join(names) or "-", repr(opts))
print("declared", "monitoring_password" in {k[len(gid) + 1:] for k in (stack.get("secrets") or {})})
EOF
)
same "stack: monitoring_password mounted on exporter alone, lab's GM_OPTIONS empty, the secret declared for the game" \
    "lab - '' exporter monitoring_password None declared True" "$(printf '%s' "$st" | tr '\n' ' ' | sed 's/ $//')"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG" >/dev/null; then
    pass "deploy: the three nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi
same "the game's monitoring_password exists (only postgres-exporter declares it: W5 item 4)" \
    "${GAME}_monitoring_password" \
    "$(docker secret ls --filter "name=${GAME}_monitoring_password" --format '{{.Name}}')"
same "exporter mounts it, lab does not" "yes no" \
    "$(docker exec -u root "$(ctr exporter)" test -s /opt/gm/secrets/monitoring_password && echo yes || echo no) $(docker exec -u root "$(ctr lab)" test -e /opt/gm/secrets/monitoring_password && echo yes || echo no)"
info "gmctl load-data"
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: lab's data file"
else
    fail "load-data"
    exit 1
fi
out=$($GMCTL inject "$SCN" --playground "$PG" 2>&1) && pass "inject: nothing run ($(printf '%s' "$out" | grep -i -m 1 "$INST" || printf '%s' "$out" | tail -n 1))" \
    || fail "inject: $out"
case $(printf '%s' "$out" | grep -i "$INST") in *topology*|*pg-monitoring-option-absent*) pass "inject lists $INST as a topology fault" ;;
    *) fail "inject does not list $INST as a topology fault: $out" ;; esac

# --- present ------------------------------------------------------------------
same "present: no role monitoring on lab" "0" "$(dbsql postgres "SELECT count(*) FROM pg_roles WHERE rolname = 'monitoring'")"
i=0
while [ "$i" -lt 60 ] && [ "$(pg_up)" != 0 ]; do sleep 2; i=$((i + 2)); done
same "present: the exporter's metrics read pg_up 0" "0" "$(pg_up)"
refused=$(docker exec -u root "$(ctr lab)" sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null \
    | grep -c 'password authentication failed for user "monitoring"' || true)
if [ "${refused:-0}" -ge 1 ]; then
    pass "present: lab's log holds the exporter's refused logins ($refused 'password authentication failed for user \"monitoring\"')"
else
    fail "present: no refused login of monitoring in lab's log"
fi
r=$(fcheck)
case $r in "1 "*) pass "gmctl check: $INST present (${r#* })" ;; *) fail "gmctl check before the fix: $r" ;; esac

# --- the GM applies the accepted proposal ----------------------------------------
# The game's password, read as root on exporter (its only mount), into the
# role on lab as the option's initdb step creates it, as postgres, unseen; on
# standard input, never on a command line.
pw=$(docker exec -u root "$(ctr exporter)" cat /opt/gm/secrets/monitoring_password)
[ -n "$pw" ] || { fail "cannot read the game's monitoring_password on exporter"; exit 1; }
printf "SET log_statement = 'none';\nSET log_min_duration_statement = -1;\nSET log_min_error_statement = 'panic';\nSET pgaudit.log = 'none';\nSET pg_stat_statements.track = 'none';\nCREATE ROLE monitoring LOGIN PASSWORD '%s';\nGRANT pg_monitor TO monitoring;\n" \
    "$(printf '%s' "$pw" | sed "s/'/''/g")" \
    | docker exec -i -u postgres "$(ctr lab)" psql -X -q -v ON_ERROR_STOP=1 -d postgres \
    && pass "the GM's fix: role monitoring created on lab with the game's monitoring_password (as the option's initdb step)" \
    || fail "the GM's fix: the role not created"
FIXED_AT=$(date +%s)

# --- fixed --------------------------------------------------------------------------
same "fixed: monitoring can log in and holds pg_monitor" "t t" \
    "$(dbsql postgres "SELECT rolcanlogin || ' ' || pg_has_role('monitoring', 'pg_monitor', 'USAGE') FROM pg_roles WHERE rolname = 'monitoring'" | tr -d '\n' | sed 's/true/t/g; s/false/f/g')"
i=0
while [ "$i" -lt 90 ] && [ "$(pg_up)" != 1 ]; do sleep 3; i=$((i + 3)); done
same "fixed: the exporter's metrics read pg_up 1 ($(( $(date +%s) - FIXED_AT )) s after the fix)" "1" "$(pg_up)"
n=$(docker exec "$(ctr exporter)" curl -fsS -m 10 http://127.0.0.1:9187/metrics 2>/dev/null | grep -c '^pg_stat_statements_' || true)
if [ "${n:-0}" -ge 1 ]; then pass "fixed: the exporter's metrics present ($n pg_stat_statements_ lines)"; else fail "fixed: no pg_stat_statements_ metric"; fi
r=$(fcheck)
case $r in "0 "*) pass "gmctl check: $INST fixed (${r#* })" ;; *) fail "gmctl check after the fix: $r" ;; esac
leaked=$(docker exec -u root "$(ctr lab)" sh -c 'cat /var/log/postgresql/postgresql-*.log' 2>/dev/null | grep -c -F "$pw" || true)
same "the password in no log line on lab" "0" "${leaked:-0}"
unset pw

# --- teardown ------------------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG" >/dev/null; then
    deployed=no
    left=$(labelled)
    same "teardown: nothing labelled with game $GAME left" "" "$left"
else
    fail "teardown"
fi

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
