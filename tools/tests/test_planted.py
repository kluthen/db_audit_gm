"""The faults' overlays on their fixtures (v0.5 capture W5 item 0 of
specs/versions/v0.5/wave-log.md; build plan chunk 22): every
`tools/tests/fixtures/<fixture>/planted/<fault-id>/` merges onto a copy of
its fixture (tools/tests/planted.py), composes and loads, planting that
fault; a seed change written as a diff (the fault's `material`) is exactly
the overlay's file against the fixture's; and the orders faults' two diffs
of one script apply together, in either order (the clinic's copy carries
both, W5 item 6).
"""

import re
import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import compose, model
from tools.tests import planted

REPO = model.REPO_ROOT
FIXTURES = REPO / "tools" / "tests" / "fixtures"
ORDERS_SCRIPT = REPO / "purposes" / "vet-lab-centre-orders" / "material" / "runner" / "scripts" / "lab_orders.py"
ORDERS_FAULTS = ("purpose-urgent-priority-dropped", "purpose-retry-without-key")


def overlays():
    return sorted(FIXTURES.glob("*/planted/*/"))


def diff_target(diff_text):
    m = re.search(r"^\+\+\+ b/(\S+)", diff_text, re.M)
    return m.group(1) if m else None


class TestOverlays(unittest.TestCase):

    def test_there_are_overlays(self):
        names = {p.name for p in overlays()}
        self.assertTrue(set(ORDERS_FAULTS) <= names, names)

    def test_each_overlay_plants_its_fault_on_a_copy(self):
        for overlay in overlays():
            fixture = overlay.parent.parent
            with self.subTest(overlay=f"{fixture.name}/{overlay.name}"), \
                    tempfile.TemporaryDirectory() as tmp:
                copy = Path(tmp) / fixture.name
                shutil.copytree(fixture, copy)
                for script in copy.glob("run-*.sh"):
                    script.unlink()
                before = yaml.safe_load((fixture / "scenario.yaml").read_text())
                planted.merge(copy, overlay)
                self.assertFalse((copy / "planted").exists())
                if (copy / "composition.yaml").is_file():
                    compose.compose(copy, REPO)
                    compose.compose(copy, REPO, check=True)
                sc = model.load_scenario(copy)
                data = yaml.safe_load((copy / "scenario.yaml").read_text())
                added = [i for i in data["fault_instances"]
                         if i["id"] not in {b["id"] for b in before["fault_instances"]}]
                self.assertEqual([i["fault"]["id"] for i in added], [overlay.name])
                self.assertEqual(data["difficulty"]["score"], len(data["fault_instances"]))
                key = yaml.safe_load((copy / "gm" / "answer-key.yaml").read_text())
                self.assertEqual(sorted(i["instance"] for i in key["instances"]), sorted(sc.faults))
                # the fixture's committed files stay unfaulted, its README as generated
                self.assertEqual((copy / "README.md").read_bytes(), (fixture / "README.md").read_bytes())

    def test_a_diff_material_is_the_overlays_seed_change(self):
        for overlay in overlays():
            fixture = overlay.parent.parent
            frag = yaml.safe_load((overlay / "scenario.yaml").read_text())
            for inst in frag["fault_instances"]:
                fault = yaml.safe_load((REPO / "faults" / inst["fault"]["id"] / "fault.yaml").read_text())
                for change in fault["injection"].get("seed_changes") or []:
                    material = change.get("material") or ""
                    if not material.endswith(".diff"):
                        continue
                    diff = (REPO / "faults" / inst["fault"]["id"] / material).read_text()
                    rel = Path("compose") / inst["node"] / diff_target(diff)
                    with self.subTest(overlay=overlay.name, file=str(rel)):
                        self.assertEqual(planted.apply_diff((fixture / rel).read_text(), diff),
                                         (overlay / rel).read_text())


class TestOrdersFaultsTogether(unittest.TestCase):

    def test_both_diffs_apply_to_the_purposes_script_in_either_order(self):
        base = ORDERS_SCRIPT.read_text()
        diffs = [(REPO / "faults" / f / "inject" / "lab_orders.py.diff").read_text() for f in ORDERS_FAULTS]
        for d in diffs:
            self.assertEqual(diff_target(d), "scripts/lab_orders.py")
        one = planted.apply_diff(planted.apply_diff(base, diffs[0]), diffs[1])
        two = planted.apply_diff(planted.apply_diff(base, diffs[1]), diffs[0])
        self.assertEqual(one, two)
        compile(one, "lab_orders.py", "exec")
        self.assertIn('{"stat": "urgent"}.get(priority, "routine")', one)
        self.assertIn('ref = body["client_ref"] = f"{ref}-{started:%H%M}"', one)

    def test_the_fixtures_script_is_the_purposes(self):
        # the overlays' diffs are against the purpose's material, copied as written
        self.assertEqual((FIXTURES / "fixture-orders" / "compose" / "interfaces" / "scripts" /
                          "lab_orders.py").read_text(), ORDERS_SCRIPT.read_text())


class TestApplyDiff(unittest.TestCase):

    DIFF = "--- a/x\n+++ b/x\n@@ -1,2 +1,2 @@\n a\n-b\n+B\n"

    def test_applies_a_hunk_found_once(self):
        self.assertEqual(planted.apply_diff("a\nb\nc\n", self.DIFF), "a\nB\nc\n")

    def test_refuses_a_hunk_found_twice_or_never(self):
        with self.assertRaises(planted.PlantError):
            planted.apply_diff("a\nb\na\nb\n", self.DIFF)
        with self.assertRaises(planted.PlantError):
            planted.apply_diff("a\nc\n", self.DIFF)

    def test_refuses_an_unknown_fragment_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            copy, overlay = Path(tmp) / "copy", Path(tmp) / "planted" / "x"
            shutil.copytree(FIXTURES / "fixture-orders", copy)
            overlay.mkdir(parents=True)
            (overlay / "scenario.yaml").write_text("nodes: []\n")
            with self.assertRaises(planted.PlantError):
                planted.merge(copy, overlay)


if __name__ == "__main__":
    unittest.main()
