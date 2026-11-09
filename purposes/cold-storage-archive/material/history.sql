-- cold-storage-archive's history (v0.5 master spec 12.1, 12.2 purpose 14;
-- cold-storage.md 3, "Before T0"; vet-machinery-domain.md,
-- "cold-storage-archive"; spec D366, D381, D401; capture W4 items 0 and 6 of
-- specs/versions/v0.5/wave-log.md): the manifests of the days the vault
-- already holds at T0, so its page shows the weeks before the hand-over and
-- not only the aging. No periodic job extends it (no feeder, chunk 29's (c)).
--
-- Named by purpose.yaml's history:. load-data runs it after the domains'
-- loads and the derivations, as postgres, unseen, in the target database
-- (the partners' database, partners, where cold storage's data.sql has made
-- coldstore.manifests), its sources read through postgres_fdw as gm_check:
-- the machinery's vitals as gm_src_source, biomed as gm_src_source_biomed.
--
-- Planted: for each type, one manifest per day before the kept window, the
-- customer's today at load_epoch less window_days (both read from the
-- source's settings: before yesterday by default), from the history's first
-- day: `vitals`, from the first session's day, its rows the 10-second ticks
-- within the sessions (the monitors' rows, W3 item 4); `machine-readings`,
-- the days of mach_readings_daily, its rows their sum (the aggregate kept on
-- site, the raw rows in the vault). Rows declared and received equal, the
-- shipment id <type>-<YYYYMMDD>, received at 00:40 the night after the
-- window, a few seconds in. Each manifest's source is the node the
-- partitions live on, read from the foreign server's host option, so no node
-- name is written here (D381).
\if :{?load_epoch}
SELECT :'load_epoch'::timestamptz AS ca_t0 \gset
\else
SELECT now() AS ca_t0 \gset
\endif

WITH src AS (
    SELECT srvname, (SELECT option_value FROM pg_options_to_table(srvoptions)
                      WHERE option_name = 'host') AS node
      FROM pg_foreign_server WHERE srvname IN ('gm_src_source', 'gm_src_source_biomed')
),
vs AS (                                         -- the vitals' zone and window
    SELECT utc_offset_hours AS o, window_days AS w,
           ((:'ca_t0'::timestamptz AT TIME ZONE 'UTC') + make_interval(hours => utc_offset_hours))::date AS today
      FROM gm_src_source.mach_vitals_settings
),
sessions AS (
    SELECT started_at, coalesce(ended_at, :'ca_t0'::timestamptz) AS ended_at
      FROM gm_src_source.mach_sessions
     WHERE started_at < :'ca_t0'::timestamptz
),
vdays AS (
    SELECT g::date AS day,
           (g::date::timestamp - make_interval(hours => vs.o)) AT TIME ZONE 'UTC' AS lo,
           ((g::date + 1)::timestamp - make_interval(hours => vs.o)) AT TIME ZONE 'UTC' AS hi,
           vs.o, vs.w
      FROM vs, generate_series((SELECT min(((started_at AT TIME ZONE 'UTC') + make_interval(hours => vs.o))::date)
                                  FROM sessions),
                               vs.today - vs.w - 1, interval '1 day') AS g
),
vitals AS (
    SELECT d.day, d.o, d.w,
           coalesce(sum(greatest(0, ceil(extract(epoch FROM least(s.ended_at, d.hi)) / 10)
                                    - ceil(extract(epoch FROM greatest(s.started_at, d.lo)) / 10))), 0)::bigint AS rows
      FROM vdays d LEFT JOIN sessions s ON s.started_at < d.hi AND s.ended_at > d.lo
     GROUP BY d.day, d.o, d.w
),
bs AS (                                         -- the readings' zone and window
    SELECT utc_offset_hours AS o, window_days AS w,
           ((:'ca_t0'::timestamptz AT TIME ZONE 'UTC') + make_interval(hours => utc_offset_hours))::date AS today
      FROM gm_src_source_biomed.mach_settings
),
readings AS (
    SELECT r.day, bs.o, bs.w, sum(r.rows)::bigint AS rows
      FROM gm_src_source_biomed.mach_readings_daily r, bs
     WHERE r.day < bs.today - bs.w
     GROUP BY r.day, bs.o, bs.w
),
planted AS (
    SELECT 'vitals' AS type, (SELECT node FROM src WHERE srvname = 'gm_src_source') AS source,
           day, o, w, rows, 170 AS width FROM vitals
    UNION ALL
    SELECT 'machine-readings', (SELECT node FROM src WHERE srvname = 'gm_src_source_biomed'),
           day, o, w, rows, 130 FROM readings
)
INSERT INTO coldstore.manifests (shipment_id, type, source, name, rows_declared, rows_received, size,
                                 date_from, date_to, received_at)
SELECT p.type || '-' || to_char(p.day, 'YYYYMMDD'), p.type, p.source, p.type || '-' || to_char(p.day, 'YYYYMMDD'),
       p.rows, p.rows, p.rows * p.width, p.day, p.day,
       ((p.day + p.w + 1)::timestamp + interval '40 minutes' - make_interval(hours => p.o)) AT TIME ZONE 'UTC'
         + make_interval(secs => 3 + (hashtext(p.type || p.day::text) & 31))
  FROM planted p
 WHERE p.day < (:'ca_t0'::timestamptz AT TIME ZONE 'UTC')::date
ON CONFLICT (source, shipment_id) DO NOTHING;
