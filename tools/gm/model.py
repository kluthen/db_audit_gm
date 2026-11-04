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
POSTGRES_BRICK = "postgres"         # whose seed postgresql.conf render may fill (v0.4 8.5)
POSTGRESQL_CONF = "postgresql.conf"
DATA_SEED_CHANGE = "data"           # a seed change naming the target node's data.file (v0.4
                                    # master spec 6.3, spec D226): not a seed file of a brick
ROLES = ("bastion", "producer", "queue", "database", "pooler", "transformer", "consumer",
         "monitoring", "backup", "api")   # api: the api brick's (v0.5 capture W1 item 1)
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
RESERVED_PARAMETERS = ("write_policy", "write_overrides", "options", "standby_of")   # node keys
                                    # (options, standby_of: v0.5 capture W1 item 0, spec D350)
SEED_ENTRY_FILE_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*$")
# pg_hba methods admitting the GM check role (W1 item 8, D164), and those
# admitting pg_basebackup's replication connection as postgres (7.3).
HBA_PASSWORD_METHODS = ("scram-sha-256", "md5", "password", "trust")
HBA_REPLICATION_METHODS = ("peer", "trust")

# v0.4: purposes, domains, governance (master spec 6.1, 6.7 to 6.9, 11;
# capture W1 of specs/versions/v0.4/wave-log.md, items 0 to 6).
PURPOSE_ID_RE = re.compile(r"^[a-z][a-z0-9-]*$")       # purpose and domain ids (W1 item 0)
PURPOSE_PARTS = ("source", "target", "runner", "consumer", "receiver", "api", "partner")
DATABASE_PARTS = ("source", "target")
PART_ROLES = {"runner": "transformer", "consumer": "consumer", "receiver": "producer",
              "api": "api"}           # partner: a third party's node, any role (v0.5 W1 item 1)
PURPOSE_KINDS = ("pulled", "transformed-in-place", "pushed", "pushed-obligation", "round-trip")
JOB_METHODS = ("sql", "script", "foreign-tables", "procedure", "pg_cron", "cron-daemon")
TRACE_KINDS = ("outbox-rows", "published-results", "run-ledger", "definitions")
INVARIANT_ID_RE = re.compile(r"^[A-Z][0-9]+$")
JUDGES = ("runs", "triggers")
CLASSES = ("personal", "customer-linked", "internal")
UNRESTRICTED_CLASS = "internal"     # a class with no entry in governance: reads as locations: any
SQL_NAME_RE = re.compile(r"^[a-z_][a-z0-9_]*$")
CLASSIFICATION_KEY_RE = re.compile(r"^[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*$")
RECEIVER_LABEL_RE = re.compile(r"^[a-z][a-z0-9-]*$")
PART_TABLE_RE = re.compile(r"^([a-z]+):([a-z_][a-z0-9_]*(?:\.[a-z_][a-z0-9_]*)?)$")
POLICY_SEED_FILE = "data-policy.md"   # the bastion's optional starter-pack seed file (D221, D223)
FRAGMENT_FILES = ("queries.yaml", "schedule.yaml", "jobs.yaml")
FRAGMENT_FOLDERS = ("builders", "scripts")
SCHEDULE_FRAGMENT_KEYS = ("connections", "streams", "shapes")
# The domain format, v0.5 (master spec 6.1, 8.2 to 8.4; W1 item 7).
_SQL_NAME = r"[a-z_][a-z0-9_]*"
# A scenario's copy of a classification: <database>.<table>.<column>, or
# <database>.<schema>.<table>.<column> outside public (W1 item 7).
SCENARIO_CLASSIFICATION_KEY_RE = re.compile(rf"^{_SQL_NAME}(\.{_SQL_NAME}){{2,3}}$")
# A domain's: <table>.<column>, or <schema>.<table>.<column>, never the database.
DOMAIN_CLASSIFICATION_KEY_RE = re.compile(rf"^{_SQL_NAME}(\.{_SQL_NAME}){{1,2}}$")
DOMAIN_TABLE_RE = re.compile(rf"^{_SQL_NAME}(\.{_SQL_NAME})?$")
DOMAIN_PART_KEYS = ("lands_with", "databases", "derive")
RESERVED_PRODUCER_FOLDERS = ("api", "partners", "public")   # never a node's name (D344)
API_FRAGMENT_FILES = ("api.yaml",)
API_FRAGMENT_FOLDERS = ("routes", "db")
API_YAML_KEYS = ("endpoints", "connections")
ENDPOINT_KEYS = ("hosts", "credentials")
ENDPOINT_RE = re.compile(r"^[a-z][a-z0-9_]*$")              # a Python module's (W1 item 0)
HTTP_CONNECTION_KEYS = ("credential", "timeout")            # W1 item 3, beside CONNECTION_KEYS
SCALE_AXES = ("population", "history", "throughput")
TAGS_MATURITY = ("homebrewed", "managed", "industrial")
TAGS_REACH = ("local", "regional", "national", "global")
TAGS_TRAITS = ("regulated", "multi-site", "24/7", "seasonal")
RETENTION_ENDS = ("erased", "anonymised")
_CREATE_TABLE_RE = re.compile(
    rf"^[ \t]*CREATE[ \t]+(?:UNLOGGED[ \t]+)?TABLE[ \t]+(?:IF[ \t]+NOT[ \t]+EXISTS[ \t]+)?"
    rf"({_SQL_NAME}(?:\.{_SQL_NAME})?)\b(?![ \t]*\.)([^\n]*)", re.IGNORECASE | re.MULTILINE)
_PARTITION_OF_RE = re.compile(r"^\s*PARTITION\s+OF\b", re.IGNORECASE)
# What a data file creates (W1 item 0): statements at the start of a line,
# keywords in any case, names unquoted; a line starting with -- is skipped.
_CREATE_NAME_RE = re.compile(
    r"^\s*(?i:create\s+(database|role|user))\s+([a-z_][a-z0-9_]*)(?![A-Za-z0-9_$\"])")
_CREATE_PG_CRON_RE = re.compile(
    r"^\s*(?i:create\s+extension\s+(?:if\s+not\s+exists\s+)?)pg_cron(?![A-Za-z0-9_$\"])")
# A created role's LOGIN or NOLOGIN, in the statement's text up to its `;`
# (string literals and `--` comments removed).
_LOGIN_RE = re.compile(r"(?<![A-Za-z0-9_$])(no)?login(?![A-Za-z0-9_$])", re.IGNORECASE)
_SQL_LITERAL_RE = re.compile(r"'(?:[^']|'')*'")
# A password of the role's own in that text (a literal; PASSWORD NULL sets none).
_OWN_PASSWORD_RE = re.compile(r"(?<![A-Za-z0-9_$])password\s*''", re.IGNORECASE)


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
    """The comment ending a template line, if any. A quote opens a quoted
    scalar only where a scalar starts (after a mapping colon, an indicator
    or blanks); elsewhere, as in `<the shop's database>`, it is a plain
    character."""
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"" and line[:i].rstrip()[-1:] in ("", ":", "[", "{", ",", "-", "?"):
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


class _StrictLoader(yaml.SafeLoader):
    """PyYAML's safe loader refusing a duplicate mapping key, which PyYAML
    otherwise resolves silently to the last (v0.5 master spec 8.4; W1 item 7:
    compose's inputs, merge.yaml, composition.yaml and every file
    check_domain_dir reads; v0.4's released scenario files load as before)."""


def _construct_strict_mapping(loader, node, deep=False):
    loader.flatten_mapping(node)
    seen = {}
    for key_node, _ in node.value:
        key = loader.construct_object(key_node, deep=deep)
        try:
            first = seen.get(key)
        except TypeError:
            continue                         # an unhashable key: the base constructor refuses it
        if first is not None:
            raise yaml.constructor.ConstructorError(
                "while constructing a mapping", node.start_mark,
                f"found duplicate key {key!r} (first on line {first + 1})", key_node.start_mark)
        seen[key] = key_node.start_mark.line
    return yaml.SafeLoader.construct_mapping(loader, node, deep=deep)


_StrictLoader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
                              _construct_strict_mapping)


def strict_load(text):
    """YAML text loaded as safe_load does, refusing a duplicate key (yaml.YAMLError)."""
    return yaml.load(text, Loader=_StrictLoader)


def _load_yaml(path, label, out, strict=False):
    try:
        with open(path, encoding="utf-8") as fh:
            return strict_load(fh) if strict else yaml.safe_load(fh)
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
    optional = seed.get("optional")
    for fname in optional if isinstance(optional, list) else []:
        if is_seed_folder_entry(fname):
            out.append(f"{label}: seed.optional: {fname} is a directory entry, optional already "
                       "(v0.4 capture W1 item 4); seed.optional lists plain entries only")
        elif fname not in files:
            out.append(f"{label}: seed.optional: {fname} is not a seed file of the brick "
                       "(seed.files)")
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


def check_fault_dir(fault_dir, label_base=None, catalog_root=None):
    """Missing items of a fault folder (format skill, "Fault"). Purposes
    named by applies_to.purposes are looked up under `catalog_root`, by
    default the folder holding faults/."""
    fault_dir = Path(fault_dir)
    base = Path(label_base) if label_base else fault_dir.parent.parent
    catalog_root = Path(catalog_root) if catalog_root else fault_dir.parent.parent
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
    if kind == "seed-file" and not injection.get("seed_changes"):
        out.append(f"{label}: injection.seed_changes: missing (kind seed-file)")
    if kind in ("seed-file", "state"):       # a state fault's too (spec D254)
        for change in injection.get("seed_changes") or []:
            material = change.get("material") if isinstance(change, dict) else None
            if material and not (fault_dir / material).is_file():
                out.append(f"{_rel(fault_dir / str(material), base)}: missing file")
    if kind == "state":
        if not injection.get("scripts"):
            out.append(f"{label}: injection.scripts: missing (kind state)")
        for script in injection.get("scripts") or []:
            if not (fault_dir / str(script)).is_file():
                out.append(f"{_rel(fault_dir / str(script), base)}: missing file")
    elif kind not in (None, "seed-file", "parameter"):
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
    _check_fault_v04(data, label, catalog_root, out)
    _check_fault_options(data, label, out)
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


def _check_fault_v04(data, label, catalog_root, out):
    """v0.4's fault keys (master spec 6.3, 6.9; capture W1 item 3):
    applies_to.purposes, sealed_check.judges, needs_unshared_host."""
    applies = _dict(data.get("applies_to"))
    purposes = applies.get("purposes")
    if "purposes" in applies and not isinstance(purposes, list):
        out.append(f"{label}: applies_to.purposes: not a list of purpose ids")
    for pid in purposes if isinstance(purposes, list) else []:
        if not (isinstance(pid, str) and PURPOSE_ID_RE.match(pid)):
            out.append(f"{label}: applies_to.purposes: {pid!r} is not a purpose id "
                       "([a-z][a-z0-9-]*)")
        elif not (Path(catalog_root) / "purposes" / pid / "purpose.yaml").is_file():
            out.append(f"{label}: applies_to.purposes: {pid} is not a purpose (no "
                       f"purposes/{pid}/purpose.yaml in the catalog)")
    sealed = _dict(data.get("sealed_check"))
    if "judges" in sealed:
        if sealed["judges"] not in JUDGES:
            out.append(f"{label}: sealed_check.judges: {sealed['judges']!r} is not "
                       f"{' or '.join(JUDGES)} (absent: the check judges the live state)")
        if sealed.get("behavioural") is True:
            out.append(f"{label}: sealed_check.judges: never with behavioural: true (a check "
                       "judging runs or triggers takes no window; master spec 6.2)")
    if "needs_unshared_host" in data and not isinstance(data["needs_unshared_host"], bool):
        out.append(f"{label}: needs_unshared_host: {data['needs_unshared_host']!r} is not a "
                   "boolean")


def fault_judges(fault_data):
    """runs or triggers when the fault's sealed check judges a purpose's
    runs or triggers, else None (master spec 6.3)."""
    judges = _dict(fault_data.get("sealed_check")).get("judges")
    return judges if judges in JUDGES else None


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
        if kind == "brick":
            missing = check_brick_dir(directory, label_base=base)
        else:
            missing = check_fault_dir(directory, label_base=base, catalog_root=catalog_root)
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

    third = _check_third_parties(data, nodes, bricks, out, sdir, catalog_root)
    apis = _api_files(nodes, bricks, sdir, out)
    http = _http_context(nodes, bricks, third, apis)
    _check_node_maps(nodes, bricks, out)
    routes = _check_web_routes(nodes, bricks, out, http)

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
    _check_scheduler_files(data, nodes, faults, minimum, sdir, out, http)
    creates = {}
    for node in nodes:
        created = node_creates(sdir, data, node, catalog_root)
        if created is not None:
            creates[node.get("name")] = created
    _check_v04(data, nodes, creates, sdir, catalog_root, out)
    _check_composition(data, sdir, catalog_root, out)
    _check_v05(data, nodes, bricks, faults, answer_key, third, apis, http, sdir, catalog_root,
               out)

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
        elif policy not in (b.get("write_policies") or []):
            out.append(f"{label}: {p}.write_policy: {policy} is not supported by brick "
                       f"{brick.id} ({', '.join(b.get('write_policies') or [])})")
    if "write_overrides" in node:
        _check_write_overrides(node, brick, p, out)
    if "options" in node:
        _check_node_options(node, brick, p, out)
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
    optional = seed_optional(b)
    if isinstance(seed_files, dict):
        for fname in declared:
            if fname not in seed_files and not is_seed_folder_entry(fname) \
                    and fname not in optional:
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


def seed_optional(brick_data):
    """The plain seed files a node of the brick may leave out of its
    seed_files (brick.yaml seed.optional; v0.4 master spec 6.4)."""
    optional = _dict(brick_data.get("seed")).get("optional")
    return [f for f in optional if isinstance(f, str)] if isinstance(optional, list) else []


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


def _check_web_routes(nodes, bricks, out, http=None):
    """web-routes parameters against the topology's web interfaces, and the
    web front's published port (v0.2 capture W1, item 3): a node whose brick
    has a web-routes parameter (the bastion) publishes it whatever its routes,
    the front running in every game (v0.4, D224). Returns the route names."""
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
        shaped = _shaped(brick.data, "web-routes")
        for pname in shaped:
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
                if http is not None and tnode in http.third_party_nodes:
                    out.append(f"{label}: {rp}: {tnode} is a third party's node: no third party "
                               "is on the bastion's routes (master spec 10.2, spec D363)")
                    continue
                if http is not None and tnode in http.aliases:
                    out.append(f"{label}: {rp}: {tnode} is a third party's hostname (an alias on "
                               "the partners' api node): no third party is on the bastion's "
                               "routes (master spec 10.2, spec D363)")
                    continue
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
        if shaped:
            ports = node.get("published_ports")
            ports = [x for x in ports if isinstance(x, dict)] if isinstance(ports, list) else []
            if not any(x.get("port") == WEB_FRONT_PORT
                       and x.get("default") == WEB_FRONT_PORT for x in ports):
                out.append(f"{label}: nodes[{name}].published_ports: no {{port: "
                           f"{WEB_FRONT_PORT}, default: {WEB_FRONT_PORT}}}, which the web "
                           "front needs (it runs in every game, routes or none)")
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
                if isinstance(change, dict) and change.get("file") == DATA_SEED_CHANGE:
                    if not _dict(by_name[target].get("data")).get("file"):
                        out.append(f"{label}: {p}: fault {fault.id} changes {DATA_SEED_CHANGE}, "
                                   f"the node's data file, but node {target} has none (no "
                                   "data.file; v0.4 master spec 6.3, spec D226)")
                elif isinstance(change, dict) and change.get("file") not in seeds:
                    out.append(f"{label}: {p}: fault {fault.id} changes {change.get('file')}, "
                               f"not a seed file of brick {brick.id}")
                elif isinstance(change, dict) and change.get("file") in seed_optional(brick.data) \
                        and change.get("file") not in _dict(by_name[target].get("seed_files")):
                    out.append(f"{label}: {p}: fault {fault.id} changes {change.get('file')}, "
                               f"which node {target} does not seed (an optional seed file of "
                               f"brick {brick.id}; v0.4 capture W1 item 1)")
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
        _check_register_diff(entry, fault, out)
    for entry in entries:
        evidence = entry.get("evidence")
        for i, item in enumerate(evidence if isinstance(evidence, list) else []):
            if isinstance(item, dict) and "where" in item:
                _check_where(item["where"], nodes, routes,
                             f"instances[{entry.get('instance')}].evidence[{i}].where", out)
    _check_expectations(key.get("tooling_expectations"), instances, out)
    return key


def _check_behavioural(entry, fault, label, out):
    """A sealed check's judges, window and threshold (v0.3 master spec 6.2,
    11, its capture W1 item 4; v0.4 master spec 6.2, 12, capture W1 item 2).
    A behavioural check: window and threshold, exactly when the fault's
    sealed_check.behavioural is true; the window a duration, the threshold a
    number. A check judging runs or triggers: judges, the fault's, and a
    threshold, a non-negative integer; no window."""
    p = f"{label}: instances[{entry.get('instance')}].sealed_check"
    sealed = _dict(entry.get("sealed_check"))
    judges = fault_judges(fault.data)
    if judges is not None:
        if "judges" not in sealed:
            out.append(f"{p}.judges: missing (fault {fault.id}'s sealed check judges {judges})")
        elif sealed["judges"] != judges:
            out.append(f"{p}.judges: {sealed['judges']}, but fault {fault.id}'s sealed check "
                       f"judges {judges}")
        if "threshold" not in sealed:
            out.append(f"{p}.threshold: missing (fault {fault.id}'s sealed check judges "
                       f"{judges}: the violations tolerated)")
        elif not (_is_int(sealed["threshold"]) and sealed["threshold"] >= 0):
            out.append(f"{p}.threshold: {sealed['threshold']!r} is not a non-negative integer "
                       "(the violations tolerated)")
        if "window" in sealed:
            out.append(f"{p}.window: fault {fault.id}'s sealed check judges {judges}, which "
                       "takes no window (master spec 6.2)")
        return
    if "judges" in sealed:
        out.append(f"{p}.judges: fault {fault.id}'s sealed check judges no runs or triggers (no "
                   "sealed_check.judges), so it takes no judges")
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
    """{{customer_timezone}} in the files render fills: the bastion's seed
    files (the starter pack, the story included) and, from v0.4, a
    `postgres` node's seed postgresql.conf (cron.timezone; a scheduler
    node's seed files need no rule, the node itself making the scenario
    age): refused with no scheduler node (master spec 6.1, 8.5, D158; v0.3
    W1 item 1, v0.4 W1 item 0)."""
    if scheduled:
        return
    for node in nodes:
        if node.get("role") == "bastion":
            fnames = list(_dict(node.get("seed_files")))
        elif _dict(node.get("brick")).get("id") == POSTGRES_BRICK:
            fnames = [POSTGRESQL_CONF]
        else:
            continue
        for fname in fnames:
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


# --- v0.4: data files, purposes, domains, governance -----------------------
# (master spec 6.1, 6.7 to 6.9, 11, 14; capture W1 of
# specs/versions/v0.4/wave-log.md, items 0, 1, 5 and 6)

@dataclass
class DataFileCreates:
    """What a data file creates, read line by line (W1 item 0): no SQL
    parser, so a statement inside a DO body or a function is not seen.
    `logins`: the roles created with LOGIN (`CREATE USER` without NOLOGIN,
    `CREATE ROLE` with LOGIN, read up to the statement's `;`) and no
    password of their own (`PASSWORD '...'`), in file order (master spec
    9.7: load-data gives each its secret; a role whose statement sets its
    password keeps it, 16.4: v0.3's scenarios run unchanged)."""
    file: str
    databases: set = field(default_factory=set)
    roles: set = field(default_factory=set)
    pg_cron: bool = False
    logins: list = field(default_factory=list)
    sources: list = field(default_factory=list)   # what was read: the data file, then each
                                                  # domain file (node_creates, v0.5 W2 item 1)


def _statement_login(kind, lines):
    """Whether the role a `CREATE ROLE|USER` statement creates can log in
    with no password of its own; `lines`, the statement's text after the
    name, then the lines after."""
    text = []
    for line in lines:
        line = _SQL_LITERAL_RE.sub("''", line).split("--", 1)[0]
        text.append(line.split(";", 1)[0])
        if ";" in line:
            break
    attributes = " ".join(text)
    if _OWN_PASSWORD_RE.search(attributes):
        return False
    m = None
    for m in _LOGIN_RE.finditer(attributes):
        pass                                 # the last one wins, as in PostgreSQL
    return kind == "user" if m is None else m.group(1) is None


def data_file_creates(text, rel):
    created = DataFileCreates(rel, sources=[rel])
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = _CREATE_NAME_RE.match(line)
        if m:
            kind, name = m.group(1).lower(), m.group(2)
            (created.databases if kind == "database" else created.roles).add(name)
            if kind != "database" and name not in created.logins and _statement_login(
                    kind, [line[m.end():], *lines[i + 1:]]):
                created.logins.append(name)
        elif _CREATE_PG_CRON_RE.match(line):
            created.pg_cron = True
    return created


