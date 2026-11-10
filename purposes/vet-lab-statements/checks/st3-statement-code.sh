#!/bin/sh
# ST3 a statement equals its month's billable charges less voids, with
# its bracket's discount (vet-lab-statements; v0.5 master spec 12.1 item 6, 12.2
# purpose 10; clinic-purposes.md 14; vet-lab rule 13): a code invariant, the
# sealed check reading the statement's code.
#
# Runs on the runner node (the report runner, backoffice) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged
# moment to the runner's last reload (check-runs since) and reads office (records/office) as
# gm_check with check-sql (read only); it never runs a job. A table read with
# row security needs the GM's read policy (spec D432): gone, the check exits 2.
#
# - The rule (game values): per practice account with lines in the month, the
#   billable lines and their sum, less the month's voids of charges stated
#   (made billable by the month's end); the bracket by that total, 3 % from
#   0, 5 % from 200, 10 % from 400, 15 % from 600; the discount on the
#   total, rounded once to the cent; the amount due the total less it.
# - The code: close-lab-statements as the runner runs it (its key in the
#   loaded jobs.yaml, the SQL key its compute names in queries.yaml), run read
#   only on office for the last month office holds statements for, against
#   the rule; and the statements of any month written since the judged moment
#   (a run the GM placed on the 1st).
# - The planted statements' own figures are not judged (a fix leaves them).
# - Exit 1: an account left out or twice, a figure off. Exit 0: the code and
#   any statement since the judged moment as the rule. Exit 2: it cannot
#   judge (the code unreadable, no lines).
#
# Written for the clinic's names: LAB and OFFICE below, the lab's node and database,
# and the primary records' database office.
# The GM adapts them as it copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ST3"
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


LAB = ("lab", "lab")                 # the source part (the lab's only node)
OFFICE = ("records", "office")       # the target part

from decimal import Decimal, ROUND_HALF_UP


def num(v):
    """A figure as compared: None, or a Decimal to the cent."""
    return None if v is None else Decimal(str(v)).quantize(Decimal("0.01"), ROUND_HALF_UP)

JOB = "close-lab-statements"
BRACKETS = [(Decimal(0), 3), (Decimal(200), 5), (Decimal(400), 10), (Decimal(600), 15)]
entry, code = runner_code(JOB, "compute")
guard(OFFICE, ["lab_charge_lines", "lab_statements", "runs"])


def rule(month):
    stated_voids = {r[0] for r in rows(OFFICE, """
SELECT DISTINCT v.charge_id FROM lab_charge_lines v
 WHERE v.event = 'void' AND v.day >= %(month)s::date AND v.day < (%(month)s::date + interval '1 month')::date
   AND EXISTS (SELECT 1 FROM lab_charge_lines p WHERE p.charge_id = v.charge_id AND p.event = 'billable'
                  AND p.day < (%(month)s::date + interval '1 month')::date)""", month=month)}
    acc = {}
    for account, event, amount, charge in rows(OFFICE, """
SELECT account_id, event, amount, charge_id FROM lab_charge_lines
 WHERE day >= %(month)s::date AND day < (%(month)s::date + interval '1 month')::date""", month=month):
        a = acc.setdefault(account, [0, Decimal("0.00"), Decimal("0.00")])
        if event == "billable":
            a[0] += 1
            a[1] += num(amount)
        elif charge in stated_voids:
            a[2] += num(amount)
    out = {}
    for account, (lines, billable, voided) in acc.items():
        total = billable - voided
        pct = max(p for t, p in BRACKETS if t <= max(total, Decimal(0)))
        discount = num(total * pct / 100)
        out[account] = [lines, billable, voided, total, pct, discount, total - discount]
    return out


def judge(month, got, label):
    expected = rule(month)
    out, seen = [], {}
    for r in got:
        try:
            account, figures = int(r[0]), [int(r[1]), num(r[2]), num(r[3]), num(r[4]), int(r[5]), num(r[6]), num(r[7])]
        except (TypeError, ValueError, IndexError, ArithmeticError):
            return [f"{label} for {month}: a row that is not (account, lines, billable, voided, total, %, discount, due)"]
        seen[account] = seen.get(account, 0) + 1
        if account not in expected or figures != expected[account]:
            out.append(f"{label} for {month}: account {account} {[str(f) for f in figures]}; the rule gives "
                       f"{[str(f) for f in expected.get(account, [])]} (lines, billable, voided, total, %, discount, due)")
    out += [f"{label} for {month}: account {a} {seen.get(a, 0)} times" for a in sorted(expected) if seen.get(a, 0) != 1]
    return out


month = query(OFFICE, """
SELECT to_jsonb(coalesce((SELECT max(month) FROM lab_statements),
                         (SELECT (date_trunc('month', max(day)) - interval '1 month')::date FROM lab_charge_lines)))::text""")
if month is None:
    cannot("office holds no charge lines to state")
problems = judge(month, rows(OFFICE, code, month=month), "the statement's code")
placed = rows(OFFICE, """
SELECT DISTINCT s.month::text FROM lab_statements s JOIN runs r ON r.id = s.run_id
 WHERE r.job = %(job)s AND r.started_at >= to_timestamp(%(judged)s::float8)""", job=JOB, judged=judged)
for (sent,) in placed:
    problems += judge(sent, rows(OFFICE, """
SELECT account_id, lines, billable, voided, total, discount_pct, discount, due FROM lab_statements
 WHERE month = %(month)s::date""", month=sent), f"the statements written {window}")
if problems:
    present(problems, window)
print(f"{INVARIANT} fixed: the statement's code gives {month}'s statements as the rule"
      f"{f', and the {len(placed)} months written {window}' if placed else ''}")
sys.exit(0)
PY
