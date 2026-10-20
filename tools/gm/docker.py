"""The Docker command line, aimed at the playground's engine.

Master spec 10.2 and 11: the GM targets one swarm manager, the local engine
or one reached over SSH (`docker_endpoint` in `playground.yaml`, such as
`ssh://user@host`; never keys). Every Docker call of gmctl goes through
`Docker.run`, so the unit tests replace it with a stub.
"""

import json
import subprocess

from . import localimpl
from .model import GmError

DOCKER = "docker"


class DockerError(GmError):
    """A Docker command failed; `.args_` is the command, `.stderr` its message."""

    def __init__(self, args, returncode, stderr):
        self.args_ = list(args)
        self.returncode = returncode
        self.stderr = (stderr or "").strip()
        detail = " ".join(self.stderr.split()) or f"exit status {returncode}"
        super().__init__(f"docker {' '.join(self.args_[:3])}: {detail}")


class Docker:
    """`docker [-H <endpoint>] ...` as subprocesses."""

    def __init__(self, endpoint=None):
        self.endpoint = endpoint or None

    def describe(self):
        return self.endpoint or "local engine"

    def command(self, args):
        prefix = [DOCKER] + (["-H", self.endpoint] if self.endpoint else [])
        return prefix + [str(a) for a in args]

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None):
        """Run `docker <args>`; returns a CompletedProcess (text mode when
        `input` is a str or nothing is fed). `stdin` is a file object
        streamed to the command; `capture=False` leaves stdout and stderr to
        the caller's terminal. Raises DockerError on a non-zero exit when
        `check`."""
        binary = isinstance(input, (bytes, bytearray))
        kwargs = {"timeout": timeout}
        if input is not None:
            kwargs["input"] = input
        elif stdin is not None:
            kwargs["stdin"] = stdin
        else:
            kwargs["stdin"] = subprocess.DEVNULL
        if capture:
            kwargs["stdout"] = subprocess.PIPE
            kwargs["stderr"] = subprocess.PIPE
        try:
            proc = subprocess.run(self.command(args), text=not binary, **kwargs)
        except FileNotFoundError:
            raise GmError("the docker command line is not installed on this host") from None
        except subprocess.TimeoutExpired:
            raise GmError(f"docker {' '.join(map(str, args[:3]))}: no answer within "
                          f"{timeout} s") from None
        if check and proc.returncode != 0:
            raise DockerError(args, proc.returncode, proc.stderr if capture else "")
        return proc

    def lines(self, args):
        """The command's non-empty output lines."""
        out = self.run(args).stdout or ""
        return [line.strip() for line in out.splitlines() if line.strip()]

    def json(self, args):
        return json.loads(self.run(args).stdout or "null")


def for_local_dir(ldir):
    """The Docker command line aimed at the playground recorded in `ldir`."""
    pg = localimpl.read_playground(ldir)
    if pg is None:
        raise GmError(f"no playground.yaml in {ldir}: run gmctl fit first")
    return Docker(pg.get("docker_endpoint"))


def label_filter(key, value):
    return f"label={key}={value}"


def running_containers(docker, service):
    """IDs of the running containers of a Swarm service on the targeted
    engine, found by the service label Swarm puts on its tasks' containers."""
    return docker.lines(["ps", "-q", "--no-trunc",
                         "--filter", label_filter("com.docker.swarm.service.name", service),
                         "--filter", "status=running"])
