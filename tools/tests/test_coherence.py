"""The composed load of load-data and the post-load coherence check (v0.5
chunk 8; capture W2 item 3; tools/gm/inject.py, tools/gm/coherence.py), on
tools/tests/fixtures/fixture-composed: the plan, the runs with exec_node
stubbed, the coherence file, the record; and, with GM_TEST_COMPOSED_LOAD=1,
the composed test load into throwaway containers of the postgres image
(the fixture's README)."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import types
import unittest
from pathlib import Path
from unittest import mock

import yaml

from tools.gm import coherence, execnode, inject, localimpl, model
from tools.gm.model import GmError

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "fixture-composed"
CATALOG = FIXTURE / "catalog"
GM_CHECK_PASSWORD = "Gm-check-secret-c8"


def fixture_copy(test):
    """A fresh copy of the fixture (scenario/ and catalog/) in a temporary
    folder; its scenario as load-data's plans read it."""
    tmp = Path(tempfile.mkdtemp(prefix="gmtest-composed."))
    test.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
    shutil.copytree(FIXTURE, tmp / "fixture")
    return tmp / "fixture"


def scenario_of(fixture):
    data = yaml.safe_load((fixture / "scenario" / "scenario.yaml").read_text())
    for node in data["nodes"]:
        brick, _, version = node["brick"].partition("@")
        node["brick"] = {"id": brick, "version": version}
    bricks = {n["name"]: types.SimpleNamespace(
        id="postgres", data={"secrets": [{"name": inject.CHECK_SECRET}]}) for n in data["nodes"]}
    return types.SimpleNamespace(dir=fixture / "scenario", data=data, nodes=data["nodes"],
                                 bricks=bricks)


def impl_of(scenario):
    return {"game_id": "gmtest", "nodes": {n["name"]: {} for n in scenario.nodes}}


def game_dir(test):
    ldir = Path(tempfile.mkdtemp(prefix="gmtest-composed-game."))
    test.addCleanup(shutil.rmtree, ldir, ignore_errors=True)
    (ldir / "secrets").mkdir()
    (ldir / "secrets" / inject.CHECK_SECRET).write_text(GM_CHECK_PASSWORD)
    localimpl.new_state(ldir, "gmtest", "deployed")
    return ldir


def write_role_secrets(ldir, plans):
    """A secret for each role the password step sets (render writes them in
    a game, the domains' and the partner file's login roles included)."""
    for _, roles in plans.passwords:
        for _, secret in roles:
            (ldir / "secrets" / secret).write_text(f"pw-{secret}")
    plans.secrets = {s for _, roles in plans.passwords for _, s in roles}


# --- The coherence file ------------------------------------------------------

class TestReadChecks(unittest.TestCase):

    def setUp(self):
        self.dir = Path(tempfile.mkdtemp(prefix="gmtest-checks."))
        self.addCleanup(shutil.rmtree, self.dir, ignore_errors=True)
        self.path = self.dir / "coherence.yaml"

    def read(self, text, databases=None):
        self.path.write_text(text)
        return coherence.read_checks(self.path, "fx-ward", databases)

    def refused(self, text, *fragments, databases=None):
        with self.assertRaises(GmError) as cm:
            self.read(text, databases)
        for fragment in fragments:
            self.assertIn(fragment, str(cm.exception))

    def test_the_fixtures_files(self):
        checks = coherence.read_checks(CATALOG / "domains/fx-ward/data/coherence.yaml", "fx-ward")
        self.assertEqual([c.id for c in checks],
                         ["placements-on-stays", "stays-placed", "requests-on-current-stays"])
        self.assertEqual(checks[2].reads, ["fx-core", "partners"])
        self.assertTrue(checks[1].sql.startswith("SELECT s.id AS stay_id"))
        self.assertFalse(checks[1].sql.endswith(";"))

    def test_none_when_absent(self):
        self.assertEqual(coherence.read_checks(self.dir / "absent.yaml", "fx-core"), [])

    def test_a_trailing_semicolon_and_a_with_query(self):
        checks = self.read("checks:\n  - {id: a, what: one, sql: 'WITH x AS (SELECT 1) "
                           "SELECT * FROM x WHERE false;'}\n")
        self.assertEqual(checks[0].sql, "WITH x AS (SELECT 1) SELECT * FROM x WHERE false")
        self.assertEqual(checks[0].reads, [])

    def test_malformed_files_are_refused_with_every_problem(self):
        self.refused("checks: []\n", "not {checks: [...]}")
        self.refused("other: 1\nchecks: [{id: a, what: b, sql: SELECT 1}]\n", "not {checks")
        self.refused("checks:\n  - {id: A, what: b, sql: SELECT 1, extra: 1}\n"
                     "  - {id: b, what: '', sql: 'SELECT 1; SELECT 2'}\n"
                     "  - {id: b, what: x, sql: DELETE FROM t}\n"
                     "  - {id: c, what: x, sql: SELECT 1, reads: fx-core}\n"
                     "  - {id: d, what: x, sql: SELECT 1, reads: [Bad]}\n",
                     "extra: not a key of a check", "id: 'A' is not a check id",
                     "what: not one line", "holds a `;`", "b twice", "does not start with "
                     "SELECT or WITH", "reads: not a list", "'Bad' is not a domain id")
        self.refused("checks:\n  - {id: a, what: b, sql: \"SELECT 1\\n\\\\gexec\"}\n",
                     "psql meta-command")
        self.refused("checks: [{id: a, what: b, sql: SELECT 1}]\nchecks: []\n", "cannot be read")

    def test_the_database_key_belongs_to_a_several_database_part(self):
        self.refused("checks: [{id: a, what: b, sql: SELECT 1, database: clinic}]\n",
                     "database is a several-database part's")
        self.refused("checks: [{id: a, what: b, sql: SELECT 1}]\n", "required on a several",
                     databases=["pacs", "vitals"])
        checks = self.read("checks: [{id: a, what: b, sql: SELECT 1, database: vitals}]\n",
                           databases=["pacs", "vitals"])
        self.assertEqual(checks[0].database, "vitals")

    def test_a_check_reading_the_partners_takes_no_database(self):
        """Spec D383: it runs in partners on the partners' node."""
        for databases in (None, ["pacs", "vitals"]):
            with self.subTest(databases=databases):
                self.refused("checks: [{id: a, what: b, sql: SELECT 1, database: vitals, "
                             "reads: [fx-ward, partners]}]\n",
                             "checks[a].database: refused on a check reading partners",
                             databases=databases)
                checks = self.read("checks: [{id: a, what: b, sql: SELECT 1, "
                                   "reads: [fx-ward, partners]}]\n", databases)
                self.assertIsNone(checks[0].database)


class TestQueryAndAnswer(unittest.TestCase):

    def test_the_query_is_read_only_and_counts_its_rows(self):
        sql = coherence.query_sql(coherence.Check("d", "c", "w", "SELECT 1 AS one"))
        self.assertTrue(sql.startswith("BEGIN TRANSACTION READ ONLY;\nWITH gm_rows AS (\n"
                                       "SELECT 1 AS one\n)"))
        self.assertIn(f"LIMIT {coherence.FIRST_ROWS}", sql)
        self.assertTrue(sql.endswith("COMMIT;\n"))

    def test_the_answer(self):
        self.assertEqual(coherence.parse_answer(['{"count" : 0, "rows" : []}'], "w"), (0, []))
        self.assertEqual(coherence.parse_answer(['{"count" : 2, "rows" : [{"id":1},{"id":2}]}'],
                                                "w"), (2, [{"id": 1}, {"id": 2}]))
        for lines in ([], ["ERROR"], ['{"count": "x"}']):
            with self.assertRaises(GmError):
                coherence.parse_answer(lines, "w")

    def test_the_failure_names_domain_check_what_count_and_rows(self):
        outcomes = [coherence.Outcome("fx-ward", "stays-placed", "every current stay placed",
                                      coherence.FAIL, 12, [{"stay_id": 5000 + i}
                                                           for i in range(1, 11)]),
                    coherence.Outcome("fx-docs", "x", "y", coherence.PASS)]
        text = coherence.failure_text(outcomes)
        self.assertIn("failed on 1 check(s): a design error", text)
        self.assertIn("fx-ward stays-placed (every current stay placed): 12 row(s); first 10:",
                      text)
        self.assertIn('{"stay_id": 5001}', text)
        self.assertNotIn("fx-docs", text)
        self.assertEqual(coherence.result_of(outcomes), coherence.FAIL)
        self.assertEqual(outcomes[0].record()["rows"], 12)
        self.assertNotIn("rows", outcomes[1].record())


