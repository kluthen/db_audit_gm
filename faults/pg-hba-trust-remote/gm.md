# pg-hba-trust-remote — GM notes

**What.** A `host all all 0.0.0.0/0 trust` line in `pg_hba.conf`, matched
before the lines asking for a password. Anyone who can reach port 5432
logs in as any role, `dba` and every other superuser included, without a
password. The `scram-sha-256` line after it is dead.

**Why it happens.** A "temporary" line added for a migration or a tool,
never removed. `trust` is often mistaken for "trusted network": it means
no authentication at all.

**What a good answer says.** The line, its position (first match wins),
and the consequence (password-less superuser access from the whole
network). A proposal removes the line or changes it to `scram-sha-256`,
narrows the addresses to the clients that need them, keeps the GM's
`local all postgres peer` line, and reloads (`sudo gm-reload-db`, or
`SELECT pg_reload_conf()`). A good answer tests the result: a login with
no password must now fail.

**Fix paths.** Edit `/etc/postgresql/pg_hba.conf`, then reload. There is
no `ALTER SYSTEM` path: pg_hba.conf is a file, not a setting.

**With a `postgres-exporter` node (v0.2).** The scenario's `pg_hba.conf`
also lets the role `monitoring` in by `samenet` (or an address range),
for the exporter. A fix must keep that line: removing it, or narrowing
the addresses so that it no longer matches, disconnects the exporter
(`pg_up` 0, every PostgreSQL panel empty, "Exporter disconnected from
PostgreSQL" firing). Judge such a fix as breaking the monitoring, even
though the sealed check reads *fixed*.

**Sealed check.** Present while a password-less TCP login to the node's
own address succeeds (the rules in effect), or while the file still holds
a non-local `trust` rule other than loopback (the bastion's address cannot
be tested from the node). A file fixed but not reloaded still reads
*present*. A dead `trust` line placed after a matching password line also
reads *present*: removing it is part of the fix.

**Feedback points.** Reading `pg_hba.conf` top to bottom, first match
wins; testing access from the client side with no password; the
difference between `trust`, `peer` and `scram-sha-256`.
