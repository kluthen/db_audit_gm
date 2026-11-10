"""The agenda and the record kept in step (purpose 11, vet-bookings-sync;
vet-scheduling-domain.md, "11. vet-bookings-sync"; capture W4 items 0 and
6; spec D413, D422, D424): check-in, book-requests and cancel-deceased,
script jobs of the centre's integration engine, every minute.

Called by the scheduler as <job>(conns, options, log): `conns["clinic"]` the
record as vet_interfaces, `conns["sched"]` the agenda as sched_interfaces,
both the database clinic (psycopg 3, autocommit off). Every run writes one
ops.runs row in the transaction of its output (the role may insert a run,
never update one, so its counts are known before it); each watermark is the
time of the last row taken (or of the read when the batch was not full),
and every read looks back ten minutes before it (the overlap a late commit
needs: an arrival recorded at 09:00:05 and committed at 09:01:10), the
duplicates found by the job's own existence tests.

check_in: the consultation bookings `arrived` since the `check-in`
watermark (read on the agenda), each with no consultation carrying its id
and no ledger row: its consultation opened in the core (kind scheduled, the
hospital's site, the booking's section, its allocated vet, started at the
arrival, booking_id), its ledger row in ops.booking_consultations, in one
clinic transaction with the run's row and the watermark. A booking with no
animal (an inbound examination's second opinion: the partner's patient is
not registered here) opens nothing.

book_requests: the core's imaging requests recorded since the `requests`
watermark, not cancelled, with no live booking (booked or arrived) for
their id: each booked on its study's machine for its consultation's section
(the procedure catalogue's machines, a copy of vet-scheduling's load) by
sched_free_slots: an urgent one at the machine's first free slot from now
(the same day on a machine around the clock, otherwise the next imaging
day's opening, D424), a routine one at the first free slot of the imaging
day (Monday to Friday 08:00-18:00 at the customer's offset, read from
sched_settings as the load reads it) from an hour after now, so within
two working days (D376). Then the inbound examinations accepted since the
`examinations` watermark with no booking: booking 28 000 + the exchange's
id (D422), on the machine its reason and the partner patient's species name
(D413; a second opinion or an endoscopy a first referral of the species'
section, with a vet and a consultation space), at the first free slot of
the imaging day from the accepted date's opening; on another day, or none
within the agenda's horizon, one ops.incidents row (kind
examination-moved or examination-unbooked, ref the exchange's id). Every
booking with its two allocations, one transaction on the agenda (a slot
taken meanwhile, 23P01, retried once in a savepoint).

cancel_deceased: the animals recorded `died` since the `deaths` watermark:
their future bookings still `booked` cancelled (reason deceased), the
trigger sched_release freeing their resources, in one agenda transaction.

Logs ids and counts only, never a name. Returns the rows written. Imports
nothing but the standard library.
"""

import datetime

PURPOSE = "vet-bookings-sync"
OVERLAP = datetime.timedelta(minutes=10)
LIVE = ["booked", "arrived"]
# The study codes' machines for a domestic, horse and farm animal
# (vet-machinery's procedure catalogue, D372, D373), as vet-scheduling's
# load.sql keeps them: code -> (domestic, horse, farm).
MACHINES = {
    "DX-THX-S": (11, None, None), "DX-ABD-S": (11, None, None), "DX-LIMB-S": (11, None, None),
    "DX-SPN-S": (11, None, None), "US-ABD-S": (14, None, None), "US-ECHO-S": (14, None, None),
    "US-THX-S": (14, None, None), "CT-HEAD-S": (7, None, None), "CT-TAB-S": (7, None, None),
    "CT-LSP-S": (7, None, None), "MR-BRN-S": (9, None, None), "MR-SPN-S": (9, None, None),
    "DX-FOOT-L": (None, 12, 13), "DX-FTLK-L": (None, 12, 13), "DX-CRHK-L": (None, 12, 13),
    "DX-STFL-L": (None, 12, 13), "DX-HEAD-L": (None, 12, 13), "DX-NKBK-L": (None, 12, 13),
    "DX-THX-L": (None, 12, 13), "US-TEND-L": (None, 15, 15), "US-ABD-L": (None, 15, 15),
    "US-THX-L": (None, 15, 15), "US-REPR-L": (None, 15, 15), "CT-HEAD-L": (None, 8, 8),
    "CT-LIMB-L": (None, 8, 8), "MR-LIMB-H": (None, 10, None), "NM-BONE-H": (None, 16, None),
    "DX-VIEW-A": (11, 12, 13), "US-GUID-A": (14, 15, 15), "DX-CONT-A": (11, 12, 13),
}
SECTION_COLUMN = {3: 0, 1: 1, 2: 2}          # the core's sections: 1 horse, 2 farm, 3 domestic
FIRST_REFERRAL = {3: 1, 1: 6, 2: 10}         # a second opinion's or an endoscopy's type
DAY_OPENS, DAY_CLOSES = datetime.time(8, 0), datetime.time(18, 0)    # the imaging day


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _mark(cur, name):
    cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = %s", (PURPOSE, name))
    got = cur.fetchone()
    return got[0] if got and got[0] is not None else None


