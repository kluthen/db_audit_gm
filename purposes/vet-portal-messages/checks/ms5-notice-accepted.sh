#!/bin/sh
# MS5 every notice accepted (vet-portal-messages, purpose 16;
# vet-portal-domain.md, "vet-portal-messages", rule 7): every document
# published since the judged moment has, once 15 minutes have passed, for
# each account that saw it at its publication as queue-notices computes it
# (its animal's current owner, the record within the ownership; a keeper the
# current owner granted access to, by the latest keeper-access event; the
# herd's keeper), active then (activated at or before the publication, not
# closed within the 15 minutes), its channel not none and its address for it
# set: a document-notice in the outbox accepted by the service (sent_at)
# within 15 minutes of the publication, or failed (failed_at) after at least
# six attempts with its ops.incidents row (purpose vet-portal-messages, kind
# failed, ref the message key). Judges triggers (the service's slowness or
# 503s retried too slowly, a watermark past documents, the sending stalled,
# a failure without its incident).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal
# (its ops.incidents too) is read as gm_check with check-sql, its tables
# through the GM's read policy gm_check_read (spec D432: no verdict when it
# is gone or a restrictive policy hides rows); no job is ever run. Exit 0
# fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too soon
# (remaining=, until the earliest publication's 15 minutes, or queue-notices'
# next run). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MS5"
PORTAL = ("records", "portal")       # the source part: node, database
DEADLINE = 900                       # seconds from the publication to the notice's acceptance
ATTEMPTS = 6                         # send-messages' options.attempts
PURPOSE = "vet-portal-messages"
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
GUARD = """
SELECT t.name,
       CASE WHEN c.oid IS NULL THEN 'missing'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read') THEN 'gone'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read'
                                AND p.permissive = 'PERMISSIVE' AND p.cmd IN ('SELECT', 'ALL')
                                AND p.qual = 'true' AND p.roles && ARRAY['public', 'gm_check']::name[])
                 THEN 'changed'
            ELSE 'ok' END,
       coalesce((SELECT string_agg(p.policyname, ',' ORDER BY p.policyname) FROM pg_policies p
                  WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                    AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('SELECT', 'ALL')
                    AND EXISTS (SELECT 1 FROM unnest(p.roles) AS r (role)
                                 WHERE CASE WHEN r.role = 'public' THEN true
                                            ELSE pg_has_role('gm_check', r.role, 'MEMBER') END)), '')
  FROM unnest(string_to_array(%(tables)s, ',')) WITH ORDINALITY AS t (name, i)
  LEFT JOIN pg_class c ON c.oid = to_regclass(t.name)
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
 ORDER BY t.i
"""


