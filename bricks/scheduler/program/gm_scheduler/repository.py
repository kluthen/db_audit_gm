"""The query repository: `queries.yaml`, `builders/` and `scripts/` (master
spec 7.1; forms: v0.3 capture W1 item 7, v0.4 capture W1 item 7; the call:
v0.5 capture W1 item 3).

A key maps to one of six things:

    a query      {sql, params?, transaction?}
    a pool       [{sql, params?, transaction?, weight?}, ...]   one per call, by weight
    a sequence   {steps: [{sql, params?}, ...], transaction?}  in order, one connection
    a builder    {builder: builders/<file>:<function>, options?}
    a script     {script: scripts/<file>:<function>, options?}  a job only (gm_scheduler.scripts)
    a call       {call: "<METHOD> <path>", params?, builder?, options?}   an HTTP request (v0.5)

A call runs only in a stream on an `http` connection, every other key but a
script only on a SQL one (runner.driver_problems). Its method is GET, POST,
PUT, PATCH or DELETE; its path absolute, each `%(name)s` filled from the
parameter of that name, URL-quoted. The parameters not in the path are the
JSON body's fields (GET, DELETE: the query string). With `builder`, the
parameters hold only the path's names and the builder, called as a
builder is, returns the JSON body (GET, DELETE: a map, the query string),
or None for none. No pool, sequence or transaction of calls.

An entry runs in autocommit unless it carries `transaction: {isolation,
hold?}`. A builder is called as `<function>(intensity, options)` (and with
`rng=`, the task's seeded generator, when its signature names `rng`); it
returns its statements and whether they run as one transaction (W1-y).
A script is called as `<function>(conns, options, log)` in a worker
thread, and never by a stream.
"""

import hashlib
import importlib.util
import inspect
import os
import re
import stat
from urllib.parse import quote

import yaml

from . import ConfigError
from .drivers.http import QUERY_METHODS, encode_json, join_query, query_string, scalar_text
from .generators import compile_params, draw_params
from .timeutil import parse_duration

