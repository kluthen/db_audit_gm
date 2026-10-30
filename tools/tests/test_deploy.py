"""gmctl deploy (tools/gm/deploy.py, tools/gm/docker.py), Docker stubbed."""

import os
import shutil
import stat
import unittest

import yaml

from tools.gm import deploy, docker, execnode, fit, localimpl, render, state, teardown
from tools.gm.model import GmError
from tools.tests import REPO_ROOT, SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl
from tools.tests.test_render import MANAGER, VPS_ENDPOINT, WORKER, TwoHostScenario


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
# `postgres` declares `monitoring_password` itself (v0.2 chunk 6), and
# `gm_check_password` and `pgbouncer_lookup_password` (v0.3 chunk 4a; the
# latter `only_with_role: pooler`, so left out here: fixture-audit has no
# pooler node, chunk 7b).
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
                         ["dba_password", "gm_check_password", "monitoring_password",
                          "player_password", "player_ssh_key", "player_ssh_key.pub",
                          "tools_password"])
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
                                   "dba_password", "monitoring_password", "gm_check_password",
                                   "tools_password")))
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

    def test_first_line_names_the_engine_on_one_host(self):
        text = self.deploy(FakeDocker()).text()
        self.assertTrue(text.startswith(f"Game {self.gid}: deployed on local engine.\n  "), text)
        self.assertNotIn("hosts", text.splitlines()[0])

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
        with self.assertRaisesRegex(GmError, "127.0.0.1:5000/dbagm/postgres:0.3.0"):
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
            {"name": f"{gid}_gm_check_password", "secret": "gm_check_password",
             "kind": "password", "handed_over": False, "file": rel + "gm_check_password"},
            {"name": f"{gid}_backup_key", "secret": "backup_key", "kind": "key-pair",
             "pair": "backup_key", "half": "private", "file": rel + "backup_key"},
        ])

    def test_generated_by_kind_mode_0600(self):
        sdir = self.ldir / "secrets"
        self.assertEqual(mode(sdir), 0o700)
        self.assertEqual(sorted(p.name for p in sdir.iterdir()), [
            "backup_key", "backup_key.pub", "dba_password", "gm_check_password",
            "monitoring_password", "player_password", "player_ssh_key", "player_ssh_key.pub", "tools_password"])
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
            # no web front in fixture-audit: no tools-password line (RG-3, D103)
            "    backup_key: private key of pair backup_key",
            "    backup_key.pub: public key of pair backup_key",
            "    monitoring_password: password",
            "    gm_check_password: password",
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


# --- Several hosts (v0.3 capture W3, items 3 and 6; D173, D181) -------------

POSTGRES = "127.0.0.1:5000/dbagm/postgres:0.3.0"
BASTION = "127.0.0.1:5000/dbagm/bastion:0.3.0"


class TestHostDockers(TwoHostScenario):
    """for_local_dir on a playground of several hosts, and the contexts."""

    def setUp(self):
        super().setUp()
        self.fit()

    def test_the_manager_reaches_each_host_through_its_context(self):
        mgr = docker.for_local_dir(self.ldir)
        self.assertEqual(mgr.command(["ps"]), ["docker", "ps"])        # the local engine
        vps = mgr.on_host(WORKER)
        self.assertIs(mgr.on_host(MANAGER), mgr)
        self.assertEqual(vps.command(["ps"]), ["docker", "--context", f"dbagm-{WORKER}", "ps"])
        self.assertEqual(vps.endpoint, VPS_ENDPOINT)
        gid = localimpl.read_implementation(self.ldir)["game_id"]
        self.assertIs(mgr.for_service(f"{gid}_db"), vps)
        self.assertIs(mgr.for_service(f"{gid}_bastion"), mgr)
        self.assertEqual(mgr.every_host(), [mgr, vps])
        with self.assertRaisesRegex(GmError, "host elsewhere is not declared"):
            mgr.on_host("elsewhere")

    def test_a_context_is_created_once_and_never_redirected(self):
        client = FakeDocker()
        vps = docker.ContextDocker(VPS_ENDPOINT, WORKER, client=client)
        self.assertTrue(docker.ensure_context(client, vps.context, VPS_ENDPOINT))
        self.assertEqual(client.contexts, {f"dbagm-{WORKER}": VPS_ENDPOINT})
        self.assertFalse(docker.ensure_context(client, vps.context, VPS_ENDPOINT))
        self.assertEqual(len(client.called("context", "create")), 1)
        with self.assertRaisesRegex(GmError, rf"names {VPS_ENDPOINT}, not ssh://other@host .*"
                                             rf"docker context update dbagm-{WORKER} --docker "
                                             r"host=ssh://other@host"):
            docker.ensure_context(client, vps.context, "ssh://other@host")
        self.assertFalse(client.called("context", "use"))

    def test_todays_form_keeps_its_endpoint(self):
        ldir = self.scenario / "local" / "solo"
        localimpl.write_playground(ldir, {"name": "solo", "platform": "swarm",
                                          "docker_endpoint": "ssh://gm@host", "capacity": {}})
        d = docker.for_local_dir(ldir)
        self.assertEqual(d.command(["ps"]), ["docker", "-H", "ssh://gm@host", "ps"])
        self.assertIs(d.on_host("any-name"), d)


