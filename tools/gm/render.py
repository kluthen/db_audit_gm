"""`gmctl render`: the stack file and the per-game envelope files.

Master spec 10.1, 10.3 and 11; stack-file rules fixed by capture W2-A.
Mounts, capabilities and `read_only` mirror the bricks' proven stack tests
(`bricks/*/tests/stack.test.yml`). `/run` is a named volume, never a tmpfs
(capture W1-E). Configs and secrets are external: `gmctl deploy` creates
and labels them (spec D46). The scenario's one network renders under its
own name, so stack `<game_id>` names it `<game_id>_<network name>` (v0.2
master spec 6.3); every node runs with `TZ=UTC` (v0.2 master spec 8).
"""

import re
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import localimpl
from .model import REPO_ROOT, GmError, load_scenario, parse_cpu, parse_mode

COMPOSE_VERSION = "3.8"
RENDERABLE_STAGES = ("fitted", "rendered")
NODE_TIMEZONE = "UTC"


def _envelope_value(value):
    if isinstance(value, bool):
        return "on" if value else "off"
    return str(value)


def _bound(envelope, key):
    value = envelope.get(key)
    return "-" if value is None or value == "-" else _envelope_value(value)


def envelope_text(node_name, knobs):
    """The envelope file of one node (format: captures W1-B and W1-E)."""
    lines = [f"# Envelope file of node {node_name}, rendered by gmctl render.",
             "# <setting> range <min> <max>   |   <setting> enum <v1>,<v2>,...",
             "# Read by the node's validator; root-owned, read-only."]
    for knob in knobs:
        envelope = knob["envelope"]
        if "allowed" in envelope:
            values = ",".join(_envelope_value(v) for v in envelope["allowed"])
            lines.append(f"{knob['setting']} enum {values}")
        else:
            lines.append(f"{knob['setting']} range {_bound(envelope, 'min')} "
                         f"{_bound(envelope, 'max')}")
    return "\n".join(lines) + "\n"


def service_environment(brick, node):
    """`TZ=UTC`, then the brick parameters as GM_<NAME> variables: the
    scenario's value, else the brick's default; unset parameters are left
    out."""
    env = {"TZ": NODE_TIMEZONE}
    values = node.get("parameters") or {}
    for name, spec in (brick.get("parameters") or {}).items():
        value = values.get(name, (spec or {}).get("default"))
        if value is None:
            continue
        if isinstance(value, bool):
            value = "true" if value else "false"
        env["GM_" + re.sub(r"[^A-Za-z0-9]", "_", str(name)).upper()] = str(value)
    return env


def _cpus(value):
    return format(parse_cpu(value), "g")


def _mount(obj):
    return {"source": obj["name"], "target": obj["path"], "uid": str(obj["uid"]),
            "gid": str(obj["gid"]), "mode": parse_mode(obj["mode"])}


def _healthcheck(spec):
    command = spec["command"]
    test = ["CMD", *command] if isinstance(command, list) else ["CMD-SHELL", str(command)]
    hc = {"test": test}
    for key in ("interval", "timeout", "retries", "start_period"):
        if key in spec:
            hc[key] = spec[key]
    return hc


