"""The aging (tools/gm/aging.py): start-load, inject --at, the host timers,
the earliest hand-over and the early check's time (v0.3 capture W2).

A fake engine (ScriptedDocker) and a fake user manager (FakeSystemd);
never a fake clock in a running game: the pure functions take their
instants as arguments, and only the late run's wait loop gets a stand-in
sleep, as deploy's health wait does."""

import datetime
import fnmatch
import os
import subprocess
import unittest
from unittest import mock

import yaml

from tools.gm import aging, build_parser, inject, localimpl, model, teardown
from tools.gm.model import GmError
from tools.tests import ScenarioCopyTest, run_gmctl
from tools.tests.test_inject import FRAGMENTS, ScriptedDocker, V03DeployedGame, script_name

UTC = datetime.timezone.utc


def at(text):
    return aging.parse_instant(text)


class FakeSystemd(aging.Systemd):
    """The user's systemd manager, in memory: unit files in a temporary
    unit directory, the units loaded at each daemon-reload, the timers
    enabled and active. `up=False`: a manager that does not answer."""

    def __init__(self, root, up=True):
        super().__init__(unit_dir=root / "systemd-user", stamp_dir=root / "systemd-timers")
        self.up = up
        self.calls = []
        self.loaded, self.active, self.enabled, self.failed = set(), set(), set(), set()

    def reachable(self):
        return self.up

    def files(self):
        return {p.name for p in self.unit_dir.glob("*")} if self.unit_dir.is_dir() else set()

    def called(self, *prefix):
        return [c for c in self.calls if tuple(c[:len(prefix)]) == prefix]

    def run(self, *args, check=True):
        args = [str(a) for a in args]
        self.calls.append(args)
        if not self.up:
            raise aging.SystemdUnreachable("Failed to connect to user scope bus")
        cmd, units = args[0], [a for a in args[1:] if not a.startswith("-")]
        out, rc = "", 0
        if cmd == "daemon-reload":
            self.loaded = self.files() | self.active
        elif cmd == "enable":
            self.enabled |= set(units)
            if "--now" in args:
                self.active |= set(units)
        elif cmd == "disable":
            self.enabled -= set(units)
            if "--now" in args:
                self.active -= set(units)
        elif cmd == "restart":
            self.active |= set(units)
        elif cmd == "stop":
            self.active -= set(units)
        elif cmd == "reset-failed":
            self.failed = {u for u in self.failed if not fnmatch.fnmatch(u, units[0])}
        elif cmd == "list-units":
            out = "".join(f"{u} loaded inactive dead x\n" for u in sorted(
                self.loaded | self.active | self.failed) if fnmatch.fnmatch(u, units[0]))
        elif cmd == "list-unit-files":
            names = sorted(u for u in self.files() if fnmatch.fnmatch(u, units[0]))
            out, rc = "".join(f"{u} enabled enabled\n" for u in names), 0 if names else 1
        return subprocess.CompletedProcess(args, rc, out, "")


# --- Pure functions ------------------------------------------------------------

class TestCron(unittest.TestCase):

    def test_daily_weekly_and_lists(self):
        t0 = at("2026-10-26T20:00:07Z")             # a Monday
        self.assertEqual(aging.cron_first_due("30 1 * * *", t0), at("2026-10-27T01:30:00Z"))
        self.assertEqual(aging.cron_first_due("0 6 * * 1", t0), at("2026-11-02T06:00:00Z"))
        self.assertEqual(aging.cron_first_due("*/15 8,12,18 * * *", t0),
                         at("2026-10-27T08:00:00Z"))
        self.assertEqual(aging.cron_first_due("5 20 * * *", t0), at("2026-10-26T20:05:00Z"))
        self.assertEqual(aging.cron_first_due("0 20 * * *", t0), at("2026-10-27T20:00:00Z"))
        self.assertEqual(aging.cron_first_due("1 20 * * *", t0), at("2026-10-26T20:01:00Z"))

    def test_in_a_fixed_zone(self):
        # 01:30 in UTC+2 (Etc/GMT-2) is 23:30 UTC the day before
        t0 = at("2026-10-26T20:00:07Z")
        self.assertEqual(aging.cron_first_due("30 1 * * *", t0, "Etc/GMT-2"),
                         at("2026-10-26T23:30:00Z"))
        self.assertEqual(aging.cron_first_due("30 1 * * *", t0, "Etc/GMT+3"),
                         at("2026-10-27T04:30:00Z"))


