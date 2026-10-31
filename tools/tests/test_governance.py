"""The governance check set's GM side and its shell's own refusals
(tools/gm/governance.py, tools/gm/governance.sh; v0.4 master spec 11.6;
capture W3-a; spec D230). The rules themselves run against PostgreSQL in
tools/tests/smoke-governance.sh."""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import checks, governance, localimpl, model
from tools.gm.model import GmError
from tools.tests.test_inject import INSTANCES_FIXTURE, InstancesDeployedGame

SET = governance.SCRIPT


def run_set(body, env=None):
    """`sh -s` fed governance.sh, a newline, then `body`, as gmctl check
    sends it; (exit status, stdout, stderr)."""
    clean = {k: v for k, v in os.environ.items() if not k.startswith("CHECK_")}
    clean.update(env or {})
    proc = subprocess.run(["sh", "-s"], input=governance.check_text(body), text=True,
                          capture_output=True, env=clean, timeout=60)
    return proc.returncode, proc.stdout, proc.stderr


CALL = 'out=$(check_governance {}); rc=$?\nprintf "%s\\n" "$out"\necho "after rc=$rc"\nexit $rc\n'


class TestEnvValue(unittest.TestCase):

    def setUp(self):
        self.scenario = model.load_scenario(INSTANCES_FIXTURE)

    def test_fixture_instances(self):
        text = governance.env_value(self.scenario)
        self.assertNotIn("\n", text)
        value = json.loads(text)
        self.assertEqual(list(value), sorted(value))
        self.assertEqual(list(value), ["classes", "columns", "database_nodes", "own_roles",
                                       "transformer_nodes"])
        self.assertEqual(value["classes"]["personal"]["locations"], ["db/shop"])
        self.assertEqual(value["classes"]["personal"]["outbound"], [
            {"to": "mail-provider", "outbox": "db/shop/mail_outbox",
             "fields": ["email", "name", "order_id"]}])
        self.assertEqual(value["classes"]["internal"], {"locations": "any"})
        self.assertEqual(value["columns"]["shop.customers.email"], "personal")
        self.assertEqual(value["columns"]["shop.orders.customer_id"], "customer-linked")
        self.assertNotIn("shop.orders.total", value["columns"])      # internal: left out
        self.assertEqual(set(value["columns"].values()), {"personal", "customer-linked"})
        self.assertEqual(value["database_nodes"], ["db", "reporting"])
        self.assertEqual(value["transformer_nodes"], [])
        self.assertEqual(value["own_roles"], list(model.RESERVED_DB_ROLES))

    def test_a_missing_internal_reads_as_any(self):
        del self.scenario.data["governance"]["classes"]["internal"]
        value = json.loads(governance.env_value(self.scenario))
        self.assertEqual(value["classes"]["internal"], {"locations": "any"})

    def test_classes_as_written(self):
        self.scenario.data["governance"]["classes"]["personal"]["separation"] = "instance"
        value = json.loads(governance.env_value(self.scenario))
        self.assertEqual(value["classes"]["personal"]["separation"], "instance")

    def test_transformer_nodes_in_topology_order(self):
        self.scenario.data["nodes"] += [{"name": "crm", "role": "transformer"},
                                        {"name": "bi", "role": "transformer"}]
        value = json.loads(governance.env_value(self.scenario))
        self.assertEqual(value["transformer_nodes"], ["crm", "bi"])

    def test_refused_without_governance(self):
        del self.scenario.data["governance"]
        with self.assertRaisesRegex(GmError, "has no governance"):
            governance.env_value(self.scenario)

    def test_command_line(self):
        root = Path(__file__).resolve().parents[2]
        proc = subprocess.run(["python3", "-B", "-m", "tools.gm.governance", "env",
                               str(INSTANCES_FIXTURE)], cwd=root, capture_output=True,
                              text=True, timeout=60)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout, governance.env_value(self.scenario) + "\n")
        proc = subprocess.run(["python3", "-B", "-m", "tools.gm.governance", "text", "-"],
                              cwd=root, input="check_governance G1\n", capture_output=True,
                              text=True, timeout=60)
        self.assertEqual(proc.stdout, SET.read_text() + "\ncheck_governance G1\n")
        proc = subprocess.run(["python3", "-B", "-m", "tools.gm.governance", "nope"],
                              cwd=root, capture_output=True, text=True, timeout=60)
        self.assertEqual(proc.returncode, 2)


