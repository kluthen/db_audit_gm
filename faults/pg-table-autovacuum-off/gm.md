# pg-table-autovacuum-off — GM notes

**What.** The storage parameter `autovacuum_enabled = off` on one table.
The server-wide `autovacuum` setting is on and the validator is green, so
only a look at the tables' options shows it.

**Why it matters.** Autovacuum removes dead row versions left by updates
and deletes, keeps the visibility map up to date (index-only scans), and
refreshes statistics (autoanalyze). Without it on a busy table: the table
and its indexes bloat, scans slow down, plans drift as statistics go
stale, and only the forced anti-wraparound vacuum, at the worst moment,
protects it against transaction ID wraparound.

**Why it happens.** Turned off during a bulk load or because "autovacuum
slowed the night batch", and never turned back on.

**What a good answer says.** Finds the option (`\d+`, or `reloptions`),
explains the consequences, and resets it (`ALTER TABLE <table> RESET
(autovacuum_enabled)`), with a manual `VACUUM (ANALYZE)` to catch up. A
better answer suggests per-table thresholds (`autovacuum_vacuum_scale_factor`,
`autovacuum_vacuum_cost_limit`) rather than off, if the table really is
too busy for the defaults.

**Fix path.** SQL as `dba`. The server setting `autovacuum` does not
override a table's option, so `ALTER SYSTEM` is not a path here.

**Sealed check.** Reads the table's `reloptions`; any false value of
`autovacuum_enabled` (`off`, `false`, `0`) reads *present*.