class TestRecord(unittest.TestCase):

    TEXT = ("# a comment\ndomains:\n  - {id: a, variant: v, at: n/d}\n"
            "order: [a]   # kept\n")

    def test_appended_when_absent(self):
        new = coherence.rewrite_record(self.TEXT, "2026-11-04T09:30:00Z", "pass")
        self.assertEqual(new, self.TEXT + "coherence: {run_at: '2026-11-04T09:30:00Z', "
                                          "result: pass}\n")
        self.assertEqual(coherence.rewrite_record(self.TEXT.rstrip("\n"), "t", "pass"),
                         self.TEXT + "coherence: {run_at: 't', result: pass}\n")

    def test_replaced_in_block_or_flow_form_every_other_line_kept(self):
        block = self.TEXT.replace("order:", "coherence:\n  run_at: <setup time>\n"
                                            "  result: <pass>\norder:")
        new = coherence.rewrite_record(block, "t", "fail")
        self.assertEqual(new, self.TEXT.replace("order:", "coherence: {run_at: 't', result: "
                                                          "fail}\norder:"))
        flow = coherence.rewrite_record(new, "u", "pass")
        self.assertEqual(flow, new.replace("{run_at: 't', result: fail}",
                                           "{run_at: 'u', result: pass}"))

    def test_the_file(self):
        tmp = Path(tempfile.mkdtemp(prefix="gmtest-record."))
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        path = tmp / "composition.yaml"
        path.write_text(self.TEXT)
        coherence.record_composition(path, "2026-11-04T09:30:00Z", "pass")
        self.assertEqual(model.strict_load(path.read_text())["coherence"],
                         {"run_at": "2026-11-04T09:30:00Z", "result": "pass"})
        self.assertTrue(path.read_text().startswith(self.TEXT))
        path.write_text("coherence: &x {result: pass}\nother: *x\n")   # an alias of it
        with self.assertRaises(GmError):
            coherence.record_composition(path, "t", "pass")


# --- The composed plan --------------------------------------------------------

