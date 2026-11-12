#!/bin/sh
# Sealed check of governance-statement-log-personal (v0.5 master spec 17.2
# s7, 17.3; clinic-traps.md T1; capture W5 item 3 of
# specs/versions/v0.5/wave-log.md). Run as root on the database node. Live
# state: exit 0 once no log_statement but none or ddl is in effect,
# server-wide or in pg_db_role_setting for a role or database writing the
# business's data; 1 while one is; 2 on an error.
#
# In effect, not in the file: the server-wide value is the one the server
# loaded at its last reload (pg_settings, read as gm_check, whose own role
# carries no setting), so a file edited without a reload still reads
# present; ALTER SYSTEM counts once reloaded. A role or database writing the
# business's data: every database but postgres and the templates, every
# role but the game's own (postgres, dba, gm_check, monitoring, replicator,
# pgbouncer_lookup) and the pg_* roles; a setting for all roles or all
# databases counts. mod logs every write, its values included, as all does.
set -u

CHECK_PSQL=/usr/local/lib/gm/check-psql
pg() { "$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 "$@"; }

server=$(pg <<'SQL'
SELECT setting || ' ' || source FROM pg_settings WHERE name = 'log_statement'
SQL
) || { echo "cannot query PostgreSQL as the GM check role."; exit 2; }
value=${server%% *}
source=${server#* }
case $source in
    default|"configuration file"|"command line"|"environment variable"|override) ;;
    *) echo "the GM check role's session carries its own log_statement ($source): the server's value cannot be read."
       exit 2 ;;
esac

# Each role or database setting logging statements beyond ddl: "<what> <value>".
others=$(pg <<'SQL'
SELECT coalesce(string_agg(w || ' ' || v, '; ' ORDER BY w), '')
  FROM (SELECT CASE WHEN s.setrole = 0 AND s.setdatabase = 0 THEN 'every role in every database'
                    WHEN s.setrole = 0 THEN 'database ' || d.datname
                    WHEN s.setdatabase = 0 THEN 'role ' || r.rolname
                    ELSE 'role ' || r.rolname || ' in database ' || d.datname END AS w,
               split_part(c, '=', 2) AS v
          FROM pg_db_role_setting s
          LEFT JOIN pg_roles r ON r.oid = s.setrole
          LEFT JOIN pg_database d ON d.oid = s.setdatabase,
               unnest(s.setconfig) AS c
         WHERE split_part(c, '=', 1) = 'log_statement'
           AND lower(split_part(c, '=', 2)) NOT IN ('none', 'ddl')
           AND (s.setrole = 0 OR (r.rolname NOT IN ('postgres', 'dba', 'gm_check', 'monitoring', 'replicator',
                                                     'pgbouncer_lookup') AND r.rolname NOT LIKE 'pg\_%'))
           AND (s.setdatabase = 0 OR d.datname NOT IN ('postgres', 'template0', 'template1'))) x
SQL
) || { echo "cannot read pg_db_role_setting as the GM check role."; exit 2; }

case $value in
    none|ddl) ;;
    mod|all)
        more=
        [ -z "$others" ] || more="; also $others"
        echo "log_statement is $value server-wide (in effect since the last reload): every write of the record, its values included, goes into the server log$more."
        exit 1 ;;
    *)
        echo "unexpected log_statement in effect: [$value]"
        exit 2 ;;
esac
if [ -n "$others" ]; then
    echo "log_statement is $value server-wide, but statements are still logged with their values for: $others."
    exit 1
fi
echo "log_statement is $value server-wide and on no role or database writing the record: the writes leave no values in the server log."
exit 0
