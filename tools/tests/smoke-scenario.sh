#!/bin/sh
# Scenario smoke deployment of gmctl on a real single-node swarm (build plan
# v0.2, "Wave gate": from wave 4, the v0.2 scenario and bookshop-new-server;
# rewritten for load by v0.3 chunk 12, master spec 11, "Smoke tests"; run
# after smoke.sh, smoke-monitoring.sh and smoke-load.sh, never at the same
# time as any of them or as another run of itself: all publish the
# bastion's ports).
#
# On a copy of a scenario as it is in the repository (scenarios/<scenario>,
# or a scenario folder given by its path, without any local implementation):
#   fit (the playground the scenario was designed for, on the local engine:
#   its designed_for host, by name, with that host's CPU, memory and disk;
#   a scenario designed for several hosts on this one host alone, every
#   designed host placed on it (fit's one-host form, the designed_for
#   placement unused), the playground named after the designed hosts and
#   declaring the sum of their CPU, memory and disk; images read from the
#   engine) -> render -> deploy -> load-data -> inject.
#   A scenario with scheduler nodes (spec D157, D158) is a short game with
#   load: rendered with --handover (a whole hour past now plus its aging
#   minimum), then start-load (T0; the early check's host timer armed), the
#   faults due during the aging planted at once with inject --at now (a test
#   harness, never a game), and a few minutes of schedules (LOAD_MINUTES:
#   3 by default, 12 for tarnbeck-outdoor-shop, see below) after which every
#   scheduler key is running: summarised every minute since T0 by its
#   scheduler, and called, counted in its metrics. Keys are read as
#   smoke-purposes.{sh,py} reads them (v0.4 bf5dbf5): through the
#   schedule's timeline as applied at the run's time (a key set at or
#   before T0 replaces the stream's at T0; a change during the minutes
#   splits them), and judged by rate: a key without a call fails only when
#   its rate, shape and intensity give it 4 calls or more over the minutes
#   (scenario hours, render's shift applied); a slower one is listed "not
#   judged", its key lines still required. A scenario with none is
#   rendered without --handover and has no start-load, as in v0.2. Then:
#   - check: one line per fault instance, in fault_instances order, each
#     reading what the scenario's files expect of a smoke run: present; or
#     too-soon for a check judging runs or triggers (its answer-key
#     entry's judges: no run in its window yet); or error for an incident
#     check (master spec 12.7: its fault's resolutions the report alone,
#     no judges), its incident not in the evidence yet. The exit the
#     readings give (2 with an error, else 1 with a present, else 3);
#     polled for up to 120 s, each run within a time limit (CHECK_TIMEOUT,
#     180 s), a check reading Prometheus' live state lagging up to one
#     scrape interval behind;
#   - validate: the verdicts the answer key gives at hand-over. A node is
#     expected red when an instance's evidence is "the public validator on
#     <node>" showing a RED line, or when validators_left_red names it; each
#     such rule must be among that node's RED lines. Every other node is
#     expected green. Exit 1 when a node is expected red, else 0;
#   - the evaluation changed no stage (injected; load-started with load);
#   -> teardown, then nothing labelled with the game id is left (its
#   systemd user timers and services included) and the objects not
#   belonging to the game are unchanged.
#
# No credential goes on a command line or in `gmctl exec --env`: the script
# reads none; the sealed checks and the validators read theirs inside the
# nodes.
#
# Needs: a swarm manager on the local engine (docker swarm init), python3
# (with PyYAML, as gmctl) on the host, the user's systemd manager
# (systemctl --user) for a scenario with scheduler nodes, and the
# scenario's bricks' images built locally (fit refuses a missing one and
# names its build command):
#   docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
#   docker build -t 127.0.0.1:5000/dbagm/bastion:0.5.0 bricks/bastion
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus
#   docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.0 bricks/postgres-exporter
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.3.0 bricks/grafana
#   docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.1 bricks/pgbouncer
#   docker build -t 127.0.0.1:5000/dbagm/scheduler:0.3.0 bricks/scheduler
# Host ports 2222 and 8080 must be free (the bastion's published ports).
# Usage: sh tools/tests/smoke-scenario.sh <scenario>        (from anywhere)
#   e.g. sh tools/tests/smoke-scenario.sh fernway-clinics-monitoring
#        sh tools/tests/smoke-scenario.sh bookshop-new-server
#        sh tools/tests/smoke-scenario.sh tarnbeck-outdoor-shop
#        sh tools/tests/smoke-scenario.sh path/to/a/scenario-folder
# LOAD_MINUTES=<n> in the environment overrides the minutes of schedules.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
LABELS="com.docker.stack.namespace dbagm.game"
KINDS="service network volume config secret"
CHECK_TIMEOUT=${CHECK_TIMEOUT:-180}    # seconds one gmctl check run may take
started=$(date +%s)