class TwoHostRendered(TwoHostScenario):

    def setUp(self):
        super().setUp()
        self.fit()
        render.render(self.scenario, "duo")
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.clock = [0.0]

    def sleep(self, seconds):
        self.clock[0] += seconds

    def cluster(self, availability="Active", **worker):
        return FakeDocker.cluster(MANAGER, {WORKER: worker}, availability=availability)

    def deploy(self, fake, **kwargs):
        kwargs.setdefault("timeout", 30)
        return deploy.deploy(self.scenario, "duo", docker=fake, sleep=self.sleep,
                             clock=lambda: self.clock[0], **kwargs)


class TestTwoHostDeploy(TwoHostRendered):

    def test_the_images_of_the_vps_nodes_are_copied_once(self):
        fake = self.cluster()
        vps = fake.on_host(WORKER)
        result = self.deploy(fake)
        self.assertEqual(fake.called("save"), [["save", POSTGRES]])     # db's, not the bastion's
        self.assertEqual(vps.called("load"), [["load", "--quiet"]])
        self.assertIn(POSTGRES, vps.loaded)
        st = localimpl.read_state(self.ldir)
        [entry] = st["images"][WORKER]
        self.assertEqual({k: entry[k] for k in ("image", "id", "copied")},
                         {"image": POSTGRES, "id": vps.loaded[POSTGRES], "copied": True})
        self.assertNotIn(MANAGER, st["images"])
        self.assertIn(f"  images on {WORKER}: 1 copied ({POSTGRES}), 0 already held under the "
                      "same id", result.text())
        self.assertIn(f"  node bastion: port 2222 on host {MANAGER}", result.text())
        # never pulled
        self.assertFalse(fake.called("pull") or vps.called("pull"))

    def test_first_line_names_the_playgrounds_hosts(self):
        """Not "local engine": each host, manager or not, and its endpoint,
        as `status` lists them (wave 3 gate carry-over)."""
        text = self.deploy(self.cluster()).text()
        self.assertTrue(text.startswith(
            f"Game {self.gid}: deployed on duo, 2 hosts:\n  host {MANAGER} (manager): local "
            f"engine\n  host {WORKER}: {VPS_ENDPOINT}\n  "), text)
        self.assertNotIn("deployed on local engine", text)

    def test_an_image_held_under_the_same_id_is_skipped(self):
        fake = self.cluster(images=True)            # the VPS already holds both images
        result = self.deploy(fake)
        self.assertFalse(fake.called("save"))
        self.assertFalse(fake.on_host(WORKER).called("load"))
        self.assertFalse(localimpl.read_state(self.ldir)["images"][WORKER][0]["copied"])
        self.assertIn("0 copied, 1 already held under the same id", result.text())

    def test_an_image_held_under_another_id_is_copied(self):
        fake = self.cluster(images=True, ids={POSTGRES: "sha256:" + "0" * 64})
        self.deploy(fake)
        self.assertEqual(fake.called("save"), [["save", POSTGRES]])
        self.assertTrue(localimpl.read_state(self.ldir)["images"][WORKER][0]["copied"])

    def test_each_node_runs_and_is_polled_on_its_host(self):
        fake = self.cluster()
        vps = fake.on_host(WORKER)
        self.deploy(fake)
        self.assertEqual(vps.names("volume"),
                         sorted(v["name"] for v in self.impl["nodes"]["db"]["volumes"]))
        self.assertEqual(fake.names("volume"),
                         sorted(v["name"] for v in self.impl["nodes"]["bastion"]["volumes"]))
        self.assertEqual([c[-1] for c in vps.called("inspect")], [f"{self.gid}_db.1.ctr"])
        self.assertEqual([c[-1] for c in fake.called("inspect")],
                         [f"{self.gid}_bastion.1.ctr"])
        self.assertFalse(vps.called("stack") or vps.called("config") or vps.called("service"))

    def test_the_exec_verb_reaches_a_node_on_the_vps(self):
        fake = self.cluster()
        self.deploy(fake)
        vps = fake.on_host(WORKER)
        result = execnode.exec_node(self.ldir, "db", "postgres", stdin="true\n", docker=fake)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.container, f"{self.gid}_db.1.ctr")
        self.assertTrue(vps.called("exec", "-i", "-u", "postgres"))
        self.assertFalse(fake.called("exec"))

    def test_a_drained_host_is_refused_before_anything_is_created(self):
        fake = self.cluster(availability="Drain")
        with self.assertRaisesRegex(GmError, rf"host {WORKER} is Ready, Drain in the swarm: .*"
                                             rf"docker node update --availability active "
                                             rf"{WORKER}\); nothing deployed"):
            self.deploy(fake)
        self.assertFalse(fake.called("config", "create"))
        self.assertFalse(fake.called("save"))
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_a_host_a_timer_run_cannot_reach_is_refused(self):
        fake = self.cluster(unattended=False)
        with self.assertRaisesRegex(GmError, rf"host {WORKER} does not answer as a host timer's "
                                             r"run would reach it, with no SSH agent and no "
                                             r"terminal \(.*Permission denied"):
            self.deploy(fake)
        self.assertFalse(fake.called("config", "create"))
        [probe] = fake.on_host(WORKER).called("version")
        self.assertEqual(probe, ["version", "--format", "{{.Server.Version}}"])

    def test_init_swarm_is_refused_on_several_hosts(self):
        with self.assertRaisesRegex(GmError, "--init-swarm on a playground of several hosts"):
            self.deploy(self.cluster(), init_swarm=True)

    def test_the_overlay_leaves_room_for_vxlan_inside_tailscale(self):
        stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        self.assertEqual(stack["networks"]["backend"]["driver_opts"],
                         {"com.docker.network.driver.mtu": "1230"})

    def test_a_game_on_one_of_the_hosts_keeps_the_default_mtu_and_copies_nothing(self):
        self.fit(mapping=("host-1=" + MANAGER, "host-2=" + MANAGER))
        render.render(self.scenario, "duo")
        stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        self.assertNotIn("driver_opts", stack["networks"]["backend"])
        fake = self.cluster(availability="Drain")         # the VPS drained: no node there
        self.deploy(fake)
        self.assertFalse(fake.called("save"))
        self.assertNotIn("images", localimpl.read_state(self.ldir))


