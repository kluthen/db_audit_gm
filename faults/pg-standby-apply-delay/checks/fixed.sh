#!/bin/sh
# Sealed check of pg-standby-apply-delay (v0.5 master spec 17.2 s8, 17.3;
# clinic-traps.md T33; capture W5 item 3 of specs/versions/v0.5/wave-log.md;
# spec D461). Run as root on the standby. Live state: exit 0 once the
# recovery_min_apply_delay in effect is 0, 1 while it is not, 2 on an error.
#
# In effect, not in the file: the value the server loaded at its last
# reload (current_setting, read as gm_check, whose own role carries no
# setting), so a file edited without a reload still reads present; ALTER
# SYSTEM counts once reloaded. The first line also gives what the standby
# has received and not replayed, and since when it replays nothing newer.
set -u

CHECK_PSQL=/usr/local/lib/gm/check-psql
out=$("$CHECK_PSQL" -d postgres -Atq -v ON_ERROR_STOP=1 <<'SQL'
SELECT (SELECT setting FROM pg_settings WHERE name = 'recovery_min_apply_delay') || '|'
       || (SELECT unit FROM pg_settings WHERE name = 'recovery_min_apply_delay') || '|'
       || pg_is_in_recovery()::text || '|'
       || coalesce(pg_size_pretty(pg_wal_lsn_diff(pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn())), '-') || '|'
       || coalesce(to_char(pg_last_xact_replay_timestamp() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), '-')
SQL
) || { echo "cannot query PostgreSQL as the GM check role."; exit 2; }

delay=$(printf '%s' "$out" | cut -d'|' -f1)
unit=$(printf '%s' "$out" | cut -d'|' -f2)
recovery=$(printf '%s' "$out" | cut -d'|' -f3)
pending=$(printf '%s' "$out" | cut -d'|' -f4)
replayed=$(printf '%s' "$out" | cut -d'|' -f5)
case $delay in
    ''|*[!0-9]*) echo "unexpected recovery_min_apply_delay in effect: [$out]"; exit 2 ;;
esac
if [ "$delay" -eq 0 ]; then
    echo "recovery_min_apply_delay is 0: the standby replays what it receives at once (received and not replayed: $pending)."
    exit 0
fi
case $recovery in
    true)
        if [ "$replayed" = - ]; then since="no transaction replayed since the standby started"
        else since="the last transaction replayed committed at $replayed"; fi
        where="received and not replayed: $pending; $since" ;;
    *) where="the node is no longer in recovery, the delay waiting for its next standby role" ;;
esac
echo "recovery_min_apply_delay is $delay$unit in effect: every commit reaches the reports' standby that late ($where)."
exit 1
