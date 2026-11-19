#!/usr/bin/env python3
"""publish-main: build `main`'s tree from a `dev` commit, check it, and
commit it as one snapshot on `main` (v0.7 master spec 8.2, 8.3; capture W1
items 2, 4 and 5 in specs/versions/v0.7/wave-log.md; spec D575).

    python3 game-mode/publish.py [--check-only] [--from <rev>] [--repo <path>]

The tree is built in a temporary index and checked out into a temporary
folder, never in the caller's checkout. Each finding is one line,
`<check>: <path>[:<line>]: <what>`. Exit 0: no finding (and, without
--check-only, `main` committed or already up to date); 1: findings, nothing
written; 2: a usage or git error. It never pushes: it prints the push
command, which runs only on the owner's word.
"""

import argparse
import json
import os
import posixpath
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT_REPO = Path(__file__).resolve().parent.parent

PATHS_FILE = "game-mode/paths"
SPOILER_FILE = "game-mode/spoiler-words"

# 8.3 step 1: the dev files replaced by game mode's.
REPLACED = {
    "README.md": "game-mode/README.md",
    "CLAUDE.md": "game-mode/CLAUDE.md",
    ".claude/settings.json": "game-mode/settings.json",
}

# 8.2's dev-only paths, the guard behind game-mode/paths: a tree carrying
# one of them is refused even if the rev's paths file forgot it.
SPEC_DEV_ONLY = (
    "specs/", "issues/", ".tech", "game-mode/", ".claude/skills/publish-main/",
    "tools/tests/", "tools/go-sbom", "tools/fake_aging/", "bricks/*/sbom/",
)

# 7.2: both agents, both dialects.
AGENTS = (
    (".claude/agents/game-master.md", "the GM, Claude Code"),
    (".opencode/agents/game-master.md", "the GM, OpenCode"),
    (".claude/agents/game-assistant.md", "the assistant, Claude Code"),
    (".opencode/agents/game-assistant.md", "the assistant, OpenCode"),
)
ASSISTANT_DEFINITIONS = (".claude/agents/game-assistant.md", ".opencode/agents/game-assistant.md")
ASSISTANT_SETTINGS = ".claude/game-assistant.settings.json"
GAME_SETTINGS = ".claude/settings.json"
SKILLS_DIR = ".claude/skills/"

# The files loaded into the assistant's session (8.3 step 2, 6.10).
SESSION_FILES = ("README.md", "CLAUDE.md") + ASSISTANT_DEFINITIONS

# A local implementation (master spec 5, 10.3), as .gitignore names it.
LOCAL_RE = re.compile(r"^(?!bricks/[^/]+/rootfs/)(.*?/)?local/")

# Telling the reader to open a path: one of these verbs before it, in the
# same clause.
OPEN_VERB_RE = re.compile(r"\b(read|open|consult|see|refer to|look at|look in|follow)\b",
                          re.IGNORECASE)
CLAUSE_END_RE = re.compile(r"[.;!?](\s|$)")
PATH_TOKEN_RE = re.compile(r"(?<![\w/.-])(?:\./|(?:\.\./)+)?([\w.-]+(?:/[\w.*-]*)*)")
INLINE_LINK_RE = re.compile(r"\]\(\s*<?([^)\s>]+)")
REFERENCE_LINK_RE = re.compile(r"^\s*\[[^\]]+\]:\s*<?(\S+?)>?(\s|$)")
URL_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9+.-]*:")

CHECK_ORDER = ("replace", "dev-only", "pointer", "dev-matter", "spoiler", "skills",
               "ignored", "local", "agents", "memory", "format")

GIT_ERROR = 2


class PublishError(Exception):
    """A usage or git error: exit 2."""


class Finding:
    def __init__(self, check, path, what, line=None):
        self.check, self.path, self.what, self.line = check, path, what, line

    def key(self):
        return (CHECK_ORDER.index(self.check), self.path, self.line or 0, self.what)

    def __str__(self):
        where = self.path if self.line is None else f"{self.path}:{self.line}"
        return f"{self.check}: {where}: {self.what}"


# --- git -------------------------------------------------------------------

