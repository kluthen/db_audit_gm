-- vet-portal's derivation (v0.5 master spec 8.5, 9.7; vet-portal-domain.md,
-- "Loading" step 2, "The history before T0"; capture W3 item 5; spec D322,
-- D326, D404), sanctioned by the composition record (composition.yaml,
-- derive: [{domain: vet-portal, after: [vet-core, vet-lab]}]). gmctl
-- load-data runs it after every source's load, as postgres, connected to the
-- portal's database, unseen (D265), with vet-core's and this part's
-- data/keys.sql streamed ahead of it, the record readable as gm_src_vet_core
-- and the lab as gm_src_vet_lab (foreign schemas it drops afterwards). It
-- copies, never computes, and writes portal only, the whole outbox included
-- (D404):
--   - the copies as the core holds them at T0 (animals, ownerships, herds);
--   - the documents of every signed consultation, released centre test
--     (account 1's) and ended stay of the year, each published five to ten
--     minutes after its gate (purpose 15's cadence), an amendment a new
--     version, the former superseded; numbered by gate, reference, version;
--   - the views of the documents by the accounts that saw them;
--   - the whole outbox, numbered 1 to n in queued_at order, ties by
--     message_key (W3 item 5): invitations, resets and closures from the
--     load's accounts (pg_temp.portal_account, portal_resets), reminders from
--     its consent events, notices from the documents written here.
-- Its keys are the load's and this file's own order; content only (master
-- spec 8.5). docs/gm.md, "The data", documents it.
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'derive.sql: psql variable customer_utc_offset is not set '
                            '(gmctl load-data passes -v customer_utc_offset=<hours>)'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'derive.sql: psql variable load_epoch is not set '
                            '(gmctl load-data passes -v load_epoch=<UTC, ISO 8601>)'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.portal_account(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'derive.sql: the key functions are missing (gmctl load-data streams vet-core''s '
                        'and vet-portal''s data/keys.sql ahead of this file, in the same session)';
    END IF;
    IF to_regclass('gm_src_vet_core.consultations') IS NULL OR to_regclass('gm_src_vet_lab.lab_results') IS NULL THEN
        RAISE EXCEPTION 'derive.sql: the sources are missing (gm_src_vet_core, gm_src_vet_lab: '
                        'composition.yaml derive: after: [vet-core, vet-lab])';
    END IF;
    IF EXISTS (SELECT 1 FROM portal_documents) OR EXISTS (SELECT 1 FROM portal_outbox) THEN
        RAISE EXCEPTION 'derive.sql: portal already derived (it runs once, after the load)';
    END IF;
END $$;

CREATE TEMP TABLE d_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       pg_temp.portal_utc(pg_temp.portal_start(:'load_epoch'::timestamptz, :customer_utc_offset),
                          :customer_utc_offset) AS su;

-- --- The copies, as at T0 (purpose 15's tables) ----------------------------------------------

INSERT INTO portal_animals (animal_id, name, species, sex, born_on, herd_id, status, died_at, synced_at)
SELECT a.id, a.name, a.species, a.sex, a.born_on, a.herd_id, a.status, a.died_at, d_env.e
  FROM gm_src_vet_core.animals AS a, d_env ORDER BY a.id;
INSERT INTO portal_ownerships (animal_id, owner_id, role, from_at, until_at, synced_at)
SELECT w.animal_id, w.owner_id, w.role, w.from_at, w.until_at, d_env.e
  FROM gm_src_vet_core.ownerships AS w, d_env ORDER BY 1, 2, 3, 4;
INSERT INTO portal_herds (herd_id, keeper_owner_id, synced_at)
SELECT h.id, h.keeper_owner_id, d_env.e FROM gm_src_vet_core.herds AS h, d_env ORDER BY h.id;

-- --- The sources, read once ----------------------------------------------------------------

CREATE TEMP TABLE d_staff AS SELECT id, name FROM gm_src_vet_core.staff;
CREATE TEMP TABLE d_sections AS SELECT id, kind FROM gm_src_vet_core.sections;
CREATE TEMP TABLE d_cons AS
SELECT c.id, c.animal_id, c.herd_id, c.kind, c.section_id, c.vet_id, c.started_at, c.signed_at
  FROM gm_src_vet_core.consultations AS c, d_env
 WHERE c.state = 'signed' AND c.signed_at >= d_env.su - interval '1 day';
CREATE TEMP TABLE d_diag AS
SELECT g.consultation_id, g.code, k.label, g.confirmed, g.id
  FROM gm_src_vet_core.diagnoses AS g JOIN gm_src_vet_core.diagnosis_codes AS k ON k.code = g.code
 WHERE g.consultation_id IN (SELECT id FROM d_cons);
CREATE TEMP TABLE d_presc AS
SELECT p.consultation_id, l.id, m.name AS medicine, l.dose, l.unit, l.frequency_hours, l.days,
       l.withdrawal_ends_on
  FROM gm_src_vet_core.prescriptions AS p
  JOIN gm_src_vet_core.prescription_lines AS l ON l.prescription_id = p.id
  JOIN gm_src_vet_core.medicines AS m ON m.id = l.medicine_id
 WHERE p.consultation_id IN (SELECT id FROM d_cons);
CREATE TEMP TABLE d_stays AS
SELECT s.id, s.animal_id, s.section_id, s.admitting_vet_id, s.admitted_at, s.discharged_at, s.outcome
  FROM gm_src_vet_core.stays AS s, d_env
 WHERE s.discharged_at IS NOT NULL AND s.discharged_at >= d_env.su - interval '1 day';
-- The centre's released tests (account 1 only, lab rule 10), never the
-- core's request state (step 7, point 3).
CREATE TEMP TABLE d_tests AS
SELECT t.id, o.animal_id, coalesce(s.collected_at, o.ordered_at) AS record_at, t.released_by, t.released_at,
       t.routing, x.code, x.name, x.discipline
  FROM gm_src_vet_lab.lab_order_tests AS t
  JOIN gm_src_vet_lab.lab_orders AS o ON o.id = t.order_id
  JOIN gm_src_vet_lab.lab_tests AS x ON x.id = t.test_id
  LEFT JOIN gm_src_vet_lab.lab_samples AS s ON s.id = t.sample_id, d_env
 WHERE o.account_id = 1 AND o.animal_id IS NOT NULL AND t.released_at IS NOT NULL
   AND t.released_at >= d_env.su - interval '1 day';
CREATE TEMP TABLE d_results AS
SELECT r.id, r.order_test_id, r.supersedes_id, r.amended_by, r.amended_at, r.numeric_value, r.text_value,
       r.flag, n.code, n.name, n.unit, i.low, i.high
  FROM gm_src_vet_lab.lab_results AS r
  JOIN gm_src_vet_lab.lab_analytes AS n ON n.id = r.analyte_id
  LEFT JOIN gm_src_vet_lab.lab_reference_intervals AS i ON i.id = r.interval_id
 WHERE r.order_test_id IN (SELECT id FROM d_tests);
CREATE INDEX ON d_results (order_test_id);

-- --- The documents (rule 2: the gate first; rule 3: no free text) ------------------------------

-- A publication: the first run of purpose 15 (every five minutes, a two-minute
-- margin) after the gate, a few seconds to a minute into it.
CREATE FUNCTION pg_temp.d_published(gate timestamptz, ref text) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE AS $$
SELECT to_timestamp(ceil(extract(epoch FROM gate + interval '2 minutes') / 300) * 300)
       + interval '1 second' * (5 + 55 * pg_temp.portal_u(hashtext(ref), 50))
$$;

CREATE TEMP TABLE d_docs (animal_id integer, herd_id integer, kind text, source_ref text, version integer,
                          record_at timestamptz, gated_at timestamptz, published_at timestamptz, title text,
                          vet_name text, body jsonb);

INSERT INTO d_docs
SELECT c.animal_id, c.herd_id, 'consultation', 'C-' || c.id, 1, c.started_at, c.signed_at,
       pg_temp.d_published(c.signed_at, 'C-' || c.id),
       CASE c.kind WHEN 'herd-visit' THEN 'Herd visit' WHEN 'in-hospital' THEN 'In-hospital examination'
                   WHEN 'emergency' THEN 'Emergency consultation' ELSE 'Consultation' END,
       f.name,
       jsonb_build_object(
           'kind', c.kind, 'section', sc.kind, 'started_at', c.started_at,
           'diagnoses', coalesce((SELECT jsonb_agg(jsonb_build_object('code', g.code, 'label', g.label,
                                                                      'confirmed', g.confirmed) ORDER BY g.id)
                                    FROM d_diag AS g WHERE g.consultation_id = c.id), '[]'::jsonb),
           'prescriptions', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                                 'medicine', p.medicine, 'dose', p.dose, 'unit', p.unit,
                                                 'frequency_hours', p.frequency_hours, 'days', p.days,
                                                 'withdrawal_ends_on', p.withdrawal_ends_on) ORDER BY p.id)
                                        FROM d_presc AS p WHERE p.consultation_id = c.id), '[]'::jsonb))
  FROM d_cons AS c JOIN d_sections AS sc ON sc.id = c.section_id LEFT JOIN d_staff AS f ON f.id = c.vet_id;

