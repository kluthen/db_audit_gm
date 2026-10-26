"""The rendered schedule, read on standard input (master spec 7.1; capture
W1 item 7; framing: W1-y).

Standard input, written by the s6 run script as root:

    gm-scheduler-input 1
    password <role> <password>        one line per role secret mounted
    schedule
    <schedule.yaml, as rendered, to the end of input>

Error messages name the place in the schedule, never a value of it: they
reach only the container's log.
"""

import re

from . import ConfigError
from .repository import KEY_RE, load_yaml
from .timeutil import parse_instant, parse_rate

INPUT_MAGIC = "gm-scheduler-input 1"
ROLE_RE = re.compile(r"^[a-z_][a-z0-9_]{0,40}$")
FORBIDDEN_ROLES = {"postgres", "dba", "monitoring", "gm_check", "pgbouncer_lookup"}
TARGET_RE = re.compile(r"^([a-z0-9][a-z0-9.-]*):([0-9]{1,5})/([A-Za-z0-9_][A-Za-z0-9_$-]*)$")
CONN_NAME_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
DRIVERS = ("sql/postgresql",)
WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
ARRIVALS = ("poisson", "even")


def parse_input(data):
    """Standard input -> (passwords {role: password}, schedule text)."""
    lines = data.split("\n")
    if not lines or lines[0] != INPUT_MAGIC:
        raise ConfigError(f"standard input: does not begin with {INPUT_MAGIC!r}")
    passwords = {}
    for i, line in enumerate(lines[1:], start=1):
        if line == "schedule":
            return passwords, "\n".join(lines[i + 1:])
        fields = line.split(" ")
        if len(fields) != 3 or fields[0] != "password" or not ROLE_RE.match(fields[1]) or not fields[2]:
            raise ConfigError(f"standard input: line {i + 1}: expected 'password <role> <password>' or 'schedule'")
        passwords[fields[1]] = fields[2]
    raise ConfigError("standard input: no 'schedule' line")


class Connection:
    def __init__(self, name, driver, host, port, database, role, pool_size, per_call):
        self.name, self.driver = name, driver
        self.host, self.port, self.database, self.role = host, port, database, role
        self.pool_size, self.per_call = pool_size, per_call


class Stream:
    def __init__(self, index, key, connection, rate, arrivals, shape, concurrency):
        self.index = index
        self.initial_key = key
        self.key, self.connection, self.rate = key, connection, rate   # rate: per second, intensity 1.0
        self.arrivals, self.shape, self.concurrency = arrivals, shape, concurrency
        self.changes = []          # TimelineChange, by time


class TimelineChange:
    def __init__(self, at, stream, sets):
        self.at, self.stream, self.sets = at, stream, sets   # sets: {key|rate|connection: value}


class Schedule:
    def __init__(self, seed, intensity, connections, streams, shapes, timeline):
        self.seed, self.intensity = seed, intensity
        self.connections, self.streams, self.shapes, self.timeline = connections, streams, shapes, timeline

    def keys(self):
        """Every key the schedule names: the streams' and the timeline's."""
        out = {s.initial_key for s in self.streams}
        out.update(c.sets["key"] for c in self.timeline if "key" in c.sets)
        return out


def _unknown(value, allowed, where):
    extra = set(value) - set(allowed)
    if extra:
        raise ConfigError(f"{where}: unknown key(s) {', '.join(sorted(map(str, extra)))}")


