# Probe — pg-role-superuser

Descriptive only in v0.1. As `player`, from the bastion or the database
node: `psql -XAt -c "SELECT rolname FROM pg_roles WHERE rolsuper ORDER BY
1"` lists the application role next to `dba` and `postgres`.

Expected: the role named by the instance's `role` parameter is listed.