class TestCheckPlan(InstancesDeployedGame):
    """A sealed check calling the set is sent as governance.sh, a newline,
    then its script, with CHECK_GOVERNANCE (W3-a item 1)."""

    def setUp(self):
        super().setUp()
        for stage in ("data-loaded", "injected"):
            localimpl.set_stage(self.ldir, stage)
        self.script = self.scenario / "faults/fixture-random-page-cost/checks/fixed.sh"

    def plan(self):
        sc = model.load_scenario(self.scenario)
        return checks.check_plan(sc, localimpl.read_implementation(self.ldir))

    def test_a_check_not_calling_the_set_is_sent_as_written(self):
        [(_, _, node, run_as, env, text)] = self.plan()
        self.assertEqual(text, self.script.read_text())
        self.assertNotIn(governance.ENV, env)
        self.assertEqual((node, run_as), ("db", "root"))

    def test_a_check_calling_the_set(self):
        body = "#!/bin/sh\nout=$(check_governance G1 G3); rc=$?\necho \"$out\"\nexit $rc\n"
        self.script.write_text(body)
        [(_, _, node, _, env, text)] = self.plan()
        self.assertEqual(text, SET.read_text() + "\n" + body)
        self.assertEqual(env[governance.ENV],
                         governance.env_value(model.load_scenario(self.scenario)))
        result = checks.check(self.scenario, "laptop", docker=self.fake)
        [run] = self.fake.runs
        self.assertEqual(run["stdin"], text)
        self.assertEqual(run["env"][governance.ENV], env[governance.ENV])
        self.assertEqual(result.exit_code, 0)

    def test_refused_in_a_scenario_without_governance(self):
        self.script.write_text("check_governance G1\n")
        path = self.scenario / "scenario.yaml"
        data = yaml.safe_load(path.read_text())
        del data["governance"]
        bastion = next(n for n in data["nodes"] if n["name"] == "bastion")
        del bastion["seed_files"]["data-policy.md"]
        path.write_text(yaml.safe_dump(data, sort_keys=False))
        with self.assertRaisesRegex(GmError, "calls check_governance, but scenario "
                                             "fixture-instances has no governance:"):
            self.plan()
        result_runs = len(self.fake.runs)
        with self.assertRaises(GmError):
            checks.check(self.scenario, "laptop", docker=self.fake)
        self.assertEqual(len(self.fake.runs), result_runs)      # nothing ran


class TestShell(unittest.TestCase):
    """governance.sh on a host that is neither node kind: what it refuses
    before reaching a database."""

    def test_syntax_and_no_top_level_effect(self):
        self.assertEqual(subprocess.run(["sh", "-n", str(SET)]).returncode, 0)
        rc, out, err = run_set("echo ok\n")
        self.assertEqual((rc, out, err), (0, "ok\n", ""))
        text = SET.read_text()
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run(["sh", "-c", 'set > "$1/before"; . "$2"; set > "$1/after"; '
                            'trap > "$1/trap"', "sh", tmp, str(SET)],
                           env={"PATH": os.environ["PATH"]}, check=True, timeout=60)
            before, after, trap = (Path(tmp, f).read_text() for f in ("before", "after", "trap"))
        self.assertEqual(after, before, "sourcing sets no variable")
        self.assertEqual(trap, "", "sourcing sets no trap")
        self.assertNotRegex(text, r"(?m)^\s*exit\b")

    def cannot(self, call, env=None):
        rc, out, _ = run_set(CALL.format(call), env)
        lines = out.splitlines()
        self.assertEqual(rc, 2, out)
        self.assertTrue(lines[0].startswith("governance: cannot judge: "), out)
        self.assertEqual(lines[-1], "after rc=2")       # returned to its caller
        return lines[0]

    def test_refusals(self):
        env = {"CHECK_GOVERNANCE": "{}"}
        self.assertIn("G5 is not a rule", self.cannot("G1 G5", env))
        self.assertIn("G1 named twice", self.cannot("G1 G1", env))
        self.assertIn("no rule named", self.cannot("", env))
        self.assertIn("no CHECK_GOVERNANCE", self.cannot("G1"))
        self.assertIn("neither a database node nor a transformer node",
                      self.cannot("G1 G2 G3 G4", env))

    def test_caller_settings_untouched(self):
        body = "set -eu\nx=1\nout=$(check_governance G9) || rc=$?\necho \"x=$x rc=$rc\"\n"
        rc, out, _ = run_set(body)
        self.assertEqual((rc, out.splitlines()[-1]), (0, "x=1 rc=2"))

    def test_shared_sql_binds_through_check_sql(self):
        """The reach SQL the transformer path sends through check-sql has no
        percent sign and only the set's four psql variables."""
        proc = subprocess.run(["sh", "-c", f". {SET}; _gov_reach_sql"], capture_output=True,
                              text=True, timeout=60)
        sql = proc.stdout
        self.assertIn("has_column_privilege", sql)
        self.assertNotIn("%", sql)
        self.assertEqual(set(re.findall(r":'(\w+)'", sql)), {"gov", "loc", "role", "tbl"})
        self.assertNotRegex(sql, r"(?<!:):[A-Za-z\"]")       # no other psql interpolation

    def test_own_roles_named_in_one_place(self):
        text = SET.read_text()
        self.assertEqual(text.count("jsonb_array_elements_text(gov.g -> 'own_roles')"), 1)
        self.assertEqual(text.count("$(_gov_own_roles_sql)"), 1)    # G2 only (D230)


if __name__ == "__main__":
    unittest.main()
