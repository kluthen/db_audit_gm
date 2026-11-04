#!/bin/sh
# Public validator of the db_audit_gm pgwatch node (v0.5 master spec 7.4).
# DO NOT TAMPER. Root-owned, read-only. Run as `pgwatch`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as pgwatch
#
# Rules:
#   config   sources.yaml is valid: pgwatch itself parses it (`pgwatch
#            source resolve`), at least one source is enabled, each enabled
#            source a postgresql:// URI with one host (else the service
#            does not start with it, or watches nothing);
#   server   pgwatch's Prometheus sink answers on port 9188 (/metrics);
#   web      pgwatch's web interface and REST API are off: nothing answers
#            on port 8080.
# pgwatch rereads the file every minute, so no edit stays pending. Whether
# pgwatch reaches the right databases (pgwatch_instance_up, the addresses
# in the file) is the audit's business, not the validator's: the validator
# never asks anything of a database.
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...` (unexpected state); the result is unknown
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

CONF=/etc/pgwatch/sources.yaml
URL=http://127.0.0.1:9188/metrics

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }

# --- config ----------------------------------------------------------------
if ! problems=$(/usr/local/lib/gm/pgwatch-sources check); then
    [ -n "$problems" ] || fail "pgwatch-sources check failed without saying why"
    say_red "config: $CONF is not valid, pgwatch does not start with it: $(printf '%s\n' "$problems" | sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600)"
fi

# --- web -------------------------------------------------------------------
if curl -sS -o /dev/null -m 3 http://127.0.0.1:8080/ 2>/dev/null; then
    say_red "web: something answers on port 8080; pgwatch's web interface must be off (--web-disable=all)"
fi

# --- server ----------------------------------------------------------------
if ! curl -fsS -o /dev/null -m 10 "$URL" 2>/dev/null; then
    say_red "server: pgwatch's Prometheus sink does not answer on port 9188"
else
    pid=$(ps -u pgwatch -o pid=,args= | awk '$2 == "/usr/local/bin/pgwatch" { print $1; exit }')
    [ -n "$pid" ] || fail "port 9188 answers but no pgwatch runs as pgwatch"
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
echo "GREEN: $CONF valid; pgwatch's sink answers on port 9188, its web interface is off"
exit 0
