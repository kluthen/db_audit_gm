#!/bin/sh
# RL6 each account sees its own animals, and of each only the current
# ownership's documents (vet-portal-release, purpose 15; vet-portal-domain.md,
# "vet-portal-release" and "Who sees what"; access model 9.3), judged on the
# owners' visits recorded since the judged moment (owners.visits, status 200)
# against the core at each visit's moment: each `GET /animals` lists exactly
# the animals the account's owner owns in the core (clinic ownerships, role
# owner), or keeps there (role keeper) with a standing consent (the current
# owner's latest keeper-access event for that keeper and animal, at or before
# the moment, a grant); each `GET /animals/{id}/documents` and `GET
# /documents/{id}` returns only documents of an animal so seen, of the asked
# animal, recorded at or after the current owner's from_at (a herd's document:
# the account's owner the herd's keeper, clinic herds). The copies lag the
# core by up to 10 minutes by design (purpose 15 runs every five, RL5's
# window): an animal listed is wrong only if the account neither owned it nor
# kept it with consent at any moment of [at - 10 min, at], an animal not
# listed only if it owned it (or kept it with consent) throughout; a document
# is wrong only if at no moment of that window it was so seen. Judges runs
# (T271 a buyer reading the seller's record, T274 a keeper reading after the
# owner withdrew, T262 two current owners in the copy, an ownership's end
# never copied).
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (W4 item 0: a check needing a partner's side runs there): the
# visits in partners through check-psql, then the accounts' owners, the
# documents and the keeper-access events in portal through check-psql --node
# records (the portal's tables through the GM's read policy gm_check_read,
# spec D432: no verdict when it is gone or a restrictive policy hides rows),
# then the core's ownerships and herds in clinic, the visits and portal's
# rows handed on as JSON literals in the statement (no argument's size
# limit); all as gm_check, no job is ever run. POSIX sh (the postgres image
# has no python3). Exit 0 fixed (with its witness, 12.3), 1 present, 2
# cannot judge, 3 too soon (remaining=TOO_SOON: the owners' visits come about
# every six minutes in the day, owners.visit's 9.3 an hour, and this node has
# no runner's check-runs to ask). Written for the clinic's names (the
# constants below); the GM adapts them as it copies the purpose.
INVARIANT=RL6
PARTNERS=partners                    # owners.visits' database, on this node
NODE=records                         # the source and target parts' node
PORTAL=portal                        # the target part's database
CLINIC=clinic                        # the source part's database
LAG=600                              # seconds the copies may lag the core (RL5's window)
TOO_SOON=300                         # seconds to wait for a visit
PURPOSE=vet-portal-release
PSQL=/usr/local/lib/gm/check-psql

cannot() { echo "$INVARIANT cannot be judged: $*"; exit 2; }

since=${CHECK_SINCE:-}
case $since in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) cannot "CHECK_SINCE ($since) is not YYYY-MM-DDTHH:MM:SSZ" ;;
esac

# q <node|-> <database> [psql -v ...]: the statement on standard input, its
# rows on standard output (columns joined by |); 2 on any failure.
q() {
    where=$1 db=$2
    shift 2
    if [ "$where" = - ]; then
        "$PSQL" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    else
        "$PSQL" --node "$where" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    fi
}

# The guard (spec D432): the first reason gm_check would not read every row
# of the portal's tables it reads, or nothing.
why=$(q "$NODE" "$PORTAL" -v tables=portal_accounts,portal_documents,portal_consent_events <<'SQL'
SELECT why FROM (
SELECT t.i,
       CASE WHEN c.oid IS NULL THEN t.name || ' is not in ' || current_database()
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read')
                 THEN 'the GM''s read policy on ' || t.name || ' is gone'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read'
                                AND p.permissive = 'PERMISSIVE' AND p.cmd IN ('SELECT', 'ALL')
                                AND p.qual = 'true' AND p.roles && ARRAY['public', 'gm_check']::name[])
                 THEN 'the GM''s read policy on ' || t.name || ' is changed: it no longer shows gm_check every row'
            WHEN r.name IS NOT NULL
                 THEN 'a restrictive policy ' || r.name || ' on ' || t.name || ' hides rows from gm_check'
       END AS why
  FROM unnest(string_to_array(:'tables', ',')) WITH ORDINALITY AS t (name, i)
  LEFT JOIN pg_class c ON c.oid = to_regclass(t.name)
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
  LEFT JOIN LATERAL (SELECT min(p.policyname) AS name FROM pg_policies p
                      WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                        AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('SELECT', 'ALL')
                        AND EXISTS (SELECT 1 FROM unnest(p.roles) AS x (role)
                                     WHERE CASE WHEN x.role = 'public' THEN true
                                                ELSE pg_has_role('gm_check', x.role, 'MEMBER') END)) r ON true
) AS g WHERE why IS NOT NULL ORDER BY i LIMIT 1
SQL
) || cannot "reading $NODE/$PORTAL: $why"
[ -z "$why" ] || cannot "$why"

