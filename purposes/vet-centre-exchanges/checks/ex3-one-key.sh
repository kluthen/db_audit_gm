#!/bin/sh
# EX3 one key per exchange, each answer on its own (vet-centre-exchanges;
# v0.5 master spec 12.2 purpose 4; clinic-purposes.md 8): one exchange_key
# per exchange, kept on a resend, and each answer recorded on its own
# exchange. A runs invariant: it judges the runs of sync-exchanges and
# chase-exchanges since the judged moment (their ops.runs rows in clinic)
# and what they and the centres left.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (no runner here: capture W4 item 0, "Where a check runs"). It
# reads the centres' stub in partners through check-psql and the clinic's
# record as gm_check through check-psql --node records; it never runs a job
# and never calls an endpoint. A table read with row security needs the GM's
# read policy (spec D432): gone, the check exits 2.
#
# - The posts of the judged runs (ops.exchange_messages, out, request or
#   resend): each under its exchange's own key. The centres: every request
#   message since the judged moment under the key of the clinic's exchange
#   it names (body ref), and no exchange of the clinic held twice under two
#   keys. Every outbound exchange answered since the judged moment holds the
#   answer its centre gave on that key (accepted with its date, or
#   declined).
# - Exit 1: any of these broken. Exit 0: at least one judged run and one
#   post or answer, none broken. Exit 3 otherwise (remaining= one cycle).
#   Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
INVARIANT=EX3
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

