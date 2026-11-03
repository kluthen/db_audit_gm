#!/bin/sh
# The v0.4 scenario's smoke cycles (v0.4 master spec 18 items 1 to 5; build
# plan chunk 17a; capture W4 items 4 and 6 to 8): a short game of
# scenarios/tarnbeck-outdoor-campaign on a real swarm, in one of four modes.
# Never at the same time as another game of this repository (the bastion's
# published ports) and never with another docker-using check: run it alone,
# under the host lock and a sleep inhibitor (a suspended host stops the
# game's clock-driven load):
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#       sh tools/tests/smoke-purposes.sh <mode> <playground> [<gmctl fit option>...]
#
# Every mode: a copy of the scenario -> fit (the options given, as
# smoke-load.sh and rehearsal.sh take them) -> render --handover, the
# planned hand-over chosen so the scenario's time at T0 is about the mode's
# (SMOKE_LOCAL_AT, HH:MM; the shift is whole hours) -> deploy -> load-data
# -> inject -> start-load -> the mode's steps -> teardown, then nothing of
# the game left on the local engine or SMOKE_ENGINES, its systemd user
# units included. No test speeds up, freezes or forges a clock, and nobody
# runs a job (master spec 8.4): a job is made to run by moving its time and
# reloading its runner, as a player may (jobs.yaml and `sudo
# gm-reload-scheduler` on crm and the producer; a crontab through `sudo
# gm-crontab`), the harness doing it as root on a report-only node (bi:
# jobs.yaml and s6's SIGHUP, master spec 18.2). A move sets the job's time
# one to two minutes ahead and the harness waits for that time and the
# run's end line in the runner's log (D246: a check's remaining= is blind
# to a move); every moved jobs.yaml is restored byte for byte, and reloaded,
# after its cycle (W4 item 6).
#
# Modes:
#   smoke     (18.1) every fault planted at once (the T0 ones by inject, the
#             others by inject --at now, f5 after the nightly close as in the
#             aging), every scheduler key running (the timeline applied) and
#             every job run: crm's two campaign jobs moved until f2 and f3
#             read present, the producer's close of day, then bi's hourly
#             roll-up and nightly close (f4 and f7 present), f5 planted
#             (present), f1, f6, f9 present, f8 present (its outage, or the
#             stub's unanswered few, 47 minutes past the last crm reload),
#             f10 planted, its 03:00 entry never moved (its check cannot
#             confirm an incident: error); db's :17 entry and reporting's
#             pg_cron job run on their own. Default SMOKE_LOCAL_AT 07:30, so
#             the gateway's outage (handover-6h to handover-4h, 08:00-10:00)
#             falls inside the run. For two hosts, with reporting on the
#             manager (fit refuses the VPS for it: f10).
#   cycles    (18.2, 18.3) the smoke steps, then every purpose fault through
#             its whole cycle (planted; its job moved; present; its
#             acceptance fix, W4 item 7; too soon; moved again; fixed) and
#             f6 and f9 present then fixed: f6, f9, f1, f2 (the runner path,
#             f3's change left), f3, then f5 (fixed outside the runner,
#             --since its instant), f7 (--since; its close moved more than 15
#             minutes after the previous close, W4 item 9), f4 (its fix, then
#             a close of day after a local midnight and the hourly run after
#             it), f8 (its fix once it reads present, all crm moves done:
#             each crm reload raises f8's judged moment). Default
#             SMOKE_LOCAL_AT 18:00: crm's moves and the close's before 21:00
#             local, f3's mail window (08:00-21:00 the company's time) and
#             f7's faulty day (offset 3: the local date until 21:00) still
#             open for their present readings; local midnight five to six
#             and a half hours after T0. Refuses to go on past 02:45 local,
#             f10's entry being at 03:00. One host.
#   baseline  (18.4) the unfaulted scenario: the copy's seed-changed files
#             fixture-campaign's (W4 item 8: crm's queries, bi's rollup.py,
#             db's and reporting's crontabs, the producer's and gateway's
#             queries and schedule; the data file cut at the fixture's last
#             line), every instance left out by render's harness-only
#             --test-leave-out; every job run (moves), then G1 to G4
#             (check-governance.sh) exit 0, again after db's :17 entry ran.
#             Default SMOKE_LOCAL_AT 10:30. One host.
#   f10       (18.5) f10's own run, on armenelos alone, every other node
#             drained (13.3): the T0 faults planted, f10's request by inject
#             --at now, its 03:00 entry moved by `sudo gm-crontab`; its
#             check reads present, PostgreSQL accepts connections again, s6,
#             sshd and cron keep their pids, every node healthy; the node's
#             memory.peak and oom_kill. Default SMOKE_LOCAL_AT 23:30.
#
# Usage: sh tools/tests/smoke-purposes.sh <smoke|cycles|baseline|f10> <playground> [<fit option>...]
#   one host:  sh tools/tests/smoke-purposes.sh cycles armenelos --cpu 4 --memory 5G --disk 10G
#   two hosts (G7: the VPS set active for the run only, then drained):
#     SMOKE_ENGINES=ssh://dbagm-vps sh tools/tests/smoke-purposes.sh smoke duo \
#       --host armenelos,manager,cpu=4,memory=4G,disk=12G \
#       --host vps-5718ad52,shared,endpoint=ssh://dbagm-vps,cpu=2,memory=2G,disk=8G
# Environment:
#   SMOKE_SCENARIO    the scenario folder (default scenarios/tarnbeck-outdoor-campaign)
#   SMOKE_BASELINE    the baseline fixture (default tools/tests/fixtures/fixture-campaign)
#   SMOKE_ENGINES     the playground's other Docker endpoints (docker -H), for
#                     the leftovers check and the memory figures
#   SMOKE_LOCAL_AT    the scenario's time at T0, HH:MM (the mode's default above)
#   LOAD_MINUTES      minutes of schedules before the keys are judged (default 5)
#   CHECK_TIMEOUT     seconds one gmctl check run may take (default 300)
# Needs what smoke-scenario.sh needs (a swarm manager on the local engine,
# the user's systemd manager, python3 with PyYAML, the bricks' images built),
# host ports 2222 and 8080 free.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 -B $REPO/tools/gmctl"
H="python3 -B $HERE/smoke-purposes.py"
SOURCE=${SMOKE_SCENARIO:-$REPO/scenarios/tarnbeck-outdoor-campaign}
FIXTURE=${SMOKE_BASELINE:-$REPO/tools/tests/fixtures/fixture-campaign}
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
LOAD_MINUTES=${LOAD_MINUTES:-5}
CHECK_TIMEOUT=${CHECK_TIMEOUT:-300}
ENGINES=${SMOKE_ENGINES:-}
SCHED_LOG=/var/log/scheduler/scheduler.log
JOBS=/srv/scheduler/jobs/jobs.yaml
REPOSITORY=/srv/scheduler/repository
started=$(date +%s)

