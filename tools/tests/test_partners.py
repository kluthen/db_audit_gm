"""The partners' catalogue folder and its two fixtures (v0.5 build plan,
chunk 11; master spec 10.2, 10.4, 11.2; capture W2 item 6, W2-f).

`partners/shared/` is the three shared partner nodes' base, the GM copies them into a scenario, and
`fixture-partners` is such a copy. These tests keep
the copies equal to the catalogue, load and render the fixture."""

import re
import shutil
import unittest
from pathlib import Path

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import FIXTURES, REPO_ROOT, SUFFICIENT, ScenarioCopyTest
from tools.tests.test_render import handover_at

PARTNERS = REPO_ROOT / "partners"
SHARED = PARTNERS / "shared"
FX_PARTNERS = FIXTURES / "fixture-partners"
HBA_LINE = re.compile(r"^host\s+partners\s+(\S+)\s+samenet\s+scram-sha-256$", re.M)


def text(path):
    return path.read_text(encoding="utf-8")


def load(path):
    return yaml.safe_load(text(path))


def body(path):
    """A YAML file's content without its leading comment block."""
    lines = text(path).splitlines(keepends=True)
    while lines and (lines[0].startswith("#") or not lines[0].strip()):
        lines.pop(0)
    return "".join(lines)


class TestCatalogue(unittest.TestCase):
    """partners/ as the GM copies it."""

    def test_layout(self):
        files = sorted(str(p.relative_to(PARTNERS)) for p in PARTNERS.rglob("*") if p.is_file())
        self.assertEqual(files, [
            "README.md",
            "shared/nodes.yaml",
            "shared/partners-backend/jobs.yaml", "shared/partners-backend/queries.yaml",
            "shared/partners-backend/schedule.yaml",
            "shared/partners-db/data.sql", "shared/partners-db/pg_hba.conf",
            "shared/partners-db/postgresql.conf",
        ])

    def test_yaml_loads_without_duplicate_keys(self):
        for path in sorted(PARTNERS.rglob("*.yaml")):
            with self.subTest(path=path.name):
                self.assertIsNotNone(model.strict_load(text(path)))

    def test_python_compiles(self):
        for path in sorted(PARTNERS.rglob("*.py")):
            with self.subTest(path=str(path.relative_to(PARTNERS))):
                compile(text(path), str(path), "exec")

    def test_the_partners_line_is_the_one_to_fill(self):
        hba = text(SHARED / "partners-db" / "pg_hba.conf")
        rules = [l for l in hba.splitlines() if l.strip() and not l.startswith("#")]
        self.assertEqual(rules[-1].split(), ["host", "all", "all", "all", "reject"])
        self.assertEqual(HBA_LINE.findall(hba), ["<prefix>,coldstore"])
        self.assertNotIn("gm_check samenet", re.sub(r"\s+", " ", hba))   # access model 14

    def test_shared_data_file_ends_in_partners(self):
        sql = [l for l in text(SHARED / "partners-db" / "data.sql").splitlines()
               if l.strip() and not l.startswith("--")]
        self.assertEqual(sql, ["CREATE DATABASE partners;", "\\connect partners"])

