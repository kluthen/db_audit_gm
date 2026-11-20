#!/bin/sh
# The tells a DBA could read on a fake game's database nodes after its
# restart (v0.6 master spec 9.9, 9.10, 12.1; capture W4 item 1): the fixed
# tells, each one verdict per node.
#
# Copied from the research's prototype, research/fake-aging 10d1bc6
# `tools/research/fake_aging/m4_tells.sh` (which printed the shop's `db`
# node's readings for a reader to judge, the game found with `docker ps`),
# and generalised: the scenario, the playground and the nodes are
# arguments, every node is read through `tools/gmctl exec`, and each tell is
# judged against the game's own restart record and clean-restart figures.
#
# Usage:
#   sh tools/fake_aging/tells.sh <scenario-dir> --playground <pg> --node <db node>
#       [--node <db node> ...] [--reference --start <game T0 dir>]
#
# Every primary `postgres` node the game reads, named by the caller (the
# shop `db`; the campaign `db` and `reporting`). Refused, exit 2: no restart
# record, a record not `mode: fake`, or no `restart.at` (the tells are a
# fake game's, after its clean-restart).
#
# The checks, per node:
#   start-time   pg_postmaster_start_time() at or after restart.at, within
#                10 s of it, before now(), and the same read again at the end
#                (no negative, no moving start time);
#   statements   no pg_stat_statements row in any database naming gm_vclock
#                or gm_pad (the fill's clock, the padding's messages), and
#                pg_stat_statements_info.stats_reset before restart.at;
#   stats-reset  one instant: the shared views' stats_reset (bgwriter,
#                checkpointer, WAL, archiver, I/O) and the statements' within
#                one second of each other, before restart.at by at most
#                RESET_BEFORE seconds (D536);
#   pg-wal       pg_wal's live total (pg_ls_waldir()) at least 90 % of the
#                padding's own figure, state.yaml's
#                clean_restart.wal.<node>.pg_wal_bytes (the ratio a FIGURE);
#   autovacuum   per table: with --reference (the shop only) and --start (the
#                game's M1 dump at its virtual T0, m1_dump.sh's folder), the
#                rows updated since that T0, in the game and in R (R started
#                from the same T0 data); each run of a bulk statement updating
#                the whole table in the span (BULK below: the shop's
#                orders.close-day on customers, its job's runs counted from
#                the rendered jobs.yaml over each span) expected as one run,
#                its rows taken out of the updated rows; the rest at R's runs
#                per updated row: expected = bulk runs + (R's runs - R's bulk
#                runs) x the game's updated rows / R's, x0.5 to x2, one run
#                either way (D596; what the rule leaves unexplained a FIGURE);
#                otherwise, a table whose updated and deleted rows passed its
#                autovacuum threshold has at least one run, and none more than
#                its dirtied (inserted, updated, deleted) rows over that
#                threshold plus one; a table whose reloptions turn autovacuum
#                off reported only;
#   search-path  no routine in any database with gm_vclock in its proconfig's
#                search_path, and no gm_vclock schema left.
# FIGURE only, never judged (9.10, curation none): Prometheus'
# prometheus_tsdb_lowest_timestamp_seconds, prometheus_tsdb_blocks_loaded and
# prometheus_tsdb_storage_blocks_bytes at the read.
#
# --reference: run R's table statistics and read time (m1-fa-real-
# 20261115T0800/table_stats.csv, meta.csv) through
# tools/fake_aging/reference/extract.sh; with the archive absent, or without
# --start, a SKIP line for R's and the autovacuum check takes the rule
# without it.
#
# Read-only: every SQL as postgres with default_transaction_read_only on,
# unseen as the fill's sessions (no statement statistics or log, no pgaudit).
#
# Output: `PASS  <check>: <detail>`, `FAIL  ...`, `SKIP  ...`, `FIGURE  ...`,
# then `tells.sh: <n> passed, <n> failed, <n> skipped`. Exit 0 nothing
# failed, 1 any failure, 2 usage or refused (nothing read).
set -eu

