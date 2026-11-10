#!/bin/sh
# EX4 an exchange carries what the agreement allows (vet-centre-exchanges;
# v0.5 master spec 12.2 purpose 4; clinic-purposes.md 8; spec D293): this
# animal's record and its owner's contact, never another animal's or
# another owner's. A runs invariant: it judges what the centres took since
# the judged moment, as sent (centres.messages keeps each body), with the
# runs of sync-exchanges and chase-exchanges since then.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (no runner here: capture W4 item 0, "Where a check runs"). It
# reads the centres' stub in partners through check-psql and the clinic's
# record as gm_check through check-psql --node records; it never runs a job
# and never calls an endpoint. A table read with row security needs the GM's
# read policy (spec D432): gone, the check exits 2.
#
# - Each request message since the judged moment (the latest 200): only
#   the agreement's fields (exchange_key, ref, kind, reason, requested_at;
#   the animal's identity; its record's dates and findings; the owner's id,
#   name, e-mail, phone). Against the record: the clinic's exchange under
#   that key and ref, its own animal with its own identifiers, an owner of
#   that animal at the time (id and name), and each consultation one of
#   that animal's (its findings, its date within a day).
# - Exit 1: a message breaking any of these. Exit 0: at least one message
#   and one judged run, none breaking them. Exit 3 otherwise (remaining=
#   one cycle). Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
INVARIANT=EX4
#
# The node has no Python (the postgres brick): each side is read in one
# statement, what one side holds is handed to the other as a psql variable
# (JSON), and the verdict is computed in SQL, as `<exit>|<line>`.
set -u
DB=partners                          # the centres' stub's database, on this node
CLINIC_NODE=records                  # the source part: node, database
CLINIC_DB=clinic
CHECK_PSQL=/usr/local/lib/gm/check-psql
# The centres' hostnames by site, in the SQL below: 2 aldermoor-central,
# 3 aldermoor-south, any other (4 to 6) aldermoor-abroad.
case ${CHECK_SINCE:-} in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "$INVARIANT cannot be judged: CHECK_SINCE ${CHECK_SINCE:-} is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac

# q <node, or - for this one> <database> [-v name=value]...: the statement on
# standard input as gm_check, CHECK_SINCE bound as :'since'; on an error, the
# reason on standard output and status 2 (the caller exits with it).
q() {
    qnode=$1 qdb=$2
    shift 2
    if [ "$qnode" = - ]; then set -- -d "$qdb" "$@"; qwhere="this node/$qdb"
    else set -- --node "$qnode" -d "$qdb" "$@"; qwhere="$qnode/$qdb"; fi
    qout=$("$CHECK_PSQL" "$@" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1) || {
        echo "$INVARIANT cannot be judged: $qwhere: $(printf '%s\n' "$qout" | tail -n 1)"
        return 2
    }
    printf '%s\n' "$qout"
}

# The GM's read policy (spec D432): a table with row security is read only
# through gm_check_read; dropped, or a restrictive policy naming public or
# gm_check, every read would come back empty, so the check refuses to judge.
guard() {   # guard <node or -> <database> <tables, comma separated>
    gone=$(q "$1" "$2" -v tables="$3" <<'SQL'
SELECT coalesce(min(c.oid::regclass::text), '') FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.oid = ANY (string_to_array(:'tables', ',')::regclass[]) AND c.relrowsecurity
   AND (NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                      AND p.policyname = 'gm_check_read')
        OR EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                     AND p.permissive = 'RESTRICTIVE' AND p.roles && ARRAY['public', 'gm_check']::name[]))
SQL
) || { printf '%s\n' "$gone"; exit 2; }
    if [ -n "$gone" ]; then
        if [ "$1" = - ]; then where="this node/$2"; else where="$1/$2"; fi
        echo "$INVARIANT cannot be judged: the GM's read policy on $gone is gone ($where)"
        exit 2
    fi
}

# verdict <`exit|line`>: the line printed, the exit taken.
verdict() {
    case $1 in
        [0-3]\|*) printf '%s\n' "${1#*|}"; exit "${1%%|*}" ;;
        *) echo "$INVARIANT cannot be judged: an answer that is not a verdict: $(printf '%s' "$1" | head -c 80)"; exit 2 ;;
    esac
}

