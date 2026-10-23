"""Stack file and envelope file rendering (tools/gm/render.py)."""

import shutil
import subprocess
import unittest

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import FIXTURES, SUFFICIENT, ScenarioCopyTest, run_gmctl


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

    # Shaped parameters (v0.2 capture W1, item 2).

    def test_node_map_is_never_passed(self):
        brick = {"parameters": {
            "node_health": {"description": "d", "default": None, "required": True,
                            "shape": "node-map"},
            "port": {"description": "d", "default": 9090, "required": False}}}
        node = {"parameters": {"node_health": {"db": "default", "app": ["app", "sshd"]}}}
        self.assertEqual(render.service_environment(brick, node),
                         {"TZ": "UTC", "GM_PORT": "9090"})

    def test_web_routes_sorted_by_name(self):
        brick = {"parameters": {"web_routes": {"description": "d", "default": {},
                                               "required": False, "shape": "web-routes"}}}
        node = {"parameters": {"web_routes": {"prometheus": "prometheus:9090",
                                              "grafana": "grafana:3000"}}}
        self.assertEqual(render.service_environment(brick, node), {
            "TZ": "UTC",
            "GM_WEB_ROUTES": "grafana=grafana:3000 prometheus=prometheus:9090"})

    def test_web_routes_empty_map(self):
        brick = {"parameters": {"web_routes": {"description": "d", "default": {},
                                               "required": False, "shape": "web-routes"}}}
        self.assertEqual(render.service_environment(brick, {}),
                         {"TZ": "UTC", "GM_WEB_ROUTES": ""})
        self.assertEqual(render.service_environment(brick, {"parameters": {"web_routes": {}}}),
                         {"TZ": "UTC", "GM_WEB_ROUTES": ""})

    def test_scalars_unchanged_beside_shaped(self):
        brick = {"parameters": {
            "flag": {"description": "d", "default": True, "required": False},
            "web_routes": {"description": "d", "default": {}, "required": False,
                           "shape": "web-routes"}}}
        self.assertEqual(render.service_environment(brick, {"parameters": {"flag": False}}),
                         {"TZ": "UTC", "GM_FLAG": "false", "GM_WEB_ROUTES": ""})


MOUNTED_FIXTURE = FIXTURES / "fixture-mounted"
NODE_HEALTH_FILES = [
    ("bricks/fixture-monitor/companion/node-health/node-health.sh",
     "/usr/local/lib/gm/node-health/node-health.sh", "0555"),
    ("bricks/fixture-monitor/companion/node-health/s6/run",
     "/etc/s6-overlay/s6-rc.d/gm-node-health/run", "0555"),
]
NODE_CONF = "/opt/gm/node-health/node.conf"


class MountedCopyTest(ScenarioCopyTest):
    """Each test works on a fresh copy of fixture-mounted (scenario-local
    bricks mounting node-health into every node; f2 leaves `app` out of
    the map, a parameter fault)."""

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-mounted"
        shutil.copytree(MOUNTED_FIXTURE, self.scenario)

    def f2_node(self, node):
        def change(d):
            next(i for i in d["fault_instances"] if i["id"] == "f2")["parameters"]["node"] = node
        self.edit_yaml("scenario.yaml", change)

    def f2_changes(self, changes):
        self.edit_yaml("faults/fixture-node-left-out/fault.yaml",
                       lambda d: d["injection"].update(parameter_changes=changes))


