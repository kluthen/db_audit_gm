#!/bin/sh
# Short test of the portal fixture (v0.5 build plan, chunks 16b and 21b; spec
# D403, D404, D405, D406, D369, D432; master spec 9.7; capture W3 items 0 and
# 5, W3-e, W3-f, W4 items 6 and 7): vet-core's record, vet-lab's laboratory
# and vet-portal's owners' portal loaded by gmctl load-data from the domains
# (the keys streamed ahead of each part's load and of its partners' data.sql;
# purposes 15's and 16's DDL at step (2b), gm_check's read policies at (2c);
# the portal's derivation after the core's and the lab's loads, as
# composition.yaml sanctions it; purpose 16's history planting the messaging
# stub's last 14 days; vet-portal's data/cron.sql on records; the coherence
# check after), the portal's API, portal-api, as portal_api over TLS, the
# integration engine running purposes 15 (vet-portal-release) and 16
# (vet-portal-messages), the messaging service's stub and the owners' traffic
# on the partners' three nodes. On one host, under 30 minutes.
#
# T0 is placed by the shift (whole hours) just before 09:00 local, for the
# reminders' queue (vet-portal-domain.md, "Testing"): the local minute is the
# host's UTC minute, so launch the test about SETUP seconds before a host
# minute :50 (reserve the host lock's window accordingly); start-load is held
# until 08:52 local, and T0 at 08:59 or later fails the run.
#
# On a copy of tools/tests/fixtures/fixture-portal (bastion 0.6.0, records,
# lab and partners-db: postgres 0.5.1, portal-api and partners-api: api
# 0.1.1, interfaces and partners-backend: scheduler 0.4.0, the owners'
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
#   - load-data: the purposes' roles, policies and watermarks, gm_check's
#     read policy on the portal's ten tables, the stub's planted messages;
#   - inject -> start-load (T0, 08:52-08:58 local), then, written by the test
#     as postgres (no pms, no lis): an owner and an animal registered, a sale,
#     a death, a consultation closed and another signed, a lab test
#     technically validated and another released, an amendment; a reminder
#     withdrawn by its link; the next send made a 503 (the stub's call
#     counter); an account closed. Within the jobs' windows: the copies, the
#     account invited and its invitation at the stub, activated with the
#     stub's token; only the signed, the released and the amendment
#     published, the former version superseded; the notice accepted with its
#     key; the 503 retried with the same key; the 09:00 reminders for the due
#     animals with consent, the withdrawn one excluded, sent within the hours;
#     the closure message at the stub;
#   - the owners' traffic: every call in owners.visits, each document opened a
#     portal_views row, each login a session, each listing the animals the
#     policy shows;
#   - the purposes' checks RL1-RL6 and MS1-MS6 as gmctl check runs them
#     (CHECK_SINCE T0): each judges (exit 0); then, gm_check_read dropped
#     on the portal's ten tables, every RL and MS check refuses (exit 2);
#   -> teardown, then nothing labelled with the game id is left.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, and the images built:
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/api:0.1.1 bricks/api
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.4.0 bricks/scheduler
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.1 bricks/postgres
# Run it under the host lock and the sleep inhibitor (build plan, workflow
# deltas).
# Usage: sh tools/tests/fixtures/fixture-portal/run-short-test.sh   (from anywhere)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
PG=portal-short
IMAGES="127.0.0.1:5000/dbagm/bastion:0.6.0 127.0.0.1:5000/dbagm/api:0.1.1 127.0.0.1:5000/dbagm/postgres:0.5.1"
IMAGES="$IMAGES 127.0.0.1:5000/dbagm/scheduler:0.4.0"
SCHEDLOG=/var/log/scheduler/scheduler.log
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
SETUP=600                                # seconds from the render to T0, about: deploy, load-data, the pre-T0 cases
DEADLINE=960                             # seconds after T0 the test waits at most for the purposes' outputs
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
# The shift that puts T0 (about SETUP seconds from now) in the 08:00 local
# hour, and the next hand-over moment that shift makes the designed 20:00.
set -- $(python3 - "$SETUP" <<'EOF2'
import datetime, sys
now = datetime.datetime.now(datetime.timezone.utc)
t0 = now + datetime.timedelta(seconds=int(sys.argv[1]))
shift = (8 - t0.hour + 11) % 24 - 11              # -11..12, render's compute_shift
moment = now.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=9)   # past the 8h aging floor
while (moment.hour + shift) % 24 != 20:
    moment += datetime.timedelta(hours=1)
