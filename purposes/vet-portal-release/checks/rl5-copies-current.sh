#!/bin/sh
# RL5 the copies current (vet-portal-release, purpose 15; vet-portal-domain.md,
# "vet-portal-release", rules 1 and 5): once 10 minutes have passed, every
# owner registered since the judged moment (but the clinic itself) has a
# portal account invited within 10 minutes of the registration; every
# ownership started or ended since it (from_at or until_at after it) is in
# portal_ownerships with the core's until_at, synced within 10 minutes of its
# latest change; every death since it is in portal_animals (status died, the
# core's died_at), synced within 10 minutes. And no closed account has been
# touched since its closure and the judged moment (synced_at after both: the
# load stamps every account, the closed ones included, with its epoch), and
# at any time none holds a display_name, email, phone or password_hash (never
# reopened, its personal columns erased). Judges triggers (the sync slowed or
# stalled, the ownerships' ends never copied, a closed account refilled by the sync).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# and portal are read as gm_check with check-sql, portal's tables through the
# GM's read policy gm_check_read (spec D432: no verdict when it is gone or a
# restrictive policy hides rows); no job is ever run. Exit 0 fixed (with its
# witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=, until
# the earliest change's 10 minutes, or sync-portal-identity's next run).
# Written for the clinic's names (the constants below); the GM adapts them as
# it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "RL5"
PORTAL = ("records", "portal")       # the target part: node, database
CLINIC = ("records", "clinic")       # the source part
DEADLINE = 600                       # seconds from the change to the copy
PURPOSE = "vet-portal-release"
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
BATCH = 300                          # rows per -v value, well under one argument's 128 KiB
GUARD = """
SELECT t.name,
       CASE WHEN c.oid IS NULL THEN 'missing'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read') THEN 'gone'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read'
                                AND p.permissive = 'PERMISSIVE' AND p.cmd IN ('SELECT', 'ALL')
                                AND p.qual = 'true' AND p.roles && ARRAY['public', 'gm_check']::name[])
                 THEN 'changed'
            ELSE 'ok' END,
       coalesce((SELECT string_agg(p.policyname, ',' ORDER BY p.policyname) FROM pg_policies p
                  WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                    AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('SELECT', 'ALL')
                    AND EXISTS (SELECT 1 FROM unnest(p.roles) AS r (role)
                                 WHERE CASE WHEN r.role = 'public' THEN true
                                            ELSE pg_has_role('gm_check', r.role, 'MEMBER') END)), '')
  FROM unnest(string_to_array(%(tables)s, ',')) WITH ORDINALITY AS t (name, i)
  LEFT JOIN pg_class c ON c.oid = to_regclass(t.name)
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
 ORDER BY t.i
"""


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


def query(text, db, **values):
    node, name = db
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


def batched(text, db, rows, **values):
    """The statement once per BATCH of rows, given as the JSON array %(rows)s."""
    out = []
    for i in range(0, len(rows), BATCH):
        out += query(text, db, rows=json.dumps(rows[i:i + BATCH], separators=(",", ":")), **values)
    return out


def guard(tables):
    """Exit 2 unless gm_check reads every row of each portal table (spec D432)."""
    for name, state, hiding in query(GUARD, PORTAL, tables=",".join(tables)):
        if state == "missing":
            cannot(f"{name} is not in {PORTAL[1]}")
        if state == "gone":
            cannot(f"the GM's read policy on {name} is gone")
        if state == "changed":
            cannot(f"the GM's read policy on {name} is changed: it no longer shows gm_check every row")
        if hiding:
            cannot(f"a restrictive policy {hiding.split(',')[0]} on {name} hides rows from gm_check")


def wait(job, why):
    """Exit 3, remaining= until the job's next run."""
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def later(seconds, why):
    print(f"remaining={max(1, int(seconds) + 1)} {why}")
    sys.exit(3)


