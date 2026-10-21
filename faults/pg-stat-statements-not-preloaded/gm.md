# pg-stat-statements-not-preloaded — GM notes

**What.** The extension `pg_stat_statements` exists in database
`postgres` (postgres 0.2.0 creates it at initdb), but the scenario's
`postgresql.conf` leaves it out of `shared_preload_libraries`. The server
collects no query statistics: the view errors, the exporter's
`stat_statements` collector fails, the PostgreSQL dashboard's statement
panels stay empty. A tool starved of information.

**Why it matters.** Without query statistics there is no way to tell
which queries cost the most: performance work becomes guessing from
logs. The empty panels look like a broken dashboard, while the exporter
is connected and every other PostgreSQL metric flows.

**Why it happens.** The preload line dropped when a configuration was
regenerated or merged; commented out "temporarily" to rule it out during
an incident; an extension created by a script that forgot the server-side
half.

**What a good answer says.** Connects the empty panels to the cause:
`SELECT * FROM pg_stat_statements` fails with "must be loaded via
shared_preload_libraries", `SHOW shared_preload_libraries` does not name
it, `pg_scrape_collector_success{collector="stat_statements"}` is 0 while
`pg_up` is 1. Proposes adding the library and restarting, and says that
a reload is not enough and that the restart drops every connection (to
be planned).

**Fix paths.** Both count; each needs a restart:
- edit `/etc/postgresql/postgresql.conf` (`shared_preload_libraries =
  'pg_stat_statements'`), then `sudo gm-restart-db`;
- `ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements'` as
  `dba`, then `sudo gm-restart-db`.

With the preload, the exporter's own queries fill the statement panels
within about 60 seconds, no load needed.

**Sealed check.** On the database node as root, through `runuser -u
postgres -- psql -d postgres`: *fixed* when `pg_stat_statements` is in
the `shared_preload_libraries` in effect and `SELECT count(*) FROM
pg_stat_statements` succeeds. A file edited (or `ALTER SYSTEM` run) but
not restarted reads *present*. A preloaded library whose extension was
dropped also reads *present*, with its own line.

**Placement (no masking).**
- `prometheus-scrape-target-missing` never removes the exporter's target:
  that would hide this fault's dashboard and Prometheus evidence.
- The scenario's `exporter.conf` keeps `--collector.stat_statements`, so
  the collector's failure shows.
- Not with a fault on the `monitoring` role (no `pg_monitor`): their
  symptoms overlap.
- `pg-join-index-missing` in the same scenario is found by `EXPLAIN` and
  the index catalogue, never by `pg_stat_statements`, which this fault
  hides.
- `pg-memory-over-envelope` shares `postgresql.conf`; both can be planted
  in the same file.

**Feedback points.** Extensions with a server-side part need the preload
and a restart; reading an empty panel as a missing data source, not a
quiet database; planning a restart.
