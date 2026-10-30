#!/bin/sh
# E3 minimum content (shop-export-declarations, v0.4 master spec 10.4, 12.1
# to 12.3): a declaration carries the fields the gateway's schema lists and
# nothing else: no e-mail, no customer id, no other order's lines.
#
# Runs on the runner node (crm) as root, fed to `sh -s` by gmctl check, with
# CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ). It reads the runs with check-runs and
# the shop's database as gm_check with check-sql; it never runs a job.
#
# - The judged moment: CHECK_SINCE raised to the runner's last reload
#   (check-runs since), before and after the hand-over alike (spec D217).
# - The gateway's schema (gm.md, "Payload schemas"): exactly the keys
#   order_ref, consignee_name, consignee_address, destination_country,
#   lines, total_value, currency; each line exactly sku, description,
#   quantity, value.
# - A violation, for a declaration sent since then: another key, or one
#   missing; a line with other keys; a line whose sku is not a line of its
#   order, or more lines than its order has; an e-mail address anywhere.
# - Witness (12.3): a run since then that sent declarations.
# Exit 1: a declaration beyond the schema, naming its run. Exit 0: every
# run since clean, one sending declarations. Exit 3, remaining= to the
# job's next run: no run since, or none sending. Exit 2: it cannot judge.
#
# Written for the first v0.4 scenario's names (the constants below); the GM
# adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
import os
import subprocess
import sys
from datetime import datetime, timezone

INVARIANT = "E3"
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


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"
rs = runs(JOB, judged)

bad = query("""
WITH spec AS (
  SELECT ARRAY['consignee_address', 'consignee_name', 'currency', 'destination_country',
               'lines', 'order_ref', 'total_value'] AS fields,
         ARRAY['description', 'quantity', 'sku', 'value'] AS line_fields)
SELECT d.id, d.order_id, extract(epoch FROM d.sent_at),
       CASE WHEN k.keys IS DISTINCT FROM s.fields
                THEN 'has the fields ' || array_to_string(k.keys, ', ')
            WHEN jsonb_typeof(d.payload -> 'lines') IS DISTINCT FROM 'array'
                THEN 'has no list of lines'
            WHEN l.bad_keys > 0 THEN 'has a line with other fields than the schema''s'
            WHEN l.alien > 0 THEN 'declares a line that is not one of its order''s'
            WHEN l.n > o.n THEN 'declares ' || l.n || ' lines, its order has ' || o.n
            ELSE 'carries the e-mail address ' || e.address END
  FROM customs_outbox d
 CROSS JOIN spec s
 CROSS JOIN LATERAL (SELECT array_agg(f ORDER BY f) AS keys
                       FROM jsonb_object_keys(CASE WHEN jsonb_typeof(d.payload) = 'object'
                                                   THEN d.payload ELSE '{}' END) AS f) AS k
 CROSS JOIN LATERAL (
       SELECT count(*) AS n,
              count(*) FILTER (WHERE jsonb_typeof(x) IS DISTINCT FROM 'object'
                               OR (SELECT array_agg(f ORDER BY f) FROM jsonb_object_keys(
                                       CASE WHEN jsonb_typeof(x) = 'object' THEN x
                                            ELSE '{}' END) AS f) IS DISTINCT FROM s.line_fields)
                  AS bad_keys,
              count(*) FILTER (WHERE NOT EXISTS (SELECT 1 FROM order_lines ol
                                                  WHERE ol.order_id = d.order_id
                                                    AND ol.sku = x ->> 'sku')) AS alien
         FROM jsonb_array_elements(CASE WHEN jsonb_typeof(d.payload -> 'lines') = 'array'
                                        THEN d.payload -> 'lines' ELSE '[]' END) AS x) AS l
 CROSS JOIN LATERAL (SELECT count(*) AS n FROM order_lines ol WHERE ol.order_id = d.order_id) AS o
  LEFT JOIN LATERAL (
       SELECT y.a[1] AS address
         FROM regexp_matches(d.payload::text, '[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+', 'g') AS y(a)
        LIMIT 1) AS e ON true
 WHERE d.sent_at > to_timestamp(%(judged)s::float8)
   AND (k.keys IS DISTINCT FROM s.fields
        OR jsonb_typeof(d.payload -> 'lines') IS DISTINCT FROM 'array'
        OR l.bad_keys > 0 OR l.alien > 0 OR l.n > o.n OR e.address IS NOT NULL)
 ORDER BY d.sent_at, d.id
""", judged=judged)
if bad:
    declaration, order, at, what = bad[0]
    run = run_of(float(at), rs)
    named = f"the {JOB} run of {iso(run[0])}" if run else f"a write at {iso(float(at))}"
    more = f" ({len(bad)} declarations beyond the schema {window})" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: declaration {declaration} of order {order}, sent by {named}, "
          f"{what}{more}")
    sys.exit(1)
if not rs:
    too_soon(JOB, f"no {JOB} run has ended {window}")
sent = [r for r in rs if r[2] > 0]
if not sent:
    too_soon(JOB, f"{len(rs)} {JOB} runs {window}, none sent a declaration")
print(f"{INVARIANT} fixed: {sum(r[2] for r in sent)} declarations sent {window} by "
      f"{len(sent)} of {len(rs)} {JOB} runs, each within the gateway's schema")
sys.exit(0)
PY
