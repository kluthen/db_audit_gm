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

-- --- The two sample partners (fixture-partners, v0.5 chunk 11a) ------------
-- In a game each is a composed domain's producers/partners/<prefix>/data.sql,
-- run into partners by load-data (chunk 8); here the fixture's own, written
-- as such a file would be: its role, LOGIN with no password (render's secret
-- role_<prefix>_password, set by load-data), its schema owned by it, its
-- state table and its baseline (capture W2 item 6).
CREATE ROLE alpha LOGIN;
CREATE SCHEMA alpha AUTHORIZATION alpha;
CREATE TABLE alpha.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE alpha.state OWNER TO alpha;
INSERT INTO alpha.state (hostname, name, value) VALUES ('alpha-lab', 'delay_ms', '0');

CREATE ROLE beta LOGIN;
CREATE SCHEMA beta AUTHORIZATION beta;
CREATE TABLE beta.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name)
);
ALTER TABLE beta.state OWNER TO beta;
INSERT INTO beta.state (hostname, name, value) VALUES ('beta-lab', 'delay_ms', '0');
