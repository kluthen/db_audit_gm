#!/bin/sh
# MS2 consent at sending (vet-portal-messages, purpose 16;
# vet-portal-domain.md, "vet-portal-messages", rule 6): every reminder sent
# since the judged moment had its owner's reminders consent at its sent_at:
# the owner's latest `reminders` event in portal_consent_events at or before
# sent_at is a grant (none: no consent). Transactional messages exempt.
# Judges runs (the consent read at queueing only, the withdrawals ignored;
# the account's reminders flag read instead of the events; the earliest
# event taken for the latest).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal
# is read as gm_check with check-sql, its tables through the GM's read policy
# gm_check_read (spec D432: no verdict when it is gone or a restrictive
# policy hides rows); no job is ever run. Exit 0 fixed (with its witness,
# 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# send-messages' next run when reminders wait in the outbox, else
# queue-reminders'). Written for the clinic's names (the constants below);
# the GM adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MS2"
PORTAL = ("records", "portal")       # the source part: node, database
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


def wait_reminders(why):
    """Exit 3 until the next sending when reminders wait in the outbox, else the next queueing."""
    unsent = int(query("SELECT count(*) FROM portal_outbox WHERE template = 'reminder' AND sent_at IS NULL"
                       " AND failed_at IS NULL")[0][0])
    wait("send-messages" if unsent else "queue-reminders", why)


guard(["portal_outbox", "portal_consent_events"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

rows = query("""
SELECT o.message_key, o.owner_id, o.sent_at::text, coalesce(e.state, 'no reminders event')
  FROM portal_outbox o
  LEFT JOIN LATERAL (SELECT CASE WHEN e.granted THEN 'granted' ELSE 'withdrawn at ' || e.at::text END AS state
                       FROM portal_consent_events e
                      WHERE e.owner_id = o.owner_id AND e.purpose = 'reminders' AND e.at <= o.sent_at
                      ORDER BY e.at DESC, e.id DESC LIMIT 1) e ON true
 WHERE o.template = 'reminder' AND o.sent_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.sent_at, o.id
""", judged=judged)
bad = [r for r in rows if r[3] != "granted"]
if bad:
    key, owner, sent, state = bad[0]
    more = f" ({len(bad)} of {len(rows)} reminders sent {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: reminder {key} sent at {sent}, its owner {owner}'s consent {state}{more}")
    sys.exit(1)
if rows:
    print(f"{INVARIANT} fixed: {len(rows)} reminders sent {window}, each with its owner's consent granted at "
          f"its sending by the latest event")
    sys.exit(0)
wait_reminders(f"no reminder sent {window}")
PY
