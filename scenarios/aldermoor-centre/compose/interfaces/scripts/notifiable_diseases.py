"""The notifiable diseases (purpose 5, vet-notifiable-diseases;
clinic-purposes.md 9; capture W4 items 0 and 4): notify-vet, notify-lab and
escalate-notifications, script jobs of the centre's integration engine.

Called by the scheduler as notify_vet, notify_lab and escalate(conns, options,
log): `conns["clinic"]` the record as vet_interfaces, `conns["lab"]` the lab
as lab_dispatch (psycopg 3, autocommit off), `conns["receiver"]` the HTTP
client to the authority (credential authority_customer).

A trigger is a vet's notifiable diagnosis, suspected or confirmed
(diagnosis_codes.notifiable A or other; vet-<diagnosis id>), or a lab
notification of any customer's (lab_notifications not yet notified;
lab-<id>). Its deadline: an hour for category A, a day otherwise. What a
notification carries (ND3): the disease, the species, the holding or the
keeper's name and address, the notifier, the date; never the clinical notes.

notify_vet and notify_lab, every five minutes:
1. One read, its transaction ended before any call: the new triggers (the
   vets' since the `vet` watermark, less ten minutes for a late commit; the
   lab's not yet notified), each with no ops.notifications row, at most
   options["batch"]; and the retries: the notifications of the last two days
   with no reference whose last post got no answer or a 5xx (the authority's
   standing 503, one call in fifty).
2. The posts, POST /notifications, keyed notification_key.
3. One transaction in the trigger's database: the run's ops.runs row, one
   ops.notifications row a new trigger (its payload, attempts, last status,
   reference), each retry's row updated; for the lab, a referenced
   notification's notified_at, channel (authority-api) and authority_ref
   written back; the `vet` watermark moved. Commit.

escalate, every fifteen minutes, in each database: each notification with no
reference past its deadline, or rejected (a 4xx), and no incident yet: one
ops.incidents row (kind unreferenced or rejected, ref the key), once; one
ops.runs row in each database, the same job and started_at.

Logs keys and statuses only, never a name. Returns the rows written. Imports
nothing but the standard library.
"""

import datetime
import json

PURPOSE = "vet-notifiable-diseases"
OVERLAP = datetime.timedelta(minutes=10)
DEADLINE = {"A": datetime.timedelta(hours=1), "other": datetime.timedelta(days=1)}
CENTRE = "Aldermoor Veterinary Hospital North"

VET_NEW = (
    "SELECT d.id, d.code, dc.label, dc.notifiable, d.confirmed, d.recorded_at, c.animal_id, c.herd_id, c.vet_id"
    " FROM diagnoses d JOIN diagnosis_codes dc ON dc.code = d.code JOIN consultations c ON c.id = d.consultation_id"
    " WHERE dc.notifiable <> 'none' AND d.recorded_at >= %s"
    " AND NOT EXISTS (SELECT 1 FROM ops.notifications n WHERE n.trigger = 'vet' AND n.trigger_id = d.id)"
    " ORDER BY d.recorded_at, d.id LIMIT %s")
LAB_NEW = (
    "SELECT n.id, n.diagnosis_code, n.category, n.suspected_at, o.species, o.client_surname, o.account_id,"
    " o.patient_ref, a.kind"
    " FROM lab_notifications n JOIN lab_order_tests t ON t.id = n.order_test_id"
    " JOIN lab_orders o ON o.id = t.order_id JOIN lab_accounts a ON a.id = o.account_id"
    " WHERE n.notified_at IS NULL"
    " AND NOT EXISTS (SELECT 1 FROM ops.notifications x WHERE x.trigger = 'lab' AND x.trigger_id = n.id)"
    " ORDER BY n.suspected_at, n.id LIMIT %s")