class TestFixtureCopies(unittest.TestCase):
    """Each fixture holds the catalogue's files as the GM copies them."""

    def nodes(self, fixture):
        return {n["name"]: n for n in load(fixture / "scenario.yaml")["nodes"]}

    def test_shared_nodes_declared_as_the_catalogue(self):
        shared = {n["name"]: n for n in load(SHARED / "nodes.yaml")["nodes"]}
        for fixture in (FX_PARTNERS,):
            nodes = self.nodes(fixture)
            for name, entry in shared.items():
                with self.subTest(fixture=fixture.name, node=name):
                    got = {k: v for k, v in nodes[name].items() if k not in ("seed_files", "data")}
                    want = {k: v for k, v in entry.items() if k != "seed_files"}
                    self.assertEqual(got, want)
                    self.assertEqual(sorted(nodes[name]["seed_files"]), sorted(entry["seed_files"]))

    def test_partners_db_seeds(self):
        for fixture, roles in ((FX_PARTNERS, ["alpha", "beta"]),):
            with self.subTest(fixture=fixture.name):
                d = fixture / "nodes" / "partners-db"
                self.assertEqual(text(d / "postgresql.conf"), text(SHARED / "partners-db" / "postgresql.conf"))
                self.assertEqual(HBA_LINE.findall(text(d / "pg_hba.conf")), [",".join(roles)])
                self.assertEqual(HBA_LINE.sub("", text(d / "pg_hba.conf")),
                                 HBA_LINE.sub("", text(SHARED / "partners-db" / "pg_hba.conf")))
                data = text(fixture / "data" / "partners-db.sql")
                self.assertTrue(data.startswith(text(SHARED / "partners-db" / "data.sql")))

    def test_the_partners_line_names_the_partners_roles(self):
        """The roles pg_hba.conf admits are exactly those the partners' nodes
        connect as (capture W2 item 1: theirs alone)."""
        for fixture in (FX_PARTNERS,):
            with self.subTest(fixture=fixture.name):
                api = load(fixture / "nodes" / "partners-api" / "api.yaml")
                sched = load(fixture / "nodes" / "partners-backend" / "schedule.yaml")
                roles = {c["role"] for c in list(api["connections"].values()) + list(sched["connections"].values())
                         if c["driver"] == "sql/postgresql"}
                line = HBA_LINE.findall(text(fixture / "nodes" / "partners-db" / "pg_hba.conf"))[0]
                self.assertEqual(set(line.split(",")), roles)

class FixtureRendered(ScenarioCopyTest):
    fixture = None

    def setUp(self):
        super().setUp()
        self.scenario = self.tmp / self.fixture.name
        shutil.copytree(self.fixture, self.scenario)
        self.ldir = self.scenario / "local" / "laptop"
        fit.fit(self.scenario, "laptop", **SUFFICIENT)
        render.render(self.scenario, "laptop", handover=handover_at(16))
        self.gid = localimpl.read_implementation(self.ldir)["game_id"]
        self.stack = yaml.safe_load((self.ldir / "stack.yml").read_text())

    def secrets(self, node):
        return sorted(s["source"][len(self.gid) + 1:] for s in self.stack["services"][node].get("secrets", [])
                      if s["source"][len(self.gid) + 1:].startswith(("role_", "http_")))


class TestPartnersFixture(FixtureRendered):
    fixture = FX_PARTNERS

    def test_loads(self):
        s = model.load_scenario(self.scenario)
        self.assertEqual([t["hostname"] for t in s.data["third_parties"]], ["alpha-lab", "beta-lab"])

    def test_aliases_and_secrets(self):
        services = self.stack["services"]
        self.assertEqual(services["partners-api"]["networks"], {"backend": {"aliases": ["alpha-lab", "beta-lab"]}})
        want = ["http_partners_backend", "role_alpha_password", "role_beta_password"]
        self.assertEqual(self.secrets("partners-api"), want)
        self.assertEqual(self.secrets("partners-backend"), want)
        self.assertEqual(self.secrets("bastion"), [])
        self.assertEqual(self.secrets("partners-db"), [])
        for node in ("partners-api", "partners-backend", "partners-db"):
            self.assertEqual(services[node]["environment"]["GM_WRITE_POLICY"], "no-access")

    def test_the_slow_key_placed_standing(self):
        """f1 at T0: the timeline changes alpha.normal to alpha.slow, at the
        render time, which no load start precedes (render.moment_instant)."""
        sched = load(FX_PARTNERS / "nodes" / "partners-backend" / "schedule.yaml")
        self.assertEqual([(c["at"], c["stream"], c["set"]["key"]) for c in sched["timeline"]],
                         [("T0", "alpha.normal", "alpha.slow")])
        queries = load(FX_PARTNERS / "nodes" / "partners-backend" / "queries.yaml")["queries"]
        self.assertIn("'delay_ms', '4000'", queries["alpha.slow"]["sql"])
        self.assertIn("'delay_ms', '0'", queries["alpha.normal"]["sql"])


if __name__ == "__main__":
    unittest.main()
