#!/bin/sh
# SO3 the catalogue's fields only (vet-lab-send-outs, v0.5 master spec 12.2
# purpose 3; clinic-purposes.md section 7; lab rule 11): a send-out carries
# the accession, the sample's label, the external code, the animal's species,
# sex and age; no owner, client, natural identifier or clinical note. Judged
# by runs.
#
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`,
# with CHECK_SINCE as given: what the external lab's stub kept of each
# send-out (xlab.orders, partners) through check-psql, the lab's send-outs,
# samples, orders and catalogue through check-psql --node, both as gm_check
# (capture W4 item 0, "Where a check runs"). It never posts anything.
#
# - Each send-out the stub took since CHECK_SINCE, by its send_key, against
#   the lab: its accession the order's id, its label the sample's, its code
#   the test's external code, species and sex the order's, its age the
#   animal's whole years at the send (one year either way, a birthday
#   between).
# - Exit 1: a send_key the lab never packed, or a field other than the
#   catalogue's value (an identifier, a name or a note in its place).
#   Exit 0: none, with a send-out taken since CHECK_SINCE (the witness).
#   Exit 3 otherwise, remaining= 15 minutes. Exit 2: it cannot judge.
#   The stub keeps those fields only: a key beyond them is dropped on its
#   side and never reaches this check (gm.md).
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
    *) echo "SO3 cannot be judged: CHECK_SINCE is not YYYY-MM-DDTHH:MM:SSZ"; exit 2 ;;
esac
rows=$("$CHECK_PSQL" -d "$DB" -XAtq -v ON_ERROR_STOP=1 -v since="$CHECK_SINCE" 2>&1 <<'SQL'
SELECT coalesce(json_agg(json_build_object('send_key', send_key, 'lab_accession', lab_accession, 'label', label,
                                           'test_code', test_code, 'species', species, 'sex', sex, 'age', age,
                                           'received_at', received_at) ORDER BY received_at, send_key), '[]')
  FROM xlab.orders WHERE received_at > :'since'::timestamptz
SQL
) || { echo "SO3 cannot be judged: $(printf '%s' "$rows" | head -n 1)"; exit 2; }
out=$("$CHECK_PSQL" --node "$LAB_NODE" -d "$LAB_DB" -XAtq -v ON_ERROR_STOP=1 -v rows="$rows" 2>&1 <<'SQL'
WITH r AS (
  SELECT * FROM jsonb_to_recordset(:'rows'::jsonb)
           AS x (send_key uuid, lab_accession integer, label text, test_code text, species text, sex text,
                 age integer, received_at timestamptz)),
m AS (
  SELECT r.*, so.id AS so_id, t.order_id, s.label AS s_label, x.external_code, o.species AS o_species,
         o.sex AS o_sex,
         CASE WHEN o.born_on IS NOT NULL THEN extract(year FROM age(r.received_at::date, o.born_on))::integer END
           AS o_age
    FROM r LEFT JOIN lab_send_outs AS so ON so.send_key = r.send_key
    LEFT JOIN lab_order_tests AS t ON t.id = so.order_test_id LEFT JOIN lab_samples AS s ON s.id = t.sample_id
    LEFT JOIN lab_orders AS o ON o.id = t.order_id LEFT JOIN lab_tests AS x ON x.id = t.test_id),
bad AS (
  SELECT received_at, 'send-out ' || send_key || CASE
           WHEN so_id IS NULL THEN ': a send_key the lab never packed'
           WHEN lab_accession IS DISTINCT FROM order_id THEN ': accession ' || coalesce(lab_accession::text, 'none')
                || ', not its order ' || order_id
           WHEN label IS DISTINCT FROM s_label THEN ': a label that is not its sample''s'
           WHEN test_code IS DISTINCT FROM external_code THEN ': code ' || coalesce(test_code, 'none')
                || ', not the catalogue''s ' || coalesce(external_code, 'none')
           WHEN species IS DISTINCT FROM o_species THEN ': a species that is not the order''s'
           WHEN sex IS DISTINCT FROM o_sex THEN ': a sex that is not the order''s'
           ELSE ': an age that is not the animal''s' END AS what
    FROM m
   WHERE so_id IS NULL OR lab_accession IS DISTINCT FROM order_id OR label IS DISTINCT FROM s_label
      OR test_code IS DISTINCT FROM external_code OR species IS DISTINCT FROM o_species
      OR sex IS DISTINCT FROM o_sex OR (age IS NULL) <> (o_age IS NULL) OR abs(age - o_age) > 1)
SELECT (SELECT count(*) FROM r) || '|' || (SELECT count(*) FROM bad) || '|'
       || coalesce((SELECT what FROM bad ORDER BY received_at LIMIT 1), '-')
SQL
) || { echo "SO3 cannot be judged: $(printf '%s' "$out" | head -n 1)"; exit 2; }
IFS='|' read -r n bad first <<EOF2
$out
EOF2
if [ "$bad" -gt 0 ]; then
    echo "SO3 present: $first ($bad send-outs beyond the catalogue's fields since $CHECK_SINCE)"
    exit 1
fi
if [ "$n" -gt 0 ]; then
    echo "SO3 fixed: $n send-outs taken by the external lab since $CHECK_SINCE, each with the catalogue's fields only"
    exit 0
fi
echo "remaining=900 no send-out taken by the external lab since $CHECK_SINCE"
exit 3