# The visits since the judged moment: their count, the listings' count and
# all of them as one SQL literal of a JSON array.
v=$(q - "$PARTNERS" <<'SQL'
SELECT count(*), count(*) FILTER (WHERE call = 'GET /animals'),
       quote_literal(coalesce(jsonb_agg(jsonb_build_object(
           'id', id, 'at', at, 'account', account_id, 'call', call,
           'animals', coalesce(animal_ids, '{}'), 'documents', coalesce(document_ids, '{}')) ORDER BY id),
                              '[]')::text)
  FROM owners.visits
 WHERE at > :'since'::timestamptz AND status = 200
   AND call IN ('GET /animals', 'GET /animals/{id}/documents', 'GET /documents/{id}')
SQL
) || cannot "reading $PARTNERS: $v"
visits=${v%%|*}
v=${v#*|}
listings=${v%%|*}
v=${v#*|}
if [ "${listings:-0}" -eq 0 ]; then
    echo "remaining=$TOO_SOON no owner's listing recorded since $since"
    exit 3
fi

# The portal's side: each visiting account's owner, each document returned,
# the keeper-access events naming a visiting owner as the keeper.
p=$({ printf 'WITH v AS (SELECT * FROM jsonb_to_recordset(%s::jsonb)\n' "$v"; cat <<'SQL'
     AS v (id bigint, at timestamptz, account integer, call text, animals integer[], documents integer[])),
a AS (SELECT id, owner_id FROM portal_accounts WHERE id IN (SELECT account FROM v))
SELECT quote_literal(jsonb_build_object(
    'accounts', (SELECT coalesce(jsonb_agg(jsonb_build_object('account', id, 'owner', owner_id)), '[]') FROM a),
    'documents', (SELECT coalesce(jsonb_agg(jsonb_build_object('document', d.id, 'animal', d.animal_id,
                                                               'herd', d.herd_id, 'record_at', d.record_at)), '[]')
                    FROM portal_documents d WHERE d.id IN (SELECT unnest(documents) FROM v)),
    'consents', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'owner', e.owner_id, 'animal', e.animal_id,
                                                              'keeper', e.keeper_id, 'granted', e.granted,
                                                              'at', e.at)), '[]')
                   FROM portal_consent_events e
                  WHERE e.purpose = 'keeper-access' AND e.keeper_id IN (SELECT owner_id FROM a)))::text)
SQL
} | q "$NODE" "$PORTAL") || cannot "reading $NODE/$PORTAL: $p"