def git_env(extra=None):
    """The environment without the caller's GIT_* variables (a hook's
    GIT_DIR or GIT_INDEX_FILE would point git elsewhere)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(extra or {})
    return env


def git(repo, *args, env=None, data=None, check=True):
    proc = subprocess.run(["git", "-C", str(repo), *args], env=git_env(env), input=data,
                          capture_output=True)
    if check and proc.returncode != 0:
        msg = proc.stderr.decode(errors="replace").strip().splitlines()
        raise PublishError(f"git {args[0]}: {msg[-1] if msg else 'failed'}")
    return proc


def git_text(repo, *args, env=None):
    return git(repo, *args, env=env).stdout.decode().strip()


def show(repo, rev, path):
    """The file's content at rev, or None when the rev has no such file."""
    proc = git(repo, "cat-file", "blob", f"{rev}:{path}", check=False)
    return proc.stdout.decode("utf-8", errors="replace") if proc.returncode == 0 else None


# --- the lists --------------------------------------------------------------

def list_lines(text):
    """One entry per line, `#` comments and blank lines ignored."""
    out = []
    for line in (text or "").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def glob_regex(entry):
    """A regex matching a path (or a path written in text) that git's
    `:(glob)<entry>` pathspec would match."""
    is_dir = entry.endswith("/")
    body = entry.rstrip("/")
    out, i = "", 0
    while i < len(body):
        if body.startswith("**/", i):
            out, i = out + "(?:.*/)?", i + 3
        elif body.startswith("/**", i) and i + 3 == len(body):
            out, i = out + "(?:/.*)?", i + 3
        elif body.startswith("**", i):
            out, i = out + ".*", i + 2
        elif body[i] == "*":
            out, i = out + "[^/]*", i + 1
        elif body[i] == "?":
            out, i = out + "[^/]", i + 1
        else:
            out, i = out + re.escape(body[i]), i + 1
    return re.compile("^" + out + ("/.*$" if is_dir else "(?:/.*)?$"))


class DevOnly:
    def __init__(self, entries):
        self.entries = list(dict.fromkeys(entries))
        self.regexes = [glob_regex(e) for e in self.entries]

    def match(self, path):
        return any(r.match(path) for r in self.regexes)

    def pathspecs(self):
        """git pathspecs for the entries. A glob pathspec with a wildcard
        matches whole paths only, so a directory entry `d/` becomes
        `d/**`, and a plain entry `e` also gets `e/**`."""
        out = []
        for entry in self.entries:
            if entry.endswith("/"):
                out.append(f":(glob){entry}**")
            else:
                out += [f":(glob){entry}", f":(glob){entry}/**"]
        return out

    def prefilter(self):
        """A regex any text naming one of the paths contains: each entry's
        last component without a glob character."""
        words = []
        for entry in self.entries:
            literal = [c for c in entry.strip("/").split("/") if c and not re.search(r"[*?\[]", c)]
            words.append(re.escape(literal[-1] if literal else entry))
        return re.compile("|".join(words))


def spoiler_regexes(words, fault_names):
    terms = [(w, f'"{w}"') for w in words] + [(f, f'fault name "{f}"') for f in fault_names]
    out = []
    for term, label in terms:
        pattern = r"\s+".join(re.escape(part) for part in term.split())
        out.append((re.compile(r"(?<!\w)" + pattern + r"(?!\w)", re.IGNORECASE), label))
    return out


# --- step 1: the tree --------------------------------------------------------

def build_tree(repo, rev, dev_only, index, findings):
    """main's tree from rev (8.3 step 1): the tree id, written from a
    temporary index."""
    env = {"GIT_INDEX_FILE": str(index)}
    git(repo, "read-tree", rev, env=env)
    pathspecs = dev_only.pathspecs()
    removed = git(repo, "ls-files", "-z", "--", *pathspecs, env=env).stdout.split(b"\0")
    removed = [p for p in removed if p]
    removed += [t.encode() for t in REPLACED]
    git(repo, "update-index", "-z", "--force-remove", "--stdin", env=env,
        data=b"\0".join(removed) + b"\0")
    for target, source in REPLACED.items():
        entry = git(repo, "ls-tree", "-z", rev, "--", source).stdout.rstrip(b"\0").decode()
        if not entry:
            findings.append(Finding("replace", source, f"missing; main would carry no {target}"))
            continue
        meta, _ = entry.split("\t", 1)
        mode, _type, sha = meta.split()
        git(repo, "update-index", "--add", "--cacheinfo", f"{mode},{sha},{target}", env=env)
    return git_text(repo, "write-tree", env=env)


def checkout_tree(repo, index, dest):
    git(repo, "checkout-index", "-a", f"--prefix={dest}/", env={"GIT_INDEX_FILE": str(index)})


def tree_paths(repo, tree):
    out = git(repo, "ls-tree", "-r", "-z", "--name-only", tree).stdout.split(b"\0")
    return [p.decode() for p in out if p]


