#!/bin/sh
# Sealed check of purpose-mail-overlapping-window (v0.4 master spec 12.1 to
# 12.3, 16.2): the customer mailing purpose's M1 for the shipping notices,
# at most one order-shipped mail per order, judged on the job's runs since
# the judged moment. Adapted from purposes/shop-customer-mailing/checks/
# m1-no-duplicate.sh, narrowed to the notices' job.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the duplicates
# tolerated, 0 by the answer key's default), FAULT_SOURCE (<node>/<database>
# holding mail_outbox) and FAULT_JOB (the notices' job). It reads the runs
# with check-runs and the database as gm_check with check-sql; it never
# runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: an order with two order-shipped mails or more, one of them
#   sent since the judged moment (past duplicates never count, 12.2).
# - Witness (12.3), at the job's latest run since: order-shipped mail sent
#   in the half hour before it, orders it could have notified again.
# Exit 1: more duplicates than the threshold, naming the latest one's run.
# Exit 0: a run since, clean, with a witness at the latest. Exit 3,
# remaining= to the job's next run: no run since, or no witness. Exit 2: it
# cannot judge.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

NAME = "purpose-mail-overlapping-window"
CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"


def cannot(text):
    print(f"{NAME} cannot be judged: {text}")
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


source = os.environ.get("FAULT_SOURCE", "db/shop")
JOB = os.environ.get("FAULT_JOB", "mail-shipped")
DB = tuple(source.split("/", 1)) if source.count("/") == 1 else None
if DB is None or not all(DB):
    cannot(f"FAULT_SOURCE is {source!r}, not <node>/<database>")
try:
    threshold = int(os.environ.get("CHECK_THRESHOLD", "0") or "0")
except ValueError:
    cannot(f"CHECK_THRESHOLD is {os.environ.get('CHECK_THRESHOLD')!r}, not an integer")


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


def too_soon(why):
    out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def run_of(ts, rs):
    """The run in whose transaction a row written at `ts` was (log instants are
    whole seconds, truncated)."""
    return next((r for r in rs if r[0] - 1 <= ts < r[1] + 1), None)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = runs(JOB, judged)

bad = query("""
SELECT order_id, count(*), extract(epoch FROM max(sent_at))
  FROM mail_outbox
 WHERE template = 'order-shipped'
   AND order_id IN (SELECT order_id FROM mail_outbox
                     WHERE template = 'order-shipped'
                       AND sent_at > to_timestamp(%(judged)s::float8))
 GROUP BY order_id HAVING count(*) > 1
 ORDER BY max(sent_at) DESC, order_id
""", judged=judged)
if len(bad) > threshold:
    order, n, at = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} orders notified twice or more {window})" if len(bad) > 1 else ""
    print(f"M1 present: order {order} got {n} order-shipped mails, the latest by {named}{more}")
    sys.exit(1)
tolerated = f", {len(bad)} duplicates tolerated (threshold {threshold})" if bad else ""

if not rs:
    too_soon(f"no {JOB} run has ended {window}{tolerated}")
latest = rs[-1][0]
witness = int(query("""
SELECT count(*) FROM mail_outbox
 WHERE template = 'order-shipped'
   AND sent_at > to_timestamp(%(latest)s::float8) - interval '30 minutes'
   AND sent_at < to_timestamp(%(latest)s::float8)
""", latest=latest)[0][0])
if witness == 0:
    too_soon(f"{len(rs)} {JOB} runs {window}, clean, but no notice sent in the half hour "
             f"before the latest that it could have sent again{tolerated}")
print(f"M1 fixed: no shipping notice twice {window}: {len(rs)} {JOB} runs, {witness} notices "
      f"sent in the half hour before the latest{tolerated}")
sys.exit(0)
PY
