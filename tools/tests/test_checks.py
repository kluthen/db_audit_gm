"""gmctl validate and check (tools/gm/checks.py); Docker stubbed."""

import argparse
import contextlib
import datetime
import io
import unittest
from unittest import mock

import yaml

import tools.gm as gm
from tools.gm import checks, localimpl, model
from tools.gm.model import GmError
from tools.tests import REPO_ROOT, run_gmctl
from tools.tests.test_deploy import RenderedGame
from tools.tests.test_inject import F2_ENV, FRAGMENTS, DeployedGame, script_name

VALIDATOR = "/opt/gm/validator/validate.sh"


class TestBrickValidators(unittest.TestCase):

    def test_extra_validator_in_both_bricks(self):
        expected = {"postgres": "postgres", "bastion": "player"}
        for brick, run_as in expected.items():
            with self.subTest(brick=brick):
                data = yaml.safe_load((REPO_ROOT / "bricks" / brick / "brick.yaml").read_text())
                definition = model.Definition("brick", brick, data["version"],
                                              REPO_ROOT / "bricks" / brick, data, "catalog")
                self.assertEqual(checks.validator_of(definition), (VALIDATOR, run_as))

    def test_brick_without_validator(self):
        definition = model.Definition("brick", "x", "0.1.0", REPO_ROOT, {"extra": {}}, "catalog")
        with self.assertRaisesRegex(GmError, "declares no extra.validator"):
            checks.validator_of(definition)


class TestValidate(DeployedGame):

    def validate(self):
        return checks.validate(self.scenario, "laptop", docker=self.fake)

    def test_every_node_green(self):
        self.replies[f"exec {VALIDATOR}"] = (0, "GREEN: all rules hold\n", "")
        result = self.validate()
        self.assertEqual(result.exit_code, 0)
        self.assertEqual([(r["container"], r["user"], r["argv"], r["stdin"], r["env"])
                          for r in self.fake.runs],
                         [(f"{self.gid}_bastion.1.ctr", "player", ["sh", "-s"],
                           f"exec {VALIDATOR}\n", {}),
                          (f"{self.gid}_db.1.ctr", "postgres", ["sh", "-s"],
                           f"exec {VALIDATOR}\n", {})])
        self.assertEqual(result.text().splitlines(), [
            "bastion:", "  GREEN: all rules hold", "db:", "  GREEN: all rules hold",
            f"Validators of game {self.gid}: bastion green, db green."])

    def test_red(self):
        def reply(run):
            if run["user"] == "postgres":
                return (1, "RED work_mem: 128MB is above 64MB\nRED x: y\n", "")
            return (0, "GREEN: ok\n", "")
        self.fake.reply = reply
        result = self.validate()
        self.assertEqual(result.exit_code, 1)
        self.assertIn("db:\n  RED work_mem: 128MB is above 64MB\n  RED x: y", result.text())
        self.assertIn("bastion green, db red.", result.text())

    def test_error_wins_over_red(self):
        def reply(run):
            if run["user"] == "postgres":
                return (2, "ERROR: envelope file unreadable\n", "")
            return (1, "RED sshd: not listening\n", "")
        self.fake.reply = reply
        result = self.validate()
        self.assertEqual(result.exit_code, 2)
        self.assertIn("  ERROR: envelope file unreadable\n  (validator exit status 2)",
                      result.text())

    def test_validator_that_cannot_start_is_an_error(self):
        self.fake.fail[("exec", "-u", "player")] = "unable to find user player"
        result = self.validate()
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.nodes[0].verdict, "error")
        self.assertIn("could not be started", result.nodes[0].lines[0])
        self.assertEqual(result.nodes[1].verdict, "green")

    def test_every_deployed_stage_and_no_stage_change(self):
        for stage in ("deployed", "data-loaded", "injected", "handed-over", "final-answer",
                      "feedback-given"):
            if stage != "deployed":
                localimpl.set_stage(self.ldir, stage)
            before = (self.ldir / "state.yaml").read_bytes()
            self.assertEqual(self.validate().exit_code, 0)
            self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)

    def test_refused_when_not_deployed(self):
        localimpl.set_stage(self.ldir, "torn-down")
        with self.assertRaisesRegex(GmError, "validate needs stage deployed"):
            self.validate()
        self.assertEqual(self.fake.runs, [])