# --- The overlay's subnet on several hosts (capture W3-a, D182) -------------

VPS_NETWORKS = {f"net{i}": [f"10.0.{i}.0/24"] for i in range(6)}       # the VPS's, G4
MANAGER_NETWORKS = {"ingress": ["10.0.0.0/24"], "bridge": ["172.17.0.0/16"]}


class TestSubnetPick(unittest.TestCase):
    """deploy.pick_subnet and choose_subnet over given network lists."""

    def test_the_first_free_slash_24_of_the_range(self):
        taken = [("armenelos", "ingress", "10.0.0.0/24"), ("vps", "net1", "10.0.1.0/24"),
                 ("vps", "v6", "fd00:20::/64")]
        self.assertEqual(deploy.pick_subnet(taken), "10.20.0.0/24")

    def test_both_kinds_of_overlap_are_skipped(self):
        taken = [("armenelos", "otherGame_backend", "10.20.0.0/24"),   # a swarm overlay
                 ("vps", "local_net", "10.20.1.128/25"),                # inside the next /24
                 ("vps", "wide", "10.20.2.0/23")]                       # containing two more
        self.assertEqual(deploy.pick_subnet(taken), "10.20.4.0/24")

    def test_a_full_range_is_refused_naming_it(self):
        with self.assertRaisesRegex(GmError, r"no free /24 left in 10\.20\.0\.0/16.*nothing "
                                             "deployed"):
            deploy.pick_subnet([("vps", "all", "10.0.0.0/8")])

    def test_a_recorded_subnet_is_kept(self):
        taken = [("vps", "net1", "10.20.0.0/24")]
        self.assertEqual(deploy.choose_subnet(taken, "10.20.7.0/24"),
                         ("10.20.7.0/24", "as recorded, still free, inside 10.20.0.0/16, the "
                                          "default range"))
        self.assertEqual(deploy.choose_subnet(taken),
                         ("10.20.1.0/24", "picked from 10.20.0.0/16, the default range"))

    def test_a_recorded_subnet_now_taken_is_refused_naming_the_network(self):
        taken = [("vps-5718ad52", "late_net", "10.20.0.0/16")]
        with self.assertRaisesRegex(GmError, r"recorded overlay subnet 10\.20\.7\.0/24, inside "
                                             r"10\.20\.0\.0/16 \(the default range\), now "
                                             r"overlaps network late_net \(10\.20\.0\.0/16\) on "
                                             r"vps-5718ad52.*nothing deployed"):
            deploy.choose_subnet(taken, "10.20.7.0/24")


