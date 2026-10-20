"""Unit tests of gmctl (tools/gm), and the helpers they share."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent / "fixtures"
FIXTURE_SCENARIO = FIXTURES / "fixture-audit"
GMCTL = REPO_ROOT / "tools" / "gmctl"

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

    def edit_yaml(self, relpath, change):
        path = self.scenario / relpath
        data = yaml.safe_load(path.read_text())
        change(data)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def node(self, data, name):
        return next(n for n in data["nodes"] if n["name"] == name)


def run_gmctl(*args):
    env = dict(os.environ)
    return subprocess.run(
        [sys.executable, str(GMCTL), *map(str, args)],
        capture_output=True, text=True, env=env, cwd=str(REPO_ROOT),
    )


class FakeDocker:
    """Stands in for tools.gm.docker.Docker: records every call and keeps an
    in-memory engine (services, networks, volumes, configs, secrets, each
    with its labels), so deploy, exec and teardown run without Docker.

    `fail` maps a command prefix (tuple) to the stderr it fails with;
    `health` is what `docker inspect` reports for every container."""

    KINDS = ("service", "network", "volume", "config", "secret")

    def __init__(self, swarm=("active", True), images=True, health="healthy", fail=None,
                 endpoint=None):
        from tools.gm.docker import Docker
        self._docker = Docker(endpoint)
        self.endpoint = endpoint
        self.swarm = swarm
        self.images = images
        self.health = health
        self.fail = dict(fail or {})
        self.calls = []
        self.objects = {kind: {} for kind in self.KINDS}

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
        import json
        cmd = args[0]
        if cmd == "info":
            return json.dumps({"LocalNodeState": self.swarm[0], "ControlAvailable": self.swarm[1]})
        if cmd == "swarm" and args[1] == "init":
            self.swarm = ("active", True)
            return ""
        if args[:2] == ["image", "inspect"]:
            return "sha256:x" if self.images else (1, "No such image")
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