class TestCheck(DeployedGame):

    def setUp(self):
        super().setUp()
        for stage in ("data-loaded", "injected"):
            localimpl.set_stage(self.ldir, stage)
        self.replies[FRAGMENTS["f1-check"]] = (1, "random_page_cost is still 4.\n", "")
        self.replies[FRAGMENTS["f2-check"]] = (1, "orders still has no index.\nmore\n", "")

    def check(self):
        return checks.check(self.scenario, "laptop", docker=self.fake)

    def test_present_one_line_per_instance(self):
        before = (self.ldir / "state.yaml").read_bytes()
        result = self.check()
        self.assertEqual(result.exit_code, 1)
        self.assertEqual(result.text().splitlines(), [
            "f1 fixture-random-page-cost: present — random_page_cost is still 4.",
            "f2 fixture-dropped-index: present — orders still has no index."])
        self.assertEqual([script_name(r) for r in self.fake.runs], ["f1-check", "f2-check"])
        f1, f2 = self.fake.runs
        faults = self.scenario / "faults"
        self.assertEqual(f1["stdin"],
                         (faults / "fixture-random-page-cost/checks/fixed.sh").read_text())
        self.assertEqual(f2["stdin"],
                         (faults / "fixture-dropped-index/checks/fixed.sh").read_text())
        self.assertEqual((f1["env"], f2["env"]), ({}, F2_ENV))
        self.assertEqual({r["user"] for r in self.fake.runs}, {"root"})
        self.assertEqual({r["argv"][0] for r in self.fake.runs}, {"sh"})
        self.assertEqual({r["container"] for r in self.fake.runs}, {f"{self.gid}_db.1.ctr"})
        self.assertEqual((self.ldir / "state.yaml").read_bytes(), before)

    def test_all_fixed(self):
        self.replies[FRAGMENTS["f1-check"]] = (0, "random_page_cost is 1.1.\n", "")
        self.replies[FRAGMENTS["f2-check"]] = (0, "orders has an index again.\n", "")
        result = self.check()
        self.assertEqual(result.exit_code, 0)
        self.assertIn("f2 fixture-dropped-index: fixed — orders has an index again.",
                      result.text())

    def test_any_error_exits_2(self):
        self.replies[FRAGMENTS["f2-check"]] = (2, "", "psql: could not connect\n")
        result = self.check()
        self.assertEqual(result.exit_code, 2)
        self.assertIn("f2 fixture-dropped-index: error — psql: could not connect",
                      result.text())
        self.replies[FRAGMENTS["f2-check"]] = (127, "", "")
        self.assertIn("error — exit status 127, no output", self.check().text())

    def test_too_soon(self):
        self.replies[FRAGMENTS["f1-check"]] = (0, "random_page_cost is 1.1.\n", "")
        self.replies[FRAGMENTS["f2-check"]] = (3, "remaining=600 duplicates: 0 in 4 min\n",
                                               "")
        result = self.check()
        self.assertEqual(result.exit_code, checks.TOO_SOON)
        self.assertEqual(checks.TOO_SOON, 3)
        self.assertEqual(result.text().splitlines(), [
            "f1 fixture-random-page-cost: fixed — random_page_cost is 1.1.",
            "f2 fixture-dropped-index: too-soon — 600 s of the window remain: "
            "duplicates: 0 in 4 min"])
        f1, f2 = result.lines
        self.assertEqual((f1.verdict, f1.returncode, f1.remaining), ("fixed", 0, None))
        self.assertEqual((f2.verdict, f2.returncode, f2.remaining), ("too-soon", 3, 600))
        self.replies[FRAGMENTS["f1-check"]] = (1, "random_page_cost is still 4.\n", "")
        self.assertEqual(self.check().exit_code, 1)

    def test_exit_3_without_remaining_line_is_an_error(self):
        self.replies[FRAGMENTS["f2-check"]] = (3, "", "psql: script error\n")
        result = self.check()
        self.assertEqual(result.exit_code, 2)
        self.assertEqual(result.lines[1].text(),
                         "f2 fixture-dropped-index: error — exit status 3 (too soon) without "
                         "a first line remaining=<N> (N seconds, at least 1): psql: script "
                         "error")
        self.assertEqual((result.lines[1].returncode, result.lines[1].remaining), (3, None))

    def test_only_the_instances_asked_in_scenario_order(self):
        result = checks.check(self.scenario, "laptop", docker=self.fake, instances=["f2"])
        self.assertEqual([script_name(r) for r in self.fake.runs], ["f2-check"])
        self.assertEqual([line.instance for line in result.lines], ["f2"])
        self.fake.runs.clear()
        result = checks.check(self.scenario, "laptop", docker=self.fake,
                              instances=["f2", "f1"])
        self.assertEqual([script_name(r) for r in self.fake.runs], ["f1-check", "f2-check"])
        self.fake.runs.clear()
        result = checks.check(self.scenario, "laptop", docker=self.fake, instances=[])
        self.assertEqual((result.lines, self.fake.runs, result.exit_code), ([], [], 0))

    def test_unknown_instance_refused_before_running(self):
        with self.assertRaisesRegex(GmError, "not a fault instance of the scenario: f9"):
            checks.check(self.scenario, "laptop", docker=self.fake, instances=["f1", "f9"])
        self.assertEqual(self.fake.runs, [])

    def test_behavioural_window_and_threshold_reach_the_script(self):
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["sealed_check"].update(behavioural=True))

        def key(d):
            d["instances"][1]["sealed_check"].update(window="10m", threshold=0.5)
        self.edit_yaml("gm/answer-key.yaml", key)
        self.check()
        f1, f2 = self.fake.runs
        self.assertEqual(f1["env"], {})
        self.assertEqual(f2["env"], dict(F2_ENV, CHECK_WINDOW_SECONDS="600",
                                         CHECK_THRESHOLD="0.5"))

        def integer_key(d):
            d["instances"][1]["sealed_check"].update(window="2h", threshold=3)
        self.edit_yaml("gm/answer-key.yaml", integer_key)
        self.fake.runs.clear()
        self.check()
        self.assertEqual({k: v for k, v in self.fake.runs[1]["env"].items()
                          if k.startswith("CHECK_")},
                         {"CHECK_WINDOW_SECONDS": "7200", "CHECK_THRESHOLD": "3"})

    def test_check_that_cannot_start_is_an_error(self):
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["sealed_check"].update(run_as="nobody2"))
        self.fake.fail[("exec", "-u", "nobody2")] = "unable to find user nobody2"
        result = self.check()
        self.assertEqual(result.exit_code, 2)
        self.assertIn("f2 fixture-dropped-index: error — the check could not be started",
                      result.text())
        self.assertEqual(result.lines[1].returncode, None)
        self.assertIn("f1 fixture-random-page-cost: present", result.text())

    def test_required_parameter_without_value_refused_before_running(self):
        def change(d):
            d["fault_instances"][1]["parameters"]["column"] = None
        self.edit_yaml("scenario.yaml", change)
        with self.assertRaisesRegex(GmError, "parameter column is required"):
            self.check()
        self.assertEqual(self.fake.runs, [])

    def test_allowed_from_injected_on(self):
        for stage in ("handed-over", "final-answer", "feedback-given"):
            localimpl.set_stage(self.ldir, stage)
            self.assertEqual(self.check().exit_code, 1)
            self.assertEqual(localimpl.read_state(self.ldir)["stage"], stage)

    def test_refused_before_injection(self):
        localimpl.set_stage(self.ldir, "data-loaded")
        with self.assertRaisesRegex(GmError, "check needs stage injected or load-started or handed-over"):
            self.check()
        self.assertEqual(self.fake.runs, [])