TIMELINE = {"aging_minimum": "16h", "planned_handover": "2026-10-28T16:00:00Z",
            "instances": {"f1": {"plant_at": "T0", "planned_at": None, "aging_minimum": "2h"},
                          "f2": {"plant_at": "handover-6h", "planned_at": "2026-10-28T10:00:00Z",
                                 "aging_minimum": "2h"}}}
T0 = "2026-10-27T08:00:00Z"
PLANTED = {"f1": {"plant_at": "T0", "planted_at": "2026-10-27T07:58:00Z"},
           "f2": {"plant_at": "handover-6h", "planted_at": "2026-10-27T12:00:00Z"}}


class TestEarliestHandover(unittest.TestCase):
    """W2 item 7, spec D175: one function."""

    def test_no_outage(self):
        earliest, waiting = aging.earliest_handover(TIMELINE, T0, PLANTED, 0)
        self.assertEqual(earliest, at("2026-10-28T00:00:00Z"))        # T0 + 16h
        self.assertEqual(waiting, [])

    def test_twenty_minutes_lost_do_not_move_it(self):
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, PLANTED, 20)[0],
                         at("2026-10-28T00:00:00Z"))
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, PLANTED, 30)[0],
                         at("2026-10-28T00:00:00Z"))

    def test_fifty_minutes_lost_move_it_by_the_excess(self):
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, PLANTED, 50)[0],
                         at("2026-10-28T00:20:00Z"))

    def test_excess_moves_the_whole_maximum(self):
        # f2 planted late: its own minimum is the maximum; the excess moves it
        late = dict(PLANTED, f2={"plant_at": "handover-6h", "planted_at": "2026-10-28T00:00:00Z"})
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, late, 0)[0],
                         at("2026-10-28T02:00:00Z"))
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, late, 45)[0],
                         at("2026-10-28T02:15:00Z"))

    def test_not_yet_planted_counts_its_due_and_waits(self):
        waiting = dict(PLANTED, f2={"plant_at": "handover-6h", "planted_at": None,
                                    "timer": {"due": "2026-10-28T03:00:00Z"}})
        earliest, names = aging.earliest_handover(TIMELINE, T0, waiting, 0)
        self.assertEqual((earliest, names), (at("2026-10-28T05:00:00Z"), ["f2"]))
        no_timer = dict(PLANTED, f2={"plant_at": "handover-6h", "planted_at": None,
                                     "timer": None})
        self.assertEqual(aging.earliest_handover(TIMELINE, T0, no_timer, 0),
                         (at("2026-10-28T12:00:00Z"), ["f2"]))        # planned_at + 2h

    def test_a_t0_instance_counts_from_t0(self):
        own = {**TIMELINE, "instances": {"f1": {"plant_at": "T0", "planned_at": None,
                                                "aging_minimum": "20h"}}}
        self.assertEqual(aging.earliest_handover(own, T0, PLANTED, 0)[0],
                         at("2026-10-28T04:00:00Z"))

    def test_the_override_caps_both_minima(self):
        own = {**TIMELINE, "instances": {
            "f2": {"plant_at": "handover-6h", "planned_at": None, "aging_minimum": "3h"}}}
        planted = {"f2": {"planted_at": "2026-10-27T08:30:00Z"}}
        # no override: max(T0 + 16h, 08:30 + 3h)
        self.assertEqual(aging.earliest_handover(own, T0, planted, 0)[0],
                         at("2026-10-28T00:00:00Z"))
        # 1h: T0 + 1h, and f2's 3h capped at 1h, 08:30 + 1h
        self.assertEqual(aging.earliest_handover(own, T0, planted, 0, override=3600)[0],
                         at("2026-10-27T09:30:00Z"))