def _number(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def parse_connection(name, value, where):
    if not isinstance(name, str) or not CONN_NAME_RE.match(name):
        raise ConfigError(f"{where}: a connection name is lowercase letters, digits, '.', '_', '-'")
    if not isinstance(value, dict):
        raise ConfigError(f"{where}: a map with driver, target, role, pool")
    _unknown(value, ("driver", "target", "role", "pool"), where)
    if value.get("driver") not in DRIVERS:
        raise ConfigError(f"{where}.driver: one of {', '.join(DRIVERS)}")
    m = TARGET_RE.match(value.get("target") or "") if isinstance(value.get("target"), str) else None
    if not m or not 1 <= int(m.group(2)) <= 65535:
        raise ConfigError(f"{where}.target: <node>:<port>/<database>")
    role = value.get("role")
    if not isinstance(role, str) or not ROLE_RE.match(role) or role in FORBIDDEN_ROLES or role.startswith("pg_"):
        raise ConfigError(f"{where}.role: an application role, never postgres, dba, monitoring, "
                          "gm_check, pgbouncer_lookup or pg_*")
    pool = value.get("pool")
    if isinstance(pool, dict) and set(pool) == {"size"} and isinstance(pool["size"], int) \
            and not isinstance(pool["size"], bool) and pool["size"] >= 1:
        size, per_call = pool["size"], False
    elif pool == {"per-call": True}:
        size, per_call = None, True
    else:
        raise ConfigError(f"{where}.pool: {{size: N}}, N at least 1, or {{per-call: true}}")
    return Connection(name, value["driver"], m.group(1), int(m.group(2)), m.group(3), role, size, per_call)


def parse_shape(name, value, where):
    """A rendered shape -> {weekday 0-6 (Monday 0): [24 multipliers]}."""
    if not isinstance(value, dict) or set(value) != {"utc"} or not isinstance(value["utc"], dict):
        raise ConfigError(f"{where}: a rendered shape is {{utc: {{mon: [24 multipliers], ... sun: [...]}}}}")
    days = value["utc"]
    if set(days) != set(WEEKDAYS):
        raise ConfigError(f"{where}.utc: one entry for each of {', '.join(WEEKDAYS)}")
    out = {}
    for i, day in enumerate(WEEKDAYS):
        hours = days[day]
        if not isinstance(hours, list) or len(hours) != 24 or not all(_number(h) and h >= 0 for h in hours):
            raise ConfigError(f"{where}.utc.{day}: 24 multipliers, each a number at least 0, hour 00 first")
        out[i] = [float(h) for h in hours]
    return out


def parse_schedule(doc, passwords=None):
    where = "schedule"
    if not isinstance(doc, dict):
        raise ConfigError(f"{where}: a map")
    _unknown(doc, ("seed", "intensity", "connections", "streams", "shapes", "timeline"), where)
    seed = doc.get("seed")
    if not isinstance(seed, int) or isinstance(seed, bool) or not 0 <= seed < 2 ** 63:
        raise ConfigError(f"{where}.seed: an integer, 0 <= seed < 2**63")
    intensity = doc.get("intensity")
    if not _number(intensity) or intensity < 0:
        raise ConfigError(f"{where}.intensity: a number at least 0")
    conns = doc.get("connections")
    if not isinstance(conns, dict) or not conns:
        raise ConfigError(f"{where}.connections: a map of at least one connection")
    connections = {n: parse_connection(n, v, f"{where}.connections.{n}") for n, v in conns.items()}
    if passwords is not None:
        for c in connections.values():
            if c.role not in passwords:
                raise ConfigError(f"{where}.connections.{c.name}: no password was passed for its role")
    shapes_doc = doc.get("shapes") or {}
    if not isinstance(shapes_doc, dict):
        raise ConfigError(f"{where}.shapes: a map")
    shapes = {n: parse_shape(n, v, f"{where}.shapes.{n}") for n, v in shapes_doc.items()}
    streams_doc = doc.get("streams") or []
    if not isinstance(streams_doc, list):
        raise ConfigError(f"{where}.streams: a list")
    streams, initial = [], {}
    for i, s in enumerate(streams_doc):
        w = f"{where}.streams[{i}]"
        if not isinstance(s, dict):
            raise ConfigError(f"{w}: a map with key, connection, rate, arrivals")
        _unknown(s, ("key", "connection", "rate", "arrivals", "shape", "concurrency"), w)
        key = s.get("key")
        if not isinstance(key, str) or not KEY_RE.match(key):
            raise ConfigError(f"{w}.key: a key")
        if key in initial:
            raise ConfigError(f"{w}.key: two streams start with the same key")
        if s.get("connection") not in connections:
            raise ConfigError(f"{w}.connection: one of the schedule's connections")
        rate = parse_rate(s.get("rate"), f"{w}.rate")
        if s.get("arrivals") not in ARRIVALS:
            raise ConfigError(f"{w}.arrivals: poisson or even")
        shape = s.get("shape")
        if shape is not None and shape not in shapes:
            raise ConfigError(f"{w}.shape: one of the schedule's shapes")
        concurrency = s.get("concurrency", 1)
        if not isinstance(concurrency, int) or isinstance(concurrency, bool) or concurrency < 1:
            raise ConfigError(f"{w}.concurrency: a whole number, at least 1")
        stream = Stream(i, key, s["connection"], rate, s["arrivals"], shape, concurrency)
        streams.append(stream)
        initial[key] = stream
    timeline_doc = doc.get("timeline") or []
    if not isinstance(timeline_doc, list):
        raise ConfigError(f"{where}.timeline: a list")
    timeline = []
    for i, t in enumerate(timeline_doc):
        w = f"{where}.timeline[{i}]"
        if not isinstance(t, dict):
            raise ConfigError(f"{w}: a map with at, stream, set")
        _unknown(t, ("at", "stream", "set"), w)
        at = parse_instant(t.get("at"), f"{w}.at")
        stream = initial.get(t.get("stream"))
        if stream is None:
            raise ConfigError(f"{w}.stream: the initial key of one of the streams")
        sets = t.get("set")
        if not isinstance(sets, dict) or not sets:
            raise ConfigError(f"{w}.set: a map of key, rate or connection")
        _unknown(sets, ("key", "rate", "connection"), f"{w}.set")
        out = {}
        if "key" in sets:
            if not isinstance(sets["key"], str) or not KEY_RE.match(sets["key"]):
                raise ConfigError(f"{w}.set.key: a key")
            out["key"] = sets["key"]
        if "rate" in sets:
            out["rate"] = parse_rate(sets["rate"], f"{w}.set.rate")
        if "connection" in sets:
            if sets["connection"] not in connections:
                raise ConfigError(f"{w}.set.connection: one of the schedule's connections")
            out["connection"] = sets["connection"]
        change = TimelineChange(at, stream, out)
        timeline.append(change)
        stream.changes.append(change)
    for s in streams:
        s.changes.sort(key=lambda c: c.at)
    return Schedule(seed, float(intensity), connections, streams, shapes, timeline)


def read_schedule(data):
    """Standard input's text -> (Schedule, passwords)."""
    passwords, text = parse_input(data)
    doc = load_yaml(text, "schedule")
    return parse_schedule(doc, passwords), passwords


def apply_past_changes(stream, now):
    """Applies to `stream` every timeline change at or before `now`, in
    order; returns the changes still to come (resuming, nothing replayed)."""
    pending = []
    for c in stream.changes:
        if c.at <= now:
            apply_change(stream, c)
        else:
            pending.append(c)
    return pending


def apply_change(stream, change):
    if "key" in change.sets:
        stream.key = change.sets["key"]
    if "rate" in change.sets:
        stream.rate = change.sets["rate"]
    if "connection" in change.sets:
        stream.connection = change.sets["connection"]