print(moment.strftime("%Y-%m-%dT%H:00Z"), shift, (t0 + datetime.timedelta(hours=shift)).strftime("%H:%M"))
EOF2
)
HANDOVER=$1 SHIFT=$2 LOCAL_T0=$3
info "render --handover $HANDOVER, shift $SHIFT: T0 expected about $LOCAL_T0 local (held to 08:52)"
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
same "stack: none on the bastion, records, lab" "bastion - records - lab -" "$(line 1) $(line 2) $(line 3)"
same "stack: the purposes' four role passwords and messaging_customer on interfaces" \
    "interfaces http_messaging_customer role_lab_release_password role_portal_dispatch_password role_portal_sync_password role_vet_portal_sync_password" \
    "$(line 4)"
same "stack: portal_desk and portal_api's password on portal-api" \
    "portal-api http_portal_desk role_portal_api_password" "$(line 5)"
same "stack: messaging_customer, partners_backend, the stub's and owners' passwords on partners-api" \
    "partners-api http_messaging_customer http_partners_backend role_messaging_password role_owners_password" "$(line 6)"
same "stack: partners_backend and the stub's password on partners-backend" \
    "partners-backend http_partners_backend role_messaging_password" "$(line 7)"
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
same "load-data: portal_api, portal_housekeeping and the purposes' portal_dispatch and portal_sync have SCRAM passwords, portal none" \
    "portal:f portal_api:t portal_dispatch:t portal_housekeeping:t portal_sync:t" \
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
same "the roles on partners own their schemas only" "messaging:messaging owners:owners practices:practices xlab:xlab" \
    "$(dbsql partners-db partners "SELECT string_agg(nspname || ':' || pg_get_userbyid(nspowner), ' ' ORDER BY nspname)
                                   FROM pg_namespace WHERE nspname IN ('xlab', 'practices', 'owners', 'messaging')")"
same "load-data (2b): the purposes' roles, their policies <table>_sync (7) and <table>_dispatch (8), their watermarks at load_epoch" \
    "lab_release portal_dispatch portal_sync vet_portal_sync|7 8|vet-portal-messages:notices vet-portal-release:identity vet-portal-release:records vet-portal-release:results" \
    "$(dbsql lab postgres "SELECT string_agg(rolname, ' ') FROM pg_roles WHERE rolname = 'lab_release'") $(dbsql records postgres "SELECT string_agg(rolname, ' ' ORDER BY rolname) FROM pg_roles WHERE rolname IN ('vet_portal_sync', 'portal_sync', 'portal_dispatch')")|$(dbsql records portal "SELECT count(*) FILTER (WHERE policyname LIKE '%\_sync') || ' ' || count(*) FILTER (WHERE policyname LIKE '%\_dispatch') FROM pg_policies")|$(dbsql records portal "SELECT string_agg(purpose || ':' || name, ' ' ORDER BY purpose, name) FROM ops.watermarks")"
same "load-data (2c): gm_check_read on the portal's ten tables" "10" \
    "$(dbsql records portal "SELECT count(*) FROM pg_policies WHERE policyname = 'gm_check_read' AND tablename LIKE 'portal\_%'")"
same "purpose 16's history: the stub holds the outbox's sent rows of the 14 days before load_epoch, owners may read them" \
    "$(dbsql records portal "SELECT count(*) FROM portal_outbox WHERE sent_at >= (SELECT at FROM ops.watermarks WHERE name = 'notices') - interval '14 days' AND sent_at < (SELECT at FROM ops.watermarks WHERE name = 'notices')") t" \
    "$(dbsql partners-db partners "SELECT count(*) || ' ' || CASE WHEN has_table_privilege('owners', 'messaging.messages', 'SELECT') THEN 't' ELSE 'f' END FROM messaging.messages")"
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

# --- T0: placed just before 09:00 local -----------------------------------------
local_hm() { dbsql records portal "SELECT to_char(now() AT TIME ZONE 'UTC' + utc_offset_hours * interval '1 hour', 'HH24MI') FROM portal_settings"; }
i=0
while [ "$(local_hm)" -lt 0852 ] && [ "$(local_hm)" -ge 0800 ] && [ "$i" -lt 900 ]; do sleep 5; i=$((i + 5)); done
[ "$i" -eq 0 ] || info "start-load held $i s, until 08:52 local"
info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG" >/dev/null && pass "inject (no state fault: f1 is a seed-file fault)" || fail "inject"
info "gmctl start-load"
T0=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if $GMCTL start-load "$SCN" --playground "$PG" >/dev/null; then pass "start-load (T0 $T0)"; else fail "start-load"; exit 1; fi
T0S=$(date +%s)
LT0=$(local_hm)
if [ "$LT0" -ge 0800 ] && [ "$LT0" -lt 0859 ]; then
    pass "T0 just before 09:00 local, the reminders' queue ($LT0)"
