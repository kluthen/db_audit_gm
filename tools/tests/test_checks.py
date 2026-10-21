"""gmctl validate and check (tools/gm/checks.py); Docker stubbed."""

import unittest

import yaml

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
        self.replies[FRAGMENTS["f2-check"]] = (3, "", "psql: could not connect\n")
        result = self.check()
        self.assertEqual(result.exit_code, 2)
        self.assertIn("f2 fixture-dropped-index: error — psql: could not connect",
                      result.text())
        self.replies[FRAGMENTS["f2-check"]] = (127, "", "")
        self.assertIn("error — exit status 127, no output", self.check().text())

    def test_check_that_cannot_start_is_an_error(self):
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["sealed_check"].update(run_as="nobody2"))
        self.fake.fail[("exec", "-u", "nobody2")] = "unable to find user nobody2"
        result = self.check()
        self.assertEqual(result.exit_code, 2)
        self.assertIn("f2 fixture-dropped-index: error — the check could not be started",
                      result.text())
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
        with self.assertRaisesRegex(GmError, "check needs stage injected or handed-over"):
            self.check()
        self.assertEqual(self.fake.runs, [])


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
