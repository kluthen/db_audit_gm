# v0.3 — the PgBouncer brick

Status: draft v1

A PgBouncer brick joins the catalog in v0.3, optional in any scenario,
used when the GM's design needs it (D119). Everything else here is
(proposed).

## Shape

- Brick id `pgbouncer`, version 0.1.0 (D72: new bricks start there),
  role `pooler` (a new role for [formats.md](../../formats.md)'s list;
  proposed).
- A full node of its own (D74): s6, `sshd`, the `player` account, a
  public validator, the node-health script when the topology has a
  metrics store. PgBouncer from Debian 13's package.
- Footprint (to measure): limits 0.25 CPU / 64M, reservations 0.05 CPU /
  32M.
- Seed-once configuration (D11): `pgbouncer.ini` and the user list,
  outside the image, owned so that a fixable node's players edit them
  (as `postgresql.conf` on the database node, D34); reload through a
  `sudo` wrapper (`gm-reload-pgbouncer`).
- Passwords: PgBouncer's `auth_query` against the database, with a
  dedicated lookup role whose password is a generated secret (D79), so no
  plain-text user list holds the application roles' passwords
  (proposed; to settle in the build).
- Knobs with envelopes, as `postgres` has: `default_pool_size`,
  `max_client_conn`, `max_db_connections`, `reserve_pool_size`;
  `pool_mode` with an allowed set (`session`, `transaction`).

## Who connects through it

A scheduler connection names PgBouncer or the database as its target
([scheduler.md](scheduler.md), "The schedule"). The players reach the
admin console (`SHOW POOLS`, `SHOW STATS`, `SHOW CLIENTS`) with `psql`
from the node or the bastion, as a `stats_users` role (proposed).

## Monitoring

`postgres_exporter` does not read PgBouncer. Options (O96): no metrics
in v0.3 (players use the admin console), or a `pgbouncer_exporter`
(prometheus-community) as a brick of its own, one per need (D64).

## Write policy

`fixable` or `report-only`, per scenario. Its faults are mostly fixable
(pool sizes, `pool_mode`). The players' console role is in `stats_users`
only, which reads but changes nothing; `admin_users` can `SET` settings
and `RELOAD` from the console, so it stays the GM's, and a report-only
pooler has no gap like the superuser's on a report-only database (D121).

## Candidate faults

In [faults-with-activity.md](faults-with-activity.md): a pool too small
for the peak, a client bypassing the pooler; also (proposed)
`pool_mode = transaction` with a client relying on session state
(`SET`, advisory locks, `WITH HOLD` cursors), and `max_client_conn` below
the clients' total.

## Open points

O96 (monitoring, admin access, write policy).
