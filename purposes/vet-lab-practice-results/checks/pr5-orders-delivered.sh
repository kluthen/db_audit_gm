#!/bin/sh
# PR5 end to end, each practice order's results delivered (vet-lab-practice-
# results, v0.5 master spec 12.2 purpose 2; clinic-purposes.md section 6):
# every practice order received since the judged moment has its released
# results acknowledged at its callback within its tests' turnaround, the
# wait for the next release round (none for an urgent order) and 15 minutes.
# Judged end to end: on the trace after the fix, wherever it was made; the
# orders a fault left undelivered before it are the answer key's backlog.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs and the lab as
# gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - An order's deadline: its receipt plus its longest test's turnaround
#   (lab_tests.turnaround_hours), then, routine, the next release round
#   (11:00 every day, 14:00 and 18:00 Monday to Saturday, the lab's local
#   time from lab_settings), plus 15 minutes. Its delivery: the final
#   (delivery_key md5('vet-lab-delivery:<order>:final:1')) acknowledged in
#   lab_callbacks.
# - Exit 1: an order acknowledged after its deadline, or not yet and past it.
#   Exit 0: none, with an order received since then and acknowledged in time
#   (the witness). Exit 3 otherwise, remaining= until the first pending
#   deadline, or the next run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "PR5"
LAB = ("lab", "lab")                 # the source and target parts: node, database
JOB = "deliver-practice-results"
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
orders = [(int(o), float(rec), float(dl), num(ack)) for o, rec, dl, ack in query(LAB, """
WITH env AS (SELECT utc_offset_hours AS off FROM lab_settings),
o AS (
  SELECT o.id, o.priority, o.received_at,
         o.received_at + (SELECT max(x.turnaround_hours) FROM lab_order_tests AS t
                            JOIN lab_tests AS x ON x.id = t.test_id WHERE t.order_id = o.id) * interval '1 hour' AS ready
    FROM lab_orders AS o JOIN lab_accounts AS a ON a.id = o.account_id
   WHERE a.kind = 'practice' AND o.cancelled_at IS NULL AND o.received_at > to_timestamp(%(judged)s::float8)),
d AS (
  SELECT o.id, o.received_at,
         CASE WHEN o.priority = 'urgent' THEN o.ready
              ELSE ((SELECT min(z.c) FROM (
                       SELECT date_trunc('day', (o.ready AT TIME ZONE 'UTC') + env.off * interval '1 hour')
                              + dd * interval '1 day' + hh * interval '1 hour' AS c, hh
                         FROM generate_series(0, 3) AS dd, unnest(ARRAY[11, 14, 18]) AS hh) AS z
                      WHERE z.c > (o.ready AT TIME ZONE 'UTC') + env.off * interval '1 hour'
                        AND (z.hh = 11 OR extract(isodow FROM z.c) <= 6))
                    - env.off * interval '1 hour') AT TIME ZONE 'UTC' END + interval '15 minutes' AS deadline
    FROM o CROSS JOIN env)
SELECT d.id, extract(epoch FROM d.received_at), extract(epoch FROM d.deadline),
       (SELECT extract(epoch FROM min(c.acknowledged_at)) FROM lab_callbacks AS c
         WHERE c.order_id = d.id AND c.delivery_key = md5('vet-lab-delivery:' || d.id || ':final:1')::uuid::text)
  FROM d ORDER BY d.received_at, d.id
""", judged=judged)]
late = [(o, dl, ack) for o, _rec, dl, ack in orders if (ack is not None and ack > dl) or (ack is None and now > dl)]
if late:
    o, dl, ack = late[0]
    how = f"acknowledged at {iso(ack)}" if ack is not None else f"still unacknowledged {int(now - dl)} s after it"
    print(f"{INVARIANT} present: practice order {o}'s final due by {iso(dl)}, {how}"
          + (f" ({len(late)} orders late {window})" if len(late) > 1 else ""))
    sys.exit(1)
done = [o for o, _rec, _dl, ack in orders if ack is not None]
if done:
    print(f"{INVARIANT} fixed: {len(done)} practice orders received {window} delivered in time; "
          f"{len(orders) - len(done)} within their deadline still")
    sys.exit(0)
if orders:
    too_soon(min(dl for _o, _rec, dl, _ack in orders) - now + 1, f"{len(orders)} practice orders received {window}, "
             "none delivered yet, none past its deadline")
too_soon(next_run(JOB) + 3600, f"no practice order received {window}")
PY
