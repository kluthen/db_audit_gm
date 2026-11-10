#!/bin/sh
# RL2 every gate published, once (vet-portal-release, purpose 15;
# vet-portal-domain.md, "vet-portal-release"): every gate passed since the
# judged moment (a consultation signed, a stay ended, a test of the centre's
# lab account with an animal released) has, once 15 minutes have passed, its
# version 1 document (C-, S- or T- and the record's id) published within 15
# minutes of the gate, exactly one; and no source_ref of a document published
# since the judged moment has two version 1 documents. Judges triggers (a
# publishing job slowed or stalled, a watermark moved past gates, the
# documents' unique dropped and a re-read publishing again).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic,
# lab and portal are read as gm_check with check-sql, portal's tables through
# the GM's read policy gm_check_read (spec D432: no verdict when it is gone or
# a restrictive policy hides rows); no job is ever run. Exit 0 fixed (with its
# witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# the earliest gate's 15 minutes, or publish-records' next run). Written for
# the clinic's names (the constants below); the GM adapts them as it copies
# the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "RL2"
PORTAL = ("records", "portal")       # the target part: node, database
CLINIC = ("records", "clinic")       # the source part
LAB = ("lab", "lab")                 # the source_lab part
ACCOUNT = 1                          # the centre's lab account (publish-results' options.account)
DEADLINE = 900                       # seconds from the gate to its document
PURPOSE = "vet-portal-release"
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


def query(text, db, **values):
    node, name = db
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


def later(seconds, why):
    print(f"remaining={max(1, int(seconds) + 1)} {why}")
    sys.exit(3)


guard(["portal_documents"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query("SELECT extract(epoch FROM now())", PORTAL)[0][0])
# The gates: (source_ref, gate as text, gate in seconds).
gates = query("""
SELECT 'C-' || id, signed_at::text, extract(epoch FROM signed_at) FROM consultations
 WHERE state = 'signed' AND signed_at > to_timestamp(%(judged)s::float8)
UNION ALL
SELECT 'S-' || id, discharged_at::text, extract(epoch FROM discharged_at) FROM stays
 WHERE discharged_at > to_timestamp(%(judged)s::float8)
""", CLINIC, judged=judged)
gates += query("""
SELECT 'T-' || t.id, t.released_at::text, extract(epoch FROM t.released_at)
  FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = %(account)s::integer AND o.animal_id IS NOT NULL
   AND t.released_at > to_timestamp(%(judged)s::float8)
""", LAB, judged=judged, account=ACCOUNT)
gates = [(ref, text, float(at)) for ref, text, at in gates]
# A trigger is judged once its window has passed, or at once when its output is already
# there (a satisfied trigger cannot fail later); an unsatisfied one inside its window waits.
unripe = {g[0] for g in gates if g[2] + DEADLINE > now}

bad = []
for ref, n in query("""
SELECT d.source_ref, count(*) FROM portal_documents d
 WHERE d.version = 1
   AND d.source_ref IN (SELECT source_ref FROM portal_documents WHERE published_at > to_timestamp(%(judged)s::float8))
 GROUP BY d.source_ref HAVING count(*) > 1 ORDER BY d.source_ref
""", PORTAL, judged=judged):
    bad.append((ref, f"published {n} times as version 1"))
bad += batched("""
SELECT x.ref,
       CASE WHEN count(d.id) = 0 THEN 'gate passed ' || ceil(extract(epoch FROM now() - x.gate))::bigint
                                      || ' s ago, no document'
            WHEN count(d.id) > 1 THEN 'published ' || count(d.id) || ' times as version 1'
            ELSE 'published ' || ceil(extract(epoch FROM min(d.published_at) - x.gate))::bigint
                 || ' s after its gate' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (ref text, gate timestamptz)
  LEFT JOIN portal_documents d ON d.source_ref = x.ref AND d.version = 1
 GROUP BY x.ref, x.gate
HAVING count(d.id) <> 1 OR min(d.published_at) > x.gate + make_interval(secs => %(deadline)s::int)
 ORDER BY x.gate, x.ref
""", PORTAL, [{"ref": r, "gate": t} for r, t, _ in gates], deadline=DEADLINE)

pending = {ref for ref, how in bad if ref in unripe and how.startswith("gate passed")}
bad = [b for b in bad if b[0] not in pending]
ripe = [g for g in gates if g[0] not in pending]
if bad:
    seen = set()
    bad = [b for b in bad if not (b[0] in seen or seen.add(b[0]))]
    ref, how = bad[0]
    more = f" ({len(bad)} gates {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {ref}: {how}{more}")
    sys.exit(1)
if ripe:
    print(f"{INVARIANT} fixed: {len(ripe)} gates passed {window}, each published once within "
          f"{DEADLINE // 60} minutes ({len(gates) - len(ripe)} still within their 15 minutes)")
    sys.exit(0)
if gates:
    first = min((g for g in gates if g[0] in pending), key=lambda g: g[2])
    later(first[2] + DEADLINE - now, f"{first[0]}'s gate is still to be judged")
wait("publish-records", f"no gate passed {window}")
PY
