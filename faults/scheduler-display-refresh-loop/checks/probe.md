# Probe — scheduler-display-refresh-loop

Descriptive only. As `player`, on the bastion:

1. `psql -h {db_node} -d postgres -c "SELECT queryid, calls FROM
   pg_stat_statements WHERE query = 'SELECT * FROM housing_unit_board WHERE
   unit_id = \$1'"`, twice a minute apart: one queryid, its calls up by
   about 124 in the minute where the wards' 64 displays account for 64.
2. `psql -h {db_node} -d postgres -c "SELECT application_name, usename,
   count(*) FROM pg_stat_activity WHERE datname = '{database}' GROUP BY 1, 2"`:
   the board's sessions are `ward`'s, as `vet_display`.
3. As `dba`, `ALTER ROLE vet_display SET log_min_duration_statement = 0`
   and the `vet_display` sessions terminated; a minute later the server
   log on `{db_node}` (`/var/log/postgresql/postgresql-*.log`) shows
   `Parameters: $1 = '{unit}'` about once a second, every other unit's
   about once a minute on average; then `ALTER ROLE vet_display RESET
   log_min_duration_statement`.
4. `psql -h {db_node} -d {database}`: the unit's display in
   `housing_displays` (no `removed_on`), its open placement, the stay, the
   animal.

Expected: 1 and 2 at any time after the start; 3 within a minute of the
setting; 4 at any time while the unit is occupied.
