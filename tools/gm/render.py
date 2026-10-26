"""`gmctl render`: the stack file and the per-game envelope files.

Master spec 10.1, 10.3 and 11; stack-file rules fixed by capture W2-A.
Mounts, capabilities and `read_only` mirror the bricks' proven stack tests
(`bricks/*/tests/stack.test.yml`). `/run` is a named volume, never a tmpfs
(capture W1-E). Configs and secrets are external: `gmctl deploy` creates
and labels them (spec D46). The scenario's one network renders under its
own name, so stack `<game_id>` names it `<game_id>_<network name>` (v0.2
master spec 6.3); every node runs with `TZ=UTC` (v0.2 master spec 8).

v0.2 master spec 8 and capture W1, items 2, 4 and 8: the parameter faults
are applied to their target nodes' parameters before anything is derived
from them; a shaped parameter reaches the container as its `shape` says;
every receiving node mounts the mounted items' files and its own config,
written here into `mounted/<item>/<node>.conf`.

v0.3 master spec 6.1, 7.1, 8.3 and 13; capture W1 items 1, 3 and 7, W2
item 1 (`specs/versions/v0.3/wave-log.md`): in a scenario with scheduler
nodes, `--handover` gives the planned hand-over (a UTC date and hour) and
render computes the shift, the customer's time zone and the game's seed,
records them under `implementation.yaml`'s `timeline`, and writes the seed
files it rewrites into `rendered/<node>/`: a scheduler's `schedule.yaml`
and `jobs.yaml` in UTC, shifted, and the bastion's files holding
`{{customer_timezone}}`, filled. A scenario with none has no aging and
shifts nothing (D158).
"""

import datetime
import re
import secrets as _random
import shutil
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from . import localimpl
from .model import (CUSTOMER_TIMEZONE, HANDOVER_MOMENT_RE, REPO_ROOT, WEEKDAYS, GmError,
                    has_scheduler_nodes, is_scheduler_node, load_scenario, parse_cpu,
                    parse_duration, parse_mode)

COMPOSE_VERSION = "3.8"
RENDERABLE_STAGES = ("fitted", "rendered")
NODE_TIMEZONE = "UTC"
NODE_MAP, WEB_ROUTES = "node-map", "web-routes"    # parameter shapes (capture W1, item 2)

# --- The planned hand-over, the shift and the customer's time zone --------
# (v0.3 master spec 8.3; capture W2, item 1)

HANDOVER_RE = re.compile(r"^([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2}):([0-9]{2})(?::([0-9]{2}))?Z$")
SHIFT_MIN, SHIFT_MAX = -11, 12
ZONE_MIN, ZONE_MAX = -12, 14            # the offsets Etc/GMT names
SEED_LIMIT = 2 ** 63                    # 0 <= seed < 2**63 (W1 item 7)
T0 = "T0"
UTC = datetime.timezone.utc


def parse_handover(text):
    """`--handover`: `YYYY-MM-DDTHH:00Z` or `...THH:00:00Z`, UTC, a whole
    hour (W2 item 1) -> an aware datetime; GmError otherwise."""
    m = HANDOVER_RE.match(text) if isinstance(text, str) else None
    if m is None:
        raise GmError(f"--handover {text!r}: give the planned hand-over as a UTC date and hour, "
                      "YYYY-MM-DDTHH:00Z (2026-10-27T14:00Z)")
    if m.group(3) != "00" or (m.group(4) or "00") != "00":
        raise GmError(f"--handover {text}: the planned hand-over is a whole hour (minutes and "
                      "seconds 00)")
    try:
        return datetime.datetime.strptime(f"{m.group(1)}T{m.group(2)}", "%Y-%m-%dT%H") \
            .replace(tzinfo=UTC)
    except ValueError:
        raise GmError(f"--handover {text}: not a valid date and hour") from None


