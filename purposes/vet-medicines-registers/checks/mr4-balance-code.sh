#!/bin/sh
# MR4 a month's balance equals the previous closing less the month's
# movements, per batch (vet-medicines-registers; v0.5 master spec 12.1 item 6,
# 12.2 purpose 7; clinic-purposes.md 11): a code invariant, the sealed check
# reading the balance's code.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads the record (records/clinic) and office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - The code: balance-controlled-drugs' computation as the runner runs it (its
#   key in the loaded jobs.yaml, the SQL key its options' compute names in
#   queries.yaml), run read only on office for the last month office holds a
#   balance for, with the controlled batches as received. Each controlled
#   batch once: its opening the previous month's closing (the quantity
#   received when there is none), its movements the month's in
#   controlled_movements, its closing the opening less the movements.
# - The output of any balance-controlled-drugs run since the judged moment
#   (the 1st's, if the GM placed one), against the same rule.
# - The planted months' own figures are not judged: a fix to the code leaves
#   them as they are (the players recommend the rerun).
# - Exit 1: a batch's figures off the rule, missing or twice. Exit 0 the code
#   and any run since the judged moment as the rule. Exit 2: it cannot judge
#   (no month planted, the code unreadable).
#
# Written for the clinic's names (CLINIC and OFFICE below: the primary records,
# its databases clinic and office); the GM adapts them as it copies the
# purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MR4"
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
JOBS_YAML = "/srv/scheduler/jobs/jobs.yaml"
QUERIES_YAML = "/srv/scheduler/repository/queries.yaml"
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


def runs(job, since):
    """(start, end, rows) of each successful run of `job` ended after `since`."""
    out = []
    for line in helper([CHECK_RUNS, "runs", job, iso(since)]).splitlines():
        start, end, rows, ms = line.split()
        end = epoch(end)
        out.append((epoch(start) if start != "-" else end - float(ms[3:]) / 1000, end,
                    int(rows[5:])))
    return out


def query(db, text, **values):
    """One statement on db (node, database) as gm_check, its one row's one
    column read as JSON."""
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    out = helper(argv, text).strip()
    try:
        return json.loads(out)
    except ValueError:
        cannot(f"{db[0]}/{db[1]}: an answer that is not JSON: {out[:80]!r}")


def rows(db, text, **values):
    """A statement's rows, each the list of its column values in order (as
    JSON gives them), read as gm_check in a read-only transaction."""
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    out = helper(argv, "SELECT coalesce(json_agg(x), '[]')::text FROM (\n" + text.strip().rstrip(";")
                 + "\n) x").strip()
    try:
        return json.loads(out, object_pairs_hook=lambda pairs: [v for _, v in pairs])
    except ValueError:
        cannot(f"{db[0]}/{db[1]}: an answer that is not JSON: {out[:80]!r}")


def too_soon(job, why):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def present(problems, window):
    more = f" ({len(problems)} such {window})" if len(problems) > 1 else ""
    print(f"{INVARIANT} present: {problems[0]}{more}")
    sys.exit(1)


# The GM's read policy (spec D432): a table with row security is read only
# through gm_check_read; dropped, or a restrictive policy naming public or
# gm_check, every read would come back empty, so the check refuses to judge.
GUARD = """
SELECT coalesce(jsonb_agg(t ORDER BY t), '[]')::text FROM (
  SELECT c.oid::regclass::text AS t FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE c.oid = ANY (string_to_array(%(tables)s, ',')::regclass[]) AND c.relrowsecurity
     AND (NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                        AND p.policyname = 'gm_check_read')
          OR EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                       AND p.permissive = 'RESTRICTIVE' AND p.roles && ARRAY['public', 'gm_check']::name[]))) x
"""


def guard(db, tables):
    gone = query(db, GUARD, tables=",".join(tables))
    if gone:
        cannot(f"the GM's read policy on {gone[0]} is gone ({db[0]}/{db[1]})")


def local_days(db, starts):
    """[(start, day's lo, day's hi, day)]: each run's yesterday, the
    customer's local date (business_settings.timezone) before its start, and
    that day's bounds (epoch seconds)."""
    if not starts:
        return []
    return [(float(s), float(lo), float(hi), d) for s, lo, hi, d in query(db, """
SELECT coalesce(jsonb_agg(jsonb_build_array(s, extract(epoch FROM (d::timestamp AT TIME ZONE b.timezone)),
                                            extract(epoch FROM ((d + 1)::timestamp AT TIME ZONE b.timezone)), d)
                          ORDER BY s), '[]')::text
  FROM business_settings b,
       LATERAL (SELECT s, (to_timestamp(s) AT TIME ZONE b.timezone)::date - 1 AS d
                  FROM unnest(string_to_array(%(starts)s, ',')::float8[]) AS s) x
""", starts=",".join(str(s) for s in starts))]