class TestComposedPlan(unittest.TestCase):

    def setUp(self):
        self.fixture = fixture_copy(self)
        self.catalog = self.fixture / "catalog"
        self.scenario = scenario_of(self.fixture)
        self.impl = impl_of(self.scenario)

    def plan(self):
        return inject.composed_plan(self.scenario, self.impl, self.catalog)

    def test_no_domains_no_plan(self):
        self.scenario.data.pop("domains")
        plan = self.plan()
        self.assertEqual((plan.domains, plan.checks, plan.composition), ([], [], None))

    def test_the_order_is_the_composition_records(self):
        plan = self.plan()
        self.assertEqual([d.domain for d in plan.domains], ["fx-core", "fx-docs", "fx-ward"])
        self.assertEqual([d.databases for d in plan.domains],
                         [[("records", "clinic")], [("records", "docs")], [("records", "clinic")]])

    def test_the_keys_ahead_of_each_load_partner_file_and_derivation_never_a_schema(self):
        plan = self.plan()
        keys = self.catalog / "domains/fx-core/data/keys.sql"
        docs_keys = self.catalog / "domains/fx-docs/data/keys.sql"
        runs = [r for d in plan.domains for r in d.runs]
        self.assertEqual([(r.what, r.node, r.database) for r in runs], [
            ("fx-core data/schema.sql", "records", "clinic"),
            ("fx-core data/load.sql", "records", "clinic"),
            ("fx-core producers/partners/xlab/data.sql", "partners-db", "partners"),
            ("fx-docs data/schema.sql", "records", "docs"),
            ("fx-docs data/load.sql", "records", "docs"),
            ("fx-ward data/schema.sql", "records", "clinic"),
            ("fx-ward data/load.sql", "records", "clinic"),
            ("fx-ward data/cron.sql", "records", "office")])
        for run in runs:
            self.assertEqual(run.paths[0] == keys, run.what.endswith("load.sql")
                             or "partners" in run.what, run.what)
        # chunk 29's (a): a part's own keys after the core's, for that part only
        self.assertEqual([r.paths for r in runs if r.what == "fx-docs data/load.sql"],
                         [[keys, docs_keys, self.catalog / "domains/fx-docs/data/load.sql"]])
        self.assertEqual([r.paths for r in runs if r.what == "fx-ward data/load.sql"],
                         [[keys, self.catalog / "domains/fx-ward/data/load.sql"]])
        self.assertEqual(plan.domains[0].partners, [("xlab", "partners-db")])
        derive, = plan.derivations
        self.assertEqual(derive.paths, [keys, docs_keys,
                                        self.catalog / "domains/fx-docs/data/derive.sql"])
        self.assertEqual((derive.node, derive.database), ("records", "docs"))
        self.assertEqual(derive.sources, [inject.Source("fx_core", "records", "clinic")])

    def test_a_core_without_keys(self):
        (self.catalog / "domains/fx-core/data/keys.sql").unlink()
        (self.catalog / "domains/fx-docs/data/keys.sql").unlink()
        plan = self.plan()
        self.assertEqual([len(r.paths) for d in plan.domains for r in d.runs], [1] * 8)

    def test_a_parts_keys_ahead_of_its_partner_files_never_another_parts(self):
        """Chunk 29's (a): a part's data/keys.sql streamed after the core's,
        ahead of that part's load, partner data.sql and derivation, never a
        schema's, a cron file's, another domain's or a history's."""
        keys = self.catalog / "domains/fx-core/data/keys.sql"
        docs_keys = self.catalog / "domains/fx-docs/data/keys.sql"
        partner = self.catalog / "domains/fx-docs/producers/partners/ylab"
        partner.mkdir(parents=True)
        (partner / "data.sql").write_text("SELECT pg_temp.docs_request(1);\n")
        plan = self.plan()
        runs = {r.what: r.paths for d in plan.domains for r in d.runs}
        self.assertEqual(runs["fx-docs producers/partners/ylab/data.sql"],
                         [keys, docs_keys, partner / "data.sql"])
        self.assertEqual(runs["fx-core producers/partners/xlab/data.sql"],
                         [keys, self.catalog / "domains/fx-core/producers/partners/xlab/data.sql"])
        self.assertEqual(runs["fx-ward data/cron.sql"],
                         [self.catalog / "domains/fx-ward/data/cron.sql"])
        for what, paths in runs.items():
            self.assertEqual(docs_keys in paths, what.startswith("fx-docs ")
                             and not what.endswith("schema.sql"), what)
        self.assertNotIn(docs_keys, plan.histories[0].paths)

    def test_a_left_out_partner_runs_with_the_partners_database(self):
        """Chunk 29's (b): a left-out partner folder's data.sql still runs
        when the scenario has a partners' database."""
        record = self.scenario.dir / "composition.yaml"
        record.write_text(record.read_text() + "  - {domain: fx-core, producer: partners/xlab, "
                          "reason: no partner nodes}\n")
        plan = self.plan()
        self.assertEqual(plan.domains[0].partners, [("xlab", "partners-db")])
        self.assertIn("fx-core producers/partners/xlab/data.sql",
                      [r.what for r in plan.domains[0].runs])

    def test_a_left_out_partner_skipped_without_the_partners_database(self):
        """Chunk 29's (b): skipped, the refusal not applying; its check
        reading partners skipped, as before."""
        record = self.scenario.dir / "composition.yaml"
        record.write_text(record.read_text() + "  - {domain: fx-core, producer: partners/xlab, "
                          "reason: no partner nodes}\n")
        self.scenario.data.pop("third_parties")
        plan = self.plan()
        self.assertEqual(plan.domains[0].partners, [])
        self.assertNotIn("partners", " ".join(r.what for d in plan.domains for r in d.runs))
        self.assertEqual([(c.check.id, c.skipped) for c in plan.checks if c.skipped],
                         [("requests-on-current-stays",
                           "reads partners: the game has no partners' database")])

    def test_the_cron_file_last_of_its_domain_in_cron_database_name(self):
        """Chunk 29's (d): data/cron.sql on the domain's node, connected to
        its seed's cron.database_name (pg_cron's default, postgres, unset),
        after its load, no keys ahead."""
        ward = next(d for d in self.plan().domains if d.domain == "fx-ward")
        self.assertEqual([(r.what, r.node, r.database) for r in ward.runs][-1],
                         ("fx-ward data/cron.sql", "records", "office"))
        conf = self.scenario.dir / "nodes/records/postgresql.conf"
        conf.write_text(conf.read_text().replace("cron.database_name = 'office'\n", ""))
        ward = next(d for d in self.plan().domains if d.domain == "fx-ward")
        self.assertEqual(ward.runs[-1].database, "postgres")

    def test_the_history_in_its_target_reading_its_other_location_parts(self):
        history, = self.plan().histories
        self.assertEqual((history.owner, history.node, history.database),
                         ("fx-weekly", "records", "office"))
        self.assertEqual(history.sources, [inject.Source("source", "records", "clinic")])
        self.assertEqual(history.paths, [self.catalog / "purposes/fx-weekly/material/history.sql"])

    def test_the_checks_and_their_sources(self):
        plan = self.plan()
        found = {(c.check.domain, c.check.id): c for c in plan.checks}
        self.assertEqual(list(found), [("fx-docs", "documents-match-stays"),
                                       ("fx-docs", "placed-stays-documented"),
                                       ("fx-ward", "placements-on-stays"),
                                       ("fx-ward", "stays-placed"),
                                       ("fx-ward", "requests-on-current-stays")])
        requests = found[("fx-ward", "requests-on-current-stays")]
        # Spec D383: a check reading partners runs in partners on the partners' node.
        self.assertEqual((requests.node, requests.database), ("partners-db", "partners"))
        self.assertEqual(requests.sources, [inject.Source("fx_core", "records", "clinic"),
                                            inject.Source("partners", "partners-db", "partners")])
        for other in ("placements-on-stays", "stays-placed"):
            self.assertEqual((found[("fx-ward", other)].node, found[("fx-ward", other)].database),
                             ("records", "clinic"))
        self.assertEqual(plan.reading_nodes(), {"records": ["clinic"],
                                                "partners-db": ["partners"]})

    def test_a_partners_check_of_a_several_database_part_runs_on_the_partners_node(self):
        """No database: on it (refused there), none required: it runs in
        partners, its own part read through reads (spec D383)."""
        domain = self.catalog / "domains/fx-docs/domain.yaml"
        data = yaml.safe_load(domain.read_text())
        data["databases"] = ["docs", "archive"]
        domain.write_text(yaml.safe_dump(data))
        entry = next(d for d in self.scenario.data["domains"] if d["id"] == "fx-docs")
        entry["at"] = {"docs": "records/docs", "archive": "records/archive"}
        record = self.scenario.dir / "composition.yaml"   # a several-database part: no derive
        record.write_text(record.read_text().split("derive:")[0])
        (self.catalog / "domains/fx-docs/data/coherence.yaml").write_text(
            "checks:\n  - id: requests-known\n    what: every partner request on a document\n"
            "    reads: [fx-docs, partners]\n"
            "    sql: SELECT r.stay_id FROM gm_src_partners_xlab.requests r WHERE NOT EXISTS "
            "(SELECT 1 FROM gm_src_fx_docs_docs.doc_requests d WHERE d.stay_id = r.stay_id)\n")
        check = coherence.read_checks(self.catalog / "domains/fx-docs/data/coherence.yaml",
                                      "fx-docs", data["databases"])[0]
        self.assertIsNone(check.database)
        for db in data["databases"]:
            (self.catalog / "domains/fx-docs/data" / db).mkdir()
            for name in ("schema.sql", "load.sql"):
                shutil.copy(self.catalog / "domains/fx-docs/data" / name,
                            self.catalog / "domains/fx-docs/data" / db / name)
        plans = self.plan()
        run = next(c for c in plans.checks if c.check.id == "requests-known")
        self.assertEqual((run.node, run.database, run.skipped), ("partners-db", "partners", None))
        self.assertEqual(run.sources, [inject.Source("fx_docs_docs", "records", "docs"),
                                       inject.Source("fx_docs_archive", "records", "archive"),
                                       inject.Source("partners", "partners-db", "partners")])

    def test_a_history_reading_the_partners_from_another_node_is_refused(self):
        entry = next(p for p in self.scenario.data["purposes"] if p["id"] == "fx-weekly")
        entry["parts"]["source"] = "partners-db/partners"
        with self.assertRaises(GmError) as cm:
            self.plan()
        self.assertIn("scenario.yaml: purposes[fx-weekly]: reads partners-db/partners "
                      "(gm_src_source) from records", str(cm.exception))
        self.assertIn("over its own socket only", str(cm.exception))

    def test_a_derivation_reading_the_partners_from_another_node_is_refused(self):
        self.scenario.data["domains"][0]["at"] = "partners-db/partners"
        with self.assertRaises(GmError) as cm:
            self.plan()
        self.assertIn("composition.yaml: derive[fx-docs]: reads partners-db/partners "
                      "(gm_src_fx_core) from records", str(cm.exception))

    def test_a_check_reading_a_domain_not_composed_is_skipped(self):
        self.scenario.data["domains"] = [d for d in self.scenario.data["domains"]
                                         if d["id"] != "fx-ward"]
        path = self.scenario.dir / "composition.yaml"
        path.write_text(path.read_text().replace("order: [fx-core, fx-docs, fx-ward]",
                                                 "order: [fx-core, fx-docs]"))
        plan = self.plan()
        skipped = [(c.check.id, c.skipped, c.sources) for c in plan.checks if c.skipped]
        self.assertEqual(skipped, [("placed-stays-documented", "reads fx-ward, not composed", [])])

    def test_a_check_reading_the_partners_without_them_is_skipped(self):
        (self.catalog / "domains/fx-core/producers/partners/xlab/data.sql").unlink()
        self.scenario.data.pop("third_parties")
        plan = self.plan()
        skipped = [(c.check.id, c.skipped) for c in plan.checks if c.skipped]
        self.assertEqual(skipped, [("requests-on-current-stays",
                                    "reads partners: the game has no partners' database")])

    def test_refusals_before_anything_runs(self):
        cases = []

        def case(change, *fragments):
            cases.append((change, fragments))

        def no_partners_node(sc, cat):
            sc.data.pop("third_parties")
        case(no_partners_node, "producers/partners/xlab/data.sql: a partner's state",
             "lists a database node holding partners")

        def standby_location(sc, cat):
            sc.nodes.append({"name": "standby", "role": "database", "standby_of": "records"})
            sc.data["domains"][2]["at"] = "standby/docs"
        case(standby_location, "domains[fx-docs].at: standby is a standby")

        def unknown_read(sc, cat):
            path = cat / "domains/fx-ward/data/coherence.yaml"
            path.write_text(path.read_text().replace("reads: [fx-core, partners]",
                                                     "reads: [fx-nowhere]"))
        case(unknown_read, "reads: fx-nowhere is not a domain of the catalogue")

        def malformed_checks(sc, cat):
            (cat / "domains/fx-docs/data/coherence.yaml").write_text("checks: {}\n")
        case(malformed_checks, "domains/fx-docs/data/coherence.yaml: not {checks")

        def schema_switching_database(sc, cat):
            path = cat / "domains/fx-ward/data/schema.sql"
            path.write_text(path.read_text() + "\\connect other\n")
        case(schema_switching_database, "domains/fx-ward/data/schema.sql:10",
             "never create one or \\connect to one")

        def left_out_another_producer(sc, cat):
            sc.data.pop("third_parties")        # left_out names fx-docs desk, not xlab
        case(left_out_another_producer, "producers/partners/xlab/data.sql: a partner's state")

        def cron_without_preload(sc, cat):
            conf = sc.dir / "nodes/records/postgresql.conf"
            conf.write_text(conf.read_text().replace(",pg_cron", ""))
        case(cron_without_preload, "domains/fx-ward/data/cron.sql: schedules pg_cron jobs on "
             "node records, which does not preload pg_cron")

        def cron_without_seed(sc, cat):
            sc.nodes[0].pop("seed_files")
        case(cron_without_seed, "which does not preload pg_cron (its seed postgresql.conf "
             "absent")

        def cron_file_with_more(sc, cat):
            path = cat / "domains/fx-ward/data/cron.sql"
            path.write_text(path.read_text() + "DELETE FROM cron.job;\n")
        case(cron_file_with_more, "domains/fx-ward/data/cron.sql:7: DELETE FROM cron.job: a "
             "cron.sql holds SELECT cron.schedule_in_database(...) calls only")

        def cron_on_two_nodes(sc, cat):
            shutil.copy(cat / "domains/fx-ward/data/cron.sql", cat / "domains/fx-docs/data")
            sc.nodes.append({"name": "archive", "role": "database"})
            self.impl["nodes"]["archive"] = {}
            path = cat / "domains/fx-docs/domain.yaml"
            data = yaml.safe_load(path.read_text())
            data["databases"] = ["docs", "old"]
            path.write_text(yaml.safe_dump(data))
            for db in data["databases"]:
                (cat / "domains/fx-docs/data" / db).mkdir()
                for name in ("schema.sql", "load.sql"):
                    shutil.copy(cat / "domains/fx-docs/data" / name,
                                cat / "domains/fx-docs/data" / db / name)
            sc.data["domains"][2]["at"] = {"docs": "records/docs", "old": "archive/old"}
            record = sc.dir / "composition.yaml"
            record.write_text(record.read_text().split("derive:")[0])
        case(cron_on_two_nodes, "domains/fx-docs/data/cron.sql: schedules pg_cron jobs on the "
             "domain's node, but its at: names 2 nodes (records, archive)")

        def load_creating_database(sc, cat):
            path = cat / "domains/fx-docs/data/load.sql"
            path.write_text("CREATE DATABASE docs;\n" + path.read_text())
        case(load_creating_database, "domains/fx-docs/data/load.sql:1")

        def partner_state_switching_database(sc, cat):
            path = cat / "domains/fx-core/producers/partners/xlab/data.sql"
            path.write_text(path.read_text() + "\\c partners\n")
        case(partner_state_switching_database,
             "domains/fx-core/producers/partners/xlab/data.sql:16: \\c partners: a partner's "
             "data.sql runs connected to the partners' database (psql -d <db>, named "
             ":\"DBNAME\"), never create one or \\connect to one")

        def partner_state_creating_database(sc, cat):
            path = cat / "domains/fx-core/producers/partners/xlab/data.sql"
            path.write_text("CREATE DATABASE xlab;\n" + path.read_text())
        case(partner_state_creating_database,
             "domains/fx-core/producers/partners/xlab/data.sql:1: CREATE DATABASE xlab;")

        def missing_derive(sc, cat):
            (cat / "domains/fx-docs/data/derive.sql").unlink()
        case(missing_derive, "domains/fx-docs/data/derive.sql: missing file")

        def missing_history(sc, cat):
            (cat / "purposes/fx-weekly/material/history.sql").unlink()
        case(missing_history, "purposes/fx-weekly/material/history.sql: missing file")

        def order_short(sc, cat):
            path = sc.dir / "composition.yaml"
            path.write_text(path.read_text().replace(", fx-ward]", "]"))
        case(order_short, "does not list every domain")

        def node_not_in_game(sc, cat):
            self.impl["nodes"].pop("partners-db")
        case(node_not_in_game, "node partners-db is not a node of game gmtest")
        for change, fragments in cases:
            with self.subTest(change.__name__):
                self.fixture = fixture_copy(self)
                self.catalog = self.fixture / "catalog"
                self.scenario = scenario_of(self.fixture)
                self.impl = impl_of(self.scenario)
                change(self.scenario, self.catalog)
                with self.assertRaises(GmError) as cm:
                    self.plan()
                for fragment in fragments:
                    self.assertIn(fragment, str(cm.exception))


