-- g3-pg-cron-own-role: a pg_cron job run as postgres in reporting, where a
-- foreign table maps the shop's e-mails: judged (D230). Its schedule (31
-- February) never comes: nothing runs.
-- node: reporting
-- database: reporting
-- expect: G1=1 G2=0 G3=1 G4=0
\if :revert
SELECT cron.unschedule('peek');
DROP FOREIGN TABLE src.people;
\else
CREATE FOREIGN TABLE src.people (contact text OPTIONS (column_name 'email'))
    SERVER shop_db OPTIONS (schema_name 'public', table_name 'customers');
SELECT cron.schedule_in_database('peek', '0 3 31 2 *', 'SELECT count(*) FROM src.people',
                                 'reporting', username => 'postgres');
\endif