class TestTwoHostSubnet(TwoHostRendered):

    def cluster(self, manager_networks=None, vps_networks=None, **kwargs):
        return FakeDocker.cluster(
            MANAGER, {WORKER: {"networks": VPS_NETWORKS if vps_networks is None
                               else vps_networks}},
            networks=MANAGER_NETWORKS if manager_networks is None else manager_networks,
            **kwargs)

    def stack(self):
        return yaml.safe_load((self.ldir / "stack.yml").read_text())

    def test_render_leaves_the_subnet_to_deploy(self):
        self.assertNotIn("ipam", self.stack()["networks"]["backend"])
        self.assertNotIn(localimpl.OVERLAY, self.impl)

    def test_deploy_picks_records_and_renders_it(self):
        fake = self.cluster(vps_networks={**VPS_NETWORKS, "app": ["10.20.0.0/24"]})
        result = self.deploy(fake)
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual(impl[localimpl.OVERLAY], {"subnet": "10.20.1.0/24"})
        backend = self.stack()["networks"]["backend"]
        self.assertEqual(backend["ipam"], {"config": [{"subnet": "10.20.1.0/24"}]})
        self.assertEqual(backend["driver_opts"], {"com.docker.network.driver.mtu": "1230"})
        self.assertEqual(fake.subnets[f"{self.gid}_backend"], ["10.20.1.0/24"])
        self.assertIn("  overlay subnet: 10.20.1.0/24 (picked from 10.20.0.0/16, the default "
                      "range)",
                      result.text())
        # read on the manager and on the placed host, nothing created there
        self.assertTrue(fake.called("network", "inspect"))
        self.assertTrue(fake.on_host(WORKER).called("network", "inspect"))
        self.assertFalse(fake.on_host(WORKER).called("network", "create"))
        # what render writes from the record is what deploy wrote
        localimpl.set_stage(self.ldir, "fitted")
        render.render(self.scenario, "duo")
        self.assertEqual(self.stack()["networks"]["backend"], backend)

    def test_a_retry_keeps_the_recorded_subnet(self):
        failing = self.cluster(fail={("stack", "deploy"): "boom"})
        with self.assertRaises(state.SetupFailed):
            self.deploy(failing)
        first = localimpl.read_implementation(self.ldir)[localimpl.OVERLAY]["subnet"]
        # another game took the first /24 since: the recorded one is kept anyway
        fake = self.cluster(manager_networks={**MANAGER_NETWORKS, "g2_backend": ["10.20.5.0/24"]})
        result = self.deploy(fake)
        self.assertEqual(localimpl.read_implementation(self.ldir)[localimpl.OVERLAY],
                         {"subnet": first})
        self.assertIn(f"overlay subnet: {first} (as recorded, still free, inside 10.20.0.0/16, "
                      "the default range)", result.text())

    def test_a_recorded_subnet_now_overlapping_is_refused_before_anything_is_created(self):
        localimpl.write_implementation(self.ldir, {**self.impl,
                                                   localimpl.OVERLAY: {"subnet": "10.20.3.0/24"}})
        fake = self.cluster(vps_networks={"late": ["10.20.3.0/25"]})
        with self.assertRaisesRegex(GmError, r"10\.20\.3\.0/24, inside 10\.20\.0\.0/16 \(the "
                                             r"default range\), now overlaps network late "
                                             rf"\(10\.20\.3\.0/25\) on {WORKER}"):
            self.deploy(fake)
        self.assertFalse(fake.called("config", "create") or fake.called("save"))
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_the_games_own_network_is_left_out(self):
        # a redeploy or a restart while Swarm still holds the game's overlay (D182)
        own = self.impl["network"]
        localimpl.write_implementation(self.ldir, {**self.impl,
                                                   localimpl.OVERLAY: {"subnet": "10.20.3.0/24"}})
        fake = self.cluster(manager_networks={**MANAGER_NETWORKS, own: ["10.20.3.0/24"]},
                            vps_networks={**VPS_NETWORKS, own: ["10.20.3.0/24"]})
        taken = deploy.taken_subnets(fake, self.impl)
        self.assertNotIn(own, [name for _, name, _ in taken])
        self.assertIn((MANAGER, "ingress", "10.0.0.0/24"), taken)
        self.assertIn((WORKER, "net5", "10.0.5.0/24"), taken)
        self.assertIn("as recorded, still free", self.deploy(fake).text())

    def test_a_new_fit_drops_the_record(self):
        self.deploy(self.cluster())
        teardown.teardown(self.scenario, "duo", docker=self.cluster(),
                          sleep=self.sleep, clock=lambda: self.clock[0])
        self.fit()
        self.assertNotIn(localimpl.OVERLAY, localimpl.read_implementation(self.ldir))

    def test_a_game_on_one_host_keeps_swarms_default(self):
        self.fit(mapping=("host-1=" + MANAGER, "host-2=" + MANAGER))
        render.render(self.scenario, "duo")
        fake = self.cluster(availability="Drain")
        self.deploy(fake)
        self.assertNotIn(localimpl.OVERLAY, localimpl.read_implementation(self.ldir))
        self.assertNotIn("ipam", self.stack()["networks"]["backend"])
        self.assertFalse(fake.called("network", "inspect"))


