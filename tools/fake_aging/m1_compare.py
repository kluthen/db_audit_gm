#!/usr/bin/env python3
"""M1, a fake game's database state against run R's scaled to the game's
span (v0.6 master spec 12.1; capture W4 item 2; spec D586, D590).

Copied from the research's prototype, research/fake-aging 10d1bc6
`tools/research/fake_aging/m1_compare.py` (R's dump beside F runs that
aged R's own span, printed side by side, nothing judged), and
generalised: the game ages its own span from its own virtual T0, so each
measure is expected at

    T0 + s x (R - T0)

T0 the game's value in its dump at the virtual T0 (after `inject`, before
`fill`: the same data and T0 plantings R started from), R the value in
run R's dump, s the share of R's inserted rows (its M3 profile's
`rows inserted/s`, 24 hourly steps up to its 14:00 hand-over) that fell
in the game's span (`--span`, scenario time, from the virtual T0 to the
read). The database is the one the game's dump names (its meta.txt).

    python3 tools/fake_aging/m1_compare.py <reference-dir> <game-dir> --start <game T0 dir>
        --profile <reference M3 profile> --span <HH:MM>-<HH:MM>

Judged, within 3 % of the expected value (the research's tolerance), or
one row either way for a count under 34 (where 3 % is less than a row):
the measures inserts drive, each table's `n_tup_ins`, the sequences'
`last_value`, the database's `tup_inserted`. Reported as FIGURE lines
with their ratio to the expected value, never judged: each table's
`n_live_tup` (D593: an estimate VACUUM and ANALYZE overwrite, not a
count inserts drive; run R's `daily_sales` reads 30 for 15 rows), the
rest of the research's list (updates, HOT updates, scans, dead rows and
bloat, transaction ages, order statuses, temporary files, sessions),
which instances the game does not play move in R.

Run R ran PostgreSQL 18; the judged measures are counts the workload
drives, which the server's major does not move (D590).

Output: `PASS  <check>: <detail>`, `FAIL  ...`, `SKIP  ...`, `FIGURE  ...`,
then `m1_compare.py: <n> passed, <n> failed, <n> skipped`. Exit 0 nothing
failed, 1 a failure, 2 usage (nothing read), 77 the reference absent.
"""
import argparse
import csv
import os
import re
import sys

TOLERANCE = 0.03
R_HANDOVER = 14 * 60            # run R handed over at 14:00 scenario time (run-2026-11-14.md)
INSERTS = "rows inserted/s, shop"   # R's M3 profile, the research's name
REPORTED_TABLE = ("n_live_tup", "n_tup_upd", "n_tup_hot_upd", "seq_scan", "idx_scan",
                  "n_dead_tup", "autovacuum_count", "autoanalyze_count")
REPORTED_DB = ("xact_commit", "tup_updated", "tup_deleted", "temp_files", "sessions")
ABSENT = "the reference archive is absent"


class Usage(Exception):
    pass


def rows(d, name):
    p = os.path.join(d, name)
    if not os.path.exists(p):
        return []
    with open(p, newline="") as f:
        return list(csv.DictReader(f))


def by(rs, key):
    return {r[key]: r for r in rs}


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def minutes(text):
    m = re.fullmatch(r"(\d{1,2}):(\d{2})", text)
    if not m or int(m.group(1)) > 23 or int(m.group(2)) > 59:
        raise Usage(f"--span: {text!r} is not HH:MM")
    return int(m.group(1)) * 60 + int(m.group(2))


def share(profile, span):
    """s: the share of R's inserted rows in [a, b) scenario time, each hourly
    step's rate spread evenly over its hour (step i covers the hour ending
    i hours after R's start, 24 hours before its hand-over)."""
    a_text, sep, b_text = span.partition("-")
    if not sep:
        raise Usage(f"--span {span!r}: expected <HH:MM>-<HH:MM>")
    start = R_HANDOVER - 24 * 60
    a = (minutes(a_text) - start) % 1440
    b = (minutes(b_text) - start) % 1440 or 1440
    if b <= a:
        raise Usage(f"--span {span}: its end is not after its start within R's day")
    rates = profile["series"][INSERTS]
    total = inside = 0.0
    for i in range(1, 25):
        r = rates[i] if i < len(rates) else None
        if r is None:
            continue
        lo, hi = (i - 1) * 60, i * 60
        total += r * 60
        inside += r * max(0, min(hi, b) - max(lo, a))
    if not total:
        raise Usage(f"the profile's {INSERTS!r} holds no step")
    return inside / total, a, b