def node_data_file_creates(sdir, node):
    """DataFileCreates of a node's data file (data.file), or None when it
    has none or it does not exist or read."""
    rel = _dict(node.get("data")).get("file")
    path = _inside(sdir, rel) if isinstance(rel, str) else None
    if path is None or not path.is_file():
        return None                          # reported with the node
    try:
        return data_file_creates(path.read_text(encoding="utf-8"), rel)
    except (OSError, UnicodeDecodeError):
        return None


def _data_files(nodes, sdir):
    """node name -> DataFileCreates of its data file (data.file), for each
    node whose data file exists and reads."""
    creates = {}
    for node in nodes:
        created = node_data_file_creates(sdir, node)
        if created is not None:
            creates[node.get("name")] = created
    return creates


def _location_problem(value, by_name, creates):
    """Why `value` is not a location <node>/<database> (W1 item 0): a
    database node, and a database its data file creates; or None."""
    node, sep, database = value.partition("/") if isinstance(value, str) else ("", "", "")
    if not sep or not NAME_RE.match(node) or not SQL_NAME_RE.match(database):
        return f"{value!r} is not a location <node>/<database>"
    if node not in by_name:
        return f"{value}: {node} is not a node"
    role = by_name[node].get("role")
    if role != "database":
        return f"{value}: {node} is not a database node (its role is {role})"
    if by_name[node].get("standby_of") is not None:
        return (f"{value}: {node} is a standby (standby_of {by_name[node]['standby_of']}): a "
                "standby is no location, it holds its primary's copy (v0.5 W2 item 1)")
    created = creates.get(node)
    if created is None:
        return f"{value}: node {node} has no data file to create database {database}"
    if database not in created.databases:
        if created.sources != [created.file]:
            return (f"{value}: {database} is not a database node {node}'s data file or the "
                    f"domains placed on it create ({', '.join(created.sources)})")
        return (f"{value}: {database} is not a database node {node}'s data file "
                f"({created.file}) creates (CREATE DATABASE {database})")
    return None


def check_classification(path, rel, out, domain_databases=None):
    """A classification file (template classification.yaml; v0.4 W1 items 0
    and 6, v0.5 W1 item 7). A scenario's copy keys <database>.<table>.<column>
    (<database>.<schema>.<table>.<column> outside public); a domain's, given
    `domain_databases` (the databases its schema files create or it lists),
    <table>.<column> (<schema>.<table>.<column>), never the database. Returns
    the classes it uses, or None when unusable."""
    content = _load_yaml(path, rel, out, strict=domain_databases is not None)
    if content is None:
        return None
    check_against_schema(content, template_schema("classification.yaml"), rel, out=out)
    placeholders(content, rel, out=out)
    columns = _dict(content).get("columns")
    if not isinstance(columns, dict):
        return None
    used = set()
    for key, cls in columns.items():
        p = f"{rel}: columns.{key}"
        names = key.split(".") if isinstance(key, str) else []
        if domain_databases is None:
            if not (isinstance(key, str) and SCENARIO_CLASSIFICATION_KEY_RE.match(key)):
                out.append(f"{p}: {key!r} is not <database>.<table>.<column> (names "
                           "[a-z_][a-z0-9_]*; <database>.<schema>.<table>.<column> outside "
                           "schema public)")
        elif not (isinstance(key, str) and DOMAIN_CLASSIFICATION_KEY_RE.match(key)):
            out.append(f"{p}: {key!r} is not <table>.<column> (names [a-z_][a-z0-9_]*; "
                       "<schema>.<table>.<column> outside schema public)")
        elif len(names) == 3 and names[0] in domain_databases:
            out.append(f"{p}: keyed with its database {names[0]}: a domain keys "
                       "<table>.<column> (<schema>.<table>.<column> outside public), the "
                       "scenario's copy adds the database (master spec 6.1)")
        elif len(names) == 3 and names[0] == "public":
            out.append(f"{p}: schema public is never written: <table>.<column>")
        if cls not in CLASSES:
            out.append(f"{p}: {cls!r} is not a class ({', '.join(CLASSES)}; "
                       "master spec 11.2)")
        else:
            used.add(cls)
    return used


def _check_fragments(folder, base, scripts_allowed, out, scheduler=True, api=False,
                     partner=False):
    """A folder of fragments (formats, "Purpose folder" and "Domain
    folder"): queries.yaml, schedule.yaml and jobs.yaml with the scenario
    file's top-level keys holding only what they add, and builders/ or
    scripts/ folders; with `api`, an api node's api.yaml fragment, routes/
    and db/ (W1 items 5 and 7); without `scheduler`, those only; with
    `partner`, a partner folder's one data.sql, its state in the partners'
    database (v0.5 W2 item 1). A queries fragment is checked as a node's
    repository."""
    rel = _rel(folder, base)
    files, folders = (), ()
    if scheduler:
        files += FRAGMENT_FILES
        folders += FRAGMENT_FOLDERS if scripts_allowed else FRAGMENT_FOLDERS[:1]
    if api:
        files += API_FRAGMENT_FILES
        folders += API_FRAGMENT_FOLDERS
    if partner:
        files += (PARTNER_DATA_FILE,)
    loaded = {}
    for entry in sorted(folder.iterdir()):
        shown = f"{rel}/{entry.name}"
        if entry.is_dir() and entry.name in folders:
            continue
        if partner and entry.is_file() and entry.name == PARTNER_DATA_FILE:
            continue                         # read by the domain's SECURITY DEFINER check
        if not (entry.is_file() and entry.name in files):
            out.append(f"{shown}{'/' if entry.is_dir() else ''}: not a fragment ("
                       f"{', '.join(files + tuple(f + '/' for f in folders))})")
            continue
        loaded[entry.name] = _load_yaml(entry, shown, out, strict=True)
    allowed = {"queries.yaml": ("queries",), "jobs.yaml": ("jobs",),
               "schedule.yaml": SCHEDULE_FRAGMENT_KEYS, "api.yaml": API_YAML_KEYS}
    for fname, content in loaded.items():
        shown = f"{rel}/{fname}"
        if content is None:
            continue
        if not isinstance(content, dict):
            out.append(f"{shown}: top level: not a mapping")
            continue
        for key in content:
            if key not in allowed[fname]:
                why = "; intensity and timeline are the scenario's" \
                    if fname == "schedule.yaml" else ""
                out.append(f"{shown}: {key}: not a key of a {fname} fragment "
                           f"({', '.join(allowed[fname])}){why}")
    if loaded.get("queries.yaml") is not None:
        seeds = [(f"{rel}/{name}", folder / name) if (folder / name).is_dir() else None
                 for name in FRAGMENT_FOLDERS]
        _check_queries(f"{rel}/queries.yaml", loaded["queries.yaml"], seeds[0], out,
                       seeds[1] if scripts_allowed else None)
    if isinstance(loaded.get("api.yaml"), dict):
        _check_api_fragment(f"{rel}/api.yaml", loaded["api.yaml"], out)


def _check_api_fragment(rel, content, out):
    """An api.yaml fragment's keys (W1 item 5): endpoints.<name> with hosts and
    optionally credentials, connections.<name> in schedule.yaml's two forms.
    Its two files per endpoint and its hosts against the topology are the
    scenario's checks."""
    endpoints = content.get("endpoints", {})
    if not isinstance(endpoints, dict):
        out.append(f"{rel}: endpoints: not a mapping of endpoint name -> its hosts")
        endpoints = {}
    for name, entry in endpoints.items():
        p = f"{rel}: endpoints.{name}"
        if not (isinstance(name, str) and ENDPOINT_RE.match(name)):
            out.append(f"{p}: {name!r} is not an endpoint name ([a-z][a-z0-9_]*, a Python "
                       "module's)")
        if not isinstance(entry, dict):
            out.append(f"{p}: not a mapping (hosts, credentials)")
            continue
        _unknown_keys(entry, ENDPOINT_KEYS, p, "an endpoint", out)
        hosts = entry.get("hosts")
        if not (isinstance(hosts, list) and hosts and all(isinstance(h, str) for h in hosts)):
            out.append(f"{p}.hosts: not a non-empty list of hostnames")
        creds = entry.get("credentials")
        if "credentials" in entry and not (
                isinstance(creds, list) and creds
                and all(isinstance(c, str) and SCRIPT_CONNECTION_RE.match(c) for c in creds)):
            out.append(f"{p}.credentials: not a non-empty list of credential names "
                       "([a-z][a-z0-9_]*); absent for a public endpoint")
    connections = content.get("connections", {})
    if not isinstance(connections, dict):
        out.append(f"{rel}: connections: not a mapping of connection name -> connection")
        connections = {}
    for name, conn in connections.items():
        p = f"{rel}: connections.{name}"
        if not isinstance(conn, dict):
            out.append(f"{p}: not a mapping")
            continue
        _unknown_keys(conn, CONNECTION_KEYS + HTTP_CONNECTION_KEYS, p, "a connection", out)


def _domain_schema_files(domain_dir, data):
    """(database or None, path) of each schema file of a domain."""
    databases = data.get("databases")
    if isinstance(databases, list):
        return [(db, domain_dir / "data" / db / "schema.sql") for db in databases
                if isinstance(db, str) and SQL_NAME_RE.match(db)]
    rel = data.get("schema")
    path = _inside(domain_dir, rel) if isinstance(rel, str) else None
    return [(None, path)] if path is not None else []


def _domain_tables(files, label, out):
    """The tables of a domain's schema files, keyed as its classification keys
    them (<table>, <schema>.<table> outside public), partitions aside: a
    partition goes with its parent. Returns (tables, databases created)."""
    tables, databases = {}, set()
    for db, path in files:
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        databases |= data_file_creates(text, str(path)).databases
        if db is not None:
            databases.add(db)
        for m in _CREATE_TABLE_RE.finditer(text):
            if _PARTITION_OF_RE.match(m.group(2)):
                continue
            name = m.group(1).lower()
            name = name[len("public."):] if name.startswith("public.") else name
            if name in tables and tables[name] != db:
                out.append(f"{label}: table {name} in databases {tables[name]} and {db}: a "
                           "part keeps its keys unique across its databases (formats.md "
                           "\"Domain\")")
            tables.setdefault(name, db)
    return set(tables), databases


def _sibling_domain(domain_dir, did):
    """The domain.yaml of a domain beside this one, or None."""
    path = domain_dir.parent / did / "domain.yaml"
    if not (isinstance(did, str) and PURPOSE_ID_RE.match(did) and path.is_file()):
        return None
    try:
        data = strict_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else {}


def _check_domain_part(domain_dir, data, label, out):
    """A part's keys (formats.md "domain.yaml must contain"; W1 item 7): one
    core, beside it, itself no part; lands_with its core; databases; derive."""
    did = domain_dir.name
    requires = data.get("requires")
    if "requires" not in data:
        for key in DOMAIN_PART_KEYS:
            if key in data:
                out.append(f"{label}: {key}: a part's key, but {did} requires no core "
                           "(requires: [<core>])")
        return
    if not (isinstance(requires, list) and len(requires) == 1
            and isinstance(requires[0], str) and PURPOSE_ID_RE.match(requires[0])):
        out.append(f"{label}: requires: {requires!r} is not one core's domain id, "
                   "[<core>] (one level only)")
        return
    core = requires[0]
    core_data = _sibling_domain(domain_dir, core) if core != did else None
    if core == did:
        out.append(f"{label}: requires: {did} cannot require itself")
    elif core_data is None:
        out.append(f"{label}: requires: {core}: no domain {core} beside it "
                   f"({_rel(domain_dir.parent / core / 'domain.yaml', domain_dir.parent.parent)}): "
                   "a part is taken only with its core")
    elif "requires" in core_data:
        out.append(f"{label}: requires: {core} is itself a part (requires "
                   f"{core_data['requires']}): a part requires a core, one level only")
    if "lands_with" in data and data["lands_with"] != core:
        out.append(f"{label}: lands_with: {data['lands_with']!r} is not its core {core}")
    databases = data.get("databases")
    if "databases" in data:
        if not (isinstance(databases, list) and databases
                and all(isinstance(d, str) and SQL_NAME_RE.match(d) for d in databases)
                and len(set(databases)) == len(databases)):
            out.append(f"{label}: databases: {databases!r} is not a list of unique database "
                       "names ([a-z_][a-z0-9_]*)")
        for key in ("schema", "load"):
            if key in data:
                out.append(f"{label}: {key}: absent with databases (data/<database>/"
                           f"{key}.sql for each)")
        for db in databases if isinstance(databases, list) else []:
            for fname in ("schema.sql", "load.sql"):
                if isinstance(db, str) and SQL_NAME_RE.match(db) \
                        and not (domain_dir / "data" / db / fname).is_file():
                    out.append(f"{_rel(domain_dir / 'data' / db / fname, domain_dir.parent.parent)}: "
                               f"missing file ({label} databases: {db})")
    derive = data.get("derive")
    if "derive" in data:
        after = derive.get("after") if isinstance(derive, dict) else None
        if not (isinstance(derive, dict) and set(derive) == {"after"}
                and isinstance(after, list) and after):
            out.append(f"{label}: derive: {derive!r} is not {{after: [<domain>, ...]}}")
        for item in after if isinstance(after, list) else []:
            if item == did or _sibling_domain(domain_dir, item) is None:
                out.append(f"{label}: derive.after: {item!r} is not another domain of the "
                           "catalogue")
        if not (domain_dir / "data" / "derive.sql").is_file():
            out.append(f"{_rel(domain_dir / 'data' / 'derive.sql', domain_dir.parent.parent)}: "
                       f"missing file ({label} derive)")


def _check_register(path, rel, tables, out):
    """The register fragment (template register.yaml; D334): every table of
    the domain in exactly one processing activity."""
    content = _load_yaml(path, rel, out, strict=True)
    if content is None:
        return
    check_against_schema(content, template_schema("register.yaml"), rel, out=out)
    placeholders(content, rel, out=out)
    activities = _dict(content).get("activities")
    if not isinstance(activities, list):
        return
    seen, held = set(), {}
    for i, act in enumerate(activities):
        if not isinstance(act, dict):
            continue                         # reported against the template
        aid = act.get("id")
        p = f"{rel}: activities[{aid if isinstance(aid, str) else i}]"
        if not (isinstance(aid, str) and PURPOSE_ID_RE.match(aid)):
            out.append(f"{p}.id: {aid!r} is not an activity id ([a-z][a-z0-9-]*)")
        elif aid in seen:
            out.append(f"{p}.id: {aid} twice")
        seen.add(aid)
        retention = act.get("retention")
        then = retention.get("then") if isinstance(retention, dict) else None
        if isinstance(retention, dict) and "then" in retention and then not in RETENTION_ENDS:
            out.append(f"{p}.retention.then: {then!r} is not {' or '.join(RETENTION_ENDS)}")
        listed = act.get("tables")
        for table in listed if isinstance(listed, list) else []:
            if not (isinstance(table, str) and DOMAIN_TABLE_RE.match(table)) \
                    or table not in tables:
                out.append(f"{p}.tables: {table!r} is not a table of the domain's schema "
                           "(<table>, <schema>.<table> outside public)")
                continue
            held.setdefault(table, []).append(str(aid))
    for table in sorted(tables):
        owners = held.get(table, [])
        if not owners:
            out.append(f"{rel}: activities: table {table} is in no activity (every table "
                       "belongs to exactly one, D334)")
        elif len(owners) > 1:
            out.append(f"{rel}: activities: table {table} is in {len(owners)} activities "
                       f"({', '.join(owners)}); every table belongs to exactly one (D334)")


def _check_producers(folder, base, out):
    """A domain's producers/ (or a variant's profile, laid out alike; formats.md
    "Producer material", D344, W1 item 7): producers/<node>/ for a scheduler
    node, api/<node>/ for an api node, partners/<partner>/ and public/<name>/
    for a partner's back end and endpoints; nothing at its root."""
    rel = _rel(folder, base)
    for entry in sorted(folder.iterdir()):
        shown = f"{rel}/{entry.name}"
        if not entry.is_dir():
            out.append(f"{shown}: a fragment at producers/' root: fragments sit in "
                       "producers/<node>/, one folder per node they target (D344)")
            continue
        if entry.name not in RESERVED_PRODUCER_FOLDERS:
            if not NAME_RE.match(entry.name):
                out.append(f"{shown}/: {entry.name} is not a node name")
            else:
                _check_fragments(entry, base, True, out)
            continue
        for sub in sorted(entry.iterdir()):
            sub_shown = f"{shown}/{sub.name}"
            if not sub.is_dir():
                what = "api node" if entry.name == "api" else "partner"
                out.append(f"{sub_shown}: not a folder: {entry.name}/ holds one folder per "
                           f"{what}")
            elif not NAME_RE.match(sub.name):
                out.append(f"{sub_shown}/: {sub.name} is not a "
                           f"{'node' if entry.name == 'api' else 'partner'} name")
            elif entry.name == "api":
                _check_fragments(sub, base, True, out, scheduler=False, api=True)
            else:
                if entry.name == "partners" and not PARTNER_PREFIX_RE.match(sub.name):
                    out.append(f"{sub_shown}/: {sub.name} is not a partner's prefix "
                               "([a-z][a-z0-9]{0,15}: its role, schema, keys' and endpoints' "
                               "prefix; v0.5 W2 item 0)")
                _check_fragments(sub, base, True, out, api=True, partner=True)


def _check_scale(scale, p, out):
    if not isinstance(scale, dict):
        return                               # reported against the template
    for axis in SCALE_AXES:
        values = scale.get(axis)
        if axis in scale and not (
                isinstance(values, dict) and values
                and all(isinstance(k, str) for k in values)
                and all(isinstance(v, (int, float, str)) and not isinstance(v, bool)
                        for v in values.values())):
            out.append(f"{p}.{axis}: not a non-empty map of name -> number or text")
    for axis in scale:
        if axis not in SCALE_AXES:
            out.append(f"{p}.{axis}: not a scale axis ({', '.join(SCALE_AXES)})")


def _check_tags(tags, p, out):
    if not isinstance(tags, list):
        if tags is not None:
            out.append(f"{p}: not a list of tags")
        return
    for tag in tags:
        if tag not in TAGS_MATURITY + TAGS_REACH + TAGS_TRAITS:
            out.append(f"{p}: {tag!r} is not a tag of the vocabulary (maturity "
                       f"{', '.join(TAGS_MATURITY)}; reach {', '.join(TAGS_REACH)}; traits "
                       f"{', '.join(TAGS_TRAITS)}; D263)")
    for axis, vocab in (("maturity", TAGS_MATURITY), ("reach", TAGS_REACH)):
        taken = [t for t in tags if t in vocab]
        if len(taken) > 1:
            out.append(f"{p}: {len(taken)} {axis} tags ({', '.join(taken)}): a setup has at "
                       "most one")


def _check_variants(domain_dir, data, base, label, out):
    """variants/ (formats.md "Variants, scale and tags", D263, D301; W1 item
    7): at least one manifest; a core's names its parts, sets the three axes,
    takes its tags from the vocabulary and lists purposes that fit; a part's,
    named after its core's variant, holds scale and purposes only."""
    vdir = domain_dir / "variants"
    vrel = _rel(vdir, base)
    if not vdir.is_dir():
        out.append(f"{vrel}/: missing folder (a domain has at least one variant, "
                   "variants/<variant>.yaml)")
        return
    did = domain_dir.name
    requires = data.get("requires")
    core = requires[0] if isinstance(requires, list) and len(requires) == 1 else None
    is_part = "requires" in data
    fits = data.get("purposes") if isinstance(data.get("purposes"), list) else []
    manifests = sorted(p for p in vdir.iterdir() if p.is_file() and p.suffix == ".yaml")
    if not manifests:
        out.append(f"{vrel}/: no variant (a domain has at least one, variants/<variant>.yaml)")
    names = {p.stem for p in manifests}
    for entry in sorted(vdir.iterdir()):
        shown = f"{vrel}/{entry.name}"
        if entry.is_file() and entry.suffix == ".yaml":
            continue
        if not entry.is_dir():
            out.append(f"{shown}: not a variant (<variant>.yaml, <variant>/producers/)")
        elif entry.name not in names:
            out.append(f"{shown}/: no manifest {entry.name}.yaml beside it")
        else:
            for sub in sorted(entry.iterdir()):
                if sub.name != "producers" or not sub.is_dir():
                    out.append(f"{shown}/{sub.name}: not a variant's profile (producers/)")
                else:
                    _check_producers(sub, base, out)
    for path in manifests:
        rel = _rel(path, base)
        variant = path.stem
        if not NAME_RE.match(variant):
            out.append(f"{rel}: {variant} is not a variant name ([a-z][a-z0-9-]*)")
        content = _load_yaml(path, rel, out, strict=True)
        if content is None:
            continue
        check_against_schema(content, template_schema("variant.yaml"), rel, out=out)
        placeholders(content, rel, out=out)
        if not isinstance(content, dict):
            continue
        _check_scale(content.get("scale"), f"{rel}: scale", out)
        purposes = content.get("purposes")
        for pid in purposes if isinstance(purposes, list) else []:
            if pid not in fits:
                out.append(f"{rel}: purposes: {pid!r} is not among {label}'s purposes")
        if is_part:
            for key in content:
                if key not in ("scale", "purposes"):
                    out.append(f"{rel}: {key}: a part's manifest holds scale and purposes "
                               "only (D301)")
            core_manifest = domain_dir.parent / str(core) / "variants" / f"{variant}.yaml"
            core_variant = _sibling_yaml(core_manifest) if core else None
            if core and core_variant is None:
                out.append(f"{rel}: no variant {variant} of its core {core} "
                           f"({_rel(core_manifest, base)}): a part's manifest takes its "
                           "core variant's name (D301)")
            elif core and did not in (core_variant.get("parts") or []):
                out.append(f"{rel}: {core}'s variant {variant} does not name {did} in its "
                           "parts (D301)")
            continue
        for key in ("parts", "tags"):
            if key not in content:
                out.append(f"{rel}: {key}: missing (a core's variant)")
        _check_tags(content.get("tags"), f"{rel}: tags", out)
        parts = content.get("parts")
        if "parts" in content and not isinstance(parts, list):
            out.append(f"{rel}: parts: not a list of domain ids")
        for part in parts if isinstance(parts, list) else []:
            part_data = _sibling_domain(domain_dir, part)
            if part_data is None:
                out.append(f"{rel}: parts: {part!r} is not a domain of the catalogue")
            elif part_data.get("requires") != [did]:
                out.append(f"{rel}: parts: {part} does not require {did}")
            elif not (domain_dir.parent / part / "variants" / f"{variant}.yaml").is_file():
                out.append(f"{rel}: parts: {part} has no manifest variants/{variant}.yaml "
                           "(its own axes, D301)")


