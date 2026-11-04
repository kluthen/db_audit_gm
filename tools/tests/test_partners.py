"""The partners' catalogue folder and its two fixtures (v0.5 build plan,
chunk 11; master spec 10.2, 10.4, 11.2; capture W2 item 6, W2-f).

`partners/shared/` is the three shared partner nodes' base, `partners/
coldstore/` cold storage's stub; the GM copies them into a scenario, and
`fixture-partners` and `fixture-archive` are such copies. These tests keep
the copies equal to the catalogue, load and render both fixtures, and read
cold storage's page code with the brick's imports stood in (the host has
neither FastAPI nor psycopg; the fixtures' short tests run it for real)."""

import re
import shutil
import sys
import types
import unittest
from pathlib import Path

import yaml

from tools.gm import fit, localimpl, model, render
from tools.tests import FIXTURES, REPO_ROOT, SUFFICIENT, ScenarioCopyTest
from tools.tests.test_render import handover_at

PARTNERS = REPO_ROOT / "partners"
SHARED = PARTNERS / "shared"
COLDSTORE = PARTNERS / "coldstore"
FX_PARTNERS = FIXTURES / "fixture-partners"
FX_ARCHIVE = FIXTURES / "fixture-archive"
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
            "coldstore/api.yaml", "coldstore/data.sql",
            "coldstore/db/coldstore_manifests.py", "coldstore/db/coldstore_page.py",
            "coldstore/db/coldstore_shipments.py", "coldstore/planted.sql", "coldstore/queries.yaml",
            "coldstore/routes/coldstore_manifests.py", "coldstore/routes/coldstore_page.py",
            "coldstore/routes/coldstore_shipments.py", "coldstore/schedule.yaml",
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

    def test_coldstore_is_laid_out_as_a_partner_folder(self):
        api = load(COLDSTORE / "api.yaml")
        self.assertEqual(sorted(api["endpoints"]),
                         ["coldstore_manifests", "coldstore_page", "coldstore_shipments"])
        for name, e in api["endpoints"].items():
            with self.subTest(endpoint=name):
                self.assertEqual(e["hosts"], ["cold-storage"])
                self.assertTrue((COLDSTORE / "routes" / f"{name}.py").is_file())
                self.assertTrue((COLDSTORE / "db" / f"{name}.py").is_file())
        self.assertEqual(api["endpoints"]["coldstore_shipments"]["credentials"], ["cold_storage"])
        self.assertNotIn("credentials", api["endpoints"]["coldstore_manifests"])
        self.assertNotIn("credentials", api["endpoints"]["coldstore_page"])
        conn = {"driver": "sql/postgresql", "target": "partners-db:5432/partners", "role": "coldstore"}
        self.assertEqual({k: api["connections"]["coldstore-db"][k] for k in conn}, conn)
        sched = load(COLDSTORE / "schedule.yaml")
        self.assertEqual(sched["streams"], [{"key": "coldstore.normal", "connection": "coldstore-db",
                                             "rate": "1/min", "arrivals": "even"}])
        self.assertIn("coldstore.normal", load(COLDSTORE / "queries.yaml")["queries"])

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

    def test_coldstore_data_never_connects(self):
        for name in ("data.sql", "planted.sql"):
            with self.subTest(file=name):
                self.assertNotRegex(text(COLDSTORE / name), r"(?m)^\\(c|connect)\b")


def coldstore_db(name):
    """A db/ module's namespace, its brick import (gm_api) stood in."""
    saved = sys.modules.get("gm_api")
    sys.modules["gm_api"] = types.ModuleType("gm_api")
    try:
        ns = {}
        exec(compile(text(COLDSTORE / "db" / f"{name}.py"), f"{name}.py", "exec"), ns)
        return ns
    finally:
        if saved is None:
            sys.modules.pop("gm_api")
        else:
            sys.modules["gm_api"] = saved


