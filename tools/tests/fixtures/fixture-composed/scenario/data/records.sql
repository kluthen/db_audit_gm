-- records' data file (tools/tests, v0.5 chunk 8): the back office's database,
-- which no domain holds, and fx-weekly's table, planted by its history.
CREATE DATABASE office;
REVOKE CONNECT ON DATABASE office FROM PUBLIC;
\connect office
CREATE TABLE weekly_stays (week date PRIMARY KEY, stays integer NOT NULL);
