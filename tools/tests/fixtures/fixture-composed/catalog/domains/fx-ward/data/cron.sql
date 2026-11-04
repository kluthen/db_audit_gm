-- The test part's pg_cron job (tools/tests, v0.5 chunk 29's (d)): run by
-- load-data on records after fx-ward's load, connected to cron.database_name
-- (office), once clinic and ward_app exist; unseen.
SELECT cron.schedule_in_database('fx-ward-tidy', '0 3 * * *',
       $job$DELETE FROM ward_placements WHERE upper(during) < now() - interval '30 days'$job$,
       'clinic', 'ward_app');
