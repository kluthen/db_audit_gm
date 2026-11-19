"""publish-main's script, game-mode/publish.py (v0.7 master spec 8.2, 8.3;
capture W1 items 2, 4 and 5; spec D575): each check refuses its fixture
and passes the clean one, --check-only writes nothing, and the commit mode
commits one snapshot on main, naming the dev commit, without ever pushing.

Each test copies tools/tests/fixtures/publish/clean/ (its README says how
names are stored) into a fixture repository of its own on branch dev,
with the real game-mode/paths and game-mode/spoiler-words, and changes one
thing. This repository's main is never touched."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tools.tests import FIXTURES, REPO_ROOT

PUBLISH = REPO_ROOT / "game-mode" / "publish.py"
CLEAN = FIXTURES / "publish" / "clean"
REAL_LISTS = ("game-mode/paths", "game-mode/spoiler-words")
IDENTITY = ["-c", "user.name=test", "-c", "user.email=test@example.invalid"]


def git_env():
    """The environment without the caller's GIT_* variables (a hook's
    GIT_DIR would point the fixture's git at another repository), with an
    identity for the commit mode."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_AUTHOR_NAME="test", GIT_AUTHOR_EMAIL="test@example.invalid",
               GIT_COMMITTER_NAME="test", GIT_COMMITTER_EMAIL="test@example.invalid")
    return env


def stored_name(part):
    if part.startswith("dot-"):
        part = "." + part[len("dot-"):]
    if part.endswith(".fixture"):
        part = part[:-len(".fixture")]
    return part


class PublishTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="publish-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        self.root = self.tmp / "repo"
        for source in sorted(CLEAN.rglob("*")):
            if source.is_file() and "__pycache__" not in source.parts:
                rel = Path(*(stored_name(p) for p in source.relative_to(CLEAN).parts))
                (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, self.root / rel)
        for rel in REAL_LISTS:
            shutil.copy2(REPO_ROOT / rel, self.root / rel)
        self.git("init", "-q", "-b", "dev")
        self.commit("fixture")

    # --- helpers ---

    def git(self, *args):
        return subprocess.run(["git", *IDENTITY, *args], cwd=self.root, env=git_env(),
                              check=True, capture_output=True, text=True).stdout.strip()

    def commit(self, message="change", force=()):
        if force:
            self.git("add", "-f", "--", *force)
        self.git("add", "-A")
        self.git("commit", "-q", "--allow-empty", "-m", message)
        return self.git("rev-parse", "HEAD")

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def append(self, rel, text):
        with open(self.root / rel, "a") as f:
            f.write(text)

    def remove(self, rel):
        (self.root / rel).unlink()

    def publish(self, *args):
        return subprocess.run([sys.executable, str(PUBLISH), "--repo", str(self.root), *args],
                              cwd=self.tmp, env=git_env(), capture_output=True, text=True)

    def check(self, *args):
        return self.publish("--check-only", *args)

    def findings(self, proc, check=None):
        lines = [line for line in proc.stdout.splitlines() if line]
        return [line for line in lines if check is None or line.startswith(check + ": ")]

    def assert_refused(self, proc, *expected):
        self.assertEqual(proc.returncode, 1, proc.stdout + proc.stderr)
        for line in expected:
            self.assertIn(line, self.findings(proc))

    def ref(self, name):
        return subprocess.run(["git", "rev-parse", "-q", "--verify", name], cwd=self.root,
                              env=git_env(), capture_output=True, text=True).stdout.strip()


class CleanFixtureTest(PublishTest):
    def test_clean_fixture_passes_and_check_only_writes_nothing(self):
        head = self.ref("HEAD")
        proc = self.check()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertEqual(self.ref("HEAD"), head)
        self.assertEqual(self.ref("refs/heads/main"), "")
        self.assertEqual(self.git("status", "--porcelain", "--ignored"), "")
        self.assertEqual(self.git("for-each-ref", "--format=%(refname)"), "refs/heads/dev")

    def test_provenance_mention_is_not_a_pointer(self):
        # The clean fixture names specs/ paths as provenance only.
        self.assertIn("specs/versions/", (self.root / "domains/shop/docs/gm.md").read_text())
        self.assertEqual(self.findings(self.check(), "pointer"), [])

    def test_dev_files_are_replaced_by_game_modes(self):
        # The dev README, CLAUDE.md and settings would each be refused.
        self.assertEqual(self.check().returncode, 0)
        self.assertIn("aged", (self.root / "README.md").read_text())