else
    fail "T0 not between 08:00 and 08:59 local ($LT0): relaunch about $SETUP s before a host minute :50"
    exit 1
fi
i=0
while [ "$i" -lt 30 ]; do
    case $(bstatus) in running\ *) break ;; esac
    sleep 2; i=$((i + 2))
done
case $(bstatus) in running\ *) pass "partners-backend running: $(bstatus)" ;; *) fail "partners-backend not running: [$(bstatus)]" ;; esac
istatus() { docker exec "$(ctr interfaces)" cat /run/scheduler/status 2>/dev/null || true; }
ilog() { docker exec "$(ctr interfaces)" cat "$SCHEDLOG" 2>/dev/null || true; }
case $(istatus) in running\ *) pass "interfaces running: $(istatus)" ;; *) fail "interfaces not running: [$(istatus)]" ;; esac

# --- the gates, written by the test as postgres (no pms, no lis) -------------------
# The witnesses, chosen in the copy and the core as T0 leaves them: a sold
# animal (X, a dog whose owner and a buyer have active accounts), a dying one
# (Y), one whose signed consultation is published and notified (Z, its owner
# active with a channel), all three not due for a reminder; a due animal (W)
# whose owner withdraws the reminders through a reminder's link; an account
# to close (K).
DUE=$(dbsql records portal "SELECT ((now() AT TIME ZONE 'UTC') + utc_offset_hours * interval '1 hour')::date + reminder_lead_days FROM portal_settings")
pick=$(dbsql records portal "
WITH due AS (SELECT n.animal_id FROM portal_animals n WHERE make_date(extract(year FROM '$DUE'::date)::integer, 1, 1) + (n.animal_id::bigint * 211 % 365)::integer = '$DUE'::date),
cur AS (SELECT w.animal_id, w.owner_id, a.id AS account_id FROM portal_ownerships w
          JOIN portal_animals n ON n.animal_id = w.animal_id AND n.status = 'alive' AND n.species = 'dog'
          JOIN portal_accounts a ON a.owner_id = w.owner_id AND a.status = 'active' AND a.notify_by = 'email'
         WHERE w.role = 'owner' AND w.until_at IS NULL AND w.owner_id > 901
           AND w.animal_id NOT IN (SELECT animal_id FROM due)
           AND NOT EXISTS (SELECT 1 FROM portal_ownerships k WHERE k.animal_id = w.animal_id AND k.role = 'keeper')
           AND EXISTS (SELECT 1 FROM portal_documents d WHERE d.animal_id = w.animal_id AND d.kind = 'consultation')),
one AS (SELECT DISTINCT ON (owner_id) * FROM cur ORDER BY owner_id, animal_id)
SELECT string_agg(animal_id || ':' || owner_id, ' ' ORDER BY owner_id) FROM (SELECT * FROM one ORDER BY owner_id LIMIT 5) x")
set -- $pick
X=${1%%:*}; X_SELLER=${1#*:}; X_BUYER=${2#*:}; Y=${3%%:*}; Z=${4%%:*}; Z_OWNER=${4#*:}; K=${5#*:}
W=$(dbsql records portal "
SELECT n.animal_id || ':' || a.id || ':' || (SELECT o.message_key FROM portal_outbox o WHERE o.account_id = a.id AND o.template = 'reminder' ORDER BY o.id DESC LIMIT 1)
  FROM portal_animals n JOIN portal_ownerships w ON w.animal_id = n.animal_id AND w.role = 'owner' AND w.until_at IS NULL
  JOIN portal_accounts a ON a.owner_id = w.owner_id AND a.status = 'active'
 WHERE n.status = 'alive' AND n.species IN ('dog', 'cat', 'rabbit', 'ferret', 'horse')
   AND make_date(extract(year FROM '$DUE'::date)::integer, 1, 1) + (n.animal_id::bigint * 211 % 365)::integer = '$DUE'::date
   AND (SELECT e.granted FROM portal_consent_events e WHERE e.owner_id = w.owner_id AND e.purpose = 'reminders' ORDER BY e.at DESC, e.id DESC LIMIT 1)
   AND EXISTS (SELECT 1 FROM portal_outbox o WHERE o.account_id = a.id AND o.template = 'reminder')
   AND (SELECT count(*) FROM portal_ownerships v WHERE v.owner_id = w.owner_id AND v.role = 'owner' AND v.until_at IS NULL) = 1
 ORDER BY n.animal_id LIMIT 1")
W_ANIMAL=${W%%:*}; rest=${W#*:}; W_ACCOUNT=${rest%%:*}; W_KEY=${rest#*:}
info "witnesses: sold $X ($X_SELLER -> $X_BUYER), dying $Y, signed for $Z (owner $Z_OWNER), withdrawn $W_ANIMAL (account $W_ACCOUNT), closing $K; reminders due $DUE"
# The heredocs go to files first: dash mis-parses a heredoc holding parentheses inside $(...).
cat > "$tmp/gates.sql" <<EOF
BEGIN;
INSERT INTO owners (id, kind, name, email, phone, address, country, registered_at)
SELECT max(id) + 1, 'person', 'Short Test Owner', 'short-test-owner-$T0S@example.org', '+33 6 00 00 00 00', '1 rue du Test', 'FR', now()
  FROM owners RETURNING id \\gset no_
INSERT INTO animals (id, species, breed, sex, born_on, name, food_chain, registered_at)
SELECT max(id) + 1, 'cat', 'European', 'female', current_date - 400, 'Testcat', 'not-applicable', now() FROM animals
RETURNING id \\gset na_
INSERT INTO ownerships (animal_id, owner_id, role, from_at) VALUES (:na_id, :no_id, 'owner', now());
UPDATE ownerships SET until_at = now() WHERE animal_id = $X AND role = 'owner' AND until_at IS NULL;
INSERT INTO ownerships (animal_id, owner_id, role, from_at) VALUES ($X, $X_BUYER, 'owner', now());
UPDATE animals SET status = 'died', died_at = now(), death_kind = 'natural' WHERE id = $Y;
INSERT INTO consultations (id, animal_id, site_id, section_id, vet_id, kind, started_at, ended_at, state)
SELECT (SELECT max(id) + 1 FROM consultations), $Z, c.site_id, c.section_id, c.vet_id, 'emergency',
       now() - interval '30 minutes', now() - interval '5 minutes', 'closed'
  FROM consultations c WHERE c.animal_id = $Z ORDER BY c.id DESC LIMIT 1 RETURNING id \\gset closed_
INSERT INTO consultations (id, animal_id, site_id, section_id, vet_id, kind, started_at, ended_at, state, signed_at)
SELECT (SELECT max(id) + 1 FROM consultations), $Z, c.site_id, c.section_id, c.vet_id, 'emergency',
       now() - interval '25 minutes', now() - interval '2 minutes', 'signed', now()
  FROM consultations c WHERE c.animal_id = $Z ORDER BY c.id DESC LIMIT 1 RETURNING id \\gset signed_
COMMIT;
SELECT :no_id, :na_id, :closed_id, :signed_id;
EOF
gates=$(docker exec -i -u postgres "$(ctr records)" psql -XAtq -v ON_ERROR_STOP=1 -d clinic < "$tmp/gates.sql" 2>&1 || true)
set -- $(printf '%s' "$gates" | tail -n 1 | tr '|' ' ')
NEW_OWNER=$1 NEW_ANIMAL=$2 CLOSED=$3 SIGNED=$4
[ -n "$SIGNED" ] && pass "gates in clinic: owner $NEW_OWNER and animal $NEW_ANIMAL registered, $X sold, $Y dead, consultation $CLOSED closed and $SIGNED signed" \
    || { fail "gates in clinic not written: $gates"; exit 1; }
cat > "$tmp/lgates.sql" <<'EOF'
BEGIN;
SELECT string_agg(id::text, ' ' ORDER BY id) AS ids FROM (
  SELECT t.id FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
   WHERE o.account_id = 1 AND o.animal_id IS NOT NULL AND t.released_at IS NULL
     AND t.status IN ('ordered', 'in-progress', 'technical') ORDER BY t.id DESC LIMIT 2) x \gset t_
SELECT split_part(:'t_ids', ' ', 1) AS rel, split_part(:'t_ids', ' ', 2) AS tech \gset
UPDATE lab_order_tests SET status = 'released', technical_at = coalesce(technical_at, now()), technical_by = coalesce(technical_by, 71),
       released_at = now(), released_by = 79 WHERE id = :rel;
UPDATE lab_order_tests SET status = 'technical', technical_at = now(), technical_by = 71 WHERE id = :tech;
SELECT r.id AS rid, r.order_test_id AS amt FROM lab_results r JOIN lab_order_tests t ON t.id = r.order_test_id
  JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = 1 AND o.animal_id IS NOT NULL AND t.released_at < now() - interval '1 day' AND r.numeric_value IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM lab_results y WHERE y.supersedes_id = r.id)
   AND NOT EXISTS (SELECT 1 FROM lab_results z WHERE z.order_test_id = t.id AND z.supersedes_id IS NOT NULL)
 ORDER BY t.released_at DESC LIMIT 1 \gset
INSERT INTO lab_results (id, order_test_id, analyte_id, numeric_value, flag, interval_id, measured_at, supersedes_id,
                         amended_by, amended_at, amendment_reason)
SELECT (SELECT max(id) + 1 FROM lab_results), r.order_test_id, r.analyte_id, r.numeric_value + 1, r.flag, r.interval_id,
       now(), r.id, 79, now(), 'transcription error' FROM lab_results r WHERE r.id = :rid;
COMMIT;
SELECT :rel, :tech, :amt;
EOF
lgates=$(docker exec -i -u postgres "$(ctr lab)" psql -XAtq -v ON_ERROR_STOP=1 -d lab < "$tmp/lgates.sql" 2>&1 || true)
set -- $(printf '%s' "$lgates" | tail -n 1 | tr '|' ' ')
RELEASED=$1 TECHNICAL=$2 AMENDED=$3
[ -n "$AMENDED" ] && pass "gates in lab: test $RELEASED released, $TECHNICAL technically validated only, test $AMENDED's result amended" \
    || { fail "gates in lab not written: $lgates"; exit 1; }
GATES_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# A reminder's link withdraws W's owner's consent before the 09:00 queue; the
# next call at the stub answers 503 (its counter put before a multiple of 50).
out=$tmp/t0.jsonl
probe > "$out" <<EOF
{"method": "POST", "path": "/unsubscribe/$W_KEY"}
{"method": "POST", "path": "/login", "body": {"email": "$(dbsql records portal "SELECT email FROM portal_accounts WHERE owner_id = $K")", "password": "$(secret "$K")"}}
EOF
tally "$(python3 - "$out" <<'EOF'
import json, sys
a = [json.loads(l) for l in open(sys.argv[1])]
print(("PASS" if a[0]["status"] in (200, 204) else "FAIL") + f"  a reminder's withdrawal link used ({a[0]['status']})")
print(("PASS" if a[1]["status"] == 201 else "FAIL") + f"  the account to close logs in ({a[1]['status']})")
EOF
)"
KTOK=$(sed -n 2p "$out" | python3 -c 'import json, sys; q = json.loads(sys.stdin.read()); print(json.loads(q["body"]).get("token", "") if q["status"] == 201 else "")')
CLOSE=$(printf '%s\n' "{\"method\": \"POST\", \"path\": \"/me/close\", \"cookie\": \"$KTOK\"}" | probe | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["status"])')
same "account of owner $K closed (POST /me/close)" "200" "$CLOSE"
dbsql partners-db partners "SELECT setval('messaging.calls', (SELECT (last_value / 50 + 1) * 50 - 1 FROM messaging.calls), true)" >/dev/null
info "the stub's next call is number $(dbsql partners-db partners "SELECT last_value + 1 FROM messaging.calls"): a 503"

# --- waiting for the purposes' outputs ---------------------------------------------
# Polled every 20 s, at most DEADLINE seconds after T0: the copies (RL5's ten
# minutes), the publications (RL2's fifteen), the notice and the invitation
# at the stub, the 09:00 reminders sent.
state() {
    printf '%s %s %s %s %s %s %s\n' \
        "$(dbsql records portal "SELECT count(*) FROM portal_accounts WHERE owner_id = $NEW_OWNER AND status IN ('invited', 'active')")" \
        "$(dbsql records portal "SELECT (SELECT count(*) FROM portal_animals WHERE animal_id = $NEW_ANIMAL) + (SELECT count(*) FROM portal_animals WHERE animal_id = $Y AND status = 'died') + (SELECT count(*) FROM portal_ownerships WHERE animal_id = $X AND owner_id = $X_BUYER AND until_at IS NULL)")" \
        "$(dbsql records portal "SELECT count(*) FROM portal_documents WHERE source_ref IN ('C-$SIGNED', 'T-$RELEASED') OR (source_ref = 'T-$AMENDED' AND version > 1)")" \
        "$(dbsql records portal "SELECT count(*) FROM portal_outbox o JOIN portal_documents d ON d.id = o.document_id WHERE d.source_ref = 'C-$SIGNED' AND o.sent_at IS NOT NULL")" \
        "$(dbsql partners-db partners "SELECT count(*) FROM messaging.messages WHERE template = 'invitation' AND address = 'short-test-owner-$T0S@example.org'")" \
        "$(dbsql records portal "SELECT count(*) FILTER (WHERE sent_at IS NULL AND failed_at IS NULL) || '/' || count(*) FROM portal_outbox WHERE template = 'reminder' AND due_on = '$DUE'")" \
        "$(dbsql records portal "SELECT count(*) FROM portal_outbox WHERE template = 'closure' AND owner_id = $K AND sent_at IS NOT NULL")"
}
while :; do
    st=$(state)
    case $st in "1 3 3 1 1 0/"[1-9]*" 1") break ;; esac
    [ $(( $(date +%s) - T0S )) -lt "$DEADLINE" ] || { info "deadline reached: [$st]"; break; }
    sleep 20
done
info "outputs at T0+$(( $(date +%s) - T0S )) s, local $(local_hm): [$st] (account, copies, documents, notice sent, invitation at the stub, reminders unsent/queued, closure sent)"

# --- the copies (RL5) ----------------------------------------------------------------
same "the new owner's account invited within 10 minutes, its invitation queued and at the stub" "1 1 1" \
    "$(dbsql records portal "SELECT count(*) FILTER (WHERE a.invited_at <= '$GATES_AT'::timestamptz + interval '10 minutes') || ' ' || sum((SELECT count(*) FROM portal_outbox x WHERE x.account_id = a.id AND x.template = 'invitation')) FROM portal_accounts a WHERE a.owner_id = $NEW_OWNER") $(dbsql partners-db partners "SELECT count(*) FROM messaging.messages WHERE template = 'invitation' AND address = 'short-test-owner-$T0S@example.org'")"
same "the copies: the new animal and its ownership, the sale (the seller's ended, the buyer's open), the death" \
    "1 1 1 1 died" \
    "$(dbsql records portal "SELECT (SELECT count(*) FROM portal_animals WHERE animal_id = $NEW_ANIMAL) || ' ' || (SELECT count(*) FROM portal_ownerships WHERE animal_id = $NEW_ANIMAL AND owner_id = $NEW_OWNER AND until_at IS NULL) || ' ' || (SELECT count(*) FROM portal_ownerships WHERE animal_id = $X AND owner_id = $X_SELLER AND until_at IS NOT NULL AND role = 'owner' AND from_at < until_at AND until_at >= '$T0'::timestamptz - interval '1 minute') || ' ' || (SELECT count(*) FROM portal_ownerships WHERE animal_id = $X AND owner_id = $X_BUYER AND until_at IS NULL) || ' ' || (SELECT status FROM portal_animals WHERE animal_id = $Y)")"
# Activation from the stub's token (the owners' route may have used it first).
TOKEN=$(dbsql partners-db partners "SELECT split_part(payload ->> 'link', '/activate/', 2) FROM messaging.messages WHERE template = 'invitation' AND address = 'short-test-owner-$T0S@example.org'")
NEW_ACCOUNT=$(dbsql records portal "SELECT id FROM portal_accounts WHERE owner_id = $NEW_OWNER")
act=$(printf '%s\n' "{\"method\": \"POST\", \"path\": \"/accounts/activate\", \"body\": {\"token\": \"$TOKEN\", \"password\": \"short-test-$T0S\", \"reminders\": true}}" | probe)
astatus=$(printf '%s' "$act" | python3 -c 'import json, sys; print(json.loads(sys.stdin.read())["status"])')
same "activation with the stub's token: 200, the account active (or the owners' route's own activation)" "active" \
    "$( [ "$astatus" = 200 ] || [ "$(dbsql partners-db partners "SELECT count(*) FROM owners.visits WHERE account_id = ${NEW_ACCOUNT:-0} AND call = 'POST /accounts/activate' AND status = 200")" -gt 0 ] && dbsql records portal "SELECT status FROM portal_accounts WHERE id = ${NEW_ACCOUNT:-0}")"

# --- the release gate (RL1 to RL3) -------------------------------------------------------
same "published: the signed consultation, the released test, the amendment's version 2; not the closed consultation nor the technical test" \
    "$(printf '%s\n' "C-$SIGNED:1" "T-$AMENDED:2" "T-$RELEASED:1" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')" \
    "$(dbsql records portal "SELECT string_agg(source_ref || ':' || version, ' ' ORDER BY (source_ref || ':' || version) COLLATE \"C\") FROM portal_documents WHERE source_ref IN ('C-$SIGNED', 'C-$CLOSED', 'T-$RELEASED', 'T-$TECHNICAL') OR (source_ref = 'T-$AMENDED' AND published_at >= '$T0')")"
same "each within 15 minutes of its gate, the amended test's former version superseded" "t t" \
    "$(dbsql records portal "SELECT bool_and(published_at <= gated_at + interval '15 minutes') FROM portal_documents WHERE published_at >= '$T0'") $(dbsql records portal "SELECT superseded_at IS NOT NULL FROM portal_documents WHERE source_ref = 'T-$AMENDED' AND version = (SELECT max(version) - 1 FROM portal_documents WHERE source_ref = 'T-$AMENDED')")"

# --- the messages (MS) --------------------------------------------------------------------
same "the signed consultation's notice accepted with its key: at the stub, its provider id the stub's" "1 true" \
    "$(dbsql records portal "SELECT count(*) || ' ' || bool_and(o.provider_id = md5('messaging:' || o.message_key)::uuid) FROM portal_outbox o JOIN portal_documents d ON d.id = o.document_id WHERE d.source_ref = 'C-$SIGNED' AND o.sent_at IS NOT NULL")"
retried=$(dbsql partners-db partners "SELECT string_agg(c.message_key || ' ' || c.status, ',' ORDER BY c.call) FROM messaging.message_calls c WHERE c.message_key = (SELECT message_key FROM messaging.message_calls WHERE status = 503 AND at >= '$T0' ORDER BY call LIMIT 1)")
info "the 503'd key's calls: $retried"
case $retried in *" 503,"*" 202"*) pass "a 503 retried with the same key, then accepted" ;; *) fail "no 503 retried with the same key: [$retried]" ;; esac
expected=$(dbsql records portal "
WITH r AS (SELECT started_at FROM ops.runs WHERE purpose = 'vet-portal-messages' AND job = 'queue-reminders' ORDER BY id DESC LIMIT 1)
SELECT coalesce(string_agg(n.animal_id::text, ' ' ORDER BY n.animal_id), '') FROM r, portal_animals n
  JOIN portal_ownerships w ON w.animal_id = n.animal_id AND w.role = 'owner' AND w.until_at IS NULL
  JOIN portal_accounts a ON a.owner_id = w.owner_id AND a.status <> 'closed'
 WHERE n.status = 'alive' AND n.species IN ('dog', 'cat', 'rabbit', 'ferret', 'horse')
   AND make_date(extract(year FROM '$DUE'::date)::integer, 1, 1) + (n.animal_id::bigint * 211 % 365)::integer = '$DUE'::date
   AND (SELECT e.granted FROM portal_consent_events e WHERE e.owner_id = w.owner_id AND e.purpose = 'reminders' AND e.at <= r.started_at ORDER BY e.at DESC, e.id DESC LIMIT 1)")
queued=$(dbsql records portal "SELECT coalesce(string_agg(animal_id::text, ' ' ORDER BY animal_id), '') FROM portal_outbox WHERE template = 'reminder' AND due_on = '$DUE'")
info "reminders due $DUE: $(echo $queued | wc -w) queued"
same "the 09:00 reminders: the due animals with consent, one each" "$expected" "$queued"
case " $queued " in *" $W_ANIMAL "*) fail "the withdrawn animal $W_ANIMAL got a reminder" ;; *) pass "the reminder withdrawn by its link excluded (animal $W_ANIMAL)" ;; esac
same "the reminders sent, within 08:00-20:00 local" "0 true" \
    "$(dbsql records portal "SELECT count(*) FILTER (WHERE o.sent_at IS NULL) || ' ' || coalesce(bool_and((o.sent_at AT TIME ZONE 'UTC' + s.utc_offset_hours * interval '1 hour')::time BETWEEN s.reminders_from AND s.reminders_until), true) FROM portal_outbox o, portal_settings s WHERE o.template = 'reminder' AND o.due_on = '$DUE'")"
