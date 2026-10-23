"""The scheduler program against the throwaway PostgreSQL: streams, jobs
(skipped while running, or when the connection is refused), builders,
the program itself idle and running (standard input, status, log,
summaries, metrics, SIGHUP, a kill and a resume). Real time throughout:
the tests wait, they never move a clock."""

import asyncio
import calendar
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request

import yaml

from pgtest import DB, HOST, PASSWORD, PORT, ROLE, admin, needs_pg

QUERIES = """\
queries:
  orders.insert:
    sql: INSERT INTO orders (order_no, amount, at) VALUES (%(order_no)s, %(amount)s, %(at)s)
    params:
      order_no: {sequence: [1, 1]}
      amount: {decimal: [5, 500, 2]}
      at: {now: utc}
  orders.insert-v2:
    sql: INSERT INTO orders (order_no, amount, at, v2) VALUES (%(order_no)s, %(amount)s, %(at)s, true)
    params:
      order_no: {sequence: [1000000, 1]}
      amount: {int: [1, 9]}
      at: {now: utc}
  slow.hold:
    transaction: {isolation: read committed, hold: 2s}
    steps:
      - sql: SELECT count(*) FROM orders
  reports.batch:
    builder: builders/batch.py:build
    options: {base: 2}
  reports.broken:
    builder: builders/batch.py:broken
"""

BUILDER = """\
def build(intensity, options, rng=None):
    n = int(options["base"] * intensity)
    return [("INSERT INTO batches (n) VALUES (%(n)s)", {"n": i}) for i in range(n)], True

def broken(intensity, options):
    raise ValueError("no data for this month")
"""


def make_cfg(root, port=19120):
    paths = {
        "log": os.path.join(root, "log", "scheduler.log"),
        "status": os.path.join(root, "run", "status"),
        "loaded": os.path.join(root, "run", "loaded"),
        "marker": os.path.join(root, "state", "load-started"),
        "state": os.path.join(root, "lib"),
        "repository": os.path.join(root, "repository"),
        "jobs": os.path.join(root, "jobs", "jobs.yaml"),
        "schedule_seed": os.path.join(root, "seed", "schedule.yaml"),
        "metrics": {"listen": "127.0.0.1", "port": port, "path": "/metrics"},
    }
    for d in ("log", "run", "state", "lib", "repository/builders", "jobs", "seed"):
        os.makedirs(os.path.join(root, d), exist_ok=True)
    with open(os.path.join(root, "repository", "queries.yaml"), "w") as f:
        f.write(QUERIES)
    with open(os.path.join(root, "repository", "builders", "batch.py"), "w") as f:
        f.write(BUILDER)
    with open(paths["jobs"], "w") as f:
        f.write("jobs:\n  - name: close-day\n    key: slow.hold\n    connection: app\n    at: \"30 1 * * *\"\n")
    cfg_file = os.path.join(root, "scheduler.yaml")
    with open(cfg_file, "w") as f:
        yaml.safe_dump(paths, f)
    return paths, cfg_file


def schedule_doc(streams, timeline=(), port=PORT):
    return {
        "seed": 4815162342,
        "intensity": 1.0,
        "connections": {
            "app": {"driver": "sql/postgresql", "target": f"{HOST}:{port}/{DB}", "role": ROLE, "pool": {"size": 2}},
            "nowhere": {"driver": "sql/postgresql", "target": f"{HOST}:1/{DB}", "role": ROLE, "pool": {"size": 1}},
        },
        "streams": list(streams),
        "shapes": {"flat": {"utc": {d: [1.0] * 24 for d in ("mon", "tue", "wed", "thu", "fri", "sat", "sun")}}},
        "timeline": list(timeline),
    }


def stdin_for(doc, password=PASSWORD):
    return f"gm-scheduler-input 1\npassword {ROLE} {password}\nschedule\n" + yaml.safe_dump(doc)


