#!/bin/sh
# Plants security-policy-ownership-end-dropped: portal_animals_scope on
# portal_animals, in database $FAULT_DATABASE, rewritten with its owner
# branch's `o.until_at IS NULL` left out; the keeper branch as vet-portal's
# schema writes it (data/schema.sql). As postgres over the local socket,
# unseen (statement logging, pgaudit and pg_stat_statements off for the
# session, as load-data's sessions). Idempotent: the same USING again.
# Fails if the policy or the table does not exist.
set -eu
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" <<'SQL'
SET log_statement = 'none';
SET log_min_duration_statement = -1;
SET log_min_error_statement = 'panic';
SET pgaudit.log = 'none';
SET pg_stat_statements.track = 'none';
SET client_min_messages = warning;
ALTER POLICY portal_animals_scope ON portal_animals
    USING (EXISTS (SELECT 1 FROM portal_ownerships o
                    WHERE o.animal_id = portal_animals.animal_id AND o.role = 'owner'
                      AND o.owner_id = NULLIF(current_setting('portal.owner_id', true), '')::integer)
           OR EXISTS (SELECT 1 FROM portal_ownerships k
                       WHERE k.animal_id = portal_animals.animal_id AND k.role = 'keeper'
                         AND k.until_at IS NULL
                         AND k.owner_id = NULLIF(current_setting('portal.owner_id', true), '')::integer
                         AND portal_keeper_granted(k.animal_id, k.owner_id)));
SQL
echo "portal_animals_scope in $FAULT_DATABASE: the owner branch no longer reads until_at IS NULL."
