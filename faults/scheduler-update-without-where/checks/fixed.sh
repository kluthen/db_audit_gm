#!/bin/sh
# Sealed check of scheduler-update-without-where (master spec 8.1, v0.3
# master spec 6.5; capture W4 items 0 and 3). Run as root on the scheduler
# node; reads the node's files only, opens no connection, never runs the
# repository's code.
#
# FAULT_KEY names the queries.yaml key. Exit 1 while the live queries.yaml
# differs from what the program loaded (/run/scheduler/loaded: fixed but not
# reloaded, or not fixed), or while an UPDATE of the key's loaded entry (a
# query, every entry of a pool, every step of a sequence) has no WHERE of
# its own (at its own nesting level, comments and literals aside); exit 0
# once every UPDATE has one. Exit 2 on an error, a builder entry included
# (its SQL is code the check never runs).
set -u
python3 -I - "${FAULT_KEY:-}" <<'EOF'
import hashlib
import os
import re
import stat
import sys

import yaml

LIVE = "/srv/scheduler/repository/queries.yaml"
SEED = "/opt/gm/seed/queries.yaml"
LOADED = "/run/scheduler/loaded"


def done(code, line):
    print(line)
    sys.exit(code)


def regular(path):
    """A regular file's bytes, never through a symbolic link."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError as exc:
        done(2, f"cannot read {path}: {exc.strerror}")
    with os.fdopen(fd, "rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            done(2, f"{path} is not a regular file")
        return f.read()


def entry(raw, path, key):
    try:
        doc = yaml.safe_load(raw.decode("utf-8"))
    except (UnicodeDecodeError, yaml.YAMLError):
        done(2, f"{path} does not parse")
    queries = doc.get("queries") if isinstance(doc, dict) else None
    if not isinstance(queries, dict) or key not in queries:
        return None
    return queries[key]


def statements(value):
    """The SQL texts of an entry; None for a builder."""
    if isinstance(value, list):
        return [str(i.get("sql", "")) for i in value if isinstance(i, dict)]
    if isinstance(value, dict) and "builder" in value:
        return None
    if isinstance(value, dict) and "steps" in value:
        return [str(s.get("sql", "")) for s in value.get("steps") or [] if isinstance(s, dict)]
    if isinstance(value, dict):
        return [str(value.get("sql", ""))]
    return []


LEXEME = re.compile(r"""--[^\n]*|/\*.*?\*/|'(?:[^']|'')*'|\$([A-Za-z_0-9]*)\$.*?\$\1\$|"(?:[^"]|"")*"
                        |[A-Za-z_][A-Za-z_0-9$]*|\(|\)|;|.""", re.S | re.X)


def tokens(sql):
    """(word, depth) for every bare word, comments and literals dropped,
    quoted identifiers kept as a non-keyword; ';' resets nothing (depth)."""
    out, depth = [], 0
    for m in LEXEME.finditer(sql):
        t = m.group(0)
        if t.startswith(("--", "/*", "'", "$")) and not t[:1].isalpha():
            continue
        if t == "(":
            depth += 1
        elif t == ")":
            depth -= 1
        elif t == ";":
            out.append((";", depth))
        elif t[:1].isalpha() or t[:1] == "_" or t[:1] == '"':
            out.append((t.lower() if t[:1] != '"' else '"', depth))
    return out


def updates_without_where(sql):
    """How many UPDATE ... SET in the text have no WHERE at their level
    before their statement ends (a ';', or the level closing)."""
    toks, missing = tokens(sql), 0
    for i, (word, depth) in enumerate(toks):
        if word != "update":
            continue
        # an UPDATE statement: its SET follows at the same level (FOR UPDATE,
        # ON UPDATE and DO UPDATE SET aside: the last two have no WHERE of
        # their own to lose, FOR UPDATE has no SET)
        prev = toks[i - 1][0] if i else ""
        if prev in ("for", "on", "do", "no", "key"):
            continue
        has_set, has_where = False, False
        for word2, depth2 in toks[i + 1:]:
            if depth2 < depth or (word2 == ";" and depth2 == depth):
                break
            if depth2 == depth and word2 == "set":
                has_set = True
            elif depth2 == depth and word2 == "where" and has_set:
                has_where = True
                break
        if has_set and not has_where:
            missing += 1
    return missing


key = sys.argv[1]
if not key:
    done(2, "FAULT_KEY must be set.")
live_raw = regular(LIVE)
if entry(regular(SEED), SEED, key) is None:
    done(2, f"the key {key} is not in the planted {SEED}.")
live = entry(live_raw, LIVE, key)

loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
texts = statements(live) if live is not None else []
missing = sum(updates_without_where(t) for t in texts or [])
if digest != hashlib.sha256(live_raw).hexdigest():
    if texts is not None and missing:
        done(1, f"the {key} update still has no WHERE (queries.yaml changed elsewhere, not "
                "reloaded either).")
    done(1, f"queries.yaml is changed but not reloaded: the program still runs the {key} "
            "update as it was (sudo gm-reload-scheduler).")
if live is None:
    done(2, f"the key {key} is not in the loaded queries.yaml.")
if texts is None:
    done(2, f"the {key} entry is now a builder: its SQL is code, which the check does not run; "
            "judge it by hand.")
if missing:
    done(1, f"the {key} entry still has {missing} UPDATE(s) with no WHERE in the loaded "
            "queries.yaml.")
if not any("update" in (w for w, _ in tokens(t)) for t in texts):
    done(0, f"the {key} entry no longer updates anything in the loaded queries.yaml.")
done(0, f"every UPDATE of the {key} entry has a WHERE in the loaded queries.yaml.")
EOF
