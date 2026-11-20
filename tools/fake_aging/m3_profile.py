#!/usr/bin/env python3
"""M3, a fake game's hourly profile in Prometheus against run R's (v0.6
master spec 12.1; capture W4 item 3; spec D590).

Copied from the research's prototype, research/fake-aging 10d1bc6
`tools/research/fake_aging/m3_profile.py` (the shop's game id and its
`shop` database hard-coded, the container found with `docker ps`), and
generalised: the scenario, the playground and the database are
arguments, Prometheus is read through `tools/gm/history.py`'s reader
(`curl` in the game's Prometheus node, read-only), and the comparison
judges only the hours the game's past holds.

    python3 tools/fake_aging/m3_profile.py dump <scenario-dir> --playground <pg>
        --handover <YYYY-MM-DDTHH:00Z> [--database <db>] <out.json>
    python3 tools/fake_aging/m3_profile.py compare <reference.json> <game.json>

`dump` reads the research's expressions at 1-hour steps over the 24 hours
up to the hand-over (step i the rate over the hour ending 24 - i hours
before it); the database is `--database` (default `shop`, the research's).
It records the game's virtual T0 and restart from its restart record. Both
games hand over at 14:00 scenario time, so step i is the same scenario
hour in both (the research's alignment).

`compare` judges, over the steps whose hour lies inside the game's past
(from its virtual T0 plus one hour to the last whole hour before the
restart; a step spanning the restart or the import left out), the traffic
expressions: Pearson correlation at least 0.95 and the ratio of means
0.95 to 1.05. The rest (the call p95, the size and resource gauges,
`series`, the transactions' age) is reported as FIGURE lines, never
judged. Run R ran PostgreSQL 18; the traffic expressions are rates the
workload drives (D590).

Output: `PASS  ...`, `FAIL  ...`, `SKIP  ...`, `FIGURE  ...`, then
`m3_profile.py: <n> passed, <n> failed, <n> skipped`. Exit 0 nothing
failed, 1 a failure (or the game unreadable), 2 usage, 77 the reference
absent.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
STEP = 3600
STEPS = 25
MIN_CORR = 0.95
MEANS = (0.95, 1.05)
ABSENT = "the reference archive is absent"

# name: (expression, judged); {db} the database
EXPRS = {
    "calls/s, all keys": ("sum(rate(scheduler_calls_total[1h]))", True),
    "errors/s": ("sum(rate(scheduler_errors_total[1h]))", True),
    "call p95 s, all keys": ("histogram_quantile(0.95, sum by (le) "
                             "(rate(scheduler_call_duration_seconds_bucket[1h])))", False),
    "commits/s": ('sum(rate(pg_stat_database_xact_commit{{datname="{db}"}}[1h]))', True),
    "rows inserted/s": ('sum(rate(pg_stat_database_tup_inserted{{datname="{db}"}}[1h]))', True),
    "statements calls/s": ("sum(rate(pg_stat_statements_calls_total[1h]))", True),
    "db size MB": ('max(pg_database_size_bytes{{datname="{db}"}}) / 1e6', False),
    "WAL MB": ("max(pg_wal_size_bytes) / 1e6", False),
    "backends": ("sum(pg_stat_activity_count)", False),
    "db node CPU cores": ('sum(rate(node_health_cpu_seconds_total{{node="db"}}[1h]))', False),
    "series": ('count({{__name__=~".+"}})', False),
    "max tx duration s": ("max(pg_stat_activity_max_tx_duration)", False),
}
# the research's names in run R's profile
ALIASES = {"commits/s, shop": "commits/s", "rows inserted/s, shop": "rows inserted/s",
           "db size MB": "db size MB"}


def parse_instant(text):
    for fmt in ("%Y-%m-%dT%H:%MZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=timezone.utc).timestamp()
        except (TypeError, ValueError):
            continue
    return None


def dump(a):
    sys.path.insert(0, str(REPO))
    from tools.gm import aging, history, localimpl
    from tools.gm.docker import for_local_dir
    from tools.gm.model import GmError
    end = parse_instant(a.handover)
    if end is None or end % 3600:
        print(f"m3_profile.py: --handover {a.handover}: expected a whole hour, "
              "YYYY-MM-DDTHH:00Z", file=sys.stderr)
        return 2
    ldir = localimpl.local_dir(a.scenario, a.playground)
    try:
        impl = localimpl.read_implementation(ldir)
        record = localimpl.read_restart_record(ldir) or {}
        node = aging.prometheus_node(impl)
        if not node:
            print("m3_profile.py: the game has no Prometheus node", file=sys.stderr)
            return 2
        prom = history.Prometheus(ldir, node, for_local_dir(ldir))
        start = end - 24 * 3600
        series = {}
        for name, (expr, _) in EXPRS.items():
            res = prom.get("query_range", query=expr.format(db=a.database), start=f"{start:.0f}",
                           end=f"{end:.0f}", step=str(STEP))["result"]
            vals = {int(float(t)): float(v) for t, v in res[0]["values"]} if res else {}
            series[name] = [vals.get(int(start) + STEP * i) for i in range(STEPS)]
    except (GmError, OSError) as exc:
        print(f"m3_profile.py: {exc}", file=sys.stderr)
        return 1
    data = {"game": impl.get("game_id"), "handover": a.handover, "database": a.database,
            "virtual_t0": record.get("virtual_t0"),
            "restart": (record.get("restart") or {}).get("at"), "series": series}
    with open(a.out, "w") as f:
        json.dump(data, f, indent=1)
    print(f"m3_profile.py: {len(series)} expressions, {STEPS} steps, written to {a.out}")
    return 0


def corr(a, b):
    p = [(x, y) for x, y in zip(a, b) if x is not None and y is not None]
    if len(p) < 3:
        return None
    mx = sum(x for x, _ in p) / len(p)
    my = sum(y for _, y in p) / len(p)
    sx = sum((x - mx) ** 2 for x, _ in p) ** 0.5
    sy = sum((y - my) ** 2 for _, y in p) ** 0.5
    return sum((x - mx) * (y - my) for x, y in p) / (sx * sy) if sx and sy else None


def mean(a):
    v = [x for x in a if x is not None]
    return sum(v) / len(v) if v else None


def held(game):
    """The steps whose hour lies inside the game's past: [i - 1h, i] within
    [virtual T0, restart)."""
    end = parse_instant(game["handover"])
    vt0, restart = parse_instant(game.get("virtual_t0")), parse_instant(game.get("restart"))
    if end is None or vt0 is None or restart is None:
        return None
    start = end - 24 * 3600
    return [i for i in range(1, STEPS)
            if start + STEP * (i - 1) >= vt0 and start + STEP * i <= restart]


def compare(a):
    passed = failed = skipped = 0

    def line(kind, text):
        nonlocal passed, failed, skipped
        print(f"{kind}  {text}", flush=True)
        passed += kind == "PASS"
        failed += kind == "FAIL"
        skipped += kind == "SKIP"

    def last():
        print(f"m3_profile.py: {passed} passed, {failed} failed, {skipped} skipped")

    if not os.path.isfile(a.reference):
        line("SKIP", f"M3 against run R: {ABSENT} ({a.reference})")
        last()
        return 77
    try:
        with open(a.reference) as f:
            r = json.load(f)
        with open(a.game) as f:
            g = json.load(f)
    except (OSError, ValueError) as exc:
        print(f"m3_profile.py: {exc}", file=sys.stderr)
        return 2
    rs = {ALIASES.get(k, k): v for k, v in r["series"].items()}
    steps = held(g)
    if not steps:
        print("m3_profile.py: the game's profile names no virtual T0 and restart (a dump of "
              "a fake game's)", file=sys.stderr)
        return 2
    start = parse_instant(g["handover"]) - 24 * 3600
    hours = [datetime.fromtimestamp(start + STEP * i, timezone.utc).strftime("%H:%MZ") for i in steps]
    line("FIGURE", f"reference: run R {r.get('game')}, hand-over {r.get('handover')}, a "
                   "PostgreSQL 18 reference (D590); game "
                   f"{g.get('game')}, hand-over {g.get('handover')}")
    line("FIGURE", f"steps judged: {len(steps)}, i = {steps[0]} to {steps[-1]} (hours ending "
                   f"{hours[0]} to {hours[-1]}, game time; R's step i the same scenario hour)")
    fmt = lambda x: "-" if x is None else f"{x:.3g}"
    for name, (_, judged) in EXPRS.items():
        ra = [(rs.get(name) or [None] * STEPS)[i] for i in steps]
        ga = [(g["series"].get(name) or [None] * STEPS)[i] for i in steps]
        c, mr, mg = corr(ra, ga), mean(ra), mean(ga)
        ratio = mg / mr if mr and mg is not None else None
        text = (f"{name}: corr {fmt(c)}, mean game/R {fmt(ratio)} (R {fmt(mr)}, game {fmt(mg)}); "
                f"R [{' '.join(fmt(x) for x in ra)}] game [{' '.join(fmt(x) for x in ga)}]")
        if not judged:
            line("FIGURE", text)
            continue
        ok = c is not None and c >= MIN_CORR and ratio is not None and MEANS[0] <= ratio <= MEANS[1]
        line("PASS" if ok else "FAIL",
             f"{text} (corr at least {MIN_CORR}, means {MEANS[0]} to {MEANS[1]})")
    last()
    return 1 if failed else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("dump")
    d.add_argument("scenario")
    d.add_argument("--playground", required=True)
    d.add_argument("--handover", required=True, metavar="<YYYY-MM-DDTHH:00Z>")
    d.add_argument("--database", default="shop")
    d.add_argument("out")
    c = sub.add_parser("compare")
    c.add_argument("reference")
    c.add_argument("game")
    try:
        a = ap.parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    return dump(a) if a.cmd == "dump" else compare(a)


if __name__ == "__main__":
    sys.exit(main())
