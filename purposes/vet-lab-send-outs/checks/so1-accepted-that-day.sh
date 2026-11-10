#!/bin/sh
# SO1 each send-out accepted the day its sample came (vet-lab-send-outs, v0.5
# master spec 12.2 purpose 3; clinic-purposes.md section 7): every sent-out
# test whose sample was received by 15:30 on a working day (Monday to
# Friday, the lab's local time) is accepted by the external lab that day, or
# in an incident. Judged by triggers.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs and the lab as
# gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - The tests routed out (not cancelled, not unperformed) whose sample was
#   received by 15:30 local on a weekday whose 16:00 run falls after the
#   judged moment (the run a fix made before 16:00 serves, so a sample
#   received before the fix counts); each one's send-out (lab_send_outs)
#   accepted on that local date, or an ops.incidents row (kind unaccepted,
#   ref its send_key).
# - Exit 1: such a test with neither once its local day has ended.
#   Exit 0: none, with one accepted that day (the witness). Exit 3
#   otherwise, remaining= until the next send-outs run, or the first pending
#   day's end. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "SO1"
LAB = ("lab", "lab")                 # the source and target parts: node, database
PURPOSE = "vet-lab-send-outs"
JOB = "send-outs"
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


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def num(text):
    return float(text) if text != "" else None


def next_run(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


def too_soon(seconds, why):
    print(f"remaining={max(1, int(seconds))} {why}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query(LAB, "SELECT extract(epoch FROM now())")[0][0])
tests = [(int(t), day, float(end), ok == "True") for t, day, end, ok in query(LAB, """
WITH env AS (SELECT utc_offset_hours AS off FROM lab_settings),
t AS (
  SELECT t.id, ((s.received_at AT TIME ZONE 'UTC') + env.off * interval '1 hour') AS rl, env.off
    FROM lab_order_tests AS t JOIN lab_samples AS s ON s.id = t.sample_id CROSS JOIN env
   WHERE t.routing = 'sent-out' AND t.status NOT IN ('not-performed', 'cancelled')
     AND s.received_at > to_timestamp(%(judged)s::float8) - interval '1 day')
SELECT t.id, to_char(t.rl, 'YYYY-MM-DD'),
       extract(epoch FROM ((date_trunc('day', t.rl) + interval '1 day' - t.off * interval '1 hour')
                           AT TIME ZONE 'UTC')),
       EXISTS (SELECT 1 FROM lab_send_outs AS so
                WHERE so.order_test_id = t.id
                  AND (((so.accepted_at AT TIME ZONE 'UTC') + t.off * interval '1 hour')::date = t.rl::date
                       OR EXISTS (SELECT 1 FROM ops.incidents AS i
                                   WHERE i.purpose = %(purpose)s AND i.kind = 'unaccepted'
                                     AND i.ref = so.send_key::text)))
  FROM t
 WHERE extract(isodow FROM t.rl) <= 5 AND t.rl::time <= time '15:30'
   AND ((date_trunc('day', t.rl) + interval '16 hours' - t.off * interval '1 hour') AT TIME ZONE 'UTC')
       > to_timestamp(%(judged)s::float8)
 ORDER BY t.rl, t.id
""", judged=judged, purpose=PURPOSE)]
late = [(t, day) for t, day, end, ok in tests if not ok and now >= end]
if late:
    t, day = late[0]
    print(f"{INVARIANT} present: sent-out test {t}, its sample received by 15:30 on {day}, neither accepted "
          f"that day nor in an incident" + (f" ({len(late)} tests {window})" if len(late) > 1 else ""))
    sys.exit(1)
done = [t for t, _day, _end, ok in tests if ok]
if done:
    print(f"{INVARIANT} fixed: {len(done)} sent-out tests received by 15:30 on a weekday, run at 16:00 {window}, each accepted "
          f"that day or in an incident; {len(tests) - len(done)} pending")
    sys.exit(0)
if tests:
    too_soon(min(next_run(JOB) + 120, min(end for _t, _d, end, _ok in tests) - now + 1),
             f"{len(tests)} sent-out tests received by 15:30 {window}, none accepted yet")
too_soon(next_run(JOB) + 120, f"no sent-out test received by 15:30 on a weekday {window}")
PY
