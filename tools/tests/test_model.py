"""Scenario loading and completeness (tools/gm/model.py)."""

import datetime
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import REPO_ROOT, FIXTURES, FIXTURE_SCENARIO, ScenarioCopyTest

FIXTURE_MOUNTED = FIXTURES / "fixture-mounted"
FIXTURE_MONITORING = FIXTURES / "fixture-monitoring"


def repo_yaml_files():
    """Every YAML file in the repository, local implementations aside."""
    skip = {".git", "local", "__pycache__"}
    for path in sorted(REPO_ROOT.rglob("*")):
        if path.suffix in (".yaml", ".yml") and path.is_file() \
                and not skip.intersection(path.relative_to(REPO_ROOT).parts):
            yield path


class TestRepositoryYaml(unittest.TestCase):

    def test_every_yaml_file_loads(self):
        files = list(repo_yaml_files())
        names = {p.name for p in files}
        # templates, brick.yaml, fault.yaml and scenario.yaml are all covered
        for expected in ("scenario.yaml", "brick.yaml", "fault.yaml", "answer-key.yaml"):
            self.assertIn(expected, names)
        for path in files:
            with self.subTest(path=str(path.relative_to(REPO_ROOT))):
                with path.open() as fh:
                    list(yaml.safe_load_all(fh))

    def test_catalog_bricks_are_complete(self):
        for brick_dir in sorted((REPO_ROOT / "bricks").iterdir()):
            with self.subTest(brick=brick_dir.name):
                self.assertEqual(model.check_brick_dir(brick_dir), [])

    def test_catalog_faults_are_complete(self):
        faults = REPO_ROOT / "faults"
        for fault_dir in sorted(faults.iterdir()) if faults.is_dir() else []:
            with self.subTest(fault=fault_dir.name):
                self.assertEqual(model.check_fault_dir(fault_dir), [])

    def test_catalog_purposes_are_complete(self):
        purposes = REPO_ROOT / "purposes"
        for purpose_dir in sorted(purposes.iterdir()) if purposes.is_dir() else []:
            with self.subTest(purpose=purpose_dir.name):
                self.assertEqual(model.check_purpose_dir(purpose_dir), [])

    def test_catalog_domains_are_complete(self):
        domains = REPO_ROOT / "domains"
        self.assertTrue((domains / "shop" / "domain.yaml").is_file())
        for domain_dir in sorted(domains.iterdir()) if domains.is_dir() else []:
            with self.subTest(domain=domain_dir.name):
                self.assertEqual(model.check_domain_dir(domain_dir), [])

    def test_repo_scenarios_load(self):
        scenarios = REPO_ROOT / "scenarios"
        for sdir in sorted(scenarios.iterdir()) if scenarios.is_dir() else []:
            with self.subTest(scenario=sdir.name):
                model.load_scenario(sdir)


class TestTemplateSchema(unittest.TestCase):

    def test_required_keys_come_from_the_template(self):
        schema = model.template_schema("scenario.yaml")
        self.assertIn("session_length_minutes", schema.fields)
        node = schema.fields["nodes"].child.item
        self.assertFalse(node.fields["resources"].optional)
        self.assertTrue(node.fields["data"].optional)
        self.assertTrue(node.fields["published_ports"].allow_empty)
        self.assertTrue(node.fields["parameters"].allow_empty)
        self.assertFalse(schema.fields["fault_instances"].allow_empty)

    def test_commented_out_keys_are_not_required(self):
        schema = model.template_schema("brick.yaml")
        self.assertNotIn("footprint_ranges", schema.fields)
        self.assertNotIn("extra", schema.fields)
        self.assertIn("processes", schema.fields)
        params = schema.fields["parameters"].child
        self.assertIn("default", params.free.child.fields)
        self.assertTrue(params.free.child.fields["default"].allow_null)

    def test_continuation_comment_marks_optional(self):
        schema = model.template_schema("answer-key.yaml")
        acceptable = schema.fields["instances"].child.item.fields["acceptable"].child
        self.assertFalse(acceptable.fields["diagnosis"].optional)
        self.assertTrue(acceptable.fields["proposal"].optional)
        self.assertTrue(acceptable.fields["fix"].optional)


class TestLoadFixture(unittest.TestCase):

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_SCENARIO)
        self.assertEqual(sc.id, "fixture-audit")
        self.assertEqual([n["name"] for n in sc.nodes], ["bastion", "db"])
        self.assertEqual(sc.bricks["db"].id, "postgres")
        self.assertEqual(sc.bricks["db"].source, "catalog")
        self.assertEqual(sc.bricks["bastion"].dir, REPO_ROOT / "bricks" / "bastion")
        fault = sc.faults["f1"]
        self.assertEqual(fault.source, "scenario")
        self.assertEqual(fault.dir, FIXTURE_SCENARIO / "faults" / "fixture-random-page-cost")
        state_fault = sc.faults["f2"]
        self.assertEqual(state_fault.data["injection"]["kind"], "state")
        self.assertEqual(sc.node("db")["data"]["file"], "data/db.sql")


class RefusalAsserts:

    catalog_root = None                 # the repository's, unless a test sets its own

    def load(self):
        return model.load_scenario(self.scenario, self.catalog_root or model.REPO_ROOT)

    def assertRefused(self, *fragments):
        with self.assertRaises(model.IncompleteScenario) as cm:
            self.load()
        text = "\n".join(cm.exception.missing)
        for fragment in fragments:
            self.assertIn(fragment, text)
        return cm.exception.missing


class TestRefusals(RefusalAsserts, ScenarioCopyTest):

    def test_every_missing_item_is_listed(self):
        def change(d):
            del d["title"]
            del self.node(d, "db")["resources"]["reservations"]["disk"]
            d["background"] = "<Short GM-facing summary>"
        self.edit_yaml("scenario.yaml", change)
        (self.scenario / "player" / "story.md").unlink()
        missing = self.assertRefused(
            "scenario.yaml: title",
            "nodes[db].resources.reservations.disk",
            "background",
            "player/story.md",
        )
        self.assertGreaterEqual(len(missing), 4)
        self.assertIn("placeholder", "\n".join(missing))

    def test_empty_list_only_where_allowed(self):
        self.edit_yaml("scenario.yaml", lambda d: d.update(flows=[]))
        self.assertRefused("scenario.yaml: flows")

    def test_pinned_version_mismatch(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "db")["brick"].update(version="0.5.0"))
        self.assertRefused("nodes[db].brick", "0.5.0", "0.4.0")

    def test_unknown_brick(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "db")["brick"].update(id="mysql"))
        self.assertRefused("nodes[db].brick", "mysql")

    def test_scenario_local_brick_resolved_first(self):
        local = self.scenario / "bricks" / "bastion"
        shutil.copytree(REPO_ROOT / "bricks" / "bastion", local)
        sc = model.load_scenario(self.scenario)
        self.assertEqual(sc.bricks["bastion"].source, "scenario")
        self.assertEqual(sc.bricks["bastion"].dir, local)

    def test_incomplete_local_brick_makes_scenario_incomplete(self):
        local = self.scenario / "bricks" / "bastion"
        shutil.copytree(REPO_ROOT / "bricks" / "bastion", local)
        (local / "docs" / "gm.md").unlink()
        self.assertRefused("bricks/bastion", "docs/gm.md")

    def test_seed_files_must_cover_brick_seed(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "db")["seed_files"].pop("pg_hba.conf"))
        self.assertRefused("nodes[db].seed_files", "pg_hba.conf")

    def test_widened_envelope_refused(self):
        def change(d):
            self.node(d, "db")["knobs"][0]["envelope"] = {"min": "16MB", "max": "256MB"}
        self.edit_yaml("scenario.yaml", change)
        self.assertRefused("shared_buffers", "widen")

    def test_knob_initial_must_match_seed(self):
        def change(d):
            self.node(d, "db")["knobs"][1]["initial"] = "8MB"
        self.edit_yaml("scenario.yaml", change)
        self.assertRefused("work_mem", "seed")

    def test_missing_knob_refused(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "db")["knobs"].pop())
        self.assertRefused("autovacuum")

    def test_role_and_write_policy_checked(self):
        def change(d):
            self.node(d, "bastion")["write_policy"] = "fixable"
            self.node(d, "db")["role"] = "bastion"
        self.edit_yaml("scenario.yaml", change)
        self.assertRefused("nodes[bastion].write_policy", "nodes[db].role")

    def test_answer_key_one_entry_per_instance(self):
        self.edit_yaml("gm/answer-key.yaml", lambda d: d.update(instances=[]))
        self.assertRefused("answer-key.yaml", "f1")

    def test_known_instance_needs_an_issue(self):
        def change(d):
            d["fault_instances"][0]["visibility"] = "known"
        self.edit_yaml("scenario.yaml", change)
        self.assertRefused("f1", "known")

    def test_session_length_at_most_240(self):
        self.edit_yaml("scenario.yaml", lambda d: d.update(session_length_minutes=300))
        self.assertRefused("session_length_minutes")

    def test_placement_covers_every_node(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d["designed_for"]["placement"].pop("db"))
        self.assertRefused("designed_for.placement", "db")

    def test_incomplete_local_fault(self):
        (self.scenario / "faults" / "fixture-random-page-cost" / "checks" / "fixed.sh").unlink()
        self.assertRefused("faults/fixture-random-page-cost", "checks/fixed.sh")

    def test_fault_parameter_env_names(self):
        self.assertEqual(model.fault_env_name("table-name"), "FAULT_TABLE_NAME")
        self.assertEqual(model.fault_env_name("db2_name"), "FAULT_DB2_NAME")
        for bad in ("2nd", "_x", "a.b", "naïve", "a b", ""):
            self.assertIsNone(model.fault_env_name(bad), bad)

    def test_invalid_parameter_name_refused_at_load(self):
        def change(d):
            d["parameters"]["a.b"] = {"description": "x", "default": 1, "required": False}
            d["parameters"]["table_name"] = {"description": "x", "default": "t",
                                             "required": False}
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml", change)
        self.assertRefused("fault.yaml: parameters.a.b: not a valid environment name",
                           "parameters.table_name: same environment name FAULT_TABLE_NAME")

    def test_list_or_map_parameter_refused_at_load(self):
        def fault(d):
            d["parameters"]["database"]["default"] = ["shop"]
        def scenario(d):
            d["fault_instances"][1]["parameters"]["column"] = {"name": "customer_id"}
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml", fault)
        self.edit_yaml("scenario.yaml", scenario)
        self.assertRefused("parameters.database.default: a list or map",
                           "fault_instances[f2].parameters.column: a list or map")

    def test_yaml_syntax_error_is_reported(self):
        (self.scenario / "scenario.yaml").write_text("id: [unclosed\n")
        self.assertRefused("scenario.yaml")


class MountedCopyTest(RefusalAsserts, ScenarioCopyTest):
    """Each test works on a fresh copy of the fixture-mounted scenario:
    scenario-local bricks that mount and receive material, and a web front
    (v0.2 capture W1, items 3 to 6)."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="gmctl-test-")
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.scenario = self.tmp / "fixture-mounted"
        shutil.copytree(FIXTURE_MOUNTED, self.scenario)

    def brick(self, brick_id, change):
        self.edit_yaml(f"bricks/{brick_id}/brick.yaml", change)

    def monitor_item(self, d):
        return d["companion"]["mounted"][0]

    def node_health(self, change):
        self.edit_yaml("scenario.yaml",
                       lambda d: change(self.node(d, "monitor")["parameters"]["node_health"]))

    def web_routes(self, routes):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "bastion")["parameters"]
                       .update(web_routes=routes))


class TestMountedFixture(MountedCopyTest):

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_MOUNTED)
        self.assertEqual(sc.id, "fixture-mounted")
        self.assertEqual({n: b.source for n, b in sc.bricks.items()},
                         {"bastion": "scenario", "app": "scenario", "monitor": "scenario"})
        self.assertEqual(sc.node("monitor")["parameters"]["node_health"],
                         {"bastion": "default", "app": ["app", "sshd"], "monitor": "default"})
        self.assertEqual(model.mounted_items(sc.bricks["monitor"].data)[0]["name"],
                         "node-health")

    def test_fixture_bricks_are_complete(self):
        for brick_dir in sorted((FIXTURE_MOUNTED / "bricks").iterdir()):
            with self.subTest(brick=brick_dir.name):
                self.assertEqual(model.check_brick_dir(brick_dir), [])


class TestMonitoringFixture(ScenarioCopyTest):
    """The v0.2 integration fixture (build plan chunk 11; capture W3, "For
    chunk 11"): every v0.2 brick at its v0.2 version. smoke-monitoring.sh
    deploys it on the real engine; here it loads, and fits on the fake
    engine at the laptop playground's capacity."""

    NODES = ["bastion", "db", "prometheus", "exporter", "grafana"]

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-monitoring"
        shutil.copytree(FIXTURE_MONITORING, self.scenario)

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_MONITORING)
        self.assertEqual(sc.id, "fixture-monitoring")
        self.assertEqual([n["name"] for n in sc.nodes], self.NODES)
        self.assertEqual({n: (b.id, b.version, b.source) for n, b in sc.bricks.items()}, {
            "bastion": ("bastion", "0.4.0", "catalog"),
            "db": ("postgres", "0.4.0", "catalog"),
            "prometheus": ("prometheus", "0.2.0", "catalog"),
            "exporter": ("postgres-exporter", "0.2.0", "catalog"),
            "grafana": ("grafana", "0.2.0", "catalog")})
        self.assertEqual(sc.node("prometheus")["parameters"]["node_health"],
                         {n: "default" for n in self.NODES})
        self.assertEqual(sc.node("bastion")["parameters"]["web_routes"],
                         {"grafana": "grafana:3000", "prometheus": "prometheus:9090"})
        self.assertEqual(sc.node("bastion")["published_ports"],
                         [{"port": 22, "default": 2222}, {"port": 8080, "default": 8080}])

    def test_fits_the_laptop_playground_and_renders(self):
        result = fit.fit(self.scenario, "laptop", cpu="2", memory="4G", disk="8G")
        self.assertTrue(result.ok, result.text())
        rendered = render.render(self.scenario, "laptop")
        self.assertEqual(sorted(p.name for p in rendered.node_config_files),
                         sorted(f"{n}.conf" for n in self.NODES))

    def test_grafana_seeds_are_the_companion_files(self):
        companion = REPO_ROOT / "bricks" / "grafana" / "companion"
        seeds = model.load_scenario(FIXTURE_MONITORING).node("grafana")["seed_files"]
        self.assertEqual(sorted(seeds), sorted(p.name for p in companion.iterdir()))
        for name, path in seeds.items():
            with self.subTest(seed=name):
                self.assertEqual((FIXTURE_MONITORING / path).read_bytes(),
                                 (companion / name).read_bytes())

    def test_prometheus_scrapes_every_node_and_the_exporter(self):
        conf = yaml.safe_load((FIXTURE_MONITORING / "nodes/prometheus/prometheus.yml").read_text())
        targets = {job["job_name"]: [t for sc in job["static_configs"] for t in sc["targets"]]
                   for job in conf["scrape_configs"]}
        self.assertEqual(targets, {"prometheus": ["localhost:9090"],
                                   "postgres": ["exporter:9187"],
                                   "node-health": [f"{n}:9110" for n in self.NODES]})


FIXTURE_LOAD = FIXTURES / "fixture-load"


class TestLoadFixture(ScenarioCopyTest):
    """The v0.3 load fixture (build plan chunk 12): every v0.3 brick, a
    producer and a consumer, prometheus report-only, write overrides on the
    producer, a scenario-local behavioural fault (f1) and a catalog state
    fault due during the aging (f2), aging at its floor. smoke-load.sh
    deploys it on the real engine; here it loads, and fits and renders on
    the fake engine on a one-host playground, both designed hosts mapped
    onto it (capture W3 item 1)."""

    NODES = ["bastion", "db", "pooler", "producer", "consumer", "prometheus", "exporter",
             "grafana"]

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-load"
        shutil.copytree(FIXTURE_LOAD, self.scenario)

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_LOAD)
        self.assertEqual(sc.id, "fixture-load")
        self.assertEqual([n["name"] for n in sc.nodes], self.NODES)
        self.assertEqual({n: (b.id, b.version, b.source) for n, b in sc.bricks.items()}, {
            "bastion": ("bastion", "0.4.0", "catalog"),
            "db": ("postgres", "0.4.0", "catalog"),
            "pooler": ("pgbouncer", "0.1.1", "catalog"),
            "producer": ("scheduler", "0.2.0", "catalog"),
            "consumer": ("scheduler", "0.2.0", "catalog"),
            "prometheus": ("prometheus", "0.2.0", "catalog"),
            "exporter": ("postgres-exporter", "0.2.0", "catalog"),
            "grafana": ("grafana", "0.2.0", "catalog")})
        self.assertTrue(model.has_scheduler_nodes(sc.data))
        self.assertEqual(sc.data["aging"], {"minimum": "8h", "handover_at": "14:00"})
        self.assertEqual([n["name"] for n in sc.nodes if n["write_policy"] == "report-only"],
                         ["bastion", "producer", "consumer", "prometheus"])
        self.assertEqual(sc.node("producer")["write_overrides"], ["/srv/scheduler/jobs"])
        self.assertEqual(sc.node("prometheus")["parameters"]["node_health"],
                         {n: "default" for n in self.NODES})
        self.assertEqual([(i["id"], i["fault"]["id"], i.get("plant_at", "T0"))
                          for i in sc.data["fault_instances"]],
                         [("f1", "fixture-job-every-minute", "T0"),
                          ("f2", "pg-table-autovacuum-off", "handover-4h")])
        designed = sc.data["designed_for"]
        self.assertEqual([h["name"] for h in designed["hosts"]], ["host-1", "host-2"])
        self.assertEqual(designed["placement"]["bastion"], "host-1")

    def test_the_fixture_fault_is_behavioural(self):
        fault = yaml.safe_load((FIXTURE_LOAD / "faults/fixture-job-every-minute/fault.yaml")
                               .read_text())
        self.assertTrue(fault["sealed_check"]["behavioural"])
        key = yaml.safe_load((FIXTURE_LOAD / "gm/answer-key.yaml").read_text())
        f1 = next(i for i in key["instances"] if i["instance"] == "f1")
        self.assertEqual((f1["sealed_check"]["window"], f1["sealed_check"]["threshold"]),
                         ("2m", 1))

    def test_fits_a_one_host_playground_and_renders_with_a_handover(self):
        result = fit.fit(self.scenario, "host-1", cpu="2", memory="4G", disk="10G")
        self.assertTrue(result.ok, result.text())
        tomorrow = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)
        rendered = render.render(self.scenario, "host-1",
                                 handover=tomorrow.strftime("%Y-%m-%dT09:00Z"))
        self.assertIn("shift +5", rendered.text())
        out = self.scenario / "local" / "host-1" / "rendered"
        self.assertEqual(sorted(str(p.relative_to(out)) for p in out.rglob("*") if p.is_file()),
                         ["bastion/story.md", "consumer/jobs.yaml", "consumer/schedule.yaml",
                          "producer/jobs.yaml", "producer/schedule.yaml"])

    def test_grafana_seeds_are_the_companion_files(self):
        companion = REPO_ROOT / "bricks" / "grafana" / "companion"
        seeds = model.load_scenario(FIXTURE_LOAD).node("grafana")["seed_files"]
        self.assertEqual(sorted(seeds), sorted(p.name for p in companion.iterdir()))
        for name, path in seeds.items():
            with self.subTest(seed=name):
                self.assertEqual((FIXTURE_LOAD / path).read_bytes(),
                                 (companion / name).read_bytes())

    def test_prometheus_scrapes_every_node_the_exporter_and_the_schedulers(self):
        conf = yaml.safe_load((FIXTURE_LOAD / "nodes/prometheus/prometheus.yml").read_text())
        targets = {job["job_name"]: [t for sc in job["static_configs"] for t in sc["targets"]]
                   for job in conf["scrape_configs"]}
        self.assertEqual(targets, {"prometheus": ["localhost:9090"],
                                   "postgres": ["exporter:9187"],
                                   "scheduler": ["producer:9120", "consumer:9120"],
                                   "node-health": [f"{n}:9110" for n in self.NODES]})


