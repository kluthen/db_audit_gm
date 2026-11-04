-- vet-portal's load (v0.5 master spec 9.7; vet-portal-domain.md,
-- "Deterministic key ranges", "The history before T0", "Loading"; capture W3
-- items 0 and 5; spec D406): last night's backup of the owners' portal, its
-- accounts, consent events and sessions. Runs after schema.sql, connected to
-- the portal's database, as postgres, with vet-core's data/keys.sql and this
-- part's data/keys.sql streamed ahead of it in the same session (W3 item 0):
-- the accounts are pg_temp.portal_account's, the core's owners and ownerships
-- the core's functions (D249); never the core's or the lab's database. The
-- copies, the documents, the views and the whole outbox are data/derive.sql's,
-- run after the sources' loads (D322, D404). docs/gm.md, "Part keys" and "The
-- data", documents both.
--
-- load-data's three psql variables (capture W1 item 0, W2 item 3):
-- customer_timezone, customer_utc_offset and load_epoch (T0, never now()).
\if :{?customer_timezone}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_timezone is not set '
                            '(gmctl load-data passes -v customer_timezone=<zone>)'; END $$;
\endif
\if :{?customer_utc_offset}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable customer_utc_offset is not set '
                            '(gmctl load-data passes -v customer_utc_offset=<hours>)'; END $$;
\endif
\if :{?load_epoch}
\else
DO $$ BEGIN RAISE EXCEPTION 'load.sql: psql variable load_epoch is not set '
                            '(gmctl load-data passes -v load_epoch=<UTC, ISO 8601>)'; END $$;
\endif
DO $$ BEGIN
    IF to_regprocedure('pg_temp.core_owner(integer, timestamp with time zone, integer)') IS NULL
       OR to_regprocedure('pg_temp.portal_account(integer, timestamp with time zone, integer)') IS NULL THEN
        RAISE EXCEPTION 'load.sql: the key functions are missing (gmctl load-data streams vet-core''s '
                        'data/keys.sql, then vet-portal''s, ahead of this file, in the same session)';
    END IF;
END $$;

CREATE TEMP TABLE p_env AS
SELECT :'load_epoch'::timestamptz AS e, :customer_utc_offset::integer AS o,
       pg_temp.portal_utc(pg_temp.portal_start(:'load_epoch'::timestamptz, :customer_utc_offset),
                          :customer_utc_offset) AS su;

-- --- Settings -----------------------------------------------------------------------------

INSERT INTO portal_settings (timezone, utc_offset_hours) VALUES (:'customer_timezone', :customer_utc_offset);

-- --- Accounts: owner o's is o (2-10 000), the sequence at 20 000 (T261) -------------------

CREATE TEMP TABLE p_acc AS
SELECT n, a.* FROM p_env, generate_series(2, 10000) AS n,
       LATERAL pg_temp.portal_account(n, p_env.e, p_env.o) AS a;

INSERT INTO portal_accounts (id, owner_id, kind, display_name, email, phone, status, invited_at,
                             invite_hash, invite_expires_at, activated_at, password_hash, failed_logins,
                             notify_by, closed_at, synced_at)
SELECT a.n, a.n, a.kind,
       CASE WHEN a.status <> 'closed' THEN a.display_name END,
       CASE WHEN a.status <> 'closed' THEN a.email END,
       CASE WHEN a.status <> 'closed' THEN a.phone END,
       a.status, a.invited_at,
       CASE WHEN a.open_template IS NOT NULL
            THEN encode(sha256(convert_to(pg_temp.portal_token(a.open_template, a.n, p_env.e), 'UTF8')), 'hex')
       END,
       a.open_sent_at + interval '14 days',
       a.activated_at,
       CASE WHEN a.status = 'active'
            THEN crypt(pg_temp.portal_password(a.n, p_env.e), pg_temp.portal_bcrypt_salt(a.n, p_env.e)) END,
       a.failed_logins,
       CASE WHEN a.status = 'closed' THEN 'none' ELSE a.notify_by END,
       a.closed_at, p_env.e
  FROM p_acc AS a, p_env
 ORDER BY a.n;

-- --- Consent events, in time order ---------------------------------------------------------

