"""Scenario model: loading and checking a scenario folder.

Loads `scenario.yaml`, `gm/answer-key.yaml`, and every `brick.yaml` and
`fault.yaml` the scenario references (by id and pinned version; the
scenario's own `bricks/` and `faults/` first, then the catalog), and checks
completeness (master spec 6; the scenario-format skill's checklists).

The required keys come from the format skill's templates
(`.claude/skills/scenario-format/templates/`, capture W1-D): a key is
required unless its template line, or a comment line continuing it, says
`# optional`; a commented-out key is not required; an empty list or map is
accepted only where the template's own value is empty or its comment says
"may be []" / "may be {}". The consistency rules of the checklist that a
script can decide are checked here too. Every failure is a missing item,
and all of them are listed, not just the first.
"""

import ast
import datetime
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
TEMPLATES_DIR = REPO_ROOT / ".claude" / "skills" / "scenario-format" / "templates"

NAME_RE = re.compile(r"^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$")   # Kubernetes-style names
PLACEHOLDER_RE = re.compile(r"<[^<>\n]*[A-Za-z0-9][^<>\n]*>")
WRITE_POLICIES = ("fixable", "report-only", "no-access")
ORIGINS = ("hand-written", "from-brief", "gm-designed")
RESOLUTION_KINDS = ("report", "propose", "fix", "improve")
MAX_SESSION_MINUTES = 240

# Parameter shapes, mounted companion material, receiving declarations and
# the web front (v0.2's capture W1, items 2 to 6).
SHAPES = ("node-map", "web-routes")
COMMAND_VOCABULARY = ("sh", "cat", "du", "df", "awk", "sed", "grep", "sleep", "perl",
                      "s6-svstat", "s6-setuidgid")
VERSION_PREFIX_RE = re.compile(r"^\d+(\.\d+)*$")
WEB_PATH_RE = re.compile(r"^/([a-z]([a-z0-9-]{0,61}[a-z0-9])?)/$")
ROUTE_TARGET_RE = re.compile(r"^([a-z]([a-z0-9-]{0,61}[a-z0-9])?):(\d+)$")
WEB_FRONT_PORT = 8080

# The `parameter` injection kind (capture W1, item 8): each op and the keys
# it takes; `{NAME}` is replaced by the instance's fault parameter NAME.
PARAMETER_OPS = {"set": ("value",), "remove-entry": ("entry",),
                 "remove-from-entry": ("entry", "item")}
SUBSTITUTION_RE = re.compile(r"\{([^{}]*)\}")
REPORT_TOOL_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
# An issue covering only tooling expectations (capture W1, item 10).
EXPECTATION_RESOLUTIONS = ("report", "propose")
EXACT_VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$")

# Fault parameters reach inject/ and checks/ scripts as FAULT_<NAME>
# (captures W1-D, W3-A): the name upper-cased, `-` replaced by `_`.
FAULT_ENV_PREFIX = "FAULT_"
FAULT_ENV_NAME_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")

# v0.3's format (master spec 6.1 to 6.4, 6.7; capture W1 of
# specs/versions/v0.3/wave-log.md, items 0 to 4).
SCHEDULER_BRICK = "scheduler"       # a scheduler node: a node whose brick id is this (W1 item 0)
ROLES = ("bastion", "producer", "queue", "database", "pooler", "transformer", "consumer",
         "monitoring", "backup")
DIFFICULTY_LEVELS = ("easy", "normal", "hard")
SNAPSHOT_METHODS = ("pg_basebackup", "copy", "stop")
AGING_TECHNIQUES = ("real-time",)
MIN_AGING_SECONDS = 8 * 3600        # D150, D157
RETENTION_MARGIN_SECONDS = 4 * 3600  # the game's four hours (master spec 6.1)
RETENTION_FAMILY = "retention"      # a fault about retention (W1 item 2)
HANDOVER_MOMENT_RE = re.compile(r"^handover-([1-9][0-9]*)h$")
HANDOVER_AT_RE = re.compile(r"^([01][0-9]|2[0-3]):00$")
CUSTOMER_TIMEZONE = "{{customer_timezone}}"
# Render passes a node's write policy as GM_WRITE_POLICY and GM_WRITE_OVERRIDES
# (W1 item 5), so no brick parameter may take these names (GM_<NAME>).
RESERVED_PARAMETERS = ("write_policy", "write_overrides")
SEED_ENTRY_FILE_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
# pg_hba methods admitting the GM check role (W1 item 8, D164), and those
# admitting pg_basebackup's replication connection as postgres (7.3).
HBA_PASSWORD_METHODS = ("scram-sha-256", "md5", "password", "trust")
HBA_REPLICATION_METHODS = ("peer", "trust")


def fault_env_name(param_name):
    """`FAULT_<NAME>` for a fault parameter, or None when the upper-cased
    name, `-` replaced by `_`, is not `[A-Z][A-Z0-9_]*` (capture W3-A)."""
    name = str(param_name).upper().replace("-", "_")
    return FAULT_ENV_PREFIX + name if FAULT_ENV_NAME_RE.match(name) else None


def _check_param_value(value, where, label, out):
    if isinstance(value, (list, dict)):
        out.append(f"{label}: {where}: a list or map cannot be passed to a script; "
                   "use a scalar")


class GmError(Exception):
    """A refusal or failure that gmctl reports to the GM (exit status 1)."""


class IncompleteScenario(GmError):
    """The scenario, or a brick or fault it references, misses items."""

    def __init__(self, scenario_dir, missing):
        self.scenario_dir = Path(scenario_dir)
        self.missing = list(missing)
        super().__init__(
            f"scenario {self.scenario_dir} is incomplete: "
            f"{len(self.missing)} missing item(s)")

    def report(self):
        return "\n".join([str(self)] + [f"  - {item}" for item in self.missing])


# --- Template schema -----------------------------------------------------

@dataclass
class Field:
    name: str
    optional: bool = False
    allow_empty: bool = False
    allow_null: bool = False
    child: object = None            # MapSchema, ListSchema, or None (scalar or free-form)


@dataclass
class MapSchema:
    fields: dict = field(default_factory=dict)
    free: Field = None              # template keys written as <placeholder>: any key


@dataclass
class ListSchema:
    item: object = None             # MapSchema for a list of mappings, else None


# Keys whose shape the template states in a comment, checked by code instead.
# (queries, pool, shapes: the scheduler's files, whose forms vary per entry.)
_CHECKED_BY_CODE = {"envelope", "queries", "pool", "shapes"}


def _inline_comment(line):
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "#" and (i == 0 or line[i - 1] in " \t"):
            return line[i + 1:].strip()
    return None


def _comments(key_node, lines):
    """The key line's inline comment, and the comment lines continuing it."""
    row, col = key_node.start_mark.line, key_node.start_mark.column
    pieces = []
    inline = _inline_comment(lines[row])
    if inline is not None:
        pieces.append(inline)
    for line in lines[row + 1:]:
        stripped = line.lstrip()
        if not stripped.startswith("#") or len(line) - len(stripped) <= col:
            break
        pieces.append(stripped[1:].strip())
    return pieces


def _build(node, lines):
    if isinstance(node, yaml.MappingNode):
        schema = MapSchema()
        for key_node, value_node in node.value:
            name = key_node.value
            comments = _comments(key_node, lines)
            text = " ".join(comments)
            empty_value = isinstance(value_node, (yaml.MappingNode, yaml.SequenceNode)) \
                and not value_node.value
            f = Field(
                name=name,
                optional=any(c.startswith("optional") for c in comments),
                allow_empty=empty_value or bool(
                    re.search(r"may be `?(\[\]|\{\})`?|may be empty", text)),
                allow_null=isinstance(value_node, yaml.ScalarNode)
                and "null" in value_node.value,
                child=None if name in _CHECKED_BY_CODE else _build(value_node, lines),
            )
            if PLACEHOLDER_RE.fullmatch(name.strip()):
                f.optional = True
                schema.free = f
            else:
                schema.fields[name] = f
        return schema
    if isinstance(node, yaml.SequenceNode):
        first = node.value[0] if node.value else None
        return ListSchema(item=_build(first, lines)
                          if isinstance(first, yaml.MappingNode) else None)
    return None


@lru_cache(maxsize=None)
def template_schema(template_name, templates_dir=TEMPLATES_DIR):
    """The required-key schema of one of the format skill's templates."""
    text = (Path(templates_dir) / template_name).read_text(encoding="utf-8")
    return _build(yaml.compose(text), text.splitlines())


def _item_label(item, index):
    if isinstance(item, dict):
        for key in ("name", "id", "setting", "instance", "key"):
            if isinstance(item.get(key), (str, int)):
                return str(item[key])
    return str(index)


def _join(path, name):
    return f"{path}.{name}" if path else str(name)


def check_against_schema(value, schema, label, path="", out=None):
    """Missing items of `value` against a template schema."""
    out = [] if out is None else out
    if isinstance(schema, MapSchema):
        if not isinstance(value, dict):
            out.append(f"{label}: {path or 'top level'}: not a mapping")
            return out
        for name, f in schema.fields.items():
            p = _join(path, name)
            if name not in value:
                if not f.optional:
                    out.append(f"{label}: {p}: missing")
                continue
            _check_value(value[name], f, label, p, out)
        if schema.free is not None:
            for key, item in value.items():
                if key not in schema.fields:
                    _check_value(item, schema.free, label, _join(path, key), out)
    elif isinstance(schema, ListSchema):
        if not isinstance(value, list):
            out.append(f"{label}: {path}: not a list")
            return out
        if schema.item is not None:
            for i, item in enumerate(value):
                check_against_schema(item, schema.item, label,
                                     f"{path}[{_item_label(item, i)}]", out)
    return out


def _check_value(value, f, label, path, out):
    if value is None:
        if not f.allow_null:
            out.append(f"{label}: {path}: empty")
        return
    if isinstance(value, (list, dict)) and not value and not f.allow_empty:
        out.append(f"{label}: {path}: empty")
        return
    if f.child is not None:
        check_against_schema(value, f.child, label, path, out)


def placeholders(value, label, path="", out=None):
    """Every `<placeholder>` left in keys or string values."""
    out = [] if out is None else out
    if isinstance(value, dict):
        for key, item in value.items():
            p = _join(path, key)
            if isinstance(key, str) and PLACEHOLDER_RE.search(key):
                out.append(f"{label}: {p}: placeholder key left")
            placeholders(item, label, p, out)
    elif isinstance(value, list):
        for i, item in enumerate(value):
            placeholders(item, label, f"{path}[{_item_label(item, i)}]", out)
    elif isinstance(value, str):
        m = PLACEHOLDER_RE.search(value)
        if m:
            out.append(f"{label}: {path or 'top level'}: placeholder {m.group(0)} left")
    return out


# --- Units ---------------------------------------------------------------

_SIZE_RE = re.compile(r"^\s*(\d+(?:\.\d+)?)\s*([kKmMgGtT])?([iI])?([bB])?\s*$")
_SIZE_UNITS = {None: 1, "k": 1024, "m": 1024 ** 2, "g": 1024 ** 3, "t": 1024 ** 4}


def parse_size(value):
    """Bytes in a memory or disk size (`512M`, `1G`, `1.5G`, `256MB`, 1024)."""
    if isinstance(value, bool):
        raise ValueError(f"not a size: {value!r}")
    if isinstance(value, int):
        return value
    m = _SIZE_RE.match(str(value))
    if not m or (m.group(2) is None and (m.group(3) or m.group(4))):
        raise ValueError(f"not a size: {value!r}")
    unit = m.group(2).lower() if m.group(2) else None
    return int(float(m.group(1)) * _SIZE_UNITS[unit])


def parse_cpu(value):
    """A CPU count (0.5, "2")."""
    if isinstance(value, bool):
        raise ValueError(f"not a CPU count: {value!r}")
    try:
        cpu = float(value)
    except (TypeError, ValueError):
        raise ValueError(f"not a CPU count: {value!r}") from None
    if cpu <= 0:
        raise ValueError(f"not a CPU count: {value!r}")
    return cpu


_DURATION_RE = re.compile(r"^([0-9]+)([smhd])$")
_DURATION_UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400}


def parse_duration(value):
    """Seconds in a duration `<integer><s|m|h|d>` (`16h`, `30m`, `0m`;
    capture W1 of v0.3, item 0)."""
    m = _DURATION_RE.match(value) if isinstance(value, str) else None
    if m is None:
        raise ValueError(f"{value!r} is not a duration (<integer><s|m|h|d>: 30m, 16h, 2d, 0m)")
    return int(m.group(1)) * _DURATION_UNITS[m.group(2)]


_PROM_DURATION_RE = re.compile(r"^(?:([0-9]+)y)?(?:([0-9]+)w)?(?:([0-9]+)d)?(?:([0-9]+)h)?"
                               r"(?:([0-9]+)m)?(?:([0-9]+)s)?(?:([0-9]+)ms)?$")
_PROM_DURATION_UNITS = (365 * 86400, 7 * 86400, 86400, 3600, 60, 1, 0.001)


def parse_prometheus_duration(value):
    """Seconds in a Prometheus duration (`1d`, `12h`, `1h30m`, `2w`)."""
    m = _PROM_DURATION_RE.match(value) if isinstance(value, str) and value else None
    if m is None:
        raise ValueError(f"{value!r} is not a Prometheus duration (1d, 12h, 1h30m)")
    return sum(int(n) * unit for n, unit in zip(m.groups(), _PROM_DURATION_UNITS) if n)


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def format_size(nbytes):
    for unit, factor in (("G", 1024 ** 3), ("M", 1024 ** 2), ("K", 1024)):
        if nbytes >= factor:
            return f"{nbytes / factor:.2f}".rstrip("0").rstrip(".") + unit
    return f"{nbytes}B"


_PG_MEMORY = {"B": 1, "kB": 1024, "MB": 1024 ** 2, "GB": 1024 ** 3, "TB": 1024 ** 4}
_PG_TIME = {"us": 1e-6, "ms": 1e-3, "s": 1, "min": 60, "h": 3600, "d": 86400}
_PG_TRUE = {"on", "true", "yes"}
_PG_FALSE = {"off", "false", "no"}


