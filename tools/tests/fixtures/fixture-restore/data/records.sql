-- Data of records, the restore fixture's primary (tools/tests, v0.5 chunk
-- 28): a small clinic database whose writes fill the WAL segments the short
-- test switches and archives, and whose rows it reads on the standby.
CREATE DATABASE clinic;

\connect clinic
CREATE TABLE visits (
    id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    animal_id integer NOT NULL,
    seen_at   timestamptz NOT NULL
);
INSERT INTO visits (animal_id, seen_at)
SELECT 1 + g % 400, now() - (g || ' minutes')::interval FROM generate_series(1, 2000) AS g;
