#!/bin/sh
# HO2 one row per day, section and measure (vet-head-office-figures; v0.5
# master spec 12.2 purpose 9; clinic-purposes.md 13): a runs invariant, on the
# runs of feed-daily-figures since the judged moment.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads the record (records/clinic), the lab (lab/lab) and office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - The grid: each section of the centre (its kind) by the record's and
#   housing's nine measures (the consultations of each of the four kinds,
#   admissions, discharges, the stays, the units occupied and in service at
#   midnight); the centre's new owners and animals; the lab's tests of each
#   discipline of its catalogue and each priority, its outside orders, their
#   median turnaround.
# - Each judged run's day (the customer's local date before the run's start):
#   office's daily_figures holds exactly one row for each of the grid's
#   section and measure, and none other.
# - Exit 1: a row missing, held twice or of no such section and measure.
#   Exit 0: at least one judged day, none failing. Exit 3 otherwise,
#   remaining= until the feeder's next run. Exit 2: it cannot judge.
#
# Written for the clinic's names: CLINIC, LAB and OFFICE below, the primary records'
# databases clinic and office, and the lab's node and database.
# The GM adapts them as it copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "HO2"
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
LAB = ("lab", "lab")                 # the source_lab part
OFFICE = ("records", "office")       # the target part

from decimal import Decimal, ROUND_HALF_UP


def num(v):
    """A figure as compared: None, or a Decimal to the cent."""
    return None if v is None else Decimal(str(v)).quantize(Decimal("0.01"), ROUND_HALF_UP)

def judged_days(job, db=None, settings="business_settings"):
    """The distinct local days of `job`'s runs since the judged moment, with
    their bounds (each run's yesterday in the customer's zone, read from
    `settings` on `db`), and the runs counted."""
    found = runs(job, judged)
    if not found:
        return found, []
    seen, out = set(), []
    for lo, hi, day in query(db or CLINIC, """
SELECT coalesce(jsonb_agg(jsonb_build_array(extract(epoch FROM (d::timestamp AT TIME ZONE b.timezone)),
                                            extract(epoch FROM ((d + 1)::timestamp AT TIME ZONE b.timezone)), d)
                          ORDER BY s), '[]')::text
  FROM """ + settings + """ b,
       LATERAL (SELECT s, (to_timestamp(s) AT TIME ZONE b.timezone)::date - 1 AS d
                  FROM unnest(string_to_array(%(starts)s, ',')::float8[]) AS s) x
""", starts=",".join(str(f[0]) for f in found)):
        if day not in seen:
            seen.add(day)
            out.append((float(lo), float(hi), day))
    return found, out