def pg_value(value):
    """A PostgreSQL setting value as (kind, comparable): kind is num, memory,
    time or text. YAML booleans read as on/off."""
    if isinstance(value, bool):
        return ("text", "on" if value else "off")
    if isinstance(value, (int, float)):
        return ("num", float(value))
    text = str(value).strip().strip("'\"").strip()
    m = re.fullmatch(r"(-?\d+(?:\.\d+)?)\s*([A-Za-z]+)?", text)
    if m:
        number, unit = float(m.group(1)), m.group(2)
        if unit is None:
            return ("num", number)
        if unit in _PG_MEMORY:
            return ("memory", number * _PG_MEMORY[unit])
        if unit in _PG_TIME:
            return ("time", number * _PG_TIME[unit])
    lowered = text.lower()
    if lowered in _PG_TRUE:
        return ("text", "on")
    if lowered in _PG_FALSE:
        return ("text", "off")
    return ("text", lowered)


def pg_equal(a, b):
    return pg_value(a) == pg_value(b)


def pg_compare(a, b):
    """-1, 0 or 1; ValueError when the two values cannot be ordered."""
    (ka, va), (kb, vb) = pg_value(a), pg_value(b)
    if ka != kb or ka == "text":
        raise ValueError(f"cannot compare {a!r} with {b!r}")
    return (va > vb) - (va < vb)


def pg_less(a, b):
    return pg_compare(a, b) < 0


def parse_mode(value):
    """A quoted octal mode string ("0400"), parsed in base 8 (capture W1-D)."""
    if not isinstance(value, str) or not re.fullmatch(r"0?[0-7]{3,4}", value):
        raise ValueError(f"mode {value!r} is not a quoted octal string")
    return int(value, 8)


def read_conf_settings(text):
    """`name = value` settings of a postgresql.conf-style file; last one wins."""
    settings = {}
    for line in text.splitlines():
        comment = _conf_comment_start(line)
        line = (line if comment is None else line[:comment]).strip()
        m = re.match(r"([A-Za-z_][\w.]*)\s*(?:=\s*|\s+)(.*)$", line)
        if m:
            settings[m.group(1).lower()] = m.group(2).strip()
    return settings


def _conf_comment_start(line):
    quoted = False
    for i, ch in enumerate(line):
        if ch == "'":
            quoted = not quoted
        elif ch == "#" and not quoted:
            return i
    return None


# --- Definitions and the scenario ------------------------------------------

@dataclass
class Definition:
    """A brick or fault definition, as found."""
    kind: str                       # brick | fault
    id: str
    version: str
    dir: Path
    data: dict
    source: str                     # scenario | catalog

    @property
    def file(self):
        return self.dir / f"{self.kind}.yaml"


@dataclass
class Scenario:
    dir: Path
    data: dict
    answer_key: dict
    bricks: dict                    # node name -> Definition
    faults: dict                    # fault instance id -> Definition

    @property
    def id(self):
        return self.data["id"]

    @property
    def nodes(self):
        return self.data["nodes"]

    def node(self, name):
        for node in self.nodes:
            if node["name"] == name:
                return node
        raise KeyError(name)


def _load_yaml(path, label, out):
    try:
        with open(path, encoding="utf-8") as fh:
            return yaml.safe_load(fh)
    except FileNotFoundError:
        out.append(f"{label}: missing file")
    except (yaml.YAMLError, UnicodeDecodeError) as exc:
        detail = " ".join(str(exc).split())
        out.append(f"{label}: cannot be read: {detail}")
    return None


def _rel(path, *bases):
    path = Path(path)
    for base in bases:
        try:
            return str(path.relative_to(base))
        except ValueError:
            continue
    return str(path)


def _inside(base, relpath):
    """`base / relpath` if it stays inside `base`, else None."""
    if not isinstance(relpath, str) or not relpath:
        return None
    path = (base / relpath).resolve()
    try:
        path.relative_to(base.resolve())
    except ValueError:
        return None
    return path


def _check_modes(entries, label, key, out):
    for i, entry in enumerate(entries or []):
        if isinstance(entry, dict) and "mode" in entry:
            try:
                parse_mode(entry["mode"])
            except ValueError as exc:
                out.append(f"{label}: {key}[{_item_label(entry, i)}].mode: {exc}")


def check_brick_dir(brick_dir, label_base=None):
    """Missing items of a brick folder (format skill, "Brick")."""
    brick_dir = Path(brick_dir)
    base = Path(label_base) if label_base else brick_dir.parent.parent
    label = _rel(brick_dir / "brick.yaml", base)
    out = []
    data = _load_yaml(brick_dir / "brick.yaml", label, out)
    if data is None:
        return out
    check_against_schema(data, template_schema("brick.yaml"), label, out=out)
    placeholders(data, label, out=out)
    if not isinstance(data, dict):
        return out
    for rel in ("Dockerfile", "docs/player.md", "docs/gm.md"):
        if not (brick_dir / rel).is_file():
            out.append(f"{_rel(brick_dir / rel, base)}: missing file")
    if not (brick_dir / "validator").is_dir():
        out.append(f"{_rel(brick_dir / 'validator', base)}/: missing folder")
    if data.get("companion") and not (brick_dir / "companion").is_dir():
        out.append(f"{_rel(brick_dir / 'companion', base)}/: missing folder "
                   "(brick.yaml sets companion)")
    if data.get("id") != brick_dir.name:
        out.append(f"{label}: id: {data.get('id')} is not the folder name {brick_dir.name}")
    image = str(data.get("image", ""))
    first = image.split("/", 1)[0]
    if "/" not in image or not ("." in first or ":" in first or first == "localhost"):
        out.append(f"{label}: image: {image} is not registry-qualified")
    _check_modes(data.get("secrets"), label, "secrets", out)
    _check_modes(data.get("protected_configs"), label, "protected_configs", out)
    if not isinstance(data.get("stateful"), bool):
        out.append(f"{label}: stateful: not a boolean")
    _check_resources(data.get("footprint"), "footprint", out, label)
    params = data.get("parameters")
    for pname, spec in params.items() if isinstance(params, dict) else ():
        if isinstance(spec, dict) and "shape" in spec and spec["shape"] not in SHAPES:
            out.append(f"{label}: parameters.{pname}.shape: {spec['shape']} is not "
                       f"{' or '.join(SHAPES)}")
    provides = _dict(data.get("interfaces")).get("provides")
    for i, iface in enumerate(provides if isinstance(provides, list) else []):
        if isinstance(iface, dict) and "web_path" in iface \
                and not WEB_PATH_RE.match(str(iface["web_path"])):
            out.append(f"{label}: interfaces.provides[{_item_label(iface, i)}].web_path: "
                       f"{iface['web_path']} is not /<route>/ (one lowercase name between "
                       "slashes)")
    _check_mounted(data, brick_dir, base, label, out)
    _check_receives(data.get("receives"), label, out)
    _check_brick_v03(data, label, out)
    return out


def _path_problem(path):
    """Why an in-container path is not absolute, whitespace-free and without a
    trailing / (capture W1 of v0.3, item 0), or None."""
    if not isinstance(path, str) or not path.startswith("/"):
        return f"{path!r} is not an absolute path"
    if re.search(r"\s", path):
        return f"{path!r} contains whitespace"
    if len(path) > 1 and path.endswith("/"):
        return f"{path} ends with /"
    return None


def _check_brick_v03(data, label, out):
    """v0.3's brick keys (master spec 6.4; capture W1 of v0.3, items 3 and 5):
    the roles list, the growth per hour, writable_paths, seed.paths and
    seed.modes, only_with_role, report_tools, snapshot, reserved parameters."""
    roles = data.get("roles")
    for role in roles if isinstance(roles, list) else []:
        if role not in ROLES:
            out.append(f"{label}: roles: {role} is not in the roles list ({' '.join(ROLES)}; "
                       "master spec 6.4)")
    growth = _dict(data.get("footprint")).get("disk_growth_per_hour")
    if growth is not None:
        try:
            parse_size(growth)
        except ValueError as exc:
            out.append(f"{label}: footprint.disk_growth_per_hour: {exc}")
    writable = data.get("writable_paths")
    for path in writable if isinstance(writable, list) else []:
        problem = _path_problem(path)
        if problem:
            out.append(f"{label}: writable_paths: {problem}")
    for pname in _dict(data.get("parameters")):
        if pname in RESERVED_PARAMETERS:
            out.append(f"{label}: parameters.{pname}: a reserved name: render passes the node's "
                       "write policy and overrides as GM_WRITE_POLICY and GM_WRITE_OVERRIDES")
    seed = _dict(data.get("seed"))
    files = [f for f in seed.get("files") or [] if isinstance(f, str)] \
        if isinstance(seed.get("files"), list) else []
    paths = seed.get("paths")
    if isinstance(paths, dict):
        for fname in files:
            if fname not in paths:
                out.append(f"{label}: seed.paths: no entry for the seed file {fname}")
        for fname, path in paths.items():
            if fname not in files:
                out.append(f"{label}: seed.paths.{fname}: not a seed file of the brick "
                           "(seed.files)")
            problem = _path_problem(path)
            if problem:
                out.append(f"{label}: seed.paths.{fname}: {problem}")
    modes = seed.get("modes")
    for fname, mode in modes.items() if isinstance(modes, dict) else ():
        if fname not in files:
            out.append(f"{label}: seed.modes.{fname}: not a seed file of the brick (seed.files)")
        try:
            parse_mode(mode)
        except ValueError as exc:
            out.append(f"{label}: seed.modes.{fname}: {exc}")
    secrets = data.get("secrets")
    for i, secret in enumerate(secrets if isinstance(secrets, list) else []):
        role = _dict(secret).get("only_with_role")
        if role is not None and role not in ROLES:
            out.append(f"{label}: secrets[{_item_label(secret, i)}].only_with_role: {role} is not "
                       f"in the roles list ({' '.join(ROLES)})")
    tools = data.get("report_tools")
    if "report_tools" in data and not isinstance(tools, list):
        out.append(f"{label}: report_tools: not a list")
    for tool in tools if isinstance(tools, list) else []:
        if not (isinstance(tool, str) and REPORT_TOOL_RE.match(tool)):
            out.append(f"{label}: report_tools: {tool!r} is not a tool name in lowercase "
                       "(pgbadger)")
    if "snapshot" in data:
        _check_snapshot(data, label, out)


def _check_snapshot(data, label, out):
    """`snapshot:` (master spec 6.4, 7.3 "Snapshot"; W1 item 3, D167): every
    volume but the one at /run, once, by pg_basebackup, copy or stop; at most
    one pg_basebackup volume. Whether the brick ships gm-snapshot-db is its
    stack test's, not the loader's."""
    snapshot = data.get("snapshot")
    if not isinstance(snapshot, dict) or not snapshot:
        out.append(f"{label}: snapshot: not a map of volume name -> "
                   f"{' | '.join(SNAPSHOT_METHODS)}")
        return
    volumes = {v.get("name"): v.get("path") for v in data.get("volumes") or []
               if isinstance(v, dict)} if isinstance(data.get("volumes"), list) else {}
    for volume, method in snapshot.items():
        if volume not in volumes:
            out.append(f"{label}: snapshot.{volume}: not a volume of the brick")
        elif volumes[volume] == "/run":
            out.append(f"{label}: snapshot.{volume}: the volume at /run is never copied (emptied "
                       "at every start; master spec 6.4)")
        if method not in SNAPSHOT_METHODS:
            out.append(f"{label}: snapshot.{volume}: {method} is not one of "
                       f"{', '.join(SNAPSHOT_METHODS)}")
    for volume, path in volumes.items():
        if path != "/run" and volume not in snapshot:
            out.append(f"{label}: snapshot: volume {volume} is not named (snapshot names every "
                       "volume but the one at /run)")
    online = [str(v) for v, m in snapshot.items() if m == "pg_basebackup"]
    if len(online) > 1:
        out.append(f"{label}: snapshot: {', '.join(online)}: at most one pg_basebackup volume "
                   "per brick")


def _version_prefix_problem(value):
    if not isinstance(value, str):
        return f"{value!r} is not a quoted version string"
    if not VERSION_PREFIX_RE.match(value):
        return f"{value} is not a version (digits and dots)"
    return None


def _unknown_commands(commands):
    return [c for c in commands if c not in COMMAND_VOCABULARY] \
        if isinstance(commands, list) else []


def _check_read_only_mode(entry, p, label, out):
    if not isinstance(entry, dict) or "mode" not in entry:
        return
    try:
        mode = parse_mode(entry["mode"])
    except ValueError as exc:
        out.append(f"{label}: {p}.mode: {exc}")
        return
    if mode & 0o222:
        out.append(f"{label}: {p}.mode: {entry['mode']} has a write bit (mounted material "
                   "is read-only)")


def _check_target(entry, p, label, out):
    if isinstance(entry, dict) and "target" in entry \
            and not (isinstance(entry["target"], str) and entry["target"].startswith("/")):
        out.append(f"{label}: {p}.target: {entry['target']} is not an absolute path")


def mounted_items(brick_data):
    """The brick's `companion.mounted` items (mappings only)."""
    companion = brick_data.get("companion")
    mounted = companion.get("mounted") if isinstance(companion, dict) else None
    return [m for m in mounted or [] if isinstance(m, dict)] \
        if isinstance(mounted, list) else []


def _check_mounted(data, brick_dir, base, label, out):
    """Mounted companion material (capture W1, item 4)."""
    params = data.get("parameters") if isinstance(data.get("parameters"), dict) else {}
    seen = set()
    for item in mounted_items(data):
        name = item.get("name")
        p = f"companion.mounted[{name}]"
        if name is not None and not (isinstance(name, str) and NAME_RE.match(name)):
            out.append(f"{label}: {p}.name: {name!r} is not lowercase letters, digits and "
                       "hyphens starting with a letter")
        if name in seen:
            out.append(f"{label}: {p}: duplicate item name")
        seen.add(name)
        pname = item.get("parameter")
        if pname is not None:
            spec = params.get(pname)
            if spec is None:
                out.append(f"{label}: {p}.parameter: {pname} is not a parameter of the brick")
            elif not isinstance(spec, dict) or spec.get("shape") != "node-map":
                out.append(f"{label}: {p}.parameter: {pname} is not a node-map parameter "
                           "(shape: node-map)")
        files = item.get("files")
        for entry in files if isinstance(files, list) else []:
            if not isinstance(entry, dict):
                continue
            source = entry.get("source")
            fp = f"{p}.files[{source}]"
            if source is not None:
                path = _inside(brick_dir, source)
                if not (isinstance(source, str) and source.startswith("companion/")
                        and path is not None):
                    out.append(f"{label}: {fp}.source: {source} is not under companion/")
                elif not path.is_file():
                    out.append(f"{_rel(brick_dir / source, base)}: missing file ({p}.files)")
            _check_target(entry, fp, label, out)
            _check_read_only_mode(entry, fp, label, out)
        node_config = item.get("node_config")
        _check_target(node_config, f"{p}.node_config", label, out)
        _check_read_only_mode(node_config, f"{p}.node_config", label, out)
        _check_resources(item.get("footprint"), f"{p}.footprint", out, label)
        requires = item.get("requires")
        if isinstance(requires, dict):
            if "s6_overlay" in requires:
                problem = _version_prefix_problem(requires["s6_overlay"])
                if problem:
                    out.append(f"{label}: {p}.requires.s6_overlay: {problem}")
            for command in _unknown_commands(requires.get("commands")):
                out.append(f"{label}: {p}.requires.commands: {command} is not in the command "
                           f"vocabulary ({' '.join(COMMAND_VOCABULARY)})")


