#!/bin/sh
# The governance check set on a real swarm (v0.4 chunk 12; master spec
# 11.6; capture W3-a; spec D230, D231): each rule G1 to G4 broken and kept
# on fixture-instances.
#
# On a copy of tools/tests/fixtures/fixture-instances (bastion, db,
# reporting) to which it adds the transformer node bi (breaches/bi/, with
# the `aging:` a scheduler node requires) and, on db, the option
# monitoring (v0.5, the role g2-own-role-kept grants): fit -> render --handover ->
# deploy -> load-data, never inject nor start-load, so no scheduler job
# runs and nobody triggers one; then:
#   - one compliant outbox row sent now, CHECK_SINCE a minute before it;
#   - the baseline: tools/tests/check-governance.sh exits 0, and each rule
#     alone reads 0 from either database node, G3 0 on bi;
#   - each breach of breaches/*.sql planted as postgres on its node, each
#     rule reading what its `expect:` line says (from db; its broken rules
#     from reporting too, the first line naming the rule, and starting
#     with its `first:` line's text when it has one), then reverted, every
#     rule back to 0 (from v0.4 chunk 20, g1-separation-database: a second
#     database on db, which personal's `separation: instance` refuses;
#     spec D253);
#   - breaches/g3-transformer-source.sh on bi: G3 reads 1 there, 0 after;
#   - the set returning to its caller, and reading 2 when it cannot judge:
#     an unknown or repeated rule, no CHECK_GOVERNANCE, G4 without
#     CHECK_SINCE, G1 on a transformer, the mapping-roles function or the
#     read policy gm_check_read gone (both restored as load-data writes
#     them); G4 reading 3 with no row since CHECK_SINCE;
#   -> teardown.
#
# Usage: sh tools/tests/smoke-governance.sh <playground> [<gmctl fit option>...]
#   Without fit options, the local engine at its own capacity.
# Needs: a swarm manager on the local engine, python3 with PyYAML, the
# images bastion 0.5.0, postgres 0.5.0, scheduler 0.3.0 built; host ports
# 2222 and 8080 free. Docker steps: run it under the host lock and the
# sleep inhibitor:
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#     sh tools/tests/smoke-governance.sh armenelos
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 -B $REPO/tools/gmctl"
FIXTURE=$REPO/tools/tests/fixtures/fixture-instances

