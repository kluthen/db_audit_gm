"""Stack file and envelope file rendering (tools/gm/render.py)."""

import shutil
import subprocess
import unittest

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import SUFFICIENT, ScenarioCopyTest, run_gmctl


class TestEnvelopeText(unittest.TestCase):

    def test_range_enum_and_unbounded(self):
        knobs = [
            {"setting": "shared_buffers", "initial": "128MB",
             "envelope": {"min": "64MB", "max": "256MB"}},
            {"setting": "max_wal_size", "initial": "1GB", "envelope": {"max": "1GB"}},
            {"setting": "work_mem", "initial": "4MB", "envelope": {"min": "1MB"}},
            {"setting": "autovacuum", "initial": "on", "envelope": {"allowed": ["on"]}},
            {"setting": "wal_level", "initial": "replica",
             "envelope": {"allowed": ["replica", "logical"]}},
            {"setting": "fsync", "initial": True, "envelope": {"allowed": [True]}},
        ]
        lines = [l for l in render.envelope_text("db", knobs).splitlines()
                 if l and not l.startswith("#")]
        self.assertEqual(lines, [
            "shared_buffers range 64MB 256MB",
            "max_wal_size range - 1GB",
            "work_mem range 1MB -",
            "autovacuum enum on",
            "wal_level enum replica,logical",
            "fsync enum on",
        ])


class TestEnvironment(unittest.TestCase):

    def test_gm_parameters(self):
        brick = {"parameters": {
            "db_name": {"description": "d", "default": "shop", "required": False},
            "unset": {"description": "d", "default": None, "required": False},
            "port": {"description": "d", "default": 5432, "required": False},
        }}
        node = {"parameters": {"port": 6543}}
        self.assertEqual(render.service_environment(brick, node),
                         {"TZ": "UTC", "GM_DB_NAME": "shop", "GM_PORT": "6543"})

    def test_utc_without_parameters(self):
        self.assertEqual(render.service_environment({}, {}), {"TZ": "UTC"})


class RenderedFixture(ScenarioCopyTest):

    def setUp(self):
        super().setUp()
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.ldir = self.scenario / "local" / "laptop"
        self.result = render.render(self.scenario, "laptop")
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.stack_text = (self.ldir / "stack.yml").read_text()
        self.stack = yaml.safe_load(self.stack_text)