class DevOnlyTest(PublishTest):
    def test_a_dev_only_path_left_out_of_paths_is_refused(self):
        text = (self.root / "game-mode/paths").read_text()
        self.write("game-mode/paths", text.replace("\nissues/\n", "\n"))
        self.commit()
        self.assert_refused(
            self.check(),
            "dev-only: issues/ISS-001.md: a dev-only path (master spec 8.2)",
            "dev-only: game-mode/paths: issues/ (master spec 8.2) is not listed")

    def test_a_glob_entry_removes_every_match(self):
        self.write("bricks/pg2/sbom/x.json", "{}\n")
        self.commit()
        self.assertEqual(self.check().returncode, 0)

    def test_a_missing_paths_file_is_refused(self):
        self.remove("game-mode/paths")
        self.commit()
        proc = self.check()
        self.assertEqual(proc.returncode, 1)
        self.assertTrue(any(f.startswith("dev-only: game-mode/paths: missing at ")
                            for f in self.findings(proc)), proc.stdout)
        self.assertEqual(self.findings(proc, "dev-only")[1:], [])   # 8.2's list still removes


class PointerTest(PublishTest):
    def test_a_link_into_specs_is_refused(self):
        self.append("domains/shop/docs/gm.md",
                    "\nThe tables: [the shop domain](../../../specs/versions/v0.5/shop.md#t).\n")
        self.commit()
        self.assert_refused(self.check(),
                            "pointer: domains/shop/docs/gm.md:5: links to "
                            "specs/versions/v0.5/shop.md")

    def test_an_instruction_to_open_a_dev_only_path_is_refused(self):
        self.append("domains/shop/docs/gm.md",
                    "\nRead `issues/ISS-001.md` before deploying.\n"
                    "For the checks, see tools/tests/check.sh.\n")
        self.commit()
        self.assert_refused(
            self.check(),
            "pointer: domains/shop/docs/gm.md:5: tells its reader to open issues/ISS-001.md",
            "pointer: domains/shop/docs/gm.md:6: tells its reader to open tools/tests/check.sh")

    def test_a_link_outside_dev_only_paths_and_a_url_pass(self):
        self.append("domains/shop/docs/gm.md",
                    "\nSee [the brick](../../../bricks/pg/brick.yaml) and "
                    "[the spec site](https://example.invalid/specs/x).\n")
        self.commit()
        self.assertEqual(self.check().returncode, 0)


class SpoilerTest(PublishTest):
    def test_an_aging_word_in_the_game_readme_is_refused(self):
        self.append("game-mode/README.md", "\nThe shop's data is AGED before you arrive.\n")
        self.commit()
        self.assert_refused(self.check(), 'spoiler: README.md:5: "aged"')

    def test_a_phrase_and_a_fault_name_in_the_assistant_definitions_are_refused(self):
        self.append(".claude/agents/game-assistant.md", "Never read the answer   key.\n")
        self.append(".opencode/agents/game-assistant.md", "Mind pg-role-superuser.\n")
        self.commit()
        self.assert_refused(
            self.check(),
            'spoiler: .claude/agents/game-assistant.md:6: "answer key"',
            'spoiler: .opencode/agents/game-assistant.md:6: fault name "pg-role-superuser"')

    def test_whole_words_only(self):
        # "engaged" and "staged" (in the clean definitions) carry "aged".
        self.append("game-mode/CLAUDE.md", "Refill nothing; prefilled forms are fine.\n")
        self.commit()
        self.assertEqual(self.check().returncode, 0)

    def test_development_matter_in_claude_md_is_refused(self):
        self.append("game-mode/CLAUDE.md", "The open issues are in issues/.\n")
        self.commit()
        self.assert_refused(self.check(), "dev-matter: CLAUDE.md:4: names issues/")

    def test_a_missing_word_list_is_refused(self):
        self.remove("game-mode/spoiler-words")
        self.commit()
        proc = self.check()
        self.assertEqual(proc.returncode, 1)
        self.assertTrue(any(f.startswith("spoiler: game-mode/spoiler-words: missing at ")
                            for f in self.findings(proc)), proc.stdout)


