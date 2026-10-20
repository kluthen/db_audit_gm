"""Unit tests of gmctl (tools/gm), and the helpers they share."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
FIXTURE_SCENARIO = FIXTURES / "fixture-audit"
GMCTL = REPO_ROOT / "tools" / "gmctl"

SUFFICIENT = {"cpu": "2", "memory": "4G", "disk": "20G"}
INSUFFICIENT = {"cpu": "0.5", "memory": "4G", "disk": "20G"}


class ScenarioCopyTest(unittest.TestCase):
    """Each test works on a fresh copy of the fixture scenario."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="gmctl-test-")
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.scenario = self.tmp / "fixture-audit"
        shutil.copytree(FIXTURE_SCENARIO, self.scenario)

    def edit_yaml(self, relpath, change):
        path = self.scenario / relpath
        data = yaml.safe_load(path.read_text())
        change(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def node(self, data, name):
        return next(n for n in data["nodes"] if n["name"] == name)


def run_gmctl(*args):
    env = dict(os.environ)
    return subprocess.run(
        [sys.executable, str(GMCTL), *map(str, args)],
        capture_output=True, text=True, env=env, cwd=str(REPO_ROOT),
    )
