#!/bin/sh
# EX5 the outbound trip, end to end (vet-centre-exchanges; v0.5 master spec
# 12.1 item 6, 12.2 purpose 4; clinic-purposes.md 8): every outbound
# exchange sent since the judged moment is answered within a working day,
# or chased and then escalated. Judged end to end: on the trace after the
# fix; the backlog is the answer key's.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl check,
# with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It raises the judged moment to the
# runner's last reload (check-runs since), reads the record (records/clinic) as gm_check with
# check-sql; it never runs a job and never calls the centres. A table read
# with row security needs the GM's read policy (spec D432): gone, the check
# exits 2.
#
# - A working day: Monday to Friday by the customer's local date
#   (business_settings.utc_offset_hours), as chase-exchanges counts them.
#   An exchange sent on day D: answered by the chase of the first working
#   day after D (09:00 local, plus 15 minutes for the run), or resent by
#   then (a resend message, any status); then answered by the next working
#   day's chase, or an ops.incidents row (unanswered, its key) by then.
# - Exit 1: an exchange past either chase with neither. Exit 0: at least
#   one exchange sent since the judged moment answered, or escalated, and
#   none failing. Exit 3 otherwise, remaining= until the earliest chase due
#   (or sync-exchanges' next run, none sent). Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "EX5"
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


PURPOSE = "vet-centre-exchanges"
CLINIC = ("records", "clinic")       # the source part: node, database
CHASE_AT = 9                         # chase-exchanges' hour, local, on working days
GRACE = 15 * 60                      # the chase's run after its hour


def working_day_after(day):
    day += timedelta(days=1)
    while day.weekday() >= 5:
        day += timedelta(days=1)
    return day


def chase_time(day, offset):
    """The epoch of `day`'s chase (09:00 local) plus its grace."""
    local = datetime(day.year, day.month, day.day, CHASE_AT, tzinfo=timezone.utc)
    return (local - timedelta(hours=offset)).timestamp() + GRACE


guard(CLINIC, ["exchanges", "business_settings", "ops.exchange_messages", "ops.incidents"])
got = query(CLINIC, """
SELECT jsonb_build_object(
  'now', extract(epoch FROM now()),
  'offset', (SELECT utc_offset_hours FROM business_settings),
  'sent', coalesce((
    SELECT jsonb_agg(jsonb_build_array(
             e.id, e.exchange_key, extract(epoch FROM e.sent_at), extract(epoch FROM e.answered_at),
             (SELECT extract(epoch FROM min(m.at)) FROM ops.exchange_messages m
               WHERE m.exchange_key = e.exchange_key AND m.kind = 'resend' AND m.direction = 'out'),
             (SELECT extract(epoch FROM min(i.opened_at)) FROM ops.incidents i
               WHERE i.purpose = %(purpose)s AND i.kind = 'unanswered' AND i.ref = e.exchange_key::text))
           ORDER BY e.sent_at, e.id)
      FROM exchanges e WHERE e.direction = 'out' AND e.sent_at > to_timestamp(%(judged)s::float8)), '[]'))::text
""", purpose=PURPOSE, judged=judged)
now, offset = float(got["now"]), int(got["offset"] or 0)

wrong, done, waiting = [], [], []    # waiting: (until, exchange id)
for xid, key, sent, answered, resent, escalated in got["sent"]:
    sent = float(sent)
    answered = float(answered) if answered is not None else None
    sent_day = (datetime.fromtimestamp(sent, timezone.utc) + timedelta(hours=offset)).date()
    d1 = working_day_after(sent_day)
    due1, due2 = chase_time(d1, offset), chase_time(working_day_after(d1), offset)
    if answered is not None and answered <= due1:
        done.append(xid)
        continue
    if now >= due1 and (resent is None or float(resent) > due1):
        wrong.append(f"exchange {xid} (key {key}), sent at {iso(sent)}, unanswered on {d1} at the chase and not "
                     "resent")
        continue
    if answered is not None and answered <= due2:
        done.append(xid)
        continue
    if now >= due2 and (escalated is None or float(escalated) > due2):
        wrong.append(f"exchange {xid} (key {key}), sent at {iso(sent)}, unanswered two working days after sending "
                     "and not escalated")
        continue
    if answered is not None or (escalated is not None and now >= due2):
        done.append(xid)
    else:
        waiting.append((due1 if now < due1 else due2, xid))

if wrong:
    more = f" ({len(wrong)} outbound exchanges neither answered nor chased {window})" if len(wrong) > 1 else ""
    print(f"{INVARIANT} present: {wrong[0]}{more}")
    sys.exit(1)
if done:
    print(f"{INVARIANT} fixed: {len(done)} outbound exchanges sent {window} answered within a working day, or "
          f"chased then escalated ({len(waiting)} still within their working day)")
    sys.exit(0)
if waiting:
    until, xid = min(waiting)
    print(f"remaining={max(1, int(until - now) + 1)} {len(waiting)} outbound exchanges sent {window} await their "
          f"answer; exchange {xid}'s working day ends at {iso(until)}")
    sys.exit(3)
too_soon("sync-exchanges", f"no outbound exchange sent {window}")
PY