RETRIES = (
    "SELECT id, trigger_id, notification_key, payload FROM ops.notifications"
    " WHERE trigger = %s AND reference IS NULL AND (last_status IS NULL OR last_status >= 500)"
    " AND first_sent_at > now() - interval '2 days' ORDER BY first_sent_at, id LIMIT %s")
KEEPER = ("SELECT o.name, o.address, o.country FROM owners o WHERE o.id = %s")
OWNER = ("SELECT w.owner_id FROM ownerships w WHERE w.animal_id = %s AND w.role = 'owner' AND w.until_at IS NULL"
         " ORDER BY w.from_at DESC LIMIT 1")


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _iso(value):
    return value.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _post(auth, payload):
    """-> (status or None, the reference or None, the answer's time)."""
    try:
        answer = auth.post("/notifications", payload)
    except auth.HttpError:
        return None, None, _now()
    reference = None
    if answer.status == 201:
        reference = (answer.json() or {}).get("reference")
    return answer.status, reference, _now()


def _keeper(cur, owner_id):
    cur.execute(KEEPER, (owner_id,))
    row = cur.fetchone()
    return dict(zip(("name", "address", "country"), row)) if row else None


def _vet_payload(cur, row):
    did, code, label, category, confirmed, recorded_at, animal_id, herd_id, vet_id = row
    payload = {"notification_key": f"vet-{did}",
               "disease": {"code": code, "label": label, "category": category},
               "status": "confirmed" if confirmed else "suspected", "date": _iso(recorded_at)}
    if herd_id is not None:
        cur.execute("SELECT holding_number, keeper_owner_id FROM herds WHERE id = %s", (herd_id,))
        holding, keeper_id = cur.fetchone()
        payload["species"] = "herd"
        payload["holding"] = {"number": holding, "keeper": _keeper(cur, keeper_id)}
    else:
        cur.execute("SELECT species FROM animals WHERE id = %s", (animal_id,))
        got = cur.fetchone()
        payload["species"] = got[0] if got else None
        cur.execute(OWNER, (animal_id,))
        owner = cur.fetchone()
        payload["keeper"] = _keeper(cur, owner[0]) if owner else None
    cur.execute("SELECT name FROM staff WHERE id = %s", (vet_id,))
    vet = cur.fetchone()
    payload["notifier"] = {"kind": "vet", "name": vet[0] if vet else None, "practice": CENTRE}
    return payload


def _lab_payload(row):
    nid, code, category, suspected_at, species, surname, account_id, patient_ref, account_kind = row
    return {"notification_key": f"lab-{nid}",
            "disease": {"code": code, "category": category}, "status": "suspected",
            "date": _iso(suspected_at), "species": species,
            "keeper": {"name": surname, "account": account_id, "patient_ref": patient_ref,
                       "customer": "the centre" if account_kind == "internal" else "a practice"},
            "notifier": {"kind": "lab", "name": f"{CENTRE}, clinical pathology laboratory"}}


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


