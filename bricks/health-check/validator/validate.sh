#!/bin/sh
# Public validator of the db_audit_gm health node (v0.5 master spec 7.4).
# DO NOT TAMPER. Root-owned, read-only. Run as `postgres`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as postgres
#
# Rules:
#   config   health.yaml is valid (its one shape: instances, each with a
#            name, host, port and dbname, a standby's primary an instance
#            of the file), else the checks run nothing;
#   scripts  every script the crontab runs (`health-run script <name>`) is
#            an executable regular file of /etc/health/scripts;
#   cron     the cron daemon runs;
#   web      the status page answers on port 8080 (/health/);
#   fresh    the checks last ran less than 15 minutes ago (they run every
#            five minutes from the crontab).
# What the checks find (a CRITICAL line on the page) is the audit's
# business, not the validator's: it never asks anything of a database.
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

CONF=/etc/health/health.yaml
RESULTS=/var/lib/health/results/checks.json

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }
[ "$(id -un)" = postgres ] || fail "run it as postgres (sudo gm-validate)"

# --- config ----------------------------------------------------------------
if ! problems=$(health-run check-config); then
    [ -n "$problems" ] || fail "health-run check-config failed without saying why"
    say_red "config: $CONF is not valid, no check runs: $(printf '%s\n' "$problems" | sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600)"
fi

# --- scripts ---------------------------------------------------------------
tab=$(crontab -l 2>/dev/null)
names=$(printf '%s\n' "$tab" | grep -v '^[[:space:]]*#' | sed -n 's/.*health-run[[:space:]][[:space:]]*script[[:space:]][[:space:]]*\([^[:space:]]*\).*/\1/p' | sort -u)
for n in $names; do
    p=/etc/health/scripts/$n
    if [ -L "$p" ] || [ ! -f "$p" ]; then
        say_red "scripts: the crontab runs $n, which is not a regular file of /etc/health/scripts"
    elif [ ! -x "$p" ]; then
        say_red "scripts: the crontab runs $n, which is not executable"
    fi
done

# --- cron ------------------------------------------------------------------
if [ -z "$(ps -C cron -o pid= 2>/dev/null)" ]; then
    say_red "cron: the cron daemon does not run; the checks and scripts do not run"
fi

# --- web -------------------------------------------------------------------
if ! curl -fsS -o /dev/null -m 5 http://127.0.0.1:8080/health/ 2>/dev/null; then
    say_red "web: the status page does not answer on port 8080 (/health/)"
fi

# --- fresh -----------------------------------------------------------------
if [ ! -f "$RESULTS" ]; then
    say_red "fresh: the checks have not run yet"
else
    age=$(( $(date +%s) - $(stat -c %Y "$RESULTS") ))
    if [ "$age" -ge 900 ]; then
        say_red "fresh: the checks last ran ${age}s ago (every five minutes expected: is health-run checks in the crontab?)"
    fi
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
echo "GREEN: $CONF valid; cron runs; the page answers on port 8080; the checks ran ${age}s ago"
exit 0