class TestMountedBrickRefusals(MountedCopyTest):

    def test_mounted_file_missing_from_companion(self):
        (self.scenario / "bricks/fixture-monitor/companion/node-health/s6/run").unlink()
        self.assertRefused("bricks/fixture-monitor/companion/node-health/s6/run: missing file "
                           "(companion.mounted[node-health].files)")

    def test_mounted_source_outside_companion(self):
        def change(d):
            self.monitor_item(d)["files"][0]["source"] = "docs/gm.md"
            self.monitor_item(d)["files"][1]["source"] = "companion/../../x"
        self.brick("fixture-monitor", change)
        self.assertRefused("companion.mounted[node-health].files[docs/gm.md].source: docs/gm.md "
                           "is not under companion/",
                           "files[companion/../../x].source: companion/../../x is not under "
                           "companion/")

    def test_mounted_target_not_absolute(self):
        def change(d):
            self.monitor_item(d)["files"][0]["target"] = "usr/local/lib/node-health.sh"
            self.monitor_item(d)["node_config"]["target"] = "node.conf"
        self.brick("fixture-monitor", change)
        self.assertRefused("files[companion/node-health/node-health.sh].target: "
                           "usr/local/lib/node-health.sh is not an absolute path",
                           "companion.mounted[node-health].node_config.target: node.conf is "
                           "not an absolute path")

    def test_mounted_mode_has_no_write_bit(self):
        def change(d):
            self.monitor_item(d)["files"][0]["mode"] = "0755"
            self.monitor_item(d)["node_config"]["mode"] = "0644"
        self.brick("fixture-monitor", change)
        self.assertRefused("files[companion/node-health/node-health.sh].mode: 0755 has a write "
                           "bit (mounted material is read-only)",
                           "node_config.mode: 0644 has a write bit")

    def test_mounted_parameter_not_declared(self):
        self.brick("fixture-monitor",
                   lambda d: self.monitor_item(d).update(parameter="health_map"))
        self.assertRefused("companion.mounted[node-health].parameter: health_map is not a "
                           "parameter of the brick")

    def test_mounted_parameter_not_a_node_map(self):
        self.brick("fixture-monitor", lambda d: d["parameters"]["node_health"].pop("shape"))
        self.assertRefused("companion.mounted[node-health].parameter: node_health is not a "
                           "node-map parameter (shape: node-map)")

    def test_unknown_shape(self):
        self.brick("fixture-monitor",
                   lambda d: d["parameters"]["node_health"].update(shape="list"))
        self.assertRefused("parameters.node_health.shape: list is not node-map or web-routes")

    def test_mounted_requirements_well_formed(self):
        def change(d):
            self.monitor_item(d)["requires"] = {"s6_overlay": 3, "commands": ["sh", "curl"]}
        self.brick("fixture-monitor", change)
        self.assertRefused("companion.mounted[node-health].requires.s6_overlay: 3 is not a "
                           "quoted version string",
                           "requires.commands: curl is not in the command vocabulary")

    def test_receives_well_formed(self):
        self.brick("fixture-app", lambda d: d.update(
            receives={"s6_overlay": "v3", "commands": ["sh", "bash"]}))
        self.assertRefused("fixture-app/brick.yaml: receives.s6_overlay: v3 is not a version "
                           "(digits and dots)",
                           "receives.commands: bash is not in the command vocabulary")

    def test_receives_needs_its_keys(self):
        self.brick("fixture-app", lambda d: d.update(receives={"commands": ["sh"]}))
        self.assertRefused("fixture-app/brick.yaml: receives.s6_overlay: missing")

    def test_footprint_units(self):
        def change(d):
            d["footprint"]["limits"]["memory"] = "lots"
            self.monitor_item(d)["footprint"]["reservations"]["cpu"] = "some"
        self.brick("fixture-monitor", change)
        self.assertRefused("fixture-monitor/brick.yaml: footprint.limits.memory: not a size",
                           "companion.mounted[node-health].footprint.reservations.cpu: not a "
                           "CPU count")

    def test_web_path_shape(self):
        self.brick("fixture-monitor",
                   lambda d: d["interfaces"]["provides"][0].update(web_path="/a/b/"))
        self.assertRefused("interfaces.provides[ui].web_path: /a/b/ is not /<route>/")


class TestNodeMapRefusals(MountedCopyTest):

    def test_map_required_with_a_mounting_brick(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "monitor")["parameters"].pop("node_health"))
        self.assertRefused("nodes[monitor].parameters.node_health: missing (required by brick "
                           "fixture-monitor)")

    def test_map_required_even_when_the_brick_says_optional(self):
        self.brick("fixture-monitor",
                   lambda d: d["parameters"]["node_health"].update(required=False))
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "monitor")["parameters"].pop("node_health"))
        self.assertRefused("nodes[monitor].parameters.node_health: missing (brick "
                           "fixture-monitor mounts node-health into the nodes it lists)")

    def test_map_lists_every_node(self):
        self.node_health(lambda m: m.pop("app"))
        self.assertRefused("nodes[monitor].parameters.node_health: node app is missing (the map "
                           "lists every node of the topology)")

    def test_map_lists_its_own_node(self):
        self.node_health(lambda m: m.pop("monitor"))
        self.assertRefused("node_health: node monitor is missing")

    def test_map_key_not_a_node(self):
        self.node_health(lambda m: m.update(ghost="default"))
        self.assertRefused("nodes[monitor].parameters.node_health.ghost: not a node of the "
                           "topology")

    def test_map_entries(self):
        self.node_health(lambda m: m.update(app=["app", "nginx"], bastion=[], monitor="all"))
        self.assertRefused("node_health.app: nginx is not a process of brick fixture-app "
                           "(app, sshd)",
                           "node_health.bastion: [] is not default or a non-empty list",
                           "node_health.monitor: 'all' is not default or a non-empty list")

    def test_map_not_a_map(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "monitor")["parameters"]
                       .update(node_health="default"))
        self.assertRefused("nodes[monitor].parameters.node_health: not a map (shape node-map "
                           "of brick fixture-monitor)")

    def test_scalar_parameter_given_a_map(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "app")["parameters"]
                       .update(listen_port={"port": 8000}))
        self.assertRefused("nodes[app].parameters.listen_port: a list or map, but brick "
                           "fixture-app declares it a scalar (no shape)")


class TestReceivingRefusals(MountedCopyTest):

    def test_receiver_without_receives(self):
        self.brick("fixture-app", lambda d: d.pop("receives"))
        self.assertRefused("scenario.yaml: nodes[app]: brick fixture-app 0.1.0 declares no "
                           "receives, but brick fixture-monitor 0.1.0's node-health is mounted "
                           "into it")

    def test_mounting_node_receives_too(self):
        self.brick("fixture-monitor", lambda d: d.pop("receives"))
        self.assertRefused("nodes[monitor]: brick fixture-monitor 0.1.0 declares no receives")

    def test_s6_overlay_version_prefix(self):
        for have in ("2.2.0.3", "30.1", "3x"):
            with self.subTest(have=have):
                self.setUp()
                self.brick("fixture-app", lambda d: d["receives"].update(s6_overlay=have))
                self.assertRefused(f"nodes[app]: brick fixture-app 0.1.0 receives s6-overlay "
                                   f"{have}, but brick fixture-monitor 0.1.0's node-health "
                                   "requires 3")

    def test_s6_overlay_prefix_accepted(self):
        for need in ("3", "3.2", "3.2.3.2"):
            with self.subTest(need=need):
                self.setUp()
                self.brick("fixture-monitor",
                           lambda d: self.monitor_item(d)["requires"].update(s6_overlay=need))
                model.load_scenario(self.scenario)

    def test_missing_commands(self):
        self.brick("fixture-app", lambda d: d["receives"].update(commands=["sh", "cat"]))
        self.assertRefused("nodes[app]: brick fixture-app 0.1.0 lacks command(s) du, "
                           "s6-svstat, s6-setuidgid, which brick fixture-monitor 0.1.0's "
                           "node-health requires")

    def test_unlisted_node_is_not_checked(self):
        # Leaving a node out exists only as a parameter fault; the map is
        # refused for it, not the node's receiving declaration.
        self.brick("fixture-app", lambda d: d.pop("receives"))
        self.node_health(lambda m: m.pop("app"))
        missing = self.assertRefused("node app is missing")
        self.assertNotIn("declares no receives", "\n".join(missing))


class TestWebRouteRefusals(MountedCopyTest):

    def test_route_to_an_unknown_node(self):
        self.web_routes({"monitor": "ghost:9090"})
        self.assertRefused("nodes[bastion].parameters.web_routes.monitor: ghost is not a node",
                           "nodes[monitor]: web interface ui (port 9090, /monitor/) has no "
                           "route in a web-routes parameter")

    def test_route_target_shape(self):
        self.web_routes({"monitor": "monitor"})
        self.assertRefused("web_routes.monitor: 'monitor' is not \"<node>:<port>\"")

    def test_route_to_a_port_without_web_interface(self):
        self.web_routes({"monitor": "monitor:9091", "app": "app:8000"})
        self.assertRefused("web_routes.monitor: brick fixture-monitor of node monitor provides "
                           "no web interface on port 9091",
                           "web_routes.app: brick fixture-app of node app provides no web "
                           "interface on port 8000")

    def test_route_name_is_the_web_path(self):
        self.web_routes({"grafana": "monitor:9090"})
        self.assertRefused("web_routes.grafana: monitor:9090 is served under /monitor/, not "
                           "/grafana/")

    def test_one_route_per_web_interface(self):
        self.web_routes({"monitor": "monitor:9090", "mon": "monitor:9090"})
        self.assertRefused("nodes[monitor]: web interface ui (port 9090, /monitor/) has 2 "
                           "routes (mon, monitor); one route per web interface")

    FRONT_PORT_MISSING = ("nodes[bastion].published_ports: no {port: 8080, default: 8080}, "
                          "which the web front needs (it runs in every game, routes or none)")

    def test_front_port_when_routes(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "bastion")
                       .update(published_ports=[{"port": 22, "default": 2222},
                                                {"port": 8080, "default": 8081}]))
        self.assertRefused(self.FRONT_PORT_MISSING)

    def drop_ui_evidence(self):
        self.edit_yaml("gm/answer-key.yaml", lambda d: d["instances"][1]["evidence"][0]
                       .update(where="node:monitor"))

    def without_web_interface(self):
        self.brick("fixture-monitor", lambda d: d["interfaces"]["provides"][0].pop("web_path"))
        self.drop_ui_evidence()

    def test_front_port_without_routes(self):
        # v0.4 (D224): the front runs in every game, so empty routes still
        # need the port; v0.3 refused it published.
        self.without_web_interface()
        def change(d):
            self.node(d, "bastion")["parameters"].update(web_routes={})
            self.node(d, "bastion")["published_ports"] = [{"port": 22, "default": 2222}]
        self.edit_yaml("scenario.yaml", change)
        missing = self.assertRefused(self.FRONT_PORT_MISSING)
        self.assertEqual(len(missing), 1, missing)

    def test_front_port_published_with_empty_routes(self):
        self.without_web_interface()
        self.web_routes({})
        model.load_scenario(self.scenario)

    def test_empty_routes_by_default(self):
        self.without_web_interface()
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "bastion")["parameters"].pop("web_routes"))
        model.load_scenario(self.scenario)
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "bastion")
                       .update(published_ports=[{"port": 22, "default": 2222}]))
        self.assertRefused(self.FRONT_PORT_MISSING)


class TestParameterFaultRefusals(MountedCopyTest):
    """The `parameter` injection kind and faults about mounted material
    (v0.2 capture W1, item 8; master spec 6.4)."""

    FAULT = "faults/fixture-node-left-out/fault.yaml"

    def fault(self, change):
        self.edit_yaml(self.FAULT, change)

    def first_change(self, d):
        return d["injection"]["parameter_changes"][0]

    def test_parameter_fault_accepted(self):
        sc = model.load_scenario(self.scenario)
        self.assertEqual(sc.faults["f2"].data["injection"]["kind"], "parameter")

    def test_unknown_kind(self):
        self.fault(lambda d: d["injection"].update(kind="script"))
        self.assertRefused("fault.yaml: injection.kind: script is not seed-file, state or "
                           "parameter")

    def test_changes_required(self):
        self.fault(lambda d: d["injection"].pop("parameter_changes"))
        self.assertRefused("fixture-node-left-out/fault.yaml: injection.parameter_changes: "
                           "missing (kind parameter)")

    def test_planted_at_render(self):
        self.fault(lambda d: d["injection"].update(stage="after-data-load"))
        self.assertRefused("fault.yaml: injection.stage: after-data-load, but a parameter fault "
                           "is planted at render (seed)")

    def test_unknown_op(self):
        self.fault(lambda d: self.first_change(d).update(op="rename"))
        self.assertRefused("injection.parameter_changes[0].op: rename is not one of set, "
                           "remove-entry, remove-from-entry")

    def test_op_keys(self):
        def change(d):
            d["injection"]["parameter_changes"] = [
                {"parameter": "node_health", "op": "remove-entry", "change": "x"},
                {"parameter": "node_health", "op": "set", "entry": "{NODE}", "change": "x"},
                {"parameter": "node_health", "op": "remove-from-entry", "entry": "{NODE}",
                 "item": ["sshd"], "change": "x"}]
        self.fault(change)
        self.assertRefused("parameter_changes[0].entry: missing (op remove-entry)",
                           "parameter_changes[1].value: missing (op set)",
                           "parameter_changes[1].entry: not used by op set",
                           "parameter_changes[2].item: a list or map; use a scalar")

    def test_substitution_names_a_fault_parameter(self):
        self.fault(lambda d: self.first_change(d).update(entry="{HOST}"))
        self.assertRefused("injection.parameter_changes[0].entry: {HOST} names no parameter of "
                           "the fault")

    def test_versions_one_by_one(self):
        self.fault(lambda d: d["applies_to"]["bricks"][0].update(
            versions=["0.1.0", ">=0.1.0", "0.1.x", 0.1]))
        missing = self.assertRefused(
            "applies_to.bricks[fixture-monitor].versions: '>=0.1.0' is not an exact version "
            "string (one by one, never a range)",
            "versions: '0.1.x' is not an exact version string",
            "versions: 0.1 is not an exact version string")
        self.assertNotIn("'0.1.0' is not", "\n".join(missing))

    def test_changed_parameter_belongs_to_the_target_brick(self):
        self.fault(lambda d: self.first_change(d).update(parameter="node_map"))
        self.assertRefused("scenario.yaml: fault_instances[f2]: fault fixture-node-left-out "
                           "changes parameter node_map, not a parameter of brick "
                           "fixture-monitor")

    def test_mounted_material_fault_targets_the_mounting_node(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d["fault_instances"][1].update(node="app"))
        self.assertRefused("fault_instances[f2].node: app runs fixture-app 0.1.0, which fault "
                           "fixture-node-left-out does not apply to",
                           "fault_instances[f2]: fault fixture-node-left-out changes parameter "
                           "node_health, not a parameter of brick fixture-app")

    def test_op_matches_the_parameter_shape(self):
        def fault(d):
            d["applies_to"]["bricks"] = [{"id": "fixture-app", "versions": ["0.1.0"]}]
            d["injection"]["parameter_changes"] = [
                {"parameter": "listen_port", "op": "remove-entry", "entry": "x", "change": "x"},
                {"parameter": "listen_port", "op": "remove-from-entry", "entry": "x",
                 "item": "y", "change": "x"}]
        self.fault(fault)
        self.edit_yaml("scenario.yaml",
                       lambda d: d["fault_instances"][1].update(node="app"))
        self.assertRefused("fault fixture-node-left-out removes an entry of listen_port, a "
                           "scalar parameter of brick fixture-app",
                           "removes an item from an entry of listen_port, not a node-map "
                           "parameter of brick fixture-app")

    def test_set_takes_a_scalar_parameter(self):
        self.fault(lambda d: d["injection"].update(parameter_changes=[
            {"parameter": "node_health", "op": "set", "value": "x", "change": "x"}]))
        self.assertRefused("fault fixture-node-left-out sets node_health, a node-map parameter "
                           "of brick fixture-monitor (set takes a scalar parameter)")

    def test_set_on_a_scalar_parameter_accepted(self):
        def fault(d):
            d["applies_to"]["bricks"] = [{"id": "fixture-app", "versions": ["0.1.0"]}]
            d["injection"]["parameter_changes"] = [
                {"parameter": "listen_port", "op": "set", "value": 9000, "change": "x"}]
        self.fault(fault)
        self.edit_yaml("scenario.yaml",
                       lambda d: d["fault_instances"][1].update(node="app"))
        model.load_scenario(self.scenario)

    def test_mounted_material_fault_names_only_the_mounting_brick(self):
        self.fault(lambda d: d["applies_to"]["bricks"].append(
            {"id": "fixture-app", "versions": ["0.1.0"]}))
        self.assertRefused("fault_instances[f2]: fault fixture-node-left-out is about material "
                           "brick fixture-monitor mounts, so its applies_to names only "
                           "fixture-monitor (it names fixture-monitor, fixture-app)")

    def test_mounted_material_fault_needs_the_node_parameter(self):
        def fault(d):
            d["parameters"] = {"host": d["parameters"].pop("node")}
            self.first_change(d)["entry"] = "{HOST}"
        self.fault(fault)
        self.edit_yaml("scenario.yaml", lambda d: d["fault_instances"][1].update(
            parameters={"host": "app"}))
        self.assertRefused("fault_instances[f2]: fault fixture-node-left-out is about mounted "
                           "material, so it needs a required parameter node, the affected node")

    def test_node_parameter_must_be_required(self):
        self.fault(lambda d: d["parameters"]["node"].update(required=False))
        self.assertRefused("so it needs a required parameter node")

    def test_node_parameter_names_a_node(self):
        self.edit_yaml("scenario.yaml", lambda d: d["fault_instances"][1].update(
            parameters={"node": "ghost"}))
        self.assertRefused("scenario.yaml: fault_instances[f2].parameters.node: ghost is not a "
                           "node of the topology")

    def test_map_checked_before_the_fault_applies(self):
        # f2 leaves app out at render; the map as scenario.yaml states it
        # still lists every node.
        self.node_health(lambda m: m.pop("app"))
        self.assertRefused("nodes[monitor].parameters.node_health: node app is missing")