# --- The runs, exec_node stubbed ------------------------------------------------

def answer_for(run):
    """The stub's answer to one psql run: the schemas' listing, a check's
    count, a database created."""
    stdin = run["stdin"]
    if stdin == inject.DATABASES_SQL:
        return 0, "[]\n", ""                      # the v0.4 survey: nothing to map
    if "FROM pg_catalog.pg_namespace" in stdin:
        return 0, '["public", "xlab"]\n' if run["argv"][-1] == "partners" else '["public"]\n', ""
    if "WITH gm_rows AS" in stdin:
        return 0, '{"count" : 0, "rows" : []}\n', ""
    if inject.CREATED_MARK in stdin:
        return 0, inject.CREATED_MARK + "\n", ""
    return 0, "", ""


class TestComposedSteps(unittest.TestCase):

    def setUp(self):
        self.fixture = fixture_copy(self)
        self.scenario = scenario_of(self.fixture)
        self.impl = impl_of(self.scenario)
        self.ldir = game_dir(self)
        self.runs = []
        self.answer = answer_for

    def exec_node(self, ldir, node, user, stdin=None, timeout=None, docker=None, argv=None,
                  env=None):
        if hasattr(stdin, "read"):
            stdin = stdin.read()
        if isinstance(stdin, bytes):
            stdin = stdin.decode()
        run = {"node": node, "user": user, "stdin": stdin, "argv": list(argv or ())}
        self.runs.append(run)
        code, out, err = self.answer(run)
        return execnode.ExecResult(node, user, f"{node}.ctr", code, out, err)

    def load(self):
        plans = inject.load_plans(self.scenario, self.impl, self.fixture / "catalog")
        write_role_secrets(self.ldir, plans)
        result = inject.LoadResult("gmtest")
        self.printed = []
        with mock.patch.object(inject, "exec_node", self.exec_node):
            inject.load_steps(self.ldir, plans, None, result, out=self.printed.append)
        return result

    def heads(self):
        """Each run as (node, database, what it streams, first)."""
        out = []
        for run in self.runs:
            db = run["argv"][-1] if run["argv"] else None
            out.append((run["node"], db, run["stdin"]))
        return out

    def test_the_steps_in_order(self):
        result = self.load()
        files = [(n, db) for n, db, _ in self.heads()]
        stdin = [s for _, _, s in self.heads()]
        index = {}
        for i, text in enumerate(stdin):
            for name, fragment in (("records.sql", "records' data file"),
                                   ("partners-db.sql", "partners-db's data file"),
                                   ("core schema", "The test core's schema"),
                                   ("core load", "The test core's load"),
                                   ("xlab", "The external lab's state"),
                                   ("docs schema", "CREATE TABLE doc_requests"),
                                   ("docs load", "a request per stay"),
                                   ("ward schema", "CREATE TABLE ward_placements"),
                                   ("ward load", "each current stay placed"),
                                   ("derive", "The test part's derivation"),
                                   ("history", "fx-weekly's history"),
                                   ("grant", "GRANT CONNECT ON DATABASE %I")):
                if fragment in text:
                    index.setdefault(name, i)
        order = sorted(index, key=index.get)
        self.assertEqual(order, ["records.sql", "partners-db.sql", "core schema", "core load",
                                 "xlab", "docs schema", "docs load", "ward schema", "ward load",
                                 "derive", "history", "grant"])
        self.assertEqual(files[index["xlab"]], ("partners-db", "partners"))
        self.assertEqual(files[index["docs load"]], ("records", "docs"))
        self.assertEqual(result.created, [("records", "clinic"), ("records", "docs"),
                                          ("records", "clinic")])
        self.assertEqual(result.partners, [("fx-core", "xlab", "partners-db")])
        self.assertEqual(result.derived, [("fx-docs", "records", "docs")])
        self.assertEqual(result.histories, [("fx-weekly", "records", "office")])
        self.assertEqual(result.coherence_result, "pass")
        text = result.text()
        self.assertIn("records/docs: database created for the domains, CONNECT revoked", text)
        self.assertIn("partners-db/partners: partner xlab's state (fx-core)", text)
        self.assertIn("coherence check: pass (5 passed, 0 failed, 0 skipped", text)

    def test_every_file_gets_one_load_epoch(self):
        self.load()
        epochs = {arg for run in self.runs for arg in run["argv"]
                  if arg.startswith(inject.EPOCH_VAR + "=")}
        self.assertEqual(len(epochs), 1)
        self.assertRegex(epochs.pop(), r"^load_epoch=\d{4}-\d\d-\d\dT\d\d:\d\dZ$")
        loads = [r for r in self.runs if "The test core's load" in r["stdin"]
                 or "fx-weekly's history" in r["stdin"]]
        self.assertEqual(len(loads), 2)
        for run in loads:
            self.assertTrue(any(a.startswith("load_epoch=") for a in run["argv"]))

    def test_the_keys_in_the_session_of_each_load_never_a_schema(self):
        self.load()
        keys = (FIXTURE / "catalog/domains/fx-core/data/keys.sql").read_text()
        for run in self.runs:
            if any(f in run["stdin"] for f in ("The test core's load", "The external lab's state",
                                               "a request per stay", "each current stay placed",
                                               "The test part's derivation")):
                self.assertIn(keys, run["stdin"])
            elif "schema (tools/tests" in run["stdin"] or "fx-weekly's history" in run["stdin"]:
                self.assertNotIn("pg_temp.core_stay(n integer)", run["stdin"])
        load = next(r for r in self.runs if "The test core's load" in r["stdin"])
        self.assertTrue(load["stdin"].startswith(inject.UNSEEN_SQL + keys))

    def test_each_domain_file_and_partner_file_unseen_never_a_data_file(self):
        # Master spec 9.2 (spec D265): schema.sql then load.sql run unseen,
        # the partners' files as well; v0.4's node data files as before.
        self.load()
        domain = [r for r in self.runs if any(f in r["stdin"] for f in (
            "The test core's schema", "The test core's load", "The external lab's state",
            "CREATE TABLE doc_requests", "a request per stay", "CREATE TABLE ward_placements",
            "each current stay placed"))]
        self.assertEqual(len(domain), 7)            # 3 schemas, 3 loads, 1 partner file
        for run in domain:
            self.assertTrue(run["stdin"].startswith(inject.UNSEEN_SQL), run["stdin"][:200])
            for line in ("SET log_statement = 'none';", "SET log_min_duration_statement = -1;",
                         "SET log_min_error_statement = 'panic';", "SET log_temp_files = -1;",
                         "SET pgaudit.log = 'none';", "SET pg_stat_statements.track = 'none';"):
                self.assertEqual(run["stdin"].count(line), 1, line)
            self.assertNotRegex(run["stdin"], r"(?m)^\\c(onnect)?\b")   # one session throughout
        schema = next(r for r in domain if "CREATE TABLE ward_placements" in r["stdin"])
        self.assertLess(schema["stdin"].index("SET log_statement = 'none';"),
                        schema["stdin"].index("CREATE EXTENSION IF NOT EXISTS btree_gist;"))
        created = [r for r in self.runs if inject.CREATED_MARK in r["stdin"]]
        self.assertEqual(len(created), 3)
        for run in created:
            text = run["stdin"]
            self.assertTrue(text.startswith(inject.UNSEEN_SQL), text[:200])
            self.assertLess(text.index("\\gset"), text.index("CREATE DATABASE"))
            self.assertEqual(run["argv"], list(inject.PSQL_ARGV))
        for fragment in ("records' data file", "partners-db's data file"):
            run = next(r for r in self.runs if fragment in r["stdin"])
            self.assertNotIn("SET log_statement", run["stdin"])

    def test_the_derivation_history_and_checks_unseen_their_sources_dropped(self):
        self.load()
        sourced = [r for r in self.runs if "gm_src_" in r["stdin"]
                   and "pg_namespace" not in r["stdin"]]
        self.assertEqual(len(sourced), 7)            # the derivation, the history, 5 checks
        for run in sourced:
            text = run["stdin"]
            self.assertTrue(text.startswith(inject.UNSEEN_SQL), text[:200])
            for line in ("SET log_statement = 'none';", "SET log_temp_files = -1;",
                         "SET pgaudit.log = 'none';", "SET pg_stat_statements.track = 'none';"):
                self.assertIn(line, text)
            for server in re.findall(r"CREATE SERVER \"(gm_src_[a-z_]+)\"", text):
                self.assertIn(f'DROP SERVER IF EXISTS "{server}" CASCADE;', text)
                self.assertIn(f'DROP SCHEMA IF EXISTS "{server}" CASCADE;', text)
            self.assertIn("OPTIONS (user 'gm_check', password 'Gm-check-secret-c8')", text)
            self.assertLess(text.index("CREATE EXTENSION IF NOT EXISTS postgres_fdw"),
                            text.index("IMPORT FOREIGN SCHEMA"))
            self.assertTrue(text.rstrip().endswith("\\if :gm_fdw_absent\nDROP EXTENSION IF "
                                                   "EXISTS postgres_fdw;\n\\endif"))
        derive = next(r for r in sourced if "derivation" in r["stdin"])
        self.assertIn("OPTIONS (host '/run/postgresql', port '5432', dbname 'clinic')",
                      derive["stdin"])
        requests = next(r for r in sourced if "gm_src_partners_xlab.requests" in r["stdin"])
        # Spec D383: on the partners' node, partners over its socket, the core over TCP.
        self.assertEqual((requests["node"], requests["argv"][-1]), ("partners-db", "partners"))
        self.assertIn('CREATE SERVER "gm_src_partners" FOREIGN DATA WRAPPER postgres_fdw OPTIONS '
                      "(host '/run/postgresql', port '5432', dbname 'partners')", requests["stdin"])
        self.assertIn('CREATE SERVER "gm_src_fx_core" FOREIGN DATA WRAPPER postgres_fdw OPTIONS '
                      "(host 'records', port '5432', dbname 'clinic')", requests["stdin"])
        self.assertIn('IMPORT FOREIGN SCHEMA "xlab" FROM SERVER "gm_src_partners" INTO '
                      '"gm_src_partners_xlab";', requests["stdin"])
        self.assertIn("BEGIN TRANSACTION READ ONLY;", requests["stdin"])
        self.assertIn("-A", requests["argv"])

    def test_the_check_roles_settings_set_before_the_reads_and_reset_after(self):
        self.load()
        stdin = [r["stdin"] for r in self.runs]
        sets = [i for i, s in enumerate(stdin) if "ALTER ROLE gm_check SET" in s]
        resets = [i for i, s in enumerate(stdin) if "ALTER ROLE gm_check RESET" in s]
        sourced = [i for i, s in enumerate(stdin) if "CREATE SERVER" in s]
        self.assertEqual([self.runs[i]["node"] for i in sets], ["records", "partners-db"])
        self.assertEqual([self.runs[i]["node"] for i in resets], ["records", "partners-db"])
        self.assertLess(max(sets), min(sourced))
        self.assertGreater(min(resets), max(sourced))
        on_records = stdin[sets[0]]
        for name, value in inject.CHECK_ROLE_SETTINGS:
            self.assertIn(f"ALTER ROLE gm_check SET {name} = '{value}';", on_records)
            self.assertIn(f"ALTER ROLE gm_check RESET {name};", stdin[resets[0]])
        self.assertIn("ALTER ROLE gm_check SET log_temp_files = '-1';", on_records)
        self.assertIn('GRANT CONNECT ON DATABASE "clinic" TO gm_check;', on_records)
        self.assertTrue(on_records.startswith(inject.UNSEEN_SQL))

    def test_the_record_in_the_composition_and_the_state(self):
        self.load()
        record = model.strict_load((self.scenario.dir / "composition.yaml").read_text())
        self.assertEqual(record["coherence"]["result"], "pass")
        st = localimpl.read_state(self.ldir)["coherence"]
        self.assertEqual(st["result"], "pass")
        self.assertEqual(st["run_at"], record["coherence"]["run_at"])
        self.assertEqual([(c["domain"], c["check"], c["result"]) for c in st["checks"]][:2],
                         [("fx-docs", "documents-match-stays", "pass"),
                          ("fx-docs", "placed-stays-documented", "pass")])
        self.assertEqual(model.check_composition(self.scenario.data, self.scenario.dir,
                                                 self.fixture / "catalog")
                         .count("composition.yaml: coherence"), 0)

    def test_a_failing_check_stops_with_the_offending_rows(self):
        def answer(run):
            if "WITH gm_rows AS" in run["stdin"] and "NOT EXISTS (SELECT 1 FROM ward_placements" \
                    in run["stdin"]:
                return 0, json.dumps({"count": 2, "rows": [{"stay_id": 5001},
                                                           {"stay_id": 5002}]}) + "\n", ""
            return answer_for(run)
        self.answer = answer
        with self.assertRaises(GmError) as cm:
            self.load()
        text = str(cm.exception)
        self.assertIn("fx-ward stays-placed (every current stay placed in a unit): 2 row(s)", text)
        self.assertIn('{"stay_id": 5001}', text)
        self.assertIn("a design error, never a fault", text)
        self.assertFalse(any("ALTER ROLE gm_check RESET" in r["stdin"] for r in self.runs))
        self.assertEqual(localimpl.read_state(self.ldir)["coherence"]["result"], "fail")
        record = model.strict_load((self.scenario.dir / "composition.yaml").read_text())
        self.assertEqual(record["coherence"]["result"], "fail")

    def test_a_failed_sourced_run_shows_no_password(self):
        def answer(run):
            if "The test part's derivation" in run["stdin"]:
                return 3, "", ("psql:<stdin>:12: ERROR:  could not connect\nLINE 1: CREATE USER "
                               "MAPPING ... password 'Gm-check-secret-c8'\n")
            return answer_for(run)
        self.answer = answer
        with self.assertRaises(GmError) as cm:
            self.load()
        self.assertIn("derive fx-docs data/derive.sql in records/docs", str(cm.exception))
        self.assertNotIn(GM_CHECK_PASSWORD, str(cm.exception))
        self.assertNotIn(GM_CHECK_PASSWORD, "\n".join(self.printed))

    def test_a_database_present_is_not_created(self):
        def answer(run):
            if inject.CREATED_MARK in run["stdin"]:
                return 0, "", ""
            return answer_for(run)
        self.answer = answer
        self.assertEqual(self.load().created, [])
        run = next(r for r in self.runs if inject.CREATED_MARK in r["stdin"])
        self.assertIn('CREATE DATABASE "clinic" OWNER postgres;\nREVOKE CONNECT ON DATABASE '
                      '"clinic" FROM PUBLIC;', run["stdin"])
        self.assertEqual(run["argv"], list(inject.PSQL_ARGV))

    def test_a_parts_keys_in_its_load_session_after_the_cores(self):
        """Chunk 29's (a): one session, the core's keys, then the part's."""
        self.load()
        core = (FIXTURE / "catalog/domains/fx-core/data/keys.sql").read_text()
        part = (FIXTURE / "catalog/domains/fx-docs/data/keys.sql").read_text()
        for fragment in ("a request per stay", "The test part's derivation"):
            run = next(r for r in self.runs if fragment in r["stdin"])
            self.assertIn(core + part, run["stdin"], fragment)
        for run in self.runs:
            if any(f in run["stdin"] for f in ("each current stay placed", "The test core's load",
                                               "The external lab's state", "fx-weekly's history",
                                               "CREATE TABLE doc_requests")):
                self.assertNotIn("pg_temp.docs_request", run["stdin"])

    def test_the_cron_file_after_its_domains_load_unseen_in_cron_database_name(self):
        """Chunk 29's (d): on records, -d office (its cron.database_name),
        after fx-ward's load and before the derivations, unseen, no keys."""
        result = self.load()
        stdin = [r["stdin"] for r in self.runs]
        cron = next(i for i, s in enumerate(stdin) if "cron.schedule_in_database" in s)
        ward = next(i for i, s in enumerate(stdin) if "each current stay placed" in s)
        derive = next(i for i, s in enumerate(stdin) if "The test part's derivation" in s)
        self.assertLess(ward, cron)
        self.assertLess(cron, derive)
        run = self.runs[cron]
        self.assertEqual((run["node"], run["user"], run["argv"][-2:]),
                         ("records", "postgres", ["-d", "office"]))
        self.assertTrue(run["stdin"].startswith(inject.UNSEEN_SQL))
        self.assertNotIn("pg_temp.core_", run["stdin"])
        self.assertIn(("fx-ward", "records", "office", "fx-ward data/cron.sql"), result.domains)
        self.assertIn("records/office: fx-ward data/cron.sql", result.text())

    def test_a_scenario_without_domains_runs_no_composed_step(self):
        self.scenario.data.pop("domains")
        result = self.load()
        self.assertFalse(any("gm_src_" in r["stdin"] or inject.CREATED_MARK in r["stdin"]
                             for r in self.runs))
        self.assertIsNone(result.coherence_result)


