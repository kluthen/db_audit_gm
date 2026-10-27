"""Stack file and envelope file rendering (tools/gm/render.py)."""

import datetime
import shutil
import subprocess
import sys
import unittest

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import FIXTURES, SUFFICIENT, FakeDocker, ScenarioCopyTest, run_gmctl


MANAGER, WORKER = "armenelos", "vps-5718ad52"
VPS_ENDPOINT = "ssh://debian@100.126.172.117"


def two_hosts(manager_memory="4G", worker_memory="4G", worker_disk="20G"):
    """`--host` options for armenelos (the manager) and the VPS."""
    return [f"{MANAGER},manager,cpu=2,memory={manager_memory},disk=20G",
            f"{WORKER},endpoint={VPS_ENDPOINT},cpu=2,memory={worker_memory},disk={worker_disk}"]


def two_host_engine(**kwargs):
    """The manager's engine, the VPS listed as a drained worker."""
    return FakeDocker(name=MANAGER, nodes={MANAGER: ("Ready", "Active", "Leader"),
                                           WORKER: ("Ready", "Drain", "")}, **kwargs)


class TwoHostScenario(ScenarioCopyTest):
    """fixture-audit designed for two hosts: the bastion on host-1, db on host-2."""

    def setUp(self):
        super().setUp()

        def two(data):
            data["designed_for"]["hosts"].append({"name": "host-2", "cpu": 2, "memory": "4G",
                                                  "disk": "20G"})
            data["designed_for"]["placement"]["db"] = "host-2"
        self.edit_yaml("scenario.yaml", two)
        self.ldir = self.scenario / "local" / "duo"

    def fit(self, hosts=None, mapping=("host-1=" + MANAGER, "host-2=" + WORKER), engine=None,
            **kwargs):
        return fit.fit(self.scenario, "duo", docker=engine or two_host_engine(),
                       hosts=two_hosts() if hosts is None else hosts, mapping=list(mapping),
                       **kwargs)

    def refused(self, pattern, **kwargs):
        with self.assertRaisesRegex(model.GmError, pattern):
            self.fit(**kwargs)
        self.assertFalse(self.ldir.exists())


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
        policy = {"GM_WRITE_POLICY": "report-only", "GM_WRITE_OVERRIDES": ""}
        self.assertEqual(env["bastion"], {"TZ": "UTC", **policy,
                                          "GM_WEB_ROUTES": "monitor=monitor:9090"})
        self.assertEqual(env["monitor"], {"TZ": "UTC", **policy})
        self.assertEqual(env["app"], {"TZ": "UTC", **policy, "GM_LISTEN_PORT": "8000"})

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
        # every node pinned to the host fit placed it on: on one host, the engine's name
        self.assertEqual(db["placement"]["constraints"], ["node.hostname == gm-host"])
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


class TestPlacement(TwoHostScenario):

    def test_every_node_pinned_to_its_host_the_bastion_with_its_ports(self):
        self.fit()
        render.render(self.scenario, "duo")
        stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        constraints = {name: svc["deploy"]["placement"]["constraints"]
                       for name, svc in stack["services"].items()}
        self.assertEqual(constraints, {"bastion": [f"node.hostname == {MANAGER}"],
                                       "db": [f"node.hostname == {WORKER}"]})
        self.assertEqual(stack["services"]["bastion"]["ports"][0]["mode"], "host")

    def test_an_implementation_fitted_before_placement_is_refused(self):
        self.fit()
        impl = localimpl.read_implementation(self.ldir)
        del impl["nodes"]["db"]["host"]
        localimpl.write_implementation(self.ldir, impl)
        with self.assertRaisesRegex(model.GmError, r"node\(s\) db have no host .*fit again"):
            render.render(self.scenario, "duo")


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


# --- v0.3: the planned hand-over, the shift, the time zone (W2 item 1) -----

UTC = datetime.timezone.utc
V03_FIXTURE = FIXTURES / "fixture-v03-refusals"
SCHEDULER_PROGRAM = FIXTURES.parents[2] / "bricks" / "scheduler" / "program"