def _sibling_yaml(path):
    """A YAML mapping read for a cross-reference, or None when absent or unusable."""
    if not path.is_file():
        return None
    try:
        data = strict_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError:
        return None
    return data if isinstance(data, dict) else None


def check_domain_dir(domain_dir, label_base=None):
    """Missing items of a domain folder (format skill, "Domain"; formats.md
    "Domain"; v0.5 master spec 6.1, 8.2 to 8.6; v0.5 W1 item 7)."""
    domain_dir = Path(domain_dir)
    base = Path(label_base) if label_base else domain_dir.parent.parent
    label = _rel(domain_dir / "domain.yaml", base)
    out = []
    data = _load_yaml(domain_dir / "domain.yaml", label, out, strict=True)
    if data is None:
        return out
    check_against_schema(data, template_schema("domain.yaml"), label, out=out)
    placeholders(data, label, out=out)
    if not isinstance(data, dict):
        return out
    if data.get("id") != domain_dir.name:
        out.append(f"{label}: id: {data.get('id')} is not the folder name {domain_dir.name}")
    if not PURPOSE_ID_RE.match(domain_dir.name):
        out.append(f"{label}: id: {domain_dir.name} is not a domain id ([a-z][a-z0-9-]*)")
    elif domain_dir.name == PARTNERS_DATABASE:
        out.append(f"{label}: id: {PARTNERS_DATABASE} is reserved: it names the partners' "
                   "database (a coherence check's reads), never a domain (W2 item 0)")
    if "databases" not in data:
        for key in ("schema", "load"):
            if key not in data:
                out.append(f"{label}: {key}: missing (required without databases)")
    if ("policy" in data) != ("governance" in data):
        have, lack = ("policy", "governance") if "policy" in data else ("governance", "policy")
        out.append(f"{label}: {have}: without {lack}: a domain's default policy comes with "
                   "its governance fragment, both or neither")
    _check_domain_part(domain_dir, data, label, out)
    tables, databases = _domain_tables(_domain_schema_files(domain_dir, data), label, out)
    for key in ("schema", "load", "classification", "register", "notes", "policy",
                "governance"):
        rel = data.get(key)
        if not isinstance(rel, str):
            continue                         # reported against the template
        path = _inside(domain_dir, rel)
        if path is None or not path.is_file():
            out.append(f"{_rel(domain_dir / rel, base)}: missing file ({label} {key})")
        elif key == "classification":
            check_classification(path, _rel(path, base), out, domain_databases=databases)
        elif key == "register":
            _check_register(path, _rel(path, base), tables, out)
        elif key == "governance":
            content = _load_yaml(path, _rel(path, base), out, strict=True)
            if content is not None and not isinstance(content, dict):
                out.append(f"{_rel(path, base)}: top level: not a mapping (a governance: "
                           "fragment)")
    producers = data.get("producers")
    if isinstance(producers, str):
        path = _inside(domain_dir, producers)
        if path is None or not path.is_dir():
            out.append(f"{_rel(domain_dir / producers, base)}/: missing folder "
                       f"({label} producers)")
        else:
            _check_producers(path, base, out)
    _check_variants(domain_dir, data, base, label, out)
    for path in _domain_sql_files(domain_dir, data):
        _check_security_definer(path, _rel(path, base), out)
    _check_part_sql(domain_dir, data, base, out)
    purposes = data.get("purposes")
    for pid in purposes if isinstance(purposes, list) else []:
        if not (isinstance(pid, str) and PURPOSE_ID_RE.match(pid)):
            out.append(f"{label}: purposes: {pid!r} is not a purpose id ([a-z][a-z0-9-]*)")
    return out


def check_purpose_dir(purpose_dir, label_base=None, catalog_root=None):
    """Missing items of a purpose folder (format skill, "Purpose folder";
    master spec 6.7, 8; W1 item 5). Its domains are looked up under
    `catalog_root`, by default the folder holding purposes/."""
    purpose_dir = Path(purpose_dir)
    base = Path(label_base) if label_base else purpose_dir.parent.parent
    catalog_root = Path(catalog_root) if catalog_root else purpose_dir.parent.parent
    label = _rel(purpose_dir / "purpose.yaml", base)
    out = []
    data = _load_yaml(purpose_dir / "purpose.yaml", label, out)
    if data is None:
        return out
    check_against_schema(data, template_schema("purpose.yaml"), label, out=out)
    placeholders(data, label, out=out)
    if not isinstance(data, dict):
        return out
    pid = purpose_dir.name
    if data.get("id") != pid:
        out.append(f"{label}: id: {data.get('id')} is not the folder name {pid}")
    if not PURPOSE_ID_RE.match(pid):
        out.append(f"{label}: id: {pid} is not a purpose id ([a-z][a-z0-9-]*)")
    if not (purpose_dir / "gm.md").is_file():
        out.append(f"{_rel(purpose_dir / 'gm.md', base)}: missing file")
    domains = data.get("domains")
    for did in domains if isinstance(domains, list) else []:
        domain_file = catalog_root / "domains" / str(did) / "domain.yaml"
        if not (isinstance(did, str) and PURPOSE_ID_RE.match(did)):
            out.append(f"{label}: domains: {did!r} is not a domain id ([a-z][a-z0-9-]*)")
        elif not domain_file.is_file():
            out.append(f"{label}: domains: {did} is not a domain (no domains/{did}/domain.yaml "
                       "in the catalog)")
        else:
            try:
                listed = _dict(yaml.safe_load(domain_file.read_text(encoding="utf-8")))
            except (yaml.YAMLError, UnicodeDecodeError):
                continue                     # reported with the domain
            if pid not in (listed.get("purposes") or []):
                out.append(f"{label}: domains: domain {did} does not list {pid} in its "
                           "domain.yaml purposes")
    if "kind" in data and data["kind"] not in PURPOSE_KINDS:
        out.append(f"{label}: kind: {data['kind']} is not one of {', '.join(PURPOSE_KINDS)} "
                   "(master spec 8.2)")
    parts = _dict(data.get("parts"))
    for part in parts:
        if part not in PURPOSE_PARTS:
            out.append(f"{label}: parts.{part}: not a part ({', '.join(PURPOSE_PARTS)})")
    databases = [p for p in DATABASE_PARTS if p in parts]
    jobs = [j for j in data.get("jobs") or [] if isinstance(j, dict)] \
        if isinstance(data.get("jobs"), list) else []
    names = []
    for i, job in enumerate(jobs):
        p = f"{label}: jobs[{_item_label(job, i)}]"
        if job.get("name") in names:
            out.append(f"{p}: duplicate job name")
        names.append(job.get("name"))
        if "part" in job and not (job["part"] == "runner" and "runner" in parts):
            out.append(f"{p}.part: {job['part']} is not a declared runner part (runner, the "
                       "only one in v0.4)")
        for key in DATABASE_PARTS:
            if key in job and job[key] not in databases:
                out.append(f"{p}.{key}: {job[key]} is not a declared database part "
                           f"({', '.join(databases)})")
        if "method" in job and job["method"] not in JOB_METHODS:
            out.append(f"{p}.method: {job['method']} is not one of {', '.join(JOB_METHODS)} "
                       "(master spec 8.6)")
        if "cadence" in job:
            problem = _cron_problem(job["cadence"])
            if problem:
                out.append(f"{p}.cadence: {problem}")
    trace = data.get("trace")
    for i, item in enumerate(trace if isinstance(trace, list) else []):
        if not isinstance(item, dict):
            continue
        p = f"{label}: trace[{i}]"
        if "kind" in item and item["kind"] not in TRACE_KINDS:
            out.append(f"{p}.kind: {item['kind']} is not one of {', '.join(TRACE_KINDS)} "
                       "(master spec 8.3)")
        if "part" in item and item["part"] not in parts:
            out.append(f"{p}.part: {item['part']} is not a declared part")
        if ("table" in item) == ("file" in item):
            out.append(f"{p}: exactly one of table and file (it has "
                       f"{'both' if 'table' in item else 'neither'})")
        if "run_column" in item and "table" not in item:
            out.append(f"{p}.run_column: only with table")
        if "file" in item:
            problem = _path_problem(item["file"])
            if problem:
                out.append(f"{p}.file: {problem}")
    invariants = data.get("invariants")
    ids = []
    for i, inv in enumerate(invariants if isinstance(invariants, list) else []):
        if not isinstance(inv, dict):
            continue
        iid = inv.get("id")
        p = f"{label}: invariants[{_item_label(inv, i)}]"
        if "id" in inv and not (isinstance(iid, str) and INVARIANT_ID_RE.match(iid)):
            out.append(f"{p}.id: {iid!r} is not [A-Z][0-9]+ (R1, L2)")
        elif iid in ids:
            out.append(f"{p}: duplicate invariant id")
        ids.append(iid)
        check = inv.get("check")
        if isinstance(check, str):
            path = _inside(purpose_dir, check)
            if path is None or not path.is_file() or not check.startswith("checks/"):
                out.append(f"{_rel(purpose_dir / check, base)}: missing file "
                           f"(invariants[{_item_label(inv, i)}].check, a file of checks/)")
    moved = data.get("data_moved")
    moved_jobs = []
    for i, entry in enumerate(moved if isinstance(moved, list) else []):
        if not isinstance(entry, dict):
            continue
        job = entry.get("job")
        p = f"{label}: data_moved[{job if isinstance(job, str) else i}]"
        if "job" in entry and job not in names:
            out.append(f"{p}.job: {job} is not a job of the purpose")
        elif job in moved_jobs:
            out.append(f"{p}: more than one entry for job {job}")
        moved_jobs.append(job)
        reads = entry.get("reads")
        for key in reads if isinstance(reads, list) else []:
            if not (isinstance(key, str) and CLASSIFICATION_KEY_RE.match(key)):
                out.append(f"{p}.reads: {key!r} is not a classification key "
                           "<database>.<table>.<column>")
        writes = entry.get("writes")
        for item in writes if isinstance(writes, list) else []:
            m = PART_TABLE_RE.match(item) if isinstance(item, str) else None
            if m is None:
                out.append(f"{p}.writes: {item!r} is not <part>:<table>")
            elif m.group(1) not in parts:
                out.append(f"{p}.writes: {item}: {m.group(1)} is not a declared part")
    for name in names:
        if isinstance(moved, list) and name not in moved_jobs:
            out.append(f"{label}: data_moved: no entry for job {name} (one entry per job)")
    roles = data.get("roles")
    for i, role in enumerate(roles if isinstance(roles, list) else []):
        if isinstance(role, dict) and "part" in role and role["part"] not in databases:
            out.append(f"{label}: roles[{_item_label(role, i)}].part: {role['part']} is not a "
                       f"declared database part ({', '.join(databases)})")
    _check_purpose_v05(purpose_dir, data, label, base, parts, jobs, out)
    return out


def _find_catalog_unit(kind, uid, catalog_root):
    """(data or None, problem or None, missing items) of a purpose or domain,
    looked up in the catalog only (W1 item 0)."""
    folder = "purposes" if kind == "purpose" else "domains"
    if not (isinstance(uid, str) and PURPOSE_ID_RE.match(uid)):
        return None, f"{uid!r} is not a {kind} id ([a-z][a-z0-9-]*)", []
    directory = Path(catalog_root) / folder / uid
    if not (directory / f"{kind}.yaml").is_file():
        return None, f"{kind} {uid} not found (looked in {folder}/{uid}/ of the catalog)", []
    if kind == "purpose":
        missing = check_purpose_dir(directory, Path(catalog_root), catalog_root)
    else:
        missing = check_domain_dir(directory, Path(catalog_root))
    if any("cannot be read" in m for m in missing):
        return None, None, missing
    data = yaml.safe_load((directory / f"{kind}.yaml").read_text(encoding="utf-8"))
    return (data if isinstance(data, dict) else None), None, missing


def _check_domain(data, catalog_root, out):
    """domain: names a domain of the catalog, which loads (master spec 6.1)."""
    if "domain" not in data or data["domain"] is None:
        return
    _, problem, missing = _find_catalog_unit("domain", data["domain"], catalog_root)
    out.extend(m for m in missing if m not in out)
    if problem:
        out.append(f"scenario.yaml: domain: {problem}")


AT_RE = re.compile(r"^([a-z]([a-z0-9-]{0,61}[a-z0-9])?)/([a-z_][a-z0-9_]*)$")
DOMAINS_ENTRY_KEYS = ("id", "variant", "at")


def _at_problem(value, by_name):
    """Why an at: value is not a database node's node/database, or None. Whether
    the scenario's data creates the database is the coherence check's (W2)."""
    m = AT_RE.match(value) if isinstance(value, str) else None
    if m is None:
        return f"{value!r} is not <node>/<database>"
    node = by_name.get(m.group(1))
    if node is None:
        return f"{value}: {m.group(1)} is not a node of the topology"
    if node.get("role") != "database":
        return f"{value}: {m.group(1)} is not a database node (role {node.get('role')})"
    return None


def check_domains_entries(data, catalog_root=REPO_ROOT, label="scenario.yaml"):
    """(domains by id, problems) of scenario.yaml's domains: (formats.md
    "Composing domains"; v0.5 master spec 6.2, 8.5; W1 items 2 and 7): each id
    a domain of the catalog, once; a part only with its core, no variant of its
    own, among its core variant's parts, beside its core when it lands_with
    it; a core's variant one of its manifests; at: a database node's
    node/database, a map of them for a part with databases. Each domain's
    own missing items are listed too. `domains` maps id -> (entry, domain.yaml)."""
    out = []
    nodes = [n for n in data.get("nodes") or [] if isinstance(n, dict)]
    by_name = {n.get("name"): n for n in nodes}
    domains = data.get("domains")
    if "domain" in data and data.get("domain") is not None:
        out.append(f"{label}: domain: and domains: both: a scenario lists domain: (one "
                   "domain) or domains:, never both")
    if not (isinstance(domains, list) and domains):
        out.append(f"{label}: domains: not a non-empty list of domains")
        return {}, out
    found = {}
    for i, entry in enumerate(domains):
        did = entry.get("id") if isinstance(entry, dict) else None
        p = f"{label}: domains[{did if isinstance(did, str) else i}]"
        if not isinstance(entry, dict):
            out.append(f"{p}: not a mapping (id, variant, at)")
            continue
        _unknown_keys(entry, DOMAINS_ENTRY_KEYS, p, "a domains: entry", out)
        for key in ("id", "at"):
            if key not in entry:
                out.append(f"{p}.{key}: missing")
        if did in found:
            out.append(f"{p}.id: {did} listed twice")
            continue
        if "id" not in entry:
            continue
        ddata, problem, missing = _find_catalog_unit("domain", did, catalog_root)
        out.extend(m for m in missing if m not in out)
        if problem:
            out.append(f"{p}.id: {problem}")
        elif ddata is not None:
            found[did] = (entry, ddata)
    for did, (entry, ddata) in found.items():
        p = f"{label}: domains[{did}]"
        requires = ddata.get("requires")
        core = requires[0] if isinstance(requires, list) and requires else None
        if "requires" in ddata:
            if "variant" in entry:
                out.append(f"{p}.variant: on a part: the variant is its core's entry's")
            if core not in found:
                out.append(f"{p}: part {did} without its core {core}: a part is taken only "
                           f"with its core (domains: lists {core} beside it)")
            else:
                core_entry = found[core][0]
                variant = core_entry.get("variant")
                manifest = _sibling_yaml(Path(catalog_root) / "domains" / str(core)
                                         / "variants" / f"{variant}.yaml")
                parts = manifest.get("parts") if manifest else None
                if variant is not None and isinstance(parts, list) and did not in parts:
                    out.append(f"{p}: not a part of {core}'s variant {variant} (its parts: "
                               f"{', '.join(map(str, parts)) or 'none'})")
                if "lands_with" in ddata and entry.get("at") != core_entry.get("at"):
                    out.append(f"{p}.at: {entry.get('at')}: {did} lands_with {core}, whose "
                               f"at: is {core_entry.get('at')}")
        else:
            variant = entry.get("variant")
            if "variant" not in entry:
                out.append(f"{p}.variant: missing (required on a core's entry)")
            elif not (Path(catalog_root) / "domains" / did / "variants"
                      / f"{variant}.yaml").is_file():
                out.append(f"{p}.variant: {variant!r} is not a variant of {did} "
                           f"(domains/{did}/variants/<variant>.yaml)")
        at = entry.get("at")
        databases = ddata.get("databases")
        if "at" not in entry:
            continue
        if isinstance(databases, list):
            if not (isinstance(at, dict) and set(at) == set(databases)):
                out.append(f"{p}.at: {at!r} is not a map from each of {did}'s databases "
                           f"({', '.join(map(str, databases))}) to <node>/<database>")
            for db, value in at.items() if isinstance(at, dict) else ():
                problem = _at_problem(value, by_name)
                if problem:
                    out.append(f"{p}.at.{db}: {problem}")
        else:
            problem = _at_problem(at, by_name)
            if problem:
                out.append(f"{p}.at: {problem}")
    return found, out