guard - "$DB" centres.messages
guard "$CLINIC_NODE" "$CLINIC_DB" exchanges,animals,ownerships,owners,consultations,ops.runs
# The latest 200 request messages since the judged moment (a few a day), as
# the centres took them: each body's fields against the agreement's (the
# exchange: exchange_key, ref, kind, reason, requested_at; the animal's
# identity; its record's dates and findings; the owner's id, name, e-mail,
# phone), and the well-formed ones' content handed to the record.
got=$(q - "$DB" <<'SQL'
WITH m AS (SELECT id, hostname AS host, exchange_key AS key, extract(epoch FROM at) AS at, body,
                  hostname || '''s request message ' || id || ' (key ' || exchange_key || ')' AS who
             FROM (SELECT * FROM centres.messages WHERE kind = 'request' AND at > :'since'::timestamptz
                    ORDER BY id DESC LIMIT 200) x),
c AS (
  SELECT m.*,
         CASE WHEN jsonb_typeof(body->'animal') = 'object' THEN body->'animal' ELSE '{}' END AS animal,
         CASE WHEN jsonb_typeof(body->'owner') = 'object' THEN body->'owner' END AS owner,
         CASE WHEN jsonb_typeof(body->'record') = 'array' THEN body->'record' ELSE '[]' END AS record
    FROM m),
e AS (
  SELECT c.*, CASE WHEN jsonb_typeof(body) = 'object' THEN
           ARRAY(SELECT k FROM jsonb_object_keys(body) AS k
                  WHERE k <> ALL (ARRAY['exchange_key', 'ref', 'kind', 'reason', 'requested_at', 'animal', 'record', 'owner'])
                  ORDER BY k COLLATE "C")
           || ARRAY(SELECT 'animal.' || k FROM jsonb_object_keys(animal) AS k
                     WHERE k <> ALL (ARRAY['id', 'species', 'breed', 'sex', 'born_on', 'name', 'microchip', 'ueln',
                                           'passport_number', 'ear_tag']) ORDER BY k COLLATE "C")
           || ARRAY(SELECT 'owner.' || k FROM jsonb_object_keys(coalesce(owner, '{}')) AS k
                     WHERE k <> ALL (ARRAY['id', 'name', 'email', 'phone']) ORDER BY k COLLATE "C")
           || ARRAY(SELECT DISTINCT 'record[].' || k COLLATE "C"
                      FROM jsonb_array_elements(record) AS r
                     CROSS JOIN LATERAL jsonb_object_keys(CASE WHEN jsonb_typeof(r) = 'object' THEN r ELSE '{}' END) AS k
                     WHERE k <> ALL (ARRAY['date', 'findings']) ORDER BY 1) END AS extra
    FROM c),
f AS (
  SELECT e.*, CASE
           WHEN jsonb_typeof(body) IS DISTINCT FROM 'object' THEN who || ' is not an object'
           WHEN cardinality(extra) > 0 THEN who || ' carries ' || array_to_string(extra, ', ') || ', beyond the agreement'
           WHEN NOT (jsonb_typeof(body->'ref') = 'number' AND (body->>'ref') ~ '^-?[0-9]+$'
                     AND jsonb_typeof(animal->'id') = 'number' AND (animal->>'id') ~ '^-?[0-9]+$')
             THEN who || ' names no exchange or no animal'
         END AS wrong
    FROM e)
SELECT jsonb_build_object(
  'n', (SELECT count(*) FROM f),
  'wrong', (SELECT coalesce(jsonb_agg(wrong ORDER BY id), '[]') FROM f WHERE wrong IS NOT NULL),
  'shape', (SELECT coalesce(jsonb_agg(jsonb_build_object(
               'mid', id, 'host', host, 'key', key, 'ref', (body->>'ref')::bigint, 'at', at, 'animal', animal, 'owner', owner,
               'record', (SELECT coalesce(jsonb_agg(r), '[]') FROM jsonb_array_elements(record) AS r WHERE jsonb_typeof(r) = 'object'))
             ORDER BY id), '[]') FROM f WHERE wrong IS NULL))
SQL
) || { printf '%s\n' "$got"; exit 2; }
# Against the record, as the agreement reads it: the exchange's own animal,
# its identity as recorded, an owner it had then, and only its own
# consultations (a date within a day of one, its findings as written).
v=$(q "$CLINIC_NODE" "$CLINIC_DB" -v got="$got" <<'SQL'
WITH p AS (SELECT :'got'::jsonb AS j),
m AS (SELECT x.* FROM p CROSS JOIN LATERAL jsonb_to_recordset(p.j->'shape')
             AS x (mid bigint, host text, key text, ref integer, at float8, animal jsonb, owner jsonb, record jsonb)),
found AS (
  SELECT m.mid, m.host, m.key, w.what
    FROM m
    LEFT JOIN exchanges e ON e.id = m.ref AND e.direction = 'out'
    LEFT JOIN animals a ON a.id = (m.animal->>'id')::integer
   CROSS JOIN LATERAL (
     SELECT 'names exchange ' || m.ref || ', which is not the clinic''s request under that key' AS what
      WHERE e.id IS NULL OR e.exchange_key::text <> m.key
     UNION ALL
     SELECT 'carries animal ' || (m.animal->>'id') || ', exchange ' || m.ref || ' is animal ' || e.animal_id || '''s'
      WHERE e.id IS NOT NULL AND e.animal_id IS DISTINCT FROM (m.animal->>'id')::integer
     UNION ALL
     SELECT 'carries identifiers that are not animal ' || (m.animal->>'id') || '''s'
      WHERE a.id IS NOT NULL AND (a.microchip IS DISTINCT FROM m.animal->>'microchip'
                                  OR a.ueln IS DISTINCT FROM m.animal->>'ueln'
                                  OR a.passport_number IS DISTINCT FROM m.animal->>'passport_number'
                                  OR a.ear_tag IS DISTINCT FROM m.animal->>'ear_tag')
     UNION ALL
     SELECT 'carries owner ' || (m.owner->>'id') || ', who did not own animal ' || (m.animal->>'id') || ' then'
      WHERE m.owner IS NOT NULL AND jsonb_typeof(m.owner) = 'object' AND NOT EXISTS (
              SELECT 1 FROM ownerships w JOIN owners o ON o.id = w.owner_id
               WHERE w.animal_id = (m.animal->>'id')::integer AND w.role = 'owner'
                 AND o.id::text = m.owner->>'id' AND o.name = m.owner->>'name'
                 AND w.from_at <= to_timestamp(m.at) AND (w.until_at IS NULL OR w.until_at > to_timestamp(m.at) - interval '1 day'))
     UNION ALL
     SELECT 'carries a consultation of ' || (r->>'date') || ' that is not animal ' || (m.animal->>'id') || '''s'
       FROM jsonb_array_elements(m.record) AS r
      WHERE NOT EXISTS (SELECT 1 FROM consultations c
                         WHERE c.animal_id = (m.animal->>'id')::integer
                           AND coalesce(c.findings, '') = coalesce(r->>'findings', '')
                           AND abs((c.started_at AT TIME ZONE 'UTC')::date - (r->>'date')::date) <= 1)
   ) w),
