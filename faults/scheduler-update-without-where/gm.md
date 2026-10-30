# scheduler-update-without-where — GM notes

**What.** An `UPDATE` of a scheduler node's repository (`queries.yaml`,
the `key` parameter) has lost its row filter: no `WHERE`, and the
filter's parameter gone, so every call rewrites every row of its table.
Planted at render: the scenario writes the entry into
`nodes/<node>/queries.yaml`; nothing runs at injection.

**Writing it into a scenario.** Keep the table small (a few thousand
rows), apart from any table `pg-table-autovacuum-off` names; run the key
with a concurrency of 2 or more so the calls wait on each other's row
locks; size its rate against the WAL and dead rows it makes over the
whole aging (each call writes the whole table). The answer key adds the
PostgreSQL log's lock waits (`node:<db>`, with `log_lock_waits`) and
pgBadger's (`report:pgbadger`). Left out of the v0.3 scenario (capture W4
item 10): its write load grows with the aging.

**Why it matters.** Data loss in the first place (every row gets the
value meant for one), then cost: the whole table's rows rewritten at each
call (WAL, dead rows, autovacuum), and concurrent calls serialising on
row locks.

**Why it happens.** A filter dropped in a refactor, a parameter list
reordered, a hand-written query tested on a one-row table.

**What a good answer says.** Finds the statement (rows per call in
`pg_stat_statements`, the entry itself), names the data damage and the
load, and restores the `WHERE` on the call's row; a `VACUUM` of the table
afterwards.

**Fix path.** Through the write override `/srv/scheduler/repository`:
edit the entry, `sudo gm-reload-scheduler`. The rows already overwritten
are not the check's business.

**Sealed check.** Files only (`queries.yaml`, `/run/scheduler/loaded`).
*Present* while the file is not reloaded or while an `UPDATE ... SET` of
the key's loaded entry has no `WHERE` at its own level (comments,
literals and other statements' clauses aside; `ON CONFLICT DO UPDATE`
and `FOR UPDATE` ignored). *Fixed* once every `UPDATE` has one, or the
entry no longer updates. Exit 2 if the entry became a builder (the check
never runs repository code): judge it by hand.
