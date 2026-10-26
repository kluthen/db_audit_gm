"""Unit tests of gmctl (tools/gm), and the helpers they share."""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
FIXTURE_SCENARIO = FIXTURES / "fixture-audit"
GMCTL = REPO_ROOT / "tools" / "gmctl"
# A `docker` stand-in answering as FakeDocker does, put first on PATH of gmctl
# run by run_gmctl, so `fit` never reaches a real engine there.
FAKE_BIN = Path(__file__).resolve().parent / "fakebin"

SUFFICIENT = {"cpu": "2", "memory": "4G", "disk": "20G"}
INSUFFICIENT = {"cpu": "0.5", "memory": "4G", "disk": "20G"}


class ScenarioCopyTest(unittest.TestCase):
    """Each test works on a fresh copy of the fixture scenario."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="gmctl-test-")
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.scenario = self.tmp / "fixture-audit"
        shutil.copytree(FIXTURE_SCENARIO, self.scenario)
        # `fit` called in-process reads the images from a FakeDocker (shaped by fake_engine)
        engine = mock.patch("tools.gm.fit.Docker",
                            lambda endpoint=None: FakeDocker.from_environment(endpoint))
        engine.start()
        self.addCleanup(engine.stop)

    def fake_engine(self, missing=(), unreachable=False):
        """The engine `fit` reads, in-process or through run_gmctl, for this test."""
        env = mock.patch.dict(os.environ, {
            FAKE_MISSING_ENV: ",".join(missing),
            FAKE_UNREACHABLE_ENV: "1" if unreachable else ""})
        env.start()
        self.addCleanup(env.stop)

    def edit_yaml(self, relpath, change):
        path = self.scenario / relpath
        data = yaml.safe_load(path.read_text())
        change(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def node(self, data, name):
        return next(n for n in data["nodes"] if n["name"] == name)


def run_gmctl(*args):
    env = dict(os.environ)
    env["PATH"] = f"{FAKE_BIN}{os.pathsep}{env.get('PATH', '')}"
    return subprocess.run(
        [sys.executable, str(GMCTL), *map(str, args)],
        capture_output=True, text=True, env=env, cwd=str(REPO_ROOT),
    )


# What FakeDocker.from_environment reads: the images missing (comma-separated),
# and "1" for an engine that does not answer.
FAKE_MISSING_ENV = "DBAGM_FAKE_DOCKER_MISSING"
FAKE_UNREACHABLE_ENV = "DBAGM_FAKE_DOCKER_UNREACHABLE"
UNREACHABLE = ("Cannot connect to the Docker daemon at unix:///var/run/docker.sock. "
               "Is the docker daemon running?")

FAKE_ENGINE_NAME = "gm-host"        # what the fake engine's `docker info` names it

# Every image of the fake engine sits on one shared base layer (as the brick
# images on debian:13-slim) under one layer of its own.
BASE_LAYER = ("sha256:" + "b" * 64, 78 * 1024 ** 2)
OWN_LAYER_SIZE = 100 * 1024 ** 2


def own_layer(image):
    return ("sha256:" + hashlib.sha256(image.encode()).hexdigest(), OWN_LAYER_SIZE)


def image_id(image):
    return "sha256:" + hashlib.sha256(f"id:{image}".encode()).hexdigest()


class FakeDocker:
    """Stands in for tools.gm.docker.Docker: records every call and keeps an
    in-memory engine (services, networks, volumes, configs, secrets, each
    with its labels), so deploy, exec and teardown run without Docker.

    `fail` maps a command prefix (tuple) to the stderr it fails with;
    `health` is what `docker inspect` reports for every container.
    `images`: True, every image is present (BASE_LAYER, then its own
    layer); False, none is; or a dict of the present images, each to its
    layers `[(diff id, size)]` bottom first. `missing` removes images;
    `reachable=False` makes every command fail as an engine that does not
    answer. `name` is the engine's (`docker info`), `nodes` what `docker
    node ls` lists, `{hostname: (status, availability, manager status)}`
    (by default the engine alone, the swarm's leader)."""

    KINDS = ("service", "network", "volume", "config", "secret")

    def __init__(self, swarm=("active", True), images=True, health="healthy", fail=None,
                 endpoint=None, missing=(), reachable=True, name=None, nodes=None):
        from tools.gm.docker import Docker
        self._docker = Docker(endpoint)
        self.endpoint = endpoint
        self.name = name or FAKE_ENGINE_NAME
        self.nodes = (dict(nodes) if nodes is not None
                      else {self.name: ("Ready", "Active", "Leader")})
        self.swarm = swarm
        self.images = images
        self.missing = set(missing)
        self.reachable = reachable
        self.health = health
        self.fail = dict(fail or {})
        self.calls = []
        self.objects = {kind: {} for kind in self.KINDS}

    @classmethod
    def from_environment(cls, endpoint=None):
        """The engine set by ScenarioCopyTest.fake_engine (every image present
        by default), as `fit` and the `docker` stand-in on PATH read it."""
        missing = [m for m in os.environ.get(FAKE_MISSING_ENV, "").split(",") if m]
        return cls(missing=missing, reachable=os.environ.get(FAKE_UNREACHABLE_ENV) != "1",
                   endpoint=endpoint)

    def layers(self, image):
        """The image's layers `[(diff id, size)]`, None when it is absent."""
        if image in self.missing or self.images is False:
            return None
        if self.images is True:
            return [BASE_LAYER, own_layer(image)]
        return self.images.get(image)

    def _image_by_id(self, ident):
        names = [] if self.images in (True, False) else list(self.images)
        names += [c[-1] for c in self.calls if c[:2] == ["image", "inspect"]]
        return next((n for n in names if image_id(n) == ident or n == ident), None)

    def describe(self):
        return self._docker.describe()

    def command(self, args):
        return self._docker.command(args)

    def add(self, kind, name, labels=None):
        self.objects[kind][name] = dict(labels or {})

    def names(self, kind):
        return sorted(self.objects[kind])

    def called(self, *prefix):
        return [c for c in self.calls if tuple(c[:len(prefix)]) == prefix]

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None):
        from tools.gm.docker import DockerError
        args = [str(a) for a in args]
        self.calls.append(args)
        for prefix, stderr in self.fail.items():
            if tuple(args[:len(prefix)]) == tuple(prefix):
                if check:
                    raise DockerError(args, 1, stderr)
                return subprocess.CompletedProcess(args, 1, "", stderr)
        out = self._respond(args, input, stdin)
        if isinstance(out, tuple):
            rc, text = out
            if check and rc:
                raise DockerError(args, rc, text)
            return subprocess.CompletedProcess(args, rc, "", text)
        return subprocess.CompletedProcess(args, 0, out, "")

    def lines(self, args):
        return [l.strip() for l in (self.run(args).stdout or "").splitlines() if l.strip()]

    def json(self, args):
        import json
        return json.loads(self.run(args).stdout or "null")

    @staticmethod
    def _filters(args):
        return [args[i + 1] for i, a in enumerate(args) if a == "--filter"]

    def _matching(self, kind, args):
        names = []
        for name, labels in self.objects[kind].items():
            ok = True
            for flt in self._filters(args):
                if flt.startswith("label="):
                    key, _, value = flt[len("label="):].partition("=")
                    ok = ok and labels.get(key) == value
            if ok:
                names.append(name)
        return sorted(names)

    def _labels(self, args):
        labels = {}
        for i, a in enumerate(args):
            if a == "--label":
                key, _, value = args[i + 1].partition("=")
                labels[key] = value
        return labels

    def _respond(self, args, input, stdin):
        cmd = args[0]
        if not self.reachable:
            return (1, UNREACHABLE)
        if cmd == "version":
            return "29.9.1\n"
        if cmd == "info" and "{{.Name}}" in args:
            return self.name + "\n"
        if args[:2] == ["node", "ls"]:
            if not self.swarm[1]:
                return (1, "Error response from daemon: This node is not a swarm manager.")
            return "".join(f"{host}\t{status}\t{avail}\t{mgr}\n"
                           for host, (status, avail, mgr) in self.nodes.items())
        if cmd == "info":
            return json.dumps({"LocalNodeState": self.swarm[0], "ControlAvailable": self.swarm[1]})
        if cmd == "swarm" and args[1] == "init":
            self.swarm = ("active", True)
            return ""
        if args[:2] == ["image", "inspect"]:
            name = args[-1]
            layers = self.layers(name)
            if layers is None:
                return (1, f"Error response from daemon: No such image: {name}")
            if "{{json .}}" not in args:
                return "sha256:x"
            return json.dumps({"Id": image_id(name), "RepoTags": [name],
                               "Size": sum(size for _, size in layers),
                               "RootFS": {"Type": "layers",
                                          "Layers": [diff for diff, _ in layers]}})
        if cmd == "history":
            name = self._image_by_id(args[-1])
            if name is None and self.images is True:
                name = args[-1]         # every default image has the same layer sizes
            layers = self.layers(name) if name else None
            if layers is None:
                return (1, f"Error response from daemon: No such image: {args[-1]}")
            # newest first, with rows that add no layer (ENTRYPOINT, ARG) at 0
            return "0\n" + "".join(f"{size}\n0\n" for _, size in reversed(layers))
        if cmd in ("config", "secret") and args[1] == "create":
            name = args[-2]
            if name in self.objects[cmd]:
                return (1, f"{cmd} {name} already exists")
            self.add(cmd, name, self._labels(args))
            return name
        if args[:2] == ["stack", "deploy"]:
            stack_file, gid = args[args.index("-c") + 1], args[-1]
            stack = yaml.safe_load(Path(stack_file).read_text())
            ns = {"com.docker.stack.namespace": gid}
            for svc in stack["services"]:
                self.add("service", f"{gid}_{svc}", ns)
            for net in stack.get("networks") or {}:
                self.add("network", f"{gid}_{net}", ns)
            for vol in (stack.get("volumes") or {}).values():
                self.add("volume", vol["name"], {**ns, **(vol.get("labels") or {})})
            return ""
        if cmd == "ps":
            ids = []
            for svc, labels in sorted(self.objects["service"].items()):
                ctr = {"com.docker.swarm.service.name": svc, **labels}
                ok = True
                for flt in self._filters(args):
                    if flt.startswith("label="):
                        key, _, value = flt[len("label="):].partition("=")
                        ok = ok and ctr.get(key) == value
                if ok:
                    ids.append(f"{svc}.1.ctr")
            return "".join(f"{i}\n" for i in ids)
        if cmd == "inspect":
            return self.health + "\n"
        if args[:2] == ["service", "ps"]:
            return "Running 5 seconds ago\t\n"
        if cmd in self.KINDS and args[1] == "ls":
            return "".join(f"{n}\n" for n in self._matching(cmd, args))
        if cmd in self.KINDS and args[1] == "rm":
            for name in args[2:]:
                if name.startswith("-"):
                    continue
                if name not in self.objects[cmd]:
                    return (1, f"no such {cmd}: {name}")
                del self.objects[cmd][name]
            return ""
        if cmd == "exec":
            return "exec-output\n"
        if args[:2] == ["service", "logs"]:
            return "log line\n"
        raise AssertionError(f"FakeDocker: unexpected command {args}")