KEY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
BUILDER_RE = re.compile(r"^builders/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
SCRIPT_RE = re.compile(r"^scripts/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
BUILDER_FILE_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
ISOLATIONS = ("read committed", "repeatable read", "serializable")
CALL_RE = re.compile(r"^(GET|POST|PUT|PATCH|DELETE) (/[\x21-\x7e]*)$")
PATH_NAME_RE = re.compile(r"%\(([A-Za-z_][A-Za-z0-9_]*)\)s")
PATH_PERCENT_RE = re.compile(r"%(?!\([A-Za-z_][A-Za-z0-9_]*\)s|[0-9A-Fa-f]{2})")
QUERIES_FILE = "queries.yaml"
BUILDERS_DIR = "builders"
SCRIPTS_DIR = "scripts"

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


class CallPlan:
    """What one call of a call key sends: a method, a target (the path and
    its query string), a body (bytes or None) and its content type."""

    def __init__(self, method, target, body, content_type):
        self.method, self.target, self.body, self.content_type = method, target, body, content_type


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
        fn = _module_function(spec, BUILDER_RE, BUILDERS_DIR, modules, where, "builder")
        options = _options(value, where)
        self.fn, self.options, self.spec = fn, options, spec
        try:
            self.takes_rng = "rng" in inspect.signature(fn).parameters
        except (TypeError, ValueError):
            self.takes_rng = False

    def plan(self, rng, ctx, intensity):
        options = dict(self.options)
        result = self.fn(intensity, options, rng=rng) if self.takes_rng else self.fn(intensity, options)
        return builder_plan(result)


class CallEntry(Entry):
    kind = "call"

    def __init__(self, key, value, where, modules):
        super().__init__(key)
        unknown = set(value) - {"call", "params", "builder", "options"}
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        m = CALL_RE.match(value["call"]) if isinstance(value["call"], str) else None
        if not m:
            raise ConfigError(f"{where}.call: \"<METHOD> <path>\", the method GET, POST, PUT, PATCH or DELETE, "
                              "the path absolute, without spaces")
        self.method, self.path = m.groups()
        if "#" in self.path or PATH_PERCENT_RE.search(self.path):
            raise ConfigError(f"{where}.call: in the path, a % is %(name)s or a %XX escape, and no #")
        self.names = PATH_NAME_RE.findall(self.path)
        self.params = compile_params(value.get("params"), f"{where}.params", key)
        missing = [n for n in self.names if n not in self.params]
        if missing:
            raise ConfigError(f"{where}.params: no parameter for the path's %({missing[0]})s")
        self.fn = None
        if "builder" in value:
            self.fn = _module_function(value["builder"], BUILDER_RE, BUILDERS_DIR, modules, where, "builder")
            extra = sorted(n for n in self.params if n not in self.names)
            if extra:
                raise ConfigError(f"{where}.params: with a builder, params holds only the path's names, "
                                  f"not {extra[0]}")
            self.options = _options(value, where)
            try:
                self.takes_rng = "rng" in inspect.signature(self.fn).parameters
            except (TypeError, ValueError):
                self.takes_rng = False
        elif "options" in value:
            raise ConfigError(f"{where}.options: only with a builder")

    def plan(self, rng, ctx, intensity):
        values = draw_params(self.params, rng, ctx)
        path = PATH_NAME_RE.sub(lambda m: quote(scalar_text(values[m.group(1)]), safe=""), self.path)
        if self.fn is None:
            payload = {k: v for k, v in values.items() if k not in self.names}
        else:
            options = dict(self.options)
            payload = self.fn(intensity, options, rng=rng) if self.takes_rng else self.fn(intensity, options)
        if self.method in QUERY_METHODS:
            if payload is not None and not isinstance(payload, dict):
                raise BuilderResult(f"a {self.method} call's builder returns a map (the query string) or None")
            return CallPlan(self.method, join_query(path, query_string(payload or {})), None, None)
        if payload is None:
            return CallPlan(self.method, path, None, None)
        try:
            body = encode_json(payload)
        except (TypeError, ValueError) as exc:
            raise BuilderResult(f"the body is not JSON: {exc}") from None
        return CallPlan(self.method, path, body, "application/json")


def _module_function(spec, regex, directory, modules, where, field):
    """`<directory>/<file>:<function>` -> the function, from the modules
    loaded for <directory>; raises ConfigError."""
    m = regex.match(spec) if isinstance(spec, str) else None
    if not m:
        raise ConfigError(f"{where}.{field}: {directory}/<file>:<function>")
    filename, function = m.groups()
    if filename not in modules:
        raise ConfigError(f"{where}.{field}: no file {directory}/{filename}")
    module = modules[filename]
    if module is None:
        raise ConfigError(f"{where}.{field}: {directory}/{filename} did not load")
    fn = getattr(module, function, None)
    if not callable(fn):
        raise ConfigError(f"{where}.{field}: {directory}/{filename} has no function {function}")
    return fn


def _options(value, where):
    options = value.get("options", {})
    if options is None:
        options = {}
    if not isinstance(options, dict):
        raise ConfigError(f"{where}.options: a map")
    return options


class ScriptEntry(Entry):
    """A transformer script: runs only as a job, which names its
    connections (gm_scheduler.scripts runs it)."""

    kind = "script"

    def __init__(self, key, value, where, modules):
        super().__init__(key)
        unknown = set(value) - {"script", "options"}
        if unknown:
            raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, unknown)))}")
        self.spec = value.get("script")
        self.fn = _module_function(self.spec, SCRIPT_RE, SCRIPTS_DIR, modules, where, "script")
        self.options = _options(value, where)


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


def builder_files(repo_dir, directory=BUILDERS_DIR):
    """Names of the regular files in builders/ (or scripts/) that may be
    builders (or scripts), sorted; other entries are ignored."""
    d = os.path.join(repo_dir, directory)
    try:
        entries = sorted(os.scandir(d), key=lambda e: e.name)
    except (FileNotFoundError, NotADirectoryError):
        return []
    return [e.name for e in entries
            if BUILDER_FILE_RE.match(e.name) and e.is_file(follow_symlinks=False)]