-- The reminders: the activation's grant (80 %), then one change for 15 % of
-- the accounts ever active (a withdrawal by a reminder's link, the portal or
-- the desk; a grant by the portal or the desk).
CREATE TEMP TABLE p_ev (owner_id integer, purpose text, animal_id integer, keeper_id integer,
                        granted boolean, at timestamptz, source text);
INSERT INTO p_ev
SELECT n, 'reminders', NULL, NULL, true, consent_at, 'activation' FROM p_acc WHERE consent_at IS NOT NULL;
INSERT INTO p_ev
SELECT a.n, 'reminders', NULL, NULL, a.consent_at IS NULL, c.at,
       CASE WHEN a.consent_at IS NULL THEN CASE WHEN pg_temp.portal_u(a.n, 32) < 0.6 THEN 'portal' ELSE 'desk' END
            WHEN pg_temp.portal_u(a.n, 32) < 0.4 THEN 'message-link'
            WHEN pg_temp.portal_u(a.n, 32) < 0.8 THEN 'portal' ELSE 'desk' END
  FROM p_acc AS a, p_env,
       LATERAL (SELECT a.activated_at + (coalesce(a.closed_at, p_env.e) - a.activated_at)
                       * (0.05 + 0.9 * pg_temp.portal_u(a.n, 31)) AS at) AS c
 WHERE a.activated_at IS NOT NULL AND pg_temp.portal_u(a.n, 30) < 0.15;

-- keeper-access: of each horse kept by a stable now, its current owner, while
-- active, granted the stable access for two in three, a day or more after
-- both began; one grant in twelve withdrawn since (about 250 in force).
CREATE TEMP TABLE p_keep AS
SELECT h AS animal_id, ow.owner_id, ow.from_at AS owner_from, kp.owner_id AS keeper_id, kp.from_at AS keeper_from
  FROM p_env, generate_series(14609, 16000) AS h,
       LATERAL (SELECT * FROM pg_temp.core_ownership(h, p_env.e, p_env.o) AS x
                 WHERE x.role = 'owner' AND x.until_at IS NULL) AS ow,
       LATERAL (SELECT * FROM pg_temp.core_ownership(h, p_env.e, p_env.o) AS x
                 WHERE x.role = 'keeper' AND x.until_at IS NULL) AS kp;
CREATE TEMP TABLE p_grant AS
SELECT k.*, g.at AS granted_at,
       CASE WHEN pg_temp.portal_u(k.animal_id, 35) < 0.08
            THEN g.at + (p_env.e - g.at) * (0.1 + 0.85 * pg_temp.portal_u(k.animal_id, 36)) END AS withdrawn_at
  FROM p_keep AS k JOIN p_acc AS a ON a.n = k.owner_id AND a.status = 'active', p_env,
       LATERAL (SELECT greatest(k.owner_from, k.keeper_from, a.activated_at) + interval '1 day' AS lo) AS l,
       LATERAL (SELECT l.lo + (p_env.e - l.lo) * pg_temp.portal_u(k.animal_id, 34) AS at) AS g
 WHERE pg_temp.portal_u(k.animal_id, 33) < 0.65 AND l.lo < p_env.e - interval '1 hour';
INSERT INTO p_ev
SELECT owner_id, 'keeper-access', animal_id, keeper_id, true, granted_at, 'portal' FROM p_grant;
INSERT INTO p_ev
SELECT owner_id, 'keeper-access', animal_id, keeper_id, false, withdrawn_at, 'portal'
  FROM p_grant WHERE withdrawn_at IS NOT NULL;

INSERT INTO portal_consent_events (id, owner_id, purpose, animal_id, keeper_id, granted, at, source)
SELECT row_number() OVER (ORDER BY at, owner_id, purpose, animal_id), owner_id, purpose, animal_id, keeper_id,
       granted, at, source
  FROM p_ev ORDER BY 1;

-- The flag beside the events: the latest reminders event, for an account not
-- closed.
UPDATE portal_accounts AS a SET reminders = l.granted
  FROM (SELECT DISTINCT ON (owner_id) owner_id, granted FROM portal_consent_events
         WHERE purpose = 'reminders' ORDER BY owner_id, at DESC, id DESC) AS l
 WHERE l.owner_id = a.owner_id AND a.status <> 'closed';