def check_composition(data, sdir, catalog_root=REPO_ROOT):
    """Problems of a scenario's domains: and its composition record (formats.md
    "Composing domains"; v0.5 master spec 8.5, 15; W1 item 7): composition.yaml
    required with domains:, refused without; its domains equal to
    scenario.yaml's (id, variant, at), lands_with exactly for a domain
    declaring it; order every id once, a part after its core, a derivation's
    domain after its after; derive only for a domain declaring it, its after
    the declared one; keys by listed parts; scale {checked, note}; left_out
    (v0.5 chunk 29's (b)) each a producer folder of a composed domain."""
    sdir = Path(sdir)
    path = sdir / "composition.yaml"
    rel = "composition.yaml"
    if "domains" not in data:
        return [f"{rel}: present without domains: in scenario.yaml (the composition record "
                "goes with domains:)"] if path.is_file() else []
    found, out = check_domains_entries(data, catalog_root)
    if not path.is_file():
        out.append(f"{rel}: missing file (the composition record, required with domains:)")
        return out
    content = _load_yaml(path, rel, out, strict=True)
    if content is None:
        return out
    check_against_schema(content, template_schema("composition.yaml"), rel, out=out)
    placeholders(content, rel, out=out)
    if not isinstance(content, dict):
        return out
    listed = [e for e in data.get("domains") or [] if isinstance(e, dict)]
    ids = [e.get("id") for e in listed]
    recorded = content.get("domains")
    if isinstance(recorded, list):
        rec_ids = [e.get("id") if isinstance(e, dict) else None for e in recorded]
        if rec_ids != ids:
            out.append(f"{rel}: domains: {rec_ids} are not scenario.yaml's domains: {ids}, "
                       "in its order")
        for entry, rec in zip(listed, recorded):
            if not isinstance(rec, dict) or rec.get("id") != entry.get("id"):
                continue
            p = f"{rel}: domains[{rec.get('id')}]"
            _unknown_keys(rec, DOMAINS_ENTRY_KEYS + ("lands_with",), p,
                          "a composition domains: entry", out)
            for key in ("variant", "at"):
                if rec.get(key) != entry.get(key):
                    out.append(f"{p}.{key}: {rec.get(key)!r} is not scenario.yaml's "
                               f"{entry.get(key)!r}")
            declared = found.get(rec.get("id"), (None, {}))[1].get("lands_with")
            if rec.get("lands_with") != declared:
                out.append(f"{p}.lands_with: {rec.get('lands_with')!r}, but the domain "
                           f"declares {declared!r} (present exactly for a domain declaring it)")
    order = content.get("order")
    if isinstance(order, list):
        if sorted(map(str, order)) != sorted(map(str, ids)) or len(order) != len(set(order)):
            out.append(f"{rel}: order: {order} does not list every domain of domains: once")
        place = {d: i for i, d in enumerate(order)}
        for did, (_, ddata) in found.items():
            requires = ddata.get("requires")
            core = requires[0] if isinstance(requires, list) and requires else None
            if core in place and did in place and place[did] < place[core]:
                out.append(f"{rel}: order: part {did} before its core {core}")
    derive = content.get("derive")
    for i, step in enumerate(derive if isinstance(derive, list) else []):
        if not isinstance(step, dict):
            continue                         # reported against the template
        did = step.get("domain")
        p = f"{rel}: derive[{did if isinstance(did, str) else i}]"
        declared = found.get(did, (None, {}))[1].get("derive") if did in found else None
        if did not in found:
            out.append(f"{p}.domain: {did!r} is not a domain of domains:")
        elif not isinstance(declared, dict):
            out.append(f"{p}: {did} declares no derive (a derivation only for a domain "
                       "shipping data/derive.sql)")
        elif sorted(map(str, step.get("after") or [])) != sorted(map(str, declared.get("after")
                                                                     or [])):
            out.append(f"{p}.after: {step.get('after')} is not {did}'s declared "
                       f"{declared.get('after')}")
        after = step.get("after") if isinstance(step.get("after"), list) else []
        for other in after:
            if other not in found:
                out.append(f"{p}.after: {other!r} is not a domain of domains:")
            elif isinstance(order, list) and other in order and did in order \
                    and order.index(did) < order.index(other):
                out.append(f"{rel}: order: {did}'s derivation before {other}, whose load it "
                           "reads")
    keys = content.get("keys")
    for part, names in keys.items() if isinstance(keys, dict) else ():
        p = f"{rel}: keys.{part}"
        if part not in found or "requires" not in found[part][1]:
            out.append(f"{p}: not a part of domains:")
        if not (isinstance(names, list) and names and all(isinstance(n, str) for n in names)):
            out.append(f"{p}: not a non-empty list of the core's range and function names")
    scale = content.get("scale")
    if isinstance(scale, dict):
        _unknown_keys(scale, ("checked", "note"), f"{rel}: scale", "scale", out)
        if "checked" in scale and not isinstance(scale["checked"], bool):
            out.append(f"{rel}: scale.checked: {scale['checked']!r} is not true or false")
    check_left_out(content, found, catalog_root, rel, out)
    return out


def _check_composition(data, sdir, catalog_root, out):
    out.extend(m for m in check_composition(data, sdir, catalog_root) if m not in out)


def _check_purposes(data, by_name, creates, sdir, catalog_root, out):
    """purposes: each a purpose of the catalog, its parts mapped exactly, to
    nodes of the right role and locations, and every job of the purpose on
    the runner node (master spec 6.1, 6.9; W1 item 1)."""
    label = "scenario.yaml"
    entries = data.get("purposes")
    seen = []
    for i, entry in enumerate(entries if isinstance(entries, list) else []):
        if not isinstance(entry, dict):
            continue
        pid = entry.get("id")
        p = f"{label}: purposes[{_item_label(entry, i)}]"
        if pid in seen:
            out.append(f"{p}: purpose {pid} listed more than once")
            continue
        seen.append(pid)
        purpose, problem, missing = _find_catalog_unit("purpose", pid, catalog_root)
        out.extend(m for m in missing if m not in out)
        if problem:
            out.append(f"{p}.id: {problem}")
        if purpose is None:
            continue
        declared = [k for k in _dict(purpose.get("parts")) if k in PURPOSE_PARTS]
        parts = entry.get("parts")
        if not isinstance(parts, dict):
            continue                         # reported against the template
        for part in declared:
            if part not in parts:
                out.append(f"{p}.parts.{part}: missing (purpose {pid} declares it)")
        for part, value in parts.items():
            if part not in declared:
                out.append(f"{p}.parts.{part}: not a part purpose {pid} declares "
                           f"({', '.join(declared)})")
            elif part in DATABASE_PARTS:
                problem = _location_problem(value, by_name, creates)
                if problem:
                    out.append(f"{p}.parts.{part}: {problem}")
            elif value not in by_name:
                out.append(f"{p}.parts.{part}: {value} is not a node")
            elif part in THIRD_PARTY_PARTS and (part == "partner" or _v05_shaped(data)):
                if value not in _third_party_nodes(data):
                    out.append(f"{p}.parts.{part}: {value} is not a node a third_parties: entry "
                               "lists (from v0.5 a receiver and a partner are declared third "
                               "parties; master spec 12.1)")
            elif by_name[value].get("role") != PART_ROLES[part]:
                out.append(f"{p}.parts.{part}: {value} is not a node of role {PART_ROLES[part]} "
                           f"(its role is {by_name[value].get('role')})")
        placed = domain_locations(data)
        for part, _ in purpose_ddl(purpose):
            if part in parts and parts[part] not in placed:
                out.append(f"{p}.parts.{part}: {parts[part]}: purpose {pid}'s ddl.{part} runs "
                           "only in a database a domains: entry's at: holds; for a database no "
                           "domain holds, its DDL stays in the node's data file (capture W3 "
                           "addendum, item 6 (e))")
        runner = by_name.get(parts.get("runner"))
        if runner is not None and runner.get("role") == PART_ROLES["runner"]:
            _check_purpose_jobs(purpose, pid, runner, sdir, f"{p}.parts.runner", out)
            _check_purpose_http(purpose, pid, runner, sdir, f"{p}.parts.runner", out)
        _check_purpose_ops(data, purpose, pid, parts, p, out)


def _check_purpose_jobs(purpose, pid, runner, sdir, p, out):
    """Every job of the purpose has an entry of that name and key in the
    runner's jobs.yaml (its key in queries.yaml: the jobs' own check)."""
    rel, path = _seed_path(runner, sdir, "jobs.yaml")
    name = runner.get("name")
    if path is None:
        out.append(f"{p}: {name} seeds no jobs.yaml to run purpose {pid}'s jobs")
        return
    try:
        content = yaml.safe_load(path.read_text(encoding="utf-8"))
    except (yaml.YAMLError, UnicodeDecodeError):
        return                               # reported with the scheduler's files
    jobs = {j.get("name"): j for j in _dict(content).get("jobs") or []
            if isinstance(j, dict)} if isinstance(_dict(content).get("jobs"), list) else {}
    for job in purpose.get("jobs") or []:
        if not isinstance(job, dict):
            continue
        jname, key = job.get("name"), job.get("key")
        if jname not in jobs:
            out.append(f"{p}: {name}'s jobs.yaml ({rel}) has no job {jname} (a job of purpose "
                       f"{pid})")
        elif jobs[jname].get("key") != key:
            out.append(f"{p}: {name}'s jobs.yaml ({rel}): job {jname} has key "
                       f"{jobs[jname].get('key')}, but purpose {pid}'s job {jname} has key {key}")


def _check_governance(data, nodes, by_name, creates, sdir, out):
    """governance: its files, its classes both ways, their locations,
    readers and outbound flows (master spec 6.1, 6.9, 11.3, 11.4; W1 item
    1); and the bastion's data-policy.md mapped to its policy, none without
    governance: (spec D223)."""
    label = "scenario.yaml"
    gov = data.get("governance")
    policy = _dict(gov).get("policy")
    for node in nodes:
        if node.get("role") != "bastion":
            continue
        mapped = _dict(node.get("seed_files")).get(POLICY_SEED_FILE)
        p = f"{label}: nodes[{node.get('name')}].seed_files.{POLICY_SEED_FILE}"
        if not isinstance(gov, dict):
            if POLICY_SEED_FILE in _dict(node.get("seed_files")):
                out.append(f"{p}: a scenario without governance: hands the players no data "
                           "policy, so its bastion maps none (spec D223)")
        elif mapped is None:
            out.append(f"{p}: missing (a scenario with governance: maps the bastion's "
                       f"{POLICY_SEED_FILE} to governance.policy {policy}; spec D223)")
        elif isinstance(policy, str) and mapped != policy:
            out.append(f"{p}: {mapped}, not governance.policy {policy} (spec D223)")
    if not isinstance(gov, dict):
        return
    used = None
    for key in ("policy", "classification"):
        rel = gov.get(key)
        if not isinstance(rel, str):
            continue                         # reported against the template
        path = _inside(sdir, rel)
        if path is None or not path.is_file():
            out.append(f"{rel}: missing file ({label} governance.{key})")
        elif key == "classification":
            used = check_classification(path, rel, out)
    classes = gov.get("classes")
    if not isinstance(classes, dict):
        return                               # reported against the template
    for cls in sorted(used or ()):
        if cls != UNRESTRICTED_CLASS and cls not in classes:
            out.append(f"{label}: governance.classes: no entry for class {cls}, which "
                       f"{gov['classification']} uses (master spec 6.1)")
    roles = set().union(*(c.roles for c in creates.values())) if creates else set()
    for cls, rules in classes.items():
        p = f"{label}: governance.classes.{cls}"
        if cls not in CLASSES:
            out.append(f"{p}: {cls} is not a class ({', '.join(CLASSES)}; master spec 11.2)")
        if not isinstance(rules, dict):
            continue                         # reported against the template
        _check_class_rules(rules, p, by_name, creates, roles, out)


def _check_class_rules(rules, p, by_name, creates, roles, out):
    locations = rules.get("locations")
    unrestricted = locations == "any"
    if unrestricted:
        for key in ("readers", "outbound", "separation"):
            if key in rules:
                out.append(f"{p}.{key}: refused with locations: any (the class is not "
                           "restricted)")
    elif isinstance(locations, list) and locations:
        for value in locations:
            problem = _location_problem(value, by_name, creates)
            if problem:
                out.append(f"{p}.locations: {problem}")
        if "readers" not in rules:
            out.append(f"{p}.readers: missing (required unless locations is any; may be [])")
    elif "locations" in rules and locations is not None and locations != []:
        out.append(f"{p}.locations: {locations!r} is not a non-empty list of locations "
                   "<node>/<database> or the word any")
    if "separation" in rules and rules["separation"] != "instance":
        out.append(f"{p}.separation: {rules['separation']!r} is not instance (the only "
                   "separation; master spec 11.4)")
    readers = rules.get("readers")
    if "readers" in rules and not isinstance(readers, list):
        out.append(f"{p}.readers: not a list of roles")
    for role in readers if isinstance(readers, list) and not unrestricted else []:
        if role in RESERVED_DB_ROLES:
            out.append(f"{p}.readers: {role} is one of the game's own roles, never a reader")
        elif role not in roles:
            out.append(f"{p}.readers: {role} is not a role a data file of the scenario creates "
                       f"(CREATE ROLE {role})")
    outbound = rules.get("outbound")
    if "outbound" in rules and not isinstance(outbound, list):
        out.append(f"{p}.outbound: not a list of flows")
    labels = []
    for i, flow in enumerate(outbound if isinstance(outbound, list) and not unrestricted
                             else []):
        if not isinstance(flow, dict):
            continue
        to = flow.get("to")
        fp = f"{p}.outbound[{to if isinstance(to, str) else i}]"
        if "to" in flow and not (isinstance(to, str) and RECEIVER_LABEL_RE.match(to)):
            out.append(f"{fp}.to: {to!r} is not a receiver's label ([a-z][a-z0-9-]*)")
        elif to in labels:
            out.append(f"{fp}.to: {to} receives the class more than once")
        labels.append(to)
        outbox = flow.get("outbox")
        if "outbox" in flow:
            location, sep, table = outbox.rpartition("/") if isinstance(outbox, str) \
                else ("", "", "")
            problem = None if sep and SQL_NAME_RE.match(table) and "/" in location \
                else f"{outbox!r} is not <node>/<database>/<table>"
            problem = problem or _location_problem(location, by_name, creates)
            if problem:
                out.append(f"{fp}.outbox: {problem}")


def _check_crontabs(nodes, creates, sdir, out):
    """A seeded crontab and its crontab_roles (master spec 6.1, 7.2; W1
    items 0, 1 and 8): crontab_roles exactly on a node seeding a crontab,
    each a customer role the node's own data file creates; each entry's
    times in the cron subset render can shift, no @ form."""
    label = "scenario.yaml"
    for node in nodes:
        name = node.get("name")
        p = f"{label}: nodes[{name}].crontab_roles"
        seeds = "crontab" in _dict(node.get("seed_files"))
        if "crontab_roles" in node and not seeds:
            out.append(f"{p}: the node seeds no crontab (no crontab in its seed_files), so it "
                       "names no crontab role (master spec 6.1)")
        elif seeds and "crontab_roles" not in node:
            out.append(f"{p}: missing (the node seeds a crontab: the customer roles it connects "
                       "as, may be []; master spec 6.1, 7.2)")
        roles = node.get("crontab_roles")
        if "crontab_roles" in node and not isinstance(roles, list):
            out.append(f"{p}: not a list of roles")
        created = creates.get(name)
        seen = []
        for role in roles if isinstance(roles, list) and seeds else []:
            if not (isinstance(role, str) and DB_ROLE_RE.match(role)):
                out.append(f"{p}: {role!r} is not a role name ([a-z_][a-z0-9_]{{0,40}})")
                continue
            if role in seen:
                out.append(f"{p}: {role} listed more than once")
            seen.append(role)
            if role in RESERVED_DB_ROLES or role.startswith("pg_"):
                out.append(f"{p}: {role} is reserved ({', '.join(RESERVED_DB_ROLES)}, pg_*); a "
                           "crontab connects as a customer role")
            elif created is None or role not in created.roles:
                where = f"its data file ({created.file})" if created else "it has no data file"
                if created is not None and created.sources != [created.file]:
                    where = f"read: {', '.join(created.sources)}"
                out.append(f"{p}: {role} is not a role node {name}'s own data file creates "
                           f"({where}; CREATE ROLE {role})")
        rel, path = _seed_path(node, sdir, "crontab")
        if path is not None:
            _check_crontab_entries(rel, path, out)


def _check_crontab_entries(rel, path, out):
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        out.append(f"{rel}: cannot be read: {exc}")
        return
    for number, line in enumerate(text.splitlines(), 1):
        entry = line.strip()
        if not entry or entry.startswith("#") or re.match(r"[A-Za-z_][A-Za-z0-9_]*\s*=", entry):
            continue                         # blank, comment, environment setting
        if entry.startswith("@"):
            out.append(f"{rel}: line {number}: {entry.split()[0]}: no @ form in a crontab; five "
                       "time fields render can shift (v0.4 capture W1 item 0)")
            continue
        fields = entry.split(None, 5)
        if len(fields) < 6:
            out.append(f"{rel}: line {number}: not a crontab entry (five time fields, then the "
                       "command)")
            continue
        problem = _cron_problem(" ".join(fields[:5]))
        if problem:
            out.append(f"{rel}: line {number}: {problem}")


def _conf_text_value(value):
    """A postgresql.conf value without its quotes."""
    value = (value or "").strip()
    if len(value) >= 2 and value[0] == value[-1] == "'":
        value = value[1:-1].replace("''", "'")
    return value


def _check_pg_cron(nodes, creates, sdir, out):
    """A data file creating pg_cron belongs to a node whose seed
    postgresql.conf preloads it, and cron.database_name names a database
    that data file creates (master spec 7.2; W1 item 0)."""
    for node in nodes:
        name = node.get("name")
        created = creates.get(name)
        if created is None or not created.pg_cron:
            continue
        rel, path = _seed_path(node, sdir, "postgresql.conf")
        if path is None:
            out.append(f"{created.file}: creates the extension pg_cron, but node {name} seeds no "
                       "postgresql.conf to preload it (master spec 7.2)")
            continue
        settings = read_conf_settings(path.read_text(encoding="utf-8"))
        preload = [lib.strip() for lib in
                   _conf_text_value(settings.get("shared_preload_libraries")).split(",")]
        if "pg_cron" not in preload:
            out.append(f"{created.file}: creates the extension pg_cron, but node {name}'s seed "
                       f"postgresql.conf ({rel}) does not preload it (shared_preload_libraries; "
                       "master spec 7.2)")
        database = _conf_text_value(settings.get("cron.database_name"))
        if "cron.database_name" not in settings:
            out.append(f"{rel}: cron.database_name: missing (node {name}'s data file creates "
                       "pg_cron; it names a database that data file creates, master spec 7.2)")
        elif database not in created.databases:
            out.append(f"{rel}: cron.database_name: {database} is not a database node {name}'s "
                       f"data file ({created.file}) creates (master spec 7.2)")


def _check_v04(data, nodes, creates, sdir, catalog_root, out):
    """v0.4's scenario keys: domain:, purposes:, governance:, crontab_roles,
    and a data file's pg_cron. `creates`: node_creates of each node (v0.5 W2
    item 1); pg_cron reads the node's own data file."""
    by_name = {n.get("name"): n for n in nodes}
    _check_domain(data, catalog_root, out)
    _check_purposes(data, by_name, creates, sdir, catalog_root, out)
    _check_governance(data, nodes, by_name, creates, sdir, out)
    _check_crontabs(nodes, creates, sdir, out)
    _check_pg_cron(nodes, _data_files(nodes, sdir), sdir, out)


# --- The scheduler's files (master spec 7.1; capture W1 of v0.3, item 7) ---

SCHEDULER_FILES = ("queries.yaml", "schedule.yaml", "jobs.yaml")
QUERY_KEY_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
ISOLATION_LEVELS = ("read committed", "repeatable read", "serializable")
GENERATORS = ("int", "decimal", "choice", "sequence", "now")
DRIVERS = ("sql/postgresql", "http")      # http: v0.5 capture W1 item 3
TARGET_RE = re.compile(r"^([a-z]([a-z0-9-]{0,61}[a-z0-9])?):([0-9]+)/([A-Za-z_][A-Za-z0-9_$-]*)$")
DB_ROLE_RE = re.compile(r"^[a-z_][a-z0-9_]{0,40}$")
RESERVED_DB_ROLES = ("postgres", "dba", "monitoring", "gm_check", "pgbouncer_lookup",
                     "replicator")    # replicator: the standby's (v0.5 W1 items 0, 6; D350)
