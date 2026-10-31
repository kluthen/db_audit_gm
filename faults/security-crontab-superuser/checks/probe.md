# Probe — security-crontab-superuser

Descriptive only. As `player` on the database node: `sudo gm-crontab -l`
shows an entry whose `psql` has no `-U` and no `PGUSER`, under a
`PGPASSFILE=` line; from the bastion, `psql -h <node> -XAt -c "SELECT
rolsuper FROM pg_roles WHERE rolname = 'postgres'"` reads `t`, and
`psql -h <node> -c '\du <role>'` lists the role `role` names, with LOGIN.
After the entry's minute, `grep -A1 'identity="postgres" method=peer'
/var/log/postgresql/postgresql-*.log` on the node shows its connection:
authenticated by peer as `postgres`, then `connection authorized:
user=postgres database=<its database> application_name=psql`.

Expected: the entry connects as `postgres`, a superuser, while the role
prepared for it exists.