def _notify(conns, options, log, trigger):
    db = conns["clinic" if trigger == "vet" else "lab"]
    auth = conns["receiver"]
    batch = int(options.get("batch", 20))
    started = _now()
    mark = None
    with db.cursor() as cur:
        cur.execute("SELECT now()")
        (read_at,) = cur.fetchone()
        if trigger == "vet":
            cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = 'vet'", (PURPOSE,))
            got = cur.fetchone()
            mark = got[0] if got and got[0] is not None else read_at
            cur.execute(VET_NEW, (mark - OVERLAP, batch))
            new = [(r[0], r[3], r[5], _vet_payload(cur, r)) for r in cur.fetchall()]
        else:
            cur.execute(LAB_NEW, (batch,))
            new = [(r[0], r[2], r[3], _lab_payload(r)) for r in cur.fetchall()]
        cur.execute(RETRIES, (trigger, batch))
        retries = cur.fetchall()
    db.commit()

    posted_new, posted_retry = [], []
    for tid, category, triggered_at, payload in new:
        status, reference, at = _post(auth, payload)
        log(f"key={payload['notification_key']} status={status} new")
        posted_new.append((tid, category, triggered_at, payload, status, reference, at))
    for nid, tid, key, payload in retries:
        status, reference, at = _post(auth, payload)
        log(f"key={key} status={status} retry")
        posted_retry.append((nid, tid, status, reference, at))

    referenced = [(p[0], p[5], p[6]) for p in posted_new if p[5]] + [(p[1], p[3], p[4]) for p in posted_retry if p[3]]
    written = 1 + len(posted_new) + len(posted_retry) + (len(referenced) if trigger == "lab" else 0) \
        + (1 if trigger == "vet" else 0)
    job = "notify-vet" if trigger == "vet" else "notify-lab"
    with db.cursor() as cur:
        run_id = _run_row(cur, job, started, len(new) + len(retries), written)
        for tid, category, triggered_at, payload, status, reference, at in posted_new:
            cur.execute(
                "INSERT INTO ops.notifications (run_id, trigger, trigger_id, notification_key, category, triggered_at,"
                " deadline, payload, first_sent_at, last_sent_at, attempts, last_status, reference, referenced_at)"
                " VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, 1, %s, %s, %s)",
                (run_id, trigger, tid, payload["notification_key"], category, triggered_at,
                 triggered_at + DEADLINE[category], json.dumps(payload), at, at, status, reference,
                 at if reference else None))
        for nid, _tid, status, reference, at in posted_retry:
            cur.execute(
                "UPDATE ops.notifications SET run_id = %s, last_sent_at = %s, attempts = attempts + 1,"
                " last_status = %s, reference = %s, referenced_at = CASE WHEN %s::text IS NULL THEN NULL ELSE %s END"
                " WHERE id = %s AND reference IS NULL",
                (run_id, at, status, reference, reference, at, nid))
        if trigger == "lab":
            for tid, reference, at in referenced:
                cur.execute("UPDATE lab_notifications SET notified_at = %s, channel = 'authority-api',"
                            " authority_ref = %s WHERE id = %s AND notified_at IS NULL", (at, reference, tid))
        else:
            moved = new[-1][2] if len(new) >= batch else read_at
            cur.execute("UPDATE ops.watermarks SET at = %s, run_id = %s WHERE purpose = %s AND name = 'vet'",
                        (max(moved, mark), run_id, PURPOSE))
    db.commit()
    return written


def notify_vet(conns, options, log):
    return _notify(conns, options, log, "vet")


def notify_lab(conns, options, log):
    return _notify(conns, options, log, "lab")


def escalate(conns, options, log):
    started = _now()
    written = 0
    for name in ("clinic", "lab"):
        db = conns[name]
        with db.cursor() as cur:
            cur.execute(
                "SELECT n.notification_key, CASE WHEN n.last_status BETWEEN 400 AND 499 THEN 'rejected'"
                " ELSE 'unreferenced' END, n.deadline"
                " FROM ops.notifications n"
                " WHERE n.reference IS NULL AND (now() > n.deadline OR n.last_status BETWEEN 400 AND 499)"
                " AND NOT EXISTS (SELECT 1 FROM ops.incidents i WHERE i.purpose = %s"
                "                   AND i.kind IN ('unreferenced', 'rejected') AND i.ref = n.notification_key)"
                " ORDER BY n.deadline, n.id", (PURPOSE,))
            due = cur.fetchall()
            run_id = _run_row(cur, "escalate-notifications", started, len(due), 1 + len(due))
            for key, kind, deadline in due:
                reason = (f"rejected by the authority" if kind == "rejected"
                          else f"no reference by its deadline {_iso(deadline)}")
                cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                            " VALUES (%s, 'escalate-notifications', %s, %s, %s, %s)",
                            (PURPOSE, kind, key, reason, run_id))
                log(f"key={key} escalated {kind}")
        db.commit()
        written += 1 + len(due)
    return written
