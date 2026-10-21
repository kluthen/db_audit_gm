"""Every brick's GM documentation has the required sections (spec D56)."""

import re
import unittest

from tools.tests import REPO_ROOT

# specs/formats.md, "`docs/gm.md` must contain (D56)"; the format skill's
# templates/brick-gm.md carries the same headings.
REQUIRED_SECTIONS = ("Purpose", "Placement", "Configuration", "Connections", "Access",
                     "Footprint", "Supported faults", "Checks", "Known limits")
TEMPLATE = REPO_ROOT / ".claude" / "skills" / "scenario-format" / "templates" / "brick-gm.md"

FENCE_RE = re.compile(r"^(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
COMMENT_RE = re.compile(r"<!--.*?-->", re.S)


def level2_sections(text):
    """`[(heading, body)]` for every level-2 heading, outside code fences;
    a body runs to the next level-2 heading, its subsections included."""
    sections, fenced = [], False
    for line in COMMENT_RE.sub("", text).splitlines():
        if FENCE_RE.match(line):
            fenced = not fenced
        match = None if fenced else HEADING_RE.match(line)
        if match and len(match.group(1)) == 2:
            sections.append((match.group(2), []))
        elif sections:
            sections[-1][1].append(line)
    return [(name, "\n".join(body).strip()) for name, body in sections]


class TestBrickGmDocs(unittest.TestCase):

    def assertRequiredSections(self, text):
        sections = level2_sections(text)
        names = [name for name, _ in sections]
        required = [name for name in names if name in REQUIRED_SECTIONS]
        self.assertEqual(required, list(REQUIRED_SECTIONS),
                         "the nine required sections, once each, in order")
        self.assertEqual(names[:len(REQUIRED_SECTIONS)], list(REQUIRED_SECTIONS),
                         "a brick's own sections come after Known limits")
        for name, body in sections:
            if name in REQUIRED_SECTIONS:
                self.assertTrue(body, f"section {name} is empty")

    def test_every_brick_has_the_required_sections(self):
        bricks = sorted(p for p in (REPO_ROOT / "bricks").iterdir() if p.is_dir())
        self.assertTrue(bricks)
        for brick_dir in bricks:
            with self.subTest(brick=brick_dir.name):
                self.assertRequiredSections((brick_dir / "docs" / "gm.md").read_text())

    def test_the_template_has_the_required_sections(self):
        self.assertRequiredSections(TEMPLATE.read_text())

    def test_a_missing_or_empty_section_is_caught(self):
        good = "".join(f"## {name}\n\nText.\n\n" for name in REQUIRED_SECTIONS)
        self.assertRequiredSections(good)
        for bad in (good.replace("## Footprint\n\nText.\n\n", ""),
                    good.replace("## Footprint\n\nText.", "## Footprint\n"),
                    good.replace("## Checks", "## Check"),
                    "## Known limits\n\nText.\n\n" + good.replace("## Known limits", "## Notes"),
                    "```\n" + good + "```\n"):
            with self.assertRaises(AssertionError):
                self.assertRequiredSections(bad)


if __name__ == "__main__":
    unittest.main()