CLINIC_FIGURES = """
WITH sec AS (SELECT sc.id, sc.kind FROM sections sc JOIN sites si ON si.id = sc.site_id WHERE si.kind = 'own'),
lo AS (SELECT to_timestamp(%(lo)s::float8) AS lo, to_timestamp(%(hi)s::float8) AS hi)
SELECT sec.kind, m.measure, CASE m.measure
  WHEN 'admissions' THEN (SELECT count(*) FROM stays x WHERE x.section_id = sec.id AND x.admitted_at >= lo AND x.admitted_at < hi)
  WHEN 'discharges' THEN (SELECT count(*) FROM stays x WHERE x.section_id = sec.id AND x.discharged_at >= lo
                             AND x.discharged_at < hi)
  WHEN 'stays.midnight' THEN (SELECT count(*) FROM stays x WHERE x.section_id = sec.id AND x.admitted_at < hi
                                 AND (x.discharged_at IS NULL OR x.discharged_at >= hi))
  WHEN 'units.occupied' THEN (SELECT count(*) FROM housing_placements p JOIN housing_units u ON u.id = p.unit_id
                               WHERE u.section_id = sec.id AND p.from_at < hi AND (p.until_at IS NULL OR p.until_at >= hi))
  WHEN 'units.in-service' THEN (SELECT count(*) FROM housing_units u WHERE u.section_id = sec.id
                                   AND NOT (u.state = 'out-of-service' AND u.state_since_at <= hi))
  ELSE (SELECT count(*) FROM consultations x WHERE x.section_id = sec.id AND 'consultations.' || x.kind = m.measure
           AND x.started_at >= lo AND x.started_at < hi) END
  FROM sec CROSS JOIN lo CROSS JOIN (VALUES ('consultations.scheduled'), ('consultations.emergency'),
       ('consultations.herd-visit'), ('consultations.in-hospital'), ('admissions'), ('discharges'), ('stays.midnight'),
       ('units.occupied'), ('units.in-service')) m (measure)
UNION ALL
SELECT 'centre', 'owners.new', count(*) FROM owners, lo WHERE registered_at >= lo AND registered_at < hi
UNION ALL
SELECT 'centre', 'animals.new', count(*) FROM animals, lo WHERE registered_at >= lo AND registered_at < hi"""
LAB_FIGURES = """
WITH lo AS (SELECT to_timestamp(%(lo)s::float8) AS lo, to_timestamp(%(hi)s::float8) AS hi),
grid AS (SELECT DISTINCT t.discipline, p.priority FROM lab_tests t CROSS JOIN (VALUES ('routine'), ('urgent')) p (priority))
SELECT 'lab', 'tests.' || g.discipline || '.' || g.priority,
       (SELECT count(*) FROM lab_order_tests ot JOIN lab_orders o ON o.id = ot.order_id JOIN lab_tests t ON t.id = ot.test_id
         WHERE t.discipline = g.discipline AND o.priority = g.priority AND ot.released_at >= lo AND ot.released_at < hi)
  FROM grid g, lo
UNION ALL
SELECT 'lab', 'orders.outside', count(*) FROM lab_orders o JOIN lab_accounts a ON a.id = o.account_id, lo
 WHERE a.kind = 'practice' AND o.ordered_at >= lo AND o.ordered_at < hi
UNION ALL
SELECT 'lab', 'turnaround.outside.median-minutes',
       round((percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM ot.released_at - o.received_at) / 60))::numeric, 2)
  FROM lab_order_tests ot JOIN lab_orders o ON o.id = ot.order_id JOIN lab_accounts a ON a.id = o.account_id, lo
 WHERE a.kind = 'practice' AND ot.status = 'released' AND ot.released_at >= lo AND ot.released_at < hi
   AND o.received_at IS NOT NULL"""
CLINIC_TABLES = ["business_settings", "sites", "sections", "consultations", "stays", "owners", "animals",
                 "housing_units", "housing_placements"]
LAB_TABLES = ["lab_tests", "lab_orders", "lab_order_tests", "lab_accounts"]

JOB = "feed-daily-figures"
guard(CLINIC, ["business_settings", "sites", "sections"])
guard(LAB, ["lab_tests"])
guard(OFFICE, ["daily_figures"])
feeds, days = judged_days(JOB)
grid = {(r[0], r[1]) for r in rows(CLINIC, """
SELECT sc.kind, m.measure FROM sections sc JOIN sites si ON si.id = sc.site_id
 CROSS JOIN (VALUES ('consultations.scheduled'), ('consultations.emergency'), ('consultations.herd-visit'),
                    ('consultations.in-hospital'), ('admissions'), ('discharges'), ('stays.midnight'),
                    ('units.occupied'), ('units.in-service')) m (measure)
 WHERE si.kind = 'own'
UNION ALL VALUES ('centre', 'owners.new'), ('centre', 'animals.new')""")}
grid |= {("lab", r[0]) for r in rows(LAB, """
SELECT DISTINCT 'tests.' || t.discipline || '.' || p.priority FROM lab_tests t CROSS JOIN (VALUES ('routine'), ('urgent')) p (priority)
UNION ALL VALUES ('orders.outside'), ('turnaround.outside.median-minutes')""")}
problems = []
for lo, hi, day in days:
    count = {}
    for section, measure in rows(OFFICE, "SELECT section, measure FROM daily_figures WHERE day = %(day)s::date", day=day):
        count[(section, measure)] = count.get((section, measure), 0) + 1
    problems += [f"{day}: {k[0]} {k[1]} held {count.get(k, 0)} times" for k in sorted(grid) if count.get(k, 0) != 1]
    problems += [f"{day}: a row for {k[0]} {k[1]}, no such section and measure" for k in sorted(count) if k not in grid]
if problems:
    present(problems, window)
if days:
    print(f"{INVARIANT} fixed: {len(feeds)} runs of {JOB} {window}, each of their {len(days)} days one row for each of "
          f"the {len(grid)} sections and measures")
    sys.exit(0)
too_soon(JOB, f"no run of {JOB} {window}")
PY