class TestManifestKey(unittest.TestCase):
    """Cold storage's manifest keyed (source, shipment_id) (spec D381): one
    segment name from two sources, two manifests; the same source again,
    its own replaced. The fixture's short test posts both for real."""

    def test_the_key_is_source_and_shipment_id(self):
        ddl = text(COLDSTORE / "data.sql")
        table = re.search(r"CREATE TABLE coldstore\.manifests \((.*?)\n\);", ddl, re.S).group(1)
        self.assertEqual(re.findall(r"PRIMARY KEY[^\n]*", table), ["PRIMARY KEY (source, shipment_id),"])
        self.assertRegex(table, r"\n    shipment_id   text NOT NULL,")

    def test_the_upsert_replaces_the_sources_own(self):
        sql = " ".join(coldstore_db("coldstore_shipments")["RECORD"].split())
        self.assertIn("ON CONFLICT (source, shipment_id) DO UPDATE SET", sql)
        sets = re.search(r"DO UPDATE SET (.*) RETURNING", sql).group(1)
        updated = [s.split("=")[0].strip() for s in sets.split(",")]
        self.assertNotIn("source", updated)
        self.assertNotIn("shipment_id", updated)
        self.assertIn("received_at = now()", sets)

    def test_manifests_ordered_received_source_id(self):
        sql = coldstore_db("coldstore_manifests")["LIST"]
        self.assertEqual(re.findall(r"ORDER BY ([^\n]*)", sql), ["received_at, source, shipment_id"])


class TestFixtureCopies(unittest.TestCase):
    """Each fixture holds the catalogue's files as the GM copies them."""

    def nodes(self, fixture):
        return {n["name"]: n for n in load(fixture / "scenario.yaml")["nodes"]}

    def test_shared_nodes_declared_as_the_catalogue(self):
        shared = {n["name"]: n for n in load(SHARED / "nodes.yaml")["nodes"]}
        for fixture in (FX_PARTNERS, FX_ARCHIVE):
            nodes = self.nodes(fixture)
            for name, entry in shared.items():
                with self.subTest(fixture=fixture.name, node=name):
                    got = {k: v for k, v in nodes[name].items() if k not in ("seed_files", "data")}
                    want = {k: v for k, v in entry.items() if k != "seed_files"}
                    self.assertEqual(got, want)
                    self.assertEqual(sorted(nodes[name]["seed_files"]), sorted(entry["seed_files"]))

    def test_partners_db_seeds(self):
        for fixture, roles in ((FX_PARTNERS, ["alpha", "beta"]), (FX_ARCHIVE, ["coldstore"])):
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
        for fixture in (FX_PARTNERS, FX_ARCHIVE):
            with self.subTest(fixture=fixture.name):
                api = load(fixture / "nodes" / "partners-api" / "api.yaml")
                sched = load(fixture / "nodes" / "partners-backend" / "schedule.yaml")
                roles = {c["role"] for c in list(api["connections"].values()) + list(sched["connections"].values())
                         if c["driver"] == "sql/postgresql"}
                line = HBA_LINE.findall(text(fixture / "nodes" / "partners-db" / "pg_hba.conf"))[0]
                self.assertEqual(set(line.split(",")), roles)

    def test_archive_holds_cold_storage_verbatim(self):
        api = FX_ARCHIVE / "nodes" / "partners-api"
        self.assertEqual(body(api / "api.yaml"), body(COLDSTORE / "api.yaml"))
        for folder in ("routes", "db"):
            names = sorted(p.name for p in (COLDSTORE / folder).glob("*.py"))
            self.assertEqual(sorted(p.name for p in (api / folder).glob("*.py")), names)
            for n in names:
                with self.subTest(file=f"{folder}/{n}"):
                    self.assertEqual(text(api / folder / n), text(COLDSTORE / folder / n))
        backend = FX_ARCHIVE / "nodes" / "partners-backend"
        sched, frag = load(backend / "schedule.yaml"), load(COLDSTORE / "schedule.yaml")
        self.assertEqual((sched["connections"], sched["streams"]), (frag["connections"], frag["streams"]))
        self.assertEqual(load(backend / "queries.yaml"), load(COLDSTORE / "queries.yaml"))
        data = text(FX_ARCHIVE / "data" / "partners-db.sql")
        self.assertIn(text(COLDSTORE / "data.sql"), data)
        self.assertIn(text(COLDSTORE / "planted.sql"), data)
        self.assertLess(data.index(text(COLDSTORE / "data.sql")), data.index(text(COLDSTORE / "planted.sql")))


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


