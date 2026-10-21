"""gmctl teardown, exec and logs (tools/gm/teardown.py, tools/gm/execnode.py),
and the teardown of a failed setup; Docker stubbed."""

from tools.gm import build_parser, execnode, fit, localimpl, state, teardown
from tools.gm.model import GmError
from tools.tests import SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl
from tools.tests.test_deploy import RenderedGame


class DeployedGame(RenderedGame):

    def setUp(self):
        super().setUp()
        self.fake = FakeDocker()
        # What else lives on the host: never touched by this game's teardown.
        other = {"com.docker.stack.namespace": "other-game-abc123",
                 "dbagm.game": "other-game-abc123"}
        self.fake.add("service", "registry")
        self.fake.add("volume", "registry-data")
        self.fake.add("volume", "unrelated")
        self.fake.add("service", "other-game-abc123_db", other)
        self.fake.add("volume", "other-game-abc123_db_pgdata", other)
        self.fake.add("config", "other-game-abc123_db_envelopes", other)
        self.fake.add("secret", "other-game-abc123_dba_password", other)
        self.fake.add("network", "ingress")
        # A game whose id extends this one's: label values must match exactly.
        longer = f"{self.gid}x"
        self.fake.add("config", f"{longer}_db_envelopes", {"dbagm.game": longer})
        self.untouched = {kind: dict(objs) for kind, objs in self.fake.objects.items()}
        self.deploy(self.fake)

    def teardown(self, **kwargs):
        return teardown.teardown(self.scenario, "laptop", docker=self.fake, sleep=self.sleep,
                                 clock=lambda: self.clock[0], **kwargs)


class TestTeardown(DeployedGame):

    def test_removes_only_the_games_objects(self):
        self.assertTrue(teardown.leftovers(self.fake, self.gid))
        self.fake.calls.clear()
        report = self.teardown()
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})
        self.assertEqual(self.fake.objects, self.untouched)
        self.assertEqual(len(report.removed["service"]), 2)
        self.assertEqual(len(report.removed["volume"]), 7)
        self.assertEqual(len(report.removed["config"]), 6)
        self.assertEqual(len(report.removed["secret"]), 4)
        self.assertEqual(report.removed["network"], [f"{self.gid}_net"])
        self.assertIn("nothing carrying its label is left", report.text())
        # Every rm names an object listed by one of the game's labels.
        for call in self.fake.calls:
            if len(call) > 1 and call[1] == "rm":
                self.assertTrue(call[2].startswith(f"{self.gid}_"), call)
        # Images and the swarm are left alone.
        self.assertFalse([c for c in self.fake.calls
                          if c[0] in ("image", "rmi", "swarm", "stack")])

    def test_services_go_first(self):
        self.teardown()
        rms = [c[0] for c in self.fake.calls if len(c) > 1 and c[1] == "rm"]
        self.assertEqual(set(rms[:2]), {"service"})
        self.assertEqual(rms[-1], "volume")

    def test_stage_and_idempotence(self):
        self.teardown()
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "torn-down")
        report = self.teardown()
        self.assertEqual(report.count(), 0)
        self.assertIn("nothing carrying its label was left", report.text())
        self.assertEqual([h["stage"] for h in localimpl.read_state(self.ldir)["history"]],
                         ["fitted", "rendered", "deployed", "torn-down"])

    def test_object_that_will_not_go_is_reported(self):
        self.fake.fail[("volume", "rm")] = "volume is in use"
        with self.assertRaisesRegex(GmError, "left objects after 5 s: volumes: "):
            self.teardown(timeout=5)
        self.assertNotEqual(localimpl.read_state(self.ldir)["stage"], "torn-down")

    def test_invalid_game_id_removes_nothing(self):
        for bad in ("", "Bad_Id", None, "a" * 64):
            with self.assertRaises(GmError):
                teardown.remove_game_objects(self.fake, bad)
        self.assertFalse([c for c in self.fake.calls if len(c) > 1 and c[1] == "rm"])


