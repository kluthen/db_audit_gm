-- data.sql of partners-db, the partners' shared database (v0.5 master spec
-- 10.2; capture W2 items 0 and 6; partners/README.md): the database
-- partners. The GM copies this file first into the node's data file
-- (scenario.yaml's data.file), then, after it, cold storage's
-- partners/coldstore/data.sql and planted.sql when the scenario has a
-- vault. load-data streams the data file into psql as postgres, connected
-- to the database postgres, before any domain (W2 item 3, step 1); each
-- composed domain's producers/partners/<prefix>/data.sql then runs in
-- partners on its own (chunk 8).
--
-- Nothing else lives here: each partner brings its role (<prefix>, LOGIN,
-- no password: render's secret role_<prefix>_password, set by load-data),
-- its schema <prefix> owned by it, its tables and its state table
-- <prefix>.state (partners/README.md, "A partner's state").
CREATE DATABASE partners;

-- What the GM appends below runs in partners.
\connect partners

-- data.sql of cold storage, the vault (v0.5 master spec 10.4, 11.2;
-- cold-storage.md 3; capture W2 item 6, W2-f; partners/README.md): its role,
-- its schema, its manifests and its state, in the partners' database. Laid
-- out as a domain's producers/partners/<prefix>/data.sql (prefix coldstore):
-- it runs connected to partners, as postgres. Cold storage belongs to no
-- domain, so the GM copies it into partners-db's data file, after
-- partners/shared/partners-db/data.sql (which ends connected to partners),
-- and planted.sql after it.

-- The role: LOGIN with no password here; render derives its secret
-- role_coldstore_password from the connection coldstore-db (partners-api's
-- api.yaml, the back end's schedule.yaml) and load-data sets it.
CREATE ROLE coldstore LOGIN;
CREATE SCHEMA coldstore AUTHORIZATION coldstore;

-- One manifest a shipment (cold-storage.md 3, "A manifest"): what the owner
-- asked for and no more. Keyed (source, shipment_id) (spec D381): the source
-- is the node holding the data, and two archiving nodes post the same segment
-- names. The same id from the same source replaces that source's manifest
-- (POST /shipments upserts it); from another source it makes a second; a new
-- id for a day already shipped adds one.
CREATE TABLE coldstore.manifests (
    shipment_id   text NOT NULL,              -- Shipment-Id: a segment's or backup's name, a data type's own
    type          text NOT NULL,              -- wal, basebackup, or a data type (vitals, machine-readings)
    source        text NOT NULL,              -- Shipment-Source: the node holding the data
    name          text NOT NULL,              -- Shipment-Name: the segment's or backup's name
    rows_declared bigint NOT NULL,            -- Shipment-Rows
    rows_received bigint NOT NULL,            -- NDJSON lines counted; 1 for a non-empty wal or basebackup
    size          bigint NOT NULL,            -- the bytes received
    date_from     date NOT NULL,              -- Shipment-From, inclusive
    date_to       date NOT NULL,              -- Shipment-To, inclusive
    received_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (source, shipment_id),
    CHECK (date_from <= date_to)
);
CREATE INDEX manifests_received_at_idx ON coldstore.manifests (received_at);
CREATE INDEX manifests_type_from_idx ON coldstore.manifests (type, date_from);
ALTER TABLE coldstore.manifests OWNER TO coldstore;

-- Its state, read by its routes at each request (capture W2 item 6, "A
-- misbehaviour key"): delay_ms, added before any answer; uploads, accept or
-- refuse (POST /shipments answering 503, an outage refusing uploads). The
-- back end's stream coldstore.normal upserts this baseline once a minute; a
-- fault's key coldstore.<behaviour> upserts other values.
CREATE TABLE coldstore.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE coldstore.state OWNER TO coldstore;
INSERT INTO coldstore.state (hostname, name, value) VALUES
    ('cold-storage', 'delay_ms', '0'),
    ('cold-storage', 'uploads', 'accept');

-- planted.sql of cold storage, the vault (v0.5 master spec 10.4, 11.2;
-- cold-storage.md 3, "Before T0"; capture W2 item 6, W2-f): the wal and
-- basebackup manifests of the weeks before T0, so the page shows the
-- archive's history and not only the aging. The data types' manifests are
-- their purpose's history (purpose 14, chunk 21), not this file's.
--
-- The GM copies it into partners-db's data file after coldstore/data.sql
-- and fills the one list below with the scenario's archiving nodes, as
-- master spec 11.2 places them (the clinic: records and lab archive their
-- WAL and send a nightly base backup; machines sends the base backup only).
-- Per node:
--   node     its name (each manifest's source);
--   wal      true when its seed archives its WAL (archive_mode on);
--   backup   true when its crontab sends a nightly base backup;
--   at       the base backup's crontab time, UTC (HH:MM);
--   segs     the WAL segments it archives an ordinary day (archive_timeout
--            1h: at least 24; more on a busy instance);
--   mb       its base backup's size, in megabytes.
-- Planted: the 35 days before T0's day (the page's five weeks), one manifest
-- per segment and per backup, received a few seconds after it was made.
--
-- Segment names: timeline 1, 16 MB segments (256 to a log), each node from
-- log 0x40 + 16 x its list position, so a planted name never meets another
-- node's nor a live one, which starts at the fresh cluster's first segment
-- (capture W2-f, the known limit: the live names start lower than the
-- planted).
-- T0: the load's reference moment, load_epoch, when load-data passes it
-- (W2 item 3), else the moment this file runs, just before T0.
\if :{?load_epoch}
SELECT :'load_epoch'::timestamptz AS cs_t0 \gset
\else
SELECT now() AS cs_t0 \gset
\endif

WITH nodes (pos, node, wal, backup, at, segs, mb) AS (
    VALUES
        -- The GM's list (one row per archiving node; pos 0, 1, 2, ...):
        (0, 'records', true, true, '03:30', 30, 96),
        (1, 'lab', true, true, '03:45', 26, 64),
        (2, 'machines', false, true, '04:00', 0, 128)
),
days AS (
    SELECT d::date AS day, row_number() OVER (ORDER BY d) - 1 AS n
    FROM generate_series((:'cs_t0'::timestamptz AT TIME ZONE 'UTC')::date - 35,
                         (:'cs_t0'::timestamptz AT TIME ZONE 'UTC')::date - 1,
                         interval '1 day') AS d
),
segments AS (                                   -- each node's segments a day, about segs
    SELECT nd.pos, nd.node, dy.day,
           -- a day's count varies a little around segs, the same for every rerun
           nd.segs + (hashtext(nd.node || dy.day::text) & 7) - 3 AS k
    FROM nodes nd CROSS JOIN days dy
    WHERE nd.wal
),
counted AS (                                    -- the node's segments before that day
    SELECT s.*, sum(s.k) OVER (PARTITION BY s.pos ORDER BY s.day) - s.k AS base
    FROM segments s
),
numbered AS (
    SELECT c.pos, c.node, c.day, g AS i, c.k, c.base + g AS seq
    FROM counted c CROSS JOIN LATERAL generate_series(0, c.k - 1) AS g
)
INSERT INTO coldstore.manifests (shipment_id, type, source, name, rows_declared, rows_received,
                                 size, date_from, date_to, received_at)
SELECT name, 'wal', node, name, 1, 1, 16777216, day, day,
       day + (i + 0.5) * (interval '24 hours' / k) + interval '3 seconds'
FROM (SELECT *, upper('00000001' || lpad(to_hex(64 + 16 * pos + (seq / 256)::int), 8, '0')
                      || lpad(to_hex((seq % 256)::int), 8, '0')) AS name
      FROM numbered) AS w
UNION ALL
SELECT node || '-' || to_char(dy.day, 'YYYYMMDD') || 'T' || replace(at, ':', '') || 'Z', 'basebackup',
       node, node || '-' || to_char(dy.day, 'YYYYMMDD') || 'T' || replace(at, ':', '') || 'Z', 1, 1,
       (mb * 1048576 + (hashtext(node || dy.day::text) & 1048575) * (dy.n + 1))::bigint,
       dy.day, dy.day, dy.day + at::time + interval '40 seconds'
FROM nodes nd CROSS JOIN days dy
WHERE nd.backup;

-- data.sql of the authority's stub, purpose 5's part (v0.5 master spec 10.2,
-- 12.2 purpose 5; clinic-purposes.md 9; capture W4 items 0 and 4; W2-f;
-- partners/README.md): its role, its schema, its state and the notifications
-- it took, in the partners' database. The GM copies it after
-- partners/shared/partners-db/data.sql in partners-db's data file (load-data
-- runs that file connected to partners); with purpose 8, both purposes'
-- files are copied, their shared block below the same text, guarded.
--
-- The shared block (purposes 5 and 8, byte-identical; W4 item 0): the role
-- (LOGIN, no password here: render's secret role_authority_password, set by
-- load-data), the schema, the state and the calls' counter both routes read.
-- authority: begin
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authority') THEN
CREATE ROLE authority LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS authority AUTHORIZATION authority;
CREATE TABLE IF NOT EXISTS authority.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE authority.state OWNER TO authority;
INSERT INTO authority.state (hostname, name, value) VALUES ('authority', 'delay_ms', '0'),
    ('authority', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call either route takes is numbered; a number that is a multiple of
-- fail_one_in answers 503 (the standing one in fifty, D214's precedent).
CREATE SEQUENCE IF NOT EXISTS authority.calls;
ALTER SEQUENCE authority.calls OWNER TO authority;
-- authority: end

-- One row a notification the authority accepted, keyed by the notifier's
-- notification_key (lab-<id> or vet-<diagnosis id>): its reference, the
-- body as first accepted, the accepted calls counted (a repeat answers the
-- same reference, never a second notification).
CREATE TABLE authority.notifications (
    notification_key text        PRIMARY KEY,
    reference        text        NOT NULL UNIQUE,
    body             jsonb       NOT NULL,
    first_at         timestamptz NOT NULL DEFAULT now(),
    last_at          timestamptz NOT NULL DEFAULT now(),
    accepted         integer     NOT NULL DEFAULT 1
);
ALTER TABLE authority.notifications OWNER TO authority;

-- Every call to POST /notifications: its number, its key, the status
-- answered (201, 503, 422), when.
CREATE TABLE authority.notification_calls (
    call             bigint      PRIMARY KEY,
    notification_key text,
    status           integer     NOT NULL,
    at               timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notification_calls_key_idx ON authority.notification_calls (notification_key);
ALTER TABLE authority.notification_calls OWNER TO authority;

-- data.sql of the authority's stub, purpose 8's part (v0.5 master spec 10.2,
-- 12.2 purpose 8; clinic-purposes.md 12; capture W4 items 0 and 5; W2-f;
-- partners/README.md): its role, its schema, its state and the yearly
-- antimicrobial-use reports it took, in the partners' database. The GM copies
-- it after partners/shared/partners-db/data.sql in partners-db's data file
-- (load-data runs that file connected to partners); with purpose 5, both
-- purposes' files are copied, their shared block below the same text,
-- guarded.
--
-- The shared block (purposes 5 and 8, byte-identical; W4 item 0): the role
-- (LOGIN, no password here: render's secret role_authority_password, set by
-- load-data), the schema, the state and the calls' counter both routes read.
-- authority: begin
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authority') THEN
CREATE ROLE authority LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS authority AUTHORIZATION authority;
CREATE TABLE IF NOT EXISTS authority.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE authority.state OWNER TO authority;
INSERT INTO authority.state (hostname, name, value) VALUES ('authority', 'delay_ms', '0'),
    ('authority', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call either route takes is numbered; a number that is a multiple of
-- fail_one_in answers 503 (the standing one in fifty, D214's precedent).
CREATE SEQUENCE IF NOT EXISTS authority.calls;
ALTER SEQUENCE authority.calls OWNER TO authority;
-- authority: end

-- One row a yearly report the authority acknowledged, keyed by the
-- customer's report_key (amu-<year>-<species>): its reference, the body as
-- first acknowledged, the acknowledged calls counted (a repeat answers the
-- same reference, never a second report).
CREATE TABLE authority.amu_reports (
    report_key text        PRIMARY KEY,
    reference  text        NOT NULL UNIQUE,
    body       jsonb       NOT NULL,
    first_at   timestamptz NOT NULL DEFAULT now(),
    last_at    timestamptz NOT NULL DEFAULT now(),
    accepted   integer     NOT NULL DEFAULT 1
);
ALTER TABLE authority.amu_reports OWNER TO authority;

-- Every call to POST /amu-reports: its number, its key, the status answered
-- (201, 503, 422), when.
CREATE TABLE authority.amu_report_calls (
    call       bigint      PRIMARY KEY,
    report_key text,
    status     integer     NOT NULL,
    at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX amu_report_calls_key_idx ON authority.amu_report_calls (report_key);
ALTER TABLE authority.amu_report_calls OWNER TO authority;

-- data.sql of the head office's stub (v0.5 master spec 10.2, 12.2 purpose 9;
-- clinic-purposes.md 13; capture W4 items 0 and 5; W2-f; partners/README.md):
-- its role, its schema, its state and the monthly figures it took, in the
-- partners' database. The GM copies it after partners/shared/partners-db/
-- data.sql (and any other stub's data.sql) in partners-db's data file
-- (load-data runs that file connected to partners).
--
-- The role (LOGIN, no password here: render's secret
-- role_headoffice_password, set by load-data), the schema, the state and the
-- calls' counter its route reads.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'headoffice') THEN
CREATE ROLE headoffice LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS headoffice AUTHORIZATION headoffice;
CREATE TABLE IF NOT EXISTS headoffice.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE headoffice.state OWNER TO headoffice;
INSERT INTO headoffice.state (hostname, name, value) VALUES ('head-office', 'delay_ms', '0'),
    ('head-office', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call is numbered; a number that is a multiple of fail_one_in answers
-- 503 (the standing one in fifty, D214's precedent).
CREATE SEQUENCE IF NOT EXISTS headoffice.calls;
ALTER SEQUENCE headoffice.calls OWNER TO headoffice;

-- One row a month's figures the head office acknowledged, keyed by the
-- customer's figures_key (figures-<centre>-<YYYY-MM>): its reference, the
-- body as first acknowledged, the acknowledged calls counted (a repeat
-- answers the same reference, never a second month).
CREATE TABLE headoffice.figures (
    figures_key text        PRIMARY KEY,
    reference   text        NOT NULL UNIQUE,
    body        jsonb       NOT NULL,
    first_at    timestamptz NOT NULL DEFAULT now(),
    last_at     timestamptz NOT NULL DEFAULT now(),
    accepted    integer     NOT NULL DEFAULT 1
);
ALTER TABLE headoffice.figures OWNER TO headoffice;

-- Every call to POST /figures: its number, its key, the status answered
-- (201, 503, 422), when.
CREATE TABLE headoffice.figure_calls (
    call        bigint      PRIMARY KEY,
    figures_key text,
    status      integer     NOT NULL,
    at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX figure_calls_key_idx ON headoffice.figure_calls (figures_key);
ALTER TABLE headoffice.figure_calls OWNER TO headoffice;

-- data.sql of the messaging service's stub, purpose 16's partner (v0.5 master
-- spec 10.2, 12.2 purpose 16; vet-portal-domain.md, "vet-portal-messages";
-- capture W4 items 0 and 6, W3 item 5; W2-f; partners/README.md; spec D404):
-- its role, its schema, its state, the calls' counter and what it received, in
-- the partners' database. The GM copies it after
-- partners/shared/partners-db/data.sql in partners-db's data file (load-data
-- runs that file connected to partners, before any domain). The messages of
-- the 14 days before T0 are planted by the purpose's history, after the
-- portal's derivation, which also grants owners its SELECT (the owners'
-- route reads the tokens and the recipients; owners does not exist yet when
-- this file runs, so the grant below is guarded).
--
-- The role: LOGIN with no password here; render derives its secret
-- role_messaging_password from the connection messaging-db (partners-api's
-- api.yaml, the back end's schedule.yaml) and load-data sets it.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'messaging') THEN
CREATE ROLE messaging LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS messaging AUTHORIZATION messaging;

-- Its state, read by its route at each request (capture W2 item 6, "A
-- misbehaviour key"): delay_ms, added before any answer; fail_one_in, the
-- standing 503 (one call in fifty). The back end's stream messaging.normal
-- upserts this baseline once a minute; a fault's key messaging.<behaviour>
-- upserts other values.
CREATE TABLE IF NOT EXISTS messaging.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE messaging.state OWNER TO messaging;
INSERT INTO messaging.state (hostname, name, value) VALUES ('messaging', 'delay_ms', '0'),
    ('messaging', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call is numbered; a number that is a multiple of fail_one_in answers 503.
CREATE SEQUENCE IF NOT EXISTS messaging.calls;
ALTER SEQUENCE messaging.calls OWNER TO messaging;

-- One row a message the service accepted (W3 item 5), keyed by the sender's
-- message_key: the service's id (provider_id), the channel and address, the
-- template, the sender's account reference, the payload as first accepted,
-- when it arrived; the same key again answers the same id, never a second
-- message.
CREATE TABLE IF NOT EXISTS messaging.messages (
    message_key uuid        PRIMARY KEY,
    provider_id uuid        NOT NULL UNIQUE,
    channel     text        NOT NULL,
    address     text        NOT NULL,
    template    text        NOT NULL,
    account_id  integer,
    payload     jsonb       NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    accepted    integer     NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS messages_received_idx ON messaging.messages (received_at);
CREATE INDEX IF NOT EXISTS messages_account_idx ON messaging.messages (account_id, template);
ALTER TABLE messaging.messages OWNER TO messaging;

-- Every call to POST /messages: its number, its key, the status answered
-- (202, 503, 422), when (MS1's and the retries' evidence).
CREATE TABLE IF NOT EXISTS messaging.message_calls (
    call        bigint      PRIMARY KEY,
    message_key uuid,
    status      integer     NOT NULL,
    at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS message_calls_key_idx ON messaging.message_calls (message_key);
ALTER TABLE messaging.message_calls OWNER TO messaging;

DO $$ BEGIN IF to_regrole('owners') IS NOT NULL THEN
GRANT USAGE ON SCHEMA messaging TO owners;
GRANT SELECT ON messaging.messages TO owners;
END IF; END $$;