same "the closure message at the stub, nothing else sent to the closed account after it" "1 0" \
    "$(dbsql partners-db partners "SELECT count(*) FILTER (WHERE template = 'closure' AND received_at >= '$T0') || ' ' || count(*) FILTER (WHERE template <> 'closure' AND received_at > (SELECT max(received_at) FROM messaging.messages WHERE template = 'closure' AND account_id = $K)) FROM messaging.messages WHERE account_id = $K")"
ierrs=$(ilog | grep ' error ' || true)
same "interfaces ran its six jobs without an error" "0" "$(printf '%s' "$ierrs" | grep -c . || true)"
[ -z "$ierrs" ] || printf '%s\n' "$ierrs" | head -n 8 | cut -c1-300 | sed 's/^/....  interfaces: /'
info "interfaces' runs since T0: $(dbsql records portal "SELECT string_agg(job || ' ' || n, ', ' ORDER BY job) FROM (SELECT job, count(*) n FROM ops.runs WHERE started_at >= '$T0' GROUP BY job) x")"

# --- the owners' traffic --------------------------------------------------------------
visits=$(dbsql partners-db partners "SELECT count(*) || ' ' || count(DISTINCT account_id) FROM owners.visits WHERE at >= '$T0'")
info "owners.visits since T0 (calls, accounts): $visits; by call: $(dbsql partners-db partners "SELECT string_agg(call || ' ' || coalesce(status::text, '-') || ' ' || n, ', ' ORDER BY call, status)
  FROM (SELECT call, status, count(*) n FROM owners.visits WHERE at >= '$T0' GROUP BY 1, 2) x")"
