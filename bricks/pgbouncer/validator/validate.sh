#!/bin/sh
# Public validator of the db_audit_gm PgBouncer node (v0.3 master spec 7.2).
# DO NOT TAMPER. Root-owned, read-only. Run as `pgbouncer`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as pgbouncer
#
# Rules:
#   config   PgBouncer loads the files as they are now
#            (/usr/local/lib/gm/pgbouncer-check), and pgbouncer.ini holds no
#            %include (not followed on this node);
#   server   PgBouncer answers on its console over the local socket;
#   gm       the GM's settings are the ones in effect: the console's users
#            (admin_users pgbouncer, stats_users dba) and the authentication
#            (auth_type, auth_file, auth_hba_file, auth_user, auth_dbname,
#            auth_query), as /usr/local/lib/gm/pgbouncer-gm.ini sets them;
#   auth     the database the logins are looked up in (auth_dbname,
#            postgres) is in [databases], else no role but the lookup role
#            can log in, the console's dba included;
#   knobs    every setting in the envelope file is within its envelope:
#            the value in effect (SHOW CONFIG) and the value pending in
#            /etc/pgbouncer/pgbouncer.ini's [pgbouncer] section (the last
#            one written after its last header, which a reload would
#            apply); and, in effect, each
#            database's own pool_size, reserve_pool_size, pool_mode and
#            max_db_connections (SHOW DATABASES) within the envelope of
#            default_pool_size, reserve_pool_size, pool_mode and
#            max_db_connections.
# Whether the pools are the right size for the load is the audit's
# business, not the validator's.
#
# Envelope file (default /opt/gm/protected/envelopes.conf), one rule a line,
# `#` comments and blank lines ignored:
#   <setting> range <min> <max>     whole numbers, or - for unbounded
#   <setting> enum <v1>,<v2>,...    compared without regard to case
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...` (unreadable or malformed envelope file, an
#      unexpected answer from the console); the result is unknown
set -u
set -f   # no globbing when splitting envelope lines
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

ENVELOPES=${1:-/opt/gm/protected/envelopes.conf}
CONF=/etc/pgbouncer/pgbouncer.ini
GM_CONF=/usr/local/lib/gm/pgbouncer-gm.ini
PGCONNECT_TIMEOUT=5
export PGCONNECT_TIMEOUT

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }
console() {  # console <command> [header]: unaligned, `|`-separated
    if [ "${2:-}" = header ]; then
        psql -X -w -q -A -F '|' -P footer=off -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "$1"
    else
        psql -X -w -q -A -t -F '|' -h /run/pgbouncer -p 6432 -U pgbouncer -d pgbouncer -c "$1"
    fi
}
is_int() { printf '%s' "$1" | grep -Eq '^-?[0-9]+$'; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# --- envelope file -------------------------------------------------------
[ -r "$ENVELOPES" ] || fail "envelope file $ENVELOPES is missing or unreadable"
rules=""      # one `<name>|range|<min>|<max>` or `<name>|enum|<v1>,<v2>` a line
nrules=0
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line=${line%%#*}
    # shellcheck disable=SC2086
    set -- $line
    [ "$#" -eq 0 ] && continue
    name=$1
    kind=${2:-}
    printf '%s' "$name" | grep -Eq '^[a-z_][a-z0-9_]*$' \
        || fail "$ENVELOPES line $lineno: bad setting name '$name'"
    case $kind in
        range)
            [ "$#" -eq 4 ] || fail "$ENVELOPES line $lineno: expected '<setting> range <min> <max>'"
            for b in "$3" "$4"; do
                [ "$b" = - ] || is_int "$b" || fail "$ENVELOPES line $lineno: bound '$b' is not a whole number"
            done
            rules="$rules$name|range|$3|$4
"
            ;;
        enum)
            [ "$#" -eq 3 ] || fail "$ENVELOPES line $lineno: expected '<setting> enum <v1>,<v2>,...'"
            printf '%s' "$3" | grep -Eq '^[A-Za-z0-9_.-]+(,[A-Za-z0-9_.-]+)*$' \
                || fail "$ENVELOPES line $lineno: bad allowed values '$3'"
            rules="$rules$name|enum|$(lower "$3")
"
            ;;
        *)
            fail "$ENVELOPES line $lineno: unknown rule kind '$kind' (range or enum)"
            ;;
    esac
    nrules=$((nrules + 1))
done < "$ENVELOPES"

# within <name> <value>: 0 when the value is within the setting's envelope,
# 1 when not, 2 when the setting has no rule; prints the envelope.
within() {
    r=$(printf '%s' "$rules" | grep "^$1|" | tail -n 1)
    [ -n "$r" ] || return 2
    old_ifs=$IFS
    IFS='|'
    # shellcheck disable=SC2086
    set -- $r "$2"
    IFS=$old_ifs
    if [ "$2" = range ]; then
        printf '%s..%s' "$3" "$4"
        v=$5
        is_int "$v" || return 1
        { [ "$3" = - ] || [ "$v" -ge "$3" ]; } && { [ "$4" = - ] || [ "$v" -le "$4" ]; }
        return
    fi
    printf '{%s}' "$3"
    v=$(lower "$4")
    case ",$3," in *",$v,"*) return 0 ;; esac
    return 1
}

# --- config ----------------------------------------------------------------
out=$(/usr/local/lib/gm/pgbouncer-check 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && [ -n "$out" ]; then
    printf '%s\n' "$out" | while IFS= read -r n; do printf 'RED config: %s; write the settings in pgbouncer.ini itself\n' "$n"; done
    red=$((red + $(printf '%s\n' "$out" | wc -l)))
fi
case $rc in
    0) ;;
    1) say_red "config: $CONF does not load (a reload would be refused): $(printf '%s\n' "$out" | tr '\n' ' ' | cut -c1-400)" ;;
    *) fail "the configuration could not be checked: $(printf '%s' "$out" | head -n 1)" ;;
esac

# --- server ----------------------------------------------------------------
if ! config=$(console 'SHOW CONFIG' 2>&1); then
    say_red "server: PgBouncer does not answer on its console (/run/pgbouncer, port 6432); rules gm, auth and knobs not checked ($(printf '%s' "$config" | head -n 1))"
    exit 1
fi
databases=$(console 'SHOW DATABASES' header 2>&1) || fail "SHOW DATABASES failed: $(printf '%s' "$databases" | head -n 1)"
setting() { printf '%s\n' "$config" | awk -F'|' -v k="$1" '$1 == k { print $2; exit }'; }

# --- gm ----------------------------------------------------------------------
for k in admin_users stats_users auth_type auth_file auth_hba_file auth_user auth_dbname auth_query; do
    want=$(sed -n "s/^$k = //p" "$GM_CONF" | tail -n 1)
    [ -n "$want" ] || fail "$GM_CONF does not set $k"
    have=$(setting "$k")
    [ "$have" = "$want" ] \
        || say_red "gm: $k in effect is '$have', not the GM's '$want' ($GM_CONF; DO NOT TAMPER)"
done

# --- auth ----------------------------------------------------------------------
auth_db=$(sed -n 's/^auth_dbname = //p' "$GM_CONF" | tail -n 1)
if ! printf '%s\n' "$databases" | awk -F'|' -v d="$auth_db" 'NR > 1 && ($1 == d || $1 == "*") { f = 1 } END { exit !f }'; then
    say_red "auth: database $auth_db, where PgBouncer looks the logins up (auth_dbname), is not in [databases] of $CONF; no role can log in, the console's dba included"
fi

# --- knobs: in effect and pending ---------------------------------------------------
# pending: the last value of each setting in [pgbouncer], with its line
pending=$(awk '
    /^[ \t]*[;#]/ { next }
    /^[ \t]*\[/ { s = $0; sub(/\].*/, "", s); gsub(/[ \t\[]/, "", s); sec = tolower(s)
                  if (sec == "pgbouncer") { split("", val); split("", ln) }   # a header resets the section
                  next }
    sec == "pgbouncer" && /=/ {
        k = substr($0, 1, index($0, "=") - 1); v = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t\r]+$/, "", k); gsub(/^[ \t]+|[ \t\r]+$/, "", v)
        k = tolower(k); val[k] = v; ln[k] = NR
    }
    END { for (k in val) print k "|" val[k] "|" ln[k] }' "$CONF" 2>/dev/null)
results=$(printf '%s' "$rules" | while IFS='|' read -r name kind rest; do
    [ -n "$name" ] || continue
    printf '%s\n' "$config" | awk -F'|' -v k="$name" '$1 == k { f = 1 } END { exit !f }' \
        || { echo "ERROR|$ENVELOPES: unknown setting $name"; continue; }
    eff=$(setting "$name")
    msg=
    env=$(within "$name" "$eff") || msg="in effect $eff"
    p=$(printf '%s\n' "$pending" | awk -F'|' -v k="$name" '$1 == k { print; exit }')
    if [ -n "$p" ]; then
        pv=$(printf '%s' "$p" | cut -d'|' -f2)
        pl=$(printf '%s' "$p" | cut -d'|' -f3)
        within "$name" "$pv" >/dev/null || msg="${msg:+$msg; }pending $pv ($CONF:$pl)"
    fi
    [ -z "$msg" ] || echo "RED|knobs: $name: $msg; envelope $env"
done 2>&1)
err=$(printf '%s\n' "$results" | sed -n 's/^ERROR|//p' | head -n 1)
[ -z "$err" ] || fail "$err"
reds=$(printf '%s\n' "$results" | sed -n 's/^RED|//p')
if [ -n "$reds" ]; then
    printf '%s\n' "$reds" | sed 's/^/RED /'
    red=$((red + $(printf '%s\n' "$reds" | wc -l)))
fi

# --- knobs: each database's own values, in effect ------------------------------------------
# column -> the global setting whose envelope bounds it
dbreds=$(printf '%s\n' "$databases" | awk -F'|' '
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    $1 != "pgbouncer" && $1 != "" {
        print $1 "|default_pool_size|pool_size|" $(col["pool_size"])
        print $1 "|reserve_pool_size|reserve_pool_size|" $(col["reserve_pool_size"])
        if ($(col["pool_mode"]) != "") print $1 "|pool_mode|pool_mode|" $(col["pool_mode"])
        if ($(col["max_connections"]) != "0") print $1 "|max_db_connections|max_db_connections|" $(col["max_connections"])
    }' | while IFS='|' read -r db rule label value; do
        env=$(within "$rule" "$value")
        case $? in
            1) echo "knobs: database $db: its $label $value is outside $rule's envelope $env" ;;
        esac
    done)
if [ -n "$dbreds" ]; then
    printf '%s\n' "$dbreds" | sed 's/^/RED /'
    red=$((red + $(printf '%s\n' "$dbreds" | wc -l)))
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
printf 'GREEN: %s loads, PgBouncer answers, the GM'"'"'s settings in effect, %s knob envelope rule(s) respected\n' "$CONF" "$nrules"
exit 0
