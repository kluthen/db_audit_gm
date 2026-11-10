#!/bin/sh
# MR3 each day's movements of controlled medicines in the register once
# (vet-medicines-registers; v0.5 master spec 12.2 purpose 7; clinic-purposes.md
# 11): a runs invariant, on the runs of feed-controlled-drugs since the judged
# moment.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads the record (records/clinic) and office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - Each judged run's day: the customer's local date before the run's start.
#   Every dispensing and every dose given of a controlled medicine
#   (medicines.controlled) that day is in office's controlled_movements once,
#   its batch number and quantity the source's; no movement of the day that
#   is not one of them.
# - Exit 1: a movement missing, held twice or differing, or one of no
#   controlled supply. Exit 0: at least one judged day with a movement, none
#   failing. Exit 3 otherwise, remaining= until the feeder's next run. Exit 2:
#   it cannot judge.
#
# Written for the clinic's names (CLINIC and OFFICE below: the primary records,
# its databases clinic and office); the GM adapts them as it copies the
# purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "MR3"
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

def judged_days(job):
    """The distinct local days of `job`'s runs since the judged moment, with
    their bounds, and the runs counted."""
    found = runs(job, judged)
    seen, out = set(), []
    for start, lo, hi, day in local_days(CLINIC, [f[0] for f in found]):
        if day not in seen:
            seen.add(day)
            out.append((lo, hi, day))
    return found, out

from decimal import Decimal


def compare(day, source, held, what):
    """source and held: [kind, id, batch number, quantity]; each source item
    held once with its batch and quantity, nothing else held."""
    out, src = [], {(r[0], r[1]): r for r in source}
    count = {}
    for r in held:
        count[(r[0], r[1])] = count.get((r[0], r[1]), 0) + 1
        s = src.get((r[0], r[1]))
        if s is None:
            out.append(f"{day}: {r[0]} {r[1]} is in the register, not a {what} of the day")
        elif s[2] != r[2] or Decimal(str(s[3])) != Decimal(str(r[3])):
            out.append(f"{day}: {r[0]} {r[1]} held with batch {r[2]} and quantity {r[3]}, the source's {s[2]} and {s[3]}")
    for key in src:
        if count.get(key, 0) != 1:
            out.append(f"{day}: {key[0]} {key[1]} is in the register {count.get(key, 0)} times")
    return out

JOB = "feed-controlled-drugs"
guard(CLINIC, ["business_settings", "dispensings", "administrations", "medicines", "medicine_batches",
               "prescription_lines"])
guard(OFFICE, ["controlled_movements"])
feeds, days = judged_days(JOB)
problems, witnessed = [], 0
for lo, hi, day in days:
    source = rows(CLINIC, """
SELECT 'dispensing', d.id, b.batch_number, d.quantity FROM dispensings d
  JOIN prescription_lines l ON l.id = d.prescription_line_id JOIN medicines m ON m.id = l.medicine_id
  JOIN medicine_batches b ON b.id = d.batch_id
 WHERE m.controlled AND d.dispensed_at >= to_timestamp(%(lo)s::float8) AND d.dispensed_at < to_timestamp(%(hi)s::float8)
UNION ALL
SELECT 'administration', a.id, b.batch_number, a.quantity FROM administrations a JOIN medicines m ON m.id = a.medicine_id
  LEFT JOIN medicine_batches b ON b.id = a.batch_id
 WHERE m.controlled AND a.state = 'given' AND a.given_at >= to_timestamp(%(lo)s::float8)
   AND a.given_at < to_timestamp(%(hi)s::float8)
""", lo=lo, hi=hi)
    held = rows(OFFICE, "SELECT movement, movement_id, batch_number, quantity FROM controlled_movements"
                        " WHERE day = %(day)s::date", day=day)
    problems += compare(day, source, held, "controlled movement")
    witnessed += 1 if source else 0
if problems:
    present(problems, window)
if witnessed:
    print(f"{INVARIANT} fixed: {len(feeds)} runs of {JOB} {window}, every controlled movement of their {witnessed} "
          "days in the register once, as the source's")
    sys.exit(0)
too_soon(JOB, f"{len(feeds)} runs of {JOB} {window}, none after a day with a controlled movement")
PY
