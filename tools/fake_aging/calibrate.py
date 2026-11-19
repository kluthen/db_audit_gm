#!/usr/bin/env python3
"""The calibration tool: measure a fault's history signature and a key's
service time in one short real run (v0.6 master spec 9.7; capture W3
item 10).

Copied from the research's prototype, research/fake-aging 10d1bc6
`tools/research/fake_aging/calibrate.py` (which compared its latency model
with run R's scheduler log, the shop and run R hard-coded), and
generalised: the scenario, the node, the key and the fault are arguments,
and it reads either a live playground (through `gmctl exec`) or the
shop's reference (run R's OpenMetrics dump and scheduler key lines,
extracted with `tools/fake_aging/reference/extract.sh`; never committed,
spec D519). The research's model comparison is not carried: the queue
model is now the scheduler's (`gm_scheduler.queue`), which `gmctl fill`
runs.

    calibrate.py <scenario-dir> keys     --node N [--key K ...] (--log FILE | --playground P)
                                         [--since T] [--until T]
    calibrate.py <scenario-dir> per-call --node N --key K --series SEL [--series SEL ...]
                                         (--om FILE | --playground P) --since T --until T
                                         [--planted T --baseline-since T]
    calibrate.py <scenario-dir> gauge    --series SEL (--om FILE | --playground P)
                                         --since T --until T
    calibrate.py <scenario-dir> wal      --node DB --playground P (--mark | --from-mark)
    calibrate.py <scenario-dir> fault    --fault INSTANCE --playground P

Every subcommand takes `--record WHAT`: the output is also written to
`tools/fake_aging/calibration/<scenario id>-<WHAT>-<YYYYMMDDTHHMMZ>.txt`,
opening with the command, the commit, the start and the wall time (W3
item 10); WHAT is the instance, `fill` or `wal-<node>`.

- `keys`: from the scheduler's per-minute key lines (`key minute=...
  key=... calls= errors= p50_ms= p95_ms=`), each key's calls, errors and
  service time as `service-times.yaml` writes it: `median` the median
  across minutes of p50, less the client's round trip and the key's
  transaction hold (queries.yaml), `sigma` the median across minutes of
  ln(p95/p50)/1.645 (a lognormal's spread), both in seconds. Minutes
  where a queue or a lock stretched the call are the GM's to leave out
  with --since/--until.
- `per-call`: a counter's increase per call of the key (a
  `counter_per_call`'s `per_call`): the series' increase over the key's
  calls' increase (`scheduler_calls_total{instance="<node>:9120",key=K}`).
  With `--planted`, the fault's share only: the series' rate per call of
  every key before the planting is taken as the baseline and subtracted
  after it, so per_call = (dS_after - b * dAll_after) / dK_after.
- `gauge`: a gauge's minimum, median, maximum, and the median interval
  between its falls (a sawtooth's period).
- `wal`: `pg_stat_wal.wal_bytes` on the node now (`--mark` writes it to the
  playground's calibration mark file) and its rate since the mark
  (`--from-mark`): `bytes_per_hour` for `wal-rate.yaml`.
- `fault`: the instance's planting as the playground's `state.yaml`
  records it, for the other subcommands' `--planted`.

Selectors: `name{label="v",label=~"re"}`, `{...}` alone, or a bare name.
Instants: ISO 8601, UTC (`2026-11-15T02:00Z`).
"""

import argparse
import datetime as dt
import json
import math
import os
import re
import shlex
import statistics
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
GMCTL = REPO / "tools" / "gmctl"
OUT_DIR = REPO / "tools" / "fake_aging" / "calibration"
SCHEDULER_PORT = 9120
# The client's own round trip, seconds, as gm_scheduler.queue's CLIENT_OVERHEAD.
CLIENT_OVERHEAD = 0.0004
P95_Z = 1.645
KEY_LINE = re.compile(r"key minute=(\S+) key=(\S+) calls=(\d+) errors=(\d+) "
                      r"p50_ms=(\S+) p95_ms=(\S+)")
