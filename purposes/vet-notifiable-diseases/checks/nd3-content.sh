#!/bin/sh
# ND3 what a notification carries (vet-notifiable-diseases; v0.5 master
# spec 12.2 purpose 5; clinic-purposes.md 9): the disease, the species, the
# holding or the keeper's name and address, the notifying vet or lab and
# the date; never the clinical notes. A runs invariant, on the
# notifications posted since the judged moment (ops.notifications.payload,
# as posted) and the runs of notify-vet and notify-lab since then.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic) and the lab (lab/lab) as gm_check with
# check-sql; it never runs a job and never calls the authority. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - Only the authority's fields (notification_key, disease, status, date,
#   species, holding, keeper, notifier), no key naming findings or notes,
#   and not the trigger's clinical notes as text (the consultation's
#   findings; the lab order's clinical_notes). The lab holds no address:
#   its notification carries the keeper's name and the account of the
#   practice that holds it (gm.md).
# - Exit 1: a notification beyond these, or lacking one. Exit 0: at least
#   one judged run and one notification, none failing. Exit 3 otherwise.
#   Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "ND3"
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
TOP = {"notification_key", "disease", "status", "date", "species", "holding", "keeper", "notifier"}
NOTES = 12                           # the shortest clinical note judged as text carried over


def text(value):
    return isinstance(value, str) and value.strip() != ""


def keys_of(value, path=""):
    """Every key of a JSON value, dotted."""
    if isinstance(value, dict):
        for k, v in value.items():
            yield f"{path}{k}"
            yield from keys_of(v, f"{path}{k}.")
    elif isinstance(value, list):
        for v in value:
            yield from keys_of(v, path)


def missing(payload, trigger):
    """What ND3 asks for that the payload lacks: the disease, the species,
    the holding or the keeper's name and address (the lab, which holds no
    address, the keeper's name and the practice's account that holds it),
    the notifier, the date."""
    out = []
    disease = payload.get("disease") if isinstance(payload.get("disease"), dict) else {}
    if not text(disease.get("code")):
        out.append("the disease")
    if not text(payload.get("species")):
        out.append("the species")
    holding = payload.get("holding") if isinstance(payload.get("holding"), dict) else None
    keeper = payload.get("keeper") if isinstance(payload.get("keeper"), dict) else None
    if holding is not None:
        hk = holding.get("keeper") if isinstance(holding.get("keeper"), dict) else {}
        if not (text(holding.get("number")) and text(hk.get("name")) and text(hk.get("address"))):
            out.append("the holding's number and its keeper's name and address")
    elif keeper is None or not text(keeper.get("name")) or not (
            text(keeper.get("address")) if trigger == "vet" else keeper.get("account") is not None):
        out.append("the keeper's name and address" if trigger == "vet"
                   else "the keeper's name and the practice's account")
    notifier = payload.get("notifier") if isinstance(payload.get("notifier"), dict) else {}
    if not text(notifier.get("name")):
        out.append("the notifier")
    if not text(payload.get("date")):
        out.append("the date")
    return out


# The notifications posted since the judged moment, each with the clinical
# notes of its trigger: a vet's consultation findings, a lab order's notes.
guard(CLINIC, ["diagnoses", "consultations", "ops.notifications"])
guard(LAB, ["lab_notifications", "lab_order_tests", "lab_orders", "ops.notifications"])
vet = query(CLINIC, """
SELECT coalesce(jsonb_agg(jsonb_build_array(n.notification_key, n.trigger, n.payload, c.findings) ORDER BY n.id),
                '[]')::text
  FROM ops.notifications n
  LEFT JOIN diagnoses d ON d.id = n.trigger_id LEFT JOIN consultations c ON c.id = d.consultation_id
 WHERE n.last_sent_at > to_timestamp(%(judged)s::float8)
""", judged=judged)
lab = query(LAB, """
SELECT coalesce(jsonb_agg(jsonb_build_array(n.notification_key, n.trigger, n.payload, o.clinical_notes) ORDER BY n.id),
                '[]')::text
  FROM ops.notifications n
  LEFT JOIN lab_notifications l ON l.id = n.trigger_id LEFT JOIN lab_order_tests t ON t.id = l.order_test_id
  LEFT JOIN lab_orders o ON o.id = t.order_id
 WHERE n.last_sent_at > to_timestamp(%(judged)s::float8)
""", judged=judged)

wrong = []
for key, trigger, payload, notes in vet + lab:
    if not isinstance(payload, dict):
        wrong.append(f"notification {key} posted something that is not an object")
        continue
    extra = sorted(set(payload) - TOP)
    named = sorted({k for k in keys_of(payload) if any(w in k.lower() for w in ("finding", "note", "clinical"))})
    lacks = missing(payload, trigger)
    if extra or named:
        wrong.append(f"notification {key} carries {', '.join(extra + named)}, beyond what the authority is owed")
    elif text(notes) and len(notes.strip()) >= NOTES and notes.strip() in json.dumps(payload, ensure_ascii=False):
        wrong.append(f"notification {key} carries its trigger's clinical notes")
    elif lacks:
        wrong.append(f"notification {key} lacks {', '.join(lacks)}")
if wrong:
    more = f" ({len(wrong)} such {window})" if len(wrong) > 1 else ""
    print(f"{INVARIANT} present: {wrong[0]}{more}")
    sys.exit(1)
ran = sum(len(runs(job, judged)) for job in JOBS)
if ran and (vet or lab):
    print(f"{INVARIANT} fixed: {len(vet) + len(lab)} notifications posted {window}, each with the disease, the "
          f"species, the holding or the keeper, the notifier and the date, no clinical note ({ran} runs)")
    sys.exit(0)
too_soon("notify-vet", f"{ran} runs of {' and '.join(JOBS)}, no notification posted {window}: nothing to judge yet")
PY