[ $# -ge 2 ] || { echo "usage: sh $0 <smoke|cycles|baseline|f10> <playground> [<gmctl fit option>...]" >&2; exit 2; }
MODE=$1 PG=$2; shift 2
case $MODE in
    smoke) LOCAL_AT=${SMOKE_LOCAL_AT:-07:30} ;;
    cycles) LOCAL_AT=${SMOKE_LOCAL_AT:-18:00} ;;
    baseline) LOCAL_AT=${SMOKE_LOCAL_AT:-10:30} ;;
    f10) LOCAL_AT=${SMOKE_LOCAL_AT:-23:30} ;;
    *) echo "unknown mode $MODE: smoke, cycles, baseline or f10" >&2; exit 2 ;;
esac
case $PG in ''|*/*) echo "not a playground name: $PG" >&2; exit 2 ;; esac
[ -f "$SOURCE/scenario.yaml" ] || { echo "no scenario.yaml in $SOURCE" >&2; exit 2; }

failures=0
passes=0
pass() { printf '%s PASS  %s\n' "$(date -u +%H:%M:%S)" "$*"; passes=$((passes + 1)); }
fail() { printf '%s FAIL  %s\n' "$(date -u +%H:%M:%S)" "$*"; failures=$((failures + 1)); }
info() { printf '%s ....  %s\n' "$(date -u +%H:%M:%S)" "$*"; }
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}
iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }

dk() {     # dk <engine> <docker arguments>: the manager ("local") or another engine
    e=$1; shift
    if [ "$e" = local ]; then docker "$@"; else docker -H "$e" "$@"; fi
}

# Everything still carrying one of the game's labels on any engine, one per line.
labelled() {
    for e in local $ENGINES; do
        for l in $LABELS; do
            if [ "$e" = local ]; then
                for k in $KINDS; do
                    docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
                done
            fi
            dk "$e" volume ls --filter "label=$l=$GAME" --format "$e volume {{.Name}}"
            dk "$e" ps -a --filter "label=$l=$GAME" --format "$e container {{.Names}}"
        done
    done | sort -u
}

UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
units() {
    {
        systemctl --user list-units --all --plain --no-legend "dbagm-${GAME}_*" 2>/dev/null \
            | awk '{ print $1 }'
        for f in "$UNIT_DIR"/"dbagm-${GAME}_"*; do [ -e "$f" ] && echo "file $f"; done
    } | sort -u
}

# --- the game ---------------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }
systemctl --user show --property=Version >/dev/null 2>&1 \
    || { echo "the user's systemd manager does not answer (systemctl --user)" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-purposes.XXXXXX")
SCN=$tmp/$(basename "$SOURCE")
GAME=
deployed=no
cleanup() {
    set +e
    if [ "$deployed" = yes ]; then
        info "cleanup: gmctl teardown"
        $GMCTL teardown "$SCN" --playground "$PG"
        left=$(labelled; units)
        [ -z "$left" ] || echo "WARNING: objects of game $GAME left behind: $left"
    fi
    rm -rf "${tmp:?}"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

cp -R "$SOURCE" "$SCN"
rm -rf "${SCN:?}/local"
LDIR=$SCN/local/$PG
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
on() {     # on <node> <user> [gmctl exec options]: the script on stdin, run there
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}
get() {    # get <node> <user> <path> <local file>
    printf 'cat %s\n' "$3" | on "$1" "$2" > "$4"
}
put() {    # put <node> <user> <path> <local file>: its bytes written in place (owner, mode kept)
    { printf "base64 -d > %s <<'GM_EOF'\n" "$3"; base64 < "$4"; printf 'GM_EOF\n'; } \
        | on "$1" "$2" >/dev/null
}
instances() { python3 -c 'import sys, yaml
print(",".join(f["id"] for f in yaml.safe_load(open(sys.argv[1]))["fault_instances"]))' "$SCN/scenario.yaml"; }

info "mode $MODE, scenario $(basename "$SOURCE")"
if [ "$MODE" = baseline ]; then
    info "the unfaulted copy: $($H baseline "$SCN" "$FIXTURE")"
fi
if $GMCTL fit "$SCN" --playground "$PG" "$@"; then pass "fit $*"; else fail "fit"; exit 1; fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
info "game id $GAME"
set -- $($H handover "$LOCAL_AT" "$(( $(date +%s) + 600 ))")
HANDOVER=$1 SHIFT=$2
set --
[ "$MODE" = baseline ] && set -- --test-leave-out "$(instances)"
info "gmctl render --handover $HANDOVER $* (shift $SHIFT: the scenario's time at T0 about $LOCAL_AT)"
if $GMCTL render "$SCN" --playground "$PG" --handover "$HANDOVER" "$@"; then pass "render"; else fail "render"; exit 1; fi
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG"; then pass "deploy"; else fail "deploy"; exit 1; fi
set +e
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
$GMCTL start-load "$SCN" --playground "$PG"
same "start-load: exit 0" 0 "$?"
same "status: stage load-started" load-started "$(stage)"
T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
PLANNED=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["timeline"]["planned_handover"])' "$LDIR/implementation.yaml")
info "T0 $T0, scenario time $($H local "$T0S" "$SHIFT"), planned hand-over $PLANNED"
[ -n "$T0" ] || exit 1

# The pooler's PgBouncer resolving its server. One started before Swarm's
# DNS knew `db` may fail every lookup ("DNS lookup failed: db: result=0")
# until its process restarts: seen in two of three runs on 2026-11-02,
# fixed in pgbouncer 0.1.1 by a bounded start-up wait (D305). The harness
# keeps a safety net, counted: it restarts PgBouncer's process once (s6,
# as root on the pooler), says so on a WORKAROUND line, and fails if that
# does not help: the runs judge the scenario, not this start-up race.
WORKAROUNDS=0
pooler_failing() {   # a DNS failure in PgBouncer's log within the last minute
    last=$(printf "grep 'DNS lookup failed' /var/log/pgbouncer/pgbouncer.log | tail -n 1 | cut -c1-19\n" \
        | on pooler root 2>/dev/null)
    [ -n "$last" ] && [ "$(date -u -d "$last" +%s)" -ge $(( $(date +%s) - 60 )) ]
}
wait=$(( T0S + 90 - $(date +%s) ))
[ "$wait" -gt 0 ] && sleep "$wait"
# Its start-up wait for the server's name (pgbouncer 0.1.1, D305), as logged.
info "pooler start-up: [$($GMCTL logs "$SCN" --playground "$PG" --node pooler 2>&1 \
    | sed -n 's/.*pgbouncer-run: //p' | tr '\n' ';')]"
if pooler_failing; then
    printf '%s WORKAROUND  pooler: PgBouncer fails to resolve its server 90 s after T0 (last %s UTC); its process restarted (s6-svc -r)\n' \
        "$(date -u +%H:%M:%S)" "$last"
    WORKAROUNDS=$((WORKAROUNDS + 1))
    printf '/command/s6-svc -r /run/service/pgbouncer\n' | on pooler root
    sleep 75
    if pooler_failing; then
        fail "pooler: PgBouncer still fails to resolve its server after its restart (last: $last UTC)"
        exit 1
    fi
fi
pass "pooler: PgBouncer resolves its server (no DNS failure in the last minute)"

# --- runners, moves, readings -------------------------------------------------
sched_lines() {  # sched_lines <node>: the runner's run and reload lines
    printf "grep -E ' (run|reload) ' %s\n" "$SCHED_LOG" | on "$1" root
}
reload() {       # reload <node>: as a player may, or as root on a report-only node (bi)
    since=$(( $(date +%s) - 2 ))
    if [ "$1" = bi ]; then
        printf '/command/s6-svc -h /run/service/scheduler\n' | on bi root >/dev/null
    else
        printf 'sudo gm-reload-scheduler\n' | on "$1" player >/dev/null
    fi
    rc=$?
    i=0
    while [ "$i" -lt 30 ]; do
        RELOADED=$(sched_lines "$1" | $H reload-after "$since")
        [ -n "$RELOADED" ] && { info "$1 reloaded at $(iso "$RELOADED")"; return 0; }
        i=$((i + 1)); sleep 2
    done
    fail "$1: no reload status=ok after the reload (exit $rc)"
    return 1
}
move() {         # move <node> <job>...: each job one minute after the previous, the first one to two minutes ahead
    n=$1; shift
    who=player; [ "$n" = bi ] && who=root
    [ -f "$tmp/orig-$n-jobs.yaml" ] || get "$n" root "$JOBS" "$tmp/orig-$n-jobs.yaml"
    get "$n" root "$JOBS" "$tmp/cur-jobs.yaml"
    now=$(date +%s)
    MOVED=$(( (now + 119) / 60 * 60 ))
    [ $((MOVED - now)) -ge 70 ] || MOVED=$((MOVED + 60))
    pairs= t=$MOVED
    for j in "$@"; do pairs="$pairs $j=$t"; t=$((t + 60)); done
    $H move-jobs "$tmp/cur-jobs.yaml" "$tmp/new-jobs.yaml" $pairs \
        || { fail "move $n $*: jobs.yaml not rewritten"; return 1; }
    put "$n" "$who" "$JOBS" "$tmp/new-jobs.yaml"
    reload "$n" || return 1
    info "moved $n: $* from $(iso "$MOVED") ($($H local "$MOVED" "$SHIFT") scenario time)"
}
restore() {      # restore <node>: its jobs.yaml as deployed, byte for byte, reloaded
    n=$1
    [ -f "$tmp/orig-$n-jobs.yaml" ] || return 0
    who=player; [ "$n" = bi ] && who=root
    put "$n" "$who" "$JOBS" "$tmp/orig-$n-jobs.yaml"
    reload "$n"; rrc=$?
    get "$n" root "$JOBS" "$tmp/back-jobs.yaml"
    if ! cmp -s "$tmp/orig-$n-jobs.yaml" "$tmp/back-jobs.yaml"; then
        fail "$n: jobs.yaml not restored byte for byte"
    elif [ "$rrc" -ne 0 ]; then
        fail "$n: jobs.yaml restored byte for byte, not reloaded"
    else
        pass "$n: jobs.yaml restored byte for byte and reloaded"
    fi
    rm -f "$tmp/orig-$n-jobs.yaml"
}
wait_run() {     # wait_run <node> <job> <from epoch> [<timeout s>]: RUN_STATUS, RUN_END of its first run ending since
    deadline=$(( $(date +%s) + ${4:-900} ))
    RUN_STATUS= RUN_END=
    while [ "$(date +%s)" -lt "$deadline" ]; do
        r=$(sched_lines "$1" | $H runs "$2" "$3" | head -n 1)
        if [ -n "$r" ]; then
            RUN_STATUS=${r% *} RUN_END=${r#* }
            info "$1 $2: run ended $(iso "$RUN_END"), status=$RUN_STATUS"
            return 0
        fi
        sleep 15
    done
    fail "$1 $2: no run ended within ${4:-900} s of $(iso "$3")"
    return 1
}
reading() {      # reading <instance> [<since>]: VERDICT and LINE of one gmctl check run
    out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG" --instance "$1" \
        ${2:+--since "$2"} 2>&1)
    VERDICT=$(printf '%s\n' "$out" | $H verdict "$1")
    LINE=$(printf '%s\n' "$out" | grep "^$1 " | head -n 1)
    [ -n "$LINE" ] || LINE=$(printf '%s' "$out" | tail -n 1)
}
await() {        # await <instance> <verdict> <timeout s> [<since>]: polled every 30 s
    deadline=$(( $(date +%s) + $3 )) t=$(date +%s)
    while :; do
        guard
        reading "$1" "${4:-}"
        [ "$VERDICT" = "$2" ] && { pass "$1 reads $2 after $(( $(date +%s) - t )) s: $LINE"; return 0; }
        [ "$(date +%s)" -ge "$deadline" ] && break
        sleep 30
    done
    fail "$1 does not read $2 within $3 s: $LINE"
    return 1
}
expect() {       # expect <instance> <verdict> [<since>]: one reading
    reading "$1" "${3:-}"
    same "$1 reads $2 ($LINE)" "$2" "$VERDICT"
}
DEADLINE=
guard() {        # cycles: f10's entry runs at 03:00 local; stop before
    [ -n "$DEADLINE" ] && [ "$(date +%s)" -ge "$DEADLINE" ] && {
        fail "02:45 scenario time reached: f10's 03:00 entry would run; stopping"
        exit 1
    }
    return 0
}
sql() {          # sql <node> <database>: SQL on stdin, as dba (the players' console role)
    { printf "PGPASSFILE=/home/player/.pgpass psql -X -q -v ON_ERROR_STOP=1 -U dba -d %s <<'GM_SQL'\n" "$2"
      cat; printf 'GM_SQL\n'; } \
        | on "$1" player
}
schedulers() { python3 -c 'import sys, yaml
print(" ".join(n["name"] for n in yaml.safe_load(open(sys.argv[1]))["nodes"] if n["brick"]["id"] == "scheduler"))' "$SCN/scenario.yaml"; }

keys_running() {  # every scheduler: every key current since T0 with calls (the timeline applied;
                  # judged at the end of the run, a key by its expected calls: the helper's keys)
    for n in $(schedulers); do
        lines=$(printf "grep ' key minute=' %s\n" "$SCHED_LOG" | on "$n" root)
        k=$(printf '%s\n' "$lines" | $H keys "$SCN" "$n" "$T0S" "$(date +%s)" "$PLANNED" "$SHIFT")
        same "scheduler $n: every key current since T0 called (by its rate)" ok "$(printf '%s\n' "$k" | sed 's/^ok .*/ok/')"
        info "  $n: $k"
    done
}
jobs_ran() {      # every job of every runner, db's crontab entry, reporting's pg_cron job
    for n in $(schedulers); do
        get "$n" root "$JOBS" "$tmp/j.yaml"
        for j in $(python3 -c 'import sys, yaml
print(" ".join(j["name"] for j in yaml.safe_load(open(sys.argv[1]))["jobs"] or []))' "$tmp/j.yaml"); do
            r=$(sched_lines "$n" | $H runs "$j" "$T0S" | awk '{ s[$1]++ } END { for (k in s) printf "%s=%d ", k, s[k] }')
            if [ -n "$r" ]; then pass "job $n $j ran since T0: $r"; else fail "job $n $j: no run since T0"; fi
        done
    done
    m=$(printf "stat -c %%Y /var/log/postgresql/cron/popular-products.log 2>/dev/null || echo 0\n" | on db root)
    if [ "${m:-0}" -ge "$T0S" ]; then pass "db's crontab entry ran since T0 (its log written $(iso "$m"))"
    else fail "db's crontab entry: no run since T0"; fi
    if [ "$MODE" != baseline ]; then
        c=$(printf "psql -X -Atq -d reporting -c \"SELECT count(*) || ' ' || coalesce(max(status), '-') FROM cron.job_run_details WHERE end_time > '%s'\"\n" "$T0" | on reporting postgres)
        case $c in 0*|'') fail "reporting's pg_cron job: no run since T0 ($c)" ;;
                   *) pass "reporting's pg_cron job ran since T0 (runs, last status: $c)" ;; esac
    fi
}
memory() {        # every game container's memory, on every engine
    for e in local $ENGINES; do
        dk "$e" stats --no-stream --format '{{.Name}} {{.MemUsage}}' 2>/dev/null \
            | grep "^${GAME}_" | sed "s/^${GAME}_/  $e /; s/\.[0-9]*\.[a-z0-9]* / /"
    done
}