INSERT INTO d_docs
SELECT s.animal_id, NULL, 'discharge', 'S-' || s.id, 1, s.admitted_at, s.discharged_at,
       pg_temp.d_published(s.discharged_at, 'S-' || s.id), 'Discharge summary', f.name,
       jsonb_build_object('section', sc.kind, 'admitted_at', s.admitted_at, 'discharged_at', s.discharged_at,
                          'outcome', s.outcome)
  FROM d_stays AS s JOIN d_sections AS sc ON sc.id = s.section_id LEFT JOIN d_staff AS f ON f.id = s.admitting_vet_id;

-- A result's versions: version 1 at the release, its original values; one
-- more at each amendment after it (its amended_at), the values in force then
-- (lab rule 3), signed by the amending pathologist.
CREATE TEMP TABLE d_versions AS
SELECT t.id AS test_id, 1 AS version, t.released_at AS gate, t.released_by AS by FROM d_tests AS t
UNION ALL
SELECT a.order_test_id, 1 + row_number() OVER (PARTITION BY a.order_test_id ORDER BY a.amended_at),
       a.amended_at, a.amended_by
  FROM (SELECT r.order_test_id, r.amended_at, min(r.amended_by) AS amended_by
          FROM d_results AS r JOIN d_tests AS t ON t.id = r.order_test_id
         WHERE r.supersedes_id IS NOT NULL AND r.amended_at >= t.released_at
         GROUP BY 1, 2) AS a;