[ "${visits%% *}" -gt 0 ] && pass "the owners' route recorded its calls in owners.visits" || fail "no call in owners.visits since T0"
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
    "$(dbsql records portal "SELECT count(*) FROM portal_sessions WHERE created_at >= '$T0' AND account_id IN ($(dbsql partners-db partners "SELECT coalesce(string_agg(DISTINCT account_id::text, ','), '0') FROM owners.visits WHERE at >= '$T0'")) AND account_id <> (SELECT id FROM portal_accounts WHERE owner_id = $K)")"
info "PUT /me/preferences through gm_api's _call: $(dbsql partners-db partners "SELECT coalesce(string_agg(status::text, ' '), 'none this run') FROM owners.visits WHERE at >= '$T0' AND call = 'PUT /me/preferences'")"
errs=$(blog | grep ' error ' || true)
same "partners-backend ran without an error" "0" "$(printf '%s' "$errs" | grep -c . || true)"
[ -z "$errs" ] || printf '%s\n' "$errs" | head -n 8 | cut -c1-300 | sed 's/^/....  partners-backend: /'
info "portal-api's request log: $(docker exec "$(ctr portal-api)" sh -c 'grep -c " request " /var/log/api/api.log' 2>/dev/null) requests, $(docker exec "$(ctr portal-api)" sh -c 'grep -c " error " /var/log/api/api.log || true' 2>/dev/null) errors"