class TestEarlyCheckDue(V03DeployedGame):
    """W2 item 8: when start-load schedules the early check."""

    def setUp(self):
        super().setUp()
        self.scen = model.load_scenario(self.scenario)

    def state(self, t0, override=None):
        st = {"load": {"t0": t0}, "plantings": {}}
        if override:
            st[aging.OVERRIDE_KEY] = {"aging_minimum": override}
        return st

    def due(self, impl, st):
        return aging.early_check_due(self.scen, "laptop", impl, st)

    def test_halfway_or_after_every_job_ran_once(self):
        impl = localimpl.read_implementation(self.ldir)
        planned = at(impl["timeline"]["planned_handover"])
        t0 = planned - datetime.timedelta(hours=20)
        t0s = aging.iso(t0)
        jobs = aging.rendered_jobs(self.scen, "laptop")
        self.assertEqual([j["name"] for _, j in jobs], ["close-day", "weekly-report", "sweep"])
        earliest, _ = aging.game_earliest(impl, self.state(t0s))
        expect = t0 + datetime.timedelta(hours=8)
        for _, job in jobs:
            first = aging.job_first_due(job, t0)
            if first is not None and first < earliest:
                expect = max(expect, first + datetime.timedelta(minutes=10))
        expect = max(min(expect, earliest - datetime.timedelta(hours=1)),
                     t0 + datetime.timedelta(minutes=5))
        self.assertEqual(self.due(impl, self.state(t0s)), expect)
        self.assertLessEqual(expect, earliest - datetime.timedelta(hours=1))
        self.assertGreaterEqual(expect, t0 + datetime.timedelta(hours=8))

    def test_a_job_due_late_is_bounded_an_hour_before_the_earliest(self):
        impl = localimpl.read_implementation(self.ldir)
        t0 = at("2026-10-26T00:00:00Z")
        path = self.ldir / "rendered" / "producer" / "jobs.yaml"
        path.write_text(yaml.safe_dump({"jobs": [
            {"name": "late", "key": "k", "connection": "app", "at": "50 15 * * *"}]}))
        impl["timeline"]["instances"] = {}
        st = self.state(aging.iso(t0))
        # earliest T0 + 16h = 16:00; the job at 15:50 (+10 min = 16:00) is capped at 15:00
        self.assertEqual(self.due(impl, st), at("2026-10-26T15:00:00Z"))

    def test_the_override_floor(self):
        impl = localimpl.read_implementation(self.ldir)
        impl["timeline"]["instances"] = {}
        t0 = at("2026-10-26T00:00:00Z")
        st = self.state(aging.iso(t0), override="1h")
        # T0 + 30 min, capped at earliest - 1 h = T0, floored at T0 + 5 min
        self.assertEqual(self.due(impl, st), at("2026-10-26T00:05:00Z"))


# --- start-load ------------------------------------------------------------------

def started_reply(run):
    """A scheduler's start script that reads running at once."""
    return (0, f"running {localimpl.now_iso()}\n", "")


class InjectedV03(V03DeployedGame):
    """fixture-v03-refusals deployed, its data loaded, its T0 faults
    planted; a fake user manager."""

    def setUp(self):
        super().setUp()
        self.load_data()
        inject.inject(self.scenario, "laptop", docker=self.fake, out=self.printed.append)
        self.systemd = FakeSystemd(self.tmp)
        self.fake.runs.clear()

    def reply(self, run):
        if aging.MARKER in run["stdin"]:
            return self.replies.get("start", started_reply)(run)
        return super().reply(run)

    def st(self):
        return localimpl.read_state(self.ldir)

    def start(self, **kwargs):
        return aging.start_load(self.scenario, "laptop", docker=self.fake, systemd=self.systemd,
                                out=self.printed.append, **kwargs)

    def inject_at(self, when, instance="f2", **kwargs):
        return aging.inject_at(self.scenario, "laptop", when, instance, docker=self.fake,
                               systemd=self.systemd, out=self.printed.append, **kwargs)

    def unit_file(self, action, suffix):
        return self.systemd.unit_dir / f"dbagm-{self.gid}_{action}.{suffix}"


