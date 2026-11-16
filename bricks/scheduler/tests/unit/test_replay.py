"""The real mode's replay guard (v0.6 build plan, chunk 8; master spec 16:
the real mode's scheduling stays byte for byte as it is).

A fixed seed and a fixed virtual clock drive the real mode (runner.Scheduler,
its streams, jobs, timeline, summaries and a reload) against a recording
driver; the planned calls, the log's lines and the metrics endpoint's text
are compared byte for byte with `replay/corpus.txt`, recorded from
`scheduler` 0.3.0's code (the program before the fill was added). Every later
change to the program keeps this test green.

No database, no network, no real time: an event loop whose clock jumps to
its next timer (VirtualLoop), the runner's and the log's `time` module
replaced by that clock, and the pools' driver replaced by a recorder whose
latencies and errors come from the statement's text. It runs on any host
with PyYAML, and in the image with the other unit tests.

Recording the corpus again is a deliberate act, never a way to make the test
pass: GM_REPLAY_RECORD=<file> writes the run's text there instead of
comparing.
"""

import asyncio
import hashlib
import os
import selectors
import shutil
import tempfile
import unittest
from unittest import mock

import yaml

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "replay", "corpus.txt")
EPOCH = 1767614310.0          # 2026-01-05T11:58:30Z, a Monday: the run crosses 12:00 (the shape steps)
SPAN = 330.0                  # virtual seconds the real mode runs
RELOAD_AT = 125.0             # a SIGHUP's reload, mid-run

QUERIES = """\
queries:
  orders.place:
    transaction: {isolation: read committed}
    steps:
      - sql: INSERT INTO orders (order_no, amount, at) VALUES (%(order_no)s, %(amount)s, %(at)s)
        params:
          order_no: {sequence: [1000, 1]}
          amount: {decimal: [5, 250, 2]}
          at: {now: utc}
      - sql: UPDATE customers SET last_order_at = now() WHERE id = %(customer)s
        params:
          customer: {int: [1, 500]}
  catalog.lookup:
    - sql: SELECT * FROM products WHERE sku = %(sku)s
      params:
        sku: {choice: [TB-00001, TB-00002, TB-00003]}
      weight: 3
    - sql: SELECT * FROM products WHERE name ILIKE %(name)s
      params:
        name: {choice: {"%tent%": 2, "%boot%": 1}}
  catalog.search:
    sql: SELECT gm_fail(%(q)s)
    params:
      q: {choice: [rope, stove]}
  reports.recent:
    sql: SELECT * FROM orders ORDER BY at DESC LIMIT 20
  reports.dashboard:
    transaction: {isolation: repeatable read, hold: 7s}
    sql: SELECT count(*) FROM orders
  orders.close-day:
    transaction: {isolation: read committed, hold: 75s}
    sql: UPDATE customers SET lifetime_value = lifetime_value
  reports.batch:
    builder: builders/batch.py:build
    options: {base: 2}
  reports.broken:
    builder: builders/batch.py:broken
"""

BUILDER = """\
def build(intensity, options, rng=None):
    n = int(options["base"] * intensity) + rng.randint(0, 2)
    return [("INSERT INTO batches (n) VALUES (%(n)s)", {"n": i}) for i in range(n)], True


def broken(intensity, options):
    raise ValueError("no data for this month")
"""

JOBS = """\
jobs:
  - name: close-day
    key: orders.close-day
    connection: app
    at: "* * * * *"
  - name: batch
    key: reports.batch
    connection: app
    at: "*/2 * * * *"
  - name: broken
    key: reports.broken
    connection: app
    at: "1 12 * * *"
  - name: offline
    key: reports.recent
    connection: down
    at: "0 12 * * *"
"""

JOBS_RELOADED = JOBS.replace('at: "*/2 * * * *"', 'at: "*/3 * * * *"')

SHAPE = {d: [0.5] * 12 + [1.0] * 12 for d in ("mon", "tue", "wed", "thu", "fri", "sat", "sun")}

