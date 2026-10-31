#!/bin/sh
# Sealed check of security-crontab-superuser (v0.4 master spec 16.2, 12.6).
# Run as root on the database node, fed to `sh -s` by gmctl check, with
# FAULT_ROLE (the role prepared for the entry). Judges the live state:
# every crontab in cron's spool (/var/spool/cron/crontabs, postgres's and
# any other user's), each entry running a PostgreSQL client program
# (psql, pg_dump, vacuumdb, ...) taken with the role it connects as, and
# that role's rolsuper read as the GM check role through check-psql.
#
# The roles an entry connects as, as libpq picks them: each -U <role>,
# -U<role> or --username[=| ]<role> on its command line (one per program
# it runs); else a user= in a connection string or the user of a
# postgres:// URI; else a PGUSER= set on the command line or on an
# environment line of the crontab above the entry; else the crontab's OS
# user (peer maps it to the same name over the local socket: postgres for
# postgres's crontab).
#
# Exit 1: an entry connects as a superuser, naming it. Exit 0: none does
# (also when no entry connects any more: the first line says so, and the
# GM judges a job deleted rather than fixed). Exit 2: it cannot judge.
set -u
CHECK_PSQL=/usr/local/lib/gm/check-psql
SPOOL=/var/spool/cron/crontabs
ROLE=${FAULT_ROLE:-}

[ -x "$CHECK_PSQL" ] || { echo "cannot judge: no $CHECK_PSQL on this node (postgres 0.4.0 needed)."; exit 2; }
[ -d "$SPOOL" ] || { echo "cannot judge: no crontab spool $SPOOL on this node."; exit 2; }

entries=$(
    for f in "$SPOOL"/*; do
        [ -f "$f" ] || continue
        case ${f##*/} in .*|tmp.*) continue ;; esac
        awk -v osuser="${f##*/}" '
        function unq(s) { gsub(/^["\047]|["\047]$/, "", s); return s }
        BEGIN { pguser = "" }
        /^[ \t]*(#|$)/ { next }
        /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*=/ {
            name = $0; sub(/[ \t]*=.*/, "", name); sub(/^[ \t]*/, "", name)
            value = $0; sub(/^[^=]*=[ \t]*/, "", value); sub(/[ \t]*$/, "", value)
            if (name == "PGUSER") pguser = unq(value)
            next
        }
        {
            line = $0; sub(/^[ \t]*/, "", line)
            if (line ~ /^@/) { when = $1; cmd = line; sub(/^[^ \t]+[ \t]+/, "", cmd) }
            else {
                when = $1 " " $2 " " $3 " " $4 " " $5; cmd = line
                for (i = 0; i < 5; i++) sub(/^[^ \t]+[ \t]+/, "", cmd)
            }
            if (cmd !~ /(^|[ \t;&|(\/])(psql|pg_dump|pg_dumpall|pg_restore|vacuumdb|reindexdb|clusterdb|pgbench|pg_amcheck|createdb|dropdb)([ \t;&|)]|$)/)
                next
            role = ""
            rest = cmd
            while (match(rest, /(^|[ \t])(-U[ \t]*|--username[= \t]+)["\047]?[^ \t"\047;&|)]+/)) {
                tok = substr(rest, RSTART, RLENGTH)
                sub(/^[ \t]*(-U[ \t]*|--username[= \t]+)/, "", tok)
                role = role (role == "" ? "" : " ") unq(tok)
                rest = substr(rest, RSTART + RLENGTH)
            }
            if (role == "" && match(cmd, /(^|[ \t"\047])user=[^ \t"\047;&|)]+/)) {
                tok = substr(cmd, RSTART, RLENGTH); sub(/^.*user=/, "", tok); role = tok
            }
            if (role == "" && match(cmd, /postgres(ql)?:\/\/[^ \t"\047\/@:]+(:[^ \t"\047\/@]*)?@/)) {
                tok = substr(cmd, RSTART, RLENGTH); sub(/^postgres(ql)?:\/\//, "", tok)
                sub(/[:@].*$/, "", tok); role = tok
            }
            if (role == "" && match(cmd, /(^|[ \t])PGUSER=[^ \t;&|)]+/)) {
                tok = substr(cmd, RSTART, RLENGTH); sub(/^.*PGUSER=/, "", tok); role = unq(tok)
            }
            if (role == "") role = (pguser != "" ? pguser : osuser)
            n = split(role, each, " ")
            for (i = 1; i <= n; i++) printf "%s\t%d\t%s\t%s\n", osuser, NR, each[i], when
        }' "$f" || exit 2
    done
) || { echo "cannot judge: a crontab of $SPOOL cannot be read."; exit 2; }

if [ -z "$entries" ]; then
    echo "no live crontab entry connects to PostgreSQL any more, so none as a superuser (the job prepared for role $ROLE is gone from every crontab)."
    exit 0
fi

roles=$(printf '%s\n' "$entries" | cut -f3 | sort -u | tr '\n' ' ')
supers=$("$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 -v roles="$roles" <<'SQL'
SELECT r.rolname
  FROM pg_roles r
 WHERE r.rolsuper
   AND r.rolname = ANY (string_to_array(btrim(:'roles'), ' '))
 ORDER BY 1
SQL
) || { echo "cannot judge: cannot read pg_roles as the GM check role."; exit 2; }

count=$(printf '%s\n' "$entries" | cut -f1,2 | sort -u | wc -l | tr -d ' ')
bad=$(printf '%s\n' "$entries" | awk -F '\t' -v supers=" $(printf '%s' "$supers" | tr '\n' ' ') " \
    'index(supers, " " $3 " ") { print }')
if [ -n "$bad" ]; then
    n=$(printf '%s\n' "$bad" | cut -f1,2 | sort -u | wc -l | tr -d ' ')
    first=$(printf '%s\n' "$bad" | head -n 1)
    user=$(printf '%s' "$first" | cut -f1)
    line=$(printf '%s' "$first" | cut -f2)
    as=$(printf '%s' "$first" | cut -f3)
    when=$(printf '%s' "$first" | cut -f4)
    more=
    [ "$n" -gt 1 ] && more=" ($n of the $count entries connecting to PostgreSQL do)"
    echo "the crontab entry of $user at line $line ($when) connects as $as, a superuser$more; role $ROLE was prepared for it."
    printf '%s\n' "$bad" | awk -F '\t' '{ printf "  %s line %s (%s): as %s\n", $1, $2, $4, $3 }'
    exit 1
fi
echo "every live crontab entry connecting to PostgreSQL ($count) connects as a role that is no superuser ($(printf '%s' "$roles" | sed 's/ $//; s/ /, /g'))."
exit 0
