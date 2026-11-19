"""The network overview's first fault and the clinic's front (v0.6 build plan,
chunk 14; master spec 6.3, 8.5, 12.1 and release gate item 4; capture W2
items 3 and 4).

Two bastion-only fixtures carry aldermoor-centre's handouts, so these tests
keep them equal to the clinic's: `fixture-clinic-front`'s starter pack is the
clinic's as a game hands it over (`{{customer_timezone}}` filled, each
`{{credential:<name>}}` a fixture value, since no partner runs a node
there), and `fixture-overview-fault`'s overview is the clinic's with n5
(`docs-overview-backup-claimed`) applied, its `overview_diff:` reverting it.
A regenerated clinic overview or register fails them until the fixtures are
copied again. The fault's sealed check runs here on handouts with the host's
`sh` and both `awk`s (the bastion's is mawk); the fixtures' short tests
deploy them for real."""

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import model
from tools.tests import FIXTURES, REPO_ROOT

CLINIC = REPO_ROOT / "scenarios" / "aldermoor-centre"
FX_FRONT = FIXTURES / "fixture-clinic-front"
FX_FAULT = FIXTURES / "fixture-overview-fault"
FAULT = REPO_ROOT / "faults" / "docs-overview-backup-claimed"
CHECK = FAULT / "checks" / "fixed.sh"
HANDOUT_LINE = "HANDOUT=/home/player/network-overview.md\n"
# what a game hands over in place of the placeholders (fixture-clinic-front's
# scenario.yaml): a render's customer time zone, a credential's value
TIMEZONE = "UTC+1 (Etc/GMT-1)"
STARTER = ("README.md", "story.md", "issues.md", "data-policy.md", "partners.md",
           "data-register.md", "network-overview.md")


def text(path):
    return path.read_text(encoding="utf-8")


def load(path):
    return yaml.safe_load(text(path))


def handed_over(content):
    content = content.replace(model.CUSTOMER_TIMEZONE, TIMEZONE)
    return re.sub(r"\{\{credential:([a-z][a-z0-9_]*)\}\}",
                  lambda m: f"fx-{m.group(1)}-0123456789abcdef", content)


def instance(sdir, iid):
    return next(i for i in load(sdir / "gm" / "answer-key.yaml")["instances"]
                if i["instance"] == iid)


class TestFault(unittest.TestCase):

    def test_format_check(self):
        self.assertEqual(model.check_fault_dir(FAULT), [])

    def test_documentation_family_on_the_bastion(self):
        data = load(FAULT / "fault.yaml")
        self.assertEqual((data["family"], data["injection"]["kind"]), ("documentation", "seed-file"))
        self.assertEqual([c["file"] for c in data["injection"]["seed_changes"]],
                         ["network-overview.md"])
        self.assertNotIn("lines", data["injection"]["seed_changes"][0])
        self.assertEqual(data["applies_to"]["bricks"], [{"id": "bastion", "versions": ["0.6.0"]}])
        self.assertEqual([r["kind"] for r in data["resolutions"]], ["propose"])
        self.assertEqual(sorted(data["parameters"]), ["claimed", "node"])


class TestClinicFront(unittest.TestCase):

    def test_loads(self):
        s = model.load_scenario(FX_FRONT)
        self.assertEqual([n["name"] for n in s.data["nodes"]], ["bastion"])
        self.assertEqual(sorted(s.data["nodes"][0]["seed_files"]), sorted(STARTER))

    def test_starter_pack_is_the_clinics_as_handed_over(self):
        for name in STARTER:
            with self.subTest(file=name):
                self.assertEqual(text(FX_FRONT / "player" / name),
                                 handed_over(text(CLINIC / "player" / name)))
                self.assertNotIn("{{", text(FX_FRONT / "player" / name))

    def test_every_partner_with_a_document_on_no_node(self):
        clinic = [(t["id"], t["name"], t["hostname"], t["player_doc"])
                  for t in load(CLINIC / "scenario.yaml")["third_parties"]]
        front = load(FX_FRONT / "scenario.yaml")["third_parties"]
        self.assertEqual([(t["id"], t["name"], t["hostname"], t["player_doc"]) for t in front], clinic)
        self.assertEqual({str(t["nodes"]) for t in front}, {"[]"})
        self.assertEqual(load(FX_FRONT / "scenario.yaml")["fault_instances"][0].get("admitted"), None)

    def test_true_files_are_the_clinics(self):
        register, clinic = load(FX_FRONT / "gm" / "data-register.yaml"), \
            load(CLINIC / "gm" / "data-register.yaml")
        for key in ("entries", "internal", "index"):
            self.assertEqual(register[key], clinic[key])
        self.assertEqual(instance(FX_FRONT, "s6")["register_diff"],
                         instance(CLINIC, "s6")["register_diff"])
        overview, clinic = load(FX_FRONT / "gm" / "network-overview.yaml"), \
            load(CLINIC / "gm" / "network-overview.yaml")
        self.assertEqual((overview["header"], overview["entries"], overview["third_parties"]),
                         (clinic["header"], [], clinic["third_parties"]))