def runner_code(job, option):
    """The loaded job's queries.yaml entry and the SQL of the key its option
    names: the job's code as the runner runs it."""
    try:
        import yaml
        with open(JOBS_YAML, encoding="utf-8") as fh:
            jobs = {j.get("name"): j for j in (yaml.safe_load(fh) or {}).get("jobs") or []}
        with open(QUERIES_YAML, encoding="utf-8") as fh:
            queries = (yaml.safe_load(fh) or {}).get("queries") or {}
    except (OSError, ImportError, ValueError) as exc:
        cannot(f"the runner's files cannot be read: {exc}")
    if job not in jobs:
        cannot(f"{job} is not in the loaded jobs.yaml")
    entry = queries.get(jobs[job].get("key"))
    if not isinstance(entry, dict) or not isinstance(entry.get("options"), dict):
        cannot(f"{job}'s key {jobs[job].get('key')} is not a script with options in queries.yaml")
    sql = (queries.get(entry["options"].get(option)) or {}).get("sql")
    if not isinstance(sql, str):
        cannot(f"{job}'s {option} key {entry['options'].get(option)} has no SQL in queries.yaml")
    return entry, sql


try:
    since = epoch(os.environ.get("CHECK_SINCE", ""))
except ValueError:
    cannot(f"CHECK_SINCE {os.environ.get('CHECK_SINCE', '')!r} is not YYYY-MM-DDTHH:MM:SSZ")
judged = epoch(helper([CHECK_RUNS, "since", iso(since)]).strip())
window = f"since {iso(judged)}"


CLINIC = ("records", "clinic")       # the source part (the primary; the job reads its standby)
OFFICE = ("records", "office")       # the target part

from decimal import Decimal

JOB = "balance-controlled-drugs"
entry, code = runner_code(JOB, "compute")
guard(CLINIC, ["medicine_batches", "medicines"])
guard(OFFICE, ["controlled_balances", "controlled_movements", "runs"])
months = rows(OFFICE, "SELECT DISTINCT month::text FROM controlled_balances ORDER BY 1")
if not months:
    cannot("office holds no month's balance to run the code against")
received = rows(CLINIC, "SELECT b.id, m.id, b.batch_number, b.quantity_received FROM medicine_batches b"
                        " JOIN medicines m ON m.id = b.medicine_id WHERE m.controlled ORDER BY b.id")
received = json.dumps({str(i): [m, n, str(q)] for i, m, n, q in received})
RULE = """
WITH received AS (
  SELECT key::integer AS batch_id, (value->>2)::numeric AS quantity FROM jsonb_each(%(received)s::jsonb)),
previous AS (SELECT batch_id, closing FROM controlled_balances WHERE month = (%(month)s::date - interval '1 month')::date),
moved AS (SELECT batch_id, sum(quantity) AS q FROM controlled_movements
           WHERE batch_id IS NOT NULL AND day >= %(month)s::date AND day < (%(month)s::date + interval '1 month')::date
           GROUP BY batch_id)
SELECT r.batch_id, coalesce(p.closing, r.quantity), coalesce(m.q, 0), coalesce(p.closing, r.quantity) - coalesce(m.q, 0)
  FROM received r LEFT JOIN previous p USING (batch_id) LEFT JOIN moved m USING (batch_id)
"""


def judge(month, got, label):
    expected = {r[0]: [Decimal(str(v)) for v in r[1:]] for r in rows(OFFICE, RULE, month=month, received=received)}
    out, seen = [], {}
    for r in got:
        try:
            batch, figures = int(r[1]), [Decimal(str(v)) for v in r[3:6]]
        except (TypeError, ValueError, IndexError):
            return [f"{label} for {month}: a row that is not (medicine, batch, number, opening, movements, closing)"]
        seen[batch] = seen.get(batch, 0) + 1
        if batch in expected and figures != expected[batch]:
            out.append(f"{label} for {month}: batch {batch} opening, movements, closing {figures[0]}, {figures[1]}, "
                       f"{figures[2]}; the rule gives {expected[batch][0]}, {expected[batch][1]}, {expected[batch][2]}")
    for batch in expected:
        if seen.get(batch, 0) != 1:
            out.append(f"{label} for {month}: batch {batch} {seen.get(batch, 0)} times")
    return out


month = months[-1][0]
problems = judge(month, rows(OFFICE, code, month=month, received=received), "the balance's code")
placed = rows(OFFICE, """
SELECT r.id, (SELECT min(month)::text FROM controlled_balances c WHERE c.run_id = r.id) FROM runs r
 WHERE r.job = %(job)s AND r.started_at >= to_timestamp(%(judged)s::float8)
""", job=JOB, judged=judged)
for run_id, run_month in placed:
    if run_month:
        problems += judge(run_month, rows(OFFICE, "SELECT medicine_id, batch_id, batch_number, opening, movements,"
                                                  " closing FROM controlled_balances WHERE run_id = %(run)s::bigint",
                                          run=run_id), f"run {run_id}'s balances")
if problems:
    present(problems, window)
print(f"{INVARIANT} fixed: the balance's code gives {month}'s balances as the rule"
      f"{f', and {len(placed)} runs {window}' if placed else ''}")
sys.exit(0)
PY
