-- Restored-backup data of fixture-v04-refusals' reporting node (tools/tests,
-- v0.4 chunk 2): the agency's reporting database, written as capture W1
-- item 0 reads a data file.
CREATE ROLE bi_etl LOGIN;
CREATE DATABASE reporting OWNER bi_etl;

\connect reporting
SET ROLE bi_etl;

CREATE TABLE sales_hourly (
    hour      timestamptz   PRIMARY KEY,
    total     numeric(12,2) NOT NULL,
    copied_at timestamptz   NOT NULL
);