class TestOverviewFault(unittest.TestCase):

    def test_loads_with_its_diff(self):
        s = model.load_scenario(FX_FAULT)
        self.assertEqual([(i["id"], i["fault"]["id"], i["node"], i["parameters"]["node"])
                          for i in s.data["fault_instances"]],
                         [("n5", "docs-overview-backup-claimed", "bastion", "machines")])
        diff = instance(FX_FAULT, "n5")["overview_diff"]
        self.assertEqual([(d["node"], d["field"]) for d in diff], [("machines", "backups")])
        claimed = s.data["fault_instances"][0]["parameters"]["claimed"]
        self.assertIn(claimed, diff[0]["handed_out"])
        self.assertNotIn(claimed, model.register_diff_true(diff[0]))

    def test_the_diff_reverted_gives_the_clinics_overview(self):
        """The handout differs from the clinic's exactly where overview_diff
        says: its handed_out lines, put back to true in the node's entry,
        give the clinic's handout; the true lines are the clinic's true
        overview's."""
        diff = instance(FX_FAULT, "n5")["overview_diff"][0]
        true = model.register_diff_true(diff)
        clinic_entry = next(e for e in load(CLINIC / "gm" / "network-overview.yaml")["entries"]
                            if e["node"] == diff["node"])
        self.assertEqual(true, [b["line"] for b in clinic_entry["backups"]])
        planted = text(FX_FAULT / "player" / "network-overview.md")
        old = "- **Backups**:\n" + "".join(f"  - {line}\n" for line in diff["handed_out"])
        new = "- **Backups**:\n" + "".join(f"  - {line}\n" for line in true)
        head, sep, tail = planted.partition(f"### {diff['node']}\n")
        self.assertEqual(tail.count(old), 1)
        self.assertEqual(head + sep + tail.replace(old, new, 1),
                         handed_over(text(CLINIC / "player" / "network-overview.md")))


class TestSealedCheck(unittest.TestCase):
    """The fault's sealed check on a handout: the claim among the node's
    Backups items reads present (1), elsewhere in the entry or another
    entry not (0), a missing entry or Backups an error (2)."""

    CLAIM = "WAL archived to Cold Storage, segment by segment"

    def run_check(self, handout, node="machines", claimed=CLAIM, awk="awk"):
        script = text(CHECK)
        self.assertIn(HANDOUT_LINE, script)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "network-overview.md"
            path.write_text(handout)
            bindir = Path(tmp) / "bin"
            bindir.mkdir()
            (bindir / "awk").symlink_to(shutil.which(awk))
            env = {"PATH": f"{bindir}:/usr/bin:/bin", "FAULT_NODE": node, "FAULT_CLAIMED": claimed}
            run = subprocess.run(["sh", "-s"], input=script.replace(HANDOUT_LINE, f"HANDOUT={path}\n"),
                                 capture_output=True, text=True, env=env)
        return run.returncode, run.stdout

    def awks(self):
        return [a for a in ("mawk", "gawk") if shutil.which(a)] or ["awk"]

    def test_the_planted_handout_reads_present(self):
        for awk in self.awks():
            with self.subTest(awk=awk):
                rc, out = self.run_check(text(FX_FAULT / "player" / "network-overview.md"), awk=awk)
                self.assertEqual(rc, 1, out)
                self.assertIn("claims, under the Backups of machines", out)

    def test_the_clinics_true_handout_reads_without_the_fault(self):
        for awk in self.awks():
            with self.subTest(awk=awk):
                rc, out = self.run_check(text(CLINIC / "player" / "network-overview.md"), awk=awk)
                self.assertEqual(rc, 0, out)

    def test_only_the_nodes_backups_count(self):
        handout = ("## Database servers\n\n### records\n\n- **Backups**:\n  - " + self.CLAIM + "\n\n"
                   "### machines\n\n- **Third parties**:\n  - Cold Storage: " + self.CLAIM + "\n"
                   "- **Backups**:\n  - a base backup each night\n- **Users**: " + self.CLAIM.lower()
                   + "\n\n## Monitoring\n\n- " + self.CLAIM + "\n")
        rc, out = self.run_check(handout)
        self.assertEqual(rc, 0, out)
        rc, out = self.run_check(handout.replace("a base backup each night", self.CLAIM.upper()))
        self.assertEqual(rc, 1, out)
        rc, out = self.run_check(handout, node="records")
        self.assertEqual(rc, 1, out)

    def test_errors(self):
        rc, out = self.run_check("## Database servers\n\n### lab\n\n- **Backups**:\n  - none\n")
        self.assertEqual(rc, 2, out)
        self.assertIn("no entry ### machines", out)
        rc, out = self.run_check("### machines\n\n- **Users**: none\n")
        self.assertEqual(rc, 2, out)
        self.assertIn("has no Backups", out)
        rc, out = self.run_check("### machines\n", claimed="")
        self.assertEqual(rc, 2, out)


if __name__ == "__main__":
    unittest.main()
