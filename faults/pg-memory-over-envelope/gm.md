# pg-memory-over-envelope — GM notes

**What.** A memory setting, typically `work_mem`, set far above what the
node can afford and above its envelope. The public validator is red from
the first run: that is part of the finding.

**Why it matters.** `work_mem` is not a total: each sort, hash or
materialise step of each connection may use up to that much, and a
parallel query multiplies it by its workers. With 100 connections and a
node limited to 1 GB, a `work_mem` of 256MB lets four or five concurrent
reports exhaust the memory, and the kernel's out-of-memory killer ends a
backend; PostgreSQL then restarts every connection. (`maintenance_work_mem`
and `shared_buffers` have their own failure modes: a vacuum or index build
eating the memory, a server that does not start.)

**Why it happens.** Someone tuned the server for one big report and set
the value globally; or a value copied from a much larger server.

**What a good answer says.** The setting, its value, the memory limit
(`/sys/fs/cgroup/memory.max`) and `max_connections`, the arithmetic that
shows the risk, and a value inside the envelope (for `work_mem`, a few MB
to a few tens of MB here), applied with a reload. A better answer adds
that a report can raise it for its own session (`SET work_mem`) or role
(`ALTER ROLE ... SET`), within reason.

**Fix paths.** Both count, and the release gate tests both:
- edit `/etc/postgresql/postgresql.conf`, then `sudo gm-reload-db` (or
  `SELECT pg_reload_conf()`); `shared_buffers` needs `sudo gm-restart-db`;
- `ALTER SYSTEM SET <setting> = '...'` then a reload. The file's line
  stays, but `postgresql.auto.conf` comes later, so the value pending is
  the new one and the validator turns green.

**Sealed check.** Compares the value in effect (`current_setting`) with
the envelope's maximum, in bytes. A file edited but not reloaded reads
*present*. The check only looks at the upper bound; a value below the
envelope's minimum reads *fixed* but leaves the validator red, which the
GM reads in the official validator run.
