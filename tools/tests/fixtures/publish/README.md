# publish-main's fixture

`clean/` is a small repository tree that passes every check of
`game-mode/publish.py`; `tools/tests/test_publish_main.py` copies it into
a fixture repository, adds the real `game-mode/paths` and
`game-mode/spoiler-words`, and changes one thing per test.

Names are stored so that nothing here acts on this repository or on a
session working in it: a leading `dot-` stands for `.` (`dot-claude/` is
`.claude/`, `dot-gitignore` is `.gitignore`), and a trailing `.fixture` is
dropped (`CLAUDE.md.fixture` is `CLAUDE.md`).
