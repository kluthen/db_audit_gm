"""gmctl compose and the composition record (tools/gm/compose.py,
model.check_composition; v0.5 master spec 8.4, 8.5, 15; W1 item 7)."""

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import build_parser, compose, localimpl, model
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


class TestLeftOut(ComposeCopyTest):
    """composition.yaml's left_out: (capture W3 item 0, chunk 29's (b)): no
    unit merged from a left-out producer folder, in either layer, and no
    node needed for it."""

    def leave_out(self, *producers):
        self.edit("scenario/composition.yaml", lambda d: d.update(left_out=[
            {"domain": did, "producer": producer, "reason": "a fixture's least environment"}
            for did, producer in producers]))

    def test_nothing_merged_and_no_node_needed(self):
        self.leave_out(("fx-part", "desk"), ("fx-core", "api/core-api"),
                       ("fx-core", "partners/practices"))
        self.edit("scenario/scenario.yaml", lambda d: (
            d.update(nodes=[n for n in d["nodes"] if n["name"] not in ("core-api",
                                                                       "partners-api")]),
            [t.update(nodes=[n for n in t["nodes"] if n != "partners-api"])
             for t in d["third_parties"]]))
        self.assertEqual(self.composition_problems(), "")
        result = self.compose()
        self.assertEqual(list(self.output("desk", "queries.yaml")["queries"]),
                         ["owners.lookup", "owners.new"])
        self.assertEqual(list(self.output("desk", "schedule.yaml")["connections"]), ["app"])
        written = sorted(str(p.relative_to(self.scenario)) for p in result.files)
        self.assertFalse([p for p in written if "core-api" in p or "practices" in p], written)
        backend = (self.scenario / "nodes/partners-backend/schedule.yaml").read_text()
        self.assertNotIn("fx-core@big: domains/fx-core/producers/partners/practices", backend)

    def test_the_variant_layer_left_out_too(self):
        self.leave_out(("fx-core", "desk"))
        self.compose()
        text = (self.scenario / "nodes/desk/schedule.yaml").read_text()
        self.assertNotIn("domains/fx-core/variants/big/producers/desk", text)
        self.assertNotIn("domains/fx-core/producers/desk", text)
        self.assertIn("domains/fx-part/producers/desk", text)

    def test_a_left_out_folder_still_needs_composing_without_the_entry(self):
        self.edit("scenario/scenario.yaml", lambda d: d.update(
            nodes=[n for n in d["nodes"] if n["name"] != "core-api"]))
        self.assertIn("domains/fx-core/producers/api/core-api/: targets node core-api, which "
                      "scenario.yaml has no api node of that name", self.refused())

    def test_a_malformed_entry_refused(self):
        self.leave_out(("fx-core", "api/nowhere"))
        text = self.refused()
        self.assertIn("composition.yaml: left_out: cannot be applied", text)
        self.assertIn("composition.yaml: left_out[0].producer: api/nowhere: not a folder of "
                      "domains/fx-core/producers/", text)



