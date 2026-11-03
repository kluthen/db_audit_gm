"""The node's files and `api.yaml` (capture W1 item 5, spec D345).

Fixed paths in the node; GM_API_ROOT and GM_API_RUN move them for the
brick's unit tests only (python3 -I ignores PYTHON* variables, not these).

    /srv/api/api.yaml           which hostname serves which endpoint, the
                                credentials each accepts, the connections
    /srv/api/routes/<name>.py   the contract (protected)
    /srv/api/db/<name>.py       the database side (the one writable path)
    /run/gm-api/secrets/        the copies of the mounted secrets the server
                                reads (role_<role>_password, http_<name>),
                                written by gm-entrypoint at every start,
                                owner-only (W1 item 0)
"""

import os
import re

import yaml

from . import ConfigError



def set_paths(root="/srv/api", run="/run/gm-api", log="/var/log/api/api.log"):
    """The node's paths; the unit tests move them."""
    global ROOT, RUN, API_YAML, ROUTES_DIR, DB_DIR, SECRETS_DIR, LOADED_FILE, LOG_FILE
    ROOT, RUN, LOG_FILE = root, run, log
    API_YAML = os.path.join(ROOT, "api.yaml")
    ROUTES_DIR = os.path.join(ROOT, "routes")
    DB_DIR = os.path.join(ROOT, "db")
    SECRETS_DIR = os.path.join(RUN, "secrets")
    LOADED_FILE = os.path.join(RUN, "loaded")


set_paths(os.environ.get("GM_API_ROOT") or "/srv/api", os.environ.get("GM_API_RUN") or "/run/gm-api",
          os.environ.get("GM_API_LOG") or "/var/log/api/api.log")
PORT = 8000

ENDPOINT_RE = re.compile(r"^[a-z][a-z0-9_]*$")          # a Python module's (W1 item 0)
CREDENTIAL_RE = re.compile(r"^[a-z][a-z0-9_]*$")
CONNECTION_RE = re.compile(r"^[a-z][a-z0-9_-]*$")
HOST_RE = re.compile(r"^[a-z0-9]([a-z0-9-]*[a-z0-9])?$")
ROLE_RE = re.compile(r"^[a-z_][a-z0-9_]{0,40}$")
SQL_TARGET_RE = re.compile(r"^([a-z0-9][a-z0-9.-]*):([0-9]{1,5})/([A-Za-z_][A-Za-z0-9_$-]*)$")
HTTP_TARGET_RE = re.compile(r"^([a-z0-9][a-z0-9.-]*):([0-9]{1,5})$")
TIMEOUT_RE = re.compile(r"^([0-9]+)s$")
DRIVERS = ("sql/postgresql", "http")
CONNECTION_KEYS = ("driver", "target", "role", "pool", "credential", "timeout")
DEFAULT_TIMEOUT = 10


class _StrictLoader(yaml.SafeLoader):
    """safe_load, refusing a duplicate mapping key (as the GM's loader does)."""


def _strict_mapping(loader, node, deep=False):
    keys = set()
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in keys:
            raise yaml.constructor.ConstructorError(
                None, None, f"duplicate key {key!r}", key_node.start_mark)
        keys.add(key)
    return loader.construct_mapping(node, deep=deep)


_StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _strict_mapping)


class Endpoint:
    def __init__(self, name, hosts, credentials):
        self.name = name
        self.hosts = hosts
        self.credentials = credentials      # () for a public endpoint


class Connection:
    def __init__(self, name, driver, host, port, database=None, role=None, pool_size=1,
                 per_call=False, credential=None, timeout=DEFAULT_TIMEOUT, target=None):
        self.name = name
        self.driver = driver
        self.host = host
        self.port = port
        self.database = database
        self.role = role
        self.pool_size = pool_size
        self.per_call = per_call
        self.credential = credential
        self.timeout = timeout
        self.target = target


