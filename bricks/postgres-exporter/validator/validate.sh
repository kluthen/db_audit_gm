#!/bin/sh
# Public validator of the db_audit_gm postgres-exporter node (v0.2 master
# spec 7.3). DO NOT TAMPER. Root-owned, read-only. Run as `exporter`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as exporter
#
# Rules:
#   config   exporter.conf is valid: known keys only, each once, the
#            required ones set, values without spaces or quotes, collectors
#            this postgres_exporter has (else the service does not start);
#   server   postgres_exporter answers on port 9187;
#   pending  the file has not changed since postgres_exporter started (it
#            reads it only at start: run sudo gm-restart-exporter); the
#            modification time the service read is in
#            /run/postgres-exporter/loaded.
# Whether the exporter reaches the right database (pg_up, the address in
# the file) is the audit's business, not the validator's: the validator
# never asks anything of the database.
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

CONF=/etc/postgres-exporter/exporter.conf
URL=http://127.0.0.1:9187
STAMP=/run/postgres-exporter/loaded

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }

# --- config ----------------------------------------------------------------
if ! problems=$(/usr/local/lib/gm/exporter-conf check); then
    [ -n "$problems" ] || fail "exporter-conf check failed without saying why"
    say_red "config: $CONF is not valid, postgres_exporter does not start with it: $(printf '%s\n' "$problems" | sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600)"
fi

# --- server ----------------------------------------------------------------
if ! curl -fsS -o /dev/null -m 5 "$URL/" 2>/dev/null; then
    say_red "server: postgres_exporter does not answer on port 9187; rule pending not checked"
    exit 1
fi

# --- pending ---------------------------------------------------------------
# The s6 service records, at each start, the modification time of the file
# it read (exporter-conf run): the file is pending when it differs now.
pid=$(ps -u exporter -o pid=,args= | awk '$2 == "/usr/local/bin/postgres_exporter" { print $1; exit }')
[ -n "$pid" ] || fail "port 9187 answers but no postgres_exporter runs as exporter"
[ -r "$STAMP" ] || fail "postgres_exporter runs but $STAMP is missing"
loaded=$(sed -n 's/^mtime=//p' "$STAMP")
started=$(sed -n 's/^started=//p' "$STAMP")
[ -n "$started" ] || fail "unexpected $STAMP"
if [ -f "$CONF" ] && [ ! -L "$CONF" ]; then
    now=$(stat -c %.9Y "$CONF")
    if [ "$now" != "$loaded" ]; then
        say_red "pending: $CONF changed at $(date -u -d "@${now%.*}" '+%Y-%m-%dT%H:%M:%SZ'), after postgres_exporter started ($started); run sudo gm-restart-exporter"
    fi
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
echo "GREEN: $CONF valid; postgres_exporter answers on port 9187 and runs the file as it is (started $started)"
exit 0
