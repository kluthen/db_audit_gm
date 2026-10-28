# pgbouncer-pool-too-small — GM notes

**What.** PgBouncer's pool for one database (the `database` parameter)
is sized below what its clients need at the peak (`default_pool_size`,
or the `[databases]` entry's `pool_size`), in transaction mode: in busy
hours clients queue for a server connection, and their latency is the
wait. Planted at render: the scenario writes the small pool into
`nodes/<pooler>/pgbouncer.ini`; nothing runs at injection.

**Writing it into a scenario.**
- **Precondition**: `pool_mode = transaction` in effect. In session mode
  each scheduler session pins a server connection for the whole game, so
  the shortfall would be constant from the first minute.
- The knob `default_pool_size` takes the seed's small value as its
  `initial` and an envelope reaching `min-pool-size`; `min-pool-size` is
  below the database's `max_connections` less its other clients.
- Size the clients (rates, concurrency, pool sizes of the schedulers'
  connections through the pooler) so waits show in business hours and
  most at the peak, not at night. Set `stats_period` in the seed so the
  log carries the per-period stats lines.
- **Aging minimum (spec D189).** The definition's 30m counts business
  hours under load: raise the instance's `aging_minimum` to the morning's
  business hours' offset from the designed T0 plus 30m (the loader cannot
  check it).
- The answer key adds the clients' `p95_ms` at the peak
  (`node:<producer>`) and Grafana.

**Why it matters.** Requests wait for a connection while the database
idles: the application looks slow and the database looks fine, so people
tune the wrong thing (or raise the database's `max_connections`).

**Why it happens.** The pool sized for last year's traffic, or copied
from a smaller service; the default left in place.

**What a good answer says.** Reads `cl_waiting` and `maxwait` (`SHOW
POOLS`) and the stats lines in busy hours, compares the pool size with
the clients' concurrency, and raises the pool within the envelope and
what the database can take (or adds a reserve pool for the peak).

**Fix path.** On a fixable pooler: edit `pgbouncer.ini`, then `sudo
gm-reload-pgbouncer` (the validator checks the envelope).

**Sealed check.** Root on the pooler, the console over the local socket
as `pgbouncer` (W2-a): the values in effect, so a file edited but not
reloaded reads *present*. *Fixed* once `SHOW DATABASES` gives the
database a `pool_size` of at least `min-pool-size` and a
`max_connections` (its `max_db_connections`) of 0 or at least
`min-pool-size`. The pool mode is not judged.
