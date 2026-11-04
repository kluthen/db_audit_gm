-- data.sql of the owners' traffic, the owners' browsers on the partners'
-- nodes (v0.5 master spec 9.7, 10.2; vet-portal-domain.md, "The applications
-- and their nodes", answer 8; capture W3 item 5; spec D369, D406): its role,
-- its schema, the passwords' and links' key and its record of visits, in the
-- partners' database. The owners are no third party (no partners.md entry, no
-- contract, no misbehaviour key: no owners.state, no owners.normal stream).
-- load-data runs it connected to partners, as postgres, with vet-core's and
-- vet-portal's data/keys.sql streamed ahead of it (W3 item 0): the key is
-- pg_temp.portal_key(load_epoch), the one the portal's load hashed the
-- passwords and the planted links with; this is its only copy (D406). The
-- messaging stub's record (messaging.messages, its tokens and recipients) is
-- purpose 16's, planted by its history (D404); the route reads it when it
-- exists.
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'owners data.sql: psql variable load_epoch is not set'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.portal_key(timestamp with time zone)') IS NULL THEN
        RAISE EXCEPTION 'owners data.sql: vet-portal''s key functions are missing (load-data streams '
                        'vet-core''s and vet-portal''s data/keys.sql ahead of this file)';
    END IF;
END $$;

CREATE ROLE owners LOGIN;
CREATE SCHEMA owners AUTHORIZATION owners;

-- The route's settings: password_key, the HMAC key of every planted password
-- (the account's id) and one-time link ('<template>:<account id>').
CREATE TABLE owners.settings (
    name  text PRIMARY KEY,
    value text NOT NULL
);
ALTER TABLE owners.settings OWNER TO owners;
INSERT INTO owners.settings (name, value) VALUES ('password_key', pg_temp.portal_key(:'load_epoch'::timestamptz));

-- One row per call to portal-api (RL6's evidence, chunk 21): when, as which
-- account, the call ('POST /login', 'GET /animals', 'GET /animals/{id}/documents',
-- 'GET /documents/{id}', ...), the status it answered, the animals and
-- documents it returned.
CREATE TABLE owners.visits (
    id           bigint      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    at           timestamptz NOT NULL,
    account_id   integer,
    call         text        NOT NULL,
    status       integer,
    animal_ids   integer[],
    document_ids integer[]
);
ALTER TABLE owners.visits OWNER TO owners;
CREATE INDEX visits_at_idx ON owners.visits (at);
