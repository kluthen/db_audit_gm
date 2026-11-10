#!/bin/sh
# EX2 the inbound trip, end to end (vet-centre-exchanges; v0.5 master spec
# 12.1 item 6, 12.2 purpose 4; clinic-purposes.md 8; spec D440): every
# request a centre posted since the judged moment is recorded in exchanges
# at once, and its answer and its report reach the centre within 10 minutes
# of the vets' decision and report. Judged end to end, from the centre's
# side: on the trace after the fix; the backlog a fault leaves is the answer
# key's, never this check's.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (no runner here: capture W4 item 0, "Where a check runs"). It
# reads the centres' stub in partners through check-psql and the clinic's
# record as gm_check through check-psql --node records; it never runs a job
# and never calls an endpoint. A table read with row security needs the GM's
# read policy (spec D432): gone, the check exits 2.
#
# - A request: a centres.exchanges row asked by a centre, requested since
#   the judged moment. Recorded: the clinic holds an inbound exchange under
#   its key. clinic-api's 2xx with nothing recorded is present at once (a
#   request lost silently); otherwise 10 minutes from the request.
# - An answer: an inbound exchange the vets answered (accepted, declined)
#   since the judged moment; it reaches the centre of its site, with the
#   same answer and date, within 10 minutes of answered_at. A report: one
#   reported since then; its centre's reported_at within 10 minutes of the
#   vets' reported_at.
# - Exit 1: a leg late, missing past its 10 minutes, or answered wrong.
#   Exit 0: every leg older than two cycles done, at least one (the
#   witness). Exit 3 otherwise, remaining= until the oldest pending leg's
#   10 minutes. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
INVARIANT=EX2
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

