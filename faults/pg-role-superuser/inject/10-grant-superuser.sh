#!/bin/sh
# Plants pg-role-superuser: gives role $FAULT_ROLE the SUPERUSER attribute.
# Idempotent: granting it again changes nothing. Fails if the role does
# not exist (the data file creates it).
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d postgres \
    -v role="$FAULT_ROLE" <<'SQL'
ALTER ROLE :"role" SUPERUSER;
SQL
echo "role $FAULT_ROLE is a superuser."
