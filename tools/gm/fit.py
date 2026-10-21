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
"""

import re
import shlex
from dataclasses import dataclass, field
from pathlib import Path

from . import localimpl
from .docker import Docker, DockerError, EngineUnreachable, inspect_image, server_version
from .model import REPO_ROOT, GmError, format_size, load_scenario, parse_cpu, parse_size

# Headroom kept free on every dimension, as a share of the declared capacity
# (master spec 10.3: "the sum of reservations plus headroom").
HEADROOM = 0.10

ENDPOINT_RE = re.compile(r"^(ssh|tcp|unix)://\S+$")


@dataclass
class CapacityReport:
    ok: bool
    lines: list = field(default_factory=list)
    problems: list = field(default_factory=list)


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
    return ImageFootprint(engine=docker.describe(), images=images, size=size, layers=layers,
                          shared=shared)


def capacity_check(scenario, capacity, images):
    """Sum of reservations plus headroom against the capacity, the images'
    footprint (an ImageFootprint) counted in the disk, and every node's
    limits against the host. Reads the scenario; changes nothing."""
    parsers = {"cpu": parse_cpu, "memory": parse_size, "disk": parse_size}
    cap = {key: parsers[key](capacity[key]) for key in parsers}
    lines, problems = [], []
    for key, parse in parsers.items():
        reserved = sum(parse(node["resources"]["reservations"][key])
                       for node in scenario.nodes)
        headroom = cap[key] * HEADROOM
        need = reserved + headroom
        terms = f"reservations {_fmt(key, reserved)}"
        if key == "disk":
            lines.append(images.line())
            need += images.size
            terms += f" + images {_fmt(key, images.size)}"
        verdict = "ok" if need <= cap[key] else "too much"
        line = (f"{key}: {terms} + headroom {_fmt(key, headroom)}"
                f" = {_fmt(key, need)} of {_fmt(key, cap[key])}: {verdict}")
        lines.append(line)
        if need > cap[key]:
            problems.append(line)
    for node in scenario.nodes:
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
    return CapacityReport(ok=not problems, lines=lines, problems=problems)


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
        cap = pg["capacity"]
        endpoint = pg.get("docker_endpoint") or "local engine"
        out = [f"Scenario {self.scenario_id}",
               f"Playground {pg['name']}: {pg['platform']}, {endpoint}, capacity cpu "
               f"{cap['cpu']}, memory {cap['memory']}, disk {cap['disk']}",
               f"Capacity check (headroom {HEADROOM:.0%} of capacity, nothing recomputed):"]
        out += [f"  {line}" for line in self.report.lines]
        if self.ok:
            out.append(f"Result: fits. Game id {self.game_id}.")
            out.append(f"Wrote {self.local_dir}/{localimpl.IMPLEMENTATION_FILE} and "
                       f"{localimpl.STATE_FILE} (stage fitted).")
        else:
            out.append("Result: does not fit; nothing deployed.")
            out += [f"  - {p}" for p in self.report.problems]
        return "\n".join(out)


def _number(value):
    cpu = parse_cpu(value)
    return int(cpu) if cpu == int(cpu) else cpu


def playground_declaration(ldir, name, endpoint=None, cpu=None, memory=None, disk=None):
    """The playground's declaration, from playground.yaml and the options,
    checked but not written: `(declaration, what playground.yaml holds)`."""
    existing = localimpl.read_playground(ldir)
    given = {k: v for k, v in (("cpu", cpu), ("memory", memory), ("disk", disk))
             if v is not None}
    if existing is None and len(given) < 3:
        raise GmError(f"playground {name} is not declared yet: give --cpu, --memory and "
                      "--disk")
    if endpoint is not None and not ENDPOINT_RE.match(endpoint):
        raise GmError(f"endpoint {endpoint!r}: expected a Docker endpoint such as "
                      "ssh://user@host (never keys)")
    try:
        if "cpu" in given:
            given["cpu"] = _number(given["cpu"])
        for key in ("memory", "disk"):
            if key in given:
                parse_size(given[key])
                given[key] = str(given[key])
    except ValueError as exc:
        raise GmError(str(exc)) from None
    declared = existing or {"name": name, "platform": localimpl.PLATFORM,
                            "docker_endpoint": None, "capacity": {}}
    updated = dict(declared, capacity=dict(declared.get("capacity") or {}, **given))
    if endpoint is not None:
        updated["docker_endpoint"] = endpoint
    return updated, existing


# Failure stages of a failed game that had been deployed (deploy, load-data, inject).
AFTER_DEPLOYMENT = ("deployed", "data-loaded", "injected")


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
        catalog_root=REPO_ROOT, docker=None):
    """Load and check the scenario, declare the playground, read the images
    from its engine (`docker`, by default the declared endpoint's), run the
    capacity check, and write implementation.yaml and state.yaml (stage
    fitted).

    Raises IncompleteScenario (listing every missing item) or GmError for a
    refusal (an unreachable engine or a missing image among them, before
    anything is written); returns a FitResult whose `ok` is False when
    capacity is short.
    """
    ldir = localimpl.local_dir(scenario_dir, playground)
    scenario = load_scenario(scenario_dir, catalog_root)
    unsupported = localimpl.check_supported(scenario)
    if unsupported:
        raise GmError("cannot fit this scenario: " + "; ".join(unsupported))
    keep = _game_to_keep(ldir, scenario.id)
    declared, existing = playground_declaration(ldir, playground, endpoint, cpu, memory, disk)
    images = image_footprint(scenario, docker or Docker(declared.get("docker_endpoint")),
                             catalog_root)
    if declared != existing:
        localimpl.write_playground(ldir, declared)
    try:
        report = capacity_check(scenario, declared["capacity"], images)
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
    impl = localimpl.build_implementation(scenario, playground, game_id, created)
    localimpl.write_implementation(ldir, impl)
    if keep is not None and state is not None:
        localimpl.set_stage(ldir, "fitted", now)
    else:
        localimpl.new_state(ldir, game_id, "fitted", now)
    result.game_id = game_id
    return result
