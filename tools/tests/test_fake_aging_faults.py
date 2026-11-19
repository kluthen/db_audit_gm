"""The faults fake aging covers (v0.6 master spec 6.3, 9.5, 9.7, 9.8, 9.10;
capture W3 items 8 to 10; wave 3's gate row): every fault the covered
scenarios use carries `aging.fake`, a `history:` unless `real-only`, the
`gm.md` "Fake aging" note where `tail-only` or `real-only`, and a
`# measured:` comment on each number of its history, naming the reference
member or the calibration file it was read from; and every instance of a
covered scenario resolves its signature's placeholders."""

import re
import unittest
from pathlib import Path

from tools.gm import model
from tools.gm.model import REPO_ROOT

# The scenarios fake aging covers in v0.6 (master spec 9.8).
COVERED = ("tarnbeck-outdoor-shop", "tarnbeck-outdoor-campaign")
MANIFEST = REPO_ROOT / "tools" / "fake_aging" / "reference" / "MANIFEST.sha256"
CALIBRATION = REPO_ROOT / "tools" / "fake_aging" / "calibration"
NOTE = "**Fake aging.**"
# History fields holding a measured number (capture W1 item 4's kinds).
NUMBER_FIELDS = ("per_call", "amplitude", "value", "period", "duration", "phase",
                 "service", "lock")
FIELD_LINE = re.compile(r"^\s+(?:- )?(%s):\s*\S" % "|".join(NUMBER_FIELDS))
MEASURED = re.compile(r"#\s*measured:\s*([^,\s]+)")


def covered_faults():
    """{fault id: [(scenario id, instance id)]} over the covered scenarios."""
    out = {}
    for sid in COVERED:
        sc = model.load_scenario(REPO_ROOT / "scenarios" / sid)
        for inst in sc.data["fault_instances"]:
            out.setdefault(inst["fault"]["id"], []).append((sid, inst["id"]))
    return out


def history_lines(text):
    """The lines of the top-level `history:` block."""
    lines, inside = [], False
    for line in text.splitlines():
        if re.match(r"^history:", line):
            inside = True
            continue
        if inside and re.match(r"^[A-Za-z_#]", line):
            break
        if inside:
            lines.append(line)
    return lines


def manifest_members():
    return {line.split(None, 1)[1].strip() for line in MANIFEST.read_text().splitlines()
            if line.strip()}


class FakeAgingFaults(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.faults = covered_faults()
        cls.members = manifest_members()

    def fault_data(self, fid):
        path = REPO_ROOT / "faults" / fid / "fault.yaml"
        return path, model.strict_load(path.read_text())

    def test_the_covered_scenarios_use_faults(self):
        self.assertGreaterEqual(len(self.faults), 10 * len(COVERED) - 1)

    def test_each_fault_passes_the_loader(self):
        for fid in sorted(self.faults):
            with self.subTest(fault=fid):
                self.assertEqual(model.check_fault_dir(REPO_ROOT / "faults" / fid), [])

    def test_each_fault_is_assessed_with_its_history(self):
        for fid in sorted(self.faults):
            with self.subTest(fault=fid):
                _, data = self.fault_data(fid)
                fake = model.fault_fake_aging(data)
                self.assertIsNotNone(fake, "no aging.fake: not assessed")
                self.assertTrue(fake.reason.strip())
                history = model.fault_history(data)
                if fake.support == "real-only":
                    self.assertIsNone(history, "a real-only fault carries no history:")
                else:
                    self.assertTrue(history, "history: missing or empty")

    def test_tail_only_and_real_only_have_the_note(self):
        for fid in sorted(self.faults):
            with self.subTest(fault=fid):
                _, data = self.fault_data(fid)
                fake = model.fault_fake_aging(data)
                gm = (REPO_ROOT / "faults" / fid / "gm.md").read_text()
                if fake.support in ("tail-only", "real-only"):
                    self.assertIn("\n" + NOTE, gm, "gm.md lacks its Fake aging note")

    def test_every_number_is_measured_and_traced(self):
        for fid in sorted(self.faults):
            path, _ = self.fault_data(fid)
            for line in history_lines(path.read_text()):
                if not FIELD_LINE.match(line):
                    continue
                with self.subTest(fault=fid, line=line.strip()[:60]):
                    m = MEASURED.search(line)
                    self.assertIsNotNone(m, "a number without its # measured: comment")
                    source = m.group(1)
                    if source.startswith("tools/fake_aging/calibration/"):
                        self.assertTrue((REPO_ROOT / source).is_file(), source)
                    else:
                        self.assertIn(source, self.members,
                                      "neither a reference member nor a calibration file")

    def test_every_instance_resolves_its_signature(self):
        for fid, instances in sorted(self.faults.items()):
            for sid, iid in instances:
                with self.subTest(scenario=sid, instance=iid):
                    sc = model.load_scenario(REPO_ROOT / "scenarios" / sid)
                    for entry in model.instance_history(sc, iid) or ():
                        text = repr(entry.fields)
                        self.assertNotIn("None", text, "a signature's parameter left unset")
                        self.assertIsNone(re.search(r"\{[A-Z][A-Z0-9_]*\}", text),
                                          "a placeholder left unresolved")


if __name__ == "__main__":
    unittest.main()
