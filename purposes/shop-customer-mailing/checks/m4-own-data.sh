#!/bin/sh
# M4 own data (shop-customer-mailing, v0.4 master spec 10.3, 12.1 to 12.3):
# every mail's payload names its recipient only: its e-mail and name are the
# recipient's, and any order in it is the recipient's.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ) and, when the fault instance sets the
# purpose's parameter `job`, FAULT_JOB (mail-shipped or mail-campaign: judge
# that job's mail only; unset, both). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation, for a mail sent since then: its email column, or its
#   payload's email or name, not the recipient's (mail_outbox.customer_id);
#   any other e-mail address anywhere in its payload; its order_id, or its
#   payload's, not an order of the recipient.
# - Witness (12.3): a run of each judged job since then that sent mail.
# Exit 1: a mail naming someone else, naming its run. Exit 0: every judged
# job ran since, clean, with a run that sent mail. Exit 3, remaining= to the
# latest next run among the jobs still waiting. Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "M4"
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


JOBS = {"mail-shipped": "m.template = 'order-shipped'", "mail-campaign": "m.campaign_id IS NOT NULL"}


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

bad = query(f"""
SELECT m.id, m.customer_id, extract(epoch FROM m.sent_at),
       CASE WHEN m.email IS DISTINCT FROM c.email THEN 'is addressed to ' || m.email
            WHEN m.payload->>'email' IS DISTINCT FROM c.email
                THEN 'names the e-mail ' || coalesce(m.payload->>'email', '(none)')
            WHEN m.payload->>'name' IS DISTINCT FROM c.name
                THEN 'names ' || coalesce(m.payload->>'name', '(no name)')
            WHEN other.address IS NOT NULL THEN 'carries the e-mail ' || other.address
            WHEN m.order_id IS NOT NULL AND o.customer_id IS DISTINCT FROM m.customer_id
                THEN 'is about order ' || m.order_id || ', not theirs'
            ELSE 'names order ' || (m.payload->>'order_id') || ', not theirs' END,
       CASE WHEN m.campaign_id IS NOT NULL THEN 'mail-campaign' ELSE 'mail-shipped' END
  FROM mail_outbox m
  JOIN customers c ON c.id = m.customer_id
  LEFT JOIN orders o ON o.id = m.order_id
  LEFT JOIN LATERAL (
       SELECT x.a[1] AS address
         FROM regexp_matches(m.payload::text, '[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+', 'g') AS x(a)
        WHERE x.a[1] <> c.email LIMIT 1) AS other ON true
  LEFT JOIN LATERAL (
       SELECT p.customer_id FROM orders p
        WHERE m.payload ? 'order_id' AND m.payload->>'order_id' ~ '^[0-9]{{1,9}}$'
          AND p.id = (m.payload->>'order_id')::integer) AS po ON true
 WHERE m.sent_at > to_timestamp(%(judged)s::float8)
   AND ({' OR '.join(JOBS[j] for j in jobs)})
   AND (m.email IS DISTINCT FROM c.email
        OR m.payload->>'email' IS DISTINCT FROM c.email
        OR m.payload->>'name' IS DISTINCT FROM c.name
        OR other.address IS NOT NULL
        OR (m.order_id IS NOT NULL AND o.customer_id IS DISTINCT FROM m.customer_id)
        OR (m.payload ? 'order_id' AND po.customer_id IS DISTINCT FROM m.customer_id))
 ORDER BY m.sent_at, m.id
""", judged=judged)
if bad:
    mail, customer, at, what, job = bad[0]
    run = run_of(float(at), rs.get(job, []))
    named = f"the {job} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} mails naming someone else {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: mail {mail} to customer {customer}, sent by {named}, {what}"
          f"{more}")
    sys.exit(1)

waiting, judged_ok = [], []
for job in jobs:
    sent = [r for r in rs[job] if r[2] > 0]
    if not rs[job]:
        waiting.append((job, f"no {job} run has ended {window}"))
    elif not sent:
        waiting.append((job, f"{len(rs[job])} {job} runs {window}, none sent mail"))
    else:
        judged_ok.append(f"{len(rs[job])} {job} runs, {sum(r[2] for r in sent)} mails")
if waiting:
    remaining = max(next_in(job) for job, _ in waiting)
    print(f"remaining={remaining} {'; '.join(why for _, why in waiting)}")
    sys.exit(3)
print(f"{INVARIANT} fixed: every mail {window} names its recipient only: {', '.join(judged_ok)}")
sys.exit(0)
PY
