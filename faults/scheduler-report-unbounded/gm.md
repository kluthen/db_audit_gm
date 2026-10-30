# scheduler-report-unbounded — GM notes

**What.** A report of a scheduler node's repository (`queries.yaml`, the
`key` parameter) reads a large table with `SELECT *` and no bound on its
date column (`date-column`): the report's period was dropped, so each
run reads, sorts or groups the whole table and spills to temporary files
at the seed's `work_mem`. Planted at render: the scenario writes the
entry into `nodes/<node>/queries.yaml`.

**Writing it into a scenario.** The table must be large enough for the
sort to spill at the seed's `work_mem` (a few hundred thousand rows at
4MB) and small enough for the database's disk reservation. The program
fetches every row a call returns, in a node of 128M: the report returns
few rows (grouped, ranked, top-N), and no index serves its sort (an index
on its partition or sort key gives an incremental sort, per group, that
never spills; seen on chunk 14's verification). The seed
`postgresql.conf` carries the logging block (`log_temp_files = 0`,
`log_min_duration_statement`) and the `pg_stat_statements` preload. The
answer key adds the PostgreSQL log's `temporary file` and duration lines
(`node:<db>`) and pgBadger (`report:pgbadger`). A report run as a job
(`jobs.yaml`) shows only at its runs: raise the instance's
`aging_minimum` to its first run's offset from T0 plus 30m (spec D189).

**Why it matters.** Each run costs the whole table in I/O, CPU and
temporary files, more every week as the table grows, and slows
everything else while it runs; `SELECT *` ships columns nobody reads.

**Why it happens.** A period filter removed to "get everything" once, a
report built on a small test database.

**What a good answer says.** Finds the statement (temporary blocks and
mean time in `pg_stat_statements`, the log's temporary files, pgBadger),
bounds it to its period, selects only the needed columns, and checks an
index serves the bound. Raising `work_mem` hides the spill, not the
reading.

**Fix path.** Through the write override `/srv/scheduler/repository`:
edit the entry, `sudo gm-reload-scheduler`.

**Sealed check.** Files only (`queries.yaml`, `/run/scheduler/loaded`).
*Present* while the file is not reloaded, or while a statement of the
loaded entry that selects has no `WHERE` comparing `{DATE_COLUMN}` (`<`,
`<=`, `>`, `>=`, `=` on either side, or `BETWEEN`, a cast allowed; in a
subquery or a CTE too). *Fixed* once each has one. `SELECT *` alone is
not judged (the acceptance's proposal names it). Exit 2 if the entry
became a builder.
