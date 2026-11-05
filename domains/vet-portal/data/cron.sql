-- vet-portal's pg_cron job (vet-portal-domain.md, "Fixed-time operation",
-- "Loading"; capture W3 items 4 and 5; spec D405): run by gmctl load-data on
-- records after the part's load, as postgres, connected to the node's
-- cron.database_name, unseen; the job's database (portal) and its role
-- (portal_housekeeping, LOGIN with CONNECT on portal: pg_cron runs a job only
-- as such a role) exist by then. The job runs as portal_housekeeping, whose
-- one privilege is the sessions' purge (portal_sessions_purge: sessions ended,
-- or expired, 30 days ago; rule 11). Its time is cron.timezone's (the
-- customer's zone where the seed sets it). Written for the database portal;
-- the GM renames it as the scenario's at: does (T254: a cron.schedule in the
-- wrong database).
SELECT cron.schedule_in_database('portal.sessions.purge', '30 3 * * *',
       $job$DELETE FROM portal_sessions WHERE coalesce(ended_at, expires_at) < now() - interval '30 days'$job$,
       'portal', 'portal_housekeeping');
