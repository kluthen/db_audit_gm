#!/bin/sh
# ND5 every notification of yesterday in office's copies, once
# (vet-notifiable-diseases; v0.5 master spec 11.3, 12.2 purpose 5;
# clinic-purposes.md 9): a runs invariant, on the runs of
# copy-notifications since the judged moment.
#
# Runs on the runner node (the report runner (backoffice; in fixture-exchanges interfaces)) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic), the lab (lab/lab) and office (records/office) as gm_check with
# check-sql; it never runs a job and never calls the authority. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - Each judged run's yesterday: the customer's local date
#   (business_settings.timezone) before the run's start. Every notification
#   of both databases first sent that day is in office's
#   regulatory_submissions (kind notifiable-disease, ref its key) exactly
#   once; and no key copied twice since the judged moment.
# - Exit 1: a notification of a judged day missing or copied twice. Exit 0:
#   at least one judged run after a day that had a notification, none
#   failing. Exit 3 otherwise, remaining= until copy-notifications' next
#   run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ND5"
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta, timezone

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


def too_soon(job, why):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


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


try:
    since = epoch(os.environ.get("CHECK_SINCE", ""))
except ValueError:
    cannot(f"CHECK_SINCE {os.environ.get('CHECK_SINCE', '')!r} is not YYYY-MM-DDTHH:MM:SSZ")
judged = epoch(helper([CHECK_RUNS, "since", iso(since)]).strip())
window = f"since {iso(judged)}"


CLINIC = ("records", "clinic")       # the source part: node, database
LAB = ("lab", "lab")                 # the source_lab part
OFFICE = ("records", "office")       # the target part
JOB = "copy-notifications"
KIND = "notifiable-disease"

guard(CLINIC, ["business_settings", "ops.notifications"])
guard(LAB, ["ops.notifications"])
guard(OFFICE, ["regulatory_submissions"])
copies = runs(JOB, judged)
# Each judged run's yesterday: the customer's local date before the run's.
days = query(CLINIC, """
SELECT coalesce(jsonb_agg(jsonb_build_array(s, extract(epoch FROM (d::timestamp AT TIME ZONE b.timezone)),
                                            extract(epoch FROM ((d + 1)::timestamp AT TIME ZONE b.timezone)), d)
                          ORDER BY s), '[]')::text
  FROM business_settings b,
       LATERAL (SELECT s, (to_timestamp(s) AT TIME ZONE b.timezone)::date - 1 AS d
                  FROM unnest(string_to_array(%(starts)s, ',')::float8[]) AS s) x
""", starts=",".join(str(c[0]) for c in copies)) if copies else []
lo = min((float(d[1]) for d in days), default=judged)
hi = max((float(d[2]) for d in days), default=judged)
SENT = """
SELECT coalesce(jsonb_agg(jsonb_build_array(notification_key, extract(epoch FROM first_sent_at)) ORDER BY id),
                '[]')::text
  FROM ops.notifications WHERE first_sent_at >= to_timestamp(%(lo)s::float8) AND first_sent_at < to_timestamp(%(hi)s::float8)
"""
sent = query(CLINIC, SENT, lo=lo, hi=hi) + query(LAB, SENT, lo=lo, hi=hi)
office = query(OFFICE, """
SELECT jsonb_build_object(
  'count', coalesce((SELECT jsonb_object_agg(ref, n) FROM (SELECT ref, count(*) AS n FROM regulatory_submissions
                       WHERE kind = %(kind)s AND ref = ANY (string_to_array(%(keys)s, ','))
                       GROUP BY ref) x), '{}'),
  'twice', coalesce((SELECT jsonb_agg(ref) FROM (SELECT ref FROM regulatory_submissions WHERE kind = %(kind)s
                       GROUP BY ref HAVING count(*) > 1 AND max(copied_at) > to_timestamp(%(judged)s::float8)) x), '[]')
)::text
""", kind=KIND, keys=",".join(k for k, _ in sent), judged=judged)

wrong = [f"notification {ref} is in office's copies more than once" for ref in office["twice"]]
witnessed = 0
for start, day_lo, day_hi, day in days:
    keys = [k for k, at in sent if float(day_lo) <= float(at) < float(day_hi)]
    witnessed += 1 if keys else 0
    for key in keys:
        n = office["count"].get(key, 0)
        if n != 1:
            wrong.append(f"notification {key} of {day} is in office's copies {n} times after the copy of "
                         f"{iso(float(start))}")
if wrong:
    more = f" ({len(wrong)} such {window})" if len(wrong) > 1 else ""
    print(f"{INVARIANT} present: {wrong[0]}{more}")
    sys.exit(1)
if witnessed:
    print(f"{INVARIANT} fixed: {len(copies)} runs of {JOB} {window}, every notification of the day before each in "
          f"office's copies once ({len(sent)} notifications over {witnessed} days that had one)")
    sys.exit(0)
too_soon(JOB, f"{len(copies)} runs of {JOB} {window}, none after a day with a notification")
PY
