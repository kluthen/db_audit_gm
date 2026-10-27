"""`gmctl fit`: capacity check of a scenario against a declared playground.

Master spec 10.3 and 11; command line and files fixed by capture W2-A.
The scenario's resource limits and envelopes are absolute in v0.1: the
check compares, it never recomputes (recomputing could turn a deliberately
planted out-of-bounds value into an in-bounds one).

v0.2 (master spec 8, spec D83 and D102): the disk also holds the images.
`fit` reads their sizes from the playground's engine, each layer counted
once however many images hold it, and refuses a missing image with its
build command, so it needs the engine reachable. Refusals about the engine
write nothing.

v0.3 (master spec 6.4, 8.6, 10.2 and 12; capture W3, items 1, 2 and 5 of
`specs/versions/v0.3/wave-log.md`): the playground declares a list of
hosts and maps the scenario's designed hosts onto them (`--host`, `--map`;
today's one-host form reads as a list of one). Each node is placed on a
host, recorded as `nodes.<n>.host`; each host is checked against the nodes
placed on it, its disk holding the images of those nodes, each counted
once, and the volumes' growth per hour (`footprint.disk_growth_per_hour`)
over the scenario's aging plus a four-hour game. The hand-over snapshot's
copies are counted on each host after the game's own disk; the verdict,
one for the game, is `implementation.yaml`'s `snapshot_fit`. The images
are read on the manager, which holds every image of the game.
"""

import re
import shlex
from dataclasses import dataclass, field
from pathlib import Path

from . import localimpl
from .docker import (Docker, DockerError, EngineUnreachable, engine_name, inspect_image,
                     server_version, swarm_nodes)
from .model import (REPO_ROOT, GmError, format_size, has_scheduler_nodes, load_scenario,
                    parse_cpu, parse_duration, parse_size)

# Headroom kept free on every dimension, as a share of the declared capacity
# (master spec 10.3: "the sum of reservations plus headroom").
HEADROOM = 0.10
GAME_SECONDS = 4 * 3600         # a game lasts at most four hours (master spec 10.1)

ENDPOINT_RE = re.compile(r"^(ssh|tcp|unix)://\S+$")
# A host's name is its swarm node name; it also names its Docker context
# (`dbagm-<host>`, W3 item 3), so no character a context name refuses.
HOST_NAME_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,62}$")
HOST_KEYS = ("endpoint", "cpu", "memory", "disk")
CAPACITY_KEYS = ("cpu", "memory", "disk")


@dataclass
class CapacityReport:
    ok: bool
    lines: list = field(default_factory=list)
    problems: list = field(default_factory=list)
    snapshot_fits: bool = True      # the hand-over snapshot's copies fit after the game
    snapshot_why: str = None        # the line saying why not


def _fmt(key, value):
    return f"{value:g}" if key == "cpu" else format_size(value)


@dataclass
class ImageFootprint:
    """The scenario's images on the engine: `size` counts each layer once
    (an image whose layers could not be sized counts whole)."""
    engine: str
    images: list                    # docker.Image, one per distinct image name
    size: int
    layers: int                     # distinct layers counted
    shared: int                     # of which held by more than one image

    def line(self):
        each = ", ".join(f"{im.name} {format_size(im.size)}" for im in self.images)
        return (f"images on {self.engine}: {each}; {self.layers} layers, {self.shared} "
                f"shared, each counted once: {format_size(self.size)}")


def scenario_images(scenario):
    """`(image, brick)` per distinct image of the scenario's nodes, in node order."""
    out = {}
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        out.setdefault(str(brick.data["image"]), brick)
    return list(out.items())


def build_command(docker, image, brick, catalog_root=REPO_ROOT):
    """The command that builds `image` on the targeted engine, from the
    catalog root (the brick's folder relative to it when inside it)."""
    folder = Path(brick.dir).resolve()
    try:
        folder = folder.relative_to(Path(catalog_root).resolve())
    except ValueError:
        pass
    return shlex.join(docker.command(["build", "-t", image, folder.as_posix()]))


