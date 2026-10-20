"""`gmctl fit`: capacity check of a scenario against a declared playground.

Master spec 10.3 and 11; command line and files fixed by capture W2-A.
The scenario's resource limits and envelopes are absolute in v0.1: the
check compares, it never recomputes (recomputing could turn a deliberately
planted out-of-bounds value into an in-bounds one).
"""

import re
from dataclasses import dataclass, field
from pathlib import Path

from . import localimpl
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


def capacity_check(scenario, capacity):
    """Sum of reservations plus headroom against the capacity, and every
    node's limits against the host. Reads the scenario; changes nothing."""
    parsers = {"cpu": parse_cpu, "memory": parse_size, "disk": parse_size}
    cap = {key: parsers[key](capacity[key]) for key in parsers}
    lines, problems = [], []
    for key, parse in parsers.items():
        reserved = sum(parse(node["resources"]["reservations"][key])
                       for node in scenario.nodes)
        headroom = cap[key] * HEADROOM
        need = reserved + headroom
        verdict = "ok" if need <= cap[key] else "too much"
        line = (f"{key}: reservations {_fmt(key, reserved)} + headroom {_fmt(key, headroom)}"
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


def declare_playground(ldir, name, endpoint=None, cpu=None, memory=None, disk=None):
    """Write playground.yaml, or reuse it; returns the declaration."""
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
    if updated != existing:
        localimpl.write_playground(ldir, updated)
    return updated


def _game_to_keep(ldir, scenario_id):
    """The game id to keep on a refit, None for a new one; GmError if the
    game may have resources on the platform."""
    state = localimpl.read_state(ldir)
    if state is None:
        return None
    stage = state.get("stage")
    failure = state.get("failure") or {}
    before_deploy = stage in ("fitted", "rendered") or (
        stage == localimpl.FAILED and failure.get("stage") in ("fitted", "rendered"))
    if stage == "torn-down":
        return None
    if not before_deploy:
        raise GmError(f"game {state.get('game_id')} on this playground is at stage {stage}; "
                      "tear it down before fitting again")
    impl = localimpl.read_yaml(ldir / localimpl.IMPLEMENTATION_FILE) or {}
    if (impl.get("scenario") or {}).get("id") != scenario_id:
        return None
    return state.get("game_id")


def fit(scenario_dir, playground, endpoint=None, cpu=None, memory=None, disk=None,
        catalog_root=REPO_ROOT):
    """Load and check the scenario, declare the playground, run the capacity
    check, and write implementation.yaml and state.yaml (stage fitted).

    Raises IncompleteScenario (listing every missing item) or GmError for a
    refusal; returns a FitResult whose `ok` is False when capacity is short.
    """
    ldir = localimpl.local_dir(scenario_dir, playground)
    scenario = load_scenario(scenario_dir, catalog_root)
    unsupported = localimpl.check_supported(scenario)
    if unsupported:
        raise GmError("cannot fit this scenario: " + "; ".join(unsupported))
    keep = _game_to_keep(ldir, scenario.id)
    declared = declare_playground(ldir, playground, endpoint, cpu, memory, disk)
    try:
        report = capacity_check(scenario, declared["capacity"])
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