class TestFixtureChecks(unittest.TestCase):
    """The fixture's catalogue and composition pass the loader's own checks
    (chunk 6's, W2-a): each domain folder and the composition record."""

    def test_check_domain_dir_is_clean_on_each_domain(self):
        domains = sorted(p for p in (CATALOG / "domains").iterdir() if p.is_dir())
        self.assertEqual([p.name for p in domains], ["fx-core", "fx-docs", "fx-ward"])
        for domain_dir in domains:
            with self.subTest(domain=domain_dir.name):
                self.assertEqual(model.check_domain_dir(domain_dir), [])

    def test_check_composition_is_clean(self):
        data = yaml.safe_load((FIXTURE / "scenario" / "scenario.yaml").read_text())
        self.assertEqual(model.check_composition(data, FIXTURE / "scenario", CATALOG), [])


class TestPasswordPlanReadsNodeCreates(unittest.TestCase):
    """password_plan places a role connecting through another node (a
    pooler) on the database nodes where its database is created, as
    model.node_creates reads them from the catalogue load_plans passes
    (W2 item 1, spec D360): a composed domain's at: database included; and
    takes the login roles the domains and the partner file create from the
    same catalogue (localimpl.data_login_roles, chunk 7)."""

    def setUp(self):
        self.scenario = scenario_of(FIXTURE)
        self.impl = impl_of(self.scenario)
        self.target = None

    def connections(self):
        conns = {"web": {"role": "docs_web", "target": self.target}} if self.target else {}
        return mock.patch.object(localimpl, "node_connections",
                                 lambda s, node: conns if node["name"] == "records" else {})

    def plan(self, catalog_root, target=None):
        self.target = target
        with self.connections():
            return {db: [r for r, _ in roles]
                    for db, roles in inject.password_plan(self.scenario, self.impl, catalog_root)}

    def placed(self, target, catalog_root):
        """The nodes the connection's role, docs_web, is set on."""
        return sorted(db for db, roles in self.plan(catalog_root, target).items()
                      if "docs_web" in roles)

    def test_a_database_a_domain_creates_is_its_nodes(self):
        self.assertEqual(self.placed("pool:6432/docs", CATALOG), ["records"])
        self.assertEqual(self.placed("pool:6432/clinic", CATALOG), ["records"])

    def test_a_database_the_data_file_creates_is_its_nodes(self):
        self.assertEqual(self.placed("pool:6432/partners", CATALOG), ["partners-db"])
        self.assertEqual(self.placed("pool:6432/office", CATALOG), ["records"])

    def test_the_catalogue_is_the_one_passed(self):
        # The repository's catalogue holds no fx-docs: no node creates docs there.
        self.assertEqual(self.placed("pool:6432/docs", model.REPO_ROOT),
                         ["partners-db", "records"])

    def test_the_login_roles_the_catalogue_creates(self):
        self.assertEqual(self.plan(CATALOG), {"records": ["core_app", "ward_app", "docs_app"],
                                              "partners-db": ["xlab"]})
        self.assertEqual(self.plan(model.REPO_ROOT), {})

    def test_load_plans_passes_its_catalogue(self):
        self.target = "pool:6432/docs"
        with self.connections():
            plans = inject.load_plans(self.scenario, self.impl, CATALOG)
        self.assertEqual({db: [r for r, _ in roles] for db, roles in plans.passwords},
                         {"records": ["docs_web", "core_app", "ward_app", "docs_app"],
                          "partners-db": ["xlab"]})


