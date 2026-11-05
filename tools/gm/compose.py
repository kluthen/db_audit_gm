"""`gmctl compose`: merge the composed domains' producer fragments into the
scenario folder, at design time (v0.5 master spec 8.4, 15; formats.md
"Producer material"; capture W1 item 7 of specs/versions/v0.5/wave-log.md).

It reads `scenario.yaml`'s `domains:` (the core's variant), `third_parties:`
and `nodes:`, the catalogue's domains, the scenario's own layer
`compose/<node>/` and `merge.yaml`, and writes each target node's ordinary
files under `nodes/<node>/`: a scheduler node's `queries.yaml`,
`schedule.yaml`, `jobs.yaml`, `builders/` and `scripts/`; an `api` node's
`api.yaml`, `routes/` and `db/`. No playground is involved.

- **Layers**, lowest first: the domain layer (each composed domain's
  `producers/<node>/` and `producers/api/<node>/`, and each
  `producers/partners/<partner>/` or `producers/public/<name>/` onto the
  shared nodes, the scheduler and `api` nodes every `third_parties:` entry
  lists; with no entry listing either, a domain's
  `producers/partners/owners/` alone onto `partners-backend` and
  `partners-api`, spec D421, `model.owners_alone_nodes`), the variant layer
  (the same under `variants/<variant>/producers/`), the scenario layer
  (`compose/<node>/`, holding the purposes' material the GM adds and each
  scheduler node's `intensity` and `timeline`). A producer
  folder `composition.yaml`'s `left_out:` names (`pms`, `api/clinic-api`,
  `partners/xlab`; capture W3 item 0, v0.5 chunk 29) is merged from in
  neither layer, and needs no node.
- **Merge units**: `connections.<name>`, `shapes.<name>`, `streams.<key>`,
  `intensity`, `timeline`; `queries.<key>`; `jobs.<name>`; `api.yaml`'s
  `endpoints.<name>` and `connections.<name>`; a file under `builders/`,
  `scripts/`, `routes/` or `db/`, by name. Identical units merge silently; a
  higher layer wins, reported as an override; two sources of one layer
  differing stop the merge until `merge.yaml` resolves the unit.
- **Provenance**: every output entry and file carries `# from <source>:
  <path>`, with `, over <source>` on an override; the report is printed only.
- `--check` writes nothing and fails when a written file would differ.

Every YAML input is read refusing duplicate keys (`model.strict_load`).
"""

from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import model
from .model import GmError

SCENARIO_LAYER = "compose"
MERGE_FILE = "merge.yaml"
COMPOSITION_FILE = "composition.yaml"
LAYER_NAMES = ("domain", "variant", "scenario")
SCHEDULER_FILES = ("queries.yaml", "schedule.yaml", "jobs.yaml")
SCHEDULER_FOLDERS = ("builders", "scripts")
API_FILES = ("api.yaml",)
API_FOLDERS = ("routes", "db")
PARTNER_FOLDERS = ("partners", "public")
# file -> its top-level keys: (key, unit form); a map's units are its keys, a
# list's its items by their key field, a whole value one unit.
UNIT_FORMS = {
    "queries.yaml": (("queries", "map"),),
    "jobs.yaml": (("jobs", "list:name"),),
    "schedule.yaml": (("intensity", "whole"), ("connections", "map"), ("streams", "list:key"),
                      ("shapes", "map"), ("timeline", "whole")),
    "api.yaml": (("endpoints", "map"), ("connections", "map")),
}
SCENARIO_ONLY = ("intensity", "timeline")      # never in a fragment (master spec 8.4)
ALWAYS_WRITTEN = {"queries.yaml": {"queries": {}}, "jobs.yaml": {"jobs": []},
                  "schedule.yaml": {"connections": {}, "streams": []},
                  "api.yaml": {"endpoints": {}}}
RESOLUTION_KEYS = ("node", "file", "entry", "take", "value", "reason")


