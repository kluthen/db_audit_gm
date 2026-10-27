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
        return aging.early_check_due(self.ldir, impl, st)

    def test_halfway_or_after_every_job_ran_once(self):
        impl = localimpl.read_implementation(self.ldir)
        planned = at(impl["timeline"]["planned_handover"])
        t0 = planned - datetime.timedelta(hours=20)
        t0s = aging.iso(t0)
        jobs = aging.rendered_jobs(self.ldir, impl)
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
        self.assertEqual(aging.parse_instant(timer["due"]),
                         aging.early_check_due(self.ldir, self.impl, st))
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
            "status", "exec", "logs", "teardown", "snapshot"]))
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
        self.assertEqual(self.st()["earliest_handover"]["at"],
                         aging.iso(t0 + datetime.timedelta(minutes=70)))

    def test_a_planting_now_moves_it_too(self):
        (self.ldir / "rendered" / "producer" / "jobs.yaml").write_text("jobs: []\n")
        self.start(test_aging_minimum="1h")
        t0 = aging.parse_instant(self.st()["load"]["t0"])
        result = self.inject_at("now")
        self.assertTrue(result.ok)
        # earliest about T0 + 1h: the early check at the floor, T0 + 5 min (or now + 1 min)
        moved = aging.parse_instant(result.early_moved["due"])
        self.assertLess(moved, t0 + datetime.timedelta(minutes=30))
        self.assertGreaterEqual(moved, t0 + datetime.timedelta(minutes=5))
        self.assertEqual(self.st()["earliest_handover"]["waiting_for"], [])


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


# --- 8b: outages, the checks, status, the hand-over --------------------------

import json  # noqa: E402

from tools.gm import state  # noqa: E402
from tools.tests import FakeDocker  # noqa: E402
from tools.tests.test_inject import DeployedGame  # noqa: E402

CHECKS = {"f1": "# Sealed check of fixture-random-page-cost",
          "f2": "# Sealed check of fixture-dropped-index",
          "f3": "# fixture sealed check (never run): the close-day job"}
LONG_AGO = "2020-01-01T00:00:00.5Z"


def minutes_between(first, last):
    out, m = [], at(first)
    while m <= at(last):
        out.append(aging.iso_minute(m))
        m += datetime.timedelta(minutes=1)
    return out


def scheduler_log(minutes, keys=("orders.insert", "orders.lookup", "reports.revenue"),
                  status="running 2020-01-01T00:00:01Z", calls=0):
    """A scheduler's reading: a summary (calls=0: a low-rate stream) and
    one key line per key for each minute."""
    lines = [f"status {status}"]
    for minute in minutes:
        stamp = aging.iso(at(minute) + datetime.timedelta(minutes=1, seconds=1))
        lines.append(f"{stamp} summary minute={minute} keys={len(keys)} calls={calls} errors=0")
        lines += [f"{stamp} key minute={minute} key={k} calls={calls} errors=0 p50_ms=- "
                  "p95_ms=- p99_ms=-" for k in keys]
    return "\n".join(lines) + "\n"


