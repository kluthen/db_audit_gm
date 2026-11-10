-- vet-portal-release's DDL in the owners' portal (v0.5 master spec 12.1, 12.2
-- purpose 15; vet-portal-domain.md, "vet-portal-release", "Who sees what" and
-- "The roles the purposes add"; clinic-purposes.md "The roles the purposes
-- add"; capture W4 items 0, 6 and 7 of specs/versions/v0.5/wave-log.md),
-- named by purpose.yaml's ddl.target. load-data reads it from the catalogue at
-- step (2b), after every domain's load and before the derivation, and runs it
-- as postgres connected to the database the scenario maps the target to
-- (portal), unseen, with the variables load_epoch, customer_timezone and
-- customer_utc_offset and no key functions. It never creates a database nor
-- \connects; the database is :"DBNAME".
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

-- The release jobs' role on the portal (this purpose's alone). LOGIN, its
-- password the game's secret; CONNECT by name, the portal's schema having
-- revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'portal_sync') THEN
CREATE ROLE portal_sync LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO portal_sync;

-- The ops grants (W4 item 0): each run's row, its watermarks.
GRANT USAGE ON SCHEMA ops TO portal_sync;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO portal_sync;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO portal_sync;

-- The copies, the accounts, the documents and the invitations
-- (clinic-purposes.md, portal_sync): accounts inserted (an invited one each,
-- its link's hash and expiry) and their contacts and synced_at updated, never
-- a closed one's (the job's care); the copies upserted; the documents
-- inserted, a former version's superseded_at set; invitations queued in the
-- outbox. The portal's tables all force row-level security: portal_sync's
-- policies, <table>_sync, USING (true) and WITH CHECK (true) where it writes
-- (W4 item 6), beside portal_api's and gm_check's (W4 item 7).
GRANT SELECT, INSERT ON portal_accounts TO portal_sync;
GRANT UPDATE (display_name, email, phone, synced_at) ON portal_accounts TO portal_sync;
GRANT SELECT, INSERT, UPDATE ON portal_animals, portal_ownerships, portal_herds TO portal_sync;
GRANT SELECT, INSERT ON portal_documents TO portal_sync;
GRANT UPDATE (superseded_at) ON portal_documents TO portal_sync;
GRANT SELECT ON portal_settings TO portal_sync;
GRANT SELECT, INSERT ON portal_outbox TO portal_sync;
GRANT USAGE ON SEQUENCE portal_accounts_id_seq, portal_documents_id_seq, portal_outbox_id_seq TO portal_sync;

DROP POLICY IF EXISTS portal_settings_sync ON portal_settings;
CREATE POLICY portal_settings_sync ON portal_settings FOR SELECT TO portal_sync USING (true);
DROP POLICY IF EXISTS portal_accounts_sync ON portal_accounts;
CREATE POLICY portal_accounts_sync ON portal_accounts FOR ALL TO portal_sync USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS portal_animals_sync ON portal_animals;
CREATE POLICY portal_animals_sync ON portal_animals FOR ALL TO portal_sync USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS portal_ownerships_sync ON portal_ownerships;
CREATE POLICY portal_ownerships_sync ON portal_ownerships FOR ALL TO portal_sync USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS portal_herds_sync ON portal_herds;
CREATE POLICY portal_herds_sync ON portal_herds FOR ALL TO portal_sync USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS portal_documents_sync ON portal_documents;
CREATE POLICY portal_documents_sync ON portal_documents FOR ALL TO portal_sync USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS portal_outbox_sync ON portal_outbox;
CREATE POLICY portal_outbox_sync ON portal_outbox FOR ALL TO portal_sync USING (true) WITH CHECK (true);

-- The watermarks at load_epoch (W4 items 0 and 6): the domains' state at T0
-- is their state at that moment, and the derivation writes T0's copies and
-- documents. identity (sync-portal-identity: registrations, ownerships,
-- deaths), records (publish-records: signatures, discharges), results
-- (publish-results: releases, amendments).
INSERT INTO ops.watermarks (purpose, name, at)
VALUES ('vet-portal-release', 'identity', :'load_epoch'), ('vet-portal-release', 'records', :'load_epoch'),
       ('vet-portal-release', 'results', :'load_epoch')
ON CONFLICT (purpose, name) DO NOTHING;
