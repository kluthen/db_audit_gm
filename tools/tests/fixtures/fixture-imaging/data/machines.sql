-- machines' data file (tools/tests, v0.5 chunk 15b; capture W3 item 4): the
-- database jobs, pg_cron's cron.database_name, which no domain holds, and the
-- extension in it. load-data runs it before the domains' loads; vet-machinery
-- creates pacs, vitals and biomed, and its data/cron.sql schedules the
-- partition jobs here once they exist.
CREATE DATABASE jobs;
REVOKE CONNECT ON DATABASE jobs FROM PUBLIC;
\connect jobs
CREATE EXTENSION pg_cron;
