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