# The core's side: each visit judged; `cannot|...`, `bad|...` lines.
out=$({ printf 'WITH v AS (SELECT * FROM jsonb_to_recordset(%s::jsonb)\n' "$v"; cat <<'SQL'
     AS v (id bigint, at timestamptz, account integer, call text, animals integer[], documents integer[])),
SQL
printf 'p AS (SELECT %s::jsonb AS j),\n' "$p"; cat <<'SQL'
acc AS (SELECT x.* FROM p, jsonb_to_recordset(p.j -> 'accounts') AS x (account integer, owner integer)),
doc AS (SELECT x.* FROM p, jsonb_to_recordset(p.j -> 'documents')
                          AS x (document integer, animal integer, herd integer, record_at timestamptz)),
ev AS (SELECT x.* FROM p, jsonb_to_recordset(p.j -> 'consents')
                         AS x (id integer, owner integer, animal integer, keeper integer, granted boolean,
                               at timestamptz)),
va AS (SELECT v.*, acc.owner, v.at - make_interval(secs => :lag) AS lo FROM v LEFT JOIN acc USING (account)),
vd AS (SELECT va.*, u.document, d.animal AS doc_animal, d.herd, d.record_at, d.document IS NOT NULL AS known
         FROM va CROSS JOIN LATERAL unnest(va.documents) AS u (document)
         LEFT JOIN doc d ON d.document = u.document
        WHERE va.call <> 'GET /animals' AND va.owner IS NOT NULL),
-- Each (visit, animal) to judge: a listing's animals listed and those its
-- owner owned or kept in its window; each document's animal.
pair AS (
    SELECT va.id, va.account, va.at, va.lo, va.owner, x.animal, x.animal = ANY (va.animals) AS listed,
           NULL::integer AS document, NULL::timestamptz AS record_at
      FROM va, LATERAL (SELECT unnest(va.animals)
                        UNION
                        SELECT w.animal_id FROM ownerships w
                         WHERE w.owner_id = va.owner AND w.from_at <= va.at
                           AND (w.until_at IS NULL OR w.until_at > va.lo)) AS x (animal)
     WHERE va.call = 'GET /animals' AND va.owner IS NOT NULL
    UNION ALL
    SELECT id, account, at, lo, owner, doc_animal, true, document, record_at
      FROM vd WHERE known AND doc_animal IS NOT NULL
),
-- The moments the account's sight of the animal can change in the window:
-- its start and end, and every ownership's start or end and consent event
-- of the animal inside it.
inst AS (
    SELECT pair.*, t.t
      FROM pair, LATERAL (SELECT pair.lo UNION SELECT pair.at
                          UNION SELECT w.from_at FROM ownerships w
                                 WHERE w.animal_id = pair.animal AND w.from_at > pair.lo AND w.from_at <= pair.at
                          UNION SELECT w.until_at FROM ownerships w
                                 WHERE w.animal_id = pair.animal AND w.until_at > pair.lo AND w.until_at <= pair.at
                          UNION SELECT e.at FROM ev e
                                 WHERE e.animal = pair.animal AND e.at > pair.lo AND e.at <= pair.at) AS t (t)
),
st AS (
    SELECT inst.*,
           (EXISTS (SELECT 1 FROM ownerships w
                     WHERE w.animal_id = inst.animal AND w.owner_id = inst.owner AND w.role = 'owner'
                       AND w.from_at <= inst.t AND (w.until_at IS NULL OR w.until_at > inst.t))
            OR (EXISTS (SELECT 1 FROM ownerships k
                         WHERE k.animal_id = inst.animal AND k.owner_id = inst.owner AND k.role = 'keeper'
                           AND k.from_at <= inst.t AND (k.until_at IS NULL OR k.until_at > inst.t))
                AND coalesce((SELECT e.granted FROM ev e JOIN ownerships c ON c.owner_id = e.owner
                               WHERE c.animal_id = inst.animal AND c.role = 'owner' AND c.from_at <= inst.t
                                 AND (c.until_at IS NULL OR c.until_at > inst.t)
                                 AND e.animal = inst.animal AND e.keeper = inst.owner AND e.at <= inst.t
                               ORDER BY e.at DESC, e.id DESC LIMIT 1), false))) AS seen,
           (SELECT max(c.from_at) FROM ownerships c
             WHERE c.animal_id = inst.animal AND c.role = 'owner' AND c.from_at <= inst.t
               AND (c.until_at IS NULL OR c.until_at > inst.t)) AS owner_since
      FROM inst
),
verdict AS (
    SELECT id, account, at, animal, listed, document,
           bool_or(seen) AS ever, bool_and(seen) AS always, coalesce(bool_or(seen AND record_at >= owner_since), false)
             AS doc_ok
      FROM st GROUP BY id, account, at, animal, listed, document
)
SELECT 'cannot|account ' || account || ' of visit ' || id || ' is not in portal' FROM va WHERE owner IS NULL
UNION ALL
SELECT 'cannot|document ' || document || ' of visit ' || id || ' is not in portal' FROM vd WHERE NOT known
UNION ALL
SELECT 'bad|' || id || '|visit ' || id || ' (account ' || account || ', ' || at || '): '
       || CASE WHEN document IS NOT NULL
                    THEN call || ' returned document ' || document || ' of animal ' || animal
                         || ', not seen by the account or recorded before the current ownership in the '
                         || (:lag / 60) || ' minutes before'
               WHEN listed THEN 'GET /animals listed animal ' || animal || ', which the account neither owned nor '
                                || 'kept with consent in the ' || (:lag / 60) || ' minutes before'
               ELSE 'GET /animals did not list animal ' || animal || ', which the account owned or kept with '
                    || 'consent throughout the ' || (:lag / 60) || ' minutes before' END
  FROM verdict JOIN v USING (id, account, at)
 WHERE CASE WHEN document IS NOT NULL THEN NOT doc_ok WHEN listed THEN NOT ever ELSE always END
UNION ALL
SELECT 'bad|' || vd.id || '|visit ' || vd.id || ' (account ' || vd.account || ', ' || vd.at || '): '
       || vd.call || ' returned document ' || vd.document || ' of animal ' || vd.doc_animal || ', not of animal '
       || vd.animals[1] || ' it asked for'
  FROM vd WHERE vd.known AND vd.call = 'GET /animals/{id}/documents'
            AND vd.doc_animal IS DISTINCT FROM vd.animals[1]
UNION ALL
SELECT 'bad|' || vd.id || '|visit ' || vd.id || ' (account ' || vd.account || ', ' || vd.at || '): '
       || vd.call || ' returned document ' || vd.document || ' of herd ' || vd.herd
       || ', whose keeper the account''s owner is not'
  FROM vd LEFT JOIN herds h ON h.id = vd.herd
 WHERE vd.known AND vd.doc_animal IS NULL AND h.keeper_owner_id IS DISTINCT FROM vd.owner
ORDER BY 1
SQL
} | q "$NODE" "$CLINIC" -v lag="$LAG") || cannot "reading $NODE/$CLINIC: $out"

c=$(printf '%s\n' "$out" | sed -n 's/^cannot|//p' | head -n 1)
[ -z "$c" ] || cannot "$c"
bad=$(printf '%s\n' "$out" | sed -n 's/^bad|[0-9]*|//p')
if [ -n "$bad" ]; then
    n=$(printf '%s\n' "$bad" | wc -l | tr -d ' ')
    more=
    [ "$n" -gt 1 ] && more=" ($n wrong among $visits visits recorded since $since)"
    echo "$INVARIANT present: $(printf '%s\n' "$bad" | head -n 1)$more"
    exit 1
fi
echo "$INVARIANT fixed: $visits owners' visits recorded since $since ($listings listings), each listing the" \
     "account's animals by the core, each document of one it saw, from within the current ownership"
exit 0