def iso(moment):
    """An aware datetime as `YYYY-MM-DDTHH:MM:SSZ`."""
    return moment.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def from_iso(text):
    return datetime.datetime.strptime(text, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


def compute_shift(designed_hour, planned_hour):
    """The designed hand-over hour minus the planned one, brought between
    -11 and +12 (-12 reads +12; master spec 8.3)."""
    return (designed_hour - planned_hour - SHIFT_MIN) % 24 + SHIFT_MIN


def zone_name(offset):
    """The fixed zone UTC+offset: `Etc/GMT-N` for UTC+N (the naming inverts
    the sign), `Etc/GMT+N` for UTC-N, `Etc/GMT` for 0."""
    if offset == 0:
        return "Etc/GMT"
    return f"Etc/GMT{'-' if offset > 0 else '+'}{abs(offset)}"


def zone_reading(offset):
    """The plain reading of UTC+offset: `UTC+N`, `UTC-N` or `UTC+0`."""
    return f"UTC{'-' if offset < 0 else '+'}{abs(offset)}"


def customer_timezone(shift):
    return {"zone": zone_name(shift), "reading": zone_reading(shift)}


def customer_timezone_text(tz):
    """What `{{customer_timezone}}` is replaced by: `UTC+2 (Etc/GMT-2)`."""
    return f"{tz['reading']} ({tz['zone']})"


def wrap_offset(offset):
    """An offset in hours wrapped modulo 24 into UTC-12..UTC+14 (8.3)."""
    while offset > ZONE_MAX:
        offset -= 24
    while offset < ZONE_MIN:
        offset += 24
    return offset


# --- The scheduler's rendered files (W1 item 7) ---------------------------

def _numbers(field_text):
    return [int(v) for v in str(field_text).split(",")]


def shift_cron(at, shift):
    """A job's `at` in scenario time -> UTC: every hour moved by -shift, the
    day of week with it when the hour wraps (the cron subset the loader
    allows, W1 item 7: hour `*` or numbers; a day of week only with a
    single-number hour). Minute, day of month and month are unchanged."""
    minute, hour, dom, month, dow = str(at).split()
    if hour == "*":
        return at
    hours = []
    for h in _numbers(hour):
        hours.append((h - shift) % 24)
    if dow != "*":
        carry = (_numbers(hour)[0] - shift) // 24
        dow = ",".join(str(d) for d in sorted({(d + carry) % 7 for d in _numbers(dow)}))
    return " ".join([minute, ",".join(str(h) for h in sorted(set(hours))), dom, month, dow])


def render_jobs(doc, shift):
    """jobs.yaml in UTC: a job's `at` shifted, no `timezone:`; a job with
    `timezone_offset: N` (D168) keeps its `at` as designed and gets the
    fixed zone UTC+M, M = shift + N wrapped into UTC-12..UTC+14."""
    jobs = []
    for job in (doc or {}).get("jobs") or []:
        out = {k: v for k, v in job.items() if k not in ("at", "timezone_offset")}
        if "timezone_offset" in job:
            out["at"] = job["at"]
            out["timezone"] = zone_name(wrap_offset(shift + int(job["timezone_offset"])))
        else:
            out["at"] = shift_cron(job["at"], shift)
        jobs.append(out)
    return {"jobs": jobs}


def _hour_spans(hours):
    """`{"HH" or "HH-HH": multiplier}` -> 24 multipliers, hour 00 first."""
    out = [None] * 24
    for key, value in hours.items():
        lo, _, hi = str(key).partition("-")
        for h in range(int(lo), int(hi or lo) + 1):
            out[h] = value
    return out


def _scenario_week(shape):
    """A scenario shape -> 7 days (Monday first) of 24 multipliers each."""
    if "hours" in shape:
        day = _hour_spans(shape["hours"])
        return [list(day) for _ in WEEKDAYS]
    week = [None] * len(WEEKDAYS)
    for key, value in shape["days"].items():
        lo, _, hi = str(key).partition("-")
        for d in range(WEEKDAYS.index(lo), WEEKDAYS.index(hi or lo) + 1):
            week[d] = _hour_spans(value["hours"])
    return week


def render_shape(shape, shift):
    """A shape in scenario time -> `{utc: {mon..sun: [24 multipliers]}}`:
    UTC hour u of weekday d takes the scenario's multiplier at u + shift,
    on the day before or after when it wraps."""
    week = _scenario_week(shape)
    utc = {}
    for d, day in enumerate(WEEKDAYS):
        hours = []
        for u in range(24):
            total = u + shift
            hours.append(week[(d + total // 24) % 7][total % 24])
        utc[day] = hours
    return {"utc": utc}


def moment_instant(moment, planned, rendered_at):
    """A timeline moment as a UTC instant: `handover-<N>h` N hours before
    the planned hand-over; `T0` as the render time, which no load start
    can precede (a change at or before the start applies at it, W1-y)."""
    m = HANDOVER_MOMENT_RE.match(str(moment))
    if m is None:
        return rendered_at
    return iso(planned - datetime.timedelta(hours=int(m.group(1))))


def render_schedule(doc, shift, planned, seed, rendered_at):
    """schedule.yaml as the program reads it (W1 item 7): the game's seed
    first, connections and streams as designed, shapes per UTC weekday,
    timeline moments as UTC instants."""
    out = {"seed": seed}
    for key in ("intensity", "connections", "streams"):
        if key in doc:
            out[key] = doc[key]
    if doc.get("shapes"):
        out["shapes"] = {name: render_shape(shape, shift) for name, shape in doc["shapes"].items()}
    if doc.get("timeline"):
        out["timeline"] = [{**change, "at": moment_instant(change.get("at"), planned, rendered_at)}
                           for change in doc["timeline"]]
    return out


# --- The timeline records (W2 item 1) -------------------------------------

def instance_minimum(scenario, inst):
    """An instance's own aging minimum: its `aging_minimum`, else its
    definition's `aging.minimum` (W1 item 1)."""
    if inst.get("aging_minimum") is not None:
        return inst["aging_minimum"]
    return ((scenario.faults[inst["id"]].data.get("aging") or {}).get("minimum"))


def build_timeline(scenario, planned, previous, rendered_at):
    """implementation.yaml's `timeline`. A scheduler game: the planned and
    designed hand-overs, the shift, the customer's time zone, the seed (the
    previous render's, kept, else a new one), the aging minimum, every
    instance's planting moment and minimum, the render time. A static game
    with `--handover`: the planned hand-over alone; without, None."""
    if planned is None:
        return None
    if not has_scheduler_nodes(scenario.data):
        return {"planned_handover": iso(planned)}
    aging = scenario.data.get("aging") or {}
    designed = str(aging.get("handover_at"))
    shift = compute_shift(int(designed.split(":")[0]), planned.hour)
    seed = (previous or {}).get("seed")
    if not (isinstance(seed, int) and not isinstance(seed, bool) and 0 <= seed < SEED_LIMIT):
        seed = _random.randbelow(SEED_LIMIT)
    instances = {}
    for inst in scenario.data.get("fault_instances") or []:
        plant_at = inst.get("plant_at") or T0
        m = HANDOVER_MOMENT_RE.match(str(plant_at))
        instances[inst["id"]] = {
            "plant_at": plant_at,
            "planned_at": iso(planned - datetime.timedelta(hours=int(m.group(1))))
            if m else None,
            "aging_minimum": instance_minimum(scenario, inst),
        }
    return {
        "planned_handover": iso(planned),
        "designed_handover": designed,
        "shift": shift,
        "customer_timezone": customer_timezone(shift),
        "seed": seed,
        "aging_minimum": aging.get("minimum"),
        "instances": instances,
        "rendered_at": rendered_at,
    }


def earliest_if_started(timeline, now):
    """The earliest hand-over the game could have if the load started at
    `now` (W2 item 7's formula, no time lost, no override)."""
    earliest = now + datetime.timedelta(seconds=parse_duration(timeline["aging_minimum"]))
    for inst in timeline["instances"].values():
        if inst["aging_minimum"] is None:
            continue
        planted = max(from_iso(inst["planned_at"]), now) if inst["planned_at"] else now
        earliest = max(earliest, planted + datetime.timedelta(
            seconds=parse_duration(inst["aging_minimum"])))
    return earliest


def rendered_seed_text(scenario, node, seed_name, timeline):
    """The content render writes for one of the seed files it rewrites."""
    rel = dict((n, r) for _, n, r in localimpl.seed_entries(scenario, node))[seed_name]
    source = Path(scenario.dir) / rel
    if not is_scheduler_node(node):
        text = source.read_text(encoding="utf-8")
        return text.replace(CUSTOMER_TIMEZONE,
                            customer_timezone_text(timeline["customer_timezone"]))
    doc = yaml.safe_load(source.read_text(encoding="utf-8")) or {}
    shift = timeline["shift"]
    if seed_name == localimpl.JOBS_FILE:
        # The players' file: no header, nothing about scenario time.
        return yaml.safe_dump(render_jobs(doc, shift), sort_keys=False,
                              default_flow_style=False, width=100)
    planned = from_iso(timeline["planned_handover"])
    body = render_schedule(doc, shift, planned, timeline["seed"], timeline["rendered_at"])
    header = (f"# schedule.yaml of node {node['name']}, rendered by gmctl render from {rel}:\n"
              f"# UTC, shift {shift:+d} (planned hand-over {timeline['planned_handover']}); "
              "never edit by hand.\n")
    return header + yaml.safe_dump(body, sort_keys=False, default_flow_style=None, width=100)


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


def web_routes_value(routes):
    """A web-routes map as `name=node:port` tokens, space-separated, sorted
    by name; `""` for an empty map (capture W1, item 2)."""
    if not isinstance(routes, dict):
        raise GmError(f"a web-routes parameter is a map of routes, not {routes!r}")
    return " ".join(f"{name}={routes[name]}" for name in sorted(routes))


def service_environment(brick, node):
    """`TZ=UTC`, then the brick parameters as GM_<NAME> variables: the
    scenario's value, else the brick's default; unset parameters are left
    out. By `shape` (capture W1, item 2): a node-map parameter is never
    passed (the mounted material carries it), a web-routes one is passed
    as its tokens, a scalar as in v0.1."""
    env = {"TZ": NODE_TIMEZONE}
    values = node.get("parameters") or {}
    for name, spec in (brick.get("parameters") or {}).items():
        spec = spec or {}
        shape = spec.get("shape")
        if shape == NODE_MAP:
            continue
        value = values.get(name, spec.get("default"))
        if value is None:
            continue
        if shape == WEB_ROUTES:
            value = web_routes_value(value)
        elif isinstance(value, bool):
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
    params = localimpl.node_parameters(scenario)
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
        svc["environment"] = service_environment(brick, {"parameters": params[name]})
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
    node_config_files: list = field(default_factory=list)
    rendered_files: list = field(default_factory=list)
    timeline: dict = None
    warning: str = None

    def text(self):
        out = [f"Game {self.game_id}: rendered.",
               f"  {self.stack_file}"]
        out += [f"  {p}" for p in self.envelope_files]
        out += [f"  {p}" for p in self.node_config_files]
        out += [f"  {p}" for p in self.rendered_files]
        tl = self.timeline
        if tl and "shift" in tl:
            out.append(f"  planned hand-over {tl['planned_handover']}, shift {tl['shift']:+d}, "
                       "customer's time zone "
                       f"{customer_timezone_text(tl['customer_timezone'])}")
        elif tl:
            out.append(f"  planned hand-over {tl['planned_handover']} (no scheduler node: "
                       "nothing shifted)")
        if self.warning:
            out.append(f"  warning: {self.warning}")
        out.append("Stage rendered.")
        return "\n".join(out)


def _check_fit(scenario, impl, playground):
    """Refuses (GmError) a scenario changed since `fit` in what fit derived."""
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
    params = localimpl.node_parameters(scenario)
    mounted = localimpl.mounted_configs(scenario, params, playground, impl["game_id"])
    kinds = (localimpl.MOUNTED_CONFIG, localimpl.NODE_CONFIG)
    if impl.get("parameter_faults") != localimpl.parameter_faults(scenario) or any(
            [c for c in impl["nodes"][name]["configs"] if c.get("kind") in kinds]
            != mounted[name] for name in mounted):
        raise GmError("the mounted material changed since gmctl fit: fit again")
    for node in scenario.nodes:
        if [c for c in impl["nodes"][node["name"]]["configs"]
                if c.get("kind") == localimpl.SEED_KIND] \
                != localimpl.seed_configs(scenario, node, playground, impl["game_id"]):
            raise GmError(f"node {node['name']}'s seed files changed since gmctl fit: fit again")


def render(scenario_dir, playground, handover=None, catalog_root=REPO_ROOT):
    """Write stack.yml, envelopes/<node>.conf, mounted/ and rendered/, and
    implementation.yaml's `timeline`; stage `rendered`. `handover` (the
    planned hand-over, `--handover`) is required with scheduler nodes."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    if localimpl.read_state(ldir) is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    localimpl.require_stage(ldir, *RENDERABLE_STAGES)
    impl = localimpl.read_implementation(ldir)
    scenario = load_scenario(scenario_dir, catalog_root)
    _check_fit(scenario, impl, playground)
    scheduled = has_scheduler_nodes(scenario.data)
    if scheduled and handover is None:
        raise GmError("this scenario has scheduler nodes: give the planned hand-over, "
                      "--handover <UTC date and hour> (2026-10-27T14:00Z)")
    now = datetime.datetime.now(UTC).replace(microsecond=0)
    planned = None
    if handover is not None:
        planned = parse_handover(handover)
        if planned <= now:
            raise GmError(f"--handover {iso(planned)} is not in the future (it is {iso(now)})")
    timeline = build_timeline(scenario, planned, impl.get(localimpl.TIMELINE), iso(now))
    warning = None
    if scheduled:
        earliest = earliest_if_started(timeline, now)
        if planned < earliest:
            warning = (f"the planned hand-over {iso(planned)} is before {iso(earliest)}, the "
                       "earliest hand-over this game could have if the load started now")

    envelope_files = []
    for node in scenario.nodes:
        name = node["name"]
        for config in impl["nodes"][name]["configs"]:
            if config.get("kind") == localimpl.ENVELOPES_CONFIG:
                path = scenario.dir / config["file"]
                localimpl.write_text(path, envelope_text(name, node.get("knobs") or []))
                envelope_files.append(path)

    node_config_files = []
    params = localimpl.node_parameters(scenario)
    shutil.rmtree(ldir / localimpl.MOUNTED_DIR, ignore_errors=True)   # a node left out keeps none
    for _, _, item, entries in localimpl.mounted_material(scenario, params):
        for name, entry in entries.items():
            path = scenario.dir / localimpl.node_config_file(playground, item["name"], name)
            localimpl.write_text(path, localimpl.node_config_text(scenario, impl, name, entry))
            node_config_files.append(path)

    rendered_files = []
    shutil.rmtree(ldir / localimpl.RENDERED_DIR, ignore_errors=True)
    for node in scenario.nodes:
        for seed_name in localimpl.rendered_seed_names(scenario, node):
            path = scenario.dir / localimpl.rendered_seed_file(playground, node["name"],
                                                               seed_name)
            localimpl.write_text(path, rendered_seed_text(scenario, node, seed_name, timeline))
            rendered_files.append(path)

    if timeline is None:
        impl.pop(localimpl.TIMELINE, None)
    else:
        impl[localimpl.TIMELINE] = timeline
    localimpl.write_implementation(ldir, impl)
    stack_file = ldir / localimpl.STACK_FILE
    localimpl.write_text(stack_file, dump_stack(build_stack(scenario, impl), impl["game_id"]))
    localimpl.set_stage(ldir, "rendered")
    return RenderResult(impl["game_id"], ldir, stack_file, envelope_files, node_config_files,
                        rendered_files, timeline, warning)
