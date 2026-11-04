-- partner-data.sql — template for
-- domains/<domain-id>/producers/partners/<prefix>/data.sql, a partner's
-- tables and planted state
--
-- Version v0.5, expected to evolve as games are played.
-- Shape: v0.5 master spec 9.3, 10.2; captures W2 items 0, 1, 3 and 6 of
-- specs/versions/v0.5/wave-log.md. Optional: a partner whose routes read or
-- write a state of their own. <prefix> is the folder's name,
-- [a-z][a-z0-9]{0,15}: the partner's role, schema, keys <prefix>.<...>,
-- endpoints <prefix>_<...> and connections <prefix>-<...>.
--
-- load-data runs this file as postgres, connected to the partners' database
-- (partners, on the postgres node the scenario's third_parties: entries
-- list), after its domain's own load, the partner folders in name order,
-- the core's data/keys.sql streamed ahead in the same session (its
-- pg_temp.core_* functions, so the partner's ids are the core's). It
-- receives -v customer_timezone, customer_utc_offset and load_epoch; a time
-- is :'load_epoch'::timestamptz, never now(). It never creates or
-- \connects to a database; it names its database :"DBNAME".
-- Replace every <placeholder>. A filled file keeps none.

-- The partner's role: LOGIN, no password (render's secret, set by
-- load-data's password step); its passwords mounted on the partners' nodes
-- only, so no customer node names it.
CREATE ROLE <xlab> LOGIN;
GRANT CONNECT ON DATABASE :"DBNAME" TO <xlab>;
CREATE SCHEMA <xlab> AUTHORIZATION <xlab>;

-- The misbehaviour key's table (W2 item 6), planted with the baseline rows.
CREATE TABLE <xlab>.state (hostname text, name text, value text NOT NULL,
                           set_at timestamptz NOT NULL DEFAULT now(),
                           PRIMARY KEY (hostname, name));
INSERT INTO <xlab>.state VALUES ('<northfield-lab>', '<mode>', '<normal>', :'load_epoch');

-- The partner's own tables and its state at T0 (the send-outs open, 9.3),
-- their ids from the core's key functions.
CREATE TABLE <xlab>.<requests> (<stay_id> integer PRIMARY KEY, sent_at timestamptz NOT NULL);
INSERT INTO <xlab>.<requests>
SELECT pg_temp.core_<stay>(n), :'load_epoch'::timestamptz - interval '<2 hours>'
  FROM generate_series(1, <4>) AS n;
ALTER TABLE <xlab>.state OWNER TO <xlab>;
ALTER TABLE <xlab>.<requests> OWNER TO <xlab>;
