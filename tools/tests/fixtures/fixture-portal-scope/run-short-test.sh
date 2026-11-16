#!/bin/sh
# Short test of the portal-scope fixture (v0.5 build plan chunk 25; master
# spec 17.2, 17.3 s5; capture W5 items 0 and 4, W5-d, of
# specs/versions/v0.5/wave-log.md; spec D423, D427, D432, D463):
# security-policy-ownership-end-dropped, a state fault, its instance s5
# committed. On one host, under 30 minutes with the deployment; no
# scheduler node, so no aging and no shift (T0 the host's time).
#
#   compose --check -> fit (2 CPU / 4G / 8G) -> render -> the stack file:
#   portal_api's password and portal_desk on portal-api alone -> deploy -> load-data (the
#   core, the lab and the portal derived after them on records; gm_check's
#   read policies at step (2c); the coherence check clean), then:
#   - the sale, as the practice software and purpose 15 would (W5 item 4,
#     after load-data and before inject): a horse whose owner has an active
#     account sold two hours back to another active owner, in clinic and in
#     the portal's copy, as postgres;
#   - before planting: as the seller (POST /login with the planted password,
#     portal_password(account, load_epoch), then GET /animals on
#     portal-api), the horse is not listed; as the buyer, it is;
#   - inject (s5 planted on records, after the coherence check);
#   - present: as the seller, GET /animals lists the horse they sold; the
#     buyer still sees it; gmctl check reads s5 present;
#   - the fix, as the GM applies the players' (ALTER POLICY with the owner
#     branch's o.until_at IS NULL restored, as vet-portal's schema writes
#     it);
#   - fixed: as the seller, the horse is no longer listed, and the buyer
#     still sees it; gmctl check reads s5 fixed; with gm_check_read dropped,
#     the check refuses to judge (exit 2);
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-portal-scope/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=portal-scope-short
INST=s5
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1 127.0.0.1:5000/dbagm/postgres:0.5.1"
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-portal-scope-short.XXXXXX")
SCN=$tmp/fixture-portal-scope
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
dbsql() { docker exec -u postgres "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -d "$1" -c "$2"; }
# HTTP from portal-api's own task to its hostname (as the portal fixture's
# test): JSON requests on standard input, one a line ({"method", "path",
# "cookie", "body"}), one JSON line each out ({"path", "status", "body"}).
PROBE_PY='
import http.client, json, sys
for line in sys.stdin:
    q = json.loads(line)
    headers = {"Content-Type": "application/json"}
    if q.get("cookie"):
        headers["Cookie"] = "portal_session=" + q["cookie"]
    try:
        c = http.client.HTTPConnection("portal-api", 8000, timeout=20)
        c.request(q["method"], q["path"], body=json.dumps(q["body"]) if "body" in q else None, headers=headers)
        r = c.getresponse()
        status, body = r.status, r.read().decode("utf-8", "replace")
        c.close()
    except OSError as exc:
        status, body = "error", type(exc).__name__ + ": " + str(exc)
    print(json.dumps({"path": q["path"], "status": status, "body": body}))
'
probe() { docker exec -i "$(ctr portal-api)" python3 -I -c "$PROBE_PY"; }
# Account n's planted password (vet-portal docs/gm.md, "The key, the
# passwords, the links"; D406): the HMAC-SHA256 of n under the key
# sha256('vet-portal ' || load_epoch), both in hex.
secret() { python3 -c 'import hashlib, hmac, sys
key = hashlib.sha256(("vet-portal " + sys.argv[1]).encode()).hexdigest()
print(hmac.new(key.encode(), sys.argv[2].encode(), hashlib.sha256).hexdigest())' "$EPOCH" "$1"; }
# `lists <account> <animal>`: as the account's owner, logged in through
# portal-api, "yes" when GET /animals lists the animal, "no" when it does
# not, else what went wrong.
lists() {
    email=$(dbsql portal "SELECT email FROM portal_accounts WHERE id = $1")
    login=$(printf '{"method": "POST", "path": "/login", "body": {"email": "%s", "password": "%s"}}\n' "$email" "$(secret "$1")" | probe)
    tok=$(python3 -c 'import json, sys; q = json.loads(sys.argv[1]); print(json.loads(q["body"]).get("token", "") if q["status"] == 201 else "")' "$login")
    [ -n "$tok" ] || { echo "login $login"; return 0; }
    printf '{"method": "GET", "path": "/animals", "cookie": "%s"}\n' "$tok" | probe \
        | python3 -c 'import json, sys
q = json.loads(sys.stdin.readline())
if q["status"] != 200:
    print("GET /animals", q["status"], q["body"][:160])
else:
    print("yes" if int(sys.argv[1]) in [a["animal_id"] for a in json.loads(q["body"])] else "no")' "$2"
}
# The fault's sealed check, as the GM runs it: prints "<exit> <its line>".
fcheck() {
    set +e
    out=$($GMCTL check "$SCN" --playground "$PG" --instance "$INST" 2>&1)
    rc=$?
    set -e
    printf '%s %s\n' "$rc" "$(printf '%s' "$out" | grep "^$INST " | head -n 1)"
}

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/portal-api/ as compose writes it"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G >/dev/null; then
    pass "fit: the three nodes fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
$GMCTL render "$SCN" --playground "$PG" >/dev/null
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
same "stack: portal_api's password and portal_desk on portal-api alone" "bastion - records - portal-api http_portal_desk role_portal_api_password" \
    "$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
out = []
for node in ("bastion", "records", "portal-api"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    out.append(node + " " + (" ".join(names) or "-"))
print(" ".join(out))
EOF
)"

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

# --- load-data -----------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
E0=$(date -u +%Y-%m-%dT%H:%MZ)
if $GMCTL load-data "$SCN" --playground "$PG" >/dev/null; then
    pass "load-data: the core, the lab and the portal derived after them on records; the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
E1=$(date -u +%Y-%m-%dT%H:%MZ)
same "load-data (2c): gm_check_read on the portal's ten tables" "10" \
    "$(dbsql portal "SELECT count(*) FROM pg_policies WHERE policyname = 'gm_check_read' AND tablename LIKE 'portal\_%'")"
same "load-data: portal_animals_scope as vet-portal's schema writes it (the owner branch reads until_at IS NULL)" "2" \
    "$(dbsql portal "SELECT (length(pg_get_expr(polqual, polrelid)) - length(replace(pg_get_expr(polqual, polrelid), 'until_at IS NULL', ''))) / length('until_at IS NULL') FROM pg_policy WHERE polname = 'portal_animals_scope'")"

# --- the sale, two hours back ----------------------------------------------------
# A horse alive, its current owner with an active account and no keeping of it;
# a buyer, another owner with an active account and no row on the horse.
pick=$(dbsql portal "
WITH act AS (SELECT id, owner_id FROM portal_accounts WHERE status = 'active')
SELECT o.animal_id || ' ' || s.id || ' ' || o.owner_id || ' ' ||
       (SELECT b.id || ' ' || b.owner_id FROM act b WHERE b.owner_id <> o.owner_id
           AND NOT EXISTS (SELECT 1 FROM portal_ownerships x WHERE x.animal_id = o.animal_id AND x.owner_id = b.owner_id)
         ORDER BY b.owner_id LIMIT 1)
  FROM portal_ownerships o JOIN portal_animals n ON n.animal_id = o.animal_id AND n.species = 'horse' AND n.status = 'alive'
  JOIN act s ON s.owner_id = o.owner_id
 WHERE o.role = 'owner' AND o.until_at IS NULL AND o.from_at < now() - interval '30 days'
   AND NOT EXISTS (SELECT 1 FROM portal_ownerships k WHERE k.animal_id = o.animal_id AND k.role = 'keeper')
 ORDER BY o.animal_id LIMIT 1")
set -- $pick
HORSE=${1:-} SELLER_ACC=${2:-} SELLER=${3:-} BUYER_ACC=${4:-} BUYER=${5:-}
[ -n "$BUYER" ] || { fail "no horse with an active owner and a buyer found: [$pick]"; exit 1; }
info "the sale: horse $HORSE, owner $SELLER (account $SELLER_ACC) to owner $BUYER (account $BUYER_ACC), two hours back"
cat > "$tmp/sale-clinic.sql" <<EOF
BEGIN;
SELECT now() - interval '2 hours' AS sold_at \\gset
UPDATE ownerships SET until_at = :'sold_at' WHERE animal_id = $HORSE AND role = 'owner' AND until_at IS NULL;
INSERT INTO ownerships (animal_id, owner_id, role, from_at) VALUES ($HORSE, $BUYER, 'owner', :'sold_at');
COMMIT;
SELECT :'sold_at';
EOF
SOLD_AT=$(docker exec -i -u postgres "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -d clinic < "$tmp/sale-clinic.sql" | tail -n 1)
[ -n "$SOLD_AT" ] && pass "the sale in clinic: owner $SELLER's ownership ended at $SOLD_AT, owner $BUYER's opened" \
    || { fail "the sale in clinic not written"; exit 1; }
cat > "$tmp/sale-portal.sql" <<EOF
BEGIN;
UPDATE portal_ownerships SET until_at = '$SOLD_AT', synced_at = now()
 WHERE animal_id = $HORSE AND role = 'owner' AND until_at IS NULL;
INSERT INTO portal_ownerships (animal_id, owner_id, role, from_at, synced_at) VALUES ($HORSE, $BUYER, 'owner', '$SOLD_AT', now());
COMMIT;
EOF
docker exec -i -u postgres "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -d portal < "$tmp/sale-portal.sql" >/dev/null \
    && pass "the sale's copy in portal, as purpose 15 would" || { fail "the sale's copy in portal not written"; exit 1; }

# The load's epoch: the minute load-data started (E0, or the next one), the
# one whose password for the seller's account verifies its bcrypt hash.
EPOCH=
for e in "$E0" "$E1" $(python3 -c 'import datetime, sys
a = datetime.datetime.strptime(sys.argv[1], "%Y-%m-%dT%H:%MZ")
for i in range(1, 30): print((a + datetime.timedelta(minutes=i)).strftime("%Y-%m-%dT%H:%MZ"))' "$E0"); do
    EPOCH=$e
    [ "$(dbsql portal "SELECT crypt('$(secret "$SELLER_ACC")', password_hash) = password_hash FROM portal_accounts WHERE id = $SELLER_ACC")" = t ] && break
    EPOCH=
done
[ -n "$EPOCH" ] && pass "the planted passwords: load_epoch $EPOCH (account $SELLER_ACC's verifies its hash)" \
    || { fail "no load_epoch from $E0 verifies account $SELLER_ACC's password"; exit 1; }

# --- before planting -------------------------------------------------------------
same "before planting: as the seller, GET /animals omits horse $HORSE; as the buyer, it lists it" "no yes" \
    "$(lists "$SELLER_ACC" "$HORSE") $(lists "$BUYER_ACC" "$HORSE")"

# --- inject: s5 planted ----------------------------------------------------------------
info "gmctl inject"
t=$(date +%s)
if $GMCTL inject "$SCN" --playground "$PG" >/dev/null; then
    pass "inject: s5 planted on records ($(( $(date +%s) - t )) s), two hours after the sale"
else
    fail "inject"
    exit 1
fi
same "planted: portal_animals_scope's owner branch without until_at IS NULL (the keeper's keeps it)" "1" \
    "$(dbsql portal "SELECT (length(pg_get_expr(polqual, polrelid)) - length(replace(pg_get_expr(polqual, polrelid), 'until_at IS NULL', ''))) / length('until_at IS NULL') FROM pg_policy WHERE polname = 'portal_animals_scope'")"

# --- present ----------------------------------------------------------------------------
same "present: as the former owner, GET /animals on portal-api returns horse $HORSE, and the buyer still sees it" "yes yes" \
    "$(lists "$SELLER_ACC" "$HORSE") $(lists "$BUYER_ACC" "$HORSE")"
r=$(fcheck)
case $r in "1 "*) pass "gmctl check: $INST present (${r#* })" ;; *) fail "gmctl check after planting: $r" ;; esac

# --- the fix, as the GM applies the players' --------------------------------------------
cat > "$tmp/fix.sql" <<'EOF'
ALTER POLICY portal_animals_scope ON portal_animals
    USING (EXISTS (SELECT 1 FROM portal_ownerships o
                    WHERE o.animal_id = portal_animals.animal_id AND o.role = 'owner'
                      AND o.until_at IS NULL
                      AND o.owner_id = NULLIF(current_setting('portal.owner_id', true), '')::integer)
           OR EXISTS (SELECT 1 FROM portal_ownerships k
                       WHERE k.animal_id = portal_animals.animal_id AND k.role = 'keeper'
                         AND k.until_at IS NULL
                         AND k.owner_id = NULLIF(current_setting('portal.owner_id', true), '')::integer
                         AND portal_keeper_granted(k.animal_id, k.owner_id)));
EOF
docker exec -i -u postgres "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -d portal < "$tmp/fix.sql" >/dev/null \
    && pass "the fix: the owner branch's o.until_at IS NULL restored (ALTER POLICY)" || fail "the fix not applied"

# --- fixed -------------------------------------------------------------------------------
same "fixed: as the former owner, GET /animals no longer returns horse $HORSE, and the buyer still sees it" "no yes" \
    "$(lists "$SELLER_ACC" "$HORSE") $(lists "$BUYER_ACC" "$HORSE")"
r=$(fcheck)
case $r in "0 "*) pass "gmctl check: $INST fixed (${r#* })" ;; *) fail "gmctl check after the fix: $r" ;; esac
dbsql portal "DROP POLICY gm_check_read ON portal_animals" >/dev/null
r=$(fcheck)
case $r in "2 "*) pass "gm_check_read dropped on portal_animals: the check cannot judge (exit 2)" ;;
    *) fail "gm_check_read dropped: $r" ;; esac

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
