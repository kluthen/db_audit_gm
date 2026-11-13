#!/bin/sh
# Sealed check of purpose-retry-without-key (v0.5 master spec 17.2 s4, 17.3;
# vet-lab-centre-orders, clinic-purposes.md section 5, LO2; capture W5 item
# 1): one lab order per consultation and priority since the judged moment, a
# retry answered with its first accession. Judged by runs.
#
# Runs on the runner node as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), CHECK_THRESHOLD (the duplicated
# requests tolerated, 0 by the answer key's default), FAULT_SOURCE (the
# record, <node>/<database>, holding the runner's ledger ops.lab_orders_sent),
# FAULT_LAB (the lab's database, <node>/<database>) and FAULT_JOB (the posting
# job). It reads the judged moment and the job's next run with check-runs,
# both databases as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - A violation (LO2): a request id the centre's account (1) carries on two
#   lab order tests or more, one of them on an order received since then;
#   two orders for one consultation and priority carry the same requests.
# - The witness: a retry since then of a post the lab took although the
#   runner had no answer: a ledger reference posted more than once, answered
#   since the judged moment with an accession whose order the lab received at
#   least WITNESS seconds before that answering run started (the lab took an
#   earlier attempt; a post answered 503 was rolled back and leaves none): the
#   case the fault turns into a second order. Without one nothing tells a
#   fixed script from a planted one.
# Exit 1: more duplicated requests than the threshold, naming the first.
# Exit 0: none beyond it, with the witness. Exit 3 otherwise, remaining= the
# job's next run (a retry needs an answer slower than the runner's timeout).
# Exit 2: it cannot judge.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
WITNESS = 20                         # seconds between the lab's order and the run answering it


def cannot(text):
    print(f"the retry's key cannot be judged: {text}")
    sys.exit(2)


def part(name, default):
    value = os.environ.get(name) or default
    node, _, db = value.partition("/")
    if not (node and db) or "/" in db:
        cannot(f"{name} is {value!r}, not <node>/<database>")
    return node, db


SOURCE = part("FAULT_SOURCE", "records/clinic")
LAB = part("FAULT_LAB", "lab/lab")
JOB = os.environ.get("FAULT_JOB") or "post-lab-orders"
try:
    THRESHOLD = int(os.environ.get("CHECK_THRESHOLD", "0") or "0")
except ValueError:
    cannot(f"CHECK_THRESHOLD is {os.environ.get('CHECK_THRESHOLD')!r}, not an integer")


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

dups = query(LAB, """
SELECT t.request_id, count(*), string_agg(DISTINCT o.client_ref, ', ' ORDER BY o.client_ref),
       min(o.consultation_id)
  FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id = 1 AND t.request_id IN (
         SELECT t2.request_id FROM lab_order_tests t2 JOIN lab_orders o2 ON o2.id = t2.order_id
          WHERE o2.account_id = 1 AND o2.ordered_at > to_timestamp(%(judged)s::float8)
            AND t2.request_id IS NOT NULL)
 GROUP BY t.request_id HAVING count(*) > 1 ORDER BY t.request_id
""", judged=judged)
if len(dups) > THRESHOLD:
    request, n, refs, consultation = dups[0]
    more = f" ({len(dups)} requests on more than one order test {window})" if len(dups) > 1 else ""
    print(f"retry without its key present: consultation {consultation}'s request {request} is on {n} lab "
          f"orders ({refs}){more}")
    sys.exit(1)
tolerated = f"; {len(dups)} duplicated requests tolerated (threshold {THRESHOLD})" if dups else ""
answered = query(SOURCE, """
SELECT client_ref, accession, attempts, extract(epoch FROM answered_at) FROM ops.lab_orders_sent
 WHERE attempts > 1 AND accession IS NOT NULL AND answered_at > to_timestamp(%(judged)s::float8)
 ORDER BY answered_at
""", judged=judged)
ordered = {}
if answered:
    accessions = ",".join(a for _r, a, _n, _t in answered)
    ordered = {o: float(t) for o, t in query(
        LAB, f"SELECT id, extract(epoch FROM ordered_at) FROM lab_orders WHERE id IN ({accessions})")}
retried = [r for r in answered if r[1] in ordered and float(r[3]) - ordered[r[1]] >= WITNESS]
if retried:
    ref, accession, attempts, _at = retried[0]
    print(f"retry without its key fixed: {len(retried)} retried posts {window} answered with their first "
          f"accession ({ref}: accession {accession} after {attempts} attempts), no request on two lab "
          f"orders{tolerated}")
    sys.exit(0)
out = subprocess.run([CHECK_RUNS, "next", JOB], capture_output=True, text=True).stdout
if "remaining=" not in out:
    cannot(f"{JOB} is not in the loaded jobs.yaml, or never due: no run to wait for")
remaining = max(1, int(out.split("remaining=")[1].split()[0]))
print(f"remaining={remaining} no request on two lab orders {window}, but no retry since then of a post the "
      f"lab took unanswered (it needs an answer slower than the runner's timeout){tolerated}")
sys.exit(3)
PY
