"""The query repository: `queries.yaml` and `builders/` (master spec 7.1;
forms: capture W1 item 7).

A key maps to one of four things:

    a query      {sql, params?, transaction?}
    a pool       [{sql, params?, transaction?, weight?}, ...]   one per call, by weight
    a sequence   {steps: [{sql, params?}, ...], transaction?}  in order, one connection
    a builder    {builder: builders/<file>:<function>, options?}

An entry runs in autocommit unless it carries `transaction: {isolation,
hold?}`. A builder is called as `<function>(intensity, options)` (and with
`rng=`, the task's seeded generator, when its signature names `rng`); it
returns its statements and whether they run as one transaction (W1-y).
"""

import hashlib
import importlib.util
import inspect
import os
import re
import stat

import yaml

from . import ConfigError
from .generators import compile_params, draw_params
from .timeutil import parse_duration

KEY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
BUILDER_RE = re.compile(r"^builders/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
BUILDER_FILE_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
ISOLATIONS = ("read committed", "repeatable read", "serializable")
QUERIES_FILE = "queries.yaml"
BUILDERS_DIR = "builders"

_Loader = getattr(yaml, "CSafeLoader", yaml.SafeLoader)


def read_regular(path, what):
    """The text of a regular file, never through a symbolic link."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        raise ConfigError(f"{what}: missing") from None
    except OSError as exc:
        if exc.errno == 40:  # ELOOP
            raise ConfigError(f"{what}: is a symbolic link, not a file") from None
        raise ConfigError(f"{what}: cannot be read ({exc.strerror})") from None
    with os.fdopen(fd, "rb") as f:
        if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
            raise ConfigError(f"{what}: not a regular file")
        data = f.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        raise ConfigError(f"{what}: not UTF-8 text") from None


def load_yaml(text, what):
    try:
        return yaml.load(text, Loader=_Loader)
    except yaml.YAMLError as exc:
        mark = getattr(exc, "problem_mark", None)
        place = f" (line {mark.line + 1}, column {mark.column + 1})" if mark else ""
        problem = getattr(exc, "problem", None) or "not valid YAML"
        raise ConfigError(f"{what}: does not parse{place}: {problem}") from None


class Txn:
    def __init__(self, isolation, hold):
        self.isolation, self.hold = isolation, hold

    def __eq__(self, other):
        return isinstance(other, Txn) and (self.isolation, self.hold) == (other.isolation, other.hold)

    def __repr__(self):
        return f"Txn({self.isolation!r}, {self.hold!r})"


class Plan:
    """What one call runs: statements with their parameters, in autocommit
    (`txn` None) or as one transaction."""

    def __init__(self, steps, txn):
        self.steps, self.txn = steps, txn


def parse_transaction(value, where):
    if value is None:
        return None
    if not isinstance(value, dict) or set(value) - {"isolation", "hold"} or "isolation" not in value:
        raise ConfigError(f"{where}: transaction is {{isolation: <level>, hold: <duration>}}, hold optional")
    isolation = value["isolation"]
    if isolation not in ISOLATIONS:
        raise ConfigError(f"{where}.isolation: one of {', '.join(ISOLATIONS)}")
    hold = parse_duration(value["hold"], f"{where}.hold") if "hold" in value else 0
    return Txn(isolation, hold)


def _sql(value, where):
    if not isinstance(value, str) or not value.strip():
        raise ConfigError(f"{where}: sql is a non-empty string")
    return value


class Statement:
    def __init__(self, item, where, ident, allowed):
        if not isinstance(item, dict):
            raise ConfigError(f"{where}: a map with sql")
        unknown = set(item) - allowed
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        self.sql = _sql(item.get("sql"), f"{where}.sql")
        self.params = compile_params(item.get("params"), f"{where}.params", ident)


class Entry:
    kind = None

    def __init__(self, key):
        self.key = key


class QueryEntry(Entry):
    kind = "query"

    def __init__(self, key, value, where):
        super().__init__(key)
        self.stmt = Statement(value, where, key, {"sql", "params", "transaction"})
        self.txn = parse_transaction(value.get("transaction"), f"{where}.transaction")

    def plan(self, rng, ctx, intensity):
        return Plan([(self.stmt.sql, draw_params(self.stmt.params, rng, ctx))], self.txn)


class PoolEntry(Entry):
    kind = "pool"

    def __init__(self, key, value, where):
        super().__init__(key)
        if not value:
            raise ConfigError(f"{where}: a pool lists at least one query")
        self.items = []
        for i, item in enumerate(value):
            w = f"{where}[{i}]"
            stmt = Statement(item, w, f"{key}[{i}]", {"sql", "params", "transaction", "weight"})
            weight = item.get("weight", 1)
            if not isinstance(weight, int) or isinstance(weight, bool) or weight < 1:
                raise ConfigError(f"{w}.weight: a whole number, at least 1")
            self.items.append((stmt, parse_transaction(item.get("transaction"), f"{w}.transaction"), weight))
        self.total = sum(w for _, _, w in self.items)

    def pick(self, rng):
        n = rng.randrange(self.total)
        for stmt, txn, weight in self.items:
            if n < weight:
                return stmt, txn
            n -= weight
        raise AssertionError("weights")

    def plan(self, rng, ctx, intensity):
        stmt, txn = self.pick(rng)
        return Plan([(stmt.sql, draw_params(stmt.params, rng, ctx))], txn)


class SequenceEntry(Entry):
    kind = "sequence"

    def __init__(self, key, value, where):
        super().__init__(key)
        unknown = set(value) - {"steps", "transaction"}
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        steps = value.get("steps")
        if not isinstance(steps, list) or not steps:
            raise ConfigError(f"{where}.steps: a non-empty list of {{sql, params}}")
        self.steps = [Statement(s, f"{where}.steps[{i}]", f"{key}.steps[{i}]", {"sql", "params"})
                      for i, s in enumerate(steps)]
        self.txn = parse_transaction(value.get("transaction"), f"{where}.transaction")

    def plan(self, rng, ctx, intensity):
        return Plan([(s.sql, draw_params(s.params, rng, ctx)) for s in self.steps], self.txn)


class BuilderEntry(Entry):
    kind = "builder"

    def __init__(self, key, value, where, modules):
        super().__init__(key)
        unknown = set(value) - {"builder", "options"}
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        spec = value.get("builder")
        m = BUILDER_RE.match(spec) if isinstance(spec, str) else None
        if not m:
            raise ConfigError(f"{where}.builder: builders/<file>:<function>")
        filename, function = m.groups()
        if filename not in modules:
            raise ConfigError(f"{where}.builder: no file builders/{filename}")
        module = modules[filename]
        if module is None:
            raise ConfigError(f"{where}.builder: builders/{filename} did not load")
        fn = getattr(module, function, None)
        if not callable(fn):
            raise ConfigError(f"{where}.builder: builders/{filename} has no function {function}")
        options = value.get("options", {})
        if options is None:
            options = {}
        if not isinstance(options, dict):
            raise ConfigError(f"{where}.options: a map")
        self.fn, self.options, self.spec = fn, options, spec
        try:
            self.takes_rng = "rng" in inspect.signature(fn).parameters
        except (TypeError, ValueError):
            self.takes_rng = False

    def plan(self, rng, ctx, intensity):
        options = dict(self.options)
        result = self.fn(intensity, options, rng=rng) if self.takes_rng else self.fn(intensity, options)
        return builder_plan(result)


class BuilderResult(Exception):
    """A builder returned something that is not a plan."""


def builder_plan(result):
    """A builder's return value -> Plan. Accepted: `(statements, transaction)`,
    or `{"statements": [...], "transaction": ...}`; a statement is
    `(sql, params)` or `{"sql": ..., "params": ...}`; transaction is false
    (autocommit), true (read committed, no hold) or `{isolation, hold?}`."""
    if isinstance(result, dict):
        statements, txn = result.get("statements"), result.get("transaction", False)
    elif isinstance(result, (tuple, list)) and len(result) == 2:
        statements, txn = result
    else:
        raise BuilderResult("a builder returns (statements, transaction)")
    if not isinstance(statements, (list, tuple)) or not statements:
        raise BuilderResult("a builder returns at least one statement")
    steps = []
    for s in statements:
        if isinstance(s, dict):
            sql, params = s.get("sql"), s.get("params")
        elif isinstance(s, (tuple, list)) and len(s) == 2:
            sql, params = s
        else:
            raise BuilderResult("a statement is (sql, params)")
        if not isinstance(sql, str) or not sql.strip():
            raise BuilderResult("a statement's sql is a non-empty string")
        if params is not None and not isinstance(params, (dict, list, tuple)):
            raise BuilderResult("a statement's params are a map or a list")
        steps.append((sql, params))
    if txn is True:
        txn = Txn("read committed", 0)
    elif txn is False or txn is None:
        txn = None
    else:
        try:
            txn = parse_transaction(txn, "transaction")
        except ConfigError as exc:
            raise BuilderResult(str(exc)) from None
    return Plan(steps, txn)


def builder_files(repo_dir):
    """Names of the regular files in builders/ that may be builders (sorted;
    other entries, an editor's backup for one, are ignored)."""
    d = os.path.join(repo_dir, BUILDERS_DIR)
    try:
        entries = sorted(os.scandir(d), key=lambda e: e.name)
    except (FileNotFoundError, NotADirectoryError):
        return []
    return [e.name for e in entries
            if BUILDER_FILE_RE.match(e.name) and e.is_file(follow_symlinks=False)]


def referenced_builders(doc):
    """The builder files queries.yaml names (only those are imported)."""
    names = set()
    queries = doc.get("queries") if isinstance(doc, dict) else None
    for value in (queries or {}).values() if isinstance(queries, dict) else ():
        if isinstance(value, dict) and isinstance(value.get("builder"), str):
            m = BUILDER_RE.match(value["builder"])
            if m:
                names.add(m.group(1))
    return sorted(names)


def load_builder_modules(repo_dir, names, generation):
    modules = {}
    for name in names:
        path = os.path.join(repo_dir, BUILDERS_DIR, name)
        try:
            source = read_regular(path, f"{BUILDERS_DIR}/{name}")
        except ConfigError as exc:
            if "missing" in str(exc):
                continue  # the entry naming it says so
            raise
        modname = f"gm_builder_{generation}_{re.sub(r'[^A-Za-z0-9_]', '_', name)}"
        spec = importlib.util.spec_from_loader(modname, loader=None, origin=path)
        module = importlib.util.module_from_spec(spec)
        module.__file__ = path
        try:
            code = compile(source, path, "exec")
            exec(code, module.__dict__)
        except SyntaxError as exc:
            raise ConfigError(f"{BUILDERS_DIR}/{name}: line {exc.lineno}: {exc.msg}") from None
        except Exception as exc:  # the builder's own code failed at import
            raise ConfigError(f"{BUILDERS_DIR}/{name}: fails at import: {type(exc).__name__}: {exc}") from None
        modules[name] = module
    return modules


_generation = 0


class Repository:
    def __init__(self, entries):
        self.entries = entries

    def __contains__(self, key):
        return key in self.entries

    def get(self, key):
        return self.entries[key]

    def keys(self):
        return sorted(self.entries)


def parse_queries(doc, modules):
    if not isinstance(doc, dict) or set(doc) != {"queries"}:
        raise ConfigError(f"{QUERIES_FILE}: one top-level key, queries")
    queries = doc["queries"]
    if not isinstance(queries, dict) or not queries:
        raise ConfigError(f"{QUERIES_FILE}: queries maps at least one key to an entry")
    entries = {}
    for key, value in queries.items():
        where = f"{QUERIES_FILE}: {key}"
        if not isinstance(key, str) or not KEY_RE.match(key):
            raise ConfigError(f"{QUERIES_FILE}: key {key!r}: lowercase letters, digits, '.', '_', '-'")
        if isinstance(value, list):
            entries[key] = PoolEntry(key, value, where)
        elif isinstance(value, dict) and "builder" in value:
            entries[key] = BuilderEntry(key, value, where, modules)
        elif isinstance(value, dict) and "steps" in value:
            entries[key] = SequenceEntry(key, value, where)
        elif isinstance(value, dict) and "sql" in value:
            entries[key] = QueryEntry(key, value, where)
        else:
            raise ConfigError(f"{where}: a query (sql), a pool (a list), a sequence (steps) or a builder")
    return Repository(entries)


def load_repository(repo_dir):
    """Reads queries.yaml and imports builders/ (their code runs here, as the
    service account); raises ConfigError."""
    global _generation
    _generation += 1
    doc = load_yaml(read_regular(os.path.join(repo_dir, QUERIES_FILE), QUERIES_FILE), QUERIES_FILE)
    modules = load_builder_modules(repo_dir, referenced_builders(doc), _generation)
    return parse_queries(doc, modules)


def queries_keys_only(repo_dir):
    """The keys of queries.yaml, without importing any builder (for the
    root-side check, which must never run the players' code)."""
    doc = load_yaml(read_regular(os.path.join(repo_dir, QUERIES_FILE), QUERIES_FILE), QUERIES_FILE)
    if not isinstance(doc, dict) or not isinstance(doc.get("queries"), dict):
        raise ConfigError(f"{QUERIES_FILE}: one top-level key, queries")
    return set(k for k in doc["queries"] if isinstance(k, str))


def fingerprint(paths):
    """{path: sha256 or a reason} of the files the program loads, for the
    validator's pending rule."""
    out = {}
    for path in paths:
        try:
            out[path] = hashlib.sha256(read_regular(path, path).encode("utf-8")).hexdigest()
        except ConfigError as exc:
            out[path] = str(exc).split(": ", 1)[-1].replace(" ", "-")
    return out


def loaded_files(repo_dir, jobs_path):
    files = [os.path.join(repo_dir, QUERIES_FILE)]
    files += [os.path.join(repo_dir, BUILDERS_DIR, n) for n in builder_files(repo_dir)]
    files.append(jobs_path)
    return files