guard "$CLINIC_NODE" "$CLINIC_DB" exchanges,ops.runs,ops.exchange_messages
guard - "$DB" centres.exchanges,centres.messages
# The centres' request messages since the judged moment: the key each came
# under and the clinic's exchange it names (body ref).
msgs=$(q - "$DB" <<'SQL'
SELECT coalesce(jsonb_agg(jsonb_build_object('host', hostname, 'key', exchange_key, 'ref', body->>'ref') ORDER BY id), '[]')
  FROM centres.messages WHERE kind = 'request' AND at > :'since'::timestamptz
SQL
) || { printf '%s\n' "$msgs"; exit 2; }
# The clinic's side: the judged runs (ops.runs), their requests and resends
# with the key each was posted under against its exchange's own, each
# message's key against the exchange it names, and the outbound exchanges
# answered since the judged moment.
clinic=$(q "$CLINIC_NODE" "$CLINIC_DB" -v msgs="$msgs" <<'SQL'
WITH r AS (SELECT id FROM ops.runs WHERE purpose = 'vet-centre-exchanges' AND job IN ('sync-exchanges', 'chase-exchanges')
              AND started_at > :'since'::timestamptz),
posts AS (SELECT m.id, m.exchange_id, m.exchange_key AS posted, m.kind, e.exchange_key AS own
            FROM ops.exchange_messages m LEFT JOIN exchanges e ON e.id = m.exchange_id
           WHERE m.run_id IN (SELECT id FROM r) AND m.direction = 'out' AND m.kind IN ('request', 'resend')),
msgs AS (SELECT n, a.m->>'host' AS host, a.m->>'key' AS key, a.m->>'ref' AS ref
           FROM jsonb_array_elements(:'msgs'::jsonb) WITH ORDINALITY AS a (m, n))
SELECT jsonb_build_object(
  'runs', (SELECT count(*) FROM r),
  'posts', (SELECT count(*) FROM posts),
  'resends', (SELECT count(*) FROM posts WHERE kind = 'resend'),
  'refs', (SELECT coalesce(jsonb_agg(DISTINCT exchange_id), '[]') FROM posts WHERE exchange_id IS NOT NULL),
  'wrong_posts', (SELECT coalesce(jsonb_agg('exchange ' || exchange_id || '''s ' || kind || ' was posted under key ' || posted
                                            || ', the exchange''s key is ' || own ORDER BY id), '[]')
                    FROM posts WHERE own IS NOT NULL AND posted <> own),
  'wrong_messages', (SELECT coalesce(jsonb_agg(m.host || ' took a request for the clinic''s exchange ' || m.ref || ' under key '
                                               || m.key || ', the exchange''s key is ' || e.exchange_key ORDER BY m.n), '[]')
                       FROM msgs m JOIN exchanges e
                         ON e.direction = 'out' AND e.id = CASE WHEN m.ref ~ '^[0-9]{1,9}$' THEN m.ref::integer END
                      WHERE e.exchange_key::text <> m.key),
  'answered', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', id, 'key', exchange_key, 'state', state,
                                                            'accepted_for', accepted_for) ORDER BY id), '[]')
                 FROM exchanges WHERE direction = 'out' AND answered_at > :'since'::timestamptz))
SQL
) || { printf '%s\n' "$clinic"; exit 2; }
# The centres' side: no exchange of the clinic held under two keys, and each
# answered exchange holding the answer its centre gave on that key.
v=$(q - "$DB" -v clinic="$clinic" <<'SQL'
WITH cl AS (SELECT :'clinic'::jsonb AS j),
twice AS (SELECT ref, count(*) AS n, string_agg(exchange_key::text, ', ' ORDER BY exchange_key) AS keys
            FROM centres.exchanges
           WHERE asked_by = 'customer' AND ref IN (SELECT (jsonb_array_elements_text(j->'refs'))::integer FROM cl)
           GROUP BY ref HAVING count(*) > 1),
ans AS (SELECT a.*, CASE WHEN a.state = 'declined' THEN 'declined' ELSE 'accepted' END AS verdict,
               c.answer, c.accepted_for AS their_date, c.answered_at
          FROM cl CROSS JOIN LATERAL jsonb_to_recordset(cl.j->'answered') AS a (id integer, key uuid, state text, accepted_for date)
          LEFT JOIN LATERAL (SELECT x.answer, x.accepted_for, x.answered_at FROM centres.exchanges x
                              WHERE x.asked_by = 'customer' AND x.exchange_key = a.key LIMIT 1) c ON true),
w AS (
  SELECT 1 AS grp, t.n AS k, t.x AS what FROM cl CROSS JOIN LATERAL jsonb_array_elements_text(cl.j->'wrong_posts') WITH ORDINALITY AS t (x, n)
  UNION ALL
  SELECT 2, ref, 'the centre holds the clinic''s exchange ' || ref || ' under ' || n || ' keys (' || keys || ')' FROM twice
  UNION ALL
  SELECT 3, t.n, t.x FROM cl CROSS JOIN LATERAL jsonb_array_elements_text(cl.j->'wrong_messages') WITH ORDINALITY AS t (x, n)
  UNION ALL
  SELECT 4, id,
         CASE WHEN answered_at IS NULL THEN
                'exchange ' || id || ' (key ' || key || ') is recorded as ' || state || ', and its centre never answered it'
              ELSE 'exchange ' || id || ' (key ' || key || ') is recorded as ' || verdict || ' ' || coalesce(accepted_for::text, '')
                   || ', its centre answered ' || coalesce(answer, '') || ' ' || coalesce(their_date::text, '') END
    FROM ans
   WHERE answered_at IS NULL OR answer IS DISTINCT FROM verdict OR (verdict = 'accepted' AND their_date IS DISTINCT FROM accepted_for))
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM w) THEN (
    SELECT '1|EX3 present: ' || what
           || CASE WHEN (SELECT count(*) FROM w) > 1 THEN ' (' || (SELECT count(*) FROM w) || ' such since ' || :'since' || ')'
                   ELSE '' END
      FROM w ORDER BY grp, k LIMIT 1)
  WHEN (j->>'runs')::integer > 0 AND (j->>'posts')::integer + jsonb_array_length(j->'answered') > 0 THEN
    '0|EX3 fixed: ' || (j->>'runs') || ' runs of sync-exchanges and chase-exchanges since ' || :'since' || ': '
    || (j->>'posts') || ' requests posted (' || (j->>'resends') || ' resends) under their exchange''s key, each held once, '
    || jsonb_array_length(j->'answered') || ' answers recorded on their own exchange'
  ELSE '3|remaining=300 ' || (j->>'runs') || ' runs of sync-exchanges and chase-exchanges since ' || :'since'
       || ', no request posted and no answer recorded since: nothing to judge yet'
END FROM cl
SQL
) || { printf '%s\n' "$v"; exit 2; }
verdict "$v"
