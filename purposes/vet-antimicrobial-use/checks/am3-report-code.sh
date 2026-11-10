#!/bin/sh
# AM3 the yearly report covers the species due at its date and sums its
# year's daily rows (vet-antimicrobial-use; v0.5 master spec 12.1 item 6, 12.2
# purpose 8; clinic-purposes.md 12): a code invariant, the sealed check reading
# the report's code.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - The code: report-antimicrobial-use as the runner runs it (its key in the
#   loaded jobs.yaml; in queries.yaml its options' due species and the SQL key
#   its compute names). For the last year office holds a report for (else the
#   year before the current one), sent on 15 January after it: the species the
#   code takes as due are the rule's (core rule 4, game values: cattle from
#   2024; sheep, goats and horses from 1 July 2027; dogs and cats from 1 July
#   2030), and its computation, run read only on office, gives per species and
#   ATCvet code the sums of that year's daily rows.
# - The payload of any report sent since the judged moment (a January run the
#   GM placed), against the same sums.
# - The planted reports' own figures are not judged (a fix leaves them).
# - Exit 1: a species due left out or one not due taken, or a sum off. Exit 0
#   the code and any report since the judged moment as the rule. Exit 2: it
#   cannot judge (the code unreadable).
#
# Written for the clinic's names (CLINIC and OFFICE below: the primary records,
# its databases clinic and office); the GM adapts them as it copies the
# purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "AM3"
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

from datetime import date
from decimal import Decimal

JOB = "report-antimicrobial-use"
RULE = {"cattle": date(2024, 1, 1), "sheep": date(2027, 7, 1), "goat": date(2027, 7, 1), "horse": date(2027, 7, 1),
        "dog": date(2030, 7, 1), "cat": date(2030, 7, 1)}
entry, code = runner_code(JOB, "compute")
guard(OFFICE, ["amu_reports", "antimicrobial_use", "runs"])
years = rows(OFFICE, "SELECT DISTINCT extract(year FROM year)::int FROM amu_reports ORDER BY 1")
year = years[-1][0] if years else datetime.now(timezone.utc).year - 1
sent = date(year + 1, 1, 15)
due = sorted(s for s, since in RULE.items() if since <= sent)
try:
    taken = sorted(s for s, since in (entry["options"].get("due") or {}).items()
                   if date.fromisoformat(str(since)) <= sent)
except (AttributeError, ValueError):
    taken = None
problems = []
if taken != due:
    problems.append(f"the report's code takes {taken} as due on {sent}; the species due are {due}")
SUMS = """
SELECT species, atcvet_code, sum(administrations), sum(dispensings), sum(quantity), sum(animals_treated),
       sum(herds_treated)
  FROM antimicrobial_use
 WHERE day >= %(year)s::date AND day < (%(year)s::date + interval '1 year')::date
   AND species = ANY (string_to_array(%(species)s, ',')) GROUP BY 1, 2"""


def figures(r):
    return [int(r[0]), int(r[1]), Decimal(str(r[2])).quantize(Decimal("0.01")), int(r[3]), int(r[4])]


def judge(got, label, y):
    expected = {(r[0], r[1]): figures(r[2:]) for r in rows(OFFICE, SUMS, year=f"{y}-01-01", species=",".join(due))}
    out, seen = [], {}
    for r in got:
        try:
            key, values = (r[0], r[1]), figures(r[2:7])
        except (TypeError, ValueError, IndexError):
            return [f"{label} for {y}: a row that is not (species, ATCvet code, doses, dispensings, quantity, "
                    "animals, herds)"]
        seen[key] = seen.get(key, 0) + 1
        if key not in expected or values != expected[key]:
            out.append(f"{label} for {y}: {key[0]} {key[1]} {values}, the year's daily rows sum to "
                       f"{expected.get(key)}")
    out += [f"{label} for {y}: {k[0]} {k[1]} {seen.get(k, 0)} times" for k in expected if seen.get(k, 0) != 1]
    return out


problems += judge(rows(OFFICE, code, year=f"{year}-01-01", species="{" + ",".join(due) + "}"),
                  "the report's code", year)
placed = rows(OFFICE, """
SELECT extract(year FROM a.year)::int, a.species, a.payload->'lines' FROM amu_reports a JOIN runs r ON r.id = a.run_id
 WHERE r.started_at >= to_timestamp(%(judged)s::float8)""", judged=judged)
for y, species, lines in placed:
    got = [[species, ln.get("atcvet_code"), ln.get("administrations"), ln.get("dispensings"), ln.get("quantity"),
            ln.get("animals_treated"), ln.get("herds_treated")] for ln in (lines or [])]
    problems += [p for p in judge(got, f"the {species} report sent {window}", y) if f" {species} " in p
                 or "a row" in p]
if problems:
    present(problems, window)
print(f"{INVARIANT} fixed: the report's code covers {', '.join(due)} for {year} and sums its daily rows"
      f"{f', as do the {len(placed)} reports sent {window}' if placed else ''}")
sys.exit(0)
PY