class TestAnswerKeyRefusals(MountedCopyTest):
    """Evidence `where` and `source` (spec D101) and tooling expectations
    (v0.2 capture W1, items 9 and 10)."""

    KEY = "gm/answer-key.yaml"

    def evidence(self, index, change):
        self.edit_yaml(self.KEY, lambda d: change(d["instances"][index]["evidence"][0]))

    def test_where_and_source_required(self):
        def change(d):
            d["instances"][0]["evidence"][0].pop("where")
            d["instances"][1]["evidence"][0].pop("source")
        self.edit_yaml(self.KEY, change)
        self.assertRefused("gm/answer-key.yaml: instances[f1].evidence[0].where: missing",
                           "gm/answer-key.yaml: instances[f2].evidence[0].source: missing")

    def test_where_forms(self):
        cases = {
            "the database node": "instances[f1].evidence[0].where: 'the database node' is not "
                                 "bastion, node:<name>, ui:<name> or report:<tool>",
            "node:ghost": "instances[f1].evidence[0].where: node:ghost: ghost is not a node of "
                          "the topology",
            "node:bastion": "instances[f1].evidence[0].where: node:bastion is the bastion; "
                            "write bastion",
            "ui:grafana": "instances[f1].evidence[0].where: ui:grafana: grafana is not a route "
                          "of the topology's web-routes parameter",
            "report:PgBadger": "instances[f1].evidence[0].where: report:PgBadger: the tool is "
                               "written in lowercase",
            "node:": "'node:' is not bastion",
        }
        for where, message in cases.items():
            with self.subTest(where=where):
                self.setUp()
                self.evidence(0, lambda e: e.update(where=where))
                self.assertRefused(message)

    def test_where_accepted(self):
        for where in ("bastion", "node:app", "node:monitor", "ui:monitor", "report:pgbadger"):
            with self.subTest(where=where):
                self.setUp()
                self.evidence(0, lambda e: e.update(where=where))
                model.load_scenario(self.scenario)

    def test_fault_evidence_where_is_a_location(self):
        # O78 option (b), v0.3 master spec 6.3: fault.yaml's evidence names a
        # location in `where`, v0.2's free text moving to `source`.
        sc = model.load_scenario(self.scenario)
        evidence = sc.faults["f2"].data["evidence"][0]
        self.assertEqual(evidence["where"], "node")
        self.assertEqual(evidence["source"],
                         "the monitor's node-health view, read on the monitor node")

    def test_tooling_expectations_required(self):
        self.edit_yaml(self.KEY, lambda d: d.pop("tooling_expectations"))
        self.assertRefused("gm/answer-key.yaml: tooling_expectations: missing")

    def test_tooling_expectation_keys(self):
        self.edit_yaml(self.KEY, lambda d: d["tooling_expectations"][0].pop("acceptable"))
        self.assertRefused("gm/answer-key.yaml: tooling_expectations[t1].acceptable: missing")

    def test_expectation_ids_unique_across_instances(self):
        def change(d):
            t1 = d["tooling_expectations"][0]
            d["tooling_expectations"] += [dict(t1), dict(t1, id="f1")]
        self.edit_yaml(self.KEY, change)
        self.assertRefused("tooling_expectations[t1].id: duplicate expectation id",
                           "tooling_expectations[f1].id: f1 is also a fault instance id")

    def test_expectation_has_no_visibility_nor_sealed_check(self):
        self.edit_yaml(self.KEY, lambda d: d["tooling_expectations"][0].update(
            visibility="known", sealed_check={"script": "x"}))
        self.assertRefused("tooling_expectations[t1].visibility: a tooling expectation has no "
                           "visibility",
                           "tooling_expectations[t1].sealed_check: a tooling expectation has "
                           "no sealed check")

    def test_issue_covers_unknown_id(self):
        self.edit_yaml("scenario.yaml", lambda d: d["issues"][0].update(covers=["t9"]))
        self.assertRefused("scenario.yaml: issues[I1].covers: t9 is not a fault instance or a "
                           "tooling expectation")

    def test_issue_covering_only_expectations(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d["issues"][0].update(expected_resolution="fix"))
        self.assertRefused("scenario.yaml: issues[I1].expected_resolution: fix, but the issue "
                           "covers only tooling expectations (report or propose)")

    def test_issue_covering_an_expectation_and_a_fault(self):
        def change(d):
            d["issues"][0].update(covers=["f2", "t1"], expected_resolution="propose")
            d["fault_instances"][1]["visibility"] = "known"
        self.edit_yaml("scenario.yaml", change)
        model.load_scenario(self.scenario)


class TestUnits(unittest.TestCase):

    def test_parse_size(self):
        self.assertEqual(model.parse_size("512M"), 512 * 1024 ** 2)
        self.assertEqual(model.parse_size("1G"), 1024 ** 3)
        self.assertEqual(model.parse_size("1.5G"), int(1.5 * 1024 ** 3))
        self.assertEqual(model.parse_size("256MB"), 256 * 1024 ** 2)
        self.assertEqual(model.parse_size(1024), 1024)
        with self.assertRaises(ValueError):
            model.parse_size("lots")

    def test_pg_value_comparison(self):
        self.assertTrue(model.pg_equal("1GB", "1024MB"))
        self.assertTrue(model.pg_equal("on", True))
        self.assertTrue(model.pg_equal("4.0", 4))
        self.assertTrue(model.pg_less("64MB", "1GB"))
        self.assertTrue(model.pg_less("30s", "5min"))

    def test_parse_duration(self):
        self.assertEqual(model.parse_duration("16h"), 16 * 3600)
        self.assertEqual(model.parse_duration("30m"), 1800)
        self.assertEqual(model.parse_duration("2d"), 2 * 86400)
        self.assertEqual(model.parse_duration("0m"), 0)
        for bad in ("16", "1h30m", "2 hours", 16, "1.5h", ""):
            with self.subTest(value=bad), self.assertRaises(ValueError):
                model.parse_duration(bad)

    def test_parse_prometheus_duration(self):
        self.assertEqual(model.parse_prometheus_duration("1d"), 86400)
        self.assertEqual(model.parse_prometheus_duration("1h30m"), 5400)
        self.assertEqual(model.parse_prometheus_duration("2w"), 14 * 86400)
        for bad in ("", "1 day", "30", "h"):
            with self.subTest(value=bad), self.assertRaises(ValueError):
                model.parse_prometheus_duration(bad)


# --- v0.3 (build plan chunk 2; capture W1 of specs/versions/v0.3/wave-log.md) ---

FIXTURE_V03 = FIXTURES / "fixture-v03-refusals"


class V03CopyTest(RefusalAsserts, ScenarioCopyTest):
    """Each test works on a fresh copy of fixture-v03-refusals: a scenario
    with a scheduler node (a scenario-local `scheduler` brick, W1 item 9),
    so it ages; f1 a seed-file fault at T0, f2 a state fault planted at
    handover-6h, f3 a fault in the scheduler's jobs.yaml, fixable on the
    report-only producer through its override."""

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-v03-refusals"
        shutil.copytree(FIXTURE_V03, self.scenario)

    def instance(self, iid, change):
        self.edit_yaml("scenario.yaml", lambda d: change(
            next(i for i in d["fault_instances"] if i["id"] == iid)))

    def fault(self, fault_id, change):
        self.edit_yaml(f"faults/{fault_id}/fault.yaml", change)

    def brick_problems(self, change, brick="bricks/scheduler"):
        self.edit_yaml(f"{brick}/brick.yaml", change)
        return "\n".join(model.check_brick_dir(self.scenario / brick))


class TestV03Fixtures(unittest.TestCase):
    """The valid fixtures: one with scheduler nodes, one without."""

    def test_fixture_with_scheduler_nodes_loads(self):
        sc = model.load_scenario(FIXTURE_V03)
        self.assertTrue(model.has_scheduler_nodes(sc.data))
        self.assertEqual(sc.bricks["producer"].id, "scheduler")
        self.assertEqual(sc.bricks["producer"].source, "scenario")
        self.assertEqual(sc.data["aging"], {"minimum": "16h", "handover_at": "14:00"})
        self.assertEqual(sc.node("producer")["write_overrides"], ["/srv/scheduler/jobs"])

    def test_fixture_without_scheduler_nodes_loads(self):
        sc = model.load_scenario(FIXTURE_SCENARIO)
        self.assertFalse(model.has_scheduler_nodes(sc.data))
        self.assertNotIn("aging", sc.data)

    def test_fixture_scheduler_brick_is_complete(self):
        self.assertEqual(model.check_brick_dir(FIXTURE_V03 / "bricks" / "scheduler"), [])


class TestAgingRefusals(V03CopyTest):
    """aging:, plant_at and aging_minimum with scheduler nodes (master spec
    6.1; W1 items 0 and 1; D150, D157)."""

    def test_aging_required_with_a_scheduler_node(self):
        self.edit_yaml("scenario.yaml", lambda d: d.pop("aging"))
        self.assertRefused("scenario.yaml: aging: missing (required with scheduler node(s) "
                           "producer; master spec 6.1, D157)")

    def test_aging_minimum_at_least_eight_hours(self):
        self.edit_yaml("scenario.yaml", lambda d: d["aging"].update(minimum="7h"))
        self.assertRefused("scenario.yaml: aging.minimum: 7h is less than 8h")

    def test_aging_minimum_is_a_duration(self):
        self.edit_yaml("scenario.yaml", lambda d: d["aging"].update(minimum="16 hours"))
        self.assertRefused("scenario.yaml: aging.minimum: '16 hours' is not a duration")

    def test_handover_at_is_quoted_hh00(self):
        for value, message in ((840, "840 is not a quoted \"HH:00\", 24-hour, minutes 00 "
                                     "(unquoted, YAML reads HH:MM as a number)"),
                               ("14:30", "'14:30' is not a quoted \"HH:00\""),
                               ("24:00", "'24:00' is not a quoted \"HH:00\"")):
            with self.subTest(value=value):
                self.setUp()
                self.edit_yaml("scenario.yaml", lambda d: d["aging"].update(handover_at=value))
                self.assertRefused(f"scenario.yaml: aging.handover_at: {message}")

    def test_aging_minimum_covers_every_instance(self):
        self.instance("f3", lambda i: i.update(aging_minimum="20h"))
        self.assertRefused("scenario.yaml: fault_instances[f3]: aging.minimum 16h does not cover "
                           "it: planted at T0, its own aging minimum is 20h")

    def test_definition_minimum_counted(self):
        self.fault("fixture-job-timezone", lambda d: d["aging"].update(minimum="1d"))
        self.assertRefused("fault_instances[f3]: aging.minimum 16h does not cover it: planted at "
                           "T0, its own aging minimum is 1d")

    def test_instance_minimum_at_least_the_definition(self):
        self.instance("f3", lambda i: i.update(aging_minimum="30m"))
        self.assertRefused("fault_instances[f3].aging_minimum: 30m is less than fault "
                           "fixture-job-timezone's aging.minimum 1h")

    def test_instance_minimum_is_a_duration(self):
        self.instance("f3", lambda i: i.update(aging_minimum=4))
        self.assertRefused("fault_instances[f3].aging_minimum: 4 is not a duration")

    def test_plant_at_forms(self):
        for value in ("handover-0h", "T1", "handover+2h", "handover-1.5h", "handover-90m"):
            with self.subTest(value=value):
                self.setUp()
                self.instance("f2", lambda i: i.update(plant_at=value))
                self.assertRefused(f"fault_instances[f2].plant_at: {value!r} is not T0 or "
                                   "handover-<N>h")

    def test_plant_at_after_t0_only_for_a_state_fault(self):
        self.instance("f1", lambda i: i.update(plant_at="handover-2h"))
        self.assertRefused("fault_instances[f1].plant_at: handover-2h, but fault "
                           "fixture-random-page-cost is a seed-file fault, planted at render: "
                           "only a state fault is planted after T0")

    def test_plant_at_t0_accepted_for_any_fault(self):
        self.instance("f1", lambda i: i.update(plant_at="T0"))
        model.load_scenario(self.scenario)

    def test_plant_at_at_most_the_aging_minimum(self):
        self.instance("f2", lambda i: i.update(plant_at="handover-20h"))
        self.assertRefused("fault_instances[f2].plant_at: handover-20h is further before "
                           "hand-over than aging.minimum 16h")

    def test_plant_at_at_least_the_instance_minimum(self):
        self.instance("f2", lambda i: i.update(plant_at="handover-1h"))
        self.assertRefused("fault_instances[f2].plant_at: handover-1h leaves less than the "
                           "instance's own aging minimum 2h before hand-over")


class TestStaticScenarioRefusals(RefusalAsserts, ScenarioCopyTest):
    """A scenario with no scheduler node does not age (D157, D158, D160):
    fixture-audit."""

    def test_aging_refused(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d.update(aging={"minimum": "16h", "handover_at": "14:00"}))
        self.assertRefused("scenario.yaml: aging: a scenario with no scheduler node does not "
                           "age, so it has no aging:")

    def test_plant_at_other_than_t0_refused(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d["fault_instances"][1].update(plant_at="handover-2h"))
        self.assertRefused("fault_instances[f2].plant_at: handover-2h, but a scenario with no "
                           "scheduler node plants every fault at T0 (D158)")

    def test_plant_at_t0_accepted(self):
        self.edit_yaml("scenario.yaml", lambda d: d["fault_instances"][1].update(plant_at="T0"))
        model.load_scenario(self.scenario)

    def test_aging_minimum_refused(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: d["fault_instances"][0].update(aging_minimum="2h"))
        self.assertRefused("fault_instances[f1].aging_minimum: a scenario with no scheduler node "
                           "does not age, so an instance has no aging minimum (D158)")

    def test_customer_timezone_refused(self):
        story = self.scenario / "player" / "story.md"
        story.write_text(story.read_text() + "\nThe shop is in {{customer_timezone}}.\n")
        self.assertRefused("player/story.md: {{customer_timezone}}: a scenario with no scheduler "
                           "node has no customer's time zone; its times stay UTC")

    def test_definition_minima_not_counted(self):
        self.edit_yaml("faults/fixture-dropped-index/fault.yaml",
                       lambda d: d["aging"].update(minimum="3d"))
        model.load_scenario(self.scenario)


class TestDifficultyRefusals(V03CopyTest):

    def test_score_equals_the_instances(self):
        self.edit_yaml("scenario.yaml", lambda d: d["difficulty"].update(score=5))
        self.assertRefused("scenario.yaml: difficulty.score: 5, but the scenario has 3 fault "
                           "instance(s), each worth 1")

    def test_score_is_an_integer(self):
        self.edit_yaml("scenario.yaml", lambda d: d["difficulty"].update(score="3"))
        self.assertRefused("scenario.yaml: difficulty.score: '3' is not an integer")

    def test_level(self):
        self.edit_yaml("scenario.yaml", lambda d: d["difficulty"].update(level="medium"))
        self.assertRefused("scenario.yaml: difficulty.level: medium is not one of easy, normal, "
                           "hard")

    def test_difficulty_required(self):
        self.edit_yaml("scenario.yaml", lambda d: d.pop("difficulty"))
        self.assertRefused("scenario.yaml: difficulty: missing")


