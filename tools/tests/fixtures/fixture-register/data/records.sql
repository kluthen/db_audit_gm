-- records' data file (tools/tests, v0.5 wave 3 gate, spec D407; the portal
-- fixture's, chunk 16b; capture W3 items 4 and 5):
-- the database jobs, pg_cron's cron.database_name, which no domain holds, and
-- the extension in it. load-data runs it before the domains' loads; vet-core
-- creates clinic, vet-portal portal, and vet-portal's data/cron.sql schedules
-- the sessions' purge here once portal and portal_housekeeping exist.
CREATE DATABASE jobs;
REVOKE CONNECT ON DATABASE jobs FROM PUBLIC;
\connect jobs
CREATE EXTENSION pg_cron;