def read_log(paths):
    try:
        with open(paths["log"]) as f:
            return f.read().splitlines()
    except FileNotFoundError:
        return []


@needs_pg
class ProgramBase(unittest.TestCase):
    def setUp(self):
        admin("DROP TABLE IF EXISTS orders, batches")
        admin("CREATE TABLE orders (order_no bigint PRIMARY KEY, amount numeric, at timestamptz, v2 bool)")
        admin("CREATE TABLE batches (n int)")
        admin("GRANT ALL ON orders, batches TO shop_app")
        self.root = tempfile.mkdtemp(prefix="gm-scheduler-test-")
        self.paths, self.cfg_file = make_cfg(self.root)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def scheduler(self, doc):
        from gm_scheduler.runner import Scheduler, load_config
        from gm_scheduler.schedule import read_schedule
        from gm_scheduler.textlog import Log
        schedule, passwords = read_schedule(stdin_for(doc))
        s = Scheduler(load_config(self.cfg_file), schedule, passwords, Log(self.paths["log"]), "unit-host")
        s.repo, s.jobs = s.load_files()
        s.started = time.time()
        self.addCleanup(s.log.close)
        self.addCleanup(lambda: asyncio.run(s.close_pools()))
        return s


class TestTasks(ProgramBase):
    def test_a_stream_calls_at_its_rate_with_its_key(self):
        doc = schedule_doc([{"key": "orders.insert", "connection": "app", "rate": "600/min", "arrivals": "even",
                             "shape": "flat", "concurrency": 2}])
        s = self.scheduler(doc)

        async def go():
            task = asyncio.ensure_future(s.run_stream(s.schedule.streams[0], []))
            await asyncio.sleep(3.05)
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
            await asyncio.gather(*s.calls, return_exceptions=True)
        asyncio.run(go())
        n = admin("SELECT count(*), count(DISTINCT order_no), min(order_no) FROM orders")[0]
        self.assertTrue(28 <= n[0] <= 31, n)        # 10 a second, even
        self.assertEqual(n[0], n[1])
        self.assertEqual(n[2], 1)
        self.assertEqual(s.stats.totals["orders.insert"].calls, n[0])

    def test_a_timeline_change_switches_the_key_at_its_moment(self):
        from gm_scheduler.schedule import TimelineChange
        doc = schedule_doc([{"key": "orders.insert", "connection": "app", "rate": "600/min", "arrivals": "even"}])
        s = self.scheduler(doc)
        stream = s.schedule.streams[0]
        change = TimelineChange(time.time() + 1.5, stream, {"key": "orders.insert-v2"})

        async def go():
            task = asyncio.ensure_future(s.run_stream(stream, [change]))
            await asyncio.sleep(3.0)
            task.cancel()
            await asyncio.gather(task, *s.calls, return_exceptions=True)
        asyncio.run(go())
        before, after = admin("SELECT count(*) FILTER (WHERE v2 IS NULL), count(*) FILTER (WHERE v2) FROM orders")[0]
        self.assertTrue(before >= 12 and after >= 12, (before, after))
        self.assertEqual(stream.key, "orders.insert-v2")

    def test_concurrency_and_pool_size_bound_the_sessions(self):
        doc = schedule_doc([{"key": "slow.hold", "connection": "app", "rate": "600/min", "arrivals": "even",
                             "concurrency": 3}])
        doc["connections"]["app"]["pool"] = {"size": 1}
        s = self.scheduler(doc)

        async def go():
            task = asyncio.ensure_future(s.run_stream(s.schedule.streams[0], []))
            await asyncio.sleep(1.5)
            n = await asyncio.to_thread(admin, "SELECT count(*) FROM pg_stat_activity "
                                               "WHERE application_name = 'unit-host'")
            task.cancel()
            for c in list(s.calls):
                c.cancel()
            await asyncio.gather(task, *s.calls, return_exceptions=True)
            return n[0][0]
        self.assertEqual(asyncio.run(go()), 1)

    def test_a_job_is_skipped_while_its_previous_run_goes(self):
        s = self.scheduler(schedule_doc([]))
        job = s.jobs[0]

        async def go():
            first = s.fire_job(job, time.time())
            await asyncio.sleep(0.5)
            second = s.fire_job(job, time.time())
            await first
            third = s.fire_job(job, time.time())
            await third
            return second
        self.assertIsNone(asyncio.run(go()))
        log = read_log(self.paths)
        self.assertEqual(sum(" skip job=close-day key=slow.hold " in l and l.endswith("reason=still-running")
                             for l in log), 1, log)
        starts = [l for l in log if " run job=close-day key=slow.hold phase=start" in l]
        ends = [l for l in log if " run job=close-day key=slow.hold phase=end status=ok rows=1 ms=" in l]
        self.assertEqual((len(starts), len(ends)), (2, 2), log)
        self.assertEqual(s.stats.job_skips[("slow.hold", "close-day", "still-running")], 1)

    def test_a_job_is_skipped_when_its_connection_is_refused(self):
        from gm_scheduler.jobs import parse_jobs
        s = self.scheduler(schedule_doc([]))
        job = parse_jobs({"jobs": [{"name": "far", "key": "slow.hold", "connection": "nowhere",
                                    "at": "0 0 * * *"}]})[0]
        asyncio.run(s.job_run(job, time.time()))
        log = read_log(self.paths)
        self.assertTrue(any(" error key=slow.hold job=far sqlstate=08" in l for l in log), log)
        self.assertTrue(any(" skip job=far key=slow.hold " in l and l.endswith("reason=connection-refused")
                            for l in log), log)
        self.assertFalse(any(" run job=far" in l for l in log))

    def test_builders_are_called_with_the_intensity_and_options(self):
        doc = schedule_doc([])
        doc["intensity"] = 3.0
        s = self.scheduler(doc)
        from gm_scheduler.jobs import parse_jobs
        job = parse_jobs({"jobs": [{"name": "b", "key": "reports.batch", "connection": "app", "at": "0 0 * * *"}]})[0]
        bad = parse_jobs({"jobs": [{"name": "c", "key": "reports.broken", "connection": "app",
                                    "at": "0 0 * * *"}]})[0]
        asyncio.run(s.job_run(job, time.time()))
        asyncio.run(s.job_run(bad, time.time()))
        self.assertEqual(admin("SELECT count(*) FROM batches")[0][0], 6)
        log = read_log(self.paths)
        self.assertTrue(any("run job=b key=reports.batch phase=end status=ok rows=6" in l for l in log), log)
        self.assertTrue(any('error key=reports.broken job=c sqlstate=- message="builder: ValueError: no data for '
                            'this month"' in l for l in log), log)


