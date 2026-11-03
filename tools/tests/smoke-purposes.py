"""Helpers of smoke-purposes.sh (v0.4 build plan chunk 17a; capture W4
items 6 to 8): the file surgery and the readings the shell script leaves
to Python. Run as `python3 -B tools/tests/smoke-purposes.py <command> ...`;
it never touches a node: the script reads and writes the nodes' files
through `gmctl exec` and gives them here as local files.

Commands:
  handover <HH:MM> <t0 epoch>
      the planned hand-over (YYYY-MM-DDTHH:00Z) putting the scenario's
      time at T0 within half an hour of <HH:MM> (the shift is whole hours,
      so the minutes are UTC's), the first whole hour after T0 whose
      scenario time is the designed 14:00; prints "<handover> <shift>"
  local <epoch> <shift>
      the scenario's local time of an instant, "YYYY-MM-DD HH:MM"
  next-local <epoch> <shift> <HH:MM>
      the epoch of the next scenario-time <HH:MM> at or after <epoch>
  move-jobs <jobs.yaml> <out> <job>=<epoch> ...
      a deployed jobs.yaml (UTC) with each named job's `at` set to the
      UTC minute and hour of its epoch, every other line kept byte for byte
  swap-entry <queries.yaml> <source> <key> <out>
      the deployed queries.yaml with entry <key>'s block (its line and the
      lines indented deeper) replaced by the source's (a queries.yaml or a
      fault's snippet); refuses unless the result loads with the entry
      equal to the source's
  procedure <data file> <name>
      the first `CREATE PROCEDURE <name>` of a data file, to its `$$;`, as
      `CREATE OR REPLACE PROCEDURE` (the purpose's material, before any
      fault snippet)
  move-crontab <crontab> <out> <pattern> <epoch>
      a crontab with the entry whose command contains <pattern> set to the
      epoch's UTC minute and hour, every other line kept
  baseline <scenario copy> <fixture>
      capture W4 item 8: the copy's item 2 files replaced by the fixture's
      (crm's queries, bi's rollup.py, db's and reporting's crontabs, the
      producer's and the gateway's queries and schedule), the data file
      cut at the fixture's last line
  verdict <instance>
      the verdict word of <instance>'s line in `gmctl check`'s output
      (stdin): fixed, present, too-soon, error; "none" without a line
  runs <job> <from epoch>
      from a scheduler log (stdin): "<status> <end epoch>" of each run of
      <job> whose end line is at or after <from>, oldest first
  reload-after <epoch>
      from a scheduler log (stdin): the epoch of the first `reload
      status=ok` at or after <epoch>; nothing without one
  keys <scenario copy> <node> <t0 epoch> <now epoch> <planned hand-over> <shift>
      from a scheduler log (stdin): every stream key current at some
      minute since T0 (the timeline applied: a key set at or before T0
      replaces the stream's at T0) with calls counted since T0; a key
      whose rate, shape and intensity give it at least 4 calls over its
      time (scenario hours, the shift applied) fails without one, a
      slower one is listed, not judged; prints "ok ..." or one line per
      failing key
"""

import datetime
import re
import sys

import yaml

UTC = datetime.timezone.utc


def at(epoch):
    return datetime.datetime.fromtimestamp(int(epoch), UTC)


def instant(text):
    """A log line's first field (ISO, Z, optional fraction) -> epoch."""
    text = text.rstrip("Z")
    for fmt in ("%Y-%m-%dT%H:%M:%S.%f", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%MZ"):
        try:
            return datetime.datetime.strptime(text, fmt).replace(tzinfo=UTC).timestamp()
        except ValueError:
            pass
    return None


def handover(target, t0):
    hh, mm = (int(x) for x in target.split(":"))
    t0 = at(t0)
    want = hh + mm / 60
    have = t0.hour + t0.minute / 60
    shift = round(want - have)
    shift = (shift + 11) % 24 - 11                  # -11..12, as render's compute_shift
    moment = t0.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=1)
    while (moment.hour + shift) % 24 != 14:
        moment += datetime.timedelta(hours=1)
    print(moment.strftime("%Y-%m-%dT%H:00Z"), shift)


def local(epoch, shift):
    print((at(epoch) + datetime.timedelta(hours=int(shift))).strftime("%Y-%m-%d %H:%M"))


def next_local(epoch, shift, target):
    hh, mm = (int(x) for x in target.split(":"))
    loc = at(epoch) + datetime.timedelta(hours=int(shift))
    moment = loc.replace(hour=hh, minute=mm, second=0, microsecond=0)
    if moment < loc:
        moment += datetime.timedelta(days=1)
    print(int((moment - datetime.timedelta(hours=int(shift))).timestamp()))


