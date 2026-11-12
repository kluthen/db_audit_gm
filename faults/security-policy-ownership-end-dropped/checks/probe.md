# Probe — security-policy-ownership-end-dropped

Descriptive only. As `player`, on the bastion (`dba` in psql):

1. `psql -h {database node} -d {database} -c "SELECT polname,
   pg_get_expr(polqual, polrelid) FROM pg_policy WHERE polrelid =
   'portal_animals'::regclass"`: `portal_animals_scope`'s owner branch
   (`o.role = 'owner'`) has no `until_at IS NULL`, its keeper branch does.
2. `psql -h {database node} -d {database} -c "SELECT animal_id, owner_id,
   from_at, until_at FROM portal_ownerships WHERE role = 'owner' AND
   until_at IS NOT NULL ORDER BY until_at DESC LIMIT 5"`: animals sold or
   given away, their former owners' rows ended.
3. In one session, `SET ROLE portal_api; SELECT set_config('portal.owner_id',
   '<a former owner>', false); SELECT animal_id FROM portal_animals`: the
   animal the former owner no longer owns is listed.

Expected: 1 at any time after planting; 2 and 3 for every ownership ended
before or after it.