def image_footprint(scenario, docker, catalog_root=REPO_ROOT):
    """Read the scenario's images from the engine. Raises GmError when the
    engine does not answer or an image is missing (naming its build
    command); changes nothing."""
    return count_images(read_images(scenario, docker, catalog_root), docker.describe())


def read_images(scenario, docker, catalog_root=REPO_ROOT):
    """The scenario's images as the engine holds them (docker.Image, one per
    distinct name); GmError as image_footprint says."""
    try:
        server_version(docker)
    except EngineUnreachable as exc:
        raise GmError(f"{exc}. fit reads the images' sizes from the playground's engine: "
                      "start it or correct the endpoint (--endpoint), then gmctl fit again; "
                      "nothing written") from None
    images, missing = [], []
    for name, brick in scenario_images(scenario):
        try:
            image = inspect_image(docker, name)
        except DockerError as exc:
            raise GmError(f"cannot read image {name} on {docker.describe()}: "
                          f"{' '.join(exc.stderr.split())}; nothing written") from None
        if image is None:
            command = build_command(docker, name, brick, catalog_root)
            missing.append(f"{name} (build it: {command})")
        else:
            images.append(image)
    if missing:
        raise GmError(f"image(s) not on {docker.describe()}: {'; '.join(missing)}; then gmctl "
                      "fit again; nothing written")
    return images


def count_images(images, engine):
    """The ImageFootprint of `images` on one engine: each layer counted once."""
    holders, sizes, size = {}, {}, 0
    for image in images:
        if not image.layers:
            size += image.size
            continue
        for chain, layer_size in image.layers:
            holders[chain] = holders.get(chain, 0) + 1
            sizes[chain] = layer_size
    size += sum(sizes.values())
    layers = len(sizes) + sum(1 for im in images if not im.layers)
    shared = sum(1 for count in holders.values() if count > 1)
    return ImageFootprint(engine=engine, images=images, size=size, layers=layers,
                          shared=shared)


def aging_seconds(scenario):
    """The scenario's aging, aging.minimum, in seconds: 0 with no scheduler
    node (no aging, D157, D158). `fit` runs before the planned hand-over is
    known, so the minimum is the aging it can count."""
    if not has_scheduler_nodes(scenario.data):
        return 0
    return parse_duration((scenario.data.get("aging") or {}).get("minimum"))


def growth_per_hour(scenario, node):
    """The node's brick's `footprint.disk_growth_per_hour`, in bytes (0 when
    the brick declares none)."""
    footprint = scenario.bricks[node["name"]].data.get("footprint") or {}
    return parse_size(footprint.get("disk_growth_per_hour") or 0)


def _hours(seconds):
    return f"{seconds / 3600:g}h"