# --- step 2: the checks ------------------------------------------------------

def read_text(root, path):
    try:
        data = (root / path).read_bytes()
    except OSError:
        return None
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def check_dev_only(paths, dev_only, spec_dev_only, paths_listed, findings):
    for path in paths:
        if path in REPLACED:
            continue
        if dev_only.match(path) or spec_dev_only.match(path):
            findings.append(Finding("dev-only", path, "a dev-only path (master spec 8.2)"))
    if paths_listed is not None:
        for entry in spec_dev_only.entries:
            if entry not in paths_listed:
                findings.append(Finding("dev-only", PATHS_FILE,
                                        f"{entry} (master spec 8.2) is not listed"))


def path_tokens(line):
    """(position, path as written, without a leading ./ or ../) for each
    path-like token of a line."""
    for m in PATH_TOKEN_RE.finditer(line):
        yield m.start(), m.group(1)


def mentions(token, dev_only):
    token = token.rstrip(".,")
    return bool(token) and dev_only.match(token)


def link_targets(line):
    for regex in (INLINE_LINK_RE, REFERENCE_LINK_RE):
        for m in regex.finditer(line):
            yield m.group(1)


def resolve_link(path, target):
    target = target.split("#", 1)[0]
    if not target or URL_RE.match(target):
        return None
    if target.startswith("/"):
        resolved = posixpath.normpath(target.lstrip("/"))
    else:
        resolved = posixpath.normpath(posixpath.join(posixpath.dirname(path), target))
    if resolved.startswith("../") or resolved == "..":
        return None
    return resolved + ("/" if target.endswith("/") else "")


def check_pointers(root, paths, dev_only, findings):
    """No carried file telling its reader to open a dev-only path: a link
    into one, or an open verb (read, open, consult, see, refer to, look
    at or in, follow) before one in the same clause. A mention as
    provenance is not a pointer (8.2)."""
    prefilter = dev_only.prefilter()
    for path in paths:
        text = read_text(root, path)
        if text is None or not prefilter.search(text):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            reported = set()
            for target in link_targets(line):
                resolved = resolve_link(path, target)
                if resolved and dev_only.match(resolved) and resolved not in reported:
                    reported.add(resolved)
                    findings.append(Finding("pointer", path, f"links to {resolved}", number))
            for pos, token in path_tokens(line):
                token = token.rstrip(".,")
                if token in reported or not mentions(token, dev_only):
                    continue
                before = line[:pos]
                ends = list(CLAUSE_END_RE.finditer(before))
                clause = before[ends[-1].end():] if ends else before
                if OPEN_VERB_RE.search(clause[-60:]):
                    reported.add(token)
                    findings.append(Finding("pointer", path,
                                            f"tells its reader to open {token}", number))


def check_session_files(root, present, dev_only, spoilers, findings):
    """README.md, CLAUDE.md and the assistant's two definitions: no
    development matter (no dev-only path named), no spoiler word, no fault
    name (8.3 step 2, 6.10)."""
    for path in SESSION_FILES:
        if path not in present:
            continue
        text = read_text(root, path) or ""
        for number, line in enumerate(text.splitlines(), 1):
            seen = set()
            for _pos, token in path_tokens(line):
                token = token.rstrip(".,")
                if token not in seen and mentions(token, dev_only):
                    seen.add(token)
                    findings.append(Finding("dev-matter", path, f"names {token}", number))
            for regex, label in spoilers:
                if regex.search(line):
                    findings.append(Finding("spoiler", path, label, number))


def skill_name(root, skill_dir):
    text = read_text(root, f"{skill_dir}SKILL.md") or ""
    m = re.match(r"---\s*\n(.*?)\n---", text, re.DOTALL)
    if m:
        for line in m.group(1).splitlines():
            if line.startswith("name:"):
                return line.split(":", 1)[1].strip().strip("'\"")
    return skill_dir.rstrip("/").rsplit("/", 1)[-1]


