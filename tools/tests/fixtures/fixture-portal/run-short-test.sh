#!/bin/sh
# Short test of the portal fixture (v0.5 build plan, chunk 16b; spec D403,
# D404, D405, D406, D369; master spec 9.7; capture W3 items 0 and 5, W3-e,
# W3-f): vet-core's record, vet-lab's laboratory and vet-portal's owners'
# portal loaded by gmctl load-data from the domains (the keys streamed ahead
# of each part's load and of its partners' data.sql; the portal's derivation
# after the core's and the lab's loads, as composition.yaml sanctions it;
# vet-portal's data/cron.sql on records; the coherence check after), the
# portal's API, portal-api, as portal_api over TLS, and the owners' traffic
# on the partners' three nodes. On one host, under 30 minutes.
#
# On a copy of tools/tests/fixtures/fixture-portal (bastion 0.5.0, records,
# lab and partners-db: postgres 0.5.0, portal-api and partners-api: api
# 0.1.0, interfaces and partners-backend: scheduler 0.3.0, the owners'
# traffic at intensity 10; left out: vet-core's pms and clinic-api, vet-lab's
# lis, lab-api and two stubs' fragments, vet-portal's desk stream):
#   gmctl compose --check -> fit (2 CPU / 4G / 8G) -> render (hand-over 20:00
#   local, so T0 falls between 11:00 and 12:00, the owners' day) -> deploy ->
#   load-data, then:
#   - the stack file: each credential and role password on its node only;
#   - load-data: the portal's tables, its roles, no key function left, the
#     owners' key and logins on partners-db, the sessions' purge in cron.job,
#     the lab's stubs' state; the coherence check clean (load-data fails
#     otherwise);
#   - owner scope, through portal-api as each case's owner (its planted
#     password, from owners.settings' key): a planted owner, a former owner
#     (the seller), the buyer, a keeper granted, a keeper withdrawn, a keeper
#     never granted: GET /animals and the animal's documents as the rules
#     say; another owner's document 404; without a cookie 401;
#   - accounts: an invitation's planted token activates its account once
#     (again 401), its new password logs in; the fifth wrong password 423,
#     then the right one 423; a past session's token refused (401); the desk
#     201 with portal_desk, 401 without; portal_api's sessions over TLS;
#   - inject -> start-load (T0): the owners' traffic for six minutes, every
#     call in owners.visits, each document opened a portal_views row, each
#     login a session, each listing the animals the policy shows;
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-portal/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=portal-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.5.0 127.0.0.1:5000/dbagm/api:0.1.0 127.0.0.1:5000/dbagm/postgres:0.5.0"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.3.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
WATCH=360                                # seconds of the owners' traffic after T0
started=$(date +%s)

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}
tally() {   # tally <verdict lines>: PASS and FAIL lines printed and counted
    printf '%s\n' "$1"
    passes=$((passes + $(printf '%s\n' "$1" | grep -c '^PASS' || true)))
    failures=$((failures + $(printf '%s\n' "$1" | grep -c '^FAIL' || true)))
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-portal-short.XXXXXX")
SCN=$tmp/fixture-portal
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
blog() { docker exec "$(ctr partners-backend)" cat "$SCHEDLOG" 2>/dev/null || true; }
bstatus() { docker exec "$(ctr partners-backend)" cat /run/scheduler/status 2>/dev/null || true; }

# HTTP from portal-api's own task to its hostname: `probe` reads JSON requests
# on its standard input, one a line ({"method", "path", "cookie", "cred",
# "body"}: cookie a session token or null, cred a secret's name or null), and
# prints one JSON line each: {"path", "status", "ms", "cookie", "body"}.
PROBE_PY='
import http.client, json, sys, time
for line in sys.stdin:
    q = json.loads(line)
    headers = {"Content-Type": "application/json"}
    if q.get("cred"):
        headers["Authorization"] = "Bearer " + open("/opt/gm/secrets/http_" + q["cred"]).read().strip()
    if q.get("cookie"):
        headers["Cookie"] = "portal_session=" + q["cookie"]
    t = time.monotonic()
    try:
        c = http.client.HTTPConnection("portal-api", 8000, timeout=20)
        c.request(q["method"], q["path"], body=json.dumps(q["body"]) if "body" in q else None, headers=headers)
        r = c.getresponse()
        status, cookie, body = r.status, r.getheader("set-cookie"), r.read().decode("utf-8", "replace")
        c.close()
    except OSError as exc:
        status, cookie, body = "error", None, type(exc).__name__ + ": " + str(exc)
    print(json.dumps({"path": q["path"], "status": status, "ms": round((time.monotonic() - t) * 1000),
                      "cookie": cookie, "body": body}))
'
probe() { docker exec -i "$(ctr portal-api)" python3 -I -c "$PROBE_PY"; }
# The planted secrets (D406): `secret <message>` the HMAC-SHA256 of it under the owners' key, in hex.
secret() { python3 -c 'import hashlib, hmac, sys; print(hmac.new(sys.argv[1].encode(), sys.argv[2].encode(), hashlib.sha256).hexdigest())' "$KEY" "$1"; }

# --- composition -------------------------------------------------------------
if $GMCTL compose --check "$SCN" >/dev/null; then
    pass "compose --check: nodes/portal-api/, nodes/interfaces/, nodes/partners-api/ and nodes/partners-backend/ as compose writes them"
else
    fail "compose --check: nodes/ differ from what compose writes (rerun gmctl compose)"
fi

# --- local implementation ---------------------------------------------------
info "gmctl fit (the laptop playground: 2 CPU / 4G / 8G)"
if $GMCTL fit "$SCN" --playground "$PG" --cpu 2 --memory 4G --disk 8G; then
    pass "fit: the eight nodes and their reservations fit 2 CPU / 4G / 8G"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
# Hand-over 8 to 9 hours ahead at 20:00 local: T0 between 11:00 and 12:00 local.
HANDOVER=$(date -u -d "@$(( ($(date +%s) / 3600 + 9) * 3600 ))" +%Y-%m-%dT%H:00Z)
$GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER"
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }

