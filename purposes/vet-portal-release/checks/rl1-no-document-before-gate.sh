#!/bin/sh
# RL1 no document before its gate (vet-portal-release, purpose 15;
# vet-portal-domain.md, "vet-portal-release"): every document published since
# the judged moment has its gate passed at or before its published_at, read in
# the source: a C-<id> its consultation signed (state signed, signed_at), an
# S-<id> its stay ended (discharged_at), a T-<id> version 1 its lab order test
# released (released_at), a later version its test released and its gated_at
# an amendment of the test's results (lab_results' amended_at), both at or
# before published_at. Judges runs (the results published at their technical
# validation, before the pathologist's release; a consultation published
# closed but unsigned).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal,
# clinic and lab are read as gm_check with check-sql, portal's tables through
# the GM's read policy gm_check_read (spec D432: no verdict when it is gone or
# a restrictive policy hides rows); no job is ever run. Exit 0 fixed (with its
# witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=). Written
# for the clinic's names (the constants below); the GM adapts them as it
# copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "RL1"
PORTAL = ("records", "portal")       # the target part: node, database
CLINIC = ("records", "clinic")       # the source part
LAB = ("lab", "lab")                 # the source_lab part
PURPOSE = "vet-portal-release"
import json
import os
import re
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


guard(["portal_documents"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

docs = query("""
SELECT id, source_ref, version, published_at::text, gated_at::text FROM portal_documents
 WHERE published_at > to_timestamp(%(judged)s::float8)
 ORDER BY published_at, id
""", PORTAL, judged=judged)
if not docs:
    wait("publish-records", f"no document published {window}")

kinds = {"C": [], "S": [], "T": []}
bad = []
for did, ref, version, pub, gated in docs:
    m = re.fullmatch(r"([CST])-([0-9]+)", ref)
    if not m:
        bad.append((int(did), ref, "its source_ref names no gate (C-, S- or T- and an id)"))
        continue
    kinds[m.group(1)].append({"id": int(did), "src": int(m.group(2)), "version": int(version),
                              "pub": pub, "gated": gated})

bad += [(int(d), r, how) for d, r, how in batched("""
SELECT x.id, 'C-' || x.src,
       CASE WHEN c.id IS NULL THEN 'its consultation is not in the record'
            WHEN c.state <> 'signed' OR c.signed_at IS NULL THEN 'its consultation is ' || c.state || ', not signed'
            ELSE 'published ' || ceil(extract(epoch FROM c.signed_at - x.pub))::bigint
                 || ' s before its consultation was signed' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (id integer, src integer, pub timestamptz)
  LEFT JOIN consultations c ON c.id = x.src
 WHERE c.id IS NULL OR c.state <> 'signed' OR c.signed_at IS NULL OR c.signed_at > x.pub
""", CLINIC, kinds["C"])]
bad += [(int(d), r, how) for d, r, how in batched("""
SELECT x.id, 'S-' || x.src,
       CASE WHEN s.id IS NULL THEN 'its stay is not in the record'
            WHEN s.discharged_at IS NULL THEN 'its stay has not ended'
            ELSE 'published ' || ceil(extract(epoch FROM s.discharged_at - x.pub))::bigint
                 || ' s before its stay ended' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (id integer, src integer, pub timestamptz)
  LEFT JOIN stays s ON s.id = x.src
 WHERE s.id IS NULL OR s.discharged_at IS NULL OR s.discharged_at > x.pub
""", CLINIC, kinds["S"])]
bad += [(int(d), r, how) for d, r, how in batched("""
SELECT x.id, 'T-' || x.src,
       CASE WHEN t.id IS NULL THEN 'its test is not in the lab'
            WHEN t.released_at IS NULL THEN 'its test is not released (' || t.status || ')'
            WHEN t.released_at > x.pub
                 THEN 'published ' || ceil(extract(epoch FROM t.released_at - x.pub))::bigint
                      || ' s before its test was released'
            WHEN x.gated > x.pub THEN 'version ' || x.version || ' published before its amendment'
            ELSE 'version ' || x.version || '''s gated_at is no amendment of its test''s results' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (id integer, src integer, version integer, pub timestamptz,
                                                  gated timestamptz)
  LEFT JOIN lab_order_tests t ON t.id = x.src
 WHERE t.id IS NULL OR t.released_at IS NULL OR t.released_at > x.pub
    OR (x.version > 1 AND (x.gated > x.pub
                           OR NOT EXISTS (SELECT 1 FROM lab_results r
                                           WHERE r.order_test_id = t.id AND r.supersedes_id IS NOT NULL
                                             AND r.amended_at = x.gated)))
""", LAB, kinds["T"])]

if bad:
    bad.sort()
    did, ref, how = bad[0]
    more = f" ({len(bad)} documents published {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: document {did} ({ref}): {how}{more}")
    sys.exit(1)
print(f"{INVARIANT} fixed: {len(docs)} documents published {window} ({len(kinds['C'])} consultations, "
      f"{len(kinds['S'])} discharges, {len(kinds['T'])} results), each after its gate")
sys.exit(0)
PY