# --- the smoke steps: every fault planted at once, every key and job running ----
CLOSE_END= INVOICED=
# crm's leads and campaign moved until each of $* has read present once, each
# in its own round's reading (a reload raises their judged moment, so a
# reading is the runs since that round's move): f2 shows only when a
# customer of the segment unsubscribed between two extractions, f3 only
# while the company's mail window is open (08:00-21:00 its time). Up to
# ROUNDS rounds (5). With EARLIER=yes an instance that read present in an
# earlier call of this run (SEEN_<id>) passes on that reading: f2's cycle,
# its fresh unsubscribes being rare once the first extraction took the
# backlog.
crm_campaign() {
    rounds=${ROUNDS:-5} round=1 missing=$*
    while [ "$round" -le "$rounds" ]; do
        guard
        move crm leads-extract mail-campaign || return 1
        wait_run crm leads-extract "$MOVED" 600
        wait_run crm mail-campaign "$((MOVED + 60))" 600
        left=
        for i in $missing; do
            reading "$i"
            info "  round $round: $LINE"
            if [ "$VERDICT" = present ]; then
                eval "SEEN_$i=\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            else
                left="$left $i"
            fi
        done
        missing=${left# }
        [ -z "$missing" ] && { pass "$*: each read present after crm's campaign moved (by round $round)"; return 0; }
        round=$((round + 1))
        [ "$round" -le "$rounds" ] && { info "  not present yet: $missing; again in 10 min"; sleep 600; }
    done
    left=
    for i in $missing; do
        eval "seen=\${SEEN_$i:-}"
        if [ "${EARLIER:-no}" = yes ] && [ -n "$seen" ]; then
            pass "$i: not present again in $rounds round(s); its present reading of $seen in this run, same planting, stands for its cycle"
        else
            left="$left $i"
        fi
    done
    [ -z "$left" ] && return 0
    fail "$*: not present after $rounds round(s):$left"
    return 1
}
smoke_steps() {
    wait=$(( T0S + LOAD_MINUTES * 60 + 75 - $(date +%s) ))
    [ "$wait" -gt 0 ] && { info "$LOAD_MINUTES minutes of schedules: ${wait} s"; sleep "$wait"; }
    info "gmctl inject --at now --instance f10 (a test harness: planted at once; its entry never moved here)"
    $GMCTL inject "$SCN" --playground "$PG" --at now --instance f10
    same "inject --at now: f10 planted" 0 "$?"

    crm_campaign f2 f3
    await f1 present 1500
    restore crm

    move producer close-day && wait_run producer close-day "$MOVED" 900
    same "producer close-day (the invoicing) ran ok" ok "$RUN_STATUS"
    INVOICED=$RUN_END
    move bi rollup-hourly rollup-close
    hourly=$MOVED
    wait_run bi rollup-hourly "$hourly" 900
    same "bi rollup-hourly ran ok after the close" ok "$RUN_STATUS"
    wait_run bi rollup-close "$((hourly + 60))" 900
    same "bi rollup-close (the nightly close) ran ok" ok "$RUN_STATUS"
    CLOSE_END=$RUN_END
    if ! await f4 present 240; then      # one more hourly run, the source settled
        move bi rollup-hourly && wait_run bi rollup-hourly "$MOVED" 900 && await f4 present 240
    fi
    await f7 present 240
    restore bi
    restore producer

    info "gmctl inject --at now --instance f5 (after the close, as in the aging: handover-5h)"
    $GMCTL inject "$SCN" --playground "$PG" --at now --instance f5
    same "inject --at now: f5 planted" 0 "$?"
    await f5 present 300
    expect f6 present
    expect f9 present
    expect f10 error
    case $LINE in *"no kill"*|*"did not happen"*|*"not happen"*) pass "f10: planted, no incident (its entry not moved)" ;;
                  *) info "f10's line: $LINE" ;; esac
    info "memory (docker stats):"
    memory
}