st=$(python3 - "$LDIR/stack.yml" "$GAME" <<'EOF'
import sys, yaml
stack, gid = yaml.safe_load(open(sys.argv[1])), sys.argv[2]
for node in ("bastion", "records", "lab", "interfaces", "portal-api", "partners-api", "partners-backend",
             "partners-db"):
    names = sorted(s["source"][len(gid) + 1:] for s in stack["services"][node].get("secrets", [])
                   if s["source"][len(gid) + 1:].startswith(("role_", "http_")))
    print(node, " ".join(names) or "-")
EOF
)
line() { printf '%s\n' "$st" | sed -n "$1p"; }
same "stack: none on the bastion, records, lab, interfaces" "bastion - records - lab - interfaces -" \
    "$(line 1) $(line 2) $(line 3) $(line 4)"
same "stack: portal_desk and portal_api's password on portal-api" \
    "portal-api http_portal_desk role_portal_api_password" "$(line 5)"
same "stack: partners_backend and owners' password on partners-api" \
    "partners-api http_partners_backend role_owners_password" "$(line 6)"
same "stack: partners_backend on partners-backend" "partners-backend http_partners_backend" "$(line 7)"
same "stack: none on partners-db" "partners-db -" "$(line 8)"

# --- deployment ---------------------------------------------------------------
info "gmctl deploy"
deployed=yes
t=$(date +%s)
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: the eight nodes healthy ($(( $(date +%s) - t )) s)"
else
    fail "deploy"
    exit 1
fi

# --- load-data ---------------------------------------------------------------
info "gmctl load-data"
t=$(date +%s)
if $GMCTL load-data "$SCN" --playground "$PG"; then
    pass "load-data: the core, the lab, the portal derived after them, the owners' state; the coherence check clean ($(( $(date +%s) - t )) s)"
