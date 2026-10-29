# scheduler-insert-retry-duplicates — GM notes

**What.** A scheduler node's ingestion key maps to a builder that inserts
one row carrying the client's own id (`id-column`) and the current time
(`time-column`) into `table-name`, and, for a share of the calls (its
`resend` option), sends the same `INSERT` again with the same values: the
client resending when its acknowledgement is late. Nothing makes the
insert idempotent: no unique constraint on the id. Planted at render:
the scenario copies `inject/resend.py` into `nodes/<node>/builders/`,
adapts its `INSERT` (table, columns, values) and maps the key to it in
`queries.yaml`.

**Writing it into a scenario.**
- The table has no unique constraint on the id; the time column is filled
  by the insert with the current time (`now()`).
- Sizing (capture W4 item 5): at the stream's lowest multiplier, any
  window W must be expected to hold at least 20 × (T+1) duplicates (T the
  threshold), so a half-window without one never happens by chance and
  the early check at night reads *present*. Duplicate *rows* count: a
  resend makes two.
- The answer key gives `window` (at most the definition's 1h minimum) and
  `threshold` (0 as a rule).
- The check connects as `gm_check` straight to the database node's port
  5432 (spec D185): the scenario's `pg_hba.conf` must carry, under its DO
  NOT TAMPER comment, `host all gm_check samenet scram-sha-256` (or the
  game network's range); `load-data` grants `gm_check` `CONNECT` on the
  scenario's databases (D176). The `db-node` parameter names the
  database node, even when the producer goes through a pooler.

**Why it matters.** Wrong counts and sums downstream (deliveries
invoiced twice), and a table growing with copies; nobody notices until
two reports disagree.

**Why it happens.** At-least-once delivery (timeouts, retries, a queue
redelivering) without an idempotency key the database enforces.

**What a good answer says.** Shows the duplicates and their rate, names
the resend and the missing constraint, and proposes idempotency: remove
the existing duplicates, add a unique constraint on the id, and `INSERT
... ON CONFLICT (id) DO NOTHING` in the client. A constraint alone turns
resends into 23505 errors in the producer's log: the data is right, the
client is not, which the GM weighs.

**Fix path.** The repository through the write override
`/srv/scheduler/repository` (the builder and `queries.yaml`, then `sudo
gm-reload-scheduler`), the database through SQL as `dba`, or both.

**Sealed check (behavioural).** Root on the producer, through
`/usr/local/lib/gm/check-sql` (scheduler 0.1.0), as `gm_check` inside the
GM's reserve, read-only, straight to `{DB_NODE}:5432`. d = rows whose
time lies in the trailing window W and whose id occurs more than once
among them. *Fixed* when d ≤ T; *present* when the newest such row is
younger than W/2; else *too soon*, `remaining=` W minus its age. Before
the load starts the table has no recent rows: *fixed*. It counts the rows
still in the table, so deleting the duplicates matters: a deletion reads
*fixed* at once, cause fixed or not, and with the cause still there the
next resend makes it *present* again. After a deletion, run it again a
few resend intervals later, and judge the cause from the client's code
and the table's definition. With the cause fixed and the duplicates
left, it reads *present*, then *too soon*, then *fixed* W after the last
duplicate. Smoke runs see
*present* only once the ingestion has run a few minutes after
`start-load`.