PLANTED = "2026-10-30T08:00:00Z"
HANDED_OVER = "2026-10-30T12:00:00Z"
NOW = datetime.datetime(2026, 10, 30, 15, 0, tzinfo=datetime.timezone.utc)


class TestJudgedMoment(DeployedGame):
    """CHECK_SINCE (master spec 6.5, 12.1, 14; spec D217): f2's check judges
    runs; f1's judges the live state, as in v0.3."""

    def setUp(self):
        super().setUp()
        for stage in ("data-loaded", "injected"):
            localimpl.set_stage(self.ldir, stage)
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["sealed_check"].update(judges="runs"))
        self.edit_yaml("gm/answer-key.yaml", lambda d: d["instances"][1]["sealed_check"]
                       .update(judges="runs", threshold=0))

        def planted(st):
            st["plantings"] = {"f1": {"plant_at": "T0", "planted_at": "2026-10-30T07:00:00Z",
                                      "by": "inject"},
                               "f2": {"plant_at": "T0", "planted_at": PLANTED, "by": "inject"}}
        localimpl.update_state(self.ldir, planted)

    def check(self, **kwargs):
        self.fake.runs.clear()
        return checks.check(self.scenario, "laptop", docker=self.fake, now=NOW, **kwargs)

    def envs(self, **kwargs):
        self.check(**kwargs)
        return {script_name(r): r["env"] for r in self.fake.runs}

    def test_before_the_hand_over_the_planting_moment(self):
        envs = self.envs()
        self.assertEqual(envs["f2-check"], dict(F2_ENV, CHECK_THRESHOLD="0",
                                                CHECK_SINCE=PLANTED))
        self.assertEqual(envs["f1-check"], {})            # a live-state check, as in v0.3

    def test_after_the_hand_over_the_hand_over_from_the_state(self):
        localimpl.set_stage(self.ldir, "handed-over", HANDED_OVER)
        self.assertEqual(self.envs()["f2-check"]["CHECK_SINCE"], HANDED_OVER)
        # the first hand-over, later stages and a restart's second one aside
        localimpl.set_stage(self.ldir, "final-answer", "2026-10-30T14:00:00Z")
        localimpl.set_stage(self.ldir, "handed-over", "2026-10-30T14:30:00Z")
        self.assertEqual(self.envs()["f2-check"]["CHECK_SINCE"], HANDED_OVER)

    def test_since_raises_it_per_instance(self):
        localimpl.set_stage(self.ldir, "handed-over", HANDED_OVER)
        envs = self.envs(since="2026-10-30T13:30:00Z", instances=["f2"])
        self.assertEqual(list(envs), ["f2-check"])
        self.assertEqual(envs["f2-check"]["CHECK_SINCE"], "2026-10-30T13:30:00Z")
        # the minute form is read too; an earlier time never lowers it
        self.assertEqual(self.envs(since="2026-10-30T13:45Z")["f2-check"]["CHECK_SINCE"],
                         "2026-10-30T13:45:00Z")
        self.assertEqual(self.envs(since="2026-10-30T09:00:00Z")["f2-check"]["CHECK_SINCE"],
                         HANDED_OVER)
        # before the hand-over it raises the planting moment
        localimpl.update_state(self.ldir, lambda st: st.update(history=[
            h for h in st["history"] if h["stage"] != "handed-over"]))
        self.assertEqual(self.envs(since="2026-10-30T09:00:00Z")["f2-check"]["CHECK_SINCE"],
                         "2026-10-30T09:00:00Z")

    def test_since_refusals_run_nothing(self):
        for since, instances, pattern in (
                ("2026-10-30T16:00:00Z", None, "--since 2026-10-30T16:00:00Z is in the future"),
                ("yesterday", None, "--since: 'yesterday' is not a UTC instant"),
                ("2026-10-30T13:00:00Z", ["f1"], r"--since 2026-10-30T13:00:00Z: no fault "
                                                 r"instance checked judges runs or triggers "
                                                 r"\(f1\)")):
            with self.subTest(since=since):
                with self.assertRaisesRegex(GmError, pattern):
                    self.check(since=since, instances=instances)
                self.assertEqual(self.fake.runs, [])

    def test_an_instance_not_planted_yet_is_refused(self):
        localimpl.update_state(self.ldir, lambda st: st["plantings"]["f2"].update(
            planted_at=None, plant_at="+2h"))
        with self.assertRaisesRegex(GmError, "fault instance f2 is not planted yet: its sealed "
                                             "check judges runs since its planting"):
            self.check()
        self.assertEqual(self.fake.runs, [])
        self.assertEqual(self.check(instances=["f1"]).exit_code, 0)

    def test_too_soon_names_the_time_to_the_next_run(self):
        self.replies[FRAGMENTS["f2-check"]] = (3, "remaining=5400 no run since the reload\n",
                                               "")
        result = self.check()
        self.assertEqual(result.exit_code, checks.TOO_SOON)
        self.assertEqual(result.lines[1].text(),
                         "f2 fixture-dropped-index: too-soon — the job's next run is in 5400 s "
                         f"(1h30m), judged since {PLANTED}: no run since the reload")
        self.assertEqual((result.lines[1].remaining, result.lines[1].since), (5400, PLANTED))


