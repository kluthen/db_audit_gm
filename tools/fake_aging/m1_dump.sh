#!/bin/sh
# M1, a fake game's database state, to CSV (v0.6 master spec 12.1; capture
# W4 item 2): one file per query, as run R's m1-fa-real-20261115T0800/.
#
# Copied from the research's prototype, research/fake-aging 10d1bc6
# `tools/research/fake_aging/m1_dump.sh` (the shop's `db` node and its `shop`
# database hard-coded), and generalised: the scenario, the playground, the
# node and the database are arguments; a query naming tables the database
# lacks (the shop's orders, deliveries, order statuses and ledger) writes no
# file; the schema filters read every non-system schema, not `public` only.
#
# Usage:
#   sh tools/fake_aging/m1_dump.sh <scenario-dir> --playground <pg> --node <db node>
#       --database <db> <out-dir>
#
# Read-only: every query runs as `postgres` on the node, through
# `tools/gmctl exec`, in a session with default_transaction_read_only on and
# unseen as the fill's (no statement statistics, no statement log, no
# pgaudit); nothing is created. Writes <out-dir>/<query>.csv, all.txt (the
# raw output) and meta.txt (scenario, playground, node, database, read at).
#
# Exit status: 0 done; 1 the node could not be read; 2 usage.
set -eu

usage() {
    echo "usage: sh tools/fake_aging/m1_dump.sh <scenario-dir> --playground <pg> --node <db node> --database <db> <out-dir>" >&2
    exit 2
}

REPO=$(cd "$(dirname "$0")/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
[ $# -ge 1 ] || usage
scen=$1
shift
pg= node= db= out=
while [ $# -gt 0 ]; do
    case $1 in
        --playground) [ $# -ge 2 ] || usage; pg=$2; shift 2 ;;
        --node) [ $# -ge 2 ] || usage; node=$2; shift 2 ;;
        --database) [ $# -ge 2 ] || usage; db=$2; shift 2 ;;
        -*) echo "m1_dump.sh: unknown option $1" >&2; usage ;;
        *) [ -z "$out" ] || usage; out=$1; shift ;;
    esac
done
[ -n "$pg" ] && [ -n "$node" ] && [ -n "$db" ] && [ -n "$out" ] || usage
[ -f "$scen/scenario.yaml" ] || { echo "m1_dump.sh: $scen: no scenario.yaml" >&2; exit 2; }
case $db in *[!A-Za-z0-9_]*|'') echo "m1_dump.sh: --database $db: a plain identifier" >&2; exit 2 ;; esac
mkdir -p "$out"

