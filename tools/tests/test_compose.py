"""gmctl compose and the composition record (tools/gm/compose.py,
model.check_composition; v0.5 master spec 8.4, 8.5, 15; W1 item 7)."""

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import build_parser, compose, model
from tools.tests import FIXTURES

FIXTURE_COMPOSE = FIXTURES / "fixture-compose"


class ComposeCopyTest(unittest.TestCase):
    """Each test works on a fresh copy of the compose fixture."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="gmctl-compose-")
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name) / "fixture-compose"
        shutil.copytree(FIXTURE_COMPOSE, self.root)
        self.scenario = self.root / "scenario"
        self.catalog = self.root / "catalog"

    def edit(self, relpath, change):
        path = self.root / relpath
        data = yaml.safe_load(path.read_text())
        change(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def write(self, relpath, text):
        path = self.root / relpath
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def compose(self, check=False):
        return compose.compose(self.scenario, self.catalog, check=check)

    def refused(self):
        with self.assertRaises(compose.ComposeRefused) as cm:
            self.compose()
        return str(cm.exception)

    def output(self, node, fname):
        return model.strict_load((self.scenario / "nodes" / node / fname).read_text())

    def composition_problems(self):
        data = yaml.safe_load((self.scenario / "scenario.yaml").read_text())
        return "\n".join(model.check_composition(data, self.scenario, self.catalog))


class TestFixture(ComposeCopyTest):

    def test_catalog_domains_are_complete(self):
        for did in ("fx-core", "fx-part"):
            with self.subTest(domain=did):
                self.assertEqual(model.check_domain_dir(self.catalog / "domains" / did), [])

    def test_composition_is_clean(self):
        self.assertEqual(self.composition_problems(), "")


class TestMerge(ComposeCopyTest):

    def test_two_layers_and_an_override(self):
        result = self.compose()
        self.assertEqual(result.overrides, [
            "desk schedule.yaml streams.owners.lookup: fx-core@big "
            "(domains/fx-core/variants/big/producers/desk/schedule.yaml) over fx-core@big "
            "(domains/fx-core/producers/desk/schedule.yaml)"])
        self.assertIn("  override: desk schedule.yaml streams.owners.lookup", result.text())
        schedule = self.output("desk", "schedule.yaml")
        self.assertEqual(schedule["intensity"], 1.0)
        self.assertEqual(list(schedule["connections"]), ["app", "part"])
        self.assertEqual([(s["key"], s["rate"]) for s in schedule["streams"]],
                         [("owners.lookup", "20/min"), ("part.boxes.read", "5/min")])
        self.assertEqual(schedule["timeline"][0]["set"], {"rate": "40/min"})
        self.assertEqual(list(self.output("desk", "queries.yaml")["queries"]),
                         ["owners.lookup", "owners.new", "part.boxes.read"])
        self.assertEqual(self.output("desk", "jobs.yaml")["jobs"][0]["name"], "close-day")
        text = (self.scenario / "nodes" / "desk" / "schedule.yaml").read_text()
        self.assertIn("  # from fx-core@big: domains/fx-core/variants/big/producers/desk/"
                      "schedule.yaml, over fx-core@big: domains/fx-core/producers/desk/"
                      "schedule.yaml\n  - key: owners.lookup\n", text)
        self.assertIn("# from scenario: compose/desk/schedule.yaml\nintensity: 1.0\n", text)
        builder = (self.scenario / "nodes" / "desk" / "builders" / "ids.py").read_text()
        self.assertTrue(builder.startswith(
            "# from fx-core@big: domains/fx-core/producers/desk/builders/ids.py\n"))

    def test_rerun_reproduces_and_check_finds_a_difference(self):
        self.compose()
        self.assertEqual(self.compose(check=True).differing, [])
        path = self.scenario / "nodes" / "desk" / "queries.yaml"
        path.write_text(path.read_text() + "# edited by hand\n")
        result = self.compose(check=True)
        self.assertEqual(result.differing, ["nodes/desk/queries.yaml"])
        self.assertTrue(path.read_text().endswith("# edited by hand\n"))   # nothing written
        self.assertIn("  differs: nodes/desk/queries.yaml", result.text())

    def test_identical_entries_merge_silently(self):
        shutil.copy(self.catalog / "domains" / "fx-core" / "producers" / "desk" / "jobs.yaml",
                    self.catalog / "domains" / "fx-part" / "producers" / "desk" / "jobs.yaml")
        self.edit("catalog/domains/fx-part/producers/desk/schedule.yaml", lambda d: d[
            "connections"].update(app=yaml.safe_load(
                (self.catalog / "domains/fx-core/producers/desk/schedule.yaml").read_text())[
                    "connections"]["app"]))
        result = self.compose()
        self.assertEqual(len(result.overrides), 1)
        self.assertEqual(len(self.output("desk", "jobs.yaml")["jobs"]), 1)

    def test_api_nodes(self):
        self.compose()
        api = self.output("core-api", "api.yaml")
        self.assertEqual(api["endpoints"], {"lookup": {"hosts": ["core-api"],
                                                       "credentials": ["desk_lookup"]}})
        self.assertEqual(list(api["connections"]), ["clinic"])
        nodes = self.scenario / "nodes"
        self.assertTrue((nodes / "core-api" / "routes" / "lookup.py").read_text().endswith(
            "router = APIRouter()\n"))
        self.assertTrue((nodes / "core-api" / "db" / "lookup.py").is_file())
        # the partner's endpoints onto the partners' api node, its back end onto the shared one
        self.assertEqual(list(self.output("partners-api", "api.yaml")["endpoints"]),
                         ["practices_referrals"])
        self.assertTrue((nodes / "partners-api" / "routes" / "practices_referrals.py").is_file())
        backend = self.output("partners-backend", "schedule.yaml")
        self.assertEqual(backend["streams"][0]["key"], "practices.referral")
        self.assertEqual(self.output("partners-backend", "jobs.yaml"), {"jobs": []})

    def test_bricks_in_the_mapping_form(self):
        # the form the loader reads (fixture-partners): the same nodes found
        shorthand = self.compose()
        nodes = sorted(p.name for p in (self.scenario / "nodes").iterdir())

        def mapping(data):
            for node in data["nodes"]:
                brick, _, version = node["brick"].partition("@")
                node["brick"] = {"id": brick, "version": version}
        self.edit("scenario/scenario.yaml", mapping)
        shutil.rmtree(self.scenario / "nodes")
        result = self.compose()
        self.assertEqual(sorted(p.name for p in (self.scenario / "nodes").iterdir()), nodes)
        self.assertEqual(result.overrides, shorthand.overrides)
        for node in ("desk", "partners-backend"):
            self.assertIn("streams", self.output(node, "schedule.yaml"))
        for node in ("core-api", "partners-api"):
            self.assertIn("endpoints", self.output(node, "api.yaml"))
        self.assertEqual(compose._target_nodes({"nodes": [
            {"name": "a", "brick": {"id": "api", "version": "0.1.0"}},
            {"name": "s", "brick": {"id": model.SCHEDULER_BRICK, "version": "0.3.0"}},
            {"name": "p", "brick": {"id": "postgres", "version": "0.5.0"}},
            {"name": "x", "brick": {"version": "0.1.0"}}, {"name": "y"}]}),
            {"a": "api", "s": "scheduler"})

    def test_api_entries_override(self):
        self.write("scenario/compose/core-api/api.yaml",
                   "endpoints:\n  lookup: {hosts: [core-api]}\n")
        result = self.compose()
        self.assertIn("core-api api.yaml endpoints.lookup: scenario (compose/core-api/api.yaml) "
                      "over fx-core@big (domains/fx-core/producers/api/core-api/api.yaml)",
                      result.overrides)
        self.assertEqual(self.output("core-api", "api.yaml")["endpoints"]["lookup"],
                         {"hosts": ["core-api"]})


class TestConflicts(ComposeCopyTest):

    def collide(self):
        self.edit("catalog/domains/fx-part/producers/desk/schedule.yaml", lambda d: d[
            "connections"].update(app={"driver": "sql/postgresql", "target": "records:5432/clinic",
                                       "role": "part_app", "pool": {"size": 9}}))

    def test_a_conflict_stops_the_merge(self):
        self.collide()
        text = self.refused()
        self.assertIn("conflict: desk schedule.yaml connections.app: fx-core@big: "
                      "domains/fx-core/producers/desk/schedule.yaml and fx-part@big: "
                      "domains/fx-part/producers/desk/schedule.yaml differ", text)
        self.assertIn("resolve each conflict in merge.yaml", text)
        self.assertFalse((self.scenario / "nodes").exists())

    def test_merge_yaml_takes_a_source(self):
        self.collide()
        self.write("scenario/merge.yaml",
                   "resolutions:\n  - node: desk\n    file: schedule.yaml\n"
                   "    entry: connections.app\n    take: fx-part@big\n"
                   "    reason: the part's pool serves both\n")
        result = self.compose()
        self.assertEqual(self.output("desk", "schedule.yaml")["connections"]["app"]["pool"],
                         {"size": 9})
        self.assertEqual(result.resolutions, ["desk schedule.yaml connections.app: fx-part@big "
                                              "(the part's pool serves both)"])
        self.assertIn("# from fx-part@big: domains/fx-part/producers/desk/schedule.yaml, over "
                      "fx-core@big: domains/fx-core/producers/desk/schedule.yaml (taken by "
                      "merge.yaml)", (self.scenario / "nodes/desk/schedule.yaml").read_text())

    def test_merge_yaml_writes_a_value(self):
        self.collide()
        self.write("scenario/merge.yaml",
                   "resolutions:\n  - node: desk\n    file: schedule.yaml\n"
                   "    entry: connections.app\n"
                   "    value: {driver: sql/postgresql, target: records:5432/clinic, "
                   "role: core_app, pool: {size: 6}}\n    reason: one pool of six\n")
        self.compose()
        self.assertEqual(self.output("desk", "schedule.yaml")["connections"]["app"]["pool"],
                         {"size": 6})

    def test_stale_and_malformed_merge_yaml(self):
        self.write("scenario/merge.yaml",
                   "resolutions:\n  - node: desk\n    file: schedule.yaml\n"
                   "    entry: connections.app\n    take: fx-core@big\n    reason: x\n")
        self.assertIn("merge.yaml: the resolution of desk schedule.yaml connections.app meets "
                      "no conflict (stale)", self.refused())
        self.write("scenario/merge.yaml",
                   "resolutions:\n  - node: desk\n    file: schedule.yaml\n"
                   "    entry: connections.app\n    take: fx-core@big\n    value: 1\n"
                   "    reason: x\n")
        self.assertIn("merge.yaml: resolutions[0]: needs node, file, entry, reason and exactly "
                      "one of take and value", self.refused())

    def test_take_naming_no_side(self):
        self.collide()
        self.write("scenario/merge.yaml",
                   "resolutions:\n  - node: desk\n    file: schedule.yaml\n"
                   "    entry: connections.app\n    take: fx-other@big\n    reason: x\n")
        self.assertIn("merge.yaml takes 'fx-other@big', which names 0 of", self.refused())


class TestRefusedInputs(ComposeCopyTest):

    def test_duplicate_key_in_a_fragment(self):
        path = self.catalog / "domains" / "fx-part" / "producers" / "desk" / "schedule.yaml"
        path.write_text(path.read_text() + "connections:\n  other: {}\n")
        text = self.refused()
        self.assertIn("domains/fx-part/producers/desk/schedule.yaml: cannot be read: while "
                      "constructing a mapping", text)
        self.assertIn("found duplicate key 'connections'", text)
        problems = "\n".join(model.check_domain_dir(self.catalog / "domains" / "fx-part"))
        self.assertIn("domains/fx-part/producers/desk/schedule.yaml: cannot be read", problems)
        self.assertIn("found duplicate key 'connections'", problems)

    def test_duplicate_keys_in_merge_and_composition(self):
        self.write("scenario/merge.yaml", "resolutions: []\nresolutions: []\n")
        self.assertIn("merge.yaml: cannot be read", self.refused())
        path = self.scenario / "composition.yaml"
        path.write_text(path.read_text() + "order: [fx-core, fx-part]\n")
        self.assertIn("composition.yaml: cannot be read", self.composition_problems())

    def test_a_fragment_never_carries_intensity(self):
        self.edit("catalog/domains/fx-part/producers/desk/schedule.yaml",
                  lambda d: d.update(intensity=2.0))
        # refused with the domain's own check, before any merge
        self.assertIn("domains/fx-part/producers/desk/schedule.yaml: intensity: not a key of a "
                      "schedule.yaml fragment (connections, streams, shapes); intensity and "
                      "timeline are the scenario's", self.refused())

    def test_a_node_the_scenario_lacks(self):
        (self.catalog / "domains" / "fx-part" / "producers" / "desk").rename(
            self.catalog / "domains" / "fx-part" / "producers" / "ward")
        self.assertIn("domains/fx-part/producers/ward/: targets node ward, which scenario.yaml "
                      "has no scheduler node of that name", self.refused())

    def test_partners_on_different_shared_nodes(self):
        self.edit("scenario/scenario.yaml", lambda d: d["third_parties"][1].update(
            nodes=["desk"]))
        self.assertIn("scenario.yaml: third_parties[no-node-authority].nodes: ['desk'] name "
                      "other shared nodes", self.refused())

    def test_domains_the_check_refuses(self):
        self.edit("scenario/scenario.yaml", lambda d: d["domains"].pop(0))
        self.assertIn("scenario.yaml: domains[fx-part]: part fx-part without its core fx-core",
                      self.refused())

    def test_no_domains(self):
        self.edit("scenario/scenario.yaml", lambda d: d.pop("domains"))
        self.assertIn("scenario.yaml: no domains: to compose", self.refused())

    def test_the_verb_parses(self):
        args = build_parser().parse_args(["compose", "scenarios/x", "--check"])
        self.assertEqual((args.command, args.scenario_dir, args.check),
                         ("compose", "scenarios/x", True))


class TestComposition(ComposeCopyTest):
    """composition.yaml against domains: (formats.md "Composing domains"; W1 item 7)."""

    def scenario_yaml(self, change):
        self.edit("scenario/scenario.yaml", change)

    def record(self, change):
        self.edit("scenario/composition.yaml", change)

    def test_required_with_domains_refused_without(self):
        (self.scenario / "composition.yaml").unlink()
        self.assertIn("composition.yaml: missing file (the composition record, required with "
                      "domains:)", self.composition_problems())
        shutil.copy(FIXTURE_COMPOSE / "scenario" / "composition.yaml", self.scenario)
        self.scenario_yaml(lambda d: d.pop("domains"))
        self.assertIn("composition.yaml: present without domains:", self.composition_problems())

    def test_domain_entries(self):
        self.scenario_yaml(lambda d: (d.update(domain="fx-core"),
                                      d["domains"][1].update(variant="big", at="desk/clinic"),
                                      d["domains"][0].update(variant="small")))
        text = self.composition_problems()
        self.assertIn("scenario.yaml: domain: and domains: both", text)
        self.assertIn("scenario.yaml: domains[fx-part].variant: on a part", text)
        self.assertIn("scenario.yaml: domains[fx-core].variant: 'small' is not a variant of "
                      "fx-core", text)
        self.assertIn("scenario.yaml: domains[fx-part].at: desk/clinic: fx-part lands_with "
                      "fx-core, whose at: is records/clinic", text)
        self.assertIn("scenario.yaml: domains[fx-part].at: desk/clinic: desk is not a database "
                      "node (role producer)", text)

    def test_part_only_with_its_core_and_its_variant(self):
        self.edit("catalog/domains/fx-core/variants/big.yaml", lambda d: d.update(parts=[]))
        self.assertIn("scenario.yaml: domains[fx-part]: not a part of fx-core's variant big",
                      self.composition_problems())
        self.scenario_yaml(lambda d: d["domains"].pop(0))
        self.assertIn("scenario.yaml: domains[fx-part]: part fx-part without its core fx-core: "
                      "a part is taken only with its core", self.composition_problems())

    def test_at_forms(self):
        self.edit("catalog/domains/fx-part/domain.yaml", lambda d: (
            d.pop("schema"), d.pop("load"), d.pop("lands_with"), d.update(databases=["boxes"])))
        for name in ("schema.sql", "load.sql"):
            self.write(f"catalog/domains/fx-part/data/boxes/{name}",
                       (self.catalog / "domains/fx-part/data" / name).read_text())
        self.record(lambda d: d["domains"][1].pop("lands_with"))
        self.assertIn("scenario.yaml: domains[fx-part].at: 'records/clinic' is not a map from "
                      "each of fx-part's databases (boxes)", self.composition_problems())
        self.scenario_yaml(lambda d: d["domains"][1].update(at={"boxes": "records/Bad"}))
        self.record(lambda d: d["domains"][1].update(at={"boxes": "records/Bad"}))
        self.assertIn("scenario.yaml: domains[fx-part].at.boxes: 'records/Bad' is not "
                      "<node>/<database>", self.composition_problems())

    def test_record_against_domains(self):
        self.record(lambda d: (d["domains"][0].update(at="records/other"),
                               d["domains"][1].pop("lands_with"),
                               d.update(order=["fx-part", "fx-core"],
                                        keys={"fx-core": ["x"], "fx-part": []},
                                        scale={"checked": "yes", "note": "n"})))
        text = self.composition_problems()
        for fragment in (
                "composition.yaml: domains[fx-core].at: 'records/other' is not scenario.yaml's "
                "'records/clinic'",
                "composition.yaml: domains[fx-part].lands_with: None, but the domain declares "
                "'fx-core' (present exactly for a domain declaring it)",
                "composition.yaml: order: part fx-part before its core fx-core",
                "composition.yaml: keys.fx-core: not a part of domains:",
                "composition.yaml: keys.fx-part: empty",
                "composition.yaml: scale.checked: 'yes' is not true or false"):
            self.assertIn(fragment, text)

    def test_order_lists_every_domain_once(self):
        self.record(lambda d: d.update(order=["fx-core", "fx-core"]))
        self.assertIn("composition.yaml: order: ['fx-core', 'fx-core'] does not list every "
                      "domain of domains: once", self.composition_problems())

    def test_derivation_only_when_declared(self):
        self.record(lambda d: d.update(derive=[{"domain": "fx-part", "after": ["fx-core"],
                                                "reason": "copies"}]))
        self.assertIn("composition.yaml: derive[fx-part]: fx-part declares no derive",
                      self.composition_problems())
        self.edit("catalog/domains/fx-part/domain.yaml",
                  lambda d: d.update(derive={"after": ["fx-core"]}))
        self.write("catalog/domains/fx-part/data/derive.sql", "SELECT 1;\n")
        self.assertEqual(self.composition_problems(), "")
        self.record(lambda d: d.update(order=["fx-core", "fx-part"], derive=[
            {"domain": "fx-part", "after": ["fx-core", "fx-part"], "reason": "copies"}]))
        self.assertIn("composition.yaml: derive[fx-part].after: ['fx-core', 'fx-part'] is not "
                      "fx-part's declared ['fx-core']", self.composition_problems())


if __name__ == "__main__":
    unittest.main()
