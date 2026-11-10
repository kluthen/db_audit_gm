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