def check_skills(root, paths, present, findings):
    """Every skill main carries is a GM skill (publish-main is dev-only),
    and each one is "off" in the assistant's settings file (7.4)."""
    skill_dirs = sorted({SKILLS_DIR + p[len(SKILLS_DIR):].split("/", 1)[0] + "/"
                         for p in paths if p.startswith(SKILLS_DIR) and
                         "/" in p[len(SKILLS_DIR):]})
    if not skill_dirs:
        return
    if ASSISTANT_SETTINGS not in present:
        findings.append(Finding("skills", ASSISTANT_SETTINGS, "missing"))
        return
    try:
        overrides = json.loads(read_text(root, ASSISTANT_SETTINGS) or "").get("skillOverrides")
    except (ValueError, AttributeError) as exc:
        findings.append(Finding("skills", ASSISTANT_SETTINGS, f"not a JSON object: {exc}"))
        return
    overrides = overrides if isinstance(overrides, dict) else {}
    for skill_dir in skill_dirs:
        name = skill_name(root, skill_dir)
        if overrides.get(name) != "off":
            findings.append(Finding("skills", f"{skill_dir}SKILL.md",
                                    f'GM skill "{name}" is not "off" in {ASSISTANT_SETTINGS}'))


def check_ignored(root, findings):
    """Nothing the tree's own .gitignore files ignore."""
    git(root, "init", "-q")
    out = git(root, "-c", "core.excludesFile=/dev/null", "ls-files", "-z", "-o", "-i",
              "--exclude-standard", "--directory").stdout.split(b"\0")
    for path in sorted(p.decode() for p in out if p):
        findings.append(Finding("ignored", path, "git-ignored by the tree's .gitignore"))


def check_local(paths, findings):
    dirs = sorted({LOCAL_RE.match(p).group(0) for p in paths if LOCAL_RE.match(p)})
    for path in dirs:
        findings.append(Finding("local", path, "a local implementation"))


def check_agents(present, findings):
    for path, what in AGENTS:
        if path not in present:
            findings.append(Finding("agents", path, f"missing ({what})"))


def check_memory(root, present, findings):
    if GAME_SETTINGS not in present:
        findings.append(Finding("memory", GAME_SETTINGS,
                                f"missing ({REPLACED[GAME_SETTINGS]} absent)"))
        return
    try:
        settings = json.loads(read_text(root, GAME_SETTINGS) or "")
    except ValueError as exc:
        findings.append(Finding("memory", GAME_SETTINGS, f"not JSON: {exc}"))
        return
    if not isinstance(settings, dict) or settings.get("autoMemoryEnabled") is not False:
        findings.append(Finding("memory", GAME_SETTINGS, "autoMemoryEnabled is not false"))


FORMAT_RUNNER = r"""
import json, sys
from pathlib import Path
sys.path.insert(0, ".")
from tools.gm import model
out = {}
for s in sorted(Path("scenarios").glob("*/scenario.yaml")):
    _scenario, missing = model.check_scenario(s.parent)
    out[s.parent.as_posix()] = [str(m) for m in missing]
print(json.dumps(out))
"""


