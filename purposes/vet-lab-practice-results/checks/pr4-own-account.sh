#!/bin/sh
# PR4 each delivery to its own account (vet-lab-practice-results, v0.5 master
# spec 12.2 purpose 2; clinic-purposes.md section 6; lab rule 10): each
# delivery goes to its own order's account's callback, never another
# practice's. Judged by runs.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`,
# with CHECK_SINCE as given: the practices' stub's received deliveries
# (practices.deliveries, partners) through check-psql, the lab's orders and
# lab_callbacks through check-psql --node, both as gm_check (capture W4 item
# 0, "Where a check runs"; access model 8, the partners' side through the
# GM's own plane). It never posts anything.
#
# - The deliveries the stub took or took again since CHECK_SINCE: each
#   one's account must be the account of the lab order its accession names,
#   and the lab's attempts under its delivery_key must be for that order.
# - Exit 1: a delivery received for another account than its order's (or for
#   an order the lab does not hold), or under a key the lab used for another
#   order. Exit 0: none, with a delivery received since CHECK_SINCE (the
#   witness). Exit 3 otherwise, remaining= a minute (the job's cadence).
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
    *) echo "PR4 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
got=$("$CHECK_PSQL" -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1 <<'SQL'
SELECT count(*) || '|' || coalesce(string_agg(delivery_key || ':' || account_id || ':' || accession, ','
                                              ORDER BY last_at, delivery_key), '')
  FROM practices.deliveries WHERE last_at > :'since'::timestamptz
SQL
) || { echo "PR4 cannot be judged: $(printf '%s' "$got" | head -n 1)"; exit 2; }
n=${got%%|*}
list=${got#*|}
if [ "$n" -eq 0 ]; then
    echo "remaining=60 no delivery received by the practices' stub since $CHECK_SINCE"
    exit 3
fi
out=$("$CHECK_PSQL" --node "$LAB_NODE" -d "$LAB_DB" -XAtq -v ON_ERROR_STOP=1 -v list="$list" 2>&1 <<'SQL'
WITH d AS (
  SELECT split_part(x, ':', 1) AS key, split_part(x, ':', 2)::integer AS account,
         split_part(x, ':', 3)::integer AS accession
    FROM unnest(string_to_array(:'list', ',')) AS x),
bad AS (
  SELECT 'delivery ' || d.key || ' of order ' || d.accession || ' received for account ' || d.account
         || CASE WHEN o.id IS NULL THEN ', an order the lab does not hold'
                 ELSE ', the order being account ' || o.account_id || '''s' END AS what
    FROM d LEFT JOIN lab_orders AS o ON o.id = d.accession
   WHERE o.account_id IS DISTINCT FROM d.account
  UNION ALL
  SELECT DISTINCT 'delivery ' || d.key || ' received for order ' || d.accession
         || ', the lab posting that key for order ' || c.order_id
    FROM d JOIN lab_callbacks AS c ON c.delivery_key = d.key
   WHERE c.order_id <> d.accession)
SELECT count(*) || '|' || coalesce(min(what), '-') FROM bad
SQL
) || { echo "PR4 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
bad=${out%%|*}
first=${out#*|}
if [ "$bad" -gt 0 ]; then
    echo "PR4 present: $first ($bad deliveries to another practice since $CHECK_SINCE)"
    exit 1
fi
echo "PR4 fixed: $n deliveries received by the practices' stub since $CHECK_SINCE, each for its own order's account"
exit 0