class TestReadCheck(unittest.TestCase):

    def read(self, returncode, *lines):
        line = checks.read_check("f3", "x-fault", returncode, list(lines))
        return line.verdict, line.returncode, line.remaining, line.text()

    def test_fixed_present_error(self):
        self.assertEqual(self.read(0, "gone."), ("fixed", 0, None, "f3 x-fault: fixed — gone."))
        self.assertEqual(self.read(1, "still there.", "more"),
                         ("present", 1, None, "f3 x-fault: present — still there."))
        self.assertEqual(self.read(2, "cannot query."),
                         ("error", 2, None, "f3 x-fault: error — cannot query."))
        self.assertEqual(self.read(127),
                         ("error", 127, None, "f3 x-fault: error — exit status 127, no output"))

    def test_too_soon(self):
        self.assertEqual(self.read(3, "remaining=600 3 duplicates in 6 min"),
                         ("too-soon", 3, 600, "f3 x-fault: too-soon — 600 s of the window "
                                              "remain: 3 duplicates in 6 min"))
        self.assertEqual(self.read(3, "remaining=1"),
                         ("too-soon", 3, 1, "f3 x-fault: too-soon — 1 s of the window remain"))
        line = checks.read_check("f3", "x-fault", 3, ["remaining=60"], "2026-10-30T12:00:00Z")
        self.assertEqual(line.text(), "f3 x-fault: too-soon — the job's next run is in 60 s "
                                      "(1m), judged since 2026-10-30T12:00:00Z")

    def test_exit_3_without_a_valid_remaining_line(self):
        for lines in ([], ["remaining=0"], ["remaining=10s"], ["remaining= 10"],
                      ["remaining=-5"], ["wait 10 minutes"], ["x", "remaining=60"]):
            with self.subTest(lines=lines):
                verdict, returncode, remaining, text = self.read(3, *lines)
                self.assertEqual((verdict, returncode, remaining), ("error", 3, None))
                self.assertIn("without a first line remaining=<N>", text)

    def test_exit_order(self):
        def result(*verdicts):
            return checks.CheckResult("g", [checks.CheckLine(f"f{i}", "x", v, "r")
                                            for i, v in enumerate(verdicts)]).exit_code
        self.assertEqual(result(), 0)
        self.assertEqual(result("fixed", "fixed"), 0)
        self.assertEqual(result("fixed", "too-soon"), 3)
        self.assertEqual(result("too-soon", "present"), 1)
        self.assertEqual(result("present", "too-soon", "error"), 2)