class TestNodeParameters(MountedCopyTest):
    """localimpl.node_parameters: parameter faults applied (capture W1, item 8)."""

    def test_remove_entry(self):
        sc = model.load_scenario(self.scenario)
        params = localimpl.node_parameters(sc)
        self.assertEqual(list(params), ["bastion", "app", "monitor"])
        self.assertEqual(params["monitor"]["node_health"],
                         {"bastion": "default", "monitor": "default"})
        self.assertEqual(params["bastion"], {"web_routes": {"monitor": "monitor:9090"}})
        self.assertEqual(params["app"], {})
        # the scenario itself is left as written
        self.assertIn("app", sc.node("monitor")["parameters"]["node_health"])

    def test_remove_from_a_default_entry_expands_it_first(self):
        self.f2_changes([{"parameter": "node_health", "op": "remove-from-entry",
                          "entry": "{NODE}", "item": "sshd", "change": "sshd unwatched"}])
        self.f2_node("bastion")
        params = localimpl.node_parameters(model.load_scenario(self.scenario))
        self.assertEqual(params["monitor"]["node_health"],
                         {"bastion": ["web-front"], "app": ["app", "sshd"],
                          "monitor": "default"})

    def test_remove_from_a_list_entry(self):
        self.f2_changes([{"parameter": "node_health", "op": "remove-from-entry",
                          "entry": "{NODE}", "item": "sshd", "change": "sshd unwatched"}])
        params = localimpl.node_parameters(model.load_scenario(self.scenario))
        self.assertEqual(params["monitor"]["node_health"]["app"], ["app"])

    def test_set_a_scalar(self):
        sc = model.load_scenario(self.scenario)
        sc.bricks["monitor"].data["parameters"]["retention"] = {
            "description": "d", "default": "1d", "required": False}
        sc.faults["f2"].data["injection"]["parameter_changes"] = [
            {"parameter": "retention", "op": "set", "value": "{NODE}-1h", "change": "c"}]
        params = localimpl.node_parameters(sc)
        self.assertEqual(params["monitor"]["retention"], "app-1h")
        env = render.service_environment(sc.bricks["monitor"].data,
                                         {"parameters": params["monitor"]})
        self.assertEqual(env, {"TZ": "UTC", "GM_RETENTION": "app-1h"})

    def test_a_change_that_plants_nothing_is_refused(self):
        sc = model.load_scenario(self.scenario)
        change = {"parameter": "node_health", "op": "remove-entry", "entry": "{NODE}"}
        sc.faults["f2"].data["injection"]["parameter_changes"] = [change, dict(change)]
        with self.assertRaisesRegex(model.GmError, r"fault instance f2 .*node_health has no "
                                                   r"entry app"):
            localimpl.node_parameters(sc)
        sc.faults["f2"].data["injection"]["parameter_changes"] = [
            {"parameter": "node_health", "op": "remove-from-entry", "entry": "{NODE}",
             "item": "web-front"}]
        with self.assertRaisesRegex(model.GmError, r"entry app of node_health has no "
                                                   r"item web-front"):
            localimpl.node_parameters(sc)


class RenderedMounted(MountedCopyTest):

    def fit_render(self):
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.ldir = self.scenario / "local" / "laptop"
        self.result = render.render(self.scenario, "laptop")
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.stack = yaml.safe_load((self.ldir / "stack.yml").read_text())

    def mounted(self, node):
        return [c for c in self.impl["nodes"][node]["configs"]
                if c["kind"] in ("mounted", "node-config")]

    def node_conf(self, node):
        conf = next(c for c in self.mounted(node) if c["kind"] == "node-config")
        return (self.scenario / conf["file"]).read_text()