# --- The overlay's range is the GM's (capture W3-b, D183) -------------------

DEPLOY_WAY_OUT = ("choose another range: gmctl deploy --overlay-range <cidr> for this run, or "
                  "gmctl fit --overlay-range <cidr> for the playground; nothing deployed")


class TestOverlayRange(TwoHostRendered):

    cluster = TestTwoHostSubnet.cluster
    stack = TestTwoHostSubnet.stack

    def declare(self, cidr):
        pg = localimpl.read_playground(self.ldir)
        localimpl.write_playground(self.ldir, dict(pg, overlay_range=cidr))

    def record(self, subnet):
        localimpl.write_implementation(self.ldir, {**self.impl,
                                                   localimpl.OVERLAY: {"subnet": subnet}})

    def recorded(self):
        return localimpl.read_implementation(self.ldir)[localimpl.OVERLAY]["subnet"]

    def assert_nothing_created(self, fake):
        self.assertFalse(fake.called("config", "create") or fake.called("save"))
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_the_playgrounds_range_is_used(self):
        self.declare("172.30.0.0/16")
        fake = self.cluster(vps_networks={"app": ["172.30.0.0/24"]})
        result = self.deploy(fake)
        self.assertEqual(self.recorded(), "172.30.1.0/24")
        self.assertEqual(self.stack()["networks"]["backend"]["ipam"],
                         {"config": [{"subnet": "172.30.1.0/24"}]})
        self.assertIn("  overlay subnet: 172.30.1.0/24 (picked from 172.30.0.0/16, playground "
                      "duo's overlay_range)\n", result.text())

    def test_the_run_option_overrides_the_playgrounds(self):
        self.declare("172.30.0.0/16")
        result = self.deploy(self.cluster(), overlay_range="10.21.7.0/24")
        self.assertEqual(self.recorded(), "10.21.7.0/24")
        self.assertIn("  overlay subnet: 10.21.7.0/24 (picked from 10.21.7.0/24, given with "
                      "--overlay-range)\n", result.text())
        # the run's range is not the playground's
        self.assertEqual(localimpl.read_playground(self.ldir)["overlay_range"], "172.30.0.0/16")

    def test_a_record_outside_the_range_in_force_is_picked_again(self):
        self.record("10.20.3.0/24")
        result = self.deploy(self.cluster(), overlay_range="10.30.0.0/16")
        self.assertEqual(self.recorded(), "10.30.0.0/24")
        self.assertEqual(self.stack()["networks"]["backend"]["ipam"],
                         {"config": [{"subnet": "10.30.0.0/24"}]})
        self.assertIn("  overlay subnet: 10.30.0.0/24 (picked from 10.30.0.0/16, given with "
                      "--overlay-range; the recorded 10.20.3.0/24 lies outside it)\n",
                      result.text())

    def test_a_record_inside_the_range_in_force_is_kept(self):
        self.record("10.20.3.0/24")
        result = self.deploy(self.cluster(), overlay_range="10.0.0.0/8")
        self.assertEqual(self.recorded(), "10.20.3.0/24")
        self.assertIn("(as recorded, still free, inside 10.0.0.0/8, given with --overlay-range)",
                      result.text())

    def test_a_record_inside_the_range_now_overlapping_is_refused_naming_the_way_out(self):
        self.record("10.20.3.0/24")
        fake = self.cluster(vps_networks={"late": ["10.20.3.0/25"]})
        with self.assertRaises(GmError) as caught:
            self.deploy(fake, overlay_range="10.20.0.0/20")
        self.assertEqual(str(caught.exception),
                         "the game's recorded overlay subnet 10.20.3.0/24, inside 10.20.0.0/20 "
                         "(given with --overlay-range), now overlaps network late (10.20.3.0/25) "
                         f"on {WORKER}: gmctl does not move a game's addresses on its own; remove "
                         "that network, or choose another range, one that leaves 10.20.3.0/24 "
                         "out: gmctl deploy --overlay-range <cidr> for this run, or gmctl fit "
                         "--overlay-range <cidr> for the playground; nothing deployed")
        self.assert_nothing_created(fake)

    def test_a_full_range_is_refused_naming_what_holds_it_and_the_way_out(self):
        self.declare("10.0.4.0/23")
        fake = self.cluster()                   # the VPS holds 10.0.4.0/24 and 10.0.5.0/24
        with self.assertRaises(GmError) as caught:
            self.deploy(fake)
        self.assertEqual(str(caught.exception),
                         "no free /24 left in 10.0.4.0/23 (playground duo's overlay_range), the "
                         "range for the overlays of gmctl's games on several hosts: taken by "
                         f"network net4 (10.0.4.0/24) on {WORKER}; network net5 (10.0.5.0/24) on "
                         f"{WORKER}; " + DEPLOY_WAY_OUT)
        self.assert_nothing_created(fake)

    def test_a_bad_option_is_refused_before_anything(self):
        fake = self.cluster()
        with self.assertRaisesRegex(GmError, r"--overlay-range '8\.8\.8\.0/24': outside the "
                                             "private ranges"):
            self.deploy(fake, overlay_range="8.8.8.0/24")
        self.assertFalse(fake.calls)
        self.assert_nothing_created(fake)

    def test_a_game_on_one_host_reads_no_range_and_no_network(self):
        self.fit(mapping=("host-1=" + MANAGER, "host-2=" + MANAGER))
        render.render(self.scenario, "duo")
        self.declare("10.0.0.0/8")
        fake = self.cluster(availability="Drain")
        result = self.deploy(fake, overlay_range="10.30.0.0/16")
        self.assertNotIn(localimpl.OVERLAY, localimpl.read_implementation(self.ldir))
        self.assertNotIn("ipam", self.stack()["networks"]["backend"])
        self.assertFalse(fake.called("network", "inspect"))
        self.assertNotIn("overlay subnet", result.text())

    def test_the_cli_option(self):
        proc = run_gmctl("deploy", self.scenario, "--playground", "duo", "--overlay-range",
                         "10.20.0.0/25")
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(proc.stderr.strip(), "gmctl deploy: --overlay-range '10.20.0.0/25': "
                                              "narrower than /24, the size of a game's overlay "
                                              "subnet")