class TestInjectAtT0(InjectedV03):

    def test_inject_planted_only_the_t0_instances_and_recorded_every_planting(self):
        st = self.st()
        self.assertEqual(st["stage"], "injected")
        self.assertNotIn("f2 inject/10-drop-index.sh (db, as root): ok", self.printed)
        p = st["plantings"]
        self.assertEqual(list(p), ["f1", "f2", "f3"])
        self.assertEqual(p["f1"]["plant_at"], "T0")
        self.assertEqual(p["f1"]["by"], "inject")
        self.assertEqual(p["f1"]["planted_at"], st["history"][-1]["at"])
        self.assertEqual(p["f2"], {"plant_at": "handover-6h",
                                   "planned_at": self.impl["timeline"]["instances"]["f2"]
                                   ["planned_at"], "timer": None, "attempts": [],
                                   "planted_at": None})

    def test_inject_refused_at_load_started(self):
        self.start()
        self.fake.runs.clear()
        with self.assertRaisesRegex(GmError, "--at now --instance"):
            inject.inject(self.scenario, "laptop", docker=self.fake)
        self.assertEqual(self.fake.runs, [])


class TestStartLoad(InjectedV03):

    def test_records_t0_and_schedules_the_early_check(self):
        result = self.start()
        self.assertTrue(result.ok, result.text())
        runs = [r for r in self.fake.runs if aging.MARKER in r["stdin"]]
        self.assertEqual(len(runs), 1)
        run = runs[0]
        self.assertEqual((run["container"], run["user"]), (f"{self.gid}_producer.1.ctr", "root"))
        self.assertEqual(run["env"], {"GM_T0": result.began})
        for fragment in ("mv -f", "chown root:scheduler", "chmod 0440",
                         "/command/s6-svc -r /run/service/scheduler", "/run/scheduler/status"):
            self.assertIn(fragment, run["stdin"])
        st = self.st()
        self.assertEqual(st["stage"], "load-started")
        self.assertEqual(st["load"]["t0"], result.began)
        self.assertEqual(st["history"][-1]["stage"], "load-started")
        self.assertGreaterEqual(st["history"][-1]["at"], st["load"]["t0"])
        attempt = st["load"]["attempts"][-1]
        self.assertEqual(attempt["began"], result.began)
        self.assertEqual(attempt["nodes"]["producer"]["outcome"], "ok")
        self.assertIsNone(st["failure"])
        timer = st["early_check"]["timer"]
        self.assertEqual(timer["unit"], f"dbagm-{self.gid}_early-check")
        self.assertIsNone(st["early_check"]["result"])
        self.assertEqual(aging.parse_instant(timer["due"]), aging.early_check_due(
            model.load_scenario(self.scenario), "laptop", self.impl, st))
        self.assertIn(["enable", "--now", f"dbagm-{self.gid}_early-check.timer"],
                      self.systemd.calls)
        service = self.unit_file("early-check", "service").read_text()
        self.assertIn(f"Environment=DBAGM_GAME={self.gid}", service)
        self.assertIn(f"check {self.scenario.resolve()} --playground laptop --early-check",
                      service)
        text = result.text()
        self.assertIn(f"Load started: T0 {result.began}. Stage load-started.", text)
        planned = self.impl["timeline"]["instances"]["f2"]["planned_at"]
        self.assertIn(f"--playground laptop --at {planned} --instance f2", text)

    def test_a_scheduler_that_does_not_start_is_recorded_without_teardown(self):
        self.replies["start"] = lambda run: (1, "status did not read running within 60 s "
                                                "(last: idle 2026-10-26T19:00:00Z)\n", "")
        result = self.start()
        self.assertFalse(result.ok)
        st = self.st()
        self.assertEqual(st["stage"], "injected")
        self.assertIsNone(st["load"]["t0"])
        self.assertIsNone(st["failure"])
        self.assertEqual(st["load"]["attempts"][-1]["nodes"]["producer"],
                         {"outcome": "failed", "reason": "status did not read running within "
                                                         "60 s (last: idle 2026-10-26T19:00:00Z)"})
        self.assertTrue(teardown.leftovers(self.fake, self.gid))      # nothing torn down
        self.assertNotIn("early_check", st)
        self.assertEqual(self.systemd.files(), set())
        self.assertIn("T0 not recorded", result.text())
        # run again once fixed: a new attempt, its own T0
        self.replies.pop("start")
        again = self.start()
        self.assertTrue(again.ok)
        self.assertEqual(len(self.st()["load"]["attempts"]), 2)
        self.assertEqual(self.st()["load"]["t0"], again.began)

    def test_refusals(self):
        self.start()
        with self.assertRaisesRegex(GmError, "the load already started, T0"):
            self.start()
        localimpl.set_stage(self.ldir, "handed-over")
        with self.assertRaisesRegex(GmError, "refused once handed over"):
            self.start()
        localimpl.set_stage(self.ldir, "data-loaded")
        with self.assertRaisesRegex(GmError, "needs stage injected"):
            self.start()

    def test_override_recorded_and_capping(self):
        result = self.start(test_aging_minimum="1h")
        self.assertTrue(result.ok)
        st = self.st()
        self.assertEqual(st[aging.OVERRIDE_KEY]["aging_minimum"], "1h")
        earliest, waiting = aging.game_earliest(self.impl, st)
        planned_f2 = aging.parse_instant(self.impl["timeline"]["instances"]["f2"]["planned_at"])
        # f2 (2h own minimum) capped at 1h, counted from its planned planting
        self.assertEqual(earliest, planned_f2 + datetime.timedelta(hours=1))
        self.assertEqual(waiting, ["f2"])

    def test_override_must_be_shorter(self):
        for value in ("16h", "2d", "30s", "soon"):
            with self.assertRaises(GmError):
                self.start(test_aging_minimum=value)
        self.assertEqual(self.st()["stage"], "injected")

    def test_override_is_not_in_the_help(self):
        for argv in (["--help"], ["start-load", "--help"]):
            proc = run_gmctl(*argv)
            self.assertNotIn("test", proc.stdout.lower().replace("the test", ""))
            self.assertNotIn("aging-minimum", proc.stdout)


