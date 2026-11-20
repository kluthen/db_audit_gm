# Probe — docs-overview-backup-claimed

Descriptive only. As `player`, on the bastion:

1. `awk '/^### {NODE}$/,/^## /' ~/network-overview.md | grep -n -A6 '\*\*Backups\*\*'`
   lists, among the entry's Backups, the claimed protection ({CLAIMED});
   the web front's "Network overview" page shows the same entry.
2. `psql -h {NODE} -c 'SHOW archive_mode' -c 'SHOW archive_command' -c 'SELECT * FROM pg_stat_archiver' -c 'SELECT * FROM pg_stat_replication'`:
   for a claimed WAL archive, `archive_mode` is `off` (or no
   `archive_command`), `pg_stat_archiver` counts no archived segment; for
   a claimed replica, `pg_stat_replication` has no row.
3. `curl -s "http://cold-storage:8000/manifests?type=wal&source={NODE}"`
   (the vault's hostname as `partners.md` gives it) lists no WAL segment of
   the node: the vault holds only what the node truly sends (its nightly
   base backups, `type=basebackup`).

Expected: all three from the start of the game, with no load.