def _check_receives(receives, label, out):
    """A receiving declaration (capture W1, item 5)."""
    if not isinstance(receives, dict):
        return
    if "s6_overlay" in receives:
        problem = _version_prefix_problem(receives["s6_overlay"])
        if problem:
            out.append(f"{label}: receives.s6_overlay: {problem}")
    for command in _unknown_commands(receives.get("commands")):
        out.append(f"{label}: receives.commands: {command} is not in the command vocabulary "
                   f"({' '.join(COMMAND_VOCABULARY)})")


def check_fault_dir(fault_dir, label_base=None):
    """Missing items of a fault folder (format skill, "Fault")."""
    fault_dir = Path(fault_dir)
    base = Path(label_base) if label_base else fault_dir.parent.parent
    label = _rel(fault_dir / "fault.yaml", base)
    out = []
    data = _load_yaml(fault_dir / "fault.yaml", label, out)
    if data is None:
        return out
    check_against_schema(data, template_schema("fault.yaml"), label, out=out)
    placeholders(data, label, out=out)
    if not isinstance(data, dict):
        return out
    for rel in ("checks/fixed.sh", "checks/probe.md", "gm.md"):
        if not (fault_dir / rel).is_file():
            out.append(f"{_rel(fault_dir / rel, base)}: missing file")
    if data.get("id") != fault_dir.name:
        out.append(f"{label}: id: {data.get('id')} is not the folder name {fault_dir.name}")
    injection = data.get("injection") or {}
    kind = injection.get("kind")
    if kind == "seed-file":
        if not injection.get("seed_changes"):
            out.append(f"{label}: injection.seed_changes: missing (kind seed-file)")
        for change in injection.get("seed_changes") or []:
            material = change.get("material") if isinstance(change, dict) else None
            if material and not (fault_dir / material).is_file():
                out.append(f"{_rel(fault_dir / str(material), base)}: missing file")
    elif kind == "state":
        if not injection.get("scripts"):
            out.append(f"{label}: injection.scripts: missing (kind state)")
        for script in injection.get("scripts") or []:
            if not (fault_dir / str(script)).is_file():
                out.append(f"{_rel(fault_dir / str(script), base)}: missing file")
    elif kind is not None and kind != "parameter":
        out.append(f"{label}: injection.kind: {kind} is not seed-file, state or parameter")
    params = data.get("parameters")
    env_names = {}
    for pname, spec in params.items() if isinstance(params, dict) else ():
        env = fault_env_name(pname)
        if env is None:
            out.append(f"{label}: parameters.{pname}: not a valid environment name once "
                       f"upper-cased with - as _ (FAULT_ then [A-Z][A-Z0-9_]*)")
        elif env in env_names:
            out.append(f"{label}: parameters.{pname}: same environment name {env} as "
                       f"parameter {env_names[env]}")
        else:
            env_names[env] = pname
        if isinstance(spec, dict):
            _check_param_value(spec.get("default"), f"parameters.{pname}.default", label, out)
    if kind == "parameter":
        _check_parameter_changes(injection, env_names, label, out)
    _check_applies_to_versions(data.get("applies_to"), label, out)
    script = (data.get("sealed_check") or {}).get("script")
    if script and not (fault_dir / str(script)).is_file():
        out.append(f"{_rel(fault_dir / str(script), base)}: missing file (sealed_check.script)")
    kinds = _resolution_kinds(data)
    acceptance = data.get("acceptance") or {}
    for kind_name, key in (("propose", "proposal"), ("fix", "fix"), ("improve", "improvement")):
        if kind_name in kinds and not acceptance.get(key):
            out.append(f"{label}: acceptance.{key}: missing (resolutions lists {kind_name})")
    for i, res in enumerate(data.get("resolutions") or []):
        if isinstance(res, dict) and res.get("kind") not in RESOLUTION_KINDS:
            out.append(f"{label}: resolutions[{i}].kind: {res.get('kind')} is not one of "
                       f"{', '.join(RESOLUTION_KINDS)}")
    _check_fault_v03(data, label, out)
    return out


def _check_fault_v03(data, label, out):
    """v0.3's fault keys (master spec 6.3, 6.7; capture W1 of v0.3, item 2):
    aging, evidence locations, the behavioural flag."""
    aging = data.get("aging")
    if isinstance(aging, dict):
        if "technique" in aging and aging["technique"] not in AGING_TECHNIQUES:
            out.append(f"{label}: aging.technique: {aging['technique']} is not "
                       f"{' or '.join(AGING_TECHNIQUES)} (the only technique in v0.3)")
        if "minimum" in aging:
            try:
                parse_duration(aging["minimum"])
            except ValueError as exc:
                out.append(f"{label}: aging.minimum: {exc}")
    evidence = data.get("evidence")
    for i, item in enumerate(evidence if isinstance(evidence, list) else []):
        where = _dict(item).get("where")
        if where is None:
            continue                     # reported as missing
        p = f"{label}: evidence[{i}].where"
        kind, _, name = where.partition(":") if isinstance(where, str) else ("", "", "")
        if where in ("node", "bastion"):
            continue
        if kind == "report" and REPORT_TOOL_RE.match(name):
            continue
        if kind == "ui":
            out.append(f"{p}: {where}: a fault never reads through a web interface, whose routes "
                       "only the scenario knows; the answer key carries that reading (D145)")
        elif kind == "node" and name:
            out.append(f"{p}: {where}: a fault reads at node (its target node); a reading on "
                       "another node is the scenario's, in its answer key (D167)")
        else:
            out.append(f"{p}: {where!r} is not node, bastion or report:<tool> (the tool in "
                       "lowercase)")
    sealed = _dict(data.get("sealed_check"))
    if "behavioural" in sealed and not isinstance(sealed["behavioural"], bool):
        out.append(f"{label}: sealed_check.behavioural: {sealed['behavioural']!r} is not a "
                   "boolean")


def fault_aging_minimum(fault_data):
    """Seconds of a fault definition's aging.minimum, or None when it is not
    a duration (reported with the fault)."""
    try:
        return parse_duration(_dict(fault_data.get("aging")).get("minimum"))
    except ValueError:
        return None


def is_behavioural(fault_data):
    return _dict(fault_data.get("sealed_check")).get("behavioural") is True


def _check_parameter_changes(injection, env_names, label, out):
    """A `parameter` injection (capture W1, item 8): well-formed changes,
    planted at render, `{NAME}` naming a parameter of the fault."""
    if injection.get("stage") not in (None, "seed"):
        out.append(f"{label}: injection.stage: {injection['stage']}, but a parameter fault is "
                   "planted at render (seed)")
    changes = injection.get("parameter_changes")
    if not changes:
        out.append(f"{label}: injection.parameter_changes: missing (kind parameter)")
        return
    for i, change in enumerate(changes if isinstance(changes, list) else []):
        if not isinstance(change, dict):
            continue
        p = f"injection.parameter_changes[{i}]"
        op = change.get("op")
        if op not in PARAMETER_OPS:
            if op is not None:
                out.append(f"{label}: {p}.op: {op} is not one of {', '.join(PARAMETER_OPS)}")
        else:
            for key in ("entry", "item", "value"):
                if key in PARAMETER_OPS.get(op, ()) and key not in change:
                    out.append(f"{label}: {p}.{key}: missing (op {op})")
                elif key in change and key not in PARAMETER_OPS.get(op, ()):
                    out.append(f"{label}: {p}.{key}: not used by op {op}")
        for key in ("entry", "item", "value"):
            value = change.get(key)
            if isinstance(value, (list, dict)):
                out.append(f"{label}: {p}.{key}: a list or map; use a scalar")
            for name in SUBSTITUTION_RE.findall(value) if isinstance(value, str) else ():
                if FAULT_ENV_PREFIX + name not in env_names:
                    out.append(f"{label}: {p}.{key}: {{{name}}} names no parameter of the "
                               "fault")


def _check_applies_to_versions(applies_to, label, out):
    """Brick versions one by one, exact strings, never ranges (capture W1,
    item 8; master spec 6.4)."""
    bricks = _dict(applies_to).get("bricks")
    for i, entry in enumerate(bricks if isinstance(bricks, list) else []):
        versions = _dict(entry).get("versions")
        for version in versions if isinstance(versions, list) else []:
            if not (isinstance(version, str) and EXACT_VERSION_RE.match(version)):
                out.append(f"{label}: applies_to.bricks[{_item_label(entry, i)}].versions: "
                           f"{version!r} is not an exact version string (one by one, never "
                           "a range)")


def _resolution_kinds(fault_data):
    return {r.get("kind") for r in fault_data.get("resolutions") or [] if isinstance(r, dict)}


def find_definition(kind, ref_id, ref_version, scenario_dir, catalog_root):
    """(Definition or None, problem or None, missing items of the definition)."""
    folder = "bricks" if kind == "brick" else "faults"
    if not isinstance(ref_id, str) or not NAME_RE.match(ref_id):
        return None, f"{kind} id {ref_id!r} is not a valid id", []
    candidates = [(Path(scenario_dir) / folder / ref_id, "scenario", Path(scenario_dir)),
                  (Path(catalog_root) / folder / ref_id, "catalog", Path(catalog_root))]
    for directory, source, base in candidates:
        if not (directory / f"{kind}.yaml").is_file():
            continue
        check = check_brick_dir if kind == "brick" else check_fault_dir
        missing = check(directory, label_base=base)
        data = yaml.safe_load((directory / f"{kind}.yaml").read_text(encoding="utf-8")) \
            if not any("cannot be read" in m for m in missing) else None
        if not isinstance(data, dict):
            return None, None, missing
        found = str(data.get("version"))
        if found != str(ref_version):
            return None, (f"pins {ref_id} {ref_version}, but "
                          f"{_rel(directory / f'{kind}.yaml', base)} has version {found}"), []
        return Definition(kind, ref_id, found, directory, data, source), None, missing
    return None, (f"{kind} {ref_id} not found (looked in {folder}/{ref_id}/ of the "
                  f"scenario, then of the catalog)"), []


def check_scenario(scenario_dir, catalog_root=REPO_ROOT):
    """(Scenario or None, missing items). The Scenario is returned only when
    nothing is missing."""
    sdir = Path(scenario_dir).resolve()
    out = []
    if not sdir.is_dir():
        return None, [f"{scenario_dir}: not a folder"]
    label = "scenario.yaml"
    data = _load_yaml(sdir / label, label, out)
    if data is None:
        return None, out
    check_against_schema(data, template_schema("scenario.yaml"), label, out=out)
    placeholders(data, label, out=out)
    if not isinstance(data, dict):
        return None, out
    _check_information(data, sdir, out)

    nodes = [n for n in data.get("nodes") or [] if isinstance(n, dict)]
    node_names = [n.get("name") for n in nodes]
    network_names = {n.get("name") for n in data.get("networks") or [] if isinstance(n, dict)}
    for name in sorted({n for n in node_names if node_names.count(n) > 1}, key=str):
        out.append(f"{label}: nodes[{name}]: duplicate node name")

    bricks = {}
    for node in nodes:
        brick = _check_node(node, sdir, catalog_root, network_names, out)
        if brick is not None:
            bricks[node.get("name")] = brick

    _check_node_maps(nodes, bricks, out)
    routes = _check_web_routes(nodes, bricks, out)

    for i, flow in enumerate(data.get("flows") or []):
        if isinstance(flow, dict):
            for end in ("from", "to"):
                if end in flow and flow[end] not in node_names:
                    out.append(f"{label}: flows[{i}].{end}: {flow[end]} is not a node")

    scheduled = has_scheduler_nodes(data)
    minimum = _check_aging(data, nodes, out)
    _check_difficulty(data, out)
    faults = _check_faults(data, nodes, bricks, sdir, catalog_root, out)
    _check_planting(data, faults, scheduled, minimum, out)
    answer_key = _check_answer_key(data, nodes, bricks, faults, routes, sdir, out)
    _check_issues(data, nodes, bricks, faults, expectation_ids(answer_key), out)
    _check_designed_for(data, nodes, out)
    _check_customer_timezone(nodes, scheduled, sdir, out)
    _check_retention(data, nodes, bricks, faults, scheduled, minimum, sdir, out)
    _check_postgres_seeds(nodes, bricks, sdir, out)
    _check_scheduler_files(data, nodes, faults, minimum, sdir, out)

    if out:
        return None, out
    return Scenario(sdir, data, answer_key, bricks, faults), []


def load_scenario(scenario_dir, catalog_root=REPO_ROOT):
    """The checked Scenario; raises IncompleteScenario listing every missing item."""
    scenario, missing = check_scenario(scenario_dir, catalog_root)
    if missing:
        raise IncompleteScenario(scenario_dir, missing)
    return scenario


