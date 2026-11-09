#!/bin/sh
# BS3 each imaging request booked within 2 minutes (vet-bookings-sync,
# purpose 11; vet-scheduling-domain.md, "11. vet-bookings-sync"; spec D376,
# D424): every imaging request recorded since the judged moment and not
# cancelled has, within 2 minutes, one live booking (booked or arrived) on
# its study's machine (the procedure catalogue's machine for its
# consultation's section); an urgent one at its machine's first free slot,
# a routine one within two working days (Monday to Friday, local dates).
# The first free slot is rebuilt at the booking's time: no start of the
# machine's slot grid (sched_hours, its type's duration from the opening)
# between the booking and its start where the machine was free and an
# operator of its kind on a shift covering it, absent from no absence, free
# of any allocation live then. Judges triggers (T113: urgent booked as
# routine; T114: a second booking for one request).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); clinic
# is read as gm_check with check-sql; no job is ever run. Exit 0 fixed (with
# its witness, 12.3), 1 present, 2 cannot judge, 3 too soon (remaining=).
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "BS3"
DB = ("records", "clinic")           # the source and target part: node, database
PURPOSE = "vet-bookings-sync"
DEADLINE = 120                       # seconds, 2 minutes
# The study codes' machines (domestic, horse, farm), as vet-scheduling's load.
MACHINES = """
('DX-THX-S', 11, NULL, NULL), ('DX-ABD-S', 11, NULL, NULL), ('DX-LIMB-S', 11, NULL, NULL),
('DX-SPN-S', 11, NULL, NULL), ('US-ABD-S', 14, NULL, NULL), ('US-ECHO-S', 14, NULL, NULL),
('US-THX-S', 14, NULL, NULL), ('CT-HEAD-S', 7, NULL, NULL), ('CT-TAB-S', 7, NULL, NULL),
('CT-LSP-S', 7, NULL, NULL), ('MR-BRN-S', 9, NULL, NULL), ('MR-SPN-S', 9, NULL, NULL),
('DX-FOOT-L', NULL, 12, 13), ('DX-FTLK-L', NULL, 12, 13), ('DX-CRHK-L', NULL, 12, 13),
('DX-STFL-L', NULL, 12, 13), ('DX-HEAD-L', NULL, 12, 13), ('DX-NKBK-L', NULL, 12, 13),
('DX-THX-L', NULL, 12, 13), ('US-TEND-L', NULL, 15, 15), ('US-ABD-L', NULL, 15, 15),
('US-THX-L', NULL, 15, 15), ('US-REPR-L', NULL, 15, 15), ('CT-HEAD-L', NULL, 8, 8),
('CT-LIMB-L', NULL, 8, 8), ('MR-LIMB-H', NULL, 10, NULL), ('NM-BONE-H', NULL, 16, NULL),
('DX-VIEW-A', 11, 12, 13), ('US-GUID-A', 14, 15, 15), ('DX-CONT-A', 11, 12, 13)"""
import os
import subprocess
import sys
from datetime import datetime, timezone

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


def query(text, db=None, **values):
    node, name = db or DB
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|") for line in helper(argv, text).splitlines()]


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


judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