def move_jobs(path, out, *pairs):
    text = open(path, encoding="utf-8").read()
    lines = text.splitlines(keepends=True)
    wanted = {}
    for pair in pairs:
        job, _, epoch = pair.partition("=")
        moment = at(epoch)
        wanted[job] = f"{moment.minute} {moment.hour} * * *"
    current, done = None, set()
    for i, line in enumerate(lines):
        m = re.match(r"^\s*-\s+name:\s*['\"]?([^'\"\s]+)", line)
        if m:
            current = m.group(1)
            continue
        m = re.match(r"^(\s*)at:\s*\S.*?(\r?\n)?$", line)
        if m and current in wanted and current not in done:
            lines[i] = f"{m.group(1)}at: \"{wanted[current]}\"{m.group(2) or ''}"
            done.add(current)
    missing = set(wanted) - done
    if missing:
        sys.exit(f"move-jobs: no job {', '.join(sorted(missing))} with an at: line in {path}")
    result = "".join(lines)
    jobs = {j["name"]: j for j in yaml.safe_load(result)["jobs"]}
    for job, cron in wanted.items():
        if jobs[job]["at"] != cron:
            sys.exit(f"move-jobs: {job}'s at reads {jobs[job]['at']!r}, not {cron!r}")
    open(out, "w", encoding="utf-8").write(result)


def entry_block(lines, key):
    """(start, end) of entry `key`: its `  key:` line and the lines after
    it indented deeper than it, blank lines inside included."""
    for i, line in enumerate(lines):
        m = re.match(r"^(\s*)" + re.escape(key) + r":\s*$", line)
        if m:
            indent = len(m.group(1))
            j = i + 1
            while j < len(lines):
                stripped = lines[j].strip()
                if stripped and len(lines[j]) - len(lines[j].lstrip()) <= indent:
                    break
                j += 1
            while j > i + 1 and not lines[j - 1].strip():
                j -= 1
            return i, j
    sys.exit(f"swap-entry: no entry {key}")


def swap_entry(path, source, key, out):
    dest = open(path, encoding="utf-8").read().splitlines(keepends=True)
    src = open(source, encoding="utf-8").read().splitlines(keepends=True)
    d0, d1 = entry_block(dest, key)
    s0, s1 = entry_block(src, key)
    block = src[s0:s1]
    if block and not block[-1].endswith("\n"):
        block[-1] += "\n"
    result = "".join(dest[:d0] + block + dest[d1:])
    want = yaml.safe_load("queries:\n" + "".join(src[s0:s1]))["queries"][key]
    got = yaml.safe_load(result)["queries"][key]
    if got != want:
        sys.exit(f"swap-entry: {key} does not read as the source's after the swap")
    open(out, "w", encoding="utf-8").write(result)


def procedure(path, name):
    lines = open(path, encoding="utf-8").read().splitlines()
    for i, line in enumerate(lines):
        if line.strip() == f"CREATE PROCEDURE {name}":
            for j in range(i + 1, len(lines)):
                if lines[j].strip() == "$$;":
                    print("CREATE OR REPLACE PROCEDURE " + name)
                    print("\n".join(lines[i + 1:j + 1]))
                    return
    sys.exit(f"procedure: no CREATE PROCEDURE {name} ... $$; in {path}")


def move_crontab(path, out, pattern, epoch):
    moment = at(epoch)
    lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
    hits = 0
    for i, line in enumerate(lines):
        if pattern in line and not line.lstrip().startswith("#"):
            fields = line.split(None, 5)
            lines[i] = f"{moment.minute} {moment.hour} {' '.join(fields[2:5])} {fields[5]}"
            hits += 1
    if hits != 1:
        sys.exit(f"move-crontab: {hits} entries contain {pattern!r} in {path}, not one")
    open(out, "w", encoding="utf-8").write("".join(lines))


ITEM2_FILES = ["nodes/crm/queries.yaml", "nodes/bi/scripts/rollup.py", "nodes/db/crontab",
               "nodes/reporting/crontab", "nodes/producer/queries.yaml",
               "nodes/producer/schedule.yaml", "nodes/gateway/queries.yaml",
               "nodes/gateway/schedule.yaml"]
DATA_FILE = "data/reporting.sql"


def baseline(scn, fixture):
    for name in ITEM2_FILES:
        with open(f"{fixture}/{name}", "rb") as src, open(f"{scn}/{name}", "wb") as dst:
            dst.write(src.read())
    last = [ln for ln in open(f"{fixture}/{DATA_FILE}", encoding="utf-8").read().splitlines()
            if ln.strip()][-1]
    lines = open(f"{scn}/{DATA_FILE}", encoding="utf-8").read().splitlines(keepends=True)
    cut = [i for i, ln in enumerate(lines) if ln.rstrip("\n") == last]
    if not cut:
        sys.exit(f"baseline: the fixture's last line {last!r} is not in the scenario's data file")
    open(f"{scn}/{DATA_FILE}", "w", encoding="utf-8").write("".join(lines[:cut[0] + 1]))
    print(f"{len(ITEM2_FILES)} files the fixture's; {DATA_FILE} cut at line {cut[0] + 1}")


