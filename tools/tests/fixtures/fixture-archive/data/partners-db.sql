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
-- asked for and no more. The same shipment id again replaces its manifest
-- (POST /shipments upserts it); a new id for a day already shipped adds one.
CREATE TABLE coldstore.manifests (
    shipment_id   text PRIMARY KEY,           -- Shipment-Id: a segment's or backup's name, a data type's own
    type          text NOT NULL,              -- wal, basebackup, or a data type (vitals, machine-readings)
    source        text NOT NULL,              -- Shipment-Source: the customer's node
    name          text NOT NULL,              -- Shipment-Name: the segment's or backup's name
    rows_declared bigint NOT NULL,            -- Shipment-Rows
    rows_received bigint NOT NULL,            -- NDJSON lines counted; 1 for a non-empty wal or basebackup
    size          bigint NOT NULL,            -- the bytes received
    date_from     date NOT NULL,              -- Shipment-From, inclusive
    date_to       date NOT NULL,              -- Shipment-To, inclusive
    received_at   timestamptz NOT NULL DEFAULT now(),
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
        (0, 'records', true, true, '03:30', 30, 96)
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
