# pg-abandoned-replication-slot — GM notes

**What.** A physical replication slot with no standby behind it
(`active = false`), left from a standby that was retired or never built.

**Why it matters.** A slot promises its consumer that the server keeps
every WAL segment from the slot's `restart_lsn` on. With no consumer, that
point never moves: `pg_wal` grows with every write, checkpoints cannot
recycle segments, and with `max_slot_wal_keep_size = -1` (the default)
nothing stops it until the disk is full and PostgreSQL stops. In a quiet
game the WAL held back is small; the risk is what it becomes in
production.

**Why it happens.** A standby decommissioned without dropping its slot on
the primary; a backup or replication tool tested once and removed.

**What a good answer says.** The slot, that it is inactive and that no
standby exists (`pg_stat_replication` empty; the topology has one
database node), the WAL it holds, and the outcome (disk full). The fix:
`SELECT pg_drop_replication_slot('<slot>')` after confirming nothing uses
it. A better answer adds `max_slot_wal_keep_size` as a safety net, and
monitoring of inactive slots and of `pg_wal`'s size.

**Fix path.** SQL as `dba`. Setting `max_slot_wal_keep_size` alone does
not drop the slot (it only invalidates it once it passes the limit): it is
an improvement, not the fix.

**Sealed check.** Present while a slot with that name exists.
