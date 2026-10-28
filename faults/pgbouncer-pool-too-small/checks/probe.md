# Probe — pgbouncer-pool-too-small

Descriptive only. As `player`, on the pooler node (or from the bastion,
`psql -h <pooler> -p 6432 -U dba pgbouncer`):

1. `SHOW POOLS;` in business hours: `cl_waiting` above 0 and `maxwait`
   in seconds for `{DATABASE}`, `sv_active` at the pool's size.
2. `SHOW DATABASES;`: the `pool_size` of `{DATABASE}`.
3. `grep 'stats:' /var/log/pgbouncer/pgbouncer.log | tail`: the wait time
   per period rising in business hours.
4. `cat /etc/pgbouncer/pgbouncer.ini`: the small pool and `pool_mode =
   transaction`.

Expected: 1 and 3 within thirty minutes of business-hours load; 2 and 4
at any time.
