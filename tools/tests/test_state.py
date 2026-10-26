"""The recorded state: setup failures and gmctl status (tools/gm/state.py)."""

from tools.gm import fit, localimpl, state
from tools.gm.model import GmError
from tools.tests import SUFFICIENT, ScenarioCopyTest, run_gmctl


class FittedGame(ScenarioCopyTest):

    def setUp(self):
        super().setUp()
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.ldir = self.scenario / "local" / "laptop"


class TestSetupStep(FittedGame):

    def test_success_records_nothing(self):
        with state.setup_step(self.ldir, "deployed"):
            pass
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "fitted")

    def test_failure_undoes_and_records(self):
        undone = []
        with self.assertRaises(state.SetupFailed) as ctx:
            with state.setup_step(self.ldir, "deployed",
                                  undo=lambda: undone.append(1) or "torn down"):
                raise RuntimeError("the  task\nfailed")
        self.assertEqual(undone, [1])
        self.assertEqual(ctx.exception.reason, "the task failed")
        self.assertIn("torn down", str(ctx.exception))
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"]["stage"], "deployed")
        self.assertEqual(st["failure"]["reason"], "the task failed")
        self.assertEqual(st["history"][-1]["stage"], "failed")

    def test_interruption_is_a_failure(self):
        with self.assertRaises(state.SetupFailed):
            with state.setup_step(self.ldir, "data-loaded"):
                raise KeyboardInterrupt
        failure = localimpl.read_state(self.ldir)["failure"]
        self.assertEqual(failure["stage"], "data-loaded")
        self.assertIn("stopped on request", failure["reason"])

    def test_failed_undo_is_added_to_the_reason(self):
        def undo():
            raise RuntimeError("volume in use")
        with self.assertRaises(state.SetupFailed):
            with state.setup_step(self.ldir, "deployed", undo=undo):
                raise RuntimeError("boom")
        reason = localimpl.read_state(self.ldir)["failure"]["reason"]
        self.assertEqual(reason, "boom; teardown after the failure also failed: volume in use")


class TestStatus(FittedGame):

    def test_fitted(self):
        text = state.status_text(self.ldir)
        gid = localimpl.read_state(self.ldir)["game_id"]
        self.assertIn(f"Game {gid}", text)
        self.assertIn("stage: fitted", text)
        self.assertIn("local engine", text)
        self.assertNotIn("failure", text)

    def test_failed(self):
        localimpl.set_failed(self.ldir, "deployed", "health checks did not pass")
        text = state.status_text(self.ldir)
        self.assertIn("stage: failed (last stage reached: fitted)", text)
        self.assertIn("failure: before stage deployed", text)
        self.assertIn("health checks did not pass", text)

    def test_network_line_from_the_fit_on(self):
        gid = localimpl.read_state(self.ldir)["game_id"]
        text = state.status_text(self.ldir)
        self.assertIn(f"\n  network: {gid}_backend", text)
        self.assertNotIn("secrets:", text)      # nothing generated before deploy

    def test_deployed_lists_secret_files_without_printing_them(self):
        localimpl.set_stage(self.ldir, "rendered")
        localimpl.set_stage(self.ldir, "deployed")
        lines = state.status_text(self.ldir).splitlines()
        start = lines.index(f"  secrets: {self.ldir / 'secrets'}/ (mode 0600, not printed)")
        self.assertEqual(lines[start + 1:], [
            "    player_password: password, handed over",
            "    player_ssh_key: private key of pair player_ssh_key",
            "    player_ssh_key.pub: public key of pair player_ssh_key",
            "    dba_password: password",
            "    tools_password: password, handed over",
            "    monitoring_password: password",
            "    gm_check_password: password",
        ])


class TestGmStages(FittedGame):
    """`gmctl status --set` (spec D49, capture W3-A)."""

    def setUp(self):
        super().setUp()
        for stage in ("rendered", "deployed", "data-loaded", "injected"):
            localimpl.set_stage(self.ldir, stage)

    def state_bytes(self):
        return (self.ldir / "state.yaml").read_bytes()

    def set(self, stage):
        return run_gmctl("status", self.scenario, "--playground", "laptop", "--set", stage)

    def test_in_turn_from_injected(self):
        for stage in ("handed-over", "final-answer", "feedback-given"):
            proc = self.set(stage)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertIn(f"  stage: {stage}", proc.stdout)
            st = localimpl.read_state(self.ldir)
            self.assertEqual(st["stage"], stage)
            self.assertEqual(st["history"][-1]["stage"], stage)

    def test_setting_the_current_stage_changes_nothing(self):
        self.assertTrue(state.set_gm_stage(self.ldir, "handed-over"))
        before = self.state_bytes()
        self.assertFalse(state.set_gm_stage(self.ldir, "handed-over"))
        proc = self.set("handed-over")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("Already at stage handed-over: nothing changed.", proc.stdout)
        self.assertEqual(self.state_bytes(), before)

    def test_any_other_transition_refused(self):
        refused = {
            "injected": ["final-answer", "feedback-given", "injected", "torn-down",
                         "deployed", "failed", "bogus"],
            "handed-over": ["feedback-given", "injected"],
            "final-answer": ["handed-over", "torn-down"],
            "feedback-given": ["handed-over", "final-answer"],
        }
        for current, stages in refused.items():
            if current != "injected":
                state.set_gm_stage(self.ldir, current)
            for stage in stages:
                with self.subTest(current=current, stage=stage):
                    before = self.state_bytes()
                    proc = self.set(stage)
                    self.assertEqual(proc.returncode, 1, proc.stdout)
                    self.assertIn("gmctl status:", proc.stderr)
                    self.assertEqual(self.state_bytes(), before)

    def test_refused_from_a_failed_or_earlier_game(self):
        localimpl.set_failed(self.ldir, "injected", "boom")
        before = self.state_bytes()
        with self.assertRaisesRegex(GmError, "can only follow injected"):
            state.set_gm_stage(self.ldir, "handed-over")
        self.assertEqual(self.state_bytes(), before)