class TestHelpers(unittest.TestCase):

    def test_load_epoch(self):
        from datetime import datetime, timedelta, timezone
        at = datetime(2026, 11, 4, 10, 15, 42, tzinfo=timezone(timedelta(hours=2)))
        self.assertEqual(inject.load_epoch(at), "2026-11-04T08:15Z")

    def test_stream_files_ends_each_with_a_newline(self):
        tmp = Path(tempfile.mkdtemp(prefix="gmtest-stream."))
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        (tmp / "a").write_bytes(b"SELECT 1;")
        (tmp / "b").write_bytes(b"")
        (tmp / "c").write_bytes(b"SELECT 2;\n")
        with inject.stream_files([tmp / "a", tmp / "b", tmp / "c"]) as fh:
            self.assertEqual(fh.read(), b"SELECT 1;\nSELECT 2;\n")
        with inject.stream_files([tmp / "a", tmp / "c"], inject.UNSEEN_SQL) as fh:
            self.assertEqual(fh.read(), inject.UNSEEN_SQL.encode() + b"SELECT 1;\nSELECT 2;\n")

    def test_data_argv_names_the_database(self):
        self.assertEqual(inject.data_argv({"a": "1"}, "clinic")[-4:], ("-v", "a=1", "-d", "clinic"))
        self.assertEqual(inject.read_argv("docs")[-2:], ("-d", "docs"))


# --- The composed test load, into throwaway containers ---------------------------

IMAGE = os.environ.get("GM_TEST_PG_IMAGE", "127.0.0.1:5000/dbagm/postgres:0.5.0")
PG_START = r"""set -eu
PGBIN=/usr/lib/postgresql/18/bin
install -d -o postgres -g postgres -m 0700 /run/gmtest/pgdata
install -d -o postgres -g postgres -m 0750 /run/gmtest/pglog
runuser -u postgres -- "$PGBIN/initdb" -D /run/gmtest/pgdata -U postgres -A peer -E UTF8 \
    --locale=C.UTF-8 --no-sync >/dev/null
if [ -n "${GM_HBA:-}" ]; then
    printf '%s\n' "$GM_HBA" > /run/gmtest/pgdata/pg_hba.conf
else
    cat > /run/gmtest/pgdata/pg_hba.conf <<'EOF'
local all gm_check scram-sha-256
local all all peer
host all gm_check samenet scram-sha-256
host all all all reject
EOF
fi
exec runuser -u postgres -- "$PGBIN/postgres" -D /run/gmtest/pgdata -c listen_addresses='*' \
    -c unix_socket_directories=/run/postgresql -c "shared_preload_libraries=$GM_LIBS" \
    -c logging_collector=on -c log_directory=/run/gmtest/pglog -c log_filename=postgresql.log \
    -c 'log_line_prefix=%m [%p] %u@%d ' -c log_statement=all -c log_min_duration_statement=0 \
    -c log_temp_files=0 \
    -c pg_stat_statements.track=all -c pg_stat_statements.track_utility=on \
    -c pgaudit.log=all -c fsync=off -c shared_buffers=32MB \
    ${GM_CRON_DB:+-c cron.database_name=$GM_CRON_DB}
"""
# records loads pgaudit (its trail in the log), partners-db does not (a
# placeholder setting there, as on a node whose seed leaves it off); records
# preloads pg_cron, its jobs in office, as its seed postgresql.conf says
# (chunk 29's (d)).
LIBS = {"records": "pg_stat_statements,pgaudit,pg_cron", "partners-db": "pg_stat_statements"}
CRON_DB = {"records": "office"}
PARTNERS_HBA = model.REPO_ROOT / "partners/shared/partners-db/pg_hba.conf"
_PARTNERS_LINE = re.compile(r"^(host\s+partners\s+)\S+(\s+samenet\s+scram-sha-256)$", re.M)


