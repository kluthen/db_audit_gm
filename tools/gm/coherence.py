"""The post-load coherence check of a composed scenario (v0.5 master spec
8.5, 15; formats.md "Composing domains"; capture W2 item 3 of
specs/versions/v0.5/wave-log.md).

A domain may ship `data/coherence.yaml`, its coherence queries:

    checks:
      - id: stays-placed              # [a-z][a-z0-9-]*, once in the domain
        what: every current stay placed in a unit   # one line, the report's
        database: clinic              # a several-database part only: one of its databases
        reads: [vet-core]             # optional: composed domains or partners
        sql: |                        # one SELECT: the offending rows, none when coherent
          SELECT s.id AS stay_id FROM gm_src_vet_core.stays s ...

A part carries its references to its core and the histories it shares; the
core carries none. `load-data` runs every check once, after the histories and
before any fault is planted, as `postgres` in the domain's database, in a
read-only transaction, its session unseen, each `reads` entry reachable
through the foreign schemas `gm_src_<name>` it creates for the check and
drops after (inject.py). A check whose `reads` names a domain not composed
(or the partners' database in a game with none) is skipped and reported so.
Any row fails the setup as a design error, naming the domain, the check, its
`what`, the row count and the first FIRST_ROWS rows.

The result is recorded twice: `coherence: {run_at, result}` rewritten in the
scenario's `composition.yaml` (that key only, every other line byte for
byte), and each check's outcome in the game's `state.yaml` (inject.py).

This module reads and checks the files and shapes the SQL and the record;
running it is load-data's (inject.py).
"""

import json
import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import model
from .model import GmError

COHERENCE_FILE = "data/coherence.yaml"
PARTNERS = "partners"                    # the partners' database, as a `reads` entry
CHECK_ID_RE = re.compile(r"^[a-z][a-z0-9-]*$")
CHECK_KEYS = ("id", "what", "database", "reads", "sql")
FIRST_ROWS = 10
PASS, FAIL, SKIPPED = "pass", "fail", "skipped"
RECORD_KEY = "coherence"
_RECORD_RE = re.compile(r"^coherence\s*:(\s|$)")
_SELECT_RE = re.compile(r"^(select|with)\b", re.IGNORECASE)


@dataclass
class Check:
    """One coherence query of a domain."""
    domain: str
    id: str
    what: str
    sql: str                          # the SELECT, its trailing `;` removed
    database: str = None              # a several-database part's, else None
    reads: list = field(default_factory=list)


@dataclass
class Outcome:
    """What one check gave."""
    domain: str
    check: str
    what: str
    result: str                       # PASS, FAIL or SKIPPED
    count: int = 0                    # the rows returned
    rows: list = field(default_factory=list)   # the first FIRST_ROWS, as JSON objects
    reason: str = None                # why it was skipped

    def record(self):
        """The outcome as the game's state.yaml keeps it."""
        out = {"domain": self.domain, "check": self.check, "what": self.what,
               "result": self.result}
        if self.result == FAIL:
            out.update(rows=self.count, first_rows=self.rows)
        if self.reason:
            out["reason"] = self.reason
        return out


def _select_problem(sql):
    """Why `sql` is not one SELECT (a WITH query allowed), or None."""
    if not _SELECT_RE.match(sql):
        return "does not start with SELECT or WITH"
    if ";" in sql:
        return "holds a `;`: one SELECT, its trailing `;` optional"
    if any(line.lstrip().startswith("\\") for line in sql.splitlines()):
        return "holds a psql meta-command (a line starting with \\)"
    return None


def read_checks(path, domain, databases=None, label=None):
    """[Check] of a domain's coherence file `path` ([] when it has none).
    `databases`: the domain's `databases` list for a several-database part,
    None otherwise. GmError listing every problem of a malformed file, before
    any query runs (W2 item 1: the loader does not check it in v0.5)."""
    path = Path(path)
    label = label or f"domains/{domain}/{COHERENCE_FILE}"
    if not path.is_file():
        return []
    try:
        content = model.strict_load(path.read_text(encoding="utf-8"))
    except (yaml.YAMLError, UnicodeDecodeError) as exc:
        raise GmError(f"{label}: cannot be read: {' '.join(str(exc).split())}") from None
    problems = []
    if not (isinstance(content, dict) and set(content) == {"checks"}
            and isinstance(content["checks"], list) and content["checks"]):
        raise GmError(f"{label}: not {{checks: [...]}}, a non-empty list of checks "
                      "(template coherence.yaml)")
    checks, seen = [], set()
    for i, item in enumerate(content["checks"]):
        cid = item.get("id") if isinstance(item, dict) else None
        p = f"{label}: checks[{cid if isinstance(cid, str) else i}]"
        if not isinstance(item, dict):
            problems.append(f"{p}: not a mapping (id, what, sql, and database, reads)")
            continue
        unknown = [k for k in item if k not in CHECK_KEYS]
        if unknown:
            problems.append(f"{p}: {', '.join(map(str, unknown))}: not a key of a check "
                            f"({', '.join(CHECK_KEYS)})")
        if not (isinstance(cid, str) and CHECK_ID_RE.match(cid)):
            problems.append(f"{p}.id: {cid!r} is not a check id ([a-z][a-z0-9-]*)")
        elif cid in seen:
            problems.append(f"{p}.id: {cid} twice in the domain")
        seen.add(cid)
        what = item.get("what")
        if not (isinstance(what, str) and what.strip() and "\n" not in what.strip()):
            problems.append(f"{p}.what: not one line of text")
        sql = item.get("sql")
        sql = sql.strip().rstrip(";").rstrip() if isinstance(sql, str) else ""
        problem = _select_problem(sql) if sql else "missing or empty"
        if problem:
            problems.append(f"{p}.sql: {problem}")
        database = item.get("database")
        if databases is None and "database" in item:
            problems.append(f"{p}.database: {domain} has one database (at:); database is a "
                            "several-database part's")
        elif databases is not None and database not in databases:
            problems.append(f"{p}.database: {database!r} is not one of {domain}'s databases "
                            f"({', '.join(databases)}), required on a several-database part")
        reads = item.get("reads", [])
        if not (isinstance(reads, list) and all(isinstance(r, str) for r in reads)
                and len(set(reads)) == len(reads)):
            problems.append(f"{p}.reads: not a list of unique domain ids or {PARTNERS}")
            reads = []
        for name in reads:
            if name != PARTNERS and not model.PURPOSE_ID_RE.match(name):
                problems.append(f"{p}.reads: {name!r} is not a domain id or {PARTNERS}")
        checks.append(Check(domain, cid, what.strip() if isinstance(what, str) else "",
                            sql, database, list(reads)))
    if problems:
        raise GmError(f"{label}: malformed:\n" + "\n".join(f"  - {m}" for m in problems))
    return checks


