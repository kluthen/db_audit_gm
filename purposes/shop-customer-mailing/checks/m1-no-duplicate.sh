#!/bin/sh
# M1 no duplicate (shop-customer-mailing, v0.4 master spec 10.3, 12.1 to
# 12.3): at most one order-shipped mail per order, and at most one campaign
# mail per (campaign, customer).
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ) and, when the fault instance sets the
# purpose's parameter `job`, FAULT_JOB (mail-shipped or mail-campaign: judge
# that job only; unset, both). It reads the runs with check-runs and the
# shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: an order with two order-shipped mails or more, or a
#   (campaign, customer) with two campaign mails or more, one of them sent
#   since the judged moment (past duplicates never count, 12.2).
# - Witness (12.3), at each judged job's latest run since: order-shipped
#   mail sent in the half hour before it (orders it could notify again);
#   campaign mail sent before it (leads it could mail again).
# Exit 1: a duplicate, naming its run. Exit 0: every judged job ran since,
# clean, with a witness at its latest run. Exit 3, remaining= to the latest
# next run among the jobs still waiting: a job with no run since, or none
# with a witness. Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "M1"
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


JOBS = ("mail-shipped", "mail-campaign")


def next_in(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
chosen = os.environ.get("FAULT_JOB", "")
if chosen and chosen not in JOBS:
    cannot(f"FAULT_JOB is {chosen!r}, not one of {', '.join(JOBS)}")
jobs = [chosen] if chosen else list(JOBS)
rs = {job: runs(job, judged) for job in jobs}

bad = []
if "mail-shipped" in jobs:
    bad += [("mail-shipped", f"order {o} got {n} order-shipped mails", float(at))
            for o, n, at in query("""
SELECT order_id, count(*), extract(epoch FROM max(sent_at))
  FROM mail_outbox
 WHERE template = 'order-shipped'
   AND order_id IN (SELECT order_id FROM mail_outbox
                     WHERE template = 'order-shipped'
                       AND sent_at > to_timestamp(%(judged)s::float8))
 GROUP BY order_id HAVING count(*) > 1
""", judged=judged)]
if "mail-campaign" in jobs:
    bad += [("mail-campaign", f"customer {c} got {n} mails of campaign {k}", float(at))
            for k, c, n, at in query("""
SELECT m.campaign_id, m.customer_id, count(*), extract(epoch FROM max(m.sent_at))
  FROM mail_outbox m
 WHERE m.campaign_id IS NOT NULL
   AND (m.campaign_id, m.customer_id) IN (
       SELECT campaign_id, customer_id FROM mail_outbox
        WHERE campaign_id IS NOT NULL AND sent_at > to_timestamp(%(judged)s::float8))
 GROUP BY m.campaign_id, m.customer_id HAVING count(*) > 1
""", judged=judged)]
if bad:
    bad.sort(key=lambda b: b[2])
    job, what, at = bad[0]
    run = run_of(at, rs[job])
    named = f"the {job} run of {iso(run[0])}" if run else f"a write at {iso(at)}"
    more = f" ({len(bad)} duplicates {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {what}, the latest by {named}{more}")
    sys.exit(1)

waiting, judged_ok = [], []
for job in jobs:
    if not rs[job]:
        waiting.append((job, f"no {job} run has ended {window}"))
        continue
    latest = rs[job][-1][0]
    if job == "mail-shipped":
        sql = ("SELECT count(*) FROM mail_outbox WHERE template = 'order-shipped' "
               "AND sent_at > to_timestamp(%(latest)s::float8) - interval '30 minutes' "
               "AND sent_at < to_timestamp(%(latest)s::float8)")
    else:
        sql = ("SELECT count(*) FROM mail_outbox m JOIN campaigns k ON k.id = m.campaign_id "
               "WHERE k.active AND m.sent_at < to_timestamp(%(latest)s::float8)")
    witness = int(query(sql, latest=latest)[0][0])
    if witness == 0:
        waiting.append((job, f"{len(rs[job])} {job} runs {window}, clean, but no mail before "
                             "the latest that it could have sent again"))
    else:
        judged_ok.append(f"{len(rs[job])} {job} runs ({witness} mails it could have repeated)")
if waiting:
    remaining = max(next_in(job) for job, _ in waiting)
    print(f"remaining={remaining} {'; '.join(why for _, why in waiting)}")
    sys.exit(3)
print(f"{INVARIANT} fixed: no mail twice {window}: {', '.join(judged_ok)}")
sys.exit(0)
PY
