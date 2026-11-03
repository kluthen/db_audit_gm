"""The endpoint pairs, imported and checked (capture W1 item 5; master spec
7.2: "the `db/` side is covered by the brick's own build checks").

Run at every start of the server, by `gm-reload-api` before it restarts
it, and by the validator. The first problem found stops the check, named
by file and line, never by a secret:

  - every endpoint of api.yaml has both files, routes/<name>.py and
    db/<name>.py, regular files;
  - a route file imports FastAPI, Pydantic, the standard library and db/
    modules only (`from db import <name>`, `import db.<name>`, `from
    db.<name> import ...`), so the contract stays out of the players'
    reach; a db/ file imports psycopg, the standard library and gm_api
    only; no relative import;
  - both import; the route file defines `router`, a FastAPI APIRouter, at
    top level, its routes plain `def` (never `async def`: psycopg's calls
    are synchronous and run in the server's worker threads);
  - every name a route file takes from a db/ module (`<module>.<name>` or
    `from db.<module> import <name>`) is defined by it: a db/ side that
    drops or renames a function the route calls is refused, not found at
    the first request;
  - gm_api.connection("<name>") and gm_api.client("<name>") in a db/ file,
    with a literal name, name an sql/postgresql or an http connection of
    api.yaml respectively;
  - two routes of one hostname never declare one method and path.
"""

import ast
import importlib
import inspect
import os
import re
import stat
import sys

from . import ConfigError, config

ROUTE_PACKAGES = ("fastapi", "pydantic")
DB_PACKAGES = ("psycopg", "gm_api")
STDLIB = frozenset(sys.stdlib_module_names)
_added_paths = []


def _rel(path):
    root = config.ROOT.rstrip("/") + "/"
    return path[len(root):] if path.startswith(root) else path


def _parse(path):
    try:
        with open(path, "rb") as f:
            source = f.read()
    except OSError as exc:
        raise ConfigError(f"{_rel(path)}: cannot be read ({exc.strerror})") from None
    try:
        return ast.parse(source, filename=_rel(path))
    except SyntaxError as exc:
        raise ConfigError(f"{_rel(path)}: line {exc.lineno}: SyntaxError: {exc.msg}") from None
    except ValueError as exc:
        raise ConfigError(f"{_rel(path)}: {exc}") from None


def _check_imports(tree, path, kind, db_modules):
    """kind "route" or "db"; raises ConfigError on the first import refused."""
    allowed = ROUTE_PACKAGES if kind == "route" else DB_PACKAGES
    what = ("FastAPI, Pydantic, the standard library and db/ modules" if kind == "route"
            else "psycopg, the standard library and gm_api")
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            names = [a.name for a in node.names]
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                raise ConfigError(f"{_rel(path)}: line {node.lineno}: a relative import; "
                                  f"a {kind} file imports {what} only")
            if kind == "route" and node.module == "db":
                for a in node.names:
                    if a.name not in db_modules:
                        raise ConfigError(f"{_rel(path)}: line {node.lineno}: from db import "
                                          f"{a.name}: there is no db/{a.name}.py")
                continue
            names = [node.module]
        else:
            continue
        for name in names:
            top = name.split(".")[0]
            if top in STDLIB or top in allowed:
                if top == "gm_api" and name != "gm_api":
                    raise ConfigError(f"{_rel(path)}: line {node.lineno}: {name}: a db/ file "
                                      "uses gm_api itself, not its modules")
                continue
            if kind == "route" and top == "db":
                parts = name.split(".")
                if len(parts) == 2 and parts[1] in db_modules:
                    continue
                raise ConfigError(f"{_rel(path)}: line {node.lineno}: {name}: not a db/ module "
                                  "(db.<name>, for a db/<name>.py)")
            raise ConfigError(f"{_rel(path)}: line {node.lineno}: imports {name}; a {kind} "
                              f"file imports {what} only")


def _db_uses(tree):
    """[(module, name, line)] a route file takes from db/ modules."""
    aliases = {}                                   # local name -> db module, or "db" itself
    uses = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for a in node.names:
                parts = a.name.split(".")
                if parts[0] == "db" and len(parts) == 2:
                    if a.asname:
                        aliases[a.asname] = parts[1]
                    else:
                        aliases["db"] = None        # db.<module>.<name>
        elif isinstance(node, ast.ImportFrom) and node.module and not node.level:
            parts = node.module.split(".")
            if node.module == "db":
                for a in node.names:
                    aliases[a.asname or a.name] = a.name
            elif parts[0] == "db" and len(parts) == 2:
                for a in node.names:
                    uses.append((parts[1], a.name, node.lineno))
    for node in ast.walk(tree):
        if not isinstance(node, ast.Attribute):
            continue
        v = node.value
        if isinstance(v, ast.Name) and v.id in aliases and aliases[v.id] is not None:
            uses.append((aliases[v.id], node.attr, node.lineno))
        elif (isinstance(v, ast.Attribute) and isinstance(v.value, ast.Name) and v.value.id == "db"
              and "db" in aliases and aliases["db"] is None):
            uses.append((v.attr, node.attr, node.lineno))
    return uses


def _gm_api_calls(tree):
    """[(function, literal name, line)] of gm_api.connection / gm_api.client."""
    local = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module == "gm_api" and not node.level:
            for a in node.names:
                if a.name in ("connection", "client"):
                    local[a.asname or a.name] = a.name
    calls = []
    for node in ast.walk(tree):
        if not (isinstance(node, ast.Call) and node.args and isinstance(node.args[0], ast.Constant)
                and isinstance(node.args[0].value, str)):
            continue
        f = node.func
        if (isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name) and f.value.id == "gm_api"
                and f.attr in ("connection", "client")):
            calls.append((f.attr, node.args[0].value, node.lineno))
        elif isinstance(f, ast.Name) and f.id in local:
            calls.append((local[f.id], node.args[0].value, node.lineno))
    return calls


