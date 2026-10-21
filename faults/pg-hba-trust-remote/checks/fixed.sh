#!/bin/sh
# Sealed check of pg-hba-trust-remote (master spec 8.1). Run as root on the
# database node. Exit 0 once remote `trust` is gone, 1 while it is present,
# 2 on an error.
#
# Present when either holds:
#   - in effect: a TCP connection to one of the node's own non-loopback
#     addresses, as dba with no password, is accepted (the loaded rules
#     still trust that address);
#   - in the file: pg_hba.conf (pg_hba_file_rules) still has a non-local
#     rule with method trust for an address other than loopback, which
#     would trust remote clients the node cannot impersonate (the bastion).
set -u

pg() { runuser -u postgres -- psql -XAtq -v ON_ERROR_STOP=1 -d postgres "$@"; }

pg -c 'SELECT 1' >/dev/null 2>&1 \
    || { echo "cannot query PostgreSQL as postgres over the local socket."; exit 2; }

rules=$(pg <<'SQL'
SELECT string_agg(format('line %s (%s %s)', line_number, type,
                         coalesce(address, '')), ', ' ORDER BY line_number)
  FROM pg_hba_file_rules
 WHERE error IS NULL AND type <> 'local' AND auth_method = 'trust'
   AND coalesce(address, '') NOT IN ('127.0.0.1', '::1', 'samehost')
SQL
) || { echo "cannot read pg_hba_file_rules."; exit 2; }

addrs=$(hostname -I 2>/dev/null) || addrs=
live=
for a in $addrs; do
    case $a in 127.*|::1) continue ;; esac
    if env -u PGPASSWORD PGPASSFILE=/nonexistent PGCONNECT_TIMEOUT=5 \
            runuser -u postgres -- psql -XAtq -w -h "$a" -U dba -d postgres \
            -c 'SELECT 1' >/dev/null 2>&1; then
        live=$a
        break
    fi
done

if [ -n "$live" ]; then
    echo "remote connections are still trusted: dba logged in from $live without a password."
    exit 1
fi
if [ -n "$rules" ]; then
    echo "pg_hba.conf still trusts remote clients: $rules."
    exit 1
fi
echo "no remote client is trusted any more: connections without a password are refused."
exit 0
