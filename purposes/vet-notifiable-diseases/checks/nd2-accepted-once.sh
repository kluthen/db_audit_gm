#!/bin/sh
# ND2 one notification accepted per trigger (vet-notifiable-diseases; v0.5
# master spec 12.2 purpose 5; clinic-purposes.md 9): a runs invariant, on
# the runs of notify-vet and notify-lab since the judged moment and the
# notifications they posted (ops.notifications, last sent since then).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic) and the lab (lab/lab) as gm_check with
# check-sql; it never runs a job and never calls the authority. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - In each database: one ops.notifications row per trigger, under its
#   trigger's key (vet-<diagnosis id>, lab-<notification id>: a retry
#   repeats the key, so the authority answers the same reference); in lab,
#   the reference written back (lab_notifications.authority_ref) the one
#   the notification got.
# - Exit 1: a trigger holding two notifications, a key not its trigger's,
#   or two references for one lab notification. Exit 0: at least one
#   judged run and one notification accepted since then (its 503s retried
#   counted in the line), none broken. Exit 3 otherwise. Exit 2: it cannot
#   judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ND2"
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
JOBS = ("notify-vet", "notify-lab")

# In each database: the notifications posted since the judged moment (their
# trigger, key, reference, attempts), every trigger holding more than one
# notification, and in the lab the reference written back against the one
# the notification got.
SQL = """
SELECT jsonb_build_object(
  'rows', coalesce((SELECT jsonb_agg(jsonb_build_array(n.trigger, n.trigger_id, n.notification_key, n.reference,
                                                       n.attempts) ORDER BY n.id)
                      FROM ops.notifications n WHERE n.last_sent_at > to_timestamp(%(judged)s::float8)), '[]'),
  'twice', coalesce((SELECT jsonb_agg(jsonb_build_array(trigger, trigger_id, keys))
                       FROM (SELECT trigger, trigger_id, jsonb_agg(notification_key ORDER BY id) AS keys
                               FROM ops.notifications GROUP BY trigger, trigger_id
                             HAVING count(*) > 1 AND max(last_sent_at) > to_timestamp(%(judged)s::float8)) x), '[]')
  {lab})::text
"""
LAB_PART = """, 'written', coalesce((
    SELECT jsonb_agg(jsonb_build_array(l.id, l.authority_ref, n.reference))
      FROM lab_notifications l JOIN ops.notifications n ON n.trigger = 'lab' AND n.trigger_id = l.id
     WHERE l.notified_at IS NOT NULL AND n.last_sent_at > to_timestamp(%(judged)s::float8)
       AND l.authority_ref IS DISTINCT FROM n.reference), '[]')"""

guard(CLINIC, ["ops.notifications"])
guard(LAB, ["lab_notifications", "ops.notifications"])
vet = query(CLINIC, SQL.replace("{lab}", ""), judged=judged)
lab = query(LAB, SQL.replace("{lab}", LAB_PART), judged=judged)

wrong = []
for name, got in (("clinic", vet), ("lab", lab)):
    for trigger, tid, keys in got["twice"]:
        wrong.append(f"{trigger} trigger {tid} holds {len(keys)} notifications ({', '.join(keys)}) in {name}")
    for trigger, tid, key, reference, attempts in got["rows"]:
        if key != f"{trigger}-{tid}":
            wrong.append(f"{trigger} trigger {tid} notified under key {key}, not {trigger}-{tid}: a repeat is a "
                         "new notification to the authority")
for lid, written, reference in lab.get("written", []):
    wrong.append(f"lab notification {lid} holds the authority's reference {written}, its notification got "
                 f"{reference}: accepted twice")
if wrong:
    more = f" ({len(wrong)} such {window})" if len(wrong) > 1 else ""
    print(f"{INVARIANT} present: {wrong[0]}{more}")
    sys.exit(1)

rows = vet["rows"] + lab["rows"]
accepted = [r for r in rows if r[3] is not None]
retried = sum(1 for r in accepted if r[4] > 1)
ran = sum(len(runs(job, judged)) for job in JOBS)
if ran and accepted:
    print(f"{INVARIANT} fixed: {len(accepted)} notifications accepted {window}, one per trigger under its own key "
          f"({retried} after a retry; {ran} runs of {' and '.join(JOBS)})")
    sys.exit(0)
too_soon("notify-vet", f"{ran} runs of {' and '.join(JOBS)}, {len(rows)} notifications posted and none accepted "
         f"{window}: nothing to judge yet")
PY
