-- records' data file (tools/tests, v0.5 chunk 19; capture W4 items 4 and 5):
-- the purposes' share, purpose 5's material/target/office.sql copied once
-- (the back office's database office, which no domain holds), nothing else.
-- load-data runs it as postgres, connected to postgres, before the domains'
-- loads; vet-core then creates clinic beside it.
-- office.sql: the back office's database office (v0.5 master spec 11.3,
-- 12.1 item 5, 12.2; clinic-purposes.md, "The roles the purposes add" and
-- "`office` at T0"; capture W4 item 5 of specs/versions/v0.5/wave-log.md),
-- byte-identical in purposes 5, 7, 8, 9, 10 and 12 (tools/tests/test_purposes.py
-- compares them). office belongs to no domain: the GM copies this file once,
-- at the head of the purposes' share of the primary's (records') data file,
-- then each purpose's material/target/data.sql after it. load-data streams
-- the data file into psql as postgres, connected to postgres, before any
-- domain; this file ends connected to postgres again.
--
-- Roles: office owns everything, no login; office_jobs, the back office's
-- writes (the report runner's), reads nothing of the record; office_reader,
-- the back office's staff and dashboards, reads office. The reports read the
-- record as the domains' vet_reports, sched_reports and lab_reports, created
-- by their schemas after this file: never here.
CREATE ROLE office NOLOGIN;
CREATE ROLE office_jobs LOGIN;
CREATE ROLE office_reader LOGIN;
CREATE DATABASE office OWNER office;
REVOKE CONNECT ON DATABASE office FROM PUBLIC;
GRANT CONNECT ON DATABASE office TO office_jobs, office_reader;

\connect office
SET ROLE office;
-- The run ledger, ops.runs' columns (W4 item 0): one row a run, in the
-- transaction of its output.
CREATE TABLE runs (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    purpose text NOT NULL, job text NOT NULL,
    started_at timestamptz NOT NULL, finished_at timestamptz NOT NULL DEFAULT now(),
    rows_read integer NOT NULL DEFAULT 0, rows_written integer NOT NULL DEFAULT 0);
CREATE INDEX runs_job_idx ON runs (purpose, job, started_at);
-- The copies of the regulatory submissions sent (purposes 5 and 8): kind
-- (notifiable-disease, amu-report), the source database, the notifier's key,
-- what was sent, when, the authority's reference.
CREATE TABLE regulatory_submissions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    kind text NOT NULL, source text NOT NULL, ref text NOT NULL,
    payload jsonb NOT NULL, sent_at timestamptz, reference text,
    copied_at timestamptz NOT NULL DEFAULT now(),
    run_id bigint NOT NULL REFERENCES runs (id));
CREATE INDEX regulatory_submissions_ref_idx ON regulatory_submissions (kind, ref);
RESET ROLE;
GRANT SELECT, INSERT, UPDATE ON runs, regulatory_submissions TO office_jobs;
GRANT SELECT ON runs, regulatory_submissions TO office_reader;
\connect postgres
