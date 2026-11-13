# Probe — pg-archive-command-silent

Descriptive only. As `player`, on the bastion:

1. `psql -h {database node} -d postgres -c 'SELECT pg_walfile_name(pg_switch_wal())'`
   as `dba` switches a segment (or wait for `archive_timeout`); then
   `psql -h {database node} -d postgres -c 'SELECT last_archived_wal,
   failed_count FROM pg_stat_archiver'` names that segment archived, with
   no failure.
2. `curl -s "http://cold-storage:8000/manifests?type=wal&source={database node}&from=$(date -u +%F)"`
   lists no manifest naming it; the vault's page (`http://cold-storage:8000/`,
   or the web front's `/cold-storage/` when the scenario routes it) shows
   no `wal` shipment since the fault, beside the days before it.
3. On the node: `grep -n archive_command /etc/postgresql/postgresql.conf`
   shows `'vault-post wal %p %f || true'`; `grep -h 'vault-post:'
   /var/log/postgresql/postgresql-*.log | tail -n 3` shows vault-post
   refusing the name `pg_wal/<segment>`, once per segment.

Expected: 1 and 2 within seconds of the switch; 3 from the first segment
archived after the start.
