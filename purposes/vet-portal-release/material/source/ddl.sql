-- vet-portal-release's DDL in the core's medical record (v0.5 master spec 12.1,
-- 12.2 purpose 15; vet-portal-domain.md, "vet-portal-release" and "The roles
-- the purposes add"; clinic-purposes.md "The roles the purposes add"; capture
-- W4 items 0 and 6 of specs/versions/v0.5/wave-log.md), named by
-- purpose.yaml's ddl.source. load-data reads it from the catalogue at step
-- (2b), after every domain's load, and runs it as postgres connected to the
-- database the scenario maps the source to (clinic), unseen, with the
-- variables load_epoch, customer_timezone and customer_utc_offset and no key
-- functions. It never creates a database nor \connects; the database is
-- :"DBNAME". The purpose writes nothing here: no ops schema.
--
-- The release jobs' role on the record (this purpose's alone). LOGIN, its
-- password the game's secret; CONNECT by name, the core's schema having
-- revoked it from PUBLIC.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vet_portal_sync') THEN
CREATE ROLE vet_portal_sync LOGIN;
END IF; END $$;
GRANT CONNECT ON DATABASE :"DBNAME" TO vet_portal_sync;

-- What the copies and the documents need, column grants where the roles
-- table names columns: the owners without their address, the animals without
-- their identifiers, the signed consultations' and the ended stays' content,
-- the vets' names. Beside the list (reported to spec-writer, as chunk 21a's
-- grants): animals.registered_at, the animals registered since the watermark
-- (sync-portal-identity's own statement), and sections (id, kind), the
-- section a document's body names, as the derivation writes it.
GRANT SELECT (id, kind, name, email, phone, registered_at) ON owners TO vet_portal_sync;
GRANT SELECT (id, name, species, sex, born_on, herd_id, status, died_at, registered_at) ON animals TO vet_portal_sync;
GRANT SELECT ON ownerships TO vet_portal_sync;
GRANT SELECT (id, keeper_owner_id) ON herds TO vet_portal_sync;
GRANT SELECT (id, animal_id, herd_id, kind, section_id, vet_id, started_at, signed_at, state)
   ON consultations TO vet_portal_sync;
GRANT SELECT ON diagnoses, diagnosis_codes, prescriptions, prescription_lines, stays TO vet_portal_sync;
GRANT SELECT (id, name) ON medicines TO vet_portal_sync;
GRANT SELECT (id, name) ON staff TO vet_portal_sync;
GRANT SELECT (id, kind) ON sections TO vet_portal_sync;
