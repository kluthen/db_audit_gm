#!/bin/sh
# E2 declared once (shop-export-declarations, v0.4 master spec 10.4, 12.1
# to 12.3): at most one accepted declaration per order. The gateway accepts
# every well-formed declaration, so two declarations of one order get two
# movement references.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: an order with two declarations or more acknowledged as
#   accepted, one of them sent since the judged moment.
# - A run counts once its declarations had two minutes to be answered (the
#   gateway answers within a minute). Witness (12.3): such a run starting
#   when declarations of its two-hour horizon already existed.
# Exit 1: an order accepted twice, naming its run. Exit 0: every run since
# clean, a witness among them. Exit 3, remaining= to the job's next run, or
# until the latest run has been answered: no run, or none with a witness.
# Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "E2"
DB = ("db", "shop")                  # the source part: node, database
JOB = "declare-exports"
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


ANSWERED = 2 * 60                    # seconds after a run its declarations are answered

judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = runs(JOB, judged)

bad = query("""
SELECT d.order_id, count(DISTINCT d.id), extract(epoch FROM max(d.sent_at)),
       string_agg(DISTINCT a.reference, ', ')
  FROM customs_outbox d
  JOIN customs_acks a ON a.outbox_id = d.id AND a.status = 'accepted'
 WHERE d.order_id IN (SELECT order_id FROM customs_outbox
                       WHERE sent_at > to_timestamp(%(judged)s::float8))
 GROUP BY d.order_id HAVING count(DISTINCT d.id) > 1
 ORDER BY max(d.sent_at), d.order_id
""", judged=judged)
if bad:
    order, n, at, refs = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} orders accepted twice {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: order {order} has {n} accepted declarations ({refs}), the "
          f"latest sent by {named}{more}")
    sys.exit(1)
if not rs:
    too_soon(JOB, f"no {JOB} run has ended {window}")

now = float(query("SELECT extract(epoch FROM now())")[0][0])
answered = [r for r in rs if r[1] <= now - ANSWERED]
if not answered:
    print(f"remaining={max(1, int(rs[0][1] + ANSWERED - now) + 1)} {len(rs)} {JOB} runs "
          f"{window}, the gateway's answers to them still to come")
    sys.exit(3)
latest = answered[-1][0]
witness = int(query("""
SELECT count(*) FROM customs_outbox
 WHERE sent_at > to_timestamp(%(latest)s::float8) - interval '2 hours'
   AND sent_at < to_timestamp(%(latest)s::float8)
""", latest=latest)[0][0])
if witness == 0:
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, clean, but none started with declared "
                  "orders it could have declared again")
print(f"{INVARIANT} fixed: {len(answered)} {JOB} runs {window} answered, no order accepted "
      f"twice; {witness} declarations of the horizon existed at the latest")
sys.exit(0)
PY