def capacity_check(scenario, capacity, images, nodes=None):
    """Sum of reservations plus headroom against one host's capacity, for
    the nodes placed there (`nodes`, by default all): the disk holds the
    images' footprint (an ImageFootprint) and the volumes' growth over the
    scenario's aging plus a four-hour game; every node's limits against the
    host. Then the hand-over snapshot's copies (each node's volumes at
    hand-over: reserved disk plus the aging's growth) after the game's disk.
    Reads the scenario; changes nothing."""
    nodes = scenario.nodes if nodes is None else nodes
    parsers = {"cpu": parse_cpu, "memory": parse_size, "disk": parse_size}
    cap = {key: parsers[key](capacity[key]) for key in parsers}
    aging = aging_seconds(scenario)
    rates = sum(growth_per_hour(scenario, node) for node in nodes)
    growth = int(round(rates * (aging + GAME_SECONDS) / 3600))
    lines, problems = [], []
    disk_need = 0
    for key, parse in parsers.items():
        reserved = sum(parse(node["resources"]["reservations"][key]) for node in nodes)
        headroom = cap[key] * HEADROOM
        need = reserved + headroom
        terms = f"reservations {_fmt(key, reserved)}"
        if key == "disk":
            lines.append(images.line())
            need += images.size + growth
            terms += f" + images {_fmt(key, images.size)}"
            terms += f" + growth {_fmt(key, growth)} ({_hours(aging + GAME_SECONDS)})"
            disk_need = need
        verdict = "ok" if need <= cap[key] else "too much"
        line = (f"{key}: {terms} + headroom {_fmt(key, headroom)}"
                f" = {_fmt(key, need)} of {_fmt(key, cap[key])}: {verdict}")
        lines.append(line)
        if need > cap[key]:
            problems.append(line)
    for node in nodes:
        limits = node["resources"]["limits"]
        parts = []
        for key in ("cpu", "memory"):
            limit = parsers[key](limits[key])
            if limit > cap[key]:
                problems.append(f"node {node['name']}: {key} limit {_fmt(key, limit)} is more "
                                f"than the host's {_fmt(key, cap[key])}")
                parts.append(f"{key} {_fmt(key, limit)} too much")
            else:
                parts.append(f"{key} {_fmt(key, limit)} ok")
        lines.append(f"node {node['name']}: limits {', '.join(parts)}")
    reserved = sum(parse_size(node["resources"]["reservations"]["disk"]) for node in nodes)
    aged = int(round(rates * aging / 3600))
    copies = reserved + aged
    fits = disk_need + copies <= cap["disk"]
    terms = (f"reservations {format_size(reserved)} + growth {format_size(aged)} over "
             f"{_hours(aging)} of aging" if aging else f"reservations {format_size(reserved)}, "
             "no aging")
    snapshot = (f"snapshot: copies {format_size(copies)} ({terms}) after the game's "
                f"{format_size(disk_need)} = {format_size(disk_need + copies)} of "
                f"{format_size(cap['disk'])}: {'fits' if fits else 'does not fit'}")
    lines.append(snapshot)
    return CapacityReport(ok=not problems, lines=lines, problems=problems,
                          snapshot_fits=fits, snapshot_why=None if fits else snapshot)


@dataclass
class HostCheck:
    """One host's part of the capacity check."""
    host: dict                      # the declared host
    nodes: list                     # names of the nodes placed on it
    report: CapacityReport


def placed_capacity_check(scenario, declared, placement, images, engine):
    """capacity_check per declared host, each against the nodes `placement`
    puts there and their images on it (`images`: docker.Image read on the
    manager, `engine` its description). Returns `(CapacityReport for the
    game, [HostCheck])`; on one host the game's report is the host's."""
    hosts = localimpl.playground_hosts(declared)
    checks = []
    for host in hosts:
        name = host.get("name")
        nodes = [n for n in scenario.nodes
                 if len(hosts) == 1 or placement[n["name"]] == name]
        wanted = {str(scenario.bricks[n["name"]].data["image"]) for n in nodes}
        held = count_images([im for im in images if im.name in wanted],
                            engine if len(hosts) == 1 else name)
        checks.append(HostCheck(host, [n["name"] for n in nodes],
                                capacity_check(scenario, host["capacity"], held, nodes)))
    if len(checks) == 1:
        return checks[0].report, checks
    lines, problems, why = [], [], None
    for check in checks:
        host = check.host
        where = host.get("docker_endpoint") or "local engine"
        role = "manager, " if host.get("manager") else ""
        lines.append(f"host {host['name']} ({role}{where}): nodes "
                     f"{', '.join(check.nodes) or 'none'}")
        lines += [f"  {line}" for line in check.report.lines]
        problems += [f"host {host['name']}: {p}" for p in check.report.problems]
        if why is None and not check.report.snapshot_fits:
            why = f"host {host['name']}: {check.report.snapshot_why}"
    return CapacityReport(ok=not problems, lines=lines, problems=problems,
                          snapshot_fits=why is None, snapshot_why=why), checks