usage() {
    echo "usage: sh tools/fake_aging/tells.sh <scenario-dir> --playground <pg> --node <db node> [--node <db node> ...] [--reference --start <game T0 dir>]" >&2
    exit 2
}

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
GMCTL="python3 $REPO/tools/gmctl"
R_TABLES=m1-fa-real-20261115T0800/table_stats.csv
R_META=m1-fa-real-20261115T0800/meta.csv
[ $# -ge 1 ] || usage
scen=$1
shift
pg= nodes= reference=no start=
while [ $# -gt 0 ]; do
    case $1 in
        --playground) [ $# -ge 2 ] || usage; pg=$2; shift 2 ;;
        --node) [ $# -ge 2 ] || usage; nodes="$nodes $2"; shift 2 ;;
        --reference) reference=yes; shift ;;
        --start) [ $# -ge 2 ] || usage; start=$2; shift 2 ;;
        *) echo "tells.sh: unexpected argument $1" >&2; usage ;;
    esac
done
[ -n "$pg" ] && [ -n "$nodes" ] || usage
[ -z "$start" ] || [ "$reference" = yes ] || { echo "tells.sh: --start goes with --reference" >&2; usage; }
[ -z "$start" ] || [ -f "$start/table_stats.csv" ] || { echo "tells.sh: --start $start: no table_stats.csv (an m1_dump.sh folder?)" >&2; exit 2; }
[ -f "$scen/scenario.yaml" ] || { echo "tells.sh: $scen: no scenario.yaml" >&2; exit 2; }
LDIR=$scen/local/$pg