class TestRender(RenderedFixture):

    def test_files_and_stage(self):
        self.assertTrue((self.ldir / "stack.yml").is_file())
        self.assertTrue((self.ldir / "envelopes" / "db.conf").is_file())
        self.assertFalse((self.ldir / "envelopes" / "bastion.conf").exists())
        state = localimpl.read_state(self.ldir)
        self.assertEqual(state["stage"], "rendered")
        self.assertEqual([h["stage"] for h in state["history"]], ["fitted", "rendered"])

    def test_envelope_file(self):
        text = (self.ldir / "envelopes" / "db.conf").read_text()
        rules = [l for l in text.splitlines() if l and not l.startswith("#")]
        self.assertEqual(rules, [
            "shared_buffers range 64MB 256MB",
            "work_mem range 1MB 64MB",
            "maintenance_work_mem range 16MB 256MB",
            "max_connections range 10 200",
            "max_wal_size range 64MB 1GB",
            "autovacuum enum on",
        ])

    def test_compose_version_and_services(self):
        self.assertEqual(self.stack["version"], "3.8")
        self.assertEqual(list(self.stack["services"]), ["bastion", "db"])

    def test_every_name_carries_the_game_id(self):
        s = self.stack
        for section in ("volumes", "configs", "secrets"):
            for key, decl in s[section].items():
                with self.subTest(section=section, key=key):
                    self.assertTrue(decl["name"].startswith(self.gid + "_"))
                    self.assertTrue(key.startswith(self.gid + "_"))
        # the scenario's network: <game_id>_backend once deployed as stack <game_id>
        self.assertEqual(list(s["networks"]), ["backend"])
        for svc in s["services"].values():
            for v in svc["volumes"]:
                self.assertIn(v["source"], s["volumes"])
            for c in svc["configs"]:
                self.assertIn(c["source"], s["configs"])
            for c in svc["secrets"]:
                self.assertIn(c["source"], s["secrets"])
        # everything gmctl deploy creates is named in implementation.yaml
        impl_configs = {c["name"] for n in self.impl["nodes"].values() for c in n["configs"]}
        self.assertEqual(impl_configs, set(s["configs"]))
        self.assertEqual({x["name"] for x in self.impl["secrets"]}, set(s["secrets"]))

    def test_external_configs_and_secrets(self):
        for section in ("configs", "secrets"):
            for decl in self.stack[section].values():
                self.assertIs(decl["external"], True)
        self.assertEqual(len([k for k in self.stack["secrets"] if k.endswith("_dba_password")]), 1)

    def test_volume_labels(self):
        for name, decl in self.stack["volumes"].items():
            self.assertEqual(decl["name"], name)
            self.assertEqual(decl["labels"], {"dbagm.game": self.gid})

    def test_hardening_and_mounts(self):
        db = self.stack["services"]["db"]
        self.assertIs(db["read_only"], True)
        self.assertEqual(db["cap_drop"], ["ALL"])
        self.assertEqual(db["cap_add"], ["AUDIT_WRITE", "CHOWN", "DAC_OVERRIDE", "FOWNER",
                                         "KILL", "NET_BIND_SERVICE", "SETGID", "SETUID",
                                         "SYS_CHROOT"])
        self.assertNotIn("tmpfs", self.stack_text)
        self.assertEqual(db["hostname"], "db")
        self.assertEqual([(v["type"], v["target"]) for v in db["volumes"]], [
            ("volume", "/var/lib/postgresql/18/data"), ("volume", "/etc/postgresql"),
            ("volume", "/home/player"), ("volume", "/var/lib/gm-state"), ("volume", "/run")])
        configs = {c["target"]: c for c in db["configs"]}
        self.assertEqual(configs["/opt/gm/seed/postgresql.conf"]["mode"], 0o444)
        self.assertEqual(configs["/opt/gm/protected/envelopes.conf"]["source"],
                         self.gid + "_db_envelopes")
        self.assertEqual(configs["/opt/gm/seed/pg_hba.conf"]["uid"], "0")
        secrets = {c["target"]: c for c in db["secrets"]}
        self.assertEqual(secrets["/opt/gm/secrets/dba_password"]["mode"], 0o400)
        self.assertEqual(secrets["/opt/gm/secrets/player_ssh_pubkey"]["mode"], 0o444)
        self.assertEqual(db["healthcheck"]["test"],
                         ["CMD", "/bin/sh", "-c", "/usr/local/lib/gm/healthcheck"])
        self.assertEqual(db["healthcheck"]["start_period"], "60s")
        self.assertNotIn("ports", db)
        self.assertEqual(db["networks"], ["backend"])
        bastion = self.stack["services"]["bastion"]
        self.assertEqual([v["target"] for v in bastion["volumes"]],
                         ["/home/player", "/var/lib/gm-sshd-keys", "/run"])
        self.assertEqual(sorted(c["target"] for c in bastion["configs"]), [
            "/opt/gm/starter/README.md", "/opt/gm/starter/issues.md",
            "/opt/gm/starter/story.md"])
        self.assertEqual(bastion["ports"], [
            {"target": 22, "published": 2222, "protocol": "tcp", "mode": "host"}])

    def test_deploy_section(self):
        db = self.stack["services"]["db"]["deploy"]
        self.assertEqual(db["replicas"], 1)
        self.assertEqual(db["placement"]["constraints"], ["node.role == manager"])
        self.assertEqual(db["resources"], {
            "limits": {"cpus": "1", "memory": "1G"},
            "reservations": {"cpus": "0.5", "memory": "512M"}})

    def test_network(self):
        self.assertEqual(self.stack["networks"],
                         {"backend": {"driver": "overlay", "attachable": False}})
        for svc in self.stack["services"].values():
            self.assertEqual(svc["networks"], ["backend"])

    def test_every_service_runs_in_utc(self):
        for name, svc in self.stack["services"].items():
            self.assertEqual(svc["environment"]["TZ"], "UTC", name)

    @unittest.skipUnless(shutil.which("docker"), "docker not installed")
    def test_docker_stack_config_accepts(self):
        r = subprocess.run(["docker", "stack", "config", "-c", str(self.ldir / "stack.yml")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


class TestRenderRefusals(ScenarioCopyTest):

    def test_needs_a_fit_first(self):
        with self.assertRaises(model.GmError):
            render.render(self.scenario, "laptop")

    def test_refuses_after_deploy(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        ldir = self.scenario / "local" / "laptop"
        localimpl.set_stage(ldir, "rendered")
        localimpl.set_stage(ldir, "deployed")
        with self.assertRaises(model.GmError):
            render.render(self.scenario, "laptop")

    def test_refuses_incomplete_scenario(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.edit_yaml("scenario.yaml", lambda d: d.pop("flows"))
        with self.assertRaises(model.IncompleteScenario):
            render.render(self.scenario, "laptop")


class TestGmctlRender(ScenarioCopyTest):

    def test_cli(self):
        r = run_gmctl("fit", self.scenario, "--playground", "laptop",
                      "--cpu", "2", "--memory", "4G", "--disk", "20G")
        self.assertEqual(r.returncode, 0, r.stderr)
        r = run_gmctl("render", self.scenario, "--playground", "laptop")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("stack.yml", r.stdout)
        r = run_gmctl("render", self.scenario, "--playground", "nowhere")
        self.assertEqual(r.returncode, 1)


if __name__ == "__main__":
    unittest.main()