@dataclass
class FitResult:
    ok: bool
    scenario_id: str
    playground: dict
    local_dir: Path
    report: CapacityReport
    game_id: str = None

    def text(self):
        pg = self.playground
        out = [f"Scenario {self.scenario_id}"]
        if localimpl.is_list_form(pg):
            hosts = localimpl.playground_hosts(pg)
            out.append(f"Playground {pg['name']}: {pg['platform']}, {len(hosts)} host(s)")
            for host in hosts:
                cap = host["capacity"]
                out.append(f"  host {host['name']}{' (manager)' if host.get('manager') else ''}"
                           f": {host.get('docker_endpoint') or 'local engine'}, capacity cpu "
                           f"{cap['cpu']}, memory {cap['memory']}, disk {cap['disk']}")
            mapping = pg.get("mapping") or {}
            if mapping:
                out.append("  mapping: " + ", ".join(f"{d} -> {h}" for d, h in mapping.items()))
        else:
            cap = pg["capacity"]
            endpoint = pg.get("docker_endpoint") or "local engine"
            out.append(f"Playground {pg['name']}: {pg['platform']}, {endpoint}, capacity cpu "
                       f"{cap['cpu']}, memory {cap['memory']}, disk {cap['disk']}")
        out.append(f"Capacity check (headroom {HEADROOM:.0%} of capacity, nothing recomputed):")
        out += [f"  {line}" for line in self.report.lines]
        if self.ok:
            out.append(f"Result: fits. Game id {self.game_id}.")
            if not self.report.snapshot_fits:
                out.append(f"The hand-over snapshot does not fit ({self.report.snapshot_why}): "
                           "this game will have no snapshot, and a restart starts from "
                           "nothing (master spec 12).")
            out.append(f"Wrote {self.local_dir}/{localimpl.IMPLEMENTATION_FILE} and "
                       f"{localimpl.STATE_FILE} (stage fitted).")
        else:
            out.append("Result: does not fit; nothing deployed.")
            out += [f"  - {p}" for p in self.report.problems]
        return "\n".join(out)


def _number(value):
    cpu = parse_cpu(value)
    return int(cpu) if cpu == int(cpu) else cpu


def _capacity(given):
    """`given` ({cpu, memory, disk} as typed) checked and normalised."""
    out = dict(given)
    try:
        if "cpu" in out:
            out["cpu"] = _number(out["cpu"])
        for key in ("memory", "disk"):
            if key in out:
                parse_size(out[key])
                out[key] = str(out[key])
    except ValueError as exc:
        raise GmError(str(exc)) from None
    return out


def _check_endpoint(endpoint, what="endpoint"):
    if endpoint is not None and not ENDPOINT_RE.match(str(endpoint)):
        raise GmError(f"{what} {endpoint!r}: expected a Docker endpoint such as "
                      "ssh://user@host (never keys)")


def parse_host(spec):
    """One `--host <name>[,manager][,endpoint=<url>],cpu=N,memory=SIZE,disk=SIZE`
    as a declared host (W3 item 1); a host with no endpoint is the local
    engine."""
    parts = [part.strip() for part in str(spec).split(",")]
    name = parts[0]
    if not HOST_NAME_RE.match(name):
        raise GmError(f"--host {spec!r}: {name!r} is not a swarm node name (letters, digits, "
                      "'.', '_', '-')")
    host = {"name": name, "docker_endpoint": None, "manager": False, "capacity": {}}
    given = {}
    for part in parts[1:]:
        if part == "manager":
            host["manager"] = True
            continue
        key, sep, value = part.partition("=")
        if not sep or key not in HOST_KEYS or not value:
            raise GmError(f"--host {spec!r}: {part!r}: expected manager or one of "
                          f"{', '.join(k + '=' for k in HOST_KEYS)}")
        if key == "endpoint":
            _check_endpoint(value, f"--host {name}: endpoint")
            host["docker_endpoint"] = value
        else:
            given[key] = value
    missing = [key for key in CAPACITY_KEYS if key not in given]
    if missing:
        raise GmError(f"--host {spec!r}: give its {', '.join(k + '=' for k in missing)} "
                      "(memory: what the host has available, master spec 10.1)")
    host["capacity"] = {key: _capacity(given)[key] for key in CAPACITY_KEYS}
    return host


def parse_mapping(specs):
    """The `--map <designed host>=<host>` options as the mapping."""
    mapping = {}
    for spec in specs:
        designed, sep, host = str(spec).partition("=")
        if not sep or not designed or not host:
            raise GmError(f"--map {spec!r}: expected <designed host>=<host> (host-1=armenelos)")
        if designed in mapping:
            raise GmError(f"--map: designed host {designed} mapped twice")
        mapping[designed] = host
    return mapping


