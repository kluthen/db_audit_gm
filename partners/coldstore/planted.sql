-- planted.sql of cold storage, the vault (v0.5 master spec 10.4, 11.2;
-- cold-storage.md 3, "Before T0"; capture W2 item 6, W2-f): the wal and
-- basebackup manifests of the weeks before T0, so the page shows the
-- archive's history and not only the aging. The data types' manifests are
-- their purpose's history (purpose 14, chunk 21), not this file's.
--
-- The GM copies it into partners-db's data file after coldstore/data.sql
-- and fills the one list below with the scenario's archiving nodes, as
-- master spec 11.2 places them (the clinic: records and lab archive their
-- WAL and send a nightly base backup; machines sends the base backup only).
-- Per node:
--   node     its name (each manifest's source);
--   wal      true when its seed archives its WAL (archive_mode on);
--   backup   true when its crontab sends a nightly base backup;
--   at       the base backup's crontab time, UTC (HH:MM);
--   segs     the WAL segments it archives an ordinary day (archive_timeout
--            1h: at least 24; more on a busy instance);
--   mb       its base backup's size, in megabytes.
-- Planted: the 35 days before T0's day (the page's five weeks), one manifest
-- per segment and per backup, received a few seconds after it was made.
--
-- Segment names: timeline 1, 16 MB segments (256 to a log), each node from
-- log 0x40 + 16 x its list position, so a planted name never meets another
-- node's nor a live one, which starts at the fresh cluster's first segment
-- (capture W2-f, the known limit: the live names start lower than the
-- planted).
-- T0: the load's reference moment, load_epoch, when load-data passes it
-- (W2 item 3), else the moment this file runs, just before T0.
\if :{?load_epoch}
SELECT :'load_epoch'::timestamptz AS cs_t0 \gset
\else
SELECT now() AS cs_t0 \gset
\endif

WITH nodes (pos, node, wal, backup, at, segs, mb) AS (
    VALUES
        -- The GM's list (one row per archiving node; pos 0, 1, 2, ...):
        (0, 'records', true, true, '03:30', 30, 96)
),
days AS (
    SELECT d::date AS day, row_number() OVER (ORDER BY d) - 1 AS n
    FROM generate_series((:'cs_t0'::timestamptz AT TIME ZONE 'UTC')::date - 35,
                         (:'cs_t0'::timestamptz AT TIME ZONE 'UTC')::date - 1,
                         interval '1 day') AS d
),
segments AS (                                   -- each node's segments a day, about segs
    SELECT nd.pos, nd.node, dy.day,
           -- a day's count varies a little around segs, the same for every rerun
           nd.segs + (hashtext(nd.node || dy.day::text) & 7) - 3 AS k
    FROM nodes nd CROSS JOIN days dy
    WHERE nd.wal
),
counted AS (                                    -- the node's segments before that day
    SELECT s.*, sum(s.k) OVER (PARTITION BY s.pos ORDER BY s.day) - s.k AS base
    FROM segments s
),
numbered AS (
    SELECT c.pos, c.node, c.day, g AS i, c.k, c.base + g AS seq
    FROM counted c CROSS JOIN LATERAL generate_series(0, c.k - 1) AS g
)
INSERT INTO coldstore.manifests (shipment_id, type, source, name, rows_declared, rows_received,
                                 size, date_from, date_to, received_at)
SELECT name, 'wal', node, name, 1, 1, 16777216, day, day,
       day + (i + 0.5) * (interval '24 hours' / k) + interval '3 seconds'
FROM (SELECT *, upper('00000001' || lpad(to_hex(64 + 16 * pos + (seq / 256)::int), 8, '0')
                      || lpad(to_hex((seq % 256)::int), 8, '0')) AS name
      FROM numbered) AS w
UNION ALL
SELECT node || '-' || to_char(dy.day, 'YYYYMMDD') || 'T' || replace(at, ':', '') || 'Z', 'basebackup',
       node, node || '-' || to_char(dy.day, 'YYYYMMDD') || 'T' || replace(at, ':', '') || 'Z', 1, 1,
       (mb * 1048576 + (hashtext(node || dy.day::text) & 1048575) * (dy.n + 1))::bigint,
       dy.day, dy.day, dy.day + at::time + interval '40 seconds'
FROM nodes nd CROSS JOIN days dy
WHERE nd.backup;
