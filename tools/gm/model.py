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

# Fault parameters reach inject/ and checks/ scripts as FAULT_<NAME>
# (captures W1-D, W3-A): the name upper-cased, `-` replaced by `_`.
FAULT_ENV_PREFIX = "FAULT_"
FAULT_ENV_NAME_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")


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
_CHECKED_BY_CODE = {"envelope"}


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
        for key in ("name", "id", "setting", "instance"):
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
    return out


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
    elif kind is not None:
        out.append(f"{label}: injection.kind: {kind} is not seed-file or state")
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
    return out


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

    for i, flow in enumerate(data.get("flows") or []):
        if isinstance(flow, dict):
            for end in ("from", "to"):
                if end in flow and flow[end] not in node_names:
                    out.append(f"{label}: flows[{i}].{end}: {flow[end]} is not a node")

    faults = _check_faults(data, nodes, bricks, sdir, catalog_root, out)
    _check_issues(data, nodes, faults, out)
    answer_key = _check_answer_key(data, nodes, faults, sdir, out)
    _check_designed_for(data, nodes, out)

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
        for pname in params:
            if pname not in brick_params:
                out.append(f"{label}: {p}.parameters.{pname}: not a parameter of brick "
                           f"{brick.id}")

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
            if fname not in seed_files:
                out.append(f"{label}: {p}.seed_files: no entry for the brick's seed file "
                           f"{fname}")
        for fname, rel in seed_files.items():
            if fname not in declared:
                out.append(f"{label}: {p}.seed_files.{fname}: not a seed file of brick "
                           f"{brick.id}")
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


def _check_resources(resources, p, out):
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
                out.append(f"scenario.yaml: {p}.{section}.{key}: {exc}")


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


def _check_issues(data, nodes, faults, out):
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
        for iid in issue.get("covers") or []:
            covered.add(iid)
            if iid not in instances:
                out.append(f"{label}: {p}.covers: {iid} is not a fault instance")
                continue
            fault = faults.get(iid)
            node = by_name.get(instances[iid].get("node")) or {}
            if fault is None or expected not in RESOLUTION_KINDS:
                continue
            policies = [r.get("write_policies") or [] for r in fault.data.get("resolutions") or []
                        if isinstance(r, dict) and r.get("kind") == expected]
            if not policies:
                out.append(f"{label}: {p}.expected_resolution: {expected} is not a resolution "
                           f"fault {fault.id} lists ({iid})")
            elif not any(node.get("write_policy") in pol for pol in policies):
                out.append(f"{label}: {p}.expected_resolution: {expected} is not possible "
                           f"under node {node.get('name')}'s write policy "
                           f"{node.get('write_policy')} ({iid})")
    for iid, inst in instances.items():
        visibility = inst.get("visibility")
        if visibility == "known" and iid not in covered:
            out.append(f"{label}: fault_instances[{iid}].visibility: known, but no issue "
                       "covers it")
        elif visibility == "hidden" and iid in covered:
            out.append(f"{label}: fault_instances[{iid}].visibility: hidden, but an issue "
                       "covers it")


def _check_answer_key(data, nodes, faults, sdir, out):
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
        fixable = (by_name.get(instances[iid].get("node")) or {}).get("write_policy") == "fixable"
        acceptable = entry.get("acceptable") or {}
        needs = {"proposal": "propose" in expected or "propose" in kinds,
                 "fix": "fix" in expected or ("fix" in kinds and fixable),
                 "improvement": "improve" in expected or ("improve" in kinds and fixable)}
        for name, needed in needs.items():
            if needed and not acceptable.get(name):
                out.append(f"{label}: instances[{iid}].acceptable.{name}: missing")
    return key


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