def referenced_builders(doc, field="builder", regex=BUILDER_RE):
    """The builder (or script) files queries.yaml names (only those are
    imported)."""
    names = set()
    queries = doc.get("queries") if isinstance(doc, dict) else None
    for value in (queries or {}).values() if isinstance(queries, dict) else ():
        if isinstance(value, dict) and isinstance(value.get(field), str):
            m = regex.match(value[field])
            if m:
                names.add(m.group(1))
    return sorted(names)


def load_builder_modules(repo_dir, names, generation, directory=BUILDERS_DIR):
    """Imports the named files of builders/ (or scripts/): their code runs
    here, as the service account."""
    modules = {}
    for name in names:
        path = os.path.join(repo_dir, directory, name)
        try:
            source = read_regular(path, f"{directory}/{name}")
        except ConfigError as exc:
            if "missing" in str(exc):
                continue  # the entry naming it says so
            raise
        kind = "builder" if directory == BUILDERS_DIR else "script"
        modname = f"gm_{kind}_{generation}_{re.sub(r'[^A-Za-z0-9_]', '_', name)}"
        spec = importlib.util.spec_from_loader(modname, loader=None, origin=path)
        module = importlib.util.module_from_spec(spec)
        module.__file__ = path
        try:
            code = compile(source, path, "exec")
            exec(code, module.__dict__)
        except SyntaxError as exc:
            raise ConfigError(f"{directory}/{name}: line {exc.lineno}: {exc.msg}") from None
        except Exception as exc:  # the builder's or script's own code failed at import
            raise ConfigError(f"{directory}/{name}: fails at import: {type(exc).__name__}: {exc}") from None
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


def parse_queries(doc, modules, scripts=None):
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
        elif isinstance(value, dict) and "call" in value:
            entries[key] = CallEntry(key, value, where, modules)
        elif isinstance(value, dict) and "builder" in value:
            entries[key] = BuilderEntry(key, value, where, modules)
        elif isinstance(value, dict) and "script" in value:
            entries[key] = ScriptEntry(key, value, where, scripts or {})
        elif isinstance(value, dict) and "steps" in value:
            entries[key] = SequenceEntry(key, value, where)
        elif isinstance(value, dict) and "sql" in value:
            entries[key] = QueryEntry(key, value, where)
        else:
            raise ConfigError(f"{where}: a query (sql), a pool (a list), a sequence (steps), a builder, a script "
                              "or a call")
    return Repository(entries)


def load_repository(repo_dir):
    """Reads queries.yaml and imports the builders/ and scripts/ files it
    names (their code runs here, as the service account); raises
    ConfigError."""
    global _generation
    _generation += 1
    doc = load_yaml(read_regular(os.path.join(repo_dir, QUERIES_FILE), QUERIES_FILE), QUERIES_FILE)
    modules = load_builder_modules(repo_dir, referenced_builders(doc), _generation)
    scripts = load_builder_modules(repo_dir, referenced_builders(doc, "script", SCRIPT_RE), _generation,
                                   SCRIPTS_DIR)
    return parse_queries(doc, modules, scripts)


def queries_outline(repo_dir):
    """(the keys of queries.yaml, those whose entry is a script, those whose
    entry is a call), without importing any builder or script (for the
    root-side check, which must never run the players' code)."""
    doc = load_yaml(read_regular(os.path.join(repo_dir, QUERIES_FILE), QUERIES_FILE), QUERIES_FILE)
    if not isinstance(doc, dict) or not isinstance(doc.get("queries"), dict):
        raise ConfigError(f"{QUERIES_FILE}: one top-level key, queries")
    q = doc["queries"]
    keys = set(k for k in q if isinstance(k, str))
    calls = set(k for k in keys if isinstance(q[k], dict) and "call" in q[k])
    scripts = set(k for k in keys if isinstance(q[k], dict) and "script" in q[k] and k not in calls)
    return keys, scripts, calls


def queries_keys_only(repo_dir):
    """The keys of queries.yaml, without importing any builder or script."""
    return queries_outline(repo_dir)[0]


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
    files += [os.path.join(repo_dir, SCRIPTS_DIR, n) for n in builder_files(repo_dir, SCRIPTS_DIR)]
    files.append(jobs_path)
    return files
