#!/bin/sh
# Sealed check of security-policy-ownership-end-dropped (master spec 8.1;
# v0.5 master spec 17.2 s5; capture W5 items 0 and 4, W5-d). Run as root on
# the database node; connects to $FAULT_DATABASE as the GM check role
# gm_check through the root-only helper check-psql, never as portal_api or
# dba, and changes nothing but its own session.
#
# Judges the live policy, not its text, whichever way it was fixed: the
# permissive SELECT policies on portal_animals that apply to portal_api
# (its own, PUBLIC's, a role's it is a member of) OR'ed, the restrictive
# ones AND'ed, evaluated as gm_check with portal.owner_id set to a witness:
# the most recent ended `owner` ownership whose owner neither owns nor
# keeps the animal now, while another owner does. gm_check reads every row
# of portal_animals and portal_ownerships through their gm_check_read
# policies (spec D432), found in place first (else exit 2, "cannot
# judge"). gm_check holds no EXECUTE on portal_keeper_granted, so each call
# to it in the expression is read as a call to a session-local function
# answering false: the witness keeps nothing, so the keeper's branch could
# never admit them anyway. Present (1): the former owner passes for the
# animal, or row-level security does not hold portal_api to the policies at
# all (off on the table, portal_api BYPASSRLS, or its owner without FORCE).
# Fixed (0): the former owner does not pass and the current owner does.
# Present (1) as well when the current owner no longer passes (a fix that
# hides the animal from its owner is no fix). Too soon (3): no ownership
# has ended yet. Error (2): the guard, a parameter, the helper.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
[ -n "${FAULT_DATABASE:-}" ] || { echo "FAULT_DATABASE must be set."; exit 2; }
[ -x "$CHECK_PSQL" ] || { echo "$CHECK_PSQL is missing: the postgres brick predates 0.3.0's GM check role."; exit 2; }

out=$("$CHECK_PSQL" -d "$FAULT_DATABASE" -Atq -v ON_ERROR_STOP=1 2>&1 <<'SQL'
SET client_min_messages = warning;
SELECT count(*) = 2 AS ok FROM pg_policies
 WHERE schemaname = 'public' AND tablename IN ('portal_animals', 'portal_ownerships')
   AND policyname = 'gm_check_read' \gset guard_
\if :guard_ok
\else
\echo 'guard'
\quit
\endif
SELECT coalesce(w.animal_id::text, '') AS animal, coalesce(w.former::text, '') AS former,
       coalesce(w.current_owner::text, '') AS current_owner
  FROM (SELECT 1) AS one
  LEFT JOIN (SELECT o.animal_id, o.owner_id AS former, c.owner_id AS current_owner, o.until_at
               FROM public.portal_ownerships o
               JOIN public.portal_ownerships c ON c.animal_id = o.animal_id AND c.role = 'owner'
                AND c.until_at IS NULL AND c.owner_id <> o.owner_id
              WHERE o.role = 'owner' AND o.until_at IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM public.portal_ownerships n
                                 WHERE n.animal_id = o.animal_id AND n.owner_id = o.owner_id
                                   AND n.until_at IS NULL)
              ORDER BY o.until_at DESC, o.animal_id LIMIT 1) AS w ON true \gset w_
SELECT :'w_animal' = '' AS none \gset
\if :none
\echo 'none'
\quit
\endif
SELECT NOT c.relrowsecurity OR r.rolbypassrls OR (c.relowner = r.oid AND NOT c.relforcerowsecurity) AS open
  FROM pg_class c, pg_roles r
 WHERE c.oid = 'public.portal_animals'::regclass AND r.rolname = 'portal_api' \gset rls_
\if :rls_open
SELECT 'open|' || :'w_animal' || '|' || :'w_former' || '|' || :'w_current_owner';
\quit
\endif
SELECT coalesce('(' || string_agg('(' || coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') || ')', ' OR ')
                         FILTER (WHERE p.polpermissive) || ')', 'false')
       || coalesce(' AND ' || string_agg('(' || coalesce(pg_get_expr(p.polqual, p.polrelid), 'true') || ')', ' AND ')
                                FILTER (WHERE NOT p.polpermissive), '') AS expr
  FROM pg_policy p
 WHERE p.polrelid = 'public.portal_animals'::regclass AND p.polcmd IN ('r', '*')
   AND EXISTS (SELECT 1 FROM unnest(p.polroles) AS x(oid)
                WHERE CASE WHEN x.oid = 0 THEN true ELSE pg_has_role('portal_api', x.oid, 'MEMBER') END) \gset
CREATE FUNCTION pg_temp.gm_no_keeper_grant(integer, integer) RETURNS boolean LANGUAGE sql IMMUTABLE AS 'SELECT false';
SELECT format('SELECT count(*) > 0 AS sees FROM public.portal_animals WHERE animal_id = %s AND (%s)', :'w_animal',
              regexp_replace(:'expr', '(public\.)?portal_keeper_granted\(', 'pg_temp.gm_no_keeper_grant(', 'g')) AS q \gset
SELECT set_config('portal.owner_id', :'w_former', false) AS asker \gset gm_
:q \gset seller_
SELECT set_config('portal.owner_id', :'w_current_owner', false) AS asker \gset gm_
:q \gset buyer_
SELECT 'judged|' || :'w_animal' || '|' || :'w_former' || '|' || :'w_current_owner' || '|' || :'seller_sees' || '|' || :'buyer_sees';
SQL
) || { echo "cannot judge portal_animals' policies in $FAULT_DATABASE as gm_check: $(printf '%s' "$out" | tail -n 1)"; exit 2; }

line=$(printf '%s\n' "$out" | tail -n 1)
case $line in
    guard)
        echo "cannot judge: gm_check_read is not in place on portal_animals and portal_ownerships in $FAULT_DATABASE (load-data's step (2c), spec D432)."
        exit 2 ;;
    none)
        echo "remaining=0 no ownership has ended yet in $FAULT_DATABASE: no former owner to judge the policy with."
        exit 3 ;;
    open\|*)
        set -- $(printf '%s' "${line#open|}" | tr '|' ' ')
        echo "row-level security does not hold portal_api to portal_animals' policies (off, BYPASSRLS, or its owner without FORCE): former owner $2 sees animal $1."
        exit 1 ;;
    judged\|*)
        set -- $(printf '%s' "${line#judged|}" | tr '|' ' ')
        animal=$1 former=$2 current=$3 seller=$4 buyer=$5
        if [ "$seller" = t ]; then
            echo "portal_animals' policies still admit former owner $former for animal $animal, which owner $current has owned since its last sale or gift."
            exit 1
        fi
        if [ "$buyer" != t ]; then
            echo "portal_animals' policies no longer admit former owner $former for animal $animal, but its current owner $current no longer sees it either."
            exit 1
        fi
        echo "portal_animals' policies admit the current owner $current for animal $animal, not its former owner $former."
        exit 0 ;;
esac
echo "unexpected answer from PostgreSQL: $line"
exit 2