def handover_at(hour, days=2):
    """`--handover` for `hour` UTC, `days` from today (always in the future)."""
    day = datetime.datetime.now(UTC).date() + datetime.timedelta(days=days)
    return f"{day.isoformat()}T{hour:02d}:00Z"


def scheduler_parsers():
    """The scheduler program's own parsers of its rendered files, or None."""
    sys.path.insert(0, str(SCHEDULER_PROGRAM))
    try:
        from gm_scheduler import jobs, schedule
        return schedule.parse_schedule, jobs.parse_jobs
    except ImportError:
        return None
    finally:
        sys.path.remove(str(SCHEDULER_PROGRAM))


class TestShift(unittest.TestCase):
    """The shift and the customer's time zone (master spec 8.3)."""

    def test_several_planned_hours(self):
        # designed hand-over 14:00 (fixture-v03-refusals)
        for planned, shift in ((14, 0), (16, -2), (12, 2), (9, 5), (1, -11), (3, 11),
                               (2, 12), (0, -10), (23, -9)):
            self.assertEqual(render.compute_shift(14, planned), shift, planned)
        self.assertEqual(render.compute_shift(2, 14), 12)       # -12 reads +12
        self.assertEqual(render.compute_shift(0, 23), 1)
        for designed in range(24):
            for planned in range(24):
                shift = render.compute_shift(designed, planned)
                self.assertTrue(-11 <= shift <= 12)
                self.assertEqual((planned + shift) % 24, designed)

    def test_customer_timezone(self):
        self.assertEqual(render.customer_timezone(2), {"zone": "Etc/GMT-2", "reading": "UTC+2"})
        self.assertEqual(render.customer_timezone(-5), {"zone": "Etc/GMT+5", "reading": "UTC-5"})
        self.assertEqual(render.customer_timezone(0), {"zone": "Etc/GMT", "reading": "UTC+0"})
        self.assertEqual(render.customer_timezone(12), {"zone": "Etc/GMT-12", "reading": "UTC+12"})
        self.assertEqual(render.customer_timezone_text(render.customer_timezone(2)),
                         "UTC+2 (Etc/GMT-2)")

    def test_handover_forms(self):
        self.assertEqual(render.parse_handover("2026-10-27T14:00Z"),
                         datetime.datetime(2026, 10, 27, 14, tzinfo=UTC))
        self.assertEqual(render.parse_handover("2026-10-27T14:00:00Z"),
                         datetime.datetime(2026, 10, 27, 14, tzinfo=UTC))
        for bad in ("2026-10-27T14:30Z", "2026-10-27T14:00:05Z", "2026-10-27 14:00",
                    "2026-10-27T14:00", "2026-02-30T14:00Z", "14:00", ""):
            with self.assertRaises(model.GmError, msg=bad):
                render.parse_handover(bad)