class TestWriteOverrideRefusals(V03CopyTest):
    """write_overrides and the per-file fix (master spec 6.1, D143; W1 items 1
    and 3, D170)."""

    def overrides(self, node, paths):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, node).update(
            write_overrides=paths))

    def test_on_a_report_only_node_only(self):
        self.overrides("db", ["/etc/postgresql"])
        self.assertRefused("scenario.yaml: nodes[db].write_overrides: only a report-only node "
                           "has overrides (its write_policy is fixable)")

    def test_among_the_writable_paths(self):
        self.overrides("producer", ["/srv/scheduler/jobs/jobs.yaml"])
        self.assertRefused("nodes[producer].write_overrides: /srv/scheduler/jobs/jobs.yaml is "
                           "not one of brick scheduler's writable_paths (/srv/scheduler/"
                           "repository, /srv/scheduler/jobs, /home/player)")

    def test_no_whitespace(self):
        self.overrides("producer", ["/srv/scheduler/jobs /etc"])
        self.assertRefused("nodes[producer].write_overrides: '/srv/scheduler/jobs /etc' contains "
                           "whitespace")

    def test_non_empty(self):
        self.overrides("producer", [])
        self.assertRefused("scenario.yaml: nodes[producer].write_overrides: empty")

    def test_fix_needs_the_file_fixable(self):
        for paths in (None, ["/srv/scheduler/repository"]):
            with self.subTest(overrides=paths):
                self.setUp()
                if paths is None:
                    self.edit_yaml("scenario.yaml",
                                   lambda d: self.node(d, "producer").pop("write_overrides"))
                else:
                    self.overrides("producer", paths)
                self.assertRefused("scenario.yaml: issues[I1].expected_resolution: fix is not "
                                   "possible under node producer's write policy report-only for "
                                   "the file(s) the fault changes (no write_overrides entry makes "
                                   "them fixable) (f3)")

    def test_fix_of_a_state_fault_keeps_the_node_policy(self):
        def change(d):
            self.node(d, "db")["write_policy"] = "report-only"
            d["issues"].append({"id": "I2", "complaint": "Customer lookups are slow.",
                                "expected_resolution": "fix", "covers": ["f2"]})
            d["fault_instances"][1]["visibility"] = "known"
        self.edit_yaml("scenario.yaml", change)
        self.assertRefused("issues[I2].expected_resolution: fix is not possible under node db's "
                           "write policy report-only (f2)")

    def test_acceptable_fix_follows_the_file_policy(self):
        def hide(d):
            d["issues"] = []
            d["fault_instances"][2]["visibility"] = "hidden"
        self.edit_yaml("scenario.yaml", hide)
        self.edit_yaml("gm/answer-key.yaml",
                       lambda d: d["instances"][2]["acceptable"].pop("fix"))
        self.assertRefused("gm/answer-key.yaml: instances[f3].acceptable.fix: missing")
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "producer").pop("write_overrides"))
        model.load_scenario(self.scenario)


class TestFaultV03Refusals(V03CopyTest):
    """aging:, evidence locations and the behavioural flag (master spec 6.3,
    D145; W1 item 2)."""

    LABEL = "faults/fixture-job-timezone/fault.yaml"

    def evidence(self, change):
        self.fault("fixture-job-timezone", lambda d: change(d["evidence"][0]))

    def test_aging_required(self):
        self.fault("fixture-job-timezone", lambda d: d.pop("aging"))
        self.assertRefused(f"{self.LABEL}: aging: missing")

    def test_aging_technique(self):
        self.fault("fixture-job-timezone", lambda d: d["aging"].update(technique="sped-up"))
        self.assertRefused(f"{self.LABEL}: aging.technique: sped-up is not real-time")

    def test_aging_minimum_is_a_duration(self):
        self.fault("fixture-job-timezone", lambda d: d["aging"].update(minimum="2 hours"))
        self.assertRefused(f"{self.LABEL}: aging.minimum: '2 hours' is not a duration")

    def test_where_forms(self):
        cases = {
            "ui:grafana": "evidence[0].where: ui:grafana: a fault never reads through a web "
                          "interface",
            "node:db": "evidence[0].where: node:db: a fault reads at node (its target node)",
            "the producer": "evidence[0].where: 'the producer' is not node, bastion or "
                            "report:<tool>",
            "report:PgBadger": "evidence[0].where: 'report:PgBadger' is not node, bastion or "
                               "report:<tool>",
        }
        for where, message in cases.items():
            with self.subTest(where=where):
                self.setUp()
                self.evidence(lambda e: e.update(where=where))
                self.assertRefused(f"{self.LABEL}: {message}")

    def test_source_required(self):
        self.evidence(lambda e: e.pop("source"))
        self.assertRefused(f"{self.LABEL}: evidence[0].source: missing")

    def test_report_tool_shipped_by_the_target_brick(self):
        self.evidence(lambda e: e.update(where="report:pgbadger"))
        self.assertRefused("scenario.yaml: fault_instances[f3]: fault fixture-job-timezone's "
                           "evidence[0] reads report:pgbadger, but brick scheduler 0.1.0 ships "
                           "no pgbadger (report_tools: none)")

    def test_report_tool_accepted(self):
        self.edit_yaml("faults/fixture-random-page-cost/fault.yaml",
                       lambda d: d["evidence"][0].update(where="report:pgbadger"))
        model.load_scenario(self.scenario)

    def test_behavioural_is_a_boolean(self):
        self.fault("fixture-job-timezone", lambda d: d["sealed_check"].update(behavioural="yes"))
        self.assertRefused(f"{self.LABEL}: sealed_check.behavioural: 'yes' is not a boolean")


class TestBehaviouralCheckRefusals(V03CopyTest):
    """A behavioural check's window and threshold (master spec 6.2, 11; W1
    item 4)."""

    KEY = "gm/answer-key.yaml"

    def behavioural(self):
        self.fault("fixture-job-timezone", lambda d: d["sealed_check"].update(behavioural=True))

    def check(self, **values):
        self.edit_yaml(self.KEY, lambda d: d["instances"][2]["sealed_check"].update(values))

    def test_window_and_threshold_required(self):
        self.behavioural()
        self.assertRefused("gm/answer-key.yaml: instances[f3].sealed_check.window: missing "
                           "(fault fixture-job-timezone's sealed check is behavioural)",
                           "gm/answer-key.yaml: instances[f3].sealed_check.threshold: missing")

    def test_window_and_threshold_accepted(self):
        self.behavioural()
        self.check(window="30m", threshold=0)
        model.load_scenario(self.scenario)

    def test_only_for_a_behavioural_check(self):
        self.check(window="30m", threshold=0)
        self.assertRefused("instances[f3].sealed_check.window: fault fixture-job-timezone's "
                           "sealed check is not behavioural",
                           "instances[f3].sealed_check.threshold: fault fixture-job-timezone's "
                           "sealed check is not behavioural")

    def test_window_is_a_duration_threshold_a_number(self):
        self.behavioural()
        self.check(window="half an hour", threshold="low")
        self.assertRefused("instances[f3].sealed_check.window: 'half an hour' is not a duration",
                           "instances[f3].sealed_check.threshold: 'low' is not a number")


class TestBrickV03Refusals(V03CopyTest):
    """v0.3's brick keys (master spec 6.4, 7.3 "Snapshot"; W1 items 3 and 5;
    D167), on the fixture's scheduler brick."""

    LABEL = "bricks/scheduler/brick.yaml"

    def assertBrickRefused(self, change, *fragments):
        problems = self.brick_problems(change)
        for fragment in fragments:
            self.assertIn(fragment, problems)

    def test_roles_from_the_closed_list(self):
        self.assertBrickRefused(lambda d: d.update(roles=["producer", "metrics-store"]),
                                f"{self.LABEL}: roles: metrics-store is not in the roles list "
                                "(bastion producer queue database pooler transformer consumer "
                                "monitoring backup; master spec 6.4)")

    def test_disk_growth_per_hour(self):
        self.assertBrickRefused(lambda d: d["footprint"].pop("disk_growth_per_hour"),
                                f"{self.LABEL}: footprint.disk_growth_per_hour: missing")
        self.setUp()
        self.assertBrickRefused(lambda d: d["footprint"].update(disk_growth_per_hour="lots"),
                                f"{self.LABEL}: footprint.disk_growth_per_hour: not a size: "
                                "'lots'")

    def test_writable_paths(self):
        self.assertBrickRefused(
            lambda d: d.update(writable_paths=["srv/jobs", "/srv/my jobs", "/srv/jobs/"]),
            f"{self.LABEL}: writable_paths: 'srv/jobs' is not an absolute path",
            f"{self.LABEL}: writable_paths: '/srv/my jobs' contains whitespace",
            f"{self.LABEL}: writable_paths: /srv/jobs/ ends with /")

    def test_seed_paths_cover_the_seed_files(self):
        def change(d):
            d["seed"]["paths"].pop("jobs.yaml")
            d["seed"]["paths"]["extra.yaml"] = "/srv/extra.yaml"
        self.assertBrickRefused(change,
                                f"{self.LABEL}: seed.paths: no entry for the seed file jobs.yaml",
                                f"{self.LABEL}: seed.paths.extra.yaml: not a seed file of the "
                                "brick (seed.files)")

    def test_seed_modes(self):
        def change(d):
            d["seed"]["modes"] = {"schedule.yaml": "0o400", "other.yaml": "0400"}
        self.assertBrickRefused(change,
                                f"{self.LABEL}: seed.modes.schedule.yaml: mode '0o400' is not a "
                                "quoted octal string",
                                f"{self.LABEL}: seed.modes.other.yaml: not a seed file of the "
                                "brick (seed.files)")

    def test_only_with_role(self):
        self.assertBrickRefused(lambda d: d["secrets"][0].update(only_with_role="proxy"),
                                f"{self.LABEL}: secrets[player_ssh_pubkey].only_with_role: proxy "
                                "is not in the roles list")

    def test_report_tools(self):
        self.assertBrickRefused(lambda d: d.update(report_tools=["PgBadger"]),
                                f"{self.LABEL}: report_tools: 'PgBadger' is not a tool name in "
                                "lowercase")

    def test_reserved_parameter_names(self):
        self.assertBrickRefused(
            lambda d: d.update(parameters={"write_policy": {
                "description": "x", "default": None, "required": False}}),
            f"{self.LABEL}: parameters.write_policy: a reserved name: render passes the node's "
            "write policy and overrides as GM_WRITE_POLICY and GM_WRITE_OVERRIDES")

    def test_snapshot_methods_and_volumes(self):
        def change(d):
            d["snapshot"].pop("home")
            d["snapshot"].update(jobs="rsync", run="copy", spool="copy")
        self.assertBrickRefused(
            change,
            f"{self.LABEL}: snapshot.jobs: rsync is not one of pg_basebackup, copy, stop",
            f"{self.LABEL}: snapshot.run: the volume at /run is never copied",
            f"{self.LABEL}: snapshot.spool: not a volume of the brick",
            f"{self.LABEL}: snapshot: volume home is not named (snapshot names every volume but "
            "the one at /run)")

    def test_snapshot_one_pg_basebackup_volume(self):
        self.assertBrickRefused(
            lambda d: d["snapshot"].update(repository="pg_basebackup", jobs="pg_basebackup"),
            f"{self.LABEL}: snapshot: repository, jobs: at most one pg_basebackup volume per "
            "brick")

    def test_snapshot_absent_accepted(self):
        self.assertEqual(self.brick_problems(lambda d: d.pop("snapshot")), "")

    def test_snapshot_pg_basebackup_needs_no_helper_check(self):
        # D167: whether the brick ships gm-snapshot-db is its stack test's.
        self.assertEqual(self.brick_problems(
            lambda d: d["snapshot"].update(schedstate="pg_basebackup")), "")


class TestSeedFolderEntry(V03CopyTest):
    """A seed entry ending in / (builders/): optional; a folder of files
    (W1 item 3)."""

    BUILDERS = "nodes/producer/builders"

    def test_entry_optional(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "producer")["seed_files"].pop("builders/"))
        problems = "\n".join(model.check_scenario(self.scenario)[1])
        self.assertNotIn("no entry for the brick's seed file builders/", problems)

    def test_folder_missing(self):
        shutil.rmtree(self.scenario / self.BUILDERS)
        self.assertRefused("nodes/producer/builders/: missing folder "
                           "(nodes[producer].seed_files.builders/)")

    def test_folder_holds_files_only(self):
        (self.scenario / self.BUILDERS / "lib").mkdir()
        (self.scenario / self.BUILDERS / ".hidden").write_text("x\n")
        self.assertRefused("nodes/producer/builders/lib: a subfolder; a folder seed entry holds "
                           "files only",
                           "nodes/producer/builders/.hidden: not a seed file name")

    def test_folder_not_empty(self):
        for path in (self.scenario / self.BUILDERS).iterdir():
            path.unlink()
        self.assertRefused("nodes/producer/builders/: holds no file")


class TestRetentionRefusals(RefusalAsserts, ScenarioCopyTest):
    """Prometheus' retention by time (master spec 6.1; W1 item 2), on
    fixture-monitoring: 4h with no aging, aging.minimum plus 4h with."""

    PROM = "nodes/prometheus/prometheus.yml"

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-monitoring"
        shutil.copytree(FIXTURE_MONITORING, self.scenario)

    def retention(self, change):
        self.edit_yaml(self.PROM, lambda d: change(d["storage"]["tsdb"]["retention"]))

    def add_scheduler_node(self):
        """fixture-v03-refusals' producer node, so the scenario ages (16h)."""
        shutil.copytree(FIXTURE_V03 / "bricks", self.scenario / "bricks")
        shutil.copytree(FIXTURE_V03 / "nodes" / "producer", self.scenario / "nodes" / "producer")
        self.edit_yaml("nodes/producer/jobs.yaml",
                       lambda d: d["jobs"][0].pop("timezone_offset"))
        producer = yaml.safe_load((FIXTURE_V03 / "scenario.yaml").read_text())["nodes"][2]
        producer.pop("write_overrides")

        def change(d):
            d["nodes"].append(producer)
            d["aging"] = {"minimum": "16h", "handover_at": "14:00"}
            self.node(d, "prometheus")["parameters"]["node_health"]["producer"] = "default"
            d["designed_for"]["placement"]["producer"] = d["designed_for"]["hosts"][0]["name"]
        self.edit_yaml("scenario.yaml", change)

    def test_four_hours_with_no_aging(self):
        self.retention(lambda r: r.update(time="3h"))
        self.assertRefused(f"{self.PROM}: storage.tsdb.retention.time: 3h is less than 4h (the "
                           "game, with no aging) (node prometheus; master spec 6.1)")

    def test_four_hours_accepted(self):
        self.retention(lambda r: r.update(time="4h"))
        model.load_scenario(self.scenario)

    def test_time_bound_required(self):
        self.retention(lambda r: r.pop("time"))
        self.assertRefused(f"{self.PROM}: storage.tsdb.retention.time: missing")

    def test_time_is_a_prometheus_duration(self):
        self.retention(lambda r: r.update(time="one day"))
        self.assertRefused(f"{self.PROM}: storage.tsdb.retention.time: 'one day' is not a "
                           "Prometheus duration")

    def test_aging_minimum_plus_four_hours(self):
        self.add_scheduler_node()
        model.load_scenario(self.scenario)             # 1d covers 16h + 4h
        self.retention(lambda r: r.update(time="18h"))
        self.assertRefused(f"{self.PROM}: storage.tsdb.retention.time: 18h is less than "
                           "aging.minimum 16h plus 4h")

    def test_fault_about_retention_exempts(self):
        local = self.scenario / "faults" / "fixture-short-retention"
        shutil.copytree(FIXTURE_MONITORING / "faults" / "fixture-random-page-cost", local)

        def fault(d):
            d.update(id="fixture-short-retention", family="retention")
            d["applies_to"]["bricks"] = [{"id": "prometheus", "versions": ["0.2.0"]}]
            d["injection"]["seed_changes"] = [{"file": "prometheus.yml",
                                               "change": "retention.time: 2h"}]
        self.edit_yaml("faults/fixture-short-retention/fault.yaml", fault)

        def scenario(d):
            d["fault_instances"].append({
                "id": "f2", "fault": {"id": "fixture-short-retention", "version": "0.1.0"},
                "node": "prometheus", "parameters": {}, "visibility": "hidden"})
            d["difficulty"]["score"] = 2
        self.edit_yaml("scenario.yaml", scenario)
        self.edit_yaml("gm/answer-key.yaml", lambda d: d["instances"].append(
            dict(d["instances"][0], instance="f2")))
        self.retention(lambda r: r.update(time="2h"))
        model.load_scenario(self.scenario)


