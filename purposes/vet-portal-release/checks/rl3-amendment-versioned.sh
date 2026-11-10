#!/bin/sh
# RL3 every amendment versioned (vet-portal-release, purpose 15;
# vet-portal-domain.md, "vet-portal-release"): every amendment since the
# judged moment of a released test of the centre's lab account (lab_results
# rows superseding another, amended_at after the judged moment and at or after
# the test's release, one amendment per test and amended_at) has, once 15
# minutes have passed, a document T-<test> of version above 1 whose gated_at
# is the amendment's amended_at, published within 15 minutes of it, the
# version before it superseded (superseded_at set). Judges triggers (the
# amendments read by released_at only, a new version without the former
# superseded, the amendments overwriting version 1).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); lab and
# portal are read as gm_check with check-sql, portal's tables through the
# GM's read policy gm_check_read (spec D432: no verdict when it is gone or a
# restrictive policy hides rows); no job is ever run. Exit 0 fixed (with its
# witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# the earliest amendment's 15 minutes, or publish-results' next run). Written
# for the clinic's names (the constants below); the GM adapts them as it
# copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "RL3"
PORTAL = ("records", "portal")       # the target part: node, database
LAB = ("lab", "lab")                 # the source_lab part
ACCOUNT = 1                          # the centre's lab account (publish-results' options.account)
DEADLINE = 900                       # seconds from the amendment to its version
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
amended = [(int(t), text, float(at)) for t, text, at in query("""
SELECT r.order_test_id, r.amended_at::text, extract(epoch FROM r.amended_at)
  FROM lab_results r JOIN lab_order_tests t ON t.id = r.order_test_id JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = %(account)s::integer AND o.animal_id IS NOT NULL AND t.released_at IS NOT NULL
   AND r.supersedes_id IS NOT NULL AND r.amended_at > to_timestamp(%(judged)s::float8)
   AND r.amended_at >= t.released_at
 GROUP BY r.order_test_id, r.amended_at
 ORDER BY r.amended_at, r.order_test_id
""", LAB, judged=judged, account=ACCOUNT)]
# A trigger is judged once its window has passed, or at once when its output is already
# there (a satisfied trigger cannot fail later); an unsatisfied one inside its window waits.
unripe = {str(a[0]) for a in amended if a[2] + DEADLINE > now}

bad = batched("""
SELECT x.test, x.gate::text,
       CASE WHEN d.id IS NULL THEN 'no new version ' || ceil(extract(epoch FROM now() - x.gate))::bigint
                                   || ' s after the amendment'
            WHEN d.version = 1 THEN 'the amendment is version 1''s gate, no new version'
            WHEN d.published_at > x.gate + make_interval(secs => %(deadline)s::int)
                 THEN 'version ' || d.version || ' published '
                      || ceil(extract(epoch FROM d.published_at - x.gate))::bigint || ' s after the amendment'
            WHEN f.id IS NULL THEN 'version ' || d.version || ' has no version ' || (d.version - 1) || ' before it'
            ELSE 'version ' || (d.version - 1) || ' not superseded by version ' || d.version END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (test integer, gate timestamptz)
  LEFT JOIN LATERAL (SELECT * FROM portal_documents d
                      WHERE d.source_ref = 'T-' || x.test AND d.gated_at = x.gate
                      ORDER BY d.version DESC LIMIT 1) d ON true
  LEFT JOIN portal_documents f ON f.source_ref = d.source_ref AND f.version = d.version - 1
 WHERE d.id IS NULL OR d.version = 1 OR d.published_at > x.gate + make_interval(secs => %(deadline)s::int)
    OR f.id IS NULL OR f.superseded_at IS NULL
 ORDER BY x.gate, x.test
""", PORTAL, [{"test": t, "gate": text} for t, text, _ in amended], deadline=DEADLINE)
pending = {str(b[0]) for b in bad if str(b[0]) in unripe and b[2].startswith("no new version")}
bad = [b for b in bad if str(b[0]) not in pending]
ripe = [a for a in amended if str(a[0]) not in pending]

if bad:
    test, gate, how = bad[0]
    more = f" ({len(bad)} amendments {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: T-{test} amended at {gate}: {how}{more}")
    sys.exit(1)
if ripe:
    print(f"{INVARIANT} fixed: {len(ripe)} amendments of the centre's results {window}, each a new version "
          f"within {DEADLINE // 60} minutes, the former superseded ({len(amended) - len(ripe)} still within "
          f"their 15 minutes)")
    sys.exit(0)
if amended:
    first = min(amended, key=lambda a: a[2])
    later(first[2] + DEADLINE - now, f"T-{first[0]}'s amendment is still to be judged")
wait("publish-results", f"no result of the centre amended {window}")
PY
