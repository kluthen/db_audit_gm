"""The program's life: idle or running, the tasks, reloads (master spec
7.1; capture W1 item 7; W1-y).

At start it reads the schedule from standard input, loads the repository
and jobs.yaml, opens the metrics endpoint, then:
  - without the load-started marker: idle (status `idle`, no call);
  - with it: running, from the current time: every timeline change whose
    moment has passed is applied, the jobs run at their next time, and
    nothing missed is replayed.
SIGHUP reloads the repository and jobs.yaml (the schedule, connections and
counters kept); SIGTERM stops it.
"""

import asyncio
import os
import signal
import socket
import sys
import time

import yaml

from . import ConfigError
from .drivers import DriverError
from .generators import Sequences
from .jobs import load_jobs
from .metrics import Stats, serve_metrics
from .pools import Pool
from .repository import BuilderResult, fingerprint, load_repository, loaded_files
from .rng import derive
from .schedule import apply_change, apply_past_changes
from .streams import draw_need, next_arrival, rate_function
from .textlog import Log
from .timeutil import instant, minute_start, parse_instant

# exit codes (W1-y): the finish script waits a few seconds after 2 and 3
EXIT_OK, EXIT_ERROR, EXIT_INPUT, EXIT_FILES = 0, 1, 2, 3

CONFIG_FILE = "/etc/scheduler/scheduler.yaml"
CONFIG_KEYS = {"log", "status", "loaded", "marker", "state", "repository", "jobs", "schedule_seed", "metrics"}
SUMMARY_DELAY = 1.0          # seconds after each UTC minute boundary
RATE_HORIZON = 3600.0        # a stream with no arrival re-plans at least hourly


def load_config(path=CONFIG_FILE):
    with open(path, encoding="utf-8") as f:
        cfg = yaml.safe_load(f)
    if not isinstance(cfg, dict) or set(cfg) != CONFIG_KEYS:
        raise ConfigError(f"{path}: keys {', '.join(sorted(CONFIG_KEYS))}")
    m = cfg["metrics"]
    if not isinstance(m, dict) or set(m) != {"listen", "port", "path"}:
        raise ConfigError(f"{path}: metrics is {{listen, port, path}}")
    return cfg


def write_atomic(path, text, mode=0o640):
    tmp = f"{path}.tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def check_references(schedule, repo, jobs):
    """Every key the schedule and jobs.yaml name is in the repository; every
    job's connection is the schedule's. Messages name only keys and the
    players' own job names (W1 item 7)."""
    problems = []
    for key in sorted(schedule.keys()):
        if key not in repo:
            problems.append(f"queries.yaml: key {key} is named by the schedule but is missing")
    for job in jobs:
        if job.key not in repo:
            problems.append(f"jobs.yaml: job {job.name}: key {job.key} is not in queries.yaml")
        if job.connection not in schedule.connections:
            problems.append(f"jobs.yaml: job {job.name}: connection {job.connection} is not one of the schedule's")
    return problems


class Context:
    """What generators need: the time and the sequences."""

    def __init__(self, sequences):
        self.sequences = sequences

    @staticmethod
    def now():
        return time.time()


async def sleep_until(ts):
    while True:
        delay = ts - time.time()
        if delay <= 0:
            return
        await asyncio.sleep(min(delay, 60.0))


async def run_plan(session, plan):
    rows = 0
    if plan.txn:
        await session.begin(plan.txn.isolation)
    try:
        for sql, params in plan.steps:
            rows += (await session.execute(sql, params)).rows
        if plan.txn:
            if plan.txn.hold:
                await asyncio.sleep(plan.txn.hold)
            await session.commit()
    except (DriverError, asyncio.CancelledError):
        if plan.txn and not session.broken:
            try:
                await session.rollback()
            except DriverError:
                pass
        raise
    return rows