class TestRenderedJobs(unittest.TestCase):
    """jobs.yaml in UTC (W1 item 7; D168)."""

    def test_a_jobs_utc_time(self):
        self.assertEqual(render.shift_cron("30 1 * * *", -2), "30 3 * * *")
        self.assertEqual(render.shift_cron("30 1 * * *", 2), "30 23 * * *")
        self.assertEqual(render.shift_cron("*/15 8,12,18 * * *", -2), "*/15 10,14,20 * * *")
        self.assertEqual(render.shift_cron("0 22,23 * * *", -3), "0 1,2 * * *")
        self.assertEqual(render.shift_cron("5,35 * * * *", 4), "5,35 * * * *")

    def test_the_day_of_week_follows_a_wrapping_hour(self):
        self.assertEqual(render.shift_cron("0 1 * * 1", 2), "0 23 * * 0")       # Mon -> Sun
        self.assertEqual(render.shift_cron("0 23 * * 6", -2), "0 1 * * 0")      # Sat -> Sun
        self.assertEqual(render.shift_cron("0 6 * * 1,5", -2), "0 8 * * 1,5")
        self.assertEqual(render.shift_cron("0 0 * * 0", 12), "0 12 * * 6")

    def test_a_wrong_zone_job_keeps_its_time(self):
        doc = {"jobs": [{"name": "close-day", "key": "k", "connection": "app",
                         "at": "30 1 * * *", "timezone_offset": -2},
                        {"name": "sweep", "key": "k", "connection": "app", "at": "0 8 * * *"}]}
        self.assertEqual(render.render_jobs(doc, 3), {"jobs": [
            {"name": "close-day", "key": "k", "connection": "app", "at": "30 1 * * *",
             "timezone": "Etc/GMT-1"},
            {"name": "sweep", "key": "k", "connection": "app", "at": "0 5 * * *"}]})

    def test_a_wrong_zone_job_wrapped_across_utc_plus_14(self):
        def zone(shift, offset):
            doc = {"jobs": [{"name": "j", "key": "k", "connection": "c", "at": "30 1 * * *",
                             "timezone_offset": offset}]}
            return render.render_jobs(doc, shift)["jobs"][0]["timezone"]
        self.assertEqual(zone(12, 2), "Etc/GMT-14")        # UTC+14: inside, kept
        self.assertEqual(zone(12, 3), "Etc/GMT+9")         # UTC+15 wraps to UTC-9
        self.assertEqual(zone(11, 5), "Etc/GMT+8")         # UTC+16 wraps to UTC-8
        self.assertEqual(zone(-11, -1), "Etc/GMT+12")      # UTC-12: inside, kept
        self.assertEqual(zone(-11, -2), "Etc/GMT-11")      # UTC-13 wraps to UTC+11
        self.assertEqual(zone(2, -2), "Etc/GMT")           # the customer's zone minus 2: UTC+0
        self.assertEqual(render.wrap_offset(15), -9)


class TestRenderedShapes(unittest.TestCase):

    def test_hours_shift_into_the_previous_utc_day(self):
        hours = {"00-06": 0.1, "07-08": 0.6, "09-11": 1.0, "12": 1.6, "13-17": 1.0,
                 "18-23": 0.3}
        utc = render.render_shape({"hours": hours}, 2)["utc"]
        self.assertEqual(list(utc), ["mon", "tue", "wed", "thu", "fri", "sat", "sun"])
        # UTC 10:00 is 12:00 at UTC+2; UTC 22:00 is 00:00 the next day
        self.assertEqual(utc["mon"][10], 1.6)
        self.assertEqual(utc["mon"][22], 0.1)
        self.assertEqual(utc["mon"][21], 0.3)
        self.assertTrue(all(len(day) == 24 for day in utc.values()))

    def test_weekdays_wrap_with_the_hour(self):
        shape = {"days": {"mon-fri": {"hours": {"00-23": 1.0}},
                          "sat-sun": {"hours": {"00-23": 0.2}}}}
        utc = render.render_shape(shape, -2)["utc"]       # customer at UTC-2
        # UTC Monday 01:00 is Sunday 23:00 there; Monday 02:00 is Monday 00:00
        self.assertEqual(utc["mon"][:3], [0.2, 0.2, 1.0])
        self.assertEqual(utc["sat"][:3], [1.0, 1.0, 0.2])
        utc = render.render_shape(shape, 3)["utc"]        # UTC+3
        # UTC Friday 21:00 is Saturday 00:00 there
        self.assertEqual(utc["fri"][20:], [1.0, 0.2, 0.2, 0.2])
        self.assertEqual(utc["sun"][20:], [0.2, 1.0, 1.0, 1.0])


class TestTimelineMoments(unittest.TestCase):

    def test_moments_from_the_planned_handover(self):
        planned = datetime.datetime(2026, 10, 27, 14, tzinfo=UTC)
        rendered_at = "2026-10-26T19:40:12Z"
        self.assertEqual(render.moment_instant("handover-6h", planned, rendered_at),
                         "2026-10-27T08:00:00Z")
        self.assertEqual(render.moment_instant("handover-16h", planned, rendered_at),
                         "2026-10-26T22:00:00Z")
        # T0 is not known at render; the render time precedes any load start
        self.assertEqual(render.moment_instant("T0", planned, rendered_at), rendered_at)


