#!/bin/sh
# PR2 one delivery_key per delivery (vet-lab-practice-results, v0.5 master
# spec 12.2 purpose 2; clinic-purposes.md section 6): a delivery keeps its
# delivery_key across attempts; one key per order, kind and revision. Judged
# by runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs and the lab's
# lab_callbacks as gm_check with check-sql (capture W4 item 0).
#
# - The attempts posted since the judged moment (CHECK_SINCE raised to the
#   runner's last reload), the practices' orders' only.
# - Exit 1: a key used for two orders or two kinds; an order's interim or
#   final delivered under two keys, or its amendments under more keys than
#   it has amendments (every attempt of those orders read).
#   Exit 0: none, with an attempt since then (the witness). Exit 3 otherwise,
#   remaining= until the next run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "PR2"
LAB = ("lab", "lab")                 # the source and target parts: node, database
JOB = "deliver-practice-results"
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


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


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def num(text):
    return float(text) if text != "" else None


def next_run(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


def too_soon(seconds, why):
    print(f"remaining={max(1, int(seconds))} {why}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

n, bad, first = query(LAB, """
WITH c AS MATERIALIZED (
  SELECT cb.order_id, cb.kind, cb.delivery_key FROM lab_callbacks AS cb
    JOIN lab_orders AS o ON o.id = cb.order_id JOIN lab_accounts AS a ON a.id = o.account_id
   WHERE a.kind = 'practice' AND cb.posted_at > to_timestamp(%(judged)s::float8)),
bad AS (
  SELECT 'key ' || delivery_key || ' used for ' || string_agg(DISTINCT 'order ' || order_id || ' ' || kind, ', ')
         AS what
    FROM c GROUP BY delivery_key HAVING count(DISTINCT order_id || ':' || kind) > 1
  UNION ALL
  SELECT 'order ' || g.order_id || ' has its ' || g.kind || ' delivery under ' || g.n || ' keys'
    FROM (SELECT cb.order_id, cb.kind, count(DISTINCT cb.delivery_key) AS n FROM lab_callbacks AS cb
           WHERE (cb.order_id, cb.kind) IN (SELECT order_id, kind FROM c) GROUP BY cb.order_id, cb.kind) AS g
   WHERE g.n > CASE WHEN g.kind = 'amended'
                    THEN (SELECT count(*) FROM lab_results AS r JOIN lab_order_tests AS x ON x.id = r.order_test_id
                           WHERE x.order_id = g.order_id AND r.supersedes_id IS NOT NULL)
                    ELSE 1 END)
SELECT (SELECT count(*) FROM c), (SELECT count(*) FROM bad), coalesce((SELECT what FROM bad ORDER BY what LIMIT 1), '')
""", judged=judged)[0]
if int(bad):
    print(f"{INVARIANT} present: {first}" + (f" ({bad} keys or deliveries {window})" if int(bad) > 1 else ""))
    sys.exit(1)
if int(n):
    print(f"{INVARIANT} fixed: {n} delivery attempts {window}, each delivery under one key")
    sys.exit(0)
too_soon(next_run(JOB), f"no delivery attempted {window}")
PY
