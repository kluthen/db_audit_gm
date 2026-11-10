#!/bin/sh
# LO1 every closed consultation's requests sent in time (vet-lab-centre-orders,
# v0.5 master spec 12.2 purpose 1; clinic-purposes.md section 5): every
# analysis request of a consultation closed since the judged moment is sent
# with an accession within 5 minutes of the close, 2 for an urgent one, or
# cancelled. A deadline invariant: it judges triggers, not runs.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ); it reads the judged moment with
# check-runs and clinic as gm_check with check-sql, never runs a job (capture
# W4 item 0, "Where a check runs").
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - A trigger: an analysis request of a consultation closed (or signed) since
#   then; its deadline the close (ended_at) plus 5 minutes, 2 when urgent.
#   Handled: sent (sent_at) or cancelled (cancelled_at) by then.
# - Exit 1: a trigger past its deadline unhandled, or handled after it.
#   Exit 0: every trigger whose deadline has passed handled in time, at least
#   one (the witness). Exit 3 otherwise, remaining= until the next deadline or
#   the next posting run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below); the GM adapts them as
# it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "LO1"
CLINIC = ("records", "clinic")       # the source part: node, database
JOB = "post-lab-orders"
ROUTINE, URGENT = 5 * 60, 2 * 60     # the deadlines after the close, seconds
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


def ids(values):
    return ",".join(str(v) for v in values) or "0"


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

now = float(query(CLINIC, "SELECT extract(epoch FROM now())")[0][0])
triggers = [(int(r), p, float(e), num(s), num(c)) for r, p, e, s, c in query(CLINIC, """
SELECT r.id, r.priority, extract(epoch FROM c.ended_at), extract(epoch FROM r.sent_at),
       extract(epoch FROM r.cancelled_at)
  FROM requests r JOIN consultations c ON c.id = r.consultation_id
 WHERE r.kind = 'analysis' AND c.state IN ('closed', 'signed')
   AND c.ended_at > to_timestamp(%(judged)s::float8)
 ORDER BY c.ended_at, r.id
""", judged=judged)]


def deadline(t):
    return t[2] + (URGENT if t[1] == "urgent" else ROUTINE)


def handled(t):
    times = [x for x in (t[3], t[4]) if x is not None]
    return min(times) if times else None


late = [t for t in triggers if (handled(t) is not None and handled(t) > deadline(t))
        or (handled(t) is None and now > deadline(t))]
if late:
    t = late[0]
    how = (f"sent or cancelled {int(handled(t) - t[2])} s after the close" if handled(t) is not None
           else f"still requested {int(now - t[2])} s after the close")
    more = f" ({len(late)} requests late {window})" if len(late) > 1 else ""
    print(f"{INVARIANT} present: request {t[0]} ({t[1]}), its consultation closed at {iso(t[2])}, {how}"
          f"{more}")
    sys.exit(1)
due = [t for t in triggers if now > deadline(t)]
if due:
    print(f"{INVARIANT} fixed: {len(due)} analysis requests of consultations closed {window}, each sent or "
          f"cancelled within its deadline ({len(triggers) - len(due)} younger)")
    sys.exit(0)
if triggers:
    t = triggers[0]
    too_soon(deadline(t) - now + 1, f"{len(triggers)} requests of consultations closed {window}; request "
             f"{t[0]}'s deadline is {iso(deadline(t))}")
too_soon(next_run(JOB) + ROUTINE, f"no consultation closed with an analysis request {window}")
PY