def _check_information(data, sdir, out):
    label = "scenario.yaml"
    sid = data.get("id")
    if sid is not None and not (isinstance(sid, str) and NAME_RE.match(sid)):
        out.append(f"{label}: id: {sid!r} is not lowercase letters, digits and hyphens "
                   "starting with a letter")
    minutes = data.get("session_length_minutes")
    if minutes is not None:
        if not isinstance(minutes, int) or isinstance(minutes, bool) or minutes <= 0:
            out.append(f"{label}: session_length_minutes: {minutes!r} is not a number of minutes")
        elif minutes > MAX_SESSION_MINUTES:
            out.append(f"{label}: session_length_minutes: {minutes} is more than "
                       f"{MAX_SESSION_MINUTES}")
    origin = data.get("origin")
    if origin is not None and origin not in ORIGINS:
        out.append(f"{label}: origin: {origin} is not one of {', '.join(ORIGINS)}")
    date = data.get("date")
    if date is not None and not isinstance(date, datetime.date):
        out.append(f"{label}: date: {date!r} is not YYYY-MM-DD")
    files = ["README.md", "player/README.md", "player/story.md", "player/issues.md",
             "gm/answer-key.yaml"]
    if isinstance(data.get("brief"), str):
        files.insert(1, data["brief"])
    for rel in files:
        path = _inside(sdir, rel)
        if path is None or not path.is_file():
            out.append(f"{rel}: missing file")


def _check_node(node, sdir, catalog_root, network_names, out):
    label = "scenario.yaml"
    name = node.get("name")
    p = f"nodes[{name}]"
    if name is not None and not (isinstance(name, str) and NAME_RE.match(name)):
        out.append(f"{label}: {p}.name: {name!r} is not a valid node name")
    ref = node.get("brick")
    if not isinstance(ref, dict) or "id" not in ref or "version" not in ref:
        return None
    brick, problem, missing = find_definition("brick", ref["id"], ref["version"],
                                              sdir, catalog_root)
    out.extend(missing)
    if problem:
        out.append(f"{label}: {p}.brick: {problem}")
    if brick is None:
        return None
    b = brick.data

    role = node.get("role")
    if role is not None and role not in (b.get("roles") or []):
        out.append(f"{label}: {p}.role: {role} is not one of the brick's roles "
                   f"({', '.join(map(str, b.get('roles') or []))})")
    policy = node.get("write_policy")
    if policy is not None:
        if policy not in WRITE_POLICIES:
            out.append(f"{label}: {p}.write_policy: {policy} is not one of "
                       f"{', '.join(WRITE_POLICIES)}")
        elif policy != "no-access" and policy not in (b.get("write_policies") or []):
            out.append(f"{label}: {p}.write_policy: {policy} is not supported by brick "
                       f"{brick.id} ({', '.join(b.get('write_policies') or [])})")
    if "write_overrides" in node:
        _check_write_overrides(node, brick, p, out)
    if "stateful" in node and node["stateful"] != b.get("stateful"):
        out.append(f"{label}: {p}.stateful: {node['stateful']} differs from the brick's "
                   f"{b.get('stateful')}")
    for net in node.get("networks") or []:
        if net not in network_names:
            out.append(f"{label}: {p}.networks: {net} is not a declared network")

    params = node.get("parameters") or {}
    brick_params = b.get("parameters") or {}
    if isinstance(params, dict):
        for pname, spec in brick_params.items():
            if isinstance(spec, dict) and spec.get("required") and pname not in params:
                out.append(f"{label}: {p}.parameters.{pname}: missing (required by brick "
                           f"{brick.id})")
        for pname, value in params.items():
            if pname not in brick_params:
                out.append(f"{label}: {p}.parameters.{pname}: not a parameter of brick "
                           f"{brick.id}")
                continue
            spec = brick_params[pname] if isinstance(brick_params[pname], dict) else {}
            shape = spec.get("shape")
            if shape is None and isinstance(value, (list, dict)):
                out.append(f"{label}: {p}.parameters.{pname}: a list or map, but brick "
                           f"{brick.id} declares it a scalar (no shape)")
            elif shape is not None and not isinstance(value, dict):
                out.append(f"{label}: {p}.parameters.{pname}: not a map (shape {shape} of "
                           f"brick {brick.id})")

    _check_resources(node.get("resources"), f"{p}.resources", out)

    ports = node.get("published_ports") or []
    if ports and "bastion" not in (b.get("roles") or []):
        out.append(f"{label}: {p}.published_ports: only the bastion publishes a port in v0.1")
    for i, port in enumerate(ports if isinstance(ports, list) else []):
        if not (isinstance(port, dict) and _is_port(port.get("port"))
                and _is_port(port.get("default"))):
            out.append(f"{label}: {p}.published_ports[{i}]: needs port and default, "
                       "both port numbers")

    seed_files = node.get("seed_files") or {}
    declared = list((b.get("seed") or {}).get("files") or [])
    if isinstance(seed_files, dict):
        for fname in declared:
            if fname not in seed_files and not is_seed_folder_entry(fname):
                out.append(f"{label}: {p}.seed_files: no entry for the brick's seed file "
                           f"{fname}")
        for fname, rel in seed_files.items():
            if fname not in declared:
                out.append(f"{label}: {p}.seed_files.{fname}: not a seed file of brick "
                           f"{brick.id}")
            if is_seed_folder_entry(fname):
                _check_seed_folder(sdir, rel, f"{p}.seed_files.{fname}", out)
                continue
            path = _inside(sdir, rel)
            if path is None or not path.is_file():
                out.append(f"{rel}: missing file ({p}.seed_files.{fname})")

    _check_knobs(node, brick, sdir, out)

    data_spec = node.get("data")
    if isinstance(data_spec, dict) and data_spec.get("file"):
        path = _inside(sdir, data_spec["file"])
        if path is None or not path.is_file():
            out.append(f"{data_spec['file']}: missing file ({p}.data.file)")
    return brick


def _is_port(value):
    return isinstance(value, int) and not isinstance(value, bool) and 0 < value < 65536


def is_seed_folder_entry(fname):
    """A brick's seed entry ending in / (builders/): a folder of files the
    scenario names, optional in its seed_files (capture W1 of v0.3, item 3)."""
    return isinstance(fname, str) and fname.endswith("/")


def _check_seed_folder(sdir, rel, p, out):
    path = _inside(sdir, rel)
    if path is None or not path.is_dir():
        out.append(f"{rel}: missing folder ({p})")
        return
    files = 0
    for entry in sorted(path.iterdir()):
        shown = f"{str(rel).rstrip('/')}/{entry.name}"
        if entry.is_dir():
            out.append(f"{shown}: a subfolder; a folder seed entry holds files only ({p})")
        elif not SEED_ENTRY_FILE_RE.match(entry.name):
            out.append(f"{shown}: not a seed file name ([A-Za-z0-9_][A-Za-z0-9_.-]*) ({p})")
        elif entry.is_file():
            files += 1
    if not files:
        out.append(f"{rel}: holds no file ({p})")


def _check_write_overrides(node, brick, p, out):
    """write_overrides (master spec 6.1; W1 items 1 and 3, D170): on a
    report-only node only, each entry one of the brick's writable_paths."""
    label = "scenario.yaml"
    overrides = node.get("write_overrides")
    policy = node.get("write_policy")
    if policy != "report-only":
        out.append(f"{label}: {p}.write_overrides: only a report-only node has overrides (its "
                   f"write_policy is {policy})")
    writable = [str(w) for w in brick.data.get("writable_paths") or []] \
        if isinstance(brick.data.get("writable_paths"), list) else []
    for path in overrides if isinstance(overrides, list) else []:
        if isinstance(path, str) and re.search(r"\s", path):
            out.append(f"{label}: {p}.write_overrides: {path!r} contains whitespace")
        elif path not in writable:
            out.append(f"{label}: {p}.write_overrides: {path} is not one of brick {brick.id}'s "
                       f"writable_paths ({', '.join(writable) or 'none'})")


def is_scheduler_node(node):
    return isinstance(node, dict) and _dict(node.get("brick")).get("id") == SCHEDULER_BRICK


def has_scheduler_nodes(data):
    """Whether the scenario has a scheduler node, and so ages (D157, D158)."""
    nodes = data.get("nodes")
    return any(is_scheduler_node(n) for n in nodes) if isinstance(nodes, list) else False


def _under(path, base):
    return path == base or path.startswith(base.rstrip("/") + "/")


def fixable_path(node, path):
    """Whether players may change `path` on the node: its policy is fixable,
    or the path is an override or lies under one (W1 item 3)."""
    if node.get("write_policy") == "fixable":
        return True
    overrides = node.get("write_overrides")
    return isinstance(path, str) and any(
        isinstance(o, str) and _under(path, o)
        for o in (overrides if isinstance(overrides, list) else []))


def fix_policy(node, brick_data, fault_data):
    """The write policy a fix of the fault meets on the node (master spec 6.1,
    D143): fixable when every file a seed-file fault changes lands, by the
    brick's seed.paths, on a fixable path; the node's own policy otherwise
    (a state or parameter fault keeps the node's)."""
    policy = node.get("write_policy")
    injection = _dict(fault_data.get("injection"))
    if policy == "fixable" or injection.get("kind") != "seed-file":
        return policy
    paths = _dict(_dict(brick_data.get("seed")).get("paths"))
    changes = injection.get("seed_changes")
    files = [c.get("file") for c in changes if isinstance(c, dict)] \
        if isinstance(changes, list) else []
    if files and all(fixable_path(node, paths.get(f)) for f in files):
        return "fixable"
    return policy


def _check_resources(resources, p, out, label="scenario.yaml"):
    if not isinstance(resources, dict):
        return
    for section, keys in (("limits", ("cpu", "memory")),
                          ("reservations", ("cpu", "memory", "disk"))):
        values = resources.get(section)
        if not isinstance(values, dict):
            continue
        for key in keys:
            if values.get(key) is None:
                continue
            try:
                (parse_cpu if key == "cpu" else parse_size)(values[key])
            except ValueError as exc:
                out.append(f"{label}: {p}.{section}.{key}: {exc}")


def _dict(value):
    return value if isinstance(value, dict) else {}


def _node_parameter(node, brick_data, pname):
    """A node's value for a brick parameter: as scenario.yaml states it, else
    the brick's default."""
    params = _dict(node.get("parameters"))
    if pname in params:
        return params[pname]
    return _dict(_dict(brick_data.get("parameters")).get(pname)).get("default")


def _shaped(brick_data, shape):
    return [name for name, spec in _dict(brick_data.get("parameters")).items()
            if _dict(spec).get("shape") == shape]


def _check_node_maps(nodes, bricks, out):
    """node-map parameters as scenario.yaml states them, before any parameter
    fault applies, and what each receiving node provides to the material
    mounted into it (capture W1, items 4 to 6; master spec 6.1, 7.1)."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    for node in nodes:
        name = node.get("name")
        brick = bricks.get(name)
        if brick is None:
            continue
        mounted = {item.get("parameter"): item for item in mounted_items(brick.data)}
        params = _dict(node.get("parameters"))
        for pname in _shaped(brick.data, "node-map"):
            p = f"nodes[{name}].parameters.{pname}"
            item = mounted.get(pname)
            if pname not in params:
                spec = _dict(brick.data["parameters"][pname])
                if item is not None and not spec.get("required"):
                    out.append(f"{label}: {p}: missing (brick {brick.id} mounts "
                               f"{item.get('name')} into the nodes it lists)")
                continue
            value = params[pname]
            if not isinstance(value, dict):
                continue                  # reported with the node's parameters
            if item is not None:
                for other in by_name:
                    if other not in value:
                        out.append(f"{label}: {p}: node {other} is missing (the map lists "
                                   "every node of the topology)")
            for key, entry in value.items():
                ep = f"{p}.{key}"
                if key not in by_name:
                    out.append(f"{label}: {ep}: not a node of the topology")
                    continue
                target = bricks.get(key)
                if entry != "default":
                    if not (isinstance(entry, list) and entry
                            and all(isinstance(s, str) for s in entry)):
                        out.append(f"{label}: {ep}: {entry!r} is not default or a non-empty "
                                   "list of the node's brick's processes")
                    elif target is not None:
                        processes = [str(s) for s in target.data.get("processes") or []]
                        for service in entry:
                            if service not in processes:
                                out.append(f"{label}: {ep}: {service} is not a process of "
                                           f"brick {target.id} ({', '.join(processes)})")
                if item is not None and target is not None:
                    _check_receiver(key, target, brick, item, out)


def _check_receiver(node_name, target, mounting, item, out):
    """The receiving node's `receives` against the requirements of the
    mounting brick, at its pinned version (capture W1, item 5)."""
    label = "scenario.yaml"
    p = f"nodes[{node_name}]"
    what = f"brick {mounting.id} {mounting.version}'s {item.get('name')}"
    receives = target.data.get("receives")
    if not isinstance(receives, dict):
        out.append(f"{label}: {p}: brick {target.id} {target.version} declares no receives, "
                   f"but {what} is mounted into it")
        return
    requires = _dict(item.get("requires"))
    need, have = requires.get("s6_overlay"), receives.get("s6_overlay")
    if isinstance(need, str) and need and not (
            isinstance(have, str) and (have == need or have.startswith(need + "."))):
        out.append(f"{label}: {p}: brick {target.id} {target.version} receives s6-overlay "
                   f"{have}, but {what} requires {need}")
    commands = receives.get("commands") if isinstance(receives.get("commands"), list) else []
    needed = requires.get("commands") if isinstance(requires.get("commands"), list) else []
    lacking = [c for c in needed if c not in commands]
    if lacking:
        out.append(f"{label}: {p}: brick {target.id} {target.version} lacks command(s) "
                   f"{', '.join(map(str, lacking))}, which {what} requires")


def _check_web_routes(nodes, bricks, out):
    """web-routes parameters against the topology's web interfaces, and the
    web front's published port (capture W1, item 3). Returns the route names."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    interfaces = {}                   # (node, port) -> provides entry with a web_path
    for node in nodes:
        brick = bricks.get(node.get("name"))
        provides = _dict((brick.data if brick else {}).get("interfaces")).get("provides")
        for iface in provides if isinstance(provides, list) else []:
            if isinstance(iface, dict) and "web_path" in iface and _is_port(iface.get("port")):
                interfaces[(node.get("name"), iface["port"])] = iface
    routed = {key: [] for key in interfaces}
    routes = set()
    for node in nodes:
        name = node.get("name")
        brick = bricks.get(name)
        if brick is None:
            continue
        for pname in _shaped(brick.data, "web-routes"):
            p = f"nodes[{name}].parameters.{pname}"
            value = _node_parameter(node, brick.data, pname)
            if not isinstance(value, dict):
                continue                  # reported with the node's parameters
            for route, target in value.items():
                rp = f"{p}.{route}"
                routes.add(route)
                if not (isinstance(route, str) and NAME_RE.match(route)):
                    out.append(f"{label}: {rp}: {route!r} is not a valid route name "
                               "(lowercase letters, digits and hyphens)")
                m = ROUTE_TARGET_RE.match(target) if isinstance(target, str) else None
                if m is None:
                    out.append(f'{label}: {rp}: {target!r} is not "<node>:<port>"')
                    continue
                tnode, port = m.group(1), int(m.group(3))
                if tnode not in by_name:
                    out.append(f"{label}: {rp}: {tnode} is not a node")
                    continue
                if bricks.get(tnode) is None:
                    continue
                iface = interfaces.get((tnode, port))
                if iface is None:
                    out.append(f"{label}: {rp}: brick {bricks[tnode].id} of node {tnode} "
                               f"provides no web interface on port {port}")
                    continue
                routed[(tnode, port)].append(str(route))
                if iface.get("web_path") != f"/{route}/":
                    out.append(f"{label}: {rp}: {tnode}:{port} is served under "
                               f"{iface.get('web_path')}, not /{route}/")
            ports = node.get("published_ports")
            ports = [x for x in ports if isinstance(x, dict)] if isinstance(ports, list) else []
            pp = f"nodes[{name}].published_ports"
            if value and not any(x.get("port") == WEB_FRONT_PORT
                                 and x.get("default") == WEB_FRONT_PORT for x in ports):
                out.append(f"{label}: {pp}: no {{port: {WEB_FRONT_PORT}, default: "
                           f"{WEB_FRONT_PORT}}}, which the web front needs ({pname} is "
                           "non-empty)")
            elif not value and any(x.get("port") == WEB_FRONT_PORT for x in ports):
                out.append(f"{label}: {pp}: port {WEB_FRONT_PORT} is published, but {pname} "
                           "is empty (the web front does not run)")
    for (tnode, port), names in routed.items():
        iface = interfaces[(tnode, port)]
        what = f"web interface {iface.get('name')} (port {port}, {iface.get('web_path')})"
        if not names:
            out.append(f"{label}: nodes[{tnode}]: {what} has no route in a web-routes "
                       "parameter")
        elif len(names) > 1:
            out.append(f"{label}: nodes[{tnode}]: {what} has {len(names)} routes "
                       f"({', '.join(sorted(names))}); one route per web interface")
    return routes


