-- vet-lab-centre-orders: the DDL of its target, clinic (purpose.yaml ddl.target;
-- v0.5 master spec 12.1, 12.2 purpose 1; clinic-purposes.md section 5 and "The
-- roles the purposes add"; capture W4 items 0 and 3 of
-- specs/versions/v0.5/wave-log.md). Run by gmctl load-data at step (2b), as
-- postgres connected to the database the scenario maps the part to (vet-core's,
-- :"DBNAME"), after every domain's load, unseen, with load_epoch; read from the
-- catalogue at every load, never copied.
--
-- 1. The ops schema, the same text in every purpose's DDL between the lines
--    "-- ops: begin" and "-- ops: end" (tools/tests/test_purposes.py keeps it
--    byte-identical): guarded, so whichever purpose's DDL runs first in a
--    database creates it for all.
-- 2. vet_interfaces, the integration engine's role on clinic (purposes 1, 4,
--    5, 11, 13 each create it, guarded), LOGIN, its password the game's secret
--    (load-data); CONNECT granted by name (vet-core revokes it from PUBLIC).
-- 3. Its grants for this purpose: the requests read and their state columns
--    written (never another column), the consultations' state and close, the
--    administered prescription lines' withdrawal end (a residue screening);
--    the ops tables.
-- 4. The purpose's own tables, owned by ops: the posts' ledger and the copied
--    results; its watermark at load_epoch (the domains' state at T0 is their
--    state at that moment, W2 item 3).
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

DO $guard$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'vet_interfaces') THEN
CREATE ROLE vet_interfaces LOGIN;   -- the integration engine's jobs (interfaces)
END IF; END $guard$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_interfaces;

GRANT SELECT ON requests TO vet_interfaces;
GRANT UPDATE (state, sent_at, resulted_at, cancelled_at) ON requests TO vet_interfaces;
GRANT SELECT (id, state, ended_at) ON consultations TO vet_interfaces;
GRANT SELECT (id, animal_id, prescription_line_id) ON administrations TO vet_interfaces;
GRANT SELECT (id, withdrawal_ends_on) ON prescription_lines TO vet_interfaces;

SET ROLE ops;
-- One row an order posted to lab-api (client_ref C-<consultation>-<priority>,
-- the idempotency key): its requests, the accession lab-api answered, the
-- attempts, the last HTTP status (or timeout, refused), the first post and the
-- answer's time; the run that last wrote it.
CREATE TABLE IF NOT EXISTS ops.lab_orders_sent (
    client_ref  text        PRIMARY KEY,
    request_ids integer[]   NOT NULL,
    accession   integer,
    attempts    integer     NOT NULL DEFAULT 1,
    last_status text        NOT NULL,
    posted_at   timestamptz NOT NULL,
    answered_at timestamptz,
    run_id      bigint      NOT NULL REFERENCES ops.runs (id));
-- One row a request whose test the lab released, did not perform or
-- cancelled (the released-results feed): the lab's time and reason, the copy's
-- time; the request's state follows in the same transaction.
CREATE TABLE IF NOT EXISTS ops.request_results (
    request_id    integer     PRIMARY KEY,
    order_test_id integer     NOT NULL,
    accession     integer     NOT NULL,
    status        text        NOT NULL CHECK (status IN ('released', 'not-performed', 'cancelled')),
    reason        text,
    released_at   timestamptz NOT NULL,
    copied_at     timestamptz NOT NULL DEFAULT now(),
    run_id        bigint      NOT NULL REFERENCES ops.runs (id));
RESET ROLE;

GRANT USAGE ON SCHEMA ops TO vet_interfaces;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO vet_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO vet_interfaces;
GRANT SELECT, INSERT, UPDATE ON ops.lab_orders_sent TO vet_interfaces;
GRANT SELECT, INSERT ON ops.request_results TO vet_interfaces;

-- The released-results feed's keyset position: (the feed's time, its
-- order_test_id), read back with a margin by fetch-lab-results.
INSERT INTO ops.watermarks (purpose, name, at, last_id)
VALUES ('vet-lab-centre-orders', 'lab-results', :'load_epoch', 0)
ON CONFLICT DO NOTHING;