now = float(query("SELECT extract(epoch FROM now())")[0][0])
rows = query("""
WITH codes (code, m_dom, m_horse, m_farm) AS (VALUES """ + MACHINES + """),
st AS (SELECT timezone FROM sched_settings WHERE id = 1),
rq AS (
  SELECT r.id, r.priority, r.requested_at,
         CASE c.section_id WHEN 3 THEN k.m_dom WHEN 1 THEN k.m_horse ELSE k.m_farm END AS machine
    FROM requests r JOIN consultations c ON c.id = r.consultation_id LEFT JOIN codes k ON k.code = r.code
   WHERE r.kind = 'imaging' AND r.state <> 'cancelled' AND r.requested_at > to_timestamp(%(judged)s::float8)),
bk AS (
  SELECT rq.id, b.id AS booking, b.booked_at, b.starts_at, b.ends_at, b.state, b.type_id,
         (SELECT a.machine_id FROM sched_allocations a WHERE a.booking_id = b.id AND a.role = 'machine' LIMIT 1) AS on_machine
    FROM rq JOIN sched_bookings b ON b.request_id = rq.id AND b.state IN ('booked', 'arrived'))
SELECT rq.id, rq.priority, extract(epoch FROM rq.requested_at), coalesce(rq.machine, 0),
       (SELECT count(*) FROM bk WHERE bk.id = rq.id),
       extract(epoch FROM (SELECT min(bk.booked_at) FROM bk WHERE bk.id = rq.id)),
       coalesce((SELECT min(bk.on_machine) FROM bk WHERE bk.id = rq.id), 0),
       (SELECT bk.booking FROM bk WHERE bk.id = rq.id ORDER BY bk.booked_at LIMIT 1),
       -- routine: the start's working days after the booking's local date
       (SELECT count(*) FROM bk, st, generate_series((bk.booked_at AT TIME ZONE st.timezone)::date + 1,
                                                    (bk.starts_at AT TIME ZONE st.timezone)::date, interval '1 day') AS d
         WHERE bk.id = rq.id AND extract(isodow FROM d) < 6),
       -- urgent: an earlier free start of the machine at the booking's time
       (SELECT min(s) FROM bk, st, sched_types t,
               generate_series((bk.booked_at AT TIME ZONE st.timezone)::date,
                               (bk.starts_at AT TIME ZONE st.timezone)::date, interval '1 day') AS d,
               sched_hours h,
               LATERAL generate_series((d::date + h.opens) AT TIME ZONE st.timezone,
                                       (d::date + h.closes) AT TIME ZONE st.timezone - t.duration_minutes * interval '1 minute',
                                       t.duration_minutes * interval '1 minute') AS s
         WHERE bk.id = rq.id AND rq.priority = 'urgent' AND t.id = bk.type_id
           AND h.resource_kind = 'machine' AND h.resource_id = bk.on_machine AND h.weekday = extract(isodow FROM d)
           AND s >= bk.booked_at AND s < bk.starts_at
           AND NOT EXISTS (SELECT 1 FROM sched_allocations a JOIN sched_bookings o ON o.id = a.booking_id
                            WHERE a.machine_id = bk.on_machine AND o.id <> bk.booking AND o.booked_at <= bk.booked_at
                              AND (a.released_at IS NULL OR a.released_at > bk.booked_at)
                              AND a.during && tstzrange(s, s + t.duration_minutes * interval '1 minute', '[)'))
           AND EXISTS (SELECT 1 FROM generate_series(CASE WHEN bk.on_machine IN (14, 15) THEN 26 ELSE 52 END,
                                                     CASE WHEN bk.on_machine IN (14, 15) THEN 28 ELSE 55 END) AS p
                        WHERE EXISTS (SELECT 1 FROM sched_shifts sh WHERE sh.staff_id = p AND sh.starts_at <= s
                                         AND sh.ends_at >= s + t.duration_minutes * interval '1 minute')
                          AND NOT EXISTS (SELECT 1 FROM sched_absences ab WHERE ab.staff_id = p AND ab.from_at <
                                             s + t.duration_minutes * interval '1 minute' AND ab.until_at > s)
                          AND NOT EXISTS (SELECT 1 FROM sched_allocations a JOIN sched_bookings o ON o.id = a.booking_id
                                           WHERE a.staff_id = p AND o.id <> bk.booking AND o.booked_at <= bk.booked_at
                                             AND (a.released_at IS NULL OR a.released_at > bk.booked_at)
                                             AND a.during && tstzrange(s, s + t.duration_minutes * interval '1 minute', '[)'))))
  FROM rq ORDER BY rq.requested_at, rq.id
""", judged=judged)
triggers = []
for rid, prio, at, machine, n, booked, on, booking, wdays, earlier in rows:
    triggers.append((int(rid), prio, float(at), int(machine), int(n), float(booked) if booked else None,
                     int(on), booking, int(wdays or 0), earlier))
bad = []
for rid, prio, at, machine, n, booked, on, booking, wdays, earlier in triggers:
    due = at + DEADLINE
    if n == 0 and now > due:
        bad.append(f"request {rid} ({prio}), recorded at {iso(at)}, has no live booking {int(now - at)} s later")
    elif n > 1:
        bad.append(f"request {rid} has {n} live bookings")
    elif n == 1 and booked > due:
        bad.append(f"request {rid} booked {int(booked - at)} s after it was recorded")
    elif n == 1 and machine and on != machine:
        bad.append(f"request {rid}'s booking {booking} is on machine {on}, its study's is {machine}")
    elif n == 1 and prio == "urgent" and earlier:
        bad.append(f"urgent request {rid}'s booking {booking} starts after its machine's first free slot "
                   f"({earlier})")
    elif n == 1 and prio == "routine" and wdays > 2:
        bad.append(f"routine request {rid}'s booking {booking} starts {wdays} working days after it was booked")
if bad:
    more = f" ({len(bad)} requests {window} not booked as BS3 states)" if len(bad) > 1 else ""
    print(f"{INVARIANT} present: {bad[0]}{more}")
    sys.exit(1)
old = [t for t in triggers if t[2] <= now - DEADLINE]
if old:
    urgent = sum(1 for t in old if t[1] == "urgent")
    print(f"{INVARIANT} fixed: {len(old)} imaging requests {window} ({urgent} urgent), each booked once on "
          f"its machine within 2 minutes, as its priority asks ({len(triggers) - len(old)} younger)")
    sys.exit(0)
if triggers:
    later(triggers[0][2] + DEADLINE - now, f"request {triggers[0][0]} {window} is still to be judged")
wait("book-requests", f"no imaging request recorded {window}")
PY
