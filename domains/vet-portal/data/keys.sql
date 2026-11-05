-- vet-portal's key functions (v0.5 master spec 9.7; vet-portal-domain.md,
-- "Deterministic key ranges", "The history before T0"; capture W3 items 0
-- and 5; spec D406). docs/gm.md, "Part keys", documents each; this file is the
-- formula.
--
-- gmctl load-data streams this file after vet-core's data/keys.sql, ahead of
-- this part's load.sql, its partners' data.sql (producers/partners/owners)
-- and its derive.sql, in their session (W3 item 0, chunk 29's (a)): every
-- function lives in pg_temp and vanishes with the session. A part calls only
-- the core's eighteen pg_temp.core_* functions (vet-core docs/gm.md, "Core
-- keys"), never its pg_temp.vc_*.
--
-- Signatures as the core's (D379): IMMUTABLE, the run's load_epoch and
-- customer_utc_offset passed by the caller, never now(); times UTC; every draw
-- a hash of an id (portal_u), never random().
--
-- The passwords' and links' key (W3 item 5, D406): the SHA-256 of
-- 'vet-portal ' and load_epoch as load-data passes it (UTC, to the minute,
-- 2026-11-04T09:30Z); a password is the HMAC-SHA256 of the account's id under
-- it, a planted one-time link's token the HMAC of '<template>:<account id>',
-- a planted session's of 'session-<rank>:<account id>'. Computed here with the
-- built-in sha256() only, so the partners' database needs no pgcrypto; equal
-- to pgcrypto's encode(hmac(msg, key, 'sha256'), 'hex').

-- --- Shared formulas ---------------------------------------------------------------

-- A uniform draw in [0, 1) from x and a salt (salts 1-99, offset from the
-- core's and the lab's).
CREATE FUNCTION pg_temp.portal_u(x bigint, salt integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (hashint8extended(x, 7300 + salt) & 2147483647)::float8 / 2147483648 $$;

-- A UTC instant as the customer's local time, and back.
CREATE FUNCTION pg_temp.portal_local(t timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t AT TIME ZONE 'UTC') + utc_offset * interval '1 hour' $$;
CREATE FUNCTION pg_temp.portal_utc(t timestamp, utc_offset integer) RETURNS timestamptz
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT (t - utc_offset * interval '1 hour') AT TIME ZONE 'UTC' $$;

-- The history's start, as the core's: local Monday 00:00, 52 weeks before
-- load_epoch's week (53 weeks, cut at load_epoch).
CREATE FUNCTION pg_temp.portal_start(load_epoch timestamptz, utc_offset integer) RETURNS timestamp
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT date_trunc('week', pg_temp.portal_local(load_epoch, utc_offset)) - interval '364 days' $$;

-- The owners' day (vet-portal-domain.md, "The business hours"): the weight
-- of local hour h, 0.1 at night to 1.6 in the evening (16.2 a day).
CREATE FUNCTION pg_temp.portal_owners_day(h integer) RETURNS float8
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN h < 7 OR h >= 23 THEN 0.1 WHEN h < 9 THEN 0.5 WHEN h < 18 THEN 0.8
            WHEN h < 22 THEN 1.6 ELSE 0.8 END
$$;

-- --- The key, the passwords, the tokens (D406) ---------------------------------------

CREATE FUNCTION pg_temp.portal_key(load_epoch timestamptz) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT encode(sha256(convert_to('vet-portal '
                                || to_char(load_epoch AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI"Z"'),
                                'UTF8')), 'hex')
$$;

-- HMAC-SHA256 (RFC 2104) of msg under key, in hex: the key's 64 characters
-- are one SHA-256 block, so it is neither padded nor hashed.
CREATE FUNCTION pg_temp.portal_hmac(msg text, key text) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT encode(sha256(o || sha256(i || convert_to(msg, 'UTF8'))), 'hex')
  FROM (SELECT string_agg(set_byte('\x00'::bytea, 0, get_byte(k, g) # 54), ''::bytea ORDER BY g) AS i,
               string_agg(set_byte('\x00'::bytea, 0, get_byte(k, g) # 92), ''::bytea ORDER BY g) AS o
          FROM (SELECT convert_to(key, 'UTF8') AS k) AS a, generate_series(0, 63) AS g) AS b
$$;

-- Account n's password (the owners' route logs in with it), a planted
-- one-time link's token ('invitation', 'password-reset'), a planted
-- session's ('session-<rank>', the rank among the account's planted
-- sessions, oldest first).
CREATE FUNCTION pg_temp.portal_password(n integer, load_epoch timestamptz) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT pg_temp.portal_hmac(n::text, pg_temp.portal_key(load_epoch)) $$;
CREATE FUNCTION pg_temp.portal_token(template text, n integer, load_epoch timestamptz) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT pg_temp.portal_hmac(template || ':' || n, pg_temp.portal_key(load_epoch)) $$;

-- A deterministic bcrypt salt at cost 6 (rule 4, a game value) for account
-- n: 22 characters of bcrypt's alphabet, so a load is reproducible.
CREATE FUNCTION pg_temp.portal_bcrypt_salt(n integer, load_epoch timestamptz) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT '$2a$06$' || translate(left(encode(sha256(convert_to('salt:' || n || ':'
                                                            || pg_temp.portal_key(load_epoch), 'UTF8')),
                                          'base64'), 22), '+', '.')
$$;

-- A message's key (W3 item 5): md5('<template>:<account id>:<reference>')
-- as a UUID, the reference '1' for an invitation and a closure, the reset's
-- rank for a reset, the document's id for a notice, '<animal>:<due on>' for a
-- reminder; a sent message's provider_id likewise, of its key.
CREATE FUNCTION pg_temp.portal_message_key(template text, account integer, reference text) RETURNS uuid
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT md5(template || ':' || account || ':' || reference)::uuid $$;
CREATE FUNCTION pg_temp.portal_provider_id(message_key uuid) RETURNS uuid
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT md5('messaging:' || message_key)::uuid $$;

-- A vaccination's due day in a year, for domestic animals and horses: day
-- 1 + (animal_id x 211) mod 365 (366 in a leap year never due).
CREATE FUNCTION pg_temp.portal_due_on(animal_id integer, y integer) RETURNS date
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS
$$ SELECT make_date(y, 1, 1) + (animal_id::bigint * 211 % 365)::integer $$;

-- --- Accounts (vet-portal-domain.md, "Deterministic key ranges") -------------------------

-- The activation's delay after the invitation: 0 to 3 days, none for three
-- invitations in ten (owners.activate's, by the same hash: hashint8extended(n,
-- 7302) and (n, 7303)).
CREATE FUNCTION pg_temp.portal_activation_delay(n integer) RETURNS interval
  LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
SELECT CASE WHEN pg_temp.portal_u(n, 2) < 0.3 THEN NULL
            ELSE pg_temp.portal_u(n, 3) * interval '3 days' END
$$;

-- Account n (owner n, 2-10 000) as the load leaves it: invited five minutes
-- after the owner's registration; active once its activation delay has
-- passed; closed for three in a hundred invited over 14 days ago (after its
-- activation, if any); an invited account over 14 days old renewed by a reset
-- in the last 14 days for one in about thirty (its open link a
-- password-reset's), a recent one's open link its invitation; the channel
-- e-mail, SMS for 15 % of people, none for 5 %; the reminders' consent granted
-- at activation by 86 % (about 5 100 in force at T0 with the later changes);
-- one active account in 500 with a failed login or three since its last
-- success.
CREATE FUNCTION pg_temp.portal_account(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (kind text, display_name text, email text, phone text, status text,
                 invited_at timestamptz, activated_at timestamptz, closed_at timestamptz,
                 open_template text, open_sent_at timestamptz, notify_by text,
                 consent_at timestamptz, failed_logins integer)
  LANGUAGE sql IMMUTABLE AS $$
WITH o AS (SELECT * FROM pg_temp.core_owner(n, load_epoch, utc_offset) WHERE n BETWEEN 2 AND 10000),
a AS (SELECT o.*, o.registered_at + interval '5 minutes' AS inv,
             pg_temp.portal_activation_delay(n) AS d FROM o),
b AS (SELECT a.*, CASE WHEN a.inv + a.d < load_epoch THEN a.inv + a.d END AS act,
             pg_temp.portal_u(n, 1) < 0.03 AND a.inv < load_epoch - interval '14 days' AS closes
        FROM a),
c AS (SELECT b.*,
             CASE WHEN b.closes THEN coalesce(b.act, b.inv)
                                     + (load_epoch - coalesce(b.act, b.inv)) * (0.1 + 0.85 * pg_temp.portal_u(n, 4))
             END AS closed
        FROM b)
SELECT c.kind, c.name, c.email, c.phone,
       CASE WHEN c.closed IS NOT NULL THEN 'closed' WHEN c.act IS NOT NULL THEN 'active' ELSE 'invited' END,
       c.inv, c.act, c.closed,
       CASE WHEN c.closed IS NOT NULL OR c.act IS NOT NULL THEN NULL
            WHEN c.inv >= load_epoch - interval '14 days' THEN 'invitation'
            WHEN pg_temp.portal_u(n, 5) < 0.035 THEN 'password-reset' END,
       CASE WHEN c.closed IS NOT NULL OR c.act IS NOT NULL THEN NULL
            WHEN c.inv >= load_epoch - interval '14 days' THEN c.inv
            WHEN pg_temp.portal_u(n, 5) < 0.035
            THEN load_epoch - (0.02 + 0.97 * pg_temp.portal_u(n, 6)) * interval '14 days' END,
       CASE WHEN c.kind <> 'person' OR pg_temp.portal_u(n, 7) < 0.80 THEN 'email'
            WHEN pg_temp.portal_u(n, 7) < 0.95 THEN 'sms' ELSE 'none' END,
       CASE WHEN c.act IS NOT NULL AND pg_temp.portal_u(n, 8) < 0.86 THEN c.act END,
       CASE WHEN c.act IS NOT NULL AND c.closed IS NULL AND pg_temp.portal_u(n, 9) < 0.002
            THEN 1 + floor(3 * pg_temp.portal_u(n, 10))::integer ELSE 0 END
  FROM c
$$;

-- Account n's password resets over the year, oldest first, each used within
-- the hour: one for an active account in five, a second for one in 33, at a
-- time between its activation (or the year's start) and its closure (or T0);
-- the renewal of an invited account's open link (portal_account's
-- open_template 'password-reset'), unused. rank 1, 2 in time order.
CREATE FUNCTION pg_temp.portal_resets(n integer, load_epoch timestamptz, utc_offset integer)
  RETURNS TABLE (rank integer, at timestamptz, used boolean)
  LANGUAGE sql IMMUTABLE AS $$
WITH a AS (SELECT p.*, greatest(p.activated_at,
                                pg_temp.portal_utc(pg_temp.portal_start(load_epoch, utc_offset), utc_offset)) AS lo,
                  coalesce(p.closed_at, load_epoch) - interval '1 hour' AS hi
             FROM pg_temp.portal_account(n, load_epoch, utc_offset) AS p),
r AS (SELECT a.lo + (a.hi - a.lo) * pg_temp.portal_u(n, 20 + k) AS at
        FROM a, generate_series(1, 2) AS k
       WHERE a.activated_at IS NOT NULL AND a.hi > a.lo
         AND pg_temp.portal_u(n, 11) < CASE k WHEN 1 THEN 0.20 ELSE 0.03 END
      UNION ALL
      SELECT a.open_sent_at FROM a WHERE a.open_template = 'password-reset')
SELECT (row_number() OVER (ORDER BY r.at))::integer, r.at, NOT EXISTS (SELECT 1 FROM a WHERE a.open_sent_at = r.at)
  FROM r
$$;