class TestPostgresSeedRefusals(RefusalAsserts, ScenarioCopyTest):
    """A postgres seed lets pg_basebackup in as postgres and the GM check
    role in by password or trust (master spec 7.3; W1 item 8; D164, D171)."""

    HBA = "nodes/db/pg_hba.conf"
    CONF = "nodes/db/postgresql.conf"
    HEAD = "# TYPE  DATABASE  USER  ADDRESS  METHOD\n# DO NOT TAMPER\n"

    def hba(self, *lines):
        (self.scenario / self.HBA).write_text(self.HEAD + "\n".join(lines) + "\n")

    def test_replication_line_required(self):
        self.hba("local all postgres peer", "local all gm_check scram-sha-256",
                 "local all all scram-sha-256")
        self.assertRefused(f"{self.HBA}: no local line allows a replication connection for "
                           "postgres (local replication postgres peer")

    def test_replication_by_peer_or_trust(self):
        self.hba("local all postgres peer", "local replication postgres scram-sha-256",
                 "local all gm_check scram-sha-256")
        self.assertRefused(f"{self.HBA}: line 4: local replication postgres scram-sha-256: the "
                           "hand-over snapshot's pg_basebackup connects as postgres over the local "
                           "socket by peer or trust")

    def test_replication_by_trust_for_all_accepted(self):
        self.hba("local all postgres peer", "local replication all trust",
                 "local all gm_check scram-sha-256")
        model.load_scenario(self.scenario)

    def test_gm_check_admitted_before_any_reject(self):
        self.hba("local all postgres peer", "local replication postgres peer",
                 "local all all reject", "local all gm_check scram-sha-256")
        self.assertRefused(f"{self.HBA}: line 5: local all all reject: comes before any local line "
                           "admitting gm_check by password or trust")

    def test_gm_check_by_a_general_line_accepted(self):
        self.hba("local all postgres peer", "local replication postgres peer",
                 "local all all scram-sha-256")
        model.load_scenario(self.scenario)

    def test_gm_check_by_trust_accepted(self):
        self.hba("local all postgres peer", "local replication postgres peer",
                 "local all gm_check trust", "local all all reject")
        model.load_scenario(self.scenario)

    def test_gm_check_needs_a_line(self):
        self.hba("local all postgres peer", "local replication postgres peer",
                 "local shop gm_check scram-sha-256", "host all all 0.0.0.0/0 scram-sha-256")
        self.assertRefused(f"{self.HBA}: no local line admits gm_check by password or trust "
                           "(local all gm_check scram-sha-256")

    def test_gm_check_by_peer_refused(self):
        self.hba("local all postgres peer", "local replication postgres peer",
                 "local all all peer", "local all gm_check scram-sha-256")
        self.assertRefused(f"{self.HBA}: line 5: local all all peer: comes before any local line "
                           "admitting gm_check")

    def test_settings_allow_replication(self):
        conf = self.scenario / self.CONF
        conf.write_text(conf.read_text() + "max_wal_senders = 0\nwal_level = minimal\n")
        self.assertRefused(f"{self.CONF}: max_wal_senders: 0 refuses the hand-over snapshot's "
                           "pg_basebackup",
                           f"{self.CONF}: wal_level: minimal refuses the hand-over snapshot's "
                           "pg_basebackup")


class SchedulerFilesTest(V03CopyTest):
    """The scheduler's files of fixture-v03-refusals' producer node (master
    spec 7.1; W1 item 7; D168)."""

    Q = "nodes/producer/queries.yaml"
    S = "nodes/producer/schedule.yaml"
    J = "nodes/producer/jobs.yaml"

    def queries(self, change):
        self.edit_yaml(self.Q, lambda d: change(d["queries"]))

    def schedule(self, change):
        self.edit_yaml(self.S, change)

    def jobs(self, change):
        self.edit_yaml(self.J, lambda d: change(d["jobs"]))


class TestSchedulerTemplates(unittest.TestCase):
    """The format skill's templates for the scheduler's files are the
    loader's schema (master spec 7.1)."""

    def test_required_keys(self):
        schedule = model.template_schema("schedule.yaml")
        self.assertFalse(schedule.fields["streams"].optional)
        self.assertTrue(schedule.fields["timeline"].optional)
        self.assertTrue(schedule.fields["shapes"].optional)
        stream = schedule.fields["streams"].child.item
        self.assertTrue(stream.fields["shape"].optional)
        self.assertFalse(stream.fields["rate"].optional)
        job = model.template_schema("jobs.yaml").fields["jobs"]
        self.assertTrue(job.allow_empty)
        self.assertTrue(job.child.item.fields["timezone_offset"].optional)
        self.assertIsNone(model.template_schema("queries.yaml").fields["queries"].child)


class TestQueryRefusals(SchedulerFilesTest):

    def test_key_shape(self):
        self.queries(lambda q: q.update({"Orders Insert": q["orders.insert"]}))
        self.assertRefused(f"{self.Q}: queries.Orders Insert: 'Orders Insert' is not a key "
                           "([a-z0-9][a-z0-9._-]*)")

    def test_entry_forms(self):
        self.queries(lambda q: q.update({"orders.odd": {"statement": "SELECT 1"},
                                         "orders.empty": []}))
        self.assertRefused(f"{self.Q}: queries.orders.odd: not a query (sql), a pool (a list of "
                           "queries), a sequence (steps), a builder (builder) or a script "
                           "(script)",
                           f"{self.Q}: queries.orders.empty: a pool lists at least one query")

    def test_query_keys(self):
        self.queries(lambda q: q["orders.insert"].update(retries=3, sql=""))
        self.assertRefused(f"{self.Q}: queries.orders.insert.retries: not a key of a query (sql, "
                           "params, transaction)",
                           f"{self.Q}: queries.orders.insert.sql: not a statement")

    def test_generators(self):
        cases = {
            "{'between': [1, 5]}": {"between": [1, 5]},
            "int: [5, 1] is not [lo, hi], integers, lo <= hi": {"int": [5, 1]},
            "decimal: [5, 500] is not [lo, hi, places]": {"decimal": [5, 500]},
            "choice: [] is not a non-empty list of values": {"choice": []},
            "sequence: [1, 0] is not [start, step], integers, step not 0": {"sequence": [1, 0]},
            "now: 'local' is not utc": {"now": "local"},
        }
        for message, generator in cases.items():
            with self.subTest(generator=generator):
                self.setUp()
                self.queries(lambda q: q["orders.insert"]["params"].update(customer_id=generator))
                self.assertRefused(f"{self.Q}: queries.orders.insert.params.customer_id",
                                   message)

    def test_transaction(self):
        self.queries(lambda q: q["orders.insert-v2"].update(
            transaction={"isolation": "snapshot", "hold": "2 seconds"}))
        self.assertRefused(f"{self.Q}: queries.orders.insert-v2.transaction.isolation: 'snapshot' "
                           "is not one of read committed, repeatable read, serializable",
                           f"{self.Q}: queries.orders.insert-v2.transaction.hold: '2 seconds' is "
                           "not a duration")

    def test_pool_weight(self):
        self.queries(lambda q: q["orders.lookup"][0].update(weight=0))
        self.assertRefused(f"{self.Q}: queries.orders.lookup[0].weight: 0 is not a positive "
                           "integer")

    def test_sequence_steps(self):
        self.queries(lambda q: q["orders.close-day"].update(steps=[]))
        self.assertRefused(f"{self.Q}: queries.orders.close-day.steps: not a non-empty list")
        self.setUp()
        self.queries(lambda q: q["orders.close-day"]["steps"][0].update(
            transaction={"isolation": "serializable"}))
        self.assertRefused(f"{self.Q}: queries.orders.close-day.steps[0].transaction: not a key "
                           "of a step (sql, params)")

    def test_builder_reference(self):
        self.queries(lambda q: q["reports.revenue"].update(builder="revenue.py:build"))
        self.assertRefused(f"{self.Q}: queries.reports.revenue.builder: 'revenue.py:build' is not "
                           "builders/<file>:<function>")

    def test_builder_file_exists(self):
        self.queries(lambda q: q["reports.revenue"].update(builder="builders/sales.py:build"))
        self.assertRefused(f"{self.Q}: queries.reports.revenue.builder: builders/sales.py:build: "
                           "nodes/producer/builders/sales.py does not exist")

    def test_builder_function_exists(self):
        self.queries(lambda q: q["reports.revenue"].update(builder="builders/revenue.py:report"))
        self.assertRefused(f"{self.Q}: queries.reports.revenue.builder: builders/revenue.py:"
                           "report: nodes/producer/builders/revenue.py defines no function report "
                           "at its top level")

    def test_builder_file_parses(self):
        (self.scenario / "nodes/producer/builders/revenue.py").write_text("def build(:\n")
        self.assertRefused("nodes/producer/builders/revenue.py: cannot be parsed as Python")

    def test_builder_needs_the_folder(self):
        self.edit_yaml("scenario.yaml",
                       lambda d: self.node(d, "producer")["seed_files"].pop("builders/"))
        self.assertRefused(f"{self.Q}: queries.reports.revenue.builder: builders/revenue.py:build, "
                           "but the node has no builders/ seed folder")

    def test_sql_is_not_a_placeholder(self):
        self.queries(lambda q: q["orders.insert"].update(
            sql="SELECT 1 WHERE %(a)s <> 0 AND <b> > 1"))
        problems = "\n".join(model.check_scenario(self.scenario)[1])
        self.assertNotIn("placeholder", problems)

    def test_placeholder_left(self):
        self.queries(lambda q: q["reports.revenue"].update(options={"months": "<3>"}))
        self.assertRefused(f"{self.Q}: queries.reports.revenue.options.months: placeholder <3> "
                           "left")


class TestScheduleRefusals(SchedulerFilesTest):

    def test_required_keys(self):
        self.schedule(lambda d: [d.pop("intensity"), d["streams"][0].pop("rate")])
        self.assertRefused(f"{self.S}: intensity: missing",
                           f"{self.S}: streams[orders.insert].rate: missing")

    def test_no_other_key(self):
        self.schedule(lambda d: d.update(seed=42))
        self.assertRefused(f"{self.S}: seed: not a key of a schedule (intensity, connections, "
                           "streams, shapes, timeline); the game's seed is render's")

    def test_intensity_positive(self):
        self.schedule(lambda d: d.update(intensity=0))
        self.assertRefused(f"{self.S}: intensity: 0 is not a positive number")

    def test_connection(self):
        self.schedule(lambda d: d["connections"]["app"].update(
            driver="sql/mysql", target="cache:5432/shop", role="gm_check",
            pool={"size": 0}))
        self.assertRefused(f"{self.S}: connections.app.driver: sql/mysql is not a known driver "
                           "(sql/postgresql)",
                           f"{self.S}: connections.app.target: cache:5432/shop: cache is not a "
                           "node of the topology",
                           f"{self.S}: connections.app.role: gm_check is reserved",
                           f"{self.S}: connections.app.pool: {{'size': 0}} is not {{size: N}}")

    def test_connection_target_and_role_shapes(self):
        self.schedule(lambda d: d["connections"]["app"].update(
            target="db/shop", role="pg_monitor", pool={"size": 2, "per-call": True}))
        self.assertRefused(f"{self.S}: connections.app.target: 'db/shop' is not "
                           "<node>:<port>/<database>",
                           f"{self.S}: connections.app.role: pg_monitor is reserved",
                           f"{self.S}: connections.app.pool:")

    def test_stream_references(self):
        self.schedule(lambda d: d["streams"][0].update(
            key="orders.delete", connection="batch", shape="night"))
        self.assertRefused(f"{self.S}: streams[orders.delete].key: orders.delete is not a key of "
                           "the node's queries.yaml",
                           f"{self.S}: streams[orders.delete].connection: batch is not a "
                           "connection of the schedule",
                           f"{self.S}: streams[orders.delete].shape: night is not a shape of the "
                           "schedule")

    def test_stream_values(self):
        self.schedule(lambda d: d["streams"][0].update(
            rate="40 per minute", arrivals="burst", concurrency=0))
        self.assertRefused(f"{self.S}: streams[orders.insert].rate: '40 per minute' is not a rate",
                           f"{self.S}: streams[orders.insert].arrivals: burst is not poisson or "
                           "even",
                           f"{self.S}: streams[orders.insert].concurrency: 0 is not a positive "
                           "integer")

    def test_stream_identity(self):
        self.schedule(lambda d: d["streams"].append(dict(d["streams"][0])))
        self.assertRefused(f"{self.S}: streams[orders.insert]: another stream starts with key "
                           "orders.insert; a stream is known by its initial key")

    def test_hours_cover_the_day_once(self):
        self.schedule(lambda d: d["shapes"]["business-hours"].update(
            hours={"00-06": 0.1, "06-11": 1.0, "13-23": 1.0}))
        self.assertRefused(f"{self.S}: shapes.business-hours.hours: hour(s) 12 not covered",
                           f"{self.S}: shapes.business-hours.hours: hour(s) 06 covered more than "
                           "once")

    def test_hours_forms(self):
        self.schedule(lambda d: d["shapes"]["business-hours"].update(
            hours={12: 1.0, "22-02": 0.1, "00-23": -1}))
        self.assertRefused(f"{self.S}: shapes.business-hours.hours: 12: hours are quoted strings",
                           f"{self.S}: shapes.business-hours.hours: '22-02' is not an hour or a "
                           "range of hours (00 to 23, never wrapping)",
                           f"{self.S}: shapes.business-hours.hours.00-23: -1 is not a multiplier")

    def test_days_cover_the_week_once(self):
        self.schedule(lambda d: d["shapes"]["weekly"]["days"].update(
            {"sat-sun": {"hours": {"00-23": 0.3}}, "fri-sat": {"hours": {"00-23": 0.5}},
             "sun-mon": {"hours": {"00-23": 0.1}}}))
        self.assertRefused(f"{self.S}: shapes.weekly.days: 'sun-mon' is not a day or a range of "
                           "days",
                           f"{self.S}: shapes.weekly.days: day(s) fri, sat covered more than once")

    def test_shape_form(self):
        self.schedule(lambda d: d["shapes"].update(night={"minutes": {}}))
        self.assertRefused(f"{self.S}: shapes.night: a shape is {{hours: ...}} or {{days: ...}}")

    def test_timeline_before_hand_over_within_the_aging(self):
        for at, message in (("handover-20h", "handover-20h is further before hand-over than "
                                             "aging.minimum 16h"),
                            ("handover-0h", "'handover-0h' is not T0 or handover-<N>h"),
                            ("handover+1h", "'handover+1h' is not T0 or handover-<N>h")):
            with self.subTest(at=at):
                self.setUp()
                self.schedule(lambda d: d["timeline"][0].update(at=at))
                self.assertRefused(f"{self.S}: timeline[0].at: {message}")

    def test_timeline_at_t0_accepted(self):
        self.schedule(lambda d: d["timeline"][0].update(at="T0"))
        model.load_scenario(self.scenario)

    def test_timeline_references(self):
        self.schedule(lambda d: d["timeline"][0].update(
            stream="orders.insert-v2", set={"key": "orders.nope", "rate": "fast",
                                            "connection": "batch", "shape": "x"}))
        self.assertRefused(f"{self.S}: timeline[0].stream: orders.insert-v2 is not a stream of the "
                           "schedule (a stream is named by its initial key)",
                           f"{self.S}: timeline[0].set.key: orders.nope is not a key of the "
                           "node's queries.yaml",
                           f"{self.S}: timeline[0].set.rate: 'fast' is not a rate",
                           f"{self.S}: timeline[0].set.connection: batch is not a connection",
                           f"{self.S}: timeline[0].set.shape: not a key of a change (key, rate, "
                           "connection)")

    def test_timeline_set_not_empty(self):
        self.schedule(lambda d: d["timeline"][0].update(set={}))
        self.assertRefused(f"{self.S}: timeline[0].set: empty")


class TestJobsRefusals(SchedulerFilesTest):

    def test_references(self):
        self.jobs(lambda j: j[1].update(key="reports.daily", connection="batch"))
        self.assertRefused(f"{self.J}: jobs[weekly-report].key: reports.daily is not a key of the "
                           "node's queries.yaml",
                           f"{self.J}: jobs[weekly-report].connection: batch is not a connection "
                           "of the node's schedule.yaml")

    def test_no_timezone(self):
        self.jobs(lambda j: j[1].update(timezone="Europe/Paris"))
        self.assertRefused(f"{self.J}: jobs[weekly-report].timezone: a scenario's job carries no "
                           "timezone:")

    def test_unknown_key_and_duplicate_name(self):
        self.jobs(lambda j: j.append(dict(j[1], retries=2)))
        self.assertRefused(f"{self.J}: jobs[weekly-report].retries: not a key of a job",
                           f"{self.J}: jobs[weekly-report]: duplicate job name")

    def test_cron_subset(self):
        cases = {
            "30 1 * *": "is not a 5-field cron expression",
            "61 1 * * *": "minute 61 is not a numeric cron form",
            "30 24 * * *": "hour 24 is not *, or a comma list of n, a-b, */s or a-b/s within "
                           "0-23 (a <= b, never wrapping; s >= 1)",
            "30 20-8 * * *": "hour 20-8 is not *, or a comma list",
            "30 */0 * * *": "hour */0 is not *, or a comma list",
            "30 1-3/0 * * *": "hour 1-3/0 is not *, or a comma list",
            "30 *,3 * * *": "hour *,3 is not *, or a comma list",
            "30 5/2 * * *": "hour 5/2 is not *, or a comma list",
            "30 1-24 * * *": "hour 1-24 is not *, or a comma list",
            "30 1 1 * *": "day of month and month are *",
            "30 1 * 6 *": "day of month and month are *",
            "30 1 * * 7": "day of week 7 is not *, a number or a list of numbers (0-6)",
            "30 1,13 * * 1": "a day of week needs a single-number hour (it is 1,13)",
        }
        for at, message in cases.items():
            with self.subTest(at=at):
                self.setUp()
                self.jobs(lambda j: j[1].update(at=at))
                self.assertRefused(f"{self.J}: jobs[weekly-report].at: {at!r}", message)

    def test_cron_accepted(self):
        for at in ("*/15 * * * *", "0-30/10 8,12 * * *", "5 6 * * 0,6", "1,31 23 * * *",
                   "*/15 8-20 * * *", "30 */2 * * *", "0 1-3,8-20/2,23 * * *", "0 0-23 * * *"):
            with self.subTest(at=at):
                self.setUp()
                self.jobs(lambda j: j[1].update(at=at))
                model.load_scenario(self.scenario)

    def test_timezone_offset_needs_a_jobs_fault_on_the_node(self):
        def drop(d):
            d["fault_instances"].pop()
            d["issues"] = []
            d["difficulty"]["score"] = 2
        self.edit_yaml("scenario.yaml", drop)
        self.edit_yaml("gm/answer-key.yaml", lambda d: d["instances"].pop())
        self.assertRefused(f"{self.J}: jobs[close-day].timezone_offset: only on a node where a "
                           "fault instance's seed change edits jobs.yaml (the wrong-time-zone "
                           "fault, spec D168)")

    def test_timezone_offset_non_zero_whole_hours(self):
        for offset in (0, 1.5, "-2"):
            with self.subTest(offset=offset):
                self.setUp()
                self.jobs(lambda j: j[0].update(timezone_offset=offset))
                self.assertRefused(f"{self.J}: jobs[close-day].timezone_offset: {offset!r} is not "
                                   "a non-zero whole number of hours")

    def test_no_job_accepted(self):
        self.jobs(lambda j: j.clear())
        model.load_scenario(self.scenario)