# --- the cycles: each fault's acceptance fix (W4 item 7) ------------------------
fix_crm() {       # fix_crm <key> <source file>: the entry swapped in crm's queries.yaml, as player
    get crm root "$REPOSITORY/queries.yaml" "$tmp/q.yaml"
    $H swap-entry "$tmp/q.yaml" "$2" "$1" "$tmp/q-new.yaml" || { fail "crm $1: not swapped"; return 1; }
    put crm player "$REPOSITORY/queries.yaml" "$tmp/q-new.yaml"
}
until_minute() {  # until_minute <mod> <rem>: sleep to the next UTC minute m with m % mod == rem, +20 s
    while :; do
        m=$(date -u +%-M); s=$(date -u +%-S)
        [ $((m % $1)) -eq "$2" ] && [ "$s" -ge 20 ] && [ "$s" -lt 50 ] && return 0
        sleep 10
    done
}
cycles() {
    DEADLINE=$($H next-local "$T0S" "$SHIFT" 02:45)
    info "cycles until $(iso "$DEADLINE") at the latest (02:45 scenario time)"

    info "--- f6: db's crontab as the fixture's, by sudo gm-crontab"
    put db player /home/player/db.cron "$FIXTURE/nodes/db/crontab"
    printf 'sudo gm-crontab /home/player/db.cron\n' | on db player
    same "f6 fix: gm-crontab exit 0" 0 "$?"
    await f6 fixed 120

    info "--- f9: the job unscheduled by id, the copy, the foreign table, the server dropped"
    sql reporting reporting <<'EOF'
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'customer-activity';
DROP TABLE rpt.customer_activity;
DROP FOREIGN TABLE src.customers;
DROP SERVER shop_backoffice CASCADE;
EOF
    same "f9 fix: exit 0" 0 "$?"
    await f9 fixed 120

    info "--- f1: mail.shipped as the mailing purpose's"
    await f1 present 1500
    until_minute 5 1
    fix_crm mail.shipped "$FIXTURE/nodes/crm/queries.yaml" && reload crm
    expect f1 too-soon
    await f1 fixed 900

    info "--- f2: leads.extract as the leads purpose's, mail.campaign's consent restored (f3's change left)"
    ROUNDS=3 EARLIER=yes crm_campaign f2
    fix_crm leads.extract "$FIXTURE/nodes/crm/queries.yaml" \
        && fix_crm mail.campaign "$REPO/faults/purpose-mail-outside-hours/inject/queries.yaml.snippet" \
        && reload crm
    expect f2 too-soon
    round=1
    while [ "$round" -le 5 ]; do
        guard
        move crm leads-extract mail-campaign
        wait_run crm leads-extract "$MOVED" 600
        wait_run crm mail-campaign "$((MOVED + 60))" 600
        reading f2; info "  round $round: $LINE"
        [ "$VERDICT" = fixed ] && break
        round=$((round + 1)); [ "$round" -le 5 ] && sleep 600
    done
    same "f2 reads fixed after its fix and the jobs moved again ($LINE)" fixed "$VERDICT"
    reading f3
    same "f3, its own invariant, still present after f2's fix ($LINE)" present "$VERDICT"

    info "--- f3: mail.campaign as the mailing purpose's"
    fix_crm mail.campaign "$FIXTURE/nodes/crm/queries.yaml" && reload crm
    expect f3 too-soon
    round=1
    while [ "$round" -le 5 ]; do
        guard
        move crm mail-campaign
        wait_run crm mail-campaign "$MOVED" 600
        reading f3; info "  round $round: $LINE"
        [ "$VERDICT" = fixed ] && break
        round=$((round + 1)); [ "$round" -le 5 ] && sleep 600
    done
    same "f3 reads fixed after its fix and the job moved again ($LINE)" fixed "$VERDICT"
    restore crm
    CRM_DONE=$(date +%s)

    info "--- f5: ALTER ROLE shop_etl VALID UNTIL 'infinity' as dba on db; --since its instant"
    expect f5 present
    sql db shop <<'EOF'
ALTER ROLE shop_etl VALID UNTIL 'infinity';
EOF
    same "f5 fix: exit 0" 0 "$?"
    S5=$(iso "$(date +%s)")
    expect f5 too-soon "$S5"
    move bi rollup-hourly && wait_run bi rollup-hourly "$MOVED" 900
    same "bi rollup-hourly ran ok after f5's fix" ok "$RUN_STATUS"
    await f5 fixed 300 "$S5"
    restore bi

    info "--- f7: rpt.close_day() as the purpose's, as dba on reporting; --since its instant"
    expect f7 present
    $H procedure "$SCN/data/reporting.sql" 'rpt.close_day()' | sql reporting reporting
    same "f7 fix: exit 0" 0 "$?"
    S7=$(iso "$(date +%s)")
    expect f7 too-soon "$S7"
    gap=$(( CLOSE_END + 16 * 60 - $(date +%s) ))
    [ "$gap" -gt 0 ] && { info "the next close more than 15 min after the last (W4 item 9): ${gap} s"; sleep "$gap"; }
    move bi rollup-close
    idle=$(( MOVED - CLOSE_END ))
    wait_run bi rollup-close "$MOVED" 900
    same "W4 item 9: bi rollup-close ran ok $idle s after the previous close (fdw link idle > 900 s)" ok "$RUN_STATUS"
    err=$(printf "grep -c 'sqlstate=08' %s || true\n" "$SCHED_LOG" | on bi root)
    info "W4 item 9: bi's log, connection-class errors (sqlstate=08...) since its start: ${err:-0}"
    await f7 fixed 300 "$S7"
    restore bi

    info "--- f4: bi's scripts/rollup.py as the purpose's, as root, s6's SIGHUP"
    put bi root "$REPOSITORY/scripts/rollup.py" "$FIXTURE/nodes/bi/scripts/rollup.py" && reload bi
    expect f4 too-soon

    info "--- f8: escalate.customs as the export purpose's, once it reads present"
    await f8 present 9000
    fix_crm escalate.customs "$FIXTURE/nodes/crm/queries.yaml" && reload crm
    expect f8 too-soon

    info "--- f4: a close of day after a local midnight, the hourly run after it"
    mid=$($H next-local "$INVOICED" "$SHIFT" 00:01)     # the first midnight after the close that showed f4
    [ "$(date +%s)" -lt "$mid" ] && { info "waiting for $(iso "$mid") (00:01 scenario time)"; sleep $(( mid - $(date +%s) )); }
    guard
    move producer close-day && wait_run producer close-day "$MOVED" 900
    same "producer close-day ran ok after the local midnight" ok "$RUN_STATUS"
    restore producer
    round=1
    while [ "$round" -le 3 ]; do
        move bi rollup-hourly && wait_run bi rollup-hourly "$MOVED" 900
        reading f4; info "  round $round: $LINE"
        [ "$VERDICT" = fixed ] && break
        round=$((round + 1)); [ "$round" -le 3 ] && sleep 300
    done
    same "f4 reads fixed after the close and the hourly run ($LINE)" fixed "$VERDICT"
    restore bi

    info "--- f8: fixed"
    await f8 fixed 9000
}