class ReplaceTest(PublishTest):
    def test_a_missing_game_readme_is_refused(self):
        self.remove("game-mode/README.md")
        self.commit()
        self.assert_refused(self.check(),
                            "replace: game-mode/README.md: missing; main would carry no "
                            "README.md")


class SkillsTest(PublishTest):
    def test_a_gm_skill_left_on_is_refused(self):
        self.write(".claude/skills/game-master-setup/SKILL.md",
                   "---\nname: game-master-setup\ndescription: x\n---\n")
        self.commit()
        self.assert_refused(
            self.check(),
            'skills: .claude/skills/game-master-setup/SKILL.md: GM skill "game-master-setup" '
            'is not "off" in .claude/game-assistant.settings.json')

    def test_a_gm_skill_turned_off_passes(self):
        self.write(".claude/skills/game-master-setup/SKILL.md",
                   "---\nname: game-master-setup\ndescription: x\n---\n")
        path = self.root / ".claude/game-assistant.settings.json"
        settings = json.loads(path.read_text())
        settings["skillOverrides"]["game-master-setup"] = "off"
        path.write_text(json.dumps(settings))
        self.commit()
        self.assertEqual(self.check().returncode, 0)


class IgnoredAndLocalTest(PublishTest):
    def test_an_ignored_file_and_a_local_implementation_are_refused(self):
        self.write("scenarios/demo/local/pg1/playground.yaml", "x: 1\n")
        self.write("tools/gm/__pycache__/model.pyc", "x")
        self.commit(force=["scenarios/demo/local", "tools/gm/__pycache__"])
        self.assert_refused(
            self.check(),
            "local: scenarios/demo/local/: a local implementation",
            "ignored: scenarios/demo/local/: git-ignored by the tree's .gitignore",
            "ignored: tools/gm/__pycache__/: git-ignored by the tree's .gitignore")

    def test_a_bricks_usr_local_is_not_a_local_implementation(self):
        self.write("bricks/pg/rootfs/usr/local/bin/tool", "#!/bin/sh\n")
        self.commit()
        self.assertEqual(self.check().returncode, 0)


class AgentsTest(PublishTest):
    def test_a_missing_dialect_is_refused(self):
        self.remove(".opencode/agents/game-master.md")
        self.commit()
        self.assert_refused(self.check(),
                            "agents: .opencode/agents/game-master.md: missing "
                            "(the GM, OpenCode)")


class MemoryTest(PublishTest):
    def test_memory_left_on_is_refused(self):
        self.write("game-mode/settings.json", '{"autoMemoryEnabled": true}\n')
        self.commit()
        self.assert_refused(self.check(),
                            "memory: .claude/settings.json: autoMemoryEnabled is not false")

    def test_memory_unset_is_refused(self):
        self.write("game-mode/settings.json", "{}\n")
        self.commit()
        self.assert_refused(self.check(),
                            "memory: .claude/settings.json: autoMemoryEnabled is not false")


class FormatTest(PublishTest):
    def test_a_scenario_failing_the_format_check_is_refused(self):
        self.append("scenarios/demo/scenario.yaml", "missing: story: missing\n")
        self.commit()
        self.assert_refused(self.check(), "format: scenarios/demo/scenario.yaml: story: missing")

    def test_a_loader_that_cannot_run_is_refused(self):
        self.write("tools/gm/model.py", "raise ImportError('broken loader')\n")
        self.commit()
        self.assert_refused(self.check(),
                            "format: tools/gm/model.py: the loader did not run: "
                            "ImportError: broken loader")


class FromRevTest(PublishTest):
    def test_from_checks_the_named_commit(self):
        old = self.ref("HEAD")
        self.remove(".claude/agents/game-master.md")
        self.commit()
        self.assertEqual(self.check().returncode, 1)
        self.assertEqual(self.check("--from", old).returncode, 0)