class TestEvaluationExit(unittest.TestCase):

    def test_check_command_exits_3_when_only_too_soon(self):
        line = checks.CheckLine("f3", "x-fault", "too-soon", "", 3, 120)
        args = argparse.Namespace(command="check", scenario_dir="s", playground="p")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = gm._evaluation(args, lambda d, p: checks.CheckResult("g", [line]))
        self.assertEqual(code, 3)
        self.assertEqual(out.getvalue(), "f3 x-fault: too-soon — 120 s of the window remain\n")


class TestCheckOptions(unittest.TestCase):

    def run_check(self, *argv):
        args = gm.build_parser().parse_args(["check", "s", "--playground", "p", *argv])
        err = io.StringIO()
        with mock.patch.object(checks, "check",
                               return_value=checks.CheckResult("g")) as check, \
                contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            code = args.func(args)
        return code, check, err.getvalue()

    def test_since_and_instance_reach_check(self):
        code, check, _ = self.run_check("--since", "2026-10-30T13:30:00Z", "--instance", "f5",
                                        "--instance", "f6")
        self.assertEqual(code, 0)
        check.assert_called_once_with("s", "p", instances=["f5", "f6"],
                                      since="2026-10-30T13:30:00Z")
        code, check, _ = self.run_check()
        check.assert_called_once_with("s", "p", instances=None, since=None)

    def test_not_with_the_agings_checks(self):
        for argv in (("--early-check", "--since", "2026-10-30T13:30:00Z"),
                     ("--handover-check", "--instance", "f5")):
            with self.subTest(argv=argv):
                code, check, err = self.run_check(*argv)
                self.assertEqual(code, 2)
                self.assertIn("--since and --instance are not for", err)
                check.assert_not_called()


class TestCommandLine(RenderedGame):

    def test_refusals_exit_2(self):
        for command in ("validate", "check"):
            proc = run_gmctl(command, self.scenario, "--playground", "laptop")
            self.assertEqual(proc.returncode, 2, proc.stderr)
            self.assertIn(f"gmctl {command}: game {self.gid} is at stage rendered",
                          proc.stderr)

    def test_incomplete_scenario_exits_2(self):
        (self.scenario / "player" / "story.md").unlink()
        localimpl.set_stage(self.ldir, "deployed")
        proc = run_gmctl("validate", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("player/story.md", proc.stdout)
