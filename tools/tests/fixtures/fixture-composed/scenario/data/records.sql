-- records' data file (tools/tests, v0.5 chunk 8): the back office's database,
-- which no domain holds, and fx-weekly's table, planted by its history; pg_cron
-- in office, its cron.database_name (chunk 29's (d)).
CREATE DATABASE office;
REVOKE CONNECT ON DATABASE office FROM PUBLIC;
\connect office
CREATE EXTENSION pg_cron;
CREATE TABLE weekly_stays (week date PRIMARY KEY, stays integer NOT NULL);
