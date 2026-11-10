#!/bin/sh
# PR1 each delivery made due acknowledged in time (vet-lab-practice-results,
# v0.5 master spec 12.2 purpose 2; clinic-purposes.md section 6): every
# delivery a practice test's release made due since the judged moment (an
# interim on an order's first release with tests still pending, the final on
# the release completing it, an amended one on an amendment) is acknowledged
# within 15 minutes, or after six failed attempts in an incident. Judged by
# triggers.
#
# Runs on the runner node (interfaces) as root, fed to `sh -s`, with
# CHECK_SINCE; it reads the judged moment with check-runs and the lab as
# gm_check with check-sql (capture W4 item 0).
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload.
# - The deliveries due since then, each by its delivery_key (the
#   purpose's md5('vet-lab-delivery:<order>:<kind>:<revision>')), against
#   lab_callbacks and ops.incidents (kind undelivered, ref the key).
# - Exit 1: one acknowledged more than 15 minutes after its event, or not at
#   all with no incident: never attempted 15 minutes after, or still neither
#   45 minutes after (six attempts five minutes apart end by then).
#   Exit 0: none, with at least one 15 minutes old acknowledged in time or
#   in its incident (the witness). Exit 3 otherwise, remaining= until the
#   youngest is 15 minutes old, the oldest pending one's 45 minutes, or the
#   next run. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below).
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone


INVARIANT = "PR1"
LAB = ("lab", "lab")                 # the source and target parts: node, database
PURPOSE = "vet-lab-practice-results"
JOB = "deliver-practice-results"
WITHIN = 15 * 60                     # seconds from the event to the acknowledgement
GIVE_UP = 45 * 60                    # by then six failed attempts have their incident
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


def query(db, text, **values):
    argv = [CHECK_SQL, "-h", db[0], "-d", db[1]]
    for name, value in values.items():
        argv += ["-v", f"{name}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def num(text):
    return float(text) if text != "" else None


def next_run(job):
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    return max(1, int(out.split("remaining=")[1].split()[0]))


def too_soon(seconds, why):
    print(f"remaining={max(1, int(seconds))} {why}")
    sys.exit(3)


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query(LAB, "SELECT extract(epoch FROM now())")[0][0])
events = [(int(o), kind, int(rev), key, float(at), num(ack), int(n), flag == "True")
          for o, kind, rev, key, at, ack, n, flag in query(LAB, """
WITH o AS MATERIALIZED (
  SELECT o.id, o.completed_at FROM lab_orders AS o JOIN lab_accounts AS a ON a.id = o.account_id
   WHERE a.kind = 'practice' AND o.cancelled_at IS NULL
     AND o.ordered_at > to_timestamp(%(judged)s::float8) - interval '30 days'),
t AS (SELECT t.order_id, count(*) AS n, min(t.released_at) AS fr
        FROM lab_order_tests AS t JOIN o ON o.id = t.order_id GROUP BY t.order_id),
ev AS (
  SELECT o.id, 'interim' AS kind, 1 AS rev, t.fr AS at FROM o JOIN t ON t.order_id = o.id
   WHERE t.n > 1 AND t.fr < coalesce(o.completed_at, 'infinity') AND t.fr > to_timestamp(%(judged)s::float8)
  UNION ALL
  SELECT o.id, 'final', 1, o.completed_at FROM o WHERE o.completed_at > to_timestamp(%(judged)s::float8)
  UNION ALL
  SELECT a.order_id, 'amended', a.rev, a.amended_at
    FROM (SELECT x.order_id, r.amended_at,
                 row_number() OVER (PARTITION BY x.order_id ORDER BY r.amended_at, r.id)::integer AS rev
            FROM lab_results AS r JOIN lab_order_tests AS x ON x.id = r.order_test_id JOIN o ON o.id = x.order_id
           WHERE r.supersedes_id IS NOT NULL AND r.amended_at IS NOT NULL) AS a
   WHERE a.amended_at > to_timestamp(%(judged)s::float8)),
k AS (SELECT ev.*, md5('vet-lab-delivery:' || ev.id || ':' || ev.kind || ':' || ev.rev)::uuid::text AS key FROM ev)
SELECT k.id, k.kind, k.rev, k.key, extract(epoch FROM k.at),
       (SELECT extract(epoch FROM min(c.acknowledged_at)) FROM lab_callbacks AS c WHERE c.delivery_key = k.key),
       (SELECT count(*) FROM lab_callbacks AS c WHERE c.delivery_key = k.key),
       EXISTS (SELECT 1 FROM ops.incidents AS i
                WHERE i.purpose = %(purpose)s AND i.kind = 'undelivered' AND i.ref = k.key)
  FROM k ORDER BY k.at, k.id
""", judged=judged, purpose=PURPOSE)]

late, good, pending = [], [], []
for order, kind, rev, key, at, ack, attempts, incident in events:
    what = f"the {kind} delivery of order {order}" + (f" (revision {rev})" if kind == "amended" else "")
    if incident:
        good.append(at)
    elif ack is not None:
        if ack > at + WITHIN:
            late.append(f"{what} acknowledged {int(ack - at)} s after its event at {iso(at)}")
        else:
            good.append(at)
    elif now > at + WITHIN and attempts == 0:
        late.append(f"{what}, due at {iso(at)}, never attempted {int(now - at)} s after")
    elif now > at + GIVE_UP:
        late.append(f"{what}, due at {iso(at)}, unacknowledged after {attempts} attempts and no incident")
    else:
        pending.append(at + (GIVE_UP if now > at + WITHIN else WITHIN))
if late:
    print(f"{INVARIANT} present: {late[0]}" + (f" ({len(late)} deliveries late {window})" if len(late) > 1 else ""))
    sys.exit(1)
old = [at for at in good if now > at + WITHIN]
if old:
    print(f"{INVARIANT} fixed: {len(old)} deliveries made due {window} at least 15 minutes ago, each acknowledged "
          f"within 15 minutes or in its incident; {len(pending)} pending")
    sys.exit(0)
if good or pending:
    first = min([at + WITHIN for at in good] + pending)
    too_soon(first - now + 1, f"{len(good) + len(pending)} deliveries made due {window}, none 15 minutes old yet")
too_soon(next_run(JOB) + WITHIN, f"no practice delivery made due {window}")
PY