guard(["portal_accounts", "portal_ownerships", "portal_animals"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

# No closed account touched since the judged moment, or refilled at any time.
bad = [f"closed account {a}: {how}" for a, how in query("""
SELECT id, CASE WHEN synced_at > greatest(closed_at, to_timestamp(%(judged)s::float8))
                THEN 'synced ' || ceil(extract(epoch FROM synced_at - closed_at))::bigint || ' s after its closure'
                ELSE 'its ' || concat_ws(', ', CASE WHEN display_name IS NOT NULL THEN 'display_name' END,
                                         CASE WHEN email IS NOT NULL THEN 'email' END,
                                         CASE WHEN phone IS NOT NULL THEN 'phone' END,
                                         CASE WHEN password_hash IS NOT NULL THEN 'password_hash' END)
                     || ' filled again' END
  FROM portal_accounts
 WHERE status = 'closed'
   AND (synced_at > greatest(closed_at, to_timestamp(%(judged)s::float8)) OR display_name IS NOT NULL OR email IS NOT NULL OR phone IS NOT NULL
        OR password_hash IS NOT NULL)
 ORDER BY closed_at, id
""", PORTAL, judged=judged)]

# The changes since the judged moment, in the core: (kind, key fields, change as text, change in seconds).
now = float(query("SELECT extract(epoch FROM now())", CLINIC)[0][0])
changes = query("""
SELECT 'registered', id::text, '', '', '', '', registered_at::text, extract(epoch FROM registered_at)
  FROM owners WHERE kind <> 'clinic' AND registered_at > to_timestamp(%(judged)s::float8)
UNION ALL
SELECT 'ownership', animal_id::text, owner_id::text, role, from_at::text, coalesce(until_at::text, ''),
       greatest(from_at, coalesce(until_at, from_at))::text,
       extract(epoch FROM greatest(from_at, coalesce(until_at, from_at)))
  FROM ownerships
 WHERE from_at > to_timestamp(%(judged)s::float8) OR until_at > to_timestamp(%(judged)s::float8)
UNION ALL
SELECT 'died', id::text, '', '', '', '', died_at::text, extract(epoch FROM died_at)
  FROM animals WHERE died_at > to_timestamp(%(judged)s::float8)
""", CLINIC, judged=judged)
changes = [(k, a, b, role, f, u, at, float(s)) for k, a, b, role, f, u, at, s in changes]
# A trigger is judged once its window has passed, or at once when its output is already
# there (a satisfied trigger cannot fail later); an unsatisfied one inside its window waits.
unripe = {(c[0], c[1]) for c in changes if c[7] + DEADLINE > now}
pending = set()
def late(kind, key, how):
    """True (and the item pending) for an unripe item whose output is missing."""
    if (kind, str(key)) in unripe and (how.startswith("no portal account") or how.startswith("not in the copy")
                                     or how.startswith("still ") or how.startswith("the copy's until_at")):
        pending.add((kind, str(key)))
        return True
    return False

bad += [f"owner {o} registered at {at}: {how}" for o, at, how in batched("""
SELECT x.owner, x.at::text,
       CASE WHEN a.id IS NULL THEN 'no portal account ' || ceil(extract(epoch FROM now() - x.at))::bigint
                                   || ' s after'
            ELSE 'account ' || a.id || ' invited ' || ceil(extract(epoch FROM a.invited_at - x.at))::bigint
                 || ' s after' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (owner integer, at timestamptz)
  LEFT JOIN portal_accounts a ON a.owner_id = x.owner
 WHERE a.id IS NULL OR a.invited_at > x.at + make_interval(secs => %(deadline)s::int)
 ORDER BY x.at, x.owner
""", PORTAL, [{"owner": int(c[1]), "at": c[6]} for c in changes if c[0] == "registered"], deadline=DEADLINE) if not late("registered", o, how)]
bad += [f"animal {an}'s {role} {o} from {f}: {how}" for an, o, role, f, how in batched("""
SELECT x.animal, x.owner, x.role, x.from_at::text,
       CASE WHEN w.animal_id IS NULL THEN 'not in the copy ' || ceil(extract(epoch FROM now() - x.at))::bigint
                                          || ' s after its change'
            WHEN w.until_at IS DISTINCT FROM x.until_at
                 THEN 'the copy''s until_at ' || coalesce(w.until_at::text, 'open') || ', the core''s '
                      || coalesce(x.until_at::text, 'open')
            ELSE 'synced ' || ceil(extract(epoch FROM w.synced_at - x.at))::bigint || ' s after its change' END
  FROM jsonb_to_recordset(%(rows)s::jsonb)
       AS x (animal integer, owner integer, role text, from_at timestamptz, until_at timestamptz, at timestamptz)
  LEFT JOIN portal_ownerships w ON (w.animal_id, w.owner_id, w.role, w.from_at)
                                 = (x.animal, x.owner, x.role, x.from_at)
 WHERE w.animal_id IS NULL OR w.until_at IS DISTINCT FROM x.until_at
    OR w.synced_at > x.at + make_interval(secs => %(deadline)s::int)
 ORDER BY x.at, x.animal
""", PORTAL, [{"animal": int(c[1]), "owner": int(c[2]), "role": c[3], "from_at": c[4], "until_at": c[5] or None,
               "at": c[6]} for c in changes if c[0] == "ownership"], deadline=DEADLINE)
        if not late("ownership", an, how)]
bad += [f"animal {an} died at {at}: {how}" for an, at, how in batched("""
SELECT x.animal, x.at::text,
       CASE WHEN n.animal_id IS NULL THEN 'not in the copy'
            WHEN n.status <> 'died'
                 THEN 'still ' || n.status || ' in the copy ' || ceil(extract(epoch FROM now() - x.at))::bigint
                      || ' s after the death'
            WHEN n.died_at IS DISTINCT FROM x.at THEN 'the copy''s died_at is not the core''s'
            ELSE 'synced ' || ceil(extract(epoch FROM n.synced_at - x.at))::bigint || ' s after the death' END
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (animal integer, at timestamptz)
  LEFT JOIN portal_animals n ON n.animal_id = x.animal
 WHERE n.animal_id IS NULL OR n.status <> 'died' OR n.died_at IS DISTINCT FROM x.at
    OR n.synced_at > x.at + make_interval(secs => %(deadline)s::int)
 ORDER BY x.at, x.animal
""", PORTAL, [{"animal": int(c[1]), "at": c[6]} for c in changes if c[0] == "died"], deadline=DEADLINE) if not late("died", an, how)]

ripe = [c for c in changes if (c[0], c[1]) not in pending]
if bad:
    more = f" ({len(bad)} wrong {window} or among the closed accounts)" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {bad[0]}{more}")
    sys.exit(1)
if ripe:
    n = {k: sum(1 for c in ripe if c[0] == k) for k in ("registered", "ownership", "died")}
    print(f"{INVARIANT} fixed: {n['registered']} registrations, {n['ownership']} ownerships started or ended and "
          f"{n['died']} deaths {window}, each in the portal within {DEADLINE // 60} minutes "
          f"({len(changes) - len(ripe)} still within their 10 minutes); no closed account touched")
    sys.exit(0)
if changes:
    first = min(changes, key=lambda c: c[7])
    later(first[7] + DEADLINE - now, f"a change at {first[6]} is still to be judged")
wait("sync-portal-identity", f"no registration, ownership change or death {window}")
PY