RATE_RE = re.compile(r"^([0-9]+(?:\.[0-9]+)?)/(s|min|h)$")
ARRIVALS = ("poisson", "even")
BUILDER_RE = re.compile(r"^builders/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
SCRIPT_RE = re.compile(r"^scripts/([A-Za-z0-9_][A-Za-z0-9_.-]*):([A-Za-z_][A-Za-z0-9_]*)$")
SCRIPT_CONNECTION_RE = re.compile(r"^[a-z][a-z0-9_]*$")   # a script's connection names (W1 item 7)
WEEKDAYS = ("mon", "tue", "wed", "thu", "fri", "sat", "sun")
HOURS_RE = re.compile(r"^([0-9]{2})(?:-([0-9]{2}))?$")
DAYS_RE = re.compile(r"^([a-z]{3})(?:-([a-z]{3}))?$")
SCHEDULE_KEYS = ("intensity", "connections", "streams", "shapes", "timeline")
CONNECTION_KEYS = ("driver", "target", "role", "pool")
STREAM_KEYS = ("key", "connection", "rate", "arrivals", "shape", "concurrency")
CHANGE_KEYS = ("at", "stream", "set")
SET_KEYS = ("key", "rate", "connection")
JOB_KEYS = ("name", "key", "connection", "connections", "at", "timezone_offset")


def _check_scheduler_files(data, nodes, faults, minimum, sdir, out, http=None):
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
        scripts = _dict(node.get("seed_files")).get("scripts/")
        folder = _inside(sdir, scripts) if isinstance(scripts, str) else None
        scripts = (str(scripts).rstrip("/"), folder) if folder is not None and folder.is_dir() \
            else None
        keys = None
        script_keys = set()
        if loaded.get("queries.yaml", (None, None))[1] is not None:
            keys = _check_queries(*loaded["queries.yaml"], builders, out, scripts)
            script_keys = _script_keys(loaded["queries.yaml"][1])
        connections = None
        if loaded.get("schedule.yaml", (None, None))[1] is not None:
            connections = _check_schedule(*loaded["schedule.yaml"], keys, names, data, minimum,
                                          out, script_keys, http)
        if loaded.get("jobs.yaml", (None, None))[1] is not None:
            _check_jobs(*loaded["jobs.yaml"], keys, connections, node, data, faults, out,
                        script_keys)
        _check_drivers(loaded, out)


def _script_keys(content):
    """The keys of a repository's script entries (master spec 7.1)."""
    queries = _dict(_dict(content).get("queries"))
    return {k for k, v in queries.items() if isinstance(v, dict) and "script" in v}


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


def _check_queries(rel, content, builders, out, scripts=None):
    """The query repository; returns its keys, or None when unusable.
    `builders` and `scripts`: (shown path, folder) of the node's seed
    folders, or None."""
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
        elif isinstance(value, dict) and "call" in value:
            _check_call(value, p, builders, out)
        elif isinstance(value, dict) and "builder" in value:
            _check_builder(value, p, builders, out)
        elif isinstance(value, dict) and "script" in value:
            _check_builder(value, p, scripts, out, kind="script")
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
            out.append(f"{p}: not a query (sql), a pool (a list of queries), a sequence "
                       "(steps), a builder (builder), a script (script) or a call (call)")
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
    """{int: [lo, hi]}, {decimal: [lo, hi, places]}, {choice: [..]} or the
    weighted {choice: {value: weight, ..}} (v0.5 W1 item 3), {sequence:
    [start, step]}, {now: utc} (W1 item 7)."""
    if not (isinstance(generator, dict) and len(generator) == 1
            and next(iter(generator)) in GENERATORS):
        out.append(f"{p}: {generator!r} is not a generator ({{int: [lo, hi]}}, {{decimal: [lo, "
                   "hi, places]}}, {choice: [..]}, {choice: {value: weight}}, {sequence: [start, "
                   "step]}, {now: utc})")
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
    elif kind == "choice" and isinstance(args, dict):
        ok = bool(args) and all(_is_int(w) and w >= 1 for w in args.values())
        form = ("a weighted choice: a non-empty map of values to weights, each a whole number "
                "at least 1 (relative, not summing to 100; v0.5 W1 item 3)")
    elif kind == "choice":
        ok = isinstance(args, list) and bool(args) \
            and not any(isinstance(a, (list, dict)) for a in args)
        form = "a non-empty list of values, or a map of values to weights"
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


def _check_builder(value, p, folder_info, out, kind="builder"):
    """builders/<file>:<function> (a builder) or scripts/<file>:<function>
    (a transformer script, master spec 7.1): a file of the node's seed folder
    of that name defining the function at its top level."""
    folder_name = "builders" if kind == "builder" else "scripts"
    _unknown_keys(value, (kind, "options"), p, f"a {kind}", out)
    if "options" in value and not isinstance(value["options"], dict):
        out.append(f"{p}.options: not a map")
    ref = value.get(kind)
    m = (BUILDER_RE if kind == "builder" else SCRIPT_RE).match(ref) \
        if isinstance(ref, str) else None
    if m is None:
        out.append(f"{p}.{kind}: {ref!r} is not {folder_name}/<file>:<function>")
        return
    fname, function = m.groups()
    if folder_info is None:
        out.append(f"{p}.{kind}: {ref}, but the node has no {folder_name}/ seed folder")
        return
    rel, folder = folder_info
    path = folder / fname
    if not path.is_file():
        out.append(f"{p}.{kind}: {ref}: {rel}/{fname} does not exist")
        return
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except (SyntaxError, UnicodeDecodeError, ValueError) as exc:
        out.append(f"{rel}/{fname}: cannot be parsed as Python: {' '.join(str(exc).split())}")
        return
    if not any(isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef)) and n.name == function
               for n in tree.body):
        out.append(f"{p}.{kind}: {ref}: {rel}/{fname} defines no function {function} at its "
                   "top level")


def _check_rate(rate, p, out):
    m = RATE_RE.match(rate) if isinstance(rate, str) else None
    if m is None or float(m.group(1)) <= 0:
        out.append(f"{p}: {rate!r} is not a rate (<number>/s, /min or /h, positive)")


def _check_schedule(rel, content, keys, names, data, minimum, out, script_keys=(), http=None):
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
        _check_connection(conn, f"{rel}: connections.{name}", names, out, http)
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
        if key in script_keys:
            out.append(f"{p}.key: {key} is a script key, which runs only as a job (jobs.yaml; "
                       "master spec 7.1)")
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
                          minimum, out, script_keys)
    return set(connections)


def _check_key_ref(key, keys, p, out):
    if keys is not None and key is not None and key not in keys:
        out.append(f"{p}: {key} is not a key of the node's queries.yaml")


def _check_connection(conn, p, names, out, http=None):
    if not isinstance(conn, dict):
        return                               # reported against the template
    if conn.get("driver") == "http":
        _check_http_connection(conn, p, http or HttpContext(set(names or ())), out)
        return
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
    if "role" not in conn and conn.get("driver") == "sql/postgresql":
        out.append(f"{p}.role: missing (an sql/postgresql connection's role)")
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


def _check_change(change, p, keys, connections, streams, data, minimum, out, script_keys=()):
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
    if values.get("key") in script_keys:
        out.append(f"{p}.set.key: {values['key']} is a script key, which runs only as a job (a "
                   "timeline change would make it a stream's; master spec 7.1)")
    if "rate" in values:
        _check_rate(values["rate"], f"{p}.set.rate", out)
    if "connection" in values and values["connection"] not in connections:
        out.append(f"{p}.set.connection: {values['connection']} is not a connection of the "
                   "schedule")


def _check_job_connections(job, p, keys, connections, script_keys, out):
    """Exactly one of connection: (every job but a script key's) and
    connections: (a script key's job: script name -> a connection of the
    schedule); master spec 7.1, W1 item 7."""
    key = job.get("key")
    if keys is None or key not in keys:
        if ("connection" in job) == ("connections" in job):
            out.append(f"{p}: exactly one of connection: and connections: (connections: for a "
                       "script key's job only)")
    elif key in script_keys:
        if "connection" in job:
            out.append(f"{p}.connection: {key} is a script key, whose job names connections: "
                       "instead (master spec 7.1)")
        if "connections" not in job:
            out.append(f"{p}.connections: missing (the job of script key {key} names each of "
                       "the script's connections; master spec 7.1)")
    else:
        if "connections" in job:
            out.append(f"{p}.connections: only a script key's job names connections: ({key} is "
                       "not a script key); it names one connection:")
        if "connection" not in job:
            out.append(f"{p}.connection: missing (every job but a script key's names one "
                       "connection of the schedule)")
    if connections is not None and "connection" in job \
            and job["connection"] not in connections:
        out.append(f"{p}.connection: {job['connection']} is not a connection of the node's "
                   "schedule.yaml")
    conns = job.get("connections")
    if "connections" in job and not (isinstance(conns, dict) and conns):
        out.append(f"{p}.connections: not a non-empty map of the script's connection name -> a "
                   "connection of the schedule")
    for name, conn in conns.items() if isinstance(conns, dict) else ():
        if not (isinstance(name, str) and SCRIPT_CONNECTION_RE.match(name)):
            out.append(f"{p}.connections.{name}: {name!r} is not a script's connection name "
                       "([a-z][a-z0-9_]*)")
        if connections is not None and conn not in connections:
            out.append(f"{p}.connections.{name}: {conn} is not a connection of the node's "
                       "schedule.yaml")


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


def _cron_hour_ok(hour):
    """An hour field render can shift (v0.4 capture W1 item 0, spec D219):
    *, or a comma list of n, a-b (a <= b), */s or a-b/s (s >= 1), 0 to 23."""
    if hour == "*":
        return True
    for item in hour.split(","):
        m = re.fullmatch(r"(?:\*|([0-9]+)-([0-9]+))/([0-9]+)|([0-9]+)-([0-9]+)|([0-9]+)", item)
        if m is None:
            return False
        a, b, step, c, d, n = m.groups()
        if step is not None and int(step) < 1:
            return False
        lo, hi = (a, b) if a is not None else (c, d) if c is not None else (n, n)
        if lo is not None and not 0 <= int(lo) <= int(hi) <= 23:
            return False
    return True


def _cron_problem(at):
    """Why a cron expression (a job's `at`, a crontab entry's times, a
    purpose job's cadence) is outside the subset render can shift (v0.3
    capture W1 item 7, widened by v0.4's item 0), or None."""
    if not isinstance(at, str):
        return f"{at!r} is not a quoted cron expression"
    fields = at.split()
    if len(fields) != 5:
        return f"{at!r} is not a 5-field cron expression"
    minute, hour, dom, month, dow = fields
    if not _cron_values(minute, 0, 59, True):
        return (f"{at!r}: minute {minute} is not a numeric cron form (*, 5, 0-30, */15, 1,31, "
                "0-30/10) within 0-59")
    if not _cron_hour_ok(hour):
        return (f"{at!r}: hour {hour} is not *, or a comma list of n, a-b, */s or a-b/s within "
                "0-23 (a <= b, never wrapping; s >= 1)")
    if dom != "*" or month != "*":
        return f"{at!r}: day of month and month are * (render shifts the hour only)"
    if dow != "*":
        if not _cron_values(dow, 0, 6, False):
            return f"{at!r}: day of week {dow} is not *, a number or a list of numbers (0-6)"
        if not re.fullmatch(r"[0-9]+", hour):
            return f"{at!r}: a day of week needs a single-number hour (it is {hour})"
    return None


def _check_jobs(rel, content, keys, connections, node, data, faults, out, script_keys=()):
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
        _check_job_connections(job, p, keys, connections, script_keys, out)
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


# --- v0.5: options, standbys, third parties, HTTP, api nodes (build plan chunk 6a;
# --- master spec 6.2 to 6.5, 7.1, 7.2, 10.2, 15; capture W1 items 0 to 6, W1-w to
# --- W1-z, W2 items 0 and 1; spec D350, D353, D354, D358, D360, D363) ---

MONITORING_OPTION = "monitoring"
OWNERS_HOST = "owners"              # the owners' browsers: a hostname, never a node or a party
PARTNERS_DATABASE = "partners"      # the partners' database (W2 item 0)
PARTNER_PREFIX_RE = re.compile(r"^[a-z][a-z0-9]{0,15}$")      # W2 item 0
THIRD_PARTY_NAME_RE = re.compile(r"^[a-z][a-z0-9-]*$")        # an id, a hostname (W1 item 2)
THIRD_PARTY_ROLES = ("inbound", "outbound", "round-trip")
API_BRICK = "api"
API_PORT = 8000                     # an api node's, and an alias's (W1 item 5)
HTTP_CREDENTIAL_RE = re.compile(r"^[a-z][a-z0-9_]{0,62}$")    # the scheduler's (W1-y)
PUBLIC_CREDENTIAL = "public"        # a purpose's value for a public endpoint, never a name (D354)
HTTP_TARGET_RE = re.compile(r"^([a-z0-9][a-z0-9.-]*):([0-9]{1,5})$")
HTTP_TIMEOUT_RE = re.compile(r"^([0-9]+)s$")
HTTP_CONNECTION_FORM = ("driver", "target", "credential", "pool", "timeout")
CALL_RE = re.compile(r"^(GET|POST|PUT|PATCH|DELETE) (/[\x21-\x7e]*)$")
PATH_NAME_RE = re.compile(r"%\(([A-Za-z_][A-Za-z0-9_]*)\)s")
PATH_PERCENT_RE = re.compile(r"%(?!\([A-Za-z_][A-Za-z0-9_]*\)s|[0-9A-Fa-f]{2})")
REPLICATION_HBA = ("host", "replication", "replicator", "samenet", "scram-sha-256")
GM_HBA_LINES = (("local", "all", "postgres", "peer"), ("local", "replication", "postgres", "peer"),
                ("local", "all", "gm_check", "scram-sha-256"), REPLICATION_HBA)
CLOSING_HBA = ("host", "all", "all", "all", "reject")
REGISTER_SEED_FILE = "data-register.md"   # the bastion's register handout (master spec 6.4)
REGISTER_DIFF_KEYS = ("entry", "field", "true", "handed_out")
# A monitoring brick's seed file naming the postgres nodes it reads (W2 items 1 and 5)
MONITOR_SEEDS = {"postgres-exporter": "exporter.conf", "pgwatch": "sources.yaml",
                 "health-check": "health.yaml"}


@dataclass
class ThirdParties:
    """What scenario.yaml's third_parties: declares (master spec 6.2, 10.2),
    with the partners' shared nodes serving the owners alone (spec D421)."""
    nodes: set = field(default_factory=set)        # every node an entry lists (+ D421's)
    hostnames: set = field(default_factory=set)    # of the entries listing nodes (the aliases)
    api_node: object = None                        # the partners' api node, when one
    db_node: object = None                         # the partners' postgres node, when one
    owners_alone: bool = False                     # api_node serves owners alone (D421)


# The partners' shared scheduler and api nodes when they serve the owners'
# route alone (spec D421): the build plan's names for chunk 11's nodes
# (partners/shared/nodes.yaml), found by name since no third_parties: entry
# lists them.
PARTNERS_BACKEND_NODE = "partners-backend"
PARTNERS_API_NODE = "partners-api"
OWNERS_ROUTE = "partners/owners"    # a domain's producers/partners/owners/ (spec D369)


@dataclass
class OwnersAlone:
    """The partners' shared nodes serving a composed domain's owners' route
    alone (spec D421): partners-backend its scheduler material, partners-api
    its endpoints. A node is None when it is not fit (missing, of another
    brick or not no-access); problems names each, as scenario.yaml's."""
    scheduler: object = None
    api: object = None
    routes: list = field(default_factory=list)     # the composed owners' folders, as shown
    problems: list = field(default_factory=list)


def node_brick_id(node):
    """A node's brick id: from the mapping the loader reads (`brick: {id:
    api, version: 0.1.0}`, _check_node), or from the `api@0.1.0` shorthand
    (compose's fixtures); None for neither."""
    brick = node.get("brick") if isinstance(node, dict) else None
    if isinstance(brick, dict):
        return brick.get("id") if isinstance(brick.get("id"), str) else None
    return brick.split("@", 1)[0] if isinstance(brick, str) else None


def _owners_routes(data, left_out, catalog_root):
    """The composed domains' owners' folders (domain and variant layers), as
    shown from the catalog, none composition.yaml's left_out: names."""
    domains = data.get("domains")
    entries = [e for e in domains if isinstance(e, dict)] if isinstance(domains, list) else []
    variants = {e.get("id"): e.get("variant") for e in entries}
    catalog = Path(catalog_root)
    routes = []
    for entry in entries:
        did = entry.get("id")
        if not (isinstance(did, str) and PURPOSE_ID_RE.match(did)) \
                or (did, OWNERS_ROUTE) in left_out:
            continue
        try:
            ddata = _dict(yaml.safe_load((catalog / "domains" / did / "domain.yaml")
                                         .read_text(encoding="utf-8")))
        except (OSError, UnicodeDecodeError, yaml.YAMLError):
            continue                         # reported by the domains: check
        requires = ddata.get("requires")
        core = requires[0] if isinstance(requires, list) and requires else did
        roots = [Path("domains") / did / "producers"]
        if isinstance(variants.get(core), str):
            roots.append(Path("domains") / did / "variants" / variants[core] / "producers")
        for root in roots:
            if (catalog / root / OWNERS_ROUTE).is_dir():
                routes.append(f"{(root / OWNERS_ROUTE).as_posix()}/")
    return routes


def owners_alone_nodes(data, left_out=frozenset(), catalog_root=REPO_ROOT):
    """The partners' shared nodes when the only partner material the
    scheduler and api nodes could carry is a composed domain's owners' route
    (spec D421; build plan chunk 31): with no third_parties: entry listing a
    scheduler or api node, and a composed domain's producers/partners/owners/
    (either layer, not left out), the no-access nodes partners-backend (a
    scheduler node) and partners-api (an api node). OwnersAlone, its problems
    naming a node missing, of another brick or not no-access; None in any
    other case (every rule as before). The one source of these nodes for
    compose and the loader; any other partner folder stays refused there."""
    data = _dict(data)
    nodes = data.get("nodes")
    by_name = {n.get("name"): n for n in nodes if isinstance(n, dict)} \
        if isinstance(nodes, list) else {}
    entries = data.get("third_parties")
    for entry in entries if isinstance(entries, list) else []:
        listed = _dict(entry).get("nodes")
        for name in listed if isinstance(listed, list) else []:
            if isinstance(name, str) and \
                    node_brick_id(by_name.get(name)) in (SCHEDULER_BRICK, API_BRICK):
                return None                  # the entries' shared nodes, as before
    routes = _owners_routes(data, left_out, catalog_root)
    if not routes:
        return None
    found = OwnersAlone(routes=routes)
    label = "scenario.yaml"
    why = (f"the owners' route ({', '.join(routes)}) goes onto the partners' shared nodes "
           f"{PARTNERS_BACKEND_NODE} and {PARTNERS_API_NODE}, as no third_parties: entry lists "
           "a scheduler or api node (spec D421)")
    for attr, name, brick in (("scheduler", PARTNERS_BACKEND_NODE, SCHEDULER_BRICK),
                              ("api", PARTNERS_API_NODE, API_BRICK)):
        node = by_name.get(name)
        if node is None:
            found.problems.append(f"{label}: nodes: no node {name}: {why}")
        elif node_brick_id(node) != brick:
            found.problems.append(f"{label}: nodes[{name}]: brick {node_brick_id(node)}, not "
                                  f"{brick}: {why}")
        elif node.get("write_policy") != "no-access":
            found.problems.append(f"{label}: nodes[{name}]: write_policy "
                                  f"{node.get('write_policy')}, not no-access: {why}, out of "
                                  "the players' reach (master spec 10.2)")
        else:
            setattr(found, attr, name)
    return found


@dataclass
class HttpContext:
    """What an HTTP connection's target may name (W2 item 1): a node, or an
    alias (an api node's host other than its name, or a third party's
    hostname on the partners' node); an api node or an alias on port 8000."""
    nodes: set
    aliases: set = field(default_factory=set)
    api_nodes: set = field(default_factory=set)
    third_party_nodes: set = field(default_factory=set)


def register_diff_true(item):
    """The true value of an answer key's register_diff item (master spec
    6.8): under the key PyYAML reads a bare `true:` as, boolean True, or
    under a quoted "true" (spec D353); None when it has neither. The one
    accessor every reader shares (chunks 17, 23)."""
    if not isinstance(item, dict):
        return None
    for key, value in item.items():
        if key is True:
            return value
    return item.get("true")


def _register_diff_keys(item):
    """An item's keys, the boolean True read as "true"."""
    return ["true" if key is True else key for key in item]


def _node_options(node):
    options = node.get("options")
    return [o for o in options if isinstance(o, str)] if isinstance(options, list) else []


def brick_options(brick_data):
    """The option names a brick declares (brick.yaml options:, master spec 6.5)."""
    options = brick_data.get("options")
    return [o.get("name") for o in options if isinstance(o, dict)] \
        if isinstance(options, list) else []


def _check_node_options(node, brick, p, out):
    """options: a non-empty list of unique names the brick declares (W1 item 2)."""
    label = "scenario.yaml"
    options = node.get("options")
    declared = brick_options(brick.data)
    if not (isinstance(options, list) and options):
        out.append(f"{label}: {p}.options: {options!r} is not a non-empty list of option names "
                   "(absent: no option; master spec 6.2)")
        return
    seen = []
    for option in options:
        if option in seen:
            out.append(f"{label}: {p}.options: {option} listed more than once")
            continue
        seen.append(option)
        if option not in declared:
            offers = f"it declares {', '.join(map(str, declared))}" if declared \
                else "it declares none"
            out.append(f"{label}: {p}.options: {option} is not an option of brick {brick.id} "
                       f"{brick.version} ({offers}; brick.yaml options:, master spec 6.5)")


def _check_fault_options(data, label, out):
    """requires_option and option_absent (master spec 6.4): option names,
    never both naming one option."""
    for key in ("requires_option", "option_absent"):
        if key in data and not (isinstance(data[key], str) and SQL_NAME_RE.match(data[key])):
            out.append(f"{label}: {key}: {data[key]!r} is not an option name")
    if "requires_option" in data and data.get("requires_option") == data.get("option_absent"):
        out.append(f"{label}: option_absent: {data['option_absent']} is also requires_option: a "
                   "fault needs an option or plants its absence, never both")


def _seed_yaml(node, sdir, fname):
    """A node's seed YAML file as loaded, or None (its problems are reported
    where the file is checked)."""
    rel, path = _seed_path(node, sdir, fname)
    if path is None:
        return None
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return None


def _check_third_parties(data, nodes, bricks, out, sdir=None, catalog_root=REPO_ROOT):
    """third_parties: (_listed_third_parties), and with no entry listing a
    scheduler or api node, the partners' shared nodes serving a composed
    domain's owners' route alone (owners_alone_nodes, spec D421): both among
    the third parties' nodes for every out-of-reach check, partners-api the
    partners' api node, serving exactly owners. Returns ThirdParties."""
    third = _listed_third_parties(data, nodes, bricks, out)
    owners = owners_alone_nodes(data, left_out_of(_composition_content(sdir)), catalog_root)
    if owners is not None:
        out.extend(owners.problems)
        third.nodes |= {n for n in (owners.scheduler, owners.api) if n is not None}
        if owners.api is not None:
            third.api_node, third.owners_alone = owners.api, True
    return third


