"""The portal's copies and release gate (purpose 15, vet-portal-release;
vet-portal-domain.md, "vet-portal-release"; capture W4 items 0 and 6; spec
D320, D404): sync-portal-identity, publish-records and publish-results,
script jobs of the centre's integration engine, every five minutes.

Called by the scheduler as sync_identity(conns, options, log),
publish_records(conns, options, log) and publish_results(conns, options,
log): `conns["clinic"]` the record as vet_portal_sync, `conns["lab"]` the
lab as lab_release, `conns["portal"]` the portal as portal_sync (psycopg 3,
autocommit off).

Each run reads its sources in one repeatable-read snapshot from its
watermark (ops.watermarks in portal, set at load_epoch by the DDL), then
writes, in one portal transaction, its copies or documents, its watermark
(the latest gate time read, less options["margin_minutes"]; unchanged when
it read nothing) and its ops.runs row. A document already published is
skipped by its source_ref and version, so the margin's re-reads publish
nothing twice.

sync_identity: the owners registered since the watermark (but the clinic
itself): an account `invited` each, unless the owner has one (a closed
account is never touched), its one-time link random (kept as its SHA-256,
expiring after portal_settings' invitation_days) and its invitation queued
in portal_outbox (a random message key, the link in the payload); the
animals registered or dead since it, upserted into portal_animals; the
ownerships started or ended since it, upserted into portal_ownerships (the
ends first, so the copy's one-current-owner index holds through a sale); a
row the copy already holds as read is left alone, its synced_at kept (the
margin's re-reads);
the herds whose keeper differs, upserted into portal_herds.

publish_records: the consultations signed since the watermark and the stays
ended since it: a document each, version 1 (C-<id>, S-<id>), its body built
in the record as the derivation builds it (the diagnoses' labels, the
prescriptions with their withdrawal ends; the stay's dates and outcome; no
findings, no free text).

publish_results: the lab's order tests of options["account"] (1, the
centre) released since the watermark, and their results amended since it:
a document T-<test id> each, version 1 at the release with the values in
force then, one more version at each amendment after it, the former
superseded (superseded_at); the vet's name the releasing or amending
pathologist's, read from the record's staff.

Logs references and counts only (no name, no address). Returns the rows
written. Imports nothing but the standard library.
"""

import datetime
import hashlib
import json
import secrets
import uuid

PURPOSE = "vet-portal-release"


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _margin(options):
    return datetime.timedelta(minutes=int(options.get("margin_minutes", 2)))


def _snapshot(conn):
    """A new repeatable-read transaction on conn (its first statement)."""
    conn.rollback()
    with conn.cursor() as cur:
        cur.execute("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")


def _mark(conn, name, started):
    with conn.cursor() as cur:
        cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = %s", (PURPOSE, name))
        got = cur.fetchone()
    conn.rollback()
    return got[0] if got and got[0] is not None else started


def _close(cur, job, name, started, read, written, gates, mark, margin):
    """The run's ops.runs row and its watermark, in the caller's transaction."""
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    run_id = cur.fetchone()[0]
    at = max(mark, max(gates) - margin) if gates else mark
    cur.execute("INSERT INTO ops.watermarks (purpose, name, at, run_id) VALUES (%s, %s, %s, %s)"
                " ON CONFLICT (purpose, name) DO UPDATE SET at = EXCLUDED.at, run_id = EXCLUDED.run_id",
                (PURPOSE, name, at, run_id))
    return run_id


# --- sync-portal-identity ----------------------------------------------------------------

OWNERS = ("SELECT id, kind, name, email, phone, registered_at FROM owners"
          " WHERE registered_at > %s AND kind <> 'clinic' ORDER BY registered_at, id")
ANIMALS = ("SELECT id, name, species, sex, born_on, herd_id, status, died_at,"
           " greatest(registered_at, coalesce(died_at, registered_at)) FROM animals"
           " WHERE registered_at > %s OR died_at > %s ORDER BY id")
OWNERSHIPS = ("SELECT animal_id, owner_id, role, from_at, until_at, greatest(from_at, coalesce(until_at, from_at))"
              " FROM ownerships WHERE from_at > %s OR until_at > %s"
              " ORDER BY (until_at IS NULL), animal_id, from_at")
