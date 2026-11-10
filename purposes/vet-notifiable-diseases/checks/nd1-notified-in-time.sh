#!/bin/sh
# ND1 every trigger notified within its deadline (vet-notifiable-diseases;
# v0.5 master spec 12.2 purpose 5; clinic-purposes.md 9; Regulation (EU)
# 2016/429 Art 18): a vet's notifiable diagnosis (diagnosis_codes.notifiable
# A or other, suspected or confirmed) and a lab notification of any
# customer's, triggered since the judged moment, each notified and
# referenced by the authority within its deadline: an hour for category A,
# a day otherwise. A deadline invariant: it judges triggers, not runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic) and the lab (lab/lab) as gm_check with
# check-sql; it never runs a job and never calls the authority. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - The deadline is the trigger's own (the disease's category in clinic,
#   the notification's in lab), never the one the job wrote. Notified: a
#   referenced ops.notifications row for the trigger (in lab, or the
#   notification's notified_at), the earliest reference counted.
# - Exit 1: a trigger past its deadline unnotified, or notified late.
#   Exit 0: every trigger older than two cycles (2 x 5 minutes) notified,
#   at least one (the witness: rare, a few a month). Exit 3 otherwise,
#   remaining= until the oldest pending trigger's deadline (or notify-vet's
#   next run, none). Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ND1"
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
CYCLE = 5 * 60                       # notify-vet's and notify-lab's cadence, seconds
DEADLINE = {"A": 3600, "other": 86400}

guard(CLINIC, ["diagnoses", "diagnosis_codes", "ops.notifications"])
guard(LAB, ["lab_notifications", "ops.notifications"])
vet = query(CLINIC, """
SELECT jsonb_build_object('now', extract(epoch FROM now()), 'triggers', coalesce((
  SELECT jsonb_agg(jsonb_build_array(d.id, dc.notifiable, extract(epoch FROM d.recorded_at),
           (SELECT extract(epoch FROM min(n.referenced_at)) FROM ops.notifications n
             WHERE n.trigger = 'vet' AND n.trigger_id = d.id AND n.reference IS NOT NULL))
         ORDER BY d.recorded_at, d.id)
    FROM diagnoses d JOIN diagnosis_codes dc ON dc.code = d.code
   WHERE dc.notifiable <> 'none' AND d.recorded_at > to_timestamp(%(judged)s::float8)), '[]'))::text
""", judged=judged)
lab = query(LAB, """
SELECT coalesce(jsonb_agg(jsonb_build_array(l.id, l.category, extract(epoch FROM l.suspected_at),
         extract(epoch FROM least(l.notified_at,
           (SELECT min(n.referenced_at) FROM ops.notifications n
             WHERE n.trigger = 'lab' AND n.trigger_id = l.id AND n.reference IS NOT NULL))))
       ORDER BY l.suspected_at, l.id), '[]')::text
  FROM lab_notifications l WHERE l.suspected_at > to_timestamp(%(judged)s::float8)
""", judged=judged)
now = float(vet["now"])
# (what, category, triggered, deadline, notified or None)
triggers = [(f"diagnosis {i}", c, float(t), float(t) + DEADLINE[c], float(n) if n is not None else None)
            for i, c, t, n in vet["triggers"]]
triggers += [(f"lab notification {i}", c, float(t), float(t) + DEADLINE[c], float(n) if n is not None else None)
             for i, c, t, n in lab]
triggers.sort(key=lambda t: t[2])

late = [t for t in triggers if (t[4] is not None and t[4] > t[3]) or (t[4] is None and now > t[3])]
if late:
    what, category, triggered, deadline, notified = late[0]
    limit = "an hour" if category == "A" else "a day"
    how = (f"notified {int((notified - triggered) // 60)} minutes after it" if notified is not None
           else f"not notified {int((now - triggered) // 60)} minutes after it")
    more = f" ({len(late)} triggers not notified in time {window})" if len(late) > 1 else ""
    print(f"{INVARIANT} present: {what} (category {category}, {limit}), triggered at {iso(triggered)}, {how}{more}")
    sys.exit(1)
old = [t for t in triggers if t[2] <= now - 2 * CYCLE]
if old and all(t[4] is not None for t in old):
    print(f"{INVARIANT} fixed: {len(old)} triggers {window} at least two cycles old, each notified and referenced "
          f"within its deadline ({len(triggers) - len(old)} younger)")
    sys.exit(0)
if triggers:
    pending = next((t for t in triggers if t[4] is None and t[2] <= now - 2 * CYCLE), triggers[0])
    until = pending[3] if pending[2] <= now - 2 * CYCLE else pending[2] + 2 * CYCLE
    print(f"remaining={max(1, int(until - now) + 1)} {len(triggers)} triggers {window}; {pending[0]}, triggered at "
          f"{iso(pending[2])}, is still to be judged")
    sys.exit(3)
too_soon("notify-vet", f"no notifiable diagnosis and no lab notification {window}")
PY
