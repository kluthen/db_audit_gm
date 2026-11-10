#!/bin/sh
# MS6 the recipient current (vet-portal-messages, purpose 16;
# vet-portal-domain.md, "vet-portal-messages", rules 5 and 7): every reminder
# sent since the judged moment was, by the core at its sent_at, for an animal
# alive (clinic animals.died_at unset or after it) and to its current owner
# (the account's owner the animal's owner in clinic ownerships, role owner,
# from_at at or before it, until_at unset or after it); and no message but a
# closure sent since the judged moment went to an account closed at or before
# its sent_at. Judges runs (the reminders not checked again at sending, the
# copy's ownerships stale, the closed accounts' rows sent).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal
# and clinic are read as gm_check with check-sql, portal's tables through the
# GM's read policy gm_check_read (spec D432: no verdict when it is gone or a
# restrictive policy hides rows); no job is ever run. Exit 0 fixed (with its
# witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# send-messages' next run when reminders wait in the outbox, else
# queue-reminders'). Written for the clinic's names (the constants below);
# the GM adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MS6"
PORTAL = ("records", "portal")       # the source part: node, database
CLINIC = ("records", "clinic")       # the core's record, whose truth the reminders answer to
PURPOSE = "vet-portal-messages"
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
BATCH = 300                          # rows per -v value, well under one argument's 128 KiB
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


def batched(text, db, rows, **values):
    """The statement once per BATCH of rows, given as the JSON array %(rows)s."""
    out = []
    for i in range(0, len(rows), BATCH):
        out += query(text, db, rows=json.dumps(rows[i:i + BATCH], separators=(",", ":")), **values)
    return out


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


guard(["portal_outbox", "portal_accounts"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

# Any message but a closure, sent to an account closed at or before.
bad = [f"{t} {key} sent at {sent} to account {a}, closed at {closed}" for t, key, a, sent, closed in query("""
SELECT o.template, o.message_key, o.account_id, o.sent_at::text, a.closed_at::text
  FROM portal_outbox o JOIN portal_accounts a ON a.id = o.account_id
 WHERE o.sent_at > to_timestamp(%(judged)s::float8) AND o.template <> 'closure' AND a.closed_at <= o.sent_at
 ORDER BY o.sent_at, o.id
""", judged=judged)]

reminders = query("""
SELECT o.message_key, o.animal_id, a.owner_id, o.sent_at::text
  FROM portal_outbox o LEFT JOIN portal_accounts a ON a.id = o.account_id
 WHERE o.template = 'reminder' AND o.sent_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.sent_at, o.id
""", judged=judged)
lost = [r[0] for r in reminders if not r[2]]
if lost:
    cannot(f"the account of reminder {lost[0]} is not in {PORTAL[1]}")
bad += [f"reminder {key} sent at {sent}: {how}" for key, sent, how in batched("""
SELECT x.key, x.sent::text,
       CASE WHEN n.id IS NULL THEN 'animal ' || x.animal || ' is not in the record'
            WHEN n.died_at <= x.sent THEN 'animal ' || x.animal || ' had died '
                                          || ceil(extract(epoch FROM x.sent - n.died_at))::bigint || ' s before'
            ELSE 'owner ' || x.owner || ' was not the current owner of animal ' || x.animal END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (key text, animal integer, owner integer, sent timestamptz)
  LEFT JOIN animals n ON n.id = x.animal
 WHERE n.id IS NULL OR n.died_at <= x.sent
    OR NOT EXISTS (SELECT 1 FROM ownerships w
                    WHERE w.animal_id = x.animal AND w.owner_id = x.owner AND w.role = 'owner'
                      AND w.from_at <= x.sent AND (w.until_at IS NULL OR w.until_at > x.sent))
 ORDER BY x.sent, x.key
""", CLINIC, [{"key": k, "animal": int(an), "owner": int(o), "sent": s} for k, an, o, s in reminders])]

if bad:
    more = f" ({len(bad)} messages sent {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {bad[0]}{more}")
    sys.exit(1)
if reminders:
    print(f"{INVARIANT} fixed: {len(reminders)} reminders sent {window}, each for an animal alive and to its "
          f"current owner by the core at its sending; no message but a closure to a closed account")
    sys.exit(0)
wait_reminders(f"no reminder sent {window}")
PY
