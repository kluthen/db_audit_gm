#!/bin/sh
# M5 truly sent (shop-customer-mailing, v0.4 master spec 10.3, 12.1 to
# 12.3): every order shipped since the judged moment, more than fifteen
# minutes ago, has its order-shipped mail. The owner's "were we truly doing
# this".
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: an order shipped since then, more than fifteen minutes
#   ago, with no order-shipped mail, whether the job ran or not; the run
#   that should have sent it is the first starting a minute or more after
#   the order shipped (mail.shipped's window).
# - Witness (12.3): an order shipped since then, more than fifteen minutes
#   ago.
# Exit 1: an order without its notice. Exit 0: a run since, and every such
# order notified, at least one. Exit 3, remaining= to the job's next run, or
# until the oldest order shipped since is fifteen minutes old. Exit 2: it
# cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "M5"
DB = ("db", "shop")                  # the source part: node, database
JOB = "mail-shipped"
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


LATE = 15 * 60                       # seconds: an order's notice is due by then

judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = runs(JOB, judged)

rows = query("""
SELECT o.id, extract(epoch FROM o.shipped_at),
       o.shipped_at <= now() - make_interval(secs => %(late)s::int),
       EXISTS (SELECT 1 FROM mail_outbox m WHERE m.template = 'order-shipped'
                  AND m.order_id = o.id),
       extract(epoch FROM now())
  FROM orders o
 WHERE o.shipped_at > to_timestamp(%(judged)s::float8)
 ORDER BY o.shipped_at, o.id
""", judged=judged, late=LATE)
now = float(rows[0][4]) if rows else None
due = [(int(o), float(at), mailed == "True") for o, at, old, mailed, _ in rows
       if old == "True"]
missing = [(o, at) for o, at, mailed in due if not mailed]
if missing:
    order, at = missing[0]
    run = next((r for r in rs if r[0] >= at + 60), None)
    named = (f"the {JOB} run of {iso(run[0])} did not send it" if run else
             f"no {JOB} run since has sent it")
    more = f" ({len(missing)} orders shipped {window} without their notice)" \
        if len(missing) > 1 else ""
    print(f"{INVARIANT} present: order {order}, shipped at {iso(at)}, has no order-shipped "
          f"mail; {named}{more}")
    sys.exit(1)
if not rs:
    too_soon(JOB, f"no {JOB} run has ended {window}")
if not due:
    if rows:
        wait = int(float(rows[0][1]) + LATE - now) + 1
        print(f"remaining={max(1, wait)} {len(rows)} orders shipped {window}, none fifteen "
              "minutes old yet")
        sys.exit(3)
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, but no order has shipped since")
print(f"{INVARIANT} fixed: {len(due)} orders shipped {window} more than fifteen minutes ago, "
      f"each with its order-shipped mail ({len(rs)} {JOB} runs)")
sys.exit(0)
PY