[ $# -ge 1 ] || { echo "usage: sh $0 <playground> [<gmctl fit option>...]" >&2; exit 2; }
PG=$1; shift
case $PG in ''|*/*) echo "not a playground name: $PG" >&2; exit 2 ;; esac

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
if [ $# -eq 0 ]; then
    root=$(docker info --format '{{.DockerRootDir}}')
    df -Pk "$root" >/dev/null 2>&1 || root=/
    set -- --cpu "$(nproc)" \
        --memory "$(awk '/^MemAvailable:/ { printf "%dM", $2 / 1024 }' /proc/meminfo)" \
        --disk "$(df -Pk "$root" | awk 'NR == 2 { printf "%dG", $4 / 1048576 }')"
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-governance.XXXXXX")
SCN=$tmp/fixture-instances
deployed=no
cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$FIXTURE" "$SCN"
rm -rf "${SCN:?}/local"
python3 -B - "$SCN" <<'EOF'
import sys, yaml
from pathlib import Path
d = Path(sys.argv[1])
s = yaml.safe_load(open(d / "scenario.yaml"))
s["nodes"].append(yaml.safe_load(open(d / "breaches/bi/node.yaml")))
s["aging"] = {"minimum": "8h", "handover_at": "14:00"}
s["designed_for"]["placement"]["bi"] = "host-1"
# v0.5 (master spec 7.1, options): the monitoring role exists only on a node
# choosing the option; breaches/g2-own-role-kept.sql grants it on db.
next(n for n in s["nodes"] if n["name"] == "db")["options"] = ["monitoring"]
yaml.safe_dump(s, open(d / "scenario.yaml", "w"), sort_keys=False)
EOF

# on <node> <user> [gmctl exec options]: the script on stdin, run on <node>.
on() {
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
GOV=
SINCE=
# set_run <node> <env: all|nosince|none> <call arguments...>: the set run
# on <node> as root, as a sealed check calls it; prints its output and a
# last line `after rc=<n>` (the caller still running); exits as the set.
set_run() {
    n=$1 e=$2; shift 2
    text=$(printf 'out=$(check_governance %s); rc=$?\nprintf "%%s\\n" "$out"\necho "after rc=$rc"\nexit $rc\n' \
        "$*" | (cd "$REPO" && python3 -B -m tools.gm.governance text -))
    case $e in
        all) printf '%s\n' "$text" | on "$n" root --env "CHECK_GOVERNANCE=$GOV" \
                 --env "CHECK_SINCE=$SINCE" ;;
        nosince) printf '%s\n' "$text" | on "$n" root --env "CHECK_GOVERNANCE=$GOV" ;;
        *) printf '%s\n' "$text" | on "$n" root ;;
    esac
}
# rule <node> <env> <call...>: "<exit> <first line>" of a set run.
rule() {
    out=$(set_run "$@" 2>&1); rc=$?
    printf '%s %s' "$rc" "$(printf '%s\n' "$out" | head -n 1)"
    printf '%s\n' "$out" > "$tmp/last.out"
}
# rc_of <node> <env> <call...>: the exit of a set run, its output kept in last.out.
rc_of() { r=$(rule "$@"); printf '%s' "${r%% *}"; }

# --- deployment ---------------------------------------------------------------
info "fixture-instances (with bi) on playground $PG"
$GMCTL fit "$SCN" --playground "$PG" "$@" || { fail "fit"; exit 1; }
pass "fit"
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 10) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" >/dev/null \
    || { fail "render"; exit 1; }
pass "render --handover $HANDOVER"
deployed=yes
$GMCTL deploy "$SCN" --playground "$PG" || { fail "deploy"; exit 1; }
pass "deploy"
$GMCTL load-data "$SCN" --playground "$PG" || { fail "load-data"; exit 1; }
pass "load-data"
set +e

GOV=$(cd "$REPO" && python3 -B -m tools.gm.governance env "$SCN")
SINCE=$(date -u -d '1 minute ago' +%Y-%m-%dT%H:%M:%SZ)
on db postgres <<'EOF' >/dev/null
psql -X -q -v ON_ERROR_STOP=1 -d shop -c "INSERT INTO mail_outbox (customer_id, payload, sent_at) VALUES (2, '{\"email\": \"customer2@example.org\", \"name\": \"Customer 2\", \"order_id\": 21}', now())"
EOF
same "setup: one compliant outbox row sent now" 0 "$?"

# --- the baseline ---------------------------------------------------------------
out=$(sh "$REPO/tools/tests/check-governance.sh" "$SCN" "$PG" "$SINCE" 2>&1); rc=$?
printf '%s\n' "$out" | sed 's/^/      /'
same "baseline: check-governance.sh exits 0" 0 "$rc"
for n in db reporting; do
    for r in G1 G2 G3 G4; do
        same "baseline: $r holds, run on $n" "0 $r holds on 2 database nodes, 4 databases" \
            "$(rule "$n" all "$r")"
    done
done
same "baseline: G3 holds on bi" "0 G3 holds on transformer bi, 1 job(s) joining databases" \
    "$(rule bi all G3)"
same "baseline: the four rules at once, first line" \
    "0 G1, G2, G3, G4 hold on 2 database nodes, 4 databases" "$(rule reporting all G1 G2 G3 G4)"
same "the set returns to its caller" "after rc=0" "$(tail -n 1 "$tmp/last.out")"

# --- each breach planted, judged and reverted --------------------------------------
# field <file> <key>: the `-- <key>: <value>` line's value.
field() { sed -n "s/^-- $2: //p" "$1" | head -n 1; }
plant() {   # plant <file> <true|false>: the breach planted (false) or reverted (true)
    { printf 'psql -X -q -v ON_ERROR_STOP=1 -v revert=%s -d %s <<'"'"'GM_BREACH'"'"'\n' \
          "$2" "$(field "$1" database)"
      cat "$1"
      printf 'GM_BREACH\n'; } | on "$(field "$1" node)" postgres >/dev/null 2>"$tmp/plant.err"
}
for f in "$FIXTURE"/breaches/*.sql; do
    b=$(basename "$f" .sql)
    info "$b: $(field "$f" expect)"
    if ! plant "$f" false; then
        fail "$b: planted ($(cat "$tmp/plant.err" | tail -n 1))"
        continue
    fi
    for e in $(field "$f" expect); do
        r=${e%%=*} want=${e#*=}
        got=$(rc_of db all "$r")
        same "$b: $r reads $want (run on db)" "$want" "$got"
        if [ "$want" = 1 ]; then
            first=$(field "$f" first)
            line=$(rule reporting all "$r")
            case $line in
                "1 $r: $first"*) pass "$b: $r reads 1 on reporting too: ${line#1 }" ;;
                *) fail "$b: $r on reporting (expected [1 $r: $first...], got [$line])" ;;
            esac
            sed 's/^/      /' "$tmp/last.out"
        fi
    done
    if plant "$f" true; then
        same "$b: reverted, every rule holds" "0" \
            "$(rc_of db all G1 G2 G3 G4)"
    else
        fail "$b: reverted ($(tail -n 1 "$tmp/plant.err"))"
    fi
done

info "g3-transformer-source on bi"
printf 'set -- plant\n' | cat - "$FIXTURE/breaches/g3-transformer-source.sh" | on bi root >/dev/null
same "g3-transformer-source: planted" 0 "$?"
line=$(rule bi all G3)
case $line in
    "1 G3: bi jobs.yaml job sync-nightly connection source (shop_wide) as shop_app reaches"*)
        pass "g3-transformer-source: G3 reads 1 on bi: ${line#1 }" ;;
    *) fail "g3-transformer-source: G3 on bi (got [$line])" ;;
esac
sed 's/^/      /' "$tmp/last.out"
same "g3-transformer-source: G3 still holds on the database nodes' catalog paths" 0 \
    "$(rc_of db all G3)"
printf 'set -- revert\n' | cat - "$FIXTURE/breaches/g3-transformer-source.sh" | on bi root >/dev/null
same "g3-transformer-source: reverted" 0 "$?"
same "g3-transformer-source: reverted, G3 holds on bi" 0 "$(rc_of bi all G3)"

# --- cannot judge, too soon ---------------------------------------------------------
cannot() {   # cannot <description> <node> <env> <call...>
    d=$1; shift
    line=$(rule "$@")
    case $line in
        "2 governance: cannot judge: "*) pass "$d: ${line#2 }" ;;
        *) fail "$d (expected [2 governance: cannot judge: ...], got [$line])" ;;
    esac
}
cannot "an unknown rule" db all G1 G5
cannot "a rule named twice" db all G1 G1
cannot "no rule" db all
cannot "no CHECK_GOVERNANCE" db none G1
cannot "G4 without CHECK_SINCE" db nosince G4
cannot "G1 on a transformer node" bi all G1
same "the set returns to its caller when it cannot judge" "after rc=2" \
    "$(tail -n 1 "$tmp/last.out")"
on reporting postgres <<'EOF' >/dev/null
psql -X -q -v ON_ERROR_STOP=1 -d reporting -c "DROP FUNCTION gm_check.user_mapping_roles()"
EOF
cannot "G3 with the mapping-roles function gone" db all G3
(cd "$REPO" && python3 -B -c 'from tools.gm import inject; print(inject.function_sql())') \
    | sed '1s/^/psql -X -q -v ON_ERROR_STOP=1 -d reporting <<'"'"'GM_SQL'"'"'\n/; $s/$/\nGM_SQL/' \
    | on reporting postgres >/dev/null
same "the mapping-roles function restored, G3 holds" 0 "$(rc_of db all G3)"
on reporting postgres <<'EOF' >/dev/null
psql -X -q -v ON_ERROR_STOP=1 -d reporting -c "DROP POLICY gm_check_read ON cron.job"
EOF
cannot "G3 with gm_check_read gone from cron.job" reporting all G3
(cd "$REPO" && python3 -B -c 'from tools.gm import inject; print(inject.policy_sql())') \
    | sed '1s/^/psql -X -q -v ON_ERROR_STOP=1 -d reporting <<'"'"'GM_SQL'"'"'\n/; $s/$/\nGM_SQL/' \
    | on reporting postgres >/dev/null
same "the read policy restored, G3 holds" 0 "$(rc_of db all G3)"
SINCE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
line=$(rule db all G4)
case $line in
    "3 G4: nothing to judge yet: no row in db/shop/mail_outbox since $SINCE") pass "G4 reads 3 with no row since $SINCE" ;;
    *) fail "G4 with no row since now (got [$line])" ;;
esac
same "G1 and G4 at once, G4 with no row: 3" 3 "$(rc_of db all G1 G4)"

echo
echo "smoke-governance: $passes passed, $failures failed"
[ "$failures" -eq 0 ]