def cannot(text):
    print(f"{INVARIANT} cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def query(text, db=None, **values):
    node, name = db or PORTAL
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def guard(tables):
    """Exit 2 unless gm_check reads every row of each portal table (spec D432)."""
    for name, state, hiding in query(GUARD, PORTAL, tables=",".join(tables)):
        if state == "missing":
            cannot(f"{name} is not in {PORTAL[1]}")
        if state == "gone":
            cannot(f"the GM's read policy on {name} is gone")
        if state == "changed":
            cannot(f"the GM's read policy on {name} is changed: it no longer shows gm_check every row")
        if hiding:
            cannot(f"a restrictive policy {hiding.split(',')[0]} on {name} hides rows from gm_check")


def wait(job, why):
    """Exit 3, remaining= until the job's next run."""
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def later(seconds, why):
    print(f"remaining={max(1, int(seconds) + 1)} {why}")
    sys.exit(3)


guard(["portal_documents", "portal_ownerships", "portal_consent_events", "portal_herds", "portal_accounts",
       "portal_outbox"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query("SELECT extract(epoch FROM now())")[0][0])
rows = query("""
WITH d AS (
    SELECT id, animal_id, herd_id, record_at, published_at FROM portal_documents
     WHERE published_at > to_timestamp(%(judged)s::float8)
),
cur AS (
    SELECT d.id AS document_id, d.animal_id, d.published_at, w.owner_id
      FROM d JOIN portal_ownerships w ON w.animal_id = d.animal_id AND w.role = 'owner'
                                     AND w.from_at <= d.published_at
                                     AND (w.until_at IS NULL OR w.until_at > d.published_at)
     WHERE d.record_at >= w.from_at
),
seen AS (
    SELECT document_id, owner_id FROM cur
    UNION
    SELECT cur.document_id, k.owner_id
      FROM cur JOIN portal_ownerships k ON k.animal_id = cur.animal_id AND k.role = 'keeper'
                                       AND k.from_at <= cur.published_at
                                       AND (k.until_at IS NULL OR k.until_at > cur.published_at)
     WHERE (SELECT e.granted FROM portal_consent_events e
             WHERE e.purpose = 'keeper-access' AND e.owner_id = cur.owner_id AND e.animal_id = cur.animal_id
               AND e.keeper_id = k.owner_id AND e.at <= cur.published_at
             ORDER BY e.at DESC, e.id DESC LIMIT 1)
    UNION
    SELECT d.id, h.keeper_owner_id FROM d JOIN portal_herds h ON h.herd_id = d.herd_id
),
due AS (
    SELECT s.document_id, a.id AS account_id, d.published_at
      FROM seen s JOIN d ON d.id = s.document_id JOIN portal_accounts a ON a.owner_id = s.owner_id
     WHERE a.activated_at <= d.published_at
       AND (a.closed_at IS NULL OR a.closed_at > d.published_at + make_interval(secs => %(deadline)s::int))
       AND a.notify_by <> 'none'
       AND CASE a.notify_by WHEN 'sms' THEN a.phone ELSE a.email END IS NOT NULL
)
SELECT due.document_id, due.account_id, extract(epoch FROM due.published_at),
       CASE WHEN o.id IS NULL THEN 'no notice in the outbox'
            WHEN o.sent_at IS NOT NULL
                 THEN CASE WHEN o.sent_at <= due.published_at + make_interval(secs => %(deadline)s::int) THEN 'ok'
                           ELSE 'accepted ' || ceil(extract(epoch FROM o.sent_at - due.published_at))::bigint
                                || ' s after the publication' END
            WHEN o.failed_at IS NOT NULL
                 THEN CASE WHEN o.attempts >= %(attempts)s::int
                                AND EXISTS (SELECT 1 FROM ops.incidents i
                                             WHERE i.purpose = %(purpose)s AND i.kind = 'failed'
                                               AND i.ref = o.message_key::text) THEN 'failed'
                           WHEN o.attempts < %(attempts)s::int
                                THEN 'stopped after ' || o.attempts || ' attempts (' || coalesce(o.last_status, '-')
                                     || ')'
                           ELSE 'failed with no incident' END
            ELSE 'not accepted ' || ceil(extract(epoch FROM now() - due.published_at))::bigint
                 || ' s after the publication (' || o.attempts || ' attempts)' END,
       coalesce(o.message_key::text, '')
  FROM due
  LEFT JOIN LATERAL (SELECT * FROM portal_outbox o
                      WHERE o.template = 'document-notice' AND o.document_id = due.document_id
                        AND o.account_id = due.account_id
                      ORDER BY o.sent_at NULLS LAST, o.id LIMIT 1) o ON true
 ORDER BY due.published_at, due.document_id, due.account_id
""", judged=judged, deadline=DEADLINE, attempts=ATTEMPTS, purpose=PURPOSE)
pairs = [(int(d), int(a), float(p), how, key) for d, a, p, how, key in rows]
# A trigger is judged once its window has passed, or at once when its output is already
# there (a satisfied trigger cannot fail later); an unsatisfied one inside its window waits.
ripe = [x for x in pairs if x[2] + DEADLINE <= now or x[3] in ("ok", "failed")]
bad = [x for x in ripe if x[3] not in ("ok", "failed")]
if bad:
    d, a, _, how, key = bad[0]
    more = f" ({len(bad)} of {len(ripe)} notices due {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: document {d} for account {a}"
          + (f" (notice {key})" if key else "") + f": {how}{more}")
    sys.exit(1)
if ripe:
    failed = sum(1 for x in ripe if x[3] == "failed")
    print(f"{INVARIANT} fixed: {len(ripe)} notices due for documents published {window}, each accepted within "
          f"{DEADLINE // 60} minutes or failed with its incident ({failed} failed; "
          f"{len(pairs) - len(ripe)} still within their 15 minutes)")
    sys.exit(0)
if pairs:
    first = min(pairs, key=lambda x: x[2])
    later(first[2] + DEADLINE - now, f"document {first[0]}'s notice for account {first[1]} is still to be judged")
wait("queue-notices", f"no document published {window} for an active account with a channel")
PY
