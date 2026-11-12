# Probe — pg-standby-apply-delay

Descriptive only. As `player`:

1. On the standby, `grep -n recovery_min_apply_delay
   /etc/postgresql/postgresql.conf`: `recovery_min_apply_delay = '1h'`.
2. On the standby, `psql -d postgres -c "SELECT pg_last_wal_receive_lsn(),
   pg_last_wal_replay_lsn(), now() - pg_last_xact_replay_timestamp()"`:
   the received position ahead of the replayed one, the last replayed
   transaction up to an hour old.
3. From the bastion, a late entry on the primary (a row dated yesterday,
   committed after midnight) read on both: on the primary, not on the
   standby, for an hour.
4. From the bastion, `psql -h <primary> -d postgres -c 'SELECT
   application_name, state, replay_lag FROM pg_stat_replication'`:
   `streaming`, the replay lag an hour once the delay has run an hour.

Expected: 1 at any time; 2 and 3 from the first commit on the primary
after the clone; 4 after an hour.
