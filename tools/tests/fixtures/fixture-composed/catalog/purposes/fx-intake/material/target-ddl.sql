-- fx-intake's target DDL (tools/tests, v0.5 chunk 29b; capture W3 addendum,
-- item 6 (e)): run by load-data as postgres, connected to its target (a
-- composed domain's database, :"DBNAME"), after the domains' loads and before
-- the derivations, unseen. Its role guarded (roles are the instance's), at
-- the start of a line, so model.node_creates sees it and render gives it a
-- secret; its own tables in schema ops.
DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'intake_watch') THEN
    CREATE ROLE intake_watch LOGIN;
  END IF;
END
$guard$;
GRANT CONNECT ON DATABASE :"DBNAME" TO intake_watch;
CREATE SCHEMA IF NOT EXISTS ops;
CREATE TABLE ops.runs (run_id integer PRIMARY KEY, ran_at timestamptz NOT NULL);
INSERT INTO ops.runs VALUES (0, :'load_epoch');   -- c29_ddl_canary
GRANT USAGE ON SCHEMA ops TO intake_watch;
GRANT SELECT, INSERT ON ops.runs TO intake_watch;
GRANT SELECT ON stays TO intake_watch;
CREATE POLICY intake_current ON stays FOR SELECT TO intake_watch USING (discharged_at IS NULL);