def build_stack(scenario, impl):
    """The stack file's content, as a dict (Compose file format 3.8)."""
    gid = impl["game_id"]
    network = localimpl.network_name(scenario)
    services, volumes, configs, secrets = {}, {}, {}, {}
    for node in scenario.nodes:
        name = node["name"]
        brick = scenario.bricks[name].data
        inode = impl["nodes"][name]
        svc = {
            "image": inode["image"],
            "hostname": name,
            "read_only": True,
            "cap_drop": ["ALL"],
            "cap_add": list(brick.get("capabilities") or []),
        }
        svc["environment"] = service_environment(brick, node)
        svc["healthcheck"] = _healthcheck(brick["healthcheck"])
        if inode["published_ports"]:
            svc["ports"] = [{"target": p["target"], "published": p["published"],
                             "protocol": "tcp", "mode": p.get("mode", "host")}
                            for p in inode["published_ports"]]
        svc["volumes"] = [{"type": "volume", "source": v["name"], "target": v["path"]}
                          for v in inode["volumes"]]
        svc["configs"] = [_mount(c) for c in inode["configs"]]
        svc["secrets"] = [_mount(s) for s in inode["secrets"]]
        svc["networks"] = [network]
        limits = inode["resources"]["limits"]
        reservations = inode["resources"]["reservations"]
        svc["deploy"] = {
            "replicas": 1,
            "placement": {"constraints": [localimpl.PLACEMENT_CONSTRAINT]},
            "resources": {
                "limits": {"cpus": _cpus(limits["cpu"]), "memory": str(limits["memory"])},
                "reservations": {"cpus": _cpus(reservations["cpu"]),
                                 "memory": str(reservations["memory"])},
            },
        }
        services[name] = svc
        for v in inode["volumes"]:
            volumes[v["name"]] = {"name": v["name"],
                                  "labels": {localimpl.LABEL_GAME: gid}}
        for c in inode["configs"]:
            configs[c["name"]] = {"external": True, "name": c["name"]}
        for s in inode["secrets"]:
            secrets[s["name"]] = {"external": True, "name": s["name"]}
    return {
        "version": COMPOSE_VERSION,
        "services": services,
        "networks": {network: {"driver": "overlay", "attachable": False}},
        "volumes": volumes,
        "configs": configs,
        "secrets": secrets,
    }


def dump_stack(stack, game_id):
    header = (f"# Stack file of game {game_id}: deploy as stack {game_id}.\n"
              "# Rendered by gmctl render from scenario.yaml and implementation.yaml;\n"
              "# never edit by hand. Configs and secrets are external (gmctl deploy\n"
              "# creates and labels them). Modes are decimal (292 = 0444, 256 = 0400).\n")
    return header + yaml.safe_dump(stack, sort_keys=False, default_flow_style=False,
                                   width=100)


@dataclass
class RenderResult:
    game_id: str
    local_dir: Path
    stack_file: Path
    envelope_files: list = field(default_factory=list)

    def text(self):
        out = [f"Game {self.game_id}: rendered.",
               f"  {self.stack_file}"]
        out += [f"  {p}" for p in self.envelope_files]
        out.append("Stage rendered.")
        return "\n".join(out)


def render(scenario_dir, playground, catalog_root=REPO_ROOT):
    """Write stack.yml and envelopes/<node>.conf; stage `rendered`."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    if localimpl.read_state(ldir) is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    localimpl.require_stage(ldir, *RENDERABLE_STAGES)
    impl = localimpl.read_implementation(ldir)
    scenario = load_scenario(scenario_dir, catalog_root)
    if impl["scenario"]["id"] != scenario.id \
            or list(impl["nodes"]) != [n["name"] for n in scenario.nodes]:
        raise GmError("the scenario changed since gmctl fit (id or nodes): fit again")
    for node in scenario.nodes:
        brick = scenario.bricks[node["name"]]
        recorded = impl["nodes"][node["name"]]["brick"]
        if recorded != {"id": brick.id, "version": brick.version}:
            raise GmError(f"node {node['name']}'s brick changed since gmctl fit: fit again")
    unsupported = localimpl.check_supported(scenario)
    if unsupported:
        raise GmError("cannot render this scenario: " + "; ".join(unsupported))
    if impl.get("network") != f"{impl['game_id']}_{localimpl.network_name(scenario)}":
        raise GmError("the scenario's network changed since gmctl fit: fit again")
    if impl.get("secrets") != localimpl.implementation_secrets(scenario, playground,
                                                               impl["game_id"]):
        raise GmError("the bricks' secrets changed since gmctl fit: fit again")

    envelope_files = []
    for node in scenario.nodes:
        name = node["name"]
        for config in impl["nodes"][name]["configs"]:
            if config.get("kind") == localimpl.ENVELOPES_CONFIG:
                path = scenario.dir / config["file"]
                localimpl.write_text(path, envelope_text(name, node.get("knobs") or []))
                envelope_files.append(path)

    stack_file = ldir / localimpl.STACK_FILE
    localimpl.write_text(stack_file, dump_stack(build_stack(scenario, impl), impl["game_id"]))
    localimpl.set_stage(ldir, "rendered")
    return RenderResult(impl["game_id"], ldir, stack_file, envelope_files)