class Scheduler:
    def __init__(self, cfg, schedule, passwords, log, hostname=None):
        self.cfg, self.schedule, self.passwords, self.log = cfg, schedule, passwords, log
        self.hostname = hostname or socket.gethostname()
        self.stats = Stats()
        self.stats.start_time = time.time()
        self.repo = None
        self.jobs = []
        self.generation = 0
        self.running = False
        self.started = None
        self.stop_event = None
        self.tasks = set()            # stream, job and summary tasks
        self.calls = set()            # calls and runs in flight
        self.job_tasks = {}
        self.job_running = {}         # job name -> its run task
        self.job_pools = {}
        self.all_pools = []
        self.ctx = Context(Sequences(os.path.join(cfg["state"], "sequences.json") if cfg.get("state") else None))

    # --- files ---------------------------------------------------------------
    def load_files(self):
        """Loads the repository and jobs.yaml and checks them against the
        schedule; raises ConfigError with every problem."""
        repo = load_repository(self.cfg["repository"])
        jobs = load_jobs(self.cfg["jobs"])
        problems = check_references(self.schedule, repo, jobs)
        if problems:
            raise ConfigError("; ".join(problems))
        return repo, jobs

    def write_loaded(self):
        self.generation += 1
        lines = [f"generation={self.generation}", f"loaded={instant(time.time())}"]
        for path, digest in fingerprint(loaded_files(self.cfg["repository"], self.cfg["jobs"])).items():
            lines.append(f"file {digest} {path}")
        now = time.time()
        for job in self.jobs:
            nxt = job.cron.next_after(now)
            lines.append(f"job {job.name} next={instant(nxt) if nxt else 'never'}")
        try:
            write_atomic(self.cfg["loaded"], "\n".join(lines) + "\n", 0o644)
        except OSError as exc:
            print(f"gm-scheduler: cannot write {self.cfg['loaded']}: {exc}", file=sys.stderr, flush=True)

    def write_status(self, state):
        try:
            write_atomic(self.cfg["status"], f"{state} {instant(time.time())}\n", 0o640)
        except OSError as exc:
            print(f"gm-scheduler: cannot write {self.cfg['status']}: {exc}", file=sys.stderr, flush=True)

    def reload(self):
        try:
            repo, jobs = self.load_files()
        except ConfigError as exc:
            self.log.write("reload", ("status", "refused"), ("message", str(exc)))
            return False
        self.repo, self.jobs = repo, jobs
        for job in jobs:
            self.stats.declare(job.key)
        if self.running:
            self.start_jobs()
        self.write_loaded()
        self.log.write("reload", ("status", "ok"), ("keys", len(repo.keys())), ("jobs", len(jobs)))
        return True

    # --- calls -----------------------------------------------------------------
    def pool_for(self, pools, name):
        pool = pools.get(name)
        if pool is None or pool.closing:
            c = self.schedule.connections[name]
            pool = Pool(c, self.passwords.get(c.role), self.hostname)
            pools[name] = pool
            self.all_pools.append(pool)
        return pool

    async def close_pools(self):
        pools, self.all_pools = self.all_pools, []
        for pool in pools:
            await pool.close_all()

    def make_plan(self, key, rng):
        """The plan of one call of `key`, drawn now (so the draws keep their
        order); returns (plan, None) or (None, error message)."""
        entry = self.repo.get(key) if key in self.repo else None
        if entry is None:
            return None, "the key is not in queries.yaml"
        try:
            return entry.plan(rng, self.ctx, self.schedule.intensity), None
        except BuilderResult as exc:
            return None, f"builder: {exc}"
        except Exception as exc:  # the builder's own code failed
            return None, f"builder: {type(exc).__name__}: {exc}"

    def record_error(self, key, code, message, job=None):
        fields = [("key", key)]
        if job is not None:
            fields.append(("job", job))
        fields += [("sqlstate", code), ("message", message)]
        self.log.write("error", *fields)

    async def call(self, key, plan, pool, started):
        error = None
        try:
            async with pool.session() as session:
                await run_plan(session, plan)
        except DriverError as exc:
            error = exc
        latency = time.monotonic() - started
        self.stats.record(key, latency, error is not None, time.time())
        if error is not None:
            self.record_error(key, error.code, error.message)

    def spawn(self, coro, group):
        task = asyncio.ensure_future(coro)
        group.add(task)
        task.add_done_callback(group.discard)
        return task

    # --- streams ---------------------------------------------------------------
    async def run_stream(self, stream, pending):
        rng = derive(self.schedule.seed, self.hostname, f"stream:{stream.index}:{stream.initial_key}", self.started)
        rate_at = rate_function(stream, self.schedule.intensity, self.schedule.shapes)
        slots = asyncio.Semaphore(stream.concurrency)
        pools = {}
        t = time.time()
        need = draw_need(rng, stream.arrivals)
        while True:
            limit = pending[0].at if pending else t + RATE_HORIZON
            at, need = next_arrival(t, need, rate_at, max(limit, t))
            await sleep_until(at)
            t = at
            if need == 0.0:
                await slots.acquire()
                now = time.time()
                if now - at > 1.0:
                    t = now                  # every slot was busy: no backlog
                key = stream.key
                plan, problem = self.make_plan(key, rng)
                started = time.monotonic()
                if plan is None:
                    slots.release()
                    self.stats.record(key, 0.0, True, now)
                    self.record_error(key, "-", problem)
                else:
                    task = self.spawn(self.call(key, plan, self.pool_for(pools, stream.connection), started),
                                      self.calls)
                    task.add_done_callback(lambda _t: slots.release())
                need = draw_need(rng, stream.arrivals)
            while pending and pending[0].at <= t:
                change = pending.pop(0)
                old_connection = stream.connection
                apply_change(stream, change)
                self.stats.touch({stream.key}, change.at)
                if stream.connection != old_connection and old_connection in pools:
                    await pools.pop(old_connection).close()

    # --- jobs ------------------------------------------------------------------
    def start_jobs(self):
        for task in self.job_tasks.values():
            task.cancel()
        self.job_tasks = {}
        for job in self.jobs:
            self.job_tasks[job.name] = self.spawn(self.run_job(job), self.tasks)

    async def run_job(self, job):
        last = time.time()
        while True:
            nxt = job.cron.next_after(last)
            if nxt is None:
                self.log.write("job", ("job", job.name), ("key", job.key), ("next", "never"))
                return
            await sleep_until(nxt)
            last = nxt
            self.fire_job(job, nxt)

    def fire_job(self, job, due):
        """Starts a run of `job` due at `due`, or skips it while the previous
        run still goes (never queued). Returns the run's task or None."""
        running = self.job_running.get(job.name)
        if running is not None and not running.done():
            self.stats.job_skip(job.key, job.name, "still-running")
            self.log.write("skip", ("job", job.name), ("key", job.key), ("at", instant(due)),
                           ("reason", "still-running"))
            return None
        task = self.spawn(self.job_run(job, due), self.calls)
        self.job_running[job.name] = task
        return task

    async def job_run(self, job, due):
        rng = derive(self.schedule.seed, self.hostname, f"job:{job.name}:{int(due)}", self.started)
        pool = self.pool_for(self.job_pools.setdefault(job.name, {}), job.connection)
        started = time.monotonic()
        plan, problem = self.make_plan(job.key, rng)
        if plan is None:
            self.stats.job_run(job.key, job.name)
            self.log.write("run", ("job", job.name), ("key", job.key), ("phase", "start"))
            self.stats.record(job.key, 0.0, True, time.time())
            self.record_error(job.key, "-", problem, job=job.name)
            self.log.write("run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "error"),
                           ("ms", "0.0"))
            return
        try:
            async with pool.session() as session:
                self.stats.job_run(job.key, job.name)
                self.stats.touch({job.key}, time.time())
                self.log.write("run", ("job", job.name), ("key", job.key), ("phase", "start"))
                error, rows = None, 0
                try:
                    rows = await run_plan(session, plan)
                except DriverError as exc:
                    error = exc
                latency = time.monotonic() - started
                self.stats.record(job.key, latency, error is not None, time.time())
                if error is None:
                    self.log.write("run", ("job", job.name), ("key", job.key), ("phase", "end"), ("status", "ok"),
                                   ("rows", rows), ("ms", f"{latency * 1000:.1f}"))
                else:
                    self.record_error(job.key, error.code, error.message, job=job.name)
                    self.log.write("run", ("job", job.name), ("key", job.key), ("phase", "end"),
                                   ("status", "error"), ("sqlstate", error.code), ("ms", f"{latency * 1000:.1f}"))
        except DriverError as exc:
            if not exc.connect:
                raise
            self.stats.job_skip(job.key, job.name, "connection-refused")
            self.record_error(job.key, exc.code, exc.message, job=job.name)
            self.log.write("skip", ("job", job.name), ("key", job.key), ("at", instant(due)),
                           ("reason", "connection-refused"))

    # --- summaries -------------------------------------------------------------
    def current_keys(self):
        return {s.key for s in self.schedule.streams}

    async def run_summaries(self):
        while True:
            boundary = minute_start(time.time()) + 60.0
            await sleep_until(boundary + SUMMARY_DELAY)
            self.stats.touch(self.current_keys(), boundary)
            for event, fields in self.stats.summary(boundary - 60.0):
                self.log.write(event, *fields)

    # --- life --------------------------------------------------------------------
    def read_marker(self):
        """T0 from the marker, None without one; raises ConfigError."""
        try:
            with open(self.cfg["marker"], encoding="utf-8") as f:
                text = f.read().strip()
        except FileNotFoundError:
            return None
        except OSError as exc:
            raise ConfigError(f"load-started marker: cannot be read ({exc.strerror})") from None
        return parse_instant(text, "load-started marker")

    async def start_running(self, t0):
        self.running = True
        self.started = time.time()
        self.stats.running = 1
        now = self.started
        for stream in self.schedule.streams:
            pending = apply_past_changes(stream, now)
            self.spawn(self.run_stream(stream, pending), self.tasks)
        self.stats.touch(self.current_keys(), now)
        self.start_jobs()
        self.spawn(self.run_summaries(), self.tasks)
        self.write_status("running")
        self.log.write("state", ("state", "running"), ("t0", instant(t0)))

    async def main(self):
        loop = asyncio.get_running_loop()
        self.stop_event = asyncio.Event()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self.stop_event.set)
        loop.add_signal_handler(signal.SIGHUP, self.reload)
        m = self.cfg["metrics"]
        server = await serve_metrics(self.stats, m["listen"], int(m["port"]), m["path"])
        t0 = self.read_marker()
        for key in self.schedule.keys():
            self.stats.declare(key)
        for job in self.jobs:
            self.stats.declare(job.key)
        self.write_loaded()
        if t0 is None:
            self.write_status("idle")
            self.log.write("state", ("state", "idle"))
        else:
            await self.start_running(t0)
        await self.stop_event.wait()
        self.log.write("state", ("state", "stopping"))
        server.close()
        for task in list(self.tasks) + list(self.calls):
            task.cancel()
        await asyncio.gather(*self.tasks, *self.calls, return_exceptions=True)
        await self.close_pools()
        return EXIT_OK


def run(cfg, data, hostname=None):
    """Runs the program; returns its exit code."""
    log = Log(cfg["log"])
    try:
        from .schedule import read_schedule
        schedule, passwords = read_schedule(data)
    except ConfigError as exc:
        print(f"gm-scheduler: the schedule on standard input is not valid: {exc}", file=sys.stderr, flush=True)
        log.write("fatal", ("message", "the schedule is not valid; the game master reads why in the container's log"))
        return EXIT_INPUT
    sched = Scheduler(cfg, schedule, passwords, log, hostname)
    try:
        sched.repo, sched.jobs = sched.load_files()
    except ConfigError as exc:
        log.write("fatal", ("message", f"not started: {exc}"))
        print(f"gm-scheduler: not started: {exc}", file=sys.stderr, flush=True)
        return EXIT_FILES
    try:
        sched.read_marker()
    except ConfigError as exc:
        log.write("fatal", ("message", str(exc)))
        return EXIT_INPUT
    try:
        return asyncio.run(sched.main())
    finally:
        log.close()