class AgingDocker(ScriptedDocker):
    """ScriptedDocker answering Swarm's task history too: `tasks` maps a
    service to its tasks (Docker's task JSON, with `_started` and
    `_finished` for its container); by default one task running since
    2020."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.tasks = {}

    def tasks_of(self, service):
        return self.tasks.get(service) or [{
            "ID": f"{service}.t1", "CreatedAt": LONG_AGO,
            "Status": {"State": "running", "Timestamp": "2020-01-01T00:00:01Z",
                       "ContainerStatus": {"ContainerID": f"{service}.c1"}},
            "_started": "2020-01-01T00:00:01.25Z", "_finished": "0001-01-01T00:00:00Z"}]

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None):
        args = [str(a) for a in args]
        if args[:3] == ["service", "ps", "-q"]:
            self.calls.append(args)
            return subprocess.CompletedProcess(
                args, 0, "".join(f"{t['ID']}\n" for t in self.tasks_of(args[-1])), "")
        if args[:3] == ["inspect", "--type", "task"]:
            self.calls.append(args)
            tasks = [t for svc in {a.rsplit(".", 1)[0] for a in args[5:]}
                     for t in self.tasks_of(svc) if t["ID"] in args[5:]]
            return subprocess.CompletedProcess(args, 0, "".join(
                json.dumps({k: v for k, v in t.items() if not k.startswith("_")}) + "\n"
                for t in tasks), "")
        if args[:3] == ["inspect", "--type", "container"]:
            self.calls.append(args)
            for tasks in [self.tasks_of(s) for s in self.objects["service"]] + \
                    list(self.tasks.values()):
                for t in tasks:
                    if (t["Status"].get("ContainerStatus") or {}).get("ContainerID") == args[-1]:
                        if t.get("_gone"):
                            return subprocess.CompletedProcess(args, 1, "", "No such container")
                        return subprocess.CompletedProcess(
                            args, 0, f"{t['_started']} {t['_finished']}\n", "")
            return subprocess.CompletedProcess(args, 1, "", "No such container")
        return super().run(args, input=input, stdin=stdin, capture=capture, check=check,
                           timeout=timeout)


class AgingGame(InjectedV03):
    """InjectedV03 on an AgingDocker; the sealed checks read present, the
    producer runs and logs every minute around now."""

    def setUp(self):
        patcher = mock.patch("tools.tests.test_inject.ScriptedDocker", AgingDocker)
        patcher.start()
        self.addCleanup(patcher.stop)
        super().setUp()
        for fragment in CHECKS.values():
            self.replies[fragment] = (1, "present\n", "")
        now = aging.now_utc()
        self.sched_text = scheduler_log(minutes_between(
            aging.iso_minute(now - datetime.timedelta(minutes=30)),
            aging.iso_minute(now + datetime.timedelta(minutes=30))))

    def reply(self, run):
        if aging.SCHEDULER_LOG in run["stdin"]:
            return (0, self.sched_text, "")
        return super().reply(run)

    def check(self, kind, **kwargs):
        return aging.run_check(self.scenario, "laptop", kind, docker=self.fake,
                               out=self.printed.append, **kwargs)


class TestOutages(unittest.TestCase):
    """W2 item 6: outage minutes, the lost time, its effect (D152, D175)."""

    T0 = at("2026-10-27T08:00:07Z")

    def lost(self, gap):
        """Minutes lost over two hours with `gap` minutes of the producer's
        summaries missing from 09:00."""
        first, last = aging.outage_span(self.T0, self.T0 + datetime.timedelta(hours=2))
        every = minutes_between(aging.iso_minute(first), aging.iso_minute(last))
        gone = set(minutes_between("2026-10-27T09:00Z",
                                   aging.iso_minute(at("2026-10-27T09:00:00Z")
                                                    + datetime.timedelta(minutes=gap - 1)))) \
            if gap else set()
        reading = aging.parse_scheduler_output(
            "producer", scheduler_log([m for m in every if m not in gone]))
        minutes = aging.outage_minutes(first, last, {"producer": reading.summaries},
                                       {"db": [(self.T0 - datetime.timedelta(days=1), None)]})
        return len(minutes), minutes

    def test_span(self):
        first, last = aging.outage_span(self.T0, at("2026-10-27T09:00:14Z"))
        self.assertEqual((first, last), (at("2026-10-27T08:01:00Z"), at("2026-10-27T08:58:00Z")))
        first, last = aging.outage_span(self.T0, at("2026-10-27T09:00:15Z"))
        self.assertEqual(last, at("2026-10-27T08:59:00Z"))
        _, last = aging.outage_span(self.T0, at("2026-10-27T12:00:00Z"),
                                    end=at("2026-10-27T10:30:00Z"))
        self.assertEqual(last, at("2026-10-27T10:29:00Z"))

    def test_lost_time_and_earliest_for_none_twenty_and_fifty_minutes(self):
        timeline = {**TIMELINE, "instances": {}}
        for gap, moved in ((0, 0), (20, 0), (50, 20)):
            lost, minutes = self.lost(gap)
            self.assertEqual(lost, gap)
            if gap:
                self.assertEqual(minutes["2026-10-27T09:00Z"], ["producer: no summary"])
            earliest, _ = aging.earliest_handover(timeline, aging.iso(self.T0), {}, lost)
            self.assertEqual(earliest, self.T0 + datetime.timedelta(hours=16, minutes=moved))

    def test_a_low_rate_stream_is_not_an_outage(self):
        # every summary reads calls=0: the scheduler runs, nothing is lost
        first, last = aging.outage_span(self.T0, self.T0 + datetime.timedelta(hours=1))
        reading = aging.parse_scheduler_output("producer", scheduler_log(
            minutes_between(aging.iso_minute(first), aging.iso_minute(last)), keys=(),
            calls=0))
        self.assertEqual(aging.outage_minutes(first, last, {"producer": reading.summaries}, {}),
                         {})

    def test_a_node_restart_is_an_outage_for_every_minute_it_touches(self):
        periods = [(at(LONG_AGO.replace(".5", "")), at("2026-10-27T08:30:40Z")),
                   (at("2026-10-27T08:31:20Z"), None)]
        first, last = aging.outage_span(self.T0, at("2026-10-27T09:00:00Z"))
        minutes = aging.outage_minutes(first, last, {}, {"db": periods})
        self.assertEqual(minutes, {"2026-10-27T08:30Z": ["db: no running task"],
                                   "2026-10-27T08:31Z": ["db: no running task"]})

    def test_periods_merge_and_a_minute_once_seen_is_kept(self):
        seen = {"2026-10-27T08:30Z": ["db: no running task"],
                "2026-10-27T08:31Z": ["db: no running task", "producer: no summary"],
                "2026-10-27T09:00Z": ["producer: no summary"]}
        periods = aging.merge_periods(seen)
        self.assertEqual(periods, [
            {"from": "2026-10-27T08:30Z", "to": "2026-10-27T08:31Z", "minutes": 2,
             "causes": ["db: no running task", "producer: no summary"]},
            {"from": "2026-10-27T09:00Z", "to": "2026-10-27T09:00Z", "minutes": 1,
             "causes": ["producer: no summary"]}])
        self.assertEqual(sorted(aging.period_minutes(periods)), sorted(seen))


class TestReadOutages(AgingGame):
    """An outage reading on the fake engine (master spec 8.7, 20)."""

    def setUp(self):
        super().setUp()
        self.start()
        self.now = at(self.st()["load"]["t0"]) + datetime.timedelta(minutes=20)
        self.t0 = aging.iso(self.now - datetime.timedelta(minutes=20))

    def read(self, st=None):
        st = st or {"load": {"t0": self.t0}, "history": [], "outages": None}
        return aging.read_outages(self.ldir, self.impl, st, self.fake, self.now)[0]

    def test_no_outage(self):
        record = self.read()
        self.assertEqual(record["lost_minutes"], 0)
        self.assertEqual(record["periods"], [])
        self.assertEqual(record["incomplete"], [])
        self.assertEqual(record["read_at"], aging.iso(self.now))

    def test_a_restarted_node_and_a_pruned_history(self):
        db = f"{self.gid}_db"
        restart = aging.floor_minute(at(self.t0)) + datetime.timedelta(minutes=6, seconds=10)
        back = restart + datetime.timedelta(seconds=40)
        self.fake.tasks[db] = [
            # the oldest kept task was created after T0: earlier ones may be pruned
            {"ID": f"{db}.t6", "CreatedAt": aging.iso(restart - datetime.timedelta(minutes=2)),
             "Status": {"State": "failed", "Timestamp": aging.iso(restart),
                        "ContainerStatus": {"ContainerID": f"{db}.c6"}},
             "_gone": True},
            {"ID": f"{db}.t7", "CreatedAt": aging.iso(restart),
             "Status": {"State": "running", "Timestamp": aging.iso(back),
                        "ContainerStatus": {"ContainerID": f"{db}.c7"}},
             "_started": aging.iso(back), "_finished": "0001-01-01T00:00:00Z"}]
        record = self.read()
        self.assertEqual(record["incomplete"], ["db"])
        # the minute of the restart; the minutes before the oldest kept task are
        # not judged by its history (pruned: at least, D174)
        self.assertEqual(record["lost_minutes"], 1)
        self.assertEqual(record["periods"][0]["from"],
                         aging.iso_minute(restart))
        self.assertEqual(record["periods"][0]["causes"], ["db: no running task"])
        self.assertEqual(aging.lost_text(record), "at least 1 min")
        # a later reading keeps the minute even once Swarm has pruned the task
        self.fake.tasks.pop(db)
        again = aging.read_outages(self.ldir, self.impl,
                                   {"load": {"t0": self.t0}, "history": [], "outages": record},
                                   self.fake, self.now + datetime.timedelta(minutes=1))[0]
        self.assertEqual(again["lost_minutes"], 1)
        self.assertEqual(again["incomplete"], ["db"])

    def test_an_unreadable_node_leaves_the_record(self):
        previous = {"read_at": self.t0, "through": None, "lost_minutes": 3,
                    "periods": [{"from": "2026-10-27T08:30Z", "to": "2026-10-27T08:32Z",
                                 "minutes": 3, "causes": ["producer: no summary"]}],
                    "incomplete": []}
        self.replies["start"] = None
        self.sched_text = None
        real = self.reply
        self.reply = lambda run: ((2, "", "grep: /var/log/scheduler/scheduler.log: denied\n")
                                  if aging.SCHEDULER_LOG in run["stdin"] else real(run))
        self.fake.reply = self.reply
        record = self.read({"load": {"t0": self.t0}, "history": [], "outages": previous})
        self.assertEqual(record["lost_minutes"], 3)
        self.assertEqual(record["periods"], previous["periods"])
        self.assertIn("could not be read", record["unread"]["reason"])


class TestEarlyAndHandOverChecks(AgingGame):

    def setUp(self):
        super().setUp()
        self.start()

    def test_the_early_check_passes_and_records(self):
        run = self.check(aging.EARLY_CHECK)
        self.assertEqual(run.exit_code, 0, run.text())
        st = self.st()
        record = st["early_check"]["result"]
        self.assertTrue(record["passed"])
        self.assertEqual([f["instance"] for f in record["faults"]], ["f1", "f3"])
        self.assertEqual(record["not_planted"], ["f2"])
        self.assertEqual(record["schedulers"][0]["node"], "producer")
        self.assertTrue(record["schedulers"][0]["running"])
        self.assertEqual(record["schedulers"][0]["keys"],
                         {"orders.insert": True, "orders.lookup": True, "reports.revenue": True})
        self.assertEqual(set(record["schedulers"][0]["jobs"].values()), {"not-due"})
        self.assertEqual(record["nodes"], {"bastion": "healthy", "db": "healthy",
                                           "producer": "healthy"})
        self.assertEqual(record["lost_minutes"], 0)
        self.assertEqual(st["early_check"]["timer"]["unit"], f"dbagm-{self.gid}_early-check")
        self.assertEqual(st["earliest_handover"]["waiting_for"], ["f2"])
        self.assertIn("Early check of game", run.text())

    def test_failures(self):
        self.replies[CHECKS["f1"]] = (0, "random_page_cost is 1.1\n", "")
        self.sched_text = scheduler_log(minutes_between(
            aging.iso_minute(aging.now_utc() - datetime.timedelta(minutes=5)),
            aging.iso_minute(aging.now_utc() + datetime.timedelta(minutes=5))),
            keys=("orders.insert", "orders.lookup"), status="idle 2026-10-26T19:00:00Z")
        self.fake.health = "unhealthy"
        run = self.check(aging.EARLY_CHECK)
        self.assertEqual(run.exit_code, 1)
        failures = self.st()["early_check"]["result"]["failures"]
        self.assertIn("f1 fixture-random-page-cost: reads fixed (exit 0), expected exit 1 at "
                      "hand-over", failures)
        self.assertIn("producer: the scheduler is not running (status: idle "
                      "2026-10-26T19:00:00Z)", failures)
        self.assertTrue(any(f.startswith("producer: key reports.revenue has no line")
                            for f in failures), failures)
        self.assertTrue(any(f.startswith("node db: unhealthy") for f in failures), failures)
        self.assertEqual(self.st()["stage"], "load-started")       # never failed (8.7)
        self.assertIsNone(self.st()["failure"])

    def test_too_soon_at_the_early_check_and_at_hand_over(self):
        self.replies[CHECKS["f3"]] = (3, "remaining=600 the job has not run since\n", "")
        run = self.check(aging.EARLY_CHECK)
        self.assertEqual(run.exit_code, 0, run.text())
        entry = self.st()["early_check"]["result"]["faults"][1]
        self.assertEqual((entry["verdict"], entry["remaining"]), ("too-soon", 600))
        self.inject_at("now")
        run = self.check(aging.HANDOVER_CHECK)
        self.assertEqual(run.exit_code, 3, run.text())
        self.assertEqual(self.st()["handover_checks"][-1]["failures"],
                         ["f3 fixture-job-timezone: too soon to tell, 600 s of its window remain"])
        self.assertIn("wait 600 s", run.text())

    def test_the_hand_over_check_needs_every_planting(self):
        run = self.check(aging.HANDOVER_CHECK)
        self.assertEqual(run.exit_code, 1)
        self.assertIn("f2: not planted", self.st()["handover_checks"][-1]["failures"])
        self.inject_at("now")
        run = self.check(aging.HANDOVER_CHECK)
        self.assertEqual(run.exit_code, 0, run.text())
        self.assertEqual(len(self.st()["handover_checks"]), 2)
        self.assertEqual([f["instance"] for f in self.st()["handover_checks"][-1]["faults"]],
                         ["f1", "f2", "f3"])

    def test_refusals(self):
        localimpl.set_stage(self.ldir, "handed-over")
        with self.assertRaisesRegex(GmError, "needs stage load-started"):
            self.check(aging.HANDOVER_CHECK)
        with mock.patch.dict(os.environ, {aging.GAME_ENV: "another-game-abc123"}):
            with self.assertRaises(aging.TimerRefused):
                self.check(aging.EARLY_CHECK)

    def test_a_job_missed_and_a_job_never(self):
        t0 = at("2026-10-26T00:00:00Z")
        now = at("2026-10-27T12:00:00Z")
        reading = aging.parse_scheduler_output("producer", scheduler_log(
            ["2026-10-27T11:58Z"]) + "2026-10-27T08:00:01Z run job=sweep key=orders.lookup "
                                     "phase=start\n2026-10-27T09:00:00Z job job=weekly-report "
                                     "key=reports.revenue next=never\n")
        entry, failures = aging.judge_scheduler(self.ldir, self.impl, "producer", reading,
                                                t0, now)
        self.assertEqual(entry["jobs"]["sweep"], "ran")
        self.assertEqual(entry["jobs"]["weekly-report"], "never")
        self.assertEqual(entry["jobs"]["close-day"], "missed")
        self.assertTrue(any("job close-day, due" in f for f in failures), failures)

    def test_a_missed_planting(self):
        planting = {"plant_at": "handover-6h", "planned_at": "2026-10-27T08:00:00Z",
                    "timer": {"unit": "u", "due": "2026-10-27T08:00:00Z"}, "attempts": [],
                    "planted_at": None}
        self.assertIsNone(aging.planting_problem("f2", planting, at("2026-10-27T08:15:00Z")))
        self.assertEqual(aging.planting_problem("f2", planting, at("2026-10-27T08:15:01Z"))[0],
                         "missed")
        planting["timer"] = None
        self.assertEqual(aging.planting_problem("f2", planting, at("2026-10-27T09:00:00Z"))[0],
                         "unscheduled")
        planting["attempts"] = [{"at": "2026-10-27T08:00:03Z", "by": "timer",
                                 "outcome": "failed", "reason": "exit 3"}]
        self.assertEqual(aging.planting_problem("f2", planting, at("2026-10-27T09:00:00Z")),
                         ("failed", "f2: its planting failed at 2026-10-27T08:00:03Z: exit 3"))
        planting["attempts"].append({"at": "2026-10-27T09:12:44Z", "by": "gmctl",
                                     "outcome": "ok"})
        planting["planted_at"] = "2026-10-27T09:12:44Z"
        self.assertIsNone(aging.planting_problem("f2", planting, at("2026-10-27T10:00:00Z")))


class TestStatus(AgingGame):
    """W2 item 11: the head, then the game's lines, then the aging's."""

    def status(self, **kwargs):
        return state.status_text(self.ldir, docker=self.fake, **kwargs)

    def test_before_t0(self):
        text = self.status()
        self.assertTrue(text.startswith(f"Game {self.gid}"), text)
        self.assertIn("  aging: not started (gmctl start-load); minimum 16h", text)
        self.assertIn("  planned hand-over: ", text)
        self.assertIn("    f2: planned ", text)

    def test_aging_lines(self):
        self.start()
        text = self.status()
        self.assertTrue(text.startswith(f"Game {self.gid}"), text)
        lines = text.splitlines()
        aging_at = next(i for i, l in enumerate(lines) if l.startswith("  aging: T0 "))
        self.assertGreater(aging_at, lines.index("  history:"))
        self.assertIn("of the 16h minimum", lines[aging_at])
        self.assertEqual(lines[aging_at + 1], "  lost time: 0 min")
        self.assertIn("(provisional, waiting for the planting of f2)", lines[aging_at + 2])
        self.assertRegex(text, r"\n  early check: due \S+, timer dbagm-")
        st = self.st()
        self.assertEqual(st["outages"]["lost_minutes"], 0)          # read on status
        self.assertEqual(st["earliest_handover"]["waiting_for"], ["f2"])

    def test_head_failures_and_outages_first(self):
        self.start()
        self.replies[FRAGMENTS["10-drop-index"]] = (3, "", "psql: error: refused\n")
        self.inject_at("now")
        self.replies[CHECKS["f1"]] = (0, "fixed\n", "")
        self.check(aging.EARLY_CHECK)

        def outage(st):
            st["outages"] = {"read_at": st["load"]["t0"], "through": None, "lost_minutes": 42,
                             "incomplete": ["db"],
                             "periods": [{"from": "2026-10-27T03:02Z", "to": "2026-10-27T03:43Z",
                                          "minutes": 42, "causes": ["producer: no summary"]}]}
        localimpl.update_state(self.ldir, outage)
        lines = self.status().splitlines()
        self.assertTrue(lines[0].startswith("FAILED planting: f2: its planting failed at "),
                        lines[0])
        self.assertIn("--at now --instance f2", lines[0])
        self.assertTrue(lines[1].startswith("FAILED early check at "), lines[1])
        self.assertIn("f1 fixture-random-page-cost: reads fixed", lines[1])
        self.assertEqual(lines[2], "OUTAGES: at least 42 min lost in 1 period(s), the earliest "
                                   "hand-over 12 min later; task history may be incomplete "
                                   "for db")
        self.assertEqual(lines[3], "  2026-10-27T03:02Z to 2026-10-27T03:43Z (42 min): "
                                   "producer: no summary")
        self.assertEqual(lines[4], f"Game {self.gid}")
        self.assertIn("  lost time: at least 42 min", lines)

    def test_a_failed_start_load_heads_it(self):
        self.replies["start"] = lambda run: (1, "status did not read running\n", "")
        self.start()
        first = self.status().splitlines()[0]
        self.assertTrue(first.startswith("FAILED start-load at "), first)
        self.assertIn("T0 not recorded: producer: status did not read running", first)

    def test_the_override_heads_everything(self):
        self.start(test_aging_minimum="1h")
        self.replies[CHECKS["f1"]] = (0, "fixed\n", "")
        run = self.check(aging.EARLY_CHECK)
        self.assertEqual(run.record["override"], "1h")
        lines = self.status().splitlines()
        self.assertTrue(lines[0].startswith("TEST HARNESS OVERRIDE: this game's aging minimum "
                                            "is shortened to 1h"), lines[0])
        self.assertTrue(lines[1].startswith("FAILED early check"), lines[1])
        self.assertIn("of the 1h minimum", self.status())
        self.assertEqual(self.st()["earliest_handover"]["override"], "1h")

    def test_status_says_when_the_outages_could_not_be_read(self):
        self.start()
        self.fake.reachable = False
        text = state.status_text(self.ldir, docker=self.fake)
        self.assertIn("OUTAGES NOT READ at ", text.splitlines()[0])


class TestHandedOver(AgingGame):
    """`status --set handed-over` in a game that ages (W2 item 11; D172)."""

    def setUp(self):
        super().setUp()
        self.start(test_aging_minimum="1h")
        self.t0 = at(self.st()["load"]["t0"])

    def record_check(self, when, passed=True):
        def change(st):
            st.setdefault("handover_checks", []).append(
                {"at": aging.iso(when), "passed": passed,
                 "failures": [] if passed else ["node db: unhealthy"]})
        localimpl.update_state(self.ldir, change)

    def set(self, when):
        return state.set_gm_stage(self.ldir, "handed-over", now=when)

    def test_refused_while_provisional(self):
        self.record_check(self.t0 + datetime.timedelta(days=3))
        with self.assertRaisesRegex(GmError, "waits for the planting of f2"):
            self.set(self.t0 + datetime.timedelta(days=3))

    def test_refused_then_accepted_on_its_three_conditions(self):
        self.inject_at("now")
        earliest = at(self.st()["plantings"]["f2"]["planted_at"]) + datetime.timedelta(hours=1)
        earliest = max(earliest, self.t0 + datetime.timedelta(hours=1))
        before = (self.ldir / "state.yaml").read_bytes()
        with self.assertRaisesRegex(GmError, r"the earliest hand-over is \S+, in 1h: not "
                                             r"reached|the earliest hand-over is \S+, in 59m"):
            self.set(self.t0)
        with self.assertRaisesRegex(GmError, "no hand-over check has run"):
            self.set(earliest)
        self.record_check(earliest - datetime.timedelta(minutes=1))
        with self.assertRaisesRegex(GmError, "before the earliest hand-over"):
            self.set(earliest)
        self.record_check(earliest, passed=False)
        with self.assertRaisesRegex(GmError, "failed: node db: unhealthy"):
            self.set(earliest)
        self.assertNotEqual((self.ldir / "state.yaml").read_bytes(), before)  # checks only
        self.assertEqual(self.st()["stage"], "load-started")
        self.record_check(earliest)
        with self.assertRaisesRegex(GmError, "the hand-over snapshot is neither taken nor "
                                             "recorded as not fitting"):
            self.set(earliest)          # the third condition (chunk 11a, spec D172)
        localimpl.update_state(self.ldir, lambda st: st.update(
            snapshot={"status": "taken", "at": aging.iso(earliest)}))
        self.assertTrue(self.set(earliest + datetime.timedelta(minutes=5)))
        st = self.st()
        self.assertEqual(st["stage"], "handed-over")
        self.assertEqual(st["earliest_handover"]["at"], aging.iso(earliest))
        self.assertEqual(st["history"][-1]["at"],
                         aging.iso(earliest + datetime.timedelta(minutes=5)))

    def test_not_from_injected_in_a_game_that_ages(self):
        localimpl.set_stage(self.ldir, "injected")
        with self.assertRaisesRegex(GmError, "can only follow load-started"):
            self.set(self.t0 + datetime.timedelta(days=3))


class TestStaticGameHandOver(DeployedGame):
    """A game with no scheduler node (D157, D158): no aging; its hand-over
    check judges the faults and the nodes only."""

    def test_handed_over_after_injected_with_no_aging(self):
        for fragment in ("# Sealed check of fixture-dropped-index",
                         "# Sealed check of fixture-random-page-cost"):
            self.replies[fragment] = (1, "present\n", "")
        self.load_data()
        self.inject()
        with self.assertRaisesRegex(GmError, "no early check"):
            aging.run_check(self.scenario, "laptop", aging.EARLY_CHECK, docker=self.fake)
        run = aging.run_check(self.scenario, "laptop", aging.HANDOVER_CHECK, docker=self.fake)
        self.assertEqual(run.exit_code, 0, run.text())
        record = localimpl.read_state(self.ldir)["handover_checks"][-1]
        self.assertEqual(sorted(record), ["at", "failures", "faults", "nodes", "passed"])
        st = localimpl.read_state(self.ldir)
        self.assertNotIn("outages", st)
        self.assertNotIn("earliest_handover", st)
        text = state.status_text(self.ldir, docker=self.fake)
        for word in ("aging:", "lost time", "earliest hand-over", "plantings:", "OUTAGES"):
            self.assertNotIn(word, text)
        self.assertIn("  hand-over check: passed at ", text)
        with self.assertRaisesRegex(GmError, "the hand-over snapshot is neither taken"):
            state.set_gm_stage(self.ldir, "handed-over")     # spec D172, in this kind too
        localimpl.update_state(self.ldir, lambda st: st.update(
            snapshot={"status": "not-fitting", "at": localimpl.now_iso()}))
        self.assertTrue(state.set_gm_stage(self.ldir, "handed-over"))
        stages = [h["stage"] for h in localimpl.read_state(self.ldir)["history"]]
        self.assertEqual(stages[-2:], ["injected", "handed-over"])


class TestCheckCommandLine(ScenarioCopyTest):

    def test_options_parse_and_exclude_each_other(self):
        parser = build_parser()
        args = parser.parse_args(["check", "d", "--playground", "p", "--early-check"])
        self.assertTrue(args.early_check)
        args = parser.parse_args(["check", "d", "--playground", "p", "--handover-check"])
        self.assertTrue(args.handover_check)
        with self.assertRaises(SystemExit):
            with mock.patch("sys.stderr"):
                parser.parse_args(["check", "d", "--playground", "p", "--early-check",
                                   "--handover-check"])

    def test_refused_without_a_game_exits_2(self):
        proc = run_gmctl("check", self.scenario, "--playground", "laptop", "--handover-check")
        self.assertEqual(proc.returncode, 2, proc.stderr)
        self.assertIn("gmctl check: no game", proc.stderr)
