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
-- exists. The owners' own logins (owners.accounts) are the load's accounts as
-- each browser remembers its own: the route cannot read portal, and an
-- address is a hash of the core's (pg_temp.core_owner).
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

-- The owners' own logins, as each browser remembers them: every account of the
-- load (2-10 000; owner n's, docs/gm.md "Part keys"), its e-mail, its status
-- as the route last knew it (the load's at T0, then the route's own
-- activations and closures), the open planted link's template (invitation or
-- password-reset) and, for an invitation whose activation delay
-- (pg_temp.portal_activation_delay: none for three in ten) ends after T0,
-- when its owner activates it (owners.activate). Accounts made in play (20 001
-- on) join from the messaging stub's invitations.
CREATE TABLE owners.accounts (
    account_id   integer     PRIMARY KEY,
    email        text        NOT NULL,
    status       text        NOT NULL CHECK (status IN ('invited', 'active', 'closed')),
    link         text        CHECK (link IN ('invitation', 'password-reset')),
    activates_at timestamptz
);
ALTER TABLE owners.accounts OWNER TO owners;
INSERT INTO owners.accounts (account_id, email, status, link, activates_at)
SELECT n, a.email, a.status, a.open_template,
       CASE WHEN a.status = 'invited' AND a.open_template = 'invitation'
            THEN a.invited_at + pg_temp.portal_activation_delay(n) END
  FROM generate_series(2, 10000) AS n,
       LATERAL pg_temp.portal_account(n, :'load_epoch'::timestamptz, :'customer_utc_offset'::integer) AS a
 WHERE a.status <> 'closed';
CREATE INDEX accounts_activates_idx ON owners.accounts (activates_at) WHERE activates_at IS NOT NULL;