# --- v0.4 (build plan chunk 2; capture W1 of specs/versions/v0.4/wave-log.md) ---

FIXTURE_V04 = FIXTURES / "fixture-v04-refusals"


class V04CopyTest(RefusalAsserts, ScenarioCopyTest):
    """Each test works on a fresh copy of fixture-v04-refusals: scenario-local
    postgres 0.4.0, scheduler 0.2.0 and bastion 0.4.0 bricks (W1 item 9), a
    purpose and a domain under its test catalog root catalog/ (W1 item 0),
    governance:, f1 a seed-file fault on db, f2 a purpose fault on the
    runner bi whose sealed check judges runs."""

    PURPOSE = "catalog/purposes/fixture-sales-copy"
    DOMAIN = "catalog/domains/fixture-shop"

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-v04-refusals"
        shutil.copytree(FIXTURE_V04, self.scenario)
        self.catalog_root = self.scenario / "catalog"

    def scenario_yaml(self, change):
        self.edit_yaml("scenario.yaml", change)

    def governance(self, change):
        self.scenario_yaml(lambda d: change(d["governance"]))

    def classes(self, change):
        self.governance(lambda g: change(g["classes"]))

    def parts(self, change):
        self.scenario_yaml(lambda d: change(d["purposes"][0]["parts"]))

    def purpose(self, change):
        self.edit_yaml(f"{self.PURPOSE}/purpose.yaml", change)

    def purpose_problems(self, change=None):
        if change is not None:
            self.purpose(change)
        return "\n".join(model.check_purpose_dir(self.scenario / self.PURPOSE))

    def domain_problems(self, change=None):
        if change is not None:
            self.edit_yaml(f"{self.DOMAIN}/domain.yaml", change)
        return "\n".join(model.check_domain_dir(self.scenario / self.DOMAIN))

    def assertProblems(self, text, *fragments):
        for fragment in fragments:
            self.assertIn(fragment, text)


class TestV04Fixture(unittest.TestCase):
    """The valid fixture, its test catalog and its bricks."""

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_V04, FIXTURE_V04 / "catalog")
        self.assertEqual(sc.data["domain"], "fixture-shop")
        self.assertEqual(sc.data["purposes"][0]["parts"]["runner"], "bi")
        self.assertEqual(sc.bricks["bi"].version, "0.2.0")
        self.assertEqual(sc.bricks["db"].source, "scenario")
        self.assertNotIn("crontab", sc.node("db")["seed_files"])
        self.assertEqual(sc.answer_key["instances"][1]["sealed_check"]["judges"], "runs")

    def test_test_catalog_is_complete(self):
        catalog = FIXTURE_V04 / "catalog"
        self.assertEqual(model.check_purpose_dir(catalog / "purposes" / "fixture-sales-copy"), [])
        self.assertEqual(model.check_domain_dir(catalog / "domains" / "fixture-shop"), [])

    def test_fixture_bricks_are_complete(self):
        for brick in ("bastion", "postgres", "scheduler"):
            with self.subTest(brick=brick):
                self.assertEqual(model.check_brick_dir(FIXTURE_V04 / "bricks" / brick), [])

    def test_repository_catalog_lacks_the_test_purpose(self):
        with self.assertRaises(model.IncompleteScenario) as cm:
            model.load_scenario(FIXTURE_V04)
        self.assertIn("scenario.yaml: purposes[fixture-sales-copy].id: purpose fixture-sales-copy "
                      "not found (looked in purposes/fixture-sales-copy/ of the catalog)",
                      cm.exception.missing)

    def test_template_comment_after_an_apostrophe(self):
        # `consumer: <the back office's dashboards>  # optional: ...`
        parts = model.template_schema("purpose.yaml").fields["parts"].child
        self.assertTrue(parts.fields["consumer"].optional)
        self.assertTrue(parts.fields["receiver"].optional)
        self.assertFalse(parts.fields["source"].optional)

    def test_data_file_reading(self):
        created = model.data_file_creates(
            "CREATE DATABASE shop OWNER shop;\n  create role bi_etl LOGIN;\nCreate User u1;\n"
            "-- CREATE ROLE commented;\nCREATE ROLE \"Quoted\";\nCREATE ROLE Mixed;\n"
            "SELECT 1; CREATE ROLE inline;\nCREATE EXTENSION IF NOT EXISTS pg_cron;\n", "x.sql")
        self.assertEqual(created.databases, {"shop"})
        self.assertEqual(created.roles, {"bi_etl", "u1"})
        self.assertTrue(created.pg_cron)
        self.assertFalse(model.data_file_creates("-- CREATE EXTENSION pg_cron;\n"
                                                 "CREATE EXTENSION pg_cronx;\n", "y").pg_cron)


class TestScenarioPurposeRefusals(V04CopyTest):
    """purposes: (master spec 6.1, 6.9; W1 item 1)."""

    P = "scenario.yaml: purposes[fixture-sales-copy]"

    def test_unknown_purpose(self):
        self.scenario_yaml(lambda d: d["purposes"].append({"id": "nope", "parts": {
            "source": "db/shop", "target": "db/shop", "runner": "bi"}}))
        self.assertRefused("scenario.yaml: purposes[nope].id: purpose nope not found (looked in "
                           "purposes/nope/ of the catalog)")

    def test_purpose_listed_twice(self):
        self.scenario_yaml(lambda d: d["purposes"].append(dict(d["purposes"][0])))
        self.assertRefused(f"{self.P}: purpose fixture-sales-copy listed more than once")

    def test_empty_purposes(self):
        self.scenario_yaml(lambda d: d.update(purposes=[]))
        self.assertRefused("scenario.yaml: purposes: empty")

    def test_parts_mapped_exactly(self):
        self.parts(lambda p: (p.pop("target"), p.update(consumer="bi")))
        self.assertRefused(f"{self.P}.parts.target: missing (purpose fixture-sales-copy declares "
                           "it)",
                           f"{self.P}.parts.consumer: not a part purpose fixture-sales-copy "
                           "declares (source, target, runner)")

    def test_locations(self):
        cases = {
            "db": "'db' is not a location <node>/<database>",
            "db/Shop": "'db/Shop' is not a location <node>/<database>",
            "nowhere/shop": "nowhere/shop: nowhere is not a node",
            "bi/shop": "bi/shop: bi is not a database node (its role is transformer)",
            "db/reporting": "db/reporting: reporting is not a database node db's data file "
                            "(data/db.sql) creates (CREATE DATABASE reporting)",
        }
        for value, message in cases.items():
            with self.subTest(value=value):
                self.setUp()
                self.parts(lambda p: p.update(source=value))
                self.assertRefused(f"{self.P}.parts.source: {message}")

    def test_location_needs_a_data_file(self):
        self.scenario_yaml(lambda d: self.node(d, "reporting").pop("data"))
        self.assertRefused(f"{self.P}.parts.target: reporting/reporting: node reporting has no "
                           "data file to create database reporting")

    def test_source_and_target_may_be_equal(self):
        self.parts(lambda p: p.update(target="db/shop"))
        self.load()

    def test_runner_role(self):
        self.parts(lambda p: p.update(runner="db"))
        self.assertRefused(f"{self.P}.parts.runner: db is not a node of role transformer (its "
                           "role is database)")
        self.setUp()
        self.parts(lambda p: p.update(runner="nobody"))
        self.assertRefused(f"{self.P}.parts.runner: nobody is not a node")

    def test_jobs_on_the_runner(self):
        self.edit_yaml("nodes/bi/jobs.yaml", lambda d: d["jobs"][0].update(name="copy"))
        self.assertRefused(f"{self.P}.parts.runner: bi's jobs.yaml (nodes/bi/jobs.yaml) has no "
                           "job copy-hourly (a job of purpose fixture-sales-copy)")

    def test_job_key_on_the_runner(self):
        self.edit_yaml("nodes/bi/queries.yaml", lambda d: d["queries"].update(
            {"sales.other": {"sql": "SELECT 1"}}))
        self.edit_yaml("nodes/bi/jobs.yaml", lambda d: d["jobs"][0].update(key="sales.other"))
        self.assertRefused(f"{self.P}.parts.runner: bi's jobs.yaml (nodes/bi/jobs.yaml): job "
                           "copy-hourly has key sales.other, but purpose fixture-sales-copy's "
                           "job copy-hourly has key sales.copy")

    def test_purpose_problems_make_the_scenario_incomplete(self):
        self.purpose(lambda d: d.update(kind="streamed"))
        self.assertRefused("purposes/fixture-sales-copy/purpose.yaml: kind: streamed is not one "
                           "of pulled, transformed-in-place, pushed, pushed-obligation")


class TestPurposeDefinitionRefusals(V04CopyTest):
    """A purpose folder (master spec 6.7, 8; W1 item 5)."""

    L = "purposes/fixture-sales-copy/purpose.yaml"

    def test_identity_and_files(self):
        (self.scenario / self.PURPOSE / "gm.md").unlink()
        text = self.purpose_problems(lambda d: d.update(id="other"))
        self.assertProblems(text, f"{self.L}: id: other is not the folder name fixture-sales-copy",
                            "purposes/fixture-sales-copy/gm.md: missing file")

    def test_template(self):
        text = self.purpose_problems(lambda d: (d.pop("trace"), d["jobs"][0].pop("cadence"),
                                                d.update(title="<one line>")))
        self.assertProblems(text, f"{self.L}: trace: missing",
                            f"{self.L}: jobs[copy-hourly].cadence: missing",
                            f"{self.L}: title: placeholder <one line> left")

    def test_domains(self):
        text = self.purpose_problems(lambda d: d.update(domains=["nope", "Bad"]))
        self.assertProblems(text, f"{self.L}: domains: nope is not a domain (no "
                            "domains/nope/domain.yaml in the catalog)",
                            f"{self.L}: domains: 'Bad' is not a domain id")
        self.setUp()
        self.edit_yaml(f"{self.DOMAIN}/domain.yaml", lambda d: d.update(purposes=[]))
        self.assertProblems(self.purpose_problems(), f"{self.L}: domains: domain fixture-shop "
                            "does not list fixture-sales-copy in its domain.yaml purposes")

    def test_closed_values(self):
        def change(d):
            d["kind"] = "streamed"
            d["parts"]["sink"] = "somewhere"
            d["jobs"][0].update(method="magic", part="source", source="runner")
            d["trace"][0]["kind"] = "logs"
        text = self.purpose_problems(change)
        self.assertProblems(text, f"{self.L}: kind: streamed is not one of pulled",
                            f"{self.L}: parts.sink: not a part (source, target, runner, "
                            "consumer, receiver)",
                            f"{self.L}: jobs[copy-hourly].method: magic is not one of sql, script",
                            f"{self.L}: jobs[copy-hourly].part: source is not a declared runner "
                            "part (runner, the only one in v0.4)",
                            f"{self.L}: jobs[copy-hourly].source: runner is not a declared "
                            "database part (source, target)",
                            f"{self.L}: trace[0].kind: logs is not one of outbox-rows")

    def test_jobs(self):
        def change(d):
            d["jobs"][0]["cadence"] = "5 * 1 * *"
            d["jobs"].append(dict(d["jobs"][0]))
        text = self.purpose_problems(change)
        self.assertProblems(text, f"{self.L}: jobs[copy-hourly]: duplicate job name",
                            f"{self.L}: jobs[copy-hourly].cadence: '5 * 1 * *': day of month and "
                            "month are *")

    def test_trace(self):
        def change(d):
            d["trace"][0]["file"] = "/var/log/x.log"
            d["trace"][1].update(part="consumer", file="log/scheduler.log")
            d["trace"].append({"kind": "definitions", "part": "source", "run_column": "x"})
        text = self.purpose_problems(change)
        self.assertProblems(text, f"{self.L}: trace[0]: exactly one of table and file (it has "
                            "both)",
                            f"{self.L}: trace[1].part: consumer is not a declared part",
                            f"{self.L}: trace[1].file: 'log/scheduler.log' is not an absolute path",
                            f"{self.L}: trace[2]: exactly one of table and file (it has neither)",
                            f"{self.L}: trace[2].run_column: only with table")

    def test_invariants(self):
        def change(d):
            d["invariants"].append(dict(d["invariants"][0], check="checks/missing.sh"))
            d["invariants"].append(dict(d["invariants"][0], id="r2", check="gm.md"))
        text = self.purpose_problems(change)
        self.assertProblems(text, f"{self.L}: invariants[R1]: duplicate invariant id",
                            "purposes/fixture-sales-copy/checks/missing.sh: missing file "
                            "(invariants[R1].check, a file of checks/)",
                            f"{self.L}: invariants[r2].id: 'r2' is not [A-Z][0-9]+",
                            "purposes/fixture-sales-copy/gm.md: missing file (invariants[r2].check")

    def test_data_moved(self):
        def change(d):
            d["data_moved"][0].update(reads=["customers.email"],
                                      writes=["sales_hourly", "consumer:x"])
            d["data_moved"].append({"job": "nightly", "reads": [], "writes": ["target:t"]})
        text = self.purpose_problems(change)
        self.assertProblems(text, f"{self.L}: data_moved[copy-hourly].reads: 'customers.email' is "
                            "not a classification key <database>.<table>.<column>",
                            f"{self.L}: data_moved[copy-hourly].writes: 'sales_hourly' is not "
                            "<part>:<table>",
                            f"{self.L}: data_moved[copy-hourly].writes: consumer:x: consumer is "
                            "not a declared part",
                            f"{self.L}: data_moved[nightly].job: nightly is not a job of the "
                            "purpose")
        self.setUp()
        self.assertProblems(self.purpose_problems(lambda d: d["data_moved"][0].update(
            job="other")), f"{self.L}: data_moved: no entry for job copy-hourly (one entry per "
            "job)")

    def test_roles(self):
        text = self.purpose_problems(lambda d: d["roles"][0].update(part="runner"))
        self.assertProblems(text, f"{self.L}: roles[shop_etl].part: runner is not a declared "
                            "database part (source, target)")


class TestDomainRefusals(V04CopyTest):
    """domain: and a domain folder (master spec 6.1, 6.8; W1 item 6)."""

    L = "domains/fixture-shop/domain.yaml"

    def test_unknown_domain(self):
        self.scenario_yaml(lambda d: d.update(domain="nope"))
        self.assertRefused("scenario.yaml: domain: domain nope not found (looked in "
                           "domains/nope/ of the catalog)")

    def test_domain_problems_make_the_scenario_incomplete(self):
        self.edit_yaml(f"{self.DOMAIN}/domain.yaml", lambda d: d.update(id="other"))
        self.assertRefused(f"{self.L}: id: other is not the folder name fixture-shop")

    def test_static_scenario_has_none(self):
        self.scenario_yaml(lambda d: d.pop("domain"))
        self.load()

    def test_files(self):
        (self.scenario / self.DOMAIN / "data" / "load.sql").unlink()
        text = self.domain_problems(lambda d: d.update(producers="feeds/", notes="docs/none.md"))
        self.assertProblems(text, f"domains/fixture-shop/data/load.sql: missing file ({self.L} "
                            "load)",
                            f"domains/fixture-shop/docs/none.md: missing file ({self.L} notes)",
                            f"domains/fixture-shop/feeds/: missing folder ({self.L} producers)")

    def test_purposes_form_only(self):
        text = self.domain_problems(lambda d: d.update(purposes=["not-yet-written", "Bad_Id"]))
        self.assertNotIn("not-yet-written", text)
        self.assertIn(f"{self.L}: purposes: 'Bad_Id' is not a purpose id", text)

    def test_producer_fragments(self):
        producers = self.scenario / self.DOMAIN / "producers"
        (producers / "notes.txt").write_text("x\n")
        (producers / "scripts").mkdir()
        (producers / "builders").mkdir()
        self.edit_yaml(f"{self.DOMAIN}/producers/schedule.yaml",
                       lambda d: d.update(intensity=1.0))
        self.edit_yaml(f"{self.DOMAIN}/producers/queries.yaml",
                       lambda d: d["queries"].update({"odd": {"statement": "SELECT 1"}}))
        (producers / "jobs.yaml").write_text("jobs: []\nconnections: {}\n")
        text = self.domain_problems()
        self.assertProblems(text, "domains/fixture-shop/producers/notes.txt: not a fragment "
                            "(queries.yaml, schedule.yaml, jobs.yaml, builders/)",
                            "domains/fixture-shop/producers/scripts/: not a fragment",
                            "domains/fixture-shop/producers/schedule.yaml: intensity: not a key "
                            "of a schedule.yaml fragment (connections, streams, shapes); "
                            "intensity and timeline are the scenario's",
                            "domains/fixture-shop/producers/jobs.yaml: connections: not a key of "
                            "a jobs.yaml fragment (jobs)",
                            "domains/fixture-shop/producers/queries.yaml: queries.odd: not a query")
        self.assertNotIn("producers/builders", text)

    def test_classification(self):
        self.edit_yaml(f"{self.DOMAIN}/data/classification.yaml", lambda d: d["columns"].update(
            {"customers.email": "personal", "shop.customers.phone": "secret"}))
        text = self.domain_problems()
        self.assertProblems(text, "domains/fixture-shop/data/classification.yaml: "
                            "columns.customers.email: 'customers.email' is not "
                            "<database>.<table>.<column>",
                            "domains/fixture-shop/data/classification.yaml: "
                            "columns.shop.customers.phone: 'secret' is not a class (personal, "
                            "customer-linked, internal; master spec 11.2)")