def _check_knobs(node, brick, sdir, out):
    label = "scenario.yaml"
    p = f"nodes[{node.get('name')}].knobs"
    knobs = node.get("knobs")
    if not isinstance(knobs, list):
        return
    brick_knobs = {k.get("setting"): k for k in brick.data.get("knobs") or []
                   if isinstance(k, dict)}
    seen = set()
    for knob in knobs:
        if not isinstance(knob, dict):
            continue
        setting = knob.get("setting")
        kp = f"{p}[{setting}]"
        if setting in seen:
            out.append(f"{label}: {kp}: duplicate entry")
        seen.add(setting)
        bknob = brick_knobs.get(setting)
        if bknob is None:
            out.append(f"{label}: {kp}: not a knob of brick {brick.id}")
            continue
        if "envelope" in knob:
            _check_envelope(knob["envelope"], bknob.get("envelope") or {},
                            f"{kp}.envelope", out)
        if "initial" in knob and knob["initial"] is not None:
            _check_initial(node, knob, bknob, sdir, kp, out)
    for setting in brick_knobs:
        if setting not in seen:
            out.append(f"{label}: {p}: no entry for the brick's knob {setting}")


def _bound(envelope, key):
    value = envelope.get(key)
    return None if value is None or value == "-" else value


def _check_envelope(env, benv, p, out):
    label = "scenario.yaml"
    if not isinstance(env, dict) or not env:
        out.append(f"{label}: {p}: empty (needs {{min, max}} or {{allowed: [..]}})")
        return
    if "allowed" in env:
        allowed = env["allowed"]
        if set(env) != {"allowed"} or not isinstance(allowed, list) or not allowed:
            out.append(f"{label}: {p}: an enum envelope is {{allowed: [..]}}, non-empty")
            return
        if "allowed" not in benv:
            out.append(f"{label}: {p}: an enum, where the brick's envelope is a range")
            return
        for value in allowed:
            if not any(pg_equal(value, b) for b in benv["allowed"]):
                out.append(f"{label}: {p}: allowed value {value} widens the brick's envelope")
        return
    if set(env) - {"min", "max"} or _bound(env, "min") is None and _bound(env, "max") is None:
        out.append(f"{label}: {p}: a range envelope is {{min, max}}")
        return
    if "allowed" in benv:
        out.append(f"{label}: {p}: a range, where the brick's envelope is an enum")
        return
    for key, wider in (("min", -1), ("max", 1)):
        theirs, ours = _bound(benv, key), _bound(env, key)
        if theirs is None:
            continue
        if ours is None:
            out.append(f"{label}: {p}: no {key} widens the brick's {key} {theirs}")
            continue
        try:
            if pg_compare(ours, theirs) == wider:
                out.append(f"{label}: {p}: {key} {ours} widens the brick's {key} {theirs}")
        except ValueError:
            out.append(f"{label}: {p}: {key} {ours} cannot be compared with the brick's "
                       f"{key} {theirs}")
    lo, hi = _bound(env, "min"), _bound(env, "max")
    if lo is not None and hi is not None:
        try:
            if pg_compare(lo, hi) > 0:
                out.append(f"{label}: {p}: min {lo} is above max {hi}")
        except ValueError:
            out.append(f"{label}: {p}: min {lo} and max {hi} cannot be compared")


def _check_initial(node, knob, bknob, sdir, kp, out):
    seed_name = Path(str(bknob.get("file", ""))).name
    rel = (node.get("seed_files") or {}).get(seed_name)
    path = _inside(sdir, rel) if rel else None
    if path is None or not path.is_file():
        return                       # reported with the seed files, or not a seeded file
    settings = read_conf_settings(path.read_text(encoding="utf-8"))
    setting = str(knob["setting"]).lower()
    initial = knob["initial"]
    if setting in settings:
        if not pg_equal(initial, settings[setting]):
            out.append(f"scenario.yaml: {kp}.initial: {initial} does not match the seed file "
                       f"{rel} ({settings[setting]})")
    elif not pg_equal(initial, bknob.get("default")):
        out.append(f"scenario.yaml: {kp}.initial: {initial}, but the seed file {rel} does not "
                   f"set it (its default is the brick's {bknob.get('default')})")


def _check_faults(data, nodes, bricks, sdir, catalog_root, out):
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    faults = {}
    ids = []
    for inst in data.get("fault_instances") or []:
        if not isinstance(inst, dict):
            continue
        iid = inst.get("id")
        p = f"fault_instances[{iid}]"
        if iid in ids:
            out.append(f"{label}: {p}: duplicate instance id")
        ids.append(iid)
        if inst.get("visibility") not in (None, "known", "hidden"):
            out.append(f"{label}: {p}.visibility: {inst['visibility']} is not known or hidden")
        ref = inst.get("fault")
        if not isinstance(ref, dict) or "id" not in ref or "version" not in ref:
            continue
        fault, problem, missing = find_definition("fault", ref["id"], ref["version"],
                                                  sdir, catalog_root)
        out.extend(m for m in missing if m not in out)
        if problem:
            out.append(f"{label}: {p}.fault: {problem}")
        if fault is None:
            continue
        faults[iid] = fault
        target = inst.get("node")
        if target is not None and target not in by_name:
            out.append(f"{label}: {p}.node: {target} is not a node")
        brick = bricks.get(target)
        if brick is not None:
            applies = (fault.data.get("applies_to") or {}).get("bricks") or []
            if not any(isinstance(a, dict) and a.get("id") == brick.id
                       and brick.version in [str(v) for v in a.get("versions") or []]
                       for a in applies):
                out.append(f"{label}: {p}.node: {target} runs {brick.id} {brick.version}, "
                           f"which fault {fault.id} does not apply to")
            injection = fault.data.get("injection") or {}
            seeds = (brick.data.get("seed") or {}).get("files") or []
            for change in injection.get("seed_changes") or []:
                if isinstance(change, dict) and change.get("file") not in seeds:
                    out.append(f"{label}: {p}: fault {fault.id} changes {change.get('file')}, "
                               f"not a seed file of brick {brick.id}")
            _check_parameter_fault(inst, fault, brick, by_name, p, out)
            _check_report_evidence(fault, brick, p, out)
        params = inst.get("parameters") or {}
        fparams = fault.data.get("parameters") or {}
        if isinstance(params, dict):
            for pname, spec in fparams.items():
                if isinstance(spec, dict) and spec.get("required") and pname not in params:
                    out.append(f"{label}: {p}.parameters.{pname}: missing (required by fault "
                               f"{fault.id})")
            for pname, value in params.items():
                if pname not in fparams:
                    out.append(f"{label}: {p}.parameters.{pname}: not a parameter of fault "
                               f"{fault.id}")
                _check_param_value(value, f"{p}.parameters.{pname}", label, out)
    return faults


def _check_report_evidence(fault, brick, p, out):
    """A fault's report:<tool> evidence names a tool its target node's brick
    ships, at its pinned version (master spec 6.3, D145; W1 item 2)."""
    tools = brick.data.get("report_tools")
    tools = [str(t) for t in tools] if isinstance(tools, list) else []
    evidence = fault.data.get("evidence")
    for i, item in enumerate(evidence if isinstance(evidence, list) else []):
        where = _dict(item).get("where")
        kind, _, tool = where.partition(":") if isinstance(where, str) else ("", "", "")
        if kind == "report" and REPORT_TOOL_RE.match(tool) and tool not in tools:
            out.append(f"scenario.yaml: {p}: fault {fault.id}'s evidence[{i}] reads {where}, but "
                       f"brick {brick.id} {brick.version} ships no {tool} (report_tools: "
                       f"{', '.join(tools) or 'none'})")


def _check_parameter_fault(inst, fault, brick, by_name, p, out):
    """A parameter fault against its target node's brick, as seed changes are
    checked, and a fault about mounted material (capture W1, item 8; master
    spec 6.4)."""
    label = "scenario.yaml"
    injection = _dict(fault.data.get("injection"))
    changes = injection.get("parameter_changes")
    if injection.get("kind") != "parameter" or not isinstance(changes, list):
        return
    changes = [c for c in changes if isinstance(c, dict)]
    bparams = _dict(brick.data.get("parameters"))
    for change in changes:
        pname, op = change.get("parameter"), change.get("op")
        if pname not in bparams:
            out.append(f"{label}: {p}: fault {fault.id} changes parameter {pname}, not a "
                       f"parameter of brick {brick.id}")
            continue
        shape = _dict(bparams[pname]).get("shape")
        if op == "set" and shape is not None:
            out.append(f"{label}: {p}: fault {fault.id} sets {pname}, a {shape} parameter of "
                       f"brick {brick.id} (set takes a scalar parameter)")
        elif op == "remove-entry" and shape is None:
            out.append(f"{label}: {p}: fault {fault.id} removes an entry of {pname}, a scalar "
                       f"parameter of brick {brick.id}")
        elif op == "remove-from-entry" and shape != "node-map":
            out.append(f"{label}: {p}: fault {fault.id} removes an item from an entry of "
                       f"{pname}, not a node-map parameter of brick {brick.id}")
    mounted = {item.get("parameter") for item in mounted_items(brick.data)}
    if not any(c.get("parameter") in mounted for c in changes):
        return
    applies = _dict(fault.data.get("applies_to")).get("bricks")
    ids = [str(_dict(a).get("id")) for a in applies] if isinstance(applies, list) else []
    if ids != [brick.id]:
        out.append(f"{label}: {p}: fault {fault.id} is about material brick {brick.id} mounts, "
                   f"so its applies_to names only {brick.id} (it names {', '.join(ids)})")
    spec = _dict(fault.data.get("parameters")).get("node")
    if not (isinstance(spec, dict) and spec.get("required")):
        out.append(f"{label}: {p}: fault {fault.id} is about mounted material, so it needs a "
                   "required parameter node, the affected node")
    node = _dict(inst.get("parameters")).get("node", _dict(spec).get("default"))
    if node is not None and node not in by_name:
        out.append(f"{label}: {p}.parameters.node: {node} is not a node of the topology")


def _check_issues(data, nodes, bricks, faults, expectations, out):
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    instances = {i.get("id"): i for i in data.get("fault_instances") or []
                 if isinstance(i, dict)}
    covered = set()
    for issue in data.get("issues") or []:
        if not isinstance(issue, dict):
            continue
        p = f"issues[{issue.get('id')}]"
        expected = issue.get("expected_resolution")
        if expected is not None and expected not in RESOLUTION_KINDS:
            out.append(f"{label}: {p}.expected_resolution: {expected} is not one of "
                       f"{', '.join(RESOLUTION_KINDS)}")
        covers = issue.get("covers") if isinstance(issue.get("covers"), list) else []
        if covers and all(iid in expectations for iid in covers) \
                and expected in RESOLUTION_KINDS and expected not in EXPECTATION_RESOLUTIONS:
            out.append(f"{label}: {p}.expected_resolution: {expected}, but the issue covers "
                       f"only tooling expectations ({' or '.join(EXPECTATION_RESOLUTIONS)})")
        for iid in covers:
            covered.add(iid)
            if iid in expectations:
                continue
            if iid not in instances:
                out.append(f"{label}: {p}.covers: {iid} is not a fault instance or a tooling "
                           "expectation")
                continue
            fault = faults.get(iid)
            node = by_name.get(instances[iid].get("node")) or {}
            if fault is None or expected not in RESOLUTION_KINDS:
                continue
            policies = [r.get("write_policies") or [] for r in fault.data.get("resolutions") or []
                        if isinstance(r, dict) and r.get("kind") == expected]
            policy = node.get("write_policy")
            brick = bricks.get(node.get("name"))
            if expected == "fix" and brick is not None:
                policy = fix_policy(node, brick.data, fault.data)
            if not policies:
                out.append(f"{label}: {p}.expected_resolution: {expected} is not a resolution "
                           f"fault {fault.id} lists ({iid})")
            elif not any(policy in pol for pol in policies):
                where = ""
                if expected == "fix" and policy != "fixable" and \
                        _dict(fault.data.get("injection")).get("kind") == "seed-file":
                    where = (" for the file(s) the fault changes (no write_overrides entry "
                             "makes them fixable)")
                out.append(f"{label}: {p}.expected_resolution: {expected} is not possible "
                           f"under node {node.get('name')}'s write policy "
                           f"{policy}{where} ({iid})")
    for iid, inst in instances.items():
        visibility = inst.get("visibility")
        if visibility == "known" and iid not in covered:
            out.append(f"{label}: fault_instances[{iid}].visibility: known, but no issue "
                       "covers it")
        elif visibility == "hidden" and iid in covered:
            out.append(f"{label}: fault_instances[{iid}].visibility: hidden, but an issue "
                       "covers it")