else
    fail "load-data"
    exit 1
fi
info "portal rows: $(dbsql records portal "SELECT string_agg(t || ' ' || n, ', ' ORDER BY t) FROM (
  SELECT 'accounts' t, count(*) n FROM portal_accounts UNION ALL SELECT 'consent_events', count(*) FROM portal_consent_events
  UNION ALL SELECT 'sessions', count(*) FROM portal_sessions UNION ALL SELECT 'animals', count(*) FROM portal_animals
  UNION ALL SELECT 'ownerships', count(*) FROM portal_ownerships UNION ALL SELECT 'documents', count(*) FROM portal_documents
  UNION ALL SELECT 'views', count(*) FROM portal_views UNION ALL SELECT 'outbox', count(*) FROM portal_outbox) x")"
info "sizes: clinic $(dbsql records clinic "SELECT pg_size_pretty(pg_database_size('clinic'))"), portal $(dbsql records portal "SELECT pg_size_pretty(pg_database_size('portal'))"), lab $(dbsql lab lab "SELECT pg_size_pretty(pg_database_size('lab'))")"
same "load-data: the portal's ten tables under forced row-level security, owned by portal" "10 10 portal" \
    "$(dbsql records portal "SELECT count(*) FILTER (WHERE relrowsecurity) || ' ' || count(*) FILTER (WHERE relforcerowsecurity) || ' '
       || string_agg(DISTINCT pg_get_userbyid(relowner), ',') FROM pg_class WHERE relname LIKE 'portal\_%' AND relkind = 'r'")"
same "load-data: portal_api and portal_housekeeping have SCRAM passwords, portal none" \
    "portal:f portal_api:t portal_housekeeping:t" \
    "$(dbsql records postgres "SELECT string_agg(rolname || ':' || CASE WHEN rolpassword LIKE 'SCRAM-SHA-256\$%' THEN 't' ELSE 'f' END, ' ' ORDER BY rolname)
                               FROM pg_authid WHERE rolname LIKE 'portal%'")"
same "load-data: no key function left in the catalog" "0" \
    "$(dbsql records portal "SELECT count(*) FROM pg_proc WHERE proname LIKE 'portal\_%' AND pronamespace <> 'public'::regnamespace")"
same "load-data: cron.job holds the sessions' purge, in portal, as portal_housekeeping" \
    "portal.sessions.purge portal portal_housekeeping 30 3 * * *" \
    "$(dbsql records jobs "SELECT string_agg(jobname || ' ' || database || ' ' || username || ' ' || schedule, '|') FROM cron.job WHERE active")"
KEY=$(dbsql partners-db partners "SELECT value FROM owners.settings WHERE name = 'password_key'")
same "load-data: the owners' key is the load's (portal_hmac of account 2 verifies its bcrypt hash)" "t" \
    "$(dbsql records portal "SELECT crypt('$(secret 2)', password_hash) = password_hash FROM portal_accounts WHERE id = 2")"
same "load-data: the owners' logins are the portal's open accounts" \
    "$(dbsql records portal "SELECT count(*) || ' ' || count(*) FILTER (WHERE status = 'active') FROM portal_accounts WHERE status <> 'closed'")" \
    "$(dbsql partners-db partners "SELECT count(*) || ' ' || count(*) FILTER (WHERE status = 'active') FROM owners.accounts")"
same "the roles on partners own their schemas only" "owners:owners practices:practices xlab:xlab" \
    "$(dbsql partners-db partners "SELECT string_agg(nspname || ':' || pg_get_userbyid(nspowner), ' ' ORDER BY nspname)
                                   FROM pg_namespace WHERE nspname IN ('xlab', 'practices', 'owners')")"