def _set_mark(cur, name, at, run_id):
    cur.execute("INSERT INTO ops.watermarks (purpose, name, at, run_id) VALUES (%s, %s, %s, %s)"
                " ON CONFLICT (purpose, name) DO UPDATE SET at = EXCLUDED.at, run_id = EXCLUDED.run_id",
                (PURPOSE, name, at, run_id))


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _next_mark(rows, read_at, batch, at_index):
    """The watermark after a read: the last row's time when the batch was
    full (rows remain), else the read's time."""
    return rows[-1][at_index] if len(rows) >= batch else read_at


def _since(mark, read_at):
    return (mark if mark is not None else read_at) - OVERLAP


# --- check-in ---------------------------------------------------------------------------
ARRIVED = (
    "SELECT b.id, b.animal_id, b.section_id, b.arrived_at,"
    " (SELECT a.staff_id FROM sched_allocations a WHERE a.booking_id = b.id AND a.role = 'vet'"
    "   ORDER BY a.id LIMIT 1)"
    " FROM sched_bookings b WHERE b.kind = 'consultation' AND b.state = 'arrived'"
    " AND b.animal_id IS NOT NULL AND b.arrived_at > %s ORDER BY b.arrived_at, b.id LIMIT %s")


def check_in(conns, options, log):
    clinic, sched = conns["clinic"], conns["sched"]
    batch, site = int(options.get("batch", 50)), int(options.get("site", 1))
    started = _now()
    with clinic.cursor() as cur:
        mark = _mark(cur, "check-in")
    with sched.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        cur.execute(ARRIVED, (_since(mark, read_at), batch))
        rows = cur.fetchall()
    sched.rollback()
    with clinic.cursor() as cur:
        todo = []
        for booking, animal, section, arrived, vet in rows:
            cur.execute("SELECT EXISTS (SELECT 1 FROM consultations WHERE booking_id = %s)"
                        " OR EXISTS (SELECT 1 FROM ops.booking_consultations WHERE booking_id = %s)",
                        (booking, booking))
            if cur.fetchone()[0]:
                continue
            if vet is None:
                log(f"booking={booking} has no vet allocated: no consultation opened")
                continue
            todo.append((booking, animal, section, arrived, vet))
        run_id = _run_row(cur, "check-in", started, len(rows), 2 * len(todo))
        for booking, animal, section, arrived, vet in todo:
            cur.execute("INSERT INTO consultations (animal_id, site_id, section_id, vet_id, kind, booking_id,"
                        " started_at) VALUES (%s, %s, %s, %s, 'scheduled', %s, %s) RETURNING id",
                        (animal, site, section, vet, booking, arrived))
            (consultation,) = cur.fetchone()
            cur.execute("INSERT INTO ops.booking_consultations (run_id, booking_id, consultation_id)"
                        " VALUES (%s, %s, %s)", (run_id, booking, consultation))
            log(f"booking={booking} consultation={consultation}")
        _set_mark(cur, "check-in", _next_mark(rows, read_at, batch, 3), run_id)
    clinic.commit()
    return 2 * len(todo) + 2


# --- book-requests ----------------------------------------------------------------------
REQUESTS = (
    "SELECT r.id, r.code, r.priority, r.requested_at, r.animal_id, c.section_id"
    " FROM requests r JOIN consultations c ON c.id = r.consultation_id"
    " WHERE r.kind = 'imaging' AND r.state <> 'cancelled' AND r.requested_at > %s"
    " ORDER BY r.requested_at, r.id LIMIT %s")
EXAMINATIONS = (
    "SELECT x.id, x.reason, coalesce(x.partner_patient, ''), x.accepted_for, x.answered_at"
    " FROM exchanges x WHERE x.direction = 'in' AND x.kind = 'examination' AND x.accepted_for IS NOT NULL"
    " AND x.state IN ('accepted', 'reported') AND x.answered_at > %s ORDER BY x.answered_at, x.id LIMIT %s")