class ComposeRefused(GmError):
    """compose refused: an input it cannot merge, or a conflict merge.yaml leaves open."""


@dataclass
class Source:
    """One folder of fragments in one layer, aimed at one node."""
    name: str                       # <domain>@<variant>, or scenario
    layer: int                      # index in LAYER_NAMES
    folder: Path
    shown: str                      # the folder, as provenance shows it
    kinds: str                      # scheduler | api

    def path(self, fname):
        return f"{self.shown}/{fname}"


@dataclass
class Entry:
    value: object
    source: Source
    path: str                       # the file, as provenance shows it
    over: list = field(default_factory=list)   # "<source>" overridden, lowest first
    resolved: str = None            # "merge.yaml" note, when a resolution chose it


@dataclass
class Result:
    scenario_dir: Path
    files: dict                     # Path -> bytes, every file compose writes
    overrides: list
    resolutions: list
    check: bool = False
    differing: list = field(default_factory=list)

    def text(self):
        nodes = sorted({p.parent.name if p.parent.name not in SCHEDULER_FOLDERS + API_FOLDERS
                        else p.parent.parent.name for p in self.files})
        lines = [f"compose {self.scenario_dir.name}: {len(nodes)} node(s), "
                 f"{len(self.files)} file(s){' checked' if self.check else ' written'}"]
        for node in nodes:
            names = sorted(str(p.relative_to(self.scenario_dir / 'nodes' / node))
                           for p in self.files if node in p.relative_to(
                               self.scenario_dir / "nodes").parts[:1])
            lines.append(f"  {node}: {', '.join(names)}")
        lines += [f"  override: {o}" for o in self.overrides]
        lines += [f"  resolved: {r}" for r in self.resolutions]
        if self.check:
            lines += [f"  differs: {d}" for d in self.differing] or ["  up to date"]
        return "\n".join(lines)


