# from vet-core@regional-franchise: domains/vet-core/producers/partners/centres/db/centres_tick.py
"""The other centres' tick and own requests, their database side (vet-core's
centres stub): as the role centres, on partners; the posts to clinic-api
through the connection centres-clinic (purpose 4's exchange endpoints).

- An answer (a request the clinic made): an examination declined one time in
  ten, else accepted for a working day one to ten days ahead (a transfer for
  the day itself), a hash of the key; posted once due, and again after a
  resend (answer_posts below requests). An accepted examination's report is
  due one to three days after it, 10:00-17:00 local.
- A centre's own request: an examination (the six reasons of core_exchange,
  D413), for a patient of its own (dog, cat, horse or cow, D413), keyed
  md5('vet-core-centre-request:' || m)::uuid, m continuing the history's
  (100 701 on, the history's ending at 100 700), the site the hostname's
  (aldermoor-abroad one of its three by m). Written before its post; posted
  again by the next tick while clinic-api has not taken it, under the same
  key (never a new one).

A post clinic-api refuses (an error status, a timeout) stays due for the next
tick."""

import hashlib
import uuid
from datetime import datetime, time, timedelta, timezone

import gm_api

BATCH = 5
SITES = {"aldermoor-central": ("ALD-C",), "aldermoor-south": ("ALD-S",),
         "aldermoor-abroad": ("ALD-BE", "ALD-DE", "ALD-LU")}
REASONS = ("CT examination", "MRI examination", "scintigraphy", "second opinion", "endoscopy",
           "cardiology examination")
SPECIES = ("dog", "cat", "horse", "cow")
REPORTS = ("Examination performed; findings consistent with the referral. Report attached.",
           "No significant abnormality detected; follow-up at the home centre.",
           "Lesion confirmed; treatment plan proposed. Report attached.")
FIRST_REF = 100701


def u(key, salt):
    """A draw in [0, 1) from a key, never random (centres_exchanges.u's
    formula: a db/ module imports psycopg, the standard library and gm_api
    only)."""
    return int(hashlib.sha256(f"centres:{key}:{salt}".encode()).hexdigest()[:8], 16) / 2 ** 32


def _utc(value):
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _post(clinic, path, body):
    try:
        return clinic.post(path, body).status in (200, 201)
    except gm_api.HttpError:
        return False


def _offset(conn, hostname):
    row = conn.execute("SELECT value FROM centres.state WHERE hostname = %s AND name = 'utc_offset'",
                       (hostname,)).fetchone()
    return int(row[0]) if row else 0


def _answer(key, kind, now_local):
    """(answer, accepted_for) of the centre for the key."""
    if kind == "examination" and u(key, "decline") < 0.1:
        return "declined", None
    if kind == "transfer":
        return "accepted", now_local.date()
    day = now_local.date() + timedelta(days=1 + int(9 * u(key, "date")))
    while day.weekday() >= 5:
        day += timedelta(days=1)
    return "accepted", day