[ $# -eq 1 ] || { echo "usage: sh $0 <scenario>   (a folder of $REPO/scenarios, or a path)" >&2; exit 2; }
case $1 in
    */*) SRC=$(cd "$1" 2>/dev/null && pwd) || { echo "no folder $1" >&2; exit 2; } ;;
    *) SRC=$REPO/scenarios/$1 ;;
esac
NAME=$(basename "$SRC")
[ -f "$SRC/scenario.yaml" ] && [ -f "$SRC/gm/answer-key.yaml" ] \
    || { echo "no scenario $1 (no scenario.yaml and gm/answer-key.yaml in $SRC)" >&2; exit 2; }
# The minutes of schedules a scenario needs before every stream key has ended
# a call: tarnbeck-outdoor-shop's f4 holds its first call five minutes after
# the first arrival and its reports.best-days stream runs every five minutes
# (20/h) at office hours' 0.6 in the evening, so 12 (gm/notes.md).
case $NAME in
    tarnbeck-outdoor-shop) LOAD_MINUTES=${LOAD_MINUTES:-12} ;;
    *) LOAD_MINUTES=${LOAD_MINUTES:-3} ;;
esac

failures=0
passes=0
pass() { printf 'PASS  %s\n' "$*"; passes=$((passes + 1)); }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
info() { printf '....  %s\n' "$*"; }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
same() {   # same <description> <expected> <actual>
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected [$2], got [$3])"; fi
}

# Objects on the engine that do not carry the game's labels, one per line.
others() {
    for k in $KINDS; do
        docker "$k" ls --format "$k {{.Name}}"
    done | { grep -v " ${GAME}_" || true; } | sort
}

# Everything still carrying one of the game's labels, one per line.
labelled() {
    for l in $LABELS; do
        for k in $KINDS; do
            docker "$k" ls --filter "label=$l=$GAME" --format "$k {{.Name}}"
        done
        docker ps -a --filter "label=$l=$GAME" --format 'container {{.Names}}'
    done | sort -u
}

# The game's systemd user units (loaded, or as files), one per line; none
# when the user's manager does not answer, as in a game with no timer.
UNIT_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
STAMP_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/systemd/timers
units() {
    {
        systemctl --user list-units --all --plain --no-legend "dbagm-${GAME}_*" 2>/dev/null \
            | awk '{ print $1 }'
        systemctl --user list-unit-files --no-legend "dbagm-${GAME}_*" 2>/dev/null \
            | awk '{ print $1 }'
        for f in "$UNIT_DIR"/"dbagm-${GAME}_"* "$STAMP_DIR"/"stamp-dbagm-${GAME}_"*; do
            [ -e "$f" ] && echo "file $f"
        done
    } | sort -u
}

# scn <what>: read from the scenario copy's scenario.yaml and answer key.
#   playground  "<name> <cpu> <memory> <disk>": its designed_for host's; for
#               several, one playground named after them all, of their sum
#   designed    its designed_for hosts' names, comma-separated
#   aging       its aging minimum in seconds, empty with no scheduler node
#   schedulers  "<node>" per scheduler node, in nodes order
#   late        "<instance>" per instance planted during the aging (not T0)
#   checks      "<instance>\t<fault-id>\t<reading>[|<reading>]\t<why>" per
#               fault instance, in order: the readings a smoke run expects
#               (present; too-soon too for a check judging runs or
#               triggers; error too for an incident check), why the others
#   keyplan <node> <t0> <first> <end> <local dir>
#               "<key> <expected calls> judged|not-judged <minutes>|-" per
#               key current over the minutes [first, end) (epochs), the
#               timeline applied; <minutes>, comma-separated, those a key
#               holds whole (its key line due in each)
#   verdicts    "<node> green|red, ..." in nodes order, as validate's last line
#   red         "<node> <rule>" per RED line the answer key expects
scn() {
    w=$1; shift
    python3 -B - "$SCN" "$w" "$REPO" "$@" <<'EOF'
import re, sys, yaml
scn, what, args = sys.argv[1], sys.argv[2], sys.argv[4:]
sys.path.insert(0, sys.argv[3])
from tools.gm.model import format_size, parse_cpu, parse_size
s = yaml.safe_load(open(scn + "/scenario.yaml"))
key = yaml.safe_load(open(scn + "/gm/answer-key.yaml"))
sched = [n for n in s["nodes"] if n["brick"]["id"] == "scheduler"]
red = []
for inst in key.get("instances") or []:
    for ev in inst.get("evidence") or []:
        m = re.match(r"the public validator on (\S+)$", str(ev.get("source", "")).strip())
        r = re.match(r"RED (\S+?):", str(ev.get("shows", "")).strip())
        if m and r:
            red.append((m.group(1), r.group(1)))
    for left in inst.get("validators_left_red") or []:
        r = re.match(r"(?:RED )?(\S+?):", str(left.get("rule", "")).strip())
        red.append((left["node"], r.group(1) if r else ""))
if what == "playground":
    hosts = s["designed_for"]["hosts"]
    if len(hosts) == 1:
        h = hosts[0]
        print(h["name"], h["cpu"], h["memory"], h["disk"])
    else:
        cpu = sum(parse_cpu(h["cpu"]) for h in hosts)
        print("-".join(str(h["name"]) for h in hosts), "%g" % cpu,
              format_size(sum(parse_size(h["memory"]) for h in hosts)),
              format_size(sum(parse_size(h["disk"]) for h in hosts)))
elif what == "designed":
    print(", ".join(str(h["name"]) for h in s["designed_for"]["hosts"]))
elif what == "aging":
    if sched:
        m = re.match(r"^(\d+)([smhd])$", str(s["aging"]["minimum"]))
        print(int(m.group(1)) * {"s": 1, "m": 60, "h": 3600, "d": 86400}[m.group(2)])
elif what == "schedulers":
    for n in sched:
        print(n["name"])
elif what == "keyplan":
    import datetime, importlib.util
    spec = importlib.util.spec_from_file_location(
        "smoke_purposes", sys.argv[3] + "/tools/tests/smoke-purposes.py")
    rules = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(rules)             # its rate rule: expected_calls, JUDGED
    node, t0, first, end, ldir = args[0], float(args[1]), float(args[2]), float(args[3]), args[4]
    tl = yaml.safe_load(open(ldir + "/implementation.yaml"))["timeline"]
    planned = tl["planned_handover"]
    if not isinstance(planned, datetime.datetime):
        planned = datetime.datetime.strptime(str(planned), "%Y-%m-%dT%H:%M:%SZ")
    if planned.tzinfo is None:
        planned = planned.replace(tzinfo=datetime.timezone.utc)
    shift = int(tl.get("shift") or 0)
    n = next(x for x in s["nodes"] if x["name"] == node)
    doc = yaml.safe_load(open(scn + "/" + n["seed_files"]["schedule.yaml"]))
    shapes, intensity = doc.get("shapes") or {}, float(doc.get("intensity", 1.0))

    def moment(text):     # as render: handover-<N>h before the planned hand-over, else T0
        m = rules.MOMENT_RE.match(str(text))
        return (planned - datetime.timedelta(hours=int(m.group(1)))).timestamp() if m else t0

    minutes = [first + 60 * i for i in range(int((end - first) // 60))]
    plan = {}                                  # key -> [expected calls, minutes held whole]
    for st in doc.get("streams") or []:
        changes = sorted(((moment(c.get("at")), c.get("set") or {}) for c in doc.get("timeline") or []
                          if c.get("stream") == st["key"]), key=lambda c: c[0])
        cur, start, spans = dict(st), first, []
        for when, sets in changes:             # at or before T0 (and before first): applied
            if when >= end:
                break
            if when > start:
                spans.append((dict(cur), start, when))
                start = when
            cur.update({k: v for k, v in sets.items() if k in ("key", "rate")})
        spans.append((cur, start, end))
        for stream, a, b in spans:
            entry = plan.setdefault(stream["key"], [0.0, []])
            entry[0] += rules.expected_calls(stream, shapes, intensity, a, b, shift)
            entry[1] += [m for m in minutes if a <= m and m + 60 <= b]
    for key, (calls, held) in plan.items():
        print(key, "%.1f" % calls, "judged" if calls >= rules.JUDGED else "not-judged",
              ",".join(datetime.datetime.fromtimestamp(m, datetime.timezone.utc)
                       .strftime("%Y-%m-%dT%H:%MZ") for m in held) or "-")
elif what == "late":
    for f in s["fault_instances"]:
        if f.get("plant_at", "T0") != "T0":
            print(f["id"])
elif what == "checks":
    from tools.gm.model import find_definition
    entries = {e.get("instance"): e.get("sealed_check") or {}
               for e in key.get("instances") or [] if isinstance(e, dict)}
    for f in s["fault_instances"]:
        judges = entries.get(f["id"], {}).get("judges")
        fault, _, _ = find_definition("fault", f["fault"]["id"], f["fault"]["version"],
                                      scn, sys.argv[3])
        kinds = {r.get("kind") for r in (fault.data.get("resolutions") or [])} if fault else set()
        if judges in ("runs", "triggers"):
            alts, why = "present|too-soon", "judges %s: too soon before one in its window" % judges
        elif kinds == {"report"}:
            alts, why = "present|error", "an incident check (12.7): error before its incident"
        else:
            alts, why = "present", ""
        print("\t".join((f["id"], f["fault"]["id"], alts, why)))
elif what == "verdicts":
    reds = {n for n, _ in red}
    print(", ".join("%s %s" % (n["name"], "red" if n["name"] in reds else "green")
                    for n in s["nodes"]) + ".")
elif what == "red":
    for n, rule in sorted(set(red)):
        print(n, rule)
EOF
}

# --- preconditions --------------------------------------------------------
[ "$(docker info --format '{{.Swarm.LocalNodeState}} {{.Swarm.ControlAvailable}}')" = "active true" ] \
    || { echo "the local engine is not a swarm manager: docker swarm init" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmctl-smoke-scenario.XXXXXX")
SCN=$tmp/$NAME
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

cp -R "$SRC" "$SCN"
rm -rf "${SCN:?}/local"

host=$(scn playground) || exit 2
set -- $host
PG=$1 CPU=$2 MEMORY=$3 DISK=$4
LDIR=$SCN/local/$PG
AGING=$(scn aging)
if [ -n "$AGING" ]; then
    systemctl --user show --property=Version >/dev/null 2>&1 \
        || { echo "the user's systemd manager does not answer (systemctl --user)" >&2; exit 2; }
    LIVE=load-started
else
    LIVE=injected
fi
stage() { $GMCTL status "$SCN" --playground "$PG" | sed -n 's/^  stage: //p'; }
on() {     # on <node> <user> [gmctl exec options]: the script on stdin, run there
    n=$1 u=$2; shift 2
    $GMCTL exec "$SCN" --playground "$PG" --node "$n" --user "$u" "$@"
}

# --- local implementation ---------------------------------------------------
info "scenario $NAME"
DESIGNED=$(scn designed)
if [ "$DESIGNED" = "$PG" ]; then
    info "gmctl fit (the $PG playground: $CPU CPU / $MEMORY / $DISK)"
else
    info "gmctl fit (designed for $DESIGNED: all on this one host, playground $PG of their sum: $CPU CPU / $MEMORY / $DISK)"
fi
if $GMCTL fit "$SCN" --playground "$PG" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK"; then
    pass "fit: the images and the reservations fit $CPU CPU / $MEMORY / $DISK"
else
    fail "fit"
    exit 1
fi
GAME=$(sed -n 's/^game_id: *//p' "$LDIR/implementation.yaml")
[ -n "$GAME" ] || { echo "no game id in $LDIR/implementation.yaml" >&2; exit 1; }
info "game id $GAME"
if [ -n "$AGING" ]; then
    # A whole hour past now plus the aging minimum and an hour, so render
    # warns of nothing.
    HANDOVER=$(date -u -d "@$(( ($(date +%s) + AGING) / 3600 * 3600 + 7200 ))" +%Y-%m-%dT%H:00Z)
    info "gmctl render --handover $HANDOVER (scheduler nodes: the scenario ages)"
    set -- --handover "$HANDOVER"
else
    info "gmctl render (no scheduler node: no aging, nothing shifted)"
    set --
fi
if $GMCTL render "$SCN" --playground "$PG" "$@"; then
    pass "render"
else
    fail "render"
    exit 1
fi
[ -z "$(labelled)" ] || { echo "objects of game $GAME already exist" >&2; exit 1; }
before=$(others)

# --- deployment -----------------------------------------------------------
info "gmctl deploy"
deployed=yes
if $GMCTL deploy "$SCN" --playground "$PG"; then
    pass "deploy: stack deployed and healthy"
else
    fail "deploy"
    exit 1
fi

# From here on, every check records its own result; keep going on failure.
set +e

same "status: stage deployed" deployed "$(stage)"

info "gmctl load-data"
$GMCTL load-data "$SCN" --playground "$PG"
same "load-data: exit 0" 0 "$?"
same "status: stage data-loaded" data-loaded "$(stage)"

info "gmctl inject"
$GMCTL inject "$SCN" --playground "$PG"
same "inject: exit 0" 0 "$?"
same "status: stage injected" injected "$(stage)"

# --- the load (scheduler nodes only) ----------------------------------------
if [ -n "$AGING" ]; then
    info "gmctl start-load"
    $GMCTL start-load "$SCN" --playground "$PG"
    same "start-load: exit 0" 0 "$?"
    same "status: stage load-started" load-started "$(stage)"
    same "the early check's host timer is active" active \
        "$(systemctl --user show -p ActiveState --value "dbagm-${GAME}_early-check.timer")"
    T0=$(python3 -c 'import sys, yaml
print(yaml.safe_load(open(sys.argv[1]))["load"]["t0"])' "$LDIR/state.yaml")
    info "T0 $T0"
    for i in $(scn late); do
        info "gmctl inject --at now --instance $i (a test harness: planted at once)"
        $GMCTL inject "$SCN" --playground "$PG" --at now --instance "$i"
        same "inject --at now: $i planted" 0 "$?"
    done

    T0S=$(date -u -d "$(printf '%s' "$T0" | sed 's/T/ /; s/Z$//')" +%s)
    first=$(( T0S / 60 * 60 + 60 ))
    end=$(( first + LOAD_MINUTES * 60 ))
    wait=$(( end + 15 - $(date +%s) ))
    if [ "$wait" -gt 0 ]; then
        info "$LOAD_MINUTES minutes of schedules: waiting ${wait} s"
        sleep "$wait"
    fi
    MINUTES=$(i=0; while [ "$i" -lt "$LOAD_MINUTES" ]; do
        date -u -d "@$(( first + i * 60 ))" +%Y-%m-%dT%H:%MZ; i=$((i + 1)); done)
    for n in $(scn schedulers); do
        plan=$(scn keyplan "$n" "$T0S" "$first" "$end" "$LDIR")
        keys=$(printf '%s\n' "$plan" | awk '$3 == "judged" { print $1 }' | tr '\n' ' ')
        slow=$(printf '%s\n' "$plan" | awk '$3 == "not-judged" { printf "%s%s (~%s)", s, $1, $2; s = ", " }')
        [ -z "$slow" ] || info "scheduler $n: not judged, under 4 calls expected in $LOAD_MINUTES minutes: $slow"
        lines=$(on "$n" root --env "MINUTES=$(printf '%s' "$MINUTES" | tr '\n' ' ')" <<'EOF'
for m in $MINUTES; do
    grep -E "^[^ ]+ (summary|key) minute=$m( |\$)" /var/log/scheduler/scheduler.log
done
EOF
)
        same "scheduler $n: every minute since T0 summarised, every current stream key in each, calls by rate" \
            ok "$(python3 - "$plan" "$MINUTES" "$lines" <<'EOF'
import re, sys
plan, minutes, text = sys.argv[1], sys.argv[2].split(), sys.argv[3]
judged, held = {}, {}
for row in plan.splitlines():
    k, _, j, ms = row.split()
    judged[k], held[k] = j == "judged", set() if ms == "-" else set(ms.split(","))
summ, calls, seen = set(), {k: 0 for k in judged}, {}
for line in text.splitlines():
    f = dict(re.findall(r"(\w+)=(\S+)", line))
    if " summary " in line:
        summ.add(f["minute"])
    elif " key " in line:
        seen.setdefault(f["minute"], set()).add(f["key"])
        if f["key"] in calls:
            calls[f["key"]] += int(f["calls"])
out = ["minute %s: no summary" % m for m in minutes if m not in summ]
out += ["minute %s: no key line for %s" % (m, k) for m in minutes for k in judged
        if m in held[k] and k not in seen.get(m, set())]
out += ["key %s: no call in %d minutes" % (k, len(minutes)) for k in judged
        if judged[k] and not calls[k]]
print("\n".join(out) or "ok")
EOF
)"
        metrics=$(printf 'curl -fsS http://localhost:9120/metrics\n' | on "$n" root)
        same "scheduler $n: running, and its metrics count calls of every judged stream key" ok \
            "$(printf '%s\n' "$metrics" | python3 -c '
import re, sys
keys, text = sys.argv[1].split(), sys.stdin.read()
v = {m.group(1): float(m.group(2)) for m in
     re.finditer(r"^scheduler_calls_total\{key=\"([^\"]+)\"\} (\S+)$", text, re.M)}
out = [] if re.search(r"^scheduler_running 1(\.0)?$", text, re.M) else ["not running"]
out += ["%s: no call counted" % k for k in keys if not v.get(k)]
print("\n".join(out) or "ok")' "$keys")"
    done
fi

# --- check: every sealed check at its expected reading ----------------------
# verdicts <output>: the instance lines of gmctl check, without their reasons.
verdicts() { printf '%s\n' "$1" | sed 's/ — .*//'; }
expected=$(scn checks)
count=$(printf '%s\n' "$expected" | wc -l | tr -d ' ')
allowed=$(printf '%s\n' "$expected" | awk -F '\t' '$3 != "present" { printf "%s%s %s", s, $1, $3; s = ", " }')
# readings <judge|notes> <output>: judge, "ok" when every instance line reads
# one of its expected readings, in order, else one line per difference;
# notes, one line per reading other than present, with why it is expected.
readings() {
    python3 - "$1" "$expected" "$(verdicts "$2")" <<'EOF'
import sys
mode, exp, got = sys.argv[1], sys.argv[2].splitlines(), sys.argv[3].splitlines()
out = []
for i, row in enumerate(exp):
    inst, fid, alts, why = row.split("\t")
    line = got[i] if i < len(got) else ""
    head, _, reading = line.rpartition(": ")
    if mode == "judge" and (head != "%s %s" % (inst, fid) or reading not in alts.split("|")):
        out.append("%s %s: %s expected, got [%s]" % (inst, fid, " or ".join(alts.split("|")), line))
    elif mode == "notes" and reading != "present" and reading in alts.split("|"):
        out.append("%s reads %s, as expected of a smoke run (%s): not judged further" % (inst, reading, why))
if mode == "judge":
    out += ["unexpected line [%s]" % line for line in got[len(exp):]]
    print("\n".join(out) or "ok")
elif out:
    print("\n".join(out))
EOF
}
# implied <output>: the exit its readings give (master spec 8.1).
implied() {
    verdicts "$1" | awk '{ r[$NF]++ } END { print (r["error"] ? 2 : r["present"] ? 1 : r["too-soon"] ? 3 : 0) }'
}
if [ -z "$allowed" ]; then
    info "gmctl check, until every sealed check reads present (up to 120 s, ${CHECK_TIMEOUT} s a run)"
else
    info "gmctl check, until every sealed check reads present, or as expected ($allowed; up to 120 s, ${CHECK_TIMEOUT} s a run)"
fi
i=0
while :; do
    out=$(timeout "$CHECK_TIMEOUT" $GMCTL check "$SCN" --playground "$PG"); rc=$?
    { [ "$(readings judge "$out")" = ok ] && [ "$rc" = "$(implied "$out")" ]; } || [ "$i" -ge 24 ] && break
    i=$((i + 1)); sleep 5
done
printf '%s\n' "$out"
info "check: $((i + 1)) run(s), $((i * 5)) s waited"
readings notes "$out" | while read -r line; do info "check: $line"; done
if [ -z "$allowed" ]; then
    same "check: exit 1 (faults present)" 1 "$rc"
    same "check: every one of the $count sealed checks at 1 (present)" ok "$(readings judge "$out")"
else
    want=$(implied "$out")
    same "check: exit $want, as its readings give (2 with an error, else 1 with a present)" "$want" "$rc"
    same "check: every one of the $count sealed checks present or as expected ($allowed)" ok "$(readings judge "$out")"
fi

# --- validate: the verdicts the answer key gives at hand-over ---------------
# red_lines <validate output> <node>: the RED lines under the node's heading.
red_lines() {
    printf '%s\n' "$1" | awk -v h="$2:" '/^[^ ]/ { on = ($0 == h); next } on && /^  RED / { print }'
}
want=$(scn verdicts)
reds=$(scn red)
if [ -n "$reds" ]; then want_rc=1; else want_rc=0; fi
info "gmctl validate (expected: $want)"
out=$($GMCTL validate "$SCN" --playground "$PG"); rc=$?
printf '%s\n' "$out"
same "validate: exit $want_rc" "$want_rc" "$rc"
same "validate: verdicts" "Validators of game $GAME: $want" "$(printf '%s\n' "$out" | tail -n 1)"
if [ -n "$reds" ]; then
    printf '%s\n' "$reds" | while read -r node rule; do
        if red_lines "$out" "$node" | grep -q "^  RED $rule:"; then
            echo yes
        else
            echo "no: $node $rule"
        fi
    done > "$tmp/red-rules"
    same "validate: the answer key's RED lines ($(printf '%s' "$reds" | tr '\n' ',' | sed 's/,/, /g'))" \
        "$(printf '%s\n' "$reds" | sed 's/.*/yes/')" "$(cat "$tmp/red-rules")"
fi
same "evaluation changed no stage" "$LIVE" "$(stage)"

# --- teardown -------------------------------------------------------------
info "gmctl teardown"
if $GMCTL teardown "$SCN" --playground "$PG"; then
    deployed=no
    pass "teardown"
else
    fail "teardown"
fi
same "status: stage torn-down" torn-down "$(stage)"
same "nothing labelled with game $GAME is left" "" "$(labelled)"
same "no systemd user timer or service of game $GAME is left" "" "$(units)"
same "objects not belonging to the game are unchanged" "$before" "$(others)"

elapsed=$(( $(date +%s) - started ))
if [ "$failures" -eq 0 ]; then
    echo "smoke-scenario $NAME: all $passes checks passed in ${elapsed}s (game $GAME)"
else
    echo "smoke-scenario $NAME: $failures check(s) failed, $passes passed, in ${elapsed}s (game $GAME)"
    exit 1
fi
