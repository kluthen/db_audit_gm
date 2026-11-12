# from scenario: compose/interfaces/scripts/portal_messages.py
"""The portal's notices and reminders to the messaging service (purpose 16,
vet-portal-messages; vet-portal-domain.md, "vet-portal-messages"; capture W4
items 0 and 6; spec D293, D320, D404): queue-notices, queue-reminders and
send-messages, script jobs of the centre's integration engine.

Called by the scheduler as queue_notices(conns, options, log),
queue_reminders(conns, options, log) and send_messages(conns, options, log):
`conns["portal"]` the portal as portal_dispatch (psycopg 3, autocommit off),
`conns["partner"]` the messaging service's endpoint under its hostname (the
scheduler's HTTP client, the customer's key with it, a five-second timeout).

queue_notices, every five minutes: the documents published since the
`notices` watermark (ops.watermarks, set at load_epoch by the DDL): one
`document-notice` for each account that sees it (its animal's current
owner, the record within the ownership; a keeper the owner grants access
now; a herd's keeper), active, its channel not `none`; message key
md5('document-notice:<account>:<document>') as the derivation's, payload the
template, the recipient's name, the animal's name and the document's link;
one per document and account (the job's own check, the partial unique index
behind it). The watermark the latest publication read, less
options["margin_minutes"].

queue_reminders, at 09:00 local: the animals of options["species"] alive in
the copy whose yearly due day (day 1 + (id x 211) mod 365, the load's) is
the customer's today plus portal_settings' reminder_lead_days, whose current
owner's account is not closed and whose latest `reminders` event is a
grant: one `reminder` per animal and due day, by sms when the account's
channel is sms, else by e-mail, its payload the withdrawal link
(unsubscribe/<message key>).

send_messages, every minute: the outbox's unsent rows, oldest first, at most
options["batch"], the reminders only within portal_settings' hours
(reminders_from to reminders_until, local); a reminder checked again at
sending time (the account not closed, the animal alive, its owner still the
account's, the consent a grant) and any message to a closed account but the
closure itself: such a row is stopped (failed_at, last_status the reason,
no incident). Each other row posted to POST /messages with its message_key
(the same on every retry); 202: provider_id (the service's id) and sent_at;
otherwise the attempt counted and its status kept, retried at the next run;
at options["attempts"] (six) failed_at and one ops.incidents row (kind
failed, ref the message key). The calls are made holding no transaction;
the results, the incidents and the run's ops.runs row are written in one
portal transaction after them.

Logs message keys, templates and counts only (no address, no name).
Returns the rows written. Imports nothing but the standard library.
"""

import datetime
import json

PURPOSE = "vet-portal-messages"


def _now():
    return datetime.datetime.now(datetime.timezone.utc)


def _run_row(cur, job, started, read, written):
    cur.execute("INSERT INTO ops.runs (purpose, job, started_at, rows_read, rows_written)"
                " VALUES (%s, %s, %s, %s, %s) RETURNING id", (PURPOSE, job, started, read, written))
    return cur.fetchone()[0]


# --- queue-notices -------------------------------------------------------------------------

NOTICES = """
WITH d AS (
    SELECT id, animal_id, herd_id, record_at, published_at FROM portal_documents
     WHERE published_at > %(mark)s AND published_at <= now()
),
seen AS (
    SELECT d.id AS document_id, w.owner_id
      FROM d JOIN portal_ownerships w ON w.animal_id = d.animal_id AND w.role = 'owner' AND w.until_at IS NULL
                                     AND d.record_at >= w.from_at
    UNION
    SELECT d.id, k.owner_id
      FROM d JOIN portal_ownerships w ON w.animal_id = d.animal_id AND w.role = 'owner' AND w.until_at IS NULL
                                     AND d.record_at >= w.from_at
      JOIN portal_ownerships k ON k.animal_id = d.animal_id AND k.role = 'keeper' AND k.until_at IS NULL
     WHERE (SELECT e.granted FROM portal_consent_events e
             WHERE e.purpose = 'keeper-access' AND e.owner_id = w.owner_id AND e.animal_id = d.animal_id
               AND e.keeper_id = k.owner_id
             ORDER BY e.at DESC, e.id DESC LIMIT 1)
    UNION
    SELECT d.id, h.keeper_owner_id FROM d JOIN portal_herds h ON h.herd_id = d.herd_id
),
q AS (
    SELECT md5('document-notice:' || a.id || ':' || d.id)::uuid AS message_key, a.id AS account_id, a.owner_id,
           a.notify_by AS channel, CASE a.notify_by WHEN 'sms' THEN a.phone ELSE a.email END AS address,
           d.id AS document_id,
           jsonb_build_object('template', 'document-notice', 'name', a.display_name,
                              'animal', coalesce(n.name, 'herd ' || d.herd_id),
                              'link', %(link)s || 'documents/' || d.id) AS payload,
           d.published_at
      FROM seen s JOIN d ON d.id = s.document_id JOIN portal_accounts a ON a.owner_id = s.owner_id
      LEFT JOIN portal_animals n ON n.animal_id = d.animal_id
     WHERE a.status = 'active' AND a.notify_by <> 'none'
)
INSERT INTO portal_outbox (message_key, account_id, owner_id, template, channel, address, document_id, payload,
                           queued_at)
SELECT q.message_key, q.account_id, q.owner_id, 'document-notice', q.channel, q.address, q.document_id, q.payload,
       now()
  FROM q
 WHERE q.address IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM portal_outbox o WHERE o.template = 'document-notice'
                      AND o.document_id = q.document_id AND o.account_id = q.account_id)
 ORDER BY q.published_at, q.document_id, q.account_id
ON CONFLICT DO NOTHING
RETURNING message_key::text, document_id
"""


