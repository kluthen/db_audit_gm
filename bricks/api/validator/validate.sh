#!/bin/sh
# Public validator of the db_audit_gm api node (v0.5 master spec 7.2).
# DO NOT TAMPER. Root-owned, read-only. Run as `api`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as api
#
# Rules:
#   config   api.yaml and every endpoint pair load and pass the brick's
#            checks (python3 -I -m gm_api check: both files, the imports a
#            route and a db/ file may make, the router, the names a route
#            takes from db/, the connections db/ names, no method and path
#            twice on a hostname); else the server does not start with
#            them, nor gm-reload-api restart it;
#   server   the server answers on port 8000;
#   pending  the files have not changed since the server loaded them (it
#            reads them at start and on sudo gm-reload-api); what it loaded
#            is in /run/gm-api/loaded.
# Whether the queries are right is the audit's business.
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

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }
oneline() { sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600; }
prog() { python3 -I -m gm_api "$@"; }

[ "$(id -un)" = api ] || fail "run as api (sudo gm-validate)"

# --- config ----------------------------------------------------------------
problems=$(cd / && prog check 2>&1)
case $? in
    0) ;;
    1) say_red "config: the endpoints do not load: $(printf '%s\n' "$problems" | oneline)" ;;
    *) fail "the check failed: $(printf '%s\n' "$problems" | oneline)" ;;
esac

# --- server ----------------------------------------------------------------
code=$(curl -s -o /dev/null -m 5 -w '%{http_code}' -H 'Host: gm-validate.invalid' http://127.0.0.1:8000/ 2>/dev/null)
if [ "$code" != 404 ]; then
    say_red "server: the server does not answer on port 8000; rule pending not checked"
    exit 1
fi

# --- pending -----------------------------------------------------------------
changed=$(cd / && prog pending 2>&1)
case $? in
    0) ;;
    1) say_red "pending: $(printf '%s\n' "$changed" | oneline); run sudo gm-reload-api" ;;
    *) fail "$(printf '%s\n' "$changed" | oneline)" ;;
esac

if [ "$red" -gt 0 ]; then
    exit 1
fi
loaded=$(sed -n 's/^loaded=//p' /run/gm-api/loaded)
echo "GREEN: api.yaml and its endpoint pairs load ($(printf '%s' "$problems" | sed 's/^api.yaml and //; s/ load (/: /; s/); hostnames: / on /')); the server answers on port 8000 and serves the files as they are (loaded $loaded)"
exit 0