same "the external lab's stub holds the lab's open send-outs" \
    "$(dbsql lab lab "SELECT count(*) FROM lab_send_outs WHERE status IN ('sent', 'accepted')")" \
    "$(dbsql partners-db partners "SELECT count(*) FROM xlab.orders WHERE answered_at IS NULL")"

# --- owner scope ---------------------------------------------------------------
# The cases, read as postgres (no row-level security): a horse sold with
# records on both sides of the sale (its seller and buyer, both active), a
# granted, a withdrawn and a never-granted current keeper of a horse with
# documents, a planted owner with animals; for each the animals and documents
# the rules give.
cases=$(dbsql records portal "
WITH act AS (SELECT owner_id FROM portal_accounts WHERE status = 'active'),
sale AS (SELECT o.animal_id, o.owner_id AS seller, b.owner_id AS buyer, b.from_at
           FROM portal_ownerships o JOIN portal_ownerships b ON b.animal_id = o.animal_id AND b.role = 'owner'
            AND b.until_at IS NULL AND b.from_at = o.until_at
          WHERE o.role = 'owner' AND o.until_at IS NOT NULL
            AND o.owner_id IN (SELECT * FROM act) AND b.owner_id IN (SELECT * FROM act)
            AND EXISTS (SELECT 1 FROM portal_documents d WHERE d.animal_id = o.animal_id AND d.record_at < b.from_at)
            AND EXISTS (SELECT 1 FROM portal_documents d WHERE d.animal_id = o.animal_id AND d.record_at >= b.from_at)
          ORDER BY o.animal_id LIMIT 1),
k AS (SELECT k.animal_id, k.owner_id AS keeper,
             (SELECT e.granted FROM portal_ownerships w JOIN portal_consent_events e ON e.owner_id = w.owner_id
                 AND e.purpose = 'keeper-access' AND e.animal_id = w.animal_id AND e.keeper_id = k.owner_id
               WHERE w.animal_id = k.animal_id AND w.role = 'owner' AND w.until_at IS NULL
               ORDER BY e.at DESC, e.id DESC LIMIT 1) AS g
        FROM portal_ownerships k WHERE k.role = 'keeper' AND k.until_at IS NULL AND k.owner_id IN (SELECT * FROM act)
         AND EXISTS (SELECT 1 FROM portal_documents d WHERE d.animal_id = k.animal_id)),
planted AS (SELECT o.owner_id, o.animal_id FROM portal_ownerships o
             WHERE o.role = 'owner' AND o.until_at IS NULL AND o.owner_id IN (SELECT * FROM act)
               AND o.owner_id > 901 AND EXISTS (SELECT 1 FROM portal_documents d WHERE d.animal_id = o.animal_id)
             ORDER BY o.owner_id LIMIT 1),
c AS (SELECT 'seller' who, seller asker, animal_id FROM sale UNION ALL SELECT 'buyer', buyer, animal_id FROM sale
      UNION ALL (SELECT 'keeper-granted', keeper, animal_id FROM k WHERE g ORDER BY animal_id LIMIT 1)
      UNION ALL (SELECT 'keeper-withdrawn', keeper, animal_id FROM k WHERE NOT g ORDER BY animal_id LIMIT 1)
      UNION ALL (SELECT 'keeper-never', keeper, animal_id FROM k WHERE g IS NULL ORDER BY animal_id LIMIT 1)
      UNION ALL SELECT 'owner', owner_id, animal_id FROM planted)
SELECT c.who, c.asker, (SELECT email FROM portal_accounts WHERE owner_id = c.asker), c.animal_id,
       CASE WHEN c.who IN ('seller', 'keeper-withdrawn', 'keeper-never') THEN 0 ELSE 1 END,
       CASE WHEN c.who IN ('seller', 'keeper-withdrawn', 'keeper-never') THEN 0
            ELSE (SELECT count(*) FROM portal_documents d WHERE d.animal_id = c.animal_id
                    AND d.record_at >= (SELECT from_at FROM portal_ownerships WHERE animal_id = c.animal_id
                                          AND role = 'owner' AND until_at IS NULL)) END,
       (SELECT count(*) FROM portal_documents d WHERE d.animal_id = c.animal_id)
  FROM c" | tr '|' ' ')
info "cases (who owner e-mail animal sees its-documents all-documents):"
printf '%s\n' "$cases" | sed 's/^/....    /'
same "six owner-scope cases found" "buyer keeper-granted keeper-never keeper-withdrawn owner seller" \
    "$(printf '%s\n' "$cases" | cut -d' ' -f1 | sort | tr '\n' ' ' | sed 's/ $//')"
OTHER_DOC=$(dbsql records portal "SELECT min(d.id) FROM portal_documents d WHERE d.animal_id NOT IN (SELECT animal_id FROM portal_ownerships WHERE owner_id IN ($(printf '%s\n' "$cases" | cut -d' ' -f2 | tr '\n' ',' | sed 's/,$//')))")
out=$tmp/scope.jsonl
: > "$out"
printf '%s\n' "$cases" | while read -r who asker email animal sees docs all; do
    login=$(printf '%s\n' "{\"method\": \"POST\", \"path\": \"/login\", \"body\": {\"email\": \"$email\", \"password\": \"$(secret "$asker")\"}}" | probe)
    tok=$(python3 -c 'import json, sys; q = json.loads(sys.argv[1]); print(json.loads(q["body"]).get("token", "") if q["status"] == 201 else "")' "$login")
    probe <<EOF | python3 -c 'import json, sys; print(json.dumps([sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]] + [json.loads(l) for l in sys.stdin]))' "$who" "$animal" "$sees" "$docs" >> "$out"
{"method": "GET", "path": "/animals", "cookie": "$tok"}
{"method": "GET", "path": "/animals/$animal/documents", "cookie": "$tok"}
{"method": "GET", "path": "/documents/$OTHER_DOC", "cookie": "$tok"}
{"method": "GET", "path": "/animals"}
EOF
done
tally "$(python3 - "$out" <<'EOF'
import json, sys
for line in open(sys.argv[1]):
    who, animal, sees, docs, lst, dl, other, nocookie = json.loads(line)
    animal, sees, docs = int(animal), sees == "1", int(docs)
    ids = [a["animal_id"] for a in json.loads(lst["body"])] if lst["status"] == 200 else None
    ok = ids is not None and (animal in ids) == sees
    print(("PASS" if ok else "FAIL") + f"  {who}: GET /animals {'lists' if sees else 'omits'} animal {animal}"
          + ("" if ok else f" ({lst['status']} {lst['body'][:160]})"))
    if sees:
        got = len(json.loads(dl["body"])) if dl["status"] == 200 else None
        ok = got == min(docs, 50)
        print(("PASS" if ok else "FAIL") + f"  {who}: its documents, {min(docs, 50)} from the ownership's start"
              + ("" if ok else f" ({dl['status']}, {got})"))
    else:
        print(("PASS" if dl["status"] == 404 else "FAIL") + f"  {who}: its documents 404 ({dl['status']})")
    print(("PASS" if other["status"] == 404 else "FAIL") + f"  {who}: another owner's document 404 ({other['status']})")
    print(("PASS" if nocookie["status"] == 401 else "FAIL") + f"  {who}: no cookie 401 ({nocookie['status']})")
EOF
)"