guard - "$DB" centres.exchanges
guard "$CLINIC_NODE" "$CLINIC_DB" exchanges
# The centres' own requests since the judged moment, by key.
keys=$(q - "$DB" <<'SQL'
SELECT coalesce(string_agg(exchange_key::text, ',' ORDER BY requested_at, exchange_key), '')
  FROM centres.exchanges WHERE asked_by = 'centre' AND requested_at > :'since'::timestamptz
SQL
) || { printf '%s\n' "$keys"; exit 2; }
# The clinic's side: which of those requests it holds, and the inbound
# exchanges its vets answered or reported since the judged moment.
clinic=$(q "$CLINIC_NODE" "$CLINIC_DB" -v keys="$keys" <<'SQL'
SELECT jsonb_build_object(
  'held', coalesce((SELECT jsonb_agg(e.exchange_key) FROM exchanges e
                     WHERE e.direction = 'in' AND e.exchange_key = ANY (string_to_array(:'keys', ',')::uuid[])), '[]'),
  'done', coalesce((
    SELECT jsonb_agg(jsonb_build_object('id', e.id, 'key', e.exchange_key, 'site', e.partner_site_id, 'state', e.state,
                                        'accepted_for', e.accepted_for, 'answered', e.answered_at,
                                        'reported', e.reported_at) ORDER BY e.id)
      FROM exchanges e
     WHERE e.direction = 'in' AND (e.answered_at > :'since'::timestamptz OR e.reported_at > :'since'::timestamptz)), '[]'))
SQL
) || { printf '%s\n' "$clinic"; exit 2; }
# Each leg of the inbound trip, against what the centre holds.
v=$(q - "$DB" -v clinic="$clinic" <<'SQL'
WITH cl AS (SELECT :'clinic'::jsonb AS j),
held AS (SELECT (jsonb_array_elements_text(j->'held'))::uuid AS key FROM cl),
done AS (SELECT x.* FROM cl CROSS JOIN LATERAL jsonb_to_recordset(cl.j->'done')
                AS x (id integer, key uuid, site integer, state text, accepted_for date, answered timestamptz, reported timestamptz)),
asked AS (SELECT exchange_key AS key, hostname, requested_at, posted_at FROM centres.exchanges
           WHERE asked_by = 'centre' AND requested_at > :'since'::timestamptz),
req AS (
  SELECT 1 AS grp, a.requested_at AS k1, 0 AS k2, a.key::text AS k3, 'request' AS what, a.requested_at AS at,
         (h.key IS NOT NULL) AS handled,
         CASE
           WHEN a.posted_at IS NOT NULL AND h.key IS NULL THEN
             a.hostname || '''s request ' || a.key || ' was taken by clinic-api at '
             || to_char(a.posted_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ', and the clinic holds no exchange under its key'
           WHEN h.key IS NOT NULL AND a.posted_at > a.requested_at + interval '10 minutes' THEN
             a.hostname || '''s request ' || a.key || ' recorded ' || floor(extract(epoch FROM a.posted_at - a.requested_at) / 60)
             || ' minutes after it was made'
           WHEN h.key IS NULL AND now() > a.requested_at + interval '10 minutes' THEN
             a.hostname || '''s request ' || a.key || ', made at ' || to_char(a.requested_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
             || ', not recorded by the clinic ' || floor(extract(epoch FROM now() - a.requested_at) / 60) || ' minutes later'
         END AS wrong
    FROM asked a LEFT JOIN (SELECT DISTINCT key FROM held) h ON h.key = a.key),
d2 AS (
  SELECT d.*, w.want, s.hostname AS host, s.answer, s.accepted_for AS their_date, s.answered_at AS their_answer_at,
         s.reported_at AS their_report_at, CASE WHEN d.state = 'declined' THEN 'declined' ELSE 'accepted' END AS verdict,
         'exchange ' || d.id || ' (key ' || d.key || ')' AS ex
    FROM done d
   CROSS JOIN LATERAL (SELECT CASE d.site WHEN 2 THEN 'aldermoor-central' WHEN 3 THEN 'aldermoor-south'
                                          ELSE 'aldermoor-abroad' END AS want) w
    LEFT JOIN LATERAL (SELECT x.* FROM centres.exchanges x WHERE x.asked_by = 'centre' AND x.exchange_key = d.key
                        ORDER BY (x.hostname = w.want) DESC LIMIT 1) s ON true),
legs AS (
  SELECT 2 AS grp, NULL::timestamptz AS k1, id AS k2, '1' AS k3, 'answer' AS what, coalesce(answered, reported) AS at,
         false AS handled, ex || ' is site ' || site || '''s, ' || want || '''s, but ' || host || ' holds it' AS wrong
    FROM d2 WHERE host IS NOT NULL AND host <> want
  UNION ALL
  SELECT 2, NULL, id, '1', 'answer', answered,
         their_answer_at IS NOT NULL AND answer IS NOT DISTINCT FROM verdict
           AND (verdict = 'declined' OR their_date IS NOT DISTINCT FROM accepted_for),
         CASE
           WHEN their_answer_at IS NULL THEN
             CASE WHEN now() > answered + interval '10 minutes' THEN
               ex || ' answered by the vets at ' || to_char(answered AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ', no answer at '
               || want || ' ' || floor(extract(epoch FROM now() - answered) / 60) || ' minutes later' END
           WHEN answer IS DISTINCT FROM verdict OR (verdict = 'accepted' AND their_date IS DISTINCT FROM accepted_for) THEN
             ex || ': the vets answered ' || verdict || ' ' || coalesce(accepted_for::text, '') || ', ' || want || ' holds '
             || coalesce(answer, '') || ' ' || coalesce(their_date::text, '')
           WHEN their_answer_at > answered + interval '10 minutes' THEN
             ex || ': its answer reached ' || want || ' ' || floor(extract(epoch FROM their_answer_at - answered) / 60)
             || ' minutes after the vets'' decision'
         END
    FROM d2 WHERE NOT (host IS NOT NULL AND host <> want) AND answered > :'since'::timestamptz
  UNION ALL
  SELECT 2, NULL, id, '2', 'report', reported, their_report_at IS NOT NULL,
         CASE
           WHEN their_report_at IS NULL THEN
             CASE WHEN now() > reported + interval '10 minutes' THEN
               ex || ' reported by the vets at ' || to_char(reported AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ', no report at '
               || want || ' ' || floor(extract(epoch FROM now() - reported) / 60) || ' minutes later' END
           WHEN their_report_at > reported + interval '10 minutes' THEN
             ex || ': its report reached ' || want || ' ' || floor(extract(epoch FROM their_report_at - reported) / 60)
             || ' minutes after the vets'''
         END
    FROM d2 WHERE NOT (host IS NOT NULL AND host <> want) AND reported > :'since'::timestamptz AND state = 'reported'),
items AS (SELECT * FROM req UNION ALL SELECT * FROM legs),
bad AS (SELECT * FROM items WHERE wrong IS NOT NULL),
old AS (SELECT * FROM items WHERE at <= now() - interval '10 minutes')
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM bad) THEN (
    SELECT '1|EX2 present: ' || wrong
           || CASE WHEN (SELECT count(*) FROM bad) > 1
                   THEN ' (' || (SELECT count(*) FROM bad) || ' legs of the inbound trip not done in time since ' || :'since' || ')'
                   ELSE '' END
      FROM bad ORDER BY grp, k1, k2, k3 LIMIT 1)
  WHEN EXISTS (SELECT 1 FROM old) AND NOT EXISTS (SELECT 1 FROM old WHERE NOT handled) THEN
    '0|EX2 fixed: ' || (SELECT count(*) FROM old WHERE what = 'request') || ' centres'' requests recorded at once, '
    || (SELECT count(*) FROM old WHERE what = 'answer') || ' answers and ' || (SELECT count(*) FROM old WHERE what = 'report')
    || ' reports at their centres within 10 minutes, since ' || :'since' || ' ('
    || ((SELECT count(*) FROM items) - (SELECT count(*) FROM old)) || ' younger)'
  WHEN EXISTS (SELECT 1 FROM items) THEN (
    SELECT '3|remaining=' || greatest(1, floor(extract(epoch FROM at + interval '10 minutes' - now()))::integer + 1)
           || ' ' || (SELECT count(*) FROM items) || ' legs of the inbound trip since ' || :'since' || '; a ' || what || ' of '
           || to_char(at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ' is still to be judged'
      FROM items ORDER BY handled, grp, k1, k2, k3 LIMIT 1)
  ELSE '3|remaining=600 no centre''s request, and no inbound exchange answered or reported, since ' || :'since'
END
SQL
) || { printf '%s\n' "$v"; exit 2; }
verdict "$v"