def queue_notices(conns, options, log):
    portal = conns["portal"]
    margin = datetime.timedelta(minutes=int(options.get("margin_minutes", 2)))
    link = options.get("link", "https://portal.example.net/")
    started = _now()
    with portal.cursor() as cur:
        cur.execute("SELECT at FROM ops.watermarks WHERE purpose = %s AND name = 'notices'", (PURPOSE,))
        got = cur.fetchone()
        mark = got[0] if got and got[0] is not None else started
        cur.execute("SELECT count(*), max(published_at) FROM portal_documents"
                    " WHERE published_at > %s AND published_at <= now()", (mark,))
        read, latest = cur.fetchone()
        cur.execute(NOTICES, {"mark": mark, "link": link})
        queued = cur.fetchall()
        run_id = _run_row(cur, "queue-notices", started, read, len(queued))
        at = max(mark, latest - margin) if latest is not None else mark
        cur.execute("INSERT INTO ops.watermarks (purpose, name, at, run_id) VALUES (%s, 'notices', %s, %s)"
                    " ON CONFLICT (purpose, name) DO UPDATE SET at = EXCLUDED.at, run_id = EXCLUDED.run_id",
                    (PURPOSE, at, run_id))
    portal.commit()
    for key, document in queued:
        log(f"notice {key} queued (document {document})")
    return len(queued) + 2


# --- queue-reminders -----------------------------------------------------------------------

REMINDERS = """
WITH s AS (
    SELECT ((now() AT TIME ZONE 'UTC') + make_interval(hours => utc_offset_hours))::date + reminder_lead_days AS due
      FROM portal_settings LIMIT 1
),
q AS (
    SELECT n.animal_id, n.name, s.due, a.id AS account_id, a.owner_id, a.display_name,
           CASE a.notify_by WHEN 'sms' THEN 'sms' ELSE 'email' END AS channel,
           CASE a.notify_by WHEN 'sms' THEN a.phone ELSE a.email END AS address,
           md5('reminder:' || a.id || ':' || n.animal_id || ':' || s.due)::uuid AS message_key
      FROM s CROSS JOIN portal_animals n
      JOIN portal_ownerships w ON w.animal_id = n.animal_id AND w.role = 'owner' AND w.until_at IS NULL
      JOIN portal_accounts a ON a.owner_id = w.owner_id
     WHERE n.status = 'alive' AND n.species = ANY(%(species)s)
       AND make_date(extract(year FROM s.due)::integer, 1, 1) + (n.animal_id::bigint * 211 %% 365)::integer = s.due
       AND a.status <> 'closed'
       AND (SELECT e.granted FROM portal_consent_events e
             WHERE e.owner_id = w.owner_id AND e.purpose = 'reminders'
             ORDER BY e.at DESC, e.id DESC LIMIT 1)
)
INSERT INTO portal_outbox (message_key, account_id, owner_id, template, channel, address, animal_id, due_on, payload,
                           queued_at)
SELECT q.message_key, q.account_id, q.owner_id, 'reminder', q.channel, q.address, q.animal_id, q.due,
       jsonb_build_object('template', 'reminder', 'name', q.display_name, 'animal', q.name, 'due_on', q.due,
                          'link', %(link)s || 'unsubscribe/' || q.message_key),
       now()
  FROM q
 WHERE q.address IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM portal_outbox o WHERE o.template = 'reminder' AND o.animal_id = q.animal_id
                      AND o.due_on = q.due)
 ORDER BY q.animal_id
ON CONFLICT DO NOTHING
RETURNING message_key::text, animal_id, due_on
"""


def queue_reminders(conns, options, log):
    portal = conns["portal"]
    species = [s.strip() for s in str(options.get("species", "dog,cat,rabbit,ferret,horse")).split(",") if s.strip()]
    started = _now()
    with portal.cursor() as cur:
        cur.execute(REMINDERS, {"species": species, "link": options.get("link", "https://portal.example.net/")})
        queued = cur.fetchall()
        _run_row(cur, "queue-reminders", started, len(queued), len(queued))
    portal.commit()
    for key, animal, due in queued:
        log(f"reminder {key} queued (animal {animal}, due {due.isoformat()})")
    return len(queued) + 1


