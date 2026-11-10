-- vet-portal-release's DDL in the laboratory's database (v0.5 master spec
-- 12.1, 12.2 purpose 15; vet-portal-domain.md, "vet-portal-release" and "The
-- roles the purposes add"; clinic-purposes.md "The roles the purposes add";
-- capture W4 items 0 and 6 of specs/versions/v0.5/wave-log.md), named by
-- purpose.yaml's ddl.source_lab. load-data reads it from the catalogue at step
-- (2b) and runs it as postgres connected to the database the scenario maps
-- source_lab to (lab), unseen, with the variables load_epoch,
-- customer_timezone and customer_utc_offset and no key functions. It never
-- creates a database nor \connects; the database is :"DBNAME". The purpose
-- writes nothing here: no ops schema.
--
-- The release jobs' role on the lab (this purpose's alone). LOGIN, its
-- password the game's secret; CONNECT by name.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lab_release') THEN
CREATE ROLE lab_release LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO lab_release;

-- The released tests of account 1 and their results: the orders without
-- their identifiers or clinical notes (a column grant), the tests, results,
-- analytes and intervals. Beside the list (reported to spec-writer): the
-- samples' collection time (lab_samples (id, collected_at)), a result
-- document's record time, as the derivation writes it.
GRANT SELECT (id, account_id, animal_id, ordered_at) ON lab_orders TO lab_release;
GRANT SELECT ON lab_order_tests, lab_results, lab_tests, lab_analytes, lab_reference_intervals TO lab_release;
GRANT SELECT (id, collected_at) ON lab_samples TO lab_release;