class TestLabStubs(unittest.TestCase):
    """vet-lab's two stubs' fragments composed onto the partners' three shared
    nodes (spec D403; capture W3 item 1): fixture-lab-core, its left-out
    partner folders put back, partners-api and partners-backend added as
    partners/shared/nodes.yaml declares them, the back end's base its scenario
    layer; gmctl compose from the repository's catalogue, then the output
    loaded with the scenario. No deployment."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="gmctl-lab-stubs-")
        self.addCleanup(tmp.cleanup)
        self.scenario = Path(tmp.name) / "fixture-lab-core"
        shutil.copytree(FIXTURES / "fixture-lab-core", self.scenario,
                        ignore=shutil.ignore_patterns("nodes"))
        shutil.copytree(FIXTURES / "fixture-lab-core" / "nodes", self.scenario / "nodes",
                        ignore=shutil.ignore_patterns("clinic-api", "lis", "lab-api"))
        record = self.scenario / "composition.yaml"
        data = yaml.safe_load(record.read_text())
        data["left_out"] = [e for e in data["left_out"] if not e["producer"].startswith("partners/")]
        record.write_text(yaml.safe_dump(data, sort_keys=False))
        shared = model.REPO_ROOT / "partners" / "shared"
        declared = yaml.safe_load((shared / "nodes.yaml").read_text())["nodes"]
        path = self.scenario / "scenario.yaml"
        data = yaml.safe_load(path.read_text())
        for node in declared[:2]:            # partners-api, partners-backend
            node["seed_files"] = {k: v.replace(f"<nodes/{node['name']}/>", f"nodes/{node['name']}/")
                                  for k, v in node["seed_files"].items()}
            data["nodes"].append(node)
            data["designed_for"]["placement"][node["name"]] = "laptop"
        for entry in data["third_parties"]:
            entry["nodes"] = ["partners-api", "partners-backend", "partners-db"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        hba = self.scenario / "nodes" / "partners-db" / "pg_hba.conf"
        hba.write_text(hba.read_text().replace(
            "host    all       all", "host    partners  practices,xlab        samenet     scram-sha-256\n"
            "host    all       all"))
        layer = self.scenario / "compose" / "partners-backend"
        layer.mkdir(parents=True)
        base = yaml.safe_load((shared / "partners-backend" / "schedule.yaml").read_text())
        (layer / "schedule.yaml").write_text(f"intensity: {base['intensity']}\n")
        self.result = compose.compose(self.scenario, model.REPO_ROOT)

    def output(self, node, fname):
        return model.strict_load((self.scenario / "nodes" / node / fname).read_text())

    def test_the_stubs_on_the_shared_nodes(self):
        api = self.output("partners-api", "api.yaml")
        self.assertEqual(api["endpoints"], {
            "practices_results": {"hosts": ["practices"], "credentials": ["practices_customer"]},
            "practices_tick": {"hosts": ["practices"], "credentials": ["partners_backend"]},
            "xlab_orders": {"hosts": ["northfield-lab"], "credentials": ["xlab_customer"]},
            "xlab_tick": {"hosts": ["northfield-lab"], "credentials": ["partners_backend"]}})
        self.assertEqual(sorted(api["connections"]), ["practices-db", "practices-lab", "xlab-db", "xlab-lab"])
        self.assertEqual({n: c["credential"] for n, c in api["connections"].items() if c["driver"] == "http"},
                         {"practices-lab": "lab_practices", "xlab-lab": "lab_xlab"})
        for name in api["endpoints"]:
            for folder in ("routes", "db"):
                self.assertTrue((self.scenario / "nodes" / "partners-api" / folder / f"{name}.py").is_file())
        backend = self.output("partners-backend", "schedule.yaml")
        self.assertEqual(backend["intensity"], 1.0)
        self.assertEqual([(s["key"], s["connection"]) for s in backend["streams"]],
                         [("practices.normal", "practices-db"), ("practices.order", "practices-tick"),
                          ("xlab.normal", "xlab-db"), ("xlab.answer", "xlab-tick")])
        self.assertEqual({n: (c["target"], c["credential"]) for n, c in backend["connections"].items()
                          if c["driver"] == "http"},
                         {"practices-tick": ("practices:8000", "partners_backend"),
                          "xlab-tick": ("northfield-lab:8000", "partners_backend")})
        self.assertEqual(sorted(backend["shapes"]), ["practice-hours", "xlab-hours"])
        queries = self.output("partners-backend", "queries.yaml")["queries"]
        self.assertEqual(queries["practices.order"], {"call": "POST /tick"})
        self.assertEqual(queries["xlab.answer"], {"call": "POST /tick"})
        self.assertEqual(self.output("partners-backend", "jobs.yaml"), {"jobs": []})

    def test_the_output_loads(self):
        scenario = model.load_scenario(self.scenario)
        self.assertEqual([t["hostname"] for t in scenario.data["third_parties"]],
                         ["northfield-lab", "practices"])
        self.assertEqual(self.result.overrides, [])


class TestPortalDesk(unittest.TestCase):
    """vet-portal's desk stream on the practice software (capture W3 item 5):
    fixture-portal, its two left-out pms folders put back (vet-core's and
    vet-portal's) and a pms node added; gmctl compose from the repository's
    catalogue. The desk's connection and stream join the core's on pms, the
    core's shape named, never written by the portal. No deployment."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="gmctl-portal-desk-")
        self.addCleanup(tmp.cleanup)
        self.scenario = Path(tmp.name) / "fixture-portal"
        shutil.copytree(FIXTURES / "fixture-portal", self.scenario, ignore=shutil.ignore_patterns("nodes"))
        shutil.copytree(FIXTURES / "fixture-portal" / "nodes", self.scenario / "nodes",
                        ignore=shutil.ignore_patterns("portal-api", "interfaces", "partners-api",
                                                      "partners-backend"))
        record = self.scenario / "composition.yaml"
        data = yaml.safe_load(record.read_text())
        data["left_out"] = [e for e in data["left_out"] if e["producer"] != "pms"]
        record.write_text(yaml.safe_dump(data, sort_keys=False))
        path = self.scenario / "scenario.yaml"
        data = yaml.safe_load(path.read_text())
        data["nodes"].append({
            "name": "pms", "brick": {"id": "scheduler", "version": "0.3.0"}, "role": "producer",
            "stateful": True, "networks": ["backend"], "write_policy": "no-access", "parameters": {},
            "resources": {"limits": {"cpu": 0.25, "memory": "128M"},
                          "reservations": {"cpu": 0.1, "memory": "64M", "disk": "128M"}},
            "published_ports": [],
            "seed_files": {f: f"nodes/pms/{f}" for f in ("queries.yaml", "jobs.yaml", "schedule.yaml")},
            "knobs": []})
        data["designed_for"]["placement"]["pms"] = "laptop"
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        layer = self.scenario / "compose" / "pms"
        layer.mkdir(parents=True)
        (layer / "schedule.yaml").write_text("intensity: 1.0\n")
        self.result = compose.compose(self.scenario, model.REPO_ROOT)

    def output(self, node, fname):
        return model.strict_load((self.scenario / "nodes" / node / fname).read_text())

    def test_the_desk_on_pms(self):
        schedule = self.output("pms", "schedule.yaml")
        self.assertEqual(schedule["connections"]["portal"],
                         {"driver": "http", "target": "portal-api:8000", "credential": "portal_desk",
                          "pool": 1, "timeout": "10s"})
        self.assertEqual(schedule["connections"]["clinic"]["role"], "vet_app")
        desk = [s for s in schedule["streams"] if s["key"] == "portal.desk-consent"]
        self.assertEqual(desk, [{"key": "portal.desk-consent", "connection": "portal", "rate": "0.28/h",
                                 "arrivals": "poisson", "shape": "clinic-day"}])
        self.assertIn("clinic-day", schedule["shapes"])
        queries = self.output("pms", "queries.yaml")["queries"]
        self.assertEqual(queries["portal.desk-consent"], {
            "call": "POST /desk/consents",
            "params": {"owner_id": {"int": [2, 10000]}, "purpose": {"choice": ["reminders"]},
                       "granted": {"choice": {True: 2, False: 1}}}})
        self.assertEqual(self.result.overrides, [])

    def test_the_desk_endpoint_takes_the_credential(self):
        api = self.output("portal-api", "api.yaml")
        self.assertEqual(api["endpoints"]["desk"], {"hosts": ["portal-api"], "credentials": ["portal_desk"]})
        self.assertEqual([n for n, e in api["endpoints"].items() if "credentials" not in e],
                         ["session", "me", "animals", "documents", "accounts"])


# A test-local owners' route (vet-portal's shape, D369): one tick on the
# hostname owners behind the back end's credential.
OWNERS_FILES = {
    "api.yaml": "endpoints:\n  owners_tick:\n    hosts: [owners]\n"
                "    credentials: [partners_backend]\n",
    "schedule.yaml": "connections:\n  owners-tick: {driver: http, target: owners:8000, "
                     "credential: partners_backend, pool: 1, timeout: 30s}\n"
                     "streams:\n  - key: owners.visit\n    connection: owners-tick\n"
                     "    rate: 6/h\n    arrivals: poisson\n",
    "queries.yaml": "queries:\n  owners.visit:\n    call: POST /tick\n",
    "routes/owners_tick.py": '"""The owners\' tick (a test-local owners\' route)."""\n\n'
                             "from fastapi import APIRouter\n\nfrom db import owners_tick\n\n"
                             "router = APIRouter()\n\n\n@router.post(\"/tick\")\ndef tick():\n"
                             "    return owners_tick.tick()\n",
    "db/owners_tick.py": '"""The owners\' tick, its database side (test-local)."""\n\n\n'
                         "def tick():\n    return {\"visits\": 1}\n",
}
OWNERS_ROUTE = "domains/vet-lab/producers/partners/owners/"


class OwnersAloneCase(unittest.TestCase):
    """The partners' shared nodes serving the owners alone (spec D421;
    build plan chunk 31): fixture-lab-core, whose third parties list
    [partners-db] only and whose lab partner folders are left out, with
    partners-api and partners-backend added as partners/shared/nodes.yaml
    declares them, and a test catalog whose vet-lab (a copy) carries a
    test-local owners' route; the repository's other units linked. No
    deployment. Holds no test: test_compose's and test_model's derive."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="gmctl-owners-alone-")
        self.addCleanup(tmp.cleanup)
        self.catalog = Path(tmp.name) / "catalog"
        (self.catalog / "domains").mkdir(parents=True)
        for unit in ("bricks", "faults", "purposes", "partners"):
            (self.catalog / unit).symlink_to(model.REPO_ROOT / unit)
        for domain in sorted((model.REPO_ROOT / "domains").iterdir()):
            if domain.name == "vet-lab":
                shutil.copytree(domain, self.catalog / "domains" / domain.name)
            elif domain.is_dir():
                (self.catalog / "domains" / domain.name).symlink_to(domain)
        for rel, text in OWNERS_FILES.items():
            path = self.catalog / OWNERS_ROUTE / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.scenario = Path(tmp.name) / "fixture-lab-core"
        shutil.copytree(FIXTURES / "fixture-lab-core", self.scenario,
                        ignore=shutil.ignore_patterns("nodes"))
        shutil.copytree(FIXTURES / "fixture-lab-core" / "nodes", self.scenario / "nodes",
                        ignore=shutil.ignore_patterns("clinic-api", "lis", "lab-api"))
        declared = yaml.safe_load((model.REPO_ROOT / "partners" / "shared" / "nodes.yaml")
                                  .read_text())["nodes"]
        def add(data):
            for node in declared[:2]:        # partners-api, partners-backend
                node["seed_files"] = {k: v.replace(f"<nodes/{node['name']}/>",
                                                   f"nodes/{node['name']}/")
                                      for k, v in node["seed_files"].items()}
                data["nodes"].append(node)
                data["designed_for"]["placement"][node["name"]] = "laptop"
        self.scenario_yaml(add)
        layer = self.scenario / "compose" / "partners-backend"
        layer.mkdir(parents=True)
        (layer / "schedule.yaml").write_text("intensity: 1.0\n")

    def scenario_yaml(self, change):
        path = self.scenario / "scenario.yaml"
        data = yaml.safe_load(path.read_text())
        change(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def node(self, data, name):
        return next(n for n in data["nodes"] if n["name"] == name)

    def compose(self):
        return compose.compose(self.scenario, self.catalog)

    def refused(self):
        with self.assertRaises(compose.ComposeRefused) as cm:
            self.compose()
        return str(cm.exception)

    def problems(self):
        return "\n".join(model.check_scenario(self.scenario, self.catalog)[1])

    def output(self, node, fname):
        return model.strict_load((self.scenario / "nodes" / node / fname).read_text())


class TestOwnersAlone(OwnersAloneCase):
    """compose with no third_parties: entry listing a scheduler or api node
    (spec D421): a domain's owners' route alone onto partners-backend and
    partners-api; every other refusal as before."""

    def test_the_owners_route_alone_composes_and_loads(self):
        result = self.compose()
        api = self.output("partners-api", "api.yaml")
        self.assertEqual(api["endpoints"], {"owners_tick": {"hosts": ["owners"],
                                                            "credentials": ["partners_backend"]}})
        for folder in ("routes", "db"):
            self.assertTrue((self.scenario / "nodes/partners-api" / folder / "owners_tick.py")
                            .is_file())
        backend = self.output("partners-backend", "schedule.yaml")
        self.assertEqual([(s["key"], s["connection"]) for s in backend["streams"]],
                         [("owners.visit", "owners-tick")])
        self.assertEqual(self.output("partners-backend", "queries.yaml")["queries"],
                         {"owners.visit": {"call": "POST /tick"}})
        self.assertIn(f"vet-lab@regional-franchise: {OWNERS_ROUTE}api.yaml",
                      (self.scenario / "nodes/partners-api/api.yaml").read_text())
        self.assertEqual(result.overrides, [])
        scenario = model.load_scenario(self.scenario, self.catalog)
        self.assertEqual({t["id"]: t["nodes"] for t in scenario.data["third_parties"]},
                         {"northfield-lab": ["partners-db"],
                          "regional-practices": ["partners-db"]})
        self.assertEqual(localimpl.node_aliases(scenario, self.node(scenario.data,
                                                                    "partners-api")),
                         ["owners"])

    def test_the_helper_names_both_nodes(self):
        data = yaml.safe_load((self.scenario / "scenario.yaml").read_text())
        found = model.owners_alone_nodes(data, set(), self.catalog)
        self.assertEqual((found.scheduler, found.api, found.routes, found.problems),
                         ("partners-backend", "partners-api", [OWNERS_ROUTE], []))
        self.assertIsNone(model.owners_alone_nodes(data, {("vet-lab", "partners/owners")},
                                                   self.catalog))
        for entry in data["third_parties"]:
            entry["nodes"] = ["partners-api", "partners-backend", "partners-db"]
        self.assertIsNone(model.owners_alone_nodes(data, set(), self.catalog))

    def test_another_partner_folder_refused_as_before(self):
        path = self.scenario / "composition.yaml"
        data = yaml.safe_load(path.read_text())
        data["left_out"] = [e for e in data["left_out"] if e["producer"] != "partners/xlab"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        self.assertEqual(self.refused(), "domains/vet-lab/producers/partners/xlab/: partner "
                         "material, but no third_parties: entry lists a scheduler node")

    def test_either_node_missing(self):
        for name in ("partners-backend", "partners-api"):
            with self.subTest(node=name):
                self.setUp()
                self.scenario_yaml(lambda d: d.update(
                    nodes=[n for n in d["nodes"] if n["name"] != name]))
                self.assertEqual(self.refused(), (
                    f"scenario.yaml: nodes: no node {name}: the owners' route ({OWNERS_ROUTE}) "
                    "goes onto the partners' shared nodes partners-backend and partners-api, as "
                    "no third_parties: entry lists a scheduler or api node (spec D421)"))

    def test_a_node_of_another_brick(self):
        self.scenario_yaml(lambda d: self.node(d, "partners-backend").update(
            brick={"id": "api", "version": "0.1.0"}))
        self.assertIn("scenario.yaml: nodes[partners-backend]: brick api, not scheduler: the "
                      f"owners' route ({OWNERS_ROUTE}) goes onto the partners' shared nodes",
                      self.refused())

    def test_a_node_not_no_access(self):
        self.scenario_yaml(lambda d: self.node(d, "partners-api").update(
            write_policy="read-only"))
        self.assertIn("scenario.yaml: nodes[partners-api]: write_policy read-only, not "
                      "no-access: the owners' route", self.refused())


class TestSharedNodeRefusals(ComposeCopyTest):
    """compose's scheduler and api refusals with no owners' route, unchanged
    by spec D421: a partner folder composed with no entry listing the node."""

    def test_no_scheduler_node_listed(self):
        self.edit("scenario/scenario.yaml", lambda d: d["third_parties"][0].update(
            nodes=["partners-db"]))
        self.assertEqual(self.refused(), "domains/fx-core/producers/partners/practices/: "
                         "partner material, but no third_parties: entry lists a scheduler node")

    def test_no_api_node_listed(self):
        self.edit("scenario/scenario.yaml", lambda d: d["third_parties"][0].update(
            nodes=["partners-backend", "partners-db"]))
        self.assertEqual(self.refused(), "domains/fx-core/producers/partners/practices/: "
                         "partner endpoints, but no third_parties: entry lists an api node")


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
