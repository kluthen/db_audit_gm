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