def partners_hba(catalog):
    """partners-db's seed pg_hba.conf as the GM fills it (partners/README.md,
    spec D383): the partners' line naming each composed partner's role (no
    vault here, so no coldstore), no gm_check host line."""
    roles = sorted(p.parent.name for p in catalog.glob("domains/*/producers/partners/*/data.sql"))
    text, n = _PARTNERS_LINE.subn(lambda m: m.group(1) + ",".join(roles) + m.group(2),
                                  PARTNERS_HBA.read_text(encoding="utf-8"))
    if n != 1 or not roles:
        raise AssertionError(f"{PARTNERS_HBA}: no partners' line to fill, or no partner")
    return text


# What the domains' files and the partner file send (their databases'
# creation included), none of it in a server's log or its statistics.
LOAD_FRAGMENTS = ('CREATE DATABASE "', "gm_absent", "pg_temp.core_", "INSERT INTO animals",
                  "INSERT INTO stays", "ward_placements", "doc_requests", "xlab.requests",
                  "xlab.state", "CREATE ROLE core_app", "CREATE ROLE ward_app",
                  "CREATE ROLE docs_app", "CREATE ROLE xlab", "btree_gist", "pgcrypto",
                  "pg_temp.docs_", "schedule_in_database", "fx-ward-tidy")
LOAD_STATEMENTS = (r"pg_temp\.(core|docs)_|ward_placements|doc_requests|xlab\.(requests|state)|"
                   r"INSERT INTO (animals|stays)|CREATE DATABASE \"|gm_absent|btree_gist|pgcrypto|"
                   r"fx-ward-tidy")     # not schedule_in_database: CREATE EXTENSION pg_cron's
                                        # own script, the data file's, is seen


@unittest.skipUnless(os.environ.get("GM_TEST_COMPOSED_LOAD") == "1",
                     "the composed test load (GM_TEST_COMPOSED_LOAD=1, under the host lock)")