def _listed_third_parties(data, nodes, bricks, out):
    """third_parties: (master spec 6.2, 10.2; W1 item 2, W2 items 0 and 1):
    ids and hostnames, each listed node a node with write_policy no-access
    (on a brick declaring it: the node's own check), one api node and one
    postgres node shared by every partner. Returns ThirdParties."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    third = ThirdParties()
    entries = data.get("third_parties")
    if entries is None:
        return third
    if not (isinstance(entries, list) and entries):
        out.append(f"{label}: third_parties: not a non-empty list of third parties (absent: "
                   "none)")
        return third
    ids, hosts, kinds = [], [], {}
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict):
            continue                         # reported against the template
        p = f"{label}: third_parties[{entry.get('id', i)}]"
        tid, host = entry.get("id"), entry.get("hostname")
        for key, value, seen in (("id", tid, ids), ("hostname", host, hosts)):
            if key not in entry:
                continue
            if not (isinstance(value, str) and THIRD_PARTY_NAME_RE.match(value)):
                out.append(f"{p}.{key}: {value!r} is not [a-z][a-z0-9-]*")
            elif value == OWNERS_HOST:
                out.append(f"{p}.{key}: {OWNERS_HOST} is reserved: the owners' browsers' "
                           "hostname, no third party (master spec 10.2, W2 item 0)")
            elif key == "hostname" and value in by_name:
                out.append(f"{p}.hostname: {value} is a node's name: an alias equal to a node "
                           "name would shadow it on the one network (W1 item 2)")
            elif value in seen:
                out.append(f"{p}.{key}: {value} is another third party's {key}")
            seen.append(value)
        if "role" in entry and entry["role"] not in THIRD_PARTY_ROLES:
            out.append(f"{p}.role: {entry['role']!r} is not one of {', '.join(THIRD_PARTY_ROLES)}")
        listed = entry.get("nodes")
        if "nodes" in entry and not (isinstance(listed, list)
                                     and all(isinstance(n, str) for n in listed)):
            out.append(f"{p}.nodes: not a list of node names (may be [])")
            continue
        for name in listed or []:
            node = by_name.get(name)
            if node is None:
                out.append(f"{p}.nodes: {name} is not a node")
                continue
            third.nodes.add(name)
            if node.get("write_policy") != "no-access":
                out.append(f"{p}.nodes: node {name} has write_policy "
                           f"{node.get('write_policy')}, not no-access: a third party's nodes "
                           "are out of the players' reach (master spec 10.2)")
            brick = bricks.get(name)
            if brick is not None:
                kinds.setdefault(brick.id, set()).add(name)
        if listed and isinstance(host, str):
            third.hostnames.add(host)
    for kind, attr in ((API_BRICK, "api_node"), (POSTGRES_BRICK, "db_node")):
        found = sorted(kinds.get(kind, ()))
        if len(found) > 1:
            out.append(f"{label}: third_parties: {len(found)} {kind} nodes ({', '.join(found)}): "
                       f"every partner shares one {kind} node (master spec 10.2)")
        elif found:
            setattr(third, attr, found[0])
    return third


def _api_files(nodes, bricks, sdir, out):
    """node name -> its seed api.yaml as loaded strictly (an api node,
    master spec 6.5, W1 item 5), for each api node whose file loads."""
    apis = {}
    for node in nodes:
        brick = bricks.get(node.get("name"))
        if brick is None or brick.id != API_BRICK:
            continue
        rel, path = _seed_path(node, sdir, "api.yaml")
        if path is None:
            continue                         # reported with the seed files
        content = _load_yaml(path, rel, out, strict=True)
        if content is None:
            continue
        if not isinstance(content, dict):
            out.append(f"{rel}: top level: not a mapping (endpoints, connections)")
            continue
        apis[node.get("name")] = (rel, content)
    return apis


def _api_hosts(content):
    hosts = []
    for entry in _dict(_dict(content).get("endpoints")).values():
        for host in _dict(entry).get("hosts") or []:
            if isinstance(host, str) and host not in hosts:
                hosts.append(host)
    return hosts


def _http_context(nodes, bricks, third, apis):
    names = {n.get("name") for n in nodes}
    aliases = set(third.hostnames)
    for name, (_, content) in apis.items():
        aliases.update(h for h in _api_hosts(content) if h != name)
    api_nodes = {n for n, b in bricks.items() if b.id == API_BRICK}
    return HttpContext(names, aliases - names, api_nodes, set(third.nodes))


def _http_target_problem(target, http):
    m = HTTP_TARGET_RE.match(target) if isinstance(target, str) else None
    if m is None:
        return f"{target!r} is not <host>:<port>"
    host, port = m.group(1), int(m.group(2))
    if not _is_port(port):
        return f"{target}: {port} is not a port"
    if host not in http.nodes and host not in http.aliases:
        return (f"{target}: {host} is neither a node of the topology nor an alias (a third "
                "party's hostname, or owners, on the partners' api node; W2 item 1)")
    if (host in http.api_nodes or host in http.aliases) and port != API_PORT:
        return f"{target}: {host} is an api node or an alias, which answers on port {API_PORT}"
    return None


def _credential_problem(credential):
    if not (isinstance(credential, str) and HTTP_CREDENTIAL_RE.match(credential)):
        return f"{credential!r} is not a credential name ([a-z][a-z0-9_]{{0,62}})"
    if credential == PUBLIC_CREDENTIAL:
        return (f"{PUBLIC_CREDENTIAL} is never a credential's name: an HTTP connection to a public "
                "endpoint has no credential (spec D354)")
    return None


def _check_http_connection(conn, p, http, out):
    """An http connection (W1 item 3; the scheduler's own refusals, W1-y):
    target <host>:<port>, optional credential, pool a positive integer,
    optional timeout <n>s, 1 to 60; no role."""
    if "role" in conn:
        out.append(f"{p}.role: an http connection has no role (its credential, if any; W1 "
                   "item 3)")
    _unknown_keys({k: v for k, v in conn.items() if k != "role"}, HTTP_CONNECTION_FORM, p,
                  "an http connection", out)
    if "target" in conn:
        problem = _http_target_problem(conn["target"], http)
        if problem:
            out.append(f"{p}.target: {problem}")
    if "credential" in conn:
        problem = _credential_problem(conn["credential"])
        if problem:
            out.append(f"{p}.credential: {problem}")
    if "pool" in conn and not (_is_int(conn["pool"]) and conn["pool"] > 0):
        out.append(f"{p}.pool: {conn['pool']!r} is not a positive integer (kept-alive "
                   "connections)")
    if "timeout" in conn:
        m = HTTP_TIMEOUT_RE.match(conn["timeout"]) if isinstance(conn["timeout"], str) else None
        if m is None or not 1 <= int(m.group(1)) <= 60:
            out.append(f"{p}.timeout: {conn['timeout']!r} is not <n>s, 1s to 60s")


def _check_call(value, p, builders, out):
    """A call (W1 item 3; the scheduler's CallEntry, W1-y): "<METHOD>
    <path>", its params generators holding every %(name)s of the path, and
    with a builder only those."""
    _unknown_keys(value, ("call", "params", "builder", "options"), p, "a call", out)
    call = value.get("call")
    m = CALL_RE.match(call) if isinstance(call, str) else None
    if m is None:
        out.append(f'{p}.call: {call!r} is not "<METHOD> <path>" (GET, POST, PUT, PATCH or '
                   "DELETE; the path absolute, without spaces)")
        return
    path = m.group(2)
    if "#" in path or PATH_PERCENT_RE.search(path):
        out.append(f"{p}.call: in the path, a % is %(name)s or a %XX escape, and no #")
    names = PATH_NAME_RE.findall(path)
    params = value.get("params", {})
    if not isinstance(params, dict):
        out.append(f"{p}.params: not a map of name -> generator")
        params = {}
    for name, generator in params.items():
        _check_generator(generator, f"{p}.params.{name}", out)
    for name in names:
        if name not in params:
            out.append(f"{p}.params: no parameter for the path's %({name})s")
    if "builder" in value:
        _check_builder({k: v for k, v in value.items() if k in ("builder", "options")}, p,
                       builders, out)
        extra = sorted(str(n) for n in params if n not in names)
        if extra:
            out.append(f"{p}.params: with a builder, params holds only the path's names, not "
                       f"{', '.join(extra)}")
    elif "options" in value:
        out.append(f"{p}.options: only with a builder")


def _check_drivers(loaded, out):
    """A call key runs on an http connection and every other key on a SQL
    one, in each stream and its timeline changes; a job's one connection:
    names no http connection and runs no call (the scheduler's
    driver_problems, W1-y)."""
    q_rel, queries = loaded.get("queries.yaml", (None, None))
    s_rel, schedule = loaded.get("schedule.yaml", (None, None))
    j_rel, jobs = loaded.get("jobs.yaml", (None, None))
    repo = _dict(_dict(queries).get("queries"))
    calls = {k for k, v in repo.items() if isinstance(v, dict) and "call" in v}
    conns = _dict(_dict(schedule).get("connections"))
    http = {n for n, c in conns.items() if _dict(c).get("driver") == "http"}
    streams = _dict(schedule).get("streams")
    timeline = _dict(schedule).get("timeline")
    changes = [c for c in timeline if isinstance(c, dict)] if isinstance(timeline, list) else []
    for stream in streams if isinstance(streams, list) else []:
        if not isinstance(stream, dict):
            continue
        initial = stream.get("key")
        sets = [_dict(c.get("set")) for c in changes if c.get("stream") == initial]
        keys = [initial] + [s["key"] for s in sets if "key" in s]
        names = [stream.get("connection")] + [s["connection"] for s in sets if "connection" in s]
        for key in dict.fromkeys(k for k in keys if k in repo):
            for name in dict.fromkeys(n for n in names if n in conns):
                if key in calls and name not in http:
                    out.append(f"{s_rel}: streams[{initial}]: key {key} is a call, but runs on "
                               f"connection {name}, which is not an http connection")
                elif key not in calls and name in http:
                    out.append(f"{s_rel}: streams[{initial}]: key {key} is not a call, but runs "
                               f"on connection {name}, an http connection")
    entries = _dict(jobs).get("jobs")
    for i, job in enumerate(entries if isinstance(entries, list) else []):
        if not isinstance(job, dict) or "connection" not in job:
            continue
        p = f"{j_rel}: jobs[{_item_label(job, i)}]"
        if job.get("key") in calls:
            out.append(f"{p}.key: {job['key']} is a call: a call runs only in a stream (W1-y)")
        elif job["connection"] in http:
            out.append(f"{p}.connection: {job['connection']} is an http connection: a job with "
                       "connection: runs SQL; an http connection is a stream's or a script's "
                       "(W1-y)")


def _hba_text_lines(node, sdir):
    rel, path = _seed_path(node, sdir, "pg_hba.conf")
    if path is None:
        return rel, None
    try:
        return rel, list(_hba_lines(path.read_text(encoding="utf-8")))
    except (OSError, UnicodeDecodeError):
        return rel, None


def _check_standbys(nodes, bricks, sdir, out):
    """standby_of (master spec 6.2, 7.1; W1 items 2 and 6): a postgres node
    whose primary is a postgres node that is no standby; no data: entry; the
    primary's seed pg_hba.conf carries the replication line."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    primaries = {}
    for node in nodes:
        if "standby_of" not in node:
            continue
        name, primary = node.get("name"), node.get("standby_of")
        p = f"{label}: nodes[{name}].standby_of"
        brick = bricks.get(name)
        if brick is not None and brick.id != POSTGRES_BRICK:
            out.append(f"{p}: node {name} runs {brick.id}: only a postgres node is a standby")
        if primary == name:
            out.append(f"{p}: names the node itself")
        elif primary not in by_name:
            out.append(f"{p}: {primary} is not a node")
        elif bricks.get(primary) is not None and bricks[primary].id != POSTGRES_BRICK:
            out.append(f"{p}: {primary} runs {bricks[primary].id}, not postgres")
        elif by_name[primary].get("standby_of") is not None:
            out.append(f"{p}: {primary} is itself a standby (standby_of "
                       f"{by_name[primary]['standby_of']}): a standby's primary is no standby")
        else:
            primaries.setdefault(primary, []).append(name)
        if "data" in node:
            out.append(f"{label}: nodes[{name}].data: a standby has no data: entry (cloned from "
                       "its primary after the load; W1 item 2)")
    for primary, standbys in primaries.items():
        rel, lines = _hba_text_lines(by_name[primary], sdir)
        if lines is not None and not any(tuple(f) == REPLICATION_HBA for _, f in lines):
            out.append(f"{rel}: no line {' '.join(REPLICATION_HBA)}: node {primary} is the "
                       f"primary of {', '.join(standbys)} and carries it under its DO NOT "
                       "TAMPER comment (W1 item 6, spec D350)")


def _uri_host(value):
    """The host of a libpq URI or of the exporter's host:port/db form."""
    text = value.strip().strip("'\"")
    for scheme in ("postgresql://", "postgres://"):
        if text.startswith(scheme):
            text = text[len(scheme):]
    text = text.rsplit("@", 1)[-1]
    return re.split(r"[:/?]", text, 1)[0]


def monitor_targets(node, brick, sdir):
    """The hosts a monitoring node's seed reads (W2 items 1 and 5):
    postgres-exporter's exporter.conf DATA_SOURCE_URI, pgwatch's sources.yaml
    (each entry with is_enabled: true, its conn_str, the URI form only;
    pgwatch 6.1.0 watches no other entry), health-check's
    health.yaml (instances[].host). [] for any other brick."""
    fname = MONITOR_SEEDS.get(brick.id)
    if fname is None:
        return []
    if brick.id == "postgres-exporter":
        rel, path = _seed_path(node, sdir, fname)
        if path is None:
            return []
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            return []
        hosts = []
        for line in text.splitlines():
            key, sep, value = line.strip().partition("=")
            if sep and key.strip() == "DATA_SOURCE_URI" and value.strip():
                hosts.append(_uri_host(value))
        return hosts
    content = _seed_yaml(node, sdir, fname)
    if brick.id == "pgwatch":
        entries = content if isinstance(content, list) else []
        return [_uri_host(e["conn_str"]) for e in entries
                if isinstance(e, dict) and e.get("is_enabled") is True
                and isinstance(e.get("conn_str"), str) and "://" in e["conn_str"]]
    instances = _dict(content).get("instances")
    return [i["host"] for i in instances if isinstance(i, dict) and isinstance(i.get("host"), str)] \
        if isinstance(instances, list) else []


def _check_monitors(data, nodes, bricks, faults, third, sdir, out):
    """A monitoring node's postgres targets choose monitoring, a monitored
    standby's primary too, unless a fault instance planting the option's
    absence has that node as its node; a third party's node is never a
    target (master spec 7.1 item 3, 7.4; W2 item 1)."""
    by_name = {n.get("name"): n for n in nodes}
    gaps = {i.get("node") for i in data.get("fault_instances") or []
            if isinstance(i, dict) and i.get("id") in faults
            and faults[i["id"]].data.get("option_absent") == MONITORING_OPTION}
    for node in nodes:
        name = node.get("name")
        brick = bricks.get(name)
        if brick is None or brick.id not in MONITOR_SEEDS:
            continue
        rel = _dict(node.get("seed_files")).get(MONITOR_SEEDS[brick.id])
        for host in dict.fromkeys(monitor_targets(node, brick, sdir)):
            target = by_name.get(host)
            if target is None:
                continue
            if host in third.nodes:
                out.append(f"{rel}: node {name} ({brick.id}) monitors {host}, a third party's "
                           "node: the partners' nodes are never monitored (master spec 7.4)")
                continue
            tbrick = bricks.get(host)
            if tbrick is None or tbrick.id != POSTGRES_BRICK:
                continue
            checked = [host]
            if target.get("standby_of") in by_name:
                checked.append(target["standby_of"])
            for need in checked:
                if MONITORING_OPTION in _node_options(by_name[need]) or need in gaps \
                        or (need != host and host in gaps):
                    continue
                why = "" if need == host else f", the primary of the standby {host} it monitors,"
                out.append(f"{rel}: node {name} ({brick.id}) monitors {host}, but node "
                           f"{need}{why} does not choose option {MONITORING_OPTION} "
                           f"(options: [{MONITORING_OPTION}]), and no fault instance planting "
                           f"its absence (option_absent: {MONITORING_OPTION}) targets it "
                           "(master spec 7.1 item 3)")


def _check_fault_instance_options(data, nodes, bricks, faults, out):
    """A fault requiring an option targets a node choosing it; one planting
    an option's absence, a node not choosing it; either option one the
    node's brick declares (master spec 6.4)."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    for inst in data.get("fault_instances") or []:
        if not isinstance(inst, dict) or inst.get("id") not in faults:
            continue
        fault = faults[inst["id"]]
        node = by_name.get(inst.get("node"))
        brick = bricks.get(inst.get("node"))
        if node is None or brick is None:
            continue
        p = f"{label}: fault_instances[{inst['id']}].node"
        for key in ("requires_option", "option_absent"):
            option = fault.data.get(key)
            if not isinstance(option, str):
                continue
            if option not in brick_options(brick.data):
                out.append(f"{p}: fault {fault.id} {'requires' if key == 'requires_option' else 'plants the absence of'} "
                           f"option {option}, which brick {brick.id} {brick.version} of node "
                           f"{node.get('name')} does not declare")
            elif key == "requires_option" and option not in _node_options(node):
                out.append(f"{p}: fault {fault.id} requires option {option}, which node "
                           f"{node.get('name')} does not choose (options:; master spec 6.4)")
            elif key == "option_absent" and option in _node_options(node):
                out.append(f"{p}: fault {fault.id} plants the absence of option {option}, which "
                           f"node {node.get('name')} chooses (options:; master spec 6.4)")


def _is_register_fault(fault_data):
    """A register fault: a seed-file change of the bastion's
    data-register.md (master spec 6.4)."""
    changes = _dict(fault_data.get("injection")).get("seed_changes")
    return any(isinstance(c, dict) and c.get("file") == REGISTER_SEED_FILE
               for c in changes if isinstance(changes, list)) if isinstance(changes, list) \
        else False


def _check_register_diff(entry, fault, out):
    """register_diff: (master spec 6.3, 6.8; spec D353): exactly on a register
    fault's instance, non-empty, each item entry, field, true and handed_out
    (true read by register_diff_true, never both forms in one item), or the
    one item {absent: true}."""
    p = f"gm/answer-key.yaml: instances[{entry.get('instance')}].register_diff"
    register = _is_register_fault(fault.data)
    if "register_diff" not in entry:
        if register:
            out.append(f"{p}: missing (fault {fault.id} is a register fault: the entry, the "
                       "field, the true value and the value handed out; master spec 6.3)")
        return
    if not register:
        out.append(f"{p}: fault {fault.id} is no register fault (a seed-file change of the "
                   f"bastion's {REGISTER_SEED_FILE}; master spec 6.4), so its instance takes no "
                   "register_diff")
    diff = entry["register_diff"]
    if not (isinstance(diff, list) and diff):
        out.append(f"{p}: not a non-empty list of items")
        return
    for i, item in enumerate(diff):
        ip = f"{p}[{i}]"
        if not isinstance(item, dict):
            out.append(f"{ip}: not a mapping (entry, field, true, handed_out; or absent: true)")
            continue
        keys = _register_diff_keys(item)
        if keys.count("true") > 1:
            out.append(f"{ip}: true twice, as YAML's boolean key and as \"true\": write one "
                       "(spec D353)")
        if "absent" in item:
            if item["absent"] is not True or len(item) > 1 or len(diff) > 1:
                out.append(f"{ip}: {{absent: true}} is the one item of a register left out, "
                           "alone in register_diff (master spec 6.3)")
            continue
        for key in REGISTER_DIFF_KEYS:
            if key not in keys:
                out.append(f"{ip}.{key}: missing")
        for key in keys:
            if key not in REGISTER_DIFF_KEYS:
                out.append(f"{ip}.{key}: not a key of a register_diff item "
                           f"({', '.join(REGISTER_DIFF_KEYS)}; or absent: true)")


def _check_api_nodes(nodes, bricks, third, apis, http, sdir, out):
    """An api node's api.yaml (master spec 6.5, 7.2; W1 item 5, W1-z, W2
    item 1; spec D345): the keys a fragment may hold (W1-w), at least one
    endpoint, each served by routes/<name>.py and db/<name>.py; its hosts:
    its own name on a node in the players' scope, on the partners' node the
    third parties' hostnames (plus owners) and never its own name, or
    exactly owners when it serves the owners alone (spec D421); its
    credentials named, never public; its connections a schedule's."""
    names = {n.get("name") for n in nodes}
    by_name = {n.get("name"): n for n in nodes}
    for name, (rel, content) in apis.items():
        node = by_name[name]
        _check_api_fragment(rel, content, out)
        for key in content:
            if key not in API_YAML_KEYS:
                out.append(f"{rel}: {key}: not a key of api.yaml ({', '.join(API_YAML_KEYS)})")
        endpoints = content.get("endpoints")
        if not (isinstance(endpoints, dict) and endpoints):
            out.append(f"{rel}: endpoints: not a non-empty mapping (a node's api.yaml serves at "
                       "least one endpoint)")
            endpoints = {}
        folders = {}
        for folder in API_FRAGMENT_FOLDERS:
            seed = _dict(node.get("seed_files")).get(folder + "/")
            path = _inside(sdir, seed) if isinstance(seed, str) else None
            folders[folder] = (str(seed).rstrip("/"), path)
        partners = name == third.api_node
        for ename, entry in endpoints.items():
            p = f"{rel}: endpoints.{ename}"
            if not isinstance(entry, dict):
                continue                     # reported by the fragment's check
            for folder, (shown, path) in folders.items():
                if path is None or not (path / f"{ename}.py").is_file():
                    where = f"{shown}/{ename}.py" if path is not None \
                        else f"{folder}/{ename}.py (the node seeds no {folder}/ folder)"
                    out.append(f"{p}: {where} does not exist (each endpoint is served by "
                               "routes/<name>.py and db/<name>.py; W1 item 5)")
            hosts = [h for h in entry.get("hosts") or [] if isinstance(h, str)] \
                if isinstance(entry.get("hosts"), list) else []
            if partners and name in hosts:
                out.append(f"{p}.hosts: {name} is the partners' node's own name: it answers "
                           "only under the third parties' hostnames and owners (W2 item 1)")
            elif not partners and hosts and hosts != [name]:
                out.append(f"{p}.hosts: {hosts}: a node in the players' scope answers under its "
                           f"own name only ([{name}]; W2 item 1)")
            for cred in entry.get("credentials") or [] \
                    if isinstance(entry.get("credentials"), list) else []:
                problem = _credential_problem(cred)
                if problem and isinstance(cred, str) and SCRIPT_CONNECTION_RE.match(cred):
                    out.append(f"{p}.credentials: {problem}")   # else the fragment's check
        if partners and third.owners_alone:
            served = set(_api_hosts(content)) - {name}
            if endpoints and OWNERS_HOST not in served:
                out.append(f"{rel}: no endpoint answers under {OWNERS_HOST}: the partners' node "
                           "serving the owners alone (no third_parties: entry lists it) serves "
                           f"exactly {OWNERS_HOST} (spec D421)")
            for host in sorted(served - {OWNERS_HOST}):
                out.append(f"{rel}: endpoints answer under {host}: the partners' node serving "
                           "the owners alone (no third_parties: entry lists it) answers under "
                           f"{OWNERS_HOST} only (spec D421)")
        elif partners:
            served = set(_api_hosts(content)) - {name}
            for host in sorted(third.hostnames - served):
                out.append(f"{rel}: no endpoint answers under {host}, a third party's hostname "
                           "(third_parties:): the partners' node serves exactly the hostnames of "
                           f"the entries naming nodes, plus {OWNERS_HOST} (W2 item 1)")
            for host in sorted(served - third.hostnames - {OWNERS_HOST}):
                out.append(f"{rel}: endpoints answer under {host}, which no third_parties: entry "
                           f"naming nodes declares as its hostname (nor {OWNERS_HOST}; W2 item 1)")
        connections = content.get("connections")
        for cname, conn in _dict(connections).items():
            _check_connection(conn, f"{rel}: connections.{cname}", names, out, http)


def _sql_roles(conns):
    return {c["role"] for c in _dict(conns).values()
            if isinstance(c, dict) and c.get("driver") == "sql/postgresql"
            and isinstance(c.get("role"), str)}


def _node_connection_roles(node, sdir, apis):
    """The SQL roles a node's connections name: a scheduler node's
    schedule.yaml, an api node's api.yaml."""
    roles = set()
    if is_scheduler_node(node):
        roles |= _sql_roles(_dict(_seed_yaml(node, sdir, "schedule.yaml")).get("connections"))
    if node.get("name") in apis:
        roles |= _sql_roles(apis[node.get("name")][1].get("connections"))
    return roles


def _check_partner_access(data, nodes, bricks, faults, answer_key, third, apis, sdir, out):
    """Out of reach (master spec 6.3, 10.2; W2 item 1): no third-party node
    in the starter pack, none an expected fix names, the partners' roles
    theirs alone, and a third-party postgres node's pg_hba.conf admitting
    those roles only, on the partners' database."""
    if not third.nodes:
        return
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    for node in nodes:
        if node.get("role") != "bastion":
            continue
        for fname, rel in _dict(node.get("seed_files")).items():
            if is_seed_folder_entry(fname) or not isinstance(rel, str):
                continue
            path = _inside(sdir, rel)
            try:
                text = path.read_text(encoding="utf-8") if path is not None and path.is_file() \
                    else ""
            except (OSError, UnicodeDecodeError):
                continue
            for name in sorted(third.nodes):
                if re.search(rf"(?<![A-Za-z0-9_.-]){re.escape(name)}(?![A-Za-z0-9_-])", text):
                    out.append(f"{rel}: names node {name}, a third party's: the partners' nodes "
                               "are not among the starter pack's nodes (master spec 10.2)")
    issues = [i for i in data.get("issues") or [] if isinstance(i, dict)]
    instances = {i.get("id"): i for i in data.get("fault_instances") or [] if isinstance(i, dict)}
    for entry in _dict(answer_key).get("instances") or []:
        if not isinstance(entry, dict) or entry.get("instance") not in instances:
            continue
        iid = entry["instance"]
        node = instances[iid].get("node")
        if node not in third.nodes:
            continue
        expected = {i.get("expected_resolution") for i in issues if iid in (i.get("covers") or [])}
        if "fix" in expected or "fix" in _dict(entry.get("acceptable")):
            out.append(f"gm/answer-key.yaml: instances[{iid}]: an expected fix on node {node}, a "
                       "third party's: every fix is the customer's (master spec 6.3, 10.2)")
    theirs = {}
    for name in sorted(third.nodes):
        for role in _node_connection_roles(by_name[name], sdir, apis):
            theirs.setdefault(role, name)
    for node in nodes:
        name = node.get("name")
        if name in third.nodes:
            continue
        crontab = node.get("crontab_roles")
        named = _node_connection_roles(node, sdir, apis) | (
            {r for r in crontab if isinstance(r, str)} if isinstance(crontab, list) else set())
        for role in sorted(named & set(theirs)):
            out.append(f"{label}: nodes[{name}]: names role {role}, a third party's (node "
                       f"{theirs[role]}'s connection): the partners' roles are theirs alone "
                       "(master spec 10.2, W2 item 1)")
    for name in sorted(third.nodes):
        brick = bricks.get(name)
        if brick is None or brick.id != POSTGRES_BRICK:
            continue
        rel, lines = _hba_text_lines(by_name[name], sdir)
        if lines is None:
            continue
        for number, f in lines:
            if tuple(f) in GM_HBA_LINES or f[-1] == "reject":
                continue
            if f[0].startswith("host") and len(f) >= 3 and "gm_check" in f[2].split(","):
                out.append(f"{rel}: line {number}: {' '.join(f)}: a third party's database "
                           "admits gm_check over its own socket only (its local line), never "
                           "from the network: no host line names gm_check (spec D383, access "
                           "model 8)")
                continue
            roles = f[2].split(",") if len(f) == 5 else []
            if len(f) == 5 and f[0] == "host" and f[1] == PARTNERS_DATABASE \
                    and f[4] == "scram-sha-256" and roles and all(r in theirs for r in roles):
                continue
            out.append(f"{rel}: line {number}: {' '.join(f)}: a third party's database admits "
                       f"no role but the partners' own ({', '.join(sorted(theirs)) or 'none'}) on "
                       f"{PARTNERS_DATABASE} (host {PARTNERS_DATABASE} <roles> <address> "
                       "scram-sha-256); every other line is the GM's or a reject (master spec "
                       "10.2, W2 item 1)")
        if not lines or tuple(lines[-1][1]) != CLOSING_HBA:
            out.append(f"{rel}: its last line is not {' '.join(CLOSING_HBA)} (a third party's "
                       "database; W2 item 1)")


def _check_vaults(nodes, bricks, http, out):
    """postgres' vault_target and vault_credential (W1 item 6, W1-x): checked
    as an http connection's target and credential."""
    for node in nodes:
        brick = bricks.get(node.get("name"))
        if brick is None or brick.id != POSTGRES_BRICK:
            continue
        params = _dict(node.get("parameters"))
        p = f"scenario.yaml: nodes[{node.get('name')}].parameters"
        if params.get("vault_target") is not None:
            problem = _http_target_problem(params["vault_target"], http)
            if problem:
                out.append(f"{p}.vault_target: {problem}")
        if params.get("vault_credential") is not None:
            problem = _credential_problem(params["vault_credential"])
            if problem:
                out.append(f"{p}.vault_credential: {problem}")


def _domain_entry_locations(entry):
    """(database, node/database) of a domains: entry's at:."""
    at = _dict(entry).get("at")
    if isinstance(at, str):
        return [(None, at)]
    return [(db, loc) for db, loc in at.items() if isinstance(loc, str)] \
        if isinstance(at, dict) else []


def _partner_data_files(domain_dir):
    """A domain's partner state files, producers/partners/<prefix>/data.sql
    and producers/public/<name>/data.sql (W2 items 1 and 3)."""
    found = []
    for folder in ("partners", "public"):
        base = domain_dir / "producers" / folder
        if base.is_dir():
            found += sorted(p for p in base.glob("*/data.sql") if p.is_file())
    return found


def node_creates(sdir, data, node, catalog_root=REPO_ROOT):
    """The DataFileCreates of what is created on a postgres node (W2 item 1,
    spec D360): its data file's (node_data_file_creates), plus, for every
    domains: entry placed there, each at: database and the roles and
    databases its schema and load files create, plus, on the partners'
    node (the postgres node the third_parties: entries list), each composed
    domain's partner data.sql, plus each purposes: entry's ddl: file whose
    part the scenario maps to this node (v0.5 chunk 29b, capture W3
    addendum item 6 (e)). None when nothing creates anything there.
    Read by the location, crontab-role and governance checks, by
    localimpl.data_login_roles and inject.password_plan."""
    sdir = Path(sdir)
    nodes = [n for n in _dict(data).get("nodes") or [] if isinstance(n, dict)]
    name = node.get("name") if isinstance(node, dict) else node
    node = next((n for n in nodes if n.get("name") == name), node if isinstance(node, dict) else {})
    own = node_data_file_creates(sdir, node)
    created = DataFileCreates(own.file if own else f"domains on node {name}", set(), set(),
                              False, [], [])
    if own is not None:
        created.databases |= own.databases
        created.roles |= own.roles
        created.pg_cron = own.pg_cron
        created.logins += own.logins
        created.sources.append(own.file)

    def take(path, rel):
        try:
            found = data_file_creates(path.read_text(encoding="utf-8"), rel)
        except (OSError, UnicodeDecodeError):
            return
        created.databases |= found.databases
        created.roles |= found.roles
        created.logins += [r for r in found.logins if r not in created.logins]
        created.sources.append(rel)

    entries = _dict(data).get("domains")
    entries = [e for e in entries if isinstance(e, dict)] if isinstance(entries, list) else []
    for entry in entries:
        did = entry.get("id")
        if not (isinstance(did, str) and PURPOSE_ID_RE.match(did)):
            continue
        domain_dir = Path(catalog_root) / "domains" / did
        try:
            domain = _dict(yaml.safe_load((domain_dir / "domain.yaml").read_text(encoding="utf-8")))
        except (OSError, UnicodeDecodeError, yaml.YAMLError):
            continue
        for database, location in _domain_entry_locations(entry):
            lnode, sep, ldb = location.partition("/")
            if lnode != name or not sep:
                continue
            created.databases.add(ldb)
            if database is None:
                files = [domain.get("schema"), domain.get("load")]
            else:
                files = [f"data/{database}/schema.sql", f"data/{database}/load.sql"]
            for rel in files:
                path = _inside(domain_dir, rel) if isinstance(rel, str) else None
                if path is not None and path.is_file():
                    take(path, f"domains/{did}/{rel}")
    third = _dict(data).get("third_parties")
    listed = {n for e in third if isinstance(e, dict) for n in e.get("nodes") or []
              if isinstance(n, str)} if isinstance(third, list) else set()
    brick = _dict(node.get("brick")).get("id")
    if name in listed and brick == POSTGRES_BRICK:
        for entry in entries:
            did = entry.get("id")
            if isinstance(did, str) and PURPOSE_ID_RE.match(did):
                domain_dir = Path(catalog_root) / "domains" / did
                for path in _partner_data_files(domain_dir):
                    take(path, f"domains/{did}/{path.relative_to(domain_dir)}")
    purposes = _dict(data).get("purposes")
    for entry in purposes if isinstance(purposes, list) else []:
        pid = _dict(entry).get("id")
        if not (isinstance(pid, str) and PURPOSE_ID_RE.match(pid)):
            continue
        purpose_dir = Path(catalog_root) / "purposes" / pid
        try:
            purpose = _dict(yaml.safe_load((purpose_dir / "purpose.yaml")
                                           .read_text(encoding="utf-8")))
        except (OSError, UnicodeDecodeError, yaml.YAMLError):
            continue
        mapped = _dict(_dict(entry).get("parts"))
        for part, rel in purpose_ddl(purpose):
            location = mapped.get(part)
            if not (isinstance(location, str) and location.partition("/")[0] == name):
                continue
            path = _inside(purpose_dir, rel)
            if path is not None and path.is_file():
                take(path, f"purposes/{pid}/{rel}")    # W3 addendum, item 6 (e)
    if not created.sources:
        return None
    return created


def _check_domains_v05(data, nodes, third, sdir, catalog_root, out):
    """No domain's at: on a standby; a composed domain with a partner
    data.sql needs a partners' postgres node (W2 item 1), unless
    composition.yaml leaves that partner's folder out (chunk 29's (b)); a
    composed domain shipping data/cron.sql sits on one node, which preloads
    pg_cron and whose data file creates it (chunk 29's (d))."""
    label = "scenario.yaml"
    by_name = {n.get("name"): n for n in nodes}
    left_out = left_out_of(_composition_content(sdir))
    entries = data.get("domains")
    for i, entry in enumerate(entries if isinstance(entries, list) else []):
        if not isinstance(entry, dict):
            continue
        p = f"{label}: domains[{_item_label(entry, i)}]"
        for database, location in _domain_entry_locations(entry):
            lnode = location.partition("/")[0]
            if _dict(by_name.get(lnode)).get("standby_of") is not None:
                where = "at" if database is None else f"at.{database}"
                out.append(f"{p}.{where}: {location}: {lnode} is a standby (standby_of "
                           f"{by_name[lnode]['standby_of']}): a standby is no location (W2 "
                           "item 1)")
        did = entry.get("id")
        if not (isinstance(did, str) and PURPOSE_ID_RE.match(did)):
            continue
        domain_dir = Path(catalog_root) / "domains" / did
        if third.db_node is None:
            for path in _partner_data_files(domain_dir):
                if (did, path.parent.relative_to(domain_dir / "producers").as_posix()) \
                        in left_out:
                    continue                 # left out: skipped with no partners' database
                out.append(f"{p}: domains/{did}/{path.relative_to(domain_dir)} plants a "
                           "partner's state, but no third_parties: entry lists a postgres node "
                           f"(the partners' database, {PARTNERS_DATABASE}; W2 items 0 and 1)")
        if (domain_dir / CRON_FILE).is_file():
            _check_domain_cron(entry, did, by_name, sdir, p, out)


def _composition_content(sdir):
    """composition.yaml's content beside scenario.yaml, or None."""
    path = Path(sdir) / "composition.yaml" if sdir is not None else None
    if path is None or not path.is_file():
        return None
    try:
        return strict_load(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, yaml.YAMLError):
        return None                          # reported by check_composition


def _check_domain_cron(entry, did, by_name, sdir, p, out):
    """A composed domain's data/cron.sql runs on its node, in its
    cron.database_name (chunk 29's (d), spec D405): every location of the
    domain on one node, whose seed postgresql.conf preloads pg_cron and whose
    data file creates the extension."""
    shown = f"domains/{did}/{CRON_FILE}"
    nodes = []
    for _, location in _domain_entry_locations(entry):
        lnode = location.partition("/")[0]
        if lnode not in nodes:
            nodes.append(lnode)
    if len(nodes) != 1:
        out.append(f"{p}: {shown} schedules pg_cron jobs on the domain's node, but its at: "
                   f"names {len(nodes)} nodes ({', '.join(nodes) or 'none'}); a domain shipping "
                   "one sits on one node")
        return
    node = by_name.get(nodes[0])
    if node is None or node.get("role") != "database":
        return                               # reported with the at:
    preloaded, _, rel = node_pg_cron(node, sdir)
    if not preloaded:
        where = f"its seed postgresql.conf ({rel})" if rel else "it seeds no postgresql.conf"
        out.append(f"{p}: {shown} schedules pg_cron jobs on node {nodes[0]}, which does not "
                   f"preload pg_cron ({where}; shared_preload_libraries, master spec 7.2)")
        return
    created = node_data_file_creates(sdir, node)
    if created is None or not created.pg_cron:
        out.append(f"{p}: {shown} schedules pg_cron jobs on node {nodes[0]}, whose data file "
                   "does not create the extension pg_cron (CREATE EXTENSION pg_cron, in "
                   "cron.database_name)")


# --- v0.5: the loader's support for the parts (build plan chunk 29; capture W3
# --- items 0 and 6 of specs/versions/v0.5/wave-log.md; spec D401, D405) ---

KEYS_FILE = "data/keys.sql"         # a core's key functions; a part's (chunk 29's (a))
CRON_FILE = "data/cron.sql"         # a domain's pg_cron jobs (chunk 29's (d))
LEFT_OUT_KEYS = ("domain", "producer", "reason")
_PRODUCER_RE = re.compile(r"^(?:(api|partners|public)/)?([a-z][a-z0-9-]*)$")
_KEY_FUNCTION_RE = re.compile(
    r"^\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+pg_temp\.([a-z][a-z0-9]*)_[a-z0-9_]*\s*\(",
    re.IGNORECASE)
_KEY_ANY_FUNCTION_RE = re.compile(
    r"^\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+pg_temp\.([a-z][a-z0-9]*)_", re.IGNORECASE)
_CREATE_LINE_RE = re.compile(r"^\s*CREATE\b", re.IGNORECASE)
_CRON_CALL_RE = re.compile(r"^SELECT\s+cron\s*\.\s*schedule_in_database\s*\(", re.IGNORECASE)


def left_out_of(content):
    """{(domain, producer)} of a composition record's left_out: (chunk 29's
    (b)), its well-formed entries only (check_composition reports the rest)."""
    entries = _dict(content).get("left_out")
    return {(e.get("domain"), e.get("producer")) for e in entries
            if isinstance(e, dict) and isinstance(e.get("domain"), str)
            and isinstance(e.get("producer"), str)} if isinstance(entries, list) else set()


def check_left_out(content, found, catalog_root, rel, out):
    """composition.yaml's optional left_out: (capture W3 item 0, chunk 29's
    (b)): a list of {domain, producer, reason}, each `producer` a folder
    under a composed domain's producers/ (`pms`, `api/clinic-api`,
    `partners/xlab`), once."""
    entries = content.get("left_out")
    if "left_out" not in content:
        return
    if not isinstance(entries, list) or not entries:
        out.append(f"{rel}: left_out: {entries!r} is not a non-empty list of {{domain, "
                   "producer, reason}}")
        return
    seen = []
    for i, entry in enumerate(entries):
        p = f"{rel}: left_out[{i}]"
        if not isinstance(entry, dict):
            out.append(f"{p}: not a mapping {{domain, producer, reason}}")
            continue
        _unknown_keys(entry, LEFT_OUT_KEYS, p, "a left_out entry", out)
        for key in LEFT_OUT_KEYS:
            if not (isinstance(entry.get(key), str) and entry[key].strip()):
                out.append(f"{p}.{key}: missing or empty")
        did, producer = entry.get("domain"), entry.get("producer")
        if not (isinstance(did, str) and isinstance(producer, str)):
            continue
        if did not in found:
            out.append(f"{p}.domain: {did} is not a domain of domains:")
            continue
        if (did, producer) in seen:
            out.append(f"{p}: {did} {producer} left out twice")
        seen.append((did, producer))
        m = _PRODUCER_RE.match(producer)
        if m is None or (m.group(1) is None and m.group(2) in RESERVED_PRODUCER_FOLDERS):
            out.append(f"{p}.producer: {producer!r} is not a producer folder (<node>, "
                       "api/<node>, partners/<prefix> or public/<name>)")
            continue
        folder = _dict(found[did][1]).get("producers")
        base = Path(catalog_root) / "domains" / did
        path = _inside(base, folder) if isinstance(folder, str) else None
        if path is None or not (path / producer).is_dir():
            out.append(f"{p}.producer: {producer}: not a folder of domains/{did}/"
                       f"{(folder or 'producers/').rstrip('/')}/ (a producer folder of the "
                       "composed domain)")


def _check_part_sql(domain_dir, data, base, out):
    """A part's data/keys.sql (check_part_keys) and any domain's
    data/cron.sql (check_cron_file), when present (chunk 29's (a), (d))."""
    for rel, check in ((KEYS_FILE, "keys"), (CRON_FILE, "cron")):
        path = domain_dir / rel
        if not path.is_file() or (check == "keys" and "requires" not in data):
            continue                         # a core's keys.sql: formats.md, unchecked
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            out.append(f"{_rel(path, base)}: cannot be read: {exc}")
            continue
        if check == "cron":
            out.extend(check_cron_file(text, _rel(path, base)))
            continue
        requires = data.get("requires")
        core = requires[0] if isinstance(requires, list) and requires else None
        core_keys = domain_dir.parent / str(core) / KEYS_FILE
        try:
            core_text = core_keys.read_text(encoding="utf-8") if core_keys.is_file() else ""
        except (OSError, UnicodeDecodeError):
            core_text = ""
        out.extend(check_part_keys(text, _rel(path, base), core_text))


def _key_prefixes(text):
    return {m.group(1).lower() for m in map(_KEY_ANY_FUNCTION_RE.match, text.splitlines()) if m}


def check_part_keys(text, rel, core_text=None):
    """Problems of a part's data/keys.sql (capture W3 item 0, chunk 29's
    (a)): every CREATE at the start of a line a `CREATE [OR REPLACE] FUNCTION
    pg_temp.<prefix>_<name>(`, one prefix throughout, its own: never `core`
    nor a prefix of the core's keys.sql (`core_text`), streamed in the same
    session after it."""
    out, prefixes = [], []
    for number, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("--") or not _CREATE_LINE_RE.match(line):
            continue
        m = _KEY_FUNCTION_RE.match(line)
        if m is None:
            out.append(f"{rel}:{number}: {line.strip()[:80]}: a part's keys.sql creates "
                       "pg_temp.<its prefix>_* functions only")
            continue
        prefix = m.group(1).lower()
        if prefix not in prefixes:
            prefixes.append(prefix)
    if len(prefixes) > 1:
        out.append(f"{rel}: functions under {len(prefixes)} prefixes ({', '.join(prefixes)}): "
                   "a part's keys share its one prefix (pg_temp.<prefix>_*)")
    core = _key_prefixes(core_text or "") | {"core"}
    for prefix in prefixes:
        if prefix in core:
            out.append(f"{rel}: pg_temp.{prefix}_*: the core's prefix; a part's keys take its "
                       "own (lab_, portal_), streamed after the core's in one session")
    return out


def check_cron_file(text, rel):
    """Problems of a domain's data/cron.sql (capture W3 item 6 (d), spec
    D405): `SELECT cron.schedule_in_database(...)` calls only, at least one."""
    out = []
    statements = sql_statements(text)
    for number, stmt in statements:
        if not _CRON_CALL_RE.match(stmt.strip()):
            out.append(f"{rel}:{number}: {' '.join(stmt.split())[:80]}: a cron.sql holds "
                       "SELECT cron.schedule_in_database(...) calls only")
    if not statements:
        out.append(f"{rel}: schedules no job (SELECT cron.schedule_in_database(...))")
    return out


def node_pg_cron(node, sdir):
    """(preloaded, cron.database_name, the seed's path) of a postgres node,
    read from its seed postgresql.conf: whether shared_preload_libraries
    names pg_cron, and the database pg_cron keeps its jobs in (`postgres`,
    pg_cron's default, when unset)."""
    rel, path = _seed_path(_dict(node), Path(sdir), POSTGRESQL_CONF)
    if path is None:
        return False, None, rel
    try:
        settings = read_conf_settings(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError):
        return False, None, rel
    preload = [lib.strip() for lib in
               _conf_text_value(settings.get("shared_preload_libraries")).split(",")]
    database = _conf_text_value(settings.get("cron.database_name")) or "postgres"
    return "pg_cron" in preload, database, rel


def _check_v05(data, nodes, bricks, faults, answer_key, third, apis, http, sdir, catalog_root,
               out):
    """v0.5's scenario checks beyond the node's own (build plan chunk 6)."""
    _check_standbys(nodes, bricks, sdir, out)
    _check_monitors(data, nodes, bricks, faults, third, sdir, out)
    _check_fault_instance_options(data, nodes, bricks, faults, out)
    _check_api_nodes(nodes, bricks, third, apis, http, sdir, out)
    _check_partner_access(data, nodes, bricks, faults, answer_key, third, apis, sdir, out)
    _check_vaults(nodes, bricks, http, out)
    _check_domains_v05(data, nodes, third, sdir, catalog_root, out)


# --- v0.5: purposes and domains (build plan chunk 6b; master spec 6.6, 12.1, 15;
# --- formats.md "Purpose definition"; W2 item 1; spec D354, D360) ---

PARTNER_DATA_FILE = "data.sql"      # a partner folder's state (W2 item 1)
THIRD_PARTY_PARTS = ("receiver", "partner")   # a declared third party's node (v0.5)
HTTP_PARTS = ("api", "partner", "receiver")   # an HTTP connection is named for the part it reaches
INVARIANT_JUDGED = ("runs", "triggers", "end-to-end", "code", "definition")
ROUND_TRIP_ASKERS = ("customer", "partner")
OPS_SCHEMA = "ops"                  # a purpose's own tables in a domain's database (12.1)
_ROUTINE_RE = re.compile(r"^\s*CREATE\s+(?:OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+([^\s(]+)",
                         re.IGNORECASE)
_SECURITY_DEFINER_RE = re.compile(r"\bSECURITY\s+DEFINER\b", re.IGNORECASE)
_SEARCH_PATH_RE = re.compile(
    r"\bSET\s+search_path\s*(?:=|\bTO\b)\s*(.*?)(?=\s+(?:AS|LANGUAGE|SECURITY|SET|IMMUTABLE|"
    r"STABLE|VOLATILE|STRICT|CALLED|RETURNS|COST|ROWS|PARALLEL|LEAKPROOF|NOT|EXTERNAL|SUPPORT|"
    r"TRANSFORM|WINDOW|BEGIN|RETURN)\b|\s*$)", re.IGNORECASE | re.DOTALL)
_DOLLAR_TAG_RE = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)?\$")