SLOTS = "SELECT starts_at, ends_at, staff_ids, room_id, machine_id FROM sched_free_slots(%s, %s, %s)"


def _species(partner_patient):
    """'partner record C-2/100123: dog, 7 years' -> 'dog' (vet-core's load
    and the centres' stub write it so, D413)."""
    tail = partner_patient.split(": ", 1)[1] if ": " in partner_patient else partner_patient
    return tail.split(",", 1)[0].strip().lower()


def _examination_machine(reason, species):
    """The machine an inbound examination takes, as vet-scheduling's load
    places it (D413); None for a consultation (second opinion, endoscopy)."""
    small = species in ("dog", "cat")
    return {"CT examination": 7 if small else 8, "MRI examination": 10 if species == "horse" else 9,
            "scintigraphy": 16, "cardiology examination": 14 if small else 15}.get(reason)


def _imaging_type(cur, machine, section):
    cur.execute("SELECT id FROM sched_types WHERE kind = 'imaging' AND machine_id = %s"
                " ORDER BY section_id = %s DESC, section_id = 3 DESC, id LIMIT 1", (machine, section))
    got = cur.fetchone()
    return got[0] if got else None


def _in_day(start, end, zone):
    s, e = start.astimezone(zone), end.astimezone(zone)
    return s.isoweekday() <= 5 and s.time() >= DAY_OPENS and e.date() == s.date() and e.time() <= DAY_CLOSES


def _day_slot(cur, type_id, after, zone, imaging_day=True, days=14):
    """The first free slot of the type from `after`, within the imaging day
    when asked: the function's slots taken a day at a time."""
    for _ in range(days):
        cur.execute(SLOTS, (type_id, after, 48))
        slots = cur.fetchall()
        for slot in slots:
            if not imaging_day or _in_day(slot[0], slot[1], zone):
                return slot
        if not slots:
            return None
        local = slots[-1][1].astimezone(zone)
        after = max(slots[-1][1], datetime.datetime.combine(local.date() + datetime.timedelta(days=1),
                                                            DAY_OPENS, zone))
    return None