def check_format(root, present, findings):
    """The loader's format check on every scenario, as gmctl runs it
    (tools.gm.model.check_scenario), with the built tree's own loader."""
    if not any(p.startswith("scenarios/") and p.endswith("/scenario.yaml") for p in present):
        return
    if "tools/gm/model.py" not in present:
        findings.append(Finding("format", "tools/gm/model.py", "missing: no loader to run"))
        return
    proc = subprocess.run([sys.executable, "-I", "-B", "-c", FORMAT_RUNNER], cwd=root,
                          capture_output=True, text=True, env=git_env())
    try:
        result = json.loads(proc.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        err = proc.stderr.strip().splitlines()
        findings.append(Finding("format", "tools/gm/model.py",
                                f"the loader did not run: {err[-1] if err else 'no output'}"))
        return
    for scenario, missing in result.items():
        for item in missing:
            findings.append(Finding("format", f"{scenario}/scenario.yaml", item))


def run_checks(repo, rev, workdir):
    """(tree id, findings)."""
    findings = []
    paths_text = show(repo, rev, PATHS_FILE)
    paths_listed = list_lines(paths_text) if paths_text is not None else None
    if paths_listed is None:
        findings.append(Finding("dev-only", PATHS_FILE, f"missing at {rev}"))
    spec_dev_only = DevOnly(SPEC_DEV_ONLY)
    dev_only = DevOnly((paths_listed or []) + list(SPEC_DEV_ONLY))
    tree = build_tree(repo, rev, DevOnly(paths_listed or SPEC_DEV_ONLY), workdir / "index",
                      findings)
    root = workdir / "tree"
    root.mkdir()
    checkout_tree(repo, workdir / "index", root)
    paths = tree_paths(repo, tree)
    present = set(paths)

    words_text = show(repo, rev, SPOILER_FILE)
    if words_text is None:
        findings.append(Finding("spoiler", SPOILER_FILE, f"missing at {rev}"))
    faults = sorted({p.split("/")[1] for p in
                     git(repo, "ls-tree", "-r", "--name-only", rev, "--", "faults/")
                     .stdout.decode().splitlines() if p.count("/") >= 2})
    spoilers = spoiler_regexes(list_lines(words_text), faults)

    check_dev_only(paths, DevOnly((paths_listed or [])), spec_dev_only, paths_listed, findings)
    check_pointers(root, paths, dev_only, findings)
    check_session_files(root, present, dev_only, spoilers, findings)
    check_skills(root, paths, present, findings)
    check_local(paths, findings)
    check_agents(present, findings)
    check_memory(root, present, findings)
    check_format(root, present, findings)
    check_ignored(root, findings)       # last: it makes the folder a repository
    return tree, sorted(findings, key=Finding.key)


# --- steps 3 and 4: the commit, the push command -----------------------------

def checked_out_main(repo):
    out = git_text(repo, "worktree", "list", "--porcelain")
    path = None
    for line in out.splitlines():
        if line.startswith("worktree "):
            path = line[len("worktree "):]
        elif line == "branch refs/heads/main":
            return path
    return None


def push_remote(repo):
    remotes = git_text(repo, "remote").split()
    if "origin" in remotes:
        return "origin"
    return remotes[0] if len(remotes) == 1 else "<remote>"


def commit_main(repo, rev, rev_sha, tree):
    where = checked_out_main(repo)
    if where:
        raise PublishError(f"main is checked out in {where}; publish from a checkout of dev")
    old = git(repo, "rev-parse", "--verify", "-q", "refs/heads/main", check=False)
    old = old.stdout.decode().strip() if old.returncode == 0 else None
    if old and git_text(repo, "rev-parse", f"{old}^{{tree}}") == tree:
        print(f"main already carries {rev} ({rev_sha[:12]})'s tree: nothing committed")
        return
    message = (f"Publish main from dev {rev_sha[:12]}\n\n"
               f"main's tree as publish-main built it from dev commit {rev_sha} ({rev}):\n"
               f"the dev-only paths of {PATHS_FILE} removed, README.md, CLAUDE.md and\n"
               f".claude/settings.json replaced by game mode's (master spec 8.3).\n")
    parents = ["-p", old] if old else []
    new = git(repo, "commit-tree", tree, *parents, data=message.encode()).stdout.decode().strip()
    git(repo, "update-ref", "-m", f"publish-main from {rev_sha}", "refs/heads/main", new,
        old or "0" * 40)
    print(f"main: {new[:12]}, published from dev {rev_sha[:12]} ({rev})")
    print("Not pushed. To push, on the owner's word only:")
    print(f"  git -C {repo} push {push_remote(repo)} main")


# --- the command --------------------------------------------------------------

def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="publish.py",
        description="Build main's tree from a dev commit, check it, and commit it as one "
                    "snapshot on main; never pushes (v0.7 master spec 8.3).")
    parser.add_argument("--check-only", action="store_true",
                        help="stop after the checks; write nothing")
    parser.add_argument("--from", dest="rev", default="HEAD", metavar="<rev>",
                        help="the dev commit to publish (default HEAD)")
    parser.add_argument("--repo", default=str(SCRIPT_REPO), metavar="<path>",
                        help="the repository (default: the one holding this script)")
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    repo = Path(args.repo).resolve()
    try:
        if not repo.is_dir():
            raise PublishError(f"{repo}: not a folder")
        git(repo, "rev-parse", "--git-dir")
        rev_sha = git(repo, "rev-parse", "--verify", "-q", f"{args.rev}^{{commit}}",
                      check=False)
        if rev_sha.returncode != 0:
            raise PublishError(f"{args.rev}: not a commit of {repo}")
        rev_sha = rev_sha.stdout.decode().strip()
        with tempfile.TemporaryDirectory(prefix="publish-main-") as tmp:
            tree, findings = run_checks(repo, rev_sha, Path(tmp))
        for finding in findings:
            print(finding)
        if findings:
            print(f"publish.py: {len(findings)} finding(s) on {args.rev} "
                  f"({rev_sha[:12]}); main not updated", file=sys.stderr)
            return 1
        if args.check_only:
            print(f"publish.py: no finding on {args.rev} ({rev_sha[:12]})", file=sys.stderr)
            return 0
        commit_main(repo, args.rev, rev_sha, tree)
        return 0
    except PublishError as exc:
        print(f"publish.py: {exc}", file=sys.stderr)
        return GIT_ERROR


if __name__ == "__main__":
    sys.exit(main())