def _v05_shaped(data):
    """A scenario with third_parties: or domains: (W2 item 1: the receiver rule)."""
    return "third_parties" in data or "domains" in data


def _third_party_nodes(data):
    entries = data.get("third_parties")
    return {n for e in entries if isinstance(e, dict) for n in e.get("nodes") or []
            if isinstance(n, str)} if isinstance(entries, list) else set()


def sql_statements(text):
    """(line, statement) of each statement of a SQL file, comments and
    dollar-quoted bodies blanked (their newlines kept), single-quoted
    literals kept; split at each `;` outside them. No SQL parser."""
    out, buf, line, start = [], [], 1, 1
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == "-" and text.startswith("--", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            buf.append(" ")
            i = j
            continue
        if c == "/" and text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            chunk = text[i:j]
            buf.append("\n" * chunk.count("\n") or " ")
            line += chunk.count("\n")
            i = j
            continue
        if c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'" and text.startswith("''", j):
                    j += 2
                    continue
                if text[j] == "'":
                    break
                j += 1
            chunk = text[i:j + 1]
            buf.append(chunk)
            line += chunk.count("\n")
            i = j + 1
            continue
        if c == "$":
            m = _DOLLAR_TAG_RE.match(text, i)
            if m:
                end = text.find(m.group(0), m.end())
                end = n if end < 0 else end + len(m.group(0))
                chunk = text[i:end]
                buf.append(" $body$ " + "\n" * chunk.count("\n"))
                line += chunk.count("\n")
                i = end
                continue
        if c == ";":
            statement = "".join(buf)
            if statement.strip():
                out.append((start, statement))
            buf = []
            i += 1
            start = line
            continue
        if c == "\n":
            line += 1
            if not "".join(buf).strip():
                start = line
        buf.append(c)
        i += 1
    if "".join(buf).strip():
        out.append((start, "".join(buf)))
    return out


def _check_security_definer(path, rel, out):
    """Every CREATE [OR REPLACE] FUNCTION|PROCEDURE holding SECURITY DEFINER
    holds SET search_path = <a fixed path>, never naming "$user" (master
    spec 6.1, 15; W2 item 1)."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        out.append(f"{rel}: cannot be read: {exc}")
        return
    for number, statement in sql_statements(text):
        m = _ROUTINE_RE.match(statement)
        if m is None or not _SECURITY_DEFINER_RE.search(statement):
            continue
        what = f"{rel}: line {number}: {m.group(1).upper()} {m.group(2)}"
        path_set = _SEARCH_PATH_RE.search(statement)
        if path_set is None:
            out.append(f"{what}: SECURITY DEFINER without SET search_path = <a fixed path> "
                       "(master spec 6.1, 15)")
        elif "$user" in path_set.group(1).lower():
            out.append(f"{what}: SECURITY DEFINER with a search_path naming \"$user\": a fixed "
                       "path names schemas only (master spec 6.1, 15)")


def _domain_sql_files(domain_dir, data):
    """The SQL files a domain's SECURITY DEFINER check reads (W2 item 1): its
    schema and load files, data/derive.sql, data/keys.sql, and each partner
    folder's data.sql."""
    files = [path for _, path in _domain_schema_files(domain_dir, data)]
    databases = data.get("databases")
    if isinstance(databases, list):
        files += [domain_dir / "data" / db / "load.sql" for db in databases
                  if isinstance(db, str) and SQL_NAME_RE.match(db)]
    elif isinstance(data.get("load"), str):
        load = _inside(domain_dir, data["load"])
        files += [load] if load is not None else []
    files += [domain_dir / "data" / "derive.sql", domain_dir / "data" / "keys.sql"]
    files += _partner_data_files(domain_dir)
    seen = []
    for path in files:
        if path is not None and path.is_file() and path not in seen:
            seen.append(path)
    return seen


def _check_purpose_v05(purpose_dir, data, label, base, parts, jobs, out):
    """The purpose format's v0.5 extensions (master spec 6.6, 12.1;
    formats.md "Purpose definition"): the round trip, judged:, HTTP
    connections, periodic jobs and their history, endpoint material, the
    purpose's classification:."""
    names = [j.get("name") for j in jobs]
    kind = data.get("kind")
    trips = data.get("round_trips")
    if kind == "round-trip" and "round_trips" not in data:
        out.append(f"{label}: round_trips: missing (a round-trip purpose: one entry per exchange "
                   "it carries; master spec 12.1)")
    elif "round_trips" in data and kind != "round-trip":
        out.append(f"{label}: round_trips: only on a round-trip purpose (kind {kind})")
    if "round_trips" in data and not (isinstance(trips, list) and trips):
        out.append(f"{label}: round_trips: not a non-empty list of exchanges")
    trips = [t for t in trips if isinstance(t, dict)] if isinstance(trips, list) else []
    for i, trip in enumerate(trips):
        p = f"{label}: round_trips[{i}]"
        asks = trip.get("asks")
        if "asks" in trip and asks not in ROUND_TRIP_ASKERS:
            out.append(f"{p}.asks: {asks!r} is not {' or '.join(ROUND_TRIP_ASKERS)}")
        job = _dict(trip.get("request")).get("job")
        if asks == "customer" and job is not None and job not in names:
            out.append(f"{p}.request.job: {job} is not a job of the purpose (the customer asks "
                       "through one of its jobs)")
        answers = trip.get("answers")
        if "answers" in trip and not (isinstance(answers, list) and answers):
            out.append(f"{p}.answers: not a non-empty list of expected answers")
        reactions = trip.get("reactions")
        if "reactions" in trip and not isinstance(reactions, list):
            out.append(f"{p}.reactions: not a list of the processes an answer starts")
    invariants = data.get("invariants")
    invariants = [v for v in invariants if isinstance(v, dict)] \
        if isinstance(invariants, list) else []
    for inv in invariants:
        if "judged" in inv and inv["judged"] not in INVARIANT_JUDGED:
            out.append(f"{label}: invariants[{_item_label(inv, 0)}].judged: {inv['judged']!r} is "
                       f"not one of {', '.join(INVARIANT_JUDGED)}")
    if kind == "round-trip":
        ends = [v.get("id") for v in invariants if v.get("judged") == "end-to-end"]
        if len(ends) != len(trips):
            out.append(f"{label}: invariants: {len(ends)} judged end-to-end "
                       f"({', '.join(map(str, ends)) or 'none'}) for {len(trips)} round trip(s): "
                       "a round trip names exactly one end-to-end invariant (master spec 12.1)")
    feeders = []
    for i, job in enumerate(jobs):
        p = f"{label}: jobs[{_item_label(job, i)}]"
        for cname, value in _dict(job.get("connections")).items():
            if cname not in HTTP_PARTS:
                continue
            if cname not in parts:
                out.append(f"{p}.connections.{cname}: an HTTP connection is named for the part "
                           f"it reaches, and the purpose declares no {cname} part")
            if value != PUBLIC_CREDENTIAL and _credential_problem(value):
                out.append(f"{p}.connections.{cname}: {value!r} is not the HTTP credential it "
                           f"calls with ([a-z][a-z0-9_]{{0,62}}) or {PUBLIC_CREDENTIAL} for a "
                           "public endpoint (spec D354)")
        if "feeder" in job:
            feeders.append(job["name"])
            if job["feeder"] == job.get("name") or job["feeder"] not in names:
                out.append(f"{p}.feeder: {job['feeder']} is not another job of the purpose (a "
                           "periodic job's daily feeder, the witness within the aging)")
    history = data.get("history")
    if feeders and "history" not in data:
        out.append(f"{label}: history: missing (a periodic purpose, jobs "
                   f"{', '.join(map(str, feeders))} naming their feeder, plants its past "
                   "periods' outputs: material/history.sql; master spec 12.1)")
    # A history with no feeder is accepted (v0.5 chunk 29's (c); purposes 14
    # and 16, spec D366, D404): it plants a past no periodic job extends.
    if isinstance(history, str):
        path = _inside(purpose_dir, history)
        if path is None or not path.is_file() or not history.startswith("material/"):
            out.append(f"{_rel(purpose_dir / history, base)}: missing file (history, a file of "
                       "material/)")
    _check_purpose_ddl(purpose_dir, data, label, base, parts, out)
    endpoints = purpose_dir / "material" / "api"
    if endpoints.is_dir():
        if "api" not in parts:
            out.append(f"{_rel(endpoints, base)}/: endpoint material, but the purpose declares "
                       "no api part")
        for node_dir in sorted(endpoints.iterdir()):
            _check_endpoint_material(node_dir, base, out)
    classification = data.get("classification")
    if "classification" in data:
        columns = _dict(classification).get("columns")
        if not (isinstance(columns, dict) and columns):
            out.append(f"{label}: classification.columns: not a non-empty map of column -> "
                       "class")
        for key, cls in _dict(columns).items():
            p = f"{label}: classification.columns.{key}"
            if not (isinstance(key, str) and SCENARIO_CLASSIFICATION_KEY_RE.match(key)):
                out.append(f"{p}: {key!r} is not <database>.<table>.<column> "
                           "(<database>.<schema>.<table>.<column> outside public)")
            if cls not in CLASSES:
                out.append(f"{p}: {cls!r} is not a class ({', '.join(CLASSES)})")


def _check_endpoint_material(node_dir, base, out):
    """material/api/<node>/: routes/ and db/, one <name>.py of each per
    endpoint (formats.md "Purpose definition"; W1 item 5)."""
    rel = _rel(node_dir, base)
    if not node_dir.is_dir() or not NAME_RE.match(node_dir.name):
        out.append(f"{rel}: not a folder named for an api node")
        return
    found = {}
    for entry in sorted(node_dir.iterdir()):
        if not (entry.is_dir() and entry.name in API_FRAGMENT_FOLDERS):
            out.append(f"{rel}/{entry.name}: not endpoint material (routes/, db/)")
            continue
        found[entry.name] = {p.stem for p in entry.iterdir() if p.suffix == ".py"}
        for p in sorted(entry.iterdir()):
            if p.suffix != ".py" or not ENDPOINT_RE.match(p.stem):
                out.append(f"{rel}/{entry.name}/{p.name}: not <endpoint>.py ([a-z][a-z0-9_]*)")
    routes, db = found.get("routes", set()), found.get("db", set())
    for name in sorted(routes ^ db):
        lacking = "db" if name in routes else "routes"
        out.append(f"{rel}/{lacking}/{name}.py: missing (each endpoint is served by "
                   "routes/<name>.py and db/<name>.py)")


def _check_purpose_http(purpose, pid, runner, sdir, p, out):
    """Each HTTP connection of a purpose's job maps to the credential the
    runner's schedule connection names, or public when it names none (spec
    D354)."""
    jobs = {j.get("name"): j for j in _dict(_seed_yaml(runner, sdir, "jobs.yaml")).get("jobs") or []
            if isinstance(j, dict)}
    conns = _dict(_dict(_seed_yaml(runner, sdir, "schedule.yaml")).get("connections"))
    for job in purpose.get("jobs") or []:
        if not isinstance(job, dict) or job.get("name") not in jobs:
            continue                         # reported by the jobs' check
        mapped = _dict(jobs[job["name"]].get("connections"))
        for cname, value in _dict(job.get("connections")).items():
            if cname not in HTTP_PARTS or cname not in mapped:
                continue
            conn = _dict(conns.get(mapped[cname]))
            where = f"{runner.get('name')}'s job {job['name']} connection {cname} ({mapped[cname]})"
            if conn.get("driver") != "http":
                out.append(f"{p}: {where} is not an http connection, but purpose {pid} names "
                           f"{cname} for the {cname} part it reaches")
                continue
            expected = conn.get("credential", PUBLIC_CREDENTIAL)
            if value != expected:
                out.append(f"{p}: purpose {pid}'s job {job['name']} maps {cname} to {value}, but "
                           f"{where} calls with {expected} (spec D354)")


def _check_purpose_ddl(purpose_dir, data, label, base, parts, out):
    """ddl: (capture W3 addendum, item 6 (e); chunk 29b): a non-empty mapping
    from database parts the purpose declares (source, target) to files of
    material/, each existing."""
    if "ddl" not in data:
        return
    ddl = data.get("ddl")
    if not (isinstance(ddl, dict) and ddl):
        out.append(f"{label}: ddl: {ddl!r} is not a non-empty map of a database part -> its "
                   "DDL file (ddl: {target: material/target-ddl.sql})")
        return
    for part, rel in ddl.items():
        p = f"{label}: ddl.{part}"
        if part not in DATABASE_PARTS or part not in _dict(parts):
            out.append(f"{p}: not a database part the purpose declares ("
                       f"{', '.join(k for k in DATABASE_PARTS if k in _dict(parts)) or 'none'})")
            continue
        path = _inside(purpose_dir, rel) if isinstance(rel, str) else None
        if path is None or not path.is_file() or not rel.startswith("material/"):
            out.append(f"{_rel(purpose_dir / str(rel), base)}: missing file (ddl.{part}, a file "
                       "of material/)")


def purpose_ddl(purpose):
    """[(part, relative file)] of a purpose.yaml's ddl:, its well-formed
    entries, in the order the purpose's parts: lists them (W3 addendum)."""
    ddl = _dict(_dict(purpose).get("ddl"))
    order = list(_dict(_dict(purpose).get("parts")))
    parts = sorted((p for p in ddl if isinstance(ddl[p], str)),
                   key=lambda p: order.index(p) if p in order else len(order))
    return [(p, ddl[p]) for p in parts]


def domain_locations(data):
    """{node/database} every domains: entry's at: places a database at."""
    entries = _dict(data).get("domains")
    return {loc for e in entries if isinstance(e, dict) for _, loc in _domain_entry_locations(e)} \
        if isinstance(entries, list) else set()


def _check_purpose_ops(data, purpose, pid, parts, p, out):
    """A purpose's own tables in a domain's database live in schema ops
    (master spec 12.1): each trace table on a database part placed at a
    domains: entry's at:."""
    placed = {loc for e in data.get("domains") or [] if isinstance(e, dict)
              for _, loc in _domain_entry_locations(e)} if isinstance(data.get("domains"), list) \
        else set()
    if not placed:
        return
    for i, item in enumerate(purpose.get("trace") or []):
        if not isinstance(item, dict) or not isinstance(item.get("table"), str):
            continue
        part = item.get("part")
        if part not in DATABASE_PARTS or parts.get(part) not in placed:
            continue
        schema = item["table"].split(".")[0] if "." in item["table"] else "public"
        if schema != OPS_SCHEMA:
            out.append(f"{p}: trace[{i}].table {item['table']} lies in {parts[part]}, a domain's "
                       f"database: a purpose's own tables there live in schema {OPS_SCHEMA} "
                       "(master spec 12.1)")
