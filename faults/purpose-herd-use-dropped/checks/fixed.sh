#!/bin/sh
# Sealed check of purpose-herd-use-dropped (v0.5 master spec 17.2 s3, 17.3;
# vet-antimicrobial-use, clinic-purposes.md 12, AM2's rule; capture W5 item 3
# of specs/versions/v0.5/wave-log.md): each day the antimicrobial feeder wrote
# since the judged moment counts every herd treatment of that day under its
# herd's species. Judged by runs.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the days tolerated, 0
# by the answer key's default), FAULT_SOURCE (the record, <node>/<database>:
# the primary; the feeder reads its standby), FAULT_TARGET (office,
# <node>/<database>) and FAULT_JOB (the feeder). It raises the judged moment
# to the runner's last reload (check-runs since), reads the feeder's runs with
# check-runs and both databases as gm_check with check-sql (read only); it
# never runs a job. A table read with row security needs the GM's read
# policy (spec D432): gone, the check exits 2.
#
# - A day judged: the customer's local date before a run of the feeder since
#   the judged moment (its yesterday).
# - A violation: a day whose herd treatments (antimicrobial dispensings on a
#   prescription to a herd) are not all counted in the target's
#   antimicrobial_use under the herd's species (a herd's animals' species)
#   and ATCvet code: fewer dispensings or herds than the record holds.
# Exit 1: more violating days than the threshold, naming the first. Exit 0:
# none beyond it, with a judged day holding a herd treatment (the witness;
# herd visits fall on Tuesdays and Thursdays in the clinic). Exit 3
# otherwise, remaining= until the feeder's next run. Exit 2: it cannot judge.
# The planted past (last year's report, rewritten short) is never judged:
# its rerun is the players' to recommend (spec D277).
exec /usr/bin/python3 -I - <<'PY'
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"the herd treatments cannot be judged: {text}")
    sys.exit(2)


def part(name, default):
    value = os.environ.get(name) or default
    node, _, db = value.partition("/")
    if not (node and db) or "/" in db:
        cannot(f"{name} is {value!r}, not <node>/<database>")
    return node, db


SOURCE = part("FAULT_SOURCE", "records/clinic")
TARGET = part("FAULT_TARGET", "records/office")
JOB = os.environ.get("FAULT_JOB") or "feed-antimicrobial-use"
try:
    THRESHOLD = int(os.environ.get("CHECK_THRESHOLD", "0") or "0")
except ValueError:
    cannot(f"CHECK_THRESHOLD is {os.environ.get('CHECK_THRESHOLD')!r}, not an integer")


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def rows(db, text, **values):
    """A statement's rows, each the list of its column values in order, read
    as gm_check (check-sql) as one JSON value."""
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    out = helper(argv, "SELECT coalesce(json_agg(x), '[]')::text FROM (\n" + text.strip().rstrip(";")
                 + "\n) x").strip()
    try:
        return json.loads(out, object_pairs_hook=lambda pairs: [v for _, v in pairs])
    except ValueError:
        cannot(f"{db[0]}/{db[1]}: an answer that is not JSON: {out[:80]!r}")


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


# The GM's read policy (spec D432): a table with row security is read only
# through gm_check_read; dropped, or a restrictive policy naming public or
# gm_check, every read would come back empty, so the check refuses to judge.
GUARD = """
SELECT c.oid::regclass::text FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.oid = ANY (string_to_array(%(tables)s, ',')::regclass[]) AND c.relrowsecurity
   AND (NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                      AND p.policyname = 'gm_check_read')
        OR EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                     AND p.permissive = 'RESTRICTIVE' AND p.roles && ARRAY['public', 'gm_check']::name[]))
"""


def guard(db, tables):
    gone = rows(db, GUARD, tables=",".join(tables))
    if gone:
        cannot(f"the GM's read policy on {gone[0][0]} is gone ({db[0]}/{db[1]})")


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

starts = []
for line in helper([CHECK_RUNS, "runs", JOB, iso(judged)]).splitlines():
    start, end, _rows, ms = line.split()
    starts.append(epoch(start) if start != "-" else epoch(end) - float(ms[3:]) / 1000)

guard(SOURCE, ["business_settings", "dispensings", "prescription_lines", "prescriptions", "medicines", "animals"])
guard(TARGET, ["antimicrobial_use"])

days = []
if starts:
    days = rows(SOURCE, """
SELECT DISTINCT d, extract(epoch FROM (d::timestamp AT TIME ZONE b.timezone)),
       extract(epoch FROM ((d + 1)::timestamp AT TIME ZONE b.timezone))
  FROM business_settings b,
       LATERAL (SELECT (to_timestamp(s) AT TIME ZONE b.timezone)::date - 1 AS d
                  FROM unnest(string_to_array(%(starts)s, ',')::float8[]) AS s) x
 ORDER BY 1
""", starts=",".join(str(s) for s in starts))

HERD = """
WITH herd_species AS (SELECT herd_id, min(species) AS species FROM animals WHERE herd_id IS NOT NULL GROUP BY herd_id)
SELECT hs.species, m.atcvet_code, count(*), count(DISTINCT p.herd_id)
  FROM dispensings d JOIN prescription_lines l ON l.id = d.prescription_line_id
  JOIN prescriptions p ON p.id = l.prescription_id JOIN medicines m ON m.id = l.medicine_id
  JOIN herd_species hs ON hs.herd_id = p.herd_id
 WHERE m.antimicrobial AND p.herd_id IS NOT NULL AND p.animal_id IS NULL
   AND d.dispensed_at >= to_timestamp(%(lo)s::float8) AND d.dispensed_at < to_timestamp(%(hi)s::float8)
 GROUP BY 1, 2
"""

violations, witnessed = [], 0
for day, lo, hi in days:
    herd = rows(SOURCE, HERD, lo=lo, hi=hi)
    if not herd:
        continue
    witnessed += 1
    held = {(s, a): (int(d), int(h)) for s, a, d, h in rows(TARGET, """
SELECT species, atcvet_code, sum(dispensings), sum(herds_treated) FROM antimicrobial_use
 WHERE day = %(day)s::date GROUP BY 1, 2""", day=day)}
    missing = []
    for species, atc, n, herds in herd:
        got_d, got_h = held.get((species, atc), (0, 0))
        if got_d < int(n) or got_h < int(herds):
            missing.append(f"{n} dispensings to {herds} herds of {species} with {atc} "
                           f"(counted: {got_d} dispensings, {got_h} herds)")
    if missing:
        more = f", and {len(missing) - 1} more" if len(missing) > 1 else ""
        violations.append(f"{day}: {missing[0]}{more}")

if len(violations) > THRESHOLD:
    more = f" ({len(violations)} such days {window})" if len(violations) > 1 else ""
    print(f"herd treatments dropped: {violations[0]}{more}")
    sys.exit(1)
tolerated = (f"; {len(violations)} days tolerated (threshold {THRESHOLD})" if violations else "")
if witnessed:
    print(f"herd treatments counted: {len(starts)} runs of {JOB} {window}, the herd treatments of {witnessed} "
          f"days under their herds' species{tolerated}")
    sys.exit(0)
out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
if "remaining=" not in out:
    cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {len(starts)} runs of {JOB} {window}, "
      f"none after a day with a herd treatment{tolerated}")
sys.exit(3)
PY