def verdict(instance):
    for line in sys.stdin:
        m = re.match(r"^" + re.escape(instance) + r" \S+: (fixed|present|too-soon|error)\b", line)
        if m:
            print(m.group(1))
            return
    print("none")


def runs(job, since):
    for line in sys.stdin:
        if f" run job={job} " not in line + " " or "phase=end" not in line:
            continue
        when = instant(line.split(" ", 1)[0])
        if when is None or when < float(since):
            continue
        status = re.search(r"status=(\S+)", line)
        print(status.group(1) if status else "?", int(when))


def reload_after(since):
    for line in sys.stdin:
        if re.search(r" reload status=ok\b", line):
            when = instant(line.split(" ", 1)[0])
            if when is not None and when >= float(since):
                print(int(when))
                return


MOMENT_RE = re.compile(r"^handover-(\d+)h$")
RATE_RE = re.compile(r"^\s*([0-9.]+)\s*/\s*(s|min|h)\s*$")
RATE_UNITS = {"s": 1, "min": 60, "h": 3600}
JUDGED = 4.0          # expected calls from which a silent key fails (Poisson: P(0) < 2%)


def hour_factors(shape):
    """A scenario shape's `hours` spans -> 24 multipliers (scenario time);
    a `days` shape (none in this scenario) -> None, read as 1.0."""
    if not shape or "hours" not in shape:
        return None
    out = [1.0] * 24
    for span, value in shape["hours"].items():
        lo, _, hi = str(span).partition("-")
        for h in range(int(lo), int(hi or lo) + 1):
            out[h] = float(value)
    return out


def expected_calls(stream, shapes, intensity, start, end, shift):
    """The calls a stream's rate, shape and intensity give between two
    epochs, minute by minute in scenario time."""
    m = RATE_RE.match(str(stream.get("rate", "")))
    if not m or end <= start:
        return 0.0
    per_min = float(m.group(1)) / RATE_UNITS[m.group(2)] * 60 * intensity
    factors = hour_factors(shapes.get(stream.get("shape"))) if stream.get("shape") else None
    total, t = 0.0, start
    while t < end:
        hour = (at(t).hour + int(shift)) % 24
        total += per_min * min(60, end - t) / 60 * (factors[hour] if factors else 1.0)
        t += 60
    return total


def keys(scn, node, t0, now, planned, shift="0"):
    s = yaml.safe_load(open(f"{scn}/scenario.yaml"))
    n = next(x for x in s["nodes"] if x["name"] == node)
    sched = yaml.safe_load(open(f"{scn}/{n['seed_files']['schedule.yaml']}"))
    planned = datetime.datetime.strptime(planned, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)
    t0, now = float(t0), float(now)
    shapes = sched.get("shapes") or {}
    intensity = float(sched.get("intensity", 1.0))

    def moment(text):
        if str(text) == "T0":
            return t0
        m = MOMENT_RE.match(str(text))
        return (planned - datetime.timedelta(hours=int(m.group(1)))).timestamp() if m else None

    expected = {}                        # key -> expected calls since it became current
    for st in sched.get("streams") or []:
        changes = sorted(((moment(e["at"]), e["set"]["key"]) for e in sched.get("timeline") or []
                          if e.get("stream") == st["key"] and "key" in (e.get("set") or {})),
                         key=lambda c: c[0])
        spans, current, start = [], st["key"], t0
        for when, key in changes:
            if when <= t0:
                current = key
            elif when <= now - 60:
                spans.append((current, start, when))
                current, start = key, when
        spans.append((current, start, now - 60))
        for key, a, b in spans:
            expected[key] = expected.get(key, 0.0) + expected_calls(st, shapes, intensity, a, b, shift)
    calls = {}
    for line in sys.stdin:
        if " key minute=" not in line:
            continue
        f = dict(re.findall(r"(\w+)=(\S+)", line))
        when = instant(f["minute"].rstrip("Z") + ":00") if "minute" in f else None
        if when is not None and when >= t0 - 60:
            calls[f["key"]] = calls.get(f["key"], 0) + int(f.get("calls", 0))
    bad = [f"key {k}: no call since T0 ({e:.1f} expected)" for k, e in sorted(expected.items())
           if e >= JUDGED and not calls.get(k)]
    print("\n".join(bad) or "ok " + " ".join(
        f"{k}={calls.get(k, 0)}" + ("" if e >= JUDGED else f"(~{e:.1f}, not judged)")
        for k, e in sorted(expected.items())))


COMMANDS = {"handover": handover, "local": local, "next-local": next_local,
            "move-jobs": move_jobs, "swap-entry": swap_entry, "procedure": procedure,
            "move-crontab": move_crontab, "baseline": baseline, "verdict": verdict,
            "runs": runs, "reload-after": reload_after, "keys": keys}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
        sys.exit(f"usage: {sys.argv[0]} <{'|'.join(COMMANDS)}> ...")
    COMMANDS[sys.argv[1]](*sys.argv[2:])
