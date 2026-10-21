"""gmctl deploy (tools/gm/deploy.py, tools/gm/docker.py), Docker stubbed."""

import os
import shutil
import stat
import unittest

import yaml

from tools.gm import deploy, docker, fit, localimpl, render, state
from tools.gm.model import GmError
from tools.tests import REPO_ROOT, SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl


def mode(path):
    return stat.S_IMODE(os.stat(path).st_mode)


def declare_secrets(scenario, brick, *secrets):
    """Make catalog brick `brick` scenario-local (same id and version) and
    add `secrets` to the ones it declares; each gets a mount under
    /opt/gm/secrets/ unless it sets its own."""
    local = scenario / "bricks" / brick
    if not local.exists():
        shutil.copytree(REPO_ROOT / "bricks" / brick, local)
    path = local / "brick.yaml"
    data = yaml.safe_load(path.read_text())
    data["secrets"] += [{"path": f"/opt/gm/secrets/{s['name']}", "uid": 0, "gid": 0,
                         "mode": "0400", **s} for s in secrets]
    path.write_text(yaml.safe_dump(data, sort_keys=False))


# Secrets no v0.1 brick declares: a key pair whose public half two bricks
# mount, and a handed-over password (capture W1, item 7); the catalog
# `postgres` 0.2.0 declares `monitoring_password` itself (chunk 6).
NEW_DB_SECRETS = (
    {"name": "backup_key", "kind": "key-pair", "pair": "backup_key", "half": "private"},
    {"name": "backup_pubkey", "kind": "key-pair", "pair": "backup_key", "half": "public",
     "mode": "0444"},
)
NEW_BASTION_SECRETS = (
    {"name": "tools_password", "kind": "password", "handed_over": True},
    {"name": "backup_pubkey", "kind": "key-pair", "pair": "backup_key", "half": "public",
     "mode": "0444"},
)


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
        paths = deploy.generate_credentials(self.ldir, self.impl)
        sdir = self.ldir / "secrets"
        self.assertEqual(mode(sdir), 0o700)
        self.assertEqual(sorted(p.name for p in sdir.iterdir()),
                         ["dba_password", "monitoring_password", "player_password",
                          "player_ssh_key", "player_ssh_key.pub", "tools_password"])
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
        self.assertTrue(pub.strip().endswith(f"{self.gid}-player_ssh_key"))

    def test_regenerated_each_time(self):
        deploy.generate_credentials(self.ldir, self.impl)
        first = (self.ldir / "secrets" / "dba_password").read_text()
        deploy.generate_credentials(self.ldir, self.impl)
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
                                   "dba_password", "monitoring_password", "tools_password")))
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
        with self.assertRaisesRegex(GmError, "127.0.0.1:5000/dbagm/postgres:0.2.0"):
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