def _check_answer_key(data, nodes, bricks, faults, routes, sdir, out):
    label = "gm/answer-key.yaml"
    if not (sdir / label).is_file():
        return None                  # listed with the missing files
    key = _load_yaml(sdir / label, label, out)
    if key is None:
        return None
    check_against_schema(key, template_schema("answer-key.yaml"), label, out=out)
    placeholders(key, label, out=out)
    if not isinstance(key, dict):
        return None
    meta = key.get("scenario") or {}
    for field_name in ("id", "version"):
        if field_name in meta and str(meta[field_name]) != str(data.get(field_name)):
            out.append(f"{label}: scenario.{field_name}: {meta[field_name]} differs from "
                       f"scenario.yaml's {data.get(field_name)}")
    notes = key.get("notes")
    if isinstance(notes, str):
        path = _inside(sdir, notes)
        if path is None or not path.is_file():
            out.append(f"{notes}: missing file ({label} notes)")
    instances = {i.get("id"): i for i in data.get("fault_instances") or []
                 if isinstance(i, dict)}
    by_name = {n.get("name"): n for n in nodes}
    entries = [e for e in key.get("instances") or [] if isinstance(e, dict)]
    seen = [e.get("instance") for e in entries]
    for iid in instances:
        if seen.count(iid) == 0:
            out.append(f"{label}: instances: no entry for fault instance {iid}")
        elif seen.count(iid) > 1:
            out.append(f"{label}: instances[{iid}]: more than one entry")
    for iid in seen:
        if iid not in instances:
            out.append(f"{label}: instances[{iid}]: not a fault instance of scenario.yaml")
    for entry in entries:
        iid = entry.get("instance")
        fault = faults.get(iid)
        if fault is None:
            continue
        expected = {i.get("expected_resolution") for i in data.get("issues") or []
                    if isinstance(i, dict) and iid in (i.get("covers") or [])}
        kinds = _resolution_kinds(fault.data)
        node = by_name.get(instances[iid].get("node")) or {}
        fixable = node.get("write_policy") == "fixable"
        brick = bricks.get(node.get("name"))
        file_fixable = fixable or (brick is not None
                                   and fix_policy(node, brick.data, fault.data) == "fixable")
        acceptable = entry.get("acceptable") or {}
        needs = {"proposal": "propose" in expected or "propose" in kinds,
                 "fix": "fix" in expected or ("fix" in kinds and file_fixable),
                 "improvement": "improve" in expected or ("improve" in kinds and fixable)}
        for name, needed in needs.items():
            if needed and not acceptable.get(name):
                out.append(f"{label}: instances[{iid}].acceptable.{name}: missing")
        _check_behavioural(entry, fault, label, out)
    for entry in entries:
        evidence = entry.get("evidence")
        for i, item in enumerate(evidence if isinstance(evidence, list) else []):
            if isinstance(item, dict) and "where" in item:
                _check_where(item["where"], nodes, routes,
                             f"instances[{entry.get('instance')}].evidence[{i}].where", out)
    _check_expectations(key.get("tooling_expectations"), instances, out)
    return key


def _check_behavioural(entry, fault, label, out):
    """A behavioural check's window and threshold (master spec 6.2, 11; W1
    item 4): present exactly when the fault's sealed_check.behavioural is
    true; the window a duration, the threshold a number."""
    p = f"{label}: instances[{entry.get('instance')}].sealed_check"
    sealed = _dict(entry.get("sealed_check"))
    behavioural = is_behavioural(fault.data)
    for key in ("window", "threshold"):
        if behavioural and key not in sealed:
            out.append(f"{p}.{key}: missing (fault {fault.id}'s sealed check is behavioural)")
        elif not behavioural and key in sealed:
            out.append(f"{p}.{key}: fault {fault.id}'s sealed check is not behavioural (no "
                       "sealed_check.behavioural: true), so it takes no window or threshold")
    if "window" in sealed:
        try:
            parse_duration(sealed["window"])
        except ValueError as exc:
            out.append(f"{p}.window: {exc}")
    if "threshold" in sealed and not _is_number(sealed["threshold"]):
        out.append(f"{p}.threshold: {sealed['threshold']!r} is not a number")


def _check_where(where, nodes, routes, p, out):
    """Where answer-key evidence is run (capture W1, item 9; spec D101)."""
    label = "gm/answer-key.yaml"
    names = {n.get("name") for n in nodes}
    bastions = {n.get("name") for n in nodes if n.get("role") == "bastion"}
    kind, _, name = where.partition(":") if isinstance(where, str) else (None, "", "")
    if where == "bastion":
        return
    if kind == "node" and name:
        if name in bastions:
            out.append(f"{label}: {p}: {where} is the bastion; write bastion")
        elif name not in names:
            out.append(f"{label}: {p}: {where}: {name} is not a node of the topology")
    elif kind == "ui" and name:
        if name not in routes:
            out.append(f"{label}: {p}: {where}: {name} is not a route of the topology's "
                       "web-routes parameter")
    elif kind == "report" and name:
        if not REPORT_TOOL_RE.match(name):
            out.append(f"{label}: {p}: {where}: the tool is written in lowercase "
                       "(report:pgbadger)")
    else:
        out.append(f"{label}: {p}: {where!r} is not bastion, node:<name>, ui:<name> or "
                   "report:<tool>")


def _check_expectations(expectations, instances, out):
    """Tooling expectations (capture W1, item 10): ids unique across fault
    instance ids and expectation ids; no visibility, no sealed check."""
    label = "gm/answer-key.yaml"
    seen = set()
    for item in expectations if isinstance(expectations, list) else []:
        if not isinstance(item, dict):
            continue
        tid = item.get("id")
        p = f"tooling_expectations[{tid}]"
        if tid in instances:
            out.append(f"{label}: {p}.id: {tid} is also a fault instance id")
        elif tid in seen:
            out.append(f"{label}: {p}.id: duplicate expectation id")
        seen.add(tid)
        for key in ("visibility", "sealed_check"):
            if key in item:
                out.append(f"{label}: {p}.{key}: a tooling expectation has no "
                           f"{key.replace('_', ' ')}")


def expectation_ids(answer_key):
    """The ids of an answer key's tooling expectations."""
    items = _dict(answer_key).get("tooling_expectations")
    return {i.get("id") for i in items if isinstance(i, dict)} \
        if isinstance(items, list) else set()


def _check_aging(data, nodes, out):
    """`aging:` (master spec 6.1, 8; D150, D157, D158): required with a
    scheduler node, refused without one. Returns aging.minimum in seconds,
    or None when absent or not a duration."""
    label = "scenario.yaml"
    scheduler = [str(n.get("name")) for n in nodes if is_scheduler_node(n)]
    if not scheduler:
        if "aging" in data:
            out.append(f"{label}: aging: a scenario with no scheduler node does not age, so it "
                       "has no aging: (master spec 6.1, D157, D158)")
        return None
    if "aging" not in data:
        out.append(f"{label}: aging: missing (required with scheduler node(s) "
                   f"{', '.join(scheduler)}; master spec 6.1, D157)")
        return None
    aging = _dict(data.get("aging"))
    minimum = None
    if "minimum" in aging:
        try:
            minimum = parse_duration(aging["minimum"])
        except ValueError as exc:
            out.append(f"{label}: aging.minimum: {exc}")
        else:
            if minimum < MIN_AGING_SECONDS:
                out.append(f"{label}: aging.minimum: {aging['minimum']} is less than 8h (master "
                           "spec 6.1, D150)")
    at = aging.get("handover_at")
    if "handover_at" in aging and not (isinstance(at, str) and HANDOVER_AT_RE.match(at)):
        hint = " (unquoted, YAML reads HH:MM as a number)" if _is_int(at) else ""
        out.append(f'{label}: aging.handover_at: {at!r} is not a quoted "HH:00", 24-hour, '
                   f"minutes 00{hint}")
    return minimum


def _check_difficulty(data, out):
    """`difficulty:` (master spec 6.1, 15.1): the score equals the number of
    fault instances; the level, when given, is easy, normal or hard."""
    label = "scenario.yaml"
    difficulty = data.get("difficulty")
    if not isinstance(difficulty, dict):
        return                           # reported against the template
    instances = data.get("fault_instances")
    count = len(instances) if isinstance(instances, list) else 0
    score = difficulty.get("score")
    if "score" in difficulty and score is not None:
        if not _is_int(score):
            out.append(f"{label}: difficulty.score: {score!r} is not an integer")
        elif score != count:
            out.append(f"{label}: difficulty.score: {score}, but the scenario has {count} fault "
                       "instance(s), each worth 1")
    if "level" in difficulty and difficulty["level"] not in DIFFICULTY_LEVELS:
        out.append(f"{label}: difficulty.level: {difficulty['level']} is not one of "
                   f"{', '.join(DIFFICULTY_LEVELS)}")


def _check_planting(data, faults, scheduled, minimum, out):
    """Each fault instance's planting moment and aging minimum (master spec
    6.1; W1 item 1; D158, D160). Without scheduler nodes every instance is
    planted at T0 and the definitions' minima are not counted."""
    label = "scenario.yaml"
    for inst in data.get("fault_instances") or []:
        if not isinstance(inst, dict):
            continue
        iid = inst.get("id")
        p = f"{label}: fault_instances[{iid}]"
        fault = faults.get(iid)
        hours = None
        if "plant_at" in inst:
            plant_at = inst["plant_at"]
            m = HANDOVER_MOMENT_RE.match(plant_at) if isinstance(plant_at, str) else None
            if m is not None:
                hours = int(m.group(1))
            elif plant_at != "T0":
                out.append(f"{p}.plant_at: {plant_at!r} is not T0 or handover-<N>h (N a whole "
                           "number of hours, at least 1: never at or after hand-over)")
        if not scheduled:
            if hours is not None:
                out.append(f"{p}.plant_at: {inst['plant_at']}, but a scenario with no scheduler "
                           "node plants every fault at T0 (D158)")
            if "aging_minimum" in inst:
                out.append(f"{p}.aging_minimum: a scenario with no scheduler node does not age, "
                           "so an instance has no aging minimum (D158)")
            continue
        own = fault_aging_minimum(fault.data) if fault is not None else None
        if "aging_minimum" in inst:
            try:
                raised = parse_duration(inst["aging_minimum"])
            except ValueError as exc:
                out.append(f"{p}.aging_minimum: {exc}")
                own = None
            else:
                if own is not None and raised < own:
                    out.append(f"{p}.aging_minimum: {inst['aging_minimum']} is less than fault "
                               f"{fault.id}'s aging.minimum {fault.data['aging']['minimum']}")
                own = raised
        if hours is not None:
            kind = _dict(fault.data.get("injection")).get("kind") if fault is not None else None
            if fault is not None and kind != "state":
                out.append(f"{p}.plant_at: {inst['plant_at']}, but fault {fault.id} is a {kind} "
                           "fault, planted at render: only a state fault is planted after T0 "
                           "(master spec 6.1)")
            if minimum is not None and hours * 3600 > minimum:
                out.append(f"{p}.plant_at: {inst['plant_at']} is further before hand-over than "
                           f"aging.minimum {data['aging']['minimum']}")
            if own is not None and own > hours * 3600:
                out.append(f"{p}.plant_at: {inst['plant_at']} leaves less than the instance's own "
                           f"aging minimum {_own_minimum_text(inst, fault)} before hand-over")
        elif minimum is not None and own is not None and own > minimum:
            out.append(f"{p}: aging.minimum {data['aging']['minimum']} does not cover it: planted "
                       f"at T0, its own aging minimum is {_own_minimum_text(inst, fault)}")


def _own_minimum_text(inst, fault):
    if "aging_minimum" in inst:
        return str(inst["aging_minimum"])
    return str(_dict(fault.data.get("aging")).get("minimum"))


def _seed_path(node, sdir, fname):
    """The scenario file a node's seed_files maps `fname` to, when it exists."""
    rel = _dict(node.get("seed_files")).get(fname)
    path = _inside(sdir, rel) if isinstance(rel, str) else None
    return (rel, path) if path is not None and path.is_file() else (rel, None)


def _check_customer_timezone(nodes, scheduled, sdir, out):
    """{{customer_timezone}} in the bastion's seed files (the starter pack,
    the story included): refused with no scheduler node (master spec 6.1,
    D158; W1 item 1)."""
    if scheduled:
        return
    for node in nodes:
        if node.get("role") != "bastion":
            continue
        for fname in _dict(node.get("seed_files")):
            rel, path = _seed_path(node, sdir, fname)
            if path is None:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            if CUSTOMER_TIMEZONE in text:
                out.append(f"{rel}: {CUSTOMER_TIMEZONE}: a scenario with no scheduler node has "
                           "no customer's time zone; its times stay UTC (master spec 6.1, D158)")


def _check_retention(data, nodes, bricks, faults, scheduled, minimum, sdir, out):
    """A prometheus node's retention by time covers aging.minimum plus four
    hours (four hours with no aging), unless a fault planted on it is about
    retention (master spec 6.1; W1 item 2, family: retention)."""
    if scheduled and minimum is None:
        return                           # aging reported missing or wrong
    need = (minimum or 0) + RETENTION_MARGIN_SECONDS
    what = (f"aging.minimum {data['aging']['minimum']} plus 4h" if scheduled
            else "4h (the game, with no aging)")
    for node in nodes:
        brick = bricks.get(node.get("name"))
        if brick is None or brick.id != "prometheus":
            continue
        about_retention = any(
            isinstance(i, dict) and i.get("node") == node.get("name") and i.get("id") in faults
            and faults[i.get("id")].data.get("family") == RETENTION_FAMILY
            for i in data.get("fault_instances") or [])
        rel, path = _seed_path(node, sdir, "prometheus.yml")
        if path is None or about_retention:
            continue
        conf = _load_yaml(path, rel, out)
        retention = _dict(_dict(_dict(_dict(conf).get("storage")).get("tsdb")).get("retention"))
        p = f"{rel}: storage.tsdb.retention.time"
        if "time" not in retention:
            out.append(f"{p}: missing (node {node.get('name')}'s retention by time covers {what}; "
                       "master spec 6.1)")
            continue
        try:
            seconds = parse_prometheus_duration(retention["time"])
        except ValueError as exc:
            out.append(f"{p}: {exc}")
            continue
        if seconds < need:
            out.append(f"{p}: {retention['time']} is less than {what} (node {node.get('name')}; "
                       "master spec 6.1), and no fault planted there is about retention")