# --- the purposes' checks, as gmctl check runs them ---------------------------------------
# RL1-RL5 and MS2-MS6 on the runner (interfaces), RL6 and MS1 on partners-db,
# each fed to `sh -s` as root with CHECK_SINCE at T0.
run_check() {   # run_check <purpose> <file> -> "<exit> <output>"
    case $2 in rl6-*|ms1-*) node=partners-db ;; *) node=interfaces ;; esac
    o=$(docker exec -i -u root -e "CHECK_SINCE=$T0" "$(ctr $node)" sh -s < "$REPO/purposes/$1/checks/$2" 2>&1) && e=0 || e=$?
    printf '%s %s\n' "$e" "$(printf '%s' "$o" | tr '\n' ' ' | cut -c1-260)"
}
CHECKS="vet-portal-release:rl1-no-document-before-gate.sh vet-portal-release:rl2-gate-published.sh
vet-portal-release:rl3-amendment-versioned.sh vet-portal-release:rl4-no-identifying-content.sh
vet-portal-release:rl5-copies-current.sh vet-portal-release:rl6-owner-scope.sh vet-portal-messages:ms1-once.sh
vet-portal-messages:ms2-consent.sh vet-portal-messages:ms3-sending-hours.sh vet-portal-messages:ms4-payload.sh
vet-portal-messages:ms5-notice-accepted.sh vet-portal-messages:ms6-recipient-current.sh"
info "the checks at T0+$(( $(date +%s) - T0S )) s, CHECK_SINCE $T0"
for c in $CHECKS; do
    r=$(run_check "${c%%:*}" "${c#*:}")
    case $r in "0 "*) pass "${c#*:}: exit 0: ${r#* }" ;; *) fail "${c#*:}: exit ${r%% *} (fixed expected): ${r#* }" ;; esac
done
# gm_check_read dropped on the portal's ten tables: every check refuses to judge (exit 2,
# D432), never a verdict on an empty read.
docker exec -i -u postgres "$(ctr records)" psql -XAtq -d portal >/dev/null <<'EOF'
SELECT format('DROP POLICY IF EXISTS gm_check_read ON %I', tablename) FROM pg_policies WHERE policyname = 'gm_check_read' AND tablename LIKE 'portal\_%' \gexec
EOF
same "gm_check_read dropped on the portal's ten tables" "0" \
    "$(dbsql records portal "SELECT count(*) FROM pg_policies WHERE policyname = 'gm_check_read'")"
for c in $CHECKS; do
    r=$(run_check "${c%%:*}" "${c#*:}")
    case $r in "2 "*) pass "gm_check_read dropped: ${c#*:} cannot judge (exit 2)" ;;
        *) fail "gm_check_read dropped: ${c#*:} exit ${r%% *}: ${r#* }" ;; esac
done

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