def playground_declaration(ldir, name, endpoint=None, cpu=None, memory=None, disk=None,
                           hosts=None, mapping=None):
    """The playground's declaration, from playground.yaml and the options,
    checked but not written: `(declaration, what playground.yaml holds)`.
    `hosts` (the `--host` options) replaces the whole host list, `mapping`
    (the `--map` options) the whole mapping (W3 item 1); `endpoint`, `cpu`,
    `memory` and `disk` are today's one-host form's."""
    existing = localimpl.read_playground(ldir)
    given = {k: v for k, v in (("cpu", cpu), ("memory", memory), ("disk", disk))
             if v is not None}
    one_host = given or endpoint is not None
    if hosts or mapping:
        if hosts and one_host:
            raise GmError("--endpoint, --cpu, --memory and --disk are the one-host form's: "
                          "give each host's in its --host")
        listed = [parse_host(spec) for spec in hosts] if hosts else None
        if listed is None:
            if not localimpl.is_list_form(existing):
                raise GmError(f"--map maps onto declared hosts: declare playground {name}'s "
                              "with --host")
            listed = localimpl.playground_hosts(existing)
        kept = (existing or {}).get("mapping") if localimpl.is_list_form(existing) else None
        declared = {"name": name, "platform": localimpl.PLATFORM, "hosts": listed,
                    "mapping": parse_mapping(mapping) if mapping else dict(kept or {})}
        return declared, existing
    if localimpl.is_list_form(existing):
        listed = localimpl.playground_hosts(existing)
        if one_host and len(listed) > 1:
            raise GmError(f"playground {name} declares {len(listed)} hosts: --endpoint, --cpu, "
                          "--memory and --disk are the one-host form's; give the whole list "
                          "again with --host")
        if one_host:
            _check_endpoint(endpoint)
            host = listed[0]
            host["capacity"] = dict(host.get("capacity") or {}, **_capacity(given))
            if endpoint is not None:
                host["docker_endpoint"] = endpoint
        return dict(existing, hosts=listed), existing
    if existing is None and len(given) < 3:
        raise GmError(f"playground {name} is not declared yet: give --cpu, --memory and "
                      "--disk, or its hosts with --host")
    _check_endpoint(endpoint)
    given = _capacity(given)
    declared = existing or {"name": name, "platform": localimpl.PLATFORM,
                            "docker_endpoint": None, "capacity": {}}
    updated = dict(declared, capacity=dict(declared.get("capacity") or {}, **given))
    if endpoint is not None:
        updated["docker_endpoint"] = endpoint
    return updated, existing


def check_declaration(scenario, declared):
    """Refuses (GmError, nothing written) a declaration `fit` cannot place
    the scenario on (W3 items 1 and 2): no host or two managers, a host
    named twice or its capacity incomplete; on several hosts, a designed
    host unmapped or unknown, a mapping onto an undeclared host, and a node
    publishing ports placed off the manager."""
    pg = declared["name"]
    hosts = localimpl.playground_hosts(declared)
    if not localimpl.is_list_form(declared):
        return
    problems = []
    names = [h.get("name") for h in hosts]
    if not hosts:
        problems.append("no host declared")
    managers = [h["name"] for h in hosts if h.get("manager") is True]
    if hosts and len(managers) != 1:
        problems.append(f"{len(managers)} hosts flagged manager ({', '.join(managers) or 'none'}"
                        "): exactly one is")
    seen = set()
    for host in hosts:
        if not HOST_NAME_RE.match(str(host.get("name"))):
            problems.append(f"host {host.get('name')!r}: not a swarm node name")
        elif host["name"] in seen:
            problems.append(f"host {host['name']} declared twice")
        seen.add(host.get("name"))
        cap = host.get("capacity") or {}
        missing = [key for key in CAPACITY_KEYS if key not in cap]
        if missing:
            problems.append(f"host {host.get('name')}: capacity has no "
                            f"{', '.join(missing)}")
    mapping = declared.get("mapping") or {}
    designed = localimpl.designed_hosts(scenario)
    for key, target in mapping.items():
        if key not in designed:
            problems.append(f"--map {key}={target}: {key} is not a designed host of scenario "
                            f"{scenario.id} ({', '.join(designed) or 'it declares none'})")
        if target not in names:
            problems.append(f"--map {key}={target}: {target} is not a declared host "
                            f"({', '.join(map(str, names))})")
    if len(hosts) > 1:
        if not designed:
            problems.append(f"scenario {scenario.id} declares no designed_for.hosts: it can "
                            "only be fitted on one host")
        for name in designed:
            if name not in mapping:
                problems.append(f"designed host {name} is not mapped onto a host (--map "
                                f"{name}=<host>)")
    if problems:
        raise GmError(f"playground {pg}: " + "; ".join(problems) + "; nothing written")
    if len(hosts) > 1:
        placement = localimpl.node_hosts(scenario, declared, None)
        manager = localimpl.manager_host(declared)["name"]
        designed_of = (scenario.data.get("designed_for") or {}).get("placement") or {}
        for node in scenario.nodes:
            host = placement[node["name"]]
            if node.get("published_ports") and host != manager:
                designed_host = designed_of.get(node["name"])
                problems.append(
                    f"node {node['name']} publishes ports and would be placed on {host}, not "
                    f"the manager {manager}: a host-mode port opens on every address of its "
                    f"host, a public one included; map {designed_host} onto {manager} "
                    f"(--map {designed_host}={manager})")
    if problems:
        raise GmError(f"playground {pg}: " + "; ".join(problems) + "; nothing written")