class TestSecretsByKind(ScenarioCopyTest):
    """Bricks declaring secrets beyond v0.1's four get them generated by
    kind, mounted, and listed by gmctl status (capture W1, item 7)."""

    def setUp(self):
        super().setUp()
        declare_secrets(self.scenario, "postgres", *NEW_DB_SECRETS)
        declare_secrets(self.scenario, "bastion", *NEW_BASTION_SECRETS)
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        render.render(self.scenario, "laptop")
        self.ldir = self.scenario / "local" / "laptop"
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        self.fake = FakeDocker()
        self.result = deploy.deploy(self.scenario, "laptop", docker=self.fake, timeout=30,
                                    sleep=lambda s: None)

    def test_implementation_records_each_secret_once_with_its_kind(self):
        gid = self.gid
        rel = "local/laptop/secrets/"
        self.assertEqual(self.impl["secrets"], [
            {"name": f"{gid}_player_password", "secret": "player_password",
             "kind": "password", "handed_over": True, "file": rel + "player_password"},
            {"name": f"{gid}_player_ssh_key", "secret": "player_ssh_key", "kind": "key-pair",
             "pair": "player_ssh_key", "half": "private", "file": rel + "player_ssh_key"},
            {"name": f"{gid}_dba_password", "secret": "dba_password", "kind": "password",
             "handed_over": False, "file": rel + "dba_password"},
            {"name": f"{gid}_tools_password", "secret": "tools_password", "kind": "password",
             "handed_over": True, "file": rel + "tools_password"},
            {"name": f"{gid}_backup_pubkey", "secret": "backup_pubkey", "kind": "key-pair",
             "pair": "backup_key", "half": "public", "file": rel + "backup_key.pub"},
            {"name": f"{gid}_player_ssh_pubkey", "secret": "player_ssh_pubkey",
             "kind": "key-pair", "pair": "player_ssh_key", "half": "public",
             "file": rel + "player_ssh_key.pub"},
            {"name": f"{gid}_monitoring_password", "secret": "monitoring_password",
             "kind": "password", "handed_over": False, "file": rel + "monitoring_password"},
            {"name": f"{gid}_backup_key", "secret": "backup_key", "kind": "key-pair",
             "pair": "backup_key", "half": "private", "file": rel + "backup_key"},
        ])

    def test_generated_by_kind_mode_0600(self):
        sdir = self.ldir / "secrets"
        self.assertEqual(mode(sdir), 0o700)
        self.assertEqual(sorted(p.name for p in sdir.iterdir()), [
            "backup_key", "backup_key.pub", "dba_password", "monitoring_password",
            "player_password", "player_ssh_key", "player_ssh_key.pub", "tools_password"])
        for path in sdir.iterdir():
            self.assertEqual(mode(path), 0o600, path.name)
        tools = (sdir / "tools_password").read_text()
        self.assertEqual(len(tools), deploy.PLAYER_PASSWORD_LENGTH)
        self.assertTrue(set(tools) <= set(deploy.PLAYER_PASSWORD_ALPHABET))
        monitoring = (sdir / "monitoring_password").read_text()
        self.assertEqual(len(monitoring), deploy.DBA_PASSWORD_LENGTH)
        self.assertTrue(set(monitoring) <= set(deploy.DBA_PASSWORD_ALPHABET))
        self.assertIn("OPENSSH PRIVATE KEY", (sdir / "backup_key").read_text())
        pub = (sdir / "backup_key.pub").read_text()
        self.assertTrue(pub.startswith("ssh-ed25519 "))
        self.assertTrue(pub.strip().endswith(f"{self.gid}-backup_key"))
        self.assertEqual(sorted(self.result.credentials), sorted(sdir.iterdir()))

    def test_created_once_from_the_matching_file(self):
        creates = {}
        for call in self.fake.called("secret", "create"):
            self.assertNotIn(call[-2], creates)
            creates[call[-2]] = call[-1]
        self.assertEqual(sorted(creates), sorted(s["name"] for s in self.impl["secrets"]))
        sdir = str(self.ldir.resolve() / "secrets")
        gid = self.gid
        self.assertEqual(creates[f"{gid}_tools_password"], f"{sdir}/tools_password")
        self.assertEqual(creates[f"{gid}_monitoring_password"], f"{sdir}/monitoring_password")
        self.assertEqual(creates[f"{gid}_backup_key"], f"{sdir}/backup_key")
        self.assertEqual(creates[f"{gid}_backup_pubkey"], f"{sdir}/backup_key.pub")

    def test_mounted_where_each_brick_declares(self):
        gid = self.gid
        def mounts(node):
            return {m["source"]: (m["target"], m["mode"])
                    for m in self.stack["services"][node]["secrets"]}
        db, bastion = mounts("db"), mounts("bastion")
        self.assertEqual(db[f"{gid}_monitoring_password"],
                         ("/opt/gm/secrets/monitoring_password", 0o440))
        self.assertEqual(db[f"{gid}_backup_key"], ("/opt/gm/secrets/backup_key", 0o400))
        self.assertEqual(db[f"{gid}_backup_pubkey"], ("/opt/gm/secrets/backup_pubkey", 0o444))
        self.assertEqual(bastion[f"{gid}_tools_password"],
                         ("/opt/gm/secrets/tools_password", 0o400))
        self.assertEqual(bastion[f"{gid}_backup_pubkey"],
                         ("/opt/gm/secrets/backup_pubkey", 0o444))
        self.assertNotIn(f"{gid}_tools_password", db)
        self.assertEqual(set(self.stack["secrets"]), {s["name"] for s in self.impl["secrets"]})

    def test_status_lists_the_files(self):
        lines = state.status_text(self.ldir).splitlines()
        start = lines.index(f"  secrets: {self.ldir / 'secrets'}/ (mode 0600, not printed)")
        self.assertEqual(lines[start + 1:], [
            "    player_password: password, handed over",
            "    player_ssh_key: private key of pair player_ssh_key",
            "    player_ssh_key.pub: public key of pair player_ssh_key",
            "    dba_password: password",
            "    tools_password: password, handed over",
            "    backup_key: private key of pair backup_key",
            "    backup_key.pub: public key of pair backup_key",
            "    monitoring_password: password",
        ])
        text = "\n".join(lines)
        for path in (self.ldir / "secrets").iterdir():
            self.assertNotIn(path.read_text().strip(), text)
            self.assertNotIn(path.read_text().strip(), self.result.text())

    @unittest.skipUnless(shutil.which("docker"), "docker not installed")
    def test_docker_stack_config_accepts(self):
        import subprocess
        r = subprocess.run(["docker", "stack", "config", "-c", str(self.ldir / "stack.yml")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


class TestSecretRefusals(ScenarioCopyTest):
    """A topology whose secrets cannot be generated is refused at fit,
    nothing written (capture W1, item 7)."""

    def refused(self, pattern):
        with self.assertRaisesRegex(GmError, pattern):
            fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.assertFalse((self.scenario / "local" / "laptop" / "implementation.yaml").exists())

    def test_one_name_two_kinds(self):
        declare_secrets(self.scenario, "postgres", {"name": "shared", "kind": "password"})
        declare_secrets(self.scenario, "bastion", {"name": "shared", "kind": "key-pair",
                                                    "pair": "shared", "half": "private"})
        self.refused(r"secret shared is declared differently by bricks bastion \(key pair "
                     r"shared, private half\) and postgres \(password\)")

    def test_one_password_handed_over_by_one_brick_only(self):
        declare_secrets(self.scenario, "postgres",
                        {"name": "tools_password", "kind": "password"})
        declare_secrets(self.scenario, "bastion",
                        {"name": "tools_password", "kind": "password", "handed_over": True})
        self.refused("secret tools_password is declared differently")

    def test_one_name_two_halves_or_pairs(self):
        declare_secrets(self.scenario, "postgres", {"name": "player_ssh_key", "kind": "key-pair",
                                                     "pair": "player_ssh_key", "half": "public"})
        self.refused("secret player_ssh_key is declared differently .*public half")

    def test_one_name_two_pairs(self):
        declare_secrets(self.scenario, "postgres", {"name": "player_ssh_key", "kind": "key-pair",
                                                     "pair": "other_key", "half": "private"})
        self.refused("secret player_ssh_key is declared differently .*pair other_key")

    def test_password_named_after_a_pair(self):
        declare_secrets(self.scenario, "postgres", {"name": "backup_key", "kind": "key-pair",
                                                     "pair": "backup", "half": "private"})
        declare_secrets(self.scenario, "bastion", {"name": "backup", "kind": "password"})
        self.refused("password backup .* would be written to the file of key pair backup")

    def test_password_named_after_a_public_key_file(self):
        declare_secrets(self.scenario, "bastion", {"name": "player_ssh_key.pub",
                                                    "kind": "password"})
        self.refused("password player_ssh_key.pub .* key pair player_ssh_key")

    def test_malformed_declarations(self):
        declare_secrets(self.scenario, "postgres",
                        {"name": "token", "kind": "token"},
                        {"name": "half_missing", "kind": "key-pair", "pair": "k"},
                        {"name": "pair_missing", "kind": "key-pair", "half": "private"},
                        {"name": "pw_with_half", "kind": "password", "half": "public"},
                        {"name": "pw_odd", "kind": "password", "handed_over": "yes"})
        with self.assertRaises(GmError) as ctx:
            fit.fit(self.scenario, "laptop", **SUFFICIENT)
        text = str(ctx.exception)
        for part in ("secret token: kind token is not password or key-pair",
                     "secret half_missing: kind key-pair needs half",
                     "secret pair_missing: kind key-pair needs pair",
                     "secret pw_with_half: half is for a key pair, not a password",
                     "secret pw_odd: handed_over is not true or false"):
            self.assertIn(part, text)

    def test_render_refuses_secrets_changed_since_fit(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        declare_secrets(self.scenario, "postgres", {"name": "replication_password",
                                                     "kind": "password"})
        with self.assertRaisesRegex(GmError, "secrets changed since gmctl fit: fit again"):
            render.render(self.scenario, "laptop")

    def test_render_refuses_a_second_network_added_since_fit(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.edit_yaml("scenario.yaml", lambda d: d["networks"].append(
            {"name": "front", "description": "a second network"}))
        with self.assertRaisesRegex(GmError, "declares 2 networks; gmctl renders one network"):
            render.render(self.scenario, "laptop")

    def test_render_refuses_network_renamed_since_fit(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        def rename(data):
            data["networks"][0]["name"] = "front"
            for node in data["nodes"]:
                node["networks"] = ["front"]
        self.edit_yaml("scenario.yaml", rename)
        with self.assertRaisesRegex(GmError, "network changed since gmctl fit: fit again"):
            render.render(self.scenario, "laptop")


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