NEW_ACCOUNT = (
    "INSERT INTO portal_accounts (owner_id, kind, display_name, email, phone, status, invited_at, invite_hash,"
    " invite_expires_at, synced_at)"
    " SELECT %s, %s, %s, %s, %s, 'invited', now(), %s, now() + s.invitation_days * interval '1 day', now()"
    " FROM portal_settings s WHERE NOT EXISTS (SELECT 1 FROM portal_accounts a WHERE a.owner_id = %s)"
    " LIMIT 1 ON CONFLICT DO NOTHING RETURNING id")
INVITATION = (
    "INSERT INTO portal_outbox (message_key, account_id, owner_id, template, channel, address, payload, queued_at)"
    " VALUES (%s, %s, %s, 'invitation', 'email', %s, %s::jsonb, now())")


def sync_identity(conns, options, log):
    clinic, portal = conns["clinic"], conns["portal"]
    margin, link = _margin(options), options.get("link", "https://portal.example.net/activate/")
    started = _now()
    mark = _mark(portal, "identity", started)
    _snapshot(clinic)
    with clinic.cursor() as cur:
        cur.execute(OWNERS, (mark,))
        owners = cur.fetchall()
        cur.execute(ANIMALS, (mark, mark))
        animals = cur.fetchall()
        cur.execute(OWNERSHIPS, (mark, mark))
        ownerships = cur.fetchall()
        cur.execute("SELECT id, keeper_owner_id FROM herds ORDER BY id")
        herds = cur.fetchall()
    clinic.rollback()
    gates = [o[5] for o in owners] + [a[8] for a in animals] + [w[5] for w in ownerships]
    written = 0
    with portal.cursor() as cur:
        cur.execute("SELECT herd_id, keeper_owner_id FROM portal_herds")
        copied = dict(cur.fetchall())
        for herd, keeper in herds:
            if copied.get(herd) != keeper:
                cur.execute("INSERT INTO portal_herds (herd_id, keeper_owner_id, synced_at) VALUES (%s, %s, now())"
                            " ON CONFLICT (herd_id) DO UPDATE SET keeper_owner_id = EXCLUDED.keeper_owner_id,"
                            " synced_at = EXCLUDED.synced_at", (herd, keeper))
                written += 1
        for aid, name, species, sex, born_on, herd, status, died_at, _ in animals:
            cur.execute("INSERT INTO portal_animals (animal_id, name, species, sex, born_on, herd_id, status, died_at,"
                        " synced_at) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, now())"
                        " ON CONFLICT (animal_id) DO UPDATE SET name = EXCLUDED.name, species = EXCLUDED.species,"
                        " sex = EXCLUDED.sex, born_on = EXCLUDED.born_on, herd_id = EXCLUDED.herd_id,"
                        " status = EXCLUDED.status, died_at = EXCLUDED.died_at, synced_at = EXCLUDED.synced_at"
                        " WHERE (portal_animals.name, portal_animals.species, portal_animals.sex, portal_animals.born_on,"
                        " portal_animals.herd_id, portal_animals.status, portal_animals.died_at) IS DISTINCT FROM"
                        " (EXCLUDED.name, EXCLUDED.species, EXCLUDED.sex, EXCLUDED.born_on, EXCLUDED.herd_id,"
                        " EXCLUDED.status, EXCLUDED.died_at)",
                        (aid, name, species, sex, born_on, herd, status, died_at))
            if not cur.rowcount:
                continue                       # a margin's re-read: the copy already holds it
            written += 1
            if status == "died":
                log(f"animal={aid} died")
        for aid, oid, role, from_at, until_at, _ in ownerships:
            cur.execute("INSERT INTO portal_ownerships (animal_id, owner_id, role, from_at, until_at, synced_at)"
                        " VALUES (%s, %s, %s, %s, %s, now())"
                        " ON CONFLICT (animal_id, owner_id, role, from_at) DO UPDATE SET until_at = EXCLUDED.until_at,"
                        " synced_at = EXCLUDED.synced_at"
                        " WHERE portal_ownerships.until_at IS DISTINCT FROM EXCLUDED.until_at",
                        (aid, oid, role, from_at, until_at))
            if not cur.rowcount:
                continue                       # a margin's re-read: the copy already holds it
            written += 1
            log(f"animal={aid} owner={oid} {role} {'ended' if until_at else 'started'}")
        for oid, kind, name, email, phone, _ in owners:
            token = secrets.token_hex(32)
            cur.execute(NEW_ACCOUNT, (oid, kind, name, email, phone, hashlib.sha256(token.encode()).hexdigest(), oid))
            got = cur.fetchone()
            if got is None:
                log(f"owner={oid} has an account (or its e-mail is taken): no invitation")
                continue
            payload = {"template": "invitation", "name": name, "link": link + token}
            cur.execute(INVITATION, (str(uuid.uuid4()), got[0], oid, email, json.dumps(payload)))
            written += 2
            log(f"owner={oid} account={got[0]} invited")
        _close(cur, "sync-portal-identity", "identity", started, len(owners) + len(animals) + len(ownerships),
               written, gates, mark, margin)
    portal.commit()
    return written + 2


