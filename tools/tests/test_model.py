"""Scenario loading and completeness (tools/gm/model.py)."""

import shutil
import unittest

import yaml

from tools.gm import model
from tools.tests import REPO_ROOT, FIXTURE_SCENARIO, ScenarioCopyTest


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


class TestRefusals(ScenarioCopyTest):

    def assertRefused(self, *fragments):
        with self.assertRaises(model.IncompleteScenario) as cm:
            model.load_scenario(self.scenario)
        text = "\n".join(cm.exception.missing)
        for fragment in fragments:
            self.assertIn(fragment, text)
        return cm.exception.missing

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
                       lambda d: self.node(d, "db")["brick"].update(version="0.2.0"))
        self.assertRefused("nodes[db].brick", "0.2.0", "0.1.1")

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
