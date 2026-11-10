#!/bin/sh
# MS4 the payload (vet-portal-messages, purpose 16; vet-portal-domain.md,
# "vet-portal-messages", rules 3 and 7): every message sent since the judged
# moment has a payload of the keys template, name, animal, link and due_on
# only (never a result, a diagnosis, an identifier, a password), its template
# the row's; a notice or a reminder the animal's name (the copy's name of the
# row's animal, or of the document's, or `herd <id>` for a herd's document)
# and a link; an invitation a link ending activate/ and a 64-hex token, a
# reset password-reset/ and one; the payload's name the recipient account's
# display_name (a closure, and a closed account's message, its name erased,
# exempt); no value holding an '@'. Judges runs (the notice's body copied
# into the payload, another owner's name, the password sent in a reset, the
# address in the payload).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal
# is read as gm_check with check-sql, its tables through the GM's read policy
# gm_check_read (spec D432: no verdict when it is gone or a restrictive
# policy hides rows); no job is ever run. Exit 0 fixed (with its witness,
# 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# send-messages' next run). Written for the clinic's names (the constants
# below); the GM adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MS4"
PORTAL = ("records", "portal")       # the source part: node, database
PURPOSE = "vet-portal-messages"
KEYS = {"template", "name", "animal", "link", "due_on"}      # a payload's keys, all templates
TOKEN = {"invitation": r"/activate/[0-9a-f]{64}", "password-reset": r"/password-reset/[0-9a-f]{64}"}
import json
import os
import re
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


def query(text, db=None, width=None, **values):
    """Rows of the statement; with width, the last column keeps any '|' it holds."""
    node, name = db or PORTAL
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|", width - 1) if width else line.split("|")
            for line in helper(argv, text).splitlines()]


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


def strings(value):
    """Every string in a JSON value, its keys too."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield k
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def wrong(template, j):
    """What is wrong with one message's payload, or None."""
    payload = j["payload"]
    if not isinstance(payload, dict):
        return "its payload is no object"
    stray = sorted(set(payload) - KEYS)
    if stray:
        return f"its payload holds a key {stray[0]}"
    if payload.get("template") != template:
        return f"its payload's template is not the row's {template}"
    if any("@" in s for s in strings(payload)):
        return "its payload holds an '@' (an address)"
    link = payload.get("link")
    if template in ("document-notice", "reminder"):
        if not j["known"]:
            cannot(f"the {'document' if template == 'document-notice' else 'animal'} of message "
                   f"{j['key']} is not in {PORTAL[1]}")
        if payload.get("animal") != j["animal"]:
            return "its payload's animal is not its animal's name"
        if not isinstance(link, str) or not link:
            return "its payload has no link"
    if template in TOKEN and not (isinstance(link, str) and re.search(TOKEN[template] + "$", link)):
        return f"its payload's link does not end {TOKEN[template][1:].split('/')[0]}/ and a 64-hex token"
    if template != "closure":
        if j["status"] is None:
            cannot(f"the account of message {j['key']} is not in {PORTAL[1]}")
        if j["status"] != "closed" and payload.get("name") != j["display_name"]:
            return "its payload's name is not its account's display_name"
    return None


guard(["portal_outbox", "portal_accounts", "portal_animals", "portal_documents"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

rows = query("""
SELECT o.template,
       jsonb_build_object(
           'key', o.message_key, 'payload', o.payload, 'display_name', a.display_name, 'status', a.status,
           'animal', CASE o.template WHEN 'reminder' THEN n.name
                                     WHEN 'document-notice' THEN coalesce(dn.name, 'herd ' || d.herd_id) END,
           'known', CASE o.template WHEN 'reminder' THEN n.animal_id IS NOT NULL
                                    WHEN 'document-notice' THEN d.id IS NOT NULL
                                                                AND (d.animal_id IS NULL OR dn.animal_id IS NOT NULL)
                                    END)::text
  FROM portal_outbox o
  LEFT JOIN portal_accounts a ON a.id = o.account_id
  LEFT JOIN portal_animals n ON n.animal_id = o.animal_id
  LEFT JOIN portal_documents d ON d.id = o.document_id
  LEFT JOIN portal_animals dn ON dn.animal_id = d.animal_id
 WHERE o.sent_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.sent_at, o.id
""", width=2, judged=judged)
bad = []
for template, text in rows:
    j = json.loads(text)
    how = wrong(template, j)
    if how:
        bad.append(f"{template} {j['key']}: {how}")
if bad:
    more = f" ({len(bad)} of {len(rows)} messages sent {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {bad[0]}{more}")
    sys.exit(1)
if rows:
    n = {}
    for template, _ in rows:
        n[template] = n.get(template, 0) + 1
    print(f"{INVARIANT} fixed: {len(rows)} messages sent {window} ("
          + ", ".join(f"{v} {k}" for k, v in sorted(n.items()))
          + "), each payload its template's keys, names and link, no '@'")
    sys.exit(0)
wait("send-messages", f"no message sent {window}")
PY