class TestStaticGame(ScenarioCopyTest):

    def test_start_load_refused_without_a_scheduler_node(self):
        from tools.gm import fit, render
        from tools.tests import SUFFICIENT
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        render.render(self.scenario, "laptop")
        gid = localimpl.read_state(self.scenario / "local" / "laptop")["game_id"]
        proc = run_gmctl("start-load", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(proc.stderr.strip(), f"gmctl start-load: game {gid} has no scheduler "
                                              "node, so it has no aging and no load to start "
                                              "(D157)")


class TestNoLoadControl(unittest.TestCase):
    """Master spec 9: no verb pauses, speeds up or triggers the load."""

    def test_verbs(self):
        sub = next(a for a in build_parser()._actions if a.dest == "command")
        self.assertEqual(sorted(sub.choices), sorted([
            "fit", "render", "deploy", "load-data", "inject", "start-load", "validate", "check",
            "status", "exec", "logs", "teardown"]))
        for verb in sub.choices:
            for word in ("pause", "resume", "speed", "trigger", "stop-load", "faster"):
                self.assertNotIn(word, verb)


# --- inject --at -------------------------------------------------------------------

class TestInjectAt(InjectedV03):

    def setUp(self):
        super().setUp()
        self.start()
        self.fake.runs.clear()
        self.planned = aging.parse_instant(self.impl["timeline"]["planned_handover"])

    def test_refused_before_the_load(self):
        localimpl.set_stage(self.ldir, "injected")
        with self.assertRaisesRegex(GmError, "needs stage load-started"):
            self.inject_at("now")

    def test_refused_for_seed_file_unknown_and_t0_instances(self):
        with self.assertRaisesRegex(GmError, "planted at render"):
            self.inject_at("now", "f1")
        with self.assertRaisesRegex(GmError, "not a fault instance"):
            self.inject_at("now", "f9")
        impl = localimpl.read_implementation(self.ldir)
        impl["timeline"]["instances"]["f2"]["plant_at"] = "T0"
        localimpl.write_implementation(self.ldir, impl)
        with self.assertRaisesRegex(GmError, r"master spec 8\.5"):
            self.inject_at("now")
        self.assertEqual(self.fake.runs, [])

    def test_refused_instants(self):
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, "--at now"):
            self.inject_at("2020-01-01T00:00Z")
        with self.assertRaisesRegex(GmError, "at or after the planned hand-over"):
            self.inject_at(aging.iso(self.planned))
        with self.assertRaisesRegex(GmError, "not a UTC instant"):
            self.inject_at("tomorrow")
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)

    def test_schedule_writes_and_enables_the_timer(self):
        when = self.planned - datetime.timedelta(hours=7)
        result = self.inject_at(aging.iso_minute(when))
        self.assertTrue(result.ok)
        unit = f"dbagm-{self.gid}_plant-f2"
        timer = self.unit_file("plant-f2", "timer").read_text()
        self.assertIn(f"OnCalendar={when.strftime('%Y-%m-%d %H:%M:%S')} UTC", timer)
        self.assertIn("Persistent=true", timer)
        self.assertIn("WantedBy=timers.target", timer)
        service = self.unit_file("plant-f2", "service").read_text()
        self.assertIn("Type=oneshot", service)
        self.assertIn(f"inject {self.scenario.resolve()} --playground laptop --at now "
                      "--instance f2", service)
        self.assertIn(["enable", "--now", f"{unit}.timer"], self.systemd.calls)
        self.assertIn(f"{unit}.timer", self.systemd.active)
        p = self.st()["plantings"]["f2"]
        self.assertEqual(p["timer"]["unit"], unit)
        self.assertEqual(p["timer"]["due"], aging.iso(when))
        self.assertIsNone(p["planted_at"])
        self.assertEqual(self.fake.runs, [])
        # replacing it rewrites the units and restarts the timer
        later = when + datetime.timedelta(minutes=30)
        self.inject_at(aging.iso(later))
        self.assertIn(["restart", f"{unit}.timer"], self.systemd.calls)
        self.assertEqual(self.st()["plantings"]["f2"]["timer"]["due"], aging.iso(later))

    def test_now_plants_and_stops_a_live_timer(self):
        self.inject_at(aging.iso(self.planned - datetime.timedelta(hours=7)))
        result = self.inject_at("now")
        self.assertTrue(result.ok, result.text())
        self.assertEqual([script_name(r) for r in self.fake.runs], ["10-drop-index", "20-analyze"])
        p = self.st()["plantings"]["f2"]
        self.assertIsNone(p["timer"])
        self.assertEqual(p["attempts"][-1]["by"], "gmctl")
        self.assertEqual(p["attempts"][-1]["outcome"], "ok")
        self.assertEqual(p["planted_at"], p["attempts"][-1]["at"])
        self.assertFalse(self.unit_file("plant-f2", "timer").exists())
        self.assertIn(["disable", "--now", f"dbagm-{self.gid}_plant-f2.timer"],
                      self.systemd.calls)
        with self.assertRaisesRegex(GmError, "already planted"):
            self.inject_at(aging.iso(self.planned - datetime.timedelta(hours=5)))

    def test_a_failing_planting_is_recorded_without_teardown(self):
        self.replies[FRAGMENTS["10-drop-index"]] = (3, "", "psql: error: connection refused\n")
        result = self.inject_at("now")
        self.assertFalse(result.ok)
        self.assertIn("FAILED", result.text())
        st = self.st()
        self.assertEqual(st["stage"], "load-started")
        self.assertIsNone(st["failure"])
        attempt = st["plantings"]["f2"]["attempts"][-1]
        self.assertEqual(attempt["outcome"], "failed")
        self.assertIn("exit 3: psql: error: connection refused", attempt["reason"])
        self.assertIsNone(st["plantings"]["f2"]["planted_at"])
        self.assertTrue(teardown.leftovers(self.fake, self.gid))
        proc_exit = 0 if result.ok else 1
        self.assertEqual(proc_exit, 1)

    def test_a_timer_run_is_recorded_by_timer(self):
        with mock.patch.dict(os.environ, {aging.GAME_ENV: self.gid}):
            result = self.inject_at("now")
        self.assertTrue(result.ok)
        self.assertEqual(self.st()["plantings"]["f2"]["attempts"][-1]["by"], "timer")

    def test_a_stale_timer_refuses_and_records_nothing(self):
        before = (self.ldir / "state.yaml").read_bytes()
        with mock.patch.dict(os.environ, {aging.GAME_ENV: "another-game-abc123"}):
            with self.assertRaises(aging.TimerRefused):
                self.inject_at("now")
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)
        self.assertEqual(self.fake.runs, [])

    def test_a_timer_run_after_hand_over_records_its_refusal(self):
        localimpl.set_stage(self.ldir, "handed-over")
        with mock.patch.dict(os.environ, {aging.GAME_ENV: self.gid}):
            with self.assertRaisesRegex(GmError, "at or after hand-over"):
                self.inject_at("now")
        attempt = self.st()["plantings"]["f2"]["attempts"][-1]
        self.assertEqual((attempt["by"], attempt["outcome"]), ("timer", "refused"))
        self.assertEqual(self.fake.runs, [])
        with self.assertRaisesRegex(GmError, "at or after hand-over"):
            self.inject_at("now")       # by hand: refused, nothing more recorded
        self.assertEqual(len(self.st()["plantings"]["f2"]["attempts"]), 1)

    def test_a_late_run_waits_for_the_nodes(self):
        down = {"left": 3}
        real_run = self.fake.run

        def run(args, **kwargs):
            if args[:1] == ["ps"] and "status=running" in args and down["left"] > 0 \
                    and not self.fake.runs:
                down["left"] -= 1
                return subprocess.CompletedProcess(args, 0, "", "")
            return real_run(args, **kwargs)
        self.fake.run = run
        clock = [0.0]
        with mock.patch.dict(os.environ, {aging.GAME_ENV: self.gid}):
            result = self.inject_at("now", sleep=lambda s: clock.__setitem__(0, clock[0] + s),
                                    clock=lambda: clock[0])
        self.assertTrue(result.ok)
        self.assertEqual(result.nodes_down, [])
        self.assertGreater(clock[0], 0)              # it waited
        self.assertEqual([script_name(r) for r in self.fake.runs], ["10-drop-index", "20-analyze"])

    def test_a_late_run_acts_after_its_bound(self):
        clock = [0.0]
        real_run = self.fake.run
        self.fake.run = lambda args, **kw: (subprocess.CompletedProcess(args, 0, "", "")
                                            if args[:1] == ["ps"] and "status=running" in args
                                            and kw.get("check", True) else real_run(args, **kw))
        with mock.patch.dict(os.environ, {aging.GAME_ENV: self.gid}):
            result = self.inject_at("now", sleep=lambda s: clock.__setitem__(0, clock[0] + s),
                                    clock=lambda: clock[0])
        self.assertEqual(clock[0], aging.LATE_RUN_WAIT)
        self.assertEqual(sorted(result.nodes_down), ["bastion", "db", "producer"])
        self.assertFalse(result.ok)                  # the node is not there: recorded
        self.assertEqual(self.st()["plantings"]["f2"]["attempts"][-1]["outcome"], "failed")


