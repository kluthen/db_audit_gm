#!/bin/sh
# SO4 end to end, the answer's leg (vet-lab-send-outs, v0.5 master spec 12.2
# purpose 3; clinic-purposes.md section 7): every answer the external lab
# posted since the judged moment is recorded against its send-out, and its
# test released by the end of the next release round. Judged end to end: on
# the trace after the fix, wherever it was made; the send-outs a fault left
# stuck before it are the answer key's backlog.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`,
# with CHECK_SINCE as given: the answers the external lab's stub posted
# (xlab.orders.answered_at, partners: set once lab-api took the answer)
# through check-psql, the lab's send-outs and tests through check-psql
# --node, both as gm_check (capture W4 item 0, "Where a check runs"). It
# never posts anything.
#
# - The deadline: the next release round after the answer (11:00 every day,
#   14:00 and 18:00 Monday to Saturday, the lab's local time from
#   lab_settings), plus 10 minutes, the round's end.
# - Exit 1: an answer not recorded (its send-out not resulted) 5 minutes
#   after it was posted; or its test not released by its deadline.
#   Exit 0: none, with an answer posted since CHECK_SINCE, recorded and its
#   test released (the witness). Exit 3 otherwise, remaining= until the
#   first pending deadline, or 10 minutes (the stub's answering cadence).
#   Exit 2: it cannot judge.
#
# The node has no Python: the verdict is computed in SQL.
#
# Written for the clinic's names (the constants below); the GM adapts them
# as it copies the purpose.
set -u
DB=partners                          # the partners' database, on this node
LAB_NODE=lab                         # the target part: node, database
LAB_DB=lab
CHECK_PSQL=/usr/local/lib/gm/check-psql
case ${CHECK_SINCE:-} in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) echo "SO4 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
list=$("$CHECK_PSQL" -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1 <<'SQL'
SELECT coalesce(string_agg(send_key || '@' || extract(epoch FROM answered_at), ',' ORDER BY answered_at, send_key), '')
  FROM xlab.orders WHERE answered_at > :'since'::timestamptz
SQL
) || { echo "SO4 cannot be judged: $(printf '%s' "$list" | head -n 1)"; exit 2; }
if [ -z "$list" ]; then
    echo "remaining=600 no answer posted by the external lab since $CHECK_SINCE"
    exit 3
fi
out=$("$CHECK_PSQL" --node "$LAB_NODE" -d "$LAB_DB" -XAtq -v ON_ERROR_STOP=1 -v list="$list" 2>&1 <<'SQL'
WITH env AS (SELECT utc_offset_hours AS off FROM lab_settings),
a AS (
  SELECT split_part(x, '@', 1)::uuid AS key, to_timestamp(split_part(x, '@', 2)::float8) AS answered
    FROM unnest(string_to_array(:'list', ',')) AS x),
m AS (
  SELECT a.key, a.answered, so.status = 'resulted' AS recorded, t.id AS test, t.released_at,
         ((SELECT min(z.c) FROM (
             SELECT date_trunc('day', (a.answered AT TIME ZONE 'UTC') + env.off * interval '1 hour')
                    + dd * interval '1 day' + hh * interval '1 hour' AS c, hh
               FROM generate_series(0, 3) AS dd, unnest(ARRAY[11, 14, 18]) AS hh) AS z
            WHERE z.c > (a.answered AT TIME ZONE 'UTC') + env.off * interval '1 hour'
              AND (z.hh = 11 OR extract(isodow FROM z.c) <= 6))
          - env.off * interval '1 hour') AT TIME ZONE 'UTC' + interval '10 minutes' AS deadline
    FROM a CROSS JOIN env
    LEFT JOIN lab_send_outs AS so ON so.send_key = a.key LEFT JOIN lab_order_tests AS t ON t.id = so.order_test_id),
bad AS (
  SELECT answered, CASE
           WHEN NOT coalesce(recorded, false) THEN 'the answer to send-out ' || key || ' posted at '
                || to_char(answered AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') || ' not recorded against it'
           ELSE 'test ' || test || ', answered at ' || to_char(answered AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
                || ', not released by the round ending '
                || to_char(deadline AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END AS what
    FROM m
   WHERE (NOT coalesce(recorded, false) AND now() > answered + interval '5 minutes')
      OR (coalesce(recorded, false) AND coalesce(released_at, 'infinity') > deadline AND now() > deadline))
SELECT (SELECT count(*) FROM m) || '|' || (SELECT count(*) FROM bad) || '|'
       || (SELECT count(*) FROM m WHERE recorded AND released_at <= deadline) || '|'
       || coalesce((SELECT floor(extract(epoch FROM min(deadline) - now()))::integer + 1 FROM m
                     WHERE recorded AND released_at IS NULL AND now() <= deadline), 600) || '|'
       || coalesce((SELECT what FROM bad ORDER BY answered LIMIT 1), '-')
SQL
) || { echo "SO4 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
IFS='|' read -r n bad good wait first <<EOF2
$out
EOF2
if [ "$bad" -gt 0 ]; then
    echo "SO4 present: $first ($bad answers since $CHECK_SINCE)"
    exit 1
fi
if [ "$good" -gt 0 ]; then
    echo "SO4 fixed: $n answers posted by the external lab since $CHECK_SINCE recorded, $good tests released by their round"
    exit 0
fi
echo "remaining=$wait $n answers posted since $CHECK_SINCE, none released yet"
exit 3