class TestMountedMaterial(RenderedMounted):

    def expected(self, node):
        files = [{"kind": "mounted", "item": "node-health",
                  "name": f"{self.gid}_monitor_node-health-{k}", "file": source,
                  "path": target, "uid": 0, "gid": 0, "mode": mode}
                 for k, (source, target, mode) in enumerate(NODE_HEALTH_FILES, 1)]
        return files + [{"kind": "node-config", "item": "node-health",
                         "name": f"{self.gid}_{node}_node-health.conf",
                         "file": f"local/laptop/mounted/node-health/{node}.conf",
                         "path": NODE_CONF, "uid": 0, "gid": 0, "mode": "0444"}]

    def test_every_node_of_the_map_and_only_them(self):
        self.fit_render()       # f2 leaves app out of the map
        self.assertEqual(self.mounted("bastion"), self.expected("bastion"))
        self.assertEqual(self.mounted("monitor"), self.expected("monitor"))
        self.assertEqual(self.mounted("app"), [])
        self.assertFalse((self.ldir / "mounted" / "node-health" / "app.conf").exists())
        self.assertEqual(self.impl["parameter_faults"], [
            {"instance": "f2", "fault": "fixture-node-left-out", "node": "monitor",
             "changes": [{"parameter": "node_health", "op": "remove-entry",
                          "entry": "app"}]}])

    def test_another_node_left_out(self):
        self.f2_node("monitor")
        self.fit_render()
        self.assertEqual(self.mounted("app"), self.expected("app"))
        self.assertEqual(self.mounted("bastion"), self.expected("bastion"))
        self.assertEqual(self.mounted("monitor"), [])

    def test_node_configs(self):
        self.fit_render()
        self.assertEqual(self.node_conf("monitor"),
                         "node=monitor\nservices=monitor\ndisk_reservation=536870912\n"
                         "volumes=/var/lib/monitor\n")
        self.assertEqual(self.node_conf("bastion"),
                         "node=bastion\nservices=sshd web-front\n"
                         "disk_reservation=268435456\nvolumes=\n")
        self.assertIn(f"  {self.ldir}/mounted/node-health/monitor.conf", self.result.text())

    def test_a_service_left_out_of_an_entry(self):
        self.f2_changes([{"parameter": "node_health", "op": "remove-from-entry",
                          "entry": "{NODE}", "item": "sshd", "change": "sshd unwatched"}])
        self.fit_render()
        self.assertEqual(self.node_conf("app"),
                         "node=app\nservices=app\ndisk_reservation=536870912\n"
                         "volumes=/var/lib/app\n")
        self.assertEqual(self.mounted("app"), self.expected("app"))

    def test_no_config_is_empty(self):
        self.fit_render()
        for node in self.impl["nodes"].values():
            for config in node["configs"]:
                path = self.scenario / config["file"]
                self.assertGreater(path.stat().st_size, 0, config["name"])

    def test_an_empty_mounted_file_is_refused(self):
        (self.scenario / NODE_HEALTH_FILES[1][0]).write_text("")
        with self.assertRaisesRegex(model.GmError, r"s6/run is empty"):
            fit.fit(self.scenario, "laptop", **SUFFICIENT)

    def test_stack_mounts(self):
        self.fit_render()
        svc = self.stack["services"]
        for node in ("bastion", "monitor"):
            mounts = {c["target"]: c for c in svc[node]["configs"]}
            self.assertEqual(mounts["/etc/s6-overlay/s6-rc.d/gm-node-health/run"], {
                "source": f"{self.gid}_monitor_node-health-2",
                "target": "/etc/s6-overlay/s6-rc.d/gm-node-health/run",
                "uid": "0", "gid": "0", "mode": 0o555})
            self.assertEqual(mounts[NODE_CONF]["source"], f"{self.gid}_{node}_node-health.conf")
            self.assertEqual(mounts[NODE_CONF]["mode"], 0o444)
        self.assertEqual(svc["app"]["configs"], [])
        # each mounted file is one config, shared by the nodes receiving it
        self.assertEqual(sorted(self.stack["configs"]), sorted(
            [f"{self.gid}_monitor_node-health-1", f"{self.gid}_monitor_node-health-2",
             f"{self.gid}_bastion_node-health.conf", f"{self.gid}_monitor_node-health.conf"]))

    def test_shaped_parameters_in_the_stack(self):
        self.fit_render()
        env = {name: s["environment"] for name, s in self.stack["services"].items()}
        self.assertEqual(env["bastion"], {"TZ": "UTC", "GM_WEB_ROUTES": "monitor=monitor:9090"})
        self.assertEqual(env["monitor"], {"TZ": "UTC"})
        self.assertEqual(env["app"], {"TZ": "UTC", "GM_LISTEN_PORT": "8000"})

    def test_catalog_brick_files_relative_to_the_scenario(self):
        sc = model.load_scenario(self.scenario)
        sc.bricks["monitor"] = model.find_definition(
            "brick", "prometheus", "0.2.0", sc.dir, model.REPO_ROOT)[0]
        configs = localimpl.mounted_configs(sc, localimpl.node_parameters(sc), "laptop", "g")
        files = [c for c in configs["bastion"] if c["kind"] == "mounted"]
        self.assertEqual(len(files), 5)
        for c in files:
            self.assertFalse(c["file"].startswith("/"))
            self.assertTrue((sc.dir / c["file"]).is_file(), c["file"])
        self.assertEqual(files[0]["name"], "g_monitor_node-health-1")

    def test_refit_needed_when_the_map_changes(self):
        self.fit_render()
        self.f2_node("bastion")
        with self.assertRaisesRegex(model.GmError, "mounted material changed since gmctl fit: "
                                                   "fit again"):
            render.render(self.scenario, "laptop")

    @unittest.skipUnless(shutil.which("docker"), "docker not installed")
    def test_docker_stack_config_accepts(self):
        self.fit_render()
        r = subprocess.run(["docker", "stack", "config", "-c", str(self.ldir / "stack.yml")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)


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
            ("volume", "/home/player"), ("volume", "/var/lib/gm-state"),
            ("volume", "/var/log/postgresql"), ("volume", "/run")])
        configs = {c["target"]: c for c in db["configs"]}
        self.assertEqual(configs["/opt/gm/seed/postgresql.conf"]["mode"], 0o444)
        self.assertEqual(configs["/opt/gm/protected/envelopes.conf"]["source"],
                         self.gid + "_db_envelopes")
        self.assertEqual(configs["/opt/gm/seed/pg_hba.conf"]["uid"], "0")
        secrets = {c["target"]: c for c in db["secrets"]}
        self.assertEqual(secrets["/opt/gm/secrets/dba_password"]["mode"], 0o400)
        self.assertEqual(secrets["/opt/gm/secrets/player_ssh_pubkey"]["mode"], 0o444)
        self.assertEqual((secrets["/opt/gm/secrets/monitoring_password"]["gid"],
                          secrets["/opt/gm/secrets/monitoring_password"]["mode"]), ("102", 0o440))
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
