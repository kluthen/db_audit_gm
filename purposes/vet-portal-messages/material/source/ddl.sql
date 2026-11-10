-- vet-portal-messages' DDL in the owners' portal (v0.5 master spec 12.1, 12.2
-- purpose 16; vet-portal-domain.md, "vet-portal-messages", "Who sees what"
-- and "The roles the purposes add"; clinic-purposes.md "The roles the
-- purposes add"; capture W4 items 0, 6 and 7 of
-- specs/versions/v0.5/wave-log.md), named by purpose.yaml's ddl.source.
-- load-data reads it from the catalogue at step (2b), after every domain's
-- load and before the derivation, and runs it as postgres connected to the
-- database the scenario maps the source to (portal), unseen, with the
-- variables load_epoch, customer_timezone and customer_utc_offset and no key
-- functions. It never creates a database nor \connects; the database is
-- :"DBNAME".
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

-- The messages' jobs' role on the portal (this purpose's alone). LOGIN, its
-- password the game's secret; CONNECT by name.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'portal_dispatch') THEN
CREATE ROLE portal_dispatch LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO portal_dispatch;

-- The ops grants (W4 item 0): each run's row, its watermark, the failed
-- messages' incidents.
GRANT USAGE ON SCHEMA ops TO portal_dispatch;
GRANT SELECT, INSERT ON ops.runs, ops.incidents TO portal_dispatch;
GRANT SELECT, INSERT, UPDATE ON ops.watermarks TO portal_dispatch;

-- What the messages need (clinic-purposes.md, portal_dispatch): the accounts'
-- status, channel and address (beside the list, reported to spec-writer:
-- the account's id and owner, which the outbox names, and its display name,
-- the payload's recipient's name as the derivation writes it); the copies;
-- the documents' animal, herd and publication; the consent events; the
-- settings (the zone, the reminders' lead and hours); the outbox, its queued
-- notices and reminders inserted and its sending columns updated. The
-- portal's tables all force row-level security: portal_dispatch's policies,
-- <table>_dispatch, USING (true), WITH CHECK (true) where it writes (W4 item
-- 6), beside portal_api's and gm_check's (W4 item 7).
GRANT SELECT (id, owner_id, display_name, email, phone, status, notify_by) ON portal_accounts TO portal_dispatch;
GRANT SELECT ON portal_animals, portal_ownerships, portal_herds, portal_consent_events, portal_settings
   TO portal_dispatch;
GRANT SELECT (id, animal_id, herd_id, record_at, published_at) ON portal_documents TO portal_dispatch;
GRANT SELECT, INSERT ON portal_outbox TO portal_dispatch;
GRANT UPDATE (sent_at, attempts, last_status, provider_id, failed_at) ON portal_outbox TO portal_dispatch;
GRANT USAGE ON SEQUENCE portal_outbox_id_seq TO portal_dispatch;

DROP POLICY IF EXISTS portal_settings_dispatch ON portal_settings;
CREATE POLICY portal_settings_dispatch ON portal_settings FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_accounts_dispatch ON portal_accounts;
CREATE POLICY portal_accounts_dispatch ON portal_accounts FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_animals_dispatch ON portal_animals;
CREATE POLICY portal_animals_dispatch ON portal_animals FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_ownerships_dispatch ON portal_ownerships;
CREATE POLICY portal_ownerships_dispatch ON portal_ownerships FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_herds_dispatch ON portal_herds;
CREATE POLICY portal_herds_dispatch ON portal_herds FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_documents_dispatch ON portal_documents;
CREATE POLICY portal_documents_dispatch ON portal_documents FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_consent_events_dispatch ON portal_consent_events;
CREATE POLICY portal_consent_events_dispatch ON portal_consent_events FOR SELECT TO portal_dispatch USING (true);
DROP POLICY IF EXISTS portal_outbox_dispatch ON portal_outbox;
CREATE POLICY portal_outbox_dispatch ON portal_outbox FOR ALL TO portal_dispatch USING (true) WITH CHECK (true);

-- The watermark at load_epoch (W4 items 0 and 6): notices (queue-notices,
-- the documents published since it). The derivation queues T0's notices.
INSERT INTO ops.watermarks (purpose, name, at) VALUES ('vet-portal-messages', 'notices', :'load_epoch')
ON CONFLICT (purpose, name) DO NOTHING;