def _hba_lines(text):
    """(line number, fields) of each pg_hba.conf rule."""
    for number, line in enumerate(text.splitlines(), 1):
        fields = line.split("#", 1)[0].split()
        if fields:
            yield number, fields


def _check_postgres_seeds(nodes, bricks, sdir, out):
    """A postgres node's seed (master spec 7.3; W1 item 8; D164, D171): a
    local replication connection for postgres by peer or trust (the
    hand-over snapshot's pg_basebackup), replication left on in the
    settings, and a local line admitting gm_check by password or trust
    before any line refusing it."""
    for node in nodes:
        brick = bricks.get(node.get("name"))
        if brick is None or brick.id != "postgres":
            continue
        rel, path = _seed_path(node, sdir, "pg_hba.conf")
        if path is not None:
            _check_hba(rel, list(_hba_lines(path.read_text(encoding="utf-8"))), out)
        rel, path = _seed_path(node, sdir, "postgresql.conf")
        if path is not None:
            settings = read_conf_settings(path.read_text(encoding="utf-8"))
            senders = settings.get("max_wal_senders")
            if senders is not None and pg_value(senders) == ("num", 0.0):
                out.append(f"{rel}: max_wal_senders: 0 refuses the hand-over snapshot's "
                           "pg_basebackup (master spec 7.3)")
            level = settings.get("wal_level")
            if level is not None and pg_value(level) == ("text", "minimal"):
                out.append(f"{rel}: wal_level: minimal refuses the hand-over snapshot's "
                           "pg_basebackup (master spec 7.3)")


def _check_hba(rel, lines, out):
    local = [(n, f) for n, f in lines if f[0] == "local" and len(f) >= 4]
    replication = next(((n, f) for n, f in local if "replication" in f[1].split(",")
                        and {"postgres", "all"} & set(f[2].split(","))), None)
    if replication is None:
        out.append(f"{rel}: no local line allows a replication connection for postgres (local "
                   "replication postgres peer, under the DO NOT TAMPER comment; master spec "
                   "7.3, D164)")
    elif replication[1][3] not in HBA_REPLICATION_METHODS:
        n, f = replication
        out.append(f"{rel}: line {n}: {' '.join(f)}: the hand-over snapshot's pg_basebackup "
                   "connects as postgres over the local socket by peer or trust (master spec "
                   "7.3, D164)")
    for n, f in local:
        databases, users, method = f[1].split(","), f[2].split(","), f[3]
        if databases == ["replication"] or not {"gm_check", "all"} & set(users):
            continue
        if method not in HBA_PASSWORD_METHODS:
            out.append(f"{rel}: line {n}: {' '.join(f)}: comes before any local line admitting "
                       "gm_check by password or trust (local all gm_check scram-sha-256, under "
                       "the DO NOT TAMPER comment; D164, D171)")
            return
        if "all" in databases:
            return
    out.append(f"{rel}: no local line admits gm_check by password or trust (local all gm_check "
               "scram-sha-256, under the DO NOT TAMPER comment; D164, D171)")


def _check_designed_for(data, nodes, out):
    label = "scenario.yaml"
    designed = data.get("designed_for")
    if not isinstance(designed, dict):
        return
    if designed.get("platform") not in (None, "swarm"):
        out.append(f"{label}: designed_for.platform: {designed['platform']} (v0.1: swarm)")
    hosts = {h.get("name"): h for h in designed.get("hosts") or [] if isinstance(h, dict)}
    placement = designed.get("placement") or {}
    if not isinstance(placement, dict):
        return
    for node in nodes:
        name = node.get("name")
        if name not in placement:
            out.append(f"{label}: designed_for.placement: node {name} is not placed")
        elif placement[name] not in hosts:
            out.append(f"{label}: designed_for.placement.{name}: {placement[name]} is not a "
                       "declared host")
    for name in placement:
        if name not in {n.get("name") for n in nodes}:
            out.append(f"{label}: designed_for.placement.{name}: not a node")
    for host_name, host in hosts.items():
        placed = [n for n in nodes if placement.get(n.get("name")) == host_name]
        for key in ("cpu", "memory", "disk"):
            try:
                parse = parse_cpu if key == "cpu" else parse_size
                capacity = parse(host.get(key))
                total = sum(parse(((n.get("resources") or {}).get("reservations") or {})
                                  .get(key)) for n in placed)
            except (ValueError, TypeError):
                continue                 # reported with the resources or the host
            if total > capacity:
                out.append(f"{label}: designed_for.hosts[{host_name}].{key}: the nodes placed "
                           "there reserve more than it has")


# --- The scheduler's files (master spec 7.1; capture W1 of v0.3, item 7) ---