-- --- Sessions: the last 30 days' (about 4 500), their ids where the year left them -----------

-- Per local hour of the last 30 days, the visits at 9.26 an hour times the
-- owners' day's weight (150 a day), randomised by the hour's hash; each by an
-- active account activated before the window, 1 to 20 minutes long, half
-- logged out, the others ended idle half an hour later, but for the last 12
-- hours' (open, idle: the late evening's), which portal_session ends when
-- next tried.
CREATE TEMP TABLE p_active AS
SELECT row_number() OVER (ORDER BY n) - 1 AS i, n FROM p_acc, p_env
 WHERE status = 'active' AND activated_at < p_env.e - interval '30 days';
CREATE TEMP TABLE p_ses AS
WITH hours AS (
  SELECT h, pg_temp.portal_utc(h, p_env.o) AS hu,
         floor(9.26 * pg_temp.portal_owners_day(extract(hour FROM h)::integer)
               + pg_temp.portal_u(extract(epoch FROM h)::bigint, 40))::integer AS k
    FROM p_env, generate_series(date_trunc('hour', pg_temp.portal_local(p_env.e, p_env.o)) - interval '30 days',
                                date_trunc('hour', pg_temp.portal_local(p_env.e, p_env.o)), interval '1 hour') AS h),
s AS (
  SELECT hours.hu + interval '1 hour' * pg_temp.portal_u(extract(epoch FROM hours.h)::bigint * 16 + j, 41)
           AS created_at,
         extract(epoch FROM hours.h)::bigint * 16 + j AS x
    FROM hours, generate_series(1, hours.k) AS j)
SELECT s.created_at, act.n AS account_id,
       s.created_at + interval '1 minute' * (1 + 19 * pg_temp.portal_u(s.x, 43)) AS last_seen_at,
       pg_temp.portal_u(s.x, 44) < 0.5 AS logout
  FROM s, p_env,
       LATERAL (SELECT n FROM p_active
                 WHERE i = floor(pg_temp.portal_u(s.x, 42) * (SELECT count(*) FROM p_active))::bigint) AS act
 WHERE s.created_at < p_env.e - interval '1 minute';

INSERT INTO portal_sessions (id, account_id, token_hash, created_at, last_seen_at, expires_at, ended_at, ended_by)
SELECT 39300 + row_number() OVER (ORDER BY s.created_at, s.account_id), s.account_id,
       encode(sha256(convert_to(pg_temp.portal_token('session-' || row_number() OVER (PARTITION BY s.account_id
                                                                                       ORDER BY s.created_at),
                                                     s.account_id, p_env.e), 'UTF8')), 'hex'),
       s.created_at, least(s.last_seen_at, p_env.e), s.created_at + interval '12 hours',
       CASE WHEN s.logout THEN least(s.last_seen_at, p_env.e)
            WHEN s.created_at < p_env.e - interval '12 hours' THEN s.last_seen_at + interval '30 minutes' END,
       CASE WHEN s.logout THEN 'logout' WHEN s.created_at < p_env.e - interval '12 hours' THEN 'idle' END
  FROM p_ses AS s, p_env
 ORDER BY 1;

UPDATE portal_accounts AS a SET last_login_at = coalesce(s.last, a.activated_at)
  FROM (SELECT p.n, (SELECT max(created_at) FROM portal_sessions WHERE account_id = p.n) AS last
          FROM p_acc AS p WHERE p.activated_at IS NOT NULL) AS s
 WHERE s.n = a.id;

-- --- Sequences after their ranges ----------------------------------------------------------

SELECT setval('portal_accounts_id_seq', 20000);
SELECT setval(pg_get_serial_sequence(t, 'id'), greatest(1, (xpath('/row/m/text()',
              query_to_xml(format('SELECT max(id) AS m FROM %I', t), false, true, '')))[1]::text::integer))
  FROM unnest(ARRAY['portal_consent_events', 'portal_sessions']) AS t;

ANALYZE portal_accounts;
ANALYZE portal_consent_events;
ANALYZE portal_sessions;
