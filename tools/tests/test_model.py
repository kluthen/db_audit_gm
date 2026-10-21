"""Scenario loading and completeness (tools/gm/model.py)."""

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import model
from tools.tests import REPO_ROOT, FIXTURES, FIXTURE_SCENARIO, ScenarioCopyTest

FIXTURE_MOUNTED = FIXTURES / "fixture-mounted"


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

    def assertRefused(self, *fragments):
        with self.assertRaises(model.IncompleteScenario) as cm:
            model.load_scenario(self.scenario)
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
                       lambda d: self.node(d, "db")["brick"].update(version="0.3.0"))
        self.assertRefused("nodes[db].brick", "0.3.0", "0.2.0")

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

    def test_front_port_when_routes(self):
        self.edit_yaml("scenario.yaml", lambda d: self.node(d, "bastion")
                       .update(published_ports=[{"port": 22, "default": 2222},
                                                {"port": 8080, "default": 8081}]))
        self.assertRefused("nodes[bastion].published_ports: no {port: 8080, default: 8080}, "
                           "which the web front needs (web_routes is non-empty)")

    def test_no_front_port_without_routes(self):
        self.brick("fixture-monitor", lambda d: d["interfaces"]["provides"][0].pop("web_path"))
        self.web_routes({})
        missing = self.assertRefused("nodes[bastion].published_ports: port 8080 is published, "
                                     "but web_routes is empty (the web front does not run)")
        self.assertEqual(len(missing), 1, missing)

    def test_empty_routes_by_default(self):
        self.brick("fixture-monitor", lambda d: d["interfaces"]["provides"][0].pop("web_path"))
        def change(d):
            self.node(d, "bastion")["parameters"].pop("web_routes")
            self.node(d, "bastion")["published_ports"] = [{"port": 22, "default": 2222}]
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


if __name__ == "__main__":
    unittest.main()