SCHEDULE = {
    "seed": 4815162342,
    "intensity": 1.0,
    "connections": {
        "app": {"driver": "sql/postgresql", "target": "db:5432/shop", "role": "shop_app", "pool": {"size": 3}},
        "reports": {"driver": "sql/postgresql", "target": "db:5432/shop", "role": "shop_reports",
                    "pool": {"per-call": True}},
        "down": {"driver": "sql/postgresql", "target": "gone:5432/shop", "role": "shop_app", "pool": {"size": 1}},
    },
    "streams": [
        {"key": "orders.place", "connection": "app", "rate": "40/min", "arrivals": "poisson",
         "shape": "noon", "concurrency": 2},
        {"key": "catalog.lookup", "connection": "app", "rate": "90/min", "arrivals": "poisson", "concurrency": 3},
        {"key": "reports.recent", "connection": "reports", "rate": "6/min", "arrivals": "even", "shape": "noon"},
        {"key": "reports.dashboard", "connection": "reports", "rate": "2/min", "arrivals": "even"},
    ],
    "shapes": {"noon": {"utc": SHAPE}},
    "timeline": [
        {"at": "2026-01-05T12:01:00Z", "stream": "catalog.lookup", "set": {"key": "catalog.search"}},
        {"at": "2026-01-05T12:02:30Z", "stream": "catalog.lookup", "set": {"key": "catalog.lookup", "rate": "30/min"}},
        {"at": "2026-01-05T12:00:20Z", "stream": "reports.recent", "set": {"connection": "app"}},
    ],
}


class VirtualLoop(asyncio.SelectorEventLoop):
    """An event loop whose clock starts at 0 and jumps to its next timer
    whenever nothing is ready: no real waiting, the same order every run."""

    def __init__(self):
        self._vt = 0.0
        super().__init__(selector=_JumpSelector(self))

    def time(self):
        return self._vt


class _JumpSelector(selectors.DefaultSelector):
    def __init__(self, loop):
        super().__init__()
        self._loop = loop

    def select(self, timeout=None):
        events = super().select(0)
        if not events and timeout is not None and timeout > 0:
            self._loop._vt += timeout
        return events


class VirtualTime:
    """Stands for the `time` module in the runner and the log."""

    def __init__(self, loop):
        self.loop = loop

    def time(self):
        return EPOCH + self.loop.time()

    def monotonic(self):
        return self.loop.time()


def _digest(text):
    return int.from_bytes(hashlib.sha256(text.encode()).digest()[:4], "big")


class Recorder:
    """The pools' driver: every statement written down with its virtual
    instant; its latency (0 to 40 ms) and its failures come from its text."""

    def __init__(self, clock):
        self.clock = clock
        self.calls = []
        self.final = []           # the sessions closed at the stop: a set's order, so sorted
        self.stopping = False
        self.sessions = 0

    def note(self, conn, what):
        (self.final if self.stopping else self.calls).append(f"{self.clock.time():.6f} {conn} {what}")


class RecSession:
    def __init__(self, rec, connection, n):
        self.rec, self.connection, self.n = rec, connection, n
        self.broken = False

    async def execute(self, statement, params):
        from gm_scheduler.drivers import DriverError, Result
        key = f"{statement}|{sorted((params or {}).items())!r}"
        self.rec.note(f"{self.connection.name}#{self.n}", f"execute {statement!r} {sorted((params or {}).items())!r}")
        await asyncio.sleep((_digest(key) % 4000) / 100000.0)
        if "gm_fail" in statement:
            raise DriverError("42883", "function gm_fail(text) does not exist")
        return Result(1 + _digest(key) % 5, 0.0)

    async def begin(self, isolation):
        self.rec.note(f"{self.connection.name}#{self.n}", f"begin {isolation}")

    async def commit(self):
        self.rec.note(f"{self.connection.name}#{self.n}", "commit")

    async def rollback(self):
        self.rec.note(f"{self.connection.name}#{self.n}", "rollback")

    async def close(self):
        self.rec.note(f"{self.connection.name}#{self.n}", "close")