SCHEDULER_FILES = ("queries.yaml", "schedule.yaml", "jobs.yaml")
QUERY_KEY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
ISOLATION_LEVELS = ("read committed", "repeatable read", "serializable")
GENERATORS = ("int", "decimal", "choice", "sequence", "now")
DRIVERS = ("sql/postgresql",)
TARGET_RE = re.compile(r"^([a-z]([a-z0-9-]{0,61}[a-z0-9])?):([0-9]+)/([A-Za-z_][A-Za-z0-9_$-]*)$")
DB_ROLE_RE = re.compile(r"^[a-z_][a-z0-9_]{0,40}$")
RESERVED_DB_ROLES = ("postgres", "dba", "monitoring", "gm_check", "pgbouncer_lookup")
RATE_RE = re.compile(r"^([0-9]+(?:\.[0-9]+)?)/(s|min|h)$")
ARRIVALS = ("poisson", "even")
BUILDER_RE = re.compile(r"^builders/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
HOURS_RE = re.compile(r"^([0-9]{2})(?:-([0-9]{2}))?$")
DAYS_RE = re.compile(r"^([a-z]{3})(?:-([a-z]{3}))?$")
SCHEDULE_KEYS = ("intensity", "connections", "streams", "shapes", "timeline")
CONNECTION_KEYS = ("driver", "target", "role", "pool")
STREAM_KEYS = ("key", "connection", "rate", "arrivals", "shape", "concurrency")
CHANGE_KEYS = ("at", "stream", "set")
SET_KEYS = ("key", "rate", "connection")
JOB_KEYS = ("name", "key", "connection", "at", "timezone_offset")


def _check_scheduler_files(data, nodes, faults, minimum, sdir, out):
    """A scheduler node's queries.yaml, builders/, schedule.yaml and
    jobs.yaml, in scenario time (master spec 7.1, normative; W1 item 7;
    D168); their templates are the format skill's."""
    names = {n.get("name") for n in nodes}
    for node in nodes:
        if not is_scheduler_node(node):
            continue
        loaded = {}
        for fname in SCHEDULER_FILES:
            rel, path = _seed_path(node, sdir, fname)
            if path is not None:            # a missing file is reported with the seed files
                loaded[fname] = (rel, _load_yaml(path, rel, out))
        builders = _dict(node.get("seed_files")).get("builders/")
        folder = _inside(sdir, builders) if isinstance(builders, str) else None
        builders = (str(builders).rstrip("/"), folder) if folder is not None and folder.is_dir() \
            else None
        keys = None
        if loaded.get("queries.yaml", (None, None))[1] is not None:
            keys = _check_queries(*loaded["queries.yaml"], builders, out)
        connections = None
        if loaded.get("schedule.yaml", (None, None))[1] is not None:
            connections = _check_schedule(*loaded["schedule.yaml"], keys, names, data, minimum,
                                          out)
        if loaded.get("jobs.yaml", (None, None))[1] is not None:
            _check_jobs(*loaded["jobs.yaml"], keys, connections, node, data, faults, out)


def _unknown_keys(value, allowed, p, what, out):
    for key in value:
        if key not in allowed:
            out.append(f"{p}.{key}: not a key of {what} ({', '.join(allowed)})")


def _without_sql(value):
    """A copy without `sql` values, whose < and > are operators, not
    placeholders."""
    if isinstance(value, dict):
        return {k: _without_sql(v) for k, v in value.items() if k != "sql"}
    if isinstance(value, list):
        return [_without_sql(v) for v in value]
    return value


def _check_queries(rel, content, builders, out):
    """The query repository; returns its keys, or None when unusable."""
    check_against_schema(content, template_schema("queries.yaml"), rel, out=out)
    placeholders(_without_sql(content), rel, out=out)
    queries = _dict(content).get("queries")
    if not isinstance(queries, dict):
        if isinstance(content, dict) and queries is not None:
            out.append(f"{rel}: queries: not a map of key -> query, pool, sequence or builder")
        return None
    for key, value in queries.items():
        p = f"{rel}: queries.{key}"
        if not (isinstance(key, str) and QUERY_KEY_RE.match(key)):
            out.append(f"{p}: {key!r} is not a key ([a-z0-9][a-z0-9._-]*)")
        if isinstance(value, list):
            if not value:
                out.append(f"{p}: a pool lists at least one query")
            for i, item in enumerate(value):
                _check_query(item, f"{p}[{i}]", ("sql", "params", "transaction", "weight"), out)
        elif isinstance(value, dict) and "builder" in value:
            _check_builder(value, p, builders, out)
        elif isinstance(value, dict) and "steps" in value:
            _unknown_keys(value, ("steps", "transaction"), p, "a sequence", out)
            steps = value["steps"]
            if not (isinstance(steps, list) and steps):
                out.append(f"{p}.steps: not a non-empty list of steps")
            for i, step in enumerate(steps if isinstance(steps, list) else []):
                _check_query(step, f"{p}.steps[{i}]", ("sql", "params"), out)
            if "transaction" in value:
                _check_transaction(value["transaction"], f"{p}.transaction", out)
        elif isinstance(value, dict) and "sql" in value:
            _check_query(value, p, ("sql", "params", "transaction"), out)
        else:
            out.append(f"{p}: not a query (sql), a pool (a list of queries), a sequence (steps) "
                       "or a builder (builder)")
    return set(queries)


def _check_query(query, p, allowed, out):
    if not isinstance(query, dict):
        out.append(f"{p}: not a query (sql, optional params)")
        return
    what = "a pool's query" if "weight" in allowed else \
        "a step" if "transaction" not in allowed else "a query"
    _unknown_keys(query, allowed, p, what, out)
    sql = query.get("sql")
    if "sql" not in query:
        out.append(f"{p}.sql: missing")
    elif not (isinstance(sql, str) and sql.strip()):
        out.append(f"{p}.sql: not a statement")
    if "params" in query:
        params = query["params"]
        if not isinstance(params, dict):
            out.append(f"{p}.params: not a map of name -> generator")
        for name, generator in params.items() if isinstance(params, dict) else ():
            _check_generator(generator, f"{p}.params.{name}", out)
    if "transaction" in query and "transaction" in allowed:
        _check_transaction(query["transaction"], f"{p}.transaction", out)
    if "weight" in query and not (_is_int(query["weight"]) and query["weight"] > 0):
        out.append(f"{p}.weight: {query['weight']!r} is not a positive integer")


def _check_generator(generator, p, out):
    """{int: [lo, hi]}, {decimal: [lo, hi, places]}, {choice: [..]},
    {sequence: [start, step]}, {now: utc} (W1 item 7)."""
    if not (isinstance(generator, dict) and len(generator) == 1
            and next(iter(generator)) in GENERATORS):
        out.append(f"{p}: {generator!r} is not a generator ({{int: [lo, hi]}}, {{decimal: [lo, "
                   "hi, places]}}, {choice: [..]}, {sequence: [start, step]}, {now: utc})")
        return
    kind, args = next(iter(generator.items()))
    ok = True
    if kind == "int":
        ok = isinstance(args, list) and len(args) == 2 and all(map(_is_int, args)) \
            and args[0] <= args[1]
        form = "[lo, hi], integers, lo <= hi"
    elif kind == "decimal":
        ok = isinstance(args, list) and len(args) == 3 and all(map(_is_number, args[:2])) \
            and args[0] <= args[1] and _is_int(args[2]) and args[2] >= 0
        form = "[lo, hi, places], lo <= hi, places a whole number of digits"
    elif kind == "choice":
        ok = isinstance(args, list) and bool(args) \
            and not any(isinstance(a, (list, dict)) for a in args)
        form = "a non-empty list of values"
    elif kind == "sequence":
        ok = isinstance(args, list) and len(args) == 2 and all(map(_is_int, args)) \
            and args[1] != 0
        form = "[start, step], integers, step not 0"
    else:
        ok = args == "utc"
        form = "utc"
    if not ok:
        out.append(f"{p}.{kind}: {args!r} is not {form}")


def _check_transaction(transaction, p, out):
    if not isinstance(transaction, dict):
        out.append(f"{p}: not {{isolation, hold}}")
        return
    _unknown_keys(transaction, ("isolation", "hold"), p, "a transaction", out)
    if transaction.get("isolation") not in ISOLATION_LEVELS:
        out.append(f"{p}.isolation: {transaction.get('isolation')!r} is not one of "
                   f"{', '.join(ISOLATION_LEVELS)}")
    if "hold" in transaction:
        try:
            parse_duration(transaction["hold"])
        except ValueError as exc:
            out.append(f"{p}.hold: {exc}")


def _check_builder(value, p, builders, out):
    """builders/<file>:<function>: a file of the node's builders/ folder
    defining the function at its top level."""
    _unknown_keys(value, ("builder", "options"), p, "a builder", out)
    if "options" in value and not isinstance(value["options"], dict):
        out.append(f"{p}.options: not a map")
    ref = value.get("builder")
    m = BUILDER_RE.match(ref) if isinstance(ref, str) else None
    if m is None:
        out.append(f"{p}.builder: {ref!r} is not builders/<file>:<function>")
        return
    fname, function = m.groups()
    if builders is None:
        out.append(f"{p}.builder: {ref}, but the node has no builders/ seed folder")
        return
    rel, folder = builders
    path = folder / fname
    if not path.is_file():
        out.append(f"{p}.builder: {ref}: {rel}/{fname} does not exist")
        return
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (SyntaxError, UnicodeDecodeError, ValueError) as exc:
        out.append(f"{rel}/{fname}: cannot be parsed as Python: {' '.join(str(exc).split())}")
        return
    if not any(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name == function
               for n in tree.body):
        out.append(f"{p}.builder: {ref}: {rel}/{fname} defines no function {function} at its "
                   "top level")


def _check_rate(rate, p, out):
    m = RATE_RE.match(rate) if isinstance(rate, str) else None
    if m is None or float(m.group(1)) <= 0:
        out.append(f"{p}: {rate!r} is not a rate (<number>/s, /min or /h, positive)")


def _check_schedule(rel, content, keys, names, data, minimum, out):
    """schedule.yaml in scenario time; returns its connection names, or None
    when unusable."""
    check_against_schema(content, template_schema("schedule.yaml"), rel, out=out)
    placeholders(content, rel, out=out)
    if not isinstance(content, dict):
        return None
    for key in content:
        if key not in SCHEDULE_KEYS:
            out.append(f"{rel}: {key}: not a key of a schedule ({', '.join(SCHEDULE_KEYS)}); "
                       "the game's seed is render's")
    if "intensity" in content and not (_is_number(content["intensity"])
                                       and content["intensity"] > 0):
        out.append(f"{rel}: intensity: {content['intensity']!r} is not a positive number")
    connections = _dict(content.get("connections"))
    for name, conn in connections.items():
        _check_connection(conn, f"{rel}: connections.{name}", names, out)
    shapes = content.get("shapes")
    if "shapes" in content and not isinstance(shapes, dict):
        out.append(f"{rel}: shapes: not a map of name -> shape")
    for name, shape in _dict(shapes).items():
        _check_shape(shape, f"{rel}: shapes.{name}", out)
    streams = content.get("streams")
    initial = []
    for i, stream in enumerate(streams if isinstance(streams, list) else []):
        if not isinstance(stream, dict):
            continue                         # reported against the template
        p = f"{rel}: streams[{stream.get('key', i)}]"
        _unknown_keys(stream, STREAM_KEYS, p, "a stream", out)
        key = stream.get("key")
        if key in initial:
            out.append(f"{p}: another stream starts with key {key}; a stream is known by its "
                       "initial key, unique on the node")
        initial.append(key)
        _check_key_ref(key, keys, f"{p}.key", out)
        if "connection" in stream and stream["connection"] not in connections:
            out.append(f"{p}.connection: {stream['connection']} is not a connection of the "
                       "schedule")
        if "rate" in stream:
            _check_rate(stream["rate"], f"{p}.rate", out)
        if "arrivals" in stream and stream["arrivals"] not in ARRIVALS:
            out.append(f"{p}.arrivals: {stream['arrivals']} is not {' or '.join(ARRIVALS)}")
        if "shape" in stream and stream["shape"] not in _dict(shapes):
            out.append(f"{p}.shape: {stream['shape']} is not a shape of the schedule")
        if "concurrency" in stream and not (_is_int(stream["concurrency"])
                                            and stream["concurrency"] > 0):
            out.append(f"{p}.concurrency: {stream['concurrency']!r} is not a positive integer")
    timeline = content.get("timeline")
    for i, change in enumerate(timeline if isinstance(timeline, list) else []):
        if isinstance(change, dict):
            _check_change(change, f"{rel}: timeline[{i}]", keys, connections, initial, data,
                          minimum, out)
    return set(connections)


def _check_key_ref(key, keys, p, out):
    if keys is not None and key is not None and key not in keys:
        out.append(f"{p}: {key} is not a key of the node's queries.yaml")


def _check_connection(conn, p, names, out):
    if not isinstance(conn, dict):
        return                               # reported against the template
    _unknown_keys(conn, CONNECTION_KEYS, p, "a connection", out)
    if "driver" in conn and conn["driver"] not in DRIVERS:
        out.append(f"{p}.driver: {conn['driver']} is not a known driver ({', '.join(DRIVERS)})")
    target = conn.get("target")
    m = TARGET_RE.match(target) if isinstance(target, str) else None
    if "target" in conn and m is None:
        out.append(f"{p}.target: {target!r} is not <node>:<port>/<database>")
    elif m is not None:
        if m.group(1) not in names:
            out.append(f"{p}.target: {target}: {m.group(1)} is not a node of the topology")
        if not _is_port(int(m.group(3))):
            out.append(f"{p}.target: {target}: {m.group(3)} is not a port")
    role = conn.get("role")
    if "role" in conn:
        if not (isinstance(role, str) and DB_ROLE_RE.match(role)):
            out.append(f"{p}.role: {role!r} is not a role name ([a-z_][a-z0-9_]{{0,40}})")
        elif role in RESERVED_DB_ROLES or role.startswith("pg_"):
            out.append(f"{p}.role: {role} is reserved ({', '.join(RESERVED_DB_ROLES)}, pg_*); "
                       "the scheduler connects as an application role")
    pool = conn.get("pool")
    if "pool" in conn and not (
            isinstance(pool, dict) and len(pool) == 1
            and (_is_int(pool.get("size")) and pool["size"] > 0
                 or pool.get("per-call") is True)):
        out.append(f"{p}.pool: {pool!r} is not {{size: N}} (N a positive integer) or "
                   "{per-call: true}")


def _check_hours(hours, p, out):
    """"HH" or "HH-HH" -> multiplier, covering 00 to 23 exactly once."""
    if not (isinstance(hours, dict) and hours):
        out.append(f"{p}: not a map of hours -> multiplier")
        return
    counts = [0] * 24
    for span, multiplier in hours.items():
        m = HOURS_RE.match(span) if isinstance(span, str) else None
        lo, hi = (int(m.group(1)), int(m.group(2) or m.group(1))) if m else (None, None)
        if not isinstance(span, str):
            out.append(f"{p}: {span!r}: hours are quoted strings, \"HH\" or \"HH-HH\" (unquoted, "
                       "YAML reads them as numbers)")
            continue
        if m is None or not lo <= hi <= 23:
            out.append(f"{p}: {span!r} is not an hour or a range of hours (00 to 23, never "
                       "wrapping)")
            continue
        if not (_is_number(multiplier) and multiplier >= 0):
            out.append(f"{p}.{span}: {multiplier!r} is not a multiplier (a number, at least 0)")
        for hour in range(lo, hi + 1):
            counts[hour] += 1
    _coverage([f"{h:02d}" for h in range(24)], counts, "hour", p,
              "a shape covers 00 to 23 exactly once", out)


def _coverage(names, counts, what, p, rule, out):
    missing = [n for n, c in zip(names, counts) if c == 0]
    twice = [n for n, c in zip(names, counts) if c > 1]
    if missing:
        out.append(f"{p}: {what}(s) {', '.join(missing)} not covered ({rule})")
    if twice:
        out.append(f"{p}: {what}(s) {', '.join(twice)} covered more than once ({rule})")


def _check_shape(shape, p, out):
    if not (isinstance(shape, dict) and len(shape) == 1 and next(iter(shape)) in ("hours",
                                                                                 "days")):
        out.append(f"{p}: a shape is {{hours: ...}} or {{days: ...}}")
        return
    if "hours" in shape:
        _check_hours(shape["hours"], f"{p}.hours", out)
        return
    days = shape["days"]
    if not (isinstance(days, dict) and days):
        out.append(f"{p}.days: not a map of days -> {{hours: ...}}")
        return
    counts = [0] * 7
    for span, value in days.items():
        m = DAYS_RE.match(span) if isinstance(span, str) else None
        ends = [m.group(1), m.group(2) or m.group(1)] if m else []
        if not ends or not all(d in WEEKDAYS for d in ends) \
                or WEEKDAYS.index(ends[0]) > WEEKDAYS.index(ends[1]):
            out.append(f"{p}.days: {span!r} is not a day or a range of days ({' '.join(WEEKDAYS)}"
                       ", never wrapping)")
            continue
        for day in range(WEEKDAYS.index(ends[0]), WEEKDAYS.index(ends[1]) + 1):
            counts[day] += 1
        if not (isinstance(value, dict) and set(value) == {"hours"}):
            out.append(f"{p}.days.{span}: not {{hours: ...}}")
            continue
        _check_hours(value["hours"], f"{p}.days.{span}.hours", out)
    _coverage(list(WEEKDAYS), counts, "day", f"{p}.days",
              "a weekly shape covers mon to sun exactly once", out)


def _check_change(change, p, keys, connections, streams, data, minimum, out):
    """A timeline change: before hand-over, no further before it than the
    aging minimum (master spec 7.1)."""
    _unknown_keys(change, CHANGE_KEYS, p, "a timeline change", out)
    at = change.get("at")
    m = HANDOVER_MOMENT_RE.match(at) if isinstance(at, str) else None
    if "at" in change and at != "T0" and m is None:
        out.append(f"{p}.at: {at!r} is not T0 or handover-<N>h (N a whole number of hours, at "
                   "least 1: before hand-over, never at or after it)")
    elif m is not None and minimum is not None and int(m.group(1)) * 3600 > minimum:
        out.append(f"{p}.at: {at} is further before hand-over than aging.minimum "
                   f"{data['aging']['minimum']}")
    if "stream" in change and change["stream"] not in streams:
        out.append(f"{p}.stream: {change['stream']} is not a stream of the schedule (a stream "
                   "is named by its initial key)")
    values = change.get("set")
    if not isinstance(values, dict):
        return                               # reported against the template
    _unknown_keys(values, SET_KEYS, f"{p}.set", "a change", out)
    _check_key_ref(values.get("key"), keys, f"{p}.set.key", out)
    if "rate" in values:
        _check_rate(values["rate"], f"{p}.set.rate", out)
    if "connection" in values and values["connection"] not in connections:
        out.append(f"{p}.set.connection: {values['connection']} is not a connection of the "
                   "schedule")


def _cron_values(field_text, lo, hi, steps):
    """Whether a cron field is a comma list of numbers in lo..hi (and, with
    steps, *, */n, a-b and a-b/n)."""
    for item in field_text.split(","):
        m = re.fullmatch(r"(\*|([0-9]+)(?:-([0-9]+))?)(?:/([0-9]+))?", item)
        if m is None:
            return False
        if not steps and (m.group(1) == "*" or m.group(3) is not None or m.group(4)):
            return False
        if m.group(4) is not None and int(m.group(4)) < 1:
            return False
        if m.group(2) is not None:
            a, b = int(m.group(2)), int(m.group(3) or m.group(2))
            if not lo <= a <= b <= hi:
                return False
    return True


def _cron_problem(at):
    """Why a job's `at` is outside the cron subset render can shift (W1
    item 7), or None."""
    if not isinstance(at, str):
        return f"{at!r} is not a quoted cron expression"
    fields = at.split()
    if len(fields) != 5:
        return f"{at!r} is not a 5-field cron expression"
    minute, hour, dom, month, dow = fields
    if not _cron_values(minute, 0, 59, True):
        return (f"{at!r}: minute {minute} is not a numeric cron form (*, 5, 0-30, */15, 1,31, "
                "0-30/10) within 0-59")
    if hour != "*" and not _cron_values(hour, 0, 23, False):
        return f"{at!r}: hour {hour} is not *, a number or a list of numbers (0-23)"
    if dom != "*" or month != "*":
        return f"{at!r}: day of month and month are * (render shifts the hour only)"
    if dow != "*":
        if not _cron_values(dow, 0, 6, False):
            return f"{at!r}: day of week {dow} is not *, a number or a list of numbers (0-6)"
        if not re.fullmatch(r"[0-9]+", hour):
            return f"{at!r}: a day of week needs a single-number hour (it is {hour})"
    return None


def _check_jobs(rel, content, keys, connections, node, data, faults, out):
    """jobs.yaml in scenario time: no timezone:, a timezone_offset only where
    a fault instance's seed change edits jobs.yaml (spec D168)."""
    check_against_schema(content, template_schema("jobs.yaml"), rel, out=out)
    placeholders(content, rel, out=out)
    jobs = _dict(content).get("jobs")
    offset_fault = any(
        isinstance(i, dict) and i.get("node") == node.get("name") and i.get("id") in faults
        and _dict(faults[i["id"]].data.get("injection")).get("kind") == "seed-file"
        and any(_dict(c).get("file") == "jobs.yaml"
                for c in _dict(faults[i["id"]].data.get("injection")).get("seed_changes") or [])
        for i in data.get("fault_instances") or [])
    seen = set()
    for i, job in enumerate(jobs if isinstance(jobs, list) else []):
        if not isinstance(job, dict):
            continue                         # reported against the template
        p = f"{rel}: jobs[{_item_label(job, i)}]"
        for key in job:
            if key == "timezone":
                out.append(f"{p}.timezone: a scenario's job carries no timezone: (its at is "
                           "scenario time; the wrong-time-zone fault writes timezone_offset, "
                           "spec D168)")
            elif key not in JOB_KEYS:
                out.append(f"{p}.{key}: not a key of a job ({', '.join(JOB_KEYS)})")
        if job.get("name") in seen:
            out.append(f"{p}: duplicate job name")
        seen.add(job.get("name"))
        _check_key_ref(job.get("key"), keys, f"{p}.key", out)
        if connections is not None and "connection" in job \
                and job["connection"] not in connections:
            out.append(f"{p}.connection: {job['connection']} is not a connection of the node's "
                       "schedule.yaml")
        if "at" in job:
            problem = _cron_problem(job["at"])
            if problem:
                out.append(f"{p}.at: {problem}")
        if "timezone_offset" in job:
            offset = job["timezone_offset"]
            if not (_is_int(offset) and offset != 0):
                out.append(f"{p}.timezone_offset: {offset!r} is not a non-zero whole number of "
                           "hours")
            elif not offset_fault:
                out.append(f"{p}.timezone_offset: only on a node where a fault instance's seed "
                           "change edits jobs.yaml (the wrong-time-zone fault, spec D168)")
