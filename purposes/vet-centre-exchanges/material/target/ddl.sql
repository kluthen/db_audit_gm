-- vet-centre-exchanges' DDL in the core's record (v0.5 master spec 12.1,
-- 12.2 purpose 4; clinic-purposes.md 8 and "The roles the purposes add";
-- capture W4 items 0 and 4 of specs/versions/v0.5/wave-log.md), named by
-- purpose.yaml's ddl.target. load-data reads it from the catalogue at step
-- (2b), after every domain's load, and runs it as postgres connected to the
-- database the scenario maps the target to (clinic), unseen, with the
-- variables load_epoch, customer_timezone and customer_utc_offset and no key
-- functions. It never creates a database nor \connects; the database is
-- :"DBNAME". Roles two purposes create on one node are created guarded.
--
-- The ops schema (W4 item 0), the same text in every purpose's DDL:
-- ops: begin
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ops') THEN
CREATE ROLE ops NOLOGIN;   -- owns the purposes' tables
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS ops AUTHORIZATION ops;
REVOKE ALL ON SCHEMA ops FROM PUBLIC;
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.runs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL,
    started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL DEFAULT now(),
    rows_read integer NOT NULL DEFAULT 0, rows_written integer NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS runs_job_idx ON ops.runs (purpose, job, started_at);
CREATE TABLE IF NOT EXISTS ops.incidents (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL, kind text NOT NULL, ref text NOT NULL,
    opened_at timestamptz NOT NULL DEFAULT now(), reason text NOT NULL,
    run_id bigint REFERENCES ops.runs (id));
CREATE INDEX IF NOT EXISTS incidents_ref_idx ON ops.incidents (purpose, kind, ref);
CREATE TABLE IF NOT EXISTS ops.watermarks (
    purpose text NOT NULL, name text NOT NULL,
    at timestamptz, last_id bigint, run_id bigint REFERENCES ops.runs (id),
    PRIMARY KEY (purpose, name));
RESET ROLE;
-- ops: end

-- The purpose's roles: the engine's (purposes 1, 4, 5, 11 and 13 create it,
-- each guarded) and clinic-api's exchange endpoints'. LOGIN, their passwords
-- the game's secrets (load-data sets them); CONNECT by name, load-data having
-- revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_interfaces') THEN
CREATE ROLE vet_interfaces LOGIN;
END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_exchange') THEN
CREATE ROLE vet_exchange LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_interfaces, vet_exchange;

-- Each message either way (clinic-purposes.md 8, "Trace"): the exchange's
-- key and id, its kind (a request, a chase's resend, an answer, a report),
-- its direction (out: posted by the engine to a centre's hostname; in: taken
-- at clinic-api's exchange endpoints, the centre its site's code), the HTTP
-- status answered (none: no answer, a timeout or a refusal), when.
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.exchange_messages (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id       bigint      NOT NULL REFERENCES ops.runs (id),
    exchange_id  integer,
    exchange_key uuid        NOT NULL,
    kind         text        NOT NULL CHECK (kind IN ('request', 'resend', 'answer', 'report')),
    direction    text        NOT NULL CHECK (direction IN ('out', 'in')),
    centre       text        NOT NULL,
    http_status  integer,
    at           timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX IF NOT EXISTS exchange_messages_key_idx ON ops.exchange_messages (exchange_key, kind);
CREATE INDEX IF NOT EXISTS exchange_messages_at_idx ON ops.exchange_messages (at);
RESET ROLE;

-- The ops grants (W4 item 0), for each of the purpose's roles.
GRANT USAGE ON SCHEMA ops TO vet_interfaces, vet_exchange;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO vet_interfaces, vet_exchange;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO vet_interfaces, vet_exchange;
GRANT SELECT, INSERT ON ops.exchange_messages TO vet_interfaces, vet_exchange;

-- The engine: the exchanges and what a request carries (the animal's
-- identity, its record's summary, its current owner's name and contact;
-- clinic-purposes.md 8, "Data moved"), the customer's zone for the working
-- days; it writes an outbound request's state and sent_at only.
GRANT SELECT ON exchanges, sites, business_settings, ownerships TO vet_interfaces;
GRANT SELECT (id, species, breed, sex, born_on, name, microchip, ueln, passport_number, ear_tag)
   ON animals TO vet_interfaces;
GRANT SELECT (id, kind, name, email, phone) ON owners TO vet_interfaces;
GRANT SELECT (id, animal_id, state, started_at, findings) ON consultations TO vet_interfaces;
GRANT UPDATE (state, sent_at) ON exchanges TO vet_interfaces;

-- The exchange endpoints: the centres' requests (inbound rows), their
-- answers and reports on the clinic's (clinic-purposes.md, "The roles the
-- purposes add": vet_exchange).
GRANT SELECT, INSERT ON exchanges TO vet_exchange;
GRANT UPDATE (state, accepted_for, answered_at, report, reported_at) ON exchanges TO vet_exchange;
GRANT SELECT (id, code, kind) ON sites TO vet_exchange;

-- The engine's watermarks start at load_epoch (W4 item 0): an inbound answer
-- or report given before T0 counts as posted, as the centres' stub holds it.
INSERT INTO ops.watermarks (purpose, name, at) VALUES
    ('vet-centre-exchanges', 'answers', :'load_epoch'),
    ('vet-centre-exchanges', 'reports', :'load_epoch')
ON CONFLICT DO NOTHING;