class RecDriver:
    def __init__(self, rec):
        self.rec = rec

    async def connect(self, connection, secret, application_name):
        from gm_scheduler.drivers import DriverError
        self.rec.sessions += 1
        self.rec.note(f"{connection.name}#{self.rec.sessions}", f"connect {connection.role} as {application_name}")
        if connection.host == "gone":
            raise DriverError("08001", f"could not translate host name \"{connection.host}\"", connect=True,
                              lost=True)
        return RecSession(self.rec, connection, self.rec.sessions)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def replay():
    """Runs the real mode for SPAN virtual seconds; returns the corpus text."""
    from gm_scheduler import pools, runner, textlog
    from gm_scheduler.schedule import read_schedule
    root = tempfile.mkdtemp(prefix="gm-replay-")
    try:
        cfg = {
            "log": os.path.join(root, "log", "scheduler.log"),
            "status": os.path.join(root, "run", "status"),
            "loaded": os.path.join(root, "run", "loaded"),
            "marker": os.path.join(root, "state", "load-started"),
            "state": os.path.join(root, "lib"),
            "repository": os.path.join(root, "repository"),
            "jobs": os.path.join(root, "jobs", "jobs.yaml"),
            "schedule_seed": os.path.join(root, "seed", "schedule.yaml"),
            "metrics": {"listen": "127.0.0.1", "port": 1, "path": "/metrics"},
        }
        for d in ("log", "run", "state", "lib"):
            os.makedirs(os.path.join(root, d), exist_ok=True)
        write(os.path.join(cfg["repository"], "queries.yaml"), QUERIES)
        write(os.path.join(cfg["repository"], "builders", "batch.py"), BUILDER)
        write(cfg["jobs"], JOBS)
        stdin = ("gm-scheduler-input 1\npassword shop_app pw-app\npassword shop_reports pw-rep\nschedule\n"
                 + yaml.safe_dump(SCHEDULE))
        loop = VirtualLoop()
        clock = VirtualTime(loop)
        rec = Recorder(clock)
        with mock.patch.object(runner, "time", clock), mock.patch.object(textlog, "time", clock), \
                mock.patch.object(pools, "get_driver", lambda name: RecDriver(rec)):
            schedule, passwords, credentials = read_schedule(stdin)
            log = textlog.Log(cfg["log"])
            sched = runner.Scheduler(cfg, schedule, passwords, log, "replay-host", credentials)
            sched.repo, sched.jobs = sched.load_files()

            async def scenario():
                for key in sched.schedule.keys():
                    sched.stats.declare(key)
                for job in sched.jobs:
                    sched.stats.declare(job.key)
                sched.write_loaded()
                sched.spawn(sched.start_running(EPOCH - 3600), sched.tasks)
                await asyncio.sleep(RELOAD_AT)
                write(cfg["jobs"], JOBS_RELOADED)
                sched.reload()
                await asyncio.sleep(SPAN - RELOAD_AT)
                log.write("state", ("state", "stopping"))
                for task in list(sched.tasks) + list(sched.calls):
                    task.cancel()
                await asyncio.gather(*sched.tasks, *sched.calls, return_exceptions=True)
                rec.stopping = True
                await sched.close_pools()

            try:
                asyncio.set_event_loop(loop)
                loop.run_until_complete(scenario())
            finally:
                asyncio.set_event_loop(None)
                loop.close()
                log.close()
            metrics = sched.stats.prometheus()
        with open(cfg["log"], encoding="utf-8") as f:
            lines = f.read()
        return ("# calls\n" + "\n".join(rec.calls + sorted(rec.final)) + "\n# log\n" + lines + "# metrics\n"
                + metrics)
    finally:
        shutil.rmtree(root, ignore_errors=True)


class TestReplay(unittest.TestCase):
    def test_the_real_mode_replays_its_corpus_byte_for_byte(self):
        text = replay()
        target = os.environ.get("GM_REPLAY_RECORD")
        if target:
            write(target, text)
            self.skipTest(f"recorded the corpus into {target} (GM_REPLAY_RECORD): nothing compared")
        with open(CORPUS, encoding="utf-8") as f:
            corpus = f.read()
        if text != corpus:
            a, b = corpus.splitlines(), text.splitlines()
            first = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
            self.fail(f"the real mode no longer replays {CORPUS}: first difference at line {first + 1}:\n"
                      f"  corpus: {a[first] if first < len(a) else '<end>'}\n"
                      f"  now:    {b[first] if first < len(b) else '<end>'}")

    def test_the_replay_is_deterministic(self):
        self.assertEqual(replay(), replay())


if __name__ == "__main__":
    unittest.main()