INSERT INTO d_docs
SELECT t.animal_id, NULL, 'result', 'T-' || t.id, v.version, t.record_at, v.gate,
       pg_temp.d_published(v.gate, 'T-' || t.id || '/' || v.version), t.name, f.name,
       jsonb_build_object(
           'test', t.code, 'name', t.name, 'discipline', t.discipline,
           'performed_by', CASE t.routing WHEN 'sent-out' THEN 'Northfield Veterinary Laboratories'
                                          ELSE 'the centre''s laboratory' END,
           'amended', v.version > 1,
           'analytes', coalesce((SELECT jsonb_agg(jsonb_build_object(
                                           'code', r.code, 'name', r.name, 'unit', r.unit,
                                           'value', coalesce(to_jsonb(r.numeric_value), to_jsonb(r.text_value)),
                                           'flag', r.flag, 'low', r.low, 'high', r.high) ORDER BY r.code, r.id)
                                   FROM d_results AS r
                                  WHERE r.order_test_id = t.id
                                    AND (r.supersedes_id IS NULL OR r.amended_at <= v.gate)
                                    AND NOT EXISTS (SELECT 1 FROM d_results AS y
                                                     WHERE y.supersedes_id = r.id AND y.amended_at <= v.gate)),
                                '[]'::jsonb))
  FROM d_versions AS v JOIN d_tests AS t ON t.id = v.test_id LEFT JOIN d_staff AS f ON f.id = v.by;

-- The year's, published by T0; numbered by gate, reference and version.
DELETE FROM d_docs USING d_env WHERE published_at > d_env.e OR gated_at < d_env.su;
CREATE TEMP TABLE d_doc AS
SELECT row_number() OVER (ORDER BY gated_at, source_ref, version)::integer AS id, d.* FROM d_docs AS d;
CREATE INDEX ON d_doc (source_ref, version);

INSERT INTO portal_documents (id, animal_id, herd_id, kind, source_ref, version, record_at, gated_at, published_at,
                              title, vet_name, body, supersedes_id, superseded_at)
