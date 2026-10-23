#!/bin/sh
# Public validator of the db_audit_gm scheduler node (v0.3 master spec
# 7.1). DO NOT TAMPER. Root-owned, read-only. Run as `scheduler`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as scheduler
#
# Rules:
#   config   queries.yaml, the builders it names and jobs.yaml load, and
#            jobs.yaml's keys are in queries.yaml (else the scheduler does
#            not start with them, nor reload them);
#   server   the scheduler program answers on port 9120;
#   pending  the files have not changed since the program loaded them (it
#            reads them at start and on sudo gm-reload-scheduler); what it
#            loaded is in /run/scheduler/loaded.
# Idle (before the load starts) is not red. The schedule is not the
# validator's to read: whether the schedule's keys are all in queries.yaml
# is gm-reload-scheduler's check. Whether the queries are right is the
# audit's business.
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

URL=http://127.0.0.1:9120/metrics
STATUS=/run/scheduler/status

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }
oneline() { sed 's/$/;/' | tr '\n' ' ' | sed 's/; $//' | cut -c1-600; }
prog() { python3 -I -m gm_scheduler "$@"; }

[ "$(id -un)" = scheduler ] || fail "run as scheduler (sudo gm-validate)"

# --- config ----------------------------------------------------------------
problems=$(prog check 2>&1)
case $? in
    0) ;;
    1) say_red "config: the scheduler does not load its files: $(printf '%s\n' "$problems" | oneline)" ;;
    *) fail "the check failed: $(printf '%s\n' "$problems" | oneline)" ;;
esac

# --- server ----------------------------------------------------------------
if ! curl -fsS -o /dev/null -m 5 "$URL" 2>/dev/null; then
    say_red "server: the scheduler does not answer on port 9120; rule pending not checked"
    exit 1
fi
state=$(cat "$STATUS" 2>/dev/null) || fail "the scheduler answers but $STATUS is missing"

# --- pending -----------------------------------------------------------------
changed=$(prog pending 2>&1)
case $? in
    0) ;;
    1) say_red "pending: $(printf '%s\n' "$changed" | oneline); run sudo gm-reload-scheduler" ;;
    *) fail "$(printf '%s\n' "$changed" | oneline)" ;;
esac

if [ "$red" -gt 0 ]; then
    exit 1
fi
loaded=$(sed -n 's/^loaded=//p' /run/scheduler/loaded)
case $state in
    idle*) what="is idle (the load has not started) since ${state#idle }" ;;
    running*) what="is running since ${state#running }" ;;
    *) fail "unexpected status: $state" ;;
esac
echo "GREEN: queries.yaml, builders/ and jobs.yaml load; the scheduler answers on port 9120, $what, and runs the files as they are (loaded $loaded)"
exit 0