# --- publish-records -------------------------------------------------------------------------

CONSULTATIONS = """
SELECT 'C-' || c.id, c.animal_id, c.herd_id, c.started_at, c.signed_at,
       CASE c.kind WHEN 'herd-visit' THEN 'Herd visit' WHEN 'in-hospital' THEN 'In-hospital examination'
                   WHEN 'emergency' THEN 'Emergency consultation' ELSE 'Consultation' END,
       f.name, 'consultation',
       jsonb_build_object(
           'kind', c.kind, 'section', sc.kind, 'started_at', c.started_at,
           'diagnoses', coalesce((SELECT jsonb_agg(jsonb_build_object('code', g.code, 'label', k.label,
                                                                      'confirmed', g.confirmed) ORDER BY g.id)
                                    FROM diagnoses g JOIN diagnosis_codes k ON k.code = g.code
                                   WHERE g.consultation_id = c.id), '[]'::jsonb),
           'prescriptions', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                                 'medicine', m.name, 'dose', l.dose, 'unit', l.unit,
                                                 'frequency_hours', l.frequency_hours, 'days', l.days,
                                                 'withdrawal_ends_on', l.withdrawal_ends_on) ORDER BY l.id)
                                        FROM prescriptions p JOIN prescription_lines l ON l.prescription_id = p.id
                                        JOIN medicines m ON m.id = l.medicine_id
                                       WHERE p.consultation_id = c.id), '[]'::jsonb))::text
  FROM consultations c JOIN sections sc ON sc.id = c.section_id LEFT JOIN staff f ON f.id = c.vet_id
 WHERE c.state = 'signed' AND c.signed_at > %s
"""
STAYS = """
SELECT 'S-' || s.id, s.animal_id, NULL::integer, s.admitted_at, s.discharged_at, 'Discharge summary', f.name,
       'discharge',
       jsonb_build_object('section', sc.kind, 'admitted_at', s.admitted_at, 'discharged_at', s.discharged_at,
                          'outcome', s.outcome)::text
  FROM stays s JOIN sections sc ON sc.id = s.section_id LEFT JOIN staff f ON f.id = s.admitting_vet_id
 WHERE s.discharged_at > %s
"""
FIRST = (
    "INSERT INTO portal_documents (animal_id, herd_id, kind, source_ref, version, record_at, gated_at, published_at,"
    " title, vet_name, body)"
    " SELECT %s, %s, %s, %s, 1, %s, %s, now(), %s, %s, %s::jsonb"
    " WHERE NOT EXISTS (SELECT 1 FROM portal_documents d WHERE d.source_ref = %s AND d.version = 1)")


def publish_records(conns, options, log):
    clinic, portal = conns["clinic"], conns["portal"]
    margin = _margin(options)
    started = _now()
    mark = _mark(portal, "records", started)
    _snapshot(clinic)
    with clinic.cursor() as cur:
        cur.execute(CONSULTATIONS, (mark,))
        docs = cur.fetchall()
        cur.execute(STAYS, (mark,))
        docs += cur.fetchall()
    clinic.rollback()
    docs.sort(key=lambda d: (d[4], d[0]))
    written = 0
    with portal.cursor() as cur:
        for ref, animal, herd, record_at, gated_at, title, vet, kind, body in docs:
            cur.execute(FIRST, (animal, herd, kind, ref, record_at, gated_at, title, vet, body, ref))
            if cur.rowcount:
                written += 1
                log(f"document {ref} published")
        _close(cur, "publish-records", "records", started, len(docs), written, [d[4] for d in docs], mark, margin)
    portal.commit()
    return written + 2


# --- publish-results -------------------------------------------------------------------------