# The remote script: the database substituted for @DB@ (an identifier,
# checked above); each block `### <name>` then its CSV, or nothing when a
# table it reads is missing.
remote=$(cat <<'REMOTE'
set -eu
export PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=120s -c log_statement=none -c log_min_duration_statement=-1 -c log_min_error_statement=panic -c pg_stat_statements.track=none -c pgaudit.log=none -c client_min_messages=warning'
q() {   # q <name> <db> [<table>...] : the SQL on stdin; skipped when a table is missing
    name=$1 d=$2
    shift 2
    for t in "$@"; do
        [ "$(psql -X -At -d "$d" -c "SELECT to_regclass('$t') IS NOT NULL")" = t ] || { cat > /dev/null; return 0; }
    done
    echo "### $name"
    psql -X --csv -d "$d" -v ON_ERROR_STOP=1 -f - 2>&1 || echo "ERROR"
}
q meta postgres <<'SQL'
SELECT now() AS read_at, pg_postmaster_start_time() AS postmaster_start, version();
SQL
q relation_sizes @DB@ <<'SQL'
SELECT n.nspname, c.relname, c.relkind, pg_relation_size(c.oid) AS bytes,
       pg_total_relation_size(c.oid) AS total_bytes, c.relpages, c.reltuples::bigint,
       (SELECT array_to_string(c.reloptions, ',')) AS reloptions
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') AND c.relkind IN ('r', 'i', 'S', 'm')
 ORDER BY 1, 2;
SQL
q indexes @DB@ <<'SQL'
SELECT schemaname, tablename, indexname, indexdef FROM pg_indexes
 WHERE schemaname NOT IN ('pg_catalog', 'information_schema') ORDER BY 1, 2, 3;
SQL
q table_stats @DB@ <<'SQL'
SELECT relname, seq_scan, seq_tup_read, idx_scan, n_tup_ins, n_tup_upd, n_tup_del, n_tup_hot_upd,
       n_live_tup, n_dead_tup, n_mod_since_analyze, last_vacuum, last_autovacuum, last_analyze,
       last_autoanalyze, vacuum_count, autovacuum_count, analyze_count, autoanalyze_count
  FROM pg_stat_user_tables ORDER BY relname;
SQL
q bloat_estimate @DB@ <<'SQL'
-- an estimate from the planner's statistics (pgstattuple would be a write)
SELECT c.relname, c.relpages, c.reltuples::bigint,
       pg_relation_size(c.oid) AS bytes,
       (c.reltuples * (24 + 4 + coalesce(w.width, 0)))::bigint AS est_live_bytes,
       round(100 * (1 - (c.reltuples * (24 + 4 + coalesce(w.width, 0)))
             / nullif(pg_relation_size(c.oid), 0))::numeric, 1) AS est_bloat_pct,
       s.n_live_tup, s.n_dead_tup,
       round(100.0 * s.n_dead_tup / nullif(s.n_live_tup + s.n_dead_tup, 0), 1) AS dead_pct
  FROM pg_class c
  JOIN pg_stat_user_tables s ON s.relid = c.oid
  LEFT JOIN (SELECT schemaname, tablename, sum(avg_width) AS width FROM pg_stats
              GROUP BY 1, 2) w ON w.schemaname = s.schemaname AND w.tablename = c.relname
 ORDER BY 1;
SQL
q pgstattuple @DB@ <<'SQL'
SELECT extname, extversion FROM pg_extension WHERE extname IN ('pgstattuple', 'pg_stat_statements');
SQL
q xid_age postgres <<'SQL'
SELECT datname, age(datfrozenxid) AS xid_age, mxid_age(datminmxid) AS mxid_age, pg_snapshot_xmax(pg_current_snapshot()) AS current_xid
  FROM pg_database ORDER BY 1;
SQL
q table_xid_age @DB@ <<'SQL'
SELECT c.relname, age(c.relfrozenxid) AS xid_age FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast') ORDER BY 1;
SQL
q rows_per_day @DB@ orders order_lines delivery_events customers <<'SQL'
SELECT 'orders' AS tbl, placed_at::date AS day, count(*) FROM orders GROUP BY 2
UNION ALL SELECT 'order_lines', created_at::date, count(*) FROM order_lines GROUP BY 2
UNION ALL SELECT 'delivery_events', received_at::date, count(*) FROM delivery_events GROUP BY 2
UNION ALL SELECT 'customers', created_at::date, count(*) FROM customers GROUP BY 2
ORDER BY 1, 2;
SQL
q rows_per_hour_recent @DB@ orders delivery_events <<'SQL'
SELECT 'orders' AS tbl, date_trunc('hour', placed_at) AS hour, count(*) FROM orders
 WHERE placed_at > (SELECT max(placed_at) FROM orders) - interval '2 days' GROUP BY 2
UNION ALL SELECT 'delivery_events', date_trunc('hour', received_at), count(*) FROM delivery_events
 WHERE received_at > (SELECT max(received_at) FROM delivery_events) - interval '2 days' GROUP BY 2
UNION ALL SELECT 'orders_updated', date_trunc('hour', updated_at), count(*) FROM orders
 WHERE updated_at > (SELECT max(updated_at) FROM orders) - interval '2 days' GROUP BY 2
ORDER BY 1, 2;
SQL
q order_status @DB@ orders <<'SQL'
SELECT status, count(*), min(placed_at), max(placed_at), max(updated_at) FROM orders GROUP BY 1 ORDER BY 1;
SQL
q duplicates @DB@ delivery_events <<'SQL'
SELECT count(*) AS events, count(DISTINCT event_id) AS distinct_events,
       min(received_at), max(received_at) FROM delivery_events;
SQL
q ledger_daily_sales @DB@ daily_sales <<'SQL'
SELECT * FROM daily_sales ORDER BY 1;
SQL
q sequences @DB@ <<'SQL'
SELECT s.schemaname, s.sequencename, s.last_value FROM pg_sequences s ORDER BY 1, 2;
SQL
q max_timestamps @DB@ orders order_lines delivery_events customers <<'SQL'
SELECT (SELECT max(placed_at) FROM orders) AS orders_placed, (SELECT max(updated_at) FROM orders) AS orders_updated,
       (SELECT max(created_at) FROM order_lines) AS lines_created,
       (SELECT max(received_at) FROM delivery_events) AS events_received,
       (SELECT max(last_order_at) FROM customers) AS customers_last_order;
SQL
q database_stats postgres <<'SQL'
SELECT datname, numbackends, xact_commit, xact_rollback, blks_read, blks_hit, tup_inserted, tup_updated,
       tup_deleted, temp_files, temp_bytes, deadlocks, sessions, session_time, stats_reset
  FROM pg_stat_database WHERE datname IS NOT NULL ORDER BY 1;
SQL
q shared_stats postgres <<'SQL'
SELECT 'checkpointer' AS view, num_timed::text AS a, num_requested::text AS b, buffers_written::text AS c,
       stats_reset FROM pg_stat_checkpointer
UNION ALL SELECT 'bgwriter', buffers_clean::text, maxwritten_clean::text, buffers_alloc::text, stats_reset
  FROM pg_stat_bgwriter
UNION ALL SELECT 'wal', wal_records::text, wal_fpi::text, wal_bytes::text, stats_reset FROM pg_stat_wal
UNION ALL SELECT 'archiver', archived_count::text, failed_count::text, last_archived_wal, stats_reset
  FROM pg_stat_archiver;
SQL
# pg_stat_statements: in the first database holding the extension (its view
# sees every database's statements)
ss=
for d in postgres $(psql -X -At -d postgres -c "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate AND datname <> 'postgres' ORDER BY 1"); do
    s=$(psql -X -At -d "$d" -c "SELECT quote_ident(n.nspname) FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_stat_statements'")
    [ -n "$s" ] && { ss="$d $s"; break; }
done
if [ -n "$ss" ]; then
    set -- $ss
    q statements "$1" <<SQL
SELECT d.datname, s.queryid, r.rolname, s.calls, round(s.total_exec_time::numeric, 1) AS total_ms,
       round(s.mean_exec_time::numeric, 2) AS mean_ms, s.rows, s.temp_blks_written,
       left(regexp_replace(s.query, '\s+', ' ', 'g'), 160) AS query
  FROM $2.pg_stat_statements s LEFT JOIN pg_roles r ON r.oid = s.userid
  LEFT JOIN pg_database d ON d.oid = s.dbid
 ORDER BY s.calls DESC LIMIT 60;
SQL
    q statements_info "$1" <<SQL
SELECT * FROM $2.pg_stat_statements_info;
SQL
fi
q log_files postgres <<'SQL'
SELECT name, size, modification FROM pg_ls_logdir() ORDER BY name;
SQL
REMOTE
)
printf '%s\n' "$remote" | sed "s/@DB@/$db/g" \
    | $GMCTL exec "$scen" --playground "$pg" --node "$node" --user postgres > "$out/all.txt" \
    || { echo "m1_dump.sh: reading node $node failed (exit $?); its output in $out/all.txt" >&2; exit 1; }
awk -v dir="$out" '
    /^### / { if (f) close(f); f = dir "/" $2 ".csv"; printf "" > f; next }
    f { print > f }
' "$out/all.txt"
if grep -q '^ERROR$' "$out/all.txt"; then
    echo "m1_dump.sh: a query failed on node $node; see $out/all.txt" >&2
    exit 1
fi
{
    echo "scenario: $scen"
    echo "playground: $pg"
    echo "node: $node"
    echo "database: $db"
    echo "read_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$out/meta.txt"
n=$(ls "$out"/*.csv | wc -l)
echo "m1_dump.sh: $n files written to $out"
