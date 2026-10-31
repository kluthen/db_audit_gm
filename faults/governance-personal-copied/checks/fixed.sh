#!/bin/sh
# Sealed check of governance-personal-copied (v0.4 master spec 16.2, 11.6,
# 11.7, 12.6). Run as root on the database node holding the copy
# (reporting), fed to `sh -s` by gmctl check, which prepends the governance
# check set (tools/gm/governance.sh) and sets CHECK_GOVERNANCE, this script
# calling check_governance (capture W3-a items 1, 2 and 5). The live state,
# exit 0 or 1.
#
# - G1 (location) and G3 (reach), on every database node: while either is
#   broken, its first line and exit 1.
# - Both hold: the copy's own parts must be gone too (11.7, removing what
#   was copied is part of the fix), on this node in $FAULT_DATABASE: the
#   pg_cron job $FAULT_JOB (or any job whose command names the table or the
#   foreign table), the table $FAULT_TABLE, the foreign table
#   $FAULT_FOREIGN_TABLE and the foreign server $FAULT_SERVER. Any left:
#   exit 1, naming them. All gone: exit 0.
# - The set cannot judge (2, or 3 which G1 and G3 never return), or this
#   node cannot be read: exit 2.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
DB=${FAULT_DATABASE:-reporting}
JOB=${FAULT_JOB:-customer-activity}
TABLE=${FAULT_TABLE:-rpt.customer_activity}
FTABLE=${FAULT_FOREIGN_TABLE:-src.customers}
SERVER=${FAULT_SERVER:-shop_backoffice}

out=$(check_governance G1 G3); rc=$?
case $rc in
    0) ;;
    1) printf '%s\n' "$out"; exit 1 ;;
    *) echo "cannot judge: the governance check set answered $rc: $(printf '%s\n' "$out" | head -n 1)"
       exit 2 ;;
esac

psql_db() { "$CHECK_PSQL" -d "$DB" -Atq -v ON_ERROR_STOP=1 "$@"; }

# pg_cron's jobs: none when the extension is gone (dropping it drops its
# jobs). An empty cron.job is trusted only with load-data's read policy in
# place (capture W2-x): without it the GM check role reads no job at all.
cron=$(psql_db <<'SQL'
SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN 'none'
            WHEN EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'cron'
                          AND tablename = 'job' AND policyname = 'gm_check_read') THEN 'ok'
            ELSE 'missing' END
SQL
) || { echo "cannot judge: $DB cannot be read as the GM check role."; exit 2; }
jobs=
if [ "$cron" != none ]; then
    jobs=$(psql_db -v job="$JOB" -v tbl="$TABLE" -v ftbl="$FTABLE" <<'SQL'
SELECT 'the pg_cron job ' || jobname || ' (' || schedule || ', as ' || username || ')'
  FROM cron.job
 WHERE jobname = :'job'
    OR command ILIKE '%' || coalesce(nullif(split_part(:'tbl', '.', 2), ''), :'tbl') || '%'
    OR command ILIKE '%' || :'ftbl' || '%'
 ORDER BY jobid
SQL
) || { echo "cannot judge: cron.job cannot be read in $DB as the GM check role."; exit 2; }
    if [ "$cron" = missing ] && [ -z "$jobs" ]; then
        echo "cannot judge: the GM check role's read policy on cron.job is gone in $DB, so the job cannot be seen (capture W2-x)."
        exit 2
    fi
fi
objects=$(psql_db -v tbl="$TABLE" -v ftbl="$FTABLE" -v srv="$SERVER" <<'SQL'
SELECT 'the table ' || :'tbl' WHERE to_regclass(:'tbl') IS NOT NULL
UNION ALL
SELECT 'the foreign table ' || :'ftbl' WHERE to_regclass(:'ftbl') IS NOT NULL
UNION ALL
SELECT 'the foreign server ' || srvname FROM pg_foreign_server WHERE srvname = :'srv'
SQL
) || { echo "cannot judge: the copy's parts cannot be read in $DB as the GM check role."; exit 2; }
left=$(printf '%s\n%s\n' "$jobs" "$objects" | sed '/^$/d')

if [ -n "$left" ]; then
    echo "G1 and G3 hold, but the copy of personal data is not removed: $(printf '%s\n' "$left" | paste -sd ';' - | sed 's/;/; /g') still in $DB (all must go, 11.7)."
    printf '%s\n' "$left" | sed 's/^/  /'
    exit 1
fi
echo "G1 and G3 hold, and the copy's job, table, foreign table and server are gone from $DB."
exit 0
