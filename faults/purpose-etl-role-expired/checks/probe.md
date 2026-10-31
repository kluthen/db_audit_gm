# Probe — purpose-etl-role-expired

Descriptive only. As `player`:

1. On the database node, the server log (`grep -h -A1 'user={ROLE},'
   /var/log/postgresql/postgresql-*.log | tail`): `password
   authentication failed for user "{ROLE}"`, `DETAIL: User "{ROLE}" has
   an expired password.`, at each hourly run since this morning.
2. From the bastion, `psql -h db -c '\du {ROLE}'`: `Password valid
   until` a moment of this morning.
3. From the bastion, `psql -h reporting -d reporting`: `rpt.etl_runs`
   has no row of the roll-up since that moment; on the transformer, its
   log shows the runs refused their connection.

Expected: 2 from the planting; 1 and 3 from the hourly job's first run
after it.
