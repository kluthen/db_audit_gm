#!/bin/sh
# Public validator of the db_audit_gm Grafana node (v0.2 master spec 7.4).
# DO NOT TAMPER. Root-owned, read-only. Run as `grafana`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as grafana
#
# Rules:
#   files    the five provisioning files are at their paths, every file
#            under /etc/grafana/provisioning is readable by grafana, and
#            every dashboard file is valid JSON;
#   server   Grafana answers on port 3000 under /grafana/ and reports its
#            database ok;
#   reload   the last start or reload provisioned without error, and every
#            dashboard file with a uid is loaded;
#   pending  no provisioning file changed since Grafana last loaded them
#            (else run sudo gm-reload-grafana).
# Whether the data source points at the right address, or the dashboards
# and alert rules watch the right things, is the audit's business, not the
# validator's.
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...`; the result is unknown. Among others when Grafana
#      refuses the administrator's login: its password is no longer the
#      tools password (DO NOT TAMPER).
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

API=/usr/local/lib/gm/grafana-api
HEALTH=http://127.0.0.1:3000/grafana/api/health
. /usr/local/lib/gm/grafana-files

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }

# --- files -------------------------------------------------------------------
problems=$(prov_check_files)
if [ -n "$problems" ]; then
    say_red "files: $(printf '%s\n' "$problems" | sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600)"
fi

# --- server ------------------------------------------------------------------
if ! health=$(curl -fsS -m 5 "$HEALTH" 2>/dev/null); then
    say_red "server: Grafana does not answer on port 3000 under /grafana/; rules reload and pending not checked"
    exit 1
fi
db=$(printf '%s' "$health" | jq -r '.database // empty' 2>/dev/null)
[ -n "$db" ] || fail "unexpected answer from /api/health: $health"
if [ "$db" != ok ]; then
    say_red "server: Grafana reports its database '$db'; rules reload and pending not checked"
    exit 1
fi

# The administrator's login (the GM's checks depend on it).
user=$("$API" GET /api/user 2>&1); rc=$?
case $rc in
    0) [ "$(printf '%s' "$user" | jq -r '.login // empty' 2>/dev/null)" = admin ] \
           || fail "unexpected answer from /api/user: $(printf '%s' "$user" | cut -c1-200)" ;;
    1) case $user in
           *'HTTP 401'*) fail "Grafana refused the administrator's login: its password is no longer the tools password. Changing Grafana's users or the administrator's password is not allowed (DO NOT TAMPER); tell the game master." ;;
           *) fail "unexpected answer from /api/user: $(printf '%s' "$user" | tr '\n' ' ' | cut -c1-200)" ;;
       esac ;;
    *) fail "Grafana answers /api/health but not /api/user" ;;
esac

# --- reload ------------------------------------------------------------------
[ -r "$APPLIED" ] || fail "no record of Grafana's last start or reload ($APPLIED)"
how=$(applied_get how)
at=$(applied_get at)
result=$(applied_get result)
files=$(applied_get files)
if [ "$result" != ok ]; then
    say_red "reload: the last reload ($at) failed: $(applied_get detail); fix the files and run sudo gm-reload-grafana"
fi

# --- pending -----------------------------------------------------------------
pending=
if [ "$(prov_fingerprint)" != "$files" ]; then
    pending=1
    say_red "pending: a provisioning file changed after Grafana last loaded them (the $how at $at); run sudo gm-reload-grafana"
fi

# Every dashboard file with a uid is loaded (a file Grafana skipped is only
# in its log). Not checked while a change is pending.
if [ -z "$pending" ] && [ "$result" = ok ]; then
    missing=
    list=$(find "$PROV/dashboards" -name '*.json' -type f 2>/dev/null | LC_ALL=C sort)
    set -f; oldifs=$IFS; IFS='
'
    for f in $list; do
        uid=$(jq -r 'if type == "object" then (.uid // empty) else empty end' "$f" 2>/dev/null) || continue
        [ -n "$uid" ] || continue
        if ! "$API" GET "/api/dashboards/uid/$uid" >/dev/null 2>&1; then
            missing="$missing${missing:+, }${f#"$PROV"/} (uid $uid)"
        fi
    done
    IFS=$oldifs; set +f
    if [ -n "$missing" ]; then
        say_red "reload: Grafana did not load these dashboard files: $missing"
    fi
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
echo "GREEN: provisioning files valid and loaded (the $how at $at), Grafana up under /grafana/"
exit 0