def _read_yaml(path, shown):
    try:
        return model.strict_load(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ComposeRefused(f"{shown}: missing file") from None
    except (yaml.YAMLError, UnicodeDecodeError) as exc:
        raise ComposeRefused(f"{shown}: cannot be read: {' '.join(str(exc).split())}") from None


def _target_nodes(data):
    """node name -> scheduler | api, from scenario.yaml's nodes."""
    kinds = {}
    for node in data.get("nodes") or []:
        if isinstance(node, dict):
            brick = model.node_brick_id(node)
            if brick == model.SCHEDULER_BRICK:
                kinds[node.get("name")] = "scheduler"
            elif brick == "api":
                kinds[node.get("name")] = "api"
    return kinds


def _shared_nodes(data, kinds):
    """(scheduler node, api node) every third_parties: entry with nodes lists;
    None for a kind none lists."""
    shared = None
    for entry in data.get("third_parties") or []:
        listed = entry.get("nodes") if isinstance(entry, dict) else None
        if not listed:
            continue
        pick = tuple(tuple(sorted(n for n in listed if kinds.get(n) == kind))
                     for kind in ("scheduler", "api"))
        if shared is not None and pick != shared:
            raise ComposeRefused(
                f"scenario.yaml: third_parties[{entry.get('id')}].nodes: {listed} name other "
                f"shared nodes than another entry's ({', '.join(sum(shared, ())) or 'none'}); "
                "every partner shares one back end and one api node")
        shared = pick
    shared = shared or ((), ())
    for kind, names in zip(("scheduler", "api"), shared):
        if len(names) > 1:
            raise ComposeRefused(f"scenario.yaml: third_parties: {len(names)} shared {kind} "
                                 f"nodes ({', '.join(names)}); the partners share one")
    return tuple(names[0] if names else None for names in shared)


def _left_out(sdir, found, catalog_root):
    """{(domain, producer)} composition.yaml's left_out: names (capture W3
    item 0, chunk 29's (b)); ComposeRefused for a malformed list."""
    path = sdir / COMPOSITION_FILE
    if not path.is_file():
        return set()
    content = _read_yaml(path, COMPOSITION_FILE)
    if not isinstance(content, dict):
        return set()                         # check_composition's to report
    problems = []
    model.check_left_out(content, found, catalog_root, COMPOSITION_FILE, problems)
    if problems:
        raise ComposeRefused(f"{COMPOSITION_FILE}: left_out: cannot be applied:\n"
                             + "\n".join(f"  - {p}" for p in problems))
    return model.left_out_of(content)


def _sources(data, sdir, catalog_root, kinds):
    """node -> its sources, in layer order; nothing from a producer folder
    composition.yaml's left_out: names, in either layer."""
    found, problems = model.check_domains_entries(data, catalog_root)
    if problems:
        raise ComposeRefused("scenario.yaml's domains: cannot be composed:\n"
                             + "\n".join(f"  - {p}" for p in problems))
    left_out = _left_out(sdir, found, catalog_root)
    shared_scheduler, shared_api = _shared_nodes(data, kinds)
    owners = model.owners_alone_nodes(data, left_out, catalog_root) \
        if shared_scheduler is None and shared_api is None else None
    if owners is not None and owners.problems:
        raise ComposeRefused("\n".join(owners.problems))
    catalog = Path(catalog_root)
    by_node = {}

    def add(node, kind, source_args, where):
        if node not in kinds:
            raise ComposeRefused(f"{where}: targets node {node}, which scenario.yaml has no "
                                 f"{kind} node of that name")
        if kinds[node] != kind:
            raise ComposeRefused(f"{where}: targets node {node}, a {kinds[node]} node, with "
                                 f"{kind} material")
        by_node.setdefault(node, []).append(Source(*source_args, kinds=kind))

    for entry in data.get("domains") or []:
        did = entry["id"]
        ddata = found[did][1]
        requires = ddata.get("requires")
        core = requires[0] if requires else did
        variant = found[core][0].get("variant")
        name = f"{did}@{variant}"
        roots = [(0, catalog / "domains" / did / "producers"),
                 (1, catalog / "domains" / did / "variants" / str(variant) / "producers")]
        for layer, root in roots:
            if not root.is_dir():
                continue
            shown_root = root.relative_to(catalog).as_posix()
            for folder in sorted(p for p in root.iterdir() if p.is_dir()):
                shown = f"{shown_root}/{folder.name}"
                if folder.name == "api":
                    for sub in sorted(p for p in folder.iterdir() if p.is_dir()):
                        if (did, f"api/{sub.name}") in left_out:
                            continue
                        add(sub.name, "api", (name, layer, sub, f"{shown}/{sub.name}"),
                            f"{shown}/{sub.name}/")
                elif folder.name in PARTNER_FOLDERS:
                    for sub in sorted(p for p in folder.iterdir() if p.is_dir()):
                        if (did, f"{folder.name}/{sub.name}") in left_out:
                            continue
                        where = f"{shown}/{sub.name}/"
                        args = (f"{name}", layer, sub, f"{shown}/{sub.name}")
                        to_scheduler, to_api = (owners.scheduler, owners.api) \
                            if owners is not None and where in owners.routes \
                            else (shared_scheduler, shared_api)
                        if any((sub / f).exists() for f in SCHEDULER_FILES + SCHEDULER_FOLDERS):
                            if to_scheduler is None:
                                raise ComposeRefused(f"{where}: partner material, but no "
                                                     "third_parties: entry lists a scheduler "
                                                     "node")
                            add(to_scheduler, "scheduler", args, where)
                        if any((sub / f).exists() for f in API_FILES + API_FOLDERS):
                            if to_api is None:
                                raise ComposeRefused(f"{where}: partner endpoints, but no "
                                                     "third_parties: entry lists an api node")
                            add(to_api, "api", args, where)
                elif (did, folder.name) not in left_out:
                    add(folder.name, "scheduler", (name, layer, folder, shown), f"{shown}/")
    layer_root = sdir / SCENARIO_LAYER
    if layer_root.is_dir():
        for folder in sorted(p for p in layer_root.iterdir() if p.is_dir()):
            shown = f"{SCENARIO_LAYER}/{folder.name}"
            add(folder.name, kinds.get(folder.name, "scheduler"),
                ("scenario", 2, folder, shown), f"{shown}/")
    return by_node


def _units(source):
    """(file, entry) -> (value, path) of one source, refusing what no layer
    of its kind may hold."""
    files, folders = (SCHEDULER_FILES, SCHEDULER_FOLDERS) if source.kinds == "scheduler" \
        else (API_FILES, API_FOLDERS)
    if source.layer < 2 and source.kinds == "scheduler" and source.folder.parent.name in \
            PARTNER_FOLDERS:
        files, folders = SCHEDULER_FILES, SCHEDULER_FOLDERS       # a partner's back end
    elif source.layer < 2 and source.folder.parent.name in PARTNER_FOLDERS:
        files, folders = API_FILES, API_FOLDERS                   # a partner's endpoints
    partner = source.folder.parent.name in PARTNER_FOLDERS
    units = {}
    for path in sorted(source.folder.iterdir()):
        shown = source.path(path.name)
        if path.is_dir() and path.name in folders:
            for item in sorted(path.iterdir()):
                if not item.is_file():
                    raise ComposeRefused(f"{shown}/{item.name}: not a file ({path.name}/ holds "
                                         "files only)")
                units[(path.name, item.name)] = (item.read_bytes(), f"{shown}/{item.name}")
            continue
        if path.is_file() and path.name in files:
            content = _read_yaml(path, shown)
            if content is None:
                continue
            if not isinstance(content, dict):
                raise ComposeRefused(f"{shown}: top level: not a mapping")
            forms = dict(UNIT_FORMS[path.name])
            for key, value in content.items():
                if key not in forms:
                    raise ComposeRefused(f"{shown}: {key}: not a key of {path.name} "
                                         f"({', '.join(forms)})")
                if key in SCENARIO_ONLY and source.layer < 2:
                    raise ComposeRefused(f"{shown}: {key}: a fragment never carries one; "
                                         f"it is the scenario's ({SCENARIO_LAYER}/<node>/)")
                for entry, item in _split(value, forms[key], f"{shown}: {key}"):
                    if (path.name, entry) in units:
                        raise ComposeRefused(f"{shown}: {entry}: twice in one file")
                    units[(path.name, entry)] = (item, shown)
            continue
        if partner and source.layer < 2:
            continue                         # the partner's other half, for the other node
        raise ComposeRefused(f"{shown}{'/' if path.is_dir() else ''}: not material for a "
                             f"{source.kinds} node ({', '.join(files + tuple(f + '/' for f in folders))})")
    return units


def _split(value, form, where):
    key = where.rsplit(": ", 1)[1]
    if form == "whole":
        yield key, value
    elif form == "map":
        if not isinstance(value, dict):
            raise ComposeRefused(f"{where}: not a mapping")
        for name, item in value.items():
            yield f"{key}.{name}", item
    else:
        field_name = form.split(":", 1)[1]
        if not isinstance(value, list):
            raise ComposeRefused(f"{where}: not a list")
        for item in value:
            if not (isinstance(item, dict) and isinstance(item.get(field_name), str)):
                raise ComposeRefused(f"{where}: an item without its {field_name}")
            yield f"{key}.{item[field_name]}", item


def _read_merge(sdir):
    path = sdir / MERGE_FILE
    if not path.is_file():
        return []
    content = _read_yaml(path, MERGE_FILE)
    resolutions = content.get("resolutions") if isinstance(content, dict) else None
    if not isinstance(content, dict) or set(content) != {"resolutions"} \
            or not isinstance(resolutions, list):
        raise ComposeRefused(f"{MERGE_FILE}: not {{resolutions: [...]}} (template merge.yaml)")
    out = []
    for i, res in enumerate(resolutions):
        p = f"{MERGE_FILE}: resolutions[{i}]"
        if not isinstance(res, dict):
            raise ComposeRefused(f"{p}: not a mapping")
        unknown = [k for k in res if k not in RESOLUTION_KEYS]
        missing = [k for k in ("node", "file", "entry", "reason") if not res.get(k)]
        if unknown or missing or (("take" in res) == ("value" in res)):
            raise ComposeRefused(
                f"{p}: needs node, file, entry, reason and exactly one of take and value"
                + (f"; unknown {', '.join(unknown)}" if unknown else "")
                + (f"; missing {', '.join(missing)}" if missing else ""))
        key = (res["node"], res["file"], res["entry"])
        if any(key == (r["node"], r["file"], r["entry"]) for r in out):
            raise ComposeRefused(f"{p}: a second resolution of {' '.join(key)}")
        out.append(res)
    return out


def _merge_node(node, sources, resolutions, used, conflicts, overrides, notes):
    """unit -> Entry for one node, layer by layer."""
    merged = {}
    for layer in range(len(LAYER_NAMES)):
        candidates = {}
        for source in (s for s in sources if s.layer == layer):
            for unit, (value, path) in _units(source).items():
                candidates.setdefault(unit, []).append(Entry(value, source, path))
        for unit, entries in candidates.items():
            fname, entry_name = unit
            distinct = []
            for e in entries:
                if not any(e.value == d.value for d in distinct):
                    distinct.append(e)
            chosen = distinct[0]
            if len(distinct) > 1:
                res = next((r for r in resolutions if (r["node"], r["file"], r["entry"])
                            == (node, fname, entry_name)), None)
                sides = " and ".join(f"{e.source.name}: {e.path}" for e in distinct)
                if res is None:
                    conflicts.append(f"{node} {fname} {entry_name}: {sides} differ")
                    continue
                used.add(id(res))
                if "take" in res:
                    picks = [e for e in distinct if res["take"] in (e.source.name, e.path)]
                    if len(picks) != 1:
                        conflicts.append(
                            f"{node} {fname} {entry_name}: {MERGE_FILE} takes "
                            f"{res['take']!r}, which names {len(picks)} of {sides} (name a "
                            "source by its catalogue path when two share a name)")
                        continue
                    chosen = picks[0]
                    chosen.resolved = f"taken by {MERGE_FILE}"
                else:
                    value = res["value"]
                    if fname in SCHEDULER_FOLDERS + API_FOLDERS:
                        value = str(value).encode("utf-8")
                    chosen = Entry(value, Source(MERGE_FILE, layer, Path(MERGE_FILE),
                                                 MERGE_FILE, distinct[0].source.kinds),
                                   MERGE_FILE, resolved="written by merge.yaml")
                chosen.over = [f"{e.source.name}: {e.path}" for e in distinct if e is not chosen]
                notes.append(f"{node} {fname} {entry_name}: {chosen.source.name} "
                             f"({res['reason']})")
            previous = merged.get(unit)
            if previous is not None:
                if previous.value == chosen.value:
                    continue
                chosen.over = previous.over + [f"{previous.source.name}: {previous.path}"] \
                    + chosen.over
                overrides.append(f"{node} {fname} {entry_name}: {chosen.source.name} "
                                 f"({chosen.path}) over {previous.source.name} "
                                 f"({previous.path})")
            merged[unit] = chosen
    return merged


class _Dumper(yaml.SafeDumper):
    pass


def _represent_str(dumper, value):
    style = "|" if "\n" in value else None
    return dumper.represent_scalar("tag:yaml.org,2002:str", value, style=style)


_Dumper.add_representer(str, _represent_str)


def _dump(value):
    return yaml.dump(value, Dumper=_Dumper, sort_keys=False, default_flow_style=False,
                     allow_unicode=True, width=100)


def _indent(text, by):
    return "".join(by + line if line.strip() else line for line in text.splitlines(True))


def _provenance(entry):
    over = f", over {', '.join(entry.over)}" if entry.over else ""
    how = f" ({entry.resolved})" if entry.resolved else ""
    return f"from {entry.source.name}: {entry.path}{over}{how}"


def _render_yaml(fname, merged, node):
    header = (f"# {fname} of node {node}, composed by gmctl compose (v0.5 master spec 8.4):\n"
              "# rerun it rather than edit this file; each entry names its source.\n")
    body = []
    for key, form in UNIT_FORMS[fname]:
        units = [(entry, e) for (f, entry), e in merged.items()
                 if f == fname and (entry == key or entry.startswith(key + "."))]
        if not units:
            if key in ALWAYS_WRITTEN.get(fname, {}):
                body.append(_dump({key: ALWAYS_WRITTEN[fname][key]}).replace("...\n", ""))
            continue
        if form == "whole":
            entry = units[0][1]
            body.append(f"# {_provenance(entry)}\n" + _dump({key: entry.value}))
            continue
        lines = [f"{key}:\n"]
        for name, entry in units:
            item = {name[len(key) + 1:]: entry.value} if form == "map" else [entry.value]
            lines.append(f"  # {_provenance(entry)}\n" + _indent(_dump(item), "  "))
        body.append("".join(lines))
    return (header + "".join(body)).encode("utf-8")


def _render_file(entry):
    text = entry.value.decode("utf-8", errors="replace") if isinstance(entry.value, bytes) \
        else str(entry.value)
    mark = "--" if entry.path.endswith(".sql") else "#"
    line = f"{mark} {_provenance(entry)}\n"
    if text.startswith("#!"):
        first, _, rest = text.partition("\n")
        return (first + "\n" + line + rest).encode("utf-8")
    return (line + text).encode("utf-8")


def compose(scenario_dir, catalog_root=model.REPO_ROOT, check=False):
    """Merge the scenario's layers; write (or, with `check`, compare) the
    target nodes' files. Raises ComposeRefused on a conflict, a stale or
    malformed merge.yaml or an input it cannot read."""
    sdir = Path(scenario_dir).resolve()
    data = _read_yaml(sdir / "scenario.yaml", "scenario.yaml")
    if not isinstance(data, dict) or "domains" not in data:
        raise ComposeRefused("scenario.yaml: no domains: to compose (a scenario listing "
                             "domain: keeps its hand-copied files)")
    kinds = _target_nodes(data)
    by_node = _sources(data, sdir, catalog_root, kinds)
    resolutions = _read_merge(sdir)
    used, conflicts, overrides, notes, files = set(), [], [], [], {}
    for node in sorted(by_node):
        merged = _merge_node(node, by_node[node], resolutions, used, conflicts, overrides,
                             notes)
        out_dir = sdir / "nodes" / node
        names = SCHEDULER_FILES if kinds[node] == "scheduler" else API_FILES
        for fname in names:
            files[out_dir / fname] = _render_yaml(fname, merged, node)
        for (fname, entry), e in merged.items():
            if fname in SCHEDULER_FOLDERS + API_FOLDERS:
                files[out_dir / fname / entry] = _render_file(e)
    stale = [r for r in resolutions if id(r) not in used]
    problems = [f"conflict: {c}" for c in conflicts] + [
        f"{MERGE_FILE}: the resolution of {r['node']} {r['file']} {r['entry']} meets no "
        "conflict (stale)" for r in stale]
    if problems:
        raise ComposeRefused(
            "not merged:\n" + "\n".join(f"  - {p}" for p in problems)
            + ("\n  resolve each conflict in merge.yaml (node, file, entry, take or value, "
               "reason)" if conflicts else ""))
    result = Result(sdir, files, overrides, notes, check=check)
    for path, content in sorted(files.items()):
        current = path.read_bytes() if path.is_file() else None
        if current != content:
            result.differing.append(str(path.relative_to(sdir)))
        if not check and current != content:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    return result