class Out:
    def __init__(self):
        self.passed = self.failed = self.skipped = 0

    def line(self, kind, text):
        print(f"{kind:6}{text}" if kind != "FIGURE" else f"FIGURE  {text}", flush=True)
        if kind == "PASS":
            self.passed += 1
        elif kind == "FAIL":
            self.failed += 1
        elif kind == "SKIP":
            self.skipped += 1


def expected(t0, r, s):
    return t0 + s * (r - t0)


def judge(out, what, game, t0, r, s):
    if game is None or t0 is None or r is None:
        out.line("FAIL", f"{what}: not read (game {game}, T0 {t0}, R {r})")
        return
    want = expected(t0, r, s)
    slack = max(TOLERANCE * abs(want), 1.0)
    ok = abs(game - want) <= slack
    ratio = f"{game / want:.3f}" if want else "-"
    out.line("PASS" if ok else "FAIL",
             f"{what}: {game:.0f} against {want:.1f} expected (T0 {t0:.0f}, R {r:.0f}; "
             f"ratio {ratio}, within {slack:.1f})")


def report(out, what, game, t0, r, s):
    if game is None:
        out.line("FIGURE", f"{what}: game -, T0 {t0}, R {r}")
        return
    if t0 is None or r is None:
        out.line("FIGURE", f"{what}: game {game:g}, T0 {t0}, R {r}")
        return
    want = expected(t0, r, s)
    ratio = f"{game / want:.2f}" if want else "-"
    out.line("FIGURE", f"{what}: game {game:g}, expected {want:.1f} (T0 {t0:g}, R {r:g}), ratio {ratio}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("reference")
    ap.add_argument("game")
    ap.add_argument("--start", required=True, metavar="<game T0 dir>")
    ap.add_argument("--profile", required=True, metavar="<reference M3 profile>")
    ap.add_argument("--span", required=True, metavar="<HH:MM>-<HH:MM>")
    try:
        a = ap.parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code else 0
    out = Out()
    if not os.path.isdir(a.reference) or not os.path.isfile(a.profile):
        out.line("SKIP", f"M1 against run R: {ABSENT} ({a.reference}, {a.profile})")
        print(f"m1_compare.py: {out.passed} passed, {out.failed} failed, {out.skipped} skipped")
        return 77
    for d in (a.game, a.start):
        if not os.path.isfile(os.path.join(d, "table_stats.csv")):
            print(f"m1_compare.py: {d}: no table_stats.csv (an m1_dump.sh folder?)", file=sys.stderr)
            return 2
    import json
    try:
        with open(a.profile) as f:
            profile = json.load(f)
        s, lo, hi = share(profile, a.span)
    except (Usage, ValueError, KeyError) as exc:
        print(f"m1_compare.py: {exc}", file=sys.stderr)
        return 2
    meta = {}
    with open(os.path.join(a.game, "meta.txt")) as f:
        for line in f:
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip()
    database = meta.get("database") or "shop"
    r_meta = (rows(a.reference, "meta.csv") or [{}])[0]
    version = (r_meta.get("version") or "").split(" on ")[0] or "PostgreSQL 18"
    out.line("FIGURE", f"reference: run R, a PostgreSQL 18 reference ({version}), read "
                       f"{r_meta.get('read_at', '-')}; its judged measures are counts the "
                       "workload drives (D590)")
    out.line("FIGURE", f"span {a.span} scenario time: R's inserted rows in it s = {s:.4f} "
                       f"(minutes {lo} to {hi} of R's day from 14:00)")

    stats = {d: by(rows(d, "table_stats.csv"), "relname") for d in (a.game, a.start, a.reference)}
    tables = sorted(set(stats[a.reference]) | set(stats[a.game]))
    for t in tables:
        g, z, r = (stats[d].get(t) for d in (a.game, a.start, a.reference))
        if g is None or r is None:
            out.line("FIGURE", f"table {t}: in the game {'yes' if g else 'no'}, in run R "
                               f"{'yes' if r else 'no'}; not compared")
            continue
        judge(out, f"{t}.n_tup_ins", num(g.get("n_tup_ins")), num((z or {}).get("n_tup_ins")),
              num(r.get("n_tup_ins")), s)
        for col in REPORTED_TABLE:
            report(out, f"{t}.{col}", num(g.get(col)), num((z or {}).get(col)), num(r.get(col)), s)

    seqs = {d: by(rows(d, "sequences.csv"), "sequencename") for d in (a.game, a.start, a.reference)}
    for q in sorted(set(seqs[a.reference]) | set(seqs[a.game])):
        g, z, r = (seqs[d].get(q) for d in (a.game, a.start, a.reference))
        if g is None or r is None:
            out.line("FIGURE", f"sequence {q}: in the game {'yes' if g else 'no'}, in run R "
                               f"{'yes' if r else 'no'}; not compared")
            continue
        judge(out, f"{q}.last_value", num(g.get("last_value")), num((z or {}).get("last_value")),
              num(r.get("last_value")), s)

    dbs = {d: by(rows(d, "database_stats.csv"), "datname") for d in (a.game, a.start, a.reference)}
    g, z, r = (dbs[d].get(database) for d in (a.game, a.start, a.reference))
    if g is None or r is None:
        out.line("FAIL", f"database {database}: not in both dumps")
    else:
        judge(out, f"database {database}.tup_inserted", num(g.get("tup_inserted")),
              num((z or {}).get("tup_inserted")), num(r.get("tup_inserted")), s)
        for col in REPORTED_DB:
            report(out, f"database {database}.{col}", num(g.get(col)), num((z or {}).get(col)),
                   num(r.get(col)), s)
    for other in ("postgres", "template1"):
        g, z, r = (dbs[d].get(other) for d in (a.game, a.start, a.reference))
        if g and r:
            report(out, f"database {other}.xact_commit (R's known difference)",
                   num(g.get("xact_commit")), num((z or {}).get("xact_commit")),
                   num(r.get("xact_commit")), s)

    bloat = {d: by(rows(d, "bloat_estimate.csv"), "relname") for d in (a.game, a.start, a.reference)}
    for t in tables:
        g, z, r = (bloat[d].get(t) for d in (a.game, a.start, a.reference))
        if g and r:
            report(out, f"{t} estimated bloat %", num(g.get("est_bloat_pct")),
                   num((z or {}).get("est_bloat_pct")), num(r.get("est_bloat_pct")), s)
    ages = {d: by(rows(d, "table_xid_age.csv"), "relname") for d in (a.game, a.start, a.reference)}
    for t in tables:
        g, z, r = (ages[d].get(t) for d in (a.game, a.start, a.reference))
        if g and r:
            report(out, f"{t} transaction age", num(g.get("xid_age")),
                   num((z or {}).get("xid_age")), num(r.get("xid_age")), s)
    st = {d: by(rows(d, "order_status.csv"), "status") for d in (a.game, a.start, a.reference)}
    for k in sorted(set(st[a.reference]) | set(st[a.game])):
        g, z, r = (st[d].get(k) for d in (a.game, a.start, a.reference))
        report(out, f"orders with status {k}", num((g or {}).get("count")),
               num((z or {}).get("count")), num((r or {}).get("count")), s)
    dup = {d: (rows(d, "duplicates.csv") or [{}])[0] for d in (a.game, a.start, a.reference)}
    if dup[a.reference] and dup[a.game]:
        for k in ("events", "distinct_events"):
            report(out, f"delivery events, {k}", num(dup[a.game].get(k)),
                   num(dup[a.start].get(k)), num(dup[a.reference].get(k)), s)
    print(f"m1_compare.py: {out.passed} passed, {out.failed} failed, {out.skipped} skipped")
    return 1 if out.failed else 0


if __name__ == "__main__":
    sys.exit(main())
