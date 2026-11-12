-- Restored-backup data of the lab fixture's lab node (tools/tests, v0.5
-- chunk 25): a small laboratory's samples, no domain. gmctl load-data
-- streams this file into
--   psql -X -q -v ON_ERROR_STOP=1 -d postgres
-- run as the postgres OS user; the file creates its own roles and databases.
CREATE ROLE lab NOLOGIN;
CREATE DATABASE lab OWNER lab;

\connect lab
SET ROLE lab;

CREATE TABLE samples (
    id          integer     PRIMARY KEY,
    received_at timestamptz NOT NULL,
    kind        text        NOT NULL
);

INSERT INTO samples (id, received_at, kind)
SELECT g, timestamptz '2026-01-01 08:00+00' + g * interval '17 minutes',
       (ARRAY['blood', 'urine', 'swab', 'faeces'])[1 + g % 4]
  FROM generate_series(1, 5000) AS g;

ANALYZE samples;
