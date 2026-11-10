"""The clinic's purposes (v0.5 master spec 12.1, 12.2; build plan chunk 18,
spec D435; capture W4 items 0 and 3 of specs/versions/v0.5/wave-log.md).

- Every purpose's `ops` block, the lines `-- ops: begin` to `-- ops: end` of
  any file under purposes/, is byte-identical to every other: the shared
  schema each purpose's DDL creates, guarded, so any subset of purposes loads
  alike (W4 item 0). Every `material/target/office.sql` likewise (W4 item 5).
  Found by glob; a changed copy fails.
- The clinic's purposes pass the format check, and the fixtures that run them
  load, compose to their nodes/ unchanged and carry the purposes' runner
  material as written.
"""

import shutil
import tempfile
import unittest
from pathlib import Path

import yaml

from tools.gm import compose, model

REPO = model.REPO_ROOT
FIXTURES = REPO / "tools" / "tests" / "fixtures"
BEGIN, END = "-- ops: begin", "-- ops: end"
OFFICE_GLOB = "*/material/target/office.sql"
# The periodic reports (chunk 20): no ddl:, their office tables in records'
# data file, the authority's stub shared with purpose 5.
PERIODIC_PURPOSES = ("vet-medicines-registers", "vet-antimicrobial-use", "vet-working-time")
CLINIC_PURPOSES = {"fixture-orders": ("vet-lab-centre-orders", "vet-lab-critical-calls"),
                   "fixture-send-outs": ("vet-lab-practice-results", "vet-lab-send-outs"),
                   "fixture-reports": PERIODIC_PURPOSES}
AUTHORITY_BEGIN, AUTHORITY_END = "-- authority: begin", "-- authority: end"
AUTHORITY_GLOB = "*/material/receiver/authority"


def ops_blocks(purposes):
    """{relative path: the block's bytes, its two marker lines included} for
    every file under `purposes` holding `-- ops: begin`; a file whose block
    does not close, or holding two, is reported as its problem text."""
    found = {}
    for path in sorted(p for p in Path(purposes).rglob("*") if p.is_file()):
        try:
            lines = path.read_bytes().decode("utf-8").splitlines(keepends=True)
        except UnicodeDecodeError:
            continue
        starts = [i for i, line in enumerate(lines) if line.rstrip("\n") == BEGIN]
        if not starts:
            continue
        rel = path.relative_to(purposes).as_posix()
        ends = [i for i, line in enumerate(lines) if line.rstrip("\n") == END]
        if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0]:
            found[rel] = f"problem: {len(starts)} begin and {len(ends)} end lines, in that order or not"
            continue
        found[rel] = "".join(lines[starts[0]:ends[0] + 1])
    return found


def differing(copies):
    """The relative paths whose content differs from the first copy's (in
    path order), with every problem text."""
    items = sorted(copies.items())
    if not items:
        return []
    first = items[0][1]
    return [rel for rel, text in items if text != first or (isinstance(text, str) and text.startswith("problem: "))]


def office_copies(purposes):
    return {p.relative_to(purposes).as_posix(): p.read_bytes()
            for p in sorted(Path(purposes).glob(OFFICE_GLOB))}


class TestSharedText(unittest.TestCase):

    def test_ops_blocks_are_byte_identical(self):
        blocks = ops_blocks(REPO / "purposes")
        self.assertGreaterEqual(len(blocks), 2, sorted(blocks))
        self.assertEqual(differing(blocks), [], "every -- ops: begin to -- ops: end block is the same text")

    def test_ops_block_is_capture_w4s(self):
        """The text itself: guarded, owned by ops, the three tables."""
        block = next(iter(ops_blocks(REPO / "purposes").values()))
        for line in ("CREATE ROLE ops NOLOGIN;   -- owns the purposes' tables",
                     "CREATE SCHEMA IF NOT EXISTS ops AUTHORIZATION ops;", "REVOKE ALL ON SCHEMA ops FROM PUBLIC;",
                     "CREATE TABLE IF NOT EXISTS ops.runs (", "CREATE TABLE IF NOT EXISTS ops.incidents (",
                     "CREATE TABLE IF NOT EXISTS ops.watermarks (", "RESET ROLE;"):
            self.assertIn(line + "\n", block)

    def test_office_sql_copies_are_byte_identical(self):
        self.assertEqual(differing(office_copies(REPO / "purposes")), [])

    def test_a_changed_copy_fails(self):
        block = next(iter(ops_blocks(REPO / "purposes").values()))
        with tempfile.TemporaryDirectory(prefix="gm-purposes-") as tmp:
            root = Path(tmp)
            for name, text in (("a", block), ("b", block), ("c", block.replace("NOT NULL", "NULL", 1))):
                ddl = root / f"p-{name}" / "material" / "target" / "ddl.sql"
                ddl.parent.mkdir(parents=True)
                ddl.write_text(f"-- {name}'s DDL\n{text}GRANT USAGE ON SCHEMA ops TO {name};\n")
            self.assertEqual(differing(ops_blocks(root)), ["p-c/material/target/ddl.sql"])
            (root / "p-c" / "material" / "target" / "ddl.sql").write_text(block.replace(END, "-- ops: fin"))
            self.assertEqual(differing(ops_blocks(root)), ["p-c/material/target/ddl.sql"])
            for name, text in (("a", "CREATE ROLE office NOLOGIN;\n"), ("b", "CREATE ROLE office NOLOGIN;\n"),
                               ("c", "CREATE ROLE office NOLOGIN; \n")):
                (root / f"p-{name}" / "material" / "target" / "office.sql").write_text(text)
            self.assertEqual(differing(office_copies(root)), ["p-c/material/target/office.sql"])

    def test_a_purpose_ddl_on_a_domain_database_carries_the_block(self):
        """Each clinic purpose's ddl: file holds the block (W4 item 0)."""
        blocks = ops_blocks(REPO / "purposes")
        for purposes in CLINIC_PURPOSES.values():
            for pid in purposes:
                data = yaml.safe_load((REPO / "purposes" / pid / "purpose.yaml").read_text())
                for part, rel in data.get("ddl", {}).items():
                    with self.subTest(purpose=pid, part=part):
                        self.assertIn(f"{pid}/{rel}", blocks)


