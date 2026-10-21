"""gmctl deploy (tools/gm/deploy.py, tools/gm/docker.py), Docker stubbed."""

import os
import stat
import unittest

from tools.gm import deploy, docker, fit, localimpl, render, state
from tools.gm.model import GmError
from tools.tests import SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl


def mode(path):
    return stat.S_IMODE(os.stat(path).st_mode)


class TestDockerCommand(unittest.TestCase):

    def test_local_engine_and_ssh_endpoint(self):
        self.assertEqual(docker.Docker().command(["ps", "-q"]), ["docker", "ps", "-q"])
        self.assertEqual(docker.Docker("ssh://gm@host").command(["ps"]),
                         ["docker", "-H", "ssh://gm@host", "ps"])
        self.assertEqual(docker.Docker().describe(), "local engine")

    def test_error_message(self):
        err = docker.DockerError(["config", "create", "x", "f"], 1, "  already\n exists ")
        self.assertIsInstance(err, GmError)
        self.assertIn("already exists", str(err))


class RenderedGame(ScenarioCopyTest):

    def setUp(self):
        super().setUp()
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        render.render(self.scenario, "laptop")
        self.ldir = self.scenario / "local" / "laptop"
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.clock = [0.0]

    def sleep(self, seconds):
        self.clock[0] += seconds

    def deploy(self, fake, **kwargs):
        kwargs.setdefault("timeout", 30)
        return deploy.deploy(self.scenario, "laptop", docker=fake, sleep=self.sleep,
                             clock=lambda: self.clock[0], **kwargs)


class TestCredentials(RenderedGame):

    def test_files_modes_and_formats(self):
        paths = deploy.generate_credentials(self.ldir, self.gid)
        sdir = self.ldir / "secrets"
        self.assertEqual(mode(sdir), 0o700)
        self.assertEqual(sorted(p.name for p in sdir.iterdir()),
                         ["dba_password", "player_password", "player_ssh_key",
                          "player_ssh_key.pub"])
        self.assertEqual(sorted(paths), sorted(sdir.iterdir()))
        for path in sdir.iterdir():
            self.assertEqual(mode(path), 0o600, path.name)
        player = (sdir / "player_password").read_text()
        dba = (sdir / "dba_password").read_text()
        self.assertEqual(len(player), deploy.PLAYER_PASSWORD_LENGTH)
        self.assertTrue(set(player) <= set(deploy.PLAYER_PASSWORD_ALPHABET))
        self.assertEqual(len(dba), deploy.DBA_PASSWORD_LENGTH)
        self.assertTrue(dba.isalnum())
        self.assertIn("OPENSSH PRIVATE KEY", (sdir / "player_ssh_key").read_text())
        pub = (sdir / "player_ssh_key.pub").read_text()
        self.assertTrue(pub.startswith("ssh-ed25519 "))
        self.assertTrue(pub.strip().endswith(f"{self.gid}-player"))

    def test_regenerated_each_time(self):
        deploy.generate_credentials(self.ldir, self.gid)
        first = (self.ldir / "secrets" / "dba_password").read_text()
        deploy.generate_credentials(self.ldir, self.gid)
        self.assertNotEqual(first, (self.ldir / "secrets" / "dba_password").read_text())

    def test_credentials_are_git_ignored(self):
        repo_ignore = (localimpl.Path(__file__).resolve().parents[2] / ".gitignore").read_text()
        self.assertIn("local/", repo_ignore.split())