class TestArchiveFixture(FixtureRendered):
    fixture = FX_ARCHIVE

    def test_loads(self):
        s = model.load_scenario(self.scenario)
        self.assertEqual([t["hostname"] for t in s.data["third_parties"]], ["cold-storage"])

    def test_aliases_and_secrets(self):
        services = self.stack["services"]
        self.assertEqual(services["partners-api"]["networks"], {"backend": {"aliases": ["cold-storage"]}})
        self.assertEqual(self.secrets("records"), ["http_cold_storage"])
        self.assertEqual(self.secrets("partners-api"), ["http_cold_storage", "role_coldstore_password"])
        self.assertEqual(self.secrets("partners-backend"), ["role_coldstore_password"])
        self.assertEqual(self.secrets("bastion"), [])
        env = services["records"]["environment"]
        self.assertEqual((env["GM_VAULT_TARGET"], env["GM_VAULT_CREDENTIAL"]), ("cold-storage:8000", "cold_storage"))


# --- cold storage's page, its brick imports stood in --------------------------------

class _Router:
    def __init__(self):
        self.routes = []

    def _add(self, method, path, **kw):
        def deco(fn):
            self.routes.append((method, path, fn))
            return fn
        return deco

    def get(self, path, **kw):
        return self._add("GET", path, **kw)

    def post(self, path, **kw):
        return self._add("POST", path, **kw)


def _stand_ins(per_day):
    fastapi = types.ModuleType("fastapi")
    fastapi.APIRouter = _Router
    fastapi.Request = object
    fastapi.Depends = fastapi.Query = lambda *a, **k: None
    fastapi.HTTPException = type("HTTPException", (Exception,), {})
    responses = types.ModuleType("fastapi.responses")
    responses.HTMLResponse = lambda content, **k: content
    fastapi.responses = responses
    db = types.ModuleType("db")
    page = types.ModuleType("db.coldstore_page")
    page.DAYS = 35
    page.state = lambda hostname: {"delay_ms": "0"}
    page.per_day = per_day
    db.coldstore_page = page
    return {"fastapi": fastapi, "fastapi.responses": responses, "db": db, "db.coldstore_page": page}


class TestColdStoragePage(unittest.TestCase):

    def page(self, rows):
        mods = _stand_ins(lambda: ("2026-11-04", rows))
        saved = {k: sys.modules.get(k) for k in mods}
        sys.modules.update(mods)
        try:
            ns = {}
            exec(compile(text(COLDSTORE / "routes" / "coldstore_page.py"), "coldstore_page.py", "exec"), ns)
            request = types.SimpleNamespace(headers={"host": "cold-storage:8000"})
            return ns, ns["page"](request)
        finally:
            for k, v in saved.items():
                if v is None:
                    sys.modules.pop(k, None)
                else:
                    sys.modules[k] = v

    def test_one_chart_per_type_vault_first(self):
        _, html = self.page([("vitals", "2026-11-03", 52000, 52000, 1), ("basebackup", "2026-11-03", 1, 1, 1),
                             ("wal", "2026-11-03", 30, 30, 30), ("wal", "2026-11-04", 12, 12, 12)])
        self.assertEqual(re.findall(r"<h2>([^<]*)</h2>", html), ["wal", "basebackup", "vitals"])
        self.assertEqual(html.count("<svg"), 3)
        self.assertNotIn("<script", html.lower())
        self.assertIn("2026-11-03: declared 30, received 30, 30 shipments", html)
        self.assertNotIn('class="mis"', html)
        self.assertIn("2026-10-01 to 2026-11-04", html)          # five weeks, today included

    def test_a_mismatch_is_marked_and_named(self):
        _, html = self.page([("vitals", "2026-11-02", 520, 480, 1)])
        self.assertEqual(html.count('class="mis"'), 1)
        self.assertIn("Received differs from declared: 2026-11-02 (declared 520, received 480)", html)

    def test_no_shipment(self):
        _, html = self.page([])
        self.assertIn("No shipment received in the last 35 days.", html)

    def test_axis_top(self):
        ns, _ = self.page([])
        self.assertEqual([ns["_top"](v) for v in (0, 1, 3, 30, 52000, 100, 101)],
                         [1, 1, 5, 50, 100000, 100, 200])


if __name__ == "__main__":
    unittest.main()