class V03Rendered(ScenarioCopyTest):
    """A fresh copy of fixture-v03-refusals (a scheduler node, aging 16h,
    hand-over designed at 14:00), fitted."""

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-v03-refusals"
        shutil.copytree(V03_FIXTURE, self.scenario)
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        self.ldir = self.scenario / "local" / "laptop"

    def render(self, handover=None):
        self.result = render.render(self.scenario, "laptop", handover=handover)
        self.impl = localimpl.read_implementation(self.ldir)
        self.gid = self.impl["game_id"]
        self.stack = yaml.safe_load((self.ldir / "stack.yml").read_text())
        return self.result

    def rendered(self, node, fname):
        return self.ldir / "rendered" / node / fname

    def config(self, node, suffix):
        return next(c for c in self.impl["nodes"][node]["configs"]
                    if c["name"] == f"{self.gid}_{node}_{suffix}")


class TestRenderV03(V03Rendered):

    def test_handover_is_required_with_scheduler_nodes(self):
        with self.assertRaisesRegex(model.GmError, "--handover"):
            render.render(self.scenario, "laptop")
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "fitted")

    def test_a_past_handover_is_refused(self):
        past = (datetime.datetime.now(UTC) - datetime.timedelta(hours=1)).strftime(
            "%Y-%m-%dT%H:00Z")
        with self.assertRaisesRegex(model.GmError, "not in the future"):
            render.render(self.scenario, "laptop", handover=past)
        self.assertFalse((self.ldir / "stack.yml").exists())

    def test_timeline_records(self):
        handover = handover_at(16)
        self.render(handover)
        tl = self.impl["timeline"]
        self.assertEqual(list(tl), ["planned_handover", "designed_handover", "shift",
                                    "customer_timezone", "seed", "aging_minimum", "instances",
                                    "rendered_at"])
        planned = render.parse_handover(handover)
        self.assertEqual(tl["planned_handover"], render.iso(planned))
        self.assertEqual(tl["designed_handover"], "14:00")
        self.assertEqual(tl["shift"], -2)
        self.assertEqual(tl["customer_timezone"], {"zone": "Etc/GMT+2", "reading": "UTC-2"})
        self.assertTrue(0 <= tl["seed"] < 2 ** 63)
        self.assertEqual(tl["aging_minimum"], "16h")
        six_before = render.iso(planned - datetime.timedelta(hours=6))
        self.assertEqual(tl["instances"], {
            "f1": {"plant_at": "T0", "planned_at": None, "aging_minimum": "0m"},
            "f2": {"plant_at": "handover-6h", "planned_at": six_before, "aging_minimum": "2h"},
            "f3": {"plant_at": "T0", "planned_at": None, "aging_minimum": "1h"},
        })
        self.assertRegex(tl["rendered_at"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$")
        self.assertIn("shift -2, customer's time zone UTC-2 (Etc/GMT+2)", self.result.text())
        self.assertIsNone(self.result.warning)

    def test_the_seed_is_kept_by_a_re_render(self):
        self.render(handover_at(16))
        seed = self.impl["timeline"]["seed"]
        self.render(handover_at(9, days=3))
        self.assertEqual(self.impl["timeline"]["seed"], seed)
        self.assertEqual(self.impl["timeline"]["shift"], 5)
        schedule = yaml.safe_load(self.rendered("producer", "schedule.yaml").read_text())
        self.assertEqual(schedule["seed"], seed)

    def test_rendered_files_named_from_fit_on(self):
        rel = "local/laptop/rendered/"
        fitted = localimpl.read_implementation(self.ldir)["nodes"]
        self.assertEqual(
            [c["file"] for c in fitted["producer"]["configs"]],
            [rel + "producer/schedule.yaml", "nodes/producer/queries.yaml",
             "nodes/producer/builders/revenue.py", rel + "producer/jobs.yaml"])
        self.assertEqual([c["file"] for c in fitted["bastion"]["configs"]],
                         [rel + "bastion/README.md", rel + "bastion/story.md",
                          "player/issues.md"])
        self.render(handover_at(16))
        for node, fname in (("producer", "schedule.yaml"), ("producer", "jobs.yaml"),
                            ("bastion", "README.md"), ("bastion", "story.md")):
            self.assertTrue(self.rendered(node, fname).is_file(), fname)
        self.assertFalse(self.rendered("bastion", "issues.md").exists())
        self.assertEqual(sorted(p.name for p in (self.ldir / "rendered").iterdir()),
                         ["bastion", "producer"])

    def test_the_time_zone_filled_in_the_story(self):
        self.render(handover_at(12))                     # shift +2
        story = self.rendered("bastion", "story.md").read_text()
        self.assertNotIn("{{customer_timezone}}", story)
        self.assertIn("A small shop in UTC+2 (Etc/GMT-2) takes orders", story)
        readme = self.rendered("bastion", "README.md").read_text()
        self.assertIn("are the customer's, UTC+2 (Etc/GMT-2).", readme)
        # the scenario's own files are left as written
        self.assertIn("{{customer_timezone}}", (self.scenario / "player/story.md").read_text())

    def test_rendered_jobs_and_schedule(self):
        handover = handover_at(16)                       # shift -2: the customer at UTC-2
        self.render(handover)
        jobs = yaml.safe_load(self.rendered("producer", "jobs.yaml").read_text())
        self.assertEqual(jobs, {"jobs": [
            {"name": "close-day", "key": "orders.close-day", "connection": "app",
             "at": "30 1 * * *", "timezone": "Etc/GMT+4"},
            {"name": "weekly-report", "key": "reports.revenue", "connection": "reports",
             "at": "0 8 * * 1"},
            {"name": "sweep", "key": "orders.lookup", "connection": "app",
             "at": "*/15 10,14,20 * * *"}]})
        text = self.rendered("producer", "jobs.yaml").read_text()
        self.assertNotIn("timezone_offset", text)
        self.assertNotIn("#", text)                      # the players' file: no spoiler
        schedule = yaml.safe_load(self.rendered("producer", "schedule.yaml").read_text())
        self.assertEqual(list(schedule), ["seed", "intensity", "connections", "streams",
                                          "shapes", "timeline"])
        self.assertEqual(schedule["seed"], self.impl["timeline"]["seed"])
        self.assertEqual(schedule["shapes"]["business-hours"]["utc"]["mon"][14], 1.6)
        planned = render.parse_handover(handover)
        self.assertEqual([c["at"] for c in schedule["timeline"]],
                         [render.iso(planned - datetime.timedelta(hours=h)) for h in (6, 2)])
        self.assertEqual(schedule["timeline"][0]["set"], {"key": "orders.insert-v2"})

    def test_the_program_reads_the_rendered_files(self):
        parsers = scheduler_parsers()
        if parsers is None:
            self.skipTest("the scheduler program's modules do not import here")
        parse_schedule, parse_jobs = parsers
        self.render(handover_at(5))
        schedule = parse_schedule(yaml.safe_load(
            self.rendered("producer", "schedule.yaml").read_text()))
        self.assertEqual(schedule.seed, self.impl["timeline"]["seed"])
        jobs = parse_jobs(yaml.safe_load(self.rendered("producer", "jobs.yaml").read_text()))
        self.assertEqual([j.name for j in jobs], ["close-day", "weekly-report", "sweep"])

    def test_a_timeline_moment_falling_before_t0(self):
        # A hand-over one to two hours away: handover-6h and handover-2h are
        # already past, so before any T0; they are rendered as such and take
        # effect at T0 (8.3). The hand-over is too soon for the aging: warned.
        now = datetime.datetime.now(UTC)
        planned = now.replace(minute=0, second=0, microsecond=0) + datetime.timedelta(hours=2)
        self.render(render.iso(planned))
        schedule = yaml.safe_load(self.rendered("producer", "schedule.yaml").read_text())
        moments = [render.from_iso(c["at"]) for c in schedule["timeline"]]
        self.assertEqual(moments, [planned - datetime.timedelta(hours=6),
                                   planned - datetime.timedelta(hours=2)])
        self.assertTrue(all(m < now for m in moments))
        self.assertIn("is before", self.result.warning)
        self.assertIn("earliest hand-over", self.result.warning)
        warnings = [l for l in self.result.text().splitlines() if "warning:" in l]
        self.assertEqual(len(warnings), 1)
        self.assertEqual(localimpl.read_state(self.ldir)["stage"], "rendered")

    def test_seed_modes_and_a_directory_entry_in_the_stack(self):
        self.render(handover_at(16))
        mounts = {m["source"]: m for m in self.stack["services"]["producer"]["configs"]}
        self.assertEqual(mounts[f"{self.gid}_producer_schedule.yaml"]["mode"], 0o400)
        self.assertEqual(mounts[f"{self.gid}_producer_schedule.yaml"]["target"],
                         "/opt/gm/seed/schedule.yaml")
        self.assertEqual(mounts[f"{self.gid}_producer_jobs.yaml"]["mode"], 0o444)
        builder = mounts[f"{self.gid}_producer_builders-revenue.py"]
        self.assertEqual((builder["target"], builder["mode"], builder["uid"], builder["gid"]),
                         ("/opt/gm/seed/builders/revenue.py", 0o444, "0", "0"))
        self.assertEqual(self.config("producer", "builders-revenue.py")["file"],
                         "nodes/producer/builders/revenue.py")

    def test_refit_needed_when_a_builder_is_added(self):
        (self.scenario / "nodes/producer/builders/extra.py").write_text("x = 1\n")
        with self.assertRaisesRegex(model.GmError, "seed files changed since gmctl fit"):
            render.render(self.scenario, "laptop", handover=handover_at(16))

    @unittest.skipUnless(shutil.which("docker"), "docker not installed")
    def test_docker_stack_config_accepts(self):
        self.render(handover_at(16))
        r = subprocess.run(["docker", "stack", "config", "-c", str(self.ldir / "stack.yml")],
                           capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_cli(self):
        r = run_gmctl("render", self.scenario, "--playground", "laptop")
        self.assertEqual(r.returncode, 1)
        self.assertIn("--handover", r.stderr)
        r = run_gmctl("render", self.scenario, "--playground", "laptop",
                      "--handover", handover_at(16))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("customer's time zone UTC-2 (Etc/GMT+2)", r.stdout)


class TestWritePolicyAndSecrets(V03Rendered):
    """Chunk 7b: the write policy in the environment (W1 item 5), the
    connection secrets (W1 item 7) and `only_with_role` (W1 item 3)."""

    def test_a_report_only_nodes_environment_with_an_override(self):
        self.render(handover_at(16))
        env = self.stack["services"]["producer"]["environment"]
        self.assertEqual(env, {"TZ": "UTC", "GM_WRITE_POLICY": "report-only",
                               "GM_WRITE_OVERRIDES": "/srv/scheduler/jobs"})
        self.assertEqual(list(env)[:3], ["TZ", "GM_WRITE_POLICY", "GM_WRITE_OVERRIDES"])
        db = self.stack["services"]["db"]["environment"]
        self.assertEqual((db["GM_WRITE_POLICY"], db["GM_WRITE_OVERRIDES"]), ("fixable", ""))
        self.assertEqual(self.stack["services"]["bastion"]["environment"]["GM_WRITE_POLICY"],
                         "report-only")

    def test_overrides_unique_sorted_space_separated(self):
        node = {"write_policy": "report-only",
                "write_overrides": ["/srv/b", "/etc/a", "/srv/b"]}
        self.assertEqual(render.write_policy_environment(node),
                         {"GM_WRITE_POLICY": "report-only", "GM_WRITE_OVERRIDES": "/etc/a /srv/b"})
        self.assertEqual(render.write_policy_environment({"write_policy": "no-access"}),
                         {"GM_WRITE_POLICY": "no-access", "GM_WRITE_OVERRIDES": ""})

    def test_connection_secrets_mounted_in_the_scheduler(self):
        self.render(handover_at(16))
        rel = "local/laptop/secrets/"
        names = [s["secret"] for s in self.impl["secrets"]]
        for role in ("shop_app", "shop_reports"):
            secret = f"role_{role}_password"
            entry = next(s for s in self.impl["secrets"] if s["secret"] == secret)
            self.assertEqual(entry, {"name": f"{self.gid}_{secret}", "secret": secret,
                                     "kind": "password", "handed_over": False,
                                     "file": rel + secret})
        self.assertEqual(names.count("role_shop_app_password"), 1)
        mounts = {m["source"]: m for m in self.stack["services"]["producer"]["secrets"]}
        for role in ("shop_app", "shop_reports"):
            m = mounts[f"{self.gid}_role_{role}_password"]
            self.assertEqual((m["target"], m["uid"], m["gid"], m["mode"]),
                             (f"/opt/gm/secrets/role_{role}_password", "0", "0", 0o400))
        for node in ("db", "bastion"):
            self.assertFalse([m for m in self.stack["services"][node]["secrets"]
                              if "_role_" in m["source"]], node)
        self.assertIn(f"{self.gid}_role_shop_app_password", self.stack["secrets"])

    def test_the_lookup_secret_only_with_a_pooler_node(self):
        sc = model.load_scenario(self.scenario)
        db = sc.node("db")
        declared = [s["name"] for s in localimpl.node_secret_declarations(sc, db)]
        self.assertIn("gm_check_password", declared)
        self.assertNotIn("pgbouncer_lookup_password", declared)
        self.assertNotIn("pgbouncer_lookup_password",
                         [s["secret"] for s in localimpl.game_secrets(sc)[0]])
        self.assertNotIn(f"{localimpl.read_implementation(self.ldir)['game_id']}"
                         "_pgbouncer_lookup_password",
                         [s["name"] for s in localimpl.read_implementation(self.ldir)["secrets"]])
        sc.node("bastion")["role"] = "pooler"        # a node with the pooler role
        declared = [s["name"] for s in localimpl.node_secret_declarations(sc, db)]
        self.assertIn("pgbouncer_lookup_password", declared)
        self.assertIn("pgbouncer_lookup_password",
                      [s["secret"] for s in localimpl.game_secrets(sc)[0]])

    def test_refit_needed_when_the_schedule_names_another_role(self):
        self.edit_yaml("nodes/producer/schedule.yaml",
                       lambda d: d["connections"]["reports"].update(role="shop_audit"))
        with self.assertRaisesRegex(model.GmError, "secrets changed since gmctl fit"):
            render.render(self.scenario, "laptop", handover=handover_at(16))


class TestRenderStatic(RenderedFixture):
    """A scenario with no scheduler node: rendered without --handover, it
    has no timeline and nothing is shifted (D158)."""

    def test_rendered_without_handover(self):
        self.assertNotIn("timeline", self.impl)
        self.assertFalse((self.ldir / "rendered").exists())
        self.assertNotIn("hand-over", self.result.text())

    def test_with_handover_only_the_planned_handover(self):
        handover = handover_at(9)
        result = render.render(self.scenario, "laptop", handover=handover)
        impl = localimpl.read_implementation(self.ldir)
        self.assertEqual(impl["timeline"],
                         {"planned_handover": render.iso(render.parse_handover(handover))})
        self.assertIn("nothing shifted", result.text())
        self.assertFalse((self.ldir / "rendered").exists())
        render.render(self.scenario, "laptop")
        self.assertNotIn("timeline", localimpl.read_implementation(self.ldir))


if __name__ == "__main__":
    unittest.main()
