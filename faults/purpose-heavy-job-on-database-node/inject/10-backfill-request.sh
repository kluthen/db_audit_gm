#!/bin/sh
# Plants purpose-heavy-job-on-database-node's incident (master spec 16.3,
# step 2): the one-off backfill request, a row of rpt.sales_detail_backfills
# in $FAULT_DATABASE asking the nightly roll-up to recompute the last
# $FAULT_DAYS days. Nothing runs the job: its next scheduled run takes the
# request and is killed for memory. Its requested_at is the planting moment,
# which the sealed check reads. Idempotent: a request already there, taken
# or not, is left as it is and none is added (the incident is never planted
# twice in a game). Fails if the table does not exist (the data file's
# seed change creates it).
set -eu
case ${FAULT_DAYS:-} in
    ''|*[!0-9]*|0*) echo "days must be a whole number of days above 0 (${FAULT_DAYS:-unset})" >&2; exit 2 ;;
esac
runuser -u postgres -- psql -X -q -v ON_ERROR_STOP=1 -d "$FAULT_DATABASE" \
    -v days="$FAULT_DAYS" <<'SQL'
INSERT INTO rpt.sales_detail_backfills (days, reason)
SELECT :days, 'formula change: recompute the sales detail of the last ' || :days || ' days'
 WHERE NOT EXISTS (SELECT FROM rpt.sales_detail_backfills);
SELECT count(*) AS n,
       to_char(min(requested_at) AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS') AS at
  FROM rpt.sales_detail_backfills \gset
\echo backfill request(s): :n, the first requested at :at UTC.
SQL
