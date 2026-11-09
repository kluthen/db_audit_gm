#!/bin/sh
# SO2 one send_key per send-out (vet-lab-send-outs, v0.5 master spec 12.2
# purpose 3; clinic-purposes.md section 7): one send_key per send-out, kept
# on every retry: no test has two external accessions. Judged by runs.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`,
# with CHECK_SINCE as given: the external lab's stub's received send-outs
# (xlab.orders, partners) through check-psql, the lab's send-outs through
# check-psql --node, both as gm_check (capture W4 item 0, "Where a check
# runs"). It never posts anything.
#
# - Exit 1: a test (the lab's accession, the sample's label and the external
#   code) the stub took under two send_keys, one of them since CHECK_SINCE
#   (two external accessions); or a test the lab packed twice since then.
#   Exit 0: none, with a send-out the stub took since CHECK_SINCE (the
#   witness). Exit 3 otherwise, remaining= 15 minutes (the chase's cadence).
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
    *) echo "SO2 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
got=$("$CHECK_PSQL" -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1 <<'SQL'
WITH r AS (SELECT * FROM xlab.orders WHERE received_at > :'since'::timestamptz),
dup AS (
  SELECT o.lab_accession, o.label, o.test_code, count(*) AS n, string_agg(o.accession, ' ' ORDER BY o.accession) AS acc
    FROM xlab.orders AS o
   WHERE (o.lab_accession, o.label, o.test_code) IN (SELECT lab_accession, label, test_code FROM r)
   GROUP BY o.lab_accession, o.label, o.test_code HAVING count(*) > 1)
SELECT (SELECT count(*) FROM r) || '|' || (SELECT count(*) FROM dup) || '|'
       || coalesce((SELECT 'test ' || test_code || ' on sample ' || label || ' of order ' || lab_accession
                           || ' taken under ' || n || ' send_keys (external accessions ' || acc || ')'
                      FROM dup ORDER BY lab_accession, label LIMIT 1), '-')
SQL
) || { echo "SO2 cannot be judged: $(printf '%s' "$got" | head -n 1)"; exit 2; }
IFS='|' read -r n dups first <<EOF2
$got
EOF2
if [ "$dups" -gt 0 ]; then
    echo "SO2 present: $first ($dups tests with two external accessions since $CHECK_SINCE)"
    exit 1
fi
out=$("$CHECK_PSQL" --node "$LAB_NODE" -d "$LAB_DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1 <<'SQL'
SELECT count(*) || '|' || coalesce(min('test ' || order_test_id || ' packed ' || n || ' times'), '-')
  FROM (SELECT order_test_id, count(*) AS n FROM lab_send_outs
         WHERE order_test_id IN (SELECT order_test_id FROM lab_send_outs WHERE packed_at > :'since'::timestamptz)
         GROUP BY order_test_id HAVING count(*) > 1) AS d
SQL
) || { echo "SO2 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
twice=${out%%|*}
if [ "$twice" -gt 0 ]; then
    echo "SO2 present: ${out#*|} ($twice tests packed twice since $CHECK_SINCE)"
    exit 1
fi
if [ "$n" -gt 0 ]; then
    echo "SO2 fixed: $n send-outs taken by the external lab since $CHECK_SINCE, each test under one send_key"
    exit 0
fi
echo "remaining=900 no send-out taken by the external lab since $CHECK_SINCE"
exit 3