# The refusals: a fake game's restart record with restart.at.
why=$(python3 - "$LDIR" "$scen" "$reference" <<'EOF'
import os, sys, yaml
ldir, scen, ref = sys.argv[1:4]
p = os.path.join(ldir, "fake-aging.yaml")
if not os.path.isfile(p):
    print(f"no restart record ({p}): the tells are a fake game's"); sys.exit()
r = yaml.safe_load(open(p)) or {}
if r.get("mode") != "fake":
    print(f"the restart record's mode is {r.get('mode')!r}, not fake"); sys.exit()
if not (r.get("restart") or {}).get("at"):
    print("the restart record has no restart.at: run the tells after clean-restart"); sys.exit()
sid = (yaml.safe_load(open(os.path.join(scen, "scenario.yaml"))) or {}).get("id")
if ref == "yes" and sid != "tarnbeck-outdoor-shop":
    print(f"--reference: run R is tarnbeck-outdoor-shop's reference, not {sid}'s")
EOF
) || why="the restart record cannot be read"
[ -z "$why" ] || { echo "tells.sh: refused: $why; nothing read" >&2; exit 2; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/tells.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT TERM

READ=$(cat <<'REMOTE'
set -eu
export PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=60s -c log_statement=none -c log_min_duration_statement=-1 -c log_min_error_statement=panic -c pg_stat_statements.track=none -c pgaudit.log=none -c client_min_messages=warning'
p() { psql -X -At -F '|' -v ON_ERROR_STOP=1 -d "$1" -c "$2"; }
p postgres "SELECT 'start|' || extract(epoch FROM pg_postmaster_start_time()) || '|' || extract(epoch FROM now())"
[ "${GM_START_ONLY:-}" = yes ] && exit 0
p postgres "SELECT 'pgwal|' || coalesce(sum(size), 0) FROM pg_ls_waldir()"
p postgres "SELECT 'reset|bgwriter|' || coalesce(extract(epoch FROM stats_reset)::text, '') FROM pg_stat_bgwriter
  UNION ALL SELECT 'reset|checkpointer|' || coalesce(extract(epoch FROM stats_reset)::text, '') FROM pg_stat_checkpointer
  UNION ALL SELECT 'reset|wal|' || coalesce(extract(epoch FROM stats_reset)::text, '') FROM pg_stat_wal
  UNION ALL SELECT 'reset|archiver|' || coalesce(extract(epoch FROM stats_reset)::text, '') FROM pg_stat_archiver
  UNION ALL SELECT 'reset|io min|' || coalesce(extract(epoch FROM min(stats_reset))::text, '') FROM pg_stat_io
  UNION ALL SELECT 'reset|io max|' || coalesce(extract(epoch FROM max(stats_reset))::text, '') FROM pg_stat_io"
ss=no
for d in $(p postgres "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname = 'postgres' DESC, datname"); do
    ext=$(p "$d" "SELECT quote_ident(n.nspname) FROM pg_extension e JOIN pg_namespace n ON n.oid = e.extnamespace WHERE e.extname = 'pg_stat_statements'")
    if [ -n "$ext" ] && [ "$ss" = no ]; then
        ss=yes
        p "$d" "SELECT 'statements|' || count(*) FILTER (WHERE query ~ ('gm' || '_vclock|gm' || '_pad')) || '|' || count(*) FROM $ext.pg_stat_statements"
        p "$d" "SELECT 'ssreset|' || coalesce(extract(epoch FROM stats_reset)::text, '') FROM $ext.pg_stat_statements_info"
    fi
    p "$d" "SELECT 'path|' || current_database() || '|' || count(*) || '|' || coalesce(string_agg(p.oid::regprocedure::text, ', '), '')
              FROM pg_proc p WHERE EXISTS (SELECT 1 FROM unnest(p.proconfig) c
                                            WHERE c LIKE 'search\_path=%' AND c LIKE '%gm\_vclock%')"
    p "$d" "SELECT 'schema|' || current_database() || '|' || count(*) FROM pg_namespace WHERE nspname = 'gm' || '_vclock'"
    p "$d" "SELECT 'table|' || current_database() || '|' || s.schemaname || '.' || s.relname || '|' || s.autovacuum_count
                   || '|' || s.n_tup_ins || '|' || s.n_tup_upd || '|' || s.n_tup_del || '|' || greatest(c.reltuples, 0)::bigint
                   || '|' || coalesce(o.vt, current_setting('autovacuum_vacuum_threshold'))
                   || '|' || coalesce(o.vsf, current_setting('autovacuum_vacuum_scale_factor'))
                   || '|' || coalesce(o.en, 'true')
              FROM pg_stat_user_tables s JOIN pg_class c ON c.oid = s.relid
              LEFT JOIN LATERAL (
                SELECT max(option_value) FILTER (WHERE option_name = 'autovacuum_vacuum_threshold') AS vt,
                       max(option_value) FILTER (WHERE option_name = 'autovacuum_vacuum_scale_factor') AS vsf,
                       max(option_value) FILTER (WHERE option_name = 'autovacuum_enabled') AS en
                  FROM pg_options_to_table(c.reloptions)) o ON true
             ORDER BY s.schemaname, s.relname"
done
[ "$ss" = yes ] || echo "statements|none"
REMOTE
)

for n in $nodes; do
    printf '%s\n' "$READ" | $GMCTL exec "$scen" --playground "$pg" --node "$n" --user postgres \
        > "$tmp/read-$n" 2> "$tmp/err-$n" || {
        echo "tells.sh: reading node $n failed: $(tr '\n' ' ' < "$tmp/err-$n" | cut -c1-300)" >&2
        echo "FAIL  read $n: the node could not be read"
        echo "tells.sh: 0 passed, 1 failed, 0 skipped"
        exit 1
    }
done

rtables= rmeta=
: > "$tmp/extract.line"
if [ "$reference" = yes ] && [ -z "$start" ]; then
    echo "SKIP  autovacuum against run R: no --start (the game's M1 at its virtual T0) to count the updates from" > "$tmp/extract.line"
elif [ "$reference" = yes ]; then
    rc=0
    rtables=$(sh "$HERE/reference/extract.sh" "$R_TABLES" "$R_META" 2> "$tmp/extract.err") || rc=$?
    if [ "$rc" -eq 0 ]; then
        rmeta=$(printf '%s\n' "$rtables" | grep '/meta\.csv$' || true)
        rtables=$(printf '%s\n' "$rtables" | grep '/table_stats\.csv$' || true)
    else
        rtables=
        if [ "$rc" -eq 77 ]; then
            echo "SKIP  autovacuum against run R: the reference archive is absent ($(sed -n 's/^extract.sh: SKIP: //p' "$tmp/extract.err"))" > "$tmp/extract.line"
        else
            echo "FAIL  autovacuum against run R: extract.sh exit $rc: $(tr '\n' ' ' < "$tmp/extract.err" | cut -c1-300)" > "$tmp/extract.line"
        fi
    fi
fi

# Prometheus' own series (FIGURE only), then the start times read again
python3 - "$REPO" "$LDIR" > "$tmp/prometheus" 2>&1 <<'EOF' || true
import sys, time
sys.path.insert(0, sys.argv[1])
from tools.gm import aging, history, localimpl
from tools.gm.docker import for_local_dir
ldir = sys.argv[2]
impl = localimpl.read_implementation(ldir)
node = aging.prometheus_node(impl)
if not node:
    print("none")
    sys.exit()
prom = history.Prometheus(ldir, node, for_local_dir(ldir))
now = time.time()
for m in ("prometheus_tsdb_lowest_timestamp_seconds", "prometheus_tsdb_blocks_loaded",
          "prometheus_tsdb_storage_blocks_bytes"):
    res = prom.query(m, now)
    print(m, res[0]["value"][1] if res else "-")
EOF
for n in $nodes; do
    printf '%s\n' "$READ" | $GMCTL exec "$scen" --playground "$pg" --node "$n" --user postgres \
        --env GM_START_ONLY=yes > "$tmp/again-$n" 2>> "$tmp/err-$n" || : > "$tmp/again-$n"
done

python3 - "$REPO" "$scen" "$LDIR" "$tmp" "$rtables" "$rmeta" "$start" $nodes <<'EOF'
import csv, datetime, os, sys, yaml
repo, scen, ldir, tmp, rtables, rmeta, start_dir = sys.argv[1:8]
nodes = sys.argv[8:]
sys.path.insert(0, repo)
START_BOUND = 10            # s after restart.at (the wave 3 gate measured +1.3 to +2.2 s)
RESET_BEFORE = 120          # s: the reset is the maintenance's step before the stop (D536)
WAL_FLOOR = 0.90
R_SPAN = 24 * 3600          # run R aged 24 h to its read (run-2026-11-14.md, "Run R")
# The bulk statements updating a whole table, per scenario: table -> the key
# of the job that runs it (capture W4 item 1, D596; the shop's close of day,
# nodes/producer/queries.yaml `orders.close-day`).
BULK = {"tarnbeck-outdoor-shop": {"customers": "orders.close-day"}}
def ts(v):
    """An instant from the YAML (a datetime, or ISO 8601 text), epoch seconds."""
    if not isinstance(v, datetime.datetime):
        v = datetime.datetime.fromisoformat(str(v).strip().replace("Z", "+00:00"))
    return (v if v.tzinfo else v.replace(tzinfo=datetime.timezone.utc)).timestamp()

record = yaml.safe_load(open(os.path.join(ldir, "fake-aging.yaml")))
state = yaml.safe_load(open(os.path.join(ldir, "state.yaml"))) or {}
at = ts(record["restart"]["at"])
wal_state = ((state.get("clean_restart") or {}).get("wal")) or {}
counts = {"PASS": 0, "FAIL": 0, "SKIP": 0}

def out(kind, text):
    print(f"{kind}  {text}" if kind != "FIGURE" else f"FIGURE  {text}")
    if kind in counts:
        counts[kind] += 1

for line in open(os.path.join(tmp, "extract.line")):
    kind, _, text = line.rstrip("\n").partition("  ")
    out(kind, text)

def iso(t):
    return datetime.datetime.fromtimestamp(t, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-4] + "Z"

def parse(path):
    lines = {}
    if os.path.exists(path):
        for line in open(path):
            parts = line.rstrip("\n").split("|")
            lines.setdefault(parts[0], []).append(parts[1:])
    return lines

R = {}
if rtables:
    for row in csv.DictReader(open(rtables)):
        R[row["relname"]] = row
Z = {}
if R and start_dir:
    for row in csv.DictReader(open(os.path.join(start_dir, "table_stats.csv"))):
        Z[row["relname"]] = row

def runs_between(key, lo, hi):
    """How many times the rendered job running `key` falls due in [lo, hi)
    (epoch seconds); None when no rendered job runs it."""
    from tools.gm import aging, localimpl
    jobs = [j for _, j in aging.rendered_jobs(ldir, localimpl.read_implementation(ldir))
            if j.get("key") == key]
    if not jobs:
        return None
    n = 0
    for job in jobs:
        t = datetime.datetime.fromtimestamp(lo, datetime.timezone.utc)
        while True:
            due = aging.job_first_due(job, t)
            if due is None or due.timestamp() >= hi:
                break
            n += 1
            t = due + datetime.timedelta(seconds=60)
    return n

sid = (yaml.safe_load(open(os.path.join(scen, "scenario.yaml"))) or {}).get("id")
bulk = BULK.get(sid, {}) if R else {}
r_read = None
if bulk and rmeta:
    r_read = ts(next(csv.DictReader(open(rmeta)))["read_at"].replace(" ", "T"))

for node in nodes:
    d = parse(os.path.join(tmp, f"read-{node}"))
    again = parse(os.path.join(tmp, f"again-{node}"))
    start, now = (float(x) for x in d["start"][0])
    a2 = float(again["start"][0][0]) if again.get("start") else None
    lag = start - at
    ok = 0 <= lag <= START_BOUND and start < now and a2 is not None and abs(a2 - start) < 0.001
    out("PASS" if ok else "FAIL",
        f"start-time {node}: the postmaster started {iso(start)}, {lag:+.1f} s from restart.at "
        f"{iso(at)} (within 0 to {START_BOUND} s), before now; read again at the end: "
        f"{iso(a2) if a2 else '-'} ({'unchanged' if a2 is not None and abs(a2 - start) < 0.001 else 'MOVED or unread'})")

    st = d.get("statements") or [["none"]]
    ssr = (d.get("ssreset") or [[""]])[0][0]
    if st[0][0] == "none":
        out("SKIP", f"statements {node}: no database holds pg_stat_statements")
    else:
        bad, total = int(st[0][0]), int(st[0][1])
        reset = float(ssr) if ssr else None
        ok = bad == 0 and reset is not None and reset < at
        out("PASS" if ok else "FAIL",
            f"statements {node}: {bad} of {total} pg_stat_statements rows name gm_vclock or gm_pad; "
            f"pg_stat_statements_info.stats_reset {iso(reset) if reset else '-'}"
            f"{f' ({at - reset:.1f} s before restart.at)' if reset else ''}")

    resets = {r[0]: (float(r[1]) if r[1] else None) for r in d.get("reset", [])}
    if ssr:
        resets["statements"] = float(ssr)
    known = [v for v in resets.values() if v is not None]
    missing = [k for k, v in resets.items() if v is None]
    if known:
        spread, before = max(known) - min(known), at - max(known)
        ok = not missing and spread <= 1.0 and 0 < before <= RESET_BEFORE and at - min(known) <= RESET_BEFORE
        out("PASS" if ok else "FAIL",
            f"stats-reset {node}: {len(known)} stats_reset within {spread:.3f} s of each other "
            f"(at most 1 s), {before:.1f} s before restart.at (at most {RESET_BEFORE} s)"
            + (f"; none in {', '.join(missing)}" if missing else ""))
    else:
        out("FAIL", f"stats-reset {node}: no stats_reset read")

    live = int(d["pgwal"][0][0])
    padded = (wal_state.get(node) or {}).get("pg_wal_bytes")
    if not padded:
        out("FAIL", f"pg-wal {node}: no clean_restart.wal.{node}.pg_wal_bytes in state.yaml")
    else:
        ratio = live / padded
        out("FIGURE", f"pg-wal {node}: {live} bytes live, {padded} after the padding's checkpoints, ratio {ratio:.3f}")
        out("PASS" if ratio >= WAL_FLOOR else "FAIL",
            f"pg-wal {node}: pg_wal at {ratio:.1%} of the padding's figure (at least {WAL_FLOOR:.0%})")

    for row in d.get("table", []):
        db, name, av, ins, upd, dele, tuples, vt, vsf, enabled = row
        av, ins, upd, dele, tuples = (int(x) for x in (av, ins, upd, dele, tuples))
        thr = float(vt) + float(vsf) * tuples
        what = f"autovacuum {node}/{db} {name}"
        base = f"{av} run(s); {ins} inserted, {upd} updated, {dele} deleted; threshold {thr:.0f}"
        rel = name.split(".", 1)[1] if name.startswith("public.") else None
        if enabled.lower() in ("false", "off", "0", "no"):
            out("FIGURE", f"{what}: {base}; autovacuum off by its reloptions, not judged")
            continue
        r = R.get(rel) if R and rel else None
        z = Z.get(rel) if rel else None
        if r is not None and z is not None:
            z_upd, rows = int(z["n_tup_upd"]), int(z["n_live_tup"])
            r_av = int(r["autovacuum_count"]) - int(z["autovacuum_count"])
            g_bulk = r_bulk = 0
            note = ""
            if rel in bulk:
                g_bulk = runs_between(bulk[rel], ts(record["virtual_t0"]), now)
                r_bulk = runs_between(bulk[rel], r_read - R_SPAN, r_read) if r_read else None
                if g_bulk is None or r_bulk is None:
                    out("FAIL", f"{what}: the bulk statement {bulk[rel]}'s runs could not be counted "
                                f"(no rendered job runs it, or R's read time unread)")
                    continue
                note = (f"(its bulk statement's rows out); {bulk[rel]} ran {g_bulk} time(s) in the "
                        f"game's span, {r_bulk} in R's, one run each")
            g_upd = upd - z_upd - g_bulk * rows
            r_upd = int(r["n_tup_upd"]) - z_upd - r_bulk * rows
            share = g_upd / r_upd if r_upd > 0 else 0.0
            want = g_bulk + max(r_av - r_bulk, 0) * share
            ok = 0.5 * want - 1 <= av <= 2 * want + 1
            out("PASS" if ok else "FAIL",
                f"{what}: {base}; since T0 the game updated {g_upd} row(s) and run R {r_upd} "
                f"{' ' + note if note else ''}; R {r_av} run(s): {want:.1f} expected "
                f"(x0.5 to x2, one run either way: {max(0.5 * want - 1, 0):.2f} to {2 * want + 1:.1f})")
            out("FIGURE", f"{what}: {want - av:+.1f} run(s) expected beyond the observed "
                          "(what the rule leaves unexplained: pruning, 18 against 19, time "
                          "compression; never judged)")
            continue
        dirtied = ins + upd + dele
        low = 1 if upd + dele >= thr else 0
        high = int(dirtied // thr) + 1 if thr > 0 else None
        ok = av >= low and (high is None or av <= high)
        out("PASS" if ok else "FAIL",
            f"{what}: {base}; at least {low}, at most {high} (its dirtied rows over the threshold, plus one)")

    paths = d.get("path", [])
    schemas = d.get("schema", [])
    bad = [f"{p[0]}: {p[2]}" for p in paths if int(p[1])] + \
          [f"{s[0]}: the gm_vclock schema" for s in schemas if int(s[1])]
    out("PASS" if not bad and paths else "FAIL",
        f"search-path {node}: {len(paths)} database(s) read; "
        + ("no routine's search_path names gm_vclock, no gm_vclock schema" if not bad else "; ".join(bad)))

prom = open(os.path.join(tmp, "prometheus")).read().split("\n")
if prom and prom[0] == "none":
    out("FIGURE", "Prometheus: the game has no Prometheus node")
else:
    vals = dict(line.split(" ", 1) for line in prom if line.count(" ") == 1 and line.startswith("prometheus_"))
    if len(vals) == 3:
        low = vals["prometheus_tsdb_lowest_timestamp_seconds"]
        low_text = iso(float(low)) if low not in ("-", "") else low
        out("FIGURE", f"Prometheus (9.10, not judged): lowest timestamp {low_text}, blocks loaded "
                      f"{vals['prometheus_tsdb_blocks_loaded']}, blocks bytes "
                      f"{vals['prometheus_tsdb_storage_blocks_bytes']}; virtual T0 {record.get('virtual_t0')}")
    else:
        out("FIGURE", "Prometheus: not read (" + " ".join(" ".join(prom).split())[:200] + ")")
print(f"tells.sh: {counts['PASS']} passed, {counts['FAIL']} failed, {counts['SKIP']} skipped")
sys.exit(1 if counts["FAIL"] else 0)
EOF