class TestEarlyCheckMoves(InjectedV03):

    def test_moved_earlier_never_later(self):
        (self.ldir / "rendered" / "producer" / "jobs.yaml").write_text("jobs: []\n")
        self.start(test_aging_minimum="1h")
        st = self.st()
        due = aging.parse_instant(st["early_check"]["timer"]["due"])
        t0 = aging.parse_instant(st["load"]["t0"])
        # f2 waits for its planned instant, two days away: earliest = planned_at + 1h;
        # the early check at T0 + 30 min, half of the 1h override
        self.assertEqual(due, t0 + datetime.timedelta(minutes=30))
        # f2 at T0 + 50 min: earliest T0 + 1h50, bound T0 + 50 min: unchanged
        result = self.inject_at(aging.iso(t0 + datetime.timedelta(minutes=50)))
        self.assertIsNone(result.early_moved)
        self.assertEqual(aging.parse_instant(self.st()["early_check"]["timer"]["due"]), due)
        # f2 at T0 + 10 min: earliest T0 + 1h10, bound T0 + 10 min: moved earlier
        result = self.inject_at(aging.iso(t0 + datetime.timedelta(minutes=10)))
        self.assertEqual(aging.parse_instant(result.early_moved["due"]),
                         t0 + datetime.timedelta(minutes=10))
        self.assertEqual(self.st()["early_check"]["timer"], result.early_moved)
        self.assertIn(["restart", f"dbagm-{self.gid}_early-check.timer"], self.systemd.calls)


