-- machines' data file in aldermoor-centre (as the clinic load fixture's;
-- capture W3 item 4): the
CREATE DATABASE jobs;
REVOKE CONNECT ON DATABASE jobs FROM PUBLIC;
\connect jobs
CREATE EXTENSION pg_cron;