def _regular(path):
    try:
        st = os.lstat(path)
    except FileNotFoundError:
        return False
    return stat.S_ISREG(st.st_mode)


def _import(module, path):
    try:
        return importlib.import_module(module)
    except ConfigError as exc:
        raise ConfigError(f"{_rel(path)}: {exc}") from None
    except SyntaxError as exc:
        raise ConfigError(f"{_rel(path)}: line {exc.lineno}: SyntaxError: {exc.msg}") from None
    except (Exception, SystemExit) as exc:       # whatever an endpoint file raises on import
        tb = exc.__traceback__
        line = None
        while tb is not None:
            if tb.tb_frame.f_code.co_filename.startswith(config.ROOT):
                line = (tb.tb_frame.f_code.co_filename, tb.tb_lineno)
            tb = tb.tb_next
        where = f"{_rel(line[0])}: line {line[1]}" if line else _rel(path)
        raise ConfigError(f"{where}: {type(exc).__name__} on import: "
                          f"{' '.join(str(exc).split())[:300]}") from None


def load_endpoints(cfg):
    """Imports and checks every endpoint pair; -> {name: (router, db module)}.
    Raises ConfigError on the first problem."""
    from fastapi import APIRouter

    sys.dont_write_bytecode = True              # no __pycache__ in db/, never a stale one
    for m in [m for m in sys.modules if m.split(".")[0] in ("routes", "db")]:
        del sys.modules[m]                       # a fresh import of every endpoint file
    importlib.invalidate_caches()
    for p in _added_paths:
        if p in sys.path:
            sys.path.remove(p)
    sys.path.insert(0, config.ROOT)
    _added_paths[:] = [config.ROOT]
    db_modules = set()
    try:
        for entry in os.scandir(config.DB_DIR):
            if entry.name.endswith(".py") and entry.is_file(follow_symlinks=False):
                db_modules.add(entry.name[:-3])
    except OSError as exc:
        raise ConfigError(f"db/: cannot be listed ({exc.strerror})") from None
    for name in cfg.endpoints:
        for d in (config.ROUTES_DIR, config.DB_DIR):
            path = os.path.join(d, f"{name}.py")
            if not _regular(path):
                raise ConfigError(f"endpoints.{name}: {_rel(path)} is missing (each endpoint is "
                                  f"two files, routes/{name}.py and db/{name}.py)")
    trees = {}
    for name in cfg.endpoints:
        for kind, d in (("route", config.ROUTES_DIR), ("db", config.DB_DIR)):
            path = os.path.join(d, f"{name}.py")
            tree = _parse(path)
            _check_imports(tree, path, kind, db_modules)
            trees[(kind, name)] = (tree, path)
    for (kind, name), (tree, path) in trees.items():
        if kind != "db":
            continue
        for fn, target, line in _gm_api_calls(tree):
            c = cfg.connections.get(target)
            want = "sql/postgresql" if fn == "connection" else "http"
            if c is None or c.driver != want:
                raise ConfigError(f"{_rel(path)}: line {line}: gm_api.{fn}({target!r}): not an "
                                  f"{want} connection of api.yaml")
    loaded = {}
    for name in cfg.endpoints:
        tree, path = trees[("route", name)]
        module = _import(f"routes.{name}", path)
        router = getattr(module, "router", None)
        if not isinstance(router, APIRouter):
            raise ConfigError(f"{_rel(path)}: defines no `router` (a FastAPI APIRouter) at top level")
        for r in router.routes:
            fn = getattr(r, "endpoint", None)
            if fn is not None and inspect.iscoroutinefunction(fn):
                raise ConfigError(f"{_rel(path)}: {getattr(r, 'path', '?')}: an async def route; "
                                  "routes are plain def (run in the server's worker threads)")
        for mod, attr, line in _db_uses(tree):
            dbm = sys.modules.get(f"db.{mod}") or _import(f"db.{mod}", os.path.join(config.DB_DIR,
                                                                                    f"{mod}.py"))
            if not hasattr(dbm, attr):
                raise ConfigError(f"{_rel(path)}: line {line}: uses {attr} of db/{mod}.py, which "
                                  f"db/{mod}.py does not define")
        loaded[name] = (router, sys.modules.get(f"db.{name}"))
    for name in cfg.endpoints:
        if f"db.{name}" not in sys.modules:
            _import(f"db.{name}", os.path.join(config.DB_DIR, f"{name}.py"))
    return loaded


PARAM_RE = re.compile(r"\{[^}]*\}")


def route_keys(router):
    """{(METHOD, path with its parameters unnamed): path as declared}."""
    keys = {}
    for r in router.routes:
        path = getattr(r, "path", "?")
        for m in getattr(r, "methods", None) or ():
            if m != "HEAD":
                keys.setdefault((m, PARAM_RE.sub("{}", path)), path)
    return keys


def check_duplicates(cfg, loaded):
    """Two endpoints of one hostname never declare one method and path (the
    parameters' names aside: /orders/{a} and /orders/{b} are one path)."""
    for host in cfg.hosts():
        seen = {}
        for name, e in cfg.endpoints.items():
            if host not in e.hosts:
                continue
            for key, path in sorted(route_keys(loaded[name][0]).items()):
                if key in seen and seen[key][0] != name:
                    raise ConfigError(f"host {host}: {key[0]} {path} (routes/{name}.py) is "
                                      f"{key[0]} {seen[key][1]} of routes/{seen[key][0]}.py")
                seen[key] = (name, path)
