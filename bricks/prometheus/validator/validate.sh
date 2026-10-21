#!/bin/sh
# Public validator of the db_audit_gm Prometheus node (v0.2 master spec 7.2).
# DO NOT TAMPER. Root-owned, read-only. Run as `prometheus`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as prometheus
#
# Rules:
#   config     prometheus.yml loads (promtool check config);
#   server     Prometheus is ready on port 9090 under /prometheus/;
#   reload     the last load of the file succeeded (else Prometheus runs an
#              older configuration);
#   pending    the file has not changed since Prometheus last loaded it
#              (else run sudo gm-reload-prometheus);
#   retention  the retention in effect is bounded both by time and by size.
# Whether the scrape targets are the right ones is the audit's business, not
# the validator's.
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...` (unexpected answer from Prometheus); the result
#      is unknown
set -u
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

CONF=${1:-/etc/prometheus/prometheus.yml}
URL=http://127.0.0.1:9090/prometheus

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }
json_str() { sed -n "s/.*\"$1\":\"\([^\"]*\)\".*/\1/p"; }
json_bool() { sed -n "s/.*\"$1\":\([a-z]*\).*/\1/p"; }

# --- config ----------------------------------------------------------------
if [ ! -r "$CONF" ]; then
    say_red "config: $CONF is missing or unreadable"
elif ! out=$(promtool check config "$CONF" 2>&1); then
    say_red "config: $CONF does not load: $(printf '%s\n' "$out" | grep -v '^Checking ' | sed 's/^ *//' | tr '\n' ' ' | cut -c1-400)"
fi

# --- server ----------------------------------------------------------------
if ! curl -fsS -o /dev/null -m 5 "$URL/-/ready" 2>/dev/null; then
    say_red "server: Prometheus is not ready on port 9090 under /prometheus/; rules reload, pending and retention not checked"
    exit 1
fi
info=$(curl -fsS -m 5 "$URL/api/v1/status/runtimeinfo" 2>/dev/null) \
    || fail "Prometheus is ready but its runtime information is not readable"
success=$(printf '%s' "$info" | json_bool reloadConfigSuccess)
loaded=$(printf '%s' "$info" | json_str lastConfigTime)
retention=$(printf '%s' "$info" | json_str storageRetention)
[ -n "$success" ] && [ -n "$loaded" ] || fail "unexpected runtime information: $info"

# --- reload ----------------------------------------------------------------
if [ "$success" != true ]; then
    say_red "reload: the last load of the configuration failed; Prometheus runs the one it loaded at $loaded"
fi

# --- pending ---------------------------------------------------------------
if [ -r "$CONF" ]; then
    loaded_s=$(date -u -d "$loaded" +%s 2>/dev/null) || fail "unexpected lastConfigTime: $loaded"
    changed_s=$(stat -c %Y "$CONF")
    if [ "$changed_s" -gt "$loaded_s" ]; then
        say_red "pending: $CONF changed at $(date -u -d "@$changed_s" '+%Y-%m-%dT%H:%M:%SZ'), after Prometheus last loaded it ($loaded); run sudo gm-reload-prometheus"
    fi
fi

# --- retention -------------------------------------------------------------
case $retention in
    *' or '*) ;;
    *) say_red "retention: in effect '${retention:-none}'; it must be bounded both by time and by size (storage.tsdb.retention.time and .size in $CONF)" ;;
esac

if [ "$red" -gt 0 ]; then
    exit 1
fi
echo "GREEN: $CONF valid and loaded, Prometheus ready under /prometheus/, retention $retention"
exit 0
