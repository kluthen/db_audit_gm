-- data.sql of the other centres of the franchise, one stub for three
-- partners (v0.5 master spec 10.2, 12.2 purpose 4; vet-core-domain.md, "The
-- partners the core meets"; clinic-purposes.md 8; capture W4 item 4, W2-f;
-- partners/README.md): its role, its schema, the exchanges each centre holds
-- in flight at T0, and its state, in the partners' database. load-data runs
-- it connected to partners, as postgres, with vet-core's data/keys.sql
-- streamed ahead of it (W3 item 0): the exchanges are pg_temp.core_exchange's,
-- the pass vet-core's load.sql runs (D374), so each centre knows the
-- exchanges the core's history leaves open with it, by the same
-- exchange_key, and no other.
--
-- Three hostnames on one folder (W4 item 4), each a partner of its own:
-- aldermoor-central (site 2, ALD-C), aldermoor-south (site 3, ALD-S) and
-- aldermoor-abroad (sites 4 to 6, the centres abroad as one).
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'centres data.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_exchange(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'centres data.sql: vet-core''s key functions are missing (load-data streams '
                        'vet-core''s data/keys.sql ahead of this file)';
    END IF;
END $$;

-- The role: LOGIN with no password here; load-data sets its secret.
CREATE ROLE centres LOGIN;
CREATE SCHEMA centres AUTHORIZATION centres;

-- One row an exchange a centre holds, keyed by the round trip's
-- exchange_key. asked_by customer: the clinic asked the centre (POST
-- /exchanges here; the clinic's direction out): ref the clinic's exchange id,
-- the centre's answer due at due_at and posted to clinic-api's POST
-- /exchanges/{key}/answer (answered_at once taken), an accepted
-- examination's report due at report_due_at and posted to .../report
-- (reported_at). asked_by centre: the centre asked the clinic (posted to
-- clinic-api's POST /exchanges, posted_at once taken; the clinic's direction
-- in): ref the centre's own patient record (100 000 + n), the clinic's
-- answer and report received here (answered_at, reported_at). requests
-- counts the requests received under the key (a resend counted, never a new
-- row); a resend after the answer has the answer posted again (answer_posts
-- below requests).
CREATE TABLE centres.exchanges (
    exchange_key  uuid        PRIMARY KEY,
    hostname      text        NOT NULL,
    site_code     text        NOT NULL,
    asked_by      text        NOT NULL CHECK (asked_by IN ('customer', 'centre')),
    kind          text        NOT NULL CHECK (kind IN ('transfer', 'examination')),
    ref           integer     NOT NULL,
    animal_id     integer,                       -- the clinic's, as its request carried it
    reason        text        NOT NULL,
    patient       text,                          -- a centre's own request: its patient's summary
    requested_at  timestamptz NOT NULL,
    received_at   timestamptz,                   -- asked by the customer: its first request here
    requests      integer     NOT NULL DEFAULT 0,
    posted_at     timestamptz,                   -- asked by a centre: taken by clinic-api
    due_at        timestamptz,                   -- asked by the customer: the centre's answer
    answer        text        CHECK (answer IN ('accepted', 'declined')),
    accepted_for  date,
    answered_at   timestamptz,
    answer_posts  integer     NOT NULL DEFAULT 0,  -- asked by the customer: the answer's posts taken
    report_due_at timestamptz,
    reported_at   timestamptz
);
CREATE INDEX exchanges_due_idx ON centres.exchanges (hostname, due_at) WHERE answered_at IS NULL;
CREATE INDEX exchanges_ref_idx ON centres.exchanges (hostname, asked_by, ref);
ALTER TABLE centres.exchanges OWNER TO centres;

-- Every message the centres' public routes took, as received (the body
-- kept): a request, a resend, an answer, a report; the status they answered.
CREATE TABLE centres.messages (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hostname     text        NOT NULL,
    exchange_key uuid        NOT NULL,
    kind         text        NOT NULL CHECK (kind IN ('request', 'answer', 'report')),
    status       integer     NOT NULL,
    at           timestamptz NOT NULL DEFAULT now(),
    body         jsonb       NOT NULL
);
CREATE INDEX messages_key_idx ON centres.messages (exchange_key, kind);
CREATE INDEX messages_at_idx ON centres.messages (at);
ALTER TABLE centres.messages OWNER TO centres;

-- Its state, read by its routes at each request (W2-f); the back end's
-- centres.normal upserts this baseline, a fault's key other values.
CREATE TABLE centres.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE centres.state OWNER TO centres;
-- delay_ms the baseline centres.normal upserts; utc_offset the customer's
-- (every site in its zone, vet-core's business_settings), for the office
-- hours the centres answer and ask in.
INSERT INTO centres.state (hostname, name, value)
SELECT h, n, v
  FROM unnest(ARRAY['aldermoor-central', 'aldermoor-south', 'aldermoor-abroad']) AS h,
       (VALUES ('delay_ms', '0'), ('utc_offset', :'customer_utc_offset')) AS s (n, v);

-- The exchanges the history leaves open with each centre (core_exchange,
-- 1-700): the clinic's requests sent and unanswered (their answer due within
-- a working day of the request), its accepted examinations not yet reported
-- (their report due one to three days after the examination, 10:00-17:00
-- local); the centres' own requests the clinic has not answered, and their
-- accepted examinations it has not reported. A draw is a hash of the key,
-- never random(); a due time past already is placed in the hour after T0.
CREATE TEMP TABLE c_x AS
SELECT n, x.*,
       CASE WHEN x.site_id = 2 THEN 'aldermoor-central' WHEN x.site_id = 3 THEN 'aldermoor-south'
            ELSE 'aldermoor-abroad' END AS hostname,
       (ARRAY['ALD-C', 'ALD-S', 'ALD-BE', 'ALD-DE', 'ALD-LU'])[x.site_id - 1] AS site_code,
       ('x' || substr(md5('centres:' || x.exchange_key::text || ':1'), 1, 8))::bit(32)::bigint / 4294967296.0 AS u1,
       ('x' || substr(md5('centres:' || x.exchange_key::text || ':2'), 1, 8))::bit(32)::bigint / 4294967296.0 AS u2,
       ('x' || substr(md5('centres:' || x.exchange_key::text || ':3'), 1, 8))::bit(32)::bigint / 4294967296.0 AS u3
  FROM generate_series(1, 700) AS n,
       pg_temp.core_exchange(n, :'load_epoch'::timestamptz, :customer_utc_offset) AS x
 WHERE x.state IN ('sent', 'received') OR (x.state = 'accepted' AND x.kind = 'examination');

INSERT INTO centres.exchanges (exchange_key, hostname, site_code, asked_by, kind, ref, animal_id, reason, patient,
                               requested_at, received_at, requests, posted_at, due_at, answer, accepted_for,
                               answered_at, answer_posts, report_due_at)
SELECT exchange_key, hostname, site_code,
       CASE direction WHEN 'out' THEN 'customer' ELSE 'centre' END,
       kind,
       CASE direction WHEN 'out' THEN n ELSE 100000 + n END,
       CASE direction WHEN 'out' THEN animal_id END,
       reason,
       CASE direction WHEN 'in' THEN partner_species || ', ' || (1 + floor(14 * u3))::integer || ' years' END,
       requested_at,
       CASE direction WHEN 'out' THEN sent_at END,
       CASE direction WHEN 'out' THEN 1 ELSE 0 END,
       CASE direction WHEN 'in' THEN requested_at END,
       CASE WHEN direction = 'out' AND state = 'sent'
            THEN greatest(sent_at + (2 + 6 * u1) * interval '1 hour',
                          :'load_epoch'::timestamptz + (5 + 55 * u2) * interval '1 minute') END,
       CASE WHEN state = 'accepted' THEN 'accepted' END,
       accepted_for,
       answered_at,
       CASE WHEN direction = 'out' AND state = 'accepted' THEN 1 ELSE 0 END,
       CASE WHEN direction = 'out' AND state = 'accepted'
            THEN greatest(((accepted_for + (1 + floor(3 * u1))::integer + time '10:00' + u2 * interval '7 hours')
                           - :customer_utc_offset * interval '1 hour') AT TIME ZONE 'UTC',
                          :'load_epoch'::timestamptz + (5 + 55 * u3) * interval '1 minute') END
  FROM c_x
 ORDER BY n;
ANALYZE centres.exchanges;
