"""Capacity check, game id and the local implementation (tools/gm/fit.py)."""

import unittest
from unittest import mock

import yaml

from tools.gm import deploy, docker, fit, localimpl, model, state, teardown
from tools.tests import (BASE_LAYER, INSUFFICIENT, OWN_LAYER_SIZE, SUFFICIENT, UNREACHABLE,
                         FakeDocker, ScenarioCopyTest, own_layer, run_gmctl)
from tools.tests.test_deploy import RenderedGame
from tools.tests.test_inject import FRAGMENTS
from tools.tests.test_inject import DeployedGame as InjectableGame
from tools.tests.test_render import (MANAGER, VPS_ENDPOINT, WORKER, MountedCopyTest,
                                     TwoHostScenario, two_host_engine, two_hosts)


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


POSTGRES = "127.0.0.1:5000/dbagm/postgres:0.3.0"
BASTION = "127.0.0.1:5000/dbagm/bastion:0.3.0"
M = 1024 ** 2
# the fixture's two images on the default fake engine: the shared base once
FIXTURE_IMAGES = BASE_LAYER[1] + 2 * OWN_LAYER_SIZE         # 278M


def footprint(size=0):
    return fit.ImageFootprint(engine="local engine", images=[], size=size, layers=0, shared=0)


class TestCapacityCheck(unittest.TestCase):

    def setUp(self):
        from tools.tests import FIXTURE_SCENARIO
        self.sc = model.load_scenario(FIXTURE_SCENARIO)

    def capacity_check(self, capacity, images=None):
        return fit.capacity_check(self.sc, capacity, images or footprint())

    def test_sufficient(self):
        report = self.capacity_check({"cpu": 2, "memory": "4G", "disk": "20G"})
        self.assertTrue(report.ok, report.problems)

    def test_insufficient_cpu(self):
        report = self.capacity_check({"cpu": 0.5, "memory": "4G", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("cpu" in p for p in report.problems))

    def test_node_limit_larger_than_host(self):
        # reservations fit (0.6 + headroom < 0.9) but db's limit (1 CPU) does not
        report = self.capacity_check({"cpu": 0.9, "memory": "4G", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("db" in p and "limit" in p for p in report.problems))

    def test_headroom_counts(self):
        # 576M reserved: fits 600M without headroom, not with 10 %
        report = self.capacity_check({"cpu": 2, "memory": "600M", "disk": "20G"})
        self.assertFalse(report.ok)
        self.assertTrue(any("memory" in p for p in report.problems))

    def test_never_recomputes(self):
        before = yaml.safe_dump(self.sc.data)
        self.capacity_check({"cpu": 0.5, "memory": "1G", "disk": "1G"})
        self.assertEqual(before, yaml.safe_dump(self.sc.data))

    def test_images_count_in_the_disk(self):
        # 2.25G reserved and 132M of growth (33M/h, four hours): 2850M holds them with 10 %
        # headroom (2721M), not with 278M of images
        cap = {"cpu": 2, "memory": "4G", "disk": "2850M"}
        self.assertTrue(self.capacity_check(cap).ok)
        report = self.capacity_check(cap, footprint(FIXTURE_IMAGES))
        self.assertFalse(report.ok)
        self.assertEqual(report.problems, ["disk: reservations 2.25G + images 278M + growth "
                                           "132M (4h) + headroom 285M = 2.93G of 2.78G: too "
                                           "much"])
        cap["disk"] = "3100M"           # 2304M + 278M + 132M + 310M = 3024M
        self.assertTrue(self.capacity_check(cap, footprint(FIXTURE_IMAGES)).ok)

    def test_report_lines(self):
        images = fit.image_footprint(self.sc, FakeDocker())
        report = fit.capacity_check(self.sc, {"cpu": 2, "memory": "4G", "disk": "20G"}, images)
        self.assertEqual(report.lines, [
            "cpu: reservations 0.6 + headroom 0.2 = 0.8 of 2: ok",
            "memory: reservations 576M + headroom 409.6M = 985.6M of 4G: ok",
            f"images on local engine: {BASTION} 178M, {POSTGRES} 178M; 3 layers, 1 shared, "
            "each counted once: 278M",
            "disk: reservations 2.25G + images 278M + growth 132M (4h) + headroom 2G = 4.65G "
            "of 20G: ok",
            "node bastion: limits cpu 0.25 ok, memory 128M ok",
            "node db: limits cpu 1 ok, memory 1G ok",
            "snapshot: copies 2.25G (reservations 2.25G, no aging) after the game's 4.65G = "
            "6.9G of 20G: fits",
        ])


class TestImageFootprint(unittest.TestCase):
    """The images read from the engine (master spec 8, spec D102)."""

    def setUp(self):
        from tools.tests import FIXTURE_SCENARIO
        self.sc = model.load_scenario(FIXTURE_SCENARIO)

    def test_a_shared_layer_counts_once(self):
        fp = fit.image_footprint(self.sc, FakeDocker())
        self.assertEqual([im.name for im in fp.images], [BASTION, POSTGRES])
        self.assertEqual([im.size for im in fp.images], [178 * M, 178 * M])
        self.assertEqual((fp.size, fp.layers, fp.shared), (FIXTURE_IMAGES, 3, 1))

    def test_layers_are_told_apart_by_chain_id(self):
        # the same diff on another base is another layer; a common stack is shared
        s6 = ("sha256:" + "5" * 64, 1 * M)
        other_base = ("sha256:" + "e" * 64, 50 * M)
        engine = FakeDocker(images={
            POSTGRES: [BASE_LAYER, s6, own_layer(POSTGRES)],
            BASTION: [other_base, s6, own_layer(BASTION)]})
        fp = fit.image_footprint(self.sc, engine)
        self.assertEqual((fp.layers, fp.shared), (6, 0))
        self.assertEqual(fp.size, 78 * M + 50 * M + 2 * M + 2 * OWN_LAYER_SIZE)
        engine.images[BASTION] = [BASE_LAYER, s6, own_layer(BASTION)]
        fp = fit.image_footprint(self.sc, engine)
        self.assertEqual((fp.layers, fp.shared), (4, 2))
        self.assertEqual(fp.size, 78 * M + 1 * M + 2 * OWN_LAYER_SIZE)

    def test_an_image_whose_layers_cannot_be_sized_counts_whole(self):
        # a layer of size 0: history's non-empty rows no longer match the layers
        engine = FakeDocker(images={
            POSTGRES: [BASE_LAYER, ("sha256:" + "0" * 64, 0), own_layer(POSTGRES)],
            BASTION: [BASE_LAYER, own_layer(BASTION)]})
        fp = fit.image_footprint(self.sc, engine)
        self.assertEqual(fp.images[1].layers, [])
        self.assertEqual(fp.size, 2 * (78 * M + OWN_LAYER_SIZE))
        self.assertEqual((fp.layers, fp.shared), (3, 0))

    def test_reads_through_the_endpoint(self):
        engine = FakeDocker(endpoint="ssh://gm@host")
        fp = fit.image_footprint(self.sc, engine)
        self.assertEqual(fp.engine, "ssh://gm@host")
        self.assertIn(["image", "inspect", "--format", "{{json .}}", POSTGRES], engine.calls)
        self.assertEqual(len(engine.called("history")), 2)
        self.assertEqual(engine.command(["version"]), ["docker", "-H", "ssh://gm@host",
                                                        "version"])

    def test_a_missing_image_is_refused_with_its_build_command(self):
        with self.assertRaises(model.GmError) as caught:
            fit.image_footprint(self.sc, FakeDocker(missing=[POSTGRES]))
        self.assertEqual(str(caught.exception),
                         f"image(s) not on local engine: {POSTGRES} (build it: docker build -t "
                         f"{POSTGRES} bricks/postgres); then gmctl fit again; nothing written")

    def test_missing_images_on_an_endpoint_name_the_endpoint(self):
        with self.assertRaises(model.GmError) as caught:
            fit.image_footprint(self.sc, FakeDocker(images=False, endpoint="ssh://gm@host"))
        self.assertEqual(str(caught.exception),
                         "image(s) not on ssh://gm@host: "
                         f"{BASTION} (build it: docker -H ssh://gm@host build -t {BASTION} "
                         f"bricks/bastion); {POSTGRES} (build it: docker -H ssh://gm@host build "
                         f"-t {POSTGRES} bricks/postgres); then gmctl fit again; nothing written")

    def test_an_unreachable_engine_is_reported(self):
        engine = FakeDocker(reachable=False)
        with self.assertRaises(model.GmError) as caught:
            fit.image_footprint(self.sc, engine)
        self.assertEqual(str(caught.exception),
                         f"the engine local engine is not reachable: {UNREACHABLE}. fit reads "
                         "the images' sizes from the playground's engine: start it or correct "
                         "the endpoint (--endpoint), then gmctl fit again; nothing written")
        self.assertEqual(engine.calls, [["version", "--format", "{{.Server.Version}}"]])

    def test_chain_ids(self):
        self.assertEqual(docker.chain_ids([]), [])
        a, b = "sha256:" + "a" * 64, "sha256:" + "b" * 64
        import hashlib
        self.assertEqual(docker.chain_ids([a, b]),
                         [a, "sha256:" + hashlib.sha256(f"{a} {b}".encode()).hexdigest()])


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
        self.assertEqual(impl["network"], gid + "_backend")   # the scenario's network
        db = impl["nodes"]["db"]
        self.assertEqual(db["brick"], {"id": "postgres", "version": "0.3.0"})
        self.assertEqual(db["image"], "127.0.0.1:5000/dbagm/postgres:0.3.0")
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
                         [f"{gid}_db_{v}" for v in ("pgdata", "pgconf", "home", "gmstate", "pglog",
                                                     "run")])
        self.assertEqual(
            [c["name"] for c in db["configs"]],
            [gid + "_db_postgresql.conf", gid + "_db_pg_hba.conf", gid + "_db_envelopes"])
        self.assertEqual(db["configs"][0]["file"], "nodes/db/postgresql.conf")
        self.assertEqual(db["configs"][2]["file"], "local/laptop/envelopes/db.conf")
        self.assertEqual([s["name"] for s in db["secrets"]],
                         [gid + "_player_ssh_pubkey", gid + "_dba_password",
                          gid + "_monitoring_password", gid + "_gm_check_password"])
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
            gid + "_monitoring_password": "local/laptop/secrets/monitoring_password",
            gid + "_gm_check_password": "local/laptop/secrets/gm_check_password",
            gid + "_tools_password": "local/laptop/secrets/tools_password",
        })
        self.assertEqual(impl["labels"], {"com.docker.stack.namespace": gid,
                                          "dbagm.game": gid})
        for name in [c["name"] for n in impl["nodes"].values() for c in n["configs"]] \
                + list(secrets):
            self.assertLessEqual(len(name), 64)
            self.assertRegex(name, r"^[a-zA-Z0-9]+(?:[a-zA-Z0-9-_.]*[a-zA-Z0-9])?$")

    def test_fit_counts_the_images(self):
        result = fit.fit(self.scenario, "laptop", **SUFFICIENT)
        text = result.text()
        self.assertIn(f"  images on local engine: {BASTION} 178M, {POSTGRES} 178M; 3 layers, "
                      "1 shared, each counted once: 278M\n", text)
        self.assertIn("  disk: reservations 2.25G + images 278M + growth 132M (4h) + headroom "
                      "2G = 4.65G of 20G: ok\n", text)

    def test_fit_refuses_when_the_images_overflow_the_disk(self):
        result = fit.fit(self.scenario, "laptop", cpu="2", memory="4G", disk="2850M")
        self.assertFalse(result.ok)
        self.assertEqual(result.report.problems,
                         ["disk: reservations 2.25G + images 278M + growth 132M (4h) + headroom "
                          "285M = 2.93G of 2.78G: too much"])
        self.assertIn("Result: does not fit; nothing deployed.", result.text())
        self.assertFalse((self.ldir() / "implementation.yaml").exists())

    def test_fit_reads_the_declared_endpoints_engine(self):
        fit.fit(self.scenario, "laptop", endpoint="ssh://gm@host", **SUFFICIENT)
        result = fit.fit(self.scenario, "laptop")
        self.assertTrue(result.report.lines[2].startswith("images on ssh://gm@host: "))
        engine = FakeDocker(endpoint="ssh://other@host")
        result = fit.fit(self.scenario, "laptop", docker=engine)
        self.assertTrue(result.report.lines[2].startswith("images on ssh://other@host: "))
        self.assertTrue(engine.called("image", "inspect"))

    def test_engine_refusals_write_nothing(self):
        for engine in (FakeDocker(missing=[POSTGRES]), FakeDocker(reachable=False)):
            with self.subTest(reachable=engine.reachable):
                with self.assertRaises(model.GmError):
                    fit.fit(self.scenario, "laptop", docker=engine, **SUFFICIENT)
                self.assertFalse(self.ldir().exists())

    def test_engine_refusals_leave_a_fitted_game_as_it_is(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        files = {n: (self.ldir() / n).read_bytes()
                 for n in ("playground.yaml", "implementation.yaml", "state.yaml")}
        for engine in (FakeDocker(missing=[BASTION]), FakeDocker(reachable=False)):
            with self.subTest(reachable=engine.reachable):
                with self.assertRaises(model.GmError):
                    fit.fit(self.scenario, "laptop", docker=engine, disk="30G")
                self.assertEqual({n: (self.ldir() / n).read_bytes() for n in files}, files)

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


class TestTwoHosts(TwoHostScenario):

    def test_the_declaration_and_the_mapping(self):
        result = self.fit()
        self.assertTrue(result.ok, result.report.problems)
        pg = yaml.safe_load((self.ldir / "playground.yaml").read_text())
        self.assertEqual(pg, {
            "name": "duo", "platform": "swarm",
            "hosts": [{"name": MANAGER, "docker_endpoint": None, "manager": True,
                       "capacity": {"cpu": 2, "memory": "4G", "disk": "20G"}},
                      {"name": WORKER, "docker_endpoint": VPS_ENDPOINT, "manager": False,
                       "capacity": {"cpu": 2, "memory": "4G", "disk": "20G"}}],
            "mapping": {"host-1": MANAGER, "host-2": WORKER}})
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual({n: node["host"] for n, node in impl["nodes"].items()},
                         {"bastion": MANAGER, "db": WORKER})
        self.assertEqual(impl["snapshot_fit"], {"fits": True, "why": None})
        text = result.text()
        self.assertIn(f"  mapping: host-1 -> {MANAGER}, host-2 -> {WORKER}\n", text)
        self.assertIn(f"  host {MANAGER} (manager, local engine): nodes bastion\n", text)
        self.assertIn(f"  host {WORKER} ({VPS_ENDPOINT}): nodes db\n", text)

    def test_a_refit_reuses_the_declaration_and_map_alone_replaces_the_mapping(self):
        self.fit()
        result = fit.fit(self.scenario, "duo", docker=two_host_engine())
        self.assertTrue(result.ok)
        result = fit.fit(self.scenario, "duo", docker=two_host_engine(),
                         mapping=["host-1=" + MANAGER, "host-2=" + MANAGER])
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual({node["host"] for node in impl["nodes"].values()}, {MANAGER})
        self.assertEqual(len(localimpl.read_playground(self.ldir)["hosts"]), 2)

    def test_each_host_counts_only_its_nodes_and_their_images(self):
        result = self.fit()
        lines = result.report.lines
        self.assertIn(f"  images on {MANAGER}: {BASTION} 178M; 2 layers, 0 shared, each counted "
                      "once: 178M", lines)
        self.assertIn(f"  images on {WORKER}: {POSTGRES} 178M; 2 layers, 0 shared, each counted "
                      "once: 178M", lines)
        # the bastion's 0.1 CPU on the manager, the database's 0.5 on the VPS
        self.assertIn("  cpu: reservations 0.1 + headroom 0.2 = 0.3 of 2: ok", lines)
        self.assertIn("  cpu: reservations 0.5 + headroom 0.2 = 0.7 of 2: ok", lines)

    def test_a_host_short_of_memory_is_refused(self):
        # db's limit is 1G and it reserves 512M: the VPS at 1000M holds neither
        result = self.fit(hosts=two_hosts(worker_memory="1000M"))
        self.assertFalse(result.ok)
        self.assertTrue(result.report.problems)
        self.assertTrue(all(p.startswith(f"host {WORKER}: ") for p in result.report.problems),
                        result.report.problems)
        self.assertIn(f"host {WORKER}: node db: memory limit 1G is more than the host's "
                      "1000M", result.report.problems)
        self.assertFalse((self.ldir / "implementation.yaml").exists())

    def test_a_host_short_of_disk_is_refused(self):
        # db: 2G reserved, 178M of images, 128M of growth (32M/h, four hours)
        result = self.fit(hosts=two_hosts(worker_disk="2.5G"))
        self.assertFalse(result.ok)
        self.assertEqual(result.report.problems,
                         [f"host {WORKER}: disk: reservations 2G + images 178M + growth 128M "
                          "(4h) + headroom 256M = 2.55G of 2.5G: too much"])

    def test_the_snapshot_that_does_not_fit_is_said_and_recorded(self):
        # the game holds on 3G (2G + 178M + 128M + 307.2M) but not its 2G of copies too
        result = self.fit(hosts=two_hosts(worker_disk="3G"))
        self.assertTrue(result.ok, result.report.problems)
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual(impl["snapshot_fit"], {
            "fits": False,
            "why": f"host {WORKER}: snapshot: copies 2G (reservations 2G, no aging) after the "
                   "game's 2.6G = 4.6G of 3G: does not fit"})
        self.assertIn("The hand-over snapshot does not fit (host " + WORKER, result.text())
        self.assertIn("this game will have no snapshot", result.text())

    def test_refusals_write_nothing(self):
        self.refused("2 hosts flagged manager", hosts=[
            f"{MANAGER},manager,cpu=2,memory=4G,disk=20G",
            f"{WORKER},manager,cpu=2,memory=4G,disk=20G"])
        self.refused("0 hosts flagged manager", hosts=[
            f"{MANAGER},cpu=2,memory=4G,disk=20G", f"{WORKER},cpu=2,memory=4G,disk=20G"])
        self.refused("designed host host-2 is not mapped", mapping=["host-1=" + MANAGER])
        self.refused("host-3 is not a designed host of scenario fixture-audit",
                     mapping=["host-1=" + MANAGER, "host-2=" + WORKER, "host-3=" + WORKER])
        self.refused("elsewhere is not a declared host",
                     mapping=["host-1=" + MANAGER, "host-2=elsewhere"])
        self.refused(f"host {WORKER} declared twice", hosts=two_hosts() + [two_hosts()[1]])
        self.refused("give its disk=", hosts=[f"{MANAGER},manager,cpu=2,memory=4G"])
        self.refused("expected manager or one of", hosts=[f"{MANAGER},manager,ram=4G"])

    def test_published_ports_off_the_manager_are_refused(self):
        # the bastion publishes 2222: on the VPS it would listen on its public address
        self.refused(rf"node bastion publishes ports and would be placed on {WORKER}, not the "
                     rf"manager {MANAGER}: .*map host-1 onto {MANAGER} \(--map "
                     rf"host-1={MANAGER}\)",
                     mapping=["host-1=" + WORKER, "host-2=" + MANAGER])

    def test_hosts_checked_against_the_swarm(self):
        self.refused(rf"host {WORKER} is not a node of the swarm \({MANAGER}\)",
                     engine=FakeDocker(name=MANAGER))
        workers = FakeDocker(name=MANAGER, nodes={MANAGER: ("Ready", "Active", ""),
                                                  WORKER: ("Ready", "Active", "")})
        self.refused(f"host {MANAGER} is flagged manager but is a worker", engine=workers)
        self.refused("cannot list the swarm's nodes", engine=two_host_engine(swarm=("active",
                                                                                     False)))

    def test_the_one_host_options_are_refused_with_several(self):
        self.refused("are the one-host form's: give each host's in its --host", cpu="2")
        self.fit()
        with self.assertRaisesRegex(model.GmError, "declares 2 hosts: --endpoint, --cpu"):
            fit.fit(self.scenario, "duo", docker=two_host_engine(), memory="8G")

    def test_several_designed_hosts_may_share_a_host_and_a_host_may_get_none(self):
        result = self.fit(mapping=("host-1=" + MANAGER, "host-2=" + MANAGER))
        self.assertTrue(result.ok, result.report.problems)
        self.assertIn(f"host {WORKER} ({VPS_ENDPOINT}): nodes none", result.report.lines)
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual({node["host"] for node in impl["nodes"].values()}, {MANAGER})


class TestOneHost(ScenarioCopyTest):

    def test_todays_form_places_every_node_on_the_engine(self):
        fit.fit(self.scenario, "laptop", docker=FakeDocker(name="laptop-host"), **SUFFICIENT)
        ldir = self.scenario / "local" / "laptop"
        impl = localimpl.read_implementation(ldir)
        self.assertEqual({node["host"] for node in impl["nodes"].values()}, {"laptop-host"})
        self.assertNotIn("hosts", localimpl.read_playground(ldir))      # never rewritten
        self.assertEqual(impl["snapshot_fit"], {"fits": True, "why": None})

    def test_a_list_of_one_must_name_the_engine(self):
        hosts = ["laptop-host,manager,cpu=2,memory=4G,disk=20G"]
        with self.assertRaisesRegex(model.GmError, "host laptop-host is declared, but the "
                                                   "engine local engine is gm-host"):
            fit.fit(self.scenario, "laptop", hosts=hosts)
        result = fit.fit(self.scenario, "laptop", hosts=hosts,
                         docker=FakeDocker(name="laptop-host"))
        self.assertTrue(result.ok)
        # one host: the mapping is implied, and --cpu updates it
        result = fit.fit(self.scenario, "laptop", disk="30G",
                         docker=FakeDocker(name="laptop-host"))
        pg = localimpl.read_playground(self.scenario / "local" / "laptop")
        self.assertEqual(pg["hosts"][0]["capacity"]["disk"], "30G")

    def test_growth_counts_over_the_aging_and_the_game(self):
        sc = model.load_scenario(self.scenario)
        with mock.patch("tools.gm.fit.aging_seconds", return_value=8 * 3600):
            report = fit.capacity_check(sc, {"cpu": 2, "memory": "4G", "disk": "20G"},
                                        footprint())
        # 33M an hour over 8h of aging and 4h of game; the copies hold the aging's 264M
        self.assertIn("disk: reservations 2.25G + images 0B + growth 396M (12h) + headroom 2G "
                      "= 4.64G of 20G: ok", report.lines)
        self.assertEqual(report.lines[-1],
                         "snapshot: copies 2.51G (reservations 2.25G + growth 264M over 8h of "
                         "aging) after the game's 4.64G = 7.14G of 20G: fits")


class TestGmctlFit(ScenarioCopyTest):

    def test_cli_accepts(self):
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("fits", r.stdout)
        self.assertRegex(r.stdout, r"fixture-audit-[a-z0-9]{6}")

    def test_cli_declares_hosts(self):
        r = run_gmctl("fit", self.scenario, "--playground", "solo",
                      "--host", "gm-host,manager,cpu=2,memory=4G,disk=20G", "--map",
                      "host-1=gm-host")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("  host gm-host (manager): local engine, capacity cpu 2, memory 4G, "
                      "disk 20G\n", r.stdout)
        r = run_gmctl("fit", self.scenario, "--playground", "solo", "--host",
                      "gm-host,manager,cpu=2,memory=4G,disk=20G", "--cpu", "4")
        self.assertEqual(r.returncode, 1)
        self.assertIn("are the one-host form's", r.stderr)

    def test_cli_refuses_insufficient(self):
        r = run_gmctl("fit", self.scenario, "--playground", "small",
                      "--cpu", "0.5", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1)
        self.assertIn("does not fit", r.stdout + r.stderr)

    def test_cli_refuses_a_missing_image(self):
        self.fake_engine(missing=[POSTGRES])
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertEqual(r.stderr.strip(),
                         f"gmctl fit: image(s) not on local engine: {POSTGRES} (build it: docker "
                         f"build -t {POSTGRES} bricks/postgres); then gmctl fit again; nothing "
                         "written")
        self.assertFalse((self.scenario / "local").exists())

    def test_cli_reports_an_unreachable_engine(self):
        self.fake_engine(unreachable=True)
        r = run_gmctl("fit", self.scenario, "--playground", "laptop", "--endpoint",
                      "ssh://gm@host", "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1, r.stdout)
        self.assertEqual(r.stderr.strip(),
                         f"gmctl fit: the engine ssh://gm@host is not reachable: {UNREACHABLE}. "
                         "fit reads the images' sizes from the playground's engine: start it or "
                         "correct the endpoint (--endpoint), then gmctl fit again; nothing "
                         "written")

    def test_cli_lists_missing_items(self):
        self.edit_yaml("scenario.yaml", lambda d: (d.pop("flows"), d.pop("title")))
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1)
        out = r.stdout + r.stderr
        self.assertIn("incomplete", out)
        self.assertIn("flows", out)
        self.assertIn("title", out)


class TestFitMounted(MountedCopyTest):
    """fit on fixture-mounted: the mounted configs' names bound the game id,
    and the parameter faults are applied (capture W1, items 4 and 8)."""

    def test_game_id_leaves_room_for_mounted_names(self):
        sc = model.load_scenario(self.scenario)
        # longest derived part: _monitor_node-health.conf (25 characters)
        self.assertEqual(localimpl.max_game_id_length(sc), 64 - 25)
        result = fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.assertLessEqual(len(result.game_id), 64 - 25)

    def test_a_parameter_fault_planting_nothing_is_refused(self):
        self.edit_yaml("faults/fixture-node-left-out/fault.yaml",
                       lambda d: d["injection"]["parameter_changes"].append(
                           dict(d["injection"]["parameter_changes"][0])))
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 1)
        self.assertIn("fault instance f2 (fixture-node-left-out): remove-entry node_health: "
                      "node_health has no entry app", r.stderr)
        self.assertFalse((self.scenario / "local" / "laptop" / "implementation.yaml").exists())


if __name__ == "__main__":
    unittest.main()
