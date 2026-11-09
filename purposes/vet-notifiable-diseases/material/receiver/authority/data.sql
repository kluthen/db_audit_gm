-- data.sql of the authority's stub, purpose 5's part (v0.5 master spec 10.2,
-- 12.2 purpose 5; clinic-purposes.md 9; capture W4 items 0 and 4; W2-f;
-- partners/README.md): its role, its schema, its state and the notifications
-- it took, in the partners' database. The GM copies it after
-- partners/shared/partners-db/data.sql in partners-db's data file (load-data
-- runs that file connected to partners); with purpose 8, both purposes'
-- files are copied, their shared block below the same text, guarded.
--
-- The shared block (purposes 5 and 8, byte-identical; W4 item 0): the role
-- (LOGIN, no password here: render's secret role_authority_password, set by
-- load-data), the schema, the state and the calls' counter both routes read.
-- authority: begin
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authority') THEN
CREATE ROLE authority LOGIN;
END IF; END $$;
CREATE SCHEMA IF NOT EXISTS authority AUTHORIZATION authority;
CREATE TABLE IF NOT EXISTS authority.state (
    hostname text NOT NULL,
    name     text NOT NULL,
    value    text NOT NULL,
    set_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (hostname, name));
ALTER TABLE authority.state OWNER TO authority;
INSERT INTO authority.state (hostname, name, value) VALUES ('authority', 'delay_ms', '0'),
    ('authority', 'fail_one_in', '50')
ON CONFLICT (hostname, name) DO NOTHING;
-- Every call either route takes is numbered; a number that is a multiple of
-- fail_one_in answers 503 (the standing one in fifty, D214's precedent).
CREATE SEQUENCE IF NOT EXISTS authority.calls;
ALTER SEQUENCE authority.calls OWNER TO authority;
-- authority: end

-- One row a notification the authority accepted, keyed by the notifier's
-- notification_key (lab-<id> or vet-<diagnosis id>): its reference, the
-- body as first accepted, the accepted calls counted (a repeat answers the
-- same reference, never a second notification).
CREATE TABLE authority.notifications (
    notification_key text        PRIMARY KEY,
    reference        text        NOT NULL UNIQUE,
    body             jsonb       NOT NULL,
    first_at         timestamptz NOT NULL DEFAULT now(),
    last_at          timestamptz NOT NULL DEFAULT now(),
    accepted         integer     NOT NULL DEFAULT 1
);
ALTER TABLE authority.notifications OWNER TO authority;

-- Every call to POST /notifications: its number, its key, the status
-- answered (201, 503, 422), when.
CREATE TABLE authority.notification_calls (
    call             bigint      PRIMARY KEY,
    notification_key text,
    status           integer     NOT NULL,
    at               timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notification_calls_key_idx ON authority.notification_calls (notification_key);
ALTER TABLE authority.notification_calls OWNER TO authority;
