#!/bin/sh
# ND4 every notification referenced, or escalated (vet-notifiable-diseases;
# v0.5 master spec 12.2 purpose 5; clinic-purposes.md 9): every
# notification first sent since the judged moment has its reference, or an
# incident by the next escalation run after its deadline (after its
# rejection, a 4xx). A deadline invariant: it judges triggers, not runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic) and the lab (lab/lab) as gm_check with
# check-sql; it never runs a job and never calls the authority. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - The deadline is the trigger's own (an hour for category A, a day
#   otherwise, from its triggering time), never the one the job wrote; for
#   a notification first sent after it, its first sending. The next
#   escalation run: the quarter hour at or after it, plus 3 minutes for the
#   run. An incident: ops.incidents, kind unreferenced or rejected, ref the
#   key, in the notification's database.
# - Exit 1: a notification past that run with neither. Exit 0: at least one
#   notification sent since the judged moment referenced or escalated, none
#   failing. Exit 3 otherwise, remaining= until the earliest escalation due
#   (or notify-vet's next run, none sent). Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ND4"
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


PURPOSE = "vet-notifiable-diseases"
CLINIC = ("records", "clinic")       # the source part: node, database
LAB = ("lab", "lab")                 # the source_lab part
ESCALATION = 15 * 60                 # escalate-notifications' cadence, seconds (scenario quarters are UTC's)
GRACE = 3 * 60                       # the escalation's run after its quarter
DEADLINE = {"A": 3600, "other": 86400}


def next_escalation(ts):
    """The end of the first escalation run at or after `ts`: its quarter
    hour plus its run's grace."""
    return -(-ts // ESCALATION) * ESCALATION + GRACE


# In each database: the notifications first sent since the judged moment,
# each with its trigger's true deadline (from the disease's category), its
# last status, its reference and the first incident naming its key.
INCIDENT = """(SELECT extract(epoch FROM min(i.opened_at)) FROM ops.incidents i
                WHERE i.purpose = %(purpose)s AND i.kind IN ('unreferenced', 'rejected') AND i.ref = n.notification_key)"""
guard(CLINIC, ["diagnoses", "diagnosis_codes", "ops.notifications", "ops.incidents"])
guard(LAB, ["lab_notifications", "ops.notifications", "ops.incidents"])
vet = query(CLINIC, f"""
SELECT jsonb_build_object('now', extract(epoch FROM now()), 'sent', coalesce((
  SELECT jsonb_agg(jsonb_build_array(n.notification_key, dc.notifiable, extract(epoch FROM d.recorded_at),
                                     extract(epoch FROM n.first_sent_at), extract(epoch FROM n.last_sent_at),
                                     n.last_status, n.reference, {INCIDENT}) ORDER BY n.id)
    FROM ops.notifications n
    LEFT JOIN diagnoses d ON n.trigger = 'vet' AND d.id = n.trigger_id
    LEFT JOIN diagnosis_codes dc ON dc.code = d.code
   WHERE n.first_sent_at > to_timestamp(%(judged)s::float8)), '[]'))::text
""", purpose=PURPOSE, judged=judged)
lab = query(LAB, f"""
SELECT coalesce(jsonb_agg(jsonb_build_array(n.notification_key, l.category, extract(epoch FROM l.suspected_at),
                                            extract(epoch FROM n.first_sent_at), extract(epoch FROM n.last_sent_at),
                                            n.last_status, n.reference, {INCIDENT}) ORDER BY n.id), '[]')::text
  FROM ops.notifications n LEFT JOIN lab_notifications l ON n.trigger = 'lab' AND l.id = n.trigger_id
 WHERE n.first_sent_at > to_timestamp(%(judged)s::float8)
""", purpose=PURPOSE, judged=judged)
now = float(vet["now"])

wrong, done, waiting = [], [], []
for key, category, triggered, first, last, status, reference, incident in vet["sent"] + lab:
    if category not in DEADLINE or triggered is None:
        wrong.append(f"notification {key} names no trigger with a notifiable category")
        continue
    deadline = float(triggered) + DEADLINE[category]
    rejected = status is not None and 400 <= int(status) < 500
    if reference is not None:
        done.append(key)
        continue
    due = next_escalation(float(last) if rejected else max(deadline, float(first)))
    if incident is not None and float(incident) <= due:
        done.append(key)
    elif now > due:
        why = "rejected" if rejected else f"unreferenced past its deadline {iso(deadline)}"
        wrong.append(f"notification {key}, {why}, has no incident by the escalation run after it ({iso(due)})")
    else:
        waiting.append((due, key))

if wrong:
    more = f" ({len(wrong)} such {window})" if len(wrong) > 1 else ""
    print(f"{INVARIANT} present: {wrong[0]}{more}")
    sys.exit(1)
if done:
    print(f"{INVARIANT} fixed: {len(done)} notifications sent {window}, each referenced or escalated by the next "
          f"escalation run after its deadline ({len(waiting)} still awaiting their answer)")
    sys.exit(0)
if waiting:
    until, key = min(waiting)
    print(f"remaining={max(1, int(until - now) + 1)} {len(waiting)} notifications sent {window} await their "
          f"reference; {key}'s escalation is due at {iso(until)}")
    sys.exit(3)
too_soon("notify-vet", f"no notification sent {window}")
PY