def check_engine_hosts(docker, declared):
    """The manager's engine against the declaration (W3 item 1): the name
    of the one host (the engine's own in today's form, which is returned;
    a declared one must match it); on several hosts, every host listed by
    the manager's `docker node ls` under its name, the manager as a
    manager. GmError, nothing written, otherwise."""
    hosts = localimpl.playground_hosts(declared)
    pg = declared["name"]
    if len(hosts) == 1:
        try:
            own = engine_name(docker)
        except DockerError as exc:
            raise GmError(f"cannot read the engine's name on {docker.describe()}: "
                          f"{' '.join(exc.stderr.split())}; nothing written") from None
        declared_name = hosts[0].get("name")
        if declared_name is not None and declared_name != own:
            raise GmError(f"playground {pg}: host {declared_name} is declared, but the engine "
                          f"{docker.describe()} is {own}; nothing written")
        return own
    try:
        nodes = swarm_nodes(docker)
    except DockerError as exc:
        raise GmError(f"playground {pg} declares {len(hosts)} hosts, but {docker.describe()} "
                      f"cannot list the swarm's nodes ({' '.join(exc.stderr.split())}): its "
                      "manager must answer docker node ls; nothing written") from None
    problems = []
    for host in hosts:
        node = nodes.get(host["name"])
        if node is None:
            problems.append(f"host {host['name']} is not a node of the swarm "
                            f"({', '.join(sorted(nodes)) or 'none listed'})")
        elif host.get("manager") and not node["manager_status"]:
            problems.append(f"host {host['name']} is flagged manager but is a worker of the "
                            "swarm")
    if problems:
        raise GmError(f"playground {pg}: " + "; ".join(problems) + "; nothing written")
    return localimpl.manager_host(declared)["name"]


# Failure stages of a failed game that had been deployed (deploy, load-data, inject;
# `handed-over`: a failed restart, chunk 11).
AFTER_DEPLOYMENT = ("deployed", "data-loaded", "injected", "handed-over")


def _refusal(state):
    """Why `fit` refuses a game that may have resources on the platform,
    and what unblocks it."""
    gid = state.get("game_id")
    stage = state.get("stage")
    failed_before = (state.get("failure") or {}).get("stage")
    if stage == localimpl.FAILED:
        text = (f"game {gid} on this playground failed before stage {failed_before} and its "
                "teardown is not recorded: run gmctl teardown, then gmctl fit again")
        if failed_before == "deployed":
            text += ", or run gmctl deploy to retry the deploy"
        elif failed_before == "handed-over":
            text += ", or run gmctl restart to retry the restart"
    else:
        text = (f"game {gid} on this playground is at stage {stage}: run gmctl teardown, "
                "then gmctl fit again")
    return text + "; nothing written"


