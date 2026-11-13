# pg-archive-command-silent — GM notes

**What.** The node archives its WAL to the vault, cold storage, through
the `postgres` brick's posting command, `vault-post wal <name> <file>`.
The scenario's `postgresql.conf` has

```
archive_command = 'vault-post wal %p %f || true'
```

Two mistakes on one line. The arguments are swapped: `%p`, the segment's
path (`pg_wal/<segment>`), is given where the name goes, and `vault-post`'s
name rule (letters, digits, `.`, `_`, `-`) refuses it with exit 2 before
posting anything, its reason on standard error, so in the server log. And
`|| true` was appended "so that a vault outage never fills `pg_wal`": the
command always exits 0. The archiver counts every segment archived,
`failed_count` stays 0, the segment is recycled, and none reaches the
vault. Planted at render (seed file), so from the first segment after the
start; the vault still shows the days before it (its planted history), so
the gap starts at the planting.

**Why it matters.** The WAL archive is what lets the base backup be rolled
forward to any moment. With it empty, a restore goes back to last night's
base backup, a day of the clinic's records lost, and nobody knows: every
signal PostgreSQL gives says the archive works. `|| true` is the deeper
mistake: an archive command that fails must fail, so PostgreSQL keeps the
segment and retries; a vault outage then grows `pg_wal`, which monitoring
should catch, rather than silently dropping segments.

**Why it happens.** A copy-paste of the arguments in another order (the
`cp %p /archive/%f` idiom, path first); `|| true` added after an incident
where the vault was down and `pg_wal` filled the disk; nobody compares the
archiver's statistics with what the vault holds.

**What a good answer says.** Reads the archiver against the vault:
`pg_stat_archiver` names segments archived, with no failure, that no
manifest from the node names (`GET /manifests?type=wal&source=<node>`),
and the vault's page shows no WAL shipment since a given day, beside the
weeks before it. Reads the line and the server log (`vault-post: name
pg_wal/...: letters, digits, '.', '_' and '-' only`, once per segment).
Names both mistakes, says point-in-time recovery past the last base backup
is impossible, and says the segments lost meanwhile can never be sent: a
fresh base backup restarts the chain.

**Fix paths.** Both count; a reload is enough (`archive_command` is
reloadable):
- edit `/etc/postgresql/postgresql.conf` to `archive_command = 'vault-post
  wal %f %p'`, then `sudo gm-reload-db`;
- `ALTER SYSTEM SET archive_command = 'vault-post wal %f %p'` as `dba`,
  then `SELECT pg_reload_conf()`.
Then a segment switched (`SELECT pg_switch_wal()`) ships at once and its
manifest names the node. The gap stays: the segments archived during the
fault are gone (recycled), and the vault's page keeps the empty days. That
gap is a finding the players should report, not something to clear.

**Sealed check.** On the node as root: the latest segment
`pg_stat_archiver` counts archived (`check-psql`) must have a `wal`
manifest from this node (cold storage's public `GET /manifests`, Perl
`HTTP::Tiny`; the vault is read as evidence, never judged). *Fixed* once a
segment switched after the fix is in the vault; *present* otherwise, its
line naming the node's latest manifest by `received_at`. Too soon (3) when
the server has archived nothing since it started. The GM switches a
segment after the players' fix before reading it (`SELECT
pg_switch_wal()` as `dba`), since the latest segment archived may predate
the fix.

**The vault's planted history (spec D382, a setup limit, not a fault).**
The planted `wal` manifests of the weeks before T0 name segments of logs
`0x40` and above, which sort above a fresh cluster's live names (log 0):
in name order the vault's "latest" segment is a planted one. Nothing reads
them in name order: this check and the players' evidence compare names and
sources, the page counts days. A player who notices it has found the
fixture's seam, not a fault.

**Placement.** The node must archive to the vault (its seed with
`archive_mode = on` and the brick's `vault_target`). It shares
`postgresql.conf` with any other seed-file fault of the node (statement
logging, a memory knob): both changes go in the scenario's copy, each
check judging its own setting. Beside a register fault on the vault
(`governance-register-flow-undeclared`), the vault still holds its planted
manifests and the nightly base backups (the crontab's, unaffected), so
the register fault's witness stands.

**Feedback points.** An archive command must fail honestly; read the
archiver's statistics against the destination, never alone; a gap in the
archive is closed by a new base backup, not by the fix.
