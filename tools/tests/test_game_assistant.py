"""The game assistant's definitions and session settings (v0.7 master spec
6, 7.2, 7.4): both dialects carry the same prompt, the shell history filter
they give drops every line carrying a credential (6.4), and the settings
file turns the GM's skills off, the automatic memory off, and denies the
three speed-bump commands."""

import json
import re
import subprocess
import unittest

from tools.tests import REPO_ROOT

CLAUDE_AGENT = REPO_ROOT / ".claude" / "agents" / "game-assistant.md"
OPENCODE_AGENT = REPO_ROOT / ".opencode" / "agents" / "game-assistant.md"
SETTINGS = REPO_ROOT / ".claude" / "game-assistant.settings.json"

# Today's GM skills (7.4); the chunk that splits the GM adds its own.
GM_SKILLS = ("game-master", "scenario-format", "scenario-document",
             "data-register", "network-overview")

# The filter is given as `grep -a -v -i -E '<pattern>' ~/.bash_history`.
FILTER_RE = re.compile(r"grep -a -v -i -E '([^']+)' ~/\.bash_history")

KEPT = [
    "ls -la ~/reports/",
    "ssh -p 2222 player@10.0.0.5",
    "sudo -u postgres gm-validate",
    "curl -s http://monitoring:9090/api/v1/targets | jq .",
    "pgbadger --anonymize /var/log/postgresql/postgresql.log -o ~/reports/pgb.html",
    "psql -h db1 -U auditor -d shop",
    "less ~/report.md",
]
DROPPED = [
    "curl -H 'Authorization: Bearer eyJhbGciOi.abc' https://partner.example/status",
    "curl -H \"authorization: Basic YWRtaW46c2VjcmV0\" http://front/",
    "PGPASSWORD=s3cret psql -h db1 -U app shop",
    "psql 'host=db1 user=app password=s3cret dbname=shop'",
    "psql postgresql://app:s3cret@db1:5432/shop",
    "curl -u admin:s3cret http://partner/status",
    "curl --user=admin:s3cret http://partner/status",
    "export API_TOKEN=abc123",
    "curl -H 'X-Api-Key: abc123' https://partner/",
    "echo 'db1:5432:*:app:s3cret' >> ~/.pgpass",
    "export CLIENT_SECRET=abc",
]


def split_definition(path):
    """`(front matter, body)` of an agent definition."""
    text = path.read_text()
    match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.S)
    if not match:
        raise AssertionError(f"{path}: no front matter")
    return match.group(1), match.group(2)


class DefinitionsTest(unittest.TestCase):
    def test_same_prompt_in_both_dialects(self):
        self.assertEqual(split_definition(CLAUDE_AGENT)[1],
                         split_definition(OPENCODE_AGENT)[1])

    def test_claude_code_tools(self):
        front, _ = split_definition(CLAUDE_AGENT)
        self.assertIn("name: game-assistant", front.splitlines())
        tools = re.search(r"^tools:\s*(.*)$", front, re.M).group(1)
        self.assertEqual([t.strip() for t in tools.split(",")],
                         ["Read", "Write", "Edit", "Bash", "WebFetch", "WebSearch"])

    def test_opencode_permissions(self):
        front, _ = split_definition(OPENCODE_AGENT)
        lines = front.splitlines()
        self.assertIn("mode: primary", lines)
        for line in ("  skill: deny", "  task: deny", "  webfetch: allow",
                     "  websearch: allow", "  todowrite: allow"):
            self.assertIn(line, lines)
        # Last match wins: the catch-all comes first.
        edit = lines[lines.index("  edit:") + 1:lines.index("  edit:") + 3]
        self.assertEqual(edit, ['    "*": ask', '    "play/**": allow'])
        bash = lines[lines.index("  bash:") + 1:lines.index("  bash:") + 5]
        self.assertEqual(bash, ['    "*": allow', '    "psql*": deny',
                                '    "docker*": deny', '    "*gmctl*": deny'])


class HistoryFilterTest(unittest.TestCase):
    def test_filter_drops_credentials_only(self):
        _, body = split_definition(CLAUDE_AGENT)
        patterns = FILTER_RE.findall(body)
        self.assertTrue(patterns, "no history filter in the definition")
        self.assertEqual(len(set(patterns)), 1, "the filter differs between uses")
        result = subprocess.run(
            ["grep", "-a", "-v", "-i", "-E", patterns[0]],
            input="\n".join(KEPT + DROPPED) + "\n",
            capture_output=True, text=True, check=False)
        self.assertEqual(result.stdout.splitlines(), KEPT)


class SettingsTest(unittest.TestCase):
    def test_settings(self):
        settings = json.loads(SETTINGS.read_text())
        self.assertEqual(set(settings),
                         {"skillOverrides", "autoMemoryEnabled", "permissions"})
        for name in GM_SKILLS:
            self.assertEqual(settings["skillOverrides"].get(name), "off", name)
        self.assertTrue(all(v == "off" for v in settings["skillOverrides"].values()))
        self.assertIs(settings["autoMemoryEnabled"], False)
        self.assertEqual(settings["permissions"],
                         {"deny": ["Bash(psql:*)", "Bash(docker:*)",
                                   "Bash(tools/gmctl:*)"]})


if __name__ == "__main__":
    unittest.main()