class TestTeardownRecord(DeployedGame):
    """The teardown record and `--reason` (spec D50)."""

    def to_injected(self):
        for stage in ("data-loaded", "injected"):
            localimpl.set_stage(self.ldir, stage)

    def state_bytes(self):
        return (self.ldir / "state.yaml").read_bytes()

    def test_reason_recorded_at_injected(self):
        self.to_injected()
        report = self.teardown(reason="stopped on request")
        self.assertEqual(teardown.leftovers(self.fake, self.gid), {})
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "torn-down")
        self.assertEqual(st["history"][-1]["stage"], "torn-down")
        self.assertIsNone(st["failure"])
        record = st["teardown"]
        self.assertEqual(set(record), {"stage", "reason", "at"})
        self.assertEqual(record["stage"], "injected")
        self.assertEqual(record["reason"], "stopped on request")
        self.assertEqual(record["at"], st["history"][-1]["at"])
        self.assertIn(f"Recorded in state.yaml: torn down at {record['at']}, from stage "
                      "injected: stopped on request.", report.text())
        self.assertIn(f"  torn down: at {record['at']}, from stage injected: "
                      "stopped on request", state.status_text(self.ldir))

    def test_reason_collapsed_to_one_line(self):
        self.teardown(reason="  stopped\n on   request \t")
        self.assertEqual(localimpl.read_state(self.ldir)["teardown"]["reason"],
                         "stopped on request")

    def test_without_reason(self):
        self.teardown()
        record = localimpl.read_state(self.ldir)["teardown"]
        self.assertIsNone(record["reason"])
        self.assertEqual(record["stage"], "deployed")
        self.assertIn("  torn down: at ", state.status_text(self.ldir))
        self.assertIn("from stage deployed: no reason given", state.status_text(self.ldir))

    def test_empty_reason_refused(self):
        before = self.state_bytes()
        for empty in ("", "   ", " \n\t "):
            with self.subTest(reason=empty):
                with self.assertRaisesRegex(GmError, "--reason is empty.*nothing removed"):
                    self.teardown(reason=empty)
        self.assertFalse(self.fake.called("service", "rm"))
        self.assertTrue(teardown.leftovers(self.fake, self.gid))
        self.assertEqual(self.state_bytes(), before)
        proc = run_gmctl("teardown", self.scenario, "--playground", "laptop", "--reason", " ")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("gmctl teardown: --reason is empty", proc.stderr)
        self.assertEqual(self.state_bytes(), before)

    def test_leftovers_record_nothing(self):
        self.fake.fail[("volume", "rm")] = "volume is in use"
        before = localimpl.read_state(self.ldir)
        with self.assertRaises(GmError):
            self.teardown(reason="stopped on request", timeout=5)
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st, before)
        self.assertNotIn("teardown", st)

    def test_second_teardown_leaves_the_record(self):
        self.to_injected()
        self.teardown(reason="stopped on request")
        before = self.state_bytes()
        report = self.teardown(reason="another reason")
        self.assertEqual(self.state_bytes(), before)
        self.assertIsNone(report.recorded)
        self.assertIn("The teardown was already recorded (torn down at ", report.text())
        self.assertIn("from stage injected: stopped on request): left unchanged, "
                      "the reason given is not recorded.", report.text())
        report = self.teardown()
        self.assertEqual(self.state_bytes(), before)
        self.assertNotIn("already recorded", report.text())

    def test_already_torn_down_without_record(self):
        # A game torn down before the record existed: nothing written.
        localimpl.set_stage(self.ldir, "torn-down")
        before = self.state_bytes()
        report = self.teardown(reason="late")
        self.assertEqual(self.state_bytes(), before)
        self.assertIn("The teardown was already recorded: left unchanged", report.text())

    def test_failed_game_keeps_its_failure(self):
        localimpl.set_stage(self.ldir, "data-loaded")
        localimpl.set_failed(self.ldir, "injected", "boom")
        failed = localimpl.read_state(self.ldir)
        self.teardown(reason="setup failed")
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"], failed["failure"])
        self.assertEqual(st["history"], failed["history"])     # no history entry
        self.assertEqual(st["teardown"]["stage"], "data-loaded")
        self.assertEqual(st["teardown"]["reason"], "setup failed")
        text = state.status_text(self.ldir)
        self.assertIn("stage: failed (last stage reached: data-loaded)", text)
        self.assertIn("failure: before stage injected", text)
        self.assertIn("from stage data-loaded: setup failed", text)

    def test_a_later_stage_or_failure_clears_the_record(self):
        # A failed deploy, torn down, then retried: the record is the old game's.
        localimpl.set_failed(self.ldir, "deployed", "boom")
        self.teardown()
        self.assertTrue(localimpl.teardown_record(localimpl.read_state(self.ldir)))
        localimpl.set_stage(self.ldir, "deployed")
        self.assertNotIn("teardown", localimpl.read_state(self.ldir))
        localimpl.set_failed(self.ldir, "deployed", "boom")
        self.teardown()
        localimpl.set_failed(self.ldir, "deployed", "boom again")
        self.assertNotIn("teardown", localimpl.read_state(self.ldir))

    def test_a_state_without_the_key_has_no_record(self):
        self.assertIsNone(localimpl.teardown_record({"stage": "fitted"}))
        self.assertIsNone(localimpl.teardown_record(None))
        self.assertNotIn("teardown", localimpl.read_state(self.ldir))
        self.assertNotIn("torn down:", state.status_text(self.ldir))

    def test_parser(self):
        args = build_parser().parse_args(["teardown", "x", "--playground", "p",
                                          "--reason", "stopped on request"])
        self.assertEqual(args.reason, "stopped on request")
        self.assertIsNone(build_parser().parse_args(
            ["teardown", "x", "--playground", "p"]).reason)


