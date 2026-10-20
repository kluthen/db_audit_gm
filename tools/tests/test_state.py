"""The recorded state: setup failures and gmctl status (tools/gm/state.py)."""

from tools.gm import fit, localimpl, state
from tools.tests import SUFFICIENT, ScenarioCopyTest


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

    def test_deployed_points_at_credentials_without_printing_them(self):
        localimpl.set_stage(self.ldir, "rendered")
        localimpl.set_stage(self.ldir, "deployed")
        self.assertIn("credentials: ", state.status_text(self.ldir))
        self.assertIn("(not printed)", state.status_text(self.ldir))
