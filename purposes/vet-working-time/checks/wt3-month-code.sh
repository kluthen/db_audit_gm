#!/bin/sh
# WT3 a month's figures equal the sum of its days, with the four months'
# average (vet-working-time; v0.5 master spec 12.1 item 6, 12.2 purpose 12;
# vet-scheduling-domain.md, purpose 12): a code invariant, the sealed check
# reading the month's code.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - The code: close-working-time's computation as the runner runs it (its key
#   in the loaded jobs.yaml, the SQL key its options' compute names in
#   queries.yaml), run read only on office for the last month office holds:
#   per staff member with a day in it, the month's worked and night hours and
#   call-outs summed from working_time_days, its breaches counted from
#   rest_breaches, and the weekly average of the hours worked over the month
#   and the three before it (their days divided by seven), to the hundredth.
# - The output of any close-working-time run since the judged moment, against
#   the same sums.
# - The planted months' own figures are not judged (a fix leaves them).
# - Exit 1: a staff member's month off the sums, missing or twice. Exit 0 the
#   code and any run since the judged moment as the sums. Exit 2: it cannot
#   judge (no month planted, the code unreadable).
#
# Written for the clinic's names (CLINIC and OFFICE below: the primary records,
# its databases clinic and office); the GM adapts them as it copies the
# purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "WT3"
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

JOB = "close-working-time"
entry, code = runner_code(JOB, "compute")
guard(OFFICE, ["working_time_days", "rest_breaches", "working_time_months", "runs"])
months = rows(OFFICE, "SELECT DISTINCT month::text FROM working_time_months ORDER BY 1")
if not months:
    cannot("office holds no month to run the code against")
SUMS = """
SELECT w.staff_id, sum(w.worked_hours), sum(w.night_hours), sum(w.call_outs),
       (SELECT count(*) FROM rest_breaches b WHERE b.staff_id = w.staff_id AND b.day >= %(month)s::date
           AND b.day < (%(month)s::date + interval '1 month')::date),
       round((SELECT sum(f.worked_hours) FROM working_time_days f WHERE f.staff_id = w.staff_id
                 AND f.day >= (%(month)s::date - interval '3 months')::date
                 AND f.day < (%(month)s::date + interval '1 month')::date) * 7
             / ((%(month)s::date + interval '1 month')::date - (%(month)s::date - interval '3 months')::date), 2)
  FROM working_time_days w
 WHERE w.day >= %(month)s::date AND w.day < (%(month)s::date + interval '1 month')::date GROUP BY w.staff_id"""


def values(r):
    return [Decimal(str(r[0])), Decimal(str(r[1])), int(r[2]), int(r[3]), Decimal(str(r[4]))]


def judge(month, got, label):
    expected = {r[0]: values(r[1:]) for r in rows(OFFICE, SUMS, month=month)}
    out, seen = [], {}
    for r in got:
        try:
            staff, figures = int(r[0]), values(r[2:7])
        except (TypeError, ValueError, IndexError):
            return [f"{label} for {month}: a row that is not (staff, name, worked, night, call-outs, breaches, "
                    "average)"]
        seen[staff] = seen.get(staff, 0) + 1
        if figures != expected.get(staff):
            out.append(f"{label} for {month}: staff {staff} {figures}, its days sum to {expected.get(staff)}")
    out += [f"{label} for {month}: staff {s} {seen.get(s, 0)} times" for s in expected if seen.get(s, 0) != 1]
    return out


month = months[-1][0]
problems = judge(month, rows(OFFICE, code, month=month), "the month's code")
placed = rows(OFFICE, """
SELECT r.id, (SELECT min(month)::text FROM working_time_months m WHERE m.run_id = r.id) FROM runs r
 WHERE r.job = %(job)s AND r.started_at >= to_timestamp(%(judged)s::float8)""", job=JOB, judged=judged)
for run_id, run_month in placed:
    if run_month:
        problems += judge(run_month, rows(OFFICE, "SELECT staff_id, staff_name, worked_hours, night_hours, call_outs,"
                                                  " breaches, average_weekly_hours FROM working_time_months"
                                                  " WHERE run_id = %(run)s::bigint", run=run_id),
                          f"run {run_id}'s month")
if problems:
    present(problems, window)
print(f"{INVARIANT} fixed: the month's code gives {month}'s figures as its days sum"
      f"{f', and {len(placed)} runs {window}' if placed else ''}")
sys.exit(0)
PY