# --- send-messages ---------------------------------------------------------------------------

TO_SEND = """
SELECT o.id, o.message_key::text, o.account_id, o.template, o.channel, o.address, o.payload::text, o.attempts,
       CASE WHEN o.template = 'reminder' THEN
                CASE WHEN a.status IS DISTINCT FROM 'active' AND a.status IS DISTINCT FROM 'invited'
                          THEN 'account-closed'
                     WHEN n.status IS DISTINCT FROM 'alive' THEN 'animal-died'
                     WHEN NOT EXISTS (SELECT 1 FROM portal_ownerships w
                                       WHERE w.animal_id = o.animal_id AND w.owner_id = o.owner_id
                                         AND w.role = 'owner' AND w.until_at IS NULL) THEN 'owner-changed'
                     WHEN NOT coalesce((SELECT e.granted FROM portal_consent_events e
                                         WHERE e.owner_id = o.owner_id AND e.purpose = 'reminders'
                                         ORDER BY e.at DESC, e.id DESC LIMIT 1), false) THEN 'consent-withdrawn'
                END
            WHEN o.template <> 'closure' AND a.status = 'closed' THEN 'account-closed'
       END AS stop
  FROM portal_outbox o CROSS JOIN portal_settings s
  LEFT JOIN portal_accounts a ON a.id = o.account_id
  LEFT JOIN portal_animals n ON n.animal_id = o.animal_id
 WHERE o.sent_at IS NULL AND o.failed_at IS NULL
   AND (o.template <> 'reminder'
        OR ((now() AT TIME ZONE 'UTC') + make_interval(hours => s.utc_offset_hours))::time
           BETWEEN s.reminders_from AND s.reminders_until - interval '1 microsecond')
 ORDER BY o.queued_at, o.id
 LIMIT %s
"""


def send_messages(conns, options, log):
    portal, partner = conns["portal"], conns["partner"]
    batch, most = int(options.get("batch", 100)), int(options.get("attempts", 6))
    started = _now()
    with portal.cursor() as cur:
        cur.execute(TO_SEND, (batch,))
        rows = cur.fetchall()
    portal.rollback()
    if not rows:
        return 0
    results = []                          # (id, key, template, sent_at, provider_id, status, attempts, stop)
    for oid, key, account, template, channel, address, payload, attempts, stop in rows:
        if stop:
            results.append((oid, key, template, None, None, stop, attempts, True))
            continue
        body = {"message_key": key, "channel": channel, "address": address, "template": template,
                "account_id": account, "payload": json.loads(payload)}
        try:
            answer = partner.post("/messages", body)
            status, provider = str(answer.status), None
            if answer.status == 202:
                provider = (answer.json() or {}).get("id")
                if not provider:
                    status = "202-no-id"
        except partner.HttpError as exc:
            status, provider = str(exc.status), None
        results.append((oid, key, template, _now() if provider else None, provider, status, attempts + 1, False))
    with portal.cursor() as cur:
        run_id = _run_row(cur, "send-messages", started, len(rows), len(results))
        for oid, key, template, sent_at, provider, status, attempts, stopped in results:
            if stopped:
                cur.execute("UPDATE portal_outbox SET failed_at = now(), last_status = %s WHERE id = %s",
                            (status, oid))
            elif provider:
                cur.execute("UPDATE portal_outbox SET sent_at = %s, provider_id = %s, attempts = %s,"
                            " last_status = %s WHERE id = %s", (sent_at, provider, attempts, status, oid))
            elif attempts >= most:
                cur.execute("UPDATE portal_outbox SET attempts = %s, last_status = %s, failed_at = now()"
                            " WHERE id = %s", (attempts, status, oid))
                cur.execute("INSERT INTO ops.incidents (purpose, job, kind, ref, reason, run_id)"
                            " VALUES (%s, 'send-messages', 'failed', %s, %s, %s)",
                            (PURPOSE, key, f"{template} {key}: not accepted after {attempts} attempts ({status})",
                             run_id))
            else:
                cur.execute("UPDATE portal_outbox SET attempts = %s, last_status = %s WHERE id = %s",
                            (attempts, status, oid))
    portal.commit()
    for oid, key, template, sent_at, provider, status, attempts, stopped in results:
        if stopped:
            log(f"{template} {key} stopped ({status})")
        elif provider:
            log(f"{template} {key} sent (attempt {attempts})")
        else:
            log(f"{template} {key} not accepted ({status}, attempt {attempts}"
                f"{', failed' if attempts >= most else ''})")
    return len(results) + 1
