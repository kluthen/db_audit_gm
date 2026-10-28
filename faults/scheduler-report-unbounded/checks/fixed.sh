#!/bin/sh
# Sealed check of scheduler-report-unbounded (master spec 8.1, v0.3 master
# spec 6.5; capture W4 items 0 and 4). Run as root on the scheduler node;
# reads the node's files only, opens no connection, never runs the
# repository's code.
#
# FAULT_KEY names the report's queries.yaml key, FAULT_DATE_COLUMN the
# column whose bound is missing. Exit 1 while the live queries.yaml differs
# from what the program loaded (/run/scheduler/loaded: fixed but not
# reloaded, or not fixed), or while a statement of the key's loaded entry
# that selects (a query, every entry of a pool, every step of a sequence)
# has no WHERE bounding the column: the column compared (<, <=, >, >=, =)
# or BETWEEN, a cast aside, comments and literals aside, in a WHERE at any
# level (a subquery's or a CTE's included). Exit 0 once each has one;
# SELECT * is not judged. Exit 2 on an error, a builder entry included.
set -u
python3 -I - "${FAULT_KEY:-}" "${FAULT_DATE_COLUMN:-}" <<'EOF'
import hashlib
import os
import re
import stat
import sys

import yaml

LIVE = "/srv/scheduler/repository/queries.yaml"
SEED = "/opt/gm/seed/queries.yaml"
LOADED = "/run/scheduler/loaded"
COMPARE = ("<", "<=", ">", ">=", "=", "between")
ENDS = ("group", "order", "having", "limit", "offset", "window", "union", "except",
        "intersect", "fetch", "for", "returning", ";")


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


LEXEME = re.compile(r"""(?P<skip>--[^\n]*|/\*.*?\*/)
                       |(?P<lit>'(?:[^']|'')*'|\$(?P<tag>[A-Za-z_0-9]*)\$.*?\$(?P=tag)\$|%\([A-Za-z_0-9]+\)s)
                       |"(?P<qid>(?:[^"]|"")*)"
                       |(?P<word>[A-Za-z_][A-Za-z_0-9$]*)
                       |(?P<op><=|>=|<>|!=|::|[<>=();.,])
                       |(?P<other>\S)""", re.S | re.X)


def tokens(sql):
    """(token, depth): words lowercased, quoted identifiers as written,
    literals and parameters as '?', comparison operators, '::'."""
    out, depth = [], 0
    for m in LEXEME.finditer(sql):
        if m.group("skip"):
            continue
        if m.group("lit"):
            out.append(("?", depth))
        elif m.group("qid") is not None:
            out.append(("id:" + m.group("qid").replace('""', '"'), depth))
        elif m.group("word"):
            out.append(("id:" + m.group("word").lower(), depth))
        elif m.group("op"):
            t = m.group("op")
            if t == "(":
                depth += 1
                continue
            if t == ")":
                depth -= 1
                continue
            out.append((t, depth))
        else:
            out.append((m.group("other"), depth))
    return out


def bounded(sql, column):
    """Whether a WHERE in the text compares the column (or BETWEEN)."""
    toks = tokens(sql)
    col = "id:" + column
    for i, (t, depth) in enumerate(toks):
        if t != "id:where":
            continue
        j = i + 1
        while j < len(toks):
            t2, d2 = toks[j]
            if d2 < depth or (d2 == depth and t2[3:] in ENDS and t2.startswith("id:")) \
                    or (t2 == ";" and d2 == depth):
                break
            if t2 == col:
                k = j + 1
                while k + 1 < len(toks) and toks[k][0] == "::":
                    k += 2                       # a cast: ::date, ::timestamptz
                after = toks[k][0] if k < len(toks) else ""
                before = toks[j - 1][0] if toks[j - 1][0] != "." else \
                    (toks[j - 3][0] if j >= 3 else "")
                if after in COMPARE or after == "id:between" or before in COMPARE:
                    return True
            j += 1
    return False


key, column = sys.argv[1], sys.argv[2]
if not key or not column:
    done(2, "FAULT_KEY and FAULT_DATE_COLUMN must be set.")
column = column.strip('"') if column.startswith('"') else column.lower()
live_raw = regular(LIVE)
if entry(regular(SEED), SEED, key) is None:
    done(2, f"the key {key} is not in the planted {SEED}.")
live = entry(live_raw, LIVE, key)

texts = statements(live) if live is not None else []
selects = [t for t in texts or [] if any(w == "id:select" for w, _ in tokens(t))]
unbounded = [t for t in selects if not bounded(t, column)]
loaded = regular(LOADED).decode("utf-8", "replace").splitlines()
digest = next((l.split(" ", 2)[1] for l in loaded
               if l.startswith("file ") and l.endswith(" " + LIVE)), None)
if digest != hashlib.sha256(live_raw).hexdigest():
    if texts is not None and unbounded:
        done(1, f"the {key} report still reads the whole table, no bound on {column} "
                "(queries.yaml changed elsewhere, not reloaded either).")
    done(1, f"queries.yaml is changed but not reloaded: the program still runs the {key} "
            "report as it was (sudo gm-reload-scheduler).")
if live is None:
    done(2, f"the key {key} is not in the loaded queries.yaml.")
if texts is None:
    done(2, f"the {key} entry is now a builder: its SQL is code, which the check does not run; "
            "judge it by hand.")
if unbounded:
    done(1, f"the {key} report still has no bound on {column} in its WHERE in the loaded "
            "queries.yaml: it reads the whole table.")
done(0, f"the {key} report bounds {column} in its WHERE in the loaded queries.yaml.")
EOF