# --- accounts ---------------------------------------------------------------------
INV=$(dbsql partners-db partners "SELECT account_id FROM owners.accounts WHERE status = 'invited' AND link = 'invitation' ORDER BY account_id LIMIT 1")
INV_EMAIL=$(dbsql records portal "SELECT email FROM portal_accounts WHERE id = $INV")
LOCK=$(printf '%s\n' "$cases" | awk '$1 == "owner" {print $2 " " $3}')
LOCK_ID=${LOCK%% *}; LOCK_EMAIL=${LOCK#* }
OLD=$(dbsql records portal "SELECT account_id FROM portal_sessions WHERE ended_at IS NOT NULL AND id = (SELECT min(id) FROM portal_sessions s
        WHERE s.account_id = portal_sessions.account_id) ORDER BY account_id LIMIT 1")
info "witnesses: invited account $INV, the lock's $LOCK_ID, an ended first session's $OLD"
out=$tmp/accounts.jsonl
probe > "$out" <<EOF
{"method": "POST", "path": "/accounts/activate", "body": {"token": "$(secret "invitation:$INV")", "password": "chosen-password-$INV", "reminders": true}}
{"method": "POST", "path": "/accounts/activate", "body": {"token": "$(secret "invitation:$INV")", "password": "chosen-password-$INV", "reminders": true}}
{"method": "POST", "path": "/login", "body": {"email": "$INV_EMAIL", "password": "chosen-password-$INV"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "wrong-1"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "wrong-2"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "wrong-3"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "wrong-4"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "wrong-5"}}
{"method": "POST", "path": "/login", "body": {"email": "$LOCK_EMAIL", "password": "$(secret "$LOCK_ID")"}}
{"method": "GET", "path": "/animals", "cookie": "$(secret "session-1:$OLD")"}
{"method": "POST", "path": "/desk/consents", "cred": "portal_desk", "body": {"owner_id": $INV, "purpose": "reminders", "granted": false}}
{"method": "POST", "path": "/desk/consents", "body": {"owner_id": $INV, "purpose": "reminders", "granted": false}}
EOF
desk=$(dbsql records portal "SELECT source || ' ' || granted FROM portal_consent_events WHERE owner_id = $INV ORDER BY id DESC LIMIT 1")
tally "$(python3 - "$out" "$desk" <<'EOF'
import json, sys
a = [json.loads(l) for l in open(sys.argv[1])]
st = [x["status"] for x in a]
def check(name, ok, detail):
    print(("PASS" if ok else "FAIL") + "  " + name + ("" if ok else f" ({detail})"))
check("activation with the invitation's planted token: 200 and the account", st[0] == 200, a[0]["body"][:160])
check("the same token again: 401", st[1] == 401, st[1])
check("the new password logs in: 201, the cookie portal_session set, HttpOnly",
      st[2] == 201 and (a[2]["cookie"] or "").startswith("portal_session=") and "httponly" in (a[2]["cookie"] or "").lower(),
      f"{st[2]} {a[2]['cookie']}")
check("four wrong passwords 401, the fifth 423", st[3:8] == [401, 401, 401, 401, 423], st[3:8])
check("then the right password 423 (locked 30 minutes)", st[8] == 423, st[8])
check("a past session's token refused: 401", st[9] == 401, st[9])
check("the desk with portal_desk: 201, the event source desk", st[10] == 201 and sys.argv[2] == "desk false",
      f"{st[10]} [{sys.argv[2]}]")
check("the desk without its credential: 401", st[11] == 401, st[11])
print(f"....  slowest answer {max(x['ms'] for x in a)} ms (the bcrypt logins among them)")
EOF
)"
same "portal_api's sessions arrive over TLS" "t" \
    "$(dbsql records postgres "SELECT coalesce(bool_and(s.ssl), false) FROM pg_stat_activity a JOIN pg_stat_ssl s USING (pid) WHERE a.usename = 'portal_api'")"