class ApiConfig:
    def __init__(self, endpoints, connections):
        self.endpoints = endpoints          # name -> Endpoint, in file order
        self.connections = connections      # name -> Connection

    def hosts(self):
        """Every hostname some endpoint answers under, sorted."""
        return sorted({h for e in self.endpoints.values() for h in e.hosts})

    def target_hosts(self):
        """The names the connections resolve, sorted (the start-up wait)."""
        return sorted({c.host for c in self.connections.values()})


def _is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def parse(text, label="api.yaml"):
    """-> ApiConfig; raises ConfigError naming the place."""
    try:
        data = yaml.load(text, Loader=_StrictLoader)
    except yaml.YAMLError as exc:
        raise ConfigError(f"{label}: cannot be read: {' '.join(str(exc).split())}") from None
    if not isinstance(data, dict):
        raise ConfigError(f"{label}: not a mapping (endpoints, connections)")
    for key in data:
        if key not in ("endpoints", "connections"):
            raise ConfigError(f"{label}: {key}: not a key of api.yaml (endpoints, connections)")
    raw = data.get("endpoints")
    if not isinstance(raw, dict) or not raw:
        raise ConfigError(f"{label}: endpoints: not a non-empty mapping of endpoint name -> "
                          "its hosts")
    endpoints = {}
    for name, entry in raw.items():
        p = f"{label}: endpoints.{name}"
        if not (isinstance(name, str) and ENDPOINT_RE.match(name)):
            raise ConfigError(f"{p}: not an endpoint name ([a-z][a-z0-9_]*, a Python module's)")
        if not isinstance(entry, dict):
            raise ConfigError(f"{p}: not a mapping (hosts, credentials)")
        for key in entry:
            if key not in ("hosts", "credentials"):
                raise ConfigError(f"{p}.{key}: not a key of an endpoint (hosts, credentials)")
        hosts = entry.get("hosts")
        if not (isinstance(hosts, list) and hosts
                and all(isinstance(h, str) and HOST_RE.match(h) for h in hosts)):
            raise ConfigError(f"{p}.hosts: not a non-empty list of hostnames")
        if len(set(hosts)) != len(hosts):
            raise ConfigError(f"{p}.hosts: a hostname is listed twice")
        creds = entry.get("credentials")
        if "credentials" in entry and not (
                isinstance(creds, list) and creds
                and all(isinstance(c, str) and CREDENTIAL_RE.match(c) for c in creds)):
            raise ConfigError(f"{p}.credentials: not a non-empty list of credential names "
                              "([a-z][a-z0-9_]*); absent for a public endpoint")
        endpoints[name] = Endpoint(name, tuple(hosts), tuple(creds or ()))
    raw = data.get("connections", {})
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        raise ConfigError(f"{label}: connections: not a mapping of connection name -> connection")
    connections = {}
    for name, conn in raw.items():
        connections[name] = _connection(name, conn, f"{label}: connections.{name}")
    return ApiConfig(endpoints, connections)