SELECT d.id, d.animal_id, d.herd_id, d.kind, d.source_ref, d.version, d.record_at, d.gated_at, d.published_at,
       d.title, d.vet_name, d.body, p.id, n.published_at
  FROM d_doc AS d
  LEFT JOIN d_doc AS p ON p.source_ref = d.source_ref AND p.version = d.version - 1
  LEFT JOIN d_doc AS n ON n.source_ref = d.source_ref AND n.version = d.version + 1
 ORDER BY d.id;

-- --- Who saw each document --------------------------------------------------------------------

-- The accounts as the load left them, and the contacts a closed one had.
CREATE TEMP TABLE d_acc AS
SELECT n AS id, a.* FROM d_env, generate_series(2, 10000) AS n,
       LATERAL pg_temp.portal_account(n, d_env.e, d_env.o) AS a;
CREATE UNIQUE INDEX ON d_acc (id);

-- The accounts a document's notice went to: its animal's owner at the
-- publication when the record falls within that ownership, a keeper the
-- owner had granted access then (both keeping and owning), a herd's keeper;
-- each active then (W3 item 5's accounts that see it).
CREATE TEMP TABLE d_seen AS
SELECT d.id AS document_id, w.owner_id AS account_id, w.until_at, 'owner' AS how
  FROM portal_documents AS d
  JOIN portal_ownerships AS w ON w.animal_id = d.animal_id AND w.role = 'owner'
   AND w.from_at <= d.published_at AND (w.until_at IS NULL OR w.until_at > d.published_at)
   AND d.record_at >= w.from_at
UNION ALL
SELECT d.id, k.owner_id, k.until_at, 'keeper'
  FROM portal_documents AS d
  JOIN portal_ownerships AS w ON w.animal_id = d.animal_id AND w.role = 'owner'
   AND w.from_at <= d.published_at AND (w.until_at IS NULL OR w.until_at > d.published_at)
   AND d.record_at >= w.from_at
  JOIN portal_ownerships AS k ON k.animal_id = d.animal_id AND k.role = 'keeper'
   AND k.from_at <= d.published_at AND (k.until_at IS NULL OR k.until_at > d.published_at)
 WHERE (SELECT e.granted FROM portal_consent_events AS e
         WHERE e.purpose = 'keeper-access' AND e.owner_id = w.owner_id AND e.animal_id = d.animal_id
           AND e.keeper_id = k.owner_id AND e.at <= d.published_at
         ORDER BY e.at DESC, e.id DESC LIMIT 1)
UNION ALL
SELECT d.id, h.keeper_owner_id, NULL, 'herd'
  FROM portal_documents AS d JOIN portal_herds AS h ON h.herd_id = d.herd_id;
DELETE FROM d_seen AS s USING portal_documents AS d, d_acc AS a
 WHERE d.id = s.document_id AND a.id = s.account_id
   AND NOT coalesce(a.activated_at <= d.published_at AND (a.closed_at IS NULL OR a.closed_at > d.published_at),
                    false);
DELETE FROM d_seen AS s WHERE NOT EXISTS (SELECT 1 FROM d_acc AS a WHERE a.id = s.account_id);

-- Views: an account opens a document it saw one to four times (2.5 on
-- average) for nearly every one (49 in 50), the first open within a day and a
-- half, mostly the same evening, the others over the following weeks; never
-- after T0, its closure or the ownership's end; one opening in eight a
-- download.
CREATE TEMP TABLE d_views AS
SELECT s.account_id, s.document_id, v.at,
       CASE WHEN pg_temp.portal_u(s.document_id::bigint * 16 + j, 53) < 0.125 THEN 'download' ELSE 'open' END
         AS action
  FROM d_seen AS s JOIN portal_documents AS d ON d.id = s.document_id JOIN d_acc AS a ON a.id = s.account_id,
       d_env,
       generate_series(1, 1 + floor(4 * pg_temp.portal_u(s.document_id::bigint * 10007 + s.account_id, 51))::integer)
         AS j,
       LATERAL (SELECT d.published_at + interval '20 minutes'
                       + interval '36 hours' * pg_temp.portal_u(s.document_id::bigint * 16 + j, 52)
                       + (j - 1) * interval '6 days' * (0.3 + pg_temp.portal_u(s.document_id::bigint * 16 + j, 54))
                         AS at) AS v
 WHERE pg_temp.portal_u(s.document_id::bigint * 10007 + s.account_id, 55) < 0.98
   AND v.at < d_env.e AND (a.closed_at IS NULL OR v.at < a.closed_at) AND (s.until_at IS NULL OR v.at < s.until_at);

INSERT INTO portal_views (id, account_id, document_id, at, action)
SELECT row_number() OVER (ORDER BY at, account_id, document_id), account_id, document_id, at, action
  FROM d_views ORDER BY 1;

-- --- The outbox: every message of the year (D404) ---------------------------------------------

CREATE TEMP TABLE d_out (message_key uuid, account_id integer, owner_id integer, template text, channel text,
                         address text, document_id integer, animal_id integer, due_on date, payload jsonb,
                         queued_at timestamptz);

-- Invitations (the year's accounts), resets and closures, by e-mail.
INSERT INTO d_out
SELECT pg_temp.portal_message_key('invitation', a.id, '1'), a.id, a.id, 'invitation', 'email', a.email,
       NULL, NULL, NULL,
       jsonb_build_object('template', 'invitation', 'name', a.display_name,
                          'link', 'https://portal.example.net/activate/'
                                  || pg_temp.portal_token('invitation', a.id, d_env.e)),
       a.invited_at
  FROM d_acc AS a, d_env WHERE a.invited_at >= d_env.su AND a.invited_at < d_env.e;
INSERT INTO d_out
SELECT pg_temp.portal_message_key('password-reset', a.id, r.rank::text), a.id, a.id, 'password-reset', 'email',
       a.email, NULL, NULL, NULL,
       jsonb_build_object('template', 'password-reset', 'name', a.display_name,
                          'link', 'https://portal.example.net/password-reset/'
                                  || pg_temp.portal_token('password-reset', a.id, d_env.e)),
       r.at
  FROM d_acc AS a, d_env, LATERAL pg_temp.portal_resets(a.id, d_env.e, d_env.o) AS r
 WHERE r.at >= d_env.su;
INSERT INTO d_out
SELECT pg_temp.portal_message_key('closure', a.id, '1'), a.id, a.id, 'closure', 'email', a.email,
       NULL, NULL, NULL, jsonb_build_object('template', 'closure', 'name', a.display_name, 'link', NULL),
       a.closed_at
  FROM d_acc AS a, d_env WHERE a.closed_at >= d_env.su;

-- Notices: one per document and account that saw it, its channel not none,
-- queued by the next queue-notices run (every five minutes).
INSERT INTO d_out
SELECT pg_temp.portal_message_key('document-notice', s.account_id, d.id::text), s.account_id, s.account_id,
       'document-notice', a.notify_by, CASE a.notify_by WHEN 'sms' THEN a.phone ELSE a.email END,
       d.id, NULL, NULL,
       jsonb_build_object('template', 'document-notice', 'name', a.display_name,
                          'animal', coalesce(n.name, 'herd ' || d.herd_id),
                          'link', 'https://portal.example.net/documents/' || d.id),
       to_timestamp(ceil(extract(epoch FROM d.published_at) / 300) * 300)
         + interval '1 second' * (5 + 25 * pg_temp.portal_u(d.id, 56))
  FROM d_seen AS s JOIN portal_documents AS d ON d.id = s.document_id JOIN d_acc AS a ON a.id = s.account_id
  LEFT JOIN portal_animals AS n ON n.animal_id = d.animal_id
 WHERE a.notify_by <> 'none';

-- Reminders: each domestic animal's and horse's (not the clinic's teaching
-- animals, T285) yearly due day, queued at 09:00 local 14 days before it,
-- when the animal was alive, its current owner's account active and its
-- latest reminders event a grant (MS2, MS6); one per animal and due day.
CREATE TEMP TABLE d_due AS
SELECT x.animal_id, x.due_on, x.q
  FROM d_env, generate_series(13, 16000) AS g(animal_id),
       generate_series(extract(year FROM pg_temp.portal_local(d_env.su, d_env.o))::integer,
                       extract(year FROM pg_temp.portal_local(d_env.e, d_env.o))::integer + 1) AS y,
       LATERAL (SELECT g.animal_id, pg_temp.portal_due_on(g.animal_id, y) AS due_on,
                       pg_temp.portal_utc((pg_temp.portal_due_on(g.animal_id, y) - 14) + time '09:00', d_env.o) AS q)
         AS x
 WHERE g.animal_id NOT BETWEEN 14601 AND 14608 AND x.q >= d_env.su AND x.q < d_env.e;
INSERT INTO d_out
SELECT pg_temp.portal_message_key('reminder', a.id, u.animal_id || ':' || u.due_on), a.id, a.id, 'reminder',
       CASE a.notify_by WHEN 'sms' THEN 'sms' ELSE 'email' END,
       CASE a.notify_by WHEN 'sms' THEN a.phone ELSE a.email END,
       NULL, u.animal_id, u.due_on,
       jsonb_build_object('template', 'reminder', 'name', a.display_name, 'animal', n.name, 'due_on', u.due_on,
                          'link', 'https://portal.example.net/unsubscribe/'
                                  || pg_temp.portal_message_key('reminder', a.id, u.animal_id || ':' || u.due_on)),
       u.q + interval '1 second' * (10 + 1200 * pg_temp.portal_u(u.animal_id::bigint * 40000 + (u.due_on - date '2000-01-01'), 57))
  FROM d_due AS u
  JOIN portal_animals AS n ON n.animal_id = u.animal_id AND (n.died_at IS NULL OR n.died_at > u.q)
  JOIN portal_ownerships AS w ON w.animal_id = u.animal_id AND w.role = 'owner' AND w.owner_id <> 1
   AND w.from_at <= u.q AND (w.until_at IS NULL OR w.until_at > u.q)
  JOIN d_acc AS a ON a.id = w.owner_id AND a.activated_at <= u.q AND (a.closed_at IS NULL OR a.closed_at > u.q)
 WHERE (SELECT e.granted FROM portal_consent_events AS e
         WHERE e.owner_id = w.owner_id AND e.purpose = 'reminders' AND e.at <= u.q
         ORDER BY e.at DESC, e.id DESC LIMIT 1);

-- Numbered in queued_at order, ties by message_key; sent within the minute
-- (send-messages), one in fifty after a 503 and a retry with the same key;
-- the last two minutes' not yet sent.
INSERT INTO portal_outbox (id, message_key, account_id, owner_id, template, channel, address, document_id,
                           animal_id, due_on, payload, queued_at, sent_at, attempts, last_status, provider_id)
SELECT row_number() OVER (ORDER BY o.queued_at, o.message_key), o.message_key, o.account_id, o.owner_id,
       o.template, o.channel, o.address, o.document_id, o.animal_id, o.due_on, o.payload, o.queued_at,
       CASE WHEN s.sent < d_env.e THEN s.sent END,
       CASE WHEN s.sent >= d_env.e THEN 0 WHEN s.retried THEN 2 ELSE 1 END,
       CASE WHEN s.sent < d_env.e THEN '202' END,
       CASE WHEN s.sent < d_env.e THEN pg_temp.portal_provider_id(o.message_key) END
  FROM d_out AS o, d_env,
       LATERAL (SELECT pg_temp.portal_u(hashtext(o.message_key::text), 58) < 0.02 AS retried) AS r,
       LATERAL (SELECT o.queued_at + interval '1 second' * (2 + 50 * pg_temp.portal_u(hashtext(o.message_key::text), 59))
                       + CASE WHEN r.retried THEN interval '1 minute' ELSE interval '0' END AS sent,
                       r.retried) AS s
 ORDER BY 1;

-- --- Sequences after their ranges ----------------------------------------------------------------

SELECT setval(pg_get_serial_sequence(t, 'id'), greatest(1, (xpath('/row/m/text()',
              query_to_xml(format('SELECT max(id) AS m FROM %I', t), false, true, '')))[1]::text::integer))
  FROM unnest(ARRAY['portal_documents', 'portal_views', 'portal_outbox']) AS t;

ANALYZE portal_animals;
ANALYZE portal_ownerships;
ANALYZE portal_herds;
ANALYZE portal_documents;
ANALYZE portal_views;
ANALYZE portal_outbox;
