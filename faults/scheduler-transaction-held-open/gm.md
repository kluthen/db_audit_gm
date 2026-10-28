# scheduler-transaction-held-open — GM notes

**What.** A scheduler node's client keeps its transactions open after its
statements: the `key` parameter's entry in `queries.yaml` carries
`transaction: {isolation: repeatable read, hold: <duration>}`, and a
stream of the node's `schedule.yaml` runs the key at a rate and
concurrency giving rate × hold ≥ 1, so one such transaction is always
open. Its snapshot (`backend_xmin`) keeps vacuum from removing the dead
rows any other session makes, on every table of the cluster. Planted at
render; nothing runs at injection.

**Writing it into a scenario.**
- Repeatable read, or a write inside the transaction, is required: a
  read-committed, read-only transaction keeps no snapshot between its
  statements and holds back no vacuum.
- rate × hold ≥ 1 (a hold of 5m: at least one call every 5 minutes, or a
  concurrency allowing overlaps). A key whose calls take the hold's time
  ties up a session of its connection's pool for as long: size the pool,
  or connect straight to the database (not through a transaction-mode
  pooler, where it would pin a server connection).
- The answer key adds the PostgreSQL log's autovacuum lines naming dead
  rows not yet removable and the oldest xmin (`node:<db>`, with
  `log_autovacuum_min_duration = 0`).
- Its seed changes name `queries.yaml` and `schedule.yaml`, which is never
  fixable, so the loader refuses an expected `fix` on any node (spec
  D186): report or propose.

**Why it matters.** Dead rows accumulate everywhere while the transaction
lives; tables and indexes bloat, queries slow down, and autovacuum burns
work it cannot finish. A transaction held for hours also risks
transaction ID wraparound pressure.

**Why it happens.** A client that opens a transaction for a dashboard or
a cursor and waits on a user, a network call or a sleep before
committing; a connection pool returning connections with a transaction
still open.

**What a good answer says.** Finds the session (`pg_stat_activity`:
idle in transaction, its age, `backend_xmin`, `application_name` naming
the node), ties it to the dead rows not yet removable, and proposes that
the client commits as soon as its statements are done.
`idle_in_transaction_session_timeout` on the database is a guard, not the
fix; terminating the session is first aid.

**Sealed check.** Files only (`queries.yaml`, `/run/scheduler/loaded`).
*Present* while the file is not reloaded or the key's loaded entry
carries a hold above 0 (on the entry, a pool entry or the sequence);
*fixed* once none does. It reads 0 only where a scenario made the
repository editable anyway, since the fault is report or propose only.