def tick(hostname):
    """-> {answered, reported, requested, refused}."""
    if hostname not in SITES:
        return {"answered": 0, "reported": 0, "requested": 0, "refused": 0}
    clinic = gm_api.client("centres-clinic")
    out = {"answered": 0, "reported": 0, "requested": 0, "refused": 0}
    with gm_api.connection("centres-db") as conn:
        offset = _offset(conn, hostname)
        answers = conn.execute(
            "SELECT exchange_key::text, kind, answer, accepted_for FROM centres.exchanges "
            "WHERE hostname = %s AND asked_by = 'customer' AND received_at IS NOT NULL "
            "AND ((answered_at IS NULL AND due_at <= now()) OR (answered_at IS NOT NULL AND answer_posts < requests)) "
            "ORDER BY due_at, exchange_key LIMIT %s", (hostname, BATCH)).fetchall()
        reports = conn.execute(
            "SELECT exchange_key::text FROM centres.exchanges "
            "WHERE hostname = %s AND asked_by = 'customer' AND answer = 'accepted' AND kind = 'examination' "
            "AND reported_at IS NULL AND report_due_at <= now() ORDER BY report_due_at, exchange_key LIMIT %s",
            (hostname, BATCH)).fetchall()
        unposted = conn.execute(
            "SELECT exchange_key::text, site_code, kind, ref, reason, patient, requested_at FROM centres.exchanges "
            "WHERE hostname = %s AND asked_by = 'centre' AND posted_at IS NULL "
            "AND requested_at > now() - interval '1 day' ORDER BY requested_at LIMIT %s",
            (hostname, BATCH)).fetchall()
        conn.rollback()
        now = datetime.now(timezone.utc)
        now_local = now + timedelta(hours=offset)
        for key, kind, kept, kept_for in answers:
            answer, accepted_for = (kept, kept_for) if kept else _answer(key, kind, now_local)
            body = {"answer": answer, "accepted_for": accepted_for.isoformat() if accepted_for else None,
                    "answered_at": _utc(now)}
            if not _post(clinic, f"/exchanges/{key}/answer", body):
                out["refused"] += 1
                continue
            report_due = None
            if answer == "accepted" and kind == "examination":
                local = datetime.combine(accepted_for + timedelta(days=1 + int(3 * u(key, "report"))), time(10)) \
                    + timedelta(hours=7 * u(key, "report-hour"))
                report_due = (local - timedelta(hours=offset)).replace(tzinfo=timezone.utc)
            conn.execute(
                "UPDATE centres.exchanges SET answer = %s, accepted_for = %s, answered_at = coalesce(answered_at, now()), "
                "answer_posts = answer_posts + 1, report_due_at = coalesce(report_due_at, %s) WHERE exchange_key = %s",
                (answer, accepted_for, report_due, key))
            conn.commit()
            out["answered"] += 1
        for (key,) in reports:
            body = {"report": REPORTS[int(3 * u(key, "report-text"))], "reported_at": _utc(now)}
            if not _post(clinic, f"/exchanges/{key}/report", body):
                out["refused"] += 1
                continue
            conn.execute("UPDATE centres.exchanges SET reported_at = now() WHERE exchange_key = %s", (key,))
            conn.commit()
            out["reported"] += 1
        for key, site, kind, ref, reason, patient, requested_at in unposted:
            if not _post(clinic, "/exchanges", _request_body(key, site, kind, ref, reason, patient, requested_at)):
                out["refused"] += 1
                continue
            conn.execute("UPDATE centres.exchanges SET posted_at = now() WHERE exchange_key = %s", (key,))
            conn.commit()
            out["requested"] += 1
    return out


def _request_body(key, site, kind, ref, reason, patient, requested_at):
    species, _, age = (patient or "").partition(", ")
    return {"exchange_key": key, "site": site, "kind": kind, "reason": reason, "requested_at": _utc(requested_at),
            "patient": {"ref": ref, "species": species, "age_years": int(age.split()[0]) if age else None}}


def request(hostname):
    """One new request of the centre's, posted -> {requested, refused}."""
    if hostname not in SITES:
        return {"requested": 0, "refused": 0}
    clinic = gm_api.client("centres-clinic")
    with gm_api.connection("centres-db") as conn:
        conn.execute("SELECT pg_advisory_xact_lock(hashtext('centres.request'))")
        (m,) = conn.execute("SELECT greatest(coalesce(max(ref), 0) + 1, %s) FROM centres.exchanges "
                            "WHERE asked_by = 'centre'", (FIRST_REF,)).fetchone()
        key = str(_uuid(f"vet-core-centre-request:{m}"))
        sites = SITES[hostname]
        site = sites[int(len(sites) * u(m, "site"))]
        reason = REASONS[int(len(REASONS) * u(m, "reason"))]
        patient = f"{SPECIES[int(len(SPECIES) * u(m, 'species'))]}, {1 + int(14 * u(m, 'age'))} years"
        (requested_at,) = conn.execute(
            "INSERT INTO centres.exchanges (exchange_key, hostname, site_code, asked_by, kind, ref, reason, patient, "
            "requested_at) VALUES (%s, %s, %s, 'centre', 'examination', %s, %s, %s, now()) RETURNING requested_at",
            (key, hostname, site, m, reason, patient)).fetchone()
        conn.commit()
        if not _post(clinic, "/exchanges", _request_body(key, site, "examination", m, reason, patient, requested_at)):
            return {"requested": 0, "refused": 1, "exchange_key": key}
        conn.execute("UPDATE centres.exchanges SET posted_at = now() WHERE exchange_key = %s", (key,))
        conn.commit()
    return {"requested": 1, "refused": 0, "exchange_key": key}


def _uuid(text):
    """md5(text)::uuid, as PostgreSQL casts it."""
    return uuid.UUID(hashlib.md5(text.encode()).hexdigest())
