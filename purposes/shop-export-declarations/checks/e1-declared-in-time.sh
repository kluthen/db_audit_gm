#!/bin/sh
# E1 every trigger declared in time (shop-export-declarations, v0.4 master
# spec 10.4, 12.1, 12.3, 12.4): every order packed since the judged moment
# with an export destination has a declaration sent within two hours of its
# packed_at. A deadline invariant: it judges triggers, not runs.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the judged moment with
# check-runs and the shop's database as gm_check with check-sql; it never
# runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A trigger: an order packed since then whose ship_country is in
#   export_countries. Its deadline: packed_at plus two hours. Handled: a
#   customs_outbox row for the order sent by then.
# - Exit 1 (12.4): a trigger past its deadline with no declaration, or
#   declared after it. Exit 0: every trigger older than two dispatch cycles
#   (2 x 5 minutes) handled, at least one such trigger (the witness, 12.3).
#   Exit 3 otherwise, remaining= until the oldest pending trigger reaches
#   two cycles or, older and still undeclared, its deadline. Exit 2: it
#   cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "E1"
DB = ("db", "shop")                  # the source part: node, database
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


CYCLE = 5 * 60                       # declare-exports' cadence, seconds
DEADLINE = 2 * 3600                  # from packed_at

judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
now = float(query("SELECT extract(epoch FROM now())")[0][0])
triggers = [(int(o), float(p), float(s) if s else None) for o, p, s in query("""
SELECT o.id, extract(epoch FROM o.packed_at),
       extract(epoch FROM (SELECT min(d.sent_at) FROM customs_outbox d WHERE d.order_id = o.id))
  FROM orders o
  JOIN export_countries x ON x.country = o.ship_country
 WHERE o.packed_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.packed_at, o.id
""", judged=judged)]

late = [(o, p, s) for o, p, s in triggers
        if (s is not None and s > p + DEADLINE) or (s is None and now > p + DEADLINE)]
if late:
    order, packed, sent = late[0]
    how = (f"declared {int((sent - packed) // 60)} minutes after packing" if sent is not None
           else f"not declared {int((now - packed) // 60)} minutes after packing")
    more = f" ({len(late)} export orders not declared in time {window})" if len(late) > 1 else ""
    print(f"{INVARIANT} present: export order {order}, packed at {iso(packed)}, {how}{more}")
    sys.exit(1)

old = [(o, p, s) for o, p, s in triggers if p <= now - 2 * CYCLE]
pending = [(o, p, s) for o, p, s in triggers if p > now - 2 * CYCLE or s is None]
if old and all(s is not None for _, _, s in old):
    print(f"{INVARIANT} fixed: {len(old)} export orders packed {window} at least two dispatch "
          f"cycles ago, each declared within two hours ({len(triggers) - len(old)} younger)")
    sys.exit(0)
if pending:
    order, packed, sent = next((t for t in pending if t[2] is None and t[1] <= now - 2 * CYCLE),
                               pending[0])
    until = packed + (DEADLINE if packed <= now - 2 * CYCLE else 2 * CYCLE)
    print(f"remaining={max(1, int(until - now) + 1)} {len(triggers)} export orders packed "
          f"{window}; order {order}, packed at {iso(packed)}, is still to be judged")
    sys.exit(3)
print(f"remaining={2 * CYCLE} no export order packed {window}")
sys.exit(3)
PY