bad AS (
  SELECT 1 AS grp, t.n AS k, t.x AS what FROM p CROSS JOIN LATERAL jsonb_array_elements_text(p.j->'wrong') WITH ORDINALITY AS t (x, n)
  UNION ALL
  SELECT 2, mid, host || '''s request message ' || mid || ' (key ' || key || ') ' || what FROM found),
runs AS (SELECT count(*) AS n FROM ops.runs WHERE purpose = 'vet-centre-exchanges'
            AND job IN ('sync-exchanges', 'chase-exchanges') AND started_at > :'since'::timestamptz)
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM bad) THEN (
    SELECT '1|EX4 present: ' || what
           || CASE WHEN (SELECT count(*) FROM bad) > 1 THEN ' (' || (SELECT count(*) FROM bad) || ' such since ' || :'since' || ')'
                   ELSE '' END
      FROM bad ORDER BY grp, k LIMIT 1)
  WHEN (j->>'n')::integer > 0 AND (SELECT n FROM runs) > 0 THEN
    '0|EX4 fixed: ' || (j->>'n') || ' requests posted to the centres since ' || :'since' || ', each carrying its exchange''s '
    || 'animal, its own record and an owner it had, nothing more (' || (SELECT n FROM runs) || ' runs)'
  ELSE '3|remaining=300 ' || (SELECT n FROM runs) || ' runs of sync-exchanges and chase-exchanges since ' || :'since'
       || ', no request posted to a centre since: nothing to judge yet'
END FROM p
SQL
) || { printf '%s\n' "$v"; exit 2; }
verdict "$v"