def _book(cur, values, allocations):
    """One booking and its allocations in a savepoint; -> its id, or None
    when a slot was taken meanwhile (23P01)."""
    try:
        with cur.connection.transaction():
            cur.execute("INSERT INTO sched_bookings (" + ("id, " if values["id"] else "") +
                        "type_id, kind, animal_id, section_id, starts_at, ends_at, state, source, request_id,"
                        " exchange_id, booked_at) VALUES (" + ("%(id)s, " if values["id"] else "") +
                        "%(type)s, %(kind)s, %(animal)s, %(section)s, %(s)s, %(e)s, 'booked', %(source)s,"
                        " %(request)s, %(exchange)s, now()) RETURNING id", values)
            (booking,) = cur.fetchone()
            for staff, room, machine, role in allocations:
                cur.execute("INSERT INTO sched_allocations (booking_id, staff_id, room_id, machine_id, role,"
                            " starts_at, ends_at) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                            (booking, staff, room, machine, role, values["s"], values["e"]))
            return booking
    except Exception as exc:                 # noqa: BLE001 (only a taken slot is retried)
        if getattr(exc, "sqlstate", None) == "23P01":
            return None
        raise


def _slot_allocations(slot, machine):
    starts, ends, staff, room, slot_machine = slot
    if machine is None:
        return [(staff[0], None, None, "vet"), (None, room, None, "room")]
    return [(None, None, slot_machine, "machine"), (staff[0], None, None, "operator")]


def book_requests(conns, options, log):
    clinic, sched = conns["clinic"], conns["sched"]
    batch = int(options.get("batch", 20))
    started = _now()
    with clinic.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        rmark, xmark = _mark(cur, "requests"), _mark(cur, "examinations")
        cur.execute(REQUESTS, (_since(rmark, read_at), batch))
        requests = cur.fetchall()
        cur.execute(EXAMINATIONS, (_since(xmark, read_at), batch))
        examinations = cur.fetchall()
    clinic.rollback()
    written = 0
    incidents = []
    with sched.cursor() as cur:
        cur.execute("SELECT utc_offset FROM sched_settings WHERE id = 1")
        zone = datetime.timezone(datetime.timedelta(hours=cur.fetchone()[0]))
        booked = []
        for rid, code, priority, _at, animal, section in requests:
            cur.execute("SELECT EXISTS (SELECT 1 FROM sched_bookings WHERE request_id = %s AND state = ANY(%s))",
                        (rid, LIVE))
            if cur.fetchone()[0]:
                continue
            machine = (MACHINES.get(code) or (None, None, None))[SECTION_COLUMN.get(section, 0)]
            type_id = _imaging_type(cur, machine, section) if machine else None
            if type_id is None:
                log(f"request={rid} code={code} section={section}: no machine for the study")
                continue
            for _attempt in range(2):
                if priority == "urgent":
                    cur.execute(SLOTS, (type_id, _now(), 1))
                    slot = cur.fetchone()
                else:
                    slot = _day_slot(cur, type_id, _now() + datetime.timedelta(hours=1), zone)
                if slot is None:
                    break
                booking = _book(cur, {"id": None, "type": type_id, "kind": "imaging", "animal": animal,
                                      "section": section, "s": slot[0], "e": slot[1], "source": "request",
                                      "request": rid, "exchange": None}, _slot_allocations(slot, machine))
                if booking is not None:
                    booked.append(booking)
                    log(f"request={rid} booking={booking} machine={machine} priority={priority}")
                    break
            else:
                log(f"request={rid}: its slot taken twice, left for the next run")
        for xid, reason, patient, accepted_for, _at in examinations:
            cur.execute("SELECT EXISTS (SELECT 1 FROM sched_bookings WHERE id = %s OR (exchange_id = %s"
                        " AND state = ANY(%s)))", (28000 + xid, xid, LIVE))
            if cur.fetchone()[0]:
                continue
            species = _species(patient)
            section = {"horse": 1, "cow": 2}.get(species, 3)
            machine = _examination_machine(reason, species)
            type_id = _imaging_type(cur, machine, section) if machine else FIRST_REFERRAL[section]
            opens = datetime.datetime.combine(accepted_for, DAY_OPENS, zone)
            slot = _day_slot(cur, type_id, max(opens, _now()), zone, imaging_day=machine is not None)
            booking = None
            if slot is not None:
                booking = _book(cur, {"id": 28000 + xid, "type": type_id,
                                      "kind": "imaging" if machine else "consultation", "animal": None,
                                      "section": section, "s": slot[0], "e": slot[1], "source": "exchange",
                                      "request": None, "exchange": xid}, _slot_allocations(slot, machine))
            if booking is None:
                incidents.append(("examination-unbooked", xid, f"no free slot for exchange {xid} from"
                                  f" {accepted_for.isoformat()} within the agenda's horizon"))
                continue
            booked.append(booking)
            day = slot[0].astimezone(zone).date()
            log(f"exchange={xid} booking={booking} machine={machine} day={day.isoformat()}")
            if day != accepted_for:
                incidents.append(("examination-moved", xid, f"exchange {xid} booked on {day.isoformat()},"
                                  f" not its accepted date {accepted_for.isoformat()}"))
        written = 3 * len(booked) + len(incidents)
        run_id = _run_row(cur, "book-requests", started, len(requests) + len(examinations), written)
        for kind, xid, why in incidents:
            cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                        " VALUES (%s, 'book-requests', %s, %s, %s, %s)", (PURPOSE, kind, str(xid), why, run_id))
        _set_mark(cur, "requests", _next_mark(requests, read_at, batch, 3), run_id)
        _set_mark(cur, "examinations", _next_mark(examinations, read_at, batch, 4), run_id)
    sched.commit()
    return written + 3


# --- cancel-deceased --------------------------------------------------------------------
def cancel_deceased(conns, options, log):
    clinic, sched = conns["clinic"], conns["sched"]
    batch = int(options.get("batch", 50))
    started = _now()
    with clinic.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        mark = _mark(cur, "deaths")
        cur.execute("SELECT id, died_at FROM animals WHERE status = 'died' AND died_at > %s"
                    " ORDER BY died_at, id LIMIT %s", (_since(mark, read_at), batch))
        deaths = cur.fetchall()
    clinic.rollback()
    with sched.cursor() as cur:
        cancelled = []
        if deaths:
            cur.execute("UPDATE sched_bookings SET state = 'cancelled', cancelled_at = now(),"
                        " cancel_reason = 'deceased' WHERE animal_id = ANY(%s) AND state = 'booked'"
                        " AND starts_at > now() RETURNING id, animal_id", ([d[0] for d in deaths],))
            cancelled = cur.fetchall()
        run_id = _run_row(cur, "cancel-deceased", started, len(deaths), len(cancelled))
        for booking, animal in cancelled:
            log(f"animal={animal} booking={booking} cancelled")
        _set_mark(cur, "deaths", _next_mark(deaths, read_at, batch, 1), run_id)
    sched.commit()
    return len(cancelled) + 2