class UsageTest(PublishTest):
    def test_an_unknown_rev_is_a_usage_error(self):
        proc = self.check("--from", "no-such-rev")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("no-such-rev: not a commit", proc.stderr)

    def test_an_unknown_flag_is_a_usage_error(self):
        self.assertEqual(self.publish("--push").returncode, 2)

    def test_a_folder_outside_git_is_an_error(self):
        proc = subprocess.run([sys.executable, str(PUBLISH), "--check-only", "--repo",
                               str(self.tmp)], env=git_env(), capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2, proc.stderr)


class CommitModeTest(PublishTest):
    """The commit mode, in fixture repositories only (wave 1 never commits
    to this repository's main)."""

    def setUp(self):
        super().setUp()
        self.remote = self.tmp / "remote.git"
        subprocess.run(["git", "init", "-q", "--bare", str(self.remote)], env=git_env(),
                       check=True)
        self.git("remote", "add", "origin", str(self.remote))

    def remote_refs(self):
        return subprocess.run(["git", "-C", str(self.remote), "for-each-ref"], env=git_env(),
                              capture_output=True, text=True, check=True).stdout

    def test_commits_one_snapshot_on_main_naming_the_dev_commit_and_never_pushes(self):
        self.git("branch", "main")                     # main's history so far
        old_main = self.ref("refs/heads/main")
        dev = self.ref("HEAD")
        proc = self.publish()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        main = self.ref("refs/heads/main")
        self.assertNotEqual(main, old_main)
        self.assertEqual(self.git("rev-list", "--parents", "-n", "1", main).split(),
                         [main, old_main])
        self.assertIn(dev, self.git("log", "-1", "--format=%B", main))
        files = self.git("ls-tree", "-r", "--name-only", main).splitlines()
        for gone in ("specs/README.md", "issues/ISS-001.md", ".tech", "tools/tests/check.sh",
                     "bricks/pg/sbom/pg.cdx.json", "game-mode/paths", "game-mode/publish.py",
                     ".claude/skills/publish-main/SKILL.md"):
            self.assertNotIn(gone, files)
        for kept in ("bricks/pg/brick.yaml", ".claude/skills/game-master/SKILL.md",
                     ".opencode/agents/game-master.md", "scenarios/demo/scenario.yaml"):
            self.assertIn(kept, files)
        for target, source in (("README.md", "game-mode/README.md"),
                               ("CLAUDE.md", "game-mode/CLAUDE.md"),
                               (".claude/settings.json", "game-mode/settings.json")):
            self.assertEqual(self.git("show", f"{main}:{target}"),
                             (self.root / source).read_text().strip())
        self.assertIn("Not pushed", proc.stdout)
        self.assertIn(f"git -C {self.root} push origin main", proc.stdout)
        self.assertEqual(self.remote_refs(), "")
        self.assertEqual(self.ref("HEAD"), dev)
        self.assertEqual(self.git("status", "--porcelain"), "")

        again = self.publish()                         # same tree: nothing new
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertIn("nothing committed", again.stdout)
        self.assertEqual(self.ref("refs/heads/main"), main)

    def test_creates_main_when_absent(self):
        proc = self.publish()
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
        main = self.ref("refs/heads/main")
        self.assertEqual(self.git("rev-list", "--parents", "-n", "1", main).split(), [main])

    def test_findings_commit_nothing(self):
        self.git("branch", "main")
        old_main = self.ref("refs/heads/main")
        self.remove(".claude/agents/game-master.md")
        self.commit()
        proc = self.publish()
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(self.ref("refs/heads/main"), old_main)

    def test_refuses_when_main_is_checked_out(self):
        self.git("branch", "main")
        old_main = self.ref("refs/heads/main")
        self.git("worktree", "add", "-q", str(self.tmp / "main-wt"), "main")
        proc = self.publish()
        self.assertEqual(proc.returncode, 2)
        self.assertIn("main is checked out in", proc.stderr)
        self.assertEqual(self.ref("refs/heads/main"), old_main)


if __name__ == "__main__":
    unittest.main()
