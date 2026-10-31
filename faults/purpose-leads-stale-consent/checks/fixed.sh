#!/bin/sh
# Sealed check of purpose-leads-stale-consent (v0.4 master spec 12.1 to
# 12.3, 16.2): the win-back leads purpose's L2 (every lead extracted had
# marketing consent at its extracted_at) and the mailing purpose's M2
# (every marketing mail had it at its sent_at), consent being the latest
# marketing-email event, never the opt-in flag; judged on both jobs' runs
# since the judged moment. Adapted from purposes/shop-winback-leads/checks/
# l2-consented.sh and purposes/shop-customer-mailing/checks/m2-consent.sh.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the leads and mails
# without consent tolerated, together; 0 by the answer key's default),
# FAULT_SOURCE (<node>/<database>), FAULT_LEADS_JOB and FAULT_MAIL_JOB. It
# reads the runs with check-runs and the database as gm_check with
# check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - A violation: a lead extracted, or a marketing mail sent, since then
#   whose recipient lacked consent both at that time and a minute before
#   (a withdrawal still committing when the job read is not held against
#   it), whether or not the job ran since.
# - Witnesses (12.3), at each job's latest run since: for the extraction,
#   customers of the segment, not leads, whose latest event then is a
#   withdrawal after a grant; for the campaign, leads not yet mailed whose
#   latest event then is a withdrawal.
# Exit 1: more violations than the threshold, naming the first one's run.
# Exit 0: each job ran since, clean, with a witness at its latest run.
# Exit 3, remaining= to the later next run among the jobs still waiting:
# a job with no run since, or none with a witness. Exit 2: it cannot judge.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

NAME = "purpose-leads-stale-consent"
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
LEADS = os.environ.get("FAULT_LEADS_JOB", "leads-extract")
MAIL = os.environ.get("FAULT_MAIL_JOB", "mail-campaign")
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


def next_in(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


def run_of(ts, rs):
    """The run in whose transaction a row written at `ts` was (log instants are
    whole seconds, truncated)."""
    return next((r for r in rs if r[0] - 1 <= ts < r[1] + 1), None)


# The latest marketing-email event at a moment, and a minute before it.
CONSENT = """
  LEFT JOIN LATERAL (
       SELECT e.granted, e.at, e.source FROM consent_events e
        WHERE e.customer_id = {who} AND e.purpose = 'marketing-email' AND e.at <= {when}
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent ON true
  LEFT JOIN LATERAL (
       SELECT e.granted FROM consent_events e
        WHERE e.customer_id = {who} AND e.purpose = 'marketing-email'
          AND e.at <= {when} - interval '1 minute'
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS earlier ON true"""
LATEST = ("coalesce('withdrawn at ' || to_char(consent.at AT TIME ZONE 'UTC', "
          "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') || ' (' || consent.source || ')', "
          "'no consent event')")
LACKING = ("coalesce(consent.granted, false) = false "
           "AND coalesce(earlier.granted, false) = false")

judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = {LEADS: runs(LEADS, judged), MAIL: runs(MAIL, judged)}

bad = [(float(at), LEADS, f"extracted customer {c} as a lead without consent, the latest "
                          f"event then {latest}")
       for c, at, latest in query(f"""
SELECT l.customer_id, extract(epoch FROM l.extracted_at), {LATEST}
  FROM leads l {CONSENT.format(who='l.customer_id', when='l.extracted_at')}
 WHERE l.extracted_at > to_timestamp(%(judged)s::float8) AND {LACKING}
""", judged=judged)]
bad += [(float(at), MAIL, f"mailed customer {c} (mail {m}) without consent, the latest "
                          f"event then {latest}")
        for m, c, at, latest in query(f"""
SELECT m.id, m.customer_id, extract(epoch FROM m.sent_at), {LATEST}
  FROM mail_outbox m {CONSENT.format(who='m.customer_id', when='m.sent_at')}
 WHERE m.campaign_id IS NOT NULL
   AND m.sent_at > to_timestamp(%(judged)s::float8) AND {LACKING}
""", judged=judged)]
if len(bad) > threshold:
    bad.sort()
    at, job, what = bad[0]
    run = run_of(at, rs[job])
    named = f"the {job} run of {iso(run[0])}" if run else f"a write of {job} at {iso(at)}"
    leads = sum(1 for b in bad if b[1] == LEADS)
    more = (f" ({leads} leads and {len(bad) - leads} marketing mails without consent {window})"
            if len(bad) > 1 else "")
    invariant = "L2" if job == LEADS else "M2"
    print(f"{invariant} present: {named} {what}{more}")
    sys.exit(1)
tolerated = f"; {len(bad)} without consent tolerated (threshold {threshold})" if bad else ""

WITNESS = {
    LEADS: """
SELECT count(*)
  FROM customers c
 CROSS JOIN LATERAL (
       SELECT e.granted, e.at FROM consent_events e
        WHERE e.customer_id = c.id AND e.purpose = 'marketing-email'
          AND e.at <= to_timestamp(%(latest)s::float8)
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent
 WHERE c.last_order_at <= to_timestamp(%(latest)s::float8) - interval '60 days'
   AND c.last_order_at >= to_timestamp(%(latest)s::float8) - interval '365 days'
   AND NOT consent.granted
   AND EXISTS (SELECT 1 FROM consent_events g WHERE g.customer_id = c.id
                  AND g.purpose = 'marketing-email' AND g.granted AND g.at < consent.at)
   AND NOT EXISTS (SELECT 1 FROM leads l WHERE l.customer_id = c.id
                      AND l.extracted_at < to_timestamp(%(latest)s::float8))
""",
    MAIL: """
SELECT count(*)
  FROM leads l
  JOIN campaigns k ON k.id = l.campaign_id
 CROSS JOIN LATERAL (
       SELECT e.granted FROM consent_events e
        WHERE e.customer_id = l.customer_id AND e.purpose = 'marketing-email'
          AND e.at <= to_timestamp(%(latest)s::float8)
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent
 WHERE k.active
   AND l.extracted_at < to_timestamp(%(latest)s::float8)
   AND NOT consent.granted
   AND NOT EXISTS (SELECT 1 FROM mail_outbox m
                    WHERE m.campaign_id = l.campaign_id AND m.customer_id = l.customer_id
                      AND m.sent_at < to_timestamp(%(latest)s::float8))
""",
}
WHAT = {LEADS: "customers of the segment had withdrawn", MAIL: "waiting leads had withdrawn"}

waiting, judged_ok = [], []
for job in (LEADS, MAIL):
    if not rs[job]:
        waiting.append((job, f"no {job} run has ended {window}"))
        continue
    witness = int(query(WITNESS[job], latest=rs[job][-1][0])[0][0])
    if witness == 0:
        waiting.append((job, f"{len(rs[job])} {job} runs {window}, clean, but none of the "
                             "customers it read at the latest had withdrawn consent"))
    else:
        judged_ok.append(f"{len(rs[job])} {job} runs ({witness} {WHAT[job]} at the latest)")
if waiting:
    remaining = max(next_in(job) for job, _ in waiting)
    print(f"remaining={remaining} {'; '.join(why for _, why in waiting)}{tolerated}")
    sys.exit(3)
print(f"L2 and M2 fixed: every lead and marketing mail {window} with consent by the latest "
      f"event: {', '.join(judged_ok)}{tolerated}")
sys.exit(0)
PY
