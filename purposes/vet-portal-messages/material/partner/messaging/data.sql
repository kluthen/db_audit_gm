-- data.sql of the messaging service's stub, purpose 16's partner (v0.5 master
-- spec 10.2, 12.2 purpose 16; vet-portal-domain.md, "vet-portal-messages";
-- capture W4 items 0 and 6, W3 item 5; W2-f; partners/README.md; spec D404):
-- its role, its schema, its state, the calls' counter and what it received, in
-- the partners' database. The GM copies it after
-- partners/shared/partners-db/data.sql in partners-db's data file (load-data
-- runs that file connected to partners, before any domain). The messages of
-- the 14 days before T0 are planted by the purpose's history, after the
-- portal's derivation, which also grants owners its SELECT (the owners'
-- route reads the tokens and the recipients; owners does not exist yet when
-- this file runs, so the grant below is guarded).
--
-- The role: LOGIN with no password here; render derives its secret
-- role_messaging_password from the connection messaging-db (partners-api's
-- api.yaml, the back end's schedule.yaml) and load-data sets it.
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'messaging') THEN
CREATE ROLE messaging LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS messaging AUTHORIZATION messaging;

-- Its state, read by its route at each request (capture W2 item 6, "A
-- misbehaviour key"): delay_ms, added before any answer; fail_one_in, the
-- standing 503 (one call in fifty). The back end's stream messaging.normal
-- upserts this baseline once a minute; a fault's key messaging.<behaviour>
-- upserts other values.
CREATE TABLE IF NOT EXISTS messaging.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE messaging.state OWNER TO messaging;
INSERT INTO messaging.state (hostname, name, value) VALUES ('messaging', 'delay_ms', '0'),
    ('messaging', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call is numbered; a number that is a multiple of fail_one_in answers 503.
CREATE SEQUENCE IF NOT EXISTS messaging.calls;
ALTER SEQUENCE messaging.calls OWNER TO messaging;

-- One row a message the service accepted (W3 item 5), keyed by the sender's
-- message_key: the service's id (provider_id), the channel and address, the
-- template, the sender's account reference, the payload as first accepted,
-- when it arrived; the same key again answers the same id, never a second
-- message.
CREATE TABLE IF NOT EXISTS messaging.messages (
    message_key uuid        PRIMARY KEY,
    provider_id uuid        NOT NULL UNIQUE,
    channel     text        NOT NULL,
    address     text        NOT NULL,
    template    text        NOT NULL,
    account_id  integer,
    payload     jsonb       NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    accepted    integer     NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS messages_received_idx ON messaging.messages (received_at);
CREATE INDEX IF NOT EXISTS messages_account_idx ON messaging.messages (account_id, template);
ALTER TABLE messaging.messages OWNER TO messaging;

-- Every call to POST /messages: its number, its key, the status answered
-- (202, 503, 422), when (MS1's and the retries' evidence).
CREATE TABLE IF NOT EXISTS messaging.message_calls (
    call        bigint      PRIMARY KEY,
    message_key uuid,
    status      integer     NOT NULL,
    at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS message_calls_key_idx ON messaging.message_calls (message_key);
ALTER TABLE messaging.message_calls OWNER TO messaging;

DO $$ BEGIN IF to_regrole('owners') IS NOT NULL THEN
GRANT USAGE ON SCHEMA messaging TO owners;
GRANT SELECT ON messaging.messages TO owners;
END IF; END $$;
