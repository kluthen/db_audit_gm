#!/bin/sh
# Sealed check of purpose-receiver-down-unnoticed (v0.4 master spec 12.1,
# 12.3, 12.4, 16.2; spec D214, D228): the export declarations purpose's E4,
# every declaration sent since the judged moment has an acknowledgement
# within 30 minutes of sending, or an incidents row by the escalation run
# after that; every rejection has an incidents row. A deadline invariant: it
# judges triggers, not runs. Adapted from purposes/shop-export-declarations/
# checks/e4-acknowledged-or-escalated.sh, the source as a parameter, and the
# threshold.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the declarations
# missed tolerated, 0 by the answer key's default) and FAULT_SOURCE
# (<node>/<database>). It reads the judged moment with check-runs and the
# database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A trigger: a declaration sent since then. Handled: an acknowledgement
#   received within 30 minutes of sending; else, or when it was rejected,
#   an incident (source customs, ref its id) opened by the deadline: for an
#   unacknowledged one, 30 minutes after sending plus one escalation cycle
#   (15 minutes, escalate-customs' cadence) and two minutes' grace; for a
#   rejected one, the rejection plus one cycle and the grace, no 30-minute
#   wait (spec D228).
# - Exit 1 (12.4): more triggers past their deadline with no incident in
#   time than the threshold. Exit 0: every trigger older than two
#   escalation cycles handled (the missed ones within the threshold), at
#   least one of them left unacknowledged or rejected and escalated (the
#   witness: the receiver never answers about one declaration in fifty).
#   Exit 3 otherwise, remaining= until the oldest pending trigger's
#   deadline, or one cycle when none is pending. Exit 2: it cannot judge.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "E4"
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


def query(text, **values):
    argv = [CHECK_SQL, "-h", DB[0], "-d", DB[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def too_soon(job, why):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def run_of(ts, rs):
    """The run in whose transaction a row written at `ts` was (log instants are
    whole seconds, truncated)."""
    return next((r for r in rs if r[0] - 1 <= ts < r[1] + 1), None)


source = os.environ.get("FAULT_SOURCE", "db/shop")
DB = tuple(source.split("/", 1)) if source.count("/") == 1 else None
if DB is None or not all(DB):
    cannot(f"FAULT_SOURCE is {source!r}, not <node>/<database>")
try:
    threshold = int(os.environ.get("CHECK_THRESHOLD", "0") or "0")
except ValueError:
    cannot(f"CHECK_THRESHOLD is {os.environ.get('CHECK_THRESHOLD')!r}, not an integer")

ACK_WITHIN = 30 * 60                 # seconds: an acknowledgement in time
CYCLE = 15 * 60                      # escalate-customs' cadence
GRACE = 2 * 60

judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
now = float(query("SELECT extract(epoch FROM now())")[0][0])


def num(text):
    return float(text) if text else None


triggers = [(int(i), float(s), num(a), num(r), num(o)) for i, s, a, r, o in query("""
SELECT d.id, extract(epoch FROM d.sent_at),
       extract(epoch FROM k.first_ack), extract(epoch FROM k.rejected), extract(epoch FROM i.opened)
  FROM customs_outbox d
 CROSS JOIN LATERAL (
       SELECT min(a.received_at) AS first_ack,
              min(a.received_at) FILTER (WHERE a.status = 'rejected') AS rejected
         FROM customs_acks a WHERE a.outbox_id = d.id) AS k
 CROSS JOIN LATERAL (
       SELECT min(n.opened_at) AS opened FROM incidents n
        WHERE n.source = 'customs' AND n.ref = d.id::text) AS i
 WHERE d.sent_at > to_timestamp(%(judged)s::float8)
 ORDER BY d.sent_at, d.id
""", judged=judged)]

judgement = []                       # (id, sent, state, deadline, needs an incident)
for i, s, a, r, o in triggers:
    if r is not None:
        deadline, needs = r + CYCLE + GRACE, "rejected"
    elif a is not None and a <= s + ACK_WITHIN:
        judgement.append((i, s, "handled", None, None))
        continue
    else:
        deadline, needs = s + ACK_WITHIN + CYCLE + GRACE, "unacknowledged"
    if o is not None and o <= deadline:
        state = "handled"
    elif (o is not None and o > deadline) or now > deadline:
        state = "missed"
    else:
        state = "pending"
    judgement.append((i, s, state, deadline, needs))

missed = [j for j in judgement if j[2] == "missed"]
if len(missed) > threshold:
    i, s, _, deadline, needs = missed[0]
    more = f" ({len(missed)} declarations neither acknowledged nor escalated in time {window})" \
        if len(missed) > 1 else ""
    print(f"{INVARIANT} present: declaration {i}, sent at {iso(s)}, {needs}, has no incident "
          f"by {iso(deadline)}{more}")
    sys.exit(1)

tolerated = (f"; {len(missed)} missed tolerated (threshold {threshold})" if missed else "")
old = [j for j in judgement if j[1] <= now - 2 * CYCLE]
escalated = [j for j in old if j[4] is not None and j[2] == "handled"]
if old and all(j[2] in ("handled", "missed") for j in old) and escalated:
    print(f"{INVARIANT} fixed: {len(old)} declarations sent {window} at least two escalation "
          f"cycles ago, each acknowledged in time or escalated; {len(escalated)} "
          f"escalated{tolerated}")
    sys.exit(0)
pending = [j for j in judgement if j[2] == "pending"]
if pending:
    i, s, _, deadline, needs = pending[0]
    print(f"remaining={max(1, int(deadline - now) + 1)} {len(triggers)} declarations sent "
          f"{window}; declaration {i}, {needs}, is still to be escalated{tolerated}")
    sys.exit(3)
print(f"remaining={CYCLE} {len(triggers)} declarations sent {window}, every one acknowledged: "
      f"none yet left unanswered to prove the escalation{tolerated}")
sys.exit(3)
PY