class TestAuthorityStub(unittest.TestCase):
    """The authority is one prefix for purposes 5 and 8 (capture W4 item 0):
    the block between `-- authority: begin` and `-- authority: end` of each
    copy's data.sql, its queries.yaml and its schedule.yaml, byte-identical."""

    def test_the_shared_text_is_byte_identical(self):
        stubs = sorted(Path(REPO / "purposes").glob(AUTHORITY_GLOB))
        self.assertGreaterEqual(len(stubs), 2, [str(s) for s in stubs])
        for name in ("queries.yaml", "schedule.yaml"):
            with self.subTest(file=name):
                self.assertEqual({(s / name).read_bytes() for s in stubs}.__len__(), 1)
        blocks = set()
        for stub in stubs:
            lines = (stub / "data.sql").read_text().splitlines(keepends=True)
            starts = [i for i, line in enumerate(lines) if line.rstrip("\n") == AUTHORITY_BEGIN]
            ends = [i for i, line in enumerate(lines) if line.rstrip("\n") == AUTHORITY_END]
            self.assertEqual((len(starts), len(ends)), (1, 1), stub)
            blocks.add("".join(lines[starts[0]:ends[0] + 1]))
        self.assertEqual(len(blocks), 1)


class TestClinicPurposes(unittest.TestCase):

    def test_the_purposes_pass_the_format_check(self):
        for purposes in CLINIC_PURPOSES.values():
            for pid in purposes:
                with self.subTest(purpose=pid):
                    self.assertEqual(model.check_purpose_dir(REPO / "purposes" / pid), [])

    def test_the_fixtures_load_and_compose_unchanged(self):
        for fixture, purposes in CLINIC_PURPOSES.items():
            with self.subTest(fixture=fixture), tempfile.TemporaryDirectory(prefix="gm-purposes-") as tmp:
                sdir = Path(tmp) / fixture
                shutil.copytree(FIXTURES / fixture, sdir)
                scenario = model.load_scenario(sdir)
                self.assertEqual([p["id"] for p in scenario.data["purposes"]], list(purposes))
                compose.compose(sdir, REPO, check=True)

    def test_the_runner_layer_is_the_purposes_material(self):
        """compose/<runner>/ of each fixture: the purposes' material/runner/
        files, merged (jobs, queries, connections: each purpose's entries as
        written), the scripts byte for byte."""
        for fixture, purposes in CLINIC_PURPOSES.items():
            sdir = FIXTURES / fixture
            data = yaml.safe_load((sdir / "scenario.yaml").read_text())
            for entry in data["purposes"]:
                runner = entry["parts"].get("runner")
                if runner is None:
                    continue
                material = REPO / "purposes" / entry["id"] / "material" / "runner"
                layer = sdir / "compose" / runner
                with self.subTest(fixture=fixture, purpose=entry["id"]):
                    queries = yaml.safe_load((layer / "queries.yaml").read_text())["queries"]
                    for key, value in yaml.safe_load((material / "queries.yaml").read_text())["queries"].items():
                        self.assertEqual(queries.get(key), value)
                    jobs = {j["name"]: j for j in yaml.safe_load((layer / "jobs.yaml").read_text())["jobs"]}
                    for job in yaml.safe_load((material / "jobs.yaml").read_text())["jobs"]:
                        self.assertEqual(jobs.get(job["name"]), job)
                    conns = yaml.safe_load((layer / "schedule.yaml").read_text())["connections"]
                    for name, value in yaml.safe_load((material / "schedule.yaml").read_text())["connections"].items():
                        self.assertEqual(conns.get(name), value)
                    for script in sorted(p for p in (material / "scripts").iterdir() if p.suffix == ".py"):
                        self.assertEqual((layer / "scripts" / script.name).read_bytes(), script.read_bytes())


if __name__ == "__main__":
    unittest.main()