SEL_RE = re.compile(r"^([A-Za-z_:][A-Za-z0-9_:]*)?(?:\{(.*)\})?$")
MATCHER_RE = re.compile(r'\s*([A-Za-z_][A-Za-z0-9_]*)\s*(=~|!=|=)\s*"((?:[^"\\]|\\.)*)"\s*,?')
SAMPLE_RE = re.compile(r"^([A-Za-z_:][A-Za-z0-9_:]*)(\{.*\})?\s+(\S+)(?:\s+(\S+))?$")
LABEL_RE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*)="((?:[^"\\]|\\.)*)"')


class Fail(Exception):
    pass


# --- time and selectors ---------------------------------------------------

def instant(text):
    t = text.strip().replace("Z", "+00:00")
    if re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d\+00:00", t):
        t = t.replace("+00:00", ":00+00:00")
    d = dt.datetime.fromisoformat(t)
    if d.tzinfo is None:
        d = d.replace(tzinfo=dt.timezone.utc)
    return d.timestamp()


def iso(ts):
    return dt.datetime.fromtimestamp(ts, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_selector(text):
    m = SEL_RE.match(text.strip())
    if not m:
        raise Fail(f"{text!r}: not a selector name{{label=\"value\",...}}")
    name, body = m.group(1), m.group(2) or ""
    matchers = []
    pos = 0
    while pos < len(body):
        mm = MATCHER_RE.match(body, pos)
        if not mm:
            raise Fail(f"{text!r}: can't read the matchers at {body[pos:]!r}")
        label, op, value = mm.group(1), mm.group(2), mm.group(3)
        if label == "__name__" and op == "=":
            name = value
        else:
            matchers.append((label, op, re.compile(value) if op == "=~" else value))
        pos = mm.end()
    return name, matchers


def matches(selector, name, labels):
    want, matchers = selector
    if want and name != want:
        return False
    for label, op, value in matchers:
        have = name if label == "__name__" else labels.get(label, "")
        if op == "=" and have != value:
            return False
        if op == "!=" and have == value:
            return False
        if op == "=~" and not value.fullmatch(have):
            return False
    return True


# --- reading series -------------------------------------------------------

def read_om(path, selectors, since, until):
    """{selector index: {series: [(ts, value)]}} from an OpenMetrics dump
    (promtool tsdb dump-openmetrics), samples in [since, until]."""
    names = {s[0] for s in selectors}
    prefixes = None if None in names or "" in names else tuple(names)
    found = [dict() for _ in selectors]
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("#") or (prefixes and not line.startswith(prefixes)):
                continue
            m = SAMPLE_RE.match(line.rstrip("\n"))
            if not m or m.group(4) is None:
                continue
            ts = float(m.group(4))
            if ts < since or ts > until:
                continue
            name, lab = m.group(1), m.group(2) or ""
            labels = dict(LABEL_RE.findall(lab))
            for i, sel in enumerate(selectors):
                if matches(sel, name, labels):
                    found[i].setdefault(name + lab, []).append((ts, float(m.group(3))))
    return found


def gmctl_exec(scenario, playground, node, user, script):
    r = subprocess.run([sys.executable, str(GMCTL), "exec", str(scenario), "--playground",
                        playground, "--node", node, "--user", user],
                       input=script, text=True, capture_output=True)
    if r.returncode != 0:
        raise Fail(f"gmctl exec on {node} failed ({r.returncode}): {r.stderr.strip()[-400:]}")
    return r.stdout


def read_live(scenario, playground, texts, since, until, step=15):
    """The same structure from the playground's Prometheus (query_range,
    through gmctl exec on the prometheus node)."""
    found = []
    for text in texts:
        q = "&".join(f"{k}={v}" for k, v in (
            ("query", _urlquote(text)), ("start", f"{since:.0f}"), ("end", f"{until:.0f}"),
            ("step", str(step))))
        url = f"http://127.0.0.1:9090/prometheus/api/v1/query_range?{q}"
        out = gmctl_exec(scenario, playground, "prometheus", "prometheus",
                         f"curl -fsS --max-time 120 {shlex.quote(url)}\n")
        data = json.loads(out)
        series = {}
        for r in data.get("data", {}).get("result", []):
            lab = r["metric"]
            name = lab.pop("__name__", "")
            key = name + "{" + ",".join(f'{k}="{v}"' for k, v in sorted(lab.items())) + "}"
            series[key] = [(float(t), float(v)) for t, v in r["values"]]
        found.append(series)
    return found


def _urlquote(text):
    from urllib.parse import quote
    return quote(text, safe="")


def increase(samples, t0, t1):
    """A counter's increase over [t0, t1], resets counted (Prometheus'
    increase without extrapolation)."""
    pts = [(t, v) for t, v in samples if t0 <= t <= t1]
    total = 0.0
    for (_, a), (_, b) in zip(pts, pts[1:]):
        total += b - a if b >= a else b
    return total


def summed_increase(series, t0, t1):
    return sum(increase(s, t0, t1) for s in series.values())


# --- subcommands ----------------------------------------------------------

def scenario_info(scenario):
    import yaml
    data = yaml.safe_load((scenario / "scenario.yaml").read_text())
    return data["id"]


def holds(scenario, node):
    """{key: transaction hold seconds} from the node's queries.yaml."""
    import yaml
    path = scenario / "nodes" / node / "queries.yaml"
    if not path.is_file():
        return {}
    data = yaml.safe_load(path.read_text()) or {}
    entries = data.get("queries", data) if isinstance(data, dict) else {}
    out = {}
    for key, entry in (entries or {}).items():
        if isinstance(entry, dict) and isinstance(entry.get("transaction"), dict):
            out[key] = _duration(entry["transaction"].get("hold"))
    return out


def _duration(v):
    if v is None:
        return 0.0
    if isinstance(v, (int, float)):
        return float(v)
    m = re.fullmatch(r"(\d+(?:\.\d+)?)(ms|s|m|h)", str(v).strip())
    if not m:
        return 0.0
    return float(m.group(1)) * {"ms": 0.001, "s": 1, "m": 60, "h": 3600}[m.group(2)]


def cmd_keys(a, scenario, out):
    if a.log:
        text = Path(a.log).read_text(errors="replace")
    elif a.playground:
        text = gmctl_exec(scenario, a.playground, a.node, "root",
                          "grep ' key minute=' /var/log/scheduler/scheduler.log || true\n")
    else:
        raise Fail("keys: --log or --playground")
    since = instant(a.since) if a.since else -math.inf
    until = instant(a.until) if a.until else math.inf
    hold = holds(scenario, a.node)
    rows = {}
    for m in KEY_LINE.finditer(text):
        t = instant(m.group(1))
        if not since <= t < until or (a.key and m.group(2) not in a.key):
            continue
        r = rows.setdefault(m.group(2), {"minutes": 0, "calls": 0, "errors": 0, "p50": [], "spread": []})
        r["minutes"] += 1
        r["calls"] += int(m.group(3))
        r["errors"] += int(m.group(4))
        p50 = None if m.group(5) == "-" else float(m.group(5)) / 1000
        p95 = None if m.group(6) == "-" else float(m.group(6)) / 1000
        if p50 is not None:
            r["p50"].append(p50)
            if p95 is not None and p95 > p50 > 0:
                r["spread"].append(math.log(p95 / p50) / P95_Z)
    out(f"node {a.node}; key lines {iso(since) if since > -math.inf else 'start'} to "
        f"{iso(until) if until < math.inf else 'end'}")
    out(f"{'key':28} {'min':>5} {'calls':>7} {'errors':>6} {'share':>6} {'p50 s':>8} {'hold s':>7}"
        f" {'median':>8} {'sigma':>5}")
    snippet = []
    for key in sorted(rows):
        r = rows[key]
        p50 = statistics.median(r["p50"]) if r["p50"] else None
        h = hold.get(key, 0.0)
        med = max(p50 - CLIENT_OVERHEAD - h, 0.0) if p50 is not None else None
        sig = statistics.median(r["spread"]) if r["spread"] else None
        share = r["errors"] / r["calls"] if r["calls"] else 0.0
        out(f"{key:28} {r['minutes']:5} {r['calls']:7} {r['errors']:6} {share:6.3f} "
            f"{_f(p50, 8, 4)} {h:7.1f} {_f(med, 8, 4)} {_f(sig, 5, 2)}")
        if med is not None:
            snippet.append(f"  {key}: {{median: {_sig(med)}, sigma: {_sig(sig or 0.0, 2)}}}")
    out("service-times.yaml keys (median/sigma, seconds):")
    for line in snippet:
        out(line)


def _f(v, w, d):
    return f"{'-':>{w}}" if v is None else f"{v:{w}.{d}f}"


def _sig(v, n=2):
    if v == 0:
        return "0"
    return f"{v:.{max(n - 1 - int(math.floor(math.log10(abs(v)))), 0)}f}"


def _series(a, scenario, texts, since, until):
    selectors = [parse_selector(t) for t in texts]
    if a.om:
        return read_om(a.om, selectors, since - 120, until + 120)
    if a.playground:
        return read_live(scenario, a.playground, texts, since - 120, until + 120)
    raise Fail("--om or --playground")


def cmd_per_call(a, scenario, out):
    since, until = instant(a.since), instant(a.until)
    key_sel = f'scheduler_calls_total{{instance="{a.node}:{SCHEDULER_PORT}",key="{a.key}"}}'
    texts = [key_sel, "scheduler_calls_total"] + a.series
    lo = instant(a.baseline_since) if a.baseline_since else since
    got = _series(a, scenario, texts, lo, until)
    keyc, allc, rest = got[0], got[1], got[2:]
    if not keyc:
        raise Fail(f"no samples of {key_sel}")
    if a.planted:
        p = instant(a.planted)
        dk = summed_increase(keyc, p, until)
        da_b, da_a = summed_increase(allc, lo, p), summed_increase(allc, p, until)
        out(f"key {a.node}/{a.key}: {dk:.0f} calls {iso(p)} to {iso(until)}; every key "
            f"{da_b:.0f} calls {iso(lo)} to {iso(p)} (baseline), {da_a:.0f} after")
    else:
        dk = summed_increase(keyc, since, until)
        out(f"key {a.node}/{a.key}: {dk:.0f} calls {iso(since)} to {iso(until)}")
    if dk <= 0:
        raise Fail("the key made no call in the window")
    for text, series in zip(a.series, rest):
        if not series:
            out(f"{text}: no samples")
            continue
        if a.planted:
            ds_b, ds_a = summed_increase(series, lo, p), summed_increase(series, p, until)
            b = ds_b / da_b if da_b else 0.0
            per = (ds_a - b * da_a) / dk
            out(f"{text}: before {ds_b:.6g} ({b:.6g} a call of any key), after {ds_a:.6g}; "
                f"per_call {per:.6g}")
        else:
            ds = summed_increase(series, since, until)
            out(f"{text}: increase {ds:.6g}; per_call {ds / dk:.6g}")


def cmd_gauge(a, scenario, out):
    since, until = instant(a.since), instant(a.until)
    got = _series(a, scenario, a.series, since, until)
    for text, series in zip(a.series, got):
        for name, samples in sorted(series.items()):
            vals = [v for t, v in samples if since <= t <= until]
            if not vals:
                continue
            falls = [t for (t0, v0), (t, v) in zip(samples, samples[1:])
                     if since <= t <= until and v < v0 - 0.5 * (max(vals) - min(vals))]
            period = statistics.median([b - c for c, b in zip(falls, falls[1:])]) if len(falls) > 1 else None
            out(f"{name}: {len(vals)} samples, min {min(vals):.6g}, median "
                f"{statistics.median(vals):.6g}, max {max(vals):.6g}, falls {len(falls)}, "
                f"period {'-' if period is None else f'{period:.0f} s'}")


WAL_SQL = "SELECT wal_bytes, extract(epoch FROM now()) FROM pg_stat_wal"


def cmd_wal(a, scenario, out):
    mark = scenario / "local" / a.playground / "calibration" / f"wal-{a.node}.mark"
    text = gmctl_exec(scenario, a.playground, a.node, "postgres",
                      f"psql -XAtq -F ' ' -c {shlex.quote(WAL_SQL)}\n").split()
    wal, at = float(text[0]), float(text[1])
    if a.mark:
        mark.parent.mkdir(parents=True, exist_ok=True)
        mark.write_text(f"{wal:.0f} {at:.3f}\n")
        out(f"{a.node}: wal_bytes {wal:.0f} at {iso(at)} (marked)")
        return
    if not mark.is_file():
        raise Fail(f"no mark {mark}: run with --mark after the data load")
    w0, t0 = (float(x) for x in mark.read_text().split())
    hours = (at - t0) / 3600
    out(f"{a.node}: wal_bytes {w0:.0f} at {iso(t0)} to {wal:.0f} at {iso(at)} ({hours * 60:.1f} min)")
    out(f"bytes_per_hour: {round((wal - w0) / hours)}")


def cmd_fault(a, scenario, out):
    import yaml
    state = scenario / "local" / a.playground / "state.yaml"
    data = yaml.safe_load(state.read_text()) or {}
    for p in data.get("plantings", []) or []:
        if p.get("instance") == a.fault:
            out(f"{a.fault}: planted_at {p.get('planted_at')} ({p.get('outcome', '-')})")
            return
    raise Fail(f"{a.fault}: no planting in {state}")


# --- main -----------------------------------------------------------------

def parser():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("scenario", type=Path)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def common(p):
        p.add_argument("--record", metavar="WHAT", help="also write the output to calibration/")
        p.add_argument("--playground")
        return p

    p = common(sub.add_parser("keys"))
    p.add_argument("--node", required=True)
    p.add_argument("--key", action="append")
    p.add_argument("--log")
    p.add_argument("--since")
    p.add_argument("--until")
    p = common(sub.add_parser("per-call"))
    p.add_argument("--node", required=True)
    p.add_argument("--key", required=True)
    p.add_argument("--series", action="append", required=True)
    p.add_argument("--om")
    p.add_argument("--since", required=True)
    p.add_argument("--until", required=True)
    p.add_argument("--planted")
    p.add_argument("--baseline-since")
    p = common(sub.add_parser("gauge"))
    p.add_argument("--series", action="append", required=True)
    p.add_argument("--om")
    p.add_argument("--since", required=True)
    p.add_argument("--until", required=True)
    p = common(sub.add_parser("wal"))
    p.add_argument("--node", required=True)
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--mark", action="store_true")
    g.add_argument("--from-mark", action="store_true")
    p = common(sub.add_parser("fault"))
    p.add_argument("--fault", required=True)
    return ap


def main(argv=None):
    a = parser().parse_args(argv)
    scenario = a.scenario.resolve()
    if a.cmd in ("wal", "fault") and not a.playground:
        print(f"calibrate.py {a.cmd}: --playground is required", file=sys.stderr)
        return 2
    lines = []

    def out(text):
        print(text, flush=True)
        lines.append(text)

    start = time.time()
    try:
        sid = scenario_info(scenario)
        {"keys": cmd_keys, "per-call": cmd_per_call, "gauge": cmd_gauge,
         "wal": cmd_wal, "fault": cmd_fault}[a.cmd](a, scenario, out)
    except Fail as e:
        print(f"calibrate.py: {e}", file=sys.stderr)
        return 1
    if a.record:
        commit = subprocess.run(["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"],
                                capture_output=True, text=True).stdout.strip()
        stamp = dt.datetime.fromtimestamp(start, dt.timezone.utc).strftime("%Y%m%dT%H%MZ")
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        path = OUT_DIR / f"{sid}-{a.record}-{stamp}.txt"
        argv_text = " ".join(shlex.quote(x) for x in (argv if argv is not None else sys.argv[1:]))
        head = [f"command: tools/fake_aging/calibrate.py {argv_text}", f"commit: {commit}",
                f"start: {iso(start)}", f"wall time: {time.time() - start:.0f} s", ""]
        path.write_text("\n".join(head + lines) + "\n")
        print(f"recorded: {path.relative_to(REPO)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