# --- Teardown of the timers --------------------------------------------------------

class TestTeardownTimers(InjectedV03):

    def setUp(self):
        super().setUp()
        self.start()
        self.inject_at(aging.iso(aging.parse_instant(
            self.impl["timeline"]["planned_handover"]) - datetime.timedelta(hours=7)))
        # another game's units: never touched
        self.other = self.systemd.unit_dir / "dbagm-other-game-abc123_early-check.timer"
        self.other.write_text("[Timer]\n")
        self.systemd.stamp_dir.mkdir(parents=True)
        (self.systemd.stamp_dir / f"stamp-dbagm-{self.gid}_early-check.timer").write_text("")
        self.systemd.failed.add(f"dbagm-{self.gid}_plant-f2.service")

    def teardown(self, **kwargs):
        return teardown.teardown(self.scenario, "laptop", docker=self.fake, systemd=self.systemd,
                                 sleep=lambda s: None, **kwargs)

    def test_units_removed_before_the_docker_objects(self):
        report = self.teardown()
        prefix = f"dbagm-{self.gid}_"
        self.assertEqual(report.timers, sorted(f"{prefix}{a}.{s}" for a in
                                               ("early-check", "plant-f2")
                                               for s in ("service", "timer")))
        self.assertEqual({f for f in self.systemd.files() if f.startswith(prefix)}, set())
        self.assertTrue(self.other.exists())
        self.assertEqual(list(self.systemd.stamp_dir.iterdir()), [])
        for unit in ("early-check", "plant-f2"):
            self.assertIn(["disable", "--now", f"{prefix}{unit}.timer"], self.systemd.calls)
        self.assertIn(["reset-failed", f"{prefix}*"], self.systemd.calls)
        self.assertEqual(self.systemd.called("daemon-reload")[-1], ["daemon-reload"])
        self.assertEqual(aging.game_units(self.systemd, self.gid), [])
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})
        self.assertIn("Host timers removed", report.text())
        self.assertEqual(self.st()["stage"], "torn-down")

    def test_a_unit_left_fails_the_teardown(self):
        stuck = f"dbagm-{self.gid}_plant-f2.timer"
        real = self.systemd.run

        def run(*args, check=True):
            proc = real(*args, check=check)
            if args[0] == "daemon-reload":
                self.systemd.loaded.add(stuck)
            return proc
        self.systemd.run = run
        with self.assertRaisesRegex(GmError, "left host timer units"):
            self.teardown()
        self.assertEqual(self.st()["stage"], "load-started")      # nothing recorded
        self.assertTrue(teardown.leftovers(self.fake, self.gid))  # Docker objects untouched

    def test_no_manager_with_timers_recorded_refuses(self):
        self.systemd.up = False
        with self.assertRaisesRegex(GmError, "does not answer"):
            self.teardown()
        self.assertEqual(self.st()["stage"], "load-started")


class TestTeardownWithoutTimers(InjectedV03):

    def test_no_manager_and_no_timer_is_a_note(self):
        systemd = FakeSystemd(self.tmp, up=False)
        report = teardown.teardown(self.scenario, "laptop", docker=self.fake, systemd=systemd,
                                   sleep=lambda s: None)
        self.assertIn("does not answer; the game records no timer", report.text())
        self.assertEqual(self.st()["stage"], "torn-down")

    def test_a_game_with_no_unit_calls_no_reload(self):
        report = teardown.teardown(self.scenario, "laptop", docker=self.fake,
                                   systemd=self.systemd, sleep=lambda s: None)
        self.assertEqual(report.timers, [])
        self.assertEqual(self.systemd.called("daemon-reload"), [])
        self.assertEqual(self.systemd.called("reset-failed"), [])


class TestExecQuoting(unittest.TestCase):

    def test_words(self):
        self.assertEqual(aging._exec_word("/usr/bin/python3"), "/usr/bin/python3")
        self.assertEqual(aging._exec_word("/srv/my games/x"), '"/srv/my games/x"')
        self.assertEqual(aging._exec_word("50%"), "50%%")
        self.assertEqual(aging._exec_word("$HOME"), "$$HOME")