class TestComposedLoad(unittest.TestCase):
    """The fixture loaded into two throwaway containers of the postgres
    image, on a network of their own, each named by its node: load-data's
    steps run with exec_node going through `docker exec`. partners-db on the
    partners' own pg_hba.conf (no gm_check host line, spec D383), so the
    check reading partners only passes on the partners' node."""

    def setUp(self):
        self.tag = f"gmtest-c8-{os.getpid()}-{len(self.id())}"
        self.network = self.tag
        self.containers = {name: f"{self.tag}-{name}" for name in LIBS}
        self.docker("network", "create", self.network)
        self.addCleanup(self.docker, "network", "rm", self.network, check=False)
        hba = {"partners-db": ["-e", f"GM_HBA={partners_hba(CATALOG)}"]}   # spec D383
        for name, container in self.containers.items():
            self.addCleanup(self.docker, "rm", "-f", container, check=False)
            cron = ["-e", f"GM_CRON_DB={CRON_DB[name]}"] if name in CRON_DB else []
            self.docker("run", "-d", "--name", container, "--network", self.network,
                        "--network-alias", name, "--memory", "512m", "-e", f"GM_LIBS={LIBS[name]}",
                        *hba.get(name, []), *cron, "--entrypoint", "sh", IMAGE, "-c", PG_START)
        for name in LIBS:
            self.wait_ready(name)
            self.psql(name, "postgres",                  # as the brick's entrypoint, unseen
                      inject.UNSEEN_SQL + f"CREATE ROLE gm_check LOGIN PASSWORD "
                      f"'{GM_CHECK_PASSWORD}'; GRANT pg_read_all_data TO gm_check;")

    def docker(self, *args, check=True, input=None):
        r = subprocess.run(["docker", *args], capture_output=True, text=True, input=input,
                           timeout=300)
        if check and r.returncode != 0:
            raise AssertionError(f"docker {' '.join(args[:3])}: {r.stderr.strip()}")
        return r

    def wait_ready(self, name, bound=60):
        start = time.monotonic()
        while time.monotonic() - start < bound:
            r = self.docker("exec", self.containers[name], "pg_isready", "-q", "-h",
                            "/run/postgresql", check=False)
            if r.returncode == 0:
                return
            time.sleep(0.5)
        raise AssertionError(f"{name}: PostgreSQL not ready after {bound} s")

    def psql(self, name, database, sql):
        r = self.docker("exec", "-i", "-u", "postgres", self.containers[name], "psql", "-X", "-q",
                        "-A", "-t", "-v", "ON_ERROR_STOP=1", "-d", database, input=sql)
        return r.stdout.strip()

    def exec_node(self, ldir, node, user, stdin=None, env=None, capture=True, timeout=None,
                  docker=None, argv=None):
        args = ["docker", "exec", "-i", "-u", user]
        for key, value in (env or {}).items():
            args += ["-e", f"{key}={value}"]
        args += [self.containers[node], *(argv or execnode.SHELL_ARGV)]
        kwargs = {"input": stdin.encode() if isinstance(stdin, str) else stdin} \
            if not hasattr(stdin, "read") else {"stdin": stdin}
        r = subprocess.run(args, capture_output=True, timeout=timeout or 600, **kwargs)
        return execnode.ExecResult(node, user, self.containers[node], r.returncode,
                                   r.stdout.decode("utf-8", "replace"),
                                   r.stderr.decode("utf-8", "replace"))

    def load(self, fixture):
        scenario = scenario_of(fixture)
        impl = impl_of(scenario)
        self.ldir = game_dir(self)
        plans = inject.load_plans(scenario, impl, fixture / "catalog")
        write_role_secrets(self.ldir, plans)
        self.result = inject.LoadResult("gmtest")
        self.printed = []
        started = time.monotonic()
        try:
            with mock.patch.object(inject, "exec_node", self.exec_node):
                inject.load_steps(self.ldir, plans, None, self.result, out=self.printed.append)
        finally:
            self.seconds = time.monotonic() - started
            print(f"\n[{self.id()}] composed load: {self.seconds:.1f} s")
        return scenario

    def server_log(self, name):
        return self.docker("exec", self.containers[name], "cat",
                           "/run/gmtest/pglog/postgresql.log").stdout

    def test_a_composed_load_passing(self):
        fixture = fixture_copy(self)
        scenario = self.load(fixture)
        printed = "\n".join(self.printed)
        r = self.result
        # the domains' databases, schemas and loads and the partner file ran
        # unseen (master spec 9.2): read before this test's own queries
        for name in LIBS:
            log = self.server_log(name)
            for fragment in LOAD_FRAGMENTS:
                self.assertNotIn(fragment, log, f"{name}'s log")
            self.assertEqual(self.psql(name, "postgres",
                                       "CREATE EXTENSION IF NOT EXISTS pg_stat_statements; "
                                       "SELECT count(*) FROM pg_stat_statements WHERE query ~ "
                                       f"'{LOAD_STATEMENTS}' AND query !~ 'pg_stat_statements';"),
                             "0", f"{name}'s statistics")
        self.assertIn("CREATE DATABASE office", self.server_log("records"))   # its data file seen
        # the order follows composition.yaml: fx-docs before fx-ward
        self.assertEqual([d for d, _, _, _ in r.domains],
                         ["fx-core", "fx-core", "fx-core", "fx-docs", "fx-docs", "fx-ward",
                          "fx-ward", "fx-ward"])
        # the databases load-data created, CONNECT revoked from PUBLIC
        self.assertEqual(r.created, [("records", "clinic"), ("records", "docs")])
        for db in ("clinic", "docs"):
            self.assertEqual(self.psql("records", "postgres",
                                       f"SELECT has_database_privilege('public', '{db}', "
                                       "'CONNECT');"), "f")
        self.assertEqual(self.psql("records", "postgres", "SELECT has_database_privilege("
                                   "'docs_app', 'docs', 'CONNECT');"), "t")
        # the contrib extensions of the parts' schemas, as postgres
        self.assertEqual(self.psql("records", "clinic", "SELECT extname FROM pg_extension "
                                   "WHERE extname = 'btree_gist';"), "btree_gist")
        self.assertEqual(self.psql("records", "docs", "SELECT extname FROM pg_extension WHERE "
                                   "extname = 'pgcrypto';"), "pgcrypto")
        # the keys served every load and the partner file, and are gone
        self.assertEqual(self.psql("records", "clinic", "SELECT string_agg(id::text, ',' ORDER "
                                   "BY id) FROM stays;"), "5001,5002,5003,5004,5005,5006")
        self.assertEqual(self.psql("records", "clinic", "SELECT string_agg(stay_id::text, ',' "
                                   "ORDER BY id) FROM ward_placements;"),
                         "5001,5002,5003,5004")
        self.assertEqual(self.psql("records", "docs", "SELECT count(*) FROM doc_requests WHERE "
                                   "stay_id BETWEEN 5001 AND 5006;"), "6")
        for name, db in (("records", "clinic"), ("records", "docs"), ("records", "office"),
                         ("partners-db", "partners")):
            self.assertEqual(self.psql(name, db, "SELECT count(*) FROM pg_proc WHERE proname "
                                       "LIKE 'core\\_%' OR proname LIKE 'docs\\_%';"), "0",
                             f"{name}/{db}")
        # a part's keys (chunk 29's (a)): fx-docs' titles from docs_title
        self.assertEqual(self.psql("records", "docs", "SELECT title FROM documents ORDER BY "
                                   "stay_id LIMIT 1;"), "animal 1 (dog)")
        # its cron.sql's job (chunk 29's (d)), in office, after step (6)'s
        # pg_cron clean-up ran on records: it survives it
        self.assertEqual(self.psql("records", "office", "SELECT jobname || '|' || schedule || '|' "
                                   "|| database || '|' || username FROM cron.job;"),
                         "fx-ward-tidy|0 3 * * *|clinic|ward_app")
        self.assertIn("records", [node for node, _ in r.cleaned])
        self.assertIn(("records", "office"), r.policies)
        # the partner's role, schema and planted state in partners
        self.assertEqual(self.psql("partners-db", "partners",
                                   "SELECT r.rolcanlogin, n.nspname, pg_get_userbyid(n.nspowner) "
                                   "FROM pg_roles r, pg_namespace n WHERE r.rolname = 'xlab' "
                                   "AND n.nspname = 'xlab';"), "t|xlab|xlab")
        self.assertEqual(self.psql("partners-db", "partners", "SELECT string_agg(stay_id::text, "
                                   "',' ORDER BY stay_id) FROM xlab.requests;"),
                         "5001,5002,5003,5004")
        # the derivation and the history ran, unseen, their sources gone
        self.assertEqual(self.psql("records", "docs", "SELECT count(*) FROM documents;"), "6")
        self.assertEqual(self.psql("records", "office", "SELECT sum(stays) FROM weekly_stays;"),
                         "6")
        for name, db in (("records", "clinic"), ("records", "docs"), ("records", "office"),
                         ("partners-db", "partners")):
            self.assertEqual(self.psql(name, db,
                                       "SELECT (SELECT count(*) FROM pg_foreign_server) || '|' || "
                                       "(SELECT count(*) FROM pg_namespace WHERE nspname LIKE "
                                       "'gm\\_src\\_%') || '|' || (SELECT count(*) FROM "
                                       "pg_extension WHERE extname = 'postgres_fdw');"),
                             "0|0|0", f"{name}/{db}")
        for name in LIBS:
            log = self.server_log(name)
            for canary in ("gm_src_", "c8_derive_canary", "c8_history_canary",
                           "c8_coherence_canary", "ALTER ROLE gm_check", "USER MAPPING",
                           GM_CHECK_PASSWORD):
                self.assertNotIn(canary, log, f"{name}'s log")
            self.assertNotRegex(log, r"gm_check@\S+ (LOG:  (statement|duration)|.*AUDIT)",
                                f"{name}'s log: a gm_check session seen")
            self.assertNotIn("temporary file", log, f"{name}'s log")
            self.assertEqual(self.psql(name, "postgres",
                                       "CREATE EXTENSION IF NOT EXISTS pg_stat_statements; "
                                       "SELECT count(*) FROM pg_stat_statements WHERE "
                                       "(query ~ 'gm_src_|c8_.*_canary' "
                                       "AND query !~ 'pg_stat_statements') OR userid = "
                                       "'gm_check'::regrole;"), "0", f"{name}'s statistics")
            self.assertEqual(self.psql(name, "postgres", "SELECT count(*) FROM "
                                       "pg_db_role_setting WHERE setrole = 'gm_check'::regrole;"),
                             "0", f"{name}: gm_check's settings reset")
        self.assertIn("AUDIT: SESSION", self.server_log("records"))   # the trail is on
        # the load is too small to spill: a forced temporary file, unseen and seen
        spill = ("SELECT pg_backend_pid(); SET work_mem = '64kB'; SELECT count(*) FROM (SELECT "
                 "g FROM generate_series(1, 100000) g ORDER BY g DESC) s;")
        unseen = self.psql("records", "postgres", inject.UNSEEN_SQL + spill).splitlines()[0]
        seen = self.psql("records", "postgres", spill).splitlines()[0]
        temp = re.compile(r"(?m)^[^[]*\[(\d+)\] .*LOG:  temporary file: ")
        start = time.monotonic()
        while seen not in temp.findall(self.server_log("records")) and \
                time.monotonic() - start < 10:
            time.sleep(0.2)
        pids = temp.findall(self.server_log("records"))
        self.assertIn(seen, pids)                        # log_temp_files = 0 logs it
        self.assertNotIn(unseen, pids)                   # the unseen prelude does not
        # gm_check's role settings: postgres sets log_temp_files for it
        self.psql("records", "postgres", inject.check_role_sql())
        shown = self.docker("exec", "-e", f"PGPASSWORD={GM_CHECK_PASSWORD}",
                            self.containers["records"], "psql", "-X", "-w", "-A", "-t", "-U",
                            "gm_check", "-d", "postgres", "-c", "SHOW log_temp_files")
        self.psql("records", "postgres", inject.check_role_sql(reset=True))
        self.assertEqual((shown.stdout.strip(), shown.stderr.strip()), ("-1", ""))
        self.assertIn("c8_derive_canary", (fixture / "catalog/domains/fx-docs/data/derive.sql")
                      .read_text())
        # partners-db refuses gm_check from the network (its pg_hba.conf, spec D383)
        refused = self.docker("exec", "-e", f"PGPASSWORD={GM_CHECK_PASSWORD}",
                              self.containers["records"], "psql", "-X", "-w", "-h", "partners-db",
                              "-U", "gm_check", "-d", "partners", "-c", "SELECT 1", check=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("pg_hba.conf rejects connection", refused.stderr)
        # the check reading partners ran on the partners' node, and passed
        self.assertIn("partners-db/partners", next(line for line in self.printed
                                                   if "requests-on-current-stays" in line
                                                   and "coherence check" in line))
        # the coherence check passed, and is recorded
        self.assertEqual(r.coherence_result, "pass")
        self.assertEqual([o.result for o in r.coherence], ["pass"] * 5)
        record = model.strict_load((scenario.dir / "composition.yaml").read_text())
        self.assertEqual(record["coherence"]["result"], "pass")
        self.assertEqual(localimpl.read_state(self.ldir)["coherence"]["result"], "pass")
        self.assertNotIn(GM_CHECK_PASSWORD, printed)
        self.assertLess(self.seconds, 600)

    def test_a_broken_range_failing(self):
        fixture = fixture_copy(self)
        load = fixture / "catalog/domains/fx-ward/data/load.sql"
        load.write_text(load.read_text().replace("generate_series(1, 4)", "generate_series(3, 6)"))
        with self.assertRaises(GmError) as cm:
            self.load(fixture)
        text = str(cm.exception)
        self.assertIn("fx-ward stays-placed (every current stay placed in a unit): 2 row(s)", text)
        self.assertIn('{"stay_id": 5001}', text)
        self.assertIn('{"stay_id": 5002}', text)
        record = model.strict_load((fixture / "scenario/composition.yaml").read_text())
        self.assertEqual(record["coherence"]["result"], "fail")
        checks = {c["check"]: c for c in localimpl.read_state(self.ldir)["coherence"]["checks"]}
        self.assertEqual(checks["stays-placed"]["result"], "fail")
        self.assertEqual(checks["placements-on-stays"]["result"], "pass")


if __name__ == "__main__":
    unittest.main()