def query_sql(check):
    """The check's query as load-data runs it (psql -A -t): in a read-only
    transaction, one JSON line (jsonb's text holds no newline, json_agg's
    does), {"count": <rows>, "rows": [first rows]}."""
    return (
        "BEGIN TRANSACTION READ ONLY;\n"
        f"WITH gm_rows AS (\n{check.sql}\n)\n"
        "SELECT pg_catalog.jsonb_build_object(\n"
        "  'count', (SELECT pg_catalog.count(*) FROM gm_rows),\n"
        "  'rows', COALESCE((SELECT pg_catalog.jsonb_agg(r) FROM "
        f"(SELECT * FROM gm_rows LIMIT {FIRST_ROWS}) AS r), '[]'::jsonb));\n"
        "COMMIT;\n")


def parse_answer(lines, what):
    """(count, rows) of a check's psql -A -t output lines; GmError on anything
    else."""
    try:
        answer = json.loads(lines[-1]) if lines else None
        count, rows = int(answer["count"]), list(answer["rows"])
    except (ValueError, TypeError, KeyError, IndexError):
        raise GmError(f"{what}: unexpected psql output: "
                      f"{(lines[-1] if lines else 'no output')[:200]}") from None
    return count, rows


def failure_text(outcomes):
    """The reason a failed coherence check gives the setup: each failing
    check, its what, its row count and its first rows."""
    failed = [o for o in outcomes if o.result == FAIL]
    lines = [f"the coherence check failed on {len(failed)} check(s): a design error, never a "
             "fault (fix the composition, a range, a function or a scale, and reload; "
             "master spec 8.5)"]
    for o in failed:
        lines.append(f"  {o.domain} {o.check} ({o.what}): {o.count} row(s); first "
                     f"{min(o.count, FIRST_ROWS)}:")
        lines += [f"    {json.dumps(row, sort_keys=True)}" for row in o.rows]
    return "\n".join(lines)


def result_of(outcomes):
    return FAIL if any(o.result == FAIL for o in outcomes) else PASS


def rewrite_record(text, run_at, result):
    """`text` (a composition.yaml) with its top-level `coherence:` key, and
    the indented lines under it, replaced by `coherence: {run_at, result}`,
    appended when absent; every other line byte for byte."""
    line = f"{RECORD_KEY}: {{run_at: '{run_at}', result: {result}}}\n"
    lines = text.splitlines(keepends=True)
    start = next((i for i, ln in enumerate(lines) if _RECORD_RE.match(ln)), None)
    if start is None:
        if lines and not lines[-1].endswith("\n"):
            lines[-1] += "\n"
        return "".join(lines) + line
    end = start + 1
    while end < len(lines) and lines[end][:1] in (" ", "\t") and lines[end].strip():
        end += 1
    return "".join(lines[:start]) + line + "".join(lines[end:])


def record_composition(path, run_at, result):
    """Rewrite the composition record's `coherence:` (rewrite_record);
    GmError when the file does not read, or would not read back as the same
    record with that key changed."""
    path = Path(path)
    try:
        text = path.read_text(encoding="utf-8")
        before = model.strict_load(text)
    except (OSError, UnicodeDecodeError, yaml.YAMLError) as exc:
        raise GmError(f"{path.name}: cannot be read to record the coherence check: "
                      f"{' '.join(str(exc).split())}") from None
    new = rewrite_record(text, run_at, result)
    try:
        after = model.strict_load(new)
    except yaml.YAMLError:
        after = None
    expected = dict(before) if isinstance(before, dict) else {}
    expected[RECORD_KEY] = {"run_at": run_at, "result": result}
    if not isinstance(after, dict) or after != expected:
        raise GmError(f"{path.name}: its coherence: key cannot be rewritten on its own (a "
                      "top-level key, its value on the lines indented under it)")
    path.write_text(new, encoding="utf-8")