class TestGovernanceRefusals(V04CopyTest):
    """governance: (master spec 6.1, 6.9, 11.3, 11.4; W1 item 1; D223)."""

    P = "scenario.yaml: governance.classes"

    def test_files(self):
        (self.scenario / "data" / "classification.yaml").unlink()
        self.governance(lambda g: g.update(policy="player/policy.md"))
        self.assertRefused("player/policy.md: missing file (scenario.yaml governance.policy)",
                           "data/classification.yaml: missing file (scenario.yaml "
                           "governance.classification)")

    def test_classes_closed_list(self):
        self.classes(lambda c: c.update(secret={"locations": "any"}))
        self.assertRefused(f"{self.P}.secret: secret is not a class (personal, customer-linked, "
                           "internal; master spec 11.2)")

    def test_every_class_used_has_rules(self):
        self.classes(lambda c: (c.pop("customer-linked"), c.pop("internal")))
        missing = self.assertRefused("scenario.yaml: governance.classes: no entry for class "
                                     "customer-linked, which data/classification.yaml uses "
                                     "(master spec 6.1)")
        self.assertNotIn("class internal", "\n".join(missing))

    def test_classification_file(self):
        self.edit_yaml("data/classification.yaml", lambda d: d["columns"].update(
            {"shop.orders": "internal", "shop.orders.placed_at": "public"}))
        self.assertRefused("data/classification.yaml: columns.shop.orders: 'shop.orders' is not "
                           "<database>.<table>.<column>",
                           "data/classification.yaml: columns.shop.orders.placed_at: 'public' is "
                           "not a class")

    def test_any_takes_no_readers_or_outbound(self):
        self.classes(lambda c: c["internal"].update(readers=["shop_app"], outbound=[
            {"to": "x", "outbox": "db/shop/mail_outbox", "fields": ["a"]}]))
        self.assertRefused(f"{self.P}.internal.readers: refused with locations: any",
                           f"{self.P}.internal.outbound: refused with locations: any")

    def test_readers_required_unless_any(self):
        self.classes(lambda c: c["customer-linked"].pop("readers"))
        self.assertRefused(f"{self.P}.customer-linked.readers: missing (required unless "
                           "locations is any; may be [])")

    def test_readers_may_be_empty(self):
        self.classes(lambda c: c["customer-linked"].update(readers=[]))
        self.load()

    def test_locations(self):
        cases = {"everywhere": "'everywhere' is not a non-empty list of locations "
                               "<node>/<database> or the word any",
                 ("bi/shop",): "bi/shop: bi is not a database node (its role is transformer)",
                 ("reporting/shop",): "reporting/shop: shop is not a database node reporting's "
                                      "data file (data/reporting.sql) creates"}
        for value, message in cases.items():
            with self.subTest(value=value):
                self.setUp()
                self.classes(lambda c: c["personal"].update(
                    locations=list(value) if isinstance(value, tuple) else value))
                self.assertRefused(f"{self.P}.personal.locations: {message}")
        self.setUp()
        self.classes(lambda c: c["personal"].update(locations=[]))
        self.assertRefused(f"{self.P}.personal.locations: empty")

    def test_readers(self):
        self.classes(lambda c: c["personal"].update(readers=["shop_app", "gm_check", "nobody"]))
        self.assertRefused(f"{self.P}.personal.readers: gm_check is one of the game's own "
                           "roles, never a reader",
                           f"{self.P}.personal.readers: nobody is not a role a data file of the "
                           "scenario creates (CREATE ROLE nobody)")

    def test_reader_from_another_data_file(self):
        self.classes(lambda c: c["personal"]["readers"].append("bi_etl"))
        self.load()

    def test_outbound(self):
        def change(c):
            flow = c["personal"]["outbound"][0]
            c["personal"]["outbound"] = [
                flow, dict(flow), dict(flow, to="Mail_Provider"),
                dict(flow, to="a", outbox="db/shop"), dict(flow, to="b", outbox="db/nope/t"),
                dict(flow, to="c", fields=[])]
        self.classes(change)
        self.assertRefused(f"{self.P}.personal.outbound[mail-provider].to: mail-provider "
                           "receives the class more than once",
                           f"{self.P}.personal.outbound[Mail_Provider].to: 'Mail_Provider' is "
                           "not a receiver's label",
                           f"{self.P}.personal.outbound[a].outbox: 'db/shop' is not "
                           "<node>/<database>/<table>",
                           f"{self.P}.personal.outbound[b].outbox: db/nope: nope is not a "
                           "database node db's data file",
                           "governance.classes.personal.outbound[5].fields: empty")

    def test_separation(self):
        self.classes(lambda c: c["personal"].update(separation="database"))
        self.assertRefused(f"{self.P}.personal.separation: 'database' is not instance")
        self.setUp()
        self.classes(lambda c: c["personal"].update(separation="instance"))
        self.load()

    def test_separation_refused_with_any(self):
        self.classes(lambda c: c["internal"].update(separation="instance"))
        self.assertRefused(f"{self.P}.internal.separation: refused with locations: any (the "
                           "class is not restricted)")

    def test_policy_mapped_to_the_bastion(self):
        self.scenario_yaml(lambda d: self.node(d, "bastion")["seed_files"].pop("data-policy.md"))
        self.assertRefused("scenario.yaml: nodes[bastion].seed_files.data-policy.md: missing (a "
                           "scenario with governance: maps the bastion's data-policy.md to "
                           "governance.policy player/data-policy.md; spec D223)")

    def test_policy_mapped_to_another_file(self):
        self.scenario_yaml(lambda d: self.node(d, "bastion")["seed_files"].update(
            {"data-policy.md": "player/story.md"}))
        self.assertRefused("scenario.yaml: nodes[bastion].seed_files.data-policy.md: "
                           "player/story.md, not governance.policy player/data-policy.md "
                           "(spec D223)")

    def test_no_governance_maps_no_policy(self):
        self.scenario_yaml(lambda d: d.pop("governance"))
        self.assertRefused("scenario.yaml: nodes[bastion].seed_files.data-policy.md: a scenario "
                           "without governance: hands the players no data policy, so its bastion "
                           "maps none (spec D223)")
        self.setUp()
        self.scenario_yaml(lambda d: (d.pop("governance"),
                                      self.node(d, "bastion")["seed_files"].pop("data-policy.md")))
        self.load()


class TestFaultV04Refusals(V04CopyTest):
    """v0.4's fault keys (master spec 6.3; W1 item 3)."""

    L = "faults/fixture-copy-runs/fault.yaml"

    def problems(self, change):
        self.edit_yaml(f"faults/fixture-copy-runs/fault.yaml", change)
        return "\n".join(model.check_fault_dir(self.scenario / "faults" / "fixture-copy-runs",
                                               catalog_root=self.catalog_root))

    def test_purposes(self):
        text = self.problems(lambda d: d["applies_to"].update(purposes=["nope", "Bad"]))
        self.assertProblems(text, f"{self.L}: applies_to.purposes: nope is not a purpose (no "
                            "purposes/nope/purpose.yaml in the catalog)",
                            f"{self.L}: applies_to.purposes: 'Bad' is not a purpose id")
        self.setUp()
        self.assertIn(f"{self.L}: applies_to.purposes: empty",
                      self.problems(lambda d: d["applies_to"].update(purposes=[])))

    def test_purposes_through_the_scenario(self):
        self.edit_yaml("faults/fixture-copy-runs/fault.yaml",
                       lambda d: d["applies_to"].update(purposes=["nope"]))
        self.assertRefused(f"{self.L}: applies_to.purposes: nope is not a purpose")

    def test_judges(self):
        text = self.problems(lambda d: d["sealed_check"].update(judges="outputs"))
        self.assertIn(f"{self.L}: sealed_check.judges: 'outputs' is not runs or triggers", text)
        self.setUp()
        text = self.problems(lambda d: d["sealed_check"].update(behavioural=True))
        self.assertIn(f"{self.L}: sealed_check.judges: never with behavioural: true", text)
        self.setUp()
        self.assertEqual(self.problems(lambda d: d["sealed_check"].update(judges="triggers")), "")

    def test_state_seed_changes_materials(self):
        """A state fault's seed_changes materials are checked as a seed-file
        fault's (spec D254)."""
        def state(material):
            def change(d):
                d["injection"].update(kind="state", stage="after-data-load",
                                      scripts=["checks/fixed.sh"])
                d["injection"]["seed_changes"][0]["material"] = material
            return change
        text = self.problems(state("inject/rollup.sql.snippet"))
        self.assertIn("faults/fixture-copy-runs/inject/rollup.sql.snippet: missing file", text)
        self.setUp()
        self.assertEqual(self.problems(state("checks/probe.md")), "")
        self.setUp()
        self.assertEqual(self.problems(lambda d: (d["injection"].update(
            kind="state", stage="after-data-load", scripts=["checks/fixed.sh"]),
            d["injection"].pop("seed_changes"))), "")

    def test_needs_unshared_host(self):
        text = self.problems(lambda d: d.update(needs_unshared_host="yes"))
        self.assertIn(f"{self.L}: needs_unshared_host: 'yes' is not a boolean", text)
        self.setUp()
        self.assertEqual(self.problems(lambda d: d.pop("needs_unshared_host")), "")


class TestJudgesAnswerKeyRefusals(V04CopyTest):
    """A sealed check judging runs or triggers in the answer key (master
    spec 6.2, 12; W1 item 2)."""

    KEY = "gm/answer-key.yaml"
    P = "gm/answer-key.yaml: instances[f2].sealed_check"

    def check(self, change, index=1):
        self.edit_yaml(self.KEY, lambda d: change(d["instances"][index]["sealed_check"]))

    def test_judges_and_threshold_required(self):
        self.check(lambda c: (c.pop("judges"), c.pop("threshold")))
        self.assertRefused(f"{self.P}.judges: missing (fault fixture-copy-runs's sealed check "
                           "judges runs)",
                           f"{self.P}.threshold: missing (fault fixture-copy-runs's sealed check "
                           "judges runs: the violations tolerated)")

    def test_judges_equal_to_the_fault(self):
        self.check(lambda c: c.update(judges="triggers"))
        self.assertRefused(f"{self.P}.judges: triggers, but fault fixture-copy-runs's sealed "
                           "check judges runs")

    def test_threshold_a_non_negative_integer(self):
        for value in (-1, 1.5, "0"):
            with self.subTest(threshold=value):
                self.setUp()
                self.check(lambda c: c.update(threshold=value))
                self.assertRefused(f"{self.P}.threshold: {value!r} is not a non-negative integer")
        self.setUp()
        self.check(lambda c: c.update(threshold=3))
        self.load()

    def test_no_window(self):
        self.check(lambda c: c.update(window="30m"))
        self.assertRefused(f"{self.P}.window: fault fixture-copy-runs's sealed check judges runs, "
                           "which takes no window (master spec 6.2)")

    def test_judges_only_for_a_judging_fault(self):
        self.check(lambda c: c.update(judges="runs", threshold=0), index=0)
        self.assertRefused("gm/answer-key.yaml: instances[f1].sealed_check.judges: fault "
                           "fixture-random-page-cost's sealed check judges no runs or triggers",
                           "gm/answer-key.yaml: instances[f1].sealed_check.threshold: fault "
                           "fixture-random-page-cost's sealed check is not behavioural")


class TestSeedOptionalRefusals(V04CopyTest):
    """brick.yaml seed.optional (master spec 6.4; W1 item 4)."""

    LABEL = "bricks/postgres/brick.yaml"

    def test_optional_entries(self):
        text = self.brick_problems_v04(lambda d: d["seed"].update(
            optional=["crontab", "pgbouncer.ini", "builders/"]))
        self.assertIn(f"{self.LABEL}: seed.optional: pgbouncer.ini is not a seed file of the "
                      "brick (seed.files)", text)
        self.assertIn(f"{self.LABEL}: seed.optional: builders/ is a directory entry, optional "
                      "already", text)

    def brick_problems_v04(self, change):
        self.edit_yaml(f"{self.LABEL}", change)
        return "\n".join(model.check_brick_dir(self.scenario / "bricks" / "postgres"))

    def test_optional_file_left_out_and_required_ones_kept(self):
        self.load()                          # db and reporting seed no crontab
        self.scenario_yaml(lambda d: self.node(d, "db")["seed_files"].pop("pg_hba.conf"))
        self.assertRefused("scenario.yaml: nodes[db].seed_files: no entry for the brick's seed "
                           "file pg_hba.conf")

    def test_without_optional_every_file_is_required(self):
        self.edit_yaml(self.LABEL, lambda d: d["seed"].pop("optional"))
        missing = self.assertRefused("scenario.yaml: nodes[db].seed_files: no entry for the "
                                     "brick's seed file crontab")
        self.assertNotIn("nodes[reporting].seed_files: no entry", "\n".join(missing))


class V04SchedulerTest(V04CopyTest):
    """The runner bi's files: a transformer script (master spec 7.1; W1 item
    7)."""

    Q = "nodes/bi/queries.yaml"
    S = "nodes/bi/schedule.yaml"
    J = "nodes/bi/jobs.yaml"

    def queries(self, change):
        self.edit_yaml(self.Q, lambda d: change(d["queries"]))

    def jobs(self, change):
        self.edit_yaml(self.J, lambda d: change(d["jobs"]))


class TestScriptRefusals(V04SchedulerTest):

    def test_script_entry_accepted(self):
        sc = self.load()
        self.assertIn("scripts/", sc.node("bi")["seed_files"])

    def test_script_reference(self):
        cases = {
            "rollup.py:hourly": "queries.sales.rollup.script: 'rollup.py:hourly' is not "
                                "scripts/<file>:<function>",
            "scripts/none.py:hourly": "queries.sales.rollup.script: scripts/none.py:hourly: "
                                      "nodes/bi/scripts/none.py does not exist",
            "scripts/rollup.py:daily": "queries.sales.rollup.script: scripts/rollup.py:daily: "
                                       "nodes/bi/scripts/rollup.py defines no function daily at "
                                       "its top level",
        }
        for ref, message in cases.items():
            with self.subTest(ref=ref):
                self.setUp()
                self.queries(lambda q: q["sales.rollup"].update(script=ref))
                self.assertRefused(f"{self.Q}: {message}")

    def test_script_keys_and_options(self):
        self.queries(lambda q: q["sales.rollup"].update(options=[1], sql="SELECT 1"))
        self.assertRefused(f"{self.Q}: queries.sales.rollup.sql: not a key of a script (script, "
                           "options)",
                           f"{self.Q}: queries.sales.rollup.options: not a map")

    def test_script_needs_the_scripts_folder(self):
        self.scenario_yaml(lambda d: self.node(d, "bi")["seed_files"].pop("scripts/"))
        self.assertRefused(f"{self.Q}: queries.sales.rollup.script: scripts/rollup.py:hourly, "
                           "but the node has no scripts/ seed folder")

    def test_script_file_parses(self):
        (self.scenario / "nodes" / "bi" / "scripts" / "rollup.py").write_text("def hourly(:\n")
        self.assertRefused("nodes/bi/scripts/rollup.py: cannot be parsed as Python")

    def test_no_stream_names_a_script_key(self):
        self.edit_yaml(self.S, lambda d: d.update(streams=[
            {"key": "sales.rollup", "connection": "source", "rate": "1/min"}]))
        self.assertRefused(f"{self.S}: streams[sales.rollup].key: sales.rollup is a script key, "
                           "which runs only as a job (jobs.yaml; master spec 7.1)")

    def test_no_timeline_change_names_a_script_key(self):
        self.edit_yaml(self.S, lambda d: d.update(
            streams=[{"key": "sales.copy", "connection": "target", "rate": "1/min"}],
            timeline=[{"at": "handover-2h", "stream": "sales.copy",
                       "set": {"key": "sales.rollup"}}]))
        self.assertRefused(f"{self.S}: timeline[0].set.key: sales.rollup is a script key, which "
                           "runs only as a job")

    def test_script_job_names_connections(self):
        self.jobs(lambda j: j[1].update(connection="target"))
        self.assertRefused(f"{self.J}: jobs[rollup-daytime].connection: sales.rollup is a script "
                           "key, whose job names connections: instead (master spec 7.1)")
        self.setUp()
        self.jobs(lambda j: j[1].pop("connections"))
        self.assertRefused(f"{self.J}: jobs[rollup-daytime].connections: missing (the job of "
                           "script key sales.rollup names each of the script's connections")

    def test_other_job_names_one_connection(self):
        self.jobs(lambda j: j[0].update(connections={"target": "target"}))
        self.assertRefused(f"{self.J}: jobs[copy-hourly].connections: only a script key's job "
                           "names connections: (sales.copy is not a script key)")
        self.setUp()
        self.jobs(lambda j: j[0].pop("connection"))
        self.assertRefused(f"{self.J}: jobs[copy-hourly].connection: missing (every job but a "
                           "script key's names one connection of the schedule)")

    def test_unknown_key_takes_exactly_one(self):
        self.jobs(lambda j: (j[0].pop("connection"), j[0].update(key="sales.none")))
        self.assertRefused(f"{self.J}: jobs[copy-hourly]: exactly one of connection: and "
                           "connections:")

    def test_connections_names_and_values(self):
        self.jobs(lambda j: j[1].update(connections={"Source": "source", "target": "warehouse"}))
        self.assertRefused(f"{self.J}: jobs[rollup-daytime].connections.Source: 'Source' is not a "
                           "script's connection name ([a-z][a-z0-9_]*)",
                           f"{self.J}: jobs[rollup-daytime].connections.target: warehouse is not "
                           "a connection of the node's schedule.yaml")
        self.setUp()
        self.jobs(lambda j: j[1].update(connections={}))
        self.assertRefused(f"{self.J}: jobs[rollup-daytime].connections: empty")

    def test_v03_producer_jobs_still_load(self):
        model.load_scenario(FIXTURE_V03)