# --- baseline and f10 ---------------------------------------------------------
baseline_steps() {
    out=$($GMCTL check "$SCN" --playground "$PG" 2>&1)
    same "check: no instance checked (every one left out)" "" \
        "$(printf '%s\n' "$out" | grep -E '^f[0-9]+ ' || true)"
    wait=$(( T0S + LOAD_MINUTES * 60 + 75 - $(date +%s) ))
    [ "$wait" -gt 0 ] && { info "$LOAD_MINUTES minutes of schedules: ${wait} s"; sleep "$wait"; }
    move crm leads-extract mail-campaign && wait_run crm leads-extract "$MOVED" 600 \
        && wait_run crm mail-campaign "$((MOVED + 60))" 600
    restore crm
    move producer close-day && wait_run producer close-day "$MOVED" 900
    restore producer
    move bi rollup-hourly rollup-close && wait_run bi rollup-hourly "$MOVED" 900 \
        && wait_run bi rollup-close "$((MOVED + 60))" 900
    restore bi
    governance "after every runner's job ran"
    m17=$(( ( $(date +%s) / 3600 ) * 3600 + 17 * 60 + 90 ))
    [ "$m17" -le "$(date +%s)" ] && m17=$((m17 + 3600))
    info "waiting for db's :17 entry ($(iso "$m17"))"
    sleep $(( m17 - $(date +%s) ))
    jobs_ran
    governance "after db's crontab entry ran"
}
governance() {
    out=$(sh "$HERE/check-governance.sh" "$SCN" "$PG" "$T0" 2>&1); rc=$?
    printf '%s\n' "$out" | sed 's/^/      /'
    same "G1 to G4, $1: exit 0" 0 "$rc"
}
f10_steps() {
    pids() { printf 'for p in s6-svscan sshd cron; do printf "%%s=%%s " $p "$(pidof $p | tr " " ,)"; done; hostname\n' | on reporting root; }
    events() { printf 'printf "oom_kill=%%s peak=%%s" "$(sed -n "s/^oom_kill //p" /sys/fs/cgroup/memory.events)" "$(cat /sys/fs/cgroup/memory.peak)"\n' | on reporting root; }
    before=$(pids)
    info "reporting before: $before; $(events)"
    $GMCTL inject "$SCN" --playground "$PG" --at now --instance f10
    same "inject --at now: f10 planted" 0 "$?"
    printf 'sudo gm-crontab -l\n' | on reporting player > "$tmp/r.cron"
    now=$(date +%s); at=$(( (now + 119) / 60 * 60 )); [ $((at - now)) -ge 70 ] || at=$((at + 60))
    $H move-crontab "$tmp/r.cron" "$tmp/r-new.cron" 'rpt.sales_detail_rollup()' "$at" \
        && put reporting player /home/player/f10.cron "$tmp/r-new.cron" \
        && printf 'sudo gm-crontab /home/player/f10.cron\n' | on reporting player
    same "f10's entry moved to $(iso "$at") by sudo gm-crontab" 0 "$?"
    info "the entry runs at $(iso "$at") ($($H local "$at" "$SHIFT") scenario time)"
    await f10 present 2400
    i=0
    while [ "$i" -lt 40 ]; do
        printf 'psql -X -Atq -d reporting -c "SELECT 1"\n' | on reporting postgres 2>/dev/null | grep -qx 1 && break
        i=$((i + 1)); sleep 15
    done
    same "PostgreSQL on reporting accepts connections again" 1 \
        "$(printf 'psql -X -Atq -d reporting -c "SELECT 1"\n' | on reporting postgres 2>/dev/null)"
    after=$(pids)
    same "s6, sshd and cron untouched (pids, container)" "$before" "$after"
    info "reporting after: $(events)"
    printf 'grep -h -E "terminated by signal 9|ready to accept connections|reinitializing" /var/log/postgresql/postgresql-*.log | tail -n 6\n' \
        | on reporting root | sed 's/^/      /'
    sleep 120
    bad=$(docker service ls --filter "label=com.docker.stack.namespace=$GAME" \
        --format '{{.Name}} {{.Replicas}}' | awk '{ split($2, r, "/"); if (r[1] != r[2]) print }')
    same "every node's service running after the recovery" "" "$bad"
    info "memory (docker stats):"
    memory
}

case $MODE in
    smoke)
        smoke_steps
        await f8 present 9000
        jobs_ran ;;
    cycles)
        smoke_steps
        cycles
        jobs_ran ;;
    baseline) baseline_steps ;;
    f10) f10_steps ;;
esac
keys_running
info "gmctl check (every instance):"
timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG" 2>&1 | sed 's/^/      /'
same "the steps changed no stage" load-started "$(stage)"

# --- teardown -----------------------------------------------------------------
if $GMCTL teardown "$SCN" --playground "$PG"; then deployed=no; pass "teardown"; else fail "teardown"; fi
same "nothing labelled with game $GAME is left on any engine" "" "$(labelled)"
same "no systemd user unit of game $GAME is left" "" "$(units)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-purposes $MODE: all $passes checks passed in ${elapsed}s (game $GAME, T0 $T0; pooler workarounds: $WORKAROUNDS)"
else
    echo "smoke-purposes $MODE: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME, T0 $T0; pooler workarounds: $WORKAROUNDS)"
    exit 1
fi
