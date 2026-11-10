-- vet-imaging-orders' DDL in the core's record (v0.5 master spec 12.1, 12.2 purpose
-- 13; vet-machinery-domain.md, "vet-imaging-orders"; clinic-purposes.md "The
-- roles the purposes add"; spec D416; capture W4 items 0 and 6 of
-- specs/versions/v0.5/wave-log.md), named by purpose.yaml's ddl.source.
-- load-data reads it from the catalogue at step (2b), after every domain's
-- load, and runs it as postgres connected to the database the scenario maps
-- the source to (clinic), unseen, with the variables load_epoch,
-- customer_timezone and customer_utc_offset and no key functions. It never
-- creates a database nor \connects; the database is :"DBNAME".
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

-- The engine's core role (purposes 1, 4, 5, 11 and 13 create it, each
-- guarded). LOGIN, its password the game's secret (load-data sets it);
-- CONNECT by name, load-data having revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_interfaces') THEN
CREATE ROLE vet_interfaces LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_interfaces;

-- The finals copied back (vet-machinery-domain.md, purpose 13's trace): one
-- row a signed final (an addendum is a new one), its request, accession and
-- report, when it was signed and copied, the run that copied it.
SET ROLE ops;
CREATE TABLE IF NOT EXISTS ops.imaging_results (
    id         bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id     bigint      NOT NULL REFERENCES ops.runs (id),
    request_id integer     NOT NULL,
    accession  text        NOT NULL,
    report_id  integer     NOT NULL,
    signed_at  timestamptz NOT NULL,
    copied_at  timestamptz NOT NULL DEFAULT clock_timestamp());
CREATE INDEX IF NOT EXISTS imaging_results_request_idx ON ops.imaging_results (request_id);
CREATE INDEX IF NOT EXISTS imaging_results_report_idx ON ops.imaging_results (report_id);
RESET ROLE;

-- The ops grants (W4 item 0).
GRANT USAGE ON SCHEMA ops TO vet_interfaces;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO vet_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO vet_interfaces;
GRANT SELECT, INSERT ON ops.imaging_results TO vet_interfaces;

-- The engine on the core (clinic-purposes.md, vet_interfaces): the requests
-- and their consultation's state and close, the customer's zone (working
-- days); a request's state written
-- (sent, resulted, cancelled), never anything else of it.
GRANT SELECT ON requests, business_settings TO vet_interfaces;
GRANT SELECT (id, state, ended_at) ON consultations TO vet_interfaces;
GRANT UPDATE (state, sent_at, resulted_at, cancelled_at) ON requests TO vet_interfaces;

-- The watermarks start at load_epoch (W4 item 0): the finals signed and the
-- entries cancelled before T0 are the load's, already on their requests.
INSERT INTO ops.watermarks (purpose, name, at) VALUES
    ('vet-imaging-orders', 'finals', :'load_epoch'),
    ('vet-imaging-orders', 'cancellations', :'load_epoch')
ON CONFLICT DO NOTHING;
