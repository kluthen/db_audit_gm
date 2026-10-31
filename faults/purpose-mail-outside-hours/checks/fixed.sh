#!/bin/sh
# Sealed check of purpose-mail-outside-hours (v0.4 master spec 12.1 to
# 12.3, 16.2): the customer mailing purpose's M3, every marketing mail's
# sent_at, in the recipient's local time (customers.timezone), within the
# sending hours (business_settings: from mail_window_start, before
# mail_window_end), judged on the campaign job's runs since the judged
# moment. Adapted from purposes/shop-customer-mailing/checks/
# m3-sending-hours.sh.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the mails outside
# their hours tolerated, 0 by the answer key's default), FAULT_SOURCE
# (<node>/<database>) and FAULT_JOB (the campaign's job). It reads the runs
# with check-runs and the database as gm_check with check-sql; it never runs
# a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - Every zone is the recipient's own, never the server's nor the
#   company's: the check holds at any shift.
# - A violation: a marketing mail sent since then outside its recipient's
#   hours, whether or not the job ran since.
# - Witness (12.3): leads of an active campaign not yet mailed at the latest
#   run's start, with consent then, whose local time then is outside the
#   sending hours.
# Exit 1: more such mails than the threshold, naming the first one's run.
# Exit 0: a run since, clean, a witness at the latest. Exit 3, remaining= to
# the job's next run: no run since the judged moment, or none with a
# witness. Exit 2: it cannot judge.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

NAME = "purpose-mail-outside-hours"
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
JOB = os.environ.get("FAULT_JOB", "mail-campaign")
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
SELECT m.id, m.customer_id, extract(epoch FROM m.sent_at),
       to_char(m.sent_at AT TIME ZONE c.timezone, 'HH24:MI'), c.timezone,
       to_char(s.mail_window_start, 'HH24:MI'), to_char(s.mail_window_end, 'HH24:MI')
  FROM mail_outbox m
  JOIN customers c ON c.id = m.customer_id
 CROSS JOIN business_settings s
 WHERE m.campaign_id IS NOT NULL
   AND m.sent_at > to_timestamp(%(judged)s::float8)
   AND NOT ((m.sent_at AT TIME ZONE c.timezone)::time >= s.mail_window_start
            AND (m.sent_at AT TIME ZONE c.timezone)::time < s.mail_window_end)
 ORDER BY m.sent_at, m.id
""", judged=judged)
if len(bad) > threshold:
    mail, customer, at, local, zone, start, end = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} marketing mails outside their hours {window})" if len(bad) > 1 else ""
    print(f"M3 present: {named} mailed customer {customer} (mail {mail}) at {local} "
          f"their time ({zone}), outside {start}-{end}{more}")
    sys.exit(1)
tolerated = f"; {len(bad)} outside their hours tolerated (threshold {threshold})" if bad else ""
if not rs:
    too_soon(f"no {JOB} run has ended {window}{tolerated}")

latest = rs[-1][0]
witness = int(query("""
SELECT count(*)
  FROM leads l
  JOIN campaigns k ON k.id = l.campaign_id
  JOIN customers c ON c.id = l.customer_id
 CROSS JOIN business_settings s
 CROSS JOIN LATERAL (
       SELECT e.granted FROM consent_events e
        WHERE e.customer_id = l.customer_id AND e.purpose = 'marketing-email'
          AND e.at <= to_timestamp(%(latest)s::float8)
        ORDER BY e.at DESC, e.id DESC LIMIT 1) AS consent
 WHERE k.active
   AND l.extracted_at < to_timestamp(%(latest)s::float8)
   AND consent.granted
   AND NOT ((to_timestamp(%(latest)s::float8) AT TIME ZONE c.timezone)::time
                >= s.mail_window_start
            AND (to_timestamp(%(latest)s::float8) AT TIME ZONE c.timezone)::time
                < s.mail_window_end)
   AND NOT EXISTS (SELECT 1 FROM mail_outbox m
                    WHERE m.campaign_id = l.campaign_id AND m.customer_id = l.customer_id
                      AND m.sent_at < to_timestamp(%(latest)s::float8))
""", latest=latest)[0][0])
if witness == 0:
    too_soon(f"{len(rs)} {JOB} runs {window}, clean, but no lead waiting at the latest was "
             f"outside their hours: none could have been mailed at the wrong time{tolerated}")
print(f"M3 fixed: {len(rs)} {JOB} runs {window}, every marketing mail within its recipient's "
      f"hours; {witness} leads waiting at the latest run were outside theirs{tolerated}")
sys.exit(0)
PY