def _connection(name, conn, p):
    if not (isinstance(name, str) and CONNECTION_RE.match(name)):
        raise ConfigError(f"{p}: not a connection name ([a-z][a-z0-9_-]*)")
    if not isinstance(conn, dict):
        raise ConfigError(f"{p}: not a mapping")
    for key in conn:
        if key not in CONNECTION_KEYS:
            raise ConfigError(f"{p}.{key}: not a key of a connection ({', '.join(CONNECTION_KEYS)})")
    driver = conn.get("driver")
    if driver not in DRIVERS:
        raise ConfigError(f"{p}.driver: {driver!r} is not {' or '.join(DRIVERS)}")
    target = conn.get("target")
    if driver == "sql/postgresql":
        for key in ("credential", "timeout"):
            if key in conn:
                raise ConfigError(f"{p}.{key}: an http connection's key, not an sql/postgresql one")
        m = SQL_TARGET_RE.match(target) if isinstance(target, str) else None
        if m is None:
            raise ConfigError(f"{p}.target: {target!r} is not <node>:<port>/<database>")
        role = conn.get("role")
        if not (isinstance(role, str) and ROLE_RE.match(role)):
            raise ConfigError(f"{p}.role: {role!r} is not a role name ([a-z_][a-z0-9_]{{0,40}})")
        pool = conn.get("pool", {"size": 1})
        if isinstance(pool, dict) and len(pool) == 1 and _is_int(pool.get("size")) and pool["size"] > 0:
            size, per_call = pool["size"], False
        elif isinstance(pool, dict) and len(pool) == 1 and pool.get("per-call") is True:
            size, per_call = 1, True
        else:
            raise ConfigError(f"{p}.pool: {pool!r} is not {{size: N}} (N a positive integer) or "
                              "{per-call: true}")
        port = int(m.group(2))
        if not 1 <= port <= 65535:
            raise ConfigError(f"{p}.target: {target}: {port} is not a port")
        return Connection(name, driver, m.group(1), port, database=m.group(3), role=role,
                          pool_size=size, per_call=per_call, target=target)
    if "role" in conn:
        raise ConfigError(f"{p}.role: an http connection has no role (its credential, if any)")
    m = HTTP_TARGET_RE.match(target) if isinstance(target, str) else None
    if m is None:
        raise ConfigError(f"{p}.target: {target!r} is not <host>:<port>")
    port = int(m.group(2))
    if not 1 <= port <= 65535:
        raise ConfigError(f"{p}.target: {target}: {port} is not a port")
    cred = conn.get("credential")
    if "credential" in conn and not (isinstance(cred, str) and CREDENTIAL_RE.match(cred)):
        raise ConfigError(f"{p}.credential: {cred!r} is not a credential name ([a-z][a-z0-9_]*)")
    pool = conn.get("pool", 1)
    if not (_is_int(pool) and pool > 0):
        raise ConfigError(f"{p}.pool: {pool!r} is not a positive integer (kept-alive connections)")
    timeout = DEFAULT_TIMEOUT
    if "timeout" in conn:
        t = conn["timeout"]
        tm = TIMEOUT_RE.match(t) if isinstance(t, str) else None
        if tm is None or not 1 <= int(tm.group(1)) <= 60:
            raise ConfigError(f"{p}.timeout: {t!r} is not <n>s, 1 to 60")
        timeout = int(tm.group(1))
    return Connection(name, driver, m.group(1), port, pool_size=pool, credential=cred,
                      timeout=timeout, target=target)


def load(path=None):
    path = path or API_YAML
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError as exc:
        raise ConfigError(f"{path}: cannot be read ({exc.strerror})") from None
    except UnicodeDecodeError:
        raise ConfigError(f"{path}: not UTF-8 text") from None
    return parse(text, path)


def read_secret(name):
    """The value of a secret the entrypoint copied, or None when absent."""
    path = os.path.join(SECRETS_DIR, name)
    try:
        with open(path, encoding="utf-8") as f:
            value = f.read()
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise ConfigError(f"secret {name}: cannot be read ({exc.strerror})") from None
    return value.rstrip("\n")


def secrets_for(cfg):
    """The secrets the configuration needs: {credential name: value} and
    {connection name: password}; raises ConfigError naming the first that is
    not mounted (never its value)."""
    credentials = {}
    for e in cfg.endpoints.values():
        for c in e.credentials:
            if c not in credentials:
                v = read_secret(f"http_{c}")
                if not v:
                    raise ConfigError(f"endpoints.{e.name}.credentials: {c}: its secret "
                                      f"http_{c} is not mounted")
                credentials[c] = v
    passwords = {}
    for c in cfg.connections.values():
        if c.driver == "sql/postgresql":
            v = read_secret(f"role_{c.role}_password")
            if not v:
                raise ConfigError(f"connections.{c.name}: the password of role {c.role} "
                                  f"(secret role_{c.role}_password) is not mounted")
            passwords[c.name] = v
        elif c.credential:
            v = read_secret(f"http_{c.credential}")
            if not v:
                raise ConfigError(f"connections.{c.name}.credential: {c.credential}: its secret "
                                  f"http_{c.credential} is not mounted")
            passwords[c.name] = v
    return credentials, passwords
