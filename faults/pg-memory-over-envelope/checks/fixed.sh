#!/bin/sh
# Sealed check of pg-memory-over-envelope (master spec 8.1). Run as root.
# Exit 0 once the value IN EFFECT of $FAULT_SETTING is at most $FAULT_MAX,
# 1 while it is above, 2 on an error. The value in effect is what the
# server uses after a reload or restart, whichever path set it (the file,
# or ALTER SYSTEM); a file edited but not applied still reads present.
set -u
r=$(runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d postgres -F ' ' \
    -v s="$FAULT_SETTING" -v mx="$FAULT_MAX" <<'SQL'
SELECT current_setting(:'s'),
       pg_size_bytes(current_setting(:'s')) <= pg_size_bytes(:'mx')
SQL
) || { echo "cannot read $FAULT_SETTING as postgres (or $FAULT_MAX is not a size)."; exit 2; }
value=${r% *}
within=${r##* }
case $within in
    t)
        echo "$FAULT_SETTING is $value in effect, within the envelope (at most $FAULT_MAX)."
        exit 0 ;;
    f)
        echo "$FAULT_SETTING is still $value in effect, above the envelope's $FAULT_MAX."
        exit 1 ;;
esac
echo "unexpected answer from PostgreSQL: $r"
exit 2
