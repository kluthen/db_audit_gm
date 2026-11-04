-- vet-machinery's pg_cron jobs (vet-machinery-domain.md, "Fixed-time
-- operations", "Loading"; capture W3 item 4; spec D405): run by gmctl
-- load-data on machines after the part's three loads, as postgres, connected
-- to the node's cron.database_name, unseen; the jobs' databases (vitals,
-- biomed) and their role (mach_maint, LOGIN with CONNECT on both: pg_cron runs
-- a job only as such a role) exist by then. Each job runs as mach_maint,
-- whose one privilege is EXECUTE on mach_create_partitions(days). Times are
-- cron.timezone's (the customer's zone where the seed sets it). Written for
-- the databases vitals and biomed; the GM renames them as the scenario's at:
-- does.
SELECT cron.schedule_in_database('vitals-partitions', '0 22 * * *',
       $job$SELECT mach_create_partitions(3)$job$, 'vitals', 'mach_maint');
SELECT cron.schedule_in_database('readings-partitions', '5 22 * * *',
       $job$SELECT mach_create_partitions(3)$job$, 'biomed', 'mach_maint');
-- next month's mach_events partition: seven days from the 25th reach it in
-- every month (and the readings' days a week ahead, harmlessly)
SELECT cron.schedule_in_database('events-partitions', '0 22 25 * *',
       $job$SELECT mach_create_partitions(7)$job$, 'biomed', 'mach_maint');