class TestProgram(ProgramBase):
    def start(self, doc, stdin=None):
        p = subprocess.Popen([sys.executable, "-I", "-m", "gm_scheduler", "run", "--config", self.cfg_file],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        p.stdin.write((stdin if stdin is not None else stdin_for(doc)).encode())
        p.stdin.close()
        p.stdin = None
        return p

    def wait_for(self, predicate, timeout=20.0):
        end = time.time() + timeout
        while time.time() < end:
            if predicate():
                return True
            time.sleep(0.2)
        return False

    def status(self):
        try:
            with open(self.paths["status"]) as f:
                return f.read().split()
        except FileNotFoundError:
            return []

    def metrics(self):
        with urllib.request.urlopen("http://127.0.0.1:19120/metrics", timeout=5) as r:
            return r.read().decode()

    def stop(self, p):
        if p.poll() is None:
            p.send_signal(signal.SIGTERM)
        return self.finish(p)

    def finish(self, p):
        """Waits for the program to exit on its own; (exit code, its output)."""
        out = p.communicate(timeout=20)[0].decode()
        return p.returncode, out

    def write_marker(self):
        with open(self.paths["marker"], "w") as f:
            f.write(time.strftime("%Y-%m-%dT%H:%M:%SZ\n", time.gmtime()))

    def test_idle_without_the_marker_and_sighup_reloads(self):
        doc = schedule_doc([{"key": "orders.insert", "connection": "app", "rate": "600/min", "arrivals": "even"}])
        p = self.start(doc)
        try:
            self.assertTrue(self.wait_for(lambda: self.status()[:1] == ["idle"]), self.status())
            self.assertIn("scheduler_running 0\n", self.metrics())
            time.sleep(1.5)
            self.assertEqual(admin("SELECT count(*) FROM orders")[0][0], 0)
            with open(self.paths["jobs"], "a") as f:
                f.write("  - name: extra\n    key: orders.insert\n    connection: app\n    at: \"*/5 * * * *\"\n")
            p.send_signal(signal.SIGHUP)
            self.assertTrue(self.wait_for(lambda: any(" reload status=ok keys=5 jobs=2" in l
                                                      for l in read_log(self.paths))))
            with open(self.paths["loaded"]) as f:
                loaded = f.read()
            self.assertIn("generation=2\n", loaded)
            self.assertRegex(loaded, r"job extra next=\d{4}-\d\d-\d\dT\d\d:\d[05]:00Z")
            with open(self.paths["jobs"], "a") as f:
                f.write("  - name: bad\n    key: no.such.key\n    connection: app\n    at: \"0 1 * * *\"\n")
            p.send_signal(signal.SIGHUP)
            self.assertTrue(self.wait_for(lambda: any(
                ' reload status=refused message="jobs.yaml: job bad: key no.such.key is not in queries.yaml"' in l
                for l in read_log(self.paths))), read_log(self.paths))
        finally:
            code, out = self.stop(p)
        self.assertEqual(code, 0, out)
        log = read_log(self.paths)
        self.assertTrue(log[0].endswith(" state state=idle"), log)
        self.assertTrue(log[-1].endswith(" state state=stopping"), log)

    def test_running_summaries_metrics_and_a_resume_without_replay(self):
        now = time.time()
        doc = schedule_doc(
            [{"key": "orders.insert", "connection": "app", "rate": "240/min", "arrivals": "poisson",
              "shape": "flat", "concurrency": 2},
             {"key": "slow.hold", "connection": "app", "rate": "2/h", "arrivals": "even"}],
            timeline=[{"at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 60)), "stream": "orders.insert",
                       "set": {"key": "orders.insert-v2"}}])
        self.write_marker()
        p = self.start(doc)
        try:
            self.assertTrue(self.wait_for(lambda: self.status()[:1] == ["running"]), self.status())
            # the next minute boundary, then its summary within ten seconds
            boundary = (int(time.time()) // 60 + 1) * 60
            minute = time.strftime("%Y-%m-%dT%H:%MZ", time.gmtime(boundary - 60))
            self.assertTrue(self.wait_for(lambda: any(f" summary minute={minute} " in l for l in read_log(self.paths)),
                                          timeout=boundary - time.time() + 10), read_log(self.paths))
            log = read_log(self.paths)
            summary = [l for l in log if f" summary minute={minute} " in l][0]
            self.assertLessEqual(calendar.timegm(time.strptime(summary[:20], "%Y-%m-%dT%H:%M:%SZ")) - boundary, 10)
            keys = [l for l in log if f" key minute={minute} " in l]
            self.assertEqual([l.split(" key=")[1].split()[0] for l in keys], ["orders.insert-v2", "slow.hold"])
            self.assertRegex(keys[0], r"calls=[1-9][0-9]* errors=0 p50_ms=[0-9.]+ p95_ms=[0-9.]+ p99_ms=[0-9.]+$")
            self.assertRegex(keys[1], r"key=slow.hold calls=0 errors=0 p50_ms=- p95_ms=- p99_ms=-$")
            m = self.metrics()
            self.assertIn("scheduler_running 1\n", m)
            self.assertRegex(m, r'scheduler_calls_total\{key="orders.insert-v2"\} [1-9]')
            self.assertIn('scheduler_calls_total{key="orders.insert"} 0\n', m)
            self.assertEqual(admin("SELECT count(*) FROM orders WHERE v2 IS NULL")[0][0], 0)
            self.assertFalse(any(" rate=" in l or "flat" in l for l in log))
            # killed: comes back running, the sequence goes on without reusing a value
            p.kill()
            p.communicate()
            before = admin("SELECT count(*), max(order_no) FROM orders")[0]
            p = self.start(doc)
            self.assertTrue(self.wait_for(lambda: sum(" state state=running" in l for l in read_log(self.paths)) == 2))
            self.assertTrue(self.wait_for(lambda: admin("SELECT count(*) FROM orders")[0][0] > before[0] + 5))
            after = admin("SELECT min(order_no) FROM orders WHERE order_no > %s", (before[1],))[0][0]
            self.assertEqual(after, 1000000 + 1000)      # the next block of the sequence
            self.assertFalse(any(" run job=" in l for l in read_log(self.paths)))
        finally:
            code, out = self.stop(p)
        self.assertEqual(code, 0, out)
        self.assertNotIn("Traceback", out)

    def test_refusals_at_start(self):
        with open(os.path.join(self.paths["repository"], "queries.yaml"), "a") as f:
            f.write("  broken: {sql: ''}\n")
        p = self.start(schedule_doc([]))
        code, out = self.finish(p)
        self.assertEqual(code, 3, out)
        self.assertTrue(read_log(self.paths)[-1].endswith(' fatal message="not started: queries.yaml: broken.sql: '
                                                          'sql is a non-empty string"'), read_log(self.paths))
        with open(os.path.join(self.paths["repository"], "queries.yaml"), "w") as f:
            f.write(QUERIES)
        doc = schedule_doc([{"key": "orders.insert", "connection": "app", "rate": "secret-7/min", "arrivals": "even"}])
        p = self.start(doc)
        code, out = self.finish(p)
        self.assertEqual(code, 2, out)
        self.assertIn("streams[0].rate", out)
        self.assertNotIn("secret", "\n".join(read_log(self.paths)))
        p = self.start(None, stdin="seed: 1\n")
        self.assertEqual(self.finish(p)[0], 2)


@needs_pg
class TestChecks(ProgramBase):
    def check(self, command):
        return subprocess.run([sys.executable, "-I", "-m", "gm_scheduler", command, "--config", self.cfg_file],
                              capture_output=True, text=True)

    def test_check_and_check_keys(self):
        with open(self.paths["schedule_seed"], "w") as f:
            yaml.safe_dump(schedule_doc([{"key": "orders.insert", "connection": "app", "rate": "1/min",
                                          "arrivals": "even"}]), f)
        self.assertEqual(self.check("check").returncode, 0)
        self.assertEqual(self.check("check-keys").returncode, 0)
        q = os.path.join(self.paths["repository"], "queries.yaml")
        with open(q, "w") as f:
            f.write(QUERIES.replace("orders.insert:", "orders.renamed:"))
        r = self.check("check-keys")
        self.assertEqual((r.returncode, r.stdout),
                         (1, "queries.yaml: key orders.insert is named by the schedule but is missing\n"))
        with open(self.paths["jobs"], "w") as f:
            f.write("jobs:\n  - {name: j, key: slow.hold, connection: elsewhere, at: '0 1 * * *'}\n")
        r = self.check("check-keys")
        self.assertIn("jobs.yaml: job j: connection elsewhere is not one of the schedule's\n", r.stdout)
        self.assertEqual(self.check("check").returncode, 0)
        with open(self.paths["jobs"], "w") as f:
            f.write("jobs:\n  - {name: j, key: nope, connection: app, at: '0 1 * * *'}\n")
        r = self.check("check")
        self.assertEqual((r.returncode, r.stdout), (1, "jobs.yaml: job j: key nope is not in queries.yaml\n"))

    def test_pending(self):
        from gm_scheduler.runner import write_atomic
        s = self.scheduler(schedule_doc([]))
        s.write_loaded()
        self.assertEqual(self.check("pending").returncode, 0)
        with open(self.paths["jobs"], "a") as f:
            f.write("# moved\n")
        r = self.check("pending")
        self.assertEqual(r.returncode, 1)
        self.assertIn("jobs.yaml changed since the program loaded its files", r.stdout)


@unittest.skipUnless(os.geteuid() == 0, "restore needs root")
class TestRestore(unittest.TestCase):
    def test_owner_and_modes_by_policy_never_through_a_link(self):
        from gm_scheduler import policy as wp
        root = tempfile.mkdtemp()
        try:
            repo, jobs = os.path.join(root, "repository"), os.path.join(root, "jobs")
            os.makedirs(os.path.join(repo, "builders"))
            os.makedirs(jobs)
            outside = os.path.join(root, "outside")
            for path in (os.path.join(repo, "queries.yaml"), os.path.join(repo, "builders", "b.py"),
                         os.path.join(jobs, "jobs.yaml"), outside):
                with open(path, "w") as f:
                    f.write("x\n")
                os.chmod(path, 0o600)
            os.symlink(outside, os.path.join(repo, "builders", "link.py"))
            uid = gid = 65534

            def modes():
                return [oct(os.stat(p).st_mode & 0o7777) for p in
                        (repo, os.path.join(repo, "builders"), jobs, os.path.join(repo, "queries.yaml"),
                         os.path.join(repo, "builders", "b.py"), os.path.join(jobs, "jobs.yaml"))]
            notes = wp.restore("report-only", [], repo, jobs, uid, gid)
            self.assertEqual(modes(), ["0o2755", "0o2755", "0o2755", "0o644", "0o644", "0o644"])
            self.assertEqual(os.stat(os.path.join(jobs, "jobs.yaml")).st_uid, uid)
            self.assertEqual(oct(os.stat(outside).st_mode & 0o777), "0o600")
            self.assertEqual(os.stat(outside).st_uid, 0)
            self.assertTrue(any("link.py: a symbolic link" in n for n in notes), notes)
            # the override names directories as the brick's writable_paths do
            wp.restore("report-only", [jobs], repo, jobs, uid, gid)
            self.assertEqual(modes(), ["0o2755", "0o2755", "0o2775", "0o644", "0o644", "0o664"])
            wp.restore("fixable", [], repo, jobs, uid, gid)
            self.assertEqual(modes(), ["0o2775", "0o2775", "0o2775", "0o664", "0o664", "0o664"])
            with open(os.path.join(jobs, "jobs.yaml")) as f:
                self.assertEqual(f.read(), "x\n")
        finally:
            shutil.rmtree(root)

    def test_policy_checks(self):
        from gm_scheduler import policy as wp
        self.assertIsNone(wp.check_policy("report-only", ["/srv/scheduler/jobs"]))
        self.assertIn("not one of", wp.check_policy("read-only", []))
        self.assertIn("writable_paths", wp.check_policy("report-only", ["/srv/scheduler/jobs/jobs.yaml"]))
        self.assertTrue(wp.is_fixable("/srv/scheduler/jobs/jobs.yaml", "report-only", ["/srv/scheduler/jobs"]))
        self.assertFalse(wp.is_fixable("/srv/scheduler/jobsx/a", "report-only", ["/srv/scheduler/jobs"]))
        self.assertFalse(wp.any_fixable("no-access", []))
        self.assertTrue(wp.any_fixable("report-only", ["/srv/scheduler/repository"]))


if __name__ == "__main__":
    unittest.main()