class TestCrontabRefusals(V04CopyTest):
    """postgres 0.4.0's optional crontab and crontab_roles (master spec 6.1,
    7.2; W1 items 0, 1 and 8)."""

    C = "nodes/reporting/crontab"
    P = "scenario.yaml: nodes[reporting].crontab_roles"

    def roles(self, value):
        self.scenario_yaml(lambda d: self.node(d, "reporting").update(crontab_roles=value))

    def crontab(self, *lines):
        (self.scenario / self.C).write_text("PGPASSFILE=/run/gm-cron/pgpass\n"
                                            + "".join(line + "\n" for line in lines))

    def test_roles_required_with_a_crontab(self):
        self.scenario_yaml(lambda d: self.node(d, "reporting").pop("crontab_roles"))
        self.assertRefused(f"{self.P}: missing (the node seeds a crontab")

    def test_roles_refused_without_a_crontab(self):
        self.scenario_yaml(lambda d: self.node(d, "db").update(crontab_roles=[]))
        self.assertRefused("scenario.yaml: nodes[db].crontab_roles: the node seeds no crontab (no "
                           "crontab in its seed_files), so it names no crontab role")

    def test_roles_may_be_empty(self):
        self.roles([])
        self.load()

    def test_roles(self):
        self.roles(["bi_etl", "bi_etl", "Bad-Role", "postgres", "shop_app"])
        self.assertRefused(f"{self.P}: bi_etl listed more than once",
                           f"{self.P}: 'Bad-Role' is not a role name",
                           f"{self.P}: postgres is reserved",
                           f"{self.P}: shop_app is not a role node reporting's own data file "
                           "creates (its data file (data/reporting.sql); CREATE ROLE shop_app)")

    def test_entries_in_the_cron_subset(self):
        self.crontab("# a comment", "", "@reboot psql -c 'SELECT 1'", "0 25 * * * psql",
                     "0 1 1 * * psql", "*/5 * * *")
        self.assertRefused(f"{self.C}: line 4: @reboot: no @ form in a crontab",
                           f"{self.C}: line 5: '0 25 * * *': hour 25 is not *",
                           f"{self.C}: line 6: '0 1 1 * *': day of month and month are *",
                           f"{self.C}: line 7: not a crontab entry (five time fields, then the "
                           "command)")

    def test_widened_entries_accepted(self):
        self.crontab("*/15 8-20 * * * psql -c 'SELECT 1'", "0 3 * * 0 psql -c 'SELECT 2'",
                     "SHELL=/bin/sh")
        self.load()

    def test_crontab_fault_on_a_node_seeding_one(self):
        self.edit_yaml("faults/fixture-random-page-cost/fault.yaml", lambda d: d["injection"][
            "seed_changes"][0].update(file="crontab"))
        self.assertRefused("scenario.yaml: fault_instances[f1]: fault fixture-random-page-cost "
                           "changes crontab, which node db does not seed (an optional seed file "
                           "of brick postgres")
        self.setUp()
        self.edit_yaml("faults/fixture-random-page-cost/fault.yaml", lambda d: d["injection"][
            "seed_changes"][0].update(file="crontab"))
        self.scenario_yaml(lambda d: d["fault_instances"][0].update(node="reporting"))
        self.load()


class TestDataSeedChange(V04CopyTest):
    """A seed change naming `data`, the target node's data.file (master spec
    6.3, spec D226)."""

    def data_change(self):
        self.edit_yaml("faults/fixture-random-page-cost/fault.yaml", lambda d: d["injection"][
            "seed_changes"][0].update(file="data"))

    def test_data_on_a_node_with_a_data_file(self):
        self.data_change()
        self.load()
        self.setUp()
        self.data_change()
        self.scenario_yaml(lambda d: d["fault_instances"][0].update(node="reporting"))
        self.load()

    def test_data_refused_on_a_node_without_one(self):
        self.data_change()
        self.scenario_yaml(lambda d: self.node(d, "db").pop("data"))
        missing = self.assertRefused(
            "scenario.yaml: fault_instances[f1]: fault fixture-random-page-cost changes data, "
            "the node's data file, but node db has none (no data.file; v0.4 master spec 6.3, "
            "spec D226)")
        self.assertFalse([m for m in missing if "not a seed file of brick" in m], missing)

    def test_data_is_no_seed_file_name(self):
        self.edit_yaml("faults/fixture-random-page-cost/fault.yaml", lambda d: d["injection"][
            "seed_changes"][0].update(file="data.sql"))
        self.assertRefused("scenario.yaml: fault_instances[f1]: fault fixture-random-page-cost "
                           "changes data.sql, not a seed file of brick postgres")


class TestPgCronRefusals(V04CopyTest):
    """A data file creating pg_cron (master spec 7.2; W1 item 0)."""

    CONF = "nodes/reporting/postgresql.conf"

    def conf(self, old, new):
        path = self.scenario / self.CONF
        text = path.read_text()
        self.assertIn(old, text)
        path.write_text(text.replace(old, new))

    def test_preload_required(self):
        self.conf("shared_preload_libraries = 'pg_cron'",
                  "shared_preload_libraries = 'pg_stat_statements'")
        self.assertRefused("data/reporting.sql: creates the extension pg_cron, but node "
                           "reporting's seed postgresql.conf (nodes/reporting/postgresql.conf) "
                           "does not preload it (shared_preload_libraries; master spec 7.2)")

    def test_last_assignment_counts(self):
        self.conf("cron.timezone", "shared_preload_libraries = ''\ncron.timezone")
        self.assertRefused("does not preload it")
        self.setUp()
        self.conf("shared_preload_libraries = 'pg_cron'",
                  "#shared_preload_libraries = 'pg_cron'\n"
                  "shared_preload_libraries = 'pg_stat_statements, pg_cron'")
        self.load()

    def test_database_name(self):
        self.conf("cron.database_name = 'reporting'", "cron.database_name = 'shop'")
        self.assertRefused(f"{self.CONF}: cron.database_name: shop is not a database node "
                           "reporting's data file (data/reporting.sql) creates (master spec 7.2)")
        self.setUp()
        self.conf("cron.database_name = 'reporting'", "")
        self.assertRefused(f"{self.CONF}: cron.database_name: missing (node reporting's data "
                           "file creates pg_cron")

    def test_preload_without_the_extension_loads(self):
        path = self.scenario / "data" / "reporting.sql"
        path.write_text(path.read_text().replace("CREATE EXTENSION pg_cron;", "-- no pg_cron"))
        self.load()


class TestPurposeCadence(V04CopyTest):
    """A purpose job's cadence in W1 item 0's subset (spec D219)."""

    def test_widened_cadence_accepted(self):
        self.assertEqual(self.purpose_problems(), "")
        self.assertIn("*/15 8-20", (self.scenario / self.PURPOSE / "purpose.yaml").read_text())

    def test_cadence_outside_the_subset(self):
        text = self.purpose_problems(lambda d: d["jobs"][1].update(cadence="*/15 20-8 * * *"))
        self.assertIn("purposes/fixture-sales-copy/purpose.yaml: jobs[rollup-daytime].cadence: "
                      "'*/15 20-8 * * *': hour 20-8 is not *", text)


# --- v0.4 chunk 13: the campaign topology (capture W3-b) ----------------------

FIXTURE_CAMPAIGN = FIXTURES / "fixture-campaign"


class TestCampaignFixture(ScenarioCopyTest):
    """fixture-campaign (build plan chunk 13, capture W3-b of
    specs/versions/v0.4/wave-log.md): master spec 16.1's topology with the
    four purposes, the shop domain, governance, two instances each seeding
    a crontab (reporting preloading pg_cron, nothing scheduled) and one
    harmless instance f0. It loads against the repository's catalog, its
    scheduler files are the purposes' and the domain's fragments unchanged,
    and it fits and renders on the fake engine on armenelos alone and on
    armenelos and the VPS declared shared, reporting on the manager."""

    NODES = ["bastion", "db", "pooler", "producer", "consumer", "reporting", "bi", "crm",
             "gateway", "prometheus", "exporter", "grafana"]
    VPS = "vps-5718ad52"

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / "fixture-campaign"
        shutil.copytree(FIXTURE_CAMPAIGN, self.scenario)

    def test_fixture_loads(self):
        sc = model.load_scenario(FIXTURE_CAMPAIGN)
        self.assertEqual(sc.id, "fixture-campaign")
        self.assertEqual([n["name"] for n in sc.nodes], self.NODES)
        self.assertEqual({n: (b.id, b.version) for n, b in sc.bricks.items()}, {
            "bastion": ("bastion", "0.4.0"), "db": ("postgres", "0.4.0"),
            "pooler": ("pgbouncer", "0.1.1"), "producer": ("scheduler", "0.2.0"),
            "consumer": ("scheduler", "0.2.0"), "reporting": ("postgres", "0.4.0"),
            "bi": ("scheduler", "0.2.0"), "crm": ("scheduler", "0.2.0"),
            "gateway": ("scheduler", "0.2.0"), "prometheus": ("prometheus", "0.2.0"),
            "exporter": ("postgres-exporter", "0.2.0"), "grafana": ("grafana", "0.2.0")})
        self.assertTrue(all(b.source == "catalog" for b in sc.bricks.values()))
        self.assertEqual({n["name"]: n["role"] for n in sc.nodes
                          if n["brick"]["id"] == "scheduler"},
                         {"producer": "producer", "consumer": "consumer", "bi": "transformer",
                          "crm": "transformer", "gateway": "producer"})
        self.assertEqual(sc.data["domain"], "shop")
        self.assertEqual([p["id"] for p in sc.data["purposes"]],
                         ["shop-sales-reporting", "shop-winback-leads", "shop-customer-mailing",
                          "shop-export-declarations"])
        self.assertEqual(sc.data["purposes"][0]["parts"],
                         {"source": "db/shop", "target": "reporting/reporting", "runner": "bi",
                          "consumer": "consumer"})
        self.assertEqual(sc.data["purposes"][3]["parts"]["receiver"], "gateway")
        self.assertEqual(sc.data["governance"]["classes"]["personal"]["locations"], ["db/shop"])
        self.assertEqual(sc.data["aging"], {"minimum": "8h", "handover_at": "14:00"})
        self.assertEqual(sc.node("db")["crontab_roles"], ["shop_refresh"])
        self.assertEqual(sc.node("reporting")["crontab_roles"], ["bi_etl"])
        self.assertEqual(sc.node("reporting")["resources"]["limits"]["memory"], "640M")
        self.assertEqual(sc.node("reporting")["resources"]["reservations"]["memory"], "256M")
        self.assertEqual(sc.node("bastion")["seed_files"]["data-policy.md"],
                         "player/data-policy.md")
        self.assertEqual([(i["id"], i["fault"]["id"], i["node"])
                          for i in sc.data["fault_instances"]],
                         [("f0", "fixture-random-page-cost", "db")])
        placement = sc.data["designed_for"]["placement"]
        self.assertEqual(sorted(n for n, h in placement.items() if h == "host-2"),
                         ["bi", "gateway"])
        self.assertEqual(placement["reporting"], "host-1")

    def test_scheduler_files_are_the_fragments_unchanged(self):
        def load(path):
            return yaml.safe_load(path.read_text())
        nodes = FIXTURE_CAMPAIGN / "nodes"
        domain = REPO_ROOT / "domains" / "shop" / "producers"
        purposes = REPO_ROOT / "purposes"
        p1 = purposes / "shop-sales-reporting" / "material"
        p5 = purposes / "shop-export-declarations" / "material"
        for node, source in [("producer", domain), ("consumer", p1 / "consumer"),
                             ("bi", p1 / "runner"), ("gateway", p5 / "receiver")]:
            with self.subTest(node=node):
                self.assertEqual(load(nodes / node / "schedule.yaml"),
                                 {"intensity": 1.0, **load(source / "schedule.yaml")})
                self.assertEqual(load(nodes / node / "queries.yaml"),
                                 load(source / "queries.yaml"))
                if (source / "jobs.yaml").exists():
                    self.assertEqual(load(nodes / node / "jobs.yaml"), load(source / "jobs.yaml"))
                else:
                    self.assertEqual(load(nodes / node / "jobs.yaml"), {"jobs": []})
        crm = [purposes / p / "material" / "runner" for p in
               ("shop-winback-leads", "shop-customer-mailing", "shop-export-declarations")]
        queries, jobs, connections = {}, [], {}
        for runner in crm:
            queries.update(load(runner / "queries.yaml")["queries"])
            jobs += load(runner / "jobs.yaml")["jobs"]
            connections.update(load(runner / "schedule.yaml")["connections"])
        self.assertEqual(load(nodes / "crm" / "queries.yaml"), {"queries": queries})
        self.assertEqual(load(nodes / "crm" / "jobs.yaml"), {"jobs": jobs})
        self.assertEqual(load(nodes / "crm" / "schedule.yaml"),
                         {"intensity": 1.0, "connections": connections, "streams": []})
        self.assertEqual((nodes / "bi" / "scripts" / "rollup.py").read_bytes(),
                         (p1 / "runner" / "scripts" / "rollup.py").read_bytes())

    def test_data_files_are_the_domains_and_the_purposes(self):
        data = FIXTURE_CAMPAIGN / "data"
        shop = REPO_ROOT / "domains" / "shop" / "data"
        self.assertEqual((data / "db.sql").read_text(),
                         (shop / "schema.sql").read_text() + (shop / "load.sql").read_text())
        self.assertEqual((data / "classification.yaml").read_bytes(),
                         (shop / "classification.yaml").read_bytes())
        target = (REPO_ROOT / "purposes" / "shop-sales-reporting" / "material" / "target"
                  / "data.sql").read_text()
        reporting = (data / "reporting.sql").read_text()
        self.assertTrue(reporting.startswith(target))
        self.assertIn("\n\\connect reporting\nCREATE EXTENSION pg_cron;\n", reporting[len(target):])
        self.assertNotIn("cron.schedule", reporting)

    def test_database_seeds(self):
        nodes = FIXTURE_CAMPAIGN / "nodes"
        for node in ("db", "reporting"):
            with self.subTest(node=node):
                hba = (nodes / node / "pg_hba.conf").read_text()
                self.assertIn("host    all         gm_check    samenet     scram-sha-256", hba)
                self.assertIn("host    all         all         0.0.0.0/0   scram-sha-256", hba)
        self.assertEqual([l for l in (nodes / "db" / "crontab").read_text().splitlines()
                          if not l.startswith("#")],
                         ["PGPASSFILE=/run/gm-cron/pgpass",
                          '17 * * * * psql -X -w -h /run/postgresql -U shop_refresh -d shop -c '
                          '"REFRESH MATERIALIZED VIEW popular_products" >> '
                          '/var/log/postgresql/cron/popular-products.log 2>&1'])
        self.assertEqual([l for l in (nodes / "reporting" / "crontab").read_text().splitlines()
                          if not l.startswith("#")], ["PGPASSFILE=/run/gm-cron/pgpass"])
        conf = (nodes / "reporting" / "postgresql.conf").read_text()
        self.assertIn("shared_preload_libraries = 'pg_stat_statements,pg_cron'\n", conf)
        self.assertIn("cron.timezone = '{{customer_timezone}}'\n", conf)

    def handover(self):
        tomorrow = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)
        return tomorrow.strftime("%Y-%m-%dT09:00Z")

    def test_fits_and_renders_on_armenelos_alone(self):
        result = fit.fit(self.scenario, "armenelos", cpu="12", memory="4.7G", disk="10G")
        self.assertTrue(result.ok, result.text())
        rendered = render.render(self.scenario, "armenelos", handover=self.handover())
        self.assertIn("shift +5", rendered.text())
        out = self.scenario / "local" / "armenelos" / "rendered"
        files = sorted(str(p.relative_to(out)) for p in out.rglob("*") if p.is_file())
        for name in ("db/crontab", "reporting/crontab", "reporting/postgresql.conf",
                     "bi/jobs.yaml", "crm/jobs.yaml", "gateway/schedule.yaml",
                     "bastion/README.md"):
            self.assertIn(name, files)
        self.assertIn("cron.timezone = 'Etc/GMT-5'",
                      (out / "reporting" / "postgresql.conf").read_text())
        self.assertIn("\n17 * * * * psql", (out / "db" / "crontab").read_text())

    def test_fits_and_renders_on_armenelos_and_the_vps_declared_shared(self):
        from tools.tests.test_render import MANAGER, two_host_engine
        hosts = [f"{MANAGER},manager,cpu=12,memory=4.7G,disk=10G",
                 f"{self.VPS},shared,endpoint=ssh://dbagm-vps,cpu=2,memory=1G,disk=8G"]
        result = fit.fit(self.scenario, "duo", hosts=hosts,
                         mapping=[f"host-1={MANAGER}", f"host-2={self.VPS}"],
                         docker=two_host_engine())
        self.assertTrue(result.ok, result.text())
        impl = localimpl.read_implementation(self.scenario / "local" / "duo")
        placed = {n: node["host"] for n, node in impl["nodes"].items()}
        self.assertEqual(sorted(n for n, h in placed.items() if h == self.VPS), ["bi", "gateway"])
        self.assertEqual(placed["reporting"], MANAGER)
        render.render(self.scenario, "duo", handover=self.handover())
        stack = (self.scenario / "local" / "duo" / "stack.yml").read_text()
        self.assertIn(f"node.hostname == {self.VPS}", stack)


if __name__ == "__main__":
    unittest.main()
