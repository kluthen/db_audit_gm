#!/bin/sh
# Sealed check of pg-stat-statements-not-preloaded (master spec 8.1; capture
# W4, fault 4). Run as root on the database node. Exit 0 once
# pg_stat_statements is in the shared_preload_libraries IN EFFECT and its
# view answers in database postgres, 1 while it does not, 2 on an error.
#
# In effect, not in the file: the library loads only at server start, so a
# file edited (or ALTER SYSTEM run) without a restart still reads present.
set -u

pg() { runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d postgres "$@"; }

loaded=$(pg <<'SQL'
SELECT EXISTS (
  SELECT 1
    FROM unnest(string_to_array(current_setting('shared_preload_libraries'), ',')) AS l
   WHERE btrim(l, ' "') = 'pg_stat_statements')
SQL
) || { echo "cannot query PostgreSQL as postgres over the local socket."; exit 2; }

case $loaded in
    f)
        libs=$(pg -c "SELECT current_setting('shared_preload_libraries')" 2>/dev/null)
        echo "pg_stat_statements is not in the shared_preload_libraries in effect (\"$libs\"): no query statistics are collected."
        exit 1 ;;
    t) ;;
    *)
        echo "unexpected answer from PostgreSQL: $loaded"
        exit 2 ;;
esac

if err=$(pg -c 'SELECT count(*) FROM pg_stat_statements' 2>&1 >/dev/null); then
    echo "pg_stat_statements is preloaded and its view answers: query statistics are collected."
    exit 0
fi
echo "pg_stat_statements is preloaded, but its view does not answer in database postgres: $(printf '%s' "$err" | head -n 1)"
exit 1