# --- T0: the owners' traffic --------------------------------------------------
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
i=0
while [ "$i" -lt 30 ]; do
    case $(bstatus) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(bstatus) in running\ *) pass "partners-backend running: $(bstatus)" ;; *) fail "partners-backend not running: [$(bstatus)]" ;; esac
info "local time at T0: $(dbsql records portal "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'Dy HH24:MI') FROM portal_settings")"
info "the owners' traffic for $WATCH s"
sleep "$WATCH"
visits=$(dbsql partners-db partners "SELECT count(*) || ' ' || count(DISTINCT account_id) FROM owners.visits WHERE at >= '$T0'")
info "owners.visits since T0 (calls, accounts): $visits; by call: $(dbsql partners-db partners "SELECT string_agg(call || ' ' || coalesce(status::text, '-') || ' ' || n, ', ' ORDER BY call, status)
  FROM (SELECT call, status, count(*) n FROM owners.visits WHERE at >= '$T0' GROUP BY 1, 2) x")"
[ "${visits%% *}" -gt 0 ] && pass "the owners' route recorded its calls in owners.visits" || fail "no call in owners.visits since T0"
# Each recorded call against portal: a document opened with its view, a
# login with its session, a listing with the animals the policy shows.
opened=$(dbsql partners-db partners "SELECT coalesce(string_agg(account_id || ':' || document_ids[1] || ':' || to_char(at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.US\"Z\"'), ' '), '')
  FROM owners.visits WHERE at >= '$T0' AND call = 'GET /documents/{id}' AND status = 200")
missing=0
for v in $opened; do
    acc=${v%%:*}; rest=${v#*:}; doc=${rest%%:*}; at=${rest#*:}
    n=$(dbsql records portal "SELECT count(*) FROM portal_views WHERE account_id = $acc AND document_id = $doc AND at BETWEEN '$at'::timestamptz - interval '5 seconds' AND '$at'::timestamptz + interval '5 seconds'")
    [ "$n" -ge 1 ] || missing=$((missing + 1))
done
info "documents opened since T0: $(echo $opened | wc -w)"
same "each document the route opened has its portal_views row" "0" "$missing"
logins=$(dbsql partners-db partners "SELECT count(*) FROM owners.visits WHERE at >= '$T0' AND call = 'POST /login' AND status = 201")
same "each login the route made has its session" "$logins" \
    "$(dbsql records portal "SELECT count(*) FROM portal_sessions WHERE created_at >= '$T0' AND account_id IN ($(dbsql partners-db partners "SELECT coalesce(string_agg(DISTINCT account_id::text, ','), '0') FROM owners.visits WHERE at >= '$T0'"))")"
listed=$(dbsql partners-db partners "SELECT coalesce(string_agg(account_id || ':' || coalesce(array_to_string(animal_ids, ','), ''), ' '), '') FROM owners.visits
  WHERE at >= '$T0' AND call = 'GET /animals' AND status = 200")
wrong=0
for v in $listed; do
    acc=${v%%:*}; got=${v#*:}
    want=$(printf "BEGIN;\nSELECT set_config('portal.owner_id', (SELECT owner_id::text FROM portal_accounts WHERE id = $acc), true) \\\\g /dev/null\nSET LOCAL ROLE portal_api;\nSELECT coalesce(string_agg(animal_id::text, ',' ORDER BY animal_id), '') FROM portal_animals;\nROLLBACK;\n" \
        | docker exec -i -u postgres "$(ctr records)" psql -XAtq -d portal)
    [ "$want" = "$got" ] || { wrong=$((wrong + 1)); info "account $acc listed [$got], the policy shows [$want]"; }
done
info "listings since T0: $(echo $listed | wc -w)"
same "each listing the route recorded is the animals the policy shows its owner" "0" "$wrong"
errs=$(blog | grep ' error ' || true)
same "partners-backend ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  partners-backend: /'
info "portal-api's request log: $(docker exec "$(ctr portal-api)" sh -c 'grep -c " request " /var/log/api/api.log' 2>/dev/null) requests, $(docker exec "$(ctr portal-api)" sh -c 'grep -c " error " /var/log/api/api.log || true' 2>/dev/null) errors"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
left=$(labelled)
same "teardown: nothing labelled with $GAME left" "" "$left"

info "$passes passed, $failures failed, $(( $(date +%s) - started )) s"
[ "$failures" -eq 0 ]
