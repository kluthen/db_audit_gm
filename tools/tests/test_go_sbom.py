"""The Go-module SBOMs the daily cve-watch sweep reads for the release
binaries (bricks/<brick>/sbom/*.cdx.json, written by tools/go-sbom) record
the version and archive checksum their brick's Dockerfile pins now. Offline;
on failure, run `tools/go-sbom generate <brick>` and commit the SBOMs."""

import subprocess
import sys
import unittest

from tools.tests import REPO_ROOT


class TestGoSbom(unittest.TestCase):

    def test_sboms_follow_the_dockerfiles(self):
        proc = subprocess.run([sys.executable, "-I", str(REPO_ROOT / "tools" / "go-sbom"), "check"],
                              capture_output=True, text=True, cwd=REPO_ROOT)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)


if __name__ == "__main__":
    unittest.main()