class TestDeploy(RenderedGame):

    def test_names_labels_and_commands(self):
        fake = FakeDocker()
        result = self.deploy(fake)
        gid = self.gid
        labels = {"com.docker.stack.namespace": gid, "dbagm.game": gid}
        self.assertEqual(fake.names("config"), sorted([
            f"{gid}_bastion_README.md", f"{gid}_bastion_story.md", f"{gid}_bastion_issues.md",
            f"{gid}_db_postgresql.conf", f"{gid}_db_pg_hba.conf", f"{gid}_db_envelopes"]))
        self.assertEqual(fake.names("secret"), sorted(
            f"{gid}_{s}" for s in ("player_password", "player_ssh_key", "player_ssh_pubkey",
                                   "dba_password")))
        for kind in ("config", "secret"):
            for name, objlabels in fake.objects[kind].items():
                self.assertEqual(objlabels, labels, name)
        # Each secret is created from its file in secrets/ (pubkey from the .pub).
        creates = {c[-2]: c[-1] for c in fake.called("secret", "create")}
        self.assertTrue(creates[f"{gid}_player_ssh_pubkey"].endswith(
            "/local/laptop/secrets/player_ssh_key.pub"))
        self.assertTrue(creates[f"{gid}_dba_password"].endswith(
            "/local/laptop/secrets/dba_password"))
        envelopes = [c for c in fake.called("config", "create") if c[-2].endswith("_envelopes")]
        self.assertTrue(envelopes[0][-1].endswith("/local/laptop/envelopes/db.conf"))
        # The stack is deployed without resolving images, as stack <game_id>.
        [cmd] = fake.called("stack", "deploy")
        self.assertIn("--resolve-image", cmd)
        self.assertEqual(cmd[cmd.index("--resolve-image") + 1], "never")
        self.assertEqual(cmd[-1], gid)
        self.assertTrue(cmd[cmd.index("-c") + 1].endswith("/local/laptop/stack.yml"))
        # Configs and secrets exist before the stack refers to them.
        order = [tuple(c[:2]) for c in fake.calls]
        self.assertLess(max(i for i, c in enumerate(order) if c[1] == "create"),
                        order.index(("stack", "deploy")))
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "deployed")
        self.assertIsNone(st["failure"])
        text = result.text()
        self.assertIn("Stage deployed.", text)
        self.assertIn("port 2222", text)
        for secret_file in (self.ldir / "secrets").iterdir():
            self.assertNotIn(secret_file.read_text().strip(), text)

    def test_ssh_endpoint_from_playground(self):
        pg = localimpl.read_playground(self.ldir)
        pg["docker_endpoint"] = "ssh://gm@swarm-host"
        localimpl.write_playground(self.ldir, pg)
        self.assertEqual(docker.for_local_dir(self.ldir).command(["info"]),
                         ["docker", "-H", "ssh://gm@swarm-host", "info"])

    def test_no_swarm_is_reported(self):
        fake = FakeDocker(swarm=("inactive", False))
        with self.assertRaisesRegex(GmError, "not part of a swarm.*--init-swarm"):
            self.deploy(fake)
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")
        self.assertFalse(fake.called("swarm", "init"))
        self.assertFalse(fake.called("config", "create"))
        self.assertFalse((self.ldir / "secrets").exists())

    def test_init_swarm_when_asked(self):
        fake = FakeDocker(swarm=("inactive", False))
        result = self.deploy(fake, init_swarm=True)
        self.assertEqual(len(fake.called("swarm", "init")), 1)
        self.assertIn("docker swarm init", result.swarm)

    def test_worker_is_refused(self):
        with self.assertRaisesRegex(GmError, "worker"):
            self.deploy(FakeDocker(swarm=("active", False)), init_swarm=True)

    def test_missing_image_is_refused(self):
        fake = FakeDocker(images=False)
        with self.assertRaisesRegex(GmError, "127.0.0.1:5000/dbagm/postgres:0.1.1"):
            self.deploy(fake)
        self.assertFalse(fake.called("stack", "deploy"))
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_needs_stage_rendered(self):
        self.deploy(FakeDocker())
        with self.assertRaisesRegex(GmError, "stage deployed"):
            self.deploy(FakeDocker())


class TestDeployFailure(RenderedGame):

    def test_stack_deploy_failure_is_recorded(self):
        fake = FakeDocker(fail={("stack", "deploy"): "network overlay: boom"})
        with self.assertRaises(state.SetupFailed) as ctx:
            self.deploy(fake)
        self.assertIn("boom", ctx.exception.reason)
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "failed")
        self.assertEqual(st["failure"]["stage"], "deployed")
        self.assertIn("boom", st["failure"]["reason"])
        self.assertEqual(localimpl.effective_stage(st), "rendered")

    def test_health_timeout_is_recorded(self):
        fake = FakeDocker(health="starting")
        with self.assertRaises(state.SetupFailed) as ctx:
            self.deploy(fake, timeout=10)
        self.assertIn("health checks did not pass within 10 s", ctx.exception.reason)
        self.assertEqual(localimpl.read_state(self.ldir)["failure"]["stage"], "deployed")

    def test_retry_after_failure(self):
        with self.assertRaises(state.SetupFailed):
            self.deploy(FakeDocker(fail={("secret", "create"): "boom"}))
        self.deploy(FakeDocker())
        st = localimpl.read_state(self.ldir)
        self.assertEqual(st["stage"], "deployed")
        self.assertEqual([h["stage"] for h in st["history"]],
                         ["fitted", "rendered", "failed", "deployed"])


class TestCommandLine(ScenarioCopyTest):

    def test_deploy_refuses_before_fit(self):
        proc = run_gmctl("deploy", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("run gmctl fit first", proc.stderr)

    def test_status(self):
        run_gmctl("fit", self.scenario, "--playground", "laptop",
                  *[f"--{k}={v}" for k, v in SUFFICIENT.items()])
        proc = run_gmctl("status", self.scenario, "--playground", "laptop")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("stage: fitted", proc.stdout)


if __name__ == "__main__":
    unittest.main()
