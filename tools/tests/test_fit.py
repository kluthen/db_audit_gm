"""Capacity check, game id and the local implementation (tools/gm/fit.py)."""

import unittest

import yaml

from tools.gm import deploy, fit, localimpl, model, state, teardown
from tools.tests import INSUFFICIENT, SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl
from tools.tests.test_deploy import RenderedGame
from tools.tests.test_inject import FRAGMENTS
from tools.tests.test_inject import DeployedGame as InjectableGame


class TestGameId(unittest.TestCase):

    def test_format(self):
        gid = localimpl.new_game_id("fixture-audit")
        self.assertRegex(gid, r"^fixture-audit-[a-z0-9]{6}$")

    def test_random(self):
        self.assertNotEqual(localimpl.new_game_id("x"), localimpl.new_game_id("x"))

    def test_long_scenario_id_is_shortened(self):
        gid = localimpl.new_game_id("a" * 80, max_length=63)
        self.assertLessEqual(len(gid), 63)
        self.assertRegex(gid, r"^a+-[a-z0-9]{6}$")
        gid = localimpl.new_game_id("ab-" + "c" * 60, max_length=10)
        self.assertRegex(gid, r"^ab-[a-z0-9]{6}$")


class TestCapacityCheck(unittest.TestCase):

    def setUp(self):
        from tools.tests import FIXTURE_SCENARIO
        self.sc = model.load_scenario(FIXTURE_SCENARIO)

    def test_sufficient(self):
        report = fit.capacity_check(self.sc, {"cpu": 2, "memory": "4G", "disk": "20G"})
        self.assertTrue(report.ok, report.problems)

    def test_insufficient_cpu(self):
        report = fit.capacity_check(self.sc, {"cpu": 0.5, "memory": "4G", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("cpu" in p for p in report.problems))

    def test_node_limit_larger_than_host(self):
        # reservations fit (0.6 + headroom < 0.9) but db's limit (1 CPU) does not
        report = fit.capacity_check(self.sc, {"cpu": 0.9, "memory": "4G", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("db" in p and "limit" in p for p in report.problems))

    def test_headroom_counts(self):
        # 576M reserved: fits 600M without headroom, not with 10 %
        report = fit.capacity_check(self.sc, {"cpu": 2, "memory": "600M", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("memory" in p for p in report.problems))

    def test_never_recomputes(self):
        before = yaml.safe_dump(self.sc.data)
        fit.capacity_check(self.sc, {"cpu": 0.5, "memory": "1G", "disk": "1G"})
        self.assertEqual(before, yaml.safe_dump(self.sc.data))


class TestFit(ScenarioCopyTest):

    def ldir(self, name="laptop"):
        return self.scenario / "local" / name

    def test_fit_accepts_on_sufficient_playground(self):
        result = fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.assertTrue(result.ok)
        ldir = self.ldir()
        pg = yaml.safe_load((ldir / "playground.yaml").read_text())
        self.assertEqual(pg, {"name": "laptop", "platform": "swarm", "docker_endpoint": None,
                              "capacity": {"cpu": 2, "memory": "4G", "disk": "20G"}})
        impl = yaml.safe_load((ldir / "implementation.yaml").read_text())
        gid = impl["game_id"]
        self.assertRegex(gid, r"^fixture-audit-[a-z0-9]{6}$")
        self.assertEqual(impl["scenario"]["id"], "fixture-audit")
        self.assertEqual(impl["stack"], gid)
        self.assertEqual(impl["network"], gid + "_net")
        db = impl["nodes"]["db"]
        self.assertEqual(db["brick"], {"id": "postgres", "version": "0.2.0"})
        self.assertEqual(db["image"], "127.0.0.1:5000/dbagm/postgres:0.2.0")
        self.assertEqual(db["resources"]["limits"], {"cpu": 1, "memory": "1G"})
        self.assertEqual(db["service"], gid + "_db")
        self.assertEqual(db["published_ports"], [])
        bastion = impl["nodes"]["bastion"]
        self.assertEqual(bastion["published_ports"],
                         [{"target": 22, "published": 2222, "mode": "host"}])
        state = yaml.safe_load((ldir / "state.yaml").read_text())
        self.assertEqual(state["game_id"], gid)
        self.assertEqual(state["stage"], "fitted")
        self.assertIsNone(state["failure"])
        self.assertNotIn("teardown", state)
        self.assertEqual([h["stage"] for h in state["history"]], ["fitted"])

    def test_derived_names(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        impl = yaml.safe_load((self.ldir() / "implementation.yaml").read_text())
        gid = impl["game_id"]
        db = impl["nodes"]["db"]
        self.assertEqual([v["name"] for v in db["volumes"]],
                         [f"{gid}_db_{v}" for v in ("pgdata", "pgconf", "home", "gmstate", "run")])
        self.assertEqual(
            [c["name"] for c in db["configs"]],
            [gid + "_db_postgresql.conf", gid + "_db_pg_hba.conf", gid + "_db_envelopes"])
        self.assertEqual(db["configs"][0]["file"], "nodes/db/postgresql.conf")
        self.assertEqual(db["configs"][2]["file"], "local/laptop/envelopes/db.conf")
        self.assertEqual([s["name"] for s in db["secrets"]],
                         [gid + "_player_ssh_pubkey", gid + "_dba_password"])
        bastion = impl["nodes"]["bastion"]
        self.assertEqual([v["name"] for v in bastion["volumes"]],
                         [f"{gid}_bastion_{v}" for v in ("home", "hostkeys", "run")])
        self.assertIn(gid + "_bastion_README.md", [c["name"] for c in bastion["configs"]])
        secrets = {s["name"]: s["file"] for s in impl["secrets"]}
        self.assertEqual(secrets, {
            gid + "_player_password": "local/laptop/secrets/player_password",
            gid + "_player_ssh_key": "local/laptop/secrets/player_ssh_key",
            gid + "_dba_password": "local/laptop/secrets/dba_password",
            gid + "_player_ssh_pubkey": "local/laptop/secrets/player_ssh_key.pub",
        })
        self.assertEqual(impl["labels"], {"com.docker.stack.namespace": gid,
                                          "dbagm.game": gid})
        for name in [c["name"] for n in impl["nodes"].values() for c in n["configs"]] \
                + list(secrets):
            self.assertLessEqual(len(name), 64)
            self.assertRegex(name, r"^[a-zA-Z0-9]+(?:[a-zA-Z0-9-_.]*[a-zA-Z0-9])?$")

    def test_fit_refuses_on_insufficient_playground(self):
        result = fit.fit(self.scenario, "small", **INSUFFICIENT)
        self.assertFalse(result.ok)
        self.assertTrue((self.ldir("small") / "playground.yaml").exists())
        self.assertFalse((self.ldir("small") / "implementation.yaml").exists())

    def test_reuses_declared_playground(self):
        fit.fit(self.scenario, "laptop", endpoint="ssh://gm@host", **SUFFICIENT)
        result = fit.fit(self.scenario, "laptop")
        self.assertTrue(result.ok)
        pg = yaml.safe_load((self.ldir() / "playground.yaml").read_text())
        self.assertEqual(pg["docker_endpoint"], "ssh://gm@host")

    def test_needs_capacity_for_a_new_playground(self):
        with self.assertRaises(model.GmError):
            fit.fit(self.scenario, "laptop")

    def test_refuses_bad_playground_name(self):
        with self.assertRaises(model.GmError):
            fit.fit(self.scenario, "../escape", **SUFFICIENT)

    def test_refuses_incomplete_scenario(self):
        self.edit_yaml("scenario.yaml", lambda d: d.pop("flows"))
        with self.assertRaises(model.IncompleteScenario):
            fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.assertFalse(self.ldir().exists())

    def test_refit_keeps_game_id_before_deploy(self):
        first = fit.fit(self.scenario, "laptop", **SUFFICIENT).game_id
        second = fit.fit(self.scenario, "laptop").game_id
        self.assertEqual(first, second)

    def test_refuses_refit_of_a_deployed_game(self):
        gid = fit.fit(self.scenario, "laptop", **SUFFICIENT).game_id
        localimpl.set_stage(self.ldir(), "rendered")
        localimpl.set_stage(self.ldir(), "deployed")
        with self.assertRaisesRegex(model.GmError,
                                    f"^game {gid} on this playground is at stage deployed: "
                                    "run gmctl teardown, then gmctl fit again; nothing "
                                    "written$"):
            fit.fit(self.scenario, "laptop")

    def test_refit_after_a_torn_down_failure_before_deploy_keeps_the_game_id(self):
        first = fit.fit(self.scenario, "laptop", **SUFFICIENT).game_id
        fit.fit(self.scenario, "laptop", **INSUFFICIENT)
        teardown.teardown(self.scenario, "laptop", reason="too small", docker=FakeDocker())
        st = localimpl.read_state(self.ldir())
        self.assertEqual((st["stage"], st["teardown"]["stage"]), ("failed", "fitted"))
        result = fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.assertEqual(result.game_id, first)
        st = localimpl.read_state(self.ldir())
        self.assertEqual(st["stage"], "fitted")
        self.assertNotIn("teardown", st)        # the game went on: the record is cleared

    def test_failed_capacity_marks_an_existing_game_failed(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        result = fit.fit(self.scenario, "laptop", **INSUFFICIENT)
        self.assertFalse(result.ok)
        state = localimpl.read_state(self.ldir())
        self.assertEqual(state["stage"], "failed")
        self.assertEqual(state["failure"]["stage"], "fitted")


class NewGameChecks:
    """`fit` on a playground whose game failed after deployment (spec D51)."""

    FILES = ("playground.yaml", "implementation.yaml", "state.yaml")

    def files(self):
        return {name: (self.ldir / name).read_bytes() for name in self.FILES}

    def teardown_game(self, **kwargs):
        return teardown.teardown(self.scenario, "laptop", docker=self.fake, sleep=self.sleep,
                                 clock=lambda: self.clock[0], **kwargs)

    def assert_new_game(self):
        proc = run_gmctl("fit", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        impl = localimpl.read_implementation(self.ldir)
        self.assertNotEqual(impl["game_id"], self.gid)
        self.assertRegex(impl["game_id"], r"^fixture-audit-[a-z0-9]{6}$")
        self.assertIn(f"Result: fits. Game id {impl['game_id']}.", proc.stdout)
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["game_id"], impl["game_id"])
        self.assertEqual(st["stage"], "fitted")
        self.assertEqual([h["stage"] for h in st["history"]], ["fitted"])
        self.assertIsNone(st["failure"])
        self.assertNotIn("teardown", st)

    def assert_refused(self, message):
        before = self.files()
        proc = run_gmctl("fit", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 1, proc.stdout)
        self.assertEqual(proc.stderr.strip(), f"gmctl fit: {message}")
        self.assertEqual(self.files(), before)


class TestFitAfterAFailedSetup(NewGameChecks, InjectableGame):

    def fail_load_data(self):
        self.replies["CREATE DATABASE shop"] = (3, "", "ERROR:  boom\n")
        with self.assertRaises(state.SetupFailed):
            self.load_data()

    def fail_inject(self):
        self.load_data()
        self.replies[FRAGMENTS["10-drop-index"]] = (4, "", "psql: error: boom\n")
        with self.assertRaises(state.SetupFailed):
            self.inject()

    def test_new_game_after_a_failed_load_data_torn_down(self):
        self.fail_load_data()
        self.teardown_game(reason="setup failed in load-data")
        self.assertEqual(localimpl.read_state(self.ldir)["teardown"]["stage"], "deployed")
        self.assert_new_game()

    def test_new_game_after_a_failed_inject_torn_down(self):
        self.fail_inject()
        self.teardown_game()
        self.assertEqual(localimpl.read_state(self.ldir)["teardown"]["stage"], "data-loaded")
        self.assert_new_game()

    def test_refuses_a_failed_inject_without_teardown_record(self):
        self.fail_inject()
        self.assert_refused(f"game {self.gid} on this playground failed before stage injected "
                            "and its teardown is not recorded: run gmctl teardown, then gmctl "
                            "fit again; nothing written")

    def test_refuses_a_game_at_a_deployed_stage(self):
        for stage in ("deployed", "data-loaded"):
            with self.subTest(stage=stage):
                if stage == "data-loaded":
                    self.load_data()
                self.assert_refused(f"game {self.gid} on this playground is at stage {stage}: "
                                    "run gmctl teardown, then gmctl fit again; nothing "
                                    "written")


class TestFitAfterAFailedDeploy(NewGameChecks, RenderedGame):

    def setUp(self):
        super().setUp()
        self.fake = FakeDocker(health="unhealthy")
        with self.assertRaises(state.SetupFailed):
            self.deploy(self.fake, timeout=10)

    def test_refused_until_torn_down_and_names_the_retry(self):
        self.assert_refused(f"game {self.gid} on this playground failed before stage deployed "
                            "and its teardown is not recorded: run gmctl teardown, then gmctl "
                            "fit again, or run gmctl deploy to retry the deploy; nothing "
                            "written")

    def test_new_game_once_torn_down_and_deploy_still_retries(self):
        self.teardown_game()
        self.assertTrue(deploy.deployable(localimpl.read_state(self.ldir)))
        self.assert_new_game()


class TestGmctlFit(ScenarioCopyTest):

    def test_cli_accepts(self):
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("fits", r.stdout)
        self.assertRegex(r.stdout, r"fixture-audit-[a-z0-9]{6}")

    def test_cli_refuses_insufficient(self):
        r = run_gmctl("fit", self.scenario, "--playground", "small",
                      "--cpu", "0.5", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1)
        self.assertIn("does not fit", r.stdout + r.stderr)

    def test_cli_lists_missing_items(self):
        self.edit_yaml("scenario.yaml", lambda d: (d.pop("flows"), d.pop("title")))
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1)
        out = r.stdout + r.stderr
        self.assertIn("incomplete", out)
        self.assertIn("flows", out)
        self.assertIn("title", out)


if __name__ == "__main__":
    unittest.main()
