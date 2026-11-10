#!/bin/sh
# EX1 every outbound exchange received in time (vet-centre-exchanges; v0.5
# master spec 12.2 purpose 4; clinic-purposes.md 8): every outbound exchange
# the clinic recorded since the judged moment is received by its centre (the
# hostname of its site: 2 aldermoor-central, 3 aldermoor-south, 4 to 6
# aldermoor-abroad) within 10 minutes of its requested_at. A deadline
# invariant: it judges triggers, not runs.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (no runner here: capture W4 item 0, "Where a check runs"). It
# reads the centres' stub in partners through check-psql and the clinic's
# record as gm_check through check-psql --node records; it never runs a job
# and never calls an endpoint. A table read with row security needs the GM's
# read policy (spec D432): gone, the check exits 2.
#
# - A trigger: an exchange of direction out requested since the judged
#   moment. Handled: its centre's row in centres.exchanges, under the same
#   exchange_key, received (received_at) within 10 minutes.
# - Exit 1: a trigger past its deadline not received by its centre (another
#   centre holding it counts as not received), or received late. Exit 0:
#   every trigger older than two cycles (2 x 5 minutes) handled, at least
#   one such trigger (the witness). Exit 3 otherwise, remaining= until the
#   oldest pending trigger reaches its deadline. Exit 2: it cannot judge.
#
# Written for the clinic's names (the constants below: nodes records, lab,
# partners-db, the centres' hostnames by site); the GM adapts them as it
# copies the purpose (gm.md, "Names to adapt").
INVARIANT=EX1
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

guard "$CLINIC_NODE" "$CLINIC_DB" exchanges
guard - "$DB" centres.exchanges
# The clinic's outbound exchanges requested since the judged moment.
out=$(q "$CLINIC_NODE" "$CLINIC_DB" <<'SQL'
SELECT coalesce(jsonb_agg(jsonb_build_object('id', e.id, 'key', e.exchange_key, 'site', e.partner_site_id,
                                             'requested', e.requested_at) ORDER BY e.requested_at, e.id), '[]')
  FROM exchanges e WHERE e.direction = 'out' AND e.requested_at > :'since'::timestamptz
SQL
) || { printf '%s\n' "$out"; exit 2; }
# Against what each centre received (a trigger past its 10 minutes not
# received by the centre of its site, or received late: present).
v=$(q - "$DB" -v out="$out" <<'SQL'
WITH o AS (SELECT * FROM jsonb_to_recordset(:'out'::jsonb) AS x (id integer, key uuid, site integer, requested timestamptz)),
u AS (
  SELECT o.id, o.key, o.requested, w.want,
         CASE WHEN c.hostname = w.want THEN c.received_at END AS got,
         CASE WHEN c.hostname <> w.want THEN c.hostname END AS other
    FROM o
   CROSS JOIN LATERAL (SELECT CASE o.site WHEN 2 THEN 'aldermoor-central' WHEN 3 THEN 'aldermoor-south'
                                          ELSE 'aldermoor-abroad' END AS want) w
    LEFT JOIN LATERAL (SELECT x.hostname, x.received_at FROM centres.exchanges x
                        WHERE x.asked_by = 'customer' AND x.exchange_key = o.key
                        ORDER BY (x.hostname = w.want) DESC LIMIT 1) c ON true),
late AS (SELECT * FROM u WHERE CASE WHEN got IS NOT NULL THEN got > requested + interval '10 minutes'
                                    ELSE now() > requested + interval '10 minutes' END),
old AS (SELECT * FROM u WHERE requested <= now() - interval '10 minutes'),
pend AS (SELECT * FROM u ORDER BY (got IS NOT NULL), requested, id LIMIT 1)
SELECT CASE
  WHEN EXISTS (SELECT 1 FROM late) THEN (
    SELECT '1|EX1 present: exchange ' || id || ' (key ' || key || '), requested at '
           || to_char(requested AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ', '
           || CASE WHEN got IS NOT NULL THEN 'received ' || floor(extract(epoch FROM got - requested) / 60)
                                             || ' minutes after its request'
                   WHEN other IS NOT NULL THEN 'held by ' || other || ', not by ' || want || ', '
                                               || floor(extract(epoch FROM now() - requested) / 60) || ' minutes after its request'
                   ELSE 'not received by ' || want || ' ' || floor(extract(epoch FROM now() - requested) / 60)
                        || ' minutes after its request' END
           || CASE WHEN (SELECT count(*) FROM late) > 1
                   THEN ' (' || (SELECT count(*) FROM late) || ' outbound exchanges not received in time since ' || :'since' || ')'
                   ELSE '' END
      FROM late ORDER BY requested, id LIMIT 1)
  WHEN EXISTS (SELECT 1 FROM old) AND NOT EXISTS (SELECT 1 FROM old WHERE got IS NULL) THEN
    '0|EX1 fixed: ' || (SELECT count(*) FROM old) || ' outbound exchanges requested since ' || :'since'
    || ' at least two cycles ago, each received by its centre within 10 minutes ('
    || ((SELECT count(*) FROM u) - (SELECT count(*) FROM old)) || ' younger)'
  WHEN EXISTS (SELECT 1 FROM u) THEN (
    SELECT '3|remaining=' || greatest(1, floor(extract(epoch FROM requested + interval '10 minutes' - now()))::integer + 1)
           || ' ' || (SELECT count(*) FROM u) || ' outbound exchanges requested since ' || :'since' || '; exchange ' || id
           || ', requested at ' || to_char(requested AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ', is still to be judged'
      FROM pend)
  ELSE '3|remaining=600 no outbound exchange requested since ' || :'since'
END
SQL
) || { printf '%s\n' "$v"; exit 2; }
verdict "$v"
