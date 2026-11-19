"""The launcher, tools/play (v0.7 master spec 7.3, 7.6; capture W1 item 3):
`assistant` runs the assistant in Claude Code or OpenCode, `gm` is not yet
available, and the launcher refuses a checkout on branch dev unless given
--dev. Each test runs a copy of the script in a fixture repository of its
own (dev is never created here), with the fake `claude` and `opencode` of
fakebin/ first on PATH."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from tools.tests import FAKE_BIN, REPO_ROOT

PLAY = REPO_ROOT / "tools" / "play"

CLAUDE_ASSISTANT = ["claude", "--agent", "game-assistant",
                    "--settings", ".claude/game-assistant.settings.json"]
OPENCODE_ASSISTANT = ["opencode", "--agent", "game-assistant"]

DEV_REFUSAL = ("tools/play: this checkout is on branch dev; a game is played "
               "from a fresh clone of main (--dev overrides, for the build's tests)")
GM_NOT_YET = "tools/play gm: not yet available"


def git_env():
    """The environment without the caller's GIT_* variables (a hook's
    GIT_DIR would point the fixture's git at another repository)."""
    return {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}


class PlayTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="play-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name).resolve()
        self.root = self.tmp / "clone"
        (self.root / "tools").mkdir(parents=True)
        shutil.copy2(PLAY, self.root / "tools" / "play")
        self.git("init", "-q", "-b", "main")
        self.git("add", "-A")
        self.git("-c", "user.name=test", "-c", "user.email=test@example.invalid",
                 "commit", "-q", "-m", "fixture")
        self.record = self.tmp / "record"

    def git(self, *args):
        subprocess.run(["git", *args], cwd=self.root, env=git_env(),
                       check=True, capture_output=True)

    def play(self, *args, cwd=None, exit_status=None):
        env = git_env()
        env["PATH"] = f"{FAKE_BIN}{os.pathsep}{env.get('PATH', '')}"
        env["DBAGM_FAKE_RECORD"] = str(self.record)
        if exit_status is not None:
            env["DBAGM_FAKE_EXIT"] = str(exit_status)
        return subprocess.run([str(self.root / "tools" / "play"), *args],
                              cwd=str(cwd or self.root), env=env,
                              capture_output=True, text=True)

    def recorded(self):
        """`(working directory, [tool, *arguments])` the fake ran with."""
        lines = self.record.read_text().splitlines()
        return lines[0], lines[1:]

    def assert_ran(self, proc, command):
        self.assertEqual(proc.returncode, 0, proc.stderr)
        cwd, ran = self.recorded()
        self.assertEqual(ran, command)
        self.assertEqual(cwd, str(self.root))

    def assert_usage_error(self, proc):
        self.assertEqual(proc.returncode, 2)
        self.assertIn("usage: tools/play <gm|assistant> [--opencode] [--dev]", proc.stderr)
        self.assertEqual(proc.stdout, "")
        self.assertFalse(self.record.exists())

    # assistant

    def test_assistant_runs_claude_with_its_settings(self):
        self.assert_ran(self.play("assistant"), CLAUDE_ASSISTANT)

    def test_assistant_opencode_runs_opencode(self):
        self.assert_ran(self.play("assistant", "--opencode"), OPENCODE_ASSISTANT)

    def test_runs_from_the_repository_root(self):
        elsewhere = self.root / "deep" / "er"
        elsewhere.mkdir(parents=True)
        self.assert_ran(self.play("assistant", cwd=elsewhere), CLAUDE_ASSISTANT)
        self.assert_ran(self.play("assistant", "--opencode", cwd=self.tmp),
                        OPENCODE_ASSISTANT)

    def test_the_tools_exit_status_is_the_launchers(self):
        proc = self.play("assistant", exit_status=3)
        self.assertEqual(proc.returncode, 3)
        self.assertEqual(self.recorded()[1], CLAUDE_ASSISTANT)

    # the branch check

    def test_refuses_branch_dev_naming_why(self):
        self.git("checkout", "-q", "-b", "dev")
        for args in (["assistant"], ["assistant", "--opencode"], ["gm"]):
            with self.subTest(args=args):
                proc = self.play(*args)
                self.assertEqual(proc.returncode, 1)
                self.assertEqual(proc.stderr.strip(), DEV_REFUSAL)
                self.assertFalse(self.record.exists())

    def test_dev_flag_overrides_in_any_order(self):
        self.git("checkout", "-q", "-b", "dev")
        self.assert_ran(self.play("assistant", "--dev"), CLAUDE_ASSISTANT)
        self.assert_ran(self.play("assistant", "--dev", "--opencode"), OPENCODE_ASSISTANT)
        self.assert_ran(self.play("assistant", "--opencode", "--dev"), OPENCODE_ASSISTANT)

    def test_other_branches_and_detached_head_run(self):
        self.git("checkout", "-q", "-b", "develop")
        self.assert_ran(self.play("assistant"), CLAUDE_ASSISTANT)
        self.git("checkout", "-q", "--detach")
        self.assert_ran(self.play("assistant"), CLAUDE_ASSISTANT)

    # gm, until chunk 5

    def test_gm_is_not_yet_available(self):
        for args in (["gm"], ["gm", "--opencode"], ["gm", "--dev"]):
            with self.subTest(args=args):
                proc = self.play(*args)
                self.assertEqual(proc.returncode, 1)
                self.assertEqual(proc.stderr.strip(), GM_NOT_YET)
                self.assertFalse(self.record.exists())

    # usage

    def test_unknown_verb_prints_the_usage(self):
        for args in (["referee"], [], ["--opencode", "assistant"], ["Assistant"]):
            with self.subTest(args=args):
                self.assert_usage_error(self.play(*args))

    def test_unknown_option_prints_the_usage(self):
        for args in (["assistant", "--claude"], ["assistant", "extra"],
                     ["gm", "--dev", "-x"]):
            with self.subTest(args=args):
                self.assert_usage_error(self.play(*args))

    def test_help_prints_the_usage_and_runs_nothing(self):
        for args in (["-h"], ["--help"], ["assistant", "--help"], ["gm", "-h"]):
            with self.subTest(args=args):
                proc = self.play(*args)
                self.assertEqual(proc.returncode, 0)
                self.assertIn("usage: tools/play <gm|assistant>", proc.stdout)
                self.assertEqual(proc.stderr, "")
                self.assertFalse(self.record.exists())


class LauncherFileTest(unittest.TestCase):
    def test_posix_shell_and_executable(self):
        self.assertTrue(PLAY.read_text().startswith("#!/bin/sh\n"))
        self.assertTrue(os.access(PLAY, os.X_OK))
        subprocess.run(["sh", "-n", str(PLAY)], check=True)

    def test_the_settings_it_passes_exist(self):
        self.assertTrue((REPO_ROOT / ".claude" / "game-assistant.settings.json").is_file())
        self.assertTrue((REPO_ROOT / ".claude" / "agents" / "game-assistant.md").is_file())
        self.assertTrue((REPO_ROOT / ".opencode" / "agents" / "game-assistant.md").is_file())


if __name__ == "__main__":
    unittest.main()