class TestTeardownBeforeDeployment(ScenarioCopyTest):

    def test_fitted(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        ldir = self.scenario / "local" / "laptop"
        fake = FakeDocker()
        report = teardown.teardown(self.scenario, "laptop", reason="stopped on request",
                                   docker=fake)
        self.assertEqual(report.count(), 0)
        self.assertFalse([c for c in fake.calls if len(c) > 1 and c[1] == "rm"])
        st = localimpl.read_state(ldir)
        self.assertEqual(st["stage"], "torn-down")
        self.assertEqual(st["teardown"]["stage"], "fitted")
        self.assertEqual(st["teardown"]["reason"], "stopped on request")
        self.assertIn("from stage fitted: stopped on request", state.status_text(ldir))


class TestFailedSetupIsTornDown(RenderedGame):

    def test_health_timeout_tears_down(self):
        fake = FakeDocker(health="unhealthy")
        fake.add("volume", "registry-data")
        with self.assertRaises(state.SetupFailed) as ctx:
            self.deploy(fake, timeout=10)
        self.assertEqual(teardown.leftovers(fake, self.gid), {})
        self.assertEqual(fake.names("volume"), ["registry-data"])
        self.assertIn("Teardown of game", str(ctx.exception))
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertIn("health checks did not pass", st["failure"]["reason"])
        # The step's own teardown writes no teardown record.
        self.assertNotIn("teardown", st)
        # A later teardown keeps the failure record, and records the teardown.
        teardown.teardown(self.scenario, "laptop", docker=fake)
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertIn("health checks did not pass", st["failure"]["reason"])
        self.assertEqual(st["teardown"]["stage"], "rendered")

    def test_partial_creation_is_torn_down(self):
        fake = FakeDocker(fail={("stack", "deploy"): "boom"})
        with self.assertRaises(state.SetupFailed):
            self.deploy(fake)
        self.assertEqual(len(fake.called("config", "rm")), 6)
        self.assertEqual(len(fake.called("secret", "rm")), 4)
        self.assertEqual(teardown.leftovers(fake, self.gid), {})


class TestExec(DeployedGame):

    def test_command(self):
        result = execnode.exec_node(self.ldir, "db", "postgres", stdin="echo hi\n",
                                    env={"FAULT_X": "a b", "GM_Y": ""}, docker=self.fake)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "exec-output\n")
        container = f"{self.gid}_db.1.ctr"
        probe, run = self.fake.called("exec")
        self.assertEqual(probe, ["exec", "-u", "postgres", container, "true"])
        self.assertEqual(run, ["exec", "-i", "-u", "postgres", "-e", "FAULT_X=a b",
                               "-e", "GM_Y=", container, "sh", "-s"])
        # The container was found by its Swarm service label.
        ps = [c for c in self.fake.calls if c[0] == "ps"][-1]
        self.assertIn(f"label=com.docker.swarm.service.name={self.gid}_db", ps)

    def test_cannot_start(self):
        with self.assertRaisesRegex(execnode.ExecError, "no node 'web'"):
            execnode.exec_node(self.ldir, "web", "root", docker=self.fake)
        self.fake.fail[("exec", "-u")] = "unable to find user nobody2"
        with self.assertRaisesRegex(execnode.ExecError, "cannot run as nobody2"):
            execnode.exec_node(self.ldir, "db", "nobody2", docker=self.fake)
        with self.assertRaises(execnode.ExecError):
            execnode.exec_node(self.ldir, "db", "root; rm", docker=self.fake)
        with self.assertRaises(execnode.ExecError):
            execnode.exec_node(self.ldir, "db", "root", env={"1X": "v"}, docker=self.fake)

    def test_no_running_container(self):
        del self.fake.objects["service"][f"{self.gid}_db"]
        with self.assertRaisesRegex(execnode.ExecError, "no running container"):
            execnode.exec_node(self.ldir, "db", "root", docker=self.fake)

    def test_needs_a_deployed_game(self):
        self.teardown()
        with self.assertRaisesRegex(execnode.ExecError, "nothing is deployed"):
            execnode.exec_node(self.ldir, "db", "root", docker=self.fake)

    def test_parse_env(self):
        self.assertEqual(execnode.parse_env(["A=1", "B=x=y", "C="]),
                         {"A": "1", "B": "x=y", "C": ""})
        for bad in ("A", "=1", "A-B=1"):
            with self.assertRaises(GmError):
                execnode.parse_env([bad])

    def test_logs(self):
        self.assertEqual(execnode.logs(self.ldir, "bastion", tail=20, docker=self.fake), 0)
        self.assertEqual(self.fake.called("service", "logs")[-1],
                         ["service", "logs", "--timestamps", "--tail", "20",
                          f"{self.gid}_bastion"])

    def test_command_line_cannot_start(self):
        proc = run_gmctl("exec", self.scenario, "--playground", "laptop", "--node", "web",
                         "--user", "root")
        self.assertEqual(proc.returncode, execnode.CANNOT_RUN)
        self.assertIn("no node 'web'", proc.stderr)