def _game_to_keep(ldir, scenario_id):
    """The game id to keep on a refit, None for a new one; GmError if the
    game may have resources on the platform.

    A new game after `torn-down`, or after a failed game whose failure came
    after deployment and whose teardown is recorded (nothing labelled with
    its id is left; spec D51)."""
    state = localimpl.read_state(ldir)
    if state is None:
        return None
    stage = state.get("stage")
    failure = state.get("failure") or {}
    before_deploy = stage in ("fitted", "rendered") or (
        stage == localimpl.FAILED and failure.get("stage") in ("fitted", "rendered"))
    if stage == localimpl.TORN_DOWN:
        return None
    if (stage == localimpl.FAILED and failure.get("stage") in AFTER_DEPLOYMENT
            and localimpl.teardown_record(state) is not None):
        return None
    if not before_deploy:
        raise GmError(_refusal(state))
    impl = localimpl.read_yaml(ldir / localimpl.IMPLEMENTATION_FILE) or {}
    if (impl.get("scenario") or {}).get("id") != scenario_id:
        return None
    return state.get("game_id")


def fit(scenario_dir, playground, endpoint=None, cpu=None, memory=None, disk=None,
        catalog_root=REPO_ROOT, docker=None, hosts=None, mapping=None):
    """Load and check the scenario, declare the playground (`hosts` and
    `mapping`: the `--host` and `--map` options), read the images from the
    manager's engine (`docker`, by default the declared manager's), place
    each node on its host, run the capacity check per host, and write
    implementation.yaml and state.yaml (stage fitted).

    Raises IncompleteScenario (listing every missing item) or GmError for a
    refusal (a declaration it cannot place the scenario on, an unreachable
    engine or a missing image among them, before anything is written);
    returns a FitResult whose `ok` is False when capacity is short.
    """
    ldir = localimpl.local_dir(scenario_dir, playground)
    scenario = load_scenario(scenario_dir, catalog_root)
    unsupported = localimpl.check_supported(scenario)
    if unsupported:
        raise GmError("cannot fit this scenario: " + "; ".join(unsupported))
    keep = _game_to_keep(ldir, scenario.id)
    declared, existing = playground_declaration(ldir, playground, endpoint, cpu, memory, disk,
                                                hosts, mapping)
    check_declaration(scenario, declared)
    manager = localimpl.manager_host(declared)
    engine = docker or Docker(manager.get("docker_endpoint"))
    images = read_images(scenario, engine, catalog_root)
    manager_name = check_engine_hosts(engine, declared)
    if declared != existing:
        localimpl.write_playground(ldir, declared)
    placement = localimpl.node_hosts(scenario, declared, manager_name)
    try:
        report, _ = placed_capacity_check(scenario, declared, placement, images,
                                          engine.describe())
    except (KeyError, ValueError) as exc:
        raise GmError(f"playground {playground}: capacity incomplete or invalid ({exc})") \
            from None
    result = FitResult(ok=report.ok, scenario_id=scenario.id, playground=declared,
                       local_dir=ldir, report=report)
    state = localimpl.read_state(ldir)
    if not report.ok:
        if keep is not None and state and state.get("stage") != localimpl.FAILED:
            localimpl.set_failed(ldir, "fitted", "insufficient capacity: "
                                 + "; ".join(report.problems))
        return result
    game_id = keep or localimpl.new_game_id(scenario.id,
                                            localimpl.max_game_id_length(scenario))
    now = localimpl.now_iso()
    created = now
    if keep is not None:
        previous = localimpl.read_yaml(ldir / localimpl.IMPLEMENTATION_FILE) or {}
        created = previous.get("created_at") or now
    snapshot_fit = {"fits": report.snapshot_fits, "why": report.snapshot_why}
    impl = localimpl.build_implementation(scenario, playground, game_id, created, placement,
                                          snapshot_fit)
    localimpl.write_implementation(ldir, impl)
    if keep is not None and state is not None:
        localimpl.set_stage(ldir, "fitted", now)
    else:
        localimpl.new_state(ldir, game_id, "fitted", now)
    result.game_id = game_id
    return result