# The gates since the watermark: each test's release (version 1) and each
# amendment after it; the body the values in force at the gate, as the
# derivation builds it.
RESULTS = """
WITH t AS (
    SELECT t.id, o.animal_id, coalesce(s.collected_at, o.ordered_at) AS record_at, t.released_at, t.released_by,
           t.routing, x.code, x.name, x.discipline
      FROM lab_order_tests t JOIN lab_orders o ON o.id = t.order_id JOIN lab_tests x ON x.id = t.test_id
      LEFT JOIN lab_samples s ON s.id = t.sample_id
     WHERE o.account_id = %(account)s AND o.animal_id IS NOT NULL AND t.released_at IS NOT NULL
),
g AS (
    SELECT t.id, false AS amended, t.released_at AS gate, t.released_by AS by FROM t WHERE t.released_at > %(mark)s
    UNION ALL
    SELECT r.order_test_id, true, r.amended_at, min(r.amended_by)
      FROM lab_results r JOIN t ON t.id = r.order_test_id
     WHERE r.supersedes_id IS NOT NULL AND r.amended_at > %(mark)s AND r.amended_at >= t.released_at
     GROUP BY r.order_test_id, r.amended_at
)
SELECT 'T-' || t.id, t.animal_id, t.record_at, g.gate, g.amended, g.by, t.name,
       jsonb_build_object(
           'test', t.code, 'name', t.name, 'discipline', t.discipline,
           'performed_by', CASE t.routing WHEN 'sent-out' THEN 'Northfield Veterinary Laboratories'
                                          ELSE 'the centre''s laboratory' END,
           'amended', g.amended,
           'analytes', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                           'code', n.code, 'name', n.name, 'unit', n.unit,
                                           'value', coalesce(to_jsonb(r.numeric_value), to_jsonb(r.text_value)),
                                           'flag', r.flag, 'low', i.low, 'high', i.high) ORDER BY n.code, r.id)
                                   FROM lab_results r JOIN lab_analytes n ON n.id = r.analyte_id
                                   LEFT JOIN lab_reference_intervals i ON i.id = r.interval_id
                                  WHERE r.order_test_id = t.id
                                    AND (r.supersedes_id IS NULL OR r.amended_at <= g.gate)
                                    AND NOT EXISTS (SELECT 1 FROM lab_results y
                                                     WHERE y.supersedes_id = r.id AND y.amended_at <= g.gate)),
                                '[]'::jsonb))::text
  FROM g JOIN t ON t.id = g.id
 ORDER BY g.gate, t.id
"""


def publish_results(conns, options, log):
    clinic, lab, portal = conns["clinic"], conns["lab"], conns["portal"]
    margin = _margin(options)
    started = _now()
    mark = _mark(portal, "results", started)
    _snapshot(lab)
    with lab.cursor() as cur:
        cur.execute(RESULTS, {"account": int(options.get("account", 1)), "mark": mark})
        gates = cur.fetchall()
    lab.rollback()
    names = {}
    if gates:
        with clinic.cursor() as cur:
            cur.execute("SELECT id, name FROM staff WHERE id = ANY(%s)", (sorted({g[5] for g in gates if g[5]}),))
            names = dict(cur.fetchall())
        clinic.rollback()
    written = 0
    with portal.cursor() as cur:
        for ref, animal, record_at, gate, amended, by, title, body in gates:
            if not amended:
                cur.execute(FIRST, (animal, None, "result", ref, record_at, gate, title, names.get(by), body, ref))
                if cur.rowcount:
                    written += 1
                    log(f"document {ref} published")
                continue
            cur.execute("SELECT id, version, gated_at FROM portal_documents WHERE source_ref = %s"
                        " ORDER BY version DESC", (ref,))
            versions = cur.fetchall()
            if not versions:
                log(f"document {ref}: amended at {gate.isoformat()} before its first version, left for the next run")
                continue
            if any(v[2] == gate for v in versions):
                continue                       # this amendment's version already published
            former, version = versions[0][0], versions[0][1] + 1
            cur.execute("INSERT INTO portal_documents (animal_id, kind, source_ref, version, record_at, gated_at,"
                        " published_at, title, vet_name, body, supersedes_id)"
                        " VALUES (%s, 'result', %s, %s, %s, %s, now(), %s, %s, %s::jsonb, %s)",
                        (animal, ref, version, record_at, gate, title, names.get(by), body, former))
            cur.execute("UPDATE portal_documents SET superseded_at = now() WHERE id = %s", (former,))
            written += 2
            log(f"document {ref} version {version} published, version {version - 1} superseded")
        _close(cur, "publish-results", "results", started, len(gates), written, [g[3] for g in gates], mark, margin)
    portal.commit()
    return written + 2
